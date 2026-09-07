/* SPDX-License-Identifier: Apache-2.0 */
/*
 * unit-pure: hardware-independent characterization of librga paths that touch
 * no RGA session and therefore never open /dev/rga. These run with NO shim.
 *
 * Covered here:
 *   (a) core/RgaUtils.cpp get_bpp_from_format / get_perPixel_stride_from_format
 *   (d) im2d_api/src/im2d_impl.cpp rga_version_compare and the ">= 1.3.0"
 *       user-close-fence predicate from im2d_api/src/im2d_context.cpp:39-44
 *   (e) include/drmrga.h rga_set_rect
 *
 * Every expectation below was READ OUT OF THE SOURCE AT THIS COMMIT and states
 * what librga does TODAY. Where today's behaviour is a defect it is asserted
 * anyway and marked, so a later fix has to change the test deliberately.
 */
#include <cerrno>
#include <cstring>
#include <dlfcn.h>

#include "RgaUtils.h"
#include "rga.h"
#include "drmrga.h"
#include "im2d.h"
#include "im2d_impl.h"

#include "unit_assert.h"

/* ---------------------------------------------------------------- (a) ---- */

/*
 * The twelve formats the CeraLive GStreamer path declares, in the plugin's own
 * naming, mapped to the RK_FORMAT_* the tables actually switch on.
 *
 * bpp values: core/RgaUtils.cpp:152-244 (get_bpp_from_format_impl).
 * stride values: core/RgaUtils.cpp:246-321
 * (get_perPixel_stride_from_format_impl) -- these are BITS PER PIXEL, not
 * bytes: the function multiplies by 8 internally and rga_check_align()
 * consumes it as a bit count (im2d_impl.cpp:1141-1148). The literals below
 * pin that unit so a "tidy-up" to bytes is caught.
 */
struct format_row {
    const char *name;
    int format;
    float bpp;
    int stride_bits;
};

static const format_row plugin_formats[] = {
    { "NV12",  RK_FORMAT_YCbCr_420_SP, 1.5f,  8 },
    { "NV16",  RK_FORMAT_YCbCr_422_SP, 2.0f,  8 },
    { "NV21",  RK_FORMAT_YCrCb_420_SP, 1.5f,  8 },
    { "NV61",  RK_FORMAT_YCrCb_422_SP, 2.0f,  8 },
    { "I420",  RK_FORMAT_YCbCr_420_P,  1.5f,  8 },
    { "YUY2",  RK_FORMAT_YUYV_422,     2.0f, 16 },
    { "UYVY",  RK_FORMAT_UYVY_422,     2.0f, 16 },
    { "BGR",   RK_FORMAT_BGR_888,      3.0f, 24 },
    { "RGB",   RK_FORMAT_RGB_888,      3.0f, 24 },
    { "BGRA",  RK_FORMAT_BGRA_8888,    4.0f, 32 },
    { "RGBA",  RK_FORMAT_RGBA_8888,    4.0f, 32 },
    { "RGB16", RK_FORMAT_RGB_565,      2.0f, 16 },
};

static void check_format_tables(void)
{
    unit_begin("(a) format bpp and per-pixel stride tables");

    for (unsigned i = 0; i < sizeof(plugin_formats) / sizeof(plugin_formats[0]); ++i) {
        const format_row &row = plugin_formats[i];
        char subject[64];

        snprintf(subject, sizeof(subject), "%s bpp", row.name);
        unit_eq_bpp(subject, row.bpp, get_bpp_from_format(row.format));

        snprintf(subject, sizeof(subject), "%s per-pixel stride (bits)", row.name);
        unit_eq_int(subject, row.stride_bits, get_perPixel_stride_from_format(row.format));
    }

    /*
     * KNOWN: validation gap, see fix-audit
     *
     * Neither accessor can report failure: an unrecognised format falls through
     * the switch default and returns 0 after a printf, indistinguishable from a
     * legitimate zero. get_buf_size_by_w_h_f() then computes a zero-byte buffer
     * size from it. -1 is used here as a stand-in for any unmapped value.
     */
    unit_eq_bpp("invalid format (-1) bpp", 0.0f, get_bpp_from_format(-1));
    unit_eq_int("invalid format (-1) per-pixel stride (bits)", 0,
                get_perPixel_stride_from_format(-1));

    /* RK_FORMAT_UNKNOWN is the library's own sentinel and takes the same path. */
    unit_eq_bpp("RK_FORMAT_UNKNOWN bpp", 0.0f, get_bpp_from_format(RK_FORMAT_UNKNOWN));
    unit_eq_int("RK_FORMAT_UNKNOWN per-pixel stride (bits)", 0,
                get_perPixel_stride_from_format(RK_FORMAT_UNKNOWN));
}

