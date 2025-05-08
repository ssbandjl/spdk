T端:

# qeury ib device
ls /sys/class/infiniband/*/device/net

# start tgt
build/bin/nvmf_tgt -L all


# 使用提升的权限启动 nvmf_tgt 应用程序。启动目标后，可以使用 nvmf_create_transport rpc 初始化给定的传输。以下示例启动目标并配置了两种不同的传输。RDMA 传输配置为 I/O 单元大小为 8192 字节、最大 I/O 大小为 131072 以及胶囊(capsule)内数据大小为 8192 字节。TCP 传输配置为 I/O 单元大小为 16384 字节、每个控制器最多 8 个 qpair 以及胶囊内数据大小为 8192 字节。

# ./scripts/rpc.py nvmf_create_transport -t RDMA -u 8192 -i 131072 -c 8192
# ./scripts/rpc.py nvmf_create_transport -t TCP -u 16384 -m 8 -c 8192

./scripts/rpc.py nvmf_create_transport -t RDMA -u 8192
# ./script/tgt/rpc.py -s /var/tmp/spdk_xb.sock nvmf_create_transport -t RDMA --no-srq

# create malloc bdev: 1024MB, block_size/sector_size(512B)
./scripts/rpc.py bdev_malloc_create -b Malloc0 1024 512 -u 41a7f127-38ea-4390-b5c6-ab0fed80f5d3
./scripts/rpc.py nvmf_create_subsystem nqn.2022-06.io.spdk:cnode216 -m 512 -r -a -s SPDK00000000000001 -d SPDK_Controll
./scripts/rpc.py nvmf_subsystem_add_ns nqn.2022-06.io.spdk:cnode216 Malloc0
./scripts/rpc.py nvmf_subsystem_add_listener nqn.2022-06.io.spdk:cnode216 -t rdma -a 192.168.1.117 -s 4520


I端(客户端):
apt install nvme-cli

1.load module
modprobe nvme-rdma

2.discovery
nvme discover -t rdma -a 192.168.1.117 -s 4520
# nvme discover -t rdma -a 192.168.80.100 -s 4520
3.connect
连接cnode1
nvme connect -t rdma -n "nqn.2022-06.io.spdk:cnode216" -a 192.168.1.117 -s 4520

连接cnode2
# nvme connect -t rdma -n "nqn.2016-06.io.spdk:cnode2" -a 192.168.1.117 -s 4520

lsblk
root@hpc118:~# nvme list 
Node             SN                   Model                                    Namespace Usage                      Format           FW Rev  
---------------- -------------------- ---------------------------------------- --------- -------------------------- ---------------- --------
/dev/nvme0n1     YS2410120000004572   HUANANZHI 256G                           1         256.06  GB / 256.06  GB    512   B +  0 B   V1208A3 
/dev/nvme1n1     SPDK00000000000001   SPDK_Controll                            1           1.07  GB /   1.07  GB    512   B +  0 B   25.01 

fio test:
fio --name=/dev/nvme1n1 --ioengine=libaio --direct=1 --fsync=1 --readwrite=randwrite --blocksize=4k --runtime=300

4.disconnect
# nvme disconnect -n "nqn.2016-06.io.spdk:cnode1"
# nvme disconnect -n "nqn.2016-06.io.spdk:cnode2"




================================================= LOG =================================================
nvmf_create_transport log:
./scripts/rpc.py nvmf_create_transport -t RDMA -u 8192
[2025-03-27 15:08:58.753174] rdma.c:2712:nvmf_rdma_create: *INFO*: *** RDMA Transport Init ***
  Transport opts:  max_ioq_depth=128, max_io_size=131072,
  max_io_qpairs_per_ctrlr=127, io_unit_size=8192,
  in_capsule_data_size=4096, max_aq_depth=128,
  num_shared_buffers=4095, num_cqe=4096, max_srq_depth=4096, no_srq=0,  acceptor_backlog=100, no_wr_batching=0 abort_timeout_sec=1
[2025-03-27 15:08:58.858135] rdma.c:2594:create_ib_device: *DEBUG*: New device 0x55acf7206a80 is added to RDMA transport
[2025-03-27 15:08:58.864678] rdma.c:2623:create_ib_device: *NOTICE*: Create IB device mlx5_0(0x55acf7206a80/0x55acf7183e20) succeed.
[2025-03-27 15:08:58.864730] rdma.c:2594:create_ib_device: *DEBUG*: New device 0x55acf7207bb0 is added to RDMA transport
[2025-03-27 15:08:58.870184] rdma.c:2623:create_ib_device: *NOTICE*: Create IB device mlx5_1(0x55acf7207bb0/0x55acf71c54f0) succeed.
[2025-03-27 15:08:58.870233] rdma.c:4057:nvmf_rdma_poller_create: *DEBUG*: Create poller 0x55acf7209260 on device 0x55acf7206a80 in poll group 0x55acf72091f0.
[2025-03-27 15:08:58.876550] rdma.c: 709:nvmf_rdma_resources_create: *DEBUG*: Command Array: 0x2000080b5000 Length: 40000
[2025-03-27 15:08:58.876569] rdma.c: 711:nvmf_rdma_resources_create: *DEBUG*: Completion Array: 0x200017206000 Length: 10000
[2025-03-27 15:08:58.876576] rdma.c: 714:nvmf_rdma_resources_create: *DEBUG*: In Capsule Data Array: 0x200017a00000 Length: 1000000
[2025-03-27 15:08:58.878600] rdma.c:4057:nvmf_rdma_poller_create: *DEBUG*: Create poller 0x55acf7233410 on device 0x55acf7207bb0 in poll group 0x55acf72091f0.
[2025-03-27 15:08:58.884419] rdma.c: 709:nvmf_rdma_resources_create: *DEBUG*: Command Array: 0x200008074000 Length: 40000
[2025-03-27 15:08:58.884433] rdma.c: 711:nvmf_rdma_resources_create: *DEBUG*: Completion Array: 0x200018a06000 Length: 10000
[2025-03-27 15:08:58.884438] rdma.c: 714:nvmf_rdma_resources_create: *DEBUG*: In Capsule Data Array: 0x200019200000 Length: 1000000
[2025-03-27 15:08:58.886081] thread.c:2405:spdk_get_io_channel: *DEBUG*: Get io_channel 0x55acf725d660 for io_device iobuf (0x55ace0ff0540) on thread nvmf_tgt_poll_group_000 refcnt 1
[2025-03-27 15:08:58.898324] jsonrpc_server_tcp.c: 285:jsonrpc_server_conn_recv: *DEBUG*: remote closed connection


create bdev:
./scripts/rpc.py bdev_malloc_create -b Malloc0 1024 512 -u 41a7f127-38ea-4390-b5c6-ab0fed80f5d3
[2025-03-27 15:16:39.363651] thread.c:2216:spdk_io_device_register: *DEBUG*: Registering io_device bdev_Malloc0 (0x55acf717e361) on thread app_thread
[2025-03-27 15:16:39.363683] bdev.c:8245:bdev_register: *DEBUG*: Inserting bdev Malloc0 into list
[2025-03-27 15:16:39.363702] bdev.c:8523:bdev_open: *DEBUG*: Opening descriptor 0x55acf717e8e0 for bdev Malloc0 on thread 0x55acf7120480
[2025-03-27 15:16:39.363718] bdev.c:8523:bdev_open: *DEBUG*: Opening descriptor 0x55acf717ec40 for bdev Malloc0 on thread 0x55acf7120480
[2025-03-27 15:16:39.363728] thread.c:2405:spdk_get_io_channel: *DEBUG*: Get io_channel 0x55acf717eec0 for io_device bdev_Malloc0 (0x55acf717e361) on thread app_thread refcnt 1
[2025-03-27 15:16:39.363746] thread.c:2405:spdk_get_io_channel: *DEBUG*: Get io_channel 0x55acf717efd0 for io_device bdev_malloc (0x55ace0fec020) on thread app_thread refcnt 1
[2025-03-27 15:16:39.363763] thread.c:2405:spdk_get_io_channel: *DEBUG*: Get io_channel 0x55acf725e920 for io_device accel (0x55ace0fefe80) on thread app_thread refcnt 1
[2025-03-27 15:16:39.364371] thread.c:2405:spdk_get_io_channel: *DEBUG*: Get io_channel 0x7f350db7d010 for io_device sw_accel_module (0x55ace0ff0060) on thread app_thread refcnt 1
[2025-03-27 15:16:39.364411] thread.c:2378:spdk_get_io_channel: *DEBUG*: Get io_channel 0x7f350db7d010 for io_device sw_accel_module (0x55ace0ff0060) on thread app_thread refcnt 2
[2025-03-27 15:16:39.364417] thread.c:2378:spdk_get_io_channel: *DEBUG*: Get io_channel 0x7f350db7d010 for io_device sw_accel_module (0x55ace0ff0060) on thread app_thread refcnt 3
[2025-03-27 15:16:39.364422] thread.c:2378:spdk_get_io_channel: *DEBUG*: Get io_channel 0x7f350db7d010 for io_device sw_accel_module (0x55ace0ff0060) on thread app_thread refcnt 4
[2025-03-27 15:16:39.364426] thread.c:2378:spdk_get_io_channel: *DEBUG*: Get io_channel 0x7f350db7d010 for io_device sw_accel_module (0x55ace0ff0060) on thread app_thread refcnt 5
[2025-03-27 15:16:39.364430] thread.c:2378:spdk_get_io_channel: *DEBUG*: Get io_channel 0x7f350db7d010 for io_device sw_accel_module (0x55ace0ff0060) on thread app_thread refcnt 6
[2025-03-27 15:16:39.364435] thread.c:2378:spdk_get_io_channel: *DEBUG*: Get io_channel 0x7f350db7d010 for io_device sw_accel_module (0x55ace0ff0060) on thread app_thread refcnt 7
[2025-03-27 15:16:39.364451] thread.c:2378:spdk_get_io_channel: *DEBUG*: Get io_channel 0x7f350db7d010 for io_device sw_accel_module (0x55ace0ff0060) on thread app_thread refcnt 8
[2025-03-27 15:16:39.364456] thread.c:2378:spdk_get_io_channel: *DEBUG*: Get io_channel 0x7f350db7d010 for io_device sw_accel_module (0x55ace0ff0060) on thread app_thread refcnt 9
[2025-03-27 15:16:39.364461] thread.c:2378:spdk_get_io_channel: *DEBUG*: Get io_channel 0x7f350db7d010 for io_device sw_accel_module (0x55ace0ff0060) on thread app_thread refcnt 10
[2025-03-27 15:16:39.364466] thread.c:2378:spdk_get_io_channel: *DEBUG*: Get io_channel 0x7f350db7d010 for io_device sw_accel_module (0x55ace0ff0060) on thread app_thread refcnt 11
[2025-03-27 15:16:39.364471] thread.c:2378:spdk_get_io_channel: *DEBUG*: Get io_channel 0x7f350db7d010 for io_device sw_accel_module (0x55ace0ff0060) on thread app_thread refcnt 12
[2025-03-27 15:16:39.364476] thread.c:2378:spdk_get_io_channel: *DEBUG*: Get io_channel 0x7f350db7d010 for io_device sw_accel_module (0x55ace0ff0060) on thread app_thread refcnt 13
[2025-03-27 15:16:39.364481] thread.c:2378:spdk_get_io_channel: *DEBUG*: Get io_channel 0x7f350db7d010 for io_device sw_accel_module (0x55ace0ff0060) on thread app_thread refcnt 14
[2025-03-27 15:16:39.364485] thread.c:2378:spdk_get_io_channel: *DEBUG*: Get io_channel 0x7f350db7d010 for io_device sw_accel_module (0x55ace0ff0060) on thread app_thread refcnt 15
[2025-03-27 15:16:39.364490] thread.c:2378:spdk_get_io_channel: *DEBUG*: Get io_channel 0x7f350db7d010 for io_device sw_accel_module (0x55ace0ff0060) on thread app_thread refcnt 16
[2025-03-27 15:16:39.364495] thread.c:2378:spdk_get_io_channel: *DEBUG*: Get io_channel 0x7f350db7d010 for io_device sw_accel_module (0x55ace0ff0060) on thread app_thread refcnt 17
[2025-03-27 15:16:39.364501] thread.c:2405:spdk_get_io_channel: *DEBUG*: Get io_channel 0x55acf725ecd0 for io_device iobuf (0x55ace0ff0540) on thread app_thread refcnt 1
[2025-03-27 15:16:39.364519] thread.c:2378:spdk_get_io_channel: *DEBUG*: Get io_channel 0x55acf725e920 for io_device accel (0x55ace0fefe80) on thread app_thread refcnt 2
[2025-03-27 15:16:39.364525] thread.c:2405:spdk_get_io_channel: *DEBUG*: Get io_channel 0x55acf725f100 for io_device bdev_mgr (0x55ace0fefc20) on thread app_thread refcnt 1
[2025-03-27 15:16:39.364531] thread.c:2378:spdk_get_io_channel: *DEBUG*: Get io_channel 0x55acf725ecd0 for io_device iobuf (0x55ace0ff0540) on thread app_thread refcnt 2
[2025-03-27 15:16:39.364589] bdev_malloc.c: 383:bdev_malloc_readv: *DEBUG*: read 32768 bytes from offset 0, iovcnt=1
[2025-03-27 15:16:39.364597] accel.c: 189:accel_sequence_set_state: *DEBUG*: seq=0x55acf7304980, setting state: init -> await-virtbuf
[2025-03-27 15:16:39.364603] accel.c: 189:accel_sequence_set_state: *DEBUG*: seq=0x55acf7304980, setting state: await-virtbuf -> check-bouncebuf
[2025-03-27 15:16:39.364608] accel.c: 189:accel_sequence_set_state: *DEBUG*: seq=0x55acf7304980, setting state: check-bouncebuf -> await-bouncebuf
[2025-03-27 15:16:39.364614] accel.c: 189:accel_sequence_set_state: *DEBUG*: seq=0x55acf7304980, setting state: await-bouncebuf -> exec-task
[2025-03-27 15:16:39.364619] accel.c:2291:accel_process_sequence: *DEBUG*: Executing copy operation, sequence: 0x55acf7304980
[2025-03-27 15:16:39.364624] accel.c: 189:accel_sequence_set_state: *DEBUG*: seq=0x55acf7304980, setting state: exec-task -> await-task
[2025-03-27 15:16:39.364638] bdev.c:8523:bdev_open: *DEBUG*: Opening descriptor 0x55acf725f470 for bdev Malloc0 on thread 0x55acf7120480
[2025-03-27 15:16:39.364645] thread.c:2378:spdk_get_io_channel: *DEBUG*: Get io_channel 0x55acf717eec0 for io_device bdev_Malloc0 (0x55acf717e361) on thread app_thread refcnt 2
[2025-03-27 15:16:39.364653] bdev_malloc.c: 383:bdev_malloc_readv: *DEBUG*: read 512 bytes from offset 0, iovcnt=1
[2025-03-27 15:16:39.364658] accel.c: 189:accel_sequence_set_state: *DEBUG*: seq=0x55acf7304940, setting state: init -> await-virtbuf
[2025-03-27 15:16:39.364663] accel.c: 189:accel_sequence_set_state: *DEBUG*: seq=0x55acf7304940, setting state: await-virtbuf -> check-bouncebuf
[2025-03-27 15:16:39.364668] accel.c: 189:accel_sequence_set_state: *DEBUG*: seq=0x55acf7304940, setting state: check-bouncebuf -> await-bouncebuf
[2025-03-27 15:16:39.364673] accel.c: 189:accel_sequence_set_state: *DEBUG*: seq=0x55acf7304940, setting state: await-bouncebuf -> exec-task
[2025-03-27 15:16:39.364677] accel.c:2291:accel_process_sequence: *DEBUG*: Executing copy operation, sequence: 0x55acf7304940
[2025-03-27 15:16:39.364681] accel.c: 189:accel_sequence_set_state: *DEBUG*: seq=0x55acf7304940, setting state: exec-task -> await-task
[2025-03-27 15:16:39.364688] bdev.c:8523:bdev_open: *DEBUG*: Opening descriptor 0x55acf717f060 for bdev Malloc0 on thread 0x55acf7120480
[2025-03-27 15:16:39.364701] blobstore.c:5049:spdk_bs_load: *DEBUG*: Loading blobstore from dev 0x55acf725f7a0
[2025-03-27 15:16:39.364717] thread.c:2216:spdk_io_device_register: *DEBUG*: Registering io_device blobstore (0x55acf7394ec0) on thread app_thread
[2025-03-27 15:16:39.364724] thread.c:2405:spdk_get_io_channel: *DEBUG*: Get io_channel 0x55acf717f140 for io_device blobstore (0x55acf7394ec0) on thread app_thread refcnt 1
[2025-03-27 15:16:39.364786] thread.c:2378:spdk_get_io_channel: *DEBUG*: Get io_channel 0x55acf717eec0 for io_device bdev_Malloc0 (0x55acf717e361) on thread app_thread refcnt 3
[2025-03-27 15:16:39.364795] request.c: 168:bs_sequence_read_dev: *DEBUG*: Reading 8 blocks from LBA 0
[2025-03-27 15:16:39.364801] bdev_malloc.c: 383:bdev_malloc_readv: *DEBUG*: read 4096 bytes from offset 0, iovcnt=1
[2025-03-27 15:16:39.364807] accel.c: 189:accel_sequence_set_state: *DEBUG*: seq=0x55acf7304900, setting state: init -> await-virtbuf
[2025-03-27 15:16:39.364812] accel.c: 189:accel_sequence_set_state: *DEBUG*: seq=0x55acf7304900, setting state: await-virtbuf -> check-bouncebuf
[2025-03-27 15:16:39.364816] accel.c: 189:accel_sequence_set_state: *DEBUG*: seq=0x55acf7304900, setting state: check-bouncebuf -> await-bouncebuf
[2025-03-27 15:16:39.364821] accel.c: 189:accel_sequence_set_state: *DEBUG*: seq=0x55acf7304900, setting state: await-bouncebuf -> exec-task
[2025-03-27 15:16:39.364826] accel.c:2291:accel_process_sequence: *DEBUG*: Executing copy operation, sequence: 0x55acf7304900
[2025-03-27 15:16:39.364831] accel.c: 189:accel_sequence_set_state: *DEBUG*: seq=0x55acf7304900, setting state: exec-task -> await-task
[2025-03-27 15:16:39.364852] accel.c: 189:accel_sequence_set_state: *DEBUG*: seq=0x55acf7304980, setting state: await-task -> complete-task
[2025-03-27 15:16:39.364858] accel.c: 189:accel_sequence_set_state: *DEBUG*: seq=0x55acf7304980, setting state: complete-task -> next-task
[2025-03-27 15:16:39.364863] accel.c:1844:accel_sequence_complete: *DEBUG*: Completed sequence: 0x55acf7304980 with status: 0
[2025-03-27 15:16:39.364871] gpt.c: 214:gpt_check_mbr: *DEBUG*: Signature mismatch, provided=0,expected=aa55
[2025-03-27 15:16:39.364876] gpt.c: 265:gpt_parse_mbr: *DEBUG*: Failed to detect gpt in MBR
[2025-03-27 15:16:39.364880] vbdev_gpt.c: 473:gpt_bdev_complete: *DEBUG*: Failed to parse mbr
[2025-03-27 15:16:39.364886] thread.c:2506:spdk_put_io_channel: *DEBUG*: Putting io_channel 0x55acf717eec0 for io_device bdev_Malloc0 (0x55acf717e361) on thread app_thread refcnt 3
[2025-03-27 15:16:39.364891] bdev.c:9013:spdk_bdev_close: *DEBUG*: Closing descriptor 0x55acf717ec40 for bdev Malloc0 on thread 0x55acf7120480
[2025-03-27 15:16:39.364900] accel.c: 189:accel_sequence_set_state: *DEBUG*: seq=0x55acf7304940, setting state: await-task -> complete-task
[2025-03-27 15:16:39.364905] accel.c: 189:accel_sequence_set_state: *DEBUG*: seq=0x55acf7304940, setting state: complete-task -> next-task
[2025-03-27 15:16:39.364910] accel.c:1844:accel_sequence_complete: *DEBUG*: Completed sequence: 0x55acf7304940 with status: 0
[2025-03-27 15:16:39.364915] bdev_raid_sb.c: 144:raid_bdev_parse_superblock: *DEBUG*: invalid signature
[2025-03-27 15:16:39.364920] bdev_raid_sb.c: 260:raid_bdev_read_sb_cb: *DEBUG*: failed to parse bdev Malloc0 superblock
[2025-03-27 15:16:39.364925] thread.c:2506:spdk_put_io_channel: *DEBUG*: Putting io_channel 0x55acf717eec0 for io_device bdev_Malloc0 (0x55acf717e361) on thread app_thread refcnt 2
[2025-03-27 15:16:39.364930] bdev.c:9013:spdk_bdev_close: *DEBUG*: Closing descriptor 0x55acf725f470 for bdev Malloc0 on thread 0x55acf7120480
[2025-03-27 15:16:39.364936] accel.c: 189:accel_sequence_set_state: *DEBUG*: seq=0x55acf7304900, setting state: await-task -> complete-task
[2025-03-27 15:16:39.364941] accel.c: 189:accel_sequence_set_state: *DEBUG*: seq=0x55acf7304900, setting state: complete-task -> next-task
[2025-03-27 15:16:39.364946] accel.c:1844:accel_sequence_complete: *DEBUG*: Completed sequence: 0x55acf7304900 with status: 0
[2025-03-27 15:16:39.364952] vbdev_lvol.c:1655:_vbdev_lvs_examine_cb: *INFO*: Lvol store not found on Malloc0
[2025-03-27 15:16:39.364958] thread.c:2506:spdk_put_io_channel: *DEBUG*: Putting io_channel 0x55acf717f140 for io_device blobstore (0x55acf7394ec0) on thread app_thread refcnt 1
[2025-03-27 15:16:39.364964] thread.c:2315:spdk_io_device_unregister: *DEBUG*: Unregistering io_device blobstore (0x55acf7394ec0) from thread app_thread
[2025-03-27 15:16:39.365010] thread.c:2442:put_io_channel: *DEBUG*: Releasing io_channel 0x55acf717f140 for io_device blobstore (0x55acf7394ec0) on thread app_thread
[2025-03-27 15:16:39.365020] blobstore.c:10224:blob_esnap_destroy_bs_channel: *DEBUG*: destroying channels on thread app_thread
[2025-03-27 15:16:39.365025] blobstore.c:10235:blob_esnap_destroy_bs_channel: *DEBUG*: done destroying channels on thread app_thread
[2025-03-27 15:16:39.365031] thread.c:2506:spdk_put_io_channel: *DEBUG*: Putting io_channel 0x55acf717eec0 for io_device bdev_Malloc0 (0x55acf717e361) on thread app_thread refcnt 1
[2025-03-27 15:16:39.365037] thread.c:2258:io_device_free: *DEBUG*: io_device blobstore (0x55acf7394ec0) needs to unregister from thread app_thread
[2025-03-27 15:16:39.365045] thread.c:2442:put_io_channel: *DEBUG*: Releasing io_channel 0x55acf717eec0 for io_device bdev_Malloc0 (0x55acf717e361) on thread app_thread
[2025-03-27 15:16:39.365050] bdev.c:4915:bdev_channel_destroy: *DEBUG*: Destroying channel 0x55acf717ef20 for bdev Malloc0 on thread 0x55acf7120480
[2025-03-27 15:16:39.365057] thread.c:2506:spdk_put_io_channel: *DEBUG*: Putting io_channel 0x55acf717efd0 for io_device bdev_malloc (0x55ace0fec020) on thread app_thread refcnt 1
[2025-03-27 15:16:39.365062] thread.c:2506:spdk_put_io_channel: *DEBUG*: Putting io_channel 0x55acf725e920 for io_device accel (0x55ace0fefe80) on thread app_thread refcnt 2
[2025-03-27 15:16:39.365067] thread.c:2506:spdk_put_io_channel: *DEBUG*: Putting io_channel 0x55acf725f100 for io_device bdev_mgr (0x55ace0fefc20) on thread app_thread refcnt 1
[2025-03-27 15:16:39.365072] thread.c:2239:_finish_unregister: *DEBUG*: Finishing unregistration of io_device blobstore (0x55acf7394ec0) on thread app_thread
[2025-03-27 15:16:39.365077] bdev.c:9013:spdk_bdev_close: *DEBUG*: Closing descriptor 0x55acf717f060 for bdev Malloc0 on thread 0x55acf7120480
[2025-03-27 15:16:39.365084] thread.c:2442:put_io_channel: *DEBUG*: Releasing io_channel 0x55acf717efd0 for io_device bdev_malloc (0x55ace0fec020) on thread app_thread
[2025-03-27 15:16:39.365090] thread.c:2506:spdk_put_io_channel: *DEBUG*: Putting io_channel 0x55acf725e920 for io_device accel (0x55ace0fefe80) on thread app_thread refcnt 1
[2025-03-27 15:16:39.365096] thread.c:2442:put_io_channel: *DEBUG*: Releasing io_channel 0x55acf725f100 for io_device bdev_mgr (0x55ace0fefc20) on thread app_thread
[2025-03-27 15:16:39.365109] thread.c:2506:spdk_put_io_channel: *DEBUG*: Putting io_channel 0x55acf725ecd0 for io_device iobuf (0x55ace0ff0540) on thread app_thread refcnt 2
[2025-03-27 15:16:39.365135] thread.c:2442:put_io_channel: *DEBUG*: Releasing io_channel 0x55acf725e920 for io_device accel (0x55ace0fefe80) on thread app_thread
[2025-03-27 15:16:39.365148] thread.c:2506:spdk_put_io_channel: *DEBUG*: Putting io_channel 0x55acf725ecd0 for io_device iobuf (0x55ace0ff0540) on thread app_thread refcnt 1
[2025-03-27 15:16:39.365154] thread.c:2506:spdk_put_io_channel: *DEBUG*: Putting io_channel 0x7f350db7d010 for io_device sw_accel_module (0x55ace0ff0060) on thread app_thread refcnt 17
[2025-03-27 15:16:39.365158] thread.c:2506:spdk_put_io_channel: *DEBUG*: Putting io_channel 0x7f350db7d010 for io_device sw_accel_module (0x55ace0ff0060) on thread app_thread refcnt 16
[2025-03-27 15:16:39.365163] thread.c:2506:spdk_put_io_channel: *DEBUG*: Putting io_channel 0x7f350db7d010 for io_device sw_accel_module (0x55ace0ff0060) on thread app_thread refcnt 15
[2025-03-27 15:16:39.365168] thread.c:2506:spdk_put_io_channel: *DEBUG*: Putting io_channel 0x7f350db7d010 for io_device sw_accel_module (0x55ace0ff0060) on thread app_thread refcnt 14
[2025-03-27 15:16:39.365173] thread.c:2506:spdk_put_io_channel: *DEBUG*: Putting io_channel 0x7f350db7d010 for io_device sw_accel_module (0x55ace0ff0060) on thread app_thread refcnt 13
[2025-03-27 15:16:39.365178] thread.c:2506:spdk_put_io_channel: *DEBUG*: Putting io_channel 0x7f350db7d010 for io_device sw_accel_module (0x55ace0ff0060) on thread app_thread refcnt 12
[2025-03-27 15:16:39.365183] thread.c:2506:spdk_put_io_channel: *DEBUG*: Putting io_channel 0x7f350db7d010 for io_device sw_accel_module (0x55ace0ff0060) on thread app_thread refcnt 11
[2025-03-27 15:16:39.365188] thread.c:2506:spdk_put_io_channel: *DEBUG*: Putting io_channel 0x7f350db7d010 for io_device sw_accel_module (0x55ace0ff0060) on thread app_thread refcnt 10
[2025-03-27 15:16:39.365192] thread.c:2506:spdk_put_io_channel: *DEBUG*: Putting io_channel 0x7f350db7d010 for io_device sw_accel_module (0x55ace0ff0060) on thread app_thread refcnt 9
[2025-03-27 15:16:39.365197] thread.c:2506:spdk_put_io_channel: *DEBUG*: Putting io_channel 0x7f350db7d010 for io_device sw_accel_module (0x55ace0ff0060) on thread app_thread refcnt 8
[2025-03-27 15:16:39.365202] thread.c:2506:spdk_put_io_channel: *DEBUG*: Putting io_channel 0x7f350db7d010 for io_device sw_accel_module (0x55ace0ff0060) on thread app_thread refcnt 7
[2025-03-27 15:16:39.365207] thread.c:2506:spdk_put_io_channel: *DEBUG*: Putting io_channel 0x7f350db7d010 for io_device sw_accel_module (0x55ace0ff0060) on thread app_thread refcnt 6
[2025-03-27 15:16:39.365212] thread.c:2506:spdk_put_io_channel: *DEBUG*: Putting io_channel 0x7f350db7d010 for io_device sw_accel_module (0x55ace0ff0060) on thread app_thread refcnt 5
[2025-03-27 15:16:39.365217] thread.c:2506:spdk_put_io_channel: *DEBUG*: Putting io_channel 0x7f350db7d010 for io_device sw_accel_module (0x55ace0ff0060) on thread app_thread refcnt 4
[2025-03-27 15:16:39.365221] thread.c:2506:spdk_put_io_channel: *DEBUG*: Putting io_channel 0x7f350db7d010 for io_device sw_accel_module (0x55ace0ff0060) on thread app_thread refcnt 3
[2025-03-27 15:16:39.365226] thread.c:2506:spdk_put_io_channel: *DEBUG*: Putting io_channel 0x7f350db7d010 for io_device sw_accel_module (0x55ace0ff0060) on thread app_thread refcnt 2
[2025-03-27 15:16:39.365230] thread.c:2506:spdk_put_io_channel: *DEBUG*: Putting io_channel 0x7f350db7d010 for io_device sw_accel_module (0x55ace0ff0060) on thread app_thread refcnt 1
[2025-03-27 15:16:39.365237] thread.c:2442:put_io_channel: *DEBUG*: Releasing io_channel 0x55acf725ecd0 for io_device iobuf (0x55ace0ff0540) on thread app_thread
[2025-03-27 15:16:39.365242] thread.c:2442:put_io_channel: *DEBUG*: Releasing io_channel 0x7f350db7d010 for io_device sw_accel_module (0x55ace0ff0060) on thread app_thread
[2025-03-27 15:16:39.372856] jsonrpc_server_tcp.c: 285:jsonrpc_server_conn_recv: *DEBUG*: remote closed connection



bind to malloc bdev:
/scripts/rpc.py nvmf_create_subsystem nqn.2022-06.io.spdk:cnode216 -m 512 -r -a -s SPDK00000000000001 -d SPDK_Controll
/scripts/rpc.py nvmf_subsystem_add_ns nqn.2022-06.io.spdk:cnode216 Malloc0
./scripts/rpc.py nvmf_subsystem_add_listener nqn.2022-06.io.spdk:cnode216 -t rdma -a 192.168.1.117 -s 4520

[2025-03-27 15:40:19.114628] jsonrpc_server_tcp.c: 285:jsonrpc_server_conn_recv: *DEBUG*: remote closed connection
[2025-03-27 15:40:34.635303] bdev.c:8523:bdev_open: *DEBUG*: Opening descriptor 0x55acf7396010 for bdev Malloc0 on thread 0x55acf7120480
[2025-03-27 15:40:34.635337] subsystem.c:2291:spdk_nvmf_subsystem_add_ns_ext: *DEBUG*: Subsystem nqn.2022-06.io.spdk:cnode216: bdev Malloc0 assigned nsid 1
[2025-03-27 15:40:34.635347] thread.c:2405:spdk_get_io_channel: *DEBUG*: Get io_channel 0x55acf725f6a0 for io_device bdev_Malloc0 (0x55acf717e361) on thread nvmf_tgt_poll_group_000 refcnt 1
[2025-03-27 15:40:34.635363] thread.c:2405:spdk_get_io_channel: *DEBUG*: Get io_channel 0x55acf725f7b0 for io_device bdev_malloc (0x55ace0fec020) on thread nvmf_tgt_poll_group_000 refcnt 1
[2025-03-27 15:40:34.635369] thread.c:2405:spdk_get_io_channel: *DEBUG*: Get io_channel 0x55acf72e49c0 for io_device accel (0x55ace0fefe80) on thread nvmf_tgt_poll_group_000 refcnt 1
[2025-03-27 15:40:34.635697] thread.c:2405:spdk_get_io_channel: *DEBUG*: Get io_channel 0x55acf73fa3b0 for io_device sw_accel_module (0x55ace0ff0060) on thread nvmf_tgt_poll_group_000 refcnt 1
[2025-03-27 15:40:34.635722] thread.c:2378:spdk_get_io_channel: *DEBUG*: Get io_channel 0x55acf73fa3b0 for io_device sw_accel_module (0x55ace0ff0060) on thread nvmf_tgt_poll_group_000 refcnt 2
[2025-03-27 15:40:34.635727] thread.c:2378:spdk_get_io_channel: *DEBUG*: Get io_channel 0x55acf73fa3b0 for io_device sw_accel_module (0x55ace0ff0060) on thread nvmf_tgt_poll_group_000 refcnt 3
[2025-03-27 15:40:34.635732] thread.c:2378:spdk_get_io_channel: *DEBUG*: Get io_channel 0x55acf73fa3b0 for io_device sw_accel_module (0x55ace0ff0060) on thread nvmf_tgt_poll_group_000 refcnt 4
[2025-03-27 15:40:34.635735] thread.c:2378:spdk_get_io_channel: *DEBUG*: Get io_channel 0x55acf73fa3b0 for io_device sw_accel_module (0x55ace0ff0060) on thread nvmf_tgt_poll_group_000 refcnt 5
[2025-03-27 15:40:34.635739] thread.c:2378:spdk_get_io_channel: *DEBUG*: Get io_channel 0x55acf73fa3b0 for io_device sw_accel_module (0x55ace0ff0060) on thread nvmf_tgt_poll_group_000 refcnt 6
[2025-03-27 15:40:34.635743] thread.c:2378:spdk_get_io_channel: *DEBUG*: Get io_channel 0x55acf73fa3b0 for io_device sw_accel_module (0x55ace0ff0060) on thread nvmf_tgt_poll_group_000 refcnt 7
[2025-03-27 15:40:34.635747] thread.c:2378:spdk_get_io_channel: *DEBUG*: Get io_channel 0x55acf73fa3b0 for io_device sw_accel_module (0x55ace0ff0060) on thread nvmf_tgt_poll_group_000 refcnt 8
[2025-03-27 15:40:34.635752] thread.c:2378:spdk_get_io_channel: *DEBUG*: Get io_channel 0x55acf73fa3b0 for io_device sw_accel_module (0x55ace0ff0060) on thread nvmf_tgt_poll_group_000 refcnt 9
[2025-03-27 15:40:34.635769] thread.c:2378:spdk_get_io_channel: *DEBUG*: Get io_channel 0x55acf73fa3b0 for io_device sw_accel_module (0x55ace0ff0060) on thread nvmf_tgt_poll_group_000 refcnt 10
[2025-03-27 15:40:34.635774] thread.c:2378:spdk_get_io_channel: *DEBUG*: Get io_channel 0x55acf73fa3b0 for io_device sw_accel_module (0x55ace0ff0060) on thread nvmf_tgt_poll_group_000 refcnt 11
[2025-03-27 15:40:34.635779] thread.c:2378:spdk_get_io_channel: *DEBUG*: Get io_channel 0x55acf73fa3b0 for io_device sw_accel_module (0x55ace0ff0060) on thread nvmf_tgt_poll_group_000 refcnt 12
[2025-03-27 15:40:34.635784] thread.c:2378:spdk_get_io_channel: *DEBUG*: Get io_channel 0x55acf73fa3b0 for io_device sw_accel_module (0x55ace0ff0060) on thread nvmf_tgt_poll_group_000 refcnt 13
[2025-03-27 15:40:34.635789] thread.c:2378:spdk_get_io_channel: *DEBUG*: Get io_channel 0x55acf73fa3b0 for io_device sw_accel_module (0x55ace0ff0060) on thread nvmf_tgt_poll_group_000 refcnt 14
[2025-03-27 15:40:34.635793] thread.c:2378:spdk_get_io_channel: *DEBUG*: Get io_channel 0x55acf73fa3b0 for io_device sw_accel_module (0x55ace0ff0060) on thread nvmf_tgt_poll_group_000 refcnt 15
[2025-03-27 15:40:34.635798] thread.c:2378:spdk_get_io_channel: *DEBUG*: Get io_channel 0x55acf73fa3b0 for io_device sw_accel_module (0x55ace0ff0060) on thread nvmf_tgt_poll_group_000 refcnt 16
[2025-03-27 15:40:34.635810] thread.c:2378:spdk_get_io_channel: *DEBUG*: Get io_channel 0x55acf73fa3b0 for io_device sw_accel_module (0x55ace0ff0060) on thread nvmf_tgt_poll_group_000 refcnt 17
[2025-03-27 15:40:34.635816] thread.c:2378:spdk_get_io_channel: *DEBUG*: Get io_channel 0x55acf725d660 for io_device iobuf (0x55ace0ff0540) on thread nvmf_tgt_poll_group_000 refcnt 2
[2025-03-27 15:40:34.635832] thread.c:2378:spdk_get_io_channel: *DEBUG*: Get io_channel 0x55acf72e49c0 for io_device accel (0x55ace0fefe80) on thread nvmf_tgt_poll_group_000 refcnt 2
[2025-03-27 15:40:34.635838] thread.c:2405:spdk_get_io_channel: *DEBUG*: Get io_channel 0x55acf72dbbb0 for io_device bdev_mgr (0x55ace0fefc20) on thread nvmf_tgt_poll_group_000 refcnt 1
[2025-03-27 15:40:34.635844] thread.c:2378:spdk_get_io_channel: *DEBUG*: Get io_channel 0x55acf725d660 for io_device iobuf (0x55ace0ff0540) on thread nvmf_tgt_poll_group_000 refcnt 3
[2025-03-27 15:40:34.647266] jsonrpc_server_tcp.c: 285:jsonrpc_server_conn_recv: *DEBUG*: remote closed connection

[2025-03-27 15:41:42.990499] rdma.c:3078:nvmf_rdma_listen: *NOTICE*: *** NVMe/RDMA Target Listening on 192.168.1.117 port 4520 ***


after client discover log:
[2025-03-27 15:46:40.186178] rdma.c:3696:nvmf_process_cm_events: *DEBUG*: Acceptor Event: RDMA_CM_EVENT_CONNECT_REQUEST
[2025-03-27 15:46:40.186200] rdma.c:1304:nvmf_rdma_connect: *DEBUG*: Connect Recv on fabric intf name mlx5_0, dev_name uverbs0
[2025-03-27 15:46:40.186205] rdma.c:1308:nvmf_rdma_connect: *DEBUG*: Listen Id was 0x55acf72dc370 with verbs 0x55acf7183e20. ListenAddr: 0x55acf728f990
[2025-03-27 15:46:40.186208] rdma.c:1315:nvmf_rdma_connect: *DEBUG*: Calculating Queue Depth
[2025-03-27 15:46:40.186212] rdma.c:1320:nvmf_rdma_connect: *DEBUG*: Target Max Queue Depth: 128
[2025-03-27 15:46:40.186216] rdma.c:1324:nvmf_rdma_connect: *DEBUG*: Local NIC Max Send/Recv Queue Depth: 32768 Max Read/Write Queue Depth: 16
[2025-03-27 15:46:40.186219] rdma.c:1331:nvmf_rdma_connect: *DEBUG*: Host (Initiator) NIC Max Incoming RDMA R/W operations: 16 Max Outgoing RDMA R/W operations: 0
[2025-03-27 15:46:40.186223] rdma.c:1360:nvmf_rdma_connect: *DEBUG*: Host Receive Queue Size: 32
[2025-03-27 15:46:40.186226] rdma.c:1361:nvmf_rdma_connect: *DEBUG*: Host Send Queue Size: 31
[2025-03-27 15:46:40.186230] rdma.c:1365:nvmf_rdma_connect: *DEBUG*: Final Negotiated Queue Depth: 32 R/W Depth: 16
[2025-03-27 15:46:40.188383] rdma.c:1026:nvmf_rdma_qpair_initialize: *DEBUG*: New RDMA Connection: 0x55acf73960f0
[2025-03-27 15:46:40.190402] rdma.c:1256:nvmf_rdma_event_accept: *DEBUG*: Sent back the accept
[2025-03-27 15:46:40.192084] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 1
[2025-03-27 15:46:40.192096] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 2
[2025-03-27 15:46:40.192115] rdma.c:1504:nvmf_rdma_fill_wr_sgl: *DEBUG*: sge[0] 0x200017280480 addr 0x200004000000, len 1024
[2025-03-27 15:46:40.192121] rdma.c:1893:nvmf_rdma_request_parse_sgl: *DEBUG*: Request 0x200017280000 took 1 buffer/s from central pool
[2025-03-27 15:46:40.192138] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 3
[2025-03-27 15:46:40.192144] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 4
[2025-03-27 15:46:40.192158] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 5
[2025-03-27 15:46:40.192173] nvme_qpair.c: 218:nvme_admin_qpair_print_command: *NOTICE*: FABRIC CONNECT qid:0 cid:0 SGL KEYED DATA BLOCK INVALIDATE KEY 0x33e3ed800 len:0x400 key:0x2003be
[2025-03-27 15:46:40.192209] subsystem.c:1641:spdk_nvmf_subsystem_listener_allowed: *WARNING*: Allowing connection to discovery subsystem on RDMA/192.168.1.117/4520, even though this listener was not added to the discovery subsystem.  This behavior is deprecated and will be removed in a future release.
[2025-03-27 15:46:40.192234] ctrlr.c: 855:_nvmf_ctrlr_connect: *DEBUG*: recfmt 0x0 qid 0 sqsize 31
[2025-03-27 15:46:40.192240] ctrlr.c: 858:_nvmf_ctrlr_connect: *DEBUG*: Connect data:
[2025-03-27 15:46:40.192246] ctrlr.c: 859:_nvmf_ctrlr_connect: *DEBUG*:   cntlid:  0xffff
[2025-03-27 15:46:40.192252] ctrlr.c: 860:_nvmf_ctrlr_connect: *DEBUG*:   hostid: c3ab7015-781c-4b07-af33-0cd1204f4499 ***
[2025-03-27 15:46:40.192257] ctrlr.c: 868:_nvmf_ctrlr_connect: *DEBUG*:   subnqn: "nqn.2014-08.org.nvmexpress.discovery"
[2025-03-27 15:46:40.192263] ctrlr.c: 869:_nvmf_ctrlr_connect: *DEBUG*:   hostnqn: "nqn.2014-08.org.nvmexpress:uuid:e553e370-9f7d-4802-8abf-745e75b2845c"
[2025-03-27 15:46:40.192269] ctrlr.c: 926:_nvmf_ctrlr_connect: *DEBUG*: Connect Admin Queue for controller ID 0xffff
[2025-03-27 15:46:40.192281] ctrlr.c: 574:nvmf_ctrlr_create: *DEBUG*: cap 0x201e01007f
[2025-03-27 15:46:40.192287] ctrlr.c: 575:nvmf_ctrlr_create: *DEBUG*: vs 0x10300
[2025-03-27 15:46:40.192293] ctrlr.c: 576:nvmf_ctrlr_create: *DEBUG*: cc 0x0
[2025-03-27 15:46:40.192297] ctrlr.c: 577:nvmf_ctrlr_create: *DEBUG*: csts 0x0
[2025-03-27 15:46:40.192304] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 6
[2025-03-27 15:46:40.192312] ctrlr.c: 215:nvmf_ctrlr_start_keep_alive_timer: *DEBUG*: Ctrlr add keep alive poller
[2025-03-27 15:46:40.192319] ctrlr.c: 320:nvmf_ctrlr_add_qpair: *DEBUG*: qpair_mask set, qid 0
[2025-03-27 15:46:40.192327] ctrlr.c: 266:nvmf_ctrlr_send_connect_rsp: *DEBUG*: connect capsule response: cntlid = 0x0001
[2025-03-27 15:46:40.192335] nvme_qpair.c: 474:spdk_nvme_print_completion: *NOTICE*: SUCCESS (00/00) qid:0 cid:0 cdw0:1 sqhd:0000 p:0 m:0 dnr:0
[2025-03-27 15:46:40.192359] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 7
[2025-03-27 15:46:40.192365] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 9
[2025-03-27 15:46:40.192370] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 10
[2025-03-27 15:46:40.192376] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 12
[2025-03-27 15:46:40.192389] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 13
[2025-03-27 15:46:40.192396] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 0
[2025-03-27 15:46:40.192455] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 1
[2025-03-27 15:46:40.192461] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 5
[2025-03-27 15:46:40.192468] nvme_qpair.c: 218:nvme_admin_qpair_print_command: *NOTICE*: FABRIC PROPERTY GET qid:0 cid:6 SGL KEYED DATA BLOCK ADDRESS 0x0 len:0x0 key:0x0
[2025-03-27 15:46:40.192479] ctrlr.c:1489:nvmf_property_get: *DEBUG*: size 1, offset 0x0
[2025-03-27 15:46:40.192485] ctrlr.c:1513:nvmf_property_get: *DEBUG*: name: cap
[2025-03-27 15:46:40.192490] ctrlr.c:1531:nvmf_property_get: *DEBUG*: response value: 0x201e01007f
[2025-03-27 15:46:40.192496] nvme_qpair.c: 474:spdk_nvme_print_completion: *NOTICE*: SUCCESS (00/00) qid:0 cid:6 cdw0:1e01007f sqhd:0000 p:0 m:0 dnr:0
[2025-03-27 15:46:40.192506] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 7
[2025-03-27 15:46:40.192511] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 9
[2025-03-27 15:46:40.192516] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 10
[2025-03-27 15:46:40.192521] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 12
[2025-03-27 15:46:40.192527] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 12
[2025-03-27 15:46:40.192538] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 13
[2025-03-27 15:46:40.192543] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 0
[2025-03-27 15:46:40.192553] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 1
[2025-03-27 15:46:40.192558] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 5
[2025-03-27 15:46:40.192565] nvme_qpair.c: 218:nvme_admin_qpair_print_command: *NOTICE*: FABRIC PROPERTY SET qid:0 cid:7 SGL KEYED DATA BLOCK ADDRESS 0x0 len:0x0 key:0x0
[2025-03-27 15:46:40.192575] ctrlr.c:1547:nvmf_property_set: *DEBUG*: size 0, offset 0x14, value 0x460000
[2025-03-27 15:46:40.192580] ctrlr.c:1572:nvmf_property_set: *DEBUG*: name: cc
[2025-03-27 15:46:40.192585] ctrlr.c:1237:nvmf_prop_set_cc: *DEBUG*: cur CC: 0x00000000
[2025-03-27 15:46:40.192591] ctrlr.c:1238:nvmf_prop_set_cc: *DEBUG*: new CC: 0x00460000
[2025-03-27 15:46:40.192595] ctrlr.c:1315:nvmf_prop_set_cc: *DEBUG*: Prop Set IOSQES = 6 (64 bytes)
[2025-03-27 15:46:40.192600] ctrlr.c:1322:nvmf_prop_set_cc: *DEBUG*: Prop Set IOCQES = 4 (16 bytes)
[2025-03-27 15:46:40.192606] nvme_qpair.c: 474:spdk_nvme_print_completion: *NOTICE*: SUCCESS (00/00) qid:0 cid:7 cdw0:0 sqhd:0000 p:0 m:0 dnr:0
[2025-03-27 15:46:40.192615] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 7
[2025-03-27 15:46:40.192621] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 9
[2025-03-27 15:46:40.192626] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 10
[2025-03-27 15:46:40.192631] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 12
[2025-03-27 15:46:40.192636] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 12
[2025-03-27 15:46:40.192647] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 13
[2025-03-27 15:46:40.192652] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 0
[2025-03-27 15:46:40.192661] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 1
[2025-03-27 15:46:40.192666] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 5
[2025-03-27 15:46:40.192673] nvme_qpair.c: 218:nvme_admin_qpair_print_command: *NOTICE*: FABRIC PROPERTY GET qid:0 cid:8 SGL KEYED DATA BLOCK ADDRESS 0x0 len:0x0 key:0x0
[2025-03-27 15:46:40.192683] ctrlr.c:1489:nvmf_property_get: *DEBUG*: size 0, offset 0x14
[2025-03-27 15:46:40.192688] ctrlr.c:1513:nvmf_property_get: *DEBUG*: name: cc
[2025-03-27 15:46:40.192693] ctrlr.c:1531:nvmf_property_get: *DEBUG*: response value: 0x460000
[2025-03-27 15:46:40.192699] nvme_qpair.c: 474:spdk_nvme_print_completion: *NOTICE*: SUCCESS (00/00) qid:0 cid:8 cdw0:460000 sqhd:0000 p:0 m:0 dnr:0
[2025-03-27 15:46:40.192708] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 7
[2025-03-27 15:46:40.192725] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 9
[2025-03-27 15:46:40.192731] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 10
[2025-03-27 15:46:40.192736] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 12
[2025-03-27 15:46:40.192741] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 12
[2025-03-27 15:46:40.192764] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 13
[2025-03-27 15:46:40.192769] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 0
[2025-03-27 15:46:40.192777] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 1
[2025-03-27 15:46:40.192783] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 5
[2025-03-27 15:46:40.192790] nvme_qpair.c: 218:nvme_admin_qpair_print_command: *NOTICE*: FABRIC PROPERTY GET qid:0 cid:9 SGL KEYED DATA BLOCK ADDRESS 0x0 len:0x0 key:0x0
[2025-03-27 15:46:40.192801] ctrlr.c:1489:nvmf_property_get: *DEBUG*: size 1, offset 0x0
[2025-03-27 15:46:40.192806] ctrlr.c:1513:nvmf_property_get: *DEBUG*: name: cap
[2025-03-27 15:46:40.192811] ctrlr.c:1531:nvmf_property_get: *DEBUG*: response value: 0x201e01007f
[2025-03-27 15:46:40.192829] nvme_qpair.c: 474:spdk_nvme_print_completion: *NOTICE*: SUCCESS (00/00) qid:0 cid:9 cdw0:1e01007f sqhd:0000 p:0 m:0 dnr:0
[2025-03-27 15:46:40.192848] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 7
[2025-03-27 15:46:40.192853] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 9
[2025-03-27 15:46:40.192858] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 10
[2025-03-27 15:46:40.192864] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 12
[2025-03-27 15:46:40.192868] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 12
[2025-03-27 15:46:40.192879] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 13
[2025-03-27 15:46:40.192884] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 0
[2025-03-27 15:46:40.192892] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 1
[2025-03-27 15:46:40.192897] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 5
[2025-03-27 15:46:40.192904] nvme_qpair.c: 218:nvme_admin_qpair_print_command: *NOTICE*: FABRIC PROPERTY SET qid:0 cid:4102 SGL KEYED DATA BLOCK ADDRESS 0x0 len:0x0 key:0x0
[2025-03-27 15:46:40.192914] ctrlr.c:1547:nvmf_property_set: *DEBUG*: size 0, offset 0x14, value 0x460001
[2025-03-27 15:46:40.192919] ctrlr.c:1572:nvmf_property_set: *DEBUG*: name: cc
[2025-03-27 15:46:40.192924] ctrlr.c:1237:nvmf_prop_set_cc: *DEBUG*: cur CC: 0x00460000
[2025-03-27 15:46:40.192929] ctrlr.c:1238:nvmf_prop_set_cc: *DEBUG*: new CC: 0x00460001
[2025-03-27 15:46:40.192945] ctrlr.c:1248:nvmf_prop_set_cc: *DEBUG*: Property Set CC Enable!
[2025-03-27 15:46:40.192952] nvme_qpair.c: 474:spdk_nvme_print_completion: *NOTICE*: SUCCESS (00/00) qid:0 cid:4102 cdw0:0 sqhd:0000 p:0 m:0 dnr:0
[2025-03-27 15:46:40.192962] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 7
[2025-03-27 15:46:40.192968] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 9
[2025-03-27 15:46:40.192973] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 10
[2025-03-27 15:46:40.192978] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 12
[2025-03-27 15:46:40.192983] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 12
[2025-03-27 15:46:40.192994] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 13
[2025-03-27 15:46:40.193000] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 0
[2025-03-27 15:46:40.193007] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 1
[2025-03-27 15:46:40.193013] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 5
[2025-03-27 15:46:40.193019] nvme_qpair.c: 218:nvme_admin_qpair_print_command: *NOTICE*: FABRIC PROPERTY GET qid:0 cid:4103 SGL KEYED DATA BLOCK ADDRESS 0x0 len:0x0 key:0x0
[2025-03-27 15:46:40.193029] ctrlr.c:1489:nvmf_property_get: *DEBUG*: size 0, offset 0x1c
[2025-03-27 15:46:40.193035] ctrlr.c:1513:nvmf_property_get: *DEBUG*: name: csts
[2025-03-27 15:46:40.193040] ctrlr.c:1531:nvmf_property_get: *DEBUG*: response value: 0x1
[2025-03-27 15:46:40.193046] nvme_qpair.c: 474:spdk_nvme_print_completion: *NOTICE*: SUCCESS (00/00) qid:0 cid:4103 cdw0:1 sqhd:0000 p:0 m:0 dnr:0
[2025-03-27 15:46:40.193055] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 7
[2025-03-27 15:46:40.193060] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 9
[2025-03-27 15:46:40.193076] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 10
[2025-03-27 15:46:40.193081] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 12
[2025-03-27 15:46:40.193086] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 12
[2025-03-27 15:46:40.193097] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 13
[2025-03-27 15:46:40.193102] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 0
[2025-03-27 15:46:40.193111] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 1
[2025-03-27 15:46:40.193127] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 5
[2025-03-27 15:46:40.193133] nvme_qpair.c: 218:nvme_admin_qpair_print_command: *NOTICE*: FABRIC PROPERTY GET qid:0 cid:4104 SGL KEYED DATA BLOCK ADDRESS 0x0 len:0x0 key:0x0
[2025-03-27 15:46:40.193155] ctrlr.c:1489:nvmf_property_get: *DEBUG*: size 0, offset 0x8
[2025-03-27 15:46:40.193160] ctrlr.c:1513:nvmf_property_get: *DEBUG*: name: vs
[2025-03-27 15:46:40.193165] ctrlr.c:1531:nvmf_property_get: *DEBUG*: response value: 0x10300
[2025-03-27 15:46:40.193171] nvme_qpair.c: 474:spdk_nvme_print_completion: *NOTICE*: SUCCESS (00/00) qid:0 cid:4104 cdw0:10300 sqhd:0000 p:0 m:0 dnr:0
[2025-03-27 15:46:40.193193] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 7
[2025-03-27 15:46:40.193198] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 9
[2025-03-27 15:46:40.193203] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 10
[2025-03-27 15:46:40.193208] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 12
[2025-03-27 15:46:40.193214] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 12
[2025-03-27 15:46:40.193224] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 13
[2025-03-27 15:46:40.193230] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 0
[2025-03-27 15:46:40.193247] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 1
[2025-03-27 15:46:40.193252] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 2
[2025-03-27 15:46:40.193258] rdma.c:1504:nvmf_rdma_fill_wr_sgl: *DEBUG*: sge[0] 0x200017280480 addr 0x200004000000, len 4096
[2025-03-27 15:46:40.193275] rdma.c:1893:nvmf_rdma_request_parse_sgl: *DEBUG*: Request 0x200017280000 took 1 buffer/s from central pool
[2025-03-27 15:46:40.193280] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 5
[2025-03-27 15:46:40.193288] nvme_qpair.c: 223:nvme_admin_qpair_print_command: *NOTICE*: IDENTIFY (06) qid:0 cid:4105 nsid:0 cdw10:00000001 cdw11:00000000 SGL KEYED DATA BLOCK INVALIDATE KEY 0x342b92000 len:0x1000 key:0x2003bf
[2025-03-27 15:46:40.193301] ctrlr.c:3382:nvmf_ctrlr_identify: *DEBUG*: Received identify command with CNS 0x01
[2025-03-27 15:46:40.193308] ctrlr.c:2961:spdk_nvmf_ctrlr_identify_ctrlr: *DEBUG*: ctrlr data: maxcmd 0x80
[2025-03-27 15:46:40.193324] ctrlr.c:2962:spdk_nvmf_ctrlr_identify_ctrlr: *DEBUG*: sgls data: 0x100005
[2025-03-27 15:46:40.193331] nvme_qpair.c: 474:spdk_nvme_print_completion: *NOTICE*: SUCCESS (00/00) qid:0 cid:4105 cdw0:0 sqhd:0000 p:0 m:0 dnr:0
[2025-03-27 15:46:40.193342] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 7
[2025-03-27 15:46:40.193347] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 8
[2025-03-27 15:46:40.193352] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 10
[2025-03-27 15:46:40.193357] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 11
[2025-03-27 15:46:40.193373] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 11
[2025-03-27 15:46:40.193387] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 13
[2025-03-27 15:46:40.193393] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 0
[2025-03-27 15:46:40.193466] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 1
[2025-03-27 15:46:40.193471] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 5
[2025-03-27 15:46:40.193478] nvme_qpair.c: 213:nvme_admin_qpair_print_command: *NOTICE*: SET FEATURES ASYNC EVENT CONFIGURATION cid:8198 cdw10:0000000b SGL KEYED DATA BLOCK ADDRESS 0x0 len:0x0 key:0x0
[2025-03-27 15:46:40.193501] ctrlr.c:2207:nvmf_ctrlr_set_features_async_event_configuration: *DEBUG*: Set Features - Async Event Configuration, cdw11 0x80000000
[2025-03-27 15:46:40.193508] nvme_qpair.c: 474:spdk_nvme_print_completion: *NOTICE*: SUCCESS (00/00) qid:0 cid:8198 cdw0:0 sqhd:0000 p:0 m:0 dnr:0
[2025-03-27 15:46:40.193518] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 7
[2025-03-27 15:46:40.193524] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 9
[2025-03-27 15:46:40.193529] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 10
[2025-03-27 15:46:40.193534] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 12
[2025-03-27 15:46:40.193540] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 12
[2025-03-27 15:46:40.193556] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 13
[2025-03-27 15:46:40.193562] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 0
[2025-03-27 15:46:40.193619] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 1
[2025-03-27 15:46:40.193624] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 5
[2025-03-27 15:46:40.193631] nvme_qpair.c: 223:nvme_admin_qpair_print_command: *NOTICE*: ASYNC EVENT REQUEST (0c) qid:0 cid:31 nsid:0 cdw10:00000000 cdw11:00000000 
[2025-03-27 15:46:40.193642] ctrlr.c:2222:nvmf_ctrlr_async_event_request: *DEBUG*: Async Event Request
[2025-03-27 15:46:40.193647] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 6
[2025-03-27 15:46:40.193693] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280580 entering state 1
[2025-03-27 15:46:40.193698] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280580 entering state 2
[2025-03-27 15:46:40.193704] rdma.c:1504:nvmf_rdma_fill_wr_sgl: *DEBUG*: sge[0] 0x200017280a00 addr 0x200004000000, len 16
[2025-03-27 15:46:40.193710] rdma.c:1893:nvmf_rdma_request_parse_sgl: *DEBUG*: Request 0x200017280580 took 1 buffer/s from central pool
[2025-03-27 15:46:40.193715] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280580 entering state 5
[2025-03-27 15:46:40.193723] nvme_qpair.c: 223:nvme_admin_qpair_print_command: *NOTICE*: GET LOG PAGE (02) qid:0 cid:8199 nsid:0 cdw10:00030070 cdw11:00000000 SGL KEYED DATA BLOCK INVALIDATE KEY 0x3452d5960 len:0x10 key:0x2003c0
[2025-03-27 15:46:40.193735] ctrlr.c:2677:nvmf_ctrlr_get_log_page: *DEBUG*: Get log page: LID=0x70 offset=0x0 len=0x10 rae=0
[2025-03-27 15:46:40.193742] ctrlr_discovery.c: 108:nvmf_generate_discovery_log: *DEBUG*: Generating log page for genctr 1
[2025-03-27 15:46:40.193750] ctrlr_discovery.c: 137:nvmf_generate_discovery_log: *DEBUG*: listener 192.168.1.117:4520 trtype RDMA
[2025-03-27 15:46:40.193759] nvme_qpair.c: 474:spdk_nvme_print_completion: *NOTICE*: SUCCESS (00/00) qid:0 cid:8199 cdw0:0 sqhd:0000 p:0 m:0 dnr:0
[2025-03-27 15:46:40.193769] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280580 entering state 7
[2025-03-27 15:46:40.193774] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280580 entering state 8
[2025-03-27 15:46:40.193780] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280580 entering state 10
[2025-03-27 15:46:40.193785] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280580 entering state 11
[2025-03-27 15:46:40.193791] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280580 entering state 11
[2025-03-27 15:46:40.193803] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280580 entering state 13
[2025-03-27 15:46:40.193809] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280580 entering state 0
[2025-03-27 15:46:40.193830] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280580 entering state 1
[2025-03-27 15:46:40.193836] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280580 entering state 2
[2025-03-27 15:46:40.193842] rdma.c:1504:nvmf_rdma_fill_wr_sgl: *DEBUG*: sge[0] 0x200017280a00 addr 0x200004000000, len 2048
[2025-03-27 15:46:40.193848] rdma.c:1893:nvmf_rdma_request_parse_sgl: *DEBUG*: Request 0x200017280580 took 1 buffer/s from central pool
[2025-03-27 15:46:40.193853] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280580 entering state 5
[2025-03-27 15:46:40.193860] nvme_qpair.c: 223:nvme_admin_qpair_print_command: *NOTICE*: GET LOG PAGE (02) qid:0 cid:8200 nsid:0 cdw10:01ff0070 cdw11:00000000 SGL KEYED DATA BLOCK INVALIDATE KEY 0x3452d5980 len:0x800 key:0x2003c1
[2025-03-27 15:46:40.193871] ctrlr.c:2677:nvmf_ctrlr_get_log_page: *DEBUG*: Get log page: LID=0x70 offset=0x0 len=0x800 rae=0
[2025-03-27 15:46:40.193878] ctrlr_discovery.c: 108:nvmf_generate_discovery_log: *DEBUG*: Generating log page for genctr 1
[2025-03-27 15:46:40.193883] ctrlr_discovery.c: 137:nvmf_generate_discovery_log: *DEBUG*: listener 192.168.1.117:4520 trtype RDMA
[2025-03-27 15:46:40.193891] nvme_qpair.c: 474:spdk_nvme_print_completion: *NOTICE*: SUCCESS (00/00) qid:0 cid:8200 cdw0:0 sqhd:0000 p:0 m:0 dnr:0
[2025-03-27 15:46:40.193901] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280580 entering state 7
[2025-03-27 15:46:40.193907] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280580 entering state 8
[2025-03-27 15:46:40.193912] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280580 entering state 10
[2025-03-27 15:46:40.193917] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280580 entering state 11
[2025-03-27 15:46:40.193922] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280580 entering state 11
[2025-03-27 15:46:40.193935] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280580 entering state 13
[2025-03-27 15:46:40.193941] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280580 entering state 0
[2025-03-27 15:46:40.193956] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280580 entering state 1
[2025-03-27 15:46:40.193961] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280580 entering state 2
[2025-03-27 15:46:40.193967] rdma.c:1504:nvmf_rdma_fill_wr_sgl: *DEBUG*: sge[0] 0x200017280a00 addr 0x200004000000, len 16
[2025-03-27 15:46:40.193972] rdma.c:1893:nvmf_rdma_request_parse_sgl: *DEBUG*: Request 0x200017280580 took 1 buffer/s from central pool
[2025-03-27 15:46:40.193977] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280580 entering state 5
[2025-03-27 15:46:40.193984] nvme_qpair.c: 223:nvme_admin_qpair_print_command: *NOTICE*: GET LOG PAGE (02) qid:0 cid:8201 nsid:0 cdw10:00030070 cdw11:00000000 SGL KEYED DATA BLOCK INVALIDATE KEY 0x3452d5980 len:0x10 key:0x2003c2
[2025-03-27 15:46:40.193996] ctrlr.c:2677:nvmf_ctrlr_get_log_page: *DEBUG*: Get log page: LID=0x70 offset=0x0 len=0x10 rae=0
[2025-03-27 15:46:40.194002] ctrlr_discovery.c: 108:nvmf_generate_discovery_log: *DEBUG*: Generating log page for genctr 1
[2025-03-27 15:46:40.194008] ctrlr_discovery.c: 137:nvmf_generate_discovery_log: *DEBUG*: listener 192.168.1.117:4520 trtype RDMA
[2025-03-27 15:46:40.194015] nvme_qpair.c: 474:spdk_nvme_print_completion: *NOTICE*: SUCCESS (00/00) qid:0 cid:8201 cdw0:0 sqhd:0000 p:0 m:0 dnr:0
[2025-03-27 15:46:40.194025] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280580 entering state 7
[2025-03-27 15:46:40.194031] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280580 entering state 8
[2025-03-27 15:46:40.194036] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280580 entering state 10
[2025-03-27 15:46:40.194042] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280580 entering state 11
[2025-03-27 15:46:40.194047] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280580 entering state 11
[2025-03-27 15:46:40.194059] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280580 entering state 13
[2025-03-27 15:46:40.194064] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280580 entering state 0
[2025-03-27 15:46:40.196168] rdma.c:3696:nvmf_process_cm_events: *DEBUG*: Acceptor Event: RDMA_CM_EVENT_ESTABLISHED
[2025-03-27 15:46:40.218459] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280580 entering state 1
[2025-03-27 15:46:40.218469] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280580 entering state 5
[2025-03-27 15:46:40.218487] nvme_qpair.c: 218:nvme_admin_qpair_print_command: *NOTICE*: FABRIC PROPERTY SET qid:0 cid:26 SGL KEYED DATA BLOCK ADDRESS 0x0 len:0x0 key:0x0
[2025-03-27 15:46:40.218501] ctrlr.c:1547:nvmf_property_set: *DEBUG*: size 0, offset 0x14, value 0x464001
[2025-03-27 15:46:40.218518] ctrlr.c:1572:nvmf_property_set: *DEBUG*: name: cc
[2025-03-27 15:46:40.218523] ctrlr.c:1237:nvmf_prop_set_cc: *DEBUG*: cur CC: 0x00460001
[2025-03-27 15:46:40.218539] ctrlr.c:1238:nvmf_prop_set_cc: *DEBUG*: new CC: 0x00464001
[2025-03-27 15:46:40.218544] ctrlr.c:1280:nvmf_prop_set_cc: *DEBUG*: Property Set CC Shutdown 01b!
[2025-03-27 15:46:40.218556] ctrlr.c:  89:nvmf_ctrlr_stop_keep_alive_timer: *DEBUG*: Stop keep alive poller
[2025-03-27 15:46:40.218563] nvme_qpair.c: 474:spdk_nvme_print_completion: *NOTICE*: SUCCESS (00/00) qid:0 cid:26 cdw0:0 sqhd:0000 p:0 m:0 dnr:0
[2025-03-27 15:46:40.218574] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280580 entering state 7
[2025-03-27 15:46:40.218579] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280580 entering state 9
[2025-03-27 15:46:40.218584] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280580 entering state 10
[2025-03-27 15:46:40.218589] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280580 entering state 12
[2025-03-27 15:46:40.218595] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280580 entering state 12
[2025-03-27 15:46:40.218604] ctrlr.c:1106:_nvmf_ctrlr_cc_reset_shn_done: *DEBUG*: ctrlr 0x55acf72de840 active queue count 1
[2025-03-27 15:46:40.218611] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280580 entering state 13
[2025-03-27 15:46:40.218617] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280580 entering state 0
[2025-03-27 15:46:40.218664] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280580 entering state 1
[2025-03-27 15:46:40.218670] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280580 entering state 5
[2025-03-27 15:46:40.218676] nvme_qpair.c: 218:nvme_admin_qpair_print_command: *NOTICE*: FABRIC PROPERTY GET qid:0 cid:27 SGL KEYED DATA BLOCK ADDRESS 0x0 len:0x0 key:0x0
[2025-03-27 15:46:40.218699] ctrlr.c:1489:nvmf_property_get: *DEBUG*: size 0, offset 0x1c
[2025-03-27 15:46:40.218705] ctrlr.c:1513:nvmf_property_get: *DEBUG*: name: csts
[2025-03-27 15:46:40.218709] ctrlr.c:1531:nvmf_property_get: *DEBUG*: response value: 0x9
[2025-03-27 15:46:40.218716] nvme_qpair.c: 474:spdk_nvme_print_completion: *NOTICE*: SUCCESS (00/00) qid:0 cid:27 cdw0:9 sqhd:0000 p:0 m:0 dnr:0
[2025-03-27 15:46:40.218726] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280580 entering state 7
[2025-03-27 15:46:40.218731] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280580 entering state 9
[2025-03-27 15:46:40.218735] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280580 entering state 10
[2025-03-27 15:46:40.218740] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280580 entering state 12
[2025-03-27 15:46:40.218746] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280580 entering state 12
[2025-03-27 15:46:40.218757] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280580 entering state 13
[2025-03-27 15:46:40.218762] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280580 entering state 0
[2025-03-27 15:46:40.226166] rdma.c:3696:nvmf_process_cm_events: *DEBUG*: Acceptor Event: RDMA_CM_EVENT_DISCONNECTED
[2025-03-27 15:46:40.226181] thread.c:2378:spdk_get_io_channel: *DEBUG*: Get io_channel 0x55acf71680b0 for io_device nvmf_tgt (0x55acf71676e0) on thread nvmf_tgt_poll_group_000 refcnt 2
[2025-03-27 15:46:40.226964] nvmf.c:1268:_nvmf_transport_qpair_fini_complete: *DEBUG*: Finish destroying qid 0
[2025-03-27 15:46:40.226994] nvmf.c:1250:_nvmf_ctrlr_free_from_qpair: *DEBUG*: qpair_mask cleared, qid 0
[2025-03-27 15:46:40.227013] nvmf.c:1254:_nvmf_ctrlr_free_from_qpair: *DEBUG*: Last qpair 0, destroy ctrlr 0x1
[2025-03-27 15:46:40.227019] subsystem.c:2585:nvmf_subsystem_remove_ctrlr: *DEBUG*: remove ctrlr 0x55acf72de840 id 0x1 from subsys 0x55acf7167a00 nqn.2014-08.org.nvmexpress.discovery
[2025-03-27 15:46:40.227025] ctrlr.c: 620:_nvmf_ctrlr_destruct: *DEBUG*: Destroy ctrlr 0x1
[2025-03-27 15:46:40.227069] ctrlr.c: 106:nvmf_ctrlr_stop_association_timer: *DEBUG*: Stop association timer
[2025-03-27 15:46:40.236167] rdma.c:3877:nvmf_process_ib_event: *DEBUG*: Last WQE reached event received for rqpair 0x55acf73960f0
[2025-03-27 15:46:40.236176] rdma.c:3939:nvmf_process_ib_events: *DEBUG*: Device mlx5_0: 1 events processed
[2025-03-27 15:46:40.237834] thread.c:2506:spdk_put_io_channel: *DEBUG*: Putting io_channel 0x55acf71680b0 for io_device nvmf_tgt (0x55acf71676e0) on thread nvmf_tgt_poll_group_000 refcnt 2



after connect:
[2025-03-27 15:51:28.062297] rdma.c:3696:nvmf_process_cm_events: *DEBUG*: Acceptor Event: RDMA_CM_EVENT_CONNECT_REQUEST
[2025-03-27 15:51:28.062319] rdma.c:1304:nvmf_rdma_connect: *DEBUG*: Connect Recv on fabric intf name mlx5_0, dev_name uverbs0
[2025-03-27 15:51:28.062324] rdma.c:1308:nvmf_rdma_connect: *DEBUG*: Listen Id was 0x55acf72dc370 with verbs 0x55acf7183e20. ListenAddr: 0x55acf728f990
[2025-03-27 15:51:28.062328] rdma.c:1315:nvmf_rdma_connect: *DEBUG*: Calculating Queue Depth
[2025-03-27 15:51:28.062331] rdma.c:1320:nvmf_rdma_connect: *DEBUG*: Target Max Queue Depth: 128
[2025-03-27 15:51:28.062335] rdma.c:1324:nvmf_rdma_connect: *DEBUG*: Local NIC Max Send/Recv Queue Depth: 32768 Max Read/Write Queue Depth: 16
[2025-03-27 15:51:28.062339] rdma.c:1331:nvmf_rdma_connect: *DEBUG*: Host (Initiator) NIC Max Incoming RDMA R/W operations: 16 Max Outgoing RDMA R/W operations: 0
[2025-03-27 15:51:28.062343] rdma.c:1360:nvmf_rdma_connect: *DEBUG*: Host Receive Queue Size: 32
[2025-03-27 15:51:28.062346] rdma.c:1361:nvmf_rdma_connect: *DEBUG*: Host Send Queue Size: 31
[2025-03-27 15:51:28.062349] rdma.c:1365:nvmf_rdma_connect: *DEBUG*: Final Negotiated Queue Depth: 32 R/W Depth: 16
[2025-03-27 15:51:28.063174] rdma.c:1026:nvmf_rdma_qpair_initialize: *DEBUG*: New RDMA Connection: 0x55acf725e180
[2025-03-27 15:51:28.064340] rdma.c:1256:nvmf_rdma_event_accept: *DEBUG*: Sent back the accept
[2025-03-27 15:51:28.065176] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 1
[2025-03-27 15:51:28.065185] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 2
[2025-03-27 15:51:28.065192] rdma.c:1504:nvmf_rdma_fill_wr_sgl: *DEBUG*: sge[0] 0x200017280480 addr 0x200004000000, len 1024
[2025-03-27 15:51:28.065209] rdma.c:1893:nvmf_rdma_request_parse_sgl: *DEBUG*: Request 0x200017280000 took 1 buffer/s from central pool
[2025-03-27 15:51:28.065213] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 3
[2025-03-27 15:51:28.065229] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 4
[2025-03-27 15:51:28.065242] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 5
[2025-03-27 15:51:28.065256] nvme_qpair.c: 218:nvme_admin_qpair_print_command: *NOTICE*: FABRIC CONNECT qid:0 cid:0 SGL KEYED DATA BLOCK INVALIDATE KEY 0x11e7c6000 len:0x400 key:0x2003df
[2025-03-27 15:51:28.065291] ctrlr.c: 855:_nvmf_ctrlr_connect: *DEBUG*: recfmt 0x0 qid 0 sqsize 31
[2025-03-27 15:51:28.065297] ctrlr.c: 858:_nvmf_ctrlr_connect: *DEBUG*: Connect data:
[2025-03-27 15:51:28.065313] ctrlr.c: 859:_nvmf_ctrlr_connect: *DEBUG*:   cntlid:  0xffff
[2025-03-27 15:51:28.065318] ctrlr.c: 860:_nvmf_ctrlr_connect: *DEBUG*:   hostid: c3ab7015-781c-4b07-af33-0cd1204f4499 ***
[2025-03-27 15:51:28.065322] ctrlr.c: 868:_nvmf_ctrlr_connect: *DEBUG*:   subnqn: "nqn.2022-06.io.spdk:cnode216"
[2025-03-27 15:51:28.065326] ctrlr.c: 869:_nvmf_ctrlr_connect: *DEBUG*:   hostnqn: "nqn.2014-08.org.nvmexpress:uuid:e553e370-9f7d-4802-8abf-745e75b2845c"
[2025-03-27 15:51:28.065331] ctrlr.c: 926:_nvmf_ctrlr_connect: *DEBUG*: Connect Admin Queue for controller ID 0xffff
[2025-03-27 15:51:28.065346] ctrlr.c: 574:nvmf_ctrlr_create: *DEBUG*: cap 0x201e01007f
[2025-03-27 15:51:28.065351] ctrlr.c: 575:nvmf_ctrlr_create: *DEBUG*: vs 0x10300
[2025-03-27 15:51:28.065354] ctrlr.c: 576:nvmf_ctrlr_create: *DEBUG*: cc 0x0
[2025-03-27 15:51:28.065360] ctrlr.c: 577:nvmf_ctrlr_create: *DEBUG*: csts 0x0
[2025-03-27 15:51:28.065368] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 6
[2025-03-27 15:51:28.065375] ctrlr.c: 215:nvmf_ctrlr_start_keep_alive_timer: *DEBUG*: Ctrlr add keep alive poller
[2025-03-27 15:51:28.065381] ctrlr.c: 320:nvmf_ctrlr_add_qpair: *DEBUG*: qpair_mask set, qid 0
[2025-03-27 15:51:28.065387] ctrlr.c: 266:nvmf_ctrlr_send_connect_rsp: *DEBUG*: connect capsule response: cntlid = 0x0001
[2025-03-27 15:51:28.065394] nvme_qpair.c: 474:spdk_nvme_print_completion: *NOTICE*: SUCCESS (00/00) qid:0 cid:0 cdw0:1 sqhd:0000 p:0 m:0 dnr:0
[2025-03-27 15:51:28.065406] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 7
[2025-03-27 15:51:28.065412] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 9
[2025-03-27 15:51:28.065417] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 10
[2025-03-27 15:51:28.065422] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 12
[2025-03-27 15:51:28.065434] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 13
[2025-03-27 15:51:28.065440] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 0
[2025-03-27 15:51:28.065507] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 1
[2025-03-27 15:51:28.065512] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 5
[2025-03-27 15:51:28.065518] nvme_qpair.c: 218:nvme_admin_qpair_print_command: *NOTICE*: FABRIC PROPERTY GET qid:0 cid:26 SGL KEYED DATA BLOCK ADDRESS 0x0 len:0x0 key:0x0
[2025-03-27 15:51:28.065529] ctrlr.c:1489:nvmf_property_get: *DEBUG*: size 1, offset 0x0
[2025-03-27 15:51:28.065535] ctrlr.c:1513:nvmf_property_get: *DEBUG*: name: cap
[2025-03-27 15:51:28.065538] ctrlr.c:1531:nvmf_property_get: *DEBUG*: response value: 0x201e01007f
[2025-03-27 15:51:28.065546] nvme_qpair.c: 474:spdk_nvme_print_completion: *NOTICE*: SUCCESS (00/00) qid:0 cid:26 cdw0:1e01007f sqhd:0000 p:0 m:0 dnr:0
[2025-03-27 15:51:28.065555] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 7
[2025-03-27 15:51:28.065560] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 9
[2025-03-27 15:51:28.065564] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 10
[2025-03-27 15:51:28.065569] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 12
[2025-03-27 15:51:28.065574] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 12
[2025-03-27 15:51:28.065584] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 13
[2025-03-27 15:51:28.065589] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 0
[2025-03-27 15:51:28.065598] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 1
[2025-03-27 15:51:28.065603] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 5
[2025-03-27 15:51:28.065610] nvme_qpair.c: 218:nvme_admin_qpair_print_command: *NOTICE*: FABRIC PROPERTY SET qid:0 cid:27 SGL KEYED DATA BLOCK ADDRESS 0x0 len:0x0 key:0x0
[2025-03-27 15:51:28.065620] ctrlr.c:1547:nvmf_property_set: *DEBUG*: size 0, offset 0x14, value 0x460000
[2025-03-27 15:51:28.065626] ctrlr.c:1572:nvmf_property_set: *DEBUG*: name: cc
[2025-03-27 15:51:28.065631] ctrlr.c:1237:nvmf_prop_set_cc: *DEBUG*: cur CC: 0x00000000
[2025-03-27 15:51:28.065635] ctrlr.c:1238:nvmf_prop_set_cc: *DEBUG*: new CC: 0x00460000
[2025-03-27 15:51:28.065640] ctrlr.c:1315:nvmf_prop_set_cc: *DEBUG*: Prop Set IOSQES = 6 (64 bytes)
[2025-03-27 15:51:28.065645] ctrlr.c:1322:nvmf_prop_set_cc: *DEBUG*: Prop Set IOCQES = 4 (16 bytes)
[2025-03-27 15:51:28.065651] nvme_qpair.c: 474:spdk_nvme_print_completion: *NOTICE*: SUCCESS (00/00) qid:0 cid:27 cdw0:0 sqhd:0000 p:0 m:0 dnr:0
[2025-03-27 15:51:28.065659] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 7
[2025-03-27 15:51:28.065664] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 9
[2025-03-27 15:51:28.065669] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 10
[2025-03-27 15:51:28.065674] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 12
[2025-03-27 15:51:28.065679] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 12
[2025-03-27 15:51:28.065689] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 13
[2025-03-27 15:51:28.065694] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 0
[2025-03-27 15:51:28.065703] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 1
[2025-03-27 15:51:28.065708] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 5
[2025-03-27 15:51:28.065714] nvme_qpair.c: 218:nvme_admin_qpair_print_command: *NOTICE*: FABRIC PROPERTY GET qid:0 cid:28 SGL KEYED DATA BLOCK ADDRESS 0x0 len:0x0 key:0x0
[2025-03-27 15:51:28.065723] ctrlr.c:1489:nvmf_property_get: *DEBUG*: size 0, offset 0x14
[2025-03-27 15:51:28.065728] ctrlr.c:1513:nvmf_property_get: *DEBUG*: name: cc
[2025-03-27 15:51:28.065733] ctrlr.c:1531:nvmf_property_get: *DEBUG*: response value: 0x460000
[2025-03-27 15:51:28.065738] nvme_qpair.c: 474:spdk_nvme_print_completion: *NOTICE*: SUCCESS (00/00) qid:0 cid:28 cdw0:460000 sqhd:0000 p:0 m:0 dnr:0
[2025-03-27 15:51:28.065747] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 7
[2025-03-27 15:51:28.065752] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 9
[2025-03-27 15:51:28.065768] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 10
[2025-03-27 15:51:28.065773] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 12
[2025-03-27 15:51:28.065778] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 12
[2025-03-27 15:51:28.065788] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 13
[2025-03-27 15:51:28.065793] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 0
[2025-03-27 15:51:28.065802] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 1
[2025-03-27 15:51:28.065807] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 5
[2025-03-27 15:51:28.065813] nvme_qpair.c: 218:nvme_admin_qpair_print_command: *NOTICE*: FABRIC PROPERTY GET qid:0 cid:29 SGL KEYED DATA BLOCK ADDRESS 0x0 len:0x0 key:0x0
[2025-03-27 15:51:28.065823] ctrlr.c:1489:nvmf_property_get: *DEBUG*: size 1, offset 0x0
[2025-03-27 15:51:28.065828] ctrlr.c:1513:nvmf_property_get: *DEBUG*: name: cap
[2025-03-27 15:51:28.065833] ctrlr.c:1531:nvmf_property_get: *DEBUG*: response value: 0x201e01007f
[2025-03-27 15:51:28.065838] nvme_qpair.c: 474:spdk_nvme_print_completion: *NOTICE*: SUCCESS (00/00) qid:0 cid:29 cdw0:1e01007f sqhd:0000 p:0 m:0 dnr:0
[2025-03-27 15:51:28.065847] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 7
[2025-03-27 15:51:28.065852] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 9
[2025-03-27 15:51:28.065869] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 10
[2025-03-27 15:51:28.065874] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 12
[2025-03-27 15:51:28.065879] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 12
[2025-03-27 15:51:28.065889] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 13
[2025-03-27 15:51:28.065895] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 0
[2025-03-27 15:51:28.065903] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 1
[2025-03-27 15:51:28.065908] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 5
[2025-03-27 15:51:28.065915] nvme_qpair.c: 218:nvme_admin_qpair_print_command: *NOTICE*: FABRIC PROPERTY SET qid:0 cid:4122 SGL KEYED DATA BLOCK ADDRESS 0x0 len:0x0 key:0x0
[2025-03-27 15:51:28.065924] ctrlr.c:1547:nvmf_property_set: *DEBUG*: size 0, offset 0x14, value 0x460001
[2025-03-27 15:51:28.065930] ctrlr.c:1572:nvmf_property_set: *DEBUG*: name: cc
[2025-03-27 15:51:28.065935] ctrlr.c:1237:nvmf_prop_set_cc: *DEBUG*: cur CC: 0x00460000
[2025-03-27 15:51:28.065939] ctrlr.c:1238:nvmf_prop_set_cc: *DEBUG*: new CC: 0x00460001
[2025-03-27 15:51:28.065944] ctrlr.c:1248:nvmf_prop_set_cc: *DEBUG*: Property Set CC Enable!
[2025-03-27 15:51:28.065950] nvme_qpair.c: 474:spdk_nvme_print_completion: *NOTICE*: SUCCESS (00/00) qid:0 cid:4122 cdw0:0 sqhd:0000 p:0 m:0 dnr:0
[2025-03-27 15:51:28.065959] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 7
[2025-03-27 15:51:28.065976] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 9
[2025-03-27 15:51:28.065981] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 10
[2025-03-27 15:51:28.065986] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 12
[2025-03-27 15:51:28.065992] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 12
[2025-03-27 15:51:28.066002] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 13
[2025-03-27 15:51:28.066007] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 0
[2025-03-27 15:51:28.066016] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 1
[2025-03-27 15:51:28.066021] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 5
[2025-03-27 15:51:28.066028] nvme_qpair.c: 218:nvme_admin_qpair_print_command: *NOTICE*: FABRIC PROPERTY GET qid:0 cid:4123 SGL KEYED DATA BLOCK ADDRESS 0x0 len:0x0 key:0x0
[2025-03-27 15:51:28.066038] ctrlr.c:1489:nvmf_property_get: *DEBUG*: size 0, offset 0x1c
[2025-03-27 15:51:28.066043] ctrlr.c:1513:nvmf_property_get: *DEBUG*: name: csts
[2025-03-27 15:51:28.066048] ctrlr.c:1531:nvmf_property_get: *DEBUG*: response value: 0x1
[2025-03-27 15:51:28.066054] nvme_qpair.c: 474:spdk_nvme_print_completion: *NOTICE*: SUCCESS (00/00) qid:0 cid:4123 cdw0:1 sqhd:0000 p:0 m:0 dnr:0
[2025-03-27 15:51:28.066063] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 7
[2025-03-27 15:51:28.066069] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 9
[2025-03-27 15:51:28.066074] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 10
[2025-03-27 15:51:28.066079] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 12
[2025-03-27 15:51:28.066084] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 12
[2025-03-27 15:51:28.066095] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 13
[2025-03-27 15:51:28.066101] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 0
[2025-03-27 15:51:28.066119] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 1
[2025-03-27 15:51:28.066125] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 5
[2025-03-27 15:51:28.066132] nvme_qpair.c: 218:nvme_admin_qpair_print_command: *NOTICE*: FABRIC PROPERTY GET qid:0 cid:4124 SGL KEYED DATA BLOCK ADDRESS 0x0 len:0x0 key:0x0
[2025-03-27 15:51:28.066142] ctrlr.c:1489:nvmf_property_get: *DEBUG*: size 0, offset 0x8
[2025-03-27 15:51:28.066148] ctrlr.c:1513:nvmf_property_get: *DEBUG*: name: vs
[2025-03-27 15:51:28.066153] ctrlr.c:1531:nvmf_property_get: *DEBUG*: response value: 0x10300
[2025-03-27 15:51:28.066170] nvme_qpair.c: 474:spdk_nvme_print_completion: *NOTICE*: SUCCESS (00/00) qid:0 cid:4124 cdw0:10300 sqhd:0000 p:0 m:0 dnr:0
[2025-03-27 15:51:28.066180] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 7
[2025-03-27 15:51:28.066186] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 9
[2025-03-27 15:51:28.066191] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 10
[2025-03-27 15:51:28.066196] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 12
[2025-03-27 15:51:28.066201] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 12
[2025-03-27 15:51:28.066212] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 13
[2025-03-27 15:51:28.066217] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 0
[2025-03-27 15:51:28.066228] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 1
[2025-03-27 15:51:28.066234] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 2
[2025-03-27 15:51:28.066240] rdma.c:1504:nvmf_rdma_fill_wr_sgl: *DEBUG*: sge[0] 0x200017280480 addr 0x200004000000, len 4096
[2025-03-27 15:51:28.066245] rdma.c:1893:nvmf_rdma_request_parse_sgl: *DEBUG*: Request 0x200017280000 took 1 buffer/s from central pool
[2025-03-27 15:51:28.066251] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 5
[2025-03-27 15:51:28.066258] nvme_qpair.c: 223:nvme_admin_qpair_print_command: *NOTICE*: IDENTIFY (06) qid:0 cid:4125 nsid:0 cdw10:00000001 cdw11:00000000 SGL KEYED DATA BLOCK INVALIDATE KEY 0x356487000 len:0x1000 key:0x2003e0
[2025-03-27 15:51:28.066281] ctrlr.c:3382:nvmf_ctrlr_identify: *DEBUG*: Received identify command with CNS 0x01
[2025-03-27 15:51:28.066288] ctrlr.c:2961:spdk_nvmf_ctrlr_identify_ctrlr: *DEBUG*: ctrlr data: maxcmd 0x80
[2025-03-27 15:51:28.066293] ctrlr.c:2962:spdk_nvmf_ctrlr_identify_ctrlr: *DEBUG*: sgls data: 0x100005
[2025-03-27 15:51:28.066300] ctrlr_bdev.c:  46:nvmf_subsystem_bdev_io_type_supported: *DEBUG*: All devices in Subsystem nqn.2022-06.io.spdk:cnode216 support io_type 3
[2025-03-27 15:51:28.066307] ctrlr_bdev.c:  46:nvmf_subsystem_bdev_io_type_supported: *DEBUG*: All devices in Subsystem nqn.2022-06.io.spdk:cnode216 support io_type 9
[2025-03-27 15:51:28.066312] ctrlr.c:3043:spdk_nvmf_ctrlr_identify_ctrlr: *DEBUG*: ext ctrlr data: ioccsz 0x104
[2025-03-27 15:51:28.066316] ctrlr.c:3045:spdk_nvmf_ctrlr_identify_ctrlr: *DEBUG*: ext ctrlr data: iorcsz 0x1
[2025-03-27 15:51:28.066320] ctrlr.c:3047:spdk_nvmf_ctrlr_identify_ctrlr: *DEBUG*: ext ctrlr data: icdoff 0x0
[2025-03-27 15:51:28.066325] ctrlr.c:3049:spdk_nvmf_ctrlr_identify_ctrlr: *DEBUG*: ext ctrlr data: ctrattr 0x0
[2025-03-27 15:51:28.066329] ctrlr.c:3051:spdk_nvmf_ctrlr_identify_ctrlr: *DEBUG*: ext ctrlr data: msdbd 0x10
[2025-03-27 15:51:28.066346] nvme_qpair.c: 474:spdk_nvme_print_completion: *NOTICE*: SUCCESS (00/00) qid:0 cid:4125 cdw0:0 sqhd:0000 p:0 m:0 dnr:0
[2025-03-27 15:51:28.066357] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 7
[2025-03-27 15:51:28.066362] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 8
[2025-03-27 15:51:28.066366] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 10
[2025-03-27 15:51:28.066371] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 11
[2025-03-27 15:51:28.066375] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 11
[2025-03-27 15:51:28.066389] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 13
[2025-03-27 15:51:28.066395] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 0
[2025-03-27 15:51:28.066459] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 1
[2025-03-27 15:51:28.066463] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 2
[2025-03-27 15:51:28.066468] rdma.c:1504:nvmf_rdma_fill_wr_sgl: *DEBUG*: sge[0] 0x200017280480 addr 0x200004000000, len 4096
[2025-03-27 15:51:28.066473] rdma.c:1893:nvmf_rdma_request_parse_sgl: *DEBUG*: Request 0x200017280000 took 1 buffer/s from central pool
[2025-03-27 15:51:28.066477] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 5
[2025-03-27 15:51:28.066483] nvme_qpair.c: 223:nvme_admin_qpair_print_command: *NOTICE*: GET LOG PAGE (02) qid:0 cid:8218 nsid:0 cdw10:03ff0005 cdw11:00000000 SGL KEYED DATA BLOCK INVALIDATE KEY 0x356485000 len:0x1000 key:0x2003e1
[2025-03-27 15:51:28.066494] ctrlr.c:2677:nvmf_ctrlr_get_log_page: *DEBUG*: Get log page: LID=0x05 offset=0x0 len=0x1000 rae=0
[2025-03-27 15:51:28.066501] ctrlr_bdev.c:  46:nvmf_subsystem_bdev_io_type_supported: *DEBUG*: All devices in Subsystem nqn.2022-06.io.spdk:cnode216 support io_type 9
[2025-03-27 15:51:28.066508] ctrlr_bdev.c:  46:nvmf_subsystem_bdev_io_type_supported: *DEBUG*: All devices in Subsystem nqn.2022-06.io.spdk:cnode216 support io_type 3
[2025-03-27 15:51:28.066517] nvme_qpair.c: 474:spdk_nvme_print_completion: *NOTICE*: SUCCESS (00/00) qid:0 cid:8218 cdw0:0 sqhd:0000 p:0 m:0 dnr:0
[2025-03-27 15:51:28.066526] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 7
[2025-03-27 15:51:28.066532] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 8
[2025-03-27 15:51:28.066536] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 10
[2025-03-27 15:51:28.066540] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 11
[2025-03-27 15:51:28.066545] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 11
[2025-03-27 15:51:28.066568] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 13
[2025-03-27 15:51:28.066574] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 0
[2025-03-27 15:51:28.066600] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 1
[2025-03-27 15:51:28.066605] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 2
[2025-03-27 15:51:28.066611] rdma.c:1504:nvmf_rdma_fill_wr_sgl: *DEBUG*: sge[0] 0x200017280480 addr 0x200004000000, len 8192
[2025-03-27 15:51:28.066616] rdma.c:1504:nvmf_rdma_fill_wr_sgl: *DEBUG*: sge[1] 0x200017280490 addr 0x200004002000, len 8192
[2025-03-27 15:51:28.066621] rdma.c:1504:nvmf_rdma_fill_wr_sgl: *DEBUG*: sge[2] 0x2000172804a0 addr 0x200004004000, len 2064
[2025-03-27 15:51:28.066625] rdma.c:1893:nvmf_rdma_request_parse_sgl: *DEBUG*: Request 0x200017280000 took 3 buffer/s from central pool
[2025-03-27 15:51:28.066630] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 5
[2025-03-27 15:51:28.066636] nvme_qpair.c: 223:nvme_admin_qpair_print_command: *NOTICE*: GET LOG PAGE (02) qid:0 cid:8219 nsid:ffffffff cdw10:1203000c cdw11:00000000 SGL KEYED DATA BLOCK INVALIDATE KEY 0x41fd88000 len:0x4810 key:0x2003e2
[2025-03-27 15:51:28.066647] ctrlr.c:2677:nvmf_ctrlr_get_log_page: *DEBUG*: Get log page: LID=0x0C offset=0x0 len=0x4810 rae=0
[2025-03-27 15:51:28.066659] nvme_qpair.c: 474:spdk_nvme_print_completion: *NOTICE*: SUCCESS (00/00) qid:0 cid:8219 cdw0:0 sqhd:0000 p:0 m:0 dnr:0
[2025-03-27 15:51:28.066668] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 7
[2025-03-27 15:51:28.066673] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 8
[2025-03-27 15:51:28.066677] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 10
[2025-03-27 15:51:28.066682] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 11
[2025-03-27 15:51:28.066687] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 11
[2025-03-27 15:51:28.066710] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 13
[2025-03-27 15:51:28.066715] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 0
[2025-03-27 15:51:28.066728] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 1
[2025-03-27 15:51:28.066733] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 2
[2025-03-27 15:51:28.066739] rdma.c:1504:nvmf_rdma_fill_wr_sgl: *DEBUG*: sge[0] 0x200017280480 addr 0x200004004000, len 512
[2025-03-27 15:51:28.066743] rdma.c:1893:nvmf_rdma_request_parse_sgl: *DEBUG*: Request 0x200017280000 took 1 buffer/s from central pool
[2025-03-27 15:51:28.066748] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 5
[2025-03-27 15:51:28.066754] nvme_qpair.c: 223:nvme_admin_qpair_print_command: *NOTICE*: GET LOG PAGE (02) qid:0 cid:8220 nsid:ffffffff cdw10:007f0002 cdw11:00000000 SGL KEYED DATA BLOCK INVALIDATE KEY 0x3c3bf0600 len:0x200 key:0x2003e3
[2025-03-27 15:51:28.066765] ctrlr.c:2677:nvmf_ctrlr_get_log_page: *DEBUG*: Get log page: LID=0x02 offset=0x0 len=0x200 rae=0
[2025-03-27 15:51:28.066771] nvme_qpair.c: 474:spdk_nvme_print_completion: *NOTICE*: SUCCESS (00/00) qid:0 cid:8220 cdw0:0 sqhd:0000 p:0 m:0 dnr:0
[2025-03-27 15:51:28.066779] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 7
[2025-03-27 15:51:28.066785] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 8
[2025-03-27 15:51:28.066789] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 10
[2025-03-27 15:51:28.066794] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 11
[2025-03-27 15:51:28.066799] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 11
[2025-03-27 15:51:28.066810] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 13
[2025-03-27 15:51:28.066815] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 0
[2025-03-27 15:51:28.066891] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 1
[2025-03-27 15:51:28.066896] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 5
[2025-03-27 15:51:28.066902] nvme_qpair.c: 213:nvme_admin_qpair_print_command: *NOTICE*: SET FEATURES NUMBER OF QUEUES cid:8221 cdw10:00000007 SGL KEYED DATA BLOCK ADDRESS 0x0 len:0x0 key:0x0
[2025-03-27 15:51:28.066912] ctrlr.c:2061:nvmf_ctrlr_set_features_number_of_queues: *DEBUG*: Set Features - Number of Queues, cdw11 0x230023
[2025-03-27 15:51:28.066920] nvme_qpair.c: 474:spdk_nvme_print_completion: *NOTICE*: SUCCESS (00/00) qid:0 cid:8221 cdw0:7e007e sqhd:0000 p:0 m:0 dnr:0
[2025-03-27 15:51:28.066928] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 7
[2025-03-27 15:51:28.066933] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 9
[2025-03-27 15:51:28.066938] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 10
[2025-03-27 15:51:28.066942] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 12
[2025-03-27 15:51:28.066947] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 12
[2025-03-27 15:51:28.066957] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 13
[2025-03-27 15:51:28.066962] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 0
[2025-03-27 15:51:28.072297] rdma.c:3696:nvmf_process_cm_events: *DEBUG*: Acceptor Event: RDMA_CM_EVENT_ESTABLISHED
[2025-03-27 15:51:28.172292] rdma.c:3696:nvmf_process_cm_events: *DEBUG*: Acceptor Event: RDMA_CM_EVENT_CONNECT_REQUEST
[2025-03-27 15:51:28.172305] rdma.c:1304:nvmf_rdma_connect: *DEBUG*: Connect Recv on fabric intf name mlx5_0, dev_name uverbs0
[2025-03-27 15:51:28.172309] rdma.c:1308:nvmf_rdma_connect: *DEBUG*: Listen Id was 0x55acf72dc370 with verbs 0x55acf7183e20. ListenAddr: 0x55acf728f990
[2025-03-27 15:51:28.172313] rdma.c:1315:nvmf_rdma_connect: *DEBUG*: Calculating Queue Depth
[2025-03-27 15:51:28.172316] rdma.c:1320:nvmf_rdma_connect: *DEBUG*: Target Max Queue Depth: 128
[2025-03-27 15:51:28.172320] rdma.c:1324:nvmf_rdma_connect: *DEBUG*: Local NIC Max Send/Recv Queue Depth: 32768 Max Read/Write Queue Depth: 16
[2025-03-27 15:51:28.172323] rdma.c:1331:nvmf_rdma_connect: *DEBUG*: Host (Initiator) NIC Max Incoming RDMA R/W operations: 16 Max Outgoing RDMA R/W operations: 0
[2025-03-27 15:51:28.172327] rdma.c:1360:nvmf_rdma_connect: *DEBUG*: Host Receive Queue Size: 128
[2025-03-27 15:51:28.172330] rdma.c:1361:nvmf_rdma_connect: *DEBUG*: Host Send Queue Size: 127
[2025-03-27 15:51:28.172333] rdma.c:1365:nvmf_rdma_connect: *DEBUG*: Final Negotiated Queue Depth: 128 R/W Depth: 16
[2025-03-27 15:51:28.173126] rdma.c:1026:nvmf_rdma_qpair_initialize: *DEBUG*: New RDMA Connection: 0x55acf725e6a0
[2025-03-27 15:51:28.173629] rdma.c:1256:nvmf_rdma_event_accept: *DEBUG*: Sent back the accept
[2025-03-27 15:51:28.182287] rdma.c:3696:nvmf_process_cm_events: *DEBUG*: Acceptor Event: RDMA_CM_EVENT_ESTABLISHED
[2025-03-27 15:51:28.272292] rdma.c:3696:nvmf_process_cm_events: *DEBUG*: Acceptor Event: RDMA_CM_EVENT_CONNECT_REQUEST
[2025-03-27 15:51:28.272302] rdma.c:1304:nvmf_rdma_connect: *DEBUG*: Connect Recv on fabric intf name mlx5_0, dev_name uverbs0
[2025-03-27 15:51:28.272306] rdma.c:1308:nvmf_rdma_connect: *DEBUG*: Listen Id was 0x55acf72dc370 with verbs 0x55acf7183e20. ListenAddr: 0x55acf728f990
[2025-03-27 15:51:28.272309] rdma.c:1315:nvmf_rdma_connect: *DEBUG*: Calculating Queue Depth
[2025-03-27 15:51:28.272313] rdma.c:1320:nvmf_rdma_connect: *DEBUG*: Target Max Queue Depth: 128
[2025-03-27 15:51:28.272316] rdma.c:1324:nvmf_rdma_connect: *DEBUG*: Local NIC Max Send/Recv Queue Depth: 32768 Max Read/Write Queue Depth: 16
[2025-03-27 15:51:28.272320] rdma.c:1331:nvmf_rdma_connect: *DEBUG*: Host (Initiator) NIC Max Incoming RDMA R/W operations: 16 Max Outgoing RDMA R/W operations: 0
[2025-03-27 15:51:28.272323] rdma.c:1360:nvmf_rdma_connect: *DEBUG*: Host Receive Queue Size: 128
[2025-03-27 15:51:28.272326] rdma.c:1361:nvmf_rdma_connect: *DEBUG*: Host Send Queue Size: 127
[2025-03-27 15:51:28.272330] rdma.c:1365:nvmf_rdma_connect: *DEBUG*: Final Negotiated Queue Depth: 128 R/W Depth: 16
[2025-03-27 15:51:28.273166] rdma.c:1026:nvmf_rdma_qpair_initialize: *DEBUG*: New RDMA Connection: 0x55acf72de530
[2025-03-27 15:51:28.273735] rdma.c:1256:nvmf_rdma_event_accept: *DEBUG*: Sent back the accept
[2025-03-27 15:51:28.282288] rdma.c:3696:nvmf_process_cm_events: *DEBUG*: Acceptor Event: RDMA_CM_EVENT_ESTABLISHED
[2025-03-27 15:51:28.372294] rdma.c:3696:nvmf_process_cm_events: *DEBUG*: Acceptor Event: RDMA_CM_EVENT_CONNECT_REQUEST
[2025-03-27 15:51:28.372304] rdma.c:1304:nvmf_rdma_connect: *DEBUG*: Connect Recv on fabric intf name mlx5_0, dev_name uverbs0
[2025-03-27 15:51:28.372308] rdma.c:1308:nvmf_rdma_connect: *DEBUG*: Listen Id was 0x55acf72dc370 with verbs 0x55acf7183e20. ListenAddr: 0x55acf728f990
[2025-03-27 15:51:28.372311] rdma.c:1315:nvmf_rdma_connect: *DEBUG*: Calculating Queue Depth
[2025-03-27 15:51:28.372315] rdma.c:1320:nvmf_rdma_connect: *DEBUG*: Target Max Queue Depth: 128
[2025-03-27 15:51:28.372318] rdma.c:1324:nvmf_rdma_connect: *DEBUG*: Local NIC Max Send/Recv Queue Depth: 32768 Max Read/Write Queue Depth: 16
[2025-03-27 15:51:28.372322] rdma.c:1331:nvmf_rdma_connect: *DEBUG*: Host (Initiator) NIC Max Incoming RDMA R/W operations: 16 Max Outgoing RDMA R/W operations: 0
[2025-03-27 15:51:28.372325] rdma.c:1360:nvmf_rdma_connect: *DEBUG*: Host Receive Queue Size: 128
[2025-03-27 15:51:28.372328] rdma.c:1361:nvmf_rdma_connect: *DEBUG*: Host Send Queue Size: 127
[2025-03-27 15:51:28.372331] rdma.c:1365:nvmf_rdma_connect: *DEBUG*: Final Negotiated Queue Depth: 128 R/W Depth: 16
[2025-03-27 15:51:28.373124] rdma.c:1026:nvmf_rdma_qpair_initialize: *DEBUG*: New RDMA Connection: 0x55acf752f270
[2025-03-27 15:51:28.373712] rdma.c:1256:nvmf_rdma_event_accept: *DEBUG*: Sent back the accept
[2025-03-27 15:51:28.382290] rdma.c:3696:nvmf_process_cm_events: *DEBUG*: Acceptor Event: RDMA_CM_EVENT_ESTABLISHED
[2025-03-27 15:51:28.472296] rdma.c:3696:nvmf_process_cm_events: *DEBUG*: Acceptor Event: RDMA_CM_EVENT_CONNECT_REQUEST
[2025-03-27 15:51:28.472306] rdma.c:1304:nvmf_rdma_connect: *DEBUG*: Connect Recv on fabric intf name mlx5_0, dev_name uverbs0
[2025-03-27 15:51:28.472311] rdma.c:1308:nvmf_rdma_connect: *DEBUG*: Listen Id was 0x55acf72dc370 with verbs 0x55acf7183e20. ListenAddr: 0x55acf728f990
[2025-03-27 15:51:28.472314] rdma.c:1315:nvmf_rdma_connect: *DEBUG*: Calculating Queue Depth
[2025-03-27 15:51:28.472317] rdma.c:1320:nvmf_rdma_connect: *DEBUG*: Target Max Queue Depth: 128
[2025-03-27 15:51:28.472320] rdma.c:1324:nvmf_rdma_connect: *DEBUG*: Local NIC Max Send/Recv Queue Depth: 32768 Max Read/Write Queue Depth: 16
[2025-03-27 15:51:28.472324] rdma.c:1331:nvmf_rdma_connect: *DEBUG*: Host (Initiator) NIC Max Incoming RDMA R/W operations: 16 Max Outgoing RDMA R/W operations: 0
[2025-03-27 15:51:28.472327] rdma.c:1360:nvmf_rdma_connect: *DEBUG*: Host Receive Queue Size: 128
[2025-03-27 15:51:28.472330] rdma.c:1361:nvmf_rdma_connect: *DEBUG*: Host Send Queue Size: 127
[2025-03-27 15:51:28.472334] rdma.c:1365:nvmf_rdma_connect: *DEBUG*: Final Negotiated Queue Depth: 128 R/W Depth: 16
[2025-03-27 15:51:28.473153] rdma.c:1026:nvmf_rdma_qpair_initialize: *DEBUG*: New RDMA Connection: 0x55acf752f9f0
[2025-03-27 15:51:28.473686] rdma.c:1256:nvmf_rdma_event_accept: *DEBUG*: Sent back the accept
[2025-03-27 15:51:28.482293] rdma.c:3696:nvmf_process_cm_events: *DEBUG*: Acceptor Event: RDMA_CM_EVENT_ESTABLISHED
[2025-03-27 15:51:28.572298] rdma.c:3696:nvmf_process_cm_events: *DEBUG*: Acceptor Event: RDMA_CM_EVENT_CONNECT_REQUEST
[2025-03-27 15:51:28.572308] rdma.c:1304:nvmf_rdma_connect: *DEBUG*: Connect Recv on fabric intf name mlx5_0, dev_name uverbs0
[2025-03-27 15:51:28.572312] rdma.c:1308:nvmf_rdma_connect: *DEBUG*: Listen Id was 0x55acf72dc370 with verbs 0x55acf7183e20. ListenAddr: 0x55acf728f990
[2025-03-27 15:51:28.572315] rdma.c:1315:nvmf_rdma_connect: *DEBUG*: Calculating Queue Depth
[2025-03-27 15:51:28.572319] rdma.c:1320:nvmf_rdma_connect: *DEBUG*: Target Max Queue Depth: 128
[2025-03-27 15:51:28.572322] rdma.c:1324:nvmf_rdma_connect: *DEBUG*: Local NIC Max Send/Recv Queue Depth: 32768 Max Read/Write Queue Depth: 16
[2025-03-27 15:51:28.572325] rdma.c:1331:nvmf_rdma_connect: *DEBUG*: Host (Initiator) NIC Max Incoming RDMA R/W operations: 16 Max Outgoing RDMA R/W operations: 0
[2025-03-27 15:51:28.572329] rdma.c:1360:nvmf_rdma_connect: *DEBUG*: Host Receive Queue Size: 128
[2025-03-27 15:51:28.572332] rdma.c:1361:nvmf_rdma_connect: *DEBUG*: Host Send Queue Size: 127
[2025-03-27 15:51:28.572335] rdma.c:1365:nvmf_rdma_connect: *DEBUG*: Final Negotiated Queue Depth: 128 R/W Depth: 16
[2025-03-27 15:51:28.573144] rdma.c:1026:nvmf_rdma_qpair_initialize: *DEBUG*: New RDMA Connection: 0x55acf7571310
[2025-03-27 15:51:28.573648] rdma.c:1256:nvmf_rdma_event_accept: *DEBUG*: Sent back the accept
[2025-03-27 15:51:28.582294] rdma.c:3696:nvmf_process_cm_events: *DEBUG*: Acceptor Event: RDMA_CM_EVENT_ESTABLISHED
[2025-03-27 15:51:28.672299] rdma.c:3696:nvmf_process_cm_events: *DEBUG*: Acceptor Event: RDMA_CM_EVENT_CONNECT_REQUEST
[2025-03-27 15:51:28.672309] rdma.c:1304:nvmf_rdma_connect: *DEBUG*: Connect Recv on fabric intf name mlx5_0, dev_name uverbs0
[2025-03-27 15:51:28.672313] rdma.c:1308:nvmf_rdma_connect: *DEBUG*: Listen Id was 0x55acf72dc370 with verbs 0x55acf7183e20. ListenAddr: 0x55acf728f990
[2025-03-27 15:51:28.672316] rdma.c:1315:nvmf_rdma_connect: *DEBUG*: Calculating Queue Depth
[2025-03-27 15:51:28.672319] rdma.c:1320:nvmf_rdma_connect: *DEBUG*: Target Max Queue Depth: 128
[2025-03-27 15:51:28.672323] rdma.c:1324:nvmf_rdma_connect: *DEBUG*: Local NIC Max Send/Recv Queue Depth: 32768 Max Read/Write Queue Depth: 16
[2025-03-27 15:51:28.672326] rdma.c:1331:nvmf_rdma_connect: *DEBUG*: Host (Initiator) NIC Max Incoming RDMA R/W operations: 16 Max Outgoing RDMA R/W operations: 0
[2025-03-27 15:51:28.672330] rdma.c:1360:nvmf_rdma_connect: *DEBUG*: Host Receive Queue Size: 128
[2025-03-27 15:51:28.672333] rdma.c:1361:nvmf_rdma_connect: *DEBUG*: Host Send Queue Size: 127
[2025-03-27 15:51:28.672336] rdma.c:1365:nvmf_rdma_connect: *DEBUG*: Final Negotiated Queue Depth: 128 R/W Depth: 16
[2025-03-27 15:51:28.673163] rdma.c:1026:nvmf_rdma_qpair_initialize: *DEBUG*: New RDMA Connection: 0x55acf7571bd0
[2025-03-27 15:51:28.673732] rdma.c:1256:nvmf_rdma_event_accept: *DEBUG*: Sent back the accept
[2025-03-27 15:51:28.682296] rdma.c:3696:nvmf_process_cm_events: *DEBUG*: Acceptor Event: RDMA_CM_EVENT_ESTABLISHED
[2025-03-27 15:51:28.772302] rdma.c:3696:nvmf_process_cm_events: *DEBUG*: Acceptor Event: RDMA_CM_EVENT_CONNECT_REQUEST
[2025-03-27 15:51:28.772311] rdma.c:1304:nvmf_rdma_connect: *DEBUG*: Connect Recv on fabric intf name mlx5_0, dev_name uverbs0
[2025-03-27 15:51:28.772315] rdma.c:1308:nvmf_rdma_connect: *DEBUG*: Listen Id was 0x55acf72dc370 with verbs 0x55acf7183e20. ListenAddr: 0x55acf728f990
[2025-03-27 15:51:28.772319] rdma.c:1315:nvmf_rdma_connect: *DEBUG*: Calculating Queue Depth
[2025-03-27 15:51:28.772322] rdma.c:1320:nvmf_rdma_connect: *DEBUG*: Target Max Queue Depth: 128
[2025-03-27 15:51:28.772326] rdma.c:1324:nvmf_rdma_connect: *DEBUG*: Local NIC Max Send/Recv Queue Depth: 32768 Max Read/Write Queue Depth: 16
[2025-03-27 15:51:28.772329] rdma.c:1331:nvmf_rdma_connect: *DEBUG*: Host (Initiator) NIC Max Incoming RDMA R/W operations: 16 Max Outgoing RDMA R/W operations: 0
[2025-03-27 15:51:28.772332] rdma.c:1360:nvmf_rdma_connect: *DEBUG*: Host Receive Queue Size: 128
[2025-03-27 15:51:28.772336] rdma.c:1361:nvmf_rdma_connect: *DEBUG*: Host Send Queue Size: 127
[2025-03-27 15:51:28.772339] rdma.c:1365:nvmf_rdma_connect: *DEBUG*: Final Negotiated Queue Depth: 128 R/W Depth: 16
[2025-03-27 15:51:28.773208] rdma.c:1026:nvmf_rdma_qpair_initialize: *DEBUG*: New RDMA Connection: 0x55acf7571eb0
[2025-03-27 15:51:28.773717] rdma.c:1256:nvmf_rdma_event_accept: *DEBUG*: Sent back the accept
[2025-03-27 15:51:28.782298] rdma.c:3696:nvmf_process_cm_events: *DEBUG*: Acceptor Event: RDMA_CM_EVENT_ESTABLISHED
[2025-03-27 15:51:28.872302] rdma.c:3696:nvmf_process_cm_events: *DEBUG*: Acceptor Event: RDMA_CM_EVENT_CONNECT_REQUEST
[2025-03-27 15:51:28.872311] rdma.c:1304:nvmf_rdma_connect: *DEBUG*: Connect Recv on fabric intf name mlx5_0, dev_name uverbs0
[2025-03-27 15:51:28.872316] rdma.c:1308:nvmf_rdma_connect: *DEBUG*: Listen Id was 0x55acf72dc370 with verbs 0x55acf7183e20. ListenAddr: 0x55acf728f990
[2025-03-27 15:51:28.872319] rdma.c:1315:nvmf_rdma_connect: *DEBUG*: Calculating Queue Depth
[2025-03-27 15:51:28.872322] rdma.c:1320:nvmf_rdma_connect: *DEBUG*: Target Max Queue Depth: 128
[2025-03-27 15:51:28.872326] rdma.c:1324:nvmf_rdma_connect: *DEBUG*: Local NIC Max Send/Recv Queue Depth: 32768 Max Read/Write Queue Depth: 16
[2025-03-27 15:51:28.872329] rdma.c:1331:nvmf_rdma_connect: *DEBUG*: Host (Initiator) NIC Max Incoming RDMA R/W operations: 16 Max Outgoing RDMA R/W operations: 0
[2025-03-27 15:51:28.872333] rdma.c:1360:nvmf_rdma_connect: *DEBUG*: Host Receive Queue Size: 128
[2025-03-27 15:51:28.872336] rdma.c:1361:nvmf_rdma_connect: *DEBUG*: Host Send Queue Size: 127
[2025-03-27 15:51:28.872339] rdma.c:1365:nvmf_rdma_connect: *DEBUG*: Final Negotiated Queue Depth: 128 R/W Depth: 16
[2025-03-27 15:51:28.873139] rdma.c:1026:nvmf_rdma_qpair_initialize: *DEBUG*: New RDMA Connection: 0x55acf7594e10
[2025-03-27 15:51:28.873678] rdma.c:1256:nvmf_rdma_event_accept: *DEBUG*: Sent back the accept
[2025-03-27 15:51:28.882299] rdma.c:3696:nvmf_process_cm_events: *DEBUG*: Acceptor Event: RDMA_CM_EVENT_ESTABLISHED
[2025-03-27 15:51:28.972305] rdma.c:3696:nvmf_process_cm_events: *DEBUG*: Acceptor Event: RDMA_CM_EVENT_CONNECT_REQUEST
[2025-03-27 15:51:28.972314] rdma.c:1304:nvmf_rdma_connect: *DEBUG*: Connect Recv on fabric intf name mlx5_0, dev_name uverbs0
[2025-03-27 15:51:28.972318] rdma.c:1308:nvmf_rdma_connect: *DEBUG*: Listen Id was 0x55acf72dc370 with verbs 0x55acf7183e20. ListenAddr: 0x55acf728f990
[2025-03-27 15:51:28.972321] rdma.c:1315:nvmf_rdma_connect: *DEBUG*: Calculating Queue Depth
[2025-03-27 15:51:28.972324] rdma.c:1320:nvmf_rdma_connect: *DEBUG*: Target Max Queue Depth: 128
[2025-03-27 15:51:28.972328] rdma.c:1324:nvmf_rdma_connect: *DEBUG*: Local NIC Max Send/Recv Queue Depth: 32768 Max Read/Write Queue Depth: 16
[2025-03-27 15:51:28.972331] rdma.c:1331:nvmf_rdma_connect: *DEBUG*: Host (Initiator) NIC Max Incoming RDMA R/W operations: 16 Max Outgoing RDMA R/W operations: 0
[2025-03-27 15:51:28.972335] rdma.c:1360:nvmf_rdma_connect: *DEBUG*: Host Receive Queue Size: 128
[2025-03-27 15:51:28.972338] rdma.c:1361:nvmf_rdma_connect: *DEBUG*: Host Send Queue Size: 127
[2025-03-27 15:51:28.972341] rdma.c:1365:nvmf_rdma_connect: *DEBUG*: Final Negotiated Queue Depth: 128 R/W Depth: 16
[2025-03-27 15:51:28.973136] rdma.c:1026:nvmf_rdma_qpair_initialize: *DEBUG*: New RDMA Connection: 0x55acf75bd800
[2025-03-27 15:51:28.973676] rdma.c:1256:nvmf_rdma_event_accept: *DEBUG*: Sent back the accept
[2025-03-27 15:51:28.982301] rdma.c:3696:nvmf_process_cm_events: *DEBUG*: Acceptor Event: RDMA_CM_EVENT_ESTABLISHED
[2025-03-27 15:51:29.072308] rdma.c:3696:nvmf_process_cm_events: *DEBUG*: Acceptor Event: RDMA_CM_EVENT_CONNECT_REQUEST
[2025-03-27 15:51:29.072319] rdma.c:1304:nvmf_rdma_connect: *DEBUG*: Connect Recv on fabric intf name mlx5_0, dev_name uverbs0
[2025-03-27 15:51:29.072324] rdma.c:1308:nvmf_rdma_connect: *DEBUG*: Listen Id was 0x55acf72dc370 with verbs 0x55acf7183e20. ListenAddr: 0x55acf728f990
[2025-03-27 15:51:29.072339] rdma.c:1315:nvmf_rdma_connect: *DEBUG*: Calculating Queue Depth
[2025-03-27 15:51:29.072343] rdma.c:1320:nvmf_rdma_connect: *DEBUG*: Target Max Queue Depth: 128
[2025-03-27 15:51:29.072347] rdma.c:1324:nvmf_rdma_connect: *DEBUG*: Local NIC Max Send/Recv Queue Depth: 32768 Max Read/Write Queue Depth: 16
[2025-03-27 15:51:29.072357] rdma.c:1331:nvmf_rdma_connect: *DEBUG*: Host (Initiator) NIC Max Incoming RDMA R/W operations: 16 Max Outgoing RDMA R/W operations: 0
[2025-03-27 15:51:29.072361] rdma.c:1360:nvmf_rdma_connect: *DEBUG*: Host Receive Queue Size: 128
[2025-03-27 15:51:29.072364] rdma.c:1361:nvmf_rdma_connect: *DEBUG*: Host Send Queue Size: 127
[2025-03-27 15:51:29.072369] rdma.c:1365:nvmf_rdma_connect: *DEBUG*: Final Negotiated Queue Depth: 128 R/W Depth: 16
[2025-03-27 15:51:29.073076] rdma.c:1026:nvmf_rdma_qpair_initialize: *DEBUG*: New RDMA Connection: 0x55acf75bdeb0
[2025-03-27 15:51:29.073566] rdma.c:1256:nvmf_rdma_event_accept: *DEBUG*: Sent back the accept
[2025-03-27 15:51:29.082303] rdma.c:3696:nvmf_process_cm_events: *DEBUG*: Acceptor Event: RDMA_CM_EVENT_ESTABLISHED
[2025-03-27 15:51:29.172310] rdma.c:3696:nvmf_process_cm_events: *DEBUG*: Acceptor Event: RDMA_CM_EVENT_CONNECT_REQUEST
[2025-03-27 15:51:29.172323] rdma.c:1304:nvmf_rdma_connect: *DEBUG*: Connect Recv on fabric intf name mlx5_0, dev_name uverbs0
[2025-03-27 15:51:29.172327] rdma.c:1308:nvmf_rdma_connect: *DEBUG*: Listen Id was 0x55acf72dc370 with verbs 0x55acf7183e20. ListenAddr: 0x55acf728f990
[2025-03-27 15:51:29.172331] rdma.c:1315:nvmf_rdma_connect: *DEBUG*: Calculating Queue Depth
[2025-03-27 15:51:29.172334] rdma.c:1320:nvmf_rdma_connect: *DEBUG*: Target Max Queue Depth: 128
[2025-03-27 15:51:29.172338] rdma.c:1324:nvmf_rdma_connect: *DEBUG*: Local NIC Max Send/Recv Queue Depth: 32768 Max Read/Write Queue Depth: 16
[2025-03-27 15:51:29.172341] rdma.c:1331:nvmf_rdma_connect: *DEBUG*: Host (Initiator) NIC Max Incoming RDMA R/W operations: 16 Max Outgoing RDMA R/W operations: 0
[2025-03-27 15:51:29.172345] rdma.c:1360:nvmf_rdma_connect: *DEBUG*: Host Receive Queue Size: 128
[2025-03-27 15:51:29.172348] rdma.c:1361:nvmf_rdma_connect: *DEBUG*: Host Send Queue Size: 127
[2025-03-27 15:51:29.172351] rdma.c:1365:nvmf_rdma_connect: *DEBUG*: Final Negotiated Queue Depth: 128 R/W Depth: 16
[2025-03-27 15:51:29.173173] rdma.c:1026:nvmf_rdma_qpair_initialize: *DEBUG*: New RDMA Connection: 0x55acf75e69c0
[2025-03-27 15:51:29.173672] rdma.c:1256:nvmf_rdma_event_accept: *DEBUG*: Sent back the accept
[2025-03-27 15:51:29.182305] rdma.c:3696:nvmf_process_cm_events: *DEBUG*: Acceptor Event: RDMA_CM_EVENT_ESTABLISHED
[2025-03-27 15:51:29.272311] rdma.c:3696:nvmf_process_cm_events: *DEBUG*: Acceptor Event: RDMA_CM_EVENT_CONNECT_REQUEST
[2025-03-27 15:51:29.272320] rdma.c:1304:nvmf_rdma_connect: *DEBUG*: Connect Recv on fabric intf name mlx5_0, dev_name uverbs0
[2025-03-27 15:51:29.272324] rdma.c:1308:nvmf_rdma_connect: *DEBUG*: Listen Id was 0x55acf72dc370 with verbs 0x55acf7183e20. ListenAddr: 0x55acf728f990
[2025-03-27 15:51:29.272339] rdma.c:1315:nvmf_rdma_connect: *DEBUG*: Calculating Queue Depth
[2025-03-27 15:51:29.272343] rdma.c:1320:nvmf_rdma_connect: *DEBUG*: Target Max Queue Depth: 128
[2025-03-27 15:51:29.272346] rdma.c:1324:nvmf_rdma_connect: *DEBUG*: Local NIC Max Send/Recv Queue Depth: 32768 Max Read/Write Queue Depth: 16
[2025-03-27 15:51:29.272350] rdma.c:1331:nvmf_rdma_connect: *DEBUG*: Host (Initiator) NIC Max Incoming RDMA R/W operations: 16 Max Outgoing RDMA R/W operations: 0
[2025-03-27 15:51:29.272353] rdma.c:1360:nvmf_rdma_connect: *DEBUG*: Host Receive Queue Size: 128
[2025-03-27 15:51:29.272357] rdma.c:1361:nvmf_rdma_connect: *DEBUG*: Host Send Queue Size: 127
[2025-03-27 15:51:29.272360] rdma.c:1365:nvmf_rdma_connect: *DEBUG*: Final Negotiated Queue Depth: 128 R/W Depth: 16
[2025-03-27 15:51:29.273105] rdma.c:1026:nvmf_rdma_qpair_initialize: *DEBUG*: New RDMA Connection: 0x55acf76612f0
[2025-03-27 15:51:29.273649] rdma.c:1256:nvmf_rdma_event_accept: *DEBUG*: Sent back the accept
[2025-03-27 15:51:29.282307] rdma.c:3696:nvmf_process_cm_events: *DEBUG*: Acceptor Event: RDMA_CM_EVENT_ESTABLISHED
[2025-03-27 15:51:29.372313] rdma.c:3696:nvmf_process_cm_events: *DEBUG*: Acceptor Event: RDMA_CM_EVENT_CONNECT_REQUEST
[2025-03-27 15:51:29.372324] rdma.c:1304:nvmf_rdma_connect: *DEBUG*: Connect Recv on fabric intf name mlx5_0, dev_name uverbs0
[2025-03-27 15:51:29.372328] rdma.c:1308:nvmf_rdma_connect: *DEBUG*: Listen Id was 0x55acf72dc370 with verbs 0x55acf7183e20. ListenAddr: 0x55acf728f990
[2025-03-27 15:51:29.372331] rdma.c:1315:nvmf_rdma_connect: *DEBUG*: Calculating Queue Depth
[2025-03-27 15:51:29.372334] rdma.c:1320:nvmf_rdma_connect: *DEBUG*: Target Max Queue Depth: 128
[2025-03-27 15:51:29.372338] rdma.c:1324:nvmf_rdma_connect: *DEBUG*: Local NIC Max Send/Recv Queue Depth: 32768 Max Read/Write Queue Depth: 16
[2025-03-27 15:51:29.372341] rdma.c:1331:nvmf_rdma_connect: *DEBUG*: Host (Initiator) NIC Max Incoming RDMA R/W operations: 16 Max Outgoing RDMA R/W operations: 0
[2025-03-27 15:51:29.372345] rdma.c:1360:nvmf_rdma_connect: *DEBUG*: Host Receive Queue Size: 128
[2025-03-27 15:51:29.372348] rdma.c:1361:nvmf_rdma_connect: *DEBUG*: Host Send Queue Size: 127
[2025-03-27 15:51:29.372351] rdma.c:1365:nvmf_rdma_connect: *DEBUG*: Final Negotiated Queue Depth: 128 R/W Depth: 16
[2025-03-27 15:51:29.373067] rdma.c:1026:nvmf_rdma_qpair_initialize: *DEBUG*: New RDMA Connection: 0x55acf7661ac0
[2025-03-27 15:51:29.373571] rdma.c:1256:nvmf_rdma_event_accept: *DEBUG*: Sent back the accept
[2025-03-27 15:51:29.382309] rdma.c:3696:nvmf_process_cm_events: *DEBUG*: Acceptor Event: RDMA_CM_EVENT_ESTABLISHED
[2025-03-27 15:51:29.472315] rdma.c:3696:nvmf_process_cm_events: *DEBUG*: Acceptor Event: RDMA_CM_EVENT_CONNECT_REQUEST
[2025-03-27 15:51:29.472325] rdma.c:1304:nvmf_rdma_connect: *DEBUG*: Connect Recv on fabric intf name mlx5_0, dev_name uverbs0
[2025-03-27 15:51:29.472329] rdma.c:1308:nvmf_rdma_connect: *DEBUG*: Listen Id was 0x55acf72dc370 with verbs 0x55acf7183e20. ListenAddr: 0x55acf728f990
[2025-03-27 15:51:29.472332] rdma.c:1315:nvmf_rdma_connect: *DEBUG*: Calculating Queue Depth
[2025-03-27 15:51:29.472335] rdma.c:1320:nvmf_rdma_connect: *DEBUG*: Target Max Queue Depth: 128
[2025-03-27 15:51:29.472339] rdma.c:1324:nvmf_rdma_connect: *DEBUG*: Local NIC Max Send/Recv Queue Depth: 32768 Max Read/Write Queue Depth: 16
[2025-03-27 15:51:29.472342] rdma.c:1331:nvmf_rdma_connect: *DEBUG*: Host (Initiator) NIC Max Incoming RDMA R/W operations: 16 Max Outgoing RDMA R/W operations: 0
[2025-03-27 15:51:29.472345] rdma.c:1360:nvmf_rdma_connect: *DEBUG*: Host Receive Queue Size: 128
[2025-03-27 15:51:29.472349] rdma.c:1361:nvmf_rdma_connect: *DEBUG*: Host Send Queue Size: 127
[2025-03-27 15:51:29.472352] rdma.c:1365:nvmf_rdma_connect: *DEBUG*: Final Negotiated Queue Depth: 128 R/W Depth: 16
[2025-03-27 15:51:29.473083] rdma.c:1026:nvmf_rdma_qpair_initialize: *DEBUG*: New RDMA Connection: 0x55acf76382f0
[2025-03-27 15:51:29.473664] rdma.c:1256:nvmf_rdma_event_accept: *DEBUG*: Sent back the accept
[2025-03-27 15:51:29.482311] rdma.c:3696:nvmf_process_cm_events: *DEBUG*: Acceptor Event: RDMA_CM_EVENT_ESTABLISHED
[2025-03-27 15:51:29.572317] rdma.c:3696:nvmf_process_cm_events: *DEBUG*: Acceptor Event: RDMA_CM_EVENT_CONNECT_REQUEST
[2025-03-27 15:51:29.572327] rdma.c:1304:nvmf_rdma_connect: *DEBUG*: Connect Recv on fabric intf name mlx5_0, dev_name uverbs0
[2025-03-27 15:51:29.572331] rdma.c:1308:nvmf_rdma_connect: *DEBUG*: Listen Id was 0x55acf72dc370 with verbs 0x55acf7183e20. ListenAddr: 0x55acf728f990
[2025-03-27 15:51:29.572334] rdma.c:1315:nvmf_rdma_connect: *DEBUG*: Calculating Queue Depth
[2025-03-27 15:51:29.572337] rdma.c:1320:nvmf_rdma_connect: *DEBUG*: Target Max Queue Depth: 128
[2025-03-27 15:51:29.572340] rdma.c:1324:nvmf_rdma_connect: *DEBUG*: Local NIC Max Send/Recv Queue Depth: 32768 Max Read/Write Queue Depth: 16
[2025-03-27 15:51:29.572344] rdma.c:1331:nvmf_rdma_connect: *DEBUG*: Host (Initiator) NIC Max Incoming RDMA R/W operations: 16 Max Outgoing RDMA R/W operations: 0
[2025-03-27 15:51:29.572347] rdma.c:1360:nvmf_rdma_connect: *DEBUG*: Host Receive Queue Size: 128
[2025-03-27 15:51:29.572350] rdma.c:1361:nvmf_rdma_connect: *DEBUG*: Host Send Queue Size: 127
[2025-03-27 15:51:29.572354] rdma.c:1365:nvmf_rdma_connect: *DEBUG*: Final Negotiated Queue Depth: 128 R/W Depth: 16
[2025-03-27 15:51:29.573160] rdma.c:1026:nvmf_rdma_qpair_initialize: *DEBUG*: New RDMA Connection: 0x55acf7638b10
[2025-03-27 15:51:29.573645] rdma.c:1256:nvmf_rdma_event_accept: *DEBUG*: Sent back the accept
[2025-03-27 15:51:29.582314] rdma.c:3696:nvmf_process_cm_events: *DEBUG*: Acceptor Event: RDMA_CM_EVENT_ESTABLISHED
[2025-03-27 15:51:29.672319] rdma.c:3696:nvmf_process_cm_events: *DEBUG*: Acceptor Event: RDMA_CM_EVENT_CONNECT_REQUEST
[2025-03-27 15:51:29.672328] rdma.c:1304:nvmf_rdma_connect: *DEBUG*: Connect Recv on fabric intf name mlx5_0, dev_name uverbs0
[2025-03-27 15:51:29.672332] rdma.c:1308:nvmf_rdma_connect: *DEBUG*: Listen Id was 0x55acf72dc370 with verbs 0x55acf7183e20. ListenAddr: 0x55acf728f990
[2025-03-27 15:51:29.672336] rdma.c:1315:nvmf_rdma_connect: *DEBUG*: Calculating Queue Depth
[2025-03-27 15:51:29.672339] rdma.c:1320:nvmf_rdma_connect: *DEBUG*: Target Max Queue Depth: 128
[2025-03-27 15:51:29.672342] rdma.c:1324:nvmf_rdma_connect: *DEBUG*: Local NIC Max Send/Recv Queue Depth: 32768 Max Read/Write Queue Depth: 16
[2025-03-27 15:51:29.672346] rdma.c:1331:nvmf_rdma_connect: *DEBUG*: Host (Initiator) NIC Max Incoming RDMA R/W operations: 16 Max Outgoing RDMA R/W operations: 0
[2025-03-27 15:51:29.672349] rdma.c:1360:nvmf_rdma_connect: *DEBUG*: Host Receive Queue Size: 128
[2025-03-27 15:51:29.672352] rdma.c:1361:nvmf_rdma_connect: *DEBUG*: Host Send Queue Size: 127
[2025-03-27 15:51:29.672355] rdma.c:1365:nvmf_rdma_connect: *DEBUG*: Final Negotiated Queue Depth: 128 R/W Depth: 16
[2025-03-27 15:51:29.673152] rdma.c:1026:nvmf_rdma_qpair_initialize: *DEBUG*: New RDMA Connection: 0x55acf7705410
[2025-03-27 15:51:29.673675] rdma.c:1256:nvmf_rdma_event_accept: *DEBUG*: Sent back the accept
[2025-03-27 15:51:29.682316] rdma.c:3696:nvmf_process_cm_events: *DEBUG*: Acceptor Event: RDMA_CM_EVENT_ESTABLISHED
[2025-03-27 15:51:29.772321] rdma.c:3696:nvmf_process_cm_events: *DEBUG*: Acceptor Event: RDMA_CM_EVENT_CONNECT_REQUEST
[2025-03-27 15:51:29.772331] rdma.c:1304:nvmf_rdma_connect: *DEBUG*: Connect Recv on fabric intf name mlx5_0, dev_name uverbs0
[2025-03-27 15:51:29.772335] rdma.c:1308:nvmf_rdma_connect: *DEBUG*: Listen Id was 0x55acf72dc370 with verbs 0x55acf7183e20. ListenAddr: 0x55acf728f990
[2025-03-27 15:51:29.772338] rdma.c:1315:nvmf_rdma_connect: *DEBUG*: Calculating Queue Depth
[2025-03-27 15:51:29.772341] rdma.c:1320:nvmf_rdma_connect: *DEBUG*: Target Max Queue Depth: 128
[2025-03-27 15:51:29.772345] rdma.c:1324:nvmf_rdma_connect: *DEBUG*: Local NIC Max Send/Recv Queue Depth: 32768 Max Read/Write Queue Depth: 16
[2025-03-27 15:51:29.772348] rdma.c:1331:nvmf_rdma_connect: *DEBUG*: Host (Initiator) NIC Max Incoming RDMA R/W operations: 16 Max Outgoing RDMA R/W operations: 0
[2025-03-27 15:51:29.772352] rdma.c:1360:nvmf_rdma_connect: *DEBUG*: Host Receive Queue Size: 128
[2025-03-27 15:51:29.772355] rdma.c:1361:nvmf_rdma_connect: *DEBUG*: Host Send Queue Size: 127
[2025-03-27 15:51:29.772358] rdma.c:1365:nvmf_rdma_connect: *DEBUG*: Final Negotiated Queue Depth: 128 R/W Depth: 16
[2025-03-27 15:51:29.773160] rdma.c:1026:nvmf_rdma_qpair_initialize: *DEBUG*: New RDMA Connection: 0x55acf7705b90
[2025-03-27 15:51:29.773687] rdma.c:1256:nvmf_rdma_event_accept: *DEBUG*: Sent back the accept
[2025-03-27 15:51:29.782318] rdma.c:3696:nvmf_process_cm_events: *DEBUG*: Acceptor Event: RDMA_CM_EVENT_ESTABLISHED
[2025-03-27 15:51:29.872323] rdma.c:3696:nvmf_process_cm_events: *DEBUG*: Acceptor Event: RDMA_CM_EVENT_CONNECT_REQUEST
[2025-03-27 15:51:29.872331] rdma.c:1304:nvmf_rdma_connect: *DEBUG*: Connect Recv on fabric intf name mlx5_0, dev_name uverbs0
[2025-03-27 15:51:29.872336] rdma.c:1308:nvmf_rdma_connect: *DEBUG*: Listen Id was 0x55acf72dc370 with verbs 0x55acf7183e20. ListenAddr: 0x55acf728f990
[2025-03-27 15:51:29.872339] rdma.c:1315:nvmf_rdma_connect: *DEBUG*: Calculating Queue Depth
[2025-03-27 15:51:29.872342] rdma.c:1320:nvmf_rdma_connect: *DEBUG*: Target Max Queue Depth: 128
[2025-03-27 15:51:29.872345] rdma.c:1324:nvmf_rdma_connect: *DEBUG*: Local NIC Max Send/Recv Queue Depth: 32768 Max Read/Write Queue Depth: 16
[2025-03-27 15:51:29.872349] rdma.c:1331:nvmf_rdma_connect: *DEBUG*: Host (Initiator) NIC Max Incoming RDMA R/W operations: 16 Max Outgoing RDMA R/W operations: 0
[2025-03-27 15:51:29.872352] rdma.c:1360:nvmf_rdma_connect: *DEBUG*: Host Receive Queue Size: 128
[2025-03-27 15:51:29.872355] rdma.c:1361:nvmf_rdma_connect: *DEBUG*: Host Send Queue Size: 127
[2025-03-27 15:51:29.872359] rdma.c:1365:nvmf_rdma_connect: *DEBUG*: Final Negotiated Queue Depth: 128 R/W Depth: 16
[2025-03-27 15:51:29.873082] rdma.c:1026:nvmf_rdma_qpair_initialize: *DEBUG*: New RDMA Connection: 0x55acf768a410
[2025-03-27 15:51:29.873623] rdma.c:1256:nvmf_rdma_event_accept: *DEBUG*: Sent back the accept
[2025-03-27 15:51:29.882320] rdma.c:3696:nvmf_process_cm_events: *DEBUG*: Acceptor Event: RDMA_CM_EVENT_ESTABLISHED
[2025-03-27 15:51:29.972325] rdma.c:3696:nvmf_process_cm_events: *DEBUG*: Acceptor Event: RDMA_CM_EVENT_CONNECT_REQUEST
[2025-03-27 15:51:29.972335] rdma.c:1304:nvmf_rdma_connect: *DEBUG*: Connect Recv on fabric intf name mlx5_0, dev_name uverbs0
[2025-03-27 15:51:29.972339] rdma.c:1308:nvmf_rdma_connect: *DEBUG*: Listen Id was 0x55acf72dc370 with verbs 0x55acf7183e20. ListenAddr: 0x55acf728f990
[2025-03-27 15:51:29.972342] rdma.c:1315:nvmf_rdma_connect: *DEBUG*: Calculating Queue Depth
[2025-03-27 15:51:29.972346] rdma.c:1320:nvmf_rdma_connect: *DEBUG*: Target Max Queue Depth: 128
[2025-03-27 15:51:29.972349] rdma.c:1324:nvmf_rdma_connect: *DEBUG*: Local NIC Max Send/Recv Queue Depth: 32768 Max Read/Write Queue Depth: 16
[2025-03-27 15:51:29.972353] rdma.c:1331:nvmf_rdma_connect: *DEBUG*: Host (Initiator) NIC Max Incoming RDMA R/W operations: 16 Max Outgoing RDMA R/W operations: 0
[2025-03-27 15:51:29.972356] rdma.c:1360:nvmf_rdma_connect: *DEBUG*: Host Receive Queue Size: 128
[2025-03-27 15:51:29.972359] rdma.c:1361:nvmf_rdma_connect: *DEBUG*: Host Send Queue Size: 127
[2025-03-27 15:51:29.972363] rdma.c:1365:nvmf_rdma_connect: *DEBUG*: Final Negotiated Queue Depth: 128 R/W Depth: 16
[2025-03-27 15:51:29.973153] rdma.c:1026:nvmf_rdma_qpair_initialize: *DEBUG*: New RDMA Connection: 0x55acf768ac30
[2025-03-27 15:51:29.973685] rdma.c:1256:nvmf_rdma_event_accept: *DEBUG*: Sent back the accept
[2025-03-27 15:51:29.982322] rdma.c:3696:nvmf_process_cm_events: *DEBUG*: Acceptor Event: RDMA_CM_EVENT_ESTABLISHED
[2025-03-27 15:51:30.072326] rdma.c:3696:nvmf_process_cm_events: *DEBUG*: Acceptor Event: RDMA_CM_EVENT_CONNECT_REQUEST
[2025-03-27 15:51:30.072335] rdma.c:1304:nvmf_rdma_connect: *DEBUG*: Connect Recv on fabric intf name mlx5_0, dev_name uverbs0
[2025-03-27 15:51:30.072339] rdma.c:1308:nvmf_rdma_connect: *DEBUG*: Listen Id was 0x55acf72dc370 with verbs 0x55acf7183e20. ListenAddr: 0x55acf728f990
[2025-03-27 15:51:30.072343] rdma.c:1315:nvmf_rdma_connect: *DEBUG*: Calculating Queue Depth
[2025-03-27 15:51:30.072346] rdma.c:1320:nvmf_rdma_connect: *DEBUG*: Target Max Queue Depth: 128
[2025-03-27 15:51:30.072349] rdma.c:1324:nvmf_rdma_connect: *DEBUG*: Local NIC Max Send/Recv Queue Depth: 32768 Max Read/Write Queue Depth: 16
[2025-03-27 15:51:30.072353] rdma.c:1331:nvmf_rdma_connect: *DEBUG*: Host (Initiator) NIC Max Incoming RDMA R/W operations: 16 Max Outgoing RDMA R/W operations: 0
[2025-03-27 15:51:30.072356] rdma.c:1360:nvmf_rdma_connect: *DEBUG*: Host Receive Queue Size: 128
[2025-03-27 15:51:30.072359] rdma.c:1361:nvmf_rdma_connect: *DEBUG*: Host Send Queue Size: 127
[2025-03-27 15:51:30.072363] rdma.c:1365:nvmf_rdma_connect: *DEBUG*: Final Negotiated Queue Depth: 128 R/W Depth: 16
[2025-03-27 15:51:30.073087] rdma.c:1026:nvmf_rdma_qpair_initialize: *DEBUG*: New RDMA Connection: 0x55acf77576c0
[2025-03-27 15:51:30.073615] rdma.c:1256:nvmf_rdma_event_accept: *DEBUG*: Sent back the accept
[2025-03-27 15:51:30.082323] rdma.c:3696:nvmf_process_cm_events: *DEBUG*: Acceptor Event: RDMA_CM_EVENT_ESTABLISHED
[2025-03-27 15:51:30.172329] rdma.c:3696:nvmf_process_cm_events: *DEBUG*: Acceptor Event: RDMA_CM_EVENT_CONNECT_REQUEST
[2025-03-27 15:51:30.172339] rdma.c:1304:nvmf_rdma_connect: *DEBUG*: Connect Recv on fabric intf name mlx5_0, dev_name uverbs0
[2025-03-27 15:51:30.172343] rdma.c:1308:nvmf_rdma_connect: *DEBUG*: Listen Id was 0x55acf72dc370 with verbs 0x55acf7183e20. ListenAddr: 0x55acf728f990
[2025-03-27 15:51:30.172346] rdma.c:1315:nvmf_rdma_connect: *DEBUG*: Calculating Queue Depth
[2025-03-27 15:51:30.172349] rdma.c:1320:nvmf_rdma_connect: *DEBUG*: Target Max Queue Depth: 128
[2025-03-27 15:51:30.172353] rdma.c:1324:nvmf_rdma_connect: *DEBUG*: Local NIC Max Send/Recv Queue Depth: 32768 Max Read/Write Queue Depth: 16
[2025-03-27 15:51:30.172356] rdma.c:1331:nvmf_rdma_connect: *DEBUG*: Host (Initiator) NIC Max Incoming RDMA R/W operations: 16 Max Outgoing RDMA R/W operations: 0
[2025-03-27 15:51:30.172360] rdma.c:1360:nvmf_rdma_connect: *DEBUG*: Host Receive Queue Size: 128
[2025-03-27 15:51:30.172363] rdma.c:1361:nvmf_rdma_connect: *DEBUG*: Host Send Queue Size: 127
[2025-03-27 15:51:30.172366] rdma.c:1365:nvmf_rdma_connect: *DEBUG*: Final Negotiated Queue Depth: 128 R/W Depth: 16
[2025-03-27 15:51:30.173099] rdma.c:1026:nvmf_rdma_qpair_initialize: *DEBUG*: New RDMA Connection: 0x55acf7757e90
[2025-03-27 15:51:30.173637] rdma.c:1256:nvmf_rdma_event_accept: *DEBUG*: Sent back the accept
[2025-03-27 15:51:30.182325] rdma.c:3696:nvmf_process_cm_events: *DEBUG*: Acceptor Event: RDMA_CM_EVENT_ESTABLISHED
[2025-03-27 15:51:30.272330] rdma.c:3696:nvmf_process_cm_events: *DEBUG*: Acceptor Event: RDMA_CM_EVENT_CONNECT_REQUEST
[2025-03-27 15:51:30.272340] rdma.c:1304:nvmf_rdma_connect: *DEBUG*: Connect Recv on fabric intf name mlx5_0, dev_name uverbs0
[2025-03-27 15:51:30.272344] rdma.c:1308:nvmf_rdma_connect: *DEBUG*: Listen Id was 0x55acf72dc370 with verbs 0x55acf7183e20. ListenAddr: 0x55acf728f990
[2025-03-27 15:51:30.272347] rdma.c:1315:nvmf_rdma_connect: *DEBUG*: Calculating Queue Depth
[2025-03-27 15:51:30.272350] rdma.c:1320:nvmf_rdma_connect: *DEBUG*: Target Max Queue Depth: 128
[2025-03-27 15:51:30.272354] rdma.c:1324:nvmf_rdma_connect: *DEBUG*: Local NIC Max Send/Recv Queue Depth: 32768 Max Read/Write Queue Depth: 16
[2025-03-27 15:51:30.272357] rdma.c:1331:nvmf_rdma_connect: *DEBUG*: Host (Initiator) NIC Max Incoming RDMA R/W operations: 16 Max Outgoing RDMA R/W operations: 0
[2025-03-27 15:51:30.272361] rdma.c:1360:nvmf_rdma_connect: *DEBUG*: Host Receive Queue Size: 128
[2025-03-27 15:51:30.272364] rdma.c:1361:nvmf_rdma_connect: *DEBUG*: Host Send Queue Size: 127
[2025-03-27 15:51:30.272367] rdma.c:1365:nvmf_rdma_connect: *DEBUG*: Final Negotiated Queue Depth: 128 R/W Depth: 16
[2025-03-27 15:51:30.273151] rdma.c:1026:nvmf_rdma_qpair_initialize: *DEBUG*: New RDMA Connection: 0x55acf76b36c0
[2025-03-27 15:51:30.273744] rdma.c:1256:nvmf_rdma_event_accept: *DEBUG*: Sent back the accept
[2025-03-27 15:51:30.282327] rdma.c:3696:nvmf_process_cm_events: *DEBUG*: Acceptor Event: RDMA_CM_EVENT_ESTABLISHED
[2025-03-27 15:51:30.372333] rdma.c:3696:nvmf_process_cm_events: *DEBUG*: Acceptor Event: RDMA_CM_EVENT_CONNECT_REQUEST
[2025-03-27 15:51:30.372342] rdma.c:1304:nvmf_rdma_connect: *DEBUG*: Connect Recv on fabric intf name mlx5_0, dev_name uverbs0
[2025-03-27 15:51:30.372346] rdma.c:1308:nvmf_rdma_connect: *DEBUG*: Listen Id was 0x55acf72dc370 with verbs 0x55acf7183e20. ListenAddr: 0x55acf728f990
[2025-03-27 15:51:30.372350] rdma.c:1315:nvmf_rdma_connect: *DEBUG*: Calculating Queue Depth
[2025-03-27 15:51:30.372353] rdma.c:1320:nvmf_rdma_connect: *DEBUG*: Target Max Queue Depth: 128
[2025-03-27 15:51:30.372356] rdma.c:1324:nvmf_rdma_connect: *DEBUG*: Local NIC Max Send/Recv Queue Depth: 32768 Max Read/Write Queue Depth: 16
[2025-03-27 15:51:30.372360] rdma.c:1331:nvmf_rdma_connect: *DEBUG*: Host (Initiator) NIC Max Incoming RDMA R/W operations: 16 Max Outgoing RDMA R/W operations: 0
[2025-03-27 15:51:30.372363] rdma.c:1360:nvmf_rdma_connect: *DEBUG*: Host Receive Queue Size: 128
[2025-03-27 15:51:30.372367] rdma.c:1361:nvmf_rdma_connect: *DEBUG*: Host Send Queue Size: 127
[2025-03-27 15:51:30.372370] rdma.c:1365:nvmf_rdma_connect: *DEBUG*: Final Negotiated Queue Depth: 128 R/W Depth: 16
[2025-03-27 15:51:30.373155] rdma.c:1026:nvmf_rdma_qpair_initialize: *DEBUG*: New RDMA Connection: 0x55acf76b3e90
[2025-03-27 15:51:30.373729] rdma.c:1256:nvmf_rdma_event_accept: *DEBUG*: Sent back the accept
[2025-03-27 15:51:30.382329] rdma.c:3696:nvmf_process_cm_events: *DEBUG*: Acceptor Event: RDMA_CM_EVENT_ESTABLISHED
[2025-03-27 15:51:30.472334] rdma.c:3696:nvmf_process_cm_events: *DEBUG*: Acceptor Event: RDMA_CM_EVENT_CONNECT_REQUEST
[2025-03-27 15:51:30.472343] rdma.c:1304:nvmf_rdma_connect: *DEBUG*: Connect Recv on fabric intf name mlx5_0, dev_name uverbs0
[2025-03-27 15:51:30.472347] rdma.c:1308:nvmf_rdma_connect: *DEBUG*: Listen Id was 0x55acf72dc370 with verbs 0x55acf7183e20. ListenAddr: 0x55acf728f990
[2025-03-27 15:51:30.472351] rdma.c:1315:nvmf_rdma_connect: *DEBUG*: Calculating Queue Depth
[2025-03-27 15:51:30.472354] rdma.c:1320:nvmf_rdma_connect: *DEBUG*: Target Max Queue Depth: 128
[2025-03-27 15:51:30.472357] rdma.c:1324:nvmf_rdma_connect: *DEBUG*: Local NIC Max Send/Recv Queue Depth: 32768 Max Read/Write Queue Depth: 16
[2025-03-27 15:51:30.472361] rdma.c:1331:nvmf_rdma_connect: *DEBUG*: Host (Initiator) NIC Max Incoming RDMA R/W operations: 16 Max Outgoing RDMA R/W operations: 0
[2025-03-27 15:51:30.472364] rdma.c:1360:nvmf_rdma_connect: *DEBUG*: Host Receive Queue Size: 128
[2025-03-27 15:51:30.472367] rdma.c:1361:nvmf_rdma_connect: *DEBUG*: Host Send Queue Size: 127
[2025-03-27 15:51:30.472370] rdma.c:1365:nvmf_rdma_connect: *DEBUG*: Final Negotiated Queue Depth: 128 R/W Depth: 16
[2025-03-27 15:51:30.473047] rdma.c:1026:nvmf_rdma_qpair_initialize: *DEBUG*: New RDMA Connection: 0x55acf78246c0
[2025-03-27 15:51:30.473560] rdma.c:1256:nvmf_rdma_event_accept: *DEBUG*: Sent back the accept
[2025-03-27 15:51:30.482331] rdma.c:3696:nvmf_process_cm_events: *DEBUG*: Acceptor Event: RDMA_CM_EVENT_ESTABLISHED
[2025-03-27 15:51:30.572336] rdma.c:3696:nvmf_process_cm_events: *DEBUG*: Acceptor Event: RDMA_CM_EVENT_CONNECT_REQUEST
[2025-03-27 15:51:30.572346] rdma.c:1304:nvmf_rdma_connect: *DEBUG*: Connect Recv on fabric intf name mlx5_0, dev_name uverbs0
[2025-03-27 15:51:30.572350] rdma.c:1308:nvmf_rdma_connect: *DEBUG*: Listen Id was 0x55acf72dc370 with verbs 0x55acf7183e20. ListenAddr: 0x55acf728f990
[2025-03-27 15:51:30.572353] rdma.c:1315:nvmf_rdma_connect: *DEBUG*: Calculating Queue Depth
[2025-03-27 15:51:30.572356] rdma.c:1320:nvmf_rdma_connect: *DEBUG*: Target Max Queue Depth: 128
[2025-03-27 15:51:30.572360] rdma.c:1324:nvmf_rdma_connect: *DEBUG*: Local NIC Max Send/Recv Queue Depth: 32768 Max Read/Write Queue Depth: 16
[2025-03-27 15:51:30.572363] rdma.c:1331:nvmf_rdma_connect: *DEBUG*: Host (Initiator) NIC Max Incoming RDMA R/W operations: 16 Max Outgoing RDMA R/W operations: 0
[2025-03-27 15:51:30.572366] rdma.c:1360:nvmf_rdma_connect: *DEBUG*: Host Receive Queue Size: 128
[2025-03-27 15:51:30.572370] rdma.c:1361:nvmf_rdma_connect: *DEBUG*: Host Send Queue Size: 127
[2025-03-27 15:51:30.572373] rdma.c:1365:nvmf_rdma_connect: *DEBUG*: Final Negotiated Queue Depth: 128 R/W Depth: 16
[2025-03-27 15:51:30.573096] rdma.c:1026:nvmf_rdma_qpair_initialize: *DEBUG*: New RDMA Connection: 0x55acf7824e90
[2025-03-27 15:51:30.573609] rdma.c:1256:nvmf_rdma_event_accept: *DEBUG*: Sent back the accept
[2025-03-27 15:51:30.582333] rdma.c:3696:nvmf_process_cm_events: *DEBUG*: Acceptor Event: RDMA_CM_EVENT_ESTABLISHED
[2025-03-27 15:51:30.672339] rdma.c:3696:nvmf_process_cm_events: *DEBUG*: Acceptor Event: RDMA_CM_EVENT_CONNECT_REQUEST
[2025-03-27 15:51:30.672349] rdma.c:1304:nvmf_rdma_connect: *DEBUG*: Connect Recv on fabric intf name mlx5_0, dev_name uverbs0
[2025-03-27 15:51:30.672364] rdma.c:1308:nvmf_rdma_connect: *DEBUG*: Listen Id was 0x55acf72dc370 with verbs 0x55acf7183e20. ListenAddr: 0x55acf728f990
[2025-03-27 15:51:30.672368] rdma.c:1315:nvmf_rdma_connect: *DEBUG*: Calculating Queue Depth
[2025-03-27 15:51:30.672371] rdma.c:1320:nvmf_rdma_connect: *DEBUG*: Target Max Queue Depth: 128
[2025-03-27 15:51:30.672375] rdma.c:1324:nvmf_rdma_connect: *DEBUG*: Local NIC Max Send/Recv Queue Depth: 32768 Max Read/Write Queue Depth: 16
[2025-03-27 15:51:30.672379] rdma.c:1331:nvmf_rdma_connect: *DEBUG*: Host (Initiator) NIC Max Incoming RDMA R/W operations: 16 Max Outgoing RDMA R/W operations: 0
[2025-03-27 15:51:30.672382] rdma.c:1360:nvmf_rdma_connect: *DEBUG*: Host Receive Queue Size: 128
[2025-03-27 15:51:30.672386] rdma.c:1361:nvmf_rdma_connect: *DEBUG*: Host Send Queue Size: 127
[2025-03-27 15:51:30.672389] rdma.c:1365:nvmf_rdma_connect: *DEBUG*: Final Negotiated Queue Depth: 128 R/W Depth: 16
[2025-03-27 15:51:30.673121] rdma.c:1026:nvmf_rdma_qpair_initialize: *DEBUG*: New RDMA Connection: 0x55acf77d2670
[2025-03-27 15:51:30.673626] rdma.c:1256:nvmf_rdma_event_accept: *DEBUG*: Sent back the accept
[2025-03-27 15:51:30.682335] rdma.c:3696:nvmf_process_cm_events: *DEBUG*: Acceptor Event: RDMA_CM_EVENT_ESTABLISHED
[2025-03-27 15:51:30.696251] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 1
[2025-03-27 15:51:30.696261] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 5
[2025-03-27 15:51:30.696270] nvme_qpair.c: 223:nvme_admin_qpair_print_command: *NOTICE*: KEEP ALIVE (18) qid:0 cid:1 nsid:0 cdw10:00000000 cdw11:00000000 
[2025-03-27 15:51:30.696289] ctrlr.c:3808:nvmf_ctrlr_keep_alive: *DEBUG*: Keep Alive
[2025-03-27 15:51:30.696308] nvme_qpair.c: 474:spdk_nvme_print_completion: *NOTICE*: SUCCESS (00/00) qid:0 cid:1 cdw0:0 sqhd:0000 p:0 m:0 dnr:0
[2025-03-27 15:51:30.696316] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 7
[2025-03-27 15:51:30.696321] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 9
[2025-03-27 15:51:30.696337] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 10
[2025-03-27 15:51:30.696341] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 12
[2025-03-27 15:51:30.696358] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 12
[2025-03-27 15:51:30.696370] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 13
[2025-03-27 15:51:30.696375] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 0
[2025-03-27 15:51:30.772341] rdma.c:3696:nvmf_process_cm_events: *DEBUG*: Acceptor Event: RDMA_CM_EVENT_CONNECT_REQUEST
[2025-03-27 15:51:30.772350] rdma.c:1304:nvmf_rdma_connect: *DEBUG*: Connect Recv on fabric intf name mlx5_0, dev_name uverbs0
[2025-03-27 15:51:30.772354] rdma.c:1308:nvmf_rdma_connect: *DEBUG*: Listen Id was 0x55acf72dc370 with verbs 0x55acf7183e20. ListenAddr: 0x55acf728f990
[2025-03-27 15:51:30.772358] rdma.c:1315:nvmf_rdma_connect: *DEBUG*: Calculating Queue Depth
[2025-03-27 15:51:30.772361] rdma.c:1320:nvmf_rdma_connect: *DEBUG*: Target Max Queue Depth: 128
[2025-03-27 15:51:30.772364] rdma.c:1324:nvmf_rdma_connect: *DEBUG*: Local NIC Max Send/Recv Queue Depth: 32768 Max Read/Write Queue Depth: 16
[2025-03-27 15:51:30.772368] rdma.c:1331:nvmf_rdma_connect: *DEBUG*: Host (Initiator) NIC Max Incoming RDMA R/W operations: 16 Max Outgoing RDMA R/W operations: 0
[2025-03-27 15:51:30.772371] rdma.c:1360:nvmf_rdma_connect: *DEBUG*: Host Receive Queue Size: 128
[2025-03-27 15:51:30.772374] rdma.c:1361:nvmf_rdma_connect: *DEBUG*: Host Send Queue Size: 127
[2025-03-27 15:51:30.772378] rdma.c:1365:nvmf_rdma_connect: *DEBUG*: Final Negotiated Queue Depth: 128 R/W Depth: 16
[2025-03-27 15:51:30.773178] rdma.c:1026:nvmf_rdma_qpair_initialize: *DEBUG*: New RDMA Connection: 0x55acf77d2e90
[2025-03-27 15:51:30.773661] rdma.c:1256:nvmf_rdma_event_accept: *DEBUG*: Sent back the accept
[2025-03-27 15:51:30.782337] rdma.c:3696:nvmf_process_cm_events: *DEBUG*: Acceptor Event: RDMA_CM_EVENT_ESTABLISHED
[2025-03-27 15:51:30.872343] rdma.c:3696:nvmf_process_cm_events: *DEBUG*: Acceptor Event: RDMA_CM_EVENT_CONNECT_REQUEST
[2025-03-27 15:51:30.872356] rdma.c:1304:nvmf_rdma_connect: *DEBUG*: Connect Recv on fabric intf name mlx5_0, dev_name uverbs0
[2025-03-27 15:51:30.872361] rdma.c:1308:nvmf_rdma_connect: *DEBUG*: Listen Id was 0x55acf72dc370 with verbs 0x55acf7183e20. ListenAddr: 0x55acf728f990
[2025-03-27 15:51:30.872364] rdma.c:1315:nvmf_rdma_connect: *DEBUG*: Calculating Queue Depth
[2025-03-27 15:51:30.872367] rdma.c:1320:nvmf_rdma_connect: *DEBUG*: Target Max Queue Depth: 128
[2025-03-27 15:51:30.872371] rdma.c:1324:nvmf_rdma_connect: *DEBUG*: Local NIC Max Send/Recv Queue Depth: 32768 Max Read/Write Queue Depth: 16
[2025-03-27 15:51:30.872374] rdma.c:1331:nvmf_rdma_connect: *DEBUG*: Host (Initiator) NIC Max Incoming RDMA R/W operations: 16 Max Outgoing RDMA R/W operations: 0
[2025-03-27 15:51:30.872378] rdma.c:1360:nvmf_rdma_connect: *DEBUG*: Host Receive Queue Size: 128
[2025-03-27 15:51:30.872381] rdma.c:1361:nvmf_rdma_connect: *DEBUG*: Host Send Queue Size: 127
[2025-03-27 15:51:30.872384] rdma.c:1365:nvmf_rdma_connect: *DEBUG*: Final Negotiated Queue Depth: 128 R/W Depth: 16
[2025-03-27 15:51:30.873070] rdma.c:1026:nvmf_rdma_qpair_initialize: *DEBUG*: New RDMA Connection: 0x55acf76dc710
[2025-03-27 15:51:30.873613] rdma.c:1256:nvmf_rdma_event_accept: *DEBUG*: Sent back the accept
[2025-03-27 15:51:30.882338] rdma.c:3696:nvmf_process_cm_events: *DEBUG*: Acceptor Event: RDMA_CM_EVENT_ESTABLISHED
[2025-03-27 15:51:30.972344] rdma.c:3696:nvmf_process_cm_events: *DEBUG*: Acceptor Event: RDMA_CM_EVENT_CONNECT_REQUEST
[2025-03-27 15:51:30.972354] rdma.c:1304:nvmf_rdma_connect: *DEBUG*: Connect Recv on fabric intf name mlx5_0, dev_name uverbs0
[2025-03-27 15:51:30.972358] rdma.c:1308:nvmf_rdma_connect: *DEBUG*: Listen Id was 0x55acf72dc370 with verbs 0x55acf7183e20. ListenAddr: 0x55acf728f990
[2025-03-27 15:51:30.972361] rdma.c:1315:nvmf_rdma_connect: *DEBUG*: Calculating Queue Depth
[2025-03-27 15:51:30.972365] rdma.c:1320:nvmf_rdma_connect: *DEBUG*: Target Max Queue Depth: 128
[2025-03-27 15:51:30.972368] rdma.c:1324:nvmf_rdma_connect: *DEBUG*: Local NIC Max Send/Recv Queue Depth: 32768 Max Read/Write Queue Depth: 16
[2025-03-27 15:51:30.972371] rdma.c:1331:nvmf_rdma_connect: *DEBUG*: Host (Initiator) NIC Max Incoming RDMA R/W operations: 16 Max Outgoing RDMA R/W operations: 0
[2025-03-27 15:51:30.972375] rdma.c:1360:nvmf_rdma_connect: *DEBUG*: Host Receive Queue Size: 128
[2025-03-27 15:51:30.972378] rdma.c:1361:nvmf_rdma_connect: *DEBUG*: Host Send Queue Size: 127
[2025-03-27 15:51:30.972381] rdma.c:1365:nvmf_rdma_connect: *DEBUG*: Final Negotiated Queue Depth: 128 R/W Depth: 16
[2025-03-27 15:51:30.973117] rdma.c:1026:nvmf_rdma_qpair_initialize: *DEBUG*: New RDMA Connection: 0x55acf77a9040
[2025-03-27 15:51:30.973620] rdma.c:1256:nvmf_rdma_event_accept: *DEBUG*: Sent back the accept
[2025-03-27 15:51:30.982340] rdma.c:3696:nvmf_process_cm_events: *DEBUG*: Acceptor Event: RDMA_CM_EVENT_ESTABLISHED
[2025-03-27 15:51:31.072346] rdma.c:3696:nvmf_process_cm_events: *DEBUG*: Acceptor Event: RDMA_CM_EVENT_CONNECT_REQUEST
[2025-03-27 15:51:31.072357] rdma.c:1304:nvmf_rdma_connect: *DEBUG*: Connect Recv on fabric intf name mlx5_0, dev_name uverbs0
[2025-03-27 15:51:31.072361] rdma.c:1308:nvmf_rdma_connect: *DEBUG*: Listen Id was 0x55acf72dc370 with verbs 0x55acf7183e20. ListenAddr: 0x55acf728f990
[2025-03-27 15:51:31.072364] rdma.c:1315:nvmf_rdma_connect: *DEBUG*: Calculating Queue Depth
[2025-03-27 15:51:31.072367] rdma.c:1320:nvmf_rdma_connect: *DEBUG*: Target Max Queue Depth: 128
[2025-03-27 15:51:31.072371] rdma.c:1324:nvmf_rdma_connect: *DEBUG*: Local NIC Max Send/Recv Queue Depth: 32768 Max Read/Write Queue Depth: 16
[2025-03-27 15:51:31.072374] rdma.c:1331:nvmf_rdma_connect: *DEBUG*: Host (Initiator) NIC Max Incoming RDMA R/W operations: 16 Max Outgoing RDMA R/W operations: 0
[2025-03-27 15:51:31.072378] rdma.c:1360:nvmf_rdma_connect: *DEBUG*: Host Receive Queue Size: 128
[2025-03-27 15:51:31.072381] rdma.c:1361:nvmf_rdma_connect: *DEBUG*: Host Send Queue Size: 127
[2025-03-27 15:51:31.072384] rdma.c:1365:nvmf_rdma_connect: *DEBUG*: Final Negotiated Queue Depth: 128 R/W Depth: 16
[2025-03-27 15:51:31.073079] rdma.c:1026:nvmf_rdma_qpair_initialize: *DEBUG*: New RDMA Connection: 0x55acf77a9810
[2025-03-27 15:51:31.073592] rdma.c:1256:nvmf_rdma_event_accept: *DEBUG*: Sent back the accept
[2025-03-27 15:51:31.082342] rdma.c:3696:nvmf_process_cm_events: *DEBUG*: Acceptor Event: RDMA_CM_EVENT_ESTABLISHED
[2025-03-27 15:51:31.172347] rdma.c:3696:nvmf_process_cm_events: *DEBUG*: Acceptor Event: RDMA_CM_EVENT_CONNECT_REQUEST
[2025-03-27 15:51:31.172357] rdma.c:1304:nvmf_rdma_connect: *DEBUG*: Connect Recv on fabric intf name mlx5_0, dev_name uverbs0
[2025-03-27 15:51:31.172361] rdma.c:1308:nvmf_rdma_connect: *DEBUG*: Listen Id was 0x55acf72dc370 with verbs 0x55acf7183e20. ListenAddr: 0x55acf728f990
[2025-03-27 15:51:31.172364] rdma.c:1315:nvmf_rdma_connect: *DEBUG*: Calculating Queue Depth
[2025-03-27 15:51:31.172367] rdma.c:1320:nvmf_rdma_connect: *DEBUG*: Target Max Queue Depth: 128
[2025-03-27 15:51:31.172371] rdma.c:1324:nvmf_rdma_connect: *DEBUG*: Local NIC Max Send/Recv Queue Depth: 32768 Max Read/Write Queue Depth: 16
[2025-03-27 15:51:31.172374] rdma.c:1331:nvmf_rdma_connect: *DEBUG*: Host (Initiator) NIC Max Incoming RDMA R/W operations: 16 Max Outgoing RDMA R/W operations: 0
[2025-03-27 15:51:31.172378] rdma.c:1360:nvmf_rdma_connect: *DEBUG*: Host Receive Queue Size: 128
[2025-03-27 15:51:31.172381] rdma.c:1361:nvmf_rdma_connect: *DEBUG*: Host Send Queue Size: 127
[2025-03-27 15:51:31.172384] rdma.c:1365:nvmf_rdma_connect: *DEBUG*: Final Negotiated Queue Depth: 128 R/W Depth: 16
[2025-03-27 15:51:31.173093] rdma.c:1026:nvmf_rdma_qpair_initialize: *DEBUG*: New RDMA Connection: 0x55acf791a040
[2025-03-27 15:51:31.173636] rdma.c:1256:nvmf_rdma_event_accept: *DEBUG*: Sent back the accept
[2025-03-27 15:51:31.182344] rdma.c:3696:nvmf_process_cm_events: *DEBUG*: Acceptor Event: RDMA_CM_EVENT_ESTABLISHED
[2025-03-27 15:51:31.272349] rdma.c:3696:nvmf_process_cm_events: *DEBUG*: Acceptor Event: RDMA_CM_EVENT_CONNECT_REQUEST
[2025-03-27 15:51:31.272358] rdma.c:1304:nvmf_rdma_connect: *DEBUG*: Connect Recv on fabric intf name mlx5_0, dev_name uverbs0
[2025-03-27 15:51:31.272362] rdma.c:1308:nvmf_rdma_connect: *DEBUG*: Listen Id was 0x55acf72dc370 with verbs 0x55acf7183e20. ListenAddr: 0x55acf728f990
[2025-03-27 15:51:31.272365] rdma.c:1315:nvmf_rdma_connect: *DEBUG*: Calculating Queue Depth
[2025-03-27 15:51:31.272369] rdma.c:1320:nvmf_rdma_connect: *DEBUG*: Target Max Queue Depth: 128
[2025-03-27 15:51:31.272372] rdma.c:1324:nvmf_rdma_connect: *DEBUG*: Local NIC Max Send/Recv Queue Depth: 32768 Max Read/Write Queue Depth: 16
[2025-03-27 15:51:31.272375] rdma.c:1331:nvmf_rdma_connect: *DEBUG*: Host (Initiator) NIC Max Incoming RDMA R/W operations: 16 Max Outgoing RDMA R/W operations: 0
[2025-03-27 15:51:31.272379] rdma.c:1360:nvmf_rdma_connect: *DEBUG*: Host Receive Queue Size: 128
[2025-03-27 15:51:31.272382] rdma.c:1361:nvmf_rdma_connect: *DEBUG*: Host Send Queue Size: 127
[2025-03-27 15:51:31.272385] rdma.c:1365:nvmf_rdma_connect: *DEBUG*: Final Negotiated Queue Depth: 128 R/W Depth: 16
[2025-03-27 15:51:31.273075] rdma.c:1026:nvmf_rdma_qpair_initialize: *DEBUG*: New RDMA Connection: 0x55acf791a860
[2025-03-27 15:51:31.273647] rdma.c:1256:nvmf_rdma_event_accept: *DEBUG*: Sent back the accept
[2025-03-27 15:51:31.282346] rdma.c:3696:nvmf_process_cm_events: *DEBUG*: Acceptor Event: RDMA_CM_EVENT_ESTABLISHED
[2025-03-27 15:51:31.372352] rdma.c:3696:nvmf_process_cm_events: *DEBUG*: Acceptor Event: RDMA_CM_EVENT_CONNECT_REQUEST
[2025-03-27 15:51:31.372362] rdma.c:1304:nvmf_rdma_connect: *DEBUG*: Connect Recv on fabric intf name mlx5_0, dev_name uverbs0
[2025-03-27 15:51:31.372367] rdma.c:1308:nvmf_rdma_connect: *DEBUG*: Listen Id was 0x55acf72dc370 with verbs 0x55acf7183e20. ListenAddr: 0x55acf728f990
[2025-03-27 15:51:31.372370] rdma.c:1315:nvmf_rdma_connect: *DEBUG*: Calculating Queue Depth
[2025-03-27 15:51:31.372373] rdma.c:1320:nvmf_rdma_connect: *DEBUG*: Target Max Queue Depth: 128
[2025-03-27 15:51:31.372377] rdma.c:1324:nvmf_rdma_connect: *DEBUG*: Local NIC Max Send/Recv Queue Depth: 32768 Max Read/Write Queue Depth: 16
[2025-03-27 15:51:31.372380] rdma.c:1331:nvmf_rdma_connect: *DEBUG*: Host (Initiator) NIC Max Incoming RDMA R/W operations: 16 Max Outgoing RDMA R/W operations: 0
[2025-03-27 15:51:31.372383] rdma.c:1360:nvmf_rdma_connect: *DEBUG*: Host Receive Queue Size: 128
[2025-03-27 15:51:31.372387] rdma.c:1361:nvmf_rdma_connect: *DEBUG*: Host Send Queue Size: 127
[2025-03-27 15:51:31.372390] rdma.c:1365:nvmf_rdma_connect: *DEBUG*: Final Negotiated Queue Depth: 128 R/W Depth: 16
[2025-03-27 15:51:31.373194] rdma.c:1026:nvmf_rdma_qpair_initialize: *DEBUG*: New RDMA Connection: 0x55acf78f12f0
[2025-03-27 15:51:31.373681] rdma.c:1256:nvmf_rdma_event_accept: *DEBUG*: Sent back the accept
[2025-03-27 15:51:31.382347] rdma.c:3696:nvmf_process_cm_events: *DEBUG*: Acceptor Event: RDMA_CM_EVENT_ESTABLISHED
[2025-03-27 15:51:31.472352] rdma.c:3696:nvmf_process_cm_events: *DEBUG*: Acceptor Event: RDMA_CM_EVENT_CONNECT_REQUEST
[2025-03-27 15:51:31.472362] rdma.c:1304:nvmf_rdma_connect: *DEBUG*: Connect Recv on fabric intf name mlx5_0, dev_name uverbs0
[2025-03-27 15:51:31.472366] rdma.c:1308:nvmf_rdma_connect: *DEBUG*: Listen Id was 0x55acf72dc370 with verbs 0x55acf7183e20. ListenAddr: 0x55acf728f990
[2025-03-27 15:51:31.472369] rdma.c:1315:nvmf_rdma_connect: *DEBUG*: Calculating Queue Depth
[2025-03-27 15:51:31.472373] rdma.c:1320:nvmf_rdma_connect: *DEBUG*: Target Max Queue Depth: 128
[2025-03-27 15:51:31.472376] rdma.c:1324:nvmf_rdma_connect: *DEBUG*: Local NIC Max Send/Recv Queue Depth: 32768 Max Read/Write Queue Depth: 16
[2025-03-27 15:51:31.472380] rdma.c:1331:nvmf_rdma_connect: *DEBUG*: Host (Initiator) NIC Max Incoming RDMA R/W operations: 16 Max Outgoing RDMA R/W operations: 0
[2025-03-27 15:51:31.472383] rdma.c:1360:nvmf_rdma_connect: *DEBUG*: Host Receive Queue Size: 128
[2025-03-27 15:51:31.472386] rdma.c:1361:nvmf_rdma_connect: *DEBUG*: Host Send Queue Size: 127
[2025-03-27 15:51:31.472389] rdma.c:1365:nvmf_rdma_connect: *DEBUG*: Final Negotiated Queue Depth: 128 R/W Depth: 16
[2025-03-27 15:51:31.473064] rdma.c:1026:nvmf_rdma_qpair_initialize: *DEBUG*: New RDMA Connection: 0x55acf78f1ac0
[2025-03-27 15:51:31.473570] rdma.c:1256:nvmf_rdma_event_accept: *DEBUG*: Sent back the accept
[2025-03-27 15:51:31.482349] rdma.c:3696:nvmf_process_cm_events: *DEBUG*: Acceptor Event: RDMA_CM_EVENT_ESTABLISHED
[2025-03-27 15:51:31.572355] rdma.c:3696:nvmf_process_cm_events: *DEBUG*: Acceptor Event: RDMA_CM_EVENT_CONNECT_REQUEST
[2025-03-27 15:51:31.572365] rdma.c:1304:nvmf_rdma_connect: *DEBUG*: Connect Recv on fabric intf name mlx5_0, dev_name uverbs0
[2025-03-27 15:51:31.572369] rdma.c:1308:nvmf_rdma_connect: *DEBUG*: Listen Id was 0x55acf72dc370 with verbs 0x55acf7183e20. ListenAddr: 0x55acf728f990
[2025-03-27 15:51:31.572373] rdma.c:1315:nvmf_rdma_connect: *DEBUG*: Calculating Queue Depth
[2025-03-27 15:51:31.572376] rdma.c:1320:nvmf_rdma_connect: *DEBUG*: Target Max Queue Depth: 128
[2025-03-27 15:51:31.572379] rdma.c:1324:nvmf_rdma_connect: *DEBUG*: Local NIC Max Send/Recv Queue Depth: 32768 Max Read/Write Queue Depth: 16
[2025-03-27 15:51:31.572383] rdma.c:1331:nvmf_rdma_connect: *DEBUG*: Host (Initiator) NIC Max Incoming RDMA R/W operations: 16 Max Outgoing RDMA R/W operations: 0
[2025-03-27 15:51:31.572386] rdma.c:1360:nvmf_rdma_connect: *DEBUG*: Host Receive Queue Size: 128
[2025-03-27 15:51:31.572390] rdma.c:1361:nvmf_rdma_connect: *DEBUG*: Host Send Queue Size: 127
[2025-03-27 15:51:31.572393] rdma.c:1365:nvmf_rdma_connect: *DEBUG*: Final Negotiated Queue Depth: 128 R/W Depth: 16
[2025-03-27 15:51:31.573109] rdma.c:1026:nvmf_rdma_qpair_initialize: *DEBUG*: New RDMA Connection: 0x55acf77802f0
[2025-03-27 15:51:31.573595] rdma.c:1256:nvmf_rdma_event_accept: *DEBUG*: Sent back the accept
[2025-03-27 15:51:31.582351] rdma.c:3696:nvmf_process_cm_events: *DEBUG*: Acceptor Event: RDMA_CM_EVENT_ESTABLISHED
[2025-03-27 15:51:31.672357] rdma.c:3696:nvmf_process_cm_events: *DEBUG*: Acceptor Event: RDMA_CM_EVENT_CONNECT_REQUEST
[2025-03-27 15:51:31.672367] rdma.c:1304:nvmf_rdma_connect: *DEBUG*: Connect Recv on fabric intf name mlx5_0, dev_name uverbs0
[2025-03-27 15:51:31.672371] rdma.c:1308:nvmf_rdma_connect: *DEBUG*: Listen Id was 0x55acf72dc370 with verbs 0x55acf7183e20. ListenAddr: 0x55acf728f990
[2025-03-27 15:51:31.672374] rdma.c:1315:nvmf_rdma_connect: *DEBUG*: Calculating Queue Depth
[2025-03-27 15:51:31.672378] rdma.c:1320:nvmf_rdma_connect: *DEBUG*: Target Max Queue Depth: 128
[2025-03-27 15:51:31.672381] rdma.c:1324:nvmf_rdma_connect: *DEBUG*: Local NIC Max Send/Recv Queue Depth: 32768 Max Read/Write Queue Depth: 16
[2025-03-27 15:51:31.672385] rdma.c:1331:nvmf_rdma_connect: *DEBUG*: Host (Initiator) NIC Max Incoming RDMA R/W operations: 16 Max Outgoing RDMA R/W operations: 0
[2025-03-27 15:51:31.672388] rdma.c:1360:nvmf_rdma_connect: *DEBUG*: Host Receive Queue Size: 128
[2025-03-27 15:51:31.672391] rdma.c:1361:nvmf_rdma_connect: *DEBUG*: Host Send Queue Size: 127
[2025-03-27 15:51:31.672394] rdma.c:1365:nvmf_rdma_connect: *DEBUG*: Final Negotiated Queue Depth: 128 R/W Depth: 16
[2025-03-27 15:51:31.673068] rdma.c:1026:nvmf_rdma_qpair_initialize: *DEBUG*: New RDMA Connection: 0x55acf7780ac0
[2025-03-27 15:51:31.673589] rdma.c:1256:nvmf_rdma_event_accept: *DEBUG*: Sent back the accept
[2025-03-27 15:51:31.676509] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 1
[2025-03-27 15:51:31.676517] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 2
[2025-03-27 15:51:31.676521] rdma.c:1902:nvmf_rdma_request_parse_sgl: *DEBUG*: In-capsule data: offset 0x0, length 0x400
[2025-03-27 15:51:31.676525] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 5
[2025-03-27 15:51:31.676532] nvme_qpair.c: 218:nvme_admin_qpair_print_command: *NOTICE*: FABRIC CONNECT qid:1 cid:0 SGL DATA BLOCK OFFSET 0x0 len:0x400
[2025-03-27 15:51:31.676554] ctrlr.c: 855:_nvmf_ctrlr_connect: *DEBUG*: recfmt 0x0 qid 1 sqsize 127
[2025-03-27 15:51:31.676585] ctrlr.c: 858:_nvmf_ctrlr_connect: *DEBUG*: Connect data:
[2025-03-27 15:51:31.676590] ctrlr.c: 859:_nvmf_ctrlr_connect: *DEBUG*:   cntlid:  0x0001
[2025-03-27 15:51:31.676594] ctrlr.c: 860:_nvmf_ctrlr_connect: *DEBUG*:   hostid: c3ab7015-781c-4b07-af33-0cd1204f4499 ***
[2025-03-27 15:51:31.676599] ctrlr.c: 868:_nvmf_ctrlr_connect: *DEBUG*:   subnqn: "nqn.2022-06.io.spdk:cnode216"
[2025-03-27 15:51:31.676603] ctrlr.c: 869:_nvmf_ctrlr_connect: *DEBUG*:   hostnqn: "nqn.2014-08.org.nvmexpress:uuid:e553e370-9f7d-4802-8abf-745e75b2845c"
[2025-03-27 15:51:31.676609] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 6
[2025-03-27 15:51:31.676615] ctrlr.c: 756:_nvmf_ctrlr_add_io_qpair: *DEBUG*: Connect I/O Queue for controller id 0x1
[2025-03-27 15:51:31.676623] ctrlr.c: 320:nvmf_ctrlr_add_qpair: *DEBUG*: qpair_mask set, qid 1
[2025-03-27 15:51:31.676630] ctrlr.c: 266:nvmf_ctrlr_send_connect_rsp: *DEBUG*: connect capsule response: cntlid = 0x0001
[2025-03-27 15:51:31.676637] nvme_qpair.c: 474:spdk_nvme_print_completion: *NOTICE*: SUCCESS (00/00) qid:1 cid:0 cdw0:1 sqhd:0000 p:0 m:0 dnr:0
[2025-03-27 15:51:31.676649] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 7
[2025-03-27 15:51:31.676654] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 9
[2025-03-27 15:51:31.676659] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 10
[2025-03-27 15:51:31.676664] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 12
[2025-03-27 15:51:31.676689] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 13
[2025-03-27 15:51:31.676694] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 0
[2025-03-27 15:51:31.676788] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 1
[2025-03-27 15:51:31.676794] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 2
[2025-03-27 15:51:31.676800] rdma.c:1902:nvmf_rdma_request_parse_sgl: *DEBUG*: In-capsule data: offset 0x0, length 0x400
[2025-03-27 15:51:31.676805] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 5
[2025-03-27 15:51:31.676813] nvme_qpair.c: 218:nvme_admin_qpair_print_command: *NOTICE*: FABRIC CONNECT qid:2 cid:0 SGL DATA BLOCK OFFSET 0x0 len:0x400
[2025-03-27 15:51:31.676825] ctrlr.c: 855:_nvmf_ctrlr_connect: *DEBUG*: recfmt 0x0 qid 2 sqsize 127
[2025-03-27 15:51:31.676831] ctrlr.c: 858:_nvmf_ctrlr_connect: *DEBUG*: Connect data:
[2025-03-27 15:51:31.676835] ctrlr.c: 859:_nvmf_ctrlr_connect: *DEBUG*:   cntlid:  0x0001
[2025-03-27 15:51:31.676841] ctrlr.c: 860:_nvmf_ctrlr_connect: *DEBUG*:   hostid: c3ab7015-781c-4b07-af33-0cd1204f4499 ***
[2025-03-27 15:51:31.676846] ctrlr.c: 868:_nvmf_ctrlr_connect: *DEBUG*:   subnqn: "nqn.2022-06.io.spdk:cnode216"
[2025-03-27 15:51:31.676850] ctrlr.c: 869:_nvmf_ctrlr_connect: *DEBUG*:   hostnqn: "nqn.2014-08.org.nvmexpress:uuid:e553e370-9f7d-4802-8abf-745e75b2845c"
[2025-03-27 15:51:31.676868] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 6
[2025-03-27 15:51:31.676874] ctrlr.c: 756:_nvmf_ctrlr_add_io_qpair: *DEBUG*: Connect I/O Queue for controller id 0x1
[2025-03-27 15:51:31.676881] ctrlr.c: 320:nvmf_ctrlr_add_qpair: *DEBUG*: qpair_mask set, qid 2
[2025-03-27 15:51:31.676887] ctrlr.c: 266:nvmf_ctrlr_send_connect_rsp: *DEBUG*: connect capsule response: cntlid = 0x0001
[2025-03-27 15:51:31.676894] nvme_qpair.c: 474:spdk_nvme_print_completion: *NOTICE*: SUCCESS (00/00) qid:2 cid:0 cdw0:1 sqhd:0000 p:0 m:0 dnr:0
[2025-03-27 15:51:31.676904] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 7
[2025-03-27 15:51:31.676909] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 9
[2025-03-27 15:51:31.676914] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 10
[2025-03-27 15:51:31.676919] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 12
[2025-03-27 15:51:31.676932] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 13
[2025-03-27 15:51:31.676938] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 0
[2025-03-27 15:51:31.677018] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 1
[2025-03-27 15:51:31.677023] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 2
[2025-03-27 15:51:31.677028] rdma.c:1902:nvmf_rdma_request_parse_sgl: *DEBUG*: In-capsule data: offset 0x0, length 0x400
[2025-03-27 15:51:31.677033] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 5
[2025-03-27 15:51:31.677040] nvme_qpair.c: 218:nvme_admin_qpair_print_command: *NOTICE*: FABRIC CONNECT qid:3 cid:0 SGL DATA BLOCK OFFSET 0x0 len:0x400
[2025-03-27 15:51:31.677052] ctrlr.c: 855:_nvmf_ctrlr_connect: *DEBUG*: recfmt 0x0 qid 3 sqsize 127
[2025-03-27 15:51:31.677058] ctrlr.c: 858:_nvmf_ctrlr_connect: *DEBUG*: Connect data:
[2025-03-27 15:51:31.677062] ctrlr.c: 859:_nvmf_ctrlr_connect: *DEBUG*:   cntlid:  0x0001
[2025-03-27 15:51:31.677067] ctrlr.c: 860:_nvmf_ctrlr_connect: *DEBUG*:   hostid: c3ab7015-781c-4b07-af33-0cd1204f4499 ***
[2025-03-27 15:51:31.677072] ctrlr.c: 868:_nvmf_ctrlr_connect: *DEBUG*:   subnqn: "nqn.2022-06.io.spdk:cnode216"
[2025-03-27 15:51:31.677077] ctrlr.c: 869:_nvmf_ctrlr_connect: *DEBUG*:   hostnqn: "nqn.2014-08.org.nvmexpress:uuid:e553e370-9f7d-4802-8abf-745e75b2845c"
[2025-03-27 15:51:31.677083] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 6
[2025-03-27 15:51:31.677089] ctrlr.c: 756:_nvmf_ctrlr_add_io_qpair: *DEBUG*: Connect I/O Queue for controller id 0x1
[2025-03-27 15:51:31.677096] ctrlr.c: 320:nvmf_ctrlr_add_qpair: *DEBUG*: qpair_mask set, qid 3
[2025-03-27 15:51:31.677102] ctrlr.c: 266:nvmf_ctrlr_send_connect_rsp: *DEBUG*: connect capsule response: cntlid = 0x0001
[2025-03-27 15:51:31.677108] nvme_qpair.c: 474:spdk_nvme_print_completion: *NOTICE*: SUCCESS (00/00) qid:3 cid:0 cdw0:1 sqhd:0000 p:0 m:0 dnr:0
[2025-03-27 15:51:31.677118] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 7
[2025-03-27 15:51:31.677123] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 9
[2025-03-27 15:51:31.677129] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 10
[2025-03-27 15:51:31.677134] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 12
[2025-03-27 15:51:31.677146] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 13
[2025-03-27 15:51:31.677151] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 0
[2025-03-27 15:51:31.677190] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 1
[2025-03-27 15:51:31.677195] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 2
[2025-03-27 15:51:31.677209] rdma.c:1902:nvmf_rdma_request_parse_sgl: *DEBUG*: In-capsule data: offset 0x0, length 0x400
[2025-03-27 15:51:31.677215] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 5
[2025-03-27 15:51:31.677223] nvme_qpair.c: 218:nvme_admin_qpair_print_command: *NOTICE*: FABRIC CONNECT qid:4 cid:0 SGL DATA BLOCK OFFSET 0x0 len:0x400
[2025-03-27 15:51:31.677236] ctrlr.c: 855:_nvmf_ctrlr_connect: *DEBUG*: recfmt 0x0 qid 4 sqsize 127
[2025-03-27 15:51:31.677242] ctrlr.c: 858:_nvmf_ctrlr_connect: *DEBUG*: Connect data:
[2025-03-27 15:51:31.677247] ctrlr.c: 859:_nvmf_ctrlr_connect: *DEBUG*:   cntlid:  0x0001
[2025-03-27 15:51:31.677252] ctrlr.c: 860:_nvmf_ctrlr_connect: *DEBUG*:   hostid: c3ab7015-781c-4b07-af33-0cd1204f4499 ***
[2025-03-27 15:51:31.677257] ctrlr.c: 868:_nvmf_ctrlr_connect: *DEBUG*:   subnqn: "nqn.2022-06.io.spdk:cnode216"
[2025-03-27 15:51:31.677262] ctrlr.c: 869:_nvmf_ctrlr_connect: *DEBUG*:   hostnqn: "nqn.2014-08.org.nvmexpress:uuid:e553e370-9f7d-4802-8abf-745e75b2845c"
[2025-03-27 15:51:31.677268] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 6
[2025-03-27 15:51:31.677275] ctrlr.c: 756:_nvmf_ctrlr_add_io_qpair: *DEBUG*: Connect I/O Queue for controller id 0x1
[2025-03-27 15:51:31.677282] ctrlr.c: 320:nvmf_ctrlr_add_qpair: *DEBUG*: qpair_mask set, qid 4
[2025-03-27 15:51:31.677300] ctrlr.c: 266:nvmf_ctrlr_send_connect_rsp: *DEBUG*: connect capsule response: cntlid = 0x0001
[2025-03-27 15:51:31.677307] nvme_qpair.c: 474:spdk_nvme_print_completion: *NOTICE*: SUCCESS (00/00) qid:4 cid:0 cdw0:1 sqhd:0000 p:0 m:0 dnr:0
[2025-03-27 15:51:31.677318] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 7
[2025-03-27 15:51:31.677324] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 9
[2025-03-27 15:51:31.677340] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 10
[2025-03-27 15:51:31.677346] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 12
[2025-03-27 15:51:31.677360] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 13
[2025-03-27 15:51:31.677365] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 0
[2025-03-27 15:51:31.677448] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 1
[2025-03-27 15:51:31.677453] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 2
[2025-03-27 15:51:31.677459] rdma.c:1902:nvmf_rdma_request_parse_sgl: *DEBUG*: In-capsule data: offset 0x0, length 0x400
[2025-03-27 15:51:31.677464] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 5
[2025-03-27 15:51:31.677472] nvme_qpair.c: 218:nvme_admin_qpair_print_command: *NOTICE*: FABRIC CONNECT qid:5 cid:0 SGL DATA BLOCK OFFSET 0x0 len:0x400
[2025-03-27 15:51:31.677485] ctrlr.c: 855:_nvmf_ctrlr_connect: *DEBUG*: recfmt 0x0 qid 5 sqsize 127
[2025-03-27 15:51:31.677491] ctrlr.c: 858:_nvmf_ctrlr_connect: *DEBUG*: Connect data:
[2025-03-27 15:51:31.677496] ctrlr.c: 859:_nvmf_ctrlr_connect: *DEBUG*:   cntlid:  0x0001
[2025-03-27 15:51:31.677502] ctrlr.c: 860:_nvmf_ctrlr_connect: *DEBUG*:   hostid: c3ab7015-781c-4b07-af33-0cd1204f4499 ***
[2025-03-27 15:51:31.677507] ctrlr.c: 868:_nvmf_ctrlr_connect: *DEBUG*:   subnqn: "nqn.2022-06.io.spdk:cnode216"
[2025-03-27 15:51:31.677511] ctrlr.c: 869:_nvmf_ctrlr_connect: *DEBUG*:   hostnqn: "nqn.2014-08.org.nvmexpress:uuid:e553e370-9f7d-4802-8abf-745e75b2845c"
[2025-03-27 15:51:31.677518] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 6
[2025-03-27 15:51:31.677524] ctrlr.c: 756:_nvmf_ctrlr_add_io_qpair: *DEBUG*: Connect I/O Queue for controller id 0x1
[2025-03-27 15:51:31.677531] ctrlr.c: 320:nvmf_ctrlr_add_qpair: *DEBUG*: qpair_mask set, qid 5
[2025-03-27 15:51:31.677538] ctrlr.c: 266:nvmf_ctrlr_send_connect_rsp: *DEBUG*: connect capsule response: cntlid = 0x0001
[2025-03-27 15:51:31.677545] nvme_qpair.c: 474:spdk_nvme_print_completion: *NOTICE*: SUCCESS (00/00) qid:5 cid:0 cdw0:1 sqhd:0000 p:0 m:0 dnr:0
[2025-03-27 15:51:31.677556] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 7
[2025-03-27 15:51:31.677562] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 9
[2025-03-27 15:51:31.677567] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 10
[2025-03-27 15:51:31.677573] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 12
[2025-03-27 15:51:31.677587] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 13
[2025-03-27 15:51:31.677593] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 0
[2025-03-27 15:51:31.677677] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 1
[2025-03-27 15:51:31.677683] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 2
[2025-03-27 15:51:31.677689] rdma.c:1902:nvmf_rdma_request_parse_sgl: *DEBUG*: In-capsule data: offset 0x0, length 0x400
[2025-03-27 15:51:31.677694] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 5
[2025-03-27 15:51:31.677702] nvme_qpair.c: 218:nvme_admin_qpair_print_command: *NOTICE*: FABRIC CONNECT qid:6 cid:0 SGL DATA BLOCK OFFSET 0x0 len:0x400
[2025-03-27 15:51:31.677715] ctrlr.c: 855:_nvmf_ctrlr_connect: *DEBUG*: recfmt 0x0 qid 6 sqsize 127
[2025-03-27 15:51:31.677720] ctrlr.c: 858:_nvmf_ctrlr_connect: *DEBUG*: Connect data:
[2025-03-27 15:51:31.677726] ctrlr.c: 859:_nvmf_ctrlr_connect: *DEBUG*:   cntlid:  0x0001
[2025-03-27 15:51:31.677731] ctrlr.c: 860:_nvmf_ctrlr_connect: *DEBUG*:   hostid: c3ab7015-781c-4b07-af33-0cd1204f4499 ***
[2025-03-27 15:51:31.677737] ctrlr.c: 868:_nvmf_ctrlr_connect: *DEBUG*:   subnqn: "nqn.2022-06.io.spdk:cnode216"
[2025-03-27 15:51:31.677742] ctrlr.c: 869:_nvmf_ctrlr_connect: *DEBUG*:   hostnqn: "nqn.2014-08.org.nvmexpress:uuid:e553e370-9f7d-4802-8abf-745e75b2845c"
[2025-03-27 15:51:31.677752] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 6
[2025-03-27 15:51:31.677758] ctrlr.c: 756:_nvmf_ctrlr_add_io_qpair: *DEBUG*: Connect I/O Queue for controller id 0x1
[2025-03-27 15:51:31.677765] ctrlr.c: 320:nvmf_ctrlr_add_qpair: *DEBUG*: qpair_mask set, qid 6
[2025-03-27 15:51:31.677772] ctrlr.c: 266:nvmf_ctrlr_send_connect_rsp: *DEBUG*: connect capsule response: cntlid = 0x0001
[2025-03-27 15:51:31.677778] nvme_qpair.c: 474:spdk_nvme_print_completion: *NOTICE*: SUCCESS (00/00) qid:6 cid:0 cdw0:1 sqhd:0000 p:0 m:0 dnr:0
[2025-03-27 15:51:31.677789] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 7
[2025-03-27 15:51:31.677795] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 9
[2025-03-27 15:51:31.677801] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 10
[2025-03-27 15:51:31.677806] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 12
[2025-03-27 15:51:31.677819] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 13
[2025-03-27 15:51:31.677825] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 0
[2025-03-27 15:51:31.677898] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 1
[2025-03-27 15:51:31.677905] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 2
[2025-03-27 15:51:31.677911] rdma.c:1902:nvmf_rdma_request_parse_sgl: *DEBUG*: In-capsule data: offset 0x0, length 0x400
[2025-03-27 15:51:31.677916] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 5
[2025-03-27 15:51:31.677924] nvme_qpair.c: 218:nvme_admin_qpair_print_command: *NOTICE*: FABRIC CONNECT qid:7 cid:0 SGL DATA BLOCK OFFSET 0x0 len:0x400
[2025-03-27 15:51:31.677937] ctrlr.c: 855:_nvmf_ctrlr_connect: *DEBUG*: recfmt 0x0 qid 7 sqsize 127
[2025-03-27 15:51:31.677944] ctrlr.c: 858:_nvmf_ctrlr_connect: *DEBUG*: Connect data:
[2025-03-27 15:51:31.677949] ctrlr.c: 859:_nvmf_ctrlr_connect: *DEBUG*:   cntlid:  0x0001
[2025-03-27 15:51:31.677954] ctrlr.c: 860:_nvmf_ctrlr_connect: *DEBUG*:   hostid: c3ab7015-781c-4b07-af33-0cd1204f4499 ***
[2025-03-27 15:51:31.677960] ctrlr.c: 868:_nvmf_ctrlr_connect: *DEBUG*:   subnqn: "nqn.2022-06.io.spdk:cnode216"
[2025-03-27 15:51:31.677965] ctrlr.c: 869:_nvmf_ctrlr_connect: *DEBUG*:   hostnqn: "nqn.2014-08.org.nvmexpress:uuid:e553e370-9f7d-4802-8abf-745e75b2845c"
[2025-03-27 15:51:31.677971] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 6
[2025-03-27 15:51:31.677978] ctrlr.c: 756:_nvmf_ctrlr_add_io_qpair: *DEBUG*: Connect I/O Queue for controller id 0x1
[2025-03-27 15:51:31.677985] ctrlr.c: 320:nvmf_ctrlr_add_qpair: *DEBUG*: qpair_mask set, qid 7
[2025-03-27 15:51:31.677992] ctrlr.c: 266:nvmf_ctrlr_send_connect_rsp: *DEBUG*: connect capsule response: cntlid = 0x0001
[2025-03-27 15:51:31.677999] nvme_qpair.c: 474:spdk_nvme_print_completion: *NOTICE*: SUCCESS (00/00) qid:7 cid:0 cdw0:1 sqhd:0000 p:0 m:0 dnr:0
[2025-03-27 15:51:31.678009] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 7
[2025-03-27 15:51:31.678015] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 9
[2025-03-27 15:51:31.678021] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 10
[2025-03-27 15:51:31.678027] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 12
[2025-03-27 15:51:31.678049] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 13
[2025-03-27 15:51:31.678055] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 0
[2025-03-27 15:51:31.678151] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 1
[2025-03-27 15:51:31.678157] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 2
[2025-03-27 15:51:31.678162] rdma.c:1902:nvmf_rdma_request_parse_sgl: *DEBUG*: In-capsule data: offset 0x0, length 0x400
[2025-03-27 15:51:31.678167] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 5
[2025-03-27 15:51:31.678174] nvme_qpair.c: 218:nvme_admin_qpair_print_command: *NOTICE*: FABRIC CONNECT qid:8 cid:0 SGL DATA BLOCK OFFSET 0x0 len:0x400
[2025-03-27 15:51:31.678187] ctrlr.c: 855:_nvmf_ctrlr_connect: *DEBUG*: recfmt 0x0 qid 8 sqsize 127
[2025-03-27 15:51:31.678193] ctrlr.c: 858:_nvmf_ctrlr_connect: *DEBUG*: Connect data:
[2025-03-27 15:51:31.678198] ctrlr.c: 859:_nvmf_ctrlr_connect: *DEBUG*:   cntlid:  0x0001
[2025-03-27 15:51:31.678203] ctrlr.c: 860:_nvmf_ctrlr_connect: *DEBUG*:   hostid: c3ab7015-781c-4b07-af33-0cd1204f4499 ***
[2025-03-27 15:51:31.678220] ctrlr.c: 868:_nvmf_ctrlr_connect: *DEBUG*:   subnqn: "nqn.2022-06.io.spdk:cnode216"
[2025-03-27 15:51:31.678226] ctrlr.c: 869:_nvmf_ctrlr_connect: *DEBUG*:   hostnqn: "nqn.2014-08.org.nvmexpress:uuid:e553e370-9f7d-4802-8abf-745e75b2845c"
[2025-03-27 15:51:31.678232] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 6
[2025-03-27 15:51:31.678238] ctrlr.c: 756:_nvmf_ctrlr_add_io_qpair: *DEBUG*: Connect I/O Queue for controller id 0x1
[2025-03-27 15:51:31.678246] ctrlr.c: 320:nvmf_ctrlr_add_qpair: *DEBUG*: qpair_mask set, qid 8
[2025-03-27 15:51:31.678252] ctrlr.c: 266:nvmf_ctrlr_send_connect_rsp: *DEBUG*: connect capsule response: cntlid = 0x0001
[2025-03-27 15:51:31.678259] nvme_qpair.c: 474:spdk_nvme_print_completion: *NOTICE*: SUCCESS (00/00) qid:8 cid:0 cdw0:1 sqhd:0000 p:0 m:0 dnr:0
[2025-03-27 15:51:31.678269] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 7
[2025-03-27 15:51:31.678275] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 9
[2025-03-27 15:51:31.678280] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 10
[2025-03-27 15:51:31.678286] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 12
[2025-03-27 15:51:31.678298] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 13
[2025-03-27 15:51:31.678304] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 0
[2025-03-27 15:51:31.678382] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 1
[2025-03-27 15:51:31.678388] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 2
[2025-03-27 15:51:31.678393] rdma.c:1902:nvmf_rdma_request_parse_sgl: *DEBUG*: In-capsule data: offset 0x0, length 0x400
[2025-03-27 15:51:31.678399] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 5
[2025-03-27 15:51:31.678406] nvme_qpair.c: 218:nvme_admin_qpair_print_command: *NOTICE*: FABRIC CONNECT qid:9 cid:0 SGL DATA BLOCK OFFSET 0x0 len:0x400
[2025-03-27 15:51:31.678419] ctrlr.c: 855:_nvmf_ctrlr_connect: *DEBUG*: recfmt 0x0 qid 9 sqsize 127
[2025-03-27 15:51:31.678425] ctrlr.c: 858:_nvmf_ctrlr_connect: *DEBUG*: Connect data:
[2025-03-27 15:51:31.678430] ctrlr.c: 859:_nvmf_ctrlr_connect: *DEBUG*:   cntlid:  0x0001
[2025-03-27 15:51:31.678436] ctrlr.c: 860:_nvmf_ctrlr_connect: *DEBUG*:   hostid: c3ab7015-781c-4b07-af33-0cd1204f4499 ***
[2025-03-27 15:51:31.678441] ctrlr.c: 868:_nvmf_ctrlr_connect: *DEBUG*:   subnqn: "nqn.2022-06.io.spdk:cnode216"
[2025-03-27 15:51:31.678446] ctrlr.c: 869:_nvmf_ctrlr_connect: *DEBUG*:   hostnqn: "nqn.2014-08.org.nvmexpress:uuid:e553e370-9f7d-4802-8abf-745e75b2845c"
[2025-03-27 15:51:31.678452] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 6
[2025-03-27 15:51:31.678458] ctrlr.c: 756:_nvmf_ctrlr_add_io_qpair: *DEBUG*: Connect I/O Queue for controller id 0x1
[2025-03-27 15:51:31.678466] ctrlr.c: 320:nvmf_ctrlr_add_qpair: *DEBUG*: qpair_mask set, qid 9
[2025-03-27 15:51:31.678472] ctrlr.c: 266:nvmf_ctrlr_send_connect_rsp: *DEBUG*: connect capsule response: cntlid = 0x0001
[2025-03-27 15:51:31.678479] nvme_qpair.c: 474:spdk_nvme_print_completion: *NOTICE*: SUCCESS (00/00) qid:9 cid:0 cdw0:1 sqhd:0000 p:0 m:0 dnr:0
[2025-03-27 15:51:31.678490] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 7
[2025-03-27 15:51:31.678495] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 9
[2025-03-27 15:51:31.678501] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 10
[2025-03-27 15:51:31.678506] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 12
[2025-03-27 15:51:31.678519] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 13
[2025-03-27 15:51:31.678525] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 0
[2025-03-27 15:51:31.678546] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 1
[2025-03-27 15:51:31.678551] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 2
[2025-03-27 15:51:31.678556] rdma.c:1902:nvmf_rdma_request_parse_sgl: *DEBUG*: In-capsule data: offset 0x0, length 0x400
[2025-03-27 15:51:31.678562] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 5
[2025-03-27 15:51:31.678579] nvme_qpair.c: 218:nvme_admin_qpair_print_command: *NOTICE*: FABRIC CONNECT qid:10 cid:0 SGL DATA BLOCK OFFSET 0x0 len:0x400
[2025-03-27 15:51:31.678591] ctrlr.c: 855:_nvmf_ctrlr_connect: *DEBUG*: recfmt 0x0 qid 10 sqsize 127
[2025-03-27 15:51:31.678596] ctrlr.c: 858:_nvmf_ctrlr_connect: *DEBUG*: Connect data:
[2025-03-27 15:51:31.678601] ctrlr.c: 859:_nvmf_ctrlr_connect: *DEBUG*:   cntlid:  0x0001
[2025-03-27 15:51:31.678605] ctrlr.c: 860:_nvmf_ctrlr_connect: *DEBUG*:   hostid: c3ab7015-781c-4b07-af33-0cd1204f4499 ***
[2025-03-27 15:51:31.678610] ctrlr.c: 868:_nvmf_ctrlr_connect: *DEBUG*:   subnqn: "nqn.2022-06.io.spdk:cnode216"
[2025-03-27 15:51:31.678614] ctrlr.c: 869:_nvmf_ctrlr_connect: *DEBUG*:   hostnqn: "nqn.2014-08.org.nvmexpress:uuid:e553e370-9f7d-4802-8abf-745e75b2845c"
[2025-03-27 15:51:31.678620] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 6
[2025-03-27 15:51:31.678626] ctrlr.c: 756:_nvmf_ctrlr_add_io_qpair: *DEBUG*: Connect I/O Queue for controller id 0x1
[2025-03-27 15:51:31.678632] ctrlr.c: 320:nvmf_ctrlr_add_qpair: *DEBUG*: qpair_mask set, qid 10
[2025-03-27 15:51:31.678638] ctrlr.c: 266:nvmf_ctrlr_send_connect_rsp: *DEBUG*: connect capsule response: cntlid = 0x0001
[2025-03-27 15:51:31.678644] nvme_qpair.c: 474:spdk_nvme_print_completion: *NOTICE*: SUCCESS (00/00) qid:10 cid:0 cdw0:1 sqhd:0000 p:0 m:0 dnr:0
[2025-03-27 15:51:31.678654] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 7
[2025-03-27 15:51:31.678660] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 9
[2025-03-27 15:51:31.678664] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 10
[2025-03-27 15:51:31.678680] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 12
[2025-03-27 15:51:31.678700] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 13
[2025-03-27 15:51:31.678705] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 0
[2025-03-27 15:51:31.678776] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 1
[2025-03-27 15:51:31.678781] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 2
[2025-03-27 15:51:31.678786] rdma.c:1902:nvmf_rdma_request_parse_sgl: *DEBUG*: In-capsule data: offset 0x0, length 0x400
[2025-03-27 15:51:31.678790] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 5
[2025-03-27 15:51:31.678797] nvme_qpair.c: 218:nvme_admin_qpair_print_command: *NOTICE*: FABRIC CONNECT qid:11 cid:0 SGL DATA BLOCK OFFSET 0x0 len:0x400
[2025-03-27 15:51:31.678809] ctrlr.c: 855:_nvmf_ctrlr_connect: *DEBUG*: recfmt 0x0 qid 11 sqsize 127
[2025-03-27 15:51:31.678825] ctrlr.c: 858:_nvmf_ctrlr_connect: *DEBUG*: Connect data:
[2025-03-27 15:51:31.678830] ctrlr.c: 859:_nvmf_ctrlr_connect: *DEBUG*:   cntlid:  0x0001
[2025-03-27 15:51:31.678836] ctrlr.c: 860:_nvmf_ctrlr_connect: *DEBUG*:   hostid: c3ab7015-781c-4b07-af33-0cd1204f4499 ***
[2025-03-27 15:51:31.678841] ctrlr.c: 868:_nvmf_ctrlr_connect: *DEBUG*:   subnqn: "nqn.2022-06.io.spdk:cnode216"
[2025-03-27 15:51:31.678846] ctrlr.c: 869:_nvmf_ctrlr_connect: *DEBUG*:   hostnqn: "nqn.2014-08.org.nvmexpress:uuid:e553e370-9f7d-4802-8abf-745e75b2845c"
[2025-03-27 15:51:31.678852] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 6
[2025-03-27 15:51:31.678858] ctrlr.c: 756:_nvmf_ctrlr_add_io_qpair: *DEBUG*: Connect I/O Queue for controller id 0x1
[2025-03-27 15:51:31.678865] ctrlr.c: 320:nvmf_ctrlr_add_qpair: *DEBUG*: qpair_mask set, qid 11
[2025-03-27 15:51:31.678871] ctrlr.c: 266:nvmf_ctrlr_send_connect_rsp: *DEBUG*: connect capsule response: cntlid = 0x0001
[2025-03-27 15:51:31.678878] nvme_qpair.c: 474:spdk_nvme_print_completion: *NOTICE*: SUCCESS (00/00) qid:11 cid:0 cdw0:1 sqhd:0000 p:0 m:0 dnr:0
[2025-03-27 15:51:31.678889] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 7
[2025-03-27 15:51:31.678894] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 9
[2025-03-27 15:51:31.678899] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 10
[2025-03-27 15:51:31.678916] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 12
[2025-03-27 15:51:31.678929] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 13
[2025-03-27 15:51:31.678935] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 0
[2025-03-27 15:51:31.678977] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 1
[2025-03-27 15:51:31.678983] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 2
[2025-03-27 15:51:31.678988] rdma.c:1902:nvmf_rdma_request_parse_sgl: *DEBUG*: In-capsule data: offset 0x0, length 0x400
[2025-03-27 15:51:31.678992] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 5
[2025-03-27 15:51:31.678999] nvme_qpair.c: 218:nvme_admin_qpair_print_command: *NOTICE*: FABRIC CONNECT qid:12 cid:0 SGL DATA BLOCK OFFSET 0x0 len:0x400
[2025-03-27 15:51:31.679012] ctrlr.c: 855:_nvmf_ctrlr_connect: *DEBUG*: recfmt 0x0 qid 12 sqsize 127
[2025-03-27 15:51:31.679018] ctrlr.c: 858:_nvmf_ctrlr_connect: *DEBUG*: Connect data:
[2025-03-27 15:51:31.679023] ctrlr.c: 859:_nvmf_ctrlr_connect: *DEBUG*:   cntlid:  0x0001
[2025-03-27 15:51:31.679028] ctrlr.c: 860:_nvmf_ctrlr_connect: *DEBUG*:   hostid: c3ab7015-781c-4b07-af33-0cd1204f4499 ***
[2025-03-27 15:51:31.679033] ctrlr.c: 868:_nvmf_ctrlr_connect: *DEBUG*:   subnqn: "nqn.2022-06.io.spdk:cnode216"
[2025-03-27 15:51:31.679061] ctrlr.c: 869:_nvmf_ctrlr_connect: *DEBUG*:   hostnqn: "nqn.2014-08.org.nvmexpress:uuid:e553e370-9f7d-4802-8abf-745e75b2845c"
[2025-03-27 15:51:31.679069] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 6
[2025-03-27 15:51:31.679076] ctrlr.c: 756:_nvmf_ctrlr_add_io_qpair: *DEBUG*: Connect I/O Queue for controller id 0x1
[2025-03-27 15:51:31.679084] ctrlr.c: 320:nvmf_ctrlr_add_qpair: *DEBUG*: qpair_mask set, qid 12
[2025-03-27 15:51:31.679090] ctrlr.c: 266:nvmf_ctrlr_send_connect_rsp: *DEBUG*: connect capsule response: cntlid = 0x0001
[2025-03-27 15:51:31.679097] nvme_qpair.c: 474:spdk_nvme_print_completion: *NOTICE*: SUCCESS (00/00) qid:12 cid:0 cdw0:1 sqhd:0000 p:0 m:0 dnr:0
[2025-03-27 15:51:31.679109] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 7
[2025-03-27 15:51:31.679115] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 9
[2025-03-27 15:51:31.679120] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 10
[2025-03-27 15:51:31.679126] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 12
[2025-03-27 15:51:31.679138] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 13
[2025-03-27 15:51:31.679144] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 0
[2025-03-27 15:51:31.679224] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 1
[2025-03-27 15:51:31.679229] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 2
[2025-03-27 15:51:31.679235] rdma.c:1902:nvmf_rdma_request_parse_sgl: *DEBUG*: In-capsule data: offset 0x0, length 0x400
[2025-03-27 15:51:31.679240] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 5
[2025-03-27 15:51:31.679247] nvme_qpair.c: 218:nvme_admin_qpair_print_command: *NOTICE*: FABRIC CONNECT qid:13 cid:0 SGL DATA BLOCK OFFSET 0x0 len:0x400
[2025-03-27 15:51:31.679260] ctrlr.c: 855:_nvmf_ctrlr_connect: *DEBUG*: recfmt 0x0 qid 13 sqsize 127
[2025-03-27 15:51:31.679266] ctrlr.c: 858:_nvmf_ctrlr_connect: *DEBUG*: Connect data:
[2025-03-27 15:51:31.679272] ctrlr.c: 859:_nvmf_ctrlr_connect: *DEBUG*:   cntlid:  0x0001
[2025-03-27 15:51:31.679277] ctrlr.c: 860:_nvmf_ctrlr_connect: *DEBUG*:   hostid: c3ab7015-781c-4b07-af33-0cd1204f4499 ***
[2025-03-27 15:51:31.679282] ctrlr.c: 868:_nvmf_ctrlr_connect: *DEBUG*:   subnqn: "nqn.2022-06.io.spdk:cnode216"
[2025-03-27 15:51:31.679288] ctrlr.c: 869:_nvmf_ctrlr_connect: *DEBUG*:   hostnqn: "nqn.2014-08.org.nvmexpress:uuid:e553e370-9f7d-4802-8abf-745e75b2845c"
[2025-03-27 15:51:31.679293] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 6
[2025-03-27 15:51:31.679300] ctrlr.c: 756:_nvmf_ctrlr_add_io_qpair: *DEBUG*: Connect I/O Queue for controller id 0x1
[2025-03-27 15:51:31.679307] ctrlr.c: 320:nvmf_ctrlr_add_qpair: *DEBUG*: qpair_mask set, qid 13
[2025-03-27 15:51:31.679313] ctrlr.c: 266:nvmf_ctrlr_send_connect_rsp: *DEBUG*: connect capsule response: cntlid = 0x0001
[2025-03-27 15:51:31.679320] nvme_qpair.c: 474:spdk_nvme_print_completion: *NOTICE*: SUCCESS (00/00) qid:13 cid:0 cdw0:1 sqhd:0000 p:0 m:0 dnr:0
[2025-03-27 15:51:31.679330] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 7
[2025-03-27 15:51:31.679336] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 9
[2025-03-27 15:51:31.679341] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 10
[2025-03-27 15:51:31.679347] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 12
[2025-03-27 15:51:31.679359] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 13
[2025-03-27 15:51:31.679365] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 0
[2025-03-27 15:51:31.679435] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 1
[2025-03-27 15:51:31.679441] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 2
[2025-03-27 15:51:31.679446] rdma.c:1902:nvmf_rdma_request_parse_sgl: *DEBUG*: In-capsule data: offset 0x0, length 0x400
[2025-03-27 15:51:31.679451] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 5
[2025-03-27 15:51:31.679458] nvme_qpair.c: 218:nvme_admin_qpair_print_command: *NOTICE*: FABRIC CONNECT qid:14 cid:0 SGL DATA BLOCK OFFSET 0x0 len:0x400
[2025-03-27 15:51:31.679472] ctrlr.c: 855:_nvmf_ctrlr_connect: *DEBUG*: recfmt 0x0 qid 14 sqsize 127
[2025-03-27 15:51:31.679478] ctrlr.c: 858:_nvmf_ctrlr_connect: *DEBUG*: Connect data:
[2025-03-27 15:51:31.679483] ctrlr.c: 859:_nvmf_ctrlr_connect: *DEBUG*:   cntlid:  0x0001
[2025-03-27 15:51:31.679488] ctrlr.c: 860:_nvmf_ctrlr_connect: *DEBUG*:   hostid: c3ab7015-781c-4b07-af33-0cd1204f4499 ***
[2025-03-27 15:51:31.679494] ctrlr.c: 868:_nvmf_ctrlr_connect: *DEBUG*:   subnqn: "nqn.2022-06.io.spdk:cnode216"
[2025-03-27 15:51:31.679499] ctrlr.c: 869:_nvmf_ctrlr_connect: *DEBUG*:   hostnqn: "nqn.2014-08.org.nvmexpress:uuid:e553e370-9f7d-4802-8abf-745e75b2845c"
[2025-03-27 15:51:31.679505] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 6
[2025-03-27 15:51:31.679512] ctrlr.c: 756:_nvmf_ctrlr_add_io_qpair: *DEBUG*: Connect I/O Queue for controller id 0x1
[2025-03-27 15:51:31.679519] ctrlr.c: 320:nvmf_ctrlr_add_qpair: *DEBUG*: qpair_mask set, qid 14
[2025-03-27 15:51:31.679525] ctrlr.c: 266:nvmf_ctrlr_send_connect_rsp: *DEBUG*: connect capsule response: cntlid = 0x0001
[2025-03-27 15:51:31.679532] nvme_qpair.c: 474:spdk_nvme_print_completion: *NOTICE*: SUCCESS (00/00) qid:14 cid:0 cdw0:1 sqhd:0000 p:0 m:0 dnr:0
[2025-03-27 15:51:31.679543] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 7
[2025-03-27 15:51:31.679549] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 9
[2025-03-27 15:51:31.679554] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 10
[2025-03-27 15:51:31.679559] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 12
[2025-03-27 15:51:31.679572] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 13
[2025-03-27 15:51:31.679578] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 0
[2025-03-27 15:51:31.679647] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 1
[2025-03-27 15:51:31.679653] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 2
[2025-03-27 15:51:31.679658] rdma.c:1902:nvmf_rdma_request_parse_sgl: *DEBUG*: In-capsule data: offset 0x0, length 0x400
[2025-03-27 15:51:31.679663] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 5
[2025-03-27 15:51:31.679670] nvme_qpair.c: 218:nvme_admin_qpair_print_command: *NOTICE*: FABRIC CONNECT qid:15 cid:0 SGL DATA BLOCK OFFSET 0x0 len:0x400
[2025-03-27 15:51:31.679683] ctrlr.c: 855:_nvmf_ctrlr_connect: *DEBUG*: recfmt 0x0 qid 15 sqsize 127
[2025-03-27 15:51:31.679689] ctrlr.c: 858:_nvmf_ctrlr_connect: *DEBUG*: Connect data:
[2025-03-27 15:51:31.679694] ctrlr.c: 859:_nvmf_ctrlr_connect: *DEBUG*:   cntlid:  0x0001
[2025-03-27 15:51:31.679700] ctrlr.c: 860:_nvmf_ctrlr_connect: *DEBUG*:   hostid: c3ab7015-781c-4b07-af33-0cd1204f4499 ***
[2025-03-27 15:51:31.679705] ctrlr.c: 868:_nvmf_ctrlr_connect: *DEBUG*:   subnqn: "nqn.2022-06.io.spdk:cnode216"
[2025-03-27 15:51:31.679710] ctrlr.c: 869:_nvmf_ctrlr_connect: *DEBUG*:   hostnqn: "nqn.2014-08.org.nvmexpress:uuid:e553e370-9f7d-4802-8abf-745e75b2845c"
[2025-03-27 15:51:31.679716] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 6
[2025-03-27 15:51:31.679722] ctrlr.c: 756:_nvmf_ctrlr_add_io_qpair: *DEBUG*: Connect I/O Queue for controller id 0x1
[2025-03-27 15:51:31.679729] ctrlr.c: 320:nvmf_ctrlr_add_qpair: *DEBUG*: qpair_mask set, qid 15
[2025-03-27 15:51:31.679736] ctrlr.c: 266:nvmf_ctrlr_send_connect_rsp: *DEBUG*: connect capsule response: cntlid = 0x0001
[2025-03-27 15:51:31.679743] nvme_qpair.c: 474:spdk_nvme_print_completion: *NOTICE*: SUCCESS (00/00) qid:15 cid:0 cdw0:1 sqhd:0000 p:0 m:0 dnr:0
[2025-03-27 15:51:31.679753] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 7
[2025-03-27 15:51:31.679759] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 9
[2025-03-27 15:51:31.679764] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 10
[2025-03-27 15:51:31.679770] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 12
[2025-03-27 15:51:31.679782] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 13
[2025-03-27 15:51:31.679788] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 0
[2025-03-27 15:51:31.679865] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 1
[2025-03-27 15:51:31.679871] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 2
[2025-03-27 15:51:31.679877] rdma.c:1902:nvmf_rdma_request_parse_sgl: *DEBUG*: In-capsule data: offset 0x0, length 0x400
[2025-03-27 15:51:31.679882] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 5
[2025-03-27 15:51:31.679889] nvme_qpair.c: 218:nvme_admin_qpair_print_command: *NOTICE*: FABRIC CONNECT qid:16 cid:0 SGL DATA BLOCK OFFSET 0x0 len:0x400
[2025-03-27 15:51:31.679902] ctrlr.c: 855:_nvmf_ctrlr_connect: *DEBUG*: recfmt 0x0 qid 16 sqsize 127
[2025-03-27 15:51:31.679907] ctrlr.c: 858:_nvmf_ctrlr_connect: *DEBUG*: Connect data:
[2025-03-27 15:51:31.679912] ctrlr.c: 859:_nvmf_ctrlr_connect: *DEBUG*:   cntlid:  0x0001
[2025-03-27 15:51:31.679918] ctrlr.c: 860:_nvmf_ctrlr_connect: *DEBUG*:   hostid: c3ab7015-781c-4b07-af33-0cd1204f4499 ***
[2025-03-27 15:51:31.679923] ctrlr.c: 868:_nvmf_ctrlr_connect: *DEBUG*:   subnqn: "nqn.2022-06.io.spdk:cnode216"
[2025-03-27 15:51:31.679928] ctrlr.c: 869:_nvmf_ctrlr_connect: *DEBUG*:   hostnqn: "nqn.2014-08.org.nvmexpress:uuid:e553e370-9f7d-4802-8abf-745e75b2845c"
[2025-03-27 15:51:31.679934] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 6
[2025-03-27 15:51:31.679941] ctrlr.c: 756:_nvmf_ctrlr_add_io_qpair: *DEBUG*: Connect I/O Queue for controller id 0x1
[2025-03-27 15:51:31.679948] ctrlr.c: 320:nvmf_ctrlr_add_qpair: *DEBUG*: qpair_mask set, qid 16
[2025-03-27 15:51:31.679954] ctrlr.c: 266:nvmf_ctrlr_send_connect_rsp: *DEBUG*: connect capsule response: cntlid = 0x0001
[2025-03-27 15:51:31.679961] nvme_qpair.c: 474:spdk_nvme_print_completion: *NOTICE*: SUCCESS (00/00) qid:16 cid:0 cdw0:1 sqhd:0000 p:0 m:0 dnr:0
[2025-03-27 15:51:31.679972] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 7
[2025-03-27 15:51:31.679978] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 9
[2025-03-27 15:51:31.679994] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 10
[2025-03-27 15:51:31.680010] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 12
[2025-03-27 15:51:31.680023] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 13
[2025-03-27 15:51:31.680029] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 0
[2025-03-27 15:51:31.680112] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 1
[2025-03-27 15:51:31.680118] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 2
[2025-03-27 15:51:31.680123] rdma.c:1902:nvmf_rdma_request_parse_sgl: *DEBUG*: In-capsule data: offset 0x0, length 0x400
[2025-03-27 15:51:31.680128] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 5
[2025-03-27 15:51:31.680134] nvme_qpair.c: 218:nvme_admin_qpair_print_command: *NOTICE*: FABRIC CONNECT qid:17 cid:0 SGL DATA BLOCK OFFSET 0x0 len:0x400
[2025-03-27 15:51:31.680147] ctrlr.c: 855:_nvmf_ctrlr_connect: *DEBUG*: recfmt 0x0 qid 17 sqsize 127
[2025-03-27 15:51:31.680152] ctrlr.c: 858:_nvmf_ctrlr_connect: *DEBUG*: Connect data:
[2025-03-27 15:51:31.680157] ctrlr.c: 859:_nvmf_ctrlr_connect: *DEBUG*:   cntlid:  0x0001
[2025-03-27 15:51:31.680162] ctrlr.c: 860:_nvmf_ctrlr_connect: *DEBUG*:   hostid: c3ab7015-781c-4b07-af33-0cd1204f4499 ***
[2025-03-27 15:51:31.680167] ctrlr.c: 868:_nvmf_ctrlr_connect: *DEBUG*:   subnqn: "nqn.2022-06.io.spdk:cnode216"
[2025-03-27 15:51:31.680172] ctrlr.c: 869:_nvmf_ctrlr_connect: *DEBUG*:   hostnqn: "nqn.2014-08.org.nvmexpress:uuid:e553e370-9f7d-4802-8abf-745e75b2845c"
[2025-03-27 15:51:31.680177] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 6
[2025-03-27 15:51:31.680183] ctrlr.c: 756:_nvmf_ctrlr_add_io_qpair: *DEBUG*: Connect I/O Queue for controller id 0x1
[2025-03-27 15:51:31.680190] ctrlr.c: 320:nvmf_ctrlr_add_qpair: *DEBUG*: qpair_mask set, qid 17
[2025-03-27 15:51:31.680196] ctrlr.c: 266:nvmf_ctrlr_send_connect_rsp: *DEBUG*: connect capsule response: cntlid = 0x0001
[2025-03-27 15:51:31.680202] nvme_qpair.c: 474:spdk_nvme_print_completion: *NOTICE*: SUCCESS (00/00) qid:17 cid:0 cdw0:1 sqhd:0000 p:0 m:0 dnr:0
[2025-03-27 15:51:31.680212] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 7
[2025-03-27 15:51:31.680218] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 9
[2025-03-27 15:51:31.680222] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 10
[2025-03-27 15:51:31.680228] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 12
[2025-03-27 15:51:31.680239] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 13
[2025-03-27 15:51:31.680245] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 0
[2025-03-27 15:51:31.680294] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 1
[2025-03-27 15:51:31.680299] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 2
[2025-03-27 15:51:31.680304] rdma.c:1902:nvmf_rdma_request_parse_sgl: *DEBUG*: In-capsule data: offset 0x0, length 0x400
[2025-03-27 15:51:31.680309] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 5
[2025-03-27 15:51:31.680315] nvme_qpair.c: 218:nvme_admin_qpair_print_command: *NOTICE*: FABRIC CONNECT qid:18 cid:0 SGL DATA BLOCK OFFSET 0x0 len:0x400
[2025-03-27 15:51:31.680326] ctrlr.c: 855:_nvmf_ctrlr_connect: *DEBUG*: recfmt 0x0 qid 18 sqsize 127
[2025-03-27 15:51:31.680332] ctrlr.c: 858:_nvmf_ctrlr_connect: *DEBUG*: Connect data:
[2025-03-27 15:51:31.680337] ctrlr.c: 859:_nvmf_ctrlr_connect: *DEBUG*:   cntlid:  0x0001
[2025-03-27 15:51:31.680342] ctrlr.c: 860:_nvmf_ctrlr_connect: *DEBUG*:   hostid: c3ab7015-781c-4b07-af33-0cd1204f4499 ***
[2025-03-27 15:51:31.680347] ctrlr.c: 868:_nvmf_ctrlr_connect: *DEBUG*:   subnqn: "nqn.2022-06.io.spdk:cnode216"
[2025-03-27 15:51:31.680351] ctrlr.c: 869:_nvmf_ctrlr_connect: *DEBUG*:   hostnqn: "nqn.2014-08.org.nvmexpress:uuid:e553e370-9f7d-4802-8abf-745e75b2845c"
[2025-03-27 15:51:31.680357] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 6
[2025-03-27 15:51:31.680363] ctrlr.c: 756:_nvmf_ctrlr_add_io_qpair: *DEBUG*: Connect I/O Queue for controller id 0x1
[2025-03-27 15:51:31.680369] ctrlr.c: 320:nvmf_ctrlr_add_qpair: *DEBUG*: qpair_mask set, qid 18
[2025-03-27 15:51:31.680375] ctrlr.c: 266:nvmf_ctrlr_send_connect_rsp: *DEBUG*: connect capsule response: cntlid = 0x0001
[2025-03-27 15:51:31.680381] nvme_qpair.c: 474:spdk_nvme_print_completion: *NOTICE*: SUCCESS (00/00) qid:18 cid:0 cdw0:1 sqhd:0000 p:0 m:0 dnr:0
[2025-03-27 15:51:31.680391] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 7
[2025-03-27 15:51:31.680397] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 9
[2025-03-27 15:51:31.680402] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 10
[2025-03-27 15:51:31.680407] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 12
[2025-03-27 15:51:31.680419] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 13
[2025-03-27 15:51:31.680424] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 0
[2025-03-27 15:51:31.680476] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 1
[2025-03-27 15:51:31.680481] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 2
[2025-03-27 15:51:31.680486] rdma.c:1902:nvmf_rdma_request_parse_sgl: *DEBUG*: In-capsule data: offset 0x0, length 0x400
[2025-03-27 15:51:31.680491] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 5
[2025-03-27 15:51:31.680497] nvme_qpair.c: 218:nvme_admin_qpair_print_command: *NOTICE*: FABRIC CONNECT qid:19 cid:0 SGL DATA BLOCK OFFSET 0x0 len:0x400
[2025-03-27 15:51:31.680509] ctrlr.c: 855:_nvmf_ctrlr_connect: *DEBUG*: recfmt 0x0 qid 19 sqsize 127
[2025-03-27 15:51:31.680514] ctrlr.c: 858:_nvmf_ctrlr_connect: *DEBUG*: Connect data:
[2025-03-27 15:51:31.680519] ctrlr.c: 859:_nvmf_ctrlr_connect: *DEBUG*:   cntlid:  0x0001
[2025-03-27 15:51:31.680524] ctrlr.c: 860:_nvmf_ctrlr_connect: *DEBUG*:   hostid: c3ab7015-781c-4b07-af33-0cd1204f4499 ***
[2025-03-27 15:51:31.680528] ctrlr.c: 868:_nvmf_ctrlr_connect: *DEBUG*:   subnqn: "nqn.2022-06.io.spdk:cnode216"
[2025-03-27 15:51:31.680533] ctrlr.c: 869:_nvmf_ctrlr_connect: *DEBUG*:   hostnqn: "nqn.2014-08.org.nvmexpress:uuid:e553e370-9f7d-4802-8abf-745e75b2845c"
[2025-03-27 15:51:31.680538] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 6
[2025-03-27 15:51:31.680544] ctrlr.c: 756:_nvmf_ctrlr_add_io_qpair: *DEBUG*: Connect I/O Queue for controller id 0x1
[2025-03-27 15:51:31.680550] ctrlr.c: 320:nvmf_ctrlr_add_qpair: *DEBUG*: qpair_mask set, qid 19
[2025-03-27 15:51:31.680556] ctrlr.c: 266:nvmf_ctrlr_send_connect_rsp: *DEBUG*: connect capsule response: cntlid = 0x0001
[2025-03-27 15:51:31.680562] nvme_qpair.c: 474:spdk_nvme_print_completion: *NOTICE*: SUCCESS (00/00) qid:19 cid:0 cdw0:1 sqhd:0000 p:0 m:0 dnr:0
[2025-03-27 15:51:31.680573] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 7
[2025-03-27 15:51:31.680579] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 9
[2025-03-27 15:51:31.680584] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 10
[2025-03-27 15:51:31.680589] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 12
[2025-03-27 15:51:31.680601] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 13
[2025-03-27 15:51:31.680606] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 0
[2025-03-27 15:51:31.680673] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 1
[2025-03-27 15:51:31.680678] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 2
[2025-03-27 15:51:31.680683] rdma.c:1902:nvmf_rdma_request_parse_sgl: *DEBUG*: In-capsule data: offset 0x0, length 0x400
[2025-03-27 15:51:31.680688] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 5
[2025-03-27 15:51:31.680694] nvme_qpair.c: 218:nvme_admin_qpair_print_command: *NOTICE*: FABRIC CONNECT qid:20 cid:0 SGL DATA BLOCK OFFSET 0x0 len:0x400
[2025-03-27 15:51:31.680706] ctrlr.c: 855:_nvmf_ctrlr_connect: *DEBUG*: recfmt 0x0 qid 20 sqsize 127
[2025-03-27 15:51:31.680711] ctrlr.c: 858:_nvmf_ctrlr_connect: *DEBUG*: Connect data:
[2025-03-27 15:51:31.680716] ctrlr.c: 859:_nvmf_ctrlr_connect: *DEBUG*:   cntlid:  0x0001
[2025-03-27 15:51:31.680721] ctrlr.c: 860:_nvmf_ctrlr_connect: *DEBUG*:   hostid: c3ab7015-781c-4b07-af33-0cd1204f4499 ***
[2025-03-27 15:51:31.680726] ctrlr.c: 868:_nvmf_ctrlr_connect: *DEBUG*:   subnqn: "nqn.2022-06.io.spdk:cnode216"
[2025-03-27 15:51:31.680731] ctrlr.c: 869:_nvmf_ctrlr_connect: *DEBUG*:   hostnqn: "nqn.2014-08.org.nvmexpress:uuid:e553e370-9f7d-4802-8abf-745e75b2845c"
[2025-03-27 15:51:31.680736] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 6
[2025-03-27 15:51:31.680743] ctrlr.c: 756:_nvmf_ctrlr_add_io_qpair: *DEBUG*: Connect I/O Queue for controller id 0x1
[2025-03-27 15:51:31.680749] ctrlr.c: 320:nvmf_ctrlr_add_qpair: *DEBUG*: qpair_mask set, qid 20
[2025-03-27 15:51:31.680755] ctrlr.c: 266:nvmf_ctrlr_send_connect_rsp: *DEBUG*: connect capsule response: cntlid = 0x0001
[2025-03-27 15:51:31.680761] nvme_qpair.c: 474:spdk_nvme_print_completion: *NOTICE*: SUCCESS (00/00) qid:20 cid:0 cdw0:1 sqhd:0000 p:0 m:0 dnr:0
[2025-03-27 15:51:31.680772] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 7
[2025-03-27 15:51:31.680777] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 9
[2025-03-27 15:51:31.680782] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 10
[2025-03-27 15:51:31.680787] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 12
[2025-03-27 15:51:31.680799] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 13
[2025-03-27 15:51:31.680804] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 0
[2025-03-27 15:51:31.680883] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 1
[2025-03-27 15:51:31.680888] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 2
[2025-03-27 15:51:31.680893] rdma.c:1902:nvmf_rdma_request_parse_sgl: *DEBUG*: In-capsule data: offset 0x0, length 0x400
[2025-03-27 15:51:31.680898] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 5
[2025-03-27 15:51:31.680905] nvme_qpair.c: 218:nvme_admin_qpair_print_command: *NOTICE*: FABRIC CONNECT qid:21 cid:0 SGL DATA BLOCK OFFSET 0x0 len:0x400
[2025-03-27 15:51:31.680917] ctrlr.c: 855:_nvmf_ctrlr_connect: *DEBUG*: recfmt 0x0 qid 21 sqsize 127
[2025-03-27 15:51:31.680923] ctrlr.c: 858:_nvmf_ctrlr_connect: *DEBUG*: Connect data:
[2025-03-27 15:51:31.680927] ctrlr.c: 859:_nvmf_ctrlr_connect: *DEBUG*:   cntlid:  0x0001
[2025-03-27 15:51:31.680932] ctrlr.c: 860:_nvmf_ctrlr_connect: *DEBUG*:   hostid: c3ab7015-781c-4b07-af33-0cd1204f4499 ***
[2025-03-27 15:51:31.680937] ctrlr.c: 868:_nvmf_ctrlr_connect: *DEBUG*:   subnqn: "nqn.2022-06.io.spdk:cnode216"
[2025-03-27 15:51:31.680942] ctrlr.c: 869:_nvmf_ctrlr_connect: *DEBUG*:   hostnqn: "nqn.2014-08.org.nvmexpress:uuid:e553e370-9f7d-4802-8abf-745e75b2845c"
[2025-03-27 15:51:31.680947] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 6
[2025-03-27 15:51:31.680953] ctrlr.c: 756:_nvmf_ctrlr_add_io_qpair: *DEBUG*: Connect I/O Queue for controller id 0x1
[2025-03-27 15:51:31.680960] ctrlr.c: 320:nvmf_ctrlr_add_qpair: *DEBUG*: qpair_mask set, qid 21
[2025-03-27 15:51:31.680966] ctrlr.c: 266:nvmf_ctrlr_send_connect_rsp: *DEBUG*: connect capsule response: cntlid = 0x0001
[2025-03-27 15:51:31.680972] nvme_qpair.c: 474:spdk_nvme_print_completion: *NOTICE*: SUCCESS (00/00) qid:21 cid:0 cdw0:1 sqhd:0000 p:0 m:0 dnr:0
[2025-03-27 15:51:31.680982] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 7
[2025-03-27 15:51:31.680988] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 9
[2025-03-27 15:51:31.680993] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 10
[2025-03-27 15:51:31.680998] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 12
[2025-03-27 15:51:31.681010] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 13
[2025-03-27 15:51:31.681016] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 0
[2025-03-27 15:51:31.681086] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 1
[2025-03-27 15:51:31.681091] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 2
[2025-03-27 15:51:31.681096] rdma.c:1902:nvmf_rdma_request_parse_sgl: *DEBUG*: In-capsule data: offset 0x0, length 0x400
[2025-03-27 15:51:31.681101] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 5
[2025-03-27 15:51:31.681107] nvme_qpair.c: 218:nvme_admin_qpair_print_command: *NOTICE*: FABRIC CONNECT qid:22 cid:0 SGL DATA BLOCK OFFSET 0x0 len:0x400
[2025-03-27 15:51:31.681119] ctrlr.c: 855:_nvmf_ctrlr_connect: *DEBUG*: recfmt 0x0 qid 22 sqsize 127
[2025-03-27 15:51:31.681125] ctrlr.c: 858:_nvmf_ctrlr_connect: *DEBUG*: Connect data:
[2025-03-27 15:51:31.681129] ctrlr.c: 859:_nvmf_ctrlr_connect: *DEBUG*:   cntlid:  0x0001
[2025-03-27 15:51:31.681134] ctrlr.c: 860:_nvmf_ctrlr_connect: *DEBUG*:   hostid: c3ab7015-781c-4b07-af33-0cd1204f4499 ***
[2025-03-27 15:51:31.681139] ctrlr.c: 868:_nvmf_ctrlr_connect: *DEBUG*:   subnqn: "nqn.2022-06.io.spdk:cnode216"
[2025-03-27 15:51:31.681144] ctrlr.c: 869:_nvmf_ctrlr_connect: *DEBUG*:   hostnqn: "nqn.2014-08.org.nvmexpress:uuid:e553e370-9f7d-4802-8abf-745e75b2845c"
[2025-03-27 15:51:31.681149] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 6
[2025-03-27 15:51:31.681155] ctrlr.c: 756:_nvmf_ctrlr_add_io_qpair: *DEBUG*: Connect I/O Queue for controller id 0x1
[2025-03-27 15:51:31.681162] ctrlr.c: 320:nvmf_ctrlr_add_qpair: *DEBUG*: qpair_mask set, qid 22
[2025-03-27 15:51:31.681168] ctrlr.c: 266:nvmf_ctrlr_send_connect_rsp: *DEBUG*: connect capsule response: cntlid = 0x0001
[2025-03-27 15:51:31.681174] nvme_qpair.c: 474:spdk_nvme_print_completion: *NOTICE*: SUCCESS (00/00) qid:22 cid:0 cdw0:1 sqhd:0000 p:0 m:0 dnr:0
[2025-03-27 15:51:31.681184] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 7
[2025-03-27 15:51:31.681190] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 9
[2025-03-27 15:51:31.681194] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 10
[2025-03-27 15:51:31.681199] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 12
[2025-03-27 15:51:31.681212] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 13
[2025-03-27 15:51:31.681217] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 0
[2025-03-27 15:51:31.681296] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 1
[2025-03-27 15:51:31.681301] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 2
[2025-03-27 15:51:31.681313] rdma.c:1902:nvmf_rdma_request_parse_sgl: *DEBUG*: In-capsule data: offset 0x0, length 0x400
[2025-03-27 15:51:31.681318] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 5
[2025-03-27 15:51:31.681325] nvme_qpair.c: 218:nvme_admin_qpair_print_command: *NOTICE*: FABRIC CONNECT qid:23 cid:0 SGL DATA BLOCK OFFSET 0x0 len:0x400
[2025-03-27 15:51:31.681336] ctrlr.c: 855:_nvmf_ctrlr_connect: *DEBUG*: recfmt 0x0 qid 23 sqsize 127
[2025-03-27 15:51:31.681342] ctrlr.c: 858:_nvmf_ctrlr_connect: *DEBUG*: Connect data:
[2025-03-27 15:51:31.681347] ctrlr.c: 859:_nvmf_ctrlr_connect: *DEBUG*:   cntlid:  0x0001
[2025-03-27 15:51:31.681352] ctrlr.c: 860:_nvmf_ctrlr_connect: *DEBUG*:   hostid: c3ab7015-781c-4b07-af33-0cd1204f4499 ***
[2025-03-27 15:51:31.681357] ctrlr.c: 868:_nvmf_ctrlr_connect: *DEBUG*:   subnqn: "nqn.2022-06.io.spdk:cnode216"
[2025-03-27 15:51:31.681362] ctrlr.c: 869:_nvmf_ctrlr_connect: *DEBUG*:   hostnqn: "nqn.2014-08.org.nvmexpress:uuid:e553e370-9f7d-4802-8abf-745e75b2845c"
[2025-03-27 15:51:31.681367] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 6
[2025-03-27 15:51:31.681373] ctrlr.c: 756:_nvmf_ctrlr_add_io_qpair: *DEBUG*: Connect I/O Queue for controller id 0x1
[2025-03-27 15:51:31.681379] ctrlr.c: 320:nvmf_ctrlr_add_qpair: *DEBUG*: qpair_mask set, qid 23
[2025-03-27 15:51:31.681385] ctrlr.c: 266:nvmf_ctrlr_send_connect_rsp: *DEBUG*: connect capsule response: cntlid = 0x0001
[2025-03-27 15:51:31.681391] nvme_qpair.c: 474:spdk_nvme_print_completion: *NOTICE*: SUCCESS (00/00) qid:23 cid:0 cdw0:1 sqhd:0000 p:0 m:0 dnr:0
[2025-03-27 15:51:31.681401] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 7
[2025-03-27 15:51:31.681407] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 9
[2025-03-27 15:51:31.681412] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 10
[2025-03-27 15:51:31.681417] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 12
[2025-03-27 15:51:31.681429] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 13
[2025-03-27 15:51:31.681434] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 0
[2025-03-27 15:51:31.681516] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 1
[2025-03-27 15:51:31.681521] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 2
[2025-03-27 15:51:31.681526] rdma.c:1902:nvmf_rdma_request_parse_sgl: *DEBUG*: In-capsule data: offset 0x0, length 0x400
[2025-03-27 15:51:31.681531] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 5
[2025-03-27 15:51:31.681538] nvme_qpair.c: 218:nvme_admin_qpair_print_command: *NOTICE*: FABRIC CONNECT qid:24 cid:0 SGL DATA BLOCK OFFSET 0x0 len:0x400
[2025-03-27 15:51:31.681550] ctrlr.c: 855:_nvmf_ctrlr_connect: *DEBUG*: recfmt 0x0 qid 24 sqsize 127
[2025-03-27 15:51:31.681555] ctrlr.c: 858:_nvmf_ctrlr_connect: *DEBUG*: Connect data:
[2025-03-27 15:51:31.681560] ctrlr.c: 859:_nvmf_ctrlr_connect: *DEBUG*:   cntlid:  0x0001
[2025-03-27 15:51:31.681565] ctrlr.c: 860:_nvmf_ctrlr_connect: *DEBUG*:   hostid: c3ab7015-781c-4b07-af33-0cd1204f4499 ***
[2025-03-27 15:51:31.681569] ctrlr.c: 868:_nvmf_ctrlr_connect: *DEBUG*:   subnqn: "nqn.2022-06.io.spdk:cnode216"
[2025-03-27 15:51:31.681574] ctrlr.c: 869:_nvmf_ctrlr_connect: *DEBUG*:   hostnqn: "nqn.2014-08.org.nvmexpress:uuid:e553e370-9f7d-4802-8abf-745e75b2845c"
[2025-03-27 15:51:31.681579] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 6
[2025-03-27 15:51:31.681585] ctrlr.c: 756:_nvmf_ctrlr_add_io_qpair: *DEBUG*: Connect I/O Queue for controller id 0x1
[2025-03-27 15:51:31.681592] ctrlr.c: 320:nvmf_ctrlr_add_qpair: *DEBUG*: qpair_mask set, qid 24
[2025-03-27 15:51:31.681597] ctrlr.c: 266:nvmf_ctrlr_send_connect_rsp: *DEBUG*: connect capsule response: cntlid = 0x0001
[2025-03-27 15:51:31.681604] nvme_qpair.c: 474:spdk_nvme_print_completion: *NOTICE*: SUCCESS (00/00) qid:24 cid:0 cdw0:1 sqhd:0000 p:0 m:0 dnr:0
[2025-03-27 15:51:31.681614] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 7
[2025-03-27 15:51:31.681619] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 9
[2025-03-27 15:51:31.681624] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 10
[2025-03-27 15:51:31.681629] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 12
[2025-03-27 15:51:31.681641] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 13
[2025-03-27 15:51:31.681647] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 0
[2025-03-27 15:51:31.681697] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 1
[2025-03-27 15:51:31.681702] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 2
[2025-03-27 15:51:31.681707] rdma.c:1902:nvmf_rdma_request_parse_sgl: *DEBUG*: In-capsule data: offset 0x0, length 0x400
[2025-03-27 15:51:31.681712] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 5
[2025-03-27 15:51:31.681718] nvme_qpair.c: 218:nvme_admin_qpair_print_command: *NOTICE*: FABRIC CONNECT qid:25 cid:0 SGL DATA BLOCK OFFSET 0x0 len:0x400
[2025-03-27 15:51:31.681730] ctrlr.c: 855:_nvmf_ctrlr_connect: *DEBUG*: recfmt 0x0 qid 25 sqsize 127
[2025-03-27 15:51:31.681735] ctrlr.c: 858:_nvmf_ctrlr_connect: *DEBUG*: Connect data:
[2025-03-27 15:51:31.681741] ctrlr.c: 859:_nvmf_ctrlr_connect: *DEBUG*:   cntlid:  0x0001
[2025-03-27 15:51:31.681746] ctrlr.c: 860:_nvmf_ctrlr_connect: *DEBUG*:   hostid: c3ab7015-781c-4b07-af33-0cd1204f4499 ***
[2025-03-27 15:51:31.681751] ctrlr.c: 868:_nvmf_ctrlr_connect: *DEBUG*:   subnqn: "nqn.2022-06.io.spdk:cnode216"
[2025-03-27 15:51:31.681756] ctrlr.c: 869:_nvmf_ctrlr_connect: *DEBUG*:   hostnqn: "nqn.2014-08.org.nvmexpress:uuid:e553e370-9f7d-4802-8abf-745e75b2845c"
[2025-03-27 15:51:31.681761] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 6
[2025-03-27 15:51:31.681767] ctrlr.c: 756:_nvmf_ctrlr_add_io_qpair: *DEBUG*: Connect I/O Queue for controller id 0x1
[2025-03-27 15:51:31.681774] ctrlr.c: 320:nvmf_ctrlr_add_qpair: *DEBUG*: qpair_mask set, qid 25
[2025-03-27 15:51:31.681780] ctrlr.c: 266:nvmf_ctrlr_send_connect_rsp: *DEBUG*: connect capsule response: cntlid = 0x0001
[2025-03-27 15:51:31.681786] nvme_qpair.c: 474:spdk_nvme_print_completion: *NOTICE*: SUCCESS (00/00) qid:25 cid:0 cdw0:1 sqhd:0000 p:0 m:0 dnr:0
[2025-03-27 15:51:31.681796] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 7
[2025-03-27 15:51:31.681802] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 9
[2025-03-27 15:51:31.681807] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 10
[2025-03-27 15:51:31.681812] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 12
[2025-03-27 15:51:31.681824] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 13
[2025-03-27 15:51:31.681829] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 0
[2025-03-27 15:51:31.681908] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 1
[2025-03-27 15:51:31.681914] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 2
[2025-03-27 15:51:31.681919] rdma.c:1902:nvmf_rdma_request_parse_sgl: *DEBUG*: In-capsule data: offset 0x0, length 0x400
[2025-03-27 15:51:31.681924] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 5
[2025-03-27 15:51:31.681931] nvme_qpair.c: 218:nvme_admin_qpair_print_command: *NOTICE*: FABRIC CONNECT qid:26 cid:0 SGL DATA BLOCK OFFSET 0x0 len:0x400
[2025-03-27 15:51:31.681944] ctrlr.c: 855:_nvmf_ctrlr_connect: *DEBUG*: recfmt 0x0 qid 26 sqsize 127
[2025-03-27 15:51:31.681949] ctrlr.c: 858:_nvmf_ctrlr_connect: *DEBUG*: Connect data:
[2025-03-27 15:51:31.681954] ctrlr.c: 859:_nvmf_ctrlr_connect: *DEBUG*:   cntlid:  0x0001
[2025-03-27 15:51:31.681959] ctrlr.c: 860:_nvmf_ctrlr_connect: *DEBUG*:   hostid: c3ab7015-781c-4b07-af33-0cd1204f4499 ***
[2025-03-27 15:51:31.681964] ctrlr.c: 868:_nvmf_ctrlr_connect: *DEBUG*:   subnqn: "nqn.2022-06.io.spdk:cnode216"
[2025-03-27 15:51:31.681969] ctrlr.c: 869:_nvmf_ctrlr_connect: *DEBUG*:   hostnqn: "nqn.2014-08.org.nvmexpress:uuid:e553e370-9f7d-4802-8abf-745e75b2845c"
[2025-03-27 15:51:31.681974] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 6
[2025-03-27 15:51:31.681980] ctrlr.c: 756:_nvmf_ctrlr_add_io_qpair: *DEBUG*: Connect I/O Queue for controller id 0x1
[2025-03-27 15:51:31.681987] ctrlr.c: 320:nvmf_ctrlr_add_qpair: *DEBUG*: qpair_mask set, qid 26
[2025-03-27 15:51:31.681993] ctrlr.c: 266:nvmf_ctrlr_send_connect_rsp: *DEBUG*: connect capsule response: cntlid = 0x0001
[2025-03-27 15:51:31.681999] nvme_qpair.c: 474:spdk_nvme_print_completion: *NOTICE*: SUCCESS (00/00) qid:26 cid:0 cdw0:1 sqhd:0000 p:0 m:0 dnr:0
[2025-03-27 15:51:31.682009] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 7
[2025-03-27 15:51:31.682015] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 9
[2025-03-27 15:51:31.682020] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 10
[2025-03-27 15:51:31.682025] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 12
[2025-03-27 15:51:31.682037] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 13
[2025-03-27 15:51:31.682043] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 0
[2025-03-27 15:51:31.682112] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 1
[2025-03-27 15:51:31.682118] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 2
[2025-03-27 15:51:31.682123] rdma.c:1902:nvmf_rdma_request_parse_sgl: *DEBUG*: In-capsule data: offset 0x0, length 0x400
[2025-03-27 15:51:31.682128] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 5
[2025-03-27 15:51:31.682134] nvme_qpair.c: 218:nvme_admin_qpair_print_command: *NOTICE*: FABRIC CONNECT qid:27 cid:0 SGL DATA BLOCK OFFSET 0x0 len:0x400
[2025-03-27 15:51:31.682146] ctrlr.c: 855:_nvmf_ctrlr_connect: *DEBUG*: recfmt 0x0 qid 27 sqsize 127
[2025-03-27 15:51:31.682152] ctrlr.c: 858:_nvmf_ctrlr_connect: *DEBUG*: Connect data:
[2025-03-27 15:51:31.682156] ctrlr.c: 859:_nvmf_ctrlr_connect: *DEBUG*:   cntlid:  0x0001
[2025-03-27 15:51:31.682162] ctrlr.c: 860:_nvmf_ctrlr_connect: *DEBUG*:   hostid: c3ab7015-781c-4b07-af33-0cd1204f4499 ***
[2025-03-27 15:51:31.682166] ctrlr.c: 868:_nvmf_ctrlr_connect: *DEBUG*:   subnqn: "nqn.2022-06.io.spdk:cnode216"
[2025-03-27 15:51:31.682170] ctrlr.c: 869:_nvmf_ctrlr_connect: *DEBUG*:   hostnqn: "nqn.2014-08.org.nvmexpress:uuid:e553e370-9f7d-4802-8abf-745e75b2845c"
[2025-03-27 15:51:31.682176] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 6
[2025-03-27 15:51:31.682181] ctrlr.c: 756:_nvmf_ctrlr_add_io_qpair: *DEBUG*: Connect I/O Queue for controller id 0x1
[2025-03-27 15:51:31.682188] ctrlr.c: 320:nvmf_ctrlr_add_qpair: *DEBUG*: qpair_mask set, qid 27
[2025-03-27 15:51:31.682194] ctrlr.c: 266:nvmf_ctrlr_send_connect_rsp: *DEBUG*: connect capsule response: cntlid = 0x0001
[2025-03-27 15:51:31.682200] nvme_qpair.c: 474:spdk_nvme_print_completion: *NOTICE*: SUCCESS (00/00) qid:27 cid:0 cdw0:1 sqhd:0000 p:0 m:0 dnr:0
[2025-03-27 15:51:31.682210] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 7
[2025-03-27 15:51:31.682216] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 9
[2025-03-27 15:51:31.682221] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 10
[2025-03-27 15:51:31.682226] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 12
[2025-03-27 15:51:31.682238] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 13
[2025-03-27 15:51:31.682243] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 0
[2025-03-27 15:51:31.682279] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 1
[2025-03-27 15:51:31.682284] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 2
[2025-03-27 15:51:31.682289] rdma.c:1902:nvmf_rdma_request_parse_sgl: *DEBUG*: In-capsule data: offset 0x0, length 0x400
[2025-03-27 15:51:31.682294] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 5
[2025-03-27 15:51:31.682301] nvme_qpair.c: 218:nvme_admin_qpair_print_command: *NOTICE*: FABRIC CONNECT qid:28 cid:0 SGL DATA BLOCK OFFSET 0x0 len:0x400
[2025-03-27 15:51:31.682312] ctrlr.c: 855:_nvmf_ctrlr_connect: *DEBUG*: recfmt 0x0 qid 28 sqsize 127
[2025-03-27 15:51:31.682317] ctrlr.c: 858:_nvmf_ctrlr_connect: *DEBUG*: Connect data:
[2025-03-27 15:51:31.682322] ctrlr.c: 859:_nvmf_ctrlr_connect: *DEBUG*:   cntlid:  0x0001
[2025-03-27 15:51:31.682327] ctrlr.c: 860:_nvmf_ctrlr_connect: *DEBUG*:   hostid: c3ab7015-781c-4b07-af33-0cd1204f4499 ***
[2025-03-27 15:51:31.682332] ctrlr.c: 868:_nvmf_ctrlr_connect: *DEBUG*:   subnqn: "nqn.2022-06.io.spdk:cnode216"
[2025-03-27 15:51:31.682336] ctrlr.c: 869:_nvmf_ctrlr_connect: *DEBUG*:   hostnqn: "nqn.2014-08.org.nvmexpress:uuid:e553e370-9f7d-4802-8abf-745e75b2845c"
[2025-03-27 15:51:31.682342] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 6
[2025-03-27 15:51:31.682347] ctrlr.c: 756:_nvmf_ctrlr_add_io_qpair: *DEBUG*: Connect I/O Queue for controller id 0x1
[2025-03-27 15:51:31.682354] ctrlr.c: 320:nvmf_ctrlr_add_qpair: *DEBUG*: qpair_mask set, qid 28
[2025-03-27 15:51:31.682363] rdma.c:3696:nvmf_process_cm_events: *DEBUG*: Acceptor Event: RDMA_CM_EVENT_ESTABLISHED
[2025-03-27 15:51:31.682370] ctrlr.c: 266:nvmf_ctrlr_send_connect_rsp: *DEBUG*: connect capsule response: cntlid = 0x0001
[2025-03-27 15:51:31.682377] nvme_qpair.c: 474:spdk_nvme_print_completion: *NOTICE*: SUCCESS (00/00) qid:28 cid:0 cdw0:1 sqhd:0000 p:0 m:0 dnr:0
[2025-03-27 15:51:31.682387] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 7
[2025-03-27 15:51:31.682392] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 9
[2025-03-27 15:51:31.682397] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 10
[2025-03-27 15:51:31.682402] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 12
[2025-03-27 15:51:31.682414] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 13
[2025-03-27 15:51:31.682419] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 0
[2025-03-27 15:51:31.682496] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 1
[2025-03-27 15:51:31.682512] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 2
[2025-03-27 15:51:31.682517] rdma.c:1902:nvmf_rdma_request_parse_sgl: *DEBUG*: In-capsule data: offset 0x0, length 0x400
[2025-03-27 15:51:31.682523] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 5
[2025-03-27 15:51:31.682530] nvme_qpair.c: 218:nvme_admin_qpair_print_command: *NOTICE*: FABRIC CONNECT qid:29 cid:0 SGL DATA BLOCK OFFSET 0x0 len:0x400
[2025-03-27 15:51:31.682545] ctrlr.c: 855:_nvmf_ctrlr_connect: *DEBUG*: recfmt 0x0 qid 29 sqsize 127
[2025-03-27 15:51:31.682551] ctrlr.c: 858:_nvmf_ctrlr_connect: *DEBUG*: Connect data:
[2025-03-27 15:51:31.682556] ctrlr.c: 859:_nvmf_ctrlr_connect: *DEBUG*:   cntlid:  0x0001
[2025-03-27 15:51:31.682561] ctrlr.c: 860:_nvmf_ctrlr_connect: *DEBUG*:   hostid: c3ab7015-781c-4b07-af33-0cd1204f4499 ***
[2025-03-27 15:51:31.682566] ctrlr.c: 868:_nvmf_ctrlr_connect: *DEBUG*:   subnqn: "nqn.2022-06.io.spdk:cnode216"
[2025-03-27 15:51:31.682571] ctrlr.c: 869:_nvmf_ctrlr_connect: *DEBUG*:   hostnqn: "nqn.2014-08.org.nvmexpress:uuid:e553e370-9f7d-4802-8abf-745e75b2845c"
[2025-03-27 15:51:31.682577] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 6
[2025-03-27 15:51:31.682583] ctrlr.c: 756:_nvmf_ctrlr_add_io_qpair: *DEBUG*: Connect I/O Queue for controller id 0x1
[2025-03-27 15:51:31.682591] ctrlr.c: 320:nvmf_ctrlr_add_qpair: *DEBUG*: qpair_mask set, qid 29
[2025-03-27 15:51:31.682597] ctrlr.c: 266:nvmf_ctrlr_send_connect_rsp: *DEBUG*: connect capsule response: cntlid = 0x0001
[2025-03-27 15:51:31.682604] nvme_qpair.c: 474:spdk_nvme_print_completion: *NOTICE*: SUCCESS (00/00) qid:29 cid:0 cdw0:1 sqhd:0000 p:0 m:0 dnr:0
[2025-03-27 15:51:31.682614] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 7
[2025-03-27 15:51:31.682620] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 9
[2025-03-27 15:51:31.682625] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 10
[2025-03-27 15:51:31.682631] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 12
[2025-03-27 15:51:31.682643] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 13
[2025-03-27 15:51:31.682649] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 0
[2025-03-27 15:51:31.682715] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 1
[2025-03-27 15:51:31.682721] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 2
[2025-03-27 15:51:31.682726] rdma.c:1902:nvmf_rdma_request_parse_sgl: *DEBUG*: In-capsule data: offset 0x0, length 0x400
[2025-03-27 15:51:31.682732] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 5
[2025-03-27 15:51:31.682738] nvme_qpair.c: 218:nvme_admin_qpair_print_command: *NOTICE*: FABRIC CONNECT qid:30 cid:0 SGL DATA BLOCK OFFSET 0x0 len:0x400
[2025-03-27 15:51:31.682752] ctrlr.c: 855:_nvmf_ctrlr_connect: *DEBUG*: recfmt 0x0 qid 30 sqsize 127
[2025-03-27 15:51:31.682757] ctrlr.c: 858:_nvmf_ctrlr_connect: *DEBUG*: Connect data:
[2025-03-27 15:51:31.682763] ctrlr.c: 859:_nvmf_ctrlr_connect: *DEBUG*:   cntlid:  0x0001
[2025-03-27 15:51:31.682768] ctrlr.c: 860:_nvmf_ctrlr_connect: *DEBUG*:   hostid: c3ab7015-781c-4b07-af33-0cd1204f4499 ***
[2025-03-27 15:51:31.682773] ctrlr.c: 868:_nvmf_ctrlr_connect: *DEBUG*:   subnqn: "nqn.2022-06.io.spdk:cnode216"
[2025-03-27 15:51:31.682778] ctrlr.c: 869:_nvmf_ctrlr_connect: *DEBUG*:   hostnqn: "nqn.2014-08.org.nvmexpress:uuid:e553e370-9f7d-4802-8abf-745e75b2845c"
[2025-03-27 15:51:31.682784] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 6
[2025-03-27 15:51:31.682790] ctrlr.c: 756:_nvmf_ctrlr_add_io_qpair: *DEBUG*: Connect I/O Queue for controller id 0x1
[2025-03-27 15:51:31.682798] ctrlr.c: 320:nvmf_ctrlr_add_qpair: *DEBUG*: qpair_mask set, qid 30
[2025-03-27 15:51:31.682804] ctrlr.c: 266:nvmf_ctrlr_send_connect_rsp: *DEBUG*: connect capsule response: cntlid = 0x0001
[2025-03-27 15:51:31.682811] nvme_qpair.c: 474:spdk_nvme_print_completion: *NOTICE*: SUCCESS (00/00) qid:30 cid:0 cdw0:1 sqhd:0000 p:0 m:0 dnr:0
[2025-03-27 15:51:31.682821] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 7
[2025-03-27 15:51:31.682827] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 9
[2025-03-27 15:51:31.682832] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 10
[2025-03-27 15:51:31.682838] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 12
[2025-03-27 15:51:31.682850] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 13
[2025-03-27 15:51:31.682856] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 0
[2025-03-27 15:51:31.682937] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 1
[2025-03-27 15:51:31.682943] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 2
[2025-03-27 15:51:31.682948] rdma.c:1902:nvmf_rdma_request_parse_sgl: *DEBUG*: In-capsule data: offset 0x0, length 0x400
[2025-03-27 15:51:31.682953] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 5
[2025-03-27 15:51:31.682960] nvme_qpair.c: 218:nvme_admin_qpair_print_command: *NOTICE*: FABRIC CONNECT qid:31 cid:0 SGL DATA BLOCK OFFSET 0x0 len:0x400
[2025-03-27 15:51:31.682974] ctrlr.c: 855:_nvmf_ctrlr_connect: *DEBUG*: recfmt 0x0 qid 31 sqsize 127
[2025-03-27 15:51:31.682979] ctrlr.c: 858:_nvmf_ctrlr_connect: *DEBUG*: Connect data:
[2025-03-27 15:51:31.682984] ctrlr.c: 859:_nvmf_ctrlr_connect: *DEBUG*:   cntlid:  0x0001
[2025-03-27 15:51:31.682990] ctrlr.c: 860:_nvmf_ctrlr_connect: *DEBUG*:   hostid: c3ab7015-781c-4b07-af33-0cd1204f4499 ***
[2025-03-27 15:51:31.682995] ctrlr.c: 868:_nvmf_ctrlr_connect: *DEBUG*:   subnqn: "nqn.2022-06.io.spdk:cnode216"
[2025-03-27 15:51:31.683000] ctrlr.c: 869:_nvmf_ctrlr_connect: *DEBUG*:   hostnqn: "nqn.2014-08.org.nvmexpress:uuid:e553e370-9f7d-4802-8abf-745e75b2845c"
[2025-03-27 15:51:31.683006] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 6
[2025-03-27 15:51:31.683012] ctrlr.c: 756:_nvmf_ctrlr_add_io_qpair: *DEBUG*: Connect I/O Queue for controller id 0x1
[2025-03-27 15:51:31.683019] ctrlr.c: 320:nvmf_ctrlr_add_qpair: *DEBUG*: qpair_mask set, qid 31
[2025-03-27 15:51:31.683025] ctrlr.c: 266:nvmf_ctrlr_send_connect_rsp: *DEBUG*: connect capsule response: cntlid = 0x0001
[2025-03-27 15:51:31.683032] nvme_qpair.c: 474:spdk_nvme_print_completion: *NOTICE*: SUCCESS (00/00) qid:31 cid:0 cdw0:1 sqhd:0000 p:0 m:0 dnr:0
[2025-03-27 15:51:31.683061] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 7
[2025-03-27 15:51:31.683068] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 9
[2025-03-27 15:51:31.683073] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 10
[2025-03-27 15:51:31.683079] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 12
[2025-03-27 15:51:31.683092] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 13
[2025-03-27 15:51:31.683099] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 0
[2025-03-27 15:51:31.683173] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 1
[2025-03-27 15:51:31.683179] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 2
[2025-03-27 15:51:31.683185] rdma.c:1902:nvmf_rdma_request_parse_sgl: *DEBUG*: In-capsule data: offset 0x0, length 0x400
[2025-03-27 15:51:31.683192] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 5
[2025-03-27 15:51:31.683205] nvme_qpair.c: 218:nvme_admin_qpair_print_command: *NOTICE*: FABRIC CONNECT qid:32 cid:0 SGL DATA BLOCK OFFSET 0x0 len:0x400
[2025-03-27 15:51:31.683229] ctrlr.c: 855:_nvmf_ctrlr_connect: *DEBUG*: recfmt 0x0 qid 32 sqsize 127
[2025-03-27 15:51:31.683240] ctrlr.c: 858:_nvmf_ctrlr_connect: *DEBUG*: Connect data:
[2025-03-27 15:51:31.683250] ctrlr.c: 859:_nvmf_ctrlr_connect: *DEBUG*:   cntlid:  0x0001
[2025-03-27 15:51:31.683260] ctrlr.c: 860:_nvmf_ctrlr_connect: *DEBUG*:   hostid: c3ab7015-781c-4b07-af33-0cd1204f4499 ***
[2025-03-27 15:51:31.683269] ctrlr.c: 868:_nvmf_ctrlr_connect: *DEBUG*:   subnqn: "nqn.2022-06.io.spdk:cnode216"
[2025-03-27 15:51:31.683279] ctrlr.c: 869:_nvmf_ctrlr_connect: *DEBUG*:   hostnqn: "nqn.2014-08.org.nvmexpress:uuid:e553e370-9f7d-4802-8abf-745e75b2845c"
[2025-03-27 15:51:31.683291] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 6
[2025-03-27 15:51:31.683304] ctrlr.c: 756:_nvmf_ctrlr_add_io_qpair: *DEBUG*: Connect I/O Queue for controller id 0x1
[2025-03-27 15:51:31.683319] ctrlr.c: 320:nvmf_ctrlr_add_qpair: *DEBUG*: qpair_mask set, qid 32
[2025-03-27 15:51:31.683331] ctrlr.c: 266:nvmf_ctrlr_send_connect_rsp: *DEBUG*: connect capsule response: cntlid = 0x0001
[2025-03-27 15:51:31.683344] nvme_qpair.c: 474:spdk_nvme_print_completion: *NOTICE*: SUCCESS (00/00) qid:32 cid:0 cdw0:1 sqhd:0000 p:0 m:0 dnr:0
[2025-03-27 15:51:31.683362] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 7
[2025-03-27 15:51:31.683368] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 9
[2025-03-27 15:51:31.683374] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 10
[2025-03-27 15:51:31.683379] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 12
[2025-03-27 15:51:31.683393] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 13
[2025-03-27 15:51:31.683399] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 0
[2025-03-27 15:51:31.683473] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 1
[2025-03-27 15:51:31.683479] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 2
[2025-03-27 15:51:31.683485] rdma.c:1902:nvmf_rdma_request_parse_sgl: *DEBUG*: In-capsule data: offset 0x0, length 0x400
[2025-03-27 15:51:31.683490] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 5
[2025-03-27 15:51:31.683498] nvme_qpair.c: 218:nvme_admin_qpair_print_command: *NOTICE*: FABRIC CONNECT qid:33 cid:0 SGL DATA BLOCK OFFSET 0x0 len:0x400
[2025-03-27 15:51:31.683513] ctrlr.c: 855:_nvmf_ctrlr_connect: *DEBUG*: recfmt 0x0 qid 33 sqsize 127
[2025-03-27 15:51:31.683520] ctrlr.c: 858:_nvmf_ctrlr_connect: *DEBUG*: Connect data:
[2025-03-27 15:51:31.683525] ctrlr.c: 859:_nvmf_ctrlr_connect: *DEBUG*:   cntlid:  0x0001
[2025-03-27 15:51:31.683532] ctrlr.c: 860:_nvmf_ctrlr_connect: *DEBUG*:   hostid: c3ab7015-781c-4b07-af33-0cd1204f4499 ***
[2025-03-27 15:51:31.683537] ctrlr.c: 868:_nvmf_ctrlr_connect: *DEBUG*:   subnqn: "nqn.2022-06.io.spdk:cnode216"
[2025-03-27 15:51:31.683542] ctrlr.c: 869:_nvmf_ctrlr_connect: *DEBUG*:   hostnqn: "nqn.2014-08.org.nvmexpress:uuid:e553e370-9f7d-4802-8abf-745e75b2845c"
[2025-03-27 15:51:31.683548] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 6
[2025-03-27 15:51:31.683554] ctrlr.c: 756:_nvmf_ctrlr_add_io_qpair: *DEBUG*: Connect I/O Queue for controller id 0x1
[2025-03-27 15:51:31.683562] ctrlr.c: 320:nvmf_ctrlr_add_qpair: *DEBUG*: qpair_mask set, qid 33
[2025-03-27 15:51:31.683569] ctrlr.c: 266:nvmf_ctrlr_send_connect_rsp: *DEBUG*: connect capsule response: cntlid = 0x0001
[2025-03-27 15:51:31.683585] nvme_qpair.c: 474:spdk_nvme_print_completion: *NOTICE*: SUCCESS (00/00) qid:33 cid:0 cdw0:1 sqhd:0000 p:0 m:0 dnr:0
[2025-03-27 15:51:31.683596] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 7
[2025-03-27 15:51:31.683602] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 9
[2025-03-27 15:51:31.683607] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 10
[2025-03-27 15:51:31.683613] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 12
[2025-03-27 15:51:31.683637] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 13
[2025-03-27 15:51:31.683664] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 0
[2025-03-27 15:51:31.683728] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 1
[2025-03-27 15:51:31.683734] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 2
[2025-03-27 15:51:31.683739] rdma.c:1902:nvmf_rdma_request_parse_sgl: *DEBUG*: In-capsule data: offset 0x0, length 0x400
[2025-03-27 15:51:31.683744] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 5
[2025-03-27 15:51:31.683751] nvme_qpair.c: 218:nvme_admin_qpair_print_command: *NOTICE*: FABRIC CONNECT qid:34 cid:0 SGL DATA BLOCK OFFSET 0x0 len:0x400
[2025-03-27 15:51:31.683767] ctrlr.c: 855:_nvmf_ctrlr_connect: *DEBUG*: recfmt 0x0 qid 34 sqsize 127
[2025-03-27 15:51:31.683773] ctrlr.c: 858:_nvmf_ctrlr_connect: *DEBUG*: Connect data:
[2025-03-27 15:51:31.683778] ctrlr.c: 859:_nvmf_ctrlr_connect: *DEBUG*:   cntlid:  0x0001
[2025-03-27 15:51:31.683784] ctrlr.c: 860:_nvmf_ctrlr_connect: *DEBUG*:   hostid: c3ab7015-781c-4b07-af33-0cd1204f4499 ***
[2025-03-27 15:51:31.683789] ctrlr.c: 868:_nvmf_ctrlr_connect: *DEBUG*:   subnqn: "nqn.2022-06.io.spdk:cnode216"
[2025-03-27 15:51:31.683794] ctrlr.c: 869:_nvmf_ctrlr_connect: *DEBUG*:   hostnqn: "nqn.2014-08.org.nvmexpress:uuid:e553e370-9f7d-4802-8abf-745e75b2845c"
[2025-03-27 15:51:31.683800] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 6
[2025-03-27 15:51:31.683806] ctrlr.c: 756:_nvmf_ctrlr_add_io_qpair: *DEBUG*: Connect I/O Queue for controller id 0x1
[2025-03-27 15:51:31.683813] ctrlr.c: 320:nvmf_ctrlr_add_qpair: *DEBUG*: qpair_mask set, qid 34
[2025-03-27 15:51:31.683820] ctrlr.c: 266:nvmf_ctrlr_send_connect_rsp: *DEBUG*: connect capsule response: cntlid = 0x0001
[2025-03-27 15:51:31.683826] nvme_qpair.c: 474:spdk_nvme_print_completion: *NOTICE*: SUCCESS (00/00) qid:34 cid:0 cdw0:1 sqhd:0000 p:0 m:0 dnr:0
[2025-03-27 15:51:31.683837] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 7
[2025-03-27 15:51:31.683842] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 9
[2025-03-27 15:51:31.683848] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 10
[2025-03-27 15:51:31.683853] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 12
[2025-03-27 15:51:31.683866] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 13
[2025-03-27 15:51:31.683871] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 0
[2025-03-27 15:51:31.683945] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 1
[2025-03-27 15:51:31.683951] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 2
[2025-03-27 15:51:31.683956] rdma.c:1902:nvmf_rdma_request_parse_sgl: *DEBUG*: In-capsule data: offset 0x0, length 0x400
[2025-03-27 15:51:31.683961] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 5
[2025-03-27 15:51:31.683969] nvme_qpair.c: 218:nvme_admin_qpair_print_command: *NOTICE*: FABRIC CONNECT qid:35 cid:0 SGL DATA BLOCK OFFSET 0x0 len:0x400
[2025-03-27 15:51:31.683993] ctrlr.c: 855:_nvmf_ctrlr_connect: *DEBUG*: recfmt 0x0 qid 35 sqsize 127
[2025-03-27 15:51:31.683999] ctrlr.c: 858:_nvmf_ctrlr_connect: *DEBUG*: Connect data:
[2025-03-27 15:51:31.684004] ctrlr.c: 859:_nvmf_ctrlr_connect: *DEBUG*:   cntlid:  0x0001
[2025-03-27 15:51:31.684009] ctrlr.c: 860:_nvmf_ctrlr_connect: *DEBUG*:   hostid: c3ab7015-781c-4b07-af33-0cd1204f4499 ***
[2025-03-27 15:51:31.684014] ctrlr.c: 868:_nvmf_ctrlr_connect: *DEBUG*:   subnqn: "nqn.2022-06.io.spdk:cnode216"
[2025-03-27 15:51:31.684019] ctrlr.c: 869:_nvmf_ctrlr_connect: *DEBUG*:   hostnqn: "nqn.2014-08.org.nvmexpress:uuid:e553e370-9f7d-4802-8abf-745e75b2845c"
[2025-03-27 15:51:31.684024] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 6
[2025-03-27 15:51:31.684029] ctrlr.c: 756:_nvmf_ctrlr_add_io_qpair: *DEBUG*: Connect I/O Queue for controller id 0x1
[2025-03-27 15:51:31.686877] ctrlr.c: 320:nvmf_ctrlr_add_qpair: *DEBUG*: qpair_mask set, qid 35
[2025-03-27 15:51:31.686912] ctrlr.c: 266:nvmf_ctrlr_send_connect_rsp: *DEBUG*: connect capsule response: cntlid = 0x0001
[2025-03-27 15:51:31.686931] nvme_qpair.c: 474:spdk_nvme_print_completion: *NOTICE*: SUCCESS (00/00) qid:35 cid:0 cdw0:1 sqhd:0000 p:0 m:0 dnr:0
[2025-03-27 15:51:31.686958] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 7
[2025-03-27 15:51:31.686971] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 9
[2025-03-27 15:51:31.686980] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 10
[2025-03-27 15:51:31.686989] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 12
[2025-03-27 15:51:31.687009] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 13
[2025-03-27 15:51:31.687022] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 0
[2025-03-27 15:51:31.687186] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 1
[2025-03-27 15:51:31.687206] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 2
[2025-03-27 15:51:31.687218] rdma.c:1902:nvmf_rdma_request_parse_sgl: *DEBUG*: In-capsule data: offset 0x0, length 0x400
[2025-03-27 15:51:31.687228] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 5
[2025-03-27 15:51:31.687243] nvme_qpair.c: 218:nvme_admin_qpair_print_command: *NOTICE*: FABRIC CONNECT qid:36 cid:0 SGL DATA BLOCK OFFSET 0x0 len:0x400
[2025-03-27 15:51:31.687275] ctrlr.c: 855:_nvmf_ctrlr_connect: *DEBUG*: recfmt 0x0 qid 36 sqsize 127
[2025-03-27 15:51:31.687287] ctrlr.c: 858:_nvmf_ctrlr_connect: *DEBUG*: Connect data:
[2025-03-27 15:51:31.687296] ctrlr.c: 859:_nvmf_ctrlr_connect: *DEBUG*:   cntlid:  0x0001
[2025-03-27 15:51:31.687307] ctrlr.c: 860:_nvmf_ctrlr_connect: *DEBUG*:   hostid: c3ab7015-781c-4b07-af33-0cd1204f4499 ***
[2025-03-27 15:51:31.687316] ctrlr.c: 868:_nvmf_ctrlr_connect: *DEBUG*:   subnqn: "nqn.2022-06.io.spdk:cnode216"
[2025-03-27 15:51:31.687325] ctrlr.c: 869:_nvmf_ctrlr_connect: *DEBUG*:   hostnqn: "nqn.2014-08.org.nvmexpress:uuid:e553e370-9f7d-4802-8abf-745e75b2845c"
[2025-03-27 15:51:31.687337] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 6
[2025-03-27 15:51:31.687350] ctrlr.c: 756:_nvmf_ctrlr_add_io_qpair: *DEBUG*: Connect I/O Queue for controller id 0x1
[2025-03-27 15:51:31.687365] ctrlr.c: 320:nvmf_ctrlr_add_qpair: *DEBUG*: qpair_mask set, qid 36
[2025-03-27 15:51:31.687378] ctrlr.c: 266:nvmf_ctrlr_send_connect_rsp: *DEBUG*: connect capsule response: cntlid = 0x0001
[2025-03-27 15:51:31.687390] nvme_qpair.c: 474:spdk_nvme_print_completion: *NOTICE*: SUCCESS (00/00) qid:36 cid:0 cdw0:1 sqhd:0000 p:0 m:0 dnr:0
[2025-03-27 15:51:31.687414] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 7
[2025-03-27 15:51:31.687426] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 9
[2025-03-27 15:51:31.687435] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 10
[2025-03-27 15:51:31.687445] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 12
[2025-03-27 15:51:31.687465] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 13
[2025-03-27 15:51:31.687477] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 0
[2025-03-27 15:51:31.687588] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 1
[2025-03-27 15:51:31.687603] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 5
[2025-03-27 15:51:31.687617] nvme_qpair.c: 213:nvme_admin_qpair_print_command: *NOTICE*: SET FEATURES ASYNC EVENT CONFIGURATION cid:12314 cdw10:0000000b SGL KEYED DATA BLOCK ADDRESS 0x0 len:0x0 key:0x0
[2025-03-27 15:51:31.687642] ctrlr.c:2207:nvmf_ctrlr_set_features_async_event_configuration: *DEBUG*: Set Features - Async Event Configuration, cdw11 0x00000900
[2025-03-27 15:51:31.687656] nvme_qpair.c: 474:spdk_nvme_print_completion: *NOTICE*: SUCCESS (00/00) qid:0 cid:12314 cdw0:0 sqhd:0000 p:0 m:0 dnr:0
[2025-03-27 15:51:31.687675] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 7
[2025-03-27 15:51:31.687685] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 9
[2025-03-27 15:51:31.687694] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 10
[2025-03-27 15:51:31.687704] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 12
[2025-03-27 15:51:31.687713] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 12
[2025-03-27 15:51:31.687730] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 13
[2025-03-27 15:51:31.687741] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 0
[2025-03-27 15:51:31.687835] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 1
[2025-03-27 15:51:31.687848] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 5
[2025-03-27 15:51:31.687860] nvme_qpair.c: 223:nvme_admin_qpair_print_command: *NOTICE*: ASYNC EVENT REQUEST (0c) qid:0 cid:31 nsid:0 cdw10:00000000 cdw11:00000000 
[2025-03-27 15:51:31.687883] ctrlr.c:2222:nvmf_ctrlr_async_event_request: *DEBUG*: Async Event Request
[2025-03-27 15:51:31.687893] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280000 entering state 6
[2025-03-27 15:51:31.687906] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280580 entering state 1
[2025-03-27 15:51:31.687915] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280580 entering state 2
[2025-03-27 15:51:31.687927] rdma.c:1504:nvmf_rdma_fill_wr_sgl: *DEBUG*: sge[0] 0x200017280a00 addr 0x200004004000, len 4096
[2025-03-27 15:51:31.687937] rdma.c:1893:nvmf_rdma_request_parse_sgl: *DEBUG*: Request 0x200017280580 took 1 buffer/s from central pool
[2025-03-27 15:51:31.687946] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280580 entering state 5
[2025-03-27 15:51:31.687959] nvme_qpair.c: 223:nvme_admin_qpair_print_command: *NOTICE*: IDENTIFY (06) qid:0 cid:6 nsid:0 cdw10:00000006 cdw11:00000000 SGL KEYED DATA BLOCK INVALIDATE KEY 0x421d20000 len:0x1000 key:0x2003e4
[2025-03-27 15:51:31.687982] ctrlr.c:3382:nvmf_ctrlr_identify: *DEBUG*: Received identify command with CNS 0x06
[2025-03-27 15:51:31.687997] nvme_qpair.c: 474:spdk_nvme_print_completion: *NOTICE*: SUCCESS (00/00) qid:0 cid:6 cdw0:0 sqhd:0000 p:0 m:0 dnr:0
[2025-03-27 15:51:31.688014] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280580 entering state 7
[2025-03-27 15:51:31.688025] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280580 entering state 8
[2025-03-27 15:51:31.688034] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280580 entering state 10
[2025-03-27 15:51:31.688043] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280580 entering state 11
[2025-03-27 15:51:31.688052] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280580 entering state 11
[2025-03-27 15:51:31.688072] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280580 entering state 13
[2025-03-27 15:51:31.688083] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280580 entering state 0
[2025-03-27 15:51:31.688179] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280580 entering state 1
[2025-03-27 15:51:31.688192] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280580 entering state 2
[2025-03-27 15:51:31.688203] rdma.c:1504:nvmf_rdma_fill_wr_sgl: *DEBUG*: sge[0] 0x200017280a00 addr 0x200004004000, len 4096
[2025-03-27 15:51:31.688212] rdma.c:1893:nvmf_rdma_request_parse_sgl: *DEBUG*: Request 0x200017280580 took 1 buffer/s from central pool
[2025-03-27 15:51:31.688221] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280580 entering state 5
[2025-03-27 15:51:31.688234] nvme_qpair.c: 223:nvme_admin_qpair_print_command: *NOTICE*: IDENTIFY (06) qid:0 cid:7 nsid:0 cdw10:00000002 cdw11:00000000 SGL KEYED DATA BLOCK INVALIDATE KEY 0x421d20000 len:0x1000 key:0x2003e5
[2025-03-27 15:51:31.688257] ctrlr.c:3382:nvmf_ctrlr_identify: *DEBUG*: Received identify command with CNS 0x02
[2025-03-27 15:51:31.688274] nvme_qpair.c: 474:spdk_nvme_print_completion: *NOTICE*: SUCCESS (00/00) qid:0 cid:7 cdw0:0 sqhd:0000 p:0 m:0 dnr:0
[2025-03-27 15:51:31.688292] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280580 entering state 7
[2025-03-27 15:51:31.688302] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280580 entering state 8
[2025-03-27 15:51:31.688311] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280580 entering state 10
[2025-03-27 15:51:31.688321] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280580 entering state 11
[2025-03-27 15:51:31.688330] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280580 entering state 11
[2025-03-27 15:51:31.688349] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280580 entering state 13
[2025-03-27 15:51:31.688360] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280580 entering state 0
[2025-03-27 15:51:31.688373] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280580 entering state 1
[2025-03-27 15:51:31.688384] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280580 entering state 2
[2025-03-27 15:51:31.688395] rdma.c:1504:nvmf_rdma_fill_wr_sgl: *DEBUG*: sge[0] 0x200017280a00 addr 0x200004004000, len 4096
[2025-03-27 15:51:31.688405] rdma.c:1893:nvmf_rdma_request_parse_sgl: *DEBUG*: Request 0x200017280580 took 1 buffer/s from central pool
[2025-03-27 15:51:31.688414] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280580 entering state 5
[2025-03-27 15:51:31.688428] nvme_qpair.c: 223:nvme_admin_qpair_print_command: *NOTICE*: IDENTIFY (06) qid:0 cid:8 nsid:1 cdw10:00000003 cdw11:00000000 SGL KEYED DATA BLOCK INVALIDATE KEY 0x421d21000 len:0x1000 key:0x2003e6
[2025-03-27 15:51:31.688451] ctrlr.c:3382:nvmf_ctrlr_identify: *DEBUG*: Received identify command with CNS 0x03
[2025-03-27 15:51:31.688476] nvme_qpair.c: 474:spdk_nvme_print_completion: *NOTICE*: SUCCESS (00/00) qid:0 cid:8 cdw0:0 sqhd:0000 p:0 m:0 dnr:0
[2025-03-27 15:51:31.688494] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280580 entering state 7
[2025-03-27 15:51:31.688505] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280580 entering state 8
[2025-03-27 15:51:31.688514] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280580 entering state 10
[2025-03-27 15:51:31.688524] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280580 entering state 11
[2025-03-27 15:51:31.688533] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280580 entering state 11
[2025-03-27 15:51:31.688552] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280580 entering state 13
[2025-03-27 15:51:31.688562] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280580 entering state 0
[2025-03-27 15:51:31.688606] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280580 entering state 1
[2025-03-27 15:51:31.688617] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280580 entering state 2
[2025-03-27 15:51:31.688627] rdma.c:1504:nvmf_rdma_fill_wr_sgl: *DEBUG*: sge[0] 0x200017280a00 addr 0x200004004000, len 4096
[2025-03-27 15:51:31.688636] rdma.c:1893:nvmf_rdma_request_parse_sgl: *DEBUG*: Request 0x200017280580 took 1 buffer/s from central pool
[2025-03-27 15:51:31.688645] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280580 entering state 5
[2025-03-27 15:51:31.688658] nvme_qpair.c: 223:nvme_admin_qpair_print_command: *NOTICE*: IDENTIFY (06) qid:0 cid:14 nsid:1 cdw10:00000000 cdw11:00000000 SGL KEYED DATA BLOCK INVALIDATE KEY 0x33f7b4000 len:0x1000 key:0x2003e7
[2025-03-27 15:51:31.688678] ctrlr.c:3382:nvmf_ctrlr_identify: *DEBUG*: Received identify command with CNS 0x00
[2025-03-27 15:51:31.688696] nvme_qpair.c: 474:spdk_nvme_print_completion: *NOTICE*: SUCCESS (00/00) qid:0 cid:14 cdw0:0 sqhd:0000 p:0 m:0 dnr:0
[2025-03-27 15:51:31.688716] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280580 entering state 7
[2025-03-27 15:51:31.688726] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280580 entering state 8
[2025-03-27 15:51:31.688735] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280580 entering state 10
[2025-03-27 15:51:31.688744] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280580 entering state 11
[2025-03-27 15:51:31.688755] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280580 entering state 11
[2025-03-27 15:51:31.688774] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280580 entering state 13
[2025-03-27 15:51:31.688787] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280580 entering state 0
[2025-03-27 15:51:31.689121] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280580 entering state 1
[2025-03-27 15:51:31.689130] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280580 entering state 2
[2025-03-27 15:51:31.689136] rdma.c:1504:nvmf_rdma_fill_wr_sgl: *DEBUG*: sge[0] 0x200017280a00 addr 0x200004004000, len 4096
[2025-03-27 15:51:31.689141] rdma.c:1893:nvmf_rdma_request_parse_sgl: *DEBUG*: Request 0x200017280580 took 1 buffer/s from central pool
[2025-03-27 15:51:31.689146] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280580 entering state 5
[2025-03-27 15:51:31.689155] nvme_qpair.c: 223:nvme_admin_qpair_print_command: *NOTICE*: IDENTIFY (06) qid:0 cid:15 nsid:1 cdw10:00000000 cdw11:00000000 SGL KEYED DATA BLOCK INVALIDATE KEY 0x33f7b4000 len:0x1000 key:0x2003e8
[2025-03-27 15:51:31.689179] ctrlr.c:3382:nvmf_ctrlr_identify: *DEBUG*: Received identify command with CNS 0x00
[2025-03-27 15:51:31.689196] nvme_qpair.c: 474:spdk_nvme_print_completion: *NOTICE*: SUCCESS (00/00) qid:0 cid:15 cdw0:0 sqhd:0000 p:0 m:0 dnr:0
[2025-03-27 15:51:31.689215] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280580 entering state 7
[2025-03-27 15:51:31.689225] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280580 entering state 8
[2025-03-27 15:51:31.689234] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280580 entering state 10
[2025-03-27 15:51:31.689244] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280580 entering state 11
[2025-03-27 15:51:31.689253] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280580 entering state 11
[2025-03-27 15:51:31.689271] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280580 entering state 13
[2025-03-27 15:51:31.689282] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280580 entering state 0
[2025-03-27 15:51:31.691474] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280580 entering state 1
[2025-03-27 15:51:31.691497] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280580 entering state 2
[2025-03-27 15:51:31.691508] rdma.c:1504:nvmf_rdma_fill_wr_sgl: *DEBUG*: sge[0] 0x200017280a00 addr 0x200004004000, len 4096
[2025-03-27 15:51:31.691517] rdma.c:1893:nvmf_rdma_request_parse_sgl: *DEBUG*: Request 0x200017280580 took 1 buffer/s from central pool
[2025-03-27 15:51:31.691526] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280580 entering state 5
[2025-03-27 15:51:31.691541] nvme_qpair.c: 243:nvme_io_qpair_print_command: *NOTICE*: READ sqid:3 cid:33 nsid:1 lba:0 len:8 SGL KEYED DATA BLOCK INVALIDATE KEY 0x4391c0000 len:0x1000 key:0x2223ff
[2025-03-27 15:51:31.691574] bdev_malloc.c: 383:bdev_malloc_readv: *DEBUG*: read 4096 bytes from offset 0, iovcnt=1
[2025-03-27 15:51:31.691589] accel.c: 189:accel_sequence_set_state: *DEBUG*: seq=0x55acf72af980, setting state: init -> await-virtbuf
[2025-03-27 15:51:31.691599] accel.c: 189:accel_sequence_set_state: *DEBUG*: seq=0x55acf72af980, setting state: await-virtbuf -> check-bouncebuf
[2025-03-27 15:51:31.691609] accel.c: 189:accel_sequence_set_state: *DEBUG*: seq=0x55acf72af980, setting state: check-bouncebuf -> await-bouncebuf
[2025-03-27 15:51:31.691618] accel.c: 189:accel_sequence_set_state: *DEBUG*: seq=0x55acf72af980, setting state: await-bouncebuf -> exec-task
[2025-03-27 15:51:31.691628] accel.c:2291:accel_process_sequence: *DEBUG*: Executing copy operation, sequence: 0x55acf72af980
[2025-03-27 15:51:31.691637] accel.c: 189:accel_sequence_set_state: *DEBUG*: seq=0x55acf72af980, setting state: exec-task -> await-task
[2025-03-27 15:51:31.691651] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280580 entering state 6
[2025-03-27 15:51:31.691665] accel.c: 189:accel_sequence_set_state: *DEBUG*: seq=0x55acf72af980, setting state: await-task -> complete-task
[2025-03-27 15:51:31.691676] accel.c: 189:accel_sequence_set_state: *DEBUG*: seq=0x55acf72af980, setting state: complete-task -> next-task
[2025-03-27 15:51:31.691686] accel.c:1844:accel_sequence_complete: *DEBUG*: Completed sequence: 0x55acf72af980 with status: 0
[2025-03-27 15:51:31.691701] nvme_qpair.c: 474:spdk_nvme_print_completion: *NOTICE*: SUCCESS (00/00) qid:3 cid:33 cdw0:0 sqhd:0000 p:0 m:0 dnr:0
[2025-03-27 15:51:31.691724] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280580 entering state 7
[2025-03-27 15:51:31.691735] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280580 entering state 8
[2025-03-27 15:51:31.691744] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280580 entering state 10
[2025-03-27 15:51:31.691754] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280580 entering state 11
[2025-03-27 15:51:31.691774] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280580 entering state 13
[2025-03-27 15:51:31.691786] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280580 entering state 0
[2025-03-27 15:51:31.691853] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280580 entering state 1
[2025-03-27 15:51:31.691865] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280580 entering state 2
[2025-03-27 15:51:31.691877] rdma.c:1504:nvmf_rdma_fill_wr_sgl: *DEBUG*: sge[0] 0x200017280a00 addr 0x200004004000, len 4096
[2025-03-27 15:51:31.691887] rdma.c:1893:nvmf_rdma_request_parse_sgl: *DEBUG*: Request 0x200017280580 took 1 buffer/s from central pool
[2025-03-27 15:51:31.691896] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280580 entering state 5
[2025-03-27 15:51:31.691909] nvme_qpair.c: 243:nvme_io_qpair_print_command: *NOTICE*: READ sqid:3 cid:34 nsid:1 lba:8 len:8 SGL KEYED DATA BLOCK INVALIDATE KEY 0x4391c1000 len:0x1000 key:0x222300
[2025-03-27 15:51:31.691935] bdev_malloc.c: 383:bdev_malloc_readv: *DEBUG*: read 4096 bytes from offset 0x1000, iovcnt=1
[2025-03-27 15:51:31.691947] accel.c: 189:accel_sequence_set_state: *DEBUG*: seq=0x55acf72af980, setting state: init -> await-virtbuf
[2025-03-27 15:51:31.691957] accel.c: 189:accel_sequence_set_state: *DEBUG*: seq=0x55acf72af980, setting state: await-virtbuf -> check-bouncebuf
[2025-03-27 15:51:31.691966] accel.c: 189:accel_sequence_set_state: *DEBUG*: seq=0x55acf72af980, setting state: check-bouncebuf -> await-bouncebuf
[2025-03-27 15:51:31.691975] accel.c: 189:accel_sequence_set_state: *DEBUG*: seq=0x55acf72af980, setting state: await-bouncebuf -> exec-task
[2025-03-27 15:51:31.691984] accel.c:2291:accel_process_sequence: *DEBUG*: Executing copy operation, sequence: 0x55acf72af980
[2025-03-27 15:51:31.691993] accel.c: 189:accel_sequence_set_state: *DEBUG*: seq=0x55acf72af980, setting state: exec-task -> await-task
[2025-03-27 15:51:31.692004] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280580 entering state 6
[2025-03-27 15:51:31.692016] accel.c: 189:accel_sequence_set_state: *DEBUG*: seq=0x55acf72af980, setting state: await-task -> complete-task
[2025-03-27 15:51:31.692026] accel.c: 189:accel_sequence_set_state: *DEBUG*: seq=0x55acf72af980, setting state: complete-task -> next-task
[2025-03-27 15:51:31.692036] accel.c:1844:accel_sequence_complete: *DEBUG*: Completed sequence: 0x55acf72af980 with status: 0
[2025-03-27 15:51:31.692049] nvme_qpair.c: 474:spdk_nvme_print_completion: *NOTICE*: SUCCESS (00/00) qid:3 cid:34 cdw0:0 sqhd:0000 p:0 m:0 dnr:0
[2025-03-27 15:51:31.692070] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280580 entering state 7
[2025-03-27 15:51:31.692081] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280580 entering state 8
[2025-03-27 15:51:31.692091] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280580 entering state 10
[2025-03-27 15:51:31.692100] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280580 entering state 11
[2025-03-27 15:51:31.692120] rdma.c:2143:nvmf_rdma_request_process: *DEBUG*: Request 0x200017280580 entering state 13






==================================== I端: ====================================
root@hpc118:~# nvme discover -t rdma -a 192.168.1.117 -s 4520

Discovery Log Number of Records 1, Generation counter 1
=====Discovery Log Entry 0======
trtype:  rdma
adrfam:  ipv4
subtype: nvme subsystem
treq:    not required
portid:  0
trsvcid: 4520
subnqn:  nqn.2022-06.io.spdk:cnode216
traddr:  192.168.1.117
rdma_prtype: not specified
rdma_qptype: connected
rdma_cms:    rdma-cm
rdma_pkey: 0x0000

connect:
nvme connect -t rdma -n "nqn.2022-06.io.spdk:cnode216" -a 192.168.1.117 -s 4520

lsblk:
nvme1n1     259:4    0     1G  0 disk

fdisk -l
Disk /dev/nvme1n1: 1 GiB, 1073741824 bytes, 2097152 sectors
Disk model: SPDK_Controll                           
Units: sectors of 1 * 512 = 512 bytes
Sector size (logical/physical): 512 bytes / 512 bytes
I/O size (minimum/optimal): 512 bytes / 131072 bytes


