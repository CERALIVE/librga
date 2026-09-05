#!/usr/bin/env bash
# Most grep patterns below are single-quoted on purpose: they are the literal text
# of build-deb.sh, ${triplet} and all. Expanding them here would assert against
# this script's values instead of the builder's source, which is the opposite of
# what a static contract is for.
# shellcheck disable=SC2016
set -euo pipefail

# Package contract for librga2-ceralive and librga-ceralive-dev.
#
# Three modes:
#
#   package-contract.sh                       STATIC — reads the packaging
#                                             sources and the tree, builds
#                                             nothing, runs anywhere.
#   package-contract.sh <run> <dev> [<out>]   STATIC + the same contract
#                                             re-checked against the two real
#                                             staged trees and the .deb output.
#   package-contract.sh --repro               builds twice with the same derived
#                                             SOURCE_DATE_EPOCH and compares the
#                                             sha256 of both .debs.
#
# The static half is what a PR can run. The staged half proves the claims that
# are properties of the produced tree — the SONAME, the export floor, the
# hardening bits, the split between the two packages — and cannot be established
# by reading a script.

readonly RUNTIME_PKG="librga2-ceralive"
readonly DEV_PKG="librga-ceralive-dev"
# FROZEN. Consumers link this name and the image keys on it; the Meson
# project() version is what produces it, so both are locked together.
readonly SONAME="librga.so.2"
readonly REAL_SO="librga.so.2.1.0"
readonly MESON_PROJECT_VERSION="2.1.0"
readonly REPLACED_RUNTIME="librga2"
readonly REPLACED_RUNTIME_VERSION="2.2.0"
readonly REPLACED_DEV="librga-dev"
readonly EXPECT_ARCH="arm64"
readonly EXPECT_TRIPLET="aarch64-linux-gnu"
readonly EXPECT_RUNTIME_DEPENDS="libc6 (>= 2.38), libgcc-s1, libstdc++6 (>= 11)"
readonly DEP5_FORMAT="https://www.debian.org/doc/packaging-manuals/copyright-format/1.0/"
readonly SOURCE_URL="https://github.com/CERALIVE/librga"
# The im2d API release the committed baseline symbol list was taken from.
readonly BASELINE_API_RELEASE="1.10.1_[4]"
# Copyright holders that ride under the "Files: *" stanza. Anything else in the
# tree needs a stanza of its own, and the census check below fails if it lacks
# one — so a new bundled subtree cannot reach a release unattributed.
readonly ROCKCHIP_HOLDERS_RE='[Rr]ock[Cc]hip'

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
builder="${root}/packaging/build-deb.sh"
copyright="${root}/packaging/copyright"
baseline="${root}/packaging/baseline-symbols-radxa-2.2.0-1.txt"
baseline_provenance="${root}/packaging/baseline-symbols-radxa-2.2.0-1.provenance"
upstream_delta="${root}/packaging/baseline-symbols-upstream-delta.txt"
suite_env="${root}/ci/target-suite.env"

fail() { printf 'package-contract: FAIL: %s\n' "$1" >&2; exit 1; }
note() { printf 'package-contract: %s\n' "$1"; }

# The tree's own rendered im2d API version, from the four numeric macros. The
# header never contains the rendered string, so it is built here the same way the
# library builds it at runtime.
rendered_api_version() {
	awk '/#define RGA_API_(MAJOR|MINOR|REVISION|BUILD)_VERSION/ {v[$2]=$3}
	     END {printf "%s.%s.%s_[%s]\n", v["RGA_API_MAJOR_VERSION"], v["RGA_API_MINOR_VERSION"],
	                                    v["RGA_API_REVISION_VERSION"], v["RGA_API_BUILD_VERSION"]}' \
		"${root}/im2d_api/im2d_version.h"
}

bash -n "${builder}"

# --- Version -------------------------------------------------------------------
version="$(sed -e 's/#.*//' -e 's/[[:space:]]//g' "${root}/packaging/version" | grep -m1 . || true)"
[ -n "${version}" ] || fail "packaging/version carries no version line"
[[ "${version}" =~ ^[0-9][0-9A-Za-z.+~-]*$ ]] \
	|| fail "packaging/version '${version}' is not a valid Debian version"
grep -qF "version : '${MESON_PROJECT_VERSION}'" "${root}/meson.build" \
	|| fail "meson.build project() version must stay ${MESON_PROJECT_VERSION} — it is what produces ${SONAME}"

