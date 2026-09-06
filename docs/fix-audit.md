# Fix audit

The per-fix evidence ledger for this fork. One row per landed fix, no exceptions.
A fix with no row here is a fix with no evidence, and a row with a missing field is
recorded as a gap rather than rounded up to a pass.

The table below holds characterization rows for findings on the unmodified
upstream base: **no fix has landed yet**, and no library source has been changed.
Rows and verbatim supporting evidence are assembled from the investigation
fragments by `scripts/wire-bootstrap.sh`; supporting prose follows in appendices.

## Row schema (D21)

Every row carries exactly these six fields, and each field has a definition that
can be checked rather than asserted:

1. **Provenance SHA** — the full 40-character commit SHA of the fix in this
   repository. For a donor pick, additionally the full source SHA and its owner;
   the `git cherry-pick -x` line in the commit is the primary record, and a pick is
   made only after a **semantic** presence check against this tree, never a
   filename or message match.
2. **Reproducer** — the tracked path of the reproducer, plus its **RED transcript**
   (the named artifact appearing on the untouched base being fixed) and its
   **GREEN transcript** (the same reproducer, same invocation, on the fixed build,
   producing no artifact). Both transcripts are retained. RED must be on the base
   the fix targets; a RED observed only on the Radxa package or on R0 does not
   authorize an R1 change. A harness that will not build or run is
   `NOT-REPRODUCED` — a ledger note, never a fix. Race rows need at least 200
   iterations, run twice, with zero failures to count as GREEN.
3. **Hardware gate** — either `host-shim-only`, or the board drill id plus the
   board the transcript names. Sanitizer legs are **always** `host-shim-only`;
   TSan, ASan and UBSan do not run on a board and no row may imply they do.
4. **ABI closure** — two results, both required: `nm -D` export-set containment
   against **R0**, and `abidiff` against the **previous release**. Containment is
   directional — the set may grow, never shrink.
5. **Independent reviewer verdict, with the reviewer session id** — the verdict
   from a reviewer that is a different agent **and** a different model from the
   author, dispatched by the orchestrator, and the reviewer's **session id**
   written out in full. A landed fix may not record `GAP:` here. Where no review
   was dispatched, the row says so plainly; a missing id is never explained away
   as a lookup failure.
6. **`Upstream-status`** — where the change stands relative to upstream: reported,
   submitted with a link, already fixed upstream at a named SHA, carried
   downstream-only with the reason, or not-applicable for packaging-shaped work.

## Rows

