/*   SPDX-License-Identifier: BSD-3-Clause
 *   Copyright (c) 2023 NVIDIA CORPORATION & AFFILIATES. All rights reserved.
 */

#include "spdk/stdinc.h"

#include "spdk_internal/cunit.h"
#include "common/lib/ut_multithread.c"

static void ut_put_io_channel(struct spdk_io_channel *ch);

#define spdk_put_io_channel(ch) ut_put_io_channel(ch);
#include "blob/bdev/blob_bdev.c"

DEFINE_STUB(spdk_bdev_io_type_supported, bool, (struct spdk_bdev *bdev,
		enum spdk_bdev_io_type io_type), false);
DEFINE_STUB_V(spdk_bdev_free_io, (struct spdk_bdev_io *g_bdev_io));
DEFINE_STUB(spdk_bdev_queue_io_wait, int,
	    (struct spdk_bdev *bdev, struct spdk_io_channel *ch,
	     struct spdk_bdev_io_wait_entry *entry), 0);
DEFINE_STUB(spdk_bdev_read_blocks, int,
	    (struct spdk_bdev_desc *desc, struct spdk_io_channel *ch, void *buf,
	     uint64_t offset_blocks, uint64_t num_blocks, spdk_bdev_io_completion_cb cb,
	     void *cb_arg), 0);
DEFINE_STUB(spdk_bdev_write_blocks, int,
	    (struct spdk_bdev_desc *desc, struct spdk_io_channel *ch, void *buf,
	     uint64_t offset_blocks, uint64_t num_blocks, spdk_bdev_io_completion_cb cb,
	     void *cb_arg), 0);
DEFINE_STUB(spdk_bdev_readv_blocks, int,
	    (struct spdk_bdev_desc *desc, struct spdk_io_channel *ch, struct iovec *iov, int iovcnt,
	     uint64_t offset_blocks, uint64_t num_blocks, spdk_bdev_io_completion_cb cb,
	     void *cb_arg), 0);
DEFINE_STUB(spdk_bdev_writev_blocks, int,
	    (struct spdk_bdev_desc *desc, struct spdk_io_channel *ch, struct iovec *iov, int iovcnt,
	     uint64_t offset_blocks, uint64_t num_blocks, spdk_bdev_io_completion_cb cb,
	     void *cb_arg), 0);
DEFINE_STUB(spdk_bdev_readv_blocks_ext, int,
	    (struct spdk_bdev_desc *desc, struct spdk_io_channel *ch, struct iovec *iov, int iovcnt,
	     uint64_t offset_blocks, uint64_t num_blocks, spdk_bdev_io_completion_cb cb,
	     void *cb_arg, struct spdk_bdev_ext_io_opts *opts), 0);
DEFINE_STUB(spdk_bdev_writev_blocks_ext, int,
	    (struct spdk_bdev_desc *desc, struct spdk_io_channel *ch, struct iovec *iov, int iovcnt,
	     uint64_t offset_blocks, uint64_t num_blocks, spdk_bdev_io_completion_cb cb,
	     void *cb_arg, struct spdk_bdev_ext_io_opts *opts), 0);
DEFINE_STUB(spdk_bdev_write_zeroes_blocks, int,
	    (struct spdk_bdev_desc *desc, struct spdk_io_channel *ch, uint64_t offset_blocks,
	     uint64_t num_blocks, spdk_bdev_io_completion_cb cb, void *cb_arg), 0);
DEFINE_STUB(spdk_bdev_unmap_blocks, int,
	    (struct spdk_bdev_desc *desc, struct spdk_io_channel *ch, uint64_t offset_blocks,
	     uint64_t num_blocks, spdk_bdev_io_completion_cb cb, void *cb_arg), 0);
DEFINE_STUB(spdk_bdev_copy_blocks, int,
	    (struct spdk_bdev_desc *desc, struct spdk_io_channel *ch, uint64_t dst_offset_blocks,
	     uint64_t src_offset_blocks, uint64_t num_blocks, spdk_bdev_io_completion_cb cb,
	     void *cb_arg), 0);

