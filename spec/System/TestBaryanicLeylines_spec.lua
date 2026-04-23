describe("BaryanicLeylines", function()
	before_each(function()
		newBuild()
	end)

	teardown(function()
		-- newBuild() takes care of resetting everything in setup()
	end)

	it("parses Non-Unique Time-Lost Jewel radius modifier", function()
		build.configTab.input.customMods = "\z
		Non-Unique Time-Lost Jewels have 40% increased radius\n\z
		"
		build.configTab:BuildModList()
		runCallback("OnFrame")

		assert.are.equals(40, build.calcsTab.mainEnv.modDB:Sum("INC", nil, "NonUniqueTimeLostJewelRadius"))
	end)

	it("resolveTimeLostRadiusIndex returns upgraded tier at 40% and falls back otherwise", function()
		-- Each base tier (Small..Very Large) maps to a +40% counterpart whose outer
		-- radius is base * 1.4 (Small 1000 -> 1400).
		assert.are.equals(1400, data.jewelRadius[data.resolveTimeLostRadiusIndex(1, 40)].outer)
		assert.are.equals(1610, data.jewelRadius[data.resolveTimeLostRadiusIndex(2, 40)].outer)
		assert.are.equals(1820, data.jewelRadius[data.resolveTimeLostRadiusIndex(3, 40)].outer)
		assert.are.equals(2100, data.jewelRadius[data.resolveTimeLostRadiusIndex(4, 40)].outer)

		-- No upgrade tier exists below 40%, so the base index is returned unchanged.
		assert.are.equals(1, data.resolveTimeLostRadiusIndex(1, 0))
		assert.are.equals(1, data.resolveTimeLostRadiusIndex(1, 39))
		assert.are.equals(1, data.resolveTimeLostRadiusIndex(1, nil))
	end)
end)
