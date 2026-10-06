<!-- Moved verbatim from AGENTS.md on 2026-10-05 by lean-rules-docs-landing-latam -->

## The additive-only principle

The effort's additive-only rule (D29), with the strict-driver availability claim
corrected on 2026-09-16:

> Additive-only (D29): nothing existing is stripped — Android/RT-Thread/other-SoC
> trees, legacy `RockchipRga`/`c_RkRga*` API, every exported symbol, all stay;
> validation changes only accept MORE valid input.

`LIBRGA_STRICT_DRIVER` is not implemented; setting it has no effect. The earlier
"stays as a default-off opt-in" and "already present" wording was false, not a
runtime contract. `rga_check_driver()` retains the upstream version-table policy,
without an environment-dependent branch. This documentation correction adds no
strict mode and changes no caller's runtime behaviour.

The 2026-09-14 owner decision makes one narrow exception to the quoted export
rule: the 18 inherited R1 removals above are accepted with documentation. It is
not authorization to remove any other symbol or source/platform tree.

In practice: the Android and RT-Thread build files stay even though CeraLive
builds with Meson, the CMake tree stays even though we do not use it, chips we
will never ship stay in the format and scheduler tables, and a validation fix may
only widen the accepted input set. Deleting any of it is merge friction against
an upstream we intend to keep syncing from, for no shipped benefit.

