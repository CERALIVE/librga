| Todo 38 / H10a; execution base `f04a90e`; decrement only for a found job. | **RED:** unknown cancellation changes count/map 0/0 to -1/0; 64 creates become 63/64. **GREEN:** 0/0 stays 0/0, creates 64/64, cleanup 0/0, unchanged cancellation status 1. Same `tests/repro/h10_job_handle.cpp count` under both runtimes; transcript directories below. | **host-shim-only**, native x86_64 Debian trixie, GCC 14.2.0, ASan+UBSan and TSan, 2026-09-14. | Matched debug build `abidiff` unchanged (`test-results/item45/abidiff.txt`); no public signature/layout/visibility/SONAME/default/status/message changes. | BLOCKED pending independent different-model review receipt. | not-offered (no source) — offer to JeffyCN. No userspace count limit exists, so no premature-limit fix is claimed. |
| Todo 38 / H10b; execution base `f04a90e`; retain manager lock through CONFIG task copying. | **RED:** ASan and TSan heap-use-after-free in both repeats; CONFIG borrows task memory after unlock and CANCEL frees it. **GREEN:** original `race 2000` completes twice under each runtime with zero failures, count/map 0/0; canaries report and controls pass. Six registered H10 tests pass under each sanitizer; native adjacent suite 28/28. | **host-shim-only**, native x86_64 Debian trixie, GCC 14.2.0, ASan+UBSan and TSan, 2026-09-14. No board commands or H7 claim. | Same matched-build `abidiff`; no public layout/API change. No released-handle state added to the library. | BLOCKED pending independent different-model review receipt. | not-offered (no source) — offer to JeffyCN. Mutex scope favors correctness; CONFIG serializes other job-manager operations until ioctl returns. |
| Todo 38 / H10c; **driver-owned, not a librga defect**; no library change. | Original `release` still forwards twice (exit 1) before and after. New opt-in shim model verifies same-buffer import twice returns handle 1, both releases succeed, exhausted refcount fails in the driver model, re-import reuses handle 1 and release succeeds. All 3 imports and 4 releases reach the shim. **PASS before/after**: `test-results/item45/reimport-base.txt` and H10 `reimport` tests under both sanitizers. | **host-shim-only**; one-buffer reference-count/reuse model, not silicon or a full kernel-memory model. | No production tombstone, deduplication, status or API change. Numeric reuse remains valid. | BLOCKED pending independent different-model review receipt. | Driver ownership: island `rga_mm.c:1582-1608,4071-4085` counts imports; `:4124-4148` uses cyclic ID allocation (plan's H-2 disposition). No librga fix offered. |

## Reproduction and artifacts

Both branches start at `f04a90e`. H10's implementation file was unchanged from
`57a1067` at the execution base; already-merged initialization/lifetime fixes
were not reimplemented. Reproduction budget: original runner's two requested
2000-iteration races per sanitizer, 30-second timeout per process. RED stops at
the first sanitizer report, not at 2000 completed iterations.

Commands: `bash tests/repro/run-h10.sh asan` and `... tsan`, before and after.
They were run detached in a native x86_64 trixie container. ASan+UBSan use
`verify_asan_link_order=0`, `detect_leaks=1`, `halt_on_error=1`, `symbolize=0`;
the canary permits UBSan to continue to its ASan fault. TSan uses
`halt_on_error=1:exitcode=66:symbolize=0`. No suppression file is used.

| Phase | ASan+UBSan directory | TSan directory |
|---|---|---|
| RED | `test-results/h10/asan-mcIiMjp9/` | `test-results/h10/tsan-011JL9dR/` |
| GREEN | `test-results/h10/asan-U1HIB78Y/` | `test-results/h10/tsan-1YmHdZWG/` |

Every directory contains `status.tsv`, build/compile logs, and
`{canary,control,count,release,race-1,race-2}/transcript.txt` plus shim logs and
request dumps. The original runner's aggregate exit stays **1** because H10c's
forwarding observation is intentionally unchanged; GREEN refers to H10a/H10b,
not to a falsified aggregate result.

### Terminal lines from the original runner

```text
RED (both modes):
H10a unknown=2147483647 status=1 before=0/0 after=-1/0 created=63/64 cleaned=-1/0 count_drift=RED
ASan race-1/race-2: ERROR: AddressSanitizer: heap-use-after-free (exit 1 each)
TSan race-1/race-2: WARNING: ThreadSanitizer: heap-use-after-free (exit 66 each)

GREEN (both modes):
H10a unknown=2147483647 status=1 before=0/0 after=0/0 created=64/64 cleaned=0/0
ASan race-1: completed=2000 config_success=754 config_missing=1246 end_success=751 end_missing=1249 count=0 map=0
ASan race-2: completed=2000 config_success=758 config_missing=1242 end_success=753 end_missing=1247 count=0 map=0
TSan race-1: completed=2000 config_success=115 config_missing=1885 end_success=110 end_missing=1890 count=0 map=0
TSan race-2: completed=2000 config_success=98 config_missing=1902 end_success=93 end_missing=1907 count=0 map=0
All four GREEN race exits: 0; no sanitizer report.
```

Offline symbolization of the RED TSan offsets is saved in
`test-results/item45/red-tsan-symbols.txt`: CONFIG `0x4d5e4` resolves to
`im2d_impl.cpp:2560`, CANCEL `0x4cacf` to `:2442`. This identifies actual shared
library frames, not just the shim's read. The sanitizer canary transcripts
prove interception, not merely linked runtimes.

The new registration adds `count`, `control`, `errors`, `reimport` and two races
to `h10`; races also enter `concurrency`. Per-case log truncation makes repeated
Meson runs independent. `errors` tests failed CONFIG followed by successful
CONFIG/cancel and repeated cancellation, including unchanged status values.

Registered-suite evidence: `test-results/item45/h10-asan-suite-fixed.txt` (6/6)
and `h10-tsan-suite-fixed.txt` (6/6). 2000-iteration repeats took 1.25/1.32 s
under ASan and 3.37/3.40 s under TSan in that run: bounded host-model overhead,
**not** hardware latency. The earlier `h10-*-suite.txt` files preserve the
failed aggregate static-UAPI rebuild; the recipe now uses `--no-rebuild` after
the explicit sanitizer build, with the static parity gate kept unsanitized.

Adjacent native tests and eight unchanged goldens: `test-results/item45/fixed-tests.txt`
(28/28, excluding only the separately covered architecture-specific UAPI suite).
ABI inputs are `build-abi-base/librga.so.2.1.0` and
`build-fixed/librga.so.2.1.0`, both GCC 14 debug builds with identical options.
This is a same-R1-base change comparison, **not** a waiver of inherited R0→R1
export removals.
