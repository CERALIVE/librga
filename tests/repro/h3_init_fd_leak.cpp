/* SPDX-License-Identifier: Apache-2.0 */
#include <cerrno>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <dirent.h>
#include <dlfcn.h>
#include <sys/mman.h>
#include <sys/resource.h>
#include <unistd.h>

#include "RgaApi.h"
#include "im2d.hpp"

static const int iterations = 1000;

static void fail(const char *message)
{
    std::fprintf(stderr, "H3 ERROR: %s (errno=%d)\n", message, errno);
    std::exit(2);
}

static int device_count()
{
    DIR *directory = opendir("/proc/self/fd");
    if (!directory) fail("opendir /proc/self/fd");
    int count = 0;
    for (;;) {
        errno = 0;
        dirent *entry = readdir(directory);
        if (!entry) {
            if (errno) fail("readdir");
            break;
        }
        if (entry->d_name[0] == '.') continue;
        char target[256];
        ssize_t length = readlinkat(dirfd(directory), entry->d_name,
                                    target, sizeof(target) - 1);
        if (length < 0 || length == static_cast<ssize_t>(sizeof(target) - 1))
            fail("readlinkat");
        target[length] = '\0';
        if (!std::strcmp(target, "/memfd:fake-rga (deleted)")) ++count;
        if (!std::strcmp(target, "/dev/rga")) fail("real device fd is forbidden");
    }
    if (closedir(directory)) fail("closedir");
    return count;
}

static int image_fd(const char *name)
{
    int fd = memfd_create(name, MFD_CLOEXEC);
    if (fd < 0 || ftruncate(fd, 64 * 64 * 4)) fail("image memfd");
    return fd;
}

int main(int argc, char **argv)
{
    if (argc != 3 || (std::strcmp(argv[1], "c_RkRgaInit") &&
                      std::strcmp(argv[1], "improcess"))) {
        std::fprintf(stderr, "usage: %s c_RkRgaInit|improcess CSV\n", argv[0]);
        return 2;
    }
    if (!dlsym(RTLD_DEFAULT, "fake_rga_active")) fail("host shim not preloaded");
    const char *knob = std::getenv("FAKE_RGA_FAIL");
    const bool control = !knob;
    if (control) knob = "unset";
    else if (std::strcmp(knob, "hwversion") && std::strcmp(knob, "driverversion") &&
             std::strcmp(knob, "getinfo")) fail("unknown failure knob");

    rlimit limit;
    if (getrlimit(RLIMIT_NOFILE, &limit) || limit.rlim_cur < iterations + 32)
        fail("RLIMIT_NOFILE must be at least 1032; do not measure fd exhaustion");
    if (device_count() != 0) fail("case must start without a device/session fd");

    const bool legacy = !std::strcmp(argv[1], "c_RkRgaInit");
    int src_fd = -1, dst_fd = -1;
    rga_buffer_t src = {}, dst = {}, pat = {};
    const im_rect rect = {};
    if (!legacy) {
        src_fd = image_fd("h3-src");
        dst_fd = image_fd("h3-dst");
        src = wrapbuffer_fd(src_fd, 64, 64, RK_FORMAT_RGBA_8888);
        dst = wrapbuffer_fd(dst_fd, 64, 64, RK_FORMAT_RGBA_8888);
    }
    auto invoke = [&]() -> int {
        // On R1 the requested legacy entry point really is a no-op. Do not
        // substitute NormalRgaOpen and then attribute its result to this API.
        return legacy ? c_RkRgaInit() :
            static_cast<int>(improcess(src, dst, pat, rect, rect, rect, IM_SYNC));
    };
    const int success = legacy ? 0 : IM_STATUS_SUCCESS;
    // Only the unset control is warmed up: its one live session is not a leak.
    // Failure cases retain the first call and never reset or close library fds.
    if (control && invoke() != success) fail("unset control warmup failed");
    const int baseline = device_count();
    FILE *csv = std::fopen(argv[2], "a");
    if (!csv) fail("open census CSV");
    int growing = 0, failures = 0, previous = baseline;
    for (int iteration = 1; iteration <= iterations; ++iteration) {
        int before = device_count();
        if (before != previous) fail("fd count changed outside API call");
        errno = 0;
        int status = invoke();
        int error = errno;
        int after = device_count();
        int delta = after - before;
        if (delta < 0) fail("unexpected fd removal");
        if (delta > 0) ++growing;
        if (status != success) ++failures;
        if (std::fprintf(csv, "%s,%s,%d,%d,%d,%d,%d,%d,%d\n", knob, argv[1],
                         iteration, status, error, before, after, delta,
                         after - baseline) < 0) fail("write census CSV");
        previous = after;
    }
    if (std::fclose(csv)) fail("close census CSV");
    if (src_fd >= 0 && close(src_fd)) fail("close source image");
    if (dst_fd >= 0 && close(dst_fd)) fail("close destination image");
    if (control && (growing || failures)) fail("unset control was not flat/successful");
    // One retained session (including a partially initialized getinfo session)
    // is reported, but does not meet the repeated-open leak criterion.
    if (growing > 1 && growing != iterations) fail("partial growth; inspect census, not a flat verdict");
    bool red = growing == iterations && failures == iterations;
    if (growing == iterations && !red) fail("growth without repeated init failure");
    std::printf("%s,%s,iterations=%d,failed_calls=%d,start=%d,end=%d,growing_rows=%d,verdict=%s\n",
                knob, argv[1], iterations, failures, baseline, previous, growing,
                red ? "RED" : "NOT-REPRODUCED");
    return red ? 1 : 0;
}
