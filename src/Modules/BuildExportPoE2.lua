-- Path of Building
--
-- Module: Build Export (Path of Exile 2 BuildPlanner)
-- Serialises the current build into a .build JSON file the in-game
-- BuildPlanner can load. See: https://www.pathofexile.com/developer/docs/game
--

local ipairs = ipairs
local pairs = pairs
local tostring = tostring
local tonumber = tonumber
local t_insert = table.insert
local t_concat = table.concat
local m_floor = math.floor
local m_min = math.min
local m_max = math.max
local s_format = string.format
local s_gsub = string.gsub

local dkjson = require "dkjson"

local M = {}

-- PoB internal slot name -> { inventory_id, weapon_set? }
-- inventory_id values for slots other than Weapon1 are educated guesses; only
-- "Weapon1" is documented by GGG. Verify against a sample .build exported from
-- the live game before relying on these in shipped builds.
M.SlotMap = {
	["Weapon 1"]      = { inventory_id = "Weapon1" },
	["Weapon 2"]      = { inventory_id = "Weapon2" },
	["Weapon 1 Swap"] = { inventory_id = "Weapon1", weapon_set = 2 },
	["Weapon 2 Swap"] = { inventory_id = "Weapon2", weapon_set = 2 },
	["Helmet"]        = { inventory_id = "Helm" },
	["Body Armour"]   = { inventory_id = "BodyArmour" },
	["Gloves"]        = { inventory_id = "Gloves" },
	["Boots"]         = { inventory_id = "Boots" },
	["Amulet"]        = { inventory_id = "Amulet" },
	["Ring 1"]        = { inventory_id = "Ring" },
	["Ring 2"]        = { inventory_id = "Ring2" },
	["Ring 3"]        = { inventory_id = "Ring3" },
	["Belt"]          = { inventory_id = "Belt" },
	["Charm 1"]       = { inventory_id = "Charm1" },
	["Charm 2"]       = { inventory_id = "Charm2" },
	["Charm 3"]       = { inventory_id = "Charm3" },
	["Flask 1"]       = { inventory_id = "Flask1" },
	["Flask 2"]       = { inventory_id = "Flask2" },
}

-- Default level brackets when the user hasn't set levelMin/Max on a set.
-- Indexed by total number of sets; falls back to a uniform split otherwise.
local presetBrackets = {
	[2] = { {1, 50},  {50, 100} },
	[3] = { {1, 33},  {33, 66},  {66, 100} },
	[4] = { {1, 30},  {30, 60},  {60, 90},  {90, 100} },
}

local function clampLevel(v)
	v = tonumber(v)
	if not v then return nil end
	v = m_floor(v)
	if v < 0 then v = 0 end
	if v > 100 then v = 100 end
	return v
end

local function autoBracket(i, n)
	if presetBrackets[n] then
		return presetBrackets[n][i]
	end
	local lo = (i == 1) and 1 or (m_floor((i - 1) / n * 99) + 1)
	local hi = (i == n) and 100 or m_floor(i / n * 99)
	return { lo, hi }
end

-- bracketsFor(orderList, getEntry) -> { [orderIndex] = {min, max} | nil, ... } | nil
-- Returns nil when there's only one set (caller should omit level_interval).
-- When some sets are explicitly tagged and others aren't, the untagged ones
-- intentionally return nil (no level_interval) — the loader treats them as
-- "applies at all levels", which is what a build-author usually means when
-- they tag a leveling loadout but leave the main build untagged.
local function bracketsFor(orderList, getEntry)
	local n = orderList and #orderList or 0
	if n <= 1 then return nil end
	local hasAnyExplicit = false
	for _, id in ipairs(orderList) do
		local entry = getEntry(id)
		if entry and entry.levelMin and entry.levelMax then
			hasAnyExplicit = true
			break
		end
	end
	local out = {}
	for i, id in ipairs(orderList) do
		local entry = getEntry(id)
		local lo = entry and clampLevel(entry.levelMin)
		local hi = entry and clampLevel(entry.levelMax)
		if lo and hi then
			if lo > hi then lo, hi = hi, lo end
			out[i] = { lo, hi }
		elseif hasAnyExplicit then
			out[i] = nil
		end
	end
	return out
