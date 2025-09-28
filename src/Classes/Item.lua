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
local catalystList = {"Flesh", "Neural", "Carapace", "Uul-Netol's", "Xoph's", "Tul's", "Esh's", "Chayula's", "Reaver", "Sibilant", "Skittering", "Adaptive"}
local catalystTags = {
	{ "life" },
	{ "mana" },
	{ "defences" },
	{ "physical" },
	{ "fire" },
	{ "cold" },
	{ "lightning" },
	{ "chaos" },
	{ "attack" },
	{ "caster" },
	{ "speed" },
	{ "attribute" },
}

local minimumReqLevel = { }

local function getCatalystScalar(catalystId, tags, quality)
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

	-- Find if any of the catalyst's tags match the provided tags
	for _, catalystTag in ipairs(catalystTags[catalystId]) do
		if tagLookup[catalystTag] then
			return (100 + quality) / 100
		end
	end
	return 1
end

local ItemClass = newClass("Item", function(self, raw, rarity, highQuality)
	if raw then
		self:ParseRaw(sanitiseText(raw), rarity, highQuality)
	end	
end)

local lineFlags = {
	["custom"] = true, ["fractured"] = true, ["desecrated"] = true, ["enchant"] = true, ["implicit"] = true, ["rune"] = true,
}

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
		local currentVariant = false
		if v.variantList then
			for variant, enabled in pairs(v.variantList) do
				if enabled and variant == self.variant then
					currentVariant = true
				end
			end
		else
			currentVariant = true
		end
		if currentVariant then
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
					if v.line:lower():find(specialMod:lower()) and (not v.variantList or v.variantList[self.variant]) then
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
	self.classRequirementModLines = { }
	self.buffModLines = { }
	self.enchantModLines = { }
	self.runeModLines = { }
	self.implicitModLines = { }
	self.explicitModLines = { }
	local implicitLines = 0
	self.variantList = nil
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

	while self.rawLines[l] do	
		local line = self.rawLines[l]
		if flaskBuffLines and flaskBuffLines[line] then
			flaskBuffLines[line] = nil
		elseif charmBuffLines and charmBuffLines[line] then
			charmBuffLines[line] = nil
		elseif line == "--------" then
			self.checkSection = true
		elseif line == "Mirrored" then
			self.mirrored = true
		elseif line == "Corrupted" then
			self.corrupted = true
		elseif line == "Desecrated Prefix" or line == "Desecrated Suffix" then
			self.desecrated = true
		elseif line == "Requirements:" then
			-- nothing to do
		else
			if self.checkSection then
				if gameModeStage == "IMPLICIT" then
					if foundImplicit then
						-- There were definitely implicits, so any following modifiers must be explicits
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
			local specName, specVal = line:match("^([%a ]+:?): (.+)$")
			if specName then
				if specName == "Class:" then
					specName = "Requires Class"
				end
			else
				specName, specVal = line:match("^(Requires %a+) (.+)$")
			end
			if specName then
				if specName == "Unique ID" then
					self.uniqueID = specVal
				elseif specName == "Item Level" then
					self.itemLevel = specToNumber(specVal)
				elseif specName == "Requires Class" then
					self.classRestriction = specVal
				elseif specName == "Charm Slots" then
					self.charmLimit = specToNumber(specVal)
				elseif specName == "Spirit" then
					self.spiritValue = specToNumber(specVal)
				elseif specName == "Quality" then
					self.quality = specToNumber(specVal)
				elseif specName == "Sockets" then
					local group = 0
					for c in specVal:gmatch(".") do
						if c:match("[S]") then
							t_insert(self.sockets, { group = group })
							group = group + 1
						end
					end
					self.itemSocketCount = #self.sockets
				elseif specName == "Rune" then
					t_insert(self.runes, specVal)
					local runeLevel = 0
					local runeData = data.itemMods.Runes[specVal]
					if runeData then
						for _, slotData in pairs(runeData) do
							runeLevel = math.max(runeLevel, slotData.rank[1])
						end
					end
					if runeLevel > 0 and (not self.requirements.runeLevel or runeLevel > self.requirements.runeLevel) then
						self.requirements.runeLevel = runeLevel
					end
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
				elseif specName == "Variant" then
					if not self.variantList then
						self.variantList = { }
					end
					-- This has to be kept for backwards compatibility
					local ver, name = specVal:match("{([%w_]+)}(.+)")
					if ver then
						t_insert(self.variantList, name)
					else
						t_insert(self.variantList, specVal)
					end
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
				elseif specName == "Requires Level" then
					self.requirements.level = specToNumber(specVal)
					minimumReqLevel = minimumReqLevel or {}
					table.insert(minimumReqLevel, { name = self.name, level = specVal })
				elseif specName == "Level" then
					-- Requirements from imported items can't always be trusted
					importedLevelReq = specToNumber(specVal)
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
				elseif specName == "Selected Variant" then
					self.variant = specToNumber(specVal)
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
				elseif specName == "Prefix" then
					local range, affix = specVal:match("{range:([%d.]+)}(.+)")
					range = range or ((affix or specVal) ~= "None" and main.defaultItemAffixQuality)
					t_insert(self.prefixes, {
						modId = affix or specVal,
						range = tonumber(range),
					})
				elseif specName == "Suffix" then
					local range, affix = specVal:match("{range:([%d.]+)}(.+)")
					range = range or ((affix or specVal) ~= "None" and main.defaultItemAffixQuality)
					t_insert(self.suffixes, {
						modId = affix or specVal,
						range = tonumber(range),
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
				elseif specName == "Str" or specName == "Strength" or specName == "Dex" or specName == "Dexterity" or
				       specName == "Int" or specName == "Intelligence" then
					self.requirements[specName:sub(1,3):lower()] = specToNumber(specVal)
				elseif specName == "Critical Hit Range" or specName == "Attacks per Second" or specName == "Weapon Range" or
				       specName == "Critical Hit Chance" or specName == "Physical Damage" or specName == "Elemental Damage" or
				       specName == "Chaos Damage" or specName == "Fire Damage" or specName == "Cold Damage" or specName == "Lightning Damage" or 
					   specName == "Reload Time" or specName == "Chance to Block" or specName == "Block chance" or 
					   specName == "Armour" or specName == "Energy Shield" or specName == "Evasion" or specName == "Requires" then
					self.hidden_specs = true
				-- Anything else is an explicit with a colon in it (Fortress Covenant, Pure Talent, etc) unless it's part of the custom name
				elseif not (self.name:match(specName) and self.name:match(specVal)) then
					foundExplicit = true
					gameModeStage = "EXPLICIT"
				end
			end
			if line == "Prefixes:" then
				foundExplicit = true
				gameModeStage = "EXPLICIT"
			end
			if not specName or foundExplicit or foundImplicit then
				local modLine = { modTags = {} }

				line = line:gsub("{(%a*):?([^}]*)}", function(k,val)
					if k == "variant" then
						modLine.variantList = { }
						for varId in val:gmatch("%d+") do
							modLine.variantList[tonumber(varId)] = true
						end
					elseif k == "tags" then
						for tag in val:gmatch("[%a_]+") do
							t_insert(modLine.modTags, tag)
						end
					elseif k == "range" then
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
				if modLine.rune then
					modLine.enchant = true
				end
				if modLine.enchant then
					modLine.implicit = true
				end
				if modLine.desecrated then
					self.desecrated = true
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
				if base then
					-- Items with variants can have multiple bases
					self.baseLines[baseName] = { line = baseName, variantList = modLine.variantList }
					-- Set the actual base if variant matches or doesn't have variants
					if not self.variant or not modLine.variantList or modLine.variantList[self.variant] then
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
						self.corruptible = self.base.type ~= "Flask" and self.base.type ~= "Charm" and self.base.type ~= "Rune" and self.base.type ~= "SoulCore"
						self.clusterJewel = data.clusterJewels and data.clusterJewels.jewels[self.baseName]
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
				local catalystScalar = getCatalystScalar(self.catalyst, modLine.modTags, self.catalystQuality)
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

				local lineLower = line:lower()
				if lineLower == "implicit modifiers cannot be changed" then
					self.implicitsCannotBeChanged = true
				elseif lineLower:match(" prefix modifiers? allowed") then
					self.prefixes.limit = (self.prefixes.limit or 0) + (tonumber(lineLower:match("%+(%d+) prefix modifiers? allowed")) or 0) - (tonumber(lineLower:match("%-(%d+) prefix modifiers? allowed")) or 0)
				elseif lineLower:match(" suffix modifiers? allowed") then
					self.suffixes.limit = (self.suffixes.limit or 0) + (tonumber(lineLower:match("%+(%d+) suffix modifiers? allowed")) or 0) - (tonumber(lineLower:match("%-(%d+) suffix modifiers? allowed")) or 0)
				elseif lineLower == "this item can be anointed by cassia" then
					self.canBeAnointed = true
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
		if self.base.weapon or self.base.armour or self.base.tags.wand or self.base.tags.staff or self.base.tags.sceptre then
			local shouldFixRunesOnItem = #self.runes == 0

			-- Form a key value table with the following format
			-- { [strippedModLine] = { { runeName1, runeValue1 }, etc, }, etc}
			-- This will be used to more easily grab the relevant runes that combinations will need to be of.
			-- This could be refactored to only needs to be called once.
			local statGroupedRunes = { }
			local broadItemType = self.base.weapon and "weapon" or (self.base.tags.wand or self.base.tags.staff) and "caster" or "armour" -- minor optimisation
			local specificItemType = self.base.type:lower()
			for runeName, runeMods in pairs(data.itemMods.Runes) do
				local addModToGroupedRunes = function (modLine)
					local runeValue = 1
					local runeStrippedModLine = modLine:gsub("(%d%.?%d*)", function(val)
						runeValue = val
						return "#"
					end)
					if statGroupedRunes[runeStrippedModLine] == nil then
						statGroupedRunes[runeStrippedModLine] = { }
					end
					t_insert(statGroupedRunes[runeStrippedModLine], { runeName, runeValue });
				end
				for slotType, slotMod in pairs(runeMods) do
					if slotType == broadItemType or slotType == specificItemType then
						for _, mod in ipairs(slotMod) do
							addModToGroupedRunes(mod)
						end
					end
				end
			end

			-- Sort table to ensure first entries are always largest.
			for _, runes in pairs(statGroupedRunes) do
				table.sort(runes,  function(a, b) return a[2] > b[2] end)
			end

			local remainingRunes = self.itemSocketCount
			for i, modLine in ipairs(self.runeModLines) do
				local value = 1
				local strippedModLine = modLine.line:gsub("(%d%.?%d*)", function(val)
					value = val
					return "#"
				end)
				local groupedRunes = statGroupedRunes[strippedModLine]
				if groupedRunes then -- found the rune category with the relevant stat.
					-- First a greedy base is found using the runes in the groupedRunes. If this matches the target value then that set of runes is applied.
					-- If the greedy base isn't a solution we search all the possible combinations that could lead to a valid combination.
					-- This done by recursing through all combinations that could lead to a valid value and pruning values that exceed the number
					-- of runes and solutions that it would be impossible to reach the target value from. Visited combinations are recorded and are used such 
					-- that candidates are only searched once. This makes for a fairly efficient algorithm that doesn't search unneeded values very much.
					local function getNumberOfRunesOfEachType(values, target)
						local function adjustCombination(values, target, result, best, visited, sum, count)
							-- This is used to avoid unnecessary checks on decrement.
							local function checkAndAdjustCombination(values, target, result, best, visited, sum, count)
								-- If it's a valid solution, update best
								if math.abs(sum-target) <  1e-9 then
									if not best.count or count < best.count then
										best.count = count
										-- Copy solution to avoid side effects from continued searching.
										local solution = {}
										for k, v in pairs(result) do
											solution[k] = v
										end
										best.solution = solution
									end
									return
								end

								-- Prune if we already used more runes than the best found
								if best.count and count >= best.count then return end

								return adjustCombination(values, target, result, best, visited, sum, count)
							end

							for _, v in ipairs(values) do
								local function checkUnique(result)
									-- Generate a unique key from the result table this prevents duplicates combinations being searched
									local key = ""
									for value, count in pairs(result) do
										if count > 0 then
											key = key .. value .. "x" .. count .. " "
										end
									end
									if visited[key] then 
										return false 
									else
										visited[key] = true
										return true
									end
								end
								
								-- Incrementing is done first as to reach the target you will need to add a count as such it should be more efficient.
								-- Try increasing (if it doesn't overshoot or exceed maximum number of remaining runes)
								if sum + tonumber(v) <= target + 1e-9 and count < remainingRunes then
									result[v] = (result[v] or 0) + 1
									if checkUnique(result) then
										checkAndAdjustCombination(values, target, result, best, visited, sum + v, count + 1)
									end
									result[v] = result[v] - 1
								end

								-- Try decreasing (if possible and only if target is still reachable).
								if (result[v] or 0) > 0 and (not best.count or target - 1e-9 < sum - tonumber(v) + values[1] * (best.count - count + 1)) then
									result[v] = result[v] - 1
									if checkUnique(result) then
										adjustCombination(values, target, result, best, visited, sum - v, count - 1)
									end
									result[v] = result[v] + 1
								end
							end
						end
						
						-- Step 1: Perform greedy search and tests if a single rune is used as these are the most common use case.
						local greedySolution = {}
						local leftover = target

						for _, v in ipairs(values) do
							local count = math.floor(leftover / v)
							greedySolution[v] = count
							leftover = leftover - count * v
						end

						local greedyCount = 0
						for v, c in pairs(greedySolution) do
							greedyCount = greedyCount + c
						end
						if math.abs(leftover) <= 1e-9 then -- Greedy search found a solution
							return greedySolution, greedyCount
						end

						-- Step 2. Perform search starting from the greedy base
						local best = {count = nil, solution = nil}
						local visited = {}

						adjustCombination(values, target, greedySolution, best, visited, target - leftover, greedyCount)

						return best.solution, best.count
					end

					local values = { }
					for i, runes in ipairs(groupedRunes) do
						t_insert(values, runes[2])
					end
					local result, numRunes = getNumberOfRunesOfEachType(values, tonumber(value))

					if result then -- we have found a valid combo for that rune category
						remainingRunes = remainingRunes - numRunes
						-- this code should probably be refactored to based off stored self.runes rather than the recomputed amounts off the runeModLines this 
						-- is too avoid having to run the relatively expensive recomputation every time the item is parsed even if we know the runes on the item already.
						modLine.soulCore = groupedRunes[1][1]:match("Soul Core") ~= nil
						modLine.runeCount = numRunes

						if shouldFixRunesOnItem then
							for i, rune in ipairs(groupedRunes) do
								for _ = 1, tonumber(result[rune[2]]) do
									t_insert(self.runes, groupedRunes[i][1])
								end
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
	
	if self.base and not self.requirements.level then
		if importedLevelReq and #self.sockets == 0 then
			-- Requirements on imported items can only be trusted for items with no sockets
			self.requirements.level = importedLevelReq
		else
			self.requirements.level = self.base.req.level
		end
	end
	if self.base and not self.requirements.baseLevel then
		self.requirements.baseLevel = self.base.req.level
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
	if self.variantList then
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
			self.quality = self.base.quality
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
		for i, affix in ipairs(self.prefixes or { }) do
			t_insert(rawLines, "Prefix: " .. (affix.range and ("{range:" .. round(affix.range,3) .. "}") or "") .. affix.modId)
		end
		for i, affix in ipairs(self.suffixes or { }) do
			t_insert(rawLines, "Suffix: " .. (affix.range and ("{range:" .. round(affix.range,3) .. "}") or "") .. affix.modId)
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
		if modLine.range and line:match("%(%-?[%d%.]+%-%-?[%d%.]+%)") then
			line = "{range:" .. round(modLine.range, 3) .. "}" .. line
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
		if modLine.variantList then
			local varSpec
			for varId in pairs(modLine.variantList) do
				varSpec = (varSpec and varSpec .. "," or "") .. varId
			end
			local var = "{variant:" .. varSpec .. "}"
			line = var .. line:gsub("\n", "\n" .. var) -- Variants that go over 1 line need to have the gsub to fix there being no "variant:" at the start
		end
		if modLine.modTags and #modLine.modTags > 0 then
			line = "{tags:" .. table.concat(modLine.modTags, ",") .. "}" .. line
		end
		t_insert(rawLines, line)
	end
	if self.variantList then
		for _, variantName in ipairs(self.variantList) do
			t_insert(rawLines, "Variant: " .. variantName)
		end
		t_insert(rawLines, "Selected Variant: " .. self.variant)

		for _, baseLine in pairs(self.baseLines) do
			if baseLine.variantList then
				writeModLine(baseLine)
			end
		end	
		if self.hasAltVariant then
			t_insert(rawLines, "Has Alt Variant: true")
			t_insert(rawLines, "Selected Alt Variant: " .. self.variantAlt)
		end
		if self.hasAltVariant2 then
			t_insert(rawLines, "Has Alt Variant Two: true")
			t_insert(rawLines, "Selected Alt Variant Two: " .. self.variantAlt2)
		end
		if self.hasAltVariant3 then
			t_insert(rawLines, "Has Alt Variant Three: true")
			t_insert(rawLines, "Selected Alt Variant Three: " .. self.variantAlt3)
		end
		if self.hasAltVariant4 then
			t_insert(rawLines, "Has Alt Variant Four: true")
			t_insert(rawLines, "Selected Alt Variant Four: " .. self.variantAlt4)
		end
		if self.hasAltVariant5 then
			t_insert(rawLines, "Has Alt Variant Five: true")
			t_insert(rawLines, "Selected Alt Variant Five: " .. self.variantAlt5)
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
	if self.corrupted then
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
	wipeTable(self.runeModLines)
	local getModRunesForTypes = function(runeName, baseType, specificType) 
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
		end
		return gatheredRuneMods
	end
	
	local statOrder = {}
	for i = 1, self.itemSocketCount do
		local name = self.runes[i]
		if name and name ~= "None" then
			local baseType = self.base.weapon and "weapon" or self.base.armour and "armour" or (self.base.tags.wand or self.base.tags.staff) and "caster"
			local specificType = self.base.type:lower()
			local gatheredMods = getModRunesForTypes(name, baseType, specificType)
			for _, mod in ipairs(gatheredMods) do
				for i, modLine in ipairs(mod) do
					local order = mod.statOrder[i]
					if statOrder[order] then
						-- Combine stats
						local start = 1
						statOrder[order].line = statOrder[order].line:gsub("(%d%.?%d*)", function(num)
							local s, e, other = mod[i]:find("(%d%.?%d*)", start)
							start = e + 1
							return tonumber(num) + tonumber(other)
						end)
					else
						local modLine = { line = modLine, order = order, rune = true, enchant = true }
						for l = 1, #self.runeModLines + 1 do
							if not self.runeModLines[l] or self.runeModLines[l].order > order then
								t_insert(self.runeModLines, l, modLine)
								break
							end
						end
						statOrder[order] = modLine
					end	
				end
			end
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
	self.requirements.level = self.base.req.level
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
				self.requirements.level = m_max(self.requirements.level or 0, m_floor(mod.level * 0.8))
				local rangeScalar = getCatalystScalar(self.catalyst, mod.modTags, self.catalystQuality)
				for i, line in ipairs(mod) do
					line = itemLib.applyRange(line, affix.range or 0.5, rangeScalar)
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
						local modLine = { line = line, order = order }
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

	self:BuildAndParseRaw()
end

function ItemClass:CheckModLineVariant(modLine)
	return not modLine.variantList 
		or modLine.variantList[self.variant]
		or (self.hasAltVariant and modLine.variantList[self.variantAlt])
		or (self.hasAltVariant2 and modLine.variantList[self.variantAlt2])
		or (self.hasAltVariant3 and modLine.variantList[self.variantAlt3])
		or (self.hasAltVariant4 and modLine.variantList[self.variantAlt4])
		or (self.hasAltVariant5 and modLine.variantList[self.variantAlt5])
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
	else
		return self.type
	end
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
	local modList = new("ModList")
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
		for _, dmgType in pairs(dmgTypeList) do
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
			-- Convert accuracy, L/MGoH and PAD Leech modifiers to local
			if (
				(mod.name == "Accuracy" and mod.flags == 0) or (mod.name == "ImpaleChance" and mod.flags ~= ModFlag.Spell) or
				((mod.name == "LifeOnHit" or mod.name == "ManaOnHit") and mod.flags == ModFlag.Attack) or
				((mod.name == "PhysicalDamageLifeLeech" or mod.name == "PhysicalDamageManaLeech") and mod.flags == ModFlag.Attack)
			   ) and (mod.keywordFlags == 0 or mod.keywordFlags == KeywordFlag.Attack) and not mod[1] then
				mod[1] = { type = "Condition", var = (slotNum == 1) and "MainHandAttack" or "OffHandAttack" }
			elseif (mod.name == "PoisonChance" or mod.name == "BleedChance") and mod.flags ~= ModFlag.Spell and (not mod[1] or (mod[1].type == "Condition" and mod[1].var == "CriticalStrike" and not mod[2])) then
				t_insert(mod, { type = "Condition", var = (slotNum == 1) and "MainHandAttack" or "OffHandAttack" })
			end
		end
		weaponData.TotalDPS = 0
		for _, dmgType in pairs(dmgTypeList) do
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

		armourData.Armour = round((armourBase + armourEvasionBase + armourEnergyShieldBase) * (1 + (armourInc + armourEvasionInc + armourEnergyShieldInc + defencesInc) / 100) * (1 + (qualityScalar / 100)))
		armourData.Evasion = round((evasionBase + armourEvasionBase + evasionEnergyShieldBase) * (1 + (evasionInc + armourEvasionInc + evasionEnergyShieldInc + defencesInc) / 100) * (1 + (qualityScalar / 100)))
		armourData.EnergyShield = round((energyShieldBase + evasionEnergyShieldBase + armourEnergyShieldBase) * (1 + (energyShieldInc + armourEnergyShieldInc + evasionEnergyShieldInc + defencesInc) / 100) * (1 + (qualityScalar / 100)))
		armourData.Ward = round((wardBase) * (1 + (wardInc + defencesInc) / 100) * (1 + (qualityScalar / 100)))

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
		charmData.duration = round(self.base.charm.duration * (1 + durationInc / 100) * durationMore, 1)
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

-- Build lists of modifiers for each slot the item can occupy
function ItemClass:BuildModList()
	if not self.base then
		return
	end
	local baseList = new("ModList")
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
		if self:CheckModLineVariant(modLine) then
			-- special section for variant over-ride of pre-modifier item parameters
			if modLine.line:find("Requires Class") then
				self.classRestriction = modLine.line:gsub("{variant:([%d,]+)}", ""):match("Requires Class (.+)")
			end
			-- handle understood modifier variable properties
			if not modLine.extra then
				if modLine.range then
					-- Check if line actually has a range
					if modLine.line:find("%((%-?%d+%.?%d*)%-(%-?%d+%.?%d*)%)") then
						local strippedModeLine = modLine.line:gsub("\n"," ")						
						local catalystScalar = getCatalystScalar(self.catalyst, modLine.modTags, self.catalystQuality)
						-- Put the modified value into the string
						local line = itemLib.applyRange(strippedModeLine, modLine.range, catalystScalar, modLine.corruptedRange)
						-- Check if we can parse it before adding the mods
						local list, extra = modLib.parseMod(line)
						if list and not extra then
							modLine.modList = list
							t_insert(self.rangeLineList, modLine)
						end
					end
				end
				for _, mod in ipairs(modLine.modList) do
					mod = modLib.setSource(mod, self.modSource)
					baseList:AddMod(mod)
				end
				if modLine.modTags and #modLine.modTags > 0 then
					self.hasModTags = true
				end
			end
		end
	end
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
	self.grantedSkills = { }
	for _, skill in ipairs(baseList:List(nil, "ExtraSkill")) do
		if skill.name ~= "Unknown" then
			t_insert(self.grantedSkills, {
				skillId = skill.skillId,
				level = skill.level,
				noSupports = skill.noSupports,
				source = self.modSource,
				triggered = skill.triggered,
				triggerChance = skill.triggerChance,
			})
		end
	end

	local reqLevel = 0
	local minReqLevel

	-- look up base minimum requirement
	for _, entry in ipairs(minimumReqLevel) do
		if entry.name == self.title then
			minReqLevel = entry.level
			break
		end
	end

	if #self.grantedSkills >= 1 then
		local skillDef = data.skills[self.grantedSkills[1].skillId]
		local gemId = data.gemForSkill[skillDef]
		local gem = data.gems[gemId]

		local skillLevel = self.grantedSkills[1].level or #skillDef.levels
		local chosenLevel = skillDef.levels[skillLevel] or skillDef.levels[#skillDef.levels]
		local gemLevelReq = chosenLevel.levelRequirement

		reqLevel = m_max(gemLevelReq, minReqLevel or 0, self.requirements.runeLevel or 0, self.requirements.baseLevel or 0)

		-- Rune level and unique base level don't scale attribute requirements. Example, Cursecarver has 33 minimum required level
		-- but the intelligence requirement will be 21 at level 4 skill.
		local attrLevel = m_max(gemLevelReq, self.requirements.baseLevel or 0)

		if self.base.type == "Sceptre" or self.base.type == "Wand" or self.base.type == "Staff" then
			self.requirements.int = calcLib.getGemStatRequirement(attrLevel, gem.reqInt)
			self.requirements.dex = calcLib.getGemStatRequirement(attrLevel, gem.reqDex)
			self.requirements.str = calcLib.getGemStatRequirement(attrLevel, gem.reqStr)
		end
	else
		reqLevel = m_max(minReqLevel or 0, self.requirements.runeLevel or 0, self.requirements.baseLevel or 0)
	end

	self.requirements.level = reqLevel

	if self.name == "Tabula Rasa, Simple Robe" or self.name == "Skin of the Loyal, Simple Robe" or self.name == "Skin of the Lords, Simple Robe" or self.name == "The Apostate, Cabalist Regalia" then
		-- Hack to remove the energy shield and base int requirement
		baseList:NewMod("ArmourData", "LIST", { key = "EnergyShield", value = 0 })
		self.requirements.int = 0
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
	self.socketedSoulCoreEffectModifier = calcLocal(baseList, "SocketedSoulCoreEffect", "INC", 0) / 100
end
