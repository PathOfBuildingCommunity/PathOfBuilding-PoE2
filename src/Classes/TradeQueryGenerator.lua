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
local utils = LoadModule("Modules/Utils")

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
---@return table[]? category list of entries for the mod type
local function getStatEntries(modType)
	local tradeStats = tradeHelpers.getTradeStats()
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

function TradeQueryGeneratorClass.WeightedRatioOutputs(baseOutput, newOutput, statWeights)
	local meanStatDiff = 0

	local function ratioModSums(...)
		local baseModSum = 0
		local newModSum = 0
		for _, mod in ipairs({ ... }) do
			baseModSum = baseModSum + data.powerStatList.GetFromOutput(baseOutput, mod, true)
			newModSum = newModSum + data.powerStatList.GetFromOutput(newOutput, mod, true)
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

-- processes mods from the data exports to a format that is more useful for generating weights.
-- this is done by measuring the range that each stat can roll within. in weight generation, a
-- midpoint is used to generate a description for the stat which can be applied to an item. the
-- canonical stat name (i.e. the stat which goes in the trade site search box) is also saved
function TradeQueryGeneratorClass:ProcessMod(mod, itemCategoriesMask, itemCategoriesOverride)
	for tradeHash, statData in pairs(mod.tradeHashes) do
		local modType = (mod.type == "Prefix" or mod.type == "Suffix") and "Explicit" or
			mod.type == "SpecialCorrupted" and "Corrupted" or mod.type

		if not modType then
			ConPrintf("Unable to match mod due to missing mod type: %s", mod[1])
			goto continue
		end

		local tradeIdCategory = tradeStatCategoryIndices[modType]
		local tradeId = tradeIdCategory .. ".stat_" .. tostring(tradeHash)

		if not self.modData[modType][tradeId] then
			for _, v in ipairs(getStatEntries(modType) or {}) do
				if tradeId == v.id then
					self.modData[modType][tradeId] = { canonicalStat = statData.canonicalStat, tradeMod = v }
					-- rare radius jewel stat descriptors don't have the prefix text
					if mod.nodeType == 1 then
						self.modData[modType][tradeId].textPrefix = "Small Passive Skills in Radius also grant "
					end
					if mod.nodeType == 2 then
						self.modData[modType][tradeId].textPrefix = "Notable Passive Skills in Radius also grant "
					end
					goto finish
				end
			end
			::finish::
			if not self.modData[modType][tradeId] then
				logToFile("%s mod does not exist in trade site data: %s", modType, mod[1])
				goto nextModLine
			end
		end

		local testStatValues = {}
		for stat, vals in pairs(statData.statValues) do
			local val = (vals.min + vals.max) * 0.5
			if val == 0 and vals.min ~= 0 then
				self.modData[modType][tradeId].zeroes = true
			end
			testStatValues[stat] = val
		end
		local modLine = data.describeStats(testStatValues, "stat_descriptions.lua")
		-- some stats are invisible. for example +0 suffix allowed
		if not modLine[1] then
			goto nextModLine
		end
		-- also skip unsupported mods
		local _, extra = modLib.parseMod(modLine[1])
		if extra then
			goto nextModLine
		end


		-- Update the min and max values available for each item category
		local modEntry = self.modData[modType][tradeId]
		for category, _ in pairs(itemCategoriesOverride or itemCategoriesMask or tradeCategoryNames) do
			if itemCategoriesOverride or canModSpawnForItemCategory(mod, category) then
				if not modEntry[category] then
					modEntry[category] = copyTable(statData.statValues)
				else
					for k, range in pairs(statData.statValues) do
					local existing = modEntry[category]
						existing[k].min = math.min(range.min, existing[k].min)
						existing[k].max = math.max(range.max, existing[k].max)
					end
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

	for catIdx, _ in ipairs(body.result) do
		table.sort(body.result[catIdx].entries, function(a, b)
			if a.text == b.text then
				return a.id < b.id
			end
			return a.text < b.text
		end)
	end

	local description = "This file contains the trade site data from https://www.pathofexile.com/api/trade2/data/stats"
	utils.saveTableToFile("./Data/TradeSiteStats.lua", body.result, description)

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
			self.modData.AllocatesXEnchant[nodeId] = { tradeMod = entry }
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
		if #entry.implicitIds > 0 and entry.type ~= "Transcendent Limb" then
			for _, modId in ipairs(entry.implicitIds) do
				if data.itemMods.Exclusive[modId] then
					local mod = copyTable(data.itemMods.Exclusive[modId])
					mod.type = "Implicit"
					-- create trade type mask for base type
					local maskOverride = {}
					for tradeName, typeNames in pairs(tradeCategoryNames) do
						for _, typeName in ipairs(typeNames) do
							local entryName = entry.type
							if entry.subType then
								entryName = entryName .. ": " .. entry.subType
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
				else
					ConPrintf("unknown implicit mod id: %s on base %s", modId, baseName)
				end
			end
		end
	end

	-- rune mods
	for name, runeMods in pairsSortByKey(data.itemMods.Runes) do
		for slotType, mod in pairs(runeMods) do
			local mod = { tradeHashes = mod.tradeHashes, type = "Rune" }
			if slotType == "weapon" then
				self:ProcessMod(mod, regularItemMask,
					{
						["1HWeapon"] = true,
						["2HWeapon"] = true,
						["1HMace"] = true,
						["Claw"] = true,
						["Quarterstaff"] = true,
						["Bow"] = true,
						["2HMace"] = true,
						["Crossbow"] = true,
						["Spear"] = true,
						["Flail"] = true,
						["Talisman"] = true
					})
			elseif slotType == "armour" then
				self:ProcessMod(mod, regularItemMask,
					{
						["Shield"] = true,
						["Chest"] = true,
						["Helmet"] = true,
						["Gloves"] = true,
						["Boots"] = true,
						["Focus"] = true
					})
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
					ConPrintf("TradeQuery: Unmatched category for modifier. Slot type: %s Modifier: %s Mod line: %s",
						slotType, name, mod[1])
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

	local qmDescription = [[This file contains categories of stats, mapped from trade hash to details
relevant for generating search weights Note that the trade site requires a
prefix of e.g. explicit.stat_{hash}. See
TradeSiteStats.lua for a list of all trade
site stats.]]
	utils.saveTableToFile(queryModFilePath, self.modData, qmDescription)
