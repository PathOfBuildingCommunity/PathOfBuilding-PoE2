-- Path of Building
--
-- Module: Trade Query Generator
-- Generates weighted trade queries for item upgrades
--

local dkjson = require "dkjson"
local curl = require("lcurl.safe")
local m_max = math.max
local s_format = string.format
local t_insert = table.insert
local tradeHelpers = LoadModule("Classes/TradeHelpers")

-- string are an any type while tables require all fields to be matched with type and subType require both to be matched exactly. [1] type, [2] subType, subType is optional and must be nil if not present.
local tradeCategoryNames = {
	["Ring"] = { "Ring" },
	["Amulet"] = { "Amulet" },
	["Belt"] = { "Belt" },
	["Chest"] = { "Body Armour", "Body Armour: Armour", "Body Armour: Armour/Energy Shield", "Body Armour: Armour/Evasion", "Body Armour: Armour/Evasion/Energy Shield", "Body Armour: Energy Shield", "Body Armour: Evasion", "Body Armour: Evasion/Energy Shield" },
	["Helmet"] = { "Helmet", "Helmet: Armour", "Helmet: Armour/Energy Shield", "Helmet: Armour/Evasion", "Helmet: Armour/Evasion/Energy Shield", "Helmet: Energy Shield", "Helmet: Evasion", "Helmet: Evasion/Energy Shield" },
	["Gloves"] = { "Gloves: Armour", "Gloves: Armour/Energy Shield", "Gloves: Armour/Evasion", "Gloves: Armour/Evasion/Energy Shield", "Gloves: Energy Shield", "Gloves: Evasion", "Gloves: Evasion/Energy Shield" },
	["Boots"] = { "Boots", "Boots: Armour", "Boots: Armour/Energy Shield", "Boots: Armour/Evasion", "Boots: Armour/Evasion/Energy Shield", "Boots: Energy Shield", "Boots: Evasion", "Boots: Evasion/Energy Shield" },
	["Quiver"] = { "Quiver" },
	["Shield"] = { "Shield", "Shield: Armour", "Shield: Armour/Energy Shield", "Shield: Armour/Evasion", "Shield: Evasion" },
	["Focus"] = { "Focus" },
	["1HWeapon"] = { "One Hand Mace", "Wand", "Sceptre", "Flail", "Spear" },
	["2HWeapon"] = { "Staff", "Staff: Warstaff", "Two Hand Mace", "Crossbow", "Bow", "Talisman" },
	-- ["1HAxe"] = { "One Hand Axe" },
	-- ["1HSword"] = { "One Hand Sword", "Thrusting One Hand Sword" },
	["1HMace"] = { "One Hand Mace" },
	["Sceptre"] = { "Sceptre" },
	-- ["Dagger"] = { "Dagger" },
	["Wand"] = { "Wand" },
	-- ["Claw"] = { "Claw" },
	["Talisman"] = { "Talisman" },
	["Staff"] = { "Staff" },
	["Quarterstaff"] = { "Staff: Warstaff" },
	["Bow"] = { "Bow" },
	["Crossbow"] = { "Crossbow"},
	-- ["2HAxe"] = { "Two Hand Axe" },
	-- ["2HSword"] = { "Two Hand Sword" },
	["2HMace"] = { "Two Hand Mace" },
	-- ["FishingRod"] = { "Fishing Rod" },
	["BaseJewel"] = { "Jewel" },
	["RadiusJewel"] = { "Jewel: Radius" },
	["AnyJewel"] = { "Jewel", "Jewel: Radius" },
	["LifeFlask"] = { "Flask: Life" },
	["ManaFlask"] = { "Flask: Mana" },
	["Charm"] = { "Charm" },
	-- doesn't have trade mods
	-- not in the game yet.
	-- ["TrapTool"] = { "TrapTool"}, Unsure if correct
	["Flail"] = { "Flail" },
	["Spear"] = { "Spear" }
}

-- Build lists of tags present on a given item category
local tradeCategoryTags = { }
for type, bases in pairs(data.itemBaseLists) do
	for _, base in ipairs(bases) do
		if not base.hidden then
			if not tradeCategoryTags[type] then
				tradeCategoryTags[type] = { }
			end
			local baseTags = { }
			for tag, _ in pairs(base.base.tags) do
				if tag ~= "default" and tag ~= "demigods" and not tag:match("_basetype") and tag ~= "not_for_sale" then -- filter fluff tags not used on mods.
					baseTags[tag] = true
				end
			end
			local present = false
			for i, tags in ipairs(tradeCategoryTags[type]) do
				if tableDeepEquals(baseTags, tags) then
					present = true
				end
			end
			if not present then
				t_insert(tradeCategoryTags[type], baseTags)
			end
		end
	end
end


---@return table[]? category list of entries for the mod type
local function getStatEntries(modType)
	local tradeStats = tradeHelpers.getTradeStats()
	local tradeStatCategoryIndices = {
		["Explicit"] = "explicit",
		["Implicit"] = "implicit",
		["Corrupted"] = "enchant",
		["AllocatesXEnchant"] = "enchant",
		-- note that in the json the label is augment while the id is rune
		["Rune"] = "rune",
		["HeartOfTheWell"] = "explicit",
		["AgainstTheDarkness"] = "explicit",
	}
	if tradeStatCategoryIndices[modType] then
		for i, cat in ipairs(tradeStats) do
			if cat.id == tradeStatCategoryIndices[modType] then
				return cat.entries
			end
		end
	end
end

local MAX_FILTERS = 35

local function logToFile(...)
	ConPrintf(...)
end

local TradeQueryGeneratorClass = newClass("TradeQueryGenerator", function(self, queryTab)
	self:InitMods()
	self.queryTab = queryTab
	self.itemsTab = queryTab.itemsTab
	self.calcContext = { }
	self.lastMaxPrice = nil
	self.lastMaxPriceTypeIndex = nil
	self.lastMaxLevel = nil
end)

local function canModSpawnForItemCategory(mod, names)
	for _, name in pairs(tradeCategoryNames[names]) do
		for _, tags in ipairs(tradeCategoryTags[name]) do
			for i, key in ipairs(mod.weightKey) do
				if tags[key] then
					if mod.weightVal[i] > 0 then
						return true
					else
						break
					end
				end
			end
		end
	end
	return false
end

-- Swaps mod word for its antonym
local function swapInverse(modLine)
	if modLine:match("increased") then
		modLine = modLine:gsub("([^ ]+) increased", "%1 reduced")
	elseif modLine:match("reduced") then
		modLine = modLine:gsub("([^ ]+) reduced", "%1 increased")
	elseif modLine:match("more") then
		modLine = modLine:gsub("([^ ]+) more", "%1 less")
	elseif modLine:match("less") then
		modLine = modLine:gsub("([^ ]+) less", "%1 more")
	elseif modLine:match("expires ([^ ]+) slower") then
		modLine = modLine:gsub("([^ ]+) slower", "%1 faster")
	elseif modLine:match("expires ([^ ]+) faster") then
		modLine = modLine:gsub("([^ ]+) faster", "%1 slower")
	end
	return modLine
