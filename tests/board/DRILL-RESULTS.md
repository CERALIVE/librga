# G-A: R0 neutrality — 2026-09-05

**Overall verdict: BLOCKED. Do not merge or release R0 on this evidence.**

**2026-09-08 investigation update:**
[`R0-NEUTRALITY.md`](../../docs/R0-NEUTRALITY.md#owner-q1-investigation-2026-09-08)
now identifies the internal CSC padding and delayed `/dev/rga` session open,
records the fd-census harness fix and the cross-release R4 assertion fix, and
preserves their RED/GREEN evidence. This September 5 table is historical: it is
not a fresh G-A result, its original `.1` R4 silence is still unexplained, and
no row below is promoted to PASS by the narrower investigation.

Both boards were reached at their current addresses. Rock 5B+ failed the driver
precondition. Orange Pi ran R1–R7, including a bounded 4K soak, and was restored
to Radxa by the EXIT cleanup. Pixel neutrality alone is not an overall PASS.

## Artifact and execution identity

- Open PR: <https://github.com/CERALIVE/librga/pull/2>.
- Latest successful Build Check at download: **33972791251**, head
  `a006ba4b5a6a07e7f8bad955b2523f16e2b40e6e`.
- Download: `gh run download 33972791251 --repo CERALIVE/librga --name dist`.
- Runtime: `librga2-ceralive_1.10.1+ceralive.1_arm64.deb`, SHA-256
  `ad78d36a71f35b83285697c485ef8b85977e089ff7972b57b203a4bcbfd91fab`.
- Development artifact (downloaded, **not installed**): SHA-256
  `6218bb1ed1c44206ff5f06ae76269a055d728dbd5816ee6ef5fc136ea261b0a7`.
- Radxa rollback: `librga2_2.2.0-1_arm64.deb`, fetched from the URL in
  `docs/ROLLBACK.md`, SHA-256
  `ca4f18666f6c5d5290c7e41e5901350ecf76530f24364e37b81fa6be4ab5f344`.
- Both observed kernels: `7.2.0-ceralive-rk3588`.
- Island UAPI reference: **v2026.9.2**. Installed island tag is **unverified**:
  there is no `rk3588-media-island` dpkg package on Orange Pi. Driver version is
  measured below, not inferred from this reference tag.
- Harness built with the existing Trixie arm64 build container. Bench SHA-256:
  `d5f88a865457d7f5938735f1d59db69c0371eec4ed66bb02f0ea3d87eb009611`;
  probe SHA-256:
  `41e58b7b5a8231b537fd4328ddf3843bd9abd96f8a65c199aba144a56c3fe94d`.
- No locally rebuilt shared library was staged or substituted. New processes
  loaded the installed package. Existing services were not restarted or modified.

## Rock 5B+ — 192.168.78.131

**PRECONDITION-FAIL**, not an unreachable-board result. The first network
operation of this task was the required real precheck at the corrected IP:

```text
7.2.0-ceralive-rk3588
rockchip_rga           28672  0
ls: cannot access '/dev/rga': No such file or directory
```

The final script invocation with the supplied strict known-hosts file reproduced
the same result. An intermediate invocation used the default known-hosts file,
which contained a stale key and refused SSH; that transport failure does not
override the successful precheck. No host key was replaced and strict verification
was not disabled in the drill.

| Row | Result |
|---|---|
| R1 package replacement | NOT-RUN: precondition failed |
| R2 plugin registration | NOT-RUN: precondition failed |
| R3 per-core routing | NOT-RUN: precondition failed |
| R4 encode smoke | NOT-RUN: precondition failed |
| R5 pixel matrix | NOT-RUN: precondition failed |
| R6 soak | NOT-RUN: precondition failed |
| R7 rollback | NOT-NEEDED: no package installation or board mutation |

No modprobe, driver configuration, kernel, RAUC, or service operation was attempted.

## Orange Pi 5+ — 192.168.78.151

Precondition PASS: expected kernel, `rga_multicore 671744`, `/dev/rga` character
device. Fork-owned probe: `driver=1.3.11 text=1.3.11`, API `1.10.1_[4]`.
Sudo required the environment-supplied password; no credential is in this report.

| Row | Result | Actual observation |
|---|---|---|
| R1 | PASS | R0 runtime installed; real `librga2` not installed; dpkg owns our library and ldconfig resolves the SONAME. |
| R2 | PASS | `gstreamer1.0-rockchip-ceralive 1.14.4+ceralive.1` stays installed; `gst-inspect-1.0 mpph264enc` succeeds. |
| R3 | FAIL (fd assertion); routing subcheck PASS | All three masks complete 1000/1000 exact copies. Per-core deltas are exactly the selected core +1000, others +0; see COUNTERS.md. Each process reports fd 4→5 and exits 1. |
| R4 | FAIL (required log absent) | RGB16 1920×1080, 300 input buffers, reaches EOS and exits 0; zero `RGA_BLIT fail`. Required canonical conversion log is absent. |
| R5 | FAIL (fd assertion); pixel subcheck PASS | All five required cells and four supplemental explicit-CSC cells agree exactly with same-session Radxa; both processes report fd 4→5 and exit 1. |
| R6 | FAIL (fd assertion) | 295-second deadline, 299-second process timeout; 3857 successful 4K NV16→NV12 iterations, zero conversion/oracle failures, but fd 4→5. |
| R7 | PASS | EXIT trap apt rollback exits 0; `librga2 2.2.0-1` installed, R0 removed, ldconfig resolves restored Radxa file; SHA-256 verified. |

The fd increase is an unresolved measurement, not proof of a growing leak and not
waived as initialization noise. The pre-existing census remains unchanged.
No claim of flat fd count is made. The same 4→5 occurs with Radxa and R0.

RGB16 is deliberately mapped to `MPP_FMT_BUTT` in canonical
`gst/rockchipmpp/gstmpp.c` (the encoder consults that table and selects NV12).
The exact required source log in its `c_RkRgaBlit` success path is
`GST_DEBUG ("converted with RGA");`. The actual transcript only establishes
`gstmpp.c:123:gst_mpp_use_rga: RGA enabled` and NV12 format/alignment messages.
That is insufficient to quote a conversion-success line or declare R4 PASS.

### R5 same-session PSNR (dB)

| Cell | Radxa | R0 | Absolute delta |
|---|---:|---:|---:|
| NV16→NV12 | 61.607624 | 61.607624 | 0.000000 |
| BGR→NV12 | 52.776426 | 52.776426 | 0.000000 |
| NV12 4K→1080p | 59.677191 | 59.677191 | 0.000000 |
| NV12 crop | infinity | infinity | exact oracle match on both |
| NV12 rotate 90 | infinity | infinity | exact oracle match on both |
| Explicit BT.601 limited | 52.776426 | 52.776426 | 0.000000 |
| Explicit BT.601 full | 53.481074 | 53.481074 | 0.000000 |
| Explicit BT.709 limited | 52.904279 | 52.904279 | 0.000000 |
| Explicit BT.709 full | 50.687602 | 50.687602 | 0.000000 |

The numerical oracle, default interpolation, and 30 dB threshold were not changed.
The known G8 `full_csc` request-byte divergence from todo 15 remains unresolved:
these finite pixel observations neither explain it nor invalidate that finding.

### Restoration and retained evidence

Two full attempts were run. The first exposed that errexit prevented post-counter
capture after the fd assertion failed. The second captures counters even on bench
failure. Its scorer initially used awk's reserved `index` name; this was corrected
to `selected` and the corrected expression was run against the retained final
logs, proving all three exact deltas without another hardware/package run.
Both attempts restored Radxa through the EXIT stack; neither left R0 installed.

Final rollback evidence:

```text
Removing librga2-ceralive (1.10.1+ceralive.1) ...
Setting up librga2 (2.2.0-1) ...
Status: install ok installed
Version: 2.2.0-1
librga.so.2 (libc6,AArch64) => /lib/aarch64-linux-gnu/librga.so.2
R7 restore exit=0
```

Restored real file: `/usr/lib/aarch64-linux-gnu/librga.so.2.1.0`, SHA-256
`0b455344259c37fec821955e2de85bb5f76a34e69682217b514c407d8a35c6c3`.
Raw per-row logs are retained in `build/g-a-opi/` and `build/g-a-opi-final/`.

## Local verification

Trixie arm64 harness rebuild succeeds. Complete Meson suite: 13 OK, zero failures,
two documented opt-in QEMU skips (`shim-contract`, `board-timing`), not native
sanitizer coverage. ShellCheck and C/shell LSP error diagnostics are clean.
lib.sh selftest proves exclusion, LIFO cleanup, and foreign-marker refusal.
No opt-in exits 77; actual `192.0.2.1` negative control exits 77 with
`SKIPPED-unreachable`. The final counter parser passes on all three retained logs.

## The suite does NOT prove

The following scope block is retained from gstreamer-rockchip's board contract:

- Hardware not named by the transcript, including the separate mainline/edge 7.2
  fleet when a drill runs on the vendor 6.1 bench board.
- Long-term thermal, suspend/resume, OTA, or every capture-device path.
- That an `INCONCLUSIVE` d3 result authorizes a stride change. d3 is report-only;
  no shipped stride edit follows without decisive evidence and separate review.
- The pre-existing 4K59.94 H.265 SIGSEGV. That fault is out of scope and must not
  be chased or reclassified by these drills.
- ThreadSanitizer or LeakSanitizer cleanliness. TSAN cannot start under the known
  qemu-user VMA layout and LSan cannot complete there; deterministic mock seams
  and counters substitute only for the specific properties they assert.
- A result from an unreachable board. Such a run is `SKIPPED-unreachable` with an
  attempt transcript, never PASS.

G-A additionally proves nothing about `rgaconvert`, `rgacompositor`, or
`d5-rgaconvert-matrix.sh`: those are on the island effort's unmerged branch, not
canonical gstreamer-rockchip main's nine-factory set. Every pixel row here uses
this fork's DMA-BUF improcess harness and independent software oracle. TSan,
ASan, and UBSan are host-shim-only, never claimed as board coverage.

---

## G-A rerun — 2026-09-08: FAIL, release remains BLOCKED

This is a fresh package-level run on **both** boards, not a reclassification of
the September 5 evidence. Rock's driver precondition now passes. The corrected
fd census and cross-release conversion-log assertion pass on both boards.
**R5 still fails on both: NV12 rotate-90 returns `EINVAL` with both the
same-session Radxa baseline and the candidate.** Both full script invocations
exit 1, and both EXIT rollbacks and final functional checks succeed.

There is also an explicit procedure gap: the written G-A requirement calls for
a **one-hour R6 soak**, whereas this branch's unmodified `--soak` implementation
sets a **295-second deadline**, with a 299-second outer timeout in the script.
The bounded runs below pass, but **the one-hour R6 requirement is NOT MET**.
Neither a short run nor a baseline-identical rotation failure is waived here.

### Fresh artifact identity and method

- PR: <https://github.com/CERALIVE/librga/pull/2>, still OPEN; target
  `release/1.10.1`, head `integration/1.10.1-ceralive.1`.
- Latest green Build Check at download:
  <https://github.com/CERALIVE/librga/actions/runs/34224662759>, head
  `33f774c177da0ccca7fcc5b77eba1d87f27c8f28`. This contains both harness fixes
  (`772f9ec`, `2f6033e`) and their investigation record (`33f774c`).
- Downloaded with `gh run download 34224662759 --repo CERALIVE/librga
  --name dist --dir test-results/todo42/dist`; artifact ID `10055193621`.
- `dpkg-deb -f` verifies runtime `librga2-ceralive`, development
  `librga-ceralive-dev`, both version `1.10.1+ceralive.1`, architecture `arm64`.
  The development package was downloaded and hashed, **not installed**.
- No R0 release exists at this measurement (`gh release view
  '1.10.1+ceralive.1' --repo CERALIVE/librga`: `release not found`). These are
  PR CI artifacts, not release assets or locally rebuilt replacements.

| Artifact | SHA-256 |
|---|---|
| Runtime CI `.deb` | `a1774e08cefa7a77847f9bcc9e5d7fcbf9f45c4b88801f07bd59748383a076b2` |
| Development CI `.deb` | `b0eba393b056b68f6bca346c4d6e18edcd91cd44066e5a69630435752bed6e11` |
| Extracted runtime `librga.so.2.1.0` | `b5de45ca349b96317f119a42846546b5fc9b448a262878daab0d320b9cde319f` |
| Pinned Radxa rollback `.deb` | `ca4f18666f6c5d5290c7e41e5901350ecf76530f24364e37b81fa6be4ab5f344` |
| Restored Radxa library, both boards | `0b455344259c37fec821955e2de85bb5f76a34e69682217b514c407d8a35c6c3` |
| Corrected `rga-convert-bench` | `602b3e0e739ba1e802b0b15b93b06e2de7f78966c9fef9cdef4144503b0d4449` |
| Fork `probe-version` | `41e58b7b5a8231b537fd4328ddf3843bd9abd96f8a65c199aba144a56c3fe94d` |

The harness was compiled/checked in `librga-trixie-arm64:latest`, GCC 14.2,
against this branch. Only the two aarch64 executables were staged in
`/tmp/librga-g-a`; **no shared library** was staged there. The final directory
inventory and `ldd` confirm resolution through the installed system SONAME.
No `LD_LIBRARY_PATH` or shim substitution was used for the board rows.

Rock's first board operation was its fresh kernel/module/device/probe precheck.
The rollback archive from [ROLLBACK.md](../../docs/ROLLBACK.md) was then staged
and SHA-verified on **both boards before either candidate installation**:
Rock at 13:08:46Z, Orange Pi at 13:08:48Z. Each run additionally re-staged and
verified both archives under its own lock. The outer board harness enforced
idle state and exclusive ownership; `lib.sh` held its separate descriptor lock
and marker throughout G-A and executed the registered cleanup stack.

The unmodified invocation, with credentials supplied only through environment:

```sh
CERALIVE_BOARD_TEST=1 PR_RUN_ID=34224662759 \
R0_DEB="$PWD/test-results/todo42/dist/librga2-ceralive_1.10.1+ceralive.1_arm64.deb" \
RADXA_DEB="$PWD/test-results/todo42/librga2_2.2.0-1_arm64.deb" \
HARNESS_DIR="$PWD/build" RESULT_DIR="$PWD/build/g-a-todo42-<board>" \
bash tests/board/g-a-neutrality.sh
```

The script registers `restore` before the first apt install. Forward install
uses `apt-get install --yes /tmp/librga2-ceralive_1.10.1+ceralive.1_arm64.deb`;
EXIT uses `apt-get install --yes --allow-downgrades
/tmp/librga2_2.2.0-1_arm64.deb`. No bare `dpkg -i`, kernel/module configuration,
service restart, boot-slot operation, or healthcheck-marker operation occurred.
The outer lock stayed held for the fresh-process post-restore selftest.

### Rock 5B+ — fresh R0 run

- **Package SHA-256:** `a1774e08cefa7a77847f9bcc9e5d7fcbf9f45c4b88801f07bd59748383a076b2`.
- **Kernel:** `7.2.0-ceralive-rk3588 #ceralive1 SMP PREEMPT @1788765300`.
- **Island tag:** installed tag **UNVERIFIED**; `v2026.9.2` remains only the
  harness's pinned UAPI reference. Driver `1.3.11` is measured, not inferred.
- **Run:** 13:09:49Z–13:15:03Z, followed by successful final functional check.
- **Precondition PASS:** at 13:07:29Z `rga_multicore 208896 0`, `/dev/rga`
  character device, and fork probe `driver=1.3.11 text=1.3.11`. Both RGA3 node
  driver links (`fdb60000`, `fdb70000`) resolve to `rga3`; RGA2 (`fdb80000`)
  resolves to `rga2`. No module reload or binding repair was attempted.

| Row | Verdict | Fresh observation |
|---|---|---|
| R1 package replacement | PASS | R0 installed; real `librga2` not installed; dpkg library ownership and ldconfig SONAME resolve correctly. |
| R2 plugin registration | PASS | Installed `gstreamer1.0-rockchip-ceralive 1.14.4+ceralive.2` retained; `mpph264enc` registers. |
| R3 per-core routing | PASS | Three 1000/1000 exact-copy runs; selected core +1000 and others +0; each fd census 5→5. |
| R4 encode smoke | PASS | RGB16 1920×1080, 300 buffers, EOS/exit 0; 300 `using RGA converted buffer` lines; no `RGA_BLIT fail`. |
| R5 pixel matrix | **FAIL** | Rotation rejected with Radxa and R0; only eight of nine PSNR cells emitted. All emitted cells equal, both fd counts 5→5. |
| R6 soak | **PARTIAL — one-hour requirement unmet** | Unmodified bounded harness exits 0: 3814 successful 4K NV16→NV12 iterations over its 295-second deadline, no bench failures, fd 5→5. |
| R7 rollback | PASS | EXIT apt rollback/status/hash checks exit 0; fresh Radxa exact-copy selftest and plugin registration pass. |

R3 counter tuples are ordered debugfs core indices 0/1/2:

| Mask | Before | After | Delta |
|---|---|---|---|
| 1 | 124423,1000,2005 | 125423,1000,2005 | 1000,0,0 |
| 2 | 125423,1000,2005 | 125423,2000,2005 | 0,1000,0 |
| 4 | 125423,2000,2005 | 125423,2000,3005 | 0,0,1000 |

Selected transcript (verbatim result lines; board address omitted):

```text
driver=1.3.11 text=1.3.11
baseline exit=1
R1 exit=0
R2 exit=0
R3-core-1 exit=0
R3-core-2 exit=0
R3-core-4 exit=0
R4 exit=0
R5 exit=1
R5 PSNR neutrality FAIL
R6 exit=0
R1-R6 scored; failures=1; R7 follows in EXIT cleanup
R7 restore exit=0
GATE-EXIT=1 UTC=2026-09-08T13:15:03Z
Status: install ok installed
Version: 2.2.0-1
copy-selftest,improcess,0,520.346,inf
completed=1 cell=copy-selftest
fd_census_before=5 after=5
RESTORED-FUNCTIONAL=PASS
FINAL-FUNCTIONAL-EXIT=0
```

### Orange Pi 5+ — fresh R0 run

- **Package SHA-256:** `a1774e08cefa7a77847f9bcc9e5d7fcbf9f45c4b88801f07bd59748383a076b2`.
- **Kernel:** `7.2.0-ceralive-rk3588 #ceralive1 SMP PREEMPT @1788765300`.
- **Island tag:** installed tag **UNVERIFIED**; `v2026.9.2` is the UAPI
  reference, not installed-image provenance. Measured driver is `1.3.11`.
- **Run:** 13:17:20Z–13:22:35Z, followed by successful final functional check.
- **Precondition PASS:** expected kernel, `rga_multicore 208896 1`, `/dev/rga`,
  fork probe `driver=1.3.11 text=1.3.11`, installed Radxa `2.2.0-1` and baseline
  library SHA match before swapping.

| Row | Verdict | Fresh observation |
|---|---|---|
| R1 package replacement | PASS | R0 installed; real `librga2` not installed; dpkg ownership and ldconfig checks pass. |
| R2 plugin registration | PASS | Installed `gstreamer1.0-rockchip-ceralive 1.14.4+ceralive.2` retained; `mpph264enc` registers. |
| R3 per-core routing | PASS | Three 1000/1000 exact-copy runs; exact selected-core deltas; each fd census 5→5. |
| R4 encode smoke | PASS | 300 RGB16 input buffers, EOS/exit 0; 300 `using RGA converted buffer` lines; no `RGA_BLIT fail`. |
| R5 pixel matrix | **FAIL** | Radxa and R0 both reject rotation; eight equal PSNR cells do not satisfy the nine-cell requirement. Both fd counts 5→5. |
| R6 soak | **PARTIAL — one-hour requirement unmet** | Bounded harness exits 0: 3935 successful 4K NV16→NV12 iterations over its 295-second deadline, no bench failures, fd 5→5. |
| R7 rollback | PASS | EXIT apt rollback/status/hash checks exit 0; fresh Radxa exact-copy selftest and plugin registration pass. |

| Mask | Before (cores 0/1/2) | After (cores 0/1/2) | Delta |
|---|---|---|---|
| 1 | 8547,37,11 | 9547,37,11 | 1000,0,0 |
| 2 | 9547,37,11 | 9547,1037,11 | 0,1000,0 |
| 4 | 9547,1037,11 | 9547,1037,1011 | 0,0,1000 |

Selected transcript:

```text
driver=1.3.11 text=1.3.11
baseline exit=1
R1 exit=0
R2 exit=0
R3-core-1 exit=0
R3-core-2 exit=0
R3-core-4 exit=0
R4 exit=0
R5 exit=1
R5 PSNR neutrality FAIL
R6 exit=0
R1-R6 scored; failures=1; R7 follows in EXIT cleanup
R7 restore exit=0
GATE-EXIT=1 UTC=2026-09-08T13:22:35Z
Status: install ok installed
Version: 2.2.0-1
copy-selftest,improcess,0,310.622,inf
completed=1 cell=copy-selftest
fd_census_before=5 after=5
RESTORED-FUNCTIONAL=PASS
FINAL-FUNCTIONAL-EXIT=0
```

### R5 same-session matrix and remaining failure

All four columns are freshly measured, not copied from the prior run. The bar
remains 30 dB and the per-board neutrality bound remains 0.01 dB.

| Cell | Rock Radxa | Rock R0 | Orange Pi Radxa | Orange Pi R0 |
|---|---:|---:|---:|---:|
| NV16→NV12 | 61.607624 | 61.607624 | 61.607624 | 61.607624 |
| BGR→NV12 | 52.776426 | 52.776426 | 52.776426 | 52.776426 |
| NV12 4K→1080p | 59.677191 | 59.677191 | 59.677191 | 59.677191 |
| NV12 crop | infinity | infinity | infinity | infinity |
| NV12 rotate 90 | **EINVAL, no pixels** | **EINVAL, no pixels** | **EINVAL, no pixels** | **EINVAL, no pixels** |
| Explicit BT.601 limited | 52.776426 | 52.776426 | 52.776426 | 52.776426 |
| Explicit BT.601 full | 53.481074 | 53.481074 | 53.481074 | 53.481074 |
| Explicit BT.709 limited | 52.904279 | 52.904279 | 52.904279 | 52.904279 |
| Explicit BT.709 full | 50.687602 | 50.687602 | 50.687602 | 50.687602 |

Absolute per-board delta is **0.000000 dB for every finite emitted cell**;
crop is exact on both libraries. Rotation has no PSNR, not zero delta. The
strict nine-cell scorer correctly rejects both boards.

The bench submits NV12 1280×720 → 720×1280 with 90-degree rotation through
`improcess`. All four processes report `RGA_BLIT fail: Invalid argument`.
The corresponding current-kernel journal records are:

```text
Rock Radxa: 13:09:53 rga: 586577 586577: ID[127431]: request validation failed before mapping
Rock R0:   13:10:03 rga: 587080 587080: ID[130740]: request validation failed before mapping
OPi Radxa: 13:17:25 rga: 1779392 1779392: ID[8598]: request validation failed before mapping
OPi R0:    13:17:35 rga: 1779906 1779906: ID[11907]: request validation failed before mapping
```

These matching PIDs establish a real rejected request, not a log-assertion or
fd-census failure. It also occurs **before installing R0**, so this A/B does
not support attributing it to the R0 package swap. The precise failing kernel
predicate and historical regression-introducing commit remain **undiagnosed**;
no driver fix or neutrality waiver was attempted. Rock additionally records
two `Failed to map attachment, ret[-5]` lines under each matrix PID one second
later; their association with a particular subsequent CSC cell is unproven.
They are retained, not conflated with the rotation's pre-mapping rejection or
the old DT/IOMMU driver-binding gap.

### Verification, retained evidence, and release boundary

- Both boards finish on the pinned Radxa library hash above, with R0 absent.
  Each fresh 64×64 NV12 copy matches the oracle exactly; fd census is 5→5.
  `gst-inspect-1.0 mpph264enc` also succeeds after rollback.
- Local aarch64 Trixie build succeeds. Complete Meson suite with the documented
  `LIBRGA_TEST_QEMU_USER=1` opt-in: **15 OK, two established emulation SKIPs,
  zero failures**. An initial invocation used incorrect opt-in variable names
  and exposed the two documented invalid-fd ioctl failures; that failed log
  is retained. Native arm64 CI at the tested head is green without those skips.
- No-opt-in control exits 77. Reserved unreachable-address control returns
  `SKIPPED-unreachable`, exit 77; neither real board was unreachable.
- The raw per-row logs live in `build/g-a-todo42-rock/` and
  `build/g-a-todo42-opi/`. Prechecks, stage receipts, complete session logs,
  final functional proofs, diagnostic journal excerpts, and scratch wrappers
  live in repo-local, ignored `test-results/todo42/`.
- `test-results/todo42/board-evidence.tar.gz` retains those logs and wrappers;
  SHA-256 `f138e0263f8145fc526a778f834aeee476a3162f6ddc9b14adb7d27ed93cb150`.

This rerun **does not prove** a one-hour soak, rotation neutrality, the installed
island tag, `rgaconvert`/`rgacompositor` behavior, sanitizer cleanliness on boards,
long-term thermal/suspend/OTA behavior, every capture path, or any untested
hardware. It neither changes raw G8 byte equality nor waives the ELF-export
finding in [R0-NEUTRALITY.md](../../docs/R0-NEUTRALITY.md). The original `.1`
R4 silence remains historical evidence, not retroactively green. **Do not merge
or release R0 on this rerun.** Independent review and release authorization are
separate; no merge, approval, release dispatch, or release-branch update was made.

---

## R6 duration correction — Orange Pi 5+ — 2026-09-08

This is the genuine one-hour R6 rerun requested to close the harness defect. It
used the fixed aarch64 `rga-convert-bench` from this worktree and the R0 runtime
artifact from successful Build Check run **34232406507**, head
`386f40c32e469c6a218190e96f6ed11ab5bebd7e`.

- **Board:** Orange Pi 5+, idle before the run; kernel `7.2.0-ceralive-rk3588`.
- **Driver:** `1.3.11`; island tag remains unverified.
- **Candidate package SHA-256:**
  `a1774e08cefa7a77847f9bcc9e5d7fcbf9f45c4b88801f07bd59748383a076b2`.
- **Soak:** 14:20:31Z–15:20:31Z, **3600 seconds elapsed**; fixed bench
  deadline `3600e6`, with the `3605` second outer timeout available.
- **Workload:** 4K `NV16 → NV12`, `3840×2160`, one `rga-convert-bench`
  process, `48227` successful iterations.
- **Failures:** zero conversion failures and zero oracle failures; R6 exit `0`.
- **Bench fd census:** `before=5 after=5`.
- **Live fd monitor:** 58 one-minute samples during the active soak, all at
  **6** descriptors for the bench process (the two post-exit probes are excluded).
  No growth or transient increase was observed.
- **Restoration:** EXIT rollback exit `0`; Radxa `librga2 2.2.0-1` restored,
  candidate absent, restored library SHA-256
  `0b455344259c37fec821955e2de85bb5f76a34e69682217b514c407d8a35c6c3`.

### R6 verdict

**PASS for the R6 one-hour soak requirement.** The overall G-A verdict remains
**FAIL / release BLOCKED** solely because the separately tracked R5 rotation row
still fails; R5 was not changed or re-run as part of this correction.
