# PoB2 全域本地化审计

运行范围：当前 PoB2 运行时、4914 个天赋节点、全部装备/技能/召唤物数据、配置文案及 764 个属性描述文件。

命令：在工程根目录运行 `build.cmd`，然后 `python tools/audit-localisation.py`。

“回退”表示输出仍为原英文；“含拉丁字母”表示输出有变化但仍需复核，可能是未翻译片段，也可能是专名、快捷键或格式符。无拉丁字母同样不证明译名准确。统计按数据域内唯一文本计数，明细保留引用次数与定位。

`source.literal-review` 枚举 Classes、Modules 与 Launch 的全部字符串常量（排除注释），包含内部键、路径、调试文字和用户文案；仅作为防漏候选，状态固定为 unclassified，不进行翻译命中统计。函数生成文案与未触发的界面交互仍需真实窗口验收。

| 语言 | 数据域 | 唯一文本 | 回退英文 | 含拉丁字母待复核 | 其余已变化 | 源码待分类 |
|---|---|---:|---:|---:|---:|---:|
| zh-CN | config.label | 637 | 230 | 14 | 393 | 0 |
| zh-CN | config.option | 104 | 14 | 5 | 85 | 0 |
| zh-CN | config.section | 7 | 0 | 1 | 6 | 0 |
| zh-CN | config.tooltip | 238 | 139 | 49 | 50 | 0 |
| zh-CN | flavour.name | 442 | 3 | 0 | 439 | 0 |
| zh-CN | flavour.text | 944 | 905 | 39 | 0 | 0 |
| zh-CN | gem.name | 961 | 4 | 263 | 694 | 0 |
| zh-CN | gem.tag | 52 | 17 | 0 | 35 | 0 |
| zh-CN | gem.type | 12 | 1 | 0 | 11 | 0 |
| zh-CN | item.affix-name | 1494 | 949 | 323 | 222 | 0 |
| zh-CN | item.base | 1753 | 211 | 54 | 1488 | 0 |
| zh-CN | item.implicit | 220 | 9 | 27 | 184 | 0 |
| zh-CN | item.mod | 7581 | 65 | 181 | 7335 | 0 |
| zh-CN | item.subtype | 14 | 3 | 1 | 10 | 0 |
| zh-CN | item.type | 31 | 8 | 0 | 23 | 0 |
| zh-CN | item.unique | 441 | 2 | 0 | 439 | 0 |
| zh-CN | item.unique-mod | 3352 | 57 | 49 | 3246 | 0 |
| zh-CN | minion.category | 5 | 2 | 0 | 3 | 0 |
| zh-CN | minion.name | 579 | 536 | 20 | 23 | 0 |
| zh-CN | skill.description | 980 | 980 | 0 | 0 | 0 |
| zh-CN | skill.name | 1226 | 148 | 267 | 811 | 0 |
| zh-CN | source.literal-review | 17391 | 0 | 0 | 0 | 17391 |
| zh-CN | stat.template | 21297 | 823 | 1570 | 18904 | 0 |
| zh-CN | tree.ascendancy | 22 | 0 | 0 | 22 | 0 |
| zh-CN | tree.class | 8 | 0 | 0 | 8 | 0 |
| zh-CN | tree.flavour | 46 | 46 | 0 | 0 | 0 |
| zh-CN | tree.name | 1998 | 18 | 0 | 1980 | 0 |
| zh-CN | tree.stat | 2626 | 22 | 12 | 2592 | 0 |
| zh-TW | config.label | 637 | 417 | 16 | 204 | 0 |
| zh-TW | config.option | 104 | 23 | 4 | 77 | 0 |
| zh-TW | config.section | 7 | 0 | 1 | 6 | 0 |
| zh-TW | config.tooltip | 238 | 180 | 41 | 17 | 0 |
| zh-TW | flavour.name | 442 | 2 | 0 | 440 | 0 |
| zh-TW | flavour.text | 944 | 905 | 39 | 0 | 0 |
| zh-TW | gem.name | 961 | 4 | 264 | 693 | 0 |
| zh-TW | gem.tag | 52 | 15 | 0 | 37 | 0 |
| zh-TW | gem.type | 12 | 1 | 0 | 11 | 0 |
| zh-TW | item.affix-name | 1494 | 950 | 323 | 221 | 0 |
| zh-TW | item.base | 1753 | 224 | 54 | 1475 | 0 |
| zh-TW | item.implicit | 220 | 9 | 27 | 184 | 0 |
| zh-TW | item.mod | 7581 | 66 | 176 | 7339 | 0 |
| zh-TW | item.subtype | 14 | 2 | 0 | 12 | 0 |
| zh-TW | item.type | 31 | 8 | 0 | 23 | 0 |
| zh-TW | item.unique | 441 | 1 | 0 | 440 | 0 |
| zh-TW | item.unique-mod | 3352 | 61 | 42 | 3249 | 0 |
| zh-TW | minion.category | 5 | 2 | 0 | 3 | 0 |
| zh-TW | minion.name | 579 | 536 | 20 | 23 | 0 |
| zh-TW | skill.description | 980 | 980 | 0 | 0 | 0 |
| zh-TW | skill.name | 1226 | 147 | 268 | 811 | 0 |
| zh-TW | source.literal-review | 17391 | 0 | 0 | 0 | 17391 |
| zh-TW | stat.template | 21297 | 806 | 1598 | 18893 | 0 |
| zh-TW | tree.ascendancy | 22 | 2 | 0 | 20 | 0 |
| zh-TW | tree.class | 8 | 1 | 1 | 6 | 0 |
| zh-TW | tree.flavour | 46 | 46 | 0 | 0 | 0 |
| zh-TW | tree.name | 1998 | 13 | 0 | 1985 | 0 |
| zh-TW | tree.stat | 2626 | 22 | 20 | 2584 | 0 |

缺口与复核明细：`localisation-runtime-missing.csv`。历史装备样本审计不能替代本报告，当前仍未完成全量中文化。
