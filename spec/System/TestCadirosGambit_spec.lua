describe("Cadiro's Gambit", function()
	local function equipCadirosGambit()
		build.itemsTab:CreateDisplayItemFromRaw([[
			Rarity: Unique
			Cadiro's Gambit
			Primed Quiver
			Implicits: 1
			10% increased Attack Speed
			Each Arrow fired is a Crescendo, Splinter, Reversing, Diamond, Covetous, or Blunt Arrow
		]])

		local item = build.itemsTab.displayItem
		build.itemsTab:AddDisplayItem(true)
		build.itemsTab:EquipItemInSet(item, build.itemsTab.activeItemSetId)
		return item
	end

	local function setupSkill(skillName)
		build.itemsTab:CreateDisplayItemFromRaw([[
			New Item
			Crude Bow
			Quality: 0
		]])
		build.itemsTab:AddDisplayItem()
		build.skillsTab:PasteSocketGroup(skillName .. " 1/0  1")
	end

	local arrowConditions = {
		"PerandusArrowCrescendo",
		"PerandusArrowSplinter",
		"PerandusArrowReversing",
		"PerandusArrowDiamond",
		"PerandusArrowCovetous",
		"PerandusArrowBlunt",
	}

	local function selectArrow(condition)
		build.configTab.input.cadirosGambitArrow = condition
		build.configTab:BuildModList()
		runCallback("OnFrame")
	end

	before_each(function()
		newBuild()
		runCallback("OnFrame")
	end)

	it("only shows its arrow selector while equipped", function()
		setupSkill("Shockchain Arrow")
		runCallback("OnFrame")

		local control = build.configTab.varControls.cadirosGambitArrow
		assert.is_not_nil(control)
		assert.is_false(control.shown())
		assert.are.equals("NONE", build.configTab.input.cadirosGambitArrow)

		local cadirosGambit = equipCadirosGambit()
		runCallback("OnFrame")

		assert.is_true(control.shown())

		build.itemsTab:DeleteItem(cadirosGambit)
		runCallback("OnFrame")

		assert.is_false(control.shown())
	end)

	it("applies only the selected arrow condition", function()
		equipCadirosGambit()
		runCallback("OnFrame")

		local selections = { "NONE" }
		for _, condition in ipairs(arrowConditions) do
			table.insert(selections, condition)
		end

		for _, selected in ipairs(selections) do
			build.configTab.input.cadirosGambitArrow = selected
			build.configTab:BuildModList()

			for _, condition in ipairs(arrowConditions) do
				local conditionExists = build.configTab.modList:HasMod(
					"FLAG", nil, "Condition:" .. condition
				)
				assert.are.equals(selected == condition, conditionExists)
			end
		end
	end)

	it("applies Crescendo Arrow chain and damage bonuses", function()
		setupSkill("Shockchain Arrow")
		equipCadirosGambit()

		build.configTab.input.skillChainCount = 1
		selectArrow("NONE")

		local baselineChainMax = build.calcsTab.mainOutput.ChainMax or 0
		local baselineSkill = build.calcsTab.mainEnv.player.mainSkill
		local baselineDamage = baselineSkill.skillModList:Sum(
			"INC", baselineSkill.skillCfg, "Damage"
		)

		selectArrow("PerandusArrowCrescendo")

		local mainSkill = build.calcsTab.mainEnv.player.mainSkill
		assert.are.equals(baselineChainMax + 6, build.calcsTab.mainOutput.ChainMax)
		assert.are.equals(1, build.calcsTab.mainOutput.Chain)
		assert.are.equals(baselineDamage + 60, mainSkill.skillModList:Sum(
			"INC", mainSkill.skillCfg, "Damage"
		))
	end)

	it("applies Splinter Arrow split bonus", function()
		setupSkill("Shockchain Arrow")
		equipCadirosGambit()

		selectArrow("NONE")
		local baselineSplitCount = build.calcsTab.mainOutput.SplitCount or 0

		selectArrow("PerandusArrowSplinter")

		assert.are.equals(
			baselineSplitCount + 6,
			build.calcsTab.mainOutput.SplitCount
		)
		assert.are.equals(
			baselineSplitCount + 6,
			build.calcsTab.mainOutput.SplitCountString
		)
	end)

	it("applies Diamond Arrow critical bonuses", function()
		setupSkill("Shockchain Arrow")
		equipCadirosGambit()

		selectArrow("NONE")
		local baselineCritMultiplier = build.calcsTab.mainOutput.CritMultiplier
		local baselineSkill = build.calcsTab.mainEnv.player.mainSkill
		local baselineCritMultiplierIncrease = baselineSkill.skillModList:Sum(
			"INC", baselineSkill.skillCfg, "CritMultiplier"
		)

		selectArrow("PerandusArrowDiamond")

		local mainSkill = build.calcsTab.mainEnv.player.mainSkill
		assert.are.equals(100, build.calcsTab.mainOutput.CritChance)
		assert.are.equals(
			baselineCritMultiplierIncrease + 60,
			mainSkill.skillModList:Sum(
				"INC", mainSkill.skillCfg, "CritMultiplier"
			)
		)
		assert.is_true(
			build.calcsTab.mainOutput.CritMultiplier > baselineCritMultiplier
		)
	end)

	it("applies Covetous Arrow rarity bonus", function()
		setupSkill("Shockchain Arrow")
		equipCadirosGambit()

		selectArrow("NONE")
		local baselineSkill = build.calcsTab.mainEnv.player.mainSkill
		local baselineRarity = baselineSkill.skillModList:Sum(
			"INC", baselineSkill.skillCfg, "LootRarity"
		)

		selectArrow("PerandusArrowCovetous")

		local mainSkill = build.calcsTab.mainEnv.player.mainSkill
		assert.are.equals(
			baselineRarity + 600,
			mainSkill.skillModList:Sum(
				"INC", mainSkill.skillCfg, "LootRarity"
			)
		)
	end)

	it("applies Blunt Arrow stun buildup bonus", function()
		setupSkill("Shockchain Arrow")
		equipCadirosGambit()

		selectArrow("NONE")
		local baselineBuildup = build.calcsTab.mainOutput.HeavyStunBuildupAvg or 0
		local baselineSkill = build.calcsTab.mainEnv.player.mainSkill
		local baselineBuildupIncrease = baselineSkill.skillModList:Sum(
			"INC", baselineSkill.skillCfg, "EnemyHeavyStunBuildup"
		)

		selectArrow("PerandusArrowBlunt")

		local mainSkill = build.calcsTab.mainEnv.player.mainSkill
		assert.are.equals(
			baselineBuildupIncrease + 600,
			mainSkill.skillModList:Sum(
				"INC", mainSkill.skillCfg, "EnemyHeavyStunBuildup"
			)
		)
		assert.is_true(
			build.calcsTab.mainOutput.HeavyStunBuildupAvg > baselineBuildup
		)
	end)

	it("does not apply arrow bonuses to a non-arrow skill", function()
		setupSkill("Fireball")
		equipCadirosGambit()

		local scopedMods = {
			{
				condition = "PerandusArrowCrescendo",
				modType = "BASE",
				modName = "ChainCountMax",
			},
			{
				condition = "PerandusArrowSplinter",
				modType = "BASE",
				modName = "SplitCount",
			},
			{
				condition = "PerandusArrowReversing",
				modType = "BASE",
				modName = "ProjectileReturnChance",
			},
			{
				condition = "PerandusArrowDiamond",
				modType = "INC",
				modName = "CritMultiplier",
			},
			{
				condition = "PerandusArrowCovetous",
				modType = "INC",
				modName = "LootRarity",
			},
			{
				condition = "PerandusArrowBlunt",
				modType = "INC",
				modName = "EnemyHeavyStunBuildup",
			},
		}

		for _, scopedMod in ipairs(scopedMods) do
			selectArrow(scopedMod.condition)

			local mainSkill = build.calcsTab.mainEnv.player.mainSkill
			assert.are.equals(
				0,
				mainSkill.skillModList:Sum(
					scopedMod.modType,
					mainSkill.skillCfg,
					scopedMod.modName
				)
			)
		end
	end)

	it("shows Reversing Arrow outputs and removes them with the item", function()
		setupSkill("Shockchain Arrow")
		local cadirosGambit = equipCadirosGambit()

		selectArrow("PerandusArrowReversing")

		assert.are.equals(100, build.calcsTab.mainOutput.PierceCount)
		assert.are.equals("All targets", build.calcsTab.mainOutput.PierceCountString)
		assert.are.equals(100, build.calcsTab.mainOutput.ProjectileReturnChance)

		build.itemsTab:DeleteItem(cadirosGambit)
		runCallback("OnFrame")

		assert.are.equals(0, build.calcsTab.mainOutput.PierceCount)
		assert.are.equals(0, build.calcsTab.mainOutput.ProjectileReturnChance)
	end)
end)
