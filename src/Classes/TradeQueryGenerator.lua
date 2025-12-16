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
	["1HWeapon"] = { "One Handed Mace", "Wand", "Sceptre", "Flail", "Spear" },
	["2HWeapon"] = { "Staff", "Staff: Warstaff", "Two Handed Mace", "Crossbow", "Bow", "Talisman" },
	-- ["1HAxe"] = { "One Handed Axe" },
	-- ["1HSword"] = { "One Handed Sword", "Thrusting One Handed Sword" },
	["1HMace"] = { "One Handed Mace" },
	["Sceptre"] = { "Sceptre" },
	-- ["Dagger"] = { "Dagger" },
	["Wand"] = { "Wand" },
	-- ["Claw"] = { "Claw" },
	["Talisman"] = { "Talisman" },
	["Staff"] = { "Staff" },
	["Quarterstaff"] = { "Staff: Warstaff" },
	["Bow"] = { "Bow" },
	["Crossbow"] = { "Crossbow"},
	-- ["2HAxe"] = { "Two Handed Axe" },
	-- ["2HSword"] = { "Two Handed Sword" },
	["2HMace"] = { "Two Handed Mace" },
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

local tradeStatCategoryIndices = {
	["Explicit"] = 2,
	["Implicit"] = 3,
	["Corrupted"] = 4,
	["AllocatesXEnchant"] = 5,
	["Rune"] = 6,
}

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

local function fetchStats()
	local tradeStats = ""
	local easy = common.curl.easy()
	easy:setopt_url("https://www.pathofexile.com/api/trade2/data/stats")
	easy:setopt_useragent("Path of Building/" .. launch.versionNumber)
	easy:setopt_writefunction(function(data)
		tradeStats = tradeStats..data
		return true
	end)
	easy:perform()
	easy:close()
	return tradeStats
end

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
			baseModSum = baseModSum + (baseOutput[mod] or 0)
			newModSum = newModSum + (newOutput[mod] or 0)
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
		if statTable.stat == "FullDPS" and not (baseOutput["FullDPS"] and newOutput["FullDPS"]) then
			meanStatDiff = meanStatDiff + ratioModSums("TotalDPS", "TotalDotDPS", "CombinedDPS") * statTable.weightMult
		end
		meanStatDiff = meanStatDiff + ratioModSums(statTable.stat) * statTable.weightMult
	end
	return meanStatDiff
end

function TradeQueryGeneratorClass:ProcessMod(mod, tradeQueryStatsParsed, itemCategoriesMask, itemCategoriesOverride)
	if mod.statOrder == nil then mod.statOrder = { } end
	if mod.group == nil then mod.group = "" end

	for index, modLine in ipairs(mod) do
		if modLine:find("Grants Level") or modLine:find("inflict Decay") then -- skip mods that grant skills / decay, as they will often be overwhelmingly powerful but don't actually fit into the build
			goto nextModLine
		end

		local modType = (mod.type == "Prefix" or mod.type == "Suffix") and "Explicit" or mod.type == "SpecialCorrupted" and "Corrupted" or mod.type

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

		-- If this is the first tier for this mod, find matching trade mod and init the entry
		if not self.modData[modType] then
			logToFile("Unhandled Mod Type: %s", modType)
			goto continue
		end

		-- iterate trade mod category to find mod with matching text.
		local function getTradeMod()
			-- try matching to global mods.
			local matchStr = modLine:gsub("[#()0-9%-%+%.]","")
			for _, entry in ipairs(tradeQueryStatsParsed.result[tradeStatCategoryIndices[modType]].entries) do
				if entry.text:gsub("[#()0-9%-%+%.]","") == matchStr then
					return entry
				end
			end
			-- check reverse
			matchStr = swapInverse(matchStr)
			for _, entry in ipairs(tradeQueryStatsParsed.result[tradeStatCategoryIndices[modType]].entries) do
				if entry.text:gsub("[#()0-9%-%+%.]","") == matchStr then
					return entry, true
				end
			end

			return nil
		end

		local tradeMod = nil
		local invert

		if mod.statOrder[index] == nil then -- if there isn't a mod order we have to use the trade id instead e.g. implicits.
			tradeMod, invert = getTradeMod()
			if tradeMod == nil then
				logToFile("Unable to match %s mod: %s", modType, modLine)
				goto nextModLine
			end
			mod.statOrder[index] = tradeMod.id
		end

		local statOrder = modLine:find("Nearby Enemies have %-") ~= nil and mod.statOrder[index + 1] or mod.statOrder[index] -- hack to get minus res mods associated with the correct statOrder
		local uniqueIndex = mod.group ~= "" and tostring(statOrder).."_"..mod.group or tostring(statOrder)

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
			logToFile("Unexpected # of tokens found for mod: %s", mod[index])
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