# --- No debian/, and upstream's is untouched -----------------------------------
# The upstream debhelper directory is preserved and unused (docs/PROVENANCE.md).
# The contract is that packaging/ never reads it, not that it must be deleted.
[ -d "${root}/debian" ] || fail "upstream debian/ has been deleted; it is retained verbatim and unused"
# Executable lines only. The builder's comments legitimately discuss debian/rules
# and debhelper to explain why neither is used, and a scan that cannot tell a
# comment from a call would forbid saying so.
exec_lines="$(grep -vE '^[[:space:]]*(#|$)' "${builder}")"
if grep -qE '(^|[^A-Za-z0-9_/.-])debian/' <<<"${exec_lines}"; then
	fail "build-deb.sh must not read the upstream debian/ directory"
fi
if grep -qE '\bdh_|debhelper|dpkg-buildpackage' <<<"${exec_lines}"; then
	fail "packaging is hand-rolled; build-deb.sh must not call debhelper"
fi

# --- Control fields, emitted as concrete strings -------------------------------
# dpkg-deb never expands substvars. A ${shlibs:Depends} here would ship to a
# device as literal text in the control field, so the fields are literals and the
# builder asserts its own output.
grep -qF "Package: \${RUNTIME_PKG}" "${builder}" || fail "control must declare Package: ${RUNTIME_PKG}"
grep -qF "Package: \${DEV_PKG}" "${builder}"     || fail "control must declare Package: ${DEV_PKG}"
grep -qF 'readonly RUNTIME_PKG="'"${RUNTIME_PKG}"'"' "${builder}" \
	|| fail "the runtime package name is FROZEN as ${RUNTIME_PKG}"
grep -qF 'readonly DEV_PKG="'"${DEV_PKG}"'"' "${builder}" \
	|| fail "the development package name is FROZEN as ${DEV_PKG}"
grep -qF 'readonly SONAME="'"${SONAME}"'"' "${builder}" \
	|| fail "the SONAME is FROZEN as ${SONAME}"
grep -qF 'readonly REAL_SO="'"${REAL_SO}"'"' "${builder}" \
	|| fail "the real library filename is FROZEN as ${REAL_SO}"
grep -qF 'Architecture: ${arch}' "${builder}" \
	|| fail "control must declare Architecture from the resolved \${arch}"
grep -qF 'Maintainer: CERALIVE <contact@ceralive.tv>' "${builder}" \
	|| fail "control Maintainer must be CERALIVE <contact@ceralive.tv>"
grep -qF "readonly EXPECT_RUNTIME_DEPENDS=\"${EXPECT_RUNTIME_DEPENDS}\"" "${builder}" \
	|| fail "the frozen runtime Depends must be: ${EXPECT_RUNTIME_DEPENDS}"
grep -qF 'Depends: ${EXPECT_RUNTIME_DEPENDS}' "${builder}" \
	|| fail "runtime control Depends must be emitted from the frozen literal"
grep -qF 'Depends: ${RUNTIME_PKG} (= ${version})' "${builder}" \
	|| fail "dev control must depend on ${RUNTIME_PKG} at the EXACT version"
grep -qF 'Provides: ${REPLACED_RUNTIME} (= ${REPLACED_RUNTIME_VERSION})' "${builder}" \
	|| fail "runtime control must Provides: ${REPLACED_RUNTIME} (= ${REPLACED_RUNTIME_VERSION})"
grep -qF 'Conflicts: ${REPLACED_RUNTIME}' "${builder}" || fail "runtime control must Conflicts: ${REPLACED_RUNTIME}"
grep -qF 'Replaces: ${REPLACED_RUNTIME}' "${builder}"  || fail "runtime control must Replaces: ${REPLACED_RUNTIME}"
grep -qF 'Provides: ${REPLACED_DEV}' "${builder}"      || fail "dev control must Provides: ${REPLACED_DEV}"
grep -qF 'Conflicts: ${REPLACED_DEV}' "${builder}"     || fail "dev control must Conflicts: ${REPLACED_DEV}"
grep -qF 'Replaces: ${REPLACED_DEV}' "${builder}"      || fail "dev control must Replaces: ${REPLACED_DEV}"
grep -qF 'readonly REPLACED_RUNTIME_VERSION="'"${REPLACED_RUNTIME_VERSION}"'"' "${builder}" \
	|| fail "the Provides version must be the Radxa upstream version ${REPLACED_RUNTIME_VERSION}"
