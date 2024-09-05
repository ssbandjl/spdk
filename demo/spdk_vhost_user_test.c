#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <pthread.h>
#include <errno.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <sys/socket.h>
#include <linux/if.h>
#include <linux/if_tun.h>
#include <sys/ioctl.h>
#include <signal.h>
#include <spdk/env.h>
#include <spdk/nvme.h>
#include <spdk/vhost.h>
#define VHOST_SCSI_CTRLR_MAX_DEVS 16
static char g_vhost_if_name[IFNAMSIZ];
static char g_ctrlr_name[VHOST_SCSI_CTRLR_MAX_DEVS][256];
static int g_num_ctrlr_devs;
static struct spdk_nvme_ctrlr *g_nvme_ctrlr;
static struct spdk_nvme_ns *g_nvme_ns;
static void *
vhost_start(void *arg)
{
    int ret;
    int vhost_fd, tun_fd;
    struct ifreq ifr;
    char tun_name[IFNAMSIZ];
    struct vhost_scsi_ctrlr *ctrlr;
    struct vhost_scsi_dev *devs[VHOST_SCSI_CTRLR_MAX_DEVS];
    memset(g_vhost_if_name, 0, sizeof(g_vhost_if_name));
    memset(g_ctrlr_name, 0, sizeof(g_ctrlr_name));
    /* Create a vhost interface */
    vhost_fd = socket(AF_UNIX, SOCK_STREAM, 0);
    if (vhost_fd == -1) {
        perror("socket");
        return NULL;
    }
    memset(&ifr, 0, sizeof(ifr));
    strncpy(ifr.ifr_name, "vhost0", IFNAMSIZ - 1);
    if (ioctl(vhost_fd, SIOCGIFINDEX, &ifr) == -1) {
        perror("ioctl");
        close(vhost_fd);
        return NULL;
    }
    ret = bind(vhost_fd, (struct sockaddr *)&(struct sockaddr_un){
            .sun_family = AF_UNIX,
            .sun_path = "/tmp/vhost.0",
    }, sizeof(struct sockaddr_un));
    if (ret == -1) {
        perror("bind");
        close(vhost_fd);
        return NULL;
    }
    ret = listen(vhost_fd, 1);
    if (ret == -1) {
        perror("listen");
        close(vhost_fd);
        return NULL;
    }
    /* Create a TUN interface */
    tun_fd = open("/dev/net/tun", O_RDWR);
    if (tun_fd == -1) {
        perror("open");
        return NULL;
    }
    memset(&ifr, 0, sizeof(ifr));
    ifr.ifr_flags = IFF_TUN | IFF_NO_PI;
    strncpy(ifr.ifr_name, "vhost-scsi", IFNAMSIZ - 1);
    ret = ioctl(tun_fd, TUNSETIFF, &ifr);
    if (ret == -1) {
        perror("ioctl");
        close(tun_fd);
        return NULL;
    }
    strncpy(g_vhost_if_name, ifr.ifr_name, IFNAMSIZ - 1);
    /* Create a vhost SCSI controller */
    ctrlr = vhost_scsi_ctrlr_construct(g_vhost_if_name, 0);
    if (!ctrlr) {
        fprintf(stderr, "Failed to create vhost SCSI controller\n");
        close(tun_fd);
        return NULL;
    }
    /* Attach the TUN interface to the vhost SCSI controller */
    ret = vhost_scsi_ctrlr_add_dev(ctrlr, tun_fd, 0);
    if (ret == -1) {
        fprintf(stderr, "Failed to add vhost SCSI device\n");
        close(tun_fd);
        return NULL;
    }
    devs[0] = vhost_scsi_dev_construct("vhost-scsi.0");
    if (!devs[0]) {
        fprintf(stderr, "Failed to create vhost SCSI device\n");
        close(tun_fd);
        return NULL;
    }
    /* Map a NVMe namespace to the vhost SCSI device */
    ret = vhost_scsi_dev_add_lun(devs[0], g_nvme_ns);
    if (ret != 0) {
        fprintf(stderr, "Failed to add NVMe namespace to vhost SCSI device\n");
        close(tun_fd);
        return NULL;
    }
    ret = vhost_scsi_ctrlr_add_dev(ctrlr, tun_fd, 1);
    if (ret == -1) {
        fprintf(stderr, "Failed to add vhost SCSI device\n");
        close(tun_fd);
        return NULL;
    }
    devs[1] = vhost_scsi_dev_construct("vhost-scsi.1");
    if (!devs[1]) {
        fprintf(stderr, "Failed to create vhost SCSI device\n");
        close(tun_fd);
        return NULL;
    }
    /* Map a NVMe namespace to the vhost SCSI device */
    ret = vhost_scsi_dev_add_lun(devs[1], g_nvme_ns);
    if (ret != 0) {
        fprintf(stderr, "Failed to add NVMe namespace to vhost SCSI device\n");
        close(tun_fd);
        return NULL;
    }
    /* Start the vhost SCSI controller */
    ret = vhost_scsi_ctrlr_start(ctrlr, &devs[0], g_num_ctrlr_devs);
    if (ret != 0) {
        fprintf(stderr, "Failed to start vhost SCSI controller\n");
        close(tun_fd);
        return NULL;
    }
    /* Run the vhost loop */
    vhost_user_start(vhost_fd);
    return NULL;
}
static void
ctrl_c_handler(int signum)
{
    spdk_nvme_detach(g_nvme_ctrlr);
    exit(1);
}
int main(int argc, char **argv)
{
    int ret;
    pthread_t vhost_thread;
    if (argc < 3) {
        fprintf(stderr, "Usage: %s nvme_device_name num_ctrlr_devs\n", argv[0]);
        exit(1);
    }
    strncpy(g_ctrlr_name[0], "vhost-scsi.0", sizeof(g_ctrlr_name[0]));
    strncpy(g_ctrlr_name[1], "vhost-scsi.1", sizeof(g_ctrlr_name[1]));
    g_num_ctrlr_devs = atoi(argv[2]);
    spdk_env_opts opts = {};
    spdk_env_init(&opts);
    signal(SIGINT, ctrl_c_handler);
    /* Connect to the NVMe device */
    ret = spdk_nvme_connect(NULL, argv[1], NULL, NULL, &g_nvme_ctrlr);
    if (ret != 0) {
        fprintf(stderr, "Failed to connect to NVMe device\n");
        return 1;
    }
    /* Open the first namespace on the NVMe device */
    g_nvme_ns = spdk_nvme_ctrlr_get_ns(g_nvme_ctrlr, 1);
    /* Start the vhost thread */
    pthread_create(&vhost_thread, NULL, vhost_start, NULL);
    /* Wait for the vhost thread to exit */
    pthread_join(vhost_thread, NULL);
    return 0;
}

