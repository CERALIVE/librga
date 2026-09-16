# PR 9 review round five — logging suppression

The fifth review, by **Oracle**, model **openai/gpt-5.6-sol**, rejected the
logging changes at `56bac09`. This records the supplied rejection, not an
independent approval of the follow-up fixes.

## Failing-first evidence and bounded fixes

Before changing production code, the new captured-output assertions failed on
`56bac09`: `unit-logging-no-device` and `unit-logging-fake-device` each reported
six failures (constructor notice and selected legacy severities at thresholds
0 and 6). `unit-gaussian-logging` reported six framing failures; its value
assertions passed. The run is preserved in `test-results/logging-red-build.log`.

Removing both added im2d gates from `ALOGI`/`ALOGD` restores their original
unconditional macro behavior, while retaining stderr, the `librga:` prefix and
every enriched message. Gaussian framing now uses `IM_LOG_ENABLED`, the same
predicate used by all `IM_LOG` implementations: enable plus threshold, OR error,
OR force. No log defaults or error-message-storage behavior changed. Both stale
flag comments now describe the actual sink and direct-output behavior.

The focused post-fix run passed all three tests with zero skips. Its transcript
is `test-results/logging-green-tests.log`. These are host-shim observations,
not hardware validation. No H10 launcher, signature, layout, visibility, SONAME
or `IM_STATUS` definition changed.

## Historical public-setter acceptance gap

**2026-09-15 disposition:** the owner-directed separate scope selected honest
deprecation, not reconnection. The header now explicitly documents both methods
as compatibility no-ops for logging. `legacy-once` and `legacy-always` are mandatory
Meson tests of that deliberate contract, with repeated operations, zero/nonzero
values, distinct context-state sentinels and positive environment/direct-dump
controls. The original positive-output assertion is replaced under this explicit
contract decision, not waived as an expected failure. The historical RED evidence
below remains unchanged; it is not a current unexplained failing probe. See
[`LEGACY-LOG-SETTERS.md`](../LEGACY-LOG-SETTERS.md) for the D29 rationale.

The review's setter explanation conflated two different fields. The inline
`RkRgaSetLogOnceFlag` and `RkRgaSetAlwaysLogFlag` write private members of
`RockchipRga`; no implementation reads those members. The similarly named
`rgaContext` fields are a different object, used by the Android palette path.
Linux operations select debug output through `is_debug_log()` / `is_out_log()`.
This wiring is identical in `e5f3fc0^`, before todo 36, and in `56bac09`.

Two explicit modes of `unit-logging` preserve the requested positive-output
assertion: `legacy-once` and `legacy-always`. Both were run before the macro
change with `ROCKCHIP_RGA_LOG` unset and the fake device preloaded. Each reported
9 assertions, 1 failure: `requested operation diagnostic emitted`. Device
initialization and the fill succeeded; global logging stayed disabled and
stdout stayed empty. Construction happens outside the capture, so its notice
cannot disguise the missing operation diagnostic. The modes refuse to run
without the shim and are not registered as green Meson tests.

Reconnecting these setters is a separate behavioral change, not a stderr
redirection repair. It was not implemented; in particular, no setter now writes
the global enable state. The requested setter-success acceptance criterion is
**not met** and requires a scope decision. No failing assertion was inverted or
removed to make the gate pass.

## Todo 36 call-site walk

Reviewed every production hunk of `e5f3fc0` against its parent:

- `NormalRgaContext.h`: the only newly gated legacy macros; now unconditional.
  The constructor uses `ALOGI`; operation `ALOGD` calls retain their existing
  call-site predicates. Android's system ALOG definitions are untouched.
- `im2d_debugger.cpp`: the two newly gated framing writes; now share the value
  predicate, including force from `rga_dump_opt()` and unforced errors.
- `im2d_log.h`: stdout-to-stderr sink replacement retained the existing
  enable/error/force predicate and error-message update conditions. The shared
  predicate preserves that behavior (Android error priority is also 6).
- `NormalRga.cpp`, `NormalRgaApi.cpp`, `im2d_impl.cpp`: direct diagnostic
  replacements remain unconditional inside the same branches; geometry
  enrichment remains intact. The palette ioctl failure retained its identical
  unconditional ALOGE diagnostic after removal of the duplicate printf.
- `RgaUtils.cpp`, `RockchipRga.cpp`, `GrallocOps.cpp`: format, file, DRM and
  gralloc diagnostic conditions are unchanged; context and errno additions stay.
- `im2d_buffer.h`, `im2d_common.h`, `im2d_single.h`: public C overload-error
  branches still emit unconditionally, preserving their message substrings.
- `im2d_context.cpp`: RT-Thread device errors now use IM_LOGE; the error bypass
  keeps them unconditional even when global logging is disabled.

The existing 62-row ledger and historical review receipts remain unchanged;
this appendix does not manufacture an approval receipt or waive release gates.
