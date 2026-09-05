#!/usr/bin/env bash
# Modified by CeraLive 2026-09-05: assemble the coordinator-owned test registration.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
shopt -s nullglob
fragments=(uapi-parity goldens unit board)
files=(tests/meson-fragments/*.build)
[[ ${#files[@]} -eq ${#fragments[@]} ]] || { printf 'Update the fragment dependency order first\n' >&2; exit 1; }
for name in "${fragments[@]}"; do test -f "tests/meson-fragments/$name.build"; done
tmp=$(mktemp)
trap 'rm -f "$tmp"' EXIT
awk '
  /^# --- test fragments \(wired by coordinator\) ---$/ { exit }
  /^librga_so = librga$/ { next }
  /^librga = static_library\(/ { print "librga_so = librga" }
  { print }
' meson.build > "$tmp"
printf '# --- test fragments (wired by coordinator) ---\n' >> "$tmp"
for name in "${fragments[@]}"; do
  printf '# >>> fragment: %s.build\n' "$name" >> "$tmp"
  cat "tests/meson-fragments/$name.build" >> "$tmp"
done
if ! cmp -s "$tmp" meson.build; then cat "$tmp" > meson.build; fi

# Keep the schema from todo 8; only the rows are generated from fix fragments.
awk '{ print } /^\|---\|---\|---\|---\|---\|---\|$/ { exit }' docs/fix-audit.md > "$tmp"
rows=(docs/fix-audit.d/*.md)
for row in "${rows[@]}"; do cat "$row" >> "$tmp"; done
if ! cmp -s "$tmp" docs/fix-audit.md; then cat "$tmp" > docs/fix-audit.md; fi
