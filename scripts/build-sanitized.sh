#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# Configure and build the host sanitizer trees.
#
#   bash scripts/build-sanitized.sh asan     # -> build-asan/   (ASan + UBSan)
#   bash scripts/build-sanitized.sh tsan     # -> build-tsan/   (ThreadSanitizer)
#
# HOST ONLY. Everything this produces runs against the fake-/dev/rga shim on a
# development machine or a CI container. No board drill may cite a sanitizer
# result: a shim report is evidence about the shim's model of the driver, never
# about silicon. See docs/SANITIZERS.md.
#
# WHY THE EXPLICIT LINK ARGS
#
# `-Db_sanitize` alone is not enough here. The library and the shim are shared
# objects, so the link needs BOTH `-fsanitize=` on the link line and
# `b_lundef=false` — meson passes `-Wl,--no-undefined` by default, and a
# sanitized DSO legitimately leaves the runtime's symbols undefined until the
# executable pulls libasan/libtsan in. An earlier attempt configured the
# sanitize flag without the link args, produced a `.so` with no sanitizer
# runtime attached, and reported a clean run that had never instrumented
# anything. That is why this script asserts the runtime is present with `ldd`
# before it exits, instead of trusting the configure step.
#
# WHY -fpermissive
#
# im2d_impl.cpp casts `void*` to `unsigned int` in the `#else` half of
# `#if defined(__arm64__) || defined(__aarch64__)`. On the device arch that code
# is not compiled. On an x86_64 development host it is, and GCC makes the
# narrowing cast a hard error unless `-fpermissive` downgrades it. The flag is
# what lets the sanitizers run on a non-aarch64 host at all; on aarch64 it is a
# no-op.
set -euo pipefail

root=$(realpath "$(dirname "${BASH_SOURCE[0]}")/..")
cd "$root"

mode=${1:-}
case "$mode" in
	asan) sanitize='address,undefined' ;;
	tsan) sanitize='thread' ;;
	*)
		printf 'usage: %s {asan|tsan}\n' "$0" >&2
		exit 2
		;;
esac

build="build-$mode"

for tool in meson ninja g++ ldd; do
	command -v "$tool" >/dev/null || { printf 'missing tool: %s\n' "$tool" >&2; exit 77; }
done

# `-fno-omit-frame-pointer` is what makes a sanitizer report name the frames a
# human can act on; without it the backtraces are unusable on -O0 too.
common_args='-fno-omit-frame-pointer -g'

setup=(setup "$build" "$root"
	-Dbuildtype=debug
	-Db_sanitize="$sanitize"
	-Db_lundef=false
	-Dlibrga_demo=false
	-Dc_args="$common_args"
	-Dcpp_args="$common_args -fpermissive"
	-Dc_link_args="-fsanitize=$sanitize"
	-Dcpp_link_args="-fsanitize=$sanitize")

if [[ -f $build/meson-private/coredata.dat ]]; then
	meson "${setup[@]}" --wipe
else
	meson "${setup[@]}"
fi
meson compile -C "$build"

# --- the assertion the configure step cannot make for us -------------------------
# A sanitized build whose runtime never got linked is worse than no build: it is
# green, fast and blind. Refuse it here rather than at report-reading time.
runtime_re='libasan|libubsan'
[[ $mode == tsan ]] && runtime_re='libtsan'

fail=0
for artifact in "$build/librga.so.2.1.0" "$build/libfake_rga.so"; do
	[[ -f $artifact ]] || { printf 'build-sanitized: missing artifact %s\n' "$artifact" >&2; fail=1; continue; }
	printf '\n=== ldd %s ===\n' "$artifact"
	if ldd "$artifact" | grep -Ei "$runtime_re"; then
		:
	else
		printf 'build-sanitized: FAIL: %s links no %s runtime\n' "$artifact" "$mode" >&2
		fail=1
	fi
done
((fail == 0)) || exit 1

# --- canaries -------------------------------------------------------------------
# Five lines of deliberate wrongdoing each, built with the same flags as the tree
# above. They exist to answer one question the `ldd` check cannot: is the runtime
# merely LINKED, or is it actually INTERCEPTING? A canary that stays silent means
# every clean report from this tree is worthless.
canary_flags=(-std=gnu11 -O1 -g -fno-omit-frame-pointer "-fsanitize=$sanitize")
if [[ $mode == asan ]]; then
	gcc "${canary_flags[@]}" tests/shim/asan-canary.c -o "$build/asan-canary"
	printf 'built %s/asan-canary\n' "$build"
else
	gcc "${canary_flags[@]}" -pthread tests/shim/tsan-canary.c -o "$build/tsan-canary"
	printf 'built %s/tsan-canary\n' "$build"
fi

printf '\nbuild-sanitized: OK (%s, %s)\n' "$mode" "$sanitize"
