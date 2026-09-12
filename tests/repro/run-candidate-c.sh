#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/../.."
mkdir -p test-results/candidate-c
out=$(mktemp -d test-results/candidate-c/run.XXXXXX)
if [[ ! -f build-qa/build.ninja ]]; then
    meson setup build-qa -Dlibrga_demo=false -Dcpp_args=-fpermissive > "$out/setup.txt" 2>&1
fi
meson compile -C build-qa rga:shared_library fake_rga > "$out/build.txt" 2>&1
g++ -std=c++14 -Wall -Wextra -Werror -Iinclude -Iim2d_api \
    tests/repro/candidate_c_scheduler.cpp -Lbuild-qa -Wl,-rpath,"$PWD/build-qa" \
    -lrga -ldl -o "$out/candidate-c"
rc=0
env LD_PRELOAD="$PWD/build-qa/libfake_rga.so" FAKE_RGA_LOG="$PWD/$out/shim.txt" \
    "$out/candidate-c" > "$out/transcript.txt" 2>&1 || rc=$?
cat "$out/transcript.txt"
printf 'Candidate C: exit=%d; evidence=%s\n' "$rc" "$out"
exit "$rc"
