#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# Modified by CeraLive 2026-09-14: fail closed on missing or non-independent D21 receipts.
set -euo pipefail
root=$(realpath "$(dirname "${BASH_SOURCE[0]}")/..")
python3 - "${1:-$root/docs/fix-audit.md}" <<'PY'
from pathlib import Path
import re
import sys

path = Path(sys.argv[1])
lines = path.read_text().splitlines()
headers = [i for i, line in enumerate(lines) if line.startswith('| Provenance SHA |')]
if len(headers) != 1:
    sys.exit(f'{path}: expected exactly one D21 schema header')
index = headers[0] + 1
if index == len(lines) or lines[index] != '|---|---|---|---|---|---|':
    sys.exit(f'{path}: missing D21 separator')
errors: list[str] = []
count = 0
green = 0
for number in range(index + 1, len(lines)):
    line = lines[number]
    if not line.startswith('|'):
        break
    count += 1
    cells = re.split(r'(?<!\\)\|', line)
    if len(cells) != 8 or any(not cell.strip() for cell in cells[1:-1]):
        errors.append(f'line {number + 1}: malformed six-field D21 row')
        continue
    if 'GAP:' in line:
        errors.append(f'line {number + 1}: unresolved GAP')
    disposition = re.match(r'\s*status=(GREEN|OBSERVATION|SKIPPED|NOT-REPRODUCED|WITHDRAWN) fix=(none|[0-9a-f]{7,40});', cells[1])
    current = cells[5].strip().split('; Historical review:', 1)[0]
    receipt = re.fullmatch(r'(?:author=([^/\s]+)/([^\s]+) )?reviewer=([^/\s]+)/([^\s]+) verdict=APPROVE (ses_[A-Za-z0-9]+)(?:; evidence-only)?', current)
    if disposition is None:
        errors.append(f'line {number + 1}: missing explicit status/fix disposition')
    if receipt is None:
        errors.append(f'line {number + 1}: missing current APPROVE receipt/session')
    if disposition is None or receipt is None:
        continue
    status, fix = disposition.groups()
    author, author_model, reviewer, reviewer_model, _ = receipt.groups()
    if status == 'GREEN':
        green += 1
        if fix == 'none' or author is None or author_model is None:
            errors.append(f'line {number + 1}: GREEN requires a fix commit and author identity')
        elif author == reviewer or author_model == reviewer_model or author_model.rsplit('/', 1)[-1] == reviewer_model.rsplit('/', 1)[-1]:
            errors.append(f'line {number + 1}: author/reviewer agents and model IDs must both differ')
    elif fix != 'none':
        errors.append(f'line {number + 1}: {status} must carry fix=none (base/donor SHAs are not fixes)')
if count == 0:
    errors.append('empty D21 ledger')
if errors:
    sys.exit(f'{path}:\n' + '\n'.join(errors))
print(f'PASS: {count} D21 rows reviewed; {green} GREEN fix rows independently approved; no GAP')
PY
