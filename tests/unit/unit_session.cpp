/* SPDX-License-Identifier: Apache-2.0 */
/*
 * unit-session: characterization of librga paths that reach a live rga_session.
 *
 * At this commit rga_check() calls get_rga_session() (im2d_impl.cpp:1293),
 * which opens /dev/rga (im2d_context.cpp:112-164). imcheck and the colour
 * space plumbing are therefore NOT host-pure, and this group runs under the
 * todo-12 LD_PRELOAD shim. Meson supplies LD_PRELOAD through the test env; the
 * guard in main() refuses to run without it, exactly like the golden client,
 * so a dropped preload can never be mistaken for a pass on real hardware.
 *
 * The shim declares a three-core RK3588-shaped device (2x RGA3 3.0.76831 plus
 * RGA2 3.2.63318, driver 1.3.11), so every limit asserted below is the MERGED
 * multi-core table rga_get_info() produces from those cores.
 *
 * Covered here:
 *   (b) the imcheck validation matrix
 *   (c) default CSC resolution, observed in the constructed rga_req
 *   (f) the RT-1 imconfig(IM_CONFIG_SCHEDULER_CORE, IM_SCHEDULER_DEFAULT)
 *       reproducer
 *
 * Everything asserts CURRENT behaviour. Nothing here is aspirational.
 */
#include <cstdlib>
#include <cstring>
#include <dlfcn.h>
#include <fcntl.h>
#include <sys/mman.h>
#include <unistd.h>

#include "im2d.h"
#include "im2d_impl.h"
#include "im2d_version.h"
#if RGA_API_REVISION_VERSION > 1 || RGA_API_MINOR_VERSION > 10 || RGA_API_MAJOR_VERSION > 1
#include "im2d_context.h"
#endif
#include "rga.h"
#include "rga_ioctl.h"

#include "unit_assert.h"

/*
 * Non-static in im2d_impl.cpp:784 but absent from im2d_impl.h. Declared here so
 * the per-core resolution limits can be exercised against an explicit table
 * entry instead of only the merged one.
 */
#if RGA_API_REVISION_VERSION > 1 || RGA_API_MINOR_VERSION > 10 || RGA_API_MAJOR_VERSION > 1
IM_STATUS rga_check_info(const char *name, const rga_buffer_t info, const im_rect rect,
                         rga_info_resolution_t resolution_usage);
#endif

static const int SRC_FD = 100;
static const int DST_FD = 101;

static const im_rect NO_RECT = { 0, 0, 0, 0 };

static bool make_buffer(int target)
{
    int fd = memfd_create("unit-session-buffer", MFD_CLOEXEC);
    if (fd < 0)
        return false;
    /* Sparse; nothing reads it. Large enough for the 8192-wide limit cases. */
    if (ftruncate(fd, 8192L * 8192 * 4) || dup2(fd, target) < 0) {
        close(fd);
        return false;
    }
    if (fd != target)
        close(fd);
    return true;
}

static IM_STATUS check_pair(int sw, int sh, int sws, int shs, int sfmt,
                            int dw, int dh, int dws, int dhs, int dfmt,
                            im_rect src_rect, int usage)
{
    rga_buffer_t pat;
    memset(&pat, 0, sizeof(pat));
    rga_buffer_t src = wrapbuffer_fd(SRC_FD, sw, sh, sfmt, sws, shs);
    rga_buffer_t dst = wrapbuffer_fd(DST_FD, dw, dh, dfmt, dws, dhs);
    return imcheck_t(src, dst, pat, src_rect, NO_RECT, NO_RECT, usage);
}

/* ---------------------------------------------------------------- (b) ---- */

static const int RGBA = RK_FORMAT_RGBA_8888;
static const int NV12 = RK_FORMAT_YCbCr_420_SP;

