# R1 record deviations — 2026-09-17 [PARTIAL]

This is a **post-release record**, not pre-release approval. It addresses rows
24 and 26 of the [R1 both-board report](../tests/board/DRILL-RESULTS.md), carrying
convergence item 47 and inherited librga todos 41–43. The plan requires the board
summary in this repository at `tests/board/DRILL-RESULTS.md` and requires it on
the open R1 PR before merge. No acceptance criterion or plan checkbox changes.

## Row 24 — missing R1 rehearsal receipts

**Finding:** no R1 dispatch-preflight, publish `dry_run=true` identity rehearsal,
or existing-tag negative receipt was found. The retained sequence went from R1
merge to live publication without a recorded R1 rehearsal. Record that as an
omitted R1 rehearsal/process gap, not as a successful test and not as proof that
an unretained execution could never have occurred.

### Search performed

Read-only search on 2026-09-17 UTC covered:

- GitHub's retained histories for `dispatch-preflight.yml` and
  `publish-release.yml`, including run jobs, available logs/metadata, artifact
  listings, workflow definitions, release assets, tags and PRs #15/#17 with
  their review/comment history. Paginated workflow-run API queries with
  `per_page=100` returned `total_count=1` and `total_count=3`, respectively;
  the complete returned inventory is below. The workflow list was also checked.
- The local evidence tree and librga-related scratch/worktrees: item-47 results,
  R1 readiness/recovery/build-gate evidence, review artifacts, R1 release and
  image evidence, task-48 package assets, and task-51 APT-serving evidence.
  Searches used R1/version identifiers, `preflight`, `dry_run`, dry-run,
  duplicate/existing-tag rejection terms and the known R0/R1 run IDs. Local
  host locations are indexed in the workspace notepad, not repository path
  dependencies. No credentials or unrelated private contents are reproduced.

