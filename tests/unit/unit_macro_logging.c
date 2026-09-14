/* SPDX-License-Identifier: Apache-2.0 */
// Modified by CeraLive 2026-09-14: assert public macro diagnostics do not reach stdout.
#include <stdio.h>
#include <string.h>
#include <unistd.h>

#include "im2d_buffer.h"
#include "im2d_common.h"
#include "im2d_single.h"

static int read_pipe(int fd, char *text, size_t text_size)
{
    size_t length = 0;
    while (length + 1 < text_size) {
        ssize_t read_count = read(fd, text + length, text_size - 1 - length);
        if (read_count < 0)
            return -1;
        if (read_count == 0)
            break;
        length += (size_t)read_count;
    }
    text[length] = '\0';
    return 0;
}

int main(void)
{
    int stdout_pipe[2];
    int stderr_pipe[2];
    char stdout_text[1024];
    char stderr_text[1024];
    rga_buffer_t image = {0};
    im_rect rect = {0};
    int result = 0;

    if (pipe(stdout_pipe) || pipe(stderr_pipe))
        return 2;
    int saved_stdout = dup(STDOUT_FILENO);
    int saved_stderr = dup(STDERR_FILENO);
    if (saved_stdout < 0 || saved_stderr < 0)
        return 2;

    fflush(NULL);
    if (dup2(stdout_pipe[1], STDOUT_FILENO) < 0 || dup2(stderr_pipe[1], STDERR_FILENO) < 0)
        return 2;

    if (imcopy(image, image, 0, 1) != IM_STATUS_INVALID_PARAM)
        result = 1;
    (void)wrapbuffer_fd(3, 2, 2, RK_FORMAT_RGBA_8888, 1, 2, 3);
    if (strstr(imStrError(1, 2), "Fatal error, imStrError() too many parameters") == NULL)
        result = 1;
    if (imcheck(image, image, rect, rect, 0, 1) != IM_STATUS_FAILED)
        result = 1;

    fflush(NULL);
    if (dup2(saved_stdout, STDOUT_FILENO) < 0 || dup2(saved_stderr, STDERR_FILENO) < 0)
        return 2;
    close(saved_stdout);
    close(saved_stderr);
    close(stdout_pipe[1]);
    close(stderr_pipe[1]);
    if (read_pipe(stdout_pipe[0], stdout_text, sizeof(stdout_text)) ||
        read_pipe(stderr_pipe[0], stderr_text, sizeof(stderr_text)))
        return 2;
    close(stdout_pipe[0]);
    close(stderr_pipe[0]);

    if (stdout_text[0] != '\0' ||
        strstr(stderr_text, "librga:") == NULL ||
        strstr(stderr_text, "invalid parameter") == NULL ||
        strstr(stderr_text, "Fatal error, imStrError() too many parameters") == NULL ||
        strstr(stderr_text, "check failed") == NULL)
        result = 1;

    if (result)
        fprintf(stderr, "unit-macro-logging failed: stdout='%s' stderr='%s'\n", stdout_text, stderr_text);
    return result;
}
