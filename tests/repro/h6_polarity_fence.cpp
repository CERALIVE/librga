/* SPDX-License-Identifier: Apache-2.0 */
/* Modified by CeraLive 2026-09-05: reproduce H6 fence ownership on the host. */
/* Modified by CeraLive 2026-09-12: run the unchanged C4 checks alone under ASan/LSan. */
#include <cerrno>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <dirent.h>
#include <dlfcn.h>
#include <fcntl.h>
#include <sys/eventfd.h>
#include <sys/mman.h>
#include <unistd.h>
#include "im2d.hpp"
#include "RgaApi.h"
#include "rga_ioctl.h"

static const int iterations = 200;

#define REQUIRE(expr) do { if (!(expr)) { \
    std::fprintf(stderr, "H6 infrastructure failure line %d: %s (errno=%d)\n", \
                 __LINE__, #expr, errno); \
    std::exit(2); \
} } while (0)

static void knob(const char *name, const char *value)
{
    REQUIRE(value ? setenv(name, value, 1) == 0 : unsetenv(name) == 0);
}

static void out_fence(int fd)
{
    char value[32];
    std::snprintf(value, sizeof(value), "%d", fd);
    knob("FAKE_RGA_OUT_FENCE", value);
}

static bool is_open(int fd)
{
    int ret = fcntl(fd, F_GETFD);
    REQUIRE(ret >= 0 || errno == EBADF);
    return ret >= 0;
}

static int census()
{
    DIR *dir = opendir("/proc/self/fd");
    REQUIRE(dir != nullptr);
    int count = 0;
    errno = 0;
    while (dirent *entry = readdir(dir)) {
        if (entry->d_name[0] != '.') ++count;
    }
    REQUIRE(errno == 0);
    REQUIRE(closedir(dir) == 0);
    return count - 1; // Exclude the census directory's own transient fd.
}

static int fence()
{
    int fd = eventfd(1, EFD_CLOEXEC | EFD_NONBLOCK);
    REQUIRE(fd > 0);
    return fd;
}

static int buffer()
{
    int fd = memfd_create("h6-buffer", MFD_CLOEXEC);
    REQUIRE(fd > 0 && ftruncate(fd, 64 * 64 * 4) == 0);
    return fd;
}

static int legacy(int src_fd, int dst_fd, int acquire)
{
    rga_info_t src = {}, dst = {};
    src.fd = src_fd;
    dst.fd = dst_fd;
    src.mmuFlag = dst.mmuFlag = 1;
    dst.sync_mode = RGA_BLIT_ASYNC;
    dst.in_fence_fd = acquire;
    dst.out_fence_fd = -99;
    rga_set_rect(&src.rect, 0, 0, 64, 64, 64, 64, RK_FORMAT_RGBA_8888);
    rga_set_rect(&dst.rect, 0, 0, 64, 64, 64, 64, RK_FORMAT_RGBA_8888);
    int ret = c_RkRgaBlit(&src, &dst, nullptr);
    REQUIRE(ret == 0 && dst.out_fence_fd == -1);
    return ret;
}

static IM_STATUS process(int src_fd, int dst_fd, int *release, int usage)
{
    rga_buffer_t src = wrapbuffer_fd(src_fd, 64, 64, RK_FORMAT_RGBA_8888);
    rga_buffer_t dst = wrapbuffer_fd(dst_fd, 64, 64, RK_FORMAT_RGBA_8888);
    return improcess(src, dst, {}, {}, {}, {}, -1, release, nullptr, usage);
}

static void row(FILE *file, const char *name, int iteration, int status,
                int fd, bool open_after, int before, int after,
                int release, const char *verdict)
{
    REQUIRE(std::fprintf(file, "%s,%d,%d,%d,%d,%d,%d,%d,%s\n", name, iteration,
                         status, fd, open_after, before, after, release, verdict) > 0);
}

static void summary(FILE *file, const char *name, int red)
{
    const char *verdict = red ? "RED" : "NOT-REPRODUCED";
    REQUIRE(std::fprintf(file, "%s,%d,%d,%s\n", name, iterations, red, verdict) > 0);
    std::printf("%s: %s (%d/%d defect observations)\n", name, verdict, red, iterations);
}

static int check_sync_error(FILE *details, FILE *cases)
{
    int baseline = census();
    int c4_red = 0;
    for (int i = 1; i <= iterations; ++i) {
        int control = fence();
        int before = census();
        IM_STATUS status = imsync(control);
        int after = census();
        REQUIRE(status == IM_STATUS_SUCCESS && !is_open(control) && after == before - 1);
        row(details, "C4-control-success", i, status, control, false, before, after, -1, "PASS");

        int fd = fence();
        before = census();
        knob("FAKE_RGA_SYNC_FAIL", "1");
        status = imsync(fd);
        knob("FAKE_RGA_SYNC_FAIL", nullptr);
        REQUIRE(status == IM_STATUS_FAILED);
        bool leaked = is_open(fd);
        after = census();
        REQUIRE(after == before - (leaked ? 0 : 1));
        c4_red += leaked;
        row(details, "C4", i, status, fd, leaked, before, after, -1,
            leaked ? "RED" : "NOT-REPRODUCED");
        if (leaked) REQUIRE(close(fd) == 0);
        REQUIRE(census() == baseline);
    }
    summary(cases, "C4", c4_red);
    return c4_red;
}

