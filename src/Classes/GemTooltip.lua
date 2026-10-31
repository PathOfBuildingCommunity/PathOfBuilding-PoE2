-- Path of Building
--
-- Module: Gem Tooltip
-- Shared renderer for gem-style tooltips.

local m_max = math.max
local m_min = math.min

local GemTooltip = { }

local function getFontSizes()
	return main.showFlavourText and 18 or 16, main.showFlavourText and 24 or 20
end

local function addDescriptionLine(tooltip, build, statSet, line, stat, index, colorCode)
	local fontSizeBig = getFontSizes()
	local source = statSet.statMap[stat] or build.data.skillStatMap[stat]
	local bg = (index % 2 == 0) and "GemHoverModBg" or nil
	if source then
		if launch.devModeAlt then
			local devText = stat
			local sourceMod = source[1] and copyTable(source[1].name and source[1] or source[1][1])
			if sourceMod then
				sourceMod.value = sourceMod.value or stat
				devText = modLib.formatMod(sourceMod)
			end
			line = line .. " ^2" .. devText
		end
		tooltip:AddLine(fontSizeBig, (colorCode or colorCodes.MAGIC) .. line, "FONTIN SC", bg)
	else
		if launch.devModeAlt then
			line = line .. " ^1" .. stat
		end
		line = colorCodes.UNSUPPORTED .. line
		line = main.notSupportedModTooltips and (line .. localisation:Field(main, 'notSupportedTooltipText')) or line
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
		tooltip:AddLine(fontSizeBig, colorCodes.GEMINFO .. localisation:Text("ui.gem_tooltip.add_granted_effect_info.tooltip_29", { tier = gemInstance.gemData.Tier }), "FONTIN SC")
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
			tooltip:AddLine(fontSizeBig, colorCodes.GEMINFO .. localisation:Text('ui.gem_tooltip.add_granted_effect_info.tooltip_30', { colour = colorCodes.MAGIC, level = totalLevel }), "FONTIN SC")
			tooltip:AddLine(fontSizeBig, "   ^7" .. localisation:Text("ui.gem_tooltip.add_granted_effect_info.tooltip_15", { level = gemInstance.level, value = ((gemInstance.level >= gemInstance.gemData.naturalMaxLevel and localisation:Ref("ui.gem_tooltip.add_granted_effect_info.tooltip_19")) or "") }), "FONTIN SC")
		else
			tooltip:AddLine(fontSizeBig, colorCodes.GEMINFO .. localisation:Text('ui.gem_tooltip.add_granted_effect_info.tooltip_20', { level = totalLevel, maximum = gemInstance.level >= gemInstance.gemData.naturalMaxLevel and localisation:Ref('ui.gem_tooltip.add_granted_effect_info.tooltip_19') or '' }), "FONTIN SC")
		end
		if corruptLevel > 0 then
			tooltip:AddLine(fontSizeBig, colorCodes.MAGIC .. localisation:Text("ui.gem_tooltip.add_granted_effect_info.tooltip_13", { corrupt_level = corruptLevel }), "FONTIN SC")
		elseif corruptLevel < 0 then
			tooltip:AddLine(fontSizeBig, colorCodes.MAGIC .. "   " .. localisation:Text("ui.gem_tooltip.add_granted_effect_info.tooltip_14", { corrupt_level = corruptLevel }), "FONTIN SC")
		end
		if totalGlobalLevels > 0 then
			tooltip:AddLine(fontSizeBig, colorCodes.MAGIC .. localisation:Text("ui.gem_tooltip.add_granted_effect_info.tooltip_16", { total_global_levels = totalGlobalLevels }), "FONTIN SC")
			if totalLevel - gemInstance.level - corruptLevel - totalGlobalLevels > 0 then
				tooltip:AddLine(fontSizeBig, colorCodes.MAGIC .. localisation:Text("ui.gem_tooltip.add_granted_effect_info.tooltip_17", { value = totalLevel - gemInstance.level - corruptLevel - totalGlobalLevels }), "FONTIN SC")
			end
		elseif totalLevel - gemInstance.level - corruptLevel > 0 then
			tooltip:AddLine(fontSizeBig, colorCodes.MAGIC .. localisation:Text("ui.gem_tooltip.add_granted_effect_info.tooltip_18", { value = totalLevel - gemInstance.level - corruptLevel }), "FONTIN SC")
		end
	end
	-- gem quality by type
	local isSupport = displayInstance.gemData?.gemType == "Support"
	if not levelRange and addReq and displayInstance.quality > 0 and not isSupport then
		local totalGlobalQuality = 0
		if displayInstance.gemPropertyInfo then
			for i, prop in ipairs(displayInstance.gemPropertyInfo) do
				if prop.value and prop.value.key == "quality" and prop.value.value then
					totalGlobalQuality = totalGlobalQuality + prop.value.value
				end
			end
		end
		totalGlobalQuality = math.floor(totalGlobalQuality)
		local gemQuality = gemInstance.quality
		if gemQuality > 0
		then
			tooltip:AddLine(fontSizeBig, colorCodes.GEMINFO .. localisation:Text("ui.gem_tooltip.add_granted_effect_info.tooltip_21", { magic = colorCodes.MAGIC, gem_quality = gemQuality }), "FONTIN SC")
		end
		if totalGlobalQuality > 0 then
			tooltip:AddLine(fontSizeBig, colorCodes.MAGIC .. localisation:Text("ui.gem_tooltip.add_granted_effect_info.tooltip_22", { total_global_quality = totalGlobalQuality }), "FONTIN SC")
		end
		local supportQuality = math.floor(displayInstance.quality) - totalGlobalQuality - gemQuality
		if supportQuality > 0 then
			tooltip:AddLine(fontSizeBig, colorCodes.MAGIC .. localisation:Text("ui.gem_tooltip.add_granted_effect_info.tooltip_23", { support_quality = supportQuality }), "FONTIN SC")
		end
	end
	if not levelRange and grantedEffect.support then
		if levelStats.manaMultiplier and levelStats.reservationMultiplier and levelStats.manaMultiplier == levelStats.reservationMultiplier then
			tooltip:AddLine(fontSizeBig, colorCodes.GEMINFO .. localisation:Text("ui.gem_tooltip.add_granted_effect_info.tooltip_11", { value = levelStats.manaMultiplier + 100 }), "FONTIN SC")
		elseif levelStats.reservationMultiplier then
			tooltip:AddLine(fontSizeBig, colorCodes.GEMINFO .. localisation:Text("ui.gem_tooltip.add_granted_effect_info.tooltip_25", { value = levelStats.reservationMultiplier + 100 }), "FONTIN SC")
		elseif levelStats.manaMultiplier then
			tooltip:AddLine(fontSizeBig, colorCodes.GEMINFO .. localisation:Text("ui.gem_tooltip.add_granted_effect_info.tooltip_10", { value = levelStats.manaMultiplier + 100 }), "FONTIN SC")
		end
		if levelStats.spiritReservationFlat then
			tooltip:AddLine(fontSizeBig, colorCodes.GEMINFO .. localisation:Text("ui.gem_tooltip.add_granted_effect_info.tooltip", { spirit_reservation_flat = levelStats.spiritReservationFlat }), "FONTIN SC")
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
			tooltip:AddLine(fontSizeBig, colorCodes.GEMINFO .. localisation:Text("ui.gem_tooltip.add_granted_effect_info.tooltip_26", { value = valueOrRange("spiritReservationFlat") }), "FONTIN SC")
		end
		if levelStats.spiritReservationPercent then
			tooltip:AddLine(fontSizeBig, colorCodes.GEMINFO .. localisation:Text("ui.gem_tooltip.add_granted_effect_info.tooltip_27", { value = valueOrRange("spiritReservationPercent", "%.1f") }), "FONTIN SC")
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
				cost = (cost and (cost .. ", ") or "") .. localisation:Field(res, 'ResourceString', { value = value })
			end
		end
		if cost then
			tooltip:AddLine(fontSizeBig, colorCodes.GEMINFO .. localisation:Text("ui.gem_tooltip.add_granted_effect_info.tooltip_9", { cost = cost }), "FONTIN SC")
		end
	end

	if levelStats.cooldown then
		local line
		if levelStats.storedUses and levelStats.storedUses > 1 then
			line = localisation:Text('skill.cooldown.with_uses', { duration = valueOrRange('cooldown', '%.2f'), uses = valueOrRange('storedUses') })
		else
			line = localisation:Text('skill.cooldown.duration', { duration = valueOrRange('cooldown', '%.2f') })
		end
		tooltip:AddLine(fontSizeBig, colorCodes.GEMINFO .. line, "FONTIN SC")
	end
	if levelStats.vaalStoredUses then
		tooltip:AddLine(fontSizeBig, localisation:Text("ui.gem_tooltip.add_granted_effect_info.tooltip_5", { vaal_stored_uses = levelStats.vaalStoredUses, value = levelStats.vaalStoredUses * levelStats.cost.Soul }), "FONTIN SC")
	end
	if levelStats.soulPreventionDuration then
		tooltip:AddLine(fontSizeBig, localisation:Text("ui.gem_tooltip.add_granted_effect_info.tooltip_28", { value = valueOrRange("soulPreventionDuration") }), "FONTIN SC")
	end
	if gemInstance.gemData.tags.attack then
		if levelStats.attackSpeedMultiplier then
			tooltip:AddLine(fontSizeBig, colorCodes.GEMINFO .. localisation:Text("ui.gem_tooltip.add_granted_effect_info.tooltip_3", { value = valueOrRange("attackSpeedMultiplier", nil, 100) }), "FONTIN SC")
		end
		if levelStats.attackTime then
			tooltip:AddLine(fontSizeBig, colorCodes.GEMINFO .. localisation:Text("ui.gem_tooltip.add_granted_effect_info.tooltip_4", { value = valueOrRange("attackTime", "%.2f", nil, 1000) }), "FONTIN SC")
		end
		if levelStats.baseMultiplier then
			tooltip:AddLine(fontSizeBig, colorCodes.GEMINFO .. localisation:Text("ui.gem_tooltip.add_granted_effect_info.tooltip_2", { value = valueOrRange("baseMultiplier", "%g", nil, nil, 100) }), "FONTIN SC")
		end
	elseif not grantedEffect.hidden then
		if (grantedEffect.castTime or 0) > 0 then
			tooltip:AddLine(fontSizeBig, colorCodes.GEMINFO .. localisation:Text("ui.gem_tooltip.add_granted_effect_info.tooltip_7", { cast_time = grantedEffect.castTime }), "FONTIN SC")
		else
			tooltip:AddLine(fontSizeBig, colorCodes.GEMINFO .. localisation:Text("ui.gem_tooltip.add_granted_effect_info.tooltip_6"), "FONTIN SC")
		end
	end
	if levelStats.critChance then
		tooltip:AddLine(fontSizeBig, colorCodes.GEMINFO .. localisation:Text("ui.gem_tooltip.add_granted_effect_info.tooltip_12", { value = valueOrRange("critChance", "%.2f") }), "FONTIN SC")
	end
	if not levelRange and addReq then
		local reqLevel = grantedEffect.levels[gemInstance.level] and grantedEffect.levels[gemInstance.level].levelRequirement or 1
		build:AddRequirementsToTooltip(tooltip, reqLevel,
			calcLib.getGemStatRequirement(reqLevel, gemInstance.gemData.reqStr, grantedEffect.support),
			calcLib.getGemStatRequirement(reqLevel, gemInstance.gemData.reqDex, grantedEffect.support),
			calcLib.getGemStatRequirement(reqLevel, gemInstance.gemData.reqInt, grantedEffect.support))
	end
	if gemInstance.gemData.weaponRequirements and not grantedEffect.hidden then
		tooltip:AddLine(fontSizeBig, localisation:Text("ui.gem_tooltip.add_granted_effect_info.tooltip_24", { weapon_requirements = localisation:Field(gemInstance.gemData, "weaponRequirements") }), "FONTIN SC")
	end
	tooltip.center = true
	if grantedEffect.description then
		tooltip:AddSeparator(10)
		tooltip:AddLine(fontSizeBig, colorCodes.GEMDESCRIPTION .. localisation:Field(grantedEffect, "description"), "FONTIN ITALIC")
	end
	if displayInstance.corrupted == true then
		tooltip:AddSeparator(10)
		tooltip:AddLine(fontSizeBig, colorCodes.NEGATIVE .. localisation:Text("ui.gem_tooltip.add_granted_effect_info.tooltip_8"), "FONTIN SC")
	end
