# R1 record deviations — 2026-09-17 [Discharged by remediation]

This is a **post-release record**, not pre-release approval. It addresses rows
24 and 26 of the [R1 both-board report](../tests/board/DRILL-RESULTS.md), carrying
convergence item 47 and inherited librga todos 41–43. The plan requires the board
summary in this repository at `tests/board/DRILL-RESULTS.md` and requires it on
the open R1 PR before merge. No acceptance criterion or plan checkbox changes.

## Row 24 — R1 redo receipts

**Disposition: Discharged by remediation.** PR #23 supplied the post-redo
receipts below. The recurrence gate now requires that evidence rather than
treating a live publish as a rehearsal. Original chronology is not rewritten.

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

The original gap removed advance evidence for dispatch readiness, publish rehearsal
and artifact-identity review. The post-redo sequence supplies the missing execution
receipts, including duplicate-tag rejection, without backdating them. The omission
is not evidence that the shipped package is wrong.
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

Those facts are not put in doubt by the original missing rehearsal receipts.
The capture alone is not a released-byte full G-B soak, D24 matrix or H1 package
transaction. Rows 8, 18 and 19 now cite their separate released-byte rerun;
this process remediation neither substitutes for nor enlarges that evidence.

## Row 26 — late both-board record

**Disposition: Discharged by remediation.** The consolidated record is now
committed and presented for review with an executable recurrence gate. It requires
the complete matrix, both matching board receipts and verified R1 rehearsals on
PRs (including documentation-only changes), before a live release build, and again
before publication. Missing/unreadable evidence is failure. These concrete repairs
discharge the outstanding record obligation without making the original order
compliant. No owner acceptance or waiver is claimed.

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

## Recurrence gate and discharge basis

`ci/check-release-record.sh` requires this receipt table, the complete 26-row
`tests/board/DRILL-RESULTS.md`, and both versioned three-line qualification
receipts matching its **released**, not candidate, artifact column. The table's
`Relevance` keys `Duplicate-tag negative receipt`, `Cross-repository dispatch
preflight` and `Pre-publication ordering rehearsal` are machine-consumed keys:
exactly one linked run is required for each.

The checker reads the real GitHub runs, requires completed dispatches of the
expected workflows/results, and reads `packaging/version` at each source commit.
Preflight and dry run must name the intended release; the duplicate-tag control
may name an already-released version, because requiring a new tag to exist before
its first publication would deadlock the release path. The negative needs that
source version's actual existing-tag error log, not merely failure; the
dry-run report must succeed while live publication is skipped. Negative and
preflight must finish before the final rehearsal. Missing/empty/unreadable files,
API metadata or logs, malformed identities and mismatched versions fail closed.
Read-only `actions: read` access is required; log expiry blocks rather than skips.

`ci/check-release-qualification.sh --records-only` performs this preflight without
a package payload. The no-argument publication invocation also retains the exact
downloaded-archive/ELF comparison. `publish-release.yml` consults the preflight
before a **live** build and the full gate before release creation. Dry runs still
produce candidates without this prerequisite. `build-check.yml` runs the mutation
suite and real preflight inside `changes`, which the required summary depends on,
even for documentation-only PRs. Administrators must retain branch protection;
publishing outside the workflow is outside this gate's authority.

Non-vacuity uses the same new checker against untouched Git snapshots: `674d879`
(PR #22 merged, before PR #23) rejects with `missing/duplicate/malformed
Duplicate-tag negative receipt`; `04acb47` (PR #23 merged) passes against actual
GitHub evidence. The checker does not require these new disposition paragraphs.
`tests/board/test-release-record.sh` additionally removes each document, board
receipt and required run, corrupts the released column, simulates unreadable API
evidence, substitutes a wrong failure/workflow or live publish, and reverses the
rehearsal ordering. The real release entry must exit 1; restoration must exit 0.

The standing rule applies literally: **rejecting or remediating a deviation needs
no owner acceptance; accepting one would.** Neither row is owner-accepted, waived
or deferred. Historical lateness remains recorded; no run is fabricated, artifact
changed or plan checkbox ticked. The check proves documentary completeness, run
provenance and artifact identity, not cryptographic board attestation, approval of
every disposition, or new measurements. Installation alone proves neither
`ldconfig` execution nor normal-loader use of R1; those claims retain their own
maps/cache and consumer evidence.
