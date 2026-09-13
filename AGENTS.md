# librga

CeraLive's public fork of Rockchip's RGA userspace library, imported from
JeffyCN's `mirrors` repository, branch `linux-rga-multi`, pinned at
`57a1067a246c71fa6c9a355d1668884fda155dd5` (im2d API `1.10.5_[11]`). The import
coordinate, the `1.10.1_[4]` release window used for R0, and the file-level
licence census all live in [`docs/PROVENANCE.md`](docs/PROVENANCE.md); this file
is the working contract that sits on top of them.

## Role

This repository is the **sole userspace bridge** between GStreamer and the RK3588
media island's `/dev/rga` character device. Everything the streaming stack asks
the 2D hardware to do arrives here first:

```text
gstreamer-rockchip  rgaconvert / rgacompositor      -> im2d API -> ioctl -> /dev/rga
gstreamer-rockchip  MPP-path colour/scale conversions -> im2d API -> ioctl -> /dev/rga
```

There is no second path. A caller that wants RGA acceleration links
`librga.so.2`, and the kernel side is reached only through this library's
`ioctl` layer. That is why the request bytes this library builds are treated as
the regression-preservation contract: they are the entire observable surface
between the plugin and the island driver.

Two releases exist, versioned upstream-style rather than CalVer:

| Release | Base | What it is |
|---|---|---|
| **R0** `1.10.1+ceralive.1` | `5a97e650a30b7c7036eb5aa26e39f2d09f18fcc9` | A rebuild of the same API release the bench boards run today, with packaging and CI commits only. Its neutrality claim is **bounded** to export-set containment, request-byte goldens on the CeraLive call set, and both-board gate rows. Never "byte-identical source". |
| **R1** `1.10.5+ceralive.1` | `57a1067a246c71fa6c9a355d1668884fda155dd5` | The pinned fork point plus the fix series that Wave 0 actually turned RED. |

## Repository map

| Area | Location |
|---|---|
| im2d public API and implementation | `im2d_api/` |
| RGA userspace driver core | `core/` |
| Public headers installed under `include/rga/` | `include/` |
| Upstream sample programs | `samples/` |
| Upstream Rockchip developer guides and FAQ | `docs/Rockchip_*` |
| Import coordinate, licence census, credits | `docs/PROVENANCE.md` |
| API usability traps every caller trips over | `docs/API-TRAPS.md` |
| Per-fix evidence ledger | `docs/fix-audit.md` |
| Sanitizer/analyzer recipes and their proof boundary | `docs/SANITIZERS.md` |
| Disposition of every `-Wanalyzer-*` finding | `docs/ANALYZER-TRIAGE.md` |
| Debian package build and contract | `packaging/` |
| Island-UAPI parity, host shim, goldens, unit tests | `tests/` |
| Board-gated drills | `tests/board/` |
| Target suite, toolchain and dependency pins | `ci/` |
| Upstream JeffyCN packaging, preserved and unused | `debian/` |
| Android / CMake / RT-Thread build trees, preserved | `Android.*`, `CMakeLists.txt`, `cmake/`, `SConscript` |

## Commit strategy

Three tiers, exactly as in `gstreamer-rockchip`, and for the same reason:
provenance and reviewability survive only if the first two tiers keep their own
commits.

1. **Tier (a), ported upstream or donor fixes.** Clean ports use
   `git cherry-pick -x`, preserving the original Author, message, and the
   `(cherry picked from commit …)` line the flag writes. Adapted ports carry the
   adapter's authorship and credit the original owner plus the full source SHA in
   the message body. **Never squashed, in either form.**
2. **Tier (b), first-party bug fixes.** One commit per defect, titled for the
   mechanism rather than implementation trivia. **Never squashed.**
3. **Tier (c), CI, packaging, docs, and mechanical work.** These may be squashed
   under the normal CeraLive Rule C convention.

Merge method follows from that. A PR carrying tier-(a) or tier-(b) history merges
with **Create a merge commit** or **Rebase and merge** — **never squash**, because
a squash collapses the whole PR into one new commit and destroys the per-fix
history those tiers exist to keep. The same rule covers upstream-sync PRs: a
squash discards the second parent, the merge-base stops advancing, and every
later sync replays already-merged commits as phantom conflicts.

`integration/1.10.5-ceralive.1` is integrated by **merge, never rebase**. It carries
eight two-parent Wave-D investigation merges; rebasing linearizes that history
and replays conflicts in `tests/shim/contract.c` and `tests/shim/fake_rga.c` that
were already resolved by union. Do not apply the generic pre-work rebase rule to
this branch. The fix-audit structural repair is authorized directly on
`0011d44f074508dd5d8533a77496a593211b9e85`, without any pre-work branch sync.

