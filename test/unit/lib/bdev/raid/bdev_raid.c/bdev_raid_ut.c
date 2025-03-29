/*   SPDX-License-Identifier: BSD-3-Clause
 *   Copyright (C) 2018 Intel Corporation.
 *   All rights reserved.
 *   Copyright (c) 2022-2023 NVIDIA CORPORATION & AFFILIATES. All rights reserved.
 */

#include "spdk/stdinc.h"
#include "spdk/util.h"
#include "spdk_internal/cunit.h"
#include "spdk/env.h"
#include "spdk_internal/mock.h"
#include "thread/thread_internal.h"
#include "bdev/raid/bdev_raid.c"
#include "bdev/raid/bdev_raid_rpc.c"
#include "common/lib/test_env.c"

#define MAX_BASE_DRIVES 32
#define MAX_RAIDS 2
#define BLOCK_CNT (1024ul * 1024ul * 1024ul * 1024ul)
#define MD_SIZE 8

struct spdk_bdev_channel {
	struct spdk_io_channel *channel;
};

struct spdk_bdev_desc {
	struct spdk_bdev *bdev;
};

/* Data structure to capture the output of IO for verification */
struct io_output {
	struct spdk_bdev_desc       *desc;
	struct spdk_io_channel      *ch;
	enum spdk_bdev_io_type      iotype;
};

/* Globals */
struct io_output *g_io_output = NULL;
uint32_t g_io_output_index;
uint32_t g_io_comp_status;
bool g_child_io_status_flag;
void *g_rpc_req;
uint32_t g_rpc_req_size;
TAILQ_HEAD(bdev, spdk_bdev);
struct bdev g_bdev_list;
uint32_t g_block_len;
uint32_t g_strip_size;
uint32_t g_max_io_size;
uint8_t g_max_base_drives;
uint8_t g_max_raids;
uint8_t g_rpc_err;
char *g_get_raids_output[MAX_RAIDS];
uint32_t g_get_raids_count;
uint8_t g_json_decode_obj_err;
uint8_t g_json_decode_obj_create;
uint8_t g_test_multi_raids;
uint64_t g_bdev_ch_io_device;
bool g_bdev_io_defer_completion;
TAILQ_HEAD(, spdk_bdev_io) g_deferred_ios = TAILQ_HEAD_INITIALIZER(g_deferred_ios);
struct spdk_thread *g_app_thread;
struct spdk_thread *g_latest_thread;

static int
ut_raid_start(struct raid_bdev *raid_bdev)
{
	uint64_t min_blockcnt = UINT64_MAX;
	struct raid_base_bdev_info *base_info;

	RAID_FOR_EACH_BASE_BDEV(raid_bdev, base_info) {
		min_blockcnt = spdk_min(min_blockcnt, base_info->data_size);
	}
	raid_bdev->bdev.blockcnt = min_blockcnt;

	return 0;
}

static void
ut_raid_submit_rw_request_defered_cb(struct spdk_bdev_io *bdev_io, bool success, void *cb_arg)
{
	struct raid_bdev_io *raid_io = cb_arg;

	raid_bdev_io_complete(raid_io, success ? SPDK_BDEV_IO_STATUS_SUCCESS : SPDK_BDEV_IO_STATUS_FAILED);
}

static void
ut_raid_submit_rw_request(struct raid_bdev_io *raid_io)
{
	if (g_bdev_io_defer_completion) {
		struct spdk_bdev_io *bdev_io = spdk_bdev_io_from_ctx(raid_io);

		bdev_io->internal.cb = ut_raid_submit_rw_request_defered_cb;
		bdev_io->internal.caller_ctx = raid_io;
		TAILQ_INSERT_TAIL(&g_deferred_ios, bdev_io, internal.link);
		return;
	}
	raid_bdev_io_complete(raid_io,
			      g_child_io_status_flag ? SPDK_BDEV_IO_STATUS_SUCCESS : SPDK_BDEV_IO_STATUS_FAILED);
}

static void
ut_raid_submit_null_payload_request(struct raid_bdev_io *raid_io)
{
	raid_bdev_io_complete(raid_io,
			      g_child_io_status_flag ? SPDK_BDEV_IO_STATUS_SUCCESS : SPDK_BDEV_IO_STATUS_FAILED);
}

static void
ut_raid_complete_process_request(void *ctx)
{
	struct raid_bdev_process_request *process_req = ctx;

	raid_bdev_process_request_complete(process_req, 0);
}

static int
ut_raid_submit_process_request(struct raid_bdev_process_request *process_req,
			       struct raid_bdev_io_channel *raid_ch)
{
	struct raid_bdev *raid_bdev = spdk_io_channel_get_io_device(spdk_io_channel_from_ctx(raid_ch));

	*(uint64_t *)raid_bdev->module_private += process_req->num_blocks;

	spdk_thread_send_msg(spdk_get_thread(), ut_raid_complete_process_request, process_req);

	return process_req->num_blocks;
}

static struct raid_bdev_module g_ut_raid_module = {
	.level = 123,
	.base_bdevs_min = 1,
	.start = ut_raid_start,
	.submit_rw_request = ut_raid_submit_rw_request,
	.submit_null_payload_request = ut_raid_submit_null_payload_request,
	.submit_process_request = ut_raid_submit_process_request,
};
RAID_MODULE_REGISTER(&g_ut_raid_module)

DEFINE_STUB_V(spdk_bdev_module_examine_done, (struct spdk_bdev_module *module));
DEFINE_STUB_V(spdk_bdev_module_list_add, (struct spdk_bdev_module *bdev_module));
DEFINE_STUB(spdk_bdev_io_type_supported, bool, (struct spdk_bdev *bdev,
		enum spdk_bdev_io_type io_type), true);
DEFINE_STUB_V(spdk_bdev_close, (struct spdk_bdev_desc *desc));
DEFINE_STUB(spdk_bdev_flush_blocks, int, (struct spdk_bdev_desc *desc, struct spdk_io_channel *ch,
		uint64_t offset_blocks, uint64_t num_blocks, spdk_bdev_io_completion_cb cb,
		void *cb_arg), 0);
DEFINE_STUB_V(spdk_rpc_register_method, (const char *method, spdk_rpc_method_handler func,
		uint32_t state_mask));
DEFINE_STUB_V(spdk_jsonrpc_end_result, (struct spdk_jsonrpc_request *request,
					struct spdk_json_write_ctx *w));
DEFINE_STUB_V(spdk_jsonrpc_send_bool_response, (struct spdk_jsonrpc_request *request,
		bool value));
DEFINE_STUB(spdk_json_decode_string, int, (const struct spdk_json_val *val, void *out), 0);
DEFINE_STUB(spdk_json_decode_uint32, int, (const struct spdk_json_val *val, void *out), 0);
DEFINE_STUB(spdk_json_decode_uuid, int, (const struct spdk_json_val *val, void *out), 0);
DEFINE_STUB(spdk_json_decode_array, int, (const struct spdk_json_val *values,
		spdk_json_decode_fn decode_func,
		void *out, size_t max_size, size_t *out_size, size_t stride), 0);
DEFINE_STUB(spdk_json_decode_bool, int, (const struct spdk_json_val *val, void *out), 0);
DEFINE_STUB(spdk_json_write_name, int, (struct spdk_json_write_ctx *w, const char *name), 0);
DEFINE_STUB(spdk_json_write_object_begin, int, (struct spdk_json_write_ctx *w), 0);
DEFINE_STUB(spdk_json_write_named_object_begin, int, (struct spdk_json_write_ctx *w,
		const char *name), 0);
DEFINE_STUB(spdk_json_write_string, int, (struct spdk_json_write_ctx *w, const char *val), 0);
DEFINE_STUB(spdk_json_write_object_end, int, (struct spdk_json_write_ctx *w), 0);
DEFINE_STUB(spdk_json_write_array_begin, int, (struct spdk_json_write_ctx *w), 0);
DEFINE_STUB(spdk_json_write_array_end, int, (struct spdk_json_write_ctx *w), 0);
DEFINE_STUB(spdk_json_write_named_array_begin, int, (struct spdk_json_write_ctx *w,
		const char *name), 0);
DEFINE_STUB(spdk_json_write_null, int, (struct spdk_json_write_ctx *w), 0);
DEFINE_STUB(spdk_json_write_named_uint64, int, (struct spdk_json_write_ctx *w, const char *name,
		uint64_t val), 0);
DEFINE_STUB(spdk_strerror, const char *, (int errnum), NULL);
DEFINE_STUB(spdk_bdev_queue_io_wait, int, (struct spdk_bdev *bdev, struct spdk_io_channel *ch,
		struct spdk_bdev_io_wait_entry *entry), 0);
DEFINE_STUB(spdk_bdev_get_memory_domains, int, (struct spdk_bdev *bdev,
		struct spdk_memory_domain **domains,	int array_size), 0);
DEFINE_STUB(spdk_bdev_get_name, const char *, (const struct spdk_bdev *bdev), "test_bdev");
DEFINE_STUB(spdk_bdev_get_md_size, uint32_t, (const struct spdk_bdev *bdev), MD_SIZE);
DEFINE_STUB(spdk_bdev_is_md_interleaved, bool, (const struct spdk_bdev *bdev), false);
DEFINE_STUB(spdk_bdev_is_md_separate, bool, (const struct spdk_bdev *bdev), true);
DEFINE_STUB(spdk_bdev_get_dif_type, enum spdk_dif_type, (const struct spdk_bdev *bdev),
	    SPDK_DIF_DISABLE);
DEFINE_STUB(spdk_bdev_is_dif_head_of_md, bool, (const struct spdk_bdev *bdev), false);
DEFINE_STUB(spdk_bdev_notify_blockcnt_change, int, (struct spdk_bdev *bdev, uint64_t size), 0);
DEFINE_STUB(spdk_json_write_named_uuid, int, (struct spdk_json_write_ctx *w, const char *name,
		const struct spdk_uuid *val), 0);
