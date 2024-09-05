# 同步master最新代码
# git fetch upstream
# git merge upstream/master
# git submodule update --init
# apt-get install libiscsi-dev libcunit1-dev libcap-ng-dev libssl-dev libaio-dev libncurses5-dev libncursesw5-dev


# 配置和编译
# ./configure --disable-unit-tests --enable-debug 

enable iscsi_bdev:
apt-get install libiscsi-dev
./configure --disable-unit-tests --enable-debug --with-iscsi-initiator
apt install libcunit1-dev
./config.sh && make -j32

#clear;./configure --with-daos --disable-tests --disable-unit-tests --disable-apps --without-vhost --without-crypto --without-rbd --with-rdma --without-iscsi-initiator --without-vtune --with-shared
# ./configure --with-shared

# clear;./configure --with-daos --with-rdma --enable-werror --disable-unit-tests
# clear;./configure --with-daos --with-rdma --disable-unit-tests --enable-debug
# clear;./configure --with-rdma --disable-unit-tests --enable-debug
