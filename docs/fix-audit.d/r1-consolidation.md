### R1 candidate consolidation — 2026-09-13 UTC

Tested merge head: `5778d1b` on `integration/1.10.5-ceralive.1`, based on
`b886777023e0c503134e340be348d6c1b11c8adc`. Native x86_64, GCC 16.2.1
20260810, Meson 1.12.0. This is characterization, not a fix or release approval.

All four original candidate tips were pushed to `origin` before any merge:

| Candidate branch | Original commit | Two-parent integration merge |
|---|---|---|
| `qa/candidate-a-initialization` | `b75213e4267f77fe68ceb78405aa77f4b1e686ae` | `ca19ae2` |
| `qa/candidate-b-shutdown` | `b0ffe9be58f7003c3dd127da5c23496e16eb67a7` | `ef7295b` |
| `qa/candidate-c-scheduler-default` | `fc797c1504e78011200a5422409c78e4921e30ec` | `e912c59` |
| `qa/candidate-d-imsync-error` | `6c167e5015c00eda1ab1aaa3db80b64775f30b2b` | `5778d1b` |

The candidate sources, runners and four original fragments are byte-identical
to their respective tips. The pre-merge bundle verified all four refs and its
`b886777` prerequisite. Candidate E's uncommitted script matched its backup and
was left untouched in the separate shared checkout. No branch was rebased,
squashed or deleted; neither R0 branch nor `main` was changed.

#### Fresh executions

From the checkout root, build both instrumented trees, then invoke each runner
independently (all four return **1**, so do not chain runners with `&&`):

```sh
bash scripts/build-sanitized.sh asan
bash scripts/build-sanitized.sh tsan
bash tests/repro/run-candidate-a.sh
bash tests/repro/run-candidate-b.sh
bash tests/repro/run-candidate-c.sh
bash tests/repro/run-candidate-d.sh
```

- **A — RED:** direct exported `RgaInit` produced TSan reports in 20/20 fresh
  processes; the first process opened eight device fds and retained seven after
  draining eight references. Both 20-process no-op/singleton controls passed.
  Injected hardware-version query failure leaked one fd per call in 1000/1000
  calls through each of real `RgaInit` and `improcess`; successful controls were
  flat. TSan offsets `0x21e69`/`0x21b55` map to `NormalRgaOpen:135/77`.
  This does not establish lost refcount increments or an incomplete-member read.
  The historical `c_RkRgaInit` entry point is a no-op, not the dynamic legacy
  failure path exercised by this direct-init extension.
- **B — RED:** ASan/UBSan deinit had 160/200 sanitizer findings, 40 clean;
  exit had 0/200 findings. TSan deinit and exit each had 200/200 findings.
  Neither batch had invalid runs or other failures. Both owned-reference
  controls printed `before=2 after=1 deinit=0 fd_open=1 blit=0` and exited 0.
  Representative diagnostics are null-context access at `NormalRga.cpp:1494`
  and use of the static singleton mutex during process exit. This demonstrates
  the borrowed-last-reference and unjoined-exit patterns, not broken serial
  refcounting or unsafe independently owned references; a null-context report
  is not evidence of heap use-after-free.
- **C — RED:** five assertions, two failures: fresh default and reset-to-default
  each expected `IM_STATUS_SUCCESS` (1), got `IM_STATUS_ILLEGAL_PARAM` (-4).
  Zero enum value, explicit-core acceptance and unsupported-bit rejection
  controls passed. This is validation inconsistency, not hardware scheduling.
- **D — RED:** all 200 injected `poll` EIO cases left the positive fence fd open
  after `imsync` returned `IM_STATUS_FAILED` (0); all 200 successful waits
  consumed it. The runner verified 200 failing poll records. Cleanup after each
  observation restored the baseline: this is not 200 accumulated leaked fds.
  This is fd-ownership evidence under ASan/UBSan/LSan instrumentation, not a
  sanitizer fd-leak diagnostic or kernel sync-file evidence.

