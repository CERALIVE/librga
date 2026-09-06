#!/usr/bin/env bash
# Modified by CeraLive 2026-09-05: assemble the coordinator-owned test registration.
# Modified by CeraLive 2026-09-06: separate D21 ledger rows from verbatim appendices.
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

# Keep the D21 definitions; rebuild everything after the first ledger header.
header="| Provenance SHA | Reproducer (path · RED · GREEN) | Hardware gate | ABI closure (nm vs R0 · abidiff vs previous release) | Independent reviewer verdict · reviewer session id | \`Upstream-status\` |"
separator='|---|---|---|---|---|---|'
awk -v header="$header" -v separator="$separator" '
  $0 == "The table below is **empty on purpose**: no fix has landed yet. Rows are appended" {
    print "The table below holds characterization rows for findings on the unmodified"
    print "upstream base: **no fix has landed yet**, and no library source has been changed."
    print "Rows and verbatim supporting evidence are assembled from the investigation"
    print "fragments by `scripts/wire-bootstrap.sh`; supporting prose follows in appendices."
    next
  }
  $0 == "by the fix todos, each writing its own fragment, and the coordinator wires them in." { next }
  $0 == header { print header; print separator; found = 1; exit }
  { print }
  END { if (!found) { print "Missing D21 ledger header" > "/dev/stderr"; exit 1 } }
' docs/fix-audit.md > "$tmp"
export LC_ALL=C
rows=(docs/fix-audit.d/*.md)
if [[ ${#rows[@]} -gt 0 ]]; then
  awk -v header="$header" -v separator="$separator" '
    function keep() { prose[FILENAME] = prose[FILENAME] $0 "\n" }
    FNR == 1 {
      names[++count] = FILENAME
      leading = 1; ledger = 0; fence = ""; comment = 0
    }
    comment {
      keep()
      if (index($0, "-->")) comment = 0
      next
    }
    match($0, /^ *(```+|~~~+)/) {
      marker = substr($0, RSTART, RLENGTH)
      sub(/^ */, "", marker)
      if (!fence) fence = marker
      else if (substr(marker, 1, 1) == substr(fence, 1, 1) && length(marker) >= length(fence)) fence = ""
      leading = 0; ledger = 0; keep(); next
    }
    fence { keep(); next }
    index($0, "<!--") {
      comment = !index(substr($0, index($0, "<!--") + 4), "-->")
      leading = 0; ledger = 0; keep(); next
    }
    $0 == header { leading = 0; ledger = 1; next }
    (leading || ledger) && $0 == separator { next }
    (leading || ledger) && /^\|/ {
      row = $0
      gsub(/\\\|/, "", row)
      fields = split(row, cells, /\|/)
      valid = fields == 8 && cells[1] == "" && cells[8] ~ /^[[:space:]]*$/
      for (i = 2; i < 8; i++) if (cells[i] !~ /[^[:space:]]/) valid = 0
      if (!valid) {
        print FILENAME ":" FNR ": expected six nonempty D21 fields" > "/dev/stderr"
        exit 1
      }
      print
      leading = 0; ledger = 1; next
    }
    {
      if ($0 ~ /[^[:space:]]/) leading = 0
      ledger = 0
      keep()
    }
    END {
      for (i = 1; i <= count; i++) {
        name = names[i]
        if (prose[name] !~ /[^[:space:]]/) continue
        sub(/^.*\//, "", name)
        printf "\n## Appendix — %s\n\n", name
        printf "Source: [fix-audit.d/%s](fix-audit.d/%s). D21 rows are in the [ledger above](#rows).\n\n", name, name
        printf "%s", prose[names[i]]
      }
    }
  ' "${rows[@]}" >> "$tmp"
fi
if ! cmp -s "$tmp" docs/fix-audit.md; then cat "$tmp" > docs/fix-audit.md; fi
