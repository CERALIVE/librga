| Candidate C; no fix. Base `b886777023e0c503134e340be348d6c1b11c8adc`, unchanged R1 library | `tests/repro/candidate_c_scheduler.cpp` via `bash tests/repro/run-candidate-c.sh`; **DEMONSTRATED**, exit 1: five assertions, two failures (fresh/default and explicit-core/reset-to-default). Transcript below; no GREEN/fix | host-shim-only | Not run; test/docs only, no ABI or accepted-input changes | Not dispatched; no reviewer session or fix approval claimed | Not reported; existing validation defect reproduced |

### Candidate C — scheduler validation, 2026-09-12

Branch: `qa/candidate-c-scheduler-default`. Native x86_64, GCC 16.2.1.
Exact command from the checkout root:

```sh
bash tests/repro/run-candidate-c.sh
```

The runner builds the ordinary shared library and existing fake-device shim,
then compiles the new client with `-Wall -Wextra -Werror`. The assertions reuse
`tests/unit/unit_assert.h`; no new assertion framework or source library is
introduced. H5's existing characterization assertions are not changed or
weakened. Raw transcript: `test-results/candidate-c/run.uY0XGn/transcript.txt`.

```text
FAIL default accepted on fresh thread: expected 1, got -4
FAIL reset explicit core to default: expected 1, got -4
candidate-c: 5 assertions, 2 failures
Candidate C: exit=1
```

One deterministic execution; both default attempts failed (2/2). Three controls
passed: the enum really equals zero, an explicit core is accepted, and the
unsupported bit `0x10` is rejected. `imconfig` at `im2d.cpp:865-871` accepts a
scheduler only if `value & IM_SCHEDULER_MASK` is nonzero. The defined
`IM_SCHEDULER_DEFAULT=0` can never satisfy that condition, returning
`IM_STATUS_ILLEGAL_PARAM` (-4) instead of `IM_STATUS_SUCCESS` (1).
This is an existing-signature input-validation issue, not a proposed API.

The first draft failed to compile because the public header expects `NULL`
to be supplied by an earlier include. Adding `<cstddef>` to the **test only**
resolved that setup failure before obtaining the RED above. The failed build
is not defect evidence. No library fix, hardware run or sanitizer claim.
