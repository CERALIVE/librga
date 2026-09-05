/* SPDX-License-Identifier: Apache-2.0 */
/* Modified by CeraLive 2026-09-05: report the QEMU-only invalid-fd ioctl limit. */
/* Modified by CeraLive 2026-09-05: assert fence knobs and poll forwarding. */
#define _GNU_SOURCE
#include <dlfcn.h>
#include <errno.h>
#include <fcntl.h>
#include <poll.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/eventfd.h>
#include <unistd.h>
#include "rga_ioctl.h"
#include "qemu_ioctl_limit.h"

#define CHECK(expr) do { if (!(expr)) { \
    fprintf(stderr, "shim contract line %d: %s (errno %d)\n", __LINE__, #expr, errno); \
    return 1; \
} } while (0)

int main(void)
{
    CHECK(dlsym(RTLD_DEFAULT, "fake_rga_active"));
    int fd = open("/dev/rga", O_RDWR | O_CLOEXEC);
    int second = openat(-1, "/dev/rga", O_RDWR);
    CHECK(fd >= 0 && second >= 0 && fd != second);
    struct stat st;
    CHECK(!fstat(fd, &st) && S_ISREG(st.st_mode));
    CHECK(fcntl(fd, F_GETFD) & FD_CLOEXEC);
    CHECK(!(fcntl(second, F_GETFD) & FD_CLOEXEC));
    struct rga_version_t v = {0};
    struct rga_hw_versions_t hw = {0};
    CHECK(ioctl(fd, RGA_IOC_GET_DRVIER_VERSION, &v) == 1);
    CHECK(v.major == 1 && v.minor == 3 && v.revision == 11 && !strcmp((char *)v.str, "1.3.11"));
    CHECK(ioctl(fd, RGA_IOC_GET_HW_VERSION, &hw) == 1);
    CHECK(hw.size == 3 && hw.version[0].revision == 0x76831 &&
          hw.version[1].revision == 0x76831 && hw.version[2].revision == 0x63318);
    char legacy[RGA_VERSION_SIZE] = {0};
    CHECK(ioctl(second, RGA2_GET_VERSION, legacy) == 1 && !strcmp(legacy, "3.2.63318"));
    struct rga_external_buffer buffers[2] = {0};
    struct rga_buffer_pool pool = {.buffers = (uintptr_t)buffers, .size = 2};
    CHECK(ioctl(fd, RGA_IOC_IMPORT_BUFFER, &pool) == 0);
    CHECK(buffers[0].handle == 1 && buffers[1].handle == 2);
    CHECK(ioctl(fd, RGA_IOC_RELEASE_BUFFER, &pool) == 0);
    uint32_t id = 0, id2 = 0;
    CHECK(ioctl(fd, RGA_IOC_REQUEST_CREATE, &id) == 0 && id == 1);
    CHECK(ioctl(fd, RGA_IOC_REQUEST_CREATE, &id2) == 0 && id2 == 2);
    struct rga_req task = {0};
    struct rga_user_request request = {.task_ptr = (uintptr_t)&task, .task_num = 1,
                                      .id = id, .sync_mode = RGA_BLIT_SYNC};
    CHECK(ioctl(fd, RGA_IOC_REQUEST_CONFIG, &request) == 0);
    CHECK(ioctl(fd, RGA_IOC_REQUEST_SUBMIT, &request) == 0);
    CHECK(ioctl(fd, RGA_IOC_REQUEST_CANCEL, &id2) == 0);
    CHECK(ioctl(fd, RGA_BLIT_SYNC, &task) == 0);
    CHECK(ioctl(fd, RGA_BLIT_ASYNC, &task) == 0);
    CHECK(!setenv("FAKE_RGA_RET_RGA_BLIT_SYNC", "7", 1));
    CHECK(ioctl(fd, RGA_BLIT_SYNC, &task) == 7);
    CHECK(!setenv("FAKE_RGA_FAIL", "RGA_BLIT_SYNC", 1));
    CHECK(!setenv("FAKE_RGA_ERRNO", "22", 1));
    CHECK(ioctl(fd, RGA_BLIT_SYNC, &task) == -1 && errno == EINVAL);
    CHECK(!unsetenv("FAKE_RGA_FAIL"));
    CHECK(!setenv("FAKE_RGA_RET_RGA_BLIT_SYNC", "-1", 1));
    CHECK(ioctl(fd, RGA_BLIT_SYNC, &task) == -1 && errno == EINVAL);
    CHECK(!unsetenv("FAKE_RGA_RET_RGA_BLIT_SYNC"));
    CHECK(!setenv("FAKE_RGA_RET_RGA_IOC_GET_DRVIER_VERSION", "0", 1));
    CHECK(ioctl(fd, RGA_IOC_GET_DRVIER_VERSION, &v) == 0 && v.revision == 11);
    CHECK(!unsetenv("FAKE_RGA_RET_RGA_IOC_GET_DRVIER_VERSION"));
    const char *fences[] = {"-1", "0", "42"};
    for (size_t i = 0; i < sizeof(fences) / sizeof(fences[0]); ++i) {
        int wanted_fence = atoi(fences[i]);
        CHECK(!setenv("FAKE_RGA_OUT_FENCE", fences[i], 1));
        CHECK(ioctl(fd, RGA_BLIT_SYNC, &task) == 0 && task.out_fence_fd == wanted_fence);
        CHECK(ioctl(fd, RGA_BLIT_ASYNC, &task) == 0 && task.out_fence_fd == wanted_fence);
        CHECK(ioctl(fd, RGA_IOC_REQUEST_SUBMIT, &request) == 0 &&
              request.release_fence_fd == (uint32_t)wanted_fence);
        CHECK(ioctl(fd, RGA_IOC_REQUEST_CONFIG, &request) == 0 &&
              request.release_fence_fd == (uint32_t)wanted_fence);
    }
    CHECK(!setenv("FAKE_RGA_FAIL", "RGA_BLIT_ASYNC", 1));
    task.out_fence_fd = 99;
    CHECK(ioctl(fd, RGA_BLIT_ASYNC, &task) == -1 && errno == EINVAL && task.out_fence_fd == 99);
    CHECK(!unsetenv("FAKE_RGA_FAIL") && !unsetenv("FAKE_RGA_OUT_FENCE"));
    CHECK(ioctl(fd, RGA_BLIT_ASYNC, &task) == 0 && task.out_fence_fd == -1);
    CHECK(ioctl(fd, RGA_IOC_REQUEST_CONFIG, &request) == 0 && request.release_fence_fd == (uint32_t)-1);

    int fence_fd = eventfd(1, EFD_CLOEXEC | EFD_NONBLOCK);
    CHECK(fence_fd >= 0);
    struct pollfd wait_fd = {.fd = fence_fd, .events = POLLIN};
    CHECK(poll(&wait_fd, 1, -1) == 1 && (wait_fd.revents & POLLIN));
    CHECK(!setenv("FAKE_RGA_SYNC_FAIL", "1", 1));
    CHECK(poll(&wait_fd, 1, -1) == -1 && errno == EIO);
    CHECK(fcntl(fence_fd, F_GETFD) >= 0);
    CHECK(poll(&wait_fd, 1, 0) == 1 && (wait_fd.revents & POLLIN));
    CHECK(poll(NULL, 0, 0) == 0);
    CHECK(!setenv("FAKE_RGA_SYNC_FAIL", "0", 1));
    CHECK(poll(&wait_fd, 1, -1) == 1 && (wait_fd.revents & POLLIN));
    CHECK(!unsetenv("FAKE_RGA_SYNC_FAIL") && !close(fence_fd));
    char dump_path[] = "shim-bytes-XXXXXX";
    int dump_fd = mkstemp(dump_path);
    CHECK(dump_fd >= 0 && !setenv("FAKE_RGA_DUMP", dump_path, 1));
    struct rga_req original = task;
    struct rga_user_request original_request = request;
    CHECK(ioctl(fd, RGA_IOC_REQUEST_CONFIG, &request) == 0);
    CHECK(ioctl(fd, RGA_BLIT_SYNC, &task) == 0);
    unsigned char captured[sizeof(request) + 2 * sizeof(task)], wanted[sizeof(captured)];
    memcpy(wanted, &original_request, sizeof(request));
    memcpy(wanted + sizeof(request), &original, sizeof(task));
    memcpy(wanted + sizeof(request) + sizeof(task), &original, sizeof(task));
    CHECK(read(dump_fd, captured, sizeof(captured)) == (ssize_t)sizeof(captured));
    CHECK(!memcmp(captured, wanted, sizeof(captured)));
    CHECK(read(dump_fd, captured, 1) == 0);
    CHECK(!unsetenv("FAKE_RGA_DUMP") && !close(dump_fd) && !unlink(dump_path));
    CHECK(ioctl(fd, 0xdeadUL, NULL) == -1 && errno == ENOTTY);
    CHECK(!close(second));
    CHECK(fcntl(second, F_GETFD) == -1 && errno == EBADF);
    int skipped = qemu_ioctl_limit(RGA_IOC_GET_HW_VERSION);
    if (skipped)
        puts("SKIP: closed-fd RGA errno assertion under QEMU user-mode (raw ioctl returns ENOTTY before fd validation)");
    else
        CHECK(ioctl(second, RGA_IOC_GET_HW_VERSION, &hw) == -1 && errno == EBADF);
    int dir = open(".", O_RDONLY | O_DIRECTORY);
    CHECK(dir >= 0);
    int plain = openat(dir, "forwarded", O_RDWR | O_CREAT | O_EXCL, 0600);
    CHECK(plain >= 0 && !fstat(plain, &st) && (st.st_mode & 0777) == 0600);
    CHECK(ioctl(plain, RGA_IOC_GET_HW_VERSION, &hw) == -1 && errno == ENOTTY);
    CHECK(!close(plain) && !unlinkat(dir, "forwarded", 0) && !close(dir));
    CHECK(!close(fd));
    CHECK(getenv("PATH") != NULL);
    puts(skipped ? "shim contract: remaining assertions PASS; closed-fd RGA errno SKIPPED"
                 : "shim contract: PASS (forwarding, close, per-ioctl returns, faults, verbatim request + task capture)");
    return skipped ? 77 : 0;
}
