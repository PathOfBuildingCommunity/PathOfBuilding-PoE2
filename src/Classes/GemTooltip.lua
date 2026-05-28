-- Path of Building
--
-- Module: Gem Tooltip
-- Shared renderer for gem-style tooltips.

local m_max = math.max

local GemTooltip = { }

local function getFontSizes()
	return main.showFlavourText and 18 or 16, main.showFlavourText and 24 or 20
end

local function addDescriptionLine(tooltip, build, statSet, line, stat, index)
	local fontSizeBig = getFontSizes()
	local source = statSet.statMap[stat] or build.data.skillStatMap[stat]
	local bg = (index % 2 == 0) and "GemHoverModBg" or nil
	if source then
		if launch.devModeAlt then
			local devText = stat
			if source[1] then
				if not source[1].value then
					source[1].value = stat
				end
				devText = modLib.formatMod(source[1])
			end
			line = line .. " ^2" .. devText
		end
		tooltip:AddLine(fontSizeBig, colorCodes.MAGIC .. line, "FONTIN SC", bg)
	else
		if launch.devModeAlt then
			line = line .. " ^1" .. stat
		end
		line = colorCodes.UNSUPPORTED .. line
		line = main.notSupportedModTooltips and (line .. main.notSupportedTooltipText) or line
		tooltip:AddLine(fontSizeBig, line, "FONTIN SC", bg)
	end
end

local function getDisplayInstance(gemInstance)
	return gemInstance.displayEffect or gemInstance
end

