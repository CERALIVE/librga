| Wave-E C; `63d60a317fe2f121356e18b445d92dc6403d8a42` | `tests/repro/run-candidate-c.sh`: independently rerun RED on `1bde9018`, GREEN on reviewed head `7b832a02`; 2/5 failures -> 0/5 | host-shim-only; hardware gates remain open | Matched pre-fix R1 -> head: 312 -> 315 exports, 0 removals, abidiff 4 additions only; strict R0 superset STILL FAILS on 18 inherited removals, abidiff 12 | APPROVE — independent reviewer `openai/gpt-6-astra`, dispatch `ses_f62dc01d3ffeHjGpEFKZ4zGBu0`; Wave-E repairs only, NOT R1 release approval | Downstream-only; this receipt makes no upstream submission |
| Wave-E D; `59f3e83521aaddce5a5309ba764ff47b35c042b4` | `tests/repro/run-candidate-d.sh`: independently rerun RED on `1bde9018`, GREEN on reviewed head `7b832a02`; 200/200 retained wait-error fences -> 0/200, success controls intact | host-shim-only; hardware gates remain open | Matched pre-fix R1 -> head: 312 -> 315 exports, 0 removals, abidiff 4 additions only; strict R0 superset STILL FAILS on 18 inherited removals, abidiff 12 | APPROVE — independent reviewer `openai/gpt-6-astra`, dispatch `ses_f62dc01d3ffeHjGpEFKZ4zGBu0`; Wave-E repairs only, NOT R1 release approval | Downstream-only; this receipt makes no upstream submission |
| Wave-E A; `d280ee104eacc60a5ba0ab2d4d92f64b7b688360` | `tests/repro/run-candidate-a.sh`: independently rerun RED on `1bde9018`, GREEN on reviewed head `7b832a02`; 20/20 direct-init TSan reports -> 0/20, both 1000-call fd-growth cases -> flat | host-shim-only; hardware gates remain open | Matched pre-fix R1 -> head: 312 -> 315 exports, 0 removals, abidiff 4 additions only; strict R0 superset STILL FAILS on 18 inherited removals, abidiff 12 | APPROVE — independent reviewer `openai/gpt-6-astra`, dispatch `ses_f62dc01d3ffeHjGpEFKZ4zGBu0`; Wave-E repairs only, NOT R1 release approval | Downstream-only; this receipt makes no upstream submission |
| Wave-E B; `0a6a9bb76267a0157c7e7541decafdde60322a0a` | `tests/repro/run-candidate-b.sh`: independently rerun RED on `1bde9018`, GREEN on reviewed head `7b832a02`; final batch 800/800 scenario processes plus both owned-reference controls; timeout and ENOSPC attempts excluded, details below | host-shim-only; hardware gates remain open | Matched pre-fix R1 -> head: 312 -> 315 exports, 0 removals, abidiff 4 additions only; strict R0 superset STILL FAILS on 18 inherited removals, abidiff 12 | APPROVE — independent reviewer `openai/gpt-6-astra`, dispatch `ses_f62dc01d3ffeHjGpEFKZ4zGBu0`; Wave-E repairs only, NOT R1 release approval | Downstream-only; this receipt makes no upstream submission |

### Wave-E independent-review receipt — 2026-09-13

**Verdict: APPROVE. Approval covers the Wave-E repairs only — it is NOT approval
to release R1.** Independent reviewer: `openai/gpt-6-astra`, not the implementing
agent. Reviewer dispatch session id: `ses_f62dc01d3ffeHjGpEFKZ4zGBu0`, supplied
by the orchestrator rather than inferred from the reviewer's environment.