end

function TradeQueryGeneratorClass:GenerateModWeights(modsToTest)
	local start = GetTime()
	for tradeId, entry in pairs(modsToTest) do
		local categoryStats = entry[self.calcContext.itemCategory]
		if categoryStats then
			-- midpoint (or what the user configured via affix quality setting) of the measured
			-- rolls for each stat
			local halfWayStats = {}
			for stat, vals in pairs(categoryStats) do
				local point = main.defaultItemAffixQuality or 0.5
				halfWayStats[stat] = math.floor(vals.min * (1 - point) + vals.max * (point))
			end


			-- describeStats returns a table as it can produce multiple lines at once, but none of
			-- these should have multiple lines as they are exported separately. transformedStats
			-- will contain the values that actually go on the mod line. for example crit chance is
			-- divided by 100
			local modLine, _, transformedStats = data.describeStats(halfWayStats, "stat_descriptions.lua")

			-- value of the stat the trade site uses
			local tradeStatValue
			-- # to # mod
			local maxStat = entry.canonicalStat:gsub("minimum", "maximum")
			if entry.canonicalStat:match("minimum") and transformedStats[maxStat] then
				tradeStatValue = (transformedStats[maxStat].min + transformedStats[entry.canonicalStat].min) / 2
			else
				tradeStatValue = transformedStats[entry.canonicalStat].min
			end

			if not (modLine[1] and tradeStatValue) then
				logToFile("Failed to describe mod: %s for category %", tradeId, self.calcContext.itemCategory)
				goto continue
			end

			-- rare radius jewel prefix
			if entry.textPrefix then
				modLine[1] = entry.textPrefix .. modLine[1]
			end

			self.calcContext.testItem.explicitModLines[1] = { line = modLine[1], custom = true }
			self.calcContext.testItem:BuildAndParseRaw()

			if (self.calcContext.testItem.modList ~= nil and #self.calcContext.testItem.modList == 0) or (self.calcContext.testItem.slotModList ~= nil and #self.calcContext.testItem.slotModList[1] == 0 and #self.calcContext.testItem.slotModList[2] == 0) then
				logToFile("Failed to test %s mod: %s", self.calcContext.itemCategory, modLine)
			end

			local output = self.calcContext.calcFunc({ repSlotName = self.calcContext.slot.slotName, repItem = self.calcContext.testItem })
			local meanStatDiff = TradeQueryGeneratorClass.WeightedRatioOutputs(self.calcContext.baseOutput, output, self.calcContext.options.statWeights) * 1000 - (self.calcContext.baseStatValue or 0)
			if meanStatDiff > 0.01 then
				t_insert(self.modWeights,
					{
						tradeModId = tradeId,
						weight = meanStatDiff / tradeStatValue,
						meanStatDiff = meanStatDiff,
						line =
							modLine[1]
					})
			end

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
		requiredMods = options.requiredMods,
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
	-- debug: uncomment to print generated weights to a file
	-- table.sort(self.modWeights, function(a, b)
	-- 	return a.weight < b.weight
	-- end)
	-- local f = io.open("genWeights.txt", "w+")
	-- for _, res in ipairs(self.modWeights) do
	-- 	f:write(string.format("%s: %s\n", res.line, res.weight))
	-- end
	-- f:close()
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
	local requiredMods = self.calcContext.requiredMods or {}
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
				},
				requiredMods and {
					type = "and",
					filters = {}
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
	num_extra = num_extra + #requiredMods

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
	for _, entry in ipairs(requiredMods) do
		local filters = queryTable.query.stats[2].filters
		t_insert(filters, { id = entry.tradeId, value = { min = entry.value } })
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
	local popupHeight = 80
	local popupWidth = 400

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
	-- forward declarations for functions interacting with mod filter selectors
	---@type fun(): table
	local getModList
	---@type fun(controls: any, modList: any)
	local setModSelectors
	-- jewel type selector
	if isJewelSlot and not context.slotTbl.unique then
		controls.jewelType = new("DropDownControl", { "TOPLEFT", lastItemAnchor, "BOTTOMLEFT" }, { 0, 5, 100, 18 }, { "Base", "Radius" }, function(index, value)
			-- update mod list for selectors
			local mods = getModList()
			setModSelectors(controls, mods)
		end)
		controls.jewelType.selIndex = self.lastJewelType or 1
		controls.jewelTypeLabel = new("LabelControl", { "RIGHT", controls.jewelType, "LEFT" }, { -5, 0, 0, 16 }, "Jewel Type:")
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

	local selectedMods = {}
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
		if #selectedMods > 0 then
			options.requiredMods = copyTable(selectedMods)
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

	if context.slotTbl.unique then
		main:OpenPopup(popupWidth, popupHeight, "Query Options", controls)
		return
	end

	-- intended width of the whole row, including dropdown and aux controls
	local totalWidth = 340
	-- size of min value input
	local fieldWidth = 60
	-- size of clear button
	local buttonSize = 20
	-- gap between controls
	local xSpacing = 4
	local auxControlWidth = buttonSize + fieldWidth + 2 * xSpacing

	local _, lastItemY = lastItemAnchor:GetPos()
	local _, lastItemH = lastItemAnchor:GetSize()
	controls.modSelectorHeaderAnchor = new("Control", { "TOPLEFT", nil, "TOPLEFT" },
		-- position right below last item, centered horizontally
		{ (popupWidth - totalWidth) / 2, lastItemH + lastItemY, 0, 0 },
		"")
	updateLastAnchor(controls.modSelectorHeaderAnchor)
	-- get mod selector list
	getModList = function()
		_, itemCategory = tradeHelpers.getTradeCategory(slot.slotName, slot and self.itemsTab.items[slot.selItemId])
		-- add radius/base as they have different mods
		if controls.jewelType then
			itemCategory = controls.jewelType:GetSelValue() .. itemCategory
		end
		local mods = { { label = "^7+ Add Required Stat" } }
		for _, modType in ipairs({ "Explicit", "Implicit", "Corrupted" }) do
			for idStr, modData in pairs(self.modData[modType]) do
				if modData[itemCategory] ~= nil then
					local text = "^7" .. modData.tradeMod.text:gsub("(%a+) Passive Skills in Radius also grant ", "%1: ")
					if modType ~= "Explicit" then
						-- dim-ish red or the greenish yellow trade site uses for implicits slightly brightened
						local colour = modType == "Corrupted" and "^x9E3E38" or "^x989654"
						text = text .. string.format(" %s(%s)", colour, modType)
					end
					t_insert(mods, { label = text, tradeId = modData.tradeMod.id })
				end
			end
		end
		return mods
	end
	-- amount of mod selectors: technically we could have 40, but the more we have the fewer
	-- stats fit in the weighted sum, and this means a static popup size is ok
	local maxSelectors = 3
	-- set mod selector dropdown labels, adjust width, and possibly change the mod list
	setModSelectors = function(controls, modList)
		-- reset selections
		if modList then
			selectedMods = {}
		end
		for i = 1, maxSelectors do
			local mod = selectedMods[i]
			local selector = controls["modSelector" .. i]
			local minimumBox = controls["modSelectorMin" .. i]
			if modList then
				selector:SetList(modList)
			end
			if mod then
				selector:SelByValue(mod.label, "label")
				selector.width = totalWidth - auxControlWidth
				minimumBox.buf = mod.value and tostring(mod.value) or ""
			else
				selector.selIndex = 1
				selector.width = totalWidth
			end
			selector:CheckDroppedWidth(true)
		end
	end
	-- mod filter dropdown and aux controls
	for i = 1, maxSelectors do
		-- dropdown which lists all mods that fit
		local dropdown = new("DropDownControl", { "TOPLEFT", lastItemAnchor, "BOTTOMLEFT" },
			{ 0, 4, totalWidth, 20 }, nil,
			function(idx, val)
				if idx == 1 then
					table.remove(selectedMods, i)
				else
					selectedMods[i] = copyTable(val)
				end
				setModSelectors(controls)
			end)
		dropdown.shown = function()
			return not not selectedMods[i - 1] or i == 1
		end
		updateLastAnchor(dropdown)
		dropdown:SetList(mods)
		controls["modSelector" .. i] = dropdown

		-- box that sets minimum value for filter
		local minimumBox = tradeHelpers.newPlainNumericEdit({ "LEFT", lastItemAnchor, "RIGHT" },
			{ xSpacing, 0, fieldWidth, buttonSize }, "", "Min", 6, false, function(val)
				selectedMods[i].value = tonumber(val)
			end)
		minimumBox.shown = function()
			return not not selectedMods[i]
		end
		controls["modSelectorMin" .. i] = minimumBox

		-- button which removes the mod row
		local clearButton = new("ButtonControl", { "LEFT", minimumBox, "RIGHT" }, { xSpacing, 0, buttonSize, buttonSize },
			"x", function()
				table.remove(selectedMods, i)
				setModSelectors(controls)
			end)
		clearButton.shown = function()
			return not not selectedMods[i]
		end
		controls["modSelectorClear" .. i] = clearButton
	end
	setModSelectors(controls, getModList())

	main:OpenPopup(popupWidth, popupHeight, "Query Options", controls)
end