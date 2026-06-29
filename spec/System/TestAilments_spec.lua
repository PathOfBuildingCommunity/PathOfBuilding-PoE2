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
end)
