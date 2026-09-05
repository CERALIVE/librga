/* SPDX-License-Identifier: Apache-2.0 */
#define _GNU_SOURCE
#include <dlfcn.h>
#include <fcntl.h>
#include <stddef.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mman.h>
#include <unistd.h>
#include "im2d.h"
#include "RgaApi.h"
#include "rga_ioctl.h"

static int verify(const char *name, const char *dump, const char *fixture)
{
    FILE *actual = fopen(dump, "rb"), *expected = fopen(fixture, "r");
    if (!actual || !expected) { perror("golden input"); return 1; }
    for (size_t offset = 0; offset < sizeof(struct rga_req); ++offset) {
        unsigned int byte;
        int got = fgetc(actual);
        if (fscanf(expected, "%2x", &byte) != 1 || got == EOF || got != (int)byte) {
            const char *field = "rga_req";
            if (offset >= offsetof(struct rga_req, src) + offsetof(rga_img_info_t, act_w) &&
                offset < offsetof(struct rga_req, src) + offsetof(rga_img_info_t, endian_mode))
                field = "rga_req.src rect (act_w/act_h/x_offset/y_offset/vir_w/vir_h)";
            fprintf(stderr, "%s: byte mismatch at offset %zu (0x%zx), %s\n",
                    name, offset, offset, field);
            return 1;
        }
    }
    unsigned int extra;
    if (fgetc(actual) != EOF || fscanf(expected, "%x", &extra) != EOF) {
        fprintf(stderr, "%s: expected exactly %zu request bytes\n", name, sizeof(struct rga_req));
        return 1;
    }
    fclose(actual);
    fclose(expected);
    printf("%s: PASS (%zu verbatim request bytes)\n", name, sizeof(struct rga_req));
    return 0;
}

static int fixed_buffer(int target)
{
    int fd = memfd_create("golden-buffer", MFD_CLOEXEC);
    if (fd < 0 || ftruncate(fd, 3840L * 2160 * 4) || dup2(fd, target) < 0) {
        perror("fixed buffer"); return -1;
    }
    if (fd != target) close(fd);
    return target;
}

int main(int argc, char **argv)
{
    if (argc == 5 && !strcmp(argv[1], "--verify"))
        return verify(argv[2], argv[3], argv[4]);
    if (argc != 2 || strlen(argv[1]) != 2 || argv[1][0] != 'G' ||
        argv[1][1] < '1' || argv[1][1] > '8') return 2;
    if (!dlsym(RTLD_DEFAULT, "fake_rga_active")) {
        fprintf(stderr, "Refusing hardware access: fake_rga preload is absent\n");
        return 1;
    }
    int number = argv[1][1] - '0';
    if (fixed_buffer(100) < 0 || fixed_buffer(101) < 0) return 1;

    int sw = 3840, sh = 2160, dw = 3840, dh = 2160;
    int format = RK_FORMAT_YCbCr_422_SP;
    int usage = IM_SYNC;
    im_rect crop = {0}, empty_rect = {0};
    rga_buffer_t empty = {0};
    if (number == 2) {
        sw = sh = dw = dh = 64;
        format = RK_FORMAT_YCbCr_420_SP;
    } else if (number == 3 || number == 4 || number == 8) {
        sw = 1920; sh = 1080; dw = 1280; dh = 720;
        format = number == 8 ? RK_FORMAT_RGB_888 : RK_FORMAT_BGR_888;
        if (number == 3) crop = (im_rect){8, 8, 1280, 720};
    } else if (number == 5) {
        sw = 1280; sh = 720; dw = 720; dh = 1280;
        format = RK_FORMAT_YCbCr_420_SP;
        usage |= IM_HAL_TRANSFORM_ROT_90;
    }
    if (number == 6) {
        if (imconfig(IM_CONFIG_SCHEDULER_CORE, IM_SCHEDULER_RGA3_CORE1) != IM_STATUS_SUCCESS ||
            imconfig(IM_CONFIG_PRIORITY, 3) != IM_STATUS_SUCCESS) return 1;
    }
    if (number == 7) {
        if (c_RkRgaInit()) return 1;
        rga_info_t src = {0}, dst = {0};
        src.fd = 100; dst.fd = 101;
        src.mmuFlag = dst.mmuFlag = 1;
        rga_set_rect(&src.rect, 0, 0, sw, sh, sw, sh, format);
        rga_set_rect(&dst.rect, 0, 0, dw, dh, dw, dh, RK_FORMAT_YCbCr_420_SP);
        int ret = c_RkRgaBlit(&src, &dst, NULL);
        c_RkRgaDeInit();
        return ret ? 1 : 0;
    }
    rga_buffer_t src = wrapbuffer_fd(100, sw, sh, format, sw, sh);
    rga_buffer_t dst = wrapbuffer_fd(101, dw, dh, RK_FORMAT_YCbCr_420_SP, dw, dh);
    if (number == 8) {
        imsetColorSpace(&src, IM_RGB_FULL);
        imsetColorSpace(&dst, IM_YUV_BT709_LIMIT_RANGE);
    }
    IM_STATUS ret = improcess(src, dst, empty, crop, empty_rect, empty_rect, usage);
    if (ret != IM_STATUS_SUCCESS) {
        fprintf(stderr, "%s: improcess failed: %s (%d)\n", argv[1], imStrError(ret), ret);
        return 1;
    }
    close(100); close(101);
    return 0;
}
