/* SPDX-License-Identifier: Apache-2.0 */
#ifndef CERALIVE_ORACLE_H
#define CERALIVE_ORACLE_H
#include <stddef.h>
#include <stdint.h>
enum oracle_matrix { ORACLE_BT601, ORACLE_BT709 };
enum oracle_range { ORACLE_LIMITED, ORACLE_FULL };
enum oracle_filter { ORACLE_BOX, ORACLE_BILINEAR };
void oracle_rgb_to_yuv(const uint8_t rgb[3], uint8_t yuv[3], enum oracle_matrix matrix, enum oracle_range range);
void oracle_yuv_to_rgb(const uint8_t yuv[3], uint8_t rgb[3], enum oracle_matrix matrix, enum oracle_range range);
double oracle_psnr(const uint8_t *a, const uint8_t *b, size_t size);
void oracle_resample(const uint8_t *src, int sw, int sh, int stride, int step,
                     uint8_t *dst, int dw, int dh, int dstride, int dstep,
                     enum oracle_filter filter);
#endif
