# GCC `-fanalyzer` triage

Every `-Wanalyzer-*` finding this tree produces, with a disposition. A finding
with no row here is reported as `UNTRIAGED` by `scripts/run-analyzer.sh`; a row
here that the current compiler does not reproduce is reported as
`NOT-REPRODUCED-HERE`. Neither is silently dropped.

Run it yourself:

```sh
bash scripts/run-analyzer.sh            # advisory
ANALYZER_STRICT=1 bash scripts/run-analyzer.sh   # fail on an untriaged hit
```

The mechanism — why `-Danalyzer=true` is required, and why only the shipped
library is analysed — is in [`SANITIZERS.md`](SANITIZERS.md).

## Dispositions

Only two values, because the fork's rules allow only two.

- **`noise (why)`** — the analyzer is modelling a path the program cannot take.
  The reason is stated, not asserted.
- **`candidate`** — a real defect or a finding that cannot be dismissed from
  reading alone. It becomes a `docs/fix-audit.md` row **only when a reproducer
  turns RED on the base being fixed**; `AGENTS.md` forbids a fix without one, so
  no row id can be quoted here yet — the ledger is empty by design. A candidate
  is not a licence to patch.

## The runs this table reconciles

| Run | Compiler | Arch | Unique hits |
|---|---|---|---|
| CI / device | `g++ (Debian 14.2.0-19) 14.2.0` | aarch64 | 9 |
| Development host | `g++ (GCC) 16.2.1` | x86_64 | 18 |

The two sets differ and both are kept. GCC 16 explores more paths than GCC 14, and
on x86_64 the `#else` half of the `__aarch64__` guards compiles instead of the
device half. The aarch64/GCC-14 run is the authoritative one for the device; the
x86_64 rows are triaged so a developer's local run is not full of unexplained
findings.

## Table

Keyed on **(source file, warning)** — deliberately not on line number, so an
unrelated edit above a finding does not invalidate the list and get it
rubber-stamped.

| Source | Warning | Hits | Disposition | Why |
|---|---|---|---|---|
| `core/NormalRga.cpp` | `-Wanalyzer-malloc-leak` | 1 | noise | Exception-unwind edge on `open()`. `ctx` is reported as leaking only "if `int open(const char*, int, ...)` throws an exception" — `open` is `extern "C"` libc and cannot throw. GCC models a throwing edge for every call it cannot prove `noexcept`. |
| `core/RgaUtils.cpp` | `-Wanalyzer-file-leak` | 4 | noise | Same edge. The chain ends at "if `int convert_to_rga_format(int)` throws an exception… unwinding 2 stack frames"; `convert_to_rga_format` (`core/utils/utils.cpp:167`) is a pure `switch` over an int and cannot throw. Every normal return in these four functions calls `fclose`. |
| `core/RgaUtils.cpp` | `-Wanalyzer-malloc-leak` | 4 | noise | The same four `fopen` results, reported a second time under the generic allocator warning. Same non-throwing call, same conclusion. |
| `/usr/include/c++/14/bits/new_allocator.h` | `-Wanalyzer-malloc-leak` | 1 | noise | Reported inside libstdc++, but the chain names `core/utils/drm_utils/src/drm_utils.cpp:130` — a file-scope `std::unordered_map`. Its bucket array is freed by the static destructor registered through `__cxa_atexit`, which the analyzer does not model, so every static-storage container looks like a leak. Path contains the compiler version; a GCC bump makes this row `NOT-REPRODUCED-HERE` until it is re-keyed. |
| `im2d_api/src/im2d_impl.cpp` | `-Wanalyzer-possible-null-dereference` | 4 | candidate | Genuine unchecked `malloc`. `rga_generate_gauss_coe` allocates `kernel` (1616) and `coe` (1627) and checks neither before writing through them — `generate_gaussian_kernel` stores `kernel[index]` at 1564, `rga_get_gaussian_special_points` stores `special_points[index]` at 1576/1582. On allocation failure this is a NULL store, not a graceful failure. |
| `im2d_api/src/im2d_impl.cpp` | `-Wanalyzer-use-of-uninitialized-value` | 3 | candidate | Two distinct findings. (a) `gcd` at 1147: the `GET_GCD` macro (1147 via `im2d_impl.cpp:54`) assigns `gcd` **only inside** `if ((n1)%i==0 && (n2)%i==0)`, and its loop `for (i = 1; i <= n1 && i <= n2; i++)` does not execute at all when either argument is `< 1` — the macro then returns the caller's uninitialized `gcd`, which `GET_LCM` immediately divides by. (b) 1564/1576: the same unchecked-`malloc` sites as the row above, seen as reads of uninitialized heap. |
| `im2d_api/src/im2d_impl.cpp` | `-Wanalyzer-malloc-leak` | 2 | candidate | Two distinct findings. (a) `job` at 2415 leaks "if `rga_map_insert_job` throws" — unlike the rows above this call **can** throw: `im2d_job.cpp:120` calls `job_map->emplace(...)`, which raises `std::bad_alloc`. Reachable only under allocation failure, and librga is not exception-safe anywhere, so the scope of any fix needs deciding before it is written. (b) `kernel` at 1635 looks like an analyzer state merge — the `free(kernel)` at 1631-1632 is guarded by the identical `gauss->matrix == NULL` predicate that selected the `malloc` at 1616, so no single path both allocates and skips the free. Left as a candidate rather than dismissed, because "looks like" is not a proof. |

## Notes for the reproducer series

- The gaussian rows (`rga_generate_gauss_coe` and its two callees) sit behind the
  `imgauss` entry point. CeraLive's plugin path does not call it. That makes them
  **low priority, not noise** — the code ships, and an unchecked `malloc` reached
  by any caller is a defect regardless of who calls it.
- `GET_GCD` is the one finding that is a defect in a *macro*, so a fix touches
  every caller of it at once. Treat its blast radius as larger than its two lines
  suggest.
- Nothing in this table may be fixed on the strength of this table. The rule is
  unchanged: a RED reproducer transcript on the base being fixed, or it is a
  ledger note and nothing else.
