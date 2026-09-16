#!/usr/bin/env bash
# Modified by CeraLive 2026-09-13: protect the merged sanitizer and summary gates.
# Modified by CeraLive 2026-09-14: exercise project-prefixed Meson suite discovery.
# Modified by CeraLive 2026-09-14: keep shim preload out of the H10 shell launcher.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
python3 - <<'PY'
import os
import json
import re
from pathlib import Path
import subprocess
import tempfile
import textwrap

workflow = Path('.github/workflows/build-check.yml').read_text()
sanitizers = workflow.split('  sanitizers:\n', 1)[1].split('  abi:\n', 1)[0]
assert 'needs: [changes, resolve-suite]' in sanitizers
assert "if: needs.changes.outputs.code == 'true'" in sanitizers
assert 'runs-on: ubuntu-24.04-arm' in sanitizers
assert 'image: debian:${{ needs.resolve-suite.outputs.suite }}-slim' in sanitizers
assert 'run: bash ci/sanitizers-steps.sh' in sanitizers
assert 'run: bash tests/test-sanitizer-failures.sh' in sanitizers
assert 'continue-on-error' not in sanitizers
assert 'placeholder' not in sanitizers
summary = workflow.split('  build-check-summary:\n', 1)[1]
assert 'if: always()' in summary
dependencies = ('changes', 'resolve-suite', 'build', 'test-results', 'sanitizers', 'werror', 'analyzer', 'abi', 'reproducible')
for dependency in dependencies:
    assert f'      - {dependency}\n' in summary, dependency
werror = workflow.split('  werror:\n', 1)[1].split('  sanitizers:\n', 1)[0]
assert 'needs: [changes, resolve-suite]' in werror
assert "if: needs.changes.outputs.code == 'true'" in werror
assert 'run: bash ci/werror-steps.sh' in werror
assert 'continue-on-error' not in werror
analyzer = workflow.split('  analyzer:\n', 1)[1].split('  werror:\n', 1)[0]
assert 'continue-on-error' not in analyzer
assert "ANALYZER_STRICT: '1'" in analyzer
assert 'run: bash scripts/run-analyzer.sh' in analyzer
assert 'run: bash tests/test-analyzer-gate.sh' in analyzer
assert 'needs: [changes, resolve-suite]' in analyzer
assert "if: needs.changes.outputs.code == 'true'" in analyzer
abi = workflow.split('  abi:\n', 1)[1].split('  reproducible:\n', 1)[0]
assert 'run: bash ci/abi-steps.sh' in abi
assert 'continue-on-error' not in abi
assert 'fetch-depth: 0' in abi
assert 'export GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=safe.directory GIT_CONFIG_VALUE_0="$root"' in Path('ci/abi-steps.sh').read_text()
abi_steps = Path('ci/abi-steps.sh').read_text()
assert 'bash tests/test-abi-layout.sh' in abi_steps
assert '-Db_lto=false' in abi_steps and '-Db_lto=true' in abi_steps
assert '"$out/abidiff-lto.txt"' in abi_steps
assert '"$out/abidiff-lto-only.txt"' in abi_steps
assert abi_steps.count('packaging/baseline-symbols-upstream-delta.txt') == 2
assert 'source ci/package-lto.env' in abi_steps
assert 'export PACKAGED_LTO' in abi_steps
assert 'bash tests/test-dynsym-gate.sh | tee "$out/dynsym-controls.txt"' in abi_steps
assert 'bash ci/check-lto-policy.sh "$out/build-r1/librga.so" "$out/build-r1-lto/librga.so"' in abi_steps
assert '"$out/dynsym-lto.diff" | tee "$out/dynsym-policy.txt"' in abi_steps
assert '-Db_lto="$PACKAGED_LTO"' in abi_steps
assert 'python3 ci/check-dynsym.py "$out/build-r1/librga.so" "$out/build-r1-selected/librga.so"' in abi_steps
assert '"$out/dynsym-selected.diff"' in abi_steps
assert 'set -euo pipefail' in abi_steps
assert 'readonly PACKAGED_LTO=false' in Path('ci/package-lto.env').read_text()
assert 'name: dynamic-symbol-evidence' in abi
dynsym_upload = abi.split('name: Retain exact dynamic-symbol comparison and LTO qualification', 1)[1].split('      - uses:', 1)[0]
assert 'if: always()' in dynsym_upload
assert 'path: test-results/abi/dynsym-*' in dynsym_upload
assert 'if-no-files-found: error' in dynsym_upload
for build_script in ('packaging/build-deb.sh', 'ci/build-check-steps.sh'):
    build_text = Path(build_script).read_text()
    assert 'source ' in build_text and 'ci/package-lto.env' in build_text, build_script
    assert '-Db_lto="${PACKAGED_LTO}"' in build_text, build_script
    assert '-Db_lto=true' not in build_text, build_script
