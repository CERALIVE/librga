# Known test-environment limits

## QEMU user-mode and invalid-fd RGA ioctls [EXISTS]

QEMU user-mode 11.1.1 returns `ENOTTY` for the unrecognized RGA commands
`0x5017` and `RGA_IOC_GET_HW_VERSION` (`0x80907202`) before native kernel fd
validation. This also happens with a direct `syscall(SYS_ioctl, ...)`, with no
shim loaded, for both `-1` and an fd immediately closed after opening `/dev/null`.
The same source compiled natively on x86_64 returns `EBADF`. In both environments
`fcntl(F_GETFD)` confirms the descriptor is invalid; the recognized `FIONREAD`
command returns `EBADF` even under QEMU.

This is not a fake-device ownership defect. The fake shim removes closed fds from
its tracked set and forwards unrecognized fds to `dlsym(RTLD_NEXT, "ioctl")`.
The timing shim always calls the real ioctl. Both original contracts pass on the
native x86_64 host; the environment limit was observed in both arm64 Bookworm and
Trixie containers on that host.

For **QEMU user-mode only**, opt in with `LIBRGA_TEST_QEMU_USER=1`. The helper
additionally requires an aarch64 build and verifies the unsupported-RGA/known-
FIONREAD raw-syscall signature before permitting a skip. The variable alone cannot
skip tests on native x86_64 or native aarch64 Linux. With it unset, the original
assertions still fail under affected emulation, deliberately.

- `shim-contract` skips only the closed-fd RGA errno assertion, still checks the
  closed fd with `fcntl`, and executes all remaining assertions. It returns 77
  after cleanup so Meson visibly reports SKIP, not a full contract pass.
- `board-timing` returns 77 before its invalid-fd RGA timing scenario. No timing
  coverage is claimed for that case under affected QEMU emulation.
- Neither shim implementation is changed. No other tests skip. Native GitHub
  arm64 CI does not set the opt-in; both complete contracts must pass there.

Example (substitute `bookworm` for the second suite):

```bash
docker run --rm --platform linux/arm64 \
  -e LIBRGA_TEST_QEMU_USER=1 \
  -v "$PWD":/src -w /src debian:trixie-slim bash ci/build-check-steps.sh
```

Do not use this allowance for QEMU system emulation: a guest kernel performs its
own fd validation, unlike user-mode syscall translation.
