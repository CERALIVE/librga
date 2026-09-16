#!/usr/bin/env bash
# Adapted from Andres Cera's 04847992b4c8fd9cc793cefdc6e764d42100ad59.
# No APT operations: sysext qualification permits process-local libraries only.
set -euo pipefail
[[ ${CERALIVE_BOARD_TEST:-0} == 1 ]] || exit 77
here=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=tests/board/lib.sh
source "$here/lib.sh"
board_require_env
: "${BASELINE_LIB:?extracted baseline library}" "${CANDIDATE_LIB:?extracted candidate library}" \
  "${BASELINE_SHA256:?}" "${CANDIDATE_SHA256:?}" "${HARNESS_DIR:?}" "${RESULT_DIR:?}" "${PR_RUN_ID:?}"
[[ $PR_RUN_ID =~ ^[0-9]+$ && $BASELINE_SHA256 =~ ^[a-f0-9]{64}$ && $CANDIDATE_SHA256 =~ ^[a-f0-9]{64}$ ]]
repo=$(realpath "$here/../..")
[[ $(realpath -m "$RESULT_DIR") == "$repo/"* && ! -e $RESULT_DIR ]]
test "$(sha256sum "$BASELINE_LIB" | cut -d' ' -f1)" = "$BASELINE_SHA256"
test "$(sha256sum "$CANDIDATE_LIB" | cut -d' ' -f1)" = "$CANDIDATE_SHA256"
mkdir -p "$RESULT_DIR"
sha256sum "$BASELINE_LIB" "$CANDIDATE_LIB" "$HARNESS_DIR/rga-convert-bench" "$HARNESS_DIR/probe-version" >"$RESULT_DIR/inputs.sha256"
board_ssh() { board_require_env; _board_auth timeout "${SSH_LIMIT:-20}" ssh "${_board_options[@]}" "$BOARD_SSH_USER@$BOARD_IP" "$@"; }
board_scp() { board_require_env; _board_auth timeout 30 scp "${_board_options[@]}" "$@"; }
if ! board_ssh true; then printf 'SKIPPED-unreachable\n'; exit 77; fi
board_lock_acquire
board_ssh 'uname -r; test -c /dev/rga && test -c /dev/dma_heap/system' >"$RESULT_DIR/preflight.log"
remote="/tmp/librga-r1-$$-$RANDOM"
# shellcheck disable=SC2317
cleanup() {
    board_ssh "rm -rf -- $remote"
}
board_cleanup_push cleanup
board_ssh "mkdir -p $remote/base $remote/candidate"
board_scp "$BASELINE_LIB" "$BOARD_SSH_USER@$BOARD_IP:$remote/base/librga.so.2"
board_scp "$CANDIDATE_LIB" "$BOARD_SSH_USER@$BOARD_IP:$remote/candidate/librga.so.2"
board_scp "$HARNESS_DIR/rga-convert-bench" "$HARNESS_DIR/probe-version" "$BOARD_SSH_USER@$BOARD_IP:$remote/"
board_ssh "cd $remote && printf '%s\n' '$BASELINE_SHA256  base/librga.so.2' '$CANDIDATE_SHA256  candidate/librga.so.2' | sha256sum -c -" >"$RESULT_DIR/staged.log"
failed=0
row() {
    local name=$1 command=$2 rc=0
    board_ssh "$command" >"$RESULT_DIR/$name.log" 2>&1 || rc=$?
    printf '%s exit=%d\n' "$name" "$rc"
    if ((rc)); then failed=1; fi
}
printf 'PR_RUN_ID=%s board=%s baseline=%s candidate=%s\n' "$PR_RUN_ID" "$BOARD_IP" "$BASELINE_SHA256" "$CANDIDATE_SHA256"
row identity-base "env LD_LIBRARY_PATH=$remote/base $remote/probe-version"
row identity-candidate "env LD_LIBRARY_PATH=$remote/candidate $remote/probe-version"
SSH_LIMIT=60 row baseline "env LD_LIBRARY_PATH=$remote/base timeout 50 $remote/rga-convert-bench --improcess-only --iterations 1 --explicit-csc"
for core in 1 2 4; do
    # Keep the after counters even when the bench fails.
    # shellcheck disable=SC2016
    counters='for f in /sys/kernel/debug/rockchip-rga/cores/*/tasks; do printf "%s " "$f"; cat "$f"; done'
    SSH_LIMIT=60 row "routing-$core" "$counters; rc=0; env LD_LIBRARY_PATH=$remote/candidate timeout 50 $remote/rga-convert-bench --routing --core $core || rc=\$?; $counters; exit \$rc"
    bash "$here/score-drill.sh" routing "$core" "$RESULT_DIR/routing-$core.log" || failed=1
done
SSH_LIMIT=120 row conversion "env LD_LIBRARY_PATH=$remote/candidate GST_DEBUG_NO_COLOR=1 GST_DEBUG=mpp:5,mppenc:5 timeout 110 gst-launch-1.0 videotestsrc num-buffers=300 ! video/x-raw,format=RGB16,width=1920,height=1080 ! mpph264enc ! fakesink"
bash "$here/conversion-evidence.sh" "$RESULT_DIR/conversion.log" || failed=1
SSH_LIMIT=60 row matrix "env LD_LIBRARY_PATH=$remote/candidate timeout 50 $remote/rga-convert-bench --improcess-only --iterations 1 --explicit-csc"
bash "$here/score-drill.sh" psnr "$RESULT_DIR/baseline.log" "$RESULT_DIR/matrix.log" || failed=1
SSH_LIMIT=3700 row soak "env LD_LIBRARY_PATH=$remote/candidate timeout 3605 $remote/rga-convert-bench --soak"
bash "$here/score-drill.sh" soak "$RESULT_DIR/soak.log" || failed=1
SSH_LIMIT=60 row baseline-after "env LD_LIBRARY_PATH=$remote/base timeout 50 $remote/rga-convert-bench --selftest"
printf 'Isolated rows scored; failures=%d; temporary-state cleanup follows (not package rollback)\n' "$failed"
exit "$failed"