local function addGrantedEffectInfo(tooltip, build, gemInstance, grantedEffect, addReq, levelRange)
	local fontSizeBig = getFontSizes()
	local displayInstance = getDisplayInstance(gemInstance)
	local levelStats = grantedEffect.levels[levelRange and 1 or displayInstance.level] or { }
	local maxStats = levelRange and (grantedEffect.levels[20] or levelStats) or levelStats

	-- Passive tree tooltips need level 1-20 ranges; normal gem tooltips keep the current level value.
	local function valueOrRange(keyName, formatter, add, div, mul)
		local firstValue = levelStats[keyName]
		if not firstValue then
			return nil
		end
		local lastValue = levelRange and ((maxStats and maxStats[keyName]) or firstValue) or firstValue
		local numFormat = formatter or "%d"
		local first = (mul or 1) * (firstValue + (add or 0)) / (div or 1)
		local last = (mul or 1) * (lastValue + (add or 0)) / (div or 1)
		if first == last then
			return string.format(numFormat, first)
		end
		return string.format("(" .. numFormat .. "-" .. numFormat .. ")", first, last)
	end

	if not levelRange and gemInstance.gemData.Tier and gemInstance.gemData.Tier > 0 and not grantedEffect.isLineage and not grantedEffect.hidden then
		tooltip:AddLine(fontSizeBig, string.format("^x7F7F7FTier: ^7%d", gemInstance.gemData.Tier), "FONTIN SC")
	end
	if not levelRange and addReq and not grantedEffect.support then
		local totalGlobalLevels = 0
		if displayInstance.gemPropertyInfo then
			for i, prop in ipairs(displayInstance.gemPropertyInfo) do
				if prop.value and prop.value.key == "level" and prop.value.value then
					totalGlobalLevels = totalGlobalLevels + prop.value.value
				end
			end
		end
		local totalLevel
		local corruptLevel = displayInstance.corruptLevel or 0
		totalLevel = m_max(displayInstance.level, (gemInstance.level + corruptLevel)) -- Needed for tooltip comparison for dropdown gems. Otherwise they only show level 20 when corrupted.
		if corruptLevel ~= 0 or
		totalGlobalLevels > 0 or
		(displayInstance.level - gemInstance.level - corruptLevel > 0)
		then
			tooltip:AddLine(fontSizeBig, string.format("^x7F7F7FLevel: ^7" .. colorCodes.MAGIC .. totalLevel), "FONTIN SC")
			tooltip:AddLine(fontSizeBig, "^7" .. gemInstance.level .. " Levels from Gem" .. ((gemInstance.level >= gemInstance.gemData.naturalMaxLevel) and " (Max)" or ""), "FONTIN SC")
		else
			tooltip:AddLine(fontSizeBig, string.format("^x7F7F7FLevel: ^7" .. totalLevel .. ((gemInstance.level >= gemInstance.gemData.naturalMaxLevel) and " (Max)" or "")), "FONTIN SC")
		end
		if corruptLevel > 0 then
			tooltip:AddLine(fontSizeBig, colorCodes.MAGIC .. "+" .. corruptLevel .. " Level from Corruption", "FONTIN SC")
		elseif corruptLevel < 0 then
			tooltip:AddLine(fontSizeBig, colorCodes.MAGIC .. corruptLevel .. " Level from Corruption", "FONTIN SC")
		end
		if totalGlobalLevels > 0 then
			tooltip:AddLine(fontSizeBig, colorCodes.MAGIC .. "+" .. totalGlobalLevels .. " Levels from Global Modifiers", "FONTIN SC")
			if totalLevel - gemInstance.level - corruptLevel - totalGlobalLevels > 0 then
				tooltip:AddLine(fontSizeBig, colorCodes.MAGIC .. "+" .. totalLevel - gemInstance.level - corruptLevel - totalGlobalLevels .. " Levels from Supports", "FONTIN SC")
			end
		elseif totalLevel - gemInstance.level - corruptLevel > 0 then
			tooltip:AddLine(fontSizeBig, colorCodes.MAGIC .. "+" .. totalLevel - gemInstance.level - corruptLevel .. " Levels from Supports", "FONTIN SC")
		end
	end

	if not levelRange and grantedEffect.support then
		if levelStats.manaMultiplier and levelStats.reservationMultiplier and levelStats.manaMultiplier == levelStats.reservationMultiplier then
			tooltip:AddLine(fontSizeBig, string.format("^x7F7F7FCost & Reservation Multiplier: ^7%d%%", levelStats.manaMultiplier + 100), "FONTIN SC")
		elseif levelStats.reservationMultiplier then
			tooltip:AddLine(fontSizeBig, string.format("^x7F7F7FReservation Multiplier: ^7%d%%", levelStats.reservationMultiplier + 100), "FONTIN SC")
		elseif levelStats.manaMultiplier then
			tooltip:AddLine(fontSizeBig, string.format("^x7F7F7FCost Multiplier: ^7%d%%", levelStats.manaMultiplier + 100), "FONTIN SC")
		end
		if levelStats.spiritReservationFlat then
			tooltip:AddLine(fontSizeBig, string.format("^x7F7F7FAdditional Reservation: ^7%d Spirit", levelStats.spiritReservationFlat), "FONTIN SC")
		end
	else
		if gemInstance.skillMinion and not levelRange then
			if gemInstance.nameSpec:match("^Spectre:") then
				levelStats.spiritReservationFlat = data.spectres[gemInstance.skillMinion].spectreReservation
			elseif gemInstance.nameSpec:match("^Companion:") then
				levelStats.spiritReservationPercent = data.spectres[gemInstance.skillMinion].companionReservation
			end
		end
		if levelStats.spiritReservationFlat then
			tooltip:AddLine(fontSizeBig, string.format("^x7F7F7FReservation: ^7%s Spirit", valueOrRange("spiritReservationFlat")), "FONTIN SC")
		end
		if levelStats.spiritReservationPercent then
			tooltip:AddLine(fontSizeBig, string.format("^x7F7F7FReservation: ^7%s%% Spirit", valueOrRange("spiritReservationPercent", "%.1f")), "FONTIN SC")
		end
		local cost
		for _, res in ipairs(data.costs) do
			if levelStats.cost and levelStats.cost[res.Resource] then
				local first = round(levelStats.cost[res.Resource] / res.Divisor, 2)
				local last = first
				if levelRange and maxStats.cost and maxStats.cost[res.Resource] then
					last = round(maxStats.cost[res.Resource] / res.Divisor, 2)
				end
				local value = first == last and string.format("%g", first) or string.format("(%g-%g)", first, last)
				cost = (cost and (cost .. ", ") or "") .. res.ResourceString:gsub("{0}", value)
			end
		end
		if cost then
			tooltip:AddLine(fontSizeBig, "^x7F7F7FCost: ^7" .. cost, "FONTIN SC")
		end
	end

	if levelStats.cooldown then
		local line = string.format("^x7F7F7FCooldown Time: ^7%s sec", valueOrRange("cooldown", "%.2f"))
		if levelStats.storedUses and levelStats.storedUses > 1 then
			line = line .. string.format(" (%s uses)", valueOrRange("storedUses"))
		end
		tooltip:AddLine(fontSizeBig, line, "FONTIN SC")
	end
	if levelStats.vaalStoredUses then
		tooltip:AddLine(fontSizeBig, string.format("^x7F7F7FCan Store ^7%d ^x7F7F7FUse (%d Souls)", levelStats.vaalStoredUses, levelStats.vaalStoredUses * levelStats.cost.Soul), "FONTIN SC")
	end
	if levelStats.soulPreventionDuration then
		tooltip:AddLine(fontSizeBig, string.format("^x7F7F7FSoul Gain Prevention: ^7%s sec", valueOrRange("soulPreventionDuration")), "FONTIN SC")
	end
	if gemInstance.gemData.tags.attack then
		if levelStats.attackSpeedMultiplier then
			tooltip:AddLine(fontSizeBig, string.format("^x7F7F7FAttack Speed: ^7%s%% of base", valueOrRange("attackSpeedMultiplier", nil, 100)), "FONTIN SC")
		end
		if levelStats.attackTime then
			tooltip:AddLine(fontSizeBig, string.format("^x7F7F7FAttack Time: ^7%s sec", valueOrRange("attackTime", "%.2f", nil, 1000)), "FONTIN SC")
		end
		if levelStats.baseMultiplier then
			tooltip:AddLine(fontSizeBig, string.format("^x7F7F7FAttack Damage: ^7%s%% of base", valueOrRange("baseMultiplier", "%g", nil, nil, 100)), "FONTIN SC")
		end
	elseif not grantedEffect.hidden then
		if (grantedEffect.castTime or 0) > 0 then
			tooltip:AddLine(fontSizeBig, string.format("^x7F7F7FCast Time: ^7%.2f sec", grantedEffect.castTime), "FONTIN SC")
		else
			tooltip:AddLine(fontSizeBig, "^x7F7F7FCast Time: ^7Instant", "FONTIN SC")
		end
	end
	if levelStats.critChance then
		tooltip:AddLine(fontSizeBig, string.format("^x7F7F7FCritical Hit Chance: ^7%s%%", valueOrRange("critChance", "%.2f")), "FONTIN SC")
	end
	if gemInstance.gemData.weaponRequirements and not grantedEffect.hidden then
		tooltip:AddLine(fontSizeBig, "^x7F7F7F Requires: ^7" .. gemInstance.gemData.weaponRequirements, "FONTIN SC")
	end
	if not levelRange and addReq and displayInstance.quality > 0 then
		tooltip:AddLine(fontSizeBig, string.format("^x7F7F7FQuality: " .. colorCodes.MAGIC .. "+%d%%^7%s",
			gemInstance.quality,
			(displayInstance.quality > gemInstance.quality) and " (" .. colorCodes.MAGIC .. "+" .. (displayInstance.quality - gemInstance.quality) .. "^7)" or ""
		), "FONTIN SC")
	end
	tooltip:AddSeparator(10)
	if not levelRange and addReq then
		local reqLevel = grantedEffect.levels[gemInstance.level] and grantedEffect.levels[gemInstance.level].levelRequirement or 1
		build:AddRequirementsToTooltip(tooltip, reqLevel,
			calcLib.getGemStatRequirement(reqLevel, gemInstance.gemData.reqStr, grantedEffect.support),
			calcLib.getGemStatRequirement(reqLevel, gemInstance.gemData.reqDex, grantedEffect.support),
			calcLib.getGemStatRequirement(reqLevel, gemInstance.gemData.reqInt, grantedEffect.support))
	end
	tooltip.center = true
	if grantedEffect.description then
		local wrap = main:WrapString(grantedEffect.description, 16, m_max(DrawStringWidth(fontSizeBig, "VAR", gemInstance.gemData.tagString), 400))
		for _, line in ipairs(wrap) do
			tooltip:AddLine(fontSizeBig, colorCodes.GEMDESCRIPTION .. line, "FONTIN ITALIC")
		end
	end
	if displayInstance.corrupted == true then
		tooltip:AddSeparator(10)
		tooltip:AddLine(fontSizeBig, colorCodes.NEGATIVE .. "Corrupted", "FONTIN SC")
	end