Reviewed head: `7b832a02ec8beb6b473bf58a0401b23b5f7687f9`,
[PR #7](https://github.com/CERALIVE/librga/pull/7), against pre-fix R1
`1bde9018d28092879978419f8e48f2b88debcbaa`. The four rows above associate that
review with each repair's actual commit. They supersede the pending-review status
in the earlier Wave-E fragments for this reviewed head; historical observations
and source fragments remain unchanged.

This receipt transcribes the independent review's `REPORT.md`; its preserved
`head.tar.gz`, `base.tar.gz` and `r0.tar.gz` contain source, builds, ELFs and logs.
Evidence names below refer to `test-results/review-pr7/` in that archived head,
not to a new ABI experiment or a new 800-process run performed to record this
receipt. The report and archives remain in the orchestrator's evidence custody;
no build or test depends on their location.

#### Independently reproduced ABI control and residual classification

The reviewer rebuilt R0 from release tag `1.10.1+ceralive.1`, resolving to
`f4c3ee62ab354c2cbe22718f543fc0ba6e58365c`, with the **unmodified**
`packaging/build-deb.sh`. The packaging script and `ci/target-suite.env` are
byte-identical between that tag and the reviewed head. The independently cached
arm64 Debian Trixie container used GCC/libstdc++ **14.2.0-19**, binutils
**2.44-3**, libc6 **2.41-12+deb13u3**, Meson **1.7.0** and Ninja **1.12.1**.
Effective optimization was **O2**: Debian's `-g -O2` followed Meson's `-O3`.

```text
Published R0: 274 dynamic exports
Rebuilt R0:  274 dynamic exports
diff -u published-r0.nm rebuilt-r0.nm: empty, exit 0
```

The published package's verified SHA-256 was
`7c59bade43e2f8bb4c31e0ae965bee480128aa128528fdc88e8bc082e98ec498`.
Both control ELFs were stripped; their build IDs differed. This validates the
**comparison method**, including weak exports, explicitly **not byte-identical
package reproducibility**. Published R0 remains the release-comparison authority.

All three residual symbols from the earlier unlike-toolchain comparison are
**(c) measurement artifact**, not librga declarations or additional upstream
removals. The reviewer independently reproduced the GCC14/GCC16.1 x O0/O2
emission matrix and resolved each definition with `addr2line` into GCC 14's own
standard-library headers:

| Residual (demangled shorthand) | `addr2line` definition | Dynamic-symbol attributes |
|---|---|---|
| `std::ctype<char>::do_widen(char) const` | `/usr/include/c++/14/bits/locale_facets.h:1092` | `FUNC WEAK DEFAULT` |
| Named `std::_Hashtable<...>::clear()` specialization | `/usr/include/c++/14/bits/hashtable.h:2584` | `FUNC WEAK DEFAULT` |
| `std::__cxx11::basic_string<char,...>::_M_replace_cold(...)` | `/usr/include/c++/14/bits/basic_string.tcc:479` | `FUNC WEAK DEFAULT` |

All three are present in the matched shipping-configuration R1 ELF. No symbol
was suppressed; `nm` and defined GLOBAL/WEAK/UNIQUE `readelf` export sets agree,
as do stripped and unstripped head sets. No visibility, LTO, section-GC or
version-script change was used. The full mangled set and configuration matrix
remain in [wave-e-abi-reconciliation.md](wave-e-abi-reconciliation.md).

Matched pre-fix R1 versus reviewed head: **312 -> 315 exports, 0 removals,
3 additions** — `Singleton<RockchipRga>::instanceLock()`, its local pointer
storage and guard variable. Unfiltered `abidiff` 2.6.0 on the matched unstripped
DWARF ELFs exited **4**, additions only: 0 removed/0 changed functions, 1 added
function and 2 added variable symbols not referenced by debug info. SONAME
**`librga.so.2`** was retained on all six built ELFs.

**Strict R0 superset containment STILL FAILS on the 18 documented inherited
upstream removals (`abidiff` exit 12). This is not a Wave-E regression. It is
not waived, not relabelled, and remains an open R1 release blocker. This receipt
records that blocker; it does not resolve it.** The missing set exactly matches
`packaging/baseline-symbols-upstream-delta.txt`. Published stripped R0 versus
stripped head reports 16 removed/56 added function symbols and 2 removed/3 added
variable symbols. R0 has no DWARF; symbol-only comparison does not prove R0/R1
public-struct equivalence. Evidence: `abi-results.log`, `abidiff.log`, the `.nm`
sets and recorded compile/link commands.

#### Four independently rerun RED-to-GREEN reproducers

The reviewer built both sanitizer trees and ran
`tests/repro/run-candidate-{a,b,c,d}.sh` on both pre-fix R1 and reviewed head.
Native compiler: GCC **16.2.1 20260810**, Meson **1.12.0**, Ninja **1.13.2**;
library sanitizer builds were debug/O0, unstripped, with the documented native
`-fpermissive`. Runtime canaries reported under the selected shim configurations.

| Case | Independently reproduced RED on pre-fix R1 | Independently reproduced result on reviewed head |
|---|---|---|
| C, default scheduler | exit 1; 5 assertions, 2 failures | exit 0; 5 assertions, 0 failures |
| D, failed wait | exit 1; 200/200 retain fence | exit 0; 0/200 retain fence; all 200 success controls still consume fds |
| A, direct init | 20/20 exit 66 with TSan reports | 20/20 exit 0 without reports |
| A, C-init/singleton controls | 20/20 each clean | 20/20 each clean |
| A, hwversion/RgaInit | 1000 failures, fds 0 -> 1000 | 1000 failures, fds 0 -> 0 |
| A, hwversion/improcess | 1000 failures, fds 0 -> 1000 | 1000 failures, fds 0 -> 0 |
| A, successful controls | flat at 0 / warmed 1 | flat at 0 / warmed 1 |
| B, ASan/UBSan deinit | 158/200 findings, 42 clean | 200/200 clean |
| B, ASan/UBSan exit | 200/200 clean | 200/200 clean |
| B, TSan deinit | 200/200 findings | 200/200 clean |
| B, TSan exit | 200/200 findings | 200/200 clean |

The original implementation-run B counts in `wave-e-b.md` describe a different
run; the table above records the reviewer's fresh run. ASan exit was already
clean before the fix; TSan establishes that exit defect. Both owned-reference
controls passed on both revisions, retaining `before=2 after=1 deinit=0
fd_open=1 blit=0`. The race releases a borrowed last reference, not one of two
independently owned references; this is not approval to redefine ordinary
owned-reference release.

**Invalid attempts are retained as failures to complete, not passing evidence.**
The first fixed candidate-B attempt exceeded its outer 120-second tool budget
after the ASan rows. A second hit host **ENOSPC** during TSan exit logging:
`candidate-b-complete.log` records deinit 200 clean, exit 111 clean/89 invalid.
Neither attempt was counted as passing. One invalid-run log was deleted to
recover tool execution and remaining review-owned shim logs were compressed.
Only the complete final batch in `candidate-b-final.log` passed **all 800
scenario processes plus both owned-reference controls**. No timeout, invalid
process, missing log or sanitizer report was scored PASS. The review also
excluded an initial ABI comparison refused for a locale mismatch; final set
comparisons used `LC_ALL=C` consistently.

#### Independently reproduced host gate and scope

| Gate | Reviewer's actual result |
|---|---|
| Native | **24/24 OK**, 0 failed |
| Expanded ASan/UBSan/LSan | **19/19 OK**, 0 failed |
| TSan concurrency | **4/4 OK**, 0 failed |
| aarch64 UAPI under QEMU | **2/2 OK**, 0 failed |
| Static package contract | **PASS** |

These are completed OK results, not skips, ignored failures or expected failures.
Evidence: `gate-native.log`, `gate-asan.log`, `gate-tsan.log`, `gate-cross.log`
and `gate-package.log`. **CI's ASan selector runs the original 11 baseline
cases; the expanded independent review run covered 19. These counts are not
interchangeable.** Native retains all 85 unit-session assertions; no existing
test was deleted, skipped or weakened to reach green.

The reviewer confirmed the preserved eight Wave-D and four candidate merge
graphs and four distinct repair commits, with no rebase or squash. The review
does not satisfy board acceptance, close plan item 43's hardware prerequisite,
erase the recorded items 44/45 ordering finding, authorize a self-merge, or
approve R1 release. PR #7 was **OPEN, draft, unmerged** at review completion;
recording this receipt does not change that disposition. Any eventual merge
belongs to the owner and must preserve the fix-series history, never squash it.