end

function TradeQueryGeneratorClass.WeightedRatioOutputs(baseOutput, newOutput, statWeights)
	local meanStatDiff = 0

	local function ratioModSums(...)
		local baseModSum = 0
		local newModSum = 0
		for _, mod in ipairs({ ... }) do
			baseModSum = baseModSum + data.powerStatList.GetFromOutput(baseOutput, mod)
			newModSum = newModSum + data.powerStatList.GetFromOutput(newOutput, mod)
		end

		if baseModSum == math.huge then
			return 0
		else
			if newModSum == math.huge then
				return data.misc.maxStatIncrease
			else
				return math.min(newModSum / ((baseModSum ~= 0) and baseModSum or 1), data.misc.maxStatIncrease)
			end
		end
	end
	for _, statTable in ipairs(statWeights) do
		local modSumRatio
		if statTable.stat == "FullDPS" and not (baseOutput["FullDPS"] and newOutput["FullDPS"]) then
			modSumRatio = ratioModSums({ stat = "TotalDPS" }, { stat = "TotalDotDPS" }, { stat = "CombinedDPS" })
		else
			modSumRatio = ratioModSums(statTable)
		end
		-- some weights, such as damage taken from hit need to be negated as lower is better for them
		if statTable.transform then
			modSumRatio = statTable.transform(modSumRatio)
		end
		meanStatDiff = meanStatDiff + modSumRatio * statTable.weightMult
	end
	return meanStatDiff
end


function TradeQueryGeneratorClass:ProcessMod(mod, itemCategoriesMask, itemCategoriesOverride)
-- processes mods from the data exports to a format that is more useful for
-- generating weights.

-- this function generally uses the .tradeHashes field of each exported mod,
-- which contains a map from the trade hash to the mod lines/stats

-- at a high level, this function matches each stat / mod line to an entry in
-- https://www.pathofexile.com/api/trade2/data/stats via the trade hash. that
-- entry is then used to determine if the mod is inverted, i.e. that the mod
-- here is x increased by y, while the trade site has x decreased by -y. the
-- function also records the minimum and maximum values of each stat, so we can
-- later test for a midpoint of those values to generate a weight
	for tradeHash, modLines in pairs(mod.tradeHashes) do
		-- the mod export sometimes splits stats to multiple lines. they should
		-- still get parsed correctly if we combine them, and that makes it
		-- simpler to process them
		local modLine = table.concat(modLines, " ")
		if modLine:find("Grants Level") or modLine:find("inflict Decay") then -- skip mods that grant skills / decay, as they will often be overwhelmingly powerful but don't actually fit into the build
			goto nextModLine
		end

		local modType = (mod.type == "Prefix" or mod.type == "Suffix") and "Explicit" or mod.type == "SpecialCorrupted" and "Corrupted" or mod.type

		if not modType then
			ConPrintf("Unable to match mod due to missing mod type: %s", modLine)
			goto continue
		end

		-- Special cases
		local specialCaseData = { }
		if modLine == "You can apply an additional Curse" then
			specialCaseData.overrideModLineSingular = "You can apply an additional Curse"
			modLine = "You can apply 1 additional Curses"
		elseif modLine == "Bow Attacks fire an additional Arrow" then
			specialCaseData.overrideModLineSingular = "Bow Attacks fire an additional Arrow"
			modLine = "Bow Attacks fire 1 additional Arrows"
		elseif modLine:find("Charm Slots") then
			specialCaseData.overrideModLinePlural = "+# Charm Slots"
			modLine = modLine:gsub("Slots", "Slot")
		end

		-- iterate trade mod category to find mod with matching text.
		local function getTradeMod()
			local entry
			local tradeHashStr = tostring(tradeHash)
			for _, v in ipairs(getStatEntries(modType) or {}) do
				-- prefix removed
				local ids = v.id:gsub(".+..stat_", "").."|"
				-- split by non-integer
				for id in ids:gmatch("%d+") do
					if tradeHashStr == id then
						entry = v
						goto finish
					end
				end
			end
			::finish::

			if not entry then
				return nil
			end

			-- determine if the mod is inversed, i.e. increased here -> reduced on trade
			local pattern = "[#()0-9%-%+%.]"
			local matchStr = modLine:gsub(pattern,"")
			local inverseMatchStr = swapInverse(matchStr)
			if entry.text:gsub(pattern, "") == matchStr then
				return entry, false
			elseif entry.text:gsub(pattern, "") == inverseMatchStr then
				return entry, true
			end
			return entry
		end

		local tradeMod = nil
		local invert

		local uniqueIndex = tostring(tradeHash)

		if self.modData[modType][uniqueIndex] == nil then
			if tradeMod == nil then
				tradeMod, invert = getTradeMod()
			end
			if tradeMod == nil then
				logToFile("Unable to match %s mod: %s", modType, modLine)
				goto nextModLine
			end
			self.modData[modType][uniqueIndex] = { tradeMod = tradeMod, specialCaseData = { } }
		elseif self.modData[modType][uniqueIndex].tradeMod.text:gsub("[#()0-9%-%+%.]","") == swapInverse(modLine):gsub("[#()0-9%-%+%.]","") and swapInverse(modLine) ~= modLine then -- if the swapped mod matches the inverse then consider it inverted, provide it changed.
			invert = true
		end

		-- this is safe as we go to next line if the mod can't be found.
		for key, value in pairs(specialCaseData) do
			self.modData[modType][uniqueIndex].specialCaseData[key] = value
		end

		if invert then
			self.modData[modType][uniqueIndex].invertOnNegative = true
			modLine = swapInverse(modLine)
		end

		-- tokenize the numerical variables for this mod and store the sign if there is one
		local tokens = { }
		local poundStartPos, poundEndPos, tokenizeOffset = 0, 0, 0
		while true do
			poundStartPos, poundEndPos = self.modData[modType][uniqueIndex].tradeMod.text:find("[%+%-]?#", poundEndPos + 1)
			if poundStartPos == nil then
				break
			end

			local startPos, endPos, sign, min, max = modLine:find("([%+%-]?)%(?(%d+%.?%d*)%-?(%d*%.?%d*)%)?", poundStartPos + tokenizeOffset)

			if endPos == nil then
				logToFile("[GMD] Error extracting tokens from '%s' for tradeMod '%s'", modLine, self.modData[modType][uniqueIndex].tradeMod.text)
				goto nextModLine
			end

			max = #max > 0 and tonumber(max) or tonumber(min)

			tokenizeOffset = tokenizeOffset + (endPos - startPos)

			-- the values are negative record its ranges as such.
			if (invert or sign == "-") and not (invert and sign == "-") then
				local temp = max
				max = -min
				min = -temp
			end

			if sign == "+" then self.modData[modType][uniqueIndex].usePositiveSign = true end

			t_insert(tokens, min)
			t_insert(tokens, max)
		end

		if #tokens ~= 0 and #tokens ~= 2 and #tokens ~= 4 then
			logToFile("Unexpected # of tokens found for mod: %s", modLine)
			goto nextModLine
		end

		-- Update the min and max values available for each item category
		for category, _ in pairs(itemCategoriesOverride or itemCategoriesMask or tradeCategoryNames) do
			if itemCategoriesOverride or canModSpawnForItemCategory(mod, category) then
				if self.modData[modType][uniqueIndex][category] == nil then
					self.modData[modType][uniqueIndex][category] = { min = 999999, max = -999999 }
				end

				local modRange = self.modData[modType][uniqueIndex][category]
				if #tokens == 0 then
					modRange.min = 1
					modRange.max = 1
				elseif #tokens == 2 then
					modRange.min = math.min(modRange.min, tokens[1])
					modRange.max = math.max(modRange.max, tokens[2])
				elseif #tokens == 4 then
					modRange.min = math.min(modRange.min, (tokens[1] + tokens[3]) / 2)
					modRange.max = math.max(modRange.max, (tokens[2] + tokens[4]) / 2)
				end
			end
		end
		::nextModLine::
	end
	::continue::
