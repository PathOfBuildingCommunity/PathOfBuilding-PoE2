describe("TestNoMercy", function()
	before_each(function()
		newBuild()
	end)

	teardown(function()
		-- newBuild() takes care of resetting everything in setup()
	end)

	local function dpsWith(missing)
		build.configTab.input.customMods = "Deal up to 40% more Damage to Enemies based on their missing Concentration"
		build.configTab.input.multiplierEnemyMissingConcentration = missing
		build.configTab:BuildModList()
		runCallback("OnFrame")
		return build.calcsTab.mainOutput.TotalDPS
	end

	it("parses the No Mercy node", function()
		local node = build.spec.nodes[46535]
		assert.is_not_nil(node)
		local mod = node.mods[1].list[1]
		assert.is_nil(node.mods[1].extra)
		assert.are.equals("Damage", mod.name)
		assert.are.equals("MORE", mod.type)
		assert.are.equals("EnemyMissingConcentrationPercent", mod[1].var)
	end)

	it("scales with the enemy's missing Concentration", function()
		build.skillsTab:PasteSocketGroup("Fireball 20/0  1")
		local base = dpsWith(0)
		assert.True(base > 0)
		assert.is_true(math.abs(dpsWith(50) - base * 1.2) < 0.01)
		assert.is_true(math.abs(dpsWith(100) - base * 1.4) < 0.01)
	end)

	it("caps at 100% missing Concentration", function()
		build.skillsTab:PasteSocketGroup("Fireball 20/0  1")
		local base = dpsWith(0)
		assert.is_true(math.abs(dpsWith(250) - base * 1.4) < 0.01)
	end)
end)
