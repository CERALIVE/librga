#!/usr/bin/env bash
set -euo pipefail
[[ ${TASK43_LOCK_HELD:-0} == 1 && ${CERALIVE_BOARD_TEST:-0} == 1 ]] || exit 77
root=${TASK43_ROOT:?}; out=${TASK43_OUT:?}/h8
for lib in base-57a1067 post-5dfe897; do
  mkdir -p "$out/$lib"
  printf 'H8 %s: 12 CSC scores + NV16 + 2 interpolation scores + rejection control\n' "$lib"
  LD_LIBRARY_PATH="$root/lib/$lib" timeout -k 3 180 "$root/bin/h8-board" "$root/data" > "$out/$lib/psnr.csv" 2> "$out/$lib/control.txt"
done
