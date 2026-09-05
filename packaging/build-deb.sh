#!/usr/bin/env bash
set -euo pipefail

# Hand-rolled packaging for the two librga binary packages.
#
# The upstream debian/ directory carried in this tree is preserved and NEVER
# invoked (docs/PROVENANCE.md). This script does not use debhelper, and that is
# the point rather than an omission: dpkg-deb does not expand substvars, so a
# ${shlibs:Depends} left in DEBIAN/control ships to devices as literal text. Every
# control field below is a concrete string, and the dependency closure is derived
# from the built ELF and checked against a frozen literal.
#
#   librga2-ceralive      the runtime library, replaces Radxa's librga2
#   librga-ceralive-dev   headers, the .so development symlink and librga.pc
#
# Run it in the target-suite container (ci/target-suite.env) on arm64:
#
#   docker run --rm --platform linux/arm64 -v "$PWD":/src -w /src \
#     debian:trixie-slim bash -c 'apt-get update && apt-get install -y \
#     meson ninja-build g++ pkg-config libdrm-dev dpkg-dev binutils && \
#     bash packaging/build-deb.sh'

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# dpkg-buildflags derives -ffile-prefix-map from the CURRENT directory, so the
# build runs from a fixed one. Two runs launched from different directories would
# otherwise be handed different compiler command lines for the same source.
cd "${root}"

fail() { printf 'build-deb: FAIL: %s\n' "$1" >&2; exit 1; }

# --- Frozen contracts. Other repositories and later releases key on these -----
readonly RUNTIME_PKG="librga2-ceralive"
readonly DEV_PKG="librga-ceralive-dev"
readonly SONAME="librga.so.2"
readonly REAL_SO="librga.so.2.1.0"
# The Radxa packages this fork replaces, and the upstream version its librga2
# claims. Provides is VERSIONED at that value so a dependency written against
# Radxa's package keeps resolving; Conflicts/Replaces are unversioned so the
# replacement holds for any Radxa revision.
readonly REPLACED_RUNTIME="librga2"
readonly REPLACED_RUNTIME_VERSION="2.2.0"
readonly REPLACED_DEV="librga-dev"

# The ELF NEEDED closure of the shipped library, mapped to the Debian package
# that supplies each SONAME. Resolved with dpkg -S in the arm64 target container,
# not guessed. libdrm2 is listed because the tree bundles DRM headers and a future
# change could start linking the library — if that happens the derivation below
# refuses the build rather than shipping an undeclared runtime dependency.
readonly SONAME_PACKAGES="\
libc.so.6=libc6
libm.so.6=libc6
ld-linux-aarch64.so.1=libc6
libgcc_s.so.1=libgcc-s1
libstdc++.so.6=libstdc++6
libdrm.so.2=libdrm2"

# The Depends line the build must produce, character for character. It is
# asserted rather than merely emitted: under-declaring a runtime dependency is
# invisible in a build container, where the library is already installed, and
# only a device fails.
#
# libdrm2 is deliberately ABSENT. -Dlibdrm=true is passed because upstream's own
# debian/rules passes it, but at this tree state meson.build never reads the
# option and the built library has no libdrm.so.2 in NEEDED. Radxa's librga2
# 2.2.0-1 declares the same three packages for the same reason. Declaring libdrm2
# here would be a build-flag transcription, not the ELF closure.
readonly EXPECT_RUNTIME_DEPENDS="libc6 (>= 2.38), libgcc-s1, libstdc++6 (>= 11)"

# libstdc++ symbol version -> the Debian libstdc++6 version that first provided
# it. Used to turn the binary's real GLIBCXX_ imports into a dependency floor
# instead of copying one from another package.
readonly GLIBCXX_FLOORS="\
3.4.29=11
3.4.30=12
3.4.31=13.1
3.4.32=13.2
3.4.33=14
3.4.34=15"

# SOURCE_DATE_EPOCH is the commit date of the last commit touching a PACKAGED
# INPUT, never HEAD's date. A merge commit, a docs commit or a test commit must
# not move the archive hashes, so the .deb a board was drilled with stays
# byte-identical to the published one. This list is the definition of "packaged
# input" and package-contract.sh asserts it has not been edited.
readonly PACKAGED_INPUTS=(
	core
	im2d_api
	include
	meson.build
	meson_options.txt
	packaging/version
	packaging/build-deb.sh
	packaging/copyright
)

# --- Version -------------------------------------------------------------------
# First non-comment, non-blank line of packaging/version. The comments in that
# file explain which release line overwrites it with what.
version="$(sed -e 's/#.*//' -e 's/[[:space:]]//g' "${root}/packaging/version" | grep -m1 . || true)"
[ -n "${version}" ] || fail "packaging/version carries no version line"

