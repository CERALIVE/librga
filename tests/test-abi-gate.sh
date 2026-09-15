#!/usr/bin/env bash
# Modified by CeraLive 2026-09-14: prove that an invisible public symbol fails ABI.
set -euo pipefail
root=$(realpath "$(dirname "${BASH_SOURCE[0]}")/..")
mkdir -p "$root/test-results"
scratch=$(mktemp -d "$root/test-results/abi-canary.XXXXXX")
trap 'rm -rf "$scratch"' EXIT
printf 'int public_entry(int x) { return x + 1; }\n' >"$scratch/old.c"
printf 'int public_entry(int x) { return x + 1; }\nint added_entry(void) { return 0; }\n' >"$scratch/added.c"
printf '__attribute__((visibility("hidden"))) int public_entry(int x) { return x + 1; }\nint added_entry(void) { return 0; }\n' >"$scratch/hidden.c"
for variant in old added hidden; do
    gcc -g -O2 -fPIC -shared -Wl,-soname,librga.so.2 \
        "$scratch/$variant.c" -o "$scratch/$variant.so"
done
bash "$root/ci/check-abi.sh" "$scratch/old.so" "$scratch/old.so" "$scratch/same.txt"
bash "$root/ci/check-abi.sh" "$scratch/old.so" "$scratch/added.so" "$scratch/added.txt"
if bash "$root/ci/check-abi.sh" "$scratch/old.so" "$scratch/hidden.so" "$scratch/hidden.txt"; then
    printf 'FAIL: ABI gate accepted a hidden public entry\n' >&2; exit 1
fi
grep -F public_entry "$scratch/hidden.txt" >/dev/null
printf 'PASS: ABI controls 3/3 (identical, additive, hidden-public-symbol rejection)\n'