end

local function addStatSetInfo(tooltip, build, gemInstance, grantedEffect, statSet, noLabel, index, levelRange)
	local fontSizeBig, fontSizeTitle = getFontSizes()
	local displayInstance = getDisplayInstance(gemInstance)
	local statSetLevel = statSet.levels[levelRange and gemInstance.level or displayInstance.level] or statSet.levels[1] or { }
	if not (index == 1 and statSet.label == grantedEffect.name) and statSet.label ~= "" and not noLabel then
		tooltip:AddSeparator(10)
		tooltip:AddLine(fontSizeTitle, colorCodes.GEM .. statSet.label, "FONTIN SC")
		tooltip:AddSeparator(10)
	end
	if statSetLevel.critChance then
		tooltip:AddLine(fontSizeBig, string.format("^x7F7F7FCritical Hit Chance: ^7%.2f%%", statSetLevel.critChance), "FONTIN SC")
	end
	if statSetLevel.baseMultiplier then
		tooltip:AddLine(fontSizeBig, string.format("^x7F7F7FAttack Damage: ^7%d%%", statSetLevel.baseMultiplier * 100), "FONTIN SC")
	end
	if build.data.describeStats then
		if not noLabel then tooltip:AddSeparator(10) end
		local stats
		if levelRange then
			-- Passive tree granted skills are not real gem instances, so show how their stats scale from level 1 to 20.
			local copiedInstance = copyTable(gemInstance, true)
			copiedInstance.quality = 0
			copiedInstance.level = 20
			local statsLevel20 = calcLib.buildSkillInstanceStats(copiedInstance, grantedEffect, statSet)
			copiedInstance.level = 1
			stats = calcLib.buildSkillInstanceStats(copiedInstance, grantedEffect, statSet)
			for statName, min in pairs(stats) do
				stats[statName] = { min = min, max = statsLevel20[statName] or min }
			end
		else
			stats = calcLib.buildSkillInstanceStats(displayInstance, grantedEffect, statSet)
		end
		local descriptions, lineMap = build.data.describeStats(stats, statSet.statDescriptionScope)
		for i, line in ipairs(descriptions) do
			addDescriptionLine(tooltip, build, statSet, line, lineMap[line], i)
		end
	end
