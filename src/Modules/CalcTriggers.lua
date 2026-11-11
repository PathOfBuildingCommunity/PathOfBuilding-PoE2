-- Path of Building
--
-- Module: Calc Triggers
-- Performs trigger rate calculations
--

---@class Calcs
local calcs = require("Modules.CalcBase")

local ipairs = ipairs
local t_insert = table.insert
local m_min = math.min
local m_floor = math.floor
local m_ceil = math.ceil
local m_sqrt = math.sqrt
local s_format = string.format
local m_huge = math.huge

-- Add trigger-based damage modifiers
local function addTriggerIncMoreMods(activeSkill, sourceSkill)
	for _, value in ipairs(activeSkill.skillModList:Tabulate("INC", sourceSkill.skillCfg, "TriggeredDamage")) do
		activeSkill.skillModList:NewMod("Damage", "INC", value.mod.value, value.mod.source, value.mod.flags, value.mod.keywordFlags, unpack(value.mod))
	end
	for _, value in ipairs(activeSkill.skillModList:Tabulate("MORE", sourceSkill.skillCfg, "TriggeredDamage")) do
		activeSkill.skillModList:NewMod("Damage", "MORE", value.mod.value, value.mod.source, value.mod.flags, value.mod.keywordFlags, unpack(value.mod))
	end
end

local function isTriggered(skill)
	return skill.skillData.triggeredByUnique or skill.skillData.triggered or skill.skillTypes[SkillType.InbuiltTrigger] or skill.skillTypes[SkillType.Triggered] or skill.activeEffect.grantedEffect.triggered or (skill.activeEffect.srcInstance and skill.activeEffect.srcInstance.triggered)
end

local dmgTypeList = {"Physical", "Lightning", "Cold", "Fire", "Chaos"}

---@param env Env
---@param skill ActiveSkill
---@return table<string, boolean>
local function getSkillFlags(env, skill)
	local statSet = env.mode == "CALCS" and skill.activeEffect.statSetCalcs or skill.activeEffect.statSet
	return statSet and statSet.skillFlags or {}
end

-- PoE2 Meta gems
--
-- A meta gem accumulates Energy from its own condition and triggers every skill
-- socketed alongside it once Energy reaches maximum while discarding excess energy.
-- Maximum Energy is the sum of the Energy cost of each socketed skill, which is
-- derived from that skill's total cast time.

-- Energy cost of a single skill socketed in a meta gem.
-- Modifiers to Total cast time count double towards the cost.
---@param skill ActiveSkill
---@return number
local function calcSocketedSkillEnergy(skill)
	local energyPerSecond = 1000 / skill.skillData.energyPerCastTimeMs
	local baseCastTime = skill.activeEffect.grantedEffect.castTime or 0
	local addedCastTime = skill.skillModList:Sum("BASE", skill.skillCfg, "TotalCastTime")
	return baseCastTime * energyPerSecond + addedCastTime * energyPerSecond * 2
end

-- The meta gem driving the skill currently being calculated
---@param env Env
---@param actor Actor
---@return ActiveSkill?
local function findMetaGemSkill(env, actor)
	local srcInstance = actor.mainSkill.triggeredBy.srcInstance
	for _, skill in ipairs(env.player.activeSkillList) do
		if skill.skillTypes[SkillType.Meta] and skill.socketGroup == actor.mainSkill.socketGroup and skill.activeEffect.srcInstance == srcInstance then
			return skill
		end
	end
end

-- Total Energy needed for one trigger, and the skills that will be triggered
---@param env Env
---@param metaSkill ActiveSkill
---@param breakdown string[]?
---@return number maxEnergy
---@return ActiveSkill[] triggeredSkills
local function calcMaxEnergy(env, metaSkill, breakdown)
	local maxEnergy = metaSkill.skillData.maxEnergy or 0
	local triggeredSkills = {}
	for _, skill in ipairs(env.player.activeSkillList) do
		if skill.socketGroup == metaSkill.socketGroup and skill.skillData.energyPerCastTimeMs and not getSkillFlags(env, skill).disable then
			t_insert(triggeredSkills, skill)
			if metaSkill.skillData.maxEnergyFromSocketedSkills then
				local energy = calcSocketedSkillEnergy(skill)
				maxEnergy = maxEnergy + energy
				if breakdown then
					t_insert(breakdown, s_format("+ %.0f ^8(%s)", energy, skill.activeEffect.grantedEffect.name))
				end
			end
		end
	end
	return maxEnergy, triggeredSkills
end

