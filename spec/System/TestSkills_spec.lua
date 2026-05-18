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

	it("Consumed Charge Effect", function()
		build.itemsTab:CreateDisplayItemFromRaw([[
			New Item
			Warmonger Bow
		]])
		build.itemsTab:AddDisplayItem()
		runCallback("OnFrame")
		build.skillsTab:PasteSocketGroup("Spiral Volley 20/0  1")
		runCallback("OnFrame")
		build.configTab.input.useFrenzyCharges = true
		build.configTab.input.overrideFrenzyCharges = 1
		build.configTab:BuildModList()
		runCallback("OnFrame")
		local baseTotalDPS = build.calcsTab.mainOutput.TotalDPS
		build.configTab.input.customMods = "Benefits from consuming Frenzy Charges for your Skills have 50% chance to be doubled"
		build.configTab:BuildModList()
		runCallback("OnFrame")

		local thrillingChaseTotalDPS = build.calcsTab.mainOutput.TotalDPS
		assert.True(baseTotalDPS < thrillingChaseTotalDPS)
		assert.are.equals(50, build.calcsTab.mainEnv.modDB:Sum("BASE", nil, "Multiplier:ConsumedFrenzyChargeEffect"))


		newBuild()
		build.itemsTab:CreateDisplayItemFromRaw([[
			New Item
			Warmonger Bow
		]])
		build.itemsTab:AddDisplayItem()
		runCallback("OnFrame")
		build.skillsTab:PasteSocketGroup("Spiral Volley 20/0  1\nHeightened Charges 1/0 1")
		runCallback("OnFrame")
		build.configTab.input.useFrenzyCharges = true
		build.configTab.input.overrideFrenzyCharges = 1
		build.configTab:BuildModList()
		runCallback("OnFrame")
		local heightenedChargesTotalDPS = build.calcsTab.mainOutput.TotalDPS
		assert.True(baseTotalDPS < heightenedChargesTotalDPS)
		assert.are.equals(20, build.calcsTab.calcsEnv.player.activeSkillList[1].skillModList:GetMultiplier("ConsumedFrenzyChargeEffect", build.calcsTab.calcsEnv.player.activeSkillList[1].skillCfg))

		build.configTab.input.customMods = "Benefits from consuming Frenzy Charges for your Skills have 50% chance to be doubled"
		build.configTab:BuildModList()
		runCallback("OnFrame")
		-- thrilling and heightened charges > thrilling
		assert.True(thrillingChaseTotalDPS < build.calcsTab.mainOutput.TotalDPS)
		assert.are.equals(70, build.calcsTab.calcsEnv.player.activeSkillList[1].skillModList:GetMultiplier("ConsumedFrenzyChargeEffect", build.calcsTab.calcsEnv.player.activeSkillList[1].skillCfg))
	end)

	it("Test 'every rage also grants you' for minion mods and minion apply to you mods #run", function()
		build.itemsTab:CreateDisplayItemFromRaw([[
			New Item
			Fanatic Greathammer
			Quality: 0
		]])
		build.itemsTab:AddDisplayItem()
		runCallback("OnFrame")

		build.skillsTab:PasteSocketGroup("Unearth 20/0  1")
		build.skillsTab:PasteSocketGroup("Leap Slam 20/0  1\nRage I 1/0  1")
		runCallback("OnFrame")

		local baseUnearthAttackSpeed = build.calcsTab.mainOutput.Minion.Speed

		build.configTab.input.customMods = "Every Rage also grants you 1% increased Minion Attack Speed"
		build.configTab.input.multiplierRage = 30
		build.configTab:BuildModList()
		runCallback("OnFrame")

		assert.True(baseUnearthAttackSpeed < build.calcsTab.mainOutput.Minion.Speed)

		newBuild()
		build.itemsTab:CreateDisplayItemFromRaw([[
			Rarity: UNIQUE
			Chober Chaber
			Leaden Greathammer
			Variant: Pre 0.1.1
			Variant: Current
			Selected Variant: 2
			Quality: 20
			LevelReq: 33
			Implicits: 0
			+100 Intelligence Requirement
			{variant:1}{range:0.5}(80-120)% increased Physical Damage
			{variant:2}{range:0.5}Adds (58-65) to (102-110) Physical Damage
			{range:0.5}+(80-100) to maximum Mana
			{variant:2}+50 to Spirit
			{variant:1}+5% to Critical Hit Chance
			Increases and Reductions to Minion Damage also affect you
		]])
		build.itemsTab:AddDisplayItem()
		runCallback("OnFrame")

		build.skillsTab:PasteSocketGroup("Leap Slam 20/0  1\nRage I 1/0  1")
		runCallback("OnFrame")

		build.configTab.input.multiplierRage = 30
		build.configTab:BuildModList()
		runCallback("OnFrame")

		local baseLeapSlamHit = build.calcsTab.mainOutput.AverageDamage

		build.configTab.input.customMods = "Every Rage also grants you 1% increased Minion Damage"
		build.configTab:BuildModList()
		runCallback("OnFrame")

		assert.True(baseLeapSlamHit < build.calcsTab.mainOutput.AverageDamage)
	end)

	it("Test stacking persistent buff supports of same category", function()
		build.skillsTab:PasteSocketGroup("Arctic Armour 20/0  1\nClarity I 1/0  1")
		build.skillsTab:PasteSocketGroup("Time of Need 20/0  1\nClarity II 1/0  1")
		runCallback("OnFrame")
		assert.are.equals(build.calcsTab.calcsOutput.BuffList, "Clarity I, Clarity II")

		newBuild()
		build.skillsTab:PasteSocketGroup("Arctic Armour 20/0  1\nClarity I 1/0  1\nClarity II 1/0 1")
		build.skillsTab:PasteSocketGroup("Time of Need 20/0  1\nClarity II 1/0  1")
		runCallback("OnFrame")
		assert.are.equals(build.calcsTab.calcsOutput.BuffList, "Clarity II")

		newBuild()
		build.skillsTab:PasteSocketGroup("Arctic Armour 20/0  1\nClarity II 1/0  1")
		build.skillsTab:PasteSocketGroup("Time of Need 20/0  1\nClarity II 1/0  1")
		runCallback("OnFrame")
		assert.are.equals(build.calcsTab.calcsOutput.BuffList, "Clarity II")
	end)
end)