#!/usr/bin/env bash
# Modified by CeraLive 2026-09-05: run the host-only H6 fence census reproducibly.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/../.."
mkdir -p test-results/h6
if [[ ! -f build-host/meson-private/coredata.dat ]]; then
    meson setup build-host -Dcpp_args=-fpermissive
fi
meson compile -C build-host
"${CXX:-g++}" -std=c++14 -Wall -Wextra -Werror -DLINUX=1 \
    -Iinclude -Iim2d_api -Icore/hardware tests/repro/h6_polarity_fence.cpp \
    -Lbuild-host -Wl,-rpath,"\$ORIGIN/../../build-host" -lrga -ldl -pthread \
    -o test-results/h6/h6-polarity-fence
: > test-results/h6/interposed.log
: > test-results/h6/requests.bin
set +e
LD_PRELOAD="$PWD/build-host/libfake_rga.so" \
FAKE_RGA_LOG="$PWD/test-results/h6/interposed.log" \
FAKE_RGA_DUMP="$PWD/test-results/h6/requests.bin" \
    timeout 30s test-results/h6/h6-polarity-fence \
    > test-results/h6/run.log 2>&1
status=$?
set -e
printf '%s\n' "$status" > test-results/h6/exit-status.txt
if [[ $status != 0 && $status != 1 ]]; then
    printf 'H6 infrastructure failure: exit %s; see test-results/h6/run.log\n' "$status" >&2
    exit "$status"
fi
# Reaching a library validation error is not proof that an injected ioctl failed.
awk '
    /ioctl RGA_BLIT_SYNC .*ret=-1 errno=5$/ { sync_fail++ }
    /ioctl RGA_BLIT_ASYNC .*ret=-1 errno=5$/ { async_fail++ }
    /poll sync-wait .*ret=-1 errno=5$/ { wait_fail++ }
    END { if (sync_fail != 200 || async_fail != 200 || wait_fail != 200) exit 1 }
' test-results/h6/interposed.log
cat test-results/h6/cases.csv
printf 'H6a: WITHDRAWN; control assertions passed; repro exit=%s (1=RED, 0=not reproduced)\n' "$status"
exit "$status"
