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

# Given the real accepted ELF names, build small libraries without the RGA driver.
# These are gate fixtures, not compatibility shims or replicas of the old ABI.
allowlist="$root/packaging/baseline-symbols-upstream-delta.txt"
python3 - "$allowlist" "$scratch" <<'PY'
from pathlib import Path
import sys

symbols = [line.split('\t')[0] for line in Path(sys.argv[1]).read_text().splitlines()
           if line and not line.startswith('#')]
assert len(symbols) == 18 and len(set(symbols)) == 18
scratch = Path(sys.argv[2])
definitions = []
for index, symbol in enumerate(symbols):
    if symbol in ('cosa_table', 'sina_table'):
        definitions.append(f'int {symbol}[360] = {{1}};\n')
    else:
        definitions.append(f'int entry{index}(void) __asm__("{symbol}");\n'
                           f'int entry{index}(void) {{ return {index}; }}\n')
kept = 'int public_entry(void) { return 1; }\nint public_data = 1;\n'
(scratch / 'baseline.c').write_text(kept + ''.join(definitions))
(scratch / 'accepted.c').write_text(kept)
(scratch / 'extra-function.c').write_text('int public_data = 1;\n')
(scratch / 'extra-variable.c').write_text('int public_entry(void) { return 1; }\n')
for variant, methods in (('vtable-old', 'virtual int f(); virtual int g();'),
                         ('vtable-new', 'virtual int g(); virtual int f();')):
    (scratch / f'{variant}.cpp').write_text(
        f'struct api {{ {methods} }};\n'
        'int api::f() { return 1; }\nint api::g() { return 2; }\n'
        'api *make_api() { return new api; }\n')
for index, definition in enumerate(definitions):
    (scratch / f'restored-{index}.c').write_text(kept + definition)
PY
for source in "$scratch/baseline.c" "$scratch/accepted.c" "$scratch"/extra-*.c "$scratch"/restored-*.c; do
    gcc -g -O2 -flto -fPIC -shared -Wl,-soname,librga.so.2 "$source" -o "${source%.c}.so"
done

# When only accepted removals occur, then the gate passes.
bash "$root/ci/check-abi.sh" "$scratch/baseline.so" "$scratch/accepted.so" "$scratch/accepted.txt" "$allowlist"

# When a nineteenth function OR variable disappears, then it fails by name.
for kind in function variable; do
    if bash "$root/ci/check-abi.sh" "$scratch/baseline.so" "$scratch/extra-$kind.so" "$scratch/extra-$kind.txt" "$allowlist" >"$scratch/rejection.txt" 2>&1; then
        printf 'FAIL: accepted an unexpected %s removal\n' "$kind" >&2; exit 1
    fi
    grep -F 'unexpected removals:' "$scratch/rejection.txt"
done

# When any accepted removal disappears, then the allowlist is stale and fails.
for library in "$scratch"/restored-*.so; do
    if bash "$root/ci/check-abi.sh" "$scratch/baseline.so" "$library" "$scratch/restored.txt" "$allowlist" >"$scratch/rejection.txt" 2>&1; then
        printf 'FAIL: accepted stale removal list: %s\n' "$library" >&2; exit 1
    fi
    grep -F 'expected removals absent:' "$scratch/rejection.txt"
done

# Restore the candidate after the mutations: acceptance must still pass.
bash "$root/ci/check-abi.sh" "$scratch/baseline.so" "$scratch/accepted.so" "$scratch/restored-pass.txt" "$allowlist"
printf 'PASS: exact 18-removal acceptance, extra function/data rejection, all 18 stale-entry rejections, restored candidate\n'

# Given exactly the accepted removals plus an incompatible vtable change,
# when deletion-only rules apply, then the independent incompatibility still fails.
for variant in old new; do
    g++ -g -O2 -flto -fPIC -c "$scratch/vtable-$variant.cpp" -o "$scratch/vtable-$variant.o"
done
gcc -g -O2 -flto -fPIC -c "$scratch/baseline.c" -o "$scratch/baseline.o"
gcc -g -O2 -flto -fPIC -c "$scratch/accepted.c" -o "$scratch/accepted.o"
g++ -g -O2 -flto -shared -Wl,-soname,librga.so.2 "$scratch/baseline.o" "$scratch/vtable-old.o" -o "$scratch/vtable-old.so"
g++ -g -O2 -flto -shared -Wl,-soname,librga.so.2 "$scratch/accepted.o" "$scratch/vtable-new.o" -o "$scratch/vtable-new.so"
if bash "$root/ci/check-abi.sh" "$scratch/vtable-old.so" "$scratch/vtable-new.so" "$scratch/vtable.txt" "$allowlist" >"$scratch/rejection.txt" 2>&1; then
    printf 'FAIL: accepted incompatible vtable change alongside known removals\n' >&2; exit 1
fi
grep -F 'abidiff after accepted removals exit=12' "$scratch/rejection.txt"
printf 'PASS: non-removal incompatible-change bit remains blocking\n'

# Given a truncated report or duplicate allowlist, when reconciled, then fail closed.
printf 'Functions changes summary: 1 Removed, 0 Changed, 0 Added functions\nVariables changes summary: 0 Removed, 0 Changed, 0 Added variables\n' >"$scratch/truncated.txt"
if python3 "$root/ci/abi-removals.py" "$scratch/truncated.txt" /dev/null "$scratch/invalid.abignore"; then
    printf 'FAIL: accepted truncated report\n' >&2; exit 1
fi
printf 'public_entry\tfixture\npublic_entry\tduplicate\n' >"$scratch/duplicate.tsv"
if python3 "$root/ci/abi-removals.py" "$scratch/same.txt" "$scratch/duplicate.tsv" "$scratch/invalid.abignore"; then
    printf 'FAIL: accepted duplicate allowlist\n' >&2; exit 1
fi
