# NVMe over Fabrics Target {#nvmf}

@sa @ref nvme_fabrics_host
@sa @ref nvmf_tgt_tracepoints

## NVMe-oF Target Getting Started Guide {#nvmf_getting_started}

The SPDK NVMe over Fabrics target is a user space application that presents block devices over a fabrics
such as Ethernet, Infiniband or Fibre Channel. SPDK currently supports RDMA and TCP transports.  
SPDK NVMe over Fabrics 目标是一个用户空间应用程序，它通过以太网、Infiniband 或光纤通道等结构提供块设备。 SPDK 目前支持 RDMA 和 TCP 传输。

The NVMe over Fabrics specification defines subsystems that can be exported over different transports.
SPDK has chosen to call the software that exports these subsystems a "target", which is the term used
for iSCSI. The specification refers to the "client" that connects to the target as a "host". Many
people will also refer to the host as an "initiator", which is the equivalent thing in iSCSI
parlance. SPDK will try to stick to the terms "target" and "host" to match the specification.  
NVMe over Fabrics 规范定义了可以通过不同传输方式导出的子系统。 SPDK 选择将导出这些子系统的软件称为“目标”，这是用于 iSCSI 的术语。 该规范将连接到目标的“客户端”称为“主机”。 许多人还会将主机称为“启动器”，这相当于 iSCSI 的说法。 SPDK 将尝试坚持术语“目标”和“主机”以匹配规范。

The Linux kernel also implements an NVMe-oF target and host, and SPDK is tested for
interoperability with the Linux kernel implementations.  
Linux 内核还实现了 NVMe-oF 目标和主机，并且测试了 SPDK 与 Linux 内核实现的互操作性。

If you want to kill the application using signal, make sure use the SIGTERM, then the application
will release all the share memory resource before exit, the SIGKILL will make the share memory
resource have no chance to be released by application, you may need to release the resource manually.  
如果要使用信号杀死应用程序，请确保使用 SIGTERM，然后应用程序将在退出前释放所有共享内存资源，SIGKILL 将使共享内存资源没有机会被应用程序释放，您可能需要 手动释放资源。

## RDMA transport support {#nvmf_rdma_transport}

