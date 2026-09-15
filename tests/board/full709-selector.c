/* SPDX-License-Identifier: Apache-2.0 */
/* Modified by CeraLive 2026-09-15: isolate full709's selector on real hardware. */
#define _GNU_SOURCE
#include <dlfcn.h>
#include <errno.h>
#include <linux/dma-buf.h>
#include <stdarg.h>
#include <stddef.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mman.h>
#include <sys/stat.h>
#include <unistd.h>
#include "rga_ioctl.h"

static int (*next_ioctl)(int, unsigned long, ...);
static unsigned calls, full_calls;

static void refuse(const char *why)
{
    fprintf(stderr, "selector probe refused: %s (errno=%d)\n", why, errno);
    exit(125);
}

static void dump(unsigned id, const char *kind, const void *data, size_t size)
{
    const char *dir = getenv("RGA_SELECTOR_DIR");
    char path[1024];
    if (!dir || snprintf(path, sizeof(path), "%s/%03u-%s.bin", dir, id, kind) >= (int)sizeof(path))
        refuse("missing/overlong output directory");
    FILE *f = fopen(path, "wbx");
    if (!f || fwrite(data, size, 1, f) != 1 || fclose(f)) refuse("write capture");
}

static void counters(unsigned long long counts[3])
{
    for (int core = 0; core < 3; ++core) {
        char path[128];
        snprintf(path, sizeof(path), "/sys/kernel/debug/rockchip-rga/cores/%d/tasks", core);
        FILE *f = fopen(path, "r");
        if (!f || fscanf(f, "%llu", &counts[core]) != 1 || fclose(f)) refuse("core counter");
    }
}

static void buffer_dump(unsigned id, const char *kind, uint64_t address, size_t size)
{
    if (address > 1024) refuse("expected direct DMA-BUF fd");
    int fd = (int)address;
    struct stat st;
    if (fstat(fd, &st) || (uint64_t)st.st_size < size) refuse("DMA-BUF size");
    void *p = mmap(NULL, size, PROT_READ, MAP_SHARED, fd, 0);
    if (p == MAP_FAILED) refuse("map capture");
    struct dma_buf_sync sync = {.flags = DMA_BUF_SYNC_START | DMA_BUF_SYNC_READ};
    if (next_ioctl(fd, DMA_BUF_IOCTL_SYNC, &sync)) refuse("capture read start");
    dump(id, kind, p, size);
    sync.flags = DMA_BUF_SYNC_END | DMA_BUF_SYNC_READ;
    if (next_ioctl(fd, DMA_BUF_IOCTL_SYNC, &sync) || munmap(p, size)) refuse("capture read end");
    fprintf(stderr, "BUFFER id=%u kind=%s fd=%d dev=%llu inode=%llu size=%zu\n",
            id, kind, fd, (unsigned long long)st.st_dev, (unsigned long long)st.st_ino, size);
}

static int full709(const struct rga_req *r)
{
    return r->full_csc.flag == 1 && r->feature.full_csc_clip_en == 1 &&
           r->full_csc.coe_y.r_v == 218 && r->full_csc.coe_y.g_y == 731 &&
           r->full_csc.coe_y.b_u == 74 && r->full_csc.coe_y.off == 0 &&
           r->full_csc.coe_u.r_v == -117 && r->full_csc.coe_u.g_y == -393 &&
           r->full_csc.coe_u.b_u == 512 && r->full_csc.coe_u.off == 130944 &&
           r->full_csc.coe_v.r_v == 512 && r->full_csc.coe_v.g_y == -463 &&
           r->full_csc.coe_v.b_u == -46 && r->full_csc.coe_v.off == 130944;
}

/* Single-threaded, synchronous G-A client only; every ioctl has a third argument. */
int ioctl(int fd, unsigned long command, ...)
{
    va_list ap;
    va_start(ap, command);
    void *arg = va_arg(ap, void *);
    va_end(ap);
    if (!next_ioctl) {
        *(void **)(&next_ioctl) = dlsym(RTLD_NEXT, "ioctl");
        if (!next_ioctl || dlsym(RTLD_DEFAULT, "fake_rga_active")) refuse("not a real forwarding chain");
    }
    char path[64], target[128];
    snprintf(path, sizeof(path), "/proc/self/fd/%d", fd);
    ssize_t n = readlink(path, target, sizeof(target) - 1);
    if (n < 0) return next_ioctl(fd, command, arg);
    target[n] = '\0';
    if (strcmp(target, "/dev/rga")) return next_ioctl(fd, command, arg);
    const char *admitted = getenv("CERALIVE_BOARD_TEST");
    if (!admitted || strcmp(admitted, "1")) refuse("board not admitted");
    if (command != RGA_BLIT_SYNC) return next_ioctl(fd, command, arg);
    if (!arg || ++calls > 36) refuse("unexpected request count");

    struct rga_req original, forwarded;
    memcpy(&original, arg, sizeof(original));
    memcpy(&forwarded, arg, sizeof(forwarded));
    int bgr = original.src.format == 7 && original.dst.format == 10 &&
              original.src.act_w == 1280 && original.src.act_h == 720 &&
              original.dst.act_w == 1280 && original.dst.act_h == 720;
    int selected = full709(&original);
    if (selected) {
        const char *sequence = getenv("RGA_FULL709_SEQUENCE");
        const char *expected = getenv("RGA_FULL709_EXPECT");
        if (!bgr || !sequence || strlen(sequence) != 4 || strspn(sequence, "08") != 4 ||
            !expected || (strcmp(expected, "0") && strcmp(expected, "8")) ||
            original.yuv2rgb_mode != (unsigned)(expected[0] - '0') || full_calls >= 4)
            refuse("unexpected full709 request/sequence");
        forwarded.yuv2rgb_mode = (unsigned)(sequence[full_calls++] - '0');
    }
    dump(calls, "original", &original, sizeof(original));
    dump(calls, "forwarded", &forwarded, sizeof(forwarded));
    if (bgr) buffer_dump(calls, "input", original.src.yrgb_addr, 1280 * 720 * 3);
    unsigned long long before[3], after[3];
    counters(before);
    memcpy(arg, &forwarded, sizeof(forwarded));
    int rc = next_ioctl(fd, command, arg);
    int saved_errno = errno;
    counters(after);
    if (!rc && bgr) buffer_dump(calls, "output", original.dst.yrgb_addr, 1280 * 720 * 3 / 2);
    fprintf(stderr, "REQUEST id=%u full709=%d selector=%u->%u offset=%zu size=%zu "
            "core_mask=%u delta=%llu/%llu/%llu rc=%d errno=%d\n", calls, selected,
            original.yuv2rgb_mode, forwarded.yuv2rgb_mode,
            offsetof(struct rga_req, yuv2rgb_mode), sizeof(original), original.core,
            after[0] - before[0], after[1] - before[1], after[2] - before[2], rc, saved_errno);
    errno = saved_errno;
    return rc;
}
