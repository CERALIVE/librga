#!/usr/bin/env bash
# license-census.sh — file-level licence census for every tracked file in this repository.
#
# WHY: this tree is Apache-2.0 at the root (COPYING) but it BUNDLES third-party
# subtrees that are not Apache-2.0, and it carries one build file whose header
# contradicts COPYING outright. A repository-level "it's Apache-2.0" claim is
# therefore false at file granularity, and packaging/copyright (DEP-5) has to be
# generated from the truth rather than from the root licence. This script is that
# truth, and it FAILS CLOSED: any tracked file it cannot classify is reported as
# UNKNOWN and the script exits non-zero.
#
# The gate that matters: a file under a `3rdparty/` path is NEVER classified by a
# generic content scan. It must match an explicit rule below, naming its licence
# and its copyright holders. A new bundled file with no rule is UNKNOWN by
# construction, which is the whole point — bundled code must be classified by a
# human before it can ship.
#
# Usage:
#   bash scripts/license-census.sh              # human report; exit 1 if any UNKNOWN
#   bash scripts/license-census.sh --paths      # also list every first-party path
#   bash scripts/license-census.sh --self-test  # prove the UNKNOWN gate actually fires
#
# Requires: git, grep. Must be run from inside a checkout of this repository.

set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

SHOW_ALL_PATHS=0
SELF_TEST=0
for arg in "$@"; do
  case "$arg" in
    --paths) SHOW_ALL_PATHS=1 ;;
    --self-test) SELF_TEST=1 ;;
    -h|--help) sed -n '2,25p' "$0"; exit 0 ;;
    *) echo "unknown argument: $arg" >&2; exit 2 ;;
  esac
done

# --- classification ---------------------------------------------------------
#
# Each rule returns "<licence>|<holders>|<evidence>". Precedence is strict and
# top-to-bottom; the first rule that matches wins.
#
#   0. this script and its output doc (neither can be content-scanned)
#   1. an in-file SPDX licence identifier (authoritative wherever present)
#   2. an explicit bundled-subtree rule, keyed on path
#   3. FAIL CLOSED for any other `3rdparty/` path
#   4. the licence text itself, plus a file whose header contradicts COPYING
#   5. an in-file licence-grant scan
#   6. imported-at-the-fork-point default: Apache-2.0 via COPYING, Rockchip
#   7. added-after-the-fork-point default: Apache-2.0 via COPYING, CeraLive
#   8. UNKNOWN

MIT_X11='MIT/X11-style'
APACHE='Apache-2.0'
IMPORT_COMMIT='57a1067a246c71fa6c9a355d1668884fda155dd5'

