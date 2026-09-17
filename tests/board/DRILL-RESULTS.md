# R1 both-board drill results — post-release record [PARTIAL]

**Recorded after release, 2026-09-17 UTC; measurements dated 2026-09-16/17.**
This consolidation was not on the open R1 PR before its merge. Required order:
both-board record → review → merge → release. Actual order: merge → release →
record. Publishing this document does not repair that historical ordering or
decide the owner's acceptance disposition. See the
[rows 24/26 deviation record](../../docs/R1-RECORD-DEVIATIONS.md).

**Item 47 is not fully dischargeable on the retained evidence.** R1 is released
and served, and both boards proved released-byte activation and genuine rollback.
That does not establish the required identity between the released artifacts and
the earlier semantic/soak/package-transaction artifacts. Rock's R1 H7 and factory
inventory also remain unresolved. This is an offline consolidation, not another
hardware run or permission to change either board.

This record covers convergence item 47 and its inherited librga todos 41–43,
including the September 15 census/package amendments and September 16 owner
decisions. Historical failures remain in their original records. A later scoped
success supersedes only the corresponding failure, not every row in that run.
No plan checkbox or acceptance criterion is changed. This post-release document
is being committed through a documentation PR; no package publication, tag,
release, pin update or new hardware run is part of that change.

## Evidence locators

The identifiers below name retained evidence collections and their members, not
filesystem dependencies on another checkout. They allow the report to remain
self-contained. The workspace audit supplies the absolute host-location index.
Raw collections are not claimed to be embedded in this repository or uploaded
with this new report.

