#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
set -euo pipefail
[[ ${TASK43_LOCK_HELD:-0} == 1 && ${CERALIVE_BOARD_TEST:-0} == 1 ]] || exit 77
root=${TASK43_ROOT:?}; out=${TASK43_OUT:?}/h1
mkdir -p "$out"
for lib in base-57a1067 post-5dfe897; do
  mkdir -p "$out/$lib"
  csv="$out/$lib/fdcensus.csv"
  printf 'iteration,scenario,threads,ok,fds_after_init,refs_after_init,deinit_calls,fds_after_teardown,refs_after_teardown,verdict\n' > "$csv"
  for scenario in c-init singleton-get direct-init; do
    failures=0
    for ((i=1;i<=200;i++)); do
      rc=0
      LD_LIBRARY_PATH="$root/lib/$lib" timeout -k 2 10 "$root/bin/h1-$lib" "$scenario" 8 > "$out/$lib/last.csv" 2>> "$out/$lib/stderr.log" || rc=$?
      printf '%s,' "$i" >> "$csv"; cat "$out/$lib/last.csv" >> "$csv"
      if ((rc == 1)); then ((failures+=1)); elif ((rc)); then printf 'INVALID scenario=%s iteration=%s exit=%s\n' "$scenario" "$i" "$rc" | tee -a "$out/$lib/iterations.txt"; exit 2; fi
      if ((i % 25 == 0)); then printf 'H1 %s %s %s/200 failures=%s\n' "$lib" "$scenario" "$i" "$failures"; fi
    done
    printf '%s failures=%s/200\n' "$scenario" "$failures" >> "$out/$lib/iterations.txt"
    LD_LIBRARY_PATH="$root/lib/$lib" timeout -k 2 10 "$root/bin/h1-$lib" "$scenario" 1 >> "$out/$lib/control.csv"
  done
done