struct spdk_bdev {
	char name[16];
	uint64_t blockcnt;
	uint32_t blocklen;
	uint32_t phys_blocklen;
	uint32_t open_cnt;
	enum spdk_bdev_claim_type claim_type;
	struct spdk_bdev_module *claim_module;
	struct spdk_bdev_desc *claim_desc;
};

struct spdk_bdev_desc {
	struct spdk_bdev *bdev;
	bool write;
	enum spdk_bdev_claim_type claim_type;
	struct spdk_thread *thread;
};

struct spdk_bdev *g_bdev;

static struct spdk_bdev_module g_bdev_mod = {
	.name = "blob_bdev_ut"
};

struct spdk_io_channel *
spdk_bdev_get_io_channel(struct spdk_bdev_desc *desc)
{
	if (desc != NULL) {
		return (struct spdk_io_channel *)0x1;
	}
	return NULL;
}

static void
ut_put_io_channel(struct spdk_io_channel *ch)
{
}

static struct spdk_bdev *
get_bdev(const char *bdev_name)
{
	if (g_bdev == NULL) {
		return NULL;
	}

	if (strcmp(bdev_name, g_bdev->name) != 0) {
		return NULL;
	}

	return g_bdev;
}

int
spdk_bdev_open_ext(const char *bdev_name, bool write, spdk_bdev_event_cb_t event_cb,
		   void *event_ctx, struct spdk_bdev_desc **_desc)
{
	struct spdk_bdev_desc *desc;
	struct spdk_bdev *bdev = get_bdev(bdev_name);

	if (bdev == NULL) {
		return -ENODEV;
	}

	if (write && bdev->claim_module != NULL) {
		return -EPERM;
	}

	desc = calloc(1, sizeof(*desc));
	desc->bdev = g_bdev;
	desc->write = write;
	desc->thread = spdk_get_thread();
	*_desc = desc;
	bdev->open_cnt++;

	return 0;
}

void
spdk_bdev_close(struct spdk_bdev_desc *desc)
{
	struct spdk_bdev *bdev = desc->bdev;

	CU_ASSERT(desc->thread == spdk_get_thread());

	bdev->open_cnt--;
	if (bdev->claim_desc == desc) {
		bdev->claim_desc = NULL;
		bdev->claim_type = SPDK_BDEV_CLAIM_NONE;
		bdev->claim_module = NULL;
	}
	free(desc);
}

struct spdk_bdev *
spdk_bdev_desc_get_bdev(struct spdk_bdev_desc *desc)
{
	return desc->bdev;
}

uint64_t
spdk_bdev_get_num_blocks(const struct spdk_bdev *bdev)
{
	return bdev->blockcnt;
}

uint32_t
spdk_bdev_get_block_size(const struct spdk_bdev *bdev)
{
	return bdev->blocklen;
}

uint32_t
spdk_bdev_get_physical_block_size(const struct spdk_bdev *bdev)
{
	return bdev->phys_blocklen;
}

/* This is a simple approximation: it does not support shared claims */
int
spdk_bdev_module_claim_bdev_desc(struct spdk_bdev_desc *desc, enum spdk_bdev_claim_type type,
				 struct spdk_bdev_claim_opts *opts,
				 struct spdk_bdev_module *module)
{
	struct spdk_bdev *bdev = desc->bdev;

	if (bdev->claim_module != NULL) {
		return -EPERM;
	}

	bdev->claim_type = type;
	bdev->claim_module = module;
	bdev->claim_desc = desc;

	desc->claim_type = type;

	return 0;
}

static void
init_bdev(struct spdk_bdev *bdev, const char *name, uint64_t num_blocks)
{
	memset(bdev, 0, sizeof(*bdev));
	snprintf(bdev->name, sizeof(bdev->name), "%s", name);
	bdev->blockcnt = num_blocks;
}

