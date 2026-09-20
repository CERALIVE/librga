# Handle-mode plane identity

`generate_blit_req()` reuses its `srcFd`/`dstFd`/`src1Fd` variables for imported
handle IDs. That assignment is correct. In the multi-RGA branch, however,
`NormalRgaSet*VirtualInfo()` also received `NULL + vir_w * vir_h` as `v_addr`.
With `handle_flag & 1`, the island interprets every nonzero plane address as a
handle ID. Thus 1920×1080 produces `This handle[2073600] is illegal`, even
though `importbuffer_fd()` returned an ordinary small ID.

The repair zeros only this synthesized offset in handle mode, for source,
destination and pattern. The one imported allocation remains in `yrgb_addr`.
FD and virtual-address request encoding is unchanged. No public API, struct,
colour/interpolation/log default, MPP binary or kernel change is involved.

## Regression

`handle-planes` links the real shared library and uses the existing fake-device
ioctl recorder. It calls both `improcess` and `improcessOpt`, imports mock-returned
IDs, and inspects the emitted request for RGBA, 1080p/4K NV16→NV12 and a
three-channel blend. FD and virtual-address controls retain their old encoding.

On unchanged main `684fc1d`, the new test reported:

```text
src yrgb=4 uv=0 v=2073600 expected=4,0,0 FAIL
```

After the repair it passes, as do the existing request goldens. The full arm64
container suite ran 46 PASS, 2 documented QEMU invalid-fd SKIPs, zero failures.
The skips are not native ioctl coverage. This result is host-shim evidence,
not pixel qualification.

## Rock 5B+ — 2026-09-19

Kernel `7.2.0-ceralive-rk3588`, installed released R1 `1.10.5+ceralive.1`.
The unchanged gstreamer-rockchip `c6b-im2d-bench.c` at `21a7cc1a` reproduced
440/440 handle refusals at 1080p, FD control all passing. Single-plane RGBA
also failed by handle (IDs 441/442) and passed by FD.

The repaired library was selected through per-process `LD_LIBRARY_PATH`, never
installed. Candidate ELF SHA256:
`faea4c91a2e3e1d43034eff1747715c53ef1faecb1f3e9b1f707712d45e342e8`.

| Workload | FD µs/frame | Handle µs/frame | FD fps | Handle fps | Handle refusals |
|---|---:|---:|---:|---:|---:|
| 3840×2160 NV16→NV12 | 4820.58 | 3238.31 | 207.4 | 308.8 | 0/440 |
| 1920×1080 NV16→NV12 | 1333.51 | 799.75 | 749.9 | 1250.4 | 0/440 |

Both RGBA controls pass with the repair. Selecting the original provider again
restores failure 2/2 while FD succeeds: a real repro→fix→reverify→negative-control
cycle. Installed provider SHA256 remained
`07b6b6c466c6bddbcf7006e5b678d68de372b44686e6eb8ea3fcf00ce1cb6b74`;
engine/UI stayed active and session scratch was removed. Captured logs contain
no `RGA_BLIT fail`, KASAN or `BUG:` matches.

These numbers measure direct API throughput, not a plugin import cache or
userspace CPU share. OPi was reserved to another investigation and not touched.
No both-board adoption, d2/d4/d5 qualification, release or image pin is claimed.
