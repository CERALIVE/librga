#!/usr/bin/env bash
set -euo pipefail
root=$(realpath "$(dirname "${BASH_SOURCE[0]}")/../..")
build=$(realpath "$1")
scratch=$(mktemp -d "$build/bench-mutations.XXXXXX")
trap 'rm -rf "$scratch"' EXIT
mkdir -p "$scratch/tests/board" "$scratch/tests/oracle"
cp "$root/tests/oracle/oracle.h" "$scratch/tests/oracle/"
cp "$root/tests/board/bench-control.c" "$scratch/tests/board/"
flags=(-std=gnu11 -Wall -Wextra -Werror -I"$root/include" -I"$root/im2d_api"
    -I"$root/core/hardware" -L"$build" "-Wl,-rpath,$build")
for mutation in missing-warm fd-leak short-soak empty-soak; do
    python3 - "$root/tests/board/rga-convert-bench.c" "$scratch/tests/board/rga-convert-bench.c" "$mutation" <<'PY'
import sys
from pathlib import Path
source, destination, mutation = sys.argv[1:]
changes = {
    'missing-warm': ('if (!context || warm_im2d())', 'if (!context)'),
    'fd-leak': ('int before=census(),rc=0;', 'int before=census(),rc=0; (void)open("/dev/null",O_RDONLY);'),
    'short-soak': ('deadline=start+3600e6;', 'deadline=start+295e6;'),
    'empty-soak': ('int completed=0;', 'int completed=0; iterations=0;'),
}
old, new = changes[mutation]
text = Path(source).read_text()
assert text.count(old) == 1, (mutation, 'mutation site drift')
Path(destination).write_text(text.replace(old, new))
PY
    input="$scratch/tests/board/rga-convert-bench.c"
    [[ $mutation != *soak ]] || input="$scratch/tests/board/bench-control.c"
    cc "${flags[@]}" "$input" "$build/libboard-oracle.a" -lrga -lm -ldl -o "$scratch/$mutation"
    rc=0
    if [[ $mutation == *soak ]]; then
        "$scratch/$mutation" clean >"$scratch/$mutation.log" 2>&1 || rc=$?
    else
        env LD_PRELOAD="$build/libfake_rga.so" "$scratch/$mutation" --session-selftest >"$scratch/$mutation.log" 2>&1 || rc=$?
    fi
    cat "$scratch/$mutation.log"
    [[ $rc == 1 ]] || { printf 'FAIL: %s exit=%d\n' "$mutation" "$rc"; exit 1; }
    printf 'PASS: bench source mutation %s returns RED (1)\n' "$mutation"
done
