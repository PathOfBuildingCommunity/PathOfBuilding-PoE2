describe("TestPyromanticPact", function()
	before_each(function()
		newBuild()
	end)

	teardown(function()
		-- newBuild() takes care of resetting everything in setup()
	end)

	local function withMods(customMods)
		build.configTab.input.customMods = customMods
		build.configTab:BuildModList()
		runCallback("OnFrame")
		return build.calcsTab.mainOutput
	end

	it("parses the Pyromantic Pact node", function()
		local node = build.spec.nodes[13174]
		assert.is_not_nil(node)
		assert.True(node.modList:Flag(nil, "ManaReplacedByInfernalFlame"))
		assert.True(node.modList:Flag(nil, "InfernalFlameInsteadOfManaCost"))
	end)

	it("replaces maximum Mana with twice as much maximum Infernal Flame", function()
		build.skillsTab:PasteSocketGroup("Fireball 20/0  1")
		local mana = withMods("").Mana
		assert.True(mana > 0)
		local output = withMods("Maximum Mana is replaced by twice as much Maximum Infernal Flame")
		assert.are.equals(0, output.Mana)
		assert.are.equals(mana * 2, output.MaximumInfernalFlame)
	end)

	it("turns Mana costs into Infernal Flame gained", function()
		build.skillsTab:PasteSocketGroup("Fireball 20/0  1")
		local manaCost = withMods("").ManaCost
		assert.True(manaCost > 0)
		local output = withMods("Gain Infernal Flame instead of spending Mana for Skill costs")
		assert.are.equals(0, output.ManaCost)
		assert.False(output.ManaHasCost)
		assert.are.equals(manaCost, output.InfernalFlameCost)
		assert.True(output.InfernalFlameHasCost)
	end)

	it("leaves Mana alone without Pyromantic Pact", function()
		build.skillsTab:PasteSocketGroup("Fireball 20/0  1")
		local output = withMods("")
		assert.is_nil(output.MaximumInfernalFlame)
		assert.is_nil(output.InfernalFlameCost)
	end)
end)
