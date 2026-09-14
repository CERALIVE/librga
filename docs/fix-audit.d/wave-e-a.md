| status=GREEN fix=d280ee104eacc60a5ba0ab2d4d92f64b7b688360; Wave-E A; first-party initialization fix; commit resolved by `git log --format=%H --grep='fix(init): serialize context publication and unwind failed opens'` | `tests/repro/run-candidate-a.sh`: RED direct-init 20/20 TSan and 1000/1000 leaked fds per API; GREEN same command, then 200 processes per scenario twice; transcripts below; fresh takeover run in `wave-e-verification.md` | host-shim-only | No removal or incompatible change vs pre-fix R1; strict R0 closure BLOCKED by pre-existing removals, see `wave-e-verification.md` | author=Sisyphus-Junior/openai/gpt-6-astra reviewer=explore/openai/gpt-5.6-luna-fast verdict=APPROVE ses_f5e64778cffecjCELmv47BBBtn; Historical review: Independent full-series review pending; not approved for merge | Downstream-only: initialization ownership repair; not yet submitted upstream |

### Wave-E A — initialization ownership

Mechanism: hold the legacy mutex across context discovery, its single device open,
initialization, reference acquisition and publication; use atomic operations on the
existing refcount storage and close uncommitted device fds on initialization failure.
The modern im2d session has its own fd, so its failure paths are unwound independently.

Fixes: `core/NormalRga.cpp` (`NormalRgaOpen`, atomic reference operations and
`RgaInit` version-rejection unwind); `im2d_api/src/im2d_context.cpp`
(`rga_device_init` failure exits and failed hardware-info initialization).
The exported `volatile int32_t refCount` declaration/size is unchanged; library
accesses use `__atomic_*`. No public structure, default, signature or symbol changes.

RED on `1bde9018d28092879978419f8e48f2b88debcbaa`, exact command
`bash tests/repro/run-candidate-a.sh`:

```text
Candidate A evidence: test-results/candidate-a/run.stdc06
hwversion,RgaInit,iterations=1000,failed_calls=1000,start=0,end=1000,growing_rows=1000,verdict=RED
unset,RgaInit,iterations=1000,failed_calls=0,start=0,end=0,growing_rows=0,verdict=NOT-REPRODUCED
hwversion,improcess,iterations=1000,failed_calls=1000,start=0,end=1000,growing_rows=1000,verdict=RED
unset,improcess,iterations=1000,failed_calls=0,start=1,end=1,growing_rows=0,verdict=NOT-REPRODUCED
Candidate A: exit=1; per-process evidence in test-results/candidate-a/run.stdc06
```

`races.csv` records all 20 direct-init processes with exit 66 and a TSan report;
all 40 C-init/singleton controls exited zero without reports.

GREEN after rebuilding both sanitizer trees with `meson compile -C build-asan`
and `meson compile -C build-tsan`, same command:

```text
Candidate A evidence: test-results/candidate-a/run.mNrUYa
hwversion,RgaInit,iterations=1000,failed_calls=1000,start=0,end=0,growing_rows=0,verdict=NOT-REPRODUCED
unset,RgaInit,iterations=1000,failed_calls=0,start=0,end=0,growing_rows=0,verdict=NOT-REPRODUCED
hwversion,improcess,iterations=1000,failed_calls=1000,start=0,end=0,growing_rows=0,verdict=NOT-REPRODUCED
unset,improcess,iterations=1000,failed_calls=0,start=1,end=1,growing_rows=0,verdict=NOT-REPRODUCED
Candidate A: exit=0; per-process evidence in test-results/candidate-a/run.mNrUYa
```

Long-race acceptance: `bash tests/repro/run-candidate-a.sh 200` run twice,
`test-results/candidate-a/run.RWhWlo` and `run.OtqPmT`. Both exited zero;
each ran 200 direct-init processes and 400 controls, with zero race reports,
and repeated all four 1000-call censuses with the same flat GREEN rows above.
Both sanitizer canaries were verified in every run. The optional count only
extends the batch; the original default 20 and all original assertions remain.

Disposition: direct-init is in Meson's green `concurrency` suite; both injected
hardware-version-failure censuses are green baseline tests against the ordinary
shared library. The long canary-verified batches remain explicit host-only QA.
