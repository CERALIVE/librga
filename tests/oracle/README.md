# Independent 8-bit colour reference

`oracle.c` has no librga headers, lookup tables, conversion helpers, or copied
implementation. It uses normalized R'G'B' and the standard luma coefficients:
BT.601 Kr=.299, Kb=.114; BT.709 Kr=.2126, Kb=.0722; Kg=1-Kr-Kb.
Cb=(B'-Y')/[2(1-Kb)] and Cr=(R'-Y')/[2(1-Kr)]. Limited-range luma uses
16+219Y', chroma 128+224C; full range uses 255Y' and 128+255C. Inversion
uses the same definitions, not an implementation-specific integer CSC table.
Values round to nearest integer (half upward for nonnegative output), saturating
to 0..255. No transfer-function linearization is intended: these are video codes.

The resampler operates on a single plane/channel with explicit row and pixel
strides. Box integrates area overlap; bilinear uses pixel-centre coordinates and
clamped edges. Callers provide nonzero, positive dimensions and valid buffers.
The bench averages each 2x2 RGB chroma block after per-pixel quantization, allowing
small PSNR differences from hardware rounding/chroma phase without bending CSC.
NV16 chroma reduction uses the same plane resampler; NV12 scale treats Y/U/V as
separate grids. Crop and rotation preserve code values.

`oracle-test` checks an 8x8 eight-colour pattern against literal hand-computed
BT.601/BT.709 limited-range YUV values (PSNR=∞), full-range red anchors, both-range
inverse conversion (within two codes), and independently specified box/bilinear
downsample values. A deliberate pixel perturbation must produce finite PSNR;
an empty sample returns NaN rather than success. PSNR measures all supplied bytes
with peak 255; callers exclude padding. These tests require no RGA device.
