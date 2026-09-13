#!/usr/bin/env bash
set -euo pipefail

# Install both packages into the running container and prove the library actually
# loads. `dpkg -i` succeeding proves only that an archive unpacked; the dlopen is
# what proves the dynamic linker can resolve every import, which is the failure
# an under-declared dependency or a too-new symbol version produces on a device.
#
#   ci/install-smoke.sh [<dist-dir>]
#
# Trixie verifies its own packages; Bookworm invokes this as an expected-refusal
# check because the Trixie package requires a newer glibc than Bookworm provides.

dist="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/dist}"
[ -d "${dist}" ] || { echo "no dist directory: ${dist}" >&2; exit 2; }
# Absolute, always: apt reads an argument as a local file only when it contains a
# slash AND starts with / or ./ — a bare `dist/x.deb` is parsed as the
# package/release syntax instead, and fails with a baffling "Release ... was not
# found for dist".
dist="$(cd "${dist}" && pwd)"

mapfile -t debs < <(find "${dist}" -maxdepth 1 -name '*.deb' | LC_ALL=C sort)
[ "${#debs[@]}" -eq 2 ] || { echo "expected exactly two .deb files in ${dist}, found ${#debs[@]}" >&2; exit 1; }

echo "installing: ${debs[*]}"
apt-get install -y --no-install-recommends "${debs[@]}"

for pkg in librga2-ceralive librga-ceralive-dev; do
	dpkg -s "${pkg}" >/dev/null || { echo "${pkg} is not installed" >&2; exit 1; }
done

ldconfig

# The literal SONAME, not a path: this is the name every consumer links against,
# so resolving it through the linker cache is the thing worth proving.
python3 -c "import ctypes; ctypes.CDLL('librga.so.2')"
echo "dlopen librga.so.2: OK"

pkg-config --exists librga
echo "pkg-config librga: $(pkg-config --modversion librga)"

echo "install-smoke: OK"
