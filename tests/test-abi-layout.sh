#!/usr/bin/env bash
# Modified by CeraLive 2026-09-16: prove the frozen LP64 size assertions in C and C++.
set -euo pipefail
root=$(realpath "$(dirname "${BASH_SOURCE[0]}")/..")
mkdir -p "$root/test-results"
scratch=$(mktemp -d "$root/test-results/abi-layout.XXXXXX")
trap 'rm -rf "$scratch"' EXIT
cp "$root/include/drmrga.h" "$root/im2d_api/im2d_type.h" "$scratch/"
printf '#include <stddef.h>\n#include "drmrga.h"\n#include "im2d_type.h"\n' >"$scratch/layout.c"
flags=(-fsyntax-only -I"$scratch" -I"$root/include" -I"$root/im2d_api")
for compiler in gcc g++; do
    language=c; standard=c11
    [[ $compiler != g++ ]] || { language=c++; standard=c++14; }
    "$compiler" -x "$language" -std="$standard" "${flags[@]}" "$scratch/layout.c"
    for header in drmrga.h im2d_type.h; do
        case "$header" in
            drmrga.h) source="$root/include/$header"; before=378; after=386; type=rga_info_t ;;
            im2d_type.h) source="$root/im2d_api/$header"; before=88; after=96; type=im_opt_t ;;
        esac
        grep -Fq "char reserve[$before]" "$source"
        sed "s/char reserve\[$before\]/char reserve[$after]/" "$source" >"$scratch/$header"
        rc=0
        "$compiler" -x "$language" -std="$standard" "${flags[@]}" "$scratch/layout.c" \
            >"$scratch/mutant.log" 2>&1 || rc=$?
        [[ $rc == 1 ]] || { printf 'FAIL: %s %s mutation exit=%s\n' "$compiler" "$type" "$rc" >&2; exit 1; }
        grep -F "$type must retain the R0 ABI size" "$scratch/mutant.log"
        printf 'RED: %s %s reserve +8 bytes: compiler exit=%s\n' "$compiler" "$type" "$rc"
        cp "$source" "$scratch/$header"
        "$compiler" -x "$language" -std="$standard" "${flags[@]}" "$scratch/layout.c"
        printf 'GREEN: %s restored %s: compiler exit=0\n' "$compiler" "$type"
    done
done
