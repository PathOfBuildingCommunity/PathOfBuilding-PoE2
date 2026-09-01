-- Path of Building
--
-- Module: Calc Tools
-- Various functions used by the calculation modules
--
local pairs = pairs
local t_insert = table.insert
local t_remove = table.remove
local m_floor = math.floor
local m_min = math.min
local m_max = math.max

calcLib = { }

-- Calculate and combine INC/MORE modifiers for the given modifier names
function calcLib.mod(modStore, cfg, ...)
	local inc, more = calcLib.mods(modStore, cfg, ...)
	return inc * more
end

---Calculates additive and multiplicative modifiers for specified modifier names
---@param modStore table
---@param cfg table
---@param ... string Mod names. Do not call this in a hot loop with more than 5 mod names, as this will break JIT traces.
---@return number increased, number more
function calcLib.mods(modStore, cfg, ...)
	-- Call separated by argument count so that we can avoid breaking LuaJIT traces. Both calling
	-- `select(i, ...)` with a non-const integer and passing `f(...)` will abort a trace.
	local n = select('#', ...)
	if n == 1 then
		local a = ...
		return 1 + modStore:Sum("INC", cfg, a) / 100, modStore:More(cfg, a)
	elseif n == 2 then
		local a, b = ...
		return 1 + modStore:Sum("INC", cfg, a, b) / 100, modStore:More(cfg, a, b)
	elseif n == 3 then
		local a, b, c = ...
		return 1 + modStore:Sum("INC", cfg, a, b, c) / 100, modStore:More(cfg, a, b, c)
	elseif n == 4 then
		local a, b, c, d = ...
		return 1 + modStore:Sum("INC", cfg, a, b, c, d) / 100, modStore:More(cfg, a, b, c, d)
	elseif n == 5 then
		local a, b, c, d, e = ...
		return 1 + modStore:Sum("INC", cfg, a, b, c, d, e) / 100, modStore:More(cfg, a, b, c, d, e)
	end
	return 1 + modStore:Sum("INC", cfg, ...) / 100, modStore:More(cfg, ...)
end

-- Calculate value
function calcLib.val(modStore, name, cfg)
	local baseVal = modStore:Sum("BASE", cfg, name)
	if baseVal ~= 0 then
		return baseVal * calcLib.mod(modStore, cfg, name)
	else
		return 0
	end
end

