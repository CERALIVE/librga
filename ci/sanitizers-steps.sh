#!/usr/bin/env bash
set -euo pipefail

# The whole of the sanitizers job, in one script, so a developer runs EXACTLY
# what CI runs without opening a pull request first:
#
#   docker run --rm -v "$PWD":/src -w /src \
#     debian:trixie-slim bash ci/sanitizers-steps.sh
#
# .github/workflows/build-check.yml calls this and nothing else. Same rule as
# ci/build-check-steps.sh: a step that lives in the workflow instead of here is a
# step nobody can reproduce locally.
#
# Environment:
#   SKIP_DEPS=1   skip apt-get (a warm container)
#
# WHAT THIS JOB PROVES, AND WHAT IT DOES NOT
#
# HOST SHIM ONLY. Every binary here talks to tests/shim/fake_rga.c, not to
# /dev/rga. A clean report is evidence about this library's behaviour against the
# shim's model of the driver — it is not evidence about silicon, and no board
# drill or ledger row may cite it as such. See AGENTS.md, "The suite does NOT
# prove", and docs/SANITIZERS.md.
#
# The canaries are not decoration. `ldd` proves a runtime is LINKED; only a
# deliberate fault proves it is INTERCEPTING. Without them a misconfigured
# sanitize flag yields a fast, green job that instrumented nothing — which is
# exactly the failure this job replaced.

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${root}"

fail() { printf '\nsanitizers-steps: FAIL: %s\n' "$1" >&2; exit 1; }
step() { printf '\n=== %s ===\n' "$1"; }

# shellcheck source=target-suite.env
. "${root}/ci/target-suite.env"
for key in TARGET_SUITE TARGET_ARCH; do
	[ -n "${!key:-}" ] || fail "${key} is not declared in ci/target-suite.env"
done

[ -r /etc/os-release ] || fail "no /etc/os-release; this script runs inside a Debian suite container"
# shellcheck disable=SC1091
suite="$(. /etc/os-release && printf '%s' "${VERSION_CODENAME:-}")"
# The sanitizer runtimes are toolchain artifacts, so this leg is pinned to the
# suite whose toolchain builds the shipped package. Running it on the secondary
# suite would report about a compiler the device never sees.
[ "${suite}" = "${TARGET_SUITE}" ] \
	|| fail "running in debian:${suite}; the sanitizer legs are pinned to the target suite (${TARGET_SUITE})"

if [ "${SKIP_DEPS:-0}" != "1" ]; then
	step "install build dependencies (debian:${suite})"
	export DEBIAN_FRONTEND=noninteractive
	apt-get update
	apt-get install -y --no-install-recommends \
		ca-certificates \
		curl \
		g++ \
		git \
		meson \
		ninja-build \
		pkg-config \
		python3
fi

for tool in meson ninja g++ gcc ldd python3; do
	command -v "${tool}" >/dev/null || fail "${tool} is not installed"
done

if command -v git >/dev/null && [ -e "${root}/.git" ]; then
	git config --global --add safe.directory "${root}" || true
fi

arch="$(dpkg --print-architecture)"
printf '\nsanitizers-steps: debian:%s · %s · %s\n' "${suite}" "${arch}" "$(g++ --version | sed -n 1p)"

# ARCHITECTURE HONESTY
#
# CI runs this on the device arch. A developer reproducing it on an x86_64
# workstation is NOT compiling the same code: im2d_impl.cpp and NormalRga.cpp
# guard their pointer arithmetic with `#if defined(__arm64__) || defined(__aarch64__)`,
# and the `#else` half — which truncates a `void*` into an `unsigned int` — is
# what an x86_64 host analyses. Say so rather than letting a green local run be
# read as a green device run.
if [ "${arch}" != "${TARGET_ARCH}" ]; then
	cat <<EOF

=== NOTE: this is a ${arch} portability run, not a ${TARGET_ARCH} run ===
The library's pointer-arithmetic paths are selected by __aarch64__. On ${arch}
the #else half compiles instead, so a finding here may not exist on the device
and a device finding may not appear here. The authoritative run is the CI leg on
${TARGET_ARCH}.
EOF
fi

# ASAN_OPTIONS is defined ONCE and used for both the canary and the test run, so
# the canary proves interception in the exact configuration the tests use.
#
# verify_asan_link_order=0 is required, not cosmetic. The golden and session
# tests reach librga through LD_PRELOAD of the shim, which puts a foreign DSO
# ahead of libasan in the initial library list; ASan's conservative ordering
# check then refuses to start. Interception still resolves through libasan —
# neither the executable nor the shim defines the intercepted allocator symbols —
# and the canary below is run under this same preload to prove exactly that.
ASAN_OPTIONS='detect_leaks=1:verify_asan_link_order=0:abort_on_error=1'
UBSAN_TEST_OPTIONS='print_stacktrace=1:halt_on_error=1'
# The canary must NOT halt on its UBSan finding, or the ASan finding in the same
# process would never be reached and only half the recipe would be proven.
UBSAN_CANARY_OPTIONS='print_stacktrace=1:halt_on_error=0'

