#!/usr/bin/env bash
set -euo pipefail

# Prove the two directions a device actually takes, in a clean root:
#
#   forward   Radxa librga2 installed, something depending on it installed,
#             then librga2-ceralive goes in. librga2 must come out and the
#             dependent package must STAY, satisfied by our Provides.
#   rollback  librga2-ceralive installed, then Radxa librga2 goes back in.
#
# The rollback direction is the one worth testing rather than assuming: a
# versioned Provides plus Conflicts is a pair of constraints apt can refuse to
# solve, and finding that out on a board mid-incident is too late. This script
# records the command that ACTUALLY worked, and docs/ROLLBACK.md quotes it.
#
#   ci/transition-test.sh [<dist-dir>]
#
# Inputs:
#   RADXA_LIBRGA2_DEB     path to the Radxa .deb (skips the download)
#   RADXA_LIBRGA2_URL     otherwise fetched from here (defaults to the URL the
#                         device image pins)
#   RADXA_LIBRGA2_SHA256  expected sha256; the download fails closed on mismatch
#   ROLLBACK_RECORD       file to write the passing rollback command into

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
dist="${1:-${root}/dist}"
[ -d "${dist}" ] || { echo "no dist directory: ${dist}" >&2; exit 2; }
# See ci/install-smoke.sh: apt only treats an argument as a local file when it
# starts with / or ./, so every .deb path handed to it below is absolute.
dist="$(cd "${dist}" && pwd)"
work="$(mktemp -d)"
trap 'rm -rf "${work}"' EXIT

readonly DEFAULT_URL="https://radxa-repo.github.io/rk3588s2-bookworm/pool/main/libr/librga/librga2_2.2.0-1_arm64.deb"
readonly DEFAULT_SHA="ca4f18666f6c5d5290c7e41e5901350ecf76530f24364e37b81fa6be4ab5f344"
url="${RADXA_LIBRGA2_URL:-${DEFAULT_URL}}"
want_sha="${RADXA_LIBRGA2_SHA256:-${DEFAULT_SHA}}"
rollback_record="${ROLLBACK_RECORD:-${work}/rollback-command}"

fail() { printf 'transition-test: FAIL: %s\n' "$1" >&2; exit 1; }

ceralive_deb="$(find "${dist}" -maxdepth 1 -name 'librga2-ceralive_*.deb' | head -1)"
[ -n "${ceralive_deb}" ] || fail "no librga2-ceralive_*.deb in ${dist}"

radxa_deb="${work}/librga2_2.2.0-1_arm64.deb"
if [ -n "${RADXA_LIBRGA2_DEB:-}" ]; then
	cp "${RADXA_LIBRGA2_DEB}" "${radxa_deb}"
else
	curl -fsSL -o "${radxa_deb}" "${url}"
fi
got_sha="$(sha256sum "${radxa_deb}" | cut -d' ' -f1)"
[ "${got_sha}" = "${want_sha}" ] \
	|| fail "Radxa .deb sha256 ${got_sha} does not match the pin ${want_sha}"

# A minimal stand-in for whatever the image installs that needs librga2 —
# gstreamer1.0-rockchip-ceralive on a real device. Built here so the test does
# not depend on a third package being fetchable.
stub="${work}/stub/librga-transition-stub"
mkdir -p "${stub}/DEBIAN"
cat >"${stub}/DEBIAN/control" <<'EOF'
Package: librga-transition-stub
Version: 1
Architecture: arm64
Maintainer: CERALIVE <contact@ceralive.tv>
Depends: librga2
Section: libs
Priority: optional
Description: Transition-test stand-in for a package that depends on librga2
 Installed only by ci/transition-test.sh, to prove that replacing librga2 with
 librga2-ceralive does not drag its dependents out with it.
EOF
dpkg-deb --root-owner-group --build "${stub}" "${work}/librga-transition-stub.deb" >/dev/null

installed() { dpkg-query -W -f='${Status}' "$1" 2>/dev/null | grep -q 'install ok installed'; }

echo "=== forward: Radxa librga2 + dependent  ->  librga2-ceralive ==="
apt-get install -y --no-install-recommends "${radxa_deb}" "${work}/librga-transition-stub.deb"
installed librga2 || fail "setup: Radxa librga2 did not install"
installed librga-transition-stub || fail "setup: the dependent stub did not install"

apt-get install --yes "${ceralive_deb}"
installed librga2-ceralive || fail "forward: librga2-ceralive is not installed"
! installed librga2 || fail "forward: Radxa librga2 is still installed; Conflicts did not take effect"
installed librga-transition-stub \
	|| fail "forward: the dependent package was removed; Provides: librga2 did not satisfy it"
echo "forward: PASS (librga2 removed, dependent retained)"

echo
echo "=== rollback: librga2-ceralive  ->  Radxa librga2 ==="
rollback_apt=(apt-get install --yes --allow-downgrades "${radxa_deb}")
if "${rollback_apt[@]}"; then
	printf 'apt-get install --yes --allow-downgrades ./librga2_2.2.0-1_arm64.deb\n' >"${rollback_record}"
else
	echo "apt refused the direct rollback; falling back to the dpkg sequence"
	dpkg --remove --force-depends librga2-ceralive
	dpkg -i "${radxa_deb}"
	apt-get -f install -y
	{
		printf 'dpkg --remove --force-depends librga2-ceralive\n'
		printf 'dpkg -i ./librga2_2.2.0-1_arm64.deb\n'
		printf 'apt-get -f install\n'
	} >"${rollback_record}"
fi
installed librga2 || fail "rollback: Radxa librga2 is not installed"
! installed librga2-ceralive || fail "rollback: librga2-ceralive is still installed"
installed librga-transition-stub || fail "rollback: the dependent package was removed"
echo "rollback: PASS (librga2-ceralive removed, dependent retained)"

echo
echo "the rollback command that passed:"
sed 's/^/  /' "${rollback_record}"
echo "transition-test: OK"
