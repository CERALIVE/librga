#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/../.."
mkdir -p test-results/candidate-d
out=$(mktemp -d test-results/candidate-d/run.XXXXXX)
g++ -std=c++14 -Wall -Wextra -Werror -DLINUX=1 -g -fno-omit-frame-pointer \
    -fsanitize=address,undefined -Iinclude -Iim2d_api -Icore/hardware \
    tests/repro/h6_polarity_fence.cpp -Lbuild-asan -Wl,-rpath,"$PWD/build-asan" \
    -lrga -ldl -pthread -o "$out/candidate-d"
export ASAN_OPTIONS=verify_asan_link_order=0:detect_leaks=1
export UBSAN_OPTIONS=print_stacktrace=1:halt_on_error=1
rc=0
env LD_PRELOAD="$PWD/build-asan/libfake_rga.so" UBSAN_OPTIONS=halt_on_error=0 \
    FAKE_RGA_LOG="$PWD/$out/canary.shim.txt" build-asan/asan-canary \
    > "$out/canary.txt" 2>&1 || rc=$?
[[ $rc != 0 ]] && grep -q 'ERROR: AddressSanitizer: heap-buffer-overflow' "$out/canary.txt" || exit 2
rc=0
timeout 30s env LD_PRELOAD="$PWD/build-asan/libfake_rga.so" \
    FAKE_RGA_LOG="$PWD/$out/shim.txt" "$out/candidate-d" sync-only \
    > "$out/transcript.txt" 2>&1 || rc=$?
[[ $rc == 0 || $rc == 1 ]] || exit 2
[[ $(grep -c '^poll sync-wait .*ret=-1 errno=5$' "$out/shim.txt") == 200 ]] || exit 2
grep '^C4:' "$out/transcript.txt"
printf 'Candidate D: exit=%d; evidence=%s\n' "$rc" "$out"
exit "$rc"
