/* SPDX-License-Identifier: Apache-2.0 */
/* Modified by CeraLive 2026-09-14: exercise combined source/destination CSC. */
/* Modified by CeraLive 2026-09-15: pin full709's selector and unchanged CSC controls. */
#ifndef _GNU_SOURCE
#define _GNU_SOURCE
#endif
#include <dlfcn.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include "RgaApi.h"
#include "im2d_buffer.h"
#include "im2d_single.h"
#include "rga_ioctl.h"

static int full709_coefficients(const struct rga_req *r)
{
    return r->full_csc.flag == 1 && r->feature.full_csc_clip_en == 1 &&
           r->full_csc.coe_y.r_v == 218 && r->full_csc.coe_y.g_y == 731 &&
           r->full_csc.coe_y.b_u == 74 && r->full_csc.coe_y.off == 0 &&
           r->full_csc.coe_u.r_v == -117 && r->full_csc.coe_u.g_y == -393 &&
           r->full_csc.coe_u.b_u == 512 && r->full_csc.coe_u.off == 130944 &&
           r->full_csc.coe_v.r_v == 512 && r->full_csc.coe_v.g_y == -463 &&
           r->full_csc.coe_v.b_u == -46 && r->full_csc.coe_v.off == 130944;
}

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
    /* Full709 must clear only R2Y, preserving the source's independent Y2R. */
    int pass = status == IM_STATUS_SUCCESS && captured && full709_coefficients(&request) &&
               request.yuv2rgb_mode == IM_YUV_TO_RGB_BT601_FULL;
    printf("improcess src601full+patRGB+dst709full status=%d captured=%d "
           "full_csc=%u yuv2rgb=%u %s\n", status, captured,
           request.full_csc.flag, request.yuv2rgb_mode, pass ? "PASS" : "FAIL");
    failures += !pass;

    const struct { const char *name; IM_COLOR_SPACE_MODE space; unsigned selector, full; } cases[] = {
        {"default", IM_COLOR_SPACE_DEFAULT, 8, 0},
        {"601-limited", IM_YUV_BT601_LIMIT_RANGE, 8, 0},
        {"601-full", IM_YUV_BT601_FULL_RANGE, 4, 0},
        {"709-limited", IM_YUV_BT709_LIMIT_RANGE, 12, 1},
        {"709-full", IM_YUV_BT709_FULL_RANGE, 0, 1},
    };
    const int formats[] = {RK_FORMAT_BGR_888, RK_FORMAT_RGB_888};
    for (unsigned f = 0; f < sizeof(formats) / sizeof(formats[0]); ++f) {
        for (unsigned i = 0; i < sizeof(cases) / sizeof(cases[0]); ++i) {
            rga_buffer_t s = wrapbuffer_fd(100, 1280, 720, formats[f], 1280, 720);
            rga_buffer_t d = wrapbuffer_fd(101, 1280, 720, RK_FORMAT_YCbCr_420_SP, 1280, 720);
            rga_buffer_t no_overlay = {0};
            if (cases[i].space) {
                imsetColorSpace(&s, IM_RGB_FULL);
                imsetColorSpace(&d, cases[i].space);
            }
            unlink(dump);
            status = improcess(s, d, no_overlay, empty, empty, empty, IM_SYNC);
            struct rga_req r = {0};
            file = fopen(dump, "rb");
            captured = file && fread(&r, sizeof(r), 1, file) == 1 && fgetc(file) == EOF;
            if (file) fclose(file);
            pass = status == IM_STATUS_SUCCESS && captured &&
                   r.yuv2rgb_mode == cases[i].selector && r.full_csc.flag == cases[i].full &&
                   (cases[i].space != IM_YUV_BT709_FULL_RANGE || full709_coefficients(&r));
            printf("improcess format=%x %s status=%d captured=%d full_csc=%u "
                   "selector=%u expected=%u %s\n", formats[f], cases[i].name, status,
                   captured, r.full_csc.flag, r.yuv2rgb_mode, cases[i].selector,
                   pass ? "PASS" : "FAIL");
            failures += !pass;
        }
    }
    return failures ? 1 : 0;
}