end

local function addStatSetInfo(tooltip, build, gemInstance, grantedEffect, statSet, noLabel, index, levelRange)
	local fontSizeBig, fontSizeTitle = getFontSizes()
	local displayInstance = getDisplayInstance(gemInstance)
	local includeAltQualityStats = build.calcsTab.mainEnv.modDB:Flag(nil, "GemlingQuality")
	local statSetLevel = statSet.levels[levelRange and gemInstance.level or displayInstance.level] or statSet.levels[1] or { }
	if not (index == 1 and statSet.label == grantedEffect.name) and statSet.label ~= "" and not noLabel then
		tooltip:AddSeparator(10)
		tooltip:AddLine(fontSizeTitle, colorCodes.GEM .. localisation:Field(statSet, "label"), "FONTIN SC")
		tooltip:AddSeparator(10)
	end
	if statSetLevel.critChance then
		tooltip:AddLine(fontSizeBig, colorCodes.GEMINFO .. localisation:Text("ui.gem_tooltip.add_stat_set_info.tooltip_2", { crit_chance = statSetLevel.critChance }), "FONTIN SC")
	end
	if statSetLevel.baseMultiplier then
		tooltip:AddLine(fontSizeBig, colorCodes.GEMINFO .. localisation:Text("ui.gem_tooltip.add_stat_set_info.tooltip", { value = statSetLevel.baseMultiplier * 100 }), "FONTIN SC")
	end
	if build.data.describeStats then
		if not noLabel then tooltip:AddSeparator(10) end
		local stats
		if levelRange then
			-- Passive tree granted skills are not real gem instances, so show how their stats scale from level 1 to 20.
			local copiedInstance = copyTable(gemInstance, true)
			copiedInstance.quality = 0
			copiedInstance.level = 20
			local statsLevel20 = calcLib.buildSkillInstanceStats(copiedInstance, grantedEffect, statSet, includeAltQualityStats)
			copiedInstance.level = 1
			stats = calcLib.buildSkillInstanceStats(copiedInstance, grantedEffect, statSet, includeAltQualityStats)
			for statName, min in pairs(stats) do
				stats[statName] = { min = min, max = statsLevel20[statName] or min }
			end
		else
			stats = calcLib.buildSkillInstanceStats(displayInstance, grantedEffect, statSet, includeAltQualityStats)
		end
		local descriptions, lineMap = build.data.describeStats(stats, statSet.statDescriptionScope)
		local altQualityStatColor = { }
		if includeAltQualityStats then
			for _, stat in ipairs(grantedEffect.altQualityStats or { }) do
				altQualityStatColor[stat[1]] = colorCodes.ENCHANTED
			end
		end
		for i, line in ipairs(descriptions) do
			local stat = lineMap[line]
			addDescriptionLine(tooltip, build, statSet, line, stat, i, stat and altQualityStatColor[stat])
		end
	end
