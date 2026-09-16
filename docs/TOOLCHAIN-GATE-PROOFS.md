# R1 toolchain gate proofs — 2026-09-16

Scope: host build/toolchain enforcement only, against main `8fcf447` and published
R0 `f4c3ee62ab354c2cbe22718f543fc0ba6e58365c`. The earlier gate promotion landed in
PR #10. This follow-up repairs two fail-open paths and adds recurring mutation
proofs. It changes no library source, public header, symbol allowance, SONAME,
visibility, package version or packaged LTO setting.

## Required checks

The active main/release ruleset requires `Build Check summary`. That summary
depends on change detection, suite resolution, both builds, grouped test results,
analyzer, scoped werror, sanitizers, ABI and reproducibility. None of those jobs
is advisory. Only the unpackaged `mtune-measurement` job remains advisory.

The documentation-exclusion filter uses `predicate-quantifier: 'every'`, with
job-level outputs and no pull-request trigger path filter. There is no positive
OR list under that quantifier. The terminal summary rejects failed, cancelled,
unexpected and non-docs skipped results. It now also rejects an empty result
list and a missing/invalid change verdict.

## Mutation receipts

All exit codes below are from processes, not a verdict string searched in an
otherwise successful log. Scratch mutations were restored; production sources
and headers were never edited.

| Gate | RED | Restore / GREEN | Evidence / recurring command |
|---|---|---|---|
| GCC analyzer, real arm64 GCC 14.2 | Append a null store to `im2d_context.cpp` in an isolated source copy: one untriaged `-Wanalyzer-null-dereference`, runner exit **1** | Restore source: runner **0**, 17 analyzed library TUs, nine hits in three triaged pairs, zero untriaged | `test-results/item47-analyzer/{red,green}.log`; `bash scripts/run-analyzer.sh` |
| Analyzer extraction and execution | Before repair, grep exit **42** became runner **0** and the new regression failed. After repair, grep/sed/sort faults each propagate **42**; compiler error **23**, zero objects **1**, untriaged diagnostic **1** | Restore tools and triage: runner **0**. No diagnostics is also valid **0** | `bash tests/test-analyzer-gate.sh`, required before analysis; its compiler boundary is a fixture, not a real compiler claim |
| Scoped werror, real arm64 GCC 14.2 | Append `#warning item47-werror-mutation` in owned `im2d_context.cpp`: job **1**, `-Werror=cpp` | Restore source: job **0**, 33 TUs with unsuppressed `-Wall -Wextra -Werror` | `test-results/item47-werror/{red,green}.log`; `bash ci/werror-steps.sh` |
| ASan | Substitute a real instrumented heap-overflow executable for `unit-pure`: actual CI test block **1**, heap-buffer-overflow report | Restore saved executable: actual test block **0**, including count guards | `bash tests/test-sanitizer-failures.sh`; `test-results/sanitizer-mutations/asan-{red,green}.log` |
| UBSan | Substitute signed-overflow executable: actual CI test block **1**, signed-integer-overflow report | Restore: actual test block **0** | Same helper; `ubsan-{red,green}.log` |
| TSan | Substitute the built data-race canary for `candidate-a`: actual concurrency block **1**, data-race report | Restore: actual block **0**, six concurrency tests | Same helper; `tsan-{red,green}.log` |
| Public sizes | Increase copied `rga_info` or `im_opt` reserve by eight bytes: **1** at the actual 696/304 assertion, independently in C11 and C++14 | Restore each copied header: compiler **0** | `bash tests/test-abi-layout.sh`, required by ABI and full-build entrypoints |
| ABI/removal set | Hidden public symbol, nineteenth function/data removal, each of 18 stale allowance entries, and incompatible vtable mutation all rejected; vtable remains abidiff **12** after exact deletion rules | Identical/additive fixtures pass; restoring exact accepted candidate passes | `bash tests/test-abi-gate.sh`, inside required ABI job |
| Dynsym/LTO | Real ELF WEAK→GLOBAL, UNIQUE→GLOBAL, type and visibility mutations each exit **1**; bad ELF fails; shipping LTO with drift fails | Exact ELF control and selected non-LTO build pass | `bash tests/test-dynsym-gate.sh`; `test-results/abi/dynsym-*` |
| Required summary | Empty results were **0** before repair. They now fail, as do missing/invalid change verdicts and each required dependency's failure/cancellation/skip/unknown result | Valid success and explicit docs-only skips return **0** | `bash tests/test-build-check-gating.sh`: 12 verdict cases plus 9 × 4 dependency mutations; existing discovery, count and child-exit controls retained |

Sanitizer mutation evidence above was executed on native **amd64** in Debian
Trixie with GCC 14.2. The preceding full sanitizer entrypoint passed 11 baseline
ASan/UBSan tests, six H10 tests and six TSan tests, with zero skips. It is
host-shim evidence, not an arm64/device or hardware sanitizer claim. The same
mutation helper is required after the native arm64 hosted sanitizer job.

The new sanitizer helper runs the test blocks extracted from the real job
script, including its sanitizer options, Meson commands and count guards. It
does not substitute a hand-written approximation of their exit handling.

## Matched-debug ABI and LTO verdict

Fresh `bash ci/abi-steps.sh`, Debian Trixie arm64 under host QEMU, GCC 14.2.0-19,
libabigail 2.6, matched `-g -O2`: **job exit 0**.

| Comparison | Result |
|---|---|
| R0 → R1, LTO off | Raw abidiff **12**; exactly the existing 18 accepted removals; deletion-only reconciliation leaves **4**, without incompatible bit 8 |
| R0 → R1, LTO on | Same exact removal set; reconciled abidiff **4** |
| R1 non-LTO → LTO | abidiff **0**, but dynsym **1**: 315 names on each side, binding metadata differs |
| R1 non-LTO → selected packaging configuration | Exact name/type/binding/visibility equality; empty dynsym diff |

The cumulative report is **not empty**: six function and two variable changes
remain visible after the accepted removals, as documented in
[R1 ABI acceptance](R1-ABI-ACCEPTANCE.md). This is no-incompatible-change under
the frozen policy, not a claim of “zero changed” or universal compatibility.
Both input libraries retain `librga.so.2` and DWARF. The C/C++ assertions enforce
696/304 bytes. The 18-entry allowance and dynsym policy are unchanged.

**LTO is disqualified, not enabled.** The requirement that it must not perturb
the ABI wins over the old plan's enablement wording. `PACKAGED_LTO=false` remains
the readonly selection. No linker, visibility or symbol-policy relaxation was
introduced. An empty abidiff report cannot override failed dynsym equivalence.

## Build boundary and undischarged work

The target arm64 package build and package contract passed locally. The complete
arm64 QEMU build/test attempt returned **2**: `shim-contract` and `board-timing`
hit the documented invalid-fd emulation limitation. All tests ran; no skip or
expectation was added to make this green. Native hosted full-suite results are
needed before merge. Shellcheck error-level validation and workflow actionlint
passed locally.

This change supplies gate hardening and mutation evidence. It does **not**
approve an R1 release, merge, tag, publication/reindex, consumer/image adoption,
two-board G-B rerun, package-install/activation/restoration, or hardware/mtune
performance claim. Reproducibility remains an existing required job, not a new
local two-build receipt here. Version remains **1.10.5+ceralive.1**. The live-APT
row stays blocked; no board operation is part of these commands.
