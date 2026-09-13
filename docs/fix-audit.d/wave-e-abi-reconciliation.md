### Wave-E ABI reconciliation and main merge — 2026-09-13

This amends the interpretation of the earlier 21-symbol result in
[wave-e-verification.md](wave-e-verification.md), not its recorded observations.
The original R1 comparator was a GCC 16.1.0 `-O0` debug build, whereas published
R0 was a Debian GCC/libstdc++ 14.2.0-19 packaging build with effective `-O2`.
That was unsuitable for release export-closure claims involving emitted C++
template/inline symbols. The matched measurement below supersedes that claim.

**Judgement: the matched strict R0 containment failure is inherited, not
introduced by Wave E or our shipping build configuration.** It is exactly the
documented 18 librga exports; the three additional observations were measurement
artifacts. The numeric strict-superset check still fails on those 18. They are
not suppressed or relabelled as present, and this note grants no release waiver.

#### Exact residual set

Both inputs were sorted uniquely with `LC_ALL=C`: the original R0-minus-R1
21-name measurement and the first tab-separated field of each of the 18
non-comment rows in `packaging/baseline-symbols-upstream-delta.txt`.
Their `comm -23` result is exactly:

```text
_ZNKSt5ctypeIcE8do_widenEc
_ZNSt10_HashtableIjSt4pairIKjjESaIS2_ENSt8__detail10_Select1stESt8equal_toIjESt4hashIjENS4_18_Mod_range_hashingENS4_20_Default_ranged_hashENS4_20_Prime_rehash_policyENS4_17_Hashtable_traitsILb0ELb0ELb1EEEE5clearEv
_ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEE15_M_replace_coldEPcmPKcmm
```

| Residual (demangled shorthand) | Determination | Controlled evidence |
|---|---|---|
| `std::ctype<char>::do_widen(char) const` | **(c), optimization-dependent emission in unlike builds** | Absent from GCC 16 `-O0`, present at `-O2` with the same GCC 16 cross toolchain and sources. Absent from GCC 14 debug, present in GCC 14 shipping configuration. |
| Named `std::_Hashtable<...>::clear()` specialization | **(c), compiler/libstdc++ mismatch** | Present with GCC/libstdc++ 14 at both `-O0` and shipping `-O2`; absent with GCC/libstdc++ 16 at both `-O0` and `-O2`. No librga source change between these builds. |
| `std::__cxx11::basic_string<char,...>::_M_replace_cold(char*, unsigned long, char const*, unsigned long, unsigned long)` | **(c), optimization-dependent emission in unlike builds** | Absent from GCC 16 `-O0`, present at `-O2` with the same GCC 16 cross toolchain and sources. Absent from GCC 14 debug, present in GCC 14 shipping configuration. |

All three are `FUNC WEAK DEFAULT` exports in the matched R1 shipping ELF. None
was added to an exception list: all three really are present in the dynamic
symbol table of the shipping-configuration build.

| Same fixed R1 sources, build configuration | `do_widen` | `clear` | `_M_replace_cold` |
|---|---|---|---|
| GCC/libstdc++ 14.2.0-19, debug `-O0` | absent | present | absent |
| GCC/libstdc++ 14.2.0-19, shipping effective `-O2` | present | present | present |
| GCC/libstdc++ 16.1.0, debug `-O0` (original comparator) | absent | absent | absent |
| GCC/libstdc++ 16.1.0, `debugoptimized` `-O2` | present | absent | present |

The last row has other compiler-emission differences outside the original three;
it is an isolation control, not a release artifact or substitute gate. These
observations do not attribute any removal to a Rockchip upstream commit: there
was no librga-source toggle in the matrix. No (a) documentation correction or
(b) shipping-build fix is warranted for these residuals.

Two other possible measurement causes were tested and refuted:

- `strip --strip-unneeded` on the original R1 ELF leaves its **entire** dynamic
  export set byte-identical. DWARF stripping is not what removed the three names.
- `nm -D --defined-only` and `readelf --dyn-syms --wide` (defined GLOBAL/WEAK/UNIQUE
  entries) produce exactly the same sorted export set. This is not a tool or
  truncated-name disagreement.

#### Build-configuration delta and matched control