static void
create_bs_dev(void)
{
	struct spdk_bdev bdev;
	struct spdk_bs_dev *bs_dev = NULL;
	struct blob_bdev *blob_bdev;
	int rc;

	init_bdev(&bdev, "bdev0", 16);
	g_bdev = &bdev;

	rc = spdk_bdev_create_bs_dev_ext("bdev0", NULL, NULL, &bs_dev);
	CU_ASSERT(rc == 0);
	SPDK_CU_ASSERT_FATAL(bs_dev != NULL);
	CU_ASSERT(bdev.open_cnt == 1);

	blob_bdev = (struct blob_bdev *)bs_dev;
	CU_ASSERT(blob_bdev->desc != NULL);
	CU_ASSERT(blob_bdev->desc->write);
	CU_ASSERT(blob_bdev->desc->bdev == g_bdev);
	CU_ASSERT(blob_bdev->desc->claim_type == SPDK_BDEV_CLAIM_NONE);
	CU_ASSERT(bdev.claim_type == SPDK_BDEV_CLAIM_NONE);

	bs_dev->destroy(bs_dev);
	CU_ASSERT(bdev.open_cnt == 0);
	g_bdev = NULL;
}

static void
create_bs_dev_ro(void)
{
	struct spdk_bdev bdev;
	struct spdk_bs_dev *bs_dev = NULL;
	struct blob_bdev *blob_bdev;
	struct spdk_bdev_bs_dev_opts opts = { 0 };
	int rc;

	/* opts with the wrong size returns -EINVAL */
	rc = spdk_bdev_create_bs_dev("nope", false, &opts, sizeof(opts) + 8, NULL, NULL, &bs_dev);
	CU_ASSERT(rc == -EINVAL);

	/* opts with the right size is OK, but can still fail if the device doesn't exist. */
	opts.opts_size = sizeof(opts);
	rc = spdk_bdev_create_bs_dev("nope", false, &opts, sizeof(opts), NULL, NULL, &bs_dev);
	CU_ASSERT(rc == -ENODEV);

	init_bdev(&bdev, "bdev0", 16);
	g_bdev = &bdev;

	/* The normal way to create a read-only device */
	rc = spdk_bdev_create_bs_dev("bdev0", false, NULL, 0, NULL, NULL, &bs_dev);
	CU_ASSERT(rc == 0);
	SPDK_CU_ASSERT_FATAL(bs_dev != NULL);
	CU_ASSERT(bdev.open_cnt == 1);

	blob_bdev = (struct blob_bdev *)bs_dev;
	CU_ASSERT(blob_bdev->desc != NULL);
	CU_ASSERT(!blob_bdev->desc->write);
	CU_ASSERT(blob_bdev->desc->bdev == g_bdev);
	CU_ASSERT(blob_bdev->desc->claim_type == SPDK_BDEV_CLAIM_NONE);
	CU_ASSERT(bdev.claim_type == SPDK_BDEV_CLAIM_NONE);

	bs_dev->destroy(bs_dev);
	CU_ASSERT(bdev.open_cnt == 0);
	g_bdev = NULL;
}

static void
create_bs_dev_rw(void)
{
	struct spdk_bdev bdev;
	struct spdk_bs_dev *bs_dev = NULL;
	struct blob_bdev *blob_bdev;
	int rc;

	init_bdev(&bdev, "bdev0", 16);
	g_bdev = &bdev;

	/* This is equivalent to spdk_bdev_create_bs_dev_ext() */
	rc = spdk_bdev_create_bs_dev("bdev0", true, NULL, 0, NULL, NULL, &bs_dev);
	CU_ASSERT(rc == 0);
	SPDK_CU_ASSERT_FATAL(bs_dev != NULL);
	CU_ASSERT(bdev.open_cnt == 1);

	blob_bdev = (struct blob_bdev *)bs_dev;
	CU_ASSERT(blob_bdev->desc != NULL);
	CU_ASSERT(blob_bdev->desc->write);
	CU_ASSERT(blob_bdev->desc->bdev == g_bdev);
	CU_ASSERT(blob_bdev->desc->claim_type == SPDK_BDEV_CLAIM_NONE);
	CU_ASSERT(bdev.claim_type == SPDK_BDEV_CLAIM_NONE);

	bs_dev->destroy(bs_dev);
	CU_ASSERT(bdev.open_cnt == 0);
	g_bdev = NULL;
}

