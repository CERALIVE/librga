#!/usr/bin/env bash
# Modified by CeraLive 2026-09-16: prove runtime findings escape the real CI test blocks.
set -euo pipefail
root=$(realpath "$(dirname "${BASH_SOURCE[0]}")/..")
cd "$root"
out=test-results/sanitizer-mutations
mkdir -p "$out"
scratch=$(mktemp -d "$root/test-results/sanitizer-mutants.XXXXXX")
cp build-asan/unit-pure "$scratch/unit-pure"
cp build-tsan/candidate-a "$scratch/candidate-a"
restore() {
    cp "$scratch/unit-pure" build-asan/unit-pure
    cp "$scratch/candidate-a" build-tsan/candidate-a
}
trap 'restore; rm -rf "$scratch"' EXIT

# Execute the job's real blocks, including their count guards, with its own
# sanitizer options. A separate approximation could hide a swallowed Meson exit.
python3 - "$scratch" <<'PY'
import re
import sys
from pathlib import Path

gate = Path('ci/sanitizers-steps.sh').read_text()
scratch = Path(sys.argv[1])
options = '\n'.join(re.findall(r"^(?:ASAN_OPTIONS|UBSAN_TEST_OPTIONS)='[^']+'$", gate, re.MULTILINE))
assert len(options.splitlines()) == 2
header = 'set -euo pipefail\nstep() { :; }\nfail() { printf "%s\\n" "$1" >&2; exit 1; }\n' + options + '\n'
asan = gate.split('step "meson test under ASan+UBSan (unit, goldens, shim)"\n', 1)[1].split('# --- ThreadSanitizer', 1)[0]
tsan = gate.split('step "meson test under TSan (concurrency suite)"\n', 1)[1].split('\n{\n', 1)[0]
(scratch / 'asan.sh').write_text(header + asan)
(scratch / 'tsan.sh').write_text(header + tsan)
PY
printf '#include <stdlib.h>\nint main(void) { volatile int *p = malloc(sizeof(int)); p[1] = 7; free((void *)p); return 0; }\n' >"$scratch/asan.c"
printf '#include <limits.h>\nint main(void) { volatile int n = INT_MAX; return n + 1; }\n' >"$scratch/ubsan.c"
for sanitizer in asan ubsan tsan; do
    block=asan
    case "$sanitizer" in
        asan|ubsan)
            gcc -O0 -g -fsanitize=address,undefined "$scratch/$sanitizer.c" -o build-asan/unit-pure
            diagnostic='ERROR: AddressSanitizer: heap-buffer-overflow'
            [[ $sanitizer != ubsan ]] || diagnostic='runtime error: signed integer overflow'
            ;;
        tsan)
            block=tsan
            cp build-tsan/tsan-canary build-tsan/candidate-a
            diagnostic='WARNING: ThreadSanitizer: data race'
            ;;
    esac
    rc=0
    bash "$scratch/$block.sh" >"$out/$sanitizer-red.log" 2>&1 || rc=$?
    [[ $rc == 1 ]] || { printf 'FAIL: %s test block exit=%s\n' "$sanitizer" "$rc" >&2; exit 1; }
    grep -F "$diagnostic" "$out/$sanitizer-red.log"
    printf 'RED: %s real job test block exit=%s\n' "$sanitizer" "$rc"
    restore
    bash "$scratch/$block.sh" >"$out/$sanitizer-green.log" 2>&1
    printf 'GREEN: %s restored real job test block exit=0\n' "$sanitizer"
done
