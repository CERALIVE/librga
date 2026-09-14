# R1 donor semantic-presence audit [EXISTS]

Audited `origin/main` at **`5dfe897d206a52f770137e15553c48f84964cf02`**.
All evidence ranges in the table name that immutable tree, **before this port**.
The four complete diffs were retrieved from the GitHub commits API for
`nyanmisaka/rk-mirrors`; authors below are commit authors, not repository owners.
Verdicts follow call paths and behavior, not SHA membership or patch-id.

## Verdicts

| Donor commit | Author | Subject | Verdict on audited main | Semantic evidence and disposition |
|---|---|---|---|---|
| [`571a880951583a3b2a04e7e1fa900861653befde`](https://github.com/nyanmisaka/rk-mirrors/commit/571a880951583a3b2a04e7e1fa900861653befde) | nyanmisaka | normal: fix setting full_csc of RGA2 | **ABSENT in the donor's legacy path** | `core/NormalRga.cpp:1367-1414`: `RgaBlit` makes full-CSC and ordinary CSC mutually exclusive and passes the entire combined mode to the coefficient selector. `core/NormalRgaApi.cpp:849-890` switches on exact full-CSC values, rejecting a valid low-bit addition. The separate im2d path already has masked, independent CSC setup at `im2d_api/src/im2d_impl.cpp:3522-3574`; that does not fix exported legacy calls. **PICK**, justified by the legacy RED/GREEN below. |
| [`338a5fe165267c4bd0704bac4628e9bb61a7806d`](https://github.com/nyanmisaka/rk-mirrors/commit/338a5fe165267c4bd0704bac4628e9bb61a7806d) | Yu Qiaowei | im2d_api: fix imsetColorSpace() cannot config src1 color space | **PRESENT — upstream-inherited** | `im2d_api/src/im2d_impl.cpp:1638-1793` contains the default/mapping helpers; `2173-2203` includes the pat trigger, pat default, RGB validation, and the source-to-pat plus pat-to-destination combination, with direct conversion when no pat exists. No pick. |
| [`1d330cc28551943bed3380261a5a9c6fbd58ff53`](https://github.com/nyanmisaka/rk-mirrors/commit/1d330cc28551943bed3380261a5a9c6fbd58ff53) | nyanmisaka | normal: fix inverted RGB/BGR order in FBCE of RGA3 | **ABSENT — SKIP, not relevant to the specified driver** | `core/NormalRga.cpp:717-728` goes directly from address logging to format normalization, without a driver-`<1.3.9`/FBCE conditional RGBA/BGRA swap. `core/NormalRgaApi.cpp:112-128` only normalizes shifted format identifiers: it is not an equivalent swap. No reproducer justifies a pick for the island's specified 1.3.11 driver; the host shim also reports 1.3.11 at `tests/shim/fake_rga.c:249-267`. **Reproducer result: NOT RUN / not applicable**, not a pixel pass. |
| [`900f9f0dc702d15536064354f6f1fd77da2719af`](https://github.com/nyanmisaka/rk-mirrors/commit/900f9f0dc702d15536064354f6f1fd77da2719af) | Yu Qiaowei | im2d_api: hardware: remove over-constrained on act_height | **PRESENT — upstream-inherited** | `im2d_api/src/im2d_hardware.h:372-385` allows RGA2-LITE2 input/output `{2880,8192}`; `im2d_api/src/im2d_impl.cpp:585-605` allows RK3506 input `{1280,8192}` and output `{1280,4096}`. Both donor hunks are present; no H8/d5-driven pick is warranted. |

Neither PRESENT finding comes from CeraLive's Wave-E repairs. Both behaviors
already exist at the imported `57a1067a246c71fa6c9a355d1668884fda155dd5` base;
the three affected implementation/header files are unchanged between that base
and audited main. Blame additionally identifies Yu Qiaowei's original commits
for the relevant lines. Wave E repairs scheduler validation, fence consumption,
initialization and lifetime, not these CSC/geometry sites.

## The legacy full-CSC reproducer and its limits

`tests/repro/donor_full_csc.c` refuses to run without `fake_rga_active`, uses
three fake handles and 64x64 NV12/RGBA/NV12 surfaces, and inspects captured
requests from the existing shim. It does not perform pixel conversion.

The legacy path `c_RkRgaBlit` reaches `RgaBlit`, not im2d's separate `rga_blit`.
The existing legacy constants allow a low-bit source CSC together with a
high-bit destination full-CSC selector. `0x200` is the full-only control;
`0x201` combines `yuv2rgb_mode1` with `rgb2yuv_709_full`.

On the unchanged audited main, built directly from its Meson source list with
GCC 16.2.1 (`-shared -fPIC -std=c++14 -DLINUX=1 -fpermissive -pthread`):

```text
mode=0x200 ret=0 captured=1 full_csc=1 yuv2rgb=0 PASS
mode=0x201 ret=-22 captured=0 full_csc=0 yuv2rgb=0 FAIL
```

The separate im2d call is an unchanged-path control. Its packed request mode
is **10**, not the legacy enum's **1**: `IM_YUV_TO_RGB_BT601_FULL` is 2,
and im2d retains `IM_RGB_TO_YUV_BT601_LIMIT` (8) while configuring full-CSC.
This follows `im2d_impl.cpp:3533-3537,3558-3574`, not an assumption that the
two builders have identical mode encoding. An exploratory assertion that
incorrectly expected 1 failed on both base and port and was corrected before
acceptance; it is not evidence for another fix.

The new Meson `donor-full-csc` test runs the legacy regression, the full-only
control and the im2d unchanged-path control against the ordinary shared library.
The RED transcript and final GREEN results are summarized in
[`fix-audit.d/donors.md`](fix-audit.d/donors.md); raw local evidence is under
`test-results/donors/`. The initial direct compile missed the root include path
and did not build; that attempt is not counted as RED.

The completed host-gate results, commands, regeneration hashes and tooling limits
are in [`repro/donor-host-gate.txt`](repro/donor-host-gate.txt).

## Credited port and frozen contracts

Only `571a880` is selected. It was applied with
`git cherry-pick -x --no-commit` and committed with the donor's original author,
author date, subject, Signed-off-by and generated full-SHA credit. The commit
body identifies these bounded CeraLive adaptations:

- Omit the donor's **new** `RGA_NORMAL_DST_FULL_CSC_FIXUP` public-header macro;
  public headers remain unchanged.
- Retain the original unmasked diagnostic argument and literal message text.
- Add the Apache §4(b) modification notice, regression, and donor credits.

No existing API, default, status value or message text is changed. There is no
new matrix or coefficient, and the existing golden fixtures are not regenerated.
The fix changes only legacy request construction for explicit combined CSC.
README, this provenance record and `packaging/copyright` credit nyanmisaka.
No transient donor remote was added: retrieval used the API and a full-SHA URL
fetch into `refs/donors/571a880`; the only configured remote remains `origin`.

The plan's suggested negative QA assumed `571a880` would be PRESENT despite a
patch-id mismatch. That premise is false for the donor's legacy site. The audit
does not fabricate it: im2d's equivalent behavior is present elsewhere while
the legacy call still fails the reproducer. This is exactly why a whole-commit
hash or an exact-text search cannot substitute for tracing the target call path.

This branch is not release approval. The new port received independent APPROVE
`ses_f5e8c52d4ffeK5JdTbtezo6MGB` before its coordinator merge; details and limits
are in [the coordinator receipt](fix-audit.d/coordinator-review.md). Item 47's
R1-versus-R0 `abidiff` criterion and board gates remain separate; this host-only
donor check does not close them.
