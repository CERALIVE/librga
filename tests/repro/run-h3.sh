#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/../.."
build="$PWD/build-host"
out="$PWD/test-results/h3"
mkdir -p "$out"
if [[ ! -f "$build/build.ninja" ]]; then
    meson setup "$build" -Dcpp_args=-fpermissive > "$out/setup.txt" 2>&1
fi
meson compile -C "$build" rga:shared_library fake_rga > "$out/build.txt" 2>&1
"${CXX:-g++}" -std=c++14 -Wall -Wextra -Werror \
    -Iinclude -Iim2d_api -Icore -Icore/hardware -Icore/3rdparty/android_hal \
    tests/repro/h3_init_fd_leak.cpp -L"$build" -Wl,-rpath,"$build" -lrga -ldl \
    -o "$build/h3-init-fd-leak" >> "$out/build.txt" 2>&1

# Reject inherited controls rather than silently run a different experiment.
if env | grep -qE '^(LD_PRELOAD|FAKE_RGA_[A-Z_]+)='; then
    printf 'Run H3 without inherited LD_PRELOAD/FAKE_RGA_* variables\n' >&2
    exit 2
fi
printf 'knob,api,iteration,status,errno,before,after,delta,cumulative_delta\n' > "$out/fdcensus.csv"
cp "$out/fdcensus.csv" "$out/control-fdcensus.csv"
: > "$out/summary.txt"
red=0
for knob in hwversion driverversion getinfo unset; do
    for api in c_RkRgaInit improcess; do
        csv="$out/fdcensus.csv"
        injection=("FAKE_RGA_FAIL=$knob")
        if [[ $knob == unset ]]; then
            csv="$out/control-fdcensus.csv"
            injection=()
        fi
        log="$out/$knob-$api.interposed.log"
        : > "$log"
        rc=0
        timeout 60s env LD_PRELOAD="$build/libfake_rga.so" FAKE_RGA_LOG="$log" \
            FAKE_RGA_ERRNO=5 "${injection[@]}" \
            "$build/h3-init-fd-leak" "$api" "$csv" \
            > "$out/$knob-$api.txt" 2>&1 || rc=$?
        if (( rc > 1 )) || [[ $knob == unset && $rc != 0 ]]; then
            printf 'H3 infrastructure/control failure: %s/%s exit %d; see %s\n' \
                "$knob" "$api" "$rc" "$out/$knob-$api.txt" >&2
            exit 2
        fi
        if (( rc == 1 )); then red=1; fi
        grep '^.*iterations=1000,.*verdict=' "$out/$knob-$api.txt" >> "$out/summary.txt"
        if grep -q 'open /dev/rga fd=-1' "$log"; then
            printf 'H3 fd exhaustion invalidates the census: %s\n' "$log" >&2
            exit 2
        fi
    done
done
cat "$out/summary.txt"
printf 'H3 overall: %s (exit 1 means reproduced leak, exit 2 means invalid run)\n' \
    "$([[ $red == 1 ]] && printf RED || printf NOT-REPRODUCED)"
exit "$red"
