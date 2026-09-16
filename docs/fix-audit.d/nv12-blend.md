## NV12 blend background classification — 2026-09-16

| Provenance SHA | Reproducer (path · RED · GREEN) | Hardware gate | ABI closure (nm vs R0 · abidiff vs previous release) | Independent reviewer verdict · reviewer session id | `Upstream-status` |
|---|---|---|---|---|---|
| status=GREEN fix=8b55be8; inherited `fc3f742` ordering retained; two namespace predicates corrected to RGB classification | `tests/unit/unit_blend.cpp`: R0 RED 4 positive failures, original R1 RED 3 negative failures, fixed GREEN 11/11; restored wrong ordering RED 4 positive failures | OPi-B finite NV12+BGRA→NV12 decoded inset; 65 frames; primary-EOS exit1 remains; no endurance/teardown/release pass | public headers and assertions unchanged; matched arm64 ABI exact18-removal policy passes; selected non-LTO315/315 dynsym tuples equal; LTO remains rejected | author=Sisyphus-Junior/openai/gpt-6-astra reviewer=codebase-search-specialist/openai/gpt-5.6-luna verdict=APPROVE ses_f57498fe2ffeb1017KoSF1qtKy | first-party classifier fix; ordering already fixed upstream by `fc3f742` |

The validator and board receipt (`docs/NV12-BLEND.md`) separates the R0 rejection
from R1's false acceptance, documents the unchanged background API restriction,
and retains the unaltered decoded inset. The review approves `8fcf447..00974ff`,
not the unrelated prerequisite range displayed by stale integration base5214fff.
PR13 is draft; integration-base synchronization needs separate authorization.
The session identifier above comes from the tool's session metadata, not the
reviewer's descriptive label. Model identity is the reviewer's reported model.
