local skillTypeMap = { }
for row in dat("ActiveSkillType"):Rows() do
	table.insert(skillTypeMap, row.Id)
end


-- This is here to fix name collisions like in the case of Barrage
local fullNameGems = {
	["Metadata/Items/Gems/SupportGemBarrage"] = true,
}

local function mapAST(ast)
	return "SkillType."..(skillTypeMap[ast._rowIndex] or ("Unknown"..ast._rowIndex))
end

local function cleanAndSplit(str) -- Same as in Flavour Text exporter.
	-- Normalize newlines
	str = str:gsub("\r\n", "\n")

	local lines = {}
	for line in str:gmatch("[^\n]+") do
		line = line:match("^%s*(.-)%s*$") -- trim each line
		if line ~= "" then
			-- Escape quotes
			line = line:gsub('"', '\\"')
			table.insert(lines, line)
		end
	end

	return lines
end

local weaponClassMap = {
	["Claw"] = "Claw",
	["Dagger"] = "Dagger",
	["One Hand Sword"] = "One Handed Sword",
	["Thrusting One Hand Sword"] = "Thrusting One Handed Sword",
	["One Hand Axe"] = "One Handed Axe",
	["One Hand Mace"] = "One Handed Mace",
	["Bow"] = "Bow",
	["Crossbow"] = "Crossbow",
	["Fishing Rod"] = "Fishing Rod",
	["Warstaff"] = "Staff",
	["Two Hand Sword"] = "Two Handed Sword",
	["Two Hand Axe"] = "Two Handed Axe",
	["Two Hand Mace"] = "Two Handed Mace",
	["Unarmed"] = "None",
	["Flail"] = "Flail",
	["Spear"] = "Spear",
}

local gems = { }
local trueGemNames = { }

local directiveTable = { }

local whiteListStat = {
	["is_area_damage"] = true,
}
local loadedStatDescriptionLua = { }
function checkModInStatDescription(statDescription, line)
	if whiteListStat[line] then
		return true
	end

	local searchIn = statDescription
	local stat

	repeat
		if loadedStatDescriptionLua[searchIn] then
			stat = loadedStatDescriptionLua[searchIn]
		else
			local errMsg, newStat
			errMsg, newStat = PLoadModule("../Data/StatDescriptions/"..searchIn..".lua")
			if errMsg then
				errMsg, newStat = PLoadModule("../Data/StatDescriptions/Specific_Skill_Stat_Descriptions/"..searchIn..".lua")

				if errMsg then
					ConPrintf("Error loading stat description: %s", errMsg)
					return false
				end
			end

			loadedStatDescriptionLua[searchIn] = newStat
			stat = newStat
		end

		if stat and stat[line] then
			return true
		end

		if stat and stat.parent then
			searchIn = stat.parent
		else
			searchIn = ""
		end
	until searchIn == ""

	return false
end

-- #noGem
-- Disables the gem component of the next skill
directiveTable.noGem = function(state, args, out)
	state.noGem = true
end

-- #addSkillTypes <flag>[ <flag>[...]]
-- skill types to be added to the skillTypes flags for this active skill
directiveTable.addSkillTypes = function(state, args, out)
	state.addSkillTypes = {}
	for flag in args:gmatch("%a+") do
		table.insert(state.addSkillTypes, flag)
	end
end

