#!/usr/bin/env bash
# Modified by CeraLive 2026-09-13: protect the merged sanitizer and summary gates.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
python3 - <<'PY'
import os
from pathlib import Path
import subprocess
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
PY
