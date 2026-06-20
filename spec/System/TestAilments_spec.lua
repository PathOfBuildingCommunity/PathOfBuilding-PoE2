describe("TestAilments", function()
	before_each(function()
		newBuild()
	end)

	teardown(function()
		-- newBuild() takes care of resetting everything in setup()
	end)

	--TODO: Shock not supported currently
	--it("maximum shock value", function()
	--end)

	--TODO: Shock not supported currently
	--it("bleed is buffed by bleed chance", function()
	--end)

	it("does not double count chaos damage taken for chaos poison", function()
		build.skillsTab:PasteSocketGroup("Chaos Bolt 1/0  1\nPoison I 1/0  1\n")
		runCallback("OnFrame")

		local baseEffMult = build.calcsTab.mainOutput.PoisonEffMult
		assert.True(baseEffMult and baseEffMult > 0)

		build.configTab.input.customMods = "Nearby enemies take 10% increased Chaos Damage"
		build.configTab:BuildModList()
		runCallback("OnFrame")

		assert.are.equals(1.1, build.calcsTab.mainOutput.PoisonEffMult)
	end)

	it("physical damage contributes to chill and freeze with Vestige of Darkness modifier", function()
		-- High flat physical, no cold, so any chill/freeze must come from physical
		build.itemsTab:CreateDisplayItemFromRaw([[
			New Item
			Razor Quarterstaff
			Quality: 20
			Adds 40000 to 60000 Physical Damage
		]])
		build.itemsTab:AddDisplayItem()
		runCallback("OnFrame")
		build.skillsTab:PasteSocketGroup("Quarterstaff Strike 1/0  1")
		runCallback("OnFrame")
		build.calcsTab:BuildOutput()
		runCallback("OnFrame")

		-- Baseline: physical hits cannot chill or freeze
		assert.are.equals(0, build.calcsTab.mainOutput.FreezeBuildupAvg)

		build.configTab.input.customMods = "Physical damage from Hits Contributes to Chill Magnitude and Freeze Buildup"
		build.configTab:BuildModList()
		runCallback("OnFrame")
		build.calcsTab:BuildOutput()
		runCallback("OnFrame")

		-- Physical hits now contribute to freeze buildup and chill
		assert.True(build.calcsTab.mainOutput.FreezeBuildupAvg > 0)
		assert.True((build.calcsTab.mainOutput.ChillDuration or 0) > 0)
	end)
end)
