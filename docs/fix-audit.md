# Fix audit

The per-fix evidence ledger for this fork. One row per landed fix, no exceptions.
A fix with no row here is a fix with no evidence, and a row with a missing field is
recorded as a gap rather than rounded up to a pass.

The table below is **empty on purpose**: no fix has landed yet. Rows are appended
by the fix todos, each writing its own fragment, and the coordinator wires them in.

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

## R0 candidate acceptance

This is a release-candidate review record, not a library-fix row. The
owner-approved [R0 amendment](R0-NEUTRALITY.md) is the acceptance contract;
the rejected literal contract and its raw failures remain unchanged.

The reviewed runtime package SHA-256 is
`7c59bade43e2f8bb4c31e0ae965bee480128aa128528fdc88e8bc082e98ec498`;
the re-extracted library SHA-256 is
`adf9e34934497092c30ba2ec3cf45141e058c368991d77524d9c0e38f5e29fc6`.
Publication must reproduce this package or obtain new both-board evidence.

| Provenance SHA | Reproducer and executed controls | Hardware gate | ABI closure and limits | Independent reviewer verdict · reviewer session id | `Upstream-status` |
|---|---|---|---|---|---|
| `037e208e4cd79b49172a53bfba722fac577bfed9` | [Amended acceptance procedure](R0-AMENDMENT-CHECK.md) rerun verbatim: 254/254 global deletions and 495/495 non-padding byte mutations rejected; 9/9 padding-only mutations accepted; named-byte and request-length controls rejected. Freshly compiled poison diagnostic returns 1 on both packaged libraries. Raw G8 remains FAIL. | [G-A receipt](https://github.com/CERALIVE/librga/pull/2#issuecomment-5649766546): R1–R7 PASS on Rock 5B+ and Orange Pi 5+ for the exact package; no hardware rerun by this reviewer. Equal finite PSNR scores are not byte-identical image proof. No hardware sanitizer claim. | Radxa GLOBAL floor 254/254, including GLOBAL binding. Unfiltered containment remains FAIL for the three enumerated weak map helpers; historical `abidiff` FAIL preserved, not rerun or promoted to a type-ABI pass. No R1 exemption. | **APPROVE under the amended contract** · `ses_f677dc1b2ffeX5gh5fNM7YkXqp` · [independent review receipt](https://github.com/CERALIVE/librga/pull/2#issuecomment-5650165812). Formal approval refused because the token account authored the PR; verdict posted as the owner-authorized comment fallback. | Not applicable: R0 packaging/CI candidate and acceptance documentation; no library-source fix. |

## Rows

| Provenance SHA | Reproducer (path · RED · GREEN) | Hardware gate | ABI closure (nm vs R0 · abidiff vs previous release) | Independent reviewer verdict · reviewer session id | `Upstream-status` |
|---|---|---|---|---|---|
