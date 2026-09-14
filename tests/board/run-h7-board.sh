#!/usr/bin/env bash
set -euo pipefail
[[ ${TASK43_LOCK_HELD:-0} == 1 && ${CERALIVE_BOARD_TEST:-0} == 1 ]] || exit 77
root=${TASK43_ROOT:?}; out=${TASK43_OUT:?}/h7
counters() {
  local f
  for f in /proc/rkrga/load /sys/kernel/debug/rkrga/{load,driver_version,hardware,mm,request_manager} /sys/kernel/debug/rockchip-rga/{load,driver_version,hardware,mm,request_manager}; do
    printf '\n%s\n' "$f"
    timeout -k 1 2 cat "$f" || printf 'UNAVAILABLE exit=%s\n' "$?"
  done
}
for lib in radxa r0 base-57a1067 post-5dfe897; do
  mkdir -p "$out/$lib"
  printf 'threads,seconds,verdict\n' > "$out/$lib/levels.csv"
  for n in 1 4 6 8; do
    duration=60; [[ $n == 1 ]] && duration=5
    level="$out/$lib/$n"; mkdir "$level"
    printf 'H7 %s %s threads for %s s\n' "$lib" "$n" "$duration"
    counters > "$level/counters-before.txt"
    (
      cd "$level"
      exec env LD_LIBRARY_PATH="$root/lib/$lib" timeout -k 3 75 "$root/bin/h7-board" "$n" "$duration"
    ) > "$level/fps.csv" 2> "$level/stderr.txt" & job=$!
    tick=0
    while kill -0 "$job" 2>/dev/null; do
      if [[ -f $level/incident ]]; then
        read -r pid verdict < "$level/incident"
        [[ $pid =~ ^[0-9]+$ ]] || exit 86
        timeout -k 1 5 bash -c 'for f in /proc/"$1"/task/*/stack; do printf "\n%s\n" "$f"; sudo -n cat "$f" || printf "SUDO-UNAVAILABLE\n"; done' _ "$pid" > "$level/stacks.txt" 2>&1 || true
        kill -KILL "$pid" 2>/dev/null || true
        break
      fi
      if ((tick % 5 == 0)); then
        printf 'H7 %s N=%s elapsed~%s s\n' "$lib" "$n" "$tick"
        counters >> "$level/counters-during.txt"
      fi
      ((tick+=1))
      sleep 1
    done
    rc=0; wait "$job" || rc=$?
    counters > "$level/counters-after.txt"
    timeout -k 1 5 journalctl -k --since '-2min' > "$level/kernel-journal.txt" 2>&1 || true
    if ((rc)); then
      verdict=INVALID; [[ -f $level/incident ]] && read -r _ verdict < "$level/incident"
      printf '%s,%s,%s\n' "$n" "$duration" "$verdict" >> "$out/$lib/levels.csv"
      if ! timeout -k 1 3 cat /proc/rkrga/load > "$level/recovery-load.txt"; then exit 86; fi
      if ! (cd "$level"; LD_LIBRARY_PATH="$root/lib/$lib" timeout -k 2 8 "$root/bin/h7-board" 1 1 > recovery.csv 2>&1); then exit 86; fi
      printf 'H7 STOP first incident: %s %s threads %s; recovery passed\n' "$lib" "$n" "$verdict"
      [[ $verdict == INVALID ]] && exit 2
      exit 3
    fi
    printf '%s,%s,OK\n' "$n" "$duration" >> "$out/$lib/levels.csv"
  done
  printf 'NO-STALL at 8 threads\n' > "$out/$lib/verdict.txt"
done
