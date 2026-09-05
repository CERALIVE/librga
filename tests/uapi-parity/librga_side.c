/*
 * librga side of the multi_rga UAPI parity gate.
 *
 * Includes ONLY this repository's own UAPI view --- include/rga.h and
 * core/hardware/rga_ioctl.h --- and prints the same flat {kind, name, value}
 * table island_side.c prints. Nothing about the island is visible from here.
 *
 * Type names differ cosmetically between the two sides (the island spells
 * things `struct rga_rect_t` where librga inherited the Android-era `RECT`
 * typedef). A type name is not ABI, so the emitted LABEL is normalised to the
 * island's spelling and the mapping is documented in compare.py's TYPE_ALIASES
 * and in docs/UAPI-PARITY.md.
 *
 * MEMBER names are a different matter --- code on both sides addresses fields
 * by name --- so they are emitted verbatim as librga spells them, and
 * compare.py reconciles the three genuine renames through an explicit alias
 * map. Normalising them here would hide the divergence instead of recording it.
 */

#include <stdio.h>
#include <stddef.h>

#include "rga.h"
#include "rga_ioctl.h"

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
    printf("#side\tlibrga\n");

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
     * librga-only legacy RGA2 commands. The island header does not declare
     * these; compare.py pins their values so a librga-side renumber is caught.
     */
    EMIT_IOCTL(RGA2_BLIT_SYNC);
    EMIT_IOCTL(RGA2_BLIT_ASYNC);
    EMIT_IOCTL(RGA2_FLUSH);

    /* Sizing constants that participate in the ABI. */
    EMIT_IOCTL(RGA_VERSION_SIZE);
    EMIT_IOCTL(RGA_HW_SIZE);
    EMIT_IOCTL(RGA_TASK_NUM_MAX);
    EMIT_IOCTL(RGA_SCHED_PRIORITY_DEFAULT);
    EMIT_IOCTL(RGA_SCHED_PRIORITY_MAX);

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

    /* ---- struct rga_external_buffer (member memory_info <-> memory_parm) ---- */
    EMIT_SIZE("rga_external_buffer", struct rga_external_buffer);
    EMIT_MEMBER("rga_external_buffer", struct rga_external_buffer, memory);
    EMIT_MEMBER("rga_external_buffer", struct rga_external_buffer, type);
    EMIT_MEMBER("rga_external_buffer", struct rga_external_buffer, handle);
    EMIT_MEMBER("rga_external_buffer", struct rga_external_buffer, memory_info);
    EMIT_MEMBER("rga_external_buffer", struct rga_external_buffer, reserve);

    /* ---- struct rga_buffer_pool (member buffers <-> buffers_ptr) ---- */
    EMIT_SIZE("rga_buffer_pool", struct rga_buffer_pool);
    EMIT_MEMBER("rga_buffer_pool", struct rga_buffer_pool, buffers);
    EMIT_MEMBER("rga_buffer_pool", struct rga_buffer_pool, size);

    /* ---- struct rga_img_info_t (member is_10b_compact <-> compact_mode) ---- */
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
    EMIT_MEMBER("rga_img_info_t", struct rga_img_info_t, is_10b_compact);
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

    /* ---- nested types reached through struct rga_req ---- */
    EMIT_SIZE("rga_rect_t", RECT);
    EMIT_MEMBER("rga_rect_t", RECT, xmin);
    EMIT_MEMBER("rga_rect_t", RECT, xmax);
    EMIT_MEMBER("rga_rect_t", RECT, ymin);
    EMIT_MEMBER("rga_rect_t", RECT, ymax);

    EMIT_SIZE("rga_point_t", POINT);
    EMIT_MEMBER("rga_point_t", POINT, x);
    EMIT_MEMBER("rga_point_t", POINT, y);

    EMIT_SIZE("rga_mmu_t", MMU);
    EMIT_MEMBER("rga_mmu_t", MMU, mmu_en);
    EMIT_MEMBER("rga_mmu_t", MMU, base_addr);
    EMIT_MEMBER("rga_mmu_t", MMU, mmu_flag);

    EMIT_SIZE("rga_color_fill_t", COLOR_FILL);
    EMIT_MEMBER("rga_color_fill_t", COLOR_FILL, gr_x_a);
    EMIT_MEMBER("rga_color_fill_t", COLOR_FILL, gr_y_r);

    EMIT_SIZE("rga_fading_t", FADING);
    EMIT_MEMBER("rga_fading_t", FADING, b);
    EMIT_MEMBER("rga_fading_t", FADING, g);
    EMIT_MEMBER("rga_fading_t", FADING, r);
    EMIT_MEMBER("rga_fading_t", FADING, res);

    EMIT_SIZE("rga_line_draw_t", line_draw_t);
    EMIT_MEMBER("rga_line_draw_t", line_draw_t, start_point);
    EMIT_MEMBER("rga_line_draw_t", line_draw_t, end_point);
    EMIT_MEMBER("rga_line_draw_t", line_draw_t, color);
    EMIT_MEMBER("rga_line_draw_t", line_draw_t, flag);
    EMIT_MEMBER("rga_line_draw_t", line_draw_t, line_width);

    EMIT_SIZE("rga_csc_coe", csc_coe_t);
    EMIT_MEMBER("rga_csc_coe", csc_coe_t, r_v);
    EMIT_MEMBER("rga_csc_coe", csc_coe_t, g_y);
    EMIT_MEMBER("rga_csc_coe", csc_coe_t, b_u);
    EMIT_MEMBER("rga_csc_coe", csc_coe_t, off);

    EMIT_SIZE("rga_full_csc", full_csc_t);
    EMIT_MEMBER("rga_full_csc", full_csc_t, flag);
    EMIT_MEMBER("rga_full_csc", full_csc_t, coe_y);
    EMIT_MEMBER("rga_full_csc", full_csc_t, coe_u);
    EMIT_MEMBER("rga_full_csc", full_csc_t, coe_v);

    EMIT_SIZE("rga_csc_range", struct rga_csc_range);
    EMIT_MEMBER("rga_csc_range", struct rga_csc_range, max);
    EMIT_MEMBER("rga_csc_range", struct rga_csc_range, min);

    EMIT_SIZE("rga_csc_clip", struct rga_csc_clip);
    EMIT_MEMBER("rga_csc_clip", struct rga_csc_clip, y);
    EMIT_MEMBER("rga_csc_clip", struct rga_csc_clip, uv);

    EMIT_SIZE("rga_mosaic_info", rga_mosaic_info_t);
    EMIT_MEMBER("rga_mosaic_info", rga_mosaic_info_t, enable);
    EMIT_MEMBER("rga_mosaic_info", rga_mosaic_info_t, mode);

    EMIT_SIZE("rga_gauss_config", rga_gauss_config_t);
    EMIT_MEMBER("rga_gauss_config", rga_gauss_config_t, size);
    EMIT_MEMBER("rga_gauss_config", rga_gauss_config_t, coe_ptr);

    EMIT_SIZE("rga_osd_invert_factor", rga_osd_invert_factor_t);
    EMIT_MEMBER("rga_osd_invert_factor", rga_osd_invert_factor_t, alpha_max);
    EMIT_MEMBER("rga_osd_invert_factor", rga_osd_invert_factor_t, crb_min);

    EMIT_SIZE("rga_color", rga_color_t);
    EMIT_MEMBER("rga_color", rga_color_t, red);
    EMIT_MEMBER("rga_color", rga_color_t, alpha);
    EMIT_MEMBER("rga_color", rga_color_t, value);

    EMIT_SIZE("rga_osd_bpp2", rga_osd_bpp2_t);
    EMIT_MEMBER("rga_osd_bpp2", rga_osd_bpp2_t, ac_swap);
    EMIT_MEMBER("rga_osd_bpp2", rga_osd_bpp2_t, endian_swap);
    EMIT_MEMBER("rga_osd_bpp2", rga_osd_bpp2_t, color0);
    EMIT_MEMBER("rga_osd_bpp2", rga_osd_bpp2_t, color1);

    EMIT_SIZE("rga_osd_mode_ctrl", rga_osd_mode_ctrl_t);
    EMIT_MEMBER("rga_osd_mode_ctrl", rga_osd_mode_ctrl_t, mode);
    EMIT_MEMBER("rga_osd_mode_ctrl", rga_osd_mode_ctrl_t, direction_mode);
    EMIT_MEMBER("rga_osd_mode_ctrl", rga_osd_mode_ctrl_t, width_mode);
    EMIT_MEMBER("rga_osd_mode_ctrl", rga_osd_mode_ctrl_t, block_fix_width);
    EMIT_MEMBER("rga_osd_mode_ctrl", rga_osd_mode_ctrl_t, block_num);
    EMIT_MEMBER("rga_osd_mode_ctrl", rga_osd_mode_ctrl_t, flags_index);
    EMIT_MEMBER("rga_osd_mode_ctrl", rga_osd_mode_ctrl_t, color_mode);
    EMIT_MEMBER("rga_osd_mode_ctrl", rga_osd_mode_ctrl_t, invert_flags_mode);
    EMIT_MEMBER("rga_osd_mode_ctrl", rga_osd_mode_ctrl_t, default_color_sel);
    EMIT_MEMBER("rga_osd_mode_ctrl", rga_osd_mode_ctrl_t, invert_enable);
    EMIT_MEMBER("rga_osd_mode_ctrl", rga_osd_mode_ctrl_t, invert_mode);
    EMIT_MEMBER("rga_osd_mode_ctrl", rga_osd_mode_ctrl_t, invert_thresh);
    EMIT_MEMBER("rga_osd_mode_ctrl", rga_osd_mode_ctrl_t, unfix_index);

    EMIT_SIZE("rga_osd_info", rga_osd_info_t);
    EMIT_MEMBER("rga_osd_info", rga_osd_info_t, enable);
    EMIT_MEMBER("rga_osd_info", rga_osd_info_t, mode_ctrl);
    EMIT_MEMBER("rga_osd_info", rga_osd_info_t, cal_factor);
    EMIT_MEMBER("rga_osd_info", rga_osd_info_t, bpp2_info);
    EMIT_MEMBER("rga_osd_info", rga_osd_info_t, last_flags);
    EMIT_MEMBER("rga_osd_info", rga_osd_info_t, last_flags0);
    EMIT_MEMBER("rga_osd_info", rga_osd_info_t, last_flags1);
    EMIT_MEMBER("rga_osd_info", rga_osd_info_t, cur_flags);
    EMIT_MEMBER("rga_osd_info", rga_osd_info_t, cur_flags0);
    EMIT_MEMBER("rga_osd_info", rga_osd_info_t, cur_flags1);

    EMIT_SIZE("rga_pre_intr_info", rga_pre_intr_info_t);
    EMIT_MEMBER("rga_pre_intr_info", rga_pre_intr_info_t, enable);
    EMIT_MEMBER("rga_pre_intr_info", rga_pre_intr_info_t, read_intr_en);
    EMIT_MEMBER("rga_pre_intr_info", rga_pre_intr_info_t, write_intr_en);
    EMIT_MEMBER("rga_pre_intr_info", rga_pre_intr_info_t, read_hold_en);
    EMIT_MEMBER("rga_pre_intr_info", rga_pre_intr_info_t, read_threshold);
    EMIT_MEMBER("rga_pre_intr_info", rga_pre_intr_info_t, write_start);
    EMIT_MEMBER("rga_pre_intr_info", rga_pre_intr_info_t, write_step);

    /* Bitfield-bearing types: sizeof only, offsetof is not applicable. */
    EMIT_SIZE("rga_feature", struct rga_feature);
    EMIT_SIZE("rga_interp", struct rga_interp);

    EMIT_SIZE("rga_rgba5551_alpha", struct rga_rgba5551_alpha);
    EMIT_MEMBER("rga_rgba5551_alpha", struct rga_rgba5551_alpha, flags);
    EMIT_MEMBER("rga_rgba5551_alpha", struct rga_rgba5551_alpha, alpha0);
    EMIT_MEMBER("rga_rgba5551_alpha", struct rga_rgba5551_alpha, alpha1);

    return 0;
}
