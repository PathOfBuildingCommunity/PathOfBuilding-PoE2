-- Path of Building
--
-- Module: Calc Defence
-- Performs defence calculations.
--
local calcs = ...

local pairs = pairs
local ipairs = ipairs
local t_insert = table.insert
local m_min = math.min
local m_max = math.max
local m_floor = math.floor
local m_ceil = math.ceil
local m_sqrt = math.sqrt
local m_modf = math.modf
local m_huge = math.huge
local s_format = string.format

local tempTable1 = { }

local isElemental = { Fire = true, Cold = true, Lightning = true }

-- List of all damage types, ordered according to the conversion sequence
local hitSourceList = {"Attack", "Spell"}
local dmgTypeList = {"Physical", "Lightning", "Cold", "Fire", "Chaos"}

local resistTypeList = { "Fire", "Cold", "Lightning", "Chaos" }

-- Calculate hit chance
function calcs.hitChance(evasion, accuracy, uncapped)
	if accuracy < 0 then
		return 5
	end
	local rawChance = ( accuracy * 1.5 ) / ( accuracy + evasion ) * 100
	return uncapped and m_max(round(rawChance), 5) or m_max(m_min(round(rawChance), 100), 5)	
end
-- Calculate damage reduction from armour, float
function calcs.armourReductionF(armour, raw)
	if armour == 0 and raw == 0 then
		return 0
	elseif armour < 0 then -- account for Armour break below zero
		armour = -armour -- revert value to positive for calculation
		return -((armour / (armour + raw * data.misc.ArmourRatio) * 100))
	end
	return (armour / (armour + raw * data.misc.ArmourRatio) * 100)
end

-- Calculate damage reduction from armour, int
function calcs.armourReduction(armour, raw)
	return round(calcs.armourReductionF(armour, raw))
end

-- Calculate life/mana/spirit pools
---@param actor table
function calcs.doActorLifeManaSpirit(actor, skipBreakdown)
	local modDB = actor.modDB
	local output = actor.output
	local breakdown = (not skipBreakdown) and actor.breakdown
	local condList = modDB.conditions

	local lowLifePerc = modDB:Sum("BASE", nil, "LowLifePercentage")
	output.LowLifePercentage = 100.0 * (lowLifePerc > 0 and lowLifePerc or data.misc.LowPoolThreshold)
	local fullLifePerc = modDB:Sum("BASE", nil, "FullLifePercentage")
	output.FullLifePercentage = 100.0 * (fullLifePerc > 0 and fullLifePerc or 1.0)

	output.ChaosInoculation = modDB:Flag(nil, "ChaosInoculation")

	for _, res in ipairs({ "Life", "Mana", "Spirit" }) do
		local base = modDB:Sum("BASE", nil, res)
		local extra = modDB:Sum("BASE", nil, "Extra" .. res)
		local inc = modDB:Sum("INC", nil, res)
		local more = modDB:More(nil, res)
		local conv = m_min(modDB:Sum("BASE", nil, res .. "ConvertToEnergyShield", res .. "ConvertToArmour", res .. "ConvertToEvasion"), 100)
		local override = modDB:Override(nil, res)
		output[res.."HasOverride"] = override ~= nil
		output[res] = override or m_max(round((base * (1 - conv/100) + extra) * (1 + inc/100) * more), 1)
		if breakdown then
			if inc ~= 0 or more ~= 1 or conv ~= 0 or extra ~= 0 then
				breakdown[res][1] = s_format("%g ^8(base)", base)
				if conv ~= 0 then
					t_insert(breakdown[res], s_format("x %.2f ^8(converted from)", 1 - conv/100))
				end
				if extra ~= 0 then
					t_insert(breakdown[res], s_format("+ %g ^8(converted to)", extra))
				end
				if conv ~= 0 or extra ~= 0 then
					t_insert(breakdown[res], s_format("= %g", round(base * (1 - conv/100) + extra)))
				end
				if inc ~= 0 then
					t_insert(breakdown[res], s_format("x %.2f ^8(increased/reduced)", 1 + inc/100))
				end
				if more ~= 1 then
					t_insert(breakdown[res], s_format("x %.2f ^8(more/less)", more))
				end
				if inc ~= 0 or more ~= 1 then
					t_insert(breakdown[res], s_format("= %g", output[res]))
				end
			end
		end
	end
	if output.ChaosInoculation then
		output.Life = 1
		condList["FullLife"] = true
	end
	output.LowestOfMaximumLifeAndMaximumMana = m_min(output.Life, output.Mana)
end


-- Calculate Darkness and Darkness Reservation
---@param actor table
function calcs.doActorDarkness(actor)
	local modDB = actor.modDB
	local output = actor.output
	local condList = modDB.conditions
	local inc = modDB:Sum("INC", nil, "Darkness")
	local base = modDB:Sum("BASE", nil, "Darkness")
	output.Darkness = base * (1+inc/100)

	local reserved = modDB:Sum("BASE", nil, "ReservedDarkness")
	output.ReservedDarkness = m_min(reserved, output.Darkness)
	output.UnreservedDarkness = output.Darkness - output.ReservedDarkness
end

-- Return the gem count of the specified skill and it's enabled status
---@param activeSkill table
function calcs.getActiveSkillCount(activeSkill)
	if not activeSkill.socketGroup then
		return 1, true
	elseif activeSkill.socketGroup.groupCount then
		return activeSkill.socketGroup.groupCount, true
	else
		local gemList = activeSkill.socketGroup.gemList
		for _, gemData in pairs(gemList) do
			if gemData.gemData then
				if gemData.gemData.vaalGem then
					if activeSkill.activeEffect.grantedEffect == gemData.gemData.grantedEffectList[1] then
						return gemData.count or 1,  gemData.enableGlobal1 == true
					elseif activeSkill.activeEffect.grantedEffect == gemData.gemData.grantedEffectList[2] then
						return gemData.count or 1,  gemData.enableGlobal2 == true
					end
				else
					if (activeSkill.activeEffect.grantedEffect == gemData.gemData.grantedEffect and not gemData.gemData.grantedEffect.support) or isValueInArray(gemData.gemData.additionalGrantedEffects, activeSkill.activeEffect.grantedEffect) then
						return gemData.count or 1, true
					end
				end
			end
		end
	end
	return 1, true
end

-- Calculate life/mana/spirit reservation
---@param actor table
function calcs.doActorLifeManaSpiritReservation(actor)
	local modDB = actor.modDB
	local output = actor.output
	local condList = modDB.conditions
	local breakdown = actor.breakdown

	actor.reserved_LifeBase = 0
	actor.reserved_LifePercent = modDB:Sum("BASE", nil, "ExtraLifeReserved")
	actor.reserved_ManaBase = 0
	actor.reserved_ManaPercent = 0
	actor.reserved_SpiritBase = 0
	actor.reserved_SpiritPercent = 0
	actor.uncancellable_LifeReservation = modDB:Sum("BASE", nil, "ExtraLifeReserved")
	actor.uncancellable_ManaReservation = modDB:Sum("BASE", nil, "ExtraManaReserved")
	actor.uncancellable_SpiritReservation = modDB:Sum("BASE", nil, "ExtraSpiritReserved")
	if breakdown then
		breakdown.LifeReserved = { reservations = { } }
		breakdown.ManaReserved = { reservations = { } }
		breakdown.SpiritReserved = { reservations = { } }
	end
	for _, activeSkill in ipairs(actor.activeSkillList) do
		if (activeSkill.skillTypes[SkillType.HasReservation] or activeSkill.skillData.SupportedByAutoexertion) and not activeSkill.skillTypes[SkillType.ReservationBecomesCost] then
			local skillModList = activeSkill.skillModList
			local skillCfg = activeSkill.skillCfg
			local mult = floor(skillModList:More(skillCfg, "ReservationMultiplier"), 4)
			local pool = { ["Mana"] = { }, ["Life"] = { }, ["Spirit"] = { } }
			pool.Mana.baseFlat = activeSkill.skillData.manaReservationFlat or activeSkill.activeEffect.grantedEffectLevel.manaReservationFlat or 0
			pool.Spirit.baseFlat = activeSkill.skillData.spiritReservationFlat or activeSkill.activeEffect.grantedEffectLevel.spiritReservationFlat or 0
			pool.Spirit.baseFlat = pool.Spirit.baseFlat + skillModList:Sum("BASE", skillCfg, "ExtraSpirit")
			if skillModList:Flag(skillCfg, "ManaCostGainAsReservation") and activeSkill.activeEffect.grantedEffectLevel.cost then
				pool.Spirit.baseFlat = skillModList:Sum("BASE", skillCfg, "ManaCostBase") + (activeSkill.activeEffect.grantedEffectLevel.cost.Mana or 0)
			end
			pool.Spirit.basePercent = activeSkill.skillData.spiritReservationPercent or activeSkill.activeEffect.grantedEffectLevel.spiritReservationPercent or 0
			pool.Mana.basePercent = activeSkill.skillData.manaReservationPercent or activeSkill.activeEffect.grantedEffectLevel.manaReservationPercent or 0
			pool.Life.baseFlat = activeSkill.skillData.lifeReservationFlat or activeSkill.activeEffect.grantedEffectLevel.lifeReservationFlat or 0
			if skillModList:Flag(skillCfg, "LifeCostGainAsReservation") and activeSkill.activeEffect.grantedEffectLevel.cost then
				pool.Life.baseFlat = skillModList:Sum("BASE", skillCfg, "LifeCostBase") + (activeSkill.activeEffect.grantedEffectLevel.cost.Life or 0)
			end
			pool.Life.basePercent = activeSkill.skillData.lifeReservationPercent or activeSkill.activeEffect.grantedEffectLevel.lifeReservationPercent or 0
			if skillModList:Flag(skillCfg, "BloodMagicReserved") then
				pool.Life.baseFlat = pool.Life.baseFlat + pool.Mana.baseFlat
				pool.Mana.baseFlat = 0
				activeSkill.skillData["LifeReservationFlatForced"] = activeSkill.skillData["ManaReservationFlatForced"]
				activeSkill.skillData["ManaReservationFlatForced"] = nil
				pool.Life.basePercent = pool.Life.basePercent + pool.Mana.basePercent
				pool.Mana.basePercent = 0
				activeSkill.skillData["LifeReservationPercentForced"] = activeSkill.skillData["ManaReservationPercentForced"]
				activeSkill.skillData["ManaReservationPercentForced"] = nil
			end
			for name, values in pairs(pool) do
				values.more = skillModList:More(skillCfg, name.."Reserved", "Reserved")
				values.inc = skillModList:Sum("INC", skillCfg, name.."Reserved", "Reserved")
				values.efficiency = m_max(skillModList:Sum("INC", skillCfg, name.."ReservationEfficiency", "ReservationEfficiency"), -100)
				-- used for Arcane Cloak calculations in ModStore.GetStat
				actor[name.."Efficiency"] = values.efficiency
				if activeSkill.skillData[name.."ReservationFlatForced"] then
					values.reservedFlat = activeSkill.skillData[name.."ReservationFlatForced"]
				else
					local baseFlatVal = values.baseFlat * mult
					values.reservedFlat = 0
					if values.more > 0 and values.inc > -100 and baseFlatVal ~= 0 then
						values.reservedFlat = m_max(m_ceil(baseFlatVal * (100 + values.inc) / 100 * values.more / (1 + values.efficiency / 100), 0), 0)
					end
				end
				if activeSkill.skillData[name.."ReservationPercentForced"] then
					values.reservedPercent = activeSkill.skillData[name.."ReservationPercentForced"]
				else
					local basePercentVal = values.basePercent * mult
					values.reservedPercent = 0
					if values.more > 0 and values.inc > -100 and basePercentVal ~= 0 then
						values.reservedPercent = m_max(m_ceil(basePercentVal * (100 + values.inc) / 100 * values.more / (1 + values.efficiency / 100), 2), 0)
					end
				end
				if activeSkill.activeMineCount then
					values.reservedFlat = values.reservedFlat * activeSkill.activeMineCount
					values.reservedPercent = values.reservedPercent * activeSkill.activeMineCount
				end
				if activeSkill.skillTypes[SkillType.MultipleReservation] then
					local activeSkillCount, enabled = calcs.getActiveSkillCount(activeSkill)
					local minionFreeSpiritCount = skillModList:Sum("BASE", skillCfg, "MinionFreeSpiritCount")
					values.reservedFlat = values.reservedFlat * m_max(activeSkillCount - minionFreeSpiritCount, 0)
				end
				if activeSkill.skillTypes[SkillType.IsBlasphemy] and activeSkill.activeEffect.srcInstance.supportEffect and activeSkill.activeEffect.srcInstance.supportEffect.isSupporting and activeSkill.skillData["blasphemyReservationFlat" .. name] then
					-- Sadly no better way to get key/val table element count in lua.
					local instances = 0
					for _ in pairs(activeSkill.activeEffect.srcInstance.supportEffect.isSupporting) do
						instances = instances + 1
					end

					-- Extra reservation of blasphemy needs to be separated from the reservation caused by curses
					local blasphemyFlat = activeSkill.skillData["blasphemyReservationFlat" .. name]
					local blasphemyEffectiveFlat = m_max(m_ceil(blasphemyFlat * mult * (100 + values.inc) / 100 * values.more / (1 + values.efficiency / 100), 0), 0)
					values.reservedFlat = values.reservedFlat + blasphemyEffectiveFlat * instances
				end
					-- Blood Sacrament increases reservation per stage channelled
				if activeSkill.skillCfg.skillName == "Blood Sacrament" and activeSkill.activeStageCount then
					values.reservedFlat = values.reservedFlat * (activeSkill.activeStageCount + 1)
					values.reservedPercent = values.reservedPercent * (activeSkill.activeStageCount + 1)
				end
				if values.reservedFlat ~= 0 then
					activeSkill.skillData[name.."ReservedBase"] = values.reservedFlat
					actor["reserved_"..name.."Base"] = actor["reserved_"..name.."Base"] + values.reservedFlat
					if breakdown then
						t_insert(breakdown[name.."Reserved"].reservations, {
							skillName = activeSkill.activeEffect.grantedEffect.name,
							base = values.baseFlat,
							mult = mult ~= 1 and ("x "..mult),
							more = values.more ~= 1 and ("x "..values.more),
							inc = values.inc ~= 0 and ("x "..(1 + values.inc / 100)),
							efficiency = values.efficiency ~= 0 and ("x " .. round(100 / (100 + values.efficiency), 4)),
							total = values.reservedFlat,
						})
					end
				end
				if values.reservedPercent ~= 0 then
					activeSkill.skillData[name.."ReservedPercent"] = values.reservedPercent
					activeSkill.skillData[name.."ReservedBase"] = (values.reservedFlat or 0) + m_ceil(output[name] * values.reservedPercent / 100)
					actor["reserved_"..name.."Percent"] = actor["reserved_"..name.."Percent"] + values.reservedPercent
					if breakdown then
						t_insert(breakdown[name.."Reserved"].reservations, {
							skillName = activeSkill.activeEffect.grantedEffect.name,
							base = values.basePercent .. "%",
							mult = mult ~= 1 and ("x "..mult),
							more = values.more ~= 1 and ("x "..values.more),
							inc = values.inc ~= 0 and ("x "..(1 + values.inc / 100)),
							efficiency = values.efficiency ~= 0 and ("x " .. round(100 / (100 + values.efficiency), 4)),
							total = values.reservedPercent .. "%",
						})
					end
				end
				if skillModList:Flag(skillCfg, "HasUncancellableReservation") then
					actor["uncancellable_"..name.."Reservation"] = actor["uncancellable_"..name.."Reservation"] + values.reservedPercent
				end
			end
		end
	end

	for _, pool in pairs({"Life", "Mana", "Spirit"}) do
		local max = output[pool]
		local lowPerc = modDB:Sum("BASE", nil, "Low" .. pool .. "Percentage")
		local reserved = (actor["reserved_"..pool.."Base"] or 0) + m_ceil(max * (actor["reserved_"..pool.."Percent"] or 0) / 100)
		local uncancellableReservation = actor["uncancellable_"..pool.."Reservation"] or 0
		output[pool.."Reserved"] = m_min(reserved, max)
		output[pool.."Unreserved"] = max - reserved
		output[pool.."UncancellableReservation"] = m_min(uncancellableReservation, 0)
		output[pool.."CancellableReservation"] = 100 - uncancellableReservation
		if max > 0 then
			output[pool.."ReservedPercent"] = m_min(reserved / max * 100, 100)
			output[pool.."UnreservedPercent"] = (max - reserved) / max * 100
			if (max - reserved) / max <= (lowPerc > 0 and lowPerc or data.misc.LowPoolThreshold) then
				condList["Low"..pool] = true
			end
		end
		for _, value in ipairs(modDB:List(nil, "GrantReserved"..pool.."AsAura")) do
			local auraMod = copyTable(value.mod)
			auraMod.value = m_floor(auraMod.value * m_min(reserved, max))
			modDB:NewMod("ExtraAura", "LIST", { mod = auraMod })
		end
	end
end

-- Based on code from FR and BS found in act_*.txt
---@param activeSkill/output/breakdown references table passed in from calc offence
---@param sourceType string type of incoming damage - it will be converted (taken as) from this type if applicable
---@param baseDmg for which to calculate the damage
---@return table of taken damage parts, and number, sum of damages
function calcs.applyDmgTakenConversion(activeSkill, output, breakdown, sourceType, baseDmg)
	local damageBreakdown = { }
	local totalDamageTaken = 0
	local shiftTable = { }
	local totalTakenAs = 0
	for _, damageType in ipairs(dmgTypeList) do
		shiftTable[damageType] = activeSkill.skillModList:Sum("BASE", nil, sourceType.."DamageTakenAs"..damageType, sourceType.."DamageFromHitsTakenAs"..damageType, isElemental[sourceType] and "ElementalDamageTakenAs"..damageType or nil, isElemental[sourceType] and "ElementalDamageFromHitsTakenAs"..damageType or nil)
		totalTakenAs = totalTakenAs + shiftTable[damageType]
	end
	for _, damageType in ipairs(dmgTypeList) do
		local damageTakenAs = (damageType == sourceType) and m_max(1 - totalTakenAs / 100, 0) or shiftTable[damageType] / 100

		if damageTakenAs ~= 0 then
			local damage = baseDmg * damageTakenAs

			local baseTakenInc = activeSkill.skillModList:Sum("INC", nil, "DamageTaken", damageType.."DamageTaken", "DamageTakenWhenHit", damageType.."DamageTakenWhenHit")
			local baseTakenMore = activeSkill.skillModList:More(nil, "DamageTaken", damageType.."DamageTaken","DamageTakenWhenHit", damageType.."DamageTakenWhenHit")
			if (damageType == "Lightning" or damageType == "Cold" or damageType == "Fire") then
				baseTakenInc = baseTakenInc + activeSkill.skillModList:Sum("INC", nil, "ElementalDamageTaken", "ElementalDamageTakenWhenHit")
				baseTakenMore = baseTakenMore * activeSkill.skillModList:More(nil, "ElementalDamageTaken", "ElementalDamageTakenWhenHit")
			end
			local damageTakenMods = m_max((1 + baseTakenInc / 100) * baseTakenMore, 0)
			local reduction = activeSkill.skillModList:Flag(nil, "SelfIgnore".."Base"..damageType.."DamageReduction") and 0 or output["Base"..damageType.."DamageReductionWhenHit"] or output["Base"..damageType.."DamageReduction"]
			local resist = activeSkill.skillModList:Flag(nil, "SelfIgnore"..damageType.."Resistance") and 0 or output[damageType.."ResistWhenHit"] or output[damageType.."Resist"]
			local armourReduct = 0
			local resMult = 1 - resist / 100
			local reductMult = 1

			local percentOfArmourApplies = m_min((not activeSkill.skillModList:Flag(nil, "ArmourDoesNotApplyTo"..damageType.."DamageTaken") and activeSkill.skillModList:Sum("BASE", nil, "ArmourAppliesTo"..damageType.."DamageTaken") or 0), 100)
			if percentOfArmourApplies > 0 then
				local effArmour = (output.Armour * percentOfArmourApplies / 100) * (1 + output.ArmourDefense)
				-- effArmour needs to consider the "EvasionAddsToPdr" flag mod, and add the evasion to armour
				armourReduct = round(effArmour ~= 0 and damage ~= 0 and calcs.armourReductionF(effArmour, damage) or 0)
				armourReduct = m_min(output[damageType.."DamageReductionMax"], armourReduct)
			end
			reductMult = (1 - m_max(m_min(output[damageType.."DamageReductionMax"], armourReduct + reduction), 0) / 100) * damageTakenMods
			local combinedMult = resMult * reductMult
			local finalDamage = damage * combinedMult
			totalDamageTaken = totalDamageTaken + finalDamage

			if breakdown then
				t_insert(damageBreakdown, damageType.." Damage Taken")
				if damageTakenAs ~= 1 then
					t_insert(damageBreakdown, s_format("^8=^7 %d^8 (Base Damage)^7 * %.2f^8 (Damage taken as %s)", baseDmg, damageTakenAs, damageType))
				end
				if combinedMult ~= 1 then
					t_insert(damageBreakdown, s_format("^8=^7 %d^8 (%s Damage)^7 * %.4f^8 (Damage taken multi)", damage, damageType, combinedMult))
				end
				t_insert(damageBreakdown, s_format("^8=^7 %d^8 (%s Damage taken)", finalDamage, damageType))
				t_insert(damageBreakdown, s_format(""))
			end
		end
	end
	return damageBreakdown, totalDamageTaken
end

---Calculates the taken damages from enemy outgoing damage
---@param rawDamage number raw incoming damage number, after enemy damage multiplier
---@param damageType string type of incoming damage - it will be converted (taken as) from this type if applicable
---@param actor table actor (with output and modDB) for which to calculate the damage
---@return number, table sum of damages and a table of taken damage parts
function calcs.takenHitFromDamage(rawDamage, damageType, actor)
	local output = actor.output
	local modDB = actor.modDB
	local function damageMitigationMultiplierForType(damage, type)
		local effectiveAppliedArmour = output[type .."EffectiveAppliedArmour"]
		local armourDRPercent = calcs.armourReductionF(effectiveAppliedArmour, damage)
		local flatDRPercent = modDB:Flag(nil, "SelfIgnore".."Base".. type .."DamageReduction") and 0 or output["Base".. type .."DamageReductionWhenHit"] or output["Base".. type .."DamageReduction"]
		local totalDRPercent = m_min(output[damageType.."DamageReductionMax"], armourDRPercent + flatDRPercent)
		local enemyOverwhelmPercent = modDB:Flag(nil, "SelfIgnore".. type .."DamageReduction") and 0 or output[type .."EnemyOverwhelm"]
		local totalDRMulti = 1 - m_max(m_min(output[damageType.."DamageReductionMax"], totalDRPercent - enemyOverwhelmPercent), 0) / 100
		local totalResistMult = output[type .."ResistTakenHitMulti"]
		return totalResistMult * totalDRMulti
	end
	local receivedDamageSum = 0
	local damages = { }
	for damageConvertedType, convertPercent in pairs(actor.damageShiftTable[damageType]) do
		local takenFlat = output[damageConvertedType.."takenFlat"]
		if convertPercent > 0 or takenFlat ~= 0 then
			local convertedDamage = rawDamage * convertPercent / 100
			local vaalArctic = m_min(-modDB:Sum("MORE", nil, "VaalArcticArmourMitigation") / 100, 1)
			local reducedDamage = round(m_max(convertedDamage * damageMitigationMultiplierForType(convertedDamage, damageConvertedType) + takenFlat, 0) * output[damageConvertedType .."AfterReductionTakenHitMulti"]) * (1 - vaalArctic)
			receivedDamageSum = receivedDamageSum + reducedDamage
			damages[damageConvertedType] = (reducedDamage > 0 or convertPercent > 0) and reducedDamage or nil
		end
	end
	return receivedDamageSum, damages
end

local function calcLifeHitPoolWithLossPrevention(life, maxLife, lifeLossPrevented, lifeLossBelowHalfPrevented)
	local halfLife = maxLife * 0.5
	local aboveLow = m_max(life - halfLife, 0)
	return aboveLow / (1 - lifeLossPrevented / 100) + m_min(life, halfLife) / (1 - lifeLossBelowHalfPrevented / 100) / (1 - lifeLossPrevented / 100)
end

---Helper function that reduces pools according to damage taken
---@param poolTable table special pool values to use. Can be nil. Values from actor output are used if this is not provided or a value for some key in this is nil.
---@param damageTable table damage table after all the relevant reductions
---@param actor table actor (with output and modDB) for which to calculate the pools
---@return table pools reduced by damage
function calcs.reducePoolsByDamage(poolTable, damageTable, actor)
	local output = actor.output
	local modDB = actor.modDB
	local poolTbl = poolTable or { }
	
	local alliesTakenBeforeYou = poolTbl.AlliesTakenBeforeYou
	if not alliesTakenBeforeYou then
		alliesTakenBeforeYou = {}
		if output.FrostShieldLife then
			alliesTakenBeforeYou["frostShield"] = { remaining = output.FrostShieldLife, percent = output.FrostShieldDamageMitigation / 100 }
		end
		if output.TotalSpectreLife then
			alliesTakenBeforeYou["spectres"] = { remaining = output.TotalSpectreLife, percent = output.SpectreAllyDamageMitigation / 100 }
		end
		if output.TotalTotemLife then
			alliesTakenBeforeYou["totems"] = { remaining = output.TotalTotemLife, percent = output.TotemAllyDamageMitigation / 100 }
		end
		if output.TotalVaalRejuvenationTotemLife then
			alliesTakenBeforeYou["vaalRejuvenationTotems"] = { remaining = output.TotalVaalRejuvenationTotemLife, percent = output.VaalRejuvenationTotemAllyDamageMitigation / 100 }
		end
		if output.TotalRadianceSentinelLife then
			alliesTakenBeforeYou["radianceSentinel"] = { remaining = output.TotalRadianceSentinelLife, percent = output.RadianceSentinelAllyDamageMitigation / 100 }
		end
		if output.AlliedEnergyShield then
			alliesTakenBeforeYou["soulLink"] = { remaining = output.AlliedEnergyShield, percent = output.SoulLinkMitigation / 100 }
		end
	end
	
	local damageTakenThatCanBeRecouped = poolTbl.damageTakenThatCanBeRecouped or { }
	local aegis = poolTbl.Aegis
	if not aegis then
		aegis = {
			shared = output.sharedAegis or 0,
			sharedElemental = output.sharedElementalAegis or 0
		}
		for damageType in pairs(damageTable) do
			aegis[damageType] = output[damageType.."Aegis"] or 0
		end
	end
	local guard = poolTbl.Guard
	if not guard then
		guard = { shared = output.sharedGuardAbsorb or 0 }
		for damageType in pairs(damageTable) do
			guard[damageType] = output[damageType.."GuardAbsorb"] or 0
		end
	end
	
	local ward = poolTbl.Ward or output.Ward or 0
	local restoreWard = modDB:Flag(nil, "WardNotBreak") and ward or 0
	
	local energyShield = poolTbl.EnergyShield or output.EnergyShieldRecoveryCap
	local mana = poolTbl.Mana or output.ManaUnreserved or 0
	local life = poolTbl.Life or output.LifeRecoverable or 0
	local lifeLossBelowHalfPrevented = modDB:Sum("BASE", nil, "LifeLossBelowHalfPrevented")
	local LifeLossLostOverTime = poolTbl.LifeLossLostOverTime or 0
	local LifeBelowHalfLossLostOverTime = poolTbl.LifeBelowHalfLossLostOverTime or 0
	local overkillDamage = 0
	local resourcesLostToTypeDamage = { Physical = { }, Lightning = { }, Cold = { }, Fire = { }, Chaos = { } }
	local MoMPoolRemaining = m_huge
	local esPoolRemaining = m_huge
	
	local damageRemaindersBeforeES = {}
	for _, damageType in ipairs(dmgTypeList) do
		local damageRemainder = damageTable[damageType]
		if damageRemainder then
			for ally, allyValues in pairs(alliesTakenBeforeYou) do
				if not allyValues.damageType or allyValues.damageType == damageType then
					if allyValues.remaining > 0 then
						local tempDamage = m_min(damageRemainder * allyValues.percent, allyValues.remaining)
						allyValues.remaining = allyValues.remaining - tempDamage
						damageRemainder = damageRemainder - tempDamage
						resourcesLostToTypeDamage[damageType][ally] = tempDamage >= 1 and tempDamage or nil
					end
				end
			end
			-- frost shield / soul link / other taken before you does not count as you taking damage
			damageTakenThatCanBeRecouped[damageType] = (damageTakenThatCanBeRecouped[damageType] or 0) + damageRemainder
			if aegis[damageType] > 0 then
				local tempDamage = m_min(damageRemainder, aegis[damageType])
				aegis[damageType] = aegis[damageType] - tempDamage
				damageRemainder = damageRemainder - tempDamage
				resourcesLostToTypeDamage[damageType].aegis = tempDamage >= 1 and tempDamage or nil
			end
			if isElemental[damageType] and aegis.sharedElemental > 0 then
				local tempDamage = m_min(damageRemainder, aegis.sharedElemental)
				aegis.sharedElemental = aegis.sharedElemental - tempDamage
				damageRemainder = damageRemainder - tempDamage
				resourcesLostToTypeDamage[damageType].sharedElementalAegis = tempDamage >= 1 and tempDamage or nil
			end
			if aegis.shared > 0 then
				local tempDamage = m_min(damageRemainder, aegis.shared)
				aegis.shared = aegis.shared - tempDamage
				damageRemainder = damageRemainder - tempDamage
				resourcesLostToTypeDamage[damageType].sharedAegis = tempDamage >= 1 and tempDamage or nil
			end
			if guard[damageType] > 0 then
				local tempDamage = m_min(damageRemainder * output[damageType.."GuardAbsorbRate"] / 100, guard[damageType])
				guard[damageType] = guard[damageType] - tempDamage
				damageRemainder = damageRemainder - tempDamage
				resourcesLostToTypeDamage[damageType].guard = tempDamage >= 1 and tempDamage or nil
			end
			if guard.shared > 0 then
				local tempDamage = m_min(damageRemainder * output.sharedGuardAbsorbRate / 100, guard.shared)
				guard.shared = guard.shared - tempDamage
				damageRemainder = damageRemainder - tempDamage
				resourcesLostToTypeDamage[damageType].sharedGuard = tempDamage >= 1 and tempDamage or nil
			end
			if ward > 0 then
				local tempDamage = m_min(damageRemainder * (1 - (modDB:Sum("BASE", nil, "WardBypass") or 0) / 100), ward)
				ward = ward - tempDamage
				damageRemainder = damageRemainder - tempDamage
				resourcesLostToTypeDamage[damageType].ward = tempDamage >= 1 and tempDamage or nil
			end
			damageRemaindersBeforeES[damageType] = damageRemainder > 0 and damageRemainder or nil
		end
	end
	
	for i=#dmgTypeList, 1, -1 do
		local damageType = dmgTypeList[i]
		local damageRemainder = damageRemaindersBeforeES[damageType]
		if damageRemainder then
			local esDamageTypeMultiplier = damageType == "Chaos" and 2 or 1
			local esBypass = output[damageType.."EnergyShieldBypass"] / 100 or 0
			local lifeHitPool = calcLifeHitPoolWithLossPrevention(life, output.Life, output.preventedLifeLoss, lifeLossBelowHalfPrevented)
			local MoMEffect = m_min(output.sharedMindOverMatter + output[damageType.."MindOverMatter"], 100) / 100
			local MoMPool = MoMEffect < 1 and m_min(lifeHitPool / (1 - MoMEffect) - lifeHitPool, mana) or mana
			if energyShield > 0 and modDB:Flag(nil, "EternalLife") then
				local tempDamage = m_min(damageRemainder, energyShield / (1 - esBypass) / esDamageTypeMultiplier)
				energyShield = energyShield - tempDamage * (1 - esBypass) * esDamageTypeMultiplier
				esPoolRemaining = m_min(esPoolRemaining, energyShield)
				damageRemainder = damageRemainder - tempDamage
				resourcesLostToTypeDamage[damageType].energyShield = tempDamage >= 1 and tempDamage * (1 - esBypass) * esDamageTypeMultiplier or nil
				resourcesLostToTypeDamage[damageType].eternalLifePrevented = tempDamage >= 1 and tempDamage * esBypass or nil
			elseif energyShield > 0 and esBypass < 1 then
				local MoMEBPool = esBypass > 0 and m_min((MoMPool + lifeHitPool) / esBypass * esDamageTypeMultiplier - (MoMPool + lifeHitPool), energyShield) or energyShield
				local tempDamage = m_min(damageRemainder * (1 - esBypass), MoMEBPool / esDamageTypeMultiplier)
				esPoolRemaining = m_min(esPoolRemaining, MoMEBPool - tempDamage * esDamageTypeMultiplier)
				energyShield = energyShield - tempDamage * esDamageTypeMultiplier
				damageRemainder = damageRemainder - tempDamage
				resourcesLostToTypeDamage[damageType].energyShield = tempDamage >= 1 and tempDamage * esDamageTypeMultiplier or nil
			end
			if MoMEffect > 0 and mana > 0 then
				local MoMDamage = damageRemainder * MoMEffect
				local tempDamage = m_min(MoMDamage, MoMPool)
				MoMPoolRemaining = m_min(MoMPoolRemaining, MoMPool - tempDamage)
				mana = mana - tempDamage
				damageRemainder = damageRemainder - tempDamage
				resourcesLostToTypeDamage[damageType].mana = tempDamage >= 1 and tempDamage or nil
			else
				MoMPoolRemaining = 0
			end
			if output.preventedLifeLossTotal > 0 then
				local halfLife = output.Life * 0.5
				local lifeOverHalfLife = m_max(life - halfLife, 0)
				local preventPercent = output.preventedLifeLoss / 100
				local poolAboveLow = lifeOverHalfLife / (1 - preventPercent)
				local preventBelowHalfPercent = lifeLossBelowHalfPrevented / 100
				local damageThatLifeCanStillTake = poolAboveLow + m_max(m_min(life, halfLife), 0) / (1 - preventBelowHalfPercent) / (1 - output.preventedLifeLoss / 100)
				if damageThatLifeCanStillTake < damageRemainder  then
					overkillDamage = overkillDamage + damageRemainder - damageThatLifeCanStillTake
					damageRemainder = damageThatLifeCanStillTake
				end
				if output.preventedLifeLossBelowHalf ~= 0 then
					local damageToSplit = m_min(damageRemainder, poolAboveLow)
					local lostLife = damageToSplit * (1 - preventPercent)
					local preventedLoss = damageToSplit * preventPercent
					damageRemainder = damageRemainder - damageToSplit
					LifeLossLostOverTime = LifeLossLostOverTime + preventedLoss
					life = life - lostLife
					resourcesLostToTypeDamage[damageType].life = lostLife
					resourcesLostToTypeDamage[damageType].lifeLossPrevented = preventedLoss
					if life <= halfLife then
						local unspecificallyLowLifePreventedDamage = damageRemainder * preventPercent
						LifeLossLostOverTime = LifeLossLostOverTime + unspecificallyLowLifePreventedDamage
						damageRemainder = damageRemainder - unspecificallyLowLifePreventedDamage
						local specificallyLowLifePreventedDamage = damageRemainder * preventBelowHalfPercent
						LifeBelowHalfLossLostOverTime = LifeBelowHalfLossLostOverTime + specificallyLowLifePreventedDamage
						damageRemainder = damageRemainder - specificallyLowLifePreventedDamage
						resourcesLostToTypeDamage[damageType].lifeLossPrevented = resourcesLostToTypeDamage[damageType].lifeLossPrevented + unspecificallyLowLifePreventedDamage + specificallyLowLifePreventedDamage
					end
					resourcesLostToTypeDamage[damageType].lifeLossPrevented = resourcesLostToTypeDamage[damageType].lifeLossPrevented >= 1 and resourcesLostToTypeDamage[damageType].lifeLossPrevented or nil
				else
					local tempDamage = damageRemainder * output.preventedLifeLoss / 100
					LifeLossLostOverTime = LifeLossLostOverTime + tempDamage
					damageRemainder = damageRemainder - tempDamage
					resourcesLostToTypeDamage[damageType].lifeLossPrevented = tempDamage >= 1 and tempDamage or nil
				end
			end
			if life > 0 then
				local tempDamage = m_min(damageRemainder, life)
				life = life - tempDamage
				damageRemainder = damageRemainder - tempDamage
				resourcesLostToTypeDamage[damageType].life = (resourcesLostToTypeDamage[damageType].life or 0) + (tempDamage > 0 and tempDamage or 0)
			end
			overkillDamage = overkillDamage + damageRemainder
			resourcesLostToTypeDamage[damageType].overkill = damageRemainder >= 1 and damageRemainder or nil
		end
	end
	local hitPoolRemaining = calcLifeHitPoolWithLossPrevention(life, output.Life, output.preventedLifeLoss, lifeLossBelowHalfPrevented) +
		(MoMPoolRemaining ~= m_huge and MoMPoolRemaining or 0) + (esPoolRemaining ~= m_huge and esPoolRemaining or 0)

	return {
		AlliesTakenBeforeYou = alliesTakenBeforeYou,
		Aegis = aegis,
		Guard = guard,
		Ward = restoreWard,
		EnergyShield = energyShield,
		Mana = mana,
		Life = life,
		damageTakenThatCanBeRecouped = damageTakenThatCanBeRecouped,
		LifeLossLostOverTime = LifeLossLostOverTime,
		LifeBelowHalfLossLostOverTime = LifeBelowHalfLossLostOverTime,
		OverkillDamage = overkillDamage,
		hitPoolRemaining = m_floor(hitPoolRemaining),
		resourcesLostToTypeDamage = resourcesLostToTypeDamage
	}