int main(int argc, char **argv)
{
    REQUIRE(dlsym(RTLD_DEFAULT, "fake_rga_active") != nullptr);
    REQUIRE(argc == 1 || (argc == 2 && !std::strcmp(argv[1], "sync-only")));
    // H6a is WITHDRAWN: no real positive-success submit path exists on the island.
    // Do not let an inherited return override manufacture that withdrawn case.
    for (char **entry = environ; *entry; ++entry)
        REQUIRE(std::strncmp(*entry, "FAKE_RGA_RET_", 13) != 0);
    knob("FAKE_RGA_FAIL", nullptr);
    knob("FAKE_RGA_SYNC_FAIL", nullptr);
    knob("FAKE_RGA_ERRNO", "5");
    if (argc == 2) return check_sync_error(stdout, stdout) ? 1 : 0;
    out_fence(-1);
    REQUIRE(is_open(STDIN_FILENO));
    int saved_stdin = dup(STDIN_FILENO);
    REQUIRE(saved_stdin > 0);
    int src = buffer(), dst = buffer();
    // Warm both independently lazy contexts before any census or closing stdin.
    legacy(src, dst, -1);
    int release = -1;
    REQUIRE(process(src, dst, &release, IM_ASYNC) == IM_STATUS_SUCCESS && release == -1);
    FILE *details = std::fopen("test-results/h6/iterations.csv", "w");
    FILE *cases = std::fopen("test-results/h6/cases.csv", "w");
    REQUIRE(details != nullptr && cases != nullptr);
    REQUIRE(std::fprintf(details, "case,iteration,status,fd,open_after,fd_before,fd_after,out_fence,verdict\n") > 0);
    REQUIRE(std::fprintf(cases, "case,iterations,defects,verdict\n") > 0);
    int baseline = census();
    int c2_red = 0, c3_red = 0, c4_red = 0;

    for (int i = 1; i <= iterations; ++i) {
        int before = census();
        int status = legacy(src, dst, -1);
        int after = census();
        REQUIRE(after == before);
        row(details, "C2-control-minus1", i, status, -1, false, before, after, -1, "PASS");

        int positive = fence();
        before = census();
        status = legacy(src, dst, positive);
        after = census();
        REQUIRE(!is_open(positive) && after == before - 1);
        row(details, "C2-control-positive", i, status, positive, false, before, after, -1, "PASS");

        int donor = fence();
        REQUIRE(close(STDIN_FILENO) == 0);
        REQUIRE(dup(donor) == STDIN_FILENO);
        REQUIRE(close(donor) == 0 && is_open(STDIN_FILENO));
        before = census();
        status = legacy(src, dst, STDIN_FILENO);
        bool leaked = is_open(STDIN_FILENO);
        after = census();
        REQUIRE(after == before - (leaked ? 0 : 1));
        c2_red += leaked;
        row(details, "C2", i, status, 0, leaked, before, after, -1, leaked ? "RED" : "NOT-REPRODUCED");
        if (leaked) REQUIRE(close(STDIN_FILENO) == 0);
        REQUIRE(dup2(saved_stdin, STDIN_FILENO) == STDIN_FILENO);
        REQUIRE(census() == baseline);
    }
    summary(cases, "C2", c2_red);

    for (int i = 1; i <= iterations; ++i) {
        int prior = fence();
        out_fence(prior);
        release = -1;
        knob("FAKE_RGA_FAIL", "RGA_BLIT_SYNC");
        REQUIRE(process(src, dst, &release, IM_SYNC) == IM_STATUS_FAILED);
        // SYNC failure must not affect an ASYNC submit; it seeds a real old output.
        REQUIRE(process(src, dst, &release, IM_ASYNC) == IM_STATUS_SUCCESS && release == prior);
        REQUIRE(imsync(release) == IM_STATUS_SUCCESS && !is_open(prior));
        REQUIRE(census() == baseline);
        out_fence(-1);
        knob("FAKE_RGA_FAIL", "RGA_BLIT_ASYNC");
        int before = census();
        IM_STATUS status = process(src, dst, &release, IM_ASYNC);
        int after = census();
        REQUIRE(status == IM_STATUS_FAILED && before == after);
        REQUIRE(release == -1 || release == prior);
        bool stale = release != -1;
        c3_red += stale;
        row(details, "C3", i, status, prior, is_open(prior), before, after, release,
            stale ? "RED" : "NOT-REPRODUCED");
        knob("FAKE_RGA_FAIL", nullptr);
    }
    summary(cases, "C3", c3_red);

    c4_red = check_sync_error(details, cases);
    REQUIRE(std::fclose(details) == 0 && std::fclose(cases) == 0);
    REQUIRE(close(src) == 0 && close(dst) == 0 && close(saved_stdin) == 0);
    std::puts("H6a: WITHDRAWN (no real positive-success submit path exists on the island)");
    std::puts("Controls: PASS (200 each); per-iteration cleanup restores fd baseline");
    return c2_red || c3_red || c4_red ? 1 : 0;
}
