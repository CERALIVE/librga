# Provenance — where this repository's source came from, and what its version claim does and does not mean

**Status: import complete.** The full first-parent history of JeffyCN's
`linux-rga-multi` branch is present in `main`, `main` sits at the pinned fork
point, and the `1.10.1_[4]` API window has been resolved from source and
cross-checked against a real board.

Nothing in this repository has been rewritten. Every commit reachable from `main`
is an upstream commit with its original author, date, message and tree.

## Why this document exists

This fork's whole claim on the R0 release is that it is a **rebuild of the same
upstream API release the bench boards already run**, not a new library. That claim
is only worth something if a reviewer can name the exact commit it means, see how
it was selected, and see the evidence tying it to the binary on the board. This
document is that record.

It also carries the **file-level licence census**, because the repository root
licence is Apache-2.0 but the tree bundles third-party subtrees that are not, and
carries one build file whose own header contradicts the root licence. A
repository-level licence claim is false at file granularity, so `packaging/`
generates its DEP-5 `copyright` from the census below rather than from `COPYING`.

## Import coordinate

| | |
|---|---|
| Upstream | `https://github.com/JeffyCN/mirrors` |
| Branch imported | `linux-rga-multi` |
| Upstream tip at import | `57a1067a246c71fa6c9a355d1668884fda155dd5` |
| Fork point (`main`) | `57a1067a246c71fa6c9a355d1668884fda155dd5` |
| Import date | 2026-09-05 |
| Commits on `main` | 991 |
| Tracked files at the fork point | 276 |

The fork point is a **pinned SHA, not a moving tip**. At import time the two
happened to be the same commit, which is a coincidence of timing and not a policy:
`main` is pinned to `57a1067a…` and does not follow `linux-rga-multi` forward.

JeffyCN's default branch is `kernel`, and the mirror repository carries twenty
unrelated branches totalling roughly 9.7 GB. Only `linux-rga-multi` was fetched,
and only `main` is pushed here. No other upstream branch exists in this
repository, and no upstream remote is attached to it: `origin` is
`CERALIVE/librga` and nothing else.

## The `1.10.1_[4]` API window

### How the window was resolved, and why not with `grep`

`im2d_api/im2d_version.h` **never contains the literal string `1.10.1_[4]`.** It
defines four numeric macros and builds the version string by macro expansion:

```c
#define RGA_API_MAJOR_VERSION       1
#define RGA_API_MINOR_VERSION       10
#define RGA_API_REVISION_VERSION    1
#define RGA_API_BUILD_VERSION       4

#define RGA_API_VERSION \
    RGA_VERSION_STR(RGA_API_MAJOR_VERSION) "." \
    RGA_VERSION_STR(RGA_API_MINOR_VERSION) "." \
    RGA_VERSION_STR(RGA_API_REVISION_VERSION) "_[" \
    RGA_VERSION_STR(RGA_API_BUILD_VERSION) "]"
#define RGA_API_FULL_VERSION "rga_api version " RGA_API_VERSION RGA_API_SUFFIX
```

(`im2d_api/im2d_version.h` lines 26-39 at `5a97e650`.) A `grep` for the rendered
string therefore matches nothing at any commit. Every probe below reads the
**four numeric macros** and renders the string itself:

```sh
ver() { git show "$1:im2d_api/im2d_version.h" | awk '/#define RGA_API_(MAJOR|MINOR|REVISION|BUILD)_VERSION/ {v[$2]=$3} END {printf "%s.%s.%s_[%s]\n", v["RGA_API_MAJOR_VERSION"], v["RGA_API_MINOR_VERSION"], v["RGA_API_REVISION_VERSION"], v["RGA_API_BUILD_VERSION"]}'; }
```

94 commits touch that header on the first-parent history of the fork point.
Walking them newest to oldest and taking the first whose `ver` is `1.10.1_[4]`
finds the last commit that **touched the header** while it still reported `[4]`.
That commit is not the end of the window: three later commits changed other files
before the build number moved. The window's true first-parent tip is the commit
immediately preceding the next header commit.

### The four coordinates

