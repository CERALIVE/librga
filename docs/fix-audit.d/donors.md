| status=GREEN fix=4449f5fa8d901e9d7d08ac078a8479d4619b97b2; `4449f5f` — constrained port of donor `571a880951583a3b2a04e7e1fa900861653befde` | `tests/repro/donor_full_csc.c`: RED on `5dfe897`, legacy mode 0x201 returns -22 before submission; GREEN after port, returns 0 and captures full_csc=1/yuv2rgb=1; 0x200 and separate im2d controls pass on both; `test-results/donors/red.txt` and `csc-green.txt` | host-shim-only; no board or pixel claim | Public headers unchanged; host gates recorded separately; no R1-versus-R0 release ABI closure claimed | author=Sisyphus-Junior/openai/gpt-6-astra reviewer=explore/openai/gpt-5.6-luna-fast verdict=APPROVE ses_f5e8c52d4ffeK5JdTbtezo6MGB; Historical review: PENDING independent review; do not merge this port into integration until an APPROVE receipt is recorded | donor (nyanmisaka); full SHA credited by cherry-pick -x |
| status=OBSERVATION fix=none; Donor `338a5fe165267c4bd0704bac4628e9bb61a7806d`; no new fix | PRESENT in audited main; source/pat/destination CSC at `im2d_api/src/im2d_impl.cpp:2173-2203`; inherited at `57a1067`, not Wave E | Static semantic audit; no board command | Not applicable: no change | reviewer=explore/openai/gpt-5.6-luna-fast verdict=APPROVE ses_f5e8c52d4ffeK5JdTbtezo6MGB; evidence-only; Historical review: Not applicable: no pick | Upstream-inherited, Yu Qiaowei |
| status=SKIPPED fix=none; Donor `1d330cc28551943bed3380261a5a9c6fbd58ff53`; no fix | ABSENT at `core/NormalRga.cpp:717-728` in audited main; SKIPPED for specified driver 1.3.11, outside donor's less-than-1.3.9 condition; reproducer NOT RUN, no justification | No hardware or pixel result claimed | Not applicable: no change | reviewer=explore/openai/gpt-5.6-luna-fast verdict=APPROVE ses_f5e8c52d4ffeK5JdTbtezo6MGB; evidence-only; Historical review: Not applicable: no pick | donor (nyanmisaka), not picked |
| status=OBSERVATION fix=none; Donor `900f9f0dc702d15536064354f6f1fd77da2719af`; no new fix | PRESENT in audited main; `im2d_api/src/im2d_hardware.h:372-385` and `im2d_api/src/im2d_impl.cpp:585-605`; both relaxed height limits inherited at `57a1067`, not Wave E | Static semantic audit; no board command | Not applicable: no change | reviewer=explore/openai/gpt-5.6-luna-fast verdict=APPROVE ses_f5e8c52d4ffeK5JdTbtezo6MGB; evidence-only; Historical review: Not applicable: no pick | Upstream-inherited, Yu Qiaowei |

### Donor audit scope

All table ranges identify audited main `5dfe897d206a52f770137e15553c48f84964cf02`,
before the legacy CSC port. See [DONORS.md](../DONORS.md) for the four complete
semantic verdicts, authors, donor links and adaptations. Only the legacy
`RgaBlit` defect is repaired; im2d's distinct `rga_blit` already has independent,
masked full-CSC setup and is an unchanged-path control.

The `0x201` RED is a real compiled and executed rejection, not a missing-text
search or a compile failure. Initial exploration omitted `-I.` from a direct
build and incorrectly assumed im2d and legacy mode encodings matched; neither
attempt is counted as defect proof. Corrected controls follow each builder's
actual encoding. Raw final reproduction:

```text
audited main:
mode=0x200 ret=0 captured=1 full_csc=1 yuv2rgb=0 PASS
mode=0x201 ret=-22 captured=0 full_csc=0 yuv2rgb=0 FAIL
improcess src601full+patRGB+dst709full status=1 captured=1 full_csc=1 yuv2rgb=10 PASS

ported legacy path:
mode=0x200 ret=0 captured=1 full_csc=1 yuv2rgb=0 PASS
mode=0x201 ret=0 captured=1 full_csc=1 yuv2rgb=1 PASS
improcess src601full+patRGB+dst709full status=1 captured=1 full_csc=1 yuv2rgb=10 PASS
```

At the original todo-39 recording the port was not independently approved.
The current receipt above records its later independent review and coordinator
integration; [the review reconciliation](coordinator-review.md) preserves that
sequence. No pre-existing Wave-E receipt was reused to approve this new code,
and neither the review nor integration is R1 release authorization.