DEFINE_STUB_V(raid_bdev_init_superblock, (struct raid_bdev *raid_bdev));
DEFINE_STUB(raid_bdev_alloc_superblock, int, (struct raid_bdev *raid_bdev, uint32_t block_size), 0);
DEFINE_STUB_V(raid_bdev_free_superblock, (struct raid_bdev *raid_bdev));
DEFINE_STUB(spdk_bdev_readv_blocks_ext, int, (struct spdk_bdev_desc *desc,
		struct spdk_io_channel *ch, struct iovec *iov, int iovcnt, uint64_t offset_blocks,
		uint64_t num_blocks, spdk_bdev_io_completion_cb cb, void *cb_arg,
		struct spdk_bdev_ext_io_opts *opts), 0);
DEFINE_STUB(spdk_bdev_writev_blocks_ext, int, (struct spdk_bdev_desc *desc,
		struct spdk_io_channel *ch, struct iovec *iov, int iovcnt, uint64_t offset_blocks,
		uint64_t num_blocks, spdk_bdev_io_completion_cb cb, void *cb_arg,
		struct spdk_bdev_ext_io_opts *opts), 0);

uint32_t
spdk_bdev_get_data_block_size(const struct spdk_bdev *bdev)
{
	return g_block_len;
}

int
raid_bdev_load_base_bdev_superblock(struct spdk_bdev_desc *desc, struct spdk_io_channel *ch,
				    raid_bdev_load_sb_cb cb, void *cb_ctx)
{
	cb(NULL, -EINVAL, cb_ctx);

	return 0;
}

void
raid_bdev_write_superblock(struct raid_bdev *raid_bdev, raid_bdev_write_sb_cb cb, void *cb_ctx)
{
	cb(0, raid_bdev, cb_ctx);
}

const struct spdk_uuid *
spdk_bdev_get_uuid(const struct spdk_bdev *bdev)
{
	return &bdev->uuid;
}

struct spdk_io_channel *
spdk_bdev_get_io_channel(struct spdk_bdev_desc *desc)
{
	return spdk_get_io_channel(&g_bdev_ch_io_device);
}

static int
set_test_opts(void)
{
	g_max_base_drives = MAX_BASE_DRIVES;
	g_max_raids = MAX_RAIDS;
	g_block_len = 4096;
	g_strip_size = 64;
	g_max_io_size = 1024;

	printf("Test Options\n");
	printf("blocklen = %u, strip_size = %u, max_io_size = %u, g_max_base_drives = %u, "
	       "g_max_raids = %u\n",
	       g_block_len, g_strip_size, g_max_io_size, g_max_base_drives, g_max_raids);

	return 0;
}

/* Set globals before every test run */
static void
set_globals(void)
{
	uint32_t max_splits;

	if (g_max_io_size < g_strip_size) {
		max_splits = 2;
	} else {
		max_splits = (g_max_io_size / g_strip_size) + 1;
	}
	if (max_splits < g_max_base_drives) {
		max_splits = g_max_base_drives;
	}

	g_io_output = calloc(max_splits, sizeof(struct io_output));
	SPDK_CU_ASSERT_FATAL(g_io_output != NULL);
	g_io_output_index = 0;
	memset(g_get_raids_output, 0, sizeof(g_get_raids_output));
	g_get_raids_count = 0;
	g_io_comp_status = 0;
	g_rpc_err = 0;
	g_test_multi_raids = 0;
	g_child_io_status_flag = true;
	TAILQ_INIT(&g_bdev_list);
	g_rpc_req = NULL;
	g_rpc_req_size = 0;
	g_json_decode_obj_err = 0;
	g_json_decode_obj_create = 0;
	g_bdev_io_defer_completion = false;
}

static void
base_bdevs_cleanup(void)
{
	struct spdk_bdev *bdev;
	struct spdk_bdev *bdev_next;

	if (!TAILQ_EMPTY(&g_bdev_list)) {
		TAILQ_FOREACH_SAFE(bdev, &g_bdev_list, internal.link, bdev_next) {
			free(bdev->name);
			TAILQ_REMOVE(&g_bdev_list, bdev, internal.link);
			free(bdev);
		}
	}
}

static void
check_and_remove_raid_bdev(struct raid_bdev *raid_bdev)
{
	struct raid_base_bdev_info *base_info;

	assert(raid_bdev != NULL);
	assert(raid_bdev->base_bdev_info != NULL);

	RAID_FOR_EACH_BASE_BDEV(raid_bdev, base_info) {
		if (base_info->desc) {
			raid_bdev_free_base_bdev_resource(base_info);
		}
	}
	assert(raid_bdev->num_base_bdevs_discovered == 0);
	raid_bdev_cleanup_and_free(raid_bdev);
}

/* Reset globals */
static void
reset_globals(void)
{
	if (g_io_output) {
		free(g_io_output);
		g_io_output = NULL;
	}
	g_rpc_req = NULL;
	g_rpc_req_size = 0;
}

void
spdk_bdev_io_get_buf(struct spdk_bdev_io *bdev_io, spdk_bdev_io_get_buf_cb cb,
		     uint64_t len)
{
	cb(bdev_io->internal.ch->channel, bdev_io, true);
}

/* Store the IO completion status in global variable to verify by various tests */
void
spdk_bdev_io_complete(struct spdk_bdev_io *bdev_io, enum spdk_bdev_io_status status)
{
	g_io_comp_status = ((status == SPDK_BDEV_IO_STATUS_SUCCESS) ? true : false);
}

static void
complete_deferred_ios(void)
{
	struct spdk_bdev_io *child_io, *tmp;

	TAILQ_FOREACH_SAFE(child_io, &g_deferred_ios, internal.link, tmp) {
		TAILQ_REMOVE(&g_deferred_ios, child_io, internal.link);
		child_io->internal.cb(child_io, g_child_io_status_flag, child_io->internal.caller_ctx);
	}
}

int
spdk_bdev_reset(struct spdk_bdev_desc *desc, struct spdk_io_channel *ch,
		spdk_bdev_io_completion_cb cb, void *cb_arg)
{
	struct io_output *output = &g_io_output[g_io_output_index];
	struct spdk_bdev_io *child_io;

	output->desc = desc;
	output->ch = ch;
	output->iotype = SPDK_BDEV_IO_TYPE_RESET;

	g_io_output_index++;

	child_io = calloc(1, sizeof(struct spdk_bdev_io));
	SPDK_CU_ASSERT_FATAL(child_io != NULL);
	cb(child_io, g_child_io_status_flag, cb_arg);

	return 0;
}

void
spdk_bdev_destruct_done(struct spdk_bdev *bdev, int bdeverrno)
{
	CU_ASSERT(bdeverrno == 0);
	SPDK_CU_ASSERT_FATAL(bdev->internal.unregister_cb != NULL);
	bdev->internal.unregister_cb(bdev->internal.unregister_ctx, bdeverrno);
}

int
spdk_bdev_register(struct spdk_bdev *bdev)
{
	TAILQ_INSERT_TAIL(&g_bdev_list, bdev, internal.link);
	return 0;
}

static void
poll_app_thread(void)
{
	while (spdk_thread_poll(g_app_thread, 0, 0) > 0) {
	}
}

void
spdk_bdev_unregister(struct spdk_bdev *bdev, spdk_bdev_unregister_cb cb_fn, void *cb_arg)
{
	int ret;

	SPDK_CU_ASSERT_FATAL(spdk_bdev_get_by_name(bdev->name) == bdev);
	TAILQ_REMOVE(&g_bdev_list, bdev, internal.link);

	bdev->internal.unregister_cb = cb_fn;
	bdev->internal.unregister_ctx = cb_arg;

	ret = bdev->fn_table->destruct(bdev->ctxt);
	CU_ASSERT(ret == 1);

	poll_app_thread();
}

int
spdk_bdev_open_ext(const char *bdev_name, bool write, spdk_bdev_event_cb_t event_cb,
		   void *event_ctx, struct spdk_bdev_desc **_desc)
{
	struct spdk_bdev *bdev;

	bdev = spdk_bdev_get_by_name(bdev_name);
	if (bdev == NULL) {
		return -ENODEV;
	}

	*_desc = (void *)bdev;
	return 0;
}

struct spdk_bdev *
spdk_bdev_desc_get_bdev(struct spdk_bdev_desc *desc)
{
	return (void *)desc;
}

int
spdk_json_write_named_uint32(struct spdk_json_write_ctx *w, const char *name, uint32_t val)
{
	if (!g_test_multi_raids) {
		struct rpc_bdev_raid_create *req = g_rpc_req;
		if (strcmp(name, "strip_size_kb") == 0) {
			CU_ASSERT(req->strip_size_kb == val);
		} else if (strcmp(name, "blocklen_shift") == 0) {
			CU_ASSERT(spdk_u32log2(g_block_len) == val);
		} else if (strcmp(name, "num_base_bdevs") == 0) {
			CU_ASSERT(req->base_bdevs.num_base_bdevs == val);
		} else if (strcmp(name, "state") == 0) {
			CU_ASSERT(val == RAID_BDEV_STATE_ONLINE);
		} else if (strcmp(name, "destruct_called") == 0) {
			CU_ASSERT(val == 0);
		} else if (strcmp(name, "num_base_bdevs_discovered") == 0) {
			CU_ASSERT(req->base_bdevs.num_base_bdevs == val);
		}
	}
	return 0;
}

int
spdk_json_write_named_string(struct spdk_json_write_ctx *w, const char *name, const char *val)
{
	if (g_test_multi_raids) {
		if (strcmp(name, "name") == 0) {
			g_get_raids_output[g_get_raids_count] = strdup(val);
			SPDK_CU_ASSERT_FATAL(g_get_raids_output[g_get_raids_count] != NULL);
			g_get_raids_count++;
		}
	} else {
		struct rpc_bdev_raid_create *req = g_rpc_req;
		if (strcmp(name, "raid_level") == 0) {
			CU_ASSERT(strcmp(val, raid_bdev_level_to_str(req->level)) == 0);
		}
	}
	return 0;
}

