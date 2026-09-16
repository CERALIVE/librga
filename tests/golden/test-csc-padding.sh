#!/usr/bin/env bash
set -euo pipefail
probe=$1 clean=$2 mutant=$3
run_probe() {
    if [[ -n ${CSC_QEMU_SYSROOT:-} ]]; then
        qemu-aarch64 -L "$CSC_QEMU_SYSROOT" -E "LD_PRELOAD=$1" "$probe"
    else
        env LD_PRELOAD="$1" "$probe"
    fi
}
run_probe "$clean"
rc=0
run_probe "$mutant" || rc=$?
[[ $rc == 1 ]] || { printf 'FAIL: padding mutant exit=%s, expected 1\n' "$rc"; exit 1; }
printf 'PASS: raw stack-poison probe rejects uninitialized-padding writer\n'