---@param skill ActiveSkill
local function canHit(skill)
	return skill.skillTypes[SkillType.Attack] or skill.skillTypes[SkillType.Damage]
end

---@param output Output
---@param kind "StoredCritAvg"|"StoredCombinedAvg"
---@return number
local function sumDamageTypes(output, kind)
	local total = 0
	for _, damageType in ipairs(dmgTypeList) do
		total = total + (output[damageType .. kind] or 0)
	end
	return total
end

-- Hit damage before mitigation, as used for ailments.
---@param output Output
---@param kind "StoredCritAvg"|"StoredCombinedAvg"
---@param skillData table<string, any>
---@return number
local function unmitigatedDamage(output, kind, skillData)
	if output.MainHand or output.OffHand then
		local mainHand = output.MainHand and sumDamageTypes(output.MainHand, kind) or 0
		local offHand = output.OffHand and sumDamageTypes(output.OffHand, kind) or 0
		if mainHand > 0 and offHand > 0 and not skillData.combinesHitsWhenDualWielding then
			return (mainHand + offHand) / 2
		end
		return mainHand + offHand
	end
	return sumDamageTypes(output, kind)
end

---@param env Env
---@return number
local function getMonsterPower(env)
	return env.modDB:Override(nil, "MonsterPower") or env.modDB:Sum("BASE", nil, "MonsterPower")
end

---@alias MetaGemEnergyFunc fun(env: Env, actor: Actor, metaData: table<string, any>, energyMult: number, maxEnergy: number, config: MetaGemConfig): energyPerEvent: number?, eventRate: number?, source: ActiveSkill?

---@class MetaGemConfig
---@field eventName string What gains the Energy, used in breakdowns
---@field energy MetaGemEnergyFunc Energy per event, events per second, and the skill causing them if any. No Energy means no source was found
---@field energyStat string? hitEnergy: skillData key of the meta gem's Energy per Monster Power
---@field onCrit boolean? hitEnergy: only Critical Hits generate Energy
---@field sourceCond (fun(skill: ActiveSkill): boolean?)? hitEnergy: which skills can generate Energy

-- Energy gained from our own hits scales with the share of the enemy's Ailment Threshold
-- the hit deals, so harder hits generate more
---@param env Env
---@param cachedData CachedSkillData
---@param metaData table<string, any>
---@param config MetaGemConfig
---@return number? energyPerHit
---@return number? hitRate
local function calcHitEnergy(env, cachedData, metaData, config)
	local output = cachedData.Env.player.output
	local rate = (cachedData.HitSpeed or cachedData.Speed or 0) * (output.DpsMultiplier or 1)
	if config.onCrit then
		if (output.CritChance or 0) <= 0 then
			return
		end
		-- Critical Hit chance already accounts for missing
		rate = rate * output.CritChance / 100
	else
		rate = rate * (output.HitChance or 100) / 100
	end
	local damage = unmitigatedDamage(output, config.onCrit and "StoredCritAvg" or "StoredCombinedAvg", cachedData.ActiveSkill.skillData)
	return metaData[config.energyStat] * getMonsterPower(env) * damage / output.EnemyAilmentThreshold, rate
end

-- Pick the skill whose hits trigger the meta gem most often.
-- Energy beyond maximum is discarded, so sources are compared by trigger rate
---@type MetaGemEnergyFunc
local function hitEnergy(env, actor, metaData, energyMult, maxEnergy, config)
	local source, bestEnergy, bestRate, bestTriggerRate = nil, 0, 0, 0
	for _, skill in ipairs(env.player.activeSkillList) do
		local flags = getSkillFlags(env, skill)
		-- Only hits made by the player themselves generate Energy
		local usedByPlayer = not (skill.skillTypes[SkillType.OtherThingUsesSkill] or skill.skillTypes[SkillType.UsedByProxy] or flags.totem or flags.trap or flags.mine)
		if canHit(skill) and not isTriggered(skill) and usedByPlayer and not flags.disable and (not config.sourceCond or config.sourceCond(skill)) then
			local uuid = cacheSkillUUID(skill, env)
			local sourceCache = env.triggerSourceCache
			local cachedData = sourceCache and sourceCache[uuid]
			if not cachedData then
				if not GlobalCache.cachedData[env.mode][uuid] or env.mode == "CALCULATOR" then
					calcs.buildActiveSkill(env, env.mode, skill, uuid)
				end
				cachedData = GlobalCache.cachedData[env.mode][uuid]
				if sourceCache then
					sourceCache[uuid] = cachedData
				end
			end
			if cachedData then
				local energy, rate = calcHitEnergy(env, cachedData, metaData, config)
				local energyPerHit = energy and m_floor(energy * energyMult * 100 + 1e-9) / 100
				local triggerRate = energyPerHit and energyPerHit > 0 and rate / m_ceil(maxEnergy / energyPerHit - 1e-9)
				if triggerRate and triggerRate > bestTriggerRate then
					source, bestEnergy, bestRate, bestTriggerRate = skill, energy, rate, triggerRate
				end
			end
		end
	end
	if source then
		return bestEnergy, bestRate, source
	end