int
spdk_json_write_named_bool(struct spdk_json_write_ctx *w, const char *name, bool val)
{
	if (!g_test_multi_raids) {
		struct rpc_bdev_raid_create *req = g_rpc_req;
		if (strcmp(name, "superblock") == 0) {
			CU_ASSERT(val == req->superblock_enabled);
		}
	}
	return 0;
}

void
spdk_bdev_free_io(struct spdk_bdev_io *bdev_io)
{
	if (bdev_io) {
		free(bdev_io);
	}
}

void
spdk_bdev_module_release_bdev(struct spdk_bdev *bdev)
{
	CU_ASSERT(bdev->internal.claim_type == SPDK_BDEV_CLAIM_EXCL_WRITE);
	CU_ASSERT(bdev->internal.claim.v1.module != NULL);
	bdev->internal.claim_type = SPDK_BDEV_CLAIM_NONE;
	bdev->internal.claim.v1.module = NULL;
}

int
spdk_bdev_module_claim_bdev(struct spdk_bdev *bdev, struct spdk_bdev_desc *desc,
			    struct spdk_bdev_module *module)
{
	if (bdev->internal.claim_type != SPDK_BDEV_CLAIM_NONE) {
		CU_ASSERT(bdev->internal.claim.v1.module != NULL);
		return -1;
	}
	CU_ASSERT(bdev->internal.claim.v1.module == NULL);
	bdev->internal.claim_type = SPDK_BDEV_CLAIM_EXCL_WRITE;
	bdev->internal.claim.v1.module = module;
	return 0;
}

int
spdk_json_decode_object(const struct spdk_json_val *values,
			const struct spdk_json_object_decoder *decoders, size_t num_decoders,
			void *out)
{
	struct rpc_bdev_raid_create *req, *_out;
	size_t i;

	if (g_json_decode_obj_err) {
		return -1;
	} else if (g_json_decode_obj_create) {
		req = g_rpc_req;
		_out = out;

		_out->name = strdup(req->name);
		SPDK_CU_ASSERT_FATAL(_out->name != NULL);
		_out->strip_size_kb = req->strip_size_kb;
		_out->level = req->level;
		_out->superblock_enabled = req->superblock_enabled;
		_out->base_bdevs.num_base_bdevs = req->base_bdevs.num_base_bdevs;
		for (i = 0; i < req->base_bdevs.num_base_bdevs; i++) {
			_out->base_bdevs.base_bdevs[i] = strdup(req->base_bdevs.base_bdevs[i]);
			SPDK_CU_ASSERT_FATAL(_out->base_bdevs.base_bdevs[i]);
		}
	} else {
		memcpy(out, g_rpc_req, g_rpc_req_size);
	}

	return 0;
}

struct spdk_json_write_ctx *
spdk_jsonrpc_begin_result(struct spdk_jsonrpc_request *request)
{
	return (void *)1;
}

void
spdk_jsonrpc_send_error_response(struct spdk_jsonrpc_request *request,
				 int error_code, const char *msg)
{
	g_rpc_err = 1;
}

void
spdk_jsonrpc_send_error_response_fmt(struct spdk_jsonrpc_request *request,
				     int error_code, const char *fmt, ...)
{
	g_rpc_err = 1;
}

struct spdk_bdev *
spdk_bdev_get_by_name(const char *bdev_name)
{
	struct spdk_bdev *bdev;

	if (!TAILQ_EMPTY(&g_bdev_list)) {
		TAILQ_FOREACH(bdev, &g_bdev_list, internal.link) {
			if (strcmp(bdev_name, bdev->name) == 0) {
				return bdev;
			}
		}
	}

	return NULL;
}

int
spdk_bdev_quiesce(struct spdk_bdev *bdev, struct spdk_bdev_module *module,
		  spdk_bdev_quiesce_cb cb_fn, void *cb_arg)
{
	if (cb_fn) {
		cb_fn(cb_arg, 0);
	}

	return 0;
}

int
spdk_bdev_unquiesce(struct spdk_bdev *bdev, struct spdk_bdev_module *module,
		    spdk_bdev_quiesce_cb cb_fn, void *cb_arg)
{
	if (cb_fn) {
		cb_fn(cb_arg, 0);
	}

	return 0;
}

int
spdk_bdev_quiesce_range(struct spdk_bdev *bdev, struct spdk_bdev_module *module,
			uint64_t offset, uint64_t length,
			spdk_bdev_quiesce_cb cb_fn, void *cb_arg)
{
	if (cb_fn) {
		cb_fn(cb_arg, 0);
	}

	return 0;
}

int
spdk_bdev_unquiesce_range(struct spdk_bdev *bdev, struct spdk_bdev_module *module,
			  uint64_t offset, uint64_t length,
			  spdk_bdev_quiesce_cb cb_fn, void *cb_arg)
{
	if (cb_fn) {
		cb_fn(cb_arg, 0);
	}

	return 0;
}

static void
bdev_io_cleanup(struct spdk_bdev_io *bdev_io)
{
	if (bdev_io->u.bdev.iovs) {
		int i;

		for (i = 0; i < bdev_io->u.bdev.iovcnt; i++) {
			free(bdev_io->u.bdev.iovs[i].iov_base);
		}
		free(bdev_io->u.bdev.iovs);
	}

	free(bdev_io);
}

static void
_bdev_io_initialize(struct spdk_bdev_io *bdev_io, struct spdk_io_channel *ch,
		    struct spdk_bdev *bdev, uint64_t lba, uint64_t blocks, int16_t iotype,
		    int iovcnt, size_t iov_len)
{
	struct spdk_bdev_channel *channel = spdk_io_channel_get_ctx(ch);
	int i;

	bdev_io->bdev = bdev;
	bdev_io->u.bdev.offset_blocks = lba;
	bdev_io->u.bdev.num_blocks = blocks;
	bdev_io->type = iotype;
	bdev_io->internal.ch = channel;
	bdev_io->u.bdev.iovcnt = iovcnt;

	if (iovcnt == 0) {
		bdev_io->u.bdev.iovs = NULL;
		return;
	}

	SPDK_CU_ASSERT_FATAL(iov_len * iovcnt == blocks * g_block_len);

	bdev_io->u.bdev.iovs = calloc(iovcnt, sizeof(struct iovec));
	SPDK_CU_ASSERT_FATAL(bdev_io->u.bdev.iovs != NULL);

	for (i = 0; i < iovcnt; i++) {
		struct iovec *iov = &bdev_io->u.bdev.iovs[i];

		iov->iov_base = calloc(1, iov_len);
		SPDK_CU_ASSERT_FATAL(iov->iov_base != NULL);
		iov->iov_len = iov_len;
	}

	bdev_io->u.bdev.md_buf = (void *)0x10000000;
}

static void
bdev_io_initialize(struct spdk_bdev_io *bdev_io, struct spdk_io_channel *ch, struct spdk_bdev *bdev,
		   uint64_t lba, uint64_t blocks, int16_t iotype)
{
	_bdev_io_initialize(bdev_io, ch, bdev, lba, blocks, iotype, 0, 0);
}

static void
verify_reset_io(struct spdk_bdev_io *bdev_io, uint8_t num_base_drives,
		struct raid_bdev_io_channel *ch_ctx, struct raid_bdev *raid_bdev, uint32_t io_status)
{
	uint8_t index = 0;
	struct io_output *output;

	SPDK_CU_ASSERT_FATAL(raid_bdev != NULL);
	SPDK_CU_ASSERT_FATAL(num_base_drives != 0);
	SPDK_CU_ASSERT_FATAL(ch_ctx->base_channel != NULL);

	CU_ASSERT(g_io_output_index == num_base_drives);
	for (index = 0; index < g_io_output_index; index++) {
		output = &g_io_output[index];
		CU_ASSERT(ch_ctx->base_channel[index] == output->ch);
		CU_ASSERT(raid_bdev->base_bdev_info[index].desc == output->desc);
		CU_ASSERT(bdev_io->type == output->iotype);
	}
	CU_ASSERT(g_io_comp_status == io_status);
}

static void
verify_raid_bdev_present(const char *name, bool presence)
{
	struct raid_bdev *pbdev;
	bool   pbdev_found;

	pbdev_found = false;
	TAILQ_FOREACH(pbdev, &g_raid_bdev_list, global_link) {
		if (strcmp(pbdev->bdev.name, name) == 0) {
			pbdev_found = true;
			break;
		}
	}
	if (presence == true) {
		CU_ASSERT(pbdev_found == true);
	} else {
		CU_ASSERT(pbdev_found == false);
	}
}

