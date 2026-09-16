# R0 known limitation: blending onto a YUV destination [EXISTS]

This page is for anyone who installed `librga2-ceralive 1.10.1+ceralive.1`
(the release called **R0**) from GitHub or `apt.ceralive.tv`. It describes one
specific thing R0 refuses to do that it should accept, how you will recognise
it, what still works, and where the fix stands. It is not a deprecation notice.
R0 is a useful, validated package. It has one boundary you deserve to know about
before you run into it.

## The short version

R0 rejects a **three-channel alpha blend whose destination is a YUV format**,
even when a valid RGB buffer is supplied as the background. The call returns
`IM_STATUS_NOT_SUPPORTED` (`-1`) without touching the hardware. In practice that
means picture-in-picture or side-by-side composition straight into an NV12
frame, the kind an encoder wants, does not work on R0.

Everything else works exactly as it did before: scaling, cropping, format
conversion, rotation, colour-space conversion, and blends whose destination is
an RGB format.

## What exactly is rejected

The im2d API has two blend shapes, and the upstream developer guide is clear
about which formats each accepts:

| Shape | Calls | Background is | YUV destination |
|---|---|---|---|
| Two-channel, `A + B -> B` | `imblend`, `improcess` with no pattern buffer | the destination itself | **Not supported, by design, in every version.** The destination is the background and the background must be RGB. |
| Three-channel, `A + B -> C` | `imcomposite`, `imcheck_composite`, `improcess` with a pattern buffer and an `IM_ALPHA_BLEND_*` usage flag | the pattern buffer (`srcB` / `pat`) | **Should be accepted when the pattern is RGB. R0 rejects it.** This is the limitation. |

So the affected case is narrow: a three-channel composite, RGB foreground and
RGB background, written to an NV12 (or any other YUV) output. Two-channel blends
onto YUV were never supported and are not what this page is about.

## Why R0 does this

The validator in `im2d_api/src/im2d_impl.cpp`, function `rga_check_blend`,
reads as follows in R0 (commit `86b91792` on `release/1.10.1`):

```cpp
/* bg format check */
if (rga_is_buffer_valid(pat) && !pat_isRGB) {
    IM_LOGW("Blend mode background layer unsupport non-RGB format, pat format = %#x(%s)", ...);
    return IM_STATUS_NOT_SUPPORTED;
} else if (!dst_isRGB) {
    IM_LOGW("Blend mode background layer unsupport non-RGB format, dst format = %#x(%s)", ...);
    return IM_STATUS_NOT_SUPPORTED;
}
```

The format classifier (`NormalRgaIsRgbFormat`) is correct: it returns false for
NV12. The problem is the control flow. When a valid RGB pattern is present, the
first condition is false, execution falls into the `else if`, and the
*destination* is tested as though it were the background. The pattern already
supplied an RGB background, so the destination's format should not matter here.
The warning text even says "background layer" while printing the destination's
format, which is the giveaway if you ever see it.

