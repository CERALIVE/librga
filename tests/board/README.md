# Board harness

This is non-installed Apache-2.0 test infrastructure. The G-A drill temporarily
swaps runtime packages; the standalone bench and staging helper do not.
Run `bash scripts/cross-build-harness.sh` to build every available Meson fragment
with aarch64 GCC/G++, including the inherited host shim/goldens. Unwired fragments
are appended only in the disposable `build-aarch64-source/` copy; a fully wired
checkout builds directly. `build-aarch64/` holds all artifacts. The coordinator
must preserve `librga_so = librga` before upstream reassigns `librga` to its static
archive. The board probe and bench link the shared library so `LD_LIBRARY_PATH`
can select either release. The inherited golden executable deliberately retains
todo 12's instrumented static library; it is not a shared-library comparison tool.
Both unit-pure and unit-session are present on the integrated R0 branch.

`QEMU_LD_PREFIX` defaults to `/usr/aarch64-linux-gnu`. This is a build-host sysroot,
not a promise of board ABI compatibility: use a target-suite-compatible cross
toolchain before a board run. No static-ASan/runtime preflight is implemented here.

## Credentials and ownership

Supply `BOARD_IP`, `BOARD_SSH_USER`, and `BOARD_SSH_PASS` or an absolute
`BOARD_SSH_PASS_FILE` through the environment. Scripts never source a credential
file or print a password. Missing credentials exit 77 before an SSH attempt.
`BOARD_KNOWN_HOSTS` defaults to `~/.ssh/known_hosts`; strict host-key verification
is always enabled. Have the owner verify a changed key out-of-band; never disable
verification to finish a drill.

Source `tests/board/lib.sh`, then call `board_lock_acquire` once. Push rollback
commands with `board_cleanup_push` before making changes. The sole EXIT trap
executes them LIFO before removing the marker and releasing the descriptor lock.
INT/TERM route through EXIT. The lock file is deliberately never unlinked (unlink
would let another process lock a different inode). The atomic remote marker is
`/tmp/ceralive-board-in-use`, containing effort, unique session, and UTC timestamp.
Any existing marker, including an old or malformed one, fails closed with 75.
Stale-marker recovery requires owner review and rollback of foreign package state;
there is no automatic six-hour theft of a potentially live board. SIGKILL/power
loss leaves a marker for that review. Do not override this library's EXIT trap.

`bash tests/board/lib.sh --selftest` uses actual independent Bash processes and
actual flock descriptors with mocked remote marker transport. It asserts second
process exit 75, rollback order, marker removal last, and foreign-marker refusal.

`bash scripts/stage-board.sh` acquires the same lock and copies `build-aarch64/.`
to `/tmp/librga-bench/`. It releases ownership after staging, not after a later
drill. A drill must acquire its own lock covering its entire execution. All board
outputs, including timing CSV, must be directed under `/tmp`.

## Bench and timing

Under a held board lock, run from `/tmp/librga-bench`:

```sh
LD_LIBRARY_PATH=/tmp/librga-bench ./probe-version
LD_LIBRARY_PATH=/tmp/librga-bench ./rga-convert-bench --selftest
LD_LIBRARY_PATH=/tmp/librga-bench \
LD_PRELOAD=/tmp/librga-bench/librga_timing.so \
RGA_TIMING_CSV=/tmp/librga-bench/timing.csv \
./rga-convert-bench --iterations 100 --explicit-csc
```

The selftest submits one synchronous 64x64 NV12 copy and requires infinite PSNR.
The matrix covers NV16→NV12, BGR→NV12, 4K→1080p NV12 scale, crop, and clockwise
90-degree rotation through both improcess and c_RkRgaBlit. Explicit 601/709
limited/full CSC rows are opt-in and use improcess. Default BGR conversion is
compared to BT.601 limited, without altering that oracle to accommodate a defect.
Every iteration poisons output before hardware submission, synchronizes CPU WRITE
START/END on each input/output write and CPU READ START/END around comparison,
and fails on sync or conversion error. Submitted work is synchronous; CPU cache
maintenance does not substitute for an asynchronous completion fence.

