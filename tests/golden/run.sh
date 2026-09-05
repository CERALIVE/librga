#!/bin/sh
set -eu
regen=false
if [ "${1:-}" = --regen ]; then regen=true; shift; fi
if [ "$#" -ne 4 ]; then
    printf '%s\n' 'usage: run.sh [--regen] CASES SHIM FIXTURE_DIR G1..G8' >&2
    exit 2
fi
cases=$1 shim=$2 fixtures=$3 name=$4
case "$name" in G[1-8]) ;; *) exit 2 ;; esac
test -f "$shim"
test -x "$cases"
work=$(mktemp -d "${TMPDIR:-.}/golden-$name.XXXXXX")
work=$(realpath "$work")
trap 'rm -rf "$work"' EXIT HUP INT TERM

run_case() {
    dump=$1 log=$2
    rm -f "$work/getenv-count"
    env LD_PRELOAD="$shim" FAKE_RGA_DUMP="$dump" FAKE_RGA_LOG="$log" \
        FAKE_RGA_GETENV_COUNT="$work/getenv-count" "$cases" "$name"
    test -s "$dump"
    test -s "$log"
    test "$(cat "$work/getenv-count")" -gt 0
    if ! grep -Eq '^open(at)? /dev/rga fd=[0-9]+$' "$log"; then
        printf '%s: no successful interposed open\n' "$name" >&2; exit 1
    fi
    awk '$1 == "ioctl" {print $2, $4, $5}' "$log" > "$work/sequence"
    printf '%s\n' \
        'RGA_IOC_GET_DRVIER_VERSION ret=1 errno=0' \
        'RGA_IOC_GET_HW_VERSION ret=1 errno=0' \
        'RGA_BLIT_SYNC ret=0 errno=0' > "$work/expected-sequence"
    if ! cmp "$work/expected-sequence" "$work/sequence"; then
        printf '%s: unexpected interposed ioctl sequence\n' "$name" >&2
        cat "$log" >&2
        exit 1
    fi
}

run_case "$work/request" "$work/interposed.log"
if [ "$name" = G1 ]; then
    run_case "$work/request-again" "$work/interposed-again.log"
    cmp "$work/request" "$work/request-again"
    printf '%s\n' 'G1: independent-process cmp identical'
fi
if "$regen"; then
    od -An -v -tx1 "$work/request" > "$fixtures/$name.bin"
fi
"$cases" --verify "$name" "$work/request" "$fixtures/$name.bin"
cat "$work/interposed.log"
