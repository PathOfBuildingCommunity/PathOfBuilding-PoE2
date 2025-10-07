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
		build.skillsTab:PasteSocketGroup("Quarterstaff Strike 1/0  1\nArmour Break I 1/0  1\nShock 1/0  1\nBiting Frost 1/0  1")
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
end)