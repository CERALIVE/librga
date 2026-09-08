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
   A `pahole`/GCC debug-layout probe on this aarch64-compatible ABI reports `full_csc` at zero-based offset 308 with size 40 (covering offsets 308–347), with `dither_mode` at 306, one byte of padding at 307, and `in_fence_fd` at 348; therefore every reported byte offset 310, 311, 312, 319, 320, 343, and 344 is inside `full_csc`, not neighboring padding or another field (and the corresponding one-based `cmp` positions are likewise inside it).
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

## Owner Q1 investigation, 2026-09-08

`R0_PREFIX_HEAD=4bb862fb68165c52e1969d40128c50e3e89bff6d` is the integration head
before these investigation commits. No rebase onto main, installed-library
change, library-default change, request masking, or golden-fixture change was
made. The following supersedes the *unexplained cause* statements above, not the
recorded raw FAIL results or the release gate.

| Finding | Terminal investigation state | Disposition |
|---|---|---|
| G8 `full_csc` | **INITIALISATION-NOISE**, proved in both packaged binaries | All observed differences are internal struct padding, not CSC members. Driver consumption and controlled stack-poison evidence below. Raw byte equality still fails; no waiver or normalization is implemented. |
| OPi R3/R5/R6 fd 4→5 | **HARNESS-DEFECT, FIXED**: deferred singleton `/dev/rga` open | Acquire the real context before the baseline census. Native selftest and 1,000-copy routing change from 4→5/exit 1 to 5→5/exit 0 with both libraries. Strict equality stays. |
| R4 success log | **CROSS-RELEASE HARNESS-DEFECT, FIXED** for `.2`/`.3` | Enable `mppenc:5` as well as `mpp:5`, and accept either actual conversion-success marker. Live `.2` RED→GREEN below. The archived `.1` missing-success cause remains **UNRESOLVED**, not retroactively passed. |

### G8: internal padding is not a coefficient

The original numbers are **one-based `cmp` positions**, not zero-based offsets.
The earlier probe correctly placed them inside the 40-byte `full_csc`, but being
inside a struct does not establish that a byte is a named member:

| Region | Zero-based request offsets | One-based `cmp` positions |
|---|---|---|
| After `flag`, before `coe_y` | 309–311 | 310–312 |
| `coe_y` alignment before `off` | 318–319 | 319–320 |
| `coe_u` alignment before `off` | 330–331 | 331–332 |
| `coe_v` alignment before `off` | 342–343 | 343–344 |

The layout is `flag` at +0, `coe_y/u/v` at +4/+16/+28; each coefficient struct
contains three 16-bit values at +0/+2/+4 and a 32-bit offset at +8. Its two bytes
at +6/+7 are padding. See `core/hardware/rga_ioctl.h:223–236`.

**Binary and source evidence.** The Radxa `.deb` has SHA-256
`ca4f18666f6c5d5290c7e41e5901350ecf76530f24364e37b81fa6be4ab5f344`;
its extracted library hashes to `0b455344…`, exactly matching OPi's installed
file. The R0 library remains `b5de45ca…` (full hashes above). `strings` identifies
Radxa as `rga_api version 1.10.1_[4]`. Ghidra decompilation and
`aarch64-linux-gnu-objdump -d -C` identify
`NormalRgaFullColorSpaceConvert(rga_req*, int)` at ELF virtual addresses
`0xa530` (Radxa) and `0xa8d0` (R0). Both select the same G8 mode `0xb00` and
compute `int(coefficient * 1023 + 0.5)` from the same matrix. Both copy the entire
40-byte local struct, whose padding was never initialized. For example, Radxa
stores only the flag byte at `0xa604`, stores named coefficients at
`0xa668–0xa694`, then copies all 40 bytes at `0xa720–0xa734`.