end

function TradeQueryGeneratorClass:GenerateModData(mods, itemCategoriesMask, itemCategoriesOverride)
	for _, mod in pairsSortByKey(mods) do
		self:ProcessMod( mod, itemCategoriesMask, itemCategoriesOverride)
	end
end

function TradeQueryGeneratorClass:InitMods()
	local queryModFilePath = "Data/QueryMods.lua"

	local file = io.open(queryModFilePath,"r")
	if file then
		file:close()
		self.modData = LoadModule(queryModFilePath)
		return
	end

	-- Download stats JSON from GGG API. Do not use launch:DownloadPage here as it is async, and QueryMods.lua must use the freshly downloaded stats.
	local tradeStats = ""
	local easy = curl.easy()
	easy:setopt_url("https://www.pathofexile.com/api/trade2/data/stats")
	easy:setopt_useragent("Path of Building/" .. launch.versionNumber)
	easy:setopt_writefunction(function(data)
		tradeStats = tradeStats..data
		return true
	end)
	local ok = easy:perform()
	easy:close()
	if not ok or tradeStats == "" then
		error("Error while downloading stats.json")
	end
	local body = dkjson.decode(tradeStats)

	if body.error then
		error("Error received from api/trade2/data/stats: "..body.error.message)
	end

	local f = io.open("./Data/TradeSiteStats.lua", "w")
	if not f then
		error("Could not open file for writing trade stat data")
	end

	for catIdx, _ in ipairs(body.result) do
		table.sort(body.result[catIdx].entries, function(a, b)
			if a.text == b.text then
				return a.id < b.id
			end
			return a.text < b.text
		end)
	end

	local template = [[-- This file is automatically downloaded, do not edit!
-- Trade site stat data (c) Grinding Gear Games
-- https://www.pathofexile.com/api/trade2/data/stats
-- spell-checker: disable
return %s
-- spell-checker: enable]]
	f:write(s_format(template, stringify(body.result)))
	f:close()

	self.modData = {
		["Explicit"] = { },
		["Implicit"] = { },
		["Corrupted"] = { },
		["Enchant"] = { },
		["AllocatesXEnchant"] = { },
		["Rune"] = { },
		["HeartOfTheWell"] = { },
		["AgainstTheDarkness"] = { },
	}

	-- create mask for regular mods
	local regularItemMask = { }
	for category, _ in pairs(tradeCategoryNames) do
		regularItemMask[category] = true
	end

	self:GenerateModData(data.itemMods.Item, regularItemMask)
	self:GenerateModData(data.itemMods.Desecrated, regularItemMask)
	self:GenerateModData(data.itemMods.Corruption, regularItemMask)
	self:GenerateModData(data.itemMods.Jewel, { ["BaseJewel"] = true, ["AnyJewel"] = true, ["RadiusJewel"] = true })
	self:GenerateModData(data.itemMods.Flask, { ["LifeFlask"] = true, ["ManaFlask"] = true })
	self:GenerateModData(data.itemMods.Charm, { ["Charm"] = true })

	-- add breach mods which lack proper weights. these mods spawn for either belts or rings, but
	-- have weights of zero for ones they cannot spawn on
	for name, mod in pairs(data.itemMods.Item) do
		local treeMod = false
		local slots = {Ring = true, Belt = true}
		for i, v in ipairs(mod.weightKey) do
			if v == "genesis_tree_minion" or v == "genesis_tree_caster" then
				treeMod = true
			end
			if (v == "belt") and mod.weightVal[i] == 0 then
				slots.Belt = nil
			end
			if (v == "ring") and mod.weightVal[i] == 0 then
				slots.Ring = nil
			end
		end
		if treeMod then
			self:ProcessMod(mod, regularItemMask, slots)
			goto continueBreach
		end

		-- there are also crafted mods which can be identified based on the name
		if name:match("^GenesisTreeRing") then
			self:ProcessMod(mod, regularItemMask, {Ring = true})
		end
		if name:match("^GenesisTreeBelt") then
			self:ProcessMod(mod, regularItemMask, {Belt = true})
		end
		::continueBreach::
	end

	-- essences, because in item mod data they don't have equipment tags
	for name, essence in pairs(data.essences) do
		-- weird exception: linked to mod that says "% dex int or str"
		if name:find("Perfect") and not (name == "Metadata/Items/Currency/CurrencyPerfectEssenceAttribute") then
			for itemType, modName in pairs(essence.mods) do
				local mask = {}
				local itemType = itemType == "Warstaff" and "Quarterstaff" or itemType
				mask[itemType] = true
				self:ProcessMod(data.itemMods.Item[modName], regularItemMask, mask)
			end
		end
	end
	-- fix the weird exception
	for _, v in ipairs({"EssencePercentStrength1", "EssencePercentDexterity1", "EssencePercentIntelligence1"}) do
		self:ProcessMod(data.itemMods.Item[v], regularItemMask, { Amulet = true }, "explicit")
	end

	for _, entry in ipairs(getStatEntries("AllocatesXEnchant") or {}) do
		if entry.text:sub(1, 10) == "Allocates " then
			-- The trade id for allocatesX enchants end with "|[nodeID]" for the allocated node.
			local nodeId = entry.id:sub(entry.id:find("|") + 1)
			self.modData.AllocatesXEnchant[nodeId] = { tradeMod = entry, specialCaseData = { } }
		end
	end

	-- heart of the well mods
	local heartMods = {}
	for name, mod in pairsSortByKey(data.itemMods.Desecrated) do
		if name:match("^UniqueHeart") then
			local modCopy = copyTable(mod)
			modCopy.type = "HeartOfTheWell"
			t_insert(heartMods, modCopy)
		end
	end
	self:GenerateModData(heartMods, { ["BaseJewel"] = true, ["AnyJewel"] = true }, { ["AnyJewel"] = "AnyJewel" })

	-- against the darkness mods
	local darknessMods = {}
	for name, mod in pairsSortByKey(data.itemMods.Exclusive) do
		-- this name prefix is not very unique and already matches some mods that don't exist on the
		-- jewel. this might cause problems later
		if name:match("^UniqueJewelRadius") then
			local modCopy = copyTable(mod)
			modCopy.type = "AgainstTheDarkness"
			t_insert(darknessMods, modCopy)
		end
	end
	self:GenerateModData(darknessMods, { ["RadiusJewel"] = true, ["AnyJewel"] = true }, { ["AnyJewel"] = "AnyJewel" })

	-- implicit mods
	for baseName, entry in pairsSortByKey(data.itemBases) do
		if entry.implicit ~= nil and entry.type ~= "Transcendent Limb" then
			local mod = { type = "Implicit" }
			for modLine in string.gmatch(entry.implicit, "([^".."\n".."]+)") do
				t_insert(mod, modLine)
			end

			local found = false
			for _, modLine in ipairs(mod) do
				if modLine:find("Grants Skill:") then
					goto continue
				end
				for _, v in pairs(data.itemMods.Exclusive) do
					if v[1] == modLine then
						found = true
						mod = v
						mod.type = "Implicit"
						-- it is possible for there to be multiple matches. For example "+(20-30) to
						-- maximum Energy Shield" tends to match both the amulet implicit and some
						-- other unique mod which is local energy shield instead. in that case it
						-- incorrectly gets mapped to the local stat. this is however super rare as
						-- it needs the ranges to match exactly.
						break
					end
				end
			end
			if not found then
				ConPrintf("unknown implicit mod: %s", mod[1])
				goto continue
			end

			-- create trade type mask for base type
			local maskOverride = {}
			for tradeName, typeNames in pairs(tradeCategoryNames) do
				for _, typeName in ipairs(typeNames) do
					local entryName = entry.type
					if entry.subType then
							entryName = entryName..": "..entry.subType
					end
					if typeName == entryName then
						maskOverride[tradeName] = true;
						break
					end
				end
			end

			-- mask found process implicit mod this avoids processing unimplemented bases i.e. two handed axes.
			if next(maskOverride) ~= nil then
				self:ProcessMod(mod, regularItemMask, maskOverride)
			end
		end
		::continue::
	end

	-- -- rune mods
	for name, runeMods in pairsSortByKey(data.itemMods.Runes) do
		for slotType, mods in pairs(runeMods) do
			for i, modLine in ipairs(mods) do
				local mod = {modLine, tradeHashes = mods.tradeHashes, type = "Rune"}
				if slotType == "weapon" then
					self:ProcessMod(mod, regularItemMask, { ["1HWeapon"] = true, ["2HWeapon"] = true, ["1HMace"] = true, ["Claw"] = true, ["Quarterstaff"] = true, ["Bow"] = true, ["2HMace"] = true, ["Crossbow"] = true, ["Spear"] = true, ["Flail"] = true, ["Talisman"] = true  })
				elseif slotType == "armour" then
					self:ProcessMod(mod, regularItemMask, { ["Shield"] = true, ["Chest"] = true, ["Helmet"] = true, ["Gloves"] = true, ["Boots"] = true, ["Focus"] = true })
				elseif slotType == "caster" then
					self:ProcessMod(mod, regularItemMask, { ["Wand"] = true, ["Staff"] = true })
				else
					-- Mod is slot specific, try to match against a value in tradeCategoryNames
					local matchedCategories = {}
					for category, categoryOptions in pairs(tradeCategoryNames) do
						for _, opt in ipairs(categoryOptions) do
							-- warstaves have inconsistent naming and need special handling
							if opt:lower() == slotType or ((opt == "Staff: Warstaff") and (slotType == "warstaff")) then
								matchedCategories[category] = true
							end
						end
					end
					if next(matchedCategories) then
						self:ProcessMod(mod, regularItemMask, matchedCategories)
					else
						ConPrintf("TradeQuery: Unmatched category for modifier. Slot type: %s Modifier: %s Mod line: %s", mods.slotType, mods.name, modLine)
					end
				end
			end
		end
	end

	-- 0.5 rune influence mods. e.g. can roll chronomancy modifiers

	-- a map of slot to weight key which is on the mods
	local runeInfluences = { Boots = { "chronomancy" }, Gloves = { "marksman", "decay" }, Helmets = { "berserking" }, Weapon = { "destruction" }, ["Body Armour"] = { "soul" } }
	local function hasSpawnTag(mod, tag)
		local idx = 1
		while mod.weightKey[idx] do
			if (mod.weightKey[idx] == tag) and (mod.weightVal[idx] > 0) then
				return true
			end
			idx = idx + 1
		end
		return false
	end
	for slot, tags in pairsSortByKey(runeInfluences) do
		for _, tag in ipairs(tags) do
			local mods = {}
			for _, mod in pairsSortByKey(data.itemMods.Item) do
				if hasSpawnTag(mod, tag) then
					t_insert(mods, mod)
				end
			end
			local itemCategories = (slot == "Weapon") and ({ ["1HWeapon"] = true, ["2HWeapon"] = true, ["1HMace"] = true, ["Claw"] = true, ["Quarterstaff"] = true, ["Bow"] = true, ["2HMace"] = true, ["Crossbow"] = true, ["Spear"] = true, ["Flail"] = true, ["Talisman"] = true }) or { [slot] = true }
			self:GenerateModData(mods, regularItemMask, itemCategories)
		end
	end

	local queryModsFile = io.open(queryModFilePath, 'w')
	queryModsFile:write([[-- This file is automatically generated, do not edit!
-- Stat data (c) Grinding Gear Games

-- This file contains categories of stats, mapped from trade hash to details
-- relevant for generating search weights Note that the trade site requires a
-- prefix of e.g. explicit.stat_{hash}. See
-- https://www.pathofexile.com/api/trade2/data/stats for a list of all trade
-- site stats.

]])
	queryModsFile:write("return " .. stringify(self.modData))
	queryModsFile:close()
