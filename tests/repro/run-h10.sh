#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# Host-only characterization: exit 0 = no finding, 1 = finding, 2 = invalid run.
# Modified by CeraLive 2026-09-06: retain per-case evidence and runtime canaries.
set -euo pipefail
root=$(realpath "$(dirname "${BASH_SOURCE[0]}")/../..")
cd "$root"
mode=${1:-asan}
case "$mode" in
    asan) sanitizer=address,undefined ;;
    tsan) sanitizer=thread ;;
    *) printf 'usage: %s asan|tsan\n' "$0" >&2; exit 2 ;;
esac
unset LD_PRELOAD
for variable in "${!FAKE_RGA_@}"; do unset "$variable"; done
mkdir -p "$root/test-results/h10"
out=$(mktemp -d "$root/test-results/h10/$mode-XXXXXXXX")
printf 'H10 evidence: %s\n' "$out"
trap 'printf "H10 harness failed at line %s; see %s\n" "$LINENO" "$out" >&2; exit 2' ERR
bash scripts/build-sanitized.sh "$mode" >"$out/build.txt" 2>&1
build="$root/build-$mode"
g++ -std=c++14 -O1 -g -fPIC -fno-omit-frame-pointer -fsanitize="$sanitizer" \
    -Wall -Wextra -Werror -Wno-pedantic -pthread \
    -Iinclude -Iim2d_api -Iim2d_api/src -Icore -Icore/hardware \
    tests/repro/h10_job_handle.cpp -L"$build" -Wl,-rpath,"$build" -lrga -ldl \
    -o "$build/h10_job_handle" >"$out/compile.txt" 2>&1

runtime_env=("LD_PRELOAD=$build/libfake_rga.so"
    'ASAN_OPTIONS=verify_asan_link_order=0:detect_leaks=1:halt_on_error=1:symbolize=0'
    'TSAN_OPTIONS=halt_on_error=1:exitcode=66:symbolize=0')
declare -A statuses
printf 'case\texit\n' >"$out/status.tsv"
run() {
    local name=$1
    shift
    # Do not preload the shim into timeout or shell utilities.
    mkdir -p "$out/$name"
    : >"$out/$name/interposed.log"
    : >"$out/$name/requests.bin"
    local status=0
    local ubsan_halt=1
    [[ $name == canary ]] && ubsan_halt=0
    timeout -k 5s 30s env "${runtime_env[@]}" \
        "UBSAN_OPTIONS=print_stacktrace=1:halt_on_error=$ubsan_halt:symbolize=0" \
        "FAKE_RGA_LOG=$out/$name/interposed.log" \
        "FAKE_RGA_DUMP=$out/$name/requests.bin" "$@" \
        >"$out/$name/transcript.txt" 2>&1 || status=$?
    statuses[$name]=$status
    printf '%s\t%d\n' "$name" "$status" >>"$out/status.tsv"
    printf '%s: exit %d (%s/%s/transcript.txt)\n' "$name" "$status" "$out" "$name"
}
run canary "$build/$mode-canary"
run control "$build/h10_job_handle" control
run count "$build/h10_job_handle" count
run release "$build/h10_job_handle" release
run race-1 "$build/h10_job_handle" race 2000
run race-2 "$build/h10_job_handle" race 2000

invalid=0
finding=0
if [[ $mode == asan ]]; then
    grep -Fq 'ERROR: AddressSanitizer: heap-buffer-overflow' "$out/canary/transcript.txt" || invalid=1
    grep -Fq 'runtime error: signed integer overflow' "$out/canary/transcript.txt" || invalid=1
else
    grep -Fq 'WARNING: ThreadSanitizer: data race' "$out/canary/transcript.txt" || invalid=1
fi
[[ ${statuses[canary]} != 0 && ${statuses[control]} == 0 ]] || invalid=1
for name in count release race-1 race-2; do
    if [[ ${statuses[$name]} != 0 && ${statuses[$name]} != 1 && ${statuses[$name]} != 66 ]]; then
        invalid=1
    elif grep -Eq 'ERROR: AddressSanitizer:|WARNING: ThreadSanitizer:|runtime error:' "$out/$name/transcript.txt"; then
        finding=1
    elif [[ ${statuses[$name]} == 0 || ${statuses[$name]} == 1 ]] &&
         grep -Eq '^H10a |^H10c |^H10b completed=2000 ' "$out/$name/transcript.txt"; then
        [[ ${statuses[$name]} == 1 ]] && finding=1
    else
        invalid=1
    fi
done
if ((invalid)); then
    printf 'INVALID-RUN: canary, control, or case failed; inspect %s/status.tsv and transcripts.\n' "$out"
    exit 2
fi
printf 'H10 complete: finding=%d; host-shim-only. Inspect %s/status.tsv and transcripts.\n' "$finding" "$out"
exit "$finding"