| Role | Commit | `ver` | Date | Subject |
|---|---|---|---|---|
| introducer | `ac84b28e97cf28623e0e6f3ea37737f106b74cb7` | `1.10.1_[4]` | 2024-08-30 | samples: alpha: wrongly used YUV format on dst channel |
| `R0` (last header-touching commit still reporting `[4]`) | `ac84b28e97cf28623e0e6f3ea37737f106b74cb7` | `1.10.1_[4]` | 2024-08-30 | samples: alpha: wrongly used YUV format on dst channel |
| **`R0_TIP` (first-parent tip of the window — THE RELEASE BASE)** | **`5a97e650a30b7c7036eb5aa26e39f2d09f18fcc9`** | `1.10.1_[4]` | 2024-09-24 | normal: release_fence fd set to -1 when driver do not support fence |
| remover (first later header commit) | `fc3f742a7be43c62c9eb3e17a007f957b0e7db83` | `1.10.1_[6]` | 2024-09-26 | im2d_api: fix wrong check dst-channel format in 3-channel mode |

All four commits are authored by Yu Qiaowei (Cerf Yu) of Rockchip.

**The R0 release base is `R0_TIP`, never `R0`.** Every later reference to "the R0
commit" in this repository — the `release/1.10.1` branch, the R0 packaging, the
R0 board drills — means `5a97e650a30b7c7036eb5aa26e39f2d09f18fcc9`.

The introducer and `R0` are the **same commit** because exactly one header commit
in the whole history renders `1.10.1_[4]`: `ac84b28e` moved
`RGA_API_BUILD_VERSION` from `3` to `4`, and the next header commit moved it
straight from `4` to `6`. Build number `5` was never published on this branch.

Three commits sit on the first-parent history between `R0` and `R0_TIP`, none of
them touching the version header:

```text
5a97e65 normal: release_fence fd set to -1 when driver do not support fence
cc620bc im2d_api: support blend between formats without per-pixel alpha
f6938cd build: samples: im2d_slt: Android.mk: add header path: 'im2d_api/'
```

### The three assertions, and their result

```text
ver(R0_TIP) == 1.10.1_[4]                      PASS   (macros 1 / 10 / 1 / 4)
ver(remover) != 1.10.1_[4]                     PASS   (renders 1.10.1_[6])
git rev-parse <remover>^ == R0_TIP             PASS
```

### The board cross-check

The `.so` was copied from the CeraLive Orange Pi 5+ bench board and read
directly. The library builds its `rga_api version …` banner from the same four
macros, so this string is the runtime rendering of the header state the binary
was compiled from:

```text
$ scp <board>:/usr/lib/aarch64-linux-gnu/librga.so.2.1.0 .
$ sha256sum librga.so.2.1.0
0b455344259c37fec821955e2de85bb5f76a34e69682217b514c407d8a35c6c3  librga.so.2.1.0
$ strings librga.so.2.1.0 | grep 'rga_api version'
rga_api version 1.10.1_[4]
```

The board package is Radxa's `librga2` at `2.2.0-1`, which matches the top entry
of the upstream `debian/changelog` carried in this tree (`librga (2.2.0-1)`). Note
that the Debian package version (`2.2.0-1`) and the im2d API version
(`1.10.1_[4]`) are independent numbering schemes; only the second one is what
`R0_TIP` is selected against.

### What this claim IS, stated precisely

The `strings` match identifies the **API RELEASE** the Radxa build came from, not
Radxa's exact commit. No Radxa source repository for this package exists, so
downstream patches on top of that API release cannot be excluded. `R0` is
therefore defined as **"the newest JeffyCN source state whose header still
reports `1.10.1_[4]`"**, never as "the exact `[4]` release" — and the selected
commit's own message may already announce a later build number while its header
still reports `[4]`. (In this history `R0`'s message body does read
`update to 1.10.1_[4]`, matching its header; the caveat stands because the
selection rule reads the header, not the message, and would still be correct if
they disagreed.)

Under the **owner-approved amendment of 2026-09-12**, R0's **neutrality claim is
bounded to three measurable things** and nothing else:

- (a) every global export of the Radxa `.so` contained (254/254), excluding
  compiler-generated weak COMDAT template internals of the private job map,
- (b) every semantic request field equal on the CeraLive call set, excluding
  only nine proved non-deterministic padding bytes inside `rga_req.full_csc`,
- (c) both-board gate rows equal.

It is **never** a claim of byte-identical source. The exact exclusions, compiler
and stack-history evidence, preserved raw FAIL records, and negative controls
are part of [R0-NEUTRALITY.md](R0-NEUTRALITY.md). This changes the original literal
export/byte promises openly; it does not claim that their failures passed.

## The upstream `debian/` directory is kept verbatim and UNUSED

The imported tree carries JeffyCN's own `debian/` packaging directory
(`changelog`, `compat`, `control`, `copyright`, `rules`, and the four
`.dirs`/`.install` files). It is retained **byte-for-byte and never invoked**.

