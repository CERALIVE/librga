#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# Host-only extension of H1/H3. Build with scripts/build-sanitized.sh first.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/../.."
out=test-results/candidate-a
mkdir -p "$out"
out=$(mktemp -d "$out/run.XXXXXX")
printf 'Candidate A evidence: %s\n' "$out"
includes=(-Iinclude -Iim2d_api -Icore -Icore/hardware -Icore/utils
    -Icore/3rdparty/libdrm/include/drm -Icore/3rdparty/android_hal)
g++ -std=c++14 -g -O1 -fno-omit-frame-pointer -fsanitize=thread -fpermissive \
    "${includes[@]}" tests/repro/h1_init_race.cpp -Lbuild-tsan \
    -Wl,-rpath,"$PWD/build-tsan" -lrga -pthread -ldl -o build-tsan/candidate-a
g++ -std=c++14 -g -O1 -fno-omit-frame-pointer -fsanitize=address,undefined \
    -fpermissive "${includes[@]}" tests/repro/h3_init_fd_leak.cpp -Lbuild-asan \
    -Wl,-rpath,"$PWD/build-asan" -lrga -ldl -o build-asan/candidate-a-fds
export TSAN_OPTIONS='halt_on_error=0:exitcode=66:symbolize=0'
export ASAN_OPTIONS='verify_asan_link_order=0:detect_leaks=1'
export UBSAN_OPTIONS='print_stacktrace=1'
rc=0
env LD_PRELOAD="$PWD/build-tsan/libfake_rga.so" FAKE_RGA_LOG="$PWD/$out/canary.shim.txt" \
    build-tsan/tsan-canary > "$out/tsan-canary.txt" 2>&1 || rc=$?
[[ $rc == 66 ]] && grep -q 'WARNING: ThreadSanitizer: data race' "$out/tsan-canary.txt" || exit 2
rc=0
env LD_PRELOAD="$PWD/build-asan/libfake_rga.so" FAKE_RGA_LOG="$PWD/$out/canary.shim.txt" \
    build-asan/asan-canary > "$out/asan-canary.txt" 2>&1 || rc=$?
[[ $rc != 0 ]] && grep -q 'ERROR: AddressSanitizer: heap-buffer-overflow' "$out/asan-canary.txt" || exit 2
printf 'scenario,run,exit,tsan_report\n' > "$out/races.csv"
red=0
for scenario in c-init singleton-get direct-init; do
    for ((i=1; i<=20; i++)); do
        rc=0
        timeout 20s env LD_PRELOAD="$PWD/build-tsan/libfake_rga.so" \
            FAKE_RGA_LOG="$PWD/$out/$scenario-$i.shim.txt" \
            build-tsan/candidate-a "$scenario" > "$out/$scenario-$i.txt" 2>&1 || rc=$?
        report=0
        if grep -q 'WARNING: ThreadSanitizer:' "$out/$scenario-$i.txt"; then report=1; fi
        if [[ $rc != 0 && $rc != 1 && $rc != 66 ]] ||
            ! grep -q '^scenario=' "$out/$scenario-$i.txt"; then exit 2; fi
        printf '%s,%d,%d,%d\n' "$scenario" "$i" "$rc" "$report" >> "$out/races.csv"
        if [[ $scenario != direct-init && ( $rc != 0 || $report != 0 ) ]]; then exit 2; fi
        if ((rc || report)); then red=1; fi
    done
done
for api in RgaInit improcess; do
    for knob in hwversion unset; do
        injection=()
        [[ $knob == unset ]] || injection=(FAKE_RGA_FAIL=hwversion FAKE_RGA_ERRNO=5)
        rc=0
        timeout 120s env LD_PRELOAD="$PWD/build-asan/libfake_rga.so" "${injection[@]}" \
            FAKE_RGA_LOG="$PWD/$out/$api-$knob.shim.txt" \
            build-asan/candidate-a-fds "$api" "$out/$api-$knob.csv" \
            > "$out/$api-$knob.txt" 2>&1 || rc=$?
        if [[ $rc != 0 && $rc != 1 ]] || ! grep -q 'iterations=1000' "$out/$api-$knob.txt"; then exit 2; fi
        [[ $knob != unset || $rc == 0 ]] || exit 2
        if ((rc)); then red=1; fi
        grep 'iterations=1000' "$out/$api-$knob.txt"
    done
done
printf 'Candidate A: exit=%d; per-process evidence in %s\n' "$red" "$out"
exit "$red"