-- #skill <GrantedEffectId> [<Display name>]
-- Initialises the skill data and emits the skill header
directiveTable.skill = function(state, args, out)
	local grantedId, displayName = args:match("(%w+) (.+)")
	if not grantedId then
		grantedId = args
		displayName = args
	end
	state.infoGrantedId = grantedId
	out:write('skills["', grantedId, '"] = {\n')
	local granted = dat("GrantedEffects"):GetRow("Id", grantedId)
	if not granted then
		ConPrintf('Unknown GE: "'..grantedId..'"')
		return
	end
	local gemEffect = dat("GemEffects"):GetRow("GrantedEffect", granted)
	local secondaryEffect
	if not gemEffect then
		gemEffect = dat("GemEffects"):GetRow("AdditionalGrantedEffects", granted)
		if gemEffect then 
			secondaryEffect = true
		end
	end
	local skillGem
	local gemColor
	if gemEffect then
		for gem in dat("SkillGems"):Rows() do
			for _, variant in ipairs(gem.GemEffects) do
				if gem.Str >= 50 then
					gemColor = 1
				elseif gem.Int >= 50 then
					gemColor = 3
				elseif gem.Dex >= 50 then
					gemColor = 2
				else
					gemColor = 4
				end
				if gemEffect.Id == variant.Id then
					skillGem = gem
					local trueGemNameObj = dat("GemEffects"):GetRow("Id", gemEffect.Id)
					if trueGemNameObj.Name ~= "" then
						trueGemNames[gemEffect.Id] = trueGemNameObj.Name
					end
					break
				end
			end
			if skillGem then break end
		end
	end
	local skill = { }
	state.skill = skill
	state.granted = granted
	if skillGem and not state.noGem then
		gems[gemEffect.Id] = true
		if granted.IsSupport then
			skill.displayName = fullNameGems[skillGem.BaseItemType.Id] and skillGem.BaseItemType.Name or skillGem.BaseItemType.Name:gsub(" Support", "")
			out:write('\tname = "', skill.displayName, '",\n')
			if #gemEffect.Description > 0 then
				out:write('\tdescription = "', escapeGGGString(gemEffect.Description:gsub('"','\\"'):gsub('\r',''):gsub('\n','\\n')), '",\n')
			end
		else
			skill.displayName = secondaryEffect and granted.ActiveSkill.DisplayName or trueGemNames[gemEffect.Id] or granted.ActiveSkill.DisplayName
			out:write('\tname = "', skill.displayName, '",\n')
			-- Hybrid gems (e.g. Vaal gems) use the display name of the active skill e.g. Vaal Summon Skeletons of Sorcery
			out:write('\tbaseTypeName = "', granted.ActiveSkill.DisplayName, '",\n')
		end
	else
		if displayName == args and not granted.IsSupport then
			displayName = gemEffect and trueGemNames[gemEffect.Id] or granted.ActiveSkill.DisplayName
		end
		skill.displayName = displayName
		out:write('\tname = "', displayName, '",\n')
		out:write('\thidden = true,\n')
	end
	if state.fromSpec then
		out:write('\tfrom' .. state.fromSpec:gsub("^%l", string.upper) .. ' = true,\n')
	end
	if state.minionList then
		out:write('\tminionList = {\n')
		for _, minion in ipairs(state.minionList) do
			out:write('\t\t"', minion, '",\n')
		end
		out:write('\t},\n')
	end
	state.noGem = false
	skill.baseFlags = { }
	skill.baseStatRow = { }
	skill.baseGrantedEffectStatSet = { }
	skill.levels = { }
	skill.sets = { }
	skill.setIndex = 1
	skill.addSkillTypes = state.addSkillTypes
	state.addSkillTypes = nil
	if skillGem and not state.noGem then
		out:write('\tcolor = ', gemColor, ',\n')
	end
	local nextGemLevelReqValue = 0
	local perLevel = dat("GrantedEffectsPerLevel"):GetRowList("GrantedEffect", granted)
	local statsPerLevel = dat("GrantedEffectStatSetsPerLevel"):GetRowList("GrantedEffect", granted)
	local gemLevelProgression = nil
	if skillGem and not state.noGem then
		gemLevelProgression = dat("ItemExperiencePerLevel"):GetRowList("ItemExperienceType", skillGem.GemLevelProgression)
	end
	for indx = 1, #perLevel do
		local levelRow = perLevel[indx]
		local statRow = statsPerLevel[indx]
		skill.baseStatRow[indx] = statRow
		local level = { extra = { }, cost = { } }
		level.level = levelRow.Level
		level.extra.levelRequirement = math.max(gemLevelProgression and gemLevelProgression[indx] and gemLevelProgression[indx].PlayerLevel or 0, nextGemLevelReqValue)
		nextGemLevelReqValue = level.extra.levelRequirement
		for i, cost in ipairs(granted.CostType) do
			level.cost[cost["Resource"]] = levelRow.CostAmounts[i]
		end
		if levelRow.SpiritReservation ~= 0 then
			level.extra.spiritReservationFlat = levelRow.SpiritReservation
		end
		if levelRow.ReservationMultiplier ~= 100 then
			level.extra.reservationMultiplier = levelRow.ReservationMultiplier - 100
		end
		--if levelRow.ManaReservationFlat ~= 0 then
		--	level.extra.manaReservationFlat = levelRow.ManaReservationFlat
		--end
		--if levelRow.ManaReservationPercent ~= 0 then
		--	level.extra.manaReservationPercent = levelRow.ManaReservationPercent / 100
		--end
		--if levelRow.LifeReservationFlat ~= 0 then
		--	level.extra.lifeReservationFlat = levelRow.LifeReservationFlat
		--end
		--if levelRow.LifeReservationPercent ~= 0 then
		--	level.extra.lifeReservationPercent = levelRow.LifeReservationPercent / 100
		--end
		if levelRow.CostMultiplier ~= 100 then
			level.extra.manaMultiplier = levelRow.CostMultiplier - 100
		end
		if levelRow.AttackSpeedMultiplier and levelRow.AttackSpeedMultiplier ~= 0 then
			level.extra.attackSpeedMultiplier = levelRow.AttackSpeedMultiplier
		end
		if levelRow.AttackTime ~= 0 then
			level.extra.attackTime = levelRow.AttackTime
		end
		if levelRow.Cooldown and levelRow.Cooldown ~= 0 then
			level.extra.cooldown = levelRow.Cooldown / 1000
		end
		if levelRow.PvPDamageMultiplier ~= 0 then
			level.extra.PvPDamageMultiplier = levelRow.PvPDamageMultiplier
		end
		if levelRow.StoredUses ~= 0 then
			level.extra.storedUses = levelRow.StoredUses
		end
		if statRow and statRow.AttackCritChance ~= 0 then
			level.extra.critChance = statRow.AttackCritChance / 100
		end
		if statRow and statRow.OffhandCritChance ~= 0 then
			level.extra.critChance = statRow.OffhandCritChance / 100
		end
		if statRow and statRow.BaseMultiplier and statRow.BaseMultiplier ~= 0 then
			level.extra.baseMultiplier = statRow.BaseMultiplier / 10000 + 1
		end
		if levelRow.VaalSouls ~= 0 then
			level.cost.Soul = levelRow.VaalSouls
		end
		if levelRow.VaalStoredUses ~= 0 then
			level.extra.vaalStoredUses = levelRow.VaalStoredUses
		end
		if levelRow.SoulGainPreventionDuration ~= 0 then
			level.extra.soulPreventionDuration = levelRow.SoulGainPreventionDuration / 1000
		end
		-- stat based level info
		--if statRow.DamageEffectiveness ~= 0 then
		--	level.extra.damageEffectiveness = statRow.DamageEffectiveness / 10000 + 1
		--end
		table.insert(skill.levels, level)
	end
	if not (skillGem and granted.IsSupport) then
		skill.qualityStats = { }
		local qualityStats = dat("GrantedEffectQualityStats"):GetRow("GrantedEffect", granted)
		if qualityStats and qualityStats.GrantedStats then
			for i, stat in ipairs(qualityStats.GrantedStats) do
				table.insert(skill.qualityStats, { stat.Id, qualityStats.StatValues[i] / 1000 })
				--ConPrintf("[%d] %s %s", i, granted.ActiveSkill.DisplayName, stat.Id)
			end
		end
	end
	if granted.IsSupport then
		skill.isSupport = true
		out:write('\tsupport = true,\n')
		out:write('\trequireSkillTypes = { ')
		for _, type in ipairs(granted.SupportTypes) do
			out:write(mapAST(type), ', ')
		end
		out:write('},\n')
		out:write('\taddSkillTypes = { ')
		skill.isTrigger = false
		for _, type in ipairs(granted.AddTypes) do
			local typeString = mapAST(type)
			if typeString == "SkillType.Triggered" then
				skill.isTrigger = true
			end
			out:write(typeString, ', ')
		end
		out:write('},\n')
		out:write('\texcludeSkillTypes = { ')
		for _, type in ipairs(granted.ExcludeTypes) do
			out:write(mapAST(type), ', ')
		end
		out:write('},\n')
		if skillGem then
			local gemFamily = { }
			local supportGem = dat("SupportGems"):GetRow("SkillGem", dat("SkillGems"):GetRow("BaseItemType", dat("BaseItemTypes"):GetRow("Id", skillGem.BaseItemType.Id)))
			for _, type in ipairs(supportGem.Family) do
				table.insert(gemFamily, type.Id)
			end
			if next(gemFamily) then
				out:write('\tgemFamily = { ')
				for _, type in ipairs(gemFamily) do
					out:write('"', type, '",')
				end
				out:write('},\n')
			end
			if supportGem.Lineage then
				out:write('\tisLineage = true,\n')
				if supportGem.FlavourText then
					out:write('\tflavourText = {')
					for _, line in ipairs(cleanAndSplit(supportGem.FlavourText.Text)) do
						out:write('"', line, '", ')
					end
					out:write('},\n')
				end
			end
		end
		if skill.isTrigger then
			out:write('\tisTrigger = true,\n')
		end
		if granted.SupportGemsOnly then
			out:write('\tsupportGemsOnly = true,\n')
		end
		if granted.IgnoreMinionTypes then
			out:write('\tignoreMinionTypes = true,\n')
		end
		local weaponTypes = { }
		if granted.WeaponRestrictions[1] then
			for _, class in ipairs(granted.WeaponRestrictions[1].WeaponClass) do
				if weaponClassMap[class.ItemClass.Id] then
					weaponTypes[weaponClassMap[class.ItemClass.Id]] = true
				end
			end
		end
		if next(weaponTypes) then
			out:write('\tweaponTypes = {\n')
			for type in pairs(weaponTypes) do
				out:write('\t\t["', type, '"] = true,\n')
			end
			out:write('\t},\n')
		end
	else
		if #granted.ActiveSkill.Description > 0 then
			out:write('\tdescription = "', escapeGGGString(granted.ActiveSkill.Description:gsub('"','\\"'):gsub('\r',''):gsub('\n','\\n')), '",\n')
		end
		out:write('\tskillTypes = { ')
		for _, type in ipairs(granted.ActiveSkill.SkillTypes) do
			out:write('[', mapAST(type), '] = true, ')
		end
		if skill.addSkillTypes then
			for _, type in ipairs(skill.addSkillTypes) do
				out:write('[SkillType.', type , '] = true, ')
			end
		end
		out:write('},\n')
		if granted.ActiveSkill.MinionSkillTypes[1] then
			out:write('\tminionSkillTypes = { ')
			for _, type in ipairs(granted.ActiveSkill.MinionSkillTypes) do
				out:write('[', mapAST(type), '] = true, ')
			end
			out:write('},\n')
		end
		local weaponTypes = { }
		if granted.ActiveSkill.WeaponRestrictions then
			for _, class in ipairs(granted.ActiveSkill.WeaponRestrictions.WeaponClass) do
				if weaponClassMap[class.ItemClass.Id] then
					weaponTypes[weaponClassMap[class.ItemClass.Id]] = true
				end
			end
		end
		if next(weaponTypes) then
			out:write('\tweaponTypes = {\n')
			for type in pairs(weaponTypes) do
				out:write('\t\t["', type, '"] = true,\n')
			end
			out:write('\t},\n')
		end
		if granted.ActiveSkill.SkillTotem < 25 then
			out:write('\tskillTotemId = ', granted.ActiveSkill.SkillTotem, ',\n')
		end
		out:write('\tcastTime = ', granted.CastTime / 1000, ',\n')
		if granted.CannotBeSupported then
			out:write('\tcannotBeSupported = true,\n')
		end
	end
	if skill.qualityStats then
		out:write('\tqualityStats = {\n')
		for _, stat in ipairs(skill.qualityStats) do
			out:write('\t\t{ "', stat[1], '", ', stat[2], ' },\n')
		end
		out:write('\t},\n')
	end
	out:write('\tlevels = {\n')
	for _, level in ipairs(skill.levels) do
		out:write('\t\t[', level.level, '] = { ')
		for _, statVal in ipairs(level) do
			out:write(tostring(statVal), ', ')
		end
		for k, v in pairs(level.extra) do
			out:write(k, ' = ', tostring(v), ', ')
		end
		if level.actorLevel ~= nil then
			out:write('actorLevel = ', level.actorLevel, ', ')
		end
		if next(level.cost) ~= nil then
			out:write('cost = { ')
			for k, v in pairs(level.cost) do
				out:write(k, ' = ', tostring(v), ', ')
			end
			out:write('}, ')
		end
		out:write('},\n')
	end
	out:write('\t},\n')