end

local function safeFilename(name)
	name = (name and name ~= "") and name or "Unnamed"
	name = s_gsub(name, "[\\/:%*%?\"<>|%c]", "-")
	return name
end

--- Compute a default (lo, hi) for a new loadout: the next 30-level chunk after
--- the highest existing levelMax found across tree specs, item sets and skill sets.
--- Returns (1, 30) when nothing has been tagged yet.
--- @param build table The build (must have treeTab/itemsTab/skillsTab).
--- @return number lo
--- @return number hi
function M.NextLoadoutBracket(build)
	local maxLvl = 0
	local function consider(entry)
		if entry and entry.levelMax and entry.levelMax > maxLvl then
			maxLvl = entry.levelMax
		end
	end
	if build.treeTab and build.treeTab.specList then
		for _, spec in ipairs(build.treeTab.specList) do consider(spec) end
	end
	if build.itemsTab and build.itemsTab.itemSetOrderList then
		for _, id in ipairs(build.itemsTab.itemSetOrderList) do
			consider(build.itemsTab.itemSets[id])
		end
	end
	if build.skillsTab and build.skillsTab.skillSetOrderList then
		for _, id in ipairs(build.skillsTab.skillSetOrderList) do
			consider(build.skillsTab.skillSets[id])
		end
	end
	if maxLvl == 0 then return 1, 30 end
	return maxLvl, m_min(maxLvl + 30, 100)
end

--- Preset the new loadout's levelMin/levelMax to the next 30-level chunk
--- after the highest existing levelMax (e.g. [1,30] -> [30,60] -> [60,90] -> [90,100]).
--- If no existing entry has levels set, seeds the first existing entry to [1, 30]
--- so the new one fits a clean chain.
--- @param existingEntries table Array of entry objects (NOT including newEntry) with optional levelMin/levelMax.
--- @param newEntry table The entry to populate.
function M.PresetNextLevels(existingEntries, newEntry)
	local maxLvl = 0
	local anyHas = false
	for _, entry in ipairs(existingEntries or {}) do
		if entry.levelMax then
			anyHas = true
			if entry.levelMax > maxLvl then maxLvl = entry.levelMax end
		end
	end
	if not anyHas then
		local first = existingEntries and existingEntries[1]
		if first and not first.levelMin and not first.levelMax then
			first.levelMin = 1
			first.levelMax = 30
			maxLvl = 30
		end
	end
	if maxLvl == 0 then
		newEntry.levelMin = 1
		newEntry.levelMax = 30
	else
		newEntry.levelMin = maxLvl
		newEntry.levelMax = m_min(maxLvl + 30, 100)
	end
end

function M.DefaultDir()
	local home = os.getenv("USERPROFILE") or os.getenv("HOME") or ""
	local sep = home:find("\\") and "\\" or "/"
	return home .. sep .. "Documents" .. sep .. "My Games" .. sep
	     .. "Path of Exile 2" .. sep .. "BuildPlanner" .. sep
end

function M.DefaultPath(build)
	return M.DefaultDir() .. safeFilename(build.buildName) .. ".build"
end

local function buildAscendancy(build)
	local spec = build.spec
	if not spec or not spec.tree or not spec.curClassId then return nil end
	local class = spec.tree.classes[spec.curClassId]
	if not class or not class.classes or not spec.curAscendClassId then return nil end
	local asc = class.classes[spec.curAscendClassId]
	if not asc or not asc.internalId or asc.internalId == "" then return nil end
	return asc.internalId
end