static void
verify_raid_bdev(struct rpc_bdev_raid_create *r, bool presence, uint32_t raid_state)
{
	struct raid_bdev *pbdev;
	struct raid_base_bdev_info *base_info;
	struct spdk_bdev *bdev = NULL;
	bool   pbdev_found;
	uint64_t min_blockcnt = 0xFFFFFFFFFFFFFFFF;

	pbdev_found = false;
	TAILQ_FOREACH(pbdev, &g_raid_bdev_list, global_link) {
		if (strcmp(pbdev->bdev.name, r->name) == 0) {
			pbdev_found = true;
			if (presence == false) {
				break;
			}
			CU_ASSERT(pbdev->base_bdev_info != NULL);
			CU_ASSERT(pbdev->strip_size == ((r->strip_size_kb * 1024) / g_block_len));
			CU_ASSERT(pbdev->strip_size_shift == spdk_u32log2(((r->strip_size_kb * 1024) /
					g_block_len)));
			CU_ASSERT((uint32_t)pbdev->state == raid_state);
			CU_ASSERT(pbdev->num_base_bdevs == r->base_bdevs.num_base_bdevs);
			CU_ASSERT(pbdev->num_base_bdevs_discovered == r->base_bdevs.num_base_bdevs);
			CU_ASSERT(pbdev->level == r->level);
			CU_ASSERT(pbdev->base_bdev_info != NULL);
			RAID_FOR_EACH_BASE_BDEV(pbdev, base_info) {
				CU_ASSERT(base_info->desc != NULL);
				bdev = spdk_bdev_desc_get_bdev(base_info->desc);
				CU_ASSERT(bdev != NULL);
				CU_ASSERT(base_info->remove_scheduled == false);
				CU_ASSERT((pbdev->superblock_enabled && base_info->data_offset != 0) ||
					  (!pbdev->superblock_enabled && base_info->data_offset == 0));
				CU_ASSERT(base_info->data_offset + base_info->data_size == bdev->blockcnt);

				if (bdev && base_info->data_size < min_blockcnt) {
					min_blockcnt = base_info->data_size;
				}
			}
			CU_ASSERT(strcmp(pbdev->bdev.product_name, "Raid Volume") == 0);
			CU_ASSERT(pbdev->bdev.write_cache == 0);
			CU_ASSERT(pbdev->bdev.blocklen == g_block_len);
			CU_ASSERT(pbdev->bdev.ctxt == pbdev);
			CU_ASSERT(pbdev->bdev.fn_table == &g_raid_bdev_fn_table);
			CU_ASSERT(pbdev->bdev.module == &g_raid_if);
			break;
		}
	}
	if (presence == true) {
		CU_ASSERT(pbdev_found == true);
	} else {
		CU_ASSERT(pbdev_found == false);
	}
}

static void
verify_get_raids(struct rpc_bdev_raid_create *construct_req,
		 uint8_t g_max_raids,
		 char **g_get_raids_output, uint32_t g_get_raids_count)
{
	uint8_t i, j;
	bool found;

	CU_ASSERT(g_max_raids == g_get_raids_count);
	if (g_max_raids == g_get_raids_count) {
		for (i = 0; i < g_max_raids; i++) {
			found = false;
			for (j = 0; j < g_max_raids; j++) {
				if (construct_req[i].name &&
				    strcmp(construct_req[i].name, g_get_raids_output[i]) == 0) {
					found = true;
					break;
				}
			}
			CU_ASSERT(found == true);
		}
	}
}

static void
create_base_bdevs(uint32_t bbdev_start_idx)
{
	uint8_t i;
	struct spdk_bdev *base_bdev;
	char name[16];

	for (i = 0; i < g_max_base_drives; i++, bbdev_start_idx++) {
		snprintf(name, 16, "%s%u%s", "Nvme", bbdev_start_idx, "n1");
		base_bdev = calloc(1, sizeof(struct spdk_bdev));
		SPDK_CU_ASSERT_FATAL(base_bdev != NULL);
		base_bdev->name = strdup(name);
		spdk_uuid_generate(&base_bdev->uuid);
		SPDK_CU_ASSERT_FATAL(base_bdev->name != NULL);
		base_bdev->blocklen = g_block_len;
		base_bdev->blockcnt = BLOCK_CNT;
		TAILQ_INSERT_TAIL(&g_bdev_list, base_bdev, internal.link);
	}
}

static void
create_test_req(struct rpc_bdev_raid_create *r, const char *raid_name,
		uint8_t bbdev_start_idx, bool create_base_bdev, bool superblock_enabled)
{
	uint8_t i;
	char name[16];
	uint8_t bbdev_idx = bbdev_start_idx;

	r->name = strdup(raid_name);
	SPDK_CU_ASSERT_FATAL(r->name != NULL);
	r->strip_size_kb = (g_strip_size * g_block_len) / 1024;
	r->level = 123;
	r->superblock_enabled = superblock_enabled;
	r->base_bdevs.num_base_bdevs = g_max_base_drives;
	for (i = 0; i < g_max_base_drives; i++, bbdev_idx++) {
		snprintf(name, 16, "%s%u%s", "Nvme", bbdev_idx, "n1");
		r->base_bdevs.base_bdevs[i] = strdup(name);
		SPDK_CU_ASSERT_FATAL(r->base_bdevs.base_bdevs[i] != NULL);
	}
	if (create_base_bdev == true) {
		create_base_bdevs(bbdev_start_idx);
	}
	g_rpc_req = r;
	g_rpc_req_size = sizeof(*r);
}

static void
create_raid_bdev_create_req(struct rpc_bdev_raid_create *r, const char *raid_name,
			    uint8_t bbdev_start_idx, bool create_base_bdev,
			    uint8_t json_decode_obj_err, bool superblock_enabled)
{
	create_test_req(r, raid_name, bbdev_start_idx, create_base_bdev, superblock_enabled);

	g_rpc_err = 0;
	g_json_decode_obj_create = 1;
	g_json_decode_obj_err = json_decode_obj_err;
	g_test_multi_raids = 0;
}

static void
free_test_req(struct rpc_bdev_raid_create *r)
{
	uint8_t i;

	free(r->name);
	for (i = 0; i < r->base_bdevs.num_base_bdevs; i++) {
		free(r->base_bdevs.base_bdevs[i]);
	}
}

static void
create_raid_bdev_delete_req(struct rpc_bdev_raid_delete *r, const char *raid_name,
			    uint8_t json_decode_obj_err)
{
	r->name = strdup(raid_name);
	SPDK_CU_ASSERT_FATAL(r->name != NULL);

	g_rpc_req = r;
	g_rpc_req_size = sizeof(*r);
	g_rpc_err = 0;
	g_json_decode_obj_create = 0;
	g_json_decode_obj_err = json_decode_obj_err;
	g_test_multi_raids = 0;
}

static void
create_get_raids_req(struct rpc_bdev_raid_get_bdevs *r, const char *category,
		     uint8_t json_decode_obj_err)
{
	r->category = strdup(category);
	SPDK_CU_ASSERT_FATAL(r->category != NULL);

	g_rpc_req = r;
	g_rpc_req_size = sizeof(*r);
	g_rpc_err = 0;
	g_json_decode_obj_create = 0;
	g_json_decode_obj_err = json_decode_obj_err;
	g_test_multi_raids = 1;
	g_get_raids_count = 0;
}

static void
test_create_raid(void)
{
	struct rpc_bdev_raid_create req;
	struct rpc_bdev_raid_delete delete_req;

	set_globals();
	CU_ASSERT(raid_bdev_init() == 0);

	verify_raid_bdev_present("raid1", false);
	create_raid_bdev_create_req(&req, "raid1", 0, true, 0, false);
	rpc_bdev_raid_create(NULL, NULL);
	CU_ASSERT(g_rpc_err == 0);
	verify_raid_bdev(&req, true, RAID_BDEV_STATE_ONLINE);
	free_test_req(&req);

	create_raid_bdev_delete_req(&delete_req, "raid1", 0);
	rpc_bdev_raid_delete(NULL, NULL);
	CU_ASSERT(g_rpc_err == 0);
	raid_bdev_exit();
	base_bdevs_cleanup();
	reset_globals();
}

static void
test_delete_raid(void)
{
	struct rpc_bdev_raid_create construct_req;
	struct rpc_bdev_raid_delete delete_req;

	set_globals();
	CU_ASSERT(raid_bdev_init() == 0);

	verify_raid_bdev_present("raid1", false);
	create_raid_bdev_create_req(&construct_req, "raid1", 0, true, 0, false);
	rpc_bdev_raid_create(NULL, NULL);
	CU_ASSERT(g_rpc_err == 0);
	verify_raid_bdev(&construct_req, true, RAID_BDEV_STATE_ONLINE);
	free_test_req(&construct_req);

	create_raid_bdev_delete_req(&delete_req, "raid1", 0);
	rpc_bdev_raid_delete(NULL, NULL);
	CU_ASSERT(g_rpc_err == 0);
	verify_raid_bdev_present("raid1", false);

	raid_bdev_exit();
	base_bdevs_cleanup();
	reset_globals();
}

static void
test_create_raid_invalid_args(void)
{
	struct rpc_bdev_raid_create req;
	struct rpc_bdev_raid_delete destroy_req;
	struct raid_bdev *raid_bdev;

	set_globals();
	CU_ASSERT(raid_bdev_init() == 0);

	verify_raid_bdev_present("raid1", false);
	create_raid_bdev_create_req(&req, "raid1", 0, true, 0, false);
	req.level = INVALID_RAID_LEVEL;
	rpc_bdev_raid_create(NULL, NULL);
	CU_ASSERT(g_rpc_err == 1);
	free_test_req(&req);
	verify_raid_bdev_present("raid1", false);

	create_raid_bdev_create_req(&req, "raid1", 0, false, 1, false);
	rpc_bdev_raid_create(NULL, NULL);
	CU_ASSERT(g_rpc_err == 1);
	free_test_req(&req);
	verify_raid_bdev_present("raid1", false);

	create_raid_bdev_create_req(&req, "raid1", 0, false, 0, false);
	req.strip_size_kb = 1231;
	rpc_bdev_raid_create(NULL, NULL);
	CU_ASSERT(g_rpc_err == 1);
	free_test_req(&req);
	verify_raid_bdev_present("raid1", false);

	create_raid_bdev_create_req(&req, "raid1", 0, false, 0, false);
	rpc_bdev_raid_create(NULL, NULL);
	CU_ASSERT(g_rpc_err == 0);
	verify_raid_bdev(&req, true, RAID_BDEV_STATE_ONLINE);
	free_test_req(&req);

	create_raid_bdev_create_req(&req, "raid1", 0, false, 0, false);
	rpc_bdev_raid_create(NULL, NULL);
	CU_ASSERT(g_rpc_err == 1);
	free_test_req(&req);

	create_raid_bdev_create_req(&req, "raid2", 0, false, 0, false);
	rpc_bdev_raid_create(NULL, NULL);
	CU_ASSERT(g_rpc_err == 1);
	free_test_req(&req);
	verify_raid_bdev_present("raid2", false);

	create_raid_bdev_create_req(&req, "raid2", g_max_base_drives, true, 0, false);
	free(req.base_bdevs.base_bdevs[g_max_base_drives - 1]);
	req.base_bdevs.base_bdevs[g_max_base_drives - 1] = strdup("Nvme0n1");
	SPDK_CU_ASSERT_FATAL(req.base_bdevs.base_bdevs[g_max_base_drives - 1] != NULL);
	rpc_bdev_raid_create(NULL, NULL);
	CU_ASSERT(g_rpc_err == 1);
	free_test_req(&req);
	verify_raid_bdev_present("raid2", false);

	create_raid_bdev_create_req(&req, "raid2", g_max_base_drives, true, 0, false);
	free(req.base_bdevs.base_bdevs[g_max_base_drives - 1]);
	req.base_bdevs.base_bdevs[g_max_base_drives - 1] = strdup("Nvme100000n1");
	SPDK_CU_ASSERT_FATAL(req.base_bdevs.base_bdevs[g_max_base_drives - 1] != NULL);
	rpc_bdev_raid_create(NULL, NULL);
	CU_ASSERT(g_rpc_err == 0);
	free_test_req(&req);
	verify_raid_bdev_present("raid2", true);
	raid_bdev = raid_bdev_find_by_name("raid2");
	SPDK_CU_ASSERT_FATAL(raid_bdev != NULL);
	check_and_remove_raid_bdev(raid_bdev);

	create_raid_bdev_create_req(&req, "raid2", g_max_base_drives, false, 0, false);
	rpc_bdev_raid_create(NULL, NULL);
	CU_ASSERT(g_rpc_err == 0);
	free_test_req(&req);
	verify_raid_bdev_present("raid2", true);
	verify_raid_bdev_present("raid1", true);

	create_raid_bdev_delete_req(&destroy_req, "raid1", 0);
	rpc_bdev_raid_delete(NULL, NULL);
	create_raid_bdev_delete_req(&destroy_req, "raid2", 0);
	rpc_bdev_raid_delete(NULL, NULL);
	raid_bdev_exit();
	base_bdevs_cleanup();
	reset_globals();
}