classify() {
  f="$1"

  # 0. A licence scanner, and the census it feeds, necessarily quote every licence
  # string they search for, so scanning either by content reports it under
  # whichever pattern happens to be tested first. Both are classified by rule.
  case "$f" in
    scripts/license-census.sh|docs/PROVENANCE.md)
      echo "$APACHE (CeraLive fork addition)|CeraLive contributors|CeraLive licence-census output or tool, classified by rule rather than by content scan"
      return ;;
  esac

  # 1. SPDX wins wherever it exists.
  spdx="$(grep -m1 -oIE 'SPDX-License-Identifier:[[:space:]]*[^*"/]+' "$f" 2>/dev/null || true)"
  if [ -n "$spdx" ]; then
    id="${spdx#*:}"
    # shellcheck disable=SC2001
    id="$(echo "$id" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"
    echo "$id|see file header|in-file $SPDX_TAG"
    return
  fi

  # 2. bundled third-party subtrees, classified by hand.
  case "$f" in
    core/3rdparty/libdrm/include/drm/drm.h|samples/utils/3rdparty/libdrm/include/libdrm/drm.h)
      echo "$MIT_X11|Precision Insight, Inc.; VA Linux Systems, Inc.|in-file 'Permission is hereby granted' grant"
      return ;;
    core/3rdparty/libdrm/include/drm/drm_fourcc.h|samples/utils/3rdparty/libdrm/include/libdrm/drm_fourcc.h)
      echo "$MIT_X11|Intel Corporation|in-file 'Permission is hereby granted' grant"
      return ;;
    core/3rdparty/libdrm/include/drm/drm_mode.h|samples/utils/3rdparty/libdrm/include/libdrm/drm_mode.h)
      echo "$MIT_X11|Dave Airlie; Jakob Bornecrantz; Red Hat Inc.; Tungsten Graphics, Inc.; Intel Corporation|in-file 'Permission is hereby granted' grant"
      return ;;
    samples/utils/3rdparty/libdrm/include/xf86drm.h)
      echo "$MIT_X11|Precision Insight, Inc.; VA Linux Systems, Inc.|in-file 'Permission is hereby granted' grant"
      return ;;
    samples/utils/3rdparty/libdrm/lib/*/libdrm.so)
      echo "$MIT_X11 (PREBUILT BINARY, no source in tree)|freedesktop.org libdrm contributors|upstream libdrm licence; ELF SONAME libdrm.so.2, sample-only build input, never packaged"
      return ;;
    core/3rdparty/android_hal/system/graphics.h)
      echo "$APACHE|The Android Open Source Project|in-file 'Licensed under the Apache License, Version 2.0'"
      return ;;
    core/3rdparty/android_hal/system/graphics-sw.h|core/3rdparty/android_hal/system/graphics-base.h)
      echo "$APACHE|The Android Open Source Project|AOSP system/core header carried without its notice; licence inherited from AOSP system/core"
      return ;;
    core/3rdparty/android_hal/system/graphics-base-v1.[012].h)
      echo "$APACHE|The Android Open Source Project|hidl-gen output from android.hardware.graphics.common; licence inherited from AOSP"
      return ;;
    core/3rdparty/android_hal/hardware/hardware_rockchip.h)
      echo "$APACHE|Rockchip Electronics Co., Ltd.|Rockchip addition to the AOSP libhardware include set; repository COPYING applies"
      return ;;
    samples/utils/3rdparty/CMakeLists.txt|samples/utils/3rdparty/3rdparty.mk)
      echo "$APACHE|Rockchip Electronics Co., Ltd.|first-party build glue that lives inside the 3rdparty directory; repository COPYING applies"
      return ;;
  esac

  # 3. FAIL CLOSED: bundled content with no rule is never guessed at.
  case "$f" in
    *3rdparty/*)
      echo "UNKNOWN|unclassified|bundled third-party path with no rule in scripts/license-census.sh"
      return ;;
  esac

  # 4. the licence text itself, and the one file whose header contradicts COPYING.
  case "$f" in
    COPYING)
      echo "$APACHE|Apache Software Foundation (licence text)|the repository licence file itself, retained verbatim"
      return ;;
    Android.mk)
      echo "GPL-3.0-or-later (CONFLICTS WITH COPYING)|Fuzhou Rockchip Electronics Co., Ltd. (Putin Li, Bin Li)|in-file 'GNU General Public License ... version 3 or later' header; Android-only build file, not built or packaged by the Meson/Linux path"
      return ;;
  esac

  # 5. in-file licence grant.
  if grep -qI 'Permission is hereby granted' "$f" 2>/dev/null; then
    holders="$(grep -ioIE '^[[:space:]*#]*Copyright[^\\]*' "$f" 2>/dev/null | sed 's/^[[:space:]*#]*//; s/[[:space:]]*$//' | paste -sd'; ' - || true)"
    echo "$MIT_X11|${holders:-see file header}|in-file 'Permission is hereby granted' grant"
    return
  fi
  if grep -qI 'Apache License' "$f" 2>/dev/null; then
    holders="$(grep -oIE '^[[:space:]*#]*Copyright[^\\]*' "$f" 2>/dev/null | sed 's/^[[:space:]*#]*//; s/[[:space:]]*$//' | paste -sd'; ' - || true)"
    echo "$APACHE|${holders:-Rockchip Electronics Co., Ltd.}|in-file 'Apache License' grant"
    return
  fi
  if grep -qIE 'GNU (General|Lesser|Library) Public License' "$f" 2>/dev/null; then
    echo "UNKNOWN|unclassified|in-file GNU licence grant with no rule in scripts/license-census.sh"
    return
  fi

  # 6/7. no in-file grant: split by whether the file predates the fork point, so a
  # CeraLive addition is never attributed to Rockchip and needs no rule of its own.
  if git cat-file -e "$IMPORT_COMMIT:$f" 2>/dev/null; then
    echo "$APACHE (repository default via COPYING)|Rockchip Electronics Co., Ltd.|no in-file grant; imported at $IMPORT_COMMIT and covered by the repository COPYING"
  else
    echo "$APACHE (CeraLive fork addition)|CeraLive contributors|no in-file grant; added after the fork point $IMPORT_COMMIT, licensed under the repository COPYING"
  fi
}