arch="${DEB_ARCH:-$(dpkg --print-architecture)}"
# arm64 only, and deliberately so: this library drives the RK3588 2D engine
# through /dev/rga. A build for any other architecture would produce a package
# with no hardware behind it.
case "${arch}" in
	arm64) ;;
	*) fail "unsupported Debian architecture: ${arch} (librga is RK3588/arm64 only)" ;;
esac
triplet="$(dpkg-architecture -a "${arch}" -qDEB_HOST_MULTIARCH)"

build_dir="${BUILD_DIR:-${root}/build-deb-${arch}}"
install_dir="${INSTALL_DIR:-${root}/install-deb-${arch}}"
stage_run="${STAGE_RUN_DIR:-${root}/stage-deb-${arch}/${RUNTIME_PKG}}"
stage_dev="${STAGE_DEV_DIR:-${root}/stage-deb-${arch}/${DEV_PKG}}"
out_dir="${OUT_DIR:-${root}/dist}"

if [ -z "${SOURCE_DATE_EPOCH:-}" ]; then
	SOURCE_DATE_EPOCH="$(git -C "${root}" log -1 --format=%ct -- "${PACKAGED_INPUTS[@]}" 2>/dev/null || true)"
fi
[ -n "${SOURCE_DATE_EPOCH}" ] \
	|| fail "SOURCE_DATE_EPOCH could not be derived from the packaged inputs; pass it explicitly outside a git checkout"
export SOURCE_DATE_EPOCH

rm -rf "${build_dir}" "${install_dir}" "${stage_run}" "${stage_dev}"

# --- Hardening -----------------------------------------------------------------
# The Debian defaults already give stack-protector-strong, stack-clash-protection,
# -mbranch-protection=standard (BTI/PAC on aarch64) and partial RELRO. Two things
# they do not give are added explicitly:
#
#   bindnow  -> -Wl,-z,now, which turns partial RELRO into full RELRO
#   fortify  -> level 3 rather than the suite default of 2
#
# The FORTIFY level is rewritten rather than appended: appending would leave the
# default -D_FORTIFY_SOURCE=2 on the command line and produce a redefinition.
export DEB_BUILD_MAINT_OPTIONS="hardening=+bindnow"
eval "$(dpkg-buildflags --export=sh)"
CPPFLAGS="$(printf '%s' "${CPPFLAGS}" | sed -E 's/-D_FORTIFY_SOURCE=[0-9]+//g') -U_FORTIFY_SOURCE -D_FORTIFY_SOURCE=3"

# The extra flag set this tree needs beyond dpkg-buildflags on the target suite.
# It is EMPTY, and that is a measured result rather than an assumption: the tree
# compiles clean on trixie aarch64 with GCC 14.2, including the C++ conversions
# that were expected to need -fpermissive. See docs/BUILD-FLAGS.md. Anything added
# here must be recorded there in the same change.
readonly EXTRA_CXXFLAGS=""

# dpkg-buildflags maps the SOURCE directory out of the debug info, but the
# compiler's own working directory is the BUILD directory, and that lands in
# DW_AT_comp_dir. The linker hashes the debug info into .note.gnu.build-id, which
# survives stripping — so without this second map, two builds that differ only in
# where they were built produce .debs with different checksums and nothing in the
# stripped output shows why.
prefix_map="-ffile-prefix-map=${build_dir}=."
export CFLAGS="${CFLAGS} ${CPPFLAGS} ${prefix_map}"
export CXXFLAGS="${CXXFLAGS} ${CPPFLAGS} ${prefix_map} ${EXTRA_CXXFLAGS}"
export LDFLAGS

case " ${LDFLAGS} " in
	*" -Wl,-z,now "*) ;;
	*) fail "LDFLAGS lost -Wl,-z,now; full RELRO is a packaging contract" ;;
esac

# --- Build ---------------------------------------------------------------------
# Every option is stated explicitly rather than left at its default. -Dlibdrm=true
# mirrors upstream debian/rules; -Dlibrga_demo=false keeps the sample binary and
# its bundled prebuilt libdrm.so out of the packages entirely.
meson setup "${build_dir}" "${root}" \
	--prefix=/usr \
	--libdir="lib/${triplet}" \
	--buildtype=release \
	-Dlibdrm=true \
	-Dlibrga_demo=false
meson compile -C "${build_dir}"
DESTDIR="${install_dir}" meson install -C "${build_dir}"

libdir="${install_dir}/usr/lib/${triplet}"
[ -f "${libdir}/${REAL_SO}" ] || fail "meson did not install ${REAL_SO}"

