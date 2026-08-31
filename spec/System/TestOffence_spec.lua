describe("TestOffence", function()
	before_each(function()
		newBuild()
	end)

	teardown(function()
		-- newBuild() takes care of resetting everything in setup()
	end)

	it("rounds each scaled damage conversion to a whole percent", function()
		build.skillsTab:PasteSocketGroup("Fireball 20/0  1")
		build.configTab.input.customMods = [[
		40% of Physical Damage Converted to Lightning Damage
		40% of Physical Damage Converted to Cold Damage
		40% of Physical Damage Converted to Fire Damage
		]]
		build.configTab:BuildModList()
		runCallback("OnFrame")

		local conversion = build.calcsTab.mainEnv.player.mainSkill.conversionTable.Physical
		assert.are.equals(0.33, conversion.Lightning)
		assert.are.equals(0.33, conversion.Cold)
		assert.are.equals(0.33, conversion.Fire)
		assert.is_true(math.abs(conversion.mult - 0.01) < 0.000001)
	end)

	it("keeps converted damage fractional until destination calculation", function()
		build.itemsTab:CreateDisplayItemFromRaw([[
		New Item
		Attuned Wand
		Adds 2 to 2 Physical Damage to Spells
		]])
		build.itemsTab:AddDisplayItem()
		build.skillsTab:PasteSocketGroup("Fireball 20/0  1")
		build.configTab.input.customMods = [[
		25% of Physical Damage Converted to Cold Damage
		]]
		build.configTab:BuildModList()
		runCallback("OnFrame")

		assert.are.equals(2, build.calcsTab.mainOutput.PhysicalMinBase)
		assert.are.equals(0.5, build.calcsTab.mainOutput.ColdSummedMinBase)
	end)
end)