It requires an RDMA-capable NIC with its corresponding OFED (OpenFabrics Enterprise Distribution)
software package installed to run. Maybe OS distributions provide packages, but OFED is also
available [here](https://downloads.openfabrics.org/OFED/).  
它需要一个支持 RDMA 的 NIC 及其相应的 OFED (OpenFabrics Enterprise Distribution) 软件包才能运行。 也许操作系统发行版提供了软件包，但 OFED 也可以在这里获得。

### Prerequisites {#nvmf_prereqs}

To build nvmf_tgt with the RDMA transport, there are some additional dependencies,
which can be install using pkgdep.sh script.  
要使用 RDMA 传输构建 nvmf_tgt，还有一些额外的依赖项，可以使用 pkgdep.sh 脚本安装。

~~~{.sh}
sudo scripts/pkgdep.sh --rdma
~~~

Then build SPDK with RDMA enabled:

~~~{.sh}
./configure --with-rdma <other config parameters>
make
~~~

Once built, the binary will be in `build/bin`.

### Prerequisites for InfiniBand/RDMA Verbs {#nvmf_prereqs_verbs}

Before starting our NVMe-oF target with the RDMA transport we must load the InfiniBand and RDMA modules
that allow userspace processes to use InfiniBand/RDMA verbs directly.  
在使用 RDMA 传输启动我们的 NVMe-oF 目标之前，我们必须加载允许用户空间进程直接使用 InfiniBand/RDMA 动词的 InfiniBand 和 RDMA 模块。

~~~{.sh}
modprobe ib_cm
modprobe ib_core
# Please note that ib_ucm does not exist in newer versions of the kernel and is not required.
modprobe ib_ucm || true
modprobe ib_umad
modprobe ib_uverbs
modprobe iw_cm
modprobe rdma_cm
modprobe rdma_ucm
~~~

### Prerequisites for RDMA NICs {#nvmf_prereqs_rdma_nics}

Before starting our NVMe-oF target we must detect RDMA NICs and assign them IP addresses.

### Finding RDMA NICs and associated network interfaces

~~~{.sh}
ls /sys/class/infiniband/*/device/net
~~~

#### Mellanox ConnectX-3 RDMA NICs

~~~{.sh}
modprobe mlx4_core
modprobe mlx4_ib
modprobe mlx4_en
~~~

#### Mellanox ConnectX-4 RDMA NICs

~~~{.sh}
modprobe mlx5_core
modprobe mlx5_ib
~~~

#### Assigning IP addresses to RDMA NICs

~~~{.sh}
ifconfig eth1 192.168.100.8 netmask 255.255.255.0 up
ifconfig eth2 192.168.100.9 netmask 255.255.255.0 up
~~~

### RDMA Limitations {#nvmf_rdma_limitations}

As RDMA NICs put a limitation on the number of memory regions registered, the SPDK NVMe-oF
target application may eventually start failing to allocate more DMA-able memory. This is
an imperfection of the DPDK dynamic memory management and is most likely to occur with too
many 2MB hugepages reserved at runtime. One type of memory bottleneck is the number of NIC memory
regions, e.g., some NICs report as many as 2048 for the maximum number of memory regions. This
gives us a 4GB memory limit with 2MB hugepages for the total memory regions. It can be overcome by
using 1GB hugepages or by pre-reserving memory at application startup with `--mem-size` or `-s`
option. All pre-reserved memory will be registered as a single region, but won't be returned to the
system until the SPDK application is terminated.  
由于 RDMA NIC 限制了注册的内存区域数量，SPDK NVMe-oF 目标应用程序最终可能无法分配更多 DMA 内存。 这是 DPDK 动态内存管理的一个缺陷，最有可能在运行时保留太多 2MB 大页面时发生。 一种内存瓶颈是 NIC 内存区域的数量，例如，某些 NIC 报告的最大内存区域数量高达 2048。 这给了我们 4GB 的内存限制，总内存区域有 2MB 的大页面。 它可以通过使用 1GB 大页面或在应用程序启动时使用 --mem-size 或 -s 选项预留内存来克服。 所有预留的内存将被注册为一个区域，但在 SPDK 应用程序终止之前不会返回给系统。

Another known issue occurs when using the E810 NICs in RoCE mode. Specifically, the NVMe-oF target
sometimes cannot destroy a qpair, because its posted work requests don't get flushed.  It can cause
the NVMe-oF target application unable to terminate cleanly. 
在 RoCE 模式下使用 E810 NIC 时会出现另一个已知问题。 具体来说，NVMe-oF 目标有时无法销毁 qpair，因为它发布的工作请求不会被刷新。 它会导致 NVMe-oF 目标应用程序无法正常终止。

## TCP transport support {#nvmf_tcp_transport}

The transport is built into the nvmf_tgt by default, and it does not need any special libraries.

## FC transport support {#nvmf_fc_transport}

To build nvmf_tgt with the FC transport, there is an additional FC LLD (Low Level Driver) code dependency.
Please contact your FC vendor for instructions to obtain FC driver module.  
要使用 FC 传输构建 nvmf_tgt，需要额外的 FC LLD（低级驱动程序）代码依赖性。 请联系您的 FC 供应商以获取获取 FC 驱动程序模块的说明。

### Broadcom FC LLD code

FC LLD driver for Broadcom FC NVMe capable adapters can be obtained from,
https://github.com/ecdufcdrvr/bcmufctdrvr.

### Fetch FC LLD module and then build SPDK with FC enabled

After cloning SPDK repo and initialize submodules, FC LLD library is built which then can be linked with
the fc transport.

~~~{.sh}
git clone https://github.com/spdk/spdk --recursive
git clone https://github.com/ecdufcdrvr/bcmufctdrvr fc
cd fc
make DPDK_DIR=../spdk/dpdk/build SPDK_DIR=../spdk
cd ../spdk
./configure --with-fc=../fc/build
make
~~~

## Configuring the SPDK NVMe over Fabrics Target {#nvmf_config}

An NVMe over Fabrics target can be configured using JSON RPCs.
The basic RPCs needed to configure the NVMe-oF subsystem are detailed below. More information about
working with NVMe over Fabrics specific RPCs can be found on the @ref jsonrpc_components_nvmf_tgt RPC page. 
可以使用 JSON RPC 配置 NVMe over Fabrics 目标。 下面详细介绍了配置 NVMe-oF 子系统所需的基本 RPC。 有关使用 NVMe over Fabrics 特定 RPC 的更多信息，请参见 NVMe-oF 目标 RPC 页面。

### Using RPCs {#nvmf_config_rpc}

Start the nvmf_tgt application with elevated privileges. Once the target is started,
the nvmf_create_transport rpc can be used to initialize a given transport. Below is an
example where the target is started and configured with two different transports.
The RDMA transport is configured with an I/O unit size of 8192 bytes, max I/O size 131072 and an
in capsule data size of 8192 bytes. The TCP transport is configured with an I/O unit size of
16384 bytes, 8 max qpairs per controller, and an in capsule data size of 8192 bytes. 
使用提升的权限启动 nvmf_tgt 应用程序。 启动目标后，nvmf_create_transport rpc 可用于初始化给定的传输。 下面是一个示例，其中目标启动并配置了两种不同的传输。 RDMA 传输配置有 8192 字节的 I/O 单元大小、最大 I/O 大小 131072 和 8192 字节的封装数据大小。 TCP 传输配置了 16384 字节的 I/O 单元大小，每个控制器最多 8 个 qpairs，以及 8192 字节的封装数据大小。

~~~{.sh}
build/bin/nvmf_tgt
scripts/rpc.py nvmf_create_transport -t RDMA -u 8192 -i 131072 -c 8192
scripts/rpc.py nvmf_create_transport -t TCP -u 16384 -m 8 -c 8192
~~~

Below is an example of creating a malloc bdev and assigning it to a subsystem. Adjust the bdevs,
NQN, serial number, and IP address with RDMA transport to your own circumstances. If you replace
"rdma" with "TCP", then the subsystem will add a listener with TCP transport.  
下面是创建 malloc bdev 并将其分配给子系统的示例。 根据您自己的情况使用 RDMA 传输调整 bdevs、NQN、序列号和 IP 地址。 如果将“rdma”替换为“TCP”，则子系统将添加一个使用 TCP 传输的侦听器。

~~~{.sh}
scripts/rpc.py bdev_malloc_create -b Malloc0 512 512
scripts/rpc.py nvmf_create_subsystem nqn.2016-06.io.spdk:cnode1 -a -s SPDK00000000000001 -d SPDK_Controller1
scripts/rpc.py nvmf_subsystem_add_ns nqn.2016-06.io.spdk:cnode1 Malloc0
scripts/rpc.py nvmf_subsystem_add_listener nqn.2016-06.io.spdk:cnode1 -t rdma -a 192.168.100.8 -s 4420
~~~

### NQN Formal Definition

NVMe qualified names or NQNs are defined in section 7.9 of the
[NVMe specification](http://nvmexpress.org/wp-content/uploads/NVM_Express_Revision_1.3.pdf). SPDK has attempted to
formalize that definition using [Extended Backus-Naur form](https://en.wikipedia.org/wiki/Extended_Backus%E2%80%93Naur_form).
SPDK modules use this formal definition (provided below) when validating NQNs. 
NVMe 限定名称或 NQN 在 NVMe 规范的第 7.9 节中定义。 SPDK 已尝试使用扩展巴科斯-诺尔形式将该定义形式化。 SPDK 模块在验证 NQN 时使用这个正式定义（在下面提供）。

~~~{.sh}

Basic Types
year = 4 * digit ;
month = '01' | '02' | '03' | '04' | '05' | '06' | '07' | '08' | '09' | '10' | '11' | '12' ;
digit = '0' | '1' | '2' | '3' | '4' | '5' | '6' | '7' | '8' | '9' ;
hex digit = 'A' | 'B' | 'C' | 'D' | 'E' | 'F' | 'a' | 'b' | 'c' | 'd' | 'e' | 'f' | '0' |
'1' | '2' | '3' | '4' | '5' | '6' | '7' | '8' | '9' ;

NQN Definition
NVMe Qualified Name = ( NVMe-oF Discovery NQN | NVMe UUID NQN | NVMe Domain NQN ), '\0' ;
NVMe-oF Discovery NQN = "nqn.2014-08.org.nvmexpress.discovery" ;
NVMe UUID NQN = "nqn.2014-08.org.nvmexpress:uuid:", string UUID ;
string UUID = 8 * hex digit, '-', 3 * (4 * hex digit, '-'), 12 * hex digit ;
NVMe Domain NQN = "nqn.", year, '-', month, '.', reverse domain, ':', utf-8 string ;

~~~

Please note that the following types from the definition above are defined elsewhere:

1. utf-8 string: Defined in [rfc 3629](https://tools.ietf.org/html/rfc3629).
2. reverse domain: Equivalent to domain name as defined in [rfc 1034](https://tools.ietf.org/html/rfc1034). 反向域：相当于 rfc 1034 中定义的域名。

While not stated in the formal definition, SPDK enforces the requirement from the spec that the
"maximum name is 223 bytes in length". SPDK does not include the null terminating character when
defining the length of an nqn, and will accept an nqn containing up to 223 valid bytes with an
additional null terminator. To be precise, SPDK follows the same conventions as the c standard
library function [strlen()](http://man7.org/linux/man-pages/man3/strlen.3.html).  
虽然没有在正式定义中说明，但 SPDK 强制执行规范中的要求，即“名称的最大长度为 223 个字节”。 SPDK 在定义 nqn 的长度时不包括空终止字符，并且将接受包含最多 223 个有效字节和附加空终止符的 nqn。 准确地说，SPDK 遵循与 c 标准库函数 strlen() 相同的约定。

#### NQN Comparisons

SPDK compares NQNs byte for byte without case matching or unicode normalization. This has specific implications for
uuid based NQNs. The following pair of NQNs, for example, would not match when compared in the SPDK NVMe-oF Target:

nqn.2014-08.org.nvmexpress:uuid:11111111-aaaa-bbdd-ffee-123456789abc
nqn.2014-08.org.nvmexpress:uuid:11111111-AAAA-BBDD-FFEE-123456789ABC

In order to ensure the consistency of uuid based NQNs while using SPDK, users should use lowercase when representing
alphabetic hex digits in their NQNs. 
SPDK 在不进行大小写匹配或 unicode 规范化的情况下逐字节比较 NQN。 这对基于 uuid 的 NQN 有特定的影响。 例如，在 SPDK NVMe-oF 目标中进行比较时，以下一对 NQN 将不匹配：

nqn.2014-08.org.nvmexpress:uuid:11111111-aaaa-bbdd-ffee-123456789abc nqn.2014-08.org.nvmexpress:uuid:11111111-AAAA-BBDD-FFEE-123456789ABC

为了保证使用SPDK时基于uuid的NQN的一致性，用户在他们的NQN中表示字母十六进制数字时应该使用小写字母。

### Assigning CPU Cores to the NVMe over Fabrics Target {#nvmf_config_lcore}

SPDK uses the [DPDK Environment Abstraction Layer](http://dpdk.org/doc/guides/prog_guide/env_abstraction_layer.html)
to gain access to hardware resources such as huge memory pages and CPU core(s). DPDK EAL provides
functions to assign threads to specific cores.
To ensure the SPDK NVMe-oF target has the best performance, configure the NICs and NVMe devices to
be located on the same NUMA node.

The `-m` core mask option specifies a bit mask of the CPU cores that
SPDK is allowed to execute work items on.
For example, to allow SPDK to use cores 24, 25, 26 and 27: 
SPDK 使用 DPDK 环境抽象层来访问硬件资源，例如巨大的内存页面和 CPU 内核。 DPDK EAL 提供了将线程分配给特定内核的功能。 为确保 SPDK NVMe-oF 目标具有最佳性能，请将 NIC 和 NVMe 设备配置为位于同一 NUMA 节点上。

-m core mask 选项指定允许 SPDK 在其上执行工作项的 CPU 核心的位掩码。 例如，要允许 SPDK 使用核心 24、25、26 和 27：
~~~{.sh}
build/bin/nvmf_tgt -m 0xF000000
~~~

## Configuring the Linux NVMe over Fabrics Host {#nvmf_host}

Both the Linux kernel and SPDK implement an NVMe over Fabrics host.
The Linux kernel NVMe-oF RDMA host support is provided by the `nvme-rdma` driver
(to support RDMA transport) and `nvme-tcp` (to support TCP transport). And the
following shows two different commands for loading the driver. 
Linux 内核和 SPDK 都实现了 NVMe over Fabrics 主机。 Linux 内核 NVMe-oF RDMA 主机支持由 nvme-rdma 驱动程序（支持 RDMA 传输）和 nvme-tcp（支持 TCP 传输）提供。 下面显示了两个不同的加载驱动程序的命令。

~~~{.sh}
modprobe nvme-rdma
modprobe nvme-tcp
~~~

The nvme-cli tool may be used to interface with the Linux kernel NVMe over Fabrics host.
See below for examples of the discover, connect and disconnect commands. In all three instances, the
transport can be changed to TCP by interchanging 'rdma' for 'tcp'.

Discovery:
~~~{.sh}
nvme discover -t rdma -a 192.168.100.8 -s 4420
~~~

Connect:
~~~{.sh}
nvme connect -t rdma -n "nqn.2016-06.io.spdk:cnode1" -a 192.168.100.8 -s 4420
~~~

Disconnect:
~~~{.sh}
nvme disconnect -n "nqn.2016-06.io.spdk:cnode1"
~~~

## Enabling NVMe-oF target tracepoints for offline analysis and debug {#nvmf_trace}

SPDK has a tracing framework for capturing low-level event information at runtime.
@ref nvmf_tgt_tracepoints enable analysis of both performance and application crashes.

## Enabling NVMe-oF Multipath

The SPDK NVMe-oF target and initiator support multiple independent paths to the same NVMe-oF subsystem.
For step-by-step instructions for configuring and switching between paths, see @ref nvmf_multipath_howto . 
SPDK NVMe-oF 目标和启动器支持到同一 NVMe-oF 子系统的多个独立路径。 有关配置和切换路径的分步说明，请参阅 NVMe-oF Multipath HOWTO 。
