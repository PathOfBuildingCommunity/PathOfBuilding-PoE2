-- Path of Building
--
-- Class: Item
-- Equippable item class
--
local ipairs = ipairs
local t_insert = table.insert
local t_remove = table.remove
local m_min = math.min
local m_max = math.max
local m_floor = math.floor

local dmgTypeList = {"Physical", "Lightning", "Cold", "Fire", "Chaos"}
local catalystList = {"Flesh", "Neural", "Carapace", "Uul-Netol's", "Xoph's", "Tul's", "Esh's", "Chayula's", "Reaver", "Sibilant", "Skittering", "Adaptive", "Necrotic"}
local catalystDescriptorList = {"Life", "Mana", "Defence", "Physical", "Fire", "Cold", "Lightning", "Chaos", "Attack", "Caster", "Speed", "Attribute", "Minion"}
local catalystTags = {
	{ "life" },
	{ "mana" },
	{ "defences", "armour", "evasion", "energyshield" },
	{ "physical" },
	{ "fire" },
	{ "cold" },
	{ "lightning" },
	{ "chaos" },
	{ "attack" },
	{ "caster" },
	{ "speed" },
	{ "attribute" },
	{ "minion" },
}

local function getCatalystScalar(catalystId, mod, quality)
	if mod.unscalable then
		return 1
	end
	local tags = mod.modTags
	if not catalystId or type(catalystId) ~= "number" or not catalystTags[catalystId] or not tags or type(tags) ~= "table" or #tags == 0 then
		return 1
	end
	if not quality then
		quality = 20
	end

	-- Create a fast lookup table for all provided tags
	local tagLookup = {}
	for _, curTag in ipairs(tags) do
		tagLookup[curTag] = true;
	end
	-- these aren't actual mod tags but do sinistral/dextral catalyst
	for _, lineFlag in ipairs({ "prefix", "suffix" }) do
		if mod[lineFlag] then
			tagLookup[lineFlag] = true
		end
	end

	-- Find if any of the catalyst's tags match the provided tags
	for _, catalystTag in ipairs(catalystTags[catalystId]) do
		if tagLookup[catalystTag] then
			return (100 + quality) / 100
		end
	end
	return 1
end

local function normaliseModLine(line)
	return line:gsub("%d+%.?%d*", "#")
		:gsub("%(%-?#%-#%)", "#"):lower()
		:gsub("\n", " ")
end

local uniqueModStatOrder

local function sortCraftedModLines(modLines)
	local sourceOrder = { }
	for index, modLine in ipairs(modLines) do
		sourceOrder[modLine] = index
	end
	table.sort(modLines, function(a, b)
		local aGroup = (a.crafted or a.custom) and 3 or a.fractured and 1 or 2
		local bGroup = (b.crafted or b.custom) and 3 or b.fractured and 1 or 2
		if aGroup ~= bGroup then
			return aGroup < bGroup
		elseif aGroup < 3 and a.order ~= b.order then
			return (a.order or math.huge) < (b.order or math.huge)
		end
		return sourceOrder[a] < sourceOrder[b]
	end)
end

---@class Item
local ItemClass = newClass("Item")

function ItemClass:Item(raw, rarity, highQuality)
	if raw then
		self:ParseRaw(sanitiseText(raw), rarity, highQuality)
	end
	return self
end

---@enum (key) LineFlags
local lineFlags = {
	["crafted"] = true,
	["custom"] = true,
	["disabled"] = true,
	["enchant"] = true,
	["fractured"] = true,
	["implicit"] = true,
	["desecrated"] = true,
	["mutated"] = true,
	["rune"] = true,
	["unscalable"] = true,
	["prefix"] = true,
	["suffix"] = true,
}

local function baseHasImplicitLine(base, line)
	if not base or not base.implicit then
		return false
	end
	for implicitLine in base.implicit:gmatch("[^\n]+") do
		if implicitLine:match("^Grants Skill:") and (implicitLine == line or line:match("^" .. implicitLine:gsub("%(%d+%-%d+%)", "%%d+") .. "$")) then
			return true
		end
	end
	return false
end

-- Special function to store unique instances of modifier on specific item slots
-- that require special handling for ItemConditions. Only called if line #224 is
-- uncommented
local specialModifierFoundList = {}
local inverseModifierFoundList = {}
local function getTagBasedModifiers(tagName, itemSlotName)
	local tag_name = tagName:lower()
	local slot_name = itemSlotName:lower():gsub(" ", "_")
	-- iterate all the item modifiers
	for k,v in pairs(data.itemMods.Item) do
		-- iterate across the modifier tags for each modifier
		for _,tag in ipairs(v.modTags) do
			-- if tag matches the tag_name we are investigating
			if tag:lower() == tag_name then
				local found = false
				-- if there is a valid weightKey table
				if #v.weightKey > 0 then
					for _,wk in ipairs(v.weightKey) do
						-- and it matches the slot_name of the item we are investigating
						if wk == slot_name then
							for _, dv in ipairs(v) do
								-- and the modifier description contains the tag_name keyword
								if dv:lower():find(tag_name) then
									found = true
									break
								else
									local excluded = false
									if data.itemTagSpecial[tagName] and data.itemTagSpecial[tagName][itemSlotName] then
										for _, specialMod in ipairs(data.itemTagSpecial[tagName][itemSlotName]) do
											if dv:lower():find(specialMod:lower()) then
												exclude = true
												break
											end
										end
									end
									if exclude then
										found = true
										break
									end
								end
							end
							if not found and not specialModifierFoundList[k] then
								specialModifierFoundList[k] = true
								ConPrintf("[%s] [%s] ENTRY: %s", tagName, itemSlotName, k)
							end
						end
					end
				else
					for _, dv in ipairs(v) do
						if dv:lower():find(tag_name) then
							found = true
							break
						else
							local excluded = false
							if data.itemTagSpecial[tagName] and data.itemTagSpecial[tagName][itemSlotName] then
								for _, specialMod in ipairs(data.itemTagSpecial[tagName][itemSlotName]) do
									if dv:lower():find(specialMod:lower()) then
										exclude = true
										break
									end
								end
							end
							if exclude then
								found = true
								break
							end
						end
					end
					if not found and not specialModifierFoundList[k] then
						specialModifierFoundList[k] = true
						ConPrintf("[%s] ENTRY: %s", tagName, k)
					end
				end
			end
		end
		for _, dv in ipairs(v) do
			if dv:lower():find(tag_name) then
				local found_2 = false
				if #v.weightKey > 0 then
					for _,wk in ipairs(v.weightKey) do
						if wk == slot_name then
							-- this is useless if the modTags = { } (is empty)
							if #v.modTags > 0 then
								for _,tag in ipairs(v.modTags) do
									if tag:lower() == tag_name then
										found_2 = true
										break
									else
										local excluded = false
										-- if we have an exclusion pattern list for that tagName and itemSlotName
										if data.itemTagSpecialExclusionPattern[tagName] and data.itemTagSpecialExclusionPattern[tagName][itemSlotName] then
											-- iterate across the exclusion patterns
											for _, specialMod in ipairs(data.itemTagSpecialExclusionPattern[tagName][itemSlotName]) do
												-- and if the description matches pattern exclude it
												if dv:lower():find(specialMod:lower()) then
													excluded = true
													break
												end
											end
										end
										if excluded then
											found_2 = true
											break
										end
									end
								end
								if not found_2 and not inverseModifierFoundList[k] then
									inverseModifierFoundList[k] = true
									ConPrintf("[%s] appears in desc but not in tags. [%s] %s", tag_name, k, dv)
									break
								end
							end
						end
					end
				else
					-- this is useless if the modTags = { } (is empty)
					if #v.modTags > 0 then
						for _,tag in ipairs(v.modTags) do
							if tag:lower() == tag_name then
								found_2 = true
								break
							else
								local excluded = false
								-- if we have an exclusion pattern list for that tagName and itemSlotName
								if data.itemTagSpecialExclusionPattern[tagName] and data.itemTagSpecialExclusionPattern[tagName][itemSlotName] then
									-- iterate across the exclusion patterns
									for _, specialMod in ipairs(data.itemTagSpecialExclusionPattern[tagName][itemSlotName]) do
										-- and if the description matches pattern exclude it
										if dv:lower():find(specialMod:lower()) then
											excluded = true
											break
										end
									end
								end
								if excluded then
									found_2 = true
									break
								end
							end
						end
						if not found_2 and not inverseModifierFoundList[k] then
							inverseModifierFoundList[k] = true
							ConPrintf("[%s] appears in desc but not in tags. [%s] %s", tag_name, k, dv)
						end
					end
				end
			end
		end
	end
end

-- Iterate over modifiers to see if specific substring is found (for conditional checking)
function ItemClass:FindModifierSubstring(substring, itemSlotName)
	local modLines = {}
	local substring, explicit = substring:gsub("explicit ", "")

	-- The commented out line below is used at GGPK updates to check if any new modifiers
	-- have been identified that need to be added to the manually maintained special modifier
	-- pool in Data.lua (data.itemTagSpecial and data.itemTagSpecialExclusionPattern tables)
	--getTagBasedModifiers(substring, itemSlotName)

	-- merge various modifier lines into one table
	for _,v in pairs(self.explicitModLines) do t_insert(modLines, v) end
	if explicit < 1 then
		for _,v in pairs(self.enchantModLines) do t_insert(modLines, v) end
		for _,v in pairs(self.implicitModLines) do t_insert(modLines, v) end
	end

	for _,v in pairs(modLines) do
		if not v.disabled and self:CheckModLineVariant(v) then
			if v.line:lower():find(substring) and not v.line:lower():find(substring .. " modifier") then
				local excluded = false
				if data.itemTagSpecialExclusionPattern[substring] and data.itemTagSpecialExclusionPattern[substring][itemSlotName] then
					for _, specialMod in ipairs(data.itemTagSpecialExclusionPattern[substring][itemSlotName]) do
						if v.line:lower():find(specialMod:lower()) then
							excluded = true
							break
						end
					end
				end
				if not excluded then
					return true
				end
			end
			if data.itemTagSpecial[substring] and data.itemTagSpecial[substring][itemSlotName] then
				for _, specialMod in ipairs(data.itemTagSpecial[substring][itemSlotName]) do
					if v.line:lower():find(specialMod:lower()) then
						return true
					end
				end
			end
		end
	end
	return false
end

local function specToNumber(s)
	local n = s:match("^([%+%-]?[%d%.]+)")
	return n and tonumber(n)
end

local function parseItemSpec(line)
	local specName, specVal = line:match("^([%a %(%)]+:?): (.+)$")
	if specName == "Class:" then
		specName = "Requires Class"
	elseif not specName then
		specName, specVal = line:match("^(Requires %a+) (.+)$")
	end
	return specName, specVal
end

local function parseIdSpec(spec, positiveOnly)
	local ids = { }
	for id in (spec or ""):gmatch("%d+") do
		id = tonumber(id)
		if not positiveOnly or id > 0 then
			ids[id] = true
		end
	end
	return ids
end

local variantSelectionSpecNames = {
	["Version"] = true,
	["Variant"] = true,
	["Selected Version"] = true,
	["Selected Variant Group"] = true,
	["Selected Variant"] = true,
}

function ItemClass:HasVariantGroups()
	return self.variantGroups and next(self.variantGroups) ~= nil or false
end

function ItemClass:HasIndependentVariants()
	return self.versionList ~= nil and self.variantList ~= nil and not self:HasVariantGroups()
end

function ItemClass:UsesVersionedOrGroupedVariants()
	return self.versionList ~= nil or self:HasVariantGroups()
end

function ItemClass:IsVariantGroupOptionEligible(groupId, variantId)
	local group = self.variantGroups and self.variantGroups[groupId]
	local versions = group and group[variantId]
	return versions and (versions[0] or self.selectedVersion and versions[self.selectedVersion]) or false
end

function ItemClass:GetVariantGroupOptions(groupId, excludeSelected)
	local options = { }
	if not self.variantGroups or not self.variantGroups[groupId] then
		return options
	end
	local used = { }
	if excludeSelected then
		for otherGroupId in pairsSortByKey(self.variantGroups) do
			if otherGroupId ~= groupId then
				local variantId = self.variantGroupSelections[otherGroupId]
				if variantId and self:IsVariantGroupOptionEligible(otherGroupId, variantId) then
					used[variantId] = true
				end
			end
		end
	end
	for variantId = 1, #self.variantList do
		if self:IsVariantGroupOptionEligible(groupId, variantId) and not used[variantId] then
			t_insert(options, variantId)
		end
	end
	return options
end

