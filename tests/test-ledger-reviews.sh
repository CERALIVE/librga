#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# Modified by CeraLive 2026-09-14: exercise the actual D21 review gate.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
python3 - <<'PY'
from pathlib import Path
import subprocess
import tempfile

root = Path.cwd()
header = '| Provenance SHA | Reproducer (path · RED · GREEN) | Hardware gate | ABI closure (nm vs R0 · abidiff vs previous release) | Independent reviewer verdict · reviewer session id | `Upstream-status` |\n|---|---|---|---|---|---|\n'
receipt = 'author=writer/openai/author-model reviewer=auditor/openai/reviewer-model verdict=APPROVE ses_Valid123'
row = f'| status=GREEN fix=abcdef1234; repair | RED then GREEN | host-shim-only | unchanged | {receipt} | donor |\n'
observation = '| status=NOT-REPRODUCED fix=none; base `abcdef1234`, no fix | GREEN: not run | host-shim-only | n/a | reviewer=auditor/openai/reviewer-model verdict=APPROVE ses_Evidence123; evidence-only | not applicable |\n'
cases = [
    ('green', header + row, True),
    ('observation', header + observation, True),
    ('missing-receipt', header + row.replace(receipt, 'pending'), False),
    ('same-agent', header + row.replace('reviewer=auditor/', 'reviewer=writer/'), False),
    ('same-model', header + row.replace('reviewer-model', 'author-model'), False),
    ('same-model-other-provider', header + row.replace('openai/reviewer-model', 'other/author-model'), False),
    ('reject', header + row.replace('verdict=APPROVE', 'verdict=REJECT'), False),
    ('empty-session', header + row.replace('ses_Valid123', 'ses_'), False),
    ('missing-author', header + row.replace('author=writer/openai/author-model ', ''), False),
    ('green-no-fix', header + row.replace('fix=abcdef1234', 'fix=none'), False),
    ('no-fix-with-commit', header + observation.replace('fix=none', 'fix=abcdef1234'), False),
    ('withdrawn-with-commit', header + observation.replace('NOT-REPRODUCED', 'WITHDRAWN').replace('fix=none', 'fix=abcdef1234'), False),
    ('skipped-with-commit', header + observation.replace('NOT-REPRODUCED', 'SKIPPED').replace('fix=none', 'fix=abcdef1234'), False),
    ('gap', header + row.replace('unchanged', 'GAP: missing ABI'), False),
    ('duplicate-header', header + row + header + row, False),
    ('empty', header, False),
    ('malformed', header + row.replace('| donor |', '| |'), False),
    ('history-not-current', header + row.replace(receipt, 'Historical: ' + receipt), False),
    ('history-reject-retained', header + row.replace(receipt, receipt + '; Historical review: REJECT ses_Old123'), True),
    ('escaped-pipe', header + row.replace('RED then GREEN', r'RED a\|b then GREEN'), True),
]
(root / 'test-results').mkdir(exist_ok=True)
with tempfile.TemporaryDirectory(prefix='ledger-gate-', dir=root / 'test-results') as tmp:
    ledger = Path(tmp) / 'ledger.md'
    for name, content, expected in cases:
        ledger.write_text(content)
        result = subprocess.run(['bash', 'scripts/check-ledger-reviews.sh', str(ledger)], text=True, capture_output=True)
        assert (result.returncode == 0) == expected, (name, result.returncode, result.stdout, result.stderr)
print(f'PASS: ledger review gate {len(cases)}/{len(cases)} scenarios')
PY
