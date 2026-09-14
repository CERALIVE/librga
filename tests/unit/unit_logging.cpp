/* SPDX-License-Identifier: Apache-2.0 */
// Modified by CeraLive 2026-09-14: assert library diagnostics use stderr with context.
#include <cstdio>
#include <cstring>
#include <dlfcn.h>
#include <unistd.h>

#include "im2d.h"
#include "RockchipRga.h"
#include "NormalRgaContext.h"

#include "unit_assert.h"

struct captured_imcheck {
    IM_STATUS status;
    char stdout_text[1024];
    char stderr_text[1024];
};

static bool read_pipe(int fd, char *text, size_t text_size)
{
    size_t length = 0;
    while (length + 1 < text_size) {
        ssize_t read_count = read(fd, text + length, text_size - 1 - length);
        if (read_count < 0)
            return false;
        if (read_count == 0)
            break;
        length += (size_t)read_count;
    }
    text[length] = '\0';
    return true;
}

static bool capture_call(captured_imcheck *capture, IM_STATUS (*operation)(void))
{
    int stdout_pipe[2];
    int stderr_pipe[2];
    if (pipe(stdout_pipe) || pipe(stderr_pipe))
        return false;

    int saved_stdout = dup(STDOUT_FILENO);
    int saved_stderr = dup(STDERR_FILENO);
    if (saved_stdout < 0 || saved_stderr < 0)
        return false;

    fflush(NULL);
    if (dup2(stdout_pipe[1], STDOUT_FILENO) < 0 || dup2(stderr_pipe[1], STDERR_FILENO) < 0)
        return false;

    capture->status = operation();

    fflush(NULL);
    if (dup2(saved_stdout, STDOUT_FILENO) < 0 || dup2(saved_stderr, STDERR_FILENO) < 0)
        return false;
    close(saved_stdout);
    close(saved_stderr);
    close(stdout_pipe[1]);
    close(stderr_pipe[1]);

    bool stdout_read = read_pipe(stdout_pipe[0], capture->stdout_text, sizeof(capture->stdout_text));
    bool stderr_read = read_pipe(stderr_pipe[0], capture->stderr_text, sizeof(capture->stderr_text));
    close(stdout_pipe[0]);
    close(stderr_pipe[0]);
    return stdout_read && stderr_read;
}

static IM_STATUS invalid_size_imcheck(void)
{
    char buffer[16] = {0};
    rga_buffer_t src = wrapbuffer_virtualaddr_t(buffer, 1, 1, 1, 1, RK_FORMAT_RGBA_8888);
    rga_buffer_t dst = wrapbuffer_virtualaddr_t(buffer, 1, 1, 1, 1, RK_FORMAT_RGBA_8888);
    rga_buffer_t pat = {};
    im_rect nothing = {};
    return imcheck_t(src, dst, pat, nothing, nothing, nothing, 0);
}

static IM_STATUS legacy_constructor(void)
{
    RockchipRga rga;
    return IM_STATUS_SUCCESS;
}

static IM_STATUS legacy_macros(void)
{
    ALOGI("legacy info selected");
    ALOGD("legacy debug selected");
    ALOGE("legacy error selected");
    return IM_STATUS_SUCCESS;
}

static void check_legacy_logging(void)
{
    unit_begin("legacy diagnostics without the im2d global gate");
    unit_eq_int("unset ROCKCHIP_RGA_LOG", 0, unsetenv("ROCKCHIP_RGA_LOG"));
    unit_eq_int("global logging is disabled", 0, rga_log_enable_update());
    const char *levels[] = {"0", "6"};
    for (const char *level : levels) {
        unit_eq_int("set independent im2d threshold", 0,
                    setenv("ROCKCHIP_RGA_LOG_LEVEL", level, 1));
        rga_log_level_update();
        captured_imcheck constructor = {};
        unit_eq_int("capture legacy constructor", 1, capture_call(&constructor, legacy_constructor));
        unit_eq_int("constructor keeps stdout empty", 0, strlen(constructor.stdout_text));
        unit_eq_int("constructor notice survives disabled logging", 1,
                    strstr(constructor.stderr_text, "librga: current rga_api version") != NULL);
        unit_eq_int("constructor keeps deprecation guidance", 1,
                    strstr(constructor.stderr_text, "The called RockchipRga API is deprecated") != NULL);
        captured_imcheck macros = {};
        unit_eq_int("capture legacy macros", 1, capture_call(&macros, legacy_macros));
        unit_eq_int("macros keep stdout empty", 0, strlen(macros.stdout_text));
        unit_eq_int("all selected legacy severities emit", 0,
                    strcmp(macros.stderr_text, "librga: legacy info selected\n"
                           "librga: legacy debug selected\n"
                           "librga: legacy error selected\n"));
    }
}

