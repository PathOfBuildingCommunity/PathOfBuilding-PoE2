describe("TestAilments", function()
	before_each(function()
		newBuild()
	end)

	teardown(function()
		-- newBuild() takes care of resetting everything in setup()
	end)

	it("does not apply hit-only damage modifiers to ignite source damage", function()
		build.skillsTab:PasteSocketGroup("Incinerate 20/0  1")
		build.configTab.input.conditionEnemyBurning = true
		build.configTab:BuildModList()
		runCallback("OnFrame")

		local baseIgniteDPS = build.calcsTab.mainOutput.IgniteDPS
		local baseAverageDamage = build.calcsTab.mainOutput.AverageDamage
		local baseFireStoredHitMin = build.calcsTab.mainOutput.FireStoredHitMin
		local baseFireStoredHitMax = build.calcsTab.mainOutput.FireStoredHitMax

		build.configTab.input.customMods = "35% increased Damage with Hits against Burning Enemies"
		build.configTab:BuildModList()
		runCallback("OnFrame")

		assert.True(build.calcsTab.mainOutput.AverageDamage > baseAverageDamage)
		assert.True(math.abs(build.calcsTab.mainOutput.IgniteDPS - baseIgniteDPS) < 0.000000001)
		assert.are.equals(baseFireStoredHitMin, build.calcsTab.mainOutput.FireStoredHitMin)
		assert.are.equals(baseFireStoredHitMax, build.calcsTab.mainOutput.FireStoredHitMax)
	end)

	--TODO: Shock not supported currently
	--it("maximum shock value", function()
	--end)

	--TODO: Shock not supported currently
	--it("bleed is buffed by bleed chance", function()
	--end)
end)
