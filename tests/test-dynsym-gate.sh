#!/usr/bin/env bash
# Modified by CeraLive 2026-09-15: prove ELF metadata drift cannot qualify LTO.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
mkdir -p test-results
python3 - <<'PY'
import os
from pathlib import Path
import subprocess
import tempfile

checker = Path('ci/check-dynsym.py').resolve()
policy = Path('ci/check-lto-policy.sh').resolve()
with tempfile.TemporaryDirectory(prefix='dynsym-control-', dir='test-results') as directory:
    scratch = Path(directory)
    source = scratch / 'control.cpp'
    source.write_text('''
extern "C" __attribute__((weak)) int overridable() { return 7; }
inline int &singleton() { static int instance; return instance; }
extern "C" int *address() { return &singleton(); }
extern "C" int ordinary() { return 3; }
''')
    original = scratch / 'original.so'
    subprocess.run(['g++', '-std=c++14', '-fPIC', '-shared', str(source), '-o', str(original)], check=True)
    report = scratch / 'comparison.diff'
    def compare(candidate: Path) -> subprocess.CompletedProcess[str]:
        return subprocess.run(['python3', str(checker), str(original), str(candidate), str(report)],
                              capture_output=True, text=True)

    # Given identical real ELF input, equality must pass and retain nonempty inventories.
    run = compare(original)
    assert run.returncode == 0, (run.returncode, run.stderr)
    assert report.read_text() == ''
    inventory = Path(str(report) + '.before.tsv').read_text()
    assert 'overridable\tFUNC\tWEAK\tDEFAULT\n' in inventory
    assert '_ZZ9singletonvE8instance\tOBJECT\tUNIQUE\tDEFAULT\n' in inventory
    for packaged in ('false', 'true'):
        run = subprocess.run(['bash', str(policy), str(original), str(original), str(report)],
                             env={**os.environ, 'PACKAGED_LTO': packaged}, capture_output=True)
        assert run.returncode == 0

    # Mutate the actual .dynsym entry, not .symtab (objcopy --globalize-symbol
    # only changes the latter). readelf supplies offsets independently of the gate.
    sections = subprocess.check_output(['readelf', '-SW', str(original)], text=True)
    dynsym = next(line.split() for line in sections.splitlines() if ' .dynsym ' in line)
    index = dynsym.index('.dynsym')
    offset, stride = int(dynsym[index + 3], 16), int(dynsym[index + 5], 16)
    symbols = subprocess.check_output(['readelf', '--dyn-syms', '--wide', str(original)], text=True)
    elf = original.read_bytes()
    info_offset = 4 if elf[4] == 2 else 12
    cases = [('overridable', 'binding', 1), ('_ZZ9singletonvE8instance', 'binding', 1),
             ('ordinary', 'type', 1), ('ordinary', 'visibility', 3)]
    for name, field, value in cases:
        number = int(next(line.split()[0].rstrip(':') for line in symbols.splitlines()
                          if line.split() and line.split()[-1] == name))
        mutated = bytearray(elf)
        position = offset + number * stride + info_offset
        if field == 'binding':
            mutated[position] = (value << 4) | (mutated[position] & 15)
        elif field == 'type':
            mutated[position] = (mutated[position] & 240) | value
        else:
            mutated[position + 1] = value
        candidate = scratch / f'{name}-{field}.so'
        candidate.write_bytes(mutated)
        run = compare(candidate)
        assert run.returncode == 1, (name, field, run.returncode, run.stderr)
        assert name in report.read_text(), report.read_text()
        print(f'PASS: real .dynsym {name} {field} mutation rejected (exit 1)')
        for packaged, expected in [('false', 0), ('true', 1), ('invalid', 2)]:
            run = subprocess.run(['bash', str(policy), str(original), str(candidate), str(report)],
                                 env={**os.environ, 'PACKAGED_LTO': packaged}, capture_output=True, text=True)
            assert run.returncode == expected, (packaged, run.returncode, run.stderr)
    broken = scratch / 'broken.so'
    broken.write_text('not ELF')
    assert compare(broken).returncode == 2
    for packaged in ('false', 'true'):
        run = subprocess.run(['bash', str(policy), str(original), str(broken), str(report)],
                             env={**os.environ, 'PACKAGED_LTO': packaged}, capture_output=True)
        assert run.returncode == 2
    print('PASS: LTO policy rejects mismatched shipping LTO and tool errors; non-LTO remains permitted')
PY
