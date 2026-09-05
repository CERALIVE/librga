# multi_rga UAPI parity

**Generated file. Do not edit by hand.** Produced by `tests/uapi-parity/compare.py --emit-doc` and refreshed by the `uapi-parity` Meson test.

This fork talks to the RK3588 `multi_rga` driver through a private ioctl ABI. Nothing in the compiler, the linker, or the packaging notices when the driver moves a field and librga does not: the mismatch shows up as a corrupt blit or a silently ignored parameter on a board. This gate makes that failure a build failure instead. It compiles the island's own driver header and librga's own headers as two independent translation units at the target ABI, then compares every ioctl number, struct size, and member offset the two have in common.

## Pinned island coordinate

| Field | Value |
| --- | --- |
| Repository | `CERALIVE/rk3588-media-island` |
| Ref | `v2026.9.2` |
| Header path | `drivers/video/rockchip/rga3/include/rga.h` |
| SHA-256 | `ac2f110c8b91ca4ba8de644dd88981560e9681978b99976ec1804654dee1ef35` |

The ref is a published release tag, never a branch: a branch would move under the pin and silently change what this gate asserts. The header is fetched from `raw.githubusercontent.com` and rejected unless its bytes hash to the value above, so no local checkout of the island is read or required.

## This run

- Target ABI: **aarch64**
- Emitters executed via: meson-exe-wrapper: /usr/bin/qemu-aarch64
- ioctl values compared: **21**
- struct sizes compared: **29**
- member offsets compared: **170**
- Result: **PASS**

## ioctl numbers

| Symbol | Value | Hex |
| --- | --- | --- |
| `RGA2_GET_RESULT` | 24602 | `0x601a` |
| `RGA2_GET_VERSION` | 24603 | `0x601b` |
| `RGA_BLIT_ASYNC` | 20504 | `0x5018` |
| `RGA_BLIT_SYNC` | 20503 | `0x5017` |
| `RGA_FLUSH` | 20505 | `0x5019` |
| `RGA_GET_RESULT` | 20506 | `0x501a` |
| `RGA_GET_VERSION` | 20507 | `0x501b` |
| `RGA_HW_SIZE` | 5 | `0x5` |
| `RGA_IOC_GET_DRVIER_VERSION` | 2149347841 | `0x801c7201` |
| `RGA_IOC_GET_HW_VERSION` | 2156950018 | `0x80907202` |
| `RGA_IOC_IMPORT_BUFFER` | 3222303235 | `0xc0107203` |
| `RGA_IOC_MAGIC` | 114 | `0x72` |
| `RGA_IOC_RELEASE_BUFFER` | 1074819588 | `0x40107204` |
| `RGA_IOC_REQUEST_CANCEL` | 3221516808 | `0xc0047208` |
| `RGA_IOC_REQUEST_CONFIG` | 3231216135 | `0xc0987207` |
| `RGA_IOC_REQUEST_CREATE` | 2147774981 | `0x80047205` |
| `RGA_IOC_REQUEST_SUBMIT` | 3231216134 | `0xc0987206` |
| `RGA_SCHED_PRIORITY_DEFAULT` | 0 | `0x0` |
| `RGA_SCHED_PRIORITY_MAX` | 6 | `0x6` |
| `RGA_TASK_NUM_MAX` | 256 | `0x100` |
| `RGA_VERSION_SIZE` | 16 | `0x10` |

## Struct sizes and member offsets

Sizes are bytes at the target ABI. `sizeof(struct rga_req)` is the load-bearing one: it is the request block handed to the driver on every blit.