/* ---------------------------------------------------------------- (d) ---- */

static struct rga_version_t version_of(uint32_t major, uint32_t minor, uint32_t revision)
{
    struct rga_version_t v;
    memset(&v, 0, sizeof(v));
    v.major = major;
    v.minor = minor;
    v.revision = revision;
    return v;
}

/*
 * im2d_context.cpp:41-44
 *
 *   static void set_driver_feature(rga_session_t *session) {
 *       if (rga_version_compare(session->driver_verison, (struct rga_version_t){ 1, 3, 0, {0} }) >= 0)
 *           session->driver_feature |= RGA_DRIVER_FEATURE_USER_CLOSE_FENCE;
 *   }
 *
 * set_driver_feature() is static and needs a live session, so the predicate is
 * reproduced here verbatim over rga_version_compare(), which is the part that
 * decides. The session-side consequence is covered by unit-session.
 */
static bool user_close_fence_granted(struct rga_version_t driver)
{
    return rga_version_compare(driver, version_of(1, 3, 0)) >= 0;
}

static void check_version_predicates(void)
{
    unit_begin("(d) rga_version_compare and the >= 1.3.0 user-close-fence fence");

    const struct rga_version_t v124  = version_of(1, 2, 4);
    const struct rga_version_t v130  = version_of(1, 3, 0);
    const struct rga_version_t v1311 = version_of(1, 3, 11);
    const struct rga_version_t v1313 = version_of(1, 3, 13);

    /* im2d_impl.cpp:115-126 returns exactly 1 / 0 / -1, never a difference. */
    unit_eq_int("compare 1.2.4 vs 1.3.0", -1, rga_version_compare(v124, v130));
    unit_eq_int("compare 1.3.0 vs 1.2.4", 1, rga_version_compare(v130, v124));
    unit_eq_int("compare 1.3.0 vs 1.3.0", 0, rga_version_compare(v130, v130));
    unit_eq_int("compare 1.3.11 vs 1.3.0", 1, rga_version_compare(v1311, v130));
    unit_eq_int("compare 1.3.0 vs 1.3.11", -1, rga_version_compare(v130, v1311));
    unit_eq_int("compare 1.3.13 vs 1.3.11", 1, rga_version_compare(v1313, v1311));
    unit_eq_int("compare 1.3.11 vs 1.3.13", -1, rga_version_compare(v1311, v1313));
    unit_eq_int("compare 1.3.13 vs 1.3.13", 0, rga_version_compare(v1313, v1313));

    /*
     * Revisions are compared numerically, not lexically: 1.3.11 is NEWER than
     * 1.3.2 even though "11" sorts before "2" as text.
     */
    unit_eq_int("compare 1.3.11 vs 1.3.2 (numeric, not lexical)", 1,
                rga_version_compare(v1311, version_of(1, 3, 2)));

    /* A higher major/minor wins regardless of the lower components. */
    unit_eq_int("compare 2.0.0 vs 1.3.13", 1,
                rga_version_compare(version_of(2, 0, 0), v1313));
    unit_eq_int("compare 1.2.99 vs 1.3.0", -1,
                rga_version_compare(version_of(1, 2, 99), v130));

    unit_eq_int("user-close-fence denied at 1.2.4", 0, user_close_fence_granted(v124));
    unit_eq_int("user-close-fence granted at 1.3.0 (boundary is inclusive)", 1,
                user_close_fence_granted(v130));
    unit_eq_int("user-close-fence granted at 1.3.11", 1, user_close_fence_granted(v1311));
    unit_eq_int("user-close-fence granted at 1.3.13", 1, user_close_fence_granted(v1313));
}

