# G-A: R0 neutrality — 2026-09-05

**Overall verdict: BLOCKED. Do not merge or release R0 on this evidence.**

Both boards were reached at their current addresses. Rock 5B+ failed the driver
precondition. Orange Pi ran R1–R7, including a bounded 4K soak, and was restored
to Radxa by the EXIT cleanup. Pixel neutrality alone is not an overall PASS.

## Artifact and execution identity

- Open PR: <https://github.com/CERALIVE/librga/pull/2>.
- Latest successful Build Check at download: **33972791251**, head
  `a006ba4b5a6a07e7f8bad955b2523f16e2b40e6e`.
- Download: `gh run download 33972791251 --repo CERALIVE/librga --name dist`.
- Runtime: `librga2-ceralive_1.10.1+ceralive.1_arm64.deb`, SHA-256
  `ad78d36a71f35b83285697c485ef8b85977e089ff7972b57b203a4bcbfd91fab`.
- Development artifact (downloaded, **not installed**): SHA-256
  `6218bb1ed1c44206ff5f06ae76269a055d728dbd5816ee6ef5fc136ea261b0a7`.
- Radxa rollback: `librga2_2.2.0-1_arm64.deb`, fetched from the URL in
  `docs/ROLLBACK.md`, SHA-256
  `ca4f18666f6c5d5290c7e41e5901350ecf76530f24364e37b81fa6be4ab5f344`.
- Both observed kernels: `7.2.0-ceralive-rk3588`.
- Island UAPI reference: **v2026.9.2**. Installed island tag is **unverified**:
  there is no `rk3588-media-island` dpkg package on Orange Pi. Driver version is
  measured below, not inferred from this reference tag.
- Harness built with the existing Trixie arm64 build container. Bench SHA-256:
  `d5f88a865457d7f5938735f1d59db69c0371eec4ed66bb02f0ea3d87eb009611`;
  probe SHA-256:
  `41e58b7b5a8231b537fd4328ddf3843bd9abd96f8a65c199aba144a56c3fe94d`.
- No locally rebuilt shared library was staged or substituted. New processes
  loaded the installed package. Existing services were not restarted or modified.

## Rock 5B+ — 192.168.78.131

**PRECONDITION-FAIL**, not an unreachable-board result. The first network
operation of this task was the required real precheck at the corrected IP:

```text
7.2.0-ceralive-rk3588
rockchip_rga           28672  0
ls: cannot access '/dev/rga': No such file or directory
```

The final script invocation with the supplied strict known-hosts file reproduced
the same result. An intermediate invocation used the default known-hosts file,
which contained a stale key and refused SSH; that transport failure does not
override the successful precheck. No host key was replaced and strict verification
was not disabled in the drill.

| Row | Result |
|---|---|
| R1 package replacement | NOT-RUN: precondition failed |
| R2 plugin registration | NOT-RUN: precondition failed |
| R3 per-core routing | NOT-RUN: precondition failed |
| R4 encode smoke | NOT-RUN: precondition failed |
| R5 pixel matrix | NOT-RUN: precondition failed |
| R6 soak | NOT-RUN: precondition failed |
| R7 rollback | NOT-NEEDED: no package installation or board mutation |

No modprobe, driver configuration, kernel, RAUC, or service operation was attempted.

## Orange Pi 5+ — 192.168.78.151

Precondition PASS: expected kernel, `rga_multicore 671744`, `/dev/rga` character
device. Fork-owned probe: `driver=1.3.11 text=1.3.11`, API `1.10.1_[4]`.
Sudo required the environment-supplied password; no credential is in this report.

| Row | Result | Actual observation |
|---|---|---|
| R1 | PASS | R0 runtime installed; real `librga2` not installed; dpkg owns our library and ldconfig resolves the SONAME. |
| R2 | PASS | `gstreamer1.0-rockchip-ceralive 1.14.4+ceralive.1` stays installed; `gst-inspect-1.0 mpph264enc` succeeds. |
| R3 | FAIL (fd assertion); routing subcheck PASS | All three masks complete 1000/1000 exact copies. Per-core deltas are exactly the selected core +1000, others +0; see COUNTERS.md. Each process reports fd 4→5 and exits 1. |
| R4 | FAIL (required log absent) | RGB16 1920×1080, 300 input buffers, reaches EOS and exits 0; zero `RGA_BLIT fail`. Required canonical conversion log is absent. |
| R5 | FAIL (fd assertion); pixel subcheck PASS | All five required cells and four supplemental explicit-CSC cells agree exactly with same-session Radxa; both processes report fd 4→5 and exit 1. |
| R6 | FAIL (fd assertion) | 295-second deadline, 299-second process timeout; 3857 successful 4K NV16→NV12 iterations, zero conversion/oracle failures, but fd 4→5. |
| R7 | PASS | EXIT trap apt rollback exits 0; `librga2 2.2.0-1` installed, R0 removed, ldconfig resolves restored Radxa file; SHA-256 verified. |

