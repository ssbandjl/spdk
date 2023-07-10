#!/usr/bin/env bash
#  SPDX-License-Identifier: BSD-3-Clause
#  All rights reserved.
#

testdir=$(readlink -f $(dirname $0))
rootdir=$(readlink -f $testdir/../../..)

source $rootdir/test/common/autotest_common.sh
source $rootdir/test/nvmf/common.sh

rpc_py="$rootdir/scripts/rpc.py"

cleanup() {
	process_shm --id $NVMF_APP_SHM_ID || true
	killprocess $bdevperf_pid
	nvmftestfini || true
	rm -f $key_path $key_2_path $key_long_path
}

function run_bdevperf() {
	local subnqn hostnqn psk
	subnqn=$1 hostnqn=$2 psk=${3:+--psk $3}

	bdevperf_rpc_sock=/var/tmp/bdevperf.sock
	# use bdevperf to test "bdev_nvme_attach_controller"
	$rootdir/build/examples/bdevperf -m 0x4 -z -r $bdevperf_rpc_sock -q 128 -o 4096 -w verify -t 10 &
	bdevperf_pid=$!

	trap 'cleanup; exit 1' SIGINT SIGTERM EXIT
	waitforlisten $bdevperf_pid $bdevperf_rpc_sock

	# send RPC
	if ! $rpc_py -s $bdevperf_rpc_sock bdev_nvme_attach_controller -b TLSTEST -t $TEST_TRANSPORT \
		-a $NVMF_FIRST_TARGET_IP -s $NVMF_PORT -f ipv4 -n "$subnqn" -q "$hostnqn" $psk; then
		killprocess $bdevperf_pid
		return 1
	fi

	# run I/O and wait
	$rootdir/examples/bdev/bdevperf/bdevperf.py -t 20 -s $bdevperf_rpc_sock perform_tests

	# finish
	trap 'nvmftestfini; exit 1' SIGINT SIGTERM EXIT
	killprocess $bdevperf_pid
}

format_interchange_psk() {
	local key hash crc

	key=$1 hash=${2:-01}
	crc=$(echo -n $key | gzip -1 -c | tail -c8 | head -c 4)

	echo "NVMeTLSkey-1:$hash:$(base64 <(echo -n ${key}${crc})):"
}

setup_nvmf_tgt() {
	local key=$1

	$rpc_py nvmf_create_transport $NVMF_TRANSPORT_OPTS
	$rpc_py nvmf_create_subsystem nqn.2016-06.io.spdk:cnode1 -s SPDK00000000000001 -m 10
	$rpc_py nvmf_subsystem_add_listener nqn.2016-06.io.spdk:cnode1 -t $TEST_TRANSPORT \
		-a $NVMF_FIRST_TARGET_IP -s $NVMF_PORT -k
	$rpc_py bdev_malloc_create 32 4096 -b malloc0
	$rpc_py nvmf_subsystem_add_ns nqn.2016-06.io.spdk:cnode1 malloc0 -n 1

	$rpc_py nvmf_subsystem_add_host nqn.2016-06.io.spdk:cnode1 nqn.2016-06.io.spdk:host1 \
		--psk $key
}

nvmftestinit
nvmfappstart -m 0x2 --wait-for-rpc

if [ "$TEST_TRANSPORT" != tcp ]; then
	echo "Unsupported transport: $TEST_TRANSPORT"
	exit 0
fi

$rpc_py sock_set_default_impl -i ssl

# Check default TLS version
version=$($rpc_py sock_impl_get_options -i ssl | jq -r .tls_version)
if [[ "$version" != "0" ]]; then
	echo "TLS version was not set correctly $version != 0"
	exit 1
fi

# Check TLS version set to 13
$rpc_py sock_impl_set_options -i ssl --tls-version 13
version=$($rpc_py sock_impl_get_options -i ssl | jq -r .tls_version)
if [[ "$version" != "13" ]]; then
	echo "TLS version was not set correctly $version != 13"
	exit 1
fi

# Check incorrect TLS version set to 7
$rpc_py sock_impl_set_options -i ssl --tls-version 7
version=$($rpc_py sock_impl_get_options -i ssl | jq -r .tls_version)
if [[ "$version" != "7" ]]; then
	echo "TLS version was not set correctly $version != 7"
	exit 1