Rockchip fixed this upstream in `1.10.1_[6]`
([`fc3f742a`](https://github.com/CERALIVE/librga/commit/fc3f742a7be43c62c9eb3e17a007f957b0e7db83),
"fix wrong check dst-channel format in 3-channel mode", September 2024). That
commit's parent is exactly R0's source base, `1.10.1_[4]`. R0 is a rebuild of
the last upstream point release before the fix, which is how it inherits the
bug.

## What it looks like when you hit it

From your own code:

- `imcomposite`, `imcheck_composite`, or `improcess` returns `-1`
  (`IM_STATUS_NOT_SUPPORTED`).
- `imStrError()` returns
  `Blend mode background layer unsupport non-RGB format, dst format = 0xa00(NV12)`
  or similar. With `ROCKCHIP_RGA_LOG=1` the same line is printed to standard
  output.
- No RGA job is submitted. The kernel driver never sees the request, so
  `dmesg` and the RGA debugfs counters show nothing.

From a GStreamer or streaming pipeline built on top of librga, the failure is
less obvious. The pipeline can reach PLAYING, the encoder can produce a
bitstream, and the picture is a **solid green frame** (the all-zero NV12 buffer
that was never written). In CeraLive's own stack the engine reported
`the driver-probed RGA backend rejected the composite pass` and the stream
showed nothing but green. Nothing in that symptom says "format support", which
is why it is written down here.

## What R0 is, and what it is good for

R0 is a rebuild of the same im2d API release that Radxa's `librga2 2.2.0-1`
package ships, `rga_api version 1.10.1_[4]`, packaged as `librga2-ceralive`
(runtime) and `librga-ceralive-dev` (headers and `librga.pc`).

- **Drop-in.** SONAME `librga.so.2` is unchanged and the runtime declares
  `Provides: librga2 (= 2.2.0)` with `Conflicts`/`Replaces: librga2`. It
  substitutes for the Radxa package without relinking anything.
- **Additive only.** Nothing was stripped. The Android, RT-Thread and other-SoC
  build trees stay. The legacy `RockchipRga` / `c_RkRga*` API stays. Every one
  of Radxa's 254 global exports is present. `LIBRGA_STRICT_DRIVER=1` is a
  default-off opt-in.
- **Measured against Radxa on two RK3588 boards** (Rock 5B+ and Orange Pi 5+,
  same session, same kernel). Every conversion cell the bench compares, nine in
  all covering NV16 to NV12, BGR to NV12, 4K to 1080p scaling, crop, 90-degree
  rotation and four explicit colour matrices, produced the same PSNR as Radxa's
  build to six decimal places, with a 0.000000 dB per-board difference. A
  one-hour conversion soak completed 139,031 iterations on the Rock and 140,572
  on the Orange Pi with the open file-descriptor count unchanged before and
  after (5 to 5, strict equality). Both boards were restored to the Radxa
  package afterwards and re-checked. The record is
  [`tests/board/DRILL-RESULTS.md`](../tests/board/DRILL-RESULTS.md) and the
  2026-09-12 receipt on
  [PR #2](https://github.com/CERALIVE/librga/pull/2#issuecomment-5649766546).
- **Built from auditable source** under CeraLive's CI, with the import
  coordinate and licence census in [`PROVENANCE.md`](PROVENANCE.md) and the
  bounded neutrality claim in [`R0-NEUTRALITY.md`](R0-NEUTRALITY.md).

If your use of RGA is scaling, cropping, converting, rotating or blending onto
an RGB surface, R0 behaves like the vendor binary it replaces, and you get a
buildable, reviewable source tree in exchange. That is most RGA use.

One packaging fact worth knowing: the R0 runtime depends on `libc6 (>= 2.38)`.
It installs on Debian 13 (Trixie) and newer. Debian 12 (Bookworm) will refuse it
at `apt install` time with an unmet-dependency error; that is a build-suite
consequence, not a runtime crash.

## Workarounds on R0

- **Composite onto an RGB destination, then convert.** Blend into a BGRA or
  RGBA buffer of the output size, then run a second `improcess` to convert that
  buffer to NV12. This costs one extra RGA pass and one extra buffer.
- **Do not attempt to bypass the check.** The rejection happens before any
  ioctl, so there is no driver-side flag to flip, and patching the library to
  skip `rga_check_blend` also removes the checks that are correct.

## Status of the fix

The next release, **R1** (`1.10.5+ceralive.1`), is based on upstream `1.10.5`,
which already carries Rockchip's reordered check: the destination format is only
tested when there is no pattern buffer. R1 additionally corrects a separate
classifier mistake in the same function so that a YUV *pattern* is still
rejected as the documented contract requires. On R1 the RGB-background, NV12-
destination composite is accepted, and a real picture-in-picture frame has been
decoded from an Orange Pi 5+ pipeline running the candidate library.

**R1 is not released.** No date is committed. Until a release exists on the
[releases page](https://github.com/CERALIVE/librga/releases), R0 is the only
CeraLive librga you can install, and this limitation applies to it.

## In one table

| | R0 `1.10.1+ceralive.1` | Radxa `librga2 2.2.0-1` | Upstream `1.10.1_[6]` and later |
|---|---|---|---|
| Scale / crop / convert / rotate / CSC | works | works | works |
| Two-channel blend onto RGB destination | works | works | works |
| Two-channel blend onto YUV destination | rejected, by design | rejected, by design | rejected, by design |
| Three-channel composite, RGB background, RGB destination | works | works | works |
| **Three-channel composite, RGB background, YUV destination** | **rejected (this page)** | expected rejected, see note | accepted |
| Three-channel composite, YUV background | rejected, by design | rejected, by design | rejected, by design |

Note on the Radxa column: that package reports `rga_api version 1.10.1_[4]`,
the same point release R0 rebuilds, and the upstream fix arrived two point
releases later. The same rejection is therefore expected there. It has not been
separately measured on the Radxa binary, so treat that one cell as an inference
from the version string rather than a test result. Either way, replacing Radxa's
package with R0 neither adds nor removes this limitation.