| UTC start | Run | Observed execution | Relevance |
|---|---|---|---|
| 2026-09-13 03:22:36 | [34735326263](https://github.com/CERALIVE/librga/actions/runs/34735326263) | Dispatch preflight, `release/1.10.1`, success | R0 preflight only |
| 2026-09-13 03:24:03 | [34735383567](https://github.com/CERALIVE/librga/actions/runs/34735383567) | Publish dry-run, `release/1.10.1`, success; publish job skipped | R0 rehearsal only |
| 2026-09-13 03:28:05 | [34735552582](https://github.com/CERALIVE/librga/actions/runs/34735552582) | Live R0 publish, success; dry-run job skipped | Not an R1 rehearsal |
| 2026-09-16 22:00:29 | [35155428515](https://github.com/CERALIVE/librga/actions/runs/35155428515) | Live R1 publish from `main`, success; dry-run job skipped | `dry_run=false`, not the missing rehearsal |

The R1 run retained a `release-assets` artifact and the release has exactly
the runtime/development `.deb` files and their two `.sha256` sidecars. Those
are live-release artifacts, not extra preflight or negative-test receipts.
All four listed runs succeeded; none records an existing-tag rejection.
The workflow's existing-tag guard is source code, not proof its rejection path
was exercised for R1.

Local lookalikes were rejected as substitutes: image-builder DRY_RUN tests a
different pipeline; controlled two-build reproducibility is not a publish
identity rehearsal; task-48's stale-checksum rejection is not duplicate-tag QA.
R0's preflight/rehearsal is evidence for R0, not a per-release R1 receipt.

**Search limit:** retained GitHub and local evidence cannot establish the absence
of deleted runs, deleted logs/artifacts or unretained executions. No R1 receipt
was recovered; no historical execution is asserted on the strength of a script
or the successful live release. Nothing was re-dispatched, re-tagged or
re-released to manufacture a receipt, and no board was contacted for this record.

### What was omitted, and what it would have proved

| Missing R1 step/receipt | Intended assurance | What the actual record establishes instead |
|---|---|---|
| Dispatch preflight | Cross-repository token/API path works before attempting live publication | R1 live publication subsequently dispatched reindex and the release is served; the separate pre-publication check is not recorded |
| Publish dry-run identity rehearsal | Rehearse R1 branch/version, build and install-smoke path without publishing; compare its asset hashes to board-tested PR artifacts before deciding whether G-B must be repeated | The live run built/published R1 and ran install-smoke; no R1 dry-run comparison or pre-publication identity decision is evidenced |
| Existing-tag negative QA | A dispatch using the same valid version inputs refuses an already-existing tag, rather than overwriting/re-publishing it | The guard exists, but no R1 rejection execution receipt was found; successful first publication does not exercise it |

The duplicate-tag negative scenario was a separate QA obligation, not evidence
that could have existed before the tag's first creation. The release was cut
without the recorded R1 rehearsal R0 had, and the later negative QA receipt is
also absent. These are process omissions; neither a retrospective successful
test nor this document can turn them into historical compliance.

### Bounded impact on the shipped release

The gap removes advance evidence for dispatch readiness, publish rehearsal and
artifact-identity review, and leaves the R1 duplicate-tag rejection path without
an execution receipt. It is not evidence that the shipped package is wrong.
Independently retained observations remain valid:

- Both R1 packages are served on the stable arm64 index. The saved
  `librga-r1-image-evidence` serving receipt records independently computed
  GitHub/APT hashes and `cmp` equality for both packages; the full hashes remain
  in the [artifact table](../tests/board/DRILL-RESULTS.md#artifact-identities--do-not-merge-these-columns).
- The `task-51-apt-serving-20260917T003028Z` collection retains
  `r1-blend-disassembly.txt` and `r0-blend-disassembly.txt`, from extracted APT
  payloads. Inside `_Z15rga_check_blend12rga_buffer_tS_S_ii`, calls
  `bl <_Z13is_rgb_formati@plt>` occur **2× in R1 and 0× in R0**. The R1 calls
  are at `0x1c3e0` and `0x1c3ec`. This is a content discriminator, not a full
  functional qualification or proof of every fix.
- Released ELF SHA-256
  `07b6b6c466c6bddbcf7006e5b678d68de372b44686e6eb8ea3fcf00ce1cb6b74`
  was verified loading in the normal consumer during the real **40-second OPi
  BRIO capture** (PID 802), without loader overrides. The
  [operational record](../tests/board/DRILL-RESULTS.md#released-byte-operational-acceptance-and-restoration)
  preserves maps/cache identity, capture output and subsequent rollback.

Those facts are not put in doubt by the missing rehearsal receipts. What remains
unproven is the omitted process assurance and, separately, transfer of earlier
candidate-byte qualification to the different released bytes (report row 19).
The capture is not a released-byte full G-B soak, D24 matrix or H1 package
transaction. This record neither closes nor enlarges those separate gaps.

## Row 26 — late both-board record

**Required order:** both-board record → review → merge → release.

**Actual order:** merge → release → record. Code review did occur, but without
the required final consolidated both-board record on the open R1 PR.

- [PR #15](https://github.com/CERALIVE/librga/pull/15) merged at
  **2026-09-16 18:16:51 UTC**, merge
  `31493bd68cd8ff8995386a77c498e33c8f61e318`.
- [PR #17](https://github.com/CERALIVE/librga/pull/17) merged at
  **2026-09-16 18:39:43 UTC**, merge
  `d57bc86e65b331948953442449618cadd3b0c7bc`, the released source.
- [R1](https://github.com/CERALIVE/librga/releases/tag/1.10.5%2Bceralive.1)
  was published at **2026-09-16 22:02:05 UTC**.
- The row-by-row report was assembled **after release**, on September 17 UTC,
  and is introduced by a separate post-release documentation PR. It was absent
  from the checked-out release/main tree. Its new commit and review cannot be
  backdated into either already-merged R1 PR.

**What this cost:** the original reviewers and release decision did not have
the required consolidated, committed both-board matrix in front of them at
the prescribed gate. That removed the planned opportunity to assess all results,
artifact boundaries and outstanding rows together before merge/release. A later
review can scrutinize this record but cannot restore that opportunity.

**What it did not cost:** this reporting deviation did not mean that the soaks,
D24, isolation or H1–H4 measurements were skipped. They ran and the report
preserves their actual dates, providers, results and limits. They did **not**
all run before merge: for example, the September 16 R6 intervals are
19:11:45–20:11:45 UTC on OPi and 20:21:34–21:21:34 UTC on Rock; released-byte
operational observations/restoration extend into September 17. H1 used candidate
packages; H2–H4 used released bytes. The report is not a claim that every required
measurement passed, that every measured artifact was the release artifact, or
that Rock completed a capture. The missing consolidation and ordering remain
real even though measurements exist.

## Owner decision — pending, not inferred from this PR

The records are supplied; their acceptance disposition is not.

The owner must decide **whether to accept the row-24 process gap and row-26
late-record deviation for item-47 closure, or keep either outstanding with an
explicitly stated follow-up requirement**. These are separable decisions. No
choice is made or recommended by this record. Merging this documentation
publishes the facts; it does not accept a deviation, waive a criterion, tick a
plan checkbox or declare item 47 complete. Separate measurement/qualification
rows retain their existing dispositions and are outside this record-keeping PR.