function TradeQueryGeneratorClass:GenerateModData(mods, tradeQueryStatsParsed, itemCategoriesMask, itemCategoriesOverride)
	for _, mod in pairsSortByKey(mods) do
		self:ProcessMod( mod, tradeQueryStatsParsed, itemCategoriesMask, itemCategoriesOverride)
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

	self.modData = {
		["Explicit"] = { },
		["Implicit"] = { },
		["Enchant"] = { },
		["AllocatesXEnchant"] = { },
		["Corrupted"] = { },
		["Rune"] = { },
	}

	-- originates from: https://www.pathofexile.com/api/trade2/data/stats
	local tradeStats = fetchStats()
	tradeStats:gsub("\n", " ")
	local tradeQueryStatsParsed = dkjson.decode(tradeStats)
	for _, modDomain in ipairs(tradeQueryStatsParsed.result) do
		for _, mod in ipairs(modDomain.entries) do
			mod.text = escapeGGGString(mod.text)
		end
	end

	-- create mask for regular mods
	local regularItemMask = { }
	for category, _ in pairs(tradeCategoryNames) do
		regularItemMask[category] = true
	end

	self:GenerateModData(data.itemMods.Item, tradeQueryStatsParsed, regularItemMask)
	self:GenerateModData(data.itemMods.Corruption, tradeQueryStatsParsed, regularItemMask)
	self:GenerateModData(data.itemMods.Jewel, tradeQueryStatsParsed, { ["BaseJewel"] = true, ["AnyJewel"] = true, ["RadiusJewel"] = true })
	self:GenerateModData(data.itemMods.Flask, tradeQueryStatsParsed, { ["LifeFlask"] = true, ["ManaFlask"] = true })
	self:GenerateModData(data.itemMods.Charm, tradeQueryStatsParsed, { ["Charm"] = true })

	for _, entry in ipairs(tradeQueryStatsParsed.result[tradeStatCategoryIndices.AllocatesXEnchant].entries) do
		if entry.text:sub(1, 10) == "Allocates " then
			-- The trade id for allocatesX enchants end with "|[nodeID]" for the allocated node.
			local nodeId = entry.id:sub(entry.id:find("|") + 1)
			self.modData.AllocatesXEnchant[nodeId] = { tradeMod = entry, specialCaseData = { } }
		end
	end

	-- implicit mods
	for baseName, entry in pairsSortByKey(data.itemBases) do
		if entry.implicit ~= nil then
			local mod = { type = "Implicit" }
			for modLine in string.gmatch(entry.implicit, "([^".."\n".."]+)") do
				t_insert(mod, modLine)
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
				self:ProcessMod(mod, tradeQueryStatsParsed, regularItemMask, maskOverride)
			end
		end
	end

	-- rune mods
	for name, runeMods in pairsSortByKey(data.itemMods.Runes) do
		for slotType, mods in pairs(runeMods) do
			if slotType == "weapon" then
				self:ProcessMod(mods, tradeQueryStatsParsed, regularItemMask, { ["1HWeapon"] = true, ["2HWeapon"] = true, ["1HMace"] = true, ["Claw"] = true, ["Quarterstaff"] = true, ["Bow"] = true, ["2HMace"] = true, ["Crossbow"] = true, ["Spear"] = true, ["Flail"] = true, ["Talisman"] = true  })
			elseif slotType == "armour" then
				self:ProcessMod(mods, tradeQueryStatsParsed, regularItemMask, { ["Shield"] = true, ["Chest"] = true, ["Helmet"] = true, ["Gloves"] = true, ["Boots"] = true, ["Focus"] = true })
			elseif slotType == "caster" then
				self:ProcessMod(mods, tradeQueryStatsParsed, regularItemMask, { ["Wand"] = true, ["Staff"] = true })
			else
				-- Mod is slot specific, try to match against a value in tradeCategoryNames
				local matchedCategory = nil
				for category, categoryOptions in pairs(tradeCategoryNames) do
					for i, opt in pairs(categoryOptions) do
						if opt:lower():match(slotType) then
							matchedCategory = category
							break
						end
					end
					if matchedCategory then
						break
					end
				end
				if matchedCategory then
					self:ProcessMod(mods, tradeQueryStatsParsed, regularItemMask, { [matchedCategory] = true })
				else
					ConPrintf("TradeQuery: Unmatched category for modifier. Slot type: %s Modifier: %s", mods.slotType, mods.name)
				end
			end
		end		
	end

	local queryModsFile = io.open(queryModFilePath, 'w')
	queryModsFile:write("-- This file is automatically generated, do not edit!\n-- Stat data (c) Grinding Gear Games\n\n")
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
	{ name = "Relative", id = nil },
	{ name = "Exalted Orb", id = "exalted" },
	{ name = "Chaos Orb", id = "chaos" },
	{ name = "Divine Orb", id = "divine" },
	{ name = "Orb of Augmentation", id = "aug" },
	{ name = "Orb of Transmutation", id = "transmute" },
	{ name = "Regal Orb", id = "regal" },
	{ name = "Vaal Orb", id = "vaal" },
	{ name = "Annulment Orb", id = "annul" },
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
	elseif slot.slotName:find("^Weapon %d") then
		if existingItem then
			if existingItem.type == "Shield" then
				itemCategoryQueryStr = "armour.shield"
				itemCategory = "Shield"
			elseif existingItem.type == "Focus" then
				itemCategoryQueryStr = "armour.focus"
				itemCategory = "Focus"
			elseif existingItem.type == "Buckler" then
				itemCategoryQueryStr = "armour.buckler"
				itemCategory = "Buckler"
			elseif existingItem.type == "Quiver" then
				itemCategoryQueryStr = "armour.quiver"
				itemCategory = "Quiver"
			elseif existingItem.type == "Bow" then
				itemCategoryQueryStr = "weapon.bow"
				itemCategory = "Bow"
			elseif existingItem.type == "Crossbow" then
				itemCategoryQueryStr = "weapon.crossbow"
				itemCategory = "Crossbow"
			elseif existingItem.type == "Talisman" then
				itemCategoryQueryStr = "weapon.talisman"
				itemCategory = "Talisman"	
			elseif existingItem.type == "Staff" and existingItem.base.subType == "Warstaff" then
				itemCategoryQueryStr = "weapon.warstaff"
				itemCategory = "Quarterstaff"
			elseif existingItem.type == "Staff" then
				itemCategoryQueryStr = "weapon.staff"
				itemCategory = "Staff"
			elseif existingItem.type == "Two Handed Sword" then
				itemCategoryQueryStr = "weapon.twosword"
				itemCategory = "2HSword"
			elseif existingItem.type == "Two Handed Axe" then
				itemCategoryQueryStr = "weapon.twoaxe"
				itemCategory = "2HAxe"
			elseif existingItem.type == "Two Handed Mace" then
				itemCategoryQueryStr = "weapon.twomace"
				itemCategory = "2HMace"
			elseif existingItem.type == "Fishing Rod" then
				itemCategoryQueryStr = "weapon.rod"
				itemCategory = "FishingRod"
			elseif existingItem.type == "One Handed Sword" then
				itemCategoryQueryStr = "weapon.onesword"
				itemCategory = "1HSword"
			elseif existingItem.type == "Spear" then
				itemCategoryQueryStr = "weapon.spear"
				itemCategory = "Spear"
			elseif existingItem.type == "Flail" then
				itemCategoryQueryStr = "weapon.flail"
				itemCategory = "weapon.flail"
			elseif existingItem.type == "One Handed Axe" then
				itemCategoryQueryStr = "weapon.oneaxe"
				itemCategory = "1HAxe"
			elseif existingItem.type == "One Handed Mace" then
				itemCategoryQueryStr = "weapon.onemace"
				itemCategory = "1HMace"
			elseif existingItem.type == "Sceptre" then
				itemCategoryQueryStr = "weapon.sceptre"
				itemCategory = "Sceptre"
			elseif existingItem.type == "Wand" then
				itemCategoryQueryStr = "weapon.wand"
				itemCategory = "Wand"
			elseif existingItem.type == "Dagger" then
				itemCategoryQueryStr = "weapon.dagger"
				itemCategory = "Dagger"
			elseif existingItem.type == "Claw" then
				itemCategoryQueryStr = "weapon.claw"
				itemCategory = "Claw"
			elseif existingItem.type:find("Two Handed") ~= nil then
				itemCategoryQueryStr = "weapon.twomelee"
				itemCategory = "2HWeapon"
			elseif existingItem.type:find("One Handed") ~= nil then
				itemCategoryQueryStr = "weapon.one"
				itemCategory = "1HWeapon"
			else
				logToFile("'%s' is not supported for weighted trade query generation", existingItem.type)
				return
			end
		else
			-- Item does not exist in this slot so assume 1H weapon
			itemCategoryQueryStr = "weapon.one"
			itemCategory = "1HWeapon"
		end
	elseif slot.slotName == "Body Armour" then
		itemCategoryQueryStr = "armour.chest"
		itemCategory = "Chest"
	elseif slot.slotName == "Helmet" then
		itemCategoryQueryStr = "armour.helmet"
		itemCategory = "Helmet"
	elseif slot.slotName == "Gloves" then
		itemCategoryQueryStr = "armour.gloves"
		itemCategory = "Gloves"
	elseif slot.slotName == "Boots" then
		itemCategoryQueryStr = "armour.boots"
		itemCategory = "Boots"
	elseif slot.slotName == "Amulet" then
		itemCategoryQueryStr = "accessory.amulet"
		itemCategory = "Amulet"
	elseif slot.slotName == "Ring 1" or slot.slotName == "Ring 2" or slot.slotName == "Ring 3" then
		itemCategoryQueryStr = "accessory.ring"
		itemCategory = "Ring"
	elseif slot.slotName == "Belt" then
		itemCategoryQueryStr = "accessory.belt"
		itemCategory = "Belt"
	elseif slot.slotName:find("Time-Lost") ~= nil then
		itemCategoryQueryStr = "jewel"
		itemCategory = "RadiusJewel"
	elseif slot.slotName:find("Jewel") ~= nil then
		itemCategoryQueryStr = "jewel"
		itemCategory = options.jewelType .. "Jewel"
		-- not present on trade site
		-- if itemCategory == "RadiusJewel" then
		-- 	itemCategoryQueryStr = "jewel.radius"
		-- elseif itemCategory == "BaseJewel" then
		-- 	itemCategoryQueryStr = "jewel.base"
		-- end
	elseif slot.slotName:find("Flask 1") ~= nil then
		itemCategoryQueryStr = "flask.life"
		itemCategory = "Life Flask"
	elseif slot.slotName:find("Flask 2") ~= nil then
		itemCategoryQueryStr = "flask.mana"
		itemCategory = "Mana Flask"
	elseif slot.slotName:find("Charm") ~= nil then
		itemCategoryQueryStr = "flask" -- these don't have a unique string so overlapping mods of the same benefit could interfere. 
		itemCategory = "Charm"
	else
		logToFile("'%s' is not supported for weighted trade query generation", existingItem and existingItem.type or "n/a")
		return
	end

	-- Create a temp item for the slot with no mods
	local itemRawStr = "Rarity: RARE\nStat Tester\n" .. testItemType
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
	self:GenerateModWeights(self.modData["Explicit"])
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
	table.sort(self.modWeights, function(a, b)
		return a.meanStatDiff > b.meanStatDiff
	end)
	
	-- A megalomaniac is not being compared to anything and the currentStatDiff will be 0, so just go for an arbitrary min weight - in this case triple the weight of the worst evaluated node.
	local megalomaniacSpecialMinWeight = self.calcContext.special.itemName == "Megalomaniac" and self.modWeights[#self.modWeights] * 3
	-- This Stat diff value will generally be higher than the weighted sum of the same item, because the stats are all applied at once and can thus multiply off each other.
	-- So apply a modifier to get a reasonable min and hopefully approximate that the query will start out with small upgrades.
	local minWeight = megalomaniacSpecialMinWeight or currentStatDiff * 0.5
	
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
			status = { option = "available" },
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
	if options.maxLevel and options.maxLevel > 0 then
		num_extra = num_extra + 1
	end
	if options.sockets and options.sockets > 0 then
		num_extra = num_extra + 1
	end

	local effective_max = MAX_FILTERS - num_extra

	-- Prioritize top mods by abs(weight)
	table.sort(self.modWeights, function(a, b) return math.abs(a.weight) > math.abs(b.weight) end)

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

	controls.includeCorrupted = new("CheckBoxControl", {"TOP",nil,"TOP"}, {-40, 30, 18}, "Corrupted Mods:", function(state) end)
	controls.includeCorrupted.state = not context.slotTbl.alreadyCorrupted and (self.lastIncludeCorrupted == nil or self.lastIncludeCorrupted == true)
	controls.includeCorrupted.enabled = not context.slotTbl.alreadyCorrupted

	local canHaveRunes = slot and (slot.slotName:find("Weapon 1") or slot.slotName:find("Weapon 2") or slot.slotName:find("Helmet") or slot.slotName:find("Body Armour") or slot.slotName:find("Gloves") or slot.slotName:find("Boots"))
	controls.includeRunes = new("CheckBoxControl", {"TOPRIGHT",controls.includeCorrupted,"BOTTOMRIGHT"}, {0, 5, 18}, "Rune Mods:", function(state) end)
	controls.includeRunes.state = canHaveRunes and (self.lastIncludeRunes == nil or self.lastIncludeRunes == true)
	controls.includeRunes.enabled = canHaveRunes

	local lastItemAnchor = controls.includeRunes

	local function updateLastAnchor(anchor, height)
		lastItemAnchor = anchor
		popupHeight = popupHeight + (height or 23)
	end

	if context.slotTbl.unique then
		options.special = { itemName = context.slotTbl.slotName }
	end

	controls.includeMirrored = new("CheckBoxControl", {"TOPRIGHT",lastItemAnchor,"BOTTOMRIGHT"}, {0, 5, 18}, "Mirrored items:", function(state) end)
	controls.includeMirrored.state = (self.lastIncludeMirrored == nil or self.lastIncludeMirrored == true)
	updateLastAnchor(controls.includeMirrored)


	if isJewelSlot then
		controls.jewelType = new("DropDownControl", {"TOPLEFT",lastItemAnchor,"BOTTOMLEFT"}, {0, 5, 100, 18}, { "Any", "Base", "Radius" }, function(index, value) end) -- this does nothing atm
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
	controls.maxPriceType = new("DropDownControl", {"LEFT",controls.maxPrice,"RIGHT"}, {5, 0, 150, 18}, currencyDropdownNames, nil)
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
		controls.socketsLabel = new("LabelControl", {"RIGHT",controls.sockets,"LEFT"}, {-5, 0, 0, 16}, "# of Empty Sockets:")
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
		main:ClosePopup()

		if controls.includeMirrored then
			self.lastIncludeMirrored, options.includeMirrored = controls.includeMirrored.state, controls.includeMirrored.state
		end
		if controls.includeCorrupted then
			self.lastIncludeCorrupted, options.includeCorrupted = controls.includeCorrupted.state, controls.includeCorrupted.state
		end
		if controls.includeRunes  then
			self.lastIncludeRunes, options.includeRunes = controls.includeRunes.state, controls.includeRunes.state
		end
		if controls.jewelType then
			self.lastJewelType = controls.jewelType.selIndex
			options.jewelType = controls.jewelType.list[controls.jewelType.selIndex]
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
	controls.cancel = new("ButtonControl", { "BOTTOM", nil, "BOTTOM" }, {45, -10, 80, 20}, "Cancel", function()
		main:ClosePopup()
	end)
	main:OpenPopup(400, popupHeight, "Query Options", controls)
end