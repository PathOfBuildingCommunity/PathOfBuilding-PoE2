-- Path of Building
--
-- Module: Mod Store
-- Base class for modifier storage classes
--
local ipairs = ipairs
local pairs = pairs
local t_insert = table.insert
local m_abs = math.abs
local m_floor = math.floor
local m_ceil = math.ceil
local round = round
local m_min = math.min
local m_max = math.max
local m_modf = math.modf
local band = AND64 -- bit.band
local bor = OR64 -- bit.bor

local modLib = modLib
local mod_createMod = modLib.createMod

-- Magic tables for caching multiplier/condition modifier names
local multiplierName = setmetatable({ }, { __index = function(t, var)
	t[var] = "Multiplier:"..var
	return t[var]
end })
local conditionName = setmetatable({ }, { __index = function(t, var)
	t[var] = "Condition:"..var
	return t[var]
end })

---@alias NumericValue number|table

---@class TabulatedMod
---@field value any
---@field mod Mod

---@class ModStore
---@field ScaleAddMod fun(self: ModStore, mod: Mod, scale: number, roundToNearest?: boolean)
---@field CopyList fun(self: ModStore, modList: Mod[])
---@field ScaleAddList fun(self: ModStore, modList: Mod[], scale: number, roundToNearest?: boolean)
---@field NewMod fun(self: ModStore, modName: string, modType: NumericModTypes|"FLAG"|"LIST", modVal?: any, sourceOrTag?: string|number|ModTag, flagsOrModTag?: number|ModTag, keywordFlagsOrModTag?: number|ModTag, ...: ModTag)
---@field ReplaceMod fun(self: ModStore, modName: string, modType: NumericModTypes|"FLAG"|"LIST", modVal?: any, sourceOrTag?: string|number|ModTag, flagsOrModTag?: number|ModTag, keywordFlagsOrModTag?: number|ModTag, ...: ModTag)
---@field ConvertMod fun(self: ModStore, oldName: string, modName: string, modType: NumericModTypes|"FLAG"|"LIST", modVal?: any, sourceOrTag?: string|number|ModTag, flagsOrModTag?: number|ModTag, keywordFlagsOrModTag?: number|ModTag, ...: ModTag)
---@field Combine fun(self: ModStore, modType: NumericModTypes|"FLAG"|"LIST", cfg: ModCfg?, ...: string): any
---@field Sum fun(self: ModStore, modType: NumericModTypes, cfg: ModCfg?, ...: string): number
---@field SumPositiveValues fun(self: ModStore, modType: NumericModTypes, cfg: ModCfg?, modName: string, ...: string): number
---@field SumNegativeValues fun(self: ModStore, modType: NumericModTypes, cfg: ModCfg?, modName: string, ...: string): number
---@field More fun(self: ModStore, cfg: ModCfg?, ...: string): number
---@field Flag fun(self: ModStore, cfg: ModCfg?, ...: string): boolean?
---@field Override fun(self: ModStore, cfg: ModCfg?, ...: string): any
---@field List fun(self: ModStore, cfg: ModCfg?, ...: string): any[]
---@field Tabulate fun(self: ModStore, modType: NumericModTypes|"FLAG"|"LIST"|nil, cfg: ModCfg?, ...: string): TabulatedMod[]
---@field Max fun(self: ModStore, cfg: ModCfg?, ...: string): number?
---@field HasMod fun(self: ModStore, modType: NumericModTypes|"FLAG"|"LIST", cfg: ModCfg?, ...: string): boolean
---@field GetCondition fun(self: ModStore, var: string, cfg?: ModCfg, noMod?: boolean): boolean
---@field GetMultiplier fun(self: ModStore, var: string, cfg?: ModCfg, noMod?: boolean): number
---@field GetStat fun(self: ModStore, stat: string, cfg?: ModCfg): number
---@field EvalMod fun(self: ModStore, mod: Mod, cfg?: ModCfg, globalLimits?: table): any
local ModStoreClass = newClass("ModStore")

function ModStoreClass:ModStore(parent)
	self.parent = parent
	self.actor = parent and parent.actor or { }
	self.multipliers = { }
	self.conditions = { }
	return self
end

-- roundToNearest is reserved for effects that the game rounds instead of truncates.
function ModStoreClass:ScaleAddMod(mod, scale, roundToNearest)
	local unscalable = false
	for _, effects in ipairs(mod) do
		if effects.unscalable then
			unscalable = true
			break
		end
	end
	if scale == 1 or unscalable then
		self:AddMod(mod)
	else
		local scaledMod = copyTable(mod)
		local subMod = scaledMod
		if type(scaledMod.value) == "table" then
			if scaledMod.value.mod then
				subMod = scaledMod.value.mod
			elseif scaledMod.value.keyOfScaledMod then
				if scaledMod.value.key == "level" then -- +Levels can't get scaled with decimals
					scaledMod.value[scaledMod.value.keyOfScaledMod] = m_floor(scaledMod.value[scaledMod.value.keyOfScaledMod] * scale)
				else
					scaledMod.value[scaledMod.value.keyOfScaledMod] = round(scaledMod.value[scaledMod.value.keyOfScaledMod] * scale, 2)
				end
			end
		end
		if type(subMod.value) == "number" then
			local precision = ((data.highPrecisionMods[subMod.name] and data.highPrecisionMods[subMod.name][subMod.type])) or ((m_floor(subMod.value) ~= subMod.value) and data.defaultHighPrecision) or nil
			if precision then
				local power = 10 ^ precision
				subMod.value = m_floor(subMod.value * scale * power) / power
			elseif roundToNearest then
				subMod.value = roundSymmetric(subMod.value * scale)
			else
				subMod.value = m_modf(round(subMod.value * scale, 2))
			end
		end
		self:AddMod(scaledMod)
	end
end

function ModStoreClass:CopyList(modList)
	for i = 1, #modList do
		self:AddMod(copyTable(modList[i]))
	end