end

local function addEffectStats(tooltip, build, gemInstance, grantedEffect, noLabel, levelRange)
	for idx, statSet in ipairs(grantedEffect.statSets) do
		addStatSetInfo(tooltip, build, gemInstance, grantedEffect, statSet, noLabel, idx, levelRange)
	end
end

local function addQualityRangeInfo(tooltip, build, grantedEffect, addedHeader)
	-- Quality ranges are tree-only. SkillsTab shows the 20 quality value separately, but tree nodes need the 0-20 range inline.
	if not grantedEffect.qualityStats or #grantedEffect.qualityStats == 0 then
		return addedHeader
	end
	local fontSizeBig = getFontSizes()
	local lineIndex = 1
	for _, stat in ipairs(grantedEffect.qualityStats) do
		if stat[1] and stat[2] then
			local stats = { [stat[1]] = 20 * stat[2] }
			local descriptions, lineMap = build.data.describeStats(stats, grantedEffect.statSets[1].statDescriptionScope, true)
			for _, line in ipairs(descriptions) do
				local statName = lineMap[line] or stat[1]
				if not addedHeader then
					tooltip:AddLine(fontSizeBig, "\n^7Additional Effects From Quality:", "FONTIN SC")
					addedHeader = true
				end
				-- Let StatDescriber format the real 20 quality value, then turn only the displayed value into a 0-20 quality range.
				line = line:gsub("([%+%-]?%d+%.?%d*)", function(value)
					local sign = value:sub(1, 1)
					if sign == "+" or sign == "-" then
						return sign .. "(0-" .. value:sub(2) .. ")"
					end
					return "(0-" .. value .. ")"
				end, 1)
				addDescriptionLine(tooltip, build, grantedEffect.statSets[1], line, statName, lineIndex)
				lineIndex = lineIndex + 1
			end
		end
	end
	return addedHeader
