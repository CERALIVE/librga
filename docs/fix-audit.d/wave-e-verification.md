### Wave-E takeover verification — 2026-09-13

This is fresh execution, not adoption of the killed lane's claims. The inherited
C/D/A commits were pushed to `origin/fixes/wave-e` before any edit. All RED runs
used a separate checkout of exactly
`1bde9018d28092879978419f8e48f2b88debcbaa`. All paths below are local to the tree
named by the corresponding RED or GREEN section; no script needs another checkout.
Historical fragments and their older runs remain evidence of those runs only.

**Release closure is BLOCKED.** All four regressions and the host gate are green,
but the strict export-superset requirement against the published R0 fails. The
same exports are already absent on pre-fix R1. This is not permission to suppress
them, modify visibility, add unrelated compatibility code, or merge the PR.

#### Commands and proof boundary

```sh
bash scripts/build-sanitized.sh asan
bash scripts/build-sanitized.sh tsan
bash tests/repro/run-candidate-c.sh
bash tests/repro/run-candidate-d.sh
bash tests/repro/run-candidate-a.sh
bash tests/repro/run-candidate-b.sh
```

On the RED tree the four runners return 1, so run them independently, not chained
with `&&`. The GREEN runners return 0. Compiler: native x86_64 GCC 16.2.1;
Meson 1.12.0. Sanitizer canaries run with the fake-device preload and must report.
This is host-shim evidence, not silicon, Debian arm64 CI, or release approval.

#### C — default scheduler

Mechanism: explicitly accept the documented zero enum value before testing the
nonzero scheduler mask, preserving every previously accepted value.
Implementation retained from `752f719`: `im2d_api/src/im2d.cpp:869`.

Fresh RED transcript excerpts:

```text
FAIL default accepted on fresh thread: expected 1, got -4
FAIL reset explicit core to default: expected 1, got -4
-- Candidate C: scheduler default is legitimate input: 5 assertions --
candidate-c: 5 assertions, 2 failures
Candidate C: exit=1; evidence=test-results/candidate-c/run.TAC5rk
```

Fresh GREEN:

```text
-- Candidate C: scheduler default is legitimate input: 5 assertions --
candidate-c: 5 assertions, 0 failures
Candidate C: exit=0; evidence=test-results/candidate-c/run.JJCggp
```

**Inherited commit corrected, implementation kept.** The full gate exposed the
old `unit-session` RT-1 assertion still requiring rejection (expected -4, got 1).
Its own comment explicitly reserved flipping to success for this authorized fix.
The C delivery commit therefore includes that exact expectation migration and
its README update; all 85 unit-session assertions and all controls remain.
This correction is kept with C, not hidden in B. `candidate-c` is a green Meson
case linked against the ordinary shared library; neither test is skipped.

#### D — positive-fence ownership on wait error

Mechanism: close the consumed positive fd on the failed wait branch as on the
successful branch; `fence_fd <= 0` rejection and all return statuses stay.
Implementation retained from `9675231`: `im2d_api/src/im2d.cpp:855`.

Fresh RED:

```text
C4: RED (200/200 defect observations)
Candidate D: exit=1; evidence=test-results/candidate-d/run.UdsAq7
```

Fresh GREEN:

```text
C4: NOT-REPRODUCED (0/200 defect observations)
Candidate D: exit=0; evidence=test-results/candidate-d/run.XC2Nj1
```

Both runs include 200 successful-wait controls and the runner verifies exactly
200 injected EIO poll records. No harness polarity or assertion changed. GREEN
means the known leak is no longer reproduced, not that the probe stayed RED and
was marked expected-pass. `candidate-d` (`sync-only`) is a green Meson case;
the other unfixed H6 characterization modes remain opt-in. Inherited commit kept.

#### A — publication and init-failure fd ownership

Mechanism: serialize context discovery, single device open and publication under
the mutex, atomically acquire references, and unwind failed opens in both the
legacy context and the separately owned im2d session.
Implementation retained from `e6d8fcf`: `core/NormalRga.cpp:104` (`NormalRgaOpen`),
`:251` (`RgaInit`), `im2d_api/src/im2d_context.cpp:113` and `:195`.
Atomic builtins preserve the exported refcount integer's type, size and symbol.