mkdir -p test-results

# --- ASan + UBSan ----------------------------------------------------------------
step "build-sanitized.sh asan (address,undefined)"
bash scripts/build-sanitized.sh asan

step "asan canary — the runtimes must intercept, not merely link"
canary_out=test-results/asan-canary.txt
canary_rc=0
LD_PRELOAD="${root}/build-asan/libfake_rga.so" \
	ASAN_OPTIONS="${ASAN_OPTIONS}" \
	UBSAN_OPTIONS="${UBSAN_CANARY_OPTIONS}" \
	./build-asan/asan-canary >"${canary_out}" 2>&1 || canary_rc=$?
sed -n '1,25p' "${canary_out}"
[ "${canary_rc}" -ne 0 ] || fail "asan-canary exited 0; the sanitizer runtimes are not intercepting"
grep -q 'ERROR: AddressSanitizer: heap-buffer-overflow' "${canary_out}" \
	|| fail "asan-canary produced no AddressSanitizer heap-buffer-overflow report"
grep -q 'runtime error: signed integer overflow' "${canary_out}" \
	|| fail "asan-canary produced no UndefinedBehaviorSanitizer report"
printf 'asan-canary: both runtimes reported under the test configuration\n'

# The suite is named explicitly rather than run wholesale. `uapi-parity` is a
# static ABI comparison that regenerates docs/UAPI-PARITY.md as a side effect —
# running it here would rewrite an aarch64 record with a host-arch one — and the
# `board-*` tests belong to the board harness.
step "meson test under ASan+UBSan (unit, goldens, shim)"
ASAN_OPTIONS="${ASAN_OPTIONS}" UBSAN_OPTIONS="${UBSAN_TEST_OPTIONS}" \
	meson test -C build-asan --print-errorlogs \
	unit-pure unit-session shim-contract goldens
cp build-asan/meson-logs/testlog.txt test-results/asan-testlog.txt

# --- ThreadSanitizer -------------------------------------------------------------
# Host-only, permanently. TSan cannot be statically linked reliably, so there is
# no board-side equivalent and no TSan row may ever be recorded against hardware.
step "build-sanitized.sh tsan (thread)"
bash scripts/build-sanitized.sh tsan

step "tsan canary — the runtime must intercept, not merely link"
tsan_out=test-results/tsan-canary.txt
tsan_rc=0
TSAN_OPTIONS='halt_on_error=1:exitcode=66' ./build-tsan/tsan-canary >"${tsan_out}" 2>&1 || tsan_rc=$?
sed -n '1,20p' "${tsan_out}"
[ "${tsan_rc}" -ne 0 ] || fail "tsan-canary exited 0; the ThreadSanitizer runtime is not intercepting"
grep -q 'WARNING: ThreadSanitizer: data race' "${tsan_out}" \
	|| fail "tsan-canary produced no ThreadSanitizer data-race report"
printf 'tsan-canary: the runtime reported the deliberate race\n'

# THE DISCOVERY CONTRACT for the concurrency reproducers (todos 21-30):
# register the test in the Meson `concurrency` suite and this leg picks it up
# with no edit here. Until one exists the count is 0 and this script SAYS SO
# rather than printing a green line that stands for nothing.
step "meson test under TSan (concurrency suite)"
concurrency_count="$(python3 - <<'PY'
import json, pathlib
tests = json.loads(pathlib.Path('build-tsan/meson-info/intro-tests.json').read_text())
print(sum(1 for t in tests if 'concurrency' in t.get('suite', [])))
PY
)"
if [ "${concurrency_count}" -gt 0 ]; then
	TSAN_OPTIONS='halt_on_error=1:exitcode=66' \
		meson test -C build-tsan --print-errorlogs --suite concurrency
	cp build-tsan/meson-logs/testlog.txt test-results/tsan-testlog.txt
	printf 'TSan: %s concurrency test(s) ran\n' "${concurrency_count}"
else
	cat <<'EOF'
NO CONCURRENCY REPRODUCER REGISTERED YET.
The TSan runtime is proven active by the canary above, and zero concurrency
tests ran. This leg claims nothing about librga's thread safety. Add a test to
the Meson `concurrency` suite and it runs here automatically.
EOF
fi

{
	printf '# sanitizers-steps summary\n'
	printf 'suite            : debian:%s\n' "${suite}"
	printf 'arch             : %s (device target %s)\n' "${arch}" "${TARGET_ARCH}"
	printf 'compiler         : %s\n' "$(g++ --version | sed -n 1p)"
	printf 'asan canary      : reported (ASan + UBSan)\n'
	printf 'tsan canary      : reported (data race)\n'
	printf 'concurrency tests: %s\n' "${concurrency_count}"
	printf 'coverage claimed : host shim only — never the board\n'
} >test-results/sanitizers-summary.txt
cat test-results/sanitizers-summary.txt

printf '\nsanitizers-steps: OK (debian:%s, %s)\n' "${suite}" "${arch}"