# The static archive is built by meson and installed by it, and neither package
# ships it: Radxa's librga-dev ships only the .so symlink, the headers and the
# .pc file, and a static librga would let a consumer bake this library's code
# into its own binary, defeating the point of replacing the shared object.
rm -f "${libdir}/librga.a"

# dh_strip's flags for a shared object: dynamic symbols survive, so the export
# contract is unchanged. .comment goes because it only records the compiler
# version. .note is deliberately KEPT — .note.gnu.property is where the AArch64
# BTI/PAC feature bits live, and dropping it would silently delete the evidence
# for the hardening this script just asked for.
strip --strip-unneeded --remove-section=.comment "${libdir}/${REAL_SO}"

# --- Dependency closure, derived from the built ELF ----------------------------
needed="$(objdump -p "${libdir}/${REAL_SO}" | awk '/NEEDED/{print $2}' | sort -u)"
declare -A needed_pkgs=()
while IFS= read -r soname; do
	[ -n "${soname}" ] || continue
	pkg="$(grep -F "${soname}=" <<<"${SONAME_PACKAGES}" | cut -d= -f2 || true)"
	[ -n "${pkg}" ] \
		|| fail "the library links ${soname}, which the frozen SONAME map does not cover"
	needed_pkgs["${pkg}"]=1
done <<<"${needed}"

readelf_soname="$(objdump -p "${libdir}/${REAL_SO}" | awk '/SONAME/{print $2}')"
[ "${readelf_soname}" = "${SONAME}" ] \
	|| fail "SONAME is FROZEN at ${SONAME}, built library reports ${readelf_soname}"

symver_max() { objdump -T "$1" | grep -oE "$2"'_[0-9][0-9.]*' | sed "s/^$2"'_//' | sort -V | tail -1; }
glibc_max="$(symver_max "${libdir}/${REAL_SO}" GLIBC)"
glibcxx_max="$(symver_max "${libdir}/${REAL_SO}" GLIBCXX)"
[ -n "${glibc_max}" ] || fail "no GLIBC_ symbol versions found in the built library"
[ -n "${glibcxx_max}" ] || fail "no GLIBCXX_ symbol versions found in the built library"
stdcxx_floor="$(grep -F "${glibcxx_max}=" <<<"${GLIBCXX_FLOORS}" | cut -d= -f2 || true)"
[ -n "${stdcxx_floor}" ] \
	|| fail "GLIBCXX_${glibcxx_max} is not in the frozen libstdc++6 floor table"

derived_depends="libc6 (>= ${glibc_max}), libgcc-s1, libstdc++6 (>= ${stdcxx_floor})"
[ "${derived_depends}" = "${EXPECT_RUNTIME_DEPENDS}" ] \
	|| fail "the built library needs '${derived_depends}' but the frozen Depends is '${EXPECT_RUNTIME_DEPENDS}' — update both together, deliberately"
for pkg in "${!needed_pkgs[@]}"; do
	case ", ${EXPECT_RUNTIME_DEPENDS}," in
		*", ${pkg},"*|*", ${pkg} ("*) ;;
		*) fail "Depends omits ${pkg}, which supplies a linked SONAME" ;;
	esac
done

# --- Stage the two packages ----------------------------------------------------
# Runtime: the real object and the SONAME symlink, nothing else. Development: the
# link-time symlink, the headers and the pkg-config file. The split is by path,
# so a new install target lands in neither package and is caught by the contract
# test rather than riding silently into the runtime .deb.
install -d "${stage_run}/usr/lib/${triplet}"
mv "${libdir}/${REAL_SO}" "${libdir}/${SONAME}" "${stage_run}/usr/lib/${triplet}/"

install -d "${stage_dev}/usr/lib/${triplet}/pkgconfig"
mv "${libdir}/librga.so" "${stage_dev}/usr/lib/${triplet}/"
mv "${libdir}/pkgconfig/librga.pc" "${stage_dev}/usr/lib/${triplet}/pkgconfig/"
mv "${install_dir}/usr/include" "${stage_dev}/usr/"

leftover="$(find "${install_dir}" -type f -o -type l | sort)"
[ -z "${leftover}" ] \
	|| fail "meson installed files that neither package claims:"$'\n'"${leftover}"

