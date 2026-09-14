| Candidate A; no fix. Base `b886777023e0c503134e340be348d6c1b11c8adc`, unchanged R1 library | `tests/repro/run-candidate-a.sh`, extending H1/H3; **DEMONSTRATED**: 20/20 direct-init TSan reports and duplicate opens; 1000/1000 failed HW-version calls leak one fd each through both real legacy init and im2d. RED transcript below; GREEN not run, no fix | host-shim-only | Not run; no library, public header, default, visibility or SONAME change | Not dispatched; no reviewer session or fix approval claimed | Not reported; QA evidence only |

### Candidate A — fresh R1 evidence, 2026-09-12

Branch: `qa/candidate-a-initialization`. Native x86_64, GCC 16.2.1.
From the checkout root:

```sh
bash scripts/build-sanitized.sh tsan
bash scripts/build-sanitized.sh asan
bash tests/repro/run-candidate-a.sh
```

The final command returns **1**. Complete raw evidence is retained in
`test-results/candidate-a/run.csKMOd/` (each future run gets its own directory).
Both canaries reported under the same shim preload. TSan uses `symbolize=0`;
online symbolization stalled the initial direct-init attempt (20-second timeout,
no completed observation), which is not counted among the 20 measured processes.
An earlier runner check expected the wrong ASan canary category; corrected to
the existing canary's heap-buffer-overflow before scoring any candidate.

All 20 fresh, eight-thread direct `RgaInit` processes returned 66 with TSan
data-race reports. Every process also printed:

```text
scenario=direct-init gate=atomic-spin threads=8 ok=8 ... ctx_agreed=0 refcount_after_init=8 fds_after_init=8 deinit_calls=8 last_deinit_ret=0 refcount_after_teardown=0 fds_after_teardown=7
WARNING: ThreadSanitizer: data race
```

Offline `addr2line -Cfipe build-tsan/librga.so.2.1.0 0x21e69 0x21b55 0x22234`
maps the opposing store/read to `NormalRgaOpen` lines **135/77**, reached through
`RgaInit` line 215. The unguarded null check lets eight allocations and opens
proceed; competing stores overwrite the only global owner. Draining all eight
references closes only the last published context's fd, leaving seven open.
No global was overwritten by the test. This is the exported low-level API, NOT
`c_RkRgaInit` (a no-op) or singleton construction: those two controls each ran
20/20 processes without reports, with respectively zero and one device fd.

The ASan/UBSan build ran with LSan enabled (`detect_leaks=1`) and
`verify_asan_link_order=0`. Its descriptor census printed:

```text
hwversion,RgaInit,iterations=1000,failed_calls=1000,start=0,end=1000,growing_rows=1000,verdict=RED
unset,RgaInit,iterations=1000,failed_calls=0,start=0,end=0,growing_rows=0,verdict=NOT-REPRODUCED
hwversion,improcess,iterations=1000,failed_calls=1000,start=0,end=1000,growing_rows=1000,verdict=RED
unset,improcess,iterations=1000,failed_calls=0,start=1,end=1,growing_rows=0,verdict=NOT-REPRODUCED
```

`FAKE_RGA_FAIL=hwversion FAKE_RGA_ERRNO=5` makes the query fail after open.
Legacy `NormalRgaOpen:151-155` frees the context without closing its fd;
im2d `rga_device_init` returns before publishing or closing its local fd.
These are **fd-census assertions under instrumentation**, not LSan descriptor
reports: ASan/LSan do not diagnose fd leaks, and emitted no memory-error report
for these four census processes. Successful legacy init/deinit and warmed im2d
controls are flat, excluding ordinary session ownership from the leak claim.

Subclaims deliberately not promoted: no incomplete-context read was observed;
publication without synchronization is proven, not a specific uninitialized
member read. The counter is volatile rather than atomic, but Linux increments
are mutex-protected and the measured count is eight, not a lost increment.
No refcount race was demonstrated by this init-only test. Other early-return
branches were not dynamically covered. No two-batch GREEN, hardware coverage,
ABI closure or approval to land a fix is claimed.