static void
test_delete_raid_invalid_args(void)
{
	struct rpc_bdev_raid_create construct_req;
	struct rpc_bdev_raid_delete destroy_req;

	set_globals();
	CU_ASSERT(raid_bdev_init() == 0);

	verify_raid_bdev_present("raid1", false);
	create_raid_bdev_create_req(&construct_req, "raid1", 0, true, 0, false);
	rpc_bdev_raid_create(NULL, NULL);
	CU_ASSERT(g_rpc_err == 0);
	verify_raid_bdev(&construct_req, true, RAID_BDEV_STATE_ONLINE);
	free_test_req(&construct_req);

	create_raid_bdev_delete_req(&destroy_req, "raid2", 0);
	rpc_bdev_raid_delete(NULL, NULL);
	CU_ASSERT(g_rpc_err == 1);

	create_raid_bdev_delete_req(&destroy_req, "raid1", 1);
	rpc_bdev_raid_delete(NULL, NULL);
	CU_ASSERT(g_rpc_err == 1);
	free(destroy_req.name);
	verify_raid_bdev_present("raid1", true);

	create_raid_bdev_delete_req(&destroy_req, "raid1", 0);
	rpc_bdev_raid_delete(NULL, NULL);
	CU_ASSERT(g_rpc_err == 0);
	verify_raid_bdev_present("raid1", false);

	raid_bdev_exit();
	base_bdevs_cleanup();
	reset_globals();
}

static void
test_io_channel(void)
{
	struct rpc_bdev_raid_create req;
	struct rpc_bdev_raid_delete destroy_req;
	struct raid_bdev *pbdev;
	struct spdk_io_channel *ch;
	struct raid_bdev_io_channel *ch_ctx;

	set_globals();
	CU_ASSERT(raid_bdev_init() == 0);

	create_raid_bdev_create_req(&req, "raid1", 0, true, 0, false);
	verify_raid_bdev_present("raid1", false);
	rpc_bdev_raid_create(NULL, NULL);
	CU_ASSERT(g_rpc_err == 0);
	verify_raid_bdev(&req, true, RAID_BDEV_STATE_ONLINE);

	TAILQ_FOREACH(pbdev, &g_raid_bdev_list, global_link) {
		if (strcmp(pbdev->bdev.name, "raid1") == 0) {
			break;
		}
	}
	CU_ASSERT(pbdev != NULL);

	ch = spdk_get_io_channel(pbdev);
	SPDK_CU_ASSERT_FATAL(ch != NULL);

	ch_ctx = spdk_io_channel_get_ctx(ch);
	SPDK_CU_ASSERT_FATAL(ch_ctx != NULL);

	free_test_req(&req);

	spdk_put_io_channel(ch);

	create_raid_bdev_delete_req(&destroy_req, "raid1", 0);
	rpc_bdev_raid_delete(NULL, NULL);
	CU_ASSERT(g_rpc_err == 0);
	verify_raid_bdev_present("raid1", false);

	raid_bdev_exit();
	base_bdevs_cleanup();
	reset_globals();
}

/* Test reset IO */
static void
test_reset_io(void)
{
	struct rpc_bdev_raid_create req;
	struct rpc_bdev_raid_delete destroy_req;
	struct raid_bdev *pbdev;
	struct spdk_io_channel *ch;
	struct raid_bdev_io_channel *ch_ctx;
	struct spdk_bdev_io *bdev_io;

	set_globals();
	CU_ASSERT(raid_bdev_init() == 0);

	verify_raid_bdev_present("raid1", false);
	create_raid_bdev_create_req(&req, "raid1", 0, true, 0, false);
	rpc_bdev_raid_create(NULL, NULL);
	CU_ASSERT(g_rpc_err == 0);
	verify_raid_bdev(&req, true, RAID_BDEV_STATE_ONLINE);
	TAILQ_FOREACH(pbdev, &g_raid_bdev_list, global_link) {
		if (strcmp(pbdev->bdev.name, "raid1") == 0) {
			break;
		}
	}
	CU_ASSERT(pbdev != NULL);

	ch = spdk_get_io_channel(pbdev);
	SPDK_CU_ASSERT_FATAL(ch != NULL);

	ch_ctx = spdk_io_channel_get_ctx(ch);
	SPDK_CU_ASSERT_FATAL(ch_ctx != NULL);

	g_child_io_status_flag = true;

	CU_ASSERT(raid_bdev_io_type_supported(pbdev, SPDK_BDEV_IO_TYPE_RESET) == true);

	bdev_io = calloc(1, sizeof(struct spdk_bdev_io) + sizeof(struct raid_bdev_io));
	SPDK_CU_ASSERT_FATAL(bdev_io != NULL);
	bdev_io_initialize(bdev_io, ch, &pbdev->bdev, 0, 1, SPDK_BDEV_IO_TYPE_RESET);
	memset(g_io_output, 0, g_max_base_drives * sizeof(struct io_output));
	g_io_output_index = 0;
	raid_bdev_submit_request(ch, bdev_io);
	verify_reset_io(bdev_io, req.base_bdevs.num_base_bdevs, ch_ctx, pbdev,
			true);
	bdev_io_cleanup(bdev_io);

	free_test_req(&req);
	spdk_put_io_channel(ch);
	create_raid_bdev_delete_req(&destroy_req, "raid1", 0);
	rpc_bdev_raid_delete(NULL, NULL);
	CU_ASSERT(g_rpc_err == 0);
	verify_raid_bdev_present("raid1", false);

	raid_bdev_exit();
	base_bdevs_cleanup();
	reset_globals();
}

/* Create multiple raids, destroy raids without IO, get_raids related tests */
static void
test_multi_raid(void)
{
	struct rpc_bdev_raid_create *construct_req;
	struct rpc_bdev_raid_delete destroy_req;
	struct rpc_bdev_raid_get_bdevs get_raids_req;
	uint8_t i;
	char name[16];
	uint8_t bbdev_idx = 0;

	set_globals();
	construct_req = calloc(MAX_RAIDS, sizeof(struct rpc_bdev_raid_create));
	SPDK_CU_ASSERT_FATAL(construct_req != NULL);
	CU_ASSERT(raid_bdev_init() == 0);
	for (i = 0; i < g_max_raids; i++) {
		snprintf(name, 16, "%s%u", "raid", i);
		verify_raid_bdev_present(name, false);
		create_raid_bdev_create_req(&construct_req[i], name, bbdev_idx, true, 0, false);
		bbdev_idx += g_max_base_drives;
		rpc_bdev_raid_create(NULL, NULL);
		CU_ASSERT(g_rpc_err == 0);
		verify_raid_bdev(&construct_req[i], true, RAID_BDEV_STATE_ONLINE);
	}

	create_get_raids_req(&get_raids_req, "all", 0);
	rpc_bdev_raid_get_bdevs(NULL, NULL);
	CU_ASSERT(g_rpc_err == 0);
	verify_get_raids(construct_req, g_max_raids, g_get_raids_output, g_get_raids_count);
	for (i = 0; i < g_get_raids_count; i++) {
		free(g_get_raids_output[i]);
	}

	create_get_raids_req(&get_raids_req, "online", 0);
	rpc_bdev_raid_get_bdevs(NULL, NULL);
	CU_ASSERT(g_rpc_err == 0);
	verify_get_raids(construct_req, g_max_raids, g_get_raids_output, g_get_raids_count);
	for (i = 0; i < g_get_raids_count; i++) {
		free(g_get_raids_output[i]);
	}

	create_get_raids_req(&get_raids_req, "configuring", 0);
	rpc_bdev_raid_get_bdevs(NULL, NULL);
	CU_ASSERT(g_rpc_err == 0);
	CU_ASSERT(g_get_raids_count == 0);

	create_get_raids_req(&get_raids_req, "offline", 0);
	rpc_bdev_raid_get_bdevs(NULL, NULL);
	CU_ASSERT(g_rpc_err == 0);
	CU_ASSERT(g_get_raids_count == 0);

	create_get_raids_req(&get_raids_req, "invalid_category", 0);
	rpc_bdev_raid_get_bdevs(NULL, NULL);
	CU_ASSERT(g_rpc_err == 1);
	CU_ASSERT(g_get_raids_count == 0);

	create_get_raids_req(&get_raids_req, "all", 1);
	rpc_bdev_raid_get_bdevs(NULL, NULL);
	CU_ASSERT(g_rpc_err == 1);
	free(get_raids_req.category);
	CU_ASSERT(g_get_raids_count == 0);

	create_get_raids_req(&get_raids_req, "all", 0);
	rpc_bdev_raid_get_bdevs(NULL, NULL);
	CU_ASSERT(g_rpc_err == 0);
	CU_ASSERT(g_get_raids_count == g_max_raids);
	for (i = 0; i < g_get_raids_count; i++) {
		free(g_get_raids_output[i]);
	}

	for (i = 0; i < g_max_raids; i++) {
		SPDK_CU_ASSERT_FATAL(construct_req[i].name != NULL);
		snprintf(name, 16, "%s", construct_req[i].name);
		create_raid_bdev_delete_req(&destroy_req, name, 0);
		rpc_bdev_raid_delete(NULL, NULL);
		CU_ASSERT(g_rpc_err == 0);
		verify_raid_bdev_present(name, false);
	}
	raid_bdev_exit();
	for (i = 0; i < g_max_raids; i++) {
		free_test_req(&construct_req[i]);
	}
	free(construct_req);
	base_bdevs_cleanup();
	reset_globals();
}

