-- Path of Building (国服 fork)
--
-- Module: ChineseItemTranslator
-- Translates an item copy/pasted from the Simplified-Chinese (国服 / WeGame) PoE2
-- client into the English item-paste text PoB's parser expects, line by line.
--
-- The 国服 client is a mirror of the international one, so every base, class,
-- skill, unique and stat line has a language-independent metadata Id. The en<->zh
-- tables in Data/ChineseTranslation.lua are datamined from that client (see
-- tools/cn-translate/ + POB-FORK-HANDOFF.md). This module only does the *input*
-- direction (zh -> en) so that ItemClass:ParseRaw can parse a 国服 item.
--
-- IMPORTANT: this must run BEFORE sanitiseText(), because sanitiseText turns every
-- byte 128-255 (i.e. all CJK UTF-8 bytes) into '?'. The hook lives in the Item
-- class constructor (src/Classes/Item.lua).

local t_insert = table.insert
local t_concat = table.concat

-- ---------------------------------------------------------------------------
-- Data (loaded lazily on the first translation so the 3 MB table costs nothing
-- at startup for users who never paste a 国服 item).
-- ---------------------------------------------------------------------------
local data
local function ensureData()
	if data then return data end
	if LoadModule then
		data = LoadModule("Data/ChineseTranslation")
	elseif __CN_TRANSLATION_DATA then       -- injected by the standalone test harness
		data = __CN_TRANSLATION_DATA
	else
		data = dofile("src/Data/ChineseTranslation.lua")
	end
	return data
end

-- ---------------------------------------------------------------------------
-- Hand-mapped labels / keywords (small, stable, exact). Everything else comes
-- from the datamined tables. Keys are the zh text AFTER fullwidth-punctuation
-- normalisation (so ASCII ':' etc).
-- ---------------------------------------------------------------------------

-- Property / section labels: the part before the colon on a "Label: value" line.
-- Translated to PoB's exact English label (see src/Classes/Item.lua:ParseRaw).
local LABELS = {
	["物品类别"] = "Item Class",
	["稀有度"] = "Rarity",
	["品质"] = "Quality",
	["精魂"] = "Spirit",
	["需求"] = "Requires",
	["物品等级"] = "Item Level",
	["插槽"] = "Sockets",
	["获得技能"] = "Grants Skill",
	["魔符等级"] = "Talisman Tier",
	["堆叠数量"] = "Stack Size",
	["咒符栏"] = "Charm Slots",
	["等级"] = "Level",
	["限制"] = "Limited to",
	["半径"] = "Radius",
	-- Defence properties (PoB parser specNames: Armour / Evasion[ Rating] / Energy Shield / Ward).
	["护甲"] = "Armour",
	["闪避值"] = "Evasion Rating",
	["闪避"] = "Evasion",
	["能量护盾"] = "Energy Shield",
	["符文结界"] = "Ward",   -- 国服/EN display "Runic Ward"; PoB's property label is "Ward"
	-- Weapon properties (PoB treats these as hidden_specs; it recomputes from base+mods).
	["物理伤害"] = "Physical Damage",
	["元素伤害"] = "Elemental Damage",
	["混沌伤害"] = "Chaos Damage",
	["暴击率"] = "Critical Hit Chance",
	["暴击几率"] = "Critical Hit Chance",
	["每秒攻击次数"] = "Attacks per Second",
	["武器范围"] = "Weapon Range",
	["装填时间"] = "Reload Time",
	["格挡几率"] = "Block chance",
}

-- Rarity values.
local RARITY = {
	["普通"] = "Normal",
	["魔法"] = "Magic",
	["稀有"] = "Rare",
	["传奇"] = "Unique",
	["独特"] = "Unique",
}

-- Words that appear *inside* a value (requirements line, etc).
local VALUE_WORDS = {
	["等级"] = "Level",
	["力量"] = "Str",
	["敏捷"] = "Dex",
	["智慧"] = "Int",
}

-- Whole-line state flags.
local LINE_FLAGS = {
	["已腐化"] = "Corrupted",
	["被腐化"] = "Corrupted",
	["腐化"] = "Corrupted",
	["未鉴定"] = "Unidentified",
	["镜像"] = "Mirrored",
	["已镜像"] = "Mirrored",
	["分裂"] = "Split",
}

