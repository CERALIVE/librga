/* SPDX-License-Identifier: Apache-2.0 */
/*
 * H9(a) — does a virtual address above 2^32 survive the trip into the request
 * bytes the library hands to the driver?
 *
 * The library builds its request through NormalRgaSet{Src,Dst}VirtualInfo. On
 * aarch64 the address is cast to `unsigned long`; on every other target the
 * `#else` arm of the same `#if defined(__arm64__) || defined(__aarch64__)`
 * casts it to `unsigned int` (core/NormalRga.cpp, and again inside
 * im2d_api/src/im2d_impl.cpp). The destination field, `rga_req.src.yrgb_addr`,
 * is a `uint64_t`. This program pins a buffer at a deliberately high address,
 * submits it, and reads back what actually landed in that field.
 *
 * No hardware is touched: tests/shim/fake_rga.c interposes open()/ioctl() and
 * dumps the raw request bytes to $FAKE_RGA_DUMP.
 */
#include <assert.h>
#include <dlfcn.h>
#include <errno.h>
#include <inttypes.h>
#include <stddef.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mman.h>
#include <unistd.h>

#include "im2d.h"
#include "rga_ioctl.h"

static const int kWidth = 1280;
static const int kHeight = 720;
static const size_t kSize = (size_t)kWidth * kHeight * 4;

/* Walk 0x7f… down to 0x1f…, taking the first address the kernel will grant. */
static void *map_high(uintptr_t *granted)
{
    for (uintptr_t want = 0x7f0000000000UL; want >= 0x1f0000000000UL;
         want -= 0x100000000000UL) {
        void *p = mmap((void *)want, kSize, PROT_READ | PROT_WRITE,
                       MAP_PRIVATE | MAP_ANONYMOUS | MAP_FIXED_NOREPLACE, -1, 0);
        if (p != MAP_FAILED) {
            printf("h9-address: mmap granted %p (requested 0x%" PRIxPTR ")\n", p, want);
            assert(p == (void *)want);
            assert((uintptr_t)p > 4294967296UL);
            *granted = want;
            return p;
        }
        printf("h9-address: mmap 0x%" PRIxPTR " refused: %s\n", want, strerror(errno));
    }
    return NULL;
}

static unsigned char *slurp(const char *path, size_t *size)
{
    FILE *f = fopen(path, "rb");
    if (!f) { perror("open dump"); return NULL; }
    if (fseek(f, 0, SEEK_END)) { fclose(f); return NULL; }
    long end = ftell(f);
    rewind(f);
    unsigned char *bytes = (unsigned char *)malloc((size_t)end);
    if (!bytes || fread(bytes, 1, (size_t)end, f) != (size_t)end) {
        fclose(f); free(bytes); return NULL;
    }
    fclose(f);
    *size = (size_t)end;
    return bytes;
}