static void
test_io_type_supported(void)
{
	CU_ASSERT(raid_bdev_io_type_supported(NULL, SPDK_BDEV_IO_TYPE_READ) == true);
	CU_ASSERT(raid_bdev_io_type_supported(NULL, SPDK_BDEV_IO_TYPE_WRITE) == true);
	CU_ASSERT(raid_bdev_io_type_supported(NULL, SPDK_BDEV_IO_TYPE_INVALID) == false);
}

static void
test_raid_json_dump_info(void)
{
	struct rpc_bdev_raid_create req;
	struct rpc_bdev_raid_delete destroy_req;
	struct raid_bdev *pbdev;

	set_globals();
	CU_ASSERT(raid_bdev_init() == 0);

	verify_raid_bdev_present("raid1", false);
	create_raid_bdev_create_req(&req, "raid1", 0, true, 0, false);
	rpc_bdev_raid_create(NULL, NULL);
	CU_ASSERT(g_rpc_err == 0);
	verify_raid_bdev(&req, true, RAID_BDEV_STATE_ONLINE);

	TAILQ_FOREACH(pbdev, &g_raid_bdev_list, global_link) {
		if (strcmp(pbdev->bdev.name, "raid1") == 0) {
			break;
		}
	}
	CU_ASSERT(pbdev != NULL);

	CU_ASSERT(raid_bdev_dump_info_json(pbdev, NULL) == 0);

	free_test_req(&req);

	create_raid_bdev_delete_req(&destroy_req, "raid1", 0);
	rpc_bdev_raid_delete(NULL, NULL);
	CU_ASSERT(g_rpc_err == 0);
	verify_raid_bdev_present("raid1", false);

	raid_bdev_exit();
	base_bdevs_cleanup();
	reset_globals();
}

static void
test_context_size(void)
{
	CU_ASSERT(raid_bdev_get_ctx_size() == sizeof(struct raid_bdev_io));
}

static void
test_raid_level_conversions(void)
{
	const char *raid_str;

	CU_ASSERT(raid_bdev_str_to_level("abcd123") == INVALID_RAID_LEVEL);
	CU_ASSERT(raid_bdev_str_to_level("0") == RAID0);
	CU_ASSERT(raid_bdev_str_to_level("raid0") == RAID0);
	CU_ASSERT(raid_bdev_str_to_level("RAID0") == RAID0);

	raid_str = raid_bdev_level_to_str(INVALID_RAID_LEVEL);
	CU_ASSERT(raid_str != NULL && strlen(raid_str) == 0);
	raid_str = raid_bdev_level_to_str(1234);
	CU_ASSERT(raid_str != NULL && strlen(raid_str) == 0);
	raid_str = raid_bdev_level_to_str(RAID0);
	CU_ASSERT(raid_str != NULL && strcmp(raid_str, "raid0") == 0);
}

static void
test_create_raid_superblock(void)
{
	struct rpc_bdev_raid_create req;
	struct rpc_bdev_raid_delete delete_req;

	set_globals();
	CU_ASSERT(raid_bdev_init() == 0);

	verify_raid_bdev_present("raid1", false);
	create_raid_bdev_create_req(&req, "raid1", 0, true, 0, true);
	rpc_bdev_raid_create(NULL, NULL);
	CU_ASSERT(g_rpc_err == 0);
	verify_raid_bdev(&req, true, RAID_BDEV_STATE_ONLINE);
	free_test_req(&req);

	create_raid_bdev_delete_req(&delete_req, "raid1", 0);
	rpc_bdev_raid_delete(NULL, NULL);
	CU_ASSERT(g_rpc_err == 0);
	raid_bdev_exit();
	base_bdevs_cleanup();
	reset_globals();
}

static void
test_raid_process(void)
{
	struct rpc_bdev_raid_create req;
	struct rpc_bdev_raid_delete destroy_req;
	struct raid_bdev *pbdev;
	struct spdk_bdev *base_bdev;
	struct spdk_thread *process_thread;
	uint64_t num_blocks_processed = 0;

	set_globals();
	CU_ASSERT(raid_bdev_init() == 0);

	create_raid_bdev_create_req(&req, "raid1", 0, true, 0, false);
	verify_raid_bdev_present("raid1", false);
	TAILQ_FOREACH(base_bdev, &g_bdev_list, internal.link) {
		base_bdev->blockcnt = 128;
	}
	rpc_bdev_raid_create(NULL, NULL);
	CU_ASSERT(g_rpc_err == 0);
	verify_raid_bdev(&req, true, RAID_BDEV_STATE_ONLINE);
	free_test_req(&req);

	TAILQ_FOREACH(pbdev, &g_raid_bdev_list, global_link) {
		if (strcmp(pbdev->bdev.name, "raid1") == 0) {
			break;
		}
	}
	CU_ASSERT(pbdev != NULL);

	pbdev->module_private = &num_blocks_processed;
	pbdev->min_base_bdevs_operational = 0;

	CU_ASSERT(raid_bdev_start_rebuild(&pbdev->base_bdev_info[0]) == 0);
	poll_app_thread();

	SPDK_CU_ASSERT_FATAL(pbdev->process != NULL);

	process_thread = g_latest_thread;
	spdk_thread_poll(process_thread, 0, 0);
	SPDK_CU_ASSERT_FATAL(pbdev->process->thread == process_thread);

	while (spdk_thread_poll(process_thread, 0, 0) > 0) {
		poll_app_thread();
	}

	CU_ASSERT(pbdev->process == NULL);
	CU_ASSERT(num_blocks_processed == pbdev->bdev.blockcnt);

	poll_app_thread();

	create_raid_bdev_delete_req(&destroy_req, "raid1", 0);
	rpc_bdev_raid_delete(NULL, NULL);
	CU_ASSERT(g_rpc_err == 0);
	verify_raid_bdev_present("raid1", false);

	raid_bdev_exit();
	base_bdevs_cleanup();
	reset_globals();
}

static void
test_raid_process_with_qos(void)
{
	struct rpc_bdev_raid_create req;
	struct rpc_bdev_raid_delete destroy_req;
	struct raid_bdev *pbdev;
	struct spdk_bdev *base_bdev;
	struct spdk_thread *process_thread;
	uint64_t num_blocks_processed = 0;
	struct spdk_raid_bdev_opts opts;
	int i = 0;

	set_globals();
	CU_ASSERT(raid_bdev_init() == 0);

	create_raid_bdev_create_req(&req, "raid1", 0, true, 0, false);
	verify_raid_bdev_present("raid1", false);
	TAILQ_FOREACH(base_bdev, &g_bdev_list, internal.link) {
		base_bdev->blockcnt = 128;
	}
	rpc_bdev_raid_create(NULL, NULL);
	CU_ASSERT(g_rpc_err == 0);
	verify_raid_bdev(&req, true, RAID_BDEV_STATE_ONLINE);
	free_test_req(&req);

	TAILQ_FOREACH(pbdev, &g_raid_bdev_list, global_link) {
		if (strcmp(pbdev->bdev.name, "raid1") == 0) {
			break;
		}
	}
	CU_ASSERT(pbdev != NULL);

	pbdev->module_private = &num_blocks_processed;
	pbdev->min_base_bdevs_operational = 0;

	opts.process_window_size_kb = 1024;
	opts.process_max_bandwidth_mb_sec = 1;
	CU_ASSERT(raid_bdev_set_opts(&opts) == 0);
	CU_ASSERT(raid_bdev_start_rebuild(&pbdev->base_bdev_info[0]) == 0);
	poll_app_thread();

	SPDK_CU_ASSERT_FATAL(pbdev->process != NULL);

	process_thread = g_latest_thread;

	for (i = 0; i < 10; i++) {
		spdk_thread_poll(process_thread, 0, 0);
		poll_app_thread();
	}
	CU_ASSERT(pbdev->process->window_offset == 0);

	spdk_delay_us(SPDK_SEC_TO_USEC);
	while (spdk_thread_poll(process_thread, 0, 0) > 0) {
		spdk_delay_us(SPDK_SEC_TO_USEC);
		poll_app_thread();
	}

	CU_ASSERT(pbdev->process == NULL);
	CU_ASSERT(num_blocks_processed == pbdev->bdev.blockcnt);

	poll_app_thread();

	create_raid_bdev_delete_req(&destroy_req, "raid1", 0);
	rpc_bdev_raid_delete(NULL, NULL);
	CU_ASSERT(g_rpc_err == 0);
	verify_raid_bdev_present("raid1", false);

	raid_bdev_exit();
	base_bdevs_cleanup();
	reset_globals();
}

