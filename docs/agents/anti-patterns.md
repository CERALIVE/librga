<!-- Moved verbatim from AGENTS.md on 2026-10-05 by lean-rules-docs-landing-latam -->

## Anti-patterns

- Do not change the default colour matrix, the default interpolation mode, or the
  default log level. Both are behaviour divergence for every caller.
- Do not remove an exported symbol, change a public struct's layout, or touch the
  SONAME, the pkg-config name, or symbol visibility.
- Do not delete the Android, RT-Thread, CMake, or other-SoC trees, and do not
  delete the legacy `RockchipRga` / `c_RkRga*` API. Additive-only means additive.
- Do not write a fix without a RED reproducer transcript **on the base being
  fixed**. A RED only on the Radxa or R0 rows does not authorize a change to R1.
  A harness that will not build is `NOT-REPRODUCED` and becomes a ledger note,
  never a fix.
- Do not merge a fix without an `APPROVE` receipt from an independent reviewer
  carrying a session id. `GAP:` is not an acceptable ledger value for a landed
  fix.
- Do not claim sanitizer coverage on the board. TSan, ASan and UBSan are
  host-shim-only.
- Do not squash a fix-series or upstream-sync PR, and do not self-merge one.
- Do not add CeraLive packaging under `debian/`, and do not execute it.
- Do not add a consumer stopgap for the thread-local `imconfig` behaviour. The
  plugin already reconfigures on the calling streaming thread before every
  `improcess`; patching it is patching a non-defect.
- Do not take "while I'm here" fixes from the audit ledgers — over-strict format
  tables, size math, allocation rows, task-API rows — unless that row's own
  reproducer is RED.
- Do not reformat, do not modernize to `#pragma once` or C++17, and do not run a
  whitespace sweep. Every one of those is merge friction against an upstream we
  keep syncing from.
- Do not do 10-bit work here, and do not touch the kernel, the media island,
  `rk3588-kernel-patches`, `cerastream`, or `CeraUI`. A librga row that needs a
  driver change is STOP-and-surface to the island track.
- Do not name a credentials path, a workspace-parent path, or any path above the
  repository root in a tracked file.
