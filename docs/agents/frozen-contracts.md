<!-- Moved verbatim from AGENTS.md on 2026-10-05 by lean-rules-docs-landing-latam -->

## Frozen contracts

These are compatibility contracts with live consumers, not cleanup opportunities:

- **SONAME:** `librga.so.2`, unchanged. The device already loads that soname from
  Radxa's build; the whole swap works because the name is identical.
- **Package names:** `librga2-ceralive` (runtime, `Provides: librga2`,
  `Conflicts`/`Replaces: librga2`) and `librga-ceralive-dev` (development).
- **pkg-config:** the file is `librga.pc` and keeps its name and its variables.
- **Header install path:** public headers install under `include/rga/`.
- **No unexpected symbol removals.** R1 accepts exactly the 18 inherited upstream
  removals in `packaging/baseline-symbols-upstream-delta.txt`, without shims. Both
  extra removals and absent expected removals fail the ABI gate. This explicit
  owner decision supersedes strict R0-superset wording for those entries only;
  see [R1 ABI acceptance](../R1-ABI-ACCEPTANCE.md) for each disposition and the
  private-binary/writable-data risks. No new public-layout, visibility or
  version-script change is authorized. R0 neutrality is unchanged.
- **Defaults are frozen.** The default colour matrix, the default interpolation
  mode, and the default log level stay exactly as upstream ships them. Changing
  any of them silently changes behaviour for every caller, including callers
  outside CeraLive. Explicit CSC and interpolation are consumer-side calls.
- **No new public API or runtime configuration knob.**
  Accepting `IM_SCHEDULER_DEFAULT` inside the existing `imconfig` signature is an
  argument-validation fix, not new API.

Linux LP64 `rga_info_t` and `im_opt_t` retain the R0 sizes (696 and 304 bytes),
locked by C/C++ header assertions. Gaussian configuration consumes existing
reserve space including its alignment gap; no preceding field moves. Non-LP64
and Android layouts are not changed by this repair. `unit-pure` guards an exact
304-byte R0 option allocation with an inaccessible page and checks Gaussian
setter/copy round-trips. The [reserve repair](../R1-ABI-REPAIR.md) records the
measurements; the later [accepted-removal decision](../R1-ABI-ACCEPTANCE.md)
changes only the enumerated removal policy, never these assertions.

