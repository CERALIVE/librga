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

## Rows

| Provenance SHA | Reproducer (path · RED · GREEN) | Hardware gate | ABI closure (nm vs R0 · abidiff vs previous release) | Independent reviewer verdict · reviewer session id | `Upstream-status` |
|---|---|---|---|---|---|
