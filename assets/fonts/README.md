# Font assets / 字体资产

Setup, atlas generation, and release requirements:
[English](../../docs/LOCALISATION.en.md#6-fonts-atlases-and-release-assets) ·
[中文](../../docs/LOCALISATION.zh-CN.md#6-字体图集与发布资源).

| File | Use | Licence |
| --- | --- | --- |
| `NotoSansSC-VF.ttf` | `zh-CN`, `zh-TW` | [OFL](../../docs/licenses/NotoSansSC-OFL.txt) |
| `NotoSansJP-VF.ttf` | `ja-JP` | [OFL](../../docs/licenses/NotoSansJP-OFL.txt) |
| `NotoSansKR-VF.ttf` | `ko-KR` | [OFL](../../docs/licenses/NotoSansKR-OFL.txt) |
| `NotoSansCJKkr-Regular.otf` | Alternative asset; not selected by the runtime or included in the font release manifest | [OFL](../../docs/licenses/NotoSansCJKkr-OFL.txt) |

The VF sources are the Google Fonts repository paths
`ofl/notosanssc/NotoSansSC[wght].ttf`,
`ofl/notosansjp/NotoSansJP[wght].ttf`, and
`ofl/notosanskr/NotoSansKR[wght].ttf`.
The alternative OTF is the unchanged Regular face from the supplied
`07_NotoSansCJKkr.zip`, family `Noto Sans CJK KR`, version 2.004.
Other weights from that archive are not included.

| File | SHA-256 |
| --- | --- |
| `NotoSansSC-VF.ttf` | `A3041811A78C361B1DE50F953C805E0244951C21C5BD412F7232EF0D899AF0DA` |
| `NotoSansJP-VF.ttf` | `C2F3B4D463500A2DDCD3849CDED1FCEEB9FD6D1C32E6CBECD568453BA50FC68F` |
| `NotoSansKR-VF.ttf` | `194018E6B2B293A7964F037B25C0249CE1418BC9AB3C971060A03AA57861E252` |
| `NotoSansCJKkr-Regular.otf` | `6BCB2A0703AA137E874FC2DFFA85F6C21BA9A67FA329E81B8C801663AF7E992A` |

Source archive SHA-256:
`E26FCF98E75176D24984875377AB921DBB46055B88ED4A39454D91D6146C5654`.