end

function ModStoreClass:ScaleAddList(modList, scale, roundToNearest)
	if scale == 1 then
		self:AddList(modList)
	else
		for i = 1, #modList do
			self:ScaleAddMod(modList[i], scale, roundToNearest)
		end
	end
end

--- Creates a new mod and adds it to this store.
---@overload fun(self: ModStore, modName: string, modType: NumericModTypes, modVal?: number, sourceOrModTag?: string|number|ModTag, flagsOrModTag?: number|ModTag, keywordFlagsOrModTag?: number|ModTag, ...: ModTag)
---@overload fun(self: ModStore, modName: string, modType: "FLAG", modVal: boolean|number, sourceOrModTag?: string|number|ModTag, flagsOrModTag?: number|ModTag, keywordFlagsOrModTag?: number|ModTag, ...: ModTag)
---@overload fun(self: ModStore, modName: string, modType: "LIST", modVal: any, sourceOrModTag?: string|number|ModTag, flagsOrModTag?: number|ModTag, keywordFlagsOrModTag?: number|ModTag, ...: ModTag)
---@param ... any @Parameters to be passed along to the modLib.createMod function
function ModStoreClass:NewMod(...)
	self:AddMod(mod_createMod(...))
end

---ReplaceMod
---  Replaces an existing matching mod with a new mod.
---  A mod is considered the same if the name, type, flags, keywordFlags, and source exactly match.
---  If no matching mod exists, the mod is added instead.
---Notes:
---    See calls to ModStoreClass:NewMod for additional parameter examples.
---    1 (string): name
---    2 (string): type
---    3 (number): value
---    4 (string): source
---    5+ (optional, varies): additional options
---@param ... any @Parameters to be passed along to the modLib.createMod function
function ModStoreClass:ReplaceMod(...)
	local mod = mod_createMod(...)
	if not self:ReplaceModInternal(mod) then
		self:AddMod(mod)
	end
end

---ConvertMod
---  Converts an existing mod to a new name, replacing it in the store.
---  Finds a mod matching oldName with the same type, flags, keywordFlags, and source as the new mod.
---  If no matching mod exists, the new mod is added instead.
---@param oldName string @The name of the existing mod to convert
---@param ... any @Parameters to be passed along to the modLib.createMod function (new name, type, value, source, ...)
function ModStoreClass:ConvertMod(oldName, ...)
	local mod = mod_createMod(...)
	if not self:ConvertModInternal(oldName, mod) then
		self:AddMod(mod)
	end
end

---@param modType NumericModTypes|"FLAG"|"LIST"
---@param cfg? ModCfg
---@param ... string
---@return any
function ModStoreClass:Combine(modType, cfg, ...)
	if modType == "MORE" then
		return self:More(cfg, ...)
	elseif modType == "FLAG" then
		return self:Flag(cfg, ...)
	elseif modType == "OVERRIDE" then
		return self:Override(cfg, ...)
	elseif modType == "LIST" then
		return self:List(cfg, ...)
	elseif modType == "MAX" then
		return self:Max(cfg, ...)
	else
		return self:Sum(modType, cfg, ...)
	end
end

---@param modType NumericModTypes
---@param cfg? ModCfg
---@param ... string  Mod names to query. Maximum 8 names due to JIT performance concerns.
---@return number
function ModStoreClass:Sum(modType, cfg, ...)
	local flags, keywordFlags = 0, 0
	local source
	if cfg then
		flags = cfg.flags or 0
		keywordFlags = cfg.keywordFlags or 0
		source = cfg.source
	end
	local n = select('#', ...)
	if n == 1 then
		local arg = ...
		return self:SumInternal(self, modType, cfg, flags, keywordFlags, source, arg)
	end
	local n1, n2, n3, n4, n5, n6, n7, n8 = ...
	return self:SumInternalMulti(self, modType, cfg, flags, keywordFlags, source, n, n1, n2, n3, n4, n5, n6, n7, n8)
end


--- Returns the value of all positive modifiers to a mod added together, ignoring any negative modifiers.
--- Works by creating a table using Tabulate and then filtering for positive values.
---
---@param modType NumericModTypes The modifier type, such as "INC" or "MORE"
---@param cfg? ModCfg
---@param modName string
---@param ... string
---@return number
function ModStoreClass:SumPositiveValues(modType, cfg, modName, ...)
	local total = 0
	local modTable = self:Tabulate(modType, cfg, modName)
	for i = 1, #modTable do
		if modTable[i].value > 0 then
			total = total + modTable[i].value
		end
	end
	return total
end

--- Returns the value of all negative modifiers to a mod added together, ignoring any negative modifiers.
--- Works by creating a table using Tabulate and then filtering for negative values.
---
---@param modType NumericModTypes The modifier type, such as "INC" or "MORE"
---@param cfg? ModCfg
---@param modName string
---@param ... string
---@return number
function ModStoreClass:SumNegativeValues(modType, cfg, modName, ...)
	local total = 0
	local modTable = self:Tabulate(modType, cfg, modName)
	for i = 1, #modTable do
		if modTable[i].value < 0 then
			total = total + modTable[i].value
		end
	end
	return total
end

---@param cfg? ModCfg
---@param ... string  Mod names to query. Maximum 8 names due to JIT performance concerns.
---@return number
function ModStoreClass:More(cfg, ...)
	local flags, keywordFlags = 0, 0
	local source
	if cfg then
		flags = cfg.flags or 0
		keywordFlags = cfg.keywordFlags or 0
		source = cfg.source
	end
	local n = select('#', ...)
	if n == 1 then
		local arg = ...
		return self:MoreInternal(self, cfg, flags, keywordFlags, source, arg)
	end
	local n1, n2, n3, n4, n5, n6, n7, n8 = ...
	return self:MoreInternalMulti(self, cfg, flags, keywordFlags, source, n, n1, n2, n3, n4, n5, n6, n7, n8)
