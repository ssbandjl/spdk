# NVMe over Fabrics Target Programming Guide NVMe over Fabrics 目标编程指南 {#nvmf_tgt_pg} 

## Target Audience

This programming guide is intended for developers authoring applications that
use the SPDK NVMe-oF target library (`lib/nvmf`). It is intended to provide
background context, architectural insight, and design recommendations. This
guide will not cover how to use the SPDK NVMe-oF target application. For a
guide on how to use the existing application as-is, see @ref nvmf.
目标听众
本编程指南适用于编写使用 SPDK NVMe-oF 目标库 (lib/nvmf) 的应用程序的开发人员。 它旨在提供背景上下文、体系结构见解和设计建议。 本指南不会介绍如何使用 SPDK NVMe-oF 目标应用程序。 有关如何按原样使用现有应用程序的指南，请参阅 NVMe over Fabrics Target。

## Introduction

The SPDK NVMe-oF target library is located in `lib/nvmf`. The library
implements all logic required to create an NVMe-oF target application. It is
used in the implementation of the example NVMe-oF target application in
`app/nvmf_tgt`, but is intended to be consumed independently.
SPDK NVMe-oF 目标库位于 lib/nvmf 中。 该库实现了创建 NVMe-oF 目标应用程序所需的所有逻辑。 它用于 app/nvmf_tgt 中示例 NVMe-oF 目标应用程序的实现，但旨在独立使用。
本指南假设读者熟悉 NVMe 和 NVMe over Fabrics。 熟悉这些的最好方法是阅读它们的规范。

