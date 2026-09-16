# CeraLive librga

Rockchip's RGA (Raster Graphic Acceleration) userspace library — the 2D
scale/rotate/blend/colour-convert engine used by the CeraLive RK3588 streaming
stack. This is CeraLive's public fork; the upstream README follows below,
unmodified.

## Maintainer notice

This fork is maintained by **CeraLive** at
<https://github.com/CERALIVE/librga>. Issues and pull requests for the CeraLive
packages belong here, not on an upstream project. Upstream bugs that are genuinely
upstream are still reported upstream, but the packages CeraLive ships are ours to
support.

The fork imports JeffyCN's `mirrors` repository, branch `linux-rga-multi`, pinned
at `57a1067a246c71fa6c9a355d1668884fda155dd5`. Nothing in the imported history has
been rewritten. The exact import coordinate and the evidence behind the version
claims are in [`docs/PROVENANCE.md`](docs/PROVENANCE.md).

## The packages

Two Debian packages, both release assets of one tag and both served from
`apt.ceralive.tv`:

| Package | Contents |
|---|---|
| `librga2-ceralive` | The runtime library, SONAME `librga.so.2`. `Provides: librga2`, `Conflicts`/`Replaces: librga2`, so it substitutes for the distribution package on a CeraLive device. |
| `librga-ceralive-dev` | Headers under `include/rga/`, the static library, and `librga.pc`. |

The SONAME, the pkg-config name, and the header install path are unchanged from
upstream. R1 accepts exactly [18 inherited internal-symbol removals](docs/R1-ABI-ACCEPTANCE.md)
with documentation; any extra removal or stale accepted entry fails the ABI gate.

## Versioning: R0 and R1

Releases are versioned **upstream-style, not CalVer**, because the number a caller
cares about is the im2d API release it corresponds to:

- **R0 — `1.10.1+ceralive.1`.** A rebuild of the same API release the CeraLive
  bench boards already run (`rga_api version 1.10.1_[4]`), cut from
  `release/1.10.1` with packaging and CI commits only. Its neutrality claim is
  deliberately **bounded** to three measurable things: ELF export-set containment
  against the board's existing library, request-byte goldens on the CeraLive call
  set, and equal board-gate rows. It is never a claim of byte-identical source.
- **R1 — `1.10.5+ceralive.1`.** The pinned fork point plus the fix series that
  reproducers actually turned RED, each fix carrying its own red/green transcripts
  and independent-review receipt in [`docs/fix-audit.md`](docs/fix-audit.md).

`LIBRGA_STRICT_DRIVER` is **not implemented**: setting it, including to `1`, has
no effect. Earlier policy text incorrectly described an existing default-off
opt-in. R1 retains the upstream `rga_check_driver()` version-table policy; this
documentation correction introduces no strict mode or runtime behaviour change.

## Build

R1's three-channel NV12-output validation now has a real-library regression and
[decoded OPi PiP evidence](docs/NV12-BLEND.md). The R0 ordering fix was already
inherited upstream; the new change corrects two RGB classifiers so unsupported
backgrounds remain rejected. The decoded frame shows a visible inset with PR36's
geometry fix. This is finite composition only: the bounded run still reports a
primary-EOS error, and soak, teardown, package-swap and release gates remain open.

R1's explicit BT.709-full RGB→YUV path now clears the ordinary destination
selector instead of retaining BT.601-limited alongside full CSC. This repairs
upstream `2aa0ab4d`, not the donor port; coefficients and other colour modes are
unchanged. The [failing-first regression and isolated pixel evidence](docs/FULL709-SELECTOR.md)
recover the recorded 50.689414 dB result. G-B and R1 release remain blocked.

CeraLive builds with **Meson**, targeting Debian **Trixie** on arm64. The CMake,
Android, and RT-Thread build files upstream ships are preserved but unused.

```bash
meson setup build --prefix=/usr --buildtype=release
meson compile -C build
meson test -C build --print-errorlogs
```

Build the Debian packages and check them against the package contract with:

```bash
bash packaging/build-deb.sh
bash packaging/package-contract.sh
```

The upstream `debian/` directory in this tree is JeffyCN's. It is kept
byte-for-byte and is **never invoked** — no debhelper is involved in a CeraLive
build.

### Wave-E regression checks (R1)