end

---Inserts breakdown of resources drained by a hit
---@param breakdownTable table table to insert items to
---@param poolsRemaining table remaining pools after running reducePoolsByDamage on damage to beak down
---@param output table must already contain things like guard, aegis, ally life...
---@return table breakdownTable with drained resource list
local function incomingDamageBreakdown(breakdownTable, poolsRemaining, output)
	--region Breakdown inserts
	if output.FrostShieldLife and output.FrostShieldLife > 0 then
		t_insert(breakdownTable, s_format("\t%d "..colorCodes.GEM.."Frost Shield Life ^7(%d remaining)", output.FrostShieldLife - poolsRemaining.AlliesTakenBeforeYou["frostShield"].remaining, poolsRemaining.AlliesTakenBeforeYou["frostShield"].remaining))
	end
	if output.TotalSpectreLife and output.TotalSpectreLife > 0 then
		t_insert(breakdownTable, s_format("\t%d "..colorCodes.GEM.."Total Spectre Life ^7(%d remaining)", output.TotalSpectreLife - poolsRemaining.AlliesTakenBeforeYou["spectres"].remaining, poolsRemaining.AlliesTakenBeforeYou["spectres"].remaining))
	end
	if output.TotalTotemLife and output.TotalTotemLife > 0 then
		t_insert(breakdownTable, s_format("\t%d "..colorCodes.GEM.."Total Totem Life ^7(%d remaining)", output.TotalTotemLife - poolsRemaining.AlliesTakenBeforeYou["totems"].remaining, poolsRemaining.AlliesTakenBeforeYou["totems"].remaining))
	end
	if output.TotalVaalRejuvenationTotemLife and output.TotalVaalRejuvenationTotemLife > 0 then
		t_insert(breakdownTable, s_format("\t%d "..colorCodes.GEM.."Total Vaal Rejuvenation Totem Life ^7(%d remaining)", output.TotalVaalRejuvenationTotemLife - poolsRemaining.AlliesTakenBeforeYou["vaalRejuvenationTotems"].remaining, poolsRemaining.AlliesTakenBeforeYou["vaalRejuvenationTotems"].remaining))
	end
	if output.TotalRadianceSentinelLife and output.TotalRadianceSentinelLife > 0 then
		t_insert(breakdownTable, s_format("\t%d "..colorCodes.GEM.."Total Sentinel of Radiance Life ^7(%d remaining)", output.TotalRadianceSentinelLife - poolsRemaining.AlliesTakenBeforeYou["radianceSentinel"].remaining, poolsRemaining.AlliesTakenBeforeYou["radianceSentinel"].remaining))
	end
	if output.AlliedEnergyShield and output.AlliedEnergyShield > 0 then
		t_insert(breakdownTable, s_format("\t%d "..colorCodes.GEM.."Total Allied Energy shield ^7(%d remaining)", output.AlliedEnergyShield - poolsRemaining.AlliesTakenBeforeYou["soulLink"].remaining, poolsRemaining.AlliesTakenBeforeYou["soulLink"].remaining))
	end
	for _, damageType in ipairs(dmgTypeList) do
		if poolsRemaining.resourcesLostToTypeDamage[damageType].aegis then
			t_insert(breakdownTable, s_format("\t%d "..colorCodes.GEM.."%s Aegis charge ^7(%d remaining)", poolsRemaining.resourcesLostToTypeDamage[damageType].aegis, damageType, poolsRemaining.Aegis[damageType]))
		end
	end
	if output.sharedElementalAegis and output.sharedElementalAegis ~= poolsRemaining.Aegis.sharedElemental then
		t_insert(breakdownTable, s_format("\t%d "..colorCodes.GEM.."Elemental Aegis charge ^7(%d remaining)", output.sharedElementalAegis - poolsRemaining.Aegis.sharedElemental, poolsRemaining.Aegis.sharedElemental))
	end
	if output.sharedAegis and output.sharedAegis > 0 then
		t_insert(breakdownTable, s_format("\t%d "..colorCodes.GEM.."Shared Aegis charge ^7(%d remaining)", output.sharedAegis - poolsRemaining.Aegis.shared, poolsRemaining.Aegis.shared))
	end
	local eternalLifePrevented = 0
	for _, damageType in ipairs(dmgTypeList) do
		eternalLifePrevented = eternalLifePrevented + (poolsRemaining.resourcesLostToTypeDamage[damageType].eternalLifePrevented or 0)
		if poolsRemaining.resourcesLostToTypeDamage[damageType].guard then
			t_insert(breakdownTable, s_format("\n\t%d "..colorCodes.SCOURGE.."%s Guard charge ^7(%d remaining)", poolsRemaining.resourcesLostToTypeDamage[damageType].guard, damageType, poolsRemaining.Guard[damageType]))
		end
	end
	if output.sharedGuardAbsorb and output.sharedGuardAbsorb > 0 then
		t_insert(breakdownTable, s_format("\t%d "..colorCodes.SCOURGE.."Shared Guard charge ^7(%d remaining)", output.sharedGuardAbsorb - poolsRemaining.Guard.shared, poolsRemaining.Guard.shared))
	end
	if output.Ward and output.Ward > 0 then
		t_insert(breakdownTable, s_format("\t%d "..colorCodes.WARD.."Ward", output.Ward))
	end
	if output.EnergyShieldRecoveryCap ~= poolsRemaining.EnergyShield and output.EnergyShieldRecoveryCap and output.EnergyShieldRecoveryCap > 0 then
		t_insert(breakdownTable, s_format("\t%d "..colorCodes.ES.."Energy Shield ^7(%d remaining)", output.EnergyShieldRecoveryCap - poolsRemaining.EnergyShield, poolsRemaining.EnergyShield))
	end
	if eternalLifePrevented > 0 then
		t_insert(breakdownTable, s_format("\t%d "..colorCodes.POSITIVE.."Life change prevented by Eternal Life", eternalLifePrevented))
	end
	if output.ManaUnreserved ~= poolsRemaining.Mana and output.ManaUnreserved and output.ManaUnreserved > 0 then
		t_insert(breakdownTable, s_format("\t%d "..colorCodes.MANA.."Mana ^7(%d remaining)", output.ManaUnreserved - poolsRemaining.Mana, poolsRemaining.Mana))
	end
	if poolsRemaining.LifeLossLostOverTime + poolsRemaining.LifeBelowHalfLossLostOverTime > 0 then
		t_insert(breakdownTable, s_format("\t%d "..colorCodes.LIFE.."Life ^7Loss Prevented", poolsRemaining.LifeLossLostOverTime + poolsRemaining.LifeBelowHalfLossLostOverTime))
	end
	t_insert(breakdownTable, s_format("\t%d "..colorCodes.LIFE.."Life ^7(%d remaining)", output.LifeRecoverable - poolsRemaining.Life, poolsRemaining.Life))
	if poolsRemaining.OverkillDamage >= 1 then
		t_insert(breakdownTable, s_format("\t%d "..colorCodes.NEGATIVE.."Overkill damage", poolsRemaining.OverkillDamage))
	end
	--endregion

	return breakdownTable
end

