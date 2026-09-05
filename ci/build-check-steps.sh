#!/usr/bin/env bash
set -euo pipefail

# The whole of build-check, in one script, so a developer runs EXACTLY what CI
# runs without opening a pull request first:
#
#   docker run --rm --platform linux/arm64 -v "$PWD":/src -w /src \
#     debian:trixie-slim bash ci/build-check-steps.sh
#   docker run --rm --platform linux/arm64 -v "$PWD":/src -w /src \
#     debian:bookworm-slim bash ci/build-check-steps.sh
#
# .github/workflows/build-check.yml calls this and nothing else for the build
# legs. A step that lives in the workflow instead of here is a step nobody can
# reproduce locally, which is how a CI-only failure becomes a guessing game.
#
# Environment:
#   SKIP_DEPS=1           skip apt-get (a warm container, or a CI leg that has
#                         already installed the suite packages)
#   SOURCE_DATE_EPOCH     passed through to packaging/build-deb.sh; derived from
#                         the packaged inputs by that script when unset
#   CCACHE_DIR            honoured for the test build if ccache is available
#
# WHICH SUITE DOES WHAT
#
# The two legs are not symmetric, and the asymmetry is a property of
# packaging/build-deb.sh rather than a shortcut taken here. That script asserts a
# FROZEN runtime Depends line derived from the built ELF's highest imported
# symbol versions. Those versions are facts about the toolchain that produced the
# library: trixie/glibc 2.41 yields `libc6 (>= 2.38)`, bookworm/glibc 2.36 yields
# `libc6 (>= 2.34)` from the same sources. Only the target suite can reproduce
# the shipped closure, and loosening the frozen literal to span both would delete
# the only check that catches an under-declared runtime dependency before a
# device does.
#
# So the secondary suite runs the source-level half — static package contract,
# configure, compile, test — and the target suite runs that plus packaging, the
# staged contract and the ABI floor gate. The secondary leg is a portability
# signal, not a second shippable package.

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${root}"

fail() { printf '\nbuild-check-steps: FAIL: %s\n' "$1" >&2; exit 1; }
step() { printf '\n=== %s ===\n' "$1"; }

# shellcheck source=target-suite.env
. "${root}/ci/target-suite.env"
for key in TARGET_SUITE SECONDARY_SUITE TARGET_ARCH TARGET_TRIPLET GLIBC_FLOOR; do
	[ -n "${!key:-}" ] || fail "${key} is not declared in ci/target-suite.env"
done

[ -r /etc/os-release ] || fail "no /etc/os-release; this script runs inside a Debian suite container"
# shellcheck disable=SC1091
suite="$(. /etc/os-release && printf '%s' "${VERSION_CODENAME:-}")"
[ -n "${suite}" ] || fail "/etc/os-release declares no VERSION_CODENAME"

case "${suite}" in
	"${TARGET_SUITE}") role="target" ;;
	"${SECONDARY_SUITE}") role="secondary" ;;
	*) fail "running in debian:${suite}, which is neither the target suite (${TARGET_SUITE}) nor the secondary suite (${SECONDARY_SUITE})" ;;
esac

# --- Dependencies ---------------------------------------------------------------
if [ "${SKIP_DEPS:-0}" != "1" ]; then
	step "install build dependencies (debian:${suite})"
	export DEBIAN_FRONTEND=noninteractive
	apt-get update
	# ca-certificates and git are not build inputs: git is how
	# packaging/build-deb.sh derives SOURCE_DATE_EPOCH from the packaged inputs,
	# and the test fragments fetch a sha-pinned header over https.
	apt-get install -y --no-install-recommends \
		ca-certificates \
		binutils \
		ccache \
		curl \
		dpkg-dev \
		g++ \
		git \
		libdrm-dev \
		meson \
		ninja-build \
		pkg-config \
		python3
fi

for tool in meson ninja g++ objdump strip dpkg-buildflags pkg-config; do
	command -v "${tool}" >/dev/null || fail "${tool} is not installed"
done

# The container runs as root against a checkout owned by another uid, and git
# refuses to read such a repository at all. build-deb.sh derives
# SOURCE_DATE_EPOCH through git, so this is a build input, not a nicety.
if command -v git >/dev/null && [ -e "${root}/.git" ]; then
	git config --global --add safe.directory "${root}" || true
