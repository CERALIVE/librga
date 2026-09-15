#!/usr/bin/env bash
# Modified by CeraLive 2026-09-14: gate matched DWARF builds on abidiff incompatibility.
set -euo pipefail
[[ $# == 3 ]] || { printf 'usage: %s OLD_SO NEW_SO REPORT\n' "$0" >&2; exit 2; }
old=$1 new=$2 report=$3
for library in "$old" "$new"; do
    readelf -SW "$library" | grep -F '.debug_info' >/dev/null || {
        printf 'ABI: missing DWARF: %s\n' "$library" >&2; exit 1;
    }
    objdump -p "$library" | grep -E 'SONAME[[:space:]]+librga.so.2$' >/dev/null || {
        printf 'ABI: wrong SONAME: %s\n' "$library" >&2; exit 1;
    }
done
rc=0
abidiff "$old" "$new" >"$report" 2>&1 || rc=$?
cat "$report"
printf 'abidiff exit=%d (error=1, usage=2, change=4, incompatible=8)\n' "$rc"
(( (rc & 11) == 0 && rc <= 15 ))