-- Performs all ingame and related defensive calculations
function calcs.defence(env, actor)
	local modDB = actor.modDB
	local enemyDB = actor.enemy.modDB
	local output = actor.output
	local breakdown = actor.breakdown

	local condList = modDB.conditions

	-- Action Speed
	output.ActionSpeedMod = calcs.actionSpeedMod(actor)
	
	-- Armour defence types for conditionals
	for _, slot in pairs({"Helmet","Gloves","Boots","Body Armour","Weapon 2","Weapon 3"}) do
		local armourData = actor.itemList[slot] and actor.itemList[slot].armourData
		if armourData then
			local wardBase = armourData.Ward or 0
			if wardBase > 0 then
				if slot == "Body Armour" and modDB:Flag(nil, "DoubleBodyArmourDefence") then
					wardBase = wardBase * 2
				end
				output["WardOn"..slot] = wardBase
			end

			local energyShieldBase = armourData.EnergyShield or 0
			if energyShieldBase > 0 then
				if slot == "Body Armour" and modDB:Flag(nil, "DoubleBodyArmourDefence") then
					energyShieldBase = energyShieldBase * 2
				end
				output["EnergyShieldOn"..slot] = energyShieldBase
			end

			local armourBase = armourData.Armour or 0
			if armourBase > 0 then
				if slot == "Body Armour" then 
					if modDB:Flag(nil, "DoubleBodyArmourDefence") then
						armourBase = armourBase * 2
					end
					if modDB:Flag(nil, "Unbreakable") then
						armourBase = armourBase * 2
					end
				end
				output["ArmourOn"..slot] = armourBase
			end

			local evasionBase = armourData.Evasion or 0
			if evasionBase > 0 then
				if slot == "Body Armour" then
					if modDB:Flag(nil, "DoubleBodyArmourDefence") then
						evasionBase = evasionBase * 2
					end
				 	if modDB:Flag(nil, "Unbreakable") and modDB:Flag(nil, "IronReflexes") then
						evasionBase = evasionBase * 2
					end
				end
				output["EvasionOn"..slot] = evasionBase
			end
			output["LowestOfArmourAndEvasionOn"..slot] = m_min(armourBase, evasionBase)
		end
	end

	-- Resistances
	output["PhysicalResist"] = 0
	
	-- Process Resistance conversion mods
	for _, resFrom in ipairs(resistTypeList) do
		local maxRes
		for _, resTo in ipairs(resistTypeList) do
			local conversionRate = modDB:Sum("BASE", nil, resFrom.."MaxResConvertTo"..resTo) / 100
			if conversionRate ~= 0 then
				if not maxRes then
					maxRes = 0
					for _, mod in ipairs(modDB:Tabulate("BASE", nil, resFrom.."ResistMax")) do
						if mod.mod.source ~= "Base" then
							maxRes = maxRes + mod.value
						end
					end
				end
				if maxRes ~= 0 then
					modDB:NewMod(resTo.."ResistMax", "BASE", maxRes * conversionRate, resFrom.." To "..resTo.." Max Resistance Conversion")
				end
			end
		end
	end
	
	for _, resFrom in ipairs(resistTypeList) do
		local res
		for _, resTo in ipairs(resistTypeList) do
			local conversionRate = modDB:Sum("BASE", nil, resFrom.."ResConvertTo"..resTo) / 100
			if conversionRate ~= 0 then
				if not res then
					res = 0
					for _, mod in ipairs(modDB:Tabulate("BASE", nil, resFrom.."Resist")) do
						if mod.mod.source ~= "Base" then
							res = res + mod.value
						end
					end
				end
				if res ~= 0 then
					modDB:NewMod(resTo.."Resist", "BASE", res * conversionRate, resFrom.." To "..resTo.." Resistance Conversion")
				end
				for _, mod in ipairs(modDB:Tabulate("INC", nil, resFrom.."Resist")) do
					modDB:NewMod(resTo.."Resist", "INC", mod.value * conversionRate, mod.mod.source)
				end
				for _, mod in ipairs(modDB:Tabulate("MORE", nil, resFrom.."Resist")) do
					modDB:NewMod(resTo.."Resist", "MORE", mod.value * conversionRate, mod.mod.source)
				end
			end
		end
	end
	
	-- Highest Maximum Elemental Resistance for Melding of the Flesh
	if modDB:Flag(nil, "ElementalResistMaxIsHighestResistMax") then
		local highestResistMax = 0;
		local highestResistMaxType = "";
		for _, elem in ipairs(resistTypeList) do
			local resistMax = modDB:Override(nil, elem.."ResistMax") or m_min(data.misc.MaxResistCap, modDB:Sum("BASE", nil, elem.."ResistMax", isElemental[elem] and "ElementalResistMax"))
			if resistMax > highestResistMax and isElemental[elem] then
				highestResistMax = resistMax;
				highestResistMaxType = elem;
			end
		end
		for _, elem in ipairs(resistTypeList) do
			if isElemental[elem] then
				modDB:NewMod(elem.."ResistMax", "OVERRIDE", highestResistMax, highestResistMaxType.." Melding of the Flesh");
			end
		end
	end
	
	for _, elem in ipairs(resistTypeList) do
		local min, max, total, dotTotal, totemTotal, totemMax
		min = data.misc.ResistFloor
		total = modDB:Override(nil, elem.."Resist")
		totemMax = modDB:Override(nil, "Totem"..elem.."ResistMax") or m_min(data.misc.MaxResistCap, modDB:Sum("BASE", nil, "Totem"..elem.."ResistMax", isElemental[elem] and "TotemElementalResistMax"))
		totemTotal = modDB:Override(nil, "Totem"..elem.."Resist")
		if not total then
			local base = modDB:Sum("BASE", nil, elem.."Resist", isElemental[elem] and "ElementalResist")
			local inc = m_max(calcLib.mod(modDB, nil, elem.."Resist", isElemental[elem] and "ElementalResist"), 0)
			total = base * inc
			local dotBase = modDB:Sum("BASE", { flags = ModFlag.Dot, keywordFlags = 0 }, elem.."Resist", isElemental[elem] and "ElementalResist")
			dotTotal = dotBase * inc
		end
		if not totemTotal then
			local base = modDB:Sum("BASE", nil, "Totem"..elem.."Resist", isElemental[elem] and "TotemElementalResist")
			totemTotal = base * m_max(calcLib.mod(modDB, nil, "Totem"..elem.."Resist", isElemental[elem] and "TotemElementalResist"), 0)
		end
		
		-- Fractional resistances are truncated
		total = m_modf(total)
		-- Unnatural Resilience needs FireResistTotal before we calc FireResistMax
		output[elem.."ResistTotal"] = total
		if modDB:Flag(nil, "MaxBlockChanceModsApplyMaxResist") then
			local blockMaxBonus = modDB:Sum("BASE", nil, "BlockChanceMax") - 75 -- Subtract base block cap
			max = (modDB:Override(nil, elem.."ResistMax") or m_min(data.misc.MaxResistCap, modDB:Sum("BASE", nil, elem.."ResistMax", isElemental[elem] and "ElementalResistMax"))) + blockMaxBonus
		else
			max = modDB:Override(nil, elem.."ResistMax") or m_min(data.misc.MaxResistCap, modDB:Sum("BASE", nil, elem.."ResistMax", isElemental[elem] and "ElementalResistMax"))
		end		
		
		dotTotal = dotTotal and m_modf(dotTotal) or total
		totemTotal = m_modf(totemTotal)
		min = m_modf(min)
		max = m_modf(max)
		totemMax = m_modf(totemMax)
		
		local final = m_max(m_min(total, max), min)
		local dotFinal = m_max(m_min(dotTotal, max), min)
		local totemFinal = m_max(m_min(totemTotal, totemMax), min)

		output[elem.."Resist"] = final
		output[elem.."ResistOverCap"] = m_max(0, total - max)
		output[elem.."ResistOver75"] = m_max(0, final - 75)
		output["Missing"..elem.."Resist"] = m_max(0, max - final)
		output[elem.."ResistOverTime"] = dotFinal
		output["Totem"..elem.."Resist"] = totemFinal
		output["Totem"..elem.."ResistTotal"] = totemTotal
		output["Totem"..elem.."ResistOverCap"] = m_max(0, totemTotal - totemMax)
		output["MissingTotem"..elem.."Resist"] = m_max(0, totemMax - totemFinal)
		if breakdown then
			breakdown[elem.."Resist"] = {
				"Min: "..min.."%",
				"Max: "..max.."%",
				"Total: "..total.."%",
			}
			breakdown["Totem"..elem.."Resist"] = {
				"Min: "..min.."%",
				"Max: "..totemMax.."%",
				"Total: "..totemTotal.."%",
			}
		end
	end

	if breakdown then
		breakdown.Ward = { slots = { } }
		breakdown.EnergyShield = { slots = { } }
		breakdown.Armour = { slots = { } }
		breakdown.Evasion = { slots = { } }
		breakdown.Life = { slots = { } }
		breakdown.Mana = { slots = { } }
		breakdown.Spirit = { slots = { } }
	end
	if actor == env.minion then
		calcs.doActorLifeManaSpirit(env.minion)
		calcs.doActorLifeManaSpiritReservation(env.minion)
	end

	-- Block
	if modDB:Flag(nil, "MaxBlockChanceModsApplyMaxResist") then
		output.BlockChanceMax = 75
	else
		output.BlockChanceMax = m_min(modDB:Sum("BASE", nil, "BlockChanceMax"), data.misc.BlockChanceCap)
	end
	if modDB:Flag(nil, "MaximumBlockAttackChanceIsEqualToParent") then
		output.BlockChanceMax = actor.parent.output.BlockChanceMax
	elseif modDB:Flag(nil, "MaximumBlockAttackChanceIsEqualToPartyMember") then
		output.BlockChanceMax = actor.partyMembers.output.BlockChanceMax
	end
	output.BlockChanceOverCap = 0
	output.SpellBlockChanceOverCap = 0
	local baseBlockChance = 0
	if actor.itemList["Weapon 2"] and actor.itemList["Weapon 2"].armourData then
		baseBlockChance = baseBlockChance + (actor.itemList["Weapon 2"].armourData.BlockChance or 0)
	end
	if actor.itemList["Weapon 3"] and actor.itemList["Weapon 3"].armourData then
		baseBlockChance = baseBlockChance + (actor.itemList["Weapon 3"].armourData.BlockChance or 0)
	end
	output.ShieldBlockChance = baseBlockChance
	baseBlockChance = modDB:Override(nil, "ReplaceShieldBlock") or baseBlockChance
	if modDB:Flag(nil, "BlockAttackChanceIsEqualToParent") then
		output.BlockChance = m_min(actor.parent.output.BlockChance, output.BlockChanceMax)
	elseif modDB:Flag(nil, "BlockAttackChanceIsEqualToPartyMember") then
		output.BlockChance = m_min(actor.partyMembers.output.BlockChance, output.BlockChanceMax)
	elseif modDB:Flag(nil, "MaxBlockIfNotBlockedRecently") then
		output.BlockChance = output.BlockChanceMax
	else
		local totalBlockChance = (baseBlockChance + modDB:Sum("BASE", nil, "BlockChance")) * calcLib.mod(modDB, nil, "BlockChance")
		output.BlockChance = m_min(totalBlockChance, output.BlockChanceMax)
		output.BlockChanceOverCap = m_max(0, totalBlockChance - output.BlockChanceMax)
	end
	output.ProjectileBlockChance = m_min(output.BlockChance + modDB:Sum("BASE", nil, "ProjectileBlockChance") * calcLib.mod(modDB, nil, "BlockChance"), output.BlockChanceMax)
	if modDB:Flag(nil, "SpellBlockChanceMaxIsBlockChanceMax") then
		output.SpellBlockChanceMax = output.BlockChanceMax
	else
		output.SpellBlockChanceMax = m_min(modDB:Sum("BASE", nil, "SpellBlockChanceMax"), data.misc.BlockChanceCap)
	end
	if modDB:Flag(nil, "MaxSpellBlockIfNotBlockedRecently") then 
		output.SpellBlockChance = output.SpellBlockChanceMax
		output.SpellProjectileBlockChance = output.SpellBlockChanceMax
	elseif modDB:Flag(nil, "SpellBlockChanceIsBlockChance") then
		output.SpellBlockChance = output.BlockChance
		output.SpellProjectileBlockChance = output.ProjectileBlockChance
		output.SpellBlockChanceOverCap = output.BlockChanceOverCap
	else
		local totalSpellBlockChance = modDB:Sum("BASE", nil, "SpellBlockChance") * calcLib.mod(modDB, nil, "SpellBlockChance")
		output.SpellBlockChance = m_min(totalSpellBlockChance, output.SpellBlockChanceMax)
		output.SpellBlockChanceOverCap = m_max(0, totalSpellBlockChance - output.SpellBlockChanceMax)
		output.SpellProjectileBlockChance = m_max(m_min(output.SpellBlockChance + modDB:Sum("BASE", nil, "ProjectileSpellBlockChance") * calcLib.mod(modDB, nil, "SpellBlockChance"), output.SpellBlockChanceMax), 0)
	end
	if breakdown then
		breakdown.BlockChance = {
			"Base: "..baseBlockChance.."%",
			"Max: "..output.BlockChanceMax.."%",
			"Total: "..output.BlockChance+output.BlockChanceOverCap.."%",
		}
		breakdown.SpellBlockChance = {
			"Max: "..output.SpellBlockChanceMax.."%",
			"Total: "..output.SpellBlockChance+output.SpellBlockChanceOverCap.."%",
		}
	end
	if modDB:Flag(nil, "CannotBlockAttacks") or enemyDB:Flag(nil, "CannotBeBlocked") then
		output.BlockChance = 0
		output.ProjectileBlockChance = 0
	end
	if modDB:Flag(nil, "CannotBlockSpells") or enemyDB:Flag(nil, "CannotBeBlocked") then
		output.SpellBlockChance = 0
		output.SpellProjectileBlockChance = 0
	end
	do
		for _, blockType in ipairs({"BlockChance", "ProjectileBlockChance", "SpellBlockChance", "SpellProjectileBlockChance"}) do
			output["Effective"..blockType] = env.mode_effective and m_max(output[blockType] - enemyDB:Sum("BASE", nil, "reduceEnemyBlock"), 0) or output[blockType]
			local luck = 1
			if env.mode_effective then
				luck = luck * (modDB:Flag(nil, blockType.."IsLucky") and 2 or 1) / (modDB:Flag(nil, blockType.."IsUnlucky") and 2 or 1)
			end
			-- unlucky config to lower the value of block, dodge, evade etc for ehp
			luck = luck / (env.configInput.EHPUnluckyWorstOf or 1)
			while luck ~= 1 do
				if luck > 1 then
					luck = luck / 2
					output["Effective"..blockType] = (1 - (1 - output["Effective"..blockType] / 100) ^ 2) * 100
				else
					luck = luck * 2
					output["Effective"..blockType] = output["Effective"..blockType] / 100 * output["Effective"..blockType]
				end
			end
		end
	end
	output.EffectiveAverageBlockChance = (output.EffectiveBlockChance + output.EffectiveProjectileBlockChance + output.EffectiveSpellBlockChance + output.EffectiveSpellProjectileBlockChance) / 4
	output.BlockEffect = m_max(100 - modDB:Sum("BASE", nil, "BlockEffect"), 0)
	if output.BlockEffect == 0 or output.BlockEffect == 100 then
		output.BlockEffect = 100
	else
		output.ShowBlockEffect = true
		output.DamageTakenOnBlock = 100 - output.BlockEffect
	end

	if modDB:Flag(nil, "ArmourAppliesToEnergyShieldRecharge") then
		-- Armour to ES Recharge conversion from Armour and Energy Shield Mastery
		local multiplier = (modDB:Max(nil, "ImprovedArmourAppliesToEnergyShieldRecharge") or 100) / 100
		for _, value in ipairs(modDB:Tabulate("INC", nil, "Armour", "ArmourAndEvasion", "Defences")) do
			local mod = value.mod
			local modifiers = calcLib.getConvertedModTags(mod, multiplier)
			modDB:NewMod("EnergyShieldRecharge", "INC", m_floor(mod.value * multiplier), mod.source, mod.flags, mod.keywordFlags, unpack(modifiers))
		end
	end

	if modDB:Flag(nil, "EnergyShieldIncreasedByOvercappedColdRes") then
		for i, value in ipairs(modDB:Tabulate("FLAG", nil, "EnergyShieldIncreasedByOvercappedColdRes")) do
				local mod = value.mod
				modDB:NewMod("EnergyShield", "INC", output.ColdResistOverCap, mod.source)
			break
		end
	end
	if modDB:Flag(nil, "ArmourIncreasedByUncappedFireRes") then
		for i, value in ipairs(modDB:Tabulate("FLAG", nil, "ArmourIncreasedByUncappedFireRes")) do
				local mod = value.mod
				modDB:NewMod("Armour", "INC", output.FireResistTotal, mod.source)
			break
		end
	end
	if modDB:Flag(nil, "ArmourIncreasedByOvercappedFireRes") then
		for i, value in ipairs(modDB:Tabulate("FLAG", nil, "ArmourIncreasedByOvercappedFireRes")) do
			local mod = value.mod
			modDB:NewMod("Armour", "INC", output.FireResistOverCap, mod.source)			
			break
		end
	end
	if modDB:Flag(nil, "EvasionRatingIncreasedByUncappedColdRes") then
		for i, value in ipairs(modDB:Tabulate("FLAG", nil, "EvasionRatingIncreasedByUncappedColdRes")) do
			local mod = value.mod
			modDB:NewMod("Evasion", "INC", output.ColdResistTotal, mod.source)			
			break
		end
	end
	if modDB:Flag(nil, "EvasionRatingIncreasedByOvercappedColdRes") then
		for i, value in ipairs(modDB:Tabulate("FLAG", nil, "EvasionRatingIncreasedByOvercappedColdRes")) do
			local mod = value.mod
			modDB:NewMod("Evasion", "INC", output.ColdResistOverCap, mod.source)			
			break
		end
	end
	if modDB:Flag(nil, "EvasionRatingIncreasedByOvercappedLightningRes") then
		for i, value in ipairs(modDB:Tabulate("FLAG", nil, "EvasionRatingIncreasedByOvercappedLightningRes")) do
			local mod = value.mod
			modDB:NewMod("Evasion", "INC", output.LightningResistOverCap, mod.source)			
			break
		end
	end
	-- Primary defences: Energy shield, evasion and armour
	do
		-- Pre-calculate Life/Mana/Spirit for mods such as Beidat's hand
		calcs.doActorLifeManaSpirit(actor, true)
		local ward = 0
		local energyShield = 0
		local armour = 0
		local evasion = 0
		local energyShieldBase, armourBase, evasionBase, wardBase
		local gearWard = 0
		local gearEnergyShield = 0
		local gearArmour = 0
		local gearEvasion = 0
		local slotCfg = wipeTable(tempTable1)
		for _, slot in pairs({"Helmet","Gloves","Boots","Body Armour","Weapon 2","Weapon 3"}) do
			local armourData = actor.itemList[slot] and actor.itemList[slot].armourData
			if armourData then
				slotCfg.slotName = slot
				wardBase = armourData.Ward or 0
				if wardBase > 0 then
					if slot == "Body Armour" and modDB:Flag(nil, "DoubleBodyArmourDefence") then
						wardBase = wardBase * 2
					end
					if modDB:Flag(nil, "EnergyShieldToWard") then
						local inc = modDB:Sum("INC", slotCfg, "Ward", "Defences", "EnergyShield")
						local more = modDB:More(slotCfg, "Ward", "Defences")
						ward = ward + wardBase * (1 + inc / 100) * more
						gearWard = gearWard + wardBase
						if breakdown then
							t_insert(breakdown["Ward"].slots, {
								base = wardBase,
								inc = (inc ~= 0) and s_format(" x %.2f", 1 + inc/100),
								more = (more ~= 1) and s_format(" x %.2f", more),
								total = s_format("%.2f", wardBase * (1 + inc / 100) * more),
								source = slot,
								item = actor.itemList[slot],
							})
						end
					else
						ward = ward + wardBase * calcLib.mod(modDB, slotCfg, "Ward", "Defences")
						gearWard = gearWard + wardBase
						if breakdown then
							breakdown.slot(slot, nil, slotCfg, wardBase, nil, "Ward", "Defences")
						end
					end
				end
				energyShieldBase = armourData.EnergyShield or 0
				if energyShieldBase > 0 then
					if slot == "Body Armour" and modDB:Flag(nil, "DoubleBodyArmourDefence") then
						energyShieldBase = energyShieldBase * 2
					end
					if modDB:Flag(nil, "EnergyShieldToWard") then
						local more = modDB:More(slotCfg, "EnergyShield", "Defences")
						gearEnergyShield = gearEnergyShield + energyShieldBase
						if breakdown then
							t_insert(breakdown["EnergyShield"].slots, {
								base = energyShieldBase,
								more = (more ~= 1) and s_format(" x %.2f", more),
								total = s_format("%.2f", energyShieldBase * more),
								source = slot,
								item = actor.itemList[slot],
							})
						end
					elseif not modDB:Flag(nil, "ConvertArmourESToLife") then
						gearEnergyShield = gearEnergyShield + energyShieldBase
						if breakdown then
							breakdown.slot(slot, nil, slotCfg, energyShieldBase, nil, "EnergyShield", "Defences", slot.."ESAndArmour")
						end
					end
				end
				armourBase = armourData.Armour or 0
				if armourBase > 0 then
					if slot == "Body Armour" then
						if modDB:Flag(nil, "DoubleBodyArmourDefence") then
							armourBase = armourBase * 2
						end
						if modDB:Flag(nil, "Unbreakable") then 
							armourBase = armourBase * 2
						end
						if modDB:Flag(nil, "ConvertBodyArmourArmourEvasionToWard") then
							armourBase = armourBase * (1 - ((modDB:Sum("BASE", nil, "BodyArmourArmourEvasionToWardPercent") or 0) / 100))
						end
					end
					gearArmour = gearArmour + armourBase
					if breakdown then
						breakdown.slot(slot, nil, slotCfg, armourBase, nil, "Armour", "ArmourAndEvasion", "Defences", slot.."ESAndArmour")
					end
				end
				evasionBase = armourData.Evasion or 0
				if evasionBase > 0 then
					if slot == "Body Armour" then
						if modDB:Flag(nil, "DoubleBodyArmourDefence") then
							evasionBase = evasionBase * 2
						end
						if modDB:Flag(nil, "Unbreakable") and modDB:Flag(nil, "IronReflexes") then
							evasionBase = evasionBase * 2
						end
						if modDB:Flag(nil, "ConvertBodyArmourArmourEvasionToWard") then
							evasionBase = evasionBase * (1 - ((modDB:Sum("BASE", nil, "BodyArmourArmourEvasionToWardPercent") or 0) / 100))
						end
					end
					gearEvasion = gearEvasion + evasionBase
					if breakdown then
						breakdown.slot(slot, nil, slotCfg, evasionBase, nil, "Evasion", "ArmourAndEvasion", "Defences")
					end
				end
			end
		end
		wardBase = modDB:Sum("BASE", nil, "Ward")

		if wardBase > 0 then
			if modDB:Flag(nil, "EnergyShieldToWard") then
				local inc = modDB:Sum("INC", nil, "Ward", "Defences", "EnergyShield")
				local more = modDB:More(nil, "Ward", "Defences")
				ward = ward + wardBase * (1 + inc / 100) * more
				if breakdown then
					t_insert(breakdown["Ward"].slots, {
						base = wardBase,
						inc = (inc ~= 0) and s_format(" x %.2f", 1 + inc/100),
						more = (more ~= 1) and s_format(" x %.2f", more),
						total = s_format("%.2f", wardBase * (1 + inc / 100) * more),
						source = "Global",
						item = actor.itemList["Global"],
					})
				end
			else
				ward = ward + wardBase * calcLib.mod(modDB, nil, "Ward", "Defences")
				if breakdown then
					breakdown.slot("Global", nil, nil, wardBase, nil, "Ward", "Defences")
				end
			end
		end
		energyShieldBase = modDB:Sum("BASE", nil, "EnergyShield")
		if energyShieldBase > 0 then
			if breakdown then
				local inc = modDB:Flag(nil, "EnergyShieldToWard") and 0 or modDB:Sum("INC", nil, "Defences", "EnergyShield")
				local more = modDB:More(nil, "EnergyShield", "Defences")
				t_insert(breakdown["EnergyShield"].slots, {
					base = energyShieldBase,
					inc = (inc ~= 0) and s_format(" x %.2f", 1 + inc/100),
					more = (more ~= 1) and s_format(" x %.2f", more),
					total = s_format("%.2f", energyShieldBase * (1 + inc / 100) * more),
					source = "Global",
					item = actor.itemList["Global"],
				})
			end
		end
		armourBase = modDB:Sum("BASE", nil, "Armour", "ArmourAndEvasion")
		if armourBase > 0 then
			if breakdown then
				breakdown.slot("Global", nil, nil, armourBase, nil, "Armour", "ArmourAndEvasion", "Defences")
			end
		end
		evasionBase = modDB:Sum("BASE", nil, "Evasion", "ArmourAndEvasion")
		if evasionBase > 0 then
			if breakdown then
				breakdown.slot("Global", nil, nil, evasionBase, nil, "Evasion", "ArmourAndEvasion", "Defences")
			end
		end

		local resourceList = {
			{ name = "Armour", basePerSlot = {}, globalBase = 0, conversionRate = { }, mods = { "Armour", "ArmourAndEvasion", "Defences" }, modsTotal = { "ArmourTotal" }, defence = true },
			{ name = "Evasion", basePerSlot = {}, globalBase = 0, conversionRate = { }, mods = { "Evasion", "ArmourAndEvasion", "Defences" }, modsTotal = { "EvasionTotal" }, defence = true },
			{ name = "EnergyShield", basePerSlot = {}, globalBase = 0, conversionRate = { }, mods = { "EnergyShield", "Defences" }, modsTotal = { "EnergyShieldTotal" }, defence = true },
			{ name = "Life", basePerSlot = {}, globalBase = 0, conversionRate = { }, mods = { "Life" }, modsTotal = { "LifeTotal" }, },
			{ name = "Mana", basePerSlot = {}, globalBase = 0, conversionRate = { }, mods = { "Mana" }, modsTotal = { "ManaTotal" }, },
		}
		for _, source in ipairs(resourceList) do
			output[source.name] = (output[source.name] or 0)
			local totalConversion = 0
			for _, target in ipairs(resourceList) do
				source.conversionRate[target.name] = m_min(modDB:Sum("BASE", nil, source.name.."ConvertTo"..target.name), 100)
				totalConversion = totalConversion + source.conversionRate[target.name]
			end
			if totalConversion > 100 then
				local factor = 100 / totalConversion
				totalConversion = 100
				for name, val in ipairs(source.conversionRate) do
					source.conversionRate[name] = val * factor
				end
			end
			source.totalConversion = totalConversion
			for _, slot in pairs({"Helmet","Gloves","Boots","Body Armour","Weapon 2","Weapon 3"}) do
				source.basePerSlot[slot] = actor.itemList[slot] and actor.itemList[slot].armourData and actor.itemList[slot].armourData[source.name] or 0
			end
		end
		for _, source in ipairs(resourceList) do
			local globalBase = modDB:Sum("BASE", nil, unpack(source.mods)) + source.globalBase
			for _, target in ipairs(resourceList) do
				if source.name ~= target.name then
					if source.defence then
						local gainRate = modDB:Sum("BASE", nil, source.name .. "GainAs" .. target.name)
						local rate = source.conversionRate[target.name] + gainRate
						if rate > 0 then
							for _, slot in pairs({ "Helmet", "Gloves", "Boots", "Body Armour", "Weapon 2", "Weapon 3" }) do
								if source.basePerSlot[slot] > 0 then
									local targetBase = source.basePerSlot[slot] * rate / 100
									if target.defence then
										target.basePerSlot[slot] = target.basePerSlot[slot] + targetBase
									else
										target.globalBase = target.globalBase + targetBase
									end
									if breakdown then
										breakdown.slot(slot, source.name .. " to " .. target.name .. " conversion", { slotName = slot }, targetBase, nil, unpack(target.mods))
									end
									source.basePerSlot[slot] = source.basePerSlot[slot] * (100 - source.totalConversion) / 100
								end
							end
							target.globalBase = target.globalBase + globalBase * rate / 100
							if breakdown then
								breakdown.slot("Global", source.name .. " to " .. target.name .. " conversion", nil, globalBase, nil, unpack(target.mods))
							end
						end
						source.globalBase = globalBase * (100 - source.totalConversion) / 100
					else
						local gainRate = modDB:Sum("BASE", nil, source.name .. "GainAs" .. target.name)
						local rate = source.conversionRate[target.name] + gainRate
						if rate > 0 then
							local targetBase = globalBase * rate / 100
							target.globalBase = target.globalBase + targetBase
							if breakdown then
								breakdown.slot("Conversion", source.name .. " to " .. target.name, nil, targetBase, nil, unpack(target.mods))
							end
						end
					end
				end
			end
		end
		for _, res in ipairs(resourceList) do
			if res.defence then
				for _, slot in pairs({"Helmet","Gloves","Boots","Body Armour","Weapon 2","Weapon 3"}) do
					output[res.name] = output[res.name] + res.basePerSlot[slot] * calcLib.mod(modDB, { slotName = slot }, unpack(res.mods))
				end
				output[res.name] = output[res.name] + res.globalBase * calcLib.mod(modDB, nil, unpack(res.mods)) + modDB:Sum("BASE", nil, unpack(res.modsTotal))
			else
				modDB:NewMod("Extra"..res.name, "BASE", res.globalBase, "Conversion")
			end
		end

		output.MaximumEnergyShield = modDB:Override(nil, "EnergyShield") or m_max(round(output.EnergyShield), 0)
		output.EnergyShield = output.MaximumEnergyShield
		if modDB:Flag(nil, "CannotHaveES") then
			output.EnergyShield = 0
		end

		output.Armour = m_max(round(output.Armour), 0)
		output.ArmourDefense = (modDB:Max(nil, "ArmourDefense") or 0) / 100
		output.RawArmourDefense = output.ArmourDefense > 0 and ((1 + output.ArmourDefense) * 100) or nil
		output.Evasion = m_max(round(output.Evasion), 0)
		output.MeleeEvasion = m_max(round(output.Evasion * calcLib.mod(modDB, nil, "MeleeEvasion")), 0)
		output.ProjectileEvasion = m_max(round(output.Evasion * calcLib.mod(modDB, nil, "ProjectileEvasion")), 0)
		output.LowestOfArmourAndEvasion = m_min(output.Armour, output.Evasion)
		output.Ward = m_max(m_floor(ward), 0)
		output["Gear:Ward"] = gearWard
		output["Gear:EnergyShield"] = gearEnergyShield
		output["Gear:Armour"] = gearArmour
		output["Gear:Evasion"] = gearEvasion
		output.CappingES = modDB:Flag(nil, "ArmourESRecoveryCap") and output.Armour < output.EnergyShield or modDB:Flag(nil, "EvasionESRecoveryCap") and output.Evasion < output.EnergyShield or env.configInput["conditionLowEnergyShield"]

		if output.CappingES then
			output.EnergyShieldRecoveryCap = modDB:Flag(nil, "ArmourESRecoveryCap") and modDB:Flag(nil, "EvasionESRecoveryCap") and m_min(output.Armour, output.Evasion) or modDB:Flag(nil, "ArmourESRecoveryCap") and output.Armour or modDB:Flag(nil, "EvasionESRecoveryCap") and output.Evasion or output.EnergyShield or 0
			output.EnergyShieldRecoveryCap = env.configInput["conditionLowEnergyShield"] and m_min(output.EnergyShield * data.misc.LowPoolThreshold, output.EnergyShieldRecoveryCap) or output.EnergyShieldRecoveryCap
		else
			output.EnergyShieldRecoveryCap = output.EnergyShield or 0
		end

		if modDB:Flag(nil, "CannotEvade") or enemyDB:Flag(nil, "CannotBeEvaded") then
			output.EvadeChance = 0
			output.MeleeEvadeChance = 0
			output.ProjectileEvadeChance = 0
		elseif modDB:Flag(nil, "AlwaysEvade") then
			output.EvadeChance = 100
			output.MeleeEvadeChance = 100
			output.ProjectileEvadeChance = 100
		else
			local enemyAccuracy = round(calcLib.val(enemyDB, "Accuracy"))
			if modDB:Flag(nil, "EnemyAccuracyDistancePenalty") then
				local enemyDistance = m_max(m_min(modDB:Sum("BASE", nil, "Multiplier:enemyDistance"), 120), 20)
				local accuracyPenalty = 1 - ((enemyDistance - 20) / 100) * (1 - 0.1)
				enemyAccuracy = m_floor(enemyAccuracy * accuracyPenalty)
			end
			local evadeChance = modDB:Sum("BASE", nil, "EvadeChance")
			local hitChance = calcLib.mod(enemyDB, nil, "HitChance")
			local evadeMax = modDB:Max(nil, "EvadeChanceMax") or data.misc.EvadeChanceCap
			output.EvadeChance = 100 - (calcs.hitChance(output.Evasion, enemyAccuracy) - evadeChance) * hitChance
			output.MeleeEvadeChance = m_max(0, m_min(evadeMax, (100 - (calcs.hitChance(output.MeleeEvasion, enemyAccuracy) - evadeChance) * hitChance) * calcLib.mod(modDB, nil, "EvadeChance", "MeleeEvadeChance")))
			output.ProjectileEvadeChance = m_max(0, m_min(evadeMax, (100 - (calcs.hitChance(output.ProjectileEvasion, enemyAccuracy) - evadeChance) * hitChance) * calcLib.mod(modDB, nil, "EvadeChance", "ProjectileEvadeChance")))
			-- Condition for displaying evade chance only if melee or projectile evade chance have the same values
			if output.MeleeEvadeChance ~= output.ProjectileEvadeChance then
				output.splitEvade = true
			else
				output.EvadeChance = output.MeleeEvadeChance
				output.noSplitEvade = true
			end
			output.EvadeChance = m_min(output.EvadeChance, evadeMax)
			if breakdown then
				breakdown.EvadeChance = {
					s_format("Enemy level: %d ^8(%s the Configuration tab)", env.enemyLevel, env.configInput.enemyLevel and "overridden from" or "can be overridden in"),
					s_format("Average enemy accuracy: %d", enemyAccuracy),
					s_format("Approximate evade chance: %d%%", output.EvadeChance),
				}
				breakdown.MeleeEvadeChance = {
					s_format("Enemy level: %d ^8(%s the Configuration tab)", env.enemyLevel, env.configInput.enemyLevel and "overridden from" or "can be overridden in"),
					s_format("Average enemy accuracy: %d", enemyAccuracy),
					s_format("Effective Evasion: %d", output.MeleeEvasion),
					s_format("Approximate melee evade chance: %d%%", output.MeleeEvadeChance),
				}
				breakdown.ProjectileEvadeChance = {
					s_format("Enemy level: %d ^8(%s the Configuration tab)", env.enemyLevel, env.configInput.enemyLevel and "overridden from" or "can be overridden in"),
					s_format("Average enemy accuracy: %d", enemyAccuracy),
					s_format("Effective Evasion: %d", output.ProjectileEvasion),
					s_format("Approximate projectile evade chance: %d%%", output.ProjectileEvadeChance),
				}
			end
		end
	end

	local spellSuppressionChance =  modDB:Sum("BASE", nil, "SpellSuppressionChance")
	local totalSpellSuppressionChance = modDB:Override(nil, "SpellSuppressionChance") or spellSuppressionChance

	-- Dodge
	-- Acrobatics Spell Suppression to Spell Dodge Chance conversion.
	if modDB:Flag(nil, "ConvertSpellSuppressionToSpellDodge") then
		modDB:NewMod("SpellDodgeChance", "BASE", spellSuppressionChance / 2, "Acrobatics")
	end
	
	output.SpellSuppressionChance = m_min(totalSpellSuppressionChance, data.misc.SuppressionChanceCap)
	output.SpellSuppressionEffect = m_max(data.misc.SuppressionEffect + modDB:Sum("BASE", nil, "SpellSuppressionEffect"), 0)
	
	do
		output.EffectiveSpellSuppressionChance = enemyDB:Flag(nil, "CannotBeSuppressed") and 0 or output.SpellSuppressionChance
		local luck = 1
		if env.mode_effective then
			luck = luck * (modDB:Flag(nil, "SpellSuppressionChanceIsLucky") and 2 or 1) / (modDB:Flag(nil, "SpellSuppressionChanceIsUnlucky") and 2 or 1)
		end
		-- unlucky config to lower the value of block, dodge, evade etc for ehp
		luck = luck / (env.configInput.EHPUnluckyWorstOf or 1)
		while luck ~= 1 do
			if luck > 1 then
				luck = luck / 2
				output.EffectiveSpellSuppressionChance = (1 - (1 - output.EffectiveSpellSuppressionChance / 100) ^ 2) * 100
			else
				luck = luck * 2
				output.EffectiveSpellSuppressionChance = output.EffectiveSpellSuppressionChance / 100 * output.EffectiveSpellSuppressionChance
			end
		end
	end
	
	output.SpellSuppressionChanceOverCap = m_max(0, totalSpellSuppressionChance - data.misc.SuppressionChanceCap)

	-- Dodge
	local totalAttackDodgeChance = modDB:Sum("BASE", nil, "AttackDodgeChance")
	local totalSpellDodgeChance = modDB:Sum("BASE", nil, "SpellDodgeChance")
	local attackDodgeChanceMax = data.misc.DodgeChanceCap
	local spellDodgeChanceMax = modDB:Override(nil, "SpellDodgeChanceMax") or modDB:Sum("BASE", nil, "SpellDodgeChanceMax")
	local enemyReduceDodgeChance = enemyDB:Sum("BASE", nil, "reduceEnemyDodge") or 0

	output.AttackDodgeChance = m_min(totalAttackDodgeChance, attackDodgeChanceMax)
	output.EffectiveAttackDodgeChance = enemyDB:Flag(nil, "CannotBeDodged") and 0 or m_min(m_max(totalAttackDodgeChance - enemyReduceDodgeChance, 0), attackDodgeChanceMax)
	output.SpellDodgeChance = m_min(totalSpellDodgeChance, spellDodgeChanceMax)
	output.EffectiveSpellDodgeChance = enemyDB:Flag(nil, "CannotBeDodged") and 0 or m_min(m_max(totalSpellDodgeChance - enemyReduceDodgeChance, 0), spellDodgeChanceMax)
	if env.mode_effective and modDB:Flag(nil, "DodgeChanceIsUnlucky") then
		output.EffectiveAttackDodgeChance = output.EffectiveAttackDodgeChance / 100 * output.EffectiveAttackDodgeChance
		output.EffectiveSpellDodgeChance = output.EffectiveSpellDodgeChance / 100 * output.EffectiveSpellDodgeChance
	end
	output.AttackDodgeChanceOverCap = m_max(0, totalAttackDodgeChance - attackDodgeChanceMax)
	output.SpellDodgeChanceOverCap = m_max(0, totalSpellDodgeChance - spellDodgeChanceMax)

	if breakdown then
		breakdown.AttackDodgeChance = {
			"Base: "..totalAttackDodgeChance.."%",
			"Max: "..attackDodgeChanceMax.."%",
			"Total: "..output.AttackDodgeChance+output.AttackDodgeChanceOverCap.."%",
		}
		breakdown.SpellDodgeChance = {
			"Base: "..totalSpellDodgeChance.."%",
			"Max: "..spellDodgeChanceMax.."%",
			"Total: "..output.SpellDodgeChance+output.SpellDodgeChanceOverCap.."%",
		}
	end

	-- Calculate life/mana pools
	calcs.doActorLifeManaSpirit(actor)

	-- Calculate life and mana reservations
	calcs.doActorLifeManaSpiritReservation(actor)

	-- Calculate darkness and darkness reservation
	calcs.doActorDarkness(actor)

	-- Stormweaver's Force of Will adds effect per max mana. Needs to happen before mana regen is calculated
	if modDB.conditions["AffectedByArcaneSurge"] or modDB:Flag(nil, "Condition:ArcaneSurge") then
		modDB.conditions["AffectedByArcaneSurge"] = true
		local effect = 1 + modDB:Sum("INC", nil, "ArcaneSurgeEffect", "BuffEffectOnSelf") / 100
		modDB:NewMod("ManaRegen", "MORE", (modDB:Max(nil, "ArcaneSurgeManaRegen") or 20) * effect, "Arcane Surge")
		modDB:NewMod("Speed", "MORE", (modDB:Max(nil, "ArcaneSurgeCastSpeed") or 10) * effect, "Arcane Surge", ModFlag.Cast)
		local arcaneSurgeDamage = modDB:Max(nil, "ArcaneSurgeDamage") or 0
		if arcaneSurgeDamage ~= 0 then modDB:NewMod("Damage", "MORE", arcaneSurgeDamage * effect, "Arcane Surge", ModFlag.Spell) end
	end

	-- Recovery modifiers
	output.LifeRecoveryRateMod = 1
	if not modDB:Flag(nil, "CannotRecoverLifeOutsideLeech") then
		output.LifeRecoveryRateMod = calcLib.mod(modDB, nil, "LifeRecoveryRate")
	end
	output.ManaRecoveryRateMod = calcLib.mod(modDB, nil, "ManaRecoveryRate")
	output.EnergyShieldRecoveryRateMod = calcLib.mod(modDB, nil, "EnergyShieldRecoveryRate")

	-- Leech caps
	output.MaxLifeLeechInstance = output.Life * calcLib.val(modDB, "MaxLifeLeechInstance") / 100
	output.MaxLifeLeechRatePercent = calcLib.val(modDB, "MaxLifeLeechRate")
	if modDB:Flag(nil, "MaximumLifeLeechIsEqualToParent") then
		output.MaxLifeLeechRatePercent = actor.parent.output.MaxLifeLeechRatePercent
	elseif modDB:Flag(nil, "MaximumLifeLeechIsEqualToPartyMember") then
		output.MaxLifeLeechRatePercent = actor.partyMembers.output.MaxLifeLeechRatePercent
	end
	output.MaxLifeLeechRate = output.Life * output.MaxLifeLeechRatePercent / 100
	if breakdown then
		breakdown.MaxLifeLeechRate = {
			s_format("%d ^8(maximum life)", output.Life),
			s_format("x %d%% ^8(percentage of life to maximum leech rate)", output.MaxLifeLeechRatePercent),
			s_format("= %.1f", output.MaxLifeLeechRate)
		}
	end
	output.MaxEnergyShieldLeechInstance = output.EnergyShield * calcLib.val(modDB, "MaxEnergyShieldLeechInstance") / 100
	output.MaxEnergyShieldLeechRate = output.EnergyShield * calcLib.val(modDB, "MaxEnergyShieldLeechRate") / 100
	if breakdown then
		breakdown.MaxEnergyShieldLeechRate = {
			s_format("%d ^8(maximum energy shield)", output.EnergyShield),
			s_format("x %d%% ^8(percentage of energy shield to maximum leech rate)", calcLib.val(modDB, "MaxEnergyShieldLeechRate")),
			s_format("= %.1f", output.MaxEnergyShieldLeechRate)
		}
	end
	output.MaxManaLeechInstance = output.Mana * calcLib.val(modDB, "MaxManaLeechInstance") / 100
	output.MaxManaLeechRate = output.Mana * calcLib.val(modDB, "MaxManaLeechRate") / 100
	if breakdown then
		breakdown.MaxManaLeechRate = {
			s_format("%d ^8(maximum mana)", output.Mana),
			s_format("x %d%% ^8(percentage of mana to maximum leech rate)", calcLib.val(modDB, "MaxManaLeechRate")),
			s_format("= %.1f", output.MaxManaLeechRate)
		}
	end

	-- Regeneration
	local resources = {"Mana", "Life", "Energy Shield", "Rage"}
	for i, resourceName in ipairs(resources) do
		local resource = resourceName:gsub(" ", "")
		local pool = output[resource] or 0
		local baseRegen = 0
		local inc = modDB:Sum("INC", nil, resource.."Regen", resource.."RecoveryRate")
		local more = modDB:More(nil, resource.."Regen", resource.."RecoveryRate")
		local regen = 0
		local regenRate = 0
		local recoveryRateMod = output[resource.."RecoveryRateMod"] or 1
		if modDB:Flag(nil, "No"..resource.."Regen") or modDB:Flag(nil, "CannotGain"..resource) then
			output[resource.."Regen"] = 0
		elseif resource == "Life" and modDB:Flag(nil, "ZealotsOath") then
			output.LifeRegen = 0
			local lifeBase = modDB:Sum("BASE", nil, "LifeRegen")
			if lifeBase > 0 then
				modDB:NewMod("EnergyShieldRegen", "BASE", lifeBase, "Zealot's Oath")
			end
			local lifePercent = modDB:Sum("BASE", nil, "LifeRegenPercent")
			if lifePercent > 0 then
				modDB:NewMod("EnergyShieldRegenPercent", "BASE", lifePercent, "Zealot's Oath")
			end
		else
			if inc ~= 0 then -- legacy chain breaker increase/decrease regen rate to different resource.
				for j=i+1,#resources do
					if modDB:Flag(nil, resource.."RegenTo"..resources[j]:gsub(" ", "").."Regen") then
						modDB:NewMod(resources[j]:gsub(" ", "").."Regen", "INC", inc, resourceName.." instead applies to "..resources[j])
						inc = 0
					end
				end
			end
			baseRegen = modDB:Sum("BASE", nil, resource.."Regen") + pool * modDB:Sum("BASE", nil, resource.."RegenPercent") / 100
			regen = baseRegen * (1 + inc/100) * more
			if regen ~= 0 then -- Pious Path
				for j=i+1,#resources do
					if modDB:Flag(nil, resource.."RegenerationRecovers"..resources[j]:gsub(" ", "")) then
						modDB:NewMod(resources[j]:gsub(" ", "").."Recovery", "BASE", regen, resourceName.." Regeneration Recovers "..resources[j])
					end
				end
			end
			regenRate = round(regen, 1)
			output[resource.."Regen"] = regenRate
		end
		output[resource.."RegenInc"] = inc
		local baseDegen = (modDB:Sum("BASE", nil, resource.."Degen") + pool * modDB:Sum("BASE", nil, resource.."DegenPercent") / 100)
		local degenRate = (baseDegen > 0) and baseDegen * calcLib.mod(modDB, nil, resource.."Degen") or 0
		output[resource.."Degen"] = degenRate
		local recoveryRate = modDB:Sum("BASE", nil, resource.."Recovery") * recoveryRateMod
		output[resource.."Recovery"] = recoveryRate
		output[resource.."RegenRecovery"] = (modDB:Flag(nil, "UnaffectedBy"..resource.."Regen") and 0 or regenRate) - degenRate + recoveryRate
		if output[resource.."RegenRecovery"] > 0 then
			modDB:NewMod("Condition:CanGain"..resource, "FLAG", true, resourceName.."Regen")
		end
		output[resource.."RegenPercent"] = pool > 0 and round(output[resource.."RegenRecovery"] / pool * 100, 1) or 0
		if breakdown then
			breakdown[resource.."RegenRecovery"] = { }
			breakdown.multiChain(breakdown[resource.."RegenRecovery"], {
				label = resourceName.." Regeneration:",
				base = { "%.1f ^8(base)", baseRegen },
				{ "%.2f ^8(increased/reduced)", 1 + inc/100 },
				{ "%.2f ^8(more/less)", more },
				total = s_format("= %.1f ^8per second", regenRate)
			})
			if modDB:Flag(nil, "UnaffectedBy"..resource.."Regen") then
				t_insert(breakdown[resource.."RegenRecovery"], "Unaffected by "..resourceName.." Regen")
			end
			if degenRate ~= 0 then
				t_insert(breakdown[resource.."RegenRecovery"], s_format("- %.1f ^8(degen)", degenRate))
				t_insert(breakdown[resource.."RegenRecovery"], s_format("= %.1f ^8per second", (modDB:Flag(nil, "UnaffectedBy"..resource.."Regen") and 0 or regenRate) - degenRate))
			end
			if recoveryRate ~= 0 then
				t_insert(breakdown[resource.."RegenRecovery"], s_format("+ %.1f ^8(recovery)", recoveryRate))
				t_insert(breakdown[resource.."RegenRecovery"], s_format("= %.1f ^8per second", output[resource.."RegenRecovery"]))
			end
		end
	end
	
	-- Energy Shield Recharge
	output.EnergyShieldRechargeAppliesToLife = modDB:Flag(nil, "EnergyShieldRechargeAppliesToLife") and not modDB:Flag(nil, "CannotRecoverLifeOutsideLeech") 
	output.EnergyShieldRechargeAppliesToEnergyShield = not (modDB:Flag(nil, "NoEnergyShieldRecharge") or modDB:Flag(nil, "CannotGainEnergyShield") or output.EnergyShieldRechargeAppliesToLife)
	
	if output.EnergyShieldRechargeAppliesToLife or output.EnergyShieldRechargeAppliesToEnergyShield then
		local inc = modDB:Sum("INC", nil, "EnergyShieldRecharge")
		local more = modDB:More(nil, "EnergyShieldRecharge")
		if output.EnergyShieldRechargeAppliesToLife then
			local recharge = output.Life * data.misc.EnergyShieldRechargeBase * (1 + inc/100) * more
			output.LifeRecharge = round(recharge * output.LifeRecoveryRateMod, 1)
			if breakdown then
				breakdown.LifeRecharge = { }
				breakdown.multiChain(breakdown.LifeRecharge, {
					label = "Recharge rate:",
					base = { "%.1f ^8(%.1f%% per second)", output.Life * data.misc.EnergyShieldRechargeBase, data.misc.EnergyShieldRechargeBase * 100 },
					{ "%.2f ^8(increased/reduced)", 1 + inc/100 },
					{ "%.2f ^8(more/less)", more },
					total = s_format("= %.1f ^8per second", recharge),
				})
				breakdown.multiChain(breakdown.LifeRecharge, {
					label = "Effective Recharge rate:",
					base = { "%.1f", recharge },
					{ "%.2f ^8(recovery rate modifier)", output.LifeRecoveryRateMod },
					total = s_format("= %.1f ^8per second", output.LifeRecharge),
				})	
			end
		else
			local recharge = output.EnergyShield * data.misc.EnergyShieldRechargeBase * (1 + inc/100) * more
			output.EnergyShieldRecharge = round(recharge * output.EnergyShieldRecoveryRateMod, 1)
			if breakdown then
				breakdown.EnergyShieldRecharge = { }
				breakdown.multiChain(breakdown.EnergyShieldRecharge, {
					label = "Recharge rate:",
					base = { "%.1f ^8(%.1f%% per second)", output.EnergyShield * data.misc.EnergyShieldRechargeBase, data.misc.EnergyShieldRechargeBase * 100 },
					{ "%.2f ^8(increased/reduced)", 1 + inc/100 },
					{ "%.2f ^8(more/less)", more },
					total = s_format("= %.1f ^8per second", recharge),
				})
				breakdown.multiChain(breakdown.EnergyShieldRecharge, {
					label = "Effective Recharge rate:",
					base = { "%.1f", recharge },
					{ "%.2f ^8(recovery rate modifier)", output.EnergyShieldRecoveryRateMod },
					total = s_format("= %.1f ^8per second", output.EnergyShieldRecharge),
				})
			end
		end
		local rechargeBase = modDB:Override(nil, "EnergyShieldRechargeBase") or data.misc.EnergyShieldRechargeDelay
		output.EnergyShieldRechargeDelay = rechargeBase / (1 + modDB:Sum("INC", nil, "EnergyShieldRechargeFaster") / 100)
		if breakdown then
			if output.EnergyShieldRechargeDelay ~= rechargeBase then
				breakdown.EnergyShieldRechargeDelay = {
					s_format("%.2fs ^8(base)", rechargeBase),
					s_format("/ %.2f ^8(faster start)", 1 + modDB:Sum("INC", nil, "EnergyShieldRechargeFaster") / 100),
					s_format("= %.2fs", output.EnergyShieldRechargeDelay)
				}
			end
		end
	else
		output.EnergyShieldRecharge = 0
	end
	
	-- recoup
	do
		output["anyRecoup"] = 0
		local recoupTypeList = {"Life", "Mana", "EnergyShield"}
		for _, recoupType in ipairs(recoupTypeList) do
			local baseRecoup = modDB:Sum("BASE", nil, recoupType.."Recoup")
			output[recoupType.."Recoup"] =  baseRecoup * output[recoupType.."RecoveryRateMod"]
			output["anyRecoup"] = output["anyRecoup"] + output[recoupType.."Recoup"]
			if breakdown then
				if output[recoupType.."RecoveryRateMod"] ~= 1 then
					breakdown[recoupType.."Recoup"] = {
						s_format("%d%% ^8(base)", baseRecoup),
						s_format("* %.2f ^8(recovery rate modifier)", output[recoupType.."RecoveryRateMod"]),
						s_format("= %.1f%% over %d seconds", output[recoupType.."Recoup"], (modDB:Flag(nil, "4Second"..recoupType.."Recoup") or modDB:Flag(nil, "4SecondRecoup")) and 4 or 8)
					}
				else
					breakdown[recoupType.."Recoup"] = { s_format("%d%% over %d seconds", output[recoupType.."Recoup"], (modDB:Flag(nil, "4Second"..recoupType.."Recoup") or modDB:Flag(nil, "4SecondRecoup")) and 4 or 8) }
				end
			end
		end

		local ElementalEnergyShieldRecoup = modDB:Sum("BASE", nil, "ElementalEnergyShieldRecoup")
		output.ElementalEnergyShieldRecoup = ElementalEnergyShieldRecoup * output.EnergyShieldRecoveryRateMod
		output["anyRecoup"] = output["anyRecoup"] + output.ElementalEnergyShieldRecoup
		if breakdown then
			if output.EnergyShieldRecoveryRateMod ~= 1 then
				breakdown.ElementalEnergyShieldRecoup = {
					s_format("%d%% ^8(base)", ElementalEnergyShieldRecoup),
					s_format("* %.2f ^8(recovery rate modifier)", output.EnergyShieldRecoveryRateMod),
					s_format("= %.1f%% over %d seconds", output.ElementalEnergyShieldRecoup, (modDB:Flag(nil, "4SecondEnergyShieldRecoup") or modDB:Flag(nil, "4SecondRecoup")) and 4 or 8)
				}
			else
				breakdown.ElementalEnergyShieldRecoup = { s_format("%d%% over %d seconds", output.ElementalEnergyShieldRecoup, (modDB:Flag(nil, "4SecondEnergyShieldRecoup") or modDB:Flag(nil, "4SecondRecoup")) and 4 or 8) }
			end
		end
		
		for _, damageType in ipairs(dmgTypeList) do
			local LifeRecoup = modDB:Sum("BASE", nil, damageType.."LifeRecoup")
			output[damageType.."LifeRecoup"] =  LifeRecoup * output.LifeRecoveryRateMod
			output["anyRecoup"] = output["anyRecoup"] + output[damageType.."LifeRecoup"]
			if breakdown then
				if output.LifeRecoveryRateMod ~= 1 then
					breakdown[damageType.."LifeRecoup"] = {
						s_format("%d%% ^8(base)", LifeRecoup),
						s_format("* %.2f ^8(recovery rate modifier)", output.LifeRecoveryRateMod),
						s_format("= %.1f%% over %d seconds", output[damageType.."LifeRecoup"], (modDB:Flag(nil, "4SecondLifeRecoup") or modDB:Flag(nil, "4SecondRecoup")) and 4 or 8)
					}
				else
					breakdown[damageType.."LifeRecoup"] = { s_format("%d%% over %d seconds", output[damageType.."LifeRecoup"], (modDB:Flag(nil, "4SecondLifeRecoup") or modDB:Flag(nil, "4SecondRecoup")) and 4 or 8) }
				end
			end
		end
		
		-- pseudo recoup (eg %physical damage prevented from hits regenerated)
		for _, resource in ipairs(recoupTypeList) do
			if not modDB:Flag(nil, "No"..resource.."Regen") and not modDB:Flag(nil, "CannotGain"..resource) then
				local PhysicalDamageMitigatedPseudoRecoup = modDB:Sum("BASE", nil, "PhysicalDamageMitigated"..resource.."PseudoRecoup")
				if PhysicalDamageMitigatedPseudoRecoup > 0 then
					output["PhysicalDamageMitigated"..resource.."PseudoRecoupDuration"] = modDB:Sum("BASE", nil, "PhysicalDamageMitigated"..resource.."PseudoRecoupDuration")
					if output["PhysicalDamageMitigated"..resource.."PseudoRecoupDuration"] == 0 then
						output["PhysicalDamageMitigated"..resource.."PseudoRecoupDuration"] = 4
					end
					local inc = modDB:Sum("INC", nil, resource.."Regen")
					local more = modDB:More(nil, resource.."Regen")
					output["PhysicalDamageMitigated"..resource.."PseudoRecoup"] = PhysicalDamageMitigatedPseudoRecoup * (1 + inc/100) * more * output[resource.."RecoveryRateMod"]
					output["anyRecoup"] = output["anyRecoup"] + output["PhysicalDamageMitigated"..resource.."PseudoRecoup"]
					if breakdown then
						breakdown["PhysicalDamageMitigated"..resource.."PseudoRecoup"] = { }
						if output[resource.."RecoveryRateMod"] ~= 1 or inc ~= 0 or more ~= 1 then
							t_insert(breakdown["PhysicalDamageMitigated"..resource.."PseudoRecoup"], s_format("%d%% ^8(base)", PhysicalDamageMitigatedPseudoRecoup))
							if inc ~= 0 or more ~= 1 then
								t_insert(breakdown["PhysicalDamageMitigated"..resource.."PseudoRecoup"], s_format("* %.2f ^8(regeneration rate modifier)", (1 + inc/100) * more))
							end
							if output[resource.."RecoveryRateMod"] ~= 1 then
								t_insert(breakdown["PhysicalDamageMitigated"..resource.."PseudoRecoup"], s_format("* %.2f ^8(recovery rate modifier)", output[resource.."RecoveryRateMod"]))
							end
						end
						t_insert(breakdown["PhysicalDamageMitigated"..resource.."PseudoRecoup"], s_format("= %.1f%% over %d seconds", output["PhysicalDamageMitigated"..resource.."PseudoRecoup"], output["PhysicalDamageMitigated"..resource.."PseudoRecoupDuration"]))
					end
				end
			end
		end
	end

	-- Ward recharge
	output.WardRechargeDelay = data.misc.WardRechargeDelay / (1 + modDB:Sum("INC", nil, "WardRechargeFaster") / 100)
	if breakdown then
		if output.WardRechargeDelay ~= data.misc.WardRechargeDelay then
			breakdown.WardRechargeDelay = {
				s_format("%.2fs ^8(base)", data.misc.WardRechargeDelay),
				s_format("/ %.2f ^8(faster start)", 1 + modDB:Sum("INC", nil, "WardRechargeFaster") / 100),
				s_format("= %.2fs", output.WardRechargeDelay)
			}
		end
	end

	-- Damage Reduction
	output.DamageReductionMax = modDB:Max(nil, "DamageReductionMax") or data.misc.DamageReductionCap
	modDB:NewMod("ArmourAppliesToPhysicalDamageTaken", "BASE", 100)
	for _, damageType in ipairs(dmgTypeList) do
		output[damageType.."DamageReductionMax"] = m_min(modDB:Max(nil, damageType.."DamageReductionMax") or data.misc.DamageReductionCap, output.DamageReductionMax)

		local base = m_max(0, modDB:Sum("BASE", nil, damageType.."DamageReduction", isElemental[damageType] and "ElementalDamageReduction"))
		local typeMax = m_min(base, output[damageType.."DamageReductionMax"])
		local globalMax = m_min(typeMax, output[damageType.."DamageReductionMax"])
		output["Base"..damageType.."DamageReduction"] = globalMax

		local baseWhenHit = globalMax + modDB:Sum("BASE", nil, damageType.."DamageReductionWhenHit")
		local typeMaxWhenHit = m_min(baseWhenHit, output[damageType.."DamageReductionMax"])
		local globalMaxWhenHit = m_min(typeMaxWhenHit, output[damageType.."DamageReductionMax"])
		output["Base"..damageType.."DamageReductionWhenHit"] = globalMaxWhenHit
	end

	-- Miscellaneous: move speed, avoidance, weapon swap speed
	output.MovementSpeedMod = modDB:Override(nil, "MovementSpeed") or (modDB:Flag(nil, "MovementSpeedEqualHighestLinkedPlayers") and actor.partyMembers.output.MovementSpeedMod or (round((1 + modDB:Sum("BASE", nil, "MovementSpeed")) * calcLib.mod(modDB, nil, "MovementSpeed"), 3)))
	if modDB:Flag(nil, "MovementSpeedCannotBeBelowBase") then
		output.MovementSpeedMod = m_max(output.MovementSpeedMod, 1)
	end
	output.EffectiveMovementSpeedMod = round(output.MovementSpeedMod * output.ActionSpeedMod, 3)
	if breakdown then
		breakdown.EffectiveMovementSpeedMod = { }
		breakdown.multiChain(breakdown.EffectiveMovementSpeedMod, {
			{ "%.3f ^8(movement speed modifier)", output.MovementSpeedMod },
			{ "%.2f ^8(action speed modifier)", output.ActionSpeedMod },
			total = s_format("= %.3f ^8(effective movement speed modifier)", output.EffectiveMovementSpeedMod)
		})
	end

	if enemyDB:Flag(nil, "Blind") then
		output.BlindEffectMod = calcLib.mod(enemyDB, nil, "BlindEffect", "BuffEffectOnSelf") * 100
	end

	output.WeaponSwapSpeed = modDB:Sum("BASE", nil, "WeaponSwapSpeed")
	output.WeaponSwapSpeedMod = calcLib.mod(modDB, nil, "WeaponSwapSpeed")
	output.WeaponSwapSpeed = output.WeaponSwapSpeed / output.WeaponSwapSpeedMod
	
	-- recovery on block, needs to be after primary defences
	output.LifeOnBlock = 0
	output.LifeOnSuppress = 0
	if not modDB:Flag(nil, "CannotRecoverLifeOutsideLeech") then
		output.LifeOnBlock = modDB:Sum("BASE", nil, "LifeOnBlock")
		output.LifeOnSuppress = modDB:Sum("BASE", nil, "LifeOnSuppress")
	end

	output.ManaOnBlock = modDB:Sum("BASE", nil, "ManaOnBlock")

	output.EnergyShieldOnBlock = modDB:Sum("BASE", nil, "EnergyShieldOnBlock")
	output.EnergyShieldOnSpellBlock = modDB:Sum("BASE", nil, "EnergyShieldOnSpellBlock")
	output.EnergyShieldOnSuppress = modDB:Sum("BASE", nil, "EnergyShieldOnSuppress")
	
	-- damage avoidances
	output.specificTypeAvoidance = false
	for _, damageType in ipairs(dmgTypeList) do
		output["Avoid"..damageType.."DamageChance"] = m_min(modDB:Sum("BASE", nil, "Avoid"..damageType.."DamageChance"), data.misc.AvoidChanceCap)
		if output["Avoid"..damageType.."DamageChance"] > 0 then
			output.specificTypeAvoidance = true
		end
	end
	output.AvoidProjectilesChance = m_min(modDB:Sum("BASE", nil, "AvoidProjectilesChance"), data.misc.AvoidChanceCap)
	-- hit avoidance
	output.AvoidAllDamageFromHitsChance = m_min(modDB:Sum("BASE", nil, "AvoidAllDamageFromHitsChance"), data.misc.AvoidChanceCap)
	-- other avoidances etc
	output.BlindAvoidChance = modDB:Flag(nil, "BlindImmune") and 100 or m_min(modDB:Sum("BASE", nil, "AvoidBlind"), 100)
	output.ImpaleAvoidChance = modDB:Flag(nil, "ImpaleImmune") and 100 or m_min(modDB:Sum("BASE", nil, "AvoidImpale"), 100)
	-- Status effect / ailment immunities
	output.CorruptedBloodImmunity = modDB:Flag(nil, "CorruptedBloodImmune")
	output.MaimImmunity = modDB:Flag(nil, "MaimImmune")
	output.HinderImmunity = modDB:Flag(nil, "HinderImmune")
	output.KnockbackImmunity = modDB:Flag(nil, "KnockbackImmune")

	if modDB:Flag(nil, "SpellSuppressionAppliesToAilmentAvoidance") then
		local spellSuppressionToAilmentPercent = (modDB:Sum("BASE", nil, "SpellSuppressionAppliesToAilmentAvoidancePercent") or 0) / 100
		-- Ancestral Vision
		modDB:NewMod("AvoidElementalAilments", "BASE", m_floor(spellSuppressionToAilmentPercent * spellSuppressionChance), "Ancestral Vision")
	end

	-- This is only used for breakdown purposes
	if modDB:Flag(nil, "ShockAvoidAppliesToElementalAilments") then
		local base = modDB:Sum("BASE", nil, "AvoidShock")
		if base ~= 0 then
			modDB:NewMod("AvoidShockAppliesToElementalAilments", "BASE", base, "Stormshroud");
		end
	end

	-- TODO: Calculate elemental ailment threshold by refactoring calcLib.val to allow for multiple mods, similar to calcLib.mod
	output.AilmentThreshold = calcLib.val(modDB, "AilmentThreshold")
	for _, ailment in ipairs(data.nonElementalAilmentTypeList) do
		output[ailment.."AvoidChance"] = modDB:Flag(nil, ailment.."Immune") and 100 or m_floor(m_min(modDB:Sum("BASE", nil, "Avoid"..ailment, "AvoidAilments"), 100))
	end
	for _, ailment in ipairs(data.elementalAilmentTypeList) do
		local shockAvoidAppliesToAll = modDB:Flag(nil, "ShockAvoidAppliesToElementalAilments") and ailment ~= "Shock"
		output[ailment.."AvoidChance"] = modDB:Flag(nil, ailment.."Immune", "ElementalAilmentImmune") and 100 or m_floor(m_min(modDB:Sum("BASE", nil, "Avoid"..ailment, "AvoidAilments", "AvoidElementalAilments") + (shockAvoidAppliesToAll and modDB:Sum("BASE", nil, "AvoidShock") or 0), 100))
	end

	output.CurseAvoidChance = modDB:Flag(nil, "CurseImmune") and 100 or m_min(modDB:Sum("BASE", nil, "AvoidCurse"), 100)
	output.SilenceAvoidChance = modDB:Flag(nil, "SilenceImmune") and 100 or output.CurseAvoidChance
	output.CritExtraDamageReduction = m_min(modDB:Sum("BASE", nil, "ReduceCritExtraDamage"), 100)
	output.LightRadiusMod = calcLib.mod(modDB, nil, "LightRadius")
	if breakdown then
		breakdown.LightRadiusMod = breakdown.mod(modDB, nil, "LightRadius")
	end
	output.CurseEffectOnSelf = modDB:More(nil, "CurseEffectOnSelf") * (100 + modDB:Sum("INC", nil, "CurseEffectOnSelf"))
	output.ExposureEffectOnSelf = modDB:More(nil, "ExposureEffectOnSelf") * (100 + modDB:Sum("INC", nil, "ExposureEffectOnSelf"))
	output.WitherEffectOnSelf = modDB:More(nil, "WitherEffectOnSelf") * (100 + modDB:Sum("INC", nil, "WitherEffectOnSelf"))

	-- Ailment duration on self
	output.DebuffExpirationRate = modDB:Sum("BASE", nil, "SelfDebuffExpirationRate")
	output.DebuffExpirationModifier = 10000 / (100 + output.DebuffExpirationRate)
	output.showDebuffExpirationModifier = (output.DebuffExpirationModifier ~= 100)
	output.SelfBlindDuration = modDB:More(nil, "SelfBlindDuration") * (100 + modDB:Sum("INC", nil, "SelfBlindDuration")) * output.DebuffExpirationModifier / 100

	-- This is only used for breakdown purposes
	if modDB:Flag(nil, "IgniteDurationAppliesToElementalAilments") then
		local inc = modDB:Sum("INC", nil, "SelfIgniteDuration");
		local more =  modDB:More(nil, "SelfIgniteDuration");
		if inc ~= 0 then
			modDB:NewMod("SelfIgniteDurationToElementalAilments", "INC", inc, "Firesong");
		end
		if more ~= 1 then
			modDB:NewMod("SelfIgniteDurationToElementalAilments", "MORE", more, "Firesong");
		end
	end

	for _, ailment in ipairs(data.nonElementalAilmentTypeList) do
		local more = modDB:More(nil, "Self"..ailment.."Duration", "SelfAilmentDuration")
		local inc = (100 + modDB:Sum("INC", nil, "Self"..ailment.."Duration", "SelfAilmentDuration")) * 100
		output["Self"..ailment.."Duration"] = inc * more / (100 + output.DebuffExpirationRate + modDB:Sum("BASE", nil, "Self"..ailment.."DebuffExpirationRate"))
	end
	for _, ailment in ipairs(data.elementalAilmentTypeList) do
		local igniteAppliesToAll = modDB:Flag(nil, "IgniteDurationAppliesToElementalAilments") and ailment ~= "Ignite"
		local more = modDB:More(nil, "Self"..ailment.."Duration", "SelfAilmentDuration", "SelfElementalAilmentDuration") * (igniteAppliesToAll and modDB:More(nil, "SelfIgniteDuration") or 1)
		local inc = (100 + modDB:Sum("INC", nil, "Self"..ailment.."Duration", "SelfAilmentDuration", "SelfElementalAilmentDuration") + (igniteAppliesToAll and modDB:Sum("INC", nil, "SelfIgniteDuration") or 0)) * 100
		output["Self"..ailment.."Duration"] = more * inc / (100 + output.DebuffExpirationRate + modDB:Sum("BASE", nil, "Self"..ailment.."DebuffExpirationRate"))
	end
	for _, ailment in ipairs(data.ailmentTypeList) do
		output["Self"..ailment.."Effect"] = calcLib.mod(modDB, nil, "Self"..ailment.."Effect") * (modDB:Flag(nil, "Condition:"..ailment.."edSelf") and calcLib.mod(modDB, nil, "Enemy"..ailment.."Magnitude", "AilmentMagnitude") or calcLib.mod(enemyDB, nil, "Enemy"..ailment.."Magnitude", "AilmentMagnitude")) * 100
	end
