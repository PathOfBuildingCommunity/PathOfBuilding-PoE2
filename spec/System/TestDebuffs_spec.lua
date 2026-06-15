describe("TestAilments", function()
	before_each(function()
		newBuild()
	end)

	teardown(function()
		-- newBuild() takes care of resetting everything in setup()
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