end

---@param cfg? ModCfg
---@param ... string
---@return boolean?
function ModStoreClass:Flag(cfg, ...)
	local flags, keywordFlags = 0, 0
	local source
	if cfg then
		flags = cfg.flags or 0
		keywordFlags = cfg.keywordFlags or 0
		source = cfg.source
	end
	local n = select('#', ...)
	if n == 1 then
		local arg = ...
		return self:FlagInternal(self, cfg, flags, keywordFlags, source, arg)
	end
	local n1, n2, n3, n4, n5, n6, n7, n8 = ...
	return self:FlagInternalMulti(self, cfg, flags, keywordFlags, source, n, n1, n2, n3, n4, n5, n6, n7, n8)
end

---@param cfg? ModCfg
---@param ... string
---@return any
function ModStoreClass:Override(cfg, ...)
	local flags, keywordFlags = 0, 0
	local source
	if cfg then
		flags = cfg.flags or 0
		keywordFlags = cfg.keywordFlags or 0
		source = cfg.source
	end
	local n = select('#', ...)
	if n == 1 then
		local arg = ...
		return self:OverrideInternal(self, cfg, flags, keywordFlags, source, arg)
	end
	local n1, n2, n3, n4, n5, n6, n7, n8 = ...
	return self:OverrideInternalMulti(self, cfg, flags, keywordFlags, source, n, n1, n2, n3, n4, n5, n6, n7, n8)
end

---@param cfg? ModCfg
---@param ... string
---@return any[]
function ModStoreClass:List(cfg, ...)
	local flags, keywordFlags = 0, 0
	local source
	if cfg then
		flags = cfg.flags or 0
		keywordFlags = cfg.keywordFlags or 0
		source = cfg.source
	end
	local result = { }
	local n = select('#', ...)
	if n == 1 then
		local arg = ...
		self:ListInternal(self, result, cfg, flags, keywordFlags, source, arg)
	else
		local n1, n2, n3, n4, n5, n6, n7, n8 = ...
		self:ListInternalMulti(self, result, cfg, flags, keywordFlags, source, n, n1, n2, n3, n4, n5, n6, n7, n8)
	end
	return result
end

---@param modType? NumericModTypes|"FLAG"|"LIST"
---@param cfg? ModCfg
---@param ... string  Mod names to query. Maximum 8 names due to JIT performance concerns.
---@return TabulatedMod[]
function ModStoreClass:Tabulate(modType, cfg, ...)
	local flags, keywordFlags = 0, 0
	local source
	if cfg then
		flags = cfg.flags or 0
		keywordFlags = cfg.keywordFlags or 0
		source = cfg.source
	end
	---@type TabulatedMod[]
	local result = { }
	local n = select('#', ...)
	if n == 1 then
		local arg = ...
		self:TabulateInternal(self, result, modType, cfg, flags, keywordFlags, source, arg)
	else
		local n1, n2, n3, n4, n5, n6, n7, n8 = ...
		self:TabulateInternalMulti(self, result, modType, cfg, flags, keywordFlags, source, n, n1, n2, n3, n4, n5, n6, n7, n8)
	end
	return result
end

---@param cfg? ModCfg
---@param ... string
---@return number?
function ModStoreClass:Max(cfg, ...)
	local max
	for _, value in ipairs(self:Tabulate("MAX", cfg, ...)) do
		local val = self:EvalMod(value.mod, cfg)
		if val > (max or 0) then
			max = val
		end	
	end
	return max		
end

---HasMod
---  Checks if a mod exists with the given properties.
---  Useful for determining if the other aggregate functions will find
---  anything to aggregate.
---@param modType NumericModTypes|"FLAG"|"LIST" Mod type to match
---@param cfg? ModCfg Configuration to use - contains flags, keywordFlags, and source to match
---@param ... string Mod names to query. Maximum 8 names due to JIT performance concerns.
---@return boolean result True if the mod is found, false otherwise.
function ModStoreClass:HasMod(modType, cfg, ...)
	local flags, keywordFlags = 0, 0
	local source
	if cfg then
		flags = cfg.flags or 0
		keywordFlags = cfg.keywordFlags or 0
		source = cfg.source
	end
	local n = select('#', ...)
	if n == 1 then
		local arg = ...
		return self:HasModInternal(modType, flags, keywordFlags, source, arg)
	end
	local n1, n2, n3, n4, n5, n6, n7, n8 = ...
	return self:HasModInternalMulti(modType, flags, keywordFlags, source, n, n1, n2, n3, n4, n5, n6, n7, n8)
end

---@param var string
---@param cfg? ModCfg
---@param noMod? boolean
---@return boolean
function ModStoreClass:GetCondition(var, cfg, noMod)
	const overrideCond = cfg?.overrideCond?.[var]
	if overrideCond ~= nil then
		return overrideCond
	else
		return self.conditions[var] or (self.parent?.:GetCondition(var, cfg, true)) or (not noMod and self:Flag(cfg, conditionName[var]))
	end
end

---@param var string
---@param cfg? ModCfg
---@param noMod? boolean
---@return number
function ModStoreClass:GetMultiplier(var, cfg, noMod)
	return (not noMod and self:Override(cfg, multiplierName[var])) or (self.multipliers[var] or 0) + (self.parent?.:GetMultiplier(var, cfg, true) or 0) + (not noMod and self:Sum("BASE", cfg, multiplierName[var]) or 0)
end

