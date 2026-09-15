#!/usr/bin/env bash
# Modified by CeraLive 2026-09-15: a failed LTO qualification forbids shipping LTO.
set -euo pipefail
root=$(realpath "$(dirname "${BASH_SOURCE[0]}")/..")
case "${PACKAGED_LTO:?PACKAGED_LTO must be explicit}" in
    true|false) ;;
    *) exit 2 ;;
esac
status=0
python3 "$root/ci/check-dynsym.py" "$@" || status=$?
case $status in
    0) printf 'LTO_DYNSYM=PASS\nPACKAGED_LTO=%s\n' "$PACKAGED_LTO" ;;
    1)
        printf 'LTO_DYNSYM=FAIL\nPACKAGED_LTO=%s\n' "$PACKAGED_LTO"
        [[ $PACKAGED_LTO == false ]] || exit 1
        printf 'LTO is disqualified; only non-LTO packaging is permitted.\n'
        ;;
    *) exit 2 ;;
esac
