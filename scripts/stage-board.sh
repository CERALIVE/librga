#!/usr/bin/env bash
set -euo pipefail
root=$(realpath "$(dirname "$0")/..")

asan=0
for arg in "$@"; do
    case "$arg" in
        --asan) asan=1 ;;
        *) printf 'usage: %s [--asan]\n' "$0" >&2; exit 2 ;;
    esac
done

# shellcheck source=/dev/null
source "$root/tests/board/lib.sh"
board_require_env

if ((asan)); then
    src=$root/build-aarch64/asan
    # Refuse on the recorded verdict rather than on a missing directory: staging
    # nothing and returning 0 would read downstream as "the board ASan leg ran".
    if [[ -f $src/PREFLIGHT.txt ]] && grep -q '^verdict  : NOT-AVAILABLE' "$src/PREFLIGHT.txt"; then
        cat "$src/PREFLIGHT.txt" >&2
        printf 'board-ASan is NOT-AVAILABLE on this host; nothing staged\n' >&2
        exit 77
    fi
    [[ -x $src/asan-canary ]] || { printf 'run cross-build-harness.sh --asan first\n' >&2; exit 2; }
    board_lock_acquire
    board_ssh 'mkdir -p /tmp/librga-bench/asan'
    board_scp -r "$src/." "$BOARD_SSH_USER@$BOARD_IP:/tmp/librga-bench/asan/"
    # The canary runs FIRST on the board or the reproducers beside it prove
    # nothing: a statically linked ASan runtime that fails to start on this
    # kernel would otherwise look like a clean run.
    printf 'staged %s -> /tmp/librga-bench/asan/ (run asan-canary there before trusting any reproducer)\n' "$src"
    exit 0
fi

[[ -x $root/build-aarch64/rga-convert-bench ]] || { printf 'run cross-build-harness.sh first\n' >&2; exit 2; }
board_lock_acquire
board_ssh 'mkdir -p /tmp/librga-bench'
board_scp -r "$root/build-aarch64/." "$BOARD_SSH_USER@$BOARD_IP:/tmp/librga-bench/"
