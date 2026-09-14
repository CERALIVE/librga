| Wave-E D; first-party wait-error ownership fix; commit resolved by `git log --format=%H --grep='fix(imsync): consume the fence after a failed wait'` | `tests/repro/run-candidate-d.sh`: RED 200/200 retained fds, GREEN 0/200; transcripts below; fresh takeover run in `wave-e-verification.md` | host-shim-only | No removal or incompatible change vs pre-fix R1; strict R0 closure BLOCKED by pre-existing removals, see `wave-e-verification.md` | Independent full-series review pending; not approved for merge | Downstream-only: error-path ownership repair; not yet submitted upstream |

### Wave-E D — wait-error fence ownership

Mechanism: `imsync` closes the accepted positive fence after a failed wait,
just as it already does after a successful wait. The `fence_fd <= 0` rejection,
return-status polarity, successful path and submit paths are unchanged.
Fix: `im2d_api/src/im2d.cpp`, `imsync` error branch.

Exact invocation before and after: `bash tests/repro/run-candidate-d.sh`, after
building `build-asan` with `scripts/build-sanitized.sh asan` (incrementally rebuilt
with `meson compile -C build-asan` after the change).

RED on `1bde9018d28092879978419f8e48f2b88debcbaa`:

```text
C4: RED (200/200 defect observations)
Candidate D: exit=1; evidence=test-results/candidate-d/run.lBWs5e
```

GREEN:

```text
C4: NOT-REPRODUCED (0/200 defect observations)
Candidate D: exit=0; evidence=test-results/candidate-d/run.jxTWU5
```

The existing probe calls a clean run `NOT-REPRODUCED`; here it is a measured
RED-to-GREEN transition, not an already-green candidate. Both runs verified the
ASan canary and exactly 200 injected `poll` failures (`errno=5`); each also
completed 200 successful-wait controls. Per-call census and status transcripts
remain under those evidence directories. No sanitizer reports in the fixed probe.

Disposition: the unchanged `h6_polarity_fence.cpp sync-only` probe is promoted to
the green Meson baseline as `candidate-d`. Full H6 remains an opt-in
characterization because C2/C3 are separate, unfixed findings.
