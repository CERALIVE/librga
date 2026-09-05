# Board counter discovery — 2026-09-05

## G-A measured update

Orange Pi at 192.168.78.151 is reachable using the supplied verified known-hosts
file. `/proc/rkrga/load` reports three schedulers and instantaneous load, not a
completed-task counter. The read-only completed counters actually used are:

- `/sys/kernel/debug/rockchip-rga/cores/0/tasks` — imconfig mask 1, RGA3 core 1.
- `/sys/kernel/debug/rockchip-rga/cores/1/tasks` — imconfig mask 2, RGA3 core 2.
- `/sys/kernel/debug/rockchip-rga/cores/2/tasks` — imconfig mask 4, RGA2.

Each directory also exposes `busy_ns`, `errors`, and `resets`. No counter was
reset or debugfs control written. The final real R0 run measured:

| Requested mask | Before (core 0,1,2) | After (core 0,1,2) | Delta |
|---|---|---|---|
| 1 | 5206,1000,1005 | 6206,1000,1005 | 1000,0,0 |
| 2 | 6206,1000,1005 | 6206,2000,1005 | 0,1000,0 |
| 4 | 6206,2000,1005 | 6206,2000,2005 | 0,0,1000 |

All 3000 submitted copies returned exact pixels; the separate fd census failed
4→5 in every process, so this is routing proof, not an overall R3 PASS.
Probe reports driver 1.3.11; hardware reports 3.0.76831 twice and 3.2.63318.

Rock 5B+ is reachable at **192.168.78.131**, with stock `rockchip_rga`, no `/dev/rga`,
and therefore **PRECONDITION-FAIL**. No counters or package drill were attempted
there. The historical .132 access finding below is superseded, not current truth.
Full row and rollback results: [DRILL-RESULTS.md](DRILL-RESULTS.md).

## Historical todo-20 attempt (superseded access findings)

No counter paths or values have been verified by this task. Do not interpret the
commands below as discovered paths or infer a driver version from the host shim.

| Board | Connectivity evidence | Hardware checks |
| --- | --- | --- |
| Orange Pi 5+ — 192.168.78.151 | ICMP reply: 0.974 ms, 0% loss. SSH refused by strict host-key verification: changed ED25519 key; existing known_hosts ECDSA entry conflicts. | **BLOCKED-host-key-mismatch**: sudo, counters, version probe, staging and DMA copy NOT RUN. |
| Rock 5B+ — 192.168.78.132 | `ping -c1 -W2` returned 100% loss. Requested board-specific credential file absent. | **SKIPPED-unreachable**: SSH kernel query, sudo, counters, version probe, staging and DMA copy NOT RUN. |

Orange Pi presented ED25519 fingerprint
`SHA256:sxA/WttVU+Ni7CwsnZgF5zl4pPwWDXIiLzu/Osx8a0I`.
This is an untrusted observation, not an approved replacement. No known-hosts
entry was edited and no SSH verification bypass was attempted. Owner must verify
the host identity out-of-band before this board lane resumes.

After identity/reachability is repaired, hold `board_lock_acquire` for the complete
drill and record these commands' actual output:

```sh
uname -r
dpkg-query -W librga2 librga2-ceralive rk3588-media-island
sudo -n true || echo NEEDS-PASSWORD
# Supply the SSH password privately on stdin, never in the transcript.
sudo -k -S -p '' true
sudo -n find /sys/kernel/debug/rockchip-rga -maxdepth 3 -type f | sort
cat /proc/rkrga/load
```

Record whether forced password authentication accepts the SSH password separately
from the passwordless verdict. Read the discovered counter files without writing
to debugfs, and list exact paths with samples here. Capture kernel/island/package
state at both start and end. Stage/run only under `/tmp`; install no packages.
Neither board's sudo-password-match status is known. Both real-board selftests
and the requested ≥3-path counter inventory remain outstanding acceptance gates.
