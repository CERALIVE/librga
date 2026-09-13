#!/usr/bin/env bash
set -euo pipefail
root=$(realpath "$(dirname "$0")/..")
# shellcheck source=/dev/null
source "$root/tests/board/lib.sh"
board_require_env
[[ -x $root/build-aarch64/rga-convert-bench ]] || { printf 'run cross-build-harness.sh first\n' >&2; exit 2; }
board_lock_acquire
board_ssh 'mkdir -p /tmp/librga-bench'
board_scp -r "$root/build-aarch64/." "$BOARD_SSH_USER@$BOARD_IP:/tmp/librga-bench/"
