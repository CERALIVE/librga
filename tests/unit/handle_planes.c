/* SPDX-License-Identifier: Apache-2.0 */
/* Modified by CeraLive 2026-09-19: reject synthesized plane offsets in handle requests. */
#include <dlfcn.h>
#include <inttypes.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include "im2d.h"
#include "rga_ioctl.h"

static int plane_ok(const char *name, const struct rga_img_info_t *plane,
                    uint64_t identity, uint64_t base, uint64_t offset)
{
    int ok = plane->yrgb_addr == identity && plane->uv_addr == base &&
             plane->v_addr == offset;
    printf("%s yrgb=%" PRIu64 " uv=%" PRIu64 " v=%" PRIu64
           " expected=%" PRIu64 ",%" PRIu64 ",%" PRIu64 " %s\n", name,
           (uint64_t)plane->yrgb_addr, (uint64_t)plane->uv_addr,
           (uint64_t)plane->v_addr, identity, base, offset, ok ? "PASS" : "FAIL");
    return ok;
}

int main(void)
{
    if (!dlsym(RTLD_DEFAULT, "fake_rga_active")) return 2;
    const char *dump = getenv("FAKE_RGA_DUMP");
    if (!dump || !*dump) return 2;
    int failures = 0;
    const struct { int width, height, src, dst, blend; } cases[] = {
        {256, 256, RK_FORMAT_RGBA_8888, RK_FORMAT_RGBA_8888, 0},
        {1920, 1080, RK_FORMAT_YCbCr_422_SP, RK_FORMAT_YCbCr_420_SP, 0},
        {3840, 2160, RK_FORMAT_YCbCr_422_SP, RK_FORMAT_YCbCr_420_SP, 0},
        {256, 256, RK_FORMAT_YCbCr_420_SP, RK_FORMAT_YCbCr_420_SP, 1},
    };
    for (unsigned c = 0; c < sizeof(cases) / sizeof(cases[0]); c++) {
        int w = cases[c].width, h = cases[c].height;
        int formats[] = {cases[c].src, cases[c].dst, RK_FORMAT_RGBA_8888};
        rga_buffer_handle_t handles[3];
        for (unsigned i = 0; i < 3; i++) {
            im_handle_param_t param = {0};
            param.width = w;
            param.height = h;
            param.format = formats[i];
            handles[i] = importbuffer_fd(100 + i, &param);
            if (!handles[i]) return 2;
        }
        /* FD and virtual-address controls preserve their original byte encoding. */
        for (unsigned mode = 0; mode < 3; mode++) {
            rga_buffer_t buffers[3];
            for (unsigned i = 0; i < 3; i++) {
                if (mode == 0)
                    buffers[i] = wrapbuffer_handle_t(handles[i], w, h, w, h, formats[i]);
                else if (mode == 1)
                    buffers[i] = wrapbuffer_fd_t(100 + i, w, h, w, h, formats[i]);
                else
                    buffers[i] = wrapbuffer_virtualaddr_t((void *)(uintptr_t)(0x10000000 + i * 0x1000000),
                                                          w, h, w, h, formats[i]);
            }
            if (!cases[c].blend) buffers[2] = (rga_buffer_t){0};
            for (unsigned opt = 0; opt < 2; opt++) {
                im_rect rect = {0};
                im_opt_t options = {0};
                options.version = RGA_CURRENT_API_HEADER_VERSION;
                int usage = IM_SYNC | (cases[c].blend ? IM_ALPHA_BLEND_SRC_OVER : 0);
                if (unlink(dump) && access(dump, F_OK) == 0) return 2;
                IM_STATUS status = opt ?
                    improcessOpt(buffers[0], buffers[1], buffers[2], rect, rect, rect,
                                 -1, NULL, &options, usage) :
                    improcess(buffers[0], buffers[1], buffers[2], rect, rect, rect, usage);
                struct rga_req request = {0};
                FILE *file = fopen(dump, "rb");
                int captured = file && fread(&request, sizeof(request), 1, file) == 1 &&
                               fgetc(file) == EOF;
                if (file) fclose(file);
                printf("case=%u mode=%u opt=%u status=%d captured=%d\n", c, mode, opt, status, captured);
                if (status != IM_STATUS_SUCCESS || !captured) { failures++; continue; }
                failures += (request.handle_flag & 1) != (mode == 0);
                const struct rga_img_info_t *planes[] = {&request.src, &request.dst, &request.pat};
                for (unsigned i = 0; i < (cases[c].blend ? 3u : 2u); i++) {
                    uint64_t base = mode == 2 ? 0x10000000 + i * 0x1000000 : 0;
                    uint64_t id = mode == 0 ? handles[i] : mode == 1 ? 100 + i : 0;
                    uint64_t offset = mode == 0 ? 0 : base + (uint64_t)w * h;
                    failures += !plane_ok(i == 0 ? "src" : i == 1 ? "dst" : "pat",
                                          planes[i], id, base, offset);
                }
            }
        }
        for (unsigned i = 0; i < 3; i++)
            if (releasebuffer_handle(handles[i]) != IM_STATUS_SUCCESS) return 2;
    }
    unlink(dump);
    return failures ? 1 : 0;
}
