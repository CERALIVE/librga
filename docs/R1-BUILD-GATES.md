# R1 build and toolchain gates [PARTIAL]

**Historical gate receipt.** The later [reserve repair](R1-ABI-REPAIR.md) restores
the two Linux LP64 public sizes and adds regression checks. The cumulative ABI
gate still fails on the separately classified inherited changes. Counts and
package hashes below belong to the original run, not the repaired candidate.

Scope: librga-fork todo 41 only. **Not ABI-cleared, not board-qualified, not
released.** Todos 42 and 43 were not attempted. No production source, installed
header, default, status/message contract, SONAME or symbol visibility changed.

Base: PR #9 merge `8490d34acd02620e9af76d15e5ebdb88de77511a`.
Candidate branch: `ci/r1-toolchain-gates`.
Authoritative run: [Build Check 34916408610](https://github.com/CERALIVE/librga/actions/runs/34916408610),
code commit `c5e7f09`, 2026-09-15 UTC (2026-09-14 local).
The workflow is **red solely on ABI and its dependent terminal summary**.

## Required gates and execution evidence

The repository ruleset requires `Build Check summary`. Its dependencies include
the analyzer, werror, sanitizers, ABI and reproducibility jobs, alongside both
build suites and their unit/golden/UAPI result checks. Failure or cancellation
always fails the summary; a skipped dependency fails unless change detection
explicitly classified the change as documentation-only.

`tests/test-build-check-gating.sh` executes the actual summary shell with each
of its nine dependencies failed, cancelled and skipped, and rejects every case.
It also exercises the result-count guards with empty, incomplete, skipped and
failed inputs. No Meson registration or C/C++ test TU was added by this task.

| Gate | Final hosted result |
|---|---|
| Bookworm arm64 | 37/37, zero failures/skips |
| Trixie arm64 | 37/37, zero failures/skips; static/staged package contract and ABI floors pass |
| Unit / goldens / UAPI result jobs | All six result jobs pass; eight goldens per suite |
| Werror | 32 TUs; both C/C++ warning canaries reject `unused-variable` |
| Analyzer | 17 analyzed library TUs produce objects; 9 hits, 3 documented pairs, zero untriaged |
| ASan/UBSan baseline | 11/11, with both runtime canaries reporting |
| H10 ASan/UBSan | 6/6; both races complete 2,000 iterations |
| TSan concurrency | 6/6, race canary reports; both H10 races complete 2,000 iterations |
| D21 ledger | 62 reviewed rows, 13 independently approved GREEN fixes, no GAP |
| ABI negative controls | 3/3: identical accepted, additive accepted, hidden public symbol rejected |
| R0→R1 ABI | **FAIL**, `abidiff` exit 12 |
| Reproducibility | **PASS**, two fresh builds, both packages byte-identical |

Sanitizer evidence remains host-shim-only. The existing public-setter RED probes,
OSD limitation, H7 board-dependent result and H4 INCONCLUSIVE result are unchanged.

## ABI blocker — matched DWARF, not an export-count threshold

R0 is published tag `1.10.1+ceralive.1`, checked against release commit
`f4c3ee62ab354c2cbe22718f543fc0ba6e58365c`. R0 and R1 are built in the same
Debian Trixie arm64 container using GCC/libstdc++ 14.2.0-19, Meson 1.7.0,
`--buildtype=debugoptimized`, `-g -O2`, and no LTO. Both unstripped libraries
contain `.debug_info` and retain `librga.so.2`. `abidiff` is 2.6.0.

The gate's invocation is unfiltered:

```sh
abidiff test-results/abi/build-r0/librga.so test-results/abi/build-r1/librga.so
```

No strict numeric R0-superset assertion, new suppression or export allowance was
introduced. The cited R0 `docs/R0-NEUTRALITY.md` exists on the R0 release line,
not R1 main; it documents the historical unfiltered comparison but contains no
copyable invocation. The command above follows todo 41's plain two-library form.

```text
Functions changes summary: 16 Removed, 6 Changed (117 filtered out), 54 Added functions
Variables changes summary: 2 Removed, 2 Changed, 1 Added variables
Function symbols changes summary: 0 Removed, 1 Added function symbol not referenced by debug info
Variable symbols changes summary: 0 Removed, 2 Added variable symbols not referenced by debug info
abidiff exit=12
```

Beyond the already documented inherited internal-symbol removals, DWARF reports
`rga_info` growing from **696 to 704 bytes**, and `im_opt` from **304 to 312
bytes**, with Gaussian members inserted and reserve offsets changed. These are
not weak libstdc++ emission noise, nor the known 21-versus-18 unlike-toolchain
artifact. The independent local arm64 comparison reported the same changes.
This task does not authorize changing these public layouts or suppressing them.

**LTO remains explicitly disabled in packaging.** No LTO adoption or LTO-golden
equivalence is claimed while the prerequisite ABI comparison fails. Ordinary
non-LTO goldens remain unchanged and green. Resolving this ABI result requires
a separately scoped compatibility decision, not a stricter threshold or a
toolchain-only workaround.

## Reproducibility and candidate artifacts

The required reproducibility job ran the existing two-clean-build procedure
with explicit `SOURCE_DATE_EPOCH=1789434806`. Both build directories are wiped
by the builder between runs; SHA-256 comparison and `cmp` both succeed for each
package:

```text
954f5251248aea433e07b00267bdaa3fe4ebbda2867450d8d8ac5c1cce7996b2  librga-ceralive-dev_1.10.5+ceralive.1_arm64.deb
b0ef4256ba7ad15b023f1c45ad0cdba3efddb2f7ee32cadf2e1687212876390a  librga2-ceralive_1.10.5+ceralive.1_arm64.deb
```

This proves fixed-path/fixed-epoch repeatability, not cross-path identity.
The separate `dist` artifact uses the normal packaged-input epoch and build
path, so its hashes are different and are not compared against the above pair:

```text
f1d3f1b3c60faecab44d4ff7bcbff3e75d28d903c848f0d523909e599d2ef510  librga-ceralive-dev_1.10.5+ceralive.1_arm64.deb
b562606b9e0d37f5501574c7a4eb4dc0311e74ba4b441448be245e14f3777c6b  librga2-ceralive_1.10.5+ceralive.1_arm64.deb
```

Both downloaded `dist` package controls report version `1.10.5+ceralive.1` and
architecture `arm64`. These are unqualified CI candidates, not released assets.

## Cortex-A76 — measurement only

The advisory job builds unpackaged variants and records GNU `size` output:

| Variant | text | data | bss | total bytes |
|---|---:|---:|---:|---:|
| Generic GCC 14 `-g -O2` | 227520 | 5440 | 900 | 233860 |
| Same compiler/flags plus `-mtune=cortex-a76` | 226832 | 5440 | 900 | 233172 |

No timing threshold is applied. These are ELF sizes, **not performance results**.
H4 microseconds/frame is **NOT RUN**, because the board gate is out of scope.
The job has `continue-on-error: true`, is excluded from the required summary,
and never invokes packaging. No tuning-adoption decision is made.

## Validation and retained evidence

`actionlint`, workflow-contract controls, and error-level Bash LSP diagnostics
passed. YAML LSP was previously declined; Markdown and extensionless-version
LSP servers are unavailable. No server or persistent Git configuration was added.

The first hosted run, 34915424022, passed the existing gates but the two new
jobs stopped on container checkout ownership before doing work. `c5e7f09` adds
process-only, checkout-scoped Git trust; the final run reaches both real checks.
That first setup failure is not claimed as ABI or reproducibility evidence.

Artifacts on the final run: `abi-evidence` (full report, DWARF libraries and
compile commands), `reproducibility-evidence`, `sanitizer-logs`, `werror-logs`,
`analyzer-log`, `mtune-measurement-only`, suite result JSON and `dist`.
Downloaded copies and complete logs are retained under `test-results/todo41/`.
No PR, merge, tag, release, publication dispatch or board command was performed.
