# Full709 ordinary selector — review pending

The first-party repair of upstream `2aa0ab4d8374d630bed628f8fb6dead9076eae7c`
has a failing-first request regression and an isolated OPi selector-only pixel
experiment. Full evidence and remaining gates: `docs/FULL709-SELECTOR.md`.

It changes only full709's destination `r2y_mode` to zero, retaining source Y2R
and every coefficient. The archived unchanged R1 library recovers exactly
33.977872→50.689414 dB when only its forwarded selector changes 8→0; the fixed
library reproduces both directions with unchanged adjacent colour controls.

**Pending independent different-agent/different-model review:** no current
APPROVE receipt or D21 GREEN disposition is claimed. The reviewer must add the
fix commit and receipt to the six-field table before this fix can merge. The
existing review checker is unchanged. This is not a G-B pass or release approval.
