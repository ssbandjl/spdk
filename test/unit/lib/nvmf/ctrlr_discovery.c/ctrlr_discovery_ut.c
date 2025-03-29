/*   SPDX-License-Identifier: BSD-3-Clause
 *   Copyright (C) 2017 Intel Corporation.
 *   All rights reserved.
 *   Copyright (c) 2021 NVIDIA CORPORATION & AFFILIATES. All rights reserved.
 */

#include "spdk/stdinc.h"

#include "spdk_internal/cunit.h"
#include "spdk_internal/mock.h"

#include "common/lib/test_env.c"
#include "spdk/bdev_module.h"
#include "nvmf/ctrlr_discovery.c"
#include "nvmf/subsystem.c"

SPDK_LOG_REGISTER_COMPONENT(nvmf)

DEFINE_STUB_V(spdk_bdev_module_release_bdev,
	      (struct spdk_bdev *bdev));

DEFINE_STUB(spdk_bdev_get_block_size, uint32_t,
	    (const struct spdk_bdev *bdev), 512);

DEFINE_STUB(spdk_nvmf_transport_stop_listen,
	    int,
	    (struct spdk_nvmf_transport *transport,
	     const struct spdk_nvme_transport_id *trid), 0);

DEFINE_STUB(spdk_nvmf_transport_get_first,
	    struct spdk_nvmf_transport *,
	    (struct spdk_nvmf_tgt *tgt), NULL);

DEFINE_STUB(spdk_nvmf_transport_get_next,
	    struct spdk_nvmf_transport *,
	    (struct spdk_nvmf_transport *transport), NULL);

DEFINE_STUB_V(spdk_bdev_close, (struct spdk_bdev_desc *desc));

DEFINE_STUB_V(nvmf_ctrlr_async_event_discovery_log_change_notice, (void *ctx));
DEFINE_STUB(spdk_nvmf_qpair_disconnect, int, (struct spdk_nvmf_qpair *qpair), 0);

DEFINE_STUB(spdk_bdev_open_ext, int,
	    (const char *bdev_name, bool write,	spdk_bdev_event_cb_t event_cb,
	     void *event_ctx, struct spdk_bdev_desc **desc), 0);

DEFINE_STUB(spdk_bdev_desc_get_bdev, struct spdk_bdev *,
	    (struct spdk_bdev_desc *desc), NULL);

DEFINE_STUB(spdk_bdev_get_md_size, uint32_t,
	    (const struct spdk_bdev *bdev), 0);

DEFINE_STUB(spdk_bdev_is_md_interleaved, bool,
	    (const struct spdk_bdev *bdev), false);

DEFINE_STUB(spdk_bdev_module_claim_bdev, int,
	    (struct spdk_bdev *bdev, struct spdk_bdev_desc *desc,
	     struct spdk_bdev_module *module), 0);

DEFINE_STUB(spdk_bdev_io_type_supported, bool,
	    (struct spdk_bdev *bdev, enum spdk_bdev_io_type io_type), false);

DEFINE_STUB_V(nvmf_ctrlr_reservation_notice_log,
	      (struct spdk_nvmf_ctrlr *ctrlr, struct spdk_nvmf_ns *ns,
	       enum spdk_nvme_reservation_notification_log_page_type type));

DEFINE_STUB(spdk_nvmf_request_complete, int,
	    (struct spdk_nvmf_request *req), -1);

DEFINE_STUB(nvmf_ctrlr_async_event_ana_change_notice, int,
	    (struct spdk_nvmf_ctrlr *ctrlr), 0);

DEFINE_STUB(nvmf_ctrlr_async_event_ns_notice, int,
	    (struct spdk_nvmf_ctrlr *ctrlr), 0);

DEFINE_STUB(spdk_nvme_transport_id_trtype_str, const char *,
	    (enum spdk_nvme_transport_type trtype), NULL);

DEFINE_STUB(spdk_bdev_is_zoned, bool, (const struct spdk_bdev *bdev), false);

DEFINE_STUB(spdk_bdev_get_max_zone_append_size, uint32_t,
	    (const struct spdk_bdev *bdev), 0);
DEFINE_STUB(spdk_key_dup, struct spdk_key *, (struct spdk_key *k), NULL);
DEFINE_STUB(spdk_key_get_name, const char *, (struct spdk_key *k), NULL);
DEFINE_STUB_V(spdk_keyring_put_key, (struct spdk_key *k));
DEFINE_STUB(nvmf_auth_is_supported, bool, (void), false);

DEFINE_STUB(spdk_bdev_get_nvme_ctratt, union spdk_bdev_nvme_ctratt,
	    (struct spdk_bdev *bdev), {});
DEFINE_STUB(nvmf_tgt_update_mdns_prr, int, (struct spdk_nvmf_tgt *tgt), 0);

const char *
spdk_bdev_get_name(const struct spdk_bdev *bdev)
{
	return "test";
}

const struct spdk_uuid *
spdk_bdev_get_uuid(const struct spdk_bdev *bdev)
{
	return &bdev->uuid;
}

int
spdk_nvme_transport_id_compare(const struct spdk_nvme_transport_id *trid1,
			       const struct spdk_nvme_transport_id *trid2)
{
	return !(trid1->trtype == trid2->trtype && strcasecmp(trid1->traddr, trid2->traddr) == 0 &&
		 strcasecmp(trid1->trsvcid, trid2->trsvcid) == 0);
}

int
spdk_nvmf_transport_listen(struct spdk_nvmf_transport *transport,
			   const struct spdk_nvme_transport_id *trid, struct spdk_nvmf_listen_opts *opts)
{
	return 0;
}

static struct spdk_nvmf_listener g_listener = {};

struct spdk_nvmf_listener *
nvmf_transport_find_listener(struct spdk_nvmf_transport *transport,
			     const struct spdk_nvme_transport_id *trid)
{
	struct spdk_nvmf_listener *listener;

	if (TAILQ_EMPTY(&transport->listeners)) {
		return &g_listener;
	}

	TAILQ_FOREACH(listener, &transport->listeners, link) {
		if (spdk_nvme_transport_id_compare(&listener->trid, trid) == 0) {
			return listener;
		}
	}

	return NULL;
}

void
nvmf_transport_listener_discover(struct spdk_nvmf_transport *transport,
				 struct spdk_nvme_transport_id *trid,
				 struct spdk_nvmf_discovery_log_page_entry *entry)
{
	transport->ops->listener_discover(transport, trid, entry);
}

static void
test_dummy_listener_discover(struct spdk_nvmf_transport *transport,
			     struct spdk_nvme_transport_id *trid, struct spdk_nvmf_discovery_log_page_entry *entry)
{
	entry->trtype = 42;
}

struct spdk_nvmf_transport_ops g_transport_ops = { .listener_discover = test_dummy_listener_discover };