The fd increase is an unresolved measurement, not proof of a growing leak and not
waived as initialization noise. The pre-existing census remains unchanged.
No claim of flat fd count is made. The same 4→5 occurs with Radxa and R0.

RGB16 is deliberately mapped to `MPP_FMT_BUTT` in canonical
`gst/rockchipmpp/gstmpp.c` (the encoder consults that table and selects NV12).
The exact required source log in its `c_RkRgaBlit` success path is
`GST_DEBUG ("converted with RGA");`. The actual transcript only establishes
`gstmpp.c:123:gst_mpp_use_rga: RGA enabled` and NV12 format/alignment messages.
That is insufficient to quote a conversion-success line or declare R4 PASS.

### R5 same-session PSNR (dB)

| Cell | Radxa | R0 | Absolute delta |
|---|---:|---:|---:|
| NV16→NV12 | 61.607624 | 61.607624 | 0.000000 |
| BGR→NV12 | 52.776426 | 52.776426 | 0.000000 |
| NV12 4K→1080p | 59.677191 | 59.677191 | 0.000000 |
| NV12 crop | infinity | infinity | exact oracle match on both |
| NV12 rotate 90 | infinity | infinity | exact oracle match on both |
| Explicit BT.601 limited | 52.776426 | 52.776426 | 0.000000 |
| Explicit BT.601 full | 53.481074 | 53.481074 | 0.000000 |
| Explicit BT.709 limited | 52.904279 | 52.904279 | 0.000000 |
| Explicit BT.709 full | 50.687602 | 50.687602 | 0.000000 |

The numerical oracle, default interpolation, and 30 dB threshold were not changed.
The known G8 `full_csc` request-byte divergence from todo 15 remains unresolved:
these finite pixel observations neither explain it nor invalidate that finding.

### Restoration and retained evidence

Two full attempts were run. The first exposed that errexit prevented post-counter
capture after the fd assertion failed. The second captures counters even on bench
failure. Its scorer initially used awk's reserved `index` name; this was corrected
to `selected` and the corrected expression was run against the retained final
logs, proving all three exact deltas without another hardware/package run.
Both attempts restored Radxa through the EXIT stack; neither left R0 installed.

Final rollback evidence:

```text
Removing librga2-ceralive (1.10.1+ceralive.1) ...
Setting up librga2 (2.2.0-1) ...
Status: install ok installed
Version: 2.2.0-1
librga.so.2 (libc6,AArch64) => /lib/aarch64-linux-gnu/librga.so.2
R7 restore exit=0
```

Restored real file: `/usr/lib/aarch64-linux-gnu/librga.so.2.1.0`, SHA-256
`0b455344259c37fec821955e2de85bb5f76a34e69682217b514c407d8a35c6c3`.
Raw per-row logs are retained in `build/g-a-opi/` and `build/g-a-opi-final/`.

## Local verification

Trixie arm64 harness rebuild succeeds. Complete Meson suite: 13 OK, zero failures,
two documented opt-in QEMU skips (`shim-contract`, `board-timing`), not native
sanitizer coverage. ShellCheck and C/shell LSP error diagnostics are clean.
lib.sh selftest proves exclusion, LIFO cleanup, and foreign-marker refusal.
No opt-in exits 77; actual `192.0.2.1` negative control exits 77 with
`SKIPPED-unreachable`. The final counter parser passes on all three retained logs.

## The suite does NOT prove

The following scope block is retained from gstreamer-rockchip's board contract:

- Hardware not named by the transcript, including the separate mainline/edge 7.2
  fleet when a drill runs on the vendor 6.1 bench board.
- Long-term thermal, suspend/resume, OTA, or every capture-device path.
- That an `INCONCLUSIVE` d3 result authorizes a stride change. d3 is report-only;
  no shipped stride edit follows without decisive evidence and separate review.
- The pre-existing 4K59.94 H.265 SIGSEGV. That fault is out of scope and must not
  be chased or reclassified by these drills.
- ThreadSanitizer or LeakSanitizer cleanliness. TSAN cannot start under the known
  qemu-user VMA layout and LSan cannot complete there; deterministic mock seams
  and counters substitute only for the specific properties they assert.
- A result from an unreachable board. Such a run is `SKIPPED-unreachable` with an
  attempt transcript, never PASS.

G-A additionally proves nothing about `rgaconvert`, `rgacompositor`, or
`d5-rgaconvert-matrix.sh`: those are on the island effort's unmerged branch, not
canonical gstreamer-rockchip main's nine-factory set. Every pixel row here uses
this fork's DMA-BUF improcess harness and independent software oracle. TSan,
ASan, and UBSan are host-shim-only, never claimed as board coverage.
