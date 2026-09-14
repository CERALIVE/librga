#!/usr/bin/env bash
set -euo pipefail
root=$(realpath "$(dirname "$0")/..")
cd "$root"

asan=0
for arg in "$@"; do
    case "$arg" in
        --asan) asan=1 ;;
        *) printf 'usage: %s [--asan]\n' "$0" >&2; exit 2 ;;
    esac
done

export QEMU_LD_PREFIX=${QEMU_LD_PREFIX:-/usr/aarch64-linux-gnu}

# --- the static-ASan board variant ------------------------------------------------
#
# TSan is deliberately absent and stays absent: it cannot be statically linked
# reliably, so there is no board-side TSan and no TSan row may ever be recorded
# against hardware. ASan can be static-linked, which is the only reason a board
# leg is conceivable at all — nothing has to be installed on the board.
#
# THE PREFLIGHT IS THE WHOLE POINT. `-print-file-name=X` prints the resolved path
# when the toolchain has X and echoes the bare name X when it does not. A bare
# `libasan.a` therefore means the cross toolchain ships no static ASan runtime,
# and the honest record is NOT-AVAILABLE — not a silently dynamic link, and
# certainly not a claim of board sanitizer coverage.
if ((asan)); then
    command -v aarch64-linux-gnu-gcc >/dev/null || { printf 'missing tool: aarch64-linux-gnu-gcc\n' >&2; exit 77; }
    out=$root/build-aarch64/asan
    mkdir -p "$out"
    resolved=$(aarch64-linux-gnu-gcc -print-file-name=libasan.a)
    {
        printf 'command  : aarch64-linux-gnu-gcc -print-file-name=libasan.a\n'
        printf 'output   : %s\n' "$resolved"
        printf 'compiler : %s\n' "$(aarch64-linux-gnu-gcc --version | sed -n 1p)"
        printf 'date     : %s\n' "$(date -u +%FT%TZ)"
    } >"$out/PREFLIGHT.txt"
    if [[ $resolved == libasan.a || ! -f $resolved ]]; then
        printf 'verdict  : NOT-AVAILABLE\n' >>"$out/PREFLIGHT.txt"
        cat "$out/PREFLIGHT.txt"
        cat >&2 <<'EOF'

board-ASan: NOT-AVAILABLE.
The aarch64 cross toolchain on this host carries no static AddressSanitizer
runtime, so no ASan binary can be produced that runs on a board without
installing one. Nothing is built and nothing is staged. Any ASan row for this
host is host-shim-only; recording a board ASan result from here would be a claim
the toolchain cannot support.
EOF
        exit 77
    fi
    printf 'verdict  : AVAILABLE (%s)\n' "$resolved" >>"$out/PREFLIGHT.txt"
    cat "$out/PREFLIGHT.txt"

    # Reproducers are discovered, not listed: drop a self-contained C file into
    # tests/repro/ and it is built here. `-static-libasan` is what removes the
    # board-side install; librga.a is offered on the link line and the linker
    # drops it when a reproducer does not reference it.
    flags=(-std=gnu11 -O1 -g -fno-omit-frame-pointer -fsanitize=address -static-libasan
        -I include -I im2d_api -I core -I core/hardware -I core/utils
        -I core/3rdparty/libdrm/include/drm -I core/3rdparty/android_hal)
    lib=()
    [[ -f $root/build-aarch64/librga.a ]] && lib=("$root/build-aarch64/librga.a" -lstdc++ -lpthread -ldl)
    shopt -s nullglob
    built=()
    for src in tests/shim/asan-canary.c tests/repro/*.c; do
        bin=$out/$(basename "${src%.c}")
        aarch64-linux-gnu-gcc "${flags[@]}" "$src" -o "$bin" "${lib[@]}"
        built+=("$bin")
    done
    shopt -u nullglob
    for bin in "${built[@]}"; do
        file "$bin" | grep -q aarch64 || { printf 'not an aarch64 binary: %s\n' "$bin" >&2; exit 1; }
        # A dynamic libasan here would mean -static-libasan silently did nothing
        # and the binary would refuse to start on a board that has no libasan.so.
        ! ldd "$bin" 2>/dev/null | grep -qi libasan \
            || { printf 'links libasan dynamically, so it is not board-portable: %s\n' "$bin" >&2; exit 1; }
        nm "$bin" | grep -q __asan_init \
            || { printf 'no static ASan runtime in %s\n' "$bin" >&2; exit 1; }
        printf 'built %s\n' "$bin"
    done
    printf 'cross-build-harness: OK (--asan, %s binaries)\n' "${#built[@]}"
    exit 0
fi

for tool in aarch64-linux-gnu-gcc aarch64-linux-gnu-g++ meson ninja qemu-aarch64; do
    command -v "$tool" >/dev/null || { printf 'missing tool: %s\n' "$tool" >&2; exit 77; }
done
source_dir=$root
unwired=0
grep -qx 'librga_so = librga' meson.build || unwired=1
for f in tests/meson-fragments/*.build; do
    grep -qx "# >>> fragment: $(basename "$f")" meson.build || unwired=1
done
if ((unwired)); then
    source_dir=$root/build-aarch64-source
    rm -rf -- "$source_dir"
    mkdir -p "$source_dir"
    tar --exclude='./.git' --exclude='./build*' -cf - . | tar -xf - -C "$source_dir"
    cd "$source_dir"
    grep -qx 'librga_so = librga' meson.build || sed -i '0,/^librga = static_library(/s//librga_so = librga\nlibrga = static_library(/' meson.build
    for f in tests/meson-fragments/*.build; do
        n=$(basename "$f")
        grep -qx "# >>> fragment: $n" meson.build || { printf '\n# >>> fragment: %s\n' "$n" >> meson.build; cat "$f" >> meson.build; }
    done
fi
if [[ -f $root/build-aarch64/meson-private/coredata.dat ]]; then
    meson setup --wipe "$root/build-aarch64" "$source_dir" --cross-file "$root/cross/aarch64-harness.ini" -Dlibrga_demo=false
else
    meson setup "$root/build-aarch64" "$source_dir" --cross-file "$root/cross/aarch64-harness.ini" -Dlibrga_demo=false
fi
meson compile -C "$root/build-aarch64"
meson test -C "$root/build-aarch64" board-oracle --print-errorlogs
