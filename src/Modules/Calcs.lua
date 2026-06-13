-- Path of Building
--
-- Module: Calcs
-- Manages the calculation system.
--
local pairs = pairs
local ipairs = ipairs
local t_insert = table.insert
local s_format = string.format
local m_min = math.min
local m_ceil = math.ceil

local calcs = { }
calcs.breakdownModule = "Modules/CalcBreakdown"
LoadModule("Modules/CalcSetup", calcs)
LoadModule("Modules/CalcPerform", calcs)
LoadModule("Modules/CalcActiveSkill", calcs)
LoadModule("Modules/CalcDefence", calcs)
LoadModule("Modules/CalcOffence", calcs)
LoadModule("Modules/CalcTriggers", calcs)
LoadModule("Modules/CalcMirages.lua", calcs)

-- Get the average value of a table -- note this is unused
function math.average(t)
	local sum = 0
	local count = 0
	for k,v in pairs(t) do
		if type(v) == 'number' then
			sum = sum + v
			count = count + 1
		end
	end
	return (sum / count)
end

-- Print various tables to the console
local function infoDump(env)
	if env.modDB.parent then
		env.modDB.parent:Print()
	end
	env.modDB:Print()
	if env.minion then
		ConPrintf("=== Minion Mod DB ===")
		env.minion.modDB:Print()
	end
	ConPrintf("=== Enemy Mod DB ===")
	env.enemyDB:Print()
	local mainSkill = env.minion and env.minion.mainSkill or env.player.mainSkill
	ConPrintf("=== Main Skill ===")
	for _, skillEffect in ipairs(mainSkill.effectList) do
		ConPrintf("%s %d/%d", skillEffect.grantedEffect.name, skillEffect.level, skillEffect.quality)
	end
	ConPrintf("=== Main Skill Flags ===")
	ConPrintf("Mod: %s", modLib.formatFlags(mainSkill.skillCfg.flags, ModFlag))
	ConPrintf("Keyword: %s", modLib.formatFlags(mainSkill.skillCfg.keywordFlags, KeywordFlag))
	ConPrintf("=== Main Skill Mods ===")
	mainSkill.skillModList.parent:Print()
	mainSkill.skillModList:Print()
	ConPrintf("=== Main Skill Data ===")
	prettyPrintTable(mainSkill.skillData)
	ConPrintf("== Aux Skills ==")
	for i, aux in ipairs(env.auxSkillList) do
		ConPrintf("Skill #%d:", i)
		for _, skillEffect in ipairs(aux.effectList) do
			ConPrintf("  %s %d/%d", skillEffect.grantedEffect.name, skillEffect.level, skillEffect.quality)
		end
	end
	ConPrintf("== Output Table ==")
	prettyPrintTable(env.player.output)
end

-- Generate a function for calculating the effect of some modification to the environment
local function getCalculator(build, fullInit, modFunc)
	-- Initialise environment
	local env, cachedPlayerDB, cachedEnemyDB, cachedMinionDB = calcs.initEnv(build, "CALCULATOR")

	-- Run base calculation pass
	calcs.perform(env)
	local fullDPS = calcs.calcFullDPS(build, "CALCULATOR", {}, { cachedPlayerDB = cachedPlayerDB, cachedEnemyDB = cachedEnemyDB, cachedMinionDB = cachedMinionDB, env = nil })
	env.player.output.SkillDPS = fullDPS.skills
	env.player.output.FullDPS = fullDPS.combinedDPS
	env.player.output.FullDotDPS = fullDPS.TotalDotDPS
	local baseOutput = env.player.output

	env.modDB.parent = cachedPlayerDB
	env.enemyDB.parent = cachedEnemyDB
	if cachedMinionDB then
		env.minion.modDB.parent = cachedMinionDB
	end

	return function(...)
		-- Remove mods added during the last pass
		wipeTable(env.modDB.mods)
		wipeTable(env.modDB.conditions)
		wipeTable(env.modDB.multipliers)
		wipeTable(env.enemyDB.mods)
		wipeTable(env.enemyDB.conditions)
		wipeTable(env.enemyDB.multipliers)

		-- Call function to make modifications to the environment
		modFunc(env, ...)
		
		-- Run calculation pass
		calcs.perform(env)
		fullDPS = calcs.calcFullDPS(build, "CALCULATOR", {}, { cachedPlayerDB = cachedPlayerDB, cachedEnemyDB = cachedEnemyDB, cachedMinionDB = cachedMinionDB, env = nil})
		env.player.output.SkillDPS = fullDPS.skills
		env.player.output.FullDPS = fullDPS.combinedDPS
		env.player.output.FullDotDPS = fullDPS.TotalDotDPS

		return env.player.output
	end, baseOutput	
end

-- Get fast calculator for adding tree node modifiers
function calcs.getNodeCalculator(build)
	return getCalculator(build, true, function(env, nodeList)
		-- Build and merge modifiers for these nodes
		env.modDB:AddList(calcs.buildModListForNodeList(env, nodeList))
	end)
end

