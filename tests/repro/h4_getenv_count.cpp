/* SPDX-License-Identifier: Apache-2.0 */
/*
 * H4 host leg: count getenv() calls made by the library across a fixed number
 * of operations, so the per-operation environment-lookup cost is a measured
 * number rather than an assumption.
 *
 * The counter lives in the fake_rga shim (tests/shim/fake_rga.c). It is
 * process-global and is flushed by a destructor to the path named by
 * FAKE_RGA_GETENV_COUNT, so each operation kind must be measured in its own
 * process. That is why this program takes a mode argument instead of running
 * both loops.
 *
 * The improcess mode replays the golden G1 geometry -- 4K NV16 -> NV12, IM_SYNC
 * -- so the profile leg and this leg exercise the same call.
 */
#define _GNU_SOURCE
#include <dlfcn.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mman.h>
#include <unistd.h>

#include "RgaApi.h"
#include "im2d.h"

namespace {

constexpr int kWidth = 3840;
constexpr int kHeight = 2160;
constexpr long kIterationsDefault = 1000;

/* The shim answers every ioctl, but the library still needs real descriptors
 * to wrap, and the request bytes encode the fd. Fixed targets keep the request
 * stable across iterations. */
int fixed_buffer(int target) {
    int fd = memfd_create("h4-buffer", MFD_CLOEXEC);
    if (fd < 0 || ftruncate(fd, 3840L * 2160 * 4) || dup2(fd, target) < 0) {
        perror("fixed buffer");
        return -1;
    }
    if (fd != target) close(fd);
    return target;
}

int run_blit(long iterations) {
    if (c_RkRgaInit()) {
        fprintf(stderr, "c_RkRgaInit failed\n");
        return 1;
    }
    for (long i = 0; i < iterations; ++i) {
        rga_info_t src = {}, dst = {};
        src.fd = 100;
        dst.fd = 101;
        src.mmuFlag = dst.mmuFlag = 1;
        rga_set_rect(&src.rect, 0, 0, kWidth, kHeight, kWidth, kHeight,
                     RK_FORMAT_YCbCr_422_SP);
        rga_set_rect(&dst.rect, 0, 0, kWidth, kHeight, kWidth, kHeight,
                     RK_FORMAT_YCbCr_420_SP);
        int ret = c_RkRgaBlit(&src, &dst, nullptr);
        if (ret) {
            fprintf(stderr, "c_RkRgaBlit failed at iteration %ld: %d\n", i, ret);
            c_RkRgaDeInit();
            return 1;
        }
    }
    c_RkRgaDeInit();
    return 0;
}

int run_improcess(long iterations) {
    rga_buffer_t src = wrapbuffer_fd(100, kWidth, kHeight, RK_FORMAT_YCbCr_422_SP,
                                     kWidth, kHeight);
    rga_buffer_t dst = wrapbuffer_fd(101, kWidth, kHeight, RK_FORMAT_YCbCr_420_SP,
                                     kWidth, kHeight);
    rga_buffer_t empty = {};
    im_rect empty_rect = {};
    for (long i = 0; i < iterations; ++i) {
        IM_STATUS ret = improcess(src, dst, empty, empty_rect, empty_rect,
                                  empty_rect, IM_SYNC);
        if (ret != IM_STATUS_SUCCESS) {
            fprintf(stderr, "improcess failed at iteration %ld: %s (%d)\n", i,
                    imStrError(ret), ret);
            return 1;
        }
    }
    return 0;
}

}  // namespace

int main(int argc, char **argv) {
    if (argc < 2 || argc > 3) {
        fprintf(stderr, "usage: h4_getenv_count blit|improcess [ITERATIONS]\n");
        return 2;
    }
    if (!dlsym(RTLD_DEFAULT, "fake_rga_active")) {
        fprintf(stderr, "Refusing hardware access: fake_rga preload is absent\n");
        return 1;
    }

    long iterations = kIterationsDefault;
    if (argc == 3) {
        char *end = nullptr;
        iterations = strtol(argv[2], &end, 10);
        if (!end || *end || iterations <= 0) {
            fprintf(stderr, "bad iteration count: %s\n", argv[2]);
            return 2;
        }
    }

    if (fixed_buffer(100) < 0 || fixed_buffer(101) < 0) return 1;

    int ret;
    if (!strcmp(argv[1], "blit")) {
        ret = run_blit(iterations);
    } else if (!strcmp(argv[1], "improcess")) {
        ret = run_improcess(iterations);
    } else {
        fprintf(stderr, "unknown mode: %s\n", argv[1]);
        return 2;
    }

    close(100);
    close(101);
    if (!ret) printf("%s: %ld operations completed\n", argv[1], iterations);
    return ret;
}
