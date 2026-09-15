#!/usr/bin/env bash
# Modified by CeraLive 2026-09-14: prepare measurement-only H4 variants, never packages.
set -euo pipefail
root=$(realpath "$(dirname "${BASH_SOURCE[0]}")/..")
cd "$root"
out="$root/test-results/mtune"
mkdir -p "$out"
export CC='ccache gcc' CXX='ccache g++'
unset CPPFLAGS LDFLAGS
for variant in generic cortex-a76; do
    tune=''
    [[ $variant != cortex-a76 ]] || tune='-mtune=cortex-a76'
    export CFLAGS="-g -O2 $tune" CXXFLAGS="-g -O2 $tune"
    meson setup "$out/$variant" "$root" --buildtype=debugoptimized -Db_lto=false -Dlibrga_demo=false
    meson compile -C "$out/$variant" rga:shared_library
done
{
    printf 'MEASUREMENT ONLY: ELF sizes, not an H4 timing or performance verdict.\n'
    g++ --version
    size "$out/generic/librga.so.2.1.0" "$out/cortex-a76/librga.so.2.1.0"
    printf 'H4 microseconds/frame: NOT RUN (board gate outside todo 41).\n'
    printf 'Both variants are unpackaged; no tuning adoption or acceptance threshold.\n'
} | tee "$out/measurement.txt"
