| Wave-E C; first-party scheduler-default fix on `1bde9018d28092879978419f8e48f2b88debcbaa`; commit resolved by `git log --format=%H --grep='fix(imconfig): accept the documented default scheduler'` | `tests/repro/run-candidate-c.sh`: RED 2/5 assertions, GREEN 0/5 failures; transcripts below; fresh takeover and unit-session expectation migration in `wave-e-verification.md` | host-shim-only | No removal or incompatible change vs pre-fix R1; strict R0 closure BLOCKED by pre-existing removals, see `wave-e-verification.md` | Independent full-series review pending; not approved for merge | Downstream-only: documented enum acceptance; not yet submitted upstream |

### Wave-E C — scheduler-default acceptance

Mechanism: the zero-valued documented default now bypasses the nonzero core-mask
test, preserving acceptance of every previously accepted value.

`im2d_api/src/im2d.cpp`, `imconfig(IM_CONFIG_SCHEDULER_CORE, value)`.
No API, default, layout, visibility or SONAME change.

Exact invocation before and after: `bash tests/repro/run-candidate-c.sh`.
Native x86_64, GCC 16.2.1; ordinary shared library and fake-device preload.

RED on `1bde9018` (`test-results/candidate-c/run.pZB6ua/transcript.txt`):

```text
FAIL default accepted on fresh thread: expected 1, got -4
FAIL reset explicit core to default: expected 1, got -4
candidate-c: 5 assertions, 2 failures
Candidate C: exit=1; evidence=test-results/candidate-c/run.pZB6ua
```

GREEN (`test-results/candidate-c/run.oT8Bu5/transcript.txt`):

```text
== Candidate C: scheduler default is legitimate input ==
0 1831754 1831754 E im2d_rga: IM2D: It's not legal rga_core[0x10], it needs to be a 'IM_SCHEDULER_CORE'.
-- Candidate C: scheduler default is legitimate input: 5 assertions --
candidate-c: 5 assertions, 0 failures
Candidate C: exit=0; evidence=test-results/candidate-c/run.oT8Bu5
```

Disposition: promoted unchanged into the green Meson baseline as `candidate-c`,
linked against the ordinary shared library (not the golden-test static library).
Historical characterization fragments remain verbatim.