function ItemClass:NormaliseVariantSelections()
	if self.versionList and #self.versionList > 0 then
		self.selectedVersion = m_max(1, m_min(#self.versionList, self.selectedVersion or #self.versionList))
	else
		self.selectedVersion = nil
	end
	if self:HasIndependentVariants() then
		self.variant = m_max(1, m_min(#self.variantList, self.variant or #self.variantList))
	end
	self.variantGroupSelections = self.variantGroupSelections or { }
	for groupId in pairs(self.variantGroupSelections) do
		if not self.variantGroups[groupId] then
			self.variantGroupSelections[groupId] = nil
		end
	end

	local used = { }
	local needsSelection = { }
	for groupId in pairsSortByKey(self.variantGroups) do
		if #self:GetVariantGroupOptions(groupId, false) > 0 then
			local selected = self.variantGroupSelections[groupId]
			if selected and self:IsVariantGroupOptionEligible(groupId, selected) and not used[selected] then
				used[selected] = true
			else
				t_insert(needsSelection, groupId)
			end
		end
	end
	for _, groupId in ipairs(needsSelection) do
		local selected
		for _, variantId in ipairs(self:GetVariantGroupOptions(groupId, false)) do
			if not used[variantId] then
				selected = variantId
				break
			end
		end
		self.variantGroupSelections[groupId] = selected
		if selected then
			used[selected] = true
		end
	end
end

function ItemClass:GetUniqueDBItem()
	if (self.rarity == "UNIQUE" or self.rarity == "RELIC") and main.uniqueDB then
		local dbItem = main.uniqueDB.list[self.name]
		if not dbItem and self.title and self.baseName then
			local originalBaseName = self.baseName:match("^Runeforged (.+)") or self.baseName:match("^Runemastered (.+)")
			dbItem = originalBaseName and main.uniqueDB.list[self.title .. ", " .. originalBaseName]
		end
		return dbItem
	end
end
---@class ModLine A modifier line on an item. An in-game mod can translate to multiple ModLines.
---@field modList Mod[]
---@field line string The actual text for the line. This might describe a range of values, in which case applyRange() can be used with this and the range value to get a ranged line.
---@field range number?
---@field extra string?
---@field valueScalar number?
---@field [LineFlags] boolean?
---@field modTags string[]?
---@field variantList table<number, boolean>?
---@field versionList table<number, boolean>?
---@field variantGroupList table<number, boolean>?
---@field modId string?

local getRangedModList
-- Parse raw item data and extract item name, base type, quality, and modifiers
function ItemClass:ParseRaw(raw, rarity, highQuality)
	self.raw = raw
	self.name = "?"
	self.namePrefix = ""
	self.nameSuffix = ""
	self.base = nil
	self.rarity = rarity or "UNIQUE"
	self.charmLimit = nil
	self.spiritValue = nil
	self.runicItem = nil
	self.quality = nil
	self.rawLines = { }
	-- Find non-blank lines and trim whitespace
	for line in raw:gmatch("%s*([^\n]*%S)") do
		line = escapeGGGString(line)
		t_insert(self.rawLines, line)
	end
	local mode = rarity and "GAME" or "WIKI"
	local l = 1
	local itemClass
	if self.rawLines[l] then
		if self.rawLines[l]:match("^Item Class:") then
			itemClass = self.rawLines[l]:gsub("^Item Class: %s+", "%1")
			l = l + 1 -- Item class is already determined by the base type
		end
		local rarity = self.rawLines[l]:match("^Rarity: (%a+)")
		if rarity then
			mode = "GAME"
			if colorCodes[rarity:upper()] then
				self.rarity = rarity:upper()
			end
			if self.rarity == "UNIQUE" then
				-- Hack for relics
				for _, line in ipairs(self.rawLines) do
					if line:find("Foil Unique") then
						self.rarity = "RELIC"
						break
					end
				end
			end
			l = l + 1
		end
	end
	if self.rawLines[l] then
		if self.rawLines[l] == "--------" then
			l = l + 1
		end
		-- Determine if "Unidentified" item
		local unidentified = false
		if self.rarity == "UNIQUE" then
			local unidentifiedBase = data.itemBases[self.rawLines[l]]
			local identifiedBase = data.itemBases[self.rawLines[l+1]]
			if unidentifiedBase and not identifiedBase then
				unidentified = true
				self.name = "Unidentified item"
				self.baseName = self.rawLines[l]
				self.base = unidentifiedBase
			else
				self.name = self.rawLines[l]
			end
		else
			self.name = self.rawLines[l]
		end
		for _, line in ipairs(self.rawLines) do
			if line == "Unidentified" then
				unidentified = true
				break
			end
		end

		-- Found the name for a rare or unique, but let's parse it if it's a magic or normal or Unidentified item to get the base
		if not (self.rarity == "NORMAL" or self.rarity == "MAGIC" or unidentified) then
			l = l + 1
		end
	end
	self.checkSection = false
	self.sockets = { }
	self.runes = { }
	self.itemSocketCount = 0
	self.jewelSocketCount = 0
	self.classRequirementModLines = { }
	self.buffModLines = { }
	---@type ModLine[]
	self.enchantModLines = { }
	---@type ModLine[]
	self.runeModLines = { }
	self.socketedAugmentTypeOverride = nil
	self.socketedSoulCoreTypes = { }
	---@type ModLine[]
	self.implicitModLines = { }
	---@type ModLine[]
	self.explicitModLines = { }
	-- old items or trade-sourced items have increases to modifiers baked in to the item text, which
	-- means that we can't add e.g. quality or mod magnitude effect to them during parsing. we will
	-- assume an item to be an advanced copy format if either has mod roll information, a modifier
	-- line with a range, or advanced copy lines
	self.advancedCopy = false
	self.modMagnitudeMods = {}
	local implicitLines = 0
	self.variantList = nil
	self.versionList = nil
	-- group ID -> variant ID -> eligible version IDs; version 0 means every version.
	---@type table<number, table<number, table<number, boolean>>>
	self.variantGroups = { }
	self.variantGroupSelections = self.variantGroupSelections or { }
	-- Resolve selection metadata first because tagged base lines can precede it.
	-- The main parser reuses these parsed tag tables when it builds each ModLine.
	local selectionTagsByLine = { }
	for lineIndex, rawLine in ipairs(self.rawLines) do
		local specName, specVal = parseItemSpec(rawLine)
		if variantSelectionSpecNames[specName] then
			if specName == "Version" then
				self.versionList = self.versionList or { }
				t_insert(self.versionList, specVal)
			elseif specName == "Variant" then
				self.variantList = self.variantList or { }
				-- This has to be kept for backwards compatibility
				local _, name = specVal:match("{([%w_]+)}(.+)")
				t_insert(self.variantList, name or specVal)
			elseif specName == "Selected Version" then
				self.selectedVersion = specToNumber(specVal)
			elseif specName == "Selected Variant Group" then
				local groupId, variantId = specVal:match("^(%d+)%s*=%s*(%d+)$")
				if groupId and variantId then
					self.variantGroupSelections[tonumber(groupId)] = tonumber(variantId)
				end
			elseif specName == "Selected Variant" then
				self.variant = specToNumber(specVal)
			end
		end

		local variantSpec = rawLine:match("{variant:([^}]*)}")
		local versionSpec = rawLine:match("{version:([^}]*)}")
		local groupSpec = rawLine:match("{group:([^}]*)}")
		if variantSpec or versionSpec or groupSpec then
			local selectionTags = {
				line = rawLine,
				variantList = variantSpec and parseIdSpec(variantSpec) or nil,
				versionList = versionSpec and parseIdSpec(versionSpec) or nil,
				variantGroupList = groupSpec and parseIdSpec(groupSpec, true) or nil,
			}
			selectionTagsByLine[lineIndex] = selectionTags
		end
	end
	for _, selectionTags in pairsSortByKey(selectionTagsByLine) do
		if selectionTags.variantGroupList and (not selectionTags.variantList or not next(selectionTags.variantList)) then
			ConPrintf("Grouped item line has no variant: %s", selectionTags.line)
		elseif selectionTags.variantGroupList then
			for groupId in pairs(selectionTags.variantGroupList) do
				local group = self.variantGroups[groupId] or { }
				self.variantGroups[groupId] = group
				for variantId in pairs(selectionTags.variantList) do
					if self.variantList and self.variantList[variantId] then
						local versions = group[variantId] or { }
						group[variantId] = versions
						if selectionTags.versionList then
							for versionId in pairs(selectionTags.versionList) do
								if self.versionList and self.versionList[versionId] then
									versions[versionId] = true
								end
							end
						else
							versions[0] = true
						end
					else
						ConPrintf("Grouped item line references unknown variant %d: %s", variantId, selectionTags.line)
					end
				end
			end
		end
	end
	if self:UsesVersionedOrGroupedVariants() then
		self:NormaliseVariantSelections()
	end
	self.prefixes = { }
	self.suffixes = { }
	self.requirements = { }
	self.requirements.runeLevel = 0
	self.requirements.str = 0
	self.requirements.dex = 0
	self.requirements.int = 0
	self.baseLines = { }
	local importedLevelReq
	local flaskBuffLines
	local charmBuffLines
	local deferJewelRadiusIndexAssignment
	local gameModeStage = "FINDIMPLICIT"
	local foundExplicit, foundImplicit
	local linePrefix = ""
	local linePostfix = ""

	while self.rawLines[l] do
		local line = self.rawLines[l]
		if flaskBuffLines and flaskBuffLines[line] then
			flaskBuffLines[line] = nil
		elseif charmBuffLines and charmBuffLines[line] then
			charmBuffLines[line] = nil
		elseif line == "--------" then
			linePrefix = ""
			linePostfix = ""
			self.checkSection = true
		elseif line == "Sanctified" then
			self.sanctified = true
			self.corruptible = false
		elseif line == "Mirrored" then
			self.mirrored = true
		elseif line == "Corrupted" then
			self.corrupted = true
		elseif line == "Twice Corrupted" then
			self.corrupted = true
			self.doubleCorrupted = true
		elseif line == "Desecrated Prefix" or line == "Desecrated Suffix" then
			self.desecrated = true
		elseif line == "Requirements:" then
			-- nothing to do
		elseif line:match("^%(%a+") then
			-- Reminder text, nothing to parse
			while self.rawLines[l] and not self.rawLines[l]:match("%)$") do
				l = l + 1
			end
		elseif self.base and self.base.flask and (
			line:match("^Recovers .+ over .+ Seconds?$")
			or line:match("^Consumes %d+.- of %d+.- Charges on use$")
			or line:match("^Currently has %d+ Charges$")
		) then
			-- In-game flask state and base properties aren't modifier lines.
		elseif line:match("^{ ") then
			-- We're parsing advanced copy/paste format
			self.advancedCopy = true
			linePrefix = ""
			linePostfix = ""
			self.crafted = true
			local fullModName, modTags, increasedAmt = line:match("^{ (.-) %- (.-)  %- (%d*).*}$")
			if not fullModName then
				fullModName, modTags = line:match("^{ (.-) %- (.-) }$")
			end
			if not fullModName then
				fullModName = line:match("^{ (.-) }$")
			end
			local modName = fullModName:match("^.*Modifier \"(.*)\"")
			if modName and modName ~= "" and self.affixes then
				self.pendingAffixList = { }
				local backupAffixList = { }
				for modId, modData in pairs(self.affixes) do
					-- these can produce false positives, and only ever exist on the monk glove base
					if modId:match("^HandWraps") and not self.name:match("Fists of Stone") then
						continue
					end
					if modData.affix == modName then
						if self:GetModSpawnWeight(modData) > 0 then
							if modData.type == "Prefix" then
								t_insert(self.pendingAffixList, { modId = modId, table = self.prefixes })
							elseif modData.type == "Suffix" then
								t_insert(self.pendingAffixList, { modId = modId, table = self.suffixes })
							end
						else
							-- Conqueror mods can't natively spawn on items, so we'll use those if we don't find a match otherwise
							if modData.type == "Prefix" then
								t_insert(backupAffixList, { modId = modId, table = self.prefixes })
							elseif modData.type == "Suffix" then
								t_insert(backupAffixList, { modId = modId, table = self.suffixes })
							end
						end
					end
				end
				if #self.pendingAffixList == 0 and #backupAffixList > 0 then
					self.pendingAffixList = backupAffixList
				end
				if #self.pendingAffixList == 0 then
					-- Could be a veiled, temple, or other custom mod, so just keep it around
					linePrefix = "{custom}"
				end
			elseif fullModName:match("(.*)Enhancement.*") then
				linePostfix = " (enchant)"
			end
			local possibleLineFlags = fullModName:gsub("Vaal Unique", "Mutated"):match("(.*)Modifier.*")
			if possibleLineFlags then
				for flag in possibleLineFlags:gmatch("%a+") do
					local flagLower = flag:lower()
					if lineFlags[flagLower] then
						linePrefix = linePrefix .. "{" .. flagLower .. "}"
					end
				end
			end
			if modTags and modTags ~= "" then
				linePrefix = linePrefix .. "{tags:" .. modTags:lower():gsub("%s+", "") .. "}"
			end
		else
			line = linePrefix .. line .. linePostfix
			local lineIsBaseImplicit = mode == "GAME" and not self.crafted and baseHasImplicitLine(self.base, line)
			if self.checkSection then
				if gameModeStage == "IMPLICIT" then
					if foundImplicit and not lineIsBaseImplicit then
						-- There were definitely implicits, so any following non-base-implicit modifiers must be explicits
						gameModeStage = "EXPLICIT"
						foundExplicit = true
					else
						gameModeStage = "FINDEXPLICIT"
					end
				elseif gameModeStage == "EXPLICIT" then
					gameModeStage = "DONE"
				elseif gameModeStage == "FINDIMPLICIT" and self.itemLevel and not line:match(" %(implicit%)") and
						not line:match(" %(enchant%)") and not line:find("Talisman Tier") then
					gameModeStage = "EXPLICIT"
					foundExplicit = true
				end
				self.checkSection = false
			end
			local levelReq = line:match("^Requires:? Level (%d+)")
			if levelReq then
				self.requirements.level = tonumber(levelReq)
				goto continue
			end
			local specName, specVal = parseItemSpec(line)
			if specName then
				if specName == "Unique ID" then
					self.uniqueID = specVal
					goto continue
				elseif specName == "Item Level" then
					self.itemLevel = specToNumber(specVal)
				elseif specName == "Requires Class" then
					self.classRestriction = specVal
				elseif specName == "Charm Slots" then
					self.charmLimit = specToNumber(specVal)
				elseif specName == "Spirit" then
					self.spiritValue = specToNumber(specVal)
				elseif specName:match("Quality %(%a+ Modifiers%)") then
					self.catalystQuality = specToNumber(specVal:match("(%d+)%%"))
					for i=1, #catalystDescriptorList do
						if specName:match("Quality %(([%a%s]+) Modifiers%)") == catalystDescriptorList[i] then
							self.catalyst = i
						end
					end
				elseif specName == "Quality" then
					self.quality = specToNumber(specVal)
				elseif specName == "Sockets" then
					local group = 0
					for c in specVal:gmatch(".") do
						if c:match("[S]") then
							t_insert(self.sockets, { group = group })
							group = group + 1
						elseif c:match("[J]") then -- e.g. specVal = "Sockets: J J J J J J"
							self.jewelSocketCount = self.jewelSocketCount + 1
						end
					end
					self.itemSocketCount = #self.sockets
				elseif specName == "Rune" then
					t_insert(self.runes, specVal)
				elseif specName == "Radius" and self.type == "Jewel" then
					self.jewelRadiusLabel = specVal:match("^[%a ]+")
					if specVal:match("^%a+") == "Variable" then
                        -- Jewel radius is variable and must be read from it's mods instead after they are parsed
                        deferJewelRadiusIndexAssignment = true
                    else
                        for index, data in pairs(data.jewelRadius) do
                            if specVal:match("^[%a ]+") == data.label then
                                self.jewelRadiusIndex = index
                                break
                            end
						end
					end
				elseif specName == "Limited to" and self.type == "Jewel" then
					self.limit = specToNumber(specVal)
				elseif variantSelectionSpecNames[specName] then
					-- Parsed before item lines so tagged bases and modifiers see the final selection.
				elseif specName == "Talisman Tier" then
					self.talismanTier = specToNumber(specVal)
				elseif specName == "Armour" or specName == "Evasion Rating" or specName == "Evasion" or specName == "Energy Shield" or specName == "Ward" then
					if specName == "Evasion Rating" then
						specName = "Evasion"
						if self.baseName == "Two-Toned Boots (Armour/Energy Shield)" then
							-- Another hack for Two-Toned Boots
							self.baseName = "Two-Toned Boots (Armour/Evasion)"
							self.base = data.itemBases[self.baseName]
						end
					elseif specName == "Energy Shield" then
						specName = "EnergyShield"
						if self.baseName == "Two-Toned Boots (Armour/Evasion)" then
							-- Yet another hack for Two-Toned Boots
							self.baseName = "Two-Toned Boots (Evasion/Energy Shield)"
							self.base = data.itemBases[self.baseName]
						end
					end
					self.armourData = self.armourData or { }
					self.armourData[specName] = specToNumber(specVal)
				elseif specName == "Level" then
					-- Requirements from imported items can't always be trusted
					importedLevelReq = specToNumber(specVal)
				elseif specName == "Requires Level" then
					self.requirements.level = specToNumber(specVal)
				elseif specName == "LevelReq" then
					self.requirements.level = specToNumber(specVal)
				elseif specName == "Has Alt Variant" then
					self.hasAltVariant = true
				elseif specName == "Has Alt Variant Two" then
					self.hasAltVariant2 = true
				elseif specName == "Has Alt Variant Three" then
					self.hasAltVariant3 = true
				elseif specName == "Has Alt Variant Four" then
					self.hasAltVariant4 = true
				elseif specName == "Has Alt Variant Five" then
					self.hasAltVariant5 = true
				elseif specName == "Selected Alt Variant" then
					self.variantAlt = specToNumber(specVal)
				elseif specName == "Selected Alt Variant Two" then
					self.variantAlt2 = specToNumber(specVal)
				elseif specName == "Selected Alt Variant Three" then
					self.variantAlt3 = specToNumber(specVal)
				elseif specName == "Selected Alt Variant Four" then
					self.variantAlt4 = specToNumber(specVal)
				elseif specName == "Selected Alt Variant Five" then
					self.variantAlt5 = specToNumber(specVal)
				elseif specName == "Allow Duplicate Variants" then
					self.allowDuplicateVariants = specVal == "true"
				elseif specName == "Has Variants" or specName == "Selected Variants" then
					-- Need to skip this line for backwards compatibility
					-- with builds that used an old Watcher's Eye implementation
					l = l + 1
				elseif specName == "League" then
					self.league = specVal
				elseif specName == "Crafted" then
					self.crafted = true
				elseif specName == "Implicit" then
					self.implicit = true
				elseif specName == "Prefix" or specName == "Suffix" then
					local affixes = specName == "Prefix" and self.prefixes or self.suffixes
					local fractured = specVal:match("^{fractured}") and true
					specVal = specVal:gsub("^{fractured}", "")
					local range, affix = specVal:match("{range:([^}]+)}(.+)")
					if range and range:find(",", 1, true) then
						local ranges = { }
						for value in range:gmatch("[^,]+") do
							t_insert(ranges, tonumber(value))
						end
						range = ranges
					else
						range = tonumber(range)
					end
					if not range and (affix or specVal) ~= "None" then
						range = main.defaultItemAffixQuality
					end
					t_insert(affixes, {
						modId = affix or specVal,
						range = range,
						fractured = fractured,
					})
				elseif specName == "Implicits" then
					implicitLines = specToNumber(specVal) or 0
					gameModeStage = "EXPLICIT"
				elseif specName == "Unreleased" then
					self.unreleased = (specVal == "true")
				elseif specName == "Upgrade" then
					self.upgradePaths = self.upgradePaths or { }
					t_insert(self.upgradePaths, specVal)
				elseif specName == "Source" then
					self.source = specVal
				elseif specName == "Cluster Jewel Skill" then
					if self.clusterJewel and self.clusterJewel.skills[specVal] then
						self.clusterJewelSkill = specVal
					end
				elseif specName == "Cluster Jewel Node Count" then
					if self.clusterJewel then
						local num = specToNumber(specVal) or self.clusterJewel.maxNodes
						self.clusterJewelNodeCount = m_min(m_max(num, self.clusterJewel.minNodes), self.clusterJewel.maxNodes)
					end
				elseif specName == "Catalyst" then
					for i=1, #catalystList do
						if specVal == catalystList[i] then
							self.catalyst = i
						end
					end
				elseif specName == "CatalystQuality" then
					self.catalystQuality = specToNumber(specVal)
				elseif specName == "Note" then
					self.note = specVal
				elseif specName == "Critical Hit Range" or specName == "Attacks per Second" or specName == "Weapon Range" or
				       specName == "Critical Hit Chance" or specName == "Physical Damage" or specName == "Elemental Damage" or
				       specName == "Chaos Damage" or specName == "Fire Damage" or specName == "Cold Damage" or specName == "Lightning Damage" or
					   specName == "Reload Time" or specName == "Chance to Block" or specName == "Block chance" or
					   specName == "Armour" or specName == "Energy Shield" or specName == "Evasion" or specName == "Requires" then
					self.hidden_specs = true
				-- Anything else is an explicit with a colon in it (Fortress Covenant, Pure Talent, etc) unless it's part of the custom name
				elseif not lineIsBaseImplicit and not (self.name:match(specName) and self.name:match(specVal)) then
					foundExplicit = true
					gameModeStage = "EXPLICIT"
				end
			end
			if line == "Prefixes:" then
				foundExplicit = true
				gameModeStage = "EXPLICIT"
			end
			if not specName or foundExplicit or foundImplicit or lineIsBaseImplicit then
				---@type ModLine
				local modLine = { modTags = {} }
				local selectionTags = selectionTagsByLine[l]

				line = line:gsub("{(%a*):?([^}]*)}", function(k,val)
					if k == "variant" then
						modLine.variantList = selectionTags and selectionTags.variantList or parseIdSpec(val)
					elseif k == "version" then
						modLine.versionList = selectionTags and selectionTags.versionList or parseIdSpec(val)
					elseif k == "group" then
						modLine.variantGroupList = selectionTags and selectionTags.variantGroupList or parseIdSpec(val, true)
					elseif k == "tags" then
						for tag in val:gmatch("[%a_]+") do
							t_insert(modLine.modTags, tag)
						end
					elseif k == "range" then
						self.advancedCopy = true
						modLine.range = tonumber(val)
					elseif k == "corruptedRange" then
						modLine.corruptedRange = tonumber(val)
					elseif lineFlags[k] then
						modLine[k] = true
					end

					return ""
				end)
				line = line:gsub(" %((%l+)%)", function(k)
					if lineFlags[k] then
						modLine[k] = true
					end
					return ""
				end)

				-- Used to flag Bonded soul core mods
				if line:find("Bonded:") then
					modLine.bonded = true
				end

				if modLine.rune then
					modLine.enchant = true
				end
				if modLine.enchant then
					modLine.implicit = true
				end
				if lineIsBaseImplicit then
					modLine.implicit = true
				end
				if modLine.desecrated then
					self.desecrated = true
				end
				if modLine.mutated then
					self.mutated = true
				end
				if modLine.fractured then
					self.fractured = true
				end
				local baseName
				if not self.base and (self.rarity == "NORMAL" or self.rarity == "MAGIC") then
					-- Exact match (affix-less magic and normal items)
					if self.name:match("Energy Blade") and itemClass then -- Special handling for energy blade base.
						self.name = itemClass:match("One Hand") and "Energy Blade One Handed" or "Energy Blade Two Handed"
					end
					if data.itemBases[self.name] then
						baseName = self.name
					else
						local bestMatch = {length = -1}
						-- Partial match (magic items with affixes)
						for itemBaseName, baseData in pairs(data.itemBases) do
							local s, e = self.name:find(itemBaseName, 1, true)
							if s and e and (e-s > bestMatch.length) then
								bestMatch.match = itemBaseName
								bestMatch.length = e-s
								bestMatch.e = e
								bestMatch.s = s
							end
						end
						if bestMatch.match then
							self.namePrefix = self.name:sub(1, bestMatch.s - 1)
							self.nameSuffix = self.name:sub(bestMatch.e + 1)
							baseName = bestMatch.match
						end
					end
					if not baseName then
						local s, e = self.name:find("Two-Toned Boots", 1, true)
						if s then
							-- Hack for Two-Toned Boots
							baseName = "Two-Toned Boots"
							self.namePrefix = self.name:sub(1, s - 1)
							self.nameSuffix = self.name:sub(e + 1)
						end
					end
					self.name = self.name:gsub(" %(.+%)","")
				end
				if not baseName then
					baseName = line:gsub("^Superior ", "")
				end
				if baseName == "Two-Toned Boots" then
					baseName = "Two-Toned Boots (Armour/Energy Shield)"
				end
				local base = data.itemBases[baseName]
				if baseName:find("Runeforged") or baseName:find("Runemastered") then
					self.runicItem = true
				end
				if base then
					-- Items with variants can have multiple bases
					self.baseLines[baseName] = {
						line = baseName,
						variantList = modLine.variantList,
						versionList = modLine.versionList,
						variantGroupList = modLine.variantGroupList,
					}
					-- Set the actual base if variant matches or doesn't have variants
					local usesVersionedOrGroupedVariants = self:UsesVersionedOrGroupedVariants()
					local baseMatches = usesVersionedOrGroupedVariants and self:CheckModLineVariant(modLine)
						or (not usesVersionedOrGroupedVariants and (not self.variant or not modLine.variantList or modLine.variantList[self.variant]))
					if baseMatches then
						self.baseName = baseName
						if not (self.rarity == "NORMAL" or self.rarity == "MAGIC") then
							self.title = self.name
						end
						self.type = base.type
						self.base = base
						self.charmLimit = base.charmLimit
						self.spiritValue = base.spirit
						self.affixes = (self.base.subType and data.itemMods[self.base.type..self.base.subType])
								or data.itemMods[self.base.type]
								or data.itemMods.Item
						self.corruptible = self.base.type ~= "Flask" and self.base.type ~= "Charm" and self.base.type ~= "Transcendent Limb"
						self.requirements.str = self.base.req.str or 0
						self.requirements.dex = self.base.req.dex or 0
						self.requirements.int = self.base.req.int or 0
						local maxReq = m_max(self.requirements.str, self.requirements.dex, self.requirements.int)
						self.defaultSocketColor = "S"
						if self.base.flask and self.base.flask.buff and not flaskBuffLines then
							flaskBuffLines = { }
							for _, line in ipairs(self.base.flask.buff) do
								flaskBuffLines[line] = true
								local modList, extra = modLib.parseMod(line)
								t_insert(self.buffModLines, { line = line, extra = extra, modList = modList or { } })
							end
						end
						if self.base.charm and self.base.charm.buff and not charmBuffLines then
							charmBuffLines = { }
							for _, line in ipairs(self.base.charm.buff) do
								charmBuffLines[line] = true
								local modList, extra = modLib.parseMod(line)
								t_insert(self.buffModLines, { line = line, extra = extra, modList = modList or { } })
							end
						end
					end
					-- Base lines don't need mod parsing, skip it
					goto continue
				end
				if modLine.implicit then
					foundImplicit = true
					gameModeStage = "IMPLICIT"
				end
				local catalystScalar = 1
				if line:match(" %- Unscalable Value$") or line:match(" — Unscalable Value$") then
					line = line:gsub(" %- Unscalable Value$", ""):gsub(" — Unscalable Value$", "")
					modLine.unscalable = true
				else
					catalystScalar = getCatalystScalar(self.catalyst, modLine, self.catalystQuality)
				end
				-- Advanced copy uses current(base) for fixed-value modifiers,
				-- in addition to the current(min-max) form handled below.
				line = line:gsub("(%-?%d+%.?%d*)%((%-?%d+%.?%d*)%)", "%1")
				if self.pendingAffixList and #self.pendingAffixList > 0 then
					if #self.pendingAffixList > 1 then
						-- Probably a conqueror or Essence mod since the mod name is the same for all of them
						-- Try to match the line against one of the mods there
						local rangeLine = line:gsub("%-?%d+%.?%d*%(", "(")
						local valueStrippedLine = rangeLine:gsub("%-?%d+%.?%d*", "#")
						local exactAffix
						local fallbackAffix
						for _, pendingAffix in ipairs(self.pendingAffixList) do
							local modData = self.affixes[pendingAffix.modId]
							for _, modDataLine in ipairs(modData) do
								if line == modDataLine or rangeLine == modDataLine then
									exactAffix = pendingAffix
									break
								end
								if not fallbackAffix and valueStrippedLine == modDataLine:gsub("%-?%d+%.?%d*", "#") then
									fallbackAffix = pendingAffix
								end
							end
							if exactAffix then
								break
							end
						end
						self.pendingAffixList = { exactAffix or fallbackAffix or self.pendingAffixList[1] }
					end
					-- Use rolling Delta/Range in case one range is 1-3 and another is 1-100 so we get the finest precision possible
					local bestPrecisionDelta = -1
					local bestPrecisionRange = -1
					local rollRanges = { }
					local affixMod = self.affixes[self.pendingAffixList[1].modId]
					modLine.order = affixMod and affixMod.statOrder[1]
					for value, range in line:gmatch("(%-?%d+%.?%d*)%((%-?%d+%.?%d*%-%-?%d+%.?%d*)%)") do
						local min, max = range:match("(%-?%d+%.?%d*)%-(%-?%d+%.?%d*)")
						local delta = tonumber(max) - min
						t_insert(rollRanges, delta > 0 and round((value - min) / delta, 6) or 0.5)
						line = line:gsub(value .. "%(" .. range:gsub("%-", "%%-") .. "%)", value)
						if delta > bestPrecisionDelta then
							bestPrecisionRange = round((value - min) / delta, 3)
							bestPrecisionDelta = delta
						end
					end
					t_insert(self.pendingAffixList[1].table, {
						modId = self.pendingAffixList[1].modId,
						-- Legacy modifiers can roll outside the current data range. Keep the
						-- extrapolated range so crafting a different affix doesn't normalise it.
						range = #rollRanges > 1 and rollRanges or bestPrecisionDelta > 0 and bestPrecisionRange or 0.5,
						fractured = modLine.fractured,
					})
					self.pendingAffixList = {}
				else
					-- Use rolling Delta/Range in case one range is 1-3 and another is 1-100 so we get the finest precision possible
					local bestPrecisionDelta = -1
					local bestPrecisionRange = -1
					local firstRollRange
					local hasIndependentRolls

					-- Advanced copy only provides the endpoints for enum ranges; keep the selected value.
					line = line:gsub("(%s*)(%b())", function(space, range)
						if range:find("-", 1, true) and not range:find("%d") then
							return ""
						end
						return space .. range
					end)
					local advancedCopyLine = line

					for value, range in line:gmatch("(%-?%d+%.?%d*)%((%-?%d+%.?%d*%-%-?%d+%.?%d*)%)") do
						local min, max = range:match("(%-?%d+%.?%d*)%-(%-?%d+%.?%d*)")
						local delta = tonumber(max) - min
						local rollRange = delta > 0 and round((value - min) / delta, 6) or 0.5
						if firstRollRange and firstRollRange ~= rollRange then
							hasIndependentRolls = true
						end
						firstRollRange = firstRollRange or rollRange
						if delta > bestPrecisionDelta then
							bestPrecisionRange = rollRange
							bestPrecisionDelta = delta
						end
						if bestPrecisionRange > 1 or bestPrecisionRange < 0 then
							line = line:gsub(value .. "%(" .. range:gsub("%-", "%%-") .. "%)", value)
						else
							line = line:gsub(value .. "%(" .. range:gsub("%-", "%%-") .. "%)", (tonumber(value) < 0 and "+" or "") .. "(" .. min .. "-" .. max .. ")")
						end
					end
					if hasIndependentRolls then
						line = advancedCopyLine:gsub("(%-?%d+%.?%d*)%(%-?%d+%.?%d*%-%-?%d+%.?%d*%)", "%1")
					elseif bestPrecisionRange <= 1 and bestPrecisionRange >= 0 then
						modLine.range = bestPrecisionRange
					end
				end
				local rangedLine = itemLib.applyRange(line, 1, catalystScalar, modLine.corruptedRange)
				local modList, extra = modLib.parseMod(rangedLine)
				if (not modList or extra) and self.rawLines[l+1] then
					-- Try to combine it with the next line
					local nextLine = self.rawLines[l+1]:gsub("%b{}", ""):gsub(" ?%(%l+%)","")
					local combLine = line.." "..nextLine
					rangedLine = itemLib.applyRange(combLine, 1, catalystScalar, modLine.corruptedRange)
					modList, extra = modLib.parseMod(rangedLine, true)
					if modList and not extra then
						line = line.."\n"..nextLine
						l = l + 1
					else
						modList, extra = modLib.parseMod(rangedLine)
					end
				end

				local lineLower = modLine.disabled and "" or line:lower()
				-- \d+% increased/reduced explicit/implicit/ *tags* modifier magnitudes
				local modMagnitudePattern = { "(%d+)%% ([ir][ne][cd][ru][ec][ae][sd]e?d?) ?([%a%s]*) modifier magnitudes",
					-- \d+% increased/reduced effect of suffixes/prefixes
					"(%d+)%% ([ir][ne][cd][ru][ec][ae][sd]e?d?) effect of ([sp][ur][fe]fix)es",
					-- eyes of the greatwolf
					"([%a%s]*) modifier magnitudes are doubled" }
				if lineLower == "implicit modifiers cannot be changed" then
					self.implicitsCannotBeChanged = true
				elseif lineLower:match(" prefix modifiers? allowed") then
					self.prefixes.limit = (self.prefixes.limit or 0) + (tonumber(lineLower:match("%+(%d+) prefix modifiers? allowed")) or 0) - (tonumber(lineLower:match("%-(%d+) prefix modifiers? allowed")) or 0)
				elseif lineLower:match(" suffix modifiers? allowed") then
					self.suffixes.limit = (self.suffixes.limit or 0) + (tonumber(lineLower:match("%+(%d+) suffix modifiers? allowed")) or 0) - (tonumber(lineLower:match("%-(%d+) suffix modifiers? allowed")) or 0)
				elseif lineLower == "this item can be anointed by cassia" then
					self.canBeAnointed = true
				elseif (lineLower == "can have 1 additional instilled modifier" or lineLower == "can have an additional instilled modifier") then
					self.canHaveTwoEnchants = true
				elseif lineLower == "can have 2 additional instilled modifiers" then
					self.canHaveTwoEnchants = true
					self.canHaveThreeEnchants = true
				elseif lineLower == "can have 3 additional instilled modifiers" then
					self.canHaveTwoEnchants = true
					self.canHaveThreeEnchants = true
					self.canHaveFourEnchants = true
				end
				modLine.socketedAugmentTypeOverride = lineLower:match("^this item gains bonuses from socketed items as though it was a? ?(.+)$")
				modLine.socketedSoulCoreType = lineLower:match("^this item gains bonuses from socketed soul cores as though it was also a? ?(.+)$")

				-- some tags might not match up exactly to tag strings. this has a list of exceptions
				local modMagnitudeTagMap = {
					defence = "defences",
					-- 3.29 eyes of the greatwolf
					enchantment = "enchant",
				}
				for _, pattern in ipairs(modMagnitudePattern) do
					if not modLine.disabled and rangedLine:lower():find(pattern) then
						local rangedLine = itemLib.applyRange(line, modLine.range or main.defaultItemAffixQuality or 1, catalystScalar, modLine.corruptedRange)
						local amount, increaseOrDecrease, modTagsString = rangedLine:lower():match(pattern)
						local multiplier
						-- "are doubled" format -> swap variables
						if amount and not (increaseOrDecrease or modTagsString) then
							modTagsString = amount
							amount = 100
							increaseOrDecrease = "increased"
							multiplier = 2
						end
						if amount and modTagsString and (increaseOrDecrease == "increased" or increaseOrDecrease == "reduced") then
							local modTags = {}
							local modType
							local quality = increaseOrDecrease == "increased" and tonumber(amount) or -tonumber(amount)
							if modTagsString == "explicit physical and chaos damage" then
								table.insert(self.modMagnitudeMods, { tags = { "damage" }, anyTags = { "physical", "chaos" }, quality = quality, modType = "explicit", sourceLine = modLine })
							else
								-- explicit elemental damage -> tags = {elemental, damage}, modType = explicit
								for word in (modTagsString .. " "):gmatch("%S+") do
									word = word:lower()
									word = modMagnitudeTagMap[word] or word
									if word == "implicit" or word == "explicit" or word == "enchant" then
										modType = word
									else
										table.insert(modTags, word)
									end
								end
								table.insert(self.modMagnitudeMods, { tags = modTags, quality = quality, multiplier = multiplier, modType = modType, sourceLine = modLine })
							end
							break
						end
					end
				end
				local modLines
				if modLine.rune then
					modLines = self.runeModLines
				elseif modLine.enchant then
					modLines = self.enchantModLines
				elseif line:find("Requires Class") then
					modLines = self.classRequirementModLines
				elseif modLine.implicit or #self.runeModLines + #self.enchantModLines + #self.implicitModLines < implicitLines then
					modLines = self.implicitModLines
				else
					modLines = self.explicitModLines
				end
				modLine.line = line
				if self:CheckModLineVariant(modLine) then
					if modLine.socketedAugmentTypeOverride then
						self.socketedAugmentTypeOverride = modLine.socketedAugmentTypeOverride
					elseif modLine.socketedSoulCoreType then
						self.socketedSoulCoreTypes[modLine.socketedSoulCoreType] = true
					end
				end
				if modList then
					modLine.modList = modList
					modLine.extra = extra
					modLine.valueScalar = catalystScalar
					modLine.range = modLine.range or main.defaultItemAffixQuality
					t_insert(modLines, modLine)
					if mode == "GAME" then
						if gameModeStage == "FINDIMPLICIT" then
							gameModeStage = "IMPLICIT"
						elseif gameModeStage == "FINDEXPLICIT" then
							foundExplicit = true
							gameModeStage = "EXPLICIT"
						elseif gameModeStage == "EXPLICIT" then
							foundExplicit = true
						end
					else
						foundExplicit = true
					end
				elseif mode == "GAME" then
					if gameModeStage == "IMPLICIT" or gameModeStage == "EXPLICIT" or (gameModeStage == "FINDIMPLICIT" and (not data.itemBases[line]) and not (self.name == line) and not line:find("Two%-Toned") and not (self.base and (line == self.base.type or self.base.subType and line == self.base.subType .. " " .. self.base.type))) then
						modLine.modList = { }
						modLine.extra = line
						t_insert(modLines, modLine)
					elseif gameModeStage == "FINDEXPLICIT" then
						gameModeStage = "DONE"
					end
				elseif foundExplicit or (not foundExplicit and gameModeStage == "EXPLICIT") then
					modLine.modList = { }
					modLine.extra = line
					t_insert(modLines, modLine)
				end
			end
		end
		::continue::
		l = l + 1
	end
	if self.baseName and self.title then
		self.name = self.title .. ", " .. self.baseName:gsub(" %(.+%)","")
	end
	-- this will need more advanced logic for jewel sockets in items to work properly but could just be removed as items like this was only introduced during development.
	if self.base then
		if self.base.weapon or self.base.armour or self.base.tags.wand or self.base.tags.staff or self.base.tags.sceptre or self.itemSocketCount > 0 then
			local shouldFixRunesOnItem = #self.runes == 0
			local canRebuildRunes
			if not shouldFixRunesOnItem and #self.runeModLines > 0 then
				canRebuildRunes = true
				for _, rune in ipairs(self.runes) do
					if rune ~= "None" and not data.itemMods.Runes[rune] then
						canRebuildRunes = false
						break
					end
				end
			end

			local function getRuneLineParts(modLine)
				local values = { }
				local strippedModLine = modLine:gsub("(%d%.?%d*)", function(val)
					t_insert(values, tonumber(val))
					return "#"
				end)
				if #values == 0 then
					t_insert(values, 1)
				end
				return strippedModLine, values
			end

			if canRebuildRunes then
				local disabledRuneLines = { }
				for _, modLine in ipairs(self.runeModLines) do
					if modLine.disabled then
						local strippedModLine = getRuneLineParts(modLine.line)
						disabledRuneLines[strippedModLine] = (disabledRuneLines[strippedModLine] or 0) + 1
					end
				end
				self:UpdateRunes()
				for _, modLine in ipairs(self.runeModLines) do
					local strippedModLine = getRuneLineParts(modLine.line)
					if (disabledRuneLines[strippedModLine] or 0) > 0 then
						modLine.disabled = true
						disabledRuneLines[strippedModLine] -= 1
					end
				end
			end

			local function compareRuneValueSets(a, b)
				for i = 1, math.max(#a, #b) do
					local aVal = a[i] or 0
					local bVal = b[i] or 0
					if aVal ~= bVal then
						return aVal > bVal
					end
				end
				return false
			end

			local function runeValueSetsEqual(a, b)
				for i = 1, math.max(#a, #b) do
					if math.abs((a[i] or 0) - (b[i] or 0)) > 1e-9 then
						return false
					end
				end
				return true
			end

			local function addRuneValueSets(a, b)
				local out = { }
				for i = 1, math.max(#a, #b) do
					out[i] = (a[i] or 0) + (b[i] or 0)
				end
				return out
			end

			local function runeValueSetExceeds(valueSet, target)
				for i = 1, math.max(#valueSet, #target) do
					if (valueSet[i] or 0) > (target[i] or 0) + 1e-9 then
						return true
					end
				end
				return false
			end

			local function findRuneCombination(groupedRunes, targetValues, maxRunes, maxRuneCounts)
				local best = { }
				local counts = { }

				local function search(startIndex, count, sum)
					if runeValueSetsEqual(sum, targetValues) then
						if not best.count or count < best.count then
							best.count = count
							best.counts = { }
							for index, value in pairs(counts) do
								best.counts[index] = value
							end
						end
						return
					end
					if count >= maxRunes or (best.count and count >= best.count) then
						return
					end

					for index = startIndex, #groupedRunes do
						if not maxRuneCounts or (counts[index] or 0) < (maxRuneCounts[groupedRunes[index].name] or 0) then
							local nextSum = addRuneValueSets(sum, groupedRunes[index].values)
							if not runeValueSetExceeds(nextSum, targetValues) then
								counts[index] = (counts[index] or 0) + 1
								search(index, count + 1, nextSum)
								counts[index] = counts[index] - 1
							end
						end
					end
				end

				search(1, 0, { })
				return best.counts, best.count
			end

			local gameSocketedAugmentEffectModifiers = {
				SocketedAugmentItemEffect = 0,
				SocketedRuneEffect = 0,
				SocketedSoulCoreEffect = 0,
			}
			if mode == "GAME" and shouldFixRunesOnItem then
				for _, modLines in ipairs({ self.enchantModLines, self.implicitModLines, self.explicitModLines }) do
					for _, effectModLine in ipairs(modLines) do
						local effectModList = effectModLine.modList or { }
						for _, mod in ipairs(effectModList) do
							if mod.type == "INC" and gameSocketedAugmentEffectModifiers[mod.name] then
								effectModList = getRangedModList(self, effectModLine) or effectModList
								break
							end
						end
						for _, mod in ipairs(effectModList) do
							if mod.type == "INC" and gameSocketedAugmentEffectModifiers[mod.name] then
								gameSocketedAugmentEffectModifiers[mod.name] = gameSocketedAugmentEffectModifiers[mod.name] + mod.value / 100
							end
						end
					end
				end
			end

			local statGroupedRunes = { }
			local broadItemType, specificItemType = self:GetSocketedAugmentTypes()
			for runeName, runeMods in pairs(data.itemMods.Runes) do
				for slotType, slotMod in pairs(runeMods) do
					if slotType == broadItemType or slotType == specificItemType or (slotMod.type == "SoulCore" and self.socketedSoulCoreTypes[slotType]) then
						local effectModifier = gameSocketedAugmentEffectModifiers.SocketedAugmentItemEffect + (gameSocketedAugmentEffectModifiers["Socketed" .. slotMod.type .. "Effect"] or 0)
						local valueScalar = effectModifier ~= 0 and 1 + effectModifier
						for _, modLine in ipairs(slotMod) do
							local line = modLine
							if valueScalar then
								local bondedPrefix = line:match("^(Bonded: )") or ""
								line = bondedPrefix .. itemLib.applyRange(line:gsub("^Bonded: ", ""), 1, valueScalar)
							end
							local strippedModLine, values = getRuneLineParts(line)
							local groupedRunes = statGroupedRunes[strippedModLine]
							if not groupedRunes then
								groupedRunes = { }
								statGroupedRunes[strippedModLine] = groupedRunes
							end
							local existingRune = groupedRunes[runeName]
							if existingRune then
								existingRune.values = addRuneValueSets(existingRune.values, values)
							else
								local rune = { name = runeName, type = slotMod.type, values = values, effectApplied = effectModifier ~= 0 }
								groupedRunes[runeName] = rune
								t_insert(groupedRunes, rune)
							end
						end
					end
				end
			end
			for _, runes in pairs(statGroupedRunes) do
				table.sort(runes, function(a, b) return compareRuneValueSets(a.values, b.values) end)
			end

			local remainingRunes = self.itemSocketCount
			local inferredRuneCounts = { }
			for _, modLine in ipairs(self.runeModLines) do
				local strippedModLine, targetValues = getRuneLineParts(modLine.line)
				local groupedRunes = statGroupedRunes[strippedModLine]
				if groupedRunes and not modLine.bonded then
					local result, numRunes = findRuneCombination(groupedRunes, targetValues, self.itemSocketCount)

					if result then -- we have found a valid combo for that rune category
						local addedRuneCount = 0
						for index, rune in ipairs(groupedRunes) do
							addedRuneCount = addedRuneCount + m_max((result[index] or 0) - (inferredRuneCounts[rune.name] or 0), 0)
						end
						if addedRuneCount <= remainingRunes then
							remainingRunes = remainingRunes - addedRuneCount
							modLine.runeCount = numRunes

							local effectApplied
							for index, rune in ipairs(groupedRunes) do
								local runeCount = result[index] or 0
								if runeCount > 0 then
									modLine.augmentType = rune.type
									effectApplied = effectApplied or rune.effectApplied
									if shouldFixRunesOnItem then
										for _ = (inferredRuneCounts[rune.name] or 0) + 1, runeCount do
											t_insert(self.runes, rune.name)
										end
									end
									inferredRuneCounts[rune.name] = m_max(inferredRuneCounts[rune.name] or 0, runeCount)
								end
							end
							modLine.socketedRuneEffectAlreadyApplied = effectApplied
						end
					end
				end
			end
			for _, modLine in ipairs(self.runeModLines) do
				if modLine.bonded then
					local strippedModLine, targetValues = getRuneLineParts(modLine.line)
					local groupedRunes = statGroupedRunes[strippedModLine]
					local result = groupedRunes and findRuneCombination(groupedRunes, targetValues, self.itemSocketCount, inferredRuneCounts)
					if result then
						for index, rune in ipairs(groupedRunes) do
							if (result[index] or 0) > 0 then
								modLine.augmentType = rune.type
								modLine.socketedRuneEffectAlreadyApplied = rune.effectApplied or modLine.socketedRuneEffectAlreadyApplied
							end
						end
					end
				end
			end
		else
			self.sockets = { }
			self.itemSocketCount = 0
			self.runes = { }
		end
	end
	if self.advancedCopy and (self.rarity == "UNIQUE" or self.rarity == "RELIC") and not self:UsesVersionedOrGroupedVariants() then
		if not uniqueModStatOrder then
			uniqueModStatOrder = { exact = { }, normalised = { } }
			for _, mod in pairs(data.itemMods.Exclusive) do
				for index, line in ipairs(mod) do
					local exactLine = line:lower():gsub("\n", " ")
					local statLine = normaliseModLine(line)
					uniqueModStatOrder.exact[exactLine] = m_min(uniqueModStatOrder.exact[exactLine] or math.huge, mod.statOrder[index])
					uniqueModStatOrder.normalised[statLine] = m_min(uniqueModStatOrder.normalised[statLine] or math.huge, mod.statOrder[index])
				end
			end
		end
		for _, modLine in ipairs(self.explicitModLines) do
			local exactLine = modLine.line:lower():gsub("\n", " ")
			modLine.order = uniqueModStatOrder.exact[exactLine]
				or uniqueModStatOrder.normalised[normaliseModLine(modLine.line)]
		end
	end
	if self.advancedCopy and #self.explicitModLines > 1 then
		sortCraftedModLines(self.explicitModLines)
	end
	if self.advancedCopy or self.crafted then
		-- apply mod magnitude boost to matching mods
		if #self.modMagnitudeMods > 0 then
			for _, modMagnitudeMod in ipairs(self.modMagnitudeMods) do
				if self:UsesVersionedOrGroupedVariants() and not self:CheckModLineVariant(modMagnitudeMod.sourceLine) then
					continue
				end
				local modLists
				if modMagnitudeMod.modType then
					modLists = { self[modMagnitudeMod.modType .. "ModLines"] }
				else
					modLists = { self.implicitModLines, self.explicitModLines, self.enchantModLines }
				end
				for _, mods in ipairs(modLists) do
					for _, mod in ipairs(mods or {}) do
						-- avoid scaling variant lines which are not active
						if self:GetModLineVariantCount(mod) == 0 or mod.unscalable then
							continue
						end
						-- Modifiers that grant skills are not affected by modifier magnitude.
						local grantsSkill = false
						for _, parsedMod in ipairs(mod.modList) do
							if parsedMod.name == "ExtraSkill" then
								grantsSkill = true
								break
							end
						end
						if mod.extra and not grantsSkill then
							local line = mod.line:lower()
							grantsSkill = line:match("^grants skill:")
						end
						-- Create a fast lookup table for all provided tags
						local tagLookup = {}
						for _, curTag in ipairs(mod.modTags) do
							tagLookup[curTag] = true;
						end
						-- these aren't actual mod tags but do appear in mod magnitude mods
						for _, lineFlag in ipairs({ "desecrated", "prefix", "suffix" }) do
							if mod[lineFlag] then
								tagLookup[lineFlag] = true
							end
						end
						local match = true
						for _, magnitudeTag in ipairs(modMagnitudeMod.tags) do
							if not tagLookup[magnitudeTag] then
								match = false
							end
						end
						if modMagnitudeMod.anyTags and not (tagLookup[modMagnitudeMod.anyTags[1]] or tagLookup[modMagnitudeMod.anyTags[2]]) then
							match = false
						end
						if match and not grantsSkill then
							if modMagnitudeMod.multiplier then
								mod.valueScalar = (mod.valueScalar or 1) * modMagnitudeMod.multiplier
							else
								mod.valueScalar = (mod.valueScalar or 1) + (modMagnitudeMod.quality / 100)
							end
						end
						if mod.valueScalar and mod.valueScalar ~= 1 then
							local rangedLine = itemLib.applyRange(mod.line, mod.range or 1, mod.valueScalar, 1)
							local modList, extra = modLib.parseMod(rangedLine)
							if modList then
								mod.displayValueScalar = 1
								mod.modList = modList
								mod.extra = extra
							end
						end
					end
				end
			end
		end
	end

	for _, runeName in ipairs(self.runes) do
		local runeData = data.itemMods.Runes[runeName]
		if runeData then
			for _, slotData in pairs(runeData) do
				self.requirements.runeLevel = m_max(self.requirements.runeLevel, slotData.rank[1])
			end
		end
	end
	if self.base then
		local dbItem = self:GetUniqueDBItem()
		if dbItem then
			self.requirements.naturalLevel = m_max(dbItem.requirements.naturalLevel or dbItem.requirements.level, self.base.req.level or 0)
		else
			if not self.requirements.level then
				if importedLevelReq and #self.sockets == 0 then
					-- Requirements on imported items can only be trusted for items with no sockets
					self.requirements.level = importedLevelReq
				else
					self.requirements.level = self.base.req.level
				end
			end
			self.requirements.naturalLevel = self.requirements.level
		end
		if not self.requirements.naturalLevel then
			self.requirements.naturalLevel = 0
		end
		self.requirements.level = self.requirements.level or self.requirements.naturalLevel
		self.requirements.level = m_max(self.requirements.level, self.requirements.naturalLevel, self.requirements.runeLevel)
	end
	self.affixLimit = 0
	if self.crafted then
		if not self.affixes then
			self.crafted = false
		elseif self.rarity == "MAGIC" then
			if self.prefixes.limit or self.suffixes.limit then
				self.prefixes.limit = m_max(m_min((self.prefixes.limit or 0) + 1, 2), 0)
				self.suffixes.limit = m_max(m_min((self.suffixes.limit or 0) + 1, 2), 0)
				self.affixLimit = self.prefixes.limit + self.suffixes.limit
			else
				self.affixLimit = 2
			end
		elseif self.rarity == "RARE" then
			self.affixLimit = ((self.type == "Jewel" and not (self.base.subType == "Abyss" and self.corrupted)) and 4 or 6)
			if self.prefixes.limit or self.suffixes.limit then
				self.prefixes.limit = m_max(m_min((self.prefixes.limit or 0) + self.affixLimit / 2, self.affixLimit), 0)
				self.suffixes.limit = m_max(m_min((self.suffixes.limit or 0) + self.affixLimit / 2, self.affixLimit), 0)
				self.affixLimit = self.prefixes.limit + self.suffixes.limit
			end
		else
			self.crafted = false
		end
		if self.crafted then
			for _, list in ipairs({self.prefixes,self.suffixes}) do
				for i = 1, (list.limit or (self.affixLimit / 2)) do
					if not list[i] then
						list[i] = { modId = "None" }
					elseif list[i].modId ~= "None" and not self.affixes[list[i].modId] then
						for modId, mod in pairs(self.affixes) do
							if list[i].modId == mod.affix then
								list[i].modId = modId
								break
							end
						end
						if not self.affixes[list[i].modId] then
							list[i].modId = "None"
						end
					end
				end
			end
		end
	end
	if not self:UsesVersionedOrGroupedVariants() and self.variantList then
		self.variant = m_min(#self.variantList, self.variant or #self.variantList)
		if self.hasAltVariant then
			self.variantAlt = m_min(#self.variantList, self.variantAlt or #self.variantList)
		end
		if self.hasAltVariant2 then
			self.variantAlt2 = m_min(#self.variantList, self.variantAlt2 or #self.variantList)
		end
		if self.hasAltVariant3 then
			self.variantAlt3 = m_min(#self.variantList, self.variantAlt3 or #self.variantList)
		end
		if self.hasAltVariant4 then
			self.variantAlt4 = m_min(#self.variantList, self.variantAlt4 or #self.variantList)
		end
		if self.hasAltVariant5 then
			self.variantAlt5 = m_min(#self.variantList, self.variantAlt5 or #self.variantList)
		end
	end
	if not self.quality then
		self:NormaliseQuality()
		if highQuality then
			-- Behavior of NormaliseQuality should be looked at because calling it twice has different results.
			-- Leaving it alone for now. Just moving it here from Main.lua so BuildAndParseRaw doesn't need to be called.
			self:NormaliseQuality()
		end
	end
	self:BuildModList()
	if deferJewelRadiusIndexAssignment then
		self.jewelRadiusIndex = self.jewelData.radiusIndex
	end
	if self.jewelData and self.jewelData.timeLostJewelRadiusOverride then
		self.jewelRadiusIndex = self.jewelData.timeLostJewelRadiusOverride
	end
end

function ItemClass:NormaliseQuality()
	if self.base and self.base.quality then
		if not self.quality then
			self.quality = 0
		elseif not self.uniqueID and not self.corrupted and not self.mirrored and not (self.base.type == "Charm") and self.quality < self.base.quality then -- charms cannot be modified by quality currency.
			self.quality = main.defaultItemQuality
		end
	end
end

function ItemClass:GetModSpawnWeight(mod, includeTags, excludeTags)
	local weight = 0
	if self.base then
		for i, key in ipairs(mod.weightKey) do
			if (self.base.tags[key] or (includeTags and includeTags[key]) and not (excludeTags and excludeTags[key])) then
				weight = mod.weightVal[i]
				break
			end
		end
		for i, key in ipairs(mod.weightMultiplierKey or {}) do
			if (self.base.tags[key] or (includeTags and includeTags[key])) and not (excludeTags and excludeTags[key]) then
				weight = weight * mod.weightMultiplierVal[i] / 100
				break
			end
		end
	end
	return weight
end

function ItemClass:BuildRaw()
	local rawLines = { }
	local usesVersionedOrGroupedVariants = self:UsesVersionedOrGroupedVariants()
	if self.runeModLines and self.runeModLines[1] then
		self:ApplySocketedRuneDisplayScalars()
	end
	t_insert(rawLines, "Rarity: " .. self.rarity)
	if self.title then
		t_insert(rawLines, self.title)
		t_insert(rawLines, self.baseName)
	else
		t_insert(rawLines, (self.namePrefix or "") .. self.baseName .. (self.nameSuffix or ""))
	end
	if self.charmLimit then
		t_insert(rawLines, "Charm Slots: " .. self.charmLimit)
	end
	if self.spiritValue then
		t_insert(rawLines, "Spirit: " .. self.spiritValue)
	end
	if self.armourData then
		for _, type in ipairs({ "Armour", "Evasion", "EnergyShield", "Ward" }) do
			if self.armourData[type] and self.armourData[type] > 0 then
				t_insert(rawLines, type:gsub("EnergyShield", "Energy Shield") .. ": " .. self.armourData[type])
			end
		end
	end
	if self.uniqueID then
		t_insert(rawLines, "Unique ID: " .. self.uniqueID)
	end
	if self.league then
		t_insert(rawLines, "League: " .. self.league)
	end
	if self.unreleased then
		t_insert(rawLines, "Unreleased: true")
	end
	if self.crafted then
		t_insert(rawLines, "Crafted: true")
		for _, affix in ipairs(self.prefixes or { }) do
			local range = affix.range and "{range:" .. (type(affix.range) == "table" and table.concat(affix.range, ",") or round(affix.range, 3)) .. "}" or ""
			t_insert(rawLines, "Prefix: " .. (affix.fractured and "{fractured}" or "") .. range .. affix.modId)
		end
		for _, affix in ipairs(self.suffixes or { }) do
			local range = affix.range and "{range:" .. (type(affix.range) == "table" and table.concat(affix.range, ",") or round(affix.range, 3)) .. "}" or ""
			t_insert(rawLines, "Suffix: " .. (affix.fractured and "{fractured}" or "") .. range .. affix.modId)
		end
	end
	if self.catalyst and self.catalyst > 0 then
		t_insert(rawLines, "Catalyst: " .. catalystList[self.catalyst])
	end
	if self.catalystQuality then
		t_insert(rawLines, "CatalystQuality: " .. self.catalystQuality)
	end
	if self.clusterJewel then
		if self.clusterJewelSkill then
			t_insert(rawLines, "Cluster Jewel Skill: " .. self.clusterJewelSkill)
		end
		if self.clusterJewelNodeCount then
			t_insert(rawLines, "Cluster Jewel Node Count: " .. self.clusterJewelNodeCount)
		end
	end
	if self.talismanTier then
		t_insert(rawLines, "Talisman Tier: " .. self.talismanTier)
	end
	if self.itemLevel then
		t_insert(rawLines, "Item Level: " .. self.itemLevel)
	end
	local function writeModLine(modLine)
		local line = modLine.line
		local function prependToAllLines(prefix)
			line = prefix .. line:gsub("\n", "\n" .. prefix)
		end
		local function makeIdSpec(idList)
			local ids = { }
			for id in pairsSortByKey(idList) do
				t_insert(ids, id)
			end
			return table.concat(ids, ",")
		end
		-- confusingly, in-game rune modifiers DO have the scaling baked into the value, while
		-- everything else does not. this matches that behaviour in PoB
		if modLine.augmentType or modLine.rune then
			local displayValueScalar = modLine.displayValueScalar and (modLine.valueScalar or 1) * modLine.displayValueScalar
			line = displayValueScalar and itemLib.applyRange(modLine.line, modLine.range or main.defaultItemAffixQuality, displayValueScalar, modLine.corruptedRange) or modLine.line
		end
		if modLine.range and line:match("%(%-?[%d%.]+%-%-?[%d%.]+%)") then
			line = "{range:" .. round(modLine.range, 6) .. "}" .. line
		end
		if modLine.corruptedRange then
			line = "{corruptedRange:" .. round(modLine.corruptedRange, 2) .. "}" .. line
		end
		if modLine.rune then
			line = "{rune}" .. line
		end
		if modLine.enchant then
			line = "{enchant}" .. line
		end
		if modLine.custom then
			line = "{custom}" .. line
		end
		if modLine.fractured then
			line = "{fractured}" .. line
		end
		if modLine.desecrated then
			line = "{desecrated}" .. line
		end
		if modLine.mutated then
			line = "{mutated}" .. line
		end
		if modLine.disabled then
			line = "{disabled}" .. line
		end
		if modLine.crafted then
			line = "{crafted}" .. line
		end
		if modLine.prefix then
			line = "{prefix}" .. line
		end
		if modLine.suffix then
			line = "{suffix}" .. line
		end
		if modLine.unscalable then
			line = "{unscalable}" .. line
		end
		local hasNewSelection = modLine.versionList or modLine.variantGroupList
		if hasNewSelection and modLine.modTags and #modLine.modTags > 0 then
			line = "{tags:" .. table.concat(modLine.modTags, ",") .. "}" .. line
		end
		if modLine.variantGroupList then
			prependToAllLines("{group:" .. makeIdSpec(modLine.variantGroupList) .. "}")
		end
		if modLine.variantList then
			prependToAllLines("{variant:" .. makeIdSpec(modLine.variantList) .. "}")
		end
		if modLine.versionList then
			prependToAllLines("{version:" .. makeIdSpec(modLine.versionList) .. "}")
		end
		if not hasNewSelection and modLine.modTags and #modLine.modTags > 0 then
			line = "{tags:" .. table.concat(modLine.modTags, ",") .. "}" .. line
		end
		t_insert(rawLines, line)
	end
	if self.versionList then
		for _, versionName in ipairs(self.versionList) do
			t_insert(rawLines, "Version: " .. versionName)
		end
		if self.selectedVersion then
			t_insert(rawLines, "Selected Version: " .. self.selectedVersion)
		end
	end
	if self.variantList then
		for _, variantName in ipairs(self.variantList) do
			t_insert(rawLines, "Variant: " .. variantName)
		end
		if self:HasIndependentVariants() then
			t_insert(rawLines, "Selected Variant: " .. self.variant)
		elseif usesVersionedOrGroupedVariants then
			for groupId in pairsSortByKey(self.variantGroups) do
				local variantId = self.variantGroupSelections[groupId]
				if variantId then
					t_insert(rawLines, "Selected Variant Group: " .. groupId .. "=" .. variantId)
				end
			end
		else
			t_insert(rawLines, "Selected Variant: " .. self.variant)
		end

		for _, baseLine in pairs(self.baseLines or { }) do
			if baseLine.variantList or baseLine.versionList or baseLine.variantGroupList then
				writeModLine(baseLine)
			end
		end
		if not usesVersionedOrGroupedVariants and self.hasAltVariant then
			t_insert(rawLines, "Has Alt Variant: true")
			t_insert(rawLines, "Selected Alt Variant: " .. self.variantAlt)
		end
		if not usesVersionedOrGroupedVariants and self.hasAltVariant2 then
			t_insert(rawLines, "Has Alt Variant Two: true")
			t_insert(rawLines, "Selected Alt Variant Two: " .. self.variantAlt2)
		end
		if not usesVersionedOrGroupedVariants and self.hasAltVariant3 then
			t_insert(rawLines, "Has Alt Variant Three: true")
			t_insert(rawLines, "Selected Alt Variant Three: " .. self.variantAlt3)
		end
		if not usesVersionedOrGroupedVariants and self.hasAltVariant4 then
			t_insert(rawLines, "Has Alt Variant Four: true")
			t_insert(rawLines, "Selected Alt Variant Four: " .. self.variantAlt4)
		end
		if not usesVersionedOrGroupedVariants and self.hasAltVariant5 then
			t_insert(rawLines, "Has Alt Variant Five: true")
			t_insert(rawLines, "Selected Alt Variant Five: " .. self.variantAlt5)
		end
		if self.allowDuplicateVariants then
			t_insert(rawLines, "Allow Duplicate Variants: true")
		end
	end
	if not self.variantList then
		for _, baseLine in pairs(self.baseLines or { }) do
			if baseLine.versionList or baseLine.variantGroupList then
				writeModLine(baseLine)
			end
		end
	end
	if self.quality then
		t_insert(rawLines, "Quality: " .. self.quality)
	end
	if self.itemSocketCount and self.itemSocketCount > 0 then
		local socketString = ""
		for _ = 1, self.itemSocketCount do
			socketString = socketString .. "S "
		end
		socketString = socketString:gsub(" $", "")
		t_insert(rawLines, "Sockets: " .. socketString)
		for i = 1, self.itemSocketCount do
			t_insert(rawLines, "Rune: "..(self.runes[i] or "None"))
		end
	end
	if self.jewelSocketCount and self.jewelSocketCount > 0 then
		local socketString = ""
		for _ = 1, self.jewelSocketCount do
			socketString = socketString .. "J "
		end
		socketString = socketString:gsub(" $", "")
		t_insert(rawLines, "Sockets: " .. socketString)
	end
	if self.requirements and self.requirements.level then
		t_insert(rawLines, "LevelReq: " .. self.requirements.level)
	end
	if self.jewelRadiusLabel then
		t_insert(rawLines, "Radius: " .. self.jewelRadiusLabel)
	end
	if self.limit then
		t_insert(rawLines, "Limited to: " .. self.limit)
	end
	if self.classRestriction then
		t_insert(rawLines, "Requires Class " .. self.classRestriction)
	end
	t_insert(rawLines, "Implicits: " .. (#self.runeModLines + #self.enchantModLines + #self.implicitModLines))
	for _, modLine in ipairs(self.runeModLines) do
		writeModLine(modLine)
	end
	for _, modLine in ipairs(self.enchantModLines) do
		writeModLine(modLine)
	end
	for _, modLine in ipairs(self.classRequirementModLines) do
		writeModLine(modLine)
	end
	for _, modLine in ipairs(self.implicitModLines) do
		writeModLine(modLine)
	end
	for _, modLine in ipairs(self.explicitModLines) do
		writeModLine(modLine)
	end
	if self.mirrored then
		t_insert(rawLines, "Mirrored")
	end
	if self.sanctified then
		t_insert(rawLines, "Sanctified")
	end
	if self.doubleCorrupted then
		t_insert(rawLines, "Twice Corrupted")
	elseif self.corrupted then
		t_insert(rawLines, "Corrupted")
	end
	return table.concat(rawLines, "\n")
end

function ItemClass:BuildAndParseRaw()
	local raw = self:BuildRaw()
	self:ParseRaw(raw)
end

-- Rebuild rune modifiers using the item's runes
function ItemClass:UpdateRunes()
	if self.requirements and self.requirements.naturalLevel then
		self.requirements.level = self.requirements.naturalLevel
	end
	wipeTable(self.runeModLines)
	local getModRunesForTypes = function(runeName, baseType, specificType, soulCoreTypes)
		local rune = data.itemMods.Runes[runeName]
		local gatheredRuneMods = { }
		if rune then
			if rune[baseType] then
				-- for _, mod in pairs(rune[baseType]) do
					t_insert(gatheredRuneMods, rune[baseType])
				-- end
			end
			if rune[specificType] then
				-- for _, mod in pairs(rune[specificType]) do
					t_insert(gatheredRuneMods, rune[specificType])
				-- end
			end
			for soulCoreType in pairs(soulCoreTypes) do
				local soulCoreMod = rune[soulCoreType]
				if soulCoreMod and soulCoreMod.type == "SoulCore" then
					t_insert(gatheredRuneMods, soulCoreMod)
				end
			end
		end
		return gatheredRuneMods
	end

	local statOrder = {}
	local baseType, specificType = self:GetSocketedAugmentTypes()
	local soulCoreTypes = self.socketedSoulCoreTypes
	for i = 1, self.itemSocketCount do
		local name = self.runes[i]
		if name and name ~= "None" then
			local gatheredMods = getModRunesForTypes(name, baseType, specificType, soulCoreTypes)
			for _, mod in ipairs(gatheredMods) do
				for i, modLine in ipairs(mod) do
					local order = mod.statOrder[i]
					local orderKey = mod.type .. ":" .. (modLine:match("^Bonded:") and "Bonded:"..order or order)
					if statOrder[orderKey] then
						-- Combine stats
						local start = 1
						statOrder[orderKey].line = statOrder[orderKey].line:gsub("(%d%.?%d*)", function(num)
							local s, e, other = mod[i]:find("(%d%.?%d*)", start)
							start = e + 1
							return tonumber(num) + tonumber(other)
						end)
						local modList, extra = modLib.parseMod(statOrder[orderKey].line)
						statOrder[orderKey].modList = modList or { }
						statOrder[orderKey].extra = extra
					else
						local modList, extra = modLib.parseMod(modLine)
						local modLine = { line = modLine, order = order, modList = modList or { }, extra = extra, rune = true, enchant = true, augmentType = mod.type }
						for l = 1, #self.runeModLines + 1 do
							if not self.runeModLines[l] or self.runeModLines[l].order > order then
								t_insert(self.runeModLines, l, modLine)
								break
							end
						end
						statOrder[orderKey] = modLine
					end
				end
			end
		end
	end
end

function ItemClass:ApplySocketedRuneDisplayScalars()
	for _, modLine in ipairs(self.runeModLines or { }) do
		local effectModifier = self.socketedAugmentItemEffectModifier or 0
		if modLine.augmentType == "SoulCore" then
			effectModifier = effectModifier + (self.socketedSoulCoreEffectModifier or 0)
		elseif modLine.augmentType == "Rune" then
			effectModifier = effectModifier + (self.socketedRuneEffectModifier or 0)
		end
		if effectModifier and effectModifier ~= 0 and not modLine.socketedRuneEffectAlreadyApplied then
			modLine.displayValueScalar = 1 + effectModifier
		else
			modLine.displayValueScalar = nil
		end
	end
end

-- Rebuild explicit modifiers using the item's affixes
function ItemClass:Craft()
	-- Save off any custom mods so they can be re-added at the end
	local savedMods = {}
	for _, mod in ipairs(self.explicitModLines) do
		if mod.custom then
			t_insert(savedMods, mod)
		end
	end

	wipeTable(self.explicitModLines)
	self.namePrefix = ""
	self.nameSuffix = ""
	self.requirements.level = m_max(self.base.req.level or 0, self.requirements.runeLevel)
	local statOrder = { }
	for _, list in ipairs({self.prefixes,self.suffixes}) do
		for i = 1, (list.limit or (self.affixLimit / 2)) do
			local affix = list[i]
			if not affix then
				list[i] = { modId = "None" }
			end
			local mod = self.affixes[affix.modId]
			if mod then
				if mod.type == "Prefix" then
					self.namePrefix = mod.affix .. " " .. self.namePrefix
				elseif mod.type == "Suffix" then
					self.nameSuffix = self.nameSuffix .. " " .. mod.affix
				end
				self.requirements.level = m_max(self.requirements.level, m_floor(mod.level * 0.8))
				for i, line in ipairs(mod) do
					line = itemLib.applyRange(line, affix.range or 0.5)
					local order = mod.statOrder[i]
					if statOrder[order] then
						-- Combine stats
						local start = 1
						statOrder[order].line = statOrder[order].line:gsub("%d+", function(num)
							local s, e, other = line:find("(%d+)", start)
							start = e + 1
							return tonumber(num) + tonumber(other)
						end)
					else
						local modLine = { line = line, order = order, type = mod.type, modTags = mod.modTags or { }, unscalable = mod.unscalable, fractured = affix.fractured }
						modLine[mod.type:lower()] = true
						for l = 1, #self.explicitModLines + 1 do
							if not self.explicitModLines[l] or self.explicitModLines[l].order > order then
								t_insert(self.explicitModLines, l, modLine)
								break
							end
						end
						statOrder[order] = modLine
					end
				end
			end
		end
	end

	-- Restore the custom mods
	for _, mod in ipairs(savedMods) do
		t_insert(self.explicitModLines, mod)
	end
	if #self.explicitModLines > 1 then
		sortCraftedModLines(self.explicitModLines)
	end

	self:BuildAndParseRaw()
end

function ItemClass:CheckModLineVariant(modLine)
	if self:UsesVersionedOrGroupedVariants() then
		if modLine.versionList and (not self.selectedVersion or not modLine.versionList[self.selectedVersion]) then
			return false
		end
		if modLine.variantGroupList then
			if not modLine.variantList then
				return false
			end
			for groupId in pairs(modLine.variantGroupList) do
				local selectedVariant = self.variantGroupSelections[groupId]
				if selectedVariant and modLine.variantList[selectedVariant] then
					return true
				end
			end
			return false
		end
		if self:HasIndependentVariants() and modLine.variantList then
			return modLine.variantList[self.variant] or false
		end
		return not modLine.variantList
	end
	return not modLine.variantList
		or modLine.variantList[self.variant]
		or (self.hasAltVariant and modLine.variantList[self.variantAlt])
		or (self.hasAltVariant2 and modLine.variantList[self.variantAlt2])
		or (self.hasAltVariant3 and modLine.variantList[self.variantAlt3])
		or (self.hasAltVariant4 and modLine.variantList[self.variantAlt4])
		or (self.hasAltVariant5 and modLine.variantList[self.variantAlt5])
end

function ItemClass:GetModLineVariantCount(modLine)
	if self:UsesVersionedOrGroupedVariants() or not self.allowDuplicateVariants or not modLine.variantList then
		return self:CheckModLineVariant(modLine) and 1 or 0
	end

	-- Mageblood can intentionally select the same variant more than once.
	local variantList = modLine.variantList
	local count = variantList[self.variant] and 1 or 0
	for i = 1, 5 do
		local suffix = i == 1 and "" or i
		local variant = self["variantAlt" .. suffix]
		if self["hasAltVariant" .. suffix] and variant and variantList[variant] then
			count = count + 1
		end
	end
	return count
end

function ItemClass:GetSocketedAugmentTypes()
	local subType = self.base.subType and self.base.subType:lower()
	local itemType = self.base.type:lower()
	local baseType = self.base.weapon and "weapon" or self.base.armour and "armour" or (self.base.tags.wand or self.base.tags.staff or self.base.tags.sceptre) and "caster"
	local specificType =
		(subType == "warstaff" and "quarterstaff") or
		(itemType == "shield" and subType == "evasion" and "buckler") or
		itemType

	if self.socketedAugmentTypeOverride then
		return "armour", self.socketedAugmentTypeOverride
	end

	return baseType, specificType
end

-- Return the name of the slot this item is equipped in
function ItemClass:GetPrimarySlot()
	if self.base.weapon or self.base.type == "Wand" or self.base.type == "Sceptre" or self.base.type == "Staff" then
		return "Weapon 1"
	elseif self.type == "Quiver" or self.type == "Shield" then
		return "Weapon 2"
	elseif self.type == "Ring" then
		return "Ring 1"
	elseif self.type == "Flask" then
		return "Flask 1"
	elseif self.base.subType == "Transcendent Leg" then
		return "Leg 1"
	elseif self.base.subType == "Transcendent Arm" then
		return "Arm 1"
	else
		return self.type
	end
end

function ItemClass:GetArmourDataValue(name, level)
	local armourData = self.armourData
	if not armourData then
		return 0
	end
	return (armourData[name] or 0) + round((armourData[name.."PerLevel"] or 0) * (level or 0))
end

-- Calculate local modifiers, and removes them from the modifier list
-- To be considered local, a modifier must be an exact flag match, and cannot have any tags (e.g. conditions, multipliers)
-- Only the InSlot tag is allowed (for Adds x to x X Damage in X Hand modifiers)
local function calcLocal(modList, name, type, flags)
	local result
	if type == "FLAG" then
		result = false
	elseif type == "MORE" then
		result = 1
	else
		result = 0
	end
	local i = 1
	while modList[i] do
		local mod = modList[i]
		if mod.name == name and mod.type == type and mod.flags == flags and mod.keywordFlags == 0 and (not mod[1] or mod[1].type == "InSlot") then
			if type == "FLAG" then
				result = result or mod.value
			-- convert MORE to times multiplier, e.g. 50% more = 1.5x, result = 1.5
			elseif type == "MORE" then
				result = result * ((100 + mod.value) / 100)
			else
				result = result + mod.value
			end
			t_remove(modList, i)
		else
			i = i + 1
		end
	end
	return result
end

-- Build list of modifiers in a given slot number (1 or 2) while applying local modifiers and adding quality
function ItemClass:BuildModListForSlotNum(baseList, slotNum)
	local slotName = self:GetPrimarySlot()
	if slotNum == 2 then
		slotName = slotName:gsub("1", "2")
	end
	local modList = new("ModList"):ModList()
	for _, baseMod in ipairs(baseList) do
		local mod = copyTable(baseMod)
		local add = true
		for _, tag in ipairs(mod) do
			if tag.type == "SlotNumber" or tag.type == "InSlot" then
				if tag.num ~= slotNum then
					add = false
					break
				end
			end
			for k, v in pairs(tag) do
				if type(v) == "string" then
					tag[k] = v:gsub("{SlotName}", slotName)
							  :gsub("{Hand}", (slotNum == 1) and "MainHand" or "OffHand")
							  :gsub("{OtherSlotNum}", slotNum == 1 and "2" or "1")
				end
			end
		end
		if add then
			mod.sourceSlot = slotName
			modList:AddMod(mod)
		end
	end
	local craftedQuality = calcLocal(modList,"Quality","BASE",0) or 0
	if craftedQuality ~= self.craftedQuality then
		if self.craftedQuality then
			self.quality = (self.quality or 0) - self.craftedQuality + craftedQuality
		end
		self.craftedQuality = craftedQuality
	end
	if self.quality then
		modList:NewMod("Multiplier:QualityOn"..slotName, "BASE", self.quality, "Quality")
	end
	if self.spiritValue then
		local spiritBase = self.base.spirit + calcLocal(modList, "Spirit", "BASE", 0)
		local spiritInc = calcLocal(modList, "Spirit", "INC", 0)
		self.spiritValue = round( spiritBase * (1 + spiritInc / 100))
	end
	if self.charmLimit then
		self.charmLimit = self.base.charmLimit + calcLocal(modList, "CharmLimit", "BASE", 0)
	end
	if self.base.weapon then
		local weaponData = { }
		self.weaponData[slotNum] = weaponData
		weaponData.type = self.base.type
		weaponData.name = self.name
		weaponData.AttackSpeedInc = calcLocal(modList, "Speed", "INC", ModFlag.Attack) + m_floor(self.quality / 8 * calcLocal(modList, "AlternateQualityLocalAttackSpeedPer8Quality", "INC", 0))
		weaponData.AttackRate = round(self.base.weapon.AttackRateBase * (1 + weaponData.AttackSpeedInc / 100), 2)
		weaponData.rangeBonus = calcLocal(modList, "WeaponRange", "BASE", 0) + 10 * calcLocal(modList, "WeaponRangeMetre", "BASE", 0) + m_floor(self.quality / 10 * calcLocal(modList, "AlternateQualityLocalWeaponRangePer10Quality", "BASE", 0))
		weaponData.range = self.base.weapon.Range + weaponData.rangeBonus
		if self.base.weapon.ReloadTimeBase then
			weaponData.ReloadSpeedInc = calcLocal(modList, "ReloadSpeed", "INC", ModFlag.Attack) + weaponData.AttackSpeedInc
			weaponData.ReloadTime = round(self.base.weapon.ReloadTimeBase / (1 + weaponData.ReloadSpeedInc / 100), 2)
		end
		local LocalIncEle = calcLocal(modList, "LocalElementalDamage", "INC", 0)
		for _, dmgType in ipairs(dmgTypeList) do
			local min = (self.base.weapon[dmgType.."Min"] or 0) + calcLocal(modList, dmgType.."Min", "BASE", 0)
			local max = (self.base.weapon[dmgType.."Max"] or 0) + calcLocal(modList, dmgType.."Max", "BASE", 0)
			if dmgType == "Physical" then
				local physInc = calcLocal(modList, "PhysicalDamage", "INC", 0)
				local qualityScalar = self.quality
				if calcLocal(modList, "AlternateQualityWeapon", "BASE", 0) > 0 then
					qualityScalar = 0
				end
				min = round(min * (1 + physInc / 100) * (1 + qualityScalar / 100))
				max = round(max * (1 + physInc / 100) * (1 + qualityScalar / 100))
			elseif dmgType ~= "Physical" and dmgType ~= "Chaos" then
				local localInc = calcLocal(modList, "Local"..dmgType.."Damage", "INC", 0) + LocalIncEle
				min = round(min * (1 + localInc / 100))
				max = round(max * (1 + localInc / 100))
			end
			if min > 0 and max > 0 then
				weaponData[dmgType.."Min"] = min
				weaponData[dmgType.."Max"] = max
				local dps = (min + max) / 2 * weaponData.AttackRate
				weaponData[dmgType.."DPS"] = dps
				if dmgType ~= "Physical" and dmgType ~= "Chaos" then
					weaponData.ElementalDPS = (weaponData.ElementalDPS or 0) + dps
				end
			end
		end
		weaponData.CritChance = round((self.base.weapon.CritChanceBase + calcLocal(modList, "CritChance", "BASE", 0)) * (1 + (calcLocal(modList, "CritChance", "INC", 0) + m_floor(self.quality / 4 * calcLocal(modList, "AlternateQualityLocalCritChancePer4Quality", "INC", 0))) / 100), 2)
		for _, value in ipairs(modList:List(nil, "WeaponData")) do
			weaponData[value.key] = value.value
		end
		for _, mod in ipairs(modList) do
			-- Convert accuracy, crit damage bonus, L/MGoH and PAD Leech modifiers to local
			if (
				(mod.name == "Accuracy" and mod.flags == 0) or (mod.name == "CritMultiplier" and mod.flags == 0) or (mod.name == "ImpaleChance" and mod.flags ~= ModFlag.Spell) or
				((mod.name == "LifeOnHit" or mod.name == "ManaOnHit") and mod.flags == ModFlag.Attack) or
				((mod.name == "PhysicalDamageLifeLeech" or mod.name == "PhysicalDamageManaLeech") and mod.flags == ModFlag.Attack)
			   ) and (mod.keywordFlags == 0 or mod.keywordFlags == KeywordFlag.Attack) and not mod[1] then
				mod[1] = { type = "Condition", var = (slotNum == 1) and "MainHandAttack" or "OffHandAttack" }
			elseif (mod.name == "PoisonChance" or mod.name == "BleedChance") and mod.flags ~= ModFlag.Spell and (not mod[1] or (mod[1].type == "Condition" and mod[1].var == "CriticalStrike" and not mod[2])) then
				t_insert(mod, { type = "Condition", var = (slotNum == 1) and "MainHandAttack" or "OffHandAttack" })
			end
		end
		weaponData.TotalDPS = 0
		for _, dmgType in ipairs(dmgTypeList) do
			weaponData.TotalDPS = weaponData.TotalDPS + (weaponData[dmgType.."DPS"] or 0)
		end
	elseif self.base.armour then
		local armourData = self.armourData
		local armourBase = calcLocal(modList, "Armour", "BASE", 0) + (self.base.armour.Armour or 0)
		local armourEvasionBase = calcLocal(modList, "ArmourAndEvasion", "BASE", 0)
		local evasionBase = calcLocal(modList, "Evasion", "BASE", 0) + (self.base.armour.Evasion or 0)
		local evasionEnergyShieldBase = calcLocal(modList, "EvasionAndEnergyShield", "BASE", 0)
		local energyShieldBase = calcLocal(modList, "EnergyShield", "BASE", 0) + (self.base.armour.EnergyShield or 0)
		local armourEnergyShieldBase = calcLocal(modList, "ArmourAndEnergyShield", "BASE", 0)
		local wardBase = calcLocal(modList, "Ward", "BASE", 0) + (self.base.armour.Ward or 0)
		local evasionPerLevel = calcLocal(modList, "EvasionPerLevel", "BASE", 0)
		local energyShieldPerLevel = calcLocal(modList, "EnergyShieldPerLevel", "BASE", 0)
		local wardPerLevel = calcLocal(modList, "WardPerLevel", "BASE", 0)
		local armourInc = calcLocal(modList, "Armour", "INC", 0)
		local armourEvasionInc = calcLocal(modList, "ArmourAndEvasion", "INC", 0)
		local evasionInc = calcLocal(modList, "Evasion", "INC", 0)
		local evasionEnergyShieldInc = calcLocal(modList, "EvasionAndEnergyShield", "INC", 0)
		local energyShieldInc = calcLocal(modList, "EnergyShield", "INC", 0)
		local wardInc = calcLocal(modList, "Ward", "INC", 0)
		local armourEnergyShieldInc = calcLocal(modList, "ArmourAndEnergyShield", "INC", 0)
		local defencesInc = calcLocal(modList, "Defences", "INC", 0)
		local qualityScalar = self.quality
		if calcLocal(modList, "AlternateQualityArmour", "BASE", 0) > 0 then
			qualityScalar = 0
		end

		armourData.ArmourBase = self.base.armour.Armour or 0
		armourData.Armour = round((armourBase + armourEvasionBase + armourEnergyShieldBase) * (1 + (armourInc + armourEvasionInc + armourEnergyShieldInc + defencesInc) / 100) * (1 + (qualityScalar / 100)))
		armourData.EvasionBase = self.base.armour.Evasion or 0
		armourData.Evasion = round((evasionBase + armourEvasionBase + evasionEnergyShieldBase) * (1 + (evasionInc + armourEvasionInc + evasionEnergyShieldInc + defencesInc) / 100) * (1 + (qualityScalar / 100)))
		armourData.EnergyShieldBase = self.base.armour.EnergyShield or 0
		armourData.EnergyShield = round((energyShieldBase + evasionEnergyShieldBase + armourEnergyShieldBase) * (1 + (energyShieldInc + armourEnergyShieldInc + evasionEnergyShieldInc + defencesInc) / 100) * (1 + (qualityScalar / 100)))
		armourData.WardBase = self.base.armour.Ward or 0
		armourData.Ward = round((wardBase) * (1 + (wardInc + defencesInc) / 100) * (1 + (qualityScalar / 100)))
		armourData.EvasionPerLevel = evasionPerLevel * (1 + (evasionInc + armourEvasionInc + evasionEnergyShieldInc + defencesInc) / 100) * (1 + (qualityScalar / 100))
		armourData.EnergyShieldPerLevel = energyShieldPerLevel * (1 + (energyShieldInc + armourEnergyShieldInc + evasionEnergyShieldInc + defencesInc) / 100) * (1 + (qualityScalar / 100))
		armourData.WardPerLevel = wardPerLevel * (1 + (wardInc + defencesInc) / 100) * (1 + (qualityScalar / 100))

		if self.base.armour.BlockChance then
			armourData.BlockChance = m_floor((self.base.armour.BlockChance + calcLocal(modList, "BlockChance", "BASE", 0)) * (1 + calcLocal(modList, "BlockChance", "INC", 0) / 100))
		end
		if self.base.armour.MovementPenalty then
			modList:NewMod("MovementSpeed", "BASE", -self.base.armour.MovementPenalty, self.modSource, { type = "Condition", var = "IgnoreMovementPenalties", neg = true })
		end
		for _, value in ipairs(modList:List(nil, "ArmourData")) do
			armourData[value.key] = value.value
		end
	elseif self.base.flask then
		local flaskData = self.flaskData
		local durationInc = calcLocal(modList, "Duration", "INC", 0)
		local durationMore = calcLocal(modList, "Duration", "MORE", 0)
		if self.base.flask.life or self.base.flask.mana then
			-- Recovery flask
			flaskData.instantPerc = calcLocal(modList, "FlaskInstantRecovery", "BASE", 0)
			local recoveryMod = 1 + calcLocal(modList, "FlaskRecovery", "INC", 0) / 100
			local rateMod = 1 + calcLocal(modList, "FlaskRecoveryRate", "INC", 0) / 100
			flaskData.duration = round(self.base.flask.duration * (1 + durationInc / 100) / rateMod * durationMore, 1)
			if self.base.flask.life then
				flaskData.lifeBase = self.base.flask.life * (1 + self.quality / 100) * recoveryMod
				flaskData.lifeInstant = flaskData.lifeBase * flaskData.instantPerc / 100
				flaskData.lifeGradual = flaskData.lifeBase * (1 - flaskData.instantPerc / 100)
				flaskData.lifeTotal = flaskData.lifeInstant + flaskData.lifeGradual
				flaskData.lifeAdditional = calcLocal(modList, "FlaskAdditionalLifeRecovery", "BASE", 0)
				flaskData.lifeEffectNotRemoved = calcLocal(baseList, "LifeFlaskEffectNotRemoved", "FLAG", 0)
			end
			if self.base.flask.mana then
				flaskData.manaBase = self.base.flask.mana * (1 + self.quality / 100) * recoveryMod
				flaskData.manaInstant = flaskData.manaBase * flaskData.instantPerc / 100
				flaskData.manaGradual = flaskData.manaBase * (1 - flaskData.instantPerc / 100)
				flaskData.manaTotal = flaskData.manaInstant + flaskData.manaGradual
				flaskData.manaEffectNotRemoved = calcLocal(baseList, "ManaFlaskEffectNotRemoved", "FLAG", 0)
			end
		end
		flaskData.chargesMax = (self.base.flask.chargesMax + calcLocal(modList, "FlaskCharges", "BASE", 0)) * (1 + calcLocal(modList, "FlaskCharges", "INC", 0) / 100)
		flaskData.chargesUsed = m_floor(self.base.flask.chargesUsed * (1 + calcLocal(modList, "FlaskChargesUsed", "INC", 0) / 100))
		flaskData.gainBase = calcLocal(modList, "FlaskChargesGenerated", "BASE", 0)
		flaskData.gainInc = calcLocal(modList, "FlaskChargesGained", "INC", 0)
		flaskData.gainMod = 1 + calcLocal(modList, "FlaskChargeRecovery", "INC", 0) / 100
		flaskData.effectInc = calcLocal(modList, "FlaskEffect", "INC", 0) + calcLocal(modList, "LocalEffect", "INC", 0)
		for _, value in ipairs(modList:List(nil, "FlaskData")) do
			flaskData[value.key] = value.value
		end
	elseif self.base.charm then
		local charmData = self.charmData
		local durationInc = calcLocal(modList, "Duration", "INC", 0)
		local durationMore = calcLocal(modList, "Duration", "MORE", 0)
		charmData.duration = round(self.base.charm.duration * (1 + durationInc / 100) * (1 + self.quality / 100) * durationMore, 1)
		charmData.chargesMax = (self.base.charm.chargesMax + calcLocal(modList, "FlaskCharges", "BASE", 0)) * (1 + calcLocal(modList, "FlaskCharges", "INC", 0) / 100)
		charmData.chargesUsed = m_floor(self.base.charm.chargesUsed * (1 + calcLocal(modList, "FlaskChargesUsed", "INC", 0) / 100))
		charmData.gainBase = calcLocal(modList, "FlaskChargesGenerated", "BASE", 0)
		charmData.gainInc = calcLocal(modList, "FlaskChargesGained", "INC", 0)
		charmData.gainMod = 1 + calcLocal(modList, "FlaskChargeRecovery", "INC", 0) / 100
		charmData.effectInc = calcLocal(modList, "CharmEffect", "INC", 0) + calcLocal(modList, "LocalEffect", "INC", 0)
		for _, value in ipairs(modList:List(nil, "CharmData")) do
			charmData[value.key] = value.value
		end
	elseif self.type == "Jewel" then
		if self.name:find("Grand Spectrum") then
			local spectrumMod = modLib.createMod("Multiplier:GrandSpectrum", "BASE", 1, self.name)
			modList:AddMod(spectrumMod)
			modList:NewMod("MinionModifier", "LIST", { mod = spectrumMod }, self.name)
		end

		local jewelData = self.jewelData
		for _, func in ipairs(modList:List(nil, "JewelFunc")) do
			jewelData.funcList = jewelData.funcList or { }
			t_insert(jewelData.funcList, func)
		end
		for _, value in ipairs(modList:List(nil, "JewelData")) do
			jewelData[value.key] = value.value
		end
		for _, className in ipairs(modList:List(nil, "AlternateClassStart")) do
			jewelData.alternateClassStart = className
		end
		if modList:List(nil, "FromNothingKeystones") then
			jewelData.fromNothingKeystones = { }
			for _, value in ipairs(modList:List(nil, "FromNothingKeystones")) do
				jewelData.fromNothingKeystones[value.key] = value.value
			end
		end
		if self.clusterJewel then
			jewelData.clusterJewelNotables = { }
			for _, name in ipairs(modList:List(nil, "ClusterJewelNotable")) do
				t_insert(jewelData.clusterJewelNotables, name)
			end
			jewelData.clusterJewelAddedMods = { }
			for _, line in ipairs(modList:List(nil, "AddToClusterJewelNode")) do
				t_insert(jewelData.clusterJewelAddedMods, line)
			end

			-- Small and Medium Curse Cluster Jewel passive mods are parsed the same so the medium cluster data overwrites small and the skills differ
			-- This changes small curse clusters to have the correct clusterJewelSkill so it passes validation below and works as expected in the tree
			if jewelData.clusterJewelSkill == "affliction_curse_effect" and jewelData.clusterJewelNodeCount and jewelData.clusterJewelNodeCount < 4 then
				jewelData.clusterJewelSkill = "affliction_curse_effect_small"
			end

			-- Validation
			if jewelData.clusterJewelNodeCount then
				jewelData.clusterJewelNodeCount = m_min(m_max(jewelData.clusterJewelNodeCount, self.clusterJewel.minNodes), self.clusterJewel.maxNodes)
			end
			if jewelData.clusterJewelSkill and not self.clusterJewel.skills[jewelData.clusterJewelSkill] then
				jewelData.clusterJewelSkill = nil
			end
			jewelData.clusterJewelValid = jewelData.clusterJewelKeystone
				or ((jewelData.clusterJewelSkill or jewelData.clusterJewelSmallsAreNothingness) and jewelData.clusterJewelNodeCount)
				or (jewelData.clusterJewelSocketCountOverride and jewelData.clusterJewelNothingnessCount)
		end
	end
	return { unpack(modList) }
end

function getRangedModList(item, modLine)
	if not modLine.range or not modLine.line:find("%((%-?%d+%.?%d*)%-(%-?%d+%.?%d*)%)") then
		return
	end
	local line = itemLib.applyRange(modLine.line:gsub("\n", " "), modLine.range, modLine.valueScalar, modLine.corruptedRange)
	local list, extra = modLib.parseMod(line)
	if itemLib.isZeroValueLine(line) then
		return {}
	end
	return not extra and list
end
-- Build lists of modifiers for each slot the item can occupy
function ItemClass:BuildModList()
	if not self.base then
		return
	end
	local baseList = new("ModList"):ModList()
	if self.base.weapon then
		self.weaponData = { }
	elseif self.base.armour then
		self.armourData = self.armourData or { }
	elseif self.base.flask then
		self.flaskData = { }
		self.buffModList = { }
	elseif self.base.charm then
		self.charmData = { }
		self.buffModList = { }
	elseif self.type == "Jewel" then
		self.jewelData = { }
	end
	self.baseModList = baseList
	self.rangeLineList = { }
	self.modSource = "Item:"..(self.id or -1)..":"..self.name
	for _, modLine in ipairs(self.buffModLines) do
		if not modLine.extra and self:CheckModLineVariant(modLine) then
			for _, mod in ipairs(modLine.modList) do
				mod.source = self.modSource
				t_insert(self.buffModList, mod)
			end
		end
	end
	local function processModLine(modLine)
		if modLine.disabled then
			return
		end
		local variantCount = self:GetModLineVariantCount(modLine)
		if variantCount > 0 then
			-- special section for variant over-ride of pre-modifier item parameters
			if modLine.line:find("Requires Class") then
				self.classRestriction = modLine.line:gsub("{variant:([%d,]+)}", ""):match("Requires Class (.+)")
			end
			if modLine.socketedAugmentTypeOverride then
				self.socketedAugmentTypeOverride = modLine.socketedAugmentTypeOverride
			elseif modLine.socketedSoulCoreType then
				self.socketedSoulCoreTypes[modLine.socketedSoulCoreType] = true
			end
			-- handle understood modifier variable properties
			if not modLine.extra then
				local rangedModList = getRangedModList(self, modLine)
				if rangedModList then
					modLine.modList = rangedModList
					t_insert(self.rangeLineList, modLine)
				end
				for _, mod in ipairs(modLine.modList) do
					for _ = 1, variantCount do
						baseList:AddMod(modLib.setSource(mod, self.modSource))
					end
				end
				if modLine.modTags and #modLine.modTags > 0 then
					self.hasModTags = true
				end
			end
		end
	end
	self.socketedAugmentTypeOverride = nil
	self.socketedSoulCoreTypes = { }
	for _, modLine in ipairs(self.enchantModLines) do
		processModLine(modLine)
	end
	for _, modLine in ipairs(self.runeModLines) do
		processModLine(modLine)
	end
	for _, modLine in ipairs(self.classRequirementModLines) do
		processModLine(modLine)
	end
	for _, modLine in ipairs(self.implicitModLines) do
		processModLine(modLine)
	end
	for _, modLine in ipairs(self.explicitModLines) do
		processModLine(modLine)
	end
	self.socketedSoulCoreEffectModifier = calcLocal(baseList, "SocketedSoulCoreEffect", "INC", 0) / 100
	self.socketedRuneEffectModifier = calcLocal(baseList, "SocketedRuneEffect", "INC", 0) / 100
	self.socketedAugmentItemEffectModifier = calcLocal(baseList, "SocketedAugmentItemEffect", "INC", 0) / 100
	if self.runeModLines[1] then
		self:ApplySocketedRuneDisplayScalars()
	end
	for _, modLine in ipairs(self.runeModLines) do
		local effectModifier = self.socketedAugmentItemEffectModifier or 0
		if modLine.augmentType == "SoulCore" then
			effectModifier = effectModifier + self.socketedSoulCoreEffectModifier
		elseif modLine.augmentType == "Rune" then
			effectModifier = effectModifier + self.socketedRuneEffectModifier
		end
		if effectModifier and effectModifier ~= 0 and self:CheckModLineVariant(modLine) and not modLine.extra and not modLine.socketedRuneEffectAlreadyApplied then
			for _, mod in ipairs(modLine.modList) do
				baseList:ScaleAddMod(mod, effectModifier)
			end
		end
	end
	self.grantedSkills = { }
	for _, skill in ipairs(baseList:List(nil, "ExtraSkill")) do
		if skill.name ~= "Unknown" then
			t_insert(self.grantedSkills, {
				skillId = skill.skillId,
				level = skill.level,
				noSupports = skill.noSupports,
				noReservation = self.base and self.base.grantedSkillsHaveNoReservation or nil,
				source = self.modSource,
				triggered = skill.triggered,
				triggerChance = skill.triggerChance,
			})
		end
	end
	--Sekhema's Resolve
	if baseList:Flag(nil, "JewelSocketRestriction") then
		self.canSocketJewelBase = { }
		self.canSocketJewelBase["Diamond"] = calcLocal(baseList, "CanSocketJewelBaseDiamond", "FLAG", 0)
		self.canSocketJewelBase["Sapphire"] = calcLocal(baseList, "CanSocketJewelBaseSapphire", "FLAG", 0)
		self.canSocketJewelBase["Emerald"] = calcLocal(baseList, "CanSocketJewelBaseEmerald", "FLAG", 0)
		self.canSocketJewelBase["Ruby"] = calcLocal(baseList, "CanSocketJewelBaseRuby", "FLAG", 0)
	end

	if self.name == "Tabula Rasa, Simple Robe" or self.name == "Skin of the Loyal, Simple Robe" or self.name == "Skin of the Lords, Simple Robe" or self.name == "The Apostate, Cabalist Regalia" then
		-- Hack to remove the energy shield and base int requirement
		baseList:NewMod("ArmourData", "LIST", { key = "EnergyShield", value = 0 })
		self.requirements.int = 0
	end
	if self.name == "Geofri's Sanctuary, Revered Vestments" then
		baseList:NewMod("ArmourData", "LIST", { key = "EnergyShield", value = 0 })
	end
	if calcLocal(baseList, "NoAttributeRequirements", "FLAG", 0) then
		self.requirements.strMod = 0
		self.requirements.dexMod = 0
		self.requirements.intMod = 0
	elseif calcLocal(baseList, "AttributeRequirementsConverted", "FLAG", 0) then
		local strConversion = calcLocal(baseList, "AttributeRequirementsConvertedToStrength", "BASE", 0) / 100
		local dexConversion = calcLocal(baseList, "AttributeRequirementsConvertedToDexterity", "BASE", 0) / 100
		local intConversion = calcLocal(baseList, "AttributeRequirementsConvertedToIntelligence", "BASE", 0) / 100
		self.requirements.intBase = intConversion * (self.requirements.str + self.requirements.dex) + (self.requirements.int + calcLocal(baseList, "IntRequirement", "BASE", 0)) - self.requirements.int * (strConversion + dexConversion)
		self.requirements.intMod = m_floor(self.requirements.intBase * (1 + calcLocal(baseList, "IntRequirement", "INC", 0) / 100))
		self.requirements.dexBase = dexConversion * (self.requirements.str + self.requirements.int) + (self.requirements.dex + calcLocal(baseList, "DexRequirement", "BASE", 0)) - self.requirements.dex * (strConversion + intConversion)
		self.requirements.dexMod = m_floor( self.requirements.dexBase * (1 + calcLocal(baseList, "DexRequirement", "INC", 0) / 100))
		self.requirements.strBase = strConversion * (self.requirements.int + self.requirements.dex) + (self.requirements.str + calcLocal(baseList, "StrRequirement", "BASE", 0)) - self.requirements.str * (dexConversion + intConversion)
		self.requirements.strMod = m_floor(self.requirements.strBase * (1 + calcLocal(baseList, "StrRequirement", "INC", 0) / 100))
	else
		self.requirements.strMod = m_floor((self.requirements.str + calcLocal(baseList, "StrRequirement", "BASE", 0)) * (1 + calcLocal(baseList, "StrRequirement", "INC", 0) / 100))
		self.requirements.dexMod = m_floor((self.requirements.dex + calcLocal(baseList, "DexRequirement", "BASE", 0)) * (1 + calcLocal(baseList, "DexRequirement", "INC", 0) / 100))
		self.requirements.intMod = m_floor((self.requirements.int + calcLocal(baseList, "IntRequirement", "BASE", 0)) * (1 + calcLocal(baseList, "IntRequirement", "INC", 0) / 100))
	end
	if self.itemSocketCount > 0 then
		-- Ensure that there are the correct number of abyssal sockets present
		local newSockets = { }
		local group = 0
		for i = 1, self.itemSocketCount do
			group = group + 1
			t_insert(newSockets, {group = group})
		end
		self.sockets = newSockets
	end
	self.socketedJewelEffectModifier = 1 + calcLocal(baseList, "SocketedJewelEffect", "INC", 0) / 100
	if self.base.weapon or self.base.type == "Wand" or self.base.type == "Sceptre" or self.base.type == "Staff" or self.type == "Ring" then
		self.slotModList = { }
		for i = 1, 2 do
			self.slotModList[i] = self:BuildModListForSlotNum(baseList, i)
		end
		if self.type == "Ring" then
			self.slotModList[3] = self:BuildModListForSlotNum(baseList, 3)
		end
	else
		self.modList = self:BuildModListForSlotNum(baseList)
	end
end
