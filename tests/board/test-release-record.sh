#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# Modified by CeraLive 2026-09-17: exercise record rejection without board access.
set -euo pipefail
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
workflow="$root/.github/workflows/publish-release.yml"
preflight=$(sed -n '/      - name: Require release records before a live build/,/      - name: Run summary/p' "$workflow")
[[ $preflight == *'if: ${{ !inputs.dry_run }}'* && $preflight != *'continue-on-error:'* ]]
command=$(sed -n 's/^        run: //p' <<<"$preflight")
[[ $command == 'bash ci/check-release-qualification.sh --records-only' ]]
changes=$(sed -n '/  changes:/,/  resolve-suite:/p' "$root/.github/workflows/build-check.yml")
record_step=$(sed -n '/      - name: Require release records even for documentation-only PRs/,/      - name: Detect non-documentation changes/p' <<<"$changes")
[[ $record_step != *'if:'* && $record_step != *'continue-on-error:'* && $record_step == *"$command"* && $record_step == *'bash tests/board/test-release-record.sh'* ]]
mkdir -p "$root/test-results"
scratch=$(mktemp -d "$root/test-results/record-control.XXXXXX")
trap 'rm -rf "$scratch"' EXIT
export RELEASE_VERSION=1.10.5+ceralive.1 DEB_ARCH=arm64
mkdir -p "$scratch/ci" "$scratch/docs" "$scratch/tests/board" "$scratch/bin"
cp "$root/ci/check-release-record.sh" "$root/ci/check-release-qualification.sh" "$scratch/ci/"
cp "$root/docs/R1-RECORD-DEVIATIONS.md" "$scratch/docs/"
cp "$root/tests/board/DRILL-RESULTS.md" "$scratch/tests/board/"
cp -r "$root/tests/board/qualification" "$scratch/tests/board/"
# Only GitHub transport is substituted. The gate, documents and receipts are real.
cat >"$scratch/bin/gh" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
[[ ${FAULT:-} != api-unreadable ]] || exit 22
case "$*" in
    *'/contents/packaging/version?'*)
        version=${FIXTURE_VERSION:-1.10.5+ceralive.1}
        [[ $* != *ref=1111111111111111111111111111111111111111* ]] || version=1.10.5+ceralive.1
        printf '# Package version\n\n%s\n' "$version" | base64 -w0 ;;
    *'/jobs?'*)
        if [[ $* == *35275456552* ]]; then
            printf '%s\t%s\n' 'Dry run — what would have been published' success
            printf '%s\t%s\n' 'Publish release and dispatch apt reindex' "${LIVE_RESULT:-skipped}"
        elif [[ $* == *35275108125* ]]; then
            printf '%s\t%s\n' 'Resolve target suite and release version' failure
        else
            printf '%s\t%s\n' 'Probe cross-repo dispatch to apt-worker' success
        fi ;;
    'run view '*)
        [[ ${FAULT:-} != wrong-negative ]] && printf 'ERROR: tag 1.10.5+ceralive.1 already exists — a released version is never rebuilt\n'
        exit 0 ;;
    *'/actions/runs/'*)
        id=${2##*/}
        workflow=publish-release.yml; result=success; start=21:13:36; end=21:15:10
        head=5acda458cce27a8252d34f4c72aeea3edf9a2845
        case "$id" in
            35275108125) result=failure; start=21:09:55; end=21:10:15; head=1111111111111111111111111111111111111111 ;;
            35275427000) workflow=dispatch-preflight.yml; start=21:13:17; end=21:13:25 ;;
        esac
        [[ ${FAULT:-} != wrong-workflow ]] || workflow=build-check.yml
        [[ ${FAULT:-} != incomplete-run ]] || result=cancelled
        [[ ${FAULT:-} != late-preflight || $id != 35275427000 ]] || end=21:14:00
        printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$id" ".github/workflows/$workflow" completed "$result" workflow_dispatch "$head" "2026-09-17T${start}Z" "2026-09-17T${end}Z" ;;
    *) exit 90 ;;