end

function TradeQueryGeneratorClass:GenerateModWeights(modsToTest)
	local start = GetTime()
	for _, entry in pairs(modsToTest) do
		if entry[self.calcContext.itemCategory] ~= nil then
			if self.alreadyWeightedMods[entry.tradeMod.id] ~= nil then -- Don't calculate the same thing twice (can happen with corrupted vs implicit)
				goto continue
			end

			-- Test with a value halfway (or configured default Item Affix Quality) between the min and max available for this mod in this slot. Note that this can generate slightly different values for the same mod as implicit vs explicit.
			local tradeModValue = math.ceil((entry[self.calcContext.itemCategory].max - entry[self.calcContext.itemCategory].min) * ( main.defaultItemAffixQuality or 0.5 ) + entry[self.calcContext.itemCategory].min)
			local modValue = tradeModValue
			-- Apply override text for special cases
			local modLine
			if (modValue == 1 or modValue == -1) and entry.specialCaseData.overrideModLineSingular ~= nil then
				modLine = entry.specialCaseData.overrideModLineSingular
			elseif (modValue ~= 1 and modValue ~= -1) and entry.specialCaseData.overrideModLinePlural ~= nil then
				modLine = entry.specialCaseData.overrideModLinePlural
			elseif entry.specialCaseData.overrideModLine ~= nil then
				modLine = entry.specialCaseData.overrideModLine
			else
				modLine = entry.tradeMod.text
			end

			if entry.invertOnNegative and modValue < 0 then
				modLine = swapInverse(modLine)
				modValue = -1 * modValue
			end

			-- trade mod dictates a plus is used in front of positive values.
			if modLine:find("+#") and modValue >= 0 then
				modLine = modLine:gsub("#", modValue)
			else
				if entry.usePositiveSign and modValue >= 0 then
					modLine = modLine:gsub("#", "+"..tostring(modValue))
				else
					modLine = modLine:gsub("+?#", modValue)
				end
			end

			-- remove (Local) suffix so pob parses the mod correctly
			modLine = modLine:gsub("%(Local%)", "")

			self.calcContext.testItem.explicitModLines[1] = { line = modLine, custom = true }
			self.calcContext.testItem:BuildAndParseRaw()

			if (self.calcContext.testItem.modList ~= nil and #self.calcContext.testItem.modList == 0) or (self.calcContext.testItem.slotModList ~= nil and #self.calcContext.testItem.slotModList[1] == 0 and #self.calcContext.testItem.slotModList[2] == 0) then
				logToFile("Failed to test %s mod: %s", self.calcContext.itemCategory, modLine)
			end

			local output = self.calcContext.calcFunc({ repSlotName = self.calcContext.slot.slotName, repItem = self.calcContext.testItem })
			local meanStatDiff = TradeQueryGeneratorClass.WeightedRatioOutputs(self.calcContext.baseOutput, output, self.calcContext.options.statWeights) * 1000 - (self.calcContext.baseStatValue or 0)
			if meanStatDiff > 0.01 then
				t_insert(self.modWeights, { tradeModId = entry.tradeMod.id, weight = meanStatDiff / tradeModValue, meanStatDiff = meanStatDiff })
			end
			self.alreadyWeightedMods[entry.tradeMod.id] = true

			local now = GetTime()
			if now - start > 50 then
				-- Would be nice to update x/y progress on the popup here, but getting y ahead of time has a cost, and the visual seems to update on a significant delay anyways so it's not very useful
				coroutine.yield()
				start = now
			end
		end
		::continue::
	end
end

function TradeQueryGeneratorClass:GeneratePassiveNodeWeights(nodesToTest)
	local start = GetTime()
	for nodeId, entry in pairs(nodesToTest) do
		if self.alreadyWeightedMods[entry.tradeMod.id] ~= nil then
			ConPrintf("Node %s already evaluated", nodeId)
			goto continue
		end

		local node = self.itemsTab.build.spec.nodes[tonumber(nodeId)]
		if not node then
			local nodeName = entry.tradeMod.text:match("1 Added Passive Skill is (.*)") or entry.tradeMod.text:match("Allocates (.*)")
			node = nodeName and self.itemsTab.build.spec.tree.notableMap[nodeName:lower()]
			if not node then
				ConPrintf("Failed to find node %s", nodeId)
				goto continue
			end
		end

		local baseOutput = self.calcContext.baseOutput
		local output = self.calcContext.calcFunc({ addNodes = { [node] = true } })
		local meanStatDiff = TradeQueryGeneratorClass.WeightedRatioOutputs(baseOutput, output, self.calcContext.options.statWeights) * 1000 - (self.calcContext.baseStatValue or 0)
		if meanStatDiff > 0.01 then
			t_insert(self.modWeights, { tradeModId = entry.tradeMod.id, weight = meanStatDiff, meanStatDiff = meanStatDiff, invert = false })
		end
		self.alreadyWeightedMods[entry.tradeMod.id] = true

		local now = GetTime()
		if now - start > 50 then
			-- Would be nice to update x/y progress on the popup here, but getting y ahead of time has a cost, and the visual seems to update on a significant delay anyways so it's not very useful
			coroutine.yield()
			start = now
		end
		::continue::
	end
end

function TradeQueryGeneratorClass:OnFrame()
	if self.calcContext.co == nil then
		return
	end

	local res, errMsg = coroutine.resume(self.calcContext.co, self)
	if launch.devMode and not res then
		error(errMsg)
	end
	if coroutine.status(self.calcContext.co) == "dead" then
		self.calcContext.co = nil
		self:FinishQuery()
	end
end

local currencyTable = {
	{ name = "Exalted Orb Equivalent", id = nil },
	{ name = "Exalted Orb", id = "exalted" },
	{ name = "Chaos Orb", id = "chaos" },
	{ name = "Divine Orb", id = "divine" },
	{ name = "Orb of Augmentation", id = "aug" },
	{ name = "Orb of Transmutation", id = "transmute" },
	{ name = "Regal Orb", id = "regal" },
	{ name = "Vaal Orb", id = "vaal" },
	{ name = "Orb of Annulment", id = "annul" },
	{ name = "Orb of Alchemy", id = "alch" },
	{ name = "Mirror of Kalandra", id = "mirror" }
}

function TradeQueryGeneratorClass:StartQuery(slot, options)
	if self.lastMaxPrice then
		options.maxPrice = self.lastMaxPrice
	end
	if self.lastMaxPriceTypeIndex then
		options.maxPriceType = currencyTable[self.lastMaxPriceTypeIndex].id
	end
	if self.lastMaxLevel then
		options.maxLevel = self.lastMaxLevel
	end

	-- Figure out what type of item we're searching for
	local existingItem = slot and self.itemsTab.items[slot.selItemId]
	local testItemType = existingItem and existingItem.baseName or "Diamond"
	local itemCategoryQueryStr
	local itemCategory
	local special = { }
	if options.special then
		if options.special.itemName == "Megalomaniac" then
			special = {
				queryFilters = {},
				queryExtra = {
					name = "Megalomaniac",
					type = "Diamond"
				},
				calcNodesInsteadOfMods = true,
			}
		end
		if options.special.itemName == "Heart of the Well" then
			special = {
				queryFilters = {},
				queryExtra = {
					name = options.special.itemName,
					type = "Diamond"
				},
				HeartOfTheWell = true
			}
			itemCategory = "AnyJewel"
			itemCategoryQueryStr = "jewel"
		end
		if options.special.itemName == "Against the Darkness" then
			special = {
				queryFilters = {},
				queryExtra = {
					name = options.special.itemName,
					type = "Time-Lost Diamond"
				},
				AgainstTheDarkness = true
			}
			itemCategory = "AnyJewel"
			itemCategoryQueryStr = "jewel"
		end
	else
		itemCategoryQueryStr, itemCategory = tradeHelpers.getTradeCategory(slot.slotName, existingItem)
		if not itemCategory then
			logToFile("'%s' is not supported for weighted trade query generation", existingItem and existingItem.type or "n/a")
			return
		end
		if itemCategory == "Jewel" then
			itemCategory = options.jewelType .. "Jewel"
		end
	end

	-- Create a temp item for the slot with no mods
	local itemRawStr = "Rarity: RARE\nStat Tester\n" .. testItemType
	if options.jewelType == "Radius" or (options.special and options.special.itemName) then
		itemRawStr = [[Rarity: RARE
Stat Tester
Time-Lost Sapphire
Radius: Small
Implicits: 0]]
	end
	local testItem = new("Item", itemRawStr)

	-- Calculate base output with a blank item
	local calcFunc, baseOutput = self.itemsTab.build.calcsTab:GetMiscCalculator()
	local baseItemOutput = slot and calcFunc({ repSlotName = slot.slotName, repItem = testItem }) or baseOutput
	-- make weights more human readable
	local compStatValue = TradeQueryGeneratorClass.WeightedRatioOutputs(baseOutput, baseItemOutput, options.statWeights) * 1000

	-- Test each mod one at a time and cache the normalized Stat (configured earlier) diff to use as weight
	self.modWeights = { }
	self.alreadyWeightedMods = { }

	self.calcContext = {
		itemCategoryQueryStr = itemCategoryQueryStr,
		itemCategory = itemCategory,
		special = special,
		testItem = testItem,
		baseOutput = baseOutput,
		baseStatValue = compStatValue,
		calcFunc = calcFunc,
		options = options,
		slot = slot,
	}

	-- OnFrame will pick this up and begin the work
	self.calcContext.co = coroutine.create(self.ExecuteQuery)

	-- Open progress tracking blocker popup
	local controls = { }
	controls.progressText = new("LabelControl", {"TOP",nil,"TOP"}, {0, 30, 0, 16}, string.format("Calculating Mod Weights..."))
	self.calcContext.popup = main:OpenPopup(280, 65, "Please Wait", controls)
end

function TradeQueryGeneratorClass:ExecuteQuery()
	if self.calcContext.special.calcNodesInsteadOfMods then
		self:GeneratePassiveNodeWeights(self.modData.AllocatesXEnchant)
		return
	end
	if self.calcContext.special.HeartOfTheWell then
		self:GenerateModWeights(self.modData.HeartOfTheWell)
		if self.calcContext.options.includeCorrupted then
			self:GenerateModWeights(self.modData["Corrupted"])
		end
		return
	end
	if self.calcContext.special.AgainstTheDarkness then
		self:GenerateModWeights(self.modData.AgainstTheDarkness)
		if self.calcContext.options.includeCorrupted then
			self:GenerateModWeights(self.modData["Corrupted"])
		end
		return
	end

	-- the trade site has no filters for jewel categories, so we can remove the
	-- other mods to filter the category. this should also free up some filter slots.
	if self.calcContext.options.jewelType == "Radius" then
		local radiusMods = {}
		-- local baseMods = {}
		for k, v in pairs(self.modData["Explicit"]) do
			if v.RadiusJewel then
				radiusMods[k] = v
			end
		end

		self:GenerateModWeights(radiusMods)
	else
	-- radius mods are not filtered out here, but they are valued at zero and
	-- ignored as the base item won't have a "radius:" line
		self:GenerateModWeights(self.modData["Explicit"])
	end

	self:GenerateModWeights(self.modData["Implicit"])
	if self.calcContext.options.includeCorrupted then
		self:GenerateModWeights(self.modData["Corrupted"])
	end
	if self.calcContext.options.includeRunes then
		self:GenerateModWeights(self.modData["Rune"])
	end
end

function TradeQueryGeneratorClass:FinishQuery()
	-- Calc original item Stats without anoint or enchant, and use that diff as a basis for default min sum.
	local originalItem = self.calcContext.slot and self.itemsTab.items[self.calcContext.slot.selItemId]
	self.calcContext.testItem.explicitModLines = { }
	if originalItem then
		for _, modLine in ipairs(originalItem.explicitModLines) do
			t_insert(self.calcContext.testItem.explicitModLines, modLine)
		end
		for _, modLine in ipairs(originalItem.implicitModLines) do
			t_insert(self.calcContext.testItem.explicitModLines, modLine)
		end
	end
	self.calcContext.testItem:BuildAndParseRaw()

	local originalOutput = originalItem and self.calcContext.calcFunc({ repSlotName = self.calcContext.slot.slotName, repItem = self.calcContext.testItem }) or self.calcContext.baseOutput
	local currentStatDiff = TradeQueryGeneratorClass.WeightedRatioOutputs(self.calcContext.baseOutput, originalOutput, self.calcContext.options.statWeights) * 1000 - (self.calcContext.baseStatValue or 0)

	-- Sort by mean Stat diff rather than weight to more accurately prioritize stats that can contribute more
	table.sort(self.modWeights, function (a, b)
		if a.meanStatDiff == b.meanStatDiff then
			return math.abs(a.weight) > math.abs(b.weight)
		end
		return a.meanStatDiff > b.meanStatDiff
	end)

	-- A megalomaniac is not being compared to anything and the currentStatDiff will be 0, so just go for an arbitrary min weight - in this case triple the weight of the worst evaluated node.
	local megalomaniacSpecialMinWeight = self.calcContext.special.itemName == "Megalomaniac" and self.modWeights[#self.modWeights] * 3
	-- This Stat diff value will generally be higher than the weighted sum of the same item, because the stats are all applied at once and can thus multiply off each other.
	-- So apply a modifier to get a reasonable min and hopefully approximate that the query will start out with small upgrades.
	local minWeight = megalomaniacSpecialMinWeight or currentStatDiff * 0.5

	-- what the trade site API uses for instant buyout etc.
	self.tradeTypes = {
		"securable",
		"available",
		"onlineleague",
		"online",
		"any",
	}
	local selectedTradeType = self.tradeTypes[self.tradeTypeIndex]
	-- Generate trade query str and open in browser
	local filters = 0
	local queryTable = {
		query = {
			filters = self.calcContext.special.queryFilters or {
				type_filters = {
					filters = {
						category = { option = self.calcContext.itemCategoryQueryStr },
						rarity = { option = "nonunique" }
					}
				}
			},
			status = { option = selectedTradeType },
			stats = {
				{
					type = "weight",
					value = { min = minWeight },
					filters = { }
				}
			}
		},
		sort = { ["statgroup.0"] = "desc" },
		engine = "new"
	}

	local options = self.calcContext.options

	local num_extra = 2
	if not options.includeMirrored then
		num_extra = num_extra + 1
	end
	if options.maxPrice and options.maxPrice > 0 then
		num_extra = num_extra + 1
	end
	if options.account then
		queryTable.query.filters.trade_filters.filters.account = {input = options.account}
	end

	if options.maxLevel and options.maxLevel > 0 then
		num_extra = num_extra + 1
	end
	if options.sockets and options.sockets > 0 then
		num_extra = num_extra + 1
	end

	local effective_max = MAX_FILTERS - num_extra

	local prioritizedMods = {}
	for _, entry in ipairs(self.modWeights) do
		if #prioritizedMods < effective_max then
			table.insert(prioritizedMods, entry)
		else
			break
		end
	end

	self.modWeights = prioritizedMods

	for k, v in pairs(self.calcContext.special.queryExtra or {}) do
		queryTable.query[k] = v
	end

	for _, entry in ipairs(self.modWeights) do
		t_insert(queryTable.query.stats[1].filters, { id = entry.tradeModId, value = { weight = (entry.invert == true and entry.weight * -1 or entry.weight) } })
		filters = filters + 1
		if filters == effective_max then
			break
		end
	end
	if not options.includeMirrored then
		queryTable.query.filters.misc_filters = {
			disabled = false,
			filters = {
				mirrored = false,
			}
		}
	end

	if options.maxPrice and options.maxPrice > 0 then
		queryTable.query.filters.trade_filters = {
			filters = {
				price = {
					option = options.maxPriceType,
					max = options.maxPrice
				}
			}
		}
	end

	if options.maxLevel and options.maxLevel > 0 then
		queryTable.query.filters.req_filters = {
			disabled = false,
			filters = {
				lvl = {
					max = options.maxLevel
				}
			}
		}
	end

	if options.sockets and options.sockets > 0 then
		queryTable.query.filters.equipment_filters = {
			disabled = false,
			filters = {
				rune_sockets = {
					min = options.sockets
				}
			}
		}
	end

	local errMsg = nil
	if #queryTable.query.stats[1].filters == 0 then
		-- No mods to filter
		errMsg = "Could not generate search, found no mods to search for"
	end

	local queryJson = dkjson.encode(queryTable)
	self.requesterCallback(self.requesterContext, queryJson, errMsg)

	-- Close blocker popup
	main:ClosePopup()
end

function TradeQueryGeneratorClass:RequestQuery(slot, context, statWeights, callback)
	self.requesterCallback = callback
	self.requesterContext = context

	local controls = { }
	local options = { }
	local popupHeight = 110

	local isJewelSlot = slot and slot.slotName:find("Jewel") ~= nil

	local lastItemAnchor
	local function updateLastAnchor(anchor, height)
		lastItemAnchor = anchor
		popupHeight = popupHeight + (height or 23)
	end

	controls.includeCorrupted = new("CheckBoxControl", {"TOP",nil,"TOP"}, {-40, 30, 18}, "Corrupted Mods:", function(state) end, "Includes corruption implicit modifiers in the weighted sum.\nNote that there is a maximum search filter count which means this might cause other weights to not be included.")
	controls.includeCorrupted.state = not context.slotTbl.alreadyCorrupted and (self.lastIncludeCorrupted == nil or self.lastIncludeCorrupted == true)
	controls.includeCorrupted.enabled = not context.slotTbl.alreadyCorrupted
	updateLastAnchor(controls.includeCorrupted)




	controls.includeMirrored = new("CheckBoxControl", {"TOPRIGHT",lastItemAnchor,"BOTTOMRIGHT"}, {0, 5, 18}, "Mirrored Items:", function(state) end)
	controls.includeMirrored.state = (self.lastIncludeMirrored == nil or self.lastIncludeMirrored == true)
	updateLastAnchor(controls.includeMirrored)

	-- there are also some exceptions like the darkness enthroned belt, but runes on these are not yet working pob
	local isAugmentableSlot = slot and (slot.slotName:find("Weapon 1") or slot.slotName:find("Weapon 2") or slot.slotName:find("Helmet") or slot.slotName:find("Body Armour") or slot.slotName:find("Gloves") or slot.slotName:find("Boots"))
	if isAugmentableSlot then
		local augmentTooltip = [[Controls how augments are used in the search.

Copy Current: augments in weights are skipped and augments are replaced with the current augments when possible.
Usually the best opinion as this ensures the augments makes sense for your build.

Keep: augments will be included in weights and will not be changed on items.
Best used when you value an augment greatly, and cannot add it yourself.

Remove: augments are completely ignored, and removed from items.]]
		controls.augmentBehaviour = new("DropDownControl", {"TOPLEFT", lastItemAnchor, "BOTTOMLEFT"}, {0, 5, 110, 18}, {"Copy Current", "Keep", "Remove"}, function(state) end, augmentTooltip)
		controls.augmentBehaviour:SetSel(self.lastAugmentBehaviourIdx or 1)
		controls.augmentBehaviourLabel = new("LabelControl", { "RIGHT", controls.augmentBehaviour, "LEFT" },
			{ -4, 0, 80, 16 }, "Rune Behaviour:")
		updateLastAnchor(controls.augmentBehaviour)
	end

	local isAmulet = slot and (slot.slotName:find("Amulet"))
	if isAmulet then
		local augmentTooltip = [[Controls how anoints are used in the search.

Copy Current: anoints are replaced with the current anoint when possible.
Usually the best opinion as this ensures the anoint makes sense for your build.

Keep: anoints will not be changed on items.
Best used when you cannot add one yourself. Note that weights cannot be generated for anoints.

Remove: anoints are completely ignored, and removed from items.]]
		controls.anointBehaviour = new("DropDownControl", {"TOPLEFT", lastItemAnchor, "BOTTOMLEFT"}, {0, 5, 110, 18}, {"Copy Current", "Keep", "Remove"}, function(state) end, augmentTooltip)
		controls.anointBehaviour:SetSel(self.lastAnointBehaviourIdx or 1)
		controls.anointBehaviourLabel = new("LabelControl", { "RIGHT", controls.anointBehaviour, "LEFT" },
			{ -4, 0, 80, 16 }, "Anoint Behaviour:")
		updateLastAnchor(controls.anointBehaviour)
	end

	if context.slotTbl.unique then
		options.special = { itemName = context.slotTbl.slotName }
	end

	if context.slotTbl.slotName == "Megalomaniac" or context.slotTbl.slotName == "Heart of the Well" or context.slotTbl.slotName == "Against the Darkness" then
		local activeSocketList = { }
		for nodeId, jewelSlot in pairs(self.itemsTab.sockets) do
			if not jewelSlot.inactive and not self.itemsTab.build.spec.nodes[nodeId].containJewelSocket then
				t_insert(activeSocketList, jewelSlot)
			end
		end
		table.sort(activeSocketList, function(a, b)
			return a.label < b.label
		end)
		controls.jewelSlot = new("DropDownControl", {"TOPLEFT", lastItemAnchor, "BOTTOMLEFT"}, {0, 5, 100, 18}, activeSocketList, function(idx, value) end)
		controls.jewelSlotLabel = new("LabelControl", {"RIGHT",controls.jewelSlot,"LEFT"}, {-5, 0, 0, 16}, "Jewel Slot:")
		for index, jewelSlot in ipairs(activeSocketList) do
			if jewelSlot.nodeId == context.slotTbl.selectedJewelNodeId then
				controls.jewelSlot.selIndex = index
				break
			end
		end
		updateLastAnchor(controls.jewelSlot)
	end


	if isJewelSlot and not context.slotTbl.unique then
		controls.jewelType = new("DropDownControl", {"TOPLEFT",lastItemAnchor,"BOTTOMLEFT"}, {0, 5, 100, 18}, { "Base", "Radius" }, function(index, value) end)
		controls.jewelType.selIndex = self.lastJewelType or 1
		controls.jewelTypeLabel = new("LabelControl", {"RIGHT",controls.jewelType,"LEFT"}, {-5, 0, 0, 16}, "Jewel Type:")
		updateLastAnchor(controls.jewelType)
	end

	-- Add max price limit selection dropbox
	local currencyDropdownNames = { }
	for _, currency in ipairs(currencyTable) do
		t_insert(currencyDropdownNames, currency.name)
	end
	controls.maxPrice = new("EditControl", {"TOPLEFT",lastItemAnchor,"BOTTOMLEFT"}, {0, 5, 70, 18}, nil, nil, "%D")
	controls.maxPrice.buf = self.lastMaxPrice and tostring(self.lastMaxPrice) or ""
	controls.maxPriceType = new("DropDownControl", {"LEFT",controls.maxPrice,"RIGHT"}, {5, 0, 150, 18}, currencyDropdownNames, nil, "The trade site will filter out listings with other currencies,\nif anything other than \"Exalted Orb Equivalent\" is chosen and a maximum is specified.")
	controls.maxPriceType.selIndex = self.lastMaxPriceTypeIndex or 1
	controls.maxPriceLabel = new("LabelControl", {"RIGHT",controls.maxPrice,"LEFT"}, {-5, 0, 0, 16}, "^7Max Price:")
	updateLastAnchor(controls.maxPrice)

	controls.maxLevel = new("EditControl", {"TOPLEFT",lastItemAnchor,"BOTTOMLEFT"}, {0, 5, 100, 18}, nil, nil, "%D")
	controls.maxLevel.buf = self.lastMaxLevel and tostring(self.lastMaxLevel) or ""
	controls.maxLevelLabel = new("LabelControl", {"RIGHT",controls.maxLevel,"LEFT"}, {-5, 0, 0, 16}, "Max Level:")
	updateLastAnchor(controls.maxLevel)

	-- basic filtering by slot for sockets Megalomaniac does not have slot and Sockets use "Jewel nodeId"
	if slot and not isJewelSlot and not slot.slotName:find("Flask") and not slot.slotName:find("Belt") and not slot.slotName:find("Ring") and not slot.slotName:find("Amulet") and not slot.slotName:find("Charm") then
		controls.sockets = new("EditControl", {"TOPLEFT",lastItemAnchor,"BOTTOMLEFT"}, {0, 5, 70, 18}, nil, nil, "%D")
		controls.sockets.buf = self.lastSockets and tostring(self.lastSockets) or ""
		controls.socketsLabel = new("LabelControl", {"RIGHT",controls.sockets,"LEFT"}, {-5, 0, 0, 16}, "^7# of Empty Sockets:")
		updateLastAnchor(controls.sockets)
	end

	for i, stat in ipairs(statWeights) do
		controls["sortStatType"..tostring(i)] = new("LabelControl", {"TOPLEFT",lastItemAnchor,"BOTTOMLEFT"}, {0, i == 1 and 5 or 3, 70, 16}, i < (#statWeights < 6 and 10 or 5) and s_format("^7%.2f: %s", stat.weightMult, stat.label) or ("+ "..tostring(#statWeights - 4).." Additional Stats"))
		lastItemAnchor = controls["sortStatType"..tostring(i)]
		popupHeight = popupHeight + 19
		if i == 1 then
			controls.sortStatLabel = new("LabelControl", {"RIGHT",lastItemAnchor,"LEFT"}, {-5, 0, 0, 16}, "^7Stat to Sort By:")
		elseif i == 5 then
			-- tooltips do not actually work for labels
			lastItemAnchor.tooltipFunc = function(tooltip)
				tooltip:Clear()
				tooltip:AddLine(16, "Sorts the weights by the stats selected multiplied by a value")
				tooltip:AddLine(16, "Currently sorting by:")
				for i, stat in ipairs(statWeights) do
					if i > 4 then
						tooltip:AddLine(16, s_format("%s: %.2f", stat.label, stat.weightMult))
					end
				end
			end
			break
		end
	end
	popupHeight = popupHeight + 4

	controls.generateQuery = new("ButtonControl", { "BOTTOM", nil, "BOTTOM" }, {-45, -10, 80, 20}, "Execute", function()
		local selectedJewelSlot = controls.jewelSlot and controls.jewelSlot:GetSelValue()
		if controls.jewelSlot and not selectedJewelSlot then
			return
		end
		main:ClosePopup()

		self.tradeTypeIndex = context.controls.tradeTypeSelection.selIndex

		if controls.includeMirrored then
			self.lastIncludeMirrored, options.includeMirrored = controls.includeMirrored.state, controls.includeMirrored.state
		end
		if controls.includeCorrupted then
			self.lastIncludeCorrupted, options.includeCorrupted = controls.includeCorrupted.state, controls.includeCorrupted.state
		end
		if controls.augmentBehaviour then
			-- remember setting
			self.lastAugmentBehaviourIdx = controls.augmentBehaviour.selIndex
			-- used by TradeQuery to change augments accordingly
			self.lastAugmentBehaviour = controls.augmentBehaviour:GetSelValue()
			-- whether weights should be generated
			options.includeRunes = controls.augmentBehaviour:GetSelValue() == "Keep"
		end
		if controls.anointBehaviour then
			-- remember setting
			self.lastAnointBehaviourIdx = controls.anointBehaviour.selIndex
			-- used by TradeQuery to change anoints accordingly
			self.lastAnointBehaviour = controls.anointBehaviour:GetSelValue()
		end
		if controls.jewelType then
			self.lastJewelType = controls.jewelType.selIndex
			options.jewelType = controls.jewelType:GetSelValue()
		end
		if controls.jewelSlot then
			slot = selectedJewelSlot
			context.slotTbl.selectedJewelNodeId = slot.nodeId
		end
		if controls.maxPrice.buf then
			options.maxPrice = tonumber(controls.maxPrice.buf)
			self.lastMaxPrice = options.maxPrice
			options.maxPriceType = currencyTable[controls.maxPriceType.selIndex].id
			self.lastMaxPriceTypeIndex = controls.maxPriceType.selIndex
		end
		if controls.maxLevel.buf then
			options.maxLevel = tonumber(controls.maxLevel.buf)
			self.lastMaxLevel = options.maxLevel
		end
		if controls.sockets and controls.sockets.buf then
			options.sockets = tonumber(controls.sockets.buf)
			self.lastSockets = options.sockets
		end
		options.statWeights = statWeights

		self:StartQuery(slot, options)
	end)
	controls.generateQuery.enabled = function()
		return not controls.jewelSlot or controls.jewelSlot:GetSelValue() ~= nil
	end
	controls.generateQuery.tooltipText = controls.jewelSlot and "Requires an active Jewel Socket." or nil
	controls.cancel = new("ButtonControl", { "BOTTOM", nil, "BOTTOM" }, {45, -10, 80, 20}, "Cancel", function()
		main:ClosePopup()
	end)
	main:OpenPopup(400, popupHeight, "Query Options", controls)
end