// SPDX-License-Identifier: Apache-2.0
#include <atomic>
#include <chrono>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <dlfcn.h>
#include <thread>

#include "NormalRga.h"
#include "RgaApi.h"

// RgaApi.h's compatibility macro calls the empty c_RkRgaDeInit(). H2 needs
// the real RgaDeInit(void **) declared by NormalRga.h, not that no-op.
#undef RgaDeInit

static int make_buffer()
{
    const int fd = memfd_create("h2-buffer", MFD_CLOEXEC);
    if (fd < 0) return -1;
    if (ftruncate(fd, 64 * 64 * 4) != 0) {
        close(fd);
        return -1;
    }
    return fd;
}

int main(int argc, char **argv)
{
    if (argc != 2 || (std::strcmp(argv[1], "deinit") != 0 &&
                      std::strcmp(argv[1], "exit") != 0)) {
        std::fprintf(stderr, "usage: %s {deinit|exit}\n", argv[0]);
        return 2;
    }
    if (dlsym(RTLD_DEFAULT, "fake_rga_active") == nullptr) {
        std::fprintf(stderr, "H2 refusing hardware access: fake_rga preload is absent\n");
        return 2;
    }

    rga_info_t src = {}, dst = {};
    src.fd = make_buffer();
    dst.fd = make_buffer();
    if (src.fd < 0 || dst.fd < 0) {
        std::perror("H2 buffer setup");
        if (src.fd >= 0) close(src.fd);
        if (dst.fd >= 0) close(dst.fd);
        return 2;
    }
    src.mmuFlag = dst.mmuFlag = 1;
    src.in_fence_fd = dst.in_fence_fd = -1;
    rga_set_rect(&src.rect, 0, 0, 64, 64, 64, 64, RK_FORMAT_RGBA_8888);
    rga_set_rect(&dst.rect, 0, 0, 64, 64, 64, 64, RK_FORMAT_RGBA_8888);

    // Borrow the singleton's only context reference. RgaInit here would add
    // another reference, preventing the one RgaDeInit below from freeing it.
    void *context = nullptr;
    c_RkRgaGetContext(&context);
    if (context == nullptr || c_RkRgaBlit(&src, &dst, nullptr) != 0) {
        std::fprintf(stderr, "H2 setup failed before concurrent work\n");
        close(src.fd);
        close(dst.fd);
        return 2;
    }
    const int device_fd = static_cast<rgaContext *>(context)->rgaFd;
    const bool exit_scenario = std::strcmp(argv[1], "exit") == 0;
    std::atomic<bool> stop{false}, teardown_started{false};
    std::atomic<unsigned long> successful{0}, rejected{0};
    std::atomic<int> blit_error{0};
    int deinit_result = -1;

    std::thread thread_a([&, src, dst]() mutable {
        while (!stop.load(std::memory_order_relaxed)) {
            const int result = c_RkRgaBlit(&src, &dst, nullptr);
            if (result == 0) {
                successful.fetch_add(1, std::memory_order_relaxed);
            } else if (!exit_scenario && teardown_started.load(std::memory_order_relaxed) &&
                       (result == -ENODEV || result == -EBADF)) {
                rejected.fetch_add(1, std::memory_order_relaxed);
            } else {
                blit_error.store(result, std::memory_order_relaxed);
                stop.store(true, std::memory_order_relaxed);
            }
        }
    });

    std::thread thread_b([&] {
        const auto deadline = std::chrono::steady_clock::now() + std::chrono::seconds(2);
        while (successful.load(std::memory_order_relaxed) < 32) {
            if (stop.load(std::memory_order_relaxed) ||
                std::chrono::steady_clock::now() >= deadline) {
                stop.store(true, std::memory_order_relaxed);
                return;
            }
            std::this_thread::yield();
        }
        std::this_thread::sleep_for(std::chrono::milliseconds(1));
        if (stop.load(std::memory_order_relaxed)) return;
        teardown_started.store(true, std::memory_order_relaxed);
        std::fprintf(stderr, "H2 action=%s successful_blits=%lu\n", argv[1],
                     successful.load(std::memory_order_relaxed));
        if (exit_scenario) {
            // Do not delete the singleton or join A: exercise only the real
            // exit-time callbacks while A continues submitting work.
            std::exit(0);
        }
        deinit_result = RgaDeInit(&context);
        stop.store(true, std::memory_order_relaxed);
    });

    thread_b.join();
    thread_a.join();
    const bool device_closed = fcntl(device_fd, F_GETFD) == -1 && errno == EBADF;
    close(src.fd);
    close(dst.fd);
    if (exit_scenario || !teardown_started.load() || deinit_result != 0 ||
        context != nullptr || !device_closed || blit_error.load() != 0) {
        std::fprintf(stderr, "H2 incomplete: deinit=%d null_context=%d closed_fd=%d blit_error=%d\n",
                     deinit_result, context == nullptr, device_closed, blit_error.load());
        return 2;
    }
    std::fprintf(stderr, "H2 complete=deinit successful_blits=%lu teardown_rejections=%lu\n",
                 successful.load(), rejected.load());
    return 0;
}
