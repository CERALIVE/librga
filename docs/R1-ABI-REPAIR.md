# R1 reserve repair and remaining ABI blockers — historical receipt [PARTIAL]

**Superseded removal disposition:** the later owner decision
[accepts exactly these 18 inherited removals with documentation](R1-ABI-ACCEPTANCE.md),
without shims, and enables LTO behind the exact-set ABI gate. The restore-all
direction and red-gate/LTO-off statements below describe the reserve-only task
at `ae59c2f`, not current policy. The layout measurements, residual type changes,
and evidence boundaries remain valid; no historical test result is rewritten.

**The two Linux LP64 public sizes are repaired; R1 is still not ABI-cleared.**
This is a reserve-budget correction on `ci/r1-toolchain-gates`, based on
`d555b87` and main `8490d34`. It is not a SONAME change, a suppression, a gate
threshold change, or approval to release. LTO remains disabled. No board work
was performed; the OSD-offset and public-log-setter limitations are unchanged.

## Compiled layout measurements

R0: published `1.10.1+ceralive.1`, commit
`f4c3ee62ab354c2cbe22718f543fc0ba6e58365c`. Measured with Debian arm64
GCC 14.2.0-19, `-g -O2`, using `sizeof`, `_Alignof` and `offsetof` in compiled
C executables. All offsets and sizes below are bytes.

| Measurement | R0 | R1 before | R1 repaired |
|---|---:|---:|---:|
| `sizeof(rga_info_t)` | 696 | 704 | 696 |
| `alignof(rga_info_t)` | 8 | 8 | 8 |
| `rga_info_t.rgba5551_alpha1` offset | 291 | 291 | 291 |
| `rga_info_t.gauss_config` offset / size | absent | 296 / 16 | 296 / 16 |
| `rga_info_t.reserve` offset / length | 292 / 398 | 312 / 386 | 312 / 378 |
| `sizeof(im_opt_t)` | 304 | 312 | 304 |
| `alignof(im_opt_t)` | 8 | 8 | 8 |
| `im_opt_t.interp` offset / size | 176 / 4 | 176 / 4 | 176 / 4 |
| `im_opt_t.gauss_config` offset / size | absent | 184 / 32 | 184 / 32 |
| `im_opt_t.reserve` offset / length | 180 / 124 | 216 / 92 | 216 / 88 |

`rga_gauss_config` is 16 bytes, aligned to 8; `coe_ptr` is at offset 8.
Insertion after byte 291 costs four alignment bytes plus 16 configuration bytes:
**398 - 4 - 16 = 378**. The reserve ends at 690 again, followed by the same six
tail-padding bytes as R0.

`im_gauss_t` is 32 bytes, aligned to 8; `matrix` is at offset 24. Insertion after
the four-byte `interp` at 176 costs four alignment bytes plus 32 configuration
bytes: **124 - 4 - 32 = 88**. Its reserve ends at 304, exactly as in R0.
The original subtraction of 32 forgot insertion padding; the final alignment
rounded that four-byte excess into an eight-byte struct growth.

No preceding non-reserved member changes offset. The matched DWARF comparison
reports only Gaussian insertion and reserve movement in these structures after
the repair, with **“type size hasn't changed”** for both. The reserve's own
offset necessarily changes when it is consumed; that is not a claim that the
reserve field remains at its old address.

The correction and header assertions are scoped to Linux LP64. Non-LP64 and
Android keep their existing declarations; this task neither measures nor claims
to repair those ABIs. The feature's fields, offsets, setters and implementation
remain present.

## Regression evidence

- With the assertions added but the original reserves retained, the GCC 14 C
  compile fails on **both** `sizeof` assertions. With reserves 378 and 88 it
  compiles and prints the repaired sizes above. C++ builds exercise the matching
  `static_assert` branches.
- `unit-pure` now puts an exact 304-byte R0 option allocation immediately before
  a `PROT_NONE` page, then calls the real `rga_get_opt()`. Its R0 version is
  `0x010a0104`. This catches the former `memcpy(sizeof(im_opt_t))` over-read
  without trusting the current header to size the fixture.
- The same new test, linked to the retained **pre-repair R1** arm64 shared
  library, terminates with SIGSEGV (exit 139; core dumps disabled). The repaired
  arm64 `unit-pure` passes. Gaussian sigma, kernel dimensions and matrix-pointer
  setter/copy round-trips pass, and compile-time offset/reserve-end checks hold.
- This is host-only evidence about memory layout and option propagation, not
  hardware Gaussian pixel correctness.