end

directiveTable.skillEnd = function(state, args, out)
	if next(state.skill.sets) ~= nil then
		out:write('\t}\n')
	end
	out:write('}')
	state.skill = nil
	state.fromSpec = nil
	state.minionList = nil
end

-- #set <GrantedEffectStatSetsId>
-- Initialises the statSet data and emits information pertaining to statSet 
directiveTable.set = function(state, args, out)
	local statSetId = args
	local originalGrantedEffectStatSet = dat("GrantedEffectStatSets"):GetRow("Id", statSetId)
	if dat("GrantedEffectStatSetsPerLevel"):GetRowList("GrantedEffectStatSets", originalGrantedEffectStatSet) == nil or originalGrantedEffectStatSet == nil then
		ConPrintf(args.." is not a valid Granted Effect")
	end
	local grantedEffectStatSet = copyTableSafe(originalGrantedEffectStatSet, false, true)
	local statsPerLevel = copyTableSafe(dat("GrantedEffectStatSetsPerLevel"):GetRowList("GrantedEffectStatSets", originalGrantedEffectStatSet), false, true)
	local label = grantedEffectStatSet.LabelType and grantedEffectStatSet.LabelType.Label or state.skill.displayName
	local set = { }
	local skill = state.skill
	if next(skill.sets) == nil then
		out:write('\tstatSets = {\n')
	end
	skill.sets[args] = set
	state.set = set
	set.baseFlags = { }
	set.mods = { }
	set.levels = { }
	set.stats = { }
	set.CannotGrantToMinion = { }
	set.constantStats = { }
	set.removeStats = { }
	for k, v in pairs(grantedEffectStatSet.RemoveStats) do
		set.removeStats[k] = v.Id
	end

	if state.skill.setIndex == 1 then
		skill.baseGrantedEffectStatSet = grantedEffectStatSet
	else
		-- For stat sets after the first we merge the base set with the current set
		grantedEffectStatSet.ImplicitStats = tableConcat(skill.baseGrantedEffectStatSet.ImplicitStats, grantedEffectStatSet.ImplicitStats)
		grantedEffectStatSet.ConstantStats = tableConcat(skill.baseGrantedEffectStatSet.ConstantStats, grantedEffectStatSet.ConstantStats)
		grantedEffectStatSet.ConstantStatsValues = tableConcat(skill.baseGrantedEffectStatSet.ConstantStatsValues, grantedEffectStatSet.ConstantStatsValues)
	end
	
	local statMap = { }
	local statMapOrder = {}

	for indx = 1, #statsPerLevel do
		local statRow = statsPerLevel[indx]
		local baseStatRow = skill.baseStatRow[indx]
		local level = { extra = { }, statInterpolation = { }, actorLevel = 1 } 
		level.level = statRow.GemLevel
		-- stat based level info
		if state.skill.setIndex ~= 1 and statRow.AttackCritChance ~= 0 then
			level.extra.critChance = (baseStatRow.AttackCritChance + statRow.AttackCritChance) / 100
		end
		if state.skill.setIndex ~= 1 and statRow.OffhandCritChance ~= 0 then
			level.extra.critChance = (baseStatRow.OffhandCritChance + statRow.OffhandCritChance) / 100
		end
		-- If UseSetAttackMulti is true, then take the multi from the stat set, otherwise add the value from base set and current set
		if state.skill.setIndex ~= 1 and grantedEffectStatSet.UseSetAttackMulti and statRow.BaseMultiplier and statRow.BaseMultiplier ~= 0 then
			level.extra.baseMultiplier = statRow.BaseMultiplier / 10000 + 1
		elseif state.skill.setIndex ~= 1 and not grantedEffectStatSet.UseSetAttackMulti and statRow.BaseMultiplier and statRow.BaseMultiplier ~= 0 then
			if skill.levels[indx].extra.baseMultiplier then
				level.extra.baseMultiplier = skill.levels[indx].extra.baseMultiplier + statRow.BaseMultiplier / 10000
			end
			level.extra.baseMultiplier = statRow.BaseMultiplier / 10000 + 1
		end
		if state.skill.setIndex ~= 1 then
			-- For stat sets after the first we merge the base set with the current set
			statRow.BaseResolvedValues = tableConcat(baseStatRow.BaseResolvedValues, statRow.BaseResolvedValues)
			statRow.FloatStats = tableConcat(baseStatRow.FloatStats, statRow.FloatStats)
			statRow.FloatStatsValues = tableConcat(baseStatRow.FloatStatsValues, statRow.FloatStatsValues)
			statRow.StatInterpolations = tableConcat(baseStatRow.StatInterpolations, statRow.StatInterpolations)
			statRow.InterpolationBases = tableConcat(baseStatRow.InterpolationBases, statRow.InterpolationBases)
			statRow.AdditionalStats = tableConcat(baseStatRow.AdditionalStats, statRow.AdditionalStats)
			statRow.AdditionalStatsValues = tableConcat(baseStatRow.AdditionalStatsValues, statRow.AdditionalStatsValues)
			statRow.BaseStats = tableConcat(tableConcat(tableConcat(skill.baseGrantedEffectStatSet.ImplicitStats, skill.baseGrantedEffectStatSet.ConstantStats), baseStatRow.FloatStats), baseStatRow.AdditionalStats)
		end
		level.statInterpolation = statRow.StatInterpolations
		level.actorLevel = statRow.ActorLevel
		local tempRemoveStats = copyTable(set.removeStats, true)
		for i, removeStat in pairs(set.removeStats) do
			-- Fixes the case where a removeStat does not exist in the base set but does in future sets
			-- It should not be removed if this is the case
			local remove = false
			for _, stat in ipairs(statRow.BaseStats) do
				if stat.Id == removeStat then
					remove = true
				end
			end
			if remove == false then
				table.remove(tempRemoveStats, i)
				table.remove(set.removeStats, i)
			end
		end
		local resolveInterpolation = true
		local injectConstantValuesIntoEachLevel = false
		local statMapOrderIndex = 1
		for i, stat in ipairs(statRow.FloatStats) do
			for k, v in pairs(tempRemoveStats) do
				if stat.Id == v then
					statRow.BaseResolvedValues[i] = 0 -- Set the removed stat value to zero, but would be better if we could remove the value and the corresponding statInterpolation value too
					table.remove(tempRemoveStats, k) -- Only remove the first stat which will be from the copied base set and not the current set
					break
				end
			end
			if not statMap[stat.Id] or indx == 1 then
				statMap[stat.Id] = #set.stats + 1
				table.insert(set.stats, { id = stat.Id })
				if indx == 1 then
					table.insert(statMapOrder, stat.Id)
					if stat.CannotGrantToMinion and not isValueInTable(set.CannotGrantToMinion, stat.Id) then
						table.insert(set.CannotGrantToMinion, stat.Id)
					end
				else
					print(label .. ": stat missing from earlier levels: ".. stat.Id)
				end
			elseif statMapOrder[statMapOrderIndex] ~= stat.Id then
				-- add missing stats
				while statMapOrderIndex < #statMapOrder and statMapOrder[statMapOrderIndex] ~= stat.Id do
					table.insert(level, 0)
					if #level.statInterpolation < #statMapOrder then
						table.insert(level.statInterpolation, statMapOrderIndex, "0")
					end
					statMapOrderIndex = statMapOrderIndex + 1
				end
			end
			if resolveInterpolation and #statsPerLevel > 5 then -- Don't resolve values for minion skills as it will break them
				table.insert(level, statRow.BaseResolvedValues[i])
				if state.skill.setIndex ~= 1 then
					-- Modify the correct statInterpolation value in the current set by offsetting the value from the count in the base set
					level.statInterpolation[#level] = 1
				else
					level.statInterpolation[statMapOrderIndex] = 1
				end
			else
				table.insert(level, statRow.FloatStatsValues[i] / math.max(statRow.InterpolationBases[i].Value, 0.00001) )
			end
			statMapOrderIndex = statMapOrderIndex + 1
		end
		if injectConstantValuesIntoEachLevel then
			for i, stat in ipairs(grantedEffectStatSet.ConstantStats) do
				if not statMap[stat.Id] or indx == 1 then
					statMap[stat.Id] = #set.stats + #set.constantStats + 1
					table.insert(set.stats, { id = stat.Id })
					if indx == 1 then
						table.insert(statMapOrder, stat.Id)
						if stat.CannotGrantToMinion and not isValueInTable(set.CannotGrantToMinion, stat.Id) then
							table.insert(set.CannotGrantToMinion, stat.Id)
						end
					else
						print(label .. ": stat missing from earlier levels: ".. stat.Id)
					end
				elseif statMapOrder[statMapOrderIndex] ~= stat.Id then
					-- add missing stats
					while statMapOrderIndex < #statMapOrder and statMapOrder[statMapOrderIndex] ~= stat.Id do
						table.insert(level, 0)
						if #level.statInterpolation < #statMapOrder then
							table.insert(level.statInterpolation, statMapOrderIndex, "0")
						end
						statMapOrderIndex = statMapOrderIndex + 1
					end
				end
				statMapOrderIndex = statMapOrderIndex + 1
				table.insert(level, grantedEffectStatSet.ConstantStatsValues[i])
				table.insert(level.statInterpolation, #statRow.FloatStats + 1, 1)
			end
		end
		for i, stat in ipairs(statRow.AdditionalStats) do
			for k, v in pairs(tempRemoveStats) do
				if stat.Id == v then
					statRow.AdditionalStatsValues[i] = 0 -- Set the removed stat value to zero, but would be better if we could remove the value and the corresponding statInterpolation value too
					table.remove(tempRemoveStats, k) -- Only remove the first stat which will be from the copied base set and not the current set
					break
				end
			end
			if not statMap[stat.Id] or indx == 1 then
				statMap[stat.Id] = #set.stats + 1
				table.insert(set.stats, { id = stat.Id })
				if indx == 1 then
					table.insert(statMapOrder, stat.Id)
					if stat.CannotGrantToMinion and not isValueInTable(set.CannotGrantToMinion, stat.Id) then
						table.insert(set.CannotGrantToMinion, stat.Id)
					end
				else
					print(label .. ": stat missing from earlier levels: ".. stat.Id)
				end
			elseif statMapOrder[statMapOrderIndex] ~= stat.Id then
				-- add missing stats
				while statMapOrderIndex < #statMapOrder and statMapOrder[statMapOrderIndex] ~= stat.Id do
					table.insert(level, 0)
					if #level.statInterpolation < #statMapOrder then
						table.insert(level.statInterpolation, statMapOrderIndex, "0")
					end
					statMapOrderIndex = statMapOrderIndex + 1
				end
			end
			table.insert(level, statRow.AdditionalStatsValues[i])
			level.statInterpolation[statMapOrderIndex] = 1
			statMapOrderIndex = statMapOrderIndex + 1
		end
		for i, stat in ipairs(statRow.AdditionalBooleanStats) do
			local copy = true
			for k, v in pairs(tempRemoveStats) do
				if stat.Id == v then
					copy = false
					table.remove(tempRemoveStats, k)
					break
				end
			end
			if copy then
				if not statMap[stat.Id] then
					statMap[stat.Id] = #set.stats + 1
					table.insert(set.stats, { id = stat.Id })
					if stat.CannotGrantToMinion and not isValueInTable(set.CannotGrantToMinion, stat.Id) then
						table.insert(set.CannotGrantToMinion, stat.Id)
					end
				end
			end
		end
		table.insert(set.levels, level)
	end
	if grantedEffectStatSet and grantedEffectStatSet.ImplicitStats then
		for i, stat in ipairs(grantedEffectStatSet.ImplicitStats) do
			local copy = true
			for k, v in pairs(set.removeStats) do
				if stat.Id == v then
					copy = false
					table.remove(set.removeStats, k)
					break
				end
			end
			if copy then
				if not statMap[stat.Id] then
					statMap[stat.Id] = #set.stats + 1
					table.insert(set.stats, { id = stat.Id })
				end
			end
		end
	end
	if grantedEffectStatSet and grantedEffectStatSet.ConstantStats then
		for i, stat in ipairs(grantedEffectStatSet.ConstantStats) do
			local copy = true
			for k, v in pairs(set.removeStats) do
				if stat.Id == v then
					copy = false
					table.remove(set.removeStats, k)
					break
				end
			end
			if copy then
				table.insert(set.constantStats, { stat.Id, grantedEffectStatSet.ConstantStatsValues[i] })
			end
		end
	end

	-- Emitting statSet data
	out:write('\t\t['..skill.setIndex..'] = {\n')
	out:write('\t\t\tlabel = "'..label..'",\n')
	if grantedEffectStatSet.BaseEffectiveness ~= 1 then
		out:write('\t\t\tbaseEffectiveness = ', grantedEffectStatSet.BaseEffectiveness, ',\n')
	end
	if grantedEffectStatSet.IncrementalEffectiveness ~= 0 then
		out:write('\t\t\tincrementalEffectiveness = ', grantedEffectStatSet.IncrementalEffectiveness, ',\n')
	end
	if grantedEffectStatSet.DamageIncrementalEffectiveness ~= 0 then
		out:write('\t\t\tdamageIncrementalEffectiveness = ', grantedEffectStatSet.DamageIncrementalEffectiveness, ',\n')
	end
	if state.granted.IsSupport then
		local gemEffect = dat("GemEffects"):GetRowList("AdditionalGrantedEffects", state.granted )
		if gemEffect[1] and gemEffect[1].Tags then
			for _, tag in ipairs(gemEffect[1].Tags) do
				if tag.Id == "meta" then
					skill.isMeta = true
				end
			end
		end
		if skill.isMeta then
			state.statDescriptionScope = "meta_gem_stat_descriptions"
		else
			state.statDescriptionScope = "gem_stat_descriptions"
		end
	else
		state.statDescriptionScope = state.granted.ActiveSkill.StatDescription:gsub("^Metadata/StatDescriptions/", ""):
		-- Need to subtract 1 from setIndex because GGG indexes from 0
		gsub("specific_skill_stat_descriptions/", ""):gsub("statset_0", "statset_"..(skill.setIndex - 1)):gsub("/$", ""):gsub("/", "_"), '",\n'
	end
	out:write('\t\t\tstatDescriptionScope = "' .. state.statDescriptionScope .. '",\n')
	skill.setIndex = skill.setIndex + 1
end

-- #from <tree | item>
-- Sets an optional from specifier if skill is granted by tree or item
directiveTable.from = function(state, args, out)
	state.fromSpec = args
end

-- #minionList <minion>[ <minion>[...]]
-- Sets the minion list for this active set
directiveTable.minionList = function(state, args, out)
	state.minionList = { }
	for minion in args:gmatch("%a+") do
		table.insert(state.minionList, minion)
	end
end

-- #flags <flag>[ <flag>[...]]
-- Sets the base flags for this active set
directiveTable.flags = function(state, args, out)
	local set = state.set
	for flag in args:gmatch("%a+") do
		table.insert(set.baseFlags, flag)
	end
end

-- #baseMod <mod definition>
-- Adds a base modifier to the set
directiveTable.baseMod = function(state, args, out)
	local set = state.set
	table.insert(set.mods, args)
end

-- #mods
-- Emits the set modifiers
directiveTable.mods = function(state, args, out)
	local set = state.set
	if not set then
		print("No statSet set, you're likely missing a #set directive in the .txt file")
		return
	end
	if not args:match("noBaseFlags") then
		if not set.isSupport then
			out:write('\t\t\tbaseFlags = {\n')
			for _, flag in ipairs(set.baseFlags) do
				out:write('\t\t\t\t', flag, ' = true,\n')
			end
			out:write('\t\t\t},\n')
		end
	end
	if not args:match("noBaseMods") then
		if next(set.mods) ~= nil then
			out:write('\t\t\tbaseMods = {\n')
			for _, mod in ipairs(set.mods) do
				out:write('\t\t\t\t', mod, ',\n')
			end
			out:write('\t\t\t},\n')
		end
	end
	if not args:match("noStats") then
		if next(set.constantStats) ~= nil then
			-- write out constant stats that don't change per level
			out:write('\t\t\tconstantStats = {\n')
			for _, stat in ipairs(set.constantStats) do
				out:write('\t\t\t\t{ "', stat[1], '", ', stat[2], ' },\n')
			end
			out:write('\t\t\t},\n')
		end
		out:write('\t\t\tstats = {\n')
		for _, stat in ipairs(set.stats) do
			out:write('\t\t\t\t"', stat.id, '",\n')
		end
		out:write('\t\t\t},\n')
		if next(set.CannotGrantToMinion) then
			out:write('\t\t\tnotMinionStat = {\n')
			for _, stat in ipairs(set.CannotGrantToMinion) do
				out:write('\t\t\t\t"', stat, '",\n')
			end
			out:write('\t\t\t},\n')
		end
	end
	if not args:match("noLevels") then
		out:write('\t\t\tlevels = {\n')
		for index, level in ipairs(set.levels) do
			out:write('\t\t\t\t[', level.level, '] = { ')
			for _, statVal in ipairs(level) do
				out:write(tostring(statVal), ', ')
			end
			for k, v in pairs(level.extra) do
				out:write(k, ' = ', tostring(v), ', ')
			end
			if next(level.statInterpolation) ~= nil then
				out:write('statInterpolation = { ')
				for _, type in ipairs(level.statInterpolation) do
					out:write(type, ', ')
				end
				out:write('}, ')
			end
			if level.actorLevel ~= nil then
				out:write('actorLevel = ', level.actorLevel, ', ')
			end
			out:write('},\n')
		end
		out:write('\t\t\t},\n')
	end
	out:write('\t\t},\n')

	-- validate stats
	local printHeader = true
	for _, stat in ipairs(set.stats) do
		if not checkModInStatDescription(state.statDescriptionScope, stat.id) then
			if printHeader then
				printHeader = false
				ConPrintf("====================================\nSkill %s: ", state.infoGrantedId)
			end
			ConPrintf("Stat %s not found in stat description %s",  stat.id, state.statDescriptionScope)
		end
	end
	for _, listStat in ipairs(set.constantStats) do
		local stat = listStat[1]
		if not checkModInStatDescription(state.statDescriptionScope, stat) then
			if printHeader then
				printHeader = false
				ConPrintf("====================================\nSkill %s: ", state.infoGrantedId)
			end
			ConPrintf("Constant Stat %s not found in stat description %s",  stat, state.statDescriptionScope)
		end
	end
	state.set = nil
end

for _, name in pairs({"act_str","act_dex","act_int","other","minion","spectre","sup_str","sup_dex","sup_int"}) do
	processTemplateFile(name, "Skills/", "../Data/Skills/", directiveTable)
end

local out = io.open("../Data/Gems.lua", "w")
out:write('-- This file is automatically generated, do not edit!\n')
out:write('-- Gem data (c) Grinding Gear Games\n\nreturn {\n')
for skillGem in dat("SkillGems"):Rows() do
	for _, gemEffect in ipairs(skillGem.GemEffects) do
		if gems[gemEffect.Id] then
			out:write('\t["', "Metadata/Items/Gems/SkillGem" .. gemEffect.Id, '"] = {\n')
			out:write('\t\tname = "', fullNameGems[skillGem.BaseItemType.Id] and skillGem.BaseItemType.Name or trueGemNames[gemEffect.Id] or skillGem.BaseItemType.Name:gsub(" Support",""), '",\n')
			-- Hybrid gems (e.g. Vaal gems) use the display name of the active skill e.g. Vaal Summon Skeletons of Sorcery
			if not skillGem.IsSupport then
				out:write('\t\tbaseTypeName = "', gemEffect.GrantedEffect.ActiveSkill.DisplayName, '",\n')
			end
			out:write('\t\tgameId = "', skillGem.BaseItemType.Id, '",\n')
			out:write('\t\tvariantId = "', gemEffect.Id, '",\n')
			out:write('\t\tgrantedEffectId = "', gemEffect.GrantedEffect.Id, '",\n')
			if gemEffect.GrantedEffect.AdditionalStatSets then
				for count, additionalGrantedEffect in ipairs(gemEffect.GrantedEffect.AdditionalStatSets) do
					out:write('\t\tadditionalStatSet' .. tostring(count) .. ' = "', additionalGrantedEffect.Id, '",\n')
				end
			end
			if gemEffect.AdditionalGrantedEffects then
				for count, additionalGrantedEffect in ipairs(gemEffect.AdditionalGrantedEffects) do
					out:write('\t\tadditionalGrantedEffectId' .. tostring(count) .. ' = "', additionalGrantedEffect.Id, '",\n')
				end
			end
			if gemEffect.GrantedEffectDisplayOrder then
				local grantedEffectDisplayOrder = { }
				for _, order in ipairs(gemEffect.GrantedEffectDisplayOrder) do
					table.insert(grantedEffectDisplayOrder, order)
				end
				if next(grantedEffectDisplayOrder) then
					out:write('\t\tgrantedEffectDisplayOrder = { ', table.concat(grantedEffectDisplayOrder, ", "), ' },\n')
				end
			end
			if #gemEffect.SecondarySupportName > 0 then
				out:write('\t\tsecondaryEffectName = "', gemEffect.SecondarySupportName, '",\n')
			end
			if skillGem.IsVaalGem then
				out:write('\t\tvaalGem = true,\n')
			end
			local gemType
			local tagNames = { }
			out:write('\t\ttags = {\n')
			for i, tag in ipairs(gemEffect.Tags) do
				out:write('\t\t\t', tag.Id, ' = true,\n')
				if #tag.Name > 0 then
					tag.Name = escapeGGGString(tag.Name) --Remove the words in brackets e.g. [DurationSkill|Duration] -> Duration
					if not gemType then
						gemType = tag.Name
					else
						table.insert(tagNames, tag.Name)
					end
				end
			end
			out:write('\t\t},\n')
			local weaponRequirement = { }
			if gemEffect.GrantedEffect.ActiveSkill and gemEffect.GrantedEffect.ActiveSkill.WeaponRestrictions then
				if gemEffect.GrantedEffect.ActiveSkill.WeaponRestrictions.String then
					table.insert(weaponRequirement, escapeGGGString(gemEffect.GrantedEffect.ActiveSkill.WeaponRestrictions.String.Text))
				else
					for _, class in ipairs(gemEffect.GrantedEffect.ActiveSkill.WeaponRestrictions.WeaponClass) do
						if weaponClassMap[class.ItemClass.Id] then
							table.insert(weaponRequirement, escapeGGGString(class.ItemClass.ItemClassCategory.Name))
						end
					end
				end
			end
			out:write('\t\tgemType = "', gemType, '",\n')
			if skillGem.IsSupport then
				local gemFamily = { }
				local supportGem = dat("SupportGems"):GetRow("SkillGem", dat("SkillGems"):GetRow("BaseItemType", dat("BaseItemTypes"):GetRow("Id", skillGem.BaseItemType.Id)))
				for _, type in ipairs(supportGem.Family) do
					table.insert(gemFamily, type.Name)
				end
				if next(gemFamily) then
					out:write('\t\tgemFamily = "', table.concat(gemFamily, ", "), '",\n')
				end
			end
			out:write('\t\ttagString = "', table.concat(tagNames, ", "), '",\n')
			if next(weaponRequirement) then
				out:write('\t\tweaponRequirements = "', table.concat(weaponRequirement, ", "), '",\n')
			end
			out:write('\t\treqStr = ', skillGem.Str, ',\n')
			out:write('\t\treqDex = ', skillGem.Dex, ',\n')
			out:write('\t\treqInt = ', skillGem.Int, ',\n')
			out:write('\t\tTier = ', skillGem.Tier, ',\n')
			-- overriding level to 1 if support because dat currently has incorrect progression for most supports
			local naturalMaxLevel = skillGem.IsSupport and 1 or #dat("ItemExperiencePerLevel"):GetRowList("ItemExperienceType", skillGem.GemLevelProgression)
			out:write('\t\tnaturalMaxLevel = ', naturalMaxLevel > 0 and naturalMaxLevel or 1, ',\n')
			out:write('\t},\n')
		end
	end
end
out:write('}')
out:close()

print("Skill data exported.")
