#!/usr/bin/env bash
set -euo pipefail
[[ $1 == -e && $2 == timeout ]] || exit 97
shift 2
limit=$1 transport=$2; shift 2
printf '%s %s %s\n' "$limit" "$transport" "$*" >>"$DRILL_FIXTURES/transport.log"
[[ $transport == scp ]] && exit 0
[[ $transport == ssh ]] || exit 97
cmd=${!#}
case "$cmd" in
    true) exit 0 ;;
    *'set -C;'*) printf 'acquire\n' >>"$DRILL_FIXTURES/order" ;;
    *'cat /tmp/ceralive-board-in-use'*) printf 'release\n' >>"$DRILL_FIXTURES/order" ;;
    'rm -rf -- /tmp/librga-r1-'*)
        printf 'cleanup\n' >>"$DRILL_FIXTURES/order"
        [[ ${DRILL_FAULT:-} != cleanup ]] || exit 13 ;;
    'mkdir -p /tmp/librga-r1-'*) exit 0 ;;
    *'sha256sum -c -'*) [[ ${DRILL_FAULT:-} != hash ]] || exit 1 ;;
    *'test -c /dev/rga'*) printf 'fixture-kernel\n' ;;
    *'/probe-version') printf 'driver=1.3.11 fixture\n' ;;
    *'--routing --core '*)
        core=${cmd#*--routing --core }; core=${core%% *}
        for phase in 0 1; do
            for i in 0 1 2; do
                value=$((10 + phase * (i == core / 2) * 1000))
                [[ ${DRILL_FAULT:-} != routing ]] || value=10
                printf '/sys/kernel/debug/rockchip-rga/cores/%s/tasks %s\n' "$i" "$value"
            done
        done ;;
    *'--soak')
        [[ $limit == 3700 && $cmd == *'timeout 3605 '* ]] || exit 97
        if [[ ${DRILL_FAULT:-} == short ]]; then cat "$DRILL_FIXTURES/short";
        else cat "$DRILL_FIXTURES/soak"; fi ;;
    *'--selftest') [[ ${DRILL_FAULT:-} != restored ]] || exit 1 ;;
    *'--improcess-only'*)
        if [[ ${DRILL_FAULT:-} == rotation && $cmd == *'/candidate '* ]]; then
            grep -v '^rotate-90,' "$DRILL_FIXTURES/matrix"
        else cat "$DRILL_FIXTURES/matrix"; fi ;;
    *gst-launch-1.0*)
        [[ $cmd == *'GST_DEBUG=mpp:5,mppenc:5'* ]] || exit 97
        if [[ ${DRILL_FAULT:-} == conversion ]]; then printf 'RGA enabled\n';
        else printf 'using RGA converted buffer\n'; fi ;;
    *) printf 'unexpected mock transport command: %s\n' "$cmd" >&2; exit 97 ;;
esac
