#!/usr/bin/env bash
#
# Fetch the pinned rk3588-media-island multi_rga UAPI header and verify it.
#
# Fail-closed by construction: the header is only written to its final path
# after its sha256 matches the pin, so a corrupted, truncated, or substituted
# download can never be compiled by the parity gate. The download itself goes
# to a temporary file that is removed on any failure.
#
# Usage: fetch-island-header.sh [output-path]
#   default output-path: <builddir-or-repo>/build/island-rga.h
#
# Offline/CI note: if the destination already exists and already hashes to the
# pin, the fetch is skipped. That keeps `meson test` runnable on a machine with
# no network once the header has been fetched, without ever weakening the hash
# check.

set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd -- "$script_dir/../.." && pwd)"

# shellcheck source=./island-pin.env
. "$script_dir/island-pin.env"

: "${ISLAND_REPO:?island-pin.env must set ISLAND_REPO}"
: "${ISLAND_REF:?island-pin.env must set ISLAND_REF}"
: "${ISLAND_RGA_H_PATH:?island-pin.env must set ISLAND_RGA_H_PATH}"
: "${ISLAND_RGA_H_SHA256:?island-pin.env must set ISLAND_RGA_H_SHA256}"

# A branch pin would move under us and silently change what the gate asserts.
# Accept only a release tag (v<something>) or a full 40-char commit SHA.
if ! [[ "$ISLAND_REF" =~ ^v[0-9] || "$ISLAND_REF" =~ ^[0-9a-f]{40}$ ]]; then
    echo "fetch-island-header: ISLAND_REF='$ISLAND_REF' is neither a v-prefixed release tag nor a 40-char commit SHA" >&2
    echo "fetch-island-header: pinning a branch is forbidden --- it moves under the pin" >&2
    exit 1
fi

out="${1:-$repo_root/build/island-rga.h}"
url="https://raw.githubusercontent.com/$ISLAND_REPO/$ISLAND_REF/$ISLAND_RGA_H_PATH"

verify() {
    local f="$1" got
    got="$(sha256sum "$f" | cut -d' ' -f1)"
    [ "$got" = "$ISLAND_RGA_H_SHA256" ]
}

if [ -f "$out" ] && verify "$out"; then
    echo "fetch-island-header: $out already matches the pin ($ISLAND_REF), skipping download"
    exit 0
fi

mkdir -p "$(dirname "$out")"
tmp="$(mktemp "${out}.XXXXXX.part")"
trap 'rm -f "$tmp"' EXIT

echo "fetch-island-header: GET $url"
if command -v curl >/dev/null 2>&1; then
    curl --fail --silent --show-error --location --retry 3 --retry-delay 2 -o "$tmp" "$url"
elif command -v wget >/dev/null 2>&1; then
    wget --quiet --tries=3 -O "$tmp" "$url"
else
    echo "fetch-island-header: neither curl nor wget is available" >&2
    exit 1
fi

if ! verify "$tmp"; then
    echo "fetch-island-header: SHA256 MISMATCH --- refusing to install the header" >&2
    echo "  ref      : $ISLAND_REF" >&2
    echo "  path     : $ISLAND_RGA_H_PATH" >&2
    echo "  expected : $ISLAND_RGA_H_SHA256" >&2
    echo "  actual   : $(sha256sum "$tmp" | cut -d' ' -f1)" >&2
    echo "fetch-island-header: either the island moved the file under the pinned ref (which a tag must never do)," >&2
    echo "fetch-island-header: or island-pin.env is stale. Do not 'fix' this by editing the sha without reading the diff." >&2
    exit 1
fi

mv -- "$tmp" "$out"
trap - EXIT
echo "fetch-island-header: OK $out ($ISLAND_REF, sha256 $ISLAND_RGA_H_SHA256)"
