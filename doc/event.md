# Event Framework {#event}

SPDK provides a framework for writing asynchronous, polled-mode,
shared-nothing server applications. The event framework is intended to be
optional; most other SPDK components are designed to be integrated into an
application without specifically depending on the SPDK event library. The
framework defines several concepts - reactors, events, and pollers - that are
described in the following sections. The event framework spawns one thread per
core (reactor) and connects the threads with lockless queues. Messages
(events) can then be passed between the threads. On modern CPU architectures,
message passing is often much faster than traditional locking. For a
discussion of the theoretical underpinnings of this framework, see @ref
concurrency. 
SPDK 提供了一个用于编写异步、轮询模式、无共享服务器应用程序的框架。 事件框架是可选的； 大多数其他 SPDK 组件旨在集成到应用程序中，而无需特别依赖 SPDK 事件库。 该框架定义了几个概念——反应器、事件和轮询器——将在以下部分中进行描述。 事件框架为每个核心（反应堆）生成一个线程，并使用无锁队列连接线程。 然后可以在线程之间传递消息（事件）。 在现代 CPU 架构上，消息传递通常比传统锁定快得多。 有关此框架的理论基础的讨论，请参阅消息传递和并发。

The event framework public interface is defined in event.h.

## Event Framework Design Considerations {#event_design}

Simple server applications can be written in a single-threaded fashion. This
allows for straightforward code that can maintain state without any locking or
other synchronization. However, to scale up (for example, to allow more
simultaneous connections), the application may need to use multiple threads.
In the ideal case where each connection is independent from all other
connections, the application can be scaled by creating additional threads and
assigning connections to them without introducing cross-thread
synchronization. Unfortunately, in many real-world cases, the connections are
not entirely independent and cross-thread shared state is necessary. SPDK
provides an event framework to help solve this problem. 
可以用单线程方式编写简单的服务器应用程序。 这允许直接代码无需任何锁定或其他同步即可维护状态。 但是，要向上扩展（例如，允许更多同时连接），应用程序可能需要使用多个线程。 在每个连接都独立于所有其他连接的理想情况下，可以通过创建额外的线程并为它们分配连接来扩展应用程序，而无需引入跨线程同步。 不幸的是，在许多实际情况下，连接并不是完全独立的，跨线程共享状态是必要的。 SPDK 提供了一个事件框架来帮助解决这个问题。

## SPDK Event Framework Components {#event_components}

### Events {#event_component_events}

To accomplish cross-thread communication while minimizing synchronization
overhead, the framework provides message passing in the form of events. The
event framework runs one event loop thread per CPU core. These threads are
called reactors, and their main responsibility is to process incoming events
from a queue. Each event consists of a bundled function pointer and its
arguments, destined for a particular CPU core. Events are created using
spdk_event_allocate() and executed using spdk_event_call(). Unlike a
thread-per-connection server design, which achieves concurrency by depending
on the operating system to schedule many threads issuing blocking I/O onto a
limited number of cores, the event-driven model requires use of explicitly
asynchronous operations to achieve concurrency. Asynchronous I/O may be issued
with a non-blocking function call, and completion is typically signaled using
a callback function. 
为了在最小化同步开销的同时完成跨线程通信，框架提供了事件形式的消息传递。 事件框架为每个 CPU 核心运行一个事件循环线程。 这些线程称为反应器，它们的主要职责是处理来自队列的传入事件。 每个事件都包含一个绑定的函数指针及其参数，指定给特定的 CPU 内核。 事件使用 spdk_event_allocate() 创建并使用 spdk_event_call() 执行。 与每个连接线程服务器设计不同，后者通过依赖操作系统调度许多线程将阻塞 I/O 发送到有限数量的内核来实现并发，事件驱动模型需要使用显式异步操作来实现并发。 异步 I/O 可以通过非阻塞函数调用发出，完成通常使用回调函数发出信号。

### Reactors {#event_component_reactors}

Each reactor has a lock-free queue for incoming events to that core, and
threads from any core may insert events into the queue of any other core. The
reactor loop running on each core checks for incoming events and executes them
in first-in, first-out order as they are received. Event functions should
never block and should preferably execute very quickly, since they are called
directly from the event loop on the destination core. 
每个反应堆都有一个无锁队列，用于接收到该核心的传入事件，来自任何核心的线程都可以将事件插入任何其他核心的队列中。 在每个核心上运行的反应器循环检查传入事件，并在接收到事件时以先进先出的顺序执行它们。 事件函数不应该阻塞，最好执行得非常快，因为它们是直接从目标核心上的事件循环调用的。

### Pollers {#event_component_pollers}

The framework also defines another type of function called a poller. Pollers
may be registered with the spdk_poller_register() function. Pollers, like
events, are functions with arguments that can be bundled and executed.
However, unlike events, pollers are executed repeatedly until unregistered and
are executed on the thread they are registered on. The reactor event loop
intersperses calls to the pollers with other event processing. Pollers are
intended to poll hardware as a replacement for interrupts. Normally, pollers
are executed on every iteration of the main event loop. Pollers may also be
scheduled to execute periodically on a timer if low latency is not required. 
该框架还定义了另一种类型的函数，称为轮询器。 可以使用 spdk_poller_register() 函数注册轮询器。 轮询器与事件一样，是带有可以捆绑和执行的参数的函数。 然而，与事件不同的是，轮询器会重复执行直到取消注册，并在它们注册的线程上执行。 反应器事件循环将对轮询器的调用与其他事件处理穿插在一起。 轮询器旨在轮询硬件以替代中断。 通常，轮询器在主事件循环的每次迭代中执行。 如果不需要低延迟，也可以安排轮询器在计时器上定期执行。

### Application Framework {#event_component_app}

The framework itself is bundled into a higher level abstraction called an "app". Once
spdk_app_start() is called, it will block the current thread until the application
terminates by calling spdk_app_stop() or an error condition occurs during the
initialization code within spdk_app_start(), itself, before invoking the caller's
supplied function. 
框架本身被捆绑到称为“应用程序”的更高级别的抽象中。 一旦调用 spdk_app_start()，它将阻塞当前线程，直到应用程序通过调用 spdk_app_stop() 终止，或者在调用调用者提供的函数之前，在 spdk_app_start() 本身的初始化代码期间发生错误情况。框架本身被捆绑到称为“应用程序”的更高级别的抽象中。 一旦调用 spdk_app_start()，它将阻塞当前线程，直到应用程序通过调用 spdk_app_stop() 终止，或者在调用调用者提供的函数之前，在 spdk_app_start() 本身的初始化代码期间发生错误情况。

### Custom shutdown callback {#event_component_shutdown}

When creating SPDK based application user may add custom shutdown callback which
will be called before the application framework starts the shutdown process.
To do that set shutdown_cb function callback in spdk_app_opts structure passed
to spdk_app_start(). Custom shutdown callback should call spdk_app_stop() before
returning to continue application shutdown process. 
创建基于 SPDK 的应用程序时，用户可以添加自定义关闭回调，该回调将在应用程序框架启动关闭过程之前调用。 为此，在传递给 spdk_app_start() 的 spdk_app_opts 结构中设置 shutdown_cb 函数回调。 自定义关闭回调应该在返回之前调用 spdk_app_stop() 以继续应用程序关闭过程。