end

---@type MetaGemEnergyFunc
local function blockEnergy(env, actor, metaData)
	local enemySkillTime = actor.output.enemySkillTime or 0
	if enemySkillTime <= 0 then
		return metaData.energyOnBlock, 0
	end
	return metaData.energyOnBlock, (actor.output.EffectiveBlockChance or 0) / 100 / enemySkillTime
end

---@param skill ActiveSkill
local function isMeleeAttack(skill)
	return skill.skillTypes[SkillType.Melee] and skill.skillTypes[SkillType.Attack]
end

-- Keyed by the hidden support each meta gem applies to its socketed skills.
-- energy returns the Energy gained per event, how often that event happens, and the skill causing it if any
---@type table<string, MetaGemConfig>
local metaGemConfigs = {
	["SupportMetaCastOnCritPlayer"] = { eventName = "Critical Hit", energy = hitEnergy, energyStat = "energyPerPowerOnCrit", onCrit = true },
	["SupportMetaCastFireSpellOnHitPlayer"] = { eventName = "melee Hit", energy = hitEnergy, energyStat = "energyPerPowerOnMeleeHit", sourceCond = isMeleeAttack },
	["SupportMetaCastLightningSpellOnHitPlayer"] = { eventName = "melee Hit", energy = hitEnergy, energyStat = "energyPerPowerOnMeleeHit", sourceCond = isMeleeAttack },
	["SupportMetaCastOnBlockPlayer"] = { eventName = "Block", energy = blockEnergy },
	["SupportMetaCastCurseOnBlockPlayer"] = { eventName = "Block", energy = blockEnergy },
	["SupportMetaCastOnDodgePlayer"] = { eventName = "dodge roll metre", energy = function(env, actor, metaData)
		-- Roll distance scales with the square root of movement speed. Energy is gained at each whole metre,
		-- and metres left in a roll after a trigger count towards the next one
			local distance = m_floor(calcLib.val(env.modDB, "DodgeRollDistance", { skillCond = { DodgeRolledRecently = true } }) * m_sqrt(actor.output.MovementSpeedMod or 1) + 1e-9)
		local rollsPerSecond = env.modDB:Override(nil, "DodgeRollsPerSecond") or env.modDB:Sum("BASE", nil, "DodgeRollsPerSecond")
		return metaData.energyPerMetreDodgeRolling, distance * rollsPerSecond
	end },
	["SupportMetaCastOnCharmUsePlayer"] = { eventName = "Charm Charge", energy = function(env, actor, metaData)
		return metaData.energyPerCharmCharge, env.modDB:Sum("BASE", nil, "Multiplier:CharmChargesUsedPerSecond")
	end },
}

---@param skill ActiveSkill
---@param message string
local function assumeSelfCast(skill, message)
	skill.skillData.triggered = nil
	skill.infoMessage = message
	skill.infoMessage2 = "DPS reported assuming Self-Cast"
	skill.infoTrigger = ""
end