No commit in this repository may carry a `Co-authored-by:` trailer or any AI or
tool attribution. Such trailers are **forbidden**. A clean cherry-pick's
preserved upstream Author field and its `-x` provenance line are not trailers;
they are the record of where the change came from, and they stay.

Remotes: `origin` is `CERALIVE/librga` and nothing else. There is never a remote
literally named `upstream`. When a source comparison against JeffyCN is genuinely
needed, add a transient remote named `jeffycn`, fetch an explicit refspec, verify
the fetched SHA against the pin, and remove the remote **before** any push or PR.

## PR-TARGETING

Every PR targets `CERALIVE/librga`, never the fork parent:

```bash
gh pr create --repo CERALIVE/librga --base main
```

Release PRs target their release branch instead (`--base release/1.10.1` for R0),
but the repository argument never changes. Before handoff, confirm the PR URL
starts with `https://github.com/CERALIVE/librga/`.

A PR carrying tier-(a) or tier-(b) commits is **never self-merged**. An
independent reviewer — a different agent and a different model from the author,
dispatched by the orchestrator — confirms the evidence and the merge method
first, and the reviewer's session id is written into the `docs/fix-audit.md` row.
A missing id is recorded as a gap, never explained away.

## Frozen contracts

These are compatibility contracts with live consumers, not cleanup opportunities:

- **SONAME:** `librga.so.2`, unchanged. The device already loads that soname from
  Radxa's build; the whole swap works because the name is identical.
- **Package names:** `librga2-ceralive` (runtime, `Provides: librga2`,
  `Conflicts`/`Replaces: librga2`) and `librga-ceralive-dev` (development).
- **pkg-config:** the file is `librga.pc` and keeps its name and its variables.
- **Header install path:** public headers install under `include/rga/`.
- **Exported symbols are a SUPERSET contract.** The set may grow; it may **never
  shrink**. No symbol removal, no public-struct layout change, no visibility or
  version-script change. `nm -D` containment against R0 plus `abidiff` between
  releases are the executable authorities.
- **Defaults are frozen.** The default colour matrix, the default interpolation
  mode, and the default log level stay exactly as upstream ships them. Changing
  any of them silently changes behaviour for every caller, including callers
  outside CeraLive. Explicit CSC and interpolation are consumer-side calls.
- **No new public API** beyond the opt-in environment variable already present.
  Accepting `IM_SCHEDULER_DEFAULT` inside the existing `imconfig` signature is an
  argument-validation fix, not new API.

## The additive-only principle

Quoted verbatim from the effort's plan (D29), because it is the rule most likely
to be broken by well-meant tidying:

> Additive-only (D29): nothing existing is stripped — Android/RT-Thread/other-SoC
> trees, legacy `RockchipRga`/`c_RkRga*` API, every exported symbol, all stay;
> `LIBRGA_STRICT_DRIVER=1` stays as a default-off opt-in; validation changes only
> accept MORE valid input.

In practice: the Android and RT-Thread build files stay even though CeraLive
builds with Meson, the CMake tree stays even though we do not use it, chips we
will never ship stay in the format and scheduler tables, and a validation fix may
only widen the accepted input set. Deleting any of it is merge friction against
an upstream we intend to keep syncing from, for no shipped benefit.

## Test and board-drill contract

Candidate A's host-only R1 extension [EXISTS] is `tests/repro/run-candidate-a.sh`.
It adds direct exported-init coverage to H1 and H3; build both sanitizer trees
first. Results and the unproven subclaims are in `docs/fix-audit.d/candidate-a.md`.
Exit 1 is a RED reproducer, not part of the green baseline suite.

Candidate B's host-only R1 probe [EXISTS], `tests/repro/run-candidate-b.sh`,
runs H2 with an additional owned-reference control after both sanitizer trees
are built. Its RED findings and ownership limits are recorded in
`docs/fix-audit.d/candidate-b.md`; it is separate from the green baseline suite.

Bootstrap registration is assembled by `bash scripts/wire-bootstrap.sh` [EXISTS].
It preserves the shared-library alias before the static-library reassignment and
appends UAPI parity, goldens, unit and board fragments in dependency order. Run it
after editing a fragment; a second invocation changes nothing. It also assembles
`docs/fix-audit.d/*.md` into one continuous six-field D21 table in
`docs/fix-audit.md`, with verbatim supporting prose in fragment-labelled appendices.
Fragments may begin with bare D21 rows or introduce them with the canonical D21
header. Duplicate ledger headers/separators are omitted from the generated file;
the source fragments remain unchanged. Subsidiary tables, fenced transcripts and
comments stay with the prose, not in the ledger. Malformed D21 rows fail assembly
without overwriting the ledger. Edit evidence in the fragments, then regenerate;
do not hand-edit the generated table or appendices. The introduction still records
characterization of the unchanged upstream base, not landed library fixes.
`bash tests/test-wire-bootstrap.sh` checks preservation, structure and idempotency
in an isolated repo-local fixture; it also runs as the Meson `wire-bootstrap` test.

