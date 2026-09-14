/* SPDX-License-Identifier: Apache-2.0 */
// Modified by CeraLive 2026-09-14: pin Gaussian framing to value emission.
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <unistd.h>

// The public dumper always forces logging; include the implementation to also
// exercise its private helper's unforced error, threshold and disabled paths.
#include "im2d_debugger.cpp"
#include "unit_assert.h"

static void check_matrix(int level, bool dump_options, bool expected)
{
    int fds[2];
    if (pipe(fds) != 0)
        abort();
    fflush(NULL);
    int saved = dup(STDERR_FILENO);
    if (saved < 0 || dup2(fds[1], STDERR_FILENO) < 0)
        abort();
    double matrix[] = {0.125, 0.25, 0.5, 1.0};
    im_opt_t opt = {};
    opt.gauss_config.ksize = {2, 2};
    opt.gauss_config.matrix = matrix;
    if (dump_options)
        rga_dump_opt(level, &opt, IM_GAUSS);
    else
        rga_dump_gauss_matrix(level, opt.gauss_config.ksize, matrix);
    fflush(stderr);
    if (dup2(saved, STDERR_FILENO) < 0)
        abort();
    close(saved);
    close(fds[1]);
    char text[4096] = {};
    size_t used = 0;
    ssize_t count;
    while ((count = read(fds[0], text + used, sizeof(text) - 1 - used)) > 0)
        used += (size_t)count;
    close(fds[0]);
    unit_eq_int("capture complete matrix", 1, count == 0 && used < sizeof(text) - 1);
    unit_eq_int("matrix value emission", expected, strstr(text, "0.125000 ") != NULL);
    if (expected) {
        unit_eq_int("matrix header", 1, strstr(text, "kernel_matrix[") != NULL);
        unit_eq_int("first row indentation and values", 1,
                    strstr(text, "librga: \t\t\tlibrga: 0.125000 \nlibrga: 0.250000 \n") != NULL);
        unit_eq_int("row break before second row", 1,
                    strstr(text, "librga: \nlibrga: \t\t\tlibrga: 0.500000 \nlibrga: 1.000000 \nlibrga: \n") != NULL);
    } else {
        unit_eq_int("disabled matrix is completely silent", 0, used);
    }
}

int main(void)
{
    unit_begin("Gaussian framing follows IM_LOG force/error/threshold");
    unit_eq_int("unset global log enable", 0, unsetenv("ROCKCHIP_RGA_LOG"));
    unit_eq_int("default log disabled", 0, rga_log_enable_update());
    unit_eq_int("set error threshold", 0, setenv("ROCKCHIP_RGA_LOG_LEVEL", "6", 1));
    rga_log_level_update();
    check_matrix(IM_LOG_DEBUG | IM_LOG_DIRECT, true, true);
    check_matrix(IM_LOG_DEBUG | IM_LOG_DIRECT | IM_LOG_FORCE, false, true);
    check_matrix(IM_LOG_ERROR | IM_LOG_DIRECT, false, true);
    check_matrix(IM_LOG_DEBUG | IM_LOG_DIRECT, false, false);
    unit_eq_int("enable logging", 0, setenv("ROCKCHIP_RGA_LOG", "1", 1));
    rga_log_enable_update();
    check_matrix(IM_LOG_DEBUG, false, false);
    unit_eq_int("set debug threshold", 0, setenv("ROCKCHIP_RGA_LOG_LEVEL", "3", 1));
    rga_log_level_update();
    check_matrix(IM_LOG_DEBUG | IM_LOG_DIRECT, false, true);
    return unit_report("unit-gaussian-logging");
}
