# PoB2 本地化全局缺口盘点

> 本文件保留首次盘点的历史结果，范围不完整。2026-10-30 的全域数据审计见 `localisation-runtime-audit.md` 与 `localisation-runtime-missing.csv`；此前的词库精确命中数和装备样本结果不能证明天赋、技能说明与全部界面文案已完成翻译。

盘点日期：2026-10-29。目标语言：简体中文 zh-CN；繁體中文使用相同边界单独复核。此文件是缺口清单，不表示所有英文文本都应该翻译：用户构筑名、内部 ID、哈希、数值和计算对象必须保留原值。

## 先看截图中的结论

截图不是一个单独的“装备词条漏翻”问题，而是四类问题叠加：

- 属性基础标签（力量、敏捷、智慧、护甲、能量护盾、闪避、生命、魔力、格挡几率）已经有词条。
- 物品基底和 PoE2 新增类别仍有缺口，例如 Blazon Crest Shield、Ezomyte Shield。
- 物品标题由唯一物品名和基底名在 src/Classes/Item.lua、src/Classes/ItemsTab.lua 拼成整句；全局 DrawString 只能看到组合后的字符串，导致单词分别有译文时整句仍保持英文。
- PoE2 的整行固定词缀、属性模板和风味文本来自运行时数据，当前词库没有覆盖全部数据。

## 当前数据覆盖统计

| 数据域 | 总候选 | 简体词库精确命中 | 缺少精确条目 | 说明 |
|---|---:|---:|---:|---|
| 装备基底 | 1,769 | 1,500 | 269 | 对运行时数据做精确词条检查；模板和组合字符串另计 |
| 唯一物品名称 | 433 | 432 | 1 | 对运行时数据做精确词条检查；模板和组合字符串另计 |
| 技能/宝石名称 | 961 | 959 | 2 | 对运行时数据做精确词条检查；模板和组合字符串另计 |
| 风味文本与风味名称候选 | 1,230 | 440 | 790 | 对运行时数据做精确词条检查；模板和组合字符串另计 |
| 简体中文词库 | 66,521 | — | — | 67 个资源文件，CSV 原始非空映射 69,440 行 |

这些数字不能被理解为翻译完成率：属性模板、颜色码、数字区间、复合物品标题和动态文本需要按渲染路径验证。

## 缺口按责任边界分组

### 1. 界面固定文案

