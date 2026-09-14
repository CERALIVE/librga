# OSD layout: confirmed, unreachable in the CeraLive call set

**Disposition (todo 37): librga-side layout divergence, confirmed against the
island UAPI; unreachable in the current CeraLive call set; deferred to a future
major version where an ABI break is permissible.** No public layout is changed.

This is the owner's explicitly authorized third terminal outcome. The plan's
two literal outcomes were unavailable: swapping the public members violates D29,
and calling this island-side contradicts the island's consistent named register
writes and readback. This is a bounded limitation, not universal OSD correctness.

## Coordinate and offsets

Island [`v2026.9.3`, `b9602a0a49432817c0689ce90b83590b7e52d5b4`](https://github.com/CERALIVE/rk3588-media-island/commit/b9602a0a49432817c0689ce90b83590b7e52d5b4),
`drivers/video/rockchip/rga3/include/rga.h`, compared with librga `5dfe897`
and unchanged public headers at execution base `f04a90e`:

| `rga_osd_info` member | Island offset | librga offset |
|---|---:|---:|
| `last_flags0` | 40 | 44 |
| `last_flags1` | 44 | 40 |
| `cur_flags0` | 48 | 52 |
| `cur_flags1` | 52 | 48 |

The island register implementation is
[`drivers/video/rockchip/rga3/rga2_reg_info.c`](https://github.com/CERALIVE/rk3588-media-island/blob/b9602a0a49432817c0689ce90b83590b7e52d5b4/drivers/video/rockchip/rga3/rga2_reg_info.c).
The existing parity comparator pins all four exact pairs in
`tests/uapi-parity/compare.py:116-140`; changing either side still fails. It is
not weakened or removed by this disposition. The automated header pin remains
`v2026.9.2`; the separate `v2026.9.3` comparison does not silently bump it.

## Reachability proof

Consumer revisions inspected:

- `CERALIVE/cerastream`: `100e84e672d21a2d38ffc7234bec2f78ad24fe4a`.
- `CERALIVE/gstreamer-rockchip`: `f8960191ea14360347ceb9b96b6dce72f26b743d`.

Source coordinates below are within those repositories, not filesystem links.

1. Engine `crates/cerastream-hal/src/capture_normalization.rs:32-105` selects
   `rgaconvert`. `crates/cerastream/src/engine/composition.rs:29-203` selects
   `rgacompositor`. MPP conversion reaches the same plugin backend.
2. Plugin `gst/rockchiprga/gstrgaconvert.c:893-917` constructs a usage mask from
   zero, adding only fixed rotation/flip bits. The request is zero-initialized
   at `:929`, and receives that mask at `:1052`. No raw operator integer is
   passed as a usage mask. Colorimetry has separate fields, not usage-bit input.
3. Plugin `gst/rockchipmpp/gstmpprgabackend.c:165-179` zero-initializes the MPP
   colorimetry request. Ordinary conversion at `:197-235` passes
   `request->usage | IM_SYNC` to `improcess`. The compositor entry `:238-286`
   passes `transform->usage | IM_SYNC`; its caller in
   `gst/rockchiprga/gstrgacompositor.c:750-753` constructs only
   `IM_ALPHA_BLEND_DST_OVER` or `IM_ALPHA_BLEND_SRC_OVER`, plus
   `IM_ALPHA_BLEND_PRE_MUL`. A BGRA overlay blend is **not** RGA OSD mode.
4. Legacy fallback `gstmpprgabackend.c:76-79` calls `c_RkRgaBlit`.
   `gst/rockchipmpp/gstmpp.c:271-279,327-328` zero-initializes its `rga_info_t`
   objects; setup at `:177-246,307-315` fills addresses/fds, MMU, geometry,
   format/stride and rotation, never `osd_info`.
5. librga `im2d_api/src/im2d_impl.cpp:1823-1829` zeroes `opt`, `srcinfo`,
   `dstinfo`, `patinfo` and `req`. Its OSD writer at `:2009-2070` is guarded by
   `usage & IM_OSD`; only inside it are OSD enabled and `last_flags`/`cur_flags`
   assigned. `generate_blit_req` zeroes its request at `:2614-2617`.
   `core/NormalRga.cpp` copies the embedded `src->osd_info` into the request;
   copying inert zero bytes is not activation or use of the divergent halves.

Neither the im2d nor legacy production route supplies OSD mode or flag data.
This limitation is scoped to these call paths/revisions, not every external
librga user, sample program, or future GStreamer pipeline.

## Validated searches (2026-09-14)

The read-only investigation used the **same patterns** against known-positive
librga implementation and consumer scopes. Counts are matching lines, not calls:

| Pattern | librga `im2d_api/` + `core/` | engine + plugin `gst/` |
|---|---:|---:|
| `IM_OSD` | 66 | 0 |
| `rga_osd_info\|osd_info\|last_flags0\|last_flags1\|cur_flags0\|cur_flags1` | 63 | 0 |
| `improcess\|improcessOpt\|improcessTask` | positive implementation control | 4 |
| `c_RkRgaBlit\|RkRgaBlit\|RgaBlit` | positive implementation control | 3 |

Repeat within each checkout: `rg -n 'IM_OSD' im2d_api core` in librga,
`rg -n 'IM_OSD' crates` in cerastream, and `rg -n 'IM_OSD' gst` in the plugin;
repeat with the second table pattern, without Markdown backslash escapes.
The original sweep excluded docs/tests/samples/build artifacts and targets.
The engine production review covered `cerastream`, `cerastream-core`,
`cerastream-hal` and `cerastream-ipc` crates; plugin review covered
`gst/rockchipmpp` and `gst/rockchiprga`. Positive production call matches and
the mask-construction trace establish that consumer scopes were searched;
the zero is not inferred from an untested guessed spelling.

Any future CeraLive caller adding `IM_OSD`, writing `osd_info`, or exposing a raw
usage mask invalidates this disposition and requires escalation **before**
enabling that path. Do not silently swap members or work around it.
