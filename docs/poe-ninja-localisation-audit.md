# poe.ninja 构筑本地化验收

验收日期：2026-10-29。使用 `src/Tests/Fixtures/poe-ninja/` 中保存的三个公开 PoB2 构筑：

- `resurrectgodaura`
- `goodnerfing`
- `xxthewizardofosu`

这些样本的来源快照为 2026-10-29，PoB2、装备、技能和天赋 XML 均能被当前工程解析。字段扫描同时运行简体中文和繁體中文，保留英文内部名称、角色名、稀有装备随机名称和数值，只报告进入显示边界且词库未命中的候选。

## 当前发现的缺口

本轮扫描结果为 **0 个未命中候选**。此前发现并已处理：

- `Grants Skill: ...` 授予技能组合模板及动态技能名
- `Tawhoan Tower Shield` 简体和繁體基底
- 繁體包缺少的 `Thawing Charm`、`Dousing Charm`、`Ultimate Mana Flask`、`Ultimate Life Flask`、`Golden Charm`、`Transcendent Mana Flask`、`Grounding Charm`、`Stone Charm`
- 简体和繁體的 `Bonded: Buffs on you expire 10% slower`
- 简体和繁體的 `Bonded: Gain 2 Rage on Melee Hit`

## 已通过的部分

- 三个公开角色 XML 均能导入 PoB2。
- 装备、技能、天赋树和 XML 段均被保留。
- 唯一物品名称、物品基底和固定/符文词缀均通过字段级扫描。
- 未发现 ID、哈希、数值或角色名称被本地化层改写。

原始扫描输出保存在 `src/Tests/Run/poe-ninja-localisation-audit.txt`；可重复执行：

```cmd
cd /d E:\PoE2\src
..\tools\LuaRunner.exe ..\tools\audit-poe-ninja.lua
```

这次验收只证明三个固定公开构筑样本的显示字段已经闭合；它不等于所有 PoE2 版本数据都完成校对。后续仍需要扩大样本覆盖，并继续从运行时数据生成缺口清单。
