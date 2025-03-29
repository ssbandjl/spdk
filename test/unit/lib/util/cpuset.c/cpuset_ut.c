/*   SPDX-License-Identifier: BSD-3-Clause
 *   Copyright (C) 2017 Intel Corporation.
 *   All rights reserved.
 */

#include "spdk/stdinc.h"
#include "spdk/cpuset.h"

#include "spdk_internal/cunit.h"

#include "util/cpuset.c"

static int
cpuset_check_range(struct spdk_cpuset *core_mask, uint32_t min, uint32_t max, bool isset)
{
	uint32_t core;
	for (core = min; core <= max; core++) {
		if (isset != spdk_cpuset_get_cpu(core_mask, core)) {
			return -1;
		}
	}
	return 0;
}

static void
test_cpuset(void)
{
	uint32_t cpu;
	struct spdk_cpuset *set = spdk_cpuset_alloc();

	SPDK_CU_ASSERT_FATAL(set != NULL);
	CU_ASSERT(spdk_cpuset_count(set) == 0);

	/* Set cpu 0 */
	spdk_cpuset_set_cpu(set, 0, true);
	CU_ASSERT(spdk_cpuset_get_cpu(set, 0) == true);
	CU_ASSERT(cpuset_check_range(set, 1, SPDK_CPUSET_SIZE - 1, false) == 0);
	CU_ASSERT(spdk_cpuset_count(set) == 1);

	/* Set last cpu (cpu 0 already set) */
	spdk_cpuset_set_cpu(set, SPDK_CPUSET_SIZE - 1, true);
	CU_ASSERT(spdk_cpuset_get_cpu(set, 0) == true);
	CU_ASSERT(spdk_cpuset_get_cpu(set, SPDK_CPUSET_SIZE - 1) == true);
	CU_ASSERT(cpuset_check_range(set, 1, SPDK_CPUSET_SIZE - 2, false) == 0);
	CU_ASSERT(spdk_cpuset_count(set) == 2);

	/* Clear cpu 0 (last cpu already set) */
	spdk_cpuset_set_cpu(set, 0, false);
	CU_ASSERT(spdk_cpuset_get_cpu(set, 0) == false);
	CU_ASSERT(cpuset_check_range(set, 1, SPDK_CPUSET_SIZE - 2, false) == 0);
	CU_ASSERT(spdk_cpuset_get_cpu(set, SPDK_CPUSET_SIZE - 1) == true);
	CU_ASSERT(spdk_cpuset_count(set) == 1);

	/* Set middle cpu (last cpu already set) */
	cpu = (SPDK_CPUSET_SIZE - 1) / 2;
	spdk_cpuset_set_cpu(set, cpu, true);
	CU_ASSERT(spdk_cpuset_get_cpu(set, cpu) == true);
	CU_ASSERT(spdk_cpuset_get_cpu(set, SPDK_CPUSET_SIZE - 1) == true);
	CU_ASSERT(cpuset_check_range(set, 1, cpu - 1, false) == 0);
	CU_ASSERT(cpuset_check_range(set, cpu + 1, SPDK_CPUSET_SIZE - 2, false) == 0);
	CU_ASSERT(spdk_cpuset_count(set) == 2);

	/* Set all cpus */
	for (cpu = 0; cpu < SPDK_CPUSET_SIZE; cpu++) {
		spdk_cpuset_set_cpu(set, cpu, true);
	}
	CU_ASSERT(cpuset_check_range(set, 0, SPDK_CPUSET_SIZE - 1, true) == 0);
	CU_ASSERT(spdk_cpuset_count(set) == SPDK_CPUSET_SIZE);

	/* Clear all cpus */
	spdk_cpuset_zero(set);
	CU_ASSERT(cpuset_check_range(set, 0, SPDK_CPUSET_SIZE - 1, false) == 0);
	CU_ASSERT(spdk_cpuset_count(set) == 0);

	spdk_cpuset_free(set);
}

