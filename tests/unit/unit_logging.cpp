/* SPDX-License-Identifier: Apache-2.0 */
// Modified by CeraLive 2026-09-14: assert library diagnostics use stderr with context.
#include <cstdio>
#include <cstring>
#include <unistd.h>

#include "im2d.h"

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

static bool capture_imcheck(captured_imcheck *capture)
{
    int stdout_pipe[2];
    int stderr_pipe[2];
    if (pipe(stdout_pipe) || pipe(stderr_pipe))
        return false;

    int saved_stdout = dup(STDOUT_FILENO);
    int saved_stderr = dup(STDERR_FILENO);
    if (saved_stdout < 0 || saved_stderr < 0)
        return false;

    char buffer[16] = {0};
    rga_buffer_t src = wrapbuffer_virtualaddr_t(buffer, 1, 1, 1, 1, RK_FORMAT_RGBA_8888);
    rga_buffer_t dst = wrapbuffer_virtualaddr_t(buffer, 1, 1, 1, 1, RK_FORMAT_RGBA_8888);
    rga_buffer_t pat = {};
    im_rect nothing = {};

    fflush(NULL);
    if (dup2(stdout_pipe[1], STDOUT_FILENO) < 0 || dup2(stderr_pipe[1], STDERR_FILENO) < 0)
        return false;

    capture->status = imcheck_t(src, dst, pat, nothing, nothing, nothing, 0);

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

static void check_no_device_logging(void)
{
    captured_imcheck capture = {};
    unit_begin("(g) logging without a device");
    unit_eq_int("capture failure diagnostic", 1, capture_imcheck(&capture));
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
    unit_eq_int("capture version banner", 1, capture_imcheck(&capture));
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
    else
        return 2;
    return unit_report("unit-logging");
}
