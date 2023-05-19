POOL_UUID="${POOL:-pool_label}"
CONT_UUID="${CONT:-const_label}"
DISK_UUID="${UUID:-`uuidgen`}"
NR_DISKS="${1:-1}"
BIND_IP="${TARGET_IP:-172.31.91.61}"

sudo ./scripts/rpc.py nvmf_create_transport -t TCP -u 2097152 -i 2097152

for i in $(seq 1 "$NR_DISKS"); do
    sudo ./scripts/rpc.py bdev_daos_create disk$i ${POOL_UUID} ${CONT_UUID} 1048576 4096 --uuid ${DISK_UUID}
    subsystem=nqn.2016-06.io.spdk$i:cnode$i
    sudo scripts/rpc.py nvmf_create_subsystem $subsystem -a -s SPDK0000000000000$i -d SPDK_Virtual_Controller_$i
    sudo scripts/rpc.py nvmf_subsystem_add_ns $subsystem  disk$i
    sudo scripts/rpc.py nvmf_subsystem_add_listener $subsystem -t tcp -a ${BIND_IP} -s 4420
done

# denis@daos2:~/spdk> POOL=denisb CONT=nvmetest sh export_disk.sh 2   #磁盘数量