-- Path of Building
--
-- Module: Build Export (Path of Exile 2 BuildPlanner)
-- Serialises one loadout of the current build into a .build JSON file the
-- in-game BuildPlanner can load.
-- See: https://www.pathofexile.com/developer/docs/game

local ipairs = ipairs
local pairs = pairs
local tostring = tostring
local tonumber = tonumber
local t_insert = table.insert
local t_concat = table.concat
local t_sort = table.sort
local s_format = string.format

local dkjson = require "dkjson"

local M = {}

local function safeFilename(name)
	name = (name and name ~= "") and name or "Unnamed"
	name = name:gsub("[\\/:%*%?\"<>|%c]", "?")
	return name
end

function M.DefaultDir()
	local home = os.getenv("USERPROFILE") or (GetScriptPath() .. "/../") or ""
	local sep = home:find("\\") and "\\" or "/"
	return home .. sep .. "Documents" .. sep .. "My Games" .. sep
	     .. "Path of Exile 2" .. sep .. "BuildPlanner" .. sep
end

function M.DefaultPath(build)
	return M.DefaultDir() .. safeFilename(build.buildName) .. ".build"
end

--- Insert a loadout name before the extension: "My Build.build" -> "My Build - Leveling.build"
function M.LoadoutPath(basePath, loadoutName)
	local suffix = " - " .. safeFilename(loadoutName)
	local stem, ext = basePath:match("^(.*)(%.[^%./\\]*)$")
	if stem then
		return stem .. suffix .. ext
	end
	return basePath .. suffix
end

local function buildAscendancy(spec)
	if not spec or not spec.tree or not spec.curClassId then return nil end
	local class = spec.tree.classes[spec.curClassId]
	if not class or not class.classes or not spec.curAscendClassId then return nil end
	local asc = class.classes[spec.curAscendClassId]
	if not asc or not asc.internalId or asc.internalId == "" then return nil end
	return asc.internalId
end

local function buildPassives(spec)
	local out = {}
	if not spec or not spec.allocNodes then return out end
	local notes = spec.nodeNotes or {}
	for nodeId, node in pairs(spec.allocNodes) do
		local idStr = type(node) == "table" and node.stringId
		-- Skip cluster-jewel synthetic subgraph nodes; they aren't in the
		-- vanilla PassiveSkills table the loader looks up.
		if idStr and type(nodeId) == "number" and nodeId < 65536 then
			local note = notes[nodeId]
			if note and note ~= "" then
				t_insert(out, { id = idStr, additional_text = note })
			else
				-- Bare-string shorthand when there's nothing else to attach.
				t_insert(out, idStr)
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

local function buildSkills(skillSet)
	local out = {}
	if not skillSet or not skillSet.socketGroupList then return out end
	for _, group in ipairs(skillSet.socketGroupList) do
		if group.enabled ~= false and group.gemList and #group.gemList > 0 then
			local activeIdx = tonumber(group.mainActiveSkill) or 1
			local activeGem = group.gemList[activeIdx] or group.gemList[1]
			local activeId = activeGem.gemData?.gameId
			if activeId then
				local entry = { id = activeId }
				local activeText = gemAdditionalText(activeGem, false)
				if activeText then entry.additional_text = activeText end
				local supports = {}
				for _, gem in ipairs(group.gemList) do
					if gem ~= activeGem and gem.enabled ~= false then
						local supId = gem.gemData?.gameId
						if supId then
							local supText = gemAdditionalText(gem, true)
							if supText then
								t_insert(supports, { id = supId, additional_text = supText })
							else
								-- Bare-string shorthand when there's nothing else to attach.
								t_insert(supports, supId)
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

-- Header for non-unique gear. Displays the item's name on two lines, coloured by rarity and shown in a larger text.
-- Usually shows as:
-- Item title
-- Item base name
local function itemHeader(item)
	local rarityCode = colorCodes[item.rarity]
	local colorTag = colorCodeToMarkupColour(rarityCode)
	local itemName = item.name:gsub(", ", "\n")
	return string.format("%s{<b>{%s}}\n", colorTag, itemName)
end

-- Builds a styled hint for non-unique gear. Implicit/rune/enchant mods are
-- italicised to set them apart from explicit mods, matching PoE convention.
local function itemAdditionalText(item)
	local parts = { itemHeader(item) }
	local function appendPlain(modLines)
		if not modLines then return end
		for _, modLine in ipairs(modLines) do
			if modLine.line and modLine.line ~= "" then
				local formatted = itemLib.formatModLine(modLine, nil, true)
				if formatted then
					local colorCode = formatted:match("%^x%x%x%x%x%x%x")
					formatted = formatted:gsub("%^x%x%x%x%x%x%x", "")
					local line = string.format("%s{%s}", colorCodeToMarkupColour(colorCode), stripBraces(formatted))
					t_insert(parts, line)
				end
			end
		end
	end
	appendPlain(item.enchantModLines)
	appendPlain(item.runeModLines)
	appendPlain(item.implicitModLines)
	appendPlain(item.explicitModLines)
	local text = t_concat(parts, "\n")
	return text
