describe("TestSkills", function()
	before_each(function()
		newBuild()
	end)

	teardown(function()
		-- newBuild() takes care of resetting everything in setup()
	end)
	
	it("Test blasphemy reserving Spirit", function()
		build.skillsTab:PasteSocketGroup("Blasphemy 20/0  1\nDespair 20/0  1\n")
		runCallback("OnFrame")

		local oneCurseReservation = build.calcsTab.mainOutput.SpiritReservedPercent
		assert.True(oneCurseReservation > 0)

		newBuild()

		build.skillsTab:PasteSocketGroup("Blasphemy 20/0  1\nDespair 20/0  1\nFlammability 20/0  1\n")
		runCallback("OnFrame")

		assert.True(build.calcsTab.mainOutput.SpiritReservedPercent > oneCurseReservation)
	end)

	it("Test cost efficiency modifiers", function()
		-- Test Mana Cost Efficiency
		build.skillsTab:PasteSocketGroup("Ball Lightning 1/0  1\n")
		runCallback("OnFrame")

		-- Get base mana cost (Ball Lightning level 1 has 9 mana cost)
		local baseCost = build.calcsTab.mainOutput.ManaCost
		assert.are.equals(9, baseCost)

		-- Add 50% mana cost efficiency (should reduce cost to 9/1.5 = 6)
		build.configTab.input.customMods = "50% increased Mana Cost Efficiency"
		build.configTab:BuildModList()
		runCallback("OnFrame")

		local reducedCost = build.calcsTab.mainOutput.ManaCost
		assert.are.equals(6, reducedCost)

		-- Test generic cost efficiency (should also affect mana)
		newBuild()
		build.skillsTab:PasteSocketGroup("Ball Lightning 1/0  1\n")
		build.configTab.input.customMods = "25% increased Cost Efficiency"
		build.configTab:BuildModList()
		runCallback("OnFrame")

		local genericEfficiencyCost = build.calcsTab.mainOutput.ManaCost
		-- Test actual behavior: 9/1.25 = 7.2 (not rounded)
		assert.True(math.abs(genericEfficiencyCost - 7.2) < 0.001)

		-- Test multiple efficiency sources stacking additively
		build.configTab.input.customMods = "25% increased Cost Efficiency\n25% increased Mana Cost Efficiency"
		build.configTab:BuildModList()
		runCallback("OnFrame")

		local stackedCost = build.calcsTab.mainOutput.ManaCost
		assert.are.equals(6, stackedCost) -- 9/(1 + 0.25 + 0.25) = 9/1.5 = 6
	end)

	it("Test cost efficiency with cost modifiers", function()
		-- Test interaction between cost efficiency and cost multipliers
		build.skillsTab:PasteSocketGroup("Ball Lightning 1/0  1\n")
		
		-- Add cost multiplier and efficiency
		build.configTab.input.customMods = "50% increased Mana Cost\n50% increased Mana Cost Efficiency"
		build.configTab:BuildModList()
		runCallback("OnFrame")

		local finalCost = build.calcsTab.mainOutput.ManaCost
		assert.True(math.abs(finalCost - 8.67) < 0.1) -- floor(9 * 1.5) / 1.5
	end)

	it("Test mana cost efficiency with support gems", function()
		-- Test interaction between cost efficiency and cost multipliers
		build.skillsTab:PasteSocketGroup("Contagion 6/0  1\nMagnified Area I 1/0  1")
		
		-- Add efficiency
		build.configTab.input.customMods = "36% increased Mana Cost Efficiency"
		build.configTab:BuildModList()
		runCallback("OnFrame")

		local finalCost = build.calcsTab.mainOutput.ManaCost
		assert.are.equals(16, round(finalCost))
	end)
end)