/* ---------------------------------------------------------------- (e) ---- */

static void check_rga_set_rect(void)
{
    unit_begin("(e) rga_set_rect populates rga_info_t.rect");

    rga_info_t info;
    memset(&info, 0xa5, sizeof(info));

    const int ret = rga_set_rect(&info.rect, 8, 16, 1280, 720, 1920, 1088,
                                 RK_FORMAT_YCbCr_420_SP);

    unit_eq_int("rga_set_rect return", 0, ret);
    unit_eq_int("rect.xoffset", 8, info.rect.xoffset);
    unit_eq_int("rect.yoffset", 16, info.rect.yoffset);
    unit_eq_int("rect.width", 1280, info.rect.width);
    unit_eq_int("rect.height", 720, info.rect.height);
    unit_eq_int("rect.wstride", 1920, info.rect.wstride);
    unit_eq_int("rect.hstride", 1088, info.rect.hstride);
    unit_eq_hex("rect.format", (unsigned long)RK_FORMAT_YCbCr_420_SP,
                (unsigned long)(unsigned int)info.rect.format);

    /*
     * rect.size is documented "user not need care about" (drmrga.h:112) and
     * rga_set_rect never writes it. Asserting the 0xa5 filler survives pins
     * that: callers who memset their rga_info_t get 0, callers who do not get
     * whatever was on the stack.
     */
    unit_eq_hex("rect.size left untouched", 0xa5a5a5a5UL,
                (unsigned long)(unsigned int)info.rect.size);

    /* Zeroes are stored verbatim; there is no minimum-size validation here. */
    rga_rect_t zeroed;
    memset(&zeroed, 0xa5, sizeof(zeroed));
    unit_eq_int("rga_set_rect return (all-zero geometry)", 0,
                rga_set_rect(&zeroed, 0, 0, 0, 0, 0, 0, RK_FORMAT_RGBA_8888));
    unit_eq_int("rect.width accepts 0", 0, zeroed.width);
    unit_eq_int("rect.wstride accepts 0", 0, zeroed.wstride);

    /* Negative geometry is stored verbatim too -- validation is imcheck's job. */
    rga_rect_t negative;
    memset(&negative, 0, sizeof(negative));
    rga_set_rect(&negative, -1, -2, -3, -4, -5, -6, RK_FORMAT_RGBA_8888);
    unit_eq_int("rect.xoffset accepts a negative value", -1, negative.xoffset);
    unit_eq_int("rect.height accepts a negative value", -4, negative.height);

    unit_eq_int("rga_set_rect(NULL) returns -EINVAL", -EINVAL,
                rga_set_rect(NULL, 0, 0, 0, 0, 0, 0, RK_FORMAT_RGBA_8888));
}

/* -------------------------------------------------------------------------- */

int main(void)
{
    /*
     * Purity guard. If the todo-12 shim were preloaded here the group would no
     * longer prove that these paths need no device, so refuse rather than pass
     * for the wrong reason.
     */
    if (dlsym(RTLD_DEFAULT, "fake_rga_active")) {
        fprintf(stderr, "unit-pure must run WITHOUT the fake_rga preload\n");
        return 2;
    }

    check_format_tables();
    check_version_predicates();
    check_rga_set_rect();

    /* Deliberately failing check. Proves the CI summary job reports RED when a
     * `meson test` unit assertion fails. Never merged. */
    unit_begin("non-vacuity probe");
    unit_eq_int("the summary job must go red on a failing unit assertion", 1, 2);

    return unit_report("unit-pure");
}