static RockchipRga *setter_rga;

static IM_STATUS legacy_fill(void)
{
    char pixels[16 * 16 * 4] = {};
    rga_info_t dst = {};
    dst.virAddr = pixels;
    dst.mmuFlag = 1;
    rga_set_rect(&dst.rect, 0, 0, 16, 16, 16, 16, RK_FORMAT_RGBA_8888);
    return setter_rga->RkRgaCollorFill(&dst) == 0 ? IM_STATUS_SUCCESS : IM_STATUS_FAILED;
}

static void check_legacy_setter(bool once)
{
    unit_begin(once ? "public legacy once setter" : "public legacy always setter");
    unit_eq_int("unset ROCKCHIP_RGA_LOG", 0, unsetenv("ROCKCHIP_RGA_LOG"));
    unit_eq_int("global logging is disabled", 0, rga_log_enable_update());
    RockchipRga rga;
    setter_rga = &rga;
    unit_eq_int("fake device is ready", 1, rga.RkRgaIsReady());
    if (once)
        rga.RkRgaSetLogOnceFlag(1);
    else
        rga.RkRgaSetAlwaysLogFlag(true);
    captured_imcheck capture = {};
    unit_eq_int("capture successful legacy operation", 1, capture_call(&capture, legacy_fill));
    unit_eq_int("legacy fill succeeded", IM_STATUS_SUCCESS, capture.status);
    unit_eq_int("setter does not enable process-wide logging", 0, rga_log_enable_get());
    unit_eq_int("setter leaves global env unset", 1, getenv("ROCKCHIP_RGA_LOG") == NULL);
    unit_eq_int("legacy fill stdout empty", 0, strlen(capture.stdout_text));
    unit_eq_int("requested operation diagnostic emitted", 1,
                strstr(capture.stderr_text, "librga: <<<<-------- print rgaLog -------->>>>") != NULL);
    setter_rga = NULL;
}

static void check_no_device_logging(void)
{
    captured_imcheck capture = {};
    unit_begin("(g) logging without a device");
    unit_eq_int("capture failure diagnostic", 1, capture_call(&capture, invalid_size_imcheck));
    unit_eq_int("no-device status remains NO_SESSION", IM_STATUS_NO_SESSION, capture.status);
    unit_eq_int("library emits no stdout diagnostic", 0, (long)strlen(capture.stdout_text));
    unit_eq_int("stderr keeps failed-open message", 1,
                strstr(capture.stderr_text, "failed to open /dev/rga") != NULL);
    unit_eq_int("stderr adds librga context", 1,
                strstr(capture.stderr_text, "librga:") != NULL);
}

static void check_fake_device_logging(void)
{
    captured_imcheck capture = {};
    unit_begin("(g) logging with a fake device");
    unit_eq_int("capture version banner", 1, capture_call(&capture, invalid_size_imcheck));
    unit_eq_int("fake-device size status remains ILLEGAL_PARAM", IM_STATUS_ILLEGAL_PARAM,
                capture.status);
    unit_eq_int("library emits no stdout version banner", 0, (long)strlen(capture.stdout_text));
    unit_eq_int("stderr keeps version-banner message", 1,
                strstr(capture.stderr_text, "rga_api version") != NULL);
    unit_eq_int("stderr adds librga context", 1,
                strstr(capture.stderr_text, "librga:") != NULL);
}

int main(int argc, char **argv)
{
    if (argc != 2)
        return 2;
    if (strcmp(argv[1], "no-device") == 0)
        check_no_device_logging();
    else if (strcmp(argv[1], "fake-device") == 0)
        check_fake_device_logging();
    else if (strcmp(argv[1], "legacy-once") == 0 || strcmp(argv[1], "legacy-always") == 0) {
        if (dlsym(RTLD_DEFAULT, "fake_rga_active") == NULL)
            return 2;
        check_legacy_setter(strcmp(argv[1], "legacy-once") == 0);
        return unit_report("unit-logging-setter");
    }
    else
        return 2;
    check_legacy_logging();
    return unit_report("unit-logging");
}
