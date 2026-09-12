| Candidate D; no fix. Base `b886777023e0c503134e340be348d6c1b11c8adc`, unchanged R1 library | H6 `sync-only` via `bash tests/repro/run-candidate-d.sh`; **DEMONSTRATED**, 200/200 failure calls retain the positive fence fd, 200/200 success controls consume it. Exit 1, transcript below; no GREEN/fix | host-shim-only | Not run; no library or ABI change, fence polarity unchanged | Not dispatched; no reviewer session or fix approval claimed | Not reported; error-branch cleanup evidence only |

### Candidate D — imsync error branch, 2026-09-12

Branch: `qa/candidate-d-imsync-error`. Native x86_64, GCC 16.2.1.

```sh
bash scripts/build-sanitized.sh asan
bash tests/repro/run-candidate-d.sh
```

The final command returns **1**. The existing H6 C4 loop was moved unchanged
into a callable test function; the original no-argument H6 still executes all
three existing cases. The new `sync-only` mode executes no submit/polarity case.
It uses the existing shim's `FAKE_RGA_SYNC_FAIL=1` knob, not a replacement for
`imsync` or `rga_sync_wait`.

Raw artifacts: `test-results/candidate-d/run.vYtMzT/` contains the executable,
preloaded ASan-canary transcript, every test row, and the shim log.
The runner checks exactly **200** failed `poll` calls with `errno=5` (EIO).
Recorded rows (`case,iteration,status,fd,open_after,fd_before,fd_after,out_fence,verdict`):

```text
C4-control-success,1,1,3,0,4,3,-1,PASS
C4,1,0,3,1,4,4,-1,RED
C4: RED (200/200 defect observations)
```

All 200 iterations match this pattern. The successful wait consumes the positive
eventfd. On EIO, `rga_sync_wait` returns -1, `imsync` returns
`IM_STATUS_FAILED` (**0**, not a positive success status), and `fcntl(F_GETFD)`
still finds that fd open. The live-fd census is unchanged rather than decreasing
by one. The test closes the retained fd **after recording** the failure and
asserts restoration of its baseline, so the result is 200 independent ownership
observations, not a claim of 200 accumulated fds or fd-exhaustion behavior.

Mechanism: `im2d.cpp:851-857` returns from the wait-error branch before reaching
`close(fence_fd)`. This demonstrates missing error-branch consumption under
the project's cleanup expectation. It does not establish a kernel sync-fence
bug: the fence is a host eventfd and the failed poll is injected.
The `fence_fd <= 0` validation and every submit-return polarity remain untouched.

ASan/UBSan instrument both library and client, LSan is enabled, and
`verify_asan_link_order=0` permits the existing preload. The preloaded canary
reports a heap-buffer-overflow. The candidate emits **no ASan/LSan/UBSan memory
diagnostic**; the RED is the fd ownership/census assertion. Those sanitizers do
not track file-descriptor ownership, so their silence is not leak cleanliness.
No hardware coverage, library fix, GREEN transcript or release approval claimed.
