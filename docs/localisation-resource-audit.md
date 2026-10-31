# 语言资源结构审计

生成日期：2026-10-31。命令：`python tools/audit-locale-resources.py`。

按 Files.lua 顺序和 Dictionary:Add 的空值/同文跳过规则计算有效词条。覆盖次数不等于缺陷；反向歧义允许安全保留原文，不能直接当成导入已兼容。大小写冲突需要结合精确匹配与小写检索复核。参数集合不一致可能丢值或产生占位符残留，须逐条核实。

| 语言 | 项目 | 数量 |
|---|---|---:|

显示资源（Manifest.messageFiles）使用稳定 key 和命名参数独立校验。英文回退数量表示尚无该语言译文，不是参数错误；以下输入词典统计不参与显示资源查找。

| 显示资源语言 | 项目 | 数量 |
|---|---|---:|
| en | files | 2 |
| en | keys | 123836 |
| zh-CN | english-fallback-keys | 660 |
| zh-CN | files | 2 |
| zh-CN | keys | 123176 |
| zh-TW | english-fallback-keys | 655 |
| zh-TW | files | 2 |
| zh-TW | keys | 123181 |

| 输入词典语言 | 项目 | 数量 |
|---|---|---:|
| zh-CN | case-collision-groups | 283 |
| zh-CN | effective-terms | 66941 |
| zh-CN | identity-rows | 14 |
| zh-CN | loaded-files | 68 |
| zh-CN | missing-glyph-codepoints | 0 |
| zh-CN | overrides | 301 |
| zh-CN | placeholder-mismatch | 395 |
| zh-CN | reverse-collision-groups | 2450 |
| zh-CN | rows | 70158 |
| zh-TW | case-collision-groups | 475 |
| zh-TW | effective-terms | 77956 |
| zh-TW | identity-rows | 7 |
| zh-TW | loaded-files | 22 |
| zh-TW | missing-glyph-codepoints | 1 |
| zh-TW | missing-glyph-terms | 4 |
| zh-TW | overrides | 1974 |
| zh-TW | placeholder-mismatch | 612 |
| zh-TW | reverse-collision-groups | 2485 |
| zh-TW | rows | 90509 |

完整定位见 `localisation-resource-review.csv`。没有执行自动词库替换，也没有把每个歧义项都判成运行错误。