local function buildPassives(build, brackets)
	local specList = build.treeTab and build.treeTab.specList
	if not specList then return {} end
	-- Dedupe by node id: collect contributing intervals + node refs across specs.
	-- "Always" (no interval) wins — if any contributing spec is untagged, the
	-- merged entry has no level_interval. Otherwise the merged interval covers
	-- the union span (min lo, max hi) of all contributing specs.
	local merged = {}
	local order = {}
	for specIdx, spec in ipairs(specList) do
		local interval = brackets and brackets[specIdx]
		local notes = spec.nodeNotes or {}
		for nodeId, node in pairs(spec.allocNodes) do
			-- Skip cluster-jewel synthetic subgraph nodes; they aren't in the
			-- vanilla PassiveSkills table the loader looks up.
			if type(nodeId) == "number" and nodeId < 65536 then
				local nodeTable = type(node) == "table" and node or nil
				local note = notes[nodeId]
				local existing = merged[nodeId]
				if existing == nil then
					merged[nodeId] = {
						node = nodeTable,
						interval = interval and { interval[1], interval[2] } or false,
						note = (note and note ~= "") and note or nil,
					}
					t_insert(order, nodeId)
				else
					if not existing.node and nodeTable then existing.node = nodeTable end
					-- First non-empty note wins.
					if not existing.note and note and note ~= "" then existing.note = note end
					if existing.interval == false then
						-- Already "always" - nothing to do.
					elseif interval == nil then
						existing.interval = false
					else
						if interval[1] < existing.interval[1] then existing.interval[1] = interval[1] end
						if interval[2] > existing.interval[2] then existing.interval[2] = interval[2] end
					end
				end
			end
		end
	end
	local out = {}
	for _, nodeId in ipairs(order) do
		local m = merged[nodeId]
		local idStr = (m.node and m.node.stringId)
		if idStr then
			if not m.interval and not m.note then
				-- Bare-string shorthand when there's nothing else to attach.
				t_insert(out, idStr)
			else
				local entry = { id = idStr }
				if m.interval then entry.level_interval = { m.interval[1], m.interval[2] } end
				if m.note then entry.additional_text = m.note end
				t_insert(out, entry)
			end
		end
	end
	return out
end

-- Build the additional_text for a gem instance. An author-set note (via
-- Shift+Right-Click on the gem) takes precedence; otherwise falls back to a
-- "Level N[, Q% Quality]" hint so the loader has something useful to show.
-- The .build schema has no level field on BuildSkill/BuildSupport, so this is
-- the only channel for either piece of info.
--
-- Support gems get the trivial "Level 1, 0% Quality" hint suppressed - that's
-- the default PoB assigns when a support is first placed and showing it on
-- every uncustomised support is just noise. Custom level/quality and notes
-- still come through.
local function gemAdditionalText(gem, isSupport)
	if not gem then return nil end
	if gem.note and gem.note ~= "" then
		return gem.note
	end
	local level = tonumber(gem.level)
	if not level or level <= 0 then return nil end
	local quality = tonumber(gem.quality) or 0
	if isSupport and level == 1 and quality == 0 then
		return nil
	end
	if quality > 0 then
		return "Level " .. tostring(level) .. ", " .. tostring(quality) .. "% Quality"
	end
	return "Level " .. tostring(level)
end

