#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
set -euo pipefail

rga_conversion_logged() {
    grep -Eq 'converted with RGA|using RGA converted buffer' "$1" &&
        ! grep -q 'RGA_BLIT fail' "$1"
}

if [[ ${1:-} == --selftest ]]; then
    scratch=$(mktemp -d)
    trap 'rm -rf "$scratch"' EXIT
    printf '%s\n' 'DEBUG mpp gstmpp.c: converted with RGA' > "$scratch/legacy"
    printf '%s\n' 'DEBUG mppenc gstmppenc.c: using RGA converted buffer' > "$scratch/im2d"
    printf '%s\n' 'WARN mpp gstmpp.c: RGA enabled' > "$scratch/enabled"
    printf '%s\n' 'DEBUG mpp gstmpp.c: converted with RGA' 'RGA_BLIT fail: -1' > "$scratch/failed"
    : > "$scratch/empty"
    for fixture in legacy im2d; do
        rga_conversion_logged "$scratch/$fixture" || { printf 'FAIL: %s success rejected\n' "$fixture" >&2; exit 1; }
    done
    for fixture in enabled failed empty; do
        if rga_conversion_logged "$scratch/$fixture"; then
            printf 'FAIL: %s is not conversion proof\n' "$fixture" >&2
            exit 1
        fi
    done
    printf 'PASS: legacy and im2d success required; enable-only, failure and empty rejected\n'
else
    [[ $# == 1 ]] || exit 2
    rga_conversion_logged "$1"
fi
