HUGEMEM=4096 scripts/setup.sh
build/bin/vhost -S /var/tmp -m 0x3

gdb --args build/bin/vhost -S /var/tmp -m 0x3

./scripts/rpc.py bdev_malloc_create 128 4096 -b Malloc0
# gernerate /var/tmp/vhost.0
./scripts/rpc.py vhost_create_scsi_controller --cpumask 0x1 vhost.0
./scripts/rpc.py vhost_scsi_controller_add_target vhost.0 1 Malloc0


# blk device
scripts/rpc.py bdev_malloc_create 64 512 -b Malloc0
scripts/rpc.py vhost_create_blk_controller --cpumask 0x1 vhost.1 Malloc0

# start qemu:
root@host101:~/xb/project/virt/qemu/build# ./qemu-system-x86_64     -machine accel=kvm     -m 4096M -object  memory-backend-file,id=mem,size=4096M,mem-path=/dev/hugepages,share=on,prealloc=yes  -numa node,memdev=mem     -drive file=/root/big/qemu/ubuntu-20.qcow2,if=none,id=disk     -device ide-hd,drive=disk,bootindex=0     -chardev socket,id=char0,reconnect=1,path=/var/tmp/vhost.1     -device vhost-user-blk-pci,packed=on,chardev=char0,num-queues=1     -nic user,hostfwd=tcp::60022-:22     -vnc :75



qemu:
/root/project/virt/qemu/build/qemu-system-x86_64 -m 4096 -enable-kvm -cpu host -smp cores=8,sockets=1 -drive file=/root/big/qemu/ubuntu20.qcow2,if=virtio -nic user,hostfwd=tcp::2222-:22 -fsdev local,security_model=passthrough,id=fsdev0,path=/root/project/linux/v5.15/linux -device virtio-9p-pci,fsdev=fsdev0,mount_tag=kernelmake -device usb-ehci,id=usb,bus=pci.0,addr=0x8 -device usb-tablet -vnc :75


taskset -c 2,3 qemu-system-x86_64 \
  --enable-kvm \
  -cpu host -smp 2 \
  -m 1G -object memory-backend-file,id=mem0,size=1G,mem-path=/dev/hugepages,share=on -numa node,memdev=mem0 \
  -drive file=guest_os_image.qcow2,if=none,id=disk \
  -device ide-hd,drive=disk,bootindex=0 \
  -chardev socket,id=spdk_vhost_scsi0,path=/var/tmp/vhost.0 \
  -device vhost-user-scsi-pci,id=scsi0,chardev=spdk_vhost_scsi0,num_queues=2 \
  -chardev socket,id=spdk_vhost_blk0,path=/var/tmp/vhost.1 \
  -device vhost-user-blk-pci,chardev=spdk_vhost_blk0,num-queues=2




log:

