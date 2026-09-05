/* SPDX-License-Identifier: Apache-2.0 */
#ifndef QEMU_IOCTL_LIMIT_H
#define QEMU_IOCTL_LIMIT_H
#include <errno.h>
#include <stdlib.h>
#include <string.h>
#include <sys/ioctl.h>
#include <sys/syscall.h>
#include <unistd.h>

/* A raw syscall bypasses both shims: only the opted-in QEMU signature skips. */
static int qemu_ioctl_limit(unsigned long command)
{
#ifdef __aarch64__
    const char *opt = getenv("LIBRGA_TEST_QEMU_USER");
    if (!opt || strcmp(opt, "1")) return 0;
    int saved = errno, arg = 0;
    int unsupported = syscall(SYS_ioctl, -1, command, &arg) == -1 && errno == ENOTTY;
    int known_invalid = syscall(SYS_ioctl, -1, FIONREAD, &arg) == -1 && errno == EBADF;
    errno = saved;
    return unsupported && known_invalid;
#else
    (void)command;
    return 0;
#endif
}
#endif