grep -qF 'Section: libs' "${builder}"     || fail "runtime control must declare Section: libs"
grep -qF 'Section: libdevel' "${builder}" || fail "dev control must declare Section: libdevel"
grep -qF 'Priority: optional' "${builder}" || fail "control must declare Priority: optional"
grep -qF "Homepage: ${SOURCE_URL}" "${builder}" || fail "control Homepage must be ${SOURCE_URL}"
grep -qF 'License: Apache-2.0' "${builder}" || fail "control must declare License: Apache-2.0"
[ "$(grep -cE '^Description: .+' "${builder}")" = "2" ] \
	|| fail "each of the two packages needs its own Description"

# The runtime Provides is VERSIONED so a dependency written against Radxa's
# librga2 keeps resolving; the dev Provides is UNVERSIONED because nothing
# depends on librga-dev at a version and inventing one only creates a constraint
# to get wrong later.
grep -qE '^Provides: \$\{REPLACED_DEV\}$' "${builder}" \
	|| fail "dev Provides must be UNVERSIONED — no (= X) suffix"

# --- Exactly two .deb outputs, named for the two packages ----------------------
# The apt reindex path downloads every .deb in a release tag and hard-fails if a
# package name differs from the dispatched component, so a third artifact is not
# cosmetic — it breaks publication.
grep -qF 'for spec in "${stage_run}:${RUNTIME_PKG}" "${stage_dev}:${DEV_PKG}"' "${builder}" \
	|| fail "build-deb.sh must build exactly the two packages, in one loop over the two stages"
[ "$(grep -cE 'dpkg-deb .*--build' "${builder}")" = "1" ] \
	|| fail "build-deb.sh must invoke dpkg-deb --build from exactly one place"

# --- Reproducible build --------------------------------------------------------
# The epoch is the commit date of the last commit touching a PACKAGED INPUT, so a
# merge commit or a docs-only commit does not move the archive hashes and the
# .deb a board was drilled with stays byte-identical to the published one.
grep -qF 'git -C "${root}" log -1 --format=%ct -- "${PACKAGED_INPUTS[@]}"' "${builder}" \
	|| fail "SOURCE_DATE_EPOCH must be derived from the packaged-input path list"
for input in core im2d_api include meson.build meson_options.txt \
	packaging/version packaging/build-deb.sh packaging/copyright; do
	awk '/^readonly PACKAGED_INPUTS=\(/,/^\)/' "${builder}" | grep -qF "	${input}" \
		|| fail "PACKAGED_INPUTS is missing ${input}"
done
if grep -qE 'SOURCE_DATE_EPOCH=.*(HEAD|rev-parse)' "${builder}"; then
	fail "SOURCE_DATE_EPOCH must NOT come from HEAD — a docs-only commit would move every hash"
fi
grep -qF 'prefix_map="-ffile-prefix-map=${build_dir}=."' "${builder}" \
	|| fail "the build directory must be mapped out of the debug info, or the build-id varies with where the build ran"
grep -qF 'gzip -9n' "${builder}" \
	|| fail "the Debian changelog must be gzipped with -n so the same input gives the same bytes"
grep -qF 'touch --no-dereference --date="@${SOURCE_DATE_EPOCH}"' "${builder}" \
	|| fail "staged timestamps must be normalised to SOURCE_DATE_EPOCH"
grep -qF -- '--root-owner-group' "${builder}" \
	|| fail "dpkg-deb must build with --root-owner-group"

# --- Hardening and the things that must NOT be added ---------------------------
grep -qF 'DEB_BUILD_MAINT_OPTIONS="hardening=+bindnow"' "${builder}" \
	|| fail "full RELRO requires hardening=+bindnow"
grep -qF -- '-D_FORTIFY_SOURCE=3' "${builder}" || fail "FORTIFY level must be raised to 3"
grep -qF 'strip --strip-unneeded' "${builder}" || fail "the shipped library must be stripped"
# .note.gnu.property carries the AArch64 BTI/PAC feature bits. Removing the note
# sections would delete the only evidence that the hardening flags took effect.
! grep -qF -- '--remove-section=.note' "${builder}" \
	|| fail "build-deb.sh must NOT strip .note — BTI/PAC lives in .note.gnu.property"