| Provenance SHA | Reproducer (path · RED · GREEN) | Hardware gate | ABI closure (nm vs R0 · abidiff vs previous release) | Independent reviewer verdict · reviewer session id | `Upstream-status` |
|---|---|---|---|---|---|
| `GAP: no fix landed` — H1 is characterisation of the unchanged tree at `96c9a53ba94c487f9fae938c73347f5bc00e624d`. Nothing was cherry-picked and nothing was changed under `core/` or `im2d_api/`. | `tests/repro/h1_init_race.cpp` + `tests/repro/run-h1-host.sh`, scenario `c-init`. RED: **NOT-REPRODUCED**. 200 fresh processes, run twice (400 total), 8 threads released together on a `std::barrier`. Every iteration identical: `ok=8 refcount_after_init=0 fds_after_init=0`, TSan named none of `rgaCtx`/`refCount`/`mMutex`. `c_RkRgaInit()` is `return 0;` at `core/RgaApi.cpp:27` — the C shim was hollowed out and `include/RgaApi.h:41-45` documents it — so this entry point opens no device and increments no counter. Teardown returns `-19` (`-ENODEV`, "Try to exit uninit"), which is the evidence the scenario left no session. GREEN: n/a, no fix. Transcripts: `test-results/h1/c-init.{log,csv}`. | `host-shim-only` (`tests/shim/fake_rga.c`, mock device is a `memfd_create("fake-rga")`; TSan build via `scripts/build-sanitized.sh tsan`). No board contacted. | n/a — no library change, so nothing to close. `librga.so.2.1.0` in `build-tsan/` is the unmodified tree. | `GAP: no review dispatched` — this row is a host-side observation, not a landed fix. | n/a — nothing to report upstream from a NOT-REPRODUCED control. |
| `GAP: no fix landed` — as above, unchanged tree at `96c9a53ba94c487f9fae938c73347f5bc00e624d`. | Same pair, scenario `singleton-get`. RED: **NOT-REPRODUCED**. 200 fresh processes, run twice (400 total), 8 threads released together on a `std::barrier` into `RockchipRga::get()` → `RkRgaInit()` → `RgaInit()` → `NormalRgaOpen()`. Every iteration identical: `ok=8 ctx_agreed=1 refcount_after_init=1 fds_after_init=1 deinit_calls=1 refcount_after_teardown=0 fds_after_teardown=0`, TSan named none of `rgaCtx`/`refCount`/`mMutex`. The unguarded `if (!rgaCtx)` at `core/NormalRga.cpp:66` is real — only `refCount++` is inside `mMutex` — but on this host it is never reached concurrently, because `Singleton::getInstance()` (`include/RgaSingleton.h:33-40`) holds `sLock` across the whole null-check-and-construct. The eight threads serialise one level above the defect. GREEN: n/a, no fix. Transcripts: `test-results/h1/singleton-get.{log,csv}`. | `host-shim-only`, same build and shim as the row above. No board contacted. | n/a — no library change. | `GAP: no review dispatched` — host-side observation, not a landed fix. | n/a — the latent unguarded check is recorded here, not reported, because no reproducer turned it RED. |
| H10a observation; **no fix**. Execution base `96c9a53ba94c487f9fae938c73347f5bc00e624d`; library source unchanged from `57a1067a246c71fa6c9a355d1668884fda155dd5`. | `tests/repro/h10_job_handle.cpp count`, via `bash tests/repro/run-h10.sh asan` or `tsan`. **RED: counter drift.** Unknown ID `2147483647`: count/map `0/0 -> -1/0`; 64 subsequent creates yield `63/64`; valid cancellation of all 64 leaves `-1/0`. Both sanitizer builds reproduce it. RED transcripts: `test-results/h10/asan-eS80sZZq/count/transcript.txt`, `test-results/h10/tsan-KHb1J64S/count/transcript.txt` (exit 1 each). `im2d_api/src/im2d_impl.cpp:2445` decrements even when lookup finds no job. No premature creation limit found within this bounded check; all 64 creates succeed and there is no userspace count-limit gate in this source. Re-run 2026-09-06 reproduces the same line in both modes: `test-results/h10/asan-eK4JCCKy/count/`, `test-results/h10/tsan-a3eySo3y/count/`. **GREEN: none; no fix tested.** | `host-shim-only`; native x86_64, GCC 16.2.1, 2026-09-06. No board access. | Not run: QA test/docs only; no library, header, or ABI change. | Not requested; no independent reviewer session or fix approval claimed. | Not reported upstream; characterization only. CeraLive does not call this job API (task scope). |
| H10b observation; **no fix**. Execution base `96c9a53ba94c487f9fae938c73347f5bc00e624d`; library source unchanged from `57a1067a246c71fa6c9a355d1668884fda155dd5`. | `tests/repro/h10_job_handle.cpp race 2000`, run twice per mode by `tests/repro/run-h10.sh`. One real queued copy task; thread A calls `rga_job_config` then `imendJob`, thread B calls `imcancelJob` on the same job. **RED:** ASan reports a 504-byte heap-use-after-free in both runs (exit 1); TSan reports a data race and a heap-use-after-free respectively (exit 66). Transcripts: `test-results/h10/asan-eS80sZZq/race-{1,2}/transcript.txt` and `test-results/h10/tsan-KHb1J64S/race-{1,2}/transcript.txt`. Offline `addr2line` identifies `rga_job_cancel` freeing at `im2d_api/src/im2d_impl.cpp:2442` while the shim reads the config task pointer at `tests/shim/fake_rga.c:77,205`, called from `rga_job_config` at `im2d_impl.cpp:2560` after its mutex unlock. Reports stop runs early, before `imendJob` in the failing iteration; **not 2000 completed iterations**. Both canaries report; serial `control` passes 200 config/end and 200 separate create/cancel lifecycles in both modes. Re-run 2026-09-06 reproduces both: ASan heap-use-after-free (`test-results/h10/asan-eK4JCCKy/race-1/`, exit 1) and TSan heap-use-after-free (`test-results/h10/tsan-a3eySo3y/race-1/`, exit 66). **GREEN: none; no fix tested.** | `host-shim-only`; native x86_64, GCC 16.2.1, 2026-09-06. The unchanged shim captures task bytes synchronously; no claim about actual driver timing or concurrent same-handle API guarantees. | Not run: QA test/docs only; no library, header, or ABI change. | Not requested; no independent reviewer session or fix approval claimed. | Not reported upstream; same-handle lifetime finding under the host model. CeraLive does not call this job API (task scope). |
| H10c observation; **no fix**. Execution base `96c9a53ba94c487f9fae938c73347f5bc00e624d`; library source unchanged from `57a1067a246c71fa6c9a355d1668884fda155dd5`. | `tests/repro/h10_job_handle.cpp release`, via `tests/repro/run-h10.sh` in both modes. **SECOND-RELEASE-FORWARDED**, not ignored: import returns handle 1, both release statuses are `IM_STATUS_SUCCESS` (1), release ioctl counts are `0 -> 1 -> 2`. Transcripts/logs: `test-results/h10/asan-eS80sZZq/release/{transcript.txt,interposed.log}` and `test-results/h10/tsan-KHb1J64S/release/{transcript.txt,interposed.log}`; exit 1 marks the observed forwarding, not a sanitizer failure. `releasebuffer_handle` at `im2d_api/src/im2d.cpp:181-182` forwards to `rga_release_buffer`, then the ioctl at `im2d_impl.cpp:1490`. The mock accepts every release and does not track driver ownership: this proves missing userspace deduplication, **not a kernel double-free or an idempotency contract violation**. Nothing further found within the time budget. Re-run 2026-09-06 reproduces `0->1->2` in both modes, and `grep -c RELEASE_BUFFER` on the shim log counts **2** release entries, not 1: `test-results/h10/asan-eK4JCCKy/release/`, `test-results/h10/tsan-a3eySo3y/release/`. **GREEN: none; no fix tested.** | `host-shim-only`; native x86_64, GCC 16.2.1, 2026-09-06. No board access; mock release behavior only. | Not run: QA test/docs only; no library, header, or ABI change. | Not requested; no independent reviewer session or fix approval claimed. | Not reported upstream; boundary observation only. The guide describes releasing driver resources, not repeated-release semantics. |
| No fix; H2 deinit tested at `96c9a53ba94c487f9fae938c73347f5bc00e624d`; library source unchanged from `57a1067a246c71fa6c9a355d1668884fda155dd5` | `tests/repro/h2_teardown_race.cpp`; `tests/repro/run-h2.sh` invoked separately with `asan 200` and `tsan 200`. 2026-09-06, Linux x86_64, GCC 16.2.1. **RED:** ASan/UBSan 156/200 null-context reports, 44/200 clean; TSan 200/200 data-race reports, 0 clean. No timeouts or invalid cases in either complete batch. Raw results: `test-results/h2/asan/run.YGzimL/` and `test-results/h2/tsan/run.a6eMUN/`. Attached output: `docs/repro/h2-sanitizers.txt`. **GREEN: not run; no library fix.** No heap-use-after-free report observed. | host-shim-only; no physical board access | Not run: test-only change; no ABI closure claimed | Not dispatched; no reviewer session id or fix approval claimed | Not reported upstream; characterization of the pinned R1 source, not a production fix |
| No fix; H2 exit tested at `96c9a53ba94c487f9fae938c73347f5bc00e624d`; library source unchanged from `57a1067a246c71fa6c9a355d1668884fda155dd5` | Same reproducer and driver, `exit(0)` scenario, 200 fresh processes per sanitizer. **ASan/UBSan: 200/200 clean, no finding. TSan: RED, 200/200 reports** involving the singleton's static mutex (invalid mutex, invalid unlock, or destruction/use data race). No timeouts or invalid cases in either complete batch. Same raw result directories and attached output as above. The heap singleton is not automatically deleted; this does not establish a `RockchipRga` destructor/free race. **GREEN: not run; no library fix or two-run GREEN claim.** | host-shim-only; no physical board access | Not run: test-only change; no ABI closure claimed | Not dispatched; no reviewer session id or fix approval claimed | Not reported upstream; characterization of the pinned R1 source, not a production fix |
| H3: no fix applied; tested R1 source `57a1067a246c71fa6c9a355d1668884fda155dd5` through infrastructure base `96c9a53ba94c487f9fae938c73347f5bc00e624d` | `tests/repro/h3_init_fd_leak.cpp`; RED: `test-results/h3/fdcensus.csv`, `hwversion-improcess.txt` and `hwversion-improcess.interposed.log`; GREEN: not run, no fix in todo 23; unset controls: `test-results/h3/control-fdcensus.csv` | host-shim-only | Not run: nm containment vs R0 and abidiff vs previous release; no library source, headers or build flags changed by this reproducer | Not dispatched; reviewer session id unavailable; this is a pre-fix finding, not a reviewed/landed fix | Unreported; 1.10.6 repeated-open fix is a plan hint only, not verified at a source SHA; no donor attribution or upstream-closure claim |
| n/a (measurement only — no fix landed) | `tests/repro/h4_getenv_count.cpp`, `tests/repro/run-h4-host.sh` · counts recorded below, no RED/GREEN pair because nothing was changed | `host-shim-only` (board leg **DEFERRED**, see below) | n/a (measurement only — no exported symbol added, removed or changed) | GAP: no independent review dispatched for a measurement-only row | not-applicable (upstream behaviour measured as-is, not modified) |
| H5 (RT-1) `imconfig(IM_CONFIG_SCHEDULER_CORE, IM_SCHEDULER_DEFAULT)` rejected: **RED, no fix landed**. Base `96c9a53ba94c487f9fae938c73347f5bc00e624d` (`integration/1.10.5-ceralive.1`), library source unchanged by this row. Site: `im2d_api/src/im2d.cpp:862-871`; `IM_SCHEDULER_DEFAULT` is `0` (`im2d_api/im2d_type.h:117`) and the setter gates on `value & IM_SCHEDULER_MASK`, so the one documented "let the driver choose" value is the one value it refuses. | `tests/unit/unit_session.cpp` group (f) `check_imconfig_rt1()`. **RED (host, x86_64)**, via `meson setup build-host -Dlibrga_demo=false -Dcpp_args=-fpermissive && meson test -C build-host unit-session --verbose`:<br>`== (f) RT-1 reproducer: imconfig scheduler core ==`<br>`0 536462 536462 E im2d_rga: IM2D: It's not legal rga_core[0x0], it needs to be a 'IM_SCHEDULER_CORE'.`<br>`0 536462 536462 E im2d_rga: IM2D: It's not legal rga_core[0x10], it needs to be a 'IM_SCHEDULER_CORE'.`<br>`0 536462 536462 E im2d_rga: IM2D: It's not legal priority[0x7], it needs to be a 'int', and it should be in the range of 0~6.`<br>`0 536462 536462 E im2d_rga: IM2D: Unsupported config name!`<br>`-- (f) RT-1 reproducer: imconfig scheduler core: 8 assertions --`<br>`unit-session: 85 assertions, 0 failures`<br>**RED (board, aarch64)**, cross-built with `scripts/cross-build-harness.sh`, staged to `/tmp/librga-bench/unit/`, run as `LD_PRELOAD=/tmp/librga-bench/unit/libfake_rga.so ./unit-session`:<br>`rga_api version 1.10.5_[11]`<br>`== (f) RT-1 reproducer: imconfig scheduler core ==`<br>`1 327759 327759 E im2d_rga: IM2D: It's not legal rga_core[0x0], it needs to be a 'IM_SCHEDULER_CORE'.`<br>`1 327759 327759 E im2d_rga: IM2D: It's not legal rga_core[0x10], it needs to be a 'IM_SCHEDULER_CORE'.`<br>`1 327759 327759 E im2d_rga: IM2D: It's not legal priority[0x7], it needs to be a 'int', and it should be in the range of 0~6.`<br>`1 327759 327759 E im2d_rga: IM2D: Unsupported config name!`<br>`-- (f) RT-1 reproducer: imconfig scheduler core: 8 assertions --`<br>`unit-session: 85 assertions, 0 failures`<br>`exit=0`<br>Both legs return `IM_STATUS_ILLEGAL_PARAM` (-4) for value `0`, and `IM_STATUS_SUCCESS` for `IM_SCHEDULER_RGA3_CORE0` / `IM_SCHEDULER_RGA2_CORE1`, so the rejection is specific to the mask gate and not a blanket refusal. **GREEN: none.** The fix is todo 31 (D20); the assertion flips there and nowhere else. | Board drill `h5-rt1-board`, Orange Pi 5+ `192.168.78.151`. Kernel `Linux 7.2.0-ceralive-rk3588 aarch64`, `Debian GNU/Linux 13 (trixie)`, `/dev/rga` present (`crw-rw---- root video 10, 258`). Read-only: one binary plus its preload staged to `/tmp` and removed on exit; no package installed or removed. Board lock and marker taken through `tests/board/lib.sh`. | n/a. No library source changed, so there is no export-set or `abidiff` delta to close. Re-checked at the fix in todo 31. | No independent review dispatched: this row lands no fix, only the RED characterization the fix will have to flip. | not-applicable for this row: nothing is proposed upstream by a RED transcript. The upstream disposition is decided with the todo-31 fix. |
| H6a · WITHDRAWN · no fix SHA | Positive-success polarity: WITHDRAWN, not tested; no real positive-success submit path exists on the island. | host-shim-only | Not applicable: no library change | Not dispatched: reproducer-only task, no fix approval claimed | Not applicable: withdrawn hypothesis |
| H6b · R1 base `57a1067a246c71fa6c9a355d1668884fda155dd5` · no fix SHA | `tests/repro/h6_polarity_fence.cpp` C2 · RED 200/200, fd 0 remains open after successful legacy async submit; `test-results/h6/iterations.csv` · GREEN not run, no fix | host-shim-only | Not run: no library change | Not dispatched: reproducer-only task, no fix approval claimed | Not reported; downstream reproduction only |
| H6c · R1 base `57a1067a246c71fa6c9a355d1668884fda155dd5` · no fix SHA | `tests/repro/h6_polarity_fence.cpp` C3 · RED 200/200, failed async `improcess` retains stale release fd 10 rather than -1; `test-results/h6/iterations.csv` · GREEN not run, no fix | host-shim-only | Not run: no library change | Not dispatched: reproducer-only task, no fix approval claimed | Not reported; downstream reproduction only |
| H6d · R1 base `57a1067a246c71fa6c9a355d1668884fda155dd5` · no fix SHA | `tests/repro/h6_polarity_fence.cpp` C4 · RED 200/200, `imsync` returns failure without closing fd 10; `test-results/h6/iterations.csv` · GREEN not run, no fix | host-shim-only | Not run: no library change | Not dispatched: reproducer-only task, no fix approval claimed | Not reported; downstream reproduction only |
| none — no fix landed | `tests/repro/h9_address.cpp` · **NOT-REPRODUCED** on `96c9a53ba94c487f9fae938c73347f5bc00e624d`: a buffer pinned at `0x7f0000012340` arrived in the request bytes as the full 64-bit value, not truncated · no GREEN, because there is no RED | `host-shim-only` | not applicable — no code change, so no export-set or `abidiff` delta | not dispatched: a finding row with no fix has nothing to review | not-applicable — nothing reported upstream |
| none — no fix landed | `tests/repro/h9_stdout.cpp` · **REPRODUCED**: with fd 1 redirected to a pipe, the library wrote 87 bytes of error text to stdout when `/dev/rga` was unavailable, and 28 bytes of version banner when it was · no GREEN, because no fix was written | `host-shim-only` | not applicable — no code change | not dispatched: a finding row with no fix has nothing to review | not-applicable — nothing reported upstream |

