# R1 inherited symbol removals: accepted with documentation [EXISTS]

## Decision — 2026-09-14

The owner accepts **exactly 16 removed functions and two removed variables** in
R1 relative to published R0 `1.10.1+ceralive.1`
(`f4c3ee62ab354c2cbe22718f543fc0ba6e58365c`). These are inherited upstream
1.10.5 changes, not CeraLive removals. No compatibility shims will be added now.
Maintaining shims for internal symbols with no known callers would create an
ongoing maintenance obligation without an identified beneficiary. The decision
is reversible: if a caller surfaces, a separately reviewed shim can restore its
original contract and the expected-removal list must be deliberately updated.

This supersedes the strict R0-export-superset demand and the restore-all-symbols
disposition in the [historical reserve-repair receipt](R1-ABI-REPAIR.md), for
**these entries only**. It does not authorize a nineteenth removal, a SONAME or
visibility change, or the deletion of legacy/public APIs or other platform trees.
R0's own neutrality contract is unchanged. The two public Linux LP64 sizes remain
locked in C **and** C++: `sizeof(rga_info_t) == 696`, `sizeof(im_opt_t) == 304`.

## Usage evidence and its limits

The 2026-09-14 investigation, **F — Usage of the 16 removed functions and 2
variables**, inspected every entry below. None was ever declared in an installed
public consumer header; declarations in private `core/` or implementation headers
do not make an installed API. No external caller was found in gstreamer-rockchip,
cerastream, another CeraLive package, or indexed public source. Public-source hits
were librga implementations/forks, not identified consuming applications.