CeraLive's packaging is hand-rolled under `packaging/` and does not use
debhelper, so nothing in this repository reads `debian/`. It is kept for two
reasons: it is the upstream record of how Rockchip and JeffyCN versioned and laid
out the very packages this fork replaces, and deleting it would be an unnecessary
divergence from the imported tree. Do not build from it, do not "fix" it, and do
not delete it.

## File-level licence census

Generated by [`scripts/license-census.sh`](../scripts/license-census.sh), which
classifies **every tracked file** and **fails closed**: a file under a
`3rdparty/` path that has no explicit rule is reported as `UNKNOWN` and the script
exits non-zero. Re-run it after any import or vendored-file change.

```text
$ bash scripts/license-census.sh
tracked files scanned: 278
repository root licence file: COPYING (Apache License, Version 2.0)
UNKNOWN rows: 0
PASS: every tracked file is classified.
```

| Licence | Files | Holders |
|---|---|---|
| Apache-2.0 (in-file grant) | 134 | Rockchip Electronics Co., Ltd. (2016-2025, incl. "RockChip Limited" spellings); The Android Open Source Project; Google, Inc.; Zhiqin Wei; Jeffy Chen; Apache Software Foundation (the `COPYING` text itself) |
| Apache-2.0 (repository default via `COPYING`) | 130 | Rockchip Electronics Co., Ltd. |
| Apache-2.0 (CeraLive fork addition) | 2 | CeraLive contributors |
| **MIT/X11-style** | **7** | Precision Insight, Inc.; VA Linux Systems, Inc.; Intel Corporation; Dave Airlie; Jakob Bornecrantz; Red Hat Inc.; Tungsten Graphics, Inc. |
| **MIT/X11-style (prebuilt binary, no source in tree)** | **4** | freedesktop.org libdrm contributors |
| **GPL-3.0-or-later (CONFLICTS WITH `COPYING`)** | **1** | Fuzhou Rockchip Electronics Co., Ltd. (Putin Li, Bin Li) |

Total 278 (276 imported plus this file and the census script).

### The non-Apache files, in full

These are the rows that matter, so they are listed by path rather than counted.

**MIT/X11-style, bundled libdrm headers.** `meson.build` puts
`core/3rdparty/libdrm/include/drm` directly on the library's include path (and
`CMakeLists.txt` does the same), so this subtree is a build input to the shipped
library, not merely sample scaffolding:

| Path | Holders |
|---|---|
| `core/3rdparty/libdrm/include/drm/drm.h` | Precision Insight, Inc.; VA Linux Systems, Inc. |
| `core/3rdparty/libdrm/include/drm/drm_fourcc.h` | Intel Corporation |
| `core/3rdparty/libdrm/include/drm/drm_mode.h` | Dave Airlie; Jakob Bornecrantz; Red Hat Inc.; Tungsten Graphics, Inc.; Intel Corporation |
| `samples/utils/3rdparty/libdrm/include/libdrm/drm.h` | Precision Insight, Inc.; VA Linux Systems, Inc. |
| `samples/utils/3rdparty/libdrm/include/libdrm/drm_fourcc.h` | Intel Corporation |
| `samples/utils/3rdparty/libdrm/include/libdrm/drm_mode.h` | Dave Airlie; Jakob Bornecrantz; Red Hat Inc.; Tungsten Graphics, Inc.; Intel Corporation |
| `samples/utils/3rdparty/libdrm/include/xf86drm.h` | Precision Insight, Inc.; VA Linux Systems, Inc. |

**MIT/X11-style, prebuilt `libdrm.so` binaries with no corresponding source.**
Surfaced explicitly because a committed shared object is a redistribution
obligation that a source-header scan would miss entirely:

```text
samples/utils/3rdparty/libdrm/lib/arm32/libdrm.so
samples/utils/3rdparty/libdrm/lib/arm64/libdrm.so
samples/utils/3rdparty/libdrm/lib/android/arm32/libdrm.so
samples/utils/3rdparty/libdrm/lib/android/arm64/libdrm.so
```

All four carry ELF `SONAME: libdrm.so.2`. They are sample-only build inputs and
are **never packaged** by CeraLive; the shipped library links the system
`libdrm2`.

**GPL-3.0-or-later, one file, conflicting with the root licence.** `Android.mk`
at the repository root carries a full GNU General Public License v3-or-later
notice (Fuzhou Rockchip Electronics Co., Ltd., 2018; authors Putin Li and Bin Li)
while `COPYING` is Apache-2.0. This is an upstream inconsistency, imported as-is
and **not** resolved by this fork.

