# Build flags — what the packaged library is compiled with, and why

The authoritative copy of every flag is `packaging/build-deb.sh`. This document
exists for the parts a reader cannot get from the script: which flags were
*measured* rather than chosen, what was tried and rejected, and which of the
results below came from real hardware and which did not.

## Where these numbers came from

Everything on this page was produced in the target-suite container on the target
architecture:

| | |
|---|---|
| Image | `debian:trixie-slim`, `--platform linux/arm64` |
| Suite | Debian GNU/Linux 13 (trixie) — `ci/target-suite.env` `TARGET_SUITE` |
| Compiler | `g++ (Debian 14.2.0-19) 14.2.0` |
| Linker | GNU `ld.bfd` 2.44 |
| Meson / Ninja | 1.7.0 / 1.12.1 |
| C library | Debian GLIBC 2.41-12+deb13u3 |
| Host | x86_64, running the arm64 container through the `qemu-aarch64` binfmt handler |

The last row is the one limitation worth stating plainly: the code generation is
real aarch64 from a real aarch64 GCC, and the resulting ELF is a real arm64
object, but it was *executed* under emulation. Nothing on this page depends on
runtime behaviour — every result is either a compiler diagnostic or a property
read off the ELF — so emulation does not weaken any of it. What emulation cannot
give is a run on the actual RK3588. That is the board drill's job, not this page's.

## `-fpermissive`: NOT needed. Measured, not assumed.

The open question this file was created to answer was whether the tree needs
`-fpermissive` on trixie/aarch64 with GCC 14 — specifically whether the
`void *` to `unsigned int` conversions in the older Rockchip code become hard
errors on a modern compiler.

**They do not.** With the plain `dpkg-buildflags` set and no extra flags at all,
the build is clean:

```text
[1/36] Compiling C++ object librga.so.2.1.0.p/core_GrallocOps.cpp.o
...
[34/36] Linking target librga.so.2.1.0
[36/36] Linking static target librga.a
compile exit: 0
```

36 of 36 targets, exit 0, and no diagnostic of any kind reached the log. There is
therefore no diagnostic list to record here, because there were no diagnostics.

Two things make that result less surprising than it looks, and both are worth
knowing before someone "fixes" them:

- `meson.build` compiles the library with `cpp_args : ['-w']`, which suppresses
  every warning the project would otherwise emit at `warning_level=3`. Warnings
  are invisible in this build by upstream's choice. Errors are not suppressed by
  `-w`, so the clean exit is still a real result about errors — but do not read
  it as "the code is warning-clean".
- Nothing in the packaged sources (`core/`, `im2d_api/`, `include/`) performs the
  conversion in a form GCC 14 rejects. The Android and sample paths, which are
  the usual source of that class of error, are not compiled: `-Dlibrga_demo=false`
  keeps the demo out, and `Android.mk`/`Android.bp` are never invoked.

`build-deb.sh` records this as `readonly EXTRA_CXXFLAGS=""`. If a future tree
state needs something there, add it in the same change that adds a section here
saying which diagnostic forced it.

## The flag set of record

`dpkg-buildflags` on trixie/arm64 supplies, unmodified:

```text
CXXFLAGS  -g -O2 -ffile-prefix-map=<cwd>=. -fstack-protector-strong
          -fstack-clash-protection -Wformat -Werror=format-security
          -mbranch-protection=standard
CPPFLAGS  -Wdate-time -D_FORTIFY_SOURCE=2
LDFLAGS   -Wl,-z,relro
```

`build-deb.sh` changes exactly two things, and both are additions rather than
overrides:

1. **`DEB_BUILD_MAINT_OPTIONS=hardening=+bindnow`** adds `-Wl,-z,now`. Debian
   enables `relro` by default but not `bindnow`, and it takes both to get full
   RELRO. Without it the GOT stays writable for the life of the process.
