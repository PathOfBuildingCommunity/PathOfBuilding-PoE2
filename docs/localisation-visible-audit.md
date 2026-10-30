# 实际显示路径扫描

生成日期：2026-10-30。命令：在 src 目录运行 `..\tools\LuaRunner.exe ..\tools\audit-visible-localisation.lua`。

执行 English、简体、繁体的九个构筑页面、选项页、递归控件提示文字、当前树的全部节点提示框（关闭属性比较，包含授予技能子提示框）和全部宝石的 20 级/20 品质提示框（自然最高等级不足 20 时使用自然最高等级）。没有点击购买、更新或外部服务。用户编辑原文保留，不算漏译。

批量提示框关闭自动换行，以完整句子统计翻译；缓存优化前后的两个保留换行版本曾对照 1,189 条简体非宝石残留记录，结果一致，另有 40 个缓存前后结果等价探针。这些对照不证明本次完整句子结果与换行片段逐行一致。审计期间仅缓存固定词库的纯函数结果。代表样本换行路径有集成回归，不能据此宣称全节点/技能的换行布局通过。

此扫描使用图形桩调用实际 Lua 绘制/提示框逻辑；不证明原生窗口布局、字体输入法、网络流程、隐藏弹窗和全部动态状态已验收。控件 tooltipFunc 没有强行用不完整参数调用；其字符串仍在全仓源码候选中。统计按语言/场景/源文/输出去重；allowed-only 只作常见缩写与按键的粗分，不保证语义正确。

| 语言与场景 | 唯一文本/异常 | 原文回退 | 部分英文 | 仅保留项 | 调用异常 |
|---|---:|---:|---:|---:|---:|
| en / control.tooltip | 273 | 0 | 0 | 0 | 0 |
| en / gem.tooltip | 6155 | 0 | 0 | 0 | 0 |
| en / options | 58 | 0 | 0 | 0 | 0 |
| en / page.CALCS | 269 | 0 | 0 | 0 | 0 |
| en / page.COMPARE | 74 | 0 | 0 | 0 | 0 |
| en / page.CONFIG | 159 | 0 | 0 | 0 | 0 |
| en / page.IMPORT | 94 | 0 | 0 | 0 | 0 |
| en / page.ITEMS | 148 | 0 | 0 | 0 | 0 |
| en / page.NOTES | 81 | 0 | 0 | 0 | 0 |
| en / page.PARTY | 86 | 0 | 0 | 0 | 0 |
| en / page.SKILLS | 83 | 0 | 0 | 0 | 0 |
| en / page.TREE | 73 | 0 | 0 | 0 | 0 |
| en / tree.tooltip | 5150 | 0 | 0 | 0 | 0 |
| zh-CN / control.tooltip | 273 | 81 | 93 | 0 | 0 |
| zh-CN / gem.tooltip | 6155 | 1981 | 738 | 889 | 0 |
| zh-CN / options | 58 | 12 | 8 | 0 | 0 |
| zh-CN / page.CALCS | 273 | 102 | 3 | 4 | 0 |
| zh-CN / page.COMPARE | 74 | 1 | 3 | 1 | 0 |
| zh-CN / page.CONFIG | 159 | 31 | 9 | 3 | 0 |
| zh-CN / page.IMPORT | 94 | 14 | 4 | 1 | 0 |
| zh-CN / page.ITEMS | 147 | 26 | 2 | 2 | 0 |
| zh-CN / page.NOTES | 81 | 13 | 3 | 1 | 0 |
| zh-CN / page.PARTY | 86 | 1 | 3 | 1 | 0 |
| zh-CN / page.SKILLS | 83 | 2 | 3 | 3 | 0 |
| zh-CN / page.TREE | 73 | 1 | 2 | 1 | 0 |
| zh-CN / tree.tooltip | 5150 | 222 | 39 | 494 | 0 |
| zh-TW / control.tooltip | 273 | 140 | 95 | 0 | 0 |
| zh-TW / gem.tooltip | 6155 | 1942 | 785 | 887 | 0 |
| zh-TW / options | 58 | 33 | 2 | 0 | 0 |
| zh-TW / page.CALCS | 273 | 111 | 2 | 1 | 0 |
| zh-TW / page.COMPARE | 74 | 10 | 1 | 0 | 0 |
| zh-TW / page.CONFIG | 159 | 48 | 6 | 1 | 0 |
| zh-TW / page.IMPORT | 94 | 18 | 2 | 0 | 0 |
| zh-TW / page.ITEMS | 147 | 33 | 1 | 1 | 0 |
| zh-TW / page.NOTES | 81 | 19 | 1 | 0 | 0 |
| zh-TW / page.PARTY | 86 | 6 | 2 | 0 | 0 |
| zh-TW / page.SKILLS | 83 | 6 | 1 | 1 | 0 |
| zh-TW / page.TREE | 73 | 7 | 1 | 0 | 0 |
| zh-TW / tree.tooltip | 5150 | 215 | 50 | 484 | 0 |

定位与完整实际输出见 `localisation-visible-missing.csv`。所有异常保留原始堆栈，须区分审计输入缺失与产品缺陷。英文基线异常同时出现时不能归因于汉化。