static void
test_raid_io_split(void)
{
	struct rpc_bdev_raid_create req;
	struct rpc_bdev_raid_delete destroy_req;
	struct raid_bdev *pbdev;
	struct spdk_io_channel *ch;
	struct raid_bdev_io_channel *raid_ch;
	struct spdk_bdev_io *bdev_io;
	struct raid_bdev_io *raid_io;
	uint64_t split_offset;
	struct iovec iovs_orig[4];
	struct raid_bdev_process process = { };

	set_globals();
	CU_ASSERT(raid_bdev_init() == 0);

	verify_raid_bdev_present("raid1", false);
	create_raid_bdev_create_req(&req, "raid1", 0, true, 0, false);
	rpc_bdev_raid_create(NULL, NULL);
	CU_ASSERT(g_rpc_err == 0);
	verify_raid_bdev(&req, true, RAID_BDEV_STATE_ONLINE);

	TAILQ_FOREACH(pbdev, &g_raid_bdev_list, global_link) {
		if (strcmp(pbdev->bdev.name, "raid1") == 0) {
			break;
		}
	}
	CU_ASSERT(pbdev != NULL);
	pbdev->bdev.md_len = 8;

	process.raid_bdev = pbdev;
	process.target = &pbdev->base_bdev_info[0];
	pbdev->process = &process;
	ch = spdk_get_io_channel(pbdev);
	SPDK_CU_ASSERT_FATAL(ch != NULL);
	raid_ch = spdk_io_channel_get_ctx(ch);
	g_bdev_io_defer_completion = true;

	/* test split of bdev_io with 1 iovec */
	bdev_io = calloc(1, sizeof(struct spdk_bdev_io) + sizeof(struct raid_bdev_io));
	SPDK_CU_ASSERT_FATAL(bdev_io != NULL);
	raid_io = (struct raid_bdev_io *)bdev_io->driver_ctx;
	_bdev_io_initialize(bdev_io, ch, &pbdev->bdev, 0, g_strip_size, SPDK_BDEV_IO_TYPE_WRITE, 1,
			    g_strip_size * g_block_len);
	memcpy(iovs_orig, bdev_io->u.bdev.iovs, sizeof(*iovs_orig) * bdev_io->u.bdev.iovcnt);

	split_offset = 1;
	raid_ch->process.offset = split_offset;
	raid_bdev_submit_request(ch, bdev_io);
	CU_ASSERT(raid_io->num_blocks == g_strip_size - split_offset);
	CU_ASSERT(raid_io->offset_blocks == split_offset);
	CU_ASSERT(raid_io->iovcnt == 1);
	CU_ASSERT(raid_io->iovs == bdev_io->u.bdev.iovs);
	CU_ASSERT(raid_io->iovs == raid_io->split.iov);
	CU_ASSERT(raid_io->iovs[0].iov_base == iovs_orig->iov_base + split_offset * g_block_len);
	CU_ASSERT(raid_io->iovs[0].iov_len == iovs_orig->iov_len - split_offset * g_block_len);
	if (spdk_bdev_get_dif_type(&pbdev->bdev) != SPDK_DIF_DISABLE &&
	    !spdk_bdev_is_md_interleaved(&pbdev->bdev)) {
		CU_ASSERT(raid_io->md_buf == bdev_io->u.bdev.md_buf + split_offset * pbdev->bdev.md_len);
	}
	complete_deferred_ios();
	CU_ASSERT(raid_io->num_blocks == split_offset);
	CU_ASSERT(raid_io->offset_blocks == 0);
	CU_ASSERT(raid_io->iovcnt == 1);
	CU_ASSERT(raid_io->iovs[0].iov_base == iovs_orig->iov_base);
	CU_ASSERT(raid_io->iovs[0].iov_len == split_offset * g_block_len);
	if (spdk_bdev_get_dif_type(&pbdev->bdev) != SPDK_DIF_DISABLE &&
	    !spdk_bdev_is_md_interleaved(&pbdev->bdev)) {
		CU_ASSERT(raid_io->md_buf == bdev_io->u.bdev.md_buf);
	}
	complete_deferred_ios();
	CU_ASSERT(raid_io->num_blocks == g_strip_size);
	CU_ASSERT(raid_io->offset_blocks == 0);
	CU_ASSERT(raid_io->iovcnt == 1);
	CU_ASSERT(raid_io->iovs[0].iov_base == iovs_orig->iov_base);
	CU_ASSERT(raid_io->iovs[0].iov_len == iovs_orig->iov_len);
	if (spdk_bdev_get_dif_type(&pbdev->bdev) != SPDK_DIF_DISABLE &&
	    !spdk_bdev_is_md_interleaved(&pbdev->bdev)) {
		CU_ASSERT(raid_io->md_buf == bdev_io->u.bdev.md_buf);
	}

	CU_ASSERT(g_io_comp_status == g_child_io_status_flag);

	bdev_io_cleanup(bdev_io);

	/* test split of bdev_io with 4 iovecs */
	bdev_io = calloc(1, sizeof(struct spdk_bdev_io) + sizeof(struct raid_bdev_io));
	SPDK_CU_ASSERT_FATAL(bdev_io != NULL);
	raid_io = (struct raid_bdev_io *)bdev_io->driver_ctx;
	_bdev_io_initialize(bdev_io, ch, &pbdev->bdev, 0, g_strip_size, SPDK_BDEV_IO_TYPE_WRITE,
			    4, g_strip_size / 4 * g_block_len);
	memcpy(iovs_orig, bdev_io->u.bdev.iovs, sizeof(*iovs_orig) * bdev_io->u.bdev.iovcnt);

	split_offset = 1; /* split at the first iovec */
	raid_ch->process.offset = split_offset;
	raid_bdev_submit_request(ch, bdev_io);
	CU_ASSERT(raid_io->num_blocks == g_strip_size - split_offset);
	CU_ASSERT(raid_io->offset_blocks == split_offset);
	CU_ASSERT(raid_io->iovcnt == 4);
	CU_ASSERT(raid_io->split.iov == &bdev_io->u.bdev.iovs[0]);
	CU_ASSERT(raid_io->iovs == &bdev_io->u.bdev.iovs[0]);
	CU_ASSERT(raid_io->iovs[0].iov_base == iovs_orig[0].iov_base + g_block_len);
	CU_ASSERT(raid_io->iovs[0].iov_len == iovs_orig[0].iov_len -  g_block_len);
	CU_ASSERT(memcmp(raid_io->iovs + 1, iovs_orig + 1, sizeof(*iovs_orig) * 3) == 0);
	if (spdk_bdev_get_dif_type(&pbdev->bdev) != SPDK_DIF_DISABLE &&
	    !spdk_bdev_is_md_interleaved(&pbdev->bdev)) {
		CU_ASSERT(raid_io->md_buf == bdev_io->u.bdev.md_buf + split_offset * pbdev->bdev.md_len);
	}
	complete_deferred_ios();
	CU_ASSERT(raid_io->num_blocks == split_offset);
	CU_ASSERT(raid_io->offset_blocks == 0);
	CU_ASSERT(raid_io->iovcnt == 1);
	CU_ASSERT(raid_io->iovs == bdev_io->u.bdev.iovs);
	CU_ASSERT(raid_io->iovs[0].iov_base == iovs_orig[0].iov_base);
	CU_ASSERT(raid_io->iovs[0].iov_len == g_block_len);
	if (spdk_bdev_get_dif_type(&pbdev->bdev) != SPDK_DIF_DISABLE &&
	    !spdk_bdev_is_md_interleaved(&pbdev->bdev)) {
		CU_ASSERT(raid_io->md_buf == bdev_io->u.bdev.md_buf);
	}
	complete_deferred_ios();
	CU_ASSERT(raid_io->num_blocks == g_strip_size);
	CU_ASSERT(raid_io->offset_blocks == 0);
	CU_ASSERT(raid_io->iovcnt == 4);
	CU_ASSERT(raid_io->iovs == bdev_io->u.bdev.iovs);
	CU_ASSERT(memcmp(raid_io->iovs, iovs_orig, sizeof(*iovs_orig) * raid_io->iovcnt) == 0);
	if (spdk_bdev_get_dif_type(&pbdev->bdev) != SPDK_DIF_DISABLE &&
	    !spdk_bdev_is_md_interleaved(&pbdev->bdev)) {
		CU_ASSERT(raid_io->md_buf == bdev_io->u.bdev.md_buf);
	}

	CU_ASSERT(g_io_comp_status == g_child_io_status_flag);

	split_offset = g_strip_size / 2; /* split exactly between second and third iovec */
	raid_ch->process.offset = split_offset;
	raid_bdev_submit_request(ch, bdev_io);
	CU_ASSERT(raid_io->num_blocks == g_strip_size - split_offset);
	CU_ASSERT(raid_io->offset_blocks == split_offset);
	CU_ASSERT(raid_io->iovcnt == 2);
	CU_ASSERT(raid_io->split.iov == NULL);
	CU_ASSERT(raid_io->iovs == &bdev_io->u.bdev.iovs[2]);
	CU_ASSERT(memcmp(raid_io->iovs, iovs_orig + 2, sizeof(*iovs_orig) * raid_io->iovcnt) == 0);
	if (spdk_bdev_get_dif_type(&pbdev->bdev) != SPDK_DIF_DISABLE &&
	    !spdk_bdev_is_md_interleaved(&pbdev->bdev)) {
		CU_ASSERT(raid_io->md_buf == bdev_io->u.bdev.md_buf + split_offset * pbdev->bdev.md_len);
	}
	complete_deferred_ios();
	CU_ASSERT(raid_io->num_blocks == split_offset);
	CU_ASSERT(raid_io->offset_blocks == 0);
	CU_ASSERT(raid_io->iovcnt == 2);
	CU_ASSERT(raid_io->iovs == bdev_io->u.bdev.iovs);
	CU_ASSERT(memcmp(raid_io->iovs, iovs_orig, sizeof(*iovs_orig) * raid_io->iovcnt) == 0);
	if (spdk_bdev_get_dif_type(&pbdev->bdev) != SPDK_DIF_DISABLE &&
	    !spdk_bdev_is_md_interleaved(&pbdev->bdev)) {
		CU_ASSERT(raid_io->md_buf == bdev_io->u.bdev.md_buf);
	}
	complete_deferred_ios();
	CU_ASSERT(raid_io->num_blocks == g_strip_size);
	CU_ASSERT(raid_io->offset_blocks == 0);
	CU_ASSERT(raid_io->iovcnt == 4);
	CU_ASSERT(raid_io->iovs == bdev_io->u.bdev.iovs);
	CU_ASSERT(memcmp(raid_io->iovs, iovs_orig, sizeof(*iovs_orig) * raid_io->iovcnt) == 0);
	if (spdk_bdev_get_dif_type(&pbdev->bdev) != SPDK_DIF_DISABLE &&
	    !spdk_bdev_is_md_interleaved(&pbdev->bdev)) {
		CU_ASSERT(raid_io->md_buf == bdev_io->u.bdev.md_buf);
	}

	CU_ASSERT(g_io_comp_status == g_child_io_status_flag);

	split_offset = g_strip_size / 2 + 1; /* split at the third iovec */
	raid_ch->process.offset = split_offset;
	raid_bdev_submit_request(ch, bdev_io);
	CU_ASSERT(raid_io->num_blocks == g_strip_size - split_offset);
	CU_ASSERT(raid_io->offset_blocks == split_offset);
	CU_ASSERT(raid_io->iovcnt == 2);
	CU_ASSERT(raid_io->split.iov == &bdev_io->u.bdev.iovs[2]);
	CU_ASSERT(raid_io->iovs == &bdev_io->u.bdev.iovs[2]);
	CU_ASSERT(raid_io->iovs[0].iov_base == iovs_orig[2].iov_base + g_block_len);
	CU_ASSERT(raid_io->iovs[0].iov_len == iovs_orig[2].iov_len - g_block_len);
	CU_ASSERT(raid_io->iovs[1].iov_base == iovs_orig[3].iov_base);
	CU_ASSERT(raid_io->iovs[1].iov_len == iovs_orig[3].iov_len);
	if (spdk_bdev_get_dif_type(&pbdev->bdev) != SPDK_DIF_DISABLE &&
	    !spdk_bdev_is_md_interleaved(&pbdev->bdev)) {
		CU_ASSERT(raid_io->md_buf == bdev_io->u.bdev.md_buf + split_offset * pbdev->bdev.md_len);
	}
	complete_deferred_ios();
	CU_ASSERT(raid_io->num_blocks == split_offset);
	CU_ASSERT(raid_io->offset_blocks == 0);
	CU_ASSERT(raid_io->iovcnt == 3);
	CU_ASSERT(raid_io->iovs == bdev_io->u.bdev.iovs);
	CU_ASSERT(memcmp(raid_io->iovs, iovs_orig, sizeof(*iovs_orig) * 2) == 0);
	CU_ASSERT(raid_io->iovs[2].iov_base == iovs_orig[2].iov_base);
	CU_ASSERT(raid_io->iovs[2].iov_len == g_block_len);
	if (spdk_bdev_get_dif_type(&pbdev->bdev) != SPDK_DIF_DISABLE &&
	    !spdk_bdev_is_md_interleaved(&pbdev->bdev)) {
		CU_ASSERT(raid_io->md_buf == bdev_io->u.bdev.md_buf);
	}
	complete_deferred_ios();
	CU_ASSERT(raid_io->num_blocks == g_strip_size);
	CU_ASSERT(raid_io->offset_blocks == 0);
	CU_ASSERT(raid_io->iovcnt == 4);
	CU_ASSERT(raid_io->iovs == bdev_io->u.bdev.iovs);
	CU_ASSERT(memcmp(raid_io->iovs, iovs_orig, sizeof(*iovs_orig) * raid_io->iovcnt) == 0);
	if (spdk_bdev_get_dif_type(&pbdev->bdev) != SPDK_DIF_DISABLE &&
	    !spdk_bdev_is_md_interleaved(&pbdev->bdev)) {
		CU_ASSERT(raid_io->md_buf == bdev_io->u.bdev.md_buf);
	}

	CU_ASSERT(g_io_comp_status == g_child_io_status_flag);

	split_offset = g_strip_size - 1; /* split at the last iovec */
	raid_ch->process.offset = split_offset;
	raid_bdev_submit_request(ch, bdev_io);
	CU_ASSERT(raid_io->num_blocks == g_strip_size - split_offset);
	CU_ASSERT(raid_io->offset_blocks == split_offset);
	CU_ASSERT(raid_io->iovcnt == 1);
	CU_ASSERT(raid_io->split.iov == &bdev_io->u.bdev.iovs[3]);
	CU_ASSERT(raid_io->iovs == &bdev_io->u.bdev.iovs[3]);
	CU_ASSERT(raid_io->iovs[0].iov_base == iovs_orig[3].iov_base + iovs_orig[3].iov_len - g_block_len);
	CU_ASSERT(raid_io->iovs[0].iov_len == g_block_len);
	if (spdk_bdev_get_dif_type(&pbdev->bdev) != SPDK_DIF_DISABLE &&
	    !spdk_bdev_is_md_interleaved(&pbdev->bdev)) {
		CU_ASSERT(raid_io->md_buf == bdev_io->u.bdev.md_buf + split_offset * pbdev->bdev.md_len);
	}
	complete_deferred_ios();
	CU_ASSERT(raid_io->num_blocks == split_offset);
	CU_ASSERT(raid_io->offset_blocks == 0);
	CU_ASSERT(raid_io->iovcnt == 4);
	CU_ASSERT(raid_io->iovs == bdev_io->u.bdev.iovs);
	CU_ASSERT(memcmp(raid_io->iovs, iovs_orig, sizeof(*iovs_orig) * 3) == 0);
	CU_ASSERT(raid_io->iovs[3].iov_base == iovs_orig[3].iov_base);
	CU_ASSERT(raid_io->iovs[3].iov_len == iovs_orig[3].iov_len - g_block_len);
	if (spdk_bdev_get_dif_type(&pbdev->bdev) != SPDK_DIF_DISABLE &&
	    !spdk_bdev_is_md_interleaved(&pbdev->bdev)) {
		CU_ASSERT(raid_io->md_buf == bdev_io->u.bdev.md_buf);
	}
	complete_deferred_ios();
	CU_ASSERT(raid_io->num_blocks == g_strip_size);
	CU_ASSERT(raid_io->offset_blocks == 0);
	CU_ASSERT(raid_io->iovcnt == 4);
	CU_ASSERT(raid_io->iovs == bdev_io->u.bdev.iovs);
	CU_ASSERT(memcmp(raid_io->iovs, iovs_orig, sizeof(*iovs_orig) * raid_io->iovcnt) == 0);
	if (spdk_bdev_get_dif_type(&pbdev->bdev) != SPDK_DIF_DISABLE &&
	    !spdk_bdev_is_md_interleaved(&pbdev->bdev)) {
		CU_ASSERT(raid_io->md_buf == bdev_io->u.bdev.md_buf);
	}

	CU_ASSERT(g_io_comp_status == g_child_io_status_flag);

	bdev_io_cleanup(bdev_io);

	spdk_put_io_channel(ch);
	free_test_req(&req);
	pbdev->process = NULL;

	create_raid_bdev_delete_req(&destroy_req, "raid1", 0);
	rpc_bdev_raid_delete(NULL, NULL);
	CU_ASSERT(g_rpc_err == 0);
	verify_raid_bdev_present("raid1", false);

	raid_bdev_exit();
	base_bdevs_cleanup();
	reset_globals();
}

