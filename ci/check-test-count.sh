#!/usr/bin/env bash
# Modified by CeraLive 2026-09-14: require executed results, never an empty green.
set -euo pipefail
python3 - "$@" <<'PY'
import json
import sys
from pathlib import Path

path, expected = sys.argv[1], int(sys.argv[2])
rows = [json.loads(line) for line in Path(path).read_text().splitlines()]
if expected <= 0 or len(rows) != expected:
    raise SystemExit(f'{path}: expected {expected} executed tests, got {len(rows)}')
bad = [row for row in rows if row['result'] != 'OK']
if bad:
    raise SystemExit(f'{path}: non-passing results: {bad}')
print(f'{path}: {len(rows)}/{expected} executed and OK')
PY
