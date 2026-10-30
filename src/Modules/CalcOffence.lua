-- Path of Building
--
-- Module: Calc Offence
-- Performs offence calculations.
--
---@class Calcs
local calcs = require("Modules.CalcBase")

local pairs = pairs
local ipairs = ipairs
local unpack = unpack
local t_insert = table.insert
local t_remove = table.remove
local m_abs = math.abs
local m_floor = math.floor
local m_ceil = math.ceil
local m_min = math.min
local m_max = math.max
local m_sqrt = math.sqrt
local m_pow = math.pow
local m_huge = math.huge
local bor = OR64 -- bit.bor
local band = AND64 -- bit.band
local bnot = NOT64 -- bit.bnot
local s_format = string.format

local tempTable1 = { }
local tempTable2 = { }
local tempTable3 = { }
local tempTable4 = { }

local isElemental = { Fire = true, Cold = true, Lightning = true }

-- List of all damage types, ordered according to the conversion sequence
local dmgTypeList = {"Physical", "Lightning", "Cold", "Fire", "Chaos"}
local dmgTypeFlags = {
	order = { "Physical", "Lightning", "Cold", "Fire", "Elemental", "Chaos" },
	flags = {
		Physical	= 0x01,
		Lightning	= 0x02,
		Cold		= 0x04,
		Fire		= 0x08,
		Elemental	= 0x0E,
		Chaos		= 0x10,
	}
}

-- List of all ailments
local ailmentTypeList = data.ailmentTypeList
-- List of elemental ailments
local elementalAilmentTypeList = data.elementalAilmentTypeList

-- Magic table for caching the modifier name sets used in calcDamage()
local damageStatsForTypes = setmetatable({ }, { __index = function(t, k)
	local modNames = { "Damage" }
	for _, type in ipairs(dmgTypeFlags.order) do
		local flag = dmgTypeFlags.flags[type]
		if band(k, flag) ~= 0 then
			t_insert(modNames, type.."Damage")
		end
	end
	t[k] = modNames
	return modNames
end })

local globalOutput = nil
---@type Breakdown?
local globalBreakdown = nil

local function processDamageConversion(skillModList, skillCfg, fromType, skill)
	local total = 0
	local totalConv = wipeTable(tempTable1)

	-- Calculate conversion for this damage type
	for _, toType in ipairs(dmgTypeList) do
		local conv
		if skill then
			conv = m_max(skillModList:Sum("BASE", skillCfg,
				"SkillDamageConvertTo"..toType,
				"Skill"..fromType.."DamageConvertTo"..toType), 0)
		else
			conv = m_max(skillModList:Sum("BASE", skillCfg,
				"DamageConvertTo"..toType,
				fromType.."DamageConvertTo"..toType,
				isElemental[fromType] and "ElementalDamageConvertTo"..toType or nil,
				fromType ~= "Chaos" and "NonChaosDamageConvertTo"..toType or nil), 0)
		end

		totalConv[toType] = conv / 100
		total = total + conv
	end

	-- Scale if over 100%
	if total > 100 then
		local factor = 100 / total
		for type, val in pairs(totalConv) do
			totalConv[type] = val * factor
		end
		total = 100
	end

	return totalConv, total
end

local selfHitHandlers = {
	["Heartbound Loop"] = function(activeSkill, output, breakdown)
		if activeSkill.activeEffect.grantedEffect.name == "Summon Skeletons" then
			local dmgType, dmgVal
			for _, value in ipairs(activeSkill.skillModList:List(nil, "HeartboundLoopSelfDamage")) do -- Combines dmg taken from both ring accounting for catalysts
				dmgVal = (dmgVal or 0) + value.baseDamage
				dmgType = string.gsub(" "..value.damageType, "%W%l", string.upper):sub(2) -- This assumes both rings deal the same damage type
			end
			if dmgType and dmgVal then
				-- !!!! WARNING !!!! --
				-- applyDmgTakenConversion does NOT consider the "And protect me from Harm" yet
				local dmgBreakdown, totalDmgTaken = calcs.applyDmgTakenConversion(activeSkill, output, breakdown, dmgType, dmgVal)
				t_insert(dmgBreakdown, 1, localisation:Text("calc.offence.details.line", { dmg_val = dmgVal }))
				t_insert(dmgBreakdown, 2, s_format(""))
				t_insert(dmgBreakdown, localisation:Text("calc.offence.details.line_2", { total_dmg_taken = totalDmgTaken, summoned_minions_per_cast = output.SummonedMinionsPerCast, value = totalDmgTaken * output.SummonedMinionsPerCast }))
				return dmgBreakdown, totalDmgTaken * output.SummonedMinionsPerCast
			end
		end
	end,
	["Trauma"] = function(activeSkill, output, breakdown)
		local dmgType = "Physical"
		local currentTraumaStacks =  math.max(activeSkill.skillModList:Sum("BASE", nil, "Multiplier:TraumaStacks"), 1)
		local damagePerTrauma = activeSkill.skillModList:Sum("BASE", nil, "TraumaSelfDamageTakenLife")
		local dmgVal = activeSkill.baseSkillModList:Flag(nil, "HasTrauma") and damagePerTrauma * currentTraumaStacks
		if dmgType and dmgVal then
			-- !!!! WARNING !!!! --
			-- applyDmgTakenConversion does NOT consider the "And protect me from Harm" yet
			local dmgBreakdown, totalDmgTaken = calcs.applyDmgTakenConversion(activeSkill, output, breakdown, dmgType, dmgVal)
			t_insert(dmgBreakdown, 1, localisation:Text("calc.offence.details.line_3", { damage_per_trauma = damagePerTrauma, dmg_type = dmgType, current_trauma_stacks = currentTraumaStacks, value = ((activeSkill.skillModList:Sum("BASE", activeSkill.skillCfg, "Multiplier:SustainableTraumaStacks") == currentTraumaStacks and localisation:Ref("calc.offence.details.line.parameter")) or localisation:Ref("calc.offence.details.line.parameter_2")), dmg_val = dmgVal, dmg_type_2 = dmgType }))
			t_insert(dmgBreakdown, 2, s_format(""))
			t_insert(dmgBreakdown, localisation:Text("calc.offence.details.line_4", { total_dmg_taken = totalDmgTaken }))
			return dmgBreakdown, totalDmgTaken
		end
	end,
}

local function calcConvertedDamage(activeSkill, output, cfg, damageType)
	local skillModList = activeSkill.skillModList
	-- Calculate conversions
	local convertedMin, convertedMax = 0, 0
	local conversionTable = activeSkill.conversionTable
	for _, otherType in ipairs(dmgTypeList) do
		local convMult = conversionTable[otherType][damageType]
		if convMult > 0 then
			-- Damage is being converted/gained from the other damage type
			local min, max = output[otherType.."MinBase"], output[otherType.."MaxBase"]
			convertedMin = convertedMin + (min or 0) * convMult
			convertedMax = convertedMax + (max or 0) * convMult
		end
	end
	return convertedMin, convertedMax
end

local function calcGainedDamage(activeSkill, output, cfg, damageType)
	local gainTable = activeSkill.gainTable

	local gainedMin, gainedMax = 0, 0
	for _, otherType in ipairs(dmgTypeList) do
		local baseMin = output[otherType.."MinBase"] * activeSkill.conversionTable[otherType].mult
		local baseMax = output[otherType.."MaxBase"] * activeSkill.conversionTable[otherType].mult
		local gainMult = gainTable[otherType][damageType]
		if gainMult and gainMult > 0 then
			-- Damage is being converted/gained from the other damage type
			local convertedMin, convertedMax = calcConvertedDamage(activeSkill, output, cfg, otherType)
			gainedMin = gainedMin + (baseMin + convertedMin) * gainMult
			gainedMax = gainedMax + (baseMax + convertedMax) * gainMult
		end
	end

	return gainedMin, gainedMax
end

-- Calculate min/max damage for the given damage type
local function calcDamage(activeSkill, output, cfg, breakdown, damageType, typeFlags, convDst)
	local skillModList = activeSkill.skillModList

	typeFlags = bor(typeFlags, dmgTypeFlags.flags[damageType])

	local conversionTable = activeSkill.conversionTable

	local addMin, addMax = 0, 0
	local summedMin = output[damageType.."SummedMinBase"]
	local summedMax = output[damageType.."SummedMaxBase"]

	if summedMin == 0 and summedMax == 0 then
		-- No base damage for this type, don't need to calculate modifiers
		if breakdown and (addMin ~= 0 or addMax ~= 0) then
			t_insert(breakdown.damageTypes, {
				source = damageType, sourceKey = localisation:TermKey("damage_type", damageType),
				convSrc = (addMin ~= 0 or addMax ~= 0) and (localisation:Text("calc.damage.range", { minimum = addMin, maximum = addMax })),
				total = localisation:Text("calc.damage.range", { minimum = addMin, maximum = addMax }),
				convDst = convDst and localisation:Text("calc.offence.calc_damage.line", { value = conversionTable[damageType][convDst] * 100, conv_dst = localisation:TermRef("damage_type", convDst) }),
			})
		end
		return addMin, addMax
	end

	-- Combine modifiers
	local modNames = damageStatsForTypes[typeFlags]
	local inc = 1 + skillModList:Sum("INC", cfg, unpack(modNames)) / 100
	local more = skillModList:More(cfg, unpack(modNames))
	local moreMinDamage = skillModList:More(cfg, "Min"..damageType.."Damage")
	local moreMaxDamage = skillModList:More(cfg, "Max"..damageType.."Damage")

	if breakdown then
		t_insert(breakdown.damageTypes, {
			source = damageType, sourceKey = localisation:TermKey("damage_type", damageType),
			base = localisation:Text("calc.damage.range", { minimum = summedMin, maximum = summedMax }),
			inc = (inc ~= 1 and "x "..inc),
			more = (more ~= 1 and "x "..more),
			convSrc = (addMin ~= 0 or addMax ~= 0) and (localisation:Text("calc.damage.range", { minimum = addMin, maximum = addMax })),
			total = localisation:Text("calc.damage.range", { minimum = (round(summedMin * inc * more) + addMin), maximum = (round(summedMax * inc * more) + addMax) }),
			convDst = convDst and conversionTable[damageType][convDst] > 0 and localisation:Text("calc.offence.calc_damage.line", { value = conversionTable[damageType][convDst] * 100, conv_dst = localisation:TermRef("damage_type", convDst) }),
		})
	end

	return 	round(summedMin * inc * more * moreMinDamage + addMin),
			round(summedMax * inc * more * moreMaxDamage + addMax)
end

---Calculates the area percentage after the client integer rounding stages.
---@param incArea number @Additive modifier
---@param moreArea number @Multiplicative modifier
---@return number
local function calcAreaMod(incArea, moreArea)
	local baseAreaPercent = roundSymmetric(incArea * 100)
	local finalAreaPercent = roundSymmetric(m_max(0, moreArea) * 100)
	local areaPercent = baseAreaPercent * finalAreaPercent / 100
	areaPercent = areaPercent >= 0 and m_floor(areaPercent) or m_ceil(areaPercent)
	return m_max(0, areaPercent) / 100
end

---Calculates skill radius
---@param baseRadius number
---@param areaMod number
---@param radiusMod number|nil
---@return number
local function calcRadius(baseRadius, areaMod, radiusMod)
	local radiusPercent = m_floor(100 * m_sqrt(areaMod))
	-- Final radius modifiers apply after Area of Effect has been converted to radius.
	radiusPercent = m_floor(radiusPercent * (radiusMod or 1))
	return m_floor(baseRadius * radiusPercent / 100)
end

---Calculates the tertiary radius for Molten Strike, correctly handling the deadzone.
---@param baseRadius number
---@param deadzoneRadius number
---@param areaMod number
---@param speedMod number
local function calcMoltenStrikeTertiaryRadius(baseRadius, deadzoneRadius, areaMod, speedMod)
	-- For now, we assume that PoE only rounds at the end.
	local maxDistIgnoringSpeed = m_sqrt(baseRadius * baseRadius * areaMod - deadzoneRadius * deadzoneRadius * (areaMod - 1))
	local maxDist = m_floor((maxDistIgnoringSpeed - deadzoneRadius) * speedMod + deadzoneRadius)
	return maxDist
end

---Calculates modifiers needed to reach the next and previous radius breakpoints
---@param baseRadius number
---@param incArea number @Additive modifier
---@param moreArea number @Multiplicative modifier
---@param radiusMod number|nil @Final radius modifier
---@return number, number, number, number @Next breakpoint: increased, more; Previous breakpoint: reduced, less
local function calcRadiusBreakpoints(baseRadius, incArea, moreArea, radiusMod)
	local radius = calcRadius(baseRadius, calcAreaMod(incArea, moreArea), radiusMod)
	local incAreaBreakpoint, redAreaBreakpoint, moreAreaBreakpoint, lessAreaBreakpoint
	if radius > 0 then
		incAreaBreakpoint = 0
		repeat
			incAreaBreakpoint = incAreaBreakpoint + 1
			local newRadius = calcRadius(baseRadius, calcAreaMod(incArea + incAreaBreakpoint / 100, moreArea), radiusMod)
		until (newRadius > radius)
		redAreaBreakpoint = 0
		repeat
			redAreaBreakpoint = redAreaBreakpoint + 1
			local newRadius = calcRadius(baseRadius, calcAreaMod(incArea - redAreaBreakpoint / 100, moreArea), radiusMod)
		until (newRadius < radius)
		moreAreaBreakpoint = 0
		repeat
			moreAreaBreakpoint = moreAreaBreakpoint + 1
			local newRadius = calcRadius(baseRadius, calcAreaMod(incArea, moreArea * (1 + moreAreaBreakpoint / 100)), radiusMod)
		until (newRadius > radius)
		lessAreaBreakpoint = 0
		repeat
			lessAreaBreakpoint = lessAreaBreakpoint + 1
			local newRadius = calcRadius(baseRadius, calcAreaMod(incArea, moreArea * (1 - lessAreaBreakpoint / 100)), radiusMod)
		until (newRadius < radius)
	end
	return incAreaBreakpoint, moreAreaBreakpoint, redAreaBreakpoint, lessAreaBreakpoint
end

---Computes and sets the breakdown for Molten Strike's tertiary radius.
---@param breakdown table
---@param deadzoneRadius number min ball landing distance (cannot be changed by any mods)
---@param baseRadius number default max landing distance with no aoe or proj. speed modifiers
---@param label string top level label to use for the breakdown
---@param incArea number current net increased area modifier
---@param moreArea number current product of all "more" and "less" area modifiers
---@param incSpd number current net increased projectile speed modifier
---@param moreSpd number current product of all "more" and "less" projectile speed modifiers
local function setMoltenStrikeTertiaryRadiusBreakdown(breakdown, deadzoneRadius, baseRadius, label, incArea, moreArea, incSpd, moreSpd)
	-- nil -> 1 (no multiplier)
	incArea = incArea or 1
	moreArea = moreArea or 1
	incSpd = incSpd or 1
	moreSpd = moreSpd or 1
	---Helper that calculates the tertiary radius with incremental modifiers to the 4 relevant pools.
	---This helps declutter the code below.
	local function calc(extraIncAoePct, extraMoreAoePct, extraIncSpdPct, extraMoreSpdPct)
		local areaMod = round(round((incArea + extraIncAoePct / 100) * moreArea * (1 + extraMoreAoePct / 100), 10), 2)
		local speedMod = round(round((incSpd + extraIncSpdPct / 100) * moreSpd * (1 + extraMoreSpdPct / 100), 10), 2)
		local dist = calcMoltenStrikeTertiaryRadius(baseRadius, deadzoneRadius, areaMod, speedMod)
		return dist, areaMod, speedMod
	end
	-- Current settings.
	local currentDist, currentAreaMod, currentSpeedMod = calc(0, 0, 0, 0)
	-- Create the detailed breakdown. This includes:
	--  * the complete formula as an algebraic expression (ignoring rounding),
	--  * the final value,
	--  * breakpoints on the 4 modifier pools (increased vs. more crossed with aoe and projectile speed), and
	--  * the input variables for the algebraic expression.
	local breakdownRadius = breakdown.AreaOfEffectRadiusTertiary or { }
	breakdown.AreaOfEffectRadiusTertiary = breakdownRadius
	t_insert(breakdownRadius, label)
	t_insert(breakdownRadius, localisation:Text("calc.offence.set_molten_strike_tertiary_radius_breakdown.line"))
	t_insert(breakdownRadius, s_format(" = %d", currentDist))
	if currentDist > 0 then
		---Helper for finding one tertiary radius breakpoint value. This is a little slower than what
		---we do in the generic calcRadiusBreakpoints, but this approach requires a lot less code and
		---should be more maintainable given that we need to search for 8 different breakpoints.
		---@param sign number +1 (for increased and more breakpoints) or -1 (for reduced and less breakpoints)
		---@param argIdx number which argument to the calc function we're modifying
		local function findBreakpoint(sign, argIdx)
			local args = {0, 0, 0, 0} -- starter args for the calc function
			repeat
				args[argIdx] = args[argIdx] + sign -- increment or decrement the desired arg
				local newDist, _, _ = calc(unpack(args))
			until (newDist ~= currentDist) or (newDist == 0) -- stop once we've hit a new radius breakpoint
			return args[argIdx] * sign -- remove the sign since we want all positive numbers
		end
		t_insert(breakdownRadius, localisation:Text("calc.offence.set_molten_strike_tertiary_radius_breakdown.line_2", { value = findBreakpoint(1, 1), value_2 = findBreakpoint(1, 2) }))
		t_insert(breakdownRadius, localisation:Text("calc.offence.set_molten_strike_tertiary_radius_breakdown.line_3", { value = findBreakpoint(1, 3), value_2 = findBreakpoint(1, 4) }))
		t_insert(breakdownRadius, localisation:Text("calc.offence.set_molten_strike_tertiary_radius_breakdown.line_4", { value = findBreakpoint(-1, 1), value_2 = findBreakpoint(-1, 2) }))
		t_insert(breakdownRadius, localisation:Text("calc.offence.set_molten_strike_tertiary_radius_breakdown.line_5", { value = findBreakpoint(-1, 3), value_2 = findBreakpoint(-1, 4) }))
	end
	-- This is the input variable table.
	breakdownRadius.label = "Inputs"
	breakdownRadius.rowList = { }
	breakdownRadius.colList = {
		{ label = "Variable", labelKey = "ui.calc_offence.set_molten_strike_tertiary_radius_breakdown.name.label", key = "name" },
		{ label = "Value", labelKey = "ui.calc_offence.set_molten_strike_tertiary_radius_breakdown.value.label", key = "value"},
		{ label = "Description", labelKey = "ui.calc_offence.set_molten_strike_tertiary_radius_breakdown.description.label", key = "description" }
	}
	t_insert(breakdownRadius.rowList, { name = "r", value = s_format("%d", deadzoneRadius), description = "fixed deadzone radius", descriptionKey = "ui.calc_offence.field.description" })
	t_insert(breakdownRadius.rowList, { name = "R", value = s_format("%d", baseRadius), description = "base outer radius", descriptionKey = "ui.calc_offence.field.description_2" })
	t_insert(breakdownRadius.rowList, { name = "a", value = s_format("%.2f", currentAreaMod), description = "net AoE multiplier (scales area)", descriptionKey = "ui.calc_offence.field.description_3" })
	t_insert(breakdownRadius.rowList, { name = "s", value = s_format("%.2f", currentSpeedMod), description = "net projectile speed multiplier (scales range)", descriptionKey = "ui.calc_offence.field.description_4" })
	-- Trigger the inclusion of the radius display.
	breakdownRadius.radius = currentDist
end
-- Calculate and return reload time in seconds for a specific Crossbow skill
---@param actor table @actor using the skill
---@param boltSkill table @skill that uses the ammo to shoot bolts
---@return number
local function calcCrossbowReloadTime(weaponData, boltSkill)
	local baseReloadTime = weaponData.ReloadTime
	if not baseReloadTime then
		return
	end

	local reloadTimeMulti = calcLib.mod(boltSkill.skillModList, boltSkill.skillCfg, "ReloadSpeed", "Speed" )
	return baseReloadTime / reloadTimeMulti
end
-- Calculate stats from parent Ammo skill that are not available on children, such as mana cost and reload speed
---@param actor table
---@param activeSkill table
---@return table @Table containing cost, boltCount, reloadTime
local function calcCrossbowAmmoStats(actor, activeSkill)
	-- Iterate over all skills in activeSkillList. If one is an ammo skill from the same base gem as current skill, take those stats
	for _, skill in ipairs(actor.activeSkillList) do
		if skill.skillTypes[SkillType.CrossbowAmmoSkill] and (skill.skillCfg.skillGem == activeSkill.skillCfg.skillGem) then
			-- assign values
			-- transfer the actual mods modifying base crossbow bolt count and reload speed from ammo skill to active skill
			for _, mod in ipairs(skill.baseSkillModList) do
				if (mod.name == "CrossbowBoltCount") or (mod.name == "ReloadSpeed") then
					activeSkill.skillModList:ReplaceMod(mod.name, mod.type, mod.value, mod.source)
				end
			end
			local ammoSkillStats = {
				cost = skill.activeEffect.grantedEffectLevel.cost,
				boltCount = activeSkill.skillModList:Sum("BASE", activeSkill.skillCfg, "CrossbowBoltCount"),
				reloadTime = calcCrossbowReloadTime(actor.weaponData1,  activeSkill)
			}
			return ammoSkillStats
		end
	end
	-- Ensure minimum 1 base bolt count in any case
	activeSkill.skillModList:ReplaceMod("CrossbowBoltCount", "BASE", 1, activeSkill.activeEffect.grantedEffect.name)
	local dummySkillStats = {
		cost = activeSkill.activeEffect.grantedEffectLevel.cost,
		boltCount = m_max(activeSkill.skillModList:Sum("BASE", activeSkill.skillCfg, "CrossbowBoltCount"), 1), -- ensure minimum one bolt
		reloadTime = calcCrossbowReloadTime(actor.weaponData1, activeSkill)
	}
	return dummySkillStats
end

function calcSkillCooldown(skillModList, skillCfg, skillData)
	local cooldownOverride = skillModList:Override(skillCfg, "CooldownRecovery")
	local addedCooldown = skillModList:Sum("BASE", skillCfg, "CooldownRecovery")
	local temporalisCooldown = skillModList:Sum("BASE", skillCfg, "CooldownRecoveryFromTemporalis")
	local noCooldownChance = skillModList:Sum("BASE", skillCfg,  "CooldownChanceNotConsume")
	local cooldownBase = (skillData.cooldown or 0) + addedCooldown
	if skillData.cooldown then
		cooldownBase = cooldownBase + temporalisCooldown
	end
	local cooldown = cooldownOverride or cooldownBase / m_max(0, calcLib.mod(skillModList, skillCfg, "CooldownRecovery"))
	if skillData.cooldown and temporalisCooldown ~= 0 then
		cooldown = m_max(cooldown, 0.1)
	end
	-- If a skill can store extra uses and has a cooldown, it doesn't round the cooldown value to server ticks
	local rounded = false
	if (skillData.storedUses and skillData.storedUses > 1) or (skillData.VaalStoredUses and skillData.VaalStoredUses > 1) or skillModList:Sum("BASE", skillCfg, "AdditionalCooldownUses") > 0 then
		-- if the skill does not have an innate cooldown, we need to pass the added otherwise things go boom
		return cooldown, rounded, skillData.cooldown and nil or addedCooldown, noCooldownChance
	else
		cooldown = m_ceil(cooldown * data.misc.ServerTickRate) / data.misc.ServerTickRate
		rounded = true
		return cooldown, rounded, addedCooldown, noCooldownChance
	end
end

local function calcWarcryCastTime(skillModList, skillCfg, skillData, actor)
	local baseSpeed = 1 / skillModList:Sum("BASE", skillCfg, "WarcryCastTime")
	local warcryCastTime = baseSpeed * calcLib.mod(skillModList, skillCfg, "WarcrySpeed") * calcs.actionSpeedMod(actor)
	warcryCastTime = m_min(warcryCastTime, data.misc.ServerTickRate)
	warcryCastTime = 1 / warcryCastTime
	if skillModList:Flag(skillCfg, "InstantWarcry") or skillData.SupportedByAutoexertion then
		warcryCastTime = 0
	end
	return warcryCastTime
end

--- Calculates effect of buff/debuff expiration rate on actors
local function calcBuffExpirationMult(actorDB, cfg)
	return 1 / m_max(data.misc.BuffExpirationSlowCap, calcLib.mod(actorDB, cfg, "BuffExpireFaster"))
end

function calcSkillDuration(skillModList, skillCfg, skillData, env, enemyDB)
	local durationMod = calcLib.mod(skillModList, skillCfg, "Duration", "PrimaryDuration", "DamagingAilmentDuration", skillData.mineDurationAppliesToSkill and "MineDuration" or nil)
	durationMod = m_max(durationMod, 0)
	local durationBase = (skillData.duration or 0) + skillModList:Sum("BASE", skillCfg, "Duration", "PrimaryDuration")
	local duration = durationBase * durationMod
	local debuffDurationMult = 1
	if env.mode_effective then
		debuffDurationMult = calcBuffExpirationMult(enemyDB, skillCfg)
	end
	if skillData.debuff then
		duration = duration * debuffDurationMult
	end
	return duration
end

local calcPenResist = function(resist, minPen, pen)
	return resist > minPen and m_max(resist - pen, minPen) or resist
end

local function calcHitResist(resist, minPen, pen, cannotElePenIgnore, ignoreNonNegativeEleRes)
	if not cannotElePenIgnore and ignoreNonNegativeEleRes and resist >= 0 then
		return 0
	end
	return cannotElePenIgnore and resist or calcPenResist(resist, minPen, pen)
end

-- Determine base leech value according to resource (using function to avoid repetition)
---@param resource string "Life" | "Mana" | "EnergyShield"
---@param dmgType string "Physical" | "Cold" | "Fire" | "Lightning" | "Chaos"
---@return number
local function getBaseLeech(resource, dmgType, skillModList, cfg, enemyDB)
	local leech = 0
	if (not skillModList:Flag(cfg, "Condition:No" .. resource .. "LeechFrom" .. dmgType .. "Damage")) and not (isElemental[dmgType] and skillModList:Flag(cfg, "No" .. resource .. "LeechFromElementalDamage")) then
		-- Check if converted physical leech (most PoE2 leech is physical only by default)
		local convertModName, convertFlag
		if isElemental[dmgType] and skillModList:Flag(cfg, resource .. "LeechBasedOnElementalDamage") then
			convertFlag = resource .. "LeechBasedOnElementalDamage"
			convertModName = "ElementalDamage" .. resource .. "Leech"
		elseif skillModList:Flag(cfg, resource .. "LeechBasedOn" .. dmgType .. "Damage") then
			convertFlag = resource .. "LeechBasedOn" .. dmgType .. "Damage"
			convertModName = dmgType .. "Damage" .. resource .. "Leech"
		end
		if convertModName and convertFlag then
			local tempCfg = copyTable(cfg, true)
			tempCfg.overrideCond = { ["No" .. resource .. "LeechFromPhysicalDamage"] = false } -- Need to force Condition to `false`, to calculate original phys leech values
			local physLeechMods = skillModList:Tabulate("BASE", tempCfg, "PhysicalDamage" .. resource .. "Leech")
			for _, entry in ipairs(physLeechMods) do
				-- Add new leech mods for that damage type with the same conditions, source, etc.
				local newMod = copyTable(entry.mod)
				newMod.name = convertModName
				-- Tags that specifically disable Physical Damage leech need to be removed
				local hasNoPhysLeech, tagIndex = modLib.hasTag(newMod, { type = "Condition", var = "No" .. resource .. "LeechFromPhysicalDamage", neg = true })
				if hasNoPhysLeech then
					t_remove(newMod, tagIndex)
				end
				if not skillModList:ReplaceModInternal(newMod) then -- using `ReplaceModInternal` instead of `ReplaceMod`, so I don't have to unpack the mod first
					skillModList:AddMod(newMod)
				end
			end
		end
		leech = skillModList:Sum("BASE", cfg, "Damage" .. resource .. "Leech", dmgType .. "Damage" .. resource .. "Leech", isElemental[dmgType] and "ElementalDamage" .. resource .. "Leech" or nil) + enemyDB:Sum("BASE", cfg, "SelfDamage" .. resource .. "Leech") / 100
	elseif skillModList:Flag(cfg, "Condition:No" .. resource .. "LeechFrom" .. dmgType .. "Damage") then
		-- dmgType leech should not apply, but still needs to exist for possible conversion so adding additional condition tag instead
		local noLeechFlagTag = { type = "Condition", var = "No" .. resource .. "LeechFrom" .. dmgType .. "Damage", neg = true }
		for _, entry in ipairs(skillModList:Tabulate("BASE", cfg, dmgType .. "Damage" .. resource .. "Leech")) do
			if not modLib.hasTag(entry.mod, noLeechFlagTag) then
				t_insert(entry.mod, noLeechFlagTag)
			end
		end
	end
	return leech and leech or 0
end
-- Performs all offensive calculations
---@param env Env
---@param actor Actor
---@param activeSkill ActiveSkill
function calcs.offence(env, actor, activeSkill)
	local modDB = actor.modDB
	local enemyDB = actor.enemy.modDB
	---@class Output
	local output = actor.output
	---@class Breakdown
	local breakdown = actor.breakdown

	local skillModList = activeSkill.skillModList
	local skillData = activeSkill.skillData
	local skillFlags
	if env.mode == "CALCS" then
		skillFlags = activeSkill.activeEffect.statSetCalcs.skillFlags
	else
		skillFlags = activeSkill.activeEffect.statSet.skillFlags
	end
	local skillCfg = activeSkill.skillCfg
	if skillData.showAverage then
		skillFlags.showAverage = true
	else
		skillFlags.notAverage = true
	end

	if skillFlags.disable then
		-- Skill is disabled
		output.CombinedDPS = 0
		return
	end

	-- Calculate armour break
	output.ArmourBreakPerHit = calcLib.val(skillModList, "ArmourBreakPerHit", skillCfg)

	local function getSkillNameFromFlag(skillModList, flag)
		local sourceMod = skillModList:Tabulate("FLAG", nil, flag)
		local sourceName = sourceMod[1] and sourceMod[1].mod and sourceMod[1].mod.source -- e.g. Skill:SupportExpandPlayer
		local dataSkill = env.data.skills[(sourceName:gsub("Skill:", ""))]
		return dataSkill and dataSkill.name
	end

	local function calcAreaOfEffect(skillModList, skillCfg, skillData, skillFlags, output, breakdown)
		local incArea, moreArea = calcLib.mods(skillModList, skillCfg, "AreaOfEffect", "AreaOfEffectPrimary")
		output.AreaOfEffectMod = calcAreaMod(incArea, moreArea)
		local radiusMod = calcLib.mod(skillModList, skillCfg, "AreaOfEffectRadius")
		if skillData.radiusIsWeaponRange then
			local range = 0
			if skillFlags.weapon1Attack then
				range = m_max(range, actor.weaponRange1)
			end
			if skillFlags.weapon2Attack then
				range = m_max(range, actor.weaponRange2)
			end
			skillData.radius = range + 2
		end
		if skillData.radius then
			skillFlags.area = true
			local baseRadius = skillData.radius + (skillData.radiusExtra or 0) + skillModList:Sum("BASE", skillCfg, "AreaOfEffect")
			output.AreaOfEffectRadius = calcRadius(baseRadius, output.AreaOfEffectMod, radiusMod)
			output.AreaOfEffectRadiusMetres = output.AreaOfEffectRadius / 10
			if breakdown then
				local incAreaBreakpoint, moreAreaBreakpoint, redAreaBreakpoint, lessAreaBreakpoint = calcRadiusBreakpoints(baseRadius, incArea, moreArea, radiusMod)
				breakdown.AreaOfEffectRadius = breakdown.area(baseRadius, output.AreaOfEffectMod, output.AreaOfEffectRadius, incAreaBreakpoint, moreAreaBreakpoint, redAreaBreakpoint, lessAreaBreakpoint, skillData.radiusLabel, radiusMod)
			end
			if skillData.radiusSecondary then
				local incAreaSecondary, moreAreaSecondary = calcLib.mods(skillModList, skillCfg, "AreaOfEffect", "AreaOfEffectSecondary")
				output.AreaOfEffectModSecondary = calcAreaMod(incAreaSecondary, moreAreaSecondary)
				baseRadius = skillData.radiusSecondary + (skillData.radiusExtra or 0)
				output.AreaOfEffectRadiusSecondary = calcRadius(baseRadius, output.AreaOfEffectModSecondary, radiusMod)
				output.AreaOfEffectRadiusSecondaryMetres = output.AreaOfEffectRadiusSecondary / 10
				if breakdown then
					local incAreaBreakpointSecondary, moreAreaBreakpointSecondary, redAreaBreakpointSecondary, lessAreaBreakpointSecondary
					if not skillData.projectileSpeedAppliesToMSAreaOfEffect then
						incAreaBreakpointSecondary, moreAreaBreakpointSecondary, redAreaBreakpointSecondary, lessAreaBreakpointSecondary = calcRadiusBreakpoints(baseRadius, incAreaSecondary, moreAreaSecondary, radiusMod)
					end
					breakdown.AreaOfEffectRadiusSecondary = breakdown.area(baseRadius, output.AreaOfEffectModSecondary, output.AreaOfEffectRadiusSecondary, incAreaBreakpointSecondary, moreAreaBreakpointSecondary, redAreaBreakpointSecondary, lessAreaBreakpointSecondary, skillData.radiusSecondaryLabel, radiusMod)
				end
			end
			if skillData.radiusTertiary then
				local incAreaTertiary, moreAreaTertiary = calcLib.mods(skillModList, skillCfg, "AreaOfEffect", "AreaOfEffectTertiary")
				output.AreaOfEffectModTertiary = calcAreaMod(incAreaTertiary, moreAreaTertiary)
				baseRadius = skillData.radiusTertiary + (skillData.radiusExtra or 0)
				if skillData.projectileSpeedAppliesToMSAreaOfEffect then
					local incSpeedTertiary, moreSpeedTertiary = calcLib.mods(skillModList, skillCfg, "ProjectileSpeed")
					output.SpeedModTertiary = round(round(incSpeedTertiary * moreSpeedTertiary, 10), 2)
					output.AreaOfEffectRadiusTertiary = calcMoltenStrikeTertiaryRadius(baseRadius, skillData.radiusSecondary, output.AreaOfEffectModTertiary, output.SpeedModTertiary)
					if breakdown then
						setMoltenStrikeTertiaryRadiusBreakdown(
							breakdown, skillData.radiusSecondary, baseRadius, skillData.radiusTertiaryLabel,
							incAreaTertiary, moreAreaTertiary, incSpeedTertiary, moreSpeedTertiary
						)
					end
				elseif skillData.radiusTertiaryBaseMargin then -- Currently only on explosive trap in the form of "Smaller explosions have between 30% reduced and 30% increased base radius at random"
					local margin = skillData.radiusTertiaryBaseMargin / 100
					local marginWidth = skillData.radiusTertiaryBaseMargin * 2 + 1
					-- Calculate all the possible base radii
					local baseRadiiOccurrences = {}
					for deviation = 1 - margin, 1 + margin + 0.01, 0.01 do
						local radiusForDeviation = m_floor(baseRadius * deviation)
						baseRadiiOccurrences[radiusForDeviation] = (baseRadiiOccurrences[radiusForDeviation] or 0) + 1
					end
					-- Calculate the modified radius for each base radius
					local sumOfRandomRadii = 0
					local radiusForBaseRadius = {}
					local radiiOccurrences = {}
					for adjustedBaseRadius, occurrenceCount in pairs(baseRadiiOccurrences) do
						local radiusForDeviation = calcRadius(adjustedBaseRadius, output.AreaOfEffectModTertiary, radiusMod)
						radiusForBaseRadius[adjustedBaseRadius] = radiusForDeviation
						sumOfRandomRadii = sumOfRandomRadii + radiusForDeviation * occurrenceCount
						radiiOccurrences[radiusForDeviation] = (radiiOccurrences[radiusForDeviation] or 0) + occurrenceCount
					end
					output.AreaOfEffectRadiusTertiary = sumOfRandomRadii / marginWidth
					output.AreaOfEffectRadiusTertiaryOccurrences = radiiOccurrences
					if breakdown then
						local out = {}
						local incAreaBreakpointTertiary, moreAreaBreakpointTertiary, redAreaBreakpointTertiary, lessAreaBreakpointTertiary = m_huge, m_huge, m_huge, m_huge
						t_insert(out, skillData.radiusTertiaryLabel)
						t_insert(out, localisation:Text("calc.offence.calc_area_of_effect.line", { value = m_floor(100 * m_sqrt(output.AreaOfEffectModTertiary)) / 100 }))
						if radiusMod ~= 1 then
							t_insert(out, localisation:Text("calc.offence.calc_area_of_effect.line_2", { radius_mod = radiusMod }))
						end
						local baseRadii = {}
						for adjustedBaseRadius in pairs(baseRadiiOccurrences) do
							t_insert(baseRadii, adjustedBaseRadius)
						end
						table.sort(baseRadii, function(a,b) return a < b end)
						for _, adjustedBaseRadius in ipairs(baseRadii) do
							t_insert(out, localisation:Text("calc.offence.calc_area_of_effect.line_3", { value = baseRadiiOccurrences[adjustedBaseRadius] / marginWidth * 100, value_2 = adjustedBaseRadius / 10, value_3 = radiusForBaseRadius[adjustedBaseRadius] / 10 }))
							local incAreaBreakpointTertiaryIntermediate, moreAreaBreakpointTertiaryIntermediate, redAreaBreakpointTertiaryIntermediate, lessAreaBreakpointTertiaryIntermediate = calcRadiusBreakpoints(adjustedBaseRadius, incAreaTertiary, moreAreaTertiary, radiusMod)
							incAreaBreakpointTertiary = m_min(incAreaBreakpointTertiary, incAreaBreakpointTertiaryIntermediate)
							moreAreaBreakpointTertiary = m_min(moreAreaBreakpointTertiary, moreAreaBreakpointTertiaryIntermediate)
							redAreaBreakpointTertiary = m_min(redAreaBreakpointTertiary, redAreaBreakpointTertiaryIntermediate)
							lessAreaBreakpointTertiary = m_min(lessAreaBreakpointTertiary, lessAreaBreakpointTertiaryIntermediate)
						end
						t_insert(out, localisation:Text("calc.offence.calc_area_of_effect.line_4", { inc_area_breakpoint_tertiary = incAreaBreakpointTertiary, more_area_breakpoint_tertiary = moreAreaBreakpointTertiary }))
						t_insert(out, localisation:Text("calc.offence.calc_area_of_effect.line_5", { red_area_breakpoint_tertiary = redAreaBreakpointTertiary, less_area_breakpoint_tertiary = lessAreaBreakpointTertiary }))
						t_insert(out, localisation:Text("calc.offence.calc_area_of_effect.line_6", { value = output.AreaOfEffectRadiusTertiary / 10 }))
						breakdown.AreaOfEffectRadiusTertiary = out
					end
				else
					output.AreaOfEffectRadiusTertiary = calcRadius(baseRadius, output.AreaOfEffectModTertiary, radiusMod)
					if breakdown then
						local incAreaBreakpointTertiary, moreAreaBreakpointTertiary, redAreaBreakpointTertiary, lessAreaBreakpointTertiary = calcRadiusBreakpoints(baseRadius, incAreaTertiary, moreAreaTertiary, radiusMod)
						breakdown.AreaOfEffectRadiusTertiary = breakdown.area(baseRadius, output.AreaOfEffectModTertiary, output.AreaOfEffectRadiusTertiary, incAreaBreakpointTertiary, moreAreaBreakpointTertiary, redAreaBreakpointTertiary, lessAreaBreakpointTertiary, skillData.radiusTertiaryLabel, radiusMod)
					end
				end
				output.AreaOfEffectRadiusTertiaryMetres = output.AreaOfEffectRadiusTertiary / 10
			end
		end
		if breakdown then
			breakdown.AreaOfEffectMod = { }
			if output.AreaOfEffectMod ~= 1 then
				breakdown.multiChain(breakdown.AreaOfEffectMod, {
					{ "%.2f ^8(increased/reduced)", 1 + skillModList:Sum("INC", skillCfg, "AreaOfEffect") / 100, formatKey = "calc.offence.calc_area_of_effect.factor", formatParams = { value = 2 } },
					{ "%.2f ^8(more/less)", skillModList:More(skillCfg, "AreaOfEffect"), formatKey = "calc.offence.calc_area_of_effect.factor_2", formatParams = { value = 2 } },
					total = s_format("= %.2f", output.AreaOfEffectMod),
				})
			end
		end
	end

	local function calcResistForType(damageType, cfg)
		local resist = enemyDB:Override(cfg, damageType.."Resist")
		local maxResist = enemyDB:Flag(nil, "DoNotChangeMaxResFromConfig") and data.misc.EnemyMaxResist or m_min(m_max(env.configInput["enemy"..damageType.."Resist"] or data.misc.EnemyMaxResist, data.misc.EnemyMaxResist), data.misc.MaxResistCap)
		if not resist then
			if env.modDB:Flag(nil, "Enemy"..damageType.."ResistEqualToYours") then
				resist = env.player.output[damageType.."Resist"]
			elseif env.partyMembers.modDB:Flag(nil, "Enemy"..damageType.."ResistEqualToYours") then
				resist = env.partyMembers.output[damageType.."Resist"]
			else
				resist = enemyDB:Sum("BASE", cfg, damageType.."Resist", isElemental[damageType] and "ElementalResist" or nil) * m_max(calcLib.mod(enemyDB, cfg, damageType.."Resist", isElemental[damageType] and "ElementalResist" or nil), 0)
			end
		end
		return m_max(m_min(resist, maxResist), data.misc.ResistFloor)
	end

	local function runSkillFunc(name)
		local func = activeSkill.activeEffect.grantedEffect[name]
		if func then
			func(activeSkill, output, breakdown)
		end
	end

	local function modHasSkillType(mod, skillType)
		for _, tag in ipairs(mod) do
			if tag.type == "SkillType" then
				if tag.skillType == skillType then
					return true
				end
				if tag.skillTypeList then
					for _, listedSkillType in ipairs(tag.skillTypeList) do
						if listedSkillType == skillType then
							return true
						end
					end
				end
			end
		end
		return false
	end

	runSkillFunc("initialFunc")

	skillCfg.skillCond["SkillIsTriggered"] = skillData.triggered
	if skillCfg.skillCond["SkillIsTriggered"] then
		skillFlags.triggered = true
	end
	skillCfg.skillCond["SkillIsFocused"] = skillData.chanceToTriggerOnFocus
	if skillCfg.skillCond["SkillIsFocused"] then
		skillFlags.focused = true
	end

	-- Update skill data
	for _, value in ipairs(skillModList:List(skillCfg, "SkillData")) do
		if value.merge == "MAX" then
			skillData[value.key] = m_max(value.value, skillData[value.key] or 0)
		else
			skillData[value.key] = value.value
		end
	end

	-- Add addition stat bonuses
	if skillModList:Flag(nil, "TransfigurationOfBody") then
		skillModList:NewMod("Damage", "INC", m_floor(skillModList:Sum("INC", nil, "Life") * data.misc.Transfiguration), "Transfiguration of Body", ModFlag.Attack)
	end
	if skillModList:Flag(nil, "TransfigurationOfMind") then
		skillModList:NewMod("Damage", "INC", m_floor(skillModList:Sum("INC", nil, "Mana") * data.misc.Transfiguration), "Transfiguration of Mind")
	end
	if skillModList:Flag(nil, "TransfigurationOfSoul") then
		skillModList:NewMod("Damage", "INC", m_floor(skillModList:Sum("INC", nil, "EnergyShield") * data.misc.Transfiguration), "Transfiguration of Soul", ModFlag.Spell)
	end

	if modDB:Flag(nil, "Elusive") and skillModList:Flag(nil, "SupportedByNightblade") then
		local elusiveEffect = output.ElusiveEffectMod / 100
		local nightbladeMulti = skillModList:Sum("BASE", nil, "NightbladeElusiveCritMultiplier")
		skillModList:NewMod("CritMultiplier", "BASE", m_floor(nightbladeMulti * elusiveEffect), "Nightblade")
	end

	-- set other limits
	output.ActiveTrapLimit = skillModList:Sum("BASE", skillCfg, "ActiveTrapLimit")
	output.ActiveMineLimit = skillModList:Sum("BASE", skillCfg, "ActiveMineLimit")

	-- set flask scaling
	output.LifeFlaskRecovery = env.itemModDB.multipliers["LifeFlaskRecovery"]
	output.LifeFlask1MaxCharges = env.itemModDB.multipliers["LifeFlask1MaxCharges"]
	output.LifeFlask2MaxCharges = env.itemModDB.multipliers["LifeFlask2MaxCharges"]
	output.ManaFlask1MaxCharges = env.itemModDB.multipliers["ManaFlask1MaxCharges"]
	output.ManaFlask2MaxCharges = env.itemModDB.multipliers["ManaFlask2MaxCharges"]

	if modDB.conditions["AffectedByEnergyBlade"] then
		local dmgMod = calcLib.mod(skillModList, skillCfg, "EnergyBladeDamage")
		local speedMod = calcLib.mod(skillModList, skillCfg, "EnergyBladeAttackSpeed")
		for slotName, weaponData in pairs({ ["Weapon 1"] = "weaponData1", ["Weapon 2"] = "weaponData2" }) do
			if actor.itemList[slotName] and actor.itemList[slotName].weaponData and actor.itemList[slotName].weaponData[1] and actor[weaponData].name and data.itemBases[actor[weaponData].name] then
				local weaponBaseData = data.itemBases[actor[weaponData].name].weapon
				actor[weaponData].CritChance = weaponBaseData.CritChanceBase
				actor[weaponData].AttackRate = weaponBaseData.AttackRateBase * speedMod
				actor[weaponData].Range = weaponBaseData.Range
				for _, damageType in ipairs(dmgTypeList) do
					actor[weaponData][damageType.."Min"] = (weaponBaseData[damageType.."Min"] or 0) + m_floor(skillModList:Sum("BASE", skillCfg, "EnergyBladeMin"..damageType) * dmgMod)
					actor[weaponData][damageType.."Max"] = (weaponBaseData[damageType.."Max"] or 0) + m_floor(skillModList:Sum("BASE", skillCfg, "EnergyBladeMax"..damageType) * dmgMod)
				end
			end
		end
	end

	-- account for Battlemage
	-- Note: we check conditions of Main Hand weapon using actor.itemList as actor.weaponData1 is populated with unarmed values when no weapon slotted.
	if skillModList:Flag(nil, "Battlemage") and actor.itemList["Weapon 1"] and actor.itemList["Weapon 1"].weaponData and actor.itemList["Weapon 1"].weaponData[1] then

		local multiplier = (skillModList:Max(skillCfg, "MainHandWeaponDamageAppliesToSpells") or 100) / 100
		for _, damageType in ipairs(dmgTypeList) do
			skillModList:NewMod(damageType.."Min", "BASE", m_floor((actor.weaponData1[damageType.."Min"] or 0) * multiplier), "Battlemage", ModFlag.Spell)
			skillModList:NewMod(damageType.."Max", "BASE", m_floor((actor.weaponData1[damageType.."Max"] or 0) * multiplier), "Battlemage", ModFlag.Spell)
		end
	end
	local weapon1info = env.data.weaponTypeInfo[actor.weaponData1.type]
	local weapon2info = env.data.weaponTypeInfo[actor.weaponData2.type]
	-- -- account for Spellblade
	-- Note: we check conditions of Main Hand weapon using actor.itemList as actor.weaponData1 is populated with unarmed values when no weapon slotted.
	local spellbladeMulti = skillModList:Max(skillCfg, "OneHandWeaponDamageAppliesToSpells")
	if spellbladeMulti and actor.itemList["Weapon 1"] and actor.itemList["Weapon 1"].weaponData and actor.itemList["Weapon 1"].weaponData[1] and weapon1info.melee and weapon1info.oneHand then
		local multiplier = spellbladeMulti / 100 * (weapon2info and 0.6 or 1)
		for _, damageType in ipairs(dmgTypeList) do
			skillModList:NewMod(damageType.."Min", "BASE", m_floor((actor.weaponData1[damageType.."Min"] or 0) * multiplier), "Spellblade Main Hand", ModFlag.Spell)
			skillModList:NewMod(damageType.."Max", "BASE", m_floor((actor.weaponData1[damageType.."Max"] or 0) * multiplier), "Spellblade Main Hand", ModFlag.Spell)
		end
		if weapon2info then
			for _, damageType in ipairs(dmgTypeList) do
				skillModList:NewMod(damageType.."Min", "BASE", m_floor((actor.weaponData2[damageType.."Min"] or 0) * multiplier), "Spellblade Off Hand", ModFlag.Spell)
				skillModList:NewMod(damageType.."Max", "BASE", m_floor((actor.weaponData2[damageType.."Max"] or 0) * multiplier), "Spellblade Off Hand", ModFlag.Spell)
			end
		end
	end
	-- Add bonus mods for Tactician's "Watch How I Do It" (technically this could be done in ModParser, but it would always add 10 mods instead of just the necessary ones)
	if actor.parent and modDB:Flag(nil, "GainMainHandDmgFromParent") and actor.parent.itemList["Weapon 1"] then
		local modSource = ""
		for i, value in ipairs(modDB:Tabulate("FLAG", nil, "GainMainHandDmgFromParent")) do
			modSource = value.mod.source
		end
		local modValue = actor.parent.modDB:Sum("BASE", { source = modSource }, "Multiplier:MainHandDamageToAllies")
		for _, damageType in ipairs(dmgTypeList) do
			if actor.parent.weaponData1[damageType .. "Min"] then
				skillModList:NewMod(damageType .. "Min", "BASE", 1, modSource, { type = "PercentStat", stat = damageType .. "MinOnWeapon 1", percent = modValue, actor = "parent" }, { type = "SkillType", skillType = SkillType.Attack })
			end
			if actor.parent.weaponData1[damageType .. "Max"] then
				skillModList:NewMod(damageType .. "Max", "BASE", 1, modSource, { type = "PercentStat", stat = damageType .. "MaxOnWeapon 1", percent = modValue, actor = "parent" }, { type = "SkillType", skillType = SkillType.Attack })
			end
		end
	end
	-- Apply Gemling's "Integrated Efficiency" Passive
	if skillModList:Flag(nil, "SkillDamageIncreasedPerRedSupport") or
		skillModList:Flag(nil, "SkillSpeedIncreasedPerGreenSupport") or
		skillModList:Flag(nil, "SkillCritChanceIncreasedPerBlueSupport") then

		local redSupportCount = 0
		local greenSupportCount = 0
		local blueSupportCount = 0
		for _, support in ipairs(activeSkill.supportList) do
			if support.gemData.grantedEffect.color == 1 then
				redSupportCount = redSupportCount + 1
			elseif support.gemData.grantedEffect.color == 2 then
				greenSupportCount = greenSupportCount + 1
			elseif support.gemData.grantedEffect.color == 3 then
				blueSupportCount = blueSupportCount + 1
			end
		end

		local lookupModData = function(flag)
			local result = 	actor.modDB:Tabulate("FLAG", nil, flag)
			return { source = result[1].mod.source, value = result[1].mod.value }
		end
		-- Conditionally check each to avoid future issues if a mod is reused in isolation
		local modData = { source = nil, value = nil }
		if skillModList:Flag(nil, "SkillDamageIncreasedPerRedSupport") then
			modData = lookupModData("SkillDamageIncreasedPerRedSupport")
			skillModList:NewMod("Damage", "INC", redSupportCount * modData.value, modData.source)
		end
		if skillModList:Flag(nil, "SkillSpeedIncreasedPerGreenSupport") then
			modData = lookupModData("SkillSpeedIncreasedPerGreenSupport")
			skillModList:NewMod("Speed", "INC", greenSupportCount * modData.value, modData.source)
			skillModList:NewMod("WarcrySpeed", "INC", greenSupportCount * modData.value, modData.source)
			skillModList:NewMod("TotemPlacementSpeed", "INC", greenSupportCount * modData.value, modData.source)
		end
		if skillModList:Flag(nil, "SkillCritChanceIncreasedPerBlueSupport") then
			modData = lookupModData("SkillCritChanceIncreasedPerBlueSupport")
			skillModList:NewMod("CritChance", "INC", blueSupportCount * modData.value, modData.source)
		end
	end
	if skillModList:Flag(nil, "MinionDamageAppliesToPlayer") or skillModList:Flag(skillCfg, "MinionDamageAppliesToPlayer") then
		-- Minion Damage conversion from Spiritual Aid and The Scourge
		local multiplier = (skillModList:Max(skillCfg, "ImprovedMinionDamageAppliesToPlayer") or 100) / 100
		for _, value in ipairs(skillModList:List(skillCfg, "MinionModifier")) do
			if value.mod.name == "Damage" and value.mod.type == "INC" then
				local mod = value.mod
				local modifiers = calcLib.getConvertedModTags(mod, multiplier, true)
				skillModList:NewMod("Damage", "INC", mod.value * multiplier, mod.source, mod.flags, mod.keywordFlags, unpack(modifiers))
			end
		end
	end
	if skillModList:Flag(nil, "CompanionDamageAppliesToPlayer") then
		-- Companion Damage conversion from Inspiring Ally
		local tempCfg = copyTable(skillCfg, true)
		tempCfg.skillTypes[SkillType.CreatesCompanion] = true -- Add companion skill tag to cfg so it doesn't fail
		for _, value in ipairs(skillModList:Tabulate("LIST", tempCfg, "MinionModifier")) do
			local mod = value.value and value.value.mod
			if modHasSkillType(value.mod, SkillType.CreatesCompanion) and mod and mod.name == "Damage" and mod.type == "INC" then
				skillModList:NewMod("Damage", "INC", mod.value, mod.source, mod.flags, mod.keywordFlags, unpack(mod))
			end
		end
	end
	if skillModList:Flag(nil, "MinionAttackSpeedAppliesToPlayer") then
		-- Minion Damage conversion from Spiritual Command
		local multiplier = (skillModList:Max(skillCfg, "ImprovedMinionAttackSpeedAppliesToPlayer") or 100) / 100
		-- Minion Attack Speed conversion from Spiritual Command
		for _, value in ipairs(skillModList:List(skillCfg, "MinionModifier")) do
			if value.mod.name == "Speed" and value.mod.type == "INC" and (value.mod.flags == 0 or band(value.mod.flags, ModFlag.Attack) ~= 0) then
				local modifiers = calcLib.getConvertedModTags(value.mod, multiplier, true)
				skillModList:NewMod("Speed", "INC", value.mod.value * multiplier, value.mod.source, ModFlag.Attack, value.mod.keywordFlags, unpack(modifiers))
			end
		end
	end
	if skillModList:Flag(nil, "SpellDamageAppliesToAttacks") then
		-- Spell Damage conversion from Crown of Eyes, Kinetic Bolt, and the Wandslinger notable
		local multiplier = (skillModList:Max(skillCfg, "ImprovedSpellDamageAppliesToAttacks") or 100) / 100
		for i, value in ipairs(skillModList:Tabulate("INC", { flags = ModFlag.Spell }, "Damage")) do
			local mod = value.mod
			if band(mod.flags, ModFlag.Spell) ~= 0 then
				local modifiers = calcLib.getConvertedModTags(mod, multiplier)
				skillModList:NewMod("Damage", "INC", mod.value * multiplier, mod.source, bor(band(mod.flags, bnot(ModFlag.Spell)), ModFlag.Attack), mod.keywordFlags, unpack(modifiers))
				if mod.source == "Strength" then -- Prevent double-dipping from converted strength's damage bonus
					skillModList:ReplaceMod("PhysicalDamage", "INC", 0, "Strength", ModFlag.Melee)
					skillModList:ReplaceMod("PhysicalDamage", "INC", 0, "Strength", bor(ModFlag.Attack, ModFlag.Projectile))
				end
			end
		end
	end

	-- Apply thorns-derived modifiers to hits
	if skillModList:Flag(nil, "ThornsDamageApplyToAttackDamage") then
		for _, value in ipairs(skillModList:Tabulate("INC", { flags = ModFlag.Thorns }, "Damage")) do
			local mod = value.mod
			skillModList:NewMod("Damage", "INC", mod.value, mod.source, bor(band(mod.flags, bnot(ModFlag.Thorns)), ModFlag.Attack), mod.keywordFlags, unpack(mod))
		end
	end

	if skillModList:Flag(nil, "CastSpeedAppliesToAttacks") then
		-- Get all increases for this; assumption is that multiple sources would not stack, so find the max
		local multiplier = (skillModList:Max(skillCfg, "ImprovedCastSpeedAppliesToAttacks") or 100) / 100
		for i, value in ipairs(skillModList:Tabulate("INC", { flags = ModFlag.Cast }, "Speed")) do
			local mod = value.mod
			-- Add a new mod for all mods that are cast only
			-- Replace this with a single mod for the sum?
			if band(mod.flags, ModFlag.Cast) ~= 0 then
				local modifiers = calcLib.getConvertedModTags(mod, multiplier)
				skillModList:NewMod("Speed", "INC", mod.value * multiplier, mod.source, bor(band(mod.flags, bnot(ModFlag.Cast)), ModFlag.Attack), mod.keywordFlags, unpack(modifiers))
			end
		end
	end
	if skillModList:Flag(nil, "CastSpeedAppliesToProjectileSpeed") then
		-- Bow mastery projectile speed to damage with bows conversion
		local multiplier = (skillModList:Max(skillCfg, "ImprovedCastSpeedAppliesToProjectileSpeed") or 100) / 100
		for i, value in ipairs(skillModList:Tabulate("INC", { flags = ModFlag.Cast }, "Speed")) do
			local mod = value.mod
			local modifiers = calcLib.getConvertedModTags(mod, multiplier)
			skillModList:NewMod("ProjectileSpeed", mod.type, mod.value * multiplier, mod.source, band(mod.flags, bnot(ModFlag.Cast)), mod.keywordFlags, unpack(modifiers))
		end
	end
	if skillModList:Flag(nil, "ProjectileSpeedAppliesToBowDamage") then
		-- Bow mastery projectile speed to damage with bows conversion
		for i, value in ipairs(skillModList:Tabulate("INC", { flags = ModFlag.Bow }, "ProjectileSpeed")) do
			local mod = value.mod
			skillModList:NewMod("Damage", mod.type, mod.value, mod.source, bor(ModFlag.Bow, ModFlag.Hit), mod.keywordFlags, unpack(mod))
		end
	end
	if skillModList:Flag(nil, "WarcryDamageAppliesToSkill") then
		-- Fortifying Cry mod
		for i, value in ipairs(skillModList:Tabulate("INC", { keywordFlags = KeywordFlag.Warcry }, "Damage")) do
			local mod = value.mod
			if band(mod.keywordFlags, KeywordFlag.Warcry) ~= 0 then
				skillModList:NewMod("Damage", mod.type, mod.value, mod.source, mod.flags, band(mod.keywordFlags, bnot(KeywordFlag.Warcry)), unpack(mod))
			end
		end
		for i, value in ipairs(skillModList:Tabulate("MORE", { keywordFlags = KeywordFlag.Warcry }, "Damage")) do
			local mod = value.mod
			if band(mod.keywordFlags, KeywordFlag.Warcry) ~= 0 then
				skillModList:NewMod("Damage", mod.type, mod.value, mod.source, mod.flags, band(mod.keywordFlags, bnot(KeywordFlag.Warcry)), unpack(mod))
			end
		end
	end
	if skillModList:Flag(nil, "PinBuildupInsteadOfHeavyStunBuildup") then
		-- Fortifying Cry mod
		for i, value in ipairs(skillModList:Tabulate("INC", { }, "EnemyHeavyStunBuildup")) do
			local mod = value.mod
			skillModList:NewMod("EnemyPinBuildup", mod.type, mod.value, mod.source, mod.flags, mod.keywordFlags, unpack(mod))
		end
		for i, value in ipairs(skillModList:Tabulate("MORE", { }, "EnemyHeavyStunBuildup")) do
			local mod = value.mod
			skillModList:NewMod("EnemyPinBuildup", mod.type, mod.value, mod.source, mod.flags, mod.keywordFlags, unpack(mod))
		end
	end
	if skillModList:Flag(nil, "FreezeBuildupInsteadOfStunBuildup") then
		-- Kaltenhalt
		for i, value in ipairs(skillModList:Tabulate("INC", { }, "EnemyHeavyStunBuildup")) do
			local mod = value.mod
			skillModList:NewMod("EnemyFreezeBuildup", mod.type, mod.value, mod.source, mod.flags, mod.keywordFlags, unpack(mod))
		end
		for i, value in ipairs(skillModList:Tabulate("MORE", { }, "EnemyHeavyStunBuildup")) do
			local mod = value.mod
			skillModList:NewMod("EnemyFreezeBuildup", mod.type, mod.value, mod.source, mod.flags, mod.keywordFlags, unpack(mod))
		end
	end
	if skillModList:Flag(nil, "ProjectileSpeedAppliesToProjectileDamage") then
		-- Projectile speed to projectile damage conversion
		for i, value in ipairs(skillModList:Tabulate("INC", { }, "ProjectileSpeed")) do
			local mod = value.mod
			skillModList:NewMod("Damage", mod.type, mod.value, mod.source, ModFlag.Projectile, mod.keywordFlags, unpack(mod))
		end
	end
	if skillModList:Flag(nil, "ClawDamageAppliesToUnarmed") then
		-- Claw Damage conversion from Rigwald's Curse
		for i, value in ipairs(skillModList:Tabulate("INC", { flags = bor(ModFlag.Claw, ModFlag.Hit), keywordFlags = KeywordFlag.Hit }, "Damage")) do
			local mod = value.mod
			if band(mod.flags, ModFlag.Claw) ~= 0 then
				skillModList:NewMod("Damage", mod.type, mod.value, mod.source, bor(band(mod.flags, bnot(ModFlag.Claw)), ModFlag.Unarmed, ModFlag.Melee), mod.keywordFlags, unpack(mod))
			end
		end
	end
	if skillModList:Flag(nil, "ClawAttackSpeedAppliesToUnarmed") then
		-- Claw Attack Speed conversion from Rigwald's Curse
		for i, value in ipairs(skillModList:Tabulate("INC", { flags = bor(ModFlag.Claw, ModFlag.Attack, ModFlag.Hit) }, "Speed")) do
			local mod = value.mod
			if band(mod.flags, ModFlag.Claw) ~= 0 and band(mod.flags, ModFlag.Attack) ~= 0 then
				skillModList:NewMod("Speed", mod.type, mod.value, mod.source, bor(band(mod.flags, bnot(ModFlag.Claw)), ModFlag.Unarmed), mod.keywordFlags, unpack(mod))
			end
		end
	end
	if skillModList:Flag(nil, "ClawCritChanceAppliesToUnarmed") then
		-- Claw Crit Chance conversion from Rigwald's Curse
		for i, value in ipairs(skillModList:Tabulate("INC", { flags = bor(ModFlag.Claw, ModFlag.Hit) }, "CritChance")) do
			local mod = value.mod
			if band(mod.flags, ModFlag.Claw) ~= 0 then
				skillModList:NewMod("CritChance", mod.type, mod.value, mod.source, bor(band(mod.flags, bnot(ModFlag.Claw)), ModFlag.Unarmed), mod.keywordFlags, unpack(mod))
			end
		end
	end
	if skillModList:Flag(nil, "ClawCritChanceAppliesToMinions") then
		-- Claw Crit Chance conversion from Law of the Wilds
		for i, value in ipairs(skillModList:Tabulate("INC", { flags = bor(ModFlag.Claw, ModFlag.Hit) }, "CritChance")) do
			local mod = value.mod
			if band(mod.flags, ModFlag.Claw) ~= 0 then
				env.minion.modDB:NewMod("CritChance", mod.type, mod.value, mod.source)
			end
		end
	end
	if skillModList:Flag(nil, "ClawCritMultiplierAppliesToMinions") then
		-- Claw Crit Multi conversion from Law of the Wilds
		for i, value in ipairs(skillModList:Tabulate("BASE", { flags = bor(ModFlag.Claw, ModFlag.Hit) }, "CritMultiplier")) do
			local mod = value.mod
			if band(mod.flags, ModFlag.Claw) ~= 0 then
				env.minion.modDB:NewMod("CritMultiplier", mod.type, mod.value, mod.source)
			end
		end
	end
	if skillModList:Flag(nil, "CritChanceIncreasedByUncappedLightningRes") then
		for i, value in ipairs(modDB:Tabulate("FLAG", nil, "CritChanceIncreasedByUncappedLightningRes")) do
			local mod = value.mod
			skillModList:NewMod("CritChance", "INC", output.LightningResistTotal, mod.source)
			break
		end
	end
	if skillModList:Flag(nil, "CritChanceIncreasedByLightningRes") then
		for i, value in ipairs(modDB:Tabulate("FLAG", nil, "CritChanceIncreasedByLightningRes")) do
			local mod = value.mod
			skillModList:NewMod("CritChance", "INC", output.LightningResist, mod.source)
			break
		end
	end
	if skillModList:Flag(nil, "CritChanceIncreasedByOvercappedLightningRes") then
		for i, value in ipairs(modDB:Tabulate("FLAG", nil, "CritChanceIncreasedByOvercappedLightningRes")) do
			local mod = value.mod
			skillModList:NewMod("CritChance", "INC", output.LightningResistOverCap, mod.source)
			break
		end
	end
	if skillModList:Flag(nil, "CritChanceIncreasedBySpellSuppressChance") then
		for i, value in ipairs(modDB:Tabulate("FLAG", nil, "CritChanceIncreasedBySpellSuppressChance")) do
			local mod = value.mod
			skillModList:NewMod("CritChance", "INC", output.SpellSuppressionChance, mod.source)
			break
		end
	end
	if skillModList:Flag(nil, "LightRadiusAppliesToAccuracy") then
		-- Light Radius conversion from Corona Solaris
		for i, value in ipairs(skillModList:Tabulate("INC",  { }, "LightRadius")) do
			local mod = value.mod
			skillModList:NewMod("Accuracy", "INC", mod.value, mod.source, mod.flags, mod.keywordFlags, unpack(mod))
		end
	end
	if skillModList:Flag(nil, "LightRadiusAppliesToAreaOfEffect") then
		-- Light Radius conversion from Wreath of Phrecia
		for i, value in ipairs(skillModList:Tabulate("INC",  { }, "LightRadius")) do
			local mod = value.mod
			skillModList:NewMod("AreaOfEffect", "INC", m_floor(mod.value / 2), mod.source, mod.flags, mod.keywordFlags, unpack(mod))
		end
	end
	if skillModList:Flag(nil, "LightRadiusAppliesToDamage") then
		-- Light Radius conversion from Wreath of Phrecia
		for i, value in ipairs(skillModList:Tabulate("INC",  { }, "LightRadius")) do
			local mod = value.mod
			skillModList:NewMod("Damage", "INC", mod.value, mod.source, mod.flags, mod.keywordFlags, unpack(mod))
		end
	end
	if skillModList:Flag(nil, "CastSpeedAppliesToTrapThrowingSpeed") then
		-- Cast Speed conversion from Slavedriver's Hand
		for i, value in ipairs(skillModList:Tabulate("INC", { flags = ModFlag.Cast }, "Speed")) do
			local mod = value.mod
			if (mod.flags == 0 or band(mod.flags, ModFlag.Cast) ~= 0) then
				skillModList:NewMod("TrapThrowingSpeed", "INC", mod.value, mod.source, band(mod.flags, bnot(ModFlag.Cast), bnot(ModFlag.Attack)), mod.keywordFlags, unpack(mod))
			end
		end
	end
	if skillData.arrowSpeedAppliesToAreaOfEffect then
		-- Arrow Speed conversion for Galvanic Arrow
		for i, value in ipairs(skillModList:Tabulate("INC", { flags = ModFlag.Bow }, "ProjectileSpeed")) do
			local mod = value.mod
			skillModList:NewMod("AreaOfEffect", "INC", mod.value, mod.source, mod.flags, mod.keywordFlags, unpack(mod))
		end
	end
	if activeSkill.skillTypes[SkillType.Barrageable] and skillModList:Flag(nil, "SequentialProjectiles") and not skillModList:Flag(nil, "OneShotProj") and not skillModList:Flag(nil, "NoAdditionalProjectiles") and not skillModList:Flag(nil, "TriggeredBySnipe") then
		-- Applies DPS multiplier based on projectile count
		if skillModList:Sum("BASE", skillCfg, "BarrageRepeats") > 0 then
			local dpsMulti = (1 + skillModList:Sum("BASE", skillCfg, "BarrageRepeats")) * (calcLib.mod(skillModList, skillCfg, "BarrageRepeatDamage"))
			skillModList:NewMod("DPS", "MORE", dpsMulti, "Barrage Repeats")
		else
			local additionalProjectiles = (skillModList:Sum("BASE", skillCfg, "ProjectileCount") + 2 * skillModList:Sum("BASE", skillCfg, "TwoAdditionalProjectilesChance") / 100 + skillModList:Sum("BASE", skillCfg, "SurpassingProjectileChance") / 100 - 1) * skillModList:More(skillCfg, "ProjectileCount")
			if additionalProjectiles > 0 then
				local barrageAttackTimePenalty = skillModList:Sum("BASE", skillCfg, "BarrageAttackTimePenalty")
				if barrageAttackTimePenalty == 0 then barrageAttackTimePenalty = 100 end -- If not otherwise specified on the skill, each additional projectile adds 100% of attack time
				skillModList:ReplaceMod("SkillAttackTime", "MORE", barrageAttackTimePenalty * additionalProjectiles, activeSkill.activeEffect.grantedEffect.name .. s_format(": %d%% attack time per add. projectile", barrageAttackTimePenalty) )
				skillModList:NewMod("DPS", "MORE", skillModList:Sum("BASE", skillCfg, "ProjectileCount") + 2 * skillModList:Sum("BASE", skillCfg, "TwoAdditionalProjectilesChance") / 100 + skillModList:Sum("BASE", skillCfg, "SurpassingProjectileChance") / 100, "Barrage Repeats")
			end
		end
	end
	local function repeatSkillTypesCheck(activeSkillTypes)
		local excludeSkillTypes = { SkillType.Instant, SkillType.Channel, SkillType.Triggered, SkillType.Retaliation, SkillType.NonRepeatable }
		for _, type in ipairs(excludeSkillTypes) do
			if activeSkillTypes[type] then
				return false
			end
		end
		return not skillModList:Flag(nil, "CannotRepeat") and ((activeSkillTypes[SkillType.Attack] or activeSkillTypes[SkillType.Spell]))
	end
	output.Repeats = 1 + (repeatSkillTypesCheck(activeSkill.skillTypes) and skillModList:Sum("BASE", skillCfg, "RepeatCount") or 0)
	if output.Repeats > 1 then
		output.RepeatCount = output.Repeats
		-- handle all the multipliers from Repeats
		if env.configInput.repeatMode ~= "NONE" then
			for i, value in ipairs(skillModList:Tabulate("INC", skillCfg, "RepeatAreaOfEffect")) do
				local mod = value.mod
				local modValue = mod.value
				if env.configInput.repeatMode == "AVERAGE" then
					modValue = modValue * (output.Repeats - 1) / output.Repeats
				end
				skillModList:NewMod("AreaOfEffect", "INC", modValue, mod.source, mod.flags, mod.keywordFlags, unpack(mod))
			end
			for i, value in ipairs(skillModList:Tabulate("INC", skillCfg, "RepeatFinalAreaOfEffect")) do
				local mod = value.mod
				local modValue = mod.value
				if env.configInput.repeatMode == "AVERAGE" then
					modValue = modValue / output.Repeats
				end
				skillModList:NewMod("AreaOfEffect", "INC", modValue, mod.source, mod.flags, mod.keywordFlags, unpack(mod))
			end
			for i, value in ipairs(skillModList:Tabulate("INC", skillCfg, "RepeatPerRepeatAreaOfEffect")) do
				local mod = value.mod
				local modValue = mod.value * (output.Repeats - 1)
				if env.configInput.repeatMode == "AVERAGE" then
					modValue = modValue / 2
				end
				skillModList:NewMod("AreaOfEffect", "INC", modValue, mod.source, mod.flags, mod.keywordFlags, unpack(mod))
			end
			for i, value in ipairs(skillModList:Tabulate("BASE", skillCfg, "RepeatFinalDoubleDamageChance")) do
				local mod = value.mod
				local modValue = mod.value
				if env.configInput.repeatMode == "AVERAGE" then
					modValue = modValue / output.Repeats
				end
				skillModList:NewMod("DoubleDamageChance", "BASE", modValue, mod.source, mod.flags, mod.keywordFlags, unpack(mod))
			end
			local DamageFinalMoreValueTotal = 1
			local DamageMoreValueTotal = 0
			for i, value in ipairs(skillModList:Tabulate("MORE", skillCfg, "RepeatFinalDamage")) do
				local mod = value.mod
				local modValue = mod.value
				DamageFinalMoreValueTotal = DamageFinalMoreValueTotal * (1 + modValue / 100)
				DamageMoreValueTotal = DamageMoreValueTotal + modValue
				if env.configInput.repeatMode == "AVERAGE" and not skillModList:Flag(nil, "OnlyFinalRepeat") then
					modValue = modValue / output.Repeats
				end
				skillModList:NewMod("Damage", "MORE", modValue, mod.source, mod.flags, mod.keywordFlags, unpack(mod))
			end
			for i, value in ipairs(skillModList:Tabulate("MORE", skillCfg, "RepeatPerRepeatDamage")) do
				local mod = value.mod
				local modValue = mod.value * (output.Repeats - 1)
				if env.configInput.repeatMode == "AVERAGE" then
					if DamageFinalMoreValueTotal ~= 1 then
						-- sum from 0 to num Repeats the damage each one does, multiplied by the other repeat multipliers,
						-- divide the total by the average other repeat multipliers and divide by number of repeats
						-- eg greater echo with 20Q div echo is (100 + 130 + 160 + 190*1.6)/1.15/4 - 100 = 50.87% more damage
						modValue = ((100 + mod.value * (output.Repeats - 2) / 2) * (output.Repeats - 1) + (100 + mod.value * (output.Repeats - 1)) * DamageFinalMoreValueTotal) / (output.Repeats + DamageMoreValueTotal / 100) - 100
					else
						modValue = modValue / 2
					end
				end
				skillModList:NewMod("Damage", "MORE", modValue, mod.source, mod.flags, mod.keywordFlags, unpack(mod))
			end

			local lastMod = nil
			DamageFinalMoreValueTotal = DamageMoreValueTotal
			for _, repeatCount in ipairs({{2, "One"}, {3, "Two"}, {4, "Three"}}) do
				if repeatCount[1] > output.Repeats then
					break
				elseif env.configInput.repeatMode == "AVERAGE" then
					for i, value in ipairs(skillModList:Tabulate("MORE", skillCfg, "Repeat"..repeatCount[2].."Damage")) do
						DamageMoreValueTotal = DamageMoreValueTotal + value.mod.value
						lastMod = value.mod
					end
				elseif repeatCount[1] == output.Repeats then
					for i, value in ipairs(skillModList:Tabulate("MORE", skillCfg, "Repeat"..repeatCount[2].."Damage")) do
						skillModList:NewMod("Damage", "MORE", value.mod.value, value.mod.source, value.mod.flags, value.mod.keywordFlags, unpack(value.mod))
					end
				end
			end
			if env.configInput.repeatMode == "AVERAGE" then
				if lastMod then
					skillModList:NewMod("Damage", "MORE", (DamageMoreValueTotal / output.Repeats + 100) / (1 + DamageFinalMoreValueTotal / output.Repeats / 100) - 100, lastMod.source, lastMod.flags, lastMod.keywordFlags, unpack(lastMod))
				end
			end
			if skillModList:Flag(nil, "FinalRepeatSumsDamage") then
				for i, value in ipairs(skillModList:Tabulate("FLAG", skillCfg, "FinalRepeatSumsDamage")) do
					skillModList:NewMod("Damage", "MORE", (100 * output.Repeats + DamageFinalMoreValueTotal) / (1 + DamageFinalMoreValueTotal / 100) - 100, value.mod.source, value.mod.flags, value.mod.keywordFlags, unpack(value.mod))
				end
			end
			if skillFlags.trap or skillFlags.mine then
				skillModList:NewMod("DPS", "MORE", (output.Repeats - 1) * 100, "Repeat Count")
			end
		end
	end
	if skillData.gainPercentBaseWandDamageToSpells then
		local mult = skillData.gainPercentBaseWandDamageToSpells / 100
		if actor.weaponData1.type == "Wand" and actor.weaponData2.type == "Wand" then
			for _, damageType in ipairs(dmgTypeList) do
				skillModList:NewMod(damageType.."Min", "BASE", m_floor(((actor.weaponData1[damageType.."Min"] or 0) + (actor.weaponData2[damageType.."Min"] or 0)) / 2 * mult), "Spellslinger", ModFlag.Spell)
				skillModList:NewMod(damageType.."Max", "BASE", m_floor(((actor.weaponData1[damageType.."Max"] or 0) + (actor.weaponData2[damageType.."Max"] or 0)) / 2 * mult), "Spellslinger", ModFlag.Spell)
			end
		elseif actor.weaponData1.type == "Wand" then
			for _, damageType in ipairs(dmgTypeList) do
				skillModList:NewMod(damageType.."Min", "BASE", m_floor((actor.weaponData1[damageType.."Min"] or 0) * mult), "Spellslinger", ModFlag.Spell)
				skillModList:NewMod(damageType.."Max", "BASE", m_floor((actor.weaponData1[damageType.."Max"] or 0) * mult), "Spellslinger", ModFlag.Spell)
			end
		elseif actor.weaponData2.type == "Wand" then
			for _, damageType in ipairs(dmgTypeList) do
				skillModList:NewMod(damageType.."Min", "BASE", m_floor((actor.weaponData2[damageType.."Min"] or 0) * mult), "Spellslinger", ModFlag.Spell)
				skillModList:NewMod(damageType.."Max", "BASE", m_floor((actor.weaponData2[damageType.."Max"] or 0) * mult), "Spellslinger", ModFlag.Spell)
			end
		end
	end
	if skillData.gainPercentBaseDaggerDamageToSpells then
		local mult = skillData.gainPercentBaseDaggerDamageToSpells / 100
		if actor.weaponData1.type == "Dagger" and actor.weaponData2.type == "Dagger" then
			for _, damageType in ipairs(dmgTypeList) do
				skillModList:NewMod(damageType.."Min", "BASE", m_floor(((actor.weaponData1[damageType.."Min"] or 0) + (actor.weaponData2[damageType.."Min"] or 0)) / 2 * mult), "Blade Blast of Dagger Detonation", ModFlag.Spell)
				skillModList:NewMod(damageType.."Max", "BASE", m_floor(((actor.weaponData1[damageType.."Max"] or 0) + (actor.weaponData2[damageType.."Max"] or 0)) / 2 * mult), "Blade Blast of Dagger Detonation", ModFlag.Spell)
			end
		elseif actor.weaponData1.type == "Dagger" then
			for _, damageType in ipairs(dmgTypeList) do
				skillModList:NewMod(damageType.."Min", "BASE", m_floor((actor.weaponData1[damageType.."Min"] or 0) * mult), "Blade Blast of Dagger Detonation", ModFlag.Spell)
				skillModList:NewMod(damageType.."Max", "BASE", m_floor((actor.weaponData1[damageType.."Max"] or 0) * mult), "Blade Blast of Dagger Detonation", ModFlag.Spell)
			end
		elseif actor.weaponData2.type == "Dagger" then
			for _, damageType in ipairs(dmgTypeList) do
				skillModList:NewMod(damageType.."Min", "BASE", m_floor((actor.weaponData2[damageType.."Min"] or 0) * mult), "Blade Blast of Dagger Detonation", ModFlag.Spell)
				skillModList:NewMod(damageType.."Max", "BASE", m_floor((actor.weaponData2[damageType.."Max"] or 0) * mult), "Blade Blast of Dagger Detonation", ModFlag.Spell)
			end
		end
	end
	-- Crossbow calculations
	-- Calculate ammo stats for bolt skills
	if activeSkill.skillTypes[SkillType.CrossbowSkill] and not (activeSkill.skillTypes[SkillType.Grenade] or activeSkill.skillTypes[SkillType.CrossbowAmmoSkill]) then
		local ammoStats = calcCrossbowAmmoStats(actor, activeSkill)
		activeSkill.activeEffect.grantedEffectLevel.cost = ammoStats.cost -- inherit base mana cost
		skillData.boltCount = ammoStats.boltCount
		skillData.reloadTime = ammoStats.reloadTime
	end

	if activeSkill.skillTypes[SkillType.Grenade] then
		local detonateTwice = m_min(skillModList:Sum("BASE", skillCfg, "GrenadeActivateTwice"), 100)
		modDB:NewMod("DPS", "MORE", detonateTwice, "Grenade Activate Twice")
	end

	-- Dual wield DPS multiplier
	if skillFlags.bothWeaponAttack and skillData.doubleHitsWhenDualWielding then
		skillModList:NewMod("DPS", "MORE", 100, "Hits with both weapons")
	end

	if skillModList:Flag(nil, "HasSeals") and not skillModList:Flag(nil, "NoRepeatBonuses") then
		-- Applies seal bonuses based on seal count
		local totalCastSpeed = 1 / activeSkill.activeEffect.grantedEffect.castTime * calcLib.mod(skillModList, skillCfg, "Speed")
		output.SealCooldown = activeSkill.activeEffect.grantedEffect.castTime * skillModList:Sum("BASE", skillCfg, "SealGainFrequency") / calcLib.mod(skillModList, skillCfg, "SealGainFrequency") / 100
		output.SealMax = skillModList:Sum("BASE", skillCfg, "SealCount")
		output.TimeMaxSeals = output.SealCooldown * output.SealMax

		if skillModList:Flag(nil, "DamageSeal") then
			output.AverageBurstHits = output.SealMax
		end
		if skillModList:Flag(nil, "DamageSeal") and not skillData.hitTimeOverride then
			local skillName = getSkillNameFromFlag(skillModList, "DamageSeal") or "Support"
			if skillModList:Flag(nil, "UseMaxUnleash") then
				for i, value in ipairs(skillModList:Tabulate("INC",  { }, "MaxSealCrit")) do
					local mod = value.mod
					skillModList:NewMod("CritChance", "INC", mod.value, mod.source, mod.flags, mod.keywordFlags, unpack(mod))
				end
				env.player.mainSkill.skillModList:NewMod("DPS", "MORE", (output.SealMax * calcLib.mod(skillModList, skillCfg, "SealRepeatPenalty")) * 100, skillName)
				env.player.mainSkill.skillData.hitTimeOverride = m_max(output.TimeMaxSeals, totalCastSpeed * 1.1)
			else
				env.player.mainSkill.skillModList:NewMod("DPS", "MORE", round(1 / output.SealCooldown / (totalCastSpeed * 1.1) * calcLib.mod(skillModList, skillCfg, "SealRepeatPenalty") * 100, 2), skillName)
			end
		end
		if skillModList:Flag(nil, "AreaSeal") then
			local skillName = getSkillNameFromFlag(skillModList, "AreaSeal") or "Support"
			local sealArea = (calcLib.mod(skillModList, skillCfg, "SealRepeatPenalty") - 1) * 100
			if skillModList:Flag(nil, "UseMaxUnleash") then
				env.player.mainSkill.skillModList:NewMod("AreaOfEffect", "INC", output.SealMax * sealArea, skillName)
				env.player.mainSkill.skillData.hitTimeOverride = m_max(output.TimeMaxSeals, totalCastSpeed * 1.1)
			else
				env.player.mainSkill.skillModList:NewMod("AreaOfEffect", "INC", round(1 / output.SealCooldown / totalCastSpeed * sealArea, 2), skillName)
			end
		end

		if breakdown then
			breakdown.SealGainTime = { }
			breakdown.multiChain(breakdown.SealGainTime, {
				label = "Gain frequency:", labelKey = "ui.calc_offence.offence.label_3",
				base = { "%.2fs ^8(base cast time)", activeSkill.activeEffect.grantedEffect.castTime, formatKey = "calc.offence.offence.factor", formatParams = { cast_time = 2 } },
				{ "%.2f ^8(increased/reduced gain frequency)", 1 + skillModList:Sum("INC", skillCfg, "SealGainFrequency") / 100, formatKey = "calc.offence.offence.factor_2", formatParams = { value = 2 } },
				{ "%d%% ^8(of cast time)", skillModList:Sum("BASE", skillCfg, "SealGainFrequency"), formatKey = "calc.offence.offence.factor_3", formatParams = { value = 2 } },
				{ "%.2f ^8(increased/reduced cast speed)", 1 / calcLib.mod(skillModList, skillCfg, "Speed"), formatKey = "calc.offence.offence.factor_4", formatParams = { value = 2 } },
				total = localisation:Text("calc.offence.offence.line", { seal_cooldown = output.SealCooldown }),
			})
		end
	end
	if skillModList:Sum("BASE", skillCfg, "PhysicalDamageGainAsRandom", "PhysicalDamageConvertToRandom", "PhysicalDamageGainAsColdOrLightning", "DamageGainAsRandom") > 0 then
		skillFlags.randomPhys = true
		local physMode = env.configInput.physMode or "AVERAGE"
		for i, value in ipairs(skillModList:Tabulate("BASE", skillCfg, "DamageGainAsRandom")) do
			local mod = value.mod
			local effVal = mod.value / 3
			if physMode == "AVERAGE" then
				skillModList:NewMod("DamageGainAsFire", "BASE", effVal, mod.source, mod.flags, mod.keywordFlags, unpack(mod))
				skillModList:NewMod("DamageGainAsCold", "BASE", effVal, mod.source, mod.flags, mod.keywordFlags, unpack(mod))
				skillModList:NewMod("DamageGainAsLightning", "BASE", effVal, mod.source, mod.flags, mod.keywordFlags, unpack(mod))
			elseif physMode == "FIRE" then
				skillModList:NewMod("DamageGainAsFire", "BASE", mod.value, mod.source, mod.flags, mod.keywordFlags, unpack(mod))
			elseif physMode == "COLD" then
				skillModList:NewMod("DamageGainAsCold", "BASE", mod.value, mod.source, mod.flags, mod.keywordFlags, unpack(mod))
			elseif physMode == "LIGHTNING" then
				skillModList:NewMod("DamageGainAsLightning", "BASE", mod.value, mod.source, mod.flags, mod.keywordFlags, unpack(mod))
			end
		end
		for i, value in ipairs(skillModList:Tabulate("BASE", skillCfg, "PhysicalDamageGainAsRandom")) do
			local mod = value.mod
			local effVal = mod.value / 3
			if physMode == "AVERAGE" then
				skillModList:NewMod("PhysicalDamageGainAsFire", "BASE", effVal, mod.source, mod.flags, mod.keywordFlags, unpack(mod))
				skillModList:NewMod("PhysicalDamageGainAsCold", "BASE", effVal, mod.source, mod.flags, mod.keywordFlags, unpack(mod))
				skillModList:NewMod("PhysicalDamageGainAsLightning", "BASE", effVal, mod.source, mod.flags, mod.keywordFlags, unpack(mod))
			elseif physMode == "FIRE" then
				skillModList:NewMod("PhysicalDamageGainAsFire", "BASE", mod.value, mod.source, mod.flags, mod.keywordFlags, unpack(mod))
			elseif physMode == "COLD" then
				skillModList:NewMod("PhysicalDamageGainAsCold", "BASE", mod.value, mod.source, mod.flags, mod.keywordFlags, unpack(mod))
			elseif physMode == "LIGHTNING" then
				skillModList:NewMod("PhysicalDamageGainAsLightning", "BASE", mod.value, mod.source, mod.flags, mod.keywordFlags, unpack(mod))
			end
		end
		for i, value in ipairs(skillModList:Tabulate("BASE", skillCfg, "PhysicalDamageConvertToRandom")) do
			local mod = value.mod
			local effVal = mod.value / 3
			if physMode == "AVERAGE" then
				skillModList:NewMod("PhysicalDamageConvertToFire", "BASE", effVal, mod.source, mod.flags, mod.keywordFlags, unpack(mod))
				skillModList:NewMod("PhysicalDamageConvertToCold", "BASE", effVal, mod.source, mod.flags, mod.keywordFlags, unpack(mod))
				skillModList:NewMod("PhysicalDamageConvertToLightning", "BASE", effVal, mod.source, mod.flags, mod.keywordFlags, unpack(mod))
			elseif physMode == "FIRE" then
				skillModList:NewMod("PhysicalDamageConvertToFire", "BASE", mod.value, mod.source, mod.flags, mod.keywordFlags, unpack(mod))
			elseif physMode == "COLD" then
				skillModList:NewMod("PhysicalDamageConvertToCold", "BASE", mod.value, mod.source, mod.flags, mod.keywordFlags, unpack(mod))
			elseif physMode == "LIGHTNING" then
				skillModList:NewMod("PhysicalDamageConvertToLightning", "BASE", mod.value, mod.source, mod.flags, mod.keywordFlags, unpack(mod))
			end
		end
		for i, value in ipairs(skillModList:Tabulate("BASE", skillCfg, "PhysicalDamageGainAsColdOrLightning")) do
			local mod = value.mod
			local effVal = mod.value / 2
			if physMode == "AVERAGE" or physMode == "FIRE" then
				skillModList:NewMod("PhysicalDamageGainAsCold", "BASE", effVal, mod.source, mod.flags, mod.keywordFlags, unpack(mod))
				skillModList:NewMod("PhysicalDamageGainAsLightning", "BASE", effVal, mod.source, mod.flags, mod.keywordFlags, unpack(mod))
			elseif physMode == "COLD" then
				skillModList:NewMod("PhysicalDamageGainAsCold", "BASE", mod.value, mod.source, mod.flags, mod.keywordFlags, unpack(mod))
			elseif physMode == "LIGHTNING" then
				skillModList:NewMod("PhysicalDamageGainAsLightning", "BASE", mod.value, mod.source, mod.flags, mod.keywordFlags, unpack(mod))
			end
		end
	end
	-- momentum stacks
	if skillModList:Flag(nil, "SupportedByMomentum") then
		local maxMomentumStacks = skillModList:Sum("BASE", skillCfg, "MomentumStacksMax")
		local extraMomentumStacks = skillModList:Sum("BASE", skillCfg, "MomentumStacksExtra")
		if maxMomentumStacks > 0 then
			if not modDB:HasMod("BASE", nil, "Multiplier:MomentumStacks") then
				modDB:NewMod("Multiplier:MomentumStacks", "BASE", m_min((maxMomentumStacks + extraMomentumStacks) / 2, maxMomentumStacks), "Config", { type = "Condition", var = "Combat" })
			elseif modDB:Sum("BASE", nil, "Multiplier:MomentumStacks") > maxMomentumStacks then
				modDB:ReplaceMod("Multiplier:MomentumStacks", "BASE", maxMomentumStacks, "Config", { type = "Condition", var = "Combat" })
			end
		elseif modDB:HasMod("BASE", nil, "Multiplier:MomentumStacks") then
			modDB:ReplaceMod("Multiplier:MomentumStacks", "BASE", 0, "Config")
		end
	end

	local isAttack = skillFlags.attack

	runSkillFunc("preSkillTypeFunc")

	-- Calculate skill type stats
	if skillFlags.minion then
		if activeSkill.minion and activeSkill.minion.minionData.limit then
			output.ActiveMinionLimit = m_floor(env.modDB:Override(nil, activeSkill.minion.minionData.limit) or (calcLib.val(skillModList, activeSkill.minion.minionData.limit, skillCfg) + calcLib.val(skillModList, "ActiveMinionLimit", skillCfg)))
		end
		output.SummonedMinionsPerCast = m_floor(calcLib.val(skillModList, "MinionPerCastCount", skillCfg))
		if output.SummonedMinionsPerCast == 0 then
			output.SummonedMinionsPerCast = 1
		end
	end
	if skillFlags.chaining then
		if skillModList:Flag(skillCfg, "CannotChain") or skillModList:Flag(skillCfg, "NoAdditionalChains")then
			output.ChainMaxString = "Cannot chain"
		else
			output.ChainMax = (skillModList:Sum("BASE", skillCfg, "ChainCountMax", not skillFlags.projectile and "BeamChainCountMax" or nil) + skillModList:Sum("BASE", skillCfg, "ChainChance") / 100) * skillModList:More(skillCfg, "ChainCountMax", not skillFlags.projectile and "BeamChainCountMax" or nil)
			output.TerrainChain = m_min(skillModList:Sum("BASE", skillCfg, "TerrainChainChance"), 100)
			if skillModList:Flag(skillCfg, "AdditionalProjectilesAddChainsInstead") then
				output.ChainMax = output.ChainMax + (skillModList:Sum("BASE", skillCfg, "ProjectileCount") + 2 * skillModList:Sum("BASE", skillCfg, "TwoAdditionalProjectilesChance") / 100 + skillModList:Sum("BASE", skillCfg, "SurpassingProjectileChance") / 100 - 1) * skillModList:More(skillCfg, "ProjectileCount")
			end
			output.ChainMaxString = output.ChainMax
			output.Chain = m_min(output.ChainMax, skillModList:Sum("BASE", skillCfg, "ChainCount"))
			output.ChainRemaining = m_max(0, output.ChainMax - output.Chain)
		end
	end
	if skillFlags.projectile then
		if skillModList:Flag(nil, "PointBlank") then
			skillModList:NewMod("Damage", "MORE", 30, "Point Blank", bor(ModFlag.Attack, ModFlag.Projectile), { type = "DistanceRamp", ramp = {{10,1},{35,0},{120,-1}} })
		end
		if skillModList:Flag(nil, "FarShot") then
			skillModList:NewMod("Damage", "MORE", 100, "Far Shot", bor(ModFlag.Attack, ModFlag.Projectile), { type = "DistanceRamp", ramp = {{10, -0.2}, {25, 0}, {70, 0.6}} })
		end
		if skillModList:Flag(skillCfg, "NoAdditionalProjectiles") then
			output.ProjectileCount = 1
		else
			local projBase = skillModList:Sum("BASE", skillCfg, "ProjectileCount") + 2 * skillModList:Sum("BASE", skillCfg, "TwoAdditionalProjectilesChance") / 100 + skillModList:Sum("BASE", skillCfg, "SurpassingProjectileChance") / 100
			local projMore = skillModList:More(skillCfg, "ProjectileCount")
			output.ProjectileCount = projBase * projMore
		end
		if skillModList:Flag(skillCfg, "AdditionalProjectilesAddBouncesInstead") then
			local projBase = skillModList:Sum("BASE", skillCfg, "ProjectileCount") + 2 * skillModList:Sum("BASE", skillCfg, "TwoAdditionalProjectilesChance") / 100 + skillModList:Sum("BASE", skillCfg, "SurpassingProjectileChance") / 100 + skillModList:Sum("BASE", skillCfg, "BounceCount") - 1
			local projMore = skillModList:More(skillCfg, "ProjectileCount")
			output.BounceCount = projBase * projMore
		end
		if skillModList:Flag(skillCfg, "CannotSplit") or activeSkill.skillTypes[SkillType.ProjectileNumber] then
			if breakdown then
				local SplitCount = skillModList:Sum("BASE", skillCfg, "SplitCount") + enemyDB:Sum("BASE", skillCfg, "SelfSplitCount")
				if SplitCount > 0 then
					output.SplitCountString = "Cannot split"
				end
			end
		else
			output.SplitCount = skillModList:Sum("BASE", skillCfg, "SplitCount") + enemyDB:Sum("BASE", skillCfg, "SelfSplitCount")
			if skillModList:Flag(skillCfg, "AdditionalProjectilesAddSplitsInstead") then
				output.SplitCount = output.SplitCount + (skillModList:Sum("BASE", skillCfg, "ProjectileCount") + 2 * skillModList:Sum("BASE", skillCfg, "TwoAdditionalProjectilesChance") / 100 + skillModList:Sum("BASE", skillCfg, "SurpassingProjectileChance") / 100 - 1) * skillModList:More(skillCfg, "ProjectileCount")
			end
			if skillModList:Flag(skillCfg, "AdditionalChainsAddSplitsInstead") then
				output.SplitCount = output.SplitCount + skillModList:Sum("BASE", skillCfg, "ChainCountMax")
			end
			output.SplitCountString = output.SplitCount
		end
		if skillModList:Flag(skillCfg, "CannotFork") then
			output.ForkCountString = "Cannot fork"
		elseif skillModList:Flag(skillCfg, "ForkOnce") then
			skillFlags.forking = true
			if skillModList:Flag(skillCfg, "ForkTwice") then
				output.ForkCountMax = m_min(skillModList:Sum("BASE", skillCfg, "ForkCountMax"), 2)
			else
				output.ForkCountMax = m_min(skillModList:Sum("BASE", skillCfg, "ForkCountMax"), 1)
			end
			output.ForkedCount = m_min(output.ForkCountMax, skillModList:Sum("BASE", skillCfg, "ForkedCount"))
			output.ForkCountString = output.ForkCountMax
			output.ForkRemaining = m_max(0, output.ForkCountMax - output.ForkedCount)
		else
			output.ForkCountString = "0"
		end
		if skillModList:Flag(skillCfg, "CannotPierce") then
			output.PierceCount = 0
			output.PierceCountString = "Cannot pierce"
		else
			if skillModList:Flag(skillCfg, "PierceAllTargets") or enemyDB:Flag(nil, "AlwaysPierceSelf") then
				output.PierceCount = 100
				output.PierceCountString = "All targets"
			else
				output.PierceCount = skillModList:Sum("BASE", skillCfg, "PierceCount") + skillModList:Sum("BASE", skillCfg, "PierceChance") / 100
				output.PierceCountString = output.PierceCount
			end
			if output.PierceCount > 0 then
				skillFlags.piercing = true
			end
			output.PiercedCount = m_min(output.PierceCount, skillModList:Sum("BASE", skillCfg, "PiercedCount"))
		end
		output.ProjectileSpeedMod = calcLib.mod(skillModList, skillCfg, "ProjectileSpeed")
		if breakdown then
			breakdown.ProjectileSpeedMod = breakdown.mod(skillModList, skillCfg, "ProjectileSpeed")
		end
		output.TwoAdditionalProjectiles = m_min(skillModList:Sum("BASE", skillCfg, "TwoAdditionalProjectilesChance"), 100)
	end
	if skillFlags.melee then
		if skillFlags.weapon1Attack then
			actor.weaponRange1 = (actor.weaponData1.range and actor.weaponData1.range + skillModList:Sum("BASE", activeSkill.weapon1Cfg, "MeleeWeaponRange") + 10 * skillModList:Sum("BASE", activeSkill.weapon1Cfg, "MeleeWeaponRangeMetre")) or (6 + skillModList:Sum("BASE", skillCfg, "UnarmedRange") + 10 * skillModList:Sum("BASE", skillCfg, "UnarmedRangeMetre"))
		end
		if skillFlags.weapon2Attack then
			actor.weaponRange2 = (actor.weaponData2.range and actor.weaponData2.range + skillModList:Sum("BASE", activeSkill.weapon2Cfg, "MeleeWeaponRange") + 10 * skillModList:Sum("BASE", activeSkill.weapon2Cfg, "MeleeWeaponRangeMetre")) or (6 + skillModList:Sum("BASE", skillCfg, "UnarmedRange") + 10 * skillModList:Sum("BASE", skillCfg, "UnarmedRangeMetre"))
		end
		if activeSkill.skillTypes[SkillType.MeleeSingleTarget] then
			local range = 100
			if skillFlags.weapon1Attack then
				range = m_min(range, actor.weaponRange1)
			end
			if skillFlags.weapon2Attack then
				range = m_min(range, actor.weaponRange2)
			end
			output.WeaponRange = range + 2
			output.WeaponRangeMetre = output.WeaponRange / 10
			if breakdown then
				breakdown.WeaponRange = {
					radius = output.WeaponRange
				}
			end

			local baseStrikeCount = 1
			output.StrikeTargets = baseStrikeCount + skillModList:Sum("BASE", skillCfg, "AdditionalStrikeTarget")
		end
	end
	if skillFlags.area or skillData.radius or (skillFlags.mine and activeSkill.skillTypes[SkillType.Aura]) then
		calcAreaOfEffect(skillModList, skillCfg, skillData, skillFlags, output, breakdown)
	end
	if activeSkill.skillTypes[SkillType.Aura] then
		output.AuraEffectMod = calcLib.mod(skillModList, skillCfg, "AuraEffect", not skillData.auraCannotAffectSelf and "SkillAuraEffectOnSelf" or nil) * calcLib.mod(skillModList, skillCfg, "Magnitude")
		if breakdown then
			breakdown.AuraEffectMod = breakdown.mod(skillModList, skillCfg, "AuraEffect", "Magnitude", not skillData.auraCannotAffectSelf and "SkillAuraEffectOnSelf" or nil)
		end
	end
	if activeSkill.skillTypes[SkillType.HasReservation] and not activeSkill.skillTypes[SkillType.ReservationBecomesCost] then
		for _, pool in ipairs({"Spirit"}) do
			output[pool .. "ReservedMod"] = 0
			if calcLib.mod(skillModList, skillCfg, "ReservationMultiplier") > 0 and calcLib.mod(skillModList, skillCfg, pool .. "Reserved", "Reserved") > 0 then
				output[pool .. "ReservedMod"] = calcLib.mod(skillModList, skillCfg, pool .. "Reserved", "Reserved") * floor(calcLib.mod(skillModList, skillCfg, "ReservationMultiplier"), 4) / m_max(0, calcLib.mod(skillModList, skillCfg, pool .. "ReservationEfficiency", "ReservationEfficiency"))
			end
			if breakdown then
				local inc = skillModList:Sum("INC", skillCfg, pool .. "Reserved", "Reserved", "ReservationMultiplier")
				local more = skillModList:More(skillCfg, pool .. "Reserved", "Reserved", "ReservationMultiplier")
				if inc ~= 0 and more ~= 1 then
					breakdown[pool .. "ReservedMod"] = {
						localisation:Text("calc.offence.offence.line_2", { value = 1 + inc/100 }),
						localisation:Text("calc.offence.offence.line_3", { more = more }),
						localisation:Text("calc.offence.offence.line_4", { value = calcLib.mod(skillModList, skillCfg, pool .. "ReservationEfficiency", "ReservationEfficiency") }),
						s_format("= %.2f", output[pool .. "ReservedMod"]),
					}
				end
			end
		end
	end
	if activeSkill.skillTypes[SkillType.AppliesCurse] then
		output.CurseEffectMod = calcLib.mod(skillModList, skillCfg, "CurseEffect")
		if breakdown then
			breakdown.CurseEffectMod = breakdown.mod(skillModList, skillCfg, "CurseEffect")
		end

		local curseActivationMod = calcLib.mod(skillModList, skillCfg, "CurseActivation")
		local curseDelayMod = calcLib.mod(skillModList, skillCfg, "CurseDelay")
		output.CurseDelayBase = (skillData.curseDelay or 0) + skillModList:Sum("BASE", skillCfg, "CurseDelayBase")
		output.CurseDelay = output.CurseDelayBase / curseActivationMod * curseDelayMod
		output.CurseDelay = m_ceil(output.CurseDelay * data.misc.ServerTickRate) / data.misc.ServerTickRate
		if breakdown and output.CurseDelay ~= output.CurseDelayBase then
			breakdown.CurseDelay = {
				localisation:Text("calc.offence.curse_delay.line", { curse_delay_base = output.CurseDelayBase }),
			}
			if curseDelayMod ~= 1 then
				t_insert(breakdown.CurseDelay, localisation:Text("calc.offence.offence.line_5", { curse_delay_mod = curseDelayMod }))
			end
			if curseActivationMod ~= 1 then
				t_insert(breakdown.CurseDelay, localisation:Text("calc.offence.offence.line_6", { curse_activation_mod = curseActivationMod }))
			end
			t_insert(breakdown.CurseDelay, localisation:Text("calc.offence.offence.line_7"))
			t_insert(breakdown.CurseDelay, s_format("= %.3fs", output.CurseDelay))
		end
	end
	if activeSkill.skillTypes[SkillType.Mark] then
		output.MarkEffectMod = calcLib.mod(skillModList, skillCfg, "MarkEffect")
		if breakdown then
			breakdown.MarkEffectMod = breakdown.mod(skillModList, skillCfg, "MarkEffect")
		end
	end
	if activeSkill.skillTypes[SkillType.PerfectTiming] then
		local perfectTimingMod = calcLib.mod(skillModList, skillCfg, "PerfectTiming")
		local baseTiming = skillModList:Sum("BASE", skillCfg, "PerfectTimingBase")
		output.PerfectTiming = baseTiming * perfectTimingMod
		if breakdown then
			breakdown.PerfectTiming = {
				localisation:Text("calc.offence.perfect_timing.line", { base_timing = baseTiming }),
				localisation:Text("calc.offence.perfect_timing.line_2", { perfect_timing_mod = perfectTimingMod }),
				s_format("\n"),
				localisation:Text("calc.offence.perfect_timing.line_3", { perfect_timing = output.PerfectTiming }),
			}
		end
	end
	if skillModList:Flag(skillCfg, "RevivingMinion") then
		local MinionRevivalSpeedMod = calcLib.mod(skillModList, skillCfg, "MinionRevivalSpeed")
		local baseMinionRevivalTime = skillModList:Override(skillCfg, "BaseReviveTime") or data.misc.MinionRevivalTimeBase
		output.MinionRevivalSpeed = baseMinionRevivalTime * (1 / MinionRevivalSpeedMod)
		if breakdown then
			breakdown.MinionRevivalSpeed = {
				localisation:Text("calc.offence.minion_revival_speed.line", { base_minion_revival_time = baseMinionRevivalTime }),
				localisation:Text("calc.offence.minion_revival_speed.line_2", { minion_revival_speed_mod = MinionRevivalSpeedMod }),
				s_format("\n"),
				localisation:Text("calc.offence.minion_revival_speed.line_3", { minion_revival_speed = output.MinionRevivalSpeed }),
			}
		end
	end
	if activeSkill.skillTypes[SkillType.Warcry] then
		local full_duration = calcSkillDuration(skillModList, skillCfg, activeSkill.skillData, env, enemyDB)
		local actual_cooldown = calcSkillCooldown(skillModList, skillCfg, activeSkill.skillData)
		local uptime = env.modDB:Flag(nil, "Condition:WarcryMaxHit") and 1 or m_min(full_duration / actual_cooldown, 1)
		local unscaledEffect = calcLib.mod(skillModList, skillCfg, "WarcryEffect", "BuffEffect")
		output.WarcryEffectMod = unscaledEffect * uptime
		if breakdown then
			breakdown.WarcryEffectMod = {
					localisation:Text("calc.offence.warcry_effect_mod.line", { unscaled_effect = unscaledEffect })
			}
			if env.modDB:Flag(nil, "Condition:WarcryMaxHit") or uptime ~= 1 then
				if env.modDB:Flag(nil, "Condition:WarcryMaxHit") then
					t_insert(breakdown.WarcryEffectMod, localisation:Text("calc.offence.offence.line_8"))
				elseif uptime ~= 1 then
					t_insert(breakdown.WarcryEffectMod, localisation:Text("calc.offence.offence.line_9", { value = uptime * 100 }))
				end
				t_insert(breakdown.WarcryEffectMod, s_format("= %.1f%%", output.WarcryEffectMod * 100))
			end
		end
	end
	if skillModList:Flag(skillCfg, "CanCreateHazards") then
		output.HazardRearmChance = m_min(skillModList:Sum("BASE", skillCfg, "HazardRearmChance"), 100)
		skillModList:NewMod("DPS", "MORE", output.HazardRearmChance, "Chance To Rearm")
		if breakdown then
			output.HazardRearmChance = skillModList:Sum("BASE", skillCfg, "HazardRearmChance")
		end
	end
	if activeSkill.skillTypes[SkillType.Link] then
		output.LinkEffectMod = calcLib.mod(skillModList, skillCfg, "LinkEffect", "BuffEffect")
		if breakdown then
			breakdown.LinkEffectMod = breakdown.mod(skillModList, skillCfg, "LinkEffect", "BuffEffect")
		end
	end
	if activeSkill.skillTypes[SkillType.GeneratesRemnants] then
		local remnantEffectMod = calcLib.mod(skillModList, skillCfg, "RemnantEffect")
		output.RemnantEffectMod = remnantEffectMod
		if breakdown then
			breakdown.RemnantEffectMod = breakdown.mod(skillModList, skillCfg, "RemnantEffect")
		end
		local baseLifeGain = skillModList:Sum("BASE", skillCfg, "LifeGainPerRemnant")
		if baseLifeGain > 0 then
			output.LifeGainPerRemnant = m_floor(baseLifeGain * remnantEffectMod)
			if breakdown then
				breakdown.LifeGainPerRemnant = {
					localisation:Text("calc.offence.life_gain_per_remnant.line", { base_life_gain = baseLifeGain }),
					localisation:Text("calc.offence.life_gain_per_remnant.line_2", { remnant_effect_mod = remnantEffectMod }),
					localisation:Text("calc.offence.life_gain_per_remnant.line_3", { life_gain_per_remnant = output.LifeGainPerRemnant }),
				}
			end
		end
		local baseManaGain = skillModList:Sum("BASE", skillCfg, "ManaGainPerRemnant")
		if baseManaGain > 0 then
			output.ManaGainPerRemnant = m_floor(baseManaGain * remnantEffectMod)
			if breakdown then
				breakdown.ManaGainPerRemnant = {
					localisation:Text("calc.offence.mana_gain_per_remnant.line", { base_mana_gain = baseManaGain }),
					localisation:Text("calc.offence.mana_gain_per_remnant.line_2", { remnant_effect_mod = remnantEffectMod }),
					localisation:Text("calc.offence.mana_gain_per_remnant.line_3", { mana_gain_per_remnant = output.ManaGainPerRemnant }),
				}
			end
		end
		local baseChaosGainPerFlame = skillModList:Sum("BASE", skillCfg, "BreachFlameChaosGain")
		local doubled = modDB:Flag(nil, "BreachFlameEffectDoubled") and 2 or 1
		if baseChaosGainPerFlame > 0 then
			output.ChaosGainPerFlame = m_floor(baseChaosGainPerFlame * remnantEffectMod * doubled)
			if breakdown then
				breakdown.ChaosGainPerFlame = {
					localisation:Text("calc.offence.chaos_gain_per_flame.line", { base_chaos_gain_per_flame = baseChaosGainPerFlame }),
					localisation:Text("calc.offence.chaos_gain_per_flame.line_2", { remnant_effect_mod = remnantEffectMod }),
					localisation:Text("calc.offence.chaos_gain_per_flame.line_3", { chaos_gain_per_flame = output.ChaosGainPerFlame }),
				}
			end
		end
		local baseLifeLeech = skillModList:Sum("BASE", skillCfg, "BreachFlameLifeLeech")
		if baseLifeLeech > 0 then
			output.BreachFlameLifeLeech = m_floor(baseLifeLeech * remnantEffectMod)
			if breakdown then
				breakdown.BreachFlameLifeLeech = {
					localisation:Text("calc.offence.breach_flame_life_leech.line", { base_life_leech = baseLifeLeech }),
					localisation:Text("calc.offence.breach_flame_life_leech.line_2", { remnant_effect_mod = remnantEffectMod }),
					localisation:Text("calc.offence.breach_flame_life_leech.line_3", { breach_flame_life_leech = output.BreachFlameLifeLeech }),
				}
			end
		end
		local baseManaLeech = skillModList:Sum("BASE", skillCfg, "BreachFlameManaLeech")
		if baseManaLeech > 0 then
			output.BreachFlameManaLeech = m_floor(baseManaLeech * remnantEffectMod)
			if breakdown then
				breakdown.BreachFlameManaLeech = {
					localisation:Text("calc.offence.breach_flame_mana_leech.line", { base_mana_leech = baseManaLeech }),
					localisation:Text("calc.offence.breach_flame_mana_leech.line_2", { remnant_effect_mod = remnantEffectMod }),
					localisation:Text("calc.offence.breach_flame_mana_leech.line_3", { breach_flame_mana_leech = output.BreachFlameManaLeech }),
				}
			end
		end
	end
	if activeSkill.skillTypes[SkillType.IceCrystal] then
		local IceCrystalLifeMod = calcLib.mod(skillModList, skillCfg, "IceCrystalLife")
		local baseIceCrystal = skillModList:Sum("BASE", skillCfg, "IceCrystalLifeBase")
		output.IceCrystalLife = baseIceCrystal * IceCrystalLifeMod
		if breakdown then
			breakdown.IceCrystalLife = {
				localisation:Text("calc.offence.ice_crystal_life.line_2", { base_ice_crystal = baseIceCrystal }),
				localisation:Text("calc.offence.ice_crystal_life.line", { ice_crystal_life_mod = IceCrystalLifeMod }),
				s_format("\n"),
				localisation:Text("calc.offence.ice_crystal_life.line_3", { ice_crystal_life = output.IceCrystalLife }),
			}
		end
	end
	if (skillFlags.trap or skillFlags.mine) and not (skillData.trapCooldown or skillData.cooldown) then
		skillFlags.notAverage = true
		skillFlags.showAverage = false
		skillData.showAverage = false
	end
	if skillFlags.trap then
		local baseSpeed = 1 / skillModList:Sum("BASE", skillCfg, "TrapThrowingTime")
		local timeMod = calcLib.mod(skillModList, skillCfg, "SkillTrapThrowingTime")
		if timeMod > 0 then
			baseSpeed = baseSpeed * (1 / timeMod)
		end
		output.TrapThrowingSpeed = baseSpeed * calcLib.mod(skillModList, skillCfg, "TrapThrowingSpeed") * output.ActionSpeedMod
		local trapThrowCount = calcLib.val(skillModList, "TrapThrowCount", skillCfg)
		if skillData.trapCooldown or skillData.cooldown then
			trapThrowCount = 1
		end
		output.TrapThrowCount = env.modDB:Override(nil, "TrapThrowCount") or trapThrowCount
		output.TrapThrowingSpeed = m_min(output.TrapThrowingSpeed, data.misc.ServerTickRate)
		output.TrapThrowingTime = 1 / output.TrapThrowingSpeed
		skillData.timeOverride = output.TrapThrowingTime / output.TrapThrowCount
		if breakdown then
			breakdown.TrapThrowingSpeed = { }
			breakdown.multiChain(breakdown.TrapThrowingSpeed, {
				label = "Throwing rate:", labelKey = "ui.calc_offence.offence.label_8",
				base = { "%.2f ^8(base throwing rate)", baseSpeed, formatKey = "calc.offence.offence.factor_5", formatParams = { base_speed = 2 } },
				{ "%.2f ^8(increased/reduced throwing speed)", 1 + skillModList:Sum("INC", skillCfg, "TrapThrowingSpeed") / 100, formatKey = "calc.offence.offence.factor_6", formatParams = { value = 2 } },
				{ "%.2f ^8(more/less throwing speed)", skillModList:More(skillCfg, "TrapThrowingSpeed"), formatKey = "calc.offence.offence.factor_7", formatParams = { value = 2 } },
				{ "%.2f ^8(action speed modifier)",  output.ActionSpeedMod, formatKey = "calc.offence.offence.factor_8", formatParams = { action_speed_mod = 2 } },
				total = localisation:Text("calc.offence.offence.line_10", { trap_throwing_speed = output.TrapThrowingSpeed }),
			})
		end
		if breakdown and timeMod > 0 then
			breakdown.TrapThrowingTime = { }
			breakdown.multiChain(breakdown.TrapThrowingTime, {
				label = "Throwing time:", labelKey = "ui.calc_offence.offence.label_9",
				base = { "%.2f ^8(base throwing time)", 1 / (output.TrapThrowingSpeed * timeMod), formatKey = "calc.offence.offence.factor_9", formatParams = { value = 2 } },
				{ "%.2f ^8(total modifier)", timeMod, formatKey = "calc.offence.offence.factor_10", formatParams = { time_mod = 2 } },
				total = localisation:Text("calc.offence.offence.line_11", { trap_throwing_time = output.TrapThrowingTime }),
			})
		end

		local baseCooldown = skillData.trapCooldown or skillData.cooldown
		if baseCooldown or skillModList:Sum("BASE", skillCfg, "CooldownRecovery") > 0 then
			if baseCooldown then
				local temporalisCooldown = skillModList:Sum("BASE", skillCfg, "CooldownRecoveryFromTemporalis")
				output.TrapCooldown = (baseCooldown + temporalisCooldown) / calcLib.mod(skillModList, skillCfg, "CooldownRecovery")
				if temporalisCooldown ~= 0 then
					output.TrapCooldown = m_max(output.TrapCooldown, 0.1)
				end
				output.TrapCooldown = m_ceil(output.TrapCooldown * data.misc.ServerTickRate) / data.misc.ServerTickRate
			else -- Assign Trap Cooldown if the trap/skill does not have cooldown but gain cooldown elsewhere
				local cooldown, _, _ = calcSkillCooldown(skillModList, skillCfg, skillData)
				output.TrapCooldown = cooldown;
			end
			if breakdown then
				breakdown.TrapCooldown = {
					localisation:Text("calc.offence.trap_cooldown.line", { value = ((skillData.trapCooldown or skillData.cooldown) or 4) }),
					localisation:Text("calc.offence.trap_cooldown.line_2", { value = 1 + skillModList:Sum("INC", skillCfg, "CooldownRecovery") / 100 }),
					localisation:Text("calc.offence.trap_cooldown.line_3"),
					s_format("= %.3fs", output.TrapCooldown)
				}
			end
		end
		local incArea, moreArea = calcLib.mods(skillModList, skillCfg, "TrapTriggerAreaOfEffect")
		local areaMod = calcAreaMod(incArea, moreArea)
		output.TrapTriggerRadius = calcRadius(data.misc.TrapTriggerRadiusBase, areaMod)
		output.TrapTriggerRadiusMetre = output.TrapTriggerRadius / 10
		if breakdown then
			local incAreaBreakpoint, moreAreaBreakpoint, redAreaBreakpoint, lessAreaBreakpoint = calcRadiusBreakpoints(data.misc.TrapTriggerRadiusBase, incArea, moreArea)
			breakdown.TrapTriggerRadius = breakdown.area(data.misc.TrapTriggerRadiusBase, areaMod, output.TrapTriggerRadius, incAreaBreakpoint, moreAreaBreakpoint, redAreaBreakpoint, lessAreaBreakpoint)
		end
	elseif skillData.cooldown or skillModList:Sum("BASE", skillCfg, "CooldownRecovery") > 0 then
		local cooldownMode = env.configInput.cooldownMode or "BASE"
		local cooldown, rounded, addedCooldown, noCooldownChance = calcSkillCooldown(skillModList, skillCfg, skillData)
		local effectiveCooldownMultiplier = 1 - noCooldownChance
		local effectiveCooldown = cooldown * effectiveCooldownMultiplier

		output.Cooldown = cooldown
		output.EffectiveCooldown = cooldown

		if breakdown then
			breakdown.Cooldown = {
				localisation:Text("calc.offence.cooldown.line", { value = (skillData.cooldown or 0 + addedCooldown) }),
				localisation:Text("calc.offence.cooldown.line_2", { value = 1 + skillModList:Sum("INC", skillCfg, "CooldownRecovery") / 100 }),
			}

			if cooldownMode == "AVERAGE" and noCooldownChance > 0 then
				output.EffectiveCooldown = effectiveCooldown
				breakdown.EffectiveCooldown = {
					localisation:Text("calc.offence.effective_cooldown.line"),
					unpack(breakdown.Cooldown),
				}
				t_insert(breakdown.EffectiveCooldown, localisation:Text("calc.offence.offence.line_12", { effective_cooldown_multiplier = effectiveCooldownMultiplier, value = noCooldownChance * 100 }))
				t_insert(breakdown.EffectiveCooldown, s_format("= %.3fs", output.EffectiveCooldown))
			end

			if rounded then
				t_insert(breakdown.Cooldown, localisation:Text("calc.offence.offence.line_7"))
			end
			t_insert(breakdown.Cooldown, s_format("= %.3fs", output.Cooldown))
		end
	end
	if skillData.storedUses then
		local baseUses = skillData.storedUses
		local additionalUses = skillModList:Sum("BASE", skillCfg, "AdditionalCooldownUses")
		output.StoredUses = baseUses + additionalUses
		if breakdown then
			breakdown.StoredUses = { localisation:Text("calc.offence.stored_uses.line", { base_uses = baseUses, value = ((baseUses == 1 and "") or "s") }) }
			if additionalUses ~= 0 then
				t_insert(breakdown.StoredUses, localisation:Text("calc.offence.offence.line_13", { additional_uses = additionalUses, value = ((additionalUses == 1 and "") or "s") }))
				t_insert(breakdown.StoredUses, localisation:Text("calc.offence.offence.line_14", { stored_uses = output.StoredUses, value = ((output.StoredUses == 1 and "") or "s") }))
			end
		end
	end
	if skillFlags.mine then
		local baseSpeed = 1 / skillModList:Sum("BASE", skillCfg, "MineLayingTime")
		local timeMod = calcLib.mod(skillModList, skillCfg, "SkillMineThrowingTime")
		if timeMod > 0 then
			baseSpeed = baseSpeed * (1 / timeMod)
		end
		output.MineLayingSpeed = baseSpeed * calcLib.mod(skillModList, skillCfg, "MineLayingSpeed") * output.ActionSpeedMod
		-- Calculate additional mine throw
		local mineThrowCount = calcLib.val(skillModList, "MineThrowCount", skillCfg)
		if skillData.trapCooldown or skillData.cooldown then
			mineThrowCount = 1
		end
		output.MineThrowCount = env.modDB:Override(nil, "MineThrowCount") or mineThrowCount
		if output.MineThrowCount >= 1 then
			-- Throwing Mines takes 10% more time for each *additional* Mine thrown
			output.MineLayingSpeed = output.MineLayingSpeed / (1 + (output.MineThrowCount - 1) * 0.1)
		end

		output.MineLayingSpeed = m_min(output.MineLayingSpeed, data.misc.ServerTickRate)
		output.MineLayingTime = 1 / output.MineLayingSpeed

		-- Trap mine interaction where the Character throws mines, mine throws traps
		if skillFlags.trap then
			skillData.timeOverride = output.MineLayingTime / output.MineThrowCount / output.TrapThrowCount
		else
			skillData.timeOverride = output.MineLayingTime / output.MineThrowCount
		end

		if breakdown then
			breakdown.MineLayingTime = { }
			breakdown.multiChain(breakdown.MineLayingTime, {
				label = "Throwing rate:", labelKey = "ui.calc_offence.offence.label_8",
				base = { "%.2f ^8(base throwing rate)", baseSpeed, formatKey = "calc.offence.offence.factor_5", formatParams = { base_speed = 2 } },
				{ "%.2f ^8(increased/reduced throwing speed)", 1 + skillModList:Sum("INC", skillCfg, "MineLayingSpeed") / 100, formatKey = "calc.offence.offence.factor_11", formatParams = { value = 2 } },
				{ "%.2f ^8(more/less throwing speed)", skillModList:More(skillCfg, "MineLayingSpeed"), formatKey = "calc.offence.offence.factor_12", formatParams = { value = 2 } },
				{ "%.2f ^8(action speed modifier)",  output.ActionSpeedMod, formatKey = "calc.offence.offence.factor_8", formatParams = { action_speed_mod = 2 } },
				{ "%.2f ^8(additional mine thrown)", 1 / (1 + (output.MineThrowCount - 1) * 0.1), formatKey = "calc.offence.offence.factor_13", formatParams = { value = 2 } },
				total = localisation:Text("calc.offence.offence.line_15", { mine_laying_speed = output.MineLayingSpeed }),
			})
		end
		if breakdown and timeMod > 0 then
			breakdown.MineThrowingTime = { }
			breakdown.multiChain(breakdown.MineThrowingTime, {
			label = "Throwing time:", labelKey = "ui.calc_offence.offence.label_9",
				base = { "%.2f ^8(base throwing time)", 1 / (output.MineLayingSpeed * timeMod), formatKey = "calc.offence.offence.factor_14", formatParams = { value = 2 } },
				{ "%.2f ^8(total modifier)", timeMod, formatKey = "calc.offence.offence.factor_10", formatParams = { time_mod = 2 } },
				total = localisation:Text("calc.offence.offence.line_16", { mine_laying_time = output.MineLayingTime }),
			})
		end

		local incArea, moreArea = calcLib.mods(skillModList, skillCfg, "MineDetonationAreaOfEffect")
		local areaMod = calcAreaMod(incArea, moreArea)
		output.MineDetonationRadius = calcRadius(data.misc.MineDetonationRadiusBase, areaMod)
		output.MineDetonationRadiusMetre = output.MineDetonationRadius / 10
		if breakdown then
			local incAreaBreakpoint, moreAreaBreakpoint, redAreaBreakpoint, lessAreaBreakpoint = calcRadiusBreakpoints(data.misc.MineDetonationRadiusBase, incArea, moreArea)
			breakdown.MineDetonationRadius = breakdown.area(data.misc.MineDetonationRadiusBase, areaMod, output.MineDetonationRadius, incAreaBreakpoint, moreAreaBreakpoint, redAreaBreakpoint, lessAreaBreakpoint)
		end
		if activeSkill.skillTypes[SkillType.Aura] then
			output.MineAuraRadius = calcRadius(data.misc.MineAuraRadiusBase, output.AreaOfEffectMod)
			output.MineAuraRadiusMetre = output.MineAuraRadius / 10
			if breakdown then
				local incArea, moreArea = calcLib.mods(skillModList, skillCfg, "AreaOfEffect")
				local incAreaBreakpoint, moreAreaBreakpoint, redAreaBreakpoint, lessAreaBreakpoint = calcRadiusBreakpoints(data.misc.MineAuraRadiusBase, incArea, moreArea)
				breakdown.MineAuraRadius = breakdown.area(data.misc.MineAuraRadiusBase, output.AreaOfEffectMod, output.MineAuraRadius, incAreaBreakpoint, moreAreaBreakpoint, redAreaBreakpoint, lessAreaBreakpoint)
			end
		end
	end
	if skillFlags.totem then
		if skillFlags.ballista then
			baseSpeed = 1 / skillModList:Sum("BASE", skillCfg, "BallistaPlacementTime")
		else
			baseSpeed = 1 / skillModList:Sum("BASE", skillCfg, "TotemPlacementTime")
		end
		output.TotemPlacementSpeed = baseSpeed * calcLib.mod(skillModList, skillCfg, "TotemPlacementSpeed") * output.ActionSpeedMod
		output.TotemPlacementTime = 1 / output.TotemPlacementSpeed
		if breakdown then
			breakdown.TotemPlacementTime = { }
			breakdown.multiChain(breakdown.TotemPlacementTime, {
				label = "Placement speed:", labelKey = "ui.calc_offence.offence.label_6",
				base = { "%.2f ^8(base placement speed)", baseSpeed, formatKey = "calc.offence.offence.factor_15", formatParams = { base_speed = 2 } },
				{ "%.2f ^8(increased/reduced placement speed)", 1 + skillModList:Sum("INC", skillCfg, "TotemPlacementSpeed") / 100, formatKey = "calc.offence.offence.factor_16", formatParams = { value = 2 } },
				{ "%.2f ^8(more/less placement speed)", skillModList:More(skillCfg, "TotemPlacementSpeed"), formatKey = "calc.offence.offence.factor_17", formatParams = { value = 2 } },
				{ "%.2f ^8(action speed modifier)",  output.ActionSpeedMod, formatKey = "calc.offence.offence.factor_8", formatParams = { action_speed_mod = 2 } },
				total = localisation:Text("calc.offence.offence.line_17", { totem_placement_speed = output.TotemPlacementSpeed }),
			})
		end
		output.ActiveTotemLimit = skillModList:Override(skillCfg, "ActiveTotemLimit", "ActiveBallistaLimit") or skillModList:Sum("BASE", skillCfg, "ActiveTotemLimit", "ActiveBallistaLimit")
		output.TotemsSummoned = env.modDB:Override(nil, "TotemsSummoned") or output.ActiveTotemLimit
		if breakdown then
			breakdown.ActiveTotemLimit = {
				localisation:Text("calc.offence.active_totem_limit.line", { totems_summoned = output.TotemsSummoned, value = ((env.configInput.TotemsSummoned and localisation:Ref("calc.offence.active_totem_limit.line.parameter")) or localisation:Ref("calc.offence.active_totem_limit.line.parameter_2")) }),
			}
		end
		output.TotemLifeMod = calcLib.mod(skillModList, skillCfg, "TotemLife")
		output.TotemLife = round(m_floor(env.data.monsterAllyLifeTable[skillData.totemLevel] * env.data.totemLifeMult[activeSkill.skillTotemId]) * output.TotemLifeMod)
		output.TotemEnergyShield = skillModList:Sum("BASE", skillCfg, "TotemEnergyShield")
		output.TotemBlockChance = skillModList:Sum("BASE", skillCfg, "TotemBlockChance")
		output.TotemArmour = skillModList:Sum("BASE", skillCfg, "TotemArmour")
		if breakdown then
			breakdown.TotemLifeMod = breakdown.mod(skillModList, skillCfg, "TotemLife")
			breakdown.TotemLife = {
				localisation:Text("calc.offence.totem_life.line", { totem_level = skillData.totemLevel }),
				localisation:Text("calc.offence.totem_life.line_2", { value = env.data.monsterAllyLifeTable[skillData.totemLevel], totem_level = skillData.totemLevel }),
				localisation:Text("calc.offence.totem_life.line_3", { value = env.data.totemLifeMult[activeSkill.skillTotemId] }),
				localisation:Text("calc.offence.totem_life.line_4", { totem_life_mod = output.TotemLifeMod }),
				"= "..output.TotemLife,
			}
			breakdown.TotemEnergyShield = breakdown.mod(skillModList, skillCfg, "TotemEnergyShield")
			breakdown.TotemBlockChance = breakdown.mod(skillModList, skillCfg, "TotemBlockChance")
			breakdown.TotemArmour = breakdown.mod(skillModList, skillCfg, "TotemArmour")
		end
	end
	if skillFlags.brand then
		output.BrandAttachmentRange = data.misc.BrandAttachmentRangeBase * calcLib.mod(skillModList, skillCfg, "BrandAttachmentRange")
		output.BrandAttachmentRangeMetre = output.BrandAttachmentRange / 10
		output.ActiveBrandLimit = skillModList:Sum("BASE", skillCfg, "ActiveBrandLimit")
		if breakdown then
			breakdown.BrandAttachmentRange = { radius = output.BrandAttachmentRange }
		end
	end

	if skillFlags.warcry then
		output.WarcryCastTime = calcWarcryCastTime(skillModList, skillCfg, skillData, actor)
	end

	if skillFlags.corpse then
		output.CorpseLevel = skillModList:Sum("BASE", skillCfg, "CorpseLevel")
		output.BaseCorpseLife = env.data.monsterLifeTable[output.CorpseLevel or 1] * (env.data.monsterVarietyLifeMult[skillData.corpseMonsterVariety] or 1) * (env.data.mapLevelLifeMult[env.enemyLevel] or 1)
		output.CorpseLifeInc = 1 + (skillModList:Sum("INC", skillCfg, "CorpseLife") or 0) / 100
		output.CorpseLife = output.BaseCorpseLife * output.CorpseLifeInc
		if breakdown then
			breakdown.CorpseLife = {
				localisation:Text("calc.offence.corpse_life.line", { value = env.data.monsterLifeTable[output.CorpseLevel or 1], value_2 = (output.CorpseLevel or "n/a") }),
				localisation:Text("calc.offence.corpse_life.line_2", { value = (env.data.monsterVarietyLifeMult[skillData.corpseMonsterVariety] or 1), corpse_monster_variety = skillData.corpseMonsterVariety }),
				localisation:Text("calc.offence.corpse_life.line_3", { value = (env.data.mapLevelLifeMult[env.enemyLevel] or 1), enemy_level = env.enemyLevel }),
				localisation:Text("calc.offence.corpse_life.line_4", { base_corpse_life = output.BaseCorpseLife }),
				s_format(""),
				localisation:Text("calc.offence.corpse_life.line_5", { corpse_life_inc = output.CorpseLifeInc }),
				s_format(" = %d", output.CorpseLife),
			}
		end
	end

	-- Skill duration
	local debuffDurationMult = 1
	if env.mode_effective then
		debuffDurationMult = 1 / m_max(data.misc.BuffExpirationSlowCap, calcLib.mod(enemyDB, skillCfg, "BuffExpireFaster"))
	end
	do
		output.DurationMod = calcLib.mod(skillModList, skillCfg, "Duration", "PrimaryDuration", "DamagingAilmentDuration", skillData.mineDurationAppliesToSkill and "MineDuration" or nil)
		output.DurationMod = m_max(output.DurationMod, 0)
		if breakdown then
			breakdown.DurationMod = breakdown.mod(skillModList, skillCfg, "Duration", "PrimaryDuration", "DamagingAilmentDuration", skillData.mineDurationAppliesToSkill and "MineDuration" or nil)
			if breakdown.DurationMod and skillData.durationSecondary then
				t_insert(breakdown.DurationMod, 1, localisation:Text("calc.offence.offence.line_18"))
			end
		end
		local durationBase = (skillData.duration or 0) + skillModList:Sum("BASE", skillCfg, "Duration", "PrimaryDuration")
		if durationBase > 0 and not (activeSkill.minion and skillModList:Flag(skillCfg, activeSkill.minion.type.."PermanentDuration")) then
			output.Duration = durationBase * output.DurationMod
			if skillData.debuff then
				output.Duration = output.Duration * debuffDurationMult
			end
			output.Duration = m_ceil(output.Duration * data.misc.ServerTickRate) / data.misc.ServerTickRate
			if breakdown and output.Duration ~= durationBase then
				breakdown.Duration = {
					localisation:Text("calc.offence.duration.line", { duration_base = durationBase }),
				}
				if output.DurationMod ~= 1 then
					t_insert(breakdown.Duration, localisation:Text("calc.offence.offence.line_19", { duration_mod = output.DurationMod }))
				end
				if skillData.debuff and debuffDurationMult ~= 1 then
					t_insert(breakdown.Duration, localisation:Text("calc.offence.offence.line_20", { value = 1 / debuffDurationMult }))
				end
				t_insert(breakdown.Duration, localisation:Text("calc.offence.offence.line_7"))
				t_insert(breakdown.Duration, s_format("= %.3fs", output.Duration))
			end
		end
		durationBase = (skillData.durationSecondary or 0) + skillModList:Sum("BASE", skillCfg, "Duration", "SecondaryDuration")
		if durationBase > 0 then
			local durationMod = calcLib.mod(skillModList, skillCfg, "Duration", "SecondaryDuration", "DamagingAilmentDuration", skillData.mineDurationAppliesToSkill and "MineDuration" or nil)
			durationMod = m_max(durationMod, 0)
			output.DurationSecondary = durationBase * durationMod
			if skillData.debuffSecondary then
				output.DurationSecondary = output.DurationSecondary * debuffDurationMult
			end
			output.DurationSecondary = m_ceil(output.DurationSecondary * data.misc.ServerTickRate) / data.misc.ServerTickRate
			if breakdown and output.DurationSecondary ~= durationBase then
				breakdown.SecondaryDurationMod = breakdown.mod(skillModList, skillCfg, "Duration", "SecondaryDuration", "DamagingAilmentDuration", skillData.mineDurationAppliesToSkill and "MineDuration" or nil)
				if breakdown.SecondaryDurationMod then
					t_insert(breakdown.SecondaryDurationMod, 1, localisation:Text("calc.offence.offence.line_21"))
				end
				breakdown.DurationSecondary = {
					localisation:Text("calc.offence.duration_secondary.line", { duration_base = durationBase }),
				}
				if output.DurationMod ~= 1 then
					t_insert(breakdown.DurationSecondary, localisation:Text("calc.offence.offence.line_22", { duration_mod = durationMod }))
				end
				if skillData.debuffSecondary and debuffDurationMult ~= 1 then
					t_insert(breakdown.DurationSecondary, localisation:Text("calc.offence.offence.line_20", { value = 1 / debuffDurationMult }))
				end
				t_insert(breakdown.DurationSecondary, localisation:Text("calc.offence.offence.line_7"))
				t_insert(breakdown.DurationSecondary, s_format("= %.3fs", output.DurationSecondary))
			end
		end
		durationBase = (skillData.durationTertiary or 0) + skillModList:Sum("BASE", skillCfg, "Duration", "TertiaryDuration")
		if durationBase > 0 then
			local durationMod = calcLib.mod(skillModList, skillCfg, "Duration", "TertiaryDuration", "DamagingAilmentDuration", skillData.mineDurationAppliesToSkill and "MineDuration" or nil)
			durationMod = m_max(durationMod, 0)
			output.DurationTertiary = durationBase * durationMod
			if skillData.debuffTertiary then
				output.DurationTertiary = output.DurationTertiary * debuffDurationMult
			end
			output.DurationTertiary = m_ceil(output.DurationTertiary * data.misc.ServerTickRate) / data.misc.ServerTickRate
			if breakdown and output.DurationTertiary ~= durationBase then
				breakdown.TertiaryDurationMod = breakdown.mod(skillModList, skillCfg, "Duration", "TertiaryDuration", "DamagingAilmentDuration", skillData.mineDurationAppliesToSkill and "MineDuration" or nil)
				if breakdown.TertiaryDurationMod then
					t_insert(breakdown.TertiaryDurationMod, 1, localisation:Text("calc.offence.offence.line_23"))
				end
				breakdown.DurationTertiary = {
					localisation:Text("calc.offence.duration_tertiary.line", { duration_base = durationBase }),
				}
				if output.DurationMod ~= 1 then
					t_insert(breakdown.DurationTertiary, localisation:Text("calc.offence.offence.line_22", { duration_mod = durationMod }))
				end
				if skillData.debuffTertiary and debuffDurationMult ~= 1 then
					t_insert(breakdown.DurationTertiary, localisation:Text("calc.offence.offence.line_20", { value = 1 / debuffDurationMult }))
				end
				t_insert(breakdown.DurationTertiary, localisation:Text("calc.offence.offence.line_7"))
				t_insert(breakdown.DurationTertiary, s_format("= %.3fs", output.DurationTertiary))
			end
		end
		durationBase = (skillData.auraDuration or 0)
		if durationBase > 0 then
			local durationMod = calcLib.mod(skillModList, skillCfg, "Duration", "DamagingAilmentDuration")
			durationMod = m_max(durationMod, 0)
			output.AuraDuration = durationBase * durationMod
			output.AuraDuration = m_ceil(output.AuraDuration * data.misc.ServerTickRate) / data.misc.ServerTickRate
			if breakdown and output.AuraDuration ~= durationBase then
				breakdown.AuraDuration = {
					localisation:Text("calc.offence.aura_duration.line", { duration_base = durationBase }),
					localisation:Text("calc.offence.aura_duration.line_2", { duration_mod = durationMod }),
					localisation:Text("calc.offence.aura_duration.line_3"),
					s_format("= %.3fs", output.AuraDuration),
				}
			end
		end
		durationBase = (skillData.reserveDuration or 0)
		if durationBase > 0 then
			local durationMod = calcLib.mod(skillModList, skillCfg, "Duration", "DamagingAilmentDuration")
			durationMod = m_max(durationMod, 0)
			output.ReserveDuration = durationBase * durationMod
			output.ReserveDuration = m_ceil(output.ReserveDuration * data.misc.ServerTickRate) / data.misc.ServerTickRate
			if breakdown and output.ReserveDuration ~= durationBase then
				breakdown.ReserveDuration = {
					localisation:Text("calc.offence.reserve_duration.line", { duration_base = durationBase }),
					localisation:Text("calc.offence.reserve_duration.line_2", { duration_mod = durationMod }),
					localisation:Text("calc.offence.reserve_duration.line_3"),
					s_format("= %.3fs", output.ReserveDuration),
				}
			end
		end
		durationBase = (skillData.soulPreventionDuration or 0)
		if durationBase > 0 then
			local durationMod = calcLib.mod(skillModList, skillCfg, "SoulGainPreventionDuration", skillData.skillEffectAppliesToSoulGainPrevention and "Duration" or "DamagingAilmentDuration" or nil, skillData.mineDurationAppliesToSkill and "MineDuration" or nil)
			durationMod = m_max(durationMod, 0)
			output.SoulGainPreventionDuration = durationBase * durationMod
			output.SoulGainPreventionDuration = m_max(m_ceil(output.SoulGainPreventionDuration * data.misc.ServerTickRate), 1) / data.misc.ServerTickRate
			if breakdown and output.SoulGainPreventionDuration ~= durationBase then
				breakdown.SoulGainPreventionDuration = {
					localisation:Text("calc.offence.soul_gain_prevention_duration.line", { duration_base = durationBase }),
					localisation:Text("calc.offence.soul_gain_prevention_duration.line_2", { duration_mod = durationMod }),
					localisation:Text("calc.offence.soul_gain_prevention_duration.line_3"),
					s_format("= %.3fs", output.SoulGainPreventionDuration),
				}
			end
		end
		output.TotemDurationMod = calcLib.mod(skillModList, skillCfg, "TotemDuration")
		output.TotemDurationMod = m_max(output.TotemDurationMod, 0)
		local TotemDurationBase = skillModList:Sum("BASE", skillCfg, "TotemDuration")
		output.TotemDuration = m_ceil(TotemDurationBase * output.TotemDurationMod * data.misc.ServerTickRate) / data.misc.ServerTickRate
		if breakdown then
			breakdown.TotemDurationMod = breakdown.mod(skillModList, skillCfg, "TotemDuration")
			breakdown.TotemDuration = {
				localisation:Text("calc.offence.totem_duration.line", { totem_duration_base = TotemDurationBase }),
			}
			if output.TotemDurationMod ~= 1 then
				t_insert(breakdown.TotemDuration, localisation:Text("calc.offence.offence.line_24", { totem_duration_mod = output.TotemDurationMod }))
			end
			t_insert(breakdown.TotemDuration, localisation:Text("calc.offence.offence.line_7"))
			t_insert(breakdown.TotemDuration, s_format("= %.3fs", output.TotemDuration))
		end
	end

	-- Skill uptime
	do
		if not activeSkill.skillTypes[SkillType.Vaal] then -- exclude vaal skills as we currently don't support soul generation or gain prevention.
			local cooldown = output.Cooldown or 0
			for _, durationType in ipairs({ "Duration", "DurationSecondary", "DurationTertiary", "AuraDuration", "reserveDuration" }) do
				local duration = output[durationType] or 0
				if (duration ~= 0 and cooldown ~= 0) then
					local uptime = 1
					if skillModList:Flag(skillCfg, "NoCooldownRecoveryInDuration") then
						uptime = duration / (cooldown + duration)
					else
						uptime = duration / (cooldown)
					end
					uptime = m_min(uptime, 1)
					output[durationType.."Uptime"] = uptime * 100
					if breakdown then
						if skillModList:Flag(skillCfg, "NoCooldownRecoveryInDuration") then
							breakdown[durationType.."Uptime"] = {
								s_format("%.2fs / (%.2fs + %.2fs)", duration, cooldown, duration),
								s_format("= %d%%", output[durationType.."Uptime"])
							}
						else
							breakdown[durationType.."Uptime"] = {
								s_format("%.2fs / %.2fs", duration, cooldown),
								s_format("= %d%%", output[durationType.."Uptime"])
							}
						end
					end
				end
			end
		end
	end

	if activeSkill.skillTypes[SkillType.DetonatesAfterTime] then
		local base = activeSkill.skillModList:Sum("BASE", skillCfg, "DetonationTime")
		local inc, more = calcLib.mods(skillModList, skillCfg, "DetonationTime")
		output.DetonationTime = base * inc * more
		if breakdown then
			breakdown.DetonationTime = { }
			breakdown.multiChain(breakdown.DetonationTime, {
				base = { "%.2fs ^8(base)", base, formatKey = "calc.offence.offence.factor_18", formatParams = { base = 2 } },
				{ "%.2f ^8(increased/reduced detonation time)", inc, formatKey = "calc.offence.offence.factor_19", formatParams = { inc = 2 } },
				{ "%.2f ^8(more/less detonation time)", more, formatKey = "calc.offence.offence.factor_20", formatParams = { more = 2 } },
				total = s_format("= %.2fs", output.DetonationTime),
			})
		end
	end

	-- Calculate costs (may be slightly off due to rounding differences)
	local costs = {
		order = { "Mana","Life","ES","Ward","Soul","Rage","ManaPercent","LifePercent","WardPercent","ManaPerMinute","LifePerMinute","WardPerMinute","ManaPercentPerMinute","LifePercentPerMinute","ESPerMinute","ESPercentPerMinute" },

		["Mana"] = { type = "Mana", upfront = true, percent = false, text = "mana", textKey = "ui.calc_offence.offence.costs.text_5", baseCost = 0, baseCostRaw = 0, totalCost = 0, baseCostNoMult = 0, finalBaseCost = 0 },
		["Life"] = { type = "Life", upfront = true, percent = false, text = "life", textKey = "ui.calc_offence.offence.costs.text_3", baseCost = 0, totalCost = 0, baseCostNoMult = 0, finalBaseCost = 0 },
		["ES"] = { type = "ES", upfront = true, percent = false, text = "ES", textKey = "ui.calc_offence.offence.costs.text", baseCost = 0, totalCost = 0, baseCostNoMult = 0, finalBaseCost = 0 },
		["Ward"] = { type = "Ward", upfront = true, percent = false, text = "runic ward", textKey = "ui.calc_offence.offence.costs.text_8", baseCost = 0, totalCost = 0, baseCostNoMult = 0, finalBaseCost = 0 },
		["Soul"] = { type = "Soul", upfront = true, percent = false, unaffectedByGenericCostMults = true, text = "soul", textKey = "ui.calc_offence.offence.costs.text_10", baseCost = 0, totalCost = 0, baseCostNoMult = 0, finalBaseCost = 0 },
		["Rage"] = { type = "Rage", upfront = true, percent = false, text = "rage", textKey = "ui.calc_offence.offence.costs.text_7", baseCost = 0, totalCost = 0, baseCostNoMult = 0, finalBaseCost = 0 },
		["ManaPercent"] = { type = "Mana", upfront = true, percent = true, text = "mana", textKey = "ui.calc_offence.offence.costs.text_5", baseCost = 0, totalCost = 0, baseCostNoMult = 0, finalBaseCost = 0 },
		["LifePercent"] = { type = "Life", upfront = true, percent = true, text = "life", textKey = "ui.calc_offence.offence.costs.text_3", baseCost = 0, totalCost = 0, baseCostNoMult = 0, finalBaseCost = 0 },
		["WardPercent"] = { type = "Ward", upfront = true, percent = true, text = "runic ward", textKey = "ui.calc_offence.offence.costs.text_8", baseCost = 0, totalCost = 0, baseCostNoMult = 0, finalBaseCost = 0 },
		["ManaPerMinute"] = { type = "Mana", upfront = false, percent = false, text = "mana/s", textKey = "ui.calc_offence.offence.costs.text_6", baseCost = 0, totalCost = 0, baseCostNoMult = 0, finalBaseCost = 0 },
		["LifePerMinute"] = { type = "Life", upfront = false, percent = false, text = "life/s", textKey = "ui.calc_offence.offence.costs.text_4", baseCost = 0, totalCost = 0, baseCostNoMult = 0, finalBaseCost = 0 },
		["WardPerMinute"] = { type = "Ward", upfront = false, percent = false, text = "runic ward/s", textKey = "ui.calc_offence.offence.costs.text_9", baseCost = 0, totalCost = 0, baseCostNoMult = 0, finalBaseCost = 0 },
		["ManaPercentPerMinute"] = { type = "Mana", upfront = false, percent = true, text = "mana/s", textKey = "ui.calc_offence.offence.costs.text_6", baseCost = 0, totalCost = 0, baseCostNoMult = 0, finalBaseCost = 0 },
		["LifePercentPerMinute"] = { type = "Life", upfront = false, percent = true, text = "life/s", textKey = "ui.calc_offence.offence.costs.text_4", baseCost = 0, totalCost = 0, baseCostNoMult = 0, finalBaseCost = 0 },
		["ESPerMinute"] = { type = "ES", upfront = false, percent = false, text = "ES/s", textKey = "ui.calc_offence.offence.costs.text_2", baseCost = 0, totalCost = 0, baseCostNoMult = 0, finalBaseCost = 0 },
		["ESPercentPerMinute"] = { type = "ES", upfront = false, percent = true, text = "ES/s", textKey = "ui.calc_offence.offence.costs.text_2", baseCost = 0, totalCost = 0, baseCostNoMult = 0, finalBaseCost = 0 },
	}

	if not skillModList:Flag(skillCfg, "HasNoCost") then
		--Support cost multipliers are calculated first and rounded down after 4 digits
		local mult = floor(skillModList:More(skillCfg, "SupportManaMultiplier"), 4)
		-- First pass to calculate base costs. Used for cost conversion (e.g. Petrified Blood)
		local additionalLifeCost = skillModList:Sum("BASE", skillCfg, "BaseManaCostAsLifeCost") / 100 -- Extra cost (e.g. Petrified Blood) calculations
		local additionalESCost = skillModList:Sum("BASE", skillCfg, "ManaCostAsEnergyShieldCost") / 100 -- Extra cost (e.g. Replica Covenant) calculations
		local hybridLifeCost = m_min(skillModList:Sum("BASE", skillCfg, "HybridManaAndLifeCost_Life"), 100) / 100 -- Blood Magic, Lifetap and tree mods capped at 100
		local wardCostPctOfLife = skillModList:Sum("BASE", skillCfg, "WardCostAsPercentOfLifeCost") / 100 -- Extra cost (e.g. Scouring Flame) calculations
		local wardCostPctOfMana = skillModList:Sum("BASE", skillCfg, "WardCostAsPercentOfManaCost") / 100
		for _, resource in ipairs(costs.order) do
			local val = costs[resource]
			local skillCost = skillModList:Override(skillCfg, "Base"..resource.."CostOverride") or activeSkill.activeEffect.grantedEffectLevel.cost and activeSkill.activeEffect.grantedEffectLevel.cost[resource] or nil
			local baseCost = round(skillCost and skillCost / data.costs[resource].Divisor or 0, 2)
			local baseCostNoMult = skillModList:Sum("BASE", skillCfg, resource.."CostNoMult") or 0 -- Flat cost from gem e.g. Divine Blessing
			local divineBlessingCorrection = 0
			if val.upfront then
				baseCost = baseCost + skillModList:Sum("BASE", skillCfg, resource.."CostBase") -- Rage Cost or Cost an additional x% max Life/ES
				val.totalCost = skillModList:Sum("BASE", skillCfg, resource.."Cost", "Cost")
				if resource == "Mana" and activeSkill.skillTypes[SkillType.ReservationBecomesCost] and val.percent == false then --Divine Blessing / Totem auras
					local reservedFlat = activeSkill.skillData[val.text.."ReservationFlat"] or activeSkill.activeEffect.grantedEffectLevel[val.text.."ReservationFlat"] or 0
					baseCost = baseCost + reservedFlat
					local reservedPercent = activeSkill.skillData[val.text.."ReservationPercent"] or activeSkill.activeEffect.grantedEffectLevel[val.text.."ReservationPercent"] or 0
					baseCost = baseCost + m_floor((output[resource] or 0) * reservedPercent / 100)
					--Divine Blessing / Totem aura skills that have a percent reservation, round instead of floor the value. This corrects the final result if it would round up
					divineBlessingCorrection = round((output[resource] or 0) * reservedPercent / 100 * mult) - m_floor((output[resource] or 0) * reservedPercent / 100 * mult)
				end
			end
			val.baseCost = val.baseCost + baseCost
			val.baseCostNoMult = val.baseCostNoMult + baseCostNoMult
			local finalBaseCostRaw = val.baseCost * mult + val.baseCostNoMult + divineBlessingCorrection
			val.finalBaseCost = m_floor(finalBaseCostRaw)
			val.baseCostRaw = val.baseCostRaw and (val.baseCost * mult + val.baseCostNoMult + divineBlessingCorrection)
			if val.type == "Life" then
				local manaType = resource:gsub("Life", "Mana")
				if skillModList:Flag(skillCfg, "CostLifeInsteadOfMana") then -- Blood Magic / Lifetap in PoE 1, not used in PoE 2 yet
					val.baseCost = val.baseCost + costs[manaType].baseCost
					val.baseCostNoMult = val.baseCostNoMult + costs[manaType].baseCostNoMult
					val.finalBaseCost = val.finalBaseCost + costs[manaType].finalBaseCost
					if val.upfront then
						local manaTotalCost = skillModList:Sum("BASE", skillCfg, manaType.."Cost")
						val.totalCost = val.totalCost + m_max(0, manaTotalCost)
						costs[manaType].totalCost = costs[manaType].totalCost - manaTotalCost
					end
					costs[manaType].baseCost = 0
					costs[manaType].baseCostRaw = 0
					costs[manaType].finalBaseCost = 0
					costs[manaType].baseCostNoMult = 0
				elseif additionalLifeCost > 0 or hybridLifeCost > 0 then
					val.baseCost = costs[manaType].baseCost
					val.finalBaseCost = round(finalBaseCostRaw + round(costs[manaType].finalBaseCost * hybridLifeCost) + m_floor(val.baseCost * mult) * additionalLifeCost)
					if val.upfront and hybridLifeCost > 0 then
						-- Positive flat Mana cost is converted and rounded separately from the base cost.
						val.totalCost = val.totalCost + round(m_max(0, skillModList:Sum("BASE", skillCfg, manaType.."Cost")) * hybridLifeCost)
					end
				end
			elseif val.type == "ES" then
				local manaType = resource:gsub("ES", "Mana")
				if additionalESCost > 0 then
					val.baseCost = costs[manaType].baseCost
					val.finalBaseCost = round(finalBaseCostRaw + round(costs[manaType].finalBaseCost * additionalESCost))
				end
			elseif val.type == "Ward" and resource == "Ward" then
				local wardCostFromOtherCosts = 0
				if wardCostPctOfMana ~= 0 then
					wardCostFromOtherCosts = wardCostFromOtherCosts + round(costs["Mana"].finalBaseCost * wardCostPctOfMana)
				end
				if wardCostPctOfLife ~= 0 then
					wardCostFromOtherCosts = wardCostFromOtherCosts + round(costs["Life"].finalBaseCost * wardCostPctOfLife)
				end
				if wardCostFromOtherCosts > 0 then
					val.baseCost = val.baseCost + wardCostFromOtherCosts
					val.finalBaseCost = val.finalBaseCost + wardCostFromOtherCosts
				end
			elseif val.type == "Rage" then
				if skillModList:Flag(skillCfg, "CostRageInsteadOfSouls") then -- Hateforge
					val.baseCost = costs.Soul.baseCost
					val.baseCostNoMult = val.baseCostNoMult + costs.Soul.baseCostNoMult
					val.finalBaseCost = costs.Soul.baseCost
					mult = 1
					costs.Soul.baseCost = 0
					costs.Soul.baseCostNoMult = 0
					costs.Soul.finalBaseCost = 0
				end
			end
		end
		for _, resource in ipairs(costs.order) do
			local val = costs[resource]
			local resource = val.upfront and resource or resource:gsub("Minute", "Second")
			local hasCost = val.baseCost > 0 or val.totalCost > 0 or val.baseCostNoMult > 0 or val.finalBaseCost > 0
			output[resource.."HasCost"] = hasCost
			local costName = resource.."Cost"
			local costNameRaw = costName.."Raw"
			local moreType = 1
			local moreCost = 1
			local inc = 0
			local costEfficiency = calcLib.mod(skillModList, skillCfg, val.type.."CostEfficiency", "CostEfficiency")
			if not val.unaffectedByGenericCostMults then
				output[costName] = val.finalBaseCost
				moreType = skillModList:More(skillCfg, val.type.."Cost")
				moreCost = skillModList:More(skillCfg, "Cost")
				inc = skillModList:Sum("INC", skillCfg, val.type.."Cost", "Cost")
				output[costNameRaw] = val.baseCostRaw and m_max(0, m_max(0, (1 + inc / 100) * val.baseCostRaw * moreType * moreCost / costEfficiency) + val.totalCost)
				if inc < 0 then
					output[costName] = m_max(0, m_ceil((1 + inc / 100) * output[costName]))
				else
					output[costName] = m_max(0, m_floor((1 + inc / 100) * output[costName]))
				end
				if moreType < 1 then
					output[costName] = m_max(0, m_ceil(moreType * output[costName]))
				else
					output[costName] = m_max(0, m_floor(moreType * output[costName]))
				end
				if moreCost < 1 then
					output[costName] = m_max(0, m_ceil(moreCost * output[costName]))
				else
					output[costName] = m_max(0, m_floor(moreCost * output[costName]))
				end
				-- Apply cost efficiency (similar to reservation efficiency)
				output[costName] = m_max(0, output[costName] / costEfficiency)
				if val.upfront and not val.percent then
					-- The game stores upfront resource costs as whole numbers after efficiency.
					output[costName] = round(output[costName])
				end
				output[costName] = m_max(0, output[costName] + val.totalCost)
				if val.type == "Mana" and hybridLifeCost > 0 then -- Life/Mana Mastery
					output[costName] = m_max(0, m_floor((1 - hybridLifeCost) * output[costName]))
					output[costNameRaw] = output[costNameRaw] and m_max(0, (1 - hybridLifeCost) * output[costNameRaw])
				end
			else
				moreType = skillModList:More(skillCfg, val.type.."Cost")
				inc = skillModList:Sum("INC", skillCfg, val.type.."Cost")
				output[costName] = m_floor(val.baseCost + val.baseCostNoMult)
				output[costName] = m_max(0, (1 + inc / 100) * output[costName])
				output[costName] = m_max(0, moreType * output[costName])
				-- Apply cost efficiency for unaffected costs too
				output[costName] = m_max(0, output[costName] / costEfficiency)
				if val.upfront and not val.percent then
					-- The game stores upfront resource costs as whole numbers after efficiency.
					output[costName] = round(output[costName])
				end
				output[costName] = m_max(0, output[costName] + val.totalCost)
				output[costNameRaw] = val.baseCostRaw and m_max(0, m_max(0, (1 + inc / 100) * (val.baseCostRaw + val.baseCostNoMult) * moreType / costEfficiency) + val.totalCost)
			end
			if breakdown and hasCost then
				breakdown[costName] = {
					localisation:Text(val.percent and "calc.cost.base_percent" or "calc.cost.base", { value = val.baseCost, resource = localisation:Field(val, "text") })
				}
				if mult ~= 1 then
					t_insert(breakdown[costName], localisation:Text("calc.offence.offence.line_25", { mult = mult }))
				end
				if val.baseCostNoMult ~= 0 then
					t_insert(breakdown[costName], localisation:Text("calc.offence.offence.line_233", { text = localisation:Field(val, 'text'), base_cost_no_mult = val.baseCostNoMult }))
				end
				if val.type == "Life" and (hybridLifeCost + additionalLifeCost) ~= 0 and not skillModList:Flag(skillCfg, "CostLifeInsteadOfMana") then
					t_insert(breakdown[costName], localisation:Text("calc.offence.offence.line_26", { value = hybridLifeCost + additionalLifeCost }))
				end
				if val.type == "ES" and additionalESCost ~= 0 and not skillModList:Flag(skillCfg, "CostLifeInsteadOfMana") then
					t_insert(breakdown[costName], localisation:Text("calc.offence.offence.line_27", { additional_escost = additionalESCost }))
				end
				if inc ~= 0 then
					t_insert(breakdown[costName], localisation:Text("calc.offence.offence.line_234", { text = localisation:Field(val, 'text'), value = 1 + inc/100 }))
				end
				if moreCost ~= 1 then
					t_insert(breakdown[costName], localisation:Text("calc.offence.offence.line_28", { more_cost = moreCost }))
				end
				if moreType ~= 1 then
					t_insert(breakdown[costName], localisation:Text("calc.offence.offence.line_235", { text = localisation:Field(val, 'text'), more_type = moreType }))
				end
				if costEfficiency ~= 1 then
					t_insert(breakdown[costName], localisation:Text("calc.offence.offence.line_236", { text = localisation:Field(val, 'text'), cost_efficiency = costEfficiency }))
				end
				if val.totalCost ~= 0 then
					t_insert(breakdown[costName], localisation:Text("calc.offence.offence.line_237", { text = localisation:Field(val, 'text'), total_cost = val.totalCost }))
				end
				if val.type == "Mana" and hybridLifeCost > 0 then
					t_insert(breakdown[costName], localisation:Text("calc.offence.offence.line_29", { value = 1-hybridLifeCost, value_2 = hybridLifeCost*100 }))
				end
				t_insert(breakdown[costName], s_format("= %"..(val.upfront and "d" or ".2f")..(val.percent and "%%" or ""), output[costName]))
			end
		end
	end
	-- Eldritch Battery adds maximum Energy Shield to the Mana available for payable-cost damage.
	output.ManaCostPayablePool = (output.ManaUnreserved or 0) + (modDB:Flag(nil, "EnergyShieldProtectsMana") and output.EnergyShield or 0)

	-- account for Sacrificial Zeal
	-- Note: Sacrificial Zeal grants Added Spell Physical Damage equal to 25% of the Skill's Mana Cost, and causes you to take Physical Damage over Time, for 4 seconds
	if skillModList:Flag(nil, "Condition:SacrificialZeal") and output.ManaHasCost then
		local multiplier = 0.25
		skillModList:NewMod("PhysicalMin", "BASE", m_floor(output.ManaCost * multiplier), "Sacrificial Zeal", ModFlag.Spell)
		skillModList:NewMod("PhysicalMax", "BASE", m_floor(output.ManaCost * multiplier), "Sacrificial Zeal", ModFlag.Spell)
	end

	runSkillFunc("preDamageFunc")

	-- Handle corpse and enemy explosions
	local monsterLife = skillData.corpseLife or (env.enemyLevel and data.monsterLifeTable[env.enemyLevel] or 100)
	if skillData.explodeCorpse and (skillData.corpseLife or env.enemyLevel) then
		local damageType = skillData.corpseExplosionDamageType or "Physical"
		skillData[damageType.."BonusMin"] = monsterLife * ( skillData.corpseExplosionLifeMultiplier or skillData.selfFireExplosionLifeMultiplier )
		skillData[damageType.."BonusMax"] = monsterLife * ( skillData.corpseExplosionLifeMultiplier or skillData.selfFireExplosionLifeMultiplier )
	end
	if skillFlags.monsterExplode then
		for _, damageType in ipairs(dmgTypeList) do
			local percentage = skillData[damageType.."EffectiveExplodePercentage"]
			local base = (percentage or 0) * monsterLife / 100
			skillData[damageType.."Min"] = base
			skillData[damageType.."Max"] = base
		end
	end

	-- Cache global damage disabling flags
	local canDeal = { }
	for _, damageType in ipairs(dmgTypeList) do
		canDeal[damageType] = not skillModList:Flag(skillCfg, "DealNo"..damageType, "DealNoDamage")
	end

	-- Calculate damage conversion percentages
	activeSkill.conversionTable = wipeTable(activeSkill.conversionTable)
	activeSkill.gainTable = wipeTable(activeSkill.gainTable)

	-- Initialize conversion tables
	for _, type in ipairs(dmgTypeList) do
		activeSkill.conversionTable[type] = {}
		activeSkill.gainTable[type] = {}
		for _, otherType in ipairs(dmgTypeList) do
			activeSkill.conversionTable[type][otherType] = 0
		end
	end

	-- First step: Process skill conversion
	for _, damageType in ipairs(dmgTypeList) do
		local skillConv, skillTotal = processDamageConversion(skillModList, skillCfg, damageType, true)
		for toType, amount in pairs(skillConv) do
			activeSkill.conversionTable[damageType][toType] = amount
		end
		activeSkill.conversionTable[damageType].mult = 1 - m_min(skillTotal / 100, 1)
	end

	-- Second step: Process global conversion and gains
	for _, damageType in ipairs(dmgTypeList) do
		local tempConversions = {}

		-- Handle global conversion of unconverted damage first
		if activeSkill.conversionTable[damageType].mult > 0 then
			local globalConv, globalTotal = processDamageConversion(skillModList, skillCfg, damageType)
			if globalTotal > 0 then
				local unconvertedMult = activeSkill.conversionTable[damageType].mult
				tempConversions[damageType] = {
					mult = unconvertedMult * (1 - globalTotal / 100),
					conv = {}
				}
				for globalToType, globalAmount in pairs(globalConv) do
					tempConversions[damageType].conv[globalToType] = unconvertedMult * globalAmount
				end
			end
		end

		-- Process global conversion on skill-converted damage
		for toType, amount in pairs(activeSkill.conversionTable[damageType]) do
			if amount > 0 and toType ~= "mult" then
				local globalConv, globalTotal = processDamageConversion(skillModList, skillCfg, toType)
				if globalTotal > 0 then
					tempConversions[toType] = {
						base = amount * (1 - globalTotal / 100),
						conv = {}
					}
					for globalToType, globalAmount in pairs(globalConv) do
						tempConversions[toType].conv[globalToType] = amount * globalAmount
					end
				end
			end
		end

		-- Apply all conversions simultaneously
		for fromType, data in pairs(tempConversions) do
			if fromType == damageType then
				activeSkill.conversionTable[damageType].mult = data.mult
			else
				activeSkill.conversionTable[damageType][fromType] = data.base
			end
			for toType, amount in pairs(data.conv) do
				activeSkill.conversionTable[damageType][toType] =
					(activeSkill.conversionTable[damageType][toType] or 0) + amount
			end
		end

		-- The game stores each final conversion destination as a whole percent.
		local convertedTotal = 0
		for toType, amount in pairs(activeSkill.conversionTable[damageType]) do
			if toType ~= "mult" then
				local conversion = round(amount * 100)
				activeSkill.conversionTable[damageType][toType] = conversion / 100
				convertedTotal = convertedTotal + conversion
			end
		end
		activeSkill.conversionTable[damageType].mult = 1 - m_min(convertedTotal / 100, 1)

	end

	-- Configure damage passes
	local passList = { }
	if isAttack then
		output.MainHand = { }
		output.OffHand = { }
		output.PreciseTechnique = env.keystonesAdded["Precise Technique"]
		local critOverride = skillModList:Override(skillCfg, "WeaponBaseCritChance")
		if skillFlags.weapon1Attack then
			if breakdown then
				breakdown.MainHand = LoadModule(calcs.breakdownModule)(skillModList, output.MainHand)
			end
			activeSkill.weapon1Cfg.skillStats = output.MainHand
			local source = copyTable(actor.weaponData1)
			-- Unarmed override for Concoction skills
			if skillFlags.unarmed then
				source = copyTable(data.unarmedWeaponData[env.classId])
			end
			if source.FacebreakerItemDamage and activeSkill.activeEffect.grantedEffect.weaponTypes and activeSkill.activeEffect.grantedEffect.weaponTypes["One Hand Mace"] then
				for _, damageType in ipairs(dmgTypeList) do
					source[damageType.."Min"] = source["Facebreaker"..damageType.."Min"] or 0
					source[damageType.."Max"] = source["Facebreaker"..damageType.."Max"] or 0
				end
			end
			if critOverride and source.type and source.type ~= "None" then
				source.CritChance = critOverride
			end
			if skillData.CritChance then
				source.CritChance = skillData.CritChance
			end
			t_insert(passList, {
				label = "Main Hand", labelKey = "ui.calc_offence.offence.label_4",
				source = source,
				cfg = activeSkill.weapon1Cfg,
				output = output.MainHand,
				breakdown = breakdown and breakdown.MainHand,
			})
		end
		if skillFlags.weapon2Attack then
			if breakdown then
				breakdown.OffHand = LoadModule(calcs.breakdownModule)(skillModList, output.OffHand)
			end
			activeSkill.weapon2Cfg.skillStats = output.OffHand
			local source = copyTable(actor.weaponData2)
			-- Unarmed override for Concoction skills
			if skillFlags.unarmed then
				source = copyTable(data.unarmedWeaponData[env.classId])
			end
			if critOverride and source.type and source.type ~= "None" then
				source.CritChance = critOverride
			end
			if skillData.CritChance then
				source.CritChance = skillData.CritChance
			end
			if skillData.setOffHandPhysicalMin and skillData.setOffHandPhysicalMax then
				source.PhysicalMin = skillData.setOffHandPhysicalMin
				source.PhysicalMax = skillData.setOffHandPhysicalMax
			end
			if skillData.setOffHandFireMin and skillData.setOffHandFireMax then
				source.FireMin = skillData.setOffHandFireMin
				source.FireMax = skillData.setOffHandFireMax
			end
			if skillData.setOffHandColdMin and skillData.setOffHandColdMax then
				source.ColdMin = skillData.setOffHandColdMin
				source.ColdMax = skillData.setOffHandColdMax
			end
			if skillData.attackTime then
				source.AttackRate = 1000 / skillData.attackTime
			end
			t_insert(passList, {
				label = "Off Hand", labelKey = "ui.calc_offence.offence.label_5",
				source = source,
				cfg = activeSkill.weapon2Cfg,
				output = output.OffHand,
				breakdown = breakdown and breakdown.OffHand,
			})
		end
	else
		t_insert(passList, {
			label = "Skill", labelKey = "ui.calc_offence.offence.label_7",
			source = skillData,
			cfg = skillCfg,
			output = output,
			breakdown = breakdown,
		})
	end

	local function combineStat(stat, mode, ...)
		-- Combine stats from Main Hand and Off Hand according to the mode
		if mode == "OR" or not skillFlags.bothWeaponAttack then
			output[stat] = output.MainHand[stat] or output.OffHand[stat]
		elseif mode == "ADD" then
			output[stat] = (output.MainHand[stat] or 0) + (output.OffHand[stat] or 0)
		elseif mode == "AVERAGE" then
			output[stat] = ((output.MainHand[stat] or 0) + (output.OffHand[stat] or 0)) / 2
		elseif mode == "CRIT" then
			if skillFlags.bothWeaponAttack and skillData.combinesHitsWhenDualWielding then
				output[stat] = (output.MainHand[stat] or 0) + (output.OffHand[stat] or 0) - ((output.MainHand[stat] or 0) * (output.OffHand[stat] or 0) / 100)
			else
				output[stat] = ((output.MainHand[stat] or 0) + (output.OffHand[stat] or 0)) / 2
			end
		elseif mode == 'HARMONICMEAN' then
			if output.MainHand[stat] == 0 or output.OffHand[stat] == 0 then
				output[stat] = 0
			else
				output[stat] = 2 / ((1 / output.MainHand[stat]) + (1 / output.OffHand[stat]))
			end
		elseif mode == "CHANCE" then
			if output.MainHand[stat] and output.OffHand[stat] then
				local mainChance = output.MainHand[...] * output.MainHand.HitChance
				local offChance = output.OffHand[...] * output.OffHand.HitChance
				local mainPortion = mainChance / (mainChance + offChance)
				local offPortion = offChance / (mainChance + offChance)
				output[stat] = output.MainHand[stat] * mainPortion + output.OffHand[stat] * offPortion
				if breakdown then
					if not breakdown[stat] then
						breakdown[stat] = { }
					end
					t_insert(breakdown[stat], localisation:Text("calc.offence.combine_stat.line"))
					t_insert(breakdown[stat], s_format("%.1f", output.MainHand[stat]))
					t_insert(breakdown[stat], localisation:Text("calc.offence.combine_stat.line_2", { main_portion = mainPortion }))
					t_insert(breakdown[stat], s_format("= %.1f", output.MainHand[stat] * mainPortion))
					t_insert(breakdown[stat], localisation:Text("calc.offence.combine_stat.line_3"))
					t_insert(breakdown[stat], s_format("%.1f", output.OffHand[stat]))
					t_insert(breakdown[stat], localisation:Text("calc.offence.combine_stat.line_4", { off_portion = offPortion }))
					t_insert(breakdown[stat], s_format("= %.1f", output.OffHand[stat] * offPortion))
					t_insert(breakdown[stat], localisation:Text("calc.offence.combine_stat.line_5"))
					t_insert(breakdown[stat], s_format("%.1f + %.1f", output.MainHand[stat] * mainPortion, output.OffHand[stat] * offPortion))
					t_insert(breakdown[stat], s_format("= %.1f", output[stat]))
				end
			else
				output[stat] = output.MainHand[stat] or output.OffHand[stat]
			end
		elseif mode == "CHANCE_AILMENT" then
			if output.MainHand[stat] and output.OffHand[stat] then
				local mainChance = output.MainHand[...] * output.MainHand.HitChance
				local offChance = output.OffHand[...] * output.OffHand.HitChance
				local mainPortion = mainChance / (mainChance + offChance)
				local offPortion = offChance / (mainChance + offChance)
				local maxInstance = m_max(output.MainHand[stat], output.OffHand[stat])
				local minInstance = m_min(output.MainHand[stat], output.OffHand[stat])
				local stackName = stat:gsub("DPS","") .. "Stacks"
				local maxInstanceStacks = m_min(1, (globalOutput[stackName] or 1) / (globalOutput[stackName.."Max"] or 1))
				output[stat] = maxInstance * maxInstanceStacks + minInstance * (1 - maxInstanceStacks)
				if breakdown then
					if not breakdown[stat] then breakdown[stat] = { } end
					t_insert(breakdown[stat], s_format(""))
					t_insert(breakdown[stat], localisation:Text("calc.offence.combine_stat.line_6", { value = maxInstanceStacks * 100 }))
					t_insert(breakdown[stat], localisation:Text("calc.offence.combine_stat.line_7", { value = ((output.MainHand[stat] >= output.OffHand[stat] and localisation:Ref("calc.offence.combine_stat.line.parameter")) or localisation:Ref("calc.offence.combine_stat.line.parameter_2")) }))
					t_insert(breakdown[stat], s_format("= %.1f", maxInstance * maxInstanceStacks))
					if maxInstanceStacks < 1 then
						t_insert(breakdown[stat], localisation:Text("calc.offence.combine_stat.line_8", { value = (1-maxInstanceStacks) * 100 }))
						t_insert(breakdown[stat], s_format("= %.1f", minInstance * (1 - maxInstanceStacks)))
					end
					t_insert(breakdown[stat], "")
					t_insert(breakdown[stat], localisation:Text("calc.offence.combine_stat.line_5"))
					if maxInstanceStacks < 1 then
						t_insert(breakdown[stat], s_format("%.1f + %.1f", maxInstance * maxInstanceStacks, minInstance * (1 - maxInstanceStacks)))
					end
					t_insert(breakdown[stat], s_format("= %.1f", output[stat]))
				end
			else
				output[stat] = output.MainHand[stat] or output.OffHand[stat]
				if breakdown then
					if not breakdown[stat] then breakdown[stat] = { } end
					t_insert(breakdown[stat], localisation:Text("calc.offence.combine_stat.line_9", { value = ((output.MainHand[stat] and localisation:Ref("calc.offence.combine_stat.line.parameter")) or localisation:Ref("calc.offence.combine_stat.line.parameter_2")) }))
				end
			end
		elseif mode == "DPS" then
			output[stat] = (output.MainHand[stat] or 0) + (output.OffHand[stat] or 0)
			if not skillData.combinesHitsWhenDualWielding then
				output[stat] = output[stat] / 2
			end
		end
	end

	local storedMainHandAccuracy = nil
	local storedMainHandAccuracyVsEnemy = nil
	local storedSustainedTraumaBreakdown = { }
	-- Calculate how often you hit (speed, accuracy, block, etc)
	for _, pass in ipairs(passList) do
		globalOutput, globalBreakdown = output, breakdown
		local source = pass.source
		---@class Output
		local output = pass.output
		local cfg = pass.cfg
		local breakdown = pass.breakdown

		if skillData.averageBurstHits then
			output.AverageBurstHits = skillData.averageBurstHits
		elseif output.Repeats and output.Repeats > 1 then
			output.AverageBurstHits = output.Repeats
		end

		-- Calculate hit chance
		local base = skillModList:Sum("BASE", cfg, "Accuracy")
		local baseVsEnemy = skillModList:Sum("BASE", cfg, "Accuracy", "AccuracyVsEnemy")
		local inc = skillModList:Sum("INC", cfg, "Accuracy")
		local incVsEnemy = skillModList:Sum("INC", cfg, "Accuracy", "AccuracyVsEnemy")
		local more = skillModList:More("MORE", cfg, "Accuracy")
		local moreVsEnemy = skillModList:More("MORE", cfg, "Accuracy", "AccuracyVsEnemy")

		local enemyDistance = env.modDB:Sum("BASE", nil, "Multiplier:enemyDistance") / 10 or 25
		local enemyDistanceCapped = m_max(m_min(enemyDistance * 10, data.misc.AccuracyFalloffEnd), data.misc.AccuracyFalloffStart)
		local modValue = m_floor(data.misc.MaxAccuracyRangePenalty * calcLib.mod(skillModList, cfg, "AccuracyPenalty"))
		local accuracyPenalty = 1 - ((enemyDistanceCapped - data.misc.AccuracyFalloffStart) / (data.misc.AccuracyFalloffEnd - data.misc.AccuracyFalloffStart)) * modValue / 100
		local accuracyPenalties = {}
		local distances = {2, 5, 9}
		for _, distance in ipairs(distances) do
			accuracyPenalties["accuracyPenalty" .. distance .. "m"] = 1 - ((distance * 10 - data.misc.AccuracyFalloffStart) / (data.misc.AccuracyFalloffEnd - data.misc.AccuracyFalloffStart)) * modValue / 100 -- Fix
		end

		output.Accuracy = m_max(0, m_floor(base * (1 + inc / 100) * more))
		local accuracyVsEnemy = m_max(0, m_floor(baseVsEnemy * (1 + incVsEnemy / 100) * moreVsEnemy))
		local accuracyVsEnemyBase = accuracyVsEnemy
		local noAccuracyDistancePenalty = modDB:Flag(cfg, "NoAccuracyDistancePenalty") -- saving this in local variable as it gets used again later
		if not noAccuracyDistancePenalty then
			accuracyVsEnemy = m_floor(accuracyVsEnemy * accuracyPenalty)
		end
		if breakdown then
			breakdown.Accuracy = { }
			breakdown.multiChain(breakdown.Accuracy, {
				base = { "%g ^8(base)", base, formatKey = "calc.offence.offence.factor_21", formatParams = { base = 2 } },
				{ "%.2f ^8(increased/reduced)", 1 + inc / 100, formatKey = "calc.offence.offence.factor_22", formatParams = { value = 2 } },
				{ "%.2f ^8(more/less)", more, formatKey = "calc.offence.offence.factor_23", formatParams = { more = 2 } },
				total = s_format("= %g", output.Accuracy)
			})
			if output.Accuracy ~= accuracyVsEnemy then
				t_insert(breakdown.Accuracy, s_format(""))
				breakdown.multiChain(breakdown.Accuracy, {
					label = "Effective Accuracy vs Enemy", labelKey = "ui.calc_offence.offence.label_2",
					base = { "%g ^8(base)", baseVsEnemy, formatKey = "calc.offence.offence.factor_24", formatParams = { base_vs_enemy = 2 } },
					{ "%.2f ^8(distance penalty)", accuracyPenalty, formatKey = "calc.offence.offence.factor_25", formatParams = { accuracy_penalty = 2 } },
					{ "%.2f ^8(increased/reduced)", 1 + incVsEnemy / 100, formatKey = "calc.offence.offence.factor_26", formatParams = { value = 2 } },
					{ "%.2f ^8(more/less)", moreVsEnemy, formatKey = "calc.offence.offence.factor_27", formatParams = { more_vs_enemy = 2 } },
					total = s_format("= %g", accuracyVsEnemy)
				})
			end
		end
		if skillModList:Flag(nil, "Condition:OffHandAccuracyIsMainHandAccuracy") and pass.label == "Main Hand" then
			storedMainHandAccuracy = output.Accuracy
			storedMainHandAccuracyVsEnemy = accuracyVsEnemy
		elseif skillModList:Flag(nil, "Condition:OffHandAccuracyIsMainHandAccuracy") and pass.label == "Off Hand" and storedMainHandAccuracy then
			output.Accuracy = storedMainHandAccuracy
			accuracyVsEnemy = storedMainHandAccuracyVsEnemy
			if breakdown then
				breakdown.Accuracy = {
					localisation:Text("calc.offence.accuracy.line", { accuracy = output.Accuracy }),
				}
			end
		end
		if not isAttack then
			output.AccuracyHitChance = 100
		else
			local enemyEvasion = m_max(round(calcLib.val(enemyDB, "Evasion")), 0)
			local hitChanceMod = calcLib.mod(skillModList, cfg, "HitChance")
			local cannotBeEvaded = skillModList:Flag(cfg, "CannotBeEvaded") or skillData.cannotBeEvaded or (env.mode_effective and enemyDB:Flag(nil, "CannotEvade"))
			output.AccuracyHitChance = (cannotBeEvaded and 100) or calcs.hitChance(enemyEvasion, accuracyVsEnemy) * hitChanceMod
			-- Accounting for mods that enable "Chance to hit with Attacks can exceed 100%"
			local exceedsHitChance = skillModList:Flag(cfg, "Condition:HitChanceCanExceed100") and calcs.hitChance(enemyEvasion, (m_floor(accuracyVsEnemyBase * accuracyPenalties["accuracyPenalty" .. distances[1] .. "m"])) * hitChanceMod) -- Check for flag and at least 100% hit chance at minimum distance
			output.AccuracyHitChanceUncapped = exceedsHitChance and m_max(calcs.hitChance(enemyEvasion, accuracyVsEnemy, true) * calcLib.mod(skillModList, cfg, "HitChance"), output.AccuracyHitChance) -- keep higher chance in case of "CannotBeEvaded"
			local handCondition = (pass.label == "Off Hand") and "OffHandAttack" or "MainHandAttack"
			if exceedsHitChance and output.AccuracyHitChanceUncapped - 100 > 0 then
				skillModList:NewMod("Multiplier:ExcessHitChance", "BASE", round(output.AccuracyHitChanceUncapped - 100, 2), "HitChanceCanExceed100", { type = "Condition", var = handCondition})
			end
			if breakdown then
				breakdown.AccuracyHitChance = {
					localisation:Text("calc.offence.accuracy_hit_chance.line", { enemy_level = env.enemyLevel, value = ((env.configInput.enemyLevel and localisation:Ref("calc.offence.accuracy_hit_chance.line.parameter")) or localisation:Ref("calc.offence.accuracy_hit_chance.line.parameter_2")) }),
					localisation:Text("calc.offence.accuracy_hit_chance.line_2", { enemy_evasion = enemyEvasion }),
					"",
					localisation:Text("calc.offence.accuracy_hit_chance.line_3"),
					}
				-- Calculating individual hit chances at different distances
				local hitChances = {}
				hitChances[1] = {distance = enemyDistance}
				local buffers = {
					dist = {"     ", "   ", "  ", ""}, -- these define the number of required spaces based on string length to have the numbers aligned (it's not a simple length * x due to linting that happens later)
					chance = {"    ", "  ", ""}
				}
				for _, distance in ipairs(distances) do -- put distance values in order, incl. config value
					if distance < hitChances[#hitChances].distance then
						t_insert(hitChances, #hitChances, { distance = distance })
					elseif distance > hitChances[#hitChances].distance then
						t_insert(hitChances, { distance = distance })
					end
				end
				for _, entry in ipairs(hitChances) do
					entry.adjustedAccuracy = ((entry.distance == enemyDistance) and accuracyVsEnemy) or  m_floor(accuracyVsEnemyBase * ((noAccuracyDistancePenalty and 1) or accuracyPenalties["accuracyPenalty" .. entry.distance .. "m"])) -- checking here for noAccuracyDistancePenalty again because it's otherwise only used to calculate accuracyVsEnemy, which uses the config distance value
					entry.capped = ((entry.distance == enemyDistance) and output.AccuracyHitChance) or (cannotBeEvaded and 100) or m_max(calcs.hitChance(enemyEvasion, entry.adjustedAccuracy) * hitChanceMod)
					entry.uncapped = exceedsHitChance and m_max(calcs.hitChance(enemyEvasion, entry.adjustedAccuracy, true) * hitChanceMod, entry.capped) -- compare to capped to account for cannotBeEvaded
					entry.excess = exceedsHitChance and entry.uncapped > 100 and entry.uncapped - entry.capped
					entry.distBuffer = buffers.dist[string.len(entry.distance)] -- buffer defines the number of spaces needed to align the output numbers
					entry.cappedBuffer = buffers.chance[string.len(entry.capped)]
					entry.excessText = entry.excess and " ^8(+" .. buffers.chance[string.len(entry.excess)+1] .. entry.excess .. "%)" or ""
					entry.config = (entry.distance == enemyDistance) and " ^8(current config)" or ""
					t_insert(breakdown.AccuracyHitChance, entry.distBuffer .. entry.distance .. "m: " .. entry.cappedBuffer .. entry.capped .. "%" .. entry.excessText .. entry.config)
				end
				-- Add note for uncapped hit chance / "Chance to hit with Attacks can exceed 100%"
				if exceedsHitChance then
					t_insert(breakdown.AccuracyHitChance, "") -- empty line for better readability
					t_insert(breakdown.AccuracyHitChance, localisation:Text("calc.offence.offence.line_30"))
					t_insert(breakdown.AccuracyHitChance, "") -- empty line for better readability
				end
			end
		end
		--enemy block chance
		output.enemyBlockChance = m_max(m_min((enemyDB:Sum("BASE", cfg, "BlockChance") or 0), 100) - skillModList:Sum("BASE", cfg, "reduceEnemyBlock"), 0)
		if enemyDB:Flag(nil, "CannotBlockAttacks") and isAttack then
			output.enemyBlockChance = 0
		end

		output.HitChance = output.AccuracyHitChance * (1 - output.enemyBlockChance / 100)
		if output.enemyBlockChance > 0 and not isAttack then
			globalOutput.enemyHasSpellBlock = true
		end
		if breakdown and output.enemyBlockChance > 0 then
			if output.AccuracyHitChance < 100 then
				breakdown.HitChance = {
					localisation:Text("calc.offence.hit_chance.line_5", { accuracy_hit_chance = output.AccuracyHitChance }),
					localisation:Text("calc.offence.hit_chance.line_6", { enemy_block_chance = output.enemyBlockChance }),
					localisation:Text("calc.offence.hit_chance.line_7", { hit_chance = output.HitChance }),
				}
			else
				breakdown.HitChance = {
					localisation:Text("calc.offence.hit_chance.line_6", { enemy_block_chance = output.enemyBlockChance }),
					localisation:Text("calc.offence.hit_chance.line_7", { hit_chance = output.HitChance }),
				}
			end
		end

		-- Check Precise Technique Keystone condition per pass as MH/OH might have different values
		local condName = pass.label:gsub(" ", "") .. "AccRatingHigherThanMaxLife"
		skillModList.conditions[condName] = ( output.Accuracy and output.Accuracy or 0 ) > env.player.output.Life

		-- Calculate attack/cast speed
		if activeSkill.activeEffect.grantedEffect.castTime == 0 and not skillData.castTimeOverride and not skillData.triggered then
			output.Time = 0
			output.Speed = 0
		elseif skillData.timeOverride then
			output.Time = skillData.timeOverride
			output.Speed = 1 / output.Time
		elseif skillData.fixedCastTime then
			output.Time = activeSkill.activeEffect.grantedEffect.castTime
			output.Speed = 1 / output.Time
		elseif skillData.triggerTime and skillData.triggered then
			local activeSkillsLinked = skillModList:Sum("BASE", cfg, "ActiveSkillsLinkedToTrigger")
			if activeSkillsLinked > 0 then
				output.Time = skillData.triggerTime / (1 + skillModList:Sum("INC", cfg, "CooldownRecovery") / 100) * activeSkillsLinked
			else
				output.Time = skillData.triggerTime / (1 + skillModList:Sum("INC", cfg, "CooldownRecovery") / 100)
			end
			output.TriggerTime = output.Time
			output.Speed = 1 / output.Time
		elseif skillData.triggerRate and skillData.triggered then
			output.Time = 1 / skillData.triggerRate
			output.TriggerTime = output.Time
			output.Speed = skillData.triggerRate
			skillData.showAverage = false
		else
			local baseTime
			if isAttack then
				if skillData.attackSpeedMultiplier and source.AttackRate then
					source.AttackRate = source.AttackRate * (1 + skillData.attackSpeedMultiplier / 100)
				end
				if skillData.castTimeOverridesAttackTime then
					-- Skill is overriding weapon attack speed
					baseTime = activeSkill.activeEffect.grantedEffect.castTime / (1 + (source.AttackSpeedInc or 0) / 100)
				elseif calcLib.mod(skillModList, skillCfg, "SkillAttackTime") > 0 then
					baseTime = (1 / ( source.AttackRate or 1 ) + skillModList:Sum("BASE", cfg, "Speed")) * calcLib.mod(skillModList, skillCfg, "SkillAttackTime")
				else
					baseTime = 1 / ( source.AttackRate or 1 ) + skillModList:Sum("BASE", cfg, "Speed")
				end
			else
				baseTime = (skillData.castTimeOverride or activeSkill.activeEffect.grantedEffect.castTime or 1) + skillModList:Sum("BASE", cfg, "Speed")
			end
			local more = skillModList:More(cfg, "Speed")
			output.Repeats = globalOutput.Repeats or 1

			--Calculates the max number of trauma stacks you can sustain
			if skillModList:Flag(nil, "HasTrauma") then
				local effectiveAttackRateCap = data.misc.ServerTickRate * output.Repeats
				local duration = skillModList:Sum("BASE", cfg, "TraumaDuration") * calcLib.mod(skillModList, skillCfg, "Duration", "DamagingAilmentDuration")
				local traumaPerAttack = 1 + m_min(skillModList:Sum("BASE", cfg, "ExtraTrauma"), 100) / 100
				local incAttackSpeedPerTrauma = skillModList:Sum("INC", skillCfg, "SpeedPerTrauma")
				-- compute trauma using an exact form.
				local configTrauma = skillModList:Sum("BASE", skillCfg, "Multiplier:TraumaStacks")
				local inc = skillModList:Sum("INC", cfg, "Speed") - incAttackSpeedPerTrauma * configTrauma -- remove trauma attack speed added by config.
				local attackSpeedBeforeInc = 1 / baseTime * globalOutput.ActionSpeedMod * more
				local incAttackSpeedPerTraumaCap = (effectiveAttackRateCap - attackSpeedBeforeInc * (1 + inc / 100)) / attackSpeedBeforeInc * 100
				local traumaRateBeforeInc = traumaPerAttack * (output.HitChance / 100) * attackSpeedBeforeInc / output.Repeats
				local trauma = traumaRateBeforeInc * (1 + inc / 100) / ( 1 / duration - traumaRateBeforeInc * incAttackSpeedPerTrauma / 100 )
				local traumaBreakdown = trauma
				local invalid = false
				if trauma < 0 or incAttackSpeedPerTrauma * trauma > incAttackSpeedPerTraumaCap then -- invalid long term trauma generation as maximum attack rate is once per tick.
					trauma = traumaPerAttack * (output.HitChance / 100) * effectiveAttackRateCap / output.Repeats * duration
					invalid = true
				end
				if skillFlags.bothWeaponAttack then -- halve trauma rate when dual wielding so pass 2 doesn't double your trauma rate
					trauma = trauma / 2
				end
				skillModList:NewMod("Multiplier:SustainableTraumaStacks", "BASE", trauma, "Maximum Sustainable Trauma Stacks")
				if breakdown then
					storedSustainedTraumaBreakdown = { }
					if incAttackSpeedPerTrauma == 0 then
						breakdown.multiChain(storedSustainedTraumaBreakdown, {
							label = "Trauma", labelKey = "ui.calc_offence.offence.label_10",
							base = { "%.2f ^8(attack speed)", attackSpeedBeforeInc * (1 + inc/100), formatKey = "calc.offence.offence.factor_28", formatParams = { value = 2 } },
							{ "%.2f ^8(trauma per attack)", traumaPerAttack, formatKey = "calc.offence.offence.factor_29", formatParams = { trauma_per_attack = 2 } },
							{ "%.2f ^8(chance to hit)", (output.HitChance / 100), formatKey = "calc.offence.offence.factor_30", formatParams = { value = 2 } },
							{ "%.2f ^8(duration)", duration, formatKey = "calc.offence.offence.factor_31", formatParams = { duration = 2 } },
							noTotal = true
						})
						if output.Repeats ~= 1 then
							t_insert(storedSustainedTraumaBreakdown, localisation:Text("calc.offence.offence.line_31", { repeats = output.Repeats }))
						end
					else
						breakdown.multiChain(storedSustainedTraumaBreakdown, {
							label = "Attack Speed before increased Attack Speed", labelKey = "ui.calc_offence.offence.label",
							base = { "%.2f ^8(base)", 1 / baseTime, formatKey = "calc.offence.offence.factor_32", formatParams = { value = 2 } },
							{ "%.2f ^8(more/less)", more, formatKey = "calc.offence.offence.factor_23", formatParams = { more = 2 } },
							{ "%.2f ^8(action speed modifier)", globalOutput.ActionSpeedMod, formatKey = "calc.offence.offence.factor_33", formatParams = { action_speed_mod = 2 } },
							total = localisation:Text("calc.offence.offence.line_32", { attack_speed_before_inc = attackSpeedBeforeInc })
						})
						t_insert(storedSustainedTraumaBreakdown, "")
						breakdown.multiChain(storedSustainedTraumaBreakdown, {
							label = "Trauma per second before increased Attack Speed", labelKey = "ui.calc_offence.offence.label_11",
							base = { "%.2f ^8(base)", attackSpeedBeforeInc, formatKey = "calc.offence.offence.factor_34", formatParams = { attack_speed_before_inc = 2 } },
							{ "%.2f ^8(trauma per attack)", traumaPerAttack, formatKey = "calc.offence.offence.factor_29", formatParams = { trauma_per_attack = 2 } },
							{ "%.2f ^8(chance to hit)", (output.HitChance / 100), formatKey = "calc.offence.offence.factor_30", formatParams = { value = 2 } },
							noTotal = true
						})
						if output.Repeats ~= 1 then
							t_insert(storedSustainedTraumaBreakdown, localisation:Text("calc.offence.offence.line_31", { repeats = output.Repeats }))
						end
						t_insert(storedSustainedTraumaBreakdown, localisation:Text("calc.offence.offence.line_33", { trauma_rate_before_inc = traumaRateBeforeInc }))
						t_insert(storedSustainedTraumaBreakdown, "")
						t_insert(storedSustainedTraumaBreakdown, localisation:Text("calc.offence.offence.line_34"))
						t_insert(storedSustainedTraumaBreakdown, localisation:Text("calc.offence.offence.line_35", { trauma_rate_before_inc = traumaRateBeforeInc }))
						t_insert(storedSustainedTraumaBreakdown, localisation:Text("calc.offence.offence.line_36", { value = 1 + inc / 100 }))
						t_insert(storedSustainedTraumaBreakdown, localisation:Text("calc.offence.offence.line_37", { value = 1 / duration - traumaRateBeforeInc * incAttackSpeedPerTrauma / 100 }))
					end
					t_insert(storedSustainedTraumaBreakdown, localisation:Text("calc.offence.offence.line_238", { value = ((invalid and colorCodes.NEGATIVE) or ""), trauma_breakdown = traumaBreakdown }))
					if invalid then
						t_insert(storedSustainedTraumaBreakdown, "")
						t_insert(storedSustainedTraumaBreakdown, localisation:Text("calc.offence.offence.line_38"))
						breakdown.multiChain(storedSustainedTraumaBreakdown, {
							base = { "%.2f ^8(base)", effectiveAttackRateCap, formatKey = "calc.offence.offence.factor_35", formatParams = { effective_attack_rate_cap = 2 } },
							{ "%.2f ^8(trauma per attack)", traumaPerAttack, formatKey = "calc.offence.offence.factor_29", formatParams = { trauma_per_attack = 2 } },
							{ "%.2f ^8(chance to hit)", (output.HitChance / 100), formatKey = "calc.offence.offence.factor_30", formatParams = { value = 2 } },
							{ "%.2f ^8(duration)", (duration), formatKey = "calc.offence.offence.factor_31", formatParams = { duration = 2 } },
							noTotal = true
						})
						if output.Repeats ~= 1 then
							t_insert(storedSustainedTraumaBreakdown, localisation:Text("calc.offence.offence.line_31", { repeats = output.Repeats }))
						end
						t_insert(storedSustainedTraumaBreakdown, localisation:Text("calc.offence.offence.line_39", { trauma = trauma }))
					end
				end
			end
			if skillModList:Sum("BASE", skillCfg, "Multiplier:TraumaStacks") == 0 then
				skillModList:NewMod("Multiplier:TraumaStacks", "BASE", skillModList:Sum("BASE", skillCfg, "Multiplier:SustainableTraumaStacks"), "Maximum Sustainable Trauma Stacks")
			end
			local inc = skillModList:Sum("INC", cfg, "Speed")

			if skillFlags.warcry then
				output.Speed = 1 / output.WarcryCastTime
			else
				output.Speed = 1 / (baseTime / round((1 + inc/100) * more, 2) + skillModList:Sum("BASE", cfg, "TotalAttackTime") + skillModList:Sum("BASE", cfg, "TotalCastTime"))

			end
			output.CastRate = output.Speed
			if skillFlags.selfCast then
				-- Self-cast skill; apply action speed
				output.Speed = output.Speed * globalOutput.ActionSpeedMod
				output.CastRate = output.Speed
			end
			if skillData.channelTimeMultiplier then
				local minTime = skillData.minChannelTime or 0
				local channelTime = output.Speed
				if skillData.channelTimeOverride then
					channelTime = 1 / skillData.channelTimeOverride
				end
				output.ChannelTime = m_max(skillData.channelTimeMultiplier / channelTime, minTime)
				output.ChannelSpeed = output.Speed or output.Time
			end
			if skillFlags.totem then
				-- Totem skill. Apply action speed
				local totemActionSpeed = 1 + (modDB:Sum("INC", nil, "TotemActionSpeed") / 100)
				output.TotemActionSpeed = totemActionSpeed
				output.Speed = output.Speed * totemActionSpeed
				output.CastRate = output.Speed
			end
			if globalOutput.Cooldown then
				output.Cooldown = globalOutput.Cooldown
				if not skillModList:Flag(skillCfg, "CooldownDoesNotLimitSkillSpeed") then
					output.Speed = m_min(output.Speed, 1 / output.Cooldown * output.Repeats)
				end
			end
			if output.Cooldown and skillFlags.selfCast or skillData.maxHitRatePerEnemy or skillData.hitTimeOverride then
				skillFlags.notAverage = true
				skillFlags.showAverage = false
				skillData.showAverage = false
			end
			if not activeSkill.skillTypes[SkillType.Channel] then
				output.Speed = m_min(output.Speed, data.misc.ServerTickRate * output.Repeats)
			end
			-- Crossbows: Adjust attack speed values for Crossbow skills that need to reload
			if skillData.reloadTime and skillData.reloadTime > 0 then
				output.FiringRate = output.Speed
				output.BoltCount = skillData.boltCount
				output.EffectiveBoltCount = output.BoltCount
				output.ChanceToNotConsumeAmmo = activeSkill.skillModList:Sum("BASE", activeSkill.skillCfg, "ChanceToNotConsumeAmmo")
				output.ChanceToReloadInstantly = m_min(activeSkill.skillModList:Sum("BASE", activeSkill.skillCfg, "InstantReloadChance"), 100)
				if output.ChanceToNotConsumeAmmo > 0 then
					if output.ChanceToNotConsumeAmmo < 100 then
						output.EffectiveBoltCount = output.BoltCount / (1 - (output.ChanceToNotConsumeAmmo / 100))
					else
						output.EffectiveBoltCount = 1 / 0 -- apparently division by zero is handled as "infinite" just fine
					end
				end
				output.TotalFiringTime = 1 / output.FiringRate * ((output.ChanceToNotConsumeAmmo >= 100) and 0 or output.EffectiveBoltCount)
				output.ReloadRate = 1 / skillData.reloadTime
				output.ReloadTime = skillData.reloadTime
				output.EffectiveReloadTime = output.ReloadTime * (1 - output.ChanceToReloadInstantly / 100)
				output.Speed = (output.ChanceToNotConsumeAmmo >= 100) and output.FiringRate or (1 / ((output.TotalFiringTime + output.EffectiveReloadTime) / (output.EffectiveBoltCount)))

				-- Average bolts reloaded past six second for purposes of calculating Fresh Clip support damage bonus
				local boltsReloadedPastSixSeconds = skillModList:Override({ source = "Config"}, "Multiplier:BoltsReloadedPastSixSeconds") or (output.ChanceToNotConsumeAmmo > 100) and 0 or (output.BoltCount * 6 / (output.TotalFiringTime + output.EffectiveReloadTime)) -- assume 0 bolts reloaded when none are consumed
				local boltsReloadedPastEightSeconds = skillModList:Override({ source = "Config"}, "Multiplier:BoltsReloadedPastEightSeconds") or (output.ChanceToNotConsumeAmmo > 100) and 0 or (output.BoltCount * 8 / (output.TotalFiringTime + output.EffectiveReloadTime)) -- assume 0 bolts reloaded when none are consumed
				if boltsReloadedPastSixSeconds > 0 then
					skillModList:ReplaceMod("Multiplier:BoltsReloadedPastSixSeconds", "BASE", boltsReloadedPastSixSeconds, activeSkill.activeEffect.grantedEffect.name)
				end
				if boltsReloadedPastEightSeconds > 0 then
					skillModList:ReplaceMod("Multiplier:BoltsReloadedPastEightSeconds", "BASE", boltsReloadedPastEightSeconds, activeSkill.activeEffect.grantedEffect.name)
				end
			end
			if output.Speed == 0 then
				output.Time = 0
			else
				output.Time = 1 / output.Speed
			end
			if breakdown then
				breakdown.Speed = { }
				breakdown.multiChain(breakdown.Speed, {
					base = { "%.2f ^8(base)", 1 / baseTime, formatKey = "calc.offence.offence.factor_32", formatParams = { value = 2 } },
					{ "%.2f ^8(increased/reduced)", 1 + inc/100, formatKey = "calc.offence.offence.factor_36", formatParams = { value = 2 } },
					{ "%.2f ^8(more/less)", more, formatKey = "calc.offence.offence.factor_23", formatParams = { more = 2 } },
					{ "%.2f ^8(action speed modifier)", (skillFlags.totem and output.TotemActionSpeed) or (skillFlags.selfCast and globalOutput.ActionSpeedMod) or 1, formatKey = "calc.offence.offence.factor_37", formatParams = { value = 2 } },
					total = localisation:Text("calc.offence.offence.line_40", { cast_rate = output.CastRate })
				})
				-- Crossbows: adjust breakdown to account for effect of reload time, bolt count, etc.
				-- note: if we are ever allowed to dual wield crossbows, this will need to be adjusted
				-- TODO: properly reflect effects of "SkillAttackTime" mods in the breakdown. (This is also not currently done in the standard breakdown.Speed calculation)
				if output.ReloadTime and source.ReloadTime then
					globalBreakdown.FiringRate = { }
					breakdown.multiChain(globalBreakdown.FiringRate, {
						base = { "%.2f ^8(base)", 1 / baseTime, formatKey = "calc.offence.offence.factor_32", formatParams = { value = 2 } },
						{ "%.2f ^8(increased/reduced)", 1 + inc/100, formatKey = "calc.offence.offence.factor_36", formatParams = { value = 2 } },
						{ "%.2f ^8(more/less)", more, formatKey = "calc.offence.offence.factor_23", formatParams = { more = 2 } },
						{ "%.2f ^8(action speed modifier)", (skillFlags.totem and output.TotemActionSpeed) or (skillFlags.selfCast and globalOutput.ActionSpeedMod) or 1, formatKey = "calc.offence.offence.factor_37", formatParams = { value = 2 } }, -- currently no way fir standard crossbow skills to be used by totems, but leaving it in for future compatibility
						total = localisation:Text("calc.offence.offence.line_41", { firing_rate = output.FiringRate })
					})

					globalBreakdown.TotalFiringTime = { }
					t_insert(globalBreakdown.TotalFiringTime, localisation:Text("calc.offence.offence.line_42", { firing_rate = output.FiringRate }))
					t_insert(globalBreakdown.TotalFiringTime, localisation:Text("calc.offence.offence.line_43", { value = 1 / output.FiringRate }))
					t_insert(globalBreakdown.TotalFiringTime, s_format("\n"))
					t_insert(globalBreakdown.TotalFiringTime, localisation:Text("calc.offence.offence.line_44", { value = 1/ output.FiringRate }))
					t_insert(globalBreakdown.TotalFiringTime, localisation:Text("calc.offence.offence.line_45", { effective_bolt_count = output.EffectiveBoltCount }))
					t_insert(globalBreakdown.TotalFiringTime, localisation:Text("calc.offence.offence.line_46", { total_firing_time = output.TotalFiringTime }))

					globalBreakdown.ReloadTime = { }
					local baseReloadTime = source.ReloadTime
					local incReloadSpeed = skillModList:Sum("INC", skillCfg, "ReloadSpeed")
					local moreReloadSpeed = skillModList:More("MORE", skillCfg, "ReloadSpeed")
					t_insert(globalBreakdown.ReloadTime, localisation:Text("calc.offence.offence.line_47", { base_reload_time = baseReloadTime }))
					t_insert(globalBreakdown.ReloadTime, localisation:Text("calc.offence.offence.line_48", { value = 1 / baseReloadTime }))
					t_insert(globalBreakdown.ReloadTime, s_format("\n"))
					t_insert(globalBreakdown.ReloadTime, localisation:Text("calc.offence.offence.line_49"))
					t_insert(globalBreakdown.ReloadTime, localisation:Text("calc.offence.offence.line_50", { value = 1 + (incReloadSpeed/100) + (inc/100) }))
					t_insert(globalBreakdown.ReloadTime, localisation:Text("calc.offence.offence.line_51", { value = 1 * moreReloadSpeed * more }))
					t_insert(globalBreakdown.ReloadTime, localisation:Text("calc.offence.offence.line_52", { reload_rate = output.ReloadRate }))
					t_insert(globalBreakdown.ReloadTime, s_format("\n"))
					t_insert(globalBreakdown.ReloadTime, localisation:Text("calc.offence.offence.line_53", { reload_rate = output.ReloadRate }))
					t_insert(globalBreakdown.ReloadTime, localisation:Text("calc.offence.offence.line_54", { reload_time = output.ReloadTime }))

					breakdown.Speed = { }
					t_insert(breakdown.Speed, localisation:Text("calc.offence.offence.line_55", { total_firing_time = output.TotalFiringTime }))
					t_insert(breakdown.Speed, localisation:Text("calc.offence.offence.line_56", { effective_reload_time = output.EffectiveReloadTime }))
					t_insert(breakdown.Speed, localisation:Text("calc.offence.offence.line_57", { value = output.TotalFiringTime + output.EffectiveReloadTime }))
					t_insert(breakdown.Speed, s_format("\n"))
					t_insert(breakdown.Speed, localisation:Text("calc.offence.offence.line_58", { value = output.TotalFiringTime + output.EffectiveReloadTime }))
					t_insert(breakdown.Speed, localisation:Text("calc.offence.offence.line_59", { effective_bolt_count = output.EffectiveBoltCount }))
					t_insert(breakdown.Speed, localisation:Text("calc.offence.offence.line_60", { value = 1 / output.Speed }))
					t_insert(breakdown.Speed, s_format("\n"))
					t_insert(breakdown.Speed, localisation:Text("calc.offence.offence.line_61", { value = 1 / output.Speed }))
					t_insert(breakdown.Speed, localisation:Text("calc.offence.offence.line_62", { speed = output.Speed }))
				end
				-- Cooldown:
				if output.Cooldown and (1 / output.Cooldown) < output.CastRate and not skillModList:Flag(skillCfg, "CooldownDoesNotLimitSkillSpeed") then
					t_insert(breakdown.Speed, s_format("\n"))
					t_insert(breakdown.Speed, localisation:Text("calc.offence.offence.line_63", { cooldown = output.Cooldown }))
					if output.Repeats > 1 then
						t_insert(breakdown.Speed, localisation:Text("calc.offence.offence.line_64", { repeats = output.Repeats }))
					end
					t_insert(breakdown.Speed, localisation:Text("calc.offence.offence.line_65", { value = output.Repeats / output.Cooldown }))
					t_insert(breakdown.Speed, s_format("\n"))
					t_insert(breakdown.Speed, localisation:Text("calc.offence.offence.line_66", { speed = output.Speed }))
				end
			end
			if breakdown and calcLib.mod(skillModList, skillCfg, "SkillAttackTime") > 0 then
				breakdown.Time = { }
				breakdown.multiChain(breakdown.Time, {
					base = { "%.2f ^8(base)", 1 / (output.Speed * calcLib.mod(skillModList, skillCfg, "SkillAttackTime") ), formatKey = "calc.offence.offence.factor_38", formatParams = { value = 2 } },
					{ "%.2f ^8(total modifier)", calcLib.mod(skillModList, skillCfg, "SkillAttackTime"), formatKey = "calc.offence.offence.factor_39", formatParams = { value = 2 } },
					total = localisation:Text("calc.offence.offence.line_67", { time = output.Time })
				})
			end

		end
		if skillData.hitTimeOverride and not skillData.triggeredOnDeath or skillData.maxHitRatePerEnemy then
			--checks if skill has a max hit rate per enemy and adjust hitTimeOverride
			if skillData.maxHitRatePerEnemy and not skillData.hitTimeOverride then
				skillData.hitTimeOverride = skillData.maxHitRatePerEnemy
			elseif skillData.maxHitRatePerEnemy and skillData.hitTimeOverride < skillData.maxHitRatePerEnemy then
				skillData.hitTimeOverride = skillData.maxHitRatePerEnemy
			end
			output.HitTime = skillData.hitTimeOverride
			output.HitSpeed = 1 / output.HitTime
			--Brands always have hitTimeOverride
			if skillFlags.brand and not skillModList:Flag(nil, "UnlimitedBrandDuration") then
				output.BrandTicks = m_floor(output.Duration * output.HitSpeed)
			end
		elseif skillData.hitTimeMultiplier and output.Time and not skillData.triggeredOnDeath then
			output.HitTime = output.Time * skillData.hitTimeMultiplier
			if skillFlags.channelRelease and skillData.minChannelTime then
				output.HitTime = m_max(output.HitTime, skillData.minChannelTime)
			end
			if output.Cooldown and skillData.triggered then
				output.HitSpeed = 1 / (m_max(output.HitTime, output.Cooldown))
			elseif output.Cooldown and not skillFlags.channelRelease then
				output.HitSpeed = 1 / (output.HitTime + output.Cooldown)
			else
				output.HitSpeed = 1 / output.HitTime
			end
		end
	end
	-- Other Misc DPS multipliers (like custom source)
	if env.configInput.repeatMode == "FINAL" or skillModList:Flag(nil, "OnlyFinalRepeat") then
		skillModList:NewMod("DPS", "MORE", -100 / (output.Repeats or 1), "Only Final Repeat")
	end
	if skillModList:Flag(nil, "TriggeredBySnipe") then
		skillFlags.channelRelease = true
	end
	if breakdown then
		breakdown.SustainableTrauma = storedSustainedTraumaBreakdown
	end
	output.SustainableTrauma = skillModList:Flag(nil, "HasTrauma") and skillModList:Sum("BASE", skillCfg, "Multiplier:SustainableTraumaStacks")
	--Mantra of Flames buff count
	modDB.multipliers["BuffOnSelf"] = (modDB.multipliers["BuffOnSelf"] or 0) + skillModList:Sum("BASE", cfg, "Multiplier:TraumaStacks")
	modDB.multipliers["BuffOnSelf"] = (modDB.multipliers["BuffOnSelf"] or 0) + skillModList:Sum("BASE", cfg, "Multiplier:VoltaxicWaitingStages")
	if isAttack then
		-- Combine hit chance and attack speed
		combineStat("AccuracyHitChance", "AVERAGE")
		combineStat("HitChance", "AVERAGE")
		combineStat("AccuracyHitChanceUncapped", "AVERAGE")
		combineStat("Speed", "HARMONICMEAN")
		combineStat("HitSpeed", "OR")
		combineStat("HitTime", "OR")
		if output.Speed == 0 then
			output.Time = 0
		else
			output.Time = 1 / output.Speed
		end

		if output.Time > 1 then
			modDB:NewMod("Condition:OneSecondAttackTime", "FLAG", true)
		end
		if skillModList:Flag(nil, "UseOffhandAttackSpeed") then
			output.Speed = output.OffHand.Speed
			output.Time = output.OffHand.Time
			if breakdown then
				breakdown.Speed = {
					localisation:Text("calc.offence.speed.line_2"),
					s_format("= %.2f", output.Speed),
				}
			end
		elseif skillFlags.bothWeaponAttack then
			if breakdown then
				if skillData.combinesHitsWhenDualWielding then
					breakdown.Speed = {
						localisation:Text("calc.offence.speed.line_3"),
						s_format("1 / (1 / %.2f + 1 / %.2f)", output.MainHand.Speed, output.OffHand.Speed),
						s_format("= %.2f", output.Speed),
					}
				elseif skillData.doubleHitsWhenDualWielding then
					breakdown.Speed = {
						localisation:Text("calc.offence.speed.line_4"),
						s_format("2 / (1 / %.2f + 1 / %.2f)", output.MainHand.Speed, output.OffHand.Speed),
						localisation:Text("calc.offence.speed.line", { speed = output.Speed }),
						s_format("= %.2f", output.Speed),
					}
				else
					breakdown.Speed = {
						localisation:Text("calc.offence.speed.line_5"),
						s_format("2 / (1 / %.2f + 1 / %.2f)", output.MainHand.Speed, output.OffHand.Speed),
						s_format("= %.2f", output.Speed),
					}
				end
			end
		end
		if skillData.channelTimeMultiplier then
			local minTime = skillData.minChannelTime or 0
			local channelTime = output.Speed
			if skillData.channelTimeOverride then
				channelTime = 1 / skillData.channelTimeOverride
			end
			output.ChannelTime = m_max(skillData.channelTimeMultiplier / channelTime, minTime)
			output.ChannelSpeed = output.Speed or output.Time
		end
		if breakdown then
			if skillFlags.bothWeaponAttack then
				breakdown.HitChance = {
					localisation:Text("calc.offence.hit_chance.line_4"),
					localisation:Text("calc.offence.hit_chance.line", { hit_chance = output.MainHand.HitChance }),
					localisation:Text("calc.offence.hit_chance.line_2", { hit_chance = output.OffHand.HitChance }),
					localisation:Text("calc.offence.hit_chance.line_3", { hit_chance = output.HitChance }),
				}
			else
				local handBreakdown = skillFlags.weapon1Attack and breakdown.MainHand or breakdown.OffHand
				breakdown.HitChance = handBreakdown.HitChance or handBreakdown.AccuracyHitChance
				breakdown.Speed = breakdown.Speed or handBreakdown.Speed
			end
		end
		if skillData.hitTimeOverride and not skillData.triggeredOnDeath then
			output.HitTime = skillData.hitTimeOverride
			output.HitSpeed = 1 / output.HitTime
		elseif skillData.timeOverride and not skillData.triggeredOnDeath then
			output.Time = skillData.timeOverride
		elseif skillData.hitTimeMultiplier and output.Time and not skillData.triggeredOnDeath then
			output.HitTime = output.Time * skillData.hitTimeMultiplier
			if skillFlags.channelRelease and skillData.minChannelTime then
				output.HitTime = m_max(output.HitTime, skillData.minChannelTime)
			end
			if output.Cooldown and skillData.triggered then
				output.HitSpeed = 1 / (m_max(output.HitTime, output.Cooldown))
			elseif output.Cooldown then
				output.HitSpeed = 1 / (output.HitTime + output.Cooldown)
			else
				output.HitSpeed = m_min(1 / output.HitTime, data.misc.ServerTickRate)
			end
		end
	end
	if breakdown then
		if skillData.channelTimeMultiplier and output.Time and not skillData.triggeredOnDeath then
			breakdown.ChannelTime = { }
			if skillData.minChannelTime then
				t_insert(breakdown.ChannelTime, localisation:Text("calc.offence.offence.line_68", { min_channel_time = skillData.minChannelTime }))
				t_insert(breakdown.ChannelTime, s_format(""))
			end
			if isAttack then
				t_insert(breakdown.ChannelTime, localisation:Text("calc.offence.offence.line_69", { value = 1 / output.ChannelSpeed }))
			else
				t_insert(breakdown.ChannelTime, localisation:Text("calc.offence.offence.line_70", { value = 1 / output.ChannelSpeed }))
			end
			t_insert(breakdown.ChannelTime, localisation:Text("calc.offence.offence.line_71", { channel_time_multiplier = skillData.channelTimeMultiplier }))
			t_insert(breakdown.ChannelTime, s_format("= %.2f", output.ChannelTime))
		end
		if skillData.hitTimeOverride and not skillData.triggeredOnDeath then
			breakdown.HitSpeed = { }
			t_insert(breakdown.HitSpeed, localisation:Text("calc.offence.offence.line_72", { hit_time = output.HitTime }))
			t_insert(breakdown.HitSpeed, s_format("= %.2f", output.HitSpeed))
		elseif skillData.hitTimeMultiplier and output.Time and not skillData.triggeredOnDeath then
			breakdown.HitTime = { }
			if m_floor(skillData.hitTimeMultiplier) ~= skillData.hitTimeMultiplier then
				t_insert(breakdown.HitTime, localisation:Text("calc.offence.offence.line_73", { custom = colorCodes.CUSTOM, value = skillData.hitTimeMultiplier - m_floor(skillData.hitTimeMultiplier) }))
			end
			if isAttack then
				t_insert(breakdown.HitTime, localisation:Text("calc.offence.offence.line_74", { time = output.Time }))
			else
				t_insert(breakdown.HitTime, localisation:Text("calc.offence.offence.line_75", { time = output.Time }))
			end
			t_insert(breakdown.HitTime, localisation:Text("calc.offence.offence.line_76", { hit_time_multiplier = skillData.hitTimeMultiplier }))
			t_insert(breakdown.HitTime, s_format("= %.2f", output.HitTime))
			breakdown.HitSpeed = { }
			if output.Cooldown and skillData.triggered then
				t_insert(breakdown.HitSpeed, localisation:Text("calc.offence.offence.line_77", { hit_time = output.HitTime, cooldown = output.Cooldown }))
			elseif output.Cooldown then
				t_insert(breakdown.HitSpeed, localisation:Text("calc.offence.offence.line_78", { hit_time = output.HitTime, cooldown = output.Cooldown }))
			else
				t_insert(breakdown.HitSpeed, localisation:Text("calc.offence.offence.line_79", { hit_time = output.HitTime }))
			end
			t_insert(breakdown.HitSpeed, s_format("= %.2f", output.HitSpeed))
		end
	end

	-- Grab quantity multiplier
	local quantityMultiplier = m_max(activeSkill.skillModList:Sum("BASE", activeSkill.skillCfg, "QuantityMultiplier"), 1)
	if quantityMultiplier > 1 then
		output.QuantityMultiplier = quantityMultiplier
	end

	if activeSkill.skillTypes[SkillType.UsableWhileMoving] then
		local inc = skillModList:Sum("INC", skillCfg, "MovementSpeedPenalty")
		local more = skillModList:More(skillCfg, "MovementSpeedPenalty")
		local penaltyMod = m_max(0, skillModList:Override(skillCfg, "MovementSpeedPenalty") or (1 + inc / 100) * more)
		local base = calcLib.mod(skillModList, skillCfg, "SkillMovementSpeed")
		local total = (1 - base) * penaltyMod
		output.MovementSpeedWhileUsingSkill = (1 - total) * output.MovementSpeedMod
		output.MovementSpeedWhileUsingSkillPercent = (1 - total) * 100
		if breakdown then
			breakdown.MovementSpeedWhileUsingSkill = {
				localisation:Text("calc.offence.movement_speed_while_using_skill.line_7"),
				localisation:Text("calc.offence.movement_speed_while_using_skill.line_8"),
				localisation:Text("calc.offence.movement_speed_while_using_skill.line_9"),
				"",
				localisation:Text("calc.offence.movement_speed_while_using_skill.line", { value = 100 - base * 100 }),
				localisation:Text("calc.offence.movement_speed_while_using_skill.line_2", { value = 1 + inc / 100 }),
				localisation:Text("calc.offence.movement_speed_while_using_skill.line_3", { more = more }),
				localisation:Text("calc.offence.movement_speed_while_using_skill.line_4", { value = 100 - output.MovementSpeedWhileUsingSkillPercent }),
				s_format(""),
				localisation:Text("calc.offence.movement_speed_while_using_skill.line_5", { value = 100 - output.MovementSpeedWhileUsingSkillPercent }),
				localisation:Text("calc.offence.movement_speed_while_using_skill.line_6", { movement_speed_while_using_skill_percent = output.MovementSpeedWhileUsingSkillPercent }),
			}
		end
	end

	-- Calculate leech
	local function getLeechInstances(amount, total, hitRate)
		if total == 0 then
			return 0, 0
		end
		local duration = amount / total / data.misc.LeechRateBase
		return duration, duration * hitRate
	end
	-- dynamic way of calculating the Ancestral Boost from a single source without duplicating the code
	-- uptimeOverride: Ancestral Empowerment
	-- combinedCalcs: ignore INC AoE as we will run that in calcCombinedAncestralBoost
	local function calcAncestralBoost(skillName, moreDmg, uptimeOverride, combinedCalcs)
		globalOutput.CreateWarcryOffensiveCalcSection = true -- labels for the CalcSection
		local skillNameVar = skillName:gsub(" ", "")   -- Fist Of War -> FistOfWar
		local skillNameLabel = skillName:lower()

		globalOutput[skillNameVar .. "DamageMultiplier"] = moreDmg or 1
		globalOutput[skillNameVar .. "UptimeRatio"] = uptimeOverride or m_min((1 / globalOutput.Speed) / globalOutput[skillNameVar .. "Cooldown"], 1) * 100
		if globalBreakdown then
			globalBreakdown[skillNameVar .. "UptimeRatio"] = {
				localisation:Text("calc.offence.calc_ancestral_boost.line", { speed = globalOutput.Speed }),
				localisation:Text("calc.offence.calc_ancestral_boost.line_2", { skill_name_label = skillNameLabel, value = ((uptimeOverride and 1 / globalOutput.Speed / (uptimeOverride / 100)) or globalOutput[skillNameVar .. "Cooldown"]) }),
				s_format("= %d%%", globalOutput[skillNameVar .. "UptimeRatio"]),
			}
		end
		globalOutput["Avg" .. skillNameVar .. "Damage"] = globalOutput[skillNameVar .. "DamageMultiplier"]
		globalOutput["Avg" .. skillNameVar .. "DamageEffect"] = 1 + globalOutput["Avg" .. skillNameVar .. "Damage"] * (globalOutput[skillNameVar .. "UptimeRatio"] / 100)
		if globalBreakdown then
			globalBreakdown["Avg" .. skillNameVar .. "DamageEffect"] = {
				localisation:Text("calc.offence.calc_ancestral_boost.line_3", { skill_name_label = skillNameLabel, value = globalOutput[skillNameVar .. "DamageMultiplier"] }),
				localisation:Text("calc.offence.calc_ancestral_boost.line_4", { skill_name_label = skillNameLabel, value = globalOutput[skillNameVar .. "UptimeRatio"] / 100 }),
				s_format("= %.2f", globalOutput["Avg" .. skillNameVar .. "DamageEffect"]),
			}
		end
		globalOutput["Max" .. skillNameVar .. "DamageEffect"] = 1 + globalOutput[skillNameVar .. "DamageMultiplier"]
		if activeSkill.skillModList:Flag(nil, "Condition:WarcryMaxHit") then
			output[skillNameVar .. "DamageEffect"] = globalOutput["Max" .. skillNameVar .. "DamageEffect"]
		else
			output[skillNameVar .. "DamageEffect"] = globalOutput["Avg" .. skillNameVar .. "DamageEffect"]
		end
		calcAreaOfEffect(skillModList, skillCfg, skillData, skillFlags, globalOutput, globalBreakdown)
		globalOutput.TheoreticalOffensiveWarcryEffect = globalOutput.TheoreticalOffensiveWarcryEffect * globalOutput["Avg" .. skillNameVar .. "DamageEffect"]
		globalOutput.TheoreticalMaxOffensiveWarcryEffect = globalOutput.TheoreticalMaxOffensiveWarcryEffect * globalOutput["Max" .. skillNameVar .. "DamageEffect"]
	end

	-- combine Ancestral Empowerment with other sources of Slam Ancestral Boost, namely Fist of War, when both active
	local function calcCombinedAncestralBoost(skillName, moreDmg, uptimeOverride, additionalSkillName)
		globalOutput.CreateWarcryOffensiveCalcSection = true -- labels for the CalcSection
		local skillNameVar = skillName:gsub(" ", "")   -- Fist Of War -> FistOfWar
		local skillNameLabel = skillName:lower()

		globalOutput[skillNameVar .. "DamageMultiplier"] = moreDmg or 1
		-- for CalcSections, set the AncestralEmpowerment damage for mod breakdown
		globalOutput[skillNameVar .. "CombinedDamageMultiplier"] = globalOutput[skillNameVar .. "DamageMultiplier"]
		skillNameVar = skillNameVar .. "Combined"
		local additionalSkillNameVar = additionalSkillName:gsub(" ", "")
		local additionalSkillNameLabel = additionalSkillName:lower()

		-- a lot of these are doubled up because it would be very long lines otherwise and hopefully this helps legibility
		globalOutput[skillNameVar .. "UptimeRatio"] = uptimeOverride or m_min((1 / globalOutput.Speed) / globalOutput[skillNameVar .. "Cooldown"], 1) * 100
		globalOutput[skillNameVar .. "UptimeRatio"] = m_min(globalOutput[skillNameVar .. "UptimeRatio"] + (globalOutput[additionalSkillNameVar .. "UptimeRatio"] or 0), 100)
		if globalBreakdown then
			globalBreakdown[skillNameVar .. "UptimeRatio"] = {
				localisation:Text("calc.offence.calc_combined_ancestral_boost.line", { speed = globalOutput.Speed }),
				localisation:Text("calc.offence.calc_combined_ancestral_boost.line_3", { skill_name_label = skillNameLabel, value = ((uptimeOverride and 1 / globalOutput.Speed / (uptimeOverride / 100)) or globalOutput[skillNameVar .. "Cooldown"]) }),
				"+",
				localisation:Text("calc.offence.calc_combined_ancestral_boost.line", { speed = globalOutput.Speed }),
				localisation:Text("calc.offence.calc_combined_ancestral_boost.line_4", { additional_skill_name_label = additionalSkillNameLabel, value = globalOutput[additionalSkillNameVar .. "Cooldown"] }),
				"capped at 100%",
				s_format("= %d%%", globalOutput[skillNameVar .. "UptimeRatio"]),
			}
		end
		globalOutput["Avg" .. skillNameVar .. "Damage"] = globalOutput[skillNameVar .. "DamageMultiplier"]
		globalOutput["Avg" .. skillNameVar .. "DamageEffect"] = 1 + globalOutput["Avg" .. skillNameVar .. "Damage"] * (globalOutput[skillNameVar .. "UptimeRatio"] / 100)
		if globalBreakdown then
			globalBreakdown["Avg" .. skillNameVar .. "DamageEffect"] = {
				localisation:Text("calc.offence.calc_combined_ancestral_boost.line_2", { value = globalOutput[skillNameVar .. "DamageMultiplier"], value_2 = globalOutput[skillNameVar .. "UptimeRatio"] / 100 }),
				s_format("= %.2f", globalOutput["Avg" .. skillNameVar .. "DamageEffect"]),
			}
		end
		globalOutput["Max" .. skillNameVar .. "DamageEffect"] = 1 + globalOutput[skillNameVar .. "DamageMultiplier"]
		if activeSkill.skillModList:Flag(nil, "Condition:WarcryMaxHit") then
			output[skillNameVar .. "DamageEffect"] = globalOutput["Max" .. skillNameVar .. "DamageEffect"]
		else
			output[skillNameVar .. "DamageEffect"] = globalOutput["Avg" .. skillNameVar .. "DamageEffect"]
		end
		calcAreaOfEffect(skillModList, skillCfg, skillData, skillFlags, globalOutput, globalBreakdown)
		globalOutput.TheoreticalOffensiveWarcryEffect = globalOutput.TheoreticalOffensiveWarcryEffect * globalOutput["Avg" .. skillNameVar .. "DamageEffect"]
		globalOutput.TheoreticalMaxOffensiveWarcryEffect = globalOutput.TheoreticalMaxOffensiveWarcryEffect * globalOutput["Max" .. skillNameVar .. "DamageEffect"]
	end
	-- Check if player is supposed to ignore a damage type, or if it's ignored on enemy side
	local useThisResist = function(cfg, damageType)
		return not skillModList:Flag(cfg, "Ignore"..damageType.."Resistance", isElemental[damageType] and "IgnoreElementalResistances" or nil) and not enemyDB:Flag(nil, "SelfIgnore"..damageType.."Resistance")
	end
	--Calculate damage (exerts, crits, ruthless, DPS, etc)
	for _, pass in ipairs(passList) do
		globalOutput, globalBreakdown = output, breakdown
		local source = pass.source
		---@class Output
		local output = pass.output
		local cfg = pass.cfg
		---@class Breakdown
		local breakdown = pass.breakdown

		-- Exerted Attack members
		local exertedDoubleDamage = env.modDB:Sum("BASE", cfg, "ExertDoubleDamageChance")
		local exertingWarcryCount = env.modDB:Sum("BASE", nil, "Multiplier:EmpoweringWarcryCount")
		local warcryPower = modDB:Override(nil, "WarcryPower") or m_max((modDB:Sum("BASE", nil, "WarcryPower") or 0) * (1 + (modDB:Sum("INC", nil, "WarcryPower") or 0) / 100), (modDB:Sum("BASE", nil, "MinimumWarcryPower") or 0))
		globalOutput.OffensiveWarcryEffect = 1
		globalOutput.MaxOffensiveWarcryEffect = 1
		globalOutput.TheoreticalOffensiveWarcryEffect = 1
		globalOutput.TheoreticalMaxOffensiveWarcryEffect = 1
		globalOutput.RallyingHitEffect = 1
		globalOutput.AilmentWarcryEffect = 1
		globalOutput.GlobalWarcryUptimeRatio = 0

		if env.mode_buffs then
			-- Iterative over all the active skills to account for exerted attacks provided by warcries
			if not activeSkill.skillTypes[SkillType.NeverExertable] and not activeSkill.skillTypes[SkillType.Triggered] and not activeSkill.skillTypes[SkillType.OtherThingUsesSkill] and not activeSkill.skillTypes[SkillType.Retaliation] then
				for index, value in ipairs(actor.activeSkillList) do
					if value.activeEffect.grantedEffect.name == "Ancestral Cry" and activeSkill.skillTypes[SkillType.MeleeSingleTarget] and not globalOutput.AncestralCryCalculated then
						globalOutput.AncestralCryDuration = calcSkillDuration(value.skillModList, value.skillCfg, value.skillData, env, enemyDB)
						globalOutput.AncestralCryCooldown = calcSkillCooldown(value.skillModList, value.skillCfg, value.skillData)
						globalOutput.AncestralCryCastTime = calcWarcryCastTime(value.skillModList, value.skillCfg, value.skillData, actor)
						globalOutput.AncestralExertsCount = env.modDB:Sum("BASE", nil, "NumAncestralExerts") or 0
						local baseUptimeRatio = m_min((globalOutput.AncestralExertsCount / globalOutput.Speed) / (globalOutput.AncestralCryCooldown + globalOutput.AncestralCryCastTime), 1) * 100
						local storedUses = value.skillData.storedUses or 0 + value.skillModList:Sum("BASE", value.skillCfg, "AdditionalCooldownUses")
						globalOutput.AncestralUpTimeRatio = m_min(100, baseUptimeRatio * storedUses)
						globalOutput.GlobalWarcryUptimeRatio = globalOutput.GlobalWarcryUptimeRatio + globalOutput.AncestralUpTimeRatio
						if globalBreakdown then
							globalBreakdown.AncestralUpTimeRatio = { }
							t_insert(globalBreakdown.AncestralUpTimeRatio, localisation:Text("calc.offence.offence.line_80", { ancestral_exerts_count = globalOutput.AncestralExertsCount }))
							t_insert(globalBreakdown.AncestralUpTimeRatio, localisation:Text("calc.offence.offence.line_81", { speed = globalOutput.Speed }))
							if globalOutput.AncestralCryCastTime > 0 then
								t_insert(globalBreakdown.AncestralUpTimeRatio, localisation:Text("calc.offence.offence.line_82", { ancestral_cry_cooldown = globalOutput.AncestralCryCooldown }))
								t_insert(globalBreakdown.AncestralUpTimeRatio, localisation:Text("calc.offence.offence.line_83", { ancestral_cry_cast_time = globalOutput.AncestralCryCastTime }))
							else
								t_insert(globalBreakdown.AncestralUpTimeRatio, localisation:Text("calc.offence.offence.line_84", { ancestral_cry_cooldown = globalOutput.AncestralCryCooldown }))
							end
							t_insert(globalBreakdown.AncestralUpTimeRatio, s_format("= %d%%", globalOutput.AncestralUpTimeRatio))
						end
						globalOutput.AncestralCryCalculated = true
					elseif value.activeEffect.grantedEffect.name == "Infernal Cry" and activeSkill.skillTypes[SkillType.Melee] and not globalOutput.InfernalCryCalculated then
						globalOutput.CreateWarcryOffensiveCalcSection = true
						globalOutput.InfernalCryDuration = calcSkillDuration(value.skillModList, value.skillCfg, value.skillData, env, enemyDB)
						globalOutput.InfernalCryCooldown = calcSkillCooldown(value.skillModList, value.skillCfg, value.skillData)
						globalOutput.InfernalCryCastTime = calcWarcryCastTime(value.skillModList, value.skillCfg, value.skillData, actor)
						globalOutput.InfernalEmpoweredCount = env.modDB:Sum("BASE", nil, "NumInfernalEmpowers") or 0
						local baseUptimeRatio = m_min((globalOutput.InfernalEmpoweredCount / globalOutput.Speed) / (globalOutput.InfernalCryCooldown + globalOutput.InfernalCryCastTime), 1) * 100
						local storedUses = value.skillData.storedUses or 0 + value.skillModList:Sum("BASE", value.skillCfg, "AdditionalCooldownUses")
						globalOutput.InfernalCryUptimeRatio = m_min(100, baseUptimeRatio * storedUses)
						globalOutput.GlobalWarcryUptimeRatio = globalOutput.GlobalWarcryUptimeRatio + globalOutput.InfernalCryUptimeRatio
						if globalBreakdown then
							globalBreakdown.InfernalCryUptimeRatio = { }
							t_insert(globalBreakdown.InfernalCryUptimeRatio, localisation:Text("calc.offence.offence.line_85", { infernal_empowered_count = globalOutput.InfernalEmpoweredCount }))
							t_insert(globalBreakdown.InfernalCryUptimeRatio, localisation:Text("calc.offence.offence.line_81", { speed = globalOutput.Speed }))
							if globalOutput.InfernalCryCastTime > 0 then
								t_insert(globalBreakdown.InfernalCryUptimeRatio, localisation:Text("calc.offence.offence.line_86", { infernal_cry_cooldown = globalOutput.InfernalCryCooldown }))
								t_insert(globalBreakdown.InfernalCryUptimeRatio, localisation:Text("calc.offence.offence.line_87", { infernal_cry_cast_time = globalOutput.InfernalCryCastTime }))
							else
								t_insert(globalBreakdown.InfernalCryUptimeRatio, localisation:Text("calc.offence.offence.line_88", { infernal_cry_cooldown = globalOutput.InfernalCryCooldown }))
							end
							t_insert(globalBreakdown.InfernalCryUptimeRatio, s_format("= %d%%", globalOutput.InfernalCryUptimeRatio))
						end
						local infernalGainAsFire = modDB:Sum("BASE", nil, "InfernalExtraFireDamage")
						if infernalGainAsFire > 0 then
							local infernalUptime = activeSkill.skillModList:Flag(nil, "Condition:WarcryMaxHit") and 100 or globalOutput.InfernalCryUptimeRatio
							skillModList:NewMod("DamageGainAsFire", "BASE", infernalGainAsFire * infernalUptime / 100, "Uptime Scaled Infernal Cry", ModFlag.Melee)
						end
						globalOutput.InfernalCryCalculated = true
					elseif value.activeEffect.grantedEffect.name == "Intimidating Cry" and activeSkill.skillTypes[SkillType.Melee] and not globalOutput.IntimidatingCryCalculated then
						globalOutput.CreateWarcryOffensiveCalcSection = true
						globalOutput.IntimidatingCryDuration = calcSkillDuration(value.skillModList, value.skillCfg, value.skillData, env, enemyDB)
						globalOutput.IntimidatingCryCooldown = calcSkillCooldown(value.skillModList, value.skillCfg, value.skillData)
						globalOutput.IntimidatingCryCastTime = calcWarcryCastTime(value.skillModList, value.skillCfg, value.skillData, actor)
						globalOutput.IntimidatingExertsCount = env.modDB:Sum("BASE", nil, "NumIntimidatingExerts") or 0
						local baseUptimeRatio = m_min((globalOutput.IntimidatingExertsCount / globalOutput.Speed) / (globalOutput.IntimidatingCryCooldown + globalOutput.IntimidatingCryCastTime), 1) * 100
						local storedUses = value.skillData.storedUses or 0 + value.skillModList:Sum("BASE", value.skillCfg, "AdditionalCooldownUses")
						globalOutput.IntimidatingUpTimeRatio = m_min(100, baseUptimeRatio * storedUses)
						globalOutput.GlobalWarcryUptimeRatio = globalOutput.GlobalWarcryUptimeRatio + globalOutput.IntimidatingUpTimeRatio
						if globalBreakdown then
							globalBreakdown.IntimidatingUpTimeRatio = { }
							t_insert(globalBreakdown.IntimidatingUpTimeRatio, localisation:Text("calc.offence.offence.line_89", { intimidating_exerts_count = globalOutput.IntimidatingExertsCount }))
							t_insert(globalBreakdown.IntimidatingUpTimeRatio, localisation:Text("calc.offence.offence.line_81", { speed = globalOutput.Speed }))
							if 	globalOutput.IntimidatingCryCastTime > 0 then
								t_insert(globalBreakdown.IntimidatingUpTimeRatio, localisation:Text("calc.offence.offence.line_90", { intimidating_cry_cooldown = globalOutput.IntimidatingCryCooldown }))
								t_insert(globalBreakdown.IntimidatingUpTimeRatio, localisation:Text("calc.offence.offence.line_91", { intimidating_cry_cast_time = globalOutput.IntimidatingCryCastTime }))
							else
								t_insert(globalBreakdown.IntimidatingUpTimeRatio, localisation:Text("calc.offence.offence.line_92", { intimidating_cry_cooldown = globalOutput.IntimidatingCryCooldown }))
							end
							t_insert(globalBreakdown.IntimidatingUpTimeRatio, s_format("= %d%%", globalOutput.IntimidatingUpTimeRatio))
						end
						local ddChance = m_min(skillModList:Sum("BASE", cfg, "DoubleDamageChance") + (env.mode_effective and enemyDB:Sum("BASE", cfg, "SelfDoubleDamageChance") or 0) + exertedDoubleDamage, 100)
						globalOutput.IntimidatingAvgDmg = 2 * (1 - ddChance / 100) -- 1
						if globalBreakdown then
							globalBreakdown.IntimidatingAvgDmg = {
								localisation:Text("calc.offence.intimidating_avg_dmg.line_3"),
								localisation:Text("calc.offence.intimidating_avg_dmg.line", { value = (1 - ddChance / 100) * 100 }),
								localisation:Text("calc.offence.intimidating_avg_dmg.line_2", { value = 2 }),
								s_format("= %.2f", globalOutput.IntimidatingAvgDmg),
							}
						end
						globalOutput.IntimidatingHitEffect = 1 + globalOutput.IntimidatingAvgDmg * globalOutput.IntimidatingUpTimeRatio / 100
						globalOutput.IntimidatingMaxHitEffect = 1 + globalOutput.IntimidatingAvgDmg
						if globalBreakdown then
							globalBreakdown.IntimidatingHitEffect = {
								localisation:Text("calc.offence.intimidating_hit_effect.line", { intimidating_avg_dmg = globalOutput.IntimidatingAvgDmg }),
								localisation:Text("calc.offence.intimidating_hit_effect.line_2", { value = globalOutput.IntimidatingUpTimeRatio / 100 }),
								s_format("= %.2f", globalOutput.IntimidatingHitEffect),
							}
						end

						globalOutput.TheoreticalOffensiveWarcryEffect = globalOutput.TheoreticalOffensiveWarcryEffect * globalOutput.IntimidatingHitEffect
						globalOutput.TheoreticalMaxOffensiveWarcryEffect = globalOutput.TheoreticalMaxOffensiveWarcryEffect * globalOutput.IntimidatingMaxHitEffect
						globalOutput.IntimidatingCryCalculated = true
					elseif value.activeEffect.grantedEffect.name == "Rallying Cry" and activeSkill.skillTypes[SkillType.Melee] and not globalOutput.RallyingCryCalculated then
						globalOutput.CreateWarcryOffensiveCalcSection = true
						globalOutput.RallyingCryDuration = calcSkillDuration(value.skillModList, value.skillCfg, value.skillData, env, enemyDB)
						globalOutput.RallyingCryCooldown = calcSkillCooldown(value.skillModList, value.skillCfg, value.skillData)
						globalOutput.RallyingCryCastTime = calcWarcryCastTime(value.skillModList, value.skillCfg, value.skillData, actor)
						globalOutput.RallyingExertsCount = env.modDB:Sum("BASE", nil, "NumRallyingExerts") or 0
						local baseUptimeRatio = m_min((globalOutput.RallyingExertsCount / globalOutput.Speed) / (globalOutput.RallyingCryCooldown + globalOutput.RallyingCryCastTime), 1) * 100
						local storedUses = value.skillData.storedUses or 0 + value.skillModList:Sum("BASE", value.skillCfg, "AdditionalCooldownUses")
						globalOutput.RallyingUpTimeRatio = m_min(100, baseUptimeRatio * storedUses)
						globalOutput.GlobalWarcryUptimeRatio = globalOutput.GlobalWarcryUptimeRatio + globalOutput.RallyingUpTimeRatio
						if globalBreakdown then
							globalBreakdown.RallyingUpTimeRatio = { }
							t_insert(globalBreakdown.RallyingUpTimeRatio, localisation:Text("calc.offence.offence.line_93", { rallying_exerts_count = globalOutput.RallyingExertsCount }))
							t_insert(globalBreakdown.RallyingUpTimeRatio, localisation:Text("calc.offence.offence.line_81", { speed = globalOutput.Speed }))
							if 	globalOutput.RallyingCryCastTime > 0 then
								t_insert(globalBreakdown.RallyingUpTimeRatio, localisation:Text("calc.offence.offence.line_94", { rallying_cry_cooldown = globalOutput.RallyingCryCooldown }))
								t_insert(globalBreakdown.RallyingUpTimeRatio, localisation:Text("calc.offence.offence.line_95", { rallying_cry_cast_time = globalOutput.RallyingCryCastTime }))
							else
								t_insert(globalBreakdown.RallyingUpTimeRatio, localisation:Text("calc.offence.offence.line_96", { rallying_cry_cooldown = globalOutput.RallyingCryCooldown }))
							end
							t_insert(globalBreakdown.RallyingUpTimeRatio, s_format("= %d%%", globalOutput.RallyingUpTimeRatio))
						end
						globalOutput.RallyingAvgDmg = m_min(env.modDB:Sum("BASE", cfg, "Multiplier:NearbyAlly"), 5) * (env.modDB:Sum("BASE", nil, "RallyingExertMoreDamagePerAlly") / 100)
						if globalBreakdown then
							globalBreakdown.RallyingAvgDmg = {
								localisation:Text("calc.offence.rallying_avg_dmg.line_3"),
								localisation:Text("calc.offence.rallying_avg_dmg.line", { value = env.modDB:Sum("BASE", nil, "RallyingExertMoreDamagePerAlly") / 100 }),
								localisation:Text("calc.offence.rallying_avg_dmg.line_2", { value = m_min(env.modDB:Sum("BASE", cfg, "Multiplier:NearbyAlly"), 5) }),
								s_format("= %.2f", globalOutput.RallyingAvgDmg),
							}
						end
						globalOutput.RallyingHitEffect = 1 + globalOutput.RallyingAvgDmg * globalOutput.RallyingUpTimeRatio / 100
						globalOutput.RallyingMaxHitEffect = 1 + globalOutput.RallyingAvgDmg
						if globalBreakdown then
							globalBreakdown.RallyingHitEffect = {
								localisation:Text("calc.offence.rallying_hit_effect.line", { rallying_avg_dmg = globalOutput.RallyingAvgDmg }),
								localisation:Text("calc.offence.rallying_hit_effect.line_2", { value = globalOutput.RallyingUpTimeRatio / 100 }),
								s_format("= %.2f", globalOutput.RallyingHitEffect),
							}
						end
						globalOutput.OffensiveWarcryEffect = globalOutput.OffensiveWarcryEffect * globalOutput.RallyingHitEffect
						globalOutput.MaxOffensiveWarcryEffect = globalOutput.MaxOffensiveWarcryEffect * globalOutput.RallyingMaxHitEffect
						globalOutput.TheoreticalOffensiveWarcryEffect = globalOutput.TheoreticalOffensiveWarcryEffect * globalOutput.RallyingHitEffect
						globalOutput.TheoreticalMaxOffensiveWarcryEffect = globalOutput.TheoreticalMaxOffensiveWarcryEffect * globalOutput.RallyingMaxHitEffect
						globalOutput.RallyingCryCalculated = true

					elseif value.activeEffect.grantedEffect.name == "Seismic Cry" and activeSkill.skillTypes[SkillType.Slam] and not globalOutput.SeismicCryCalculated then
						globalOutput.CreateWarcryOffensiveCalcSection = true
						globalOutput.SeismicCryDuration = calcSkillDuration(value.skillModList, value.skillCfg, value.skillData, env, enemyDB)
						globalOutput.SeismicCryCooldown = calcSkillCooldown(value.skillModList, value.skillCfg, value.skillData)
						globalOutput.SeismicCryCastTime = calcWarcryCastTime(value.skillModList, value.skillCfg, value.skillData, actor)
						globalOutput.SeismicExertsCount = env.modDB:Sum("BASE", nil, "NumSeismicExerts") or 0
						local baseUptimeRatio = m_min((globalOutput.SeismicExertsCount / globalOutput.Speed) / (globalOutput.SeismicCryCooldown + globalOutput.SeismicCryCastTime), 1) * 100
						local storedUses = value.skillData.storedUses or 0 + value.skillModList:Sum("BASE", value.skillCfg, "AdditionalCooldownUses")
						globalOutput.SeismicUpTimeRatio = m_min(100, baseUptimeRatio * storedUses)
						globalOutput.GlobalWarcryUptimeRatio = globalOutput.GlobalWarcryUptimeRatio + globalOutput.SeismicUpTimeRatio
						-- account for AoE increase
						if activeSkill.skillModList:Flag(nil, "Condition:WarcryMaxHit") then
							skillModList:NewMod("AreaOfEffect", "MORE", env.modDB:Sum("BASE", nil, "SeismicMoreAoE"), "Max Seismic Exert AoE")
						else
							skillModList:NewMod("AreaOfEffect", "MORE", m_floor(env.modDB:Sum("BASE", nil, "SeismicMoreAoE") / 100 * globalOutput.SeismicUpTimeRatio), "Avg Seismic Exert AoE")
						end
						calcAreaOfEffect(skillModList, skillCfg, skillData, skillFlags, globalOutput, globalBreakdown)
						if globalBreakdown then
							globalBreakdown.SeismicUpTimeRatio = { }
							t_insert(globalBreakdown.SeismicUpTimeRatio, localisation:Text("calc.offence.offence.line_97", { seismic_exerts_count = globalOutput.SeismicExertsCount }))
							t_insert(globalBreakdown.SeismicUpTimeRatio, localisation:Text("calc.offence.offence.line_81", { speed = globalOutput.Speed }))
							if 	globalOutput.SeismicCryCastTime > 0 then
								t_insert(globalBreakdown.SeismicUpTimeRatio, localisation:Text("calc.offence.offence.line_98", { seismic_cry_cooldown = globalOutput.SeismicCryCooldown }))
								t_insert(globalBreakdown.SeismicUpTimeRatio, localisation:Text("calc.offence.offence.line_99", { seismic_cry_cast_time = globalOutput.SeismicCryCastTime }))
							else
								t_insert(globalBreakdown.SeismicUpTimeRatio, localisation:Text("calc.offence.offence.line_100", { seismic_cry_cooldown = globalOutput.SeismicCryCooldown }))
							end
							t_insert(globalBreakdown.SeismicUpTimeRatio, s_format("= %d%%", globalOutput.SeismicUpTimeRatio))
						end
						globalOutput.SeismicCryCalculated = true
					elseif value.activeEffect.grantedEffect.name == "Battlemage's Cry" and not globalOutput.BattleMageCryCalculated then
						globalOutput.BattleMageCryDuration = calcSkillDuration(value.skillModList, value.skillCfg, value.skillData, env, enemyDB)
						globalOutput.BattleMageCryCooldown = calcSkillCooldown(value.skillModList, value.skillCfg, value.skillData)
						globalOutput.BattleMageCryCastTime = calcWarcryCastTime(value.skillModList, value.skillCfg, value.skillData, actor)
						if activeSkill.skillTypes[SkillType.Melee] then
							globalOutput.BattleCryExertsCount = env.modDB:Sum("BASE", nil, "NumBattlemageExerts") or 0
							local baseUptimeRatio = m_min((globalOutput.BattleCryExertsCount / globalOutput.Speed) / (globalOutput.BattleMageCryCooldown + globalOutput.BattleMageCryCastTime), 1) * 100
							local storedUses = value.skillData.storedUses or 0 + value.skillModList:Sum("BASE", value.skillCfg, "AdditionalCooldownUses")
							globalOutput.BattlemageUpTimeRatio = m_min(100, baseUptimeRatio * storedUses)
							globalOutput.GlobalWarcryUptimeRatio = globalOutput.GlobalWarcryUptimeRatio + globalOutput.BattlemageUpTimeRatio
							if globalBreakdown then
								globalBreakdown.BattlemageUpTimeRatio = { }
								t_insert(globalBreakdown.BattlemageUpTimeRatio, localisation:Text("calc.offence.offence.line_101", { battle_cry_exerts_count = globalOutput.BattleCryExertsCount }))
								t_insert(globalBreakdown.BattlemageUpTimeRatio, localisation:Text("calc.offence.offence.line_81", { speed = globalOutput.Speed }))
								if globalOutput.BattleMageCryCastTime > 0 then
									t_insert(globalBreakdown.BattlemageUpTimeRatio, localisation:Text("calc.offence.offence.line_102", { battle_mage_cry_cooldown = globalOutput.BattleMageCryCooldown }))
									t_insert(globalBreakdown.BattlemageUpTimeRatio, localisation:Text("calc.offence.offence.line_103", { battle_mage_cry_cast_time = globalOutput.BattleMageCryCastTime }))
								else
									t_insert(globalBreakdown.BattlemageUpTimeRatio, localisation:Text("calc.offence.offence.line_104", { battle_mage_cry_cooldown = globalOutput.BattleMageCryCooldown }))
								end
								t_insert(globalBreakdown.BattlemageUpTimeRatio, s_format("= %d%%", globalOutput.BattlemageUpTimeRatio))
							end
						end
						globalOutput.BattleMageCryCalculated = true
					end
				end

				if activeSkill.skillModList:Flag(nil, "Condition:WarcryMaxHit") then
					globalOutput.AilmentWarcryEffect = globalOutput.MaxOffensiveWarcryEffect
					skillData.showAverage = true
					skillFlags.showAverage = true
					skillFlags.notAverage = false
				else
					globalOutput.AilmentWarcryEffect = globalOutput.OffensiveWarcryEffect
				end
			end
		end

		output.FistOfWarDamageEffect = 1
		output.AncestralCallDamageEffect = 1
		output.AncestralEmpowermentDamageEffect = 1
		output.AncestralEmpowermentCombinedDamageEffect = 1
		if env.mode_combat then
			local ruthlessEffect = env.configInput.ruthlessSupportMode or "AVERAGE"
			local ruthlessBlowMaxCount = skillModList:Sum("BASE", cfg, "RuthlessBlowMaxCount")
			local ruthlessBlowChance
			if ruthlessBlowMaxCount > 0 and ( not skillCfg.skillCond["usedByMirage"] or (skillData.mirageUses or 0) > ruthlessBlowMaxCount ) then
				if ruthlessEffect == "AVERAGE" then
					ruthlessBlowChance = round(100 / ruthlessBlowMaxCount)
				elseif ruthlessEffect == "MAX" then
					ruthlessBlowChance = 100
					skillModList:NewMod("DPS", "MORE", -100 + 100 / (ruthlessBlowMaxCount or 1), "Only Ruthless Blows")
				end
			else
				ruthlessBlowChance = 0
			end
			local ruthlessBlowStunMultiplier = skillModList:Sum("BASE", cfg, "RuthlessBlowStunMultiplier") / 100
			local ruthlessBlowStunEffect = (ruthlessBlowChance / 100) * ruthlessBlowStunMultiplier
			skillModList:NewMod("EnemyHeavyStunBuildup", "MORE", ruthlessBlowStunEffect * 100, "Ruthless Blows")

			-- Condition:AncestrallyBoosted * AncestralBoostEffect (e.g. Fist of War III)
			local ancestrallyBoostedMoreDamageMulti = skillModList:Sum("BASE", cfg, "AncestralBoostMoreDamage") / 100

			globalOutput.FistOfWarCooldown = skillModList:Sum("BASE", cfg, "FistOfWarCooldown") or 0
			if skillModList:Flag(cfg, "AncestralEmpowerment") and activeSkill.skillTypes[SkillType.Slam] and not activeSkill.skillTypes[SkillType.Vaal] and not activeSkill.skillTypes[SkillType.OtherThingUsesSkill] then
				if globalOutput.FistOfWarCooldown ~= 0 then -- get the fist of war calcs in output to use in Empowerment
					calcAncestralBoost("Fist Of War", ancestrallyBoostedMoreDamageMulti, nil, true)
					globalOutput.TheoreticalOffensiveWarcryEffect = 1 -- reset effects from FistOfWar calc, we combine later
					globalOutput.TheoreticalMaxOffensiveWarcryEffect = 1

					calcCombinedAncestralBoost("Ancestral Empowerment", ancestrallyBoostedMoreDamageMulti, 50, "Fist Of War")
					globalOutput.FistOfWarUptimeRatio = nil -- hide from CalcSections, but we need it for the combined calc first
				else
					calcAncestralBoost("Ancestral Empowerment", ancestrallyBoostedMoreDamageMulti, 50)
				end
			end
			-- If Fist of War & Active Skill is a Slam Skill & NOT a Vaal Skill & NOT used by mirage or other
			if not skillModList:Flag(cfg, "AncestralEmpowerment") and globalOutput.FistOfWarCooldown ~= 0 and activeSkill.skillTypes[SkillType.Slam] and not activeSkill.skillTypes[SkillType.Vaal] and not activeSkill.skillTypes[SkillType.OtherThingUsesSkill] then
				calcAncestralBoost("Fist Of War", ancestrallyBoostedMoreDamageMulti)
			else
				output.FistOfWarDamageEffect = 1
			end

			globalOutput.AncestralCallCooldown = skillModList:Sum("BASE", cfg, "AncestralCallCooldown") or 0
			-- If Ancestral Call & Active Skill is NOT a Vaal Skill & NOT used by mirage or other & NOT a Channel Skill
			if globalOutput.AncestralCallCooldown ~= 0 and not activeSkill.skillTypes[SkillType.Vaal] and not activeSkill.skillTypes[SkillType.OtherThingUsesSkill] and not activeSkill.skillTypes[SkillType.Channel] then
				calcAncestralBoost("Ancestral Call", ancestrallyBoostedMoreDamageMulti)
			else
				output.AncestralCallDamageEffect = 1
			end
		end

		-- Calculate Empowered Attack Uptime
		-- Ancestrally Boosted attacks are also Empowered, so we need to check for the highest uptime among both lists
		-- we can use these ratio flags to max the uptime for attacks/skills that guarantee Ancestrally Boosted or Empowered in specific cases like Crescendo III
		local maxEmpoweredUptimeRatio = (skillModList:Flag(cfg, "MaxBoostedUptimeRatio") or skillModList:Flag(cfg, "MaxEmpoweredUptimeRatio")) and 100
		local warcryList = { "InfernalCryUptimeRatio" }
		local ancestralBoostList = { "AncestralEmpowermentCombinedUptimeRatio", "AncestralEmpowermentUptimeRatio", "FistOfWarUptimeRatio", "AncestralCallUptimeRatio" }
		local combinedList = {}
		for _, ratio in ipairs(warcryList) do
			t_insert(combinedList, ratio)
		end
		for _, ratio in ipairs(ancestralBoostList) do
			t_insert(combinedList, ratio)
		end

		for _, cryTimeRatio in ipairs(combinedList) do
			globalOutput.ExertedAttackUptimeRatio = maxEmpoweredUptimeRatio or m_max(globalOutput.ExertedAttackUptimeRatio or 0, globalOutput[cryTimeRatio] or 0)
		end
		if globalBreakdown then
			globalBreakdown.ExertedAttackUptimeRatio = { }
			t_insert(globalBreakdown.ExertedAttackUptimeRatio, localisation:Text("calc.offence.offence.line_105"))
			for _, cryTimeRatio in ipairs(combinedList) do
				if globalOutput[cryTimeRatio] then
					t_insert(globalBreakdown.ExertedAttackUptimeRatio, localisation:Text("calc.offence.offence.line_106", { value = ((maxEmpoweredUptimeRatio or globalOutput[cryTimeRatio]) or 0), value_2 = (((maxEmpoweredUptimeRatio and localisation:Ref("calc.offence.offence.line.parameter")) or cryTimeRatio:match("(.+)Up.*")) or localisation:Ref("calc.offence.offence.line.parameter")) }))
				end
			end
			t_insert(globalBreakdown.ExertedAttackUptimeRatio, s_format("= %d%%", globalOutput.ExertedAttackUptimeRatio))
		end
		if globalOutput.ExertedAttackUptimeRatio > 0 and not globalOutput.ExertedAttackUptimeRatioCalculated then
			local incExertedAttacks = skillModList:Sum("INC", cfg, "EmpoweredIncrease")
			if activeSkill.skillModList:Flag(nil, "Condition:WarcryMaxHit") then
				skillModList:NewMod("Damage", "INC", incExertedAttacks, "Empowered Attacks", ModFlag.Attack)
			else
				skillModList:NewMod("Damage", "INC", incExertedAttacks * globalOutput.ExertedAttackUptimeRatio / 100, "Uptime Scaled Empowered Attacks", ModFlag.Attack)
			end
			globalOutput.ExertedAttackAvgDmg = calcLib.mod(skillModList, skillCfg, "EmpoweredIncrease")
			globalOutput.ExertedAttackHitEffect = globalOutput.ExertedAttackAvgDmg * globalOutput.ExertedAttackUptimeRatio / 100
			globalOutput.ExertedAttackMaxHitEffect = globalOutput.ExertedAttackAvgDmg
			if globalBreakdown then
				globalBreakdown.ExertedAttackHitEffect = {
					localisation:Text("calc.offence.exerted_attack_hit_effect.line", { exerted_attack_avg_dmg = globalOutput.ExertedAttackAvgDmg }),
					localisation:Text("calc.offence.exerted_attack_hit_effect.line_2", { value = globalOutput.ExertedAttackUptimeRatio / 100 }),
					s_format("= %.2f", globalOutput.ExertedAttackHitEffect),
				}
			end
			globalOutput.ExertedAttackUptimeRatioCalculated = true
		end

		local maxBoostedUptimeRatio = skillModList:Flag(cfg, "MaxBoostedUptimeRatio") and 100
		-- Calculate Ancestrally Boosted Attack Uptime
		for _, boostUptimeRatio in ipairs(ancestralBoostList) do
			globalOutput.BoostedAttackUptimeRatio = maxBoostedUptimeRatio or m_max(globalOutput.BoostedAttackUptimeRatio or 0, globalOutput[boostUptimeRatio] or 0)
		end
		if globalBreakdown then
			globalBreakdown.BoostedAttackUptimeRatio = { }
			t_insert(globalBreakdown.BoostedAttackUptimeRatio, localisation:Text("calc.offence.offence.line_105"))
			for _, boostUptimeRatio in ipairs(ancestralBoostList) do
				if globalOutput[boostUptimeRatio] then
					t_insert(globalBreakdown.BoostedAttackUptimeRatio, localisation:Text("calc.offence.offence.line_107", { value = ((maxBoostedUptimeRatio or globalOutput[boostUptimeRatio]) or 0), value_2 = ((maxBoostedUptimeRatio and localisation:Ref("calc.offence.offence.line.parameter")) or boostUptimeRatio:match("(.+)Up.*")) }))
				end
			end
			t_insert(globalBreakdown.BoostedAttackUptimeRatio, s_format("= %d%%", globalOutput.BoostedAttackUptimeRatio))
		end
		if globalOutput.BoostedAttackUptimeRatio > 0 and not globalOutput.BoostedAttackUptimeRatioCalculated then
			local incBoostedAttacks = skillModList:Sum("INC", cfg, "AncestralBoostDamage")
			local incAoEBoostedAttacks = skillModList:Sum("INC", cfg, "AncestralBoostAreaOfEffect")
			if activeSkill.skillModList:Flag(nil, "Condition:WarcryMaxHit") then
				skillModList:NewMod("Damage", "INC", incBoostedAttacks, "Ancestrally Boosted Attacks", ModFlag.Attack)
				skillModList:NewMod("AreaOfEffect", "INC", incAoEBoostedAttacks, "Ancestrally Boosted Attacks")
			else
				skillModList:NewMod("Damage", "INC", incBoostedAttacks * globalOutput.BoostedAttackUptimeRatio / 100, "Uptime Scaled Ancestrally Boosted Attacks", ModFlag.Attack)
				skillModList:NewMod("AreaOfEffect", "INC", incAoEBoostedAttacks * globalOutput.BoostedAttackUptimeRatio / 100, "Uptime Scaled Ancestrally Boosted AoE")
			end
			calcAreaOfEffect(skillModList, skillCfg, skillData, skillFlags, globalOutput, globalBreakdown)

			globalOutput.BoostedAttackAvgDmg = calcLib.mod(skillModList, skillCfg, "AncestralBoostDamage")
			globalOutput.BoostedAttackHitEffect = globalOutput.BoostedAttackAvgDmg * globalOutput.BoostedAttackUptimeRatio / 100
			globalOutput.BoostedAttackMaxHitEffect = globalOutput.BoostedAttackAvgDmg
			if globalBreakdown then
				globalBreakdown.BoostedAttackHitEffect = {
					localisation:Text("calc.offence.boosted_attack_hit_effect.line", { boosted_attack_avg_dmg = globalOutput.BoostedAttackAvgDmg }),
					localisation:Text("calc.offence.boosted_attack_hit_effect.line_2", { value = globalOutput.BoostedAttackUptimeRatio / 100 }),
					s_format("= %.2f", globalOutput.BoostedAttackHitEffect),
				}
			end
			globalOutput.BoostedAttackUptimeRatioCalculated = true
		end

		-- Calculate maximum sustainable fuses and explosion rate for Explosive Arrow
		-- Does not take into account mines or traps
		if activeSkill.activeEffect.grantedEffect.name == "Explosive Arrow" then
			activeSkill.activeEffect.grantedEffect.explosiveArrowFunc(activeSkill, output, globalOutput, globalBreakdown, env)
		end

		-- Calculate crit chance, crit multiplier, and their combined effect
		local inevitableCrits = false
		if skillModList:Flag(cfg, "NeverCrit") then
			output.PreEffectiveCritChance = 0
			output.CritChance = 0
			output.CritMultiplier = 0
			output.BonusCritDotMultiplier = 0
			output.CritEffect = 1
		elseif skillModList:Flag(cfg, "SpellSkillsCannotDealCriticalStrikesExceptOnFinalRepeat") then
			if (output.Repeats or 1) == 1 then
				output.PreEffectiveCritChance = 0
				output.CritChance = 0
				output.CritMultiplier = 0
				output.BonusCritDotMultiplier = 0
				output.CritEffect = 1
			elseif skillModList:Flag(cfg, "SpellSkillsAlwaysDealCriticalStrikesOnFinalRepeat") then
				if env.configInput.repeatMode == "None" then
					output.PreEffectiveCritChance = 0
					output.CritChance = 0
				elseif env.configInput.repeatMode == "AVERAGE" then
					output.PreEffectiveCritChance = 100 / output.Repeats
					output.CritChance = 100 / output.Repeats
					if breakdown then
						breakdown.CritChance = {
							s_format("100%%"),
							localisation:Text("calc.offence.crit_chance.line", { repeats = output.Repeats }),
							localisation:Text("calc.offence.crit_chance.line_2", { crit_chance = output.CritChance })
						}
					end
				else
					output.PreEffectiveCritChance = 100
					output.CritChance = 100
				end
			--else -- this shouldn't ever be a case but leaving this here if someone wants to implement it
			end
		else
			local critOverride = skillModList:Override(cfg, "CritChance")
			-- destructive link
			if skillModList:Flag(cfg, "MainHandCritIsEqualToParent") then
				critOverride = actor.parent.output.MainHand and actor.parent.output.MainHand.CritChance or actor.parent.weaponData1.CritChance
			elseif skillModList:Flag(cfg, "MainHandCritIsEqualToPartyMember") then
				critOverride = actor.partyMembers.output.MainHand and actor.partyMembers.output.MainHand.CritChance or (actor.partyMembers.weaponData1 and actor.partyMembers.weaponData1.CritChance or 0)
			end
			local baseCrit = critOverride or source.CritChance or 0

			local baseCritFromMainHand = skillModList:Flag(cfg, "BaseCritFromMainHand")
			local baseCritFromParentMainHand = skillModList:Flag(cfg, "AttackCritIsEqualToParentMainHand")
			local baseCritOverride = skillModList:Override(cfg, "CritChanceBase")
			if baseCritOverride then
				baseCrit = baseCritOverride
			elseif baseCritFromMainHand then
				baseCrit = actor.weaponData1.CritChance
			elseif baseCritFromParentMainHand then
				baseCrit = actor.parent.weaponData1 and actor.parent.weaponData1.CritChance or baseCrit
			end

			if critOverride == 100 then
				output.PreEffectiveCritChance = 100
				output.PreBifurcateCritChance = 100
				output.CritChance = 100
			else
				local base = 0
				local inc = 0
				local more = 1
				if not critOverride then
					base = skillModList:Sum("BASE", cfg, "CritChance") + (env.mode_effective and enemyDB:Sum("BASE", nil, "SelfCritChance") or 0)
					inc = skillModList:Sum("INC", cfg, "CritChance") + (env.mode_effective and enemyDB:Sum("INC", nil, "SelfCritChance") or 0)
					more = skillModList:More(cfg, "CritChance")
				end
				-- The game uses an integer permyriad chance for each critical strike roll.
				output.CritChance = round((baseCrit + base) * (1 + inc / 100) * more * 100) / 100
				local preCapCritChance = output.CritChance
				output.CritChance = m_min(output.CritChance, skillModList:Override(nil, "CritChanceCap") or skillModList:Sum("BASE", cfg, "CritChanceCap"))
				if (baseCrit + base) > 0 then
					output.CritChance = m_max(output.CritChance, 0)
				end
				output.PreEffectiveCritChance = output.CritChance
				local preHitCheckCritChance = output.CritChance
				if env.mode_effective then
					-- Hits that make an accuracy check make a second accuracy check if they roll a crit. If that fails, the crit is nullified and it just stays a normal hit
					-- https://www.pathofexile.com/forum/view-thread/11707/filter-account-type/staff/page/10#p748465
					output.CritChance = output.CritChance * output.AccuracyHitChance / 100
				end
				local preLuckyCritChance = output.CritChance
				if env.mode_effective and skillModList:Flag(cfg, "CritChanceLucky") then
					output.CritChance = (1 - (1 - output.CritChance / 100) ^ 2) * 100
				end
				output.PreBifurcateCritChance = output.CritChance
				local preBifurcateCritChance = output.CritChance
				if env.mode_effective and skillModList:Flag(cfg, "BifurcateCrit") then
					output.CritChance = (1 - (1 - output.CritChance / 100) ^ 2) * 100
				end
				local preInevitableCritChance = output.CritChance
				if env.mode_effective and skillModList:Flag(cfg, "InevitableCriticalHits") and output.CritChance > 0 then
					inevitableCrits = true
					-- Lucky crits use their effective crit chance without an extra roll-down penalty.
					-- Bifurcated crits roll twice per roll-down; only both rolls failing advances the penalty.
					local critChance = output.CritChance / 100
					local nonCritChance = 1 - critChance

					local critBonusMultiplier =
						1 * critChance + 								  -- 100% crit damage, crit% of the time
						0.7 * nonCritChance * critChance +				  -- 70% if we roll non-crit then a crit
						0.4 * m_pow(nonCritChance, 2) * critChance + -- 40% if we roll two non-crit then a crit
						0.1 * m_pow(nonCritChance, 3) * critChance   -- 10% if we roll three non-crits then a crit
					if skillModList:Flag(cfg, "BifurcateCrit") then
						-- The terminating stage can crit twice, so scale its one-or-more-crit bonus
						-- by the expected number of crits on that stage.
						critBonusMultiplier = critBonusMultiplier * 2 * output.PreBifurcateCritChance / output.CritChance
						output.CritBifurcates = output.PreBifurcateCritChance ^ 2 / output.CritChance
					end

					-- This gets rounded when used in damage logic, so round it ahead of time to make the breakdown accurate (and less ugly)
					local lessCritBonus = round((1 - critBonusMultiplier) * -100.0, 0)
					skillModList:NewMod("CritMultiplier", "MORE", lessCritBonus, "Tree:55135")

					-- For the sake of any logic that depends on it, every hit is considered a crit
					output.CritChance = 100
				end
				if breakdown and output.CritChance ~= baseCrit then
					breakdown.CritChance = { }
					local baseCritFromMainHandStr = baseCritFromMainHand and " from main weapon" or baseCritFromParentMainHand and " from parent main weapon" or ""
					if base ~= 0 then
						t_insert(breakdown.CritChance, localisation:Text("calc.offence.offence.line_108", { base_crit = baseCrit, base = base, base_crit_from_main_hand_str = baseCritFromMainHandStr }))
					else
						t_insert(breakdown.CritChance, localisation:Text("calc.offence.offence.line_109", { value = baseCrit + base, base_crit_from_main_hand_str = baseCritFromMainHandStr }))
					end
					if inc ~= 0 then
						t_insert(breakdown.CritChance, localisation:Text("calc.offence.offence.line_110", { value = 1 + inc/100 }))
					end
					if more ~= 1 then
						t_insert(breakdown.CritChance, localisation:Text("calc.offence.offence.line_3", { more = more }))
					end
					t_insert(breakdown.CritChance, localisation:Text("calc.offence.offence.line_111", { pre_effective_crit_chance = output.PreEffectiveCritChance }))
					if preCapCritChance > 100 then
						local overCap = preCapCritChance - 100
						t_insert(breakdown.CritChance, localisation:Text("calc.offence.offence.line_112", { over_cap = overCap, value = overCap / more / (baseCrit + base) * 100 }))
					end
					breakdown.PreEffectiveCritChance = copyTable(breakdown.CritChance)
					if env.mode_effective and output.AccuracyHitChance < 100 then
						t_insert(breakdown.CritChance, "")
						t_insert(breakdown.CritChance, localisation:Text("calc.offence.offence.line_113"))
						t_insert(breakdown.CritChance, s_format("%.2f%%", preHitCheckCritChance))
						t_insert(breakdown.CritChance, localisation:Text("calc.offence.offence.line_114", { value = output.AccuracyHitChance / 100 }))
						t_insert(breakdown.CritChance, s_format("= %.2f%%", preLuckyCritChance))
					end
					if env.mode_effective and skillModList:Flag(cfg, "CritChanceLucky") then
						t_insert(breakdown.CritChance, localisation:Text("calc.offence.offence.line_115"))
						t_insert(breakdown.CritChance, s_format("1 - (1 - %.4f) x (1 - %.4f)", preLuckyCritChance / 100, preLuckyCritChance / 100))
						t_insert(breakdown.CritChance, s_format("= %.2f%%", preBifurcateCritChance))
					end
					if env.mode_effective and skillModList:Flag(cfg, "BifurcateCrit") then
						t_insert(breakdown.CritChance, localisation:Text("calc.offence.offence.line_116"))
						t_insert(breakdown.CritChance, s_format("1 - (1 - %.4f) x (1 - %.4f)", preBifurcateCritChance / 100, preBifurcateCritChance / 100))
						t_insert(breakdown.CritChance, s_format("= %.2f%%", preInevitableCritChance))
					end
					if inevitableCrits then
						t_insert(breakdown.CritChance, localisation:Text("calc.offence.offence.line_117"))
						t_insert(breakdown.CritChance, localisation:Text("calc.offence.offence.line_118"))
					end
				end
			end
		end
		if not output.CritEffect then
			if skillModList:Flag(cfg, "NoCritMultiplier") then
				output.CritMultiplier = 1
			else
				local extraDamage = skillModList:Sum("BASE", cfg, "CritMultiplier") / 100
				local extraDamageInc = 1 + skillModList:Sum("INC", cfg, "CritMultiplier") / 100
				local extraDamageMore = skillModList:More("MORE", cfg, "CritMultiplier")
				extraDamage = extraDamage * extraDamageInc * extraDamageMore
				local multiOverride = skillModList:Override(skillCfg, "CritMultiplier")
				if multiOverride then
					extraDamage = multiOverride / 100
				end

				output.PreEffectiveCritMultiplier = 1 + extraDamage
				-- if crit bifurcates are enabled, roll for crit twice and add multiplier for each
				if env.mode_effective and skillModList:Flag(cfg, "BifurcateCrit") and not inevitableCrits then
					-- get crit chance and calculate odds of critting twice
					local critChancePercentage = output.PreBifurcateCritChance
					local bifurcateMultiChance = (critChancePercentage ^ 2) / 100
					local effectiveCritChance = output.CritChance
					local conditionalBifurcateChance = effectiveCritChance > 0 and bifurcateMultiChance / effectiveCritChance or 0
					output.CritBifurcates = 1 + conditionalBifurcateChance
					local damageBonus = extraDamage
					local bifurcatedBonus = conditionalBifurcateChance * extraDamage
					if breakdown then
						breakdown.CritBifurcates = {
							localisation:Text("calc.offence.crit_bifurcates.line", { crit_chance_percentage = critChancePercentage }),
							s_format("x %.2f%%", critChancePercentage),
							localisation:Text("calc.offence.crit_bifurcates.line_2", { bifurcate_multi_chance = bifurcateMultiChance }),
							localisation:Text("calc.offence.crit_bifurcates.line_3", { effective_crit_chance = effectiveCritChance }),
							localisation:Text("calc.offence.crit_bifurcates.line_4", { value = 1 + conditionalBifurcateChance }),
						}
					end
					extraDamage = damageBonus + bifurcatedBonus
					skillModList:NewMod("CritMultiplier", "MORE", floor(conditionalBifurcateChance * 100, 2), "Bifurcated Crit Damage Bonus")
				end

				if env.mode_effective then
					local enemyInc = 1 + enemyDB:Sum("INC", nil, "SelfCritMultiplier") / 100
					extraDamage = extraDamage + enemyDB:Sum("BASE", nil, "SelfCritMultiplier") / 100
					extraDamage = round(extraDamage * enemyInc, 2)
					if breakdown and enemyInc ~= 1 then
						breakdown.CritMultiplier = {
							localisation:Text("calc.offence.crit_multiplier.line", { value = (enemyDB:Sum("BASE", nil, "SelfCritMultiplier") + skillModList:Sum("BASE", cfg, "CritMultiplier")) / 100 }),
							localisation:Text("calc.offence.crit_multiplier.line_2", { enemy_inc = enemyInc }),
							localisation:Text("calc.offence.crit_multiplier.line_3", { value = extraDamage * 100 }),
						}
					end
				end
				output.CritMultiplier = 1 + m_max(0, extraDamage)
			end
			local critChancePercentage = output.CritChance / 100
			output.CritEffect = 1 - critChancePercentage + critChancePercentage * output.CritMultiplier
			output.BonusCritDotMultiplier = (skillModList:Sum("BASE", cfg, "CritMultiplier") - 50) * skillModList:Sum("BASE", cfg, "CritMultiplierAppliesToDegen") / 10000
			if breakdown and output.CritEffect ~= 1 then
				breakdown.CritEffect = {
					localisation:Text("calc.offence.crit_effect.line", { crit_chance_percentage = critChancePercentage }),
					localisation:Text("calc.offence.crit_effect.line_2", { crit_chance_percentage = critChancePercentage, crit_multiplier = output.CritMultiplier }),
					s_format("= %.3f", output.CritEffect),
				}
			end
		end

		output.ScaledDamageEffect = 1

		-- Calculate chance and multiplier for dealing triple damage on Normal and Crit
		output.TripleDamageChanceOnCrit = m_min(skillModList:Sum("BASE", cfg, "TripleDamageChanceOnCrit"), 100)
		output.TripleDamageChance = m_min(skillModList:Sum("BASE", cfg, "TripleDamageChance") or 0 + (env.mode_effective and enemyDB:Sum("BASE", cfg, "SelfTripleDamageChance") or 0) + (output.TripleDamageChanceOnCrit * output.CritChance / 100), 100)
		output.TripleDamageEffect = 2 * output.TripleDamageChance / 100

		-- Calculate chance and multiplier for dealing double damage on Normal and Crit
		output.DoubleDamageChanceOnCrit = m_min(skillModList:Sum("BASE", cfg, "DoubleDamageChanceOnCrit"), 100)
		output.DoubleDamageChance = m_min(skillModList:Sum("BASE", cfg, "DoubleDamageChance") + (env.mode_effective and enemyDB:Sum("BASE", cfg, "SelfDoubleDamageChance") or 0) + (output.DoubleDamageChanceOnCrit * output.CritChance / 100), 100)
		if globalOutput.IntimidatingUpTimeRatio and activeSkill.skillModList:Flag(nil, "Condition:WarcryMaxHit") then
			output.DoubleDamageChance = 100
		elseif globalOutput.IntimidatingUpTimeRatio then
			output.DoubleDamageChance = m_min(output.DoubleDamageChance + globalOutput.IntimidatingUpTimeRatio, 100)
		end
		-- Triple Damage overrides Double Damage. If you have both, it's the same as just having Triple
		-- We need to subtract the probability of both happening in favor of Triple Damage
		if output.TripleDamageChance > 0 then
			output.DoubleDamageChance = m_max(output.DoubleDamageChance - output.TripleDamageChance * output.DoubleDamageChance / 100, 0)
		end
		output.DoubleDamageEffect = output.DoubleDamageChance / 100
		output.ScaledDamageEffect = output.ScaledDamageEffect * (1 + output.DoubleDamageEffect + output.TripleDamageEffect)

		output.DpsMultiplier = ( skillData.dpsMultiplier or 1 ) * calcLib.mod(skillModList, skillCfg, "DPS")

		local hitRate = output.HitChance / 100 * (globalOutput.HitSpeed or globalOutput.Speed) * output.DpsMultiplier

		local enemyRarity = (enemyDB:Flag(nil, "Condition:Unique") and "Unique" or (enemyDB:Flag(nil, "Condition:RareOrUnique") and "Rare" or "Normal"))
		-- Calculate culling DPS
		local criticalCull = skillModList:Override(cfg, "CriticalCullPercent") or (skillModList:Flag(cfg, "CritCanCull") and data.gameConstants["CullingStrike"..enemyRarity.."Threshold"] or 0)
		if criticalCull > 0 then
			criticalCull = m_min(criticalCull, criticalCull * (1 - (1 - output.CritChance / 100) ^ hitRate))
		end
		local regularCull = skillModList:Override(cfg, "CullPercent") or (skillModList:Flag(cfg, "CanCull") and data.gameConstants["CullingStrike"..enemyRarity.."Threshold"] or 0)
		local incCullPercent = 1 + skillModList:Sum("INC", cfg, "CullPercent") / 100
		local maxCullPercent = m_max(criticalCull, regularCull) * incCullPercent
		globalOutput.CullPercent = maxCullPercent
		globalOutput.CullMultiplier = 100 / (100 - globalOutput.CullPercent)

		if globalBreakdown and maxCullPercent > 0 then
			globalBreakdown.CullingStrike = { }
			if (skillModList:Override(cfg, "CullPercent") or 0) > 0 then
				t_insert(globalBreakdown.CullingStrike, localisation:Text("calc.offence.offence.line_119", { regular_cull = regularCull }))
			else
				t_insert(globalBreakdown.CullingStrike, localisation:Text("calc.offence.offence.line_120", { regular_cull = regularCull, value = enemyRarity:lower() }))
			end
			if criticalCull > 0 then
				if (skillModList:Override(cfg, "CriticalCullPercent") or 0) > 0 then
					t_insert(globalBreakdown.CullingStrike, localisation:Text("calc.offence.offence.line_121", { critical_cull = criticalCull }))
				else
					t_insert(globalBreakdown.CullingStrike, localisation:Text("calc.offence.offence.line_122", { critical_cull = criticalCull, enemy_rarity = enemyRarity }))
				end
			end
			t_insert(globalBreakdown.CullingStrike, localisation:Text("calc.offence.offence.line_123", { inc_cull_percent = incCullPercent }))
			t_insert(globalBreakdown.CullingStrike, s_format("= %.2f%%", maxCullPercent))
		end

		--Calculate reservation DPS
		globalOutput.ReservationDpsMultiplier = 100 / (100 - enemyDB:Sum("BASE", nil, "LifeReservationPercent"))

		for _, damageType in ipairs(dmgTypeList) do
			activeSkill.gainTable[damageType] = {}
			for _, toType in ipairs(dmgTypeList) do
				local globalGain = m_max(skillModList:Sum("BASE", skillCfg,
					"DamageAs"..toType,
					"DamageGainAs"..toType,
					damageType.."DamageAs"..toType,
					damageType.."DamageGainAs"..toType,
					isElemental[damageType] and "ElementalDamageAs"..toType or nil,
					isElemental[damageType] and "ElementalDamageGainAs"..toType or nil,
					damageType ~= "Chaos" and "NonChaosDamageAs"..toType or nil,
					damageType ~= "Chaos" and "NonChaosDamageGainAs"..toType or nil), 0)
				local skillGain = m_max(skillModList:Sum("BASE", skillCfg,
					"SkillDamageGainAs"..toType,
					"Skill"..damageType.."DamageGainAs"..toType,
					isElemental[damageType] and "SkillElementalDamageGainAs"..toType or nil,
					damageType ~= "Chaos" and "SkillNonChaosDamageGainAs"..toType or nil), 0)
				if skillModList:Flag(skillCfg, "DamageGainIsOnlyCold") and toType ~= "Cold" then
					activeSkill.gainTable[damageType]["Cold"] = (activeSkill.gainTable[damageType]["Cold"] or 0) + (globalGain + skillGain) / 100
				else
					activeSkill.gainTable[damageType][toType] = (activeSkill.gainTable[damageType][toType] or 0) + (globalGain + skillGain) / 100
				end
			end
		end

		-- Calculate base hit damage
		for _, damageType in ipairs(dmgTypeList) do
			local damageTypeMin = damageType.."Min"
			local damageTypeMax = damageType.."Max"
			local baseMultiplier = activeSkill.activeEffect.grantedEffectLevel.baseMultiplier or skillData.baseMultiplier or 1
			local addedMin = skillModList:Sum("BASE", cfg, damageTypeMin) + enemyDB:Sum("BASE", cfg, "Self"..damageTypeMin)
			local addedMax = skillModList:Sum("BASE", cfg, damageTypeMax) + enemyDB:Sum("BASE", cfg, "Self"..damageTypeMax)
			local addedMult = calcLib.mod(skillModList, cfg, "Added"..damageType.."Damage", "AddedDamage")
			local baseMin = ((source[damageTypeMin] or 0) + (source[damageType.."BonusMin"] or 0) + (addedMin * addedMult)) * baseMultiplier
			local baseMax = ((source[damageTypeMax] or 0) + (source[damageType.."BonusMax"] or 0) + (addedMax * addedMult)) * baseMultiplier
			output[damageTypeMin.."Base"] = baseMin
			output[damageTypeMax.."Base"] = baseMax
			if breakdown then
				breakdown[damageType] = { damageTypes = { } }
				if baseMin ~= 0 or baseMax ~= 0 then
					t_insert(breakdown[damageType], localisation:Text("calc.offence.offence.line_124"))
					local plus = ""
					if (source[damageTypeMin] or 0) ~= 0 or (source[damageTypeMax] or 0) ~= 0 then
						t_insert(breakdown[damageType], localisation:Text("calc.offence.offence.line_125", { value = source[damageTypeMin], value_2 = source[damageTypeMax], value_3 = ((source.type and localisation:Ref("calc.offence.offence.line.parameter_2")) or localisation:Ref("calc.offence.offence.line.parameter_3")) }))
					end
					if addedMin ~= 0 or addedMax ~= 0 then
						t_insert(breakdown[damageType], localisation:Text("calc.offence.offence.line_126", { plus = plus, added_min = addedMin, added_max = addedMax }))
						if addedMult ~= 1 then
							t_insert(breakdown[damageType], localisation:Text("calc.offence.offence.line_127", { added_mult = addedMult }))
						end
					end
					if baseMultiplier ~= 1 then
						t_insert(breakdown[damageType], localisation:Text("calc.offence.offence.line_128", { base_multiplier = baseMultiplier }))
					end
				end
			end
		end

		for _, damageType in ipairs(dmgTypeList) do
			local damageTypeMin = damageType.."Min"
			local damageTypeMax = damageType.."Max"
			local convMult = activeSkill.conversionTable[damageType].mult
			local convertedMin, convertedMax = calcConvertedDamage(activeSkill, output, cfg, damageType)
			local gainedMin, gainedMax = calcGainedDamage(activeSkill, output, cfg, damageType)
			local baseMin = output[damageTypeMin.."Base"]
			local baseMax = output[damageTypeMax.."Base"]
			local summedMin = baseMin * convMult + convertedMin + gainedMin
			local summedMax = baseMax * convMult + convertedMax + gainedMax
			output[damageType.."SummedMinBase"] = summedMin
			output[damageType.."SummedMaxBase"] = summedMax
			if breakdown then
				if (baseMin ~= 0 or baseMax ~= 0) then
					if convMult ~= 1 then
						t_insert(breakdown[damageType], localisation:Text("calc.offence.offence.line_129", { conv_mult = convMult, value = (1-convMult)*100 }))
					end
				else  -- this means base damage header wasn't applied in the previous section
					t_insert(breakdown[damageType], localisation:Text("calc.offence.offence.line_124"))
				end
				if convertedMin ~= 0 or convertedMax ~= 0 then
					t_insert(breakdown[damageType], localisation:Text("calc.offence.offence.line_130", { value = round(convertedMin), value_2 = round(convertedMax) }))
				end
				if gainedMin ~= 0 or gainedMax ~= 0 then
					t_insert(breakdown[damageType], localisation:Text("calc.offence.offence.line_131", { value = round(gainedMin), value_2 = round(gainedMax) }))
				end
				t_insert(breakdown[damageType], localisation:Text("calc.offence.offence.line_132", { summed_min = summedMin, summed_max = summedMax }))
			end

			output[damageType.."StoredCombinedAvg"] = 0
		end

		-- Calculate hit damage for each damage type
		local totalHitMin, totalHitMax, totalHitAvg = 0, 0, 0
		local totalCritMin, totalCritMax, totalCritAvg = 0, 0, 0
		local ghostReaver = skillModList:Flag(nil, "GhostReaver")
		output.LifeLeech = 0
		output.LifeLeechInstant = 0
		output.EnergyShieldLeech = 0
		output.EnergyShieldLeechInstant = 0
		output.ManaLeech = 0
		output.ManaLeechInstant = 0

		for pass = 1, 2 do
			-- Pass 1 is critical strike damage, pass 2 is non-critical strike
			cfg.skillCond["CriticalStrike"] = (pass == 1)
			local lifeLeechTotal = 0
			local energyShieldLeechTotal = 0
			local manaLeechTotal = 0
			local noLifeLeech = skillModList:Flag(cfg, "CannotLeechLife") or enemyDB:Flag(nil, "CannotLeechLifeFromSelf") or skillModList:Flag(cfg, "CannotGainLife")
			local noEnergyShieldLeech = skillModList:Flag(cfg, "CannotLeechEnergyShield") or enemyDB:Flag(nil, "CannotLeechEnergyShieldFromSelf") or skillModList:Flag(cfg, "CannotGainEnergyShield")
			local noManaLeech = skillModList:Flag(cfg, "CannotLeechMana") or enemyDB:Flag(nil, "CannotLeechManaFromSelf") or skillModList:Flag(cfg, "CannotGainMana")
			for _, damageType in ipairs(dmgTypeList) do
				local damageTypeHitMin, damageTypeHitMax, damageTypeHitAvg, damageTypeLuckyChance, damageTypeHitAvgLucky, damageTypeHitAvgNotLucky = 0, 0, 0, 0, 0
				if skillFlags.hit and canDeal[damageType] then
					damageTypeHitMin, damageTypeHitMax = calcDamage(activeSkill, output, cfg, pass == 2 and breakdown and breakdown[damageType], damageType, 0)
					if pass == 2 and breakdown then
						t_insert(breakdown[damageType], localisation:Text("calc.offence.offence.line_133"))
						t_insert(breakdown[damageType], localisation:Text("calc.offence.offence.line_134", { damage_type_hit_min = damageTypeHitMin, damage_type_hit_max = damageTypeHitMax }))
						if output.DoubleDamageEffect ~= 0 then
							if output.TripleDamageEffect ~= 0 then
								t_insert(breakdown[damageType], localisation:Text("calc.offence.offence.line_135", { value = 1 + output.DoubleDamageEffect + output.TripleDamageEffect, double_damage_effect = output.DoubleDamageEffect, triple_damage_effect = output.TripleDamageEffect, double_damage_chance = output.DoubleDamageChance, triple_damage_chance = output.TripleDamageChance }))
							else
								t_insert(breakdown[damageType], localisation:Text("calc.offence.offence.line_136", { value = 1 + output.DoubleDamageEffect, double_damage_chance = output.DoubleDamageChance }))
							end
						elseif output.TripleDamageEffect ~= 0 then
							t_insert(breakdown[damageType], localisation:Text("calc.offence.offence.line_137", { value = 1 + output.TripleDamageEffect, triple_damage_chance = output.TripleDamageChance }))
						end
						if output.FistOfWarDamageEffect ~= 1 then
							t_insert(breakdown[damageType], localisation:Text("calc.offence.offence.line_138", { fist_of_war_damage_effect = output.FistOfWarDamageEffect }))
						end
						if output.AncestralCallDamageEffect ~= 1 then
							t_insert(breakdown[damageType], localisation:Text("calc.offence.offence.line_139", { ancestral_call_damage_effect = output.AncestralCallDamageEffect }))
						end
						if output.AncestralEmpowermentDamageEffect ~= 1 then
							t_insert(breakdown[damageType], localisation:Text("calc.offence.offence.line_140", { ancestral_empowerment_damage_effect = output.AncestralEmpowermentDamageEffect }))
						end
						if output.AncestralEmpowermentCombinedDamageEffect ~= 1 then
							t_insert(breakdown[damageType], localisation:Text("calc.offence.offence.line_141", { ancestral_empowerment_combined_damage_effect = output.AncestralEmpowermentCombinedDamageEffect }))
						end
						if globalOutput.OffensiveWarcryEffect ~= 1  and not activeSkill.skillModList:Flag(nil, "Condition:WarcryMaxHit") then
							t_insert(breakdown[damageType], localisation:Text("calc.offence.offence.line_142", { offensive_warcry_effect = globalOutput.OffensiveWarcryEffect }))
						end
						if globalOutput.MaxOffensiveWarcryEffect ~= 1 and activeSkill.skillModList:Flag(nil, "Condition:WarcryMaxHit") then
							t_insert(breakdown[damageType], localisation:Text("calc.offence.offence.line_143", { max_offensive_warcry_effect = globalOutput.MaxOffensiveWarcryEffect }))
						end
					end
					if activeSkill.skillModList:Flag(nil, "Condition:WarcryMaxHit") then
						output.allMult = output.ScaledDamageEffect * output.FistOfWarDamageEffect * output.AncestralCallDamageEffect * output.AncestralEmpowermentDamageEffect * output.AncestralEmpowermentCombinedDamageEffect * globalOutput.MaxOffensiveWarcryEffect
					else
						output.allMult = output.ScaledDamageEffect * output.FistOfWarDamageEffect * output.AncestralCallDamageEffect * output.AncestralEmpowermentDamageEffect * output.AncestralEmpowermentCombinedDamageEffect * globalOutput.OffensiveWarcryEffect
					end
					local allMult = output.allMult
					if pass == 1 then
						-- Apply crit multiplier
						allMult = allMult * output.CritMultiplier
					end
					damageTypeHitMin = damageTypeHitMin * allMult
					damageTypeHitMax = damageTypeHitMax * allMult
					if skillModList:Flag(skillCfg, "LuckyHits")
					or (pass == 2 and damageType == "Lightning" and skillModList:Flag(skillCfg, "LightningNoCritLucky"))
					or (pass == 1 and skillModList:Flag(skillCfg, "CritLucky"))
					or ((damageType == "Lightning" or damageType == "Cold" or damageType == "Fire") and skillModList:Flag(skillCfg, "ElementalLuckHits")) then
						damageTypeLuckyChance = 1
					else
						damageTypeLuckyChance = m_min(skillModList:Sum("BASE", skillCfg, damageType.."LuckyHitsChance", "LuckyHitsChance"), 100) / 100
					end
					damageTypeHitAvgNotLucky = (damageTypeHitMin / 2 + damageTypeHitMax / 2)
					damageTypeHitAvgLucky = (damageTypeHitMin / 3 + 2 * damageTypeHitMax / 3)
					damageTypeHitAvg = damageTypeHitAvgNotLucky * (1 - damageTypeLuckyChance) + damageTypeHitAvgLucky * damageTypeLuckyChance

					-- Store pre-resist/armour/penetration hit damage for ailment calculations
					if pass == 1 then
						output[damageType.."StoredCombinedAvg"] = output[damageType.."StoredCombinedAvg"] + damageTypeHitAvg * (output.CritChance / 100)
						output[damageType.."StoredCritAvg"] = damageTypeHitAvg
						output[damageType.."StoredCritMin"] = damageTypeHitMin
						output[damageType.."StoredCritMax"] = damageTypeHitMax
					else
						output[damageType.."StoredCombinedAvg"] = output[damageType.."StoredCombinedAvg"] + damageTypeHitAvg * (1 - output.CritChance / 100)
						output[damageType.."StoredHitAvg"] = damageTypeHitAvg
						output[damageType.."StoredHitMin"] = damageTypeHitMin
						output[damageType.."StoredHitMax"] = damageTypeHitMax
					end

					if (damageTypeHitMin ~= 0 or damageTypeHitMax ~= 0) and env.mode_effective then
						-- Apply enemy resistances and damage taken modifiers
						local resist = 0
						local pen = 0
						local minPen = 0
						local sourceRes = damageType
						local takenInc = enemyDB:Sum("INC", cfg, "DamageTaken", damageType.."DamageTaken")
						local takenMore = enemyDB:More(cfg, "DamageTaken", damageType.."DamageTaken")

						if damageType == "Physical" then
							local enemyArmourMin = 0
							if modDB:GetCondition("CanArmourBreakBelowZero", cfg, nil) then -- check for possibility to break Armour below zero
								enemyArmourMin = -enemyDB:Sum("BASE", { source = "Config"}, "Armour") or 0 -- adjust minimum armour value
								enemyDB:ReplaceMod("Armour", "OVERRIDE", -enemyDB:Sum("BASE", { source = "Config" }, "Armour"), "ArmourBreak", { type = "Condition", var = "ArmourBrokenBelowZeroMax" }, { type = "GlobalEffect", effectType= "Debuff", effectName = "ArmourBreak" }) -- if Config is set to Max, add mod with max value (use replace to avoid doubling)
							end
							local enemyArmour = enemyDB:Override(nil, "Armour") or m_max(calcLib.val(enemyDB, "Armour"), enemyArmourMin)
							local chanceIgnoreEnemyArmour = m_min(skillModList:Sum("BASE", cfg, "ChanceToIgnoreEnemyArmour") / 100, 1)
							local ignoreEnemyArmour = skillModList:Flag(cfg, "IgnoreEnemyArmour") and enemyArmour or calcLib.val(enemyDB, "IgnoreArmour") -- check for mods that ignore Armour
							if ignoreEnemyArmour and (enemyArmour > 0) then enemyArmour = m_max(enemyArmour - ignoreEnemyArmour, 0) end -- subtract ignored value up to zero, if Armour is still positive (to allow future support of negative Armour)
							local armourReduction = calcs.armourReductionF(enemyArmour, damageTypeHitAvg * skillModList:More(cfg, "CalcArmourAsThoughDealing"))
							local ChanceToIgnoreEnemyPhysicalDamageReduction = m_min(skillModList:Sum("BASE", cfg, "ChanceToIgnoreEnemyPhysicalDamageReduction"), 100)
							if ChanceToIgnoreEnemyPhysicalDamageReduction > 0 and ChanceToIgnoreEnemyPhysicalDamageReduction < 100 then
								if env.configInput.ChanceToIgnoreEnemyPhysicalDamageReductionMode == "MAX" then
									ChanceToIgnoreEnemyPhysicalDamageReduction = 100
								elseif env.configInput.ChanceToIgnoreEnemyPhysicalDamageReductionMode == "MIN" then
									ChanceToIgnoreEnemyPhysicalDamageReduction = 0
								end
							end
							if skillModList:Flag(cfg, "IgnoreEnemyPhysicalDamageReduction") or ChanceToIgnoreEnemyPhysicalDamageReduction >= 100 then
								resist = 0
							else
								resist = m_min(m_max(-data.misc.NegArmourDmgBonusCap, enemyDB:Sum("BASE", nil, "PhysicalDamageReduction") + skillModList:Sum("BASE", cfg, "EnemyPhysicalDamageReduction") + armourReduction * (1 - chanceIgnoreEnemyArmour)), data.misc.EnemyPhysicalDamageReductionCap)
								resist = resist > 0 and resist * (1 - (skillModList:Sum("BASE", nil, "PartialIgnoreEnemyPhysicalDamageReduction") / 100 + ChanceToIgnoreEnemyPhysicalDamageReduction / 100)) or resist
							end
						else
							resist = calcResistForType(damageType, cfg)
							if ((skillModList:Flag(cfg, "ChaosDamageUsesLowestResistance") or skillModList:Flag(cfg, "ChaosDamageUsesHighestResistance")) and damageType == "Chaos") or
							   (skillModList:Flag(cfg, "ElementalDamageUsesLowestResistance") and isElemental[damageType]) then
								-- Default to using the current damage type
								local elementUsed = damageType
								if isElemental[damageType] then
									takenInc = takenInc + enemyDB:Sum("INC", cfg, "ElementalDamageTaken")
								end
								-- Find the lowest resist of all the elements and use that if it's lower
								for _, eleDamageType in ipairs(dmgTypeList) do
									if isElemental[eleDamageType] and useThisResist(cfg,eleDamageType) and damageType ~= eleDamageType then
										local currentElementResist = calcResistForType(eleDamageType, cfg)
										-- If it's explicitly lower, then use the resist and update which element we're using to account for penetration
										if skillModList:Flag(cfg, "ChaosDamageUsesHighestResistance") then
											if resist < currentElementResist then
												resist = currentElementResist
												elementUsed = eleDamageType
											end
										else
											if resist > currentElementResist then
												resist = currentElementResist
												elementUsed = eleDamageType
											end
										end
									end
								end
								-- Update the penetration based on the element used
								if isElemental[elementUsed] then
									pen = skillModList:Sum("BASE", cfg, elementUsed.."Penetration", "ElementalPenetration")
									minPen = skillModList:Sum("BASE", cfg, elementUsed.."PenetrationMinimum", "ElementalPenetrationMinimum")
								elseif elementUsed == "Chaos" then
									pen = skillModList:Sum("BASE", cfg, "ChaosPenetration")
								end
								sourceRes = elementUsed
							elseif isElemental[damageType] then
								pen = skillModList:Sum("BASE", cfg, damageType.."Penetration", "ElementalPenetration")
								minPen = skillModList:Sum("BASE", cfg, damageType.."PenetrationMinimum", "ElementalPenetrationMinimum")
								takenInc = takenInc + enemyDB:Sum("INC", cfg, "ElementalDamageTaken")
							elseif damageType == "Chaos" then
								pen = skillModList:Sum("BASE", cfg, "ChaosPenetration")
							end
						end

						local invertChance = isElemental[damageType] and m_max(m_min(skillModList:Sum("CHANCE", cfg, "HitsInvertEleResChance"), 1), 0) or 0
						sourceRes = env.modDB:Flag(nil, "Enemy"..sourceRes.."ResistEqualToYours") and "Your "..sourceRes.." Resistance" or (env.partyMembers.modDB:Flag(nil, "Enemy"..sourceRes.."ResistEqualToYours") and "Party Member "..sourceRes.." Resistance" or sourceRes)
						if skillFlags.projectile then
							takenInc = takenInc + enemyDB:Sum("INC", nil, "ProjectileDamageTaken")
						end
						if skillFlags.projectile and skillFlags.attack then
							takenInc = takenInc + enemyDB:Sum("INC", nil, "ProjectileAttackDamageTaken")
						end
						if skillFlags.trap or skillFlags.mine then
							takenInc = takenInc + enemyDB:Sum("INC", nil, "TrapMineDamageTaken")
						end
						local effMult = (1 + takenInc / 100) * takenMore
						local useRes = useThisResist(cfg,damageType)
						local effectiveResist = resist
						local cannotElePenIgnore = isElemental[damageType] and skillModList:Flag(cfg, "CannotElePenIgnore")
						local ignoreNonNegativeEleRes = isElemental[damageType] and modDB:Flag(cfg, "IgnoreNonNegativeEleRes")
						local normalHitResist = calcHitResist(resist, minPen, pen, cannotElePenIgnore, ignoreNonNegativeEleRes)
						local invertedHitResist = calcHitResist(-resist, minPen, pen, cannotElePenIgnore, ignoreNonNegativeEleRes)
						local usesResistance = cannotElePenIgnore or useRes
						if usesResistance then
							if isElemental[damageType] and invertChance > 0 then
								effectiveResist = normalHitResist * (1 - invertChance) + invertedHitResist * invertChance
							else
								effectiveResist = normalHitResist
							end
							effMult = effMult * (1 - effectiveResist / 100)
						end
						damageTypeHitMin = damageTypeHitMin * effMult
						damageTypeHitMax = damageTypeHitMax * effMult
						damageTypeHitAvg = damageTypeHitAvg * effMult
						if env.mode == "CALCS" then
							output[damageType.."EffMult"] = effMult
						end
						local breakdownResist = invertChance > 0 and resist or normalHitResist
						if pass == 2 and breakdown and (effMult ~= 1 or sourceRes ~= damageType or invertChance > 0) and cannotElePenIgnore then
							t_insert(breakdown[damageType], localisation:Text("calc.offence.offence.line_144", { eff_mult = effMult }))
							breakdown[damageType.."EffMult"] = breakdown.effMult(damageType, breakdownResist, 0, takenInc, effMult, takenMore, sourceRes, usesResistance, invertChance, minPen, effectiveResist, normalHitResist, invertedHitResist)
						elseif pass == 2 and breakdown and (effMult ~= 1 or (resist - pen) < minPen or sourceRes ~= damageType or invertChance > 0) then
							t_insert(breakdown[damageType], localisation:Text("calc.offence.offence.line_144", { eff_mult = effMult }))
							breakdown[damageType.."EffMult"] = breakdown.effMult(damageType, breakdownResist, pen, takenInc, effMult, takenMore, sourceRes, usesResistance, invertChance, minPen, effectiveResist, normalHitResist, invertedHitResist)
						end
					end
					if pass == 2 and breakdown then
						t_insert(breakdown[damageType], localisation:Text("calc.offence.offence.line_145", { damage_type_hit_min = damageTypeHitMin, damage_type_hit_max = damageTypeHitMax }))
					end

					-- Beginning of Leech Calculation for this DamageType
					local lifeLeech = 0
					local energyShieldLeech = 0
					local manaLeech = 0

					if skillFlags.mine or skillFlags.trap or skillFlags.totem then
						lifeLeech = skillModList:Sum("BASE", cfg, "DamageLifeLeechToPlayer")
					else
						lifeLeech = getBaseLeech("Life", damageType, skillModList, cfg, enemyDB)
						energyShieldLeech = getBaseLeech("EnergyShield", damageType, skillModList, cfg, enemyDB)
						manaLeech = getBaseLeech("Mana", damageType, skillModList, cfg, enemyDB)
					end

					if ghostReaver and not noLifeLeech then
						energyShieldLeech = energyShieldLeech + lifeLeech
						lifeLeech = 0
					end

					if lifeLeech > 0 and not noLifeLeech then
						lifeLeechTotal = lifeLeechTotal + damageTypeHitAvg * lifeLeech / 100
					end
					if manaLeech > 0 and not noManaLeech then
						manaLeechTotal = manaLeechTotal + damageTypeHitAvg * manaLeech / 100
					end
					if energyShieldLeech > 0 and not noEnergyShieldLeech  then
						energyShieldLeechTotal = energyShieldLeechTotal + damageTypeHitAvg * energyShieldLeech / 100
					end
				else
					if breakdown then
						breakdown[damageType] = {
							localisation:Text("calc.offence.offence.line_239", { damage_type = localisation:TermRef("damage_type", damageType) })
						}
					end
				end
				if pass == 1 then
					output[damageType.."CritAverage"] = damageTypeHitAvg
					totalCritAvg = totalCritAvg + damageTypeHitAvg
					totalCritMin = totalCritMin + damageTypeHitMin
					totalCritMax = totalCritMax + damageTypeHitMax
				else
					if env.mode == "CALCS" then
						output[damageType.."Min"] = damageTypeHitMin
						output[damageType.."Max"] = damageTypeHitMax
					end
					output[damageType.."HitAverage"] = damageTypeHitAvg
					totalHitAvg = totalHitAvg + damageTypeHitAvg
					totalHitMin = totalHitMin + damageTypeHitMin
					totalHitMax = totalHitMax + damageTypeHitMax
				end
			end
			if skillData.lifeLeechPerUse then
				lifeLeechTotal = lifeLeechTotal + skillData.lifeLeechPerUse
			end
			if skillData.manaLeechPerUse then
				manaLeechTotal = manaLeechTotal + skillData.manaLeechPerUse
			end

			-- leech caps per instance
			lifeLeechTotal = m_min(lifeLeechTotal, globalOutput.MaxLifeLeechInstance)
			energyShieldLeechTotal = m_min(energyShieldLeechTotal, globalOutput.MaxEnergyShieldLeechInstance)
			manaLeechTotal = m_min(manaLeechTotal, globalOutput.MaxManaLeechInstance)

			local portion = (pass == 1) and (output.CritChance / 100) or (1 - output.CritChance / 100)
			output.LifeLeech = output.LifeLeech + lifeLeechTotal * portion
			output.EnergyShieldLeech = output.EnergyShieldLeech + energyShieldLeechTotal * portion
			output.ManaLeech = output.ManaLeech + manaLeechTotal * portion
		end
		output.TotalMin = totalHitMin
		output.TotalMax = totalHitMax

		if skillModList:Flag(skillCfg, "ElementalEquilibrium") and not env.configInput.EEIgnoreHitDamage and (output.FireHitAverage + output.ColdHitAverage + output.LightningHitAverage > 0) then
			-- Update enemy hit-by-damage-type conditions
			enemyDB.conditions.HitByFireDamage = output.FireHitAverage > 0
			enemyDB.conditions.HitByColdDamage = output.ColdHitAverage > 0
			enemyDB.conditions.HitByLightningDamage = output.LightningHitAverage > 0
		end

		local highestType = "Physical"

		-- For each damage type, calculate percentage of total damage. Also tracks the highest damage type and outputs a Condition:TypeIsHighestDamageType flag for whichever the highest type is
		for _, damageType in ipairs(dmgTypeList) do
			if output[damageType.."HitAverage"] > 0 then
				local portion = output[damageType.."HitAverage"] / totalHitAvg * 100
				skillModList:NewMod("Condition:"..damageType.."HasDamage", "FLAG", true, "Config")
				if output[damageType.."HitAverage"] > output[highestType.."HitAverage"] then
					highestType = damageType
				end
				if breakdown then
					t_insert(breakdown[damageType], localisation:Text("calc.offence.offence.line_146", { portion = portion }))
				end
			end
		end
		if not skillModList:Flag(nil, "IsHighestDamageTypeOVERRIDE") then
			skillModList:NewMod("Condition:"..highestType.."IsHighestDamageType", "FLAG", true, "Config")
		end



		--Instant Leech
		output.LifeLeechInstantProportion = m_max(m_min(skillModList:Sum("BASE", cfg, "InstantLifeLeech") or 0, 100), 0) / 100
		if output.LifeLeechInstantProportion > 0 then
			output.LifeLeechInstant = output.LifeLeech * output.LifeLeechInstantProportion
			output.LifeLeech = output.LifeLeech * (1 - output.LifeLeechInstantProportion)
		end
		output.ManaLeechInstantProportion = m_max(m_min(skillModList:Sum("BASE", cfg, "InstantManaLeech") or 0, 100), 0) / 100
		if output.ManaLeechInstantProportion > 0 then
			output.ManaLeechInstant = output.ManaLeech * output.ManaLeechInstantProportion
			output.ManaLeech = output.ManaLeech * (1 - output.ManaLeechInstantProportion)
		end
		output.EnergyShieldLeechInstantProportion = m_max(m_min(skillModList:Sum("BASE", cfg, "InstantEnergyShieldLeech") or 0, 100), 0) / 100
		if skillModList:Flag(cfg, "ManaLeechRecoversEnergyShield") then
			output.EnergyShieldLeechInstantProportion = output.EnergyShieldLeechInstantProportion + output.ManaLeechInstantProportion
		end
		if output.EnergyShieldLeechInstantProportion > 0 then
			output.EnergyShieldLeechInstant = output.EnergyShieldLeech * output.EnergyShieldLeechInstantProportion
			output.EnergyShieldLeech = output.EnergyShieldLeech * (1 - output.EnergyShieldLeechInstantProportion)
		end

		output.LifeLeechDuration, output.LifeLeechInstances = getLeechInstances(output.LifeLeech, globalOutput.Life, hitRate)
		output.LifeLeechInstantRate = output.LifeLeechInstant * hitRate
		output.EnergyShieldLeechDuration, output.EnergyShieldLeechInstances = getLeechInstances(output.EnergyShieldLeech, globalOutput.EnergyShield, hitRate)
		output.EnergyShieldLeechInstantRate = output.EnergyShieldLeechInstant * hitRate
		output.ManaLeechDuration, output.ManaLeechInstances = getLeechInstances(output.ManaLeech, globalOutput.Mana, hitRate)
		output.ManaLeechInstantRate = output.ManaLeechInstant * hitRate

		-- Calculate gain on hit
		if skillFlags.mine or skillFlags.trap or skillFlags.totem then
			output.LifeOnHit = 0
			output.EnergyShieldOnHit = 0
			output.ManaOnHit = 0
		else
			output.LifeOnHit = not skillModList:Flag(cfg, "CannotGainLife") and not skillModList:Flag(cfg, "CannotRecoverLifeOutsideLeech") and (skillModList:Sum("BASE", cfg, "LifeOnHit") + enemyDB:Sum("BASE", cfg, "SelfLifeOnHit")) or 0
			output.EnergyShieldOnHit = not skillModList:Flag(cfg, "CannotGainEnergyShield") and (skillModList:Sum("BASE", cfg, "EnergyShieldOnHit") + enemyDB:Sum("BASE", cfg, "SelfEnergyShieldOnHit")) or 0
			output.ManaOnHit = not skillModList:Flag(cfg, "CannotGainMana") and (skillModList:Sum("BASE", cfg, "ManaOnHit") + enemyDB:Sum("BASE", cfg, "SelfManaOnHit")) or 0
		end
		output.LifeOnHitRate = output.LifeOnHit * hitRate
		output.EnergyShieldOnHitRate = output.EnergyShieldOnHit * hitRate
		output.ManaOnHitRate = output.ManaOnHit * hitRate

		-- Calculate gain on kill
		if skillFlags.mine or skillFlags.trap or skillFlags.totem then
			output.LifeOnKill = 0
			output.EnergyShieldOnKill = 0
			output.ManaOnKill = 0
		else
			output.LifeOnKill = not skillModList:Flag(cfg, "CannotGainLife") and not skillModList:Flag(cfg, "CannotRecoverLifeOutsideLeech") and (m_floor(skillModList:Sum("BASE", cfg, "LifeOnKill"))) or 0
			output.EnergyShieldOnKill = not skillModList:Flag(cfg, "CannotGainEnergyShield") and (m_floor(skillModList:Sum("BASE", cfg, "EnergyShieldOnKill"))) or 0
			output.ManaOnKill = not skillModList:Flag(cfg, "CannotGainMana") and (m_floor(skillModList:Sum("BASE", cfg, "ManaOnKill"))) or 0
		end

		-- Enemy Regeneration Rate
		output.EnemyLifeRegen = enemyDB:Sum("INC", cfg, "LifeRegen")
		output.EnemyManaRegen = enemyDB:Sum("INC", cfg, "ManaRegen")
		output.EnemyEnergyShieldRegen = enemyDB:Sum("INC", cfg, "EnergyShieldRegen")

		-- Calculate average damage and final DPS
		output.AverageHit = totalHitAvg * (1 - output.CritChance / 100) + totalCritAvg * output.CritChance / 100
		if skillFlags.monsterExplode then
			output.AverageHitToMonsterLifePercentage = output.AverageHit / monsterLife * 100
			if skillData.hitChanceIsExplodeChance then
				output.HitChance = output.ExplodeChance
			end
		end
		output.AverageDamage = output.AverageHit * output.HitChance / 100
		globalOutput.AverageBurstHits = output.AverageBurstHits or 1
		local repeatPenalty = skillModList:Flag(nil, "HasSeals") and skillModList:Flag(nil, "DamageSeal") and not skillModList:Flag(nil, "NoRepeatBonuses") and calcLib.mod(skillModList, skillCfg, "SealRepeatPenalty") or 1
		globalOutput.AverageBurstDamage = output.AverageDamage + output.AverageDamage * (globalOutput.AverageBurstHits - 1) * repeatPenalty or 0
		globalOutput.ShowBurst = globalOutput.AverageBurstHits > 1
		output.TotalDPS = output.AverageDamage * (globalOutput.HitSpeed or globalOutput.Speed) * output.DpsMultiplier * quantityMultiplier
		if breakdown then
			if output.CritEffect ~= 1 then
				breakdown.AverageHit = { }
				if skillModList:Flag(skillCfg, "LuckyHits") then
					t_insert(breakdown.AverageHit, localisation:Text("calc.offence.offence.line_147", { total_hit_min = totalHitMin, total_hit_max = totalHitMax, total_hit_avg = totalHitAvg }))
				end
				if skillModList:Flag(skillCfg, "CritLucky") or skillModList:Flag(skillCfg, "LuckyHits") then
					t_insert(breakdown.AverageHit, localisation:Text("calc.offence.offence.line_148", { total_crit_min = totalCritMin, total_crit_max = totalCritMax, total_crit_avg = totalCritAvg }))
					t_insert(breakdown.AverageHit, "")
				end
				t_insert(breakdown.AverageHit, localisation:Text("calc.offence.offence.line_149", { total_hit_avg = totalHitAvg, value = output.CritChance / 100 }))
				t_insert(breakdown.AverageHit, localisation:Text("calc.offence.offence.line_150", { total_crit_avg = totalCritAvg, value = output.CritChance / 100 }))
				t_insert(breakdown.AverageHit, s_format("= %.1f", output.AverageHit))
			end
			if output.HitChance < 100 then
				breakdown.AverageDamage = { }
				t_insert(breakdown.AverageDamage, s_format("%s:", localisation:Term("attack_hand", pass.label)))
				t_insert(breakdown.AverageDamage, localisation:Text("calc.offence.offence.line_151", { average_hit = output.AverageHit }))
				t_insert(breakdown.AverageDamage, localisation:Text("calc.offence.offence.line_152", { value = output.HitChance / 100 }))
				t_insert(breakdown.AverageDamage, s_format("= %.1f", output.AverageDamage))
			end
		end
		if globalBreakdown and globalOutput.AverageBurstDamage > 0 then
			globalBreakdown.AverageBurstDamage = { }
			t_insert(globalBreakdown.AverageBurstDamage, localisation:Text("calc.offence.offence.line_151", { average_hit = output.AverageHit }))
			if output.HitChance < 100 then
				t_insert(globalBreakdown.AverageBurstDamage, localisation:Text("calc.offence.offence.line_152", { value = output.HitChance / 100 }))
			end
			if repeatPenalty < 1 then
				t_insert(globalBreakdown.AverageBurstDamage, localisation:Text("calc.offence.offence.line_153", { value = globalOutput.AverageBurstHits - 1 }))
				t_insert(globalBreakdown.AverageBurstDamage, localisation:Text("calc.offence.offence.line_154", { repeat_penalty = repeatPenalty }))
				t_insert(globalBreakdown.AverageBurstDamage, localisation:Text("calc.offence.offence.line_155", { value = globalOutput.AverageBurstDamage - output.AverageDamage }))
				t_insert(globalBreakdown.AverageBurstDamage, "")
				t_insert(globalBreakdown.AverageBurstDamage, localisation:Text("calc.offence.offence.line_156", { average_hit = output.AverageHit }))
				if output.HitChance < 100 then
					t_insert(globalBreakdown.AverageBurstDamage, localisation:Text("calc.offence.offence.line_152", { value = output.HitChance / 100 }))
				end
			else
				t_insert(globalBreakdown.AverageBurstDamage, localisation:Text("calc.offence.offence.line_157", { average_burst_hits = globalOutput.AverageBurstHits }))
			end
			t_insert(globalBreakdown.AverageBurstDamage, localisation:Text("calc.offence.offence.line_158", { average_burst_damage = globalOutput.AverageBurstDamage }))
		end


		-- Calculate PvP values

		--setup flags
		skillFlags.isPvP = false
		skillFlags.notAttackPvP = false
		skillFlags.attackPvP = false
		skillFlags.weapon1AttackPvP = false
		skillFlags.weapon2AttackPvP = false
		skillFlags.notAveragePvP = false

		if env.configInput.PvpScaling then
			skillFlags.isPvP = true
			skillFlags.attackPvP = skillFlags.attack
			skillFlags.notAttackPvP = not skillFlags.attack
			skillFlags.weapon1AttackPvP = skillFlags.weapon1Attack
			skillFlags.weapon2AttackPvP = skillFlags.weapon2Attack
			skillFlags.notAveragePvP = skillFlags.notAverage
			local PvpTvalue = env.configInput.multiplierPvpTvalueOverride or nil
			if PvpTvalue then
				PvpTvalue = PvpTvalue / 1000
			else
				if skillData.cooldown then
					PvpTvalue = skillData.cooldown
				elseif skillFlags.mine then
					PvpTvalue = (output.MineLayingTime or 1) / globalOutput.ActionSpeedMod
				elseif skillFlags.trap then
					PvpTvalue = (output.TrapThrowingTime or 1) / globalOutput.ActionSpeedMod
				else
					PvpTvalue = 1/((globalOutput.HitSpeed or globalOutput.Speed)/globalOutput.ActionSpeedMod) * skillModList:More(cfg, "PvpTvalueMultiplier")
				end
				if PvpTvalue > 2147483647 then
					PvpTvalue = 1
				end
			end
			local PvpMultiplier = skillModList:More(cfg, "PvpDamageMultiplier")

			local PvpNonElemental1 = data.misc.PvpNonElemental1
			local PvpNonElemental2 = data.misc.PvpNonElemental2
			local PvpElemental1 = data.misc.PvpElemental1
			local PvpElemental2 = data.misc.PvpElemental2

			local percentageNonElemental = ((output["PhysicalHitAverage"] + output["ChaosHitAverage"]) / (totalHitMin + totalHitMax) * 2)
			local percentageElemental = 1 - percentageNonElemental
			local portionNonElemental = (output.AverageHit / PvpTvalue / PvpNonElemental2 ) ^ PvpNonElemental1 * PvpTvalue * PvpNonElemental2 * percentageNonElemental
			local portionElemental = (output.AverageHit / PvpTvalue / PvpElemental2 ) ^ PvpElemental1 * PvpTvalue * PvpElemental2 * percentageElemental
			output.PvpAverageHit = (portionNonElemental + portionElemental) * PvpMultiplier
			output.PvpAverageDamage = output.PvpAverageHit * output.HitChance / 100
			output.PvpTotalDPS = output.PvpAverageDamage * (globalOutput.HitSpeed or globalOutput.Speed) * output.DpsMultiplier

			-- fix for these being nan
			if output.PvpAverageHit ~= output.PvpAverageHit then
				output.PvpAverageHit = 0
			end
			if output.PvpAverageDamage ~= output.PvpAverageDamage then
				output.PvpAverageDamage = 0
			end
			if output.PvpTotalDPS ~= output.PvpTotalDPS then
				output.PvpTotalDPS = 0
			end

			if breakdown then
				breakdown.PvpAverageHit = { }
				local percentBoth = (percentageNonElemental > 0) and (percentageElemental > 0)
				t_insert(breakdown.PvpAverageHit, localisation:Text("calc.offence.offence.line_159", { value = ((percentBoth and "M*P") or "M") }))
				t_insert(breakdown.PvpAverageHit, localisation:Text("calc.offence.offence.line_160", { value = ((percentBoth and localisation:Ref("calc.offence.offence.line.parameter_4")) or localisation:Ref("calc.offence.offence.line.parameter_5")) }))
				if percentBoth then
					t_insert(breakdown.PvpAverageHit, localisation:Text("calc.offence.offence.line_161", { pvp_elemental2 = PvpElemental2, pvp_non_elemental2 = PvpNonElemental2, pvp_elemental1 = PvpElemental1, pvp_non_elemental1 = PvpNonElemental1 }))
					t_insert(breakdown.PvpAverageHit, s_format("(%.1f / (%.2f * %.1f)) ^ %.2f * %.2f * %.1f * %.2f = %.1f", output.AverageHit, PvpTvalue,  PvpNonElemental2, PvpNonElemental1, PvpTvalue, PvpNonElemental2, percentageNonElemental, portionNonElemental))
					t_insert(breakdown.PvpAverageHit, s_format("(%.1f / (%.2f * %.1f)) ^ %.2f * %.2f * %.1f * %.2f = %.1f", output.AverageHit, PvpTvalue,  PvpElemental2, PvpElemental1, PvpTvalue, PvpElemental2, percentageElemental, portionElemental))
					t_insert(breakdown.PvpAverageHit, localisation:Text("calc.offence.offence.line_162", { value = ((PvpMultiplier ~= 1 and localisation:Ref("calc.offence.offence.line.parameter_6")) or " ") }))
					if PvpMultiplier ~= 1 then
						t_insert(breakdown.PvpAverageHit, s_format("(%.1f + %.1f) * %g", portionNonElemental, portionElemental, PvpMultiplier))
					else
						t_insert(breakdown.PvpAverageHit, s_format("%.1f + %.1f", portionNonElemental, portionElemental))
					end
				elseif percentageElemental <= 0 then
					t_insert(breakdown.PvpAverageHit, localisation:Text("calc.offence.offence.line_163", { pvp_non_elemental2 = PvpNonElemental2, pvp_non_elemental1 = PvpNonElemental1 }))
					t_insert(breakdown.PvpAverageHit, s_format("(%.1f / (%.2f * %.1f)) ^ %.2f * %.2f * %.1f = %.1f", output.AverageHit, PvpTvalue,  PvpNonElemental2, PvpNonElemental1, PvpTvalue, PvpNonElemental2, portionNonElemental))
					if PvpMultiplier ~= 1 then
						t_insert(breakdown.PvpAverageHit, localisation:Text("calc.offence.offence.line_164", { portion_non_elemental = portionNonElemental, pvp_multiplier = PvpMultiplier }))
					end
				elseif percentageNonElemental <= 0 then
					t_insert(breakdown.PvpAverageHit, localisation:Text("calc.offence.offence.line_165", { pvp_elemental2 = PvpElemental2, pvp_elemental1 = PvpElemental1 }))
					t_insert(breakdown.PvpAverageHit, s_format("(%.1f / (%.2f * %.1f)) ^ %.2f * %.2f * %.1f = %.1f", output.AverageHit, PvpTvalue,  PvpElemental2, PvpElemental1, PvpTvalue, PvpElemental2, portionElemental))
					if PvpMultiplier ~= 1 then
						t_insert(breakdown.PvpAverageHit, localisation:Text("calc.offence.offence.line_166", { portion_elemental = portionElemental, pvp_multiplier = PvpMultiplier }))
					end
				end
				t_insert(breakdown.PvpAverageHit, s_format("= %.1f", output.PvpAverageHit))
				if isAttack then
					breakdown.PvpAverageDamage = { }
					t_insert(breakdown.PvpAverageDamage, s_format("%s:", localisation:Term("attack_hand", pass.label)))
					t_insert(breakdown.PvpAverageDamage, localisation:Text("calc.offence.offence.line_167", { pvp_average_hit = output.PvpAverageHit }))
					t_insert(breakdown.PvpAverageDamage, localisation:Text("calc.offence.offence.line_152", { value = output.HitChance / 100 }))
					t_insert(breakdown.PvpAverageDamage, s_format("= %.1f", output.PvpAverageDamage))
				end
			end
		end
	end

	if isAttack then
		-- Combine crit stats, average damage and DPS
		combineStat("PreEffectiveCritChance", "AVERAGE")
		combineStat("CritChance", "CRIT")
		combineStat("PreEffectiveCritMultiplier", "AVERAGE")
		combineStat("CritMultiplier", "AVERAGE")
		combineStat("CritBifurcates", "AVERAGE")
		combineStat("AverageDamage", "DPS")
		combineStat("PvpAverageDamage", "DPS")
		combineStat("DpsMultiplier", "DPS")
		combineStat("TotalDPS", "DPS")
		combineStat("PvpTotalDPS", "DPS")
		combineStat("LifeLeechDuration", "DPS")
		combineStat("LifeLeechInstances", "DPS")
		combineStat("LifeLeechInstant", "DPS")
		combineStat("LifeLeechInstantRate", "DPS")
		combineStat("LifeLeechInstantProportion", "DPS")
		combineStat("EnergyShieldLeechDuration", "DPS")
		combineStat("EnergyShieldLeechInstances", "DPS")
		combineStat("EnergyShieldLeechInstant", "DPS")
		combineStat("EnergyShieldLeechInstantRate", "DPS")
		combineStat("EnergyShieldLeechInstantProportion", "DPS")
		combineStat("ManaLeechDuration", "DPS")
		combineStat("ManaLeechInstances", "DPS")
		combineStat("ManaLeechInstant", "DPS")
		combineStat("ManaLeechInstantRate", "DPS")
		combineStat("ManaLeechInstantProportion", "DPS")
		combineStat("LifeOnHit", "DPS")
		combineStat("LifeOnHitRate", "DPS")
		combineStat("LifeOnKill", "DPS")
		combineStat("EnergyShieldOnHit", "DPS")
		combineStat("EnergyShieldOnHitRate", "DPS")
		combineStat("EnergyShieldOnKill", "DPS")
		combineStat("ManaOnHit", "DPS")
		combineStat("ManaOnHitRate", "DPS")
		combineStat("ManaOnKill", "DPS")
		for _, damageType in ipairs(dmgTypeList) do
			combineStat(damageType.."StoredCombinedAvg", "DPS")
		end
		-- Crossbows:
		if activeSkill.skillTypes[SkillType.CrossbowSkill] and not activeSkill.skillTypes[SkillType.Grenade] then
			-- Combine stats related to reload and bolt functionality
			combineStat("FiringRate", "AVERAGE")
			combineStat("ReloadTime", "AVERAGE")
			combineStat("EffectiveReloadTime", "AVERAGE")
			combineStat("ReloadRate", "AVERAGE")
			combineStat("BoltCount", "AVERAGE")
			combineStat("EffectiveBoltCount", "AVERAGE")
			combineStat("TotalFiringTime", "AVERAGE")
			combineStat("ChanceToNotConsumeAmmo", "AVERAGE")
			combineStat("ChanceToReloadInstantly", "AVERAGE")

			-- Add stats related to "Chance to not consume a bolt" to breakdown
			if breakdown then
				if output.ChanceToNotConsumeAmmo then
					breakdown.EffectiveBoltCount = { }
					t_insert(breakdown.EffectiveBoltCount, localisation:Text("calc.offence.offence.line_168", { bolt_count = output.BoltCount }))
					t_insert(breakdown.EffectiveBoltCount, localisation:Text("calc.offence.offence.line_169", { value = m_min(output.ChanceToNotConsumeAmmo / 100, 1) }))
					t_insert(breakdown.EffectiveBoltCount, s_format("\n"))
					t_insert(breakdown.EffectiveBoltCount, localisation:Text("calc.offence.offence.line_170", { value = (output.EffectiveBoltCount or 1/0) })) -- 1/0 is used as a stand-in for "infinite"
				end
				if output.ChanceToReloadInstantly then
					breakdown.EffectiveReloadTime = { }
					t_insert(breakdown.EffectiveReloadTime, localisation:Text("calc.offence.offence.line_171", { reload_time = output.ReloadTime }))
					t_insert(breakdown.EffectiveReloadTime, localisation:Text("calc.offence.offence.line_172", { value = m_min(output.ChanceToReloadInstantly / 100, 1) }))
					t_insert(breakdown.EffectiveReloadTime, s_format("\n"))
					t_insert(breakdown.EffectiveReloadTime, localisation:Text("calc.offence.offence.line_173", { effective_reload_time = output.EffectiveReloadTime }))
				end

			end
			-- Game data specifies "base skill show average damage instead of dps" for many crossbow skills, where that doesn't make sense for PoB (e.g. Explosive Shot)
			skillData.showAverage = false
			skillFlags.showAverage = false
			skillFlags.notAverage = true
		end
		if breakdown then
			if skillFlags.bothWeaponAttack then
				for _, critStat in ipairs({ "PreEffectiveCritChance", "CritChance" }) do
					local combinedBreakdown = { localisation:Text("calc.offence.offence.line_242") }
					for _, pass in ipairs(passList) do
						t_insert(combinedBreakdown, localisation:Term("attack_hand", pass.label) .. ":")
						if pass.breakdown[critStat] then
							for _, line in ipairs(pass.breakdown[critStat]) do
								t_insert(combinedBreakdown, line)
							end
						else
							t_insert(combinedBreakdown, s_format("%.2f%%", pass.output[critStat]))
						end
					end
					t_insert(combinedBreakdown, localisation:Text("calc.offence.offence.line_174", { value = output[critStat] }))
					breakdown[critStat] = combinedBreakdown
				end
			else
				local handBreakdown = skillFlags.weapon1Attack and breakdown.MainHand or breakdown.OffHand
				breakdown.PreEffectiveCritChance = handBreakdown.PreEffectiveCritChance
				breakdown.CritChance = handBreakdown.CritChance
			end
			local breakdownSource = skillFlags.weapon1Attack and "MainHand.CritChance" or "OffHand.CritChance"
			if breakdown.PreEffectiveCritChance then
				breakdown.PreEffectiveCritChance.breakdownSource = breakdownSource
			end
			if breakdown.CritChance then
				breakdown.CritChance.breakdownSource = breakdownSource
			end
		end
		if skillFlags.bothWeaponAttack then
			if breakdown then
				breakdown.AverageDamage = { }
				t_insert(breakdown.AverageDamage, localisation:Text("calc.offence.offence.line_175"))
				if skillData.combinesHitsWhenDualWielding then
					t_insert(breakdown.AverageDamage, localisation:Text("calc.offence.offence.line_176", { average_damage = output.MainHand.AverageDamage, average_damage_2 = output.OffHand.AverageDamage }))
				elseif skillData.doubleHitsWhenDualWielding then
					t_insert(breakdown.AverageDamage, localisation:Text("calc.offence.offence.line_177", { average_damage = output.MainHand.AverageDamage, average_damage_2 = output.OffHand.AverageDamage }))
				else
					t_insert(breakdown.AverageDamage, localisation:Text("calc.offence.offence.line_178", { average_damage = output.MainHand.AverageDamage, average_damage_2 = output.OffHand.AverageDamage }))
				end
				t_insert(breakdown.AverageDamage, s_format("= %.1f", output.AverageDamage))
				if skillFlags.isPvP then
					breakdown.PvpAverageDamage = { }
					t_insert(breakdown.PvpAverageDamage, localisation:Text("calc.offence.offence.line_175"))
					if skillData.combinesHitsWhenDualWielding then
						t_insert(breakdown.PvpAverageDamage, localisation:Text("calc.offence.offence.line_179", { pvp_average_damage = output.MainHand.PvpAverageDamage, pvp_average_damage_2 = output.OffHand.PvpAverageDamage }))
					else
						t_insert(breakdown.PvpAverageDamage, localisation:Text("calc.offence.offence.line_180", { pvp_average_damage = output.MainHand.PvpAverageDamage, pvp_average_damage_2 = output.OffHand.PvpAverageDamage }))
					end
					t_insert(breakdown.PvpAverageDamage, s_format("= %.1f", output.PvpAverageDamage))
				end
			end
		end
	end
	if env.mode == "CALCS" then
		if skillData.showAverage then
			output.DisplayDamage = formatNumSep(s_format("%.1f", output.AverageDamage)) .. " average damage"
		else
			output.DisplayDamage = formatNumSep(s_format("%.1f", output.TotalDPS)) .. " DPS"
		end
	end
	if breakdown then
		if isAttack then
			breakdown.TotalDPS = {
				localisation:Text("calc.offence.total_dps.line", { average_damage = output.AverageDamage }),
				output.HitSpeed and localisation:Text("calc.offence.total_dps.line_2", { hit_speed = output.HitSpeed }) or localisation:Text("calc.offence.total_dps.line_3", { speed = output.Speed }),
			}
		elseif skillData.triggered then
			breakdown.TotalDPS = {
				localisation:Text("calc.offence.total_dps.line", { average_damage = output.AverageDamage }),
				output.HitSpeed and localisation:Text("calc.offence.total_dps.line_2", { hit_speed = output.HitSpeed }) or localisation:Text("calc.offence.total_dps.line_4", { speed = output.Speed }),
			}
		else
			breakdown.TotalDPS = {
				localisation:Text("calc.offence.total_dps.line_5", { average_damage = output.AverageDamage }),
				output.HitSpeed and localisation:Text("calc.offence.total_dps.line_2", { hit_speed = output.HitSpeed }) or localisation:Text("calc.offence.total_dps.line_6", { speed = output.Speed }),
			}
		end
		if output.DpsMultiplier ~= 1 then
			t_insert(breakdown.TotalDPS, localisation:Text("calc.offence.offence.line_181", { dps_multiplier = output.DpsMultiplier }))
		end
		if quantityMultiplier > 1 then
			t_insert(breakdown.TotalDPS, localisation:Text("calc.offence.offence.line_182", { quantity_multiplier = quantityMultiplier }))
		end
		t_insert(breakdown.TotalDPS, s_format("= %.1f", output.TotalDPS))
		if skillFlags.isPvP then
			local rateType = "cast"
			if isAttack then
				rateType = "attack"
			elseif skillData.triggered then
				rateType = "trigger"
			end
			breakdown.PvpTotalDPS = {
				localisation:Text("calc.offence.pvp_total_dps.line", { pvp_average_damage = output.PvpAverageDamage }),
				output.HitSpeed and localisation:Text("calc.offence.pvp_total_dps.line_2", { hit_speed = output.HitSpeed }) or localisation:Text("calc.offence.pvp_total_dps.line_3", { speed = output.Speed, rate_type = rateType }),
			}
			if output.DpsMultiplier ~= 1 then
				t_insert(breakdown.PvpTotalDPS, localisation:Text("calc.offence.offence.line_181", { dps_multiplier = output.DpsMultiplier }))
			end
			if quantityMultiplier > 1 then
				t_insert(breakdown.PvpTotalDPS, localisation:Text("calc.offence.offence.line_182", { quantity_multiplier = quantityMultiplier }))
			end
			t_insert(breakdown.PvpTotalDPS, s_format("= %.1f", output.PvpTotalDPS))
		end
	end

	if skillFlags.minion then
		skillData.summonSpeed = output.SummonedMinionsPerCast * (output.HitSpeed or output.Speed) * output.DpsMultiplier
	end

	-- Calculate leech rates
	output.LifeLeechInstanceRate = output.Life * data.misc.LeechRateBase * calcLib.mod(skillModList, skillCfg, "LifeLeechRate")
	output.LifeLeechRate = output.LifeLeechInstances * output.LifeLeechInstanceRate
	output.LifeLeechPerHit = output.LifeLeechInstanceRate
	output.EnergyShieldLeechInstanceRate = output.EnergyShield * data.misc.LeechRateBase * calcLib.mod(skillModList, skillCfg, "EnergyShieldLeechRate")
	output.EnergyShieldLeechRate = output.EnergyShieldLeechInstances * output.EnergyShieldLeechInstanceRate
	output.EnergyShieldLeechPerHit = output.EnergyShieldLeechInstanceRate
	output.ManaLeechInstanceRate = output.Mana * data.misc.LeechRateBase * calcLib.mod(skillModList, skillCfg, "ManaLeechRate")
	output.ManaLeechRate = output.ManaLeechInstances * output.ManaLeechInstanceRate
	output.ManaLeechPerHit = output.ManaLeechInstanceRate
	-- On full life, Immortal Ambition treats life leech as energy shield leech
	if skillModList:Flag(nil, "ImmortalAmbition") then
		output.EnergyShieldLeechRate = output.EnergyShieldLeechRate + output.LifeLeechRate
		output.EnergyShieldLeechPerHit = output.EnergyShieldLeechPerHit  + output.LifeLeechPerHit
		-- Clears output.LifeLeechRate to disable leechLife flag
		output.LifeLeechRate = 0
		output.LifeLeechPerHit = 0
	end
	-- Disable non-instant life leech
	if skillModList:Flag(nil, "UnaffectedByNonInstantLifeLeech") then
		output.LifeLeechRate = 0
		output.LifeLeechPerHit = 0
		output.LifeLeechInstances = 0
	end
	output.LifeLeechRate = output.LifeLeechInstantRate + m_min(output.LifeLeechRate, output.MaxLifeLeechRate) * output.LifeRecoveryRateMod
	output.LifeLeechPerHit = output.LifeLeechInstant + m_min(output.LifeLeechPerHit, output.MaxLifeLeechRate) * output.LifeLeechDuration * output.LifeRecoveryRateMod
	output.EnergyShieldLeechRate = output.EnergyShieldLeechInstantRate + m_min(output.EnergyShieldLeechRate, output.MaxEnergyShieldLeechRate) * output.EnergyShieldRecoveryRateMod
	output.EnergyShieldLeechPerHit = output.EnergyShieldLeechInstant + m_min(output.EnergyShieldLeechPerHit, output.MaxEnergyShieldLeechRate) * output.EnergyShieldLeechDuration * output.EnergyShieldRecoveryRateMod
	output.ManaLeechRate = output.ManaLeechInstantRate + m_min(output.ManaLeechRate, output.MaxManaLeechRate) * output.ManaRecoveryRateMod
	output.ManaLeechPerHit = output.ManaLeechInstant + m_min(output.ManaLeechPerHit, output.MaxManaLeechRate) * output.ManaLeechDuration * output.ManaRecoveryRateMod
	skillFlags.leechLife = output.LifeLeechRate > 0
	skillFlags.leechES = output.EnergyShieldLeechRate > 0
	skillFlags.leechMana = output.ManaLeechRate > 0
	if skillData.showAverage then
		output.LifeLeechGainPerHit = output.LifeLeechPerHit + output.LifeOnHit
		output.EnergyShieldLeechGainPerHit = output.EnergyShieldLeechPerHit + output.EnergyShieldOnHit
		output.ManaLeechGainPerHit = output.ManaLeechPerHit + output.ManaOnHit
	else
		output.LifeLeechGainRate = output.LifeLeechRate + output.LifeOnHitRate
		output.EnergyShieldLeechGainRate = output.EnergyShieldLeechRate + output.EnergyShieldOnHitRate
		output.ManaLeechGainRate = output.ManaLeechRate + output.ManaOnHitRate
	end
	if breakdown then
		local hitRate = output.HitChance / 100 * (globalOutput.HitSpeed or globalOutput.Speed) * output.DpsMultiplier
		if skillFlags.leechLife then
			breakdown.LifeLeech = breakdown.leech(output.LifeLeechInstant, output.LifeLeechInstantRate, output.LifeLeechInstances, output.Life, "LifeLeechRate", output.MaxLifeLeechRate, output.LifeLeechDuration, output.LifeLeechInstantProportion, hitRate)
		end
		if skillFlags.leechES then
			breakdown.EnergyShieldLeech = breakdown.leech(output.EnergyShieldLeechInstant, output.EnergyShieldLeechInstantRate, output.EnergyShieldLeechInstances, output.EnergyShield, "EnergyShieldLeechRate", output.MaxEnergyShieldLeechRate, output.EnergyShieldLeechDuration, output.EnergyShieldLeechInstantProportion, hitRate)
		end
		if skillFlags.leechMana then
			breakdown.ManaLeech = breakdown.leech(output.ManaLeechInstant, output.ManaLeechInstantRate, output.ManaLeechInstances, output.Mana, "ManaLeechRate", output.MaxManaLeechRate, output.ManaLeechDuration, output.ManaLeechInstantProportion, hitRate)
		end
	end

	local ailmentData = data.nonDamagingAilment
	for _, ailment in ipairs(ailmentTypeList) do
		skillFlags[string.lower(ailment)] = false
	end
	skillFlags.impale = false

	-- Calculate ailment thresholds
	local enemyThreshold = data.monsterAilmentThresholdTable[env.enemyLevel] * calcLib.mod(enemyDB, nil, "EnemyAilmentThreshold")
	output['EnemyAilmentThreshold'] = enemyThreshold


	-- Calculate ailments and debuffs (poison, bleed, ignite, impale, exposure, etc)
	for _, pass in ipairs(passList) do
		globalOutput, globalBreakdown = output, breakdown
		local source = pass.source
		---@class Output
		local output = pass.output
		local cfg = pass.cfg
		---@class Breakdown
		local breakdown = pass.breakdown

		-- Legacy PoE1 ailments (to be removed later): Scorched, Brittle, Sapped, Impale
		output.ImpaleChance = 0
		output.ImpaleChanceOnCrit = 0
		output.ScorchChance = 0
		output.BrittleChance = 0
		output.SappedChance = 0
		output.ChaosPoisonChance = 0

		-- address Weapon1H interaction with Ailment for nodes like Coated Arms (PoE1: Sleight of Hand)
		-- bit.and on cfg.flags confirms if the skill has the 1H flag
		-- if so, bit.or on the targetCfg (e.g. dotCfg) to guarantee for calculations like Sum("INC") and breakdown
		local function checkWeapon1HFlags(targetCfg)
			targetCfg.flags = bor(targetCfg.flags, band(cfg.flags, ModFlag.Weapon1H))
		end

		-- Check if the skill can inflict a given ailment
		local function canDoAilment(ailmentType, damageType, defaultDamageTypes)
			if not canDeal[damageType] then
				return false
			end
			-- check against input valid types
			if ((defaultDamageTypes and defaultDamageTypes[damageType])
				or (ailmentData[ailmentType] and damageType == ailmentData[ailmentType].associatedType)) then
				if skillModList:Flag(cfg, damageType.."Cannot"..ailmentType) or skillModList:Flag(cfg, "Cannot"..ailmentType) then
					return false
				end
				return true
			end
			-- Process overrides eg. LightningCanFreeze
			if skillModList:Flag(cfg, damageType.."Can"..ailmentType) or skillModList:Flag(cfg, "Can"..ailmentType) then
				return true
			end
			return false
		end

		---Calculates normal and crit damage to be used in non-damaging ailment calculations
		---@param ailment string
		---@param defaultDamageTypes table
		---@return number, number average hit damage, average crit damage
		local function calcAverageUnmitigatedSourceDamage(ailment, defaultDamageTypes)
			local canCrit = not skillModList:Flag(cfg, "AilmentsAreNeverFromCrit")
			local sourceHitDmg, sourceCritDmg = 0, 0
			for _, dmg_type in ipairs(dmgTypeList) do
				if canDoAilment(ailment, dmg_type, defaultDamageTypes) then
					sourceHitDmg = sourceHitDmg + output[dmg_type.."HitAverage"]
					if canCrit then
						sourceCritDmg = sourceCritDmg + output[dmg_type.."CritAverage"]
					end
				end
			end
			return sourceHitDmg, sourceCritDmg
		end

		---Calculates damage to be used in damaging ailment calculations
		---@param ailment string
		---@param defaultDamageTypes table
		---@return number, number, number, number min / max hit, min / max crit damage
		local function calcMinMaxUnmitigatedAilmentSourceDamage(ailment, defaultDamageTypes)
			local canCrit = not skillModList:Flag(cfg, "AilmentsAreNeverFromCrit")
			local hitMin, hitMax = 0, 0
			local critMin, critMax = 0, 0
			for _, damageType in ipairs(dmgTypeList) do
				if canDoAilment(ailment, damageType, defaultDamageTypes) then
					local override = skillModList:Override(cfg, ailment .. damageType .. "HitDamage")
					local more = skillModList:More(cfg, damageType .. ailment .. "Buildup")
					local ailmentHitMin = override or output[damageType.."StoredHitMin"] or 0
					local ailmentHitMax = override or output[damageType.."StoredHitMax"] or 0
					hitMin = hitMin + ailmentHitMin * more
					hitMax = hitMax + ailmentHitMax * more
					output[ailment .. damageType .. "Min"] = ailmentHitMin * more
					output[ailment .. damageType .. "Max"] = ailmentHitMax * more
					if canCrit then
						override = skillModList:Override(cfg, ailment .. damageType .. "CritDamage")
						critMin = critMin + (override or output[damageType.."StoredCritMin"] or 0) * more
						critMax = critMax + (override or output[damageType.."StoredCritMax"] or 0) * more
					end
				end
			end
			return hitMin, hitMax, critMin, critMax
		end

		---Calculates damage to be used in poise related ailment calculations
		---@param ailment string
		---@param defaultDamageTypes table
		---@return number, number, number, number min / max / avg hit, min / max/ avg crit damage
		local function calcMinMaxPoiseSourceDamage(ailment, defaultDamageTypes)
			local canCrit = not skillModList:Flag(cfg, "AilmentsAreNeverFromCrit")
			local hitMin, hitMax, hitAvg = 0, 0, 0
			local critMin, critMax , critAvg = 0, 0, 0
			local poseDamageAvg = 0
			local critChance = output.CritChance
			for _, damageType in ipairs(dmgTypeList) do
				if canDoAilment(ailment, damageType, defaultDamageTypes) then
					local override = skillModList:Override(cfg, ailment .. damageType .. "HitDamage")
					local more = skillModList:More(cfg, damageType .. ailment .. "Buildup")
					local ailmentHitMin = override or output[damageType.."StoredHitMin"] or 0
					local ailmentHitMax = override or output[damageType.."StoredHitMax"] or 0
					local ailmentAverage = override or output[damageType.."HitAverage"] or 0
					local effMulti = output[damageType.."EffMult"] or 1
					hitMin = hitMin + ailmentHitMin * more * effMulti
					hitMax = hitMax + ailmentHitMax * more * effMulti
					hitAvg = hitAvg + ailmentAverage * more
					output[ailment .. damageType .. "Min"] = ailmentHitMin * more
					output[ailment .. damageType .. "Max"] = ailmentHitMax * more
					output[ailment .. damageType .. "Max"] = ailmentAverage * more
					if canCrit then
						override = skillModList:Override(cfg, ailment .. damageType .. "CritDamage")
						critMin = critMin + (override or output[damageType.."StoredCritMin"] or 0) * more * effMulti
						critMax = critMax + (override or output[damageType.."StoredCritMax"] or 0) * more * effMulti
						critAvg = critAvg + (override or output[damageType.."CritAverage"] or 0) * more
					end
				end
			end
			if canCrit then
				poseDamageAvg = hitAvg * (1 - critChance / 100) + critAvg * critChance / 100
			else
				poseDamageAvg = hitAvg
			end
			return hitMin, hitMax, hitAvg, critMin, critMax, critAvg, poseDamageAvg
		end

		---Calculate the inflict chance and base damage of a secondary effect (bleed/poison/ignite/shock/freeze)
		---@param ailment string
		---@param sourceCritChance number
		---@param sourceHitDmg number
		---@param sourceCritDmg number
		---@param hideFromBreakdown boolean?
		---@return number baseVal
		local function calcAilmentDamage(ailment, sourceCritChance, sourceHitDmg, sourceCritDmg, hideFromBreakdown)

			local chanceOnHit, chanceOnCrit = output[ailment.."ChanceOnHit"], output[ailment.."ChanceOnCrit"]
			-- Use sourceCritChance to factor in chance a critical ailment is present
			local chanceFromHit = chanceOnHit * (1 - sourceCritChance / 100)
			local chanceFromCrit = chanceOnCrit * sourceCritChance / 100
			local chance = chanceFromHit + chanceFromCrit
			output[ailment.."Chance"] = chance
			local baseFromHit = sourceHitDmg * chanceFromHit / (chanceFromHit + chanceFromCrit)
			local baseFromCrit = sourceCritDmg * chanceFromCrit / (chanceFromHit + chanceFromCrit)
			local baseVal = baseFromHit + baseFromCrit
			local sourceMult = skillModList:More(cfg, ailment.."AsThoughDealing")
			if breakdown and chance ~= 0 and not hideFromBreakdown then
				local breakdownChance = breakdown[ailment.."Chance"] or { }
				breakdown[ailment.."Chance"] = breakdownChance
				if breakdownChance[1] then
					t_insert(breakdownChance, "")
				end
				if isAttack then
					t_insert(breakdownChance, localisation:Term("attack_hand", pass.label)..":")
				end
				t_insert(breakdownChance, localisation:Text("calc.offence.calc_ailment_damage.line", { chance_on_hit = chanceOnHit }))
				t_insert(breakdownChance, localisation:Text("calc.offence.calc_ailment_damage.line_2", { chance_on_crit = chanceOnCrit }))
				if chanceOnHit ~= chanceOnCrit then
					t_insert(breakdownChance, localisation:Text("calc.offence.calc_ailment_damage.line_3"))
					t_insert(breakdownChance, localisation:Text("calc.offence.calc_ailment_damage.line_4", { chance_on_hit = chanceOnHit, value = sourceCritChance/100 }))
					t_insert(breakdownChance, localisation:Text("calc.offence.calc_ailment_damage.line_5", { chance_on_crit = chanceOnCrit, value = sourceCritChance/100 }))
					local chancePerHit = chanceOnHit * (1 - sourceCritChance / 100) + chanceOnCrit * sourceCritChance / 100
					t_insert(breakdownChance, s_format("= %.2f", chancePerHit))
				end
			end
			if breakdown and baseVal > 0 and not hideFromBreakdown then
				local breakdownDPS = breakdown[ailment.."DPS"] or { }
				breakdown[ailment.."DPS"] = breakdownDPS
				if breakdownDPS[1] then
					t_insert(breakdownDPS, "")
				end
				if isAttack then
					t_insert(breakdownDPS, localisation:Term("attack_hand", pass.label)..":")
				end
				if sourceHitDmg == sourceCritDmg or output.CritChance == 0 then
					t_insert(breakdownDPS, localisation:Text("calc.offence.calc_ailment_damage.line_6", { ailment = localisation:TermRef("ailment", ailment) }))
					t_insert(breakdownDPS, localisation:Text("calc.offence.calc_ailment_damage.line_7", { source_hit_dmg = sourceHitDmg }))
					if sourceMult > 1 then
						t_insert(breakdownDPS, localisation:Text("calc.offence.calc_ailment_damage.line_8", { source_mult = sourceMult }))
						t_insert(breakdownDPS, s_format("= %.1f", baseVal * sourceMult))
					end
				else
					if baseFromHit > 0 then
						t_insert(breakdownDPS, localisation:Text("calc.offence.calc_ailment_damage.line_9"))
						t_insert(breakdownDPS, localisation:Text("calc.offence.calc_ailment_damage.line_10", { source_hit_dmg = sourceHitDmg }))
						t_insert(breakdownDPS, localisation:Text("calc.offence.calc_ailment_damage.line_11", { value = chanceFromHit / (chanceFromHit + chanceFromCrit) }))
						if sourceMult == 1 or baseFromCrit ~= 0 then
							t_insert(breakdownDPS, s_format("= %.1f", baseFromHit))
						end
					end
					if baseFromCrit > 0 then
						t_insert(breakdownDPS, localisation:Text("calc.offence.calc_ailment_damage.line_12"))
						t_insert(breakdownDPS, localisation:Text("calc.offence.calc_ailment_damage.line_13", { source_crit_dmg = sourceCritDmg }))
						t_insert(breakdownDPS, localisation:Text("calc.offence.calc_ailment_damage.line_14", { value = chanceFromCrit / (chanceFromHit + chanceFromCrit) }))
						if sourceMult == 1 or baseFromHit ~= 0 then
							t_insert(breakdownDPS, s_format("= %.1f", baseFromCrit))
						end
					end
					if baseFromHit > 0 and baseFromCrit > 0 then
						t_insert(breakdownDPS, localisation:Text("calc.offence.calc_ailment_damage.line_6", { ailment = localisation:TermRef("ailment", ailment) }))
						t_insert(breakdownDPS, s_format("%.1f + %.1f", baseFromHit, baseFromCrit))
						if sourceMult == 1 then
							t_insert(breakdownDPS, s_format("= %.1f", baseVal))
						end
					end
					if sourceMult > 1 then
						t_insert(breakdownDPS, localisation:Text("calc.offence.calc_ailment_damage.line_8", { source_mult = sourceMult }))
						t_insert(breakdownDPS, s_format("= %.1f", baseVal * sourceMult))
					end
				end
			end
			return baseVal
		end

		local critMetatable = { __index = |_, key| -> skillCfg.skillCond[key] or cfg.skillCond[key] }
		---Calculate global / breakdown values for a damaging ailment
		---@param ailment string
		---@param ailmentDamageType table
		---@param defaultDamageTypes table
		local function calcDamagingAilmentOutputs(ailment, ailmentDamageType, defaultDamageTypes)

			if not canDeal[ailmentDamageType] then
				return
			end

			if (output[ailment .. "ChanceOnHit"] + output[ailment .. "ChanceOnCrit"] + (output[ailmentDamageType .. ailment .. "Chance"] or 0)) <= 0 then
				return
			end

			activeSkill[pass.label ~= "Off Hand" and (ailment:lower() .. "Cfg") or ("OH" .. ailment:lower() .. "Cfg")] = {
				skillName = skillCfg.skillName,
				skillPart = skillCfg.skillPart,
				skillTypes = skillCfg.skillTypes,
				summonSkillName = skillCfg.summonSkillName,
				slotName = skillCfg.slotName,
				flags = bor(ModFlag.Dot, ModFlag.Ailment, band(cfg.flags, ModFlag.WeaponMask), band(cfg.flags, ModFlag.Melee) ~= 0 and ModFlag.MeleeHit or 0),
				keywordFlags = bor(band(cfg.keywordFlags, bnot(KeywordFlag.Hit)), KeywordFlag[ailment], KeywordFlag.Ailment, KeywordFlag[ailmentDamageType .. "Dot"]),
				skillCond = setmetatable({ ["CriticalStrike"] = true },critMetatable ),
				skillDist = skillCfg.skillDist,
			}

			local dotCfg = pass.label ~= "Off Hand" and activeSkill[ailment:lower() .. "Cfg"] or activeSkill["OH" .. ailment:lower() .. "Cfg"]
			checkWeapon1HFlags(dotCfg)
			if breakdown then
				for _, damageType in ipairs(dmgTypeList) do
					breakdown[ailment .. damageType] = { damageTypes = { } }
				end
			end

			globalOutput[ailment .. "ChancePerHit"] = output[ailment .. "ChanceOnHit"] * (1 - output.CritChance / 100) + output[ailment .. "ChanceOnCrit"] * output.CritChance / 100

			-- We will be using a weighted average calculation
			local maxStacks = 1
			if skillModList:Flag(skillCfg, ailment .. "CanStack") then
				skillFlags[ailment:lower() .. "CanStack"] = true
				maxStacks = skillModList:Override(cfg, ailment .. "Stacks") or ((maxStacks + skillModList:Sum("BASE", cfg, ailment .. "Stacks")) * skillModList:More(cfg, ailment .. "Stacks"))
			end
			globalOutput[ailment .. "StacksMax"] = maxStacks

			-- The ailment duration
			local ailmentTypeMod
			if ailmentDamageType ~= "Physical" and ailmentDamageType ~= "Chaos" then
				ailmentTypeMod = "Elemental"
			else
				ailmentTypeMod = ailmentDamageType
			end
			local rateMod = (calcLib.mod(skillModList, cfg, ailment .. "Faster") + enemyDB:Sum("INC", nil, "Self" .. ailment .. "Faster") / 100)  / calcLib.mod(skillModList, cfg, ailment .. "Slower")
			local durationBase = skillData[ailment:lower() .. "DurationIsSkillDuration"] and skillData.duration or env.modDB:Override(nil, ailment .. "DurationBase") or data.misc[ailment .. "DurationBase"]
			local durationMod = m_max(calcLib.mod(skillModList, dotCfg, "Enemy" .. ailment .. "Duration", "EnemyAilmentDuration", "Enemy" .. ailmentTypeMod .. "AilmentDuration", "DamagingAilmentDuration", skillData[ailment:lower() .. "DurationIsSkillDuration"] and
				"Duration" or nil) * calcLib.mod(enemyDB, nil, "Self" .. ailment .. "Duration", "SelfAilmentDuration", "Self" .. ailmentTypeMod .. "AilmentDuration"), 0)
			durationMod = m_max(durationMod, 0)
			globalOutput[ailment .. "Duration"] = durationBase * durationMod / rateMod * debuffDurationMult

			-- The chance any given hit applies ailment
			local ailmentChance = output[ailment .. "ChanceOnHit"] / 100 * (1 - output.CritChance / 100) + output[ailment .. "ChanceOnCrit"] / 100 * output.CritChance / 100

			-- The average number of ailment that will be active on the enemy at once
			local ailmentStacks = output.HitChance / 100 * ailmentChance * output.DpsMultiplier
			local configStacks = enemyDB:Sum("BASE", nil, "Multiplier:" .. ailment .. "Stacks")
			if not skillData.triggeredOnDeath then
				if output.Cooldown then
					ailmentStacks = ailmentStacks * globalOutput[ailment .. "Duration"] / m_max(output.Cooldown, (output.HitTime or output.Time))
				elseif (globalOutput.HitSpeed or globalOutput.Speed) > 0 then
					-- assume skills with no cast, attack, or cooldown time are single cast
					ailmentStacks = ailmentStacks * globalOutput[ailment .. "Duration"] * (globalOutput.HitSpeed or globalOutput.Speed)
				end

				local activeTotems = env.modDB:Override(nil, "TotemsSummoned") or skillModList:Sum("BASE", skillCfg, "ActiveTotemLimit", "ActiveBallistaLimit")
				if skillFlags.totem then
					ailmentStacks = ailmentStacks * activeTotems
				end
				if configStacks > 0 then
					ailmentStacks = configStacks
				end
				if ailmentStacks <= 1 then
					skillModList:NewMod("Condition:Single" .. ailment, "FLAG", true, ailment:lower())
				end
			end

			-- Ratio of ailments applied : max effective ailments
			globalOutput[ailment .. "StackPotential"] = ailmentStacks / maxStacks
			globalOutput[ailment .. "StackPotentialPercent"] = globalOutput[ailment .. "StackPotential"] * 100
			if globalBreakdown then
				globalBreakdown[ailment .. "StackPotential"] = {
					localisation:Text("calc.offence.calc_damaging_ailment_outputs.line", { custom = colorCodes.CUSTOM }),
					s_format(""),
				}
				if configStacks > 0 then
					t_insert(globalBreakdown[ailment .. "StackPotential"], localisation:Text("calc.offence.calc_damaging_ailment_outputs.line_2", { config_stacks = configStacks }))
				else
					t_insert(globalBreakdown[ailment .. "StackPotential"], localisation:Text("calc.offence.calc_damaging_ailment_outputs.line_3", { value = output.HitChance / 100 }))
					t_insert(globalBreakdown[ailment .. "StackPotential"], localisation:Text("calc.offence.calc_damaging_ailment_outputs.line_4", { ailment_chance = ailmentChance }))
					if skillData.triggeredOnDeath then
						t_insert(globalBreakdown[ailment .. "StackPotential"], localisation:Text("calc.offence.calc_damaging_ailment_outputs.line_5"))
					elseif output.Cooldown then
						t_insert(globalBreakdown[ailment .. "StackPotential"], localisation:Text("calc.offence.calc_damaging_ailment_outputs.line_6", { value = globalOutput[ailment .. "Duration"], cooldown = output.Cooldown, value_2 = (output.HitTime or output.Time) }))
					elseif (globalOutput.HitSpeed or globalOutput.Speed) > 0 then
						t_insert(globalBreakdown[ailment .. "StackPotential"], localisation:Text("calc.offence.calc_damaging_ailment_outputs.line_7", { value = globalOutput[ailment .. "Duration"], value_2 = (globalOutput.HitTime or output.Time) }))
					end
					if output.DpsMultiplier ~= 1 then
						t_insert(globalBreakdown[ailment .. "StackPotential"], localisation:Text("calc.offence.calc_damaging_ailment_outputs.line_8", { dps_multiplier = output.DpsMultiplier }))
					end
				end
				t_insert(globalBreakdown[ailment .. "StackPotential"], localisation:Text("calc.offence.calc_damaging_ailment_outputs.line_9", { max_stacks = maxStacks }))
				t_insert(globalBreakdown[ailment .. "StackPotential"], s_format("= %.2f", globalOutput[ailment .. "StackPotential"]))
			end

			-- the amount of damage each application does as % maximum
			local ailmentRollAverage
			if globalOutput[ailment .. "StackPotential"] > 1 then
				-- shift damage towards top of range as only top applications apply
				ailmentRollAverage = (ailmentStacks - (maxStacks - 1)/2) / (ailmentStacks + 1) * 100
			else
				-- assume middle of range for hit damage
				ailmentRollAverage = 50
			end
			globalOutput[ailment .. "RollAverage"] = ailmentRollAverage

			if globalBreakdown then
				globalBreakdown[ailment .. "RollAverage"] = {
					localisation:Text("calc.offence.calc_damaging_ailment_outputs.line_10", { custom = colorCodes.CUSTOM }),
					localisation:Text("calc.offence.calc_damaging_ailment_outputs.line_11", { custom = colorCodes.CUSTOM }),
					localisation:Text("calc.offence.calc_damaging_ailment_outputs.line_12", { custom = colorCodes.CUSTOM, custom_2 = colorCodes.CUSTOM, ailment_roll_average = ailmentRollAverage }),
					s_format(""),
					localisation:Text("calc.offence.calc_damaging_ailment_outputs.line_13"),
				}
				if ailmentStacks >= maxStacks then
					t_insert(globalBreakdown[ailment .. "RollAverage"], s_format("%.2f - (%.2f - 1)/2", ailmentStacks, maxStacks))
					t_insert(globalBreakdown[ailment .. "RollAverage"], s_format("/ (%.2f + 1)", ailmentStacks))
					t_insert(globalBreakdown[ailment .. "RollAverage"], s_format("= %.2f%%", ailmentRollAverage))
				else
					t_insert(globalBreakdown[ailment .. "RollAverage"], localisation:Text("calc.offence.calc_damaging_ailment_outputs.line_14", { max_stacks = maxStacks }))
				end
			end

			local hitMin, hitMax, critMin, critMax = calcMinMaxUnmitigatedAilmentSourceDamage(ailment, defaultDamageTypes)
			local hitAvg = hitMin + ((hitMax - hitMin) * ailmentRollAverage / 100)
			local critAvg = critMin + ((critMax - critMin) * ailmentRollAverage / 100)
			if globalBreakdown then
				globalBreakdown[ailment .. "DPS"] = {
					localisation:Text("calc.offence.calc_damaging_ailment_outputs.line_15"),
					s_format("%.0f + (%.0f - %.0f) * %.2f%%", hitMin, hitMax, hitMin, ailmentRollAverage),
					localisation:Text("calc.offence.calc_damaging_ailment_outputs.line_16"),
					s_format("= %.2f", hitAvg),
				}
				if hitAvg ~= critAvg or output.CritChance > 0 then
					t_insert(globalBreakdown[ailment .. "DPS"], "")
					t_insert(globalBreakdown[ailment .. "DPS"], "Crit Dmg Derivation:")
					t_insert(globalBreakdown[ailment .. "DPS"], s_format("%.0f + (%.0f - %.0f) * %.2f%%", critMin, critMax, critMin, ailmentRollAverage))
					t_insert(globalBreakdown[ailment .. "DPS"], "^8min combined sources + (max combined sources - min combined sources) * average roll")
					t_insert(globalBreakdown[ailment .. "DPS"], s_format("= %.2f", critAvg))
				end
			end

			-- Over-stacking stacks increases the chance a critical is present
			local ailmentCritChance = 100 * (1 - m_pow(1 - output.CritChance / 100, m_max(globalOutput[ailment .. "StackPotential"], 1)))
			globalOutput[ailment .. "MagnitudeEffect"] = calcLib.mod(skillModList, dotCfg, "AilmentMagnitude")
			local ailmentPercentBase = data.misc[ailment .. "PercentBase"] * globalOutput[ailment .. "MagnitudeEffect"]
			local baseMinVal = calcAilmentDamage(ailment, ailmentCritChance, hitMin, 0, true) * ailmentPercentBase
			local baseMaxVal = calcAilmentDamage(ailment, 100, hitMax, critMax, true) * ailmentPercentBase
			local baseVal = calcAilmentDamage(ailment, ailmentCritChance, hitAvg, critAvg) * ailmentPercentBase

			if baseVal > 0 then
				skillFlags[ailment:lower()] = true
				local effMult = 1
				if env.mode_effective then
					if skillModList:Flag(cfg, ailment .. "ToChaos") then
						local resist = calcResistForType("Chaos", dotCfg)
						local takenInc = enemyDB:Sum("INC", dotCfg, "DamageTaken", "DamageTakenOverTime", "ChaosDamageTaken", "ChaosDamageTakenOverTime")
						local takenMore = enemyDB:More(dotCfg, "DamageTaken", "DamageTakenOverTime", "ChaosDamageTaken", "ChaosDamageTakenOverTime")
						effMult = (1 - resist / 100) * (1 + takenInc / 100) * takenMore
						globalOutput[ailment .. "EffMult"] = effMult
						if breakdown and effMult ~= 1 then
							local sourceRes = env.modDB:Flag(nil, "EnemyChaosResistEqualToYours") and "Your Chaos Resistance" or (env.partyMembers.modDB:Flag(nil, "EnemyChaosResistEqualToYours") and "Party Member Chaos Resistance" or "Chaos")
							globalBreakdown[ailment .. "EffMult"] = breakdown.effMult("Chaos", resist, 0, takenInc, effMult, takenMore, sourceRes, true)
						end
					elseif skillModList:Flag(cfg, ailment .. "ToFire") then
						local resist = calcResistForType("Fire", dotCfg)
						local takenInc = enemyDB:Sum("INC", dotCfg, "DamageTaken", "DamageTakenOverTime", "FireDamageTaken", "FireDamageTakenOverTime")
						local takenMore = enemyDB:More(dotCfg, "DamageTaken", "DamageTakenOverTime", "FireDamageTaken", "FireDamageTakenOverTime")
						effMult = (1 - resist / 100) * (1 + takenInc / 100) * takenMore
						globalOutput[ailment .. "EffMult"] = effMult
						if breakdown and effMult ~= 1 then
							local sourceRes = env.modDB:Flag(nil, "EnemyFireResistEqualToYours") and "Your Fire Resistance" or (env.partyMembers.modDB:Flag(nil, "EnemyFireResistEqualToYours") and "Party Member Fire Resistance" or "Fire")
							globalBreakdown[ailment .. "EffMult"] = breakdown.effMult("Fire", resist, 0, takenInc, effMult, takenMore, sourceRes, true)
						end
					else
						local resist = calcResistForType(ailmentDamageType, dotCfg)
						local elementalDamageTaken = isElemental[ailmentDamageType] and "ElementalDamageTaken" or nil
						local takenInc = enemyDB:Sum("INC", dotCfg, "DamageTaken", "DamageTakenOverTime", ailmentDamageType .. "DamageTaken", ailmentDamageType .. "DamageTakenOverTime", elementalDamageTaken)
						local takenMore = enemyDB:More(dotCfg, "DamageTaken", "DamageTakenOverTime", ailmentDamageType .. "DamageTaken", ailmentDamageType .. "DamageTakenOverTime", elementalDamageTaken)
						effMult = (1 - resist / 100) * (1 + takenInc / 100) * takenMore
						globalOutput[ailment .. "EffMult"] = effMult
						if breakdown and effMult ~= 1 then
							local sourceRes = env.modDB:Flag(nil, "Enemy" .. ailmentDamageType .."ResistEqualToYours") and "Your ".. ailmentDamageType .. " Resistance"
								or (env.partyMembers.modDB:Flag(nil, "Enemy" .. ailmentDamageType .."ResistEqualToYours") and "Party Member ".. ailmentDamageType .. " Resistance" or ailmentDamageType)
							globalBreakdown[ailment .. "EffMult"] = breakdown.effMult(ailmentDamageType, resist, 0, takenInc, effMult, takenMore, sourceRes, true)
						end
					end
				end

				local effectMod = calcLib.mod(skillModList, dotCfg, "AilmentEffect")
				local activeAilments = m_min(ailmentStacks, maxStacks)
				local ailmentDPSUncapped = baseVal * effectMod * rateMod * activeAilments * effMult
				local ailmentDPSCapped = m_min(ailmentDPSUncapped, data.misc.DotDpsCap)
				local minAilmentDPSUncapped = baseMinVal * effectMod * rateMod * activeAilments * effMult
				local minAilmentDPSCapped = m_min(minAilmentDPSUncapped, data.misc.DotDpsCap)
				local maxAilmentDPSUncapped = baseMaxVal * effectMod * rateMod * activeAilments * effMult
				local maxAilmentDPSCapped = m_min(maxAilmentDPSUncapped, data.misc.DotDpsCap)
				output[ailment .. "DPS"] = ailmentDPSCapped

				if ailment == "Ignite" then
					local groundMult = m_max(skillModList:Max(nil, "IgniteDpsAsBurningGround") or 0, enemyDB:Max(nil, "IgniteDpsAsBurningGround") or 0)
					if groundMult > 0 then
						local groundDPSUncapped = baseVal * effectMod * rateMod * effMult * groundMult / 100
						local groundDPSCapped = m_min(groundDPSUncapped, data.misc.DotDpsCap)
						globalOutput.BurningGroundDPS = groundDPSCapped
						globalOutput.BurningGroundFromIgnite = true
						if globalBreakdown then
							globalBreakdown.BurningGroundDPS = {
								localisation:Text("calc.offence.burning_ground_dps.line", { value = baseVal * effectMod * rateMod }),
								localisation:Text("calc.offence.burning_ground_dps.line_2", { ground_mult = groundMult }),
								localisation:Text("calc.offence.burning_ground_dps.line_3", { eff_mult = effMult }),
								localisation:Text("calc.offence.burning_ground_dps.line_4", { burning_ground_dps = globalOutput.BurningGroundDPS })
							}
						end
					end
				elseif ailment == "Poison" then
					local groundMult = m_max(skillModList:Max(nil, "PoisonDpsAsCausticGround") or 0, enemyDB:Max(nil, "PoisonDpsAsCausticGround") or 0)
					if groundMult > 0 then
						local groundDPSUncapped = baseVal * effectMod * rateMod * effMult * groundMult / 100
						local groundDPSCapped = m_min(groundDPSUncapped, data.misc.DotDpsCap)
						globalOutput.CausticGroundDPS = groundDPSCapped
						globalOutput.CausticGroundFromPoison = true
						if globalBreakdown then
							globalBreakdown.CausticGroundDPS = {
								localisation:Text("calc.offence.caustic_ground_dps.line", { value = baseVal * effectMod * rateMod }),
								localisation:Text("calc.offence.caustic_ground_dps.line_2", { ground_mult = groundMult }),
								localisation:Text("calc.offence.caustic_ground_dps.line_3", { eff_mult = effMult }),
								localisation:Text("calc.offence.caustic_ground_dps.line_4", { caustic_ground_dps = globalOutput.CausticGroundDPS })
							}
						end
					end
				end

				globalOutput[ailment .. "Damage"] = output[ailment .. "DPS"] * globalOutput[ailment .. "Duration"]
				if skillFlags[ailment:lower() .. "CanStack"] then
					output[ailment .. "Damage"] = output[ailment .. "DPS"] * globalOutput[ailment .. "Duration"]
					output[ailment .. "StacksMax"] = maxStacks
					output["Total" .. ailment .. "DPS"] = output[ailment .. "DPS"]
				end

				if breakdown then
					t_insert(breakdown[ailment .. "DPS"], localisation:Text("calc.offence.calc_damaging_ailment_outputs.line_17", { value = data.misc[ailment .. "PercentBase"], value_2 = data.misc[ailment .. "PercentBase"] * 100 }))
					t_insert(breakdown[ailment .. "DPS"], localisation:Text("calc.offence.calc_damaging_ailment_outputs.line_18", { value = globalOutput[ailment .. "MagnitudeEffect"] }))
					t_insert(breakdown[ailment .. "DPS"], s_format("= %.1f", baseVal, 1))
					t_insert(breakdown[ailment .. "DPS"], "")
					t_insert(breakdown[ailment .. "DPS"], localisation:Text("calc.offence.calc_damaging_ailment_outputs.line_19", { ailment = localisation:TermRef("ailment", ailment) }))
					if baseVal ~= ailmentDPSUncapped then
						t_insert(breakdown[ailment .. "DPS"], localisation:Text("calc.offence.calc_damaging_ailment_outputs.line_20", { base_val = baseVal }))
					end
					if effectMod ~= 1 then
						t_insert(breakdown[ailment .. "DPS"], localisation:Text("calc.offence.calc_damaging_ailment_outputs.line_21", { effect_mod = effectMod }))
					end
					if rateMod ~= 1 then
						t_insert(breakdown[ailment .. "DPS"], localisation:Text("calc.offence.calc_damaging_ailment_outputs.line_22", { rate_mod = rateMod }))
					end
					if activeAilments ~= 1 then
						t_insert(breakdown[ailment .. "DPS"], localisation:Text("calc.offence.calc_damaging_ailment_outputs.line_23", { active_ailments = activeAilments }))
					end
					if effMult ~= 1 then
						t_insert(breakdown[ailment .. "DPS"], localisation:Text("calc.offence.calc_damaging_ailment_outputs.line_24", { eff_mult = effMult }))
					end
					if output[ailment .. "DPS"] ~= ailmentDPSUncapped then
						t_insert(breakdown[ailment .. "DPS"], localisation:Text("calc.offence.calc_damaging_ailment_outputs.line_25", { ailment_dpsuncapped = ailmentDPSUncapped }))
						t_insert(breakdown[ailment .. "DPS"], localisation:Text("calc.offence.calc_damaging_ailment_outputs.line_26", { negative = colorCodes.NEGATIVE, value = ailmentDPSUncapped - ailmentDPSCapped, value_2 = (ailmentDPSUncapped - ailmentDPSCapped) / ailmentDPSCapped * 100 }))
						t_insert(breakdown[ailment .. "DPS"], localisation:Text("calc.offence.calc_damaging_ailment_outputs.line_27", { ailment_dpscapped = ailmentDPSCapped }))
					else
						t_insert(breakdown[ailment .. "DPS"], localisation:Text("calc.offence.calc_damaging_ailment_outputs.line_28", { value = output[ailment .. "DPS"] }))
					end
					t_insert(breakdown[ailment .. "DPS"], localisation:Text("calc.offence.calc_damaging_ailment_outputs.line_29", { value = output[ailment .. "DPS"] / maxAilmentDPSCapped * 100 }))
					t_insert(breakdown[ailment .. "DPS"], "")
					t_insert(breakdown[ailment .. "DPS"], localisation:Text("calc.offence.calc_damaging_ailment_outputs.line_30"))
					if maxAilmentDPSCapped == maxAilmentDPSUncapped and minAilmentDPSCapped == minAilmentDPSUncapped then
						t_insert(breakdown[ailment .. "DPS"], localisation:Text("calc.offence.calc_damaging_ailment_outputs.line_31", { min_ailment_dpsuncapped = minAilmentDPSUncapped, max_ailment_dpsuncapped = maxAilmentDPSUncapped }))
					else
						t_insert(breakdown[ailment .. "DPS"], localisation:Text("calc.offence.calc_damaging_ailment_outputs.line_32", { min_ailment_dpsuncapped = minAilmentDPSUncapped, max_ailment_dpsuncapped = maxAilmentDPSUncapped }))
					end
					if minAilmentDPSCapped ~= minAilmentDPSUncapped then
						t_insert(breakdown[ailment .. "DPS"], localisation:Text("calc.offence.calc_damaging_ailment_outputs.line_33", { negative = colorCodes.NEGATIVE, value = minAilmentDPSUncapped - minAilmentDPSCapped, value_2 = (minAilmentDPSUncapped - minAilmentDPSCapped) / minAilmentDPSCapped * 100 }))
					end
					if maxAilmentDPSCapped ~= maxAilmentDPSUncapped then
						t_insert(breakdown[ailment .. "DPS"], localisation:Text("calc.offence.calc_damaging_ailment_outputs.line_34", { negative = colorCodes.NEGATIVE, value = maxAilmentDPSUncapped - maxAilmentDPSCapped, value_2 = (maxAilmentDPSUncapped - maxAilmentDPSCapped) / maxAilmentDPSCapped * 100 }))
					end
					if maxAilmentDPSCapped ~= maxAilmentDPSUncapped or minAilmentDPSCapped ~= minAilmentDPSUncapped then
						t_insert(breakdown[ailment .. "DPS"], localisation:Text("calc.offence.calc_damaging_ailment_outputs.line_35", { min_ailment_dpscapped = minAilmentDPSCapped, max_ailment_dpscapped = maxAilmentDPSCapped }))
					end
					if skillFlags[ailment:lower() .. "CanStack"] then
						breakdown[ailment .. "Damage"] = { }
						if isAttack then
							t_insert(breakdown[ailment .. "Damage"], localisation:Term("attack_hand", pass.label)..":")
						end
						t_insert(breakdown[ailment .. "Damage"], localisation:Text("calc.offence.calc_damaging_ailment_outputs.line_36", { base_val = baseVal }))
						t_insert(breakdown[ailment .. "Damage"], localisation:Text("calc.offence.calc_damaging_ailment_outputs.line_37", { value = globalOutput[ailment .. "Duration"] }))
						t_insert(breakdown[ailment .. "Damage"], localisation:Text("calc.offence.calc_damaging_ailment_outputs.line_38", { value = output[ailment .. "Damage"] }))
					end
					if globalOutput[ailment .. "Duration"] ~= durationBase then
						globalBreakdown[ailment .. "Duration"] = {
							localisation:Text("calc.offence.calc_damaging_ailment_outputs.line_39", { duration_base = durationBase })
						}
						if durationMod ~= 1 then
							t_insert(globalBreakdown[ailment .. "Duration"], localisation:Text("calc.offence.calc_damaging_ailment_outputs.line_40", { duration_mod = durationMod }))
						end
						if rateMod ~= 1 then
							t_insert(globalBreakdown[ailment .. "Duration"], localisation:Text("calc.offence.calc_damaging_ailment_outputs.line_41", { rate_mod = rateMod }))
						end
						if debuffDurationMult ~= 1 then
							t_insert(globalBreakdown[ailment .. "Duration"], localisation:Text("calc.offence.calc_damaging_ailment_outputs.line_42", { value = 1 / debuffDurationMult }))
						end
						t_insert(globalBreakdown[ailment .. "Duration"], s_format("= %.2fs", globalOutput[ailment .. "Duration"]))
					end
				end
			end
		end

		-- Knockback (not sure why this is in ailment calc, but I'll calculate it anyway)
		output.KnockbackChanceOnHit = 0
		output.KnockbackChanceOnCrit = 0
		if skillModList:Flag(cfg, "Knockback") then -- From what I could see, all skills are 0% or 100%, with no enemy mitigation
			output.KnockbackChanceOnHit = 100
			output.KnockbackChanceOnCrit = 100
		end

		-- Calculate flat chance ailment (Poison, Bleed) chance on crit
		for _, flatAilment in ipairs({"Bleed", "Poison"}) do
			if not skillFlags.hit or skillModList:Flag(cfg, "Cannot"..flatAilment) then
				output[flatAilment.."ChanceOnHit"] = 0
				output[flatAilment.."ChanceOnCrit"] = 0
				skillFlags["inflict"..flatAilment] = false
			else
				for _, val in ipairs({"OnHit", "OnCrit"}) do
					local critCfg = copyTable(cfg,true)
					critCfg.skillCond.CriticalStrike = val == "OnCrit" -- force crit config to be true for "OnCrit" chance calculation
					local base = skillModList:Sum("BASE", critCfg, flatAilment.."Chance", "AilmentChance") + enemyDB:Sum("BASE", nil, "Self"..flatAilment.."Chance")
					local inc = skillModList:Sum("INC", critCfg, flatAilment.."Chance", "AilmentChance")
					local more = skillModList:More(critCfg, flatAilment.."Chance", "AilmentChance")
					local chance = m_min(100, skillModList:Override(critCfg, flatAilment .. "Chance") or (base * (1 + inc / 100) * more))
					output[flatAilment.."Chance" .. val] = chance
				end
				skillFlags["inflict"..flatAilment] = true
			end
		end

		local unmitigatedColdDamage = calcAverageUnmitigatedSourceDamage("Chill", data.defaultAilmentDamageTypes["Chill"]["ScalesFrom"])
		local chillMinimumThreshold = enemyThreshold / data.gameConstants.ChillEffectMultiplier
		output['chillMinimumThreshold'] = chillMinimumThreshold
		if unmitigatedColdDamage > chillMinimumThreshold then
			output["ChillChanceOnHit"] = 100
			output["ChillChanceOnCrit"] = 100
			skillFlags["inflictChill"] = true
		else
			output["ChillChanceOnHit"] = 0
			output["ChillChanceOnCrit"] = 0
			skillFlags["inflictChill"] = false
		end

		output["FreezeChanceOnHit"] = 0
		output["FreezeChanceOnCrit"] = 0
		skillFlags["inflictFreeze"] = false
		skillFlags["inflictElectrocute"] = false

		-- Calculate poise-related debuffs
		for _, ailment in ipairs({"Freeze", "Electrocute", "HeavyStun", "Pin"}) do
			local enemyPoiseThreshold = m_floor(data.monsterPoiseThresholdTable[env.enemyLevel] * calcLib.mod(enemyDB, nil, "PoiseThreshold", ailment.."Threshold", ailment == "HeavyStun" and "EnemyStunThreshold", (ailment == "Freeze" or ailment == "Electrocute") and "EnemyAilmentThreshold"))
			local hitMin, hitMax, hitAvg, critMin, critMax, critAvg, poiseAvg = calcMinMaxPoiseSourceDamage(ailment, data.buildupTypes[ailment].ScalesFrom)
			-- TODO: average for now, can do more complicated calculation later
			local inc = skillModList:Sum("INC", cfg, not skillModList:Flag(cfg, "PinBuildupInsteadOf"..ailment.."Buildup") and "Enemy"..ailment.."Buildup", "EnemyImmobilisationBuildup")
			local more = skillModList:More(cfg, "Enemy"..ailment.."Buildup", "EnemyImmobilisationBuildup") * calcLib.mod(enemyDB, nil, ailment.."Buildup", "ImmobilisationBuildup", ailment == "HeavyStun" and "StunBuildup")
			local poiseBuildup = data.gameConstants[ailment .. "DamageScale"] / enemyPoiseThreshold * (1 + inc / 100) * more * 100
			local minHit = hitMin * poiseBuildup
			local maxHit = hitMax * poiseBuildup
			local hitPoiseBuildup = hitAvg * poiseBuildup
			local minCrit = critMin * poiseBuildup
			local maxCrit = critMax * poiseBuildup
			local critPoiseBuildup = critAvg * poiseBuildup
			local totalAvgPoiseBuildup = poiseAvg * poiseBuildup

			if skillFlags.hit and not skillModList:Flag(cfg, "Cannot"..ailment) then
				globalOutput[ailment .. "BuildupAvg"] = totalAvgPoiseBuildup
			else
				globalOutput[ailment .. "BuildupAvg"] = 0
			end

			if breakdown then
				globalBreakdown[ailment .. "Buildup"] = {
					localisation:Text("calc.offence.offence.line_243", { enemy_level = env.enemyLevel, value = ((env.configInput.enemyLevel and localisation:Ref("calc.offence.offence.line.parameter_11")) or localisation:Ref("calc.offence.offence.line.parameter_12")) }),
					localisation:Text("calc.offence.offence.line_244", { enemy_poise_threshold = enemyPoiseThreshold }),
					"",
				}
				t_insert(globalBreakdown[ailment .. "Buildup"], localisation:Text("calc.offence.offence.line_245", { ailment = localisation:TermRef("ailment", ailment) }))
				t_insert(globalBreakdown[ailment .. "Buildup"], localisation:Text("calc.offence.offence.line_183", { min_hit = minHit }))
				t_insert(globalBreakdown[ailment .. "Buildup"], localisation:Text("calc.offence.offence.line_184", { max_hit = maxHit }))
				t_insert(globalBreakdown[ailment .. "Buildup"], localisation:Text("calc.offence.offence.line_185", { hit_poise_buildup = hitPoiseBuildup }))
				t_insert(globalBreakdown[ailment .. "Buildup"], s_format(""))
				t_insert(globalBreakdown[ailment .. "Buildup"], localisation:Text("calc.offence.offence.line_246", { ailment = localisation:TermRef("ailment", ailment) }))
				t_insert(globalBreakdown[ailment .. "Buildup"], localisation:Text("calc.offence.offence.line_186", { min_crit = minCrit }))
				t_insert(globalBreakdown[ailment .. "Buildup"], localisation:Text("calc.offence.offence.line_187", { max_crit = maxCrit }))
				t_insert(globalBreakdown[ailment .. "Buildup"], localisation:Text("calc.offence.offence.line_188", { crit_poise_buildup = critPoiseBuildup }))

				t_insert(globalBreakdown[ailment .. "Buildup"], s_format(""))
				t_insert(globalBreakdown[ailment .. "Buildup"], localisation:Text("calc.offence.offence.line_247", { ailment = localisation:TermRef("ailment", ailment) }))
				t_insert(globalBreakdown[ailment .. "Buildup"], s_format("= %.1f%%", totalAvgPoiseBuildup))
			end
		end


		-- Calculate scaling threshold ailment chance
		for _, ailment in ipairs({"Ignite", "Shock"}) do
			local hitMin, hitMax, critMin, critMax = calcMinMaxUnmitigatedAilmentSourceDamage(ailment, data.defaultAilmentDamageTypes[ailment]["ScalesFrom"])
			-- TODO: average for now, can do more complicated calculation later
			local hitAvg = hitMin + (hitMax - hitMin) / 2
			local critAvg = critMin + (critMax - critMin) / 2
			local base = skillModList:Sum("BASE", cfg, "Enemy"..ailment.."Chance", "AilmentChance") + enemyDB:Sum("BASE", nil, "Self"..ailment.."Chance")
			local inc = skillModList:Sum("INC", cfg, "Enemy"..ailment.."Chance", "AilmentChance") + enemyDB:Sum("INC", nil, "Self"..ailment.."Chance")
			local more = skillModList:More(cfg, "Enemy"..ailment.."Chance", "AilmentChance") * enemyDB:More(nil, "Self"..ailment.."Chance")
			local hitElementalAilmentChance = hitAvg / enemyThreshold * data.gameConstants[ailment .. "ChanceMultiplier"]
			hitElementalAilmentChance = (hitElementalAilmentChance + base) * (1 + inc / 100) * more
			local critElementalAilmentChance = critAvg / enemyThreshold * data.gameConstants[ailment .. "ChanceMultiplier"]
			critElementalAilmentChance = (critElementalAilmentChance + base) * (1 + inc / 100) * more

			if skillFlags.hit and not skillModList:Flag(cfg, "Cannot"..ailment) then
				output[ailment.."ChanceOnHit"] = m_min(100, hitElementalAilmentChance)
				output[ailment.."ChanceOnCrit"] = m_min(100, critElementalAilmentChance)
			else
				output[ailment.."ChanceOnHit"] = 0
				output[ailment.."ChanceOnCrit"] = 0
			end

			local anyChanceToAilment = output[ailment.."ChanceOnHit"] + (skillModList:Flag(cfg, "NeverCrit") and 0 or output[ailment.."ChanceOnCrit"])
			if anyChanceToAilment > 0 then
				skillFlags["inflict"..ailment] = true
			end
		end

		-- Apply elemental exposure from skill
		for _, element in ipairs({"Fire", "Cold", "Lightning"}) do
			if (skillModList:Sum("BASE", cfg, element.."ExposureChance") > 0) or skillModList:Flag(cfg, "InflictExposure") then
				skillFlags["apply"..element.."Exposure"] = true
			end
		end

		-- Apply user damage type config
		local ailmentMode = env.configInput.ailmentMode or "AVERAGE"
		if ailmentMode == "CRIT" then
			for _, ailment in ipairs(ailmentTypeList) do
				output[ailment.."ChanceOnHit"] = 0
			end
		end

		-- Calculate damaging ailment values
		for _, damagingAilment in ipairs({"Bleed", "Poison", "Ignite"}) do
			local damageType = data.defaultAilmentDamageTypes[damagingAilment]["DamageType"]
			if not canDeal[damageType] then
				for _, type in ipairs(dmgTypeList) do
					if skillModList:Flag(skillCfg, type.."Can"..damagingAilment) then -- e.g. Avatar of Fire + Blistering Bond -> DealNoPhysical + FireCanBleed
						calcDamagingAilmentOutputs(damagingAilment, type, data.defaultAilmentDamageTypes[damagingAilment]["ScalesFrom"])
					end
				end
			else
				calcDamagingAilmentOutputs(damagingAilment, damageType, data.defaultAilmentDamageTypes[damagingAilment]["ScalesFrom"])
			end
		end

		-- Calculate non-damaging ailments effect and duration modifiers
		local nonDamagingAilmentsConfig = {
			["Chill"] = {
				effList = { 10, 20 },
				effect = function(damage, effectMod) return data.gameConstants.ChillEffectMultiplier * (damage / enemyThreshold) * effectMod end,
				thresh = function(damage, value, effectMod) return damage * (data.gameConstants.ChillEffectMultiplier * effectMod / value) end,
				ramping = false,
			},
			["Shock"] = {
				effList = { 10, 20, 40 },
				effect = function(damage, effectMod) return 50 * ((damage / enemyThreshold) ^ 0.4) * effectMod end,
				thresh = function(damage, value, effectMod) return damage * ((50 * effectMod / value) ^ 2.5) end,
				ramping = true,
			},
		}
		if activeSkill.skillTypes[SkillType.ChillingArea] or activeSkill.skillTypes[SkillType.NonHitChill] then
			skillFlags.chill = true
			local incChill = skillModList:Sum("INC", cfg, "EnemyChillMagnitude", "AilmentMagnitude")
			local moreChill = skillModList:More(cfg, "EnemyChillMagnitude")
			output.ChillEffectMod = (1 + incChill / 100) * moreChill
			output.ChillDurationMod = 1 + skillModList:Sum("INC", cfg, "EnemyChillDuration", "EnemyAilmentDuration", "EnemyElementalAilmentDuration") / 100
			output.ChillSourceEffect = m_min(skillModList:Override(nil, "ChillMax") or ailmentData.Chill.max, m_floor(ailmentData.Chill.default * output.ChillEffectMod))
			if breakdown then
				breakdown.DotChill = { }
				breakdown.multiChain(breakdown.DotChill, {
					label = localisation:Text("calc.offence.offence.line_189", { value = (skillModList:Override(nil, "ChillMax") or ailmentData.Chill.max) }),
					base = localisation:Text("calc.offence.offence.line_190", { default = ailmentData.Chill.default }),
					{ "%.2f ^8(increased/reduced effect of chill)", 1 + incChill / 100, formatKey = "calc.offence.offence.factor_40", formatParams = { value = 2 } },
					{ "%.2f ^8(more/less effect of chill)", moreChill, formatKey = "calc.offence.offence.factor_41", formatParams = { more_chill = 2 } },
					total = s_format("= %.0f%%", output.ChillSourceEffect)
				})
			end
		end
		if (output.FreezeChanceOnHit + output.FreezeChanceOnCrit) > 0 then
			if globalBreakdown then
				globalBreakdown.FreezeDurationMod = {
					localisation:Text("calc.offence.freeze_duration_mod.line", { value = ((ailmentMode == "CRIT" and localisation:Ref("calc.offence.freeze_duration_mod.line.parameter")) or localisation:Ref("calc.offence.freeze_duration_mod.line.parameter_2")) })
				}
			end
			local baseVal = calcAilmentDamage("Freeze", output.CritChance, calcAverageUnmitigatedSourceDamage("Freeze", data.defaultAilmentDamageTypes["Freeze"]["ScalesFrom"])) * skillModList:More(cfg, "FreezeAsThoughDealing")
			if baseVal > 0 then
				skillFlags.freeze = true
				output.FreezeDurationMod = 1 + skillModList:Sum("INC", cfg, "EnemyFreezeDuration", "EnemyAilmentDuration", "EnemyElementalAilmentDuration") / 100 + enemyDB:Sum("INC", nil, "SelfFreezeDuration", "SelfElementalAilmentDuration", "SelfAilmentDuration", "HoarfrostFreezeDuration") / 100
				if breakdown then
					t_insert(breakdown.FreezeDPS, localisation:Text("calc.offence.offence.line_191", { value = baseVal * 20 * output.FreezeDurationMod }))
				end
			end
		end
		for ailment, val in pairs(nonDamagingAilmentsConfig) do
			if (output[ailment.."ChanceOnHit"] + output[ailment.."ChanceOnCrit"]) > 0 then
				if globalBreakdown then
					globalBreakdown[ailment.."EffectMod"] = {
						localisation:Text("calc.offence.offence.line_192", { value = ((ailmentMode == "CRIT" and localisation:Ref("calc.offence.offence.line.parameter_7")) or localisation:Ref("calc.offence.offence.line.parameter_8")) })
					}
				end
				local damage = calcAilmentDamage(ailment, output.CritChance, calcAverageUnmitigatedSourceDamage(ailment, data.defaultAilmentDamageTypes[ailment]["ScalesFrom"])) * skillModList:More(cfg, ailment.."AsThoughDealing")
				if damage > 0 then
					skillFlags[string.lower(ailment)] = true
					local incDur = skillModList:Sum("INC", cfg, "Enemy"..ailment.."Duration", "EnemyElementalAilmentDuration", "EnemyAilmentDuration") + enemyDB:Sum("INC", nil, "Self"..ailment.."Duration", "SelfElementalAilmentDuration", "SelfAilmentDuration")
					local moreDur = skillModList:More(cfg, "Enemy"..ailment.."Duration", "EnemyElementalAilmentDuration", "EnemyAilmentDuration") * enemyDB:More(nil, "Self"..ailment.."Duration", "SelfElementalAilmentDuration", "SelfAilmentDuration")
					output[ailment.."Duration"] = ailmentData[ailment].duration * (1 + incDur / 100) * moreDur * debuffDurationMult
					output[ailment.."EffectMod"] = calcLib.mod(skillModList, cfg, "Enemy"..ailment.."Magnitude", "AilmentMagnitude") * calcLib.mod(enemyDB, cfg, "Self"..ailment.."Magnitude", "AilmentMagnitude")
					if breakdown then
						local maximum = globalOutput["Maximum"..ailment] or ailmentData[ailment].max
						local current = m_max(m_min(globalOutput["Current"..ailment] or 0, maximum), 0)
						local desired = m_max(m_min(enemyDB:Sum("BASE", nil, "Desired"..ailment.."Val"), maximum), 0)
						if ailmentData[ailment].min ~= 0 then
							t_insert(val.effList, ailmentData[ailment].min)
						end
						if enemyThreshold > 0 then
							t_insert(val.effList, val.effect(damage, output[ailment.."EffectMod"]))
						end
						if not isValueInArray(val.effList, maximum) then
							t_insert(val.effList, maximum)
						end
						if current > 0 and not isValueInArray(val.effList, current) then
							t_insert(val.effList, current)
						end
						if desired > 0 and not isValueInArray(val.effList, desired) and current == 0 then
							t_insert(val.effList, desired)
						end
						breakdown[ailment.."DPS"].label = localisation:Text((current > 0 and val.ramping) and "calc.ailment.result_ramping" or "calc.ailment.result", (current > 0 and val.ramping) and { ramping = localisation:Ref("calc.offence.label.line", { current = current, ailment = localisation:TermRef("ailment", ailment) }) } or nil)
						breakdown[ailment.."DPS"].rowList = { }
						breakdown[ailment.."DPS"].colList = {
							{ label = "Ailment Threshold", labelKey = "ui.calc_offence.offence.thresh.label", key = "thresh" },
							{ label = ailment.." Effect", labelKey = "calc.ailment.effect_column", labelParams = { ailment = localisation:TermRef("ailment", ailment) }, key = "effect" },
						}
						table.sort(val.effList)
						for _, value in ipairs(val.effList) do
							local thresh = val.thresh(damage, value, output[ailment.."EffectMod"])
							local decCheck = value / m_floor(value)
							local precision = ailmentData[ailment].precision
							value = m_floor(value * (10 ^ precision)) / (10 ^ precision)
							local valueFormat = "%."..tostring(precision).."f%%"
							local threshString = s_format("%d", thresh)..(m_floor(thresh + 0.5) == m_floor(enemyThreshold + 0.5) and s_format(" ^8(%s)", env.configInput.enemyIsBoss) or "")
							local labels = { }
							if decCheck == 1 and value ~= 0 then
								if value == current then
									t_insert(labels, localisation:Text("calc.offence.offence.line_193"))
								end
								if value == desired then
									t_insert(labels, localisation:Text("calc.offence.offence.line_194"))
								end
								if value == maximum then
									t_insert(labels, localisation:Text("calc.offence.offence.line_195"))
								end
								if value == ailmentData[ailment].min then
									t_insert(labels, localisation:Text("calc.offence.offence.line_196"))
								end
							end
							t_insert(breakdown[ailment.."DPS"].rowList, {
								effect = s_format(valueFormat, value)..(next(labels) ~= nil and " ^8("..table.concat(labels, ", ")..")" or ""),
								thresh = threshString,
							})
						end
					end
					if breakdown and output[ailment.."Duration"] ~= ailmentData[ailment].duration then
						breakdown[ailment.."Duration"] = { }
						if isAttack then
							t_insert(breakdown[ailment.."Duration"], localisation:Term("attack_hand", pass.label)..":")
						end
						t_insert(breakdown[ailment.."Duration"], localisation:Text("calc.offence.offence.line_197", { duration = ailmentData[ailment].duration }))
						if incDur ~= 0 then
							t_insert(breakdown[ailment.."Duration"], localisation:Text("calc.offence.offence.line_198", { value = 1 + incDur / 100 }))
						end
						if moreDur ~= 1 then
							t_insert(breakdown[ailment.."Duration"], localisation:Text("calc.offence.offence.line_199", { more_dur = moreDur }))
						end
						if debuffDurationMult ~= 1 then
							t_insert(breakdown[ailment.."Duration"], localisation:Text("calc.offence.offence.line_200", { value = 1 / debuffDurationMult }))
						end
						t_insert(breakdown[ailment.."Duration"], s_format("= %.2fs", output[ailment.."Duration"]))
					end
				end
			end
		end

		-- Calculate knockback chance/distance
		output.KnockbackChance = m_min(100, output.KnockbackChanceOnHit * (1 - output.CritChance / 100) + output.KnockbackChanceOnCrit * output.CritChance / 100 + enemyDB:Sum("BASE", nil, "SelfKnockbackChance"))
		if output.KnockbackChance > 0 then
			output.KnockbackDistance = round(4 * calcLib.mod(skillModList, cfg, "EnemyKnockbackDistance"))
			if breakdown then
				breakdown.KnockbackDistance = {
					radius = output.KnockbackDistance,
				}
			end
		end

		-- Calculate enemy stun modifiers
		local enemyStunThresholdRed = -skillModList:Sum("INC", cfg, "EnemyStunThreshold")
		if enemyStunThresholdRed > 75 then
			output.EnemyStunThresholdMod = 1 - (75 + (enemyStunThresholdRed - 75) * 25 / (enemyStunThresholdRed - 50)) / 100
		else
			output.EnemyStunThresholdMod = 1 - enemyStunThresholdRed / 100
		end
		local base = skillData.baseStunDuration or 0.35
		local incDur = skillModList:Sum("INC", cfg, "EnemyStunDuration")
		local incDurCrit = skillModList:Sum("INC", cfg, "EnemyStunDurationOnCrit")
		local moreDur = skillModList:More(cfg, "EnemyStunDuration")
		local chanceToDouble = m_min(skillModList:Sum("BASE", cfg, "DoubleEnemyStunDurationChance") + enemyDB:Sum("BASE", cfg, "SelfDoubleStunDurationChance"), 100)
		local incRecov = enemyDB:Sum("INC", nil, "StunRecovery")
		local minimumStunDuration = base * moreDur / (1 + incRecov / 100)
		local maximumStunDuration = minimumStunDuration
		output.EnemyStunDuration = minimumStunDuration
		if incDurCrit ~= 0 and output.CritChance ~= 0 then
			if output.CritChance == 100 then
				minimumStunDuration = minimumStunDuration * (1 + (incDur + incDurCrit) / 100)
				maximumStunDuration = minimumStunDuration
				output.EnemyStunDuration = minimumStunDuration
			else
				minimumStunDuration = minimumStunDuration * (1 + incDur / 100)
				maximumStunDuration = maximumStunDuration * (1 + (incDur + incDurCrit) / 100)
				output.EnemyStunDuration = output.EnemyStunDuration * (1 + (incDur + incDurCrit * output.CritChance / 100) / 100)
			end
		else
			minimumStunDuration = minimumStunDuration * (1 + incDur / 100)
			maximumStunDuration = minimumStunDuration
			output.EnemyStunDuration = minimumStunDuration
		end
		if chanceToDouble ~= 0 then
			if chanceToDouble == 100 then
				minimumStunDuration = minimumStunDuration * 2
			end
			maximumStunDuration = maximumStunDuration * 2
			output.EnemyStunDuration = output.EnemyStunDuration * (1 + chanceToDouble / 100)
		end
		if breakdown then
			if output.EnemyStunDuration ~= base then
				breakdown.EnemyStunDuration = {
					localisation:Text("calc.offence.enemy_stun_duration.line", { base = base }),
				}
				if incDur ~= 0 or (incDurCrit ~= 0 and output.CritChance ~= 0) then
					t_insert(breakdown.EnemyStunDuration, localisation:Text("calc.offence.offence.line_201", { value = 1 + (incDur + incDurCrit * output.CritChance / 100) / 100 }))
				end
				if moreDur ~= 1 then
					t_insert(breakdown.EnemyStunDuration, localisation:Text("calc.offence.offence.line_202", { more_dur = moreDur }))
				end
				if chanceToDouble ~= 0 then
					t_insert(breakdown.EnemyStunDuration, localisation:Text("calc.offence.offence.line_203", { value = 1 + chanceToDouble / 100 }))
				end
				if incRecov ~= 0 then
					t_insert(breakdown.EnemyStunDuration, localisation:Text("calc.offence.offence.line_204", { value = 1 + incRecov / 100 }))
				end
				t_insert(breakdown.EnemyStunDuration, s_format("= %.2fs", output.EnemyStunDuration))
				if minimumStunDuration ~= maximumStunDuration then
					t_insert(breakdown.EnemyStunDuration, localisation:Text("calc.offence.offence.line_205", { minimum_stun_duration = minimumStunDuration, maximum_stun_duration = maximumStunDuration }))
				end
				local enemyActionSpeed = calcs.actionSpeedMod(actor.enemy)
				if enemyActionSpeed ~= 1 then
					t_insert(breakdown.EnemyStunDuration, localisation:Text("calc.offence.offence.line_206", { enemy_action_speed = enemyActionSpeed }))
					t_insert(breakdown.EnemyStunDuration, localisation:Text("calc.offence.offence.line_207", { value = output.EnemyStunDuration / enemyActionSpeed }))
					if minimumStunDuration ~= maximumStunDuration then
						t_insert(breakdown.EnemyStunDuration, localisation:Text("calc.offence.offence.line_208", { value = minimumStunDuration / enemyActionSpeed, value_2 = maximumStunDuration / enemyActionSpeed }))
					end
				end
			end
		end

		-- Calculate impale chance and modifiers
		if canDeal.Physical and (output.ImpaleChance + output.ImpaleChanceOnCrit) > 0 then
			skillFlags.impale = true
			local critChance = output.CritChance / 100
			local impaleChance =  (m_min(output.ImpaleChance/100, 1) * (1 - critChance) + m_min(output.ImpaleChanceOnCrit/100, 1) * critChance)
			local maxStacks = skillModList:Sum("BASE", cfg, "ImpaleStacksMax") * (1 + skillModList:Sum("BASE", cfg, "ImpaleAdditionalDurationChance") / 100)
			local configStacks = enemyDB:Sum("BASE", cfg, "Multiplier:ImpaleStacks")
			local impaleStacks = m_min(maxStacks, configStacks)

			local baseStoredDamage = data.misc.ImpaleStoredDamageBase
			local storedExpectedDamageIncOnBleed = skillModList:Sum("INC", cfg, "ImpaleEffectOnBleed")*skillModList:Sum("BASE", cfg, "BleedChance")/100
			local storedExpectedDamageInc = (skillModList:Sum("INC", cfg, "ImpaleEffect") + storedExpectedDamageIncOnBleed)/100
			local storedExpectedDamageMore = round(skillModList:More(cfg, "ImpaleEffect"), 2)
			local storedExpectedDamageModifier = (1 + storedExpectedDamageInc) * storedExpectedDamageMore
			local impaleStoredDamage = baseStoredDamage * storedExpectedDamageModifier
			local impaleHitDamageMod = impaleStoredDamage * impaleStacks  -- Source: https://www.reddit.com/r/pathofexile/comments/chgqqt/impale_and_armor_interaction/

			local enemyArmour = m_max(calcLib.val(enemyDB, "Armour"), 0)
			local impaleArmourReduction = calcs.armourReductionF(enemyArmour, impaleHitDamageMod * output.PhysicalStoredCombinedAvg)
			local impaleResist = m_min(m_max(0, enemyDB:Sum("BASE", nil, "PhysicalDamageReduction") + skillModList:Sum("BASE", cfg, "EnemyImpalePhysicalDamageReduction") + impaleArmourReduction), data.misc.EnemyPhysicalDamageReductionCap)
			if skillModList:Flag(cfg, "IgnoreEnemyImpalePhysicalDamageReduction") then
				impaleResist = 0
			end
			local impaleTakenCfg = { flags = ModFlag.Hit }
			local impaleTaken = (1 + enemyDB:Sum("INC", impaleTakenCfg, "DamageTaken", "PhysicalDamageTaken", "ReflectedDamageTaken") / 100)
								* enemyDB:More(impaleTakenCfg, "DamageTaken", "PhysicalDamageTaken", "ReflectedDamageTaken")
			local impaleDMGModifier = impaleHitDamageMod * (1 - impaleResist / 100) * impaleChance * impaleTaken

			globalOutput.ImpaleStacksMax = maxStacks
			globalOutput.ImpaleStacks = impaleStacks
			--ImpaleStoredDamage should be named ImpaleEffect or similar
			--Using the variable name ImpaleEffect breaks the calculations sidebar (?!)
			output.ImpaleStoredDamage = impaleStoredDamage * 100
			output.ImpaleModifier = 1 + impaleDMGModifier

			if breakdown then
				breakdown.ImpaleStoredDamage = {}
				t_insert(breakdown.ImpaleStoredDamage, localisation:Text("calc.offence.offence.line_209"))
				t_insert(breakdown.ImpaleStoredDamage, localisation:Text("calc.offence.offence.line_210", { stored_expected_damage_modifier = storedExpectedDamageModifier }))
				t_insert(breakdown.ImpaleStoredDamage, s_format("= %.1f%%", output.ImpaleStoredDamage))

				breakdown.ImpaleModifier = {}
				t_insert(breakdown.ImpaleModifier, localisation:Text("calc.offence.offence.line_211", { impale_stacks = impaleStacks }))
				t_insert(breakdown.ImpaleModifier, localisation:Text("calc.offence.offence.line_212", { impale_stored_damage = impaleStoredDamage }))
				t_insert(breakdown.ImpaleModifier, localisation:Text("calc.offence.offence.line_213", { impale_chance = impaleChance }))
				t_insert(breakdown.ImpaleModifier, localisation:Text("calc.offence.offence.line_214", { value = 1 - impaleResist / 100 }))
				if impaleTaken ~= 1 then
					t_insert(breakdown.ImpaleModifier, localisation:Text("calc.offence.offence.line_215", { impale_taken = impaleTaken }))
				end
				t_insert(breakdown.ImpaleModifier, localisation:Text("calc.offence.offence.line_216", { impale_dmgmodifier = impaleDMGModifier }))
			end
		end
	end

	-- Combine secondary effect stats
	if isAttack then
		for _, ailment in ipairs({"Bleed", "Poison", "Ignite"}) do
			combineStat(ailment.."Chance", "AVERAGE")
			combineStat(ailment.."DPS", "CHANCE_AILMENT", ailment.."Chance")
			if skillFlags[ailment:lower() .. "CanStack"] then
				combineStat(ailment.."Damage", "CHANCE", ailment.."Chance")
				combineStat("Total"..ailment.."DPS", "DPS")
				combineStat(ailment .. "StacksMax", "DPS")
			end
		end

		combineStat("ChillEffectMod", "AVERAGE")
		combineStat("ChillDuration", "AVERAGE")
		combineStat("ShockChance", "AVERAGE")
		combineStat("ShockDuration", "AVERAGE")
		combineStat("ShockEffectMod", "AVERAGE")
		combineStat("FreezeChance", "AVERAGE")
		combineStat("FreezeDurationMod", "AVERAGE")
		combineStat("ImpaleChance", "AVERAGE")
		combineStat("ImpaleStoredDamage", "AVERAGE")
		combineStat("ImpaleModifier", "CHANCE", "ImpaleChance")
	end

	if skillData.decay and canDeal.Chaos then
		-- Calculate DPS for Decay effect
		skillFlags.decay = true
		activeSkill.decayCfg = {
			skillName = skillCfg.skillName,
			skillPart = skillCfg.skillPart,
			skillTypes = skillCfg.skillTypes,
			summonSkillName = skillCfg.summonSkillName,
			slotName = skillCfg.slotName,
			flags = ModFlag.Dot,
			keywordFlags = bor(band(skillCfg.keywordFlags, bnot(KeywordFlag.Hit)), KeywordFlag.ChaosDot),
		}
		local dotCfg = activeSkill.decayCfg
		local effMult = 1
		if env.mode_effective then
			local resist = calcResistForType("Chaos", dotCfg)
			local takenInc = enemyDB:Sum("INC", nil, "DamageTaken", "DamageTakenOverTime", "ChaosDamageTaken", "ChaosDamageTakenOverTime")
			local takenMore = enemyDB:More(nil, "DamageTaken", "DamageTakenOverTime", "ChaosDamageTaken", "ChaosDamageTakenOverTime")
			effMult = (1 - resist / 100) * (1 + takenInc / 100) * takenMore
			output["DecayEffMult"] = effMult
			if breakdown and effMult ~= 1 then
				local sourceRes = env.modDB:Flag(nil, "EnemyChaosResistEqualToYours") and "Your Chaos Resistance" or (env.partyMembers.modDB:Flag(nil, "EnemyChaosResistEqualToYours") and "Party Member Chaos Resistance" or "Chaos")
				breakdown.DecayEffMult = breakdown.effMult("Chaos", resist, 0, takenInc, effMult, takenMore, sourceRes, true)
			end
		end
		local inc = skillModList:Sum("INC", dotCfg, "Damage", "ChaosDamage")
		local more = skillModList:More(dotCfg, "Damage", "ChaosDamage")
		local mult = skillModList:Override(dotTypeCfg, "DotMultiplier") or skillModList:Sum("BASE", dotTypeCfg, "DotMultiplier") + skillModList:Sum("BASE", dotTypeCfg, "ChaosDotMultiplier")
		output.DecayDPS = skillData.decay * (1 + inc/100) * more * (1 + mult/100) * effMult
		output.DecayDuration = 8 * debuffDurationMult
		if breakdown then
			breakdown.DecayDPS = { }
			breakdown.dot(breakdown.DecayDPS, skillData.decay, inc, more, mult, nil, nil, effMult, output.DecayDPS)
			if output.DecayDuration ~= 8 then
				breakdown.DecayDuration = {
					localisation:Text("calc.offence.decay_duration.line", { value = 8 })
				}
				if debuffDurationMult ~= 1 then
					t_insert(breakdown.DecayDuration, localisation:Text("calc.offence.offence.line_200", { value = 1 / debuffDurationMult }))
				end
				t_insert(breakdown.DecayDuration, s_format("= %.2fs", output.DecayDuration))
			end
		end
	end

	local baseDropsBurningGround = modDB:Sum("BASE", nil, "DropsBurningGround")
	if baseDropsBurningGround > 0 then
		if canDeal.Fire then
			local dotCfg = {
				flags = bor(ModFlag.Dot),
				keywordFlags = 0
			}
			local dotTakenCfg = copyTable(dotCfg, true)
			local dotTypeCfg = copyTable(dotCfg, true)
			dotTypeCfg.keywordFlags = bor(dotTypeCfg.keywordFlags, KeywordFlag.FireDot)
			local effMult = 1
			if env.mode_effective then
				local resist = calcResistForType("Fire", dotTypeCfg)
				local takenInc = enemyDB:Sum("INC", dotTakenCfg, "DamageTaken", "DamageTakenOverTime", "FireDamageTaken", "FireDamageTakenOverTime", "ElementalDamageTaken")
				local takenMore = enemyDB:More(dotTakenCfg, "DamageTaken", "DamageTakenOverTime", "FireDamageTaken", "FireDamageTakenOverTime", "ElementalDamageTaken")
				effMult = (1 - resist / 100) * (1 + takenInc / 100) * takenMore
			end
			local inc = modDB:Sum("INC", dotTypeCfg, "Damage", "FireDamage", "ElementalDamage")
			local more = modDB:More(dotTypeCfg, "Damage", "FireDamage", "ElementalDamage")
			local mult = modDB:Override(dotTypeCfg, "DotMultiplier") or modDB:Sum("BASE", dotTypeCfg, "DotMultiplier") + modDB:Sum("BASE", dotTypeCfg, "FireDotMultiplier")
			local total = baseDropsBurningGround * (1 + inc/100) * more * (1 + mult/100) * effMult
			if not output.BurningGroundDPS or output.BurningGroundDPS < total then
				output.BurningGroundDPS = total
				output.BurningGroundFromIgnite = false
			end
		end
	end

	-- Calculate skill DOT components
	local dotCfg = {
		skillName = skillCfg.skillName,
		skillPart = skillCfg.skillPart,
		skillTypes = skillCfg.skillTypes,
		summonSkillName = skillCfg.summonSkillName,
		slotName = skillCfg.slotName,
		flags = bor(ModFlag.Dot, skillCfg.flags),
		keywordFlags = band(skillCfg.keywordFlags, bnot(KeywordFlag.Hit)),
	}
	if bor(dotCfg.flags, ModFlag.Area) == dotCfg.flags and not skillData.dotIsArea then
		dotCfg.flags = band(dotCfg.flags, bnot(ModFlag.Area))
	end
	if bor(dotCfg.flags, ModFlag.Projectile) == dotCfg.flags and not skillData.dotIsProjectile then
		dotCfg.flags = band(dotCfg.flags, bnot(ModFlag.Projectile))
	end
	if bor(dotCfg.flags, ModFlag.Spell) == dotCfg.flags and not skillData.dotIsSpell then
		dotCfg.flags = band(dotCfg.flags, bnot(ModFlag.Spell))
	end
	if bor(dotCfg.flags, ModFlag.Attack) == dotCfg.flags and not skillData.dotIsAttack then
		dotCfg.flags = band(dotCfg.flags, bnot(ModFlag.Attack))
	end
	if bor(dotCfg.flags, ModFlag.Hit) == dotCfg.flags and not skillData.dotIsHit then
		dotCfg.flags = band(dotCfg.flags, bnot(ModFlag.Hit))
	end

	-- spell_damage_modifiers_apply_to_skill_dot does not apply to enemy damage taken
	local dotTakenCfg = copyTable(dotCfg, true)
	if (skillData.dotIsSpell) then
		dotTakenCfg.flags = band(dotTakenCfg.flags, bnot(ModFlag.Spell))
	end

	activeSkill.dotCfg = dotCfg
	output.TotalDotInstance = 0

	runSkillFunc("preDotFunc")

	---Section Handles Generic Damage over time [DOT]
	for _, damageType in ipairs(dmgTypeList) do
		local dotTypeCfg = copyTable(dotCfg, true)
		dotTypeCfg.keywordFlags = bor(dotTypeCfg.keywordFlags, KeywordFlag[damageType.."Dot"])
		activeSkill["dot"..damageType.."Cfg"] = dotTypeCfg
		local baseVal
		if canDeal[damageType] then
			baseVal = skillData[damageType.."Dot"] or 0
		else
			baseVal = 0
		end
		if baseVal > 0 or (output[damageType.."Dot"] or 0) > 0 then
			skillFlags.dot = true
			local effMult = 1
			--Section handles Enemy Damage Taken based on Configs
			if env.mode_effective then
				local resist = 0
				local takenInc = enemyDB:Sum("INC", dotTakenCfg, "DamageTaken", "DamageTakenOverTime", damageType.."DamageTaken", damageType.."DamageTakenOverTime") + (isElemental[damageType] and enemyDB:Sum("INC", dotTakenCfg, "ElementalDamageTaken") or 0)
				local takenMore = enemyDB:More(dotTakenCfg, "DamageTaken", "DamageTakenOverTime", damageType.."DamageTaken", damageType.."DamageTakenOverTime") * (isElemental[damageType] and enemyDB:More(dotTakenCfg, "ElementalDamageTaken") or 1)
				if damageType == "Physical" then
					resist = m_max(0, m_min(enemyDB:Sum("BASE", nil, "PhysicalDamageReduction"), data.misc.EnemyPhysicalDamageReductionCap))
				else
					resist = calcResistForType(damageType, dotTypeCfg)
				end
				effMult = (1 - resist / 100) * (1 + takenInc / 100) * takenMore
				output[damageType.."DotEffMult"] = effMult
				if breakdown and effMult ~= 1 then
					local sourceRes = env.modDB:Flag(nil, "Enemy"..damageType.."ResistEqualToYours") and "Your "..damageType.." Resistance" or (env.partyMembers.modDB:Flag(nil, "Enemy"..damageType.."ResistEqualToYours") and "Party Member "..damageType.." Resistance" or damageType)
					breakdown[damageType.."DotEffMult"] = breakdown.effMult(damageType, resist, 0, takenInc, effMult, takenMore, sourceRes, true)
				end
			end
			--Variables below calculate DOT damage
			local inc = skillModList:Sum("INC", dotTypeCfg, "Damage", damageType.."Damage", isElemental[damageType] and "ElementalDamage" or nil)
			if skillModList:Flag(nil, "dotIsHeraldOfAsh") then
				inc = inc - skillModList:Sum("INC", skillCfg, "Damage", damageType.."Damage", isElemental[damageType] and "ElementalDamage" or nil)
			end
			local more = skillModList:More(dotTypeCfg, "Damage", damageType.."Damage", isElemental[damageType] and "ElementalDamage" or nil)
			local mult = skillModList:Override(dotTypeCfg, "DotMultiplier") or skillModList:Sum("BASE", dotTypeCfg, "DotMultiplier") + skillModList:Sum("BASE", dotTypeCfg, damageType.."DotMultiplier")
			local aura = activeSkill.skillTypes[SkillType.Aura] and not activeSkill.skillTypes[SkillType.RemoteMined] and calcLib.mod(skillModList, dotTypeCfg, "AuraEffect") * calcLib.mod(skillModList, skillCfg, "Magnitude")
			local total = baseVal * (1 + inc/100) * more * (1 + mult/100) * (aura or 1) * effMult
			if output[damageType.."Dot"] == 0 or not output[damageType.."Dot"] then
				output[damageType.."Dot"] = total
				output.TotalDotInstance = m_min(output.TotalDotInstance + total, data.misc.DotDpsCap)
			else
				output.TotalDotInstance = m_min(output.TotalDotInstance + total + (output[damageType.."Dot"] or 0), data.misc.DotDpsCap)
			end
			if breakdown then
				breakdown[damageType.."Dot"] = { }
				breakdown.dot(breakdown[damageType.."Dot"], baseVal, inc, more, mult, nil, aura, effMult, total)
			end
		end
	end

	if skillModList:Flag(nil, "DotCanStack") then
		skillFlags.DotCanStack = true
		local speed = output.Speed
		-- Check if skill is being triggered via Mine (e.g., Blastchain Mine Support) or Trap
		-- if "yes", you cannot use output.Speed but rather should use output.MineLayingSpeed or output.TrapThrowingSpeed
		if band(dotCfg.keywordFlags, KeywordFlag.Mine) ~= 0 then
			speed = output.MineLayingSpeed
		elseif band(dotCfg.keywordFlags, KeywordFlag.Trap) ~= 0 then
			speed = output.TrapThrowingSpeed
		end
		output.TotalDot = m_min(output.TotalDotInstance * speed * output.Duration * output.DpsMultiplier * quantityMultiplier, data.misc.DotDpsCap)
		output.TotalDotCalcSection = output.TotalDot
		if breakdown then
			breakdown.TotalDot = {
				localisation:Text("calc.offence.total_dot.line", { total_dot_instance = output.TotalDotInstance }),
				localisation:Text("calc.offence.total_dot.line_2", { speed = speed }),
				localisation:Text("calc.offence.total_dot.line_3", { duration = output.Duration }),
			}
			if output.DpsMultiplier ~= 1 then
				t_insert(breakdown.TotalDot, localisation:Text("calc.offence.offence.line_181", { dps_multiplier = output.DpsMultiplier }))
			end
			if quantityMultiplier > 1 then
				t_insert(breakdown.TotalDot, localisation:Text("calc.offence.offence.line_182", { quantity_multiplier = quantityMultiplier }))
			end
			t_insert(breakdown.TotalDot, s_format("= %.1f", output.TotalDot))
		end
	elseif skillModList:Flag(nil, "dotIsBurningGround") then
		output.TotalDot = 0
		output.TotalDotCalcSection = output.TotalDotInstance
		if not output.BurningGroundDPS or output.BurningGroundDPS < output.TotalDotInstance then
			output.BurningGroundDPS = m_max(output.BurningGroundDPS or 0, output.TotalDotInstance)
			output.BurningGroundFromIgnite = false
		end
	elseif skillModList:Flag(nil, "dotIsCausticGround") then
		output.TotalDot = 0
		output.TotalDotCalcSection = output.TotalDotInstance
		if not output.CausticGroundDPS or output.CausticGroundDPS < output.TotalDotInstance then
			output.CausticGroundDPS = m_max(output.CausticGroundDPS or 0, output.TotalDotInstance)
			output.CausticGroundFromPoison = false
		end
	elseif skillModList:Flag(nil, "dotIsCorruptingBlood") then
		output.TotalDot = 0
		output.TotalDotCalcSection = output.TotalDotInstance
		if not output.CorruptingBloodDPS or output.CorruptingBloodDPS < output.TotalDotInstance then
			output.CorruptingBloodDPS = m_max(output.CorruptingBloodDPS or 0, output.TotalDotInstance)
		end
	else
		if skillModList:Flag(nil, "DotCanStackAsTotems") and skillFlags.totem then
			skillFlags.DotCanStack = true
		end
		output.TotalDot = output.TotalDotInstance
		output.TotalDotCalcSection = output.TotalDotInstance
	end

	--Calculates and displays cost per second for skills that don't already have one (link skills)
	for _, resource in ipairs(costs.order) do
		local val = costs[resource]
		local EB = env.modDB:Flag(nil, "EnergyShieldProtectsMana")
		if(val.upfront and output[resource.."HasCost"] and output[resource.."Cost"] > 0 and not (output[resource.."PerSecondHasCost"] and not (EB and skillModList:Sum("BASE", skillCfg, "ManaCostAsEnergyShieldCost"))) and (output.Speed > 0 or output.Cooldown)) then
			local usedResource = resource

			if EB and resource == "Mana" then
				usedResource = "ES"
			end

			local repeats = output.Repeats or 1
			local useSpeed = 1
			local timeType
			if skillFlags.trap or skillFlags.mine then
				local preSpeed = output.TrapThrowingSpeed or output.MineLayingSpeed
				local cooldown = output.TrapCooldown or output.Cooldown
				useSpeed = (cooldown and cooldown > 0 and 1 / cooldown or preSpeed)
				timeType = skillFlags.trap and localisation:Text("calc.action_time.trap") or localisation:Text("calc.action_time.mine")
			elseif skillFlags.totem then
				useSpeed = (output.Cooldown and output.Cooldown > 0 and (output.TotemPlacementSpeed > 0 and output.TotemPlacementSpeed or 1 / output.Cooldown) or output.TotemPlacementSpeed) / repeats
				timeType = localisation:Text("calc.action_time.totem")
			elseif skillModList:Flag(nil, "HasSeals") and skillModList:Flag(nil, "DamageSeal") and skillModList:Flag(nil, "UseMaxUnleash") then
				useSpeed = env.player.mainSkill.skillData.hitTimeOverride / repeats
				timeType = localisation:Text("calc.action_time.unleash")
			elseif output.EffectiveReloadTime then -- Crossbows: Account for mana cost only happening on reload (once all bolts are fired)
				useSpeed = (not output.EffectiveBoltCount) and 0 or (1 / (output.TotalFiringTime + output.EffectiveReloadTime))
				timeType = localisation:Text("calc.action_time.reload")
			else
				useSpeed = (output.Cooldown and output.Cooldown > 0 and (output.Speed > 0 and output.Speed or 1 / output.Cooldown) or output.Speed) / repeats
				timeType = skillData.triggered and localisation:Text("calc.action_time.trigger") or (skillFlags.totem and localisation:Text("calc.action_time.totem") or skillFlags.attack and localisation:Text("calc.action_time.attack") or localisation:Text("calc.action_time.cast"))
			end

			output[usedResource.."PerSecondHasCost"] = true
			output[usedResource.."PerSecondCost"] = (output[usedResource.."PerSecondCost"] or 0)+ output[resource.."Cost"] * useSpeed

			if breakdown then
				breakdown[usedResource.."PerSecondCost"] = copyTable(breakdown[resource.."Cost"])
				t_remove(breakdown[usedResource.."PerSecondCost"])
				t_insert(breakdown[usedResource.."PerSecondCost"], localisation:Text("calc.offence.offence.line_248", { time_type = timeType, use_speed = useSpeed }))
				t_insert(breakdown[usedResource.."PerSecondCost"], localisation:Text("calc.offence.offence.line_217", { value = output[usedResource.."PerSecondCost"] }))
			end
		end
	end

	-- Self hit dmg calcs
	do
		for _, sourceFunc in pairs(selfHitHandlers) do
			local selfHitBreakdown, dmgTaken = sourceFunc(activeSkill, output, breakdown)
			if dmgTaken then
				output.SelfHitDamage = (output.SelfHitDamage or 0) + dmgTaken
			end
			if breakdown and selfHitBreakdown then
				breakdown.SelfHitDamage = breakdown.SelfHitDamage or {}
				for _, line in ipairs(selfHitBreakdown) do
					t_insert(breakdown.SelfHitDamage, line)
				end
				t_insert(breakdown.SelfHitDamage, "")
			end
		end

		-- Special handling for self hit skills
		-- These need to be handled higher up in this file using runFuncs for correct DPS calcs
		for selfHitSkill, displayName in ipairs({["FRDamageTaken"] = "Forbidden Rite"}) do
			if output[selfHitSkill] then
				output.SelfHitDamage = (output.SelfHitDamage or 0) + output[selfHitSkill]
			end
			if breakdown and breakdown[selfHitSkill] then
				breakdown.SelfHitDamage = breakdown.SelfHitDamage or {}
				for _, line in ipairs(breakdown[selfHitSkill]) do
					t_insert(breakdown.SelfHitDamage, line)
				end
				t_insert(breakdown.SelfHitDamage, "")
			end
		end

		if breakdown and breakdown.SelfHitDamage then
			breakdown.SelfHitDamage[#breakdown.SelfHitDamage] = nil -- Remove new line at the end
		end
	end

	-- Calculate combined DPS estimate, including DoTs
	local baseDPS = output[(skillData.showAverage and "AverageDamage") or "TotalDPS"]
	output.CombinedDPS = baseDPS
	output.CombinedAvg = baseDPS
	if skillFlags.dot then
		output.WithDotDPS = baseDPS + (output.TotalDot or 0)
	end

	for _, ailment in ipairs({"Bleed", "Poison", "Ignite"}) do
		if skillFlags[ailment:lower()] then
			if skillFlags[ailment:lower() .. "CanStack"] then
				if skillData.showAverage then
					output.CombinedAvg = output.CombinedDPS + output[ailment .. "Damage"]
				else
					output["With" .. ailment .. "DPS"] = baseDPS + output["Total" .. ailment .. "DPS"]
				end
			elseif skillData.showAverage then
				output["With" .. ailment .. "DPS"] = baseDPS + output[ailment .. "Damage"]
				output.CombinedAvg = output.CombinedAvg + output[ailment .. "Damage"]
			else
				output["With" .. ailment .. "DPS"] = baseDPS + output[ailment .. "DPS"]
			end
		else
			output["With" .. ailment .. "DPS"] = baseDPS
		end
	end
	if skillFlags.monsterExplode then
		output.CombinedAvgToMonsterLife = output.CombinedAvg / monsterLife * 100
	end
	-- Parry Stats
	-- NOTE: This section is mainly for skill-specific breakdowns. Actual application of damage modifier is handled in `CalcPerform`
	local parryDebuffMagnitudeMod = calcLib.mod(skillModList, skillCfg, "ParryDebuffMagnitude")
	if skillData.parryDebuffBaseMagnitude and parryDebuffMagnitudeMod and parryDebuffMagnitudeMod ~= 1 then
		output.ParryDebuffMagnitudeMod = parryDebuffMagnitudeMod
		if breakdown then
			local inc = skillModList:Sum("INC", skillCfg, "ParryDebuffMagnitude")
			local more = skillModList:More(skillCfg, "ParryDebuffMagnitude") * calcLib.mod(skillModList, skillCfg, "DebuffEffect")
			breakdown.ParryDebuffMagnitudeMod = {
				localisation:Text("calc.offence.parry_debuff_magnitude_mod.line"),
				s_format(""),
				localisation:Text("calc.offence.parry_debuff_magnitude_mod.line_2", { value = 1 + inc / 100 }),
				localisation:Text("calc.offence.parry_debuff_magnitude_mod.line_3", { value = more + 1 }),
				s_format("= %.2f", parryDebuffMagnitudeMod),
				s_format(""),
				localisation:Text("calc.offence.parry_debuff_magnitude_mod.line_4"),
				localisation:Text("calc.offence.parry_debuff_magnitude_mod.line_5", { parry_debuff_base_magnitude = skillData.parryDebuffBaseMagnitude }),
				s_format("x %.2f", parryDebuffMagnitudeMod),
				localisation:Text("calc.offence.parry_debuff_magnitude_mod.line_6", { value = skillData.parryDebuffBaseMagnitude * parryDebuffMagnitudeMod }),
				localisation:Text("calc.offence.parry_debuff_magnitude_mod.line_7"),
			}
		end
	end
	if skillData.parryDebuffDuration and skillData.parryDebuffDuration > 0 then
		local expirationMult = calcBuffExpirationMult(enemyDB, skillCfg)
		--skillModList:NewMod("ParryDebuffDuration", "BASE", skillData.parryDebuffDuration, "Base value from skill")
		output.ParryDebuffDuration = skillData.parryDebuffDuration * calcLib.mod(skillModList, skillCfg, "ParryDebuffDuration") * (expirationMult or 0)
		if breakdown then
			breakdown.ParryDebuffDuration = {
				localisation:Text("calc.offence.parry_debuff_duration.line"),
				s_format(""),
				localisation:Text("calc.offence.parry_debuff_duration.line_2", { parry_debuff_duration = skillData.parryDebuffDuration }),
				localisation:Text("calc.offence.parry_debuff_duration.line_3", { value = calcLib.mod(skillModList, skillCfg, "ParryDebuffDuration") }),
			}
			if expirationMult and expirationMult ~= 1 then
				t_insert(breakdown.ParryDebuffDuration, localisation:Text("calc.offence.offence.line_218", { expiration_mult = expirationMult }))
			end
			t_insert(breakdown.ParryDebuffDuration, s_format("= %.2fs", output.ParryDebuffDuration))
		end
	end
	if skillData.parryRangeNonProj or skillData.parryRangeProj then
		output.ParryRangeNonProj = (skillData.parryRangeNonProj or 0) * calcLib.mod(skillModList, skillCfg, "ParryRangeNonProj")
		output.ParryRangeProj = (skillData.parryRangeProj or 0) * calcLib.mod(skillModList, skillCfg, "ParryRangeProj")
		if breakdown then
			if output.ParryRangeNonProj > 0 then
				breakdown.ParryRangeNonProj = {
					localisation:Text("calc.offence.parry_range_non_proj.line"),
					s_format(""),
					localisation:Text("calc.offence.parry_range_non_proj.line_2", { parry_range_non_proj = skillData.parryRangeNonProj }),
					localisation:Text("calc.offence.parry_range_non_proj.line_3", { value = calcLib.mod(skillModList, skillCfg, "ParryRangeNonProj") }),
					s_format("= %.1f m", output.ParryRangeNonProj),
				}
			end
			if output.ParryRangeProj > 0 then
				breakdown.ParryRangeProj = {
					localisation:Text("calc.offence.parry_range_proj.line"),
					s_format(""),
					localisation:Text("calc.offence.parry_range_proj.line_2", { parry_range_proj = skillData.parryRangeProj }),
					localisation:Text("calc.offence.parry_range_proj.line_3", { value = calcLib.mod(skillModList, skillCfg, "ParryRangeProj") }),
					s_format("= %.1f m", output.ParryRangeProj),
				}
			end
		end
	end
	if skillFlags.impale then
		local mainHandImpaleDPS, offHandImpaleDPS
		if skillFlags.attack and skillData.combinesHitsWhenDualWielding and skillFlags.bothWeaponAttack then
			-- separately combine
			mainHandImpaleDPS = output.MainHand.impaleStoredHitAvg * ((output.MainHand.ImpaleModifier or 1) - 1) * output.MainHand.HitChance / 100 * output.DpsMultiplier
			offHandImpaleDPS = output.OffHand.impaleStoredHitAvg * ((output.OffHand.ImpaleModifier or 1) - 1) * output.OffHand.HitChance / 100 * output.DpsMultiplier
			output.ImpaleDPS = mainHandImpaleDPS + offHandImpaleDPS
		else
			output.ImpaleDPS = output.PhysicalStoredCombinedAvg * ((output.ImpaleModifier or 1) - 1) * output.HitChance / 100 * output.DpsMultiplier
		end
		if skillData.showAverage then
			output.WithImpaleDPS = output.AverageDamage + output.ImpaleDPS
			output.CombinedAvg = output.CombinedAvg + output.ImpaleDPS
		else
			skillFlags.notAverage = true
			output.ImpaleDPS = output.ImpaleDPS * (output.HitSpeed or output.Speed)
			output.WithImpaleDPS = output.TotalDPS + output.ImpaleDPS
		end
		if quantityMultiplier > 1 then
			output.ImpaleDPS = output.ImpaleDPS * quantityMultiplier
		end
		output.CombinedDPS = output.CombinedDPS + output.ImpaleDPS
		if breakdown then
			breakdown.ImpaleDPS = {}
			if skillFlags.attack and skillData.combinesHitsWhenDualWielding and skillFlags.bothWeaponAttack then
				t_insert(breakdown.ImpaleDPS, localisation:Text("calc.offence.offence.line_219"))
				t_insert(breakdown.ImpaleDPS, localisation:Text("calc.offence.offence.line_220", { impale_stored_hit_avg = output.MainHand.impaleStoredHitAvg }))
				t_insert(breakdown.ImpaleDPS, localisation:Text("calc.offence.offence.line_221", { value = output.MainHand.HitChance / 100 }))
				t_insert(breakdown.ImpaleDPS, localisation:Text("calc.offence.offence.line_222", { value = (output.MainHand.ImpaleModifier or 1) - 1 }))
				t_insert(breakdown.ImpaleDPS, s_format("= %.2f", mainHandImpaleDPS))
				t_insert(breakdown.ImpaleDPS, localisation:Text("calc.offence.offence.line_223"))
				t_insert(breakdown.ImpaleDPS, localisation:Text("calc.offence.offence.line_224", { impale_stored_hit_avg = output.OffHand.impaleStoredHitAvg }))
				t_insert(breakdown.ImpaleDPS, localisation:Text("calc.offence.offence.line_225", { value = output.OffHand.HitChance / 100 }))
				t_insert(breakdown.ImpaleDPS, localisation:Text("calc.offence.offence.line_226", { value = (output.OffHand.ImpaleModifier or 1) - 1 }))
				t_insert(breakdown.ImpaleDPS, s_format("= %.2f", offHandImpaleDPS))
				t_insert(breakdown.ImpaleDPS, localisation:Text("calc.offence.offence.line_227"))
				t_insert(breakdown.ImpaleDPS, s_format("%.2f + %.2f", mainHandImpaleDPS, offHandImpaleDPS))
			else
				t_insert(breakdown.ImpaleDPS, localisation:Text("calc.offence.offence.line_228", { physical_stored_combined_avg = output.PhysicalStoredCombinedAvg }))
				t_insert(breakdown.ImpaleDPS, localisation:Text("calc.offence.offence.line_152", { value = output.HitChance / 100 }))
				t_insert(breakdown.ImpaleDPS, localisation:Text("calc.offence.offence.line_229", { value = (output.ImpaleModifier or 1) - 1 }))
			end
		if skillFlags.notAverage then
			t_insert(breakdown.ImpaleDPS, output.HitSpeed and localisation:Text("calc.offence.offence.line_230", { hit_speed = output.HitSpeed }) or localisation:Text("calc.offence.offence.line_231", { speed = output.Speed, value = ((skillFlags.attack and localisation:Ref("calc.offence.offence.line.parameter_9")) or localisation:Ref("calc.offence.offence.line.parameter_10")) }))
		end
		if output.DpsMultiplier ~= 1 then
			t_insert(breakdown.ImpaleDPS, localisation:Text("calc.offence.offence.line_232", { dps_multiplier = output.DpsMultiplier }))
		end
		if quantityMultiplier > 1 then
			t_insert(breakdown.ImpaleDPS, localisation:Text("calc.offence.offence.line_182", { quantity_multiplier = quantityMultiplier }))
		end
		t_insert(breakdown.ImpaleDPS, s_format("= %.1f", output.ImpaleDPS))
		end
	end

	local bestCull = 1
	if activeSkill.mirage and activeSkill.mirage.output and activeSkill.mirage.output.TotalDPS then
		local mirageCount = activeSkill.mirage.count or 1
		output.MirageDPS = activeSkill.mirage.output.TotalDPS * mirageCount
		output.CombinedDPS = output.CombinedDPS + activeSkill.mirage.output.TotalDPS * mirageCount
		output.MirageBurningGroundDPS = activeSkill.mirage.output.BurningGroundDPS
		output.MirageCausticGroundDPS = activeSkill.mirage.output.CausticGroundDPS

		if activeSkill.mirage.output.IgniteDPS and activeSkill.mirage.output.IgniteDPS > (output.IgniteDPS or 0) then
			output.MirageDPS = output.MirageDPS + activeSkill.mirage.output.IgniteDPS
			output.IgniteDPS = 0
		end
		if activeSkill.mirage.output.BleedDPS and activeSkill.mirage.output.BleedDPS > (output.BleedDPS or 0) then
			output.MirageDPS = output.MirageDPS + activeSkill.mirage.output.BleedDPS
			output.BleedDPS = 0
		end

		if activeSkill.mirage.output.PoisonDPS then
			output.MirageDPS = output.MirageDPS + activeSkill.mirage.output.PoisonDPS * mirageCount
			output.CombinedDPS = output.CombinedDPS + activeSkill.mirage.output.PoisonDPS * mirageCount
		end
		if activeSkill.mirage.output.ImpaleDPS then
			output.MirageDPS = output.MirageDPS + activeSkill.mirage.output.ImpaleDPS * mirageCount
			output.CombinedDPS = output.CombinedDPS + activeSkill.mirage.output.ImpaleDPS * mirageCount
		end
		if activeSkill.mirage.output.DecayDPS then
			output.MirageDPS = output.MirageDPS + activeSkill.mirage.output.DecayDPS
			output.CombinedDPS = output.CombinedDPS + activeSkill.mirage.output.DecayDPS
		end
		if activeSkill.mirage.output.TotalDot and (skillFlags.DotCanStack or not output.TotalDot or output.TotalDot == 0) then
			output.MirageDPS = output.MirageDPS + activeSkill.mirage.output.TotalDot * (skillFlags.DotCanStack and mirageCount or 1)
			output.CombinedDPS = output.CombinedDPS + activeSkill.mirage.output.TotalDot * (skillFlags.DotCanStack and mirageCount or 1)
		end
		if activeSkill.mirage.output.CullMultiplier > 1 then
			bestCull = activeSkill.mirage.output.CullMultiplier
		end
	end

	local TotalDotDPS = (output.TotalDot or 0)
		+ (output.TotalPoisonDPS or output.PoisonDPS or 0)
		+ (m_max(output.CausticGroundDPS or 0, output.MirageCausticGroundDPS or 0 ))
		+ (output.TotalIgniteDPS or output.IgniteDPS or 0)
		+ (m_max(output.BurningGroundDPS or 0, output.MirageBurningGroundDPS or 0))
		+ (output.TotalBleedDPS or output.BleedDPS or 0)
		+ (output.CorruptingBloodDPS or 0)
		+ (output.DecayDPS or 0)

	output.TotalDotDPS = m_min(TotalDotDPS, data.misc.DotDpsCap)
	if output.TotalDotDPS ~= TotalDotDPS then
		output.showTotalDotDPS = true
	end
	if not skillData.showAverage then
		output.CombinedDPS = output.CombinedDPS + output.TotalDotDPS
	end

	bestCull = m_max(bestCull, output.CullMultiplier)
	output.CullingDPS = output.CombinedDPS * (bestCull - 1)
	output.ReservationDPS = output.CombinedDPS * (output.ReservationDpsMultiplier - 1)
	output.CombinedDPS = output.CombinedDPS * bestCull * output.ReservationDpsMultiplier
end
