#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
set -euo pipefail
ulimit -c 0

root=$(realpath "$(dirname "${BASH_SOURCE[0]}")/../..")
cd "$root"
mode=${1:-}
iterations=${2:-200}
fail() { printf 'H2: %s\n' "$*" >&2; exit 2; }
case "$mode" in
    asan) sanitize=address,undefined ;;
    tsan) sanitize=thread ;;
    *) fail "usage: bash tests/repro/run-h2.sh {asan|tsan} [iterations=200]" ;;
esac
[[ $# -le 2 && $iterations =~ ^[1-9][0-9]{0,4}$ ]] || fail 'iterations must be 1..99999'
[[ -z ${LD_PRELOAD:-} ]] || fail 'unset LD_PRELOAD; the driver selects its own shim'
for variable in "${!FAKE_RGA_@}"; do unset "$variable"; done
for tool in g++ timeout; do command -v "$tool" >/dev/null || fail "missing tool: $tool"; done
build="$root/build-$mode"
for artifact in librga.so.2.1.0 libfake_rga.so "$mode-canary"; do
    [[ -f $build/$artifact ]] || fail "run bash scripts/build-sanitized.sh $mode first (missing $artifact)"
done
mkdir -p "test-results/h2/$mode"
out=$(mktemp -d "$root/test-results/h2/$mode/run.XXXXXX")
printf 'H2 evidence: %s\n' "$out"

g++ -std=c++14 -DLINUX=1 -O0 -g -fno-omit-frame-pointer \
    -Wall -Wextra -Werror -Wno-pedantic "-fsanitize=$sanitize" \
    -Iinclude -Iim2d_api -Icore -Icore/hardware -Icore/3rdparty/android_hal \
    tests/repro/h2_teardown_race.cpp -L"$build" "-Wl,-rpath,$build" \
    -lrga -ldl -pthread -o "$build/h2-teardown-race" >"$out/compile.log" 2>&1 \
    || fail "test compilation failed; see $out/compile.log"

# Online TSan symbolization stalled some shim-preloaded processes on the host.
# Keep raw module offsets for offline addr2line; do not suppress any diagnostics.
run_env=(env "LD_PRELOAD=$build/libfake_rga.so" "LD_LIBRARY_PATH=$build"
    'ROCKCHIP_RGA_LOG=0'
    'ASAN_OPTIONS=detect_leaks=1:verify_asan_link_order=0:abort_on_error=1'
    'UBSAN_OPTIONS=print_stacktrace=1:halt_on_error=1'
    'TSAN_OPTIONS=halt_on_error=1:exitcode=66:symbolize=0')
canary_rc=0
timeout --kill-after=2s 10s "${run_env[@]}" \
    'UBSAN_OPTIONS=print_stacktrace=1:halt_on_error=0' \
    "FAKE_RGA_LOG=$out/canary-shim.log" "$build/$mode-canary" \
    >"$out/canary.log" 2>&1 || canary_rc=$?
[[ $canary_rc -ne 0 && $canary_rc -ne 124 && $canary_rc -ne 137 ]] \
    || fail "canary did not report normally (exit $canary_rc); see $out/canary.log"
if [[ $mode == asan ]]; then
    if ! grep -q 'ERROR: AddressSanitizer: heap-buffer-overflow' "$out/canary.log" \
        || ! grep -q 'runtime error: signed integer overflow' "$out/canary.log"; then
        fail "ASan/UBSan interception is unproven; see $out/canary.log"
    fi
else
    grep -q 'WARNING: ThreadSanitizer: data race' "$out/canary.log" \
        || fail "TSan interception is unproven; see $out/canary.log"
fi
{
    date -u '+started=%Y-%m-%dT%H:%M:%SZ'
    uname -sm
    g++ --version
    printf 'mode=%s iterations_per_scenario=%s canary_exit=%s\n' "$mode" "$iterations" "$canary_rc"
    printf '%s\n' "${run_env[@]}"
    sha256sum "$build/librga.so.2.1.0" "$build/libfake_rga.so" "$build/h2-teardown-race"
} >"$out/environment.txt"
printf 'scenario,iteration,exit_code,action_reached,blit_ioctls,outcome\n' >"$out/results.csv"
printf 'scenario,iterations,clean,sanitizer,other_failure,invalid\n' >"$out/summary.csv"
verdict=0
for scenario in deinit exit; do
    clean=0 sanitizer=0 other=0 invalid=0
    for ((iteration = 1; iteration <= iterations; ++iteration)); do
        stem="$out/$scenario-$iteration"
        rc=0
        timeout --kill-after=2s 10s "${run_env[@]}" "FAKE_RGA_LOG=$stem.shim.log" \
            "$build/h2-teardown-race" "$scenario" >"$stem.log" 2>&1 || rc=$?
        action=no
        grep -q "^H2 action=$scenario successful_blits=" "$stem.log" && action=yes
        blits=0
        if [[ -f $stem.shim.log ]]; then
            blits=$(grep -c '^ioctl RGA_BLIT_SYNC fd=[0-9]* ret=0 errno=0$' "$stem.shim.log" || true)
        fi
        if [[ $action != yes || $blits -lt 33 ]]; then
            outcome=invalid
            ((invalid += 1))
        elif grep -Eq 'ERROR: (AddressSanitizer|LeakSanitizer):|WARNING: ThreadSanitizer:|runtime error:|AddressSanitizer:DEADLYSIGNAL' "$stem.log"; then
            outcome=sanitizer
            ((sanitizer += 1))
        elif [[ $rc -ne 0 ]]; then
            outcome='other-failure'
            ((other += 1))
        elif [[ $scenario == deinit ]] && ! grep -q '^H2 complete=deinit ' "$stem.log"; then
            outcome=invalid
            ((invalid += 1))
        else
            outcome=clean
            ((clean += 1))
        fi
        printf '%s,%d,%d,%s,%d,%s\n' "$scenario" "$iteration" "$rc" "$action" "$blits" "$outcome" \
            >>"$out/results.csv"
    done
    printf '%s,%d,%d,%d,%d,%d\n' "$scenario" "$iterations" "$clean" "$sanitizer" "$other" "$invalid" \
        | tee -a "$out/summary.csv"
    if ((invalid > 0)); then verdict=2;
    elif ((sanitizer + other > 0 && verdict == 0)); then verdict=1; fi
done
printf 'H2 driver exit=%d (0=no finding, 1=finding/failure, 2=invalid run); logs: %s\n' "$verdict" "$out"
exit "$verdict"
