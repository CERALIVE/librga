/* SPDX-License-Identifier: Apache-2.0 */
/* Modified by CeraLive 2026-09-12: exercise the exported init below the singleton lock. */
/*
 * H1: concurrent-init reproducer for the legacy session bring-up path.
 *
 * WHAT IS UNDER TEST
 *
 * `NormalRgaOpen()` (core/NormalRga.cpp:66) tests the process-global
 * `rgaCtx` OUTSIDE any lock:
 *
 *     if (!rgaCtx) { ... open("/dev/rga") ... rgaCtx = ctx; }
 *     pthread_mutex_lock(&mMutex); refCount++; pthread_mutex_unlock(&mMutex);
 *
 * Only the counter bump is serialised. The malloc, the device open, the two
 * version ioctls and the `rgaCtx` store all sit in the unguarded arm, so N
 * threads that arrive together can each observe a null `rgaCtx`, each open the
 * device, and each overwrite the store. `NormalRgaClose()`
 * (core/NormalRga.cpp:158) then closes exactly ONE fd when the count reaches
 * zero, because it only ever sees the last writer's context.
 *
 * This client makes that arrival simultaneous on purpose and then measures
 * three things a race would move:
 *
 *   - `refCount` and `rgaCtx`, read straight out of the library (both are
 *     unmangled global symbols in `librga.so`, confirmed with `nm -D`),
 *   - how many descriptors in `/proc/self/fd` point at the shim's mock device,
 *   - whether any such descriptor survives a full teardown.
 *
 * TWO SCENARIOS, AND WHY BOTH
 *
 *   c-init          8 threads call `c_RkRgaInit()`.
 *   singleton-get   8 threads call `RockchipRga::get()`, which reaches
 *                   `RgaInit()` through the singleton constructor.
 *
 * They are not two spellings of the same thing, and the difference is the
 * point of running both. See the notes on each `run_*` function below.
 *
 * HOST ONLY. `/dev/rga` here is `tests/shim/fake_rga.c`, which answers an open
 * with a `memfd_create("fake-rga", ...)`. Nothing in this file touches silicon,
 * and no sanitizer result it produces may be cited as board evidence.
 */

/*
 * Order matters. NormalRga.h declares the REAL `RgaInit`/`RgaDeInit`
 * functions; RgaApi.h then redefines both names as macros that forward to the
 * do-nothing C shims. Include the header with the declarations first, then
 * drop the macros, so the teardown below calls the function that actually
 * decrements the reference count instead of the empty `c_RkRgaDeInit()`.
 */
#include "NormalRga.h"
#include "RgaApi.h"
#undef RgaInit
#undef RgaDeInit

#include "RockchipRga.h"

#include <dirent.h>
#include <dlfcn.h>
#include <unistd.h>

#include <atomic>
#include <cstdint>
#include <cstdio>
#include <cstring>
#include <string>
#include <thread>
#include <vector>

#if defined(__has_include)
#  if __has_include(<barrier>)
#    include <barrier>
#  endif
#endif
#if __cplusplus >= 202002L && defined(__cpp_lib_barrier) && !defined(__clang__)
#  define H1_HAVE_STD_BARRIER 1
#endif

/*
 * The library's own globals. Both are plain namespace-scope objects in
 * NormalRga.cpp, so they carry unmangled names and can be read directly.
 * Reading them is the only way to see a duplicate increment that a later
 * successful teardown would otherwise hide.
 */
extern volatile int32_t refCount;
extern struct rgaContext *rgaCtx;

static const int THREADS = 8;

/* Cap the teardown loop so a stuck count reports rather than spins forever. */
static const int MAX_DEINIT = 64;

/*
 * A release gate for all eight threads. std::barrier where the toolchain has
 * it; otherwise an atomic counter plus a spin, which is what the fallback in
 * the task brief asks for. The spin is deliberate: sleeping would let the
 * scheduler stagger exactly the arrival this test needs bunched.
 */
class StartGate {
  public:
    explicit StartGate(int expected)
#if defined(H1_HAVE_STD_BARRIER)
        : gate_(expected)
#else
        : expected_(expected), arrived_(0)
#endif
    {
#if !defined(H1_HAVE_STD_BARRIER)
        (void)expected_;
#endif
    }

    void arrive_and_wait() {
#if defined(H1_HAVE_STD_BARRIER)
        gate_.arrive_and_wait();
#else
        arrived_.fetch_add(1, std::memory_order_acq_rel);
        while (arrived_.load(std::memory_order_acquire) < expected_)
            std::this_thread::yield();
#endif
    }

