/*
 * Copyright (C) 2016 Rockchip Electronics Co., Ltd.
 * Authors:
 *  Zhiqin Wei <wzq@rock-chips.com>
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
// Modified by CeraLive 2026-09-14: route legacy diagnostics to stderr with context.

#ifndef _rockchip_normal_rga_context_h_
#define _rockchip_normal_rga_context_h_

#include <stdio.h>

#include "rga_ioctl.h"
#include "src/im2d_context.h"
#include "src/im2d_log.h"

#ifndef ANDROID
#define ALOGI(...) do { \
    RGA_LOG_STDERR(__VA_ARGS__); \
    fprintf(stderr, "\n"); \
} while (0)
#define ALOGD(...) do { \
    RGA_LOG_STDERR(__VA_ARGS__); \
    fprintf(stderr, "\n"); \
} while (0)
#define ALOGE(...) do { RGA_LOG_STDERR(__VA_ARGS__); fprintf(stderr, "\n"); } while (0)
#endif

struct rgaContext {
    int rgaFd;
    int mLogAlways;
    int mLogOnce;
    float mVersion;
    int Is_debug;
    struct rga_hw_versions_t mHwVersions;
    struct rga_version_t mDriverVersion;
    RGA_DRIVER_IOC_TYPE driver;
    uint32_t driver_feature;
};
#endif
