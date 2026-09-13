#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# Modified by CeraLive 2026-09-08: track conversion evidence across plugin releases.
# Remote shell expressions and EXIT callbacks are deliberately indirect; lib.sh's selftest uses subshell credentials.
# shellcheck disable=SC2016,SC2031,SC2317
set -euo pipefail
[[ ${CERALIVE_BOARD_TEST:-0} == 1 ]] || exit 77
here=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=tests/board/lib.sh
source "$here/lib.sh"
board_require_env
# Bound even the library's marker operations. Authentication remains env-only.
board_ssh() { board_require_env; _board_auth timeout "${SSH_LIMIT:-20}" ssh "${_board_options[@]}" "$BOARD_SSH_USER@$BOARD_IP" "$@"; }
board_scp() { board_require_env; _board_auth timeout 30 scp "${_board_options[@]}" "$@"; }
if ! board_ssh true; then printf 'SKIPPED-unreachable %s\n' "$BOARD_IP"; exit 77; fi
if ! board_ssh 'uname -r; lsmod | grep rga; ls /dev/rga; test "$(uname -r)" = 7.2.0-ceralive-rk3588 && lsmod | grep -q "^rga_multicore " && test -c /dev/rga'; then
    printf 'PRECONDITION-FAIL %s; R1-R7 NOT-RUN; verdict BLOCKED\n' "$BOARD_IP"; exit 1
fi
: "${R0_DEB:?download PR dist artifact first}" "${RADXA_DEB:?stage pinned rollback deb}" "${HARNESS_DIR:?target-suite arm64 harness directory}" "${PR_RUN_ID:?artifact run id}" "${RESULT_DIR:?repo-local output directory}"
[[ $PR_RUN_ID =~ ^[0-9]+$ ]]
mkdir -p "$RESULT_DIR"
sha256sum "$R0_DEB" "$RADXA_DEB" "$HARNESS_DIR/rga-convert-bench" "$HARNESS_DIR/probe-version"
printf 'PR_RUN_ID=%s board=%s\n' "$PR_RUN_ID" "$BOARD_IP"
test "$(sha256sum "$RADXA_DEB" | cut -d' ' -f1)" = ca4f18666f6c5d5290c7e41e5901350ecf76530f24364e37b81fa6be4ab5f344
test "$(dpkg-deb -f "$R0_DEB" Package Version Architecture | tr '\n' ' ')" = 'Package: librga2-ceralive Version: 1.10.1+ceralive.1 Architecture: arm64 '
if [[ -z ${BOARD_SSH_PASS:-} ]]; then BOARD_SSH_PASS=$(<"$BOARD_SSH_PASS_FILE"); fi
root() { printf '%s\n' "$BOARD_SSH_PASS" | board_ssh "sudo -S -p '' bash -o pipefail -c $(printf '%q' "$1")"; }
board_lock_acquire
remote=/tmp/librga-g-a
board_ssh "mkdir -p $remote"
board_scp "$RADXA_DEB" "$BOARD_SSH_USER@$BOARD_IP:/tmp/librga2_2.2.0-1_arm64.deb"
board_scp "$R0_DEB" "$BOARD_SSH_USER@$BOARD_IP:/tmp/librga2-ceralive_1.10.1+ceralive.1_arm64.deb"
board_scp "$HARNESS_DIR/rga-convert-bench" "$HARNESS_DIR/probe-version" "$BOARD_SSH_USER@$BOARD_IP:$remote/"
root "sha256sum /tmp/librga*.deb; $remote/probe-version" | tee "$RESULT_DIR/probe.log"
root "test \"\$(sha256sum /tmp/librga2-ceralive_1.10.1+ceralive.1_arm64.deb | cut -d' ' -f1)\" = $(sha256sum "$R0_DEB" | cut -d' ' -f1)"
grep -q '^driver=1.3.11 ' "$RESULT_DIR/probe.log" || { printf 'PRECONDITION-FAIL driver; BLOCKED\n'; exit 1; }
root "test \"\$(sha256sum /tmp/librga2_2.2.0-1_arm64.deb | cut -d' ' -f1)\" = ca4f18666f6c5d5290c7e41e5901350ecf76530f24364e37b81fa6be4ab5f344; dpkg -s librga2; sha256sum /usr/lib/aarch64-linux-gnu/librga.so.2.1.0" | tee "$RESULT_DIR/initial.log"
grep -q '^Status: install ok installed$' "$RESULT_DIR/initial.log"
failed=0
row() {
    local name=$1 command=$2 rc=0
    root "$command" >"$RESULT_DIR/$name.log" 2>&1 || rc=$?
    printf '%s exit=%d\n' "$name" "$rc"
    if ((rc)); then failed=1; fi
}
restore() {
    local rc=0
    SSH_LIMIT=120 root 'timeout 110 apt-get install --yes --allow-downgrades /tmp/librga2_2.2.0-1_arm64.deb' >"$RESULT_DIR/restore.log" 2>&1 || rc=$?
    root 'dpkg -s librga2; ldconfig -p | grep librga; dpkg -s librga2 | grep -q "Status: install ok installed" && test "$(sha256sum /usr/lib/aarch64-linux-gnu/librga.so.2.1.0 | cut -d" " -f1)" = 0b455344259c37fec821955e2de85bb5f76a34e69682217b514c407d8a35c6c3 && ! dpkg -s librga2-ceralive 2>/dev/null | grep -q "Status: install ok installed"' >>"$RESULT_DIR/restore.log" 2>&1 || rc=$?
    printf 'R7 restore exit=%d\n' "$rc"
    return "$rc"
}
# Rollback is armed BEFORE apt can remove the baseline provider.
board_cleanup_push restore
SSH_LIMIT=60 row baseline "timeout 50 $remote/rga-convert-bench --improcess-only --iterations 1 --explicit-csc"
SSH_LIMIT=120 root 'timeout 110 apt-get install --yes /tmp/librga2-ceralive_1.10.1+ceralive.1_arm64.deb' >"$RESULT_DIR/install.log" 2>&1
row R1 'dpkg -s librga2-ceralive; ldconfig -p | grep librga; dpkg -S /usr/lib/aarch64-linux-gnu/librga.so.2.1.0; dpkg -s librga2-ceralive | grep -q "Status: install ok installed" && ! dpkg -s librga2 2>/dev/null | grep -q "Status: install ok installed"'
row R2 'dpkg -s gstreamer1.0-rockchip-ceralive && gst-inspect-1.0 mpph264enc'
for core in 1 2 4; do
    SSH_LIMIT=60 row "R3-core-$core" "rc=0; for f in /sys/kernel/debug/rockchip-rga/cores/*/tasks; do printf '%s ' \"\$f\"; cat \"\$f\"; done; timeout 50 $remote/rga-convert-bench --routing --core $core || rc=\$?; for f in /sys/kernel/debug/rockchip-rga/cores/*/tasks; do printf '%s ' \"\$f\"; cat \"\$f\"; done; exit \$rc"
    index=$((core / 2))
    if ! awk -v selected="$index" '
      /^\/sys\/kernel\/debug\/rockchip-rga\/cores\/[012]\/tasks / {
        split($1,p,"/"); i=p[7]; n[i]++; if(n[i]==1) before[i]=$2; else after[i]=$2;
      }
      END { for(i=0;i<3;i++) if(n[i]!=2 || after[i]-before[i]!=(i==selected ? 1000 : 0)) exit 1; }
    ' "$RESULT_DIR/R3-core-$core.log"; then failed=1; printf 'R3-core-%s counter proof FAIL\n' "$core"; fi