Published R0 is release
[`1.10.1+ceralive.1`](https://github.com/CERALIVE/librga/releases/tag/1.10.1%2Bceralive.1),
commit `f4c3ee62ab354c2cbe22718f543fc0ba6e58365c`, published by
[run 34735552582](https://github.com/CERALIVE/librga/actions/runs/34735552582).
Its downloaded runtime package's published checksum was verified:
`7c59bade43e2f8bb4c31e0ae965bee480128aa128528fdc88e8bc082e98ec498`.

| Property | Published R0 / matched R1 packaging | Original R1 comparator |
|---|---|---|
| Compiler and C++ headers | Debian GCC/libstdc++ 14.2.0-19 | cross GCC/libstdc++ 16.1.0 |
| Target | aarch64, Debian Trixie | aarch64 cross build on the development host |
| Meson | 1.7.0, `--buildtype=release` | 1.12.0, debug/default build |
| Effective optimization | `-O2`: Debian CXXFLAGS follow Meson's `-O3` | `-O0` |
| Language/platform | C++14, `LINUX=1`, shared PIC, pthread | same |
| Hardening | stack protector, stack-clash protection, BTI/PAC, FORTIFY 3, full RELRO/bind-now | no Debian packaging hardening flag set |
| Build metadata | source/build prefix maps; packaged-input SOURCE_DATE_EPOCH | ordinary debug paths; no packaging epoch normalization |
| ELF used | stripped staged runtime; `.note` retained | unstripped build-tree ELF with DWARF |
| Visibility/LTO/GC | no visibility restriction, version script, LTO or section-GC change | none introduced here either |

`packaging/build-deb.sh` and `ci/target-suite.env` are byte-identical between the
R0 release and pre-merge R1. No packaging option was edited for this reconciliation.
The matched local builds used arm64 container image
`ad30acd806a1415904846a69cc4426c67386c2af21aef2f698bc2328cdbdf2da`:
this is the locally cached `gstrk-trixie-arm64` image, **not claimed to be the
original release container digest**. Measured tools/packages are GCC and
libstdc++ 14.2.0-19, binutils 2.44-3, libc6 2.41-12+deb13u3, Meson 1.7.0 and
Ninja 1.12.1. Package builds use the unmodified packaging script. The actual
recorded library compile command ends with Debian's `-g -O2` and hardening flags
after Meson's `-O3`; calling it an `-O3` comparison would be incorrect.

As a control on that local environment, R0 was rebuilt from its exact published
tag using the same container and packaging script. Its complete sorted dynamic
export set is **identical to the published R0 ELF**, including weak symbols.
The rebuilt archive hash differs (`a1774e08cefa7a77847f9bcc9e5d7fcbf9f45c4b88801f07bd59748383a076b2`);
this is an export-method control, **not** a byte-reproducible release claim.
Published R0 remains the authority used by the corrected containment/abidiff.

#### Corrected release-configuration results

```text
published R0 -> fixed R1 packaging ELF:
missing dynamic exports: 18
missing minus documented upstream delta: 0
documented upstream delta minus missing: 0
abidiff 2.6.0:
Function symbols changes summary: 16 Removed, 56 Added function symbols not referenced by debug info
Variable symbols changes summary: 2 Removed, 3 Added variable symbols not referenced by debug info
PUBLISHED_R0_ABIDIFF_EXIT=12

pre-Wave-E R1 (1bde9018) -> fixed R1, both packaging configuration:
missing dynamic exports: 0
abidiff 2.6.0 (unstripped counterparts for DWARF):
Functions changes summary: 0 Removed, 0 Changed, 1 Added function
Variables changes summary: 0 Removed, 0 Changed, 0 Added variable
Function symbols changes summary: 0 Removed, 0 Added function symbol not referenced by debug info
Variable symbols changes summary: 0 Removed, 2 Added variable symbols not referenced by debug info
PRE_WAVE_E_ABIDIFF_EXIT=4
```

The pre-Wave-E control was built from exactly `1bde9018` with the same packaging
script/toolchain. The additions are the singleton lock accessor and its static
storage/guard. No suppression, weakened symbol filter, or
`--no-unreferenced-symbols` was used. The 18-name allowlist and its 2+4+2+10
accounting remain unchanged because the corrected measurement agrees exactly.
R0 has no DWARF, so public-struct equivalence across R0/R1 is not inferred from
these symbol-only observations. Release authorization remains an owner decision.

Evidence is under `test-results/abi-reconcile/`: `r0.nm`, `r0-rebuilt.nm`,
`missing21.txt`, `documented18.txt`, the four `r1-*.nm` matrix files,
`r1-release14-missing.txt`, `wave-e-release14-removals.txt`,
`release14-environment-dynsym.log`, `shipping-abidiff.log`, each build's log and
its `compile_commands.json`. `r1-base-source/` and `r0-source/` are isolated
repo-local checkouts for the two controls, not build-time repository dependencies.

#### Conflict resolution

Merge parents: R1 `0a6a9bb76267a0157c7e7541decafdde60322a0a` and main
`dbc388f98e8145ad4a8e3efd84924c0b115c9ea7`. The only conflicted file was
`.github/workflows/build-check.yml`. Main added job-level documentation gating
and the terminal summary around the old sanitizer placeholder; R1 had replaced
that placeholder with the real target-suite arm64 sanitizer job and its summary.

The merge keeps R1's real `ci/sanitizers-steps.sh` execution, arm64 runner,
target-suite container and honest host-only summary, while adding main's
`changes` dependency/condition alongside `resolve-suite`. Main's terminal
`build-check-summary` stays and watches every failure-bearing prerequisite.
It rejects failures/cancellations, and permits skipped jobs only when change
detection explicitly returned `code=false`; this avoids a silently skipped code
lane passing green. The advisory analyzer remains advisory.

`tests/test-build-check-gating.sh` checks the actual merged workflow and executes
its summary shell block across seven success/skip/failure/cancellation cases.
`ci/build-check-steps.sh` runs that contract before its static package contract.
No library, public-header, reproducer, unit-test, golden or Meson-registration
hunk changes relative to the four-fix head. No rebase or squash is used.
The ledger was not conflicted; this new evidence fragment is assembled by
`scripts/wire-bootstrap.sh`, never by editing the generated ledger.

#### Post-resolution gate

Run after resolving the workflow, with the merge still uncommitted:

```text
actionlint .github/workflows/build-check.yml: exit 0
tests/test-build-check-gating.sh: 7/7 PASS
native Meson baseline: 24/24 OK
static package contract: OK
rebuilt ASan/UBSan/LSan Meson baseline: 19/19 OK
rebuilt TSan concurrency suite: 4/4 OK
aarch64 UAPI under QEMU: 2/2 OK
shipping-configuration static + staged package contract (arm64 Trixie): OK
shipping ELF ABI floors (GLIBC/GLIBCXX/CXXABI): OK
```

No existing test was skipped or weakened. The two sanitizer trees were rebuilt
with `scripts/build-sanitized.sh`; `run-candidate-a.sh` and
`run-candidate-d.sh` also returned 0, checking their preloaded sanitizer canaries.
The ASan canary transcript contains both its heap-buffer-overflow and the intended
UBSan signed-overflow report. New raw runs: `test-results/candidate-a/run.2z9NlO`
and `test-results/candidate-d/run.L4Qwgi`. Testlogs are in `build-qa/`, `build-asan/`
and `build-tsan/` under `meson-logs/`; the cross testlog is under
`test-results/abi-reconcile/gate-cross/meson-logs/`. The cross run restores the
canonical aarch64 `docs/UAPI-PARITY.md` after the native smoke test.

Changed shell files have clean error-level LSP diagnostics. YAML LSP is not
installed and installation was previously declined; `actionlint` validates the
workflow instead. This is host/shim/emulation evidence, not a board acceptance run.

An extra host-side staged-check attempt produced a false stack-protector failure:
the ELF does import `__stack_chk_fail@GLIBC_2.17`, but the check's
`nm ... | grep -q` pipeline returned `PIPESTATUS=141 0` under host binutils 2.47.
The consumer matched then closed the pipe; the producer received SIGPIPE under
`pipefail`. Running the unchanged staged contract in its intended arm64 Trixie
environment passed, as did the independent ABI-floor check. This is a host-checker
portability finding, not lost hardening, and no assertion was bypassed or edited.
The staged checker uses its existing 18-name allowance; the independent unfiltered
containment/abidiff above, not that allowance, establishes the inherited result.

After recording these results, regenerate the ledger twice and compare ledger
and Meson hashes. The final hash is recorded in PR #7, not self-referentially
inside this generated ledger. Keep the PR draft and unmerged for owner-dispatched
independent review; this follow-up resolves the residual classification and
content conflict without granting a strict-superset exception or release approval.
