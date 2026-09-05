# Sanitizers and the static analyzer

What is instrumented, what each recipe proves, and — the part that matters most —
what none of it proves. Read the proof boundary in
[`AGENTS.md`](../AGENTS.md) first; this file is the mechanism behind it.

## The one-line boundary

**TSan, ASan and UBSan are host-shim-only.** Every sanitized binary in this
repository talks to `tests/shim/fake_rga.c`, not to `/dev/rga`. A clean run is
evidence about this library's behaviour against the shim's *model* of the driver.
It is not evidence about silicon, and no board drill or `docs/fix-audit.md` row
may cite a sanitizer result as a hardware claim.

## Recipes

| Command | Tree | Instrumentation |
|---|---|---|
| `bash scripts/build-sanitized.sh asan` | `build-asan/` | `-fsanitize=address,undefined` |
| `bash scripts/build-sanitized.sh tsan` | `build-tsan/` | `-fsanitize=thread` |
| `bash scripts/run-analyzer.sh` | `build-analyzer/` | GCC `-fanalyzer` |
| `bash ci/sanitizers-steps.sh` | both sanitizer trees | the whole CI leg, locally |

`ci/sanitizers-steps.sh` is the CI job. Run it exactly as CI does:

```sh
docker run --rm --platform linux/arm64 -v "$PWD":/src -w /src \
  debian:trixie-slim bash ci/sanitizers-steps.sh
```

### Where this can be reproduced — and where it cannot

The CI leg runs on a **native** aarch64 runner. Reproducing it on an x86_64
workstation works only in a **native-arch** container (`debian:trixie-slim`
without `--platform`); it does **not** work under qemu-user aarch64 emulation, and
the failures are the emulator's, not the recipe's:

```text
# gcc -fsanitize=address … under docker --platform linux/arm64
==1228==LeakSanitizer has encountered a fatal error.

# gcc -fsanitize=thread … under docker --platform linux/arm64
FATAL: ThreadSanitizer: unsupported VMA range
FATAL: Found 47 - Supported 39, 42 and 48
```

LeakSanitizer needs a stop-the-world mechanism the emulator does not provide, and
TSan rejects the emulated 47-bit VMA layout outright. Meson's compiler sanity
check links with the configured sanitize flags, so `meson setup` itself fails —
before any `ASAN_OPTIONS` could soften it, and softening it would delete the leak
detection the leg exists for.

So: reproduce locally on the host's own architecture, and read the aarch64 result
off CI or off a board. The architecture caveat that comes with a non-aarch64 run
is printed by `ci/sanitizers-steps.sh` on every such run.

### Three flags that are not optional

- **`-Db_lundef=false`.** Meson links with `-Wl,--no-undefined` by default. A
  sanitized shared object legitimately leaves the runtime's symbols undefined
  until an executable pulls `libasan`/`libtsan` in, so the default refuses the
  link.
- **`-Dcpp_link_args=-fsanitize=…` (and `-Dc_link_args`).** Setting the sanitize
  option without the link args produced a `.so` with no runtime attached and a
  clean run that had instrumented nothing. `scripts/build-sanitized.sh` therefore
  asserts the runtime with `ldd` before it exits, rather than trusting configure.
- **`-fpermissive`.** `im2d_impl.cpp` and `NormalRga.cpp` cast `void*` to
  `unsigned int` in the `#else` half of
  `#if defined(__arm64__) || defined(__aarch64__)`. On aarch64 that code is not
  compiled; on an x86_64 development host it is, and GCC makes the narrowing cast
  a hard error without this flag. It is what lets the host legs run off-device at
  all, and it is a no-op on the device arch.

### The canaries

`ldd` proves a runtime is *linked*. Only a deliberate fault proves it is
*intercepting*. `tests/shim/asan-canary.c` commits a signed-integer overflow and
then a one-byte heap overflow — one fault per runtime, because `asan` here means
`address,undefined` and half a proof is not a proof. `tests/shim/tsan-canary.c`
races two threads on one `int`. `ci/sanitizers-steps.sh` runs both and **fails if
either stays silent**.

The ASan canary runs under the same `LD_PRELOAD` and `ASAN_OPTIONS` as the tests,
which is the point of it — see the next section.

### `verify_asan_link_order=0`