# The export set is a SUPERSET contract. Both of these narrow it, and both are
# forbidden for that reason, in the builder and in the build files alike.
for forbidden in '-fvisibility=hidden' 'version-script' 'version_script'; do
	! grep -qF -- "${forbidden}" "${builder}" "${root}/meson.build" \
		|| fail "${forbidden} narrows the export set, which is a frozen superset contract"
done
grep -qF -- '-Dlibrga_demo=false' "${builder}" \
	|| fail "the demo must stay off; it drags in the bundled prebuilt libdrm.so"
grep -qF -- '-Dlibdrm=true' "${builder}" \
	|| fail "meson setup must pass -Dlibdrm=true, as upstream debian/rules does"
grep -qF -- '--buildtype=release' "${builder}" || fail "meson setup must use --buildtype=release"
grep -qF -- '--libdir="lib/${triplet}"' "${builder}" \
	|| fail "meson setup must install libraries under lib/\${triplet}"
live_triplet="$(dpkg-architecture -a "${EXPECT_ARCH}" -qDEB_HOST_MULTIARCH 2>/dev/null)"
[ "${live_triplet}" = "${EXPECT_TRIPLET}" ] \
	|| fail "${EXPECT_ARCH} must resolve to ${EXPECT_TRIPLET}, got ${live_triplet}"

# --- Target suite --------------------------------------------------------------
[ -f "${suite_env}" ] || fail "ci/target-suite.env is missing"
# shellcheck source=/dev/null
. "${suite_env}"
[ "${TARGET_SUITE:-}" = "trixie" ] || fail "TARGET_SUITE must be trixie, the suite the device image ships"
[ "${TARGET_ARCH:-}" = "${EXPECT_ARCH}" ] || fail "TARGET_ARCH must be ${EXPECT_ARCH}"
[ "${TARGET_TRIPLET:-}" = "${EXPECT_TRIPLET}" ] || fail "TARGET_TRIPLET must be ${EXPECT_TRIPLET}"
for floor in GLIBC_FLOOR GLIBCXX_FLOOR CXXABI_FLOOR; do
	[ -n "${!floor:-}" ] || fail "ci/target-suite.env must declare ${floor}"
done

# --- Baseline symbol list ------------------------------------------------------
[ -s "${baseline}" ] || fail "packaging/baseline-symbols-radxa-2.2.0-1.txt is missing or empty"
[ -s "${baseline_provenance}" ] \
	|| fail "the baseline needs its .provenance sidecar naming the board binary it came from"
grep -qF '0b455344259c37fec821955e2de85bb5f76a34e69682217b514c407d8a35c6c3' "${baseline_provenance}" \
	|| fail "the baseline provenance must record the sha256 of the board binary it was taken from"
# comm(1) needs both inputs in the same collation, and a comment or blank line in
# this file would sort ahead of every symbol and silently never match.
if grep -qE '^[[:space:]]*(#|$)' "${baseline}"; then
	fail "the baseline must be a bare symbol list — no comments, no blank lines (see its .provenance)"
fi
diff -q <(LC_ALL=C sort -u "${baseline}") "${baseline}" >/dev/null \
	|| fail "the baseline must be LC_ALL=C sorted and unique, or comm reports phantom differences"

[ -f "${upstream_delta}" ] || fail "packaging/baseline-symbols-upstream-delta.txt is missing"
delta_rows="$(grep -vE '^[[:space:]]*(#|$)' "${upstream_delta}" || true)"
if [ -n "${delta_rows}" ]; then
	while IFS= read -r row; do
		[ "$(printf '%s' "${row}" | tr -cd '\t' | wc -c)" -ge 1 ] \
			|| fail "upstream-delta row has no tab-separated reason: ${row}"
		reason="${row#*$'\t'}"
		[ -n "${reason//[[:space:]]/}" ] || fail "upstream-delta row has an empty reason: ${row}"
	done <<<"${delta_rows}"
fi

# --- DEP-5 copyright, checked against the licence census -----------------------
[ -f "${copyright}" ] || fail "packaging/copyright is missing"
grep -qxF "Format: ${DEP5_FORMAT}" "${copyright}" || fail "packaging/copyright must open with Format: ${DEP5_FORMAT}"
grep -qxF "Source: ${SOURCE_URL}" "${copyright}"  || fail "packaging/copyright must declare Source: ${SOURCE_URL}"
stanzas="$(awk 'BEGIN{RS="";FS="\n"} /^Files:/ {n++} END{print n+0}' "${copyright}")"
[ "${stanzas}" -ge 10 ] \
	|| fail "packaging/copyright needs a Files: stanza per holder group and bundled subtree (found ${stanzas})"