static struct spdk_nvmf_transport g_transport = {
	.ops = &g_transport_ops
};

int
spdk_nvmf_transport_create_async(const char *transport_name,
				 struct spdk_nvmf_transport_opts *tprt_opts,
				 spdk_nvmf_transport_create_done_cb cb_fn, void *cb_arg)
{
	if (strcasecmp(transport_name, spdk_nvme_transport_id_trtype_str(SPDK_NVME_TRANSPORT_RDMA))) {
		cb_fn(cb_arg, &g_transport);
		return 0;
	}

	return -1;
}

struct spdk_nvmf_subsystem *
spdk_nvmf_tgt_find_subsystem(struct spdk_nvmf_tgt *tgt, const char *subnqn)
{
	return NULL;
}

DEFINE_RETURN_MOCK(spdk_nvmf_tgt_get_transport, struct spdk_nvmf_transport *);
struct spdk_nvmf_transport *
spdk_nvmf_tgt_get_transport(struct spdk_nvmf_tgt *tgt, const char *transport_name)
{
	HANDLE_RETURN_MOCK(spdk_nvmf_tgt_get_transport);
	return &g_transport;
}

int
spdk_nvme_transport_id_parse_trtype(enum spdk_nvme_transport_type *trtype, const char *str)
{
	if (trtype == NULL || str == NULL) {
		return -EINVAL;
	}

	if (strcasecmp(str, "PCIe") == 0) {
		*trtype = SPDK_NVME_TRANSPORT_PCIE;
	} else if (strcasecmp(str, "RDMA") == 0) {
		*trtype = SPDK_NVME_TRANSPORT_RDMA;
	} else {
		return -ENOENT;
	}
	return 0;
}

void
nvmf_ctrlr_ns_changed(struct spdk_nvmf_ctrlr *ctrlr, uint32_t nsid)
{
}

void
nvmf_ctrlr_destruct(struct spdk_nvmf_ctrlr *ctrlr)
{
}

int
nvmf_poll_group_update_subsystem(struct spdk_nvmf_poll_group *group,
				 struct spdk_nvmf_subsystem *subsystem)
{
	return 0;
}

int
nvmf_poll_group_add_subsystem(struct spdk_nvmf_poll_group *group,
			      struct spdk_nvmf_subsystem *subsystem,
			      spdk_nvmf_poll_group_mod_done cb_fn, void *cb_arg)
{
	return 0;
}

void
nvmf_poll_group_remove_subsystem(struct spdk_nvmf_poll_group *group,
				 struct spdk_nvmf_subsystem *subsystem,
				 spdk_nvmf_poll_group_mod_done cb_fn, void *cb_arg)
{
}

void
nvmf_poll_group_pause_subsystem(struct spdk_nvmf_poll_group *group,
				struct spdk_nvmf_subsystem *subsystem,
				uint32_t nsid,
				spdk_nvmf_poll_group_mod_done cb_fn, void *cb_arg)
{
}

void
nvmf_poll_group_resume_subsystem(struct spdk_nvmf_poll_group *group,
				 struct spdk_nvmf_subsystem *subsystem,
				 spdk_nvmf_poll_group_mod_done cb_fn, void *cb_arg)
{
}

static void
_subsystem_add_listen_done(void *cb_arg, int status)
{
	SPDK_CU_ASSERT_FATAL(status == 0);
}

static void
test_gen_trid(struct spdk_nvme_transport_id *trid, enum spdk_nvme_transport_type trtype,
	      enum spdk_nvmf_adrfam adrfam, const char *tradd, const char *trsvcid)
{
	snprintf(trid->traddr, sizeof(trid->traddr), "%s", tradd);
	snprintf(trid->trsvcid, sizeof(trid->trsvcid), "%s", trsvcid);
	trid->adrfam = adrfam;
	trid->trtype = trtype;
	switch (trtype) {
	case SPDK_NVME_TRANSPORT_RDMA:
		snprintf(trid->trstring, SPDK_NVMF_TRSTRING_MAX_LEN, "%s", SPDK_NVME_TRANSPORT_NAME_RDMA);
		break;
	case SPDK_NVME_TRANSPORT_TCP:
		snprintf(trid->trstring, SPDK_NVMF_TRSTRING_MAX_LEN, "%s", SPDK_NVME_TRANSPORT_NAME_TCP);
		break;
	default:
		SPDK_CU_ASSERT_FATAL(0 && "not supported by test");
	}
}