local function buildSkills(build, brackets)
	local out = {}
	local skillsTab = build.skillsTab
	if not skillsTab or not skillsTab.skillSets then return out end
	local orderList = skillsTab.skillSetOrderList or {}
	for setIdx, setId in ipairs(orderList) do
		local skillSet = skillsTab.skillSets[setId]
		local interval = brackets and brackets[setIdx] or nil
		if skillSet and skillSet.socketGroupList then
			for _, group in ipairs(skillSet.socketGroupList) do
				if group.enabled ~= false and group.gemList and #group.gemList > 0 then
					local activeIdx = tonumber(group.mainActiveSkill) or 1
					local activeGem = group.gemList[activeIdx] or group.gemList[1]
					local activeId = activeGem.gemData.gameId
					if activeId then
						local entry = { id = activeId }
						if interval then entry.level_interval = { interval[1], interval[2] } end
						local activeText = gemAdditionalText(activeGem, false)
						if activeText then entry.additional_text = activeText end
						local supports = {}
						for gi, gem in ipairs(group.gemList) do
							if gem ~= activeGem and gem.enabled ~= false then
								local supId = gem.gemData.gameId
								if supId then
									local supText = gemAdditionalText(gem, true)
									if not interval and not supText then
										-- Bare-string shorthand when there's nothing else to attach.
										t_insert(supports, supId)
									else
										local sup = { id = supId }
										if interval then sup.level_interval = { interval[1], interval[2] } end
										if supText then sup.additional_text = supText end
										t_insert(supports, sup)
									end
								else
									ConPrintf("[PoE2Export] skipping support gem with no id in group '%s'", tostring(group.label or "?"))
								end
							end
						end
						if #supports > 0 then entry.support_skills = supports end
						t_insert(out, entry)
					else
						ConPrintf("[PoE2Export] skipping active gem with no id in group '%s'", tostring(group.label or "?"))
					end
				end
			end
		end
	end
	return out
end

-- additional_text uses PoE2's Custom Text markup (see
-- https://www.pathofexile.com/developer/docs/game#buildplanner):
--   <bold>{ text }    <italic>{ text }    <red>{ text }    <rgb(R,G,B)>{ text }
-- The format uses { } as delimiters, so any stray braces in mod text must be
-- stripped to avoid breaking the parser.
local function stripBraces(s)
	if not s then return "" end
	return (s:gsub("[{}]", ""))
end

local function titleCaseRarity(r)
	if not r or r == "" then return "Item" end
	return r:sub(1, 1):upper() .. r:sub(2):lower()
end

-- Header for non-unique gear. Bold the item's name; for rares with a rolled
-- title (e.g. "Mire Spike"), put the base type on the next line. Examples:
--   <b>{Mire Spike}\nAncestral Tiara     (rare with a rolled title)
--   <b>{Magic Ultimate Mana Flask}        (magic)
--   <b>{Ancestral Tiara}                  (normal)
local function itemHeader(item)
	local title = item.title
	local base = item.baseName
	if title and title ~= "" and base and title ~= base then
		return "<b>{" .. stripBraces(title) .. "}\n" .. stripBraces(base)
	elseif title and title ~= "" then
		return "<b>{" .. stripBraces(title) .. "}"
	elseif base then
		if item.rarity and item.rarity ~= "NORMAL" then
			return "<b>{" .. titleCaseRarity(item.rarity) .. " " .. stripBraces(base) .. "}"
		end
		return "<b>{" .. stripBraces(base) .. "}"
	end
	return "<b>{" .. titleCaseRarity(item.rarity) .. "}"
end

-- Builds a styled hint for non-unique gear. Implicit/rune/enchant mods are
-- italicised to set them apart from explicit mods, matching PoE convention.
local function itemAdditionalText(item)
	local parts = { itemHeader(item) }
	local function appendItalic(modLines)
		if not modLines then return end
		for _, modLine in ipairs(modLines) do
			if modLine.line and modLine.line ~= "" then
				t_insert(parts, "<i>{" .. stripBraces(modLine.line) .. "}")
			end
		end
	end
	local function appendPlain(modLines)
		if not modLines then return end
		for _, modLine in ipairs(modLines) do
			if modLine.line and modLine.line ~= "" then
				t_insert(parts, stripBraces(modLine.line))
			end
		end
	end
	appendItalic(item.enchantModLines)
	appendItalic(item.runeModLines)
	appendItalic(item.implicitModLines)
	appendPlain(item.explicitModLines)
	local text = t_concat(parts, "\n")
	if #text > 600 then text = text:sub(1, 597) .. "..." end
	return text
end

