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
end)