end

function GemTooltip.AddGemTooltip(tooltip, build, gemInstance, options)
	options = options or { }
	local fontSizeBig, fontSizeTitle = getFontSizes()
	local levelRange = options.levelRange
	tooltip.center = false
	tooltip.color = colorCodes.GEM
	tooltip.tooltipHeader = "GEM"
	tooltip.gemIcon = gemInstance.gemData.grantedEffect.icon
	tooltip.gemBackground = gemInstance.gemData.grantedEffect.id

	local grantedEffect = gemInstance.gemData.grantedEffect
	local additionalEffects = gemInstance.gemData.additionalGrantedEffects

	if grantedEffect.name:match("^Spectre:") or grantedEffect.name:match("^Companion:") then
		tooltip:AddLine(fontSizeTitle, colorCodes.GEM .. (gemInstance.displayEffect and gemInstance.displayEffect.nameSpec or gemInstance.gemData.name), "FONTIN SC")
	else
		tooltip:AddLine(fontSizeTitle, colorCodes.GEM .. "            " .. gemInstance.gemData.name, "FONTIN SC")
	end
	tooltip:AddLine(fontSizeBig, colorCodes.NORMAL .. "                   " .. gemInstance.gemData.gemType, "FONTIN SC")
	tooltip:AddSeparator(8)
	if gemInstance.gemData.tagString ~= "" then
		tooltip:AddLine(fontSizeBig, "^x7F7F7F" .. gemInstance.gemData.tagString, "FONTIN")
	end
	if gemInstance.gemData.gemFamily then
		tooltip:AddLine(fontSizeBig, "^x7F7F7FCategory: ^7" .. gemInstance.gemData.gemFamily, "FONTIN SC")
	end
	-- Default mode preserves the old GemSelectControl tooltip. levelRange is only for passive-tree granted skills.
	addGrantedEffectInfo(tooltip, build, gemInstance, grantedEffect, true, levelRange)
	addEffectStats(tooltip, build, gemInstance, grantedEffect, nil, levelRange)

	for _, additional in ipairs(additionalEffects or { }) do
		if not additional.support then
			if additional.name ~= "" then
				tooltip:AddSeparator(10)
				tooltip:AddLine(fontSizeTitle, colorCodes.GEM .. additional.name, "FONTIN SC")
			end
			tooltip:AddSeparator(10)
			addGrantedEffectInfo(tooltip, build, gemInstance, additional, nil, levelRange)
			addEffectStats(tooltip, build, gemInstance, additional, nil, levelRange)
		else
			addEffectStats(tooltip, build, gemInstance, additional, true, levelRange)
		end
	end

	if options.includeQualityRange then
		local addedHeader
		addedHeader = addQualityRangeInfo(tooltip, build, grantedEffect, addedHeader)
		for _, effect in ipairs(additionalEffects or { }) do
			addedHeader = addQualityRangeInfo(tooltip, build, effect, addedHeader)
		end
	end

	if grantedEffect.flavourText and main.showFlavourText then
		tooltip:AddSeparator(10)
		for _, line in ipairs(grantedEffect.flavourText) do
			tooltip:AddLine(fontSizeBig, colorCodes.UNIQUE .. line, "FONTIN SC ITALIC")
		end
	end
end

return GemTooltip