Fresh RED:

```text
Candidate A evidence: test-results/candidate-a/run.Km1nUt
hwversion,RgaInit,iterations=1000,failed_calls=1000,start=0,end=1000,growing_rows=1000,verdict=RED
unset,RgaInit,iterations=1000,failed_calls=0,start=0,end=0,growing_rows=0,verdict=NOT-REPRODUCED
hwversion,improcess,iterations=1000,failed_calls=1000,start=0,end=1000,growing_rows=1000,verdict=RED
unset,improcess,iterations=1000,failed_calls=0,start=1,end=1,growing_rows=0,verdict=NOT-REPRODUCED
Candidate A: exit=1; per-process evidence in test-results/candidate-a/run.Km1nUt
```

All 20 `direct-init` rows in `races.csv` are `exit=66,tsan_report=1`;
all 40 C-init/singleton controls are `exit=0,tsan_report=0`.

Fresh GREEN:

```text
Candidate A evidence: test-results/candidate-a/run.HPHsmg
hwversion,RgaInit,iterations=1000,failed_calls=1000,start=0,end=0,growing_rows=0,verdict=NOT-REPRODUCED
unset,RgaInit,iterations=1000,failed_calls=0,start=0,end=0,growing_rows=0,verdict=NOT-REPRODUCED
hwversion,improcess,iterations=1000,failed_calls=1000,start=0,end=0,growing_rows=0,verdict=NOT-REPRODUCED
unset,improcess,iterations=1000,failed_calls=0,start=1,end=1,growing_rows=0,verdict=NOT-REPRODUCED
Candidate A: exit=0; per-process evidence in test-results/candidate-a/run.HPHsmg
```

All 60 race/control rows are `exit=0,tsan_report=0`. Failure injection still makes
all 1000 calls per API fail: GREEN is fd cleanup, not a fault that stopped firing.
Inherited commit kept. Direct-init and both failure censuses are green Meson
cases; long batches remain explicit QA. The earlier lane's two 200-process batches
are preserved in its fragment, not claimed as independently repeated here.

#### B — teardown

The fresh RED/GREEN transcripts, ownership distinction, implementation and baseline
disposition are in [wave-e-b.md](wave-e-b.md). The inherited B lifetime mechanism
was retained after validation. Only unfinished surrounding evidence/build wiring
and corrupted documentation/generator text needed completion.

#### Host gate

```sh
meson test -C build-qa --print-errorlogs
bash packaging/package-contract.sh
ASAN_OPTIONS=detect_leaks=1:verify_asan_link_order=0:abort_on_error=1 \
  UBSAN_OPTIONS=print_stacktrace=1:halt_on_error=1 \
  meson test -C build-asan --print-errorlogs \
  unit-pure unit-session shim-contract goldens \
  candidate-a-fds-RgaInit candidate-a-fds-improcess candidate-c candidate-d \
  candidate-b-deinit candidate-b-exit candidate-b-refcount candidate-a-init
TSAN_OPTIONS=halt_on_error=1:exitcode=66:symbolize=0 \
  meson test -C build-tsan --print-errorlogs --suite concurrency
QEMU_LD_PREFIX=/usr/aarch64-linux-gnu meson setup test-results/wave-e-cross \
  --cross-file tests/uapi-parity/aarch64.cross -Dlibrga_demo=false
QEMU_LD_PREFIX=/usr/aarch64-linux-gnu \
  meson test -C test-results/wave-e-cross --print-errorlogs --suite uapi
```

| Gate | Result |
|---|---|
| Native host | 24/24 OK, no skips: all former 16 baseline cases plus 8 regressions |
| ASan/UBSan/LSan host | 19/19 OK: all former 11 baseline cases plus 8 regressions |
| TSan concurrency | 4/4 OK, including owned-reference control |
| aarch64 UAPI under QEMU | 2/2 OK; 21 ioctls, 29 sizes, 170 offsets |
| Static package contract | OK; no version/SONAME/visibility/packaging edits |