Canaries reported with the instrumented shim preloaded. These observations are
host-shim-only. No board, library fix, full-CSC padding reproduction, two-batch
GREEN, ABI release closure or independent fix-approval receipt is claimed.

Raw evidence is retained in these repo-local, gitignored directories:

| Evidence | Directory |
|---|---|
| A | `test-results/candidate-a/run.gtir1P/` |
| B wrapper / owned-reference controls | `test-results/candidate-b/run.OlWEli/` |
| B ASan/UBSan batch | `test-results/h2/asan/run.9FU7N9/` |
| B TSan batch | `test-results/h2/tsan/run.zaLl1g/` |
| C | `test-results/candidate-c/run.fwsz5o/` |
| D | `test-results/candidate-d/run.Qd2n7G/` |

#### Green baseline, separate from the RED probes

The candidate C runner configured `build-qa` with `-Dlibrga_demo=false` and the
documented x86_64 `-Dcpp_args=-fpermissive`. Subsequent commands and results:

```sh
meson compile -C build-qa
meson test -C build-qa --print-errorlogs
bash packaging/package-contract.sh
ASAN_OPTIONS=detect_leaks=1:verify_asan_link_order=0:abort_on_error=1 \
  UBSAN_OPTIONS=print_stacktrace=1:halt_on_error=1 \
  meson test -C build-asan --print-errorlogs \
  unit-pure unit-session shim-contract goldens
QEMU_LD_PREFIX=/usr/aarch64-linux-gnu meson setup build-parity \
  --cross-file tests/uapi-parity/aarch64.cross -Dlibrga_demo=false
QEMU_LD_PREFIX=/usr/aarch64-linux-gnu \
  meson test -C build-parity --print-errorlogs --suite uapi
bash scripts/run-analyzer.sh
```

- Native baseline: **16/16 OK**, zero failures or skips: both UAPI tests,
  eight goldens, shim contract, both unit tests, wire-bootstrap, board-oracle
  and board-timing. The last two are local oracle/shim tests, not board access.
- ASan/UBSan baseline: **11/11 OK** with leak detection enabled.
- aarch64 UAPI: **2/2 OK**, GCC 16.1.0 emitters executed by local QEMU;
  21 ioctl values, 29 struct sizes and 170 member offsets. The pinned island
  header is `v2026.9.2`, SHA-256
  `ac2f110c8b91ca4ba8de644dd88981560e9681978b99976ec1804654dee1ef35`.
  The native run was only x86_64 smoke; the later cross run regenerated
  `docs/UAPI-PARITY.md` byte-identically to the committed aarch64 record.
- Static package contract: **OK**. No package build or ABI-release test claimed.
- Advisory analyzer: build exit 0, **18 findings**, six file/warning pairs,
  all six already triaged, zero untriaged. This is GCC 16 host evidence, not
  the target-suite GCC 14 CI leg.
- Error-level LSP diagnostics: clean for all five merged C++ reproducers and
  four shell runners; shell syntax checks passed.

The candidate runners are deliberately not registered in Meson; the unchanged
registration contains zero `concurrency` tests. `meson test --list --suite
concurrency` reports no suitable tests, not passing concurrency coverage.
The RED probes were executed separately above, never hidden behind a green gate.
Existing Meson fragments, library sources, public headers and defaults did not
change. This host gate is not a claim that the Debian arm64 release matrix ran.

#### Generated-ledger provenance

Each generated-ledger merge conflict was replaced by running
`bash scripts/wire-bootstrap.sh` against the available source fragments. After
the fourth merge all four fragments were present; no generated rows or appendices
were hand-resolved. This consolidation note is itself a source fragment.
The generator was run again after adding it, then a second invocation was checked
for byte-identical `docs/fix-audit.md` and `meson.build` output. The baseline's
`wire-bootstrap` test also passed its structure, preservation and idempotency
checks. All historical characterization fragments remain unchanged.
