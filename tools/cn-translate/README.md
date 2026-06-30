# cn-translate — 国服 item-paste translation toolchain

Datamines the **国服 (WeGame / Simplified-Chinese) PoE2 client** into en↔zh tables and
emits a single Lua module (`src/Data/ChineseTranslation.lua`) that the fork loads at
runtime. The translator (`src/Modules/ChineseItemTranslator.lua`) uses those tables to
convert a copy/pasted 国服 item into the English item-paste text PoB's parser expects.
See `../../POB-FORK-HANDOFF.md` for the full design and gotchas.

## Requirements

- The **WeGame 国服 PoE2 client** installed (the only source of the Simplified-Chinese
  strings). Auto-detected under `…/WeGameApps/rail_apps/Path of  Exile 2(…)` (double space).
  Override with `data/config.json` `{"cnInstall":"C:\\…"}` or a CLI path arg.
- **WSL node** (v22). `npm install` once in this folder pulls `pathofexile-dat`.
- For tests: **luajit** + **busted** + the `luautf8` rock (`lua-utf8`) in WSL.

## Regenerate after a 国服 patch

```bash
# under WSL, from this folder:
npm install                      # once
node extract_items.mjs           # bases, classes, skills, unique words -> data/*.json
node extract_statdesc.mjs        # full StatDescriptions -> data/stat_lines.json
node extract_passives.mjs        # passive-node names (for anointments) -> data/passive_names.json
node extract_mods.mjs            # affix (modifier) display names -> data/mod_names.json
node extract_clientstrings.mjs   # UI labels/flags (reference; labels are hand-mapped in Lua)
node emit_lua.mjs                # -> ../../src/Data/ChineseTranslation.lua  (commit this)
```

`data/` and `node_modules/` are gitignored; the committed output is the generated Lua table.

## Test

```bash
# standalone translator check (no PoB harness):
luajit test/run_translate.lua ../../src/Data/ChineseTranslation.lua \
  ../../src/Modules/ChineseItemTranslator.lua test/fixture_sceptre.txt

# full round-trip through PoB's real parser (busted headless harness):
bash test/run_spec.sh System/TestChineseItemParse_spec.lua
```

## Files

| File | Purpose |
| --- | --- |
| `engine.mjs` | Self-contained `.dat`/bundle reader (pathofexile-dat). |
| `extract_items.mjs` | BaseItemTypes, ItemClasses, ActiveSkills, Words.Text2 (en+zh). |
| `extract_statdesc.mjs` | Full `StatDescriptions/*.csd` → zh→en stat-line templates. |
| `extract_clientstrings.mjs` | ClientStrings (en+zh) — reference for the hand-mapped labels. |
| `extract_passives.mjs` | PassiveSkills node names (anointments). |
| `extract_mods.mjs` | Mods.Name affix display names (for `{ Prefix/Suffix "name" }` annotations). |
| `emit_lua.mjs` | JSON → `src/Data/ChineseTranslation.lua`. |
| `test/` | Fixture + standalone harness + busted runner + coverage probe. |

The committed output is a single module, **`src/Data/ChineseTranslation.lua`** (bases, classes,
skills, uniques, passives, affixes, stat-line + property templates), loaded lazily on a 国服 paste.

## Scope (Phase 1 — item paste, zh→en input)

Labels, rarity, class, base, unique name, properties (incl. weapon/defence), requirements,
mod/stat lines (with `(min-max)` range + `(augmented)` stripping), flask/charm charge & duration
lines, granted skills, anointments (`配置 X` → `Allocates X`), rune/implicit/crafted/desecrated
flags, and affix annotations (`{ 前缀属性 "name" (等阶：N) }` → translated name + tier, so PoB
fills prefix/suffix tiers). Chinese DISPLAY (en→zh) is **out of scope** — PoB's renderer can't
draw CJK glyphs (see `../../` notes); that needs a CJK-capable SimpleGraphic.
