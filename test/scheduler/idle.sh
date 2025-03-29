#!/usr/bin/env bash
#  SPDX-License-Identifier: BSD-3-Clause
#  Copyright (C) 2020 Intel Corporation
#  All rights reserved.
#

testdir=$(readlink -f "$(dirname "$0")")
rootdir=$(readlink -f "$testdir/../../")

source "$rootdir/test/common/autotest_common.sh"
source "$testdir/common.sh"

trap 'killprocess "$spdk_pid"' EXIT

thread_stats() {
	local thread load
	busy_threads=0

	get_thread_stats_current

	# Simply verify if threads stay idle
	for thread in "${!thread_map[@]}"; do
		printf '[load:%3u%%, idle:%10u, busy:%10u] ' \
			$((busy[thread] * 100 / (busy[thread] + idle[thread]))) \
			"${idle[thread]}" "${busy[thread]}"
		if ((idle[thread] < busy[thread])); then
			printf 'Waiting for %s to become idle\n' "${thread_map[thread]}"
			((++busy_threads))
		else
			printf '%s is idle\n' "${thread_map[thread]}"
		fi
	done
}

idle() {
	local reactor_framework
	local reactors thread
	local thread_cpumask
	local threads

	exec_under_dynamic_scheduler "${SPDK_APP[@]}" -m "$spdk_cpumask" --main-core "$spdk_main_core"

	# The expectation here is that when SPDK app is idle the following is true:
	# - all threads are assigned to main lcore
	# - threads are not being moved between lcores

	# Get first set of stats, to exclude initialization from the busy/idle
	get_thread_stats_current

	xtrace_disable
	while ((samples++ < 5)); do
		cpumask=0
		reactor_framework=$(rpc_cmd framework_get_reactors | jq -r '.reactors[]')
		threads=($(
			jq -r "select(.lcore == $spdk_main_core) | .lw_threads[].name" <<< "$reactor_framework"
		))

		for thread in "${threads[@]}"; do
			thread_cpumask=0x$(jq -r "select(.lcore == $spdk_main_core) | .lw_threads[] | select(.name == \"$thread\") | .cpumask" <<< "$reactor_framework")
			printf 'SPDK cpumask: %s Thread %s cpumask: %s\n' "$spdk_cpumask" "$thread" "$thread_cpumask"
		done

		thread_stats

		((busy_threads == 0))
	done

	xtrace_restore
}

idle