incomplete="$(awk 'BEGIN{RS="";FS="\n"}
	/^Files:/ { if ($0 !~ /\nCopyright:/ || $0 !~ /\nLicense:/) n++ }
	END{print n+0}' "${copyright}")"
[ "${incomplete}" = "0" ] || fail "${incomplete} Files: stanza(s) lack a Copyright: or License: field"
for lic in Apache-2.0 MIT GPL-3.0-or-later; do
	awk -v L="License: ${lic}" 'BEGIN{RS="";FS="\n"} $0 ~ "^" L "\n " {found=1} END{exit !found}' "${copyright}" \
		|| fail "packaging/copyright needs a standalone License: ${lic} paragraph carrying the licence text"
done
# The GPL-3.0 Android.mk must have its own stanza and must NOT ride under
# "Files: *": it ships in no package, and absorbing it into the Apache stanza
# would relicense it by omission.
grep -qxF 'Files: Android.mk' "${copyright}" \
	|| fail "Android.mk needs its own stanza; it is GPL-3.0-or-later and ships in no package"
awk 'BEGIN{RS="";FS="\n"} /^Files: Android.mk/ {print}' "${copyright}" | grep -qF 'License: GPL-3.0-or-later' \
	|| fail "the Android.mk stanza must record its GPL-3.0-or-later licence"

# Every path the census treats as bundled or non-Rockchip-held must be matched by
# a Files: pattern that is not the catch-all. Derived from the tree, so a new
# vendored subtree or a new copyright holder cannot reach a release unattributed.
mapfile -t files_patterns < <(
	awk '/^Files:/ { sub(/^Files:[[:space:]]*/, ""); print; inblock=1; next }
	     inblock && /^[[:space:]]+[^[:space:]]/ && !/^[[:space:]]*(Copyright|License|Comment):/ { sub(/^[[:space:]]+/, ""); print; next }
	     { inblock=0 }' "${copyright}" | tr -s ' ' '\n' | grep -v '^\*$' | grep -v '^$'
)
[ "${#files_patterns[@]}" -ge 10 ] || fail "could not parse the Files: patterns out of packaging/copyright"

covered() {
	local path="$1" pat
	for pat in "${files_patterns[@]}"; do
		# shellcheck disable=SC2254
		case "${path}" in ${pat}) return 0 ;; esac
	done
	return 1
}

uncovered=""
while IFS= read -r path; do
	[ -n "${path}" ] || continue
	covered "${path}" || uncovered+="${path}"$'\n'
done < <(
	cd "${root}" || exit 1
	git ls-files | grep '3rdparty/'
	# Every tracked file carrying a copyright line for someone other than
	# Rockchip. Derived rather than listed, so a new holder appearing anywhere in
	# the tree needs a stanza before the package can be built.
	git ls-files -z | xargs -0 grep -lIiE '^[[:space:]*#/]*Copyright' 2>/dev/null \
		| while IFS= read -r f; do
			if grep -ioIE '^[[:space:]*#/]*Copyright.*' "${f}" \
				| grep -viE "${ROCKCHIP_HOLDERS_RE}" | grep -qiE '[a-z]'; then
				printf '%s\n' "${f}"
			fi
		done
	# The GPL-3.0-or-later outlier, named explicitly: its holder string contains
	# "Rockchip", so the holder scan above would not surface it.
	printf 'Android.mk\n'
)
[ -z "${uncovered}" ] \
	|| fail "the licence census lists paths with no specific Files: stanza:"$'\n'"${uncovered}"

if [ "$#" -eq 0 ]; then
	note "OK static (${RUNTIME_PKG} + ${DEV_PKG} ${version} · SONAME ${SONAME} · api $(rendered_api_version))"
	exit 0
fi

