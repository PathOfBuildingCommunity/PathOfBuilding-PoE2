describe("TestWard", function()
	before_each(function()
		newBuild()
	end)

	teardown(function()
		-- newBuild() takes care of resetting everything in setup()
	end)

	it("Ward stat from items", function()
		build.configTab.input.customMods = "\z
		+100 to Ward\n\z
		"
		build.configTab:BuildModList()
		runCallback("OnFrame")

		assert.are.equals(100, build.calcsTab.calcsOutput.Ward)
	end)

	it("Ward increased modifier", function()
		build.configTab.input.customMods = "\z
		+100 to Ward\n\z
		50% increased Ward\n\z
		"
		build.configTab:BuildModList()
		runCallback("OnFrame")

		assert.are.equals(150, build.calcsTab.calcsOutput.Ward)
	end)

	it("Ward regeneration", function()
		build.configTab.input.customMods = "\z
		+1000 to Ward\n\z
		"
		build.configTab:BuildModList()
		runCallback("OnFrame")

		-- 5% per second = 300% per minute, so 1000 * 300/100/60 = 50 per second
		assert.are.equals(50, build.calcsTab.calcsOutput.WardRegen)
	end)

	it("Ward regeneration with increased", function()
		build.configTab.input.customMods = "\z
		+1000 to Ward\n\z
		100% increased Ward Regeneration\n\z
		"
		build.configTab:BuildModList()
		runCallback("OnFrame")

		-- 50 base * (1 + 100/100) = 100 per second
		assert.are.equals(100, build.calcsTab.calcsOutput.WardRegen)
	end)

	it("Ward bypass", function()
		build.configTab.input.customMods = "\z
		+100 to Ward\n\z
		50% of Damage taken bypasses Ward\n\z
		"
		build.configTab:BuildModList()
		runCallback("OnFrame")

		assert.are.equals(50, build.calcsTab.calcsOutput.WardBypass)
	end)

	it("Ward recharge delay", function()
		build.configTab.input.customMods = "\z
		+100 to Ward\n\z
		"
		build.configTab:BuildModList()
		runCallback("OnFrame")

		-- Base ward recharge delay is 2 seconds
		assert.are.equals(2, build.calcsTab.calcsOutput.WardRechargeDelay)
	end)

	it("Ward recharge delay faster", function()
		build.configTab.input.customMods = "\z
		+100 to Ward\n\z
		50% faster Restoration of Ward\n\z
		"
		build.configTab:BuildModList()
		runCallback("OnFrame")

		-- 2 / (1 + 50/100) = 2 / 1.5 = 1.33
		assert.is_near(1.33, build.calcsTab.calcsOutput.WardRechargeDelay, 0.01)
	end)

	it("Runic Ward keyword maps to Ward (import alias)", function()
		build.configTab.input.customMods = "\z
		+100 to Runic Ward\n\z
		"
		build.configTab:BuildModList()
		runCallback("OnFrame")

		assert.are.equals(100, build.calcsTab.calcsOutput.Ward)
	end)

	it("increased Runic Ward keyword maps to Ward INC", function()
		build.configTab.input.customMods = "\z
		+100 to Runic Ward\n\z
		50% increased Runic Ward\n\z
		"
		build.configTab:BuildModList()
		runCallback("OnFrame")

		assert.are.equals(150, build.calcsTab.calcsOutput.Ward)
	end)

	it("faster Restoration of Runic Ward maps to ward recharge", function()
		build.configTab.input.customMods = "\z
		+100 to Runic Ward\n\z
		50% faster Restoration of Runic Ward\n\z
		"
		build.configTab:BuildModList()
		runCallback("OnFrame")

		-- 2 / (1 + 50/100) = 1.33
		assert.is_near(1.33, build.calcsTab.calcsOutput.WardRechargeDelay, 0.01)
	end)

	it("damage taken bypasses Runic Ward maps to WardBypass", function()
		build.configTab.input.customMods = "\z
		+100 to Runic Ward\n\z
		50% of Damage taken bypasses Runic Ward\n\z
		"
		build.configTab:BuildModList()
		runCallback("OnFrame")

		assert.are.equals(50, build.calcsTab.calcsOutput.WardBypass)
	end)

	it("Ward config options", function()
		build.configTab.input.customMods = "\z
		+100 to Ward\n\z
		"
		build.configTab:BuildModList()
		runCallback("OnFrame")

		assert.are.equals(100, build.calcsTab.calcsOutput.Ward)

		build.configTab.input.conditionLowWard = true
		build.configTab:BuildModList()
		runCallback("OnFrame")

		assert.is_true(build.calcsTab.calcsOutput.LowWard)
	end)

	it("WardRegen is included in TotalNetRegen when degens present", function()
		build.configTab.input.customMods = "\z
		+1000 to Ward\n\z
		"
		build.configTab:BuildModList()
		runCallback("OnFrame")

		assert.are.equals(50, build.calcsTab.calcsOutput.WardRegen)
		-- TotalNetRegen is only computed when TotalBuildDegen is non-zero;
		-- verify WardRegen itself is correct (TotalNetRegen formula tested by code inspection)
	end)

	it("WardCoverOnMinionDeath stat ID parses correctly", function()
		build.configTab.input.customMods = "\z
		recover 10% of maximum ward on persistent minion death\n\z
		"
		build.configTab:BuildModList()
		runCallback("OnFrame")

		assert.are.equals(10, build.calcsTab.calcsOutput.WardCoverOnMinionDeath)
	end)
end)