int main(void)
{
    if (!dlsym(RTLD_DEFAULT, "fake_rga_active")) {
        fprintf(stderr, "h9-address: refusing to run without the fake_rga preload\n");
        return 1;
    }
    const char *dump = getenv("FAKE_RGA_DUMP");
    if (!dump) { fprintf(stderr, "h9-address: FAKE_RGA_DUMP unset\n"); return 2; }

    uintptr_t want = 0;
    void *base = map_high(&want);
    if (!base) { fprintf(stderr, "h9-address: no high address available\n"); return 1; }
    memset(base, 0, kSize);

    /*
     * The mapping base has zero low 32 bits, which would make "full value" and
     * "low 32 bits only" indistinguishable. Offset into the same mapping so the
     * two hypotheses produce different numbers.
     */
    void *src_addr = (char *)base + 0x12340;
    want += 0x12340;
    printf("h9-address: submitting %p (full 0x%" PRIxPTR ", low32 0x%08" PRIx32 ")\n",
           src_addr, want, (uint32_t)want);

    void *dst_addr = mmap(NULL, kSize, PROT_READ | PROT_WRITE,
                          MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
    if (dst_addr == MAP_FAILED) { perror("dst mmap"); return 1; }

    rga_buffer_t src = wrapbuffer_virtualaddr_t(src_addr, kWidth, kHeight,
                                                kWidth, kHeight, RK_FORMAT_RGBA_8888);
    rga_buffer_t dst = wrapbuffer_virtualaddr_t(dst_addr, kWidth, kHeight,
                                                kWidth, kHeight, RK_FORMAT_RGBA_8888);
    rga_buffer_t pat;
    im_rect nothing;
    memset(&pat, 0, sizeof(pat));
    memset(&nothing, 0, sizeof(nothing));

    IM_STATUS ret = improcess(src, dst, pat, nothing, nothing, nothing, IM_SYNC);
    printf("h9-address: improcess returned %d (%s)\n", ret, imStrError(ret));

    size_t size = 0;
    unsigned char *bytes = slurp(dump, &size);
    if (!bytes) { fprintf(stderr, "h9-address: dump unreadable\n"); return 1; }
    printf("h9-address: dump is %zu bytes, sizeof(struct rga_req)=%zu\n",
           size, sizeof(struct rga_req));

    uint64_t full = (uint64_t)want;
    uint32_t low = (uint32_t)want;

    /* Field-accurate read: the trailing rga_req in the dump is the submitted one. */
    if (size >= sizeof(struct rga_req)) {
        struct rga_req req;
        memcpy(&req, bytes + size - sizeof(struct rga_req), sizeof(req));
        printf("h9-address: rga_req.src.yrgb_addr = 0x%016" PRIx64 "\n",
               (uint64_t)req.src.yrgb_addr);
        printf("h9-address: rga_req.src.uv_addr   = 0x%016" PRIx64 "\n",
               (uint64_t)req.src.uv_addr);
        printf("h9-address: rga_req.dst.yrgb_addr = 0x%016" PRIx64 "\n",
               (uint64_t)req.dst.yrgb_addr);
        printf("h9-address: rga_req.dst.uv_addr   = 0x%016" PRIx64 "\n",
               (uint64_t)req.dst.uv_addr);

        uint64_t carried = req.src.yrgb_addr == full || req.src.yrgb_addr == (uint64_t)low
                           ? req.src.yrgb_addr : req.src.uv_addr;
        const char *field = req.src.yrgb_addr == full || req.src.yrgb_addr == (uint64_t)low
                            ? "src.yrgb_addr" : "src.uv_addr";
        if (carried == full)
            printf("h9-address: VERDICT %s holds the FULL 64-bit pointer\n", field);
        else if (carried == (uint64_t)low)
            printf("h9-address: VERDICT %s holds ONLY the low 32 bits "
                   "(0x%08" PRIx32 "), upper bits lost\n", field, low);
        else
            printf("h9-address: VERDICT no request field holds the pointer or its "
                   "low 32 bits\n");
    }

    /* Independent of any struct layout: scan the raw stream for both encodings. */
    size_t full_hits = 0, low_hits = 0;
    for (size_t i = 0; i + 8 <= size; ++i) {
        uint64_t v;
        memcpy(&v, bytes + i, 8);
        if (v == full) {
            ++full_hits;
            printf("h9-address: full 64-bit value at dump offset %zu\n", i);
        }
    }
    for (size_t i = 0; i + 4 <= size; ++i) {
        uint32_t v;
        memcpy(&v, bytes + i, 4);
        if (v == low) {
            ++low_hits;
            printf("h9-address: low 32-bit value at dump offset %zu\n", i);
        }
    }
    printf("h9-address: offsetof(rga_req, src.yrgb_addr)=%zu, dst.yrgb_addr=%zu\n",
           offsetof(struct rga_req, src) + offsetof(rga_img_info_t, yrgb_addr),
           offsetof(struct rga_req, dst) + offsetof(rga_img_info_t, yrgb_addr));
    printf("h9-address: raw scan — 8-byte matches of 0x%016" PRIx64 ": %zu; "
           "4-byte matches of 0x%08" PRIx32 ": %zu\n", full, full_hits, low, low_hits);

    free(bytes);
    return 0;
}
