/*   SPDX-License-Identifier: BSD-3-Clause
 *   Copyright (C) 2022 Intel Corporation.
 *   All rights reserved.
 */

#include <linux/ublk_cmd.h>
#include <liburing.h>

#include "spdk/stdinc.h"
#include "spdk/string.h"
#include "spdk/bdev.h"
#include "spdk/endian.h"
#include "spdk/env.h"
#include "spdk/likely.h"
#include "spdk/log.h"
#include "spdk/util.h"
#include "spdk/queue.h"
#include "spdk/json.h"
#include "spdk/ublk.h"
#include "spdk/thread.h"

#include "ublk_internal.h"

#define UBLK_CTRL_DEV					"/dev/ublk-control"
#define UBLK_BLK_CDEV					"/dev/ublkc"

#define LINUX_SECTOR_SHIFT				9
#define UBLK_POLL_GROUP_MAX				128
#define UBLK_IO_MAX_BYTES				SPDK_BDEV_LARGE_BUF_MAX_SIZE
#define UBLK_DEV_MAX_QUEUES				32
#define UBLK_DEV_MAX_QUEUE_DEPTH			1024
#define UBLK_QUEUE_REQUEST				32
#define UBLK_STOP_BUSY_WAITING_MS			10000
#define UBLK_BUSY_POLLING_INTERVAL_US			20000
#define UBLK_DEFAULT_CTRL_URING_POLLING_INTERVAL_US	1000
/* By default, kernel ublk_drv driver can support up to 64 block devices */
#define UBLK_DEFAULT_MAX_SUPPORTED_DEVS			64

#define UBLK_IOBUF_SMALL_CACHE_SIZE			128
#define UBLK_IOBUF_LARGE_CACHE_SIZE			32