Two environments, and they prove different things. Keeping them apart is the
point of this section.

QEMU user-mode has a measured invalid-fd RGA ioctl limitation, not a shim bug.
The two narrowly scoped, opt-in emulation skips and native mandatory coverage
are documented in [`docs/KNOWN-LIMITS.md`](docs/KNOWN-LIMITS.md).

H6 fence ownership reproduction [EXISTS] runs separately from the green baseline
suite: `bash tests/repro/run-h6.sh` builds the unchanged shared library and runs
200 iterations each of C2/C3/C4, with controls and fd census under
`test-results/h6/`. Exit 1 records RED, not a harness success hidden as a green
test. H6a is WITHDRAWN because no real positive-success submit path exists on
the island. The test-only fence/poll knobs are documented in
[`tests/golden/README`](tests/golden/README); the findings are in
[`docs/fix-audit.d/h6.md`](docs/fix-audit.d/h6.md). No hardware or sanitizer
coverage is claimed by this reproducer.

| Environment | What runs there |
|---|---|
| **Host shim** | Island-UAPI parity gate (struct sizes, member offsets, ioctl numbers against the island's pinned `rga.h`), request-byte goldens, hardware-independent unit tests, TSan/ASan/UBSan legs, GCC-14 `-fanalyzer`, `nm` containment and `abidiff`. |
| **Board** | Package install/removal, library-level PSNR and colour oracle, DMA-BUF behaviour, fd census, and the A/B rows against the Radxa package. Both boards: Orange Pi 5+ and Rock 5B+. |

The sanitizer and analyzer recipes, the flags that are load-bearing, the canaries
that prove a runtime is intercepting rather than merely linked, and the discovery
contracts a new reproducer registers itself through are in
[`docs/SANITIZERS.md`](docs/SANITIZERS.md). Every `-Wanalyzer-*` finding carries a
disposition in [`docs/ANALYZER-TRIAGE.md`](docs/ANALYZER-TRIAGE.md).

The manual H2 teardown probe [EXISTS] is `tests/repro/run-h2.sh`: 200 fresh
processes per scenario and sanitizer, with its six-field ledger fragment in
`docs/fix-audit.d/h2.md`. Invocation and diagnostic-output settings are documented
in [`docs/SANITIZERS.md`](docs/SANITIZERS.md#h2-concurrent-teardown-probe).

### The suite proves

- That the request bytes this library writes for the CeraLive call set are
  unchanged against the recorded goldens.
- That every ioctl number and every shared struct layout matches the island
  driver's UAPI at the pinned island tag, on aarch64.
- That the exported-symbol set of a release contains R0's, and that `abidiff`
  reports no incompatible change against the previous release.
- On the board, only what the transcript for that run names: the exact package,
  the exact kernel, the exact island tag, and the finite observations that run
  scored.

### The suite does NOT prove

- **Sanitizer cleanliness on the board. TSan runs on the host shim only**, as do
  ASan and UBSan. No board drill claims sanitizer coverage, and no ledger row may
  imply one. A host-shim sanitizer report is evidence about the shim's model of
  the driver, not about silicon.
  TSan is host-only **permanently** — it cannot be statically linked reliably, so
  no board-side equivalent can exist. ASan *could* reach a board via
  `-static-libasan`, and `scripts/cross-build-harness.sh --asan` gates that on a
  preflight. As of 2026-09-05 the verdict is **NOT-AVAILABLE**:
  `aarch64-linux-gnu-gcc -print-file-name=libasan.a` echoes the bare name, so the
  cross toolchain carries no static ASan runtime and the board-ASan leg does not
  exist. Reproducer rows record `host-shim-only` until a toolchain that has it is
  in use.
- That the host shim reproduces RGA hardware. It models ioctl return values; it
  does not execute a blit, does not produce pixels, and cannot detect a
  hardware-side correctness fault.
- Anything about hardware the transcript does not name, including the other board
  when only one was reachable.
- Long-term thermal, suspend/resume, or OTA behaviour.
- A result from an unreachable board. That run is `SKIPPED-unreachable` with its
  attempt transcript, never PASS.

Board scripts require `CERALIVE_BOARD_TEST=1` and otherwise exit 77. Board
identity arrives only through `BOARD_IP`, `BOARD_SSH_USER`, and `BOARD_SSH_PASS`.
No repository file names a credential path, and no repository file resolves a path
above the repository root. Drills write only under `/tmp` and install or remove
only the librga package under test, always via `apt-get install ./<deb>` and never
a bare `dpkg -i` across the `Conflicts: librga2` boundary; the Radxa rollback deb
is staged on the board before the first install.

## Licensing

The librga code proper is **Apache-2.0** (`COPYING`, retained byte-for-byte at the
repository root), **with documented third-party exceptions**. The exceptions are
not a formality: the todo-7 file-level census in
[`docs/PROVENANCE.md`](docs/PROVENANCE.md) classifies all 278 tracked files and
fails closed on anything unclassified. Three findings from that census govern how
this repository is packaged:

- **The vendored libdrm headers are MIT/X11-style and keep their own notices.**
  Seven files under `core/3rdparty/libdrm/include/drm/` and
  `samples/utils/3rdparty/libdrm/include/`, held by Precision Insight, VA Linux
  Systems, Intel, Dave Airlie, Jakob Bornecrantz, Red Hat and Tungsten Graphics.
  `core/3rdparty/libdrm/include/drm` is on the shipped library's include path, so
  this is a build input, not sample scaffolding. Alongside them sit four prebuilt
  `libdrm.so` binaries under `samples/utils/3rdparty/libdrm/lib/` with no source
  in tree; they are sample-only and are **never packaged**.
- **`Android.mk` at the repository root is GPL-3.0-or-later** (Fuzhou Rockchip
  Electronics, Putin Li and Bin Li) and therefore conflicts with the Apache-2.0
  `COPYING`. This is an upstream inconsistency, imported as-is and not resolved
  here. It is safe only because it is an Android NDK build file that CeraLive
  never invokes — so it must be **excluded from every distributed artifact** and
  must never land under a `Files: *` Apache-2.0 stanza in `packaging/copyright`.
- **`core/rga_sync.cpp` and `core/rga_sync.h` are held by AOSP and Google**, not
  Rockchip. Same licence as the root, different copyright holder, so they need
  their own DEP-5 stanza.

`packaging/copyright` is generated from that census rather than from `COPYING`,
because a repository-level licence claim is false at file granularity.

CeraLive modifications remain Apache-2.0. Per Apache-2.0 §4(b), every modified
file carries a notice line of the form:

```c
// Modified by CeraLive <YYYY-MM-DD>: <why>
```

**Do not invent a `NOTICE` file.** Upstream ships none, §4(b) does not require one
where there is nothing to propagate, and the per-file notice line above is the
whole convention.

The upstream `debian/` directory is JeffyCN's, is preserved byte-for-byte, and is
**unused**: CeraLive packages are built by `packaging/build-deb.sh` alone, with no
debhelper, no `debian/patches/`, and no DEP-3 patch headers. Do not build from
`debian/`, do not fix it, do not delete it.

Credits for Rockchip, Jeffy Chen, tsukumijima and nyanmisaka are in
[`README.md`](README.md) and, in full, in `docs/PROVENANCE.md`.

## Anti-patterns

- Do not change the default colour matrix, the default interpolation mode, or the
  default log level. Both are behaviour divergence for every caller.
- Do not remove an exported symbol, change a public struct's layout, or touch the
  SONAME, the pkg-config name, or symbol visibility.
- Do not delete the Android, RT-Thread, CMake, or other-SoC trees, and do not
  delete the legacy `RockchipRga` / `c_RkRga*` API. Additive-only means additive.
- Do not write a fix without a RED reproducer transcript **on the base being
  fixed**. A RED only on the Radxa or R0 rows does not authorize a change to R1.
  A harness that will not build is `NOT-REPRODUCED` and becomes a ledger note,
  never a fix.
- Do not merge a fix without an `APPROVE` receipt from an independent reviewer
  carrying a session id. `GAP:` is not an acceptable ledger value for a landed
  fix.
- Do not claim sanitizer coverage on the board. TSan, ASan and UBSan are
  host-shim-only.
- Do not squash a fix-series or upstream-sync PR, and do not self-merge one.
- Do not add CeraLive packaging under `debian/`, and do not execute it.
- Do not add a consumer stopgap for the thread-local `imconfig` behaviour. The
  plugin already reconfigures on the calling streaming thread before every
  `improcess`; patching it is patching a non-defect.
- Do not take "while I'm here" fixes from the audit ledgers — over-strict format
  tables, size math, allocation rows, task-API rows — unless that row's own
  reproducer is RED.
- Do not reformat, do not modernize to `#pragma once` or C++17, and do not run a
  whitespace sweep. Every one of those is merge friction against an upstream we
  keep syncing from.
- Do not do 10-bit work here, and do not touch the kernel, the media island,
  `rk3588-kernel-patches`, `cerastream`, or `CeraUI`. A librga row that needs a
  driver change is STOP-and-surface to the island track.
- Do not name a credentials path, a workspace-parent path, or any path above the
  repository root in a tracked file.