---@param stat string
---@param cfg? ModCfg
---@return number
function ModStoreClass:GetStat(stat, cfg)
	const output = self.actor.output
	if stat == "ManaReservedPercent" then
		local reservedPercentMana = 0
		-- Check if mana is 0 (i.e. from Blood Magic) to avoid division by 0.
		const totalMana = output["Mana"]
		if totalMana == 0 then return 0
		else
			for _, activeSkill in ipairs(self.actor.activeSkillList) do
				-- currently only checks main statSet for skill flags. rework if required
				if (activeSkill.skillTypes[SkillType.Aura] and not activeSkill.activeEffect.statSet.skillFlags.disable and activeSkill.buffList?.[1]?.name == cfg.skillName) then
					const manaBase = activeSkill.skillData["ManaReservedBase"] or 0
					reservedPercentMana = m_floor(manaBase / totalMana * 100)
					break
				end
			end
			return m_min(reservedPercentMana, 100) --Don't let people get more than 100% reservation for aura effect.
		end
	end
	if stat == "LifeReservedPercent" then
		local reservedPercentLife = 0
		const totalLife = output["Life"]
		if totalLife == 0 then return 0
		else
			for _, activeSkill in ipairs(self.actor.activeSkillList) do
				if (activeSkill.skillTypes[SkillType.HasReservation] and not activeSkill.skillFlags.disable and activeSkill.buffList?.[1] and cfg and (isNameInBuffList(activeSkill.buffList, cfg.skillName) or isNameInBuffList(activeSkill.buffList, cfg.summonSkillName)) ) then
					const lifeBase = activeSkill.skillData["LifeReservedBase"] or 0
					reservedPercentLife = m_floor(lifeBase / totalLife * 100)
					break
				end
			end
			return m_min(reservedPercentLife, 100) --Don't let people get more than 100% reservation for aura effect.
		end
	end
	-- if ReservationEfficiency is -100, ManaUnreserved is nan which breaks everything if Arcane Cloak is enabled
	if stat == "ManaUnreserved" and output[stat] ~= output[stat] then
		-- 0% reserved = total mana
		return output["Mana"]
	elseif stat == "ManaUnreserved" and not output[stat] == nil and output[stat] < 0 then
		-- This reverse engineers how much mana is unreserved before efficiency for accurate Arcane Cloak calcs
		local reservedPercentBeforeEfficiency = (m_abs(output["ManaUnreservedPercent"]) + 100) * ((100 + self.actor["ManaEfficiency"]) / 100)
		return output["Mana"] * (m_ceil(reservedPercentBeforeEfficiency) / 100);
	else
		return output?.[stat] or cfg?.skillStats?.[stat] or 0
	end
end

const GetCondition = ModStoreClass.GetCondition
const GetMultiplier = ModStoreClass.GetMultiplier
const GetStat = ModStoreClass.GetStat

---Find the ModStore instance for a given actor type, starting from self.
---@param self ModStore @The ModStore instance
---@param targetActor string? @The actor type to resolve. If nil, self is returned.
---@return ModStore? @The resolved ModStore instance for the target actor, or nil.
local function resolveActor(self, targetActor)
	if not targetActor then
		return self
	end
	const a = self.actor
	local actor
	if targetActor == "player" then
		actor = a.player ?? a.parent?.player ?? a.enemy?.player
	else
		actor = a[targetActor]
	end
	return actor?.modDB
end

---Calculate the modified value based on the provided value, multiplier, base, and optional limits.
---@param value NumericValue @The value to be modified
---@param mult number @Multiplier to apply to the value
---@param base number? @Additive base value
---@param limitMin number? @The minimum limit
---@param limitMax number? @The maximum limit
---@param ceil boolean? @Whether to ceil the result
---@return NumericValue @The modified value
local function applyValue(value, mult, base, limitMin, limitMax, ceil)
	local v = value
	const isTable = type(value) == "table"
	if isTable then
		value = copyTable(value)
		v = value.mod?.value ?? value.value
	end

	v = v * mult + (base ?? 0)

	if ceil then
		v = m_ceil(v)
	end

	if limitMax then
		v = m_min(v, limitMax)
	end
	if limitMin then
		v = m_max(v, limitMin)
	end

	if isTable then
		if value.mod then
			value.mod.value = v
		else
			value.value = v
		end
	else
		value = v
	end
	return value
end

---Evaluate a Multiplier tag.
---@param self ModStore @The ModStore instance
---@param value NumericValue @The value to be modified by the tag
---@param tag MultiplierModTag @The tag containing the modifying information
---@param cfg ModCfg? @Configuration table, may be nil
---@return NumericValue? @The modified value after applying the tag, or nil if the tag conditions are not met
local function evalMultiplier(self, value, tag, cfg)
	const target = resolveActor(self, tag.actor)
	if not target then return end

	-- Allow limiting a self multiplier on a parent multiplier (eg. Agony Crawler on player virulence)
	-- This explicit target is necessary because even though the GetMultiplier method does call self.parent.GetMultiplier, it does so with noMod = true,
	-- disabling the summation (3rd part): (not noMod and self:Sum("BASE", cfg, multiplierName[var]) or 0)
	const limitTarget = resolveActor(self, tag.limitActor)
	if not limitTarget then return end

	local base = 0
	if tag.varList then
		for _, var in ipairs(tag.varList) do
			base += GetMultiplier(target, var, cfg)
		end
	elseif tag.var then
		base = GetMultiplier(target, tag.var, cfg)
	else
		error("Multiplier tag missing both var and varList")
	end
	if tag.divVar then
		tag.div = GetMultiplier(self, tag.divVar, cfg)
	end
	local mult = m_floor(base / (tag.div ?? 1) + 0.0001)
	local limitTotal
	local limitNegTotal
	const limit = tag.limit ?? (tag.limitVar and GetMultiplier(limitTarget, tag.limitVar, cfg))
	if limit then
		if tag.limitTotal then
			limitTotal = limit
		elseif tag.limitNegTotal then
			limitNegTotal = limit
		else
			mult = m_min(mult, limit)
		end
	end
	if tag.invert and mult ~= 0 then
		mult = 1 / mult
	end
	return applyValue(value, mult, tag.base, limitNegTotal, limitTotal)
end

