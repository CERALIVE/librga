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
| status=OBSERVATION fix=none; Candidate A; no fix. Base `b886777023e0c503134e340be348d6c1b11c8adc`, unchanged R1 library | `tests/repro/run-candidate-a.sh`, extending H1/H3; **DEMONSTRATED**: 20/20 direct-init TSan reports and duplicate opens; 1000/1000 failed HW-version calls leak one fd each through both real legacy init and im2d. RED transcript below; GREEN not run, no fix | host-shim-only | Not run; no library, public header, default, visibility or SONAME change | reviewer=explore/openai/gpt-5.6-luna-fast verdict=APPROVE ses_f5e6595c5ffemYVq21ljvRHHgy; evidence-only; Historical review: Not dispatched; no reviewer session or fix approval claimed | Not reported; QA evidence only |
| status=OBSERVATION fix=none; Candidate B; no fix. Base `b886777023e0c503134e340be348d6c1b11c8adc`, unchanged R1 library | `tests/repro/run-candidate-b.sh` extends H2; **DEMONSTRATED** last-reference/deinit and exit races under the stated caller pattern. TSan 200/200 each; ASan/UBSan deinit 167/200, exit 0/200. Owned-reference control passes both builds. RED transcript below; no GREEN/fix | host-shim-only | Not run; no library or ABI change | reviewer=explore/openai/gpt-5.6-luna-fast verdict=APPROVE ses_f5e6595c5ffemYVq21ljvRHHgy; evidence-only; Historical review: Not dispatched; no reviewer session or fix approval claimed | Not reported; characterization only |
| status=OBSERVATION fix=none; Candidate C; no fix. Base `b886777023e0c503134e340be348d6c1b11c8adc`, unchanged R1 library | `tests/repro/candidate_c_scheduler.cpp` via `bash tests/repro/run-candidate-c.sh`; **DEMONSTRATED**, exit 1: five assertions, two failures (fresh/default and explicit-core/reset-to-default). Transcript below; no GREEN/fix | host-shim-only | Not run; test/docs only, no ABI or accepted-input changes | reviewer=explore/openai/gpt-5.6-luna-fast verdict=APPROVE ses_f5e6595c5ffemYVq21ljvRHHgy; evidence-only; Historical review: Not dispatched; no reviewer session or fix approval claimed | Not reported; existing validation defect reproduced |
| status=OBSERVATION fix=none; Candidate D; no fix. Base `b886777023e0c503134e340be348d6c1b11c8adc`, unchanged R1 library | H6 `sync-only` via `bash tests/repro/run-candidate-d.sh`; **DEMONSTRATED**, 200/200 failure calls retain the positive fence fd, 200/200 success controls consume it. Exit 1, transcript below; no GREEN/fix | host-shim-only | Not run; no library or ABI change, fence polarity unchanged | reviewer=explore/openai/gpt-5.6-luna-fast verdict=APPROVE ses_f5e6595c5ffemYVq21ljvRHHgy; evidence-only; Historical review: Not dispatched; no reviewer session or fix approval claimed | Not reported; error-branch cleanup evidence only |
| status=GREEN fix=4449f5fa8d901e9d7d08ac078a8479d4619b97b2; `4449f5f` — constrained port of donor `571a880951583a3b2a04e7e1fa900861653befde` | `tests/repro/donor_full_csc.c`: RED on `5dfe897`, legacy mode 0x201 returns -22 before submission; GREEN after port, returns 0 and captures full_csc=1/yuv2rgb=1; 0x200 and separate im2d controls pass on both; `test-results/donors/red.txt` and `csc-green.txt` | host-shim-only; no board or pixel claim | Public headers unchanged; host gates recorded separately; no R1-versus-R0 release ABI closure claimed | author=Sisyphus-Junior/openai/gpt-6-astra reviewer=explore/openai/gpt-5.6-luna-fast verdict=APPROVE ses_f5e8c52d4ffeK5JdTbtezo6MGB; Historical review: PENDING independent review; do not merge this port into integration until an APPROVE receipt is recorded | donor (nyanmisaka); full SHA credited by cherry-pick -x |
| status=OBSERVATION fix=none; Donor `338a5fe165267c4bd0704bac4628e9bb61a7806d`; no new fix | PRESENT in audited main; source/pat/destination CSC at `im2d_api/src/im2d_impl.cpp:2173-2203`; inherited at `57a1067`, not Wave E | Static semantic audit; no board command | Not applicable: no change | reviewer=explore/openai/gpt-5.6-luna-fast verdict=APPROVE ses_f5e8c52d4ffeK5JdTbtezo6MGB; evidence-only; Historical review: Not applicable: no pick | Upstream-inherited, Yu Qiaowei |
| status=SKIPPED fix=none; Donor `1d330cc28551943bed3380261a5a9c6fbd58ff53`; no fix | ABSENT at `core/NormalRga.cpp:717-728` in audited main; SKIPPED for specified driver 1.3.11, outside donor's less-than-1.3.9 condition; reproducer NOT RUN, no justification | No hardware or pixel result claimed | Not applicable: no change | reviewer=explore/openai/gpt-5.6-luna-fast verdict=APPROVE ses_f5e8c52d4ffeK5JdTbtezo6MGB; evidence-only; Historical review: Not applicable: no pick | donor (nyanmisaka), not picked |
| status=OBSERVATION fix=none; Donor `900f9f0dc702d15536064354f6f1fd77da2719af`; no new fix | PRESENT in audited main; `im2d_api/src/im2d_hardware.h:372-385` and `im2d_api/src/im2d_impl.cpp:585-605`; both relaxed height limits inherited at `57a1067`, not Wave E | Static semantic audit; no board command | Not applicable: no change | reviewer=explore/openai/gpt-5.6-luna-fast verdict=APPROVE ses_f5e8c52d4ffeK5JdTbtezo6MGB; evidence-only; Historical review: Not applicable: no pick | Upstream-inherited, Yu Qiaowei |
| status=NOT-REPRODUCED fix=none; `At recording: no fix landed` — H1 is characterisation of the unchanged tree at `96c9a53ba94c487f9fae938c73347f5bc00e624d`. Nothing was cherry-picked and nothing was changed under `core/` or `im2d_api/`. | `tests/repro/h1_init_race.cpp` + `tests/repro/run-h1-host.sh`, scenario `c-init`. RED: **NOT-REPRODUCED**. 200 fresh processes, run twice (400 total), 8 threads released together on a `std::barrier`. Every iteration identical: `ok=8 refcount_after_init=0 fds_after_init=0`, TSan named none of `rgaCtx`/`refCount`/`mMutex`. `c_RkRgaInit()` is `return 0;` at `core/RgaApi.cpp:27` — the C shim was hollowed out and `include/RgaApi.h:41-45` documents it — so this entry point opens no device and increments no counter. Teardown returns `-19` (`-ENODEV`, "Try to exit uninit"), which is the evidence the scenario left no session. GREEN: n/a, no fix. Transcripts: `test-results/h1/c-init.{log,csv}`. | `host-shim-only` (`tests/shim/fake_rga.c`, mock device is a `memfd_create("fake-rga")`; TSan build via `scripts/build-sanitized.sh tsan`). No board contacted. | n/a — no library change, so nothing to close. `librga.so.2.1.0` in `build-tsan/` is the unmodified tree. | reviewer=explore/openai/gpt-5.6-luna-fast verdict=APPROVE ses_f5e6595c5ffemYVq21ljvRHHgy; evidence-only; Historical review: `Pending at recording: no review dispatched` — this row is a host-side observation, not a landed fix. | n/a — nothing to report upstream from a NOT-REPRODUCED control. |
| status=NOT-REPRODUCED fix=none; `At recording: no fix landed` — as above, unchanged tree at `96c9a53ba94c487f9fae938c73347f5bc00e624d`. | Same pair, scenario `singleton-get`. RED: **NOT-REPRODUCED**. 200 fresh processes, run twice (400 total), 8 threads released together on a `std::barrier` into `RockchipRga::get()` → `RkRgaInit()` → `RgaInit()` → `NormalRgaOpen()`. Every iteration identical: `ok=8 ctx_agreed=1 refcount_after_init=1 fds_after_init=1 deinit_calls=1 refcount_after_teardown=0 fds_after_teardown=0`, TSan named none of `rgaCtx`/`refCount`/`mMutex`. The unguarded `if (!rgaCtx)` at `core/NormalRga.cpp:66` is real — only `refCount++` is inside `mMutex` — but on this host it is never reached concurrently, because `Singleton::getInstance()` (`include/RgaSingleton.h:33-40`) holds `sLock` across the whole null-check-and-construct. The eight threads serialise one level above the defect. GREEN: n/a, no fix. Transcripts: `test-results/h1/singleton-get.{log,csv}`. | `host-shim-only`, same build and shim as the row above. No board contacted. | n/a — no library change. | reviewer=explore/openai/gpt-5.6-luna-fast verdict=APPROVE ses_f5e6595c5ffemYVq21ljvRHHgy; evidence-only; Historical review: `Pending at recording: no review dispatched` — host-side observation, not a landed fix. | n/a — the latent unguarded check is recorded here, not reported, because no reproducer turned it RED. |
| status=OBSERVATION fix=none; Untouched source base `57a1067a246c71fa6c9a355d1668884fda155dd5`; no fix in this measurement | `tests/board/h1-board.cpp`, `run-h1-board.sh`: **RED**, direct-init bypassing singleton serialization, 200/200 fresh eight-thread processes. All eight initializations succeeded; 194 processes opened eight RGA fds and retained seven after eight deinitializations, six opened seven and retained six. Refcount was eight after init and zero after teardown. C-stub and singleton controls each had 0/200 findings; all one-thread controls passed. | **Rock 5B+ measured 2026-09-14 UTC**, real `/dev/rga` census; no device mock. Sanitizers **host-shim-only**. OPi not contacted. | n/a — measurement only, no library or ABI change | reviewer=explore/openai/gpt-5.6-luna-fast verdict=APPROVE ses_f5e6595c5ffemYVq21ljvRHHgy; evidence-only; Historical review: Pending at recording: independent board-evidence review pending; not release approval | Characterization only; no upstream submission in this dispatch |
| status=OBSERVATION fix=none; Post-fix `5dfe897d206a52f770137e15553c48f84964cf02`, distinct from the untouched base | Same board runner: direct-init **0/200 findings**; every process had eight successful initializations, one RGA fd, refcount eight, eight deinitializations, then zero fds/refcount. C-stub and singleton each 0/200 findings; all one-thread controls passed. **Repair confirmation**, not retroactive evidence that hardware RED preceded the already-merged fixes. | **Rock 5B+ measured 2026-09-14 UTC**; sanitizers **host-shim-only**. OPi pending separate authorization. | n/a — no library or ABI change | reviewer=explore/openai/gpt-5.6-luna-fast verdict=APPROVE ses_f5e6595c5ffemYVq21ljvRHHgy; evidence-only; Historical review: Pending at recording: independent board-evidence review pending | No new fix or upstream submission |
| status=OBSERVATION fix=none; Untouched source base `57a1067a246c71fa6c9a355d1668884fda155dd5`; OPi measurement | Same real-device runner: direct-init **RED 200/200** fresh eight-thread processes. All eight initializations succeeded. 193 processes opened eight fds/retained seven, six opened seven/retained six, one opened five/retained four. C-stub and singleton controls each 0/200 findings; all one-thread controls clean. | **Orange Pi 5+ measured 2026-09-14 UTC**, real `/dev/rga`, no mock. Sanitizers **host-shim-only**. | n/a — no library or ABI change | reviewer=explore/openai/gpt-5.6-luna-fast verdict=APPROVE ses_f5e6595c5ffemYVq21ljvRHHgy; evidence-only; Historical review: Pending at recording: independent board-evidence review pending | Characterization only; no new fix or upstream submission |
| status=OBSERVATION fix=none; Post-fix `5dfe897d206a52f770137e15553c48f84964cf02`; OPi measurement | Same runner: direct-init **0/200 findings**, one fd after eight successful initializations and zero after teardown. C-stub/singleton each 0/200 findings; all one-thread controls clean. Repair confirmation, not retroactive pre-merge board RED. | **Orange Pi 5+ measured 2026-09-14 UTC**; sanitizers **host-shim-only** | n/a — unchanged library | reviewer=explore/openai/gpt-5.6-luna-fast verdict=APPROVE ses_f5e6595c5ffemYVq21ljvRHHgy; evidence-only; Historical review: Pending at recording: independent board-evidence review pending | No new fix authorized |
| status=OBSERVATION fix=none; H10a observation; **no fix**. Execution base `96c9a53ba94c487f9fae938c73347f5bc00e624d`; library source unchanged from `57a1067a246c71fa6c9a355d1668884fda155dd5`. | `tests/repro/h10_job_handle.cpp count`, via `bash tests/repro/run-h10.sh asan` or `tsan`. **RED: counter drift.** Unknown ID `2147483647`: count/map `0/0 -> -1/0`; 64 subsequent creates yield `63/64`; valid cancellation of all 64 leaves `-1/0`. Both sanitizer builds reproduce it. RED transcripts: `test-results/h10/asan-eS80sZZq/count/transcript.txt`, `test-results/h10/tsan-KHb1J64S/count/transcript.txt` (exit 1 each). `im2d_api/src/im2d_impl.cpp:2445` decrements even when lookup finds no job. No premature creation limit found within this bounded check; all 64 creates succeed and there is no userspace count-limit gate in this source. Re-run 2026-09-06 reproduces the same line in both modes: `test-results/h10/asan-eK4JCCKy/count/`, `test-results/h10/tsan-a3eySo3y/count/`. **GREEN: none; no fix tested.** | `host-shim-only`; native x86_64, GCC 16.2.1, 2026-09-06. No board access. | Not run: QA test/docs only; no library, header, or ABI change. | reviewer=explore/openai/gpt-5.6-luna-fast verdict=APPROVE ses_f5e6595c5ffemYVq21ljvRHHgy; evidence-only; Historical review: Not requested; no independent reviewer session or fix approval claimed. | Not reported upstream; characterization only. CeraLive does not call this job API (task scope). |
| status=OBSERVATION fix=none; H10b observation; **no fix**. Execution base `96c9a53ba94c487f9fae938c73347f5bc00e624d`; library source unchanged from `57a1067a246c71fa6c9a355d1668884fda155dd5`. | `tests/repro/h10_job_handle.cpp race 2000`, run twice per mode by `tests/repro/run-h10.sh`. One real queued copy task; thread A calls `rga_job_config` then `imendJob`, thread B calls `imcancelJob` on the same job. **RED:** ASan reports a 504-byte heap-use-after-free in both runs (exit 1); TSan reports a data race and a heap-use-after-free respectively (exit 66). Transcripts: `test-results/h10/asan-eS80sZZq/race-{1,2}/transcript.txt` and `test-results/h10/tsan-KHb1J64S/race-{1,2}/transcript.txt`. Offline `addr2line` identifies `rga_job_cancel` freeing at `im2d_api/src/im2d_impl.cpp:2442` while the shim reads the config task pointer at `tests/shim/fake_rga.c:77,205`, called from `rga_job_config` at `im2d_impl.cpp:2560` after its mutex unlock. Reports stop runs early, before `imendJob` in the failing iteration; **not 2000 completed iterations**. Both canaries report; serial `control` passes 200 config/end and 200 separate create/cancel lifecycles in both modes. Re-run 2026-09-06 reproduces both: ASan heap-use-after-free (`test-results/h10/asan-eK4JCCKy/race-1/`, exit 1) and TSan heap-use-after-free (`test-results/h10/tsan-a3eySo3y/race-1/`, exit 66). **GREEN: none; no fix tested.** | `host-shim-only`; native x86_64, GCC 16.2.1, 2026-09-06. The unchanged shim captures task bytes synchronously; no claim about actual driver timing or concurrent same-handle API guarantees. | Not run: QA test/docs only; no library, header, or ABI change. | reviewer=explore/openai/gpt-5.6-luna-fast verdict=APPROVE ses_f5e6595c5ffemYVq21ljvRHHgy; evidence-only; Historical review: Not requested; no independent reviewer session or fix approval claimed. | Not reported upstream; same-handle lifetime finding under the host model. CeraLive does not call this job API (task scope). |
| status=OBSERVATION fix=none; H10c observation; **no fix**. Execution base `96c9a53ba94c487f9fae938c73347f5bc00e624d`; library source unchanged from `57a1067a246c71fa6c9a355d1668884fda155dd5`. | `tests/repro/h10_job_handle.cpp release`, via `tests/repro/run-h10.sh` in both modes. **SECOND-RELEASE-FORWARDED**, not ignored: import returns handle 1, both release statuses are `IM_STATUS_SUCCESS` (1), release ioctl counts are `0 -> 1 -> 2`. Transcripts/logs: `test-results/h10/asan-eS80sZZq/release/{transcript.txt,interposed.log}` and `test-results/h10/tsan-KHb1J64S/release/{transcript.txt,interposed.log}`; exit 1 marks the observed forwarding, not a sanitizer failure. `releasebuffer_handle` at `im2d_api/src/im2d.cpp:181-182` forwards to `rga_release_buffer`, then the ioctl at `im2d_impl.cpp:1490`. The mock accepts every release and does not track driver ownership: this proves missing userspace deduplication, **not a kernel double-free or an idempotency contract violation**. Nothing further found within the time budget. Re-run 2026-09-06 reproduces `0->1->2` in both modes, and `grep -c RELEASE_BUFFER` on the shim log counts **2** release entries, not 1: `test-results/h10/asan-eK4JCCKy/release/`, `test-results/h10/tsan-a3eySo3y/release/`. **GREEN: none; no fix tested.** | `host-shim-only`; native x86_64, GCC 16.2.1, 2026-09-06. No board access; mock release behavior only. | Not run: QA test/docs only; no library, header, or ABI change. | reviewer=explore/openai/gpt-5.6-luna-fast verdict=APPROVE ses_f5e6595c5ffemYVq21ljvRHHgy; evidence-only; Historical review: Not requested; no independent reviewer session or fix approval claimed. | Not reported upstream; boundary observation only. The guide describes releasing driver resources, not repeated-release semantics. |
| status=OBSERVATION fix=none; No fix; H2 deinit tested at `96c9a53ba94c487f9fae938c73347f5bc00e624d`; library source unchanged from `57a1067a246c71fa6c9a355d1668884fda155dd5` | `tests/repro/h2_teardown_race.cpp`; `tests/repro/run-h2.sh` invoked separately with `asan 200` and `tsan 200`. 2026-09-06, Linux x86_64, GCC 16.2.1. **RED:** ASan/UBSan 156/200 null-context reports, 44/200 clean; TSan 200/200 data-race reports, 0 clean. No timeouts or invalid cases in either complete batch. Raw results: `test-results/h2/asan/run.YGzimL/` and `test-results/h2/tsan/run.a6eMUN/`. Attached output: `docs/repro/h2-sanitizers.txt`. **GREEN: not run; no library fix.** No heap-use-after-free report observed. | host-shim-only; no physical board access | Not run: test-only change; no ABI closure claimed | reviewer=explore/openai/gpt-5.6-luna-fast verdict=APPROVE ses_f5e6595c5ffemYVq21ljvRHHgy; evidence-only; Historical review: Not dispatched; no reviewer session id or fix approval claimed | Not reported upstream; characterization of the pinned R1 source, not a production fix |
| status=OBSERVATION fix=none; No fix; H2 exit tested at `96c9a53ba94c487f9fae938c73347f5bc00e624d`; library source unchanged from `57a1067a246c71fa6c9a355d1668884fda155dd5` | Same reproducer and driver, `exit(0)` scenario, 200 fresh processes per sanitizer. **ASan/UBSan: 200/200 clean, no finding. TSan: RED, 200/200 reports** involving the singleton's static mutex (invalid mutex, invalid unlock, or destruction/use data race). No timeouts or invalid cases in either complete batch. Same raw result directories and attached output as above. The heap singleton is not automatically deleted; this does not establish a `RockchipRga` destructor/free race. **GREEN: not run; no library fix or two-run GREEN claim.** | host-shim-only; no physical board access | Not run: test-only change; no ABI closure claimed | reviewer=explore/openai/gpt-5.6-luna-fast verdict=APPROVE ses_f5e6595c5ffemYVq21ljvRHHgy; evidence-only; Historical review: Not dispatched; no reviewer session id or fix approval claimed | Not reported upstream; characterization of the pinned R1 source, not a production fix |
| status=OBSERVATION fix=none; H3: no fix applied; tested R1 source `57a1067a246c71fa6c9a355d1668884fda155dd5` through infrastructure base `96c9a53ba94c487f9fae938c73347f5bc00e624d` | `tests/repro/h3_init_fd_leak.cpp`; RED: `test-results/h3/fdcensus.csv`, `hwversion-improcess.txt` and `hwversion-improcess.interposed.log`; GREEN: not run, no fix in todo 23; unset controls: `test-results/h3/control-fdcensus.csv` | host-shim-only | Not run: nm containment vs R0 and abidiff vs previous release; no library source, headers or build flags changed by this reproducer | reviewer=explore/openai/gpt-5.6-luna-fast verdict=APPROVE ses_f5e6595c5ffemYVq21ljvRHHgy; evidence-only; Historical review: Not dispatched; reviewer session id unavailable; this is a pre-fix finding, not a reviewed/landed fix | Unreported; 1.10.6 repeated-open fix is a plan hint only, not verified at a source SHA; no donor attribution or upstream-closure claim |
| status=OBSERVATION fix=none; n/a (measurement only — no fix landed) | `tests/repro/h4_getenv_count.cpp`, `tests/repro/run-h4-host.sh` · counts recorded below, no RED/GREEN pair because nothing was changed | `host-shim-only` (board leg **DEFERRED**, see below) | n/a (measurement only — no exported symbol added, removed or changed) | reviewer=explore/openai/gpt-5.6-luna-fast verdict=APPROVE ses_f5e6595c5ffemYVq21ljvRHHgy; evidence-only; Historical review: Pending at recording: no independent review dispatched for a measurement-only row | not-applicable (upstream behaviour measured as-is, not modified) |
| status=OBSERVATION fix=none; **MEASUREMENT-BELOW-GATE — todo 34, no library source change** | H4 board timing: Rock warmed estimate approximately **0.469%**, warmed envelope **0–1.894%**; OPi post-fix estimates **0.470–0.479%**, warmed-envelope union **0–3.015%**. The cross-board decision is **INCONCLUSIVE**, not fix permission: a 2% crossing remains inconclusive and no subset of repeats was selected. No RED/GREEN pair applies because the measurement gate closed against a code change. | Both boards, 2,000 scored 4K G1 frames per post-fix repeat; real DMA-BUF with forwarding-only timing/getenv instrumentation; sanitizers **host-shim-only**. Direct `RgaInit(void **)` established legacy context after im2d warmup left `rgaCtx` null; the original base calibration SIGSEGVed and the post-fix path returned without a lookup, so its inverted calibration was rejected. | n/a — no source, ABI, export, default, `IM_STATUS`, or message change | reviewer=explore/openai/gpt-5.6-luna-fast verdict=APPROVE ses_f5fbaf881ffeDEJB02Y2vmQo1E; evidence-only; Historical review: **APPROVE** — independent `gpt-5.6-luna` review, session `ses_f5fbaf881ffeDEJB02Y2vmQo1E` | No optimization proposed or reported upstream; a conclusive profile remains separate future work |
| status=OBSERVATION fix=none; Untouched `57a1067a246c71fa6c9a355d1668884fda155dd5`, measurement only | `tests/board/h4-board.c`: **INVALID**, process exit 139 during calibration, after warmups and before scored samples; no 2,000-sample result or percentage. Crash is not promoted to a library RED. | Rock 5B+, 2026-09-14 UTC; real DMA-BUF and forwarding-only instrumentation; sanitizers **host-shim-only**. OPi not contacted. | n/a — unchanged binary/library | reviewer=explore/openai/gpt-5.6-luna-fast verdict=APPROVE ses_f5e6595c5ffemYVq21ljvRHHgy; evidence-only; Historical review: Pending at recording: calibration precondition and independent review unresolved | No fix authorized |
| status=OBSERVATION fix=none; Post-fix `5dfe897d206a52f770137e15553c48f84964cf02`, measurement only | Same binary: **2,000 G1 samples**, userspace median/p95/p99 **28.292/31.792/47.834 µs**. Printed percentage **0.423593%**, printed empirical envelope **0.161764217–1.061936370%**, but its inclusive upper-cost calibration is inconsistent; decision **INCONCLUSIVE**, not accepted below-gate evidence. | Rock 5B+ measured, OPi pending; sanitizers **host-shim-only** | n/a — no ABI change | reviewer=explore/openai/gpt-5.6-luna-fast verdict=APPROVE ses_f5e6595c5ffemYVq21ljvRHHgy; evidence-only; Historical review: Pending at recording: corrected calibration and independent review required before item 44 / todo 34 | No fix authorized |
| status=OBSERVATION fix=none; Radxa package `2.2.0-1` and matched-toolchain R0 rebuild `f4c3ee62ab354c2cbe22718f543fc0ba6e58365c`, separate comparison rows below | 2,000 G1 samples each; raw timings and empirical percentages retained below. These are comparison artifacts, not substitutes for the missing untouched-base row. | Rock 5B+ only; no package installation; sanitizers **host-shim-only** | n/a — not an ABI comparison | reviewer=explore/openai/gpt-5.6-luna-fast verdict=APPROVE ses_f5e6595c5ffemYVq21ljvRHHgy; evidence-only; Historical review: Pending at recording: independent review pending | Measurement only |
| status=OBSERVATION fix=none; Untouched `57a1067a246c71fa6c9a355d1668884fda155dd5`, follow-up measurement | Corrected calibration client: **2,000 G1 samples**, userspace median/p95/p99 **27.418/30.334/36.168 µs**; matched logging-refresh estimate **0.443840543%**, warmed empirical envelope **0–0.968484686%**. Runtime probe establishes the missing legacy-context precondition. | Rock 5B+ only, 2026-09-14 UTC; sanitizers **host-shim-only** | n/a — library binary unchanged | reviewer=explore/openai/gpt-5.6-luna-fast verdict=APPROVE ses_f5e6595c5ffemYVq21ljvRHHgy; evidence-only; Historical review: Pending at recording: independent measurement review pending | Calibration-client defect, not a new library RED |
| status=OBSERVATION fix=none; Post-fix `5dfe897d206a52f770137e15553c48f84964cf02`, follow-up measurement | **Three 2,000-frame repeats**; point estimates **0.468938750–0.472452994%**; union of matched-warm empirical envelopes **0–1.893894432%**, all calibration checks valid. **MEASUREMENT-BELOW-GATE for the warmed steady-state protocol only**; cold-inclusive bound remains INCONCLUSIVE. | Rock 5B+ only; OPi pending; sanitizers **host-shim-only** | n/a — library binary unchanged | reviewer=explore/openai/gpt-5.6-luna-fast verdict=APPROVE ses_f5e6595c5ffemYVq21ljvRHHgy; evidence-only; Historical review: Pending at recording: independent measurement review pending; no optimization licensed | Item 44 / todo 34 input is scoped below; no general cold-path or cross-board verdict |
| status=OBSERVATION fix=none; Untouched `57a1067a246c71fa6c9a355d1668884fda155dd5`; OPi measurement | Existing corrected client, 2,000 G1 frames: userspace median/p95/p99 **26.833/30.332/39.084 µs**; valid matched calibration, estimate **0.494021987%**, warmed envelope **0–1.395794425%**. | Orange Pi 5+, 2026-09-14 UTC; sanitizers **host-shim-only** | n/a — unchanged library and client | reviewer=explore/openai/gpt-5.6-luna-fast verdict=APPROVE ses_f5e6595c5ffemYVq21ljvRHHgy; evidence-only; Historical review: Pending at recording: independent measurement review pending | No new library defect or fix |
| status=OBSERVATION fix=none; Post-fix `5dfe897d206a52f770137e15553c48f84964cf02`; OPi measurement | Three 2,000-frame repeats, valid calibration: estimates **0.469814269–0.479471490%**, warmed envelope union **0–3.014690673%**. **INCONCLUSIVE**: two repeats cross 2%; do not select only the below-gate repeat. | Orange Pi 5+, 2026-09-14 UTC; sanitizers **host-shim-only** | n/a — no library or ABI change | reviewer=explore/openai/gpt-5.6-luna-fast verdict=APPROVE ses_f5e6595c5ffemYVq21ljvRHHgy; evidence-only; Historical review: Pending at recording: independent measurement review pending; todo-34 prerequisite unresolved | No optimization permission |
| status=OBSERVATION fix=none; Radxa `2.2.0-1` and R0 rebuild `f4c3ee62ab354c2cbe22718f543fc0ba6e58365c`; OPi comparisons | Original client, 2,000 frames each: userspace median/p95/p99 **26.834/29.458/37.332** and **28.584/30.917/36.458 µs** respectively. Original proxy-calibration estimates are comparison-only, not matched R1 decision inputs. | Orange Pi 5+; isolated libraries, no installation; sanitizers **host-shim-only** | n/a — no ABI comparison | reviewer=explore/openai/gpt-5.6-luna-fast verdict=APPROVE ses_f5e6595c5ffemYVq21ljvRHHgy; evidence-only; Historical review: Pending at recording: independent measurement review pending | No fix authorized |
| status=OBSERVATION fix=none; H5 (RT-1) `imconfig(IM_CONFIG_SCHEDULER_CORE, IM_SCHEDULER_DEFAULT)` rejected: **RED, no fix landed**. Base `96c9a53ba94c487f9fae938c73347f5bc00e624d` (`integration/1.10.5-ceralive.1`), library source unchanged by this row. Site: `im2d_api/src/im2d.cpp:862-871`; `IM_SCHEDULER_DEFAULT` is `0` (`im2d_api/im2d_type.h:117`) and the setter gates on `value & IM_SCHEDULER_MASK`, so the one documented "let the driver choose" value is the one value it refuses. | `tests/unit/unit_session.cpp` group (f) `check_imconfig_rt1()`. **RED (host, x86_64)**, via `meson setup build-host -Dlibrga_demo=false -Dcpp_args=-fpermissive && meson test -C build-host unit-session --verbose`:<br>`== (f) RT-1 reproducer: imconfig scheduler core ==`<br>`0 536462 536462 E im2d_rga: IM2D: It's not legal rga_core[0x0], it needs to be a 'IM_SCHEDULER_CORE'.`<br>`0 536462 536462 E im2d_rga: IM2D: It's not legal rga_core[0x10], it needs to be a 'IM_SCHEDULER_CORE'.`<br>`0 536462 536462 E im2d_rga: IM2D: It's not legal priority[0x7], it needs to be a 'int', and it should be in the range of 0~6.`<br>`0 536462 536462 E im2d_rga: IM2D: Unsupported config name!`<br>`-- (f) RT-1 reproducer: imconfig scheduler core: 8 assertions --`<br>`unit-session: 85 assertions, 0 failures`<br>**RED (board, aarch64)**, cross-built with `scripts/cross-build-harness.sh`, staged to `/tmp/librga-bench/unit/`, run as `LD_PRELOAD=/tmp/librga-bench/unit/libfake_rga.so ./unit-session`:<br>`rga_api version 1.10.5_[11]`<br>`== (f) RT-1 reproducer: imconfig scheduler core ==`<br>`1 327759 327759 E im2d_rga: IM2D: It's not legal rga_core[0x0], it needs to be a 'IM_SCHEDULER_CORE'.`<br>`1 327759 327759 E im2d_rga: IM2D: It's not legal rga_core[0x10], it needs to be a 'IM_SCHEDULER_CORE'.`<br>`1 327759 327759 E im2d_rga: IM2D: It's not legal priority[0x7], it needs to be a 'int', and it should be in the range of 0~6.`<br>`1 327759 327759 E im2d_rga: IM2D: Unsupported config name!`<br>`-- (f) RT-1 reproducer: imconfig scheduler core: 8 assertions --`<br>`unit-session: 85 assertions, 0 failures`<br>`exit=0`<br>Both legs return `IM_STATUS_ILLEGAL_PARAM` (-4) for value `0`, and `IM_STATUS_SUCCESS` for `IM_SCHEDULER_RGA3_CORE0` / `IM_SCHEDULER_RGA2_CORE1`, so the rejection is specific to the mask gate and not a blanket refusal. **GREEN: none.** The fix is todo 31 (D20); the assertion flips there and nowhere else. | Board drill `h5-rt1-board`, Orange Pi 5+ `192.168.78.151`. Kernel `Linux 7.2.0-ceralive-rk3588 aarch64`, `Debian GNU/Linux 13 (trixie)`, `/dev/rga` present (`crw-rw---- root video 10, 258`). Read-only: one binary plus its preload staged to `/tmp` and removed on exit; no package installed or removed. Board lock and marker taken through `tests/board/lib.sh`. | n/a. No library source changed, so there is no export-set or `abidiff` delta to close. Re-checked at the fix in todo 31. | reviewer=explore/openai/gpt-5.6-luna-fast verdict=APPROVE ses_f5e6595c5ffemYVq21ljvRHHgy; evidence-only; Historical review: No independent review dispatched: this row lands no fix, only the RED characterization the fix will have to flip. | not-applicable for this row: nothing is proposed upstream by a RED transcript. The upstream disposition is decided with the todo-31 fix. |
| status=WITHDRAWN fix=none; H6a · WITHDRAWN · no fix SHA | Positive-success polarity: WITHDRAWN, not tested; no real positive-success submit path exists on the island. | host-shim-only | Not applicable: no library change | reviewer=explore/openai/gpt-5.6-luna-fast verdict=APPROVE ses_f5e6595c5ffemYVq21ljvRHHgy; evidence-only; Historical review: Not dispatched: reproducer-only task, no fix approval claimed | Not applicable: withdrawn hypothesis |
| status=OBSERVATION fix=none; H6b · R1 base `57a1067a246c71fa6c9a355d1668884fda155dd5` · no fix SHA | `tests/repro/h6_polarity_fence.cpp` C2 · RED 200/200, fd 0 remains open after successful legacy async submit; `test-results/h6/iterations.csv` · GREEN not run, no fix | host-shim-only | Not run: no library change | reviewer=explore/openai/gpt-5.6-luna-fast verdict=APPROVE ses_f5e6595c5ffemYVq21ljvRHHgy; evidence-only; Historical review: Not dispatched: reproducer-only task, no fix approval claimed | Not reported; downstream reproduction only |
| status=OBSERVATION fix=none; H6c · R1 base `57a1067a246c71fa6c9a355d1668884fda155dd5` · no fix SHA | `tests/repro/h6_polarity_fence.cpp` C3 · RED 200/200, failed async `improcess` retains stale release fd 10 rather than -1; `test-results/h6/iterations.csv` · GREEN not run, no fix | host-shim-only | Not run: no library change | reviewer=explore/openai/gpt-5.6-luna-fast verdict=APPROVE ses_f5e6595c5ffemYVq21ljvRHHgy; evidence-only; Historical review: Not dispatched: reproducer-only task, no fix approval claimed | Not reported; downstream reproduction only |
| status=OBSERVATION fix=none; H6d · R1 base `57a1067a246c71fa6c9a355d1668884fda155dd5` · no fix SHA | `tests/repro/h6_polarity_fence.cpp` C4 · RED 200/200, `imsync` returns failure without closing fd 10; `test-results/h6/iterations.csv` · GREEN not run, no fix | host-shim-only | Not run: no library change | reviewer=explore/openai/gpt-5.6-luna-fast verdict=APPROVE ses_f5e6595c5ffemYVq21ljvRHHgy; evidence-only; Historical review: Not dispatched: reproducer-only task, no fix approval claimed | Not reported; downstream reproduction only |
| status=OBSERVATION fix=none; Measurement preparation only; source base `57a1067a246c71fa6c9a355d1668884fda155dd5`, post-fix `5dfe897d206a52f770137e15553c48f84964cf02` | `tests/board/h7-board.c` and `run-h7-board.sh`; RED/GREEN not measured | **NOT-RUN: PREP ONLY**, Orange Pi 5+ and Rock 5B+ occupied; sanitizers **host-shim-only** | n/a: no library or public ABI change | reviewer=explore/openai/gpt-5.6-luna-fast verdict=APPROVE ses_f5e6595c5ffemYVq21ljvRHHgy; evidence-only; Historical review: Pending at recording: no independent hardware review; no result claimed | not-applicable: characterization pending, no defect claim |
| status=OBSERVATION fix=none; Radxa `librga2 2.2.0-1`, SHA-256 `0b455344259c37fec821955e2de85bb5f76a34e69682217b514c407d8a35c6c3` | Existing H7 runner: **RED incident, IM_STATUS_FAILURE at eight threads after 4.605350 s**; four/six threads completed their 60 s budgets. **Not a five-second STALL**, and not NO-STALL at eight. Stop-at-first-incident honored; one-worker recovery passed. | Rock 5B+, 2026-09-14 UTC; real RGA/DMA-BUF. Host collector/descriptor-lock interruption noted below. Sanitizers **host-shim-only** | n/a — measurement only, no library or ABI change | reviewer=explore/openai/gpt-5.6-luna-fast verdict=APPROVE ses_f5e6595c5ffemYVq21ljvRHHgy; evidence-only; Historical review: Pending at recording: independent incident review pending; no R1-fix authorization | Surface driver diagnostics; no kernel or library fix made |
| status=OBSERVATION fix=none; R0 `f4c3ee62ab354c2cbe22718f543fc0ba6e58365c`; untouched `57a1067a246c71fa6c9a355d1668884fda155dd5`; post-fix `5dfe897d206a52f770137e15553c48f84964cf02` | **NOT-RUN** for H7: the preceding Radxa incident stopped all later libraries. No base RED and no post-fix confirmation exist for this leg. | Rock rows unmeasured; OPi not contacted. Sanitizers **host-shim-only** | n/a | reviewer=explore/openai/gpt-5.6-luna-fast verdict=APPROVE ses_f5e6595c5ffemYVq21ljvRHHgy; evidence-only; Historical review: Pending at recording: later-library board matrix and independent review pending | Radxa-only RED does not license an R1 fix |
| status=OBSERVATION fix=none; R0 rebuild `f4c3ee62ab354c2cbe22718f543fc0ba6e58365c` | Existing H7 binary: four/six-thread dwell complete; **IM_STATUS_FAILURE at eight after 0.400651 s**; same-library recovery OK. Not a five-second stall. | Rock 5B+, follow-up 2026-09-14 UTC; sanitizers **host-shim-only** | n/a: no library change | reviewer=explore/openai/gpt-5.6-luna-fast verdict=APPROVE ses_f5e6595c5ffemYVq21ljvRHHgy; evidence-only; Historical review: Pending at recording: independent incident review pending | Common four-library status incident; surface to island/driver investigation |
| status=OBSERVATION fix=none; Untouched `57a1067a246c71fa6c9a355d1668884fda155dd5` | Existing H7 binary: four/six-thread dwell complete; **IM_STATUS_FAILURE at eight after 0.500773 s**; same-library recovery OK. This establishes a base status-failure RED, not a progress-stall RED. | Rock 5B+, follow-up 2026-09-14 UTC; sanitizers **host-shim-only** | n/a: no library change | reviewer=explore/openai/gpt-5.6-luna-fast verdict=APPROVE ses_f5e6595c5ffemYVq21ljvRHHgy; evidence-only; Historical review: Pending at recording: independent incident/root-cause review pending | Not Radxa-specific; does not establish a userspace-fix mechanism |
| status=OBSERVATION fix=none; Post-fix `5dfe897d206a52f770137e15553c48f84964cf02` | Existing H7 binary: four/six-thread dwell complete; **IM_STATUS_FAILURE at eight after 0.901518 s**; same-library recovery OK. Not NO-STALL at eight. | Rock 5B+, follow-up 2026-09-14 UTC; sanitizers **host-shim-only** | n/a: no library change | reviewer=explore/openai/gpt-5.6-luna-fast verdict=APPROVE ses_f5e6595c5ffemYVq21ljvRHHgy; evidence-only; Historical review: Pending at recording: independent incident/root-cause review pending | Same incident class survives current fixes; no R1 fix authorized here |
| status=OBSERVATION fix=none; Radxa `2.2.0-1`; R0 rebuild `f4c3ee62ab354c2cbe22718f543fc0ba6e58365c`; untouched `57a1067a246c71fa6c9a355d1668884fda155dd5`; post-fix `5dfe897d206a52f770137e15553c48f84964cf02` | Existing H7 binary, **all four libraries NO-STALL at eight threads**, full 60-second N=4/6/8 dwell plus five-second N=1 controls. No status-failure incident; no stop/recovery branch invoked. Per-library times below. | **Orange Pi 5+, 2026-09-14 UTC**; real RGA/DMA-BUF; sanitizers **host-shim-only** | n/a — no library or ABI change | reviewer=explore/openai/gpt-5.6-luna-fast verdict=APPROVE ses_f5e6595c5ffemYVq21ljvRHHgy; evidence-only; Historical review: Pending at recording: independent hardware/root-cause review pending | Significant board-dependent contrast to Rock; no R1 fix authorized |
| status=OBSERVATION fix=none; Measurement preparation only; base `57a1067a246c71fa6c9a355d1668884fda155dd5`, post-fix `5dfe897d206a52f770137e15553c48f84964cf02` | `tests/board/h8-board.c`, `h8-data.c`, `run-h8-board.sh`; PSNR unmeasured; RED not applicable | **NOT-RUN: PREP ONLY**, Orange Pi 5+ and Rock 5B+ occupied; sanitizers **host-shim-only** | n/a: no library or default changes | reviewer=explore/openai/gpt-5.6-luna-fast verdict=APPROVE ses_f5e6595c5ffemYVq21ljvRHHgy; evidence-only; Historical review: Pending at recording: independent hardware review pending; no measurement claimed | not-applicable: characterization, not a defect claim |
| status=OBSERVATION fix=none; Untouched `57a1067a246c71fa6c9a355d1668884fda155dd5` | Existing H8 binary/runner: **MEASURED**, all 15 scored cells below plus CSC rejection and explicit-709 improvement controls; no fix or default change | Rock 5B+, 2026-09-14 UTC, real DMA-BUF/RGA; sanitizers **host-shim-only**; OPi not contacted | n/a — no ABI change | reviewer=explore/openai/gpt-5.6-luna-fast verdict=APPROVE ses_f5e6595c5ffemYVq21ljvRHHgy; evidence-only; Historical review: Pending at recording: independent board review pending | Characterization only |
| status=OBSERVATION fix=none; Post-fix `5dfe897d206a52f770137e15553c48f84964cf02` | Existing H8 binary/runner: **MEASURED**, all 15 scores identical to the base; both controls satisfied. This is post-fix characterization, not historical RED | Rock 5B+ only; OPi pending; sanitizers **host-shim-only** | n/a — no ABI change | reviewer=explore/openai/gpt-5.6-luna-fast verdict=APPROVE ses_f5e6595c5ffemYVq21ljvRHHgy; evidence-only; Historical review: Pending at recording: independent board review pending | No new defect or fix claimed |
| status=OBSERVATION fix=none; Untouched `57a1067a246c71fa6c9a355d1668884fda155dd5` and post-fix `5dfe897d206a52f770137e15553c48f84964cf02`; separate OPi columns below | Existing H8 binary/runner: **all 15 scored cells per tree MEASURED**, identical scores across both trees and to Rock. Explicit-709 improves by 25.968579 dB; inappropriate YUV→YUV CSC rejected with −4. | **Orange Pi 5+, 2026-09-14 UTC**, real RGA/DMA-BUF; sanitizers **host-shim-only** | n/a — no library, default or ABI change | reviewer=explore/openai/gpt-5.6-luna-fast verdict=APPROVE ses_f5e6595c5ffemYVq21ljvRHHgy; evidence-only; Historical review: Pending at recording: independent hardware review pending | Characterization only; no new fix |
| status=NOT-REPRODUCED fix=none; none — no fix landed | `tests/repro/h9_address.cpp` · **NOT-REPRODUCED** on `96c9a53ba94c487f9fae938c73347f5bc00e624d`: a buffer pinned at `0x7f0000012340` arrived in the request bytes as the full 64-bit value, not truncated · no GREEN, because there is no RED | `host-shim-only` | not applicable — no code change, so no export-set or `abidiff` delta | reviewer=explore/openai/gpt-5.6-luna-fast verdict=APPROVE ses_f5e6595c5ffemYVq21ljvRHHgy; evidence-only; Historical review: not dispatched: a finding row with no fix has nothing to review | not-applicable — nothing reported upstream |
| status=OBSERVATION fix=none; none — no fix landed | `tests/repro/h9_stdout.cpp` · **REPRODUCED**: with fd 1 redirected to a pipe, the library wrote 87 bytes of error text to stdout when `/dev/rga` was unavailable, and 28 bytes of version banner when it was · no GREEN, because no fix was written | `host-shim-only` | not applicable — no code change | reviewer=explore/openai/gpt-5.6-luna-fast verdict=APPROVE ses_f5e6595c5ffemYVq21ljvRHHgy; evidence-only; Historical review: not dispatched: a finding row with no fix has nothing to review | not-applicable — nothing reported upstream |
| status=GREEN fix=e5f3fc0; `e5f3fc0` todo 36 fix | **RED:** `tests/repro/run-h9.sh` on R1 base `f04a90e95c5018b693f267a9dcdd445c20ec6e3a` captures 89 bytes of failed-open diagnostics and 28 bytes of version banner on stdout. **GREEN:** the same reproducer captures **0 bytes** on stdout in both paths; `tests/unit/unit_logging.cpp` verifies empty stdout plus original error/banner substrings and `librga:` context on stderr in no-device and fake-device runs; `tests/unit/unit_macro_logging.c` covers the public C macro diagnostics. | host-shim-only | `abidiff` of matched arm64 Trixie R1-base and `e5f3fc0` `librga.so.2.1.0`: clean exit, no removed or changed exported symbol | author=Sisyphus-Junior/openai/gpt-5.6-terra reviewer=explore/openai/gpt-5.6-luna-fast verdict=APPROVE ses_f5fa60204ffeFk8z6ioIjQOQzY; Historical review: **APPROVE** — independent `gpt-5.6-luna` review, session `ses_f5fa60204ffeFk8z6ioIjQOQzY` | Not reported upstream; review determines a source contribution path |
| status=GREEN fix=864751a; Todo 37 warning gate; base `f04a90e`; no runtime fix. | **RED:** C++ `_GNU_SOURCE` redefinition in owned H4 reproducer under unsuppressed strict compilation. **GREEN:** guarded define; 22 TUs compile with `-Wall -Wextra -Werror`, no suppression flags; C/C++ warning canaries rejected. **Bounded scope:** `im2d_context.cpp` plus CeraLive `.c`/`.cpp` test/reproducer TUs, excluding deliberately broken sanitizer canaries and the generated-header island emitter; board sources are compiled only. Previously fork-modified vendor TUs, including `NormalRga.cpp` and `im2d.cpp`, are **excluded** from this strict gate; see [BUILD-FLAGS.md — scope and inherited-warning justification](https://github.com/CERALIVE/librga/blob/c5f976ca9fe4bb18f4229d5754b8b6f4227b948e/docs/BUILD-FLAGS.md#scoped-warnings-as-errors-todo-37). `test-results/werror/transcript.txt`, `gcc-canary.txt`, `g++-canary.txt`; inherited broad-scope failure in `inherited-red.txt`. | trixie/GCC 14 arm64 under QEMU; compilation only. No board commands. Sanitizers N/A: build gate only. | Public headers/source ABI unchanged; only macro redefinition guard in a test. | author=Sisyphus-Junior/openai/gpt-6-astra reviewer=explore/openai/gpt-5.6-luna-fast verdict=APPROVE ses_f5e86daf3ffeHEV1vUxQoKxGQb; Historical review: REJECT at `c5f976c` — reviewer `ses_f5f39adafffebJRUpIUzALwh32`: ledger scope disclosure only. Disclosure corrected here; BLOCKED pending fresh independent different-model APPROVE receipt before item 46 may merge. The prior review is not approval of this correction. | not-offered — CeraLive CI scope, not an upstream runtime fix. |
| status=OBSERVATION fix=none; Todo 37 OSD layout; **bounded deferred limitation**, no struct fix. | Confirmed offsets island/librga: `last_flags0` 40/44, `last_flags1` 44/40, `cur_flags0` 48/52, `cur_flags1` 52/48. Island `v2026.9.3`, `b9602a0a49432817c0689ce90b83590b7e52d5b4`. **UNREACHABLE in current CeraLive call set**: fixed conversion/blend usage masks, no `IM_OSD`, zero-initialized legacy/im2d structs. Full call-path and positive-control search evidence: `docs/OSD-LAYOUT-LIMITATION.md`. | Static source reachability and UAPI offsets only; no board/sanitizer claim. | D29 preserved: no public member, layout, API, SONAME, visibility or default changed. | reviewer=explore/openai/gpt-5.6-luna-fast verdict=APPROVE ses_f5e86daf3ffeHEV1vUxQoKxGQb; evidence-only; Historical review: BLOCKED pending independent different-model review receipt. | librga-side divergence; deferred to future major ABI break. Owner-authorized third terminal outcome; neither public-layout fix nor island-side attribution was available. |
| status=GREEN fix=fdcf207; Todo 38 / H10a; execution base `f04a90e`; decrement only for a found job. | **RED:** unknown cancellation changes count/map 0/0 to -1/0; 64 creates become 63/64. **GREEN:** 0/0 stays 0/0, creates 64/64, cleanup 0/0, unchanged cancellation status 1. Same `tests/repro/h10_job_handle.cpp count` under both runtimes; transcript directories below. | **host-shim-only**, native x86_64 Debian trixie, GCC 14.2.0, ASan+UBSan and TSan, 2026-09-14. | Matched debug build `abidiff` unchanged (`test-results/item45/abidiff.txt`); no public signature/layout/visibility/SONAME/default/status/message changes. | author=Sisyphus-Junior/openai/gpt-6-astra reviewer=explore/openai/gpt-5.6-luna-fast verdict=APPROVE ses_f5e86daf3ffeHEV1vUxQoKxGQb; Historical review: BLOCKED pending independent different-model review receipt. | not-offered (no source) — offer to JeffyCN. No userspace count limit exists, so no premature-limit fix is claimed. |
| status=GREEN fix=b1ba828; Todo 38 / H10b; execution base `f04a90e`; retain manager lock through CONFIG task copying. | **RED:** ASan and TSan heap-use-after-free in both repeats; CONFIG borrows task memory after unlock and CANCEL frees it. **GREEN:** original `race 2000` completes twice under each runtime with zero failures, count/map 0/0; canaries report and controls pass. Six registered H10 tests pass under each sanitizer; native adjacent suite 28/28. | **host-shim-only**, native x86_64 Debian trixie, GCC 14.2.0, ASan+UBSan and TSan, 2026-09-14. No board commands or H7 claim. | Same matched-build `abidiff`; no public layout/API change. No released-handle state added to the library. | author=Sisyphus-Junior/openai/gpt-6-astra reviewer=explore/openai/gpt-5.6-luna-fast verdict=APPROVE ses_f5e86daf3ffeHEV1vUxQoKxGQb; Historical review: BLOCKED pending independent different-model review receipt. | not-offered (no source) — offer to JeffyCN. Mutex scope favors correctness; CONFIG serializes other job-manager operations until ioctl returns. |
| status=OBSERVATION fix=none; Todo 38 / H10c; **driver-owned, not a librga defect**; no library change. | Original `release` still forwards twice (exit 1) before and after. New opt-in shim model verifies same-buffer import twice returns handle 1, both releases succeed, exhausted refcount fails in the driver model, re-import reuses handle 1 and release succeeds. All 3 imports and 4 releases reach the shim. **PASS before/after**: `test-results/item45/reimport-base.txt` and H10 `reimport` tests under both sanitizers. | **host-shim-only**; one-buffer reference-count/reuse model, not silicon or a full kernel-memory model. | No production tombstone, deduplication, status or API change. Numeric reuse remains valid. | reviewer=explore/openai/gpt-5.6-luna-fast verdict=APPROVE ses_f5e86daf3ffeHEV1vUxQoKxGQb; evidence-only; Historical review: BLOCKED pending independent different-model review receipt. | Driver ownership: island `rga_mm.c:1582-1608,4071-4085` counts imports; `:4124-4148` uses cyclic ID allocation (plan's H-2 disposition). No librga fix offered. |
| status=GREEN fix=d280ee104eacc60a5ba0ab2d4d92f64b7b688360; Wave-E A; first-party initialization fix; commit resolved by `git log --format=%H --grep='fix(init): serialize context publication and unwind failed opens'` | `tests/repro/run-candidate-a.sh`: RED direct-init 20/20 TSan and 1000/1000 leaked fds per API; GREEN same command, then 200 processes per scenario twice; transcripts below; fresh takeover run in `wave-e-verification.md` | host-shim-only | No removal or incompatible change vs pre-fix R1; strict R0 closure BLOCKED by pre-existing removals, see `wave-e-verification.md` | author=Sisyphus-Junior/openai/gpt-6-astra reviewer=explore/openai/gpt-5.6-luna-fast verdict=APPROVE ses_f5e64778cffecjCELmv47BBBtn; Historical review: Independent full-series review pending; not approved for merge | Downstream-only: initialization ownership repair; not yet submitted upstream |
| status=GREEN fix=0a6a9bb76267a0157c7e7541decafdde60322a0a; Wave-E B; first-party teardown fix; commit resolved by `git log --format=%H --grep='fix(lifetime): drain active operations before final context release'` | `tests/repro/run-candidate-b.sh`: fresh RED on `1bde9018`, GREEN with active-operation draining and process-lifetime lookup lock; transcripts below | host-shim-only; no board claim | No removal or incompatible change against pre-fix R1; strict R0 closure BLOCKED by pre-existing removals, see `wave-e-verification.md` | author=Sisyphus-Junior/openai/gpt-6-astra reviewer=explore/openai/gpt-5.6-luna-fast verdict=APPROVE ses_f5e64778cffecjCELmv47BBBtn; Historical review: Independent review pending; no approval or reviewer session id; NOT approved for merge | Downstream-only: borrowed-last-reference and exit-time lock lifetime repair; not submitted upstream |
| status=GREEN fix=63d60a317fe2f121356e18b445d92dc6403d8a42; Wave-E C; first-party scheduler-default fix on `1bde9018d28092879978419f8e48f2b88debcbaa`; commit resolved by `git log --format=%H --grep='fix(imconfig): accept the documented default scheduler'` | `tests/repro/run-candidate-c.sh`: RED 2/5 assertions, GREEN 0/5 failures; transcripts below; fresh takeover and unit-session expectation migration in `wave-e-verification.md` | host-shim-only | No removal or incompatible change vs pre-fix R1; strict R0 closure BLOCKED by pre-existing removals, see `wave-e-verification.md` | author=Sisyphus-Junior/openai/gpt-6-astra reviewer=explore/openai/gpt-5.6-luna-fast verdict=APPROVE ses_f5e64778cffecjCELmv47BBBtn; Historical review: Independent full-series review pending; not approved for merge | Downstream-only: documented enum acceptance; not yet submitted upstream |
| status=GREEN fix=59f3e83521aaddce5a5309ba764ff47b35c042b4; Wave-E D; first-party wait-error ownership fix; commit resolved by `git log --format=%H --grep='fix(imsync): consume the fence after a failed wait'` | `tests/repro/run-candidate-d.sh`: RED 200/200 retained fds, GREEN 0/200; transcripts below; fresh takeover run in `wave-e-verification.md` | host-shim-only | No removal or incompatible change vs pre-fix R1; strict R0 closure BLOCKED by pre-existing removals, see `wave-e-verification.md` | author=Sisyphus-Junior/openai/gpt-6-astra reviewer=explore/openai/gpt-5.6-luna-fast verdict=APPROVE ses_f5e64778cffecjCELmv47BBBtn; Historical review: Independent full-series review pending; not approved for merge | Downstream-only: error-path ownership repair; not yet submitted upstream |
| status=GREEN fix=63d60a317fe2f121356e18b445d92dc6403d8a42; Wave-E C; `63d60a317fe2f121356e18b445d92dc6403d8a42` | `tests/repro/run-candidate-c.sh`: independently rerun RED on `1bde9018`, GREEN on reviewed head `7b832a02`; 2/5 failures -> 0/5 | host-shim-only; hardware gates remain open | Matched pre-fix R1 -> head: 312 -> 315 exports, 0 removals, abidiff 4 additions only; strict R0 superset STILL FAILS on 18 inherited removals, abidiff 12 | author=Sisyphus-Junior/openai/gpt-6-astra reviewer=explore/openai/gpt-5.6-luna-fast verdict=APPROVE ses_f5e64778cffecjCELmv47BBBtn; Historical review: APPROVE — independent reviewer `openai/gpt-6-astra`, dispatch `ses_f62dc01d3ffeHjGpEFKZ4zGBu0`; Wave-E repairs only, NOT R1 release approval | Downstream-only; this receipt makes no upstream submission |
| status=GREEN fix=59f3e83521aaddce5a5309ba764ff47b35c042b4; Wave-E D; `59f3e83521aaddce5a5309ba764ff47b35c042b4` | `tests/repro/run-candidate-d.sh`: independently rerun RED on `1bde9018`, GREEN on reviewed head `7b832a02`; 200/200 retained wait-error fences -> 0/200, success controls intact | host-shim-only; hardware gates remain open | Matched pre-fix R1 -> head: 312 -> 315 exports, 0 removals, abidiff 4 additions only; strict R0 superset STILL FAILS on 18 inherited removals, abidiff 12 | author=Sisyphus-Junior/openai/gpt-6-astra reviewer=explore/openai/gpt-5.6-luna-fast verdict=APPROVE ses_f5e64778cffecjCELmv47BBBtn; Historical review: APPROVE — independent reviewer `openai/gpt-6-astra`, dispatch `ses_f62dc01d3ffeHjGpEFKZ4zGBu0`; Wave-E repairs only, NOT R1 release approval | Downstream-only; this receipt makes no upstream submission |
| status=GREEN fix=d280ee104eacc60a5ba0ab2d4d92f64b7b688360; Wave-E A; `d280ee104eacc60a5ba0ab2d4d92f64b7b688360` | `tests/repro/run-candidate-a.sh`: independently rerun RED on `1bde9018`, GREEN on reviewed head `7b832a02`; 20/20 direct-init TSan reports -> 0/20, both 1000-call fd-growth cases -> flat | host-shim-only; hardware gates remain open | Matched pre-fix R1 -> head: 312 -> 315 exports, 0 removals, abidiff 4 additions only; strict R0 superset STILL FAILS on 18 inherited removals, abidiff 12 | author=Sisyphus-Junior/openai/gpt-6-astra reviewer=explore/openai/gpt-5.6-luna-fast verdict=APPROVE ses_f5e64778cffecjCELmv47BBBtn; Historical review: APPROVE — independent reviewer `openai/gpt-6-astra`, dispatch `ses_f62dc01d3ffeHjGpEFKZ4zGBu0`; Wave-E repairs only, NOT R1 release approval | Downstream-only; this receipt makes no upstream submission |
| status=GREEN fix=0a6a9bb76267a0157c7e7541decafdde60322a0a; Wave-E B; `0a6a9bb76267a0157c7e7541decafdde60322a0a` | `tests/repro/run-candidate-b.sh`: independently rerun RED on `1bde9018`, GREEN on reviewed head `7b832a02`; final batch 800/800 scenario processes plus both owned-reference controls; timeout and ENOSPC attempts excluded, details below | host-shim-only; hardware gates remain open | Matched pre-fix R1 -> head: 312 -> 315 exports, 0 removals, abidiff 4 additions only; strict R0 superset STILL FAILS on 18 inherited removals, abidiff 12 | author=Sisyphus-Junior/openai/gpt-6-astra reviewer=explore/openai/gpt-5.6-luna-fast verdict=APPROVE ses_f5e64778cffecjCELmv47BBBtn; Historical review: APPROVE — independent reviewer `openai/gpt-6-astra`, dispatch `ses_f62dc01d3ffeHjGpEFKZ4zGBu0`; Wave-E repairs only, NOT R1 release approval | Downstream-only; this receipt makes no upstream submission |

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

## Appendix — coordinator-review.md

Source: [fix-audit.d/coordinator-review.md](fix-audit.d/coordinator-review.md). D21 rows are in the [ledger above](#rows).

## R1 coordinator review reconciliation — 2026-09-14

The current receipt precedes `Historical review:` in each D21 review cell.
Historical pending statements and rejections describe their original recording,
not the current authorization. Observation receipts are retrospective **evidence
reviews only**; they do not invent a fix, a historical pre-merge review, or a new
hardware run. `status=GREEN` identifies an implemented repair/build-gate change;
all other row dispositions explicitly carry `fix=none`. Base, donor and tested
artifact SHAs remain visible but are not misclassified as fix commits.

`author` is the implementing/porting execution agent and its stored model ID,
not the human Git author. In particular, nyanmisaka remains the original author
of `4449f5f`, with the donor's full cherry-pick credit intact. Provider-qualified
model IDs below come from session metadata, not shortened self-descriptions.
The checker compares agent names and model IDs independently.

### Approval history retained

| Scope | Original review history | Current strict-independence receipt |
|---|---|---|
| Todo 34 | `ses_f5fbaf881ffeDEJB02Y2vmQo1E`: APPROVE measurement-only disposition | Same `explore/openai/gpt-5.6-luna-fast` receipt; no code or optimization approval |
| Todo 36 | Three REJECT rounds: `ses_f5fbaf881ffeDEJB02Y2vmQo1E` (public C macros still on stdout), `ses_f5fb08d49ffeYAxHFTGiNfaJIH` (remaining context/verification concerns), `ses_f5faa60a1ffeX3TlE1TM0tsAO2` (geometry/log-gating/final-state concerns). Final `ses_f5fa60204ffeFk8z6ioIjQOQzY`: APPROVE. Android logging remains unchanged. | Author `Sisyphus-Junior/openai/gpt-5.6-terra`; reviewer `explore/openai/gpt-5.6-luna-fast`, final session above |
| Todo 37 | `ses_f5f39adafffebJRUpIUzALwh32`: REJECT scope disclosure at `c5f976c`; disclosure corrected by `16b7f02`; `ses_f5f17873effel4eGLcYrSrLpdp`: APPROVE that exact head | Supplemental APPROVE `ses_f5e86daf3ffeHEV1vUxQoKxGQb`, `explore/openai/gpt-5.6-luna-fast`, after the original approval; author/repair lane `Sisyphus-Junior/openai/gpt-6-astra` |
| Todo 38 | `ses_f5f17f6e7ffeDBxkvfDovEpWDs`: REJECT dead concurrency discovery at `b58df2b`; `7f4c69d` repairs it; `ses_f5ec40901ffeqDLYiw4ufn7mF7`: APPROVE `614ab1a`, actual gate reports six concurrency tests | Supplemental APPROVE `ses_f5e86daf3ffeHEV1vUxQoKxGQb`, `explore/openai/gpt-5.6-luna-fast`; author/repair lane `Sisyphus-Junior/openai/gpt-6-astra` |
| Original PR-7 fixes | Original APPROVE `ses_f62dc01d3ffeHjGpEFKZ4zGBu0` and its fresh RED/GREEN, canary and ABI results remain in `wave-e-review-receipt.md` | Supplemental APPROVE for each of `63d60a3`, `59f3e83`, `d280ee1`, `0a6a9bb`: `ses_f5e64778cffecjCELmv47BBBtn`, `explore/openai/gpt-5.6-luna-fast`; original author `Sisyphus-Junior/openai/gpt-6-astra` |
| Donor audit/port | Original pending state retained in `donors.md`; semantic dispositions in `docs/DONORS.md` | APPROVE `e24951a` / port `4449f5f`: `ses_f5e8c52d4ffeK5JdTbtezo6MGB`, `explore/openai/gpt-5.6-luna-fast`; porting lane `Sisyphus-Junior/openai/gpt-6-astra` |
| Historical observations and item-43 board fragments | Original no-review/preparation/invalid-run records retained | Evidence-only APPROVE `ses_f5e6595c5ffemYVq21ljvRHHgy`, `explore/openai/gpt-5.6-luna-fast`, for candidates A–D and H1–H10 no-fix observations |

The original final reviewers for 37/38 and PR 7 were different sessions but
shared the implementing agent/model identity. Their approvals are genuine and
remain visible; the **supplemental** receipts supply the stronger identity
diversity required by this coordinator. No rejected session is relabelled APPROVE.

The supplemental reviews inspected committed source and retained evidence;
they did not independently repeat the full sanitizer/ABI/board campaigns. The
donor reviewer additionally ran the existing head reproducer with the actual
shim, but inspected rather than reran base RED. The board-evidence reviewer
initially rejected an unrequested conclusive H4 gate, then explicitly clarified
APPROVE for the requested **inconclusive measurement-only** merge scope. That
clarification authorizes neither an optimization nor a conclusive timing claim.

### Boundaries that remain

- H4: no optimization. Rock's cold-inclusive bound is unresolved; OPi's warmed
  envelope is 0–3.015%, crossing 2%. The no-code disposition is unchanged.
- H7: Rock eight-thread status failures across four libraries versus clean OPi
  dwell. This is a board-dependent island/driver investigation, not a librga fix.
- OSD: four public member offsets remain divergent on the librga side. The path
  is unreachable in the current CeraLive call set and deferred to a future major;
  zero-initialization is not a layout repair.
- Sanitizers are host-shim-only. Board observations remain their original runs.
- The inherited 18-symbol strict R0 containment blocker is not waived. Opening
  this integration PR is not R1 release or merge authorization.

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

At the original todo-39 recording the port was not independently approved.
The current receipt above records its later independent review and coordinator
integration; [the review reconciliation](coordinator-review.md) preserves that
sequence. No pre-existing Wave-E receipt was reused to approve this new code,
and neither the review nor integration is R1 release authorization.

## Appendix — full709-selector.md

Source: [fix-audit.d/full709-selector.md](fix-audit.d/full709-selector.md). D21 rows are in the [ledger above](#rows).

# Full709 ordinary selector — review pending

The first-party repair of upstream `2aa0ab4d8374d630bed628f8fb6dead9076eae7c`
has a failing-first request regression and an isolated OPi selector-only pixel
experiment. Full evidence and remaining gates: `docs/FULL709-SELECTOR.md`.

It changes only full709's destination `r2y_mode` to zero, retaining source Y2R
and every coefficient. The archived unchanged R1 library recovers exactly
33.977872→50.689414 dB when only its forwarded selector changes 8→0; the fixed
library reproduces both directions with unchanged adjacent colour controls.

**Pending independent different-agent/different-model review:** no current
APPROVE receipt or D21 GREEN disposition is claimed. The reviewer must add the
fix commit and receipt to the six-field table before this fix can merge. The
existing review checker is unchanged. This is not a G-B pass or release approval.

## Appendix — h1.md

Source: [fix-audit.d/h1.md](fix-audit.d/h1.md). D21 rows are in the [ledger above](#rows).


Board-side static-ASan real-hardware leg deferred — boards temporarily unavailable, to be appended by a follow-up task without modifying the host rows above.

## Rock execution — hardware census appended (2026-09-14 UTC)

The two original host rows remain verbatim. The preparation/deferred text below
is historical; this dispatch measures Rock only and creates **no board sanitizer
leg**. Item 43 remains open for OPi and the separately recorded H4 measurement gap.

Primary evidence run `20260914T023538Z-2107123`: per-tree `h1/fdcensus.csv`,
`iterations.txt`, and `control.csv` in the retained execution archive. Each tree
has 600 census records, three scenarios × 200 fresh processes. C-init opens no
fd; singleton-get opens one, holds one reference, and closes it. Neither control
is proof that unsynchronized direct initialization is race-free. A prior
unprivileged run also observed 200/200 base direct-init findings and zero
post-fix findings; its later H4 permission failure is preserved separately.

Both libraries and their separately header-matched clients are aarch64 Debian
GCC/G++ 14.2.0-19, `-O2 -g`, unstripped, without LTO or sanitizers; the libraries
use Meson debugoptimized/C++14/`-fpermissive`, the H1 clients C++17. The staged
payload was verified on the board by SHA-256, not package metadata. Library
digests: base `1d6ca938bf6374074e8415681d133ef21e8fbfd72bbc77a62fddfc2d90773022`;
post-fix `1bc56ff2d89a29cbeef37475a9fb3aad81be006d1ca68048351f83fe940f2a19`.

## Board preparation — no hardware result (2026-09-13)

The host rows above are unchanged. `tests/board/h1-board.cpp` and
`run-h1-board.sh` are separate hardware infrastructure, not edits to the host
reproducer. Both boards remain occupied; **no board command ran**. Hardware
rows will be inserted immediately beside the host rows only after transcripts
exist. Sanitizers remain **host-shim-only**; the historical static-ASan wording
above is not a claim that such a board leg exists.

The runner uses real `/dev/rga` fd targets and rejects `fake_rga_active`. It runs
200 fresh processes for each of `c-init`, `singleton-get`, and `direct-init`,
with eight threads, plus one-thread controls. Direct init deliberately bypasses
the singleton serialization; the C stub and singleton remain distinct controls.
It reports failures/200 and census rows, not a false clean result after failed init.

Measure **both** untouched `57a1067a246c71fa6c9a355d1668884fda155dd5` and
post-fix `5dfe897d206a52f770137e15553c48f84964cf02`. Each H1 executable is compiled
against its matching tree's inline singleton header. Post-fix results characterize
the already-merged fix, not historical RED or retroactive dependency satisfaction.
Artifacts: `test-results/h1/<board>/<lib>/{fdcensus.csv,iterations.txt,control.csv}`.

## OPi execution — hardware census appended (2026-09-14 UTC)

Run `20260914T130553Z-3452424` retains `h1/<tree>/fdcensus.csv`,
`iterations.txt`, and `control.csv`: 600 census records per tree, three scenarios
times 200 fresh processes, plus the three one-thread controls. The original host
and Rock rows above are unchanged. Both boards now demonstrate the direct-init
base RED and current post-fix cleanliness; neither control exercises concurrent
direct initialization, so neither control alone could have established this result.

Artifacts are the same header-matched clients and library hashes described above:
Debian GCC/G++ 14.2.0-19, aarch64, `-O2 -g`, unstripped, no LTO or sanitizer.
No binary was rebuilt. All 28 original payload checksums passed on the OPi.
The board ran `7.2.0-ceralive-rk3588`. This run freshly **OWNED**, not inherited,
both host locks and both remote markers, held by one detached collector from
13:05:54 to release at 13:20:22 UTC. There was no collector timeout or lease gap.
Before/after: B booted, A/B good, budgets 3/3, configuration and CeraUI unchanged.

This completes H1's item-43 board measurements. Historical deferred/preparation
and pending-OPi statements above remain the record of their respective runs,
not the current verdict. It creates **no board sanitizer row**.

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

## Todo 34 disposition — measurement gate closed against a fix (2026-09-14)

The completed two-board H4 timing evidence closes todo 34 without a code change.
Rock's corrected warmed steady-state estimate is approximately **0.469%** with a
**0–1.894%** warmed envelope. Its cold-inclusive result remains
**INCONCLUSIVE**. On the Orange Pi, the three post-fix estimates are
**0.470–0.479%**, but their warmed-envelope union is **0–3.015%**. The latter
crosses the 2% decision gate.

The standing decision rule is applied without selecting a favourable point or
repeat: an envelope that crosses 2% is **INCONCLUSIVE**, never permission to
apply the rate-limit. The sub-2% point estimates therefore do not license todo
34's optimization; this row is labelled **MEASUREMENT-BELOW-GATE** only to record
the observed sub-gate estimates and its no-code disposition.

The initial calibration was invalid. im2d warmup leaves legacy `rgaCtx` null, so
the base's direct debug calibration SIGSEGVed while the post-fix path returned
without performing a lookup. That created the impossible result in which the
claimed inclusive upper cost was below the property-only lower cost. Direct
`RgaInit(void **)` establishes the required context; the corrected samples above
use that precondition. No source file under `core/` or `im2d_api/` changed for
todo 34.

## Board preparation — no measurements yet (2026-09-13)

`tests/board/h4-board.c`, `getenv-meter.c` and `run-h4-board.sh` add a separate
real-DMA-BUF G1 runner, leaving the host reproducer and library unchanged.
Valgrind is still absent on the development host; the documented skip stays.
Both boards are occupied and **no board command ran**. Sanitizers: host-shim-only.

Per board it measures Radxa, an R0 source rebuild, untouched `57a1067`, and
post-fix `5dfe897`, 32 warmups then 2,000 synchronous 3840×2160 NV16→NV12 calls.
The unchanged forwarding timing shim supplies operation total and individual
ioctl durations. The reader advances from the warmup file offset after each
scope, sums its ioctl durations, and never sums duplicated operation totals.
`perf.csv` has the six required columns; `summary.txt` gives median/p95/p99.

Todo 34's percentage is **debug-property reread cost / userspace-side time**,
not ioctl fraction and not frame-wall-time fraction. `counts.csv` measures actual
in-scope debug getenv calls. Thirty-one 100,000-call calibrations measure exported
`get_int_property` (getenv + parsing) net of a no-op call, and inclusive
`is_debug_log` as a conservative upper estimate. No environment value is cached,
changed or suppressed. All getenv calls forward to libc.

Raw denominator is `t_total_us - sum(t_ioctl_us)`. It includes forwarding probe
overhead, so an observed envelope also allows four times the largest calibrated
fd-readlink/two-clock cost plus 1 µs per ioctl, and the inclusive debug-call cost
per measured lookup. This is an **empirical conservative allowance, not a proven
hard bound**. The lower percentage uses the smallest property cost / largest
observed userspace sample; the upper uses the largest inclusive debug cost /
smallest sample minus that allowance. Nonpositive corrected time or an envelope
crossing 2% gives `INCONCLUSIVE-REPEAT-PROFILE`, never a fix or a below-gate row.
An envelope wholly below 2% supplies `MEASUREMENT-BELOW-GATE`; one wholly at or
above supplies the ≥2% decision input. Inspect/repeat noisy or boundary results
before making the todo 34 decision. Post-fix is the operative decision tree;
pre-fix records the ordering inversion rather than undoing it.

## Rock execution — timing measured, decision blocked (2026-09-14 UTC)

The original host row and sections above remain unchanged; their deferred/prep
statements describe the earlier run. Item 43 is **still open**, both for OPi and
for the incomplete/invalid Rock H4 calibration. Do not use the executable's
printed `MEASUREMENT-BELOW-GATE` as the accepted post-fix verdict.

32 warmups precede each measured library's 2,000 synchronous 3840×2160 G1 calls.
Values below are **median / p95 / p99**, in microseconds per frame. Userspace is
computed per sample as operation total minus the sum of that scope's ioctl
durations. Quantiles of the separate columns are not subtracted from one another.

| Library / tree | Samples | Total µs/frame | Summed ioctl µs/frame | Userspace µs/frame |
|---|---:|---|---|---|
| Radxa `2.2.0-1` | 2,000 | 6974.508 / 7058.803 / 7135.221 | 6952.633 / 7033.427 / 7095.553 | 21.875 / 32.376 / 57.460 |
| R0 source rebuild `f4c3ee6` | 2,000 | 6412.453 / 7021.177 / 7111.304 | 6383.577 / 6998.718 / 7085.053 | 28.293 / 31.792 / 53.085 |
| Untouched `57a1067` | 0 scored | INVALID: calibration exit 139 | Warmup rows only | Unmeasured |
| Post-fix `5dfe897` | 2,000 | 6419.453 / 6513.956 / 7041.011 | 6391.160 / 6480.996 / 7019.719 | 28.292 / 31.792 / 47.834 |

Each completed row counted **two debug getenv calls per operation**. These are
userspace-side wall-time remainders, including observer overhead, not CPU time.

| Library | Printed estimate | Printed empirical envelope | Interpretation |
|---|---:|---|---|
| Radxa | 0.474705% | 0.131370460–0.952478594% | Comparison-only below-gate measurement; not R1 authorization |
| R0 rebuild | 0.415166% | 0.145913095–1.012919201% | Comparison-only below-gate measurement; not R1 authorization |
| Untouched `57a1067` | unavailable | unavailable | INVALID: no scored samples |
| Post-fix `5dfe897` | 0.423593% | 0.161764217–1.061936370% | **INCONCLUSIVE: invalid upper-cost calibration**, not an accepted uncertainty bound |

The post-fix summary's `debug_upper_us=0.051045860` is smaller than
`property_lower_us=0.059921510`. An alleged inclusive getenv-plus-parse upper
cost cannot be accepted on this evidence. The calibration calls exported legacy
`is_debug_log()` directly; the base implementation dereferences legacy `rgaCtx`,
while post-fix guards a missing context and can return without the property read.
The base's zero-byte `calibration.csv` after warmup and the post-fix cost inversion
are consistent with a missing legacy-context precondition. No runtime backtrace
was available, so that mechanism remains a hypothesis, not a proven crash cause.
No calibration or tested binary was rebuilt or patched in this execution lane.

**Item 44 / todo 34 input: INCONCLUSIVE.** Repair/validate the calibration and
repeat the missing base timing before deciding. An envelope crossing 2% must
likewise remain INCONCLUSIVE; this run grants no fix permission. Valgrind's
historical host skip is unchanged.

Evidence run `20260914T023538Z-2107123` preserves per-library `h4/` summaries,
`perf.csv`, `counts.csv`, `calibration.csv`, forwarding `timing.csv`, original
`h4.exit=139`, and resumed `h4-post.exit=0`. The first unprivileged attempt failed
DMA-heap access before H4 sampling; sudo was used for the retry without changing
device permissions or installing libraries. The payload SHA-256 remained
`aa07266832b924f1a4443c85ceb437cbb9ecef755fcbc8494fa1a04ef3005201` and its
per-file checksums were verified on the board.

Rebuilt R0/base/post libraries: Debian GCC/G++ 14.2.0-19, aarch64, Meson
debugoptimized `-O2 -g`, C++14, `-fpermissive`, unstripped, no LTO/sanitizer.
H4 client: same compiler, GNU C11, `-O2 -g`, unstripped. Radxa: stripped vendor
binary, compiler/optimization unknown. Cross-library latency differences are
observations of these artifacts, not an unlike-build ABI or optimization claim.

## Rock calibration repair and repeat (2026-09-14 UTC)

The original rows above remain historical, including their rejected percentages.
The missing base measurement is now obtained. The old calibration client is not
safe to reuse unchanged: the execution-only corrected client and its exact build
inputs are retained with follow-up run `h4-20260914T034918Z-3294944`.
No library, forwarding timer, getenv meter, or H1/H7/H8 binary was rebuilt.

### Precondition demonstrated, not inferred

| Tree / probe | Before initialization | Direct `RgaInit(void **)` | After initialization |
|---|---|---|---|
| Untouched base | `rgaCtx=null`; isolated debug call gets SIGSEGV (11) | returns **1**, context non-null | debug call completes with exactly **1** getenv lookup |
| Post-fix | `rgaCtx=null`; debug call completes with **0** lookups | returns **1**, context non-null | debug call completes with exactly **1** lookup |

An im2d warmup also leaves the legacy context null. The C `c_RkRgaInit()` stub
returns 0 without establishing that context; it is not the required precondition.
Direct init/deinit and the driver-version ioctl use **negative=failure**, not
nonzero=failure. These details were checked at runtime, and failed client attempts
remain recorded rather than attributed to the library. The base's original crash
was an invalid direct calibration call; the post-fix short-circuit explains why
its old purported inclusive upper cost was below the property-only cost.

### Matched warmed measurements

Each row has 32 G1 warmups and 2,000 scored synchronous 4K G1 operations, pinned
to CPU 6 without changing clock/governor settings. Values are median / p95 / p99
in µs/frame. Every scored operation has two counted debug-property lookups and
one timed ioctl; userspace is computed per sample, never from separate quantiles.

| Tree / repeat | Samples | Total µs/frame | Summed ioctl µs/frame | Userspace µs/frame |
|---|---:|---|---|---|
| Base | 2,000 | 6399.034 / 6474.285 / 6689.541 | 6371.470 / 6444.827 / 6664.165 | **27.418 / 30.334 / 36.168** |
| Post 1 | 2,000 | 6395.096 / 6483.911 / 6716.376 | 6366.950 / 6453.869 / 6684.292 | **28.001 / 31.209 / 38.209** |
| Post 2 | 2,000 | 6399.471 / 6486.828 / 6706.750 | 6371.325 / 6456.494 / 6677.874 | **28.000 / 31.209 / 41.126** |
| Post 3 | 2,000 | 6392.325 / 6486.245 / 6781.127 | 6364.033 / 6454.160 / 6750.793 | **27.709 / 30.626 / 37.044** |

Thirty-one rounds measure both exported R1 logging refresh functions together
(`rga_log_enable_update` plus `rga_log_level_update`), not a single LOG-key proxy
for both keys. Each round includes inactive/active forwarding-counter batches of
100,000 calls; active counts must be exactly 100,000 for property/debug calls and
200,000 for the refresh pair. All batches pass. Debug calibration uses a real,
owned legacy context; post property lower costs are 0.057078–0.057183 µs, below
the corresponding inclusive debug maxima 0.083778–0.083970 µs. No inversion remains.

The point estimate is median net refresh-pair cost divided by median userspace
remainder. The upper numerator is the largest complete active-counter pair cost,
including parsing and atomic log-state updates. The lower systematic bound is
**zero**, because forwarding overhead in the numerator has not independently been
subtracted; a positive observed minimum is not mislabelled a proven lower bound.

Observer cost is measured with the **actual** forwarding timer and read-only
driver-version ioctls, not an arbitrary multiple of a readlink microbenchmark.
The observer receives 32 warmups, then 128 scored scopes; all 160 rows remain in
`observer.csv` (negative indices identify warmups). No scored outlier is removed.
For each repeat, with `Umin` the smallest G1 userspace remainder, `Qmax` the largest
scored observer remainder, `Imax` the largest ioctl count, and `Pmax` the largest
active refresh-pair cost, the upper percentage is
`100 * Pmax / (Umin - Imax*Qmax - Pmax)`. A nonpositive denominator means infinity.
Subtracting the entire pair cost also conservatively allows for its counter
overhead. These are **empirical warmed envelopes, not hard bounds or statistical
confidence intervals**; the point estimate is instrumented wall-time attribution,
not a measured optimization speedup or pure CPU time.

| Tree / repeat | Net pair median µs | Point estimate | Empirical envelope | Decision |
|---|---:|---:|---|---|
| Base | 0.121692200 | 0.443840543% | 0–0.968484686% | warmed below gate |
| Post 1 | 0.131334930 | 0.469036570% | 0–1.893894432% | warmed below gate |
| Post 2 | 0.131302850 | 0.468938750% | 0–1.569395414% | warmed below gate |
| Post 3 | 0.130912000 | 0.472452994% | 0–1.157708461% | warmed below gate |

**Item 44 / todo 34 Rock input:** approximately **0.469%**, with the three-repeat
envelope union **0–1.894%**, for the stated warmed steady-state protocol. This
does not meet the ≥2% prerequisite and grants **no permission to optimize**.
Do not generalize the result to cold calls: the preceding cold-inclusive observer
run (`h4-20260914T034622Z-3244767`) had first-scope costs 18.667/18.084 µs and
nonpositive corrected minimum denominators, giving **0–infinity: INCONCLUSIVE**.
That result is retained, not silently relabelled below gate. If todo 34 requires
an unconditioned/cold-path decision, its input remains INCONCLUSIVE. Any new or
applicable envelope crossing 2% likewise remains INCONCLUSIVE, not fix permission.

Radxa/R0's prior H4 rows stand. They do not export R1's enable-refresh function;
an attempted optional Radxa matched-pair rerun stopped before samples, and no
export was fabricated or library rebuilt to make it run. H1 and H8 were not rerun.

The corrected client is Debian GCC 14.2.0-19, GNU C11, `-O2 -g`, unstripped,
without LTO/sanitizers; SHA-256
`df866a0725073d89bcbb949d67b6dcff5a711b528ea224d87ec136fab2449767`.
Probe SHA-256: `353539e37a91141e1010a4451931a3455ac4b1294cebcedd34e73679e70f6618`.
Library identities are unchanged from the preceding table and were checked by
payload SHA-256 before execution. Raw timings, counts, calibration, observer
warmups, probes, failed attempts and exact build commands are retained.

H4 first acquired fresh ownership, then **inherited only this lane's exact retained
markers** across failed attempts. A collector token did not propagate out of a
shell command substitution during one resume; collection failed closed, the
detached runner finished, and its results were retrieved under the exact-owner
lease without restarting it. Continuous host-descriptor ownership across that
interval is **not claimed**. The final measurement held both host locks throughout;
the inherited markers were released at 03:50:26 UTC. RAUC before/after has both
slots good, B booted/A inactive, attempt budgets 3/3. No reboot, driver operation,
serial write, package installation, or slot mutation.
**Item 43 remains OPEN until the separately authorized OPi legs land.**

## OPi execution — calibrated, but decision INCONCLUSIVE (2026-09-14 UTC)

Run `20260914T130553Z-3452424` completes the OPi measurement matrix. The earlier
pending/deferred statements above are historical. This lane did not contact the
Rock. It reused, without rebuilding, the corrected client and probe identified
above for base/post-fix and the original client for Radxa/R0. Both corrected
artifact digests and all 28 original payload entries were checked on the board.
The four library build identities and toolchain/optimization/stripped distinctions
above remain unchanged; no unlike-build optimization or ABI conclusion is drawn.

The OPi reproduces the calibration precondition trap exactly: initially null
legacy context, base debug call SIGSEGV 11 in the isolated child, post-fix debug
call returning with **zero** lookups. Direct `RgaInit(void **)` returns **1** and
establishes the context; both initialized probes then perform exactly one lookup.
The measurement client also records null context after im2d warmup and non-null
after direct init. No invalid null-context calibration is used in the R1 figures.

Each row below uses CPU 6, 32 G1 warmups, then **2,000** scored G1 frames.
Values are median / p95 / p99 in µs/frame. Each scope has two debug lookups and
one ioctl. Userspace is the per-operation total minus summed ioctl durations,
not a subtraction of independently computed quantiles and not pure CPU time.

| Library / repeat | Total µs/frame | Summed ioctl µs/frame | Userspace µs/frame |
|---|---|---|---|
| Radxa | 6542.005 / 6620.463 / 6745.586 | 6515.172 / 6593.629 / 6717.294 | 26.834 / 29.458 / 37.332 |
| R0 rebuild | 6528.297 / 6602.380 / 6790.794 | 6499.714 / 6573.213 / 6760.752 | 28.584 / 30.917 / 36.458 |
| Untouched base | 6542.297 / 6618.129 / 6789.627 | 6515.464 / 6588.962 / 6756.377 | 26.833 / 30.332 / 39.084 |
| Post 1 | 6535.880 / 6619.587 / 6860.209 | 6508.755 / 6591.587 / 6823.169 | 27.125 / 30.042 / 38.500 |
| Post 2 | 6550.172 / 6617.546 / 6826.960 | 6522.463 / 6589.255 / 6796.043 | 27.416 / 29.749 / 37.334 |
| Post 3 | 6529.463 / 6606.462 / 6801.877 | 6502.630 / 6578.171 / 6765.419 | 26.834 / 30.040 / 38.500 |

Base/post use the same matched-refresh-pair and actual read-only ioctl observer
protocol as the corrected Rock run: 31 inactive and 31 active 100,000-call
calibration rounds, 32 observer warmups then 128 scored controls, all retained.
Every active property/debug count is 100,000 and pair count 200,000. All four
calibration-valid checks pass; there is no inclusive-upper/property-lower inversion.
Independent offline arithmetic reproduces the estimates/envelopes below.

| Tree / repeat | Net pair median µs | Point estimate | Warmed empirical envelope | Decision |
|---|---:|---:|---|---|
| Base | 0.132560920 | 0.494021987% | 0–1.395794425% | warmed below gate |
| Post 1 | 0.128731380 | 0.474585732% | 0–1.369317579% | warmed below gate |
| Post 2 | 0.128804280 | 0.469814269% | 0–2.454084260% | **INCONCLUSIVE** |
| Post 3 | 0.128661380 | 0.479471490% | 0–3.014690673% | **INCONCLUSIVE** |

Post observer maxima are 2.042 / 2.333 / 8.458 µs. The systematic lower bound
remains zero; the upper uses **all** scored extrema with the formula above.
No low-denominator frame or high observer sample was discarded. These empirical
envelopes are not hard bounds or confidence intervals. Repeating until a narrower
envelope appears would not erase these already measured rows.

Original-client comparison-only estimates: Radxa **0.372682%**, printed envelope
0.130869766–4.407397858% (**INCONCLUSIVE**); R0 **0.354518%**, printed envelope
0.180020750–0.910127368%. These use the old property/debug proxy and empirical
observer allowance, not the matched R1 pair method; their positive lower values
are not asserted as systematic lower bounds and neither authorizes an R1 fix.

**Item 44 / todo 34 cross-board input: INCONCLUSIVE, no fix permission.** Rock's
corrected warmed 0–1.894% result stands, but OPi's warmed union reaches 3.015%.
Rock cold-inclusive remains INCONCLUSIVE; OPi cold-inclusive was not measured.
Item 43's requirement to supply measurements and a ≥2% decision input is met;
that is not a claim that the downstream measurement-gated optimization may run.
If a conclusive todo-34 decision is required, further justified profiling remains
owed. The historical Valgrind skip is unchanged.

One fresh **OWNED** dual-contract lease covered the entire OPi run, held by the
detached host collector 13:05:54–13:20:22 UTC, then released normally. No inherited
marker, collector timeout, library rebuild, installation, driver reload, reboot,
serial write, camera-setting or service change. B stayed booted, both RAUC slots
good, budgets 3/3; CeraUI executable/public assets and configuration hashes match.

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

## Appendix — h7.md

Source: [fix-audit.d/h7.md](fix-audit.d/h7.md). D21 rows are in the [ledger above](#rows).


## Prepared escalation

Real DMA-BUFs from `/dev/dma_heap/system`, one source/destination pair per worker;
3840×2160 NV16→NV12 `improcess(IM_SYNC)`. For each board: Radxa, R0, untouched
57a1067, then post-fix confirmation. N=1 five-second control, then N=4,6,8 for
60 seconds each. Any worker with no completed operation for five seconds is a
STALL; any failed IM_STATUS is an incident. The first incident stops further
levels **and libraries**. Therefore an early Radxa incident leaves the R1 base
unmeasured and cannot license an R1 fix.

The watchdog writes per-worker FPS and an incident marker before stopping the
process for stack collection. The runner captures kernel journal, counters and
sudo stack availability, kills only its process, then requires responsive load
and a successful one-worker recovery workload. No reboot/module reload. Failed
recovery exits 86 and requires owner/island-track intervention. A complete clean
budget records `NO-STALL at 8 threads`; no QEMU fixture is a hardware result.

Artifacts: `test-results/h7/<board>/<lib>/levels.csv` and per-level FPS, journal,
stack/recovery and counter transcripts. No board command has been executed.

## Rock escalation — stopped at first incident (2026-09-14 UTC)

The preparation record above is historical. Actual evidence is retained under
run `20260914T023538Z-2107123`, `h7/radxa/`, with the unchanged runner's
`h7.exit=3`. All libraries were isolated copies, never installed.

The Radxa one-thread five-second control passed; later libraries' controls were
not reached.

| Library | N=4 | N=6 | N=8 | Stall / incident threshold |
|---|---|---|---|---|
| Radxa | 60.175039 s OK | 60.174391 s OK | IM_STATUS_FAILURE at 4.605350 s; remaining dwell not run | **First status-failure incident at 8; progress-stall threshold unestablished** |
| R0 rebuild | NOT-RUN | NOT-RUN | NOT-RUN | Stopped after Radxa incident |
| Untouched `57a1067` | NOT-RUN | NOT-RUN | NOT-RUN | No historical base RED established |
| Post-fix `5dfe897` | NOT-RUN | NOT-RUN | NOT-RUN | No current repair confirmation established |

At eight threads, worker 4 returned status **0**, while the other seven workers'
last statuses remained success **1**. The aggregate incident label is printed
on every worker row; that does **not** mean all eight calls failed. Workers had
completed 108–114 frames each. The `levels.csv` value `seconds=60` is the
**requested** budget, not elapsed time; the per-worker `fps.csv` gives the actual
4.605350 s before this stop. No five-second no-progress incident was reported.

Kernel journal for the test process records repeated
`Failed to map attachment, ret[-5]`. This is supporting driver evidence, not a
proved kernel root cause. Captured stacks show `do_signal_stop`, consistent with
the harness's deliberate stop for capture; they are not proof of a mutex deadlock.
Missing `mm` and alternate debugfs paths are recorded UNAVAILABLE, never invented.
No driver module, kernel, or library was changed in response.

Recovery: `/proc/rkrga/load` remained responsive, and the **same Radxa library**
completed a one-worker run with **157 frames in 1.101792 s**, status 1, verdict OK.
The test process was killed by the incident runner. Final locked health inspection
confirmed the process absent, all three RGA schedulers at 0% load, and both RAUC
slots good (B booted, A inactive). No reboot, reload, or slot mutation occurred.

**Execution discipline gap:** the host tool timeout terminated the original
collector after 120 s while the detached remote runner continued and stopped
itself. Its remote ownership marker remained intact, but uninterrupted possession
of the host descriptor lock is **not claimed**. The collector was reattached with
a fully detached session, acquired the host lock, verified this lane's exact
retained marker, and retrieved the completed incident/recovery archive without
restarting a workload. It then released ownership. Every additional remote
command was issued under an acquired host lock; no OPi connection or lock was used.

Radxa is its stripped vendor binary, compiler/optimization unknown. The prepared
R0/base/post libraries use aarch64 Debian GCC/G++ 14.2.0-19, Meson debugoptimized
`-O2 -g`, C++14/`-fpermissive`, unstripped, no LTO or sanitizers; those libraries
were **not reached by H7**. H7 client: same GCC, GNU C11, `-O2 -g`, unstripped.

**Item 45 scope input:** investigate the Radxa incident and its driver diagnostics;
do not label it an R1 stall or authorize an R1 fix. **Item 43 remains open** for the
missing H7 library rows, the H4 calibration gap, and the separately authorized OPi
dispatch. Continuing past this incident was deliberately not attempted.

## Rock follow-up — missing library matrix measured (2026-09-14 UTC)

The NOT-RUN entries above preserve the first run's history. Owner-authorized
follow-up `h7-20260914T032730Z-2926571` measures only R0, base and post-fix.
The existing binary and runner body are unchanged. An execution adapter selects
one library per invocation, retaining the first-incident stop and same-library
recovery requirement; only a completed recovery permits the next invocation.
There is no retry of the failed eight-thread dwell and no invented 60-second pass.

| Library | N=1 control | N=4 elapsed | N=6 elapsed | N=8 incident elapsed | Failed worker / status | One-worker recovery |
|---|---|---|---|---|---|---|
| R0 rebuild | 5.106143 s OK | 60.177739 s OK | 60.175414 s OK | **0.400651 s** | 6 / 0 | 143 frames / 1.101724 s, OK |
| Untouched base | 5.106664 s OK | 60.174696 s OK | 60.177585 s OK | **0.500773 s** | 4 / 0 | 155 frames / 1.101622 s, OK |
| Post-fix | 5.106911 s OK | 60.175719 s OK | 60.176356 s OK | **0.901518 s** | 7 / 0 | 152 frames / 1.101648 s, OK |

All three failures are `IM_STATUS_FAILURE`. Other workers still have last status
1; the shared verdict column does not mean every worker failed. Together with the
retained Radxa row (4.605350 s), **the first status incident is at eight threads
for all four libraries**. No five-second progress-stall threshold was observed or
established. No library completed the eight-thread budget, so none earns
`NO-STALL at 8 threads`.

Each incident's kernel journal contains `Failed to map attachment, ret[-5]`
attributed to that test process. This common signature makes the island/driver
DMA-BUF mapping path the next investigation owner, not a Radxa-only compatibility
patch. It is supporting evidence, **not a proved driver root cause**: common
userspace request handling or harness pressure is not excluded by this matrix.
The base now has a real-device status-failure RED, but that alone neither proves
an R1 mutex stall nor authorizes an R1 code change. No library or driver was fixed.

H7 held freshly **owned** host locks and matching remote markers for both the
canonical board harness and the inherited librga lock contract. A detached host
collector held them continuously from 03:27:32 through release at 03:34:10 UTC;
this run did not inherit the previous lane's marker and suffered no collector
timeout. Logs and archives were collected incrementally. RAUC before/after:
both slots good, B booted/A inactive, attempt budgets 3/3. Load remained responsive;
the immediate post-recovery sample still showed 27% on one scheduler, so it is
not described as a zero-load observation.

Hashes of all staged payload entries were verified before measurement. The
R0/base/post compiler and optimization identities above apply unchanged; Radxa's
toolchain remains unknown/stripped. No rebuild, package install, driver reload,
serial write, reboot or slot mutation. Raw `fps.csv`, `levels.csv`, counters,
kernel journals, stacks and recovery outputs are retained with the run.
**Item 43 remains OPEN for the OPi legs**, which this lane never contacted or
locked; this follow-up closes only the Rock H7 missing-library measurement gap.

## OPi escalation — all four libraries complete eight threads (2026-09-14 UTC)

Run `20260914T130553Z-3452424`, `h7/<library>/`: each library ran the unchanged
H7 executable and runner body in a separately selected invocation. The adapter
retains first-incident stop and permits another library only after clean completion
or successful same-library recovery. **No incident occurred**, so every library
completed every level and all four per-library exits are zero. No failed dwell
was retried. Recovery is **not invoked**, not an invented recovery PASS.

| Library | N=1 control elapsed | N=4 elapsed | N=6 elapsed | N=8 elapsed | Threshold / verdict | Incident recovery |
|---|---|---|---|---|---|---|
| Radxa | 5.105583 s | 60.171312 s | 60.173267 s | 60.177481 s | **NO-STALL at 8** | not invoked |
| R0 rebuild | 5.106846 s | 60.170418 s | 60.171520 s | 60.175651 s | **NO-STALL at 8** | not invoked |
| Untouched base | 5.106433 s | 60.174285 s | 60.170043 s | 60.172038 s | **NO-STALL at 8** | not invoked |
| Post-fix | 5.106355 s | 60.178206 s | 60.178994 s | 60.179594 s | **NO-STALL at 8** | not invoked |

Every worker's final status is success 1 and verdict OK. Per-worker frame counts,
FPS, before/during/after counters and kernel journals are retained. This is the
finite 60-second-per-level result, not a claim about higher concurrency or long
soaks. The load interface was responsive after completion; its immediate rolling
load sample was 35% / 35% / 48%, **not zero load**, with no session rows listed.

**The OPi does not agree with the Rock's incident outcome.** The exact same four
library artifacts fail at eight on Rock but complete eight on OPi. This preserves
the Rock-local evidence against a Radxa-specific explanation, while rejecting a
uniform both-board failure claim. Board/kernel-runtime/DMA-BUF mapping differences
remain the investigation target; this experiment does not establish their root
cause or isolate memory pressure, request routing, or driver state. No OPi base
RED exists for H7; Rock base status-failure RED does not prove an R1 mutex stall.
**No R1 fix is authorized.** Surface the contrast to the island/driver investigation.

Payload hashes were verified before execution; no client, library or driver was
rebuilt or installed. Rebuilt libraries and client: Debian GCC/G++ 14.2.0-19,
aarch64, `-O2 -g`, unstripped, no LTO/sanitizers; libraries are Meson
debugoptimized C++14/`-fpermissive`. Radxa remains stripped with unknown vendor
compiler/optimization. These are observations of named artifacts, not ABI claims.

Fresh **OWNED** canonical and legacy host locks plus exact remote markers were
held continuously by the detached collector 13:05:54–13:20:22 UTC, then released.
Before/after: `7.2.0-ceralive-rk3588`, unchanged boot ID/packages/configuration and
CeraUI/service state, B booted/A inactive, both RAUC slots good, budgets 3/3.
No Rock contact, serial write, reboot, driver reload, camera or service change.
The Rock follow-up above already closed its cut-short library matrix; **no H7
library measurement remains owed for item 43**. Root-cause review remains separate.

## Appendix — h8.md

Source: [fix-audit.d/h8.md](fix-audit.d/h8.md). D21 rows are in the [ledger above](#rows).


## Prepared colour matrix

Host-generated 4K colour bars use the fork-owned `tests/oracle/oracle.c` from
todo 20. Nothing is copied from the BT.601-bent downstream oracle associated
with `77b3bcb0`. BGR→NV12 and NV12→BGR each test default, explicit 601 limited,
explicit 709 limited against **both** references (12 scores). NV16 is generated
as 709-coded YUV with repeated chroma rows; NV16→NV12 is a no-CSC resampling
cell against the same-colourimetry NV12 reference. An additional inappropriate
CSC request must be rejected and is recorded separately, never worked around.

The 4K→1080p NV12 downscale compares default and explicit
`IM_INTERP(IM_INTERP_CUBIC, IM_INTERP_CUBIC)` against a separable antialiased
Lanczos-3 reference: pixel-centred half scale, 12 taps per axis, edge clamping,
normalized weights, floating-point intermediate, rounding only at final output.
Constant and interior affine anchors are host-testable. The inherited oracle's
literal 601/709 colour anchors remain authoritative for colour conversion.

`psnr.csv` contains 15 scored rows plus the YUV-YUV rejection record per tree
per board. Explicit-709 BGR→NV12 must beat default against 709 by at least 1 dB;
otherwise the leg exits invalid for investigation, not MEASURED. The hardware
fragment becomes MEASURED only after actual board results are imported. All
CPU DMA-BUF reads/writes are synchronized; library defaults remain unchanged.
No board command has been executed.

## Rock PSNR measurements (2026-09-14 UTC)

The preparation record above is historical. Run `20260914T023538Z-2107123`
completed the unchanged H8 script with exit 0 on both trees. The table lists
**all 15 scored cells per tree**, in dB; the negative control is separate.

| Cell | Requested mode | Reference | Untouched `57a1067` dB | Post-fix `5dfe897` dB |
|---|---|---|---:|---:|
| BGR→NV12 | default | 601 limited | 52.825289 | 52.825289 |
| BGR→NV12 | default | 709 limited | 27.002087 | 27.002087 |
| BGR→NV12 | explicit 601 limited | 601 limited | 52.825289 | 52.825289 |
| BGR→NV12 | explicit 601 limited | 709 limited | 27.002087 | 27.002087 |
| BGR→NV12 | explicit 709 limited | 601 limited | 27.000895 | 27.000895 |
| BGR→NV12 | explicit 709 limited | 709 limited | 52.970666 | 52.970666 |
| NV12→BGR | default | 601 limited | 53.264029 | 53.264029 |
| NV12→BGR | default | 709 limited | 28.041012 | 28.041012 |
| NV12→BGR | explicit 601 limited | 601 limited | 53.264029 | 53.264029 |
| NV12→BGR | explicit 601 limited | 709 limited | 28.041012 | 28.041012 |
| NV12→BGR | explicit 709 limited | 601 limited | 27.920087 | 27.920087 |
| NV12→BGR | explicit 709 limited | 709 limited | 53.859821 | 53.859821 |
| NV16→NV12 | default, no CSC | 709 same-colourimetry | ∞ | ∞ |
| NV12 4K→1080p | default interpolation | Lanczos-3 | 54.344714 | 54.344714 |
| NV12 4K→1080p | explicit cubic/cubic | Lanczos-3 | 54.344714 | 54.344714 |

All scored operations returned `IM_STATUS_SUCCESS=1`. For **both trees**:

- The inappropriate NV16→NV12 CSC request returned **-4**; its `nan` PSNR is
  unscored, not zero or a missing positive cell.
- Explicit-709 BGR→NV12 beat default against the 709 reference by
  **25.968579 dB**, exceeding the required 1 dB negative-control separation.
- Default and explicit 601 coincide on these bars; wrong-reference scores are
  intentional characterization, not failures to be fixed by changing defaults.
- Identical interpolation scores describe this fixture only; they do not prove
  that default and cubic are generally equivalent.

Raw evidence: per-tree `h8/<tree>/psnr.csv` and `control.txt` in the retained
execution archive. The 4K references and binaries are the original payload,
SHA-256 `aa07266832b924f1a4443c85ceb437cbb9ecef755fcbc8494fa1a04ef3005201`,
verified per file on the Rock before execution and again on resume. No QEMU
fixture or fake device entered this run.

Both libraries: aarch64 Debian GCC/G++ 14.2.0-19, Meson debugoptimized `-O2 -g`,
C++14/`-fpermissive`, unstripped, no LTO/sanitizers. H8 client: same compiler,
GNU C11, `-O2 -g`, unstripped. No library, reference, default, or package changed.
**Item 43 remains open**: OPi has no row, and Rock's H4 gap is separate from
these completed colour measurements.

## OPi PSNR measurements (2026-09-14 UTC)

Run `20260914T130553Z-3452424`, `h8/<tree>/{psnr.csv,control.txt}`:
all 15 scored cells on **each** tree, with the negative control separate.
The earlier pending-OPi statements are historical; no Rock command ran here.

| Cell | Requested mode | Reference | Untouched `57a1067` dB | Post-fix `5dfe897` dB |
|---|---|---|---:|---:|
| BGR→NV12 | default | 601 limited | 52.825289 | 52.825289 |
| BGR→NV12 | default | 709 limited | 27.002087 | 27.002087 |
| BGR→NV12 | explicit 601 limited | 601 limited | 52.825289 | 52.825289 |
| BGR→NV12 | explicit 601 limited | 709 limited | 27.002087 | 27.002087 |
| BGR→NV12 | explicit 709 limited | 601 limited | 27.000895 | 27.000895 |
| BGR→NV12 | explicit 709 limited | 709 limited | 52.970666 | 52.970666 |
| NV12→BGR | default | 601 limited | 53.264029 | 53.264029 |
| NV12→BGR | default | 709 limited | 28.041012 | 28.041012 |
| NV12→BGR | explicit 601 limited | 601 limited | 53.264029 | 53.264029 |
| NV12→BGR | explicit 601 limited | 709 limited | 28.041012 | 28.041012 |
| NV12→BGR | explicit 709 limited | 601 limited | 27.920087 | 27.920087 |
| NV12→BGR | explicit 709 limited | 709 limited | 53.859821 | 53.859821 |
| NV16→NV12 | default, no CSC | 709 same-colourimetry | ∞ | ∞ |
| NV12 4K→1080p | default interpolation | Lanczos-3 | 54.344714 | 54.344714 |
| NV12 4K→1080p | explicit cubic/cubic | Lanczos-3 | 54.344714 | 54.344714 |

Every scored status is success 1. Both trees reject the inappropriate CSC with
**−4**, whose unscored PSNR is `nan`. Both improve explicit-709 BGR→NV12 against
the 709 reference from **27.002087 to 52.970666 dB**, separation **25.968579 dB**.
Wrong-reference scores remain intentional controls, not default-change requests.
Equal default/cubic scores apply only to this fixture, not all scaling inputs.

The original payload, including the precomputed references, was unchanged and
verified by all 28 per-file SHA-256 checks on the board. The library/client build
identity remains Debian GCC/G++ 14.2.0-19, aarch64, `-O2 -g`, unstripped, without
LTO or sanitizer; library flags Meson debugoptimized/C++14/`-fpermissive`, client
GNU C11. No rebuild, mock device, package install, or camera/default change.

Fresh **OWNED** two-contract lease, 13:05:54–13:20:22 UTC, with a continuously
detached collector and normal exact-marker release. Before/after CeraUI public
assets, running executable and configuration hashes match; both RAUC slots remain
good, B booted, budgets 3/3. H8's both-board item-43 matrix is now complete.

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

## Todo 36 — stderr with context

The R1-base run above is the RED transcript. It captures 89 bytes of the
unchanged failed-open message on stdout without the shim and 28 bytes of the
unchanged version banner with the shim. The fix routes library diagnostics to
stderr, prefixes them with `librga:`, preserves the existing message text as a
substring, and leaves `IM_STATUS` values unchanged. The Meson `unit-logging`
tests run both paths: no device proves the error still prints even when logging
is otherwise disabled; the fake device proves the initialization banner no
longer reaches stdout. The GREEN `run-h9.sh` transcript captures zero stdout
bytes in both paths. A matched arm64 Trixie `abidiff` against the R1 base exits
cleanly with no removed or changed exported symbol. The C macro regression covers
the public header paths that previously emitted invalid-argument diagnostics to
stdout. Android's existing logcat sink did not use stdout and remains unchanged;
the carried stderr requirement applies to the Linux/RT stdout implementations.

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

## Appendix — logging-round-five.md

Source: [fix-audit.d/logging-round-five.md](fix-audit.d/logging-round-five.md). D21 rows are in the [ledger above](#rows).

# PR 9 review round five — logging suppression

The fifth review, by **Oracle**, model **openai/gpt-5.6-sol**, rejected the
logging changes at `56bac09`. This records the supplied rejection, not an
independent approval of the follow-up fixes.

## Failing-first evidence and bounded fixes

Before changing production code, the new captured-output assertions failed on
`56bac09`: `unit-logging-no-device` and `unit-logging-fake-device` each reported
six failures (constructor notice and selected legacy severities at thresholds
0 and 6). `unit-gaussian-logging` reported six framing failures; its value
assertions passed. The run is preserved in `test-results/logging-red-build.log`.

Removing both added im2d gates from `ALOGI`/`ALOGD` restores their original
unconditional macro behavior, while retaining stderr, the `librga:` prefix and
every enriched message. Gaussian framing now uses `IM_LOG_ENABLED`, the same
predicate used by all `IM_LOG` implementations: enable plus threshold, OR error,
OR force. No log defaults or error-message-storage behavior changed. Both stale
flag comments now describe the actual sink and direct-output behavior.

The focused post-fix run passed all three tests with zero skips. Its transcript
is `test-results/logging-green-tests.log`. These are host-shim observations,
not hardware validation. No H10 launcher, signature, layout, visibility, SONAME
or `IM_STATUS` definition changed.

## Historical public-setter acceptance gap

**2026-09-15 disposition:** the owner-directed separate scope selected honest
deprecation, not reconnection. The header now explicitly documents both methods
as compatibility no-ops for logging. `legacy-once` and `legacy-always` are mandatory
Meson tests of that deliberate contract, with repeated operations, zero/nonzero
values, distinct context-state sentinels and positive environment/direct-dump
controls. The original positive-output assertion is replaced under this explicit
contract decision, not waived as an expected failure. The historical RED evidence
below remains unchanged; it is not a current unexplained failing probe. See
[`LEGACY-LOG-SETTERS.md`](../LEGACY-LOG-SETTERS.md) for the D29 rationale.

The review's setter explanation conflated two different fields. The inline
`RkRgaSetLogOnceFlag` and `RkRgaSetAlwaysLogFlag` write private members of
`RockchipRga`; no implementation reads those members. The similarly named
`rgaContext` fields are a different object, used by the Android palette path.
Linux operations select debug output through `is_debug_log()` / `is_out_log()`.
This wiring is identical in `e5f3fc0^`, before todo 36, and in `56bac09`.

Two explicit modes of `unit-logging` preserve the requested positive-output
assertion: `legacy-once` and `legacy-always`. Both were run before the macro
change with `ROCKCHIP_RGA_LOG` unset and the fake device preloaded. Each reported
9 assertions, 1 failure: `requested operation diagnostic emitted`. Device
initialization and the fill succeeded; global logging stayed disabled and
stdout stayed empty. Construction happens outside the capture, so its notice
cannot disguise the missing operation diagnostic. The modes refuse to run
without the shim and are not registered as green Meson tests.

Reconnecting these setters is a separate behavioral change, not a stderr
redirection repair. It was not implemented; in particular, no setter now writes
the global enable state. The requested setter-success acceptance criterion is
**not met** and requires a scope decision. No failing assertion was inverted or
removed to make the gate pass.

## Todo 36 call-site walk

Reviewed every production hunk of `e5f3fc0` against its parent:

- `NormalRgaContext.h`: the only newly gated legacy macros; now unconditional.
  The constructor uses `ALOGI`; operation `ALOGD` calls retain their existing
  call-site predicates. Android's system ALOG definitions are untouched.
- `im2d_debugger.cpp`: the two newly gated framing writes; now share the value
  predicate, including force from `rga_dump_opt()` and unforced errors.
- `im2d_log.h`: stdout-to-stderr sink replacement retained the existing
  enable/error/force predicate and error-message update conditions. The shared
  predicate preserves that behavior (Android error priority is also 6).
- `NormalRga.cpp`, `NormalRgaApi.cpp`, `im2d_impl.cpp`: direct diagnostic
  replacements remain unconditional inside the same branches; geometry
  enrichment remains intact. The palette ioctl failure retained its identical
  unconditional ALOGE diagnostic after removal of the duplicate printf.
- `RgaUtils.cpp`, `RockchipRga.cpp`, `GrallocOps.cpp`: format, file, DRM and
  gralloc diagnostic conditions are unchanged; context and errno additions stay.
- `im2d_buffer.h`, `im2d_common.h`, `im2d_single.h`: public C overload-error
  branches still emit unconditionally, preserving their message substrings.
- `im2d_context.cpp`: RT-Thread device errors now use IM_LOGE; the error bypass
  keeps them unconditional even when global logging is disabled.

The existing 62-row ledger and historical review receipts remain unchanged;
this appendix does not manufacture an approval receipt or waive release gates.

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

## Appendix — todo-38.md

Source: [fix-audit.d/todo-38.md](fix-audit.d/todo-38.md). D21 rows are in the [ledger above](#rows).


## Reproduction and artifacts

Both branches start at `f04a90e`. H10's implementation file was unchanged from
`57a1067` at the execution base; already-merged initialization/lifetime fixes
were not reimplemented. Reproduction budget: original runner's two requested
2000-iteration races per sanitizer, 30-second timeout per process. RED stops at
the first sanitizer report, not at 2000 completed iterations.

Commands: `bash tests/repro/run-h10.sh asan` and `... tsan`, before and after.
They were run detached in a native x86_64 trixie container. ASan+UBSan use
`verify_asan_link_order=0`, `detect_leaks=1`, `halt_on_error=1`, `symbolize=0`;
the canary permits UBSan to continue to its ASan fault. TSan uses
`halt_on_error=1:exitcode=66:symbolize=0`. No suppression file is used.

| Phase | ASan+UBSan directory | TSan directory |
|---|---|---|
| RED | `test-results/h10/asan-mcIiMjp9/` | `test-results/h10/tsan-011JL9dR/` |
| GREEN | `test-results/h10/asan-U1HIB78Y/` | `test-results/h10/tsan-1YmHdZWG/` |

Every directory contains `status.tsv`, build/compile logs, and
`{canary,control,count,release,race-1,race-2}/transcript.txt` plus shim logs and
request dumps. The original runner's aggregate exit stays **1** because H10c's
forwarding observation is intentionally unchanged; GREEN refers to H10a/H10b,
not to a falsified aggregate result.

### Terminal lines from the original runner

```text
RED (both modes):
H10a unknown=2147483647 status=1 before=0/0 after=-1/0 created=63/64 cleaned=-1/0 count_drift=RED
ASan race-1/race-2: ERROR: AddressSanitizer: heap-use-after-free (exit 1 each)
TSan race-1/race-2: WARNING: ThreadSanitizer: heap-use-after-free (exit 66 each)

GREEN (both modes):
H10a unknown=2147483647 status=1 before=0/0 after=0/0 created=64/64 cleaned=0/0
ASan race-1: completed=2000 config_success=754 config_missing=1246 end_success=751 end_missing=1249 count=0 map=0
ASan race-2: completed=2000 config_success=758 config_missing=1242 end_success=753 end_missing=1247 count=0 map=0
TSan race-1: completed=2000 config_success=115 config_missing=1885 end_success=110 end_missing=1890 count=0 map=0
TSan race-2: completed=2000 config_success=98 config_missing=1902 end_success=93 end_missing=1907 count=0 map=0
All four GREEN race exits: 0; no sanitizer report.
```

Offline symbolization of the RED TSan offsets is saved in
`test-results/item45/red-tsan-symbols.txt`: CONFIG `0x4d5e4` resolves to
`im2d_impl.cpp:2560`, CANCEL `0x4cacf` to `:2442`. This identifies actual shared
library frames, not just the shim's read. The sanitizer canary transcripts
prove interception, not merely linked runtimes.

The new registration adds `count`, `control`, `errors`, `reimport` and two races
to `h10`; races also enter `concurrency`. Per-case log truncation makes repeated
Meson runs independent. `errors` tests failed CONFIG followed by successful
CONFIG/cancel and repeated cancellation, including unchanged status values.

Registered-suite evidence: `test-results/item45/h10-asan-suite-fixed.txt` (6/6)
and `h10-tsan-suite-fixed.txt` (6/6). 2000-iteration repeats took 1.25/1.32 s
under ASan and 3.37/3.40 s under TSan in that run: bounded host-model overhead,
**not** hardware latency. The earlier `h10-*-suite.txt` files preserve the
failed aggregate static-UAPI rebuild; the recipe now uses `--no-rebuild` after
the explicit sanitizer build, with the static parity gate kept unsanitized.

Adjacent native tests and eight unchanged goldens: `test-results/item45/fixed-tests.txt`
(28/28, excluding only the separately covered architecture-specific UAPI suite).
ABI inputs are `build-abi-base/librga.so.2.1.0` and
`build-fixed/librga.so.2.1.0`, both GCC 14 debug builds with identical options.
This is a same-R1-base change comparison, **not** a waiver of inherited R0→R1
export removals.

### CI discovery repair after independent review — 2026-09-14

Review `ses_f5f17f6e7ffeDBxkvfDovEpWDs` rejected the CI coverage claim at
`b58df2b`: the bare list-membership predicate missed Meson's project-prefixed
suite names and reported zero concurrency tests. The repair matches the exact
`:concurrency` suffix and counts each test once, retaining `--no-rebuild`.
No sibling discovery predicate exists: H10 is selected directly by `--suite h10`.
The existing CI-gating test now executes the actual discovery block against seven
fixtures (prefixed names, multiple suites, near-matches and empty/missing suites).
It failed on the old predicate (`librga:concurrency`: expected 1, got 0), then
passed 7/7 after the repair; all seven existing summary-gate cases still pass.

`SKIP_DEPS=1 bash ci/sanitizers-steps.sh` at `7f4c69d` ran in the native amd64
Debian trixie tools container, GCC 14.2.0, Meson 1.7.0, with
`seccomp=unconfined`. Both sanitizer trees rebuilt; the complete gate exited 0
in 11 seconds. Logs: `test-results/todo38-ci-gate.log`,
`test-results/todo38-ci-gate.exit`, and `test-results/sanitizers-summary.txt`.

- ASan/UBSan baseline: 11/11 OK; H10: 6/6 OK (`asan-h10-testlog.txt`).
- ASan/UBSan and TSan canaries reported their deliberate faults.
- Summary: **`concurrency tests: 6`**. `test-results/tsan-testlog.txt` records
  `candidate-a-init`, `candidate-b-deinit`, `candidate-b-refcount`,
  `candidate-b-exit`, `h10-race-1`, and `h10-race-2`: **6/6 OK**, zero failures.
- Both TSan H10 races completed 2000 iterations, with 95/112 successful CONFIG
  calls and final count/map 0/0. Durations were 1.40/1.41 seconds; the other
  newly discovered tests took 0.02–1.03 seconds each. No new failure surfaced.
  These are absolute timings, not a measured before/after CI speed comparison.

The README H10 CI claim, AGENTS suite registration contract, and SANITIZERS
discovery contract now agree with an executed gate, not just a manual suite run.
Evidence remains **amd64 host-shim-only**, not an arm64 CI-run or board claim.
The production fixes and their regressions were unchanged. This repair is not
an independent APPROVE receipt; review/merge remains with the coordinator.

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
