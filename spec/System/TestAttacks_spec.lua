describe("TestAttacks", function()
	before_each(function()
		newBuild()
	end)

	teardown(function()
		-- newBuild() takes care of resetting everything in setup()
	end)

	it("creates an item and has the correct crit chance", function()
		assert.are.equals(build.calcsTab.mainOutput.CritChance, data.unarmedWeaponData[0].CritChance * build.calcsTab.mainOutput.HitChance / 100)
		build.itemsTab:CreateDisplayItemFromRaw([[
			New Item
			Heavy Bow
		]])
		build.itemsTab:AddDisplayItem()
		runCallback("OnFrame")
		assert.are.equals(build.calcsTab.mainOutput.CritChance, 5 * build.calcsTab.mainOutput.HitChance / 100)
	end)

	it("creates an item and has the correct crit multi", function()
		assert.are.equals(2, build.calcsTab.mainOutput.CritMultiplier)
		build.itemsTab:CreateDisplayItemFromRaw([[
			New Item
			Heavy Bow
			25% increased Critical Damage Bonus
		]])
		build.itemsTab:AddDisplayItem()
		runCallback("OnFrame")
		assert.are.equals(2 + 0.25, build.calcsTab.mainOutput.CritMultiplier)
	end)

	it("correctly converts spell damage per stat to attack damage", function()
		assert.are.equals(0, build.calcsTab.mainEnv.player.modDB:Sum("INC", { flags = ModFlag.Attack }, "Damage"))
		build.itemsTab:CreateDisplayItemFromRaw([[
		New Item
		Ring
		10% increased attack damage
		10% increased spell damage
		+20 to Intelligence
		1% increased spell damage per 10 intelligence
		]])
		build.itemsTab:AddDisplayItem()
		runCallback("OnFrame")
		assert.are.equals(10, build.calcsTab.mainEnv.player.modDB:Sum("INC", { flags = ModFlag.Attack }, "Damage"))
		-- Scion starts with 20 Intelligence
		assert.are.equals(12, build.calcsTab.mainEnv.player.modDB:Sum("INC", { flags = ModFlag.Spell }, "Damage"))

		build.itemsTab:CreateDisplayItemFromRaw([[
		New Item
		Ring
		increases and reductions to spell damage also apply to attacks
		]])
		build.itemsTab:AddDisplayItem()
		runCallback("OnFrame")
		assert.are.equals(22, build.calcsTab.mainEnv.player.mainSkill.skillModList:Sum("INC", { flags = ModFlag.Attack }, "Damage"))
	end)


	local integratedEfficiencyLoadout = function(modLine)
		-- Activate via custom mod text to simplify testing
		build.configTab.input.customMods = modLine
		build.configTab:BuildModList()
		runCallback("OnFrame")

		build.itemsTab:CreateDisplayItemFromRaw([[
			New Item
			Razor Quarterstaff
			Quality: 0
		]])
		build.itemsTab:AddDisplayItem()
		runCallback("OnFrame")
		-- Add 2 skills with 1 red, 1 blue, 1 green support each
		-- Test against Quarterstaff Strike (skill slot 1)
		build.skillsTab:PasteSocketGroup("Quarterstaff Strike 1/0  1\nArmour Break I 1/0  1\nShock 1/0  1\nBiting Frost I 1/0  1")
		runCallback("OnFrame")
		build.skillsTab:PasteSocketGroup("Falling Thunder 1/0  1\nIgnite I 1/0  1\nDaze 1/0  1\nShock Conduction 1/0  1")
		runCallback("OnFrame")

		build.configTab:BuildModList()
		runCallback("OnFrame")
		build.calcsTab:BuildOutput()
		runCallback("OnFrame")
	end
	it("correctly calculates increased damage with gemling integrated efficiency", function()
		integratedEfficiencyLoadout("skills deal 99% increased damage per connected red support gem")
		local incDmg = build.calcsTab.mainEnv.player.activeSkillList[1].skillModList:Sum("INC", nil, "Damage")
		assert.are.equals(incDmg, 99)
	end)

	it("correctly calculates crit chance with gemling integrated efficiency", function()
		integratedEfficiencyLoadout("skills have 99% increased critical hit chance per connected blue support gem")
		local incCritChance = build.calcsTab.mainEnv.player.activeSkillList[1].skillModList:Sum("INC", nil, "CritChance")
		assert.are.equals(incCritChance, 99)
	end)

	it("correctly calculates increased skill speed with gemling integrated efficiency", function()
		integratedEfficiencyLoadout("skills have 99% increased skill speed per connected green support gem")
		local incSpeed = build.calcsTab.mainEnv.player.activeSkillList[1].skillModList:Sum("INC", nil, "Speed")
		assert.are.equals(incSpeed, 99)
	end)

	it("correctly calculates critical hit damage", function()
		-- Setup: Add weapon with no crit chance, and strip enemy defenses
		--   changing enemy mods seems to get overwritten when mods are calculated, so it's easiest to just strip their defenses here
		build.itemsTab:CreateDisplayItemFromRaw([[
			New Item
			Heavy Bow
			-100% increased critical hit chance
			nearby enemies have 100% less armour
			nearby enemies have 100% less evasion
		]])
		build.itemsTab:AddDisplayItem()
		runCallback("OnFrame")
		build.calcsTab:BuildOutput()
		runCallback("OnFrame")

		-- 1: Get base damage with no crits
		local critChance = 0
		local critMult = 2
		assert.are.equals(critChance, build.calcsTab.mainOutput.CritChance)
		assert.are.equals(critMult, build.calcsTab.mainOutput.CritMultiplier)

		local averageHit = build.calcsTab.mainOutput.MainHand.AverageHit

		-- 2: Add crits and validate crit damage
		build.configTab.input.customMods = "+10% to critical hit chance"
		build.configTab:BuildModList()
		runCallback("OnFrame")
		build.calcsTab:BuildOutput()
		runCallback("OnFrame")

		local critChance = build.calcsTab.mainOutput.CritChance / 100
		local newAvgHit = (1 - critChance) * averageHit + critChance * averageHit * critMult
		assert.are.equals(newAvgHit, build.calcsTab.mainOutput.MainHand.AverageHit)
	end)

	it("correctly calculates critical hit damage with static values", function()
		-- Setup: Create a 1 damage weapon with no crit chance, and strip enemy defenses
		build.itemsTab:CreateDisplayItemFromRaw([[
			New Item
			Heavy Bow
			Quality: 0
			-100% increased critical hit chance
			-100% increased physical damage
			adds 1 to 1 physical damage to attacks
			nearby enemies have 100% less armour
			nearby enemies have 100% less evasion
		]])
		build.itemsTab:AddDisplayItem()
		runCallback("OnFrame")
		build.calcsTab:BuildOutput()
		runCallback("OnFrame")

		-- 1: Validate base damage = 1
		assert.are.equals(0, build.calcsTab.mainOutput.MainHand.CritChance)
		assert.are.equals(2, build.calcsTab.mainOutput.CritMultiplier)
		assert.are.equals(1, build.calcsTab.mainOutput.MainHand.AverageHit)

		-- 2: Add crits and validate new damage = 1.1 (for a 10% crit chance)
		build.configTab.input.customMods = "+10% to critical hit chance"
		build.configTab:BuildModList()
		runCallback("OnFrame")
		build.calcsTab:BuildOutput()
		runCallback("OnFrame")

		assert.are.equals(1.1, build.calcsTab.mainOutput.MainHand.AverageHit)
	end)

	it("correctly adds damage with oracle forced outcome", function()
		-- Setup: Add weapon with no crit chance, and strip enemy defenses
		build.itemsTab:CreateDisplayItemFromRaw([[
			New Item
			Heavy Bow
			-100% increased Critical Hit Chance
			nearby enemies have 100% less armour
			nearby enemies have 100% less evasion
		]])
		build.itemsTab:AddDisplayItem()
		runCallback("OnFrame")
		build.calcsTab:BuildOutput()
		runCallback("OnFrame")

		-- 1: Get base damage with no crits
		local critChance = 0.0
		local critMult = 2
		assert.are.equals(critChance, build.calcsTab.mainOutput.CritChance)
		assert.are.equals(critMult, build.calcsTab.mainOutput.CritMultiplier)

		local averageHit = build.calcsTab.mainOutput.MainHand.AverageHit

		-- 2: Add crits and forced outcome, and validate damage
		build.configTab.input.customMods = [[
			+10% to critical hit chance
			inevitable critical hits
		]]
		build.configTab:BuildModList()
		runCallback("OnFrame")
		build.calcsTab:BuildOutput()
		runCallback("OnFrame")

		critChance = 0.1
		local nonCritChance = 1 - critChance

		local critBonusMultiplier =
			1 * critChance
			+ .7 * nonCritChance * critChance
			+ .4 * nonCritChance * nonCritChance * critChance
			+ .1 * nonCritChance * nonCritChance * nonCritChance * critChance

		-- When adding them as MORE mods, they get auto rounded after *100, so we need to do the same
		critBonusMultiplier = math.floor(critBonusMultiplier * 100 + 0.5)/100

		local critBonus = critMult - 1
		critBonus = critBonus * critBonusMultiplier
		critMult = 1 + critBonus

		local forcedExpectedAvgHit = averageHit * critMult
		assert.are.equals(forcedExpectedAvgHit, build.calcsTab.mainOutput.MainHand.AverageHit)
	end)

	it("does not force critical hits when critical hit chance is zero", function()
		build.itemsTab:CreateDisplayItemFromRaw([[
			New Item
			Heavy Bow
			Quality: 0
			-100% increased critical hit chance
			-100% increased physical damage
			adds 1 to 1 physical damage to attacks
			nearby enemies have 100% less armour
			nearby enemies have 100% less evasion
		]])
		build.itemsTab:AddDisplayItem()
		runCallback("OnFrame")

		build.configTab.input.customMods = "inevitable critical hits"
		build.configTab:BuildModList()
		runCallback("OnFrame")
		build.calcsTab:BuildOutput()
		runCallback("OnFrame")

		assert.are.equals(0, build.calcsTab.mainOutput.MainHand.CritChance)
		assert.are.equals(1, build.calcsTab.mainOutput.MainHand.AverageHit)
	end)

	it("correctly calculates forced outcome with bifurcated critical hits", function()
		build.itemsTab:CreateDisplayItemFromRaw([[
			New Item
			Heavy Bow
			Quality: 0
			-100% increased critical hit chance
			-100% increased physical damage
			adds 1 to 1 physical damage to attacks
			nearby enemies have 100% less armour
			nearby enemies have 100% less evasion
		]])
		build.itemsTab:AddDisplayItem()
		runCallback("OnFrame")

		build.configTab.input.customMods = [[
			+10% to critical hit chance
			inevitable critical hits
			bifurcates critical hits
		]]
		build.configTab:BuildModList()
		runCallback("OnFrame")
		build.calcsTab:BuildOutput()
		runCallback("OnFrame")

		local critChance = 0.1
		local failedStageChance = (1 - critChance) ^ 2
		local critBonusMultiplier = 2 * critChance * (
			1
			+ .7 * failedStageChance
			+ .4 * failedStageChance ^ 2
			+ .1 * failedStageChance ^ 3
		)
		critBonusMultiplier = math.floor(critBonusMultiplier * 100 + 0.5) / 100

		assert.are.equals(100, build.calcsTab.mainOutput.MainHand.CritChance)
		local bifurcateChance = (critChance * 100) ^ 2 / ((1 - failedStageChance) * 100)
		assert.is_true(math.abs(bifurcateChance - build.calcsTab.mainOutput.MainHand.CritBifurcates) < 0.000001)
		assert.are.equals(1 + critBonusMultiplier, build.calcsTab.mainOutput.MainHand.AverageHit)
	end)

	-- Dual Wield tests
	local setupDualWieldTestConditions = function()
		local slowHighDmgMace = [[  
			Slow High Crit High Damage Mace
			Marauding Mace
			Quality: 0
			200% increased physical damage
			100% increased critical hit chance
			-25% increased attack speed
		]]

		local fastLowDmgMace = [[  
			Fast Low Crit Low Damage Mace
			Marauding Mace
			Quality: 0
			-50% increased physical damage
			-100% increased critical hit chance
			50% increased attack speed
		]]
		
		build.itemsTab:CreateDisplayItemFromRaw(slowHighDmgMace)
		build.itemsTab:AddDisplayItem()
		runCallback("OnFrame")
		build.itemsTab.slots["Weapon 1"]:SetSelItemId(build.itemsTab.items[1].id)

		build.itemsTab:CreateDisplayItemFromRaw(fastLowDmgMace)
		build.itemsTab:AddDisplayItem()
		runCallback("OnFrame")
		build.itemsTab.slots["Weapon 2"]:SetSelItemId(build.itemsTab.items[2].id)

		build.configTab.input.customMods = [[
			nearby enemies have 100% less armour
			your hits can't be evaded
		]]
		build.configTab:BuildModList()
		runCallback("OnFrame")
	end

	local function harmonicMean(a, b)
		return 2 / (1/a + 1/b)
	end
	
	it("correctly calculates dual wield DPS for double hits", function()
		setupDualWieldTestConditions()
		build.skillsTab:PasteSocketGroup("skillId:MeleeMaceMacePlayer Mace Strike 20/0  1")
		runCallback("OnFrame")
		build.calcsTab:BuildOutput()
		runCallback("OnFrame")

		-- Attack Speed
		local mainHandSpeed = build.calcsTab.mainOutput.MainHand.Speed
		local offHandSpeed = build.calcsTab.mainOutput.OffHand.Speed
		local combinedSpeed = harmonicMean(mainHandSpeed, offHandSpeed)
		assert.are.equals(round(combinedSpeed, 4), round(build.calcsTab.mainOutput.Speed, 4))

		-- Average Hit
		local mainHandAvgDmg = build.calcsTab.mainOutput.MainHand.AverageDamage
		local offHandAvgDmg = build.calcsTab.mainOutput.OffHand.AverageDamage
		local combinedAvgDmg = build.calcsTab.mainOutput.AverageDamage
		assert.are.equals(round((mainHandAvgDmg + offHandAvgDmg) / 2, 4), round(combinedAvgDmg, 4))

		-- DPS (hits twice per attack)
		local combinedDPS = build.calcsTab.mainOutput.TotalDPS
		assert.are.equals(round(combinedAvgDmg * combinedSpeed * 2,4), round(combinedDPS,4))
	end)

	it("correctly calculates dual wield crit chance for double hits", function()
		setupDualWieldTestConditions()
		build.skillsTab:PasteSocketGroup("skillId:MeleeMaceMacePlayer Mace Strike 20/0  1")
		runCallback("OnFrame")
		build.calcsTab:BuildOutput()
		runCallback("OnFrame")

		-- Double hits roll crit individually per weapon, so should be average
		local mainHandCritChance = build.calcsTab.mainOutput.MainHand.CritChance
		local offHandCritChance = build.calcsTab.mainOutput.OffHand.CritChance
		local combinedCritChance = (mainHandCritChance + offHandCritChance) / 2
		assert.are.equals(combinedCritChance, build.calcsTab.mainOutput.CritChance)
	end)

	it("correctly calculates dual wield DPS for alternating hits", function()
		setupDualWieldTestConditions()
		build.skillsTab:PasteSocketGroup("Armour Breaker 20/0  1")
		runCallback("OnFrame")
		build.calcsTab:BuildOutput()
		runCallback("OnFrame")

		-- Attack Speed
		local mainHandSpeed = build.calcsTab.mainOutput.MainHand.Speed
		local offHandSpeed = build.calcsTab.mainOutput.OffHand.Speed
		local combinedSpeed = harmonicMean(mainHandSpeed, offHandSpeed)
		assert.are.equals(round(combinedSpeed, 4), round(build.calcsTab.mainOutput.Speed, 4))

		-- Average Hit
		local mainHandAvgDmg = build.calcsTab.mainOutput.MainHand.AverageDamage
		local offHandAvgDmg = build.calcsTab.mainOutput.OffHand.AverageDamage
		local combinedAvgDmg = build.calcsTab.mainOutput.AverageDamage
		assert.are.equals(round((mainHandAvgDmg + offHandAvgDmg) / 2, 4), round(combinedAvgDmg, 4))

		-- DPS (hits once per attack)
		local combinedDPS = build.calcsTab.mainOutput.TotalDPS
		assert.are.equals(round(combinedAvgDmg * combinedSpeed, 4), round(combinedDPS, 4))
	end)

	it("correctly calculates dual wield crit chance for alternating hits", function()
		setupDualWieldTestConditions()
		build.skillsTab:PasteSocketGroup("Armour Breaker 20/0  1")
		runCallback("OnFrame")
		build.calcsTab:BuildOutput()
		runCallback("OnFrame")

		-- Alternating hits roll crit individually per weapon, so should be average
		local mainHandCritChance = build.calcsTab.mainOutput.MainHand.CritChance
		local offHandCritChance = build.calcsTab.mainOutput.OffHand.CritChance
		local combinedCritChance = (mainHandCritChance + offHandCritChance) / 2
		assert.are.equals(combinedCritChance, build.calcsTab.mainOutput.CritChance)
	end)

	--[[
		NOTE: the following section contains tests for "combined hits", which PoE2 doesn't have as of 2026-06-02,
		which means the tests were written for a temporary test skill that will not be committed.
		The test can be updated by simply replacing `"skillId:MeleeMaceMacePlayerCombinedTEST Mace Strike TEST 20/0  1"`
		with actual skill data once available
	]]
	--[[ it("correctly calculates dual wield DPS for combined hits", function()
		setupDualWieldTestConditions()
		build.skillsTab:PasteSocketGroup("skillId:MeleeMaceMacePlayerCombinedTEST Mace Strike TEST 20/0  1")
		runCallback("OnFrame")
		build.calcsTab:BuildOutput()
		runCallback("OnFrame")

		-- Attack Speed
		local mainHandSpeed = build.calcsTab.mainOutput.MainHand.Speed
		local offHandSpeed = build.calcsTab.mainOutput.OffHand.Speed
		local combinedSpeed = harmonicMean(mainHandSpeed, offHandSpeed)
		assert.are.equals(round(combinedSpeed, 4), round(build.calcsTab.mainOutput.Speed, 4))

		-- Average Hit
		local mainHandAvgDmg = build.calcsTab.mainOutput.MainHand.AverageDamage
		local offHandAvgDmg = build.calcsTab.mainOutput.OffHand.AverageDamage
		local combinedAvgDmg = build.calcsTab.mainOutput.AverageDamage
		assert.are.equals(round((mainHandAvgDmg + offHandAvgDmg), 4), round(combinedAvgDmg, 4))

		-- DPS (hits twice per attack)
		local combinedDPS = build.calcsTab.mainOutput.TotalDPS
		assert.are.equals(round(combinedAvgDmg * combinedSpeed, 4), round(combinedDPS,4))
	end)

	it("correctly calculates dual wield crit chance for combined hits", function()
		setupDualWieldTestConditions()
		build.skillsTab:PasteSocketGroup("skillId:MeleeMaceMacePlayerCombinedTEST Mace Strike TEST 20/0  1")
		runCallback("OnFrame")
		build.calcsTab:BuildOutput()
		runCallback("OnFrame")

		-- combined hits count whole attack as crit, as long as one hand rolls crit)
		local mainHandCritChance = build.calcsTab.mainOutput.MainHand.CritChance
		local offHandCritChance = build.calcsTab.mainOutput.OffHand.CritChance
		local combinedCritChance = mainHandCritChance + offHandCritChance - (mainHandCritChance * offHandCritChance / 100)
		assert.are.equals(combinedCritChance, build.calcsTab.mainOutput.CritChance)
	end) ]]
end)
