#!/usr/bin/env bash
set -euo pipefail

# Refuse a library that imports a symbol version the target suite cannot supply.
#
# The failure this exists to prevent is silent: a build container that is newer
# than the device produces a binary needing, say, GLIBC_2.42, the package
# installs cleanly because apt only checks the declared Depends, and the library
# fails to load on the board with an "version not found" message at the moment
# the stream starts. Reading the imports off the ELF is the only check that
# catches it before a device does.
#
#   ci/check-abi-floors.sh <path-to-librga.so.2.1.0>
#
# Floors come from ci/target-suite.env and are facts about TARGET_SUITE, not
# independent pins.

usage() { echo "usage: $0 <shared-object>" >&2; exit 2; }
[ "$#" -eq 1 ] || usage
so="$1"
[ -f "${so}" ] || { echo "no such file: ${so}" >&2; exit 2; }

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=target-suite.env
. "${root}/ci/target-suite.env"

command -v objdump >/dev/null || { echo "objdump is required (install binutils)" >&2; exit 2; }

fail=0

# `sort -V` orders 3.4.9 before 3.4.11, which a lexical sort gets backwards and
# which is exactly the range these symbol versions live in.
max_symver() {
	objdump -T "${so}" | grep -oE "$1"'_[0-9][0-9.]*' | sed "s/^$1"'_//' | sort -V | tail -1
}

check() {
	local tag="$1" floor="$2" max
	max="$(max_symver "${tag}")"
	if [ -z "${max}" ]; then
		printf '%-8s no imports\n' "${tag}"
		return
	fi
	if [ "$(printf '%s\n%s\n' "${max}" "${floor}" | sort -V | tail -1)" != "${floor}" ]; then
		printf '%-8s FAIL  needs %s_%s, %s provides at most %s_%s\n' \
			"${tag}" "${tag}" "${max}" "${TARGET_SUITE}" "${tag}" "${floor}"
		fail=1
	else
		printf '%-8s ok    needs %s_%s <= %s_%s (%s)\n' \
			"${tag}" "${tag}" "${max}" "${tag}" "${floor}" "${TARGET_SUITE}"
	fi
}

echo "abi floors for ${so} against ${TARGET_SUITE}/${TARGET_ARCH}"
check GLIBC "${GLIBC_FLOOR}"
check GLIBCXX "${GLIBCXX_FLOOR}"
check CXXABI "${CXXABI_FLOOR}"

[ "${fail}" = "0" ] || { echo "check-abi-floors: FAIL" >&2; exit 1; }
echo "check-abi-floors: OK"
