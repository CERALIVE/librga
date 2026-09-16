#!/usr/bin/env python3
# Modified by CeraLive 2026-09-15: compare exported ELF metadata, not DWARF alone.
# /// script
# requires-python = ">=3.11"
# dependencies = []
# ///
# Usage: python3 ci/check-dynsym.py BEFORE.so AFTER.so REPORT.diff
"""Require exact exported (name, type, binding, visibility) equality.

Exit 0 means equality, 1 means drift, and 2 means invalid input/tool failure.
Undefined imports and local symbols are not exports. Addresses, sizes, section
indices and symbol-table order are deliberately outside this metadata contract.
"""

import difflib
import os
from pathlib import Path
import re
import subprocess
import sys


def inventory(library: Path, destination: Path) -> list[str]:
    result = subprocess.run(
        ['readelf', '--dyn-syms', '--wide', str(library)],
        env={**os.environ, 'LC_ALL': 'C'}, check=True, capture_output=True, text=True,
    )
    Path(str(destination) + '.readelf').write_text(result.stdout)
    header = re.search(r"Symbol table '.dynsym' contains (\d+) entries:", result.stdout)
    if header is None:
        raise SystemExit(f'dynsym: missing .dynsym in {library}')
    rows = [line.split() for line in result.stdout.splitlines() if re.match(r'\s*\d+:', line)]
    if len(rows) != int(header[1]) or any(len(row) < 7 for row in rows):
        raise SystemExit(f'dynsym: incomplete symbol table in {library}')
    exports: list[str] = []
    for row in rows:
        if row[6] == 'UND' or row[4] == 'LOCAL':
            continue
        if len(row) != 8:
            raise SystemExit(f'dynsym: malformed export in {library}: {row}')
        exports.append('\t'.join((row[7], row[3], row[4], row[5])) + '\n')
    if not exports:
        raise SystemExit(f'dynsym: no exports in {library}')
    exports.sort()
    destination.write_text(''.join(exports))
    return exports


def main() -> int:
    if len(sys.argv) != 4:
        print(__doc__, file=sys.stderr)
        return 2
    before, after, report = map(Path, sys.argv[1:])
    try:
        old = inventory(before, Path(str(report) + '.before.tsv'))
        new = inventory(after, Path(str(report) + '.after.tsv'))
        delta = ''.join(difflib.unified_diff(old, new, fromfile=str(before), tofile=str(after)))
        report.write_text(delta)
    except (OSError, subprocess.CalledProcessError, SystemExit) as error:
        print(f'dynsym: invalid comparison: {error}', file=sys.stderr)
        return 2
    print(f'dynsym: {len(old)} -> {len(new)} exports; ' + ('FAIL: metadata differs' if delta else 'PASS: exact equality'))
    return 1 if delta else 0


if __name__ == '__main__':
    sys.exit(main())