---@param env Env
---@param actor Actor
---@param metaSkill ActiveSkill
---@param config MetaGemConfig
local function metaGemTriggerHandler(env, actor, metaSkill, config)
	local output = actor.output
	---@class Breakdown
	local breakdown = actor.breakdown
	---@type ActiveSkill
	local skill = actor.mainSkill
	local triggerName = metaSkill.activeEffect.grantedEffect.name

	local maxEnergyBreakdown = breakdown and {}
	local maxEnergy, triggeredSkills = calcMaxEnergy(env, metaSkill, maxEnergyBreakdown)
	if maxEnergy <= 0 then
		assumeSelfCast(skill, s_format("%s has no socketed skills that use Energy", triggerName))
		return
	end
	local energyMult = calcLib.mod(metaSkill.skillModList, metaSkill.skillCfg, "EnergyGenerated")
	local energyPerEvent, eventRate, source = config.energy(env, actor, metaSkill.skillData, energyMult, maxEnergy, config)
	if not energyPerEvent then
		assumeSelfCast(skill, s_format("No %s Triggering Skill Found", triggerName))
		return
	end

	-- Energy gains round down to 0.01
	energyPerEvent = m_floor(energyPerEvent * energyMult * 100 + 1e-9) / 100
	if energyPerEvent * eventRate <= 0 then
		assumeSelfCast(skill, s_format("%s gains no Energy from %ss", triggerName, config.eventName))
		return
	end
	-- Excess Energy is discarded when the meta gem triggers, so each trigger takes a whole number of events
	local events = m_ceil(maxEnergy / energyPerEvent - 1e-9)
	output.EnergyPerSecond = energyPerEvent * eventRate
	output.MaxEnergy = maxEnergy

	-- A triggered skill's own cooldown still caps how often it can go off
	local triggerRateCap = m_huge
	local cooldown, rounded = calcSkillCooldown(skill.skillModList, skill.skillCfg, skill.skillData)
	if cooldown > 0 then
		triggerRateCap = 1 / cooldown
		output.TriggerRateCap = triggerRateCap
		if breakdown then
			breakdown.TriggerRateCap = {
				s_format("1 / %.3fs ^8(cooldown%s)", cooldown, rounded and ", rounded up to nearest server tick" or ""),
				s_format("= %.2f ^8per second", triggerRateCap),
			}
		end
	end

	output.SkillTriggerRate = m_min(eventRate / events, triggerRateCap)
	skill.skillData.triggered = true
	skill.skillData.triggerRate = output.SkillTriggerRate
	if source then
		skill.skillData.triggerSourceUUID = cacheSkillUUID(source, env)
		skill.infoMessage = triggerName .. "'s Trigger: " .. source.activeEffect.grantedEffect.name
	else
		skill.infoMessage = triggerName .. " Trigger"
	end
	skill.infoTrigger = triggerName
	addTriggerIncMoreMods(skill, source or skill)

	if breakdown then
		breakdown.MaxEnergy = maxEnergyBreakdown
		if metaSkill.skillData.maxEnergyFromSocketedSkills then
			t_insert(breakdown.MaxEnergy, 1, "Energy cost of each socketed skill (100 per second of base cast time, 200 per second of added total cast time):")
		end
		t_insert(breakdown.MaxEnergy, s_format("= %.0f ^8(maximum Energy)", maxEnergy))

		breakdown.EnergyPerSecond = {}
		if source then
			t_insert(breakdown.EnergyPerSecond, s_format("%.2f ^8(Energy per %s from %s)", energyPerEvent, config.eventName, source.activeEffect.grantedEffect.name))
			t_insert(breakdown.EnergyPerSecond, s_format("^8(Monster Power x unmitigated %s damage / enemy Ailment Threshold)", config.eventName))
		else
			t_insert(breakdown.EnergyPerSecond, s_format("%.2f ^8(Energy per %s)", energyPerEvent, config.eventName))
		end
		t_insert(breakdown.EnergyPerSecond, s_format("x %.2f ^8(%ss per second)", eventRate, config.eventName))
		t_insert(breakdown.EnergyPerSecond, s_format("= %.2f ^8(Energy per second)", output.EnergyPerSecond))

		breakdown.SkillTriggerRate = {
			s_format("%.2f ^8(%ss per second)", eventRate, config.eventName),
			s_format("/ %d ^8(%ss to reach %.0f maximum Energy)", events, config.eventName, maxEnergy),
			s_format("= %.2f ^8per second", eventRate / events),
		}
		if output.SkillTriggerRate < eventRate / events then
			t_insert(breakdown.SkillTriggerRate, s_format("capped at %.2f ^8(trigger rate cap)", triggerRateCap))
		end
	end
end

---@param env Env
---@param actor Actor?
function calcs.triggers(env, actor)
	if not actor then
		return
	end
	-- Only Energy based meta gems are handled here. Other triggers such as Blasphemy keep their own flags
	local triggeredBy = actor.mainSkill.triggeredBy
	if not (triggeredBy and actor.mainSkill.skillData.energyPerCastTimeMs) or getSkillFlags(env, actor.mainSkill).disable then
		return
	end
	local config = metaGemConfigs[triggeredBy.grantedEffect.id]
	local metaSkill = findMetaGemSkill(env, actor)
	if config and metaSkill then
		metaGemTriggerHandler(env, actor, metaSkill, config)
	else
		local triggerName = metaSkill and metaSkill.activeEffect.grantedEffect.name or triggeredBy.grantedEffect.name
		assumeSelfCast(actor.mainSkill, s_format("%s is not supported yet", triggerName))
	end
end
