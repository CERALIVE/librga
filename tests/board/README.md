# Board harness

Current acceptance evidence: [R1 both-board drill results](DRILL-RESULTS.md),
**post-release record**, [PARTIAL]. It was not on the original open R1 PR;
[rows 24/26 deviations](../../docs/R1-RECORD-DEVIATIONS.md) await owner disposition.
The record distinguishes measured candidate results, released-byte
activation/restoration, owner supersessions and still-missing qualification.
It is not permission to run a board drill or a live APT transaction.

This is non-installed Apache-2.0 test infrastructure. It never installs packages.
Run `bash scripts/cross-build-harness.sh` to build every available Meson fragment
with aarch64 GCC/G++, including the inherited host shim/goldens. Unwired fragments
are appended only in the disposable `build-aarch64-source/` copy; a fully wired
checkout builds directly. `build-aarch64/` holds all artifacts. The coordinator
must preserve `librga_so = librga` before upstream reassigns `librga` to its static
archive. The board probe and bench link the shared library so `LD_LIBRARY_PATH`
can select either release. The inherited golden executable deliberately retains
todo 12's instrumented static library; it is not a shared-library comparison tool.
Both unit-pure and unit-session are present. `golden-cases-dynamic` is the
separate uninstrumented shared-library client for provider comparisons.

`QEMU_LD_PREFIX` defaults to `/usr/aarch64-linux-gnu`. This is a build-host sysroot,
not a promise of board ABI compatibility: use a target-suite-compatible cross
toolchain before a board run.

## The static-ASan board variant

`bash scripts/cross-build-harness.sh --asan` is a separate leg from the default
one above: it does not configure Meson at all. It runs one preflight —

```sh
aarch64-linux-gnu-gcc -print-file-name=libasan.a
```

— and records the verdict in `build-aarch64/asan/PREFLIGHT.txt`. A bare
`libasan.a` back means the cross toolchain has no static ASan runtime, so nothing
can be built that runs on a board without installing one; the leg is recorded
**NOT-AVAILABLE**, builds nothing, and exits 77. **That is the verdict on the
current toolchain** (GCC 16.1.0, checked 2026-09-05 — it carries no aarch64
`libasan`, `libtsan` or `libubsan` at all).

When the preflight passes, the leg compiles `tests/shim/asan-canary.c` and every
`tests/repro/*.c` with `-fsanitize=address -static-libasan`, then refuses any
output that still resolves `libasan` dynamically or lacks `__asan_init`.
`bash scripts/stage-board.sh --asan` reads the recorded verdict, refuses to stage
on NOT-AVAILABLE, and otherwise copies `build-aarch64/asan/` to
`/tmp/librga-bench/asan/`. Run `asan-canary` on the board first: a static ASan
runtime that fails to start there is indistinguishable from a clean run.

TSan has no board leg and never will — it cannot be statically linked reliably.
Full detail in [`docs/SANITIZERS.md`](../../docs/SANITIZERS.md).

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
is not mistaken for a leak. The bench acquires `c_RkRgaGetContext()` and runs
an im2d validation-only `imcheck` before the census: R1 has a separate lazy im2d
session that the legacy context does not warm. `--session-selftest` requires the
host fake-device shim and checks both sessions again inside the measured interval.
Strict equality is unchanged. No hardware result may be inferred from host tests.

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

## Recovered isolated R1 drill [EXISTS]

`r1-isolated-drill.sh` adapts the reusable measurements from the R0 package drill.
It **does not install/remove packages**: current sysext qualification forbids APT
management or remounting `/usr`. Supply an already-authorized, idle board and an
SSH identity allowed to access its RGA, DMA heap and read-only debugfs counters.
The script holds the existing descriptor lock/remote marker throughout staging,
measurement and LIFO cleanup. Every transport call is bounded.

Supply `CERALIVE_BOARD_TEST=1`, the credential environment above, `PR_RUN_ID`,
`BASELINE_LIB` and `CANDIDATE_LIB` (locally extracted real `librga.so.2.1.0`
files), their expected `BASELINE_SHA256`/`CANDIDATE_SHA256`, `HARNESS_DIR` holding
target-suite `probe-version` and `rga-convert-bench`, and a **fresh repo-local**
`RESULT_DIR`. Run `bash tests/board/r1-isolated-drill.sh` only after obtaining
board ownership from the coordinator. It stages unique `/tmp` directories,
verifies both provider hashes remotely, and sets `LD_LIBRARY_PATH` for each
individual process. It never exports a system-wide override or restarts services.

Also required: `RELEASE_VERSION`, `RUNTIME_DEB`, `DEV_DEB` and `BOARD_MODEL`
(`rock-5b-plus` or `orange-pi-5-plus`). The archives must be that version's arm64
runtime/development pair. The candidate's expected hash must equal the ELF **inside
the runtime archive**; a separately rebuilt local library is rejected before SSH,
even if its supplied hash is accurate. Inputs go in `artifact-inputs.sha256`.
Only successful rows **and successful cleanup** produce `<BOARD_MODEL>.sha256`.
Review/promote both receipts as described in
[the identity contract](../../docs/QUALIFICATION-IDENTITY.md). This records package
identity, not a package-transaction test; it does not discharge H1 or other drills.

Measurements retained from R0:

- `--routing --core 1|2|4`: 1000 exact NV12 copies at 128×64; selected debugfs
  core must increase by exactly 1000 and the other two by zero.
- `--improcess-only --iterations 1 --explicit-csc`: all nine named cells,
  including rotation, must exist exactly once on each provider, score at least
  30 dB, and agree within 0.01 dB (infinity must agree exactly). This is a strict
  comparison, **not** a new R1 neutrality policy; intended behavior changes may
  make it RED and require review, never a silent threshold relaxation.
- RGB16 encoder smoke: `mpp:5,mppenc:5`; either `converted with RGA` or
  `using RGA converted buffer` is required. Enable-only/empty/failure logs fail.
- `--soak`: one process, 3840×2160 NV16→NV12, a 3600-second monotonic deadline,
  3605-second process timeout and 3700-second SSH bound. Every iteration retains
  DMA synchronization, poisoned output, submission/oracle checks and PSNR output.
  Zero iterations or reaching the iteration cap before the deadline is failure.
  The wrapper independently checks elapsed time, completed-row count and fd equality.
- A fresh baseline copy runs afterward. EXIT removes only the uniquely staged
  directory before ownership release; cleanup failure propagates. This is not R0's
  package-restoration proof. Interrupted transport/power loss still requires owner
  inspection of the retained marker and temporary state.

Offline coverage is registered in Meson: `board-session-baseline`,
`board-soak-control`, `board-recovery-mutations`, `board-conversion-evidence` and
`board-isolated-drill`. The loop fixture substitutes in-memory I/O and a clock;
the drill fixture substitutes **all transport**, retaining real orchestration,
scorers and cleanup. Neither executes hardware. Both-board R1 soaks and package
installation/removal/rollback remain **NOT RUN by this recovery**.
