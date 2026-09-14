/* SPDX-License-Identifier: Apache-2.0 */
// Modified by CeraLive 2026-09-06: bounded host-only job/handle characterization, not a fix.
#include <cerrno>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <dlfcn.h>
#include <fstream>
#include <string>
#include <thread>
#include <sched.h>
#include <sys/mman.h>
#include <unistd.h>

#include "im2d.h"
#include "im2d_impl.h"
#include "im2d_job.h"

static void require(bool ok, const char *message) {
    if (!ok) {
        std::fprintf(stderr, "HARNESS-ERROR: %s\n", message);
        std::exit(2);
    }
}

struct Snapshot { int count; size_t entries; };

// No getter or count limit exists. Observe the exported internal manager using
// its actual header and mutex; never reset its count or mutate its map.
static Snapshot snapshot() {
    require(pthread_mutex_lock(&g_im2d_job_manager.mutex) == 0, "manager lock");
    Snapshot result{g_im2d_job_manager.job_count, g_im2d_job_manager.job_map.size()};
    require(pthread_mutex_unlock(&g_im2d_job_manager.mutex) == 0, "manager unlock");
    return result;
}

static size_t ioctl_count(const char *name) {
    const char *path = std::getenv("FAKE_RGA_LOG");
    require(path && *path, "FAKE_RGA_LOG must name an isolated interposed.log");
    std::ifstream log(path);
    require(log.good(), "cannot read shim log");
    size_t count = 0;
    std::string line;
    const std::string prefix = std::string("ioctl ") + name + " ";
    while (std::getline(log, line))
        if (line.compare(0, prefix.size(), prefix) == 0) ++count;
    require(log.eof(), "shim log read failed");
    return count;
}

static int count_case() {
    const Snapshot before = snapshot();
    require(before.count == 0 && before.entries == 0, "count case needs fresh process");
    const im_job_handle_t unknown = 0x7fffffff;
    const IM_STATUS cancelled = imcancelJob(unknown);
    const Snapshot after = snapshot();
    im_job_handle_t jobs[64];
    for (im_job_handle_t &job : jobs) {
        job = imbeginJob();
        require(job != 0 && job != unknown, "create after unknown cancel");
    }
    const Snapshot created = snapshot();
    for (im_job_handle_t job : jobs)
        require(imcancelJob(job) == IM_STATUS_SUCCESS, "cancel valid job");
    const Snapshot cleaned = snapshot();
    const bool drift = after.count != before.count || created.count != 64 || cleaned.count != 0;
    std::printf("H10a unknown=%u status=%d before=%d/%zu after=%d/%zu "
                "created=%d/%zu cleaned=%d/%zu count_drift=%s "
                "premature_limit=NOT-REPRODUCED(no-userspace-count-limit)\n",
                unknown, cancelled, before.count, before.entries, after.count, after.entries,
                created.count, created.entries, cleaned.count, cleaned.entries,
                drift ? "RED" : "NOT-REPRODUCED-WITHIN-BUDGET");
    require(after.entries == 0 && created.entries == 64 && cleaned.entries == 0,
            "unexpected map accounting");
    require(ioctl_count("RGA_IOC_REQUEST_CREATE") == 64, "create ioctl control");
    // A corrected library may reject the unknown handle before calling the shim.
    const size_t cancellations = ioctl_count("RGA_IOC_REQUEST_CANCEL");
    require(cancellations == 64 || cancellations == 65, "cancel ioctl control");
    return drift ? 1 : 0;
}

static int release_case() {
    char memory[4096] = {};
    const rga_buffer_handle_t h = importbuffer_virtualaddr(memory, sizeof(memory));
    require(h != 0, "import buffer");
    const size_t before = ioctl_count("RGA_IOC_RELEASE_BUFFER");
    const IM_STATUS first = releasebuffer_handle(h);
    const size_t once = ioctl_count("RGA_IOC_RELEASE_BUFFER");
    const IM_STATUS second = releasebuffer_handle(h);
    const size_t twice = ioctl_count("RGA_IOC_RELEASE_BUFFER");
    require(first == IM_STATUS_SUCCESS && once == before + 1, "first release control");
    const bool duplicate = twice == once + 1;
    require(duplicate || twice == once, "unexpected release ioctl count");
    std::printf("H10c handle=%u first_status=%d second_status=%d "
                "release_ioctls=%zu->%zu->%zu verdict=%s\n", h, first, second,
                before, once, twice, duplicate ? "SECOND-RELEASE-FORWARDED" : "SECOND-RELEASE-NOT-FORWARDED");
    return duplicate ? 1 : 0;
}

struct Buffers {
    int src_fd = -1, dst_fd = -1;
    rga_buffer_t src{}, dst{};

    Buffers() {
        src_fd = memfd_create("h10-source", MFD_CLOEXEC);
        dst_fd = memfd_create("h10-destination", MFD_CLOEXEC);
        require(src_fd >= 0 && dst_fd >= 0, "memfd buffers");
        require(ftruncate(src_fd, 64 * 64 * 4) == 0 &&
                ftruncate(dst_fd, 64 * 64 * 4) == 0, "size buffers");
        src = wrapbuffer_fd(src_fd, 64, 64, RK_FORMAT_RGBA_8888);
        dst = wrapbuffer_fd(dst_fd, 64, 64, RK_FORMAT_RGBA_8888);
    }
    ~Buffers() { close(src_fd); close(dst_fd); }
    im_job_handle_t create() const {
        const im_job_handle_t h = imbeginJob();
        require(h != 0, "create task job");
        require(imcopyTask(h, src, dst) == IM_STATUS_SUCCESS, "queue one actual task");
        return h;
    }
};

