-- Path of Building
--
-- Module: AI Build Snapshot
-- Creates a compact English text snapshot of the current build for AI analysis.

local t_insert = table.insert

local snapshot = { }

local itemSlots = {
	"Weapon 1", "Weapon 2", "Weapon 1 Swap", "Weapon 2 Swap",
	"Helmet", "Body Armour", "Gloves", "Boots", "Amulet",
	"Ring 1", "Ring 2", "Ring 3", "Belt",
	"Charm 1", "Charm 2", "Charm 3", "Flask 1", "Flask 2",
}

local statOrder = {
	{ key = "FullDPS", label = "Full DPS" },
	{ key = "CombinedDPS", label = "Combined DPS" },
	{ key = "TotalDPS", label = "Hit DPS" },
	{ key = "TotalDot", label = "DoT DPS" },
	{ key = "AverageHit", label = "Average Hit" },
	{ key = "AverageDamage", label = "Average Damage" },
	{ key = "Speed", label = "Attack/Cast Rate" },
	{ key = "CritChance", label = "Crit Chance" },
	{ key = "HitChance", label = "Hit Chance" },
	{ key = "TotalEHP", label = "Effective Hit Pool" },
	{ key = "Life", label = "Life" },
	{ key = "EnergyShield", label = "Energy Shield" },
	{ key = "Mana", label = "Mana" },
	{ key = "Spirit", label = "Spirit" },
	{ key = "Armour", label = "Armour" },
	{ key = "Evasion", label = "Evasion" },
	{ key = "FireResist", label = "Fire Resistance" },
	{ key = "ColdResist", label = "Cold Resistance" },
	{ key = "LightningResist", label = "Lightning Resistance" },
	{ key = "ChaosResist", label = "Chaos Resistance" },
	{ key = "EffectiveBlockChance", label = "Block Chance" },
	{ key = "TotalNetRegen", label = "Total Net Recovery" },
	{ key = "EffectiveMovementSpeedMod", label = "Movement Speed Modifier" },
}

local function clean(value)
	value = tostring(value or "")
	if StripEscapes then
		value = StripEscapes(value)
	end
	value = value:gsub("%^x%x%x%x%x%x%x", "")
	value = value:gsub("%^%d", "")
	value = value:gsub("%^%a", "")
	return value
end

local function fmt(value)
	if type(value) == "number" then
		if value >= 1000 then
			return tostring(round(value))
		elseif value == math.floor(value) then
			return tostring(value)
		else
			return tostring(round(value, 2))
		end
	end
	return clean(value)
end

local function addHeader(lines, title)
	t_insert(lines, "")
	t_insert(lines, "## " .. title)
end

local function addKeyValue(lines, key, value)
	if value ~= nil and value ~= "" then
		t_insert(lines, "- " .. key .. ": " .. clean(value))
	end
end

local function gemName(gem)
	if not gem then
		return nil
	end
	if gem.gemData and gem.gemData.grantedEffect and gem.gemData.grantedEffect.name then
		return gem.gemData.grantedEffect.name
	end
	return gem.nameSpec or gem.name or "Unknown Gem"
end

local function addSkillGroups(lines, build)
	local skillsTab = build.skillsTab
	if not skillsTab or not skillsTab.socketGroupList then
		return
	end
	addHeader(lines, "Skills")
	for index, group in ipairs(skillsTab.socketGroupList) do
		if index > 10 then
			t_insert(lines, "- Remaining skill groups omitted.")
			break
		end
		local groupLabel = clean(group.displayLabel or group.label or ("Skill Group " .. index))
		local groupInfo = "- " .. index .. ". " .. groupLabel
		if index == build.mainSocketGroup then
			groupInfo = groupInfo .. " [main skill group]"
		end
		if group.slot then
			groupInfo = groupInfo .. " / " .. group.slot
		end
		if group.enabled == false or group.slotEnabled == false then
			groupInfo = groupInfo .. " / disabled"
		end
		t_insert(lines, groupInfo)
		local gemParts = { }
		for gemIndex, gem in ipairs(group.gemList or { }) do
			if gemIndex > 8 then
				t_insert(gemParts, "...")
				break
			end
			local label = clean(gemName(gem))
			if gem.level then
				label = label .. " Lv" .. tostring(gem.level)
			end
			if gem.quality and tonumber(gem.quality) and tonumber(gem.quality) > 0 then
				label = label .. " Q" .. tostring(gem.quality)
			end
			if gem.enabled == false then
				label = label .. " disabled"
			end
			t_insert(gemParts, label)
		end
		if #gemParts > 0 then
			t_insert(lines, "  Gems: " .. table.concat(gemParts, " + "))
		end
	end