---Evaluate a MultiplierThreshold tag.
---@param self ModStore @The ModStore instance
---@param value ModValue @The value to be modified by the tag
---@param tag MultiplierThresholdModTag @The tag containing the modifying information
---@param cfg ModCfg? @Configuration table, may be nil
---@return ModValue? @The modified value after applying the tag, or nil if the tag conditions are not met
local function evalMultiplierThreshold(self, value, tag, cfg)
	const target = resolveActor(self, tag.actor)
	if not target then return end
	const thresholdTarget = resolveActor(self, tag.thresholdActor)
	if not thresholdTarget then return end
	local mult = 0
	if tag.varList then
		for _, var in ipairs(tag.varList) do
			mult += GetMultiplier(target, var, cfg)
		end
	elseif tag.var then
		mult = GetMultiplier(target, tag.var, cfg)
	else
		error("MultiplierThreshold tag missing both var and varList")
	end
	const threshold = tag.threshold ?? (tag.thresholdVar and GetMultiplier(thresholdTarget, tag.thresholdVar, cfg))
	if (tag.upper and mult > threshold) or (tag.equals and mult ~= threshold) or (not tag.upper and mult < threshold) then
		return
	end
	return value
end

---Evaluate a PerStat tag.
---@param self ModStore @The ModStore instance
---@param value NumericValue @The value to be modified by the tag
---@param tag PerStatModTag @The tag containing the modifying information
---@param cfg ModCfg? @Configuration table, may be nil
---@return NumericValue @The modified value after applying the tag
local function evalPerStat(self, value, tag, cfg)
	local base
	const target = resolveActor(self, tag.actor) ?? self
	if tag.statList then
		base = 0
		for _, stat in ipairs(tag.statList) do
			base += GetStat(target, stat, cfg)
		end
	elseif tag.stat then
		base = GetStat(target, tag.stat, cfg)
	else
		error("PerStat tag missing both stat and statList")
	end
	if tag.divVar then
		tag.div = GetMultiplier(self, tag.divVar, cfg)
	end
	local mult = m_floor(base / (tag.div ?? 1) + 0.0001)
	local limitTotal
	const limit = tag.limit ?? (tag.limitVar and GetMultiplier(self, tag.limitVar, cfg))
	if limit then
		if tag.limitTotal then
			limitTotal = limit
		else
			mult = m_min(mult, limit)
		end
	end
	return applyValue(value, mult, tag.base, nil, limitTotal)
end

---Evaluate a PercentStat tag.
---@param self ModStore @The ModStore instance
---@param value NumericValue @The value to be modified by the tag
---@param tag PercentStatModTag @The tag containing the modifying information
---@param cfg ModCfg? @Configuration table, may be nil
---@return NumericValue @The modified value after applying the tag
local function evalPercentStat(self, value, tag, cfg)
	local base
	const target = resolveActor(self, tag.actor) ?? self
	if tag.statList then
		base = 0
		for _, stat in ipairs(tag.statList) do
			base += GetStat(target, stat, cfg)
		end
	elseif tag.stat then
		base = GetStat(target, tag.stat, cfg)
	else
		error("PercentStat tag missing both stat and statList")
	end
	const percent = tag.percent ?? (tag.percentVar and GetMultiplier(self, tag.percentVar, cfg))
	local mult = base * (percent and percent / 100 or 1)
	if tag.floor then
		mult = m_floor(mult)
	end
	local limitTotal
	const limit = tag.limit ?? (tag.limitVar and GetMultiplier(self, tag.limitVar, cfg))
	if limit then
		if tag.limitTotal then
			limitTotal = limit
		else
			mult = m_min(mult, limit)
		end 
	end
	return applyValue(value, mult, tag.base, nil, limitTotal, true)
end

---Evaluate a StatThreshold tag.
---@param self ModStore @The ModStore instance
---@param value ModValue @The value to be modified by the tag
---@param tag StatThresholdModTag @The tag containing the modifying information
---@param cfg ModCfg? @Configuration table, may be nil
---@return ModValue? @The modified value after applying the tag, or nil if the tag conditions are not met
local function evalStatThreshold(self, value, tag, cfg)
	local stat
	if tag.statList then
		stat = 0
		for _, s in ipairs(tag.statList) do
			stat += GetStat(self, s, cfg)
		end
	elseif tag.stat then
		stat = GetStat(self, tag.stat, cfg)
	else
		error("StatThreshold tag missing both stat and statList")
	end
	local threshold = tag.threshold ?? (tag.thresholdStat and GetStat(self, tag.thresholdStat, cfg))
	const thresholdPercent = tag.thresholdPercent ?? (tag.thresholdPercentVar and GetMultiplier(self, tag.thresholdPercentVar, cfg))
	if threshold and thresholdPercent then
		threshold *= thresholdPercent / 100
	end
	if (tag.upper and stat > threshold) or (not tag.upper and stat < threshold) then
		return
	end
	return value
end