-- Validate the level of the given gem
function calcLib.validateGemLevel(gemInstance)
	local grantedEffect = gemInstance.grantedEffect or gemInstance.gemData.grantedEffect
	if not grantedEffect.levels[gemInstance.level] then
		-- Try limiting to the level range of the skill
		gemInstance.level = m_max(1, gemInstance.level)
		if #grantedEffect.levels > 0 then
			gemInstance.level = m_min(#grantedEffect.levels, gemInstance.level)
		end
	end
	if not grantedEffect.levels[gemInstance.level] and gemInstance.gemData and gemInstance.gemData.naturalMaxLevel then
		gemInstance.level = gemInstance.gemData.naturalMaxLevel
	end
	if not grantedEffect.levels[gemInstance.level] then
		-- That failed, so just grab any level
		gemInstance.level = next(grantedEffect.levels)
	end
end

local typeExpressionStack = { }

-- Evaluate a skill type postfix expression
function calcLib.doesTypeExpressionMatch(checkTypes, skillTypes, minionTypes)
	local stackSize = 0
	for _, skillType in pairs(checkTypes) do
		if skillType == SkillType.OR then
			local other = typeExpressionStack[stackSize]
			stackSize = stackSize - 1
			typeExpressionStack[stackSize] = typeExpressionStack[stackSize] or other
		elseif skillType == SkillType.AND then
			local other = typeExpressionStack[stackSize]
			stackSize = stackSize - 1
			typeExpressionStack[stackSize] = typeExpressionStack[stackSize] and other
		elseif skillType == SkillType.NOT then
			typeExpressionStack[stackSize] = not typeExpressionStack[stackSize]
		else
			stackSize = stackSize + 1
			typeExpressionStack[stackSize] = skillTypes[skillType] or (minionTypes and minionTypes[skillType]) or false
		end
	end
	for index = 1, stackSize do
		if typeExpressionStack[index] then
			return true
		end
	end
	return false
end

-- Check if given support skill can support the given active skill
function calcLib.canGrantedEffectSupportActiveSkill(grantedEffect, activeSkill)
	if activeSkill.activeEffect.grantedEffect.cannotBeSupported then
		return false
	end
	if grantedEffect.supportGemsOnly and not activeSkill.activeEffect.gemData then
		return false
	end

	-- Special case for things like Forbidden Shako or Hungry Loop with  for example Prismatic Burst and another compatible support
	if grantedEffect.fromItem and grantedEffect.support and (activeSkill.activeEffect.grantedEffect.fromItem or activeSkill.activeEffect.grantedEffect.modSource:sub(1, #"Item") == "Item" or (activeSkill.activeEffect.srcInstance and activeSkill.activeEffect.srcInstance.fromItem)) then
		return false
	end
	
	local effectiveSkillTypes = activeSkill.summonSkill and activeSkill.summonSkill.skillTypes or activeSkill.skillTypes
	local effectiveMinionTypes = not grantedEffect.ignoreMinionTypes and (activeSkill.summonSkill and activeSkill.summonSkill.minionSkillTypes or activeSkill.minionSkillTypes)
	
	-- if the activeSkill is a Minion's skill like "Default Attack", use minion's skillTypes instead for exclusions
	-- otherwise compare support to activeSkill directly
	if grantedEffect.excludeSkillTypes[1] and calcLib.doesTypeExpressionMatch(grantedEffect.excludeSkillTypes, effectiveSkillTypes) then
		return false
	end
	if grantedEffect.isTrigger and activeSkill.actor.enemy.player ~= activeSkill.actor then
		return false
	end
	return not grantedEffect.requireSkillTypes[1] or calcLib.doesTypeExpressionMatch(grantedEffect.requireSkillTypes, effectiveSkillTypes, effectiveMinionTypes)
end

-- Check if given gem is of the given type ("all", "strength", "melee", etc)
function calcLib.gemIsType(gem, type, includeTransfigured)
	local gemData = gem.gemData or gem
	return (type == "all" or
			(type == "corrupted" and gem.corrupted) or
			(type == "elemental" and (gemData.tags.fire or gemData.tags.cold or gemData.tags.lightning)) or
			(type == "aoe" and gemData.tags.area) or
			(type == "trap or mine" and (gemData.tags.trap or gemData.tags.mine)) or
			((type == "active skill" or type == "grants_active_skill" or type == "skill") and gemData.tags.grants_active_skill and not gemData.tags.support) or
			(type == "non-vaal" and not gemData.tags.vaal) or
			(type == gemData.name:lower()) or
			(type == gemData.name:lower():gsub("^vaal ", "")) or
			(includeTransfigured and calcLib.isGemIdSame(gemData.name, type, true)) or
			((type ~= "active skill" and type ~= "grants_active_skill" and type ~= "skill") and gemData.tags[type]))
end

-- In-game formula
function calcLib.getGemStatRequirement(level, multi, isSupport)
	if multi == 0 or isSupport then
		return 0
	end
	local req = round( ( 5 + ( level - 3 ) * 1.7 ) * ( multi / 100 ) ^ 0.9 ) + 4
	return req < 8 and 0 or req
end

-- Build table of stats for the given skill instance statset
function calcLib.buildSkillInstanceStats(skillInstance, grantedEffect, statSet, includeAltQualityStats)
	local stats = { }
	if skillInstance.quality > 0 then
		local qualityStats = grantedEffect.qualityStats
		if qualityStats then
			for _, stat in ipairs(qualityStats) do
				stats[stat[1]] = (stats[stat[1]] or 0) + math.modf(stat[2] * skillInstance.quality)
			end
		end
		qualityStats = grantedEffect.altQualityStats
		if includeAltQualityStats and qualityStats then
			for _, stat in ipairs(qualityStats) do
				stats[stat[1]] = (stats[stat[1]] or 0) + math.modf(stat[2] * skillInstance.quality)
			end
		end
	end
	local grantedEffectLevel = grantedEffect.levels[skillInstance.level] or { }
	local statSetLevel = statSet.levels[skillInstance.level] or statSet.levels[1] or { }
	local availableEffectiveness
	local actorLevel = skillInstance.actorLevel or grantedEffectLevel.levelRequirement or 1
	for index, stat in ipairs(statSet.stats) do
		-- Static value used as default (assumes statInterpolation == 1)
		local statValue = statSetLevel[index] or 1
		if statSetLevel.statInterpolation then
			if statSetLevel.statInterpolation[index] == 3 then
				-- Effectiveness interpolation
				if not availableEffectiveness then
					actorLevel = #statSet.levels < 5 and skillInstance.actorLevel or statSetLevel.actorLevel
					availableEffectiveness =
						data.gameConstants["SkillDamageBaseEffectiveness"] * (statSet.baseEffectiveness or 1)
							* (1 + (statSet.incrementalEffectiveness or 0) * (actorLevel - 1)) 
							* (1 + (statSet.damageIncrementalEffectiveness or 0)) ^ (actorLevel - 1)
				end
				statValue = round(availableEffectiveness * statSetLevel[index])
			elseif statSetLevel.statInterpolation[index] == 2 then
				-- Linear interpolation; I'm actually just guessing how this works

				-- Order the levels, since sometimes they skip around
				local orderedLevels = { }
				local currentLevelIndex
				for level, _ in pairs(grantedEffect.levels) do
					t_insert(orderedLevels, level)
				end
				table.sort(orderedLevels)
				for idx, level in ipairs(orderedLevels) do
					if skillInstance.level == level then
						currentLevelIndex = idx
					end
				end

				if #orderedLevels > 1 then
					local nextLevelIndex = m_min(currentLevelIndex + 1, #orderedLevels)
					local nextReq = grantedEffect.levels[orderedLevels[nextLevelIndex]].levelRequirement
					local prevReq = grantedEffect.levels[orderedLevels[nextLevelIndex - 1]].levelRequirement
					local nextStat = grantedEffect.levels[orderedLevels[nextLevelIndex]][index]
					local prevStat = grantedEffect.levels[orderedLevels[nextLevelIndex - 1]][index]
					statValue = round(prevStat + (nextStat - prevStat) * (actorLevel - prevReq) / (nextReq - prevReq))
				else
					statValue = round(grantedEffect.levels[orderedLevels[currentLevelIndex]][index])
				end
			end
		end
		stats[stat] = (stats[stat] or 0) + statValue
	end
	if statSet.constantStats then
		for _, stat in ipairs(statSet.constantStats) do
			stats[stat[1]] = (stats[stat[1]] or 0) + (stat[2] or 0)
		end
	end
	return stats
end

--- Correct the tags on conversion with multipliers so they carry over correctly
--- @param mod table
--- @param multiplier number
--- @param minionMods boolean @convert ActorConditions pointing at parent to normal Conditions
--- @return table @converted multipliers
function calcLib.getConvertedModTags(mod, multiplier, minionMods)
	local modifiers = { }
	for k, value in ipairs(mod) do
		if minionMods and value.type == "ActorCondition" and value.actor == "parent" then
			modifiers[k] = { type = "Condition", var = value.var }
		elseif value.limitTotal then
			-- LimitTotal can apply to 'per stat' or 'multiplier', so just copy the whole and update the limit
			local copy = copyTable(value)
			copy.limit = copy.limit * multiplier
			modifiers[k] = copy
		else
			modifiers[k] = copyTable(value)
		end
	end
	return modifiers
end

--- Get the gameId from the gemName which will be the same as the base gem for transfigured gems
--- @param gemName string
--- @param dropVaal boolean
--- @return string
function calcLib.getGameIdFromGemName(gemName, dropVaal)
	if type(gemName) ~= "string" then
		return
	end
	local gemId = data.gemForBaseName[gemName:lower()]
	if not gemId then return end
	local gameId 
	if dropVaal and data.gems[gemId].vaalGem then
		gameId = data.gems[data.gemVaalGemIdForBaseGemId[gemId]].gameId
	else
		gameId = data.gems[gemId].gameId
	end
	return gameId
end

--- Use getGameIdFromGemName to get gameId from the gemName and passed in type. Return true if they're the same and not nil
--- @param gemName string
--- @param typeName string
--- @param dropVaal boolean 
--- @return boolean
function calcLib.isGemIdSame(gemName, typeName, dropVaal)
	local gemNameId = calcLib.getGameIdFromGemName(gemName, dropVaal)
	local typeId = calcLib.getGameIdFromGemName(typeName, dropVaal)
	return gemNameId and typeId and gemNameId == typeId
end
