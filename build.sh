# 同步master最新代码
# git fetch upstream
# git merge upstream/master
# git submodule update --init

# 配置和编译
# ./configure --disable-unit-tests --enable-debug
./config.sh && make -j32

#clear;./configure --with-daos --disable-tests --disable-unit-tests --disable-apps --without-vhost --without-crypto --without-rbd --with-rdma --without-iscsi-initiator --without-vtune --with-shared
# ./configure --with-shared

# clear;./configure --with-daos --with-rdma --enable-werror --disable-unit-tests
# clear;./configure --with-daos --with-rdma --disable-unit-tests --enable-debug
# clear;./configure --with-rdma --disable-unit-tests --enable-debug