| ID | Collection and members |
|---|---|
| ROCK | `r1-rock-acceptance-20260916`: `DRILL-RESULTS-ROCK.md`, `PROVENANCE.md`, `D24-RESULTS.md`, `HISTORICAL-CORPUS.md`, `logs/rows.txt`, `logs/soak.log`, `logs/scores.txt`, `d24-results/factories.txt`, `final-control.log` |
| OPI | `r1-opi-acceptance-20260916`, member `test-results/acceptance/`: `FINDINGS.md`, `r6-verdict.log`, `recovered/soak.log`, `isolation-verdict.log`, `drill/`, `final/` |
| IMAGE | `decision-1b-image-20260916`: `HARDWARE-PROCEDURE.md`, `package-proof.log`; `proof/H2-H4-RESULTS.md`, `proof/H2-H4-NOTEPAD.md`, `proof/h1.1-executed.log`, `proof/h1.2-executed.log`, `proof/h1.4-executed.log` |
| ROCK-OPS | IMAGE `proof/rock-resume-RESULTS.md`, `rock-resume-h3.txt`, `rock-resume-h4.txt`, `rock-resume-comparison.txt`; prior `r1-install-rock.txt`, `rock-h3-preview-hdmi.txt` |
| OPI-OPS | IMAGE `proof/opi-h234-RESULTS.md`, `opi-h234-install.txt`, `opi-h234-preview.txt`, `opi-h234-assert.txt`, `opi-h234-comparison.txt`, `opi-h234-final.txt` |
| GB15 | `task-47-todo42-20260915`: `REPORT.md`, `NUMERIC-TABLES.md`, `rock-measure/results/`, `opi-measure/results/` |
| D24-OPI | `gb-complete-opi-20260915`: `REPORT.md`, `NUMERIC-TABLES.md`, retained raw outputs, fixtures and scorer controls |
| H7-ROCK | `h7-postfix-rock-20260915T202843Z`: `REPORT.md`, `results/{1,4,6,8}/fps.csv`, corresponding maps and journal receipts |
| RATE | `opi-gb-rate-20260916`: `REPORT.md`, `MEASUREMENTS.md`, `QA.md` |
| CI15 | `librga-pr15-evidence-bff0cec/receipt.md`; [exact-head Build Check 35132310063](https://github.com/CERALIVE/librga/actions/runs/35132310063) |
| CI17 | `librga-pr17-review-receipt.md`, `librga-pr17-review-ci`; [post-sync Build Check 35135448873](https://github.com/CERALIVE/librga/actions/runs/35135448873) |
| PUB | `librga-r1-release-35155428515/reindex.log`; [live Publish Release 35155428515](https://github.com/CERALIVE/librga/actions/runs/35155428515) |
| APT | `librga-r1-image-evidence/serving-receipt.md`; saved `librga-r1-stable-arm64-Packages` |

## Artifact identities — do not merge these columns

Both candidate and release name source
`d57bc86e65b331948953442449618cadd3b0c7bc` and version `1.10.5+ceralive.1`.
**Same source and version are not byte identity.**

| Artifact | Local candidate tested by both R6 runs and H1 | Published / APT / H2–H4 |
|---|---|---|
| Runtime `.deb` SHA-256 | `724834d6e122ab17e6d338c356e6bf7a0849aedfc969683ca45374cbeb7bcb0f` | `5f8ea1f259b95d5bf6fbe68edf03bf08820ab7bc8d4d17bfc1fc4a00344c7bb3` |
| Development `.deb` SHA-256 | `77509b8b1bd52578c7cbf2f0ebbeaff720377fb9f33fb07d34790268ae2b4489` | `8dd35334ed1022ff8e64a86b3ac426abb847bf36f3ccff2746a658ccc0d8577a` |
| Runtime ELF SHA-256 | `361ab931ebe49f3c77256003a36849dc5703de26f3863ada0acdbe84a6f7c884` | `07b6b6c466c6bddbcf7006e5b678d68de372b44686e6eb8ea3fcf00ce1cb6b74` |

Released R0 control ELF throughout the final acceptance records:
`adf9e34934497092c30ba2ec3cf45141e058c368991d77524d9c0e38f5e29fc6`.
Recovered bench used for both R6 runs:
`4800fe29a6f0a9a48e6098c4606e2838b8e09019b0bcf84c312e966be53063b6`.

IMAGE explicitly records that even the runtime ELF changed and forbids transferring
old H1 as artifact-bound proof. Its procedure states that H1 has not been repeated
against the released bytes. No cause of the byte difference, executable equivalence
proof, owner waiver of exact identity, or released-byte full G-B rerun was located.
This is an **evidence-transfer gap**, not a demonstrated defect in the release.

Other older R1 receipts also retain their own identities:

- D24-OPI fixed provider: source `8fcf447a9a79fe65535388293b83ac927a06af33`,
  ELF `725e0f70ff390335ddab5de2016aa24255c73b3ad916954e8a1704792ce39071`.
- RATE's R1 provider is the earlier NV12 candidate `89430972…`, not either
  full hash in the table above. The cadence owner decision expressly accepts
  that measurement; it does not establish whole-release artifact identity.
- H7-ROCK uses Radxa ELF
  `0b455344259c37fec821955e2de85bb5f76a34e69682217b514c407d8a35c6c3`, not R1.

## Row-by-row verdict

**Discharged** means the named, bounded obligation is evidenced. Candidate-only
passes are retained as such; they do not bypass row 19's release-identity gate.
**Remaining** means evidence or an explicit acceptance disposition is missing.
**Superseded-by-owner-decision** identifies a replaced requirement, not a claim
that the old test passed.

| # | Item 47 obligation | Status | Evidence and exact boundary |
|---|---|---|---|
| 1 | Blocking analyzer, scoped werror, host sanitizers, unit/goldens/UAPI and summary | Discharged | CI15/CI17. Final post-sync native suites 47/47 on Bookworm and Trixie, zero skips; analyzer 17 library TUs; 11 baseline ASan/UBSan, six H10 and six TSan tests. Host-shim coverage only. |
| 2 | Matched-debug R0→R1 ABI and public sizes | Discharged under owner-amended removal policy | CI15/CI17; [ABI acceptance](../../docs/R1-ABI-ACCEPTANCE.md). Raw 12→4 after exactly 18 accepted removals, no remaining incompatible-change bit; `rga_info_t=696`, `im_opt_t=304`. Not an empty diff. |
| 3 | LTO behind ABI/dynsym gate | Discharged by rejection | CI15/CI17; [build flags](../../docs/BUILD-FLAGS.md). LTO changes symbol metadata and remains disabled. Selected non-LTO comparison 315→315 is exact metadata equality, not R0→R1 export-count equality. |
| 4 | Two-build reproducibility and package contracts | Discharged within CI | CI15/CI17. Both archives reproduce within the controlled job. This does not reconcile the different local candidate and release archives. |
| 5 | Four-way timing and unpackaged `-mtune` measurement | Discharged; NOT ADOPTED | GB15 numeric tables and timing table below. Rock −5.322%, OPi +3.293%; no qualifying ≥5% gain on both boards. Measurement-only was the original requirement, not a waived optimization. |
| 6 | Literal live-APT install/remove/restoration | Superseded-by-owner-decision | September 16 option B: isolated exact-provider semantics plus disposable-root package proof and real image delivery/activation/restoration. Does not qualify arbitrary live APT upgrades. |
| 7 | Decision-1b part 1: provider identity, pixels, strict warmed fd census and controls | Discharged for measured candidate | OPI semantic controls, ROCK maps/census. Wrong-provider, skipped-submit and real fd-leak checks each reject with exit 1; positives pass. No +1 allowance. Release transfer remains row 19. |
| 8 | H1 disposable-root dependency/ownership/rollback proof | Remaining for released artifacts; candidate PASS | IMAGE H1 logs prove `361ab931…`→R0→same `361ab931…`, clean audit; R0 dev refused against R1 runtime. Released-byte H1 was explicitly not repeated. H2–H4 do not replace that package transaction. |
| 9 | H2 real image delivery on both boards | Discharged | IMAGE signed-rootfs checks and ROCK-OPS/OPI-OPS. Correct board compatibles, unchanged trusted keyring, actual inactive-A RAUC installs, released runtime package installed. Development-signed images, not production image releases. |
| 10 | H3 normal-loader activation and F1 cache identity | Discharged under late owner scope; full Rock capture NOT PASSED | OPI-OPS: real 40-second BRIO capture/PID 802. ROCK-OPS: PID 763 exact released bytes/cache, no override. Owner-directed Rock continuation explicitly accepts activation/F1 without relabelling its failed capture witness. |
| 11 | H4 restore original bytes AND full package state | Discharged on both boards | ROCK-OPS/OPI-OPS package-block and raw dpkg-stanza comparisons, clean audit, genuine A→B rollback. Not mere preservation after a refused install. |
| 12 | G-A R2 factory inventory/registration | Remaining | ROCK reports 9/10 required-present factories: `mppjpegenc` exits 255 with candidate and fresh-registry R0; `mpph264enc` positive exits 0. `mppvp8enc` is separately expected absent. No owner supersession or waiver found for `mppjpegenc`; baseline equality is not a passing inventory. |
| 13 | G-A R3 exact core routing | Discharged for measured providers | ROCK/OPI and GB15: masks 1/2/4 give exactly (1000,0,0)/(0,1000,0)/(0,0,1000). Corrected census passes on the local candidate. No core-routing waiver found or needed. |
| 14 | G-A R4 RGB16 encoder conversion | Discharged, finite smoke | ROCK: 300 RGB16 1920×1080 buffers, process and recovered log scorer exit 0. OPI: explicit plugin `.6` smoke/scorer pass. No registration, endurance or arbitrary-format claim follows. |
| 15 | G-A R5 nine-cell pixels, including full709 | Discharged for local candidate | ROCK/OPI: all nine cells agree with R0; full709 restored to 50.689414 dB. Earlier broken-R1 33.977872 dB remains a real failure, not an expected D24 limit. |
| 16 | G-A R6 full-hour direct-library soak | Discharged numerically for local candidate; orchestration qualification retained | Both real processes and unchanged scorer pass; exact table below. OPI lacks proof of continuous full-hour local lock retention after tool interruption. Neither receipt qualifies the different released ELF. |
| 17 | G-A R7 baseline recovery | Discharged for replacement's stated scope | ROCK/OPI fresh process-local R0 copy positives; actual operational byte/package rollback is separately discharged by row 11, not inferred from temporary-provider cleanup. |
| 18 | H7 R1 4/6/8-thread escalation on both boards | Remaining | GB15 OPi R1 eight-thread 60.169808 s passed; earlier Rock R1 eight-thread failed. H7-ROCK's later 60.169041 s pass is explicitly Radxa-only, other libraries not rerun. No final/released-R1 Rock escalation or transfer authorization located. |
| 19 | Board-tested artifact identity with released archives | Remaining | Candidate/release SHA table above; IMAGE expressly records different ELF bytes. Inherited todo 43 requires matching dry-run hashes, otherwise post-merge G-B rerun. No matching final release G-B record or explicit identity exception found. |
| 20 | D24 fork matrix and exact nonempty expected-FAIL list | Discharged for named measured tuples; final release transfer remains | ROCK local candidate and D24-OPI earlier fixed R1: all 48 submissions/provider quartets complete; six exact expected failures, no new FAIL/FIXED. Latest OPi nine-cell R5 is not a new twelve-cell D24 on final ELF. See row 19. |
| 21 | OPi literal `>60 fps` / Rock source-less HDMI | Superseded-by-owner-decision; replacement measurement discharged | RATE: R0 and R1 each 600 decoded frames/10.010034 s = 59.939856 fps. Rock `NOT-RUN: no source` is an allowed disposition, backed by ENOLINK. Not both-board cadence measurement or an hour of media streaming. |
| 22 | Synthetic 10-bit conversion/PSNR vs receiver-depth observation | Superseded by convergence scope; observation discharged | GB15: Rock no signal/depth unknown; OPi capture NV16 8-bit, wire depth not exported/unknown in that query. Convergence 47 explicitly requires receiver-reported observation only. No Main10, 10-bit preservation or synthetic 10-bit PASS. |
| 23 | Independent review and merge-commit of R1 work | Discharged for code/review/merge record | CI15/CI17 and PRs #15/#17, merge SHAs below. This is not independent approval of this later consolidated acceptance record. |
| 24 | R1 dispatch preflight, publish dry-run identity rehearsal and duplicate-tag negative receipt | Search complete; process deviation recorded, not a historical PASS | No R1 receipts found in retained workflow history, artifacts or local evidence. PUB is live (`dry_run=false`); R0 receipts and image DRY_RUN are not substitutes. [Search scope, omitted rehearsal and bounded impact](../../docs/R1-RECORD-DEVIATIONS.md#row-24--missing-r1-rehearsal-receipts). No dispatch/re-tag performed. |
| 25 | R1 release, four assets, reindex and stable serving | Discharged | PUB/APT: release at `d57bc86…`, both `.deb`/`.sha256` pairs, GitHub/APT byte equality. Publication does not imply row 19 passed. |
| 26 | Final both-board record on the open R1 PR before merge | Post-release record supplied; owner disposition pending | This file supplies the consolidation after merge and release, not on the original open PR. [Late-record deviation](../../docs/R1-RECORD-DEVIATIONS.md#row-26--late-both-board-record) records what the ordering cost and preserves the measurements and their limits. A documentation merge is not owner acceptance of this deviation. |

## Both-board R6 and pixel evidence

| Field | Rock 5B+ | Orange Pi 5+ |
|---|---|---|
| Provider | Local R1 ELF `361ab931…` | Local R1 ELF `361ab931…` |
| Kernel / queried RGA | 7.2.0-ceralive-rk3588 / 1.3.11 | 7.2.0-ceralive-rk3588 / 1.3.11 |
| Provenance limit | Live module build ID matched retained island v2026.9.4 receipt | This lane did not establish exact island source tag; not inferred from 1.3.11 |
| Workload | Synthetic 3840×2160 NV16→NV12, real DMA-BUF/RGA | Same |
| UTC interval, September 16 | 20:21:34–21:21:34 | 19:11:45–20:11:45 |
| Monotonic seconds | **3600.009368** | **3600.007046** |
| Completed iterations | **138,945** | **140,407** |
| PSNR of every iteration | **66.378836 dB** | **66.378836 dB** |
| Strict warmed fds | **8→8** | **8→8** |
| Bench / recovered scorer | **0 / 0** | **0 / 0** |
| Core0 task delta | 138,945 | 140,407 |

The eight descriptors include two identified loader-log handles. Plain controls
remain 6→6; a real added descriptor gives 6→7 and rejection. Both sessions are
warmed; counts need not match R0's five absolute descriptors. No normalization
or leak tolerance was introduced.

OPI's board supervisor completed the hour after the local tool hit its 120-second
bound. The raw receipt survived and independently retrieved copies matched
SHA-256 `06999c968a5c00354f2063390a2cc65a07c1421262c5abcbc41e814d9ffc48c3`.
The missing local `drill.exit`, full-hour lock-retention proof and periodic-copy
completion are **not** retroactively supplied by scoring that receipt. A later
ordinary lock/cleanup succeeded. Rock's collection qualification is different and
must not inherit the OPi interruption. No endurance stream/fps or silicon-sanitizer
claim follows from either synthetic run.

| R5 cell | Rock candidate and same-session R0 | OPi candidate and same-session R0 |
|---|---:|---:|
| NV16→NV12 | 61.607624 | 61.607624 |
| BGR→NV12 / explicit 601 limited | 52.776426 | 52.776426 |
| Scale 4K→1080p | 59.677191 | 59.677191 |
| Crop | infinity | infinity |
| Rotate 90 | infinity | infinity |
| Explicit 601 full | 53.468170 | 53.468170 |
| Explicit 709 limited | 52.904279 | 52.904279 |
| Explicit 709 full | 50.689414 | 50.689414 |

## D24 — keep thresholds, tuples and corpora separate

These are the six failures in the fresh twelve-cell matrix at the unchanged
**40 dB worst-plane** floor. All conversions exit 0; successful submission is
not the numerical verdict. Each board's four-provider comparison has identical
outputs per cell, but OPi and Rock used the distinct fixed-R1 providers above.

| Expected-FAIL ID | Fresh worst-plane dB | Reason |
|---|---:|---|
| csc-BGR-to-NV12 | 38.529219 | CSC/chroma-decimation difference |
| scale-NV12-to-NV16 | 39.706076 | Chroma resampling |
| scale-NV16-to-NV12 | 39.706076 | Chroma resampling |
| scale-BGR-to-NV12 | 38.275697 | CSC and chroma resampling |
| crop-BGR-to-NV12 | 34.295946 | CSC and chroma resampling |
| rotate-BGR-to-NV12 | 33.787360 | CSC and chroma resampling |

The other six pass; `FIXED=[]`, `newFAIL=[]`. Exact-list controls reject an empty
or shortened list, missing/duplicate cells, NaN, new FAIL and a simulated FIXED.
BT.709 references remain report-only. The G-A 30 dB floor is not substituted.

ROCK recovered all 24 September 10 historical output/reference files and rescored
them to the historical values. Its `HISTORICAL-CORPUS.md` preserves their hashes.
The original transient input files were not archived; bit-identical original-source
replay remains **unproven**, especially BGR. The new measurements use the separately
identified retained September 15 regenerated corpus. This is a reproducibility
limit, not another library failure or permission to erase the six expected IDs.
The governing same-session D24 comparison does not add a new requirement to
reconstruct source files that were never saved.

## Timing — measured, not adopted

GB15 ran three repeats of 2,000 conversions per build per board. Values below
are medians of repeat medians, in microseconds per frame.

| Build | Rock total | Rock userspace estimate | OPi total | OPi userspace estimate |
|---|---:|---:|---:|---:|
| Radxa | 6418.139 | 29.167 | 6709.566 | 27.708 |
| R0 | 6443.078 | 29.168 | 6676.170 | 28.000 |
| R1 packaged comparison | 6418.285 | 30.334 | 6723.419 | 26.249 |
| Matched generic O2, unpackaged | 6876.651 | 27.417 | 6685.211 | 26.541 |
| Cortex-A76, unpackaged | 6440.014 | 28.876 | 6720.212 | 25.667 |

Matched userspace change: Rock **−5.322%**, OPi **+3.293%** (positive is faster).
Neither establishes the qualifying gain on both boards. Instrumentation and
normal scheduling are included; these are not CPU-cycle measurements. The tuning
variant was not packaged. No later adoption or missing optimization is implied.

## Released-byte operational acceptance and restoration

IMAGE's corrected board-specific signed payloads contain released R1, not the
earlier local build. Real dpkg unpack/configure happened in the image build.
Both host builds report nine stages and parity 20/0/0. The unchanged installed
NON-PRODUCTION signing chain was verified; no trust bypass or trust rotation.

| Artifact | SHA-256 |
|---|---|
| Rock bundle, `20260916T220912Z.raucb` | `ab4daf9a3913297e84e76504eeb45f4837b3e9ae6cb9a4b747b4eb5d6943c6b8` |
| OPi bundle, `20260916T223021Z.raucb` | `6f67220f0a1bfcd5e1211e0df754fe1befbb55115301720e6775ba685dbdc7dc` |
| Rock signed rootfs payload | `f3be204395cb3c67f0bcd10e15c240129c699c822095a3bcd0ad29e915f75a40` |
| OPi signed rootfs payload | `b2e2aad788490bed5679c97c21da314415e3d3c12b922216c15687df8c8c9a9d` |

| Observation | Rock | OPi |
|---|---|---|
| H2 | Verified inactive-A install, transaction `962dd8f7-bce4-48b4-83f8-0e6d2c02233e` | Verified inactive-A install, transaction `9e183d4b-f96a-4222-badc-8d281b6a931e` |
| Live consumer | cerastream PID 763 | cerastream PID 802 during genuine capture |
| Maps device / inode | `b3:62` / `133359` | `b3:02` / `133359` |
| Hash through consumer root | Released `07b6b6c4…1cb6b74` | Same released full digest |
| F1 | Cache alias matches mapped device/inode/hash | Same; R0 explicitly not loaded |
| Loader overrides / refresh | No `LD_*`, preload or cache refresh | No `LD_*`, preload or cache refresh |
| Capture witness | **NOT PASSED: no usable camera/source; HDMI ENOLINK** | BRIO `/dev/video1`, 40 s, 317 binary messages / 7,108,144 bytes, no preview error |
| H4 | Genuine rollback to original R0 bytes and complete dpkg state | Same, including independent raw status stanza |
| Final measured state | September 17 00:07:18Z, B selected/booted/good; A good; 3/3 | September 17 00:25Z, B selected/booted/good; A good; 3/3 |

**Rock's capture limitation is a board-capability limit, not an R1 defect.** Its
earlier preview returned `pipeline-failed` with zero media; that reply alone does
not diagnose a library failure. GB15 records the source query's ENOLINK. The late
owner-directed continuation explicitly states: “This PASS is the owner's current
H3 activation criterion, not a new preview/PiP functional claim.” Consequently
normal-loader activation/F1 is discharged, while full capture H3 is honestly
not claimed. It is not an extra Rock-capture blocker under that accepted scope.

Both H4 comparisons include original ELF, SONAME link, version, full package
stanza, ownership, complete file list and empty audit. The two intentionally
omitted documentation files remain explicit; non-doc integrity is clean. CeraUI
Start SSH after slot reboot was the missing procedure step, not a reason to
enable SSH fleet-wide. These are last recorded states, not fresh board probes.

## Review, release and serving

- [PR #15](https://github.com/CERALIVE/librga/pull/15): independently approved,
  merge `31493bd68cd8ff8995386a77c498e33c8f61e318`.
- [PR #17](https://github.com/CERALIVE/librga/pull/17): independent recovery review,
  main merged into topic without rebase; final topic `c414c3d9d60cca87443573c570132674ffead80a`,
  merge `d57bc86e65b331948953442449618cadd3b0c7bc`. Exact post-sync CI is CI17.
- [R1 release](https://github.com/CERALIVE/librga/releases/tag/1.10.5%2Bceralive.1):
  published September 16 22:02:05Z from that main commit, with exactly runtime
  `.deb` + `.sha256` and development `.deb` + `.sha256`.
- [Publish/reindex job](https://github.com/CERALIVE/librga/actions/runs/35155428515/job/104994035068)
  and PUB log record dispatch/publication. APT independently confirms both
  stable-arm64 stanzas and GitHub/APT byte equality at the release digests above.
  Runtime is 84,552 bytes; development is 24,684 bytes.

The 2026-09-17 read-only receipt search found no R1-specific dispatch-preflight,
publish `dry_run=true` identity rehearsal or existing-tag rejection receipt.
The [deviation record](../../docs/R1-RECORD-DEVIATIONS.md) enumerates the retained
history and local evidence scope, the omitted rehearsal and its limits. The
located R0 runs `34735326263` and `34735383567` are not R1 evidence. A live
publish (`dry_run=false`) and image-pipeline DRY_RUN cannot supply those receipts.
This process gap does not invalidate the independently established serving,
GitHub/APT byte equality or normal-loader capture observations. It also does
not discharge row 19's separate candidate-to-release identity requirement.

## What remains before a defensible item-47 closure

1. Resolve **released-artifact qualification**. The explicit identity condition
   failed; the released ELF is not the R6/H1-tested ELF. Locate a matching
   released-byte record or obtain an owner disposition of the required rerun.
   A rerun would need the full applicable G-B scope, including R6 on both boards,
   final-provider D24 (OPi currently has an older fixed provider), controls and
   proved ownership. Separately qualify H1 with the actual released package pair,
   or obtain a specific amendment. No rerun is authorized by this report.
2. Resolve **Rock R1 H7**, not Radxa H7: retain the real fixed-kernel Radxa PASS,
   but obtain the required R1 4/6/8 result or an explicit acceptance amendment.
3. Resolve **R2 `mppjpegenc` inventory**: correct the hardware-conditional
   expectation with owner approval, or supply the required inventory proof.
   Its same-baseline absence establishes no R1 regression, not a waiver.
4. Owner disposition of the recorded **R1 preflight/dry-run/duplicate-tag QA**
   process gap and **late report/pre-release-order deviation** remains pending.
   The receipt search and post-release consolidation are now documented in
   [R1 record deviations](../../docs/R1-RECORD-DEVIATIONS.md); neither records a
   historical PASS. Do not fabricate a run, re-tag R1, or treat this post-release
   document as having been on the original open PR.

No additional tuning adoption, synthetic Main10 test, Rock HDMI source, original
BGR input reconstruction or arbitrary live-APT upgrade is silently added to the
remaining work. The measured successes above stand; they simply do not justify
a blanket both-boards-green release-qualification claim.
