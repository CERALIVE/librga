#!/bin/sh
# SPDX-License-Identifier: Apache-2.0
#
# Build and run the two H9 reproducers against the host shim. No hardware is
# touched: tests/shim/fake_rga.c interposes open()/ioctl() on /dev/rga.
#
# This builds the library sources directly rather than through meson, because
# the meson `rga-golden-host` target does not compile on an x86_64 host: the
# non-aarch64 arm of the `#if defined(__arm64__) || defined(__aarch64__)`
# blocks casts `void *` to `unsigned int`, which GCC 14 rejects as
# "loses precision [-fpermissive]". That refusal is itself part of the H9
# evidence, so it is recorded rather than worked around in the tree.
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
build=${H9_BUILD_DIR:-$root/build-h9-repro}
mkdir -p "$build"

incs="-I$root/include -I$root/im2d_api -I$root/core -I$root/core/hardware \
-I$root/core/utils -I$root/core/3rdparty/libdrm/include/drm \
-I$root/core/3rdparty/android_hal -I$root -I$root/im2d_api/src"

srcs="core/utils/android_utils/src/android_utils.cpp
core/utils/drm_utils/src/drm_utils.cpp
core/utils/utils.cpp
core/GrallocOps.cpp
core/NormalRgaApi.cpp
core/NormalRga.cpp
core/RgaUtils.cpp
core/RgaUtils_symbol.cpp
core/RockchipRga.cpp
core/RgaApi.cpp
core/rga_sync.cpp
im2d_api/src/im2d_log.cpp
im2d_api/src/im2d_debugger.cpp
im2d_api/src/im2d_context.cpp
im2d_api/src/im2d_job.cpp
im2d_api/src/im2d_impl.cpp
im2d_api/src/im2d.cpp"

objs=""
for src in $srcs; do
    obj=$build/$(echo "$src" | tr / _).o
    if [ ! -f "$obj" ] || [ "$root/$src" -nt "$obj" ]; then
        # shellcheck disable=SC2086
        g++ -std=gnu++14 -g -O0 -w -fpermissive -DLINUX=1 \
            -ftrivial-auto-var-init=zero $incs -c "$root/$src" -o "$obj"
    fi
    objs="$objs $obj"
done
# shellcheck disable=SC2086
ar rcs "$build/librga-h9.a" $objs

shim=$build/libfake_rga.so
# shellcheck disable=SC2086
gcc -std=gnu11 -g -O0 -shared -fPIC $incs \
    "$root/tests/shim/fake_rga.c" -o "$shim" -ldl -lpthread

for name in h9_address h9_stdout; do
    # shellcheck disable=SC2086
    g++ -std=gnu++14 -g -O0 -Wall -Wextra $incs \
        "$root/tests/repro/$name.cpp" "$build/librga-h9.a" \
        -ldl -lpthread -o "$build/$name"
done

work=$(mktemp -d "${TMPDIR:-/tmp}/h9.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM

echo "=== host ==="
uname -m
g++ --version | head -1

echo
echo "=== h9_address ==="
env LD_PRELOAD="$shim" FAKE_RGA_DUMP="$work/request" \
    FAKE_RGA_LOG="$work/interposed.log" "$build/h9_address"
echo "--- interposed ioctl log ---"
cat "$work/interposed.log" 2>/dev/null || echo "(no log)"

echo
echo "=== h9_stdout (no shim: /dev/rga absent) ==="
"$build/h9_stdout"

echo
echo "=== h9_stdout (under shim: /dev/rga opens, so the 1x1 size check runs) ==="
env LD_PRELOAD="$shim" FAKE_RGA_DUMP="$work/stdout-request" \
    FAKE_RGA_LOG="$work/stdout.log" "$build/h9_stdout"
