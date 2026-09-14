// SPDX-License-Identifier: Apache-2.0
// Modified by CeraLive 2026-09-13: real-device census without changing host reproducers.
#include "NormalRga.h"
#include "RgaApi.h"
#undef RgaInit
#undef RgaDeInit
#include "RockchipRga.h"
#include <dirent.h>
#include <dlfcn.h>
#include <sys/stat.h>
#include <pthread.h>
#include <thread>
#include <vector>

extern volatile int32_t refCount;
extern struct rgaContext *rgaCtx;

static int device_fds()
{
    DIR *dir = opendir("/proc/self/fd");
    if (!dir) return -1;
    int count = 0;
    while (dirent *entry = readdir(dir)) {
        char path[512], target[512];
        snprintf(path, sizeof path, "/proc/self/fd/%s", entry->d_name);
        ssize_t n = readlink(path, target, sizeof target - 1);
        if (n < 0) continue;
        target[n] = 0;
        if (!strcmp(target, "/dev/rga")) ++count;
    }
    closedir(dir);
    return count;
}

int main(int argc, char **argv)
{
    if (argc == 2 && !strcmp(argv[1], "--selftest")) {
        if (device_fds() != 0) return 2;
        puts("PASS: real-device census parser; no RGA device opened");
        return 0;
    }
    if (argc != 3 || (strcmp(argv[1], "c-init") && strcmp(argv[1], "singleton-get") && strcmp(argv[1], "direct-init"))) return 2;
    int n = atoi(argv[2]);
    if (n != 1 && n != 8) return 2;
    struct stat st;
    if (dlsym(RTLD_DEFAULT, "fake_rga_active")) return 2;
    if (stat("/dev/rga", &st) || !S_ISCHR(st.st_mode) || access("/dev/rga", R_OK | W_OK)) {
        perror("real /dev/rga required"); return 77;
    }
    FILE *csv = fdopen(dup(STDOUT_FILENO), "w");
    if (!csv || dup2(STDERR_FILENO, STDOUT_FILENO) < 0) return 2;
    pthread_barrier_t barrier;
    if (pthread_barrier_init(&barrier, nullptr, n)) return 2;
    std::vector<std::thread> threads;
    std::vector<int> results(n, -1);
    std::vector<void *> contexts(n, nullptr);
    for (int i = 0; i < n; ++i) threads.emplace_back([&, i] {
        pthread_barrier_wait(&barrier);
        if (!strcmp(argv[1], "c-init")) results[i] = c_RkRgaInit();
        else if (!strcmp(argv[1], "direct-init")) results[i] = RgaInit(&contexts[i]);
        else {
            RockchipRga::get().RkRgaGetContext(&contexts[i]);
            results[i] = contexts[i] ? 0 : -1;
        }
    });
    for (auto &thread : threads) thread.join();
    pthread_barrier_destroy(&barrier);
    int ok = 0;
    for (int result : results) if (result >= 0) ++ok;
    int before = device_fds(), refs = refCount, closes = 0;
    // Drain the published context, not stale racing handles; count orphan fds afterwards.
    void *saved = rgaCtx;
    while (refCount > 0 && closes < 64) {
        void *ctx = saved;
        if (RgaDeInit(&ctx) < 0) break;
        ++closes;
    }
    int after = device_fds();
    bool invalid = ok != n || before < 0 || after < 0;
    if (strcmp(argv[1], "c-init") && before == 0) invalid = true;
    bool red = before > 1 || after > 0 || refCount != 0;
    fprintf(csv,"%s,%d,%d,%d,%d,%d,%d,%d,%s\n", argv[1], n, ok, before, refs, closes,
           after, (int)refCount, invalid ? "INVALID" : red ? "RED" : "NOT-REPRODUCED");
    fclose(csv);
    return invalid ? 2 : red ? 1 : 0;
}
