#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# Run GCC's static analyzer over the shipped library sources.
#
#   bash scripts/run-analyzer.sh
#
# Writes the raw compiler output to test-results/analyzer.txt and the normalised
# hit list to test-results/analyzer-hits.txt, then reconciles every hit against
# the dispositions in docs/ANALYZER-TRIAGE.md.
#
# WHY THIS NEEDS -Danalyzer=true
#
# meson.build compiles the library with a blanket `-w`. GCC's `-w` sets a global
# inhibit flag that is checked when a diagnostic is EMITTED, not when the option
# is parsed, so it silences every -Wanalyzer-* finding no matter where
# `-fanalyzer` sits on the command line. `-Danalyzer=true` drops that one flag
# for the library targets and nothing else; the option defaults to false, so no
# other build in this repository changes.
#
# WHY C++ ONLY
#
# `-fanalyzer` is applied through `-Dcpp_args`, which reaches the library sources
# — the code that ships. The C sources in this tree are the test shim and the
# board harness; they build with `-Werror`, so feeding them analyzer diagnostics
# would turn a finding about non-shipped test scaffolding into a build failure.
#
# EXIT STATUS
#
# Advisory by default: a compile failure fails, untriaged hits only warn. Set
# ANALYZER_STRICT=1 to fail on an untriaged hit — that is how this becomes a gate
# once the backlog it surfaces is at zero.
set -euo pipefail

root=$(realpath "$(dirname "${BASH_SOURCE[0]}")/..")
cd "$root"

for tool in meson ninja g++ python3; do
	command -v "$tool" >/dev/null || { printf 'missing tool: %s\n' "$tool" >&2; exit 77; }
done

build='build-analyzer'
out='test-results/analyzer.txt'
hits='test-results/analyzer-hits.txt'
triage='docs/ANALYZER-TRIAGE.md'

mkdir -p test-results

# ccache replays a cached stderr, which is correct but makes a re-run look like
# it re-analysed when it did not. The analyzer is slow enough that the honesty is
# worth more than the cache.
export CCACHE_DISABLE=1

# `-fdiagnostics-plain-output` and `b_colorout=never` keep test-results/analyzer.txt
# diffable: no ANSI escapes, no caret art, one diagnostic per line.
setup=(setup "$build" "$root"
	-Danalyzer=true
	-Dlibrga_demo=false
	-Dwarning_level=0
	-Db_colorout=never
	-Dcpp_args='-fanalyzer -fpermissive -fdiagnostics-plain-output')

if [[ -f $build/meson-private/coredata.dat ]]; then
	meson "${setup[@]}" --wipe >/dev/null
else
	meson "${setup[@]}" >/dev/null
fi

{
	printf '# GCC -fanalyzer over the librga library sources\n'
	printf '# compiler : %s\n' "$(g++ --version | sed -n 1p)"
	printf '# arch     : %s\n' "$(uname -m)"
	printf '# tree     : %s\n' "$(git -C "$root" rev-parse --short HEAD 2>/dev/null || printf 'unknown')"
	printf '# date     : %s\n' "$(date -u +%FT%TZ)"
	printf '#\n'
	printf '# On a non-aarch64 host the `#else` half of the __aarch64__ guards in\n'
	printf '# im2d_impl.cpp/NormalRga.cpp is what gets analysed. Findings inside those\n'
	printf '# blocks are host-only and are triaged as such.\n#\n'
} >"$out"

# ONE target: the shipped shared library. Building everything would also feed
# `-fanalyzer` to the C++ test sources, which compile with `-Werror` — an
# analyzer finding in non-shipped test scaffolding would then abort the run
# instead of being reported. `-k0` keeps the remaining sources analysed when one
# of them stops.
rc=0
meson compile -C "$build" --ninja-args=-k0 rga:shared_library >>"$out" 2>&1 || rc=$?

grep -oE '^[^ ]+:[0-9]+:[0-9]+: warning: .*\[-Wanalyzer-[a-z-]+\]' "$out" \
	| sed -E 's#^(\.\./)+##' \
	| LC_ALL=C sort -u >"$hits" || true

total=$(wc -l <"$hits")
printf '\nrun-analyzer: %s unique -Wanalyzer-* hits (compile exit %s)\n' "$total" "$rc"
printf 'run-analyzer: raw output %s\n' "$out"
printf 'run-analyzer: hit list   %s\n' "$hits"

[[ -r $triage ]] || { printf 'run-analyzer: FAIL: %s is missing\n' "$triage" >&2; exit 1; }

# Reconcile by (source file, warning name). Deliberately NOT by line number:
# a line moves with every edit above it, and a triage list that goes stale on
# unrelated churn gets rubber-stamped instead of read.
status=0
python3 - "$hits" "$triage" <<'PY' || status=$?
import re, sys
hits_path, triage_path = sys.argv[1], sys.argv[2]
hit_re = re.compile(r'^(?P<file>[^:]+):\d+:\d+: warning: .*\[(?P<warn>-Wanalyzer-[a-z-]+)\]$')
keys = {}
for line in open(hits_path):
    line = line.rstrip('\n')
    if not line:
        continue
    m = hit_re.match(line)
    if not m:
        raise SystemExit(f'run-analyzer: FAIL: unparsable hit line: {line}')
    keys.setdefault((m['file'], m['warn']), []).append(line)

# Triage rows are markdown table rows: | file | -Wanalyzer-name | count | disposition | note |
row_re = re.compile(r'^\|\s*`([^`]+)`\s*\|\s*`(-Wanalyzer-[a-z-]+)`\s*\|')
triaged = set()
for line in open(triage_path):
    m = row_re.match(line.strip())
    if m:
        triaged.add((m.group(1), m.group(2)))

untriaged = sorted(k for k in keys if k not in triaged)
stale = sorted(k for k in triaged if k not in keys)
print(f'run-analyzer: {len(keys)} (file, warning) pairs; {len(keys) - len(untriaged)} triaged, {len(untriaged)} untriaged')
for f, w in untriaged:
    print(f'  UNTRIAGED {f} {w} x{len(keys[(f, w)])}')
    for line in keys[(f, w)]:
        print(f'            {line}')
for f, w in stale:
    print(f'  NOT-REPRODUCED-HERE {f} {w} (triaged, not seen by this compiler/arch)')
sys.exit(1 if untriaged else 0)
PY

if ((status != 0)); then
	if [[ ${ANALYZER_STRICT:-0} == 1 ]]; then
		printf 'run-analyzer: FAIL: untriaged analyzer hits (ANALYZER_STRICT=1)\n' >&2
		exit 1
	fi
	printf 'run-analyzer: ADVISORY: untriaged analyzer hits above; add them to %s\n' "$triage" >&2
fi

((rc == 0)) || { printf 'run-analyzer: FAIL: the analyzer build did not compile (exit %s)\n' "$rc" >&2; exit "$rc"; }
printf 'run-analyzer: OK\n'
