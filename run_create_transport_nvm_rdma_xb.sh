# ./scripts/rpc.py nvmf_create_transport -t RDMA -u 8192
/opt/h3c/script/tgt/rpc.py -s /var/tmp/spdk_xb.sock nvmf_create_transport -t RDMA --no-srq
/opt/h3c/script/tgt/rpc.py -s /var/tmp/spdk_xb.sock bdev_malloc_create -b Malloc0 1024 512 -u 41a7f127-38ea-4390-b5c6-ab0fed80f5d3
/opt/h3c/script/tgt/rpc.py -s /var/tmp/spdk_xb.sock nvmf_create_subsystem nqn.2022-06.io.spdk:cnode216 -m 512 -r -a -s SPDK00000000000001 -d SPDK_Controll
/opt/h3c/script/tgt/rpc.py -s /var/tmp/spdk_xb.sock nvmf_subsystem_add_ns nqn.2022-06.io.spdk:cnode216 Malloc0
/opt/h3c/script/tgt/rpc.py -s /var/tmp/spdk_xb.sock nvmf_subsystem_add_listener nqn.2022-06.io.spdk:cnode216 -t rdma -a 172.17.29.63 -s 4520

