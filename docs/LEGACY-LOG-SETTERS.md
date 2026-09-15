# Use diagnostics without the legacy logging setters

## Decision: retain and honestly deprecate

`RkRgaSetLogOnceFlag(int)` and `RkRgaSetAlwaysLogFlag(bool)` are compatibility
no-ops for logging [EXISTS]. Their signatures, inline assignments and member
layout stay intact. They do not enable or disable diagnostics. This is a
documentation deprecation, not a compiler warning, runtime warning or removal.
Use the [existing Linux diagnostic controls](API-TRAPS.md#environment-logging-and-the-legacy-api)
instead. This change resolves an ambiguous contract; it does not repair wiring.

The 2026-09-15 owner-directed scope offered reconnection or honest deprecation.
This chooses deprecation under D29 for the following reasons:

- A silent no-op advertised as diagnostic control is misleading. Leaving its
  meaning undocumented is not acceptable. Explicitly naming its inert behavior
  and testing a working alternative removes that trap without changing output.
- Reconnection would restore the apparent intent, but requires choosing scope,
  one-shot consumption, lifetime and precedence semantics that the existing
  implementation does not supply. Linux operation logging and Android palette
  logging are not one shared switch. Making the setters live is observable to
  callers that currently receive no output, with output-volume and timing risks.
- The supplied caller survey found no CeraLive-package or indexed public-source
  caller, validated against `c_RkRgaBlit` as a positive search control. That is not
  proof about private binaries. No known caller means both low known regression
  risk **and no current fleet workflow repaired by reconnection**. In a frozen
  legacy API, that favors a documented compatibility contract rather than new
  semantics without a consumer requirement.
- These setters are inline in the public header. Replacing their bodies with new
  controls would also make behavior depend on consumer recompilation. Keeping
  their bodies avoids an old-header/new-header split.

D29's runtime boundaries remain unchanged: public API, defaults, messages,
`IM_STATUS`, class/struct layouts, SONAME, symbol visibility and bindings. The
696-byte `rga_info_t` and 304-byte `im_opt_t` assertions, exact 18-entry ABI
removal allowlist and `PACKAGED_LTO=false` are untouched. No release, device
installation or hardware qualification is implied.

## Two objects, not two names for one flag

| Storage | Writer | Logging reader |
|---|---|---|
| `RockchipRga::mLogOnce`, `RockchipRga::mLogAlways` | The inline public setters | None |
| `rgaContext::mLogOnce`, `rgaContext::mLogAlways` in `NormalRgaContext.h` | Separate context state; palette resets `mLogOnce` | Android `NormalRgaPaletteTable` |
| `rgaContext::Is_debug` | `is_debug_log()` via `get_int_property()` | Core operation diagnostics via `is_out_log()` |

On Linux, `get_int_property()` reads `ROCKCHIP_RGA_LOG`; on Android it reads
`vendor.rga.log`. Neither public setter controls that source. Do not cast an
instance flag into the context or rename the context flags as a cosmetic fix.
Android's palette reads and one-shot reset must remain independent.

## Verification boundary

The earlier `legacy-once` and `legacy-always` probes deliberately failed their
positive-output assertion before and after the stderr migration. Those historical
RED results remain evidence of the misleading contract, not unexplained current
failures. The owner-selected deprecation contract replaces that expectation with
mandatory silence assertions and positive diagnostic controls, preserving operation
success and stdout checks. It does not mark expected failures as passing.

Android preservation is a source/executable-input comparison against the base:
the palette implementation, context declaration, platform build inputs and
logging implementation remain unchanged; the public header gains comments only.
This is not an Android build, runtime or hardware qualification claim.

Run both deprecation probes through the normal gate:

```bash
meson test -C build unit-logging-deprecated-legacy-once \
  unit-logging-deprecated-legacy-always --print-errorlogs
```

Each probe constructs the instance before capture, checks successful fills twice
per setter value (`1`, `0`, `-1`, `2`), and requires both stdout and stderr to stay
empty. Context sentinels prove the similarly named fields are neither written nor
consumed by these setters. Separate captures require `ROCKCHIP_RGA_LOG=1` to emit
operation diagnostics despite a zero setter, `ROCKCHIP_RGA_LOG=0` to remain quiet
despite a nonzero setter, and `RkRgaLogOutUserPara()` to emit with logging disabled.
Both modes fail closed without the fake-device shim. Existing constructor, macro,
failure-diagnostic and Gaussian tests remain unchanged.