done
SSH_LIMIT=120 row R4 "GST_DEBUG_NO_COLOR=1 GST_DEBUG=mpp:5,mppenc:5 timeout 110 gst-launch-1.0 videotestsrc num-buffers=300 ! video/x-raw,format=RGB16,width=1920,height=1080 ! mpph264enc ! fakesink"
if ! bash "$here/conversion-evidence.sh" "$RESULT_DIR/R4.log"; then failed=1; printf 'R4 conversion evidence FAIL\n'; fi
SSH_LIMIT=60 row R5 "timeout 50 $remote/rga-convert-bench --improcess-only --iterations 1 --explicit-csc"
if ! awk -F, '
  $2=="improcess" && $3==0 {
    if(FNR==NR) baseline[$1]=$5; else {
      if(!($1 in baseline)) bad=1;
      else if($5=="inf" || baseline[$1]=="inf") { if($5!=baseline[$1]) bad=1; }
      else { d=$5-baseline[$1]; if(d>0.01 || d< -0.01) bad=1; }
      count++;
    }
  }
  END { if(count!=9 || bad) exit 1; }
' "$RESULT_DIR/baseline.log" "$RESULT_DIR/R5.log"; then failed=1; printf 'R5 PSNR neutrality FAIL\n'; fi
SSH_LIMIT=3700 row R6 "timeout 3605 $remote/rga-convert-bench --soak"
printf 'R1-R6 scored; failures=%d; R7 follows in EXIT cleanup\n' "$failed"
# Never emit PASS before R7, exact counter deltas and all PSNR cells are scored.
exit "$failed"