fi

# Check default KTLS is disabled
ktls=$($rpc_py sock_impl_get_options -i ssl | jq -r .enable_ktls)
if [[ "$ktls" != "false" ]]; then
	echo "KTLS was not set correctly $ktls != false"
	exit 1
fi

# Check KTLS enable
$rpc_py sock_impl_set_options -i ssl --enable-ktls
ktls=$($rpc_py sock_impl_get_options -i ssl | jq -r .enable_ktls)
if [[ "$ktls" != "true" ]]; then
	echo "KTLS was not set correctly $ktls != true"
	exit 1
fi

# Check KTLS disable
$rpc_py sock_impl_set_options -i ssl --disable-ktls
ktls=$($rpc_py sock_impl_get_options -i ssl | jq -r .enable_ktls)
if [[ "$ktls" != "false" ]]; then
	echo "KTLS was not set correctly $ktls != false"
	exit 1
fi

key=$(format_interchange_psk 00112233445566778899aabbccddeeff)
key_2=$(format_interchange_psk ffeeddccbbaa99887766554433221100)

key_path="$testdir/key1.txt"
key_2_path="$testdir/key2.txt"

echo -n "$key" > $key_path
echo -n "$key_2" > $key_2_path

chmod 0600 $key_path
chmod 0600 $key_2_path

$rpc_py sock_impl_set_options -i ssl --tls-version 13
$rpc_py framework_start_init

setup_nvmf_tgt $key_path

# Test #1 - test connectivity with perf and bdevperf application
# Check connectivity with nvmeperf"
"${NVMF_TARGET_NS_CMD[@]}" $SPDK_EXAMPLE_DIR/perf -S ssl -q 64 -o 4096 -w randrw -M 30 -t 10 \
	-r "trtype:${TEST_TRANSPORT} adrfam:IPv4 traddr:${NVMF_FIRST_TARGET_IP} trsvcid:${NVMF_PORT} \
subnqn:nqn.2016-06.io.spdk:cnode1 hostnqn:nqn.2016-06.io.spdk:host1" \
	--psk-path $key_path

# Check connectivity with bdevperf with 32 bytes long key
run_bdevperf nqn.2016-06.io.spdk:cnode1 nqn.2016-06.io.spdk:host1 "$key_path"

# Test #2 - test if it is possible to connect with different PSK
NOT run_bdevperf nqn.2016-06.io.spdk:cnode1 nqn.2016-06.io.spdk:host1 "$key_2_path"

# Test #3 - test if it is possible to connect with different hostnqn
NOT run_bdevperf nqn.2016-06.io.spdk:cnode1 nqn.2016-06.io.spdk:host2 "$key_path"

# Test #4 - test if it is possible to connect with different subnqn
NOT run_bdevperf nqn.2016-06.io.spdk:cnode2 nqn.2016-06.io.spdk:host1 "$key_path"

# Test #5 - test if it is possible to connect with POSIX socket to SSL socket (no credentials provided)
NOT run_bdevperf nqn.2016-06.io.spdk:cnode1 nqn.2016-06.io.spdk:host1 ""

# Test #6 - check connectivity with bdevperf, but with 48 bytes long key
killprocess $nvmfpid
key_long=$(format_interchange_psk 00112233445566778899aabbccddeeff0011223344556677 02)
key_long_path="$testdir/key_long.txt"
echo -n "$key_long" > $key_long_path
chmod 0600 $key_long_path
nvmfappstart -m 0x2

setup_nvmf_tgt $key_long_path

run_bdevperf nqn.2016-06.io.spdk:cnode1 nqn.2016-06.io.spdk:host1 "$key_long_path"

# Test #7 - check if it is possible to connect with incorrect permissions
chmod 0666 $key_long_path
NOT run_bdevperf nqn.2016-06.io.spdk:cnode1 nqn.2016-06.io.spdk:host1 "$key_long_path"

# Test #8 - check if it is possible to setup nvmf_tgt with PSK with incorrect permissions
killprocess $nvmfpid
nvmfappstart -m 0x2

NOT setup_nvmf_tgt $key_long_path

trap - SIGINT SIGTERM EXIT
cleanup
