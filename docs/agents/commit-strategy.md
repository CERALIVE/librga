<!-- Moved verbatim from AGENTS.md on 2026-10-05 by lean-rules-docs-landing-latam -->

## Commit strategy

Three tiers, exactly as in `gstreamer-rockchip`, and for the same reason:
provenance and reviewability survive only if the first two tiers keep their own
commits.

1. **Tier (a), ported upstream or donor fixes.** Clean ports use
   `git cherry-pick -x`, preserving the original Author, message, and the
   `(cherry picked from commit …)` line the flag writes. Adapted ports carry the
   adapter's authorship and credit the original owner plus the full source SHA in
   the message body. **Never squashed, in either form.**
2. **Tier (b), first-party bug fixes.** One commit per defect, titled for the
   mechanism rather than implementation trivia. **Never squashed.**
3. **Tier (c), CI, packaging, docs, and mechanical work.** These may be squashed
   under the normal CeraLive Rule C convention.

Merge method follows from that. A PR carrying tier-(a) or tier-(b) history merges
with **Create a merge commit** or **Rebase and merge** — **never squash**, because
a squash collapses the whole PR into one new commit and destroys the per-fix
history those tiers exist to keep. The same rule covers upstream-sync PRs: a
squash discards the second parent, the merge-base stops advancing, and every
later sync replays already-merged commits as phantom conflicts.

`integration/1.10.5-ceralive.1` is integrated by **merge, never rebase**. It carries
eight two-parent Wave-D investigation merges; rebasing linearizes that history
and replays conflicts in `tests/shim/contract.c` and `tests/shim/fake_rga.c` that
were already resolved by union. Do not apply the generic pre-work rebase rule to
this branch. The fix-audit structural repair is authorized directly on
`0011d44f074508dd5d8533a77496a593211b9e85`, without any pre-work branch sync.

No commit in this repository may carry a `Co-authored-by:` trailer or any AI or
tool attribution. Such trailers are **forbidden**. A clean cherry-pick's
preserved upstream Author field and its `-x` provenance line are not trailers;
they are the record of where the change came from, and they stay.

Remotes: `origin` is `CERALIVE/librga` and nothing else. There is never a remote
literally named `upstream`. When a source comparison against JeffyCN is genuinely
needed, add a transient remote named `jeffycn`, fetch an explicit refspec, verify
the fetched SHA against the pin, and remove the remote **before** any push or PR.

