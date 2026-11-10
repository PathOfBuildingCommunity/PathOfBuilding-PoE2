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

	it("treats a sustained ignite as permanently applied", function()
		-- Flameblast's 10 second cooldown only keeps a 4 second ignite up 40% of the time
		build.skillsTab:PasteSocketGroup("Flameblast 20/0  1\n")
		runCallback("OnFrame")

		local baseIgniteDPS = build.calcsTab.mainOutput.IgniteDPS
		assert.True(baseIgniteDPS and baseIgniteDPS > 0)
		assert.True(build.calcsTab.mainOutput.IgniteStackPotential < 1)

		build.configTab.input.conditionSustainedIgnite = true
		build.configTab:BuildModList()
		runCallback("OnFrame")

		assert.are.equals(1, build.calcsTab.mainOutput.IgniteStackPotential)
		assert.True(build.calcsTab.mainOutput.IgniteDPS > baseIgniteDPS)
	end)

	it("scales a sustained ignite with faster ignites but not with ignite duration", function()
		build.skillsTab:PasteSocketGroup("Flameblast 20/0  1\n")
		build.configTab.input.conditionSustainedIgnite = true
		build.configTab:BuildModList()
		runCallback("OnFrame")

		local sustainedIgniteDPS = build.calcsTab.mainOutput.IgniteDPS
		assert.True(sustainedIgniteDPS > 0)

		build.configTab.input.customMods = "100% increased Ignite Duration on Enemies"
		build.configTab:BuildModList()
		runCallback("OnFrame")

		assert.are.equals(sustainedIgniteDPS, build.calcsTab.mainOutput.IgniteDPS)
		assert.True(build.calcsTab.mainOutput.IgniteDuration > 4)

		build.configTab.input.customMods = "Ignites you inflict deal damage 50% faster"
		build.configTab:BuildModList()
		runCallback("OnFrame")

		assert.True(math.abs(build.calcsTab.mainOutput.IgniteDPS - sustainedIgniteDPS * 1.5) < 0.0001)
	end)
end)