# --- self-test --------------------------------------------------------------
if [ "$SELF_TEST" = 1 ]; then
  probe='core/3rdparty/libdrm/include/drm/__census_self_test__.h'
  got="$(classify "$probe")"
  case "$got" in
    UNKNOWN\|*) echo "self-test PASS: an unruled 3rdparty path classifies as UNKNOWN" ;;
    *) echo "self-test FAIL: expected UNKNOWN for $probe, got: $got" >&2; exit 1 ;;
  esac
  probe2='Android.mk'
  got2="$(classify "$probe2")"
  case "$got2" in
    GPL-3.0-or-later*) echo "self-test PASS: Android.mk is reported as a COPYING conflict" ;;
    *) echo "self-test FAIL: expected the GPL conflict row for $probe2, got: $got2" >&2; exit 1 ;;
  esac
  exit 0
fi

# --- census -----------------------------------------------------------------
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

total=0
while IFS= read -r f; do
  total=$((total + 1))
  printf '%s\t%s\n' "$(classify "$f")" "$f" >> "$tmp/rows"
done < <(git ls-files)

echo "librga file-level licence census"
echo "================================"
echo "tracked files scanned: $total"
echo "repository root licence file: COPYING (Apache License, Version 2.0)"
echo

unknown=0
while IFS= read -r lic; do
  count="$(awk -F'|' -v L="$lic" '$1 == L' "$tmp/rows" | wc -l | tr -d ' ')"
  echo "[$lic]  files: $count"
  awk -F'|' -v L="$lic" '$1 == L {print $2}' "$tmp/rows" | sort -u | while IFS= read -r h; do
    echo "    holders: $h"
  done
  awk -F'|' -v L="$lic" '$1 == L {split($3, a, "\t"); print a[1]}' "$tmp/rows" | sort -u | while IFS= read -r e; do
    echo "    evidence: $e"
  done
  case "$lic" in
    "$APACHE (repository default via COPYING)")
      if [ "$SHOW_ALL_PATHS" = 1 ]; then
        awk -F'\t' -v L="$lic" 'index($1, L "|") == 1 {print "    path: " $2}' "$tmp/rows" | sort
      else
        echo "    paths: first-party Rockchip sources, build files, docs and sample assets."
        echo "           Directory breakdown (re-run with --paths for the full list):"
        awk -F'\t' -v L="$lic" 'index($1, L "|") == 1 {print $2}' "$tmp/rows" \
          | sed 's#/[^/]*$##; s#^[^/]*$#<repo-root>#' | sort | uniq -c | sort -rn \
          | awk '{printf "             %5d  %s\n", $1, $2}'
      fi
      ;;
    *)
      awk -F'\t' -v L="$lic" 'index($1, L "|") == 1 {print "    path: " $2}' "$tmp/rows" | sort
      ;;
  esac
  echo
  case "$lic" in UNKNOWN) unknown=1 ;; esac
done < <(cut -f1 "$tmp/rows" | cut -d'|' -f1 | sort -u)

unknown_count="$(awk -F'|' '$1 == "UNKNOWN"' "$tmp/rows" | wc -l | tr -d ' ')"
echo "UNKNOWN rows: $unknown_count"

if [ "$unknown_count" -ne 0 ] || [ "$unknown" -ne 0 ]; then
  echo "FAIL: every tracked file must be classified before it can be packaged." >&2
  exit 1
fi

echo "PASS: every tracked file is classified."