It is safe for our purposes for a narrow and stated reason: `Android.mk` is an
Android NDK build file. CeraLive builds with Meson for Linux, never invokes it,
and never ships it. It must therefore be **excluded from every distributed
artifact**, and `packaging/copyright` must not silently place it under the
`Files: *` Apache-2.0 stanza. This paragraph is the reason that exclusion exists;
do not remove it as a false positive.

**Android HAL headers under `core/3rdparty/android_hal/`.** Apache-2.0, The
Android Open Source Project. Only `system/graphics.h` carries the notice in-file;
`system/graphics-sw.h`, `system/graphics-base.h` and the three
`system/graphics-base-v1.x.h` hidl-gen outputs carry none and inherit it from
AOSP `system/core`. `hardware/hardware_rockchip.h` is a Rockchip addition to that
include set and falls under `COPYING`.

**`core/rga_sync.cpp` and `core/rga_sync.h`.** Apache-2.0, but the holders are
The Android Open Source Project (2017) and Google, Inc. (2012), not Rockchip.
Same licence as the root, different copyright holder, so they need their own
DEP-5 stanza.

### `COPYING` is retained verbatim

The upstream Apache License, Version 2.0 text is kept byte-for-byte at the
repository root:

```text
sha256  58f1fdcee3211f839f749c1ed97ca87fd56d9d01d729bb74241eca9e2ac710bc  COPYING
```

## Licence posture: Apache-2.0 library, LGPL-2.1 plugin

This library is Apache-2.0. The CeraLive GStreamer plugin that consumes it
(`gstreamer-rockchip`) is LGPL-2.1. That combination is **pre-existing and
unchanged by this fork**: the device already links a Radxa-built Apache-2.0
librga against the same LGPL-2.1 plugin today, and replacing the provider of
`librga.so.2` with a CeraLive build of the same upstream source changes neither
licence nor the direction of the linkage. Nothing in this repository alters that
posture, and no relicensing is performed or implied.

CeraLive modifications remain Apache-2.0. Per Apache-2.0 §4(b), a modified file
carries a notice line of the form
`// Modified by CeraLive <YYYY-MM-DD>: <why>`. No `NOTICE` file is invented;
upstream does not ship one.

## Upstream lineage and credits

This repository descends from Rockchip's `linux-rga` through JeffyCN's
`linux-rga-multi` mirror branch. CeraLive thanks:

- **Rockchip Electronics Co., Ltd.** and its contributors for the original RGA
  userspace library. The principal authors named in the tree and in upstream's
  own `debian/copyright` are **Zhiqin Wei** (`wzq@rock-chips.com`), **Putin Lee**
  (`putin.li@rock-chips.com`) and **Yu Qiaowei / Cerf Yu**
  (`cerf.yu@rock-chips.com`), who authors every commit in the R0 window above.
- **Jeffy Chen / JeffyCN** (`jeffy.chen@rock-chips.com`) for maintaining the
  `mirrors` repository and its `linux-rga-multi` branch, which is the tree this
  fork imports, and for the upstream `debian/` packaging retained here unused.
- **airockchip/librga** as the **header and CHANGELOG reference only**. That
  distribution is binary-only: it publishes headers and release notes but no
  buildable source for the library, so it is consulted for API documentation and
  release history and is **never** a source donor. Nothing in this repository is
  copied from it.
- **tsukumijima** for packaging ideas informing the CeraLive `packaging/` layout.
  Ideas only; no code is taken.
- **nyanmisaka** for downstream fixes that are **candidate** donors. Any pick is
  taken with `git cherry-pick -x`, keeps its original author, and is recorded in
  `docs/fix-audit.md` with a reproducer. No pick has been made in this commit.

The Android Open Source Project, Google, Inc., Intel Corporation, Precision
Insight, Inc., VA Linux Systems, Inc., Red Hat Inc., Tungsten Graphics, Inc.,
Dave Airlie and Jakob Bornecrantz hold copyright in the bundled subtrees listed
in the census above. Source headers remain authoritative in every case.

## What this document does NOT claim

Stated plainly, because provenance documents attract over-reading:

- It does not claim `R0_TIP` is the commit Radxa built. It claims the board's
  binary reports the same API release, and lists in the census what else that
  does and does not license.
- It does not claim byte-identical source with the board's `librga.so.2.1.0`. R0
  neutrality is bounded to (a), (b) and (c) above.
- It does not resolve the `Android.mk` licence conflict. It records it, and
  requires the file's exclusion from every distributed artifact.
- It does not relicense anything, and it does not rewrite an upstream notice.
- It does not certify that any imported file is correct. Correctness is the test
  suite's job and the board drills'; this document only certifies where the bytes
  came from and under what terms.