end

local function addItems(lines, build)
	local itemsTab = build.itemsTab
	local itemSet = itemsTab and itemsTab.activeItemSet
	if not itemsTab or not itemSet then
		return
	end
	addHeader(lines, "Items")
	addKeyValue(lines, "Current item set", itemSet.title or "Default")
	for _, slotName in ipairs(itemSlots) do
		local slot = itemSet[slotName]
		local item = slot and itemsTab.items and itemsTab.items[slot.selItemId]
		if item then
			local name = clean(item.name or item.title or item.baseName or "Unknown Item")
			t_insert(lines, "- " .. slotName .. ": " .. name)
			local rawLines = item.rawLines or { }
			local added = 0
			for _, line in ipairs(rawLines) do
				line = clean(line)
				if line ~= "" and not line:match("^Rarity:") and not line:match("^Item Class:") and not line:match("^Unique ID:") then
					t_insert(lines, "  " .. line)
					added = added + 1
					if added >= 12 then
						break
					end
				end
			end
		end
	end
end

local function addStats(lines, build)
	local output = build.calcsTab and build.calcsTab.mainOutput
	if not output then
		return
	end
	addHeader(lines, "Key Stats")
	for _, stat in ipairs(statOrder) do
		local value = output[stat.key]
		if value ~= nil then
			addKeyValue(lines, stat.label, fmt(value))
		end
	end
	if output.SkillDPS and type(output.SkillDPS) == "table" then
		t_insert(lines, "- Skill DPS:")
		for index, skill in ipairs(output.SkillDPS) do
			if index > 8 then
				t_insert(lines, "  ...")
				break
			end
			local dps = (skill.dps or 0) * (skill.count or 1)
			t_insert(lines, "  " .. clean(skill.name or ("Skill " .. index)) .. ": " .. fmt(dps))
		end
	end
end

local function addWarnings(lines, build)
	local warnings = build.controls and build.controls.warnings and build.controls.warnings.lines
	if not warnings or not next(warnings) then
		return
	end
	addHeader(lines, "Warnings")
	for _, warning in pairs(warnings) do
		t_insert(lines, "- " .. clean(warning))
	end
end

function snapshot.Create(build)
	local lines = {
		"This is a Path of Building for Path of Exile 2 build snapshot. Use it as context for build analysis.",
	}
	addHeader(lines, "Character")
	addKeyValue(lines, "Build name", build.buildName or "Unnamed build")
	addKeyValue(lines, "Class", build.spec and build.spec.curClassName)
	addKeyValue(lines, "Ascendancy", build.spec and build.spec.curAscendClassName)
	addKeyValue(lines, "Level", build.characterLevel)
	if build.treeTab and build.treeTab.specList and build.treeTab.activeSpec then
		local spec = build.treeTab.specList[build.treeTab.activeSpec]
		addKeyValue(lines, "Passive tree", spec and spec.title or "Default")
	end
	if build.skillsTab and build.skillsTab.skillSets and build.skillsTab.activeSkillSetId then
		local set = build.skillsTab.skillSets[build.skillsTab.activeSkillSetId]
		addKeyValue(lines, "Skill set", set and set.title or "Default")
	end
	if build.configTab and build.configTab.configSets and build.configTab.activeConfigSetId then
		local set = build.configTab.configSets[build.configTab.activeConfigSetId]
		addKeyValue(lines, "Config set", set and set.title or "Default")
	end
	addSkillGroups(lines, build)
	addStats(lines, build)
	addItems(lines, build)
	addWarnings(lines, build)
	return table.concat(lines, "\n")
end

return snapshot