reproducible = workflow.split('  reproducible:\n', 1)[1].split('  mtune-measurement:\n', 1)[0]
assert 'export GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=safe.directory GIT_CONFIG_VALUE_0="$PWD"' in reproducible
assert 'packaging/package-contract.sh --repro' in reproducible
assert 'continue-on-error' not in reproducible
measurement = workflow.split('  mtune-measurement:\n', 1)[1].split('  build-check-summary:\n', 1)[0]
assert 'continue-on-error: true' in measurement
assert '      - mtune-measurement\n' not in summary
assert '-mtune' not in Path('packaging/build-deb.sh').read_text()
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
    ('true', '', False),
    ('false', '  ', False),
    ('true', 'success unknown success success success', False),
    ('', 'success success success success success', False),
    ('unknown', 'success success success success success', False),
]
for code, results, expected in cases:
    run = subprocess.run(['bash', '-c', script], capture_output=True, text=True,
                         env={**os.environ, 'CODE_CHANGED': code, 'RESULTS': results})
    assert (run.returncode == 0) == expected, (code, results, run.stdout, run.stderr)
print(f'PASS: real sanitizer lane retained; summary gate {len(cases)}/{len(cases)} cases')
for dependency in dependencies:
    for result in ('failure', 'cancelled', 'skipped', 'unknown'):
        results = ['success'] * len(dependencies)
        results[dependencies.index(dependency)] = result
        run = subprocess.run(['bash', '-c', script], capture_output=True, text=True,
                             env={**os.environ, 'CODE_CHANGED': 'true', 'RESULTS': ' '.join(results)})
        assert run.returncode != 0, (dependency, result, run.stdout)
print(f'PASS: all {len(dependencies)} required dependencies reject failure/cancelled/skipped/unknown')

count_checker = Path('ci/check-test-count.sh').resolve()
Path('test-results').mkdir(exist_ok=True)
with tempfile.TemporaryDirectory(prefix='count-contract-', dir='test-results') as directory:
    log = Path(directory) / 'testlog.json'
    for expected in (11, 6):
        for count, result, passes in ((expected, 'OK', True), (0, 'OK', False),
                                      (expected - 1, 'OK', False), (expected, 'SKIP', False),
                                      (expected, 'FAIL', False)):
            log.write_text('\n'.join(json.dumps({'name': f'test-{i}', 'result': result}) for i in range(count)))
            run = subprocess.run(['bash', str(count_checker), str(log), str(expected)], capture_output=True)
            assert (run.returncode == 0) == passes, (expected, count, result)
print('PASS: executed-count guards reject empty, incomplete, skipped and failed runs')

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

# Use the registration's actual preload key: checking only the shell would miss
# Meson injecting LD_PRELOAD before the shell can execute its first statement.
fragment = Path('tests/meson-fragments/unit.build').read_text()
assert fragment in Path('meson.build').read_text(), 'generated unit fragment drift'
preload_keys = re.findall(r"h10_env\.set\('([^']+)', fake_rga\.full_path\(\)\)", fragment)
assert len(preload_keys) == 1, preload_keys
launcher = Path('tests/repro/run-h10-case.sh').resolve()
with tempfile.TemporaryDirectory(prefix='h10-launcher-', dir=results_dir) as directory:
    scratch = Path(directory).resolve()
    startup = scratch / 'bash-startup.sh'
    startup.write_text('[[ ! -v LD_PRELOAD ]] || { printf "shim preloaded into Bash\\n" >&2; exit 91; }\n')
    log, dump = scratch / 'shim log', scratch / 'shim dump'
    # libc is a valid preload on both tested architectures; this contract checks
    # the process boundary. The real H10 binary separately requires the real shim.
    env = {key: value for key, value in os.environ.items() if key != 'LD_PRELOAD'}
    env.update({preload_keys[0]: 'libc.so.6', 'BASH_ENV': str(startup),
                'FAKE_RGA_LOG': str(log), 'FAKE_RGA_DUMP': str(dump),
                'FAKE_RGA_REIMPORT': 'stale', 'FAKE_RGA_FAIL': 'stale',
                'ASAN_OPTIONS': 'detect_leaks=1:verify_asan_link_order=0:abort_on_error=1',
                'UBSAN_OPTIONS': 'print_stacktrace=1:halt_on_error=1',
                'TSAN_OPTIONS': 'halt_on_error=1:exitcode=66'})
    log.write_text('stale log')
    dump.write_bytes(b'stale dump')
    run = subprocess.run(['bash', str(launcher), '/usr/bin/env'], env=env,
                         capture_output=True, text=True, timeout=10)
    assert run.returncode == 0, (run.returncode, run.stderr)
    child = dict(line.split('=', 1) for line in run.stdout.splitlines() if '=' in line)
    assert child['LD_PRELOAD'] == 'libc.so.6', child
    assert 'FAKE_RGA_REIMPORT' not in child and 'FAKE_RGA_FAIL' not in child
    assert log.read_bytes() == dump.read_bytes() == b''
    for key in ('ASAN_OPTIONS', 'UBSAN_OPTIONS', 'TSAN_OPTIONS'):
        assert child[key] == env[key], (key, child)
    for status in (0, 23, 66):
        run = subprocess.run(['bash', str(launcher), '/bin/sh', '-c', f'exit {status}'],
                             env=env, capture_output=True, text=True, timeout=10)
        assert run.returncode == status, (status, run.returncode, run.stderr)
print('PASS: H10 preloads only the child; log reset, fault reset, options and exit status preserved')
PY
