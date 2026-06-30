# Item-modification coverage map

"Are all item modifications covered?" Item mods come from several different game-data
sources. This maps each to its datamine source, how the translator handles it, and the
residual gaps. The guiding principle: **we translate each zh line to the exact English the
*international* game renders**, then PoB parses that English. So a mod is "covered" when we
can produce its correct English; whether PoB then recognises that English is a separate
(upstream) question — see "Residual" below.

| Modification kind | Example (zh → en) | Source table | Handled by |
| --- | --- | --- | --- |
| Explicit / implicit / rune / desecrated / corrupted stat lines | `魔力再生率提高 67%` → `67% increased Mana Regeneration Rate` | `StatDescriptions/*.csd` (all files) → `stat_lines` | numeric-placeholder template matcher |
| Anointment (passive allocation) | `配置 高效铭文` → `Allocates Efficient Inscriptions` | `PassiveSkills.Name` → `passives` | `translateAllocates` (text placeholder → passive-node lookup) |
| Forbidden Flame/Flesh combo | `禁断之火上有匹配的词缀则配置 X` → `Allocates X if you have the matching modifier on Forbidden Flame` | `PassiveSkills.Name` (ascendancy) | `translateAllocates` |
| Granted skill | `获得技能: 等级 19 冰霜净化` → `Grants Skill: Level 19 Purity of Ice` | `ActiveSkills` → `skills` | label + skill-name substitution |
| Affix annotations (name + flags + tier) | `{ 前缀属性 "龙胆的" (等阶：4) }` → `{ Prefix Modifier "Galvanic" (Tier: 4) }` | keywords hand-mapped + `Mods.Name` → `affixes` | `translateAffixAnnotation` (PoB matches the affix → fills prefix/suffix tiers) |
| Item-class / rarity / base / unique name | `圣地权杖` → `Shrine Sceptre` | `BaseItemTypes` / `ItemClasses` / `Words.Text2` | exact-match maps |
| Property lines (labels) | `物理伤害: 34-53` → `Physical Damage: 34-53` | `ClientStrings` (reference) → hand-mapped labels | `LABELS` |
| Property TEMPLATES (flask/charm) | `持续 {0} 秒` → `Lasts {0} Seconds`; `目前有 {0} 充能次数` → `Currently has {0} Charges` | `ClientStrings` `ItemDisplay(Flask|Charges|TalismanTier)*` → `propLines` | same numeric matcher |
| State flags | `被腐化` → `Corrupted`, `(符文)` → `(rune)` | `ClientStrings` (reference) → hand-mapped | `LINE_FLAGS` / `FLAG_PAREN` |

## Intentional gaps (do **not** affect whether a mod's stats apply)

- **Rare item names** (`复仇 巨锤`) — affix-generated and procedural, no fixed table; PoB
  ignores the name for parsing, so they stay Chinese (`???` after sanitise). Cosmetic only.
- **Unique flavour text** (the italic quotes) — not modifiers; PoB regenerates a matched
  unique's display from its own data, so the pasted flavour is irrelevant.

## Residual (upstream, not a translation gap)

Because we emit the international game's English, a mod fails to *apply* only if **PoB's own
mod database doesn't recognise that English string** — i.e. the 国服 client and PoB are on
different patches ("content lag", see POB-FORK-HANDOFF.md §9). This is invisible to the
translator. Find it three ways:

1. **Coverage probe** — lines still containing CJK after translation (we couldn't translate):
   `luajit test/coverage.lua <data.lua> <translator.lua> test/items.txt` (see ../items.txt).
2. **Parse spec** — `test/run_spec.sh System/TestChineseItemParse_spec.lua` parses every corpus
   item through PoB and asserts the base is recognised + reports resolved mod counts.
3. **In-app Dev Mode** — launch `runtime/Path of  Building-PoE2.exe` and hold **Alt** over an
   item; PoB highlights any unrecognised parts of a stat description.

When PoB and 国服 are on the same patch (as verified for the anointment node "Efficient
Inscriptions", whose datamined name matches PoB's `tree.notableMap` key exactly), coverage of
mod *effects* is complete.
