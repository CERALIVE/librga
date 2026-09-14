#!/usr/bin/env bash
# Modified by CeraLive 2026-09-13: protect the merged sanitizer and summary gates.
# Modified by CeraLive 2026-09-14: exercise project-prefixed Meson suite discovery.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
python3 - <<'PY'
import os
import json
from pathlib import Path
import subprocess
import tempfile
import textwrap

workflow = Path('.github/workflows/build-check.yml').read_text()
sanitizers = workflow.split('  sanitizers:\n', 1)[1].split('  build-check-summary:\n', 1)[0]
assert 'needs: [changes, resolve-suite]' in sanitizers
assert "if: needs.changes.outputs.code == 'true'" in sanitizers
assert 'runs-on: ubuntu-24.04-arm' in sanitizers
assert 'image: debian:${{ needs.resolve-suite.outputs.suite }}-slim' in sanitizers
assert 'run: bash ci/sanitizers-steps.sh' in sanitizers
assert 'placeholder' not in sanitizers
summary = workflow.split('  build-check-summary:\n', 1)[1]
assert 'if: always()' in summary
for dependency in ('changes', 'resolve-suite', 'build', 'test-results', 'sanitizers', 'werror'):
    assert f'      - {dependency}\n' in summary, dependency
werror = workflow.split('  werror:\n', 1)[1].split('  sanitizers:\n', 1)[0]
assert 'needs: [changes, resolve-suite]' in werror
assert "if: needs.changes.outputs.code == 'true'" in werror
assert 'run: bash ci/werror-steps.sh' in werror
assert 'continue-on-error' not in werror
assert 'CODE_CHANGED: ${{ needs.changes.outputs.code }}' in summary
script = textwrap.dedent(summary.split('        run: |\n', 1)[1])
cases = [
    ('true', 'success success success success success', True),
    ('false', 'success skipped skipped skipped skipped', True),
    ('true', 'success success skipped success success', False),
    ('', 'success skipped skipped skipped skipped', False),
    ('true', 'success failure skipped skipped skipped', False),
    ('false', 'success success failure success success', False),
    ('false', 'success cancelled skipped skipped skipped', False),
]
for code, results, expected in cases:
    run = subprocess.run(['bash', '-c', script], capture_output=True, text=True,
                         env={**os.environ, 'CODE_CHANGED': code, 'RESULTS': results})
    assert (run.returncode == 0) == expected, (code, results, run.stdout, run.stderr)
print(f'PASS: real sanitizer lane retained; summary gate {len(cases)}/{len(cases)} cases')

# Execute the gate's actual discovery block, not a duplicate of its predicate.
gate = Path('ci/sanitizers-steps.sh').read_text()
discovery = gate.split("concurrency_count=\"$(python3 - <<'PY'\n", 1)[1].split('\nPY\n', 1)[0]
suite_cases = [
    ([{'suite': ['librga:concurrency']}], 1),
    ([{'suite': ['librga:h10', 'librga:concurrency']}], 1),
    ([{'suite': ['other:concurrency', 'librga:concurrency']}], 1),
    ([{'suite': ['librga:h10']}], 0),
    ([{'suite': ['librga:not-concurrency', 'librga:concurrency-extra', 'concurrency:h10']}], 0),
    ([{'suite': []}, {}], 0),
    ([], 0),
]
results_dir = Path('test-results')
results_dir.mkdir(exist_ok=True)
with tempfile.TemporaryDirectory(prefix='suite-discovery-', dir=results_dir) as directory:
    intro = Path(directory) / 'build-tsan/meson-info/intro-tests.json'
    intro.parent.mkdir(parents=True)
    for tests, expected in suite_cases:
        intro.write_text(json.dumps(tests))
        run = subprocess.run(['python3', '-c', discovery], cwd=directory,
                             capture_output=True, text=True)
        assert run.returncode == 0, run.stderr
        assert int(run.stdout) == expected, (tests, expected, run.stdout)
print(f'PASS: sanitizer suite discovery {len(suite_cases)}/{len(suite_cases)} cases')
PY
