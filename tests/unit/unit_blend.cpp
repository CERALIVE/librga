/* SPDX-License-Identifier: Apache-2.0 */
// Modified by CeraLive 2026-09-16: guard the inherited three-channel blend fix.
#include <cstdio>
#include <cstring> // IWYU pragma: keep
#include <dlfcn.h>

#include "im2d.h" // IWYU pragma: keep
#include "unit_assert.h"

static const im_rect NO_RECT = { 0, 0, 0, 0 };

int main(void)
{
    if (!dlsym(RTLD_DEFAULT, "fake_rga_active")) {
        fprintf(stderr, "Refusing hardware access: fake_rga preload is absent\n");
        return 2;
    }

    /* imcheck reads descriptors, not pixels; only device discovery is shimmed. */
    unsigned char pixel = 0;
    rga_buffer_t src = wrapbuffer_virtualaddr(&pixel, 1920, 1080,
                                             RK_FORMAT_YCbCr_420_SP, 1920, 1088);
    rga_buffer_t dst = src;
    rga_buffer_t pat = wrapbuffer_virtualaddr(&pixel, 960, 540,
                                             RK_FORMAT_BGRA_8888, 960, 544);
    rga_buffer_t absent = {};
    const im_rect inset = { 864, 54, 960, 540 };
    const int blend = IM_ALPHA_BLEND_DST_OVER | IM_SYNC;

    unit_begin("RGB pattern with NV12 destination (real imcheck_t)");
    unit_eq_int("NV12 + BGRA -> NV12, equal active dimensions", IM_STATUS_NOERROR,
                imcheck_t(src, dst, pat, inset, inset, NO_RECT, blend));
    pat.format = RK_FORMAT_RGBA_8888;
    unit_eq_int("NV12 + RGBA -> NV12", IM_STATUS_NOERROR,
                imcheck_t(src, dst, pat, inset, inset, NO_RECT, blend));
    src.format = RK_FORMAT_BGRA_8888;
    unit_eq_int("BGRA + RGBA -> NV12", IM_STATUS_NOERROR,
                imcheck_t(src, dst, pat, inset, inset, NO_RECT, blend));
    src.format = RK_FORMAT_YCbCr_420_SP;

    unit_begin("background channel and geometry negative controls");
    unit_eq_int("two-channel NV12 background remains unsupported", IM_STATUS_NOT_SUPPORTED,
                imcheck_t(src, dst, absent, inset, inset, NO_RECT, blend));
    pat.format = RK_FORMAT_YCbCr_420_SP;
    unit_eq_int("three-channel NV12 pattern remains unsupported", IM_STATUS_NOT_SUPPORTED,
                imcheck_t(src, dst, pat, inset, inset, NO_RECT, blend));
    dst.format = RK_FORMAT_BGRA_8888;
    unit_eq_int("RGB output does not make an NV12 pattern valid", IM_STATUS_NOT_SUPPORTED,
                imcheck_t(src, dst, pat, inset, inset, NO_RECT, blend));
    unit_eq_int("two-channel RGB background remains supported", IM_STATUS_NOERROR,
                imcheck_t(src, dst, absent, inset, inset, NO_RECT, blend));
    dst.format = RK_FORMAT_YCbCr_420_SP;
    pat.format = RK_FORMAT_BGRA_8888;
    pat.width = 944;
    unit_eq_int("RGB pattern active width must equal destination", IM_STATUS_NOT_SUPPORTED,
                imcheck_t(src, dst, pat, inset, inset, NO_RECT, blend));
    pat.width = 960;
    pat.height = 538;
    unit_eq_int("RGB pattern active height must equal destination", IM_STATUS_NOT_SUPPORTED,
                imcheck_t(src, dst, pat, inset, inset, NO_RECT, blend));

    pat = wrapbuffer_virtualaddr(&pixel, 1920, 1080,
                                 RK_FORMAT_BGRA_8888, 1920, 1088);
    unit_eq_int("uncropped full-size pattern cannot scale to inset", IM_STATUS_NOT_SUPPORTED,
                imcheck_t(src, dst, pat, inset, inset, NO_RECT, blend));
    const im_rect crop = { 0, 0, 960, 540 };
    unit_eq_int("pattern crop selects active dimensions, not a scale", IM_STATUS_NOERROR,
                imcheck_t(src, dst, pat, inset, inset, crop, blend));

    return unit_report("blend-validation");
}