This guide is written assuming that the reader is familiar with both NVMe and
NVMe over Fabrics. The best way to become familiar with those is to read their
[specifications](http://nvmexpress.org/resources/specifications/).

## Primitives 基元

The library exposes a number of primitives - basic objects that the user
creates and interacts with. They are:
该库公开了许多原语——用户创建并与之交互的基本对象。 他们是：

`struct spdk_nvmf_tgt`: An NVMe-oF target. This concept, surprisingly, does
not appear in the NVMe-oF specification. SPDK defines this to mean the
collection of subsystems with the associated namespaces, plus the set of
transports and their associated network connections. This will be referred to
throughout this guide as a **target**.
NVMe-oF 目标。 令人惊讶的是，这个概念并没有出现在 NVMe-oF 规范中。 SPDK 将其定义为具有关联命名空间的子系统的集合，以及传输集及其关联的网络连接。 在本指南中，这将被称为目标。

`struct spdk_nvmf_subsystem`: An NVMe-oF subsystem, as defined by the NVMe-oF
specification. Subsystems contain namespaces and controllers and perform
access control. This will be referred to throughout this guide as a
**subsystem**.
NVMe-oF 子系统，由 NVMe-oF 规范定义。 子系统包含名称空间和控制器并执行访问控制。 这将在本指南中称为子系统

`struct spdk_nvmf_ns`: An NVMe-oF namespace, as defined by the NVMe-oF
specification. Namespaces are **bdevs**. See @ref bdev for an explanation of
the SPDK bdev layer. This will be referred to throughout this guide as a
**namespace**.
NVMe-oF 命名空间，由 NVMe-oF 规范定义。 命名空间是 bdev。 有关 SPDK bdev 层的说明，请参阅块设备用户指南。 这将在本指南中称为命名空间

`struct spdk_nvmf_qpair`: An NVMe-oF queue pair, as defined by the NVMe-oF
specification. These map 1:1 to network connections. This will be referred to
throughout this guide as a **qpair**.
NVMe-oF 队列对，由 NVMe-oF 规范定义。 这些映射 1:1 到网络连接。 在本指南中，这将被称为 qpair。

`struct spdk_nvmf_transport`: An abstraction for a network fabric, as defined
by the NVMe-oF specification. The specification is designed to allow for many
different network fabrics, so the code mirrors that and implements a plugin
system. Currently, only the RDMA transport is available. This will be referred
to throughout this guide as a **transport**.
网络结构的抽象，由 NVMe-oF 规范定义。 该规范旨在允许许多不同的网络结构，因此代码反映了这一点并实现了一个插件系统。 目前，只有 RDMA 传输可用。 在本指南中，这将被称为传输

`struct spdk_nvmf_poll_group`: An abstraction for a collection of network
connections that can be polled as a unit. This is an SPDK-defined concept that
does not appear in the NVMe-oF specification. Often, network transports have
facilities to check for incoming data on groups of connections more
efficiently than checking each one individually (e.g. epoll), so poll groups
provide a generic abstraction for that. This will be referred to throughout
this guide as a **poll group**.
可以作为一个单元轮询的网络连接集合的抽象。 这是SPDK定义的概念，没有出现在NVMe-oF规范中。 通常，网络传输具有比单独检查每个连接（例如 epoll）更有效地检查连接组上传入数据的工具，因此轮询组为此提供了通用抽象。 在本指南中，这将被称为poll组

`struct spdk_nvmf_listener`: A network address at which the target will accept
new connections. 目标将接受新连接的网络地址。

`struct spdk_nvmf_host`: An NVMe-oF NQN representing a host (initiator)
system. This is used for access control. 代表主机（启动器）的 NVMe-oF NQN
系统。 这用于访问控制

## The Basics

A user of the NVMe-oF target library begins by creating a target using
spdk_nvmf_tgt_create(), setting up a set of addresses on which to accept
connections by calling spdk_nvmf_tgt_listen_ext(), then creating a subsystem
using spdk_nvmf_subsystem_create().
NVMe-oF 目标库的用户首先使用 spdk_nvmf_tgt_create() 创建目标，通过调用 spdk_nvmf_tgt_listen_ext() 设置一组接受连接的地址，然后使用 spdk_nvmf_subsystem_create() 创建子系统。

Subsystems begin in an inactive state and must be activated by calling
spdk_nvmf_subsystem_start(). Subsystems may be modified at run time, but only
when in the paused or inactive state. A running subsystem may be paused by
calling spdk_nvmf_subsystem_pause() and resumed by calling
spdk_nvmf_subsystem_resume().
子系统以非活动状态开始，必须通过调用 spdk_nvmf_subsystem_start() 激活。 子系统可以在运行时修改，但仅限于处于暂停或非活动状态时。 正在运行的子系统可以通过调用 spdk_nvmf_subsystem_pause() 暂停并通过调用 spdk_nvmf_subsystem_resume() 恢复。

Namespaces may be added to the subsystem by calling
spdk_nvmf_subsystem_add_ns_ext() when the subsystem is inactive or paused.
Namespaces are bdevs. See @ref bdev for more information about the SPDK bdev
layer. A bdev may be obtained by calling spdk_bdev_get_by_name().
当子系统处于非活动或暂停状态时，可以通过调用 spdk_nvmf_subsystem_add_ns_ext() 将命名空间添加到子系统。 命名空间是 bdev。 有关 SPDK bdev 层的更多信息，请参阅块设备用户指南。 bdev 可以通过调用 spdk_bdev_get_by_name() 获得。

Once a subsystem exists and the target is listening on an address, new
connections will be automatically assigned to poll groups as they are
detected. 一旦子系统存在并且目标正在侦听地址，新连接将在检测到时自动分配给轮询组。

All I/O to a subsystem is driven by a poll group, which polls for incoming
network I/O. Poll groups may be created by calling
spdk_nvmf_poll_group_create(). They automatically request to begin polling
upon creation on the thread from which they were created. Most importantly, *a
poll group may only be accessed from the thread on which it was created.*
子系统的所有 I/O 都由轮询组驱动，轮询组轮询传入的网络 I/O。 可以通过调用 spdk_nvmf_poll_group_create() 创建轮询组。 它们会自动请求在创建它们的线程上创建时开始轮询。 最重要的是，轮询组只能从创建它的线程访问。

## Access Control

Access control is performed at the subsystem level by adding allowed listen
addresses and hosts to a subsystem (see spdk_nvmf_subsystem_add_listener() and
spdk_nvmf_subsystem_add_host()). By default, a subsystem will not accept
connections from any host or over any established listen address. Listeners
and hosts may only be added to inactive or paused subsystems.
通过向子系统添加允许的侦听地址和主机来在子系统级别执行访问控制（请参阅 spdk_nvmf_subsystem_add_listener() 和 spdk_nvmf_subsystem_add_host()）。 默认情况下，子系统不会接受来自任何主机或任何已建立的侦听地址的连接。 侦听器和主机只能添加到非活动或暂停的子系统。

## Discovery Subsystems

A discovery subsystem, as defined by the NVMe-oF specification, is
automatically created for each NVMe-oF target constructed. Connections to the
discovery subsystem are handled in the same way as any other subsystem.
为每个构建的 NVMe-oF 目标自动创建一个由 NVMe-oF 规范定义的发现子系统。 与发现子系统的连接的处理方式与任何其他子系统的处理方式相同。

## Transports

The NVMe-oF specification defines multiple network transports (the "Fabrics"
in NVMe over Fabrics) and has an extensible system for adding new fabrics
in the future. The SPDK NVMe-oF target library implements a plugin system for
network transports to mirror the specification. The API a new transport must
implement is located in lib/nvmf/transport.h. As of this writing, only an RDMA
transport has been implemented.

The SPDK NVMe-oF target is designed to be able to process I/O from multiple
fabrics simultaneously.
NVMe-oF 规范定义了多种网络传输（NVMe over Fabrics 中的“Fabrics”），并拥有一个可扩展的系统，用于在未来添加新的结构。 SPDK NVMe-oF 目标库实现了一个用于网络传输的插件系统以镜像规范。 新传输必须实现的 API 位于 lib/nvmf/transport.h 中。 在撰写本文时，仅实现了 RDMA 传输。

SPDK NVMe-oF 目标旨在能够同时处理来自多个结构的 I/O。

## Choosing a Threading Model

The SPDK NVMe-oF target library does not strictly dictate threading model, but
poll groups do all of their polling and I/O processing on the thread they are
created on. Given that, it almost always makes sense to create one poll group
per thread used in the application.
SPDK NVMe-oF 目标库没有严格规定线程模型，但轮询组在创建它们的线程上执行所有轮询和 I/O 处理。 鉴于此，为应用程序中使用的每个线程创建一个轮询组几乎总是有意义的。

## Scaling Across CPU Cores

Incoming I/O requests are picked up by the poll group polling their assigned
qpair. For regular NVMe commands such as READ and WRITE, the I/O request is
processed on the initial thread from start to the point where it is submitted
to the backing storage device, without interruption. Completions are
discovered by polling the backing storage device and also processed to
completion on the polling thread. **Regular NVMe commands (READ, WRITE, etc.)
do not require any cross-thread coordination, and therefore take no locks.**
传入的 I/O 请求由轮询组轮询其分配的 qpair 来拾取。 对于 READ 和 WRITE 等常规 NVMe 命令，I/O 请求从开始到提交到后备存储设备的整个过程都在初始线程上进行处理，没有中断。 通过轮询后备存储设备发现完成，并在轮询线程上处理完成。 常规 NVMe 命令（READ、WRITE 等）不需要任何跨线程协调，因此不需要锁。

NVMe ADMIN commands, which are used for managing the NVMe device itself, may
modify global state in the subsystem. For instance, an NVMe ADMIN command may
perform namespace management, such as shrinking a namespace. For these
commands, the subsystem will temporarily enter a paused state by sending a
message to each thread in the system. All new incoming I/O on any thread
targeting the subsystem will be queued during this time. Once the subsystem is
fully paused, the state change will occur, and messages will be sent to each
thread to release queued I/O and resume. Management commands are rare, so this
style of coordination is preferable to forcing all commands to take locks in
the I/O path.
用于管理 NVMe 设备本身的 NVMe ADMIN 命令可能会修改子系统中的全局状态。 例如，NVMe ADMIN 命令可以执行命名空间管理，例如缩小命名空间。 对于这些命令，子系统将通过向系统中的每个线程发送消息来暂时进入暂停状态。 在此期间，针对子系统的任何线程上的所有新传入 I/O 都将排队。 一旦子系统完全暂停，状态将发生变化，消息将发送到每个线程以释放排队的 I/O 并恢复。 管理命令很少见，因此这种协调方式优于强制所有命令在 I/O 路径中获取锁。

## Zero Copy Support

For the RDMA transport, data is transferred from the RDMA NIC to host memory
and then host memory to the SSD (or vice versa), without any intermediate
copies. Data is never moved from one location in host memory to another. Other
transports in the future may require data copies.
对于 RDMA 传输，数据从 RDMA NIC 传输到主机内存，然后从主机内存传输到 SSD（反之亦然），没有任何中间副本。 数据永远不会从主机内存中的一个位置移动到另一个位置。 未来的其他传输可能需要数据副本。

## RDMA

The SPDK NVMe-oF RDMA transport is implemented on top of the libibverbs and
rdmacm libraries, which are packaged and available on most Linux
distributions. It does not use a user-space RDMA driver stack through DPDK.
SPDK NVMe-oF RDMA 传输是在 libibverbs 和 rdmacm 库之上实现的，这些库在大多数 Linux 发行版上都已打包并可用。 它不通过 DPDK 使用用户空间 RDMA 驱动程序堆栈。

In order to scale to large numbers of connections, the SPDK NVMe-oF RDMA
transport allocates a single RDMA completion queue per poll group. All new
qpairs assigned to the poll group are given their own RDMA send and receive
queues, but share this common completion queue. This allows the poll group to
poll a single queue for incoming messages instead of iterating through each
one.
为了扩展到大量连接，SPDK NVMe-oF RDMA 传输为每个轮询组分配一个 RDMA 完成队列。 分配给轮询组的所有新 qpairs 都有自己的 RDMA 发送和接收队列，但共享这个公共完成队列。 这允许轮询组轮询单个队列以获取传入消息，而不是遍历每个队列。

Each RDMA request is handled by a state machine that walks the request through
a number of states. This keeps the code organized and makes all of the corner
cases much more obvious.
每个 RDMA 请求都由一个状态机处理，该状态机使请求遍历多个状态。 这使代码保持井井有条，并使所有极端情况更加明显。

RDMA SEND, READ, and WRITE operations are ordered with respect to one another,
but RDMA RECVs are not necessarily ordered with SEND acknowledgements. For
instance, it is possible to detect an incoming RDMA RECV message containing a
new NVMe-oF capsule prior to detecting the acknowledgement of a previous SEND
containing an NVMe completion. This is problematic at full queue depth because
there may not yet be a free request structure. To handle this, the RDMA
request structure is broken into two parts - an rdma_recv and an rdma_request.
New RDMA RECVs will always grab a free rdma_recv, but may need to wait in a
queue for a SEND acknowledgement before they can acquire a full rdma_request
object.
RDMA SEND、READ 和 WRITE 操作是相对于彼此排序的，但 RDMA RECV 不一定与 SEND 确认一起排序。 例如，在检测到包含 NVMe 完成的先前 SEND 的确认之前，可以检测到包含新 NVMe-oF 胶囊的传入 RDMA RECV 消息。 这在完整的队列深度是有问题的，因为可能还没有空闲的请求结构。 为处理此问题，RDMA 请求结构分为两部分 - rdma_recv 和 rdma_request。 新的 RDMA RECV 将始终获取空闲的 rdma_recv，但可能需要在队列中等待 SEND 确认，然后才能获取完整的 rdma_request 对象。

Further, RDMA NICs expose different queue depths for READ/WRITE operations
than they do for SEND/RECV operations. The RDMA transport reports available
queue depth based on SEND/RECV operation limits and will queue in software as
necessary to accommodate (usually lower) limits on READ/WRITE operations.
此外，RDMA NIC 为 READ/WRITE 操作公开的队列深度与为 SEND/RECV 操作公开的队列深度不同。 RDMA 传输根据 SEND/RECV 操作限制报告可用队列深度，并将根据需要在软件中排队以适应（通常较低的）READ/WRITE 操作限制。
