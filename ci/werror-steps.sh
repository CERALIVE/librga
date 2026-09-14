#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# Modified by CeraLive 2026-09-14: unsuppressed warning gate for owned translation units.
set -euo pipefail
root=$(realpath "$(dirname "${BASH_SOURCE[0]}")/..")
cd "$root"
if [[ ${SKIP_DEPS:-0} != 1 ]]; then
    apt-get update
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        g++ ccache meson ninja-build pkg-config python3 curl ca-certificates
fi
source ci/target-suite.env
source /etc/os-release
[[ ${VERSION_CODENAME:-} == "$TARGET_SUITE" ]] || exit 2
[[ $(dpkg --print-architecture) == "$TARGET_ARCH" ]] || exit 2
out=test-results/werror
mkdir -p "$out"
exec > >(tee "$out/transcript.txt") 2>&1
g++ --version
printf 'Scope: im2d_context.cpp and CeraLive test/reproducer TUs; not the whole inherited library.\n'
printf 'Excluded: deliberate sanitizer canaries and generated-header island emitter (separate UAPI gate).\n'
flags=(-Wall -Wextra -Werror -O0 -g -fPIC -pthread -DLINUX=1
    -I. -Iinclude -Iim2d_api -Iim2d_api/src -Icore -Icore/hardware -Icore/utils
    -Icore/3rdparty/libdrm/include/drm -Icore/3rdparty/android_hal)
# A warning-only negative control proves neither compiler is globally silenced.
for compiler in gcc g++; do
    if printf 'int main(void) { int unused; return 0; }\n' |
        "$compiler" -x "$( [[ $compiler == gcc ]] && printf c || printf c++ )" \
        "${flags[@]}" -c -o "$out/canary.o" - >"$out/$compiler-canary.txt" 2>&1; then
        printf 'FAIL: %s accepted the warning canary\n' "$compiler"
        exit 1
    fi
    grep -Fq 'unused-variable' "$out/$compiler-canary.txt"
done
shopt -s globstar nullglob
sources=(im2d_api/src/im2d_context.cpp tests/**/*.c tests/**/*.cpp)
count=0
for source in "${sources[@]}"; do
    case "$source" in
        tests/shim/*-canary.c|tests/uapi-parity/island_side.c) continue ;;
    esac
    compiler=gcc; standard=gnu11
    [[ $source == *.cpp ]] && { compiler=g++; standard=c++14; }
    printf 'WERROR %s\n' "$source"
    ccache "$compiler" "-std=$standard" "${flags[@]}" -c "$source" \
        -o "$out/${source//\//_}.o"
    count=$((count + 1))
done
((count > 1))
printf 'PASS: %d translation units, -Wall -Wextra -Werror, no suppression flags.\n' "$count"
