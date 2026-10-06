<!-- Moved verbatim from AGENTS.md on 2026-10-05 by lean-rules-docs-landing-latam -->

## Licensing

The librga code proper is **Apache-2.0** (`COPYING`, retained byte-for-byte at the
repository root), **with documented third-party exceptions**. The exceptions are
not a formality: the todo-7 file-level census in
[`docs/PROVENANCE.md`](../PROVENANCE.md) classifies all 278 tracked files and
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
[`README.md`](../../README.md) and, in full, in `docs/PROVENANCE.md`.