static void
claim_bs_dev(void)
{
	struct spdk_bdev bdev;
	struct spdk_bs_dev *bs_dev = NULL, *bs_dev2 = NULL;
	struct blob_bdev *blob_bdev;
	int rc;

	init_bdev(&bdev, "bdev0", 16);
	g_bdev = &bdev;

	rc = spdk_bdev_create_bs_dev_ext("bdev0", NULL, NULL, &bs_dev);
	CU_ASSERT(rc == 0);
	SPDK_CU_ASSERT_FATAL(bs_dev != NULL);

	blob_bdev = (struct blob_bdev *)bs_dev;
	CU_ASSERT(blob_bdev->desc->claim_type == SPDK_BDEV_CLAIM_NONE);
	CU_ASSERT(bdev.claim_type == SPDK_BDEV_CLAIM_NONE);
	CU_ASSERT(blob_bdev->desc->write);

	/* Can get an exclusive write claim */
	rc = spdk_bs_bdev_claim(bs_dev, &g_bdev_mod);
	CU_ASSERT(rc == 0);
	CU_ASSERT(blob_bdev->desc->write);
	CU_ASSERT(bdev.claim_type == SPDK_BDEV_CLAIM_READ_MANY_WRITE_ONE);
	CU_ASSERT(bdev.claim_desc == blob_bdev->desc);

	/* Claim blocks a second writer without messing up the first one. */
	rc = spdk_bdev_create_bs_dev_ext("bdev0", NULL, NULL, &bs_dev2);
	CU_ASSERT(rc == -EPERM);
	CU_ASSERT(bdev.claim_type == SPDK_BDEV_CLAIM_READ_MANY_WRITE_ONE);
	CU_ASSERT(bdev.claim_desc == blob_bdev->desc);

	/* Claim blocks a second claim without messing up the first one. */
	rc = spdk_bs_bdev_claim(bs_dev, &g_bdev_mod);
	CU_ASSERT(rc == -EPERM);
	CU_ASSERT(bdev.claim_type == SPDK_BDEV_CLAIM_READ_MANY_WRITE_ONE);
	CU_ASSERT(bdev.claim_desc == blob_bdev->desc);

	bs_dev->destroy(bs_dev);
	CU_ASSERT(bdev.open_cnt == 0);
	CU_ASSERT(bdev.claim_type == SPDK_BDEV_CLAIM_NONE);
	CU_ASSERT(bdev.claim_module == NULL);
	CU_ASSERT(bdev.claim_desc == NULL);
	g_bdev = NULL;
}

static void
claim_bs_dev_ro(void)
{
	struct spdk_bdev bdev;
	struct spdk_bs_dev *bs_dev = NULL, *bs_dev2 = NULL;
	struct blob_bdev *blob_bdev;
	int rc;

	init_bdev(&bdev, "bdev0", 16);
	g_bdev = &bdev;

	rc = spdk_bdev_create_bs_dev("bdev0", false, NULL, 0, NULL, NULL, &bs_dev);
	CU_ASSERT(rc == 0);
	SPDK_CU_ASSERT_FATAL(bs_dev != NULL);

	blob_bdev = (struct blob_bdev *)bs_dev;
	CU_ASSERT(blob_bdev->desc->claim_type == SPDK_BDEV_CLAIM_NONE);
	CU_ASSERT(bdev.claim_type == SPDK_BDEV_CLAIM_NONE);
	CU_ASSERT(!blob_bdev->desc->write);

	/* Can get an shared reader claim */
	rc = spdk_bs_bdev_claim(bs_dev, &g_bdev_mod);
	CU_ASSERT(rc == 0);
	CU_ASSERT(!blob_bdev->desc->write);
	CU_ASSERT(bdev.claim_type == SPDK_BDEV_CLAIM_READ_MANY_WRITE_NONE);
	CU_ASSERT(bdev.claim_desc == blob_bdev->desc);

	/* Claim blocks a writer without messing up the claim. */
	rc = spdk_bdev_create_bs_dev_ext("bdev0", NULL, NULL, &bs_dev2);
	CU_ASSERT(rc == -EPERM);
	CU_ASSERT(bdev.claim_type == SPDK_BDEV_CLAIM_READ_MANY_WRITE_NONE);
	CU_ASSERT(bdev.claim_desc == blob_bdev->desc);

	/* Another reader is just fine */
	rc = spdk_bdev_create_bs_dev("bdev0", false, NULL, 0, NULL, NULL, &bs_dev2);
	CU_ASSERT(rc == 0);
	SPDK_CU_ASSERT_FATAL(bs_dev2 != NULL);
	bs_dev2->destroy(bs_dev2);

	bs_dev->destroy(bs_dev);
	CU_ASSERT(bdev.open_cnt == 0);
	CU_ASSERT(bdev.claim_type == SPDK_BDEV_CLAIM_NONE);
	CU_ASSERT(bdev.claim_module == NULL);
	CU_ASSERT(bdev.claim_desc == NULL);
	g_bdev = NULL;
}