local function uniqueNameOf(item)
	-- For UNIQUE/RELIC items, Item.lua stores the first line of the unique
	-- entry (the GGG Words-table key) in self.title; fall back to .name.
	return item.title or item.name
end

local function buildItems(build)
	local out = {}
	local itemsTab = build.itemsTab
	if not itemsTab or not itemsTab.itemSets then return out end
	local orderList = itemsTab.itemSetOrderList or {}
	for _, setId in ipairs(orderList) do
		local itemSet = itemsTab.itemSets[setId]
		if itemSet then
			for pobSlotName, mapping in pairs(data.buildFileInventorySlotMap) do
				local slotEntry = itemSet[pobSlotName]
				if slotEntry and (slotEntry.selItemId or slotEntry.note) then
					local item = itemsTab.items[slotEntry.selItemId]
					local entry = {
						inventory_id = mapping.id,
						slot_x = mapping.slot_x,
					}
					if interval then entry.level_interval = { interval[1], interval[2] } end
					if item and (item.rarity == "UNIQUE" or item.rarity == "RELIC") then
						local name = uniqueNameOf(item)
						if name and name ~= "" and name ~= "?" then
							entry.unique_name = name
						end
					end
					entry.additional_text = slotEntry.note or (item and itemAdditionalText(item))

					t_insert(out, entry)
				end
			end
		end
	end
	return out
end

local function getItemSet(itemsTab, id)
	return itemsTab.itemSets[id]
end
local function getSkillSet(skillsTab, id)
	return skillsTab.skillSets[id]
end

--- Build the in-memory table that will be JSON-encoded as the .build file.
--- Exposed for testing.
function M.BuildTable(build)
	local root = {
		name = (build.buildName and build.buildName ~= "") and build.buildName or "Unnamed",
	}
	local ascendancy = buildAscendancy(build)
	if ascendancy then root.ascendancy = ascendancy end

	-- Bracket each section independently so users can tag tree/items/skills
	-- with different level ranges without forcing the set counts to match.
	local treeBrackets = nil
	if build.treeTab and build.treeTab.specList and #build.treeTab.specList > 1 then
		local pseudoOrder = {}
		for i = 1, #build.treeTab.specList do pseudoOrder[i] = i end
		treeBrackets = bracketsFor(pseudoOrder, function(i) return build.treeTab.specList[i] end)
	end
	local skillBrackets = nil
	if build.skillsTab and build.skillsTab.skillSetOrderList then
		skillBrackets = bracketsFor(build.skillsTab.skillSetOrderList, function(id) return getSkillSet(build.skillsTab, id) end)
	end
	local itemBrackets = nil
	if build.itemsTab and build.itemsTab.itemSetOrderList then
		itemBrackets = bracketsFor(build.itemsTab.itemSetOrderList, function(id) return getItemSet(build.itemsTab, id) end)
	end

	root.passives = buildPassives(build, treeBrackets)
	root.skills   = buildSkills(build, skillBrackets)
	root.inventory_slots    = buildItems(build, itemBrackets)
	return root
end

--- Returns (jsonString, nil) on success, or (nil, errorMessage) on failure.
function M.Export(build)
	local root = M.BuildTable(build)
	-- Force array-ness on the three top-level lists even when empty so the
	-- loader sees `[]` instead of `{}`.
	local state = { indent = true, level = 0 }
	local json, err = dkjson.encode(root, state)
	if not json then return nil, "JSON encode failed: " .. tostring(err) end
	return json
end

--- Writes the exported build to disk. Returns (path, nil) on success.
function M.WriteFile(build, path)
	local json, err = M.Export(build)
	if not json then return nil, err end
	-- Best-effort: ensure the target directory exists.
	local dir = path:match("^(.*[/\\])")
	if dir then MakeDir(dir) end
	local f, ferr = io.open(path, "w")
	if not f then return nil, "Couldn't open '" .. path .. "': " .. tostring(ferr) end
	f:write(json)
	f:close()
	return path
end

return M
