#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# Modified by CeraLive 2026-09-17: identify archives and the ELF they actually ship.
set -euo pipefail
[[ $# == 3 ]] || { printf 'usage: %s VERSION RUNTIME_DEB DEV_DEB\n' "$0" >&2; exit 1; }
version=$1 runtime=$2 dev=$3
[[ $version =~ ^[0-9][a-zA-Z0-9.+~-]*$ ]] || exit 1
for kind in runtime dev; do
    package=librga2-ceralive deb=$runtime
    if [[ $kind == dev ]]; then
        package=librga-ceralive-dev deb=$dev
    fi
    [[ $(dpkg-deb -f "$deb" Package) == "$package" &&
       $(dpkg-deb -f "$deb" Version) == "$version" &&
       $(dpkg-deb -f "$deb" Architecture) == arm64 ]] || {
        printf 'ARTIFACT-IDENTITY-FAIL: wrong package/version/architecture: %s\n' "$deb" >&2
        exit 1
    }
    digest=$(sha256sum "$deb")
    printf '%s  %s_%s_arm64.deb\n' "${digest%% *}" "$package" "$version"
done
# Hash the packaged, stripped ELF, not its sibling in a Meson build directory.
digest=$(dpkg-deb --fsys-tarfile "$runtime" |
    tar -xOf - ./usr/lib/aarch64-linux-gnu/librga.so.2.1.0 | sha256sum)
printf '%s  librga.so.2.1.0\n' "${digest%% *}"
