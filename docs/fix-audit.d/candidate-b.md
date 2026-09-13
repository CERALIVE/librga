| Candidate B; no fix. Base `b886777023e0c503134e340be348d6c1b11c8adc`, unchanged R1 library | `tests/repro/run-candidate-b.sh` extends H2; **DEMONSTRATED** last-reference/deinit and exit races under the stated caller pattern. TSan 200/200 each; ASan/UBSan deinit 167/200, exit 0/200. Owned-reference control passes both builds. RED transcript below; no GREEN/fix | host-shim-only | Not run; no library or ABI change | Not dispatched; no reviewer session or fix approval claimed | Not reported; characterization only |

### Candidate B — fresh R1 evidence, 2026-09-12

Branch: `qa/candidate-b-shutdown`. Native x86_64, GCC 16.2.1.

```sh
bash scripts/build-sanitized.sh asan
bash scripts/build-sanitized.sh tsan
bash tests/repro/run-candidate-b.sh
```

The final command returns **1**. It compiles the existing H2 source under each
sanitizer and invokes its existing runner for 200 fresh processes per scenario.
Raw wrapper evidence: `test-results/candidate-b/run.98LZbp/`.
ASan/UBSan batch: `test-results/h2/asan/run.gGIVDA/`.
TSan batch: `test-results/h2/tsan/run.SwcTLe/`.
Both preloaded canaries report. LSan is enabled; TSan symbolization is offline.

```text
scenario,iterations,clean,sanitizer,other_failure,invalid
asan/deinit,200,33,167,0,0
asan/exit,200,200,0,0,0
tsan/deinit,200,0,200,0,0
tsan/exit,200,0,200,0,0
H2 refcount: before=2 after=1 deinit=0 fd_open=1 blit=0
```

The refcount line occurs in **both** sanitized builds, exit 0. It acquires a
second real `RgaInit` reference, releases it, verifies the fd still exists, and
successfully blits with the singleton's remaining reference. This refutes the
blanket claim that `RgaDeInit` ignores its reference count in serial operation.

The deinit race deliberately releases the singleton's **borrowed last reference**
while another thread repeatedly calls `c_RkRgaBlit`. It is not a test of two
independently owned references. The worker completes at least 32 successful
blits before the action marker, and the runner validates those ioctls. A sample:

```text
H2 action=deinit successful_blits=107
../core/NormalRga.cpp:1494:17: runtime error: member access within null pointer of type 'struct rgaContext'
```

TSan reports the unsynchronized `rgaCtx` store at `NormalRgaClose:203` against
the read at `RgaBlit:375` (`addr2line` offsets `0x22197`, `0x2236e` in this build).
The operation holds no lifetime reference or shared lock against that release.
The ASan/UBSan sample is a **UBSan null-context report**, not an ASan heap UAF.
No heap-use-after-free claim is inferred from a null-context failure. This proves
the missing protection for the exercised last-reference caller pattern, not that
the API promises arbitrary concurrent destruction or that normal owned-reference
usage is broken.

The exit scenario calls `exit(0)` without joining the active blit thread.
TSan's sample reports `use of an invalid mutex (e.g. uninitialized or destroyed)`
through `Mutex::lock` (`0x2e67e`, `RgaMutex.h:164`) and
`Singleton<RockchipRga>::getInstance` (`0x2e6fc`, `RgaSingleton.h:34`). The static
mutex is destroyed at process exit while another thread can still acquire it.
The heap singleton is never automatically deleted; no `RockchipRga` destructor
race or universally unspecified destructor order is established. Joining users
before process exit is a separate caller responsibility not waived by this test.

No hardware, two-batch GREEN, memory-leak finding, release gate or fix approval
is claimed. The ordinary baseline suite remains separate from these RED probes.
