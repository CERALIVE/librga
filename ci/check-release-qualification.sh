#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# Modified by CeraLive 2026-09-17: refuse publication of bytes absent from board receipts.
set -euo pipefail
[[ $# == 0 || ( $# == 1 && $1 == --records-only ) ]] || {
    printf 'usage: %s [--records-only]\n' "$0" >&2
    exit 1
}
: "${RELEASE_VERSION:?}" "${DEB_ARCH:?}"
[[ $DEB_ARCH == arm64 && $RELEASE_VERSION =~ ^[0-9][a-zA-Z0-9.+~-]*$ ]] || exit 1
bash ci/check-release-record.sh
[[ $# == 0 ]] || exit 0
runtime="dist/librga2-ceralive_${RELEASE_VERSION}_${DEB_ARCH}.deb"
dev="dist/librga-ceralive-dev_${RELEASE_VERSION}_${DEB_ARCH}.deb"
actual=$(bash ci/artifact-identity.sh "$RELEASE_VERSION" "$runtime" "$dev")
for board in rock-5b-plus orange-pi-5-plus; do
    receipt="tests/board/qualification/$RELEASE_VERSION/$board.sha256"
    [[ -s $receipt ]] || {
        printf 'QUALIFICATION-IDENTITY-FAIL: missing %s\n' "$receipt" >&2
        exit 1
    }
    if ! diff -u "$receipt" <(printf '%s\n' "$actual"); then
        printf 'QUALIFICATION-IDENTITY-FAIL: %s did not qualify these release bytes\n' "$board" >&2
        exit 1
    fi
    printf 'QUALIFICATION-IDENTITY-PASS: %s\n' "$board"
done