static void
test_cpuset_parse(void)
{
	int rc;
	struct spdk_cpuset *core_mask;
	char buf[1024];

	core_mask = spdk_cpuset_alloc();
	SPDK_CU_ASSERT_FATAL(core_mask != NULL);

	/* Only core 0 should be set */
	rc = spdk_cpuset_parse(core_mask, "0x1");
	CU_ASSERT(rc >= 0);
	CU_ASSERT(cpuset_check_range(core_mask, 0, 0, true) == 0);
	CU_ASSERT(cpuset_check_range(core_mask, 1, SPDK_CPUSET_SIZE - 1, false) == 0);

	/* Only core 1 should be set */
	rc = spdk_cpuset_parse(core_mask, "[1]");
	CU_ASSERT(rc >= 0);
	CU_ASSERT(cpuset_check_range(core_mask, 0, 0, false) == 0);
	CU_ASSERT(cpuset_check_range(core_mask, 1, 1, true) == 0);
	CU_ASSERT(cpuset_check_range(core_mask, 2, SPDK_CPUSET_SIZE - 1, false) == 0);

	/* Set cores 0-10,12,128-254 */
	rc = spdk_cpuset_parse(core_mask, "[0-10,12,128-254]");
	CU_ASSERT(rc >= 0);
	CU_ASSERT(cpuset_check_range(core_mask, 0, 10, true) == 0);
	CU_ASSERT(cpuset_check_range(core_mask, 11, 11, false) == 0);
	CU_ASSERT(cpuset_check_range(core_mask, 12, 12, true) == 0);
	CU_ASSERT(cpuset_check_range(core_mask, 13, 127, false) == 0);
	CU_ASSERT(cpuset_check_range(core_mask, 128, 254, true) == 0);
	CU_ASSERT(cpuset_check_range(core_mask, 255, SPDK_CPUSET_SIZE - 1, false) == 0);

	/* Set all cores */
	snprintf(buf, sizeof(buf), "[0-%d]", SPDK_CPUSET_SIZE - 1);
	rc = spdk_cpuset_parse(core_mask, buf);
	CU_ASSERT(rc >= 0);
	CU_ASSERT(cpuset_check_range(core_mask, 0, SPDK_CPUSET_SIZE - 1, true) == 0);

	/* Null parameters not allowed */
	rc = spdk_cpuset_parse(core_mask, NULL);
	CU_ASSERT(rc < 0);

	rc = spdk_cpuset_parse(NULL, "[1]");
	CU_ASSERT(rc < 0);

	/* Wrong formatted core lists */
	rc = spdk_cpuset_parse(core_mask, "");
	CU_ASSERT(rc < 0);

	rc = spdk_cpuset_parse(core_mask, "[");
	CU_ASSERT(rc < 0);

	rc = spdk_cpuset_parse(core_mask, "[]");
	CU_ASSERT(rc < 0);

	rc = spdk_cpuset_parse(core_mask, "[10--11]");
	CU_ASSERT(rc < 0);

	rc = spdk_cpuset_parse(core_mask, "[11-10]");
	CU_ASSERT(rc < 0);

	rc = spdk_cpuset_parse(core_mask, "[10-11,]");
	CU_ASSERT(rc < 0);

	rc = spdk_cpuset_parse(core_mask, "[,10-11]");
	CU_ASSERT(rc < 0);

	/* Out of range value */
	snprintf(buf, sizeof(buf), "[%d]", SPDK_CPUSET_SIZE + 1);
	rc = spdk_cpuset_parse(core_mask, buf);
	CU_ASSERT(rc < 0);

	/* Overflow value (UINT64_MAX * 10) */
	rc = spdk_cpuset_parse(core_mask, "[184467440737095516150]");
	CU_ASSERT(rc < 0);

	/* Test mask with cores 4-7 and 168-171 set. */
	rc = spdk_cpuset_parse(core_mask, "0xF0000000000000000000000000000000000000000F0");
	CU_ASSERT(rc == 0);
	CU_ASSERT(cpuset_check_range(core_mask, 0, 3, false) == 0);
	CU_ASSERT(cpuset_check_range(core_mask, 4, 7, true) == 0);
	CU_ASSERT(cpuset_check_range(core_mask, 8, 167, false) == 0);
	CU_ASSERT(cpuset_check_range(core_mask, 168, 171, true) == 0);
	CU_ASSERT(cpuset_check_range(core_mask, 172, SPDK_CPUSET_SIZE - 1, false) == 0);

	/* Test masks with commas. The commas should be ignored by cpuset, to
	 * allow using spdk_cpuset_parse() with Linux kernel sysfs strings
	 * that insert commas for readability purposes.
	 */
	rc = spdk_cpuset_parse(core_mask, "FF,FF0000FF,00000000");
	CU_ASSERT(rc == 0);
	CU_ASSERT(cpuset_check_range(core_mask, 0, 31, false) == 0);
	CU_ASSERT(cpuset_check_range(core_mask, 32, 39, true) == 0);
	CU_ASSERT(cpuset_check_range(core_mask, 40, 55, false) == 0);
	CU_ASSERT(cpuset_check_range(core_mask, 56, 71, true) == 0);
	CU_ASSERT(cpuset_check_range(core_mask, 72, SPDK_CPUSET_SIZE - 1, false) == 0);

	/* Test masks with random commas. We just ignore the commas, cpuset
	 * should not try to validate that commas are only in certain positions.
	 */
	rc = spdk_cpuset_parse(core_mask, ",,,,,000,,1,0,0,,,,");
	CU_ASSERT(rc == 0);
	CU_ASSERT(cpuset_check_range(core_mask, 0, 7, false) == 0);
	CU_ASSERT(cpuset_check_range(core_mask, 8, 8, true) == 0);
	CU_ASSERT(cpuset_check_range(core_mask, 9, SPDK_CPUSET_SIZE - 1, false) == 0);

	spdk_cpuset_free(core_mask);
}

