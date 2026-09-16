/* SPDX-License-Identifier: Apache-2.0 */
// Modified by CeraLive 2026-09-14: assert library diagnostics use stderr with context.
// Modified by CeraLive 2026-09-15: gate deprecated setters and working diagnostic controls.
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
static bool setter_once;
static int setter_value;

static IM_STATUS legacy_set_flag(void)
{
    if (setter_once)
        setter_rga->RkRgaSetLogOnceFlag(setter_value);
    else
        setter_rga->RkRgaSetAlwaysLogFlag(setter_value != 0);
    return IM_STATUS_SUCCESS;
}

static IM_STATUS legacy_parameter_dump(void)
{
    rga_info_t info = {};
    return setter_rga->RkRgaLogOutUserPara(&info) == 0 ? IM_STATUS_SUCCESS : IM_STATUS_FAILED;
}

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
    unit_begin(once ? "deprecated legacy once setter" : "deprecated legacy always setter");
    unit_eq_int("unset ROCKCHIP_RGA_LOG", 0, unsetenv("ROCKCHIP_RGA_LOG"));
    unit_eq_int("global logging is disabled", 0, rga_log_enable_update());
    RockchipRga rga;
    setter_rga = &rga;
    setter_once = once;
    unit_eq_int("fake device is ready", 1, rga.RkRgaIsReady());
    void *context = NULL;
    rga.RkRgaGetContext(&context);
    unit_eq_int("legacy context exists", 1, context != NULL);
    if (!context) {
        setter_rga = NULL;
        return;
    }
    rgaContext *ctx = static_cast<rgaContext *>(context);
    ctx->mLogOnce = 23;
    ctx->mLogAlways = 47;
    const int values[] = {1, 0, -1, 2};
    for (int value : values) {
        setter_value = value;
        captured_imcheck setter = {};
        unit_eq_int("capture deprecated setter", 1, capture_call(&setter, legacy_set_flag));
        unit_eq_int("setter stdout empty", 0, strlen(setter.stdout_text));
        unit_eq_int("setter emits no runtime warning", 0, strlen(setter.stderr_text));
        for (int operation = 0; operation < 2; ++operation) {
            captured_imcheck capture = {};
            unit_eq_int("capture successful legacy operation", 1, capture_call(&capture, legacy_fill));
            unit_eq_int("legacy fill succeeded", IM_STATUS_SUCCESS, capture.status);
            unit_eq_int("setter does not enable process-wide logging", 0, rga_log_enable_get());
            unit_eq_int("setter leaves global env unset", 1, getenv("ROCKCHIP_RGA_LOG") == NULL);
            unit_eq_int("legacy fill stdout empty", 0, strlen(capture.stdout_text));
            unit_eq_int("deprecated setter leaves operation diagnostics disabled", 0,
                        strlen(capture.stderr_text));
            unit_eq_int("context once flag is separate and unconsumed", 23, ctx->mLogOnce);
            unit_eq_int("context always flag is separate", 47, ctx->mLogAlways);
        }
    }

    unit_eq_int("enable documented Linux operation diagnostics", 0,
                setenv("ROCKCHIP_RGA_LOG", "1", 1));
    setter_value = 0;
    legacy_set_flag();
    for (int operation = 0; operation < 2; ++operation) {
        captured_imcheck enabled = {};
        unit_eq_int("capture environment-enabled fill", 1, capture_call(&enabled, legacy_fill));
        unit_eq_int("environment-enabled fill succeeded", IM_STATUS_SUCCESS, enabled.status);
        unit_eq_int("environment-enabled fill stdout empty", 0, strlen(enabled.stdout_text));
        unit_eq_int("zero setter cannot suppress environment-selected diagnostics", 1,
                    strstr(enabled.stderr_text, "librga: <<<<-------- print rgaLog -------->>>>") != NULL);
        unit_eq_int("environment remains enabled", 0, strcmp(getenv("ROCKCHIP_RGA_LOG"), "1"));
        unit_eq_int("context once flag still unconsumed", 23, ctx->mLogOnce);
        unit_eq_int("context always flag still separate", 47, ctx->mLogAlways);
    }

    unit_eq_int("disable documented Linux operation diagnostics", 0,
                setenv("ROCKCHIP_RGA_LOG", "0", 1));
    setter_value = 1;
    legacy_set_flag();
    captured_imcheck capture = {};
    unit_eq_int("capture explicitly disabled fill", 1, capture_call(&capture, legacy_fill));
    unit_eq_int("explicitly disabled fill succeeded", IM_STATUS_SUCCESS, capture.status);
    unit_eq_int("explicitly disabled fill stdout empty", 0, strlen(capture.stdout_text));
    unit_eq_int("nonzero setter cannot override environment zero", 0, strlen(capture.stderr_text));
    unit_eq_int("setter leaves global logging disabled throughout", 0, rga_log_enable_get());
    unit_eq_int("environment remains zero", 0, strcmp(getenv("ROCKCHIP_RGA_LOG"), "0"));

    captured_imcheck dump = {};
    unit_eq_int("capture explicit parameter dump", 1, capture_call(&dump, legacy_parameter_dump));
    unit_eq_int("explicit dump succeeded", IM_STATUS_SUCCESS, dump.status);
    unit_eq_int("explicit dump stdout empty", 0, strlen(dump.stdout_text));
    unit_eq_int("explicit dump still emits with logging disabled", 1,
                strstr(dump.stderr_text, "librga: handl-fd-vir-phy-hnd-format[") != NULL);
    unit_eq_int("restore absent environment", 0, unsetenv("ROCKCHIP_RGA_LOG"));
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
