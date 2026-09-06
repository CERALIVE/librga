#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
#
# H4 host leg. Two measurements, both on the fake_rga shim, neither touching
# hardware:
#
#   1. getenv() calls made by the library over 1000 c_RkRgaBlit() calls and
#      over 1000 improcess() calls, read out of the shim's counter.
#   2. A callgrind profile over 5000 improcess() calls using the golden G1
#      geometry (4K NV16 -> NV12), if valgrind is installed. If it is not, the
#      script says so and skips -- it installs nothing.
#
# The board leg of H4 (the microsecond-level userspace-vs-hardware split) needs
# real silicon and is deliberately absent here. It is added as a separate
# script and separate ledger rows; nothing below has to change for it to land.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/../.."

build=build-h4
out=test-results/h4
iterations=${H4_ITERATIONS:-1000}
profile_iterations=${H4_PROFILE_ITERATIONS:-5000}

mkdir -p "$out"

# -fpermissive for the documented reason in docs/SANITIZERS.md: the library
# casts void* to unsigned int, which a 64-bit host build rejects outright.
if [[ ! -d $build ]]; then
    meson setup "$build" -Dcpp_args=-fpermissive >"$out/meson-setup.log" 2>&1
fi
meson compile -C "$build" fake_rga rga-golden-host >"$out/meson-compile.log" 2>&1

shim=$build/libfake_rga.so
client=$build/h4_getenv_count
test -f "$shim"

g++ -std=gnu++17 -O2 -fpermissive -w \
    -Iinclude -Iim2d_api -Icore -Icore/hardware -Icore/3rdparty/android_hal \
    tests/repro/h4_getenv_count.cpp -o "$client" \
    "$build/librga-golden-host.a" -lpthread -ldl

# The shim's counter is process-global and is flushed by a destructor, so each
# mode is measured in its own process against its own counter file.
measure() {
    local mode=$1 count_file="$out/getenv-$1.count"
    rm -f "$count_file"
    env LD_PRELOAD="$PWD/$shim" \
        FAKE_RGA_GETENV_COUNT="$PWD/$count_file" \
        FAKE_RGA_LOG="$PWD/$out/interposed-$mode.log" \
        "$client" "$mode" "$iterations" >/dev/null
    printf '%s: %s getenv() calls over %s operations\n' \
        "$mode" "$(cat "$count_file")" "$iterations"
}

printf '=== H4 (a) getenv counter over calls ===\n'
measure blit
measure improcess

printf '\n=== H4 (b) callgrind profile, G1 geometry ===\n'
if ! command -v valgrind >/dev/null 2>&1; then
    printf 'valgrind not available on this host: profile leg SKIPPED (nothing installed)\n'
    printf 'valgrind not available on this host: profile leg SKIPPED\n' \
        > "$out/callgrind.txt"
elif ! command -v callgrind_annotate >/dev/null 2>&1; then
    printf 'callgrind_annotate not available on this host: profile leg SKIPPED\n'
    printf 'callgrind_annotate not available on this host: profile leg SKIPPED\n' \
        > "$out/callgrind.txt"
else
    rm -f "$out"/callgrind.out.*
    env LD_PRELOAD="$PWD/$shim" \
        FAKE_RGA_GETENV_COUNT="$PWD/$out/getenv-profile.count" \
        FAKE_RGA_LOG="$PWD/$out/interposed-profile.log" \
        valgrind --tool=callgrind \
        --callgrind-out-file="$PWD/$out/callgrind.out.%p" \
        "$client" improcess "$profile_iterations" >/dev/null
    callgrind_annotate --inclusive=yes "$out"/callgrind.out.* \
        | head -15 > "$out/callgrind.txt"
    cat "$out/callgrind.txt"
fi