---Evaluate a DistanceRamp tag.
---@param value number @The value to be modified by the tag
---@param tag DistanceRampModTag @The tag containing the modifying information
---@param cfg ModCfg? @Configuration table, may be nil
---@return number? @The modified value after applying the tag, or nil if the tag conditions are not met
local function evalDistanceRamp(_, value, tag, cfg)
	if not cfg or not cfg.skillDist then
		return
	end
	if cfg.skillDist <= tag.ramp[1][1] then
		value *= tag.ramp[1][2]
	elseif cfg.skillDist >= tag.ramp[#tag.ramp][1] then
		value *= tag.ramp[#tag.ramp][2]
	else
		for i, dat in ipairs(tag.ramp) do
			const next = tag.ramp[i+1]
			if cfg.skillDist <= next[1] then
				value *= (dat[2] + (next[2] - dat[2]) * (cfg.skillDist - dat[1]) / (next[1] - dat[1]))
				break
			end
		end
	end
	return value
end

---Evaluate a Limit tag.
---@param self ModStore @The ModStore instance
---@param value number @The value to be modified by the tag
---@param tag LimitModTag @The tag containing the modifying information
---@param cfg ModCfg? @Configuration table, may be nil
---@return number @The modified value after applying the tag
local function evalLimit(self, value, tag, cfg)
	const limit = tag.limit ?? (tag.limitVar and GetMultiplier(self, tag.limitVar, cfg))
	if limit then
		return tag.neg and m_max(value, -limit) or m_min(value, limit)
	else
		error("Limit tag missing both limit and limitVar")
	end
end

---Evaluate a Condition tag.
---@param self ModStore @The ModStore instance
---@param value ModValue @The value to be modified by the tag
---@param tag ConditionModTag @The tag containing the modifying information
---@param cfg ModCfg? @Configuration table, may be nil
---@return ModValue? @The original value or nil if the tag conditions are not met
local function evalCondition(self, value, tag, cfg)
	local match = false
	const allOneH = ((self.actor.weaponData1?.countsAsAll1H) and self.actor.weaponData1) or ((self.actor.weaponData2?.countsAsAll1H) and self.actor.weaponData2)
	if tag.varList then
		for _, var in ipairs(tag.varList) do
			if tag.neg and allOneH and allOneH["Added"..var] ~= nil then
				-- Varunastra adds all using weapon conditions and that causes this condition to fail when it shouldn't
				-- if the condition was added by Varunastra then ignore, otherwise return as the tag condition is not satisfied
				if not allOneH["Added"..var] then
					return
				end
			elseif GetCondition(self, var, cfg) or (cfg?.skillCond?.[var]) then
				match = true
				break
			end
		end
	elseif tag.var then
		if tag.neg and allOneH and allOneH["Added"..tag.var] ~= nil then
			if not allOneH["Added"..tag.var] then
				return
			end
		else
			match = GetCondition(self, tag.var, cfg) or (cfg?.skillCond?.[tag.var])
		end
	else
		error("Condition tag missing both var and varList")
	end
	if tag.neg then
		match = not match
	end
	if not match then
		return
	end
	return value
end

---Evaluate an ActorCondition tag.
---@param self ModStore @The ModStore instance
---@param value ModValue @The value to be modified by the tag
---@param tag ActorConditionModTag @The tag containing the modifying information
---@param cfg ModCfg? @Configuration table, may be nil
---@return ModValue? @The original value or nil if the tag conditions are not met
local function evalActorCondition(self, value, tag, cfg)
	local match = false
	const target = resolveActor(self, tag.actor) ?? self
	if tag.varList then
		for _, var in ipairs(tag.varList) do
			if GetCondition(target, var, cfg) then
				match = true
				break
			end
		end
	elseif tag.var then
		match = GetCondition(target, tag.var, cfg)
	elseif tag.actor and cfg and tag.actor == cfg.actor then
		match = true
	end
	if tag.neg then
		match = not match
	end
	if not match then
		return
	end
	return value
end

---Evaluate an ItemCondition tag.
---@param self ModStore @The ModStore instance
---@param value ModValue @The value to be modified by the tag
---@param tag ItemConditionModTag @The tag containing the modifying information
---@param cfg ModCfg? @Configuration table, may be nil
---@return ModValue? @The original value or nil if the tag conditions are not met
local function evalItemCondition(self, value, tag, cfg)
	const neg = tag.neg ?? false
	const itemList = self.actor?.itemList ?? {}
	const itemSlot = tag.itemSlot?.:lower():gsub("(%l)(%w*)", |a, b| -> string.upper(a)..b):gsub('^%s*(.-)%s*$', '%1')
	local items = tag.allSlots and itemList or {}
	if not tag.allSlots and tag.bothSlots and itemSlot then
		local itemSlot1 = itemList[itemSlot .. " 1"]
		local itemSlot2 = itemList[itemSlot .. " 2"]
		if itemSlot1?.name:match("Kalandra's Touch") then itemSlot1 = itemSlot2 end
		if itemSlot2?.name:match("Kalandra's Touch") then itemSlot2 = itemSlot1 end
		if itemSlot1 and itemSlot2 then
			items = {[itemSlot .. " 1"] = itemSlot1, [itemSlot .. " 2"] = itemSlot2}
		end
	elseif not tag.allSlots and itemSlot then
		local item = itemList[itemSlot] ?? cfg?.item
		if item?.name:match("Kalandra's Touch") then
			item = itemList[itemSlot:gsub("%d$", {["1"] = "2", ["2"] = "1"})]
		end
		items = {[itemSlot] = item or cfg?.item}
	end
	if tag.searchCond then
		const searchCond = tag.searchCond:lower()
		for slot, item in pairs(items) do
			if item and ((not tag.allSlots or item.type ~= "Jewel") and slot ~= itemSlot or not tag.excludeSelf) then
				if item:FindModifierSubstring(searchCond, slot:lower()) == neg then return end
			end
		end
	end
	if tag.rarityCond then
		for _, item in pairs(items) do
			if item and (item.rarity == tag.rarityCond) == neg then return end
		end
	end
	if tag.corruptedCond then
		for _, item in pairs(items) do
			if item and (item.corrupted == tag.corruptedCond) == neg then return end
		end
	end
	const hasItems = next(items) ~= nil
	if not hasItems and not neg then
		return
	end
	return value
end

---Evaluate a SocketedIn tag.
---@param value ModValue @The value to be modified by the tag
---@param tag SocketedInModTag @The tag containing the modifying information
---@param cfg ModCfg? @Configuration table, may be nil
---@return ModValue? @The original value or nil if the tag conditions are not met
local function evalSocketedIn(_, value, tag, cfg)
	if not cfg or (not tag.slotName and not tag.keyword and not tag.socketColor and not tag.slotType) then
		return
	end

	local match = {}
	if tag.slotType then
		match["slotType"] = true  -- implemented in CalcSetup.lua
	elseif tag.slotName then
		match["slotName"] = (tag.slotName == cfg.slotName) or false
	end
	if tag.keyword then
		match["keyword"] = (cfg.skillGem and calcLib.gemIsType(cfg.skillGem, tag.keyword)) or false
	elseif tag.socketColor and tag.sockets ~= "all" then -- the all socket tag inherently checks for the correct color
		match["socketColor"] = (tag.socketColor == cfg.socketColor) or false
	end
	if tag.sockets then
		const targetAtrColor = tag.socketColor == "R" and "strengthGems" or tag.socketColor == "G" and "dexterityGems" or tag.socketColor == "B" and "intelligenceGems"
		const count = cfg[targetAtrColor] or 0
		if tag.sockets == "all" then
			local total = (cfg.intelligenceGems or 0) + (cfg.dexterityGems or 0) + (cfg.strengthGems or 0)
			match["sockets"] = (total == count) and (total > 0) or false
		elseif type(tag.sockets) == "table" and cfg.socketNum then
			match["sockets"] = (isValueInArray(tag.sockets, cfg.socketNum)) or false
		elseif type(tag.sockets) == "number" then
			match["sockets"] = (count < tag.sockets) or false
		else
			return
		end
	end
	for _, v in pairs(match) do
		if (not tag.neg and not v) or (tag.neg and v) then
			return
		end
	end

	return value
end

---Evaluate a SkillName tag.
---@param value ModValue @The value to be modified by the tag
---@param tag SkillNameModTag @The tag containing the modifying information
---@param cfg ModCfg? @Configuration table, may be nil
---@return ModValue? @The original value or nil if the tag conditions are not met
local function evalSkillName(_, value, tag, cfg)
	local match = false
	if tag.includeTransfigured then
		const matchGameId = tag.summonSkill and (cfg?.summonSkillName and calcLib.getGameIdFromGemName(cfg.summonSkillName, true) or "") or (cfg?.skillName and calcLib.getGameIdFromGemName(cfg.skillName, true) or "")
		if tag.skillNameList then
			for _, name in ipairs(tag.skillNameList) do
				if name and matchGameId == calcLib.getGameIdFromGemName(name, true) then
					match = true
					break
				end
			end
		elseif tag.skillName then
			match = (tag.skillName and matchGameId == calcLib.getGameIdFromGemName(tag.skillName, true))
		else
			error("SkillName tag missing both skillName and skillNameList")
		end
	else
		const matchName = (tag.summonSkill and (cfg?.summonSkillName ?? "") or (cfg?.skillName ?? "")):lower()
		if tag.skillNameList then
			for _, name in ipairs(tag.skillNameList) do
				const nameLower = name:lower()
				if (tag.partialMatch and matchName:find(nameLower, 1, true)) or (not tag.partialMatch and nameLower == matchName) then
					match = true
					break
				end
			end
		elseif tag.skillName then
			match = (tag.partialMatch and matchName:find(tag.skillName:lower(), 1, true) ~= nil) or (tag.skillName:lower() == matchName)
		else
			error("SkillName tag missing both skillName and skillNameList")
		end
	end
	if tag.neg then
		match = not match
	end
	if not match then
		return
	end
	return value
end

---Evaluate a SkillId tag.
---@param value ModValue @The value to be modified by the tag
---@param tag SkillIdModTag @The tag containing the modifying information
---@param cfg ModCfg? @Configuration table, may be nil
---@return ModValue? @The original value or nil if the tag conditions are not met
local function evalSkillId(_, value, tag, cfg)
	local match = cfg?.skillGrantedEffect?.id == tag.skillId
	if tag.neg then
		match = not match
	end
	if not match then
		return
	end
	return value
end

---Evaluate a SkillPart tag.
---@param value ModValue @The value to be modified by the tag
---@param tag SkillPartModTag @The tag containing the modifying information
---@param cfg ModCfg? @Configuration table, may be nil
---@return ModValue? @The original value or nil if the tag conditions are not met
local function evalSkillPart(_, value, tag, cfg)
	local match = false
	if cfg?.skillPart then
		if tag.skillPartList then
			for _, part in ipairs(tag.skillPartList) do
				if part == cfg.skillPart then
					match = true
					break
				end
			end
		elseif tag.skillPart then
			match = (tag.skillPart == cfg.skillPart)
		else
			error("SkillPart tag missing both skillPart and skillPartList")
		end
	end
	if tag.neg then
		match = not match
	end
	if not match then
		return
	end
	return value
end

---Evaluate a SkillType tag.
---@param value ModValue @The value to be modified by the tag
---@param tag SkillTypeModTag @The tag containing the modifying information
---@param cfg ModCfg? @Configuration table, may be nil
---@return ModValue? @The original value or nil if the tag conditions are not met
local function evalSkillType(_, value, tag, cfg)
	local match = false
	const skillTypes = cfg?.skillTypes
	if skillTypes then
		if tag.skillTypeList then
			for _, type in ipairs(tag.skillTypeList) do
				if skillTypes[type] then
					match = true
					break
				end
			end
		elseif tag.skillType then
			match = skillTypes[tag.skillType]
		else
			error("SkillType tag missing both skillType and skillTypeList")
		end
	end
	if tag.neg then
		match = not match
	end
	if not match then
		return
	end
	return value
end

---Evaluate a GemTag tag.
---@param value ModValue @The value to be modified by the tag
---@param tag GemTagModTag @The tag containing the modifying information
---@param cfg ModCfg? @Configuration table, may be nil
---@return ModValue? @The original value or nil if the tag conditions are not met
local function evalGemTag(_, value, tag, cfg)
	local match = false
	const gemTags = cfg?.skillGem?.tags
	if gemTags then
		if tag.gemTagList then
			for _, gemTag in ipairs(tag.gemTagList) do
				if gemTags[gemTag:lower()] then
					match = true
					break
				end
			end
		elseif tag.gemTag then
			match = gemTags[tag.gemTag:lower()]
		else
			error("GemTag tag missing both gemTag and gemTagList")
		end
	end
	if tag.neg then
		match = not match
	end
	if not match then
		return
	end
	return value
end

---Evaluate a BaseFlag tag.
---@param value ModValue @The value to be modified by the tag
---@param tag BaseFlagModTag @The tag containing the modifying information
---@param cfg ModCfg? @Configuration table, may be nil
---@return ModValue? @The original value or nil if the tag conditions are not met
local function evalBaseFlag(_, value, tag, cfg)
	local match = (cfg?.skillGem?.grantedEffect?.statSets?.[1] ?? cfg)?.baseFlags?.[tag.baseFlag]
	if tag.neg then
		match = not match
	end
	if not match then
		return
	end
	return value
end

---Evaluate a SlotName tag.
---@param value ModValue @The value to be modified by the tag
---@param tag SlotNameModTag @The tag containing the modifying information
---@param cfg ModCfg? @Configuration table, may be nil
---@return ModValue? @The original value or nil if the tag conditions are not met
local function evalSlotName(_, value, tag, cfg)
	local match = false
	const slotName = cfg?.slotName
	if slotName then
		if tag.slotNameList then
			for _, slot in ipairs(tag.slotNameList) do
				if slot == slotName then
					match = true
					break
				end
			end
		elseif tag.slotName then
			match = tag.slotName == slotName
		else
			error("SlotName tag missing both slotName and slotNameList")
		end
	end
	if tag.neg then
		match = not match
	end
	if not match then
		return
	end
	return value
end

---Evaluate a ModFlagOr tag.
---@param value ModValue @The value to be modified by the tag
---@param tag ModFlagOrModTag @The tag containing the modifying information
---@param cfg ModCfg? @Configuration table, may be nil
---@return ModValue? @The original value or nil if the tag conditions are not met
local function evalModFlagOr(_, value, tag, cfg)
	if not cfg?.flags then
		return
	end
	if band(cfg.flags, tag.modFlags) == 0 then
		return
	end
	return value
end

---Evaluate a KeywordFlagAnd tag.
---@param value ModValue @The value to be modified by the tag
---@param tag KeywordFlagAndModTag @The tag containing the modifying information
---@param cfg ModCfg? @Configuration table, may be nil
---@return ModValue? @The original value or nil if the tag conditions are not met
local function evalKeywordFlagAnd(_, value, tag, cfg)
	if not cfg?.keywordFlags then
		return
	end
	if band(cfg.keywordFlags, tag.keywordFlags) ~= tag.keywordFlags then
		return
	end
	return value
end

---Evaluate a MonsterTag tag.
---@param self ModStore @The ModStore instance
---@param value ModValue @The value to be modified by the tag
---@param tag MonsterTagModTag @The tag containing the modifying information
---@return ModValue? @The original value or nil if the tag conditions are not met
local function evalMonsterTag(self, value, tag, _)
	local match = false
	const monsterTags = self.actor?.minionData?.monsterTags
	if monsterTags then
		for _, tagList in ipairs(monsterTags) do
			const matchName = tagList:lower()
			if tag.monsterTagList then
				for _, name in ipairs(tag.monsterTagList) do
					if name:lower() == matchName then
						match = true
						break
					end
				end
			elseif tag.monsterTag then
				match = tag.monsterTag?.:lower() == matchName
			else
				error("MonsterTag tag missing both monsterTag and monsterTagList")
			end
			if match == true then
				break
			end
		end
	end
	if tag.neg then
		match = not match
	end
	if not match then
		return
	end
	return value
end

---@alias ModHandler fun(self: ModStore, value: ModValue, tag: ModTag, cfg: ModCfg?): ModValue?

---Dispatch table for tag handlers.
---@type table<string, ModHandler>
const handlers = {
	Multiplier = evalMultiplier,
	MultiplierThreshold = evalMultiplierThreshold,
	PerStat = evalPerStat,
	PercentStat = evalPercentStat,
	StatThreshold = evalStatThreshold,
	DistanceRamp = evalDistanceRamp,
	Limit = evalLimit,
	Condition = evalCondition,
	ActorCondition = evalActorCondition,
	ItemCondition = evalItemCondition,
	SocketedIn = evalSocketedIn,
	SkillName = evalSkillName,
	SkillId = evalSkillId,
	SkillPart = evalSkillPart,
	SkillType = evalSkillType,
	GemTag = evalGemTag,
	BaseFlag = evalBaseFlag,
	SlotName = evalSlotName,
	ModFlagOr = evalModFlagOr,
	KeywordFlagAnd = evalKeywordFlagAnd,
	MonsterTag = evalMonsterTag,
}

---Evaluate a mod with the given configuration, applying all tags to the mod value and returning the final result.
---@param mod Mod @The mod to evaluate
---@param cfg ModCfg? @The configuration to use for evaluation, may be nil.
---@param globalLimits table? @A table to track global limits. If provided, any tags with global limits will add to this table and have their value reduced if the global limit has already been reached.
---@return ModValue? @The final evaluated value of the mod, or nil if any tag conditions were not met.
function ModStoreClass:EvalMod(mod, cfg, globalLimits)
	local value = mod.value

	for i = 1, #mod do
		const tag = mod[i]
		---@type ModHandler?
		const fn = handlers[tag.type]

		if fn then
			value = fn(self, value, tag, cfg)
			if value == nil then return end
		end
	end

	if globalLimits then
		for i = 1, #mod do
			const tag = mod[i]
			const globalLimit = tag.globalLimit
			const globalLimitKey = tag.globalLimitKey
			if globalLimit and globalLimitKey then
				value = value or 0
				globalLimits[globalLimitKey] = globalLimits[globalLimitKey] or 0
				if globalLimits[globalLimitKey] + value > globalLimit then
					value = globalLimit - globalLimits[globalLimitKey]
				end
				globalLimits[globalLimitKey] += value
			end
		end
	end

	return value
end
