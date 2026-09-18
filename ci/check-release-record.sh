#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# Modified by CeraLive 2026-09-17: require readable R1 records and real rehearsal runs.
set -euo pipefail
fail() { printf 'RELEASE-RECORD-FAIL: %s\n' "$*" >&2; exit 1; }
readable() { [[ -f $1 && -r $1 && -s $1 ]] || fail "missing/empty/unreadable evidence: $1"; }
api() { timeout 60 gh api "$@" || fail "unreadable GitHub evidence: $1"; }
: "${RELEASE_VERSION:?}" "${DEB_ARCH:?}"
[[ $DEB_ARCH == arm64 && $RELEASE_VERSION =~ ^[0-9][a-zA-Z0-9.+~-]*$ ]] || fail 'invalid release identity'
report=tests/board/DRILL-RESULTS.md
record=docs/R1-RECORD-DEVIATIONS.md
readable "$report"
readable "$record"
grep -Fq "\`$RELEASE_VERSION\`" "$report" || fail 'report does not identify this release'
# Require the complete consolidated matrix, not an existing but empty heading.
awk -F'|' '
    /^\| [0-9]+ \|/ {
        n=$2+0; if (NF != 6 || n != ++count || $4 !~ /[^[:space:]]/ || $5 !~ /[^[:space:]]/) exit 1
    }
    END { if (count != 26) exit 1 }
' "$report" || fail 'incomplete/duplicate/malformed 26-row board record'
reference=
for board in rock-5b-plus orange-pi-5-plus; do
    receipt="tests/board/qualification/$RELEASE_VERSION/$board.sha256"
    readable "$receipt"
    mapfile -t lines <"$receipt"
    [[ ${#lines[@]} == 3 ]] || fail "malformed board identity: $board"
    names=("librga2-ceralive_${RELEASE_VERSION}_arm64.deb" "librga-ceralive-dev_${RELEASE_VERSION}_arm64.deb" librga.so.2.1.0)
    labels=('Runtime `.deb` SHA-256' 'Development `.deb` SHA-256' 'Runtime ELF SHA-256')
    for i in 0 1 2; do
        hash=${lines[i]%% *}
        [[ $hash =~ ^[0-9a-f]{64}$ && ${lines[i]} == "$hash  ${names[i]}" ]] || fail "malformed board identity: $board"
        value=$(awk -F'|' -v label=" ${labels[i]} " '$2 == label { print $4 }' "$report")
        [[ $value == " \`$hash\` " ]] || fail "report/released identity mismatch: $board ${names[i]}"
    done
    [[ -z $reference ]] || cmp -s "$reference" "$receipt" || fail 'board identities disagree'
    reference=$receipt
done

roles=('Duplicate-tag negative receipt' 'Cross-repository dispatch preflight' 'Pre-publication ordering rehearsal')
workflows=(publish-release.yml dispatch-preflight.yml publish-release.yml)
conclusions=(failure success success)
declare -a starts ends ids
for i in 0 1 2; do
    link=$(awk -F'|' -v role=" ${roles[i]} " '$5 == role { print $3 }' "$record")
    [[ $link =~ ^\ \[([0-9]+)\]\(https://github.com/CERALIVE/librga/actions/runs/([0-9]+)\)\ $ && ${BASH_REMATCH[1]} == "${BASH_REMATCH[2]}" ]] || fail "missing/duplicate/malformed ${roles[i]}"
    id=${BASH_REMATCH[1]}
    ids[i]=$id
    metadata=$(api "repos/CERALIVE/librga/actions/runs/$id" --jq '[.id,.path,.status,.conclusion,.event,.head_sha,.run_started_at,.updated_at] | @tsv')
    IFS=$'\t' read -r actual workflow status conclusion event head start end <<<"$metadata"
    [[ $actual == "$id" && $workflow == ".github/workflows/${workflows[i]}" && $status == completed && $conclusion == "${conclusions[i]}" && $event == workflow_dispatch && $head =~ ^[0-9a-f]{40}$ ]] || fail "wrong run identity/result: $id"
    [[ $start =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$ && $end =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$ && ! $end < $start ]] || fail "invalid run times: $id"
    starts[i]=$start; ends[i]=$end
    encoded=$(api "repos/CERALIVE/librga/contents/packaging/version?ref=$head" --jq .content)
    version=$(printf '%s' "$encoded" | base64 --decode | sed -e 's/#.*//' -e 's/[[:space:]]//g' | sed -n '/./{p;q;}') || fail "unreadable version at $head"
    [[ $version =~ ^[0-9][a-zA-Z0-9.+~-]*$ ]] || fail "invalid source version: $id"
    # The duplicate-tag control needs an existing release, not the new tag.
    [[ $i == 0 || $version == "$RELEASE_VERSION" ]] || fail "run $id belongs to another release"
    jobs=$(api "repos/CERALIVE/librga/actions/runs/$id/jobs?per_page=100" --jq '.jobs[] | [.name,.conclusion] | @tsv')
    case "$i" in
        0)
            grep -Fxq $'Resolve target suite and release version\tfailure' <<<"$jobs" || fail "wrong negative job: $id"
            log=$(timeout 60 gh run view "$id" --repo CERALIVE/librga --log) || fail "unreadable negative log: $id"
            grep -Fq "ERROR: tag $version already exists — a released version is never rebuilt" <<<"$log" || fail "wrong negative failure: $id"
            ;;
        1) grep -Fxq $'Probe cross-repo dispatch to apt-worker\tsuccess' <<<"$jobs" || fail "preflight did not execute: $id" ;;
        2)
            grep -Fxq $'Dry run — what would have been published\tsuccess' <<<"$jobs" || fail "dry run did not execute: $id"
            grep -Fxq $'Publish release and dispatch apt reindex\tskipped' <<<"$jobs" || fail "live publication is not rehearsal: $id"
            ;;
    esac
    printf 'RELEASE-RECORD-RECEIPT: %s run=%s result=%s\n' "${roles[i]}" "$id" "$conclusion"
done
[[ ${ids[0]} != "${ids[1]}" && ${ids[0]} != "${ids[2]}" && ${ids[1]} != "${ids[2]}" ]] || fail 'reused receipt ID'
[[ ${ends[0]} < "${starts[2]}" && ${ends[1]} < "${starts[2]}" ]] || fail 'negative/preflight must complete before final rehearsal'
printf 'RELEASE-RECORD-PASS: %s; consolidated matrix, both identities and three verified rehearsal receipts (not historical ordering or loader proof)\n' "$RELEASE_VERSION"