static void
test_discovery_log(void)
{
	struct spdk_nvmf_tgt tgt = {};
	struct spdk_nvmf_subsystem *subsystem;
	uint8_t buffer[8192];
	struct iovec iov;
	struct spdk_nvmf_discovery_log_page *disc_log;
	struct spdk_nvmf_discovery_log_page_entry *entry;
	struct spdk_nvme_transport_id trid = {};
	const char *hostnqn = "nqn.2016-06.io.spdk:host1";
	int rc;

	iov.iov_base = buffer;
	iov.iov_len = 8192;

	tgt.max_subsystems = 1024;
	tgt.subsystem_ids = spdk_bit_array_create(tgt.max_subsystems);
	RB_INIT(&tgt.subsystems);

	/* Add one subsystem and verify that the discovery log contains it */
	subsystem = spdk_nvmf_subsystem_create(&tgt, "nqn.2016-06.io.spdk:subsystem1",
					       SPDK_NVMF_SUBTYPE_NVME, 0);
	SPDK_CU_ASSERT_FATAL(subsystem != NULL);

	rc = spdk_nvmf_subsystem_add_host(subsystem, hostnqn, NULL);
	CU_ASSERT(rc == 0);

	/* Get only genctr (first field in the header) */
	memset(buffer, 0xCC, sizeof(buffer));
	disc_log = (struct spdk_nvmf_discovery_log_page *)buffer;
	nvmf_get_discovery_log_page(&tgt, hostnqn, &iov, 1, 0, sizeof(disc_log->genctr),
				    &trid);
	/* No listeners yet on new subsystem, so genctr should still be 0. */
	CU_ASSERT(disc_log->genctr == 0);

	test_gen_trid(&trid, SPDK_NVME_TRANSPORT_RDMA, SPDK_NVMF_ADRFAM_IPV4, "1234", "5678");
	spdk_nvmf_subsystem_add_listener(subsystem, &trid, _subsystem_add_listen_done, NULL);
	subsystem->state = SPDK_NVMF_SUBSYSTEM_ACTIVE;

	/* Get only genctr (first field in the header) */
	memset(buffer, 0xCC, sizeof(buffer));
	disc_log = (struct spdk_nvmf_discovery_log_page *)buffer;
	nvmf_get_discovery_log_page(&tgt, hostnqn, &iov, 1, 0, sizeof(disc_log->genctr),
				    &trid);
	CU_ASSERT(disc_log->genctr == 1); /* one added subsystem and listener */

	/* Get only the header, no entries */
	memset(buffer, 0xCC, sizeof(buffer));
	disc_log = (struct spdk_nvmf_discovery_log_page *)buffer;
	nvmf_get_discovery_log_page(&tgt, hostnqn, &iov, 1, 0, sizeof(*disc_log),
				    &trid);
	CU_ASSERT(disc_log->genctr == 1);
	CU_ASSERT(disc_log->numrec == 1);

	/* Offset 0, exact size match */
	memset(buffer, 0xCC, sizeof(buffer));
	disc_log = (struct spdk_nvmf_discovery_log_page *)buffer;
	nvmf_get_discovery_log_page(&tgt, hostnqn, &iov, 1, 0,
				    sizeof(*disc_log) + sizeof(disc_log->entries[0]), &trid);
	CU_ASSERT(disc_log->genctr != 0);
	CU_ASSERT(disc_log->numrec == 1);
	CU_ASSERT(disc_log->entries[0].trtype == 42);

	/* Offset 0, oversize buffer */
	memset(buffer, 0xCC, sizeof(buffer));
	disc_log = (struct spdk_nvmf_discovery_log_page *)buffer;
	nvmf_get_discovery_log_page(&tgt, hostnqn, &iov, 1, 0, sizeof(buffer), &trid);
	CU_ASSERT(disc_log->genctr != 0);
	CU_ASSERT(disc_log->numrec == 1);
	CU_ASSERT(disc_log->entries[0].trtype == 42);
	CU_ASSERT(spdk_mem_all_zero(buffer + sizeof(*disc_log) + sizeof(disc_log->entries[0]),
				    sizeof(buffer) - (sizeof(*disc_log) + sizeof(disc_log->entries[0]))));

	/* Get just the first entry, no header */
	memset(buffer, 0xCC, sizeof(buffer));
	entry = (struct spdk_nvmf_discovery_log_page_entry *)buffer;
	nvmf_get_discovery_log_page(&tgt, hostnqn, &iov, 1,
				    offsetof(struct spdk_nvmf_discovery_log_page, entries[0]), sizeof(*entry), &trid);
	CU_ASSERT(entry->trtype == 42);

	/* remove the host and verify that the discovery log contains nothing */
	rc = spdk_nvmf_subsystem_remove_host(subsystem, hostnqn);
	CU_ASSERT(rc == 0);

	/* Get only the header, no entries */
	memset(buffer, 0xCC, sizeof(buffer));
	disc_log = (struct spdk_nvmf_discovery_log_page *)buffer;
	nvmf_get_discovery_log_page(&tgt, hostnqn, &iov, 1, 0, sizeof(*disc_log),
				    &trid);
	CU_ASSERT(disc_log->genctr != 0);
	CU_ASSERT(disc_log->numrec == 0);

	/* destroy the subsystem and verify that the discovery log contains nothing */
	subsystem->state = SPDK_NVMF_SUBSYSTEM_INACTIVE;
	rc = spdk_nvmf_subsystem_destroy(subsystem, NULL, NULL);
	CU_ASSERT(rc == 0);

	/* Get only the header, no entries */
	memset(buffer, 0xCC, sizeof(buffer));
	disc_log = (struct spdk_nvmf_discovery_log_page *)buffer;
	nvmf_get_discovery_log_page(&tgt, hostnqn, &iov, 1, 0, sizeof(*disc_log),
				    &trid);
	CU_ASSERT(disc_log->genctr != 0);
	CU_ASSERT(disc_log->numrec == 0);

	spdk_bit_array_free(&tgt.subsystem_ids);
}

static void
test_rdma_discover(struct spdk_nvmf_transport *transport, struct spdk_nvme_transport_id *trid,
		   struct spdk_nvmf_discovery_log_page_entry *entry)
{
	entry->trtype = SPDK_NVMF_TRTYPE_RDMA;
	entry->adrfam = trid->adrfam;
	memcpy(entry->traddr, trid->traddr, sizeof(entry->traddr));
	memcpy(entry->trsvcid, trid->trsvcid, sizeof(entry->trsvcid));
}

static void
test_tcp_discover(struct spdk_nvmf_transport *transport, struct spdk_nvme_transport_id *trid,
		  struct spdk_nvmf_discovery_log_page_entry *entry)
{
	entry->trtype = SPDK_NVMF_TRTYPE_TCP;
	entry->adrfam = trid->adrfam;
	memcpy(entry->traddr, trid->traddr, sizeof(entry->traddr));
	memcpy(entry->trsvcid, trid->trsvcid, sizeof(entry->trsvcid));
}