The golden and session tests reach librga through `LD_PRELOAD` of the shim. That
puts a foreign DSO ahead of `libasan` in the initial library list, and ASan's
conservative ordering check then refuses to start at all:

```text
ASan runtime does not come first in initial library list
```

Interception still resolves through `libasan` — neither the executable nor the
shim defines the intercepted allocator symbols — so the check is waived and the
canary is run under that same preload to demonstrate it. If the canary ever goes
quiet, the waiver is no longer safe and the leg fails.

## The board question: ASan yes-if, TSan never

**TSan is host-only permanently.** It cannot be statically linked reliably, so
there is no board-side ThreadSanitizer and no TSan row may ever be recorded
against hardware.

**ASan *can* be static-linked**, which is the only reason a board leg is
conceivable: `-static-libasan` means nothing has to be installed on the board.
That leg is gated on one preflight, run by `scripts/cross-build-harness.sh --asan`:

```sh
aarch64-linux-gnu-gcc -print-file-name=libasan.a
```

`-print-file-name=X` prints a resolved path when the toolchain has `X` and echoes
the bare name when it does not. A bare `libasan.a` therefore means the cross
toolchain ships no static ASan runtime; the harness writes
`build-aarch64/asan/PREFLIGHT.txt` with `verdict : NOT-AVAILABLE`, builds
nothing, and exits 77. `scripts/stage-board.sh --asan` reads that verdict and
refuses to stage, because staging nothing and returning 0 would read downstream
as "the board ASan leg ran".

### Verdict recorded on 2026-09-05

```text
command  : aarch64-linux-gnu-gcc -print-file-name=libasan.a
output   : libasan.a
compiler : aarch64-linux-gnu-gcc (GCC) 16.1.0
verdict  : NOT-AVAILABLE
```

The toolchain on the development host carries **no** aarch64 sanitizer runtimes
at all — `libasan.a`, `libasan.so`, `libtsan.a`, `libubsan.a` and `libubsan.so`
all echo back as bare names. Consequences, stated plainly so no downstream row
overclaims:

- The board-ASan leg is **NOT-AVAILABLE** on this host.
- Every ASan row on this branch is **host-shim-only**.
- The concurrency work in the Wave-D reproducer series records its board rows as
  `host-shim-only`, not as board sanitizer results.

The verdict is a property of the *host toolchain*, not of the project. Install a
cross toolchain that carries `libasan.a` and `--asan` builds and stages; the
preflight is re-run on every invocation and never cached.

## Contracts for the reproducer series

Two discovery contracts, so a new reproducer is picked up with no edit to any
script:

| Where the reproducer goes | What picks it up |
|---|---|
| A Meson test registered in the **`concurrency`** suite | the TSan leg of `ci/sanitizers-steps.sh` |
| A self-contained C file in **`tests/repro/`** | `scripts/cross-build-harness.sh --asan`, if the preflight passes |

Until a `concurrency` test exists the TSan leg runs the canary and **says** that
zero concurrency tests ran. A green leg that executed nothing is the failure mode
this job was rebuilt to remove.

## The analyzer

`scripts/run-analyzer.sh` writes the raw compiler output to
`test-results/analyzer.txt`, the normalised hit list to
`test-results/analyzer-hits.txt`, and reconciles every hit against
[`ANALYZER-TRIAGE.md`](ANALYZER-TRIAGE.md). Both output files are gitignored; the
triage is the committed record.

`meson.build` compiles the library with a blanket `-w`, and GCC's `-w` sets a
global inhibit flag checked when a diagnostic is *emitted* — so it silences every
`-Wanalyzer-*` finding no matter where `-fanalyzer` sits on the command line.
`-Danalyzer=true` drops that one flag for the library targets and nothing else.
The option defaults to `false`, so no other build in this repository changes.

Only the shipped shared library is analysed. Building everything would feed
`-fanalyzer` to the C++ test sources, which compile with `-Werror`; a finding in
non-shipped scaffolding would abort the run instead of being reported.

Reconciliation is keyed on **(source file, warning name)**, deliberately not on
line number: a line moves with every edit above it, and a triage list that goes
stale on unrelated churn gets rubber-stamped instead of read. The job is
advisory; `ANALYZER_STRICT=1` makes an untriaged hit fail, which is how it becomes
a gate once the backlog reaches zero.