static int
test_new_thread_fn(struct spdk_thread *thread)
{
	g_latest_thread = thread;

	return 0;
}

static int
test_bdev_ioch_create(void *io_device, void *ctx_buf)
{
	return 0;
}

static void
test_bdev_ioch_destroy(void *io_device, void *ctx_buf)
{
}

int
main(int argc, char **argv)
{
	CU_pSuite suite = NULL;
	unsigned int num_failures;

	CU_initialize_registry();

	suite = CU_add_suite("raid", set_test_opts, NULL);
	CU_ADD_TEST(suite, test_create_raid);
	CU_ADD_TEST(suite, test_create_raid_superblock);
	CU_ADD_TEST(suite, test_delete_raid);
	CU_ADD_TEST(suite, test_create_raid_invalid_args);
	CU_ADD_TEST(suite, test_delete_raid_invalid_args);
	CU_ADD_TEST(suite, test_io_channel);
	CU_ADD_TEST(suite, test_reset_io);
	CU_ADD_TEST(suite, test_multi_raid);
	CU_ADD_TEST(suite, test_io_type_supported);
	CU_ADD_TEST(suite, test_raid_json_dump_info);
	CU_ADD_TEST(suite, test_context_size);
	CU_ADD_TEST(suite, test_raid_level_conversions);
	CU_ADD_TEST(suite, test_raid_io_split);
	CU_ADD_TEST(suite, test_raid_process);
	CU_ADD_TEST(suite, test_raid_process_with_qos);

	spdk_thread_lib_init(test_new_thread_fn, 0);
	g_app_thread = spdk_thread_create("app_thread", NULL);
	spdk_set_thread(g_app_thread);
	spdk_io_device_register(&g_bdev_ch_io_device, test_bdev_ioch_create, test_bdev_ioch_destroy, 0,
				NULL);

	num_failures = spdk_ut_run_tests(argc, argv, NULL);
	CU_cleanup_registry();

	spdk_io_device_unregister(&g_bdev_ch_io_device, NULL);
	spdk_thread_exit(g_app_thread);
	spdk_thread_poll(g_app_thread, 0, 0);
	spdk_thread_destroy(g_app_thread);
	spdk_thread_lib_fini();

	return num_failures;
}
