#!/usr/bin/env bash
set -euo pipefail
root=$(realpath "$(dirname "${BASH_SOURCE[0]}")/..")
cd "$root"
count=0
[[ ! -f test-results/analyzer-complete.count ]] || count=$(<test-results/analyzer-complete.count)
if [[ ! $count =~ ^[1-9][0-9]*$ || ! -s test-results/analyzer.txt ||
      ! -s test-results/analyzer-probe.log || ! -f test-results/analyzer-hits.txt ]]; then
    printf 'GCC -fanalyzer: ANALYSIS INCOMPLETE — not a clean zero-findings result\n'
    exit 1
fi
grep -q -- '-Wanalyzer-null-dereference' test-results/analyzer-probe.log
printf 'GCC -fanalyzer: %s library translation units; %s unique findings; capability probe passed\n' \
    "$count" "$(wc -l <test-results/analyzer-hits.txt)"