2. **`-D_FORTIFY_SOURCE=3`**, replacing the suite default of 2. The existing
   `-D_FORTIFY_SOURCE=2` is *removed* from `CPPFLAGS` before 3 is appended,
   because leaving both on the command line is a redefinition rather than an
   upgrade.

`pie` is deliberately not requested. Debian's GCC already defaults to PIE, and a
shared library is `ET_DYN` and `-fPIC` by construction; asking `dpkg-buildflags`
for the `pie` feature would put `-pie` into `LDFLAGS`, which the linker rejects
alongside `-shared`.

The build runs from a fixed directory (`cd "${root}"`) because
`-ffile-prefix-map` is derived from the current directory. Two runs launched from
different directories would otherwise be handed different compiler command lines
for identical source.

### Verified on the produced binary, not on the command line

`packaging/package-contract.sh` reads each of these off the staged library, so a
flag silently dropped by Meson fails the build rather than shipping quietly:

```text
RELRO           DT_FLAGS_1 NOW present            (full RELRO)
BTI / PAC       .note.gnu.property AArch64 feature: BTI, PAC
stack canary    __stack_chk_fail in the undefined symbols
PIE             ELF type DYN
stripped        no .debug_info section
```

The `.note.gnu.property` line is why `strip` removes `.comment` but **not**
`.note`. Stripping the note sections — which the sibling `gstreamer-rockchip`
packaging does, for a plugin where it does not matter — would delete the only
evidence that `-mbranch-protection=standard` took effect.

## Dependency floors, derived from the ELF

Measured imports of the stripped library, against what the suite provides:

| Symbol version | Library needs | trixie provides |
|---|---|---|
| `GLIBC_` | 2.38 | 2.41 |
| `GLIBCXX_` | 3.4.29 | 3.4.33 |
| `CXXABI_` | 1.3.9 | 1.3.15 |

`ci/check-abi-floors.sh` is the executable form of that table. The frozen
`Depends` follows from the same measurement:

```text
Depends: libc6 (>= 2.38), libgcc-s1, libstdc++6 (>= 11)
```

`libstdc++6 (>= 11)` is `GLIBCXX_3.4.29` mapped through the table in
`build-deb.sh`; the same mapping run against Radxa's own binary reproduces the
`libstdc++6 (>= 11)` that Radxa's `librga2` declares, which is how the table was
checked rather than trusted.

**`libdrm2` is deliberately absent**, and this is the one place where the shipped
`Depends` differs from what a reader of the build flags would predict.
`-Dlibdrm=true` is passed, because upstream's own `debian/rules` passes it — but
at this tree state `meson.build` never reads that option, the DRM headers the
library uses are the vendored header-only ones under `core/3rdparty/libdrm/`, and
`libdrm.so.2` does not appear in the built library's `NEEDED` list. Radxa's
`librga2 2.2.0-1` declares the same three packages and no `libdrm2`, for the same
reason. `build-deb.sh` derives the closure from `objdump -p` and asserts it equals
the frozen literal, so if a future change does start linking libdrm the build
fails until both are updated together.

### A trixie-built package does not run on bookworm

`GLIBC_2.38` is above bookworm's 2.36. That is expected and is not a defect: the
device image is Debian 13. The consequence for CI is that the bookworm leg must
build and smoke *its own* package rather than installing the trixie artifact —
the bookworm leg is a portability signal, not a second runtime target.
`ci/target-suite.env` names it `SECONDARY_SUITE` for that reason.

## Export set: what the baseline comparison actually measured

`packaging/baseline-symbols-radxa-2.2.0-1.txt` is the export floor, taken from the
real board binary (sha256 `0b455344…`, `rga_api version 1.10.1_[4]`). Three
measurements were run against it, and the difference between them is the reason
`package-contract.sh` applies the floor the way it does.

| Built from | Global baseline symbols missing |
|---|---|
| `5a97e650` (`R0_TIP`, API `1.10.1_[4]` — the R0 release base) | **0** |
| `57a1067` (this branch, API `1.10.5_[11]`) | 18 |