This matches R0 `core/NormalRgaApi.cpp:883,951–973`: an uninitialized
`default_csc_table`, member assignments, then `memcpy(sizeof(full_csc_t))`.
The calling path is `im2d_api/src/im2d_impl.cpp:1845–1856` (explicit RGB-full to
BT.709-limited) → `core/NormalRga.cpp:1332–1340` (full-CSC writer plus the packed
BT.709 selector). R0 Meson supplies `-DLINUX=1`. The CSC writer has no
`RGA_FULL_CSC`/`RGA_IM2D_*` conditional. Radxa's exact source commit and complete
compiler defines are **not recoverable from this stripped binary**; equal API
strings are not proof of equal source. However, no different mode or table is
needed to explain these bytes: controlled execution proves the uninitialized
local object in both binaries. Installed flags remain unchanged.

**RED reproducer and causal toggle.** The unmodified dynamic golden runner and
fake-device shim ran 48 processes on OPi: eight cases × two libraries × three
repetitions. Every request is 504 bytes. G1–G7 match verbatim in all repetitions;
G8 fails at exactly the seven original one-based positions each time, with
changing byte values between processes. No real RGA ioctl occurs in this run.

`tests/golden/csc-padding-probe.c` makes the cause repeatable without relying on
ASLR: it seeds the callee's stack with `0xaa`, then `0x55`, and calls the exported
writer with identical, zeroed requests and mode `0xb00`. This is a diagnostic,
not a replacement golden scorer. Build on aarch64 from the repo root:

```sh
cc -Wall -Wextra -Werror -Icore/hardware tests/golden/csc-padding-probe.c \
  -Wl,--no-as-needed -Lbuild -lrga -ldl -o build/csc-padding-probe
LD_LIBRARY_PATH=<directory-containing-extracted-librga.so.2> build/csc-padding-probe
```

Both Radxa and R0 return **1** (raw `memcmp` inequality), and differ in exactly
the nine padding bytes in the table, each changing `aa`→`55`. No named member or
other request byte changes. Both report:

```text
flag=1 Y=187,628,63,16368 U=-102,-346,449,130944 V=449,-407,-40,130944
```

