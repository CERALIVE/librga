/* SPDX-License-Identifier: Apache-2.0 */
/*
 * H9(b) — where does a failing imcheck() write its diagnostic?
 *
 * im2d_api/src/im2d_log.h routes every IM_LOG level, IM_LOG_ERROR included,
 * through `fprintf(stdout, ...)`. A caller whose stdout is a pipe, a log file
 * or a media stream therefore gets library error text mixed into its own
 * output rather than onto stderr where a diagnostic belongs.
 *
 * This program points fd 1 at a pipe, asks imcheck() to validate a 1x1 image
 * (below the hardware minimum, so the call must fail), restores fd 1, and
 * reports how many bytes the library put down the pipe.
 */
#include <errno.h>
#include <poll.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mman.h>
#include <unistd.h>

#include "im2d.h"

int main(void)
{
    void *buf = mmap(NULL, 4096, PROT_READ | PROT_WRITE,
                     MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
    if (buf == MAP_FAILED) { perror("mmap"); return 1; }

    rga_buffer_t src = wrapbuffer_virtualaddr_t(buf, 1, 1, 1, 1, RK_FORMAT_RGBA_8888);
    rga_buffer_t dst = wrapbuffer_virtualaddr_t(buf, 1, 1, 1, 1, RK_FORMAT_RGBA_8888);
    rga_buffer_t pat;
    im_rect nothing;
    memset(&pat, 0, sizeof(pat));
    memset(&nothing, 0, sizeof(nothing));

    int pipefd[2];
    if (pipe(pipefd)) { perror("pipe"); return 1; }
    int saved = dup(1);
    if (saved < 0) { perror("dup"); return 1; }

    fflush(stdout);
    if (dup2(pipefd[1], 1) < 0) { perror("dup2"); return 1; }

    IM_STATUS ret = imcheck_t(src, dst, pat, nothing, nothing, nothing, 0);

    /* stdout is fully buffered on a pipe; flush before looking. */
    fflush(stdout);
    if (dup2(saved, 1) < 0) { perror("restore dup2"); return 1; }
    close(saved);
    close(pipefd[1]);

    char captured[8192];
    size_t total = 0;
    for (;;) {
        struct pollfd p = { pipefd[0], POLLIN, 0 };
        int r = poll(&p, 1, 200);
        if (r <= 0) break;
        ssize_t n = read(pipefd[0], captured + total, sizeof(captured) - 1 - total);
        if (n <= 0) break;
        total += (size_t)n;
        if (total >= sizeof(captured) - 1) break;
    }
    captured[total] = '\0';
    close(pipefd[0]);

    printf("h9-stdout: imcheck_t returned %d (%s)\n", ret, imStrError(ret));
    printf("h9-stdout: bytes captured from fd 1: %zu\n", total);
    if (total) {
        printf("h9-stdout: VERDICT the library wrote its error diagnostic to STDOUT\n");
        printf("h9-stdout: captured text begins ---\n%s--- end captured text\n", captured);
    } else {
        printf("h9-stdout: VERDICT nothing reached stdout\n");
    }
    return 0;
}