| Struct | sizeof | members compared |
| --- | --- | --- |
| `rga_buffer_pool` | 16 | 2 |
| `rga_color` (librga `rga_color_t`) | 4 | 3 |
| `rga_color_fill_t` (librga `COLOR_FILL`) | 16 | 2 |
| `rga_csc_clip` | 8 | 2 |
| `rga_csc_coe` (librga `csc_coe_t`) | 12 | 4 |
| `rga_csc_range` | 4 | 2 |
| `rga_external_buffer` | 288 | 5 |
| `rga_fading_t` (librga `FADING`) | 4 | 4 |
| `rga_feature` | 4 | 0 |
| `rga_full_csc` (librga `full_csc_t`) | 40 | 4 |
| `rga_gauss_config` (librga `rga_gauss_config_t`) | 16 | 2 |
| `rga_hw_versions_t` | 144 | 2 |
| `rga_img_info_t` | 56 | 17 |
| `rga_interp` | 1 | 0 |
| `rga_line_draw_t` (librga `line_draw_t`) | 20 | 5 |
| `rga_memory_parm` | 16 | 4 |
| `rga_mmu_t` (librga `MMU`) | 24 | 3 |
| `rga_mosaic_info` (librga `rga_mosaic_info_t`) | 2 | 2 |
| `rga_osd_bpp2` (librga `rga_osd_bpp2_t`) | 12 | 4 |
| `rga_osd_info` (librga `rga_osd_info_t`) | 56 | 10 |
| `rga_osd_invert_factor` (librga `rga_osd_invert_factor_t`) | 6 | 2 |
| `rga_osd_mode_ctrl` (librga `rga_osd_mode_ctrl_t`) | 18 | 13 |
| `rga_point_t` (librga `POINT`) | 4 | 2 |
| `rga_pre_intr_info` (librga `rga_pre_intr_info_t`) | 16 | 7 |
| `rga_rect_t` (librga `RECT`) | 8 | 4 |
| `rga_req` | 504 | 50 |
| `rga_rgba5551_alpha` | 4 | 3 |
| `rga_user_request` | 152 | 8 |
| `rga_version_t` | 28 | 4 |

## Reconciled member renames

The same field, spelled differently on each side. Offsets and widths must still agree exactly; only the identifier differs.

| island | librga |
| --- | --- |
| `rga_buffer_pool.buffers_ptr` | `rga_buffer_pool.buffers` |
| `rga_external_buffer.memory_parm` | `rga_external_buffer.memory_info` |
| `rga_img_info_t.compact_mode` | `rga_img_info_t.is_10b_compact` |

## Declared divergences

Real disagreements, recorded with both sides' current values. These are findings to fix, not exemptions: if either side moves again the recorded pair stops matching and the gate fails.

| Entry | island | librga | Why it is recorded |
| --- | --- | --- | --- |
| `off rga_osd_info.cur_flags0` | 48 | 52 | island declares cur_flags0 before cur_flags1 inside the u64 union; librga declares them the other way round |
| `off rga_osd_info.cur_flags1` | 52 | 48 | mirror of rga_osd_info.cur_flags0 |
| `off rga_osd_info.last_flags0` | 40 | 44 | island declares last_flags0 before last_flags1 inside the u64 union; librga declares them the other way round, so on little-endian the two sides disagree about which half of last_flags each name addresses |
| `off rga_osd_info.last_flags1` | 44 | 40 | mirror of rga_osd_info.last_flags0 |

## Symbols present on one side only

| Symbol | Side | Value | Why |
| --- | --- | --- | --- |
| `RGA_BUFFER_POOL_SIZE_MAX` | island | `0x28` | driver-side cap on one import batch; librga does not expose it |
| `RGA_CACHE_FLUSH` | island | `0x501c` | legacy RGA1 cache-flush command; librga has no caller |
| `RGA_IMPORT_DMA` | island | `0x601d` | legacy RGA2 dma import; librga uses RGA_IOC_IMPORT_BUFFER instead |
| `RGA_RELEASE_DMA` | island | `0x601e` | legacy RGA2 dma release; librga uses RGA_IOC_RELEASE_BUFFER instead |
| `RGA2_BLIT_ASYNC` | librga | `0x6018` | legacy RGA2 blit command retained for pre-multi_rga drivers |
| `RGA2_BLIT_SYNC` | librga | `0x6017` | legacy RGA2 blit command retained for pre-multi_rga drivers |
| `RGA2_FLUSH` | librga | `0x6019` | legacy RGA2 flush command retained for pre-multi_rga drivers |

Their values are pinned here too, so a renumber on either side is caught even though there is nothing to compare it against.

## Regenerating

```sh
# QEMU_LD_PREFIX is for Meson's own configure-time sanity binary, which is
# dynamically linked. The parity emitters themselves are linked -static.
export QEMU_LD_PREFIX=/usr/aarch64-linux-gnu
meson setup build-parity --cross-file tests/uapi-parity/aarch64.cross
meson test -C build-parity uapi-parity uapi-parity-stubs
```

Moving the pin is a deliberate act: edit `tests/uapi-parity/island-pin.env`, re-run `tests/uapi-parity/fetch-island-header.sh`, and record the new SHA-256 in the same commit as the diff that justifies it.
