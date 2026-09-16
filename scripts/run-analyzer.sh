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
# Modified by CeraLive 2026-09-14: -Danalyzer=true remains compatible, but the
# blanket -w is gone; normal builds expose inherited diagnostics too.
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
# Untriaged hits fail by default. ANALYZER_STRICT=0 is a local advisory mode;
# the required CI job explicitly selects ANALYZER_STRICT=1.
set -euo pipefail

root=$(realpath "$(dirname "${BASH_SOURCE[0]}")/..")
cd "$root"
mkdir -p test-results
rm -f test-results/analyzer-complete.count test-results/analyzer-object.count \
    test-results/analyzer-hits.txt test-results/analyzer-probe.log

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
((rc == 0)) || { printf 'run-analyzer: FAIL: analyzer compile exit %s\n' "$rc" >&2; exit "$rc"; }
python3 - <<'PY'
import json
import shlex
import subprocess
from pathlib import Path

entries = json.loads(Path('build-analyzer/compile_commands.json').read_text())
checked = 0
for entry in entries:
    args = shlex.split(entry['command'])
    output = args[args.index('-o') + 1]
    if not output.startswith('librga.so.'):
        continue
    obj = Path(entry['directory']) / output
    if '-fanalyzer' not in args or '-w' in args or not obj.is_file() or obj.stat().st_size == 0:
        raise SystemExit(f'analyzer did not produce an analyzed object: {output}')
    if checked == 0:
        probe = Path('test-results/analyzer-probe.cpp').resolve()
        probe.write_text('int main() { int *p = nullptr; *p = 1; return 0; }\n')
        probe_output = probe.with_suffix('.o')
        if entry['file'] not in args:
            raise SystemExit('analyzer probe cannot identify the source argument')
        probe_args = [str(probe) if arg == entry['file'] else arg for arg in args]
        for option in ('-o', '-MF', '-MQ'):
            if option in probe_args:
                probe_args[probe_args.index(option) + 1] = str(probe_output) + ('.d' if option == '-MF' else '')
        result = subprocess.run(probe_args, cwd=entry['directory'], capture_output=True,
                                text=True, check=False)
        Path('test-results/analyzer-probe.log').write_text(result.stdout + result.stderr)
        if result.returncode != 0 or '-Wanalyzer-null-dereference' not in result.stderr:
            raise SystemExit('analyzer capability probe failed: planted null dereference not diagnosed')
    checked += 1
if checked == 0:
    raise SystemExit('analyzer executed no library translation units')
print(f'run-analyzer: {checked} analyzed library translation units produced objects')
Path('test-results/analyzer-object.count').write_text(f'{checked}\n')
PY

extract_rc=0
grep -oE '^[^ ]+:[0-9]+:[0-9]+: warning: .*\[-Wanalyzer-[a-z-]+\]' "$out" \
	>"$hits.raw" || extract_rc=$?
case "$extract_rc" in
	0|1) ;;
	*) printf 'run-analyzer: FAIL: diagnostic extraction exit %s\n' "$extract_rc" >&2; exit "$extract_rc" ;;
esac
sed -E 's#^(\.\./)+##' "$hits.raw" | LC_ALL=C sort -u >"$hits"

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
	if [[ ${ANALYZER_STRICT:-1} == 1 ]]; then
		printf 'run-analyzer: FAIL: untriaged analyzer hits (ANALYZER_STRICT=1)\n' >&2
		exit 1
	fi
	printf 'run-analyzer: ADVISORY: untriaged analyzer hits above; add them to %s\n' "$triage" >&2
fi

((rc == 0)) || { printf 'run-analyzer: FAIL: the analyzer build did not compile (exit %s)\n' "$rc" >&2; exit "$rc"; }
((status == 0)) && cp test-results/analyzer-object.count test-results/analyzer-complete.count
printf 'run-analyzer: OK\n'
