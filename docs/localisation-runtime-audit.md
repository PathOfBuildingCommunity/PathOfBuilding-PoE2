# PoB2 全域本地化审计

本次重新生成：2026-10-30，装备显示修复之后。

运行范围：当前 PoB2 运行时、4914 个天赋节点、全部装备/技能/召唤物数据、配置和计算页静态显示字段及 764 个属性描述文件。源码候选覆盖 123 个 Lua 文件。全仓逐文件范围见 `localisation-repository-inventory.csv`；历史树、未加载数据、二进制原生界面与导出/开发工具没有冒充已运行验收。

命令：在工程根目录运行 `build.cmd`，然后 `python tools/audit-localisation.py`。

“回退”表示输出仍为原英文；“含拉丁字母”表示输出有变化但仍需复核，可能是未翻译片段，也可能是专名、快捷键或格式符。无拉丁字母同样不证明译名准确。统计按数据域内唯一文本计数，明细保留引用次数与定位。

`source.literal-review` 递归枚举 Classes、Modules 及 src 根目录全部 Lua 的字符串常量（排除注释），包含内部键、路径、调试文字和用户文案；仅作为防漏候选，状态固定为 unclassified，不进行翻译命中统计。函数生成文案与未触发的界面交互仍需真实窗口验收。

| 语言 | 数据域 | 唯一文本 | 回退英文 | 含拉丁字母待复核 | 其余已变化 | 源码待分类 |
|---|---|---:|---:|---:|---:|---:|
| zh-CN | calcs.label | 742 | 487 | 21 | 234 | 0 |
| zh-CN | config.label | 637 | 195 | 47 | 395 | 0 |
| zh-CN | config.option | 104 | 13 | 4 | 87 | 0 |
| zh-CN | config.section | 7 | 0 | 1 | 6 | 0 |
| zh-CN | config.tooltip | 238 | 71 | 89 | 78 | 0 |
| zh-CN | flavour.name | 442 | 0 | 0 | 442 | 0 |
| zh-CN | flavour.text | 944 | 943 | 0 | 1 | 0 |
| zh-CN | gem.name | 961 | 4 | 263 | 694 | 0 |
| zh-CN | gem.tag | 52 | 17 | 0 | 35 | 0 |
| zh-CN | gem.type | 12 | 1 | 0 | 11 | 0 |
| zh-CN | item.affix-name | 1494 | 1272 | 0 | 222 | 0 |
| zh-CN | item.base | 1753 | 0 | 0 | 1753 | 0 |
| zh-CN | item.implicit | 220 | 2 | 13 | 205 | 0 |
| zh-CN | item.mod | 7581 | 74 | 171 | 7336 | 0 |
| zh-CN | item.subtype | 14 | 1 | 0 | 13 | 0 |
| zh-CN | item.type | 31 | 0 | 0 | 31 | 0 |
| zh-CN | item.unique | 441 | 0 | 0 | 441 | 0 |
| zh-CN | item.unique-mod | 3352 | 53 | 44 | 3255 | 0 |
| zh-CN | minion.category | 5 | 2 | 0 | 3 | 0 |
| zh-CN | minion.name | 579 | 553 | 3 | 23 | 0 |
| zh-CN | skill.description | 980 | 980 | 0 | 0 | 0 |
| zh-CN | skill.name | 1226 | 152 | 263 | 811 | 0 |
| zh-CN | source.literal-review | 17508 | 0 | 0 | 0 | 17508 |
| zh-CN | stat.template | 21297 | 402 | 1296 | 19599 | 0 |
| zh-CN | tree.ascendancy | 22 | 0 | 0 | 22 | 0 |
| zh-CN | tree.class | 8 | 0 | 0 | 8 | 0 |
| zh-CN | tree.flavour | 46 | 46 | 0 | 0 | 0 |
| zh-CN | tree.name | 1998 | 15 | 0 | 1983 | 0 |
| zh-CN | tree.stat | 2626 | 28 | 6 | 2592 | 0 |
| zh-TW | calcs.label | 742 | 487 | 1 | 254 | 0 |
| zh-TW | config.label | 637 | 384 | 47 | 206 | 0 |
| zh-TW | config.option | 104 | 22 | 3 | 79 | 0 |
| zh-TW | config.section | 7 | 1 | 0 | 6 | 0 |
| zh-TW | config.tooltip | 238 | 115 | 92 | 31 | 0 |
| zh-TW | flavour.name | 442 | 0 | 0 | 442 | 0 |
| zh-TW | flavour.text | 944 | 943 | 0 | 1 | 0 |
| zh-TW | gem.name | 961 | 4 | 264 | 693 | 0 |
| zh-TW | gem.tag | 52 | 15 | 0 | 37 | 0 |
| zh-TW | gem.type | 12 | 1 | 0 | 11 | 0 |
| zh-TW | item.affix-name | 1494 | 1273 | 0 | 221 | 0 |
| zh-TW | item.base | 1753 | 0 | 0 | 1753 | 0 |
| zh-TW | item.implicit | 220 | 2 | 13 | 205 | 0 |
| zh-TW | item.mod | 7581 | 75 | 166 | 7340 | 0 |
| zh-TW | item.subtype | 14 | 0 | 0 | 14 | 0 |
| zh-TW | item.type | 31 | 0 | 0 | 31 | 0 |
| zh-TW | item.unique | 441 | 0 | 0 | 441 | 0 |
| zh-TW | item.unique-mod | 3352 | 58 | 37 | 3257 | 0 |
| zh-TW | minion.category | 5 | 2 | 0 | 3 | 0 |
| zh-TW | minion.name | 579 | 553 | 3 | 23 | 0 |
| zh-TW | skill.description | 980 | 980 | 0 | 0 | 0 |
| zh-TW | skill.name | 1226 | 151 | 264 | 811 | 0 |
| zh-TW | source.literal-review | 17508 | 0 | 0 | 0 | 17508 |
| zh-TW | stat.template | 21297 | 349 | 1333 | 19615 | 0 |
| zh-TW | tree.ascendancy | 22 | 2 | 0 | 20 | 0 |
| zh-TW | tree.class | 8 | 2 | 0 | 6 | 0 |
| zh-TW | tree.flavour | 46 | 46 | 0 | 0 | 0 |
| zh-TW | tree.name | 1998 | 10 | 0 | 1988 | 0 |
| zh-TW | tree.stat | 2626 | 28 | 14 | 2584 | 0 |

缺口与复核明细：`localisation-runtime-missing.csv`。历史装备样本审计不能替代本报告，当前仍未完成全量中文化。