-- Get calculator for other changes (adding/removing nodes, items, gems, etc)
function calcs.getMiscCalculator(build)
	-- Run base calculation pass
	local env, cachedPlayerDB, cachedEnemyDB, cachedMinionDB = calcs.initEnv(build, "CALCULATOR")
	calcs.perform(env)
	-- Capture per-skill Full DPS results and their input references during the base pass,
	-- so accelerated calls can reuse results for skills whose inputs are unchanged
	local fullDPSStore = { }
	local fullDPS = calcs.calcFullDPS(build, "CALCULATOR", {}, { cachedPlayerDB = cachedPlayerDB, cachedEnemyDB = cachedEnemyDB, cachedMinionDB = cachedMinionDB, env = nil, fullDPSCache = { store = fullDPSStore, capture = true }})
	local usedFullDPS = #fullDPS.skills > 0
	if usedFullDPS then
		env.player.output.SkillDPS = fullDPS.skills
		env.player.output.FullDPS = fullDPS.combinedDPS
		env.player.output.FullDotDPS = fullDPS.TotalDotDPS
	end
	local fastEnv
	return function(override, useFullDPS, fastCalcOptions)
		if fastCalcOptions then
			if fastCalcOptions.fullDPSOnly and usedFullDPS and useFullDPS then
				-- The caller only reads the FullDPS roll-up (e.g. sorting gems by Full DPS), and
				-- calcFullDPS builds its own environments, so the main-skill pass can be skipped entirely.
				-- The base-pass cache store lets skills with unchanged inputs reuse their captured results
				local fullDPS = calcs.calcFullDPS(build, "CALCULATOR", override, { cachedPlayerDB = cachedPlayerDB, cachedEnemyDB = cachedEnemyDB, cachedMinionDB = cachedMinionDB, env = nil, fullDPSCache = { store = fullDPSStore } })
				return { SkillDPS = fullDPS.skills, FullDPS = fullDPS.combinedDPS, FullDotDPS = fullDPS.TotalDotDPS }
			end
			-- Accelerated pass for hot loops (e.g. gem dropdown DPS sorting): reuse the cached
			-- DBs and environment so unchanged state (tree, items, requirements - per the
			-- accelerate flags) is carried over instead of being rebuilt for every call.
			-- The first call builds the reusable environment from scratch, like calcFullDPS does.
			local accelerate = fastEnv and fastCalcOptions or nil
			fastEnv = calcs.initEnv(build, "CALCULATOR", override, { cachedPlayerDB = cachedPlayerDB, cachedEnemyDB = cachedEnemyDB, cachedMinionDB = cachedMinionDB, env = fastEnv, accelerate = accelerate })
			fastEnv.override = override
			calcs.perform(fastEnv, fastCalcOptions.skipEHP)
			if (useFullDPS ~= false or build.viewMode == "TREE") and usedFullDPS then
				local fullDPS = calcs.calcFullDPS(build, "CALCULATOR", override, { cachedPlayerDB = cachedPlayerDB, cachedEnemyDB = cachedEnemyDB, cachedMinionDB = cachedMinionDB, env = nil})
				fastEnv.player.output.SkillDPS = fullDPS.skills
				fastEnv.player.output.FullDPS = fullDPS.combinedDPS
				fastEnv.player.output.FullDotDPS = fullDPS.TotalDotDPS
			end
			return fastEnv.player.output
		end
		local env, cachedPlayerDB, cachedEnemyDB, cachedMinionDB = calcs.initEnv(build, "CALCULATOR", override)
		-- we need to preserve the override somewhere for use by possible trigger-based build-outs with overrides
		env.override = override
		calcs.perform(env)
		if (useFullDPS ~= false or build.viewMode == "TREE") and usedFullDPS then
			-- prevent upcoming calculation from using Cached Data and thus forcing it to re-calculate new FullDPS roll-up 
			-- without this, FullDPS increase/decrease when for node/item/gem comparison would be all 0 as it would be comparing
			-- A with A (due to cache reuse) instead of A with B
			local fullDPS = calcs.calcFullDPS(build, "CALCULATOR", override, { cachedPlayerDB = cachedPlayerDB, cachedEnemyDB = cachedEnemyDB, cachedMinionDB = cachedMinionDB, env = nil})
			env.player.output.SkillDPS = fullDPS.skills
			env.player.output.FullDPS = fullDPS.combinedDPS
			env.player.output.FullDotDPS = fullDPS.TotalDotDPS
		end
		return env.player.output
	end, env.player.output
end

-- Output fields harvested from each Full DPS calc pass; captured into plain snapshot
-- tables so that cached passes can be merged identically to freshly computed ones
local harvestFields = { "TotalDPS", "BleedDPS", "CorruptingBloodDPS", "IgniteDPS", "BurningGroundDPS", "PoisonDPS", "CausticGroundDPS", "ImpaleDPS", "DecayDPS", "TotalDot", "CullMultiplier" }
local function captureFields(output)
	local captured = { }
	for _, field in ipairs(harvestFields) do
		captured[field] = output[field]
	end
	return captured
end

local mergeStatsSpec = {
	{ key = "BleedDPS", target = "bleedDPS", mode = "max" },
	{ key = "CorruptingBloodDPS", target = "corruptingBloodDPS", mode = "max" },
	{ key = "IgniteDPS", target = "igniteDPS", mode = "max" },
	{ key = "BurningGroundDPS", target = "burningGroundDPS", mode = "max" },
	{ key = "PoisonDPS", target = "poisonDPS", mode = "max" },
	{ key = "CausticGroundDPS", target = "causticGroundDPS", mode = "max" },
	{ key = "ImpaleDPS", target = "impaleDPS", mode = "add", scaled = true },
	{ key = "DecayDPS", target = "decayDPS", mode = "add" },
	{ key = "CullMultiplier", target = "cullingMulti", mode = "cull" },
}