The R0 result is the one that matters for the neutrality claim in todo 15: a GCC
14 rebuild of the same upstream API release exports **every** global symbol the
Radxa build exports. Nothing is narrowed.

Two details behind that number, both of which cost time to discover:

- **Weak symbols are excluded from the baseline.** The board binary defines 274
  dynamic symbols: 254 global and 20 weak. The R0 rebuild reproduces all 254
  globals and drops three of the weak ones — all three
  `std::_Rb_tree<unsigned int, im_rga_job *>` members. Those are COMDAT template
  instantiations emitted by whichever compiler happened to build the object, not
  promises this library makes. Including them would make the contract fail for a
  toolchain reason and train people to ignore it.
- **`LC_ALL=C` everywhere.** `comm(1)` needs both inputs in the same collation. A
  list sorted under a UTF-8 locale and compared inside a C-locale container
  reported 232 phantom differences, with the words `input is not in sorted order`
  buried mid-output where they are easy to miss.

The 18 symbols on this branch are upstream's own changes between API `1.10.1_[4]`
and `1.10.5_[11]`: two tables became `static const`, four functions became
`static`, two were deleted outright, and ten changed signature and so changed
mangled name. Each is listed with its reason in
`packaging/baseline-symbols-upstream-delta.txt`, and none is reachable from an
installed header — which is what the contract's first, unconditional tier checks.

## Reproducibility

`SOURCE_DATE_EPOCH` is the commit date of the last commit touching a **packaged
input** — the source directories, the build files, the version file, the builder
and the copyright file — and never `HEAD`. A merge commit, a docs commit or a
drill-results commit therefore does not move the archive hashes, which is what
lets a board-drilled `.deb` be byte-identical to the published one.

`packaging/package-contract.sh --repro` builds twice into a scratch directory and
compares the sha256 of both archives. Two full builds, same build path:

```text
package-contract: OK reproducible — two builds, identical sha256:
  56085fd1b0298631506565b0203667a8675ef863ec269c2ca798ac2bcd6b9844  librga-ceralive-dev_…_arm64.deb
  da0a84fa22ad504c0bb7a51673c28f7aee1076edbb2632d2afa26a2f06d4aad7  librga2-ceralive_…_arm64.deb
```

Epoch invariance is visible in the history rather than argued: `HEAD` on this
branch is a docs-only commit, and the derived epoch is the date of an earlier
commit — the last one that touched a packaged input. A docs commit cannot move it
because `docs/` is not in the list.

### Reproducibility is per build path, and the difference is exactly 20 bytes

Building the same source at two different paths and comparing the stripped
libraries byte for byte:

```text
264584  librga.so.2.1.0   built at <repo>/build-deb-arm64
264584  librga.so.2.1.0   built at /tmp/deep/a/b/c/build

build-id  a5acec62a950cf3a2602bfa537e615613105c25e
build-id  b3f1df4632cdd127d0931ce1be3bbb662b27bf5c

differing bytes: 20, at offsets 673-692
```

Twenty bytes, contiguous, at the offset of the SHA-1 in `.note.gnu.build-id`.
**Every other byte of the library — all code, all data, all relocations — is
identical.** The generated object is build-path independent; only the identifier
the linker derives from the debug info is not.

The cause is that Meson passes source paths *relative* to the build directory, so
a build directory at a different depth produces different path strings in the
debug info, and the linker hashes those into the build-id. `-ffile-prefix-map` is
applied to both the source directory and the build directory, which removes the
absolute paths, but a relative path is not a prefix either map can rewrite.

Two consequences, both practical:

- CI must build at a **fixed path** for published archives to be byte-comparable
  across runs. This is the ordinary Debian position — it is why `.buildinfo`
  records `Build-Path` — and not a defect.
- A build-id mismatch between two otherwise identical builds is *not* evidence of
  a code difference. Compare the stripped libraries directly before concluding
  anything from a checksum difference; the expected signature of a path change is
  exactly the 20 bytes above.
