#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
set -euo pipefail
here=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
root=$(realpath "$here/../..")
mkdir -p "$root/test-results"
scratch=$(mktemp -d "$root/test-results/identity-control.XXXXXX")
trap 'rm -rf "$scratch"' EXIT
export RELEASE_VERSION=1.0+fixture DEB_ARCH=arm64
mkdir -p "$scratch/ci" "$scratch/dist" "$scratch/tests/board/qualification/$RELEASE_VERSION"
cp "$root/ci/artifact-identity.sh" "$root/ci/check-release-qualification.sh" "$scratch/ci/"
# Record/API rejection is exercised separately by test-release-record.sh.
printf 'exit 0\n' >"$scratch/ci/check-release-record.sh"
bash "$here/make-artifact-fixture.sh" "$scratch/dist" "$RELEASE_VERSION"
runtime="$scratch/dist/librga2-ceralive_${RELEASE_VERSION}_arm64.deb"
dev="$scratch/dist/librga-ceralive-dev_${RELEASE_VERSION}_arm64.deb"
bash "$root/ci/artifact-identity.sh" "$RELEASE_VERSION" "$runtime" "$dev" >"$scratch/qualified.sha256"
receipts="$scratch/tests/board/qualification/$RELEASE_VERSION"
for board in rock-5b-plus orange-pi-5-plus; do
    cp "$scratch/qualified.sha256" "$receipts/$board.sha256"
done
# Execute the workflow's actual gate command in a separate job-shell process.
workflow="$root/.github/workflows/publish-release.yml"
block=$(sed -n '/      - name: Require exact board-qualified release bytes/,/      - name: Create the GitHub release/p' "$workflow")
[[ $block == *'RELEASE_VERSION: ${{ needs.resolve.outputs.version }}'* &&
   $block == *'DEB_ARCH: ${{ needs.resolve.outputs.arch }}'* &&
   $block != *'if:'* && $block != *'continue-on-error:'* ]]
command=$(sed -n 's/^        run: //p' <<<"$block")
[[ $command == 'bash ci/check-release-qualification.sh' ]]
job() { (cd "$scratch"; bash --noprofile --norc -e -o pipefail -c "$command"); }
expect_red() {
    local label=$1 rc=0
    job >"$scratch/$label.log" 2>&1 || rc=$?
    [[ $rc == 1 ]] || { cat "$scratch/$label.log" >&2; exit 1; }
    grep -q 'QUALIFICATION-IDENTITY-FAIL' "$scratch/$label.log"
    printf 'RED: %s, publish job-shell exit=%d\n' "$label" "$rc"
}
job
cp "$runtime" "$scratch/runtime-original.deb"
cp "$dev" "$scratch/dev-original.deb"
printf '\001' >>"$scratch/dist/runtime/usr/lib/aarch64-linux-gnu/librga.so.2.1.0"
dpkg-deb --build --root-owner-group "$scratch/dist/runtime" "$runtime" >/dev/null
expect_red changed-packaged-elf
cp "$scratch/runtime-original.deb" "$runtime"
printf 'mutation\n' >"$scratch/dist/dev/changed-header"
dpkg-deb --build --root-owner-group "$scratch/dist/dev" "$dev" >/dev/null
expect_red changed-dev-archive
cp "$scratch/dev-original.deb" "$dev"
for board in rock-5b-plus orange-pi-5-plus; do
    rm "$receipts/$board.sha256"
    expect_red "missing-$board"
    : >"$receipts/$board.sha256"
    expect_red "empty-$board"
    printf 'not-a-receipt\n' >"$receipts/$board.sha256"
    expect_red "malformed-$board"
    cp "$scratch/qualified.sha256" "$receipts/$board.sha256"
done
job
printf 'GREEN: restored exact qualified archives, publish job-shell exit=0\n'
for fault in wrong-version wrong-package wrong-architecture missing-elf; do
    case "$fault" in
        wrong-version) version=2.0 ;;
        wrong-package) mv "$runtime" "$scratch/saved-runtime"; cp "$dev" "$runtime" ;;
        wrong-architecture)
            sed -i 's/Architecture: arm64/Architecture: amd64/' "$scratch/dist/runtime/DEBIAN/control"
            dpkg-deb --build --root-owner-group "$scratch/dist/runtime" "$runtime" >/dev/null ;;
        missing-elf)
            sed -i 's/Architecture: amd64/Architecture: arm64/' "$scratch/dist/runtime/DEBIAN/control"
            rm "$scratch/dist/runtime/usr/lib/aarch64-linux-gnu/librga.so.2.1.0"
            dpkg-deb --build --root-owner-group "$scratch/dist/runtime" "$runtime" >/dev/null ;;
    esac
    rc=0
    bash "$root/ci/artifact-identity.sh" "${version:-$RELEASE_VERSION}" "$runtime" "$dev" >"$scratch/$fault.log" 2>&1 || rc=$?
    [[ $rc != 0 ]] || { cat "$scratch/$fault.log" >&2; exit 1; }
    unset version
    cp "$scratch/runtime-original.deb" "$runtime"
    printf 'PASS: %s cannot generate a valid identity\n' "$fault"
done