The [toolchain mutation receipt](docs/TOOLCHAIN-GATE-PROOFS.md) distinguishes
real compiler/runtime faults from process-boundary fixtures. Required CI proves
analyzer extraction failures propagate, public-size assertions reject growth,
and actual sanitizer test blocks fail on instrumented faults before restoring
their original executables. Empty or unknown summary results fail closed.

The `Build Check summary` requires the analyzer, scoped werror and host-shim
sanitizer jobs. The analyzer fails on untriaged findings; the sanitizer runner
rejects empty or skipped suites as well as failures. Run the workflow-contract
regressions locally with `bash tests/test-build-check-gating.sh`. Manual
`Build Check` runs build and test branch candidates only, without publishing.
The matched-debug ABI and reproducibility jobs also feed the summary. The
[reserve repair](docs/R1-ABI-REPAIR.md) restores the Linux LP64 public sizes with
C/C++ assertions and an R0-sized guarded-copy test. The later
[accepted-removal decision](docs/R1-ABI-ACCEPTANCE.md) enumerates the 18 inherited
removals, rejects unexpected or stale entries, and leaves all other ABI changes
visible. Gaussian configuration remains available. Packaged LTO and the matching
normal test lane use `ci/package-lto.env`, currently **disabled**: the LTO
experiment preserves names but changes WEAK/GNU_UNIQUE bindings. A separate,
required dynamic-symbol check compares exact name/type/binding/visibility tuples,
retains the failed LTO qualification, and demands equality for the selected
packaging configuration. Run its real-ELF mutation controls with
`bash tests/test-dynsym-gate.sh`. An empty abidiff report is not LTO clearance.
See [build flags](docs/BUILD-FLAGS.md) for the
measurement boundary and the unpackaged, non-gating Cortex-A76 variant.
The [todo-41 gate receipt](docs/R1-BUILD-GATES.md) records the passing counts,
reproducible package hashes and the blocking matched-debug ABI report.

The R1 evidence ledger is checked by `bash scripts/check-ledger-reviews.sh`
and the Meson suite. It distinguishes approved fixes from reviewed observations,
requires different author/reviewer agent and model identities for GREEN fixes,
and retains earlier rejection/approval history. See the
[coordinator receipt](docs/fix-audit.d/coordinator-review.md). A passing receipt
gate is not permission to release R1 or waive its outstanding ABI/board gates.
It also compares every rendered row against the fragment inputs, rejecting row
loss, duplication or changed evidence rather than trusting a positive count.

H1 board characterization [EXISTS] lives in `tests/board/h1-board.cpp` and
`run-h1-board.sh`. It requires the board driver's held-lock environment and
measures real-device fd targets on pre/post-fix trees. Both Rock and OPi direct-init
measured 200/200 base findings and 0/200 post-fix findings, with clean controls.
Sanitizers remain host-shim-only. See
[`docs/fix-audit.d/h1.md`](docs/fix-audit.d/h1.md).

H4 board characterization [EXISTS] lives in `tests/board/h4-board.c` and
`run-h4-board.sh`. It requires a held board lock and the forwarding timing and
getenv-count interposers. The percentage method and undecided ≥2% gate are in
[`docs/fix-audit.d/h4.md`](docs/fix-audit.d/h4.md). Rock follow-up repaired the
calibration client and measured the untouched base plus three post-fix repeats:
approximately 0.469%, with a warmed empirical envelope of 0–1.894%. The
cold-inclusive result remains INCONCLUSIVE; do not generalize the warmed result.
The original client needs the documented correction before reuse. OPi reused the
already-built corrected client: three post-fix estimates of 0.470–0.479%, but a
warmed envelope union of 0–3.015%. The cross-board todo-34 input is therefore
INCONCLUSIVE; no optimization is authorized. Both-board measurements are complete,
which is distinct from satisfying the downstream ≥2% prerequisite.

H7 board characterization [EXISTS] lives in `tests/board/h7-board.c` and
`run-h7-board.sh`. The held-lock runner escalates real G1 work through 4/6/8
threads and stops at the first incident. Budget, recovery and hardware evidence
boundaries are in [`docs/fix-audit.d/h7.md`](docs/fix-audit.d/h7.md).
Rock follow-up measured all four libraries: each has a status-failure incident
at eight threads after clean four/six-thread dwell, and each recovered. These
are not progress stalls or NO-STALL-at-eight results. The common mapping-error
signature is surfaced to island/driver investigation, not treated as permission
for an R1 fix. OPi differs significantly: all four libraries completed the full
4/6/8-thread dwell without incidents, each NO-STALL at eight. The item-43 H7 matrix
is complete; the board-dependent contrast remains for driver/root-cause review,
not a uniform both-board failure claim or R1-fix permission.

