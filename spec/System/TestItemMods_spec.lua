describe("TetsItemMods", function()
	before_each(function()
		newBuild()
	end)

	teardown(function()
		-- newBuild() takes care of resetting everything in setup()
	end)

	it("Both slots mod (evasion and es mastery)", function()

		build.configTab.input.customMods = "\z
		20% increased Maximum Energy Shield if both Equipped Rings have an Evasion Modifier\n\z
		"
		build.configTab:BuildModList()
		runCallback("OnFrame")

		build.itemsTab:CreateDisplayItemFromRaw([[
			New Item
			Elementalist Robe
			Energy Shield: 116
		]])
		build.itemsTab:AddDisplayItem()
		runCallback("OnFrame")

		local baseEs = build.calcsTab.mainOutput.EnergyShield

		build.itemsTab:CreateDisplayItemFromRaw([[
			New Item
			Ring
			Implicits: 1
			+71 to Evasion Rating
			+10 to maximum life
		]])
		build.itemsTab:AddDisplayItem()
		runCallback("OnFrame")

		assert.are.equals(baseEs, build.calcsTab.mainOutput.EnergyShield) -- No change in es with just one ring.

		build.itemsTab:CreateDisplayItemFromRaw([[
			New Item
			Ring
			+71 to Evasion Rating
		]])
		build.itemsTab:AddDisplayItem()
		runCallback("OnFrame")

		assert.are_not.equals(baseEs, build.calcsTab.mainOutput.EnergyShield)
		-- Es changes after adding another ring with mod. Regardless of the evasion mod on the first ring being implicit.
	end)

	it("Both slots explicit mod with mixed mod rings (evasion and es mastery)", function()
	
		build.configTab.input.customMods = "\z
		20% increased Maximum Energy Shield if both Equipped Rings have an Explicit Evasion Modifier\n\z
		"
		build.configTab:BuildModList()
		runCallback("OnFrame")

		build.itemsTab:CreateDisplayItemFromRaw([[
			New Item
			Elementalist Robe
			Energy Shield: 116
		]])
		build.itemsTab:AddDisplayItem()
		runCallback("OnFrame")

		local baseEs = build.calcsTab.mainOutput.EnergyShield

		build.itemsTab:CreateDisplayItemFromRaw([[
			New Item
			Ring
			Implicits: 1
			+71 to Evasion Rating
			+10 to maximum life
		]])
		build.itemsTab:AddDisplayItem()
		runCallback("OnFrame")

		assert.are.equals(baseEs, build.calcsTab.mainOutput.EnergyShield) -- No change in es with just one ring.

		build.itemsTab:CreateDisplayItemFromRaw([[
			New Item
			Ring
			+71 to Evasion Rating
		]])
		build.itemsTab:AddDisplayItem()
		runCallback("OnFrame")

		assert.are.equals(baseEs, build.calcsTab.mainOutput.EnergyShield)
		-- Es does not change after adding another ring with mod due to the first ring having an implicit evasion mod.
	end)

	it("Both slots explicit mod (evasion and es mastery)", function()

		build.configTab.input.customMods = "\z
		20% increased Maximum Energy Shield if both Equipped Rings have an Explicit Evasion Modifier\n\z
		"
		build.configTab:BuildModList()
		runCallback("OnFrame")

		build.itemsTab:CreateDisplayItemFromRaw([[
			New Item
			Elementalist Robe
			Energy Shield: 116
		]])
		build.itemsTab:AddDisplayItem()
		runCallback("OnFrame")

		local baseEs = build.calcsTab.mainOutput.EnergyShield

		build.itemsTab:CreateDisplayItemFromRaw([[
			New Item
			Ring
			+71 to Evasion Rating
		]])
		build.itemsTab:AddDisplayItem()
		runCallback("OnFrame")

		assert.are.equals(baseEs, build.calcsTab.mainOutput.EnergyShield) -- No change in es with just one ring.

		build.itemsTab:CreateDisplayItemFromRaw([[
			New Item
			Ring
			+71 to Evasion Rating
		]])
		build.itemsTab:AddDisplayItem()
		runCallback("OnFrame")

		assert.are_not.equals(baseEs, build.calcsTab.mainOutput.EnergyShield)
		-- Es changes after adding two rings with explicit mods.
	end)

	it("Both slots explicit mod no rings (evasion and es mastery)", function()
		build.itemsTab:CreateDisplayItemFromRaw([[
			New Item
			Elementalist Robe
			Energy Shield: 116
		]])
		build.itemsTab:AddDisplayItem()
		runCallback("OnFrame")

		local baseEs = build.calcsTab.mainOutput.EnergyShield

		build.configTab.input.customMods = "\z
		20% increased Maximum Energy Shield if both Equipped Rings have an Explicit Evasion Modifier\n\z
		"
		build.configTab:BuildModList()
		runCallback("OnFrame")

		assert.are.equals(baseEs, build.calcsTab.mainOutput.EnergyShield) -- No change in es with no rings.

	end)

	it("mod if no mod on x slot", function()
		local baseLife = build.calcsTab.mainOutput.Life

		build.configTab.input.customMods = "\z
		15% increased maximum Life if there are no Life Modifiers on Equipped Body Armour\n\z
		"
		build.configTab:BuildModList()
		runCallback("OnFrame")

		assert.are_not.equals(baseLife, build.calcsTab.mainOutput.Life)

		baseLife = build.calcsTab.mainOutput.Life

		build.itemsTab:CreateDisplayItemFromRaw([[
			New Item
			Elementalist Robe
			Energy Shield: 116
			+95 to maximum Life
		]])
		build.itemsTab:AddDisplayItem()
		runCallback("OnFrame")

		assert.are_not.equals(baseLife, build.calcsTab.mainOutput.Life)
	end)

	it("globalLimit mods", function()
		build.configTab.input.customMods = [[
			-1000% to cold resistance
		]]
		build.configTab:BuildModList()
		build.itemsTab:CreateDisplayItemFromRaw([[Replica Nebulis
			Clasped Sceptre
			League: Heist
			Quality: 20
			Sockets: B-B-B
			LevelReq: 68
			Implicits: 1
			40% increased Elemental Damage
			{fractured}{range:1}(15-20)% increased Cast Speed
			{range:1}(15-20)% increased Cold Damage per 1% Missing Cold Resistance, up to a maximum of 300%
			{range:1}(15-20)% increased Fire Damage per 1% Missing Fire Resistance, up to a maximum of 300%]])
		build.itemsTab:AddDisplayItem()
		build.skillsTab:PasteSocketGroup("Slot: Weapon 1\nFireball 20/0 Default  1\n")
		runCallback("OnFrame")

		assert.are_not.equals(340, build.calcsTab.mainEnv.modDB:Sum("INC", "FireDamage"))
		assert.are_not.equals(340, build.calcsTab.mainEnv.modDB:Sum("INC", "ColdDamage"))

		newBuild()

		build.configTab.input.customMods = [[
			Gain 25% increased Armour per 5 Power for 8 seconds when you Warcry, up to a maximum of 100%
			Warcries have infinite Power
			warcries grant arcane surge to you and allies, with 10% increased effect per 5 power, up to 100%
		]]
		build.configTab:BuildModList()
		build.itemsTab:CreateDisplayItemFromRaw([[
			New Item
			Fur Plate
			Armour: 60
		]])
		build.itemsTab:AddDisplayItem()
		build.skillsTab:PasteSocketGroup("Arc 20/0 Default  1")

		assert.are_not.equals(20, build.calcsTab.mainEnv.modDB:Sum("MORE", { flags = ModFlag.Cast }, "Speed"))
		assert.are_not.equals(120, build.calcsTab.mainOutput.Armour)
		runCallback("OnFrame")
	end)
end)
