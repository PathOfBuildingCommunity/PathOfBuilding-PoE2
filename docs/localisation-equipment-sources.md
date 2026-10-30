# 装备词条来源与显示修复

日期：2026-10-30。语言包新增 `Equipment.csv`，加载在 `Integrated.csv` 之前。

## 来源与边界

1. 原有 PoeCharm 词库继续用于技能、修饰词、属性名称和旧装备；比较字段的部分译名复用已有带冒号标签，新增不带冒号的明确条目。
2. 通过官方公开交易接口取得三语物品表：`https://www.pathofexile.com/api/trade2/data/items`、`https://poe.game.qq.com/api/trade2/data/items`、`https://pathofexile.tw/api/trade2/data/items`。以已知传奇译名关联基底，区分普通、Runeforged、Runemastered，过滤 legacy；只有译名候选唯一时采用。不同服务器条目数量及顺序不同，不能按索引配对。直接关联补充简体 75 条、繁体 84 条基底名称。
3. 其余基底、缺失界面文案、比较字段和截图中的风味文本为项目补译；可复用的术语以现有词库为准。未把项目补译宣称为官方译名。`Rondel de Ezo` 采用项目音意译，后续应按正式游戏术语校对。
4. `localisation-equipment-terms.csv` 标出直接关联与项目补录，供术语复核。CSV 条数不是翻译准确率；无英文回退也不能替代校对。

## 已确认的显示根因

- 数据库、构筑、共享列表及装备槽直接绘制 `item.name`，组合名称不能命中按字段组织的词库。统一使用显示专用 `ItemName`，保留内部物品名、基底、raw、ID、排序和计算输入。
- 装备槽缓存名称，语言切换后只刷新标签，不重新装备物品。
- 装备槽使用下拉控件已有的 label/searchFilter 分离显示与检索词；数据库同时检索内部原名与显示名，避免中文显示破坏英文查询或译名无法查询。
- 词缀正文与“不支持”附注之间插入颜色码，导致整句失配。整句匹配优先，未命中后才按颜色/换行边界翻译，保留布局空白和颜色码。
- 无类型约束的 `{0}s` 把 `Requires`、`Focus`、`Fortress`、`Tethering Bands` 误识别为秒数。纯单位模板只接受数值。旧审计中的 latin-review 包含这类错误变化，不能视作已翻译。
- 比较栏先拼数值再尝试翻译，属性名失去字段边界。先翻译属性标签，再拼数值；保留比较百分比与颜色。
- 提示框在拆行前翻译后，原有英文 Equipping/Removing 分块标记随之消失。分块判断保留源文依据。
- 编辑控件整体关闭显示翻译，连 Search 等界面标签也被屏蔽。标签和占位提示先转换，用户缓冲区继续按原文绘制、测宽和编辑。

## 验证范围

`Tests/LocalisationEquipment.lua` 使用真实神谕装备、ItemsTab 提示框、数据库/共享/构筑列表、装备槽和编辑控件，检查 English → 简体 → 繁体 → English，以及原始物品数据不被改写。对神谕主提示框只允许保留 PoB、Shift、Ctrl+D；范围数值完整保留，比较分块与英文相同。

另行检查全部基底及实际运行时比较字段；`tools/audit-item-display.lua` 遍历当前数据的所有传奇样本默认变体，输出真实提示框和列表仍含拉丁字母的行。报告见 `localisation-item-display-audit.md`，明细见 `localisation-item-display-missing.csv`。历史版本、所有分组变体、全部稀有词缀组合、Shift 展开的技能子提示框及原生窗口布局并未因此获得全量验收。

风味文本、掉落来源等仍有翻译缺口，完整中文化任务继续保持开放。
