server(iscsi_target):
echo 4096 > /sys/kernel/mm/hugepages/hugepages-2048kB/nr_hugepages
cat /proc/meminfo |grep -i huge
./build/bin/iscsi_tgt
./scripts/rpc.py log_set_level DEBUG
./scripts/rpc.py bdev_malloc_create -b Malloc0 64 512
./scripts/rpc.py bdev_malloc_create -b Malloc1 64 512
./scripts/rpc.py iscsi_create_portal_group 1 127.0.0.1:3260
# ./scripts/rpc.py iscsi_create_auth_group -c 'user:admin secret:admin muser:admin msecret:admin' 0
# ./scripts/rpc.py iscsi_set_discovery_auth -m -r -g 0
./scripts/rpc.py iscsi_create_initiator_group 2 ANY 127.0.0.1/24
./scripts/rpc.py iscsi_create_target_node disk1 "Data Disk1" "Malloc0:0 Malloc1:1" 1:2 64 -d




client(iscsi_initiator):
apt install open-iscsi
iscsiadm -m discovery -t sendtargets -p 127.0.0.1
127.0.0.1:3260,1 iqn.2016-06.io.spdk:disk1

iscsiadm -m node --login
iscsiadm -m node --logoutall=all


iscsi_bdev:
url: iscsi://[<username>[%<password>]@]<host>[:<port>]/<target-iqn>/<lun>
Example: iscsi://ronnie%password@server/iqn.ronnie.test/1
./scripts/rpc.py bdev_iscsi_create -b iSCSI0 -i iqn.2016-06.io.spdk:init --url iscsi://admin%admin@127.0.0.1/iqn.2016-06.io.spdk:disk1/0
./scripts/rpc.py bdev_iscsi_create -b iSCSI0 -i iqn.2016-06.io.spdk:init --url iscsi://127.0.0.1/iqn.2016-06.io.spdk:disk1/1
./scripts/spdkcli.py ls

cd build/examples
./hello_bdev -b iSCSI0 -m 0x2 -r /tmp/spdk.sock -c /root/xb/project/stor/spdk/examples/bdev/hello_world/bdev_iscsi.json