[2024-07-06 14:42:06.617938] Starting SPDK v23.09-pre git sha1 4f9b46d7d / DPDK 22.07.0 initialization...
[2024-07-06 14:42:06.618134] [ DPDK EAL parameters: vhost --no-shconf -c 0x3 --huge-unlink --log-level=lib.eal:6 --log-level=lib.cryptodev:5 --log-level=user1:6 --iova-mode=pa --base-virtaddr=0x200000000000 --match-allocations --file-prefix=spdk_pid106081 ]
TELEMETRY: No legacy callbacks, legacy socket not created
[2024-07-06 14:42:56.680563] app.c: 767:spdk_app_start: *NOTICE*: Total cores available: 2
[2024-07-06 14:43:16.826317] reactor.c: 937:reactor_run: *NOTICE*: Reactor started on core 1
[2024-07-06 14:43:16.826328] reactor.c: 937:reactor_run: *NOTICE*: Reactor started on core 0
[2024-07-06 14:43:16.853920] accel_sw.c: 605:sw_accel_module_init: *NOTICE*: Accel framework software module initialized.
VHOST_CONFIG: (/var/tmp/vhost.0) logging feature is disabled in async copy mode
VHOST_CONFIG: (/var/tmp/vhost.0) vhost-user server: socket created, fd: 235
VHOST_CONFIG: (/var/tmp/vhost.0) binding succeeded
VHOST_CONFIG: (/var/tmp/vhost.0) new vhost user connection is 234
VHOST_CONFIG: (/var/tmp/vhost.0) new device, handle is 0
VHOST_CONFIG: (/var/tmp/vhost.0) read message VHOST_USER_GET_FEATURES
VHOST_CONFIG: (/var/tmp/vhost.0) read message VHOST_USER_GET_PROTOCOL_FEATURES
VHOST_CONFIG: (/var/tmp/vhost.0) read message VHOST_USER_SET_PROTOCOL_FEATURES
VHOST_CONFIG: (/var/tmp/vhost.0) negotiated Vhost-user protocol features: 0x11cbf
VHOST_CONFIG: (/var/tmp/vhost.0) read message VHOST_USER_GET_QUEUE_NUM
VHOST_CONFIG: (/var/tmp/vhost.0) read message VHOST_USER_SET_SLAVE_REQ_FD
VHOST_CONFIG: (/var/tmp/vhost.0) read message VHOST_USER_SET_OWNER
VHOST_CONFIG: (/var/tmp/vhost.0) read message VHOST_USER_GET_FEATURES
VHOST_CONFIG: (/var/tmp/vhost.0) read message VHOST_USER_SET_VRING_CALL
VHOST_CONFIG: (/var/tmp/vhost.0) vring call idx:0 file:305
VHOST_CONFIG: (/var/tmp/vhost.0) read message VHOST_USER_SET_VRING_ERR
VHOST_CONFIG: (/var/tmp/vhost.0) not implemented
VHOST_CONFIG: (/var/tmp/vhost.0) read message VHOST_USER_SET_VRING_CALL
VHOST_CONFIG: (/var/tmp/vhost.0) vring call idx:1 file:306
VHOST_CONFIG: (/var/tmp/vhost.0) read message VHOST_USER_SET_VRING_ERR
VHOST_CONFIG: (/var/tmp/vhost.0) not implemented
VHOST_CONFIG: (/var/tmp/vhost.0) read message VHOST_USER_SET_VRING_CALL
VHOST_CONFIG: (/var/tmp/vhost.0) vring call idx:2 file:307
VHOST_CONFIG: (/var/tmp/vhost.0) read message VHOST_USER_SET_VRING_ERR
VHOST_CONFIG: (/var/tmp/vhost.0) not implemented
VHOST_CONFIG: (/var/tmp/vhost.0) read message VHOST_USER_SET_VRING_CALL
VHOST_CONFIG: (/var/tmp/vhost.0) vring call idx:3 file:308
VHOST_CONFIG: (/var/tmp/vhost.0) read message VHOST_USER_SET_VRING_ERR
VHOST_CONFIG: (/var/tmp/vhost.0) not implemented
VHOST_CONFIG: (/var/tmp/vhost.0) read message VHOST_USER_SET_FEATURES
VHOST_CONFIG: (/var/tmp/vhost.0) negotiated Virtio features: 0x140000000
VHOST_CONFIG: (/var/tmp/vhost.0) read message VHOST_USER_GET_STATUS
VHOST_CONFIG: (/var/tmp/vhost.0) read message VHOST_USER_SET_STATUS
VHOST_CONFIG: (/var/tmp/vhost.0) new device status(0x00000008):
VHOST_CONFIG: (/var/tmp/vhost.0)        -RESET: 0
VHOST_CONFIG: (/var/tmp/vhost.0)        -ACKNOWLEDGE: 0
VHOST_CONFIG: (/var/tmp/vhost.0)        -DRIVER: 0
VHOST_CONFIG: (/var/tmp/vhost.0)        -FEATURES_OK: 1
VHOST_CONFIG: (/var/tmp/vhost.0)        -DRIVER_OK: 0
VHOST_CONFIG: (/var/tmp/vhost.0)        -DEVICE_NEED_RESET: 0
VHOST_CONFIG: (/var/tmp/vhost.0)        -FAILED: 0
VHOST_CONFIG: (/var/tmp/vhost.0) read message VHOST_USER_GET_INFLIGHT_FD
VHOST_CONFIG: (/var/tmp/vhost.0) get_inflight_fd num_queues: 4
VHOST_CONFIG: (/var/tmp/vhost.0) get_inflight_fd queue_size: 128
VHOST_CONFIG: (/var/tmp/vhost.0) send inflight mmap_size: 8448
VHOST_CONFIG: (/var/tmp/vhost.0) send inflight mmap_offset: 0
VHOST_CONFIG: (/var/tmp/vhost.0) send inflight fd: 309
VHOST_CONFIG: (/var/tmp/vhost.0) read message VHOST_USER_SET_INFLIGHT_FD
VHOST_CONFIG: (/var/tmp/vhost.0) set_inflight_fd mmap_size: 8448
VHOST_CONFIG: (/var/tmp/vhost.0) set_inflight_fd mmap_offset: 0
VHOST_CONFIG: (/var/tmp/vhost.0) set_inflight_fd num_queues: 4
VHOST_CONFIG: (/var/tmp/vhost.0) set_inflight_fd queue_size: 128
VHOST_CONFIG: (/var/tmp/vhost.0) set_inflight_fd fd: 310
VHOST_CONFIG: (/var/tmp/vhost.0) set_inflight_fd pervq_inflight_size: 2112
VHOST_CONFIG: (/var/tmp/vhost.0) read message VHOST_USER_SET_FEATURES
VHOST_CONFIG: (/var/tmp/vhost.0) negotiated Virtio features: 0x140000000
VHOST_CONFIG: (/var/tmp/vhost.0) read message VHOST_USER_GET_STATUS
VHOST_CONFIG: (/var/tmp/vhost.0) read message VHOST_USER_SET_MEM_TABLE
VHOST_CONFIG: (/var/tmp/vhost.0) guest memory region size: 0x40000000
VHOST_CONFIG: (/var/tmp/vhost.0)         guest physical addr: 0x0
VHOST_CONFIG: (/var/tmp/vhost.0)         guest virtual  addr: 0x7fa58be00000
VHOST_CONFIG: (/var/tmp/vhost.0)         host  virtual  addr: 0x7fffa8000000
VHOST_CONFIG: (/var/tmp/vhost.0)         mmap addr : 0x7fffa8000000
VHOST_CONFIG: (/var/tmp/vhost.0)         mmap size : 0x40000000
VHOST_CONFIG: (/var/tmp/vhost.0)         mmap align: 0x200000
VHOST_CONFIG: (/var/tmp/vhost.0)         mmap off  : 0x0
EAL: VFIO support not initialized
EAL: Couldn't map new region for DMA
VHOST_CONFIG: (/var/tmp/vhost.0) read message VHOST_USER_SET_VRING_NUM
VHOST_CONFIG: (/var/tmp/vhost.0) read message VHOST_USER_SET_VRING_BASE
VHOST_CONFIG: (/var/tmp/vhost.0) vring base idx:2 last_used_idx:0 last_avail_idx:0.
VHOST_CONFIG: (/var/tmp/vhost.0) read message VHOST_USER_SET_VRING_ADDR
VHOST_CONFIG: (/var/tmp/vhost.0) read message VHOST_USER_SET_VRING_KICK
VHOST_CONFIG: (/var/tmp/vhost.0) vring kick idx:2 file:311
VHOST_CONFIG: (/var/tmp/vhost.0) read message VHOST_USER_SET_VRING_ENABLE
VHOST_CONFIG: (/var/tmp/vhost.0) set queue enable: 1 to qp idx: 0
VHOST_CONFIG: (/var/tmp/vhost.0) read message VHOST_USER_SET_VRING_ENABLE
VHOST_CONFIG: (/var/tmp/vhost.0) set queue enable: 1 to qp idx: 1
VHOST_CONFIG: (/var/tmp/vhost.0) read message VHOST_USER_SET_VRING_ENABLE
VHOST_CONFIG: (/var/tmp/vhost.0) set queue enable: 1 to qp idx: 2
VHOST_CONFIG: (/var/tmp/vhost.0) read message VHOST_USER_SET_VRING_ENABLE
VHOST_CONFIG: (/var/tmp/vhost.0) set queue enable: 1 to qp idx: 3
VHOST_CONFIG: (/var/tmp/vhost.0) read message VHOST_USER_SET_VRING_CALL
VHOST_CONFIG: (/var/tmp/vhost.0) vring call idx:0 file:312
VHOST_CONFIG: (/var/tmp/vhost.0) read message VHOST_USER_SET_VRING_CALL
VHOST_CONFIG: (/var/tmp/vhost.0) vring call idx:1 file:305
VHOST_CONFIG: (/var/tmp/vhost.0) read message VHOST_USER_SET_VRING_CALL
VHOST_CONFIG: (/var/tmp/vhost.0) vring call idx:2 file:306
VHOST_CONFIG: (/var/tmp/vhost.0) read message VHOST_USER_SET_VRING_CALL
VHOST_CONFIG: (/var/tmp/vhost.0) vring call idx:3 file:307
VHOST_CONFIG: (/var/tmp/vhost.0) read message VHOST_USER_SET_VRING_ENABLE
VHOST_CONFIG: (/var/tmp/vhost.0) set queue enable: 0 to qp idx: 0
VHOST_CONFIG: (/var/tmp/vhost.0) read message VHOST_USER_SET_VRING_ENABLE
VHOST_CONFIG: (/var/tmp/vhost.0) set queue enable: 0 to qp idx: 1
VHOST_CONFIG: (/var/tmp/vhost.0) read message VHOST_USER_SET_VRING_ENABLE
VHOST_CONFIG: (/var/tmp/vhost.0) set queue enable: 0 to qp idx: 2
VHOST_CONFIG: (/var/tmp/vhost.0) read message VHOST_USER_SET_VRING_ENABLE
VHOST_CONFIG: (/var/tmp/vhost.0) set queue enable: 0 to qp idx: 3
VHOST_CONFIG: (/var/tmp/vhost.0) read message VHOST_USER_GET_VRING_BASE
VHOST_CONFIG: (/var/tmp/vhost.0) vring base idx:2 file:259
VHOST_CONFIG: (/var/tmp/vhost.0) read message VHOST_USER_SET_FEATURES
VHOST_CONFIG: (/var/tmp/vhost.0) negotiated Virtio features: 0x150000006
VHOST_CONFIG: (/var/tmp/vhost.0) read message VHOST_USER_GET_STATUS
VHOST_CONFIG: (/var/tmp/vhost.0) read message VHOST_USER_GET_INFLIGHT_FD
VHOST_CONFIG: (/var/tmp/vhost.0) get_inflight_fd num_queues: 4
VHOST_CONFIG: (/var/tmp/vhost.0) get_inflight_fd queue_size: 128
VHOST_CONFIG: (/var/tmp/vhost.0) send inflight mmap_size: 8448
VHOST_CONFIG: (/var/tmp/vhost.0) send inflight mmap_offset: 0
VHOST_CONFIG: (/var/tmp/vhost.0) send inflight fd: 306
VHOST_CONFIG: (/var/tmp/vhost.0) read message VHOST_USER_SET_INFLIGHT_FD
VHOST_CONFIG: (/var/tmp/vhost.0) set_inflight_fd mmap_size: 8448
VHOST_CONFIG: (/var/tmp/vhost.0) set_inflight_fd mmap_offset: 0
VHOST_CONFIG: (/var/tmp/vhost.0) set_inflight_fd num_queues: 4
VHOST_CONFIG: (/var/tmp/vhost.0) set_inflight_fd queue_size: 128
VHOST_CONFIG: (/var/tmp/vhost.0) set_inflight_fd fd: 308
VHOST_CONFIG: (/var/tmp/vhost.0) set_inflight_fd pervq_inflight_size: 2112
VHOST_CONFIG: (/var/tmp/vhost.0) read message VHOST_USER_SET_FEATURES
VHOST_CONFIG: (/var/tmp/vhost.0) negotiated Virtio features: 0x150000006
VHOST_CONFIG: (/var/tmp/vhost.0) read message VHOST_USER_GET_STATUS
VHOST_CONFIG: (/var/tmp/vhost.0) read message VHOST_USER_SET_MEM_TABLE
VHOST_CONFIG: (/var/tmp/vhost.0) memory regions not changed
VHOST_CONFIG: (/var/tmp/vhost.0) read message VHOST_USER_SET_VRING_NUM
VHOST_CONFIG: (/var/tmp/vhost.0) read message VHOST_USER_SET_VRING_BASE
VHOST_CONFIG: (/var/tmp/vhost.0) vring base idx:0 last_used_idx:0 last_avail_idx:0.
VHOST_CONFIG: (/var/tmp/vhost.0) read message VHOST_USER_SET_VRING_ADDR
VHOST_CONFIG: (/var/tmp/vhost.0) read message VHOST_USER_SET_VRING_KICK
VHOST_CONFIG: (/var/tmp/vhost.0) vring kick idx:0 file:306
VHOST_CONFIG: (/var/tmp/vhost.0) read message VHOST_USER_SET_VRING_NUM
VHOST_CONFIG: (/var/tmp/vhost.0) read message VHOST_USER_SET_VRING_BASE
VHOST_CONFIG: (/var/tmp/vhost.0) vring base idx:1 last_used_idx:0 last_avail_idx:0.
VHOST_CONFIG: (/var/tmp/vhost.0) read message VHOST_USER_SET_VRING_ADDR
VHOST_CONFIG: (/var/tmp/vhost.0) read message VHOST_USER_SET_VRING_KICK
VHOST_CONFIG: (/var/tmp/vhost.0) vring kick idx:1 file:310
VHOST_CONFIG: (/var/tmp/vhost.0) read message VHOST_USER_SET_VRING_NUM
VHOST_CONFIG: (/var/tmp/vhost.0) read message VHOST_USER_SET_VRING_BASE
VHOST_CONFIG: (/var/tmp/vhost.0) vring base idx:2 last_used_idx:0 last_avail_idx:0.
VHOST_CONFIG: (/var/tmp/vhost.0) read message VHOST_USER_SET_VRING_ADDR
VHOST_CONFIG: (/var/tmp/vhost.0) read message VHOST_USER_SET_VRING_KICK
VHOST_CONFIG: (/var/tmp/vhost.0) vring kick idx:2 file:311
VHOST_CONFIG: (/var/tmp/vhost.0) read message VHOST_USER_SET_VRING_NUM
VHOST_CONFIG: (/var/tmp/vhost.0) read message VHOST_USER_SET_VRING_BASE
VHOST_CONFIG: (/var/tmp/vhost.0) vring base idx:3 last_used_idx:0 last_avail_idx:0.
VHOST_CONFIG: (/var/tmp/vhost.0) read message VHOST_USER_SET_VRING_ADDR
VHOST_CONFIG: (/var/tmp/vhost.0) read message VHOST_USER_SET_VRING_KICK
VHOST_CONFIG: (/var/tmp/vhost.0) vring kick idx:3 file:313
VHOST_CONFIG: (/var/tmp/vhost.0) read message VHOST_USER_SET_VRING_ENABLE
VHOST_CONFIG: (/var/tmp/vhost.0) set queue enable: 1 to qp idx: 0
VHOST_CONFIG: (/var/tmp/vhost.0) read message VHOST_USER_SET_VRING_ENABLE
VHOST_CONFIG: (/var/tmp/vhost.0) set queue enable: 1 to qp idx: 1
VHOST_CONFIG: (/var/tmp/vhost.0) read message VHOST_USER_SET_VRING_ENABLE
VHOST_CONFIG: (/var/tmp/vhost.0) set queue enable: 1 to qp idx: 2
VHOST_CONFIG: (/var/tmp/vhost.0) read message VHOST_USER_SET_VRING_ENABLE
VHOST_CONFIG: (/var/tmp/vhost.0) set queue enable: 1 to qp idx: 3
VHOST_CONFIG: (/var/tmp/vhost.0) read message VHOST_USER_SET_VRING_CALL
VHOST_CONFIG: (/var/tmp/vhost.0) vring call idx:0 file:314
VHOST_CONFIG: (/var/tmp/vhost.0) read message VHOST_USER_SET_VRING_CALL
VHOST_CONFIG: (/var/tmp/vhost.0) vring call idx:1 file:312
VHOST_CONFIG: (/var/tmp/vhost.0) read message VHOST_USER_SET_VRING_CALL
VHOST_CONFIG: (/var/tmp/vhost.0) vring call idx:2 file:305
VHOST_CONFIG: (/var/tmp/vhost.0) read message VHOST_USER_SET_VRING_CALL
VHOST_CONFIG: (/var/tmp/vhost.0) vring call idx:3 file:315


