#!/usr/bin/env bash
set -euo pipefail
control=$1
"$control" clean
for fault in submit sync pixels; do
    rc=0
    "$control" "$fault" || rc=$?
    [[ $rc == 1 ]] || { printf 'FAIL: %s returned %s\n' "$fault" "$rc"; exit 1; }
    printf 'PASS: %s fault makes real soak loop RED\n' "$fault"
done