#define UBLK_DEBUGLOG(ublk, format, ...) \
	SPDK_DEBUGLOG(ublk, "ublk%d: " format, ublk->ublk_id, ##__VA_ARGS__);

static uint32_t g_num_ublk_poll_groups = 0;
static uint32_t g_next_ublk_poll_group = 0;
static uint32_t g_ublks_max = UBLK_DEFAULT_MAX_SUPPORTED_DEVS;
static struct spdk_cpuset g_core_mask;

struct ublk_queue;
struct ublk_poll_group;
static void ublk_submit_bdev_io(struct ublk_queue *q, uint16_t tag);
static void ublk_dev_queue_fini(struct ublk_queue *q);
static int ublk_poll(void *arg);
static int ublk_ctrl_cmd(struct spdk_ublk_dev *ublk, uint32_t cmd_op);

typedef void (*ublk_next_state_fn)(struct spdk_ublk_dev *ublk);
static void ublk_set_params(struct spdk_ublk_dev *ublk);
static void ublk_finish_start(struct spdk_ublk_dev *ublk);
static void ublk_free_dev(struct spdk_ublk_dev *ublk);

static const char *ublk_op_name[64]
__attribute__((unused)) = {
	[UBLK_CMD_ADD_DEV] =	"UBLK_CMD_ADD_DEV",
	[UBLK_CMD_DEL_DEV] =	"UBLK_CMD_DEL_DEV",
	[UBLK_CMD_START_DEV] =	"UBLK_CMD_START_DEV",
	[UBLK_CMD_STOP_DEV] =	"UBLK_CMD_STOP_DEV",
	[UBLK_CMD_SET_PARAMS] =	"UBLK_CMD_SET_PARAMS",
};

struct ublk_io;
typedef void (*ublk_get_buf_cb)(struct ublk_io *io);

struct ublk_io {
	void			*payload;
	void			*mpool_entry;
	bool			need_data;
	uint32_t		sector_per_block_shift;
	uint32_t		payload_size;
	uint32_t		cmd_op;
	int32_t			result;
	struct spdk_bdev_desc	*bdev_desc;
	struct spdk_io_channel	*bdev_ch;
	const struct ublksrv_io_desc	*iod;
	ublk_get_buf_cb		get_buf_cb;
	struct ublk_queue	*q;
	/* for bdev io_wait */
	struct spdk_bdev_io_wait_entry bdev_io_wait;
	struct spdk_iobuf_entry	iobuf;

	TAILQ_ENTRY(ublk_io)	tailq;
};

struct ublk_queue {
	uint32_t		q_id;
	uint32_t		q_depth;
	struct ublk_io		*ios;
	TAILQ_HEAD(, ublk_io)	completed_io_list;
	TAILQ_HEAD(, ublk_io)	inflight_io_list;
	uint32_t		cmd_inflight;
	struct ublksrv_io_desc	*io_cmd_buf;
	/* ring depth == dev_info->queue_depth. */
	struct io_uring		ring;
	struct spdk_ublk_dev	*dev;
	struct ublk_poll_group	*poll_group;
	struct spdk_io_channel	*bdev_ch;

	TAILQ_ENTRY(ublk_queue)	tailq;
};

struct spdk_ublk_dev {
	struct spdk_bdev	*bdev;
	struct spdk_bdev_desc	*bdev_desc;

	int			cdev_fd;
	struct ublk_params	dev_params;
	struct ublksrv_ctrl_dev_info	dev_info;

	uint32_t		ublk_id;
	uint32_t		num_queues;
	uint32_t		queue_depth;
	uint32_t		sector_per_block_shift;
	struct ublk_queue	queues[UBLK_DEV_MAX_QUEUES];

	struct spdk_poller	*retry_poller;
	int			retry_count;
	uint32_t		queues_closed;
	volatile bool		is_closing;
	ublk_start_cb		start_cb;
	ublk_del_cb		del_cb;
	void			*cb_arg;
	uint32_t		ctrl_cmd_op;
	ublk_next_state_fn	next_state_fn;
	uint32_t		ctrl_ops_in_progress;

	TAILQ_ENTRY(spdk_ublk_dev) tailq;
	TAILQ_ENTRY(spdk_ublk_dev) wait_tailq;
};

struct ublk_poll_group {
	struct spdk_thread		*ublk_thread;
	struct spdk_poller		*ublk_poller;
	struct spdk_iobuf_channel	iobuf_ch;
	TAILQ_HEAD(, ublk_queue)	queue_list;
};

struct ublk_tgt {
	int			ctrl_fd;
	bool			active;
	bool			is_destroying;
	spdk_ublk_fini_cb	cb_fn;
	void			*cb_arg;
	struct io_uring		ctrl_ring;
	struct spdk_poller	*ctrl_poller;
	uint32_t		ctrl_ops_in_progress;
	struct ublk_poll_group	poll_group[UBLK_POLL_GROUP_MAX];
	uint32_t		num_ublk_devs;
};

static TAILQ_HEAD(, spdk_ublk_dev) g_ublk_devs = TAILQ_HEAD_INITIALIZER(g_ublk_devs);
static struct ublk_tgt g_ublk_tgt;

/* helpers for using io_uring */
static inline int
ublk_setup_ring(uint32_t depth, struct io_uring *r, unsigned flags)
{
	struct io_uring_params p = {};

	p.flags = flags | IORING_SETUP_CQSIZE;
	p.cq_entries = depth;

	return io_uring_queue_init_params(depth, r, &p);
}

static inline struct io_uring_sqe *
ublk_uring_get_sqe(struct io_uring *r, uint32_t idx)
{
	/* Need to update the idx since we set IORING_SETUP_SQE128 parameter in ublk_setup_ring */
	return &r->sq.sqes[idx << 1];
}

static inline void *
ublk_get_sqe_cmd(struct io_uring_sqe *sqe)
{
	return (void *)&sqe->addr3;
}

static inline void
ublk_set_sqe_cmd_op(struct io_uring_sqe *sqe, uint32_t cmd_op)
{
	sqe->off = cmd_op;
}

static inline uint64_t
build_user_data(uint16_t tag, uint8_t op)
{
	assert(!(tag >> 16) && !(op >> 8));

	return tag | (op << 16);
}

static inline uint16_t
user_data_to_tag(uint64_t user_data)
{
	return user_data & 0xffff;
}

static inline uint8_t
user_data_to_op(uint64_t user_data)
{
	return (user_data >> 16) & 0xff;
}

void
spdk_ublk_init(void)
{
	assert(spdk_get_thread() == spdk_thread_get_app_thread());

	g_ublk_tgt.ctrl_fd = -1;
	g_ublk_tgt.ctrl_ring.ring_fd = -1;
}

static int
ublk_ctrl_poller(void *arg)
{
	struct io_uring *ring = &g_ublk_tgt.ctrl_ring;
	struct spdk_ublk_dev *ublk;
	struct io_uring_cqe *cqe;
	const int max = 8;
	int i, count = 0, rc;

	if (!g_ublk_tgt.ctrl_ops_in_progress) {
		return SPDK_POLLER_IDLE;
	}

	for (i = 0; i < max; i++) {
		rc = io_uring_peek_cqe(ring, &cqe);
		if (rc == -EAGAIN) {
			break;
		}

		assert(cqe != NULL);
		g_ublk_tgt.ctrl_ops_in_progress--;
		ublk = (struct spdk_ublk_dev *)cqe->user_data;
		UBLK_DEBUGLOG(ublk, "ctrl cmd completed\n");
		ublk->ctrl_ops_in_progress--;
		if (ublk->next_state_fn) {
			ublk->next_state_fn(ublk);
		}
		io_uring_cqe_seen(ring, cqe);
		count++;
	}

	return count > 0 ? SPDK_POLLER_BUSY : SPDK_POLLER_IDLE;
}

static int
ublk_ctrl_cmd(struct spdk_ublk_dev *ublk, uint32_t cmd_op)
{
	uint32_t dev_id = ublk->ublk_id;
	int rc = -EINVAL;
	struct io_uring_sqe *sqe;
	struct ublksrv_ctrl_cmd *cmd;

	UBLK_DEBUGLOG(ublk, "ctrl cmd %s\n", ublk_op_name[cmd_op]);

	ublk->ctrl_cmd_op = cmd_op;
	sqe = io_uring_get_sqe(&g_ublk_tgt.ctrl_ring);
	if (!sqe) {
		SPDK_ERRLOG("No available sqe in ctrl ring\n");
		assert(false);
		return -ENOENT;
	}

	cmd = (struct ublksrv_ctrl_cmd *)ublk_get_sqe_cmd(sqe);
	sqe->fd = g_ublk_tgt.ctrl_fd;
	sqe->opcode = IORING_OP_URING_CMD;
	sqe->ioprio = 0;
	cmd->dev_id = dev_id;
	cmd->queue_id = -1;
	ublk->next_state_fn = NULL;

	switch (cmd_op) {
	case UBLK_CMD_ADD_DEV:
		ublk->next_state_fn = ublk_set_params;
		cmd->addr = (__u64)(uintptr_t)&ublk->dev_info;
		cmd->len = sizeof(ublk->dev_info);
		break;
	case UBLK_CMD_SET_PARAMS:
		ublk->next_state_fn = ublk_finish_start;
		cmd->addr = (__u64)(uintptr_t)&ublk->dev_params;
		cmd->len = sizeof(ublk->dev_params);
		break;
	case UBLK_CMD_START_DEV:
		cmd->data[0] = getpid();
		cmd->data[1] = 0;
		break;
	case UBLK_CMD_STOP_DEV:
		break;
	case UBLK_CMD_DEL_DEV:
		ublk->next_state_fn = ublk_free_dev;
		break;
	default:
		SPDK_ERRLOG("No match cmd operation,cmd_op = %d\n", cmd_op);
		return -EINVAL;
	}
	ublk_set_sqe_cmd_op(sqe, cmd_op);
	io_uring_sqe_set_data(sqe, ublk);

	rc = io_uring_submit(&g_ublk_tgt.ctrl_ring);
	if (rc < 0) {
		SPDK_ERRLOG("uring submit rc %d\n", rc);
		return rc;
	}
	g_ublk_tgt.ctrl_ops_in_progress++;
	ublk->ctrl_ops_in_progress++;

	return 0;
}

static int
ublk_queue_cmd_buf_sz(uint32_t q_depth)
{
	uint32_t size = q_depth * sizeof(struct ublksrv_io_desc);
	uint32_t page_sz = getpagesize();

	/* round up size */
	return (size + page_sz - 1) & ~(page_sz - 1);
}

static int
ublk_get_max_support_devs(void)
{
	FILE *file;
	char str[128];

	file = fopen("/sys/module/ublk_drv/parameters/ublks_max", "r");
	if (!file) {
		return -ENOENT;
	}

	if (!fgets(str, sizeof(str), file)) {
		fclose(file);
		return -EINVAL;
	}
	fclose(file);

	spdk_str_chomp(str);
	return spdk_strtol(str, 10);
}

static int
ublk_open(void)
{
	int rc, ublks_max;

	g_ublk_tgt.ctrl_fd = open(UBLK_CTRL_DEV, O_RDWR);
	if (g_ublk_tgt.ctrl_fd < 0) {
		rc = errno;
		SPDK_ERRLOG("UBLK conrol dev %s can't be opened, error=%s\n", UBLK_CTRL_DEV, spdk_strerror(errno));
		return -rc;
	}

	ublks_max = ublk_get_max_support_devs();
	if (ublks_max > 0) {
		g_ublks_max = ublks_max;
	}

	/* We need to set SQPOLL for kernels 6.1 and earlier, since they would not defer ublk ctrl
	 * ring processing to a workqueue.  Ctrl ring processing is minimal, so SQPOLL is fine.
	 * All the commands sent via control uring for a ublk device is executed one by one, so use
	 * ublks_max * 2 as the number of uring entries is enough.
	 */
	rc = ublk_setup_ring(g_ublks_max * 2, &g_ublk_tgt.ctrl_ring,
			     IORING_SETUP_SQE128 | IORING_SETUP_SQPOLL);
	if (rc < 0) {
		SPDK_ERRLOG("UBLK ctrl queue_init: %s\n", spdk_strerror(-rc));
		close(g_ublk_tgt.ctrl_fd);
		g_ublk_tgt.ctrl_fd = -1;
		return rc;
	}

	return 0;
}

static int
ublk_parse_core_mask(const char *mask)
{
	struct spdk_cpuset tmp_mask;
	int rc;

	if (mask == NULL) {
		spdk_env_get_cpuset(&g_core_mask);
		return 0;
	}

	rc = spdk_cpuset_parse(&g_core_mask, mask);
	if (rc < 0) {
		SPDK_ERRLOG("invalid cpumask %s\n", mask);
		return -EINVAL;
	}

	if (spdk_cpuset_count(&g_core_mask) == 0) {
		SPDK_ERRLOG("no cpus specified\n");
		return -EINVAL;
	}

	spdk_env_get_cpuset(&tmp_mask);
	spdk_cpuset_and(&tmp_mask, &g_core_mask);

	if (!spdk_cpuset_equal(&tmp_mask, &g_core_mask)) {
		SPDK_ERRLOG("one of selected cpu is outside of core mask(=%s)\n",
			    spdk_cpuset_fmt(&g_core_mask));
		return -EINVAL;
	}

	return 0;
}

static void
ublk_poller_register(void *args)
{
	struct ublk_poll_group *poll_group = args;
	int rc;

	assert(spdk_get_thread() == poll_group->ublk_thread);
	/* Bind ublk spdk_thread to current CPU core in order to avoid thread context switch
	 * during uring processing as required by ublk kernel.
	 */
	spdk_thread_bind(spdk_get_thread(), true);

	TAILQ_INIT(&poll_group->queue_list);
	poll_group->ublk_poller = SPDK_POLLER_REGISTER(ublk_poll, poll_group, 0);
	rc = spdk_iobuf_channel_init(&poll_group->iobuf_ch, "ublk",
				     UBLK_IOBUF_SMALL_CACHE_SIZE, UBLK_IOBUF_LARGE_CACHE_SIZE);
	if (rc != 0) {
		assert(false);
	}
}

int
ublk_create_target(const char *cpumask_str)
{
	int rc;
	uint32_t i;
	char thread_name[32];
	struct ublk_poll_group *poll_group;

	if (g_ublk_tgt.active == true) {
		SPDK_ERRLOG("UBLK target has been created\n");
		return -EBUSY;
	}

	rc = ublk_parse_core_mask(cpumask_str);
	if (rc != 0) {
		return rc;
	}

	rc = ublk_open();
	if (rc != 0) {
		SPDK_ERRLOG("Fail to open UBLK, error=%s\n", spdk_strerror(-rc));
		return rc;
	}

	spdk_iobuf_register_module("ublk");

	SPDK_ENV_FOREACH_CORE(i) {
		if (!spdk_cpuset_get_cpu(&g_core_mask, i)) {
			continue;
		}
		snprintf(thread_name, sizeof(thread_name), "ublk_thread%u", i);
		poll_group = &g_ublk_tgt.poll_group[g_num_ublk_poll_groups];
		poll_group->ublk_thread = spdk_thread_create(thread_name, &g_core_mask);
		spdk_thread_send_msg(poll_group->ublk_thread, ublk_poller_register, poll_group);
		g_num_ublk_poll_groups++;
	}

	assert(spdk_get_thread() == spdk_thread_get_app_thread());
	g_ublk_tgt.active = true;
	g_ublk_tgt.ctrl_ops_in_progress = 0;
	g_ublk_tgt.ctrl_poller = SPDK_POLLER_REGISTER(ublk_ctrl_poller, NULL,
				 UBLK_DEFAULT_CTRL_URING_POLLING_INTERVAL_US);

	SPDK_NOTICELOG("UBLK target created successfully\n");

	return 0;
}

static void
_ublk_fini_done(void *args)
{
	SPDK_DEBUGLOG(ublk, "\n");
	g_num_ublk_poll_groups = 0;
	g_next_ublk_poll_group = 0;
	g_ublk_tgt.is_destroying = false;
	g_ublk_tgt.active = false;
	if (g_ublk_tgt.cb_fn) {
		g_ublk_tgt.cb_fn(g_ublk_tgt.cb_arg);
		g_ublk_tgt.cb_fn = NULL;
		g_ublk_tgt.cb_arg = NULL;
	}
}

static void
ublk_thread_exit(void *args)
{
	struct spdk_thread *ublk_thread = spdk_get_thread();
	uint32_t i;

	for (i = 0; i < g_num_ublk_poll_groups; i++) {
		if (g_ublk_tgt.poll_group[i].ublk_thread == ublk_thread) {
			spdk_poller_unregister(&g_ublk_tgt.poll_group[i].ublk_poller);
			spdk_iobuf_channel_fini(&g_ublk_tgt.poll_group[i].iobuf_ch);
			spdk_thread_bind(ublk_thread, false);
			spdk_thread_exit(ublk_thread);
		}
	}
}

static int
ublk_close_dev(struct spdk_ublk_dev *ublk)
{
	int rc;

	/* set is_closing */
	if (ublk->is_closing) {
		return -EBUSY;
	}
	ublk->is_closing = true;

	rc = ublk_ctrl_cmd(ublk, UBLK_CMD_STOP_DEV);
	if (rc < 0) {
		SPDK_ERRLOG("stop dev %d failed\n", ublk->ublk_id);
	}
	return rc;
}

static void
_ublk_fini(void *args)
{
	struct spdk_ublk_dev	*ublk, *ublk_tmp;

	TAILQ_FOREACH_SAFE(ublk, &g_ublk_devs, tailq, ublk_tmp) {
		ublk_close_dev(ublk);
	}

	/* Check if all ublks closed */
	if (TAILQ_EMPTY(&g_ublk_devs)) {
		SPDK_DEBUGLOG(ublk, "finish shutdown\n");
		spdk_poller_unregister(&g_ublk_tgt.ctrl_poller);
		if (g_ublk_tgt.ctrl_ring.ring_fd >= 0) {
			io_uring_queue_exit(&g_ublk_tgt.ctrl_ring);
			g_ublk_tgt.ctrl_ring.ring_fd = -1;
		}
		if (g_ublk_tgt.ctrl_fd >= 0) {
			close(g_ublk_tgt.ctrl_fd);
			g_ublk_tgt.ctrl_fd = -1;
		}
		spdk_for_each_thread(ublk_thread_exit, NULL, _ublk_fini_done);
	} else {
		spdk_thread_send_msg(spdk_get_thread(), _ublk_fini, NULL);
	}
}

int
spdk_ublk_fini(spdk_ublk_fini_cb cb_fn, void *cb_arg)
{
	assert(spdk_get_thread() == spdk_thread_get_app_thread());

	if (g_ublk_tgt.is_destroying == true) {
		/* UBLK target is being destroying */
		return -EBUSY;
	}
	g_ublk_tgt.cb_fn = cb_fn;
	g_ublk_tgt.cb_arg = cb_arg;
	g_ublk_tgt.is_destroying = true;
	_ublk_fini(NULL);

	return 0;
}

int
ublk_destroy_target(spdk_ublk_fini_cb cb_fn, void *cb_arg)
{
	int rc;

	if (g_ublk_tgt.active == false) {
		/* UBLK target has not been created */
		return -ENOENT;
	}

	rc = spdk_ublk_fini(cb_fn, cb_arg);

	return rc;
}

struct spdk_ublk_dev *
ublk_dev_find_by_id(uint32_t ublk_id)
{
	struct spdk_ublk_dev *ublk;

	/* check whether ublk has already been registered by ublk path. */
	TAILQ_FOREACH(ublk, &g_ublk_devs, tailq) {
		if (ublk->ublk_id == ublk_id) {
			return ublk;
		}
	}

	return NULL;
}

uint32_t
ublk_dev_get_id(struct spdk_ublk_dev *ublk)
{
	return ublk->ublk_id;
}

struct spdk_ublk_dev *ublk_dev_first(void)
{
	return TAILQ_FIRST(&g_ublk_devs);
}

struct spdk_ublk_dev *ublk_dev_next(struct spdk_ublk_dev *prev)
{
	return TAILQ_NEXT(prev, tailq);
}

uint32_t
ublk_dev_get_queue_depth(struct spdk_ublk_dev *ublk)
{
	return ublk->queue_depth;
}

uint32_t
ublk_dev_get_num_queues(struct spdk_ublk_dev *ublk)
{
	return ublk->num_queues;
}

const char *
ublk_dev_get_bdev_name(struct spdk_ublk_dev *ublk)
{
	return spdk_bdev_get_name(ublk->bdev);
}

void
spdk_ublk_write_config_json(struct spdk_json_write_ctx *w)
{
	struct spdk_ublk_dev *ublk;

	spdk_json_write_array_begin(w);

	if (g_ublk_tgt.active) {
		spdk_json_write_object_begin(w);

		spdk_json_write_named_string(w, "method", "ublk_create_target");
		spdk_json_write_named_object_begin(w, "params");
		spdk_json_write_named_string(w, "cpumask", spdk_cpuset_fmt(&g_core_mask));
		spdk_json_write_object_end(w);

		spdk_json_write_object_end(w);
	}

	TAILQ_FOREACH(ublk, &g_ublk_devs, tailq) {
		spdk_json_write_object_begin(w);

		spdk_json_write_named_string(w, "method", "ublk_start_disk");

		spdk_json_write_named_object_begin(w, "params");
		spdk_json_write_named_string(w, "bdev_name", ublk_dev_get_bdev_name(ublk));
		spdk_json_write_named_uint32(w, "ublk_id", ublk->ublk_id);
		spdk_json_write_named_uint32(w, "num_queues", ublk->num_queues);
		spdk_json_write_named_uint32(w, "queue_depth", ublk->queue_depth);
		spdk_json_write_object_end(w);

		spdk_json_write_object_end(w);
	}

	spdk_json_write_array_end(w);
}

static int
ublk_dev_list_register(struct spdk_ublk_dev *ublk)
{
	/* Make sure ublk_id is not used in this SPDK app */
	if (ublk_dev_find_by_id(ublk->ublk_id)) {
		SPDK_NOTICELOG("%d is already exported with bdev %s\n",
			       ublk->ublk_id, ublk_dev_get_bdev_name(ublk));
		return -EBUSY;
	}

	UBLK_DEBUGLOG(ublk, "add to tailq\n");
	TAILQ_INSERT_TAIL(&g_ublk_devs, ublk, tailq);
	g_ublk_tgt.num_ublk_devs++;

	return 0;
}

static void
ublk_dev_list_unregister(struct spdk_ublk_dev *ublk)
{
	/*
	 * ublk device may be stopped before registered.
	 * check whether it was registered.
	 */

	if (ublk_dev_find_by_id(ublk->ublk_id)) {
		UBLK_DEBUGLOG(ublk, "remove from tailq\n");
		TAILQ_REMOVE(&g_ublk_devs, ublk, tailq);
		assert(g_ublk_tgt.num_ublk_devs);
		g_ublk_tgt.num_ublk_devs--;
		return;
	}

	UBLK_DEBUGLOG(ublk, "not found in tailq\n");
	assert(false);
}

static void
ublk_delete_dev(void *arg)
{
	struct spdk_ublk_dev *ublk = arg;
	int rc = 0;
	uint32_t q_idx;

	assert(spdk_get_thread() == spdk_thread_get_app_thread());
	for (q_idx = 0; q_idx < ublk->num_queues; q_idx++) {
		ublk_dev_queue_fini(&ublk->queues[q_idx]);
	}

	if (ublk->cdev_fd >= 0) {
		close(ublk->cdev_fd);
	}

	rc = ublk_ctrl_cmd(ublk, UBLK_CMD_DEL_DEV);
	if (rc < 0) {
		SPDK_ERRLOG("delete dev %d failed\n", ublk->ublk_id);
	}
}

static int
_ublk_close_dev_retry(void *arg)
{
	struct spdk_ublk_dev *ublk = arg;

	if (ublk->ctrl_ops_in_progress > 0) {
		if (ublk->retry_count-- > 0) {
			return SPDK_POLLER_BUSY;
		}
		SPDK_ERRLOG("Timeout on ctrl op completion.\n");
	}
	spdk_poller_unregister(&ublk->retry_poller);
	ublk_delete_dev(ublk);
	return SPDK_POLLER_BUSY;
}

static void
ublk_try_close_dev(void *arg)
{
	struct spdk_ublk_dev *ublk = arg;

	assert(spdk_get_thread() == spdk_thread_get_app_thread());
	ublk->queues_closed += 1;
	if (ublk->queues_closed < ublk->num_queues) {
		return;
	}

	if (ublk->ctrl_ops_in_progress > 0) {
		assert(ublk->retry_poller == NULL);
		ublk->retry_count = UBLK_STOP_BUSY_WAITING_MS * 1000ULL / UBLK_BUSY_POLLING_INTERVAL_US;
		ublk->retry_poller = SPDK_POLLER_REGISTER(_ublk_close_dev_retry, ublk,
				     UBLK_BUSY_POLLING_INTERVAL_US);
	} else {
		ublk_delete_dev(ublk);
	}
}

static void
ublk_try_close_queue(struct ublk_queue *q)
{
	struct spdk_ublk_dev *ublk = q->dev;

	/* Close queue until no I/O is submitted to bdev in flight,
	 * no I/O is waiting to commit result, and all I/Os are aborted back.
	 */
	if (!TAILQ_EMPTY(&q->inflight_io_list) || !TAILQ_EMPTY(&q->completed_io_list) || q->cmd_inflight) {
		/* wait for next retry */
		return;
	}

	TAILQ_REMOVE(&q->poll_group->queue_list, q, tailq);
	spdk_put_io_channel(q->bdev_ch);
	q->bdev_ch = NULL;

	spdk_thread_send_msg(spdk_thread_get_app_thread(), ublk_try_close_dev, ublk);
}

int
ublk_stop_disk(uint32_t ublk_id, ublk_del_cb del_cb, void *cb_arg)
{
	struct spdk_ublk_dev *ublk;

	assert(spdk_get_thread() == spdk_thread_get_app_thread());

	ublk = ublk_dev_find_by_id(ublk_id);
	if (ublk == NULL) {
		SPDK_ERRLOG("no ublk dev with ublk_id=%u\n", ublk_id);
		return -ENODEV;
	}
	if (ublk->is_closing) {
		SPDK_WARNLOG("ublk %d is closing\n", ublk->ublk_id);
		return -EBUSY;
	}

	ublk->del_cb = del_cb;
	ublk->cb_arg = cb_arg;
	return ublk_close_dev(ublk);
}

static inline void
ublk_mark_io_get_data(struct ublk_io *io)
{
	io->cmd_op = UBLK_IO_NEED_GET_DATA;
	io->result = 0;
}

static inline void
ublk_mark_io_done(struct ublk_io *io, int res)
{
	/*
	 * mark io done by target, so that SPDK can commit its
	 * result and fetch new request via io_uring command.
	 */
	io->cmd_op = UBLK_IO_COMMIT_AND_FETCH_REQ;
	io->result = res;
}

static void
ublk_io_done(struct spdk_bdev_io *bdev_io, bool success, void *cb_arg)
{
	struct ublk_io	*io = cb_arg;
	struct ublk_queue *q = io->q;
	int res, tag;

	if (success) {
		res = io->result;
	} else {
		res = -EIO;
	}

	ublk_mark_io_done(io, res);
	tag = (int)(io - q->ios);
	q->ios[tag].need_data = false;

	SPDK_DEBUGLOG(ublk_io, "(qid %d tag %d res %d)\n",
		      q->q_id, tag, res);
	TAILQ_REMOVE(&q->inflight_io_list, io, tailq);
	TAILQ_INSERT_TAIL(&q->completed_io_list, io, tailq);

	if (bdev_io != NULL) {
		spdk_bdev_free_io(bdev_io);
	}
}

static void
ublk_resubmit_io(void *arg)
{
	struct ublk_io *io = (struct ublk_io *)arg;
	uint16_t tag = (io - io->q->ios);

	ublk_submit_bdev_io(io->q, tag);
}

static void
ublk_queue_io(struct ublk_io *io)
{
	int rc;
	struct spdk_bdev *bdev = io->q->dev->bdev;
	struct ublk_queue *q = io->q;

	io->bdev_io_wait.bdev = bdev;
	io->bdev_io_wait.cb_fn = ublk_resubmit_io;
	io->bdev_io_wait.cb_arg = io;

	rc = spdk_bdev_queue_io_wait(bdev, q->bdev_ch, &io->bdev_io_wait);
	if (rc != 0) {
		SPDK_ERRLOG("Queue io failed in ublk_queue_io, rc=%d.\n", rc);
		ublk_io_done(NULL, false, io);
	}
}

static void
ublk_io_get_buffer_cb(struct spdk_iobuf_entry *iobuf, void *buf)
{
	struct ublk_io *io = SPDK_CONTAINEROF(iobuf, struct ublk_io, iobuf);

	io->mpool_entry = buf;
	io->payload = (void *)(uintptr_t)SPDK_ALIGN_CEIL((uintptr_t)buf, 4096ULL);
	io->get_buf_cb(io);
}

static void
ublk_io_get_buffer(struct ublk_io *io, struct spdk_iobuf_channel *iobuf_ch,
		   ublk_get_buf_cb get_buf_cb)
{
	uint64_t io_size;
	void *buf;

	io_size = io->iod->nr_sectors * (1ULL << LINUX_SECTOR_SHIFT);
	io->get_buf_cb = get_buf_cb;
	buf = spdk_iobuf_get(iobuf_ch, io_size, &io->iobuf, ublk_io_get_buffer_cb);
	if (buf != NULL) {
		ublk_io_get_buffer_cb(&io->iobuf, buf);
	}
}

static void
ublk_io_put_buffer(struct ublk_io *io, struct spdk_iobuf_channel *iobuf_ch)
{
	uint64_t io_size;

	if (io->payload) {
		io_size = io->iod->nr_sectors * (1ULL << LINUX_SECTOR_SHIFT);
		spdk_iobuf_put(iobuf_ch, io->mpool_entry, io_size);
		io->mpool_entry = NULL;
		io->payload = NULL;
	}
}

static void
read_get_buffer_done(struct ublk_io *io)
{
	struct spdk_bdev_desc *desc = io->bdev_desc;
	struct spdk_io_channel *ch = io->bdev_ch;
	uint64_t offset_blocks, num_blocks;
	int rc = 0;
	const struct ublksrv_io_desc *iod = io->iod;

	offset_blocks = iod->start_sector >> io->sector_per_block_shift;
	num_blocks = iod->nr_sectors >> io->sector_per_block_shift;

	rc = spdk_bdev_read_blocks(desc, ch, io->payload, offset_blocks, num_blocks, ublk_io_done, io);
	if (rc == -ENOMEM) {
		SPDK_INFOLOG(ublk, "No memory, start to queue io.\n");
		ublk_queue_io(io);
	} else if (rc < 0) {
		SPDK_ERRLOG("ublk io failed in ublk_queue_io, rc=%d.\n", rc);
		ublk_io_done(NULL, false, io);
	}
}

static void
ublk_submit_bdev_io(struct ublk_queue *q, uint16_t tag)
{
	struct spdk_ublk_dev *ublk = q->dev;
	struct ublk_io *io = &q->ios[tag];
	struct spdk_bdev_desc *desc = io->bdev_desc;
	struct spdk_io_channel *ch = io->bdev_ch;
	struct spdk_iobuf_channel *iobuf_ch = &q->poll_group->iobuf_ch;
	uint64_t offset_blocks, num_blocks;
	uint8_t ublk_op;
	int rc = 0;
	const struct ublksrv_io_desc *iod = io->iod;

	ublk_op = ublksrv_get_op(iod);
	offset_blocks = iod->start_sector >> ublk->sector_per_block_shift;
	num_blocks = iod->nr_sectors >> ublk->sector_per_block_shift;

	io->result = num_blocks * spdk_bdev_get_data_block_size(ublk->bdev);
	switch (ublk_op) {
	case UBLK_IO_OP_READ:
		ublk_io_get_buffer(io, iobuf_ch, read_get_buffer_done);
		return;
	case UBLK_IO_OP_WRITE:
		assert((void *)iod->addr == io->payload);
		rc = spdk_bdev_write_blocks(desc, ch, io->payload, offset_blocks, num_blocks, ublk_io_done, io);
		break;
	case UBLK_IO_OP_FLUSH:
		rc = spdk_bdev_flush_blocks(desc, ch, offset_blocks, num_blocks, ublk_io_done, io);
		break;
	case UBLK_IO_OP_DISCARD:
		rc = spdk_bdev_unmap_blocks(desc, ch, offset_blocks, num_blocks, ublk_io_done, io);
		break;
	case UBLK_IO_OP_WRITE_ZEROES:
		rc = spdk_bdev_write_zeroes_blocks(desc, ch, offset_blocks, num_blocks, ublk_io_done, io);
		break;
	default:
		rc = -1;
	}

	if (rc < 0) {
		if (rc == -ENOMEM) {
			SPDK_INFOLOG(ublk, "No memory, start to queue io.\n");
			ublk_queue_io(io);
		} else {
			SPDK_ERRLOG("ublk io failed in ublk_queue_io, rc=%d.\n", rc);
			ublk_io_done(NULL, false, io);
		}
	}
}

static inline void
ublksrv_queue_io_cmd(struct ublk_queue *q,
		     struct ublk_io *io, unsigned tag)
{
	struct ublksrv_io_cmd *cmd;
	struct io_uring_sqe *sqe;
	unsigned int cmd_op = 0;;
	uint64_t user_data;

	/* each io should have operation of fetching or committing */
	assert((io->cmd_op == UBLK_IO_FETCH_REQ) || (io->cmd_op == UBLK_IO_NEED_GET_DATA) ||
	       (io->cmd_op == UBLK_IO_COMMIT_AND_FETCH_REQ));
	cmd_op = io->cmd_op;

	sqe = io_uring_get_sqe(&q->ring);
	assert(sqe);

	cmd = (struct ublksrv_io_cmd *)ublk_get_sqe_cmd(sqe);
	if (cmd_op == UBLK_IO_COMMIT_AND_FETCH_REQ) {
		cmd->result = io->result;
	}

	/* These fields should be written once, never change */
	ublk_set_sqe_cmd_op(sqe, cmd_op);
	/* dev->cdev_fd */
	sqe->fd		= 0;
	sqe->opcode	= IORING_OP_URING_CMD;
	sqe->flags	= IOSQE_FIXED_FILE;
	sqe->rw_flags	= 0;
	cmd->tag	= tag;
	cmd->addr	= (__u64)(uintptr_t)(io->payload);
	cmd->q_id	= q->q_id;

	user_data = build_user_data(tag, cmd_op);
	io_uring_sqe_set_data64(sqe, user_data);

	io->cmd_op = 0;
	q->cmd_inflight += 1;

	SPDK_DEBUGLOG(ublk_io, "(qid %d tag %u cmd_op %u) iof %x stopping %d\n",
		      q->q_id, tag, cmd_op,
		      io->cmd_op, q->dev->is_closing);
}

static int
ublk_io_xmit(struct ublk_queue *q)
{
	TAILQ_HEAD(, ublk_io) buffer_free_list;
	struct spdk_iobuf_channel *iobuf_ch;
	int rc = 0, count = 0, tag;
	struct ublk_io *io;

	if (TAILQ_EMPTY(&q->completed_io_list)) {
		return 0;
	}

	TAILQ_INIT(&buffer_free_list);
	while (!TAILQ_EMPTY(&q->completed_io_list)) {
		io = TAILQ_FIRST(&q->completed_io_list);
		tag = io - io->q->ios;
		assert(io != NULL);
		/*
		 * Remove IO from list now assuming it will be completed. It will be inserted
		 * back to the head if it cannot be completed. This approach is specifically
		 * taken to work around a scan-build use-after-free mischaracterization.
		 */
		TAILQ_REMOVE(&q->completed_io_list, io, tailq);
		if (!io->need_data) {
			TAILQ_INSERT_TAIL(&buffer_free_list, io, tailq);
		}
		ublksrv_queue_io_cmd(q, io, tag);
		count++;
	}

	rc = io_uring_submit(&q->ring);
	if (rc != count) {
		SPDK_ERRLOG("could not submit all commands\n");
		assert(false);
	}

	/* Note: for READ io, ublk will always copy the data out of
	 * the buffers in the io_uring_submit context.  Since we
	 * are not using SQPOLL for IO rings, we can safely free
	 * those IO buffers here.  This design doesn't seem ideal,
	 * but it's what's possible since there is no discrete
	 * COMMIT_REQ operation.  That will need to change in the
	 * future should we ever want to support async copy
	 * operations.
	 */
	iobuf_ch = &q->poll_group->iobuf_ch;
	while (!TAILQ_EMPTY(&buffer_free_list)) {
		io = TAILQ_FIRST(&buffer_free_list);
		TAILQ_REMOVE(&buffer_free_list, io, tailq);
		ublk_io_put_buffer(io, iobuf_ch);
	}
	return rc;
}

static void
write_get_buffer_done(struct ublk_io *io)
{
	io->need_data = true;
	ublk_mark_io_get_data(io);
	TAILQ_REMOVE(&io->q->inflight_io_list, io, tailq);
	TAILQ_INSERT_TAIL(&io->q->completed_io_list, io, tailq);
}

static int
ublk_io_recv(struct ublk_queue *q)
{
	struct io_uring_cqe *cqe;
	unsigned head, tag;
	int fetch, count = 0;
	struct ublk_io *io;
	struct spdk_ublk_dev *dev = q->dev;
	struct spdk_iobuf_channel *iobuf_ch;
	unsigned __attribute__((unused)) cmd_op;

	if (q->cmd_inflight == 0) {
		return 0;
	}

	iobuf_ch = &q->poll_group->iobuf_ch;
	io_uring_for_each_cqe(&q->ring, head, cqe) {
		tag = user_data_to_tag(cqe->user_data);
		cmd_op = user_data_to_op(cqe->user_data);
		fetch = (cqe->res != UBLK_IO_RES_ABORT) && !dev->is_closing;

		SPDK_DEBUGLOG(ublk_io, "res %d qid %d tag %u cmd_op %u\n",
			      cqe->res, q->q_id, tag, cmd_op);

		q->cmd_inflight--;
		io = &q->ios[tag];

		if (!fetch) {
			dev->is_closing = true;
			if (io->cmd_op == UBLK_IO_FETCH_REQ) {
				io->cmd_op = 0;
			}
		}

		TAILQ_INSERT_TAIL(&q->inflight_io_list, io, tailq);
		if (cqe->res == UBLK_IO_RES_OK) {
			ublk_submit_bdev_io(q, tag);
		} else if (cqe->res == UBLK_IO_RES_NEED_GET_DATA) {
			ublk_io_get_buffer(io, iobuf_ch, write_get_buffer_done);
		} else {
			if (cqe->res != UBLK_IO_RES_ABORT) {
				SPDK_ERRLOG("ublk received error io: res %d qid %d tag %u cmd_op %u\n",
					    cqe->res, q->q_id, tag, cmd_op);
			}
			TAILQ_REMOVE(&q->inflight_io_list, io, tailq);
		}
		count += 1;
		if (count == UBLK_QUEUE_REQUEST) {
			break;
		}
	}
	io_uring_cq_advance(&q->ring, count);

	return count;
}

static int
ublk_poll(void *arg)
{
	struct ublk_poll_group *poll_group = arg;
	struct ublk_queue *q, *q_tmp;
	struct spdk_ublk_dev *ublk;
	int sent, received, count = 0;

	TAILQ_FOREACH_SAFE(q, &poll_group->queue_list, tailq, q_tmp) {
		sent = ublk_io_xmit(q);
		received = ublk_io_recv(q);
		ublk = q->dev;
		if (spdk_unlikely(ublk->is_closing)) {
			ublk_try_close_queue(q);
		}
		count += sent + received;
	}
	if (count > 0) {
		return SPDK_POLLER_BUSY;
	} else {
		return SPDK_POLLER_IDLE;
	}
}

static void
ublk_bdev_hot_remove(struct spdk_ublk_dev *ublk)
{
	ublk_close_dev(ublk);
}

static void
ublk_bdev_event_cb(enum spdk_bdev_event_type type, struct spdk_bdev *bdev,
		   void *event_ctx)
{
	switch (type) {
	case SPDK_BDEV_EVENT_REMOVE:
		ublk_bdev_hot_remove(event_ctx);
		break;
	default:
		SPDK_NOTICELOG("Unsupported bdev event: type %d\n", type);
		break;
	}
}

static void
ublk_dev_init_io_cmds(struct io_uring *r, uint32_t q_depth)
{
	struct io_uring_sqe *sqe;
	uint32_t i;

	for (i = 0; i < q_depth; i++) {
		sqe = ublk_uring_get_sqe(r, i);

		/* These fields should be written once, never change */
		sqe->flags = IOSQE_FIXED_FILE;
		sqe->rw_flags = 0;
		sqe->ioprio = 0;
		sqe->off = 0;
	}
}

static int
ublk_dev_queue_init(struct ublk_queue *q)
{
	int rc = 0, cmd_buf_size;
	uint32_t j;
	struct spdk_ublk_dev *ublk = q->dev;
	unsigned long off;

	cmd_buf_size = ublk_queue_cmd_buf_sz(q->q_depth);
	off = UBLKSRV_CMD_BUF_OFFSET +
	      q->q_id * (UBLK_MAX_QUEUE_DEPTH * sizeof(struct ublksrv_io_desc));
	q->io_cmd_buf = (struct ublksrv_io_desc *)mmap(0, cmd_buf_size, PROT_READ,
			MAP_SHARED | MAP_POPULATE, ublk->cdev_fd, off);
	if (q->io_cmd_buf == MAP_FAILED) {
		q->io_cmd_buf = NULL;
		rc = -errno;
		SPDK_ERRLOG("Failed at mmap: %s\n", spdk_strerror(-rc));
		goto err;
	}

	for (j = 0; j < q->q_depth; j++) {
		q->ios[j].cmd_op = UBLK_IO_FETCH_REQ;
		q->ios[j].iod = &q->io_cmd_buf[j];
	}

	rc = ublk_setup_ring(q->q_depth, &q->ring, IORING_SETUP_SQE128);
	if (rc < 0) {
		SPDK_ERRLOG("Failed at setup uring: %s\n", spdk_strerror(-rc));
		munmap(q->io_cmd_buf, ublk_queue_cmd_buf_sz(q->q_depth));
		q->io_cmd_buf = NULL;
		goto err;
	}

	rc = io_uring_register_files(&q->ring, &ublk->cdev_fd, 1);
	if (rc != 0) {
		SPDK_ERRLOG("Failed at uring register files: %s\n", spdk_strerror(-rc));
		io_uring_queue_exit(&q->ring);
		q->ring.ring_fd = -1;
		munmap(q->io_cmd_buf, ublk_queue_cmd_buf_sz(q->q_depth));
		q->io_cmd_buf = NULL;
		goto err;
	}

	ublk_dev_init_io_cmds(&q->ring, q->q_depth);

	return 0;
err:
	return rc;
}

static void
ublk_dev_queue_fini(struct ublk_queue *q)
{
	if (q->ring.ring_fd >= 0) {
		io_uring_unregister_files(&q->ring);
		io_uring_queue_exit(&q->ring);
		q->ring.ring_fd = -1;
	}
	if (q->io_cmd_buf) {
		munmap(q->io_cmd_buf, ublk_queue_cmd_buf_sz(q->q_depth));
	}
}

static void
ublk_dev_queue_io_init(struct ublk_queue *q)
{
	struct ublk_io *io;
	uint32_t i;
	int rc __attribute__((unused));
	void *buf;

	/* Some older kernels require a buffer to get posted, even
	 * when NEED_GET_DATA has been specified.  So allocate a
	 * temporary buffer, only for purposes of this workaround.
	 * It never actually gets used, so we will free it immediately
	 * after all of the commands are posted.
	 */
	buf = malloc(64);

	assert(q->bdev_ch != NULL);

	/* Initialize and submit all io commands to ublk driver */
	for (i = 0; i < q->q_depth; i++) {
		io = &q->ios[i];
		io->payload = buf;
		io->bdev_ch = q->bdev_ch;
		io->bdev_desc = q->dev->bdev_desc;
		io->sector_per_block_shift = q->dev->sector_per_block_shift;
		ublksrv_queue_io_cmd(q, io, i);
	}

	rc = io_uring_submit(&q->ring);
	assert(rc == (int)q->q_depth);
	for (i = 0; i < q->q_depth; i++) {
		io = &q->ios[i];
		io->payload = NULL;
	}
	free(buf);
}

static void
ublk_set_params(struct spdk_ublk_dev *ublk)
{
	int rc;

	ublk->dev_params.len = sizeof(struct ublk_params);
	rc = ublk_ctrl_cmd(ublk, UBLK_CMD_SET_PARAMS);
	if (rc < 0) {
		SPDK_ERRLOG("UBLK can't set params for dev %d, rc %s\n", ublk->ublk_id, spdk_strerror(-rc));
		ublk_delete_dev(ublk);
		if (ublk->start_cb) {
			ublk->start_cb(ublk->cb_arg, rc);
		}
	}
}

/* Set ublk device parameters based on bdev */
static void
ublk_info_param_init(struct spdk_ublk_dev *ublk)
{
	struct spdk_bdev *bdev = ublk->bdev;
	uint32_t blk_size = spdk_bdev_get_data_block_size(bdev);
	uint32_t pblk_size = spdk_bdev_get_physical_block_size(bdev);
	uint32_t io_opt_blocks = spdk_bdev_get_optimal_io_boundary(bdev);
	uint64_t num_blocks = spdk_bdev_get_num_blocks(bdev);
	uint8_t sectors_per_block = blk_size >> LINUX_SECTOR_SHIFT;
	uint32_t io_min_size = blk_size;
	uint32_t io_opt_size = spdk_max(io_opt_blocks * blk_size, io_min_size);

	struct ublksrv_ctrl_dev_info uinfo = {
		.queue_depth = ublk->queue_depth,
		.nr_hw_queues = ublk->num_queues,
		.dev_id = ublk->ublk_id,
		.max_io_buf_bytes = UBLK_IO_MAX_BYTES,
		.ublksrv_pid = getpid(),
		.flags = UBLK_F_NEED_GET_DATA | UBLK_F_URING_CMD_COMP_IN_TASK,
	};
	struct ublk_params uparams = {
		.types = UBLK_PARAM_TYPE_BASIC,
		.basic = {
			.logical_bs_shift = spdk_u32log2(blk_size),
			.physical_bs_shift = spdk_u32log2(pblk_size),
			.io_min_shift = spdk_u32log2(io_min_size),
			.io_opt_shift = spdk_u32log2(io_opt_size),
			.dev_sectors = num_blocks * sectors_per_block,
			.max_sectors = UBLK_IO_MAX_BYTES >> LINUX_SECTOR_SHIFT,
		}
	};

	if (spdk_bdev_io_type_supported(bdev, SPDK_BDEV_IO_TYPE_UNMAP)) {
		uparams.types |= UBLK_PARAM_TYPE_DISCARD;
		uparams.discard.discard_alignment = sectors_per_block;
		uparams.discard.max_discard_sectors = num_blocks * sectors_per_block;
		uparams.discard.max_discard_segments = 1;
		uparams.discard.discard_granularity = blk_size;
		if (spdk_bdev_io_type_supported(bdev, SPDK_BDEV_IO_TYPE_WRITE_ZEROES)) {
			uparams.discard.max_write_zeroes_sectors = num_blocks * sectors_per_block;
		}
	}

	ublk->dev_info = uinfo;
	ublk->dev_params = uparams;
}

static void
_ublk_free_dev(void *arg)
{
	struct spdk_ublk_dev *ublk = arg;

	ublk_free_dev(ublk);
}

static void
free_buffers(void *arg)
{
	struct ublk_queue *q = arg;
	uint32_t i;

	for (i = 0; i < q->q_depth; i++) {
		ublk_io_put_buffer(&q->ios[i], &q->poll_group->iobuf_ch);
	}
	free(q->ios);
	q->ios = NULL;
	spdk_thread_send_msg(spdk_thread_get_app_thread(), _ublk_free_dev, q->dev);
}

static void
ublk_free_dev(struct spdk_ublk_dev *ublk)
{
	struct ublk_queue *q;
	uint32_t q_idx;

	for (q_idx = 0; q_idx < ublk->num_queues; q_idx++) {
		q = &ublk->queues[q_idx];

		/* The ublk_io of this queue are not initialized. */
		if (q->ios == NULL) {
			continue;
		}

		/* We found a queue that has an ios array that may have buffers
		 * that need to be freed.  Send a message to the queue's thread
		 * so it can free the buffers back to that thread's iobuf channel.
		 * When it's done, it will set q->ios to NULL and send a message
		 * back to this function to continue.
		 */
		spdk_thread_send_msg(q->poll_group->ublk_thread, free_buffers, q);
		return;
	}

	/* All of the buffers associated with the queues have been freed, so now
	 * continue with releasing resources for the rest of the ublk device.
	 */
	if (ublk->bdev_desc) {
		spdk_bdev_close(ublk->bdev_desc);
		ublk->bdev_desc = NULL;
	}

	ublk_dev_list_unregister(ublk);

	if (ublk->del_cb) {
		ublk->del_cb(ublk->cb_arg);
	}
	SPDK_NOTICELOG("ublk dev %d stopped\n", ublk->ublk_id);
	free(ublk);
}

static int
ublk_ios_init(struct spdk_ublk_dev *ublk)
{
	int rc;
	uint32_t i, j;
	struct ublk_queue *q;

	for (i = 0; i < ublk->num_queues; i++) {
		q = &ublk->queues[i];

		TAILQ_INIT(&q->completed_io_list);
		TAILQ_INIT(&q->inflight_io_list);
		q->dev = ublk;
		q->q_id = i;
		q->q_depth = ublk->queue_depth;
		q->ios = calloc(q->q_depth, sizeof(struct ublk_io));
		if (!q->ios) {
			rc = -ENOMEM;
			SPDK_ERRLOG("could not allocate queue ios\n");
			goto err;
		}
		for (j = 0; j < q->q_depth; j++) {
			q->ios[j].q = q;
		}
	}

	return 0;

err:
	for (i = 0; i < ublk->num_queues; i++) {
		free(q->ios);
		q->ios = NULL;
	}
	return rc;
}

static void
ublk_queue_run(void *arg1)
{
	struct ublk_queue	*q = arg1;
	struct spdk_ublk_dev *ublk = q->dev;
	struct ublk_poll_group *poll_group = q->poll_group;

	assert(spdk_get_thread() == poll_group->ublk_thread);
	q->bdev_ch = spdk_bdev_get_io_channel(ublk->bdev_desc);
	/* Queues must be filled with IO in the io pthread */
	ublk_dev_queue_io_init(q);

	TAILQ_INSERT_TAIL(&poll_group->queue_list, q, tailq);
}

int
ublk_start_disk(const char *bdev_name, uint32_t ublk_id,
		uint32_t num_queues, uint32_t queue_depth,
		ublk_start_cb start_cb, void *cb_arg)
{
	int			rc;
	uint32_t		i;
	struct spdk_bdev	*bdev;
	struct spdk_ublk_dev	*ublk = NULL;
	uint32_t		sector_per_block;

	assert(spdk_get_thread() == spdk_thread_get_app_thread());

	if (g_ublk_tgt.active == false) {
		SPDK_ERRLOG("NO ublk target exist\n");
		return -ENODEV;
	}

	ublk = ublk_dev_find_by_id(ublk_id);
	if (ublk != NULL) {
		SPDK_DEBUGLOG(ublk, "ublk id %d is in use.\n", ublk_id);
		return -EBUSY;
	}

	if (g_ublk_tgt.num_ublk_devs >= g_ublks_max) {
		SPDK_DEBUGLOG(ublk, "Reached maximum number of supported devices: %u\n", g_ublks_max);
		return -ENOTSUP;
	}

	ublk = calloc(1, sizeof(*ublk));
	if (ublk == NULL) {
		return -ENOMEM;
	}
	ublk->start_cb = start_cb;
	ublk->cb_arg = cb_arg;
	ublk->cdev_fd = -1;
	ublk->ublk_id = ublk_id;
	UBLK_DEBUGLOG(ublk, "bdev %s num_queues %d queue_depth %d\n",
		      bdev_name, num_queues, queue_depth);

	rc = spdk_bdev_open_ext(bdev_name, true, ublk_bdev_event_cb, ublk, &ublk->bdev_desc);
	if (rc != 0) {
		SPDK_ERRLOG("could not open bdev %s, error=%d\n", bdev_name, rc);
		free(ublk);
		return rc;
	}

	bdev = spdk_bdev_desc_get_bdev(ublk->bdev_desc);
	ublk->bdev = bdev;
	sector_per_block = spdk_bdev_get_data_block_size(ublk->bdev) >> LINUX_SECTOR_SHIFT;
	ublk->sector_per_block_shift = spdk_u32log2(sector_per_block);

	ublk->queues_closed = 0;
	ublk->num_queues = num_queues;
	ublk->queue_depth = queue_depth;
	if (ublk->queue_depth > UBLK_DEV_MAX_QUEUE_DEPTH) {
		SPDK_WARNLOG("Set Queue depth %d of UBLK %d to maximum %d\n",
			     ublk->queue_depth, ublk->ublk_id, UBLK_DEV_MAX_QUEUE_DEPTH);
		ublk->queue_depth = UBLK_DEV_MAX_QUEUE_DEPTH;
	}
	if (ublk->num_queues > UBLK_DEV_MAX_QUEUES) {
		SPDK_WARNLOG("Set Queue num %d of UBLK %d to maximum %d\n",
			     ublk->num_queues, ublk->ublk_id, UBLK_DEV_MAX_QUEUES);
		ublk->num_queues = UBLK_DEV_MAX_QUEUES;
	}
	for (i = 0; i < ublk->num_queues; i++) {
		ublk->queues[i].ring.ring_fd = -1;
	}

	/* Add ublk_dev to the end of disk list */
	rc = ublk_dev_list_register(ublk);
	if (rc != 0) {
		spdk_bdev_close(ublk->bdev_desc);
		free(ublk);
		return rc;
	}

	ublk_info_param_init(ublk);
	rc = ublk_ios_init(ublk);
	if (rc != 0) {
		ublk_free_dev(ublk);
		return rc;
	}

	SPDK_INFOLOG(ublk, "Enabling kernel access to bdev %s via ublk %d\n",
		     bdev_name, ublk_id);
	rc = ublk_ctrl_cmd(ublk, UBLK_CMD_ADD_DEV);
	if (rc < 0) {
		SPDK_ERRLOG("UBLK can't add dev %d, rc %s\n", ublk->ublk_id, spdk_strerror(-rc));
		ublk_free_dev(ublk);
	}

	return rc;
}

static void
ublk_finish_start(struct spdk_ublk_dev *ublk)
{
	int			rc;
	uint32_t		q_id;
	struct spdk_thread	*ublk_thread;
	char			buf[64];

	snprintf(buf, 64, "%s%d", UBLK_BLK_CDEV, ublk->ublk_id);
	ublk->cdev_fd = open(buf, O_RDWR);
	if (ublk->cdev_fd < 0) {
		rc = ublk->cdev_fd;
		SPDK_ERRLOG("can't open %s, rc %d\n", buf, rc);
		goto err;
	}

	for (q_id = 0; q_id < ublk->num_queues; q_id++) {
		rc = ublk_dev_queue_init(&ublk->queues[q_id]);
		if (rc) {
			goto err;
		}
	}

	rc = ublk_ctrl_cmd(ublk, UBLK_CMD_START_DEV);
	if (rc < 0) {
		SPDK_ERRLOG("start dev %d failed, rc %s\n", ublk->ublk_id,
			    spdk_strerror(-rc));
		goto err;
	}

	/* Send queue to different spdk_threads for load balance */
	for (q_id = 0; q_id < ublk->num_queues; q_id++) {
		ublk->queues[q_id].poll_group = &g_ublk_tgt.poll_group[g_next_ublk_poll_group];
		ublk_thread = g_ublk_tgt.poll_group[g_next_ublk_poll_group].ublk_thread;
		spdk_thread_send_msg(ublk_thread, ublk_queue_run, &ublk->queues[q_id]);
		g_next_ublk_poll_group++;
		if (g_next_ublk_poll_group == g_num_ublk_poll_groups) {
			g_next_ublk_poll_group = 0;
		}
	}

	goto out;

err:
	ublk_delete_dev(ublk);
out:
	if (ublk->start_cb) {
		ublk->start_cb(ublk->cb_arg, rc);
	}
}

SPDK_LOG_REGISTER_COMPONENT(ublk)
SPDK_LOG_REGISTER_COMPONENT(ublk_io)