The complete native x86_64 GCC 14 Meson suite passes **37/37**, with zero
failures, skips or timeouts. The arm64 `unit-pure` result is **68 assertions,
zero failures**, including ten new guarded-copy/Gaussian checks. The native
build uses the already documented non-aarch64 `-fpermissive` workaround for
upstream pointer-to-32-bit casts; the first native build without that flag
failed on those existing casts. The authoritative arm64 ABI build uses no such
flag. Native logs are in `test-results/reserve-native-suite.log` and
`test-results/reserve-native-build/meson-logs/`; its regenerated x86_64 UAPI
smoke document was not substituted for the tracked aarch64 receipt.

Editor LSP diagnostics were not usable: the available session kept treating the
C++ test as C with `-std=gnu11` and omitted header include paths, even with a
temporary checkout-local configuration. That temporary file was removed.
This is a tooling limitation, not a clean-LSP claim; real GCC C/C++ compilations
and test results above are the validation evidence. No hosted full-workflow,
sanitizer, analyzer or reproducibility rerun is claimed for this repair; prior
results remain attributed to their original commits in the historical receipt.

## Unmodified cumulative gate: still RED

Executed the existing **`bash ci/abi-steps.sh`**, not a replacement comparison.
It rebuilt R0 and repaired R1 with the same GCC/libstdc++ 14.2, `-g -O2`, no LTO,
and DWARF in one Trixie arm64 container. libabigail 2.6.0 reports:

```text
Functions changes summary: 16 Removed, 6 Changed (117 filtered out), 54 Added functions
Variables changes summary: 2 Removed, 2 Changed, 1 Added variables
Function symbols changes summary: 0 Removed, 1 Added function symbol not referenced by debug info
Variable symbols changes summary: 0 Removed, 2 Added variable symbols not referenced by debug info
abidiff exit=12
```

The wrapper exits 1, correctly rejecting incompatible changes. Identical,
additive and hidden-public-symbol controls remain 3/3. Size repair does not
change the number of reported types: reserve consumption remains visible to the
unfiltered comparator, as do the independent changes below. No noise-only result
or green ABI gate is claimed.

Local raw evidence is under `test-results/abi/` (both DWARF builds and
`abidiff.txt`), `test-results/abi-repair-run.log`, and
`test-results/layout-probe.c`. Earlier baseline reports remain under
`test-results/todo41/`. These are ignored build artifacts, not released binaries.

## The 16 removed functions and two removed variables

**All 18 are intentional upstream source changes inherited from the 1.10.5
base, not accidental CeraLive visibility edits and not build artifacts.**
“Intentional upstream” does not mean acceptable for this SONAME-stable drop-in.
Every row remains a **D29 blocker**. Disposition: preserve the failing gate;
an independently scoped compatibility repair must restore each R0 entry point
or variable with its original contract while retaining the current feature set.
None is waived because its declaration is internal rather than installed.

The exact ELF names are in
[`baseline-symbols-upstream-delta.txt`](../packaging/baseline-symbols-upstream-delta.txt)
and the raw `abidiff` report. The existing packaging allowance is **not**
cumulative ABI clearance. Its “legitimately no longer exports” wording must not
be interpreted as overriding D29 or the independent `abidiff` gate.

