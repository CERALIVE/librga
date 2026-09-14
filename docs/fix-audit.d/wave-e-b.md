| status=GREEN fix=0a6a9bb76267a0157c7e7541decafdde60322a0a; Wave-E B; first-party teardown fix; commit resolved by `git log --format=%H --grep='fix(lifetime): drain active operations before final context release'` | `tests/repro/run-candidate-b.sh`: fresh RED on `1bde9018`, GREEN with active-operation draining and process-lifetime lookup lock; transcripts below | host-shim-only; no board claim | No removal or incompatible change against pre-fix R1; strict R0 closure BLOCKED by pre-existing removals, see `wave-e-verification.md` | author=Sisyphus-Junior/openai/gpt-6-astra reviewer=explore/openai/gpt-5.6-luna-fast verdict=APPROVE ses_f5e64778cffecjCELmv47BBBtn; Historical review: Independent review pending; no approval or reviewer session id; NOT approved for merge | Downstream-only: borrowed-last-reference and exit-time lock lifetime repair; not submitted upstream |

### Wave-E B — final release and exit-time lookup

Mechanism: final close marks the context closing under the publication mutex,
rejects new operations and waits for all existing operation guards before closing
the fd and freeing the context; singleton lookup uses a lock with the same process
lifetime as the already never-deleted singleton.

`core/NormalRga.cpp`: `RgaContextUse` guards legacy blit, fill, palette and flush
operations; `NormalRgaClose` validates/decrements under `mMutex` and waits on
`context_idle` only for the last reference. `NormalRgaOpen` waits for that close
to complete. Debug-level context access is under the same mutex. Ordinary release
from two owned references to one still returns without closing or draining.

`include/RgaSingleton.h`: `instanceLock()` constructs its mutex once, with C++14
thread-safe local-static initialization, and never destroys it. The singleton
already has that lifetime upstream. The previous `sLock` definition is retained
for ABI compatibility but lookup no longer uses it. This is deterministic lifetime
matching, not an atexit registration-order trick, and does not introduce a
singleton destructor that could race active callers. Explicit deletion/dlclose
with active callers and Android's separate singleton implementation are not proven.

The inherited B implementation is retained. Broken duplicated text in its pending
documentation/generator edits was removed; no library cleanup was added. Its H2
runner change separates stdout/stderr so buffered library stdout cannot split an
action/completion marker. Both streams are scanned for sanitizer diagnostics;
the required markers, 33 successful ioctls, timeout, exit checks and controls stay.

Command on each tree after building both sanitizer trees:

```sh
bash tests/repro/run-candidate-b.sh
```

Fresh RED on `1bde9018d28092879978419f8e48f2b88debcbaa`:

```text
Candidate B evidence: test-results/candidate-b/run.hArjys
ASan/UBSan summary (scenario,iterations,clean,sanitizer,other_failure,invalid):
deinit,200,35,165,0,0
exit,200,200,0,0,0
H2 driver exit=1
H2 refcount: before=2 after=1 deinit=0 fd_open=1 blit=0
TSan summary (same columns):
deinit,200,0,200,0,0
exit,200,0,200,0,0
H2 driver exit=1
H2 refcount: before=2 after=1 deinit=0 fd_open=1 blit=0
```

The wrapper returned 1. Raw batch evidence: `test-results/h2/asan/run.UVRQED`
and `test-results/h2/tsan/run.D9CjdS` in the pre-fix checkout. TSan exit reports
use of an invalid/destroyed mutex, not a singleton-object use-after-free. Both
owned-reference controls returned 0; they do not authorize a serial-refcount fix.

Fresh GREEN with B applied:

```text
Candidate B evidence: test-results/candidate-b/run.4Zx5sj
ASan/UBSan summary (scenario,iterations,clean,sanitizer,other_failure,invalid):
deinit,200,200,0,0,0
exit,200,200,0,0,0
H2 driver exit=0
H2 refcount: before=2 after=1 deinit=0 fd_open=1 blit=0
TSan summary (same columns):
deinit,200,200,0,0,0
exit,200,200,0,0,0
H2 driver exit=0
H2 refcount: before=2 after=1 deinit=0 fd_open=1 blit=0
```

The wrapper returned 0. Raw batches: `test-results/h2/asan/run.zf3XQY` and
`test-results/h2/tsan/run.fDpqql`. Both runtimes' deliberately failing canaries
were checked by the runner. ASan exit was clean before as well as after: only
TSan establishes that exit defect. No invalid run is counted as GREEN.

Disposition: all three H2 scenarios are now green Meson `concurrency` tests.
The 200-process batches and their canaries remain explicit host-only QA, not an
expected-RED exception. The original probe source and owned-reference assertions
are unchanged. Historical H2/candidate-B fragments retain their original results.
