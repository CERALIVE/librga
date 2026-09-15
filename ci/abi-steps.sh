#!/usr/bin/env bash
# Modified by CeraLive 2026-09-14: compare published R0 and R1 with one toolchain.
set -euo pipefail
root=$(realpath "$(dirname "${BASH_SOURCE[0]}")/..")
cd "$root"
export GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=safe.directory GIT_CONFIG_VALUE_0="$root"
source ci/target-suite.env
source ci/package-lto.env
export PACKAGED_LTO
source /etc/os-release
[[ $VERSION_CODENAME == "$TARGET_SUITE" && $(dpkg --print-architecture) == "$TARGET_ARCH" ]]
out="$root/test-results/abi"
mkdir -p "$out"
readonly r0=f4c3ee62ab354c2cbe22718f543fc0ba6e58365c
[[ $(git rev-parse '1.10.1+ceralive.1^{commit}') == "$r0" ]]
[[ ! -e "$out/r0" && ! -e "$out/build-r1" && ! -e "$out/build-r1-lto" && ! -e "$out/build-r1-selected" ]] || {
    printf 'ABI: use a fresh test-results/abi directory\n' >&2; exit 1;
}
mkdir -p "$out/r0"
git archive "$r0" | tar -x -C "$out/r0"
g++ --version
abidiff --version
export CC='ccache gcc' CXX='ccache g++' CFLAGS='-g -O2' CXXFLAGS='-g -O2'
unset CPPFLAGS LDFLAGS
for revision in r0 r1; do
    source_dir="$root"
    [[ $revision != r0 ]] || source_dir="$out/r0"
    meson setup "$out/build-$revision" "$source_dir" \
        --buildtype=debugoptimized -Db_lto=false -Dlibrga_demo=false
    meson compile -C "$out/build-$revision" rga:shared_library
done
bash tests/test-abi-gate.sh
bash ci/check-abi.sh "$out/build-r0/librga.so" "$out/build-r1/librga.so" "$out/abidiff.txt" \
    packaging/baseline-symbols-upstream-delta.txt

# Keep the non-LTO control above; only the candidate changes optimization here.
meson setup "$out/build-r1-lto" "$root" \
    --buildtype=debugoptimized -Db_lto=true -Dlibrga_demo=false
meson compile -C "$out/build-r1-lto" rga:shared_library
bash tests/test-dynsym-gate.sh | tee "$out/dynsym-controls.txt"
bash ci/check-lto-policy.sh "$out/build-r1/librga.so" "$out/build-r1-lto/librga.so" \
    "$out/dynsym-lto.diff" | tee "$out/dynsym-policy.txt"
meson setup "$out/build-r1-selected" "$root" \
    --buildtype=debugoptimized -Db_lto="$PACKAGED_LTO" -Dlibrga_demo=false
meson compile -C "$out/build-r1-selected" rga:shared_library
python3 ci/check-dynsym.py "$out/build-r1/librga.so" "$out/build-r1-selected/librga.so" \
    "$out/dynsym-selected.diff"
bash ci/check-abi.sh "$out/build-r0/librga.so" "$out/build-r1-lto/librga.so" "$out/abidiff-lto.txt" \
    packaging/baseline-symbols-upstream-delta.txt
bash ci/check-abi.sh "$out/build-r1/librga.so" "$out/build-r1-lto/librga.so" "$out/abidiff-lto-only.txt"
