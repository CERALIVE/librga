# R1 full709 selector recovery — 2026-09-15

**[EXISTS] Selector fix and isolated OPi pixel proof. Not G-B or release approval.**

This repairs an **upstream** regression introduced by
[`2aa0ab4d8374d630bed628f8fb6dead9076eae7c`](https://github.com/CERALIVE/librga/commit/2aa0ab4d8374d630bed628f8fb6dead9076eae7c)
(“im2d_api: support both constant_csc & full_csc config”), not the CeraLive donor
port. The starting tree is `099ee2d4b0044e0ce044489e78c4f9cbddfc41d1`.
Keep this regression test when syncing upstream.

## Change and failing-first regression

`generate_blit_req()` seeds ordinary RGB→YUV with BT.601-limited selector 8.
Explicit limited709 already replaces it with 12. Full709 previously retained 8
alongside its correct full-CSC coefficients. The fix adds only the full709
assignment `r2y_mode = 0`; the final `r2y_mode | y2r_mode` remains unchanged.
No coefficient, default, public layout, SONAME, visibility or legacy API changes.

The existing shared-library `donor-full-csc` test now asserts:

- RGB and BGR → NV12: default/601-limited/601-full/709-limited/full709 selectors
  **8/8/4/12/0**, successful submission and exactly one captured request.
- Full709 retains all twelve coefficient values, full-CSC enable and clip-enable.
- Combined im2d source601-full + RGB overlay + destination709-full retains source
  Y2R selector **2**, without destination selector 8. Its previous expectation of
  **10** characterized the upstream bug; this is a corrected expected result,
  not deletion of the donor test. The two legacy donor controls remain unchanged.

Before the fix, the new assertions were RED: RGB/BGR full709 were 8 instead of
0, and combined im2d was 10 instead of 2. Every adjacent control passed. After
the fix, all 13 rows passed. Commands:

```sh
meson setup test-results/full709-host -Dlibdrm=false -Dlibrga_demo=false -Dcpp_args=-fpermissive
meson compile -C test-results/full709-host donor-full-csc fake_rga
meson test -C test-results/full709-host donor-full-csc --print-errorlogs
```

This native-LP64 diagnostic recipe uses the existing host compatibility flag;
it is not a shipping compiler configuration. The initial attempt without that
flag failed to compile inherited pointer casts and was **not** counted as RED.
Arm64 library/probe builds used Debian Trixie GCC 14.2.0.

## Decisive experiment: unchanged artifact, client and buffers

The [evidence archive](full709-selector-evidence.tar.xz) contains raw original
and forwarded requests, input/output pixels, client output, per-call counters,
package/hash comparisons, the offline verifier and its results. No board network
identity or credentials are included.

Archive SHA-256: `85056262d6fd1d3658e5782abef461e1b05dc90d91a0532e157eaadb1aabffe4`.

The retained G-A client is unchanged. Its four iterations reuse the same source
and destination DMA-BUFs within each cell, poison output before each conversion,
and perform CPU synchronization. Per-process `LD_LIBRARY_PATH` selects extracted
libraries. The non-installed forwarding probe
[`tests/board/full709-selector.c`](../tests/board/full709-selector.c) changes
only full709's ordinary selector at ioctl submission; it generates no pixels and
never fakes an ioctl result or driver capability. It records each real request
and selected core through counter deltas. Full709 stays on core index 2 (RGA2),
with **0/0/1** deltas for every intervention and control iteration.

| Artifact | SHA-256 |
|---|---|
| Unchanged retained G-A client | `59dde7eb0de8f9d2bc81cc9daf71e5d17f4c5cd5ec941d97cb494f9d1f19c586` |
| Unchanged retained R1 package library | `e2b571ed816aba48437ac385ea7053890becc3b9d800c4ac88b44624cd059db4` |
| Fixed local arm64 shared library (not installed/published) | `593d3ab9a0cb83e7aacdb423d8d5be2947f4b771abd74cdc417288900bf7c0d1` |
| Forwarding probe | `a61c4a67b39c7e85b109a708a5873079a7cf97e3145508efce218c1077b7d396` |
| Common 1280×720 BGR input | `39528df1d46ce2ef6f3fd51b00355025e5ae9afe0dd15367cdd9f808eab1db4a` |

### Pixel results (dB)

| Run | Ordinary full709 selectors, iterations 0–3 | Full709 PSNR, iterations 0–3 |
|---|---|---|
| Retained R1, toggle | 8 / 0 / 8 / 0 | **33.977872 / 50.689414 / 33.977872 / 50.689414** |
| Fixed R1, no selector change | 0 / 0 / 0 / 0 | **50.689414 / 50.689414 / 50.689414 / 50.689414** |
| Fixed R1, reverse intervention | 0 / 8 / 0 / 8 | **50.689414 / 33.977872 / 50.689414 / 33.977872** |

Selector 0 recovers **16.711542 dB**, exactly the recorded Radxa/R0 PSNR
**50.689414 dB** for this corpus. This is a new R1 pixel measurement compared
with the retained Radxa/R0 score, not a fresh Radxa/R0 board run.

| Control | Every iteration, all three runs |
|---|---:|
| BT.601 limited | 52.776426 |
| BT.601 full | 53.468170 |
| BT.709 limited | 52.904279 |
| Default BGR→NV12 | 52.776426 |

All five other geometry/default cells also completed four iterations with
unchanged scores. No D24 classification is derived from these cells.

### Causal controls and independent checks

The verifier passed **666 assertions**. It compares all 504 bytes of each
original/forwarded request, permitting only byte 274 to change on full709;
control requests must be byte-identical, with no padding normalization. Within
each toggle run, all four original full709 requests are byte-identical, and the
input/output fd, device, inode and size identities stay the same. All captured
input bytes are equal, including across the three libraries/runs. Output bytes
for the same colour mode and selector are equal across runs, not merely close
in PSNR. Full709 output hashes:

- Selector 0: `b89ed84db9c097eef9e487ff04b8c47e042825cb7ef4fa65474d4b8cf774e682`
- Selector 8: `0bf2f268ae2fc15de56d3726b921b76adcf0d928e5b10bb71cdcfad7501a6e44`

The strongest counter-case was that recovery came from different buffers, core
routing or a rebuilt artifact rather than the selector. The retained-library
8→0→8→0 intervention rules those out; forcing the fixed artifact back to 8
recreates exactly the bad output bytes. Combined-CSC host coverage separately
guards against accidentally clearing source Y2R.

The archive's `rescore.c` independently scores captured pixels against the
unchanged repository colour oracle. Compile it with the **same arm64 GCC 14.2.0
toolchain** as the retained client: the first GCC 16 x86 rescore rejected exact
equality (e.g. full601 53.481074 versus 53.468170), while matched arm64 scoring
reproduced every six-decimal result. Floating-point reference evaluation is
toolchain-sensitive; no oracle formula, tolerance or production coefficient was
changed to hide that difference.

Host-only replay, from the repository root in that arm64 toolchain environment:

```sh
mkdir -p test-results/full709-replay
tar -xJf docs/full709-selector-evidence.tar.xz -C test-results/full709-replay
gcc -O2 -Wall -Wextra -Werror -Itests/oracle \
  test-results/full709-replay/rescore.c tests/oracle/oracle.c -lm \
  -o test-results/full709-replay/rescore
perl test-results/full709-replay/verify.pl \
  test-results/full709-replay/results test-results/full709-replay/rescore
```

For an explicitly admitted future board run, compile the probe with `-shared
-fPIC -Iinclude -Iim2d_api -Icore/hardware -ldl`. Supply an existing fresh
`RGA_SELECTOR_DIR`, `CERALIVE_BOARD_TEST=1`, `RGA_FULL709_EXPECT=8` (retained) or
`0` (fixed), and a four-character `RGA_FULL709_SEQUENCE` containing only 0/8.
Preload it **only into** the retained single-threaded synchronous G-A client with
`--improcess-only --iterations 4 --explicit-csc`, under the board lock. The
archive's `remote.sh` records the exact runner, not authority to access a board.

## Proof boundary and outstanding review

Local checks passed: 37/37 native non-UAPI tests (no skips), both arm64 UAPI
checks, the required host-shim sanitizer suites (11 ASan/UBSan baseline, six
H10, six TSan concurrency cases, with positive sanitizer canaries), and the
expanded CSC test under ASan/UBSan. Scoped arm64 werror compiled 33 translation
units without suppression flags; analyzer compiled 17 library units with zero
untriaged findings. Fresh-output package contract and ABI floors passed. The
arm64 emulation suite's two existing invalid-fd ioctl skips are covered by the
native run, not waived; native arm64 CI remains the complete PR authority.

- Only **OPi**, production B, kernel `7.2.0-ceralive-rk3588`, was exercised.
  Rock was deliberately untouched. No new Rock or both-board qualification.
- Installed `librga2 2.2.0-1` and `gstreamer1.0-rockchip-ceralive
  1.14.4+ceralive.5` records and the installed librga hash were unchanged.
  Kernel taint was 0 before/after. No package operation, `/usr` remount or driver
  unload/reload occurred. These are **isolated**, not package-install passes.
- The unchanged client exits **1** at its existing cold-session census **5→6**
  in all three runs. All nine pixel cells complete; this does not waive that
  separate gate defect or convert the client/G-A verdict into PASS.
- H7 remains platform qualification work. **G-B and todo 43 remain blocked**;
  no R1 tag, release or merge is authorized. No D24 expected-FAIL cell is FIXED,
  and no empty-set waiver is taken.
- The fix requires a different-agent, different-model review receipt before
  merge. Pending that receipt, this document is evidence, not an approved D21
  GREEN row. No approval identity is fabricated and no ledger check is weakened.