fi

arch="$(dpkg --print-architecture)"
[ "${arch}" = "${TARGET_ARCH}" ] \
	|| fail "this container is ${arch}; librga is ${TARGET_ARCH} only — run docker with --platform linux/${TARGET_ARCH}"

# `sed -n 1p` rather than `head -1`: head closes the pipe after one line, the
# compiler takes SIGPIPE, and `set -o pipefail` turns a banner into exit 141.
printf '\nbuild-check-steps: debian:%s (%s leg) · %s · %s\n' \
	"${suite}" "${role}" "${arch}" "$(g++ --version | sed -n 1p)"

# --- Static package contract ------------------------------------------------------
# First, because it reads the packaging sources and builds nothing: a contract
# break should cost seconds, not a full compile.
step "package contract (static)"
bash packaging/package-contract.sh

# --- Configure and compile --------------------------------------------------------
# A build directory of its own, separate from the one packaging/build-deb.sh
# wipes and owns. The feature options mirror that script so the tests exercise
# the configuration the package ships.
step "meson setup"
if command -v ccache >/dev/null; then
	# meson has no compiler-launcher option; it reads the compiler out of the
	# environment at setup time. Only the TEST build is launched through ccache
	# — packaging/build-deb.sh keeps the plain compiler so the archive it
	# produces here is byte-comparable with the one a release produces.
	export CXX="ccache g++"
	ccache -M "${CCACHE_MAXSIZE:-200M}" >/dev/null
fi
rm -rf build
meson setup build \
	-Dlibdrm=true \
	-Dlibrga_demo=false

step "meson compile"
meson compile -C build

# --- Tests ------------------------------------------------------------------------
# Every registered test, by design rather than by name. The suites that will
# appear here once the bootstrap branches merge are `uapi-parity` (island UAPI
# static comparison), `goldens` (fake-/dev/rga request bytes), `unit-pure` and
# `unit-session`. Naming them now would fail closed on a branch that legitimately
# does not carry their Meson fragments yet; running all of them goes green when
# they land and never silently skips one that does.
step "meson test"
meson test -C build --print-errorlogs

if [ "${role}" != "target" ]; then
	cat <<EOF

=== packaging: not applicable on this leg ===
debian:${suite} is the secondary suite. It proves the source still configures,
compiles and passes its tests on an older toolchain. It cannot produce the
shipped package: packaging/build-deb.sh asserts the frozen runtime Depends
derived from the built ELF, and this suite's glibc yields a different floor than
${TARGET_SUITE} does. The .deb, the staged contract and the ABI floor gate are
properties of the target suite and are checked on that leg.

build-check-steps: OK (debian:${suite}, secondary leg)
EOF
	exit 0
fi

# --- Package ----------------------------------------------------------------------
step "packaging/build-deb.sh"
unset CXX
bash packaging/build-deb.sh

step "package contract (staged trees + dist)"
bash packaging/package-contract.sh \
	"stage-deb-${TARGET_ARCH}/librga2-ceralive" \
	"stage-deb-${TARGET_ARCH}/librga-ceralive-dev" \
	dist

# --- ABI floors -------------------------------------------------------------------
# Run against the STRIPPED library the runtime package actually ships, not the
# sibling object in the meson build tree, so the artifact itself carries the
# proof. Enforced on the target leg only: a newer suite imports newer symbol
# versions by construction, so gating the secondary leg would fail every build
# for a reason that says nothing about the device.
step "ABI floor gate (GLIBC ${GLIBC_FLOOR} · GLIBCXX ${GLIBCXX_FLOOR} · CXXABI ${CXXABI_FLOOR})"
shipped="stage-deb-${TARGET_ARCH}/librga2-ceralive/usr/lib/${TARGET_TRIPLET}/librga.so.2.1.0"
[ -f "${shipped}" ] || fail "the runtime stage does not contain ${shipped}"
bash ci/check-abi-floors.sh "${shipped}"

step "release assets"
find dist -maxdepth 1 -type f -name '*.deb' -printf '  %f\n' | LC_ALL=C sort

printf '\nbuild-check-steps: OK (debian:%s, target leg)\n' "${suite}"