H8 board characterization [EXISTS] lives in `tests/board/h8-data.c`, `h8-board.c`
and `run-h8-board.sh`. References are prepared on the host using the inherited
colour oracle; hardware conversion stays behind the board lock. The full matrix
and negative controls are in [`docs/fix-audit.d/h8.md`](docs/fix-audit.d/h8.md).
Rock and OPi each completed all 15 scored cells on both trees with identical
scores and passing controls. Both-board characterization is complete; defaults
are unchanged and sanitizers remain host-shim-only.

The scheduler default, failed `imsync` wait cleanup, legacy initialization and
borrowed-last-reference teardown fixes have green Meson regression cases. Long
host-only runs use `tests/repro/run-candidate-{a,b,c,d}.sh`; build the ASan and
TSan trees first with `scripts/build-sanitized.sh`. The owned-reference teardown
control remains unchanged. The Linux singleton and its active lookup mutex both
live until process termination; final context release drains in-flight operations.

These fixes are not release approval. Fresh evidence and the separate R0 ABI
closure finding are in [`docs/fix-audit.d/wave-e-verification.md`](docs/fix-audit.d/wave-e-verification.md).
The [matched-build reconciliation](docs/fix-audit.d/wave-e-abi-reconciliation.md)
corrects the initial unlike-toolchain comparison: 18 inherited removals, no
shipping-build or Wave-E removals. The later owner decision accepts those 18 only;
it does not erase the historical findings or authorize another removal.

Before reaching for the im2d API, read
[`docs/API-TRAPS.md`](docs/API-TRAPS.md). It documents the argument-unit and
status-code surprises that this library's callers hit first, and most of them are
silent.

The legacy `RkRgaSetLogOnceFlag` and `RkRgaSetAlwaysLogFlag` methods are
deprecated compatibility no-ops for logging [EXISTS], not diagnostic controls.
On Linux, use `ROCKCHIP_RGA_LOG=1` for process-wide operation diagnostics instead.
Their names must not be confused with Android's separate palette-context flags.
The [compatibility decision](docs/LEGACY-LOG-SETTERS.md) explains why their bodies
and both member sets remain unchanged.

The [OSD layout limitation](docs/OSD-LAYOUT-LIMITATION.md) is confirmed
librga-side but unreachable in the current CeraLive conversion/composition call
set. The public layout stays unchanged pending a future major version.