来源主要是 src/Modules/*.lua、src/Classes/*.lua 和 src/Export/*.lua 中直接传给控件或绘制函数的英文常量。当前已覆盖一部分 CSV，但仍有构筑列表、保存/导入弹窗、配置项、召唤物面板、比较面板、交易筛选、错误/警告和开发提示等路径需要做静态扫描。

对控件构造和 DrawString 调用做了初步静态扫描：发现 221 个唯一字符串候选，其中 95 个没有精确词条。这个数字包含格式串和内部控件字段，不能直接当作最终用户文案数量；可确认的可见候选包括 `<No matches>`、`Add Item Text`、`Allocate`、`Compare Build`、`Export All Loadouts`、`Import Item`、`Minion Stats`、`Monster Stats`、`Roll Ranges`、`Open Folder` 和 `Update`。

### 2. 角色属性和计算结果

基础属性名已有译文，但计算结果不是单一词条，包含 src/Data/StatDescriptions/*.lua、src/Data/Mod*.lua、src/Data/QueryMods.lua、CalcSections 和动态数字/区间模板。当前缺口集中在 PoE2 新增词缀、整行模板、授予技能和组合条件文本。

### 3. 装备基底、装备类别和唯一物品

数据来源是 src/Data/Bases/*.lua 和 src/Data/Uniques/*.lua。当前 1,769 个装备基底候选中有 269 个没有精确简体词条；唯一物品名称候选中缺少 1 个。截图里的 Blazon Crest Shield 属于此域，Ezomyte Shield 还涉及类别/子类型显示。

### 4. 物品词缀、固定词缀和授予技能

数据来源是装备基底的 implicit、唯一物品多行文本、src/Data/ModCache.lua、src/Data/ModItem*.lua、src/Data/ModRunes.lua 与 src/Data/StatDescriptions。不能只靠添加单个英文短语，因为同一词缀有固定值、区间值、颜色码和变体组合。

### 5. 技能、支援技能、召唤物和宝石

技能名称主要来自 src/Data/Gems.lua、src/Data/Skills/*.lua 和 src/Data/Spectres.lua。961 个技能/宝石名称候选中有 2 个没有精确条目；当前可见缺口包括 Oisin's Oath、Morrigan's Insight。支援技能、授予技能、Spectre:/Companion: 动态前缀还需要按组合文本验证。

### 6. 天赋树、升华、珠宝和标签

来源是 src/Data/PassiveTree*.lua、src/Data/ClusterJewels.lua、src/Data/Tattoo*.lua 及 src/Locales/zh-CN/passiveTree.csv、tree_*.csv。天赋节点和标签部分已有译文，但节点说明、升华名、珠宝名称、纹身、标签和搜索显示要分开核对；不能把天赋哈希或内部节点 ID 翻译。

### 7. 风味文本和世界文本

来源是 src/Data/FlavourText.lua。当前 1,230 个名称/文本候选中只有 440 个有精确词条，790 个缺少精确词条。截图底部的 May your resolve never waver. 就属于此域。风味文本应单独建立术语和校对范围，不能让未知文本静默变成空字符串。

### 8. 导入、搜索和反向转换

中文输入边界已经存在，但新增装备基底、技能、词缀和组合标题必须同时加入反向转换测试。否则界面看似翻译，复制物品或导入角色时仍会因英文内部键缺失而失败。相关入口：src/Modules/Localisation/Import.lua、src/Classes/ImportTab.lua、src/Classes/Item.lua。

### 9. 繁體中文资源包

繁體包当前文件清单与简体包不同，不能假设简体词库新增内容会自动存在于 zh-TW。例如 Grants Skill: Raise Shield 的繁體整行已有译文，但其中授予技能名仍显示英文，说明同样存在组合字符串粒度问题。

## 下一步应按这个顺序处理

1. 以 `RecoveredPoE2/src/resources/js/translator.js` 的已验证职责作为迁移参考：它已经把物品名称/基底、需求、属性、宝石、词缀、多行词缀和天赋覆盖拆成独立处理函数。当前 fork 应迁移这组字段边界，而不是继续增加最终整句替换。
2. 先建立运行时数据审计：启动 PoB2 数据后，逐项检查装备基底、唯一物品、技能、固定词缀、属性模板、天赋节点和风味文本的显示译文与反向译文。
3. 修正显示边界：物品标题按“唯一名/前后缀/基底名”分段翻译，属性词缀按模板翻译，类别和授予技能使用独立字段翻译；不要继续依赖整句 DrawString 精确匹配。
4. 再按数据域补充 PoE2 词库，优先装备基底、唯一物品、固定词缀、属性模板和当前角色常用技能。
5. 最后补全风味文本、低频数据和界面长尾，并为 zh-CN、zh-TW 各保留真实角色/物品回归样本。

当前已经落地的第一步是公共本地化层支持“固定标签 + 动态名称”的分段翻译，物品标题显示也按唯一名称和基底名称分别翻译。它只能解决词条边界问题，不能替代对缺失 PoE2 基底和词缀译文的全量补录。

完整的精确缺失候选已导出到 docs/localisation-gap-audit-missing.csv。

## 截图中的代表性条目

| 显示内容 | 当前判断 |
|---|---|
| Alkem Eira, Blazon Crest Shield | 组合字符串未命中；Alkem Eira 单独可命中，基底缺失 |
| Blazon Crest Shield | 词库缺少 PoE2 物品基底译名 |
| Ezomyte Shield | 由物品类型/子类型生成，词库缺少类别映射 |
| Grants Skill: Raise Shield | PoE2 基底 implicit 数据中的整行未命中 |
| (15-20)% increased Block Chance | 当前 statDescriptions 未覆盖该 PoE2 词缀模板 |
| (30-50)% increased Armour and Energy Shield | 简体词库已有相近模板，当前完整显示串仍需核对模板命中 |
| Damage Blocked is Recouped as Mana | 简体词库已有译文 |
| May your resolve never waver. | FlavourText 数据未进入当前简体词库 |
| Unnamed build | 用户构筑默认名称，当前未提供译文；是否翻译需区分用户数据 |

本盘点没有修改 PoB2 业务代码或批量词库，只建立了缺口证据，避免继续按单个截图逐项打补丁。
