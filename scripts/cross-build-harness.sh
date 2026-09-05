#!/usr/bin/env bash
set -euo pipefail
root=$(realpath "$(dirname "$0")/..")
cd "$root"
export QEMU_LD_PREFIX=${QEMU_LD_PREFIX:-/usr/aarch64-linux-gnu}
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
