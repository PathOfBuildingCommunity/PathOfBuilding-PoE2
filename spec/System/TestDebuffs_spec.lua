describe("TestAilments", function()
	before_each(function()
		newBuild()
	end)

	teardown(function()
		-- newBuild() takes care of resetting everything in setup()
	end)

	it("reduces Chill and the movement penalty from Maim and Hinder", function()
		local input = build.configTab.input
		input.conditionChilled = true
		input.conditionChilledEffect = 30
		input.conditionMaimed = true
		input.conditionHindered = true
		input.customMods = "+100 to Evasion Rating\n10% reduced Movement Speed"
		build.configTab:BuildModList()
		runCallback("OnFrame")

		local output = build.calcsTab.mainOutput
		local maimedEvasion = output.Evasion
		assert.are.near(0.70, output.ActionSpeedMod, 0.001)
		assert.are.near(0.30, output.MovementSpeedMod, 0.001)

		input.customMods = input.customMods .. "\n20% reduced Slowing Potency of Debuffs on You"
		build.configTab:BuildModList()
		runCallback("OnFrame")

		output = build.calcsTab.mainOutput
		assert.are.near(0.76, output.ActionSpeedMod, 0.001)
		assert.are.near(0.42, output.MovementSpeedMod, 0.001)
		assert.are.equals(maimedEvasion, output.Evasion)
	end)

	it("only applies conditional slowing potency reduction after using a Charm", function()
		local input = build.configTab.input
		input.conditionChilled = true
		input.conditionChilledEffect = 30
		input.customMods = "20% reduced Slowing Potency of Debuffs on You if you've used a Charm Recently"
		build.configTab:BuildModList()
		runCallback("OnFrame")
		assert.are.near(0.70, build.calcsTab.mainOutput.ActionSpeedMod, 0.001)

		input.conditionUsedCharmRecently = true
		build.configTab:BuildModList()
		runCallback("OnFrame")
		assert.are.near(0.76, build.calcsTab.mainOutput.ActionSpeedMod, 0.001)
	end)

	it("adds slowing potency to Temporal Chains magnitude", function()
		local input = build.configTab.input
		input.customMods = "You are Cursed with Level 20 Temporal Chains"
		build.configTab:BuildModList()
		runCallback("OnFrame")
		local baseSlow = 1 - build.calcsTab.mainOutput.ActionSpeedMod
		assert.True(baseSlow > 0)

		input.customMods = input.customMods .. "\n20% reduced Effect of Curses on you"
		build.configTab:BuildModList()
		runCallback("OnFrame")
		local expiry = build.calcsTab.mainEnv.player.modDB:More(nil, "BuffExpireFaster")
		assert.True(expiry < 1)

		input.customMods = input.customMods .. "\n20% reduced Slowing Potency of Debuffs on You"
		build.configTab:BuildModList()
		runCallback("OnFrame")
		assert.are.near(1 - baseSlow * 0.60, build.calcsTab.mainOutput.ActionSpeedMod, 0.01)
		assert.are.equals(expiry, build.calcsTab.mainEnv.player.modDB:More(nil, "BuffExpireFaster"))
	end)

	it("correctly applies effects dependent on 'Condition:Slowed'", function()
		build.skillsTab:PasteSocketGroup("Chaos Bolt 1/0  1\n")
		runCallback("OnFrame")

		local defaultDmg = build.calcsTab.mainOutput.TotalDPS
		assert.True(defaultDmg > 0, "build should deal damage")
		
		build.configTab.input.customMods = "100% increased damage against slowed enemies"
		build.configTab:BuildModList()
		runCallback("OnFrame")
		
		-- no effect yet
		local nonSlowedDmg = build.calcsTab.mainOutput.TotalDPS
		assert.are.equals(nonSlowedDmg, defaultDmg, "damage should be unchanged until enemy is slowed")
		
		-- action speed
		build.configTab.input.customMods = [[
			100% increased damage against slowed enemies
			Nearby enemies have 10% reduced action speed
		]]
			
		build.configTab:BuildModList()
		runCallback("OnFrame")
		local actionSlowedDmg = build.calcsTab.mainOutput.TotalDPS
		assert.True(actionSlowedDmg > nonSlowedDmg, "damage should be higher vs. reduced action speed")

		-- movement speed
		build.configTab.input.customMods = [[
			100% increased damage against slowed enemies
			Nearby enemies have 10% reduced movement speed
		]]
			
		build.configTab:BuildModList()
		runCallback("OnFrame")
		local movementSlowedDmg = build.calcsTab.mainOutput.TotalDPS
		assert.True(movementSlowedDmg > nonSlowedDmg, "damage should be higher vs. reduced movement speed")

		-- specific slowing debuffs checks
		-- NOTE: there might be more conditions that should be checked here, feel free to add more
		for _, debuff in ipairs({"chilled", "maimed", "hindered"}) do
			build.configTab.input.customMods = [[
				100% increased damage against slowed enemies
				nearby enemies are ]] .. debuff .. [[
			]]
			
			build.configTab:BuildModList()
			runCallback("OnFrame")
			local debuffSlowedDmg = build.calcsTab.mainOutput.TotalDPS
			assert.True(debuffSlowedDmg > nonSlowedDmg, "damage should be higher vs. " .. debuff .. " enemies")
		end

		-- temporal chains curse
		build.configTab.input.customMods = [[
			100% increased damage against slowed enemies
		]]
		build.skillsTab:PasteSocketGroup("Temporal Chains 20/0  1\n")
		build.configTab:BuildModList()
		runCallback("OnFrame")
		local temporalChainsSlowedDmg = build.calcsTab.mainOutput.TotalDPS
		assert.True(temporalChainsSlowedDmg > nonSlowedDmg, "damage should be higher with Temporal Chains curse")
	end)
end)
