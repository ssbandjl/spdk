# Blobstore Programmer's Guide {#blob}

## In this document {#blob_pg_toc}

* @ref blob_pg_audience
* @ref blob_pg_intro
* @ref blob_pg_theory
* @ref blob_pg_design
* @ref blob_pg_examples
* @ref blob_pg_config
* @ref blob_pg_component

## Target Audience {#blob_pg_audience}

The programmer's guide is intended for developers authoring applications that utilize the SPDK Blobstore. It is
intended to supplement the source code in providing an overall understanding of how to integrate Blobstore into
an application as well as provide some high level insight into how Blobstore works behind the scenes. It is not
intended to serve as a design document or an API reference and in some cases source code snippets and high level
sequences will be discussed; for the latest source code reference refer to the [repo](https://github.com/spdk).

程序员指南适用于编写使用 SPDK Blobstore 的应用程序的开发人员。 它旨在补充源代码，以全面了解如何将 Blobstore 集成到应用程序中，并提供对 Blobstore 如何在幕后工作的一些高级见解。 它无意用作设计文档或 API 参考，在某些情况下将讨论源代码片段和高级序列； 有关最新的源代码参考，请参阅 repo。

## Introduction {#blob_pg_intro}

Blobstore is a persistent, power-fail safe block allocator designed to be used as the local storage system
backing a higher level storage service, typically in lieu of a traditional filesystem. These higher level services
can be local databases or key/value stores (MySQL, RocksDB), they can be dedicated appliances (SAN, NAS), or
distributed storage systems (ex. Ceph, Cassandra). It is not designed to be a general purpose filesystem, however,
and it is intentionally not POSIX compliant. To avoid confusion, we avoid references to files or objects instead
using the term 'blob'. The Blobstore is designed to allow asynchronous, uncached, parallel reads and writes to
groups of blocks on a block device called 'blobs'. Blobs are typically large, measured in at least hundreds of
kilobytes, and are always a multiple of the underlying block size.

Blobstore 是一种持久的、断电安全的块分配器，旨在用作支持更高级别存储服务的本地存储系统，通常代替传统的文件系统。 这些更高级别的服务可以是本地数据库或键/值存储（MySQL、RocksDB），它们可以是专用设备（SAN、NAS）或分布式存储系统（例如 Ceph、Cassandra）。 但是，它并非设计为通用文件系统，并且有意不兼容 POSIX。 为避免混淆，我们避免引用文件或对象，而是使用术语“blob”。 Blobstore 旨在允许被称为“blob”的块设备上的块组进行异步、未缓存、并行读取和写入。 Blob 通常很大，至少有数百 KB，并且始终是底层块大小的倍数。

The Blobstore is designed primarily to run on "next generation" media, which means the device supports fast random
reads and writes, with no required background garbage collection. However, in practice the design will run well on
NAND too.

Blobstore 主要设计用于在“下一代”介质上运行，这意味着该设备支持快速随机读写，无需后台垃圾收集。 然而，在实践中，该设计也能在 NAND 上运行良好。

## Theory of Operation  操作原理{#blob_pg_theory}

### Abstractions 抽象

The Blobstore defines a hierarchy of storage abstractions as follows. Blobstore 定义存储抽象层次结构如下。

* **Logical Block**: Logical blocks are exposed by the disk itself, which are numbered from 0 to N, where N is the
  number of blocks in the disk. A logical block is typically either 512B or 4KiB.  逻辑块：逻辑块是磁盘本身暴露出来的，从0到N编号，其中N是磁盘中的块数。 逻辑块通常为 512B 或 4KiB
* **Page**: A page is defined to be a fixed number of logical blocks defined at Blobstore creation time. The logical
  blocks that compose a page are always contiguous. Pages are also numbered from the beginning of the disk such
  that the first page worth of blocks is page 0, the second page is page 1, etc. A page is typically 4KiB in size,
  so this is either 8 or 1 logical blocks in practice. The SSD must be able to perform atomic reads and writes of
  at least the page size.  页面：页面被定义为在 Blobstore 创建时定义的固定数量的逻辑块。 组成页面的逻辑块总是连续的。 页面也从磁盘的开头开始编号，这样第一页的块是第 0 页，第二页是第 1 页，等等。一个页面的大小通常为 4KiB，所以这实际上是 8 个或 1 个逻辑块 . SSD 必须能够执行至少页面大小的原子读写
* **Cluster**: A cluster is a fixed number of pages defined at Blobstore creation time. The pages that compose a cluster
  are always contiguous. Clusters are also numbered from the beginning of the disk, where cluster 0 is the first cluster
  worth of pages, cluster 1 is the second grouping of pages, etc. A cluster is typically 1MiB in size, or 256 pages.  集群：集群是在 Blobstore 创建时定义的固定数量的页面。 构成集群的页面始终是连续的。 集群也从磁盘的开头开始编号，其中集群 0 是第一个页面，集群1 是第二组页面，依此类推。一个集群的大小通常为 1MiB，或 256 页
* **Blob**: A blob is an ordered list of clusters. Blobs are manipulated (created, sized, deleted, etc.) by the application
  and persist across power failures and reboots. Applications use a Blobstore provided identifier to access a particular blob.
  Blobs are read and written in units of pages by specifying an offset from the start of the blob. Applications can also
  store metadata in the form of key/value pairs with each blob which we'll refer to as xattrs (extended attributes).  Blob：Blob 是集群的有序列表。 Blob 由应用程序操作（创建、调整大小、删除等），并在电源故障和重新启动后持续存在。 应用程序使用 Blobstore 提供的标识符来访问特定的 blob。 通过指定距 blob 开头的偏移量，以页为单位读取和写入 blob。 应用程序还可以将元数据以键/值对的形式存储在每个 blob 中，我们将其称为 xattrs（扩展属性）。
* **Blobstore**: An SSD which has been initialized by a Blobstore-based application is referred to as "a Blobstore." A
  Blobstore owns the entire underlying device which is made up of a private Blobstore metadata region and the collection of
  blobs as managed by the application.  Blobstore：已由基于 Blobstore 的应用程序初始化的 SSD 称为“Blobstore”。 Blobstore 拥有整个底层设备，该设备由私有 Blobstore 元数据区域和应用程序管理的 blob 集合组成。

```text
+-----------------------------------------------------------------+
|                              Blob                               |
| +-----------------------------+ +-----------------------------+ |
| |           Cluster           | |           Cluster           | |
| | +----+ +----+ +----+ +----+ | | +----+ +----+ +----+ +----+ | |
| | |Page| |Page| |Page| |Page| | | |Page| |Page| |Page| |Page| | |
| | +----+ +----+ +----+ +----+ | | +----+ +----+ +----+ +----+ | |
| +-----------------------------+ +-----------------------------+ |
+-----------------------------------------------------------------+
```

### Atomicity

For all Blobstore operations regarding atomicity, there is a dependency on the underlying device to guarantee atomic
operations of at least one page size. Atomicity here can refer to multiple operations:  

对于所有与原子性相关的 Blobstore 操作，都依赖于底层设备来保证至少一个页面大小的原子操作。 这里的原子性可以指代多个操作：

* **Data Writes**: For the case of data writes, the unit of atomicity is one page. Therefore if a write operation of
  greater than one page is underway and the system suffers a power failure, the data on media will be consistent at a page
  size granularity (if a single page were in the middle of being updated when power was lost, the data at that page location
  will be as it was prior to the start of the write operation following power restoration.)  数据写入：对于数据写入的情况，原子性的单位是一页。 因此，如果正在进行大于一页的写入操作并且系统发生电源故障，则介质上的数据将以页面大小粒度保持一致（如果断电时单个页面正在更新，则 该页面位置的数据将与电源恢复后写入操作开始之前一样。）
* **Blob Metadata Updates**: Each blob has its own set of metadata (xattrs, size, etc). For performance reasons, a copy of
  this metadata is kept in RAM and only synchronized with the on-disk version when the application makes an explicit call to
  do so, or when the Blobstore is unloaded. Therefore, setting of an xattr, for example is not consistent until the call to
  synchronize it (covered later) which is, however, performed atomically.  Blob 元数据更新：每个 Blob 都有自己的一组元数据（xattrs、大小等）。 出于性能原因，此元数据的副本保存在 RAM 中，并且仅在应用程序进行显式调用或卸载 Blobstore 时才与磁盘版本同步。 因此，例如，xattr 的设置在调用同步它（稍后介绍）之前是不一致的，但是，它是原子执行的。
* **Blobstore Metadata Updates**: Blobstore itself has its own metadata which, like per blob metadata, has a copy in both
  RAM and on-disk. Unlike the per blob metadata, however, the Blobstore metadata region is not made consistent via a blob
  synchronization call, it is only synchronized when the Blobstore is properly unloaded via API. Therefore, if the Blobstore
  metadata is updated (blob creation, deletion, resize, etc.) and not unloaded properly, it will need to perform some extra
  steps the next time it is loaded which will take a bit more time than it would have if shutdown cleanly, but there will be
  no inconsistencies.  Blobstore 元数据更新：Blobstore 本身有自己的元数据，就像每个 blob 元数据一样，在 RAM 和磁盘上都有一个副本。 然而，与每个 blob 元数据不同的是，Blobstore 元数据区域不会通过 blob 同步调用保持一致，它仅在通过 API 正确卸载 Blobstore 时才会同步。 因此，如果 Blobstore 元数据已更新（blob 创建、删除、调整大小等）但未正确卸载，则在下次加载时将需要执行一些额外的步骤，这将比在加载时花费更多的时间 干净地关闭，但不会有不一致。

### Callbacks

Blobstore is callback driven; in the event that any Blobstore API is unable to make forward progress it will
not block but instead return control at that point and make a call to the callback function provided in the API, along with
arguments, when the original call is completed. The callback will be made on the same thread that the call was made from, more on
threads later. Some API, however, offer no callback arguments; in these cases the calls are fully synchronous. Examples of
asynchronous calls that utilize callbacks include those that involve disk IO, for example, where some amount of polling
is required before the IO is completed.

Blobstore 是回调驱动的； 如果任何 Blobstore API 无法向前推进，它不会阻止，而是在此时返回控制权，并在原始调用完成时调用 API 中提供的回调函数以及参数。 回调将在与调用相同的线程上进行，稍后会在线程上进行。 但是，有些 API 不提供回调参数； 在这些情况下，调用是完全同步的。 使用回调的异步调用示例包括那些涉及磁盘 IO 的示例，例如，在 IO 完成之前需要进行一定数量的轮询。

### Backend Support

Blobstore requires a backing storage device that can be integrated using the `bdev` layer, or by directly integrating a
device driver to Blobstore. The blobstore performs operations on a backing block device by calling function pointers
supplied to it at initialization time. For convenience, an implementation of these function pointers that route I/O
to the bdev layer is available in `bdev_blob.c`.  Alternatively, for example, the SPDK NVMe driver may be directly integrated
bypassing a small amount of `bdev` layer overhead. These options will be discussed further in the upcoming section on examples.

Blobstore 需要一个可以使用 bdev 层集成的后备存储设备，或者通过直接将设备驱动程序集成到 Blobstore。 blobstore 通过调用在初始化时提供给它的函数指针来在后备块设备上执行操作。 为方便起见，这些将 I/O 路由到 bdev 层的函数指针的实现在 bdev_blob.c 中可用。 或者，例如，可以绕过少量 bdev 层开销直接集成 SPDK NVMe 驱动程序。 这些选项将在接下来的示例部分中进一步讨论。

### Metadata Operations

Because Blobstore is designed to be lock-free, metadata operations need to be isolated to a single
thread to avoid taking locks on in memory data structures that maintain data on the layout of definitions of blobs (along
with other data). In Blobstore this is implemented as `the metadata thread` and is defined to be the thread on which the
application makes metadata related calls on. It is up to the application to setup a separate thread to make these calls on
and to assure that it does not mix relevant IO operations with metadata operations even if they are on separate threads.
This will be discussed further in the Design Considerations section.

由于 Blobstore 设计为无锁，因此元数据操作需要隔离到单个线程，以避免锁定内存数据结构，这些数据结构维护 blob 定义布局上的数据（以及其他数据）。 在 Blobstore 中，这被实现为元数据线程，并被定义为应用程序在其上进行元数据相关调用的线程。 由应用程序设置一个单独的线程来进行这些调用，并确保它不会将相关的 IO 操作与元数据操作混合在一起，即使它们在单独的线程上也是如此。 这将在“设计注意事项”部分进一步讨论。

### Threads

An application using Blobstore with the SPDK NVMe driver, for example, can support a variety of thread scenarios.
The simplest would be a single threaded application where the application, the Blobstore code and the NVMe driver share a
single core. In this case, the single thread would be used to submit both metadata operations as well as IO operations and
it would be up to the application to assure that only one metadata operation is issued at a time and not intermingled with
affected IO operations.

例如，将 Blobstore 与 SPDK NVMe 驱动程序结合使用的应用程序可以支持各种线程方案。 最简单的是单线程应用程序，其中应用程序、Blobstore 代码和 NVMe 驱动程序共享一个内核。 在这种情况下，单个线程将用于提交元数据操作和 IO 操作，并且将由应用程序确保一次只发出一个元数据操作并且不与受影响的 IO 操作混合。

### Channels

Channels are an SPDK-wide abstraction and with Blobstore the best way to think about them is that they are
required in order to do IO.  The application will perform IO to the channel and channels are best thought of as being
associated 1:1 with a thread.

通道是 SPDK 范围内的抽象，对于 Blobstore，考虑它们的最佳方式是它们是执行 IO 所必需的。 应用程序将对通道执行 IO，最好将通道视为与线程 1:1 关联。

### Blob Identifiers

When an application creates a blob, it does not provide a name as is the case with many other similar
storage systems, instead it is returned a unique identifier by the Blobstore that it needs to use on subsequent APIs to
perform operations on the Blobstore.

当应用程序创建 blob 时，它不会像许多其他类似存储系统那样提供名称，而是由 Blobstore 返回一个唯一标识符，它需要在后续 API 上使用该标识符以在 Blobstore 上执行操作。

## Design Considerations 设计注意事项{#blob_pg_design}

### Initialization Options

When the Blobstore is initialized, there are multiple configuration options to consider. The
options and their defaults are:  初始化 Blobstore 时，需要考虑多个配置选项。 选项及其默认值是：

* **Cluster Size**: By default, this value is 1MB. The cluster size is required to be a multiple of page size and should be
  selected based on the application’s usage model in terms of allocation. Recall that blobs are made up of clusters so when
  a blob is allocated/deallocated or changes in size, disk LBAs will be manipulated in groups of cluster size.  If the
  application is expecting to deal with mainly very large (always multiple GB) blobs then it may make sense to change the
  cluster size to 1GB for example.  集群大小：默认情况下，该值为 1MB。 集群大小需要是页面大小的倍数，并且应根据应用程序的使用模型在分配方面进行选择。 回想一下，blob 由集群组成，因此当分配/取消分配 blob 或更改大小时，磁盘 LBA 将按集群大小分组进行操作。 如果应用程序预计主要处理非常大（总是多个 GB）的 blob，那么将集群大小更改为 1GB 可能是有意义的。
* **Number of Metadata Pages**: By default, Blobstore will assume there can be as many clusters as there are metadata pages
  which is the worst case scenario in terms of metadata usage and can be overridden here however the space efficiency is
  not significant.  元数据页数：默认情况下，Blobstore 会假设集群的数量与元数据页的数量一样多，这是元数据使用方面最糟糕的情况，可以在此处覆盖，但空间效率并不显着。
* **Maximum Simultaneous Metadata Operations**: Determines how many internally pre-allocated memory structures are set
  aside for performing metadata operations. It is unlikely that changes to this value (default 32) would be desirable.  Maximum Simultaneous Metadata Operations：确定为执行元数据操作预留了多少内部预分配内存结构。 不太可能需要更改此值（默认值 32）。
* **Maximum Simultaneous Operations Per Channel**: Determines how many internally pre-allocated memory structures are set
  aside for channel operations. Changes to this value would be application dependent and best determined by both a knowledge
  of the typical usage model, an understanding of the types of SSDs being used and empirical data. The default is 512.  Maximum Simultaneous Operations Per Channel：确定为通道操作留出多少内部预分配内存结构。 对此值的更改将取决于应用程序，并且最好由对典型使用模型的了解、对所使用的 SSD 类型的理解以及经验数据来确定。 默认值为 512。
* **Blobstore Type**: This field is a character array to be used by applications that need to identify whether the
  Blobstore found here is appropriate to claim or not. The default is NULL and unless the application is being deployed in
  an environment where multiple applications using the same disks are at risk of inadvertently using the wrong Blobstore, there
  is no need to set this value. It can, however, be set to any valid set of characters.  Blobstore 类型：此字段是一个字符数组，供需要识别此处找到的 Blobstore 是否适合声明的应用程序使用。 默认值为 NULL，除非应用程序部署在使用相同磁盘的多个应用程序存在无意中使用错误 Blobstore 的风险的环境中，否则无需设置此值。 但是，它可以设置为任何有效的字符集。

### Sub-page Sized Operations

Blobstore is only capable of doing page sized read/write operations. If the application
requires finer granularity it will have to accommodate that itself. 

Blobstore 只能执行页面大小的读/写操作。 如果应用程序需要更精细的粒度，则它必须自行适应。

### Threads

As mentioned earlier, Blobstore can share a single thread with an application or the application
can define any number of threads, within resource constraints, that makes sense.  The basic considerations that must be
followed are: 如前所述，Blobstore 可以与应用程序共享单个线程，或者应用程序可以在资源限制范围内定义任意数量的线程。 必须遵循的基本注意事项是：

* Metadata operations (API with MD in the name) should be isolated from each other as there is no internal locking on the
   memory structures affected by these API. 元数据操作（名称中带有 MD 的 API）应该相互隔离，因为在受这些 API 影响的内存结构上没有内部锁定。
* Metadata operations should be isolated from conflicting IO operations (an example of a conflicting IO would be one that is
  reading/writing to an area of a blob that a metadata operation is deallocating). 元数据操作应与冲突 IO 操作隔离（冲突 IO 的一个示例是读取/写入元数据操作正在释放的 blob 区域）。
* Asynchronous callbacks will always take place on the calling thread.   异步回调将始终发生在调用线程上。
* No assumptions about IO ordering can be made regardless of how many or which threads were involved in the issuing. 无论发布中涉及多少线程或哪些线程，都不能对 IO 排序做出任何假设。

### Data Buffer Memory

As with all SPDK based applications, Blobstore requires memory used for data buffers to be allocated
with SPDK API.

与所有基于 SPDK 的应用程序一样，Blobstore 需要使用 SPDK API 分配用于数据缓冲区的内存。

### Error Handling

Asynchronous Blobstore callbacks all include an error number that should be checked; non-zero values
indicate an error. Synchronous calls will typically return an error value if applicable.

异步 Blobstore 回调都包含一个应该检查的错误号； 非零值表示错误。 如果适用，同步调用通常会返回一个错误值。

### Asynchronous API

Asynchronous callbacks will return control not immediately, but at the point in execution where no
more forward progress can be made without blocking.  Therefore, no assumptions can be made about the progress of
an asynchronous call until the callback has completed.

异步回调不会立即返回控制权，而是在执行时不阻塞就无法取得更多进展。 因此，在回调完成之前，无法对异步调用的进度做出任何假设。

### Xattrs

Setting and removing of xattrs in Blobstore is a metadata operation, xattrs are stored in per blob metadata.
Therefore, xattrs are not persisted until a blob synchronization call is made and completed. Having a step process for
persisting per blob metadata allows for applications to perform batches of xattr updates, for example, with only one
more expensive call to synchronize and persist the values.

在 Blobstore 中设置和删除 xattrs 是一个元数据操作，xattrs 存储在每个 blob 元数据中。 因此，在进行并完成 blob 同步调用之前，不会保留 xattrs。 拥有一个用于持久化每个 blob 元数据的步骤过程允许应用程序执行批量 xattr 更新，例如，只需一个更昂贵的调用来同步和持久化值。

### Synchronizing Metadata

As described earlier, there are two types of metadata in Blobstore, per blob and one global
metadata for the Blobstore itself.  Only the per blob metadata can be explicitly synchronized via API. The global
metadata will be inconsistent during run-time and only synchronized on proper shutdown. The implication, however, of
an improper shutdown is only a performance penalty on the next startup as the global metadata will need to be rebuilt
based on a parsing of the per blob metadata. For consistent start times, it is important to always close down the Blobstore
properly via API.

如前所述，Blobstore 中有两种类型的元数据，一种是针对 Blob 的元数据，另一种是针对 Blobstore 本身的全局元数据。 只有 per blob 元数据可以通过 API 显式同步。 全局元数据在运行时将不一致，只有在正确关闭时才会同步。 然而，不当关闭的含义只是下一次启动时的性能损失，因为需要根据对每个 blob 元数据的解析来重建全局元数据。 为了保持一致的开始时间，务必始终通过 API 正确关闭 Blobstore。

### Iterating Blobs

Multiple examples of how to iterate through the blobs are included in the sample code and tools.
Worthy to note, however, if walking through the existing blobs via the iter API, if your application finds the blob its
looking for it will either need to explicitly close it (because was opened internally by the Blobstore) or complete walking
the full list.

示例代码和工具中包含如何循环访问 blob 的多个示例。 但是，值得注意的是，如果通过 iter API 遍历现有的 blob，如果您的应用程序找到了它正在寻找的 blob，则需要显式关闭它（因为它是由 Blobstore 在内部打开的）或完成完整列表的遍历。

### The Super Blob

The super blob is simply a single blob ID that can be stored as part of the global metadata to act
as sort of a "root" blob. The application may choose to use this blob to store any information that it needs or finds
relevant in understanding any kind of structure for what is on the Blobstore.

超级 blob 只是一个单一的 blob ID，可以作为全局元数据的一部分存储，充当某种“根”blob。 应用程序可以选择使用此 blob 来存储它需要的任何信息或发现与理解 Blobstore 上的任何类型的结构相关的信息。

## Examples {#blob_pg_examples}

There are multiple examples of Blobstore usage in the [repo](https://github.com/spdk/spdk):

* **Hello World**: Actually named `hello_blob.c` this is a very basic example of a single threaded application that
  does nothing more than demonstrate the very basic API. Although Blobstore is optimized for NVMe, this example uses
  a RAM disk (malloc) back-end so that it can be executed easily in any development environment. The malloc back-end
  is a `bdev` module thus this example uses not only the SPDK Framework but the `bdev` layer as well.  Hello World：实际上名为 hello_blob.c，这是一个非常基本的单线程应用程序示例，它仅演示非常基本的 API。 尽管 Blobstore 针对 NVMe 进行了优化，但此示例使用 RAM 磁盘 (malloc) 后端，因此它可以在任何开发环境中轻松执行。 malloc 后端是一个 bdev 模块，因此该示例不仅使用 SPDK 框架，还使用 bdev 层。

* **CLI**: The `blobcli.c` example is command line utility intended to not only serve as example code but as a test
  and development tool for Blobstore itself. It is also a simple single threaded application that relies on both the
  SPDK Framework and the `bdev` layer but offers multiple modes of operation to accomplish some real-world tasks. In
  command mode, it accepts single-shot commands which can be a little time consuming if there are many commands to
  get through as each one will take a few seconds waiting for DPDK initialization. It therefore has a shell mode that
  allows the developer to get to a `blob>` prompt and then very quickly interact with Blobstore with simple commands
  that include the ability to import/export blobs from/to regular files. Lastly there is a scripting mode to automate
  a series of tasks, again, handy for development and/or test type activities.  CLI：blobcli.c 示例是命令行实用程序，旨在不仅用作示例代码，而且用作 Blobstore 本身的测试和开发工具。 它也是一个简单的单线程应用程序，它依赖于 SPDK 框架和 bdev 层，但提供多种操作模式来完成一些实际任务。 在命令模式下，它接受单次命令，如果有很多命令要通过，这可能会有点耗时，因为每个命令都需要几秒钟等待 DPDK 初始化。 因此，它有一个 shell 模式，允许开发人员进入 blob> 提示符，然后使用简单的命令非常快速地与 Blobstore 交互，这些命令包括从常规文件导入/导出 blob 的能力。 最后还有一个脚本模式可以自动执行一系列任务，同样方便开发和/或测试类型的活动

## Configuration {#blob_pg_config}

Blobstore configuration options are described in the initialization options section under @ref blob_pg_design.

Blobstore 配置选项在设计注意事项下的初始化选项部分进行了描述。

## Component Detail {#blob_pg_component}

The information in this section is not necessarily relevant to designing an application for use with Blobstore, but
understanding a little more about the internals may be interesting and is also included here for those wanting to
contribute to the Blobstore effort itself.

本节中的信息不一定与设计与 Blobstore 一起使用的应用程序相关，但了解更多有关内部结构的信息可能会很有趣，并且也包含在此处，供那些希望为 Blobstore 努力本身做出贡献的人使用。

### Media Format

The Blobstore owns the entire storage device. The device is divided into clusters starting from the beginning, such
that cluster 0 begins at the first logical block.  Blobstore 拥有整个存储设备。 设备从头开始划分为集群，因此集群 0 从第一个逻辑块开始。

```text
LBA 0                                   LBA N
+-----------+-----------+-----+-----------+
| Cluster 0 | Cluster 1 | ... | Cluster N |
+-----------+-----------+-----+-----------+
```

Cluster 0 is special and has the following format, where page 0 is the first page of the cluster:

集群 0 是特殊的，具有以下格式，其中页 0 是集群的第一页：

```text
+--------+-------------------+
| Page 0 | Page 1 ... Page N |
+--------+-------------------+
| Super  |  Metadata Region  |
| Block  |                   |
+--------+-------------------+
```

The super block is a single page located at the beginning of the partition. It contains basic information about
the Blobstore. The metadata region is the remainder of cluster 0 and may extend to additional clusters. Refer
to the latest source code for complete structural details of the super block and metadata region.

超级块是位于分区开头的单个页面。 它包含有关 Blobstore 的基本信息。 元数据区域是集群 0 的其余部分，并且可以扩展到其他集群。 有关超级块和元数据区域的完整结构细节，请参阅最新的源代码。

Each blob is allocated a non-contiguous set of pages inside the metadata region for its metadata. These pages
form a linked list. The first page in the list will be written in place on update, while all other pages will
be written to fresh locations. This requires the backing device to support an atomic write size greater than
or equal to the page size to guarantee that the operation is atomic. See the section on atomicity for details.

每个 blob 在其元数据的元数据区域内分配了一组不连续的页面。 这些页面形成一个链表。 列表中的第一页将在更新时写入到位，而所有其他页面将写入新位置。 这需要支持设备支持大于或等于页面大小的原子写入大小，以保证操作是原子的。 有关详细信息，请参阅原子性部分。

### Blob cluster layout {#blob_pg_cluster_layout}

Each blob is an ordered list of clusters, where starting LBA of a cluster is called extent. A blob can be
thin provisioned, resulting in no extent for some of the clusters. When first write operation occurs
to the unallocated cluster - new extent is chosen. This information is stored in RAM and on-disk.

每个 blob 都是一个有序的集群列表，其中一个集群的起始 LBA 称为范围。 可以对 blob 进行精简配置，从而导致某些集群没有范围。 当第一次写操作发生在未分配的集群时——选择新的范围。 此信息存储在 RAM 和磁盘上。

There are two extent representations on-disk, dependent on `use_extent_table` (default:true) opts used
when creating a blob. 磁盘上有两种范围表示，取决于创建 blob 时使用的 use_extent_table（默认值：true）选项。

* **use_extent_table=true**: EXTENT_PAGE descriptor is not part of linked list of pages. It contains extents
  that are not run-length encoded. Each extent page is referenced by EXTENT_TABLE descriptor, which is serialized
  as part of linked list of pages.  Extent table is run-length encoding all unallocated extent pages.
  Every new cluster allocation updates a single extent page, in case when extent page was previously allocated.
  Otherwise additionally incurs serializing whole linked list of pages for the blob.  use_extent_table=true：EXTENT_PAGE 描述符不是页面链表的一部分。 它包含未经游程编码的范围。 每个范围页面都由 EXTENT_TABLE 描述符引用，该描述符被序列化为页面链表的一部分。 范围表对所有未分配的范围页进行游程编码。 每个新的集群分配都会更新一个扩展页面，以防先前分配了扩展页面。 否则还会导致序列化 blob 的整个页面链接列表。

* **use_extent_table=false**: EXTENT_RLE descriptor is serialized as part of linked list of pages.
  Extents pointing to contiguous LBA are run-length encoded, including unallocated extents represented by 0.
  Every new cluster allocation incurs serializing whole linked list of pages for the blob.  use_extent_table=false：EXTENT_RLE 描述符被序列化为页面链表的一部分。 指向连续 LBA 的范围是运行长度编码的，包括由 0 表示的未分配范围。每个新的集群分配都会导致序列化 blob 的整个页面链接列表。

### Sequences and Batches

Internally Blobstore uses the concepts of sequences and batches to submit IO to the underlying device in either
a serial fashion or in parallel, respectively. Both are defined using the following structure:

在内部，Blobstore 使用序列和批处理的概念分别以串行方式或并行方式将 IO 提交给底层设备。 两者都使用以下结构定义：

~~~{.sh}
struct spdk_bs_request_set;
~~~

These requests sets are basically bookkeeping mechanisms to help Blobstore efficiently deal with related groups
of IO. They are an internal construct only and are pre-allocated on a per channel basis (channels were discussed
earlier). They are removed from a channel associated linked list when the set (sequence or batch) is started and
then returned to the list when completed.

这些请求集基本上是簿记机制，以帮助 Blobstore 有效地处理相关的 IO 组。 它们只是一个内部构造，并且是在每个通道的基础上预先分配的（通道已在前面讨论过）。 当集合（序列或批次）开始时，它们从通道关联的链表中删除，然后在完成时返回到链表中。

### Key Internal Structures

`blobstore.h` contains many of the key structures for the internal workings of Blobstore. Only a few notable ones
are reviewed here.  Note that `blobstore.h` is an internal header file, the header file for Blobstore that defines
the public API is `blob.h`.  blobstore.h 包含 Blobstore 内部工作的许多关键结构。 这里只回顾了一些值得注意的。 请注意，blobstore.h 是一个内部头文件，用于定义公共 API 的 Blobstore 的头文件是 blob.h。

~~~{.sh}
struct spdk_blob
~~~
This is an in-memory data structure that contains key elements like the blob identifier, its current state and two
copies of the mutable metadata for the blob; one copy is the current metadata and the other is the last copy written
to disk.

这是一个内存数据结构，包含关键元素，如 blob 标识符、其当前状态和 blob 的可变元数据的两个副本； 一个副本是当前的元数据，另一个是写入磁盘的最后一个副本。

~~~{.sh}
struct spdk_blob_mut_data
~~~
This is a per blob structure, included the `struct spdk_blob` struct that actually defines the blob itself. It has the
specific information on size and makeup of the blob (ie how many clusters are allocated for this blob and which ones.)

这是一个 per blob 结构，包括实际定义 blob 本身的 struct spdk_blob 结构。 它具有关于 blob 的大小和构成的特定信息（即为该 blob 分配了多少集群以及哪些集群。）

~~~{.sh}
struct spdk_blob_store
~~~
This is the main in-memory structure for the entire Blobstore. It defines the global on disk metadata region and maintains
information relevant to the entire system - initialization options such as cluster size, etc.

这是整个 Blobstore 的主要内存结构。 它定义了磁盘上的全局元数据区域并维护与整个系统相关的信息——初始化选项，例如集群大小等。

~~~{.sh}
struct spdk_bs_super_block
~~~
The super block is an on-disk structure that contains all of the relevant information that's in the in-memory Blobstore
structure just discussed along with other elements one would expect to see here such as signature, version, checksum, etc.

超级块是一个磁盘上的结构，它包含刚才讨论的内存中 Blobstore 结构中的所有相关信息以及您希望在此处看到的其他元素，例如签名、版本、校验和等。

### Code Layout and Common Conventions 代码布局和通用约定

In general, `Blobstore.c` is laid out with groups of related functions blocked together with descriptive comments. For
example, 通常，Blobstore.c 的布局是将相关功能组与描述性注释一起屏蔽。 例如，

~~~{.sh}
/* START spdk_bs_md_delete_blob */
< relevant functions to accomplish the deletion of a blob >
/* END spdk_bs_md_delete_blob */
~~~

And for the most part the following conventions are followed throughout: 在大多数情况下，始终遵循以下约定：

* functions beginning with an underscore are called internally only 以下划线开头的函数仅在内部调用
* functions or variables with the letters `cpl` are related to set or callback completions 带有字母 cpl 的函数或变量与设置或回调完成相关