end

local function buildItems(itemsTab, itemSet)
	local out = {}
	if not itemsTab or not itemSet then return out end
	for pobSlotName, mapping in pairs(data.buildFileInventorySlotMap) do
		local slotEntry = itemSet[pobSlotName]
		local item = slotEntry and slotEntry.selItemId and slotEntry.selItemId ~= 0
			and itemsTab.items[slotEntry.selItemId]
		local note = slotEntry and slotEntry.note ~= "" and slotEntry.note
		if item or note then
			local entry = {
				inventory_id = mapping.id,
				slot_x = mapping.slot_x,
			}
			-- the unique_name field shows a larger header when you don't have the matching unique
			-- equipped in the slot, but since we show the full item name in the additional
			-- text, it doesn't really do anything useful here
			if item then
				entry.additional_text = itemAdditionalText(item)
				if note then
					entry.additional_text = entry.additional_text .. "\n\n" .. note
				end
			else
				entry.additional_text = note
			end

			t_insert(out, entry)
		end
	end
	return out
end

--- Resolve a selection into the actual spec/skill set/item set to export.
--- Any field left unset falls back to whatever is currently active.
--- selection = { specIndex = n, skillSetId = id, itemSetId = id }
function M.ResolveSelection(build, selection)
	selection = selection or {}
	local treeTab, skillsTab, itemsTab = build.treeTab, build.skillsTab, build.itemsTab
	local spec = treeTab and (treeTab.specList[selection.specIndex])
	local skillSet = skillsTab and (skillsTab.skillSets[selection.skillSetId])
	local itemSet = itemsTab and (itemsTab.itemSets[selection.itemSetId])
	return spec, skillSet, itemSet
end

function M.GetLoadouts(build)
	local out = {}
	ConPrintf("%s, %s, %s", build.treeTab, build.skillsTab, build.itemsTab)
	if not (build.treeTab and build.skillsTab and build.itemsTab) then return out end
	build:SyncLoadouts(true)
	for _, displayName in ipairs(build.controls.buildLoadouts.list) do
		ConPrintf("%s", displayName)
		if not displayName:find("^%^7%^7") then
			local loadout = build:GetLoadoutByName(displayName)
			local plainName = displayName:gsub(" {.-}$", "")
			t_insert(out, {
				name = plainName,
				specIndex = loadout.specId,
				skillSetId = loadout.skillSetId,
				itemSetId = loadout.itemSetId,
			})
		end
	end
	return out
end

--- Build the in-memory table that will be JSON-encoded as the .build file.
--- Exposed for testing.
function M.BuildTable(build, metadata, selection)
	metadata = metadata or {}
	local spec, skillSet, itemSet = M.ResolveSelection(build, selection)
	local root = {
		name = (metadata.name and metadata.name ~= "") and metadata.name
			or ((build.buildName and build.buildName ~= "") and build.buildName or "Unnamed"),
	}
	local ascendancy = buildAscendancy(spec)
	if ascendancy then root.ascendancy = ascendancy end
	root.author = metadata.author
	root.description = metadata.description

	root.passives = buildPassives(spec)
	root.skills = buildSkills(skillSet)
	root.inventory_slots = buildItems(build.itemsTab, itemSet)
	return root
end

--- Returns (jsonString, nil) on success, or (nil, errorMessage) on failure.
function M.Export(build, metadata, selection)
	local root = M.BuildTable(build, metadata, selection)
	-- Force array-ness on the three top-level lists even when empty so the
	-- loader sees `[]` instead of `{}`.
	local state = { indent = true, level = 0 }
	local json, err = dkjson.encode(root, state)
	if not json then return nil, "JSON encode failed: " .. tostring(err) end
	return json
end

--- Writes one loadout to disk. Returns (path, nil) on success.
function M.WriteFile(build, path, metadata, selection)
	local json, err = M.Export(build, metadata, selection)
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

--- Write every loadout to "build - loadout.build"
function M.WriteAllLoadouts(build, basePath, metadata, loadouts)
	local written = {}
	local errors = {}
	loadouts = loadouts or M.GetLoadouts(build)
	if #loadouts == 0 then
		return written, { "This build has no passive trees to export." }
	end
	for _, loadout in ipairs(loadouts) do
		local path = M.LoadoutPath(basePath, loadout.name)
		local loadoutMeta = {
			name = s_format("%s - %s", metadata and metadata.name or build.buildName, loadout.name),
			author = metadata and metadata.author,
			description = metadata and metadata.description,
		}
		local ok, err = M.WriteFile(build, path, loadoutMeta, loadout)
		if ok then
			t_insert(written, ok)
		else
			t_insert(errors, err)
		end
	end
	return written, errors
end
return M