static int control_case() {
    Buffers buffers;
    for (int i = 0; i < 200; ++i) {
        const im_job_handle_t submitted = buffers.create();
        require(rga_job_config(submitted, IM_SYNC, -1, nullptr) == IM_STATUS_SUCCESS,
                "serial config");
        require(imendJob(submitted, IM_SYNC, -1, nullptr) == IM_STATUS_SUCCESS, "serial end");
        // Cancel a different live job: cancelling the already-ended job is H10a,
        // not a valid single-owner lifecycle control.
        require(imcancelJob(buffers.create()) == IM_STATUS_SUCCESS, "serial cancel");
        const Snapshot state = snapshot();
        require(state.count == 0 && state.entries == 0, "serial accounting");
    }
    require(ioctl_count("RGA_IOC_REQUEST_CONFIG") == 200, "serial config ioctl control");
    require(ioctl_count("RGA_IOC_REQUEST_SUBMIT") == 200, "serial submit ioctl control");
    require(ioctl_count("RGA_IOC_REQUEST_CANCEL") == 200, "serial cancel ioctl control");
    std::puts("CONTROL PASS: 200 config/end + 200 create/cancel; count=0 map=0");
    return 0;
}

static void rendezvous(pthread_barrier_t *barrier) {
    const int ret = pthread_barrier_wait(barrier);
    require(ret == 0 || ret == PTHREAD_BARRIER_SERIAL_THREAD, "barrier wait");
}

static int race_case(int iterations) {
    require(std::getenv("FAKE_RGA_DUMP") && *std::getenv("FAKE_RGA_DUMP"),
            "race needs request capture to exercise task_ptr reads");
    const Snapshot before = snapshot();
    require(before.count == 0 && before.entries == 0, "race needs fresh process");
    Buffers buffers;
    unsigned config_ok = 0, config_missing = 0, end_ok = 0, end_missing = 0;
    for (int i = 0; i < iterations; ++i) {
        const im_job_handle_t h = buffers.create();
        pthread_barrier_t barrier;
        require(pthread_barrier_init(&barrier, nullptr, 2) == 0, "barrier init");
        IM_STATUS configured = IM_STATUS_FAILED, ended = IM_STATUS_FAILED;
        IM_STATUS cancelled = IM_STATUS_FAILED;
        std::thread a([&] {
            rendezvous(&barrier);
            if (i % 3 == 0) sched_yield();
            configured = rga_job_config(h, IM_SYNC, -1, nullptr);
            ended = imendJob(h, IM_SYNC, -1, nullptr);
        });
        std::thread b([&] {
            rendezvous(&barrier);
            if (i % 3 == 1) sched_yield();
            if (i % 3 == 2) for (int j = 0; j < 8; ++j) sched_yield();
            cancelled = imcancelJob(h);
        });
        a.join();
        b.join();
        if ((i + 1) % 200 == 0)
            std::printf("H10b progress=%d/%d\n", i + 1, iterations);
        require(pthread_barrier_destroy(&barrier) == 0, "barrier destroy");
        require(cancelled == IM_STATUS_SUCCESS, "shim cancel must succeed");
        require(configured == IM_STATUS_SUCCESS || configured == IM_STATUS_ILLEGAL_PARAM,
                "unexpected config status");
        require(ended == IM_STATUS_SUCCESS || ended == IM_STATUS_ILLEGAL_PARAM,
                "unexpected end status");
        require(ended != IM_STATUS_SUCCESS || configured == IM_STATUS_SUCCESS,
                "end succeeded after config found no job");
        config_ok += configured == IM_STATUS_SUCCESS;
        config_missing += configured == IM_STATUS_ILLEGAL_PARAM;
        end_ok += ended == IM_STATUS_SUCCESS;
        end_missing += ended == IM_STATUS_ILLEGAL_PARAM;
        require(snapshot().entries == 0, "race left a live job");
    }
    const Snapshot after = snapshot();
    require(ioctl_count("RGA_IOC_REQUEST_CONFIG") == config_ok, "race config ioctl control");
    require(ioctl_count("RGA_IOC_REQUEST_SUBMIT") == end_ok, "race submit ioctl control");
    std::printf("H10b completed=%d config_success=%u config_missing=%u "
                "end_success=%u end_missing=%u count=%d map=%zu count_drift=%s; "
                "verdict requires sanitizer transcript (completion alone is not GREEN)\n",
                iterations, config_ok, config_missing, end_ok, end_missing,
                after.count, after.entries, after.count != 0 ? "RED" : "NOT-OBSERVED");
    return after.count != 0 ? 1 : 0;
}

int main(int argc, char **argv) {
    require(dlsym(RTLD_DEFAULT, "fake_rga_active") != nullptr,
            "host shim missing; refusing library calls");
    require(argc == 2 || argc == 3, "usage: h10_job_handle count|release|control|race [iterations]");
    require(argc != 3 || !std::strcmp(argv[1], "race"), "only race accepts iterations");
    std::setvbuf(stdout, nullptr, _IOLBF, 0);
    if (!std::strcmp(argv[1], "count")) return count_case();
    if (!std::strcmp(argv[1], "release")) return release_case();
    if (!std::strcmp(argv[1], "control")) return control_case();
    if (!std::strcmp(argv[1], "race")) {
        char *end = nullptr;
        errno = 0;
        const long n = argc == 3 ? std::strtol(argv[2], &end, 10) : 2000;
        require(errno != ERANGE && (argc != 3 || (end != argv[2] && *end == '\0')) &&
                n >= 200 && n <= 10000,
                "iterations must be 200..10000");
        return race_case(static_cast<int>(n));
    }
    require(false, "unknown case");
    return 2;
}
