#!/usr/bin/env bash
# Modified by CeraLive 2026-09-06: protect ledger structure and verbatim evidence.
set -euo pipefail
root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
python3 - "$root" <<'PY'
from collections import Counter
from hashlib import sha256
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

root = Path(sys.argv[1])
header = '| Provenance SHA | Reproducer (path · RED · GREEN) | Hardware gate | ABI closure (nm vs R0 · abidiff vs previous release) | Independent reviewer verdict · reviewer session id | `Upstream-status` |'
separator = '|---|---|---|---|---|---|'
original = (root / 'docs/fix-audit.md').read_bytes()
fragments = {p.name: p.read_bytes() for p in (root / 'docs/fix-audit.d').glob('*.md')}
results = root / 'test-results'
results.mkdir(exist_ok=True)

def evidence_lines(text):
    return Counter(line for line in text.splitlines() if line.strip()
                   and line not in (header, separator))

def table_rows(text):
    lines = text.splitlines()
    start = lines.index(header)
    assert lines[start + 1] == separator, 'missing D21 separator'
    end = next((i for i in range(start + 2, len(lines))
                if not lines[i].startswith('|')), len(lines))
    rows = lines[start + 2:end]
    assert rows, 'empty ledger table'
    assert all(len(line.replace(r'\|', '').split('|')) == 8 for line in rows)
    return rows

with tempfile.TemporaryDirectory(prefix='wire-bootstrap-', dir=results) as directory:
    fixture = Path(directory)
    for name in ('scripts', 'docs/fix-audit.d', 'tests/meson-fragments'):
        (fixture / name).mkdir(parents=True, exist_ok=True)
    for name in ('scripts/wire-bootstrap.sh', 'meson.build', 'docs/fix-audit.md'):
        shutil.copyfile(root / name, fixture / name)
    for source in (root / 'tests/meson-fragments').glob('*.build'):
        shutil.copyfile(source, fixture / 'tests/meson-fragments' / source.name)
    for name, data in fragments.items():
        (fixture / 'docs/fix-audit.d' / name).write_bytes(data)

    def wire():
        return subprocess.run(['bash', 'scripts/wire-bootstrap.sh'], cwd=fixture,
                              capture_output=True, text=True)

    run = wire()
    assert run.returncode == 0, run.stderr
    ledger = (fixture / 'docs/fix-audit.md').read_bytes()
    text = ledger.decode()
    assert text.splitlines().count(header) == 1, 'duplicate D21 headers'
    assert text.splitlines().count(separator) == 1, 'duplicate D21 separators'
    assert 'empty on purpose' not in text, 'stale introduction'
    assert 'no fix has landed yet' in text
    assert 'no library source has been changed' in text
    expected_rows = [line for data in fragments.values() for line in data.decode().splitlines()
                     if line.startswith('|') and line.count('|') == 7
                     and line not in (header, separator)]
    assert Counter(table_rows(text)) == Counter(expected_rows), 'lost or misplaced D21 rows'
    expected = sum((evidence_lines(data.decode()) for data in fragments.values()), Counter())
    assert not expected - evidence_lines(text), 'fragment evidence changed or dropped'
    for name, data in fragments.items():
        rows = set(expected_rows)
        prose = ''.join(line for line in data.decode().splitlines(keepends=True)
                        if line.rstrip('\n') not in rows | {header, separator})
        if prose.strip():
            label = f'## Appendix — {name}'
            assert text.index(label) > text.index(expected_rows[-1])
            section = text.split(label, 1)[1].split('\n## Appendix — ', 1)[0]
            assert prose in section, f'{name}: prose changed, reordered or moved outside its appendix'
        assert (fixture / 'docs/fix-audit.d' / name).read_bytes() == data

    meson = (fixture / 'meson.build').read_bytes()
    run = wire()
    assert run.returncode == 0, run.stderr
    assert (fixture / 'docs/fix-audit.md').read_bytes() == ledger, 'ledger is not idempotent'
    assert (fixture / 'meson.build').read_bytes() == meson, 'Meson wiring is not idempotent'
    print(f'PASS: {len(fragments)} unchanged fragments; {len(expected_rows)} continuous D21 rows; all evidence retained')
    print(f'PASS: both wiring runs SHA-256 {sha256(ledger).hexdigest()}')

    # A six-column measurement table is not a D21 table. Nor are literal rows
    # in a transcript or comment, even if they look exactly like ledger rows.
    row = '| fixture | path \\| literal · RED · GREEN | host-shim-only | ABI | reviewer | status |'
    prose = ('# Fixture prose\n\n```text\n' + header + '\n' + separator + '\n' + row + '\n```\n\n'
             '<!--\n' + header + '\n' + separator + '\n' + row + '\n-->\n\n'
             '| A | B | C | D | E | F |\n' + separator + '\n'
             '| 1 | 2 | 3 | 4 | 5 | 6 |\n')
    extra = fixture / 'docs/fix-audit.d/fixture.md'
    extra.write_text(header + '\n' + separator + '\n' + row + '\n\n' + prose)
    run = wire()
    assert run.returncode == 0, run.stderr
    text = (fixture / 'docs/fix-audit.md').read_text()
    assert Counter(table_rows(text)) == Counter(expected_rows + [row])
    assert prose in text.split('## Appendix — fixture.md', 1)[1]

    before = (fixture / 'docs/fix-audit.md').read_bytes()
    extra.write_text(header + '\n' + separator + '\n| missing | fields |\n')
    run = wire()
    assert run.returncode != 0, 'malformed D21 row accepted'
    assert (fixture / 'docs/fix-audit.md').read_bytes() == before, 'failed assembly overwrote ledger'
    print('PASS: subsidiary tables, fenced/commented transcripts, escaped pipes, malformed-row rejection')

assert (root / 'docs/fix-audit.md').read_bytes() == original, 'test changed checkout ledger'
PY