| Removed R0 function | Source mechanism / current disposition target |
|---|---|
| `NormalRgaInitTables()` | Removed when `core/NormalRgaApi.cpp` switched runtime-filled trig tables to static constants; restore the old entry point's contract. |
| `NormalRgaSetBitbltMode(rga_req*, rga_interp, unsigned char, unsigned int, unsigned int, unsigned int, unsigned int)` | Interpolation parameter changed from value to pointer; the old mangled entry point is gone. |
| `get_buf_size_by_w_h_f(int, int, int)` | Made `static` in `core/RgaUtils.cpp`; the old exported helper is gone. |
| `get_string_by_format(char*, int)` | Made `static` in `core/RgaUtils.cpp`; the old exported helper is gone. |
| `rga_check_driver(rga_version_t&)` | Reference parameter changed to value. |
| `rga_check_info(const char*, rga_buffer_t, im_rect, int)` | Final parameter replaced by `rga_info_resolution_t`. |
| `rga_check_rotate(int, rga_info_table_entry&)` | Reference parameter changed to pointer. |
| `rga_get_info(rga_info_table_entry*)` | Replaced by a form adding an initial `rga_hw_versions_t*`. |
| `rga_import_buffer(uint64_t, int, im_handle_param_t*)` | Old symbol removed; the parameter-taking functionality is now named `rga_import_buffer_param`; a size-taking `rga_import_buffer` also exists. |
| `rga_log_level_init()` | Removed; upstream now resolves logging settings through the logging path. |
| `rga_set_buffer_info(rga_buffer_t, rga_info_t*)` | Made `static` in `im2d_api/src/im2d_impl.cpp`. |
| `rga_set_buffer_info(rga_buffer_t, rga_buffer_t, rga_info_t*, rga_info_t*)` | Second overload made `static` in the same source file. |
| `rga_task_submit(im_job_handle_t, rga_buffer_t, rga_buffer_t, rga_buffer_t, im_rect, im_rect, im_rect, im_opt_t*, int)` | Replaced by a form adding `int` and `int*` fence parameters before the options pointer. |
| `rga_version_table_check_minimum_range(rga_version_t&, const rga_version_bind_table_entry_t*, int, int)` | Reference parameter changed to value. |
| `rga_version_table_get_current_index(rga_version_t&, const rga_version_bind_table_entry_t*, int)` | Reference parameter changed to value. |
| `rga_version_table_get_minimum_index(rga_version_t&, const rga_version_bind_table_entry_t*, int)` | Reference parameter changed to value. |

| Removed R0 variable | Source mechanism / disposition |
|---|---|
| `int cosa_table[360]` | Exported writable runtime-filled table became `static const` in `core/NormalRgaApi.cpp`. Requires restoration of the old data-symbol contract, not merely a function wrapper. |
| `int sina_table[360]` | Same transformation and separate data-symbol obligation. |

The prior [matched-build reconciliation](fix-audit.d/wave-e-abi-reconciliation.md)
already isolated these 18 from the three **additional** weak libstdc++ emissions
in the erroneous GCC 16 `-O0` versus GCC 14 `-O2` comparison. Those three weak
symbols are measurement noise; these 18 are not. No symbol restoration is hidden
inside this reserve-only repair, and no signature or visibility is changed here.

## All six changed functions and both changed variables

| Reported entity | Classification and disposition |
|---|---|
| `NormalRgaCompatModeConvertRga2(rga2_req*, rga_req*)` | Inherited `rga_req` Gaussian insertion into reserved/tail space. Compiled R0/R1 size is 504, alignment 8; preceding `rgba5551_alpha` stays at 456, size 4. Old reserve is 460/39; Gaussian is 464/16; new reserve is 480/24. Twenty bytes consumed, fifteen removed from reserve, five old tail-padding bytes used. No struct growth or preceding-field shift; retain this kernel-facing layout unchanged. |
| `NormalRgaLogOutRgaReq(rga_req)` | Same `rga_req` change, passed by value. Same compiled size/alignment; not a second reserve-size defect. |
| `NormalRgaDitherMode(rga_req*, rga_info*, int)` | DWARF also identifies the struct through its typedef. Public size now restored to 696; typedef spelling is not an entry-point change. |
| `RgaBlit(rga_info*, rga_info*, rga_info*)` | Public Gaussian/reserve change remains visible, but size is now 696 with non-reserved prefix unchanged. Fixed in this task. |
| `empty_structure(..., im_opt_t*)` | Public Gaussian/reserve change remains visible, but size is now 304 with non-reserved prefix unchanged. Fixed in this task. |
| `rga_log_level_update()` | Inherited return type changed `void`→`int` in `fb421ad` (NDK logging support). Same mangled name, real source-signature change, not stdlib noise. Old void callers discard the return register, but this report is not waived or repaired under the no-signature-change scope. |
| `g_im2d_job_manager` | Inherited `std::mutex`→`pthread_mutex_t` in `a76b3cf` (C multi-task support). DWARF size/offset unchanged on this target, but a real exported internal type change, not differing compiler emission. Retain and track for compatibility closure. |
| `rgaCtx` | Inherited internal `RGA_DRIVER_IOC_TYPE` evolution: RGA1 added at 1, RGA2 1→2, DEFAULT/MULTI_RGA 2→3. No size/offset change, but numeric semantics differ for external access to this exported pointer. Not noise and not repaired here. |

The additions (54 functions, one variable, and three symbols without debug-info
references) are additive exports, not missing-R0 replacements merely by count.
The three latter symbols are `improcessOpt` and the singleton lock/guard objects.
They cannot compensate for an absent old mangled entry point. Full compatibility
closure requires separately authorized work; until then the gate must stay red.
