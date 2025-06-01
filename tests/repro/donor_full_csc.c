/* SPDX-License-Identifier: Apache-2.0 */
/* Modified by CeraLive 2026-09-14: exercise combined source/destination CSC. */
#define _GNU_SOURCE
#include <dlfcn.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include "RgaApi.h"
#include "im2d.h"
#include "rga_ioctl.h"

/* The driver shim captures requests; it does not execute colour conversion. */
int main(void)
{
    if (!dlsym(RTLD_DEFAULT, "fake_rga_active")) {
        fprintf(stderr, "Refusing hardware access: fake_rga preload is absent\n");
        return 2;
    }
    const char *dump = getenv("FAKE_RGA_DUMP");
    if (!dump || !*dump || c_RkRgaInit()) return 2;
    rga_info_t src = {0}, pat = {0}, dst = {0};
    src.handle = 100;
    pat.handle = 101;
    dst.handle = 102;
    rga_set_rect(&src.rect, 0, 0, 64, 64, 64, 64, RK_FORMAT_YCbCr_420_SP);
    rga_set_rect(&pat.rect, 0, 0, 64, 64, 64, 64, RK_FORMAT_RGBA_8888);
    rga_set_rect(&dst.rect, 0, 0, 64, 64, 64, 64, RK_FORMAT_YCbCr_420_SP);

    /* 601-full YUV -> RGB on src0, RGB -> 709-full YUV on dst. */
    const int modes[] = {rgb2yuv_709_full, yuv2rgb_mode1 | rgb2yuv_709_full};
    int failures = 0;
    for (unsigned i = 0; i < sizeof(modes) / sizeof(modes[0]); ++i) {
        unlink(dump);
        dst.color_space_mode = modes[i];
        int ret = c_RkRgaBlit(&src, &dst, &pat);
        struct rga_req request = {0};
        FILE *file = fopen(dump, "rb");
        int captured = file && fread(&request, sizeof(request), 1, file) == 1;
        if (file) fclose(file);
        int pass = ret == 0 && captured && request.full_csc.flag == 1 &&
                   request.yuv2rgb_mode == (i == 0 ? 0 : yuv2rgb_mode1);
        printf("mode=0x%x ret=%d captured=%d full_csc=%u yuv2rgb=%u %s\n",
               modes[i], ret, captured, request.full_csc.flag,
               request.yuv2rgb_mode, pass ? "PASS" : "FAIL");
        failures += !pass;
    }
    c_RkRgaDeInit();
    rga_buffer_t input = wrapbuffer_handle(100, 64, 64, RK_FORMAT_YCbCr_420_SP, 64, 64);
    rga_buffer_t overlay = wrapbuffer_handle(101, 64, 64, RK_FORMAT_RGBA_8888, 64, 64);
    rga_buffer_t output = wrapbuffer_handle(102, 64, 64, RK_FORMAT_YCbCr_420_SP, 64, 64);
    imsetColorSpace(&input, IM_YUV_BT601_FULL_RANGE);
    imsetColorSpace(&overlay, IM_RGB_FULL);
    imsetColorSpace(&output, IM_YUV_BT709_FULL_RANGE);
    im_rect empty = {0};
    unlink(dump);
    IM_STATUS status = improcess(input, output, overlay, empty, empty, empty,
                                 IM_SYNC | IM_ALPHA_BLEND_SRC_OVER);
    struct rga_req request = {0};
    FILE *file = fopen(dump, "rb");
    int captured = file && fread(&request, sizeof(request), 1, file) == 1;
    if (file) fclose(file);
    int pass = status == IM_STATUS_SUCCESS && captured && request.full_csc.flag == 1 &&
               request.yuv2rgb_mode == (IM_YUV_TO_RGB_BT601_FULL | IM_RGB_TO_YUV_BT601_LIMIT);
    printf("improcess src601full+patRGB+dst709full status=%d captured=%d "
           "full_csc=%u yuv2rgb=%u %s\n", status, captured,
           request.full_csc.flag, request.yuv2rgb_mode, pass ? "PASS" : "FAIL");
    failures += !pass;
    return failures ? 1 : 0;
}
