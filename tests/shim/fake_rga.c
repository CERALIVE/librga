/* SPDX-License-Identifier: Apache-2.0 */
/* Modified by CeraLive 2026-09-05: model H3 init failures without census saturation. */
#ifdef FORWARD_TIMING
#include "forward_timing.c"
#else
#define _GNU_SOURCE
#undef _FILE_OFFSET_BITS
#include <dlfcn.h>
#include <errno.h>
#include <fcntl.h>
#include <pthread.h>
#include <stdarg.h>
#include <stdatomic.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mman.h>
#include <unistd.h>
#include "../../core/hardware/rga_ioctl.h"

static int (*next_open)(const char *, int, ...);
static int (*next_openat)(int, const char *, int, ...);
static int (*next_ioctl)(int, unsigned long, ...);
static int (*next_close)(int);
static char *(*next_getenv)(const char *);
static pthread_once_t symbols_once = PTHREAD_ONCE_INIT;
static pthread_mutex_t lock = PTHREAD_MUTEX_INITIALIZER;
static _Thread_local bool resolving;
static atomic_ulong getenv_calls;
static int device_fds[4096];
static size_t device_count;
static uint32_t next_handle = 1, next_request = 1;

static void resolve_symbols(void)
{
    resolving = true;
#define RESOLVE(name) do { \
    *(void **)(&next_##name) = dlsym(RTLD_NEXT, #name); \
    if (!next_##name) _exit(125); \
} while (0)
    RESOLVE(open);
    RESOLVE(openat);
    RESOLVE(ioctl);
    RESOLVE(close);
    RESOLVE(getenv);
#undef RESOLVE
    resolving = false;
}

/* A marker lets a host client refuse to run when LD_PRELOAD was ignored. */
int fake_rga_active(void)
{
    return 1;
}

char *getenv(const char *name)
{
    if (resolving) {
        size_t length = strlen(name);
        for (char **entry = environ; *entry; ++entry)
            if (!strncmp(*entry, name, length) && (*entry)[length] == '=')
                return *entry + length + 1;
        return NULL;
    }
    pthread_once(&symbols_once, resolve_symbols);
    atomic_fetch_add_explicit(&getenv_calls, 1, memory_order_relaxed);
    return next_getenv(name);
}

static void write_file(const char *path, const void *data, size_t size, int flags)
{
    if (!path || !*path) return;
    int fd = next_open(path, O_WRONLY | O_CREAT | O_CLOEXEC | flags, 0600);
    if (fd < 0) _exit(125);
    const char *bytes = data;
    while (size) {
        ssize_t count = write(fd, bytes, size);
        if (count < 0 && errno == EINTR) continue;
        if (count <= 0) _exit(125);
        bytes += count;
        size -= (size_t)count;
    }
    if (next_close(fd)) _exit(125);
}

static void record(const char *text)
{
    const char *path = next_getenv("FAKE_RGA_LOG");
    write_file(path ? path : "interposed.log", text, strlen(text), O_APPEND);
}

__attribute__((destructor)) static void save_getenv_count(void)
{
    pthread_once(&symbols_once, resolve_symbols);
    char text[32];
    int length = snprintf(text, sizeof(text), "%lu\n",
                         atomic_load_explicit(&getenv_calls, memory_order_relaxed));
    write_file(next_getenv("FAKE_RGA_GETENV_COUNT"), text, (size_t)length, O_TRUNC);
}

static int fake_open(const char *operation, int flags)
{
    pthread_mutex_lock(&lock);
    int fd = -1;
    if (device_count == sizeof(device_fds) / sizeof(device_fds[0])) {
        errno = EMFILE;
    } else {
        fd = memfd_create("fake-rga", (flags & O_CLOEXEC) ? MFD_CLOEXEC : 0);
        if (fd >= 0) device_fds[device_count++] = fd;
    }
    int saved_errno = errno;
    char text[96];
    snprintf(text, sizeof(text), "%s /dev/rga fd=%d\n", operation, fd);
    record(text);
    pthread_mutex_unlock(&lock);
    errno = saved_errno;
    return fd;
}

static bool has_mode(int flags)
{
    return (flags & O_CREAT) || (flags & O_TMPFILE) == O_TMPFILE;
}

int open(const char *path, int flags, ...)
{
    pthread_once(&symbols_once, resolve_symbols);
    mode_t mode = 0;
    if (has_mode(flags)) {
        va_list args;
        va_start(args, flags);
        mode = va_arg(args, mode_t);
        va_end(args);
    }
    if (!strcmp(path, "/dev/rga")) return fake_open("open", flags);
    return has_mode(flags) ? next_open(path, flags, mode) : next_open(path, flags);
}

int openat(int dirfd, const char *path, int flags, ...)
{
    pthread_once(&symbols_once, resolve_symbols);
    mode_t mode = 0;
    if (has_mode(flags)) {
        va_list args;
        va_start(args, flags);
        mode = va_arg(args, mode_t);
        va_end(args);
    }
    if (!strcmp(path, "/dev/rga")) return fake_open("openat", flags);
    return has_mode(flags) ? next_openat(dirfd, path, flags, mode) : next_openat(dirfd, path, flags);
}

int open64(const char *path, int flags, ...) __attribute__((alias("open")));
int openat64(int dirfd, const char *path, int flags, ...) __attribute__((alias("openat")));

int close(int fd)
{
    pthread_once(&symbols_once, resolve_symbols);
    pthread_mutex_lock(&lock);
    for (size_t i = 0; i < device_count; ++i) {
        if (device_fds[i] == fd) {
            device_fds[i] = device_fds[--device_count];
            break;
        }
    }
    int ret = next_close(fd);
    pthread_mutex_unlock(&lock);
    return ret;
}

static const char *ioctl_name(unsigned long command)
{
    switch (command) {
#define NAME(value) case value: return #value
        NAME(RGA_BLIT_SYNC); NAME(RGA_BLIT_ASYNC);
        NAME(RGA_IOC_GET_DRVIER_VERSION); NAME(RGA_IOC_GET_HW_VERSION);
        NAME(RGA2_GET_VERSION); NAME(RGA_GET_VERSION);
        NAME(RGA_IOC_IMPORT_BUFFER); NAME(RGA_IOC_RELEASE_BUFFER);
        NAME(RGA_IOC_REQUEST_CREATE); NAME(RGA_IOC_REQUEST_SUBMIT);
        NAME(RGA_IOC_REQUEST_CONFIG); NAME(RGA_IOC_REQUEST_CANCEL);
        NAME(RGA_FLUSH); NAME(RGA_GET_RESULT);
#undef NAME
        default: return "UNKNOWN";
    }
}

static void version(struct rga_version_t *v, uint32_t major, uint32_t minor,
                    uint32_t revision, const char *text)
{
    memset(v, 0, sizeof(*v));
    v->major = major; v->minor = minor; v->revision = revision;
    snprintf((char *)v->str, sizeof(v->str), "%s", text);
}

static int handle_ioctl(unsigned long command, void *arg)
{
    const char *dump = next_getenv("FAKE_RGA_DUMP");
    /* Capture inputs, including padding and pointers, BEFORE driver output writes. */
    if (command == RGA_BLIT_SYNC || command == RGA_BLIT_ASYNC)
        write_file(dump, arg, sizeof(struct rga_req), O_APPEND);
    if (command == RGA_IOC_REQUEST_SUBMIT || command == RGA_IOC_REQUEST_CONFIG) {
        struct rga_user_request *request = arg;
        write_file(dump, request, sizeof(*request), O_APPEND);
        if (request->task_num > RGA_TASK_NUM_MAX) { errno = EINVAL; return -1; }
        write_file(dump, (void *)(uintptr_t)request->task_ptr,
                   request->task_num * sizeof(struct rga_req), O_APPEND);
    }

    const char *name = ioctl_name(command);
    const char *fail = next_getenv("FAKE_RGA_FAIL");
    if (fail && !strcmp(fail, "hwversion")) fail = "RGA_IOC_GET_HW_VERSION";
    if (fail && !strcmp(fail, "driverversion")) fail = "RGA_IOC_GET_DRVIER_VERSION";
    char variable[96];
    snprintf(variable, sizeof(variable), "FAKE_RGA_RET_%s", name);
    const char *override = next_getenv(variable);
    int result = override ? (int)strtol(override, NULL, 0) : 0;
    if ((fail && !strcmp(fail, name)) || (override && result < 0)) {
        const char *error = next_getenv("FAKE_RGA_ERRNO");
        errno = error ? (int)strtol(error, NULL, 0) : EIO;
        return (fail && !strcmp(fail, name)) ? -1 : result;
    }

    int normal_result = 0;
    switch (command) {
    case RGA_IOC_GET_DRVIER_VERSION:
        version(arg, 1, 3, 11, "1.3.11");
        normal_result = 1;
        break;
    case RGA_IOC_GET_HW_VERSION: {
        struct rga_hw_versions_t *hw = arg;
        memset(hw, 0, sizeof(*hw));
        /* rga_get_info is a userspace lookup, not an ioctl. An unknown core
         * exercises that lookup's failure AFTER the device fd is published. */
        if (fail && !strcmp(fail, "getinfo")) {
            hw->size = 1;
            version(&hw->version[0], 99, 0, 0, "99.0.0");
            normal_result = 1;
            break;
        }
        hw->size = 3;
        version(&hw->version[0], 3, 0, 0x76831, "3.0.76831");
        version(&hw->version[1], 3, 0, 0x76831, "3.0.76831");
        version(&hw->version[2], 3, 2, 0x63318, "3.2.63318");
        normal_result = 1;
        break;
    }
    case RGA2_GET_VERSION:
    case RGA_GET_VERSION:
        strcpy(arg, "3.2.63318");
        normal_result = 1;
        break;
    case RGA_IOC_IMPORT_BUFFER: {
        struct rga_buffer_pool *pool = arg;
        struct rga_external_buffer *buffers = (void *)(uintptr_t)pool->buffers;
        for (uint32_t i = 0; i < pool->size; ++i) buffers[i].handle = next_handle++;
        break;
    }
    case RGA_IOC_REQUEST_CREATE:
        *(uint32_t *)arg = next_request++;
        break;
    case RGA_IOC_REQUEST_SUBMIT:
    case RGA_IOC_REQUEST_CONFIG:
        ((struct rga_user_request *)arg)->release_fence_fd = (uint32_t)-1;
        break;
    case RGA_BLIT_SYNC:
    case RGA_BLIT_ASYNC:
        ((struct rga_req *)arg)->out_fence_fd = -1;
        break;
    case RGA_IOC_RELEASE_BUFFER:
    case RGA_IOC_REQUEST_CANCEL:
    case RGA_FLUSH:
    case RGA_GET_RESULT:
        break;
    default:
        errno = ENOTTY;
        return -1;
    }
    return override ? result : normal_result;
}

int ioctl(int fd, unsigned long command, ...)
{
    pthread_once(&symbols_once, resolve_symbols);
    va_list args;
    va_start(args, command);
    void *arg = va_arg(args, void *);
    va_end(args);
    pthread_mutex_lock(&lock);
    bool fake = false;
    for (size_t i = 0; i < device_count; ++i) fake |= device_fds[i] == fd;
    if (!fake) {
        pthread_mutex_unlock(&lock);
        return next_ioctl(fd, command, arg);
    }
    int ret = handle_ioctl(command, arg);
    int saved_errno = errno;
    char text[160];
    snprintf(text, sizeof(text), "ioctl %s fd=%d ret=%d errno=%d\n",
             ioctl_name(command), fd, ret, ret < 0 ? saved_errno : 0);
    record(text);
    pthread_mutex_unlock(&lock);
    errno = saved_errno;
    return ret;
}
#endif
