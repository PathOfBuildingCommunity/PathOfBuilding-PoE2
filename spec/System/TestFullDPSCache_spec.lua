describe("TestFullDPSCache", function()
	local calcsModule

	before_each(function()
		newBuild()
		calcsModule = LoadModule("Modules/Calcs")
	end)

	-- Two single-skill groups, both included in Full DPS
	local function buildTwoGroups()
		build.skillsTab:PasteSocketGroup("Spark 20/0  1")
		runCallback("OnFrame")
		build.skillsTab:PasteSocketGroup("Fireball 20/0  1")
		runCallback("OnFrame")
		local sparkGroup = build.skillsTab.socketGroupList[1]
		local fireballGroup = build.skillsTab.socketGroupList[2]
		sparkGroup.mainActiveSkill = 1
		fireballGroup.mainActiveSkill = 1
		sparkGroup.includeInFullDPS = true
		fireballGroup.includeInFullDPS = true
		build.mainSocketGroup = 1
		build.buildFlag = true
		runCallback("OnFrame")
		return sparkGroup, fireballGroup
	end

	local function buildMinionGroup()
		build.skillsTab:PasteSocketGroup("Skeletal Sniper 20/0  1")
		runCallback("OnFrame")
		local group = build.skillsTab.socketGroupList[1]
		group.mainActiveSkill = 1
		build.mainSocketGroup = 1
		build.viewMode = "SKILLS"
		build.buildFlag = true
		runCallback("OnFrame")
		return group
	end

	local function findGem(name)
		for _, gemData in pairs(build.data.gems) do
			if gemData.name == name then
				return gemData
			end
		end
	end

	local function makeGemInstance(gemData, level)
		return {
			level = level or gemData.naturalMaxLevel, quality = 0,
			count = 1, enabled = true, enableGlobal1 = true, enableGlobal2 = true,
			gemId = gemData.id, nameSpec = gemData.name, skillId = gemData.grantedEffectId,
			gemData = gemData,
		}
	end

	-- Run calcFullDPS, optionally with a cache, counting perform passes per skill name
	local function runFullDPS(cache, counts)
		local realPerform = calcsModule.perform
		if counts then
			calcsModule.perform = function(env, ...)
				realPerform(env, ...)
				if env.player and env.player.mainSkill then
					local name = env.player.mainSkill.activeEffect.grantedEffect.name
					counts[name] = (counts[name] or 0) + 1
				end
			end
		end
		local result = calcsModule.calcFullDPS(build, "CALCULATOR", {}, cache and { fullDPSCache = cache } or {})
		calcsModule.perform = realPerform
		return result
	end

	-- Capture a base cache, then evaluate one candidate gem socketed into the group,
	-- returning the cached-path result, per-skill perform counts, and a fresh result
	local function evaluateGem(group, gemData, level)
		local store = { }
		runFullDPS({ store = store, capture = true })
		local slotIndex = #group.gemList + 1
		group.gemList[slotIndex] = makeGemInstance(gemData, level)
		local counts = { }
		local cachedResult = runFullDPS({ store = store }, counts)
		local freshResult = runFullDPS(nil)
		group.gemList[slotIndex] = nil
		return cachedResult, counts, freshResult
	end

	local function assertClose(expected, actual, label)
		local diff = math.abs((expected or 0) - (actual or 0))
		local scale = math.max(math.abs(expected or 0), math.abs(actual or 0), 1)
		assert.is_true(diff <= scale * 1e-9, (label or "value") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
	end

	it("returns identical results from the cached path and a fresh calculation", function()
		local sparkGroup = buildTwoGroups()
		for _, gemName in ipairs({ "Controlled Destruction", "Fire Exposure", "Purity of Fire", "Bleed II" }) do
			local gemData = findGem(gemName)
			assert.is_true(gemData ~= nil, "gem not found: " .. gemName)
			local cachedResult, _, freshResult = evaluateGem(sparkGroup, gemData)
			assertClose(freshResult.combinedDPS, cachedResult.combinedDPS, gemName .. " combinedDPS")
			assertClose(freshResult.TotalDotDPS, cachedResult.TotalDotDPS, gemName .. " TotalDotDPS")
		end
	end)

	it("reuses the other skill's result for a local support", function()
		local sparkGroup = buildTwoGroups()
		local _, counts = evaluateGem(sparkGroup, findGem("Controlled Destruction"))
		assert.is_true((counts["Spark"] or 0) >= 1, "Spark should be recalculated")
		assert.is_true(counts["Fireball"] == nil, "Fireball should be served from the cache")
	end)

	it("recalculates other skills when the support can inflict exposure", function()
		local sparkGroup = buildTwoGroups()
		local _, counts = evaluateGem(sparkGroup, findGem("Fire Exposure"))
		assert.is_true((counts["Spark"] or 0) >= 1, "Spark should be recalculated")
		assert.is_true((counts["Fireball"] or 0) >= 1, "Fireball must be recalculated when exposure enters the build")
	end)

	it("recalculates other skills when the support changes the buff surface", function()
		local sparkGroup = buildTwoGroups()
		local _, counts = evaluateGem(sparkGroup, findGem("Purity of Fire"))
		assert.is_true((counts["Fireball"] or 0) >= 1, "Fireball must be recalculated when a buff/aura is granted")
	end)

	it("caches skills whose supports rebuild level-scaled mods each pass (Minion Mastery)", function()
		local sparkGroup = buildTwoGroups()
		build.skillsTab:PasteSocketGroup("Skeletal Sniper 20/0  1")
		runCallback("OnFrame")
		local sniperGroup = build.skillsTab.socketGroupList[3]
		sniperGroup.mainActiveSkill = 1
		sniperGroup.includeInFullDPS = true
		local masteryData = findGem("Minion Mastery")
		assert.is_true(masteryData ~= nil, "Minion Mastery gem not found")
		table.insert(sniperGroup.gemList, makeGemInstance(masteryData))
		build.buildFlag = true
		runCallback("OnFrame")
		-- The GemSupportLevel mod granted by Minion Mastery is reconstructed every initEnv;
		-- the structural comparator must still recognise the sniper's inputs as unchanged
		local cachedResult, counts, freshResult = evaluateGem(sparkGroup, findGem("Controlled Destruction"))
		assert.is_true(counts["Skeletal Sniper"] == nil, "Skeletal Sniper should be served from the cache despite Minion Mastery")
		assertClose(freshResult.combinedDPS, cachedResult.combinedDPS, "combinedDPS with Minion Mastery in build")
	end)

	it("candidate gem level changes the cached-path result like a fresh one", function()
		local sparkGroup = buildTwoGroups()
		local gemData = findGem("Controlled Destruction")
		local cachedLow, _, freshLow = evaluateGem(sparkGroup, gemData, 1)
		assertClose(freshLow.combinedDPS, cachedLow.combinedDPS, "combinedDPS at level 1")
		local cachedHigh, _, freshHigh = evaluateGem(sparkGroup, gemData)
		assertClose(freshHigh.combinedDPS, cachedHigh.combinedDPS, "combinedDPS at max level")
	end)

	it("end to end: the misc calculator fast path matches the slow path", function()
		local sparkGroup = buildTwoGroups()
		local calcFunc = build.calcsTab:GetMiscCalculator()
		local fastOpts = { nodeAlloc = true, requirementsItems = true, requirementsGems = true, skipEHP = true, fullDPSOnly = true }
		for _, gemName in ipairs({ "Controlled Destruction", "Fire Exposure" }) do
			local gemData = findGem(gemName)
			local slotIndex = #sparkGroup.gemList + 1
			sparkGroup.gemList[slotIndex] = makeGemInstance(gemData)
			local slow = calcFunc(nil, true)
			local slowFullDPS, slowDot = slow.FullDPS, slow.FullDotDPS
			local fast = calcFunc(nil, true, fastOpts)
			sparkGroup.gemList[slotIndex] = nil
			assertClose(slowFullDPS, fast.FullDPS, gemName .. " FullDPS")
			assertClose(slowDot, fast.FullDotDPS, gemName .. " FullDotDPS")
		end
	end)

	it("ordinary DPS fast calculations match fresh minion calculations", function()
		local group = buildMinionGroup()
		local calcFunc = build.calcsTab:GetMiscCalculator()
		local fastOpts = { nodeAlloc = true, requirementsItems = true, requirementsGems = true, skipEHP = true }
		for _, gemName in ipairs({ "Heft", "Meat Shield I" }) do
			local slotIndex = #group.gemList + 1
			local gemData = assert(findGem(gemName), "gem not found: " .. gemName)
			group.gemList[slotIndex] = makeGemInstance(gemData, build.skillsTab:ProcessGemLevel(gemData))
			local slow = calcFunc(nil, false)
			local slowTotalDPS = assert(slow.Minion and slow.Minion.TotalDPS)
			local slowAverageDamage = assert(slow.Minion.AverageDamage)
			local fast = calcFunc(nil, false, fastOpts)
			group.gemList[slotIndex] = nil
			assertClose(slowTotalDPS, fast.Minion.TotalDPS, gemName .. " minion TotalDPS")
			assertClose(slowAverageDamage, fast.Minion.AverageDamage, gemName .. " minion AverageDamage")
		end
	end)

	it("gem sorting reads the selected minion damage field", function()
		local group = buildMinionGroup()
		build.skillsTab:SetDisplayGroup(group)
		local control = assert(build.skillsTab.gemSlots[#group.gemList + 1].nameSpec)
		control.sortGemsBy = "support"
		local candidateOutput = { FullDPS = 444, Minion = { CombinedDPS = 333, TotalDPS = 222, AverageDamage = 111 } }
		local baseOutput = { FullDPS = 4, Minion = { CombinedDPS = 3, TotalDPS = 2, AverageDamage = 1 } }
		build.calcsTab.GetMiscCalculator = function()
			return function()
				return candidateOutput
			end, baseOutput
		end
		local gemId = "Default:" .. assert(findGem("Heft")).id
		for field, expected in pairs({ FullDPS = 444, TotalDPS = 222, AverageDamage = 111 }) do
			build.skillsTab.sortGemsByDPSField = field
			control:UpdateSortCache()
			assert.is_true(control.sortCache.canSupport[gemId])
			assert.are.equals(expected, control.sortCache.dps[gemId])
		end
	end)

	it("skipEHP omits companion life work without changing damage", function()
		build.skillsTab:PasteSocketGroup("Companion: Lightless Abomination 20/0  1\nLoyalty 1/0  1")
		runCallback("OnFrame")
		build.viewMode = "SKILLS"
		local calcFunc = build.calcsTab:GetMiscCalculator()
		local fastOpts = { nodeAlloc = true, requirementsItems = true, requirementsGems = true }
		fastOpts.skipEHP = false
		local withEHP = calcFunc(nil, false, fastOpts)
		local companionLife = withEHP.TotalCompanionLife
		local totalDPS = withEHP.Minion.TotalDPS
		fastOpts.skipEHP = true
		local withoutEHP = calcFunc(nil, false, fastOpts)
		assert.is_true(companionLife > 0)
		assert.are.equals(0, withoutEHP.TotalCompanionLife or 0)
		assertClose(totalDPS, withoutEHP.Minion.TotalDPS, "minion TotalDPS")
	end)

	it("the uncached Full DPS-only path matches a full passive-node calculation", function()
		buildTwoGroups()
		local calcFunc, calcBase = build.calcsTab:GetMiscCalculator()
		local node = assert(build.spec.nodes[1755], "Spell Damage passive not found")
		local override = { addNodes = { [node] = true } }
		local slow = calcFunc(override, true)
		local fast = calcFunc(override, true, { fullDPSOnly = true, noFullDPSCache = true })
		assertClose(slow.FullDPS, fast.FullDPS, "passive override FullDPS")
		assertClose(slow.FullDotDPS, fast.FullDotDPS, "passive override FullDotDPS")
		assert.is_true(math.abs((calcBase.FullDPS or 0) - (fast.FullDPS or 0)) > 1e-6, "passive should affect FullDPS")
	end)

	it("a stale cache is not reused after the build changes when recaptured", function()
		local sparkGroup, fireballGroup = buildTwoGroups()
		local gemData = findGem("Controlled Destruction")
		local before = evaluateGem(sparkGroup, gemData)
		-- change the other group's gem and re-evaluate; evaluateGem recaptures its own base,
		-- mirroring the calculator closure being rebuilt on every build change
		fireballGroup.gemList[1].level = 1
		build.buildFlag = true
		runCallback("OnFrame")
		local cachedResult, _, freshResult = evaluateGem(sparkGroup, gemData)
		assertClose(freshResult.combinedDPS, cachedResult.combinedDPS, "combinedDPS after build change")
		assert.is_true(math.abs(before.combinedDPS - cachedResult.combinedDPS) > 1e-6, "expected combinedDPS to change after lowering Fireball's level")
	end)
end)
