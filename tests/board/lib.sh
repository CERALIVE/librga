#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# Source once in a drill. Never replace this library's EXIT trap.
[[ ${_BOARD_LIB_LOADED:-0} == 1 ]] && return 0
_BOARD_LIB_LOADED=1
declare -a _board_cleanups=()
board_cleanup_push() { _board_cleanups+=("$1"); }
_board_cleanup() {
    local status=$? i rc
    trap - EXIT
    set +e
    for ((i=${#_board_cleanups[@]}-1; i>=0; i--)); do
        eval "${_board_cleanups[i]}"
        rc=$?
        if ((rc)); then
            printf 'BOARD-CLEANUP-FAILED: %s\n' "${_board_cleanups[i]}" >&2
            ((status == 0)) && status=$rc
        fi
    done
    exit "$status"
}
trap _board_cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

board_require_env() {
    if [[ -z ${BOARD_IP:-} || -z ${BOARD_SSH_USER:-} ||
          ( -z ${BOARD_SSH_PASS:-} && ! -r ${BOARD_SSH_PASS_FILE:-} ) ]]; then
        printf 'SKIPPED-unreachable: set BOARD_IP, BOARD_SSH_USER and BOARD_SSH_PASS (or BOARD_SSH_PASS_FILE)\n' >&2
        exit 77
    fi
    [[ $BOARD_IP =~ ^[a-zA-Z0-9.-]+$ && $BOARD_SSH_USER =~ ^[a-zA-Z0-9_-]+$ ]] || exit 77
    BOARD_KNOWN_HOSTS=${BOARD_KNOWN_HOSTS:-$HOME/.ssh/known_hosts}
    _board_options=(-o "UserKnownHostsFile=$BOARD_KNOWN_HOSTS" -o StrictHostKeyChecking=yes
        -o ConnectTimeout=8 -o ConnectionAttempts=1 -o ServerAliveInterval=5 -o ServerAliveCountMax=2)
}
_board_auth() {
    if [[ -n ${BOARD_SSH_PASS:-} ]]; then
        SSHPASS=$BOARD_SSH_PASS sshpass -e "$@"
    else
        sshpass -f "$BOARD_SSH_PASS_FILE" "$@"
    fi
}
board_ssh() { board_require_env; _board_auth ssh "${_board_options[@]}" "$BOARD_SSH_USER@$BOARD_IP" "$@"; }
board_scp() { board_require_env; _board_auth scp "${_board_options[@]}" "$@"; }
_board_marker_acquire() {
    board_ssh "(set -C; printf '%s\\n' '$_board_token' > /tmp/ceralive-board-in-use) 2>/dev/null || { cat /tmp/ceralive-board-in-use >&2; exit 75; }"
}
_board_marker_release() {
    board_ssh "test \"\$(cat /tmp/ceralive-board-in-use)\" = '$_board_token' && rm /tmp/ceralive-board-in-use"
}
_board_release() {
    local rc=0
    if [[ ${_board_marker_owned:-0} == 1 ]]; then _board_marker_release || rc=$?; fi
    flock -u "$lockfd"
    exec {lockfd}>&-
    return "$rc"
}
board_lock_acquire() {
    board_require_env
    [[ -z ${lockfd:-} ]] || { printf 'board lock already acquired\n' >&2; exit 75; }
    exec {lockfd}>"/tmp/ceralive-board-$BOARD_IP.lock"
    flock -n "$lockfd" || exit 75
    board_cleanup_push _board_release
    _board_token="effort=librga-fork session=$(hostname)-$$-$RANDOM since=$(date -u +%FT%TZ)"
    _board_marker_acquire || exit "$?"
    _board_marker_owned=1
}

board_selftest() (
    set -eu
    local lib scratch first status
    lib=$(realpath "${BASH_SOURCE[0]}")
    scratch=$(mktemp -d)
    export BOARD_TEST_DIR=$scratch BOARD_TEST_LIB=$lib
    export BOARD_IP="selftest-$$" BOARD_SSH_USER=test BOARD_SSH_PASS=test
    # Each child sources the real lock/cleanup code; only the remote transport is mocked.
    # Child and cleanup commands expand in their own shells.
    # shellcheck disable=SC2016
    local child='source "$BOARD_TEST_LIB"; set -eu
      _board_marker_acquire() { (set -C; printf marker > "$BOARD_TEST_DIR/marker"); }
      _board_marker_release() { printf "marker\n" >> "$BOARD_TEST_DIR/order"; rm "$BOARD_TEST_DIR/marker"; }
      board_lock_acquire
      board_cleanup_push '\''printf "first\n" >> "$BOARD_TEST_DIR/order"'\''
      board_cleanup_push '\''printf "second\n" >> "$BOARD_TEST_DIR/order"'\''
      touch "$BOARD_TEST_DIR/ready"
      while [[ ! -f $BOARD_TEST_DIR/release ]]; do sleep .05; done'
    bash -c "$child" & first=$!
    board_cleanup_push "kill $first 2>/dev/null || true"
    for ((i=0;i<100;i++)); do [[ -f $scratch/ready ]] && break; sleep .05; done
    [[ -f $scratch/ready ]]
    status=0
    timeout 3 bash -c "$child" || status=$?
    [[ $status == 75 ]]
    printf 'PASS: second process exits 75 while first holds descriptor lock\n'
    touch "$scratch/release"
    wait "$first"
    [[ ! -e $scratch/marker && $(<"$scratch/order") == $'second\nfirst\nmarker' ]]
    printf 'PASS: LIFO second -> first -> marker; marker removed last\n'
    status=0
    bash -c 'source "$BOARD_TEST_LIB"; _board_marker_acquire() { return 75; }; board_lock_acquire' || status=$?
    [[ $status == 75 ]]
    printf 'PASS: foreign marker returns 75 and does not run marker removal\n'
    rm -r "$scratch"
)
if [[ ${BASH_SOURCE[0]} == "$0" ]]; then
    [[ ${1:-} == --selftest ]] || exit 2
    board_selftest
fi