    static const char *kind() {
#if defined(H1_HAVE_STD_BARRIER)
        return "std::barrier";
#else
        return "atomic-spin";
#endif
    }

  private:
#if defined(H1_HAVE_STD_BARRIER)
    std::barrier<> gate_;
#else
    const int expected_;
    std::atomic<int> arrived_;
#endif
};

/*
 * Count descriptors that resolve to the shim's mock device. memfd links read
 * back as "/memfd:fake-rga (deleted)", so match on the name the shim passes to
 * memfd_create rather than on "/dev/rga", which never appears in /proc at all.
 *
 * Returns -1 only if /proc/self/fd cannot be opened; a legitimate zero is a
 * finding, not an error.
 */
static int count_device_fds()
{
    DIR *dir = opendir("/proc/self/fd");
    if (!dir)
        return -1;

    int count = 0;
    for (struct dirent *entry = readdir(dir); entry; entry = readdir(dir)) {
        if (entry->d_name[0] == '.')
            continue;
        std::string path = std::string("/proc/self/fd/") + entry->d_name;
        char target[512];
        ssize_t length = readlink(path.c_str(), target, sizeof(target) - 1);
        if (length < 0)
            continue;   /* the readdir fd itself races closed; not a device */
        target[length] = '\0';
        if (strstr(target, "memfd:fake-rga"))
            ++count;
    }
    closedir(dir);
    return count;
}

struct Result {
    int ok = 0;             /* threads whose call reported success */
    int fds_after_init = -1;
    int refcount_after_init = -1;
    int deinit_calls = 0;
    int last_deinit_ret = 0;
    int refcount_after_teardown = -1;
    int fds_after_teardown = -1;
    const void *ctx = nullptr;
    bool ctx_agreed = true; /* every thread saw the same singleton/context */
};

/*
 * Bring `refCount` back to zero through the real NormalRgaClose path.
 *
 * The saved pointer is restored before every call because a successful close
 * nulls the caller's handle, and a duplicate increment needs more than one
 * close to drain. Passing a null handle back in would return -ENODEV and
 * report a leak that is really just a lost handle.
 */
static void teardown(Result &result, void *saved)
{
    while (refCount > 0 && result.deinit_calls < MAX_DEINIT) {
        void *ctx = saved;
        result.last_deinit_ret = RgaDeInit(&ctx);
        ++result.deinit_calls;
    }
    result.refcount_after_teardown = refCount;
    result.fds_after_teardown = count_device_fds();
}

/*
 * Scenario 1: eight threads on `c_RkRgaInit()`.
 *
 * Read core/RgaApi.cpp:27 before reading this scenario's numbers. In this tree
 * `c_RkRgaInit()` is `return 0;` and nothing else — the C compatibility shim
 * was hollowed out when init moved into the singleton, and RgaApi.h says so in
 * its own comment. So this scenario is a CONTROL, not a race: it establishes
 * that the entry point the task named opens no device and touches no reference
 * count, which is what makes the second scenario's numbers attributable.
 *
 * The context is deliberately NOT fetched here. `c_RkRgaGetContext()` would
 * construct the singleton and manufacture exactly the init this scenario is
 * supposed to show does not happen.
 */
static Result run_c_init(void)
{
    Result result;
    StartGate gate(THREADS);
    std::atomic<int> ok(0);

    std::vector<std::thread> threads;
    threads.reserve(THREADS);
    for (int i = 0; i < THREADS; ++i) {
        threads.emplace_back([&gate, &ok]() {
            gate.arrive_and_wait();
            if (c_RkRgaInit() == 0)
                ok.fetch_add(1, std::memory_order_relaxed);
        });
    }
    for (std::thread &thread : threads)
        thread.join();

    result.ok = ok.load(std::memory_order_relaxed);
    result.fds_after_init = count_device_fds();
    result.refcount_after_init = refCount;
    result.ctx = rgaCtx;

    /*
     * Nothing was opened, so there is nothing to drain; call once anyway with a
     * null handle and record what the library says. That return value is the
     * evidence the scenario left no session behind.
     */
    void *ctx = nullptr;
    result.last_deinit_ret = RgaDeInit(&ctx);
    result.deinit_calls = 1;
    result.refcount_after_teardown = refCount;
    result.fds_after_teardown = count_device_fds();
    return result;
}