# --- Reproducibility mode ------------------------------------------------------
if [ "$1" = "--repro" ]; then
	tmp="$(mktemp -d)"
	trap 'rm -rf "${tmp}"' EXIT
	# Both runs use the SAME build directory, because that is what a rebuild is.
	# Reproducibility here is the Debian sense — identical bytes for a given build
	# path — and build-deb.sh wipes its working directories on entry, so the
	# second run genuinely rebuilds rather than reusing objects. Varying the build
	# path between the two runs would test something else: meson passes source
	# paths RELATIVE to the build directory, and those relative strings reach the
	# debug info and therefore .note.gnu.build-id. See docs/BUILD-FLAGS.md.
	for run in 1 2; do
		BUILD_DIR="${tmp}/build" INSTALL_DIR="${tmp}/install" \
		STAGE_RUN_DIR="${tmp}/stage/${RUNTIME_PKG}" \
		STAGE_DEV_DIR="${tmp}/stage/${DEV_PKG}" \
		OUT_DIR="${tmp}/dist-${run}" \
			bash "${builder}" >/dev/null
		(cd "${tmp}/dist-${run}" && sha256sum ./*.deb | sed 's#\./##') | LC_ALL=C sort >"${tmp}/sums-${run}"
	done
	if ! diff -u "${tmp}/sums-1" "${tmp}/sums-2"; then
		fail "two builds with the same SOURCE_DATE_EPOCH produced different archives"
	fi
	note "OK reproducible — two builds, identical sha256:"
	sed 's/^/  /' "${tmp}/sums-1"
	exit 0
fi

# --- Staged trees --------------------------------------------------------------
[ "$#" -ge 2 ] || fail "staged mode needs the runtime stage and the dev stage"
stage_run="$1"
stage_dev="$2"
out="${3:-${root}/dist}"
[ -d "${stage_run}" ] || fail "runtime stage ${stage_run} does not exist"
[ -d "${stage_dev}" ] || fail "dev stage ${stage_dev} does not exist"

libdir_rel="usr/lib/${EXPECT_TRIPLET}"
staged_so="${stage_run}/${libdir_rel}/${REAL_SO}"
[ -f "${staged_so}" ] || fail "runtime stage is missing ${libdir_rel}/${REAL_SO}"
[ -L "${stage_run}/${libdir_rel}/${SONAME}" ] || fail "runtime stage is missing the ${SONAME} symlink"
[ -L "${stage_dev}/${libdir_rel}/librga.so" ] || fail "dev stage is missing the librga.so link-time symlink"
[ -f "${stage_dev}/${libdir_rel}/pkgconfig/librga.pc" ] || fail "dev stage is missing librga.pc"
grep -qE "^Version: ${MESON_PROJECT_VERSION}$" "${stage_dev}/${libdir_rel}/pkgconfig/librga.pc" \
	|| fail "librga.pc must carry Version: ${MESON_PROJECT_VERSION}"
[ -d "${stage_dev}/usr/include/rga" ] || fail "dev stage is missing /usr/include/rga"
[ "$(find "${stage_dev}/usr/include/rga" -name '*.h' | wc -l)" -ge 15 ] \
	|| fail "dev stage ships too few headers to be the development package"

# The split is the contract: development artifacts in the runtime package would
# be shipped to every device, and a runtime object in the dev package would break
# the exact-version dependency between them.
leaked="$(find "${stage_run}" -type f \( -name '*.h' -o -name '*.pc' -o -name '*.a' -o -name '*.la' \) -print)"
[ -z "${leaked}" ] || fail "development artifacts leaked into the runtime package:"$'\n'"${leaked}"
[ ! -e "${stage_run}/usr/include" ] || fail "headers leaked into the runtime package"
[ ! -e "${stage_dev}/${libdir_rel}/${REAL_SO}" ] || fail "the real shared object leaked into the dev package"
# Neither package ships a static archive: Radxa's librga-dev does not, and a
# static librga would let a consumer bake this code in and bypass the shared
# object this fork exists to control.
for stage in "${stage_run}" "${stage_dev}"; do
	[ -z "$(find "${stage}" -name '*.a' -print -quit)" ] || fail "a static archive is staged in ${stage}"
done

command -v objdump >/dev/null || fail "objdump is required for the staged checks (install binutils)"
command -v readelf >/dev/null || fail "readelf is required for the staged checks (install binutils)"
command -v nm >/dev/null      || fail "nm is required for the staged export check (install binutils)"

soname="$(objdump -p "${staged_so}" | awk '/SONAME/{print $2}')"
[ "${soname}" = "${SONAME}" ] || fail "SONAME is FROZEN at ${SONAME}, staged library reports ${soname}"

# --- Hardening, read off the produced binary -----------------------------------
readelf -d "${staged_so}" | grep -q 'BIND_NOW\|FLAGS_1.*NOW' \
	|| fail "the staged library is not full RELRO (no BIND_NOW)"
readelf -n "${staged_so}" | grep -q 'BTI' \
	|| fail "the staged library carries no AArch64 BTI property; -mbranch-protection was lost"
readelf -n "${staged_so}" | grep -q 'PAC' \
	|| fail "the staged library carries no AArch64 PAC property; -mbranch-protection was lost"
nm -D --undefined-only "${staged_so}" | grep -q '__stack_chk_fail' \
	|| fail "no stack-protector reference in the staged library; -fstack-protector-strong was lost"
[ "$(readelf -h "${staged_so}" | awk '/Type:/{print $2}')" = "DYN" ] \
	|| fail "the staged library is not position-independent"
! readelf -S "${staged_so}" | grep -q '\.debug_info' \
	|| fail "the staged library still carries DWARF; strip --strip-unneeded did not run"

# --- Symbol containment --------------------------------------------------------
# The export set is a floor, not a fingerprint: a CeraLive build must never export
# FEWER symbols than the Radxa build the device already runs. Additions are
# expected — the Meson build exports internals Radxa's did not.
command -v c++filt >/dev/null || fail "c++filt is required for the export check (install binutils)"
built_syms="$(mktemp)"; missing="$(mktemp)"
trap 'rm -f "${built_syms}" "${missing}"' EXIT
nm -D --defined-only "${staged_so}" | awk '{print $3}' | LC_ALL=C sort -u >"${built_syms}"
LC_ALL=C comm -23 "${baseline}" "${built_syms}" >"${missing}"

# Tier 1, unconditional: nothing reachable from an installed header may vanish.
# That is the set a consumer can actually reference, so its loss is an ABI break
# on any API release, whatever upstream did to the internals.
hdr_ids="$(mktemp)"; trap 'rm -f "${built_syms}" "${missing}" "${hdr_ids}"' EXIT
cat "${stage_dev}"/usr/include/rga/*.h \
	| grep -ohE '\b[A-Za-z_][A-Za-z0-9_]*\b' | LC_ALL=C sort -u >"${hdr_ids}"
api_missing=""
while IFS= read -r sym; do
	[ -n "${sym}" ] || continue
	case "${sym}" in
		# std:: template instantiations are libstdc++'s, emitted per translation
		# unit by whichever compiler built the object. Never this library's ABI.
		_ZNSt*|_ZSt*|_ZNKSt*|_ZNVSt*) continue ;;
		_Z*) base="$(printf '%s' "${sym}" | c++filt | sed -E 's/\(.*$//; s/<.*$//; s/.*:://')" ;;
		*)   base="${sym}" ;;
	esac
	if grep -qxF "${base}" "${hdr_ids}"; then
		api_missing+="${sym}"$'\n'
	fi
done <"${missing}"
[ -z "${api_missing}" ] \
	|| fail "the build DROPPED exports that installed headers declare:"$'\n'"${api_missing}"

# Tier 2: the full floor. It applies as a strict superset test only when the tree
# renders the API release the baseline was captured from — comparing a different
# upstream API release against it is a category error, not a regression. On any
# other release the delta must equal the recorded, reasoned upstream delta, so a
# CeraLive-caused removal still fails the build.
api_now="$(rendered_api_version)"
if [ "${api_now}" = "${BASELINE_API_RELEASE}" ]; then
	[ ! -s "${missing}" ] \
		|| fail "api ${api_now} matches the baseline, so the export floor is strict; missing:"$'\n'"$(cat "${missing}")"
	note "export floor: strict superset of the Radxa ${BASELINE_API_RELEASE} baseline — 0 missing"
else
	expected_delta="$(grep -vE '^[[:space:]]*(#|$)' "${upstream_delta}" | cut -f1 | LC_ALL=C sort -u)"
	if ! diff -u <(printf '%s\n' "${expected_delta}") <(LC_ALL=C sort -u "${missing}") >/dev/null; then
		printf 'package-contract: recorded upstream delta vs measured:\n' >&2
		diff -u <(printf '%s\n' "${expected_delta}") <(LC_ALL=C sort -u "${missing}") >&2 || true
		fail "the export delta against the ${BASELINE_API_RELEASE} baseline is not the one recorded in packaging/baseline-symbols-upstream-delta.txt"
	fi
	note "export floor: api ${api_now} != baseline ${BASELINE_API_RELEASE}; delta matches the recorded upstream delta ($(printf '%s\n' "${expected_delta}" | grep -c .) symbols)"
fi

# --- Dependency closure, from the staged binary --------------------------------
while IFS= read -r needed; do
	[ -n "${needed}" ] || continue
	case "${needed}" in
		libc.so.6|libm.so.6|ld-linux-aarch64.so.1) pkg="libc6" ;;
		libgcc_s.so.1) pkg="libgcc-s1" ;;
		libstdc++.so.6) pkg="libstdc++6" ;;
		*) fail "the staged library links ${needed}, which no declared dependency supplies" ;;
	esac
	case ", ${EXPECT_RUNTIME_DEPENDS}," in
		*", ${pkg},"*|*", ${pkg} ("*) ;;
		*) fail "Depends omits ${pkg}, which supplies the linked ${needed}" ;;
	esac
done < <(objdump -p "${staged_so}" | awk '/NEEDED/{print $2}' | LC_ALL=C sort -u)

# --- Staged control ------------------------------------------------------------
check_control() {
	local control="$1" pkg="$2"
	[ -f "${control}" ] || fail "staged DEBIAN/control is missing for ${pkg}"
	grep -qxF "Package: ${pkg}" "${control}" || fail "staged control Package is not ${pkg}"
	grep -qxF "Version: ${version}" "${control}" || fail "staged ${pkg} Version is not ${version}"
	grep -qxF "Architecture: ${EXPECT_ARCH}" "${control}" || fail "staged ${pkg} Architecture must be ${EXPECT_ARCH}"
	! grep -q '\${' "${control}" || fail "staged ${pkg} control carries an unexpanded substvar"
	local doc="${control%/DEBIAN/control}/usr/share/doc/${pkg}"
	for f in copyright COPYING changelog.Debian.gz; do
		[ -f "${doc}/${f}" ] || fail "${pkg} is missing /usr/share/doc/${pkg}/${f}"
	done
	gzip -t "${doc}/changelog.Debian.gz" || fail "${pkg} changelog.Debian.gz is not valid gzip"
}
check_control "${stage_run}/DEBIAN/control" "${RUNTIME_PKG}"
check_control "${stage_dev}/DEBIAN/control" "${DEV_PKG}"
grep -qxF "Depends: ${EXPECT_RUNTIME_DEPENDS}" "${stage_run}/DEBIAN/control" \
	|| fail "staged runtime Depends is not the frozen literal"
grep -qxF "Provides: ${REPLACED_RUNTIME} (= ${REPLACED_RUNTIME_VERSION})" "${stage_run}/DEBIAN/control" \
	|| fail "staged runtime Provides is wrong"
grep -qxF "Conflicts: ${REPLACED_RUNTIME}" "${stage_run}/DEBIAN/control" || fail "staged runtime Conflicts is wrong"
grep -qxF "Replaces: ${REPLACED_RUNTIME}" "${stage_run}/DEBIAN/control" || fail "staged runtime Replaces is wrong"
grep -qxF "Depends: ${RUNTIME_PKG} (= ${version})" "${stage_dev}/DEBIAN/control" \
	|| fail "staged dev Depends must pin ${RUNTIME_PKG} at the exact version"
grep -qxF "Provides: ${REPLACED_DEV}" "${stage_dev}/DEBIAN/control" || fail "staged dev Provides is wrong"

# --- The output directory ------------------------------------------------------
if [ -d "${out}" ]; then
	mapfile -t debs < <(find "${out}" -maxdepth 1 -name '*.deb' | LC_ALL=C sort)
	[ "${#debs[@]}" = "2" ] \
		|| fail "the release publishes EXACTLY TWO .debs, ${out} holds ${#debs[@]}"
	for pkg in "${RUNTIME_PKG}" "${DEV_PKG}"; do
		[ -f "${out}/${pkg}_${version}_${EXPECT_ARCH}.deb" ] \
			|| fail "missing ${pkg}_${version}_${EXPECT_ARCH}.deb in ${out}"
	done
fi

note "OK static + staged (${RUNTIME_PKG} + ${DEV_PKG} ${version} · ${SONAME} · api ${api_now})"
