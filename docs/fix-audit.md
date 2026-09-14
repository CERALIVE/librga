# Fix audit

The per-fix evidence ledger for this fork. One row per landed fix, no exceptions.
A fix with no row here is a fix with no evidence, and a row with a missing field is
recorded as a gap rather than rounded up to a pass.

The table below preserves upstream characterization and records the Wave-E fixes.
Historical RED rows describe their named base; fix rows carry their own RED/GREEN evidence.
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
| Candidate A; no fix. Base `b886777023e0c503134e340be348d6c1b11c8adc`, unchanged R1 library | `tests/repro/run-candidate-a.sh`, extending H1/H3; **DEMONSTRATED**: 20/20 direct-init TSan reports and duplicate opens; 1000/1000 failed HW-version calls leak one fd each through both real legacy init and im2d. RED transcript below; GREEN not run, no fix | host-shim-only | Not run; no library, public header, default, visibility or SONAME change | Not dispatched; no reviewer session or fix approval claimed | Not reported; QA evidence only |
| Candidate B; no fix. Base `b886777023e0c503134e340be348d6c1b11c8adc`, unchanged R1 library | `tests/repro/run-candidate-b.sh` extends H2; **DEMONSTRATED** last-reference/deinit and exit races under the stated caller pattern. TSan 200/200 each; ASan/UBSan deinit 167/200, exit 0/200. Owned-reference control passes both builds. RED transcript below; no GREEN/fix | host-shim-only | Not run; no library or ABI change | Not dispatched; no reviewer session or fix approval claimed | Not reported; characterization only |
| Candidate C; no fix. Base `b886777023e0c503134e340be348d6c1b11c8adc`, unchanged R1 library | `tests/repro/candidate_c_scheduler.cpp` via `bash tests/repro/run-candidate-c.sh`; **DEMONSTRATED**, exit 1: five assertions, two failures (fresh/default and explicit-core/reset-to-default). Transcript below; no GREEN/fix | host-shim-only | Not run; test/docs only, no ABI or accepted-input changes | Not dispatched; no reviewer session or fix approval claimed | Not reported; existing validation defect reproduced |
| Candidate D; no fix. Base `b886777023e0c503134e340be348d6c1b11c8adc`, unchanged R1 library | H6 `sync-only` via `bash tests/repro/run-candidate-d.sh`; **DEMONSTRATED**, 200/200 failure calls retain the positive fence fd, 200/200 success controls consume it. Exit 1, transcript below; no GREEN/fix | host-shim-only | Not run; no library or ABI change, fence polarity unchanged | Not dispatched; no reviewer session or fix approval claimed | Not reported; error-branch cleanup evidence only |
| `4449f5f` — constrained port of donor `571a880951583a3b2a04e7e1fa900861653befde` | `tests/repro/donor_full_csc.c`: RED on `5dfe897`, legacy mode 0x201 returns -22 before submission; GREEN after port, returns 0 and captures full_csc=1/yuv2rgb=1; 0x200 and separate im2d controls pass on both; `test-results/donors/red.txt` and `csc-green.txt` | host-shim-only; no board or pixel claim | Public headers unchanged; host gates recorded separately; no R1-versus-R0 release ABI closure claimed | PENDING independent review; do not merge this port into integration until an APPROVE receipt is recorded | donor (nyanmisaka); full SHA credited by cherry-pick -x |
| Donor `338a5fe165267c4bd0704bac4628e9bb61a7806d`; no new fix | PRESENT in audited main; source/pat/destination CSC at `im2d_api/src/im2d_impl.cpp:2173-2203`; inherited at `57a1067`, not Wave E | Static semantic audit; no board command | Not applicable: no change | Not applicable: no pick | Upstream-inherited, Yu Qiaowei |
| Donor `1d330cc28551943bed3380261a5a9c6fbd58ff53`; no fix | ABSENT at `core/NormalRga.cpp:717-728` in audited main; SKIPPED for specified driver 1.3.11, outside donor's less-than-1.3.9 condition; reproducer NOT RUN, no justification | No hardware or pixel result claimed | Not applicable: no change | Not applicable: no pick | donor (nyanmisaka), not picked |
| Donor `900f9f0dc702d15536064354f6f1fd77da2719af`; no new fix | PRESENT in audited main; `im2d_api/src/im2d_hardware.h:372-385` and `im2d_api/src/im2d_impl.cpp:585-605`; both relaxed height limits inherited at `57a1067`, not Wave E | Static semantic audit; no board command | Not applicable: no change | Not applicable: no pick | Upstream-inherited, Yu Qiaowei |
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
| Wave-E A; first-party initialization fix; commit resolved by `git log --format=%H --grep='fix(init): serialize context publication and unwind failed opens'` | `tests/repro/run-candidate-a.sh`: RED direct-init 20/20 TSan and 1000/1000 leaked fds per API; GREEN same command, then 200 processes per scenario twice; transcripts below; fresh takeover run in `wave-e-verification.md` | host-shim-only | No removal or incompatible change vs pre-fix R1; strict R0 closure BLOCKED by pre-existing removals, see `wave-e-verification.md` | Independent full-series review pending; not approved for merge | Downstream-only: initialization ownership repair; not yet submitted upstream |
| Wave-E B; first-party teardown fix; commit resolved by `git log --format=%H --grep='fix(lifetime): drain active operations before final context release'` | `tests/repro/run-candidate-b.sh`: fresh RED on `1bde9018`, GREEN with active-operation draining and process-lifetime lookup lock; transcripts below | host-shim-only; no board claim | No removal or incompatible change against pre-fix R1; strict R0 closure BLOCKED by pre-existing removals, see `wave-e-verification.md` | Independent review pending; no approval or reviewer session id; NOT approved for merge | Downstream-only: borrowed-last-reference and exit-time lock lifetime repair; not submitted upstream |
| Wave-E C; first-party scheduler-default fix on `1bde9018d28092879978419f8e48f2b88debcbaa`; commit resolved by `git log --format=%H --grep='fix(imconfig): accept the documented default scheduler'` | `tests/repro/run-candidate-c.sh`: RED 2/5 assertions, GREEN 0/5 failures; transcripts below; fresh takeover and unit-session expectation migration in `wave-e-verification.md` | host-shim-only | No removal or incompatible change vs pre-fix R1; strict R0 closure BLOCKED by pre-existing removals, see `wave-e-verification.md` | Independent full-series review pending; not approved for merge | Downstream-only: documented enum acceptance; not yet submitted upstream |
| Wave-E D; first-party wait-error ownership fix; commit resolved by `git log --format=%H --grep='fix(imsync): consume the fence after a failed wait'` | `tests/repro/run-candidate-d.sh`: RED 200/200 retained fds, GREEN 0/200; transcripts below; fresh takeover run in `wave-e-verification.md` | host-shim-only | No removal or incompatible change vs pre-fix R1; strict R0 closure BLOCKED by pre-existing removals, see `wave-e-verification.md` | Independent full-series review pending; not approved for merge | Downstream-only: error-path ownership repair; not yet submitted upstream |
| Wave-E C; `63d60a317fe2f121356e18b445d92dc6403d8a42` | `tests/repro/run-candidate-c.sh`: independently rerun RED on `1bde9018`, GREEN on reviewed head `7b832a02`; 2/5 failures -> 0/5 | host-shim-only; hardware gates remain open | Matched pre-fix R1 -> head: 312 -> 315 exports, 0 removals, abidiff 4 additions only; strict R0 superset STILL FAILS on 18 inherited removals, abidiff 12 | APPROVE — independent reviewer `openai/gpt-6-astra`, dispatch `ses_f62dc01d3ffeHjGpEFKZ4zGBu0`; Wave-E repairs only, NOT R1 release approval | Downstream-only; this receipt makes no upstream submission |
| Wave-E D; `59f3e83521aaddce5a5309ba764ff47b35c042b4` | `tests/repro/run-candidate-d.sh`: independently rerun RED on `1bde9018`, GREEN on reviewed head `7b832a02`; 200/200 retained wait-error fences -> 0/200, success controls intact | host-shim-only; hardware gates remain open | Matched pre-fix R1 -> head: 312 -> 315 exports, 0 removals, abidiff 4 additions only; strict R0 superset STILL FAILS on 18 inherited removals, abidiff 12 | APPROVE — independent reviewer `openai/gpt-6-astra`, dispatch `ses_f62dc01d3ffeHjGpEFKZ4zGBu0`; Wave-E repairs only, NOT R1 release approval | Downstream-only; this receipt makes no upstream submission |
| Wave-E A; `d280ee104eacc60a5ba0ab2d4d92f64b7b688360` | `tests/repro/run-candidate-a.sh`: independently rerun RED on `1bde9018`, GREEN on reviewed head `7b832a02`; 20/20 direct-init TSan reports -> 0/20, both 1000-call fd-growth cases -> flat | host-shim-only; hardware gates remain open | Matched pre-fix R1 -> head: 312 -> 315 exports, 0 removals, abidiff 4 additions only; strict R0 superset STILL FAILS on 18 inherited removals, abidiff 12 | APPROVE — independent reviewer `openai/gpt-6-astra`, dispatch `ses_f62dc01d3ffeHjGpEFKZ4zGBu0`; Wave-E repairs only, NOT R1 release approval | Downstream-only; this receipt makes no upstream submission |
| Wave-E B; `0a6a9bb76267a0157c7e7541decafdde60322a0a` | `tests/repro/run-candidate-b.sh`: independently rerun RED on `1bde9018`, GREEN on reviewed head `7b832a02`; final batch 800/800 scenario processes plus both owned-reference controls; timeout and ENOSPC attempts excluded, details below | host-shim-only; hardware gates remain open | Matched pre-fix R1 -> head: 312 -> 315 exports, 0 removals, abidiff 4 additions only; strict R0 superset STILL FAILS on 18 inherited removals, abidiff 12 | APPROVE — independent reviewer `openai/gpt-6-astra`, dispatch `ses_f62dc01d3ffeHjGpEFKZ4zGBu0`; Wave-E repairs only, NOT R1 release approval | Downstream-only; this receipt makes no upstream submission |