Native, ASan and TSan testlogs are in their build directories' `meson-logs/`;
the cross testlog is under `test-results/wave-e-cross/meson-logs/`. The aarch64
record is restored by the cross test after native smoke. The pre-existing corrupt
`build-parity/` is untouched; the new cross build has its own output directory.
This gate does not claim a built .deb, staged package contract, a Debian arm64
release matrix or a board drill. The out-of-scope `rga_osd_info` exception is unchanged.

#### ABI and export closure — fail closed against R0

Published baseline: GitHub release `1.10.1+ceralive.1`, target commit
`f4c3ee62ab354c2cbe22718f543fc0ba6e58365c`.
Downloaded `librga2-ceralive_1.10.1+ceralive.1_arm64.deb`; its published sidecar
verified SHA-256 `7c59bade43e2f8bb4c31e0ae965bee480128aa128528fdc88e8bc082e98ec498`.
R0 is the actual stripped release ELF, not a locally substituted baseline.

Both pre-fix and fixed R1 ELFs were built with the same aarch64 GCC 16.1.0
cross file and debug configuration. For each ELF:

```sh
nm -D --defined-only --format=posix <library> | cut -d ' ' -f1 | LC_ALL=C sort -u
```

`comm -23` gives **0 removed exports vs pre-fix R1**, but **21 missing vs R0**.
The R0-minus-R1 list is byte-identical before and after Wave E. Eighteen entries
are librga internals already named in `packaging/baseline-symbols-upstream-delta.txt`;
three are compiler-emitted C++ symbols. No entry is ignored by this strict check.

Unfiltered `abidiff` 2.6.0:

```text
R0 -> fixed R1:
Functions changes summary: 0 Removed, 0 Changed, 325 Added functions
Variables changes summary: 0 Removed, 0 Changed, 1 Added variable
Function symbols changes summary: 19 Removed, 16 Added function symbols not referenced by debug info
Variable symbols changes summary: 2 Removed, 2 Added variable symbols not referenced by debug info
R0_ABIDIFF_EXIT=12

pre-fix R1 -> fixed R1:
Functions changes summary: 0 Removed, 0 Changed, 2 Added functions
Variables changes summary: 0 Removed, 0 Changed, 0 Added variable
Function symbols changes summary: 0 Removed, 0 Added function symbol not referenced by debug info
Variable symbols changes summary: 0 Removed, 2 Added variable symbols not referenced by debug info
R1_BASE_ABIDIFF_EXIT=4
```

Exit 4 here is additive change only; exit 12 includes incompatible change. The
added R1 symbols are the new private singleton lock accessor, emitted mutex
constructor and its local-static storage/guard. R0 has no DWARF, so its zero
changed-function count does **not** establish public-struct ABI equivalence.
No suppression or `--no-unreferenced-symbols` option was used. Logs and symbol
lists are `test-results/wave-e-abi-summary.log`, `wave-e-r0-abidiff.log`,
`wave-e-missing-r0.txt`, `wave-e-base-missing-r0.txt` and `wave-e-missing-base.txt`.

The existing package checker permits a recorded upstream delta against Radxa;
that is not the user's stricter published-R0 superset requirement. Wave E causes
no removals, but **R1 release ABI closure is not green**. Restoring those exports
or changing that policy requires a separate owner decision, not an unrelated
fifth fix smuggled into this series.

#### Generated-file provenance

The inherited pending generator contained malformed duplicate awk/shell text,
and its test had a duplicated, unterminated Python assertion. Those edits were
not a legitimate merge repair and were removed. The only intentional generator
change now migrates the stale introduction from upstream characterization to
historical-plus-fix evidence. Its fixture test verifies migration, idempotency,
unchanged fragments, one continuous D21 table and malformed-row rejection.

The inherited hand-edited introduction is not accepted as provenance: the new
generator reconstructs it itself. No rows or appendices are hand-merged.
After all fragments are written, run `bash scripts/wire-bootstrap.sh` twice;
compare complete file contents and record the ledger SHA-256 outside the ledger
(putting its own hash inside it would be self-referential). The PR carries the
hash and equality result. The Meson test registrations are also generated,
not edited in their assembled region. Independent reviewer approval is pending.
