/*
 * Island side of the multi_rga UAPI parity gate.
 *
 * Includes ONLY the sha-verified island driver header (fetched by
 * fetch-island-header.sh at the ref pinned in island-pin.env) and prints a flat
 * {kind, name, value} table on stdout. It deliberately knows nothing about
 * librga: the whole point is that two independent translation units describe
 * the same ABI and a comparator decides whether they agree.
 *
 * The kernel primitives the island header needs but does not include are
 * supplied by the forced preinclude kstubs/preinclude.h and the empty stub
 * include root kstubs/linux/. Neither may define anything compared here; see
 * check-stubs.sh, which enforces that mechanically.
 *
 * Member names are emitted VERBATIM as the island spells them. Where librga
 * spells the same field differently (memory_parm vs memory_info, buffers_ptr vs
 * buffers, compact_mode vs is_10b_compact) the rename stays visible in both
 * tables and compare.py reconciles it through an explicit, auditable alias map.
 * Normalising the names here instead would hide exactly the drift we are
 * trying to see.
 */

#include <stdio.h>

#include "island-rga.h"

#define EMIT_IOCTL(sym) \
    printf("ioctl\t%s\t%llu\n", #sym, (unsigned long long)(sym))

#define EMIT_SIZE(label, type) \
    printf("size\t%s\t%llu\n", label, (unsigned long long)sizeof(type))

#define EMIT_MEMBER(label, type, member)                                      \
    do {                                                                      \
        printf("off\t%s.%s\t%llu\n", label, #member,                          \
               (unsigned long long)offsetof(type, member));                   \
        printf("msize\t%s.%s\t%llu\n", label, #member,                        \
               (unsigned long long)sizeof(((type *)0)->member));              \
    } while (0)

int main(void)
{
    printf("#side\tisland\n");

    /* ---- ioctl request numbers and the constants that build them ---- */
    EMIT_IOCTL(RGA_IOC_MAGIC);
    EMIT_IOCTL(RGA_IOC_GET_DRVIER_VERSION);
    EMIT_IOCTL(RGA_IOC_GET_HW_VERSION);
    EMIT_IOCTL(RGA_IOC_IMPORT_BUFFER);
    EMIT_IOCTL(RGA_IOC_RELEASE_BUFFER);
    EMIT_IOCTL(RGA_IOC_REQUEST_CREATE);
    EMIT_IOCTL(RGA_IOC_REQUEST_SUBMIT);
    EMIT_IOCTL(RGA_IOC_REQUEST_CONFIG);
    EMIT_IOCTL(RGA_IOC_REQUEST_CANCEL);

    /* Legacy RGA1/RGA2 command numbers. */
    EMIT_IOCTL(RGA_BLIT_SYNC);
    EMIT_IOCTL(RGA_BLIT_ASYNC);
    EMIT_IOCTL(RGA_FLUSH);
    EMIT_IOCTL(RGA_GET_RESULT);
    EMIT_IOCTL(RGA_GET_VERSION);
    EMIT_IOCTL(RGA2_GET_RESULT);
    EMIT_IOCTL(RGA2_GET_VERSION);

    /*
     * Island-only commands: librga never issues these, so its headers do not
     * declare them. compare.py still pins their values, so an island renumber
     * is caught rather than shrugged off.
     */
    EMIT_IOCTL(RGA_CACHE_FLUSH);
    EMIT_IOCTL(RGA_IMPORT_DMA);
    EMIT_IOCTL(RGA_RELEASE_DMA);

    /* Sizing constants that participate in the ABI. */
    EMIT_IOCTL(RGA_VERSION_SIZE);
    EMIT_IOCTL(RGA_HW_SIZE);
    EMIT_IOCTL(RGA_TASK_NUM_MAX);
    EMIT_IOCTL(RGA_SCHED_PRIORITY_DEFAULT);
    EMIT_IOCTL(RGA_SCHED_PRIORITY_MAX);
    EMIT_IOCTL(RGA_BUFFER_POOL_SIZE_MAX);

    /* ---- struct rga_version_t ---- */
    EMIT_SIZE("rga_version_t", struct rga_version_t);
    EMIT_MEMBER("rga_version_t", struct rga_version_t, major);
    EMIT_MEMBER("rga_version_t", struct rga_version_t, minor);
    EMIT_MEMBER("rga_version_t", struct rga_version_t, revision);
    EMIT_MEMBER("rga_version_t", struct rga_version_t, str);

    /* ---- struct rga_hw_versions_t ---- */
    EMIT_SIZE("rga_hw_versions_t", struct rga_hw_versions_t);
    EMIT_MEMBER("rga_hw_versions_t", struct rga_hw_versions_t, version);
    EMIT_MEMBER("rga_hw_versions_t", struct rga_hw_versions_t, size);

    /* ---- struct rga_memory_parm ---- */
    EMIT_SIZE("rga_memory_parm", struct rga_memory_parm);
    EMIT_MEMBER("rga_memory_parm", struct rga_memory_parm, width);
    EMIT_MEMBER("rga_memory_parm", struct rga_memory_parm, height);
    EMIT_MEMBER("rga_memory_parm", struct rga_memory_parm, format);
    EMIT_MEMBER("rga_memory_parm", struct rga_memory_parm, size);

    /* ---- struct rga_external_buffer (member memory_parm <-> memory_info) ---- */
    EMIT_SIZE("rga_external_buffer", struct rga_external_buffer);
    EMIT_MEMBER("rga_external_buffer", struct rga_external_buffer, memory);
    EMIT_MEMBER("rga_external_buffer", struct rga_external_buffer, type);
    EMIT_MEMBER("rga_external_buffer", struct rga_external_buffer, handle);
    EMIT_MEMBER("rga_external_buffer", struct rga_external_buffer, memory_parm);
    EMIT_MEMBER("rga_external_buffer", struct rga_external_buffer, reserve);

    /* ---- struct rga_buffer_pool (member buffers_ptr <-> buffers) ---- */
    EMIT_SIZE("rga_buffer_pool", struct rga_buffer_pool);
    EMIT_MEMBER("rga_buffer_pool", struct rga_buffer_pool, buffers_ptr);
    EMIT_MEMBER("rga_buffer_pool", struct rga_buffer_pool, size);

    /* ---- struct rga_img_info_t (member compact_mode <-> is_10b_compact) ---- */
    EMIT_SIZE("rga_img_info_t", struct rga_img_info_t);
    EMIT_MEMBER("rga_img_info_t", struct rga_img_info_t, yrgb_addr);
    EMIT_MEMBER("rga_img_info_t", struct rga_img_info_t, uv_addr);
    EMIT_MEMBER("rga_img_info_t", struct rga_img_info_t, v_addr);
    EMIT_MEMBER("rga_img_info_t", struct rga_img_info_t, format);
    EMIT_MEMBER("rga_img_info_t", struct rga_img_info_t, act_w);
    EMIT_MEMBER("rga_img_info_t", struct rga_img_info_t, act_h);
    EMIT_MEMBER("rga_img_info_t", struct rga_img_info_t, x_offset);
    EMIT_MEMBER("rga_img_info_t", struct rga_img_info_t, y_offset);
    EMIT_MEMBER("rga_img_info_t", struct rga_img_info_t, vir_w);
    EMIT_MEMBER("rga_img_info_t", struct rga_img_info_t, vir_h);
    EMIT_MEMBER("rga_img_info_t", struct rga_img_info_t, endian_mode);
    EMIT_MEMBER("rga_img_info_t", struct rga_img_info_t, alpha_swap);
    EMIT_MEMBER("rga_img_info_t", struct rga_img_info_t, rotate_mode);
    EMIT_MEMBER("rga_img_info_t", struct rga_img_info_t, rd_mode);
    EMIT_MEMBER("rga_img_info_t", struct rga_img_info_t, compact_mode);
    EMIT_MEMBER("rga_img_info_t", struct rga_img_info_t, is_10b_endian);
    EMIT_MEMBER("rga_img_info_t", struct rga_img_info_t, enable);

    /* ---- struct rga_user_request ---- */
    EMIT_SIZE("rga_user_request", struct rga_user_request);
    EMIT_MEMBER("rga_user_request", struct rga_user_request, task_ptr);
    EMIT_MEMBER("rga_user_request", struct rga_user_request, task_num);
    EMIT_MEMBER("rga_user_request", struct rga_user_request, id);
    EMIT_MEMBER("rga_user_request", struct rga_user_request, sync_mode);
    EMIT_MEMBER("rga_user_request", struct rga_user_request, release_fence_fd);
    EMIT_MEMBER("rga_user_request", struct rga_user_request, mpi_config_flags);
    EMIT_MEMBER("rga_user_request", struct rga_user_request, acquire_fence_fd);
    EMIT_MEMBER("rga_user_request", struct rga_user_request, reservr);

    /* ---- struct rga_req: the big one, and the first assert that matters ---- */
    EMIT_SIZE("rga_req", struct rga_req);
    EMIT_MEMBER("rga_req", struct rga_req, render_mode);
    EMIT_MEMBER("rga_req", struct rga_req, src);
    EMIT_MEMBER("rga_req", struct rga_req, dst);
    EMIT_MEMBER("rga_req", struct rga_req, pat);
    EMIT_MEMBER("rga_req", struct rga_req, rop_mask_addr);
    EMIT_MEMBER("rga_req", struct rga_req, LUT_addr);
    EMIT_MEMBER("rga_req", struct rga_req, clip);
    EMIT_MEMBER("rga_req", struct rga_req, sina);
    EMIT_MEMBER("rga_req", struct rga_req, cosa);
    EMIT_MEMBER("rga_req", struct rga_req, alpha_rop_flag);
    EMIT_MEMBER("rga_req", struct rga_req, interp);
    EMIT_MEMBER("rga_req", struct rga_req, scale_mode);
    EMIT_MEMBER("rga_req", struct rga_req, color_key_max);
    EMIT_MEMBER("rga_req", struct rga_req, color_key_min);
    EMIT_MEMBER("rga_req", struct rga_req, fg_color);
    EMIT_MEMBER("rga_req", struct rga_req, bg_color);
    EMIT_MEMBER("rga_req", struct rga_req, gr_color);
    EMIT_MEMBER("rga_req", struct rga_req, line_draw_info);
    EMIT_MEMBER("rga_req", struct rga_req, fading);
    EMIT_MEMBER("rga_req", struct rga_req, PD_mode);
    EMIT_MEMBER("rga_req", struct rga_req, alpha_global_value);
    EMIT_MEMBER("rga_req", struct rga_req, rop_code);
    EMIT_MEMBER("rga_req", struct rga_req, bsfilter_flag);
    EMIT_MEMBER("rga_req", struct rga_req, palette_mode);
    EMIT_MEMBER("rga_req", struct rga_req, yuv2rgb_mode);
    EMIT_MEMBER("rga_req", struct rga_req, endian_mode);
    EMIT_MEMBER("rga_req", struct rga_req, rotate_mode);
    EMIT_MEMBER("rga_req", struct rga_req, color_fill_mode);
    EMIT_MEMBER("rga_req", struct rga_req, mmu_info);
    EMIT_MEMBER("rga_req", struct rga_req, alpha_rop_mode);
    EMIT_MEMBER("rga_req", struct rga_req, src_trans_mode);
    EMIT_MEMBER("rga_req", struct rga_req, dither_mode);
    EMIT_MEMBER("rga_req", struct rga_req, full_csc);
    EMIT_MEMBER("rga_req", struct rga_req, in_fence_fd);
    EMIT_MEMBER("rga_req", struct rga_req, core);
    EMIT_MEMBER("rga_req", struct rga_req, priority);
    EMIT_MEMBER("rga_req", struct rga_req, out_fence_fd);
    EMIT_MEMBER("rga_req", struct rga_req, handle_flag);
    EMIT_MEMBER("rga_req", struct rga_req, mosaic_info);
    EMIT_MEMBER("rga_req", struct rga_req, uvhds_mode);
    EMIT_MEMBER("rga_req", struct rga_req, uvvds_mode);
    EMIT_MEMBER("rga_req", struct rga_req, osd_info);
    EMIT_MEMBER("rga_req", struct rga_req, pre_intr_info);
    EMIT_MEMBER("rga_req", struct rga_req, fg_global_alpha);
    EMIT_MEMBER("rga_req", struct rga_req, bg_global_alpha);
    EMIT_MEMBER("rga_req", struct rga_req, feature);
    EMIT_MEMBER("rga_req", struct rga_req, full_csc_clip);
    EMIT_MEMBER("rga_req", struct rga_req, rgba5551_alpha);
    EMIT_MEMBER("rga_req", struct rga_req, gauss_config);
    EMIT_MEMBER("rga_req", struct rga_req, reservr);

    /*
     * ---- nested types reached through struct rga_req ----
     *
     * Not strictly required by the parity contract, but a bare
     * "sizeof(rga_req) differs" is close to useless when it fires at 03:00.
     * Sizing every constituent turns one opaque failure into a pointer at the
     * offending sub-structure.
     */
    EMIT_SIZE("rga_rect_t", struct rga_rect_t);
    EMIT_MEMBER("rga_rect_t", struct rga_rect_t, xmin);
    EMIT_MEMBER("rga_rect_t", struct rga_rect_t, xmax);
    EMIT_MEMBER("rga_rect_t", struct rga_rect_t, ymin);
    EMIT_MEMBER("rga_rect_t", struct rga_rect_t, ymax);

    EMIT_SIZE("rga_point_t", struct rga_point_t);
    EMIT_MEMBER("rga_point_t", struct rga_point_t, x);
    EMIT_MEMBER("rga_point_t", struct rga_point_t, y);

    EMIT_SIZE("rga_mmu_t", struct rga_mmu_t);
    EMIT_MEMBER("rga_mmu_t", struct rga_mmu_t, mmu_en);
    EMIT_MEMBER("rga_mmu_t", struct rga_mmu_t, base_addr);
    EMIT_MEMBER("rga_mmu_t", struct rga_mmu_t, mmu_flag);

    EMIT_SIZE("rga_color_fill_t", struct rga_color_fill_t);
    EMIT_MEMBER("rga_color_fill_t", struct rga_color_fill_t, gr_x_a);
    EMIT_MEMBER("rga_color_fill_t", struct rga_color_fill_t, gr_y_r);

    EMIT_SIZE("rga_fading_t", struct rga_fading_t);
    EMIT_MEMBER("rga_fading_t", struct rga_fading_t, b);
    EMIT_MEMBER("rga_fading_t", struct rga_fading_t, g);
    EMIT_MEMBER("rga_fading_t", struct rga_fading_t, r);
    EMIT_MEMBER("rga_fading_t", struct rga_fading_t, res);

    EMIT_SIZE("rga_line_draw_t", struct rga_line_draw_t);
    EMIT_MEMBER("rga_line_draw_t", struct rga_line_draw_t, start_point);
    EMIT_MEMBER("rga_line_draw_t", struct rga_line_draw_t, end_point);
    EMIT_MEMBER("rga_line_draw_t", struct rga_line_draw_t, color);
    EMIT_MEMBER("rga_line_draw_t", struct rga_line_draw_t, flag);
    EMIT_MEMBER("rga_line_draw_t", struct rga_line_draw_t, line_width);

    EMIT_SIZE("rga_csc_coe", struct rga_csc_coe);
    EMIT_MEMBER("rga_csc_coe", struct rga_csc_coe, r_v);
    EMIT_MEMBER("rga_csc_coe", struct rga_csc_coe, g_y);
    EMIT_MEMBER("rga_csc_coe", struct rga_csc_coe, b_u);
    EMIT_MEMBER("rga_csc_coe", struct rga_csc_coe, off);

    EMIT_SIZE("rga_full_csc", struct rga_full_csc);
    EMIT_MEMBER("rga_full_csc", struct rga_full_csc, flag);
    EMIT_MEMBER("rga_full_csc", struct rga_full_csc, coe_y);
    EMIT_MEMBER("rga_full_csc", struct rga_full_csc, coe_u);
    EMIT_MEMBER("rga_full_csc", struct rga_full_csc, coe_v);

    EMIT_SIZE("rga_csc_range", struct rga_csc_range);
    EMIT_MEMBER("rga_csc_range", struct rga_csc_range, max);
    EMIT_MEMBER("rga_csc_range", struct rga_csc_range, min);

    EMIT_SIZE("rga_csc_clip", struct rga_csc_clip);
    EMIT_MEMBER("rga_csc_clip", struct rga_csc_clip, y);
    EMIT_MEMBER("rga_csc_clip", struct rga_csc_clip, uv);

    EMIT_SIZE("rga_mosaic_info", struct rga_mosaic_info);
    EMIT_MEMBER("rga_mosaic_info", struct rga_mosaic_info, enable);
    EMIT_MEMBER("rga_mosaic_info", struct rga_mosaic_info, mode);

    EMIT_SIZE("rga_gauss_config", struct rga_gauss_config);
    EMIT_MEMBER("rga_gauss_config", struct rga_gauss_config, size);
    EMIT_MEMBER("rga_gauss_config", struct rga_gauss_config, coe_ptr);

    EMIT_SIZE("rga_osd_invert_factor", struct rga_osd_invert_factor);
    EMIT_MEMBER("rga_osd_invert_factor", struct rga_osd_invert_factor, alpha_max);
    EMIT_MEMBER("rga_osd_invert_factor", struct rga_osd_invert_factor, crb_min);

    EMIT_SIZE("rga_color", struct rga_color);
    EMIT_MEMBER("rga_color", struct rga_color, red);
    EMIT_MEMBER("rga_color", struct rga_color, alpha);
    EMIT_MEMBER("rga_color", struct rga_color, value);

    EMIT_SIZE("rga_osd_bpp2", struct rga_osd_bpp2);
    EMIT_MEMBER("rga_osd_bpp2", struct rga_osd_bpp2, ac_swap);
    EMIT_MEMBER("rga_osd_bpp2", struct rga_osd_bpp2, endian_swap);
    EMIT_MEMBER("rga_osd_bpp2", struct rga_osd_bpp2, color0);
    EMIT_MEMBER("rga_osd_bpp2", struct rga_osd_bpp2, color1);

    EMIT_SIZE("rga_osd_mode_ctrl", struct rga_osd_mode_ctrl);
    EMIT_MEMBER("rga_osd_mode_ctrl", struct rga_osd_mode_ctrl, mode);
    EMIT_MEMBER("rga_osd_mode_ctrl", struct rga_osd_mode_ctrl, direction_mode);
    EMIT_MEMBER("rga_osd_mode_ctrl", struct rga_osd_mode_ctrl, width_mode);
    EMIT_MEMBER("rga_osd_mode_ctrl", struct rga_osd_mode_ctrl, block_fix_width);
    EMIT_MEMBER("rga_osd_mode_ctrl", struct rga_osd_mode_ctrl, block_num);
    EMIT_MEMBER("rga_osd_mode_ctrl", struct rga_osd_mode_ctrl, flags_index);
    EMIT_MEMBER("rga_osd_mode_ctrl", struct rga_osd_mode_ctrl, color_mode);
    EMIT_MEMBER("rga_osd_mode_ctrl", struct rga_osd_mode_ctrl, invert_flags_mode);
    EMIT_MEMBER("rga_osd_mode_ctrl", struct rga_osd_mode_ctrl, default_color_sel);
    EMIT_MEMBER("rga_osd_mode_ctrl", struct rga_osd_mode_ctrl, invert_enable);
    EMIT_MEMBER("rga_osd_mode_ctrl", struct rga_osd_mode_ctrl, invert_mode);
    EMIT_MEMBER("rga_osd_mode_ctrl", struct rga_osd_mode_ctrl, invert_thresh);
    EMIT_MEMBER("rga_osd_mode_ctrl", struct rga_osd_mode_ctrl, unfix_index);

    EMIT_SIZE("rga_osd_info", struct rga_osd_info);
    EMIT_MEMBER("rga_osd_info", struct rga_osd_info, enable);
    EMIT_MEMBER("rga_osd_info", struct rga_osd_info, mode_ctrl);
    EMIT_MEMBER("rga_osd_info", struct rga_osd_info, cal_factor);
    EMIT_MEMBER("rga_osd_info", struct rga_osd_info, bpp2_info);
    EMIT_MEMBER("rga_osd_info", struct rga_osd_info, last_flags);
    EMIT_MEMBER("rga_osd_info", struct rga_osd_info, last_flags0);
    EMIT_MEMBER("rga_osd_info", struct rga_osd_info, last_flags1);
    EMIT_MEMBER("rga_osd_info", struct rga_osd_info, cur_flags);
    EMIT_MEMBER("rga_osd_info", struct rga_osd_info, cur_flags0);
    EMIT_MEMBER("rga_osd_info", struct rga_osd_info, cur_flags1);

    EMIT_SIZE("rga_pre_intr_info", struct rga_pre_intr_info);
    EMIT_MEMBER("rga_pre_intr_info", struct rga_pre_intr_info, enable);
    EMIT_MEMBER("rga_pre_intr_info", struct rga_pre_intr_info, read_intr_en);
    EMIT_MEMBER("rga_pre_intr_info", struct rga_pre_intr_info, write_intr_en);
    EMIT_MEMBER("rga_pre_intr_info", struct rga_pre_intr_info, read_hold_en);
    EMIT_MEMBER("rga_pre_intr_info", struct rga_pre_intr_info, read_threshold);
    EMIT_MEMBER("rga_pre_intr_info", struct rga_pre_intr_info, write_start);
    EMIT_MEMBER("rga_pre_intr_info", struct rga_pre_intr_info, write_step);

    /* Bitfield-bearing types: sizeof only, offsetof is not applicable. */
    EMIT_SIZE("rga_feature", struct rga_feature);
    EMIT_SIZE("rga_interp", struct rga_interp);

    EMIT_SIZE("rga_rgba5551_alpha", struct rga_rgba5551_alpha);
    EMIT_MEMBER("rga_rgba5551_alpha", struct rga_rgba5551_alpha, flags);
    EMIT_MEMBER("rga_rgba5551_alpha", struct rga_rgba5551_alpha, alpha0);
    EMIT_MEMBER("rga_rgba5551_alpha", struct rga_rgba5551_alpha, alpha1);

    return 0;
}
