#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/../.."
mkdir -p test-results/candidate-b
out=$(mktemp -d test-results/candidate-b/run.XXXXXX)
printf 'Candidate B evidence: %s\n' "$out"
red=0
for mode in asan tsan; do
    rc=0
    bash tests/repro/run-h2.sh "$mode" 200 > "$out/$mode.txt" 2>&1 || rc=$?
    [[ $rc == 0 || $rc == 1 ]] || { cat "$out/$mode.txt"; exit 2; }
    if ((rc)); then red=1; fi
    cat "$out/$mode.txt"
    env LD_PRELOAD="$PWD/build-$mode/libfake_rga.so" \
        FAKE_RGA_LOG="$PWD/$out/$mode-refcount.shim.txt" \
        ASAN_OPTIONS=verify_asan_link_order=0:detect_leaks=1 \
        TSAN_OPTIONS=halt_on_error=1:exitcode=66:symbolize=0 \
        "build-$mode/h2-teardown-race" refcount > "$out/$mode-refcount.txt" 2>&1
    cat "$out/$mode-refcount.txt"
done
exit "$red"