**Driver-source proof.** At immutable media-island commit
[`66d3f4973a9e4957493fb96af1af73ef38e79e78`](https://github.com/CERALIVE/rk3588-media-island/tree/66d3f4973a9e4957493fb96af1af73ef38e79e78),
all paths below are under `drivers/video/rockchip/rga3/`:

- `include/rga.h:411–424` declares the same padded coefficient layout.
- `rga2_reg_info.c:2922–2939` copies full-CSC when flag bit 0 is enabled;
  `3186–3209` emits registers from the twelve **named members only**;
  `3271–3272` gates emission on the flag. The copied padding is never used as a
  register operand.
- `rga3_reg_info.c:1721–1749` instead maps the packed `yuv2rgb_mode` to hardware
  CSC modes; `284–292,689–697` emits those modes. RGA3 does not load the full-CSC
  coefficient payload. `rga_policy.c:89–99` checks the flag/capability and the
  BT.709 exception, not padding.

The **padding bytes**, not the whole `full_csc` field, are ignored. G8's flag is
1, so declaring its whole matrix disabled would be wrong. The already-recorded
same-session pixel evidence is `tests/board/DRILL-RESULTS.md` R5: all nine cells
equal Radxa, including BT.709-limited PSNR **52.904279 dB on both**. These are
finite pixel observations, not sanitizer or whole-library neutrality claims.

### FD: lazy initialization, not an R0-specific leak

OPi had no `strace` installed. Debian arm64 `strace 6.13+ds-1` was extracted to
`/tmp` and run without installing a package. Golden processes used
`strace -f -yy -e trace=openat,close,ioctl,memfd_create`; the hardware bench used
the requested `strace -f -yy -e trace=openat,close,ioctl` under sudo. An initial
unprivileged hardware probe exited 77, permission denied; it is not a test pass.

Both golden runners open one shim `memfd:fake-rga` (fd 3), close every log/dump
descriptor immediately, and close their fixed 100/101 buffer descriptors. They
do not expose an extra R0-only fd. The real bench supplies the missing evidence:

```text
openat(..., "/proc/self/fd", ...) = 3  # first census: 4 incl. census directory
close(3) = 0
... two DMA-heap allocations; heap descriptors closed ...
openat(..., "/dev/rga", O_RDWR) = 3    # first real conversion
... version queries and synchronous blit ...
... both DMA-BUF descriptors closed ...
openat(..., "/proc/self/fd", ...) = 4  # final census: 5 incl. census directory
```

`core/RgaApi.cpp:27–31` implements init/deinit as no-ops. The first
`RockchipRga::get()` initializes the persistent context; `c_RkRgaGetContext()`
already exposes that acquisition (`RgaApi.cpp:33–36`,
`RockchipRga.cpp:99–124,138–140`). The library owns the fd for the session; the
bench's no-op deinit does not close it, and the process exit reclaims it. It is
neither a second `/dev/rga` open nor per-frame growth.

The fix changes **only the bench** to acquire that context before measuring.
`board-session-baseline` runs the same boundary with the host shim: RED 4→5,
GREEN 5→5. On native OPi, Radxa and R0 each change from exit 1 to exit 0 for both
the exact 64×64 selftest and 1,000-copy routing. The final traces move the single
device open before the first census and retain strict before/after equality.
This does not rerun the full 295-second R6 soak or the full G-A package swap.

### R4: distinguish the release fix from the historical gap

Tagged plugin source establishes these markers, all at DEBUG level:

| Release | Success-site evidence |
|---|---|
| `1.14.4+ceralive.1` (`73b0e772`) | `gstmpp.c:273`, category `mpp`: `converted with RGA`, following successful `c_RkRgaBlit`. Also `gstmppenc.c:1769`, category `mppenc`: `using RGA converted buffer`. |
| `1.14.4+ceralive.2` (`c01cf90`) | Backend refactor `26637fb7` removes the old `gstmpp.c` marker; encoder success is `gstmppenc.c:2065`, category `mppenc`: `using RGA converted buffer`. |
| `1.14.4+ceralive.3` (`12865647`) | Same encoder success site/category/text as `.2`. |

Thus the old `mpp:5` selector plus old-only text cannot score `.2`/`.3`.
On live OPi, still carrying **`.2`**, the original 300-frame RGB16 command reaches
EOS without a success marker. Adding `mppenc:5` yields 300
`using RGA converted buffer` lines and EOS. The old predicate still rejects this
log; `conversion-evidence.sh` accepts it. Its registered selftest accepts both
release success markers and rejects empty, enable-only and blit-failure logs.
Neither pixels nor quality thresholds are involved in this assertion fix.

The archived `.1` log is a separate limit: that source's default category really
is `mpp`, with no local redefinition or debug-disable guard. The `.2` refactor
cannot explain a September 5 run labeled `.1`. The archive lacks enough evidence
to distinguish a bypassed conversion path from a binary/source identity issue.
It still fails the corrected predicate. Do not turn that historical row green
from today's `.2` run or claim `.3` was installed/tested here.

### Evidence and release boundary

Raw traces, extracted binaries, disassembly, Ghidra output and RED/GREEN logs are
retained in repo-local `test-results/todo41/`; the old fd RED traces are in
`results/`, GREEN in `green/results/`. Board work used only OPi's locked harness;
Rock was not contacted. Radxa remained installed and its library hash unchanged.

The investigation explains G8 without changing the default CSC, interpolation,
log level, build defines, source goldens or dynamic scorer. **Raw G8 byte equality
is still RED.** This is not permission to mask padding or call that gate PASS.
The weak-symbol `abidiff` result also remains as recorded. Independent review,
the outstanding literal-gate disposition and a fresh both-board G-A remain
required before merge/release; this investigation alone does not authorize them.
