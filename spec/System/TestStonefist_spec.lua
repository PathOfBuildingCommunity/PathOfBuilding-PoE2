describe("TestStonefist", function()
	before_each(function()
		newBuild()
	end)

	teardown(function()
		-- newBuild() takes care of resetting everything in setup()
	end)

	-- ModParser: flag parsing

	it("GloveBaseTypeTransform flag is set from ascendancy mod string", function()
		build.configTab.input.customMods = "\z
		Gloves you equip have their base type transformed to fists of stone while equipped\n\z
		"
		build.configTab:BuildModList()
		runCallback("OnFrame")

		assert.is_true(build.calcsTab.mainEnv.modDB:Flag(nil, "GloveBaseTypeTransform"))
	end)

	it("IgnoreAttributeRequirementsForGloves flag is set from ascendancy mod string", function()
		build.configTab.input.customMods = "\z
		Ignore attribute requirements to equip gloves\n\z
		"
		build.configTab:BuildModList()
		runCallback("OnFrame")

		assert.is_true(build.calcsTab.mainEnv.modDB:Flag(nil, "IgnoreAttributeRequirementsForGloves"))
	end)

	it("GloveExplicitModTransform flag is set from ascendancy mod string", function()
		build.configTab.input.customMods = "\z
		their explicit modifiers are transformed into more powerful related modifiers\n\z
		"
		build.configTab:BuildModList()
		runCallback("OnFrame")

		assert.is_true(build.calcsTab.mainEnv.modDB:Flag(nil, "GloveExplicitModTransform"))
	end)

	-- CalcPerform: base type transform overwrites glove armour values

	it("GloveBaseTypeTransform: equipping pure-evasion gloves gains Armour from Fists of Stone base", function()
		-- Suede Bracers: Evasion only, no Armour stat
		build.itemsTab:CreateDisplayItemFromRaw([[
			New Item
			Suede Bracers
			Evasion: 10
		]])
		build.itemsTab:AddDisplayItem()
		runCallback("OnFrame")

		local baseArmour = build.calcsTab.mainOutput.Armour or 0

		-- Apply transform flag
		build.configTab.input.customMods = "\z
		Gloves you equip have their base type transformed to fists of stone while equipped\n\z
		"
		build.configTab:BuildModList()
		runCallback("OnFrame")

		local transformedArmour = build.calcsTab.mainOutput.Armour or 0
		-- Fists of Stone base armour is 44; should exceed the evasion-only baseline
		assert.is_true(transformedArmour > baseArmour,
			("expected transformed armour %d > base armour %d"):format(transformedArmour, baseArmour))
		assert.is_near(44, transformedArmour, 10)
	end)

	it("GloveBaseTypeTransform: armour-only gloves take on Fists of Stone armour value (~44)", function()
		-- Stocky Mitts base armour = 15; Fists of Stone base armour = 44
		build.itemsTab:CreateDisplayItemFromRaw([[
			New Item
			Stocky Mitts
		]])
		build.itemsTab:AddDisplayItem()
		runCallback("OnFrame")

		local baseArmour = build.calcsTab.mainOutput.Armour or 0

		build.configTab.input.customMods = "\z
		Gloves you equip have their base type transformed to fists of stone while equipped\n\z
		"
		build.configTab:BuildModList()
		runCallback("OnFrame")

		local transformedArmour = build.calcsTab.mainOutput.Armour or 0
		-- Armour should change from Stocky Mitts base (~15) to Fists of Stone base (~44)
		assert.are_not.equals(baseArmour, transformedArmour)
		assert.is_near(44, transformedArmour, 10)
	end)

	it("GloveBaseTypeTransform: Fists of Stone implicit injects Evasion per level into modDB", function()
		build.itemsTab:CreateDisplayItemFromRaw([[
			New Item
			Stocky Mitts
			Armour: 10
		]])
		build.itemsTab:AddDisplayItem()
		runCallback("OnFrame")

		local baseEvasion = build.calcsTab.mainOutput.Evasion or 0

		build.configTab.input.customMods = "\z
		Gloves you equip have their base type transformed to fists of stone while equipped\n\z
		"
		build.configTab:BuildModList()
		runCallback("OnFrame")

		-- Implicit: +2 Evasion per level; at level 1 that is +2, plus Fists of Stone base evasion (40)
		local transformedEvasion = build.calcsTab.mainOutput.Evasion or 0
		assert.is_true(transformedEvasion > baseEvasion,
			("expected evasion %d > base evasion %d after Fists of Stone transform"):format(transformedEvasion, baseEvasion))
	end)

	-- CalcPerform: scoped attribute requirement ignore

	it("IgnoreAttributeRequirementsForGloves does not zero global attribute requirements", function()
		-- The scoped flag should NOT zero requirements from non-glove sources
		build.configTab.input.customMods = "\z
		Ignore attribute requirements to equip gloves\n\z
		"
		build.configTab:BuildModList()
		runCallback("OnFrame")

		-- Global flag should be nil; only the scoped flag should be set
		local globalFlag = build.calcsTab.mainEnv.modDB:Flag(nil, "IgnoreAttributeRequirements")
		assert.is_falsy(globalFlag)
		assert.is_true(build.calcsTab.mainEnv.modDB:Flag(nil, "IgnoreAttributeRequirementsForGloves"))
	end)
end)