## Appendix — candidate-a.md

Source: [fix-audit.d/candidate-a.md](fix-audit.d/candidate-a.md). D21 rows are in the [ledger above](#rows).


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

## Appendix — candidate-b.md

Source: [fix-audit.d/candidate-b.md](fix-audit.d/candidate-b.md). D21 rows are in the [ledger above](#rows).


### Candidate B — fresh R1 evidence, 2026-09-12

Branch: `qa/candidate-b-shutdown`. Native x86_64, GCC 16.2.1.

```sh
bash scripts/build-sanitized.sh asan
bash scripts/build-sanitized.sh tsan
bash tests/repro/run-candidate-b.sh
```

The final command returns **1**. It compiles the existing H2 source under each
sanitizer and invokes its existing runner for 200 fresh processes per scenario.
Raw wrapper evidence: `test-results/candidate-b/run.98LZbp/`.
ASan/UBSan batch: `test-results/h2/asan/run.gGIVDA/`.
TSan batch: `test-results/h2/tsan/run.SwcTLe/`.
Both preloaded canaries report. LSan is enabled; TSan symbolization is offline.

```text
scenario,iterations,clean,sanitizer,other_failure,invalid
asan/deinit,200,33,167,0,0
asan/exit,200,200,0,0,0
tsan/deinit,200,0,200,0,0
tsan/exit,200,0,200,0,0
H2 refcount: before=2 after=1 deinit=0 fd_open=1 blit=0
```

The refcount line occurs in **both** sanitized builds, exit 0. It acquires a
second real `RgaInit` reference, releases it, verifies the fd still exists, and
successfully blits with the singleton's remaining reference. This refutes the
blanket claim that `RgaDeInit` ignores its reference count in serial operation.

The deinit race deliberately releases the singleton's **borrowed last reference**
while another thread repeatedly calls `c_RkRgaBlit`. It is not a test of two
independently owned references. The worker completes at least 32 successful
blits before the action marker, and the runner validates those ioctls. A sample:

```text
H2 action=deinit successful_blits=107
../core/NormalRga.cpp:1494:17: runtime error: member access within null pointer of type 'struct rgaContext'
```

TSan reports the unsynchronized `rgaCtx` store at `NormalRgaClose:203` against
the read at `RgaBlit:375` (`addr2line` offsets `0x22197`, `0x2236e` in this build).
The operation holds no lifetime reference or shared lock against that release.
The ASan/UBSan sample is a **UBSan null-context report**, not an ASan heap UAF.
No heap-use-after-free claim is inferred from a null-context failure. This proves
the missing protection for the exercised last-reference caller pattern, not that
the API promises arbitrary concurrent destruction or that normal owned-reference
usage is broken.

The exit scenario calls `exit(0)` without joining the active blit thread.
TSan's sample reports `use of an invalid mutex (e.g. uninitialized or destroyed)`
through `Mutex::lock` (`0x2e67e`, `RgaMutex.h:164`) and
`Singleton<RockchipRga>::getInstance` (`0x2e6fc`, `RgaSingleton.h:34`). The static
mutex is destroyed at process exit while another thread can still acquire it.
The heap singleton is never automatically deleted; no `RockchipRga` destructor
race or universally unspecified destructor order is established. Joining users
before process exit is a separate caller responsibility not waived by this test.

No hardware, two-batch GREEN, memory-leak finding, release gate or fix approval
is claimed. The ordinary baseline suite remains separate from these RED probes.

## Appendix — candidate-c.md

Source: [fix-audit.d/candidate-c.md](fix-audit.d/candidate-c.md). D21 rows are in the [ledger above](#rows).


### Candidate C — scheduler validation, 2026-09-12

Branch: `qa/candidate-c-scheduler-default`. Native x86_64, GCC 16.2.1.
Exact command from the checkout root:

```sh
bash tests/repro/run-candidate-c.sh
```

The runner builds the ordinary shared library and existing fake-device shim,
then compiles the new client with `-Wall -Wextra -Werror`. The assertions reuse
`tests/unit/unit_assert.h`; no new assertion framework or source library is
introduced. H5's existing characterization assertions are not changed or
weakened. Raw transcript: `test-results/candidate-c/run.uY0XGn/transcript.txt`.

```text
FAIL default accepted on fresh thread: expected 1, got -4
FAIL reset explicit core to default: expected 1, got -4
candidate-c: 5 assertions, 2 failures
Candidate C: exit=1
```

One deterministic execution; both default attempts failed (2/2). Three controls
passed: the enum really equals zero, an explicit core is accepted, and the
unsupported bit `0x10` is rejected. `imconfig` at `im2d.cpp:865-871` accepts a
scheduler only if `value & IM_SCHEDULER_MASK` is nonzero. The defined
`IM_SCHEDULER_DEFAULT=0` can never satisfy that condition, returning
`IM_STATUS_ILLEGAL_PARAM` (-4) instead of `IM_STATUS_SUCCESS` (1).
This is an existing-signature input-validation issue, not a proposed API.

The first draft failed to compile because the public header expects `NULL`
to be supplied by an earlier include. Adding `<cstddef>` to the **test only**
resolved that setup failure before obtaining the RED above. The failed build
is not defect evidence. No library fix, hardware run or sanitizer claim.

## Appendix — candidate-d.md

Source: [fix-audit.d/candidate-d.md](fix-audit.d/candidate-d.md). D21 rows are in the [ledger above](#rows).


### Candidate D — imsync error branch, 2026-09-12

Branch: `qa/candidate-d-imsync-error`. Native x86_64, GCC 16.2.1.

```sh
bash scripts/build-sanitized.sh asan
bash tests/repro/run-candidate-d.sh
```

The final command returns **1**. The existing H6 C4 loop was moved unchanged
into a callable test function; the original no-argument H6 still executes all
three existing cases. The new `sync-only` mode executes no submit/polarity case.
It uses the existing shim's `FAKE_RGA_SYNC_FAIL=1` knob, not a replacement for
`imsync` or `rga_sync_wait`.

Raw artifacts: `test-results/candidate-d/run.vYtMzT/` contains the executable,
preloaded ASan-canary transcript, every test row, and the shim log.
The runner checks exactly **200** failed `poll` calls with `errno=5` (EIO).
Recorded rows (`case,iteration,status,fd,open_after,fd_before,fd_after,out_fence,verdict`):

```text
C4-control-success,1,1,3,0,4,3,-1,PASS
C4,1,0,3,1,4,4,-1,RED
C4: RED (200/200 defect observations)
```

All 200 iterations match this pattern. The successful wait consumes the positive
eventfd. On EIO, `rga_sync_wait` returns -1, `imsync` returns
`IM_STATUS_FAILED` (**0**, not a positive success status), and `fcntl(F_GETFD)`
still finds that fd open. The live-fd census is unchanged rather than decreasing
by one. The test closes the retained fd **after recording** the failure and
asserts restoration of its baseline, so the result is 200 independent ownership
observations, not a claim of 200 accumulated fds or fd-exhaustion behavior.

Mechanism: `im2d.cpp:851-857` returns from the wait-error branch before reaching
`close(fence_fd)`. This demonstrates missing error-branch consumption under
the project's cleanup expectation. It does not establish a kernel sync-fence
bug: the fence is a host eventfd and the failed poll is injected.
The `fence_fd <= 0` validation and every submit-return polarity remain untouched.

ASan/UBSan instrument both library and client, LSan is enabled, and
`verify_asan_link_order=0` permits the existing preload. The preloaded canary
reports a heap-buffer-overflow. The candidate emits **no ASan/LSan/UBSan memory
diagnostic**; the RED is the fd ownership/census assertion. Those sanitizers do
not track file-descriptor ownership, so their silence is not leak cleanliness.
No hardware coverage, library fix, GREEN transcript or release approval claimed.

## Appendix — donors.md

Source: [fix-audit.d/donors.md](fix-audit.d/donors.md). D21 rows are in the [ledger above](#rows).


### Donor audit scope

All table ranges identify audited main `5dfe897d206a52f770137e15553c48f84964cf02`,
before the legacy CSC port. See [DONORS.md](../DONORS.md) for the four complete
semantic verdicts, authors, donor links and adaptations. Only the legacy
`RgaBlit` defect is repaired; im2d's distinct `rga_blit` already has independent,
masked full-CSC setup and is an unchanged-path control.

The `0x201` RED is a real compiled and executed rejection, not a missing-text
search or a compile failure. Initial exploration omitted `-I.` from a direct
build and incorrectly assumed im2d and legacy mode encodings matched; neither
attempt is counted as defect proof. Corrected controls follow each builder's
actual encoding. Raw final reproduction:

```text
audited main:
mode=0x200 ret=0 captured=1 full_csc=1 yuv2rgb=0 PASS
mode=0x201 ret=-22 captured=0 full_csc=0 yuv2rgb=0 FAIL
improcess src601full+patRGB+dst709full status=1 captured=1 full_csc=1 yuv2rgb=10 PASS

ported legacy path:
mode=0x200 ret=0 captured=1 full_csc=1 yuv2rgb=0 PASS
mode=0x201 ret=0 captured=1 full_csc=1 yuv2rgb=1 PASS
improcess src601full+patRGB+dst709full status=1 captured=1 full_csc=1 yuv2rgb=10 PASS
```

The port is not independently approved yet. This is a todo-39 branch, not a
todo-40 integration merge or an R1 release authorization. No existing review
receipt is reused for this new code.

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

## Appendix — r1-consolidation.md

Source: [fix-audit.d/r1-consolidation.md](fix-audit.d/r1-consolidation.md). D21 rows are in the [ledger above](#rows).

### R1 candidate consolidation — 2026-09-13 UTC

Tested merge head: `5778d1b` on `integration/1.10.5-ceralive.1`, based on
`b886777023e0c503134e340be348d6c1b11c8adc`. Native x86_64, GCC 16.2.1
20260810, Meson 1.12.0. This is characterization, not a fix or release approval.

All four original candidate tips were pushed to `origin` before any merge:

| Candidate branch | Original commit | Two-parent integration merge |
|---|---|---|
| `qa/candidate-a-initialization` | `b75213e4267f77fe68ceb78405aa77f4b1e686ae` | `ca19ae2` |
| `qa/candidate-b-shutdown` | `b0ffe9be58f7003c3dd127da5c23496e16eb67a7` | `ef7295b` |
| `qa/candidate-c-scheduler-default` | `fc797c1504e78011200a5422409c78e4921e30ec` | `e912c59` |
| `qa/candidate-d-imsync-error` | `6c167e5015c00eda1ab1aaa3db80b64775f30b2b` | `5778d1b` |

The candidate sources, runners and four original fragments are byte-identical
to their respective tips. The pre-merge bundle verified all four refs and its
`b886777` prerequisite. Candidate E's uncommitted script matched its backup and
was left untouched in the separate shared checkout. No branch was rebased,
squashed or deleted; neither R0 branch nor `main` was changed.

#### Fresh executions

From the checkout root, build both instrumented trees, then invoke each runner
independently (all four return **1**, so do not chain runners with `&&`):

```sh
bash scripts/build-sanitized.sh asan
bash scripts/build-sanitized.sh tsan
bash tests/repro/run-candidate-a.sh
bash tests/repro/run-candidate-b.sh
bash tests/repro/run-candidate-c.sh
bash tests/repro/run-candidate-d.sh
```

- **A — RED:** direct exported `RgaInit` produced TSan reports in 20/20 fresh
  processes; the first process opened eight device fds and retained seven after
  draining eight references. Both 20-process no-op/singleton controls passed.
  Injected hardware-version query failure leaked one fd per call in 1000/1000
  calls through each of real `RgaInit` and `improcess`; successful controls were
  flat. TSan offsets `0x21e69`/`0x21b55` map to `NormalRgaOpen:135/77`.
  This does not establish lost refcount increments or an incomplete-member read.
  The historical `c_RkRgaInit` entry point is a no-op, not the dynamic legacy
  failure path exercised by this direct-init extension.
- **B — RED:** ASan/UBSan deinit had 160/200 sanitizer findings, 40 clean;
  exit had 0/200 findings. TSan deinit and exit each had 200/200 findings.
  Neither batch had invalid runs or other failures. Both owned-reference
  controls printed `before=2 after=1 deinit=0 fd_open=1 blit=0` and exited 0.
  Representative diagnostics are null-context access at `NormalRga.cpp:1494`
  and use of the static singleton mutex during process exit. This demonstrates
  the borrowed-last-reference and unjoined-exit patterns, not broken serial
  refcounting or unsafe independently owned references; a null-context report
  is not evidence of heap use-after-free.
- **C — RED:** five assertions, two failures: fresh default and reset-to-default
  each expected `IM_STATUS_SUCCESS` (1), got `IM_STATUS_ILLEGAL_PARAM` (-4).
  Zero enum value, explicit-core acceptance and unsupported-bit rejection
  controls passed. This is validation inconsistency, not hardware scheduling.
- **D — RED:** all 200 injected `poll` EIO cases left the positive fence fd open
  after `imsync` returned `IM_STATUS_FAILED` (0); all 200 successful waits
  consumed it. The runner verified 200 failing poll records. Cleanup after each
  observation restored the baseline: this is not 200 accumulated leaked fds.
  This is fd-ownership evidence under ASan/UBSan/LSan instrumentation, not a
  sanitizer fd-leak diagnostic or kernel sync-file evidence.

Canaries reported with the instrumented shim preloaded. These observations are
host-shim-only. No board, library fix, full-CSC padding reproduction, two-batch
GREEN, ABI release closure or independent fix-approval receipt is claimed.

Raw evidence is retained in these repo-local, gitignored directories:

| Evidence | Directory |
|---|---|
| A | `test-results/candidate-a/run.gtir1P/` |
| B wrapper / owned-reference controls | `test-results/candidate-b/run.OlWEli/` |
| B ASan/UBSan batch | `test-results/h2/asan/run.9FU7N9/` |
| B TSan batch | `test-results/h2/tsan/run.zaLl1g/` |
| C | `test-results/candidate-c/run.fwsz5o/` |
| D | `test-results/candidate-d/run.Qd2n7G/` |

#### Green baseline, separate from the RED probes

The candidate C runner configured `build-qa` with `-Dlibrga_demo=false` and the
documented x86_64 `-Dcpp_args=-fpermissive`. Subsequent commands and results:

```sh
meson compile -C build-qa
meson test -C build-qa --print-errorlogs
bash packaging/package-contract.sh
ASAN_OPTIONS=detect_leaks=1:verify_asan_link_order=0:abort_on_error=1 \
  UBSAN_OPTIONS=print_stacktrace=1:halt_on_error=1 \
  meson test -C build-asan --print-errorlogs \
  unit-pure unit-session shim-contract goldens
QEMU_LD_PREFIX=/usr/aarch64-linux-gnu meson setup build-parity \
  --cross-file tests/uapi-parity/aarch64.cross -Dlibrga_demo=false
QEMU_LD_PREFIX=/usr/aarch64-linux-gnu \
  meson test -C build-parity --print-errorlogs --suite uapi
bash scripts/run-analyzer.sh
```

- Native baseline: **16/16 OK**, zero failures or skips: both UAPI tests,
  eight goldens, shim contract, both unit tests, wire-bootstrap, board-oracle
  and board-timing. The last two are local oracle/shim tests, not board access.
- ASan/UBSan baseline: **11/11 OK** with leak detection enabled.
- aarch64 UAPI: **2/2 OK**, GCC 16.1.0 emitters executed by local QEMU;
  21 ioctl values, 29 struct sizes and 170 member offsets. The pinned island
  header is `v2026.9.2`, SHA-256
  `ac2f110c8b91ca4ba8de644dd88981560e9681978b99976ec1804654dee1ef35`.
  The native run was only x86_64 smoke; the later cross run regenerated
  `docs/UAPI-PARITY.md` byte-identically to the committed aarch64 record.
- Static package contract: **OK**. No package build or ABI-release test claimed.
- Advisory analyzer: build exit 0, **18 findings**, six file/warning pairs,
  all six already triaged, zero untriaged. This is GCC 16 host evidence, not
  the target-suite GCC 14 CI leg.
- Error-level LSP diagnostics: clean for all five merged C++ reproducers and
  four shell runners; shell syntax checks passed.

The candidate runners are deliberately not registered in Meson; the unchanged
registration contains zero `concurrency` tests. `meson test --list --suite
concurrency` reports no suitable tests, not passing concurrency coverage.
The RED probes were executed separately above, never hidden behind a green gate.
Existing Meson fragments, library sources, public headers and defaults did not
change. This host gate is not a claim that the Debian arm64 release matrix ran.

#### Generated-ledger provenance

Each generated-ledger merge conflict was replaced by running
`bash scripts/wire-bootstrap.sh` against the available source fragments. After
the fourth merge all four fragments were present; no generated rows or appendices
were hand-resolved. This consolidation note is itself a source fragment.
The generator was run again after adding it, then a second invocation was checked
for byte-identical `docs/fix-audit.md` and `meson.build` output. The baseline's
`wire-bootstrap` test also passed its structure, preservation and idempotency
checks. All historical characterization fragments remain unchanged.

## Appendix — wave-e-a.md

Source: [fix-audit.d/wave-e-a.md](fix-audit.d/wave-e-a.md). D21 rows are in the [ledger above](#rows).


### Wave-E A — initialization ownership

Mechanism: hold the legacy mutex across context discovery, its single device open,
initialization, reference acquisition and publication; use atomic operations on the
existing refcount storage and close uncommitted device fds on initialization failure.
The modern im2d session has its own fd, so its failure paths are unwound independently.

Fixes: `core/NormalRga.cpp` (`NormalRgaOpen`, atomic reference operations and
`RgaInit` version-rejection unwind); `im2d_api/src/im2d_context.cpp`
(`rga_device_init` failure exits and failed hardware-info initialization).
The exported `volatile int32_t refCount` declaration/size is unchanged; library
accesses use `__atomic_*`. No public structure, default, signature or symbol changes.

RED on `1bde9018d28092879978419f8e48f2b88debcbaa`, exact command
`bash tests/repro/run-candidate-a.sh`:

```text
Candidate A evidence: test-results/candidate-a/run.stdc06
hwversion,RgaInit,iterations=1000,failed_calls=1000,start=0,end=1000,growing_rows=1000,verdict=RED
unset,RgaInit,iterations=1000,failed_calls=0,start=0,end=0,growing_rows=0,verdict=NOT-REPRODUCED
hwversion,improcess,iterations=1000,failed_calls=1000,start=0,end=1000,growing_rows=1000,verdict=RED
unset,improcess,iterations=1000,failed_calls=0,start=1,end=1,growing_rows=0,verdict=NOT-REPRODUCED
Candidate A: exit=1; per-process evidence in test-results/candidate-a/run.stdc06
```

`races.csv` records all 20 direct-init processes with exit 66 and a TSan report;
all 40 C-init/singleton controls exited zero without reports.

GREEN after rebuilding both sanitizer trees with `meson compile -C build-asan`
and `meson compile -C build-tsan`, same command:

```text
Candidate A evidence: test-results/candidate-a/run.mNrUYa
hwversion,RgaInit,iterations=1000,failed_calls=1000,start=0,end=0,growing_rows=0,verdict=NOT-REPRODUCED
unset,RgaInit,iterations=1000,failed_calls=0,start=0,end=0,growing_rows=0,verdict=NOT-REPRODUCED
hwversion,improcess,iterations=1000,failed_calls=1000,start=0,end=0,growing_rows=0,verdict=NOT-REPRODUCED
unset,improcess,iterations=1000,failed_calls=0,start=1,end=1,growing_rows=0,verdict=NOT-REPRODUCED
Candidate A: exit=0; per-process evidence in test-results/candidate-a/run.mNrUYa
```

Long-race acceptance: `bash tests/repro/run-candidate-a.sh 200` run twice,
`test-results/candidate-a/run.RWhWlo` and `run.OtqPmT`. Both exited zero;
each ran 200 direct-init processes and 400 controls, with zero race reports,
and repeated all four 1000-call censuses with the same flat GREEN rows above.
Both sanitizer canaries were verified in every run. The optional count only
extends the batch; the original default 20 and all original assertions remain.

Disposition: direct-init is in Meson's green `concurrency` suite; both injected
hardware-version-failure censuses are green baseline tests against the ordinary
shared library. The long canary-verified batches remain explicit host-only QA.

## Appendix — wave-e-abi-reconciliation.md

Source: [fix-audit.d/wave-e-abi-reconciliation.md](fix-audit.d/wave-e-abi-reconciliation.md). D21 rows are in the [ledger above](#rows).

### Wave-E ABI reconciliation and main merge — 2026-09-13

This amends the interpretation of the earlier 21-symbol result in
[wave-e-verification.md](wave-e-verification.md), not its recorded observations.
The original R1 comparator was a GCC 16.1.0 `-O0` debug build, whereas published
R0 was a Debian GCC/libstdc++ 14.2.0-19 packaging build with effective `-O2`.
That was unsuitable for release export-closure claims involving emitted C++
template/inline symbols. The matched measurement below supersedes that claim.

**Judgement: the matched strict R0 containment failure is inherited, not
introduced by Wave E or our shipping build configuration.** It is exactly the
documented 18 librga exports; the three additional observations were measurement
artifacts. The numeric strict-superset check still fails on those 18. They are
not suppressed or relabelled as present, and this note grants no release waiver.

#### Exact residual set

Both inputs were sorted uniquely with `LC_ALL=C`: the original R0-minus-R1
21-name measurement and the first tab-separated field of each of the 18
non-comment rows in `packaging/baseline-symbols-upstream-delta.txt`.
Their `comm -23` result is exactly:

```text
_ZNKSt5ctypeIcE8do_widenEc
_ZNSt10_HashtableIjSt4pairIKjjESaIS2_ENSt8__detail10_Select1stESt8equal_toIjESt4hashIjENS4_18_Mod_range_hashingENS4_20_Default_ranged_hashENS4_20_Prime_rehash_policyENS4_17_Hashtable_traitsILb0ELb0ELb1EEEE5clearEv
_ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEE15_M_replace_coldEPcmPKcmm
```

| Residual (demangled shorthand) | Determination | Controlled evidence |
|---|---|---|
| `std::ctype<char>::do_widen(char) const` | **(c), optimization-dependent emission in unlike builds** | Absent from GCC 16 `-O0`, present at `-O2` with the same GCC 16 cross toolchain and sources. Absent from GCC 14 debug, present in GCC 14 shipping configuration. |
| Named `std::_Hashtable<...>::clear()` specialization | **(c), compiler/libstdc++ mismatch** | Present with GCC/libstdc++ 14 at both `-O0` and shipping `-O2`; absent with GCC/libstdc++ 16 at both `-O0` and `-O2`. No librga source change between these builds. |
| `std::__cxx11::basic_string<char,...>::_M_replace_cold(char*, unsigned long, char const*, unsigned long, unsigned long)` | **(c), optimization-dependent emission in unlike builds** | Absent from GCC 16 `-O0`, present at `-O2` with the same GCC 16 cross toolchain and sources. Absent from GCC 14 debug, present in GCC 14 shipping configuration. |

All three are `FUNC WEAK DEFAULT` exports in the matched R1 shipping ELF. None
was added to an exception list: all three really are present in the dynamic
symbol table of the shipping-configuration build.

| Same fixed R1 sources, build configuration | `do_widen` | `clear` | `_M_replace_cold` |
|---|---|---|---|
| GCC/libstdc++ 14.2.0-19, debug `-O0` | absent | present | absent |
| GCC/libstdc++ 14.2.0-19, shipping effective `-O2` | present | present | present |
| GCC/libstdc++ 16.1.0, debug `-O0` (original comparator) | absent | absent | absent |
| GCC/libstdc++ 16.1.0, `debugoptimized` `-O2` | present | absent | present |

The last row has other compiler-emission differences outside the original three;
it is an isolation control, not a release artifact or substitute gate. These
observations do not attribute any removal to a Rockchip upstream commit: there
was no librga-source toggle in the matrix. No (a) documentation correction or
(b) shipping-build fix is warranted for these residuals.

Two other possible measurement causes were tested and refuted:

- `strip --strip-unneeded` on the original R1 ELF leaves its **entire** dynamic
  export set byte-identical. DWARF stripping is not what removed the three names.
- `nm -D --defined-only` and `readelf --dyn-syms --wide` (defined GLOBAL/WEAK/UNIQUE
  entries) produce exactly the same sorted export set. This is not a tool or
  truncated-name disagreement.

#### Build-configuration delta and matched control

Published R0 is release
[`1.10.1+ceralive.1`](https://github.com/CERALIVE/librga/releases/tag/1.10.1%2Bceralive.1),
commit `f4c3ee62ab354c2cbe22718f543fc0ba6e58365c`, published by
[run 34735552582](https://github.com/CERALIVE/librga/actions/runs/34735552582).
Its downloaded runtime package's published checksum was verified:
`7c59bade43e2f8bb4c31e0ae965bee480128aa128528fdc88e8bc082e98ec498`.

| Property | Published R0 / matched R1 packaging | Original R1 comparator |
|---|---|---|
| Compiler and C++ headers | Debian GCC/libstdc++ 14.2.0-19 | cross GCC/libstdc++ 16.1.0 |
| Target | aarch64, Debian Trixie | aarch64 cross build on the development host |
| Meson | 1.7.0, `--buildtype=release` | 1.12.0, debug/default build |
| Effective optimization | `-O2`: Debian CXXFLAGS follow Meson's `-O3` | `-O0` |
| Language/platform | C++14, `LINUX=1`, shared PIC, pthread | same |
| Hardening | stack protector, stack-clash protection, BTI/PAC, FORTIFY 3, full RELRO/bind-now | no Debian packaging hardening flag set |
| Build metadata | source/build prefix maps; packaged-input SOURCE_DATE_EPOCH | ordinary debug paths; no packaging epoch normalization |
| ELF used | stripped staged runtime; `.note` retained | unstripped build-tree ELF with DWARF |
| Visibility/LTO/GC | no visibility restriction, version script, LTO or section-GC change | none introduced here either |

`packaging/build-deb.sh` and `ci/target-suite.env` are byte-identical between the
R0 release and pre-merge R1. No packaging option was edited for this reconciliation.
The matched local builds used arm64 container image
`ad30acd806a1415904846a69cc4426c67386c2af21aef2f698bc2328cdbdf2da`:
this is the locally cached `gstrk-trixie-arm64` image, **not claimed to be the
original release container digest**. Measured tools/packages are GCC and
libstdc++ 14.2.0-19, binutils 2.44-3, libc6 2.41-12+deb13u3, Meson 1.7.0 and
Ninja 1.12.1. Package builds use the unmodified packaging script. The actual
recorded library compile command ends with Debian's `-g -O2` and hardening flags
after Meson's `-O3`; calling it an `-O3` comparison would be incorrect.

As a control on that local environment, R0 was rebuilt from its exact published
tag using the same container and packaging script. Its complete sorted dynamic
export set is **identical to the published R0 ELF**, including weak symbols.
The rebuilt archive hash differs (`a1774e08cefa7a77847f9bcc9e5d7fcbf9f45c4b88801f07bd59748383a076b2`);
this is an export-method control, **not** a byte-reproducible release claim.
Published R0 remains the authority used by the corrected containment/abidiff.

#### Corrected release-configuration results

```text
published R0 -> fixed R1 packaging ELF:
missing dynamic exports: 18
missing minus documented upstream delta: 0
documented upstream delta minus missing: 0
abidiff 2.6.0:
Function symbols changes summary: 16 Removed, 56 Added function symbols not referenced by debug info
Variable symbols changes summary: 2 Removed, 3 Added variable symbols not referenced by debug info
PUBLISHED_R0_ABIDIFF_EXIT=12

pre-Wave-E R1 (1bde9018) -> fixed R1, both packaging configuration:
missing dynamic exports: 0
abidiff 2.6.0 (unstripped counterparts for DWARF):
Functions changes summary: 0 Removed, 0 Changed, 1 Added function
Variables changes summary: 0 Removed, 0 Changed, 0 Added variable
Function symbols changes summary: 0 Removed, 0 Added function symbol not referenced by debug info
Variable symbols changes summary: 0 Removed, 2 Added variable symbols not referenced by debug info
PRE_WAVE_E_ABIDIFF_EXIT=4
```

The pre-Wave-E control was built from exactly `1bde9018` with the same packaging
script/toolchain. The additions are the singleton lock accessor and its static
storage/guard. No suppression, weakened symbol filter, or
`--no-unreferenced-symbols` was used. The 18-name allowlist and its 2+4+2+10
accounting remain unchanged because the corrected measurement agrees exactly.
R0 has no DWARF, so public-struct equivalence across R0/R1 is not inferred from
these symbol-only observations. Release authorization remains an owner decision.

Evidence is under `test-results/abi-reconcile/`: `r0.nm`, `r0-rebuilt.nm`,
`missing21.txt`, `documented18.txt`, the four `r1-*.nm` matrix files,
`r1-release14-missing.txt`, `wave-e-release14-removals.txt`,
`release14-environment-dynsym.log`, `shipping-abidiff.log`, each build's log and
its `compile_commands.json`. `r1-base-source/` and `r0-source/` are isolated
repo-local checkouts for the two controls, not build-time repository dependencies.

#### Conflict resolution

Merge parents: R1 `0a6a9bb76267a0157c7e7541decafdde60322a0a` and main
`dbc388f98e8145ad4a8e3efd84924c0b115c9ea7`. The only conflicted file was
`.github/workflows/build-check.yml`. Main added job-level documentation gating
and the terminal summary around the old sanitizer placeholder; R1 had replaced
that placeholder with the real target-suite arm64 sanitizer job and its summary.

The merge keeps R1's real `ci/sanitizers-steps.sh` execution, arm64 runner,
target-suite container and honest host-only summary, while adding main's
`changes` dependency/condition alongside `resolve-suite`. Main's terminal
`build-check-summary` stays and watches every failure-bearing prerequisite.
It rejects failures/cancellations, and permits skipped jobs only when change
detection explicitly returned `code=false`; this avoids a silently skipped code
lane passing green. The advisory analyzer remains advisory.

`tests/test-build-check-gating.sh` checks the actual merged workflow and executes
its summary shell block across seven success/skip/failure/cancellation cases.
`ci/build-check-steps.sh` runs that contract before its static package contract.
No library, public-header, reproducer, unit-test, golden or Meson-registration
hunk changes relative to the four-fix head. No rebase or squash is used.
The ledger was not conflicted; this new evidence fragment is assembled by
`scripts/wire-bootstrap.sh`, never by editing the generated ledger.

#### Post-resolution gate

Run after resolving the workflow, with the merge still uncommitted:

```text
actionlint .github/workflows/build-check.yml: exit 0
tests/test-build-check-gating.sh: 7/7 PASS
native Meson baseline: 24/24 OK
static package contract: OK
rebuilt ASan/UBSan/LSan Meson baseline: 19/19 OK
rebuilt TSan concurrency suite: 4/4 OK
aarch64 UAPI under QEMU: 2/2 OK
shipping-configuration static + staged package contract (arm64 Trixie): OK
shipping ELF ABI floors (GLIBC/GLIBCXX/CXXABI): OK
```

No existing test was skipped or weakened. The two sanitizer trees were rebuilt
with `scripts/build-sanitized.sh`; `run-candidate-a.sh` and
`run-candidate-d.sh` also returned 0, checking their preloaded sanitizer canaries.
The ASan canary transcript contains both its heap-buffer-overflow and the intended
UBSan signed-overflow report. New raw runs: `test-results/candidate-a/run.2z9NlO`
and `test-results/candidate-d/run.L4Qwgi`. Testlogs are in `build-qa/`, `build-asan/`
and `build-tsan/` under `meson-logs/`; the cross testlog is under
`test-results/abi-reconcile/gate-cross/meson-logs/`. The cross run restores the
canonical aarch64 `docs/UAPI-PARITY.md` after the native smoke test.

Changed shell files have clean error-level LSP diagnostics. YAML LSP is not
installed and installation was previously declined; `actionlint` validates the
workflow instead. This is host/shim/emulation evidence, not a board acceptance run.

An extra host-side staged-check attempt produced a false stack-protector failure:
the ELF does import `__stack_chk_fail@GLIBC_2.17`, but the check's
`nm ... | grep -q` pipeline returned `PIPESTATUS=141 0` under host binutils 2.47.
The consumer matched then closed the pipe; the producer received SIGPIPE under
`pipefail`. Running the unchanged staged contract in its intended arm64 Trixie
environment passed, as did the independent ABI-floor check. This is a host-checker
portability finding, not lost hardening, and no assertion was bypassed or edited.
The staged checker uses its existing 18-name allowance; the independent unfiltered
containment/abidiff above, not that allowance, establishes the inherited result.

After recording these results, regenerate the ledger twice and compare ledger
and Meson hashes. The final hash is recorded in PR #7, not self-referentially
inside this generated ledger. Keep the PR draft and unmerged for owner-dispatched
independent review; this follow-up resolves the residual classification and
content conflict without granting a strict-superset exception or release approval.

## Appendix — wave-e-b.md

Source: [fix-audit.d/wave-e-b.md](fix-audit.d/wave-e-b.md). D21 rows are in the [ledger above](#rows).


### Wave-E B — final release and exit-time lookup

Mechanism: final close marks the context closing under the publication mutex,
rejects new operations and waits for all existing operation guards before closing
the fd and freeing the context; singleton lookup uses a lock with the same process
lifetime as the already never-deleted singleton.

`core/NormalRga.cpp`: `RgaContextUse` guards legacy blit, fill, palette and flush
operations; `NormalRgaClose` validates/decrements under `mMutex` and waits on
`context_idle` only for the last reference. `NormalRgaOpen` waits for that close
to complete. Debug-level context access is under the same mutex. Ordinary release
from two owned references to one still returns without closing or draining.

`include/RgaSingleton.h`: `instanceLock()` constructs its mutex once, with C++14
thread-safe local-static initialization, and never destroys it. The singleton
already has that lifetime upstream. The previous `sLock` definition is retained
for ABI compatibility but lookup no longer uses it. This is deterministic lifetime
matching, not an atexit registration-order trick, and does not introduce a
singleton destructor that could race active callers. Explicit deletion/dlclose
with active callers and Android's separate singleton implementation are not proven.

The inherited B implementation is retained. Broken duplicated text in its pending
documentation/generator edits was removed; no library cleanup was added. Its H2
runner change separates stdout/stderr so buffered library stdout cannot split an
action/completion marker. Both streams are scanned for sanitizer diagnostics;
the required markers, 33 successful ioctls, timeout, exit checks and controls stay.

Command on each tree after building both sanitizer trees:

```sh
bash tests/repro/run-candidate-b.sh
```

Fresh RED on `1bde9018d28092879978419f8e48f2b88debcbaa`:

```text
Candidate B evidence: test-results/candidate-b/run.hArjys
ASan/UBSan summary (scenario,iterations,clean,sanitizer,other_failure,invalid):
deinit,200,35,165,0,0
exit,200,200,0,0,0
H2 driver exit=1
H2 refcount: before=2 after=1 deinit=0 fd_open=1 blit=0
TSan summary (same columns):
deinit,200,0,200,0,0
exit,200,0,200,0,0
H2 driver exit=1
H2 refcount: before=2 after=1 deinit=0 fd_open=1 blit=0
```

The wrapper returned 1. Raw batch evidence: `test-results/h2/asan/run.UVRQED`
and `test-results/h2/tsan/run.D9CjdS` in the pre-fix checkout. TSan exit reports
use of an invalid/destroyed mutex, not a singleton-object use-after-free. Both
owned-reference controls returned 0; they do not authorize a serial-refcount fix.

Fresh GREEN with B applied:

```text
Candidate B evidence: test-results/candidate-b/run.4Zx5sj
ASan/UBSan summary (scenario,iterations,clean,sanitizer,other_failure,invalid):
deinit,200,200,0,0,0
exit,200,200,0,0,0
H2 driver exit=0
H2 refcount: before=2 after=1 deinit=0 fd_open=1 blit=0
TSan summary (same columns):
deinit,200,200,0,0,0
exit,200,200,0,0,0
H2 driver exit=0
H2 refcount: before=2 after=1 deinit=0 fd_open=1 blit=0
```

The wrapper returned 0. Raw batches: `test-results/h2/asan/run.zf3XQY` and
`test-results/h2/tsan/run.fDpqql`. Both runtimes' deliberately failing canaries
were checked by the runner. ASan exit was clean before as well as after: only
TSan establishes that exit defect. No invalid run is counted as GREEN.

Disposition: all three H2 scenarios are now green Meson `concurrency` tests.
The 200-process batches and their canaries remain explicit host-only QA, not an
expected-RED exception. The original probe source and owned-reference assertions
are unchanged. Historical H2/candidate-B fragments retain their original results.

## Appendix — wave-e-c.md

Source: [fix-audit.d/wave-e-c.md](fix-audit.d/wave-e-c.md). D21 rows are in the [ledger above](#rows).


### Wave-E C — scheduler-default acceptance

Mechanism: the zero-valued documented default now bypasses the nonzero core-mask
test, preserving acceptance of every previously accepted value.

`im2d_api/src/im2d.cpp`, `imconfig(IM_CONFIG_SCHEDULER_CORE, value)`.
No API, default, layout, visibility or SONAME change.

Exact invocation before and after: `bash tests/repro/run-candidate-c.sh`.
Native x86_64, GCC 16.2.1; ordinary shared library and fake-device preload.

RED on `1bde9018` (`test-results/candidate-c/run.pZB6ua/transcript.txt`):

```text
FAIL default accepted on fresh thread: expected 1, got -4
FAIL reset explicit core to default: expected 1, got -4
candidate-c: 5 assertions, 2 failures
Candidate C: exit=1; evidence=test-results/candidate-c/run.pZB6ua
```

GREEN (`test-results/candidate-c/run.oT8Bu5/transcript.txt`):

```text
== Candidate C: scheduler default is legitimate input ==
0 1831754 1831754 E im2d_rga: IM2D: It's not legal rga_core[0x10], it needs to be a 'IM_SCHEDULER_CORE'.
-- Candidate C: scheduler default is legitimate input: 5 assertions --
candidate-c: 5 assertions, 0 failures
Candidate C: exit=0; evidence=test-results/candidate-c/run.oT8Bu5
```

Disposition: promoted unchanged into the green Meson baseline as `candidate-c`,
linked against the ordinary shared library (not the golden-test static library).
Historical characterization fragments remain verbatim.

## Appendix — wave-e-d.md

Source: [fix-audit.d/wave-e-d.md](fix-audit.d/wave-e-d.md). D21 rows are in the [ledger above](#rows).


### Wave-E D — wait-error fence ownership

Mechanism: `imsync` closes the accepted positive fence after a failed wait,
just as it already does after a successful wait. The `fence_fd <= 0` rejection,
return-status polarity, successful path and submit paths are unchanged.
Fix: `im2d_api/src/im2d.cpp`, `imsync` error branch.

Exact invocation before and after: `bash tests/repro/run-candidate-d.sh`, after
building `build-asan` with `scripts/build-sanitized.sh asan` (incrementally rebuilt
with `meson compile -C build-asan` after the change).

RED on `1bde9018d28092879978419f8e48f2b88debcbaa`:

```text
C4: RED (200/200 defect observations)
Candidate D: exit=1; evidence=test-results/candidate-d/run.lBWs5e
```

GREEN:

```text
C4: NOT-REPRODUCED (0/200 defect observations)
Candidate D: exit=0; evidence=test-results/candidate-d/run.jxTWU5
```

The existing probe calls a clean run `NOT-REPRODUCED`; here it is a measured
RED-to-GREEN transition, not an already-green candidate. Both runs verified the
ASan canary and exactly 200 injected `poll` failures (`errno=5`); each also
completed 200 successful-wait controls. Per-call census and status transcripts
remain under those evidence directories. No sanitizer reports in the fixed probe.

Disposition: the unchanged `h6_polarity_fence.cpp sync-only` probe is promoted to
the green Meson baseline as `candidate-d`. Full H6 remains an opt-in
characterization because C2/C3 are separate, unfixed findings.

## Appendix — wave-e-review-receipt.md

Source: [fix-audit.d/wave-e-review-receipt.md](fix-audit.d/wave-e-review-receipt.md). D21 rows are in the [ledger above](#rows).


### Wave-E independent-review receipt — 2026-09-13

**Verdict: APPROVE. Approval covers the Wave-E repairs only — it is NOT approval
to release R1.** Independent reviewer: `openai/gpt-6-astra`, not the implementing
agent. Reviewer dispatch session id: `ses_f62dc01d3ffeHjGpEFKZ4zGBu0`, supplied
by the orchestrator rather than inferred from the reviewer's environment.

Reviewed head: `7b832a02ec8beb6b473bf58a0401b23b5f7687f9`,
[PR #7](https://github.com/CERALIVE/librga/pull/7), against pre-fix R1
`1bde9018d28092879978419f8e48f2b88debcbaa`. The four rows above associate that
review with each repair's actual commit. They supersede the pending-review status
in the earlier Wave-E fragments for this reviewed head; historical observations
and source fragments remain unchanged.

This receipt transcribes the independent review's `REPORT.md`; its preserved
`head.tar.gz`, `base.tar.gz` and `r0.tar.gz` contain source, builds, ELFs and logs.
Evidence names below refer to `test-results/review-pr7/` in that archived head,
not to a new ABI experiment or a new 800-process run performed to record this
receipt. The report and archives remain in the orchestrator's evidence custody;
no build or test depends on their location.

#### Independently reproduced ABI control and residual classification

The reviewer rebuilt R0 from release tag `1.10.1+ceralive.1`, resolving to
`f4c3ee62ab354c2cbe22718f543fc0ba6e58365c`, with the **unmodified**
`packaging/build-deb.sh`. The packaging script and `ci/target-suite.env` are
byte-identical between that tag and the reviewed head. The independently cached
arm64 Debian Trixie container used GCC/libstdc++ **14.2.0-19**, binutils
**2.44-3**, libc6 **2.41-12+deb13u3**, Meson **1.7.0** and Ninja **1.12.1**.
Effective optimization was **O2**: Debian's `-g -O2` followed Meson's `-O3`.

```text
Published R0: 274 dynamic exports
Rebuilt R0:  274 dynamic exports
diff -u published-r0.nm rebuilt-r0.nm: empty, exit 0
```

The published package's verified SHA-256 was
`7c59bade43e2f8bb4c31e0ae965bee480128aa128528fdc88e8bc082e98ec498`.
Both control ELFs were stripped; their build IDs differed. This validates the
**comparison method**, including weak exports, explicitly **not byte-identical
package reproducibility**. Published R0 remains the release-comparison authority.

All three residual symbols from the earlier unlike-toolchain comparison are
**(c) measurement artifact**, not librga declarations or additional upstream
removals. The reviewer independently reproduced the GCC14/GCC16.1 x O0/O2
emission matrix and resolved each definition with `addr2line` into GCC 14's own
standard-library headers:

| Residual (demangled shorthand) | `addr2line` definition | Dynamic-symbol attributes |
|---|---|---|
| `std::ctype<char>::do_widen(char) const` | `/usr/include/c++/14/bits/locale_facets.h:1092` | `FUNC WEAK DEFAULT` |
| Named `std::_Hashtable<...>::clear()` specialization | `/usr/include/c++/14/bits/hashtable.h:2584` | `FUNC WEAK DEFAULT` |
| `std::__cxx11::basic_string<char,...>::_M_replace_cold(...)` | `/usr/include/c++/14/bits/basic_string.tcc:479` | `FUNC WEAK DEFAULT` |

All three are present in the matched shipping-configuration R1 ELF. No symbol
was suppressed; `nm` and defined GLOBAL/WEAK/UNIQUE `readelf` export sets agree,
as do stripped and unstripped head sets. No visibility, LTO, section-GC or
version-script change was used. The full mangled set and configuration matrix
remain in [wave-e-abi-reconciliation.md](wave-e-abi-reconciliation.md).

Matched pre-fix R1 versus reviewed head: **312 -> 315 exports, 0 removals,
3 additions** — `Singleton<RockchipRga>::instanceLock()`, its local pointer
storage and guard variable. Unfiltered `abidiff` 2.6.0 on the matched unstripped
DWARF ELFs exited **4**, additions only: 0 removed/0 changed functions, 1 added
function and 2 added variable symbols not referenced by debug info. SONAME
**`librga.so.2`** was retained on all six built ELFs.

**Strict R0 superset containment STILL FAILS on the 18 documented inherited
upstream removals (`abidiff` exit 12). This is not a Wave-E regression. It is
not waived, not relabelled, and remains an open R1 release blocker. This receipt
records that blocker; it does not resolve it.** The missing set exactly matches
`packaging/baseline-symbols-upstream-delta.txt`. Published stripped R0 versus
stripped head reports 16 removed/56 added function symbols and 2 removed/3 added
variable symbols. R0 has no DWARF; symbol-only comparison does not prove R0/R1
public-struct equivalence. Evidence: `abi-results.log`, `abidiff.log`, the `.nm`
sets and recorded compile/link commands.

#### Four independently rerun RED-to-GREEN reproducers

The reviewer built both sanitizer trees and ran
`tests/repro/run-candidate-{a,b,c,d}.sh` on both pre-fix R1 and reviewed head.
Native compiler: GCC **16.2.1 20260810**, Meson **1.12.0**, Ninja **1.13.2**;
library sanitizer builds were debug/O0, unstripped, with the documented native
`-fpermissive`. Runtime canaries reported under the selected shim configurations.

| Case | Independently reproduced RED on pre-fix R1 | Independently reproduced result on reviewed head |
|---|---|---|
| C, default scheduler | exit 1; 5 assertions, 2 failures | exit 0; 5 assertions, 0 failures |
| D, failed wait | exit 1; 200/200 retain fence | exit 0; 0/200 retain fence; all 200 success controls still consume fds |
| A, direct init | 20/20 exit 66 with TSan reports | 20/20 exit 0 without reports |
| A, C-init/singleton controls | 20/20 each clean | 20/20 each clean |
| A, hwversion/RgaInit | 1000 failures, fds 0 -> 1000 | 1000 failures, fds 0 -> 0 |
| A, hwversion/improcess | 1000 failures, fds 0 -> 1000 | 1000 failures, fds 0 -> 0 |
| A, successful controls | flat at 0 / warmed 1 | flat at 0 / warmed 1 |
| B, ASan/UBSan deinit | 158/200 findings, 42 clean | 200/200 clean |
| B, ASan/UBSan exit | 200/200 clean | 200/200 clean |
| B, TSan deinit | 200/200 findings | 200/200 clean |
| B, TSan exit | 200/200 findings | 200/200 clean |

The original implementation-run B counts in `wave-e-b.md` describe a different
run; the table above records the reviewer's fresh run. ASan exit was already
clean before the fix; TSan establishes that exit defect. Both owned-reference
controls passed on both revisions, retaining `before=2 after=1 deinit=0
fd_open=1 blit=0`. The race releases a borrowed last reference, not one of two
independently owned references; this is not approval to redefine ordinary
owned-reference release.

**Invalid attempts are retained as failures to complete, not passing evidence.**
The first fixed candidate-B attempt exceeded its outer 120-second tool budget
after the ASan rows. A second hit host **ENOSPC** during TSan exit logging:
`candidate-b-complete.log` records deinit 200 clean, exit 111 clean/89 invalid.
Neither attempt was counted as passing. One invalid-run log was deleted to
recover tool execution and remaining review-owned shim logs were compressed.
Only the complete final batch in `candidate-b-final.log` passed **all 800
scenario processes plus both owned-reference controls**. No timeout, invalid
process, missing log or sanitizer report was scored PASS. The review also
excluded an initial ABI comparison refused for a locale mismatch; final set
comparisons used `LC_ALL=C` consistently.

#### Independently reproduced host gate and scope

| Gate | Reviewer's actual result |
|---|---|
| Native | **24/24 OK**, 0 failed |
| Expanded ASan/UBSan/LSan | **19/19 OK**, 0 failed |
| TSan concurrency | **4/4 OK**, 0 failed |
| aarch64 UAPI under QEMU | **2/2 OK**, 0 failed |
| Static package contract | **PASS** |

These are completed OK results, not skips, ignored failures or expected failures.
Evidence: `gate-native.log`, `gate-asan.log`, `gate-tsan.log`, `gate-cross.log`
and `gate-package.log`. **CI's ASan selector runs the original 11 baseline
cases; the expanded independent review run covered 19. These counts are not
interchangeable.** Native retains all 85 unit-session assertions; no existing
test was deleted, skipped or weakened to reach green.

The reviewer confirmed the preserved eight Wave-D and four candidate merge
graphs and four distinct repair commits, with no rebase or squash. The review
does not satisfy board acceptance, close plan item 43's hardware prerequisite,
erase the recorded items 44/45 ordering finding, authorize a self-merge, or
approve R1 release. PR #7 was **OPEN, draft, unmerged** at review completion;
recording this receipt does not change that disposition. Any eventual merge
belongs to the owner and must preserve the fix-series history, never squash it.

## Appendix — wave-e-verification.md

Source: [fix-audit.d/wave-e-verification.md](fix-audit.d/wave-e-verification.md). D21 rows are in the [ledger above](#rows).

### Wave-E takeover verification — 2026-09-13

**Measurement amendment:** the 21-name comparison below used unlike compiler and
optimization configurations. [The matched-build reconciliation](wave-e-abi-reconciliation.md)
resolves its three residuals as weak C++ emission artifacts: shipping R1 is
missing exactly the 18 already documented upstream names, with zero removals
introduced by Wave E. The original transcripts below remain historical evidence,
not the current release-comparison method.

This is fresh execution, not adoption of the killed lane's claims. The inherited
C/D/A commits were pushed to `origin/fixes/wave-e` before any edit. All RED runs
used a separate checkout of exactly
`1bde9018d28092879978419f8e48f2b88debcbaa`. All paths below are local to the tree
named by the corresponding RED or GREEN section; no script needs another checkout.
Historical fragments and their older runs remain evidence of those runs only.

**Release closure is BLOCKED.** All four regressions and the host gate are green,
but the strict export-superset requirement against the published R0 fails. The
same exports are already absent on pre-fix R1. This is not permission to suppress
them, modify visibility, add unrelated compatibility code, or merge the PR.

#### Commands and proof boundary

```sh
bash scripts/build-sanitized.sh asan
bash scripts/build-sanitized.sh tsan
bash tests/repro/run-candidate-c.sh
bash tests/repro/run-candidate-d.sh
bash tests/repro/run-candidate-a.sh
bash tests/repro/run-candidate-b.sh
```

On the RED tree the four runners return 1, so run them independently, not chained
with `&&`. The GREEN runners return 0. Compiler: native x86_64 GCC 16.2.1;
Meson 1.12.0. Sanitizer canaries run with the fake-device preload and must report.
This is host-shim evidence, not silicon, Debian arm64 CI, or release approval.

#### C — default scheduler

Mechanism: explicitly accept the documented zero enum value before testing the
nonzero scheduler mask, preserving every previously accepted value.
Implementation retained from `752f719`: `im2d_api/src/im2d.cpp:869`.

Fresh RED transcript excerpts:

```text
FAIL default accepted on fresh thread: expected 1, got -4
FAIL reset explicit core to default: expected 1, got -4
-- Candidate C: scheduler default is legitimate input: 5 assertions --
candidate-c: 5 assertions, 2 failures
Candidate C: exit=1; evidence=test-results/candidate-c/run.TAC5rk
```

Fresh GREEN:

```text
-- Candidate C: scheduler default is legitimate input: 5 assertions --
candidate-c: 5 assertions, 0 failures
Candidate C: exit=0; evidence=test-results/candidate-c/run.JJCggp
```

**Inherited commit corrected, implementation kept.** The full gate exposed the
old `unit-session` RT-1 assertion still requiring rejection (expected -4, got 1).
Its own comment explicitly reserved flipping to success for this authorized fix.
The C delivery commit therefore includes that exact expectation migration and
its README update; all 85 unit-session assertions and all controls remain.
This correction is kept with C, not hidden in B. `candidate-c` is a green Meson
case linked against the ordinary shared library; neither test is skipped.

#### D — positive-fence ownership on wait error

Mechanism: close the consumed positive fd on the failed wait branch as on the
successful branch; `fence_fd <= 0` rejection and all return statuses stay.
Implementation retained from `9675231`: `im2d_api/src/im2d.cpp:855`.

Fresh RED:

```text
C4: RED (200/200 defect observations)
Candidate D: exit=1; evidence=test-results/candidate-d/run.UdsAq7
```

Fresh GREEN:

```text
C4: NOT-REPRODUCED (0/200 defect observations)
Candidate D: exit=0; evidence=test-results/candidate-d/run.XC2Nj1
```

Both runs include 200 successful-wait controls and the runner verifies exactly
200 injected EIO poll records. No harness polarity or assertion changed. GREEN
means the known leak is no longer reproduced, not that the probe stayed RED and
was marked expected-pass. `candidate-d` (`sync-only`) is a green Meson case;
the other unfixed H6 characterization modes remain opt-in. Inherited commit kept.

#### A — publication and init-failure fd ownership

Mechanism: serialize context discovery, single device open and publication under
the mutex, atomically acquire references, and unwind failed opens in both the
legacy context and the separately owned im2d session.
Implementation retained from `e6d8fcf`: `core/NormalRga.cpp:104` (`NormalRgaOpen`),
`:251` (`RgaInit`), `im2d_api/src/im2d_context.cpp:113` and `:195`.
Atomic builtins preserve the exported refcount integer's type, size and symbol.

Fresh RED:

```text
Candidate A evidence: test-results/candidate-a/run.Km1nUt
hwversion,RgaInit,iterations=1000,failed_calls=1000,start=0,end=1000,growing_rows=1000,verdict=RED
unset,RgaInit,iterations=1000,failed_calls=0,start=0,end=0,growing_rows=0,verdict=NOT-REPRODUCED
hwversion,improcess,iterations=1000,failed_calls=1000,start=0,end=1000,growing_rows=1000,verdict=RED
unset,improcess,iterations=1000,failed_calls=0,start=1,end=1,growing_rows=0,verdict=NOT-REPRODUCED
Candidate A: exit=1; per-process evidence in test-results/candidate-a/run.Km1nUt
```

All 20 `direct-init` rows in `races.csv` are `exit=66,tsan_report=1`;
all 40 C-init/singleton controls are `exit=0,tsan_report=0`.

Fresh GREEN:

```text
Candidate A evidence: test-results/candidate-a/run.HPHsmg
hwversion,RgaInit,iterations=1000,failed_calls=1000,start=0,end=0,growing_rows=0,verdict=NOT-REPRODUCED
unset,RgaInit,iterations=1000,failed_calls=0,start=0,end=0,growing_rows=0,verdict=NOT-REPRODUCED
hwversion,improcess,iterations=1000,failed_calls=1000,start=0,end=0,growing_rows=0,verdict=NOT-REPRODUCED
unset,improcess,iterations=1000,failed_calls=0,start=1,end=1,growing_rows=0,verdict=NOT-REPRODUCED
Candidate A: exit=0; per-process evidence in test-results/candidate-a/run.HPHsmg
```

All 60 race/control rows are `exit=0,tsan_report=0`. Failure injection still makes
all 1000 calls per API fail: GREEN is fd cleanup, not a fault that stopped firing.
Inherited commit kept. Direct-init and both failure censuses are green Meson
cases; long batches remain explicit QA. The earlier lane's two 200-process batches
are preserved in its fragment, not claimed as independently repeated here.

#### B — teardown

The fresh RED/GREEN transcripts, ownership distinction, implementation and baseline
disposition are in [wave-e-b.md](wave-e-b.md). The inherited B lifetime mechanism
was retained after validation. Only unfinished surrounding evidence/build wiring
and corrupted documentation/generator text needed completion.

#### Host gate

```sh
meson test -C build-qa --print-errorlogs
bash packaging/package-contract.sh
ASAN_OPTIONS=detect_leaks=1:verify_asan_link_order=0:abort_on_error=1 \
  UBSAN_OPTIONS=print_stacktrace=1:halt_on_error=1 \
  meson test -C build-asan --print-errorlogs \
  unit-pure unit-session shim-contract goldens \
  candidate-a-fds-RgaInit candidate-a-fds-improcess candidate-c candidate-d \
  candidate-b-deinit candidate-b-exit candidate-b-refcount candidate-a-init
TSAN_OPTIONS=halt_on_error=1:exitcode=66:symbolize=0 \
  meson test -C build-tsan --print-errorlogs --suite concurrency
QEMU_LD_PREFIX=/usr/aarch64-linux-gnu meson setup test-results/wave-e-cross \
  --cross-file tests/uapi-parity/aarch64.cross -Dlibrga_demo=false
QEMU_LD_PREFIX=/usr/aarch64-linux-gnu \
  meson test -C test-results/wave-e-cross --print-errorlogs --suite uapi
```

| Gate | Result |
|---|---|
| Native host | 24/24 OK, no skips: all former 16 baseline cases plus 8 regressions |
| ASan/UBSan/LSan host | 19/19 OK: all former 11 baseline cases plus 8 regressions |
| TSan concurrency | 4/4 OK, including owned-reference control |
| aarch64 UAPI under QEMU | 2/2 OK; 21 ioctls, 29 sizes, 170 offsets |
| Static package contract | OK; no version/SONAME/visibility/packaging edits |

Native, ASan and TSan testlogs are in their build directories' `meson-logs/`;
the cross testlog is under `test-results/wave-e-cross/meson-logs/`. The aarch64
record is restored by the cross test after native smoke. The pre-existing corrupt
`build-parity/` is untouched; the new cross build has its own output directory.
This gate does not claim a built .deb, staged package contract, a Debian arm64
release matrix or a board drill. The out-of-scope `rga_osd_info` exception is unchanged.

#### ABI and export closure — fail closed against R0

Published baseline: GitHub release `1.10.1+ceralive.1`, target commit
`f4c3ee62ab354c2cbe22718f543fc0ba6e58365c`.
Downloaded `librga2-ceralive_1.10.1+ceralive.1_arm64.deb`; its published sidecar
verified SHA-256 `7c59bade43e2f8bb4c31e0ae965bee480128aa128528fdc88e8bc082e98ec498`.
R0 is the actual stripped release ELF, not a locally substituted baseline.

Both pre-fix and fixed R1 ELFs were built with the same aarch64 GCC 16.1.0
cross file and debug configuration. For each ELF:

```sh
nm -D --defined-only --format=posix <library> | cut -d ' ' -f1 | LC_ALL=C sort -u
```

`comm -23` gives **0 removed exports vs pre-fix R1**, but **21 missing vs R0**.
The R0-minus-R1 list is byte-identical before and after Wave E. Eighteen entries
are librga internals already named in `packaging/baseline-symbols-upstream-delta.txt`;
three are compiler-emitted C++ symbols. No entry is ignored by this strict check.

Unfiltered `abidiff` 2.6.0:

```text
R0 -> fixed R1:
Functions changes summary: 0 Removed, 0 Changed, 325 Added functions
Variables changes summary: 0 Removed, 0 Changed, 1 Added variable
Function symbols changes summary: 19 Removed, 16 Added function symbols not referenced by debug info
Variable symbols changes summary: 2 Removed, 2 Added variable symbols not referenced by debug info
R0_ABIDIFF_EXIT=12

pre-fix R1 -> fixed R1:
Functions changes summary: 0 Removed, 0 Changed, 2 Added functions
Variables changes summary: 0 Removed, 0 Changed, 0 Added variable
Function symbols changes summary: 0 Removed, 0 Added function symbol not referenced by debug info
Variable symbols changes summary: 0 Removed, 2 Added variable symbols not referenced by debug info
R1_BASE_ABIDIFF_EXIT=4
```

Exit 4 here is additive change only; exit 12 includes incompatible change. The
added R1 symbols are the new private singleton lock accessor, emitted mutex
constructor and its local-static storage/guard. R0 has no DWARF, so its zero
changed-function count does **not** establish public-struct ABI equivalence.
No suppression or `--no-unreferenced-symbols` option was used. Logs and symbol
lists are `test-results/wave-e-abi-summary.log`, `wave-e-r0-abidiff.log`,
`wave-e-missing-r0.txt`, `wave-e-base-missing-r0.txt` and `wave-e-missing-base.txt`.

The existing package checker permits a recorded upstream delta against Radxa;
that is not the user's stricter published-R0 superset requirement. Wave E causes
no removals, but **R1 release ABI closure is not green**. Restoring those exports
or changing that policy requires a separate owner decision, not an unrelated
fifth fix smuggled into this series.

#### Generated-file provenance

The inherited pending generator contained malformed duplicate awk/shell text,
and its test had a duplicated, unterminated Python assertion. Those edits were
not a legitimate merge repair and were removed. The only intentional generator
change now migrates the stale introduction from upstream characterization to
historical-plus-fix evidence. Its fixture test verifies migration, idempotency,
unchanged fragments, one continuous D21 table and malformed-row rejection.

The inherited hand-edited introduction is not accepted as provenance: the new
generator reconstructs it itself. No rows or appendices are hand-merged.
After all fragments are written, run `bash scripts/wire-bootstrap.sh` twice;
compare complete file contents and record the ledger SHA-256 outside the ledger
(putting its own hash inside it would be self-referential). The PR carries the
hash and equality result. The Meson test registrations are also generated,
not edited in their assembled region. Independent reviewer approval is pending.
