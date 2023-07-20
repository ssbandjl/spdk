nvme disconnect -n 'nqn.2022-06.io.spdk:cnode216'
nvme discover -t rdma -a 172.17.29.63 -s 4420
nvme connect -t rdma -n 'nqn.2022-06.io.spdk:cnode216' -a  172.17.29.63 -s 4420
nvme list
nvme list-subsys

nvme write /dev/nvme2n1 -s0 -c63 -z 4096

disconnect