static void check_status_literals(void)
{
    unit_begin("(b0) IM_STATUS literal values");

    /*
     * imcheck's contract is the literal, not "some negative number". Pin the
     * numeric values so a reordering of the enum is caught here rather than by
     * a caller comparing against a stale integer.
     */
    unit_eq_int("IM_STATUS_NOERROR", 2, IM_STATUS_NOERROR);
    unit_eq_int("IM_STATUS_SUCCESS", 1, IM_STATUS_SUCCESS);
    unit_eq_int("IM_STATUS_NOT_SUPPORTED", -1, IM_STATUS_NOT_SUPPORTED);
    unit_eq_int("IM_STATUS_INVALID_PARAM", -3, IM_STATUS_INVALID_PARAM);
    unit_eq_int("IM_STATUS_ILLEGAL_PARAM", -4, IM_STATUS_ILLEGAL_PARAM);
    unit_eq_int("IM_STATUS_FAILED", 0, IM_STATUS_FAILED);
}

static void check_imcheck_matrix(void)
{
    unit_begin("(b) imcheck validation matrix");

    /*
     * 2x2 minimum (im2d_impl.cpp:792-797). wstride is 4 rather than 2 because
     * rga_check_align() independently requires an RGBA8888 width stride that is
     * a multiple of 4 on a 16-byte-stride core (im2d_impl.cpp:1141-1151); at
     * wstride 2 the alignment check fires first and hides the size check.
     */
    unit_eq_int("2x2 minimum accepted", IM_STATUS_NOERROR,
                check_pair(2, 2, 4, 2, RGBA, 2, 2, 4, 2, RGBA, NO_RECT, 0));
    unit_eq_int("src width 1 rejected as ILLEGAL_PARAM", IM_STATUS_ILLEGAL_PARAM,
                check_pair(1, 2, 4, 2, RGBA, 2, 2, 4, 2, RGBA, NO_RECT, 0));
    unit_eq_int("dst height 1 rejected as ILLEGAL_PARAM", IM_STATUS_ILLEGAL_PARAM,
                check_pair(2, 2, 4, 2, RGBA, 2, 1, 4, 2, RGBA, NO_RECT, 0));

    /* Zero and negative dimensions are caught before the 2-pixel floor. */
    unit_eq_int("width 0 rejected as ILLEGAL_PARAM", IM_STATUS_ILLEGAL_PARAM,
                check_pair(0, 64, 64, 64, RGBA, 64, 64, 64, 64, RGBA, NO_RECT, 0));
    unit_eq_int("negative height rejected as ILLEGAL_PARAM", IM_STATUS_ILLEGAL_PARAM,
                check_pair(64, -1, 64, 64, RGBA, 64, 64, 64, 64, RGBA, NO_RECT, 0));

    /* wstride < width / hstride < height (im2d_impl.cpp:799-804). */
    unit_eq_int("wstride < width rejected as INVALID_PARAM", IM_STATUS_INVALID_PARAM,
                check_pair(64, 64, 32, 64, RGBA, 64, 64, 64, 64, RGBA, NO_RECT, 0));
    unit_eq_int("hstride < height rejected as INVALID_PARAM", IM_STATUS_INVALID_PARAM,
                check_pair(64, 64, 64, 32, RGBA, 64, 64, 64, 64, RGBA, NO_RECT, 0));

    /* Odd YUV geometry (rga_yuv_legality_check, im2d_impl.cpp:385-398). */
    unit_eq_int("odd YUV wstride rejected as INVALID_PARAM", IM_STATUS_INVALID_PARAM,
                check_pair(64, 64, 65, 64, NV12, 64, 64, 64, 64, NV12, NO_RECT, 0));
    unit_eq_int("odd YUV hstride rejected as INVALID_PARAM", IM_STATUS_INVALID_PARAM,
                check_pair(64, 64, 64, 65, NV12, 64, 64, 64, 64, NV12, NO_RECT, 0));
    unit_eq_int("odd YUV width rejected as INVALID_PARAM", IM_STATUS_INVALID_PARAM,
                check_pair(63, 64, 64, 64, NV12, 64, 64, 64, 64, NV12, NO_RECT, 0));
    unit_eq_int("odd YUV height rejected as INVALID_PARAM", IM_STATUS_INVALID_PARAM,
                check_pair(64, 63, 64, 64, NV12, 64, 64, 64, 64, NV12, NO_RECT, 0));
    unit_eq_int("even YUV geometry accepted", IM_STATUS_NOERROR,
                check_pair(64, 64, 64, 64, NV12, 64, 64, 64, 64, NV12, NO_RECT, 0));

    /*
     * Scale limits (rga_check_limit, im2d_impl.cpp:843-868). The merged table's
     * scale_limit is 16, and the comparison is a strict '>', so exactly 1/16
     * and exactly 16x are ACCEPTED.
     */
    unit_eq_int("scale exactly 1/16 accepted", IM_STATUS_NOERROR,
                check_pair(1024, 1024, 1024, 1024, RGBA, 64, 64, 64, 64, RGBA, NO_RECT, 0));
    unit_eq_int("scale below 1/16 rejected as NOT_SUPPORTED", IM_STATUS_NOT_SUPPORTED,
                check_pair(1024, 1024, 1024, 1024, RGBA, 60, 60, 60, 60, RGBA, NO_RECT, 0));
    unit_eq_int("scale exactly 16x accepted", IM_STATUS_NOERROR,
                check_pair(64, 64, 64, 64, RGBA, 1024, 1024, 1024, 1024, RGBA, NO_RECT, 0));
    unit_eq_int("scale above 16x rejected as NOT_SUPPORTED", IM_STATUS_NOT_SUPPORTED,
                check_pair(64, 64, 64, 64, RGBA, 1028, 1028, 1028, 1028, RGBA, NO_RECT, 0));

    /*
     * The 90/270 swap (im2d_impl.cpp:850-856). 2048x64 -> 64x2048 is a 32x
     * horizontal change unrotated and a 1:1 change once the destination is
     * transposed, so the same geometry flips from rejected to accepted purely
     * on the rotation flag. 180 does not transpose and stays rejected.
     */
    unit_eq_int("32x geometry without rotation rejected as NOT_SUPPORTED", IM_STATUS_NOT_SUPPORTED,
                check_pair(2048, 64, 2048, 64, RGBA, 64, 2048, 64, 2048, RGBA, NO_RECT, 0));
    unit_eq_int("same geometry accepted under ROT_90 swap", IM_STATUS_NOERROR,
                check_pair(2048, 64, 2048, 64, RGBA, 64, 2048, 64, 2048, RGBA, NO_RECT,
                           IM_HAL_TRANSFORM_ROT_90));
    unit_eq_int("same geometry accepted under ROT_270 swap", IM_STATUS_NOERROR,
                check_pair(2048, 64, 2048, 64, RGBA, 64, 2048, 64, 2048, RGBA, NO_RECT,
                           IM_HAL_TRANSFORM_ROT_270));
    unit_eq_int("ROT_180 does not swap and stays rejected", IM_STATUS_NOT_SUPPORTED,
                check_pair(2048, 64, 2048, 64, RGBA, 64, 2048, 64, 2048, RGBA, NO_RECT,
                           IM_HAL_TRANSFORM_ROT_180));

    /* Crop bounds (im2d_impl.cpp:806-825). */
    const im_rect crop_ok      = { 8, 8, 1280, 720 };
    const im_rect crop_past_ws = { 1000, 8, 1280, 720 };
    const im_rect crop_zero_h  = { 0, 0, 1280, 0 };
    const im_rect crop_negative = { -1, 0, 1280, 720 };

    unit_eq_int("crop inside wstride/hstride accepted", IM_STATUS_NOERROR,
                check_pair(1920, 1080, 1920, 1080, RGBA, 1280, 720, 1280, 720, RGBA, crop_ok, 0));
    unit_eq_int("crop x+width past wstride rejected as INVALID_PARAM", IM_STATUS_INVALID_PARAM,
                check_pair(1920, 1080, 1920, 1080, RGBA, 1280, 720, 1280, 720, RGBA, crop_past_ws, 0));
#if RGA_API_REVISION_VERSION > 1 || RGA_API_MINOR_VERSION > 10 || RGA_API_MAJOR_VERSION > 1
    unit_eq_int("crop height 0 with width > 0 rejected as ILLEGAL_PARAM", IM_STATUS_ILLEGAL_PARAM,
#else
    unit_eq_int("1.10.1 accepts a zero-height crop", IM_STATUS_NOERROR,
#endif
                check_pair(1920, 1080, 1920, 1080, RGBA, 1280, 720, 1280, 720, RGBA, crop_zero_h, 0));
    unit_eq_int("crop negative origin rejected as ILLEGAL_PARAM", IM_STATUS_ILLEGAL_PARAM,
                check_pair(1920, 1080, 1920, 1080, RGBA, 1280, 720, 1280, 720, RGBA, crop_negative, 0));
}

static void check_resolution_limits(void)
{
#if RGA_API_REVISION_VERSION > 1 || RGA_API_MINOR_VERSION > 10 || RGA_API_MAJOR_VERSION > 1
    unit_begin("(b2) input/output resolution limits");

    /*
     * The merged session table for the shim's core set. rga_support_info_merge_table()
     * (im2d_impl.cpp:73-103) takes the larger entry only when BOTH dimensions are
     * larger, so the merged input comes from the RGA2 core and the merged output
     * from RGA3's own 8128 ceiling.
     */
    rga_session_t *session = get_rga_session();
    unit_eq_int("merged input_resolution.width", 8192,
                session->hardware_info.input_resolution.width);
    unit_eq_int("merged input_resolution.height", 8192,
                session->hardware_info.input_resolution.height);
    unit_eq_int("merged output_resolution.width", 8128,
                session->hardware_info.output_resolution.width);
    unit_eq_int("merged output_resolution.height", 8128,
                session->hardware_info.output_resolution.height);
    unit_eq_int("merged byte_stride", 16, (int)session->hardware_info.byte_stride);
    unit_eq_int("merged scale_limit", 16, (int)session->hardware_info.scale_limit);

    unit_eq_int("src at the merged 8192 input limit accepted", IM_STATUS_NOERROR,
                check_pair(8192, 8192, 8192, 8192, RGBA, 1024, 1024, 1024, 1024, RGBA, NO_RECT, 0));
    unit_eq_int("src one past the input limit rejected as NOT_SUPPORTED", IM_STATUS_NOT_SUPPORTED,
                check_pair(8196, 8192, 8196, 8192, RGBA, 1024, 1024, 1024, 1024, RGBA, NO_RECT, 0));
    unit_eq_int("dst at the merged 8128 output limit accepted", IM_STATUS_NOERROR,
                check_pair(1024, 1024, 1024, 1024, RGBA, 8128, 8128, 8128, 8128, RGBA, NO_RECT, 0));
    unit_eq_int("dst past the output limit rejected as NOT_SUPPORTED", IM_STATUS_NOT_SUPPORTED,
                check_pair(1024, 1024, 1024, 1024, RGBA, 8192, 8192, 8192, 8192, RGBA, NO_RECT, 0));

    /*
     * Per-core limits, driven straight through rga_check_info() with an explicit
     * resolution_usage so the 8192-in / 4096-out pair is exercised regardless of
     * what the merged table happens to be.
     *
     * NOTE for readers of the work plan: the plan describes these as "RGA3
     * 8192-in/4096-out". The imported upstream at this commit disagrees --
     * hw_info_table's RGA3 row (im2d_api/src/im2d_hardware.h:404) is
     * {8176, 8176} in and {8128, 8128} out. That row is asserted below as-is.
     * The 8192/4096 pair is still exercised, as an explicit resolution_usage,
     * because it is the boundary arithmetic that matters and it is what the plan
     * names.
     */
    const rga_info_resolution_t in_8192  = { 8192, 8192 };
    const rga_info_resolution_t out_4096 = { 4096, 4096 };

    unit_eq_int("rga_check_info: 8192x8192 within an 8192 input limit", IM_STATUS_NOERROR,
                rga_check_info("src", wrapbuffer_fd(SRC_FD, 8192, 8192, RGBA, 8192, 8192),
                               NO_RECT, in_8192));
    unit_eq_int("rga_check_info: width 8193 over an 8192 input limit", IM_STATUS_NOT_SUPPORTED,
                rga_check_info("src", wrapbuffer_fd(SRC_FD, 8193, 8192, RGBA, 8193, 8192),
                               NO_RECT, in_8192));
    unit_eq_int("rga_check_info: height 8193 over an 8192 input limit", IM_STATUS_NOT_SUPPORTED,
                rga_check_info("src", wrapbuffer_fd(SRC_FD, 8192, 8193, RGBA, 8192, 8193),
                               NO_RECT, in_8192));
    unit_eq_int("rga_check_info: 4096x4096 within a 4096 output limit", IM_STATUS_NOERROR,
                rga_check_info("dst", wrapbuffer_fd(DST_FD, 4096, 4096, RGBA, 4096, 4096),
                               NO_RECT, out_4096));
    unit_eq_int("rga_check_info: width 4097 over a 4096 output limit", IM_STATUS_NOT_SUPPORTED,
                rga_check_info("dst", wrapbuffer_fd(DST_FD, 4097, 4096, RGBA, 4097, 4096),
                               NO_RECT, out_4096));

    /*
     * An in-range image with an out-of-range RECT takes the second branch of the
     * resolution check (im2d_impl.cpp:833-838) and still reports NOT_SUPPORTED.
     */
    const im_rect oversized_rect = { 0, 0, 8192, 4096 };
    unit_eq_int("rga_check_info: oversized rect on an in-range image", IM_STATUS_NOT_SUPPORTED,
                rga_check_info("dst", wrapbuffer_fd(DST_FD, 4096, 4096, RGBA, 8192, 4096),
                               oversized_rect, out_4096));

    /* The RGA3 row of hw_info_table, as imported. */
    const rga_info_table_entry *rga3 = &hw_info_table[IM_RGA_HW_VERSION_RGA_3_INDEX];
    unit_eq_int("hw_info_table RGA3 input width", 8176, rga3->input_resolution.width);
    unit_eq_int("hw_info_table RGA3 input height", 8176, rga3->input_resolution.height);
    unit_eq_int("hw_info_table RGA3 output width", 8128, rga3->output_resolution.width);
    unit_eq_int("hw_info_table RGA3 output height", 8128, rga3->output_resolution.height);
    unit_eq_int("hw_info_table RGA3 byte_stride", 16, (int)rga3->byte_stride);
    unit_eq_int("hw_info_table RGA3 scale_limit", 8, (int)rga3->scale_limit);
#else
    puts("NOT APPLICABLE: post-1.10.1 session/context and rectangular resolution API");
#endif
}

/* ---------------------------------------------------------------- (c) ---- */

/*
 * The CSC decision is made by two static helpers, rga_get_default_csc_mode()
 * and rga_get_csc_mode() (im2d_impl.cpp:1638-1793). Neither is linkable, so the
 * outcome is read where it lands: rga_req.yuv2rgb_mode and rga_req.full_csc.flag
 * in the request the shim intercepts (NormalRga.cpp:1324-1332 and
 * NormalRgaApi.cpp:849-916).
 */
struct csc_result {
    IM_STATUS status;
    bool captured;
    unsigned int yuv2rgb_mode;
    unsigned int full_csc_flag;
};

static char csc_dump_path[256];

static csc_result run_csc(int src_format, int dst_format, int src_space, int dst_space)
{
    csc_result result;
    memset(&result, 0, sizeof(result));

    unlink(csc_dump_path);
    setenv("FAKE_RGA_DUMP", csc_dump_path, 1);

    rga_buffer_t src = wrapbuffer_fd(SRC_FD, 1280, 720, src_format, 1280, 720);
    rga_buffer_t dst = wrapbuffer_fd(DST_FD, 1280, 720, dst_format, 1280, 720);
    if (src_space >= 0)
        imsetColorSpace(&src, (IM_COLOR_SPACE_MODE)src_space);
    if (dst_space >= 0)
        imsetColorSpace(&dst, (IM_COLOR_SPACE_MODE)dst_space);

    rga_buffer_t pat;
    memset(&pat, 0, sizeof(pat));
    result.status = improcess(src, dst, pat, NO_RECT, NO_RECT, NO_RECT, IM_SYNC);

    int fd = open(csc_dump_path, O_RDONLY);
    if (fd >= 0) {
        struct rga_req request;
        memset(&request, 0, sizeof(request));
        if (read(fd, &request, sizeof(request)) == (ssize_t)sizeof(request)) {
            result.captured = true;
            result.yuv2rgb_mode = request.yuv2rgb_mode;
            result.full_csc_flag = request.full_csc.flag;
        }
        close(fd);
    }

    unsetenv("FAKE_RGA_DUMP");
    return result;
}

static void check_csc_defaults(void)
{
    unit_begin("(c) default colour-space resolution");

    /*
     * No colour space configured on either side. NormalRga.cpp:1357-1400 picks
     * the mode from the formats alone: YUV source into an RGB destination is
     * BT.601 LIMITED, and RGB into YUV likewise.
     */
    csc_result y2r = run_csc(NV12, RK_FORMAT_RGB_888, -1, -1);
    unit_eq_int("YUV->RGB default improcess", IM_STATUS_SUCCESS, y2r.status);
    unit_eq_int("YUV->RGB default request captured", 1, y2r.captured);
    unit_eq_hex("YUV->RGB default is BT.601 limited", (unsigned long)IM_YUV_TO_RGB_BT601_LIMIT,
                y2r.yuv2rgb_mode);
    unit_eq_int("YUV->RGB default uses no full-CSC matrix", 0, (int)y2r.full_csc_flag);

    csc_result r2y = run_csc(RK_FORMAT_RGB_888, NV12, -1, -1);
    unit_eq_int("RGB->YUV default improcess", IM_STATUS_SUCCESS, r2y.status);
    unit_eq_hex("RGB->YUV default is BT.601 limited", (unsigned long)IM_RGB_TO_YUV_BT601_LIMIT,
                r2y.yuv2rgb_mode);
    unit_eq_int("RGB->YUV default uses no full-CSC matrix", 0, (int)r2y.full_csc_flag);

    /*
     * Only one side configured. The unset side is filled in by
     * rga_get_default_csc_mode() (im2d_impl.cpp:1638-1647): RGB -> IM_RGB_FULL,
     * YUV -> IM_YUV_BT601_LIMIT_RANGE. Both fill-ins land back on BT.601 limited.
     */
    csc_result filled_src_yuv = run_csc(NV12, RK_FORMAT_RGB_888, -1, IM_RGB_FULL);
    unit_eq_int("YUV source default fill-in improcess", IM_STATUS_SUCCESS, filled_src_yuv.status);
    unit_eq_hex("unset YUV source defaults to BT.601 limited",
                (unsigned long)IM_YUV_TO_RGB_BT601_LIMIT, filled_src_yuv.yuv2rgb_mode);

    csc_result filled_src_rgb = run_csc(RK_FORMAT_RGB_888, NV12, -1, IM_YUV_BT601_LIMIT_RANGE);
    unit_eq_int("RGB source default fill-in improcess", IM_STATUS_SUCCESS, filled_src_rgb.status);
    unit_eq_hex("unset RGB source defaults to RGB full, giving BT.601 limited R2Y",
                (unsigned long)IM_RGB_TO_YUV_BT601_LIMIT, filled_src_rgb.yuv2rgb_mode);

    /* Explicit RGB full -> BT.601 limited is the same mode, no full-CSC matrix. */
    csc_result explicit_601 = run_csc(RK_FORMAT_RGB_888, NV12, IM_RGB_FULL,
                                      IM_YUV_BT601_LIMIT_RANGE);
    unit_eq_hex("explicit RGB full -> BT.601 limited", (unsigned long)IM_RGB_TO_YUV_BT601_LIMIT,
                explicit_601.yuv2rgb_mode);
    unit_eq_int("explicit BT.601 limited uses no full-CSC matrix", 0,
                (int)explicit_601.full_csc_flag);

    /*
     * 709 limited. im2d_impl.cpp:1662-1668 prefers rgb2yuv_709_limit whenever
     * the core advertises DST_FULL_CSC, which loads a full coefficient matrix
     * (full_csc.flag == 1) and additionally ORs IM_RGB_TO_YUV_BT709_LIMIT into
     * yuv2rgb_mode (NormalRga.cpp:1331-1332).
     */
    csc_result full_709_limit = run_csc(RK_FORMAT_RGB_888, NV12, IM_RGB_FULL,
                                        IM_YUV_BT709_LIMIT_RANGE);
    unit_eq_int("RGB full -> 709 limited improcess", IM_STATUS_SUCCESS, full_709_limit.status);
    unit_eq_hex("RGB full -> 709 limited yuv2rgb_mode",
                (unsigned long)IM_RGB_TO_YUV_BT709_LIMIT, full_709_limit.yuv2rgb_mode);
    unit_eq_int("RGB full -> 709 limited loads a full-CSC matrix", 1,
                (int)full_709_limit.full_csc_flag);

    /*
     * The legacy R2Y selector reaches the same place: im2d_impl.cpp:2156-2164
     * rewrites a bare IM_RGB_TO_YUV_BT709_LIMIT into rgb2yuv_709_limit on a
     * DST_FULL_CSC core, so both spellings produce an identical request.
     */
    csc_result legacy_709_limit = run_csc(RK_FORMAT_RGB_888, NV12, -1,
                                          IM_RGB_TO_YUV_BT709_LIMIT);
    unit_eq_int("legacy IM_RGB_TO_YUV_BT709_LIMIT improcess", IM_STATUS_SUCCESS,
                legacy_709_limit.status);
    unit_eq_hex("legacy IM_RGB_TO_YUV_BT709_LIMIT maps to the same mode",
                (unsigned long)IM_RGB_TO_YUV_BT709_LIMIT, legacy_709_limit.yuv2rgb_mode);
#if RGA_API_REVISION_VERSION > 1 || RGA_API_MINOR_VERSION > 10 || RGA_API_MAJOR_VERSION > 1
    unit_eq_int("legacy IM_RGB_TO_YUV_BT709_LIMIT loads a full-CSC matrix", 1,
#else
    unit_eq_int("1.10.1 legacy 709 selector uses no full-CSC matrix", 0,
#endif
                (int)legacy_709_limit.full_csc_flag);

    /*
     * 709 FULL is only half-supported today, and the asymmetry is the point.
     *
     * RGB full -> YUV 709 full resolves to rgb2yuv_709_full (im2d_impl.cpp:1669-1671)
     * and NormalRgaApi.cpp:860-863 has a matrix for it, so it goes through.
     */
    csc_result rgb_to_709_full = run_csc(RK_FORMAT_RGB_888, NV12, IM_RGB_FULL,
                                         IM_YUV_BT709_FULL_RANGE);
    unit_eq_int("RGB full -> YUV 709 full improcess", IM_STATUS_SUCCESS, rgb_to_709_full.status);
    unit_eq_int("RGB full -> YUV 709 full loads a full-CSC matrix", 1,
                (int)rgb_to_709_full.full_csc_flag);

    /*
     * The reverse, YUV 709 full -> RGB full, resolves to yuv2rgb_709_full, which
     * rga.h:182 marks "not support" and NormalRgaApi.cpp's switch has no case
     * for, so NormalRgaFullColorSpaceConvert() returns -1 and the blit fails
     * with a generic IM_STATUS_FAILED rather than a colour-space-specific
     * status. Asserted as-is: this is CURRENT behaviour, not desired behaviour.
     */
    csc_result yuv_709_full_to_rgb = run_csc(NV12, RK_FORMAT_RGB_888,
                                             IM_YUV_BT709_FULL_RANGE, IM_RGB_FULL);
    unit_eq_int("YUV 709 full -> RGB full is rejected", IM_STATUS_FAILED,
                yuv_709_full_to_rgb.status);
    unit_eq_int("YUV 709 full -> RGB full never reaches the driver", 0,
                (int)yuv_709_full_to_rgb.captured);

    /* Same shape of rejection for an unsupported YUV-to-YUV conversion. */
    csc_result yuv_601_to_709 = run_csc(NV12, NV12, IM_YUV_BT601_LIMIT_RANGE,
                                        IM_YUV_BT709_LIMIT_RANGE);
    unit_eq_int("YUV 601 limited -> YUV 709 limited is rejected", IM_STATUS_FAILED,
                yuv_601_to_709.status);
    unit_eq_int("YUV 601 limited -> YUV 709 limited never reaches the driver", 0,
                (int)yuv_601_to_709.captured);
}

/* ---------------------------------------------------------------- (f) ---- */

static void check_imconfig_rt1(void)
{
    unit_begin("(f) RT-1 reproducer: imconfig scheduler core");

    /*
     * RT-1 reproducer: this flips to accept IM_SCHEDULER_DEFAULT in a later fix
     * todo (D20).
     *
     * IM_SCHEDULER_DEFAULT is 0 (im2d_type.h:117) and imconfig() gates on
     * "value & IM_SCHEDULER_MASK" (im2d.cpp:865-871), so the documented
     * "let the driver choose" value is the one value the setter refuses. Until
     * D20 lands, IM_STATUS_ILLEGAL_PARAM is the correct expectation and must
     * not be softened.
     */
    unit_eq_int("IM_SCHEDULER_DEFAULT is 0", 0, IM_SCHEDULER_DEFAULT);
    unit_eq_int("imconfig(IM_CONFIG_SCHEDULER_CORE, IM_SCHEDULER_DEFAULT) rejects today",
                IM_STATUS_ILLEGAL_PARAM,
                imconfig(IM_CONFIG_SCHEDULER_CORE, IM_SCHEDULER_DEFAULT));

    /* Any value outside the 0xf core mask is rejected the same way. */
    unit_eq_int("imconfig(IM_CONFIG_SCHEDULER_CORE, 0x10) rejects", IM_STATUS_ILLEGAL_PARAM,
                imconfig(IM_CONFIG_SCHEDULER_CORE, 0x10));

    /* A real core selection is accepted, so the rejection above is specific. */
    unit_eq_int("imconfig(IM_CONFIG_SCHEDULER_CORE, RGA3_CORE0) succeeds", IM_STATUS_SUCCESS,
                imconfig(IM_CONFIG_SCHEDULER_CORE, IM_SCHEDULER_RGA3_CORE0));
    unit_eq_int("imconfig(IM_CONFIG_SCHEDULER_CORE, RGA2_CORE1) succeeds", IM_STATUS_SUCCESS,
                imconfig(IM_CONFIG_SCHEDULER_CORE, IM_SCHEDULER_RGA2_CORE1));

    /* Neighbouring config names for contrast; both are unchanged by D20. */
    unit_eq_int("imconfig(IM_CONFIG_PRIORITY, 6) succeeds", IM_STATUS_SUCCESS,
                imconfig(IM_CONFIG_PRIORITY, 6));
    unit_eq_int("imconfig(IM_CONFIG_PRIORITY, 7) rejects", IM_STATUS_ILLEGAL_PARAM,
                imconfig(IM_CONFIG_PRIORITY, 7));
    unit_eq_int("imconfig with an unknown name is NOT_SUPPORTED", IM_STATUS_NOT_SUPPORTED,
                imconfig((IM_CONFIG_NAME)0x7fff, 0));
}

/* -------------------------------------------------------------------------- */

int main(void)
{
    if (!dlsym(RTLD_DEFAULT, "fake_rga_active")) {
        fprintf(stderr, "Refusing hardware access: fake_rga preload is absent\n");
        return 2;
    }
    if (!make_buffer(SRC_FD) || !make_buffer(DST_FD)) {
        perror("unit-session buffer");
        return 2;
    }

    const char *tmp = getenv("TMPDIR");
    snprintf(csc_dump_path, sizeof(csc_dump_path), "%s/librga-unit-session-csc-%d.bin",
             tmp && *tmp ? tmp : "/tmp", (int)getpid());

    check_status_literals();
    check_imcheck_matrix();
    check_resolution_limits();
    check_csc_defaults();
    /* Last: imconfig mutates the thread-local im2d context the groups above read. */
    check_imconfig_rt1();

    unlink(csc_dump_path);
    close(SRC_FD);
    close(DST_FD);

    return unit_report("unit-session");
}
