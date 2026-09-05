# R0 candidate: bounded neutrality [PARTIAL]

Base: `5a97e650a30b7c7036eb5aa26e39f2d09f18fcc9`, API `1.10.1_[4]`.
Package version: `1.10.1+ceralive.1`. No library implementation, public header,
default, or installed target flags were changed. The release branch stays at
the base; only the integration branch receives tier-(c) infrastructure.

## Bootstrap adaptations

All fourteen non-merge bootstrap commits were replayed with `cherry-pick -x`,
without conflicts. The commits titled `fix(packaging)` and `fix(ci)` correct
infrastructure only; they are not library fixes.

- `unit-session` uses header-version guards for the absent `im2d_context.h`,
  `get_rga_session`, and rectangular `rga_info_resolution_t` API. The 22
  post-1.10.1 resolution assertions are explicitly not applicable; the other
  63 assertions run. The original later-version expectations remain guarded.
- Two characterization expectations differ on this older implementation:
  zero-height crop is accepted, and the legacy BT.709 selector does not load
  a full-CSC matrix. The tests assert these existing behaviors, not fixes.
- The parity emitter cannot reference the absent Gaussian type/member. The
  comparator pins all seven island-only Gaussian measurements and both reserved
  region differences (offset 480/460, size 24/39). Both requests remain 504 bytes.
  Existing OSD divergences remain pinned. See `UAPI-PARITY.md` for the full table.
- `golden-cases-dynamic` links the uninstrumented shared library, unlike the
  existing static, zero-initialized source-golden client. It uses the same case
  source and permits a genuine `LD_LIBRARY_PATH` A/B test. The static goldens
  are unchanged; their instrumentation is not proof about packaged bytes.

## Measurements, 2026-09-05

Target-suite local CI equivalent: Debian Trixie arm64, GCC 14.2 under QEMU;
13 tests passed, two existing narrowly gated QEMU skips, zero failures.
Package contract, staged contract, and ABI floor checks passed.

1. **Non-weak export containment: PASS.** `LC_ALL=C comm -23` against the
   committed 254-symbol Radxa baseline is empty. The baseline deliberately
   excludes weak template/toolchain symbols; it is not a 274-symbol assertion.
2. **Plain ELF export abidiff: FAIL against the literal acceptance criterion.**
   Comparing stripped Radxa with `build/librga.so.2.1.0` reports 0 removed
   functions and variables, but one removed function symbol:
   `_ZNKSt5ctypeIcE8do_widenEc` (weak in Radxa). Exit 12 includes incompatible
   change bit 8. This is an ELF EXPORT check only: missing Radxa DWARF cannot
   establish signature or type-layout compatibility. Added debug-described
   functions are not evidence of an API addition. No suppression was used.
3. **Real Orange Pi golden comparison: FAIL for G8; G1–G7 PASS.** Kernel
   `7.2.0-ceralive-rk3588`; installed Radxa `librga2 2.2.0-1` remained untouched.
   The same dynamically linked client and fake-device shim ran separately with
   each library. All sixteen processes completed and emitted 504 bytes each.
   `cmp` returns 0 for G1–G7 and 1 for G8, differing at one-based positions
   310, 311, 312, 319, 320, 343, 344. Both APIs support G6 and G8, so neither
   can be excluded. Uninitialized CSC padding is a known source-golden concern,
   but this measurement alone does not prove the cause of every differing byte.
   No byte masking, installed package changes, or actual RGA ioctl occurred.
4. **Reproducibility: PASS at a fixed build path and epoch.** Two complete
   package builds at `/src`, `SOURCE_DATE_EPOCH=1788618000`, gave identical files:

   ```text
   74f41eb4c6f06d98e545515353a52d3289c16f08d6e21359ec0d8699c7ce2320  librga2-ceralive_1.10.1+ceralive.1_arm64.deb
   63f71e036a338ae8c457e1f2abbd47b5af13c6023e546f6835ac48361ae31f44  librga-ceralive-dev_1.10.1+ceralive.1_arm64.deb
   ```

Compared libraries:

```text
Radxa 0b455344259c37fec821955e2de85bb5f76a34e69682217b514c407d8a35c6c3
R0    b5de45ca349b96317f119a42846546b5fc9b448a262878daab0d320b9cde319f
```

This does not satisfy the complete neutrality gate. Keep the R0 PR open and
do not promote the G8 or weak-symbol findings to passes. Any resolution requires
an explicit follow-up decision; no corrective library change belongs in R0.