/*
 * Verify that create_channel() and destroy_channel() increment and decrement the blob_bdev->refs.
 */
static void
deferred_destroy_refs(void)
{
	struct spdk_bdev bdev;
	struct spdk_io_channel *ch1, *ch2;
	struct spdk_bs_dev *bs_dev = NULL;
	struct blob_bdev *blob_bdev;
	int rc;

	set_thread(0);
	init_bdev(&bdev, "bdev0", 16);
	g_bdev = &bdev;

	/* Open a blob_bdev, verify reference count is 1. */
	rc = spdk_bdev_create_bs_dev("bdev0", false, NULL, 0, NULL, NULL, &bs_dev);
	CU_ASSERT(rc == 0);
	SPDK_CU_ASSERT_FATAL(bs_dev != NULL);
	blob_bdev = (struct blob_bdev *)bs_dev;
	CU_ASSERT(blob_bdev->refs == 1);
	CU_ASSERT(blob_bdev->desc != NULL);

	/* Verify reference count increases with channels on the same thread. */
	ch1 = bs_dev->create_channel(bs_dev);
	SPDK_CU_ASSERT_FATAL(ch1 != NULL);
	CU_ASSERT(blob_bdev->refs == 2);
	ch2 = bs_dev->create_channel(bs_dev);
	SPDK_CU_ASSERT_FATAL(ch2 != NULL);
	CU_ASSERT(blob_bdev->refs == 3);
	bs_dev->destroy_channel(bs_dev, ch1);
	CU_ASSERT(blob_bdev->refs == 2);
	bs_dev->destroy_channel(bs_dev, ch2);
	CU_ASSERT(blob_bdev->refs == 1);
	CU_ASSERT(blob_bdev->desc != NULL);

	/* Verify reference count increases with channels on different threads. */
	ch1 = bs_dev->create_channel(bs_dev);
	SPDK_CU_ASSERT_FATAL(ch1 != NULL);
	CU_ASSERT(blob_bdev->refs == 2);
	set_thread(1);
	ch2 = bs_dev->create_channel(bs_dev);
	SPDK_CU_ASSERT_FATAL(ch2 != NULL);
	CU_ASSERT(blob_bdev->refs == 3);
	bs_dev->destroy_channel(bs_dev, ch1);
	CU_ASSERT(blob_bdev->refs == 2);
	bs_dev->destroy_channel(bs_dev, ch2);
	CU_ASSERT(blob_bdev->refs == 1);
	CU_ASSERT(blob_bdev->desc != NULL);

	set_thread(0);
	bs_dev->destroy(bs_dev);
	g_bdev = NULL;
}

/*
 * When a channel is open bs_dev->destroy() should not free bs_dev until after the last channel is
 * closed. Further, destroy() prevents the creation of new channels.
 */