end

local function addEffectStats(tooltip, build, gemInstance, grantedEffect, noLabel, levelRange)
	for idx, statSet in ipairs(grantedEffect.statSets) do
		addStatSetInfo(tooltip, build, gemInstance, grantedEffect, statSet, noLabel, idx, levelRange)
	end
end

local function addQualityRangeInfo(tooltip, build, grantedEffect, addedHeader, includeAltQualityStats)
	-- Quality ranges are tree-only. SkillsTab shows the 20 quality value separately, but tree nodes need the 0-20 range inline.
	local qualityStats = { }
	for _, stat in ipairs(grantedEffect.qualityStats or { }) do
		qualityStats[#qualityStats + 1] = { stat = stat[1], value = stat[2], statSetIndexes = stat[3], color = colorCodes.MAGIC }
	end
	if includeAltQualityStats then
		for _, stat in ipairs(grantedEffect.altQualityStats or { }) do
			qualityStats[#qualityStats + 1] = { stat = stat[1], value = stat[2], statSetIndexes = stat[3], color = colorCodes.ENCHANTED }
		end
	end
	if #qualityStats == 0 then
		return addedHeader
	end
	local fontSizeBig = getFontSizes()
	local lineIndex = 1
	for _, stat in ipairs(qualityStats) do
		if stat.stat and stat.value then
			local stats = { [stat.stat] = 20 * stat.value }
			local statSet = grantedEffect.statSets[(stat.statSetIndexes[1] or 0) + 1] or grantedEffect.statSets[1]
			local descriptions, lineMap = build.data.describeStats(stats, statSet.statDescriptionScope, true, function(value, index, firstNumber)
				if not firstNumber then return value end
				local sign = value:sub(1, 1)
				if sign == '+' or sign == '-' then return sign .. '(0-' .. value:sub(2) .. ')' end
				return '(0-' .. value .. ')'
			end)
			for _, line in ipairs(descriptions) do
				local statName = lineMap[line] or stat.stat
				if not addedHeader then
					tooltip:AddLine(fontSizeBig, localisation:Text("ui.gem_tooltip.add_quality_range_info.tooltip"), "FONTIN SC")
					addedHeader = true
				end
				addDescriptionLine(tooltip, build, statSet, line, statName, lineIndex, stat.color)
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
	tooltip.minWidth = 600
	tooltip.maxWidth = m_min(tooltip.maxWidth or 600, 600)
	tooltip.tooltipHeader = "GEM"
	tooltip.gemIcon = gemInstance.gemData.grantedEffect.icon
	tooltip.gemBackground = gemInstance.gemData.grantedEffect.id

	local grantedEffect = gemInstance.gemData.grantedEffect
	local additionalEffects = gemInstance.gemData.additionalGrantedEffects

	if grantedEffect.isLineage then
		tooltip.isUniqueGem = true
	end

	local iconNameIndent = "            "
	local iconTagIndent = "                  "
	if grantedEffect.support then
		iconNameIndent = "    "
	 	iconTagIndent = "      "
	end

	if grantedEffect.name:match("^Spectre:") or grantedEffect.name:match("^Companion:") then
		tooltip:AddLine(fontSizeTitle, colorCodes.GEM .. iconNameIndent .. (gemInstance.displayEffect and gemInstance.displayEffect.nameSpec or localisation:Field(gemInstance.gemData, "name")), "FONTIN SC")
	else
		tooltip:AddLine(fontSizeTitle, colorCodes.GEM .. iconNameIndent .. localisation:Field(gemInstance.gemData, "name"), "FONTIN SC")
	end
	tooltip:AddLine(fontSizeBig, colorCodes.GEMINFO .. iconTagIndent .. localisation:Field(gemInstance.gemData, "gemType"), "FONTIN SC")
	tooltip:AddSeparator(8)
	if grantedEffect.legacy then
		tooltip:AddLine(fontSizeBig, colorCodes.WARNING .. localisation:Text("ui.gem_tooltip.add_gem_tooltip.tooltip_3"), "FONTIN SC")
		tooltip:AddLine(fontSizeBig, colorCodes.WARNING .. localisation:Text("ui.gem_tooltip.add_gem_tooltip.tooltip_2"), "FONTIN SC")
	end
	if gemInstance.gemData.tagString ~= "" then
		tooltip:AddLine(fontSizeBig, "   ^x7F7F7F" .. localisation:Field(gemInstance.gemData, "tagString"), "FONTIN")
	end
	if gemInstance.gemData.gemFamily then
		tooltip:AddLine(fontSizeBig, colorCodes.GEMINFO .. localisation:Text("ui.gem_tooltip.add_gem_tooltip.tooltip", { gem_family = localisation:Field(gemInstance.gemData, "gemFamily") }), "FONTIN SC")
	end
	-- Default mode preserves the old GemSelectControl tooltip. levelRange is only for passive-tree granted skills.
	addGrantedEffectInfo(tooltip, build, gemInstance, grantedEffect, true, levelRange)
	addEffectStats(tooltip, build, gemInstance, grantedEffect, nil, levelRange)

	for _, additional in ipairs(additionalEffects or { }) do
		if not additional.support then
			if additional.name ~= "" then
				tooltip:AddSeparator(10)
				tooltip:AddLine(fontSizeTitle, colorCodes.GEM .. localisation:Field(additional, "name"), "FONTIN SC")
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
		local includeAltQualityStats = build.calcsTab.mainEnv.modDB:Flag(nil, "GemlingQuality")
		addedHeader = addQualityRangeInfo(tooltip, build, grantedEffect, addedHeader, includeAltQualityStats)
		for _, effect in ipairs(additionalEffects or { }) do
			addedHeader = addQualityRangeInfo(tooltip, build, effect, addedHeader, includeAltQualityStats)
		end
	end

	if grantedEffect.flavourText and main.showFlavourText then
		tooltip:AddSeparator(10)
		for index, line in ipairs(grantedEffect.flavourText) do
			tooltip:AddLine(fontSizeBig, colorCodes.UNIQUE .. localisation:Line(grantedEffect, 'flavourText', index, line), "FONTIN SC ITALIC")
		end
	end
	if options.includeBuildPlannerNote then
		tooltip:AddSeparator(10)
		tooltip:AddLine(14, colorCodes.TIP .. localisation:Text("ui.gem_tooltip.add_gem_tooltip.tooltip_4"))
		if gemInstance.note and gemInstance.note ~= "" then
			tooltip:AddBuildPlannerNote(14, gemInstance.note, "^7" .. localisation:Text("build_note.prefix"))
		end
	end
end

return GemTooltip