static void
test_cpuset_fmt(void)
{
	int i;
	uint32_t lcore;
	struct spdk_cpuset *core_mask = spdk_cpuset_alloc();
	const char *hex_mask;
	char hex_mask_ref[SPDK_CPUSET_SIZE / 4 + 1];

	/* Clear coremask. hex_mask should be "0" */
	spdk_cpuset_zero(core_mask);
	hex_mask = spdk_cpuset_fmt(core_mask);
	SPDK_CU_ASSERT_FATAL(hex_mask != NULL);
	CU_ASSERT(strcmp("0", hex_mask) == 0);

	/* Set coremask 0x51234. Result should be "51234" */
	spdk_cpuset_zero(core_mask);
	spdk_cpuset_set_cpu(core_mask, 2, true);
	spdk_cpuset_set_cpu(core_mask, 4, true);
	spdk_cpuset_set_cpu(core_mask, 5, true);
	spdk_cpuset_set_cpu(core_mask, 9, true);
	spdk_cpuset_set_cpu(core_mask, 12, true);
	spdk_cpuset_set_cpu(core_mask, 16, true);
	spdk_cpuset_set_cpu(core_mask, 18, true);
	hex_mask = spdk_cpuset_fmt(core_mask);
	SPDK_CU_ASSERT_FATAL(hex_mask != NULL);
	CU_ASSERT(strcmp("51234", hex_mask) == 0);

	/* Set all cores */
	spdk_cpuset_zero(core_mask);
	CU_ASSERT(cpuset_check_range(core_mask, 0, SPDK_CPUSET_SIZE - 1, false) == 0);

	for (lcore = 0; lcore < SPDK_CPUSET_SIZE; lcore++) {
		spdk_cpuset_set_cpu(core_mask, lcore, true);
	}
	for (i = 0; i < SPDK_CPUSET_SIZE / 4; i++) {
		hex_mask_ref[i] = 'f';
	}
	hex_mask_ref[SPDK_CPUSET_SIZE / 4] = '\0';

	/* Check data before format */
	CU_ASSERT(cpuset_check_range(core_mask, 0, SPDK_CPUSET_SIZE - 1, true) == 0);

	hex_mask = spdk_cpuset_fmt(core_mask);
	SPDK_CU_ASSERT_FATAL(hex_mask != NULL);
	CU_ASSERT(strcmp(hex_mask_ref, hex_mask) == 0);

	/* Check data integrity after format */
	CU_ASSERT(cpuset_check_range(core_mask, 0, SPDK_CPUSET_SIZE - 1, true) == 0);

	spdk_cpuset_free(core_mask);
}

static void
set_bit(void *ctx, uint32_t cpu)
{
	uint64_t *mask = ctx;

	SPDK_CU_ASSERT_FATAL(cpu < 64);
	(*mask) |= (1 << cpu);
}

static void
test_cpuset_foreach(void)
{
	struct spdk_cpuset cpuset = {};
	uint64_t mask = 0;

	CU_ASSERT(spdk_cpuset_parse(&cpuset, "0xF135704") == 0);
	spdk_cpuset_for_each_cpu(&cpuset, set_bit, &mask);
	CU_ASSERT(mask == 0xF135704);
}

int
main(int argc, char **argv)
{
	CU_pSuite	suite = NULL;
	unsigned int	num_failures;

	CU_initialize_registry();

	suite = CU_add_suite("cpuset", NULL, NULL);

	CU_ADD_TEST(suite, test_cpuset);
	CU_ADD_TEST(suite, test_cpuset_parse);
	CU_ADD_TEST(suite, test_cpuset_fmt);
	CU_ADD_TEST(suite, test_cpuset_foreach);

	num_failures = spdk_ut_run_tests(argc, argv, NULL);

	CU_cleanup_registry();

	return num_failures;
}