`bash ci/werror-steps.sh` [EXISTS] gates `im2d_context.cpp` and CeraLive test and
reproducer translation units on trixie/arm64 with `-Wall -Wextra -Werror` and no
warning suppressions. It is not a whole-upstream-tree warning-clean claim.
Normal library builds now expose inherited warnings; see
[build flags](docs/BUILD-FLAGS.md#scoped-warnings-as-errors-todo-37).

The host-only H3 initialization-failure census is [EXISTS]: run
`bash tests/repro/run-h3.sh` to build the unchanged shared library and measure
1,000 calls per API/fault pair. Exit 1 means a reproduced leak, not a harness
failure. Results, caveats and the shim fault mappings are recorded in
[`docs/fix-audit.d/h3.md`](docs/fix-audit.d/h3.md).

### Job and buffer-handle QA (H10)

The host-only bookkeeping reproducer is available separately from the normal
passing test suite:

```bash
bash tests/repro/run-h10.sh asan
bash tests/repro/run-h10.sh tsan
```

Each command builds through the existing sanitizer recipe, checks its runtime
canary, and runs unknown-job cancellation, concurrent config/end versus cancel,
and repeated buffer release against the unchanged fake device. Serial lifecycle
controls run first. Exit `1` means an observed finding, `2` means an invalid run,
and `0` means no finding in that finite run. These are characterization runs, not
expected-pass CI tests. They do not change the library or access a board.

Fresh logs and request dumps go under `test-results/h10/`; the
[H10 audit fragment](docs/fix-audit.d/h10.md) records the measured results and their
limits. Race runs request 2000 iterations twice, but halt on the first sanitizer
finding; an early report is not a completed 2000-iteration run. Reports keep raw
module offsets (`symbolize=0`), because online symbolization stalled under the
preloaded shim on the QA host. Resolve those offsets offline with `addr2line`
against the matching build before rebuilding it. The shim models ioctl handling,
not hardware or driver-side ownership, so a forwarded second release is not
evidence of a kernel double-free.

### H10 regression gate (todo 38)

The fixes decrement the job count only for a removed job and retain the manager
mutex through CONFIG's ioctl, so cancel/submit cannot free borrowed task bytes
before the driver copies them. This serializes other job-manager operations
during CONFIG; no public structure, return status or message text changes.

`meson test -C build --suite h10 --print-errorlogs` [EXISTS] gates accounting,
serial lifecycle, CONFIG failure/unlock, driver-owned import reference counting
and numeric reuse, plus two 2000-iteration config/end-versus-cancel runs. Each
case resets its own shim log/dump. ASan/UBSan CI runs the H10 suite and TSan
discovers both races through `concurrency`. All sanitizer evidence is
**host-shim-only**.

The original `run-h10.sh` characterization command intentionally still exits 1
for `SECOND-RELEASE-FORWARDED` after the bookkeeping fixes: H10c is **driver-owned,
not a librga defect**, not a remaining userspace fix. No released-handle
tombstone is introduced. The opt-in `FAKE_RGA_REIMPORT` shim mode models one
buffer with reference-counted imports and recycled numeric handle 1; it rejects
an exhausted release itself. The normal shim behavior and goldens are unchanged.
See [`docs/fix-audit.d/todo-38.md`](docs/fix-audit.d/todo-38.md) for evidence.

## Credits

This repository descends from Rockchip's `linux-rga` through JeffyCN's
`linux-rga-multi` mirror branch. CeraLive thanks:

- **Rockchip Electronics Co., Ltd.** and its contributors for the original RGA
  userspace library. The principal authors named in the tree are **Zhiqin Wei**,
  **Putin Lee**, and **Yu Qiaowei (Cerf Yu)**.
- **Jeffy Chen / JeffyCN** for maintaining the `mirrors` repository and its
  `linux-rga-multi` branch — the tree this fork imports — and for the upstream
  `debian/` packaging retained here.
- **tsukumijima** for the packaging model that informed CeraLive's `packaging/`
  layout. Ideas only; no code is taken.
- **nyanmisaka** for downstream fixes that are candidate donors. Any pick is taken
  with `git cherry-pick -x`, keeps its original author, and is recorded in
  `docs/fix-audit.md` with its reproducer. Picks are credited individually as they
  land. The R1 donor audit and the constrained port of nyanmisaka's
  `571a880951583a3b2a04e7e1fa900861653befde` combined-CSC fix are recorded in
  [`docs/DONORS.md`](docs/DONORS.md). No new public feature macro is exposed.

`airockchip/librga` is consulted as a header and CHANGELOG reference only. That
distribution is binary-only and is never a source donor.

## License

This library is **Apache License, Version 2.0** — see [`COPYING`](COPYING) — with
documented third-party exceptions. The bundled libdrm headers under
`core/3rdparty/libdrm/` and `samples/utils/3rdparty/libdrm/` are MIT/X11-style and
keep their own notices, and the root `Android.mk` carries a GPL-3.0-or-later
notice that conflicts with `COPYING`; it is an Android build file, is never built
and never shipped, and is excluded from every distributed artifact. The complete
file-level census is in [`docs/PROVENANCE.md`](docs/PROVENANCE.md), and the
machine-readable attribution is `packaging/copyright`.

CeraLive modifications remain Apache-2.0. Modified files carry an Apache-2.0
§4(b) notice line, `// Modified by CeraLive <YYYY-MM-DD>: <why>`. Upstream
copyright and licence notices are preserved everywhere.

Contribution rules, frozen contracts, and the proof boundary of the test suite are
in [`AGENTS.md`](AGENTS.md).

---

# librga

RGA (Raster Graphic Acceleration Unit)是一个独立的2D硬件加速器，可用于加速点/线绘制，执行图像缩放、旋转、bitBlt、alpha混合等常见的2D图形操作。本仓库代码实现了RGA用户空间驱动，并提供了一系列2D图形操作API。

## 版本说明

**RGA API** 版本: 1.10.5

## 适用芯片平台

Rockchip RK3066 | RK3188 | RK2926 | RK2928 | RK3026 | RK3028 | RK3128 | Sofia3gr | RK3288 | RK3288w | RK3190 | RK1108 | RK3368 | RK3326 | RK3228 | RK3228H | RK3326 | RK1808 | RV1126 | RV1109 | RK3399 | RK3399pro | RK3566 | RK3568 | RK3588 | RK3326S | RV1106 | RV1103 | RK3528 | RK3562 | RK3576 | RK3506 | RV1103B | RV1126B | RK1820

## 目录说明

├── **im2d_api**：RGA API相关实现及头文件<br/>
├── **include**：RGA硬件相关头文件<br/>
├── **core**：RGA用户空间驱动实现<br/>
├── **docs**：FAQ以及API说明文档<br/>
├── **samples**：示例代码<br/>
├── **toolchains**：示例工具链配置文件<br/>
└──其余编译相关文件<br/>

## 编译说明

### Android Source Project

​	下载librga仓库拷贝至android源码工程 hardware/rockchip目录，配置好编译环境后，执行**mm**进行编译，根据不同的Android版本将自动选择Android.mk或Android.bp作为编译脚本。

```bash
$ mm -j16
```

### CMAKE

​	本仓库示例代码支持CMAKE编译，可以通过修改toolchain_*.cmake文件以及编译脚本实现快速编译。

#### 工具链修改

- **Android NDK（build for android）**

​	参考librga源码目录下**toolchains/toolchain_android_ndk.cmake**写法，修改NDK路径、Android版本信息等。

| 工具链选项                          | 描述                                         |
| ----------------------------------- | -------------------------------------------- |
| CMAKE_ANDROID_NDK                   | NDK编译包路径                                |
| CMAKE_SYSTEM_NAME                   | 平台名，默认为Android                        |
| CMAKE_SYSTEM_VERSION                | Android版本                                  |
| CMAKE_ANDROID_ARCH_ABI              | 处理器版本                                   |
| CMAKE_ANDROID_NDK_TOOLCHAIN_VERSION | 工具链选择（clang/gcc）                      |
| CMAKE_ANDROID_STL_TYPE              | NDK C++库的链接方式（c++_static/c++_shared） |

- **Linux（buildroot/debian）**

​	参考librga源码目录下**toolchains/toolchain_linux.cmake**写法，修改工具链路径、名称。

| 工具链选项     | 描述       |
| -------------- | ---------- |
| TOOLCHAIN_HOME | 工具链目录 |
| TOOLCHAIN_NAME | 工具链名称 |

#### 编译脚本修改

​	修改samples目录或需要编译的示例代码目录下**cmake_*.sh**，指定toolchain路径。

| 编译选项       | 描述                                                         |
| -------------- | ------------------------------------------------------------ |
| TOOLCHAIN_PATH | toolchain的绝对路径，即《工具链修改》小节中修改后的toolchain_*.cmake文件的绝对路径 |
| LIBRGA_PATH    | 需要链接的librga.so的绝对路径，默认为librga cmake编译时的默认打包路径 |
| BUILD_DIR      | 编译生成文件存放的相对路径                                   |

#### 执行编译脚本

- **Android NDK（build for android）**

```bash
$ chmod +x ./cmake_android.sh
$ ./cmake_android.sh
```

- **Linux（buildroot/debian）**

```bash
$ chmod +x ./cmake_linux.sh
$ ./cmake_linux.sh
```

- **RT-thread**

```bash
$ chmod +x ./cmake-rt-thread.sh
$ ./cmake-rt-thread.sh c
```

### Meson

​	本仓库提供了meson.build，buildroot/debian支持meson编译。单独编译可以使用meson.sh 脚本进行config，需要自行修改meson.sh 内指定install 路径，以及PATH等环境变量，cross目录下是交叉编译工具配置文件，也需要自行修改为对应交叉编译工具路径。

​	执行以下操作完成编译:

```bash
$ ./meson.sh
```

## 使用说明

* **头文件引用**

  * C++调用im2d api

    im2d_api/im2d.hpp

  * C调用im2d api

    im2d_api/im2d.h

* **库文件**

  librga.so

  librga.a

* **librga应用开发接口说明文档**

  [IM2D API说明文档【中文】](docs/Rockchip_Developer_Guide_RGA_CN.md)

  [IM2D API说明文档【英文】](docs/Rockchip_Developer_Guide_RGA_EN.md)

* **RGA模块FAQ文档**

  [RGA_FAQ【中文】](docs/Rockchip_FAQ_RGA_CN.md)

  [RGA_FAQ【英文】](docs/Rockchip_FAQ_RGA_EN.md)
