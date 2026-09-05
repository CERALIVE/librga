# Board counter discovery — 2026-09-05

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