static void
test_discovery_log_with_filters(void)
{
	struct spdk_nvmf_tgt tgt = {};
	struct spdk_nvmf_transport_ops rdma_tr_ops = { .listener_discover = test_rdma_discover }, tcp_tr_ops
		= { .listener_discover = test_tcp_discover };
	struct spdk_nvmf_transport rdma_tr = {.ops = &rdma_tr_ops }, tcp_tr = { .ops = &tcp_tr_ops };
	struct spdk_nvmf_subsystem *subsystem;
	const char *hostnqn = "nqn.2016-06.io.spdk:host1";
	uint8_t buffer[8192];
	struct iovec iov;
	struct spdk_nvmf_discovery_log_page *disc_log;
	struct spdk_nvmf_listener rdma_listener_1 = {}, rdma_listener_2 = {}, rdma_listener_3 = {},
	tcp_listener_1 = {}, tcp_listener_2 = {}, tcp_listener_3 = {};
	struct spdk_nvme_transport_id rdma_trid_1 = {}, rdma_trid_2 = {}, rdma_trid_3 = {}, rdma_trid_4 = {},
	tcp_trid_1 = {}, tcp_trid_2 = {}, tcp_trid_3 = {}, tcp_trid_4 = {};
	struct spdk_nvmf_referral ref1 = {}, ref2 = {};

	iov.iov_base = buffer;
	iov.iov_len = 8192;

	tgt.max_subsystems = 4;
	tgt.subsystem_ids = spdk_bit_array_create(tgt.max_subsystems);
	RB_INIT(&tgt.subsystems);

	subsystem = spdk_nvmf_subsystem_create(&tgt, "nqn.2016-06.io.spdk:subsystem1",
					       SPDK_NVMF_SUBTYPE_NVME, 0);
	subsystem->allow_any_host = true;
	SPDK_CU_ASSERT_FATAL(subsystem != NULL);

	TAILQ_INIT(&tgt.referrals);

	test_gen_trid(&rdma_trid_1, SPDK_NVME_TRANSPORT_RDMA, SPDK_NVMF_ADRFAM_IPV4, "10.10.10.10", "4420");
	test_gen_trid(&rdma_trid_2, SPDK_NVME_TRANSPORT_RDMA, SPDK_NVMF_ADRFAM_IPV4, "11.11.11.11", "4420");
	test_gen_trid(&rdma_trid_3, SPDK_NVME_TRANSPORT_RDMA, SPDK_NVMF_ADRFAM_IPV4, "10.10.10.10", "4421");
	test_gen_trid(&rdma_trid_4, SPDK_NVME_TRANSPORT_RDMA, SPDK_NVMF_ADRFAM_IPV4, "10.10.10.10", "4430");
	test_gen_trid(&tcp_trid_1, SPDK_NVME_TRANSPORT_TCP, SPDK_NVMF_ADRFAM_IPV4, "11.11.11.11", "4421");
	test_gen_trid(&tcp_trid_2, SPDK_NVME_TRANSPORT_TCP, SPDK_NVMF_ADRFAM_IPV4, "10.10.10.10", "4422");
	test_gen_trid(&tcp_trid_3, SPDK_NVME_TRANSPORT_TCP, SPDK_NVMF_ADRFAM_IPV4, "11.11.11.11", "4422");
	test_gen_trid(&tcp_trid_4, SPDK_NVME_TRANSPORT_TCP, SPDK_NVMF_ADRFAM_IPV4, "11.11.11.11", "4430");

	rdma_listener_1.trid = rdma_trid_1;
	rdma_listener_2.trid = rdma_trid_2;
	rdma_listener_3.trid = rdma_trid_3;
	TAILQ_INIT(&rdma_tr.listeners);
	TAILQ_INSERT_TAIL(&rdma_tr.listeners, &rdma_listener_1, link);
	TAILQ_INSERT_TAIL(&rdma_tr.listeners, &rdma_listener_2, link);
	TAILQ_INSERT_TAIL(&rdma_tr.listeners, &rdma_listener_3, link);

	tcp_listener_1.trid = tcp_trid_1;
	tcp_listener_2.trid = tcp_trid_2;
	tcp_listener_3.trid = tcp_trid_3;
	TAILQ_INIT(&tcp_tr.listeners);
	TAILQ_INSERT_TAIL(&tcp_tr.listeners, &tcp_listener_1, link);
	TAILQ_INSERT_TAIL(&tcp_tr.listeners, &tcp_listener_2, link);
	TAILQ_INSERT_TAIL(&tcp_tr.listeners, &tcp_listener_3, link);

	MOCK_SET(spdk_nvmf_tgt_get_transport, &rdma_tr);
	spdk_nvmf_subsystem_add_listener(subsystem, &rdma_trid_1, _subsystem_add_listen_done, NULL);
	spdk_nvmf_subsystem_add_listener(subsystem, &rdma_trid_2, _subsystem_add_listen_done, NULL);
	spdk_nvmf_subsystem_add_listener(subsystem, &rdma_trid_3, _subsystem_add_listen_done, NULL);
	MOCK_SET(spdk_nvmf_tgt_get_transport, &tcp_tr);
	spdk_nvmf_subsystem_add_listener(subsystem, &tcp_trid_1, _subsystem_add_listen_done, NULL);
	spdk_nvmf_subsystem_add_listener(subsystem, &tcp_trid_2, _subsystem_add_listen_done, NULL);
	spdk_nvmf_subsystem_add_listener(subsystem, &tcp_trid_3, _subsystem_add_listen_done, NULL);
	MOCK_CLEAR(spdk_nvmf_tgt_get_transport);

	subsystem->state = SPDK_NVMF_SUBSYSTEM_ACTIVE;

	ref1.trid = rdma_trid_4;

	ref1.entry.trtype = rdma_trid_4.trtype;
	ref1.entry.adrfam = rdma_trid_4.adrfam;
	ref1.entry.subtype = SPDK_NVMF_SUBTYPE_DISCOVERY;
	ref1.entry.treq.secure_channel = SPDK_NVMF_TREQ_SECURE_CHANNEL_NOT_REQUIRED;
	ref1.entry.cntlid = 0xffff;
	memcpy(ref1.entry.trsvcid, rdma_trid_4.trsvcid, sizeof(ref1.entry.trsvcid));
	memcpy(ref1.entry.traddr, rdma_trid_4.traddr, sizeof(ref1.entry.traddr));
	snprintf(ref1.entry.subnqn, sizeof(ref1.entry.subnqn), "%s", SPDK_NVMF_DISCOVERY_NQN);

	ref2.trid = tcp_trid_4;

	ref2.entry.trtype = tcp_trid_4.trtype;
	ref2.entry.adrfam = tcp_trid_4.adrfam;
	ref2.entry.subtype = SPDK_NVMF_SUBTYPE_DISCOVERY;
	ref2.entry.treq.secure_channel = SPDK_NVMF_TREQ_SECURE_CHANNEL_NOT_REQUIRED;
	ref2.entry.cntlid = 0xffff;
	memcpy(ref2.entry.trsvcid, tcp_trid_4.trsvcid, sizeof(ref2.entry.trsvcid));
	memcpy(ref2.entry.traddr, tcp_trid_4.traddr, sizeof(ref2.entry.traddr));
	snprintf(ref2.entry.subnqn, sizeof(ref2.entry.subnqn), "%s", SPDK_NVMF_DISCOVERY_NQN);

	TAILQ_INSERT_HEAD(&tgt.referrals, &ref1, link);
	TAILQ_INSERT_HEAD(&tgt.referrals, &ref2, link);

	spdk_nvmf_send_discovery_log_notice(&tgt, NULL);

	disc_log = (struct spdk_nvmf_discovery_log_page *)buffer;
	memset(buffer, 0, sizeof(buffer));

	/* Test case 1 - check that all trids are reported */
	tgt.discovery_filter = SPDK_NVMF_TGT_DISCOVERY_MATCH_ANY;
	nvmf_get_discovery_log_page(&tgt, hostnqn, &iov, 1, 0, 8192, &rdma_trid_1);
	CU_ASSERT(disc_log->numrec == 8);

	/* Test case 2 - check that only entries of the same transport type are returned */
	tgt.discovery_filter = SPDK_NVMF_TGT_DISCOVERY_MATCH_TRANSPORT_TYPE;
	nvmf_get_discovery_log_page(&tgt, hostnqn, &iov, 1, 0, 8192, &rdma_trid_1);
	CU_ASSERT(disc_log->numrec == 5);
	CU_ASSERT(disc_log->entries[0].trtype == rdma_trid_1.trtype);
	CU_ASSERT(disc_log->entries[1].trtype == rdma_trid_1.trtype);
	CU_ASSERT(disc_log->entries[2].trtype == rdma_trid_1.trtype);
	CU_ASSERT(disc_log->entries[3].trtype == tcp_trid_4.trtype);
	CU_ASSERT(disc_log->entries[4].trtype == rdma_trid_4.trtype);

	nvmf_get_discovery_log_page(&tgt, hostnqn, &iov, 1, 0, 8192, &tcp_trid_1);
	CU_ASSERT(disc_log->numrec == 5);
	CU_ASSERT(disc_log->entries[0].trtype == tcp_trid_1.trtype);
	CU_ASSERT(disc_log->entries[1].trtype == tcp_trid_1.trtype);
	CU_ASSERT(disc_log->entries[2].trtype == tcp_trid_1.trtype);
	CU_ASSERT(disc_log->entries[3].trtype == tcp_trid_1.trtype);
	CU_ASSERT(disc_log->entries[4].trtype == rdma_trid_4.trtype);

	/* Test case 3 - check that only entries of the same transport address are returned */
	tgt.discovery_filter = SPDK_NVMF_TGT_DISCOVERY_MATCH_TRANSPORT_ADDRESS;
	nvmf_get_discovery_log_page(&tgt, hostnqn, &iov, 1, 0, 8192, &rdma_trid_1);
	CU_ASSERT(disc_log->numrec == 5);
	/* 1 tcp and 3 rdma  */
	CU_ASSERT(strcasecmp(disc_log->entries[0].traddr, rdma_trid_1.traddr) == 0);
	CU_ASSERT(strcasecmp(disc_log->entries[1].traddr, rdma_trid_1.traddr) == 0);
	CU_ASSERT(strcasecmp(disc_log->entries[2].traddr, rdma_trid_1.traddr) == 0);
	CU_ASSERT(strcasecmp(disc_log->entries[3].traddr, tcp_trid_4.traddr) == 0);
	CU_ASSERT(strcasecmp(disc_log->entries[4].traddr, rdma_trid_4.traddr) == 0);

	nvmf_get_discovery_log_page(&tgt, hostnqn, &iov, 1, 0, 8192, &tcp_trid_1);
	CU_ASSERT(disc_log->numrec == 5);
	/* 1 rdma and 3 tcp */
	CU_ASSERT((disc_log->entries[0].trtype ^ disc_log->entries[1].trtype ^ disc_log->entries[2].trtype)
		  != 0);
	CU_ASSERT(strcasecmp(disc_log->entries[0].traddr, tcp_trid_1.traddr) == 0);
	CU_ASSERT(strcasecmp(disc_log->entries[1].traddr, tcp_trid_1.traddr) == 0);
	CU_ASSERT(strcasecmp(disc_log->entries[2].traddr, tcp_trid_1.traddr) == 0);
	CU_ASSERT(strcasecmp(disc_log->entries[3].traddr, tcp_trid_1.traddr) == 0);
	CU_ASSERT(strcasecmp(disc_log->entries[4].traddr, rdma_trid_4.traddr) == 0);

	/* Test case 4 - check that only entries of the same transport address and type returned */
	tgt.discovery_filter = SPDK_NVMF_TGT_DISCOVERY_MATCH_TRANSPORT_TYPE |
			       SPDK_NVMF_TGT_DISCOVERY_MATCH_TRANSPORT_ADDRESS;
	nvmf_get_discovery_log_page(&tgt, hostnqn, &iov, 1, 0, 8192, &rdma_trid_1);
	CU_ASSERT(disc_log->numrec == 4);
	CU_ASSERT(strcasecmp(disc_log->entries[0].traddr, rdma_trid_1.traddr) == 0);
	CU_ASSERT(strcasecmp(disc_log->entries[1].traddr, rdma_trid_1.traddr) == 0);
	CU_ASSERT(strcasecmp(disc_log->entries[2].traddr, tcp_trid_4.traddr) == 0);
	CU_ASSERT(strcasecmp(disc_log->entries[3].traddr, rdma_trid_4.traddr) == 0);
	CU_ASSERT(disc_log->entries[0].trtype == rdma_trid_1.trtype);
	CU_ASSERT(disc_log->entries[1].trtype == rdma_trid_1.trtype);
	CU_ASSERT(disc_log->entries[2].trtype == tcp_trid_4.trtype);
	CU_ASSERT(disc_log->entries[3].trtype == rdma_trid_4.trtype);

	nvmf_get_discovery_log_page(&tgt, hostnqn, &iov, 1, 0, 8192, &rdma_trid_2);
	CU_ASSERT(disc_log->numrec == 3);
	CU_ASSERT(strcasecmp(disc_log->entries[0].traddr, rdma_trid_2.traddr) == 0);
	CU_ASSERT(strcasecmp(disc_log->entries[1].traddr, tcp_trid_4.traddr) == 0);
	CU_ASSERT(strcasecmp(disc_log->entries[2].traddr, rdma_trid_4.traddr) == 0);
	CU_ASSERT(disc_log->entries[0].trtype == rdma_trid_2.trtype);
	CU_ASSERT(disc_log->entries[1].trtype == tcp_trid_4.trtype);
	CU_ASSERT(disc_log->entries[2].trtype == rdma_trid_4.trtype);

	nvmf_get_discovery_log_page(&tgt, hostnqn, &iov, 1, 0, 8192, &tcp_trid_1);
	CU_ASSERT(disc_log->numrec == 4);
	CU_ASSERT(strcasecmp(disc_log->entries[0].traddr, tcp_trid_1.traddr) == 0);
	CU_ASSERT(strcasecmp(disc_log->entries[1].traddr, tcp_trid_1.traddr) == 0);
	CU_ASSERT(strcasecmp(disc_log->entries[2].traddr, tcp_trid_4.traddr) == 0);
	CU_ASSERT(strcasecmp(disc_log->entries[3].traddr, rdma_trid_4.traddr) == 0);
	CU_ASSERT(disc_log->entries[0].trtype == tcp_trid_1.trtype);
	CU_ASSERT(disc_log->entries[1].trtype == tcp_trid_1.trtype);
	CU_ASSERT(disc_log->entries[2].trtype == tcp_trid_4.trtype);
	CU_ASSERT(disc_log->entries[3].trtype == rdma_trid_4.trtype);

	nvmf_get_discovery_log_page(&tgt, hostnqn, &iov, 1, 0, 8192, &rdma_trid_2);
	CU_ASSERT(disc_log->numrec == 3);
	CU_ASSERT(strcasecmp(disc_log->entries[0].traddr, rdma_trid_2.traddr) == 0);
	CU_ASSERT(strcasecmp(disc_log->entries[1].traddr, tcp_trid_4.traddr) == 0);
	CU_ASSERT(strcasecmp(disc_log->entries[2].traddr, rdma_trid_4.traddr) == 0);
	CU_ASSERT(disc_log->entries[0].trtype == rdma_trid_2.trtype);
	CU_ASSERT(disc_log->entries[1].trtype == tcp_trid_4.trtype);
	CU_ASSERT(disc_log->entries[2].trtype == rdma_trid_4.trtype);

	/* Test case 5 - check that only entries of the same transport address and type returned */
	tgt.discovery_filter = SPDK_NVMF_TGT_DISCOVERY_MATCH_TRANSPORT_TYPE |
			       SPDK_NVMF_TGT_DISCOVERY_MATCH_TRANSPORT_SVCID;
	nvmf_get_discovery_log_page(&tgt, hostnqn, &iov, 1, 0, 8192, &rdma_trid_1);
	CU_ASSERT(disc_log->numrec == 4);
	CU_ASSERT(strcasecmp(disc_log->entries[0].trsvcid, rdma_trid_1.trsvcid) == 0);
	CU_ASSERT(strcasecmp(disc_log->entries[1].trsvcid, rdma_trid_2.trsvcid) == 0);
	CU_ASSERT(strcasecmp(disc_log->entries[2].trsvcid, tcp_trid_4.trsvcid) == 0);
	CU_ASSERT(strcasecmp(disc_log->entries[3].trsvcid, rdma_trid_4.trsvcid) == 0);
	CU_ASSERT(disc_log->entries[0].trtype == rdma_trid_1.trtype);
	CU_ASSERT(disc_log->entries[1].trtype == rdma_trid_2.trtype);
	CU_ASSERT(disc_log->entries[2].trtype == tcp_trid_4.trtype);
	CU_ASSERT(disc_log->entries[3].trtype == rdma_trid_4.trtype);

	nvmf_get_discovery_log_page(&tgt, hostnqn, &iov, 1, 0, 8192, &rdma_trid_3);
	CU_ASSERT(disc_log->numrec == 3);
	CU_ASSERT(strcasecmp(disc_log->entries[0].trsvcid, rdma_trid_3.trsvcid) == 0);
	CU_ASSERT(strcasecmp(disc_log->entries[1].trsvcid, tcp_trid_4.trsvcid) == 0);
	CU_ASSERT(strcasecmp(disc_log->entries[2].trsvcid, rdma_trid_4.trsvcid) == 0);
	CU_ASSERT(disc_log->entries[0].trtype == rdma_trid_3.trtype);
	CU_ASSERT(disc_log->entries[1].trtype == tcp_trid_4.trtype);
	CU_ASSERT(disc_log->entries[2].trtype == rdma_trid_4.trtype);

	nvmf_get_discovery_log_page(&tgt, hostnqn, &iov, 1, 0, 8192, &tcp_trid_1);
	CU_ASSERT(disc_log->numrec == 3);
	CU_ASSERT(strcasecmp(disc_log->entries[0].trsvcid, tcp_trid_1.trsvcid) == 0);
	CU_ASSERT(strcasecmp(disc_log->entries[1].trsvcid, tcp_trid_4.trsvcid) == 0);
	CU_ASSERT(strcasecmp(disc_log->entries[2].trsvcid, rdma_trid_4.trsvcid) == 0);
	CU_ASSERT(disc_log->entries[0].trtype == tcp_trid_1.trtype);
	CU_ASSERT(disc_log->entries[1].trtype == tcp_trid_4.trtype);
	CU_ASSERT(disc_log->entries[2].trtype == rdma_trid_4.trtype);

	nvmf_get_discovery_log_page(&tgt, hostnqn, &iov, 1, 0, 8192, &tcp_trid_2);
	CU_ASSERT(disc_log->numrec == 4);
	CU_ASSERT(strcasecmp(disc_log->entries[0].trsvcid, tcp_trid_2.trsvcid) == 0);
	CU_ASSERT(strcasecmp(disc_log->entries[1].trsvcid, tcp_trid_2.trsvcid) == 0);
	CU_ASSERT(strcasecmp(disc_log->entries[2].trsvcid, tcp_trid_4.trsvcid) == 0);
	CU_ASSERT(strcasecmp(disc_log->entries[3].trsvcid, rdma_trid_4.trsvcid) == 0);
	CU_ASSERT(disc_log->entries[0].trtype == tcp_trid_2.trtype);
	CU_ASSERT(disc_log->entries[1].trtype == tcp_trid_2.trtype);
	CU_ASSERT(disc_log->entries[2].trtype == tcp_trid_4.trtype);
	CU_ASSERT(disc_log->entries[3].trtype == rdma_trid_4.trtype);

	/* Test case 6 - check that only entries of the same transport address and type returned.
	 * That also implies trtype since RDMA and TCP listeners can't occupy the same socket */
	tgt.discovery_filter = SPDK_NVMF_TGT_DISCOVERY_MATCH_TRANSPORT_ADDRESS |
			       SPDK_NVMF_TGT_DISCOVERY_MATCH_TRANSPORT_SVCID;
	nvmf_get_discovery_log_page(&tgt, hostnqn, &iov, 1, 0, 8192, &rdma_trid_1);
	CU_ASSERT(disc_log->numrec == 3);
	CU_ASSERT(strcasecmp(disc_log->entries[0].traddr, rdma_trid_1.traddr) == 0);
	CU_ASSERT(strcasecmp(disc_log->entries[1].traddr, tcp_trid_4.traddr) == 0);
	CU_ASSERT(strcasecmp(disc_log->entries[2].traddr, rdma_trid_4.traddr) == 0);
	CU_ASSERT(strcasecmp(disc_log->entries[0].trsvcid, rdma_trid_1.trsvcid) == 0);
	CU_ASSERT(strcasecmp(disc_log->entries[1].trsvcid, tcp_trid_4.trsvcid) == 0);
	CU_ASSERT(strcasecmp(disc_log->entries[2].trsvcid, rdma_trid_4.trsvcid) == 0);
	CU_ASSERT(disc_log->entries[0].trtype == rdma_trid_1.trtype);
	CU_ASSERT(disc_log->entries[1].trtype == tcp_trid_4.trtype);
	CU_ASSERT(disc_log->entries[2].trtype == rdma_trid_4.trtype);

	nvmf_get_discovery_log_page(&tgt, hostnqn, &iov, 1, 0, 8192, &rdma_trid_2);
	CU_ASSERT(disc_log->numrec == 3);
	CU_ASSERT(strcasecmp(disc_log->entries[0].traddr, rdma_trid_2.traddr) == 0);
	CU_ASSERT(strcasecmp(disc_log->entries[1].traddr, tcp_trid_4.traddr) == 0);
	CU_ASSERT(strcasecmp(disc_log->entries[2].traddr, rdma_trid_4.traddr) == 0);
	CU_ASSERT(strcasecmp(disc_log->entries[0].trsvcid, rdma_trid_2.trsvcid) == 0);
	CU_ASSERT(strcasecmp(disc_log->entries[1].trsvcid, tcp_trid_4.trsvcid) == 0);
	CU_ASSERT(strcasecmp(disc_log->entries[2].trsvcid, rdma_trid_4.trsvcid) == 0);
	CU_ASSERT(disc_log->entries[0].trtype == rdma_trid_2.trtype);
	CU_ASSERT(disc_log->entries[1].trtype == tcp_trid_4.trtype);
	CU_ASSERT(disc_log->entries[2].trtype == rdma_trid_4.trtype);

	nvmf_get_discovery_log_page(&tgt, hostnqn, &iov, 1, 0, 8192, &rdma_trid_3);
	CU_ASSERT(disc_log->numrec == 3);
	CU_ASSERT(strcasecmp(disc_log->entries[0].traddr, rdma_trid_3.traddr) == 0);
	CU_ASSERT(strcasecmp(disc_log->entries[1].traddr, tcp_trid_4.traddr) == 0);
	CU_ASSERT(strcasecmp(disc_log->entries[2].traddr, rdma_trid_4.traddr) == 0);
	CU_ASSERT(strcasecmp(disc_log->entries[0].trsvcid, rdma_trid_3.trsvcid) == 0);
	CU_ASSERT(strcasecmp(disc_log->entries[1].trsvcid, tcp_trid_4.trsvcid) == 0);
	CU_ASSERT(strcasecmp(disc_log->entries[2].trsvcid, rdma_trid_4.trsvcid) == 0);
	CU_ASSERT(disc_log->entries[0].trtype == rdma_trid_3.trtype);
	CU_ASSERT(disc_log->entries[1].trtype == tcp_trid_4.trtype);
	CU_ASSERT(disc_log->entries[2].trtype == rdma_trid_4.trtype);

	nvmf_get_discovery_log_page(&tgt, hostnqn, &iov, 1, 0, 8192, &tcp_trid_1);
	CU_ASSERT(disc_log->numrec == 3);
	CU_ASSERT(strcasecmp(disc_log->entries[0].traddr, tcp_trid_1.traddr) == 0);
	CU_ASSERT(strcasecmp(disc_log->entries[1].traddr, tcp_trid_4.traddr) == 0);
	CU_ASSERT(strcasecmp(disc_log->entries[2].traddr, rdma_trid_4.traddr) == 0);
	CU_ASSERT(strcasecmp(disc_log->entries[0].trsvcid, tcp_trid_1.trsvcid) == 0);
	CU_ASSERT(strcasecmp(disc_log->entries[1].trsvcid, tcp_trid_4.trsvcid) == 0);
	CU_ASSERT(strcasecmp(disc_log->entries[2].trsvcid, rdma_trid_4.trsvcid) == 0);
	CU_ASSERT(disc_log->entries[0].trtype == tcp_trid_1.trtype);
	CU_ASSERT(disc_log->entries[1].trtype == tcp_trid_4.trtype);
	CU_ASSERT(disc_log->entries[2].trtype == rdma_trid_4.trtype);

	nvmf_get_discovery_log_page(&tgt, hostnqn, &iov, 1, 0, 8192, &tcp_trid_2);
	CU_ASSERT(disc_log->numrec == 3);
	CU_ASSERT(strcasecmp(disc_log->entries[0].traddr, tcp_trid_2.traddr) == 0);
	CU_ASSERT(strcasecmp(disc_log->entries[1].traddr, tcp_trid_4.traddr) == 0);
	CU_ASSERT(strcasecmp(disc_log->entries[2].traddr, rdma_trid_4.traddr) == 0);
	CU_ASSERT(strcasecmp(disc_log->entries[0].trsvcid, tcp_trid_2.trsvcid) == 0);
	CU_ASSERT(strcasecmp(disc_log->entries[1].trsvcid, tcp_trid_4.trsvcid) == 0);
	CU_ASSERT(strcasecmp(disc_log->entries[2].trsvcid, rdma_trid_4.trsvcid) == 0);
	CU_ASSERT(disc_log->entries[0].trtype == tcp_trid_2.trtype);
	CU_ASSERT(disc_log->entries[1].trtype == tcp_trid_4.trtype);
	CU_ASSERT(disc_log->entries[2].trtype == rdma_trid_4.trtype);

	nvmf_get_discovery_log_page(&tgt, hostnqn, &iov, 1, 0, 8192, &tcp_trid_3);
	CU_ASSERT(disc_log->numrec == 3);
	CU_ASSERT(strcasecmp(disc_log->entries[0].traddr, tcp_trid_3.traddr) == 0);
	CU_ASSERT(strcasecmp(disc_log->entries[1].traddr, tcp_trid_4.traddr) == 0);
	CU_ASSERT(strcasecmp(disc_log->entries[2].traddr, rdma_trid_4.traddr) == 0);
	CU_ASSERT(strcasecmp(disc_log->entries[0].trsvcid, tcp_trid_3.trsvcid) == 0);
	CU_ASSERT(strcasecmp(disc_log->entries[1].trsvcid, tcp_trid_4.trsvcid) == 0);
	CU_ASSERT(strcasecmp(disc_log->entries[2].trsvcid, rdma_trid_4.trsvcid) == 0);
	CU_ASSERT(disc_log->entries[0].trtype == tcp_trid_3.trtype);
	CU_ASSERT(disc_log->entries[1].trtype == tcp_trid_4.trtype);
	CU_ASSERT(disc_log->entries[2].trtype == rdma_trid_4.trtype);

	/* Test case 7 - check that only entries of the same transport address, svcid and type returned */
	tgt.discovery_filter = SPDK_NVMF_TGT_DISCOVERY_MATCH_TRANSPORT_TYPE |
			       SPDK_NVMF_TGT_DISCOVERY_MATCH_TRANSPORT_ADDRESS |
			       SPDK_NVMF_TGT_DISCOVERY_MATCH_TRANSPORT_SVCID;
	nvmf_get_discovery_log_page(&tgt, hostnqn, &iov, 1, 0, 8192, &rdma_trid_1);
	CU_ASSERT(disc_log->numrec == 3);
	CU_ASSERT(strcasecmp(disc_log->entries[0].traddr, rdma_trid_1.traddr) == 0);
	CU_ASSERT(strcasecmp(disc_log->entries[1].traddr, tcp_trid_4.traddr) == 0);
	CU_ASSERT(strcasecmp(disc_log->entries[2].traddr, rdma_trid_4.traddr) == 0);
	CU_ASSERT(strcasecmp(disc_log->entries[0].trsvcid, rdma_trid_1.trsvcid) == 0);
	CU_ASSERT(strcasecmp(disc_log->entries[1].trsvcid, tcp_trid_4.trsvcid) == 0);
	CU_ASSERT(strcasecmp(disc_log->entries[2].trsvcid, rdma_trid_4.trsvcid) == 0);
	CU_ASSERT(disc_log->entries[0].trtype == rdma_trid_1.trtype);
	CU_ASSERT(disc_log->entries[1].trtype == tcp_trid_4.trtype);
	CU_ASSERT(disc_log->entries[2].trtype == rdma_trid_4.trtype);

	nvmf_get_discovery_log_page(&tgt, hostnqn, &iov, 1, 0, 8192, &rdma_trid_2);
	CU_ASSERT(disc_log->numrec == 3);
	CU_ASSERT(strcasecmp(disc_log->entries[0].traddr, rdma_trid_2.traddr) == 0);
	CU_ASSERT(strcasecmp(disc_log->entries[1].traddr, tcp_trid_4.traddr) == 0);
	CU_ASSERT(strcasecmp(disc_log->entries[2].traddr, rdma_trid_4.traddr) == 0);
	CU_ASSERT(strcasecmp(disc_log->entries[0].trsvcid, rdma_trid_2.trsvcid) == 0);
	CU_ASSERT(strcasecmp(disc_log->entries[1].trsvcid, tcp_trid_4.trsvcid) == 0);
	CU_ASSERT(strcasecmp(disc_log->entries[2].trsvcid, rdma_trid_4.trsvcid) == 0);
	CU_ASSERT(disc_log->entries[0].trtype == rdma_trid_2.trtype);
	CU_ASSERT(disc_log->entries[1].trtype == tcp_trid_4.trtype);
	CU_ASSERT(disc_log->entries[2].trtype == rdma_trid_4.trtype);

	nvmf_get_discovery_log_page(&tgt, hostnqn, &iov, 1, 0, 8192, &rdma_trid_3);
	CU_ASSERT(disc_log->numrec == 3);
	CU_ASSERT(strcasecmp(disc_log->entries[0].traddr, rdma_trid_3.traddr) == 0);
	CU_ASSERT(strcasecmp(disc_log->entries[1].traddr, tcp_trid_4.traddr) == 0);
	CU_ASSERT(strcasecmp(disc_log->entries[2].traddr, rdma_trid_4.traddr) == 0);
	CU_ASSERT(strcasecmp(disc_log->entries[0].trsvcid, rdma_trid_3.trsvcid) == 0);
	CU_ASSERT(strcasecmp(disc_log->entries[1].trsvcid, tcp_trid_4.trsvcid) == 0);
	CU_ASSERT(strcasecmp(disc_log->entries[2].trsvcid, rdma_trid_4.trsvcid) == 0);
	CU_ASSERT(disc_log->entries[0].trtype == rdma_trid_3.trtype);
	CU_ASSERT(disc_log->entries[1].trtype == tcp_trid_4.trtype);
	CU_ASSERT(disc_log->entries[2].trtype == rdma_trid_4.trtype);

	nvmf_get_discovery_log_page(&tgt, hostnqn, &iov, 1, 0, 8192, &tcp_trid_1);
	CU_ASSERT(disc_log->numrec == 3);
	CU_ASSERT(strcasecmp(disc_log->entries[0].traddr, tcp_trid_1.traddr) == 0);
	CU_ASSERT(strcasecmp(disc_log->entries[1].traddr, tcp_trid_4.traddr) == 0);
	CU_ASSERT(strcasecmp(disc_log->entries[2].traddr, rdma_trid_4.traddr) == 0);
	CU_ASSERT(strcasecmp(disc_log->entries[0].trsvcid, tcp_trid_1.trsvcid) == 0);
	CU_ASSERT(strcasecmp(disc_log->entries[1].trsvcid, tcp_trid_4.trsvcid) == 0);
	CU_ASSERT(strcasecmp(disc_log->entries[2].trsvcid, rdma_trid_4.trsvcid) == 0);
	CU_ASSERT(disc_log->entries[0].trtype == tcp_trid_1.trtype);
	CU_ASSERT(disc_log->entries[1].trtype == tcp_trid_4.trtype);
	CU_ASSERT(disc_log->entries[2].trtype == rdma_trid_4.trtype);

	nvmf_get_discovery_log_page(&tgt, hostnqn, &iov, 1, 0, 8192, &tcp_trid_2);
	CU_ASSERT(disc_log->numrec == 3);
	CU_ASSERT(strcasecmp(disc_log->entries[0].traddr, tcp_trid_2.traddr) == 0);
	CU_ASSERT(strcasecmp(disc_log->entries[1].traddr, tcp_trid_4.traddr) == 0);
	CU_ASSERT(strcasecmp(disc_log->entries[2].traddr, rdma_trid_4.traddr) == 0);
	CU_ASSERT(strcasecmp(disc_log->entries[0].trsvcid, tcp_trid_2.trsvcid) == 0);
	CU_ASSERT(strcasecmp(disc_log->entries[1].trsvcid, tcp_trid_4.trsvcid) == 0);
	CU_ASSERT(strcasecmp(disc_log->entries[2].trsvcid, rdma_trid_4.trsvcid) == 0);
	CU_ASSERT(disc_log->entries[0].trtype == tcp_trid_2.trtype);
	CU_ASSERT(disc_log->entries[1].trtype == tcp_trid_4.trtype);
	CU_ASSERT(disc_log->entries[2].trtype == rdma_trid_4.trtype);

	nvmf_get_discovery_log_page(&tgt, hostnqn, &iov, 1, 0, 8192, &tcp_trid_3);
	CU_ASSERT(disc_log->numrec == 3);
	CU_ASSERT(strcasecmp(disc_log->entries[0].traddr, tcp_trid_3.traddr) == 0);
	CU_ASSERT(strcasecmp(disc_log->entries[1].traddr, tcp_trid_4.traddr) == 0);
	CU_ASSERT(strcasecmp(disc_log->entries[2].traddr, rdma_trid_4.traddr) == 0);
	CU_ASSERT(strcasecmp(disc_log->entries[0].trsvcid, tcp_trid_3.trsvcid) == 0);
	CU_ASSERT(strcasecmp(disc_log->entries[1].trsvcid, tcp_trid_4.trsvcid) == 0);
	CU_ASSERT(strcasecmp(disc_log->entries[2].trsvcid, rdma_trid_4.trsvcid) == 0);
	CU_ASSERT(disc_log->entries[0].trtype == tcp_trid_3.trtype);
	CU_ASSERT(disc_log->entries[1].trtype == tcp_trid_4.trtype);
	CU_ASSERT(disc_log->entries[2].trtype == rdma_trid_4.trtype);

	subsystem->state = SPDK_NVMF_SUBSYSTEM_INACTIVE;
	spdk_nvmf_subsystem_destroy(subsystem, NULL, NULL);
	spdk_bit_array_free(&tgt.subsystem_ids);
}

int
main(int argc, char **argv)
{
	CU_pSuite	suite = NULL;
	unsigned int	num_failures;

	CU_initialize_registry();

	suite = CU_add_suite("nvmf", NULL, NULL);

	CU_ADD_TEST(suite, test_discovery_log);
	CU_ADD_TEST(suite, test_discovery_log_with_filters);

	num_failures = spdk_ut_run_tests(argc, argv, NULL);
	CU_cleanup_registry();
	return num_failures;
}