/*
 * Scenario 2: eight threads on `RockchipRga::get()`.
 *
 * This is the one that reaches `NormalRgaOpen()`. Note what stands between the
 * threads and the unguarded `if (!rgaCtx)`: `Singleton::getInstance()`
 * (include/RgaSingleton.h:33) takes `sLock` for the whole null-check-and-
 * construct, so the construction that calls `RgaInit()` is serialised by the
 * SINGLETON's lock, not by anything in NormalRga.cpp. Whether that incidental
 * serialisation is enough to hide the unguarded check is precisely the
 * question, so the numbers below are reported as observed and are not asserted
 * either way.
 */
static Result run_singleton_get(void)
{
    Result result;
    StartGate gate(THREADS);
    std::atomic<int> ok(0);
    std::atomic<const void *> seen(nullptr);
    std::atomic<bool> disagreed(false);

    std::vector<std::thread> threads;
    threads.reserve(THREADS);
    for (int i = 0; i < THREADS; ++i) {
        threads.emplace_back([&gate, &ok, &seen, &disagreed]() {
            gate.arrive_and_wait();
            RockchipRga &rga = RockchipRga::get();
            const void *instance = static_cast<const void *>(&rga);
            const void *expected = nullptr;
            if (!seen.compare_exchange_strong(expected, instance)) {
                if (expected != instance)
                    disagreed.store(true, std::memory_order_relaxed);
            }
            ok.fetch_add(1, std::memory_order_relaxed);
        });
    }
    for (std::thread &thread : threads)
        thread.join();

    result.ok = ok.load(std::memory_order_relaxed);
    result.ctx_agreed = !disagreed.load(std::memory_order_relaxed);
    result.fds_after_init = count_device_fds();
    result.refcount_after_init = refCount;

    void *ctx = nullptr;
    RockchipRga::get().RkRgaGetContext(&ctx);
    result.ctx = ctx;
    teardown(result, ctx);
    return result;
}

static void print(const char *scenario, const Result &result)
{
    printf("scenario=%s gate=%s threads=%d ok=%d ctx=%p ctx_agreed=%d "
           "refcount_after_init=%d fds_after_init=%d "
           "deinit_calls=%d last_deinit_ret=%d "
           "refcount_after_teardown=%d fds_after_teardown=%d\n",
           scenario, StartGate::kind(), THREADS, result.ok, result.ctx,
           result.ctx_agreed ? 1 : 0,
           result.refcount_after_init, result.fds_after_init,
           result.deinit_calls, result.last_deinit_ret,
           result.refcount_after_teardown, result.fds_after_teardown);
    fflush(stdout);
}

static Result run_direct_init(void)
{
    Result result;
    StartGate gate(THREADS);
    void *contexts[THREADS] = {};
    int statuses[THREADS] = {};
    std::vector<std::thread> threads;
    for (int i = 0; i < THREADS; ++i) {
        threads.emplace_back([&, i]() {
            gate.arrive_and_wait();
            statuses[i] = RgaInit(&contexts[i]);
        });
    }
    for (std::thread &thread : threads)
        thread.join();
    for (int i = 0; i < THREADS; ++i) {
        if (statuses[i] >= 0 && contexts[i]) ++result.ok;
        if (contexts[i] != contexts[0]) result.ctx_agreed = false;
    }
    result.ctx = rgaCtx;
    result.refcount_after_init = refCount;
    result.fds_after_init = count_device_fds();
    teardown(result, rgaCtx);
    return result;
}

int main(int argc, char **argv)
{
    if (argc != 2) {
        fprintf(stderr, "usage: h1_init_race {c-init|singleton-get|direct-init}\n");
        return 2;
    }

    /*
     * Refuse to run bare. Without the preload this would try the real
     * /dev/rga, and on a host that fails open in a way that looks exactly like
     * "no leak" — a false clean result is worse than no result.
     */
    if (!dlsym(RTLD_DEFAULT, "fake_rga_active")) {
        fprintf(stderr, "h1: shim not preloaded; refusing to run\n");
        return 2;
    }

    if (!strcmp(argv[1], "c-init")) {
        print("c-init", run_c_init());
        return 0;
    }
    if (!strcmp(argv[1], "singleton-get")) {
        print("singleton-get", run_singleton_get());
        return 0;
    }
    if (!strcmp(argv[1], "direct-init")) {
        Result result = run_direct_init();
        print("direct-init", result);
        return result.ok != THREADS || !result.ctx_agreed ||
            result.refcount_after_init != THREADS || result.fds_after_init != 1 ||
            result.refcount_after_teardown != 0 || result.fds_after_teardown != 0;
    }

    fprintf(stderr, "h1: unknown scenario '%s'\n", argv[1]);
    return 2;
}
