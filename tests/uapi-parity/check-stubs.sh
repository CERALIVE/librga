#!/usr/bin/env bash
#
# Anti-cheat gate for the UAPI parity harness.
#
# The island header cannot be compiled in userspace on its own, so we give it a
# compile ENVIRONMENT: a forced preinclude and an include root that answers its
# kernel-internal #includes. That environment is the one place where somebody
# could quietly make the parity test pass by supplying a struct of their own
# instead of letting the real header speak. This script makes that impossible to
# do by accident and obvious to do on purpose.
#
# It asserts:
#   1. every file under kstubs/linux/ is EMPTY (zero bytes)
#   2. the preinclude defines no field-bearing struct, union, or enum
#   3. the preinclude never even mentions a type the parity gate compares
#   4. the preinclude defines no RGA_* macro
#   5. nothing under kstubs/ defines an RGA_* macro or a struct body
#
# The compared-type list in (3) is DERIVED from island_side.c rather than
# hardcoded, so adding a struct to the comparison automatically extends this
# gate. A stub that grows to cover a new struct fails immediately.

set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
stub_root="$script_dir/kstubs"
preinclude="$stub_root/preinclude.h"
island_side="$script_dir/island_side.c"

fail=0
note() { printf 'check-stubs: %s\n' "$1"; }
bad() { printf 'check-stubs: FAIL: %s\n' "$1" >&2; fail=1; }

[ -f "$preinclude" ] || { bad "missing $preinclude"; exit 1; }
[ -f "$island_side" ] || { bad "missing $island_side"; exit 1; }
[ -d "$stub_root/linux" ] || { bad "missing $stub_root/linux"; exit 1; }

# ---- 1. every stub include must be empty ---------------------------------
stub_count=0
while IFS= read -r -d '' f; do
    stub_count=$((stub_count + 1))
    if [ -s "$f" ]; then
        bad "stub include ${f#"$stub_root"/} is not empty ($(wc -c <"$f") bytes)"
        bad "  stub includes exist only to satisfy the island header's #include lines;"
        bad "  anything inside one is content the real driver header did not ask for"
    fi
done < <(find "$stub_root/linux" -type f -print0)
[ "$stub_count" -gt 0 ] || bad "no stub includes found under $stub_root/linux"
note "checked $stub_count stub include(s) under kstubs/linux/ for emptiness"

# ---- 2. the preinclude may declare no aggregate WITH A BODY ---------------
# Opaque forward declarations (`struct mutex;`) are the whole point and are
# fine: they have no size and no members. An opening brace after a struct,
# union, or enum tag is not.
if grep -nE '^[[:space:]]*(typedef[[:space:]]+)?(struct|union|enum)\b[^;]*\{' "$preinclude"; then
    bad "the preinclude defines a field-bearing aggregate (see the lines above)"
    bad "  it may only forward-declare opaque kernel types"
fi

# ---- 3. the preinclude must not mention any compared type -----------------
# Derive the list from the EMIT_SIZE labels in island_side.c: those ARE the
# types the gate compares.
mapfile -t compared < <(
    grep -oE 'EMIT_SIZE\("[A-Za-z0-9_]+"' "$island_side" |
        sed -E 's/EMIT_SIZE\("([A-Za-z0-9_]+)"/\1/' | sort -u
)
[ "${#compared[@]}" -gt 0 ] || bad "could not derive the compared-type list from island_side.c"

for t in "${compared[@]}"; do
    if grep -nE "\\b${t}\\b" "$preinclude"; then
        bad "the preinclude mentions compared type '$t' (see the line above)"
        bad "  the parity gate must read that type from the sha-verified island header, not from here"
    fi
done
note "checked ${#compared[@]} compared type name(s) for leakage into the preinclude"

# ---- 4/5. no RGA_* macros anywhere in the stub environment ----------------
while IFS= read -r -d '' f; do
    if grep -nE '^[[:space:]]*#[[:space:]]*define[[:space:]]+RGA[A-Za-z0-9_]*' "$f"; then
        bad "${f#"$stub_root"/} defines an RGA_* macro (see the line above)"
        bad "  ioctl numbers and sizing constants must come from the real headers"
    fi
    if [ "$f" != "$preinclude" ] &&
        grep -nE '^[[:space:]]*(typedef[[:space:]]+)?(struct|union|enum)\b[^;]*\{' "$f"; then
        bad "${f#"$stub_root"/} defines a field-bearing aggregate (see the line above)"
    fi
done < <(find "$stub_root" -type f -print0)

if [ "$fail" -ne 0 ]; then
    echo "check-stubs: FAILED --- the compile environment is contaminated" >&2
    exit 1
fi

note "PASS --- the stub environment supplies primitives and opaque declarations only"
