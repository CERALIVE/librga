#!/usr/bin/env bash
# Modified by CeraLive 2026-09-14: gate matched DWARF builds on abidiff incompatibility.
set -euo pipefail
[[ $# == 3 || $# == 4 ]] || { printf 'usage: %s OLD_SO NEW_SO REPORT [ACCEPTED_REMOVALS_TSV]\n' "$0" >&2; exit 2; }
old=$1 new=$2 report=$3
expected=${4:-/dev/null}
root=$(realpath "$(dirname "${BASH_SOURCE[0]}")/..")
export LC_ALL=C
for library in "$old" "$new"; do
    readelf -SW "$library" | grep -F '.debug_info' >/dev/null || {
        printf 'ABI: missing DWARF: %s\n' "$library" >&2; exit 1;
    }
    objdump -p "$library" | grep -E 'SONAME[[:space:]]+librga.so.2$' >/dev/null || {
        printf 'ABI: wrong SONAME: %s\n' "$library" >&2; exit 1;
    }
done
rc=0
abidiff --no-default-suppression "$old" "$new" >"$report" 2>&1 || rc=$?
cat "$report"
printf 'abidiff exit=%d (error=1, usage=2, change=4, incompatible=8)\n' "$rc"
(( (rc & 3) == 0 && rc <= 15 )) || exit 1
python3 "$root/ci/abi-removals.py" "$report" "$expected" "$report.abignore"
if [[ -s "$report.abignore" ]]; then
    rc=0
    abidiff --no-default-suppression --suppr "$report.abignore" "$old" "$new" >"$report.accepted" 2>&1 || rc=$?
    cat "$report.accepted"
    printf 'abidiff after accepted removals exit=%d\n' "$rc"
fi
(( (rc & 11) == 0 && rc <= 15 ))