static void
deferred_destroy_channels(void)
{
	struct spdk_bdev bdev;
	struct spdk_io_channel *ch1, *ch2;
	struct spdk_bs_dev *bs_dev = NULL;
	struct blob_bdev *blob_bdev;
	int rc;

	set_thread(0);
	init_bdev(&bdev, "bdev0", 16);

	/* Open bs_dev and sanity check */
	g_bdev = &bdev;
	rc = spdk_bdev_create_bs_dev("bdev0", false, NULL, 0, NULL, NULL, &bs_dev);
	CU_ASSERT(rc == 0);
	SPDK_CU_ASSERT_FATAL(bs_dev != NULL);
	CU_ASSERT(bdev.open_cnt == 1);
	blob_bdev = (struct blob_bdev *)bs_dev;
	CU_ASSERT(blob_bdev->refs == 1);
	CU_ASSERT(blob_bdev->desc != NULL);

	/* Create a channel, destroy the bs_dev. It should not be freed yet. */
	ch1 = bs_dev->create_channel(bs_dev);
	SPDK_CU_ASSERT_FATAL(ch1 != NULL);
	CU_ASSERT(blob_bdev->refs == 2);
	bs_dev->destroy(bs_dev);

	/* Destroy closes the bdev and prevents desc from being used for creating more channels. */
	CU_ASSERT(blob_bdev->desc == NULL);
	CU_ASSERT(bdev.open_cnt == 0);
	CU_ASSERT(blob_bdev->refs == 1);
	ch2 = bs_dev->create_channel(bs_dev);
	CU_ASSERT(ch2 == NULL)
	CU_ASSERT(blob_bdev->refs == 1);
	bs_dev->destroy_channel(bs_dev, ch1);
	g_bdev = NULL;

	/* Now bs_dev should have been freed. Builds with asan will verify. */
}

/*
 * Verify that deferred destroy copes well with the last channel destruction being on a thread other
 * than the thread used to obtain the bdev descriptor.
 */
static void
deferred_destroy_threads(void)
{
	struct spdk_bdev bdev;
	struct spdk_io_channel *ch1, *ch2;
	struct spdk_bs_dev *bs_dev = NULL;
	struct blob_bdev *blob_bdev;
	int rc;

	set_thread(0);
	init_bdev(&bdev, "bdev0", 16);
	g_bdev = &bdev;

	/* Open bs_dev and sanity check */
	rc = spdk_bdev_create_bs_dev("bdev0", false, NULL, 0, NULL, NULL, &bs_dev);
	CU_ASSERT(rc == 0);
	SPDK_CU_ASSERT_FATAL(bs_dev != NULL);
	CU_ASSERT(bdev.open_cnt == 1);
	blob_bdev = (struct blob_bdev *)bs_dev;
	CU_ASSERT(blob_bdev->refs == 1);
	CU_ASSERT(blob_bdev->desc != NULL);

	/* Create two channels, each on their own thread. */
	ch1 = bs_dev->create_channel(bs_dev);
	SPDK_CU_ASSERT_FATAL(ch1 != NULL);
	CU_ASSERT(blob_bdev->refs == 2);
	CU_ASSERT(spdk_get_thread() == blob_bdev->desc->thread);
	set_thread(1);
	ch2 = bs_dev->create_channel(bs_dev);
	SPDK_CU_ASSERT_FATAL(ch2 != NULL);
	CU_ASSERT(blob_bdev->refs == 3);

	/* Destroy the bs_dev on thread 0, the channel on thread 0, then the channel on thread 1. */
	set_thread(0);
	bs_dev->destroy(bs_dev);
	CU_ASSERT(blob_bdev->desc == NULL);
	CU_ASSERT(bdev.open_cnt == 0);
	CU_ASSERT(blob_bdev->refs == 2);
	bs_dev->destroy_channel(bs_dev, ch1);
	CU_ASSERT(blob_bdev->refs == 1);
	set_thread(1);
	bs_dev->destroy_channel(bs_dev, ch2);
	set_thread(0);
	g_bdev = NULL;

	/* Now bs_dev should have been freed. Builds with asan will verify. */
}

int
main(int argc, char **argv)
{
	CU_pSuite	suite;
	unsigned int	num_failures;

	CU_initialize_registry();

	suite = CU_add_suite("blob_bdev", NULL, NULL);

	CU_ADD_TEST(suite, create_bs_dev);
	CU_ADD_TEST(suite, create_bs_dev_ro);
	CU_ADD_TEST(suite, create_bs_dev_rw);
	CU_ADD_TEST(suite, claim_bs_dev);
	CU_ADD_TEST(suite, claim_bs_dev_ro);
	CU_ADD_TEST(suite, deferred_destroy_refs);
	CU_ADD_TEST(suite, deferred_destroy_channels);
	CU_ADD_TEST(suite, deferred_destroy_threads);

	allocate_threads(2);
	set_thread(0);

	num_failures = spdk_ut_run_tests(argc, argv, NULL);
	CU_cleanup_registry();

	free_threads();

	return num_failures;
}
