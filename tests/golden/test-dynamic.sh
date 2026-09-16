#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
set -euo pipefail
client=$(realpath "$1") shim=$(realpath "$2") fixtures=$(realpath "$3")
scratch=$(mktemp -d "${MESON_BUILD_ROOT:-.}/dynamic-golden.XXXXXX")
trap 'rm -rf "$scratch"' EXIT
readelf -d "$client" | grep -Eq 'NEEDED.*\[librga.so.2\]'
for n in {1..8}; do
    env LD_PRELOAD="$shim" FAKE_RGA_DUMP="$scratch/G$n.raw" FAKE_RGA_LOG="$scratch/G$n.log" \
        "$client" "G$n"
    [[ $(wc -c <"$scratch/G$n.raw") == 504 ]]
done
"$client" --verify G2 "$scratch/G2.raw" "$fixtures/G2.bin"
printf '\377' | dd of="$scratch/G2.raw" bs=1 seek=0 conv=notrunc status=none
if "$client" --verify G2 "$scratch/G2.raw" "$fixtures/G2.bin"; then
    printf 'FAIL: mutated request passed\n' >&2; exit 1
fi
printf 'PASS: dynamic client rejects changed request byte\n'
truncate -s 503 "$scratch/G2.raw"
if "$client" --verify G2 "$scratch/G2.raw" "$fixtures/G2.bin"; then exit 1; fi
if env -u LD_PRELOAD "$client" G2; then exit 1; fi
if env LD_PRELOAD="$shim" FAKE_RGA_FAIL=RGA_BLIT_SYNC "$client" G2; then exit 1; fi
printf 'PASS: malformed request, missing shim and failed submit rejected\n'