Output contains per-iteration PSNR and cumulative mean API latency. Matrix rows
fail below 30 dB; copy selftest requires exact bytes. Box is the default reference
resampler; `--bilinear` selects pixel-centred bilinear. This selection changes the
reference only, not driver interpolation. FD census spans allocation/release after
library initialization and before deinitialization so the persistent RGA session
is not mistaken for a leak. No hardware result may be inferred from host tests.

`fake_rga.c -DFORWARD_TIMING` builds a separate forwarding-only implementation:
no fake device opens, fake version data, or failure injection. All ioctls reach
the real next ioctl. Only fds resolving to `/dev/rga` are recorded. The bench's
optional `rga_timing_begin/end` hooks bracket the API call; each ioctl row carries
that operation's `t_total_us` and the individual `t_ioctl_us`. Do not sum repeated
total values when one API call emits several ioctls. Calls outside a bracket
(initialization/query) report total equal to ioctl duration. CSV includes pid,
command, result and errno, appends under flock, and preserves errno. A scope over
256 calls fails with 125 rather than dropping timing rows. Use a fresh CSV per run.
As with the inherited shim, the variadic ABI assumes an explicit third ioctl
argument; the librga and DMA-BUF calls exercised here all provide it.

`t_ioctl_us` is kernel-call wall time, including scheduling/waiting, NOT a pure
hardware execution counter. The total-minus-sum(ioctl) value is a userspace-side
estimate with instrumentation overhead. The fake shim's hardware marker is absent
from the timing shim, and the board bench refuses the fake marker explicitly.
The timing contract test mocks only fd-path lookup, then checks the real EBADF
result, errno preservation, CSV fields, and a userspace delay in the total scope.

See [COUNTERS.md](COUNTERS.md) for actual access status and the outstanding hardware
checks; see [the oracle](../oracle/README.md) for the independent numerical model.

## R0 neutrality gate [EXISTS]

Run `bash tests/board/g-a-neutrality.sh` once per board with `CERALIVE_BOARD_TEST=1`
and the credential environment above. Also supply `R0_DEB`, `RADXA_DEB`,
`HARNESS_DIR`, `PR_RUN_ID`, and a fresh repo-local `RESULT_DIR` under `build/`.
Download `dist` with `gh run download <run> --repo CERALIVE/librga --name dist`
from the latest successful Build Check run of the open R0 PR; record its head SHA.
Build the harness with a Trixie arm64 toolchain. Only the runtime CI artifact is
installed, never the development package or the locally built library.

The script checks reachability separately from the kernel/driver precondition,
holds lib.sh's lock and marker, verifies staged hashes, and registers the proven
Radxa rollback before apt installation. Every SSH/SCP call is timeout-bounded;
the soak runs a single process with a 295-second deadline and a 299-second outer
timeout. The fd census remains strict: any increase fails, even if pixels agree.
`--routing --core 1|2|4` submits 1,000 exact 128x64 NV12 copies using `imconfig`;
`--soak` exercises 4K NV16→NV12; `--improcess-only` excludes legacy pixel rows.
No oracle threshold or pre-existing fd assertion is relaxed for G-A.

RGB16 is the smoke format: canonical gstmpp.c maps it to `MPP_FMT_BUTT` to force
RGA conversion, and gstmppenc.c selects NV12 for unsupported input. Required log:
`converted with RGA` from the canonical c_RkRgaBlit path. Registration alone or
`RGA enabled` is insufficient. No rgaconvert/rgacompositor dependency exists.

R3 scores exact per-core counter deltas; R5 requires all nine default/supplemental
cells and the same-session 0.01 dB bound. A nonzero command, missing counter,
missing conversion log, fd increase, or rollback failure returns nonzero. A zero
exit covers this board only; overall PASS requires both boards and review of
[DRILL-RESULTS.md](DRILL-RESULTS.md). Interrupted SSH or power loss can prevent a
host EXIT trap reaching the board: inspect the retained marker and restore Radxa
manually before any next run in that case.