## Appendix — h1.md

Source: [fix-audit.d/h1.md](fix-audit.d/h1.md). D21 rows are in the [ledger above](#rows).


Board-side static-ASan real-hardware leg deferred — boards temporarily unavailable, to be appended by a follow-up task without modifying the host rows above.

<!--
Notes for whoever appends the board leg or wires this fragment.

1. SCHEMA LINES. The two lines above are the column headers copied from
   docs/fix-audit.md, as the H1 task asked for. scripts/wire-bootstrap.sh copies
   the master file down to its own `|---|---|---|---|---|---|` separator and then
   appends every fragment beneath it, so the coordinator must DROP those two
   lines when wiring or the assembled table renders a second header mid-body.
   They are kept here so this fragment reads correctly on its own.

2. WHAT "CLEAN" IS WORTH HERE. The TSan runtime is linked into both the library
   and the client (`nm -uD` shows 18 and 19 `__tsan_*` imports respectively) and
   `build-tsan/tsan-canary` still fires, so a silent run means TSan was watching
   and saw nothing. It does NOT mean the unguarded check is safe — only that this
   host, this scheduler and the singleton lock above it did not expose it.

3. A CONTROL IS NOT A PASS. The `c-init` row is NOT-REPRODUCED because the entry
   point is a stub, not because a race was ruled out. Do not summarise the two
   rows together as "8-thread init is race-free".

4. WHAT WOULD TURN IT RED. Threads reaching `RgaInit()`/`NormalRgaOpen()` without
   passing through `Singleton::getInstance()` — the counters and the fd census in
   the client are already wired to detect a duplicate open (`fds_after_init > 1`)
   and a duplicate increment (`refcount_after_init > 1`).

5. TRANSCRIPTS. `test-results/` is gitignored, so the transcripts cited above are
   reproducible by re-running `bash tests/repro/run-h1-host.sh 200`, not committed
   artifacts.
-->

## Appendix — h3.md

Source: [fix-audit.d/h3.md](fix-audit.d/h3.md). D21 rows are in the [ledger above](#rows).


### H3 — init-failure fd census [EXISTS]

**2026-09-05, native x86_64 host, GCC 16.2.1: RED.** No board access and no
library changes. The test links the ordinary, uninstrumented shared `librga`,
not the zero-initialized golden library. This is a descriptor census, not an
ASan/TSan result or a hardware acceptance claim.

Run from the checkout root with Meson, Ninja, GCC, GNU coreutils and a soft
`RLIMIT_NOFILE` of at least 1032:

```sh
bash tests/repro/run-h3.sh
```

The runner uses `build-host/`, writes `test-results/h3/`, and starts a fresh
process for each combination. Remove inherited `LD_PRELOAD` and `FAKE_RGA_*`
variables first; the runner rejects them. Exit 0 means NOT-REPRODUCED, 1 means
RED, and 2 means an invalid run/control failure. The first build configures the
documented x86 host `-fpermissive` workaround; no source patch or sanitizer is
involved. Run the ordinary full host suite separately with
`meson test -C build-host --print-errorlogs`.

`fdcensus.csv` has 6,000 measurements, with columns
`knob,api,iteration,status,errno,before,after,delta,cumulative_delta`.
`control-fdcensus.csv` has another 2,000. Counts come from `/proc/self/fd`
symlinks exactly matching `/memfd:fake-rga (deleted)`, excluding image buffers,
logs and the census directory fd. Failure cases are never warmed up, cleaned
up, fork-batched or reset between iterations. Each unset control has one
successful warmup outside its 1,000 measured calls so a live session is not
misclassified as a leak. A missing shim marker, fd exhaustion, incomplete run
or non-flat control invalidates the experiment.

| Knob | Call | Measured calls | Failed calls | Device fds start → end | Rows with delta ≥ 1 | Verdict |
|---|---|---:|---:|---|---:|---|
| hwversion | c_RkRgaInit | 1000 | 0 | 0 → 0 | 0 | NOT-REPRODUCED |
| hwversion | improcess | 1000 | 1000 | 0 → 1000 | 1000 | **RED** |
| driverversion | c_RkRgaInit | 1000 | 0 | 0 → 0 | 0 | NOT-REPRODUCED |
| driverversion | improcess | 1000 | 0 | 0 → 1 | 1 | NOT-REPRODUCED; live fallback session |
| getinfo | c_RkRgaInit | 1000 | 0 | 0 → 0 | 0 | NOT-REPRODUCED |
| getinfo | improcess | 1000 | 1000 | 0 → 1 | 1 | NOT-REPRODUCED; partial session retained |
| unset (control) | c_RkRgaInit | 1000 | 0 | 0 → 0 | 0 | NOT-REPRODUCED; flat |
| unset (control) | improcess | 1000 | 0 | 1 → 1 | 0 | NOT-REPRODUCED; flat after warmup |

#### Fault mapping and source mechanism

The inherited shim recognized only full ioctl names and could retain only 256
fake device fds. This task adds two shorthand aliases, a response-injection
case, and a 4096-fd capacity. The shim contract tests cover all additions,
including 1,000 simultaneously open descriptors. Existing full-name failures
and default responses are preserved. `FAKE_RGA_ERRNO=5` supplies EIO; errno is
diagnostic only and can remain stale on a successful library call.

- **`hwversion`** aliases `RGA_IOC_GET_HW_VERSION`. The driver-version query
  succeeds, then hardware-version ioctl returns -1/EIO. The call chain is
  `improcess` → `rga_single_task_submit` → `rga_task_submit` → `get_rga_session`
  → `rga_session_init` → `rga_device_init`. At
  `im2d_api/src/im2d_context.cpp:124-127`, the local opened fd is neither closed
  nor published to `session->rga_dev_fd`. The next call retries initialization.
  All 1,000 calls return `IM_STATUS_NO_SESSION` (-6), each leaks exactly one fd,
  and all 1,000 corresponding HW ioctls return -1/EIO. No open fails.
- **`driverversion`** aliases the UAPI's intentionally misspelled
  `RGA_IOC_GET_DRVIER_VERSION`. Only that ioctl fails: legacy `RGA2_GET_VERSION`
  succeeds. The session initializes once and every `improcess` returns success
  (1). This is **not** a reproducer of the branch where all three version
  queries fail; no hidden secondary fault is injected to make it RED.
- **`getinfo`** cannot be a failed ioctl: `rga_get_info` is a userspace lookup
  (`im2d_impl.cpp:451-745`). The shim instead returns a successful HW query
  containing unsupported core version `99.0.0`. The lookup takes its error path;
  `rga_session_init` returns without rollback at `im2d_context.cpp:187-190`.
  The first `improcess` returns -6, the next 999 return -1. Its fd was already
  stored at line 161, so `get_rga_session`'s `rga_dev_fd > 0` fast path reuses
  the incomplete session. The resulting single retained fd is visible but is
  **not repeated-open growth**. There is exactly one open/HW query, and the
  library log confirms `get RGA hardware info failed!`. Shutdown's existing
  `rga_session_deinit`/`rga_device_exit` path owns that stored fd; this census
ends before process exit and does not claim to measure shutdown cleanup.
- **Legacy coverage limit:** `core/RgaApi.cpp:27-31` implements
  `c_RkRgaInit()` as `return 0` and `c_RkRgaDeInit()` as a no-op. All three
  mandated legacy combinations execute the actual API and produce empty shim
  logs. They do **not** reach `NormalRgaOpen`. Its missing close at
  `NormalRga.cpp:151-155` remains a source observation only; this task does not
  substitute a different legacy entry point or claim dynamic coverage there.

The repeated-growth criterion is met only by hwversion/improcess. The one-fd
startup changes in the other im2d rows are explicitly retained above, not
reported as completely flat runs or promoted to additional RED cases.

#### Retained evidence

All raw files are repo-local and gitignored. Per-case `.txt` files retain library
output and verdict; `.interposed.log` files retain every open and ioctl. The
`summary.txt` file carries all eight case summaries. CSV SHA-256 values:

```text
4b4005408221c42c8a8b2073426d32d58040a02d40107b86644176c5e48b1275  fdcensus.csv
040e530374a5b9fea824cee4626c8f98f456c35e89f6836df17c024682f52e18  control-fdcensus.csv
```

Verification: the complete native host Meson suite passed **15/15**, including
the extended shim contract and all eight unchanged goldens. The UAPI result is
an x86_64 smoke run, not an aarch64 claim. ShellCheck, Bash syntax checking and
source/shell LSP error diagnostics were clean. The host test's generated
`docs/UAPI-PARITY.md` change was discarded rather than replacing the checked-in
aarch64 record with host evidence.

## Appendix — h4.md

Source: [fix-audit.d/h4.md](fix-audit.d/h4.md). D21 rows are in the [ledger above](#rows).

# H4 — per-operation `getenv()` cost

Measurement notes, not a landed fix. No source under `core/` or `im2d_api/`
changed for this row, so the schema fields below that describe a change carry
`n/a (measurement only)` rather than an invented value.

The table repeats the six-field schema from [`docs/fix-audit.md`](../fix-audit.md)
so this fragment reads standalone.


## Host leg — measured

Ran on the x86-64 development host against the `fake_rga` shim
(`tests/shim/fake_rga.c`), library built from this worktree with `-fpermissive`
for the reason documented in [`docs/SANITIZERS.md`](../SANITIZERS.md). The shim's
`getenv()` interposer keeps a process-global counter and flushes it from a
destructor to the path named by `FAKE_RGA_GETENV_COUNT`, so each operation kind
is measured in its own process.

Literal counts, 1000 operations each:

| Operation | 1000 calls | Fixed init cost | Per operation |
|---|---|---|---|
| `c_RkRgaBlit()` | **1002** | 2 | **1** |
| `improcess()` | **2002** | 2 | **2** |

The split into a fixed part and a per-operation part is measured, not inferred:
the same runner at 1 and 10 iterations gives 3 / 12 for `c_RkRgaBlit()` and
4 / 22 for `improcess()`, which fits `2 + 1n` and `2 + 2n` exactly.

Where the calls come from, per the call sites read before measuring:

- `core/NormalRga.cpp:49-59` — `get_int_property()` reads `ROCKCHIP_RGA_LOG`
  with `getenv()` on the non-Android path. There is no cache; every call is a
  fresh environment scan.
- `core/NormalRga.cpp:421-424` — `RgaBlit()` calls `is_debug_log()` on entry.
  That is the single lookup per `c_RkRgaBlit()`, and both operation kinds pay it
  because `improcess()` funnels down into the same blit.
- `im2d_api/src/im2d_impl.cpp:3945` — the im2d submit path calls `is_debug_log()`
  again before `RgaBlit()` is reached. This second call is why `improcess()`
  costs two lookups per operation and `c_RkRgaBlit()` costs one.
- `im2d_api/src/im2d_log.cpp:95` and `:108` — `ROCKCHIP_RGA_LOG` and
  `ROCKCHIP_RGA_LOG_LEVEL` are read once for the log-level state. That is the
  fixed cost of 2, and it does not repeat per operation.
- `im2d_api/src/im2d_impl.cpp:1879` and `im2d_api/src/im2d_context.cpp:187` —
  `rga_check()` and `rga_get_info()` were read as candidate call sites and are
  **not** on this count: neither reaches `getenv()` on its own.

`improcess()` therefore pays twice what the legacy blit entry point pays for the
same 4K NV16-to-NV12 conversion, and the cost is per call rather than amortised.

Reproduce with:

```sh
bash tests/repro/run-h4-host.sh
```

Artifacts land under the gitignored `test-results/h4/`.

## Profile leg — skipped, honestly

`valgrind` is not installed on this development host, and nothing was installed
to change that. `test-results/h4/callgrind.txt` records the skip verbatim rather
than a fabricated profile. The runner already carries the callgrind invocation —
5000 `improcess()` calls at the golden G1 geometry, then
`callgrind_annotate --inclusive=yes` truncated to the top 15 lines — so on a host
that has valgrind the leg runs with no edit.

## Board leg — DEFERRED

The other half of H4 is the microsecond-level split between time spent in
userspace and time spent waiting on the hardware. That measurement needs real
silicon: it is a wall-clock comparison across the `ioctl` boundary on an
Orange Pi 5+ and a Rock 5B+, and the host shim cannot produce it — the shim
models ioctl return values and never executes a blit, so any timing taken
against it measures the shim.

Both bench boards were unreachable when this leg was written, so it is
**DEFERRED**, not failed and not skipped-as-unnecessary. It is appended here as
its own section and its own row when a board is available. The host rows above
are complete as they stand and do not change when it lands.

## Appendix — h6.md

Source: [fix-audit.d/h6.md](fix-audit.d/h6.md). D21 rows are in the [ledger above](#rows).


## H6 reproduction: 2026-09-05

**H6a is WITHDRAWN:** the island's blit/submit ioctls return 0 on success; only
version queries return `true`, and librga already accepts those with `>= 0`.
There is no real positive-success submit path to make RED. No H6a test ran and
no positive submit-return override was used. The pre-existing shim contract's
arbitrary-return-override check is infrastructure coverage, not H6a evidence.

### Build and run

```sh
bash tests/repro/run-h6.sh
# Expected on this unfixed base: exit 1, three RED rows, all controls pass.
meson test -C build-host --print-errorlogs
shellcheck tests/repro/run-h6.sh
```

Execution base: `96c9a53ba94c487f9fae938c73347f5bc00e624d` (todo-19 infrastructure
on R1). `git diff 57a1067a246c71fa6c9a355d1668884fda155dd5 -- core im2d_api include`
is empty: all library sources and public headers are the untouched imported base.
Host: native Linux x86_64, GCC 16.2.1, Meson 1.12.0. The reproducer links the
ordinary `build-host/librga.so.2.1.0`, **not** the auto-initialized golden archive.
The existing x86 pointer-cast workaround `-fpermissive` applies to the library
build; the new reproducer compiles with `-Wall -Wextra -Werror` without it.

The shim marker is mandatory before calling either API. Buffer memfds and
readable eventfds are real host descriptors, not DMA-BUFs or kernel sync_files.
Both lazy RGA contexts are warmed before measuring. Each census enumerates
`/proc/self/fd`, excluding its own directory descriptor; `fcntl(F_GETFD)` checks
the specific fence. Leaked fds are closed by the harness **after** measurement,
and the census returns to its baseline after each ownership case. This is 200
independent deterministic observations per case, not a claim of 200 accumulated
leaks, and not a race or sanitizer test. No board was contacted.

### Observations

| Case | Iterations | Observed result in every iteration | Verdict |
|---|---:|---|---|
| C2 / H6b | 200 | `c_RkRgaBlit` returns 0; fd 0 still open; census 10 → 10, expected 10 → 9 | RED |
| C3 / H6c | 200 | `improcess(IM_ASYNC)` returns `IM_STATUS_FAILED` (0); release output remains 10, expected -1; census 10 → 10 | RED |
| C4 / H6d | 200 | `imsync(10)` returns `IM_STATUS_FAILED` (0); fd 10 still open; census 11 → 11, expected 11 → 10 | RED |

C2 explicitly closes stdin and uses `dup` on an eventfd to obtain **valid fd 0**,
then restores the saved stdin. Its path is `c_RkRgaBlit` → `RockchipRga::RkRgaBlit`
→ `RgaBlit` (`core/NormalRga.cpp:1456–1497`). The default shim driver version
1.3.11 enables `RGA_DRIVER_FEATURE_USER_CLOSE_FENCE`; the `> 0` close predicate
excludes fd 0. Controls ran 200 times each: acquire=-1 leaves the census 10 → 10;
a positive acquire fd closes and changes 11 → 10. Output fences are -1 throughout
C2. The analogous modern close predicate at `im2d_impl.cpp:2356–2358` was inspected
but is not a second C2 runtime claim.

C3 first obtains a real release fd from a successful async `improcess` using
`FAKE_RGA_OUT_FENCE=10`, then successfully `imsync`s it closed, leaving its number
in the caller's output variable. A subsequent failing async submit must clear
that variable to -1; instead it leaves the stale value. The path is the public
`improcess` overload → `rga_single_task_submit` → `rga_task_submit`; the ioctl
failure jumps past the only output assignment (`im2d_impl.cpp:2340–2359`).
**Fault-name correction to the plan:** `IM_ASYNC` selects `RGA_BLIT_ASYNC`, so
the failing call uses `FAKE_RGA_FAIL=RGA_BLIT_ASYNC` and `FAKE_RGA_ERRNO=5`.
Every iteration also proves that `FAKE_RGA_FAIL=RGA_BLIT_SYNC` fails a synchronous
call but permits the async seed call. Setting the SYNC knob alone could not
reproduce the async failure. Failed shim submissions never write output fields.

C4 uses `FAKE_RGA_SYNC_FAIL=1` to inject -1/EIO at the `poll` called by the real
`rga_sync_wait`, not by replacing `imsync` or the wait function. The early return
at `im2d.cpp:852–854` skips the `close` at line 857. Its successful-wait control
runs 200 times and closes the fd with census 11 → 10. The shim knob deliberately
matches only a single nonnegative fd, POLLIN, infinite-timeout poll; other polls
forward unchanged. This models wait failure/ownership, not real fence completion.

The runner requires exactly 200 logged synchronous submit failures, 200 async
submit failures and 200 injected poll failures, all with errno 5. This rules out
a validation failure before ioctl being misclassified as an injected failure.
The extended shim contract checks -1/0/positive output values for both blit modes
and both request commands, failed-submit output preservation, and poll forwarding.

### Retained evidence and validation

- `test-results/h6/cases.csv`: three summaries, each `200,200,RED`.
- `test-results/h6/iterations.csv`: 1,200 data rows: 600 case rows and 600 fd-control
  rows, with status, specific-fd state, before/after census and release output.
- `test-results/h6/run.log`, `interposed.log`, `requests.bin`, `exit-status.txt`:
  raw library diagnostics, shim calls, unmodified input request bytes and exit 1.
- Existing native Meson suite: **15/15 OK, no skips or failures**, including the
  expanded shim contract, all eight goldens, both unit groups and host-only
  board-oracle/board-timing tests. Those two names do not imply board access.
- ShellCheck: clean. C shim/contract and shell LSP error diagnostics: clean.
  The editor LSP misclassified the standalone C++ file with C/gnu11 flags on
  both attempts; a fresh `clangd --check` using an exact, temporary C++14 compile
  database exited 0 with no errors. The temporary database was removed afterward.
- No production source, Meson registration, golden fixture, release pin or ABI
  changed. No GREEN fix run, ABI closure or independent fix review is claimed.

SHA-256 of the retained run artifacts:

```text
56381f9a2d205ca6049e410857c65dae05a6816bb9bd8b2ebbd3af464e897991  cases.csv
e65914080601fdcfd064fd0b1db2c10491cdce567112eba934872667a246642c  iterations.csv
700789cab87a40b4cfebf4f05ea350b9653c9a9b493643aa7e2cf7a74a10b355  run.log
106b4ac6c2a9b89952a9fde73513443c687d358258bfb70e7a887a83a2efb747  interposed.log
36e1d89d401e44d1f79ba4d418286677f11eb187c9ef8cec5650f79070a0e164  requests.bin
89eb998b392c4d2677f5a96be0906d83c974107b2932bd38722da71eb2b398ee  librga.so.2.1.0
```

## Appendix — h9.md

Source: [fix-audit.d/h9.md](fix-audit.d/h9.md). D21 rows are in the [ledger above](#rows).

# H9 — high virtual addresses and stdout-routed diagnostics

Two hypotheses, two reproducers, run on the host shim. **Neither produced a fix.**
Both rows below are evidence rows: H9(a) came back NOT-REPRODUCED on the path the
library actually takes, and H9(b) reproduced but is a behaviour question for the
consumer track rather than a defect with a RED-on-base fix attached.

Reproducers: `tests/repro/h9_address.cpp`, `tests/repro/h9_stdout.cpp`,
driver `tests/repro/run-h9.sh`. No hardware was contacted; `tests/shim/fake_rga.c`
interposes `open()`/`ioctl()` on `/dev/rga` and dumps the raw request bytes to
`$FAKE_RGA_DUMP`.

## Rows


## H9(a) — what was printed

`0x7f0000000000` was granted on the first `mmap` attempt, so the fallback ladder
(`0x6f…`, `0x5f…`, …) never ran. The mapping base has zero low 32 bits, which
would make "full pointer" and "low 32 bits only" the same number, so the program
submits a `+0x12340` offset inside that same mapping to separate the two.

```text
=== host ===
x86_64
g++ (GCC) 16.2.1 20260810

=== h9_address ===
h9-address: mmap granted 0x7f0000000000 (requested 0x7f0000000000)
h9-address: submitting 0x7f0000012340 (full 0x7f0000012340, low32 0x00012340)
rga_api version 1.10.5_[11]
h9-address: improcess returned 1 (Run successfully)
h9-address: dump is 504 bytes, sizeof(struct rga_req)=504
h9-address: rga_req.src.yrgb_addr = 0x0000000000000000
h9-address: rga_req.src.uv_addr   = 0x00007f0000012340
h9-address: rga_req.dst.yrgb_addr = 0x0000000000000000
h9-address: rga_req.dst.uv_addr   = 0x00007f131be7c000
h9-address: VERDICT src.uv_addr holds the FULL 64-bit pointer
h9-address: full 64-bit value at dump offset 16
h9-address: low 32-bit value at dump offset 16
h9-address: offsetof(rga_req, src.yrgb_addr)=8, dst.yrgb_addr=64
h9-address: raw scan — 8-byte matches of 0x00007f0000012340: 1; 4-byte matches of 0x00012340: 1
--- interposed ioctl log ---
open /dev/rga fd=3
ioctl RGA_IOC_GET_DRVIER_VERSION fd=3 ret=1 errno=0
ioctl RGA_IOC_GET_HW_VERSION fd=3 ret=1 errno=0
ioctl RGA_BLIT_SYNC fd=3 ret=0 errno=0
```

Three things in that transcript are worth reading carefully, because the naive
version of this hypothesis is wrong in an instructive way.

**The pointer is not truncated.** `src.uv_addr` at dump offset 16 holds
`0x00007f0000012340` — every bit of the submitted address. The raw byte scan,
which knows nothing about the struct layout, agrees: exactly one 8-byte match of
the full value, at the same offset.

**It is in `uv_addr`, not `yrgb_addr`, and that is not a bug.** On the
`RGA_DRIVER_IOC_MULTI_RGA` path the setter is called as
`NormalRgaSetSrcVirtualInfo(&rgaReg, srcFd != -1 ? srcFd : 0, (uintptr_t)srcBuf, …)`,
so the fd occupies the first slot and the buffer address lands in the second.
`yrgb_addr = 0` is the fd, and the virtual address correctly follows it.

**The reason it survives is the cast.** The path that ran is
`im2d_api/src/im2d_impl.cpp:3495`, which casts with `(uintptr_t)` and has no
architecture guard at all. The truncating `(unsigned int)` casts that motivated
this hypothesis live in the `#else` arms of
`#if defined(__arm64__) || defined(__aarch64__)` blocks in both
`core/NormalRga.cpp` (lines 1126-1145, 1170-1175, 1232-1237, 1296-1313) and
`im2d_api/src/im2d_impl.cpp` (around 4423-4440). On the shipped aarch64 target
the `#if` arm is taken and the cast is `unsigned long`, which is 64-bit. On
anything else the `#else` arm truncates — but the modern im2d entry point does
not route through it. The truncating code is reachable only on the legacy
driver-version branches, on a non-aarch64 host.

`dst.uv_addr` is an ordinary kernel-chosen mapping (`0x00007f131be7c000`) and
varies run to run; only `src` is pinned.

### A build result that came out of this, not a diagnostic list

Building the library on x86_64 to run this reproducer surfaced something the
aarch64 build cannot see. The `#else` arms above do not compile on a 64-bit host
under GCC 16 without `-fpermissive`:

```text
../im2d_api/src/im2d_impl.cpp:4425:37: error: cast from ‘void*’ to ‘unsigned int’ loses precision [-fpermissive]
 4425 |                                     (unsigned int)srcBuf,
      |                                     ^~~~~~~~~~~~~~~~~~~~
```

The meson `rga-golden-host` target therefore fails outright on an x86_64
workstation. `tests/repro/run-h9.sh` sidesteps this by compiling the library
sources itself with `-w -fpermissive` rather than changing anything in the tree —
`core/` and `im2d_api/` are read-only for this work.

This does **not** contradict `docs/BUILD-FLAGS.md`. That page's measurement is on
aarch64, where the `#if` arm is selected and no truncating cast is ever compiled.

## H9(b) — what was printed

`im2d_api/src/im2d_log.h` lines 102-118 route every `IM_LOG` level, `IM_LOG_ERROR`
included, through `fprintf(stdout, …)`. The reproducer points fd 1 at a pipe,
calls `imcheck_t` on a 1x1 image, restores fd 1, and drains the pipe with a 200 ms
`poll()` so it cannot hang. Both runs use the same binary; only the shim differs.

```text
=== h9_stdout (no shim: /dev/rga absent) ===
h9-stdout: imcheck_t returned -6 (No session: failed to open /dev/rga:No such file or directory.)
h9-stdout: bytes captured from fd 1: 87
h9-stdout: VERDICT the library wrote its error diagnostic to STDOUT
h9-stdout: captured text begins ---
1 395514 395514 E im2d_rga_context: failed to open /dev/rga:No such file or directory.
--- end captured text

=== h9_stdout (under shim: /dev/rga opens, so the 1x1 size check runs) ===
h9-stdout: imcheck_t returned -4 (Illegal parameters: Hardware limitation src, unsupported operation of images smaller than 2 pixels, width = 1, height = 1)
h9-stdout: bytes captured from fd 1: 28
h9-stdout: VERDICT the library wrote its error diagnostic to STDOUT
h9-stdout: captured text begins ---
rga_api version 1.10.5_[11]
--- end captured text
```

The two runs separate two different stdout writers, and the distinction matters
more than the raw byte counts.

Without the shim, `/dev/rga` cannot be opened, and the 87 bytes are a genuine
`IM_LOGE` line — severity `E`, tag `im2d_rga_context`, complete with the timestamp,
tid and pid prefix from the `IM_LOG` format string. An error diagnostic went to
stdout.

With the shim, the device opens and the call gets far enough to hit the real size
check, returning `-4` with an accurate message. The 28 bytes on stdout are **not**
that message: they are the `rga_api version 1.10.5_[11]` banner the library prints
once at context init. The `-4` text reached the caller through `imStrError` and the
per-thread error string, not through stdout. So this run demonstrates the second,
quieter half of the same behaviour — the library writes an unsolicited banner to
stdout on every successful init, whether or not anything failed. The same banner is
visible mid-transcript in the H9(a) run above.

Neither is a correctness fault in the request bytes, and neither is being fixed
here. Changing the log sink is a behaviour change for every caller and collides
directly with the frozen-defaults rule in `AGENTS.md`. It is recorded so the
consumer side knows that a process which captures librga's stdout will find
library text mixed into it.

## Supporting context: the compiler diagnostics from `docs/BUILD-FLAGS.md`

Copied verbatim. The relevant fact is that the list is empty, and the page says so
explicitly:

> **They do not.** With the plain `dpkg-buildflags` set and no extra flags at all,
> the build is clean:
>
> ```text
> [1/36] Compiling C++ object librga.so.2.1.0.p/core_GrallocOps.cpp.o
> ...
> [34/36] Linking target librga.so.2.1.0
> [36/36] Linking static target librga.a
> compile exit: 0
> ```
>
> 36 of 36 targets, exit 0, and no diagnostic of any kind reached the log. There is
> therefore no diagnostic list to record here, because there were no diagnostics.
>
> Two things make that result less surprising than it looks, and both are worth
> knowing before someone "fixes" them:
>
> - `meson.build` compiles the library with `cpp_args : ['-w']`, which suppresses
>   every warning the project would otherwise emit at `warning_level=3`. Warnings
>   are invisible in this build by upstream's choice. Errors are not suppressed by
>   `-w`, so the clean exit is still a real result about errors — but do not read
>   it as "the code is warning-clean".
> - Nothing in the packaged sources (`core/`, `im2d_api/`, `include/`) performs the
>   conversion in a form GCC 14 rejects. The Android and sample paths, which are
>   the usual source of that class of error, are not compiled: `-Dlibrga_demo=false`
>   keeps the demo out, and `Android.mk`/`Android.bp` are never invoked.

The flag set that page records as being in force:

> ```text
> CXXFLAGS  -g -O2 -ffile-prefix-map=<cwd>=. -fstack-protector-strong
>           -fstack-clash-protection -Wformat -Werror=format-security
>           -mbranch-protection=standard
> CPPFLAGS  -Wdate-time -D_FORTIFY_SOURCE=2
> LDFLAGS   -Wl,-z,relro
> ```

Read alongside the H9(a) build result above, the two are consistent rather than in
tension. `-w` hides warnings but not errors, and on aarch64 the truncating cast is
never compiled at all, so a clean aarch64 build and an x86_64 build that will not
link without `-fpermissive` are both true statements about the same tree.

## How to re-run

```sh
sh tests/repro/run-h9.sh
```

Builds into `build-h9-repro/` (override with `H9_BUILD_DIR`), needs no root, no
board, and no `/dev/rga`.
