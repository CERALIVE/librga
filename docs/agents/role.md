<!-- Moved verbatim from AGENTS.md on 2026-10-05 by lean-rules-docs-landing-latam -->

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
| **R0** `1.10.1+ceralive.1` | `5a97e650a30b7c7036eb5aa26e39f2d09f18fcc9` | A rebuild of the API release the bench boards ran before the fork (Radxa `librga2 2.2.0-1`, `rga_api 1.10.1_[4]`), with packaging and CI commits only. Its neutrality claim is **bounded** to export-set containment, request-byte goldens on the CeraLive call set, and both-board gate rows. Never "byte-identical source". |
| **R1** `1.10.5+ceralive.1` | `57a1067a246c71fa6c9a355d1668884fda155dd5` | The pinned fork point plus the fix series that Wave 0 actually turned RED. |

Shipped reality, recorded 2026-09-21. Both releases are published and both package
pairs are served by `apt.ceralive.tv`. `image-building-pipeline` master pins **R1**
(`librga2-ceralive_1.10.5+ceralive.1`, image PR #172, the R0 row commented above it
as the rollback), and that pin is what the boards run: on 2026-09-21 the Rock 5B+ and
the Orange Pi 5+ each promoted the image built from it to RAUC slot A, booted it with
`systemctl --failed` empty and `ceralive-healthcheck.service` self-marking the slot
good, and read `librga2-ceralive 1.10.5+ceralive.1` back through `dpkg-query` on the
booted slot, alongside `gstreamer1.0-rockchip-ceralive 1.14.4+ceralive.7`, `cerastream
2026.9.6` and the island `v2026.9.5` kernel. "The bench boards run today" therefore
means R1. That boot is an installed-library receipt and nothing more: the
[R1 both-board results](../../tests/board/DRILL-RESULTS.md) stay a post-release record with
the acceptance gaps they list, and no row below is closed by it.