# --- Documentation -------------------------------------------------------------
# The Apache-2.0 text, the machine-readable per-holder attribution generated from
# the licence census, and a Debian changelog, at the paths dpkg and licence
# auditors both expect.
write_docs() {
	local stage="$1" pkg="$2" doc_dir
	doc_dir="${stage}/usr/share/doc/${pkg}"
	install -Dm644 "${root}/packaging/copyright" "${doc_dir}/copyright"
	install -Dm644 "${root}/COPYING" "${doc_dir}/COPYING"
	# -n omits the filename and mtime header so the same input always gzips to
	# the same bytes.
	gzip -9n >"${doc_dir}/changelog.Debian.gz" <<EOF
${pkg} (${version}) unstable; urgency=medium

  * CeraLive build of the Rockchip RGA userspace library, from the imported
    JeffyCN linux-rga-multi history recorded in docs/PROVENANCE.md.
  * Replaces ${REPLACED_RUNTIME} and ${REPLACED_DEV} on the device image; the
    SONAME ${SONAME} and the installed paths are unchanged.

 -- CERALIVE <contact@ceralive.tv>  $(date -R -u -d "@${SOURCE_DATE_EPOCH}")
EOF
}
write_docs "${stage_run}" "${RUNTIME_PKG}"
write_docs "${stage_dev}" "${DEV_PKG}"

# --- Control -------------------------------------------------------------------
mkdir -p "${stage_run}/DEBIAN" "${stage_dev}/DEBIAN"

cat >"${stage_run}/DEBIAN/control" <<EOF
Package: ${RUNTIME_PKG}
Version: ${version}
Architecture: ${arch}
Maintainer: CERALIVE <contact@ceralive.tv>
Installed-Size: $(du -ks "${stage_run}" | cut -f1)
Depends: ${EXPECT_RUNTIME_DEPENDS}
Provides: ${REPLACED_RUNTIME} (= ${REPLACED_RUNTIME_VERSION})
Conflicts: ${REPLACED_RUNTIME}
Replaces: ${REPLACED_RUNTIME}
Section: libs
Priority: optional
Homepage: https://github.com/CERALIVE/librga
License: Apache-2.0
Description: CeraLive build of the Rockchip RGA 2D accelerator library
 The userspace side of the RK3588 2D engine: format conversion, scaling,
 rotation and blending through /dev/rga, used by the CeraLive GStreamer plugin
 set and by anything else that links librga.so.2.
 .
 This is CeraLive's build of the Rockchip library, from an imported upstream
 history whose fork point and API release are recorded commit by commit rather
 than asserted. It replaces ${REPLACED_RUNTIME} and provides that package name,
 so nothing downstream has to learn a new dependency.
EOF

cat >"${stage_dev}/DEBIAN/control" <<EOF
Package: ${DEV_PKG}
Version: ${version}
Architecture: ${arch}
Maintainer: CERALIVE <contact@ceralive.tv>
Installed-Size: $(du -ks "${stage_dev}" | cut -f1)
Depends: ${RUNTIME_PKG} (= ${version})
Provides: ${REPLACED_DEV}
Conflicts: ${REPLACED_DEV}
Replaces: ${REPLACED_DEV}
Section: libdevel
Priority: optional
Homepage: https://github.com/CERALIVE/librga
License: Apache-2.0
Description: CeraLive build of the Rockchip RGA 2D accelerator library (development)
 Headers under /usr/include/rga, the librga.so development symlink and the
 librga.pc pkg-config file for building against ${RUNTIME_PKG}.
 .
 The dependency on ${RUNTIME_PKG} is exact rather than a floor: the headers and
 the shared object are two halves of one build and are never mixed across
 versions.
EOF

# dpkg-deb does not expand substvars. A ${...} that survives to here ships to a
# device as literal text in the control field, so the check is worth its line.
for control in "${stage_run}/DEBIAN/control" "${stage_dev}/DEBIAN/control"; do
	! grep -q '\${' "${control}" \
		|| fail "unexpanded substvar in ${control}; dpkg-deb never expands these"
done
grep -qxF "Depends: ${EXPECT_RUNTIME_DEPENDS}" "${stage_run}/DEBIAN/control" \
	|| fail "runtime control Depends is not the frozen literal"
grep -qxF "Depends: ${RUNTIME_PKG} (= ${version})" "${stage_dev}/DEBIAN/control" \
	|| fail "dev control must depend on ${RUNTIME_PKG} at the exact version"

# --- Build the archives --------------------------------------------------------
# Timestamps are normalised rather than left to dpkg-deb's clamping, so the
# archives are reproducible on any dpkg version and the two runs of a
# reproducibility check compare bytes rather than luck.
mkdir -p "${out_dir}"
debs=()
for spec in "${stage_run}:${RUNTIME_PKG}" "${stage_dev}:${DEV_PKG}"; do
	stage="${spec%%:*}"; pkg="${spec##*:}"
	find "${stage}" -exec touch --no-dereference --date="@${SOURCE_DATE_EPOCH}" {} +
	deb="${out_dir}/${pkg}_${version}_${arch}.deb"
	dpkg-deb --root-owner-group --build "${stage}" "${deb}" >/dev/null
	debs+=("${deb}")
done
printf '%s\n' "${debs[@]}"