esac
SH
chmod +x "$scratch/bin/gh"
export PATH="$scratch/bin:$PATH"
job() { (cd "$scratch"; bash --noprofile --norc -e -o pipefail -c "$command"); }
red() {
    local label=$1 rc=0
    job >"$scratch/result.log" 2>&1 || rc=$?
    [[ $rc == 1 ]] && grep -q 'RELEASE-RECORD-FAIL:' "$scratch/result.log" || {
        cat "$scratch/result.log" >&2; printf 'FAIL: %s exit=%s\n' "$label" "$rc" >&2; exit 1;
    }
    printf 'RED: %s, release entry exit=1\n' "$label"
}
# Given the reviewed record, when the real release entry runs, then it passes.
job
for path in docs/R1-RECORD-DEVIATIONS.md tests/board/DRILL-RESULTS.md \
    tests/board/qualification/1.10.5+ceralive.1/rock-5b-plus.sha256 \
    tests/board/qualification/1.10.5+ceralive.1/orange-pi-5-plus.sha256; do
    mv "$scratch/$path" "$scratch/saved"
    red "missing-$path"
    : >"$scratch/$path"
    red "empty-$path"
    rm "$scratch/$path"
    mkdir "$scratch/$path"
    red "unreadable-as-file-$path"
    rmdir "$scratch/$path"
    mv "$scratch/saved" "$scratch/$path"
    if [[ $EUID != 0 ]]; then
        chmod 000 "$scratch/$path"
        red "unreadable-permissions-$path"
        chmod 644 "$scratch/$path"
    fi
done
for role in 'Duplicate-tag negative receipt' 'Cross-repository dispatch preflight' 'Pre-publication ordering rehearsal'; do
    cp "$scratch/docs/R1-RECORD-DEVIATIONS.md" "$scratch/saved"
    sed -i "/| $role |/d" "$scratch/docs/R1-RECORD-DEVIATIONS.md"
    red "missing-$role"
    mv "$scratch/saved" "$scratch/docs/R1-RECORD-DEVIATIONS.md"
done
for fault in api-unreadable wrong-negative wrong-workflow incomplete-run late-preflight; do
    FAULT=$fault red "$fault"
done
LIVE_RESULT=success red live-publish-is-not-a-dry-run
RELEASE_VERSION=1.10.5+ceralive.2 red wrong-release-version
cp "$scratch/tests/board/DRILL-RESULTS.md" "$scratch/saved"
sed -i '/^| 19 |/d' "$scratch/tests/board/DRILL-RESULTS.md"
red missing-matrix-row
mv "$scratch/saved" "$scratch/tests/board/DRILL-RESULTS.md"
cp "$scratch/tests/board/DRILL-RESULTS.md" "$scratch/saved"
sed -i '/^| Runtime ELF SHA-256 |/s/07b6b6c4/17b6b6c4/' "$scratch/tests/board/DRILL-RESULTS.md"
red wrong-released-column
mv "$scratch/saved" "$scratch/tests/board/DRILL-RESULTS.md"
job
printf 'GREEN: restored record and receipts, release entry exit=0\n'
# Given a new version, its negative control must target an already-existing tag.
old=$RELEASE_VERSION
export RELEASE_VERSION=1.10.5+ceralive.2 FIXTURE_VERSION=1.10.5+ceralive.2
mv "$scratch/tests/board/qualification/$old" "$scratch/tests/board/qualification/$RELEASE_VERSION"
sed -i "s/$old/$RELEASE_VERSION/g" "$scratch/tests/board/DRILL-RESULTS.md" \
    "$scratch/tests/board/qualification/$RELEASE_VERSION/"*.sha256
job
printf 'GREEN: new-version rehearsal with prior-version duplicate-tag control, release entry exit=0\n'
FIXTURE_VERSION=$old red stale-new-version-rehearsal