-- Tolerant modifier equality for the Full DPS input diff: mod tables are pointer-stable
-- across initEnv calls within one build revision, except for a few mods constructed per
-- pass (e.g. GemLevel, level-scaled support mods), which are compared structurally instead.
local function modsEqual(a, b)
	return a == b or (type(a) == "table" and type(b) == "table" and tableDeepEquals(a, b) and tableDeepEquals(b, a))
end
local function modListsEqual(refList, curList)
	if #refList ~= #curList then
		return false
	end
	for i = 1, #refList do
		if not modsEqual(refList[i], curList[i]) then
			return false
		end
	end
	return true
end

-- Capture the coupling surface of an environment: the state through which one skill's gems
-- can influence other skills' results - buffs/auras/curses each skill provides (buffList)
-- and exposure it can inflict. While this surface is unchanged, a skill whose own mod list
-- is unchanged must produce unchanged results.
local exposureElements = { "Fire", "Cold", "Lightning", "Chaos" }
local function captureCouplingSurface(env)
	local surface = { mods = { }, meta = { } }
	for _, skill in ipairs(env.player.activeSkillList) do
		for _, buff in ipairs(skill.buffList or { }) do
			surface.meta[#surface.meta + 1] = tostring(buff.type) .. "/" .. tostring(buff.name)
			for _, mod in ipairs(buff.modList or { }) do
				surface.mods[#surface.mods + 1] = mod
			end
		end
		local modList = skill.baseSkillModList
		if modList then
			if modList:HasMod("FLAG", nil, "InflictExposure") then
				surface.meta[#surface.meta + 1] = "expoFlag"
			end
			for _, element in ipairs(exposureElements) do
				if modList:HasMod("BASE", nil, element .. "ExposureChance") then
					surface.meta[#surface.meta + 1] = "expo" .. element
				end
			end
		end
	end
	surface.metaStr = table.concat(surface.meta, ";")
	return surface
end
local function surfacesEqual(refSurface, curSurface)
	return refSurface.metaStr == curSurface.metaStr and modListsEqual(refSurface.mods, curSurface.mods)
end

function calcs.calcFullDPS(build, mode, override, specEnv)
	local fullEnv, cachedPlayerDB, cachedEnemyDB, cachedMinionDB = calcs.initEnv(build, mode, override, specEnv)
	local usedEnv = nil
	-- Optional per-skill result cache driven by input diffing (specEnv.fullDPSCache):
	-- with capture set, each skill's harvested results are stored in the cache store along
	-- with its input references (own mod list + the env's coupling surface); on later calls,
	-- a skill whose references are unchanged merges its cached results instead of recalculating
	local fullDPSCache = specEnv and specEnv.fullDPSCache
	local cacheStore = fullDPSCache and fullDPSCache.store
	local surfaceSame = false
	if cacheStore then
		local curSurface = captureCouplingSurface(fullEnv)
		if fullDPSCache.capture then
			cacheStore.snapshots = { }
			cacheStore.refs = { }
			cacheStore.surface = curSurface
		else
			surfaceSame = cacheStore.surface ~= nil and surfacesEqual(cacheStore.surface, curSurface)
		end
	end

	local fullDPS = {
		combinedDPS = 0,
		TotalDotDPS = 0,
		skills = { },
		poisonDPS = 0,
		causticGroundDPS = 0,
		impaleDPS = 0,
		igniteDPS = 0,
		burningGroundDPS = 0,
		bleedDPS = 0,
		corruptingBloodDPS = 0,
		decayDPS = 0,
		dotDPS = 0,
		cullingMulti = 0
	}


	local sources = { }

	local function mergeStats(out, count, sourceName)
		for _, stat in ipairs(mergeStatsSpec) do
			local value = out[stat.key]
			if value then
				if stat.mode == "max" then
					if value > fullDPS[stat.target] then
						fullDPS[stat.target] = value
						sources[stat.target] = sourceName
					end
				elseif stat.mode == "add" then
					if value > 0 then
						fullDPS[stat.target] = fullDPS[stat.target] + value * (stat.scaled and count or 1)
					end
				elseif stat.mode == "cull" then
					if value > 1 and value > fullDPS[stat.target] then
						fullDPS[stat.target] = value
					end
				end
			end
		end
	end

	-- Merge one captured calc pass into the Full DPS totals
		local function mergePass(pass)
		for _, actor in ipairs(pass.actors) do
			local out = actor.out
			if out.TotalDPS and out.TotalDPS > 0 then
				t_insert(fullDPS.skills, { name = actor.name, dps = out.TotalDPS, count = actor.count, trigger = actor.trigger, skillPart = actor.skillPart })
				fullDPS.combinedDPS = fullDPS.combinedDPS + out.TotalDPS * actor.count
			end
			mergeStats(out, actor.count, actor.sourceName)
			if out.TotalDot and out.TotalDot > 0 and actor.dotScale then
				fullDPS.dotDPS = fullDPS.dotDPS + out.TotalDot * actor.dotScale
			end
		end
	end

	for _, activeSkill in ipairs(fullEnv.player.activeSkillList) do
		if activeSkill.socketGroup and activeSkill.socketGroup.includeInFullDPS then
			local uuid = cacheStore and cacheSkillUUID(activeSkill, fullEnv)
			local cachedPasses
			if surfaceSame and activeSkill.baseSkillModList then
				local ref = cacheStore.refs[uuid]
				if ref and cacheStore.snapshots[uuid] and modListsEqual(ref, activeSkill.baseSkillModList) then
					cachedPasses = cacheStore.snapshots[uuid]
				end
			end
			local activeSkillCount, enabled
			if not cachedPasses then
				activeSkillCount, enabled = calcs.getActiveSkillCount(activeSkill)
			end
			if cachedPasses then
				-- This skill's own mod list and the coupling surface are unchanged since the
				-- capture pass, so its results cannot have changed: merge the cached passes
				for _, pass in ipairs(cachedPasses) do
					mergePass(pass)
				end
			elseif enabled then
				local ownRef
				if cacheStore and fullDPSCache.capture and activeSkill.baseSkillModList then
					-- Reference the skill's pre-perform mod list for later input diffing
					ownRef = { }
					for i, mod in ipairs(activeSkill.baseSkillModList) do
						ownRef[i] = mod
					end
				end
				fullEnv.player.mainSkill = activeSkill
				calcs.perform(fullEnv, true)
				usedEnv = fullEnv
				-- Capture this pass's results into a plain snapshot, then merge it into the totals;
				-- the snapshot lets later calls reuse the results when this skill's inputs are unchanged
				local skillName = activeSkill.activeEffect.grantedEffect.name
				local dotCanStack = activeSkill.activeEffect.statSet.skillFlags.DotCanStack
				local pass = { actors = { } }
				local minionOut
				if activeSkill.minion or usedEnv.minion then
					minionOut = captureFields(usedEnv.minion.output)
					local minionNamePrefix = (activeSkill.minion and activeSkill.minion.minionData.name..": ") or (usedEnv.minion and usedEnv.minion.minionData.name..": ") or ""
					t_insert(pass.actors, {
						out = minionOut,
						name = skillName,
						count = activeSkillCount,
						trigger = activeSkill.infoTrigger,
						skillPart = minionNamePrefix .. activeSkill.skillPartName,
						sourceName = skillName,
						dotScale = 1,
					})
					-- This is a fix to prevent Absolution spell hit from being counted multiple times when increasing minions count
					if activeSkill.activeEffect.grantedEffect.name == "Absolution" and fullEnv.modDB:Flag(false, "Condition:AbsolutionSkillDamageCountedOnce") then
						activeSkillCount = 1
						activeSkill.infoMessage2 = "Skill Damage"
					end
				end

				local playerOut = captureFields(usedEnv.player.output)
				if activeSkill.mirage then
					local mirageCount = (activeSkill.mirage.count or 1) * activeSkillCount
					t_insert(pass.actors, {
						out = captureFields(activeSkill.mirage.output),
						name = activeSkill.mirage.name .. " (Mirage)",
						count = mirageCount,
						trigger = activeSkill.mirage.infoTrigger,
						skillPart = activeSkill.mirage.skillPartName,
						sourceName = skillName .. " (Mirage)",
						dotScale = (dotCanStack or (playerOut.TotalDot and playerOut.TotalDot == 0)) and (dotCanStack and mirageCount or 1) or nil,
					})
				end

				local minionContributed = minionOut and minionOut.TotalDPS and minionOut.TotalDPS > 0
				t_insert(pass.actors, {
					out = playerOut,
					name = skillName,
					count = activeSkillCount,
					trigger = activeSkill.infoTrigger,
					skillPart = minionContributed and activeSkill.infoMessage2 or activeSkill.skillPartName,
					sourceName = skillName,
					dotScale = dotCanStack and activeSkillCount or 1,
				})
				mergePass(pass)
				if cacheStore and fullDPSCache.capture and ownRef then
					cacheStore.snapshots[uuid] = { pass }
					cacheStore.refs[uuid] = ownRef
				end

				-- Re-Build env calculator for new run
				local accelerationTbl = {
					nodeAlloc = true,
					requirementsItems = true,
					requirementsGems = true,
					skills = true,
					everything = true,
				}
				fullEnv, _, _, _ = calcs.initEnv(build, mode, override, { cachedPlayerDB = cachedPlayerDB, cachedEnemyDB = cachedEnemyDB, cachedMinionDB = cachedMinionDB, env = fullEnv, accelerate = accelerationTbl })
			end
		end
	end

	-- Re-Add ailment DPS components
	fullDPS.TotalDotDPS = 0
	if fullDPS.bleedDPS > 0 then
		t_insert(fullDPS.skills, { name = "Best Bleed DPS", dps = fullDPS.bleedDPS, count = 1, source = sources.bleedDPS or "" })
		fullDPS.TotalDotDPS = fullDPS.TotalDotDPS + fullDPS.bleedDPS
	end
	if fullDPS.corruptingBloodDPS > 0 then
		t_insert(fullDPS.skills, { name = "Best Corr. Blood DPS", dps = fullDPS.corruptingBloodDPS, count = 1, source = sources.corruptingBloodDPS or "" })
		fullDPS.TotalDotDPS = fullDPS.TotalDotDPS + fullDPS.corruptingBloodDPS
	end
	if fullDPS.igniteDPS > 0 then
		t_insert(fullDPS.skills, { name = "Best Ignite DPS", dps = fullDPS.igniteDPS, count = 1, source = sources.igniteDPS or "" })
		fullDPS.TotalDotDPS = fullDPS.TotalDotDPS + fullDPS.igniteDPS
	end
	if fullDPS.burningGroundDPS > 0 then
		t_insert(fullDPS.skills, { name = "Best Burning Ground DPS", dps = fullDPS.burningGroundDPS, count = 1, source = sources.burningGroundDPS or "" })
		fullDPS.TotalDotDPS = fullDPS.TotalDotDPS + fullDPS.burningGroundDPS
	end
	if fullDPS.poisonDPS > 0 then
		t_insert(fullDPS.skills, { name = "Best Poison DPS", dps = fullDPS.poisonDPS, count = 1, source = sources.poisonDPS or "" })
		fullDPS.TotalDotDPS = fullDPS.TotalDotDPS + fullDPS.poisonDPS
	end
	if fullDPS.causticGroundDPS > 0 then
		t_insert(fullDPS.skills, { name = "Best Caustic Ground DPS", dps = fullDPS.causticGroundDPS, count = 1, source = sources.causticGroundDPS or "" })
		fullDPS.TotalDotDPS = fullDPS.TotalDotDPS + fullDPS.causticGroundDPS
	end
	if fullDPS.impaleDPS > 0 then
		t_insert(fullDPS.skills, { name = "Full Impale DPS", dps = fullDPS.impaleDPS, count = 1 })
		fullDPS.combinedDPS = fullDPS.combinedDPS + fullDPS.impaleDPS
	end
	if fullDPS.decayDPS > 0 then
		t_insert(fullDPS.skills, { name = "Full Decay DPS", dps = fullDPS.decayDPS, count = 1 })
		fullDPS.TotalDotDPS = fullDPS.TotalDotDPS + fullDPS.decayDPS
	end
	if fullDPS.dotDPS > 0 then
		t_insert(fullDPS.skills, { name = "Full DoT DPS", dps = fullDPS.dotDPS, count = 1 })
		fullDPS.TotalDotDPS = fullDPS.TotalDotDPS + fullDPS.dotDPS
	end
	fullDPS.TotalDotDPS = m_min(fullDPS.TotalDotDPS, data.misc.DotDpsCap)
	fullDPS.combinedDPS = fullDPS.combinedDPS + fullDPS.TotalDotDPS
	if fullDPS.cullingMulti > 0 then
		fullDPS.cullingDPS = fullDPS.combinedDPS * (fullDPS.cullingMulti - 1)
		t_insert(fullDPS.skills, { name = "Full Culling DPS", dps = fullDPS.cullingDPS, count = 1 })
		fullDPS.combinedDPS = fullDPS.combinedDPS + fullDPS.cullingDPS
	end

	return fullDPS
end

-- Process active skill
function calcs.buildActiveSkill(env, mode, skill, targetUUID, limitedProcessingFlags)
	local fullEnv, _, _, _ = calcs.initEnv(env.build, mode, env.override)

	-- env.limitedSkills contains a map of uuids that should be limited in calculation
	-- this is in order to prevent infinite recursion loops
	fullEnv.limitedSkills = fullEnv.limitedSkills or {}
	for uuid, _ in pairs(env.limitedSkills or {}) do
		fullEnv.limitedSkills[uuid] = true
	end
	for uuid, _ in pairs(limitedProcessingFlags or {}) do
		fullEnv.limitedSkills[uuid] = true
	end

	targetUUID = targetUUID or cacheSkillUUID(skill, env)
	for _, activeSkill in ipairs(fullEnv.player.activeSkillList) do
		local activeSkillUUID = cacheSkillUUID(activeSkill, fullEnv)
		if activeSkillUUID == targetUUID then
			fullEnv.player.mainSkill = activeSkill
			calcs.perform(fullEnv, true)
			return
		end
	end
	ConPrintf("[calcs.buildActiveSkill] Failed to process skill: " .. skill.activeEffect.grantedEffect.name)
end

-- Build output for display in the side bar or calcs tab
function calcs.buildOutput(build, mode)
	-- Build output for selected main skill
	local env, cachedPlayerDB, cachedEnemyDB, cachedMinionDB = calcs.initEnv(build, mode)
	calcs.perform(env)

	local output = env.player.output

	-- Build output across all skills added to FullDPS skills
	local fullDPS = calcs.calcFullDPS(build, "CALCULATOR", {}, { cachedPlayerDB = cachedPlayerDB, cachedEnemyDB = cachedEnemyDB, cachedMinionDB = cachedMinionDB, env = nil })

	-- Add Full DPS data to main `env`
	env.player.output.SkillDPS = fullDPS.skills
	env.player.output.FullDPS = fullDPS.combinedDPS
	env.player.output.FullDotDPS = fullDPS.TotalDotDPS

	if mode == "MAIN" then
		for _, skill in ipairs(env.player.activeSkillList) do
			local uuid = cacheSkillUUID(skill, env)
			if not GlobalCache.cachedData[mode][uuid] then
				calcs.buildActiveSkill(env, mode, skill, uuid)
			end
			if GlobalCache.cachedData[mode][uuid] and (not skill.triggeredBy or skill.triggeredBy.grantedEffect.id ~= "SupportBlasphemyPlayer") then
				output.EnergyShieldProtectsMana = env.modDB:Flag(nil, "EnergyShieldProtectsMana")
				for pool, costResource in pairs({["LifeUnreserved"] = "LifeCost", ["ManaUnreserved"] = "ManaCost", ["Rage"] = "RageCost", ["EnergyShield"] = "ESCost"}) do
					local cachedCost = GlobalCache.cachedData[mode][uuid].Env.player.output[costResource]
					if cachedCost then
						local totalPool = (output.EnergyShieldProtectsMana and costResource == "ManaCost" and output["EnergyShield"] or 0) + (output[pool] or 0)
						if totalPool < cachedCost then
							local rawPool = pool:gsub("Unreserved$", "")
							local reservation = GlobalCache.cachedData[mode][uuid].Env.player.mainSkill and GlobalCache.cachedData[mode][uuid].Env.player.mainSkill.skillData[rawPool .. "ReservedPercent"]
							-- Skill has both cost and reservation check if there's available pool for raw cost before reservation
							if not reservation or (reservation and (totalPool + m_ceil((output[rawPool] or 0) * reservation / 100)) < cachedCost) then
								if env.player.mainSkill and env.player.mainSkill.activeEffect.grantedEffect.name == skill.activeEffect.grantedEffect.name then
									output[costResource.."Warning"] = true
								end
								output[costResource.."WarningList"] = output[costResource.."WarningList"] or {}
								t_insert(output[costResource.."WarningList"], skill.activeEffect.grantedEffect.name)
							end
						end
						output.EternalLifeWarning = output.EternalLifeWarning or env.modDB:Flag(nil, "EternalLife") and costResource == "LifeCost" and cachedCost > 0 and output.EnergyShieldRecoveryCap > 0
					end
				end
				for pool, costResource in pairs({["LifeUnreservedPercent"] = "LifePercentCost", ["ManaUnreservedPercent"] = "ManaPercentCost"}) do
					local cachedCost = GlobalCache.cachedData[mode][uuid].Env.player.output[costResource]
					if cachedCost then
						if (output[pool] or 0) < cachedCost then
							output[costResource.."PercentCostWarningList"] = output[costResource.."PercentCostWarningList"] or {}
							t_insert(output[costResource.."PercentCostWarningList"], skill.activeEffect.grantedEffect.name)
						end
					end
				end
			end
		end
	
		output.ExtraPoints = env.modDB:Sum("BASE", nil, "ExtraPoints")
		output.WeaponSetPassivePoints = env.modDB:Sum("BASE", nil, "WeaponSetPassivePoints")
		output.PassivePointsToWeaponSetPoints = env.modDB:Sum("BASE", nil, "PassivePointsToWeaponSetPoints")

		local specCfg = {
			source = "Tree"
		}
		output["Spec:LifeInc"] = env.modDB:Sum("INC", nil, "Life")
		output["Spec:ManaInc"] = env.modDB:Sum("INC", specCfg, "Mana")
		output["Spec:ArmourInc"] = env.modDB:Sum("INC", specCfg, "Armour", "ArmourAndEvasion")
		output["Spec:EvasionInc"] = env.modDB:Sum("INC", specCfg, "Evasion", "ArmourAndEvasion")
		output["Spec:EnergyShieldInc"] = env.modDB:Sum("INC", specCfg, "EnergyShield")

		env.skillsUsed = { }
		for _, activeSkill in ipairs(env.player.activeSkillList) do
			for _, skillEffect in ipairs(activeSkill.effectList) do
				env.skillsUsed[skillEffect.grantedEffect.name] = true
			end
			if activeSkill.minion then
				for	_, activeSkill in ipairs(activeSkill.minion.activeSkillList) do
					env.skillsUsed[activeSkill.activeEffect.grantedEffect.id] = true
				end
			end
		end

		env.conditionsUsed = { }
		env.enemyConditionsUsed = { }
		env.minionConditionsUsed = { }
		env.multipliersUsed = { }
		env.enemyMultipliersUsed = { }
		env.perStatsUsed = { }
		env.enemyPerStatsUsed = { }
		env.tagTypesUsed = { }
		env.modsUsed = { }
		local function addTo(out, var, mod)
			-- Do not count Base mods as mods being actually used as they are only used as descriptors for mods
			if mod.source == "Base" then
				return
			end
			if not out[var] then
				out[var] = { }
			end
			t_insert(out[var], mod)
		end
		local function addVarTag(out, tag, mod)
			if tag.varList then
				for _, var in ipairs(tag.varList) do
					addTo(out, var, mod)
				end
			else
				addTo(out, tag.var, mod)
			end
		end
		local function addStatTag(out, tag, mod)
			if tag.varList then
				for _, var in ipairs(tag.statList) do
					addTo(out, var, mod)
				end
			elseif tag.stat then
				addTo(out, tag.stat, mod)
			end
		end
		local function addModTags(actor, mod)
			addTo(env.modsUsed, mod.name, mod)
			
			-- Imply enemy conditionals based on damage type
			-- Needed to preemptively show config options for elemental ailments
			for dmgType, conditions in pairs({["[fi][ig][rn][ei]t?e?"] = {"Ignited", "Burning"}, ["[cf][or][le][de]z?e?"] = {"Frozen"}}) do
				if mod.name:lower():match(dmgType) then
					for _, var in ipairs(conditions) do
						addTo(env.enemyConditionsUsed, var, mod)
					end
				end
			end
			
			for _, tag in ipairs(mod) do
				addTo(env.tagTypesUsed, tag.type, mod)
				if tag.type == "IgnoreCond" then
					break
				elseif tag.type == "Condition" then
					if actor == env.player then
						addVarTag(env.conditionsUsed, tag, mod)
					else
						addVarTag(env.minionConditionsUsed, tag, mod)
					end
				elseif tag.type == "ActorCondition" and tag.var then
					if tag.actor == "enemy" then
						addTo(env.enemyConditionsUsed, tag.var, mod)
					else
						addTo(env.conditionsUsed, tag.var, mod)
					end
				elseif tag.type == "Multiplier" or tag.type == "MultiplierThreshold" then
					if not tag.actor then
						if actor == env.player then
							addVarTag(env.multipliersUsed, tag, mod)
						end
					elseif tag.actor == "enemy" then
						addVarTag(env.enemyMultipliersUsed, tag, mod)
					end
				elseif tag.type == "PerStat" or tag.type == "StatThreshold" then
					if not tag.actor then
						if actor == env.player then
							addStatTag(env.perStatsUsed, tag, mod)
						end
					elseif tag.actor == "enemy" then
						addStatTag(env.enemyPerStatsUsed, tag, mod)
					end
				end
			end
		end
		for _, actor in ipairs({env.player, env.minion}) do
			for modName, modList in pairs(actor.modDB.mods) do
				for _, mod in ipairs(modList) do
					addModTags(actor, mod)
				end
			end
		end
		for _, activeSkill in pairs(env.player.activeSkillList) do
			for _, mod in ipairs(activeSkill.baseSkillModList) do
				addModTags(env.player, mod)
			end
			for _, mod in ipairs(activeSkill.skillModList) do
				addTo(env.modsUsed, mod.name, mod)
				for _, tag in ipairs(mod) do
					addTo(env.tagTypesUsed, tag.type, mod)
				end
			end
			if activeSkill.minion then
				for _, activeSkill in pairs(activeSkill.minion.activeSkillList) do
					for _, mod in ipairs(activeSkill.baseSkillModList) do
						addModTags(env.minion, mod)
					end
				end
			end
		end
		for modName, modList in pairs(env.enemyDB.mods) do
			for _, mod in ipairs(modList) do
				for _, tag in ipairs(mod) do
					if tag.type == "IgnoreCond" then
						break
					elseif tag.type == "Condition" then
						addVarTag(env.enemyConditionsUsed, tag, mod)
					elseif tag.type == "ActorCondition" and tag.var then
						if tag.actor == "enemy" or tag.actor == "player" then
							addTo(env.conditionsUsed, tag.var, mod)
						else
							addTo(env.enemyConditionsUsed, tag.var, mod)
						end
					elseif tag.type == "Multiplier" or tag.type == "MultiplierThreshold" then
						if not tag.actor then
							addVarTag(env.enemyMultipliersUsed, tag, mod)
						elseif tag.actor == "enemy" or tag.actor == "player" then
							addVarTag(env.multipliersUsed, tag, mod)
						end
					end
				end
			end
		end
--		ConPrintf("=== Cond ===")
--		ConPrintTable(env.conditionsUsed)
--		ConPrintf("=== Mult ===")
--		ConPrintTable(env.multipliersUsed)
--		ConPrintf("=== Minion Cond ===")
--		ConPrintTable(env.minionConditionsUsed)
--		ConPrintf("=== Enemy Cond ===")
--		ConPrintTable(env.enemyConditionsUsed)
--		ConPrintf("=== Enemy Mult ===")
--		ConPrintTable(env.enemyMultipliersUsed)
	elseif mode == "CALCS" then
		local buffList = { }
		local combatList = { }
		local curseList = { }
		if output.PowerCharges > 0 then
			t_insert(combatList, s_format("%d Power Charges", output.PowerCharges))
		end
		if output.AbsorptionCharges > 0 then
			t_insert(combatList, s_format("%d Absorption Charges", output.AbsorptionCharges))
		end
		if output.FrenzyCharges > 0 then
			t_insert(combatList, s_format("%d Frenzy Charges", output.FrenzyCharges))
		end
		if output.AfflictionCharges > 0 then
			t_insert(combatList, s_format("%d Affliction Charges", output.AfflictionCharges))
		end
		if output.EnduranceCharges > 0 then
			t_insert(combatList, s_format("%d Endurance Charges", output.EnduranceCharges))
		end
		if output.BrutalCharges > 0 then
			t_insert(combatList, s_format("%d Brutal Charges", output.BrutalCharges))
		end
		if output.SiphoningCharges > 0 then
			t_insert(combatList, s_format("%d Siphoning Charges", output.SiphoningCharges))
		end
		if output.ChallengerCharges > 0 then
			t_insert(combatList, s_format("%d Challenger Charges", output.ChallengerCharges))
		end
		if output.BlitzCharges > 0 then
			t_insert(combatList, s_format("%d Blitz Charges", output.BlitzCharges))
		end
		if build.calcsTab.mainEnv.multipliersUsed["InspirationCharge"] then
			t_insert(combatList, s_format("%d Inspiration Charges", output.InspirationCharges))
		end
		if output.GhostShrouds > 0 then
			t_insert(combatList, s_format("%d Ghost Shrouds", output.GhostShrouds))
		end
		if output.CrabBarriers > 0 then
			t_insert(combatList, s_format("%d Crab Barriers", output.CrabBarriers))
		end
		if build.calcsTab.mainEnv.multipliersUsed["BloodCharge"] then
			t_insert(combatList, s_format("%d Blood Charges", output.BloodCharges))
		end
		if build.calcsTab.mainEnv.multipliersUsed["SpiritCharge"] then
			t_insert(combatList, s_format("%d Spirit Charges", output.SpiritCharges))
		end
		if env.player.mainSkill.baseSkillModList:Flag(nil, "Cruelty") then
			t_insert(combatList, "Cruelty")
		end
		if env.modDB:Flag(nil, "Fortify") then
			t_insert(combatList, "Fortify")
		end
		if env.modDB:Flag(nil, "Onslaught") then
			t_insert(combatList, "Onslaught")
		end
		if env.modDB:Flag(nil, "UnholyMight") then
			t_insert(combatList, "Unholy Might")
		end
		if env.modDB:Flag(nil, "ChaoticMight") then
			t_insert(combatList, "Chaotic Might")
		end
		if env.modDB:Flag(nil, "Tailwind") then
			t_insert(combatList, "Tailwind")
		end
		if env.modDB:Flag(nil, "Adrenaline") then
			t_insert(combatList, "Adrenaline")
		end
		if env.modDB:Flag(nil, "AlchemistsGenius") then
			t_insert(combatList, "Alchemist's Genius")
		end
		if env.modDB:Flag(nil, "HerEmbrace") then
			t_insert(combatList, "Her Embrace")
		end
		if env.modDB:Flag(nil, "LesserMassiveShrine") then
			t_insert(combatList, "Lesser Massive Shrine")
		end
		if env.modDB:Flag(nil, "LesserBrutalShrine") then
			t_insert(combatList, "Lesser Brutal Shrine")
		end
		if env.modDB:Flag(nil, "DiamondShrine") then
			t_insert(combatList, "Diamond Shrine")
		end
		if env.modDB:Flag(nil, "MassiveShrine") then
			t_insert(combatList, "Massive Shrine")
		end
		for name in pairs(env.buffs) do
			t_insert(buffList, name)
		end
		if env.modDB:Flag(nil, "Elusive") then
			t_insert(combatList, "Elusive")
		end
		table.sort(buffList)
		env.player.breakdown.SkillBuffs = { modList = { } }
		for _, name in ipairs(buffList) do
			for _, mod in ipairs(env.buffs[name]) do
				local value = env.modDB:EvalMod(mod)
				if value and value ~= 0 then
					t_insert(env.player.breakdown.SkillBuffs.modList, {
						mod = mod,
						value = value,
					})
				end
			end
		end
		env.player.breakdown.SkillDebuffs = { modList = { } }
		for name, modList in pairs(env.debuffs) do
			t_insert(curseList, name)
		end
		table.sort(curseList)
		for index, name in ipairs(curseList) do
			for _, mod in ipairs(env.debuffs[name]) do
				local value = env.enemy.modDB:EvalMod(mod)
				if value and value ~= 0 then
					t_insert(env.player.breakdown.SkillDebuffs.modList, {
						mod = mod,
						value = value,
					})
				end
			end
			local stackCount = env.debuffs[name]:Sum("BASE", nil, "Multiplier:"..name.."Stack")
			if stackCount > 0 then
				curseList[index] = name .. " (" .. stackCount .. " stack" .. (stackCount > 1 and "s" or "") .. ")"
			end
		end
		for _, slot in ipairs(env.curseSlots) do
			t_insert(curseList, slot.name)
			if slot.modList then
				for _, mod in ipairs(slot.modList) do
					local value = env.enemy.modDB:EvalMod(mod)
					if value and value ~= 0 then
						t_insert(env.player.breakdown.SkillDebuffs.modList, {
							mod = mod,
							value = value,
						})
					end
				end
			end
		end
		output.BuffList = table.concat(buffList, ", ")
		output.CombatList = table.concat(combatList, ", ")
		output.CurseList = table.concat(curseList, ", ")
		if env.minion then
			local buffList = { }
			local combatList = { }
			if output.Minion.PowerCharges > 0 then
				t_insert(combatList, s_format("%d Power Charges", output.Minion.PowerCharges))
			end
			if output.Minion.FrenzyCharges > 0 then
				t_insert(combatList, s_format("%d Frenzy Charges", output.Minion.FrenzyCharges))
			end
			if output.Minion.EnduranceCharges > 0 then
				t_insert(combatList, s_format("%d Endurance Charges", output.Minion.EnduranceCharges))
			end
			if env.minion.modDB:Flag(nil, "Fortify") then
				t_insert(combatList, "Fortify")
			end
			if env.minion.modDB:Flag(nil, "Onslaught") then
				t_insert(combatList, "Onslaught")
			end
			if env.minion.modDB:Flag(nil, "UnholyMight") then
				t_insert(combatList, "Unholy Might")
			end
			if env.minion.modDB:Flag(nil, "ChaoticMight") then
				t_insert(combatList, "Chaotic Might")
			end
			if env.minion.modDB:Flag(nil, "Tailwind") then
				t_insert(combatList, "Tailwind")
			end
			if env.minion.modDB:Flag(nil, "DiamondShrine") then
				t_insert(combatList, "Diamond Shrine")
			end
			if env.minion.modDB:Flag(nil, "MassiveShrine") then
				t_insert(combatList, "Massive Shrine")
			end
			for name in pairs(env.minionBuffs) do
				t_insert(buffList, name)
			end
			table.sort(buffList)
			env.minion.breakdown.SkillBuffs = { modList = { } }
			for _, name in ipairs(buffList) do
				for _, mod in ipairs(env.minionBuffs[name]) do
					local value = env.minion.modDB:EvalMod(mod)
					if value and value ~= 0 then
						t_insert(env.minion.breakdown.SkillBuffs.modList, {
							mod = mod,
							value = value,
						})
					end
				end
			end
			env.minion.breakdown.SkillDebuffs = env.player.breakdown.SkillDebuffs
			output.Minion.BuffList = table.concat(buffList, ", ")
			output.Minion.CombatList = table.concat(combatList, ", ")
			output.Minion.CurseList = output.CurseList
		end

		-- infoDump(env)
	end

	return env
end

return calcs
