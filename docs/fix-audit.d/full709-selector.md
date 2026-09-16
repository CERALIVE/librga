| status=GREEN fix=9ddd7d8; first-party repair of upstream `2aa0ab4d8374d630bed628f8fb6dead9076eae7c` | `tests/repro/donor_full_csc.c`: RED on `099ee2d4` (full709 8 instead of 0; combined 10 instead of 2), GREEN after fix; unchanged RGB/BGR 601/limited709 and legacy donor controls; `docs/full709-selector-evidence.tar.xz` retains transcripts and selector-only pixel evidence | Isolated OPi only: unchanged retained R1/client/buffers, 8→0→8→0 gives 33.977872→50.689414→33.977872→50.689414 dB; reverse fixed-library control agrees; RGA2 delta 0/0/1 each; sanitizers host-shim-only | No coefficient, default, public-layout, visibility or SONAME change; scoped werror, analyzer, package contract and ABI floors pass; no G-B or R1-release approval | author=Sisyphus-Junior/openai/gpt-6-astra reviewer=explore/openai/gpt-5.6-luna verdict=APPROVE ses_f59ddb8a5ffeoojhlQh42r9NWq | First-party selector assignment; upstream regression, not donor-port defect |

# Full709 ordinary selector — independently reviewed

The first-party repair of upstream `2aa0ab4d8374d630bed628f8fb6dead9076eae7c`
has a failing-first request regression and an isolated OPi selector-only pixel
experiment. Full evidence and remaining gates: `docs/FULL709-SELECTOR.md`.

It changes only full709's destination `r2y_mode` to zero, retaining source Y2R
and every coefficient. The archived unchanged R1 library recovers exactly
33.977872→50.689414 dB when only its forwarded selector changes 8→0; the fixed
library reproduces both directions with unchanged adjacent colour controls.

The independent reviewer approved code/evidence readiness at `282d4bc`, including
the original/forwarded request boundary, archived pixel controls and privacy.
The receipt above approves fix `9ddd7d8`; it is not permission to merge this PR,
pass G-B or release R1. The existing review checker is unchanged. The earlier
pending-review prose described the state before that review, not an approval.