end

-- Performs all extra defensive calculations ( eg EHP, maxHit )
function calcs.buildDefenceEstimations(env, actor)
	local modDB = actor.modDB
	local enemyDB = actor.enemy.modDB
	local output = actor.output
	local breakdown = actor.breakdown

	local condList = modDB.conditions

	local damageCategoryConfig = env.configInput.enemyDamageType or "Average"
	
	-- chance to not be hit calculations
	if damageCategoryConfig ~= "DamageOverTime" then
		local worstOf = env.configInput.EHPUnluckyWorstOf or 1
		output.MeleeNotHitChance = 100 - (1 - output.MeleeEvadeChance / 100) * (1 - output.EffectiveAttackDodgeChance / 100) * (1 - output.AvoidAllDamageFromHitsChance / 100) * 100
		output.ProjectileNotHitChance = 100 - (1 - output.ProjectileEvadeChance / 100) * (1 - output.EffectiveAttackDodgeChance / 100) * (1 - output.AvoidAllDamageFromHitsChance / 100) * (1 - (output.specificTypeAvoidance and 0 or output.AvoidProjectilesChance) / 100) * 100
		output.SpellNotHitChance = 100 - (1 - output.EffectiveSpellDodgeChance / 100) * (1 - output.AvoidAllDamageFromHitsChance / 100) * 100
		output.SpellProjectileNotHitChance = 100 - (1 - output.EffectiveSpellDodgeChance / 100) * (1 - output.AvoidAllDamageFromHitsChance / 100) * (1 - (output.specificTypeAvoidance and 0 or output.AvoidProjectilesChance) / 100) * 100
		output.UntypedNotHitChance = 100 - (1 - output.AvoidAllDamageFromHitsChance / 100) * 100
		output.AverageNotHitChance = (output.MeleeNotHitChance + output.ProjectileNotHitChance + output.SpellNotHitChance + output.SpellProjectileNotHitChance) / 4
		output.AverageEvadeChance = (output.MeleeEvadeChance + output.ProjectileEvadeChance) / 4
		output.ConfiguredNotHitChance = output[damageCategoryConfig.."NotHitChance"]
		output.ConfiguredEvadeChance = output[damageCategoryConfig.."EvadeChance"] or 0
		-- unlucky config to lower the value of block, dodge, evade etc for ehp
		if worstOf > 1 then
			output.ConfiguredNotHitChance = output.ConfiguredNotHitChance / 100 * output.ConfiguredNotHitChance
			output.ConfiguredEvadeChance = output.ConfiguredEvadeChance / 100 * output.ConfiguredEvadeChance
			if worstOf == 4 then
				output.ConfiguredNotHitChance = output.ConfiguredNotHitChance / 100 * output.ConfiguredNotHitChance
				output.ConfiguredEvadeChance = output.ConfiguredEvadeChance / 100 * output.ConfiguredEvadeChance
			end
		end
	end

	--Enemy damage input and modifications
	output["totalEnemyDamage"] = 0
	output["totalEnemyDamageIn"] = 0
	if damageCategoryConfig == "DamageOverTime" then
		for _, damageType in ipairs(dmgTypeList) do
			output[damageType.."EnemyPen"] = 0
			output[damageType.."EnemyDamageMult"] = calcLib.mod(enemyDB, nil, "Damage", damageType.."Damage", isElemental[damageType] and "ElementalDamage" or nil) -- missing taunt from allies
			output[damageType.."EnemyOverwhelm"] = 0
			output[damageType.."EnemyDamage"] = 0
		end
	else
		if breakdown then
			breakdown["totalEnemyDamage"] = { 
				label = "Total damage from the enemy",
				rowList = { },
				colList = {
					{ label = "Type", key = "type" },
					{ label = "Value", key = "value" },
					{ label = "Mult", key = "mult" },
					{ label = "Crit", key = "crit" },
					{ label = "Conversion", key = "convMult" },
					{ label = "Final", key = "final" },
					{ label = "From", key = "from" },
				},
			}
		end
		local enemyCritChance = enemyDB:Flag(nil, "NeverCrit") and 0 or enemyDB:Flag(nil, "AlwaysCrit") and 100 or (m_max(m_min((modDB:Override(nil, "enemyCritChance") or env.configInput["enemyCritChance"] or env.configPlaceholder["enemyCritChance"] or 0) * (1 + modDB:Sum("INC", nil, "EnemyCritChance") / 100 + enemyDB:Sum("INC", nil, "CritChance") / 100) * (1 - output["ConfiguredEvadeChance"] / 100), 100), 0))
		output["EnemyCritChance"] = enemyCritChance
		local enemyCritDamage = m_max((env.configInput["enemyCritDamage"] or env.configPlaceholder["enemyCritDamage"] or 0) + enemyDB:Sum("BASE", nil, "CritMultiplier"), 0)
		output["EnemyCritEffect"] = 1 + enemyCritChance / 100 * (enemyCritDamage / 100) * (1 - output.CritExtraDamageReduction / 100)
		local enemyCfg = {keywordFlags = NOT64(KeywordFlag.MatchAll)} -- Match all keywordFlags parameter for enemy min-max damage mods
		local enemyDamageConversion = {}
		for _, damageType in ipairs(dmgTypeList) do
			local enemyDamageMult = calcLib.mod(enemyDB, nil, "Damage", damageType.."Damage", isElemental[damageType] and "ElementalDamage" or nil) -- missing taunt from allies
			local enemyDamage = tonumber(env.configInput["enemy"..damageType.."Damage"])
			local enemyPen = tonumber(env.configInput["enemy"..damageType.."Pen"])
			local enemyOverwhelm = tonumber(env.configInput["enemy"..damageType.."Overwhelm"])
			local sourceStr = enemyDamage == nil and "Default" or "Config"

			if enemyDamage == nil then
				enemyDamage = tonumber(env.configPlaceholder["enemy"..damageType.."Damage"]) or 0
			end
			if enemyPen == nil then
				enemyPen = tonumber(env.configPlaceholder["enemy"..damageType.."Pen"]) or 0
			end
			if enemyOverwhelm == nil then
				enemyOverwhelm = tonumber(env.configPlaceholder["enemy"..damageType.."enemyOverwhelm"]) or 0
			end
			
			-- Add min-max enemy damage from mods
			enemyDamage = enemyDamage + (enemyDB:Sum("BASE", enemyCfg, (damageType.."Min")) + enemyDB:Sum("BASE", enemyCfg, (damageType.."Max"))) / 2
			
			-- Conversion and Gain As Mods
			local conversionTotal = 0
			if damageType == "Physical" then
				local conversions = {total = 0, totalSkill = 0}
				for _, damageTypeTo in ipairs(dmgTypeList) do
					conversions[damageTypeTo.."skill"] = enemyDB:Sum("BASE", enemyCfg, (damageType.."DamageSkillConvertTo"..damageTypeTo))
					conversions[damageTypeTo] = enemyDB:Sum("BASE", enemyCfg, (damageType.."DamageConvertTo"..damageTypeTo))
					conversions["totalSkill"] = conversions["totalSkill"] + conversions[damageTypeTo.."skill"]
					conversions["total"] = conversions["total"] + conversions[damageTypeTo]
				end
				-- Cap the amount of conversion to 100%
				if conversions["totalSkill"] > 100 then
					local mult = 100 / conversions["totalSkill"]
					conversions["totalSkill"] = conversions["totalSkill"] * mult
					conversions["total"] = 0
					for _, damageTypeTo in ipairs(dmgTypeList) do
						conversions[damageTypeTo.."skill"] = conversions[damageTypeTo.."skill"] * mult
						conversions[damageTypeTo] = 0
					end
				elseif conversions["total"] + conversions["totalSkill"] > 100 then
					local mult = (100 - conversions["totalSkill"]) / conversions["total"]
					conversions["total"] = conversions["total"] * mult
					for _, damageTypeTo in ipairs(dmgTypeList) do
						conversions[damageTypeTo] = conversions[damageTypeTo] * mult
					end
				end
				conversionTotal = conversions["total"] + conversions["totalSkill"]
				-- Calculate the amount converted/gained as
				for _, damageTypeTo in ipairs(dmgTypeList) do
					local gainAsPercent = (enemyDB:Sum("BASE", enemyCfg, (damageType.."DamageGainAs"..damageTypeTo), ("DamageGainAs"..damageTypeTo)) + conversions[damageTypeTo.."skill"] + conversions[damageTypeTo]) / 100
					if gainAsPercent > 0 then
						enemyDamageConversion[damageTypeTo] = enemyDamageConversion[damageTypeTo] or { }
						enemyDamageConversion[damageTypeTo][damageType] = enemyDamage * gainAsPercent
					end
				end
			end
			
			enemyOverwhelm = enemyOverwhelm + enemyDB:Sum("BASE", nil, "PhysicalOverwhelm") + modDB:Sum("BASE", nil, "EnemyPhysicalOverwhelm")

			output[damageType.."EnemyPen"] = enemyPen
			output[damageType.."EnemyDamageMult"] = enemyDamageMult
			output[damageType.."EnemyOverwhelm"] = enemyOverwhelm
			output["totalEnemyDamageIn"] = output["totalEnemyDamageIn"] + enemyDamage
			output[damageType.."EnemyDamage"] = enemyDamage * (1 - conversionTotal/100) * enemyDamageMult * output["EnemyCritEffect"]
			local conversionExtra = -enemyDamage * enemyDamageMult * output["EnemyCritEffect"] + output[damageType.."EnemyDamage"]
			if enemyDamageConversion[damageType] then
				for damageTypeFrom, enemyDamage in pairs(enemyDamageConversion[damageType]) do
					local enemyDamageMult = calcLib.mod(enemyDB, nil, "Damage", damageType.."Damage", damageTypeFrom.."Damage", isElemental[damageType] and "ElementalDamage" or nil, isElemental[damageTypeFrom] and "ElementalDamage" or nil) -- missing taunt from allies
					output[damageType.."EnemyDamage"] = output[damageType.."EnemyDamage"] + enemyDamage * enemyDamageMult * output["EnemyCritEffect"]
					conversionExtra = conversionExtra + enemyDamage * enemyDamageMult * output["EnemyCritEffect"]
				end
			end
			output["totalEnemyDamage"] = output["totalEnemyDamage"] + output[damageType.."EnemyDamage"]
			if breakdown then
				breakdown[damageType.."EnemyDamage"] = {
				s_format("from %s: %d", sourceStr, enemyDamage),
				s_format("* %.2f (modifiers to enemy damage)", enemyDamageMult),
				s_format("* %.3f (enemy crit effect)", output["EnemyCritEffect"]),
				}
				if conversionExtra ~= 0 then
					t_insert(breakdown[damageType.."EnemyDamage"], s_format("%s %d (enemy damage conversion)", conversionExtra > 0 and "+" or "-", conversionExtra >= 0 and conversionExtra or -conversionExtra))
				end
				t_insert(breakdown[damageType.."EnemyDamage"], s_format("= %d", output[damageType.."EnemyDamage"]))
				t_insert(breakdown["totalEnemyDamage"].rowList, {
					type = s_format("%s", damageType),
					value = s_format("%d", enemyDamage),
					mult = s_format("%.2f", enemyDamageMult),
					crit = s_format("%.2f", output["EnemyCritEffect"]),
					convMult = s_format("%s%d", conversionExtra > 0 and "+" or (conversionExtra < 0 and "-" or ""), conversionExtra >= 0 and conversionExtra or -conversionExtra),
					final = s_format("%d", output[damageType.."EnemyDamage"]),
					from = s_format("%s", sourceStr),
				})
			end
		end
	end
	
	--Damage Taken as
	do
		actor.damageShiftTable = wipeTable(actor.damageShiftTable)
		actor.damageOverTimeShiftTable = wipeTable(actor.damageOverTimeShiftTable)
		for _, damageType in ipairs(dmgTypeList) do
			-- Build damage shift tables
			local shiftTable = { }
			local dotShiftTable = { }
			local destTotal = 0
			local dotDestinationTotal = 0
			for _, destType in ipairs(dmgTypeList) do
				if destType ~= damageType then
					dotShiftTable[destType] = modDB:Sum("BASE", nil, damageType.."DamageTakenAs"..destType, isElemental[damageType] and "ElementalDamageTakenAs"..destType or nil)
					dotDestinationTotal = dotDestinationTotal + dotShiftTable[destType]
					shiftTable[destType] = dotShiftTable[destType] + modDB:Sum("BASE", nil, damageType.."DamageFromHitsTakenAs"..destType, isElemental[damageType] and "ElementalDamageFromHitsTakenAs"..destType or nil)
					destTotal = destTotal + shiftTable[destType]
				end
			end
			dotShiftTable[damageType] = m_max(100 - dotDestinationTotal, 0)
			actor.damageOverTimeShiftTable[damageType] = dotShiftTable
			shiftTable[damageType] = m_max(100 - destTotal, 0)
			actor.damageShiftTable[damageType] = shiftTable
			
			--add same type damage
			output[damageType.."TakenDamage"] = output[damageType.."EnemyDamage"] * actor.damageShiftTable[damageType][damageType] / 100
			if breakdown then
				breakdown[damageType.."TakenDamage"] = { 
					label = "Taken",
					rowList = { },
					colList = {
						{ label = "Type", key = "type" },
						{ label = "Value", key = "value" },
					},
				}
				t_insert(breakdown[damageType.."TakenDamage"].rowList, {
					type = s_format("%s", damageType),
					value = s_format("%d", output[damageType.."TakenDamage"]),
				})
			end
		end
		--converted damage types
		for _, damageType in ipairs(dmgTypeList) do
			for _, damageConvertedType in ipairs(dmgTypeList) do
				if damageType ~= damageConvertedType then
					local damage = output[damageType.."EnemyDamage"] * actor.damageShiftTable[damageType][damageConvertedType] / 100
					output[damageConvertedType.."TakenDamage"] = output[damageConvertedType.."TakenDamage"] + damage
					if breakdown and damage > 0 then
						t_insert(breakdown[damageConvertedType.."TakenDamage"].rowList, {
							type = s_format("%s", damageType),
							value = s_format("%d", damage),
						})
					end
				end
			end
		end
		--total
		output["totalTakenDamage"] = 0
		if breakdown then
			breakdown["totalTakenDamage"] = { 
				label = "Total damage taken from the enemy after taken as",
				rowList = { },
				colList = {
					{ label = "Type", key = "type" },
					{ label = "Value", key = "value" },
				},
			}
		end
		for _, damageType in ipairs(dmgTypeList) do
			output["totalTakenDamage"] = output["totalTakenDamage"] + output[damageType.."TakenDamage"]
			if breakdown then
				t_insert(breakdown["totalTakenDamage"].rowList, {
					type = s_format("%s", damageType),
					value = s_format("%d", output[damageType.."TakenDamage"]),
				})
			end
		end
	end

	-- Damage taken multipliers/Degen calculations
	output.AnyTakenReflect = false
	for _, damageType in ipairs(dmgTypeList) do
		local baseTakenInc = modDB:Sum("INC", nil, "DamageTaken", damageType.."DamageTaken")
		local baseTakenMore = modDB:More(nil, "DamageTaken", damageType.."DamageTaken")
		if isElemental[damageType] then
			baseTakenInc = baseTakenInc + modDB:Sum("INC", nil, "ElementalDamageTaken")
			baseTakenMore = baseTakenMore * modDB:More(nil, "ElementalDamageTaken")
		end
		do	-- Hit
			local takenInc = baseTakenInc + modDB:Sum("INC", nil, "DamageTakenWhenHit", damageType.."DamageTakenWhenHit")
			local takenMore = baseTakenMore * modDB:More(nil, "DamageTakenWhenHit", damageType.."DamageTakenWhenHit")
			if isElemental[damageType] then
				takenInc = takenInc + modDB:Sum("INC", nil, "ElementalDamageTakenWhenHit")
				takenMore = takenMore * modDB:More(nil, "ElementalDamageTakenWhenHit")
			end
			output[damageType.."TakenHitMult"] = m_max((1 + takenInc / 100) * takenMore, 0)
			
			for _, hitType in ipairs(hitSourceList) do
				local baseTakenIncType = takenInc + modDB:Sum("INC", nil, hitType.."DamageTaken")
				local baseTakenMoreType = takenMore * modDB:More(nil, hitType.."DamageTaken")
				output[hitType.."TakenHitMult"] = m_max((1 + baseTakenIncType / 100) * baseTakenMoreType, 0)
				output[damageType..hitType.."TakenHitMult"] = output[hitType.."TakenHitMult"]
			end
			do
				-- Reflect
				takenInc = takenInc + modDB:Sum("INC", nil, "ReflectedDamageTaken", damageType.."ReflectedDamageTaken")
				takenMore = takenMore * modDB:More(nil, "ReflectedDamageTaken", damageType.."ReflectedDamageTaken")
				if isElemental[damageType] then
					takenInc = takenInc + modDB:Sum("INC", nil, "ElementalReflectedDamageTaken")
					takenMore = takenMore * modDB:More(nil, "ElementalReflectedDamageTaken")
				end
				output[damageType.."TakenReflect"] = m_max((1 + takenInc / 100) * takenMore, 0)
				if output[damageType.."TakenReflect"] ~= output[damageType.."TakenHitMult"] then
					output.AnyTakenReflect = false --true --this needs a rework as well
				end
			end
		end
		do	-- Dot
			local takenInc = baseTakenInc + modDB:Sum("INC", nil, "DamageTakenOverTime", damageType.."DamageTakenOverTime")
			local takenMore = baseTakenMore * modDB:More(nil, "DamageTakenOverTime", damageType.."DamageTakenOverTime")
			if isElemental[damageType] then
				takenInc = takenInc + modDB:Sum("INC", nil, "ElementalDamageTakenOverTime")
				takenMore = takenMore * modDB:More(nil, "ElementalDamageTakenOverTime")
			end
			local resist = modDB:Flag(nil, "SelfIgnore"..damageType.."Resistance") and 0 or output[damageType.."ResistOverTime"] or output[damageType.."Resist"]
			local reduction = modDB:Flag(nil, "SelfIgnore".."Base"..damageType.."DamageReduction") and 0 or output["Base"..damageType.."DamageReduction"]
			output[damageType.."TakenDotMult"] = m_max((1 - resist / 100) * (1 - reduction / 100) * (1 + takenInc / 100) * takenMore, 0)
			if breakdown then
				breakdown[damageType.."TakenDotMult"] = { }
				breakdown.multiChain(breakdown[damageType.."TakenDotMult"], {
					label = "DoT Multiplier:",
					{ "%.2f ^8(resistance)", (1 - resist / 100) },
					{ "%.2f ^8(%s damage reduction)", (1 - reduction / 100), damageType:lower() },
					{ "%.2f ^8(increased/reduced damage taken)", (1 + takenInc / 100) },
					{ "%.2f ^8(more/less damage taken)", takenMore },
					total = s_format("= %.2f", output[damageType.."TakenDotMult"]),
				})
			end
		end
	end

	-- Incoming hit damage multipliers
	output["totalTakenHit"] = 0
	if breakdown then
		breakdown["totalTakenHit"] = { 
			label = "Total damage taken after mitigation",
			rowList = { },
			colList = {
				{ label = "Type", key = "type" },
				{ label = "Incoming", key = "incoming" },
				{ label = "Mult", key = "mult" },
				{ label = "Value", key = "value" },
			},
		}
	end
	local enemyImpaleChance = (enemyDB:Sum("BASE", { flags = (damageCategoryConfig == "Melee" or damageCategoryConfig == "Projectile" or damageCategoryConfig == "Average") and ModFlag.Attack or 0, keywordFlags = 0 } , "ImpaleChance") or 0) * (damageCategoryConfig == "Average" and 0.5 or 1) * (1 - (output.ImpaleAvoidChance or 0))
	for _, damageType in ipairs(dmgTypeList) do
		-- Calculate incoming damage multiplier
		local resist = modDB:Flag(nil, "SelfIgnore"..damageType.."Resistance") and 0 or output[damageType.."ResistWhenHit"] or output[damageType.."Resist"]
		local reduction = modDB:Flag(nil, "SelfIgnore".."Base"..damageType.."DamageReduction") and 0 or output["Base"..damageType.."DamageReductionWhenHit"] or output["Base"..damageType.."DamageReduction"]
		local enemyPen = modDB:Flag(nil, "SelfIgnore"..damageType.."Resistance", "EnemyCannotPen"..damageType.."Resistance") and 0 or output[damageType.."EnemyPen"]
		local enemyOverwhelm = modDB:Flag(nil, "SelfIgnore"..damageType.."DamageReduction") and 0 or output[damageType.."EnemyOverwhelm"]
		local damage = output[damageType.."TakenDamage"]
		local impaleDamage = enemyImpaleChance > 0 and (damageType == "Physical" and (damage * data.misc.ImpaleStoredDamageBase) or 0) or 0
		
		--armour/PDR calculations
		local armourReduct = 0
		local impaleArmourReduct = 0
		local percentOfArmourApplies = m_min((not modDB:Flag(nil, "ArmourDoesNotApplyTo"..damageType.."DamageTaken") and modDB:Sum("BASE", nil, "ArmourAppliesTo"..damageType.."DamageTaken") or 0), 100)
		local effectiveAppliedArmour = (output.Armour * percentOfArmourApplies / 100) * (1 + output.ArmourDefense)
		local effectiveArmourFromArmour = effectiveAppliedArmour;
		local effectiveArmourFromOther = { }
		local evasionAddsToPdr = modDB:Flag(nil, "EvasionAddsToPdr") and damageType == "Physical"
		if evasionAddsToPdr then
			effectiveArmourFromOther["Evasion"] = output.Evasion 
		end
		for source, amount in pairs(effectiveArmourFromOther) do
			-- should this be done BEFORE percentOfArmourApplies and ArmourDefense is used? Probably needs GGG confirmation
			effectiveAppliedArmour = effectiveAppliedArmour + amount
		end
		
		local resMult = 1 - (resist > 0 and m_max(resist - enemyPen, 0) or resist) / 100
		local reductMult = 1
		local takenFlat = modDB:Sum("BASE", nil, "DamageTaken", damageType.."DamageTaken", "DamageTakenWhenHit", damageType.."DamageTakenWhenHit")
		if damageCategoryConfig == "Melee" or damageCategoryConfig == "Projectile" then
			takenFlat = takenFlat + modDB:Sum("BASE", nil, "DamageTakenFromAttacks", damageType.."DamageTakenFromAttacks", damageType.."DamageTakenFrom"..damageCategoryConfig.."Attacks")
		elseif damageCategoryConfig == "Spell" or damageCategoryConfig == "SpellProjectile" then
			takenFlat = takenFlat + modDB:Sum("BASE", nil, "DamageTakenFromSpells", damageType.."DamageTakenFromSpells", damageType.."DamageTakenFromSpellProjectiles")
		elseif damageCategoryConfig == "Average" then
			takenFlat = takenFlat + modDB:Sum("BASE", nil, "DamageTakenFromAttacks", damageType.."DamageTakenFromAttacks") / 2 + modDB:Sum("BASE", nil, damageType.."DamageTakenFromProjectileAttacks") / 4 + modDB:Sum("BASE", nil, "DamageTakenFromSpells", damageType.."DamageTakenFromSpells") / 2 + modDB:Sum("BASE", nil, "DamageTakenFromSpellProjectiles", damageType.."DamageTakenFromSpellProjectiles") / 4
		end
		output[damageType.."takenFlat"] = takenFlat
		if percentOfArmourApplies > 0 then
			armourReduct = calcs.armourReduction(effectiveAppliedArmour, damage)
			armourReduct = m_min(output[damageType.."DamageReductionMax"], armourReduct)
			if impaleDamage > 0 then
				impaleArmourReduct = m_min(output[damageType.."DamageReductionMax"], calcs.armourReduction(effectiveAppliedArmour, impaleDamage))
			end
		end
		local totalReduct = m_min(output[damageType.."DamageReductionMax"], armourReduct + reduction)
		reductMult = 1 - m_max(m_min(output[damageType.."DamageReductionMax"], totalReduct - enemyOverwhelm), 0) / 100
		output[damageType.."DamageReduction"] = 100 - reductMult * 100
		if impaleDamage > 0 then
			impaleDamage = impaleDamage * resMult * (1 - m_max(m_min(output[damageType.."DamageReductionMax"], m_min(output[damageType.."DamageReductionMax"], impaleArmourReduct + reduction) - enemyOverwhelm), 0) / 100)
			impaleDamage = impaleDamage * enemyImpaleChance / 100 * 5 * output[damageType.."TakenReflect"]
		end
		if breakdown then
			breakdown[damageType.."DamageReduction"] = { }
			if armourReduct ~= 0 then
				if percentOfArmourApplies ~= 100 then
					t_insert(breakdown[damageType.."DamageReduction"], s_format("%d%% percent of armour applies", percentOfArmourApplies))
				end
				if effectiveArmourFromArmour == effectiveAppliedArmour then
					t_insert(breakdown[damageType.."DamageReduction"], s_format("Reduction from Armour: %d%%", armourReduct))
				else
					t_insert(breakdown[damageType.."DamageReduction"], s_format("Armour contributing to reduction: %d", effectiveArmourFromArmour))
					for source, amount in pairs(effectiveArmourFromOther) do
						t_insert(breakdown[damageType.."DamageReduction"], s_format("%s contributing to reduction: %d",source, amount))
					end
					t_insert(breakdown[damageType.."DamageReduction"], s_format("Combined Armour used for reduction: %d", effectiveAppliedArmour))
					t_insert(breakdown[damageType.."DamageReduction"], s_format("Reduction from combined Armour: %d%%", armourReduct))
				end
				if resMult ~= 1 then
					t_insert(breakdown[damageType.."DamageReduction"], s_format("Enemy Hit Damage After Resistance: %d ^8(total incoming damage)", damage * resMult))
				else
					t_insert(breakdown[damageType.."DamageReduction"], s_format("Enemy Hit Damage: %d ^8(total incoming damage)", damage))
				end
			end
			if reduction ~= 0 then
				t_insert(breakdown[damageType.."DamageReduction"], s_format("Base %s Damage Reduction: %d%%", damageType, reduction))
			end
			if enemyOverwhelm ~= 0 then
				t_insert(breakdown[damageType.."DamageReduction"], s_format("Enemy Overwhelm %s Damage: %d%%", damageType, enemyOverwhelm))
			end
			if (armourReduct ~= 0 and 1 or 0) + (reduction ~= 0 and 1 or 0) + (enemyOverwhelm ~= 0 and 1 or 0) >= 2 then
				t_insert(breakdown[damageType.."DamageReduction"], s_format("Total %s Damage Reduction: %d%%", damageType, 100 - reductMult * 100))
			end
		end
		local takenMult = output[damageType.."TakenHitMult"]
		local spellSuppressMult = 1
		if damageCategoryConfig == "Melee" or damageCategoryConfig == "Projectile" then
			takenMult = output[damageType.."AttackTakenHitMult"]
		elseif damageCategoryConfig == "Spell" or damageCategoryConfig == "SpellProjectile" then
			takenMult = output[damageType.."SpellTakenHitMult"]
			spellSuppressMult = output.EffectiveSpellSuppressionChance == 100 and (1 - output.SpellSuppressionEffect / 100) or 1
		elseif damageCategoryConfig == "Average" then
			takenMult = (output[damageType.."SpellTakenHitMult"] + output[damageType.."AttackTakenHitMult"]) / 2
			spellSuppressMult = output.EffectiveSpellSuppressionChance == 100 and (1 - output.SpellSuppressionEffect / 100 / 2) or 1
		end
		output[damageType.."EffectiveAppliedArmour"] = effectiveAppliedArmour
		output[damageType.."ResistTakenHitMulti"] = resMult
		local afterReductionMulti = takenMult * spellSuppressMult
		output[damageType.."AfterReductionTakenHitMulti"] = afterReductionMulti
		local baseMult = resMult * reductMult
		output[damageType.."BaseTakenHitMult"] = baseMult * afterReductionMulti
		local takenMultReflect = output[damageType.."TakenReflect"]
		local finalReflect = baseMult * takenMultReflect
		output[damageType.."TakenHit"] = m_max(damage * baseMult + takenFlat, 0) * takenMult * spellSuppressMult + impaleDamage
		output[damageType.."TakenHitMult"] = (damage > 0) and (output[damageType.."TakenHit"] / damage) or 0
		output["totalTakenHit"] = output["totalTakenHit"] + output[damageType.."TakenHit"]
		if output.AnyTakenReflect then
			output[damageType.."TakenReflectMult"] = finalReflect
		end
		if breakdown then
			breakdown[damageType.."TakenHitMult"] = { }
			if reduction ~= 0 then
				t_insert(breakdown[damageType.."TakenHitMult"], s_format("Base %s Damage Reduction: %.2f", damageType, 1 - reduction / 100))
			end
			if armourReduct ~= 0 then
				if percentOfArmourApplies ~= 100 then
					t_insert(breakdown[damageType.."TakenHitMult"], s_format("%d%% percent of armour applies", percentOfArmourApplies))
				end
				if effectiveArmourFromArmour == effectiveAppliedArmour then
					t_insert(breakdown[damageType.."TakenHitMult"], s_format("Reduction from Armour: %.2f", 1 - armourReduct / 100))
				else
					t_insert(breakdown[damageType.."TakenHitMult"], s_format("Armour contributing to reduction: %d", effectiveArmourFromArmour))
					for source, amount in pairs(effectiveArmourFromOther) do
						t_insert(breakdown[damageType.."TakenHitMult"], s_format("%s contributing to reduction: %d",source, amount))
					end
					t_insert(breakdown[damageType.."TakenHitMult"], s_format("Combined Armour used for reduction: %d", effectiveAppliedArmour))
					t_insert(breakdown[damageType.."TakenHitMult"], s_format("Reduction from combined Armour: %.2f", 1 - armourReduct / 100))
				end
			end
			if enemyOverwhelm ~= 0 then
				t_insert(breakdown[damageType.."TakenHitMult"], s_format("+ Enemy Overwhelm %s Damage: %.2f", damageType, enemyOverwhelm / 100))
			end
			if reduction ~= 0 or armourReduct ~= 0 or enemyOverwhelm ~= 0 then
				t_insert(breakdown[damageType.."TakenHitMult"], s_format("= %.2f", reductMult))
			end
			if resist ~= 0 then
				t_insert(breakdown[damageType.."TakenHitMult"], s_format("Resistance: %.2f", 1 - resist / 100))
			end
			if enemyPen ~= 0 then
				t_insert(breakdown[damageType.."TakenHitMult"], s_format("+ Enemy Pen: %.2f", enemyPen / 100))
			end
			if resist <= 0 and enemyPen ~=0 then
				t_insert(breakdown[damageType.."TakenHitMult"], s_format("= %.2f ^8(Negative resistance unaffected by penetration)", resMult))
			elseif (resist - enemyPen) < 0 then
				t_insert(breakdown[damageType.."TakenHitMult"], s_format("= %.2f ^8(Penetration cannot bring resistances below 0)", resMult))
			elseif resist ~= 0 then
				t_insert(breakdown[damageType.."TakenHitMult"], s_format("= %.2f", resMult))
			end
			if resMult ~= 1 and reductMult ~= 1 then
				t_insert(breakdown[damageType.."TakenHitMult"], s_format("%.2f x %.2f = %.3f", resMult, reductMult, baseMult))
			end
			if takenFlat ~= 0 then
				t_insert(breakdown[damageType.."TakenHitMult"], s_format("+ Flat: %d", takenFlat))
			end
			if takenMult ~= 1 then
				t_insert(breakdown[damageType.."TakenHitMult"], s_format("x Taken: %.3f", takenMult))
			end
			if spellSuppressMult ~= 1 then
				t_insert(breakdown[damageType.."TakenHitMult"], s_format("x Spell Suppression: %.3f", spellSuppressMult))
			end
			if impaleDamage ~= 0 then
				t_insert(breakdown[damageType.."TakenHitMult"], s_format("+ Impale: %.1f", impaleDamage))
			end
			if takenMult ~= 1 or takenFlat ~= 0 or spellSuppressMult ~= 1 or impaleDamage ~= 0 then
				t_insert(breakdown[damageType.."TakenHitMult"], s_format("= %.3f", output[damageType.."TakenHitMult"]))
			end
			if output.AnyTakenReflect then
				breakdown[damageType.."TakenReflectMult"] = {
					s_format("Resistance: %.3f", 1 - resist / 100),
				}
				if enemyPen > 0 then
					t_insert(breakdown[damageType.."TakenReflectMult"], s_format("Enemy Pen: %.2f", enemyPen))
				end
				t_insert(breakdown[damageType.."TakenReflectMult"], s_format("Taken: %.3f", takenMultReflect))
				t_insert(breakdown[damageType.."TakenReflectMult"], s_format("= %.3f", finalReflect))
			end
		end
	end
	
	-- stun
	do
		local stunThresholdBase = 0
		local stunThresholdSource = nil
		if modDB:Flag(nil, "StunThresholdBasedOnEnergyShieldInsteadOfLife") then
			local stunThresholdMult = modDB:Sum("BASE", nil, "StunThresholdEnergyShieldPercent")
			stunThresholdBase = output.EnergyShield * stunThresholdMult / 100
			stunThresholdSource = stunThresholdMult.."% of Energy Shield"
		elseif modDB:Flag(nil, "StunThresholdBasedOnManaInsteadOfLife") then
			local stunThresholdMult = modDB:Sum("BASE", nil, "StunThresholdManaPercent")
			stunThresholdBase = output.Mana * stunThresholdMult / 100
			stunThresholdSource = stunThresholdMult.."% of Mana"
		elseif modDB:Flag(nil, "ChaosInoculation") then
			stunThresholdBase = modDB:Sum("BASE", nil, "Life")
			stunThresholdSource = "Life before Chaos Inoculation"
		else
			stunThresholdBase = output.Life
			stunThresholdSource = "Life"
		end
		if modDB:Flag(nil, "AddESToStunThreshold") then
			local ESMult = modDB:Sum("BASE", nil, "ESToStunThresholdPercent")
			stunThresholdBase = stunThresholdBase + output.EnergyShield * ESMult / 100
			stunThresholdSource = stunThresholdSource.." and "..ESMult.."% of Energy Shield"
		end
		local StunThresholdInc = 1 + modDB:Sum("INC", nil, "StunThreshold") / 100
		local StunThresholdMore = modDB:More("INC", nil, "StunThreshold")
		local StunThresholdModBase = modDB:Sum("BASE", nil, "StunThreshold")
		output.StunThreshold = (stunThresholdBase + StunThresholdModBase) * StunThresholdInc * StunThresholdMore
		
		local notAvoidChance = modDB:Flag(nil, "StunImmune") and 0 or 100 - m_min(modDB:Sum("BASE", nil, "AvoidStun"), 100)
		if output.EnergyShield > output["totalTakenHit"] and not env.modDB:Flag(nil, "EnergyShieldProtectsMana") then
			notAvoidChance = notAvoidChance * 0.5
		end
		output.StunAvoidChance = 100 - notAvoidChance
		
		if breakdown then
			breakdown.StunThreshold = { s_format("%d ^8(base from %s)", stunThresholdBase, stunThresholdSource) }
			for _, source in ipairs({"Tree", "Item", "Skill"}) do
				local sourceVal = modDB:Sum("BASE", { source = source }, "StunThreshold")
				if sourceVal > 0 then
					t_insert(breakdown.StunThreshold, s_format("+ %d ^8(base from %s)", sourceVal, source))
				end
			end
			if StunThresholdInc ~= 1 then
				t_insert(breakdown.StunThreshold, s_format("* %.2f ^8(increased threshold)", StunThresholdInc))
			end
			if StunThresholdMore ~= 1 then	
				t_insert(breakdown.StunThreshold, s_format("* %.2f ^8(more threshold)", StunThresholdMore))
			end
			if StunThresholdInc ~= 1 or StunThresholdMore ~= 1 then	
				t_insert(breakdown.StunThreshold, s_format("= %d", output.StunThreshold))
			end
			breakdown.StunAvoidChance = {
				colorCodes.CUSTOM.."NOTE: Having any energy shield when the hit occurs grants 50% chance to avoid stun.",
				colorCodes.CUSTOM.."POB only applies this modifier when ES > Total incoming damage.",
			}
		end
		if output.StunAvoidChance >= 100 then
			output.StunDuration = 0
			output.BlockDuration = 0
			if breakdown then
				breakdown.StunDuration = {"Cannot be Stunned"}
				breakdown.BlockDuration = {"Cannot be Stunned"}
			end
		else
			local stunDuration = (1 + modDB:Sum("INC", nil, "StunDuration") / 100)
			local baseStunDuration = data.misc.StunBaseDuration
			local stunRecovery = (1 + modDB:Sum("INC", nil, "StunRecovery") / 100)
			local stunAndBlockRecovery = (1 + modDB:Sum("INC", nil, "StunRecovery", "BlockRecovery") / 100)
			output.StunDuration = m_ceil(baseStunDuration * stunDuration / stunRecovery * data.misc.ServerTickRate) / data.misc.ServerTickRate
			output.BlockDuration = m_ceil(baseStunDuration * stunDuration / stunAndBlockRecovery * data.misc.ServerTickRate) / data.misc.ServerTickRate
			if breakdown then
				breakdown.StunDuration = {s_format("%.2fs ^8(base)", baseStunDuration)}
				breakdown.BlockDuration = {s_format("%.2fs ^8(base)", baseStunDuration)}
				if stunDuration ~= 1 then
					t_insert(breakdown.StunDuration, s_format("* %.2f ^8(increased duration)", stunDuration))
					t_insert(breakdown.BlockDuration, s_format("* %.2f ^8(increased duration)", stunDuration))
				end
				if stunRecovery ~= 1 then
					t_insert(breakdown.StunDuration, s_format("/ %.2f ^8(increased/reduced recovery)", stunRecovery))
				end
				if stunAndBlockRecovery ~= 1 then
					t_insert(breakdown.BlockDuration, s_format("/ %.2f ^8(increased/reduced block recovery)", stunAndBlockRecovery))
				end
				t_insert(breakdown.StunDuration, s_format("rounded up to nearest server tick"))
				t_insert(breakdown.StunDuration, s_format("= %.2fs", output.StunDuration))
				
				t_insert(breakdown.BlockDuration, s_format("rounded up to nearest server tick"))
				t_insert(breakdown.BlockDuration, s_format("= %.2fs", output.BlockDuration))
			end
		end
		output.InterruptStunAvoidChance = m_min(modDB:Sum("BASE", nil, "AvoidInterruptStun"), 100)
		local effectiveEnemyDamage = output["totalTakenHit"] + output["PhysicalTakenHit"] * 0.25
		if damageCategoryConfig ~= "Average" then
			effectiveEnemyDamage = effectiveEnemyDamage * (1 + data.misc.StunNotMeleeDamageMult * 3) / 4
		elseif damageCategoryConfig ~= "Melee" then
			effectiveEnemyDamage = effectiveEnemyDamage * data.misc.StunNotMeleeDamageMult
		end
		local baseStunChance = m_min(data.misc.StunBaseMult * effectiveEnemyDamage / output.StunThreshold, 100)
		output.SelfStunChance = (baseStunChance > data.misc.MinStunChanceNeeded and baseStunChance or 0) * notAvoidChance / 100
		if breakdown then
			breakdown.SelfStunChance = {
				s_format("%d%% ^8(stun multiplier)", data.misc.StunBaseMult),
				s_format("* %.1f ^8(effective enemy stun damage)", effectiveEnemyDamage),
				s_format("/ %d ^8(stun threshold)", output.StunThreshold)
			}
			if baseStunChance < data.misc.MinStunChanceNeeded then
				t_insert(breakdown.SelfStunChance, s_format("= %.2f%%", baseStunChance))
				t_insert(breakdown.SelfStunChance, s_format("Stun Chance has to be more than %d%% to stun.", data.misc.MinStunChanceNeeded))
			else
				if notAvoidChance ~= 100 then
					t_insert(breakdown.SelfStunChance, s_format("* %.2f ^8(1 - chance to avoid stun)", notAvoidChance / 100))
				end
				t_insert(breakdown.SelfStunChance, s_format("= %.2f%%", output.SelfStunChance))
			end
		end
	end
	
	-- Life Recoverable
	output.LifeRecoverable = output.LifeUnreserved
	if env.configInput["conditionLowLife"] then
		output.LifeRecoverable = m_min(output.Life * (output.LowLifePercentage or data.misc.LowPoolThreshold) / 100, output.LifeUnreserved)
		if output.LifeRecoverable < output.LifeUnreserved then
			output.CappingLife = true
		end
	end

	-- Dissolution of the flesh life pool change
	if modDB:Flag(nil, "DamageInsteadReservesLife") then 
		output.LifeRecoverable = (output.LifeCancellableReservation / 100) * output.Life
	end
	
	output.LifeRecoverable = m_max(output.LifeRecoverable, 1)
	
	-- Prevented life loss taken over 4 seconds (and Petrified Blood)
	do
		local recoverable = output.LifeRecoverable
		local preventedLifeLoss = m_min(modDB:Sum("BASE", nil, "LifeLossPrevented"), 100)
		output["preventedLifeLoss"] = preventedLifeLoss
		local initialLifeLossBelowHalfPrevented = modDB:Sum("BASE", nil, "LifeLossBelowHalfPrevented")
		output["preventedLifeLossBelowHalf"] = (1 - output["preventedLifeLoss"] / 100) * initialLifeLossBelowHalfPrevented
		local portionLife = 1
		if not env.configInput["conditionLowLife"] then
			--portion of life that is lowlife
			portionLife = m_min(output.Life * 0.5 / recoverable, 1)
			output["preventedLifeLossTotal"] = output["preventedLifeLoss"] + output["preventedLifeLossBelowHalf"] * portionLife
		else
			output["preventedLifeLossTotal"] = output["preventedLifeLoss"] + output["preventedLifeLossBelowHalf"]
		end
		output.LifeHitPool = calcLifeHitPoolWithLossPrevention(recoverable, output.Life, preventedLifeLoss, initialLifeLossBelowHalfPrevented)
		
		if breakdown then
			breakdown["preventedLifeLossTotal"] = {
				s_format("Total life protected:"),
			}
			if output["preventedLifeLoss"] ~= 0 then
				t_insert(breakdown["preventedLifeLossTotal"], s_format("%.2f ^8(portion taken over 4 seconds instead)", output["preventedLifeLoss"] / 100))
			end
			if output["preventedLifeLossBelowHalf"] ~= 0 then
				if portionLife ~= 1 then
					if output["preventedLifeLoss"] ~= 0 then
						t_insert(breakdown["preventedLifeLossTotal"], s_format(""))
					end
					t_insert(breakdown["preventedLifeLossTotal"], s_format("%s%.2f ^8(initial portion taken by petrified blood)", output["preventedLifeLoss"] ~= 0 and "+ " or "", initialLifeLossBelowHalfPrevented / 100))
					if output["preventedLifeLoss"] ~= 0 then
						t_insert(breakdown["preventedLifeLossTotal"], s_format("* %.2f ^8(portion not already taken over time)", (1 - output["preventedLifeLoss"] / 100)))
					end
					t_insert(breakdown["preventedLifeLossTotal"], s_format("* %.2f ^8(portion of life on low life)", portionLife))
					t_insert(breakdown["preventedLifeLossTotal"], s_format("= %.2f ^8(final portion taken by petrified blood)", output["preventedLifeLossBelowHalf"] * portionLife / 100))
					t_insert(breakdown["preventedLifeLossTotal"], s_format(""))
				else
					t_insert(breakdown["preventedLifeLossTotal"], s_format("%s%.2f ^8(%s taken by petrified blood)", output["preventedLifeLoss"] ~= 0 and "+ " or "", initialLifeLossBelowHalfPrevented / 100, output["preventedLifeLoss"] ~= 0 and "initial portion" or "portion"))
					if output["preventedLifeLoss"] ~= 0 then
						t_insert(breakdown["preventedLifeLossTotal"], s_format("* %.2f ^8(portion not already taken over time)", (1 - output["preventedLifeLoss"] / 100)))
						t_insert(breakdown["preventedLifeLossTotal"], s_format("= %.2f ^8(final portion taken by petrified blood)", output["preventedLifeLossBelowHalf"] / 100))
					end
				end
			end
			t_insert(breakdown["preventedLifeLossTotal"], s_format("%.2f ^8(portion taken from life)", 1 - output["preventedLifeLossTotal"] / 100))
		end
	end

	-- Energy Shield bypass
	output.AnyBypass = false
	output.MinimumBypass = 100
	for _, damageType in ipairs(dmgTypeList) do
		if modDB:Flag(nil, "UnblockedDamageDoesBypassES") then
			output[damageType.."EnergyShieldBypass"] = 100
			output.AnyBypass = true
		else
			output[damageType.."EnergyShieldBypass"] = modDB:Override(nil, damageType.."EnergyShieldBypass") or modDB:Sum("BASE", nil, damageType.."EnergyShieldBypass") or 0
			if output[damageType.."EnergyShieldBypass"] ~= 0 then
				output.AnyBypass = true
			end
		end
		output[damageType.."EnergyShieldBypass"] = m_max(m_min(output[damageType.."EnergyShieldBypass"], 100), 0)
		output.MinimumBypass = m_min(output.MinimumBypass, output[damageType.."EnergyShieldBypass"])
	end

	output.ehpSectionAnySpecificTypes = false
	-- Mind over Matter
	output.OnlySharedMindOverMatter = false
	output.AnySpecificMindOverMatter = false
	output["sharedMindOverMatter"] = m_min(modDB:Sum("BASE", nil, "DamageTakenFromManaBeforeLife"), 100)
	if output["sharedMindOverMatter"] > 0 then
		output.OnlySharedMindOverMatter = true
		local sourcePool = m_max(output.ManaUnreserved or 0, 0)
		local sourceHitPool = sourcePool
		local manatext = "unreserved mana"
		local esBypass = output.MinimumBypass / 100
		if modDB:Flag(nil, "EnergyShieldProtectsMana") and esBypass < 1 then
			manatext = manatext.." + non-bypassed energy shield"
			if esBypass > 0 then
				local manaProtected = m_min(sourcePool / esBypass - sourcePool, output.EnergyShieldRecoveryCap)
				sourcePool = m_max(sourcePool - manaProtected, -output.LifeRecoverable) + m_min(sourcePool + output.LifeRecoverable, manaProtected) / esBypass
				sourceHitPool = m_max(sourceHitPool - manaProtected, -output.LifeHitPool) + m_min(sourceHitPool + output.LifeHitPool, manaProtected) / esBypass
			else
				sourcePool = sourcePool + output.EnergyShieldRecoveryCap
				sourceHitPool = sourcePool
			end
		end
		local poolProtected = sourcePool / (output["sharedMindOverMatter"] / 100) * (1 - output["sharedMindOverMatter"] / 100)
		local hitPoolProtected = sourceHitPool / (output["sharedMindOverMatter"] / 100) * (1 - output["sharedMindOverMatter"] / 100)
		if output["sharedMindOverMatter"] >= 100 then
			poolProtected = m_huge
			output["sharedManaEffectiveLife"] = output.LifeRecoverable + sourcePool
			output["sharedMoMHitPool"] = output.LifeHitPool + sourceHitPool
		else
			output["sharedManaEffectiveLife"] = m_max(output.LifeRecoverable - poolProtected, 0) + m_min(output.LifeRecoverable, poolProtected) / (1 - output["sharedMindOverMatter"] / 100)
			output["sharedMoMHitPool"] = m_max(output.LifeHitPool - hitPoolProtected, 0) + m_min(output.LifeHitPool, hitPoolProtected) / (1 - output["sharedMindOverMatter"] / 100)
		end
		if breakdown then
			if output["sharedMindOverMatter"] then
				breakdown["sharedMindOverMatter"] = {
					s_format("Total life protected:"),
					s_format("%d ^8(%s)", sourcePool, manatext),
					s_format("/ %.2f ^8(portion taken from mana)", output["sharedMindOverMatter"] / 100),
					s_format("x %.2f ^8(portion taken from life)", 1 - output["sharedMindOverMatter"] / 100),
					s_format("= %d", poolProtected),
					s_format("Effective life: %d", output["sharedManaEffectiveLife"])
				}
			end
		end
	else
		output["sharedManaEffectiveLife"] = output.LifeRecoverable
		output["sharedMoMHitPool"] = output.LifeHitPool
	end
	for _, damageType in ipairs(dmgTypeList) do
		output[damageType.."MindOverMatter"] = m_min(modDB:Sum("BASE", nil, damageType.."DamageTakenFromManaBeforeLife"), 100 - output["sharedMindOverMatter"])
		if output[damageType.."MindOverMatter"] > 0 or (output[damageType.."EnergyShieldBypass"] > output.MinimumBypass and output["sharedMindOverMatter"] > 0) then
			local MindOverMatter = output[damageType.."MindOverMatter"] + output["sharedMindOverMatter"]
			output.ehpSectionAnySpecificTypes = true
			output.AnySpecificMindOverMatter = true
			output.OnlySharedMindOverMatter = false
			local sourcePool = m_max(output.ManaUnreserved or 0, 0)
			local sourceHitPool = sourcePool
			local manatext = "unreserved mana"
			if modDB:Flag(nil, "EnergyShieldProtectsMana") and output[damageType.."EnergyShieldBypass"] < 100 then
				manatext = manatext.." + non-bypassed energy shield"
				if output[damageType.."EnergyShieldBypass"] > 0 then
					local manaProtected = output.EnergyShieldRecoveryCap / (1 - output[damageType.."EnergyShieldBypass"] / 100) * (output[damageType.."EnergyShieldBypass"] / 100)
					sourcePool = m_max(sourcePool - manaProtected, -output.LifeRecoverable) + m_min(sourcePool + output.LifeRecoverable, manaProtected) / (output[damageType.."EnergyShieldBypass"] / 100)
					sourceHitPool = m_max(sourceHitPool - manaProtected, -output.LifeHitPool) + m_min(sourceHitPool + output.LifeHitPool, manaProtected) / (output[damageType.."EnergyShieldBypass"] / 100)
				else
					sourcePool = sourcePool + output.EnergyShieldRecoveryCap
					sourceHitPool = sourcePool
				end
			end
			local poolProtected = sourcePool / (MindOverMatter / 100) * (1 - MindOverMatter / 100)
			local hitPoolProtected = sourceHitPool / (MindOverMatter / 100) * (1 - MindOverMatter / 100)
			if MindOverMatter >= 100 then
				poolProtected = m_huge
				output[damageType.."ManaEffectiveLife"] = output.LifeRecoverable + sourcePool
				output[damageType.."MoMHitPool"] = output.LifeHitPool + sourceHitPool
			else
				output[damageType.."ManaEffectiveLife"] = m_max(output.LifeRecoverable - poolProtected, 0) + m_min(output.LifeRecoverable, poolProtected) / (1 - MindOverMatter / 100)
				output[damageType.."MoMHitPool"] = m_max(output.LifeHitPool - hitPoolProtected, 0) + m_min(output.LifeHitPool, hitPoolProtected) / (1 - MindOverMatter / 100)
			end
			if breakdown then
				if output[damageType.."MindOverMatter"] then
					breakdown[damageType.."MindOverMatter"] = {
						s_format("Total life protected:"),
						s_format("%d ^8(%s)", sourcePool, manatext),
						s_format("/ %.2f ^8(portion taken from mana)", MindOverMatter / 100),
						s_format("x %.2f ^8(portion taken from life)", 1 - MindOverMatter / 100),
						s_format("= %d", poolProtected),
						s_format("Effective life: %d", output[damageType.."ManaEffectiveLife"])
					}
				end
			end
		else
			output[damageType.."ManaEffectiveLife"] = output["sharedManaEffectiveLife"]
			output[damageType.."MoMHitPool"] = output["sharedMoMHitPool"]
		end
	end

	-- Guard
	output.AnyGuard = false
	output["sharedGuardAbsorbRate"] = m_min(modDB:Sum("BASE", nil, "GuardAbsorbRate"), 100)
	if output["sharedGuardAbsorbRate"] > 0 then
		output.OnlySharedGuard = true
		output["sharedGuardAbsorb"] = calcLib.val(modDB, "GuardAbsorbLimit")
		local lifeProtected = output["sharedGuardAbsorb"] / (output["sharedGuardAbsorbRate"] / 100) * (1 - output["sharedGuardAbsorbRate"] / 100)
		if breakdown then
			breakdown["sharedGuardAbsorb"] = {
				s_format("Total life protected:"),
				s_format("%d ^8(guard limit)", output["sharedGuardAbsorb"]),
				s_format("/ %.2f ^8(portion taken from guard)", output["sharedGuardAbsorbRate"] / 100),
				s_format("x %.2f ^8(portion taken from life and energy shield)", 1 - output["sharedGuardAbsorbRate"] / 100),
				s_format("= %d", lifeProtected)
			}
		end
	end
	for _, damageType in ipairs(dmgTypeList) do
		output[damageType.."GuardAbsorbRate"] = m_min(modDB:Sum("BASE", nil, damageType.."GuardAbsorbRate"), 100)
		if output[damageType.."GuardAbsorbRate"] > 0 then
			output.ehpSectionAnySpecificTypes = true
			output.AnyGuard = true
			output.OnlySharedGuard = false
			output[damageType.."GuardAbsorb"] = calcLib.val(modDB, damageType.."GuardAbsorbLimit")
			local lifeProtected = output[damageType.."GuardAbsorb"] / (output[damageType.."GuardAbsorbRate"] / 100) * (1 - output[damageType.."GuardAbsorbRate"] / 100)
			if breakdown then
				breakdown[damageType.."GuardAbsorb"] = {
					s_format("Total life protected:"),
					s_format("%d ^8(guard limit)", output[damageType.."GuardAbsorb"]),
					s_format("/ %.2f ^8(portion taken from guard)", output[damageType.."GuardAbsorbRate"] / 100),
					s_format("x %.2f ^8(portion taken from life and energy shield)", 1 - output[damageType.."GuardAbsorbRate"] / 100),
					s_format("= %d", lifeProtected),
				}
			end
		end
	end
	
	--aegis
	output.AnyAegis = false
	output["sharedAegis"] = modDB:Max(nil, "AegisValue") or 0
	output["sharedElementalAegis"] = modDB:Max(nil, "ElementalAegisValue") or 0
	if output["sharedAegis"] > 0 then
		output.AnyAegis = true
	end
	if output["sharedElementalAegis"] > 0 then
		output.ehpSectionAnySpecificTypes = true
		output.AnyAegis = true
	end
	for _, damageType in ipairs(dmgTypeList) do
		local aegisValue = modDB:Max(nil, damageType.."AegisValue") or 0
		if aegisValue > 0 then
			output.ehpSectionAnySpecificTypes = true
			output.AnyAegis = true
			output[damageType.."Aegis"] = aegisValue
		else
			output[damageType.."Aegis"] = 0
		end
		if isElemental[damageType] then
			output[damageType.."AegisDisplay"] = output[damageType.."Aegis"] + output["sharedElementalAegis"]
		end
	end
	
	-- taken from allies before you, eg. frost shield
	do
		-- frost shield
		output["FrostShieldLife"] = modDB:Sum("BASE", nil, "FrostGlobeHealth")
		output["FrostShieldDamageMitigation"] = modDB:Sum("BASE", nil, "FrostGlobeDamageMitigation")
		
		local lifeProtected = output["FrostShieldLife"] / (output["FrostShieldDamageMitigation"] / 100) * (1 - output["FrostShieldDamageMitigation"] / 100)
		if breakdown then
			breakdown["FrostShieldLife"] = {
				s_format("Total life protected:"),
				s_format("%d ^8(frost shield limit)", output["FrostShieldLife"]),
				s_format("/ %.2f ^8(portion taken from frost shield)", output["FrostShieldDamageMitigation"] / 100),
				s_format("x %.2f ^8(portion taken from life and energy shield)", 1 - output["FrostShieldDamageMitigation"] / 100),
				s_format("= %d", lifeProtected),
			}
		end
		
		-- from spectres
		output["SpectreAllyDamageMitigation"] = modDB:Sum("BASE", nil, "takenFromSpectresBeforeYou")
		if output["SpectreAllyDamageMitigation"] ~= 0 then
			output["TotalSpectreLife"] = modDB:Sum("BASE", nil, "TotalSpectreLife")
		end
		
		-- from totems
		output["TotemAllyDamageMitigation"] = modDB:Sum("BASE", nil, "takenFromTotemsBeforeYou")
		if output["TotemAllyDamageMitigation"] ~= 0 then
			output["TotalTotemLife"] = modDB:Sum("BASE", nil, "TotalTotemLife")
		end
		
		-- from VaalRejuveTotem
		output["VaalRejuvenationTotemAllyDamageMitigation"] = modDB:Sum("BASE", nil, "takenFromVaalRejuvenationTotemsBeforeYou") + output["TotemAllyDamageMitigation"]
		if output["VaalRejuvenationTotemAllyDamageMitigation"] ~= output["TotemAllyDamageMitigation"] then
			output["TotalVaalRejuvenationTotemLife"] = modDB:Sum("BASE", nil, "TotalVaalRejuvenationTotemLife")
		end
		
		-- from Sentinel of Radiance
		output["RadianceSentinelAllyDamageMitigation"] = modDB:Sum("BASE", nil, "takenFromRadianceSentinelBeforeYou")
		if output["RadianceSentinelAllyDamageMitigation"] ~= 0 then
			output["TotalRadianceSentinelLife"] = modDB:Sum("BASE", nil, "TotalRadianceSentinelLife")
		end
		
		-- from Allied Energy Shield
		output["SoulLinkMitigation"] = modDB:Sum("BASE", nil, "TakenFromParentESBeforeYou")
		if output["SoulLinkMitigation"] ~= 0 then
			output["AlliedEnergyShield"] = actor.parent.output.EnergyShieldRecoveryCap or 0
		else
			output["SoulLinkMitigation"] = modDB:Sum("BASE", nil, "TakenFromPartyMemberESBeforeYou")
			if output["SoulLinkMitigation"] ~= 0 then
				output["AlliedEnergyShield"] = actor.partyMembers.output.EnergyShieldRecoveryCap or 0
			end
		end
	end
	
	-- Vaal Arctic Armour
	do
		output["VaalArcticArmourLife"] = modDB:Sum("BASE", nil, "VaalArcticArmourMaxHits")
		output["VaalArcticArmourMitigation"] = m_min(-modDB:Sum("MORE", nil, "VaalArcticArmourMitigation") / 100, 1)
	end

	--total pool
	for _, damageType in ipairs(dmgTypeList) do
		output[damageType.."TotalPool"] = output[damageType.."ManaEffectiveLife"]
		output[damageType.."TotalHitPool"] = output[damageType.."MoMHitPool"]
		local esBypass = output[damageType.."EnergyShieldBypass"] / 100
		local chaosESMultiplier = damageType == "Chaos" and 2 or 1
		if modDB:Flag(nil, "EternalLife") then
			output[damageType.."TotalPool"] = output[damageType.."TotalPool"] + output.EnergyShieldRecoveryCap / (1 - esBypass) / chaosESMultiplier
			output[damageType.."TotalHitPool"] = output[damageType.."TotalHitPool"] + output.EnergyShieldRecoveryCap / (1 - esBypass) / chaosESMultiplier
		elseif esBypass < 1 then 
			if esBypass > 0 then
				local poolProtected = output.EnergyShieldRecoveryCap / (1 - esBypass) * esBypass / chaosESMultiplier
				output[damageType.."TotalPool"] = m_max(output[damageType.."TotalPool"] - poolProtected, 0) + m_min(output[damageType.."TotalPool"], poolProtected) / esBypass
				output[damageType.."TotalHitPool"] = m_max(output[damageType.."TotalHitPool"] - poolProtected, 0) + m_min(output[damageType.."TotalHitPool"], poolProtected) / esBypass
			else
				output[damageType.."TotalPool"] = output[damageType.."TotalPool"] + output.EnergyShieldRecoveryCap / chaosESMultiplier
				output[damageType.."TotalHitPool"] = output[damageType.."TotalHitPool"] + output.EnergyShieldRecoveryCap / chaosESMultiplier
			end
		end
		if breakdown then
			breakdown[damageType.."TotalPool"] = {
				s_format("Life: %d", output.LifeRecoverable)
			}
			if output[damageType.."ManaEffectiveLife"] ~= output.LifeRecoverable then
				t_insert(breakdown[damageType.."TotalPool"], s_format("Mana through MoM: %d", output[damageType.."ManaEffectiveLife"] - output.LifeRecoverable))
			end
			if modDB:Flag(nil, "EternalLife") then
				t_insert(breakdown[damageType.."TotalPool"], s_format("Energy Shield: %d%s", output.EnergyShieldRecoveryCap / chaosESMultiplier, damageType == "Chaos" and "^8 (ES takes double damage from chaos)" or ""))
				t_insert(breakdown[damageType.."TotalPool"], s_format("Life change prevented by Eternal Life: %d", output[damageType.."TotalPool"] - output[damageType.."ManaEffectiveLife"] - output.EnergyShieldRecoveryCap / chaosESMultiplier))
			elseif esBypass < 1 then
				t_insert(breakdown[damageType.."TotalPool"], s_format("Non-bypassed Energy Shield: %d", output[damageType.."TotalPool"] - output[damageType.."ManaEffectiveLife"]))
			end
			t_insert(breakdown[damageType.."TotalPool"], s_format("Total Pool: %d", output[damageType.."TotalPool"]))
		end
	end
	
	-- helper function that iteratively reduces pools until life hits 0 to determine the number of hits it would take with given damage to die
	local function numberOfHitsToDie(DamageIn)
		local numHits = 0
		DamageIn["cycles"] = DamageIn["cycles"] or 1
		DamageIn["iterations"] = DamageIn["iterations"] or 0
		
		-- check damage in isn't 0 and that ward doesn't mitigate all damage
		for _, damageType in ipairs(dmgTypeList) do
			numHits = numHits + DamageIn[damageType]
		end
		if numHits == 0 then
			return m_huge
		elseif modDB:Flag(nil, "WardNotBreak") and output.Ward > 0 and numHits < output.Ward then
			return m_huge
		else
			numHits = 0
		end

		local ward = output.Ward or 0
		-- don't apply non-perma ward for speed up calcs as it won't zero it correctly per hit
		if (not modDB:Flag(nil, "WardNotBreak")) and DamageIn["cycles"] > 1 then
			ward = 0
		end
		local aegis = { }
		aegis["shared"] = output["sharedAegis"] or 0
		aegis["sharedElemental"] = output["sharedElementalAegis"] or 0
		local guard = { }
		guard["shared"] = output.sharedGuardAbsorb or 0
		for _, damageType in ipairs(dmgTypeList) do
			aegis[damageType] = output[damageType.."Aegis"] or 0
			guard[damageType] = output[damageType.."GuardAbsorb"] or 0
		end
		local alliesTakenBeforeYou = {}
		if output.FrostShieldLife then
			alliesTakenBeforeYou["frostShield"] = { remaining = output.FrostShieldLife, percent = output.FrostShieldDamageMitigation / 100 }
		end
		if output.TotalSpectreLife then
			alliesTakenBeforeYou["spectres"] = { remaining = output.TotalSpectreLife, percent = output.SpectreAllyDamageMitigation / 100 }
		end
		if output.TotalTotemLife then
			alliesTakenBeforeYou["totems"] = { remaining = output.TotalTotemLife, percent = output.TotemAllyDamageMitigation / 100 }
		end
		if output.TotalVaalRejuvenationTotemLife then
			alliesTakenBeforeYou["vaalRejuvenationTotems"] = { remaining = output.TotalVaalRejuvenationTotemLife, percent = output.VaalRejuvenationTotemAllyDamageMitigation / 100 }
		end
		if output.TotalRadianceSentinelLife then
			alliesTakenBeforeYou["radianceSentinel"] = { remaining = output.TotalRadianceSentinelLife, percent = output.RadianceSentinelAllyDamageMitigation / 100 }
		end
		if output.AlliedEnergyShield then
			alliesTakenBeforeYou["soulLink"] = { remaining = output.AlliedEnergyShield, percent = output.SoulLinkMitigation / 100 }
		end
		
		local poolTable = {
			AlliesTakenBeforeYou = alliesTakenBeforeYou,
			Aegis = aegis,
			Guard = guard,
			Ward = ward,
			EnergyShield = output.EnergyShieldRecoveryCap,
			Mana = output.ManaUnreserved or 0,
			Life = output.LifeRecoverable or 0,
			LifeLossLostOverTime = output.LifeLossLostOverTime or 0,
			LifeBelowHalfLossLostOverTime = output.LifeBelowHalfLossLostOverTime or 0,
			damageTakenThatCanBeRecouped = { }
		}
		
		if DamageIn["cycles"] == 1 then
			DamageIn["TrackRecoupable"] = DamageIn["TrackRecoupable"] or false
			DamageIn["TrackLifeLossOverTime"] = DamageIn["TrackLifeLossOverTime"] or false
		else
			DamageIn["TrackRecoupable"] = false
			DamageIn["TrackLifeLossOverTime"] = false
		end
		DamageIn["WardBypass"] = DamageIn["WardBypass"] or modDB:Sum("BASE", nil, "WardBypass") or 0
		
		local VaalArcticArmourHitsLeft = output.VaalArcticArmourLife
		if DamageIn["cycles"] > 1 then
			VaalArcticArmourHitsLeft = 0
		end

		local iterationMultiplier = 1
		local damageTotal = 0
		local maxDamage = data.misc.ehpCalcMaxDamage
		local maxIterations = data.misc.ehpCalcMaxIterationsToCalc
		while poolTable.Life > 0 and DamageIn["iterations"] < maxIterations do
			DamageIn["iterations"] = DamageIn["iterations"] + 1
			local Damage = { }
			damageTotal = 0
			local VaalArcticArmourMultiplier = VaalArcticArmourHitsLeft > 0 and (( 1 - output["VaalArcticArmourMitigation"] * m_min(VaalArcticArmourHitsLeft / iterationMultiplier, 1))) or 1
			VaalArcticArmourHitsLeft = VaalArcticArmourHitsLeft - iterationMultiplier
			for _, damageType in ipairs(dmgTypeList) do
				local damage = DamageIn[damageType] or 0
				Damage[damageType] = damage > 0 and damage * iterationMultiplier * VaalArcticArmourMultiplier or nil
				damageTotal = damageTotal + damage
			end
			if DamageIn.GainWhenHit and (iterationMultiplier > 1 or DamageIn["cycles"] > 1) then
				local gainMult = iterationMultiplier * DamageIn["cycles"]
				poolTable.Life = m_min(poolTable.Life + DamageIn.LifeWhenHit * (gainMult - 1), gainMult * (output.LifeRecoverable or 0))
				poolTable.Mana = m_min(poolTable.Mana + DamageIn.ManaWhenHit * (gainMult - 1), gainMult * (output.ManaUnreserved or 0))
				poolTable.EnergyShield = m_min(poolTable.EnergyShield + DamageIn.EnergyShieldWhenHit * (gainMult - 1), gainMult * output.EnergyShieldRecoveryCap)
			end
			poolTable = calcs.reducePoolsByDamage(poolTable, Damage, actor)
			
			-- If still living and the amount of damage exceeds maximum threshold we survived infinite number of hits.
			if poolTable.Life > 0 and damageTotal >= maxDamage then
				return m_huge
			end
			if DamageIn.GainWhenHit and poolTable.Life > 0 then
				poolTable.Life = m_min(poolTable.Life + DamageIn.LifeWhenHit, output.LifeRecoverable or 0)
				poolTable.Mana = m_min(poolTable.Mana + DamageIn.ManaWhenHit, output.ManaUnreserved or 0)
				poolTable.EnergyShield = m_min(poolTable.EnergyShield + DamageIn.EnergyShieldWhenHit, output.EnergyShieldRecoveryCap)
			end
			iterationMultiplier = 1
			-- to speed it up, run recursively but accelerated
			local speedUp = data.misc.ehpCalcSpeedUp
			DamageIn["cyclesRan"] = DamageIn["cyclesRan"] or false
			if not DamageIn["cyclesRan"] and poolTable.Life > 0 and DamageIn["iterations"] < maxIterations then
				Damage = { }
				for _, damageType in ipairs(dmgTypeList) do
					Damage[damageType] = DamageIn[damageType] * speedUp
				end
				if DamageIn.GainWhenHit then
					Damage.GainWhenHit = true
					Damage.LifeWhenHit = DamageIn.LifeWhenHit
					Damage.ManaWhenHit = DamageIn.ManaWhenHit
					Damage.EnergyShieldWhenHit = DamageIn.EnergyShieldWhenHit
				end
				Damage["cycles"] = DamageIn["cycles"] * speedUp
				Damage["iterations"] = DamageIn["iterations"]
				iterationMultiplier = m_max((numberOfHitsToDie(Damage) - 1) * speedUp - 1, 1)
				if iterationMultiplier == m_huge then -- avoid unnecessary calculations if we know we survive infinite hits.
					return m_huge
				end
				DamageIn["iterations"] = Damage["iterations"]
				DamageIn["cyclesRan"] = true
			end
			numHits = numHits + iterationMultiplier
		end
		if DamageIn.TrackRecoupable then
			for damageType, recoupable in pairs(poolTable.damageTakenThatCanBeRecouped) do
				output[damageType.."RecoupableDamageTaken"] = output[damageType.."RecoupableDamageTaken"] + recoupable
			end
		end
		if DamageIn["TrackLifeLossOverTime"] then
			output.LifeLossLostOverTime = output.LifeLossLostOverTime + poolTable.LifeLossLostOverTime
			output.LifeBelowHalfLossLostOverTime = output.LifeBelowHalfLossLostOverTime + poolTable.LifeBelowHalfLossLostOverTime
		end
		
		if poolTable.Life == 0 and DamageIn["cycles"] == 1 then -- Don't count overkill damage and only on final pass as to not break speedup.
			numHits = numHits - poolTable.OverkillDamage / damageTotal
		end
		-- Recalculate total hit damage
		damageTotal = 0
		for _, damageType in ipairs(dmgTypeList) do
			damageTotal = damageTotal + DamageIn[damageType] * numHits
		end
		if poolTable.Life >= 0 and damageTotal >= maxDamage then -- If still living and the amount of damage exceeds maximum threshold we survived infinite number of hits.
			return m_huge
		end
		return numHits
	end
	
	if damageCategoryConfig ~= "DamageOverTime" then
		-- number of damaging hits needed to be taken to die
		do
			local DamageIn = { }
			for _, damageType in ipairs(dmgTypeList) do
				DamageIn[damageType] = output[damageType.."TakenHit"]
			end
			output["NumberOfDamagingHits"] = numberOfHitsToDie(DamageIn)
		end

	
		do
			local DamageIn = { }
			local BlockChance = output.EffectiveBlockChance / 100
			if damageCategoryConfig ~= "Melee" and damageCategoryConfig ~= "Untyped" then
				BlockChance = output["Effective"..damageCategoryConfig.."BlockChance"] / 100
			end
			local blockEffect = (1 - BlockChance * output.BlockEffect / 100)
			local suppressChance = 0
			local suppressionEffect = 1
			local ExtraAvoidChance = 0
			local averageAvoidChance = 0
			if not env.configInput.DisableEHPGainOnBlock then
				DamageIn.LifeWhenHit = output.LifeOnBlock * BlockChance
				DamageIn.ManaWhenHit = output.ManaOnBlock * BlockChance
				DamageIn.EnergyShieldWhenHit = output.EnergyShieldOnBlock * BlockChance
				if damageCategoryConfig == "Spell" or damageCategoryConfig == "SpellProjectile" then
					DamageIn.EnergyShieldWhenHit = DamageIn.EnergyShieldWhenHit + output.EnergyShieldOnSpellBlock * BlockChance
				elseif damageCategoryConfig == "Average" then
					DamageIn.EnergyShieldWhenHit = DamageIn.EnergyShieldWhenHit + output.EnergyShieldOnSpellBlock / 2 * BlockChance
				end
			end
			-- suppression
			if damageCategoryConfig == "Spell" or damageCategoryConfig == "SpellProjectile" or damageCategoryConfig == "Average" then
				suppressChance = output.EffectiveSpellSuppressionChance / 100
			end
			-- We include suppression in damage reduction if it is 100% otherwise we handle it here.
			if suppressChance < 1 then
				if damageCategoryConfig == "Average" then
					suppressChance = suppressChance / 2
				end
				DamageIn.EnergyShieldWhenHit = (DamageIn.EnergyShieldWhenHit or 0) + output.EnergyShieldOnSuppress * suppressChance
				DamageIn.LifeWhenHit = (DamageIn.LifeWhenHit or 0) + output.LifeOnSuppress * suppressChance
				suppressionEffect = 1 - suppressChance * output.SpellSuppressionEffect / 100
			else
				DamageIn.EnergyShieldWhenHit = (DamageIn.EnergyShieldWhenHit or 0) + output.EnergyShieldOnSuppress * ( damageCategoryConfig == "Average" and 0.5 or 1 )
				DamageIn.LifeWhenHit = (DamageIn.LifeWhenHit or 0) + output.LifeOnSuppress * ( damageCategoryConfig == "Average" and 0.5 or 1 )
			end
			-- extra avoid chance
			if damageCategoryConfig == "Projectile" or damageCategoryConfig == "SpellProjectile" then
				ExtraAvoidChance = ExtraAvoidChance + output.AvoidProjectilesChance
			elseif damageCategoryConfig == "Average" then
				ExtraAvoidChance = ExtraAvoidChance + output.AvoidProjectilesChance / 2
			end
			-- gain when hit (currently just gain on block/suppress)
			if not env.configInput.DisableEHPGainOnBlock then
				if (DamageIn.LifeWhenHit or 0) ~= 0 or (DamageIn.ManaWhenHit or 0) ~= 0 or DamageIn.EnergyShieldWhenHit ~= 0 then
					DamageIn.GainWhenHit = true
				end
			else
				DamageIn.LifeWhenHit = 0
				DamageIn.ManaWhenHit = 0
				DamageIn.EnergyShieldWhenHit = 0
			end
			for _, damageType in ipairs(dmgTypeList) do
				 -- Emperor's Vigilance (this needs to fail with divine flesh as it can't override it, hence the check for high bypass)
				if modDB:Flag(nil, "BlockedDamageDoesntBypassES") and (output[damageType.."EnergyShieldBypass"] < 100 and damageType ~= "Chaos") then
					DamageIn[damageType.."EnergyShieldBypass"] = output[damageType.."EnergyShieldBypass"] * (1 - BlockChance) 
				end
				local AvoidChance = 0
				if output.specificTypeAvoidance then
					AvoidChance = m_min(output["Avoid"..damageType.."DamageChance"] + ExtraAvoidChance, data.misc.AvoidChanceCap)
					-- unlucky config to lower the value of block, dodge, evade etc for ehp
					local worstOf = env.configInput.EHPUnluckyWorstOf or 1
					if worstOf > 1 then
						AvoidChance = AvoidChance / 100 * AvoidChance
						if worstOf == 4 then
							AvoidChance = AvoidChance / 100 * AvoidChance
						end
					end
					averageAvoidChance = averageAvoidChance + AvoidChance
				end
				DamageIn[damageType] = output[damageType.."TakenHit"] * (blockEffect * suppressionEffect * (1 - AvoidChance / 100))
			end
			-- recoup initialisation
			if output["anyRecoup"] > 0 then
				DamageIn["TrackRecoupable"] = true
				for _, damageType in ipairs(dmgTypeList) do
					output[damageType.."RecoupableDamageTaken"] = 0
				end
			end
			-- taken over time degen initialisation
			if output["preventedLifeLossTotal"] > 0 then
				DamageIn["TrackLifeLossOverTime"] = true
				output["LifeLossLostOverTime"] = 0
				output["LifeBelowHalfLossLostOverTime"] = 0
			end
			averageAvoidChance = averageAvoidChance / 5
			output["ConfiguredDamageChance"] = 100 * (blockEffect * suppressionEffect * (1 - averageAvoidChance / 100))
			output["NumberOfMitigatedDamagingHits"] = (output["ConfiguredDamageChance"] ~= 100 or DamageIn["TrackRecoupable"] or DamageIn["TrackLifeLossOverTime"] or DamageIn.GainWhenHit) and numberOfHitsToDie(DamageIn) or output["NumberOfDamagingHits"]
			if breakdown then
				breakdown["ConfiguredDamageChance"] = {
					s_format("%.2f ^8(chance for block to fail)", 1 - BlockChance)
				}	
				if output.ShowBlockEffect then
					t_insert(breakdown["ConfiguredDamageChance"], s_format("x %.2f ^8(block effect)", output.BlockEffect / 100))
				end
				if suppressionEffect ~= 1 then
					t_insert(breakdown["ConfiguredDamageChance"], s_format("x %.3f ^8(suppression effect)", suppressionEffect))
				end
				if averageAvoidChance > 0 then
					t_insert(breakdown["ConfiguredDamageChance"], s_format("x %.2f ^8(chance for avoidance to fail)", 1 - averageAvoidChance / 100))
				end
				t_insert(breakdown["ConfiguredDamageChance"], s_format("= %.1f%% ^8(of damage taken from a%s hit)", output["ConfiguredDamageChance"], (damageCategoryConfig == "Average" and "n " or (damageCategoryConfig == "Untyped" and "n " or " "))..damageCategoryConfig))
			end
		end
		
		-- chance to not be hit breakdown
		do
			output["TotalNumberOfHits"] = output["NumberOfMitigatedDamagingHits"] / (1 - output["ConfiguredNotHitChance"] / 100)
			if breakdown then
				breakdown.ConfiguredNotHitChance = { }
				if damageCategoryConfig == "Melee" or damageCategoryConfig == "Projectile" then
					if output[damageCategoryConfig.."EvadeChance"] > 0 then
						t_insert(breakdown["ConfiguredNotHitChance"], s_format("%.2f ^8(chance for evasion to fail)", 1 - output[damageCategoryConfig.."EvadeChance"] / 100))
					end
					if output.AttackDodgeChance > 0 then
						t_insert(breakdown["ConfiguredNotHitChance"], s_format("x %.2f ^8(chance for dodge to fail)", 1 - output.AttackDodgeChance / 100))
					end
					if damageCategoryConfig == "Projectile" and not output.specificTypeAvoidance and output.AvoidProjectilesChance > 0 then
						t_insert(breakdown["ConfiguredNotHitChance"], s_format("x %.2f ^8(chance for avoidance to fail)", 1 - output.AvoidProjectilesChance / 100))
					end
				elseif damageCategoryConfig == "Spell" or damageCategoryConfig == "SpellProjectile" then
					if output.SpellDodgeChance > 0 then
						t_insert(breakdown["ConfiguredNotHitChance"], s_format("%.2f ^8(chance for dodge to fail)", 1 - output.SpellDodgeChance / 100))
					end
					if damageCategoryConfig == "SpellProjectile" and not output.specificTypeAvoidance and output.AvoidProjectilesChance > 0 then
						t_insert(breakdown["ConfiguredNotHitChance"], s_format("x %.2f ^8(chance for avoidance to fail)", 1 - output.AvoidProjectilesChance / 100))
					end
				elseif damageCategoryConfig == "Average" then
					if output.MeleeEvadeChance > 0 or output.ProjectileEvadeChance > 0 then
						t_insert(breakdown["ConfiguredNotHitChance"], s_format("%.2f ^8(chance for evasion to fail, only applies to the attack portion)", 1 - (output.MeleeEvadeChance + output.ProjectileEvadeChance) / 2 / 100))
					end
					if output.AttackDodgeChance > 0  or output.SpellDodgeChance > 0 then
						t_insert(breakdown["ConfiguredNotHitChance"], s_format("x%.2f ^8(chance for dodge to fail)", 1 - (output.AttackDodgeChance + output.SpellDodgeChance) / 2 / 100))
					end
					if not output.specificTypeAvoidance and output.AvoidProjectilesChance > 0 then
						t_insert(breakdown["ConfiguredNotHitChance"], s_format("x %.2f ^8(chance for avoidance to fail)", 1 - output.AvoidProjectilesChance / 2 / 100))
					end
				end
				if output.AvoidAllDamageFromHitsChance > 0 then
					t_insert(breakdown["ConfiguredNotHitChance"], s_format("x %.2f ^8(chance for damage avoidance to fail)", 1 - output.AvoidAllDamageFromHitsChance / 100))
				end
				local worstOf = env.configInput.EHPUnluckyWorstOf or 1
				if worstOf > 1 then
					t_insert(breakdown["ConfiguredNotHitChance"], s_format("unlucky worst of %d", worstOf))
				end
				t_insert(breakdown["ConfiguredNotHitChance"], s_format("= %d%% ^8(chance to be hit by a%s hit)", 100 - output.ConfiguredNotHitChance, (damageCategoryConfig == "Average" and "n " or (damageCategoryConfig == "Untyped" and "n " or " ") )..damageCategoryConfig))
				breakdown["TotalNumberOfHits"] = {
					s_format("%.2f ^8(Number of mitigated hits)", output["NumberOfMitigatedDamagingHits"]),
					s_format("/ %.2f ^8(Chance to even be hit)", 1 - output["ConfiguredNotHitChance"] / 100),
					s_format("= %.2f ^8(total average number of hits you can take)", output["TotalNumberOfHits"]),
				}
			end
		end
		
		-- effective hit pool
		output["TotalEHP"] = output["TotalNumberOfHits"] * output["totalEnemyDamageIn"]
		if breakdown then
			breakdown["TotalEHP"] = {
				s_format("%.2f ^8(total average number of hits you can take)", output["TotalNumberOfHits"]),
				s_format("x %d ^8(total incoming damage)", output["totalEnemyDamageIn"]),
				s_format("= %d ^8(total damage you can take)", output["TotalEHP"]),
			}
		end
		
		-- survival time
		do
			output.enemySkillTime = (env.configInput.enemySpeed or env.configPlaceholder.enemySpeed or 700) / (1 + enemyDB:Sum("INC", nil, "Speed") / 100)
			local enemyActionSpeed = calcs.actionSpeedMod(actor.enemy)
			output.enemySkillTime = output.enemySkillTime / 1000 / enemyActionSpeed
			output["EHPSurvivalTime"] = output["TotalNumberOfHits"] * output.enemySkillTime
			if breakdown then
				breakdown["EHPSurvivalTime"] = {
					s_format("%.2f ^8(total average number of hits you can take)", output["TotalNumberOfHits"]),
					s_format("x %.2f ^8enemy attack/cast time", output.enemySkillTime),
					s_format("= %.2f seconds ^8(total time it would take to die)", output["EHPSurvivalTime"]),
				}
			end
		end
	end
	
	-- recoup
	if output["anyRecoup"] > 0 and damageCategoryConfig ~= "DamageOverTime" then
		local totalDamage = 0
		local totalElementalDamage = 0
		local totalPhysicalDamageMitigated = output["NumberOfMitigatedDamagingHits"] * (output.PhysicalTakenDamage - output.PhysicalTakenHit)
		local extraPseudoRecoup = {}
		for _, damageType in ipairs(dmgTypeList) do
			totalDamage = totalDamage + output[damageType.."RecoupableDamageTaken"]
			if isElemental[damageType] then
				totalElementalDamage = totalElementalDamage + output[damageType.."RecoupableDamageTaken"]
			end
		end
		local recoupTypeList = {"Life", "Mana", "EnergyShield"}
		for i, recoupType in ipairs(recoupTypeList) do
			local recoupTime = (modDB:Flag(nil, "4Second"..recoupType.."Recoup") or modDB:Flag(nil, "4SecondRecoup")) and 4 or 8
			output["Total"..recoupType.."RecoupRecovery"] = (output[recoupType.."Recoup"] or 0) / 100 * totalDamage
			if (output["Elemental"..recoupType.."Recoup"] or 0) > 0 and totalElementalDamage > 0 then
				output["Total"..recoupType.."RecoupRecovery"] = output["Total"..recoupType.."RecoupRecovery"] + output["Elemental"..recoupType.."Recoup"] / 100 * totalElementalDamage
			end
			for _, damageType in ipairs(dmgTypeList) do
				if (output[damageType..recoupType.."Recoup"] or 0) > 0 and output[damageType.."RecoupableDamageTaken"] > 0 then
					output["Total"..recoupType.."RecoupRecovery"] = output["Total"..recoupType.."RecoupRecovery"] + output[damageType..recoupType.."Recoup"] / 100 * output[damageType.."RecoupableDamageTaken"]
				end
			end
			output["Total"..recoupType.."PseudoRecoup"] = (output["PhysicalDamageMitigated"..recoupType.."PseudoRecoup"] or 0) / 100 * totalPhysicalDamageMitigated
			local PseudoRecoupDuration = (output["PhysicalDamageMitigated"..recoupType.."PseudoRecoupDuration"] or 4)
			-- Pious Path
			if output["Total"..recoupType.."PseudoRecoup"] ~= 0 then
				for j=i+1,#recoupTypeList do
					if modDB:Flag(nil, recoupType.."RegenerationRecovers"..recoupTypeList[j]) and not modDB:Flag(nil, "UnaffectedBy"..recoupTypeList[j].."Regen") and not modDB:Flag(nil, "No"..recoupTypeList[j].."Regen") and not modDB:Flag(nil, "CannotGain"..recoupTypeList[j]) then
						extraPseudoRecoup[recoupTypeList[j]] = { output["Total"..recoupType.."PseudoRecoup"] * output[recoupTypeList[j].."RecoveryRateMod"] / output[recoupType.."RecoveryRateMod"], PseudoRecoupDuration }
					end
				end
			end
			output["Total"..recoupType.."PseudoRecoup"] = ((not modDB:Flag(nil, "UnaffectedBy"..recoupType.."Regen")) and output["Total"..recoupType.."PseudoRecoup"] or 0)
			output[recoupType.."RecoupRecoveryMax"] = output["Total"..recoupType.."RecoupRecovery"] / recoupTime + output["Total"..recoupType.."PseudoRecoup"] / PseudoRecoupDuration + (extraPseudoRecoup[recoupType] and (extraPseudoRecoup[recoupType][1] / extraPseudoRecoup[recoupType][2]) or 0)
			output[recoupType.."RecoupRecoveryAvg"] = output["Total"..recoupType.."RecoupRecovery"] / (output["EHPSurvivalTime"] + recoupTime) + output["Total"..recoupType.."PseudoRecoup"] / (output["EHPSurvivalTime"] + PseudoRecoupDuration) + (extraPseudoRecoup[recoupType] and (extraPseudoRecoup[recoupType][1] / (output["EHPSurvivalTime"] + extraPseudoRecoup[recoupType][2])) or 0)
			if breakdown then
				local multipleTypes = 0
				breakdown[recoupType.."RecoupRecoveryMax"] = { }
				if (output[recoupType.."Recoup"] or 0) > 0 then
					t_insert(breakdown[recoupType.."RecoupRecoveryMax"], s_format("%d ^8(total damage taken during ehp calcs)", totalDamage))
					t_insert(breakdown[recoupType.."RecoupRecoveryMax"], s_format("* %.2f ^8(percent of damage recouped)", output[recoupType.."Recoup"] / 100))
					multipleTypes = multipleTypes + 1
				end
				if (output["Elemental"..recoupType.."Recoup"] or 0) > 0 and totalElementalDamage > 0 then
					if multipleTypes > 0 then
						t_insert(breakdown[recoupType.."RecoupRecoveryMax"], s_format(""))
					end
					t_insert(breakdown[recoupType.."RecoupRecoveryMax"], s_format("%s%d ^8(total elemental damage taken during ehp calcs)", multipleTypes > 0 and "+" or "", totalDamage))
					t_insert(breakdown[recoupType.."RecoupRecoveryMax"], s_format("* %.2f ^8(percent of damage recouped)", output["Elemental"..recoupType.."Recoup"] / 100))
					multipleTypes = multipleTypes + 1
				end
				for _, damageType in ipairs(dmgTypeList) do
					if (output[damageType..recoupType.."Recoup"] or 0) > 0 and output[damageType.."RecoupableDamageTaken"] > 0 then
						if multipleTypes > 0 then
							t_insert(breakdown[recoupType.."RecoupRecoveryMax"], s_format(""))
						end
						t_insert(breakdown[recoupType.."RecoupRecoveryMax"], s_format("%s%d ^8(total %s damage taken during ehp calcs)", multipleTypes > 0 and "+" or "", totalDamage, damageType))
						t_insert(breakdown[recoupType.."RecoupRecoveryMax"], s_format("* %.2f ^8(percent of damage recouped)", output[damageType..recoupType.."Recoup"] / 100))
						multipleTypes = multipleTypes + 1
					end
				end
				t_insert(breakdown[recoupType.."RecoupRecoveryMax"], s_format("= %d ^8(total damage recoup amount)", output["Total"..recoupType.."RecoupRecovery"]))
				breakdown[recoupType.."RecoupRecoveryAvg"] = copyTable(breakdown[recoupType.."RecoupRecoveryMax"])
				t_insert(breakdown[recoupType.."RecoupRecoveryMax"], s_format("/ %.2f ^8(over %d seconds)", recoupTime, recoupTime))
				if output["Total"..recoupType.."PseudoRecoup"] > 0 then
					t_insert(breakdown[recoupType.."RecoupRecoveryMax"], s_format("+ %.2f ^8(total damage mitigated pseudo recoup amount)", output["Total"..recoupType.."PseudoRecoup"]))
					t_insert(breakdown[recoupType.."RecoupRecoveryMax"], s_format("/ %.2f ^8(over %d seconds)", PseudoRecoupDuration, PseudoRecoupDuration))
				end
				if extraPseudoRecoup[recoupType] then
					t_insert(breakdown[recoupType.."RecoupRecoveryMax"], s_format("+ %.2f ^8(total damage mitigated pseudo recoup amount)", extraPseudoRecoup[recoupType][1]))
					t_insert(breakdown[recoupType.."RecoupRecoveryMax"], s_format("/ %.2f ^8(over %d seconds)", extraPseudoRecoup[recoupType][2], extraPseudoRecoup[recoupType][2]))
				end
				t_insert(breakdown[recoupType.."RecoupRecoveryMax"], s_format("= %.2f per second ^8", output[recoupType.."RecoupRecoveryMax"]))
				t_insert(breakdown[recoupType.."RecoupRecoveryAvg"], s_format("/ %.2f ^8(total time of the recoup (survival time + %d seconds))", (output["EHPSurvivalTime"] + recoupTime), recoupTime))
				if output["Total"..recoupType.."PseudoRecoup"] > 0 then
					t_insert(breakdown[recoupType.."RecoupRecoveryAvg"], s_format("+ %.2f ^8(total damage mitigated pseudo recoup amount)", output["Total"..recoupType.."PseudoRecoup"]))
					t_insert(breakdown[recoupType.."RecoupRecoveryAvg"], s_format("/ %.2f ^8(total time of the recoup (survival time + %d seconds)", (output["EHPSurvivalTime"] + PseudoRecoupDuration), PseudoRecoupDuration))
				end
				if extraPseudoRecoup[recoupType] then
					t_insert(breakdown[recoupType.."RecoupRecoveryAvg"], s_format("+ %.2f ^8(total damage mitigated pseudo recoup amount)", extraPseudoRecoup[recoupType][1]))
					t_insert(breakdown[recoupType.."RecoupRecoveryAvg"], s_format("/ %.2f ^8(total time of the recoup (survival time + %d seconds)", (output["EHPSurvivalTime"] + extraPseudoRecoup[recoupType][2]), extraPseudoRecoup[recoupType][2]))
				end
				t_insert(breakdown[recoupType.."RecoupRecoveryAvg"], s_format("= %.2f per second ^8", output[recoupType.."RecoupRecoveryAvg"]))
			end
		end
	end
	
	-- petrified blood "degen"
	if output.preventedLifeLossTotal > 0 and (output["LifeLossLostOverTime"] and output["LifeBelowHalfLossLostOverTime"]) then
		local LifeLossBelowHalfLost = modDB:Sum("BASE", nil, "LifeLossBelowHalfLost") / 100
		output["LifeLossLostMax"] = (output["LifeLossLostOverTime"] + output["LifeBelowHalfLossLostOverTime"] * LifeLossBelowHalfLost) / 4
		output["LifeLossLostAvg"] = (output["LifeLossLostOverTime"] + output["LifeBelowHalfLossLostOverTime"] * LifeLossBelowHalfLost) / (output["EHPSurvivalTime"] + 4)
		if breakdown then
			breakdown["LifeLossLostMax"] = { }
			if output["LifeLossLostOverTime"] ~= 0 then
				t_insert(breakdown["LifeLossLostMax"], s_format("( %d ^8(total damage prevented by Progenesis)", output["LifeLossLostOverTime"]))
			end
			if output["LifeBelowHalfLossLostOverTime"] ~= 0 then
				t_insert(breakdown["LifeLossLostMax"], s_format("%s %d ^8(total damage prevented by petrified blood)", output["LifeLossLostOverTime"] ~= 0 and "+" or "(", output["LifeBelowHalfLossLostOverTime"]))
				t_insert(breakdown["LifeLossLostMax"], s_format("* %.2f ^8(percent of damage taken from petrified blood)", LifeLossBelowHalfLost))
			end
			t_insert(breakdown["LifeLossLostMax"], s_format(") / %.2f ^8(over 4 seconds)", 4))
			t_insert(breakdown["LifeLossLostMax"], s_format("= %.2f per second", output["LifeLossLostMax"]))
			breakdown["LifeLossLostAvg"] = { }
			if output["LifeLossLostOverTime"] ~= 0 then
				t_insert(breakdown["LifeLossLostAvg"], s_format("( %d ^8(total damage prevented by Progenesis)", output["LifeLossLostOverTime"]))
			end
			if output["LifeBelowHalfLossLostOverTime"] ~= 0 then
				t_insert(breakdown["LifeLossLostAvg"], s_format("%s %d ^8(total damage prevented by petrified blood)", output["LifeLossLostOverTime"] ~= 0 and "+" or "(", output["LifeBelowHalfLossLostOverTime"]))
				t_insert(breakdown["LifeLossLostAvg"], s_format("* %.2f ^8(percent of damage taken from petrified blood)", LifeLossBelowHalfLost))
			end
			t_insert(breakdown["LifeLossLostAvg"], s_format(") / %.2f ^8(total time of the degen (survival time + 4 seconds))", (output["EHPSurvivalTime"] + 4)))
			t_insert(breakdown["LifeLossLostAvg"], s_format("= %.2f per second", output["LifeLossLostAvg"]))
		end
	end
	
	-- net recovery over time from enemy hits
	if (output["LifeRecoupRecoveryAvg"] or 0) > 0 or output.preventedLifeLossTotal > 0 then
		output["netLifeRecoupAndLossLostOverTimeMax"] = (output["LifeRecoupRecoveryMax"] or 0) - (output["LifeLossLostMax"] or 0)
		output["netLifeRecoupAndLossLostOverTimeAvg"] = (output["LifeRecoupRecoveryAvg"] or 0) - (output["LifeLossLostAvg"] or 0)
		if (output["LifeRecoupRecoveryAvg"] or 0) > 0 and output.preventedLifeLossTotal > 0 then
			output["showNetRecoup"] = true
			if breakdown then
				breakdown["netLifeRecoupAndLossLostOverTimeMax"] = {
					s_format("%.2f ^8(total life recouped per second)", output["LifeRecoupRecoveryMax"]),
					s_format("- %.2f ^8(total life taken over time per second)", output["LifeLossLostMax"]),
					s_format("= %.2f per second", output["netLifeRecoupAndLossLostOverTimeMax"]),
				}
				breakdown["netLifeRecoupAndLossLostOverTimeAvg"] = {
					s_format("%.2f ^8(total life recouped per second)", output["LifeRecoupRecoveryAvg"]),
					s_format("- %.2f ^8(total life taken over time per second)", output["LifeLossLostAvg"]),
					s_format("= %.2f per second", output["netLifeRecoupAndLossLostOverTimeAvg"]),
				}
			end
		end
	end
	
	-- pvp
	if env.configInput.PvpScaling then
		local PvpTvalue = output.enemySkillTime
		local PvpMultiplier = (env.configInput.enemyMultiplierPvpDamage or 100) / 100
		
		local PvpNonElemental1 = data.misc.PvpNonElemental1
		local PvpNonElemental2 = data.misc.PvpNonElemental2
		local PvpElemental1 = data.misc.PvpElemental1
		local PvpElemental2 = data.misc.PvpElemental2

		local percentageNonElemental = (output["PhysicalTakenHit"] + output["ChaosTakenHit"]) / output["totalTakenHit"]
		local percentageElemental = 1 - percentageNonElemental
		local portionNonElemental = (output["totalTakenHit"] / PvpTvalue / PvpNonElemental2 ) ^ PvpNonElemental1 * PvpTvalue * PvpNonElemental2 * percentageNonElemental
		local portionElemental = (output["totalTakenHit"] / PvpTvalue / PvpElemental2 ) ^ PvpElemental1 * PvpTvalue * PvpElemental2 * percentageElemental
		output.PvPTotalTakenHit = ((portionNonElemental or 0) + (portionElemental or 0)) * PvpMultiplier

		if breakdown then
			breakdown.PvPTotalTakenHit = { }
			local percentBoth = (percentageNonElemental > 0) and (percentageElemental > 0)
			t_insert(breakdown.PvPTotalTakenHit, s_format("Pvp Formula is (D/(T*M))^E*T*%s, where D is the damage, T is the time taken,", percentBoth and "M*P" or "M" ))
			t_insert(breakdown.PvPTotalTakenHit, s_format(" M is the multiplier%s", percentBoth and ", E is the exponent and P is the percentage of that type (ele or non ele)" or " and E is the exponent" ))
			if percentBoth then
				t_insert(breakdown.PvPTotalTakenHit, s_format("(M= %.1f for ele and %.1f for non-ele)(E= %.2f for ele and %.2f for non-ele)", PvpElemental2, PvpNonElemental2, PvpElemental1, PvpNonElemental1))
				t_insert(breakdown.PvPTotalTakenHit, s_format("(%.1f / (%.2f * %.1f)) ^ %.2f * %.2f * %.1f * %.2f = %.1f", output["totalTakenHit"], PvpTvalue,  PvpNonElemental2, PvpNonElemental1, PvpTvalue, PvpNonElemental2, percentageNonElemental, portionNonElemental))
				t_insert(breakdown.PvPTotalTakenHit, s_format("(%.1f / (%.2f * %.1f)) ^ %.2f * %.2f * %.1f * %.2f = %.1f", output["totalTakenHit"], PvpTvalue,  PvpElemental2, PvpElemental1, PvpTvalue, PvpElemental2, percentageElemental, portionElemental))
				t_insert(breakdown.PvPTotalTakenHit, s_format("(portionNonElemental + portionElemental)%s", PvpMultiplier ~= 1 and " * PvP multiplier" or " "))
				if PvpMultiplier ~= 1 then
					t_insert(breakdown.PvPTotalTakenHit, s_format("(%.1f + %.1f) * %g", portionNonElemental, portionElemental, PvpMultiplier))
				else
					t_insert(breakdown.PvPTotalTakenHit, s_format("%.1f + %.1f", portionNonElemental, portionElemental))
				end
			elseif percentageElemental <= 0 then
				t_insert(breakdown.PvPTotalTakenHit, s_format("(M= %.1f for non-ele)(E= %.2f for non-ele)", PvpNonElemental2, PvpNonElemental1))
				t_insert(breakdown.PvPTotalTakenHit, s_format("(%.1f / (%.2f * %.1f)) ^ %.2f * %.2f * %.1f = %.1f", output["totalTakenHit"], PvpTvalue,  PvpNonElemental2, PvpNonElemental1, PvpTvalue, PvpNonElemental2, portionNonElemental))
				if PvpMultiplier ~= 1 then
					t_insert(breakdown.PvPTotalTakenHit, s_format("%.1f * %g ^8(portionNonElemental * PvP multiplier)", portionNonElemental, PvpMultiplier))
				end
			elseif percentageNonElemental <= 0 then
				t_insert(breakdown.PvPTotalTakenHit, s_format("(M= %.1f for ele)(E= %.2f for ele)", PvpElemental2, PvpElemental1))
				t_insert(breakdown.PvPTotalTakenHit, s_format("(%.1f / (%.2f * %.1f)) ^ %.2f * %.2f * %.1f = %.1f", output["totalTakenHit"], PvpTvalue,  PvpElemental2, PvpElemental1, PvpTvalue, PvpElemental2, portionElemental))
				if PvpMultiplier ~= 1 then
					t_insert(breakdown.PvPTotalTakenHit, s_format("%.1f * %g ^8(portionElemental * PvP multiplier)", portionElemental, PvpMultiplier))
				end
			end
			t_insert(breakdown.PvPTotalTakenHit, s_format("= %.1f", output.PvPTotalTakenHit))
		end
	end
	
	-- maximum hit taken
	do
		-- fix total pools, as they aren't used anymore
		for _, damageType in ipairs(dmgTypeList) do
			-- ward
			local wardBypass = modDB:Sum("BASE", nil, "WardBypass") or 0
			if wardBypass > 0 then
				local poolProtected = output.Ward / (1 - wardBypass / 100) * (wardBypass / 100)
				local sourcePool = output[damageType.."TotalHitPool"]
				sourcePool = m_max(sourcePool - poolProtected, 0) + m_min(sourcePool, poolProtected) / (wardBypass / 100)
				output[damageType.."TotalHitPool"] = sourcePool
			else
				output[damageType.."TotalHitPool"] = output[damageType.."TotalHitPool"] + output.Ward or 0
			end
			-- aegis
			output[damageType.."TotalHitPool"] = output[damageType.."TotalHitPool"] + m_max(m_max(output[damageType.."Aegis"], output["sharedAegis"]), isElemental[damageType] and output[damageType.."AegisDisplay"] or 0)
			-- guard skill
			local GuardAbsorbRate = output["sharedGuardAbsorbRate"] or 0 + output[damageType.."GuardAbsorbRate"] or 0
			if GuardAbsorbRate > 0 then
				local GuardAbsorb = output["sharedGuardAbsorb"] or 0 + output[damageType.."GuardAbsorb"] or 0
				if GuardAbsorbRate >= 100 then
					output[damageType.."TotalHitPool"] = output[damageType.."TotalHitPool"] + GuardAbsorb
				else
					local poolProtected = GuardAbsorb / (GuardAbsorbRate / 100) * (1 - GuardAbsorbRate / 100)
					output[damageType.."TotalHitPool"] = m_max(output[damageType.."TotalHitPool"] - poolProtected, 0) + m_min(output[damageType.."TotalHitPool"], poolProtected) / (1 - GuardAbsorbRate / 100)
				end
			end
			-- from allies before you
			-- frost shield
			if output["FrostShieldLife"] > 0 then
				local poolProtected = output["FrostShieldLife"] / (output["FrostShieldDamageMitigation"] / 100) * (1 - output["FrostShieldDamageMitigation"] / 100)
				output[damageType.."TotalHitPool"] = m_max(output[damageType.."TotalHitPool"] - poolProtected, 0) + m_min(output[damageType.."TotalHitPool"], poolProtected) / (1 - output["FrostShieldDamageMitigation"] / 100)
			end
			-- spectres
			if output["TotalSpectreLife"] and output["TotalSpectreLife"] > 0 then
				local poolProtected = output["TotalSpectreLife"] / (output["SpectreAllyDamageMitigation"] / 100) * (1 - output["SpectreAllyDamageMitigation"] / 100)
				output[damageType.."TotalHitPool"] = m_max(output[damageType.."TotalHitPool"] - poolProtected, 0) + m_min(output[damageType.."TotalHitPool"], poolProtected) / (1 - output["SpectreAllyDamageMitigation"] / 100)
			end
			-- totems
			if output["TotalTotemLife"] and output["TotalTotemLife"] > 0 then
				local poolProtected = output["TotalTotemLife"] / (output["TotemAllyDamageMitigation"] / 100) * (1 - output["TotemAllyDamageMitigation"] / 100)
				output[damageType.."TotalHitPool"] = m_max(output[damageType.."TotalHitPool"] - poolProtected, 0) + m_min(output[damageType.."TotalHitPool"], poolProtected) / (1 - output["TotemAllyDamageMitigation"] / 100)
			end
			if output["TotalVaalRejuvenationTotemLife"] and output["TotalVaalRejuvenationTotemLife"] > 0 then
				local poolProtected = output["TotalVaalRejuvenationTotemLife"] / (output["VaalRejuvenationTotemAllyDamageMitigation"] / 100) * (1 - output["VaalRejuvenationTotemAllyDamageMitigation"] / 100)
				output[damageType.."TotalHitPool"] = m_max(output[damageType.."TotalHitPool"] - poolProtected, 0) + m_min(output[damageType.."TotalHitPool"], poolProtected) / (1 - output["VaalRejuvenationTotemAllyDamageMitigation"] / 100)
			end
			if output["TotalRadianceSentinelLife"] and output["TotalRadianceSentinelLife"] > 0 then
				local poolProtected = output["TotalRadianceSentinelLife"] / (output["RadianceSentinelAllyDamageMitigation"] / 100) * (1 - output["RadianceSentinelAllyDamageMitigation"] / 100)
				output[damageType.."TotalHitPool"] = m_max(output[damageType.."TotalHitPool"] - poolProtected, 0) + m_min(output[damageType.."TotalHitPool"], poolProtected) / (1 - output["RadianceSentinelAllyDamageMitigation"] / 100)
			end
			-- soul link
			if output["AlliedEnergyShield"] and output["AlliedEnergyShield"] > 0 then
				local poolProtected = output["AlliedEnergyShield"] / (output["SoulLinkMitigation"] / 100) * (1 - output["SoulLinkMitigation"] / 100)
				output[damageType.."TotalHitPool"] = m_max(output[damageType.."TotalHitPool"] - poolProtected, 0) + m_min(output[damageType.."TotalHitPool"], poolProtected) / (1 - output["SoulLinkMitigation"] / 100)
			end
		end

		for _, damageType in ipairs(dmgTypeList) do
			local partMin = m_huge
			local useConversionSmoothing = false
			for _, damageConvertedType in ipairs(dmgTypeList) do
				local convertPercent = actor.damageShiftTable[damageType][damageConvertedType]
				local takenFlat = output[damageConvertedType.."takenFlat"]
				if convertPercent > 0 or takenFlat ~= 0 then
					local hitTaken = 0
					local effectiveAppliedArmour = output[damageConvertedType.."EffectiveAppliedArmour"]
					local damageConvertedMulti = convertPercent / 100
					local totalHitPool = output[damageConvertedType.."TotalHitPool"]
					local totalTakenMulti = output[damageConvertedType.."AfterReductionTakenHitMulti"] * (1 - output["VaalArcticArmourMitigation"])

					if effectiveAppliedArmour == 0 and convertPercent == 100 then	-- use a simpler calculation for no armour DR
						local drMulti = output[damageConvertedType.."ResistTakenHitMulti"] * (1 - output[damageConvertedType.."DamageReduction"] / 100)
						hitTaken = m_max(totalHitPool / damageConvertedMulti / drMulti - takenFlat, 0) / totalTakenMulti
					else
						-- get relevant raw reductions and reduction modifiers
						local totalResistMult = output[damageConvertedType.."ResistTakenHitMulti"]

						local reductionPercent = modDB:Flag(nil, "SelfIgnore".."Base"..damageConvertedType.."DamageReduction") and 0 or output["Base"..damageConvertedType.."DamageReductionWhenHit"] or output["Base"..damageConvertedType.."DamageReduction"]
						local enemyOverwhelmPercent = modDB:Flag(nil, "SelfIgnore"..damageConvertedType.."DamageReduction") and 0 or output[damageConvertedType.."EnemyOverwhelm"]
						local flatDR = reductionPercent / 100

						-- We know the damage and armour calculation chain. The important part for max hit calculations is:
						-- 		armourDR = AppliedArmour / (AppliedArmour + data.misc.ArmourRatio * RAW * DamageConvertedMulti)
						-- 		drMulti = 1 - max(min(armourDR + FlatDR, MaxReduction) - Overwhelm, 0)	-- min and max is complicated to actually math out so skip caps first and tack it on later. Result should be close enough
						-- 		dmgAfterRes = RAW * DamageConvertedMulti * drMulti * ResistanceMulti
						-- 		damageTaken = (dmgAfterRes + takenFlat) * TakenMulti
						-- If we consider damageTaken to be the total hit pool of the actor, we can go backwards in the chain until we find the max hit - the RAW damage.
						-- Unfortunately the above is slightly simplified and is missing a line that *really* complicates stuff for exact calculations:
						--		damageTaken = damageTakenAsPhys + damageTakenAsFire + damageTakenAsCold + damageTakenAsLightning + damageTakenAsChaos
						-- Trying to solve that for RAW might require solving a polynomial equation of 6th degree, so this solution settles for solving the parts independently and then approximating the final result
						--
						-- To solve only one part the above can be expressed as this:
						--		RAW * RAW * data.misc.ArmourRatio * DamageConvertedMulti * (1 - FlatDR + Overwhelm)
						--		+ RAW * (AppliedArmour * (1 - FlatDR + Overwhelm) - AppliedArmour - (damageTaken / TakenMulti - takenFlat) / (DamageConvertedMulti * ResistanceMulti) * data.misc.ArmourRatio * DamageConvertedMulti)
						--		- (damageTaken / TakenMulti - takenFlat) / (DamageConvertedMulti * ResistanceMulti) * AppliedArmour = 0
						-- Which means that
						-- 		RAW = [quadratic]

						local oneMinusFlatPlusOverwhelm = (1 + flatDR - enemyOverwhelmPercent / 100)
						local HP_tTM_tF_DCM_tRM = (totalHitPool / totalTakenMulti - takenFlat) / (damageConvertedMulti * totalResistMult)
						
						local a = data.misc.ArmourRatio * damageConvertedMulti * oneMinusFlatPlusOverwhelm
						local b = (effectiveAppliedArmour * oneMinusFlatPlusOverwhelm - effectiveAppliedArmour - HP_tTM_tF_DCM_tRM * data.misc.ArmourRatio * damageConvertedMulti)
						local c = -HP_tTM_tF_DCM_tRM * effectiveAppliedArmour

						local RAW = (m_sqrt(b * b - 4 * a * c) - b) / (2 * a)

						-- tack on some caps
						local noDRMaxHit = totalHitPool / damageConvertedMulti / totalResistMult / totalTakenMulti * (1 - takenFlat * totalTakenMulti / totalHitPool)
						local maxDRMaxHit = noDRMaxHit / (1 - (output[damageType.."DamageReductionMax"] - enemyOverwhelmPercent) / 100)
						hitTaken = m_floor(m_max(m_min(RAW, maxDRMaxHit), noDRMaxHit))
						useConversionSmoothing = useConversionSmoothing or convertPercent ~= 100
					end
					partMin = m_min(partMin, hitTaken)
				end
			end

			local enemyDamageMult = output[damageType .."EnemyDamageMult"]

			local finalMaxHit
			if partMin == m_huge then
				finalMaxHit = m_huge
			elseif useConversionSmoothing then
				local passIncomingDamage = partMin
				local previousOverkill
				for n = 1, data.misc.maxHitSmoothingPasses do
					local _, passDamages = calcs.takenHitFromDamage(passIncomingDamage, damageType, actor)
					local passPools = calcs.reducePoolsByDamage(nil, passDamages, actor)
					local passOverkill = passPools.OverkillDamage - passPools.hitPoolRemaining
					local passRatio = 0
					for partType, _ in pairs(passDamages) do
						passRatio = m_max(passRatio, (passOverkill + output[partType.."TotalHitPool"]) / output[partType.."TotalHitPool"])
					end
					local stepSize = n > 1 and m_min(math.abs((passOverkill - previousOverkill) / previousOverkill), 2) or 1
					local stepAdjust = stepSize > 1 and -passOverkill / stepSize or n > 1 and -passOverkill * stepSize or 0
					previousOverkill = passOverkill
					passIncomingDamage = (passIncomingDamage + stepAdjust) / m_sqrt(passRatio)
					if passOverkill < 1 and passOverkill > -1 then
						break
					end
				end
				
				finalMaxHit = round(passIncomingDamage / enemyDamageMult)
			else
				finalMaxHit = round(partMin / enemyDamageMult)
			end
			
			local maxHitCurType = damageType.."MaximumHitTaken"
			output[maxHitCurType] = finalMaxHit

			if breakdown then
				breakdown[maxHitCurType] = {
					label = "Maximum hit damage breakdown",
					rowList = {},
					colList = {
						{ label = "Type", key = "type" },
						{ label = "Pool", key = "pool" },
						{ label = "Incoming", key = "incoming" },
						{ label = "Multi", key = "multi" },
						{ label = "Taken", key = "taken" },
					},
				}
				
				local fullTaken, takenDamages = calcs.takenHitFromDamage(finalMaxHit * enemyDamageMult, damageType, actor)
				fullTaken = fullTaken == fullTaken and fullTaken or 0
				
				for takenType, takenAmt in pairs(takenDamages) do
					local conversion = actor.damageShiftTable[damageType][takenType]
					local incoming = finalMaxHit * enemyDamageMult * conversion / 100
					local nanToZero = takenAmt == takenAmt and takenAmt or 0
					takenDamages[takenType] = nanToZero
					t_insert(breakdown[maxHitCurType].rowList, {
						type = s_format("%d%% as %s", conversion, takenType),
						pool = s_format("%d", output[takenType .."TotalHitPool"]),
						incoming = s_format("%.0f", incoming),
						multi = s_format("x%.3f", nanToZero / incoming),
						taken = s_format("%.0f", nanToZero),
					})
				end

				local fullMulti = fullTaken / finalMaxHit / enemyDamageMult
				t_insert(breakdown[maxHitCurType], "^8Maximum hit is calculated in reverse -")
				t_insert(breakdown[maxHitCurType], "^8from health pools, via damage reductions, to the max hit:")
				t_insert(breakdown[maxHitCurType], s_format("%d ^8(used pool)", fullTaken))
				if round(fullMulti, 2) ~= 1 then
					t_insert(breakdown[maxHitCurType], s_format("/ %.2f ^8(modifiers to damage taken)", fullMulti))
				end
				if enemyDamageMult ~= 1 then
					t_insert(breakdown[maxHitCurType], s_format("/ %.2f ^8(modifiers to enemy damage)", enemyDamageMult))
				end
				t_insert(breakdown[maxHitCurType], s_format("= %.0f ^8maximum survivable enemy damage%s", finalMaxHit, useConversionSmoothing and " (approximate)" or ""))

				t_insert(breakdown[maxHitCurType], "^8Such a hit would drain the following resources:")
				breakdown[maxHitCurType] = incomingDamageBreakdown(breakdown[maxHitCurType], calcs.reducePoolsByDamage(nil, takenDamages, actor), output)
			end
		end

		-- second minimum used for power calcs, as there are issues using average or minimum
		local minimum = m_huge
		local SecondMinimum = m_huge
		for _, damageType in ipairs(dmgTypeList) do
			if output[damageType.."MaximumHitTaken"] < minimum then
				SecondMinimum = minimum
				minimum = output[damageType.."MaximumHitTaken"]
			elseif output[damageType.."MaximumHitTaken"] < SecondMinimum then
				SecondMinimum = output[damageType.."MaximumHitTaken"]
			end
		end
		output.SecondMinimalMaximumHitTaken = SecondMinimum
	end

	-- effective health pool vs dots
	for _, damageType in ipairs(dmgTypeList) do
		output[damageType.."DotEHP"] = output[damageType.."TotalPool"] / output[damageType.."TakenDotMult"]
		if breakdown then
			breakdown[damageType.."DotEHP"] = {
				s_format("Total Pool: %d", output[damageType.."TotalPool"]),
				s_format("Dot Damage Taken modifier: %.2f", output[damageType.."TakenDotMult"]),
				s_format("Total Effective Dot Pool: %d", output[damageType.."DotEHP"]),
			}
		end
	end
	
	-- degens
	do
		output.TotalBuildDegen = 0
		for _, damageType in ipairs(dmgTypeList) do
			local baseVal = modDB:Sum("BASE", nil, damageType.."Degen")
			if baseVal > 0 then
				for damageConvertedType, convertPercent in pairs(actor.damageOverTimeShiftTable[damageType]) do
					if convertPercent > 0 then
						local total = baseVal * (convertPercent / 100) * output[damageConvertedType.."TakenDotMult"]
						output[damageConvertedType.."BuildDegen"] = (output[damageConvertedType.."BuildDegen"] or 0) + total
						output.TotalBuildDegen = output.TotalBuildDegen + total
						if breakdown then
							breakdown.TotalBuildDegen = breakdown.TotalBuildDegen or { 
								rowList = { },
								colList = {
									{ label = "Base Type", key = "type" },
									{ label = "Final Type", key = "type2" },
									{ label = "Base", key = "base" },
									{ label = "Taken As Percent", key = "conv" },
									{ label = "Multiplier", key = "mult" },
									{ label = "Total", key = "total" },
								}
							}
							t_insert(breakdown.TotalBuildDegen.rowList, {
								type = damageType,
								type2 = damageConvertedType,
								base = s_format("%.1f", baseVal),
								conv = s_format("x %.2f%%", convertPercent),
								mult = s_format("x %.2f", output[damageConvertedType.."TakenDotMult"]),
								total = s_format("%.1f", total),
							})
							breakdown[damageConvertedType.."BuildDegen"] = breakdown[damageConvertedType.."BuildDegen"] or { 
								rowList = { },
								colList = {
									{ label = "Base Type", key = "type" },
									{ label = "Base", key = "base" },
									{ label = "Taken As Percent", key = "conv" },
									{ label = "Multiplier", key = "mult" },
									{ label = "Total", key = "total" },
								}
							}
							t_insert(breakdown[damageConvertedType.."BuildDegen"].rowList, {
								type = damageType,
								base = s_format("%.1f", baseVal),
								conv = s_format("x %.2f%%", convertPercent),
								mult = s_format("x %.2f", output[damageConvertedType.."TakenDotMult"]),
								total = s_format("%.1f", total),
							})
						end
					end
				end
			end
		end
		if output.TotalBuildDegen == 0 then
			output.TotalBuildDegen = nil
		else
			output.NetLifeRegen = output.LifeRegenRecovery
			output.NetManaRegen = output.ManaRegenRecovery
			output.NetEnergyShieldRegen = output.EnergyShieldRegenRecovery
			local totalLifeDegen = 0
			local totalManaDegen = 0
			local totalEnergyShieldDegen = 0
			if breakdown then
				breakdown.NetLifeRegen = { 
						label = "Total Life Degen",
						rowList = { },
						colList = {
							{ label = "Type", key = "type" },
							{ label = "Degen", key = "degen" },
						},
					}
				breakdown.NetManaRegen = { 
						label = "Total Mana Degen",
						rowList = { },
						colList = {
							{ label = "Type", key = "type" },
							{ label = "Degen", key = "degen" },
						},
					}
				breakdown.NetEnergyShieldRegen = { 
						label = "Total Energy Shield Degen",
						rowList = { },
						colList = {
							{ label = "Type", key = "type" },
							{ label = "Degen", key = "degen" },
						},
					}
			end
			for _, damageType in ipairs(dmgTypeList) do
				if output[damageType.."BuildDegen"] then 
					local energyShieldDegen = 0
					local lifeDegen = 0
					local manaDegen = 0
					local takenFromMana = output[damageType.."MindOverMatter"] + output["sharedMindOverMatter"]
					if output.EnergyShieldRegenRecovery > 0 then 
						if modDB:Flag(nil, "EnergyShieldProtectsMana") then
							lifeDegen = output[damageType.."BuildDegen"] * (1 - takenFromMana / 100)
							energyShieldDegen = output[damageType.."BuildDegen"] * (1 - output[damageType.."EnergyShieldBypass"] / 100) * (takenFromMana / 100)
						else
							lifeDegen = output[damageType.."BuildDegen"] * (output[damageType.."EnergyShieldBypass"] / 100) * (1 - takenFromMana / 100)
							energyShieldDegen = output[damageType.."BuildDegen"] * (1 - output[damageType.."EnergyShieldBypass"] / 100)
						end
						manaDegen = output[damageType.."BuildDegen"] * (output[damageType.."EnergyShieldBypass"] / 100) * (takenFromMana / 100)
					else
						lifeDegen = output[damageType.."BuildDegen"] * (1 - takenFromMana / 100)
						manaDegen = output[damageType.."BuildDegen"] * (takenFromMana / 100)
					end
					totalLifeDegen = totalLifeDegen + lifeDegen
					totalManaDegen = totalManaDegen + manaDegen
					totalEnergyShieldDegen = totalEnergyShieldDegen + energyShieldDegen
					if breakdown then
						t_insert(breakdown.NetLifeRegen.rowList, {
							type = s_format("%s", damageType),
							degen = s_format("%.2f", lifeDegen),
						})
						t_insert(breakdown.NetManaRegen.rowList, {
							type = s_format("%s", damageType),
							degen = s_format("%.2f", manaDegen),
						})
						t_insert(breakdown.NetEnergyShieldRegen.rowList, {
							type = s_format("%s", damageType),
							degen = s_format("%.2f", energyShieldDegen),
						})
					end
				end
			end
			output.NetLifeRegen = output.NetLifeRegen - totalLifeDegen
			output.NetManaRegen = output.NetManaRegen - totalManaDegen
			output.NetEnergyShieldRegen = output.NetEnergyShieldRegen - totalEnergyShieldDegen
			output.TotalNetRegen = output.NetLifeRegen + output.NetManaRegen + output.NetEnergyShieldRegen
			if breakdown then
				t_insert(breakdown.NetLifeRegen, s_format("%.1f ^8(total life regen)", output.LifeRegenRecovery))
				t_insert(breakdown.NetLifeRegen, s_format("- %.1f ^8(total life degen)", totalLifeDegen))
				t_insert(breakdown.NetLifeRegen, s_format("= %.1f", output.NetLifeRegen))
				t_insert(breakdown.NetManaRegen, s_format("%.1f ^8(total mana regen)", output.ManaRegenRecovery))
				t_insert(breakdown.NetManaRegen, s_format("- %.1f ^8(total mana degen)", totalManaDegen))
				t_insert(breakdown.NetManaRegen, s_format("= %.1f", output.NetManaRegen))
				t_insert(breakdown.NetEnergyShieldRegen, s_format("%.1f ^8(total energy shield regen)", output.EnergyShieldRegenRecovery))
				t_insert(breakdown.NetEnergyShieldRegen, s_format("- %.1f ^8(total energy shield degen)", totalEnergyShieldDegen))
				t_insert(breakdown.NetEnergyShieldRegen, s_format("= %.1f", output.NetEnergyShieldRegen))
				breakdown.TotalNetRegen = {
					s_format("Net Life Regen: %.1f", output.NetLifeRegen),
					s_format("+ Net Mana Regen: %.1f", output.NetManaRegen),
					s_format("+ Net Energy Shield Regen: %.1f", output.NetEnergyShieldRegen),
					s_format("= Total Net Regen: %.1f", output.TotalNetRegen)
				}
			end
		end
		local enemyCritAilmentEffect = 1 + (output.EnemyCritChance or 0) / 100 * 0.5 * (1 - output.CritExtraDamageReduction / 100)
		-- this is just used so that ailments don't always showup if the enemy has no other way of applying the ailment and they have a low crit chance
		local enemyCritThreshold = 10.1
		local enemyBleedChance = 0
		local enemyIgniteChance = 0
		if output.SelfIgniteEffect ~= 0 and output.IgniteAvoidChance < 100 and output.SelfIgniteDuration ~= 0 and damageCategoryConfig ~= "DamageOverTime" then
			enemyIgniteChance = enemyDB:Sum("BASE", nil, "IgniteChance", "ElementalAilmentChance", "AilmentChance")
			local enemyCritAilmentChance = (not modDB:Flag(nil, "CritsOnYouDontAlwaysApplyElementalAilments")) and ((output.EnemyCritChance > enemyCritThreshold or enemyIgniteChance > 0) and output.EnemyCritChance or 0) or 0
			enemyIgniteChance = (enemyCritAilmentChance + (1 - enemyCritAilmentChance / 100) * enemyIgniteChance) * (1 - output.IgniteAvoidChance / 100)
		end
		local enemyPoisonChance = 0
		if output.SelfPoisonEffect ~= 0 and output.PoisonAvoidChance < 100 and output.SelfPoisonDuration ~= 0 and damageCategoryConfig ~= "DamageOverTime" then
			enemyPoisonChance = enemyDB:Sum("BASE", nil, "PoisonChance") * (1 - output.PoisonAvoidChance / 100)
		end
		if damageCategoryConfig == "DamageOverTime" or (enemyIgniteChance + enemyPoisonChance + enemyBleedChance) > 0 then
			output.TotalDegen = output.TotalBuildDegen or 0
			if damageCategoryConfig == "DamageOverTime" then
				for _, damageType in ipairs(dmgTypeList) do
					local source = "Config"
					local baseVal = tonumber(env.configInput["enemy"..damageType.."Damage"])
					if baseVal == nil then
						source = "Default"
						baseVal = tonumber(env.configPlaceholder["enemy"..damageType.."Damage"]) or 0
					end
					if baseVal > 0 then
						for damageConvertedType, convertPercent in pairs(actor.damageOverTimeShiftTable[damageType]) do
							if convertPercent > 0 then
								local total = baseVal * (convertPercent / 100) * output[damageConvertedType.."TakenDotMult"]
								output[damageConvertedType.."EnemyDegen"] = (output[damageConvertedType.."EnemyDegen"] or 0) + total
								output.TotalDegen = output.TotalDegen + total
								if breakdown then
									breakdown.TotalDegen = breakdown.TotalDegen or { 
										rowList = { },
										colList = {
											{ label = "Source", key = "source" },
											{ label = "Base Type", key = "type" },
											{ label = "Final Type", key = "type2" },
											{ label = "Base", key = "base" },
											{ label = "Taken As Percent", key = "conv" },
											{ label = "Multiplier", key = "mult" },
											{ label = "Total", key = "total" },
										}
									}
									t_insert(breakdown.TotalDegen.rowList, {
										source = source,
										type = damageType,
										type2 = damageConvertedType,
										base = s_format("%.1f", baseVal),
										conv = s_format("x %.2f%%", convertPercent),
										mult = s_format("x %.2f", output[damageConvertedType.."TakenDotMult"]),
										total = s_format("%.1f", total),
									})
									breakdown[damageConvertedType.."EnemyDegen"] = breakdown[damageConvertedType.."EnemyDegen"] or { 
										rowList = { },
										colList = {
											{ label = "Source", key = "source" },
											{ label = "Base Type", key = "type" },
											{ label = "Base", key = "base" },
											{ label = "Taken As Percent", key = "conv" },
											{ label = "Multiplier", key = "mult" },
											{ label = "Total", key = "total" },
										}
									}
									t_insert(breakdown[damageConvertedType.."EnemyDegen"].rowList, {
										source = source,
										type = damageType,
										base = s_format("%.1f", baseVal),
										conv = s_format("x %.2f%%", convertPercent),
										mult = s_format("x %.2f", output[damageConvertedType.."TakenDotMult"]),
										total = s_format("%.1f", total),
									})
								end
							end
						end
					end
				end
			elseif (enemyIgniteChance + enemyPoisonChance + enemyBleedChance) > 0 then
				local ailmentList = {}
				if enemyBleedChance > 0 then
					ailmentList["Bleed"] = { damageType = "Physical", sourceTypes = { "Physical" } }
				end
				if enemyIgniteChance > 0 then
					ailmentList["Ignite"] = { damageType = "Fire", sourceTypes = enemyDB:Flag(nil, "AllDamageIgnites") and dmgTypeList or { "Fire" } }
				end
				if enemyPoisonChance > 0 then
					ailmentList["Poison"] = { damageType = "Chaos", sourceTypes = { "Physical", "Chaos" } }
				end
				for source, ailment in pairs(ailmentList) do
					local baseVal = 0
					for _, damageType in ipairs(ailment.sourceTypes) do
						baseVal = baseVal + output[damageType.."TakenDamage"]
					end
					baseVal = baseVal * data.misc[source.."PercentBase"] * (enemyCritAilmentEffect / output["EnemyCritEffect"]) * output["Self"..source.."Effect"] / 100
					if baseVal > 0 then
						for damageConvertedType, convertPercent in pairs(actor.damageOverTimeShiftTable[ailment.damageType]) do
							if convertPercent > 0 then
								local total = baseVal * (convertPercent / 100) * output[damageConvertedType.."TakenDotMult"]
								output[damageConvertedType.."EnemyDegen"] = (output[damageConvertedType.."EnemyDegen"] or 0) + total
								output.TotalDegen = output.TotalDegen + total
								if breakdown then
									breakdown.TotalDegen = breakdown.TotalDegen or { 
										rowList = { },
										colList = {
											{ label = "Source", key = "source" },
											{ label = "Base Type", key = "type" },
											{ label = "Final Type", key = "type2" },
											{ label = "Base", key = "base" },
											{ label = "Taken As Percent", key = "conv" },
											{ label = "Multiplier", key = "mult" },
											{ label = "Total", key = "total" },
										}
									}
									t_insert(breakdown.TotalDegen.rowList, {
										source = source,
										type = ailment.damageType,
										type2 = damageConvertedType,
										base = s_format("%.1f", baseVal),
										conv = s_format("x %.2f%%", convertPercent),
										mult = s_format("x %.2f", output[damageConvertedType.."TakenDotMult"]),
										total = s_format("%.1f", total),
									})
									breakdown[damageConvertedType.."EnemyDegen"] = breakdown[damageConvertedType.."EnemyDegen"] or { 
										rowList = { },
										colList = {
											{ label = "Source", key = "source" },
											{ label = "Base Type", key = "type" },
											{ label = "Base", key = "base" },
											{ label = "Taken As Percent", key = "conv" },
											{ label = "Multiplier", key = "mult" },
											{ label = "Total", key = "total" },
										}
									}
									t_insert(breakdown[damageConvertedType.."EnemyDegen"].rowList, {
										source = source,
										type = ailment.damageType,
										base = s_format("%.1f", baseVal),
										conv = s_format("x %.2f%%", convertPercent),
										mult = s_format("x %.2f", output[damageConvertedType.."TakenDotMult"]),
										total = s_format("%.1f", total),
									})
								end
							end
						end
					end
				end
			end
			if output.TotalDegen == (output.TotalBuildDegen or 0) then
				output.TotalDegen = nil
			else
				output.ComprehensiveNetLifeRegen = output.LifeRegenRecovery
				output.ComprehensiveNetManaRegen = output.ManaRegenRecovery
				output.ComprehensiveNetEnergyShieldRegen = output.EnergyShieldRegenRecovery
				local totalLifeDegen = 0
				local totalManaDegen = 0
				local totalEnergyShieldDegen = 0
				if breakdown then
					breakdown.ComprehensiveNetLifeRegen = { 
							label = "Total Life Degen",
							rowList = { },
							colList = {
								{ label = "Type", key = "type" },
								{ label = "Degen", key = "degen" },
							},
						}
					breakdown.ComprehensiveNetManaRegen = { 
							label = "Total Mana Degen",
							rowList = { },
							colList = {
								{ label = "Type", key = "type" },
								{ label = "Degen", key = "degen" },
							},
						}
					breakdown.ComprehensiveNetEnergyShieldRegen = { 
							label = "Total Energy Shield Degen",
							rowList = { },
							colList = {
								{ label = "Type", key = "type" },
								{ label = "Degen", key = "degen" },
							},
						}
				end
				for _, damageType in ipairs(dmgTypeList) do
					local typeDegen = (output[damageType.."BuildDegen"] or 0) + (output[damageType.."EnemyDegen"] or 0)
					if typeDegen ~= 0 then 
						local energyShieldDegen = 0
						local lifeDegen = 0
						local manaDegen = 0
						local takenFromMana = output[damageType.."MindOverMatter"] + output["sharedMindOverMatter"]
						if output.EnergyShieldRegenRecovery > 0 then 
							if modDB:Flag(nil, "EnergyShieldProtectsMana") then
								lifeDegen = typeDegen * (1 - takenFromMana / 100)
								energyShieldDegen = typeDegen * (1 - output[damageType.."EnergyShieldBypass"] / 100) * (takenFromMana / 100)
							else
								lifeDegen = typeDegen * (output[damageType.."EnergyShieldBypass"] / 100) * (1 - takenFromMana / 100)
								energyShieldDegen = typeDegen * (1 - output[damageType.."EnergyShieldBypass"] / 100)
							end
							manaDegen = typeDegen * (output[damageType.."EnergyShieldBypass"] / 100) * (takenFromMana / 100)
						else
							lifeDegen = typeDegen * (1 - takenFromMana / 100)
							manaDegen = typeDegen * (takenFromMana / 100)
						end
						totalLifeDegen = totalLifeDegen + lifeDegen
						totalManaDegen = totalManaDegen + manaDegen
						totalEnergyShieldDegen = totalEnergyShieldDegen + energyShieldDegen
						if breakdown then
							t_insert(breakdown.ComprehensiveNetLifeRegen.rowList, {
								type = s_format("%s", damageType),
								degen = s_format("%.2f", lifeDegen),
							})
							t_insert(breakdown.ComprehensiveNetManaRegen.rowList, {
								type = s_format("%s", damageType),
								degen = s_format("%.2f", manaDegen),
							})
							t_insert(breakdown.ComprehensiveNetEnergyShieldRegen.rowList, {
								type = s_format("%s", damageType),
								degen = s_format("%.2f", energyShieldDegen),
							})
						end
					end
				end
				output.ComprehensiveNetLifeRegen = output.ComprehensiveNetLifeRegen + (output.LifeRecoupRecoveryAvg or 0) - totalLifeDegen - (output.LifeLossLostAvg or 0)
				output.ComprehensiveNetManaRegen = output.ComprehensiveNetManaRegen + (output.ManaRecoupRecoveryAvg or 0) - totalManaDegen
				output.ComprehensiveNetEnergyShieldRegen = output.ComprehensiveNetEnergyShieldRegen + (output.EnergyShieldRecoupRecoveryAvg or 0) - totalEnergyShieldDegen
				output.ComprehensiveTotalNetRegen = output.ComprehensiveNetLifeRegen + output.ComprehensiveNetManaRegen + output.ComprehensiveNetEnergyShieldRegen
				if breakdown then
					t_insert(breakdown.ComprehensiveNetLifeRegen, s_format("%.1f ^8(total life regen)", output.LifeRegenRecovery))
					if (output.LifeRecoupRecoveryAvg or 0) ~= 0 then
						t_insert(breakdown.ComprehensiveNetLifeRegen, s_format("+ %.1f ^8(average life recoup)", (output.LifeRecoupRecoveryAvg or 0)))
					end
					t_insert(breakdown.ComprehensiveNetLifeRegen, s_format("- %.1f ^8(total life degen)", totalLifeDegen))
					if (output.LifeLossLostAvg or 0) ~= 0 then
						t_insert(breakdown.ComprehensiveNetLifeRegen, s_format("- %.1f ^8(average life lost over time)", (output.LifeLossLostAvg or 0)))
					end
					t_insert(breakdown.ComprehensiveNetLifeRegen, s_format("= %.1f", output.ComprehensiveNetLifeRegen))
					t_insert(breakdown.ComprehensiveNetManaRegen, s_format("%.1f ^8(total mana regen)", output.ManaRegenRecovery))
					if (output.ManaRecoupRecoveryAvg or 0) ~= 0 then
						t_insert(breakdown.ComprehensiveNetManaRegen, s_format("+ %.1f ^8(average mana recoup)", (output.ManaRecoupRecoveryAvg or 0)))
					end
					t_insert(breakdown.ComprehensiveNetManaRegen, s_format("- %.1f ^8(total mana degen)", totalManaDegen))
					t_insert(breakdown.ComprehensiveNetManaRegen, s_format("= %.1f", output.ComprehensiveNetManaRegen))
					t_insert(breakdown.ComprehensiveNetEnergyShieldRegen, s_format("%.1f ^8(total energy shield regen)", output.EnergyShieldRegenRecovery))
					if (output.EnergyShieldRecoupRecoveryAvg or 0) ~= 0 then
						t_insert(breakdown.ComprehensiveNetEnergyShieldRegen, s_format("+ %.1f ^8(average energy shield recoup)", (output.EnergyShieldRecoupRecoveryAvg or 0)))
					end
					t_insert(breakdown.ComprehensiveNetEnergyShieldRegen, s_format("- %.1f ^8(total energy shield degen)", totalEnergyShieldDegen))
					t_insert(breakdown.ComprehensiveNetEnergyShieldRegen, s_format("= %.1f", output.ComprehensiveNetEnergyShieldRegen))
					breakdown.ComprehensiveTotalNetRegen = {
						s_format("Net Life Regen: %.1f", output.ComprehensiveNetLifeRegen),
						s_format("+ Net Mana Regen: %.1f", output.ComprehensiveNetManaRegen),
						s_format("+ Net Energy Shield Regen: %.1f", output.ComprehensiveNetEnergyShieldRegen),
						s_format("= Total Net Regen: %.1f", output.ComprehensiveTotalNetRegen)
					}
				end
			end
		end
	end

	--region Add breakdown to enemy incoming damage
	if breakdown then
		local takenHit = { }
		for _, damageType in ipairs(dmgTypeList) do
			takenHit[damageType] = output[damageType.."TakenHit"] > 0 and output[damageType.."TakenHit"] or nil
			t_insert(breakdown["totalTakenHit"].rowList, {
				type = s_format("%s", damageType),
				incoming = s_format("%.1f incoming damage", output[damageType.."TakenDamage"]),
				mult = s_format("x %.3f damage mult", output[damageType.."TakenHitMult"] ),
				value = s_format("%d", m_ceil(output[damageType.."TakenHit"])),
			})
		end
		local poolsRemaining = calcs.reducePoolsByDamage(nil, takenHit, actor)
		
		t_insert(breakdown["totalTakenHit"], "Such a hit would drain the following resources:")
		breakdown["totalTakenHit"] = incomingDamageBreakdown(breakdown["totalTakenHit"], poolsRemaining, output)

		for _, damageType in ipairs(dmgTypeList) do
			local breakdownTable = {}
			local resourcesLost = poolsRemaining.resourcesLostToTypeDamage[damageType]
			local resourcesLostSum = 0

			t_insert(breakdownTable, s_format("Final %s Damage taken:", damageType))
			t_insert(breakdownTable, s_format("%.1f incoming damage", output[damageType.."TakenDamage"]))
			t_insert(breakdownTable, s_format("x %.3f damage mult", output[damageType.."TakenHitMult"]))
			t_insert(breakdownTable, s_format("= %.1f", output[damageType.."TakenHit"]))

			t_insert(breakdownTable, "This part of the hit drains the following resources:")
			if resourcesLost.frostShield then
				resourcesLostSum = resourcesLostSum + resourcesLost.frostShield
				t_insert(breakdownTable, s_format("\t%d "..colorCodes.GEM.."Frost Shield Life", resourcesLost.frostShield))
			end
			if resourcesLost.spectres then
				resourcesLostSum = resourcesLostSum + resourcesLost.spectres
				t_insert(breakdownTable, s_format("\t%d "..colorCodes.GEM.."Total Spectre Life", resourcesLost.spectres))
			end
			if resourcesLost.totems then
				resourcesLostSum = resourcesLostSum + resourcesLost.totems
				t_insert(breakdownTable, s_format("\t%d "..colorCodes.GEM.."Total Totem Life", resourcesLost.totems))
			end
			if resourcesLost.vaalRejuvenationTotems then
				resourcesLostSum = resourcesLostSum + resourcesLost.vaalRejuvenationTotems
				t_insert(breakdownTable, s_format("\t%d "..colorCodes.GEM.."Total Vaal Rejuvenation Totem Life", resourcesLost.vaalRejuvenationTotems))
			end
			if resourcesLost.radianceSentinel then
				resourcesLostSum = resourcesLostSum + resourcesLost.radianceSentinel
				t_insert(breakdownTable, s_format("\t%d "..colorCodes.GEM.."Total Sentinel of Radiance Life", resourcesLost.radianceSentinel))
			end
			if resourcesLost.soulLink then
				resourcesLostSum = resourcesLostSum + resourcesLost.soulLink
				t_insert(breakdownTable, s_format("\t%d "..colorCodes.GEM.."Total Allied Energy shield", resourcesLost.soulLink))
			end
			if resourcesLost.aegis then
				resourcesLostSum = resourcesLostSum + resourcesLost.aegis
				t_insert(breakdownTable, s_format("\t%d "..colorCodes.GEM.."%s Aegis charge", resourcesLost.aegis, damageType))
			end
			if resourcesLost.sharedElementalAegis then
				resourcesLostSum = resourcesLostSum + resourcesLost.sharedElementalAegis
				t_insert(breakdownTable, s_format("\t%d "..colorCodes.GEM.."Elemental Aegis charge", resourcesLost.sharedElementalAegis))
			end
			if resourcesLost.sharedAegis then
				resourcesLostSum = resourcesLostSum + resourcesLost.sharedAegis
				t_insert(breakdownTable, s_format("\t%d "..colorCodes.GEM.."Shared Aegis charge", resourcesLost.sharedAegis))
			end
			if resourcesLost.guard then
				resourcesLostSum = resourcesLostSum + resourcesLost.guard
				t_insert(breakdownTable, s_format("\n\t%d "..colorCodes.SCOURGE.."%s Guard charge", resourcesLost.guard, damageType))
			end
			if resourcesLost.sharedGuard then
				resourcesLostSum = resourcesLostSum + resourcesLost.sharedGuard
				t_insert(breakdownTable, s_format("\t%d "..colorCodes.SCOURGE.."Shared Guard charge", resourcesLost.sharedGuard))
			end
			if resourcesLost.ward then
				resourcesLostSum = resourcesLostSum + resourcesLost.ward
				t_insert(breakdownTable, s_format("\t%d "..colorCodes.WARD.."Ward", resourcesLost.ward))
			end
			if resourcesLost.energyShield then
				resourcesLostSum = resourcesLostSum + resourcesLost.energyShield
				t_insert(breakdownTable, s_format("\t%d "..colorCodes.ES.."Energy Shield%s", resourcesLost.energyShield, damageType == "Chaos" and "^8 (ES takes double damage from chaos)" or ""))
			end
			if resourcesLost.eternalLifePrevented then
				t_insert(breakdownTable, s_format("\t%d "..colorCodes.POSITIVE.."Life change prevented by Eternal Life", resourcesLost.eternalLifePrevented))
			end
			if resourcesLost.mana then
				resourcesLostSum = resourcesLostSum + resourcesLost.mana
				t_insert(breakdownTable, s_format("\t%d "..colorCodes.MANA.."Mana", resourcesLost.mana))
			end
			if resourcesLost.lifeLossPrevented and resourcesLost.lifeLossPrevented > 0 then
				resourcesLostSum = resourcesLostSum + resourcesLost.lifeLossPrevented
				t_insert(breakdownTable, s_format("\t%d "..colorCodes.LIFE.."Life ^7Loss Prevented", resourcesLost.lifeLossPrevented))
			end
			if resourcesLost.life and resourcesLost.life > 0 then
				resourcesLostSum = resourcesLostSum + resourcesLost.life
				t_insert(breakdownTable, s_format("\t%d "..colorCodes.LIFE.."Life", resourcesLost.life))
			end
			if resourcesLost.overkill then
				resourcesLostSum = resourcesLostSum + resourcesLost.overkill
				t_insert(breakdownTable, s_format("\t%d "..colorCodes.NEGATIVE.."Overkill damage", resourcesLost.overkill))
			end
			t_insert(breakdownTable, s_format("\t^8(%d total)", resourcesLostSum))
			breakdown[damageType.."TakenHit"] = breakdownTable
		end
	end
	--endregion
end
