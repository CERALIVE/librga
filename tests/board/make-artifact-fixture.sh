#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
set -euo pipefail
out=$1 version=$2
mkdir -p "$out/runtime/DEBIAN" "$out/dev/DEBIAN" "$out/runtime/usr/lib/aarch64-linux-gnu"
printf 'int fixture_identity(void) { return 1; }\n' |
    cc -shared -fPIC -x c - -o "$out/runtime/usr/lib/aarch64-linux-gnu/librga.so.2.1.0"
for kind in runtime dev; do
    package=librga2-ceralive
    [[ $kind != dev ]] || package=librga-ceralive-dev
    printf 'Package: %s\nVersion: %s\nArchitecture: arm64\nMaintainer: Test <test@example.invalid>\nDescription: identity fixture, not an installable RGA library\n' \
        "$package" "$version" >"$out/$kind/DEBIAN/control"
    dpkg-deb --build --root-owner-group "$out/$kind" "$out/${package}_${version}_arm64.deb" >/dev/null
done
