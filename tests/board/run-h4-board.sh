#!/usr/bin/env bash
set -euo pipefail
[[ ${TASK43_LOCK_HELD:-0} == 1 && ${CERALIVE_BOARD_TEST:-0} == 1 ]] || exit 77
root=${TASK43_ROOT:?}; out=${TASK43_OUT:?}/h4
for lib in radxa r0 base-57a1067 post-5dfe897; do
  mkdir -p "$out/$lib"
  (
    cd "$out/$lib"
    LD_LIBRARY_PATH="$root/lib/$lib" LD_PRELOAD="$root/lib/librga_timing.so:$root/lib/getenv-meter.so" \
      RGA_TIMING_CSV="$PWD/timing.csv" timeout -k 5 240 "$root/bin/h4-board" "$lib" "${TASK43_BOARD:?}" > summary.txt
  )
done