-- Whole-line non-mod flag / reminder text (PoB-irrelevant for parsing, but translated
-- so imports don't show stray ???). Exact match on the rendered (punct-normalised) line.
local MISC = {
	["引路石掉落"] = "Waystone Drop",
	["只能在使用弓时装备。"] = "Can only be equipped if you are wielding a Bow.",
	["放入天赋树上配置好的珠宝槽。"] = "Place into an allocated Jewel Socket on the Passive Skill Tree.",
	["满足条件时自动使用。只有装备于腰带上时才会充能。可通过水井或击败怪物补充。"] =
		"Used automatically when condition is met. Can only hold charges while in belt. Refill at Wells or by killing monsters.",
}

-- Trailing parenthetical mod-state flags, e.g. "...提高 15% (符文)" -> "(rune)".
-- English forms pass through unchanged so an English-flagged paste still works.
local FLAG_PAREN = {
	["符文"] = "rune",     ["rune"] = "rune",
	["附魔"] = "enchant",  ["enchant"] = "enchant",
	["工艺"] = "crafted",  ["打造"] = "crafted",  ["crafted"] = "crafted",
	["基底"] = "implicit", ["固有"] = "implicit", ["implicit"] = "implicit",
	["分裂的"] = "fractured", ["fractured"] = "fractured",
	["凿刻"] = "desecrated",  ["desecrated"] = "desecrated",
}

-- Affix-annotation `{ … }` pieces. We translate the *type* keywords (so PoB's
-- existing `{ }` parser sets the implicit/enchant/crafted/desecrated flags) and
-- omit the affix NAME + tags — the name needs the Mods table (Phase 2/3), and an
-- untranslated name would make PoB mark the mod "custom". Order matters: longer /
-- leading modifiers first.
local AFFIX_LEADING = {            -- leading qualifiers (become lineFlags via "Modifier")
	{ "亵渎的", "Desecrated" },
	{ "打造的", "Crafted" },
}
local AFFIX_TYPE = {               -- the modifier type
	{ "前缀属性", "Prefix Modifier" },
	{ "后缀属性", "Suffix Modifier" },
	{ "基底属性", "Implicit Modifier" },
	{ "传奇属性", "Unique Modifier" },
	{ "强化", "Enhancement" },     -- enchant marker -> PoB adds " (enchant)"
}

-- ---------------------------------------------------------------------------
-- Fullwidth / CJK punctuation normalisation (byte-level, UTF-8)
-- ---------------------------------------------------------------------------
local PUNCT = {
	["\239\188\154"] = ":",  -- U+FF1A FULLWIDTH COLON
	["\239\188\140"] = ",",  -- U+FF0C FULLWIDTH COMMA
	["\239\188\136"] = "(",  -- U+FF08 FULLWIDTH LEFT PARENTHESIS
	["\239\188\137"] = ")",  -- U+FF09 FULLWIDTH RIGHT PARENTHESIS
	["\227\128\128"] = " ",  -- U+3000 IDEOGRAPHIC SPACE
	["\239\188\141"] = "-",  -- U+FF0D FULLWIDTH HYPHEN-MINUS
	["\226\128\148"] = "-",  -- U+2014 EM DASH
	["\226\128\147"] = "-",  -- U+2013 EN DASH
	["\226\128\146"] = "-",  -- U+2012 FIGURE DASH
	["\226\128\149"] = "-",  -- U+2015 HORIZONTAL BAR
}
-- Fullwidth digits U+FF10..U+FF19 -> 0..9
for n = 0, 9 do PUNCT["\239\188" .. string.char(0x90 + n)] = tostring(n) end

local function normalizePunct(s)
	-- Match any 3-byte sequence we care about, plus the common 2/3-byte dashes.
	return (s:gsub("[\226\227\239][\128-\189][\128-\191]", function(seq)
		return PUNCT[seq]
	end))
end

-- ---------------------------------------------------------------------------
-- Stat-line (StatDescriptions) matcher — ported from the trade helper's proven
-- translateStatLine(). data.statLines is { { zhTemplate, enTemplate }, ... } with
-- {N} / {} placeholders. We normalise both the template and the rendered line's
-- numbers to '#', look up by the normalised key, then confirm with a Lua pattern
-- (so literal numbers in a template must match) and transplant the rolled values.
-- ---------------------------------------------------------------------------
local NUMRUN = "[%+%-]?%d[%d%.,]*"
local PLACEHOLDER = "{%d*}"

local function normNums(s)
	return (s:gsub(NUMRUN, "#"))
end

-- Escape Lua-pattern magic chars in a literal segment (CJK bytes are not magic).
local function escapePat(s)
	return (s:gsub("[%(%)%.%%%+%-%*%?%[%]%^%$]", "%%%1"))
end

local STATMAP            -- normalisedZh -> { {zh, en}, ... }
local function buildStatMap()
	if STATMAP then return STATMAP end
	STATMAP = {}
	local function add(pair)
		-- Normalise the zh template's punctuation the SAME way as the runtime line
		-- (the paste is normalised globally), so fullwidth commas/colons in a
		-- template still match. Store the normalised zh for the regex pass.
		local zhNorm = normalizePunct(pair[1])
		local key = normNums(zhNorm:gsub(PLACEHOLDER, "#"))
		local bucket = STATMAP[key]
		if not bucket then bucket = {}; STATMAP[key] = bucket end
		t_insert(bucket, { zhNorm, pair[2] })
	end
	for _, pair in ipairs(data.statLines or {}) do add(pair) end
	-- Item-text property templates (flask recovery, charge/duration lines) that
	-- render from ClientStrings rather than StatDescriptions.
	for _, pair in ipairs(data.propLines or {}) do add(pair) end
	return STATMAP
end

local _reCache = {}
-- Build a `^...$` Lua pattern from a zh template, with each placeholder a numeric
-- capture; returns the pattern and the ordered list of placeholder indices.
local function statRe(zh)
	local c = _reCache[zh]
	if c then return c.pat, c.order end
	local parts, order, pos, last = {}, {}, 0, 1
	for s, dig, e in zh:gmatch("(){(%d*)}()") do
		parts[#parts + 1] = escapePat(zh:sub(last, s - 1))
		parts[#parts + 1] = "(" .. NUMRUN .. ")"
		local idx
		if dig == "" then idx = pos; pos = pos + 1 else idx = tonumber(dig) end
		order[#order + 1] = idx
		last = e
	end
	parts[#parts + 1] = escapePat(zh:sub(last))
	local pat = "^" .. t_concat(parts) .. "$"
	_reCache[zh] = { pat = pat, order = order }
	return pat, order
end

-- Fill an en template's {N}/{} placeholders from valueByIndex.
local function fillTemplate(en, valueByIndex)
	local pos = 0
	return (en:gsub("{(%d*)}", function(dig)
		local idx
		if dig == "" then idx = pos; pos = pos + 1 else idx = tonumber(dig) end
		local v = valueByIndex[idx]
		return v ~= nil and v or ("{" .. dig .. "}")
	end))
end

local function translateStatLine(line)
	local cands = buildStatMap()[normNums(line)]
	if not cands then return nil end
	for _, pair in ipairs(cands) do
		local pat, order = statRe(pair[1])
		if #order == 0 then
			if line:match(pat) then return pair[2] end
		else
			local caps = { line:match(pat) }
			if caps[1] ~= nil then
				local val = {}
				for k = 1, #order do val[order[k]] = caps[k] end
				return fillTemplate(pair[2], val)
			end
		end
	end
	return nil
end

-- ---------------------------------------------------------------------------
-- Line helpers
-- ---------------------------------------------------------------------------

-- Strip advanced-display range groups " (min-max)" (digits/dot/dash/comma only;
-- lettered parens like "(rune)" are left for the flag pass), plus the inline
-- "(augmented)" marker that the client prints (in English) on quality-modified
-- values, e.g. "3 秒内回复 1855 (augmented) 生命".
local function stripRanges(s)
	s = s:gsub("%s*%(augmented%)", "")
	return (s:gsub("%s*%([%d%.%-,]+%)", ""))
end

-- Plain (non-pattern) replace of the first occurrence of `find` with `repl`.
local function plainReplace(s, find, repl)
	local i = s:find(find, 1, true)
	if not i then return s, false end
	return s:sub(1, i - 1) .. repl .. s:sub(i + #find), true
end

local function replaceWords(s, map)
	for zh, en in pairs(map) do
		local changed = true
		while changed do s, changed = plainReplace(s, zh, en) end
	end
	return s
end

-- Skill names sorted longest-first so a longer name isn't shadowed by a prefix.
local SKILLS_SORTED
local function buildSkillsSorted()
	if SKILLS_SORTED then return SKILLS_SORTED end
	SKILLS_SORTED = {}
	for zh, en in pairs(data.skills or {}) do t_insert(SKILLS_SORTED, { zh, en }) end
	table.sort(SKILLS_SORTED, function(a, b) return #a[1] > #b[1] end)
	return SKILLS_SORTED
end

local function replaceSkills(s)
	for _, sk in ipairs(buildSkillsSorted()) do
		local out, ok = plainReplace(s, sk[1], sk[2])
		if ok then return out end
	end
	return s
end

local function translateValue(enLabel, val)
	if enLabel == "Rarity" then return RARITY[val] or val end
	if enLabel == "Item Class" then return data.classes[val] or val end
	if enLabel == "Grants Skill" then
		val = replaceWords(val, VALUE_WORDS)
		return replaceSkills(val)
	end
	-- Requires + anything else: translate value keywords (Level / attributes).
	return replaceWords(val, VALUE_WORDS)
end

-- Translate a mod line: peel off a trailing "- Unscalable Value" marker and a
-- trailing state flag, strip ranges, match the StatDescriptions template, then
-- re-append the marker/flag in the English form PoB expects.
local function translateModLine(line)
	-- "… - 数值不可调整" (value not adjustable) -> PoB strips " - Unscalable Value".
	local unscalable = false
	local pre = line:match("^(.-)%s*[%-]%s*数值不可调整%s*$")
	if pre then line = pre; unscalable = true end

	local flagEn
	local body, inner = line:match("^(.-)%s*%(([^()]*)%)%s*$")
	if inner and inner ~= "" and not inner:match("%d") then
		local f = FLAG_PAREN[inner]
		if f then flagEn = f; line = body end
	end
	local core = stripRanges(line)
	core = core:gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
	local en = translateStatLine(core)
	if not en then return nil end
	if flagEn then en = en .. " (" .. flagEn .. ")" end
	if unscalable then en = en .. " - Unscalable Value" end
	return en
end

-- Anointment / passive-allocation mods render as "配置 <节点名>" -> "Allocates <node>".
-- The generic stat matcher only fills NUMERIC placeholders, but here the "{0}" of the
-- template "配置 {0}" is a passive-node NAME (text), so we look it up in data.passives.
-- Handles the trailing " - 数值不可调整" (Unscalable Value) marker too.
local function lookupPassive(node)
	return data.passives and data.passives[(node:gsub("%s+$", ""))]
end

local function translateAllocates(line)
	-- Forbidden Flame/Flesh ascendancy combo (a unique-jewel mod).
	local side, fnode = line:match("^禁断之([肉火])上有匹配的词缀则配置%s+(.+)$")
	if fnode then
		local en = lookupPassive(fnode)
		if en then
			return "Allocates " .. en .. " if you have the matching modifier on "
				.. (side == "肉" and "Forbidden Flesh" or "Forbidden Flame")
		end
		return nil
	end
	-- Plain anointment "配置 <node>" (with optional " - 数值不可调整"/Unscalable marker).
	local unscalable = false
	local pre = line:match("^(.-)%s*%-%s*数值不可调整%s*$")
	if pre then line = pre; unscalable = true end
	local node = line:match("^配置%s+(.+)$")
	if not node then return nil end
	local en = lookupPassive(node)
	if not en then return nil end
	return "Allocates " .. en .. (unscalable and " - Unscalable Value" or "")
end

-- Translate an affix-annotation line `{ [亵渎的] 前缀属性 "name" (等阶：N) — tags }`.
-- Keeps the modifier-type keywords (so PoB flags implicit/enchant/crafted/desecrated),
-- the translated affix NAME (so PoB matches the affix and fills prefix/suffix tiers),
-- and the tier; tags are omitted. Returns nil for an unrecognised annotation.
local function translateAffixAnnotation(line)
	local inner = line:match("^%s*{%s*(.-)%s*}%s*$")
	if not inner then return nil end
	local parts = {}
	for _, m in ipairs(AFFIX_LEADING) do
		if inner:find(m[1], 1, true) then t_insert(parts, m[2]) end
	end
	for _, m in ipairs(AFFIX_TYPE) do
		if inner:find(m[1], 1, true) then t_insert(parts, m[2]); break end
	end
	if #parts == 0 then return nil end
	local out = "{ " .. t_concat(parts, " ")
	-- Affix display name (datamined Mods table). Included only when we can translate
	-- it; an untranslated name would make PoB mark the mod "custom".
	local zhName = inner:match('"(.-)"')
	if zhName and data.affixes and data.affixes[zhName] then
		out = out .. ' "' .. data.affixes[zhName] .. '"'
	end
	local tier = inner:match("等阶[:：]%s*(%d+)")
	if tier then out = out .. " (Tier: " .. tier .. ")" end
	return out .. " }"
end

-- Last-resort: a magic-item name line contains a base type as a substring. Swap
-- the longest base substring to English so PoB can still find the base.
local BASES_SORTED
local function buildBasesSorted()
	if BASES_SORTED then return BASES_SORTED end
	BASES_SORTED = {}
	for zh, en in pairs(data.bases or {}) do t_insert(BASES_SORTED, { zh, en }) end
	table.sort(BASES_SORTED, function(a, b) return #a[1] > #b[1] end)
	return BASES_SORTED
end

local function substringBase(line)
	for _, b in ipairs(buildBasesSorted()) do
		if line:find(b[1], 1, true) then
			return (plainReplace(line, b[1], b[2]))
		end
	end
	return nil
end

-- ---------------------------------------------------------------------------
-- Per-line dispatch
-- ---------------------------------------------------------------------------
-- Returns the translated line, or nil to DROP the line from the output.
local function translateLine(line)
	if line == "" or line:match("^%-+$") then return line end
	-- Affix annotation `{ 前缀属性 "name" (等阶：N) — tags }`.
	if line:match("^%s*{") then return translateAffixAnnotation(line) end

	-- "Label: value"
	local label, val = line:match("^([^:]+):%s*(.*)$")
	if label then
		local enLabel = LABELS[(label:gsub("%s+$", ""))]
		if enLabel then return enLabel .. ": " .. translateValue(enLabel, val) end
	end

	-- Whole-line exact matches.
	if data.bases[line] then return data.bases[line] end
	if data.uniques[line] then return data.uniques[line] end
	if RARITY[line] then return RARITY[line] end
	if LINE_FLAGS[line] then return LINE_FLAGS[line] end
	if MISC[line] then return MISC[line] end

	-- Anointment / passive-allocation mod (text placeholder -> passive-node lookup).
	local alloc = translateAllocates(line)
	if alloc then return alloc end

	-- Mod / stat line.
	local mod = translateModLine(line)
	if mod then return mod end

	-- Magic-item name fallback.
	local sub = substringBase(line)
	if sub then return sub end

	return line  -- passthrough (e.g. rare cosmetic name, PoB-irrelevant flags)
end

-- ---------------------------------------------------------------------------
-- Public API
-- ---------------------------------------------------------------------------
local M = {}

-- True if the text contains a CJK (3-byte UTF-8) character.
function M.hasCJK(raw)
	return raw ~= nil and raw:find("[\227-\233][\128-\191][\128-\191]") ~= nil
end

-- Translate a 国服 item paste to English item-paste text. No-op (returns the
-- input unchanged) if there's no CJK. Never throws: on any error the original
-- text is returned so PoB's parser still runs.
function M.translate(raw)
	if not M.hasCJK(raw) then return raw end
	local ok, result = pcall(function()
		ensureData()
		local text = normalizePunct(raw)
		local out = {}
		local start = 1
		while true do
			local nl = text:find("\n", start, true)
			local line = (nl and text:sub(start, nl - 1) or text:sub(start)):gsub("\r$", "")
			local t = translateLine(line)
			if t ~= nil then out[#out + 1] = t end
			if not nl then break end
			start = nl + 1
		end
		return t_concat(out, "\n")
	end)
	return ok and result or raw
end

-- Global hook entry point used by the Item constructor.
function translateChineseItem(raw)
	return M.translate(raw)
end

return M
