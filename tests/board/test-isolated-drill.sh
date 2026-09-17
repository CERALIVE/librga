#!/usr/bin/env bash
# Modified by CeraLive 2026-09-17: exercise package/ELF identity and successful-receipt lifecycle.
set -euo pipefail
here=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
root=$(realpath "$here/../..")
mkdir -p "$root/test-results"
scratch=$(mktemp -d "$root/test-results/drill-control.XXXXXX")
trap 'rm -rf "$scratch"' EXIT
mkdir -p "$scratch/bin"
cp "$here/mock-drill-transport.sh" "$scratch/bin/sshpass"
chmod +x "$scratch/bin/sshpass"
export DRILL_FIXTURES=$scratch PATH="$scratch/bin:$PATH"
export CERALIVE_BOARD_TEST=1 BOARD_IP="recovery-fixture-$$" BOARD_SSH_USER=test BOARD_SSH_PASS=fixture
export RELEASE_VERSION=1.0+fixture BOARD_MODEL=rock-5b-plus
bash "$here/make-artifact-fixture.sh" "$scratch" "$RELEASE_VERSION"
export RUNTIME_DEB="$scratch/librga2-ceralive_${RELEASE_VERSION}_arm64.deb"
export DEV_DEB="$scratch/librga-ceralive-dev_${RELEASE_VERSION}_arm64.deb"
export BASELINE_LIB="$here/lib.sh" CANDIDATE_LIB="$scratch/runtime/usr/lib/aarch64-linux-gnu/librga.so.2.1.0" HARNESS_DIR="$scratch" PR_RUN_ID=1
BASELINE_SHA256=$(sha256sum "$BASELINE_LIB" | cut -d' ' -f1)
CANDIDATE_SHA256=$(sha256sum "$CANDIDATE_LIB" | cut -d' ' -f1)
export BASELINE_SHA256 CANDIDATE_SHA256
touch "$scratch/rga-convert-bench" "$scratch/probe-version"
for name in nv16-nv12 bgr-nv12 scale-4k-1080p crop rotate-90 bgr-601-limited bgr-601-full bgr-709-limited bgr-709-full; do
    printf '%s,improcess,0,20,50.000000\n' "$name" >>"$scratch/matrix"
done
printf '%s\n' 'soak-4k-nv16,improcess,0,20,50.000000' 'completed=1 cell=soak-4k-nv16' \
    'soak_elapsed_seconds=3600.000000' 'fd_census_before=6 after=6' >"$scratch/soak"
sed 's/3600.000000/295.000000/' "$scratch/soak" >"$scratch/short"
for fault in clean routing rotation short conversion hash restored cleanup; do
    rc=0
    : >"$scratch/order"
    DRILL_FAULT=$fault RESULT_DIR="$scratch/results-$fault" bash "$here/r1-isolated-drill.sh" >"$scratch/$fault.log" 2>&1 || rc=$?
    expected=1
    [[ $fault != clean ]] || expected=0
    [[ $fault != cleanup ]] || expected=13
    if [[ $rc != "$expected" || $(<"$scratch/order") != $'acquire\ncleanup\nrelease' ]]; then
        cat "$scratch/$fault.log" "$scratch/order" >&2; exit 1
    fi
    if [[ $fault == clean ]]; then
        cmp "$scratch/results-$fault/artifact-inputs.sha256" "$scratch/results-$fault/$BOARD_MODEL.sha256"
    else
        test ! -e "$scratch/results-$fault/$BOARD_MODEL.sha256"
    fi
    printf 'PASS: isolated drill %s exit=%d; cleanup precedes ownership release\n' "$fault" "$rc"
done
cp "$CANDIDATE_LIB" "$scratch/original-elf"
printf '\001' >>"$CANDIDATE_LIB"
for fault in expected-hash package-elf; do
    : >"$scratch/order"
    if [[ $fault == package-elf ]]; then
        CANDIDATE_SHA256=$(sha256sum "$CANDIDATE_LIB" | cut -d' ' -f1)
    fi
    rc=0
    RESULT_DIR="$scratch/results-$fault" bash "$here/r1-isolated-drill.sh" >"$scratch/$fault.log" 2>&1 || rc=$?
    [[ $rc == 1 && ! -s $scratch/order && ! -e $scratch/results-$fault ]]
    printf 'RED: changed candidate ELF (%s), drill exit=%d before transport or receipt\n' "$fault" "$rc"
done
cp "$scratch/original-elf" "$CANDIDATE_LIB"
CANDIDATE_SHA256=$(sha256sum "$CANDIDATE_LIB" | cut -d' ' -f1)
: >"$scratch/order"
DRILL_FAULT=clean RESULT_DIR="$scratch/results-restored-elf" bash "$here/r1-isolated-drill.sh" >"$scratch/restored-elf.log" 2>&1
test -s "$scratch/results-restored-elf/$BOARD_MODEL.sha256"
printf 'GREEN: restored candidate ELF, drill exit=0 and receipt emitted after cleanup\n'
for missing in CANDIDATE_SHA256 BASELINE_SHA256 RUNTIME_DEB DEV_DEB RELEASE_VERSION BOARD_MODEL; do
    : >"$scratch/order"
    rc=0
    env -u "$missing" RESULT_DIR="$scratch/results-missing-$missing" bash "$here/r1-isolated-drill.sh" >"$scratch/missing-$missing.log" 2>&1 || rc=$?
    [[ $rc == 1 && ! -s $scratch/order && ! -e $scratch/results-missing-$missing ]]
    printf 'PASS: missing %s exits 1 before transport or receipt\n' "$missing"
done
for mode in empty nan duplicate drift missing fd; do
    cp "$scratch/matrix" "$scratch/candidate"
    case "$mode" in
        empty) : >"$scratch/candidate" ;;
        nan) sed -i 's/50.000000/nan/g' "$scratch/candidate" ;;
        duplicate) cat "$scratch/matrix" >>"$scratch/candidate" ;;
        drift) sed -i 's/50.000000/50.020000/g' "$scratch/candidate" ;;
        missing) grep -v '^rotate-90,' "$scratch/matrix" >"$scratch/candidate" ;;
        fd)
            sed 's/after=6/after=7/' "$scratch/soak" >"$scratch/leak"
            if bash "$here/score-drill.sh" soak "$scratch/leak"; then exit 1; fi
            continue ;;
    esac
    if bash "$here/score-drill.sh" psnr "$scratch/matrix" "$scratch/candidate"; then exit 1; fi
    printf 'PASS: PSNR scorer rejects %s mutation\n' "$mode"
done
bash "$here/test-release-qualification.sh"
