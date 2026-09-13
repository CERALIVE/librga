# API traps

Things about this library's public API that are easy to get wrong, hard to notice
when you do, and not stated plainly in the upstream developer guide. Every entry
here is a property of the API as shipped, not a defect being tracked. Defects live
in [`fix-audit.md`](fix-audit.md); this file is what a caller needs before writing
the first line.

Read this before adding an im2d call to a consumer.

## Argument units

- **Stride arguments are in PIXELS, not bytes.** `wrapbuffer_virtualaddr`,
  `wrapbuffer_fd`, and the `_t` struct forms all take `wstride`/`hstride` as pixel
  counts; passing a byte pitch silently describes a much wider buffer and the blit
  reads or writes far past the intended rows.
- **`get_perPixel_stride_from_format` returns BITS per pixel, not bytes.** Its
  name reads like a stride helper and it is not one — the value must be divided by
  8 before it can be combined with anything measured in bytes, and using it raw
  inflates every derived size by a factor of eight.
- **`RK_FORMAT_*` constants are the driver's format enum shifted left by 8.** The
  userspace constant and the raw driver value are therefore never equal; comparing
  an `RK_FORMAT_*` value against a number read out of a driver structure, or vice
  versa, fails for every format unless one side is shifted.

## Return values and status

- **`IM_STATUS` mixes positive and negative values.** Success is a positive
  `IM_STATUS_SUCCESS` (1) while errors are negative, so the usual C idioms
  `if (ret)`, `if (ret < 0)` alone, and `if (!ret)` each misclassify part of the
  range. Compare against `IM_STATUS_SUCCESS` explicitly.
- **`wrapbuffer_fd` is a variadic macro that returns a zeroed buffer when called
  with the wrong number of arguments.** There is no compile error and no runtime
  complaint; the call simply yields an all-zero `rga_buffer_t` that fails later,
  somewhere else, for a reason that looks unrelated.

## Configuration and threading

- **`imconfig` state is THREAD-LOCAL.** Scheduler core, priority, and the other
  configurable knobs apply only to the thread that called `imconfig`, so
  configuration must happen on the same thread that will later call `improcess`.
  Configuring once at startup and then processing on a worker thread silently runs
  with defaults.
- **`IM_SCHEDULER_DEFAULT` (0) is rejected by argument validation.** The value
  that reads like "leave it alone" is not accepted by the scheduler-core check, so
  passing it fails the call rather than selecting the default. Until that
  validation is widened, pass an explicit core mask.

## Environment, logging, and the legacy API

- **`ROCKCHIP_RGA_LOG` is the only environment knob the library reads.** There is
  no other supported environment variable for log level or behaviour; anything
  else found in samples or downstream trees does nothing here.
- **The library logs to stdout until R1.** Diagnostic output lands on the calling
  process's standard output rather than stderr or a log facility, which matters
  for any consumer that parses its own stdout.
- **The legacy `RockchipRga` / `c_RkRga*` API has been frozen since 1.10.3 and
  prints a deprecation notice at init since 1.10.5.** It still works and it is
  never removed — the additive-only rule keeps every legacy symbol exported — but
  it receives no new capability, and new consumer code uses the im2d API instead.
