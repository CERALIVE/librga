# R1 record deviations — 2026-09-17 [PARTIAL]

This is a **post-release record**, not pre-release approval. It addresses rows
24 and 26 of the [R1 both-board report](../tests/board/DRILL-RESULTS.md), carrying
convergence item 47 and inherited librga todos 41–43. The plan requires the board
summary in this repository at `tests/board/DRILL-RESULTS.md` and requires it on
the open R1 PR before merge. No acceptance criterion or plan checkbox changes.

## Row 24 — R1 redo receipts

**Finding:** the previously stale row-24 status is corrected by POST-REDO receipts
produced on 2026-09-17. The required sequence was executed after the R1 release
was deleted and re-published: an existing-tag negative, a successful publish
dry-run, dispatch preflight, a second successful pre-publication dry-run, and a
live publication attempt. The first live publication failed at the qualification
gate because the Rock receipt did not yet exist; PR #22 then committed the real
receipts and the retry succeeded. This establishes post-redo execution, not
historical pre-release compliance for the original R1 release.

### Post-redo receipt verification

The retained GitHub workflow runs and final release state were re-verified on
2026-09-17 UTC:

- `publish-release.yml` and `dispatch-preflight.yml` run metadata and failed
  logs, including the qualification-gate failure and the successful retry.
- The restored release's tag, four assets and asset digests.
- PR #22, which committed the two board qualification receipts required by the
  release gate.

| UTC start | Run | Observed execution | Relevance |
|---|---|---|---|
| 2026-09-17 21:09:55 | [35275108125](https://github.com/CERALIVE/librga/actions/runs/35275108125) | Non-dry-run publish against the existing tag, failed by design at the existing-tag guard | Duplicate-tag negative receipt |
| 2026-09-17 21:10:31 | [35275168751](https://github.com/CERALIVE/librga/actions/runs/35275168751) | Publish `dry_run=true`, success | Post-redo identity rehearsal |
| 2026-09-17 21:13:17 | [35275427000](https://github.com/CERALIVE/librga/actions/runs/35275427000) | Dispatch preflight, success | Cross-repository dispatch preflight |
| 2026-09-17 21:13:36 | [35275456552](https://github.com/CERALIVE/librga/actions/runs/35275456552) | Publish `dry_run=true`, success; live publish job skipped | Pre-publication ordering rehearsal |
| 2026-09-17 21:15:50 | [35275669851](https://github.com/CERALIVE/librga/actions/runs/35275669851) | First live publish attempt, failed at `ci/check-release-qualification.sh`: missing `rock-5b-plus.sha256` | Failed honestly before receipts existed |
| 2026-09-17 21:27:52 | [35276804263](https://github.com/CERALIVE/librga/actions/runs/35276804263) | Retried live publish after PR #22 committed both receipts, success | R1 restored |

PR #22 merged the real qualification receipts before the successful retry. The
restored release has exactly the runtime/development `.deb` files and their two
`.sha256` sidecars. The first live attempt is retained as a failed attempt, not
omitted from the sequence.

The final release verification records tag target
`d57bc86e65b331948953442449618cadd3b0c7bc`, runtime package SHA-256
`5f8ea1f259b95d5bf6fbe68edf03bf08820ab7bc8d4d17bfc1fc4a00344c7bb3`, and
development package SHA-256
`8dd35334ed1022ff8e64a86b3ac426abb847bf36f3ccff2746a658ccc0d8577a`.

These are post-redo receipts. They do not backdate the sequence into the original
open R1 PR or change the separate row-26 disposition.

### What the post-redo sequence proves

| R1 step/receipt | Intended assurance | What the post-redo record establishes |
|---|---|---|
| Dispatch preflight | Cross-repository token/API path works before attempting live publication | Run `35275427000` passed before the post-redo publication sequence continued |
| Publish dry-run identity rehearsal | Rehearse R1 branch/version, build and install-smoke path without publishing | Runs `35275168751` and `35275456552` passed; the latter was the pre-publication ordering rehearsal |
| Existing-tag negative QA | A dispatch using the same valid version inputs refuses an already-existing tag, rather than overwriting/re-publishing it | Run `35275108125` refused the existing tag as designed |
| Live publication and retry | Require the release gate to accept the exact board-qualified bytes | Run `35275669851` failed because the Rock receipt was not yet present; after PR #22 committed the receipts, run `35276804263` passed and restored R1 |


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
