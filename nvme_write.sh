# nvme write /dev/nvme0n1 -s 0 -c 10 -z 40980 -d examples.desktop
# dd if=/dev/urandom of=4k bs=4k count=1
rm -rf 4k; for i in {0..4095};do printf a >> 4k;done; stat 4k
# gdb --args ./nvme write /dev/nvme2n1 --start-block=0 --block-count=1 --data-size=4k --data=./4k -v
nvme write /dev/nvme2n1 --start-block=0 --block-count=1 --data-size=4k --data=./4k -v