The search had a known-positive control: the actual
[`c_RkRgaBlit` call at `gstmpprgabackend.c:79`](https://github.com/CERALIVE/gstreamer-rockchip/blob/main/gst/rockchipmpp/gstmpprgabackend.c#L79)
and `tests/check/rgaconvert.c:29` both matched. Thus the consumer search was not
silently missing all RGA calls. The current streaming path uses `c_RkRgaBlit` and
public RGA operations. No built CeraLive shared objects were available for that
investigation's undefined-symbol inspection; it is source-search evidence, not a
binary census. Package indexes expose SONAME dependencies, not symbol-level
reverse dependencies. These scope limits matter even with a positive control.

**Residual risks are real:** private/unindexed binaries may call an undeclared
entry point and fail at load/link time. In particular, **`int cosa_table[360]`
was writable exported data**, not a harmless constant; `sina_table` had the same
contract. A private consumer may read or write those objects. Restoring that
compatibility would require the original data-object semantics, not merely a
function wrapper or a new read-only table. The import-buffer entry is a **rename**
to `rga_import_buffer_param`, not removal of the capability; an old binary still
cannot resolve the old mangled name. None of these risks is claimed impossible.

## Individual dispositions

Each row is **accepted without a shim** based on its upstream mechanism and the
no-public-header/no-known-caller findings above. The literal ELF identities (not
overload prefixes or regular expressions) and per-entry reasons are committed in
[`packaging/baseline-symbols-upstream-delta.txt`](../packaging/baseline-symbols-upstream-delta.txt).
That same file is consumed by the package contract and the ABI gate.

| Removed R0 symbol | Disposition and justification |
|---|---|
| `NormalRgaInitTables()` | **Accepted.** Runtime table initialization was removed when upstream switched to static constant tables; no public declaration or known caller. |
| `NormalRgaSetBitbltMode(rga_req*, rga_interp, unsigned char, unsigned int, unsigned int, unsigned int, unsigned int)` | **Accepted.** Upstream replaced value interpolation with a pointer parameter; no public declaration or known caller of the old mangled overload. |
| `get_buf_size_by_w_h_f(int,int,int)` | **Accepted.** Upstream made this private sizing helper `static`; no public declaration or known caller. |
| `get_string_by_format(char*,int)` | **Accepted.** Upstream made this private formatting helper `static`; no public declaration or known caller. |
| `rga_check_driver(rga_version_t&)` | **Accepted.** Upstream changed reference to value; internal driver check with no public declaration or known caller. |
| `rga_check_info(const char*,rga_buffer_t,im_rect,int)` | **Accepted.** Upstream replaced the final parameter with `rga_info_resolution_t`; internal check with no public declaration or known caller. |
| `rga_check_rotate(int,rga_info_table_entry&)` | **Accepted.** Upstream changed reference to pointer; internal check with no public declaration or known caller. |
| `rga_get_info(rga_info_table_entry*)` | **Accepted.** Upstream added an initial `rga_hw_versions_t*` parameter; internal helper with no public declaration or known caller. |
| `rga_import_buffer(uint64_t,int,im_handle_param_t*)` | **Accepted rename.** Capability moved to `rga_import_buffer_param`; the separate size-taking overload is not a substitute for the old signature. No public declaration or known caller of the old entry point. |
| `rga_log_level_init()` | **Accepted.** Upstream moved settings resolution into the logging path; internal initializer with no public declaration or known caller. |
| `rga_set_buffer_info(rga_buffer_t,rga_info_t*)` | **Accepted.** Upstream made this implementation helper `static`; no public declaration or known caller. |
| `rga_set_buffer_info(rga_buffer_t,rga_buffer_t,rga_info_t*,rga_info_t*)` | **Accepted.** The second overload independently became `static`; no public declaration or known caller. |
| `rga_task_submit(im_job_handle_t,rga_buffer_t,rga_buffer_t,rga_buffer_t,im_rect,im_rect,im_rect,im_opt_t*,int)` | **Accepted.** Upstream added fence parameters before the options pointer; internal submission helper with no public declaration or known caller of the old signature. |
| `rga_version_table_check_minimum_range(rga_version_t&,const rga_version_bind_table_entry_t*,int,int)` | **Accepted.** Upstream changed reference to value; internal version-table helper with no public declaration or known caller. |
| `rga_version_table_get_current_index(rga_version_t&,const rga_version_bind_table_entry_t*,int)` | **Accepted.** Upstream changed reference to value; internal version-table helper with no public declaration or known caller. |
| `rga_version_table_get_minimum_index(rga_version_t&,const rga_version_bind_table_entry_t*,int)` | **Accepted.** Upstream changed reference to value; internal version-table helper with no public declaration or known caller. |
| `int cosa_table[360]` | **Accepted data-symbol removal.** Writable, runtime-filled exported array became `static const`; no public declaration or known caller, but private readers/writers remain a residual risk. |
| `int sina_table[360]` | **Accepted data-symbol removal.** Separate writable array underwent the same static-constant conversion; no public declaration or known caller, with the same private-reader/writer risk. |

## Executable boundary

`ci/check-abi.sh OLD_SO NEW_SO REPORT [ACCEPTED_REMOVALS_TSV]`:

1. Requires DWARF and SONAME `librga.so.2` on both libraries.
2. Saves an **unfiltered** `abidiff` report, with ambient user/system suppression
   files disabled. Tool errors and unknown exit bits fail.
3. `ci/abi-removals.py` checks the reported removal details against the summary
   counts, expands any reported aliases, and requires **set equality** with the
   literal ELF names in the TSV. Extra removals and absent expected removals both
   fail; malformed or duplicate entries and incomplete reports fail too. Omitting
   the TSV means **no accepted removals**, never a blanket waiver.
4. Only after equality succeeds, generates one exact `symbol_name` rule per
   entry, restricted to `deleted-function` or `deleted-variable`, and runs
   `abidiff` again. No category-level rule, type suppression, early `drop`, regex
   prefix, or public-header filter is used. The original report, generated rules
   (`REPORT.abignore`) and remaining report (`REPORT.accepted`) are retained.
5. Applies the existing exit-bit rule to the remaining report: 0 or 4 is accepted;
   errors and incompatible-change bit 8 fail. The bit is not manually cleared.

This uses libabigail's documented
[per-symbol deletion suppressions](https://sourceware.org/libabigail/manual/suppression-specifications.html#suppress-function),
not a hand-maintained global exit-code exception. The
[exit-code contract](https://sourceware.org/libabigail/manual/abidiff.html#return-values)
distinguishes change bit 4 from incompatible-change bit 8. A green gate is **not
an empty diff or proof of universal binary compatibility**: the six function and
two variable changes catalogued in the reserve-repair receipt remain visible,
including the logging return type, internal manager mutex type and driver enum
values. They are not reclassified as libstdc++ noise or newly suppressed here.

## LTO and regression coverage

`ci/abi-steps.sh` first compares R0 and R1 with the same target-suite GCC 14,
libstdc++, `-g -O2` and LTO off. It then builds R1 with `-Db_lto=true` and compares
it against that **same** R0 baseline, with the **same** accepted-removal set.
This isolates LTO rather than changing the baseline to excuse optimizer effects.
The packaging and normal build/test lanes now disable LTO via `ci/package-lto.env`.
Both ABI comparisons remain required, as do analyzer, werror, sanitizers and
reproducibility. The failed LTO experiment remains an unshipped comparison input.

Plain GCC 14 LTO initially removed **16 additional weak C++ exports** from R1
(including `Mutex` and `im2d_job_manager` destructor variants and libstdc++
instantiations). The exact-set gate rejected that candidate in
[run 34927102093](https://github.com/CERALIVE/librga/actions/runs/34927102093).
Those names were **not added to the removal allowlist**. Instead, `meson.build`
passes one `--undefined=<symbol>` linker root per existing definition when LTO is
enabled. This retains compiled definitions through LTO; it adds no compatibility
shim, source implementation, visibility override or version script. A generic
`--export-dynamic` probe did not retain them and was discarded. The ABI job also
compares non-LTO R1 to LTO R1 with **no accepted removals**: LTO itself must not
lose an export. This is separate from the accepted upstream R0→R1 transition.

`bash tests/test-abi-gate.sh` uses real GCC-built ELF fixtures and real abidiff:
identical/additive controls pass; an unlisted hidden public symbol fails; exactly
the committed 18 removals pass; a nineteenth function or variable fails; restoring
**each** of the 18 fails as a stale list; restoring the accepted candidate passes.
An independent incompatible vtable change still fails after the accepted deletions
are suppressed. Truncated-report and duplicate-list cases also fail closed.
The original three controls are retained, not replaced or weakened.

The earlier 21-versus-18 discrepancy came from GCC 16 `-O0` versus Debian GCC 14
`-O2`. The matched control had 274 exports in both rebuilt and published R0, with
an empty symbol diff. The extra three weak libstdc++ names were measurement noise;
**none of these accepted 18 is**. Do not widen this list to hide toolchain drift.

No PR, tag, release, board qualification or SONAME change is authorized by this
decision. `Provides: librga2 (= 2.2.0)` and `Conflicts`/`Replaces: librga2` remain
unchanged.

## Binding-drift correction — 2026-09-15 UTC

Independent review of PR #10 found **25 exported R1 bindings changed under LTO**,
including 20 functions already WEAK in R0. The job-manager destructor and
`Singleton<RockchipRga>::getInstance()` become GLOBAL; two singleton-related
GNU_UNIQUE objects also become GLOBAL. Their visibility remains DEFAULT. The
empty `abidiff-lto-only.txt` report below is genuine, but does not measure this
metadata and is **not evidence of ELF equivalence**. The prior LTO clearance is
withdrawn; no reliable binding-preserving retention mechanism is claimed.

`ci/check-dynsym.py` compares sorted exported `(name, type, binding, visibility)`
tuples from `readelf --dyn-syms --wide`, requiring exact equality with no
allowlist. It includes version suffixes, ignores undefined imports and local
symbols, and excludes addresses/sizes/section indices from this metadata-only
contract. Exit 1 means drift; malformed/empty inputs and tool errors return 2.

The required `abi` job always runs that comparison on non-LTO R1 versus the real
LTO experiment. `ci/check-lto-policy.sh` records `LTO_DYNSYM=FAIL`, permitting
only `PACKAGED_LTO=false` on a mismatch; errors fail regardless. A separately
built R1 using the selected packaging LTO setting must pass the comparator
unconditionally. Thus a green summary means the **non-LTO selection** is valid,
not that the LTO experiment passed. The shared readonly setting is consumed by
packaging, the normal test lane and this policy. The experimental linker roots
remain measurable but are not used by packaged builds.

The required `dynamic-symbol-evidence` upload retains raw readelf output,
normalized before/after inventories, both comparison diffs, the LTO verdict and
positive-control results. `tests/test-dynsym-gate.sh` mutates real ELF .dynsym
entries: WEAK→GLOBAL, UNIQUE→GLOBAL, function type and visibility each fail.
Identical inputs pass; invalid ELF fails even with LTO off. The policy is tested
with LTO both on and off. The workflow-contract test keeps the comparison,
controls and artifact in the required ABI lane; all nine summary dependencies
retain failure/cancellation/skip rejection. No existing abidiff control or
comparison was removed or weakened.

Local reproduction against the retained arm64 artifacts of run 34927479435:
315 exports on each side, comparator exit **1**, including the named binding
changes. Local real-ELF mutation controls pass. Host abidiff and Meson are absent;
the corrected workflow's native hosted result must supply full build/ABI evidence.

## Historical verification receipt — 2026-09-15 UTC (not LTO clearance)

Code commit **`eeb4f74`** on `ci/r1-toolchain-gates`, based on `ae59c2f` and main
`8490d34`. [Build Check 34927479435](https://github.com/CERALIVE/librga/actions/runs/34927479435)
is **fully green**, including its required summary. This is a branch candidate,
not a released package or a hardware qualification.

| Gate | Measured result |
|---|---|
| R0 → R1, matched GCC 14.2 `-g -O2`, LTO off | Raw abidiff 12; exact 18-removal set; deletion-only rules leave exit **4**; wrapper passes |
| Same R0 → R1 with LTO on | Raw abidiff 12; same exact 18-removal set; deletion-only rules leave exit **4**; wrapper passes |
| Non-LTO R1 → LTO R1 | No accepted removals; abidiff **0**, empty report |
| ABI regression controls | Original 3/3; exact-18 acceptance; extra function/data rejection; all 18 stale-entry rejections; restored candidate passes; independent vtable incompatibility still returns 12 after filtering; truncated report and duplicate list rejected |
| Bookworm arm64, LTO on | **37/37**, zero failures or skips |
| Trixie arm64, LTO on | **37/37**, zero failures or skips; package contracts and ABI floors pass |
| Analyzer | 17 analyzed library TUs; three documented finding pairs; zero untriaged |
| Scoped werror | 32 TUs, `-Wall -Wextra -Werror`, no suppression flags; canaries pass |
| Host-shim sanitizers | ASan/UBSan baseline **11/11**, H10 **6/6**, TSan concurrency **6/6** |
| Reproducibility, LTO packages | Two complete builds, byte-identical runtime and development packages at `SOURCE_DATE_EPOCH=1789445141` |
| Required summary | All nine dependency results `success` |

The reproducibility artifact records SHA-256:

```text
3e4c1c062d5fe0251ffe4700d39761972693cecf883cbcbe1956f3fb59dbf1fb  librga2-ceralive_1.10.5+ceralive.1_arm64.deb
d274a6f53f797aa731f521b18fb2772cb0c856c3a819553caae7afc8fbef363f  librga-ceralive-dev_1.10.5+ceralive.1_arm64.deb
```

The `abi-evidence` artifact retains all three raw reports, both generated
deletion-only rule files, both remaining reports, compile commands and the three
DWARF libraries. The six function/two variable changes remain visible in the
cumulative reports, not hidden by an empty-diff claim. Local ABI controls and
matched arm64 probes are retained under `test-results/acceptance/`; a local image
initially lacked abidiff, and that setup failure is not counted as a gate run.
Local full build/repro steps did not run after the plain-LTO ABI failure; the
complete native hosted run above supplies those results, not an emulation claim.

Changed Python and shell files have clean error-level LSP diagnostics. Bash
syntax, workflow-contract tests and `actionlint` pass. YAML LSP was previously
declined, and no Meson/Markdown server is configured; real Meson configuration,
compilation and CI are the build-file evidence. No tooling configuration was
installed. Validation stopped at the first complete green run; this receipt is a
documentation-only follow-up, not a second build claim.
