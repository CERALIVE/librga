# R0 infrastructure recovery into R1 [PARTIAL]

Audit boundary: R0 `90f5ff2289b81baa72c664bf4f5b0363a33f8e04`, R1 integration
`4d61f022309cb31695c045394f06fdec52ca1913`, combined candidate
`3aff921dcb5773579116781c41839b38178518c8` (draft PR #15). Recovery is stacked
on that combined candidate, not pushed into it. No production fix, release,
hardware run, R0 modification, rebase or squash is part of this work.

Follow-on infrastructure: the [qualification identity gate](QUALIFICATION-IDENTITY.md)
extends the recovered isolated drill with package-bound receipts and a mandatory
publication cross-check. It does not retroactively qualify the historical R1
candidate or replace any measurement in this recovery record.

## Complete commit disposition

The range contains 43 commits, including three merges. Each non-merge delta was
examined; each merge's tree equals its second parent's tree. The first fourteen
are individually patch-equivalent to the bootstrap originals named below
(`git cherry` reports `-`), despite having no shared CeraLive ancestry.
PORT means missing reusable content; ADAPT means only the identified reusable
part is recovered. Neither designation transfers an old hardware receipt.

| R0 commit | Verdict | Reason / R1 disposition |
|---|---|---|
| `00e7471` provenance and licence census | SKIP (superseded) | Patch-equivalent to R1 ancestor `262d55a`; census and provenance already present. |
| `fc9cef8` repository contracts and ledger | SKIP (superseded) | Patch-equivalent to `14526b7`; preserve R1's evolved contracts/ledger. |
| `28f2d10` packaging and symbol floor | SKIP (superseded) | Patch-equivalent to `5fdd9ea`; R1 additionally has matched ABI and exact dynsym gates. |
| `133feb1` CI and two-asset publication | SKIP (superseded) | Patch-equivalent to `9f305b8`; retain the newer required R1 workflow. |
| `5d0f8c3` island UAPI parity | SKIP (superseded) | Patch-equivalent to `6145311`; R1 retains its Gaussian measurements. |
| `31e3d7e` shim and byte goldens | SKIP (superseded) | Patch-equivalent to `46e305e`; R1 has these plus later fault controls. |
| `f6ec975` issue-only upstream watch | SKIP (superseded) | Patch-equivalent to `5610f22`; watch already exists. |
| `41a3ccb` pure/session unit tests | SKIP (superseded) | Patch-equivalent to `9283b5e`; retain full R1 API coverage. |
| `e927f19` board bench, oracle and timing | SKIP (superseded) | Patch-equivalent to `1937ba1`; original infrastructure exists, later repairs do not. |
| `a74ab9a` README attribution | SKIP (superseded) | Patch-equivalent to `0bd524a`; dedicated DEP-5 stanza exists. |
| `ac9de4e` two-suite group gates | SKIP (superseded) | Patch-equivalent to `6bbf94a`; current workflow already gates both suites. |
| `00092bb` QEMU invalid-fd limitation | SKIP (superseded) | Patch-equivalent to `21a1c92`; keep existing opt-in boundary/native coverage. |
| `4bbb2b1` bootstrap wiring | SKIP (superseded) | Patch-equivalent to `72c02e8`; preserve newer fragment/ledger assembly. |
| `e50cdec` Meson name normalization | SKIP (superseded) | Patch-equivalent to `6fac456`; slash/colon normalization already tested. |
| `1471631` R0 header-version guards | SKIP (R0-specific) | R1 has the APIs; importing guards would suppress its resolution assertions. |
| `e922c2d` pre-Gaussian layout | SKIP (R0-specific) | Its Gaussian omissions/reserved-byte differences do not describe R1. |
| `26edc0f` shared-library golden client | PORT | Missing dynamic target; static instrumented goldens cannot select a different provider. |
| `d029a07` R0 package version | SKIP (R0-specific) | Do not set an R1 candidate to the R0 release version. |
| `a006ba4` R0 adaptations/neutrality | SKIP (R0-specific) | Artifact identities, API guards and acceptance findings belong to R0. |
| `9637e28` G8 struct-offset note | SKIP (R0-specific) | Historical R0 layout measurement, not R1 evidence; current UAPI emitters and recovered padding probe measure the layout afresh. |
| `0484799` bounded drill and rollback | ADAPT | Recover routing, matrix and soak modes/scoring; use process-local providers instead of forbidden sysext APT swaps. |
| `4bb862f` blocked G-A/restoration receipt | SKIP (R0-specific) | Historical board addresses, package hashes and restoration evidence cannot qualify R1. |
| `772f9ec` session-before-fd census | ADAPT | R1 needs both legacy context and its separate lazy im2d session warmed before strict census. |
| `2f6033e` cross-release conversion logs | PORT | Recover both success markers, both debug categories and negative controls. |
| `33f774c` CSC padding investigation | ADAPT | Recover the actual aarch64 stack-poison diagnostic hidden in this docs-titled commit; do not import R0 acceptance or receipts. |
| `b267570` both-board rotation rerun | SKIP (R0-specific) | Changes only the old board receipt; keep missing-rotation rejection in the recovered scorer. |
| `386f40c` R0 release block | SKIP (R0-specific) | R0 status/receipt update, not infrastructure. |
| `a04a082` one-hour soak deadline | ADAPT | Preserve 3600 seconds and additionally reject zero work/early iteration-cap completion. |
| `1a05788` soak wrapper timeout | ADAPT | Preserve 3605-second process and 3700-second transport bounds in isolated R1 drill. |
| `4c0f96b` one-hour harness description | ADAPT | Describe recovered R1 mechanics, without copying R0 release-block prose. |
| `fb5b997` genuine R6 soak receipt | ADAPT | Recover README duration correction only; its measured R0 soak is not R1 evidence. |
| `318298f` non-vacuous analyzer | ADAPT | Keep R1 Meson/object discovery and #14 controls; recover missing live capability probe and fail-closed completion summary. |
| `f09da93` no packaged static archive | PORT | R1 README still falsely promises a static archive; packaging already forbids it. |
| `037e208` amended R0 neutrality | SKIP (R0-specific) | No R0 padding masks, weak-symbol exceptions or artifact-specific acceptance recipes become R1 gates. |
| `fa31d8c` R0 acceptance review | SKIP (R0-specific) | Review belongs to the exact R0 artifact/contract. |
| `0967154` required summary context | SKIP (superseded) | R1 has the same named summary with stricter result and docs-only gating controls. |
| `f4c3ee6` merge PR #2 | SKIP (R0-specific) | R0 assembly merge; tree equals reviewed second parent `0967154`. |
| `aa38f42` merged R0 review head | SKIP (R0-specific) | Historical review receipt, not reusable code. |
| `86b9179` merge PR #6 | SKIP (R0-specific) | Receipt-only merge; tree equals second parent `aa38f42`. |
| `0b03e73` R0 YUV blend limitation | SKIP (R0-specific) | Public documentation of released R0 belongs on its release branch. |
| `dbcbf9f` R0 limitation links | SKIP (R0-specific) | R0 user/status documentation, not R1 harnesses. |
| `28a35bc` R0 release/limitation truth | SKIP (R0-specific) | R0 agent routing/status documentation, not R1 qualification. |
| `90f5ff2` merge PR #16 | SKIP (R0-specific) | R0 limitation merge; tree equals second parent `28a35bc`. |

## Non-negotiable boundaries

R0's G8 padding investigation contains generally useful representation knowledge,
but its nine-byte waiver and measured offsets are not R1 policy. The recovered
probe prints the current layout and compares the entire request without masking.
It is a diagnostic: exit 1 is a finding, not an expected-green test inversion.

The inherited R1 analyzer checks compiler arguments, nonempty objects, nonzero
translation-unit count, extraction errors and triage. Those do not prove that a
compiler wrapper actually honors `-fanalyzer`. Its old always-running summary
also printed zero when no hit file existed. Recovery must retain #14 while
closing both gaps; merely copying R0's inline source-list parser would regress it.

Current R1 qualification prohibits APT management or remounting sysext `/usr`.
Recovered board orchestration therefore selects extracted libraries per process,
preserves timed rows, strict fd equality, exact routing and all nine PSNR cells,
and restores temporary state through the existing LIFO cleanup contract. This is
**not package installation/removal/rollback qualification**. That R0 capability
remains unported as an executable R1 package-swap drill under current policy.

Both-board one-hour soaks, routing/pixel/plugin checks and fresh artifact-specific
acceptance remain outstanding. No R0 transcript becomes R1 evidence. ABI sizes
696/304, the frozen 18-symbol acceptance list, `ci/check-dynsym.py`, SONAME and
disabled packaged LTO are unchanged. No plan checkbox is modified.

## Adaptation and host verification receipt — 2026-09-16

Original author for recovered R0 code: **Andres Cera**. Source SHAs are recorded
in the recovery commits; the 43-row table above identifies the complete scope.
Generated Meson wiring is regenerated from fragments, not hand-maintained.

| Recovered harness | Positive execution | Deliberate RED demonstration |
|---|---|---|
| Shared golden client (`26edc0f`) | Eight 504-byte captures using the actual shared R1 library and fake device; G2 verbatim comparison passes. | Changed request byte and truncated request are rejected; missing shim and injected failed submit return nonzero. |
| Session census (`772f9ec`) | Both warmed sessions give exact fd equality. | Compiled copy without im2d warm-up returns 1; a compiled extra-fd mutation returns 1. |
| Timed bench (`0484799`, `a04a082`) | Actual bench loop runs with virtual clock/in-memory I/O in a separate test binary. | Submitted-work, DMA-sync and pixel-score faults return 1; compiled 295-second deadline and zero-iteration mutations return 1. |
| Isolated drill/scorers (`0484799`, `1a05788`) | Real shell orchestration, scoring and cleanup run through a fake transport. | Wrong counter delta, absent rotation, 295-second receipt, missing conversion, hash mismatch and failed baseline recovery return 1; failed cleanup returns 13. Cleanup always precedes ownership release. |
| Conversion evidence (`2f6033e`) | Both legacy and im2d success messages accepted. | Enable-only, success-plus-failure and empty logs rejected. |
| CSC poison probe (`33f774c`) | Clean fixture writer exits 0; current aarch64 layout printed. | Padding-dependent writer exits 1 and identifies offset 309; tested with cross-compiled aarch64 executables under host QEMU, no device. |
| Analyzer capability/completion (`318298f`) | Real GCC 14.2 analyzes 17 library TUs, with 9 triaged findings and a live null-dereference diagnostic. | A real compiler wrapper silently removing `-fanalyzer` produces objects but the entrypoint returns 1 at the capability check; completion is absent and summary returns 1. #14's compile/zero-object/extraction/triage failures still propagate. |

Native **x86_64 Debian Trixie/GCC 14.2** build and complete Meson suite:
**46/46, zero failures, zero skips**. The unmodified upstream non-aarch64 pointer
casts require the already-established host-only `-Dcpp_args=-fpermissive`; the
first plain host build failed on those inherited casts. No packaged flag was
changed. Native aarch64 additionally registers the CSC diagnostic-control test.
The x86 UAPI run is a smoke test, not a replacement for the arm64 gate; its
generated documentation was restored rather than overwriting the arm64 receipt.

Also passed: existing workflow/result-count controls, 696/304 C/C++ header-size
mutation controls, static package contract and 64-row independent-ledger check.
The isolated container could not resolve the host worktree's Git metadata; the
package checker printed that diagnostic before returning static-contract OK.
No package build, matched arm64 ABI run or new sanitizer claim is inferred from
this host receipt. Those remain the unweakened hosted PR gates.

Changed C and shell files have no LSP **errors**. ShellCheck warning/error checks
pass; existing informational shell-analysis findings are not claimed absent.
Markdown/Meson language servers are unconfigured and YAML server installation
was previously declined; no clean-LSP claim is made for those formats.
Meson compilation and the existing workflow-contract tests validate their
executable surfaces.

Local evidence: `build/recovery-build.log`, `build/meson-logs/testlog.txt`,
`test-results/recovery-analyzer.log`, `test-results/recovery-inert-analyzer.log`.
These are ignored per-run artifacts, not a replacement for hosted exact-head
evidence. This receipt qualifies recovered **infrastructure**, not a board,
release, package swap or the real library's padding behavior.
