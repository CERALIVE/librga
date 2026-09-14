#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# Modified by CeraLive 2026-09-14: isolate each registered host-shim H10 run.
# Modified by CeraLive 2026-09-14: defer instrumented preload until the test exec.
set -euo pipefail
: "${FAKE_RGA_LOG:?}" "${FAKE_RGA_DUMP:?}"
unset FAKE_RGA_REIMPORT FAKE_RGA_FAIL
: >"$FAKE_RGA_LOG"
: >"$FAKE_RGA_DUMP"
export LD_PRELOAD="${H10_SHIM:?}"
exec "$@"
