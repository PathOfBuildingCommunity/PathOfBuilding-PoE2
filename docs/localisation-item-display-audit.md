# 装备实际显示审计

生成日期：2026-10-30。命令：在 `src` 目录运行 `..\tools\LuaRunner.exe ..\tools\audit-item-display.lua`。

使用真实 Item、ItemsTab:AddItemTooltip 和数据库 GetRowValue，启用风味文本及不支持附注。扫描当前默认变体；未遍历全部历史版本、分组变体、稀有词缀组合及 Shift 展开的技能子提示框。比较栏检查真实字段标签，数值拼接另外由集成测试覆盖。

| 语言 | 基底数 | 原文回退基底 | 传奇样本 | 提示框行 | 含拉丁字母行 | 比较标签 | 原文回退标签 | 构建异常 |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| zh-CN | 1756 | 0 | 443 | 6766 | 2253 | 203 | 0 | 0 |
| zh-TW | 1756 | 0 | 443 | 6766 | 2231 | 203 | 0 | 0 |

| 待复核输出域 | 简体含拉丁行 | 繁体含拉丁行 |
|---|---:|---:|
| base | 0 | 0 |
| list-name | 0 | 0 |
| comparison-label | 36 | 1 |
| tooltip.property | 231 | 197 |
| tooltip.modifier | 330 | 332 |
| tooltip.flavour | 949 | 949 |
| tooltip.source | 209 | 219 |
| tooltip.hint | 534 | 534 |
| error | 0 | 0 |

`localisation-item-display-missing.csv` 按属性、词缀、风味、来源、提示等域保存实际含拉丁字母输出，并携带拆行前源文与装备定位；其中包含 PoB、Shift、Ctrl、DPS 等合理保留项，不能直接当作未翻译数量。没有拉丁字母也不等于术语准确。该审计使用图形桩，不能代替原生窗口布局和交互验收。
