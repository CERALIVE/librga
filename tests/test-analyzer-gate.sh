#!/usr/bin/env bash
# Modified by CeraLive 2026-09-16: exercise analyzer failures through its job entrypoint.
set -euo pipefail
root=$(realpath "$(dirname "${BASH_SOURCE[0]}")/..")
mkdir -p "$root/test-results"
scratch=$(mktemp -d "$root/test-results/analyzer-gate.XXXXXX")
trap 'rm -rf "$scratch"' EXIT
mkdir -p "$scratch"/{scripts,docs,bin}
cp "$root/scripts/run-analyzer.sh" "$scratch/scripts/"
printf '| `core/probe.cpp` | `-Wanalyzer-null-dereference` | 1 | fixture | fixture |\n' >"$scratch/docs/ANALYZER-TRIAGE.md"

# Fake only the expensive compiler boundary. Extraction, reconciliation, object
# coverage and the outer job's exit status are the real production implementation.
cat >"$scratch/bin/meson" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
case "$1" in
    setup)
        mkdir -p build-analyzer
        printf 'object\n' >build-analyzer/librga.so.probe.o
        printf '[{"directory":"build-analyzer","command":"g++ -fanalyzer -o librga.so.probe.o"}]\n' >build-analyzer/compile_commands.json
        ;;
    compile)
        if [[ ${COMPILE_RC:-0} != 0 ]]; then exit "$COMPILE_RC"; fi
        if [[ ${ZERO_OBJECTS:-0} == 1 ]]; then
            printf '[]\n' >build-analyzer/compile_commands.json
        fi
        if [[ ${NO_HITS:-0} != 1 ]]; then
            printf '../core/probe.cpp:4:2: warning: fixture [-Wanalyzer-null-dereference]\n'
        fi
        ;;
    *) exit 97 ;;
esac
SH
for tool in grep sed sort; do
    real_tool=$(command -v "$tool")
    printf '#!/usr/bin/env bash\n' >"$scratch/bin/$tool"
    printf 'if [[ ${FAULT_TOOL:-} == %q ]]; then exit 42; fi\n' "$tool" >>"$scratch/bin/$tool"
    printf 'exec %q "$@"\n' "$real_tool" >>"$scratch/bin/$tool"
done
chmod +x "$scratch/bin/"*
export PATH="$scratch/bin:$PATH" ANALYZER_STRICT=1

run_case() {
    local name=$1 expected=$2 rc=0
    bash "$scratch/scripts/run-analyzer.sh" >"$scratch/$name.log" 2>&1 || rc=$?
    if [[ $rc != "$expected" ]]; then
        cat "$scratch/$name.log" >&2
        printf 'FAIL: %s: job exit=%s, expected=%s\n' "$name" "$rc" "$expected" >&2
        exit 1
    fi
    printf 'PASS: %s: job exit=%s\n' "$name" "$rc"
}

run_case triaged 0
NO_HITS=1 run_case no-findings 0
COMPILE_RC=23 run_case compile-error 23
ZERO_OBJECTS=1 run_case zero-objects 1
mv "$scratch/docs/ANALYZER-TRIAGE.md" "$scratch/docs/triage.saved"
touch "$scratch/docs/ANALYZER-TRIAGE.md"
run_case untriaged 1
mv "$scratch/docs/triage.saved" "$scratch/docs/ANALYZER-TRIAGE.md"
for tool in grep sed sort; do
    FAULT_TOOL=$tool run_case "$tool-error" 42
done
run_case restored 0
