<!-- Moved verbatim from AGENTS.md on 2026-10-05 by lean-rules-docs-landing-latam -->

## PR-TARGETING

Every PR targets `CERALIVE/librga`, never the fork parent:

```bash
gh pr create --repo CERALIVE/librga --base main
```

Release PRs target their release branch instead (`--base release/1.10.1` for R0),
but the repository argument never changes. Before handoff, confirm the PR URL
starts with `https://github.com/CERALIVE/librga/`.

A PR carrying tier-(a) or tier-(b) commits is **never self-merged**. An
independent reviewer — a different agent and a different model from the author,
dispatched by the orchestrator — confirms the evidence and the merge method
first, and the reviewer's session id is written into the `docs/fix-audit.md` row.
A missing id is recorded as a gap, never explained away.

