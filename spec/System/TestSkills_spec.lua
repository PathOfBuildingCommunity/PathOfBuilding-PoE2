describe("TestSkills", function()
	before_each(function()
		newBuild()
	end)

	teardown(function()
		-- newBuild() takes care of resetting everything in setup()
	end)

	local function selectActiveSkillById(socketGroup, skillId)
		local socketGroupIndex
		for index, group in ipairs(build.skillsTab.socketGroupList) do
			if group == socketGroup then
				socketGroupIndex = index
				break
			end
		end
		for index, activeSkill in ipairs(socketGroup.displaySkillList) do
			if activeSkill.activeEffect.grantedEffect.id == skillId then
				build.mainSocketGroup = socketGroupIndex
				build.calcsTab.input.skill_number = socketGroupIndex
				socketGroup.mainActiveSkill = index
				socketGroup.mainActiveSkillCalcs = index
				build.buildFlag = true
				runCallback("OnFrame")
				return activeSkill
			end
		end
	end

	local function assertGemSupportLevel(gemName, expectedLevel, expectedCount)
		local count = 0
		for _, activeSkill in ipairs(build.calcsTab.calcsEnv.player.activeSkillList) do
			if activeSkill.activeEffect.gemData and activeSkill.activeEffect.gemData.name == gemName then
				count = count + 1
				assert.are.equals(expectedLevel, activeSkill.skillModList:Sum("BASE", activeSkill.skillCfg, "GemSupportLevel"))
			end
		end
		assert.are.equals(expectedCount, count)
	end

	it("evaluates GemTag mod tags against active skill gem tags", function()
		local modDB = build.calcsTab.mainEnv.modDB

		modDB:NewMod("Damage", "INC", 10, "Test Fire GemTag", { type = "GemTag", gemTag = "Fire" })
		modDB:NewMod("Damage", "INC", 20, "Test Elemental GemTagList", { type = "GemTag", gemTagList = { "Cold", "Lightning" } })
		modDB:NewMod("Damage", "INC", 40, "Test Not Minion GemTag", { type = "GemTag", gemTag = "Minion", neg = true })

		assert.are.equals(50, modDB:Sum("INC", { skillGem = { tags = { fire = true } } }, "Damage"))
		assert.are.equals(60, modDB:Sum("INC", { skillGem = { tags = { cold = true } } }, "Damage"))
		assert.are.equals(0, modDB:Sum("INC", { skillGem = { tags = { minion = true } } }, "Damage"))
	end)

	it("applies Fire Mastery level to Apocalypse through the source gem tag", function()
		build.skillsTab:PasteSocketGroup("Apocalypse 20/0  1\nFire Mastery 1/0  1")
		runCallback("OnFrame")
		assertGemSupportLevel("Apocalypse", 1, 4)
	end)

	it("evaluates conditional gem levels using the source gem support count", function()
		build.skillsTab:PasteSocketGroup("Apocalypse 20/0  1\nFire Mastery 1/0  1\nUhtred's Omen 1/0  1")
		runCallback("OnFrame")
		assertGemSupportLevel("Apocalypse", 3, 4)
	end)

	it("applies Advanced Thaumaturgy quality stats only when enabled", function()
		local advancedThaumaturgy = build.spec.nodes[14429]
		assert.is_not_nil(advancedThaumaturgy)
		assert.True(advancedThaumaturgy.modList:Flag(nil, "GemlingQuality"))

		local grantedEffect = data.skills["AlchemistsBoonPlayer"]
		local statSet = grantedEffect.statSets[1]
		local skillInstance = {
			level = 20,
			quality = 20,
		}

		local stats = calcLib.buildSkillInstanceStats(skillInstance, grantedEffect, statSet)
		assert.is_not_nil(stats["skill_alchemists_boon_generate_x_charges_for_any_flask_per_minute"])
		assert.is_nil(stats["alchemists_boon_attack_speed_granted_+%_during_life_flask"])
		assert.is_nil(stats["alchemists_boon_cast_speed_granted_+%_during_mana_flask"])

		stats = calcLib.buildSkillInstanceStats(skillInstance, grantedEffect, statSet, true)
		assert.are.equals(20, stats["alchemists_boon_attack_speed_granted_+%_during_life_flask"])
		assert.are.equals(20, stats["alchemists_boon_cast_speed_granted_+%_during_mana_flask"])
	end)

	it("describes quality stats from secondary skill stat sets", function()
		local grantedEffect = data.skills["ExplosiveSpearPlayer"]
		local qualityStat = grantedEffect.qualityStats[1]
		local stats = {
			active_skill_base_area_of_effect_radius = 4,
		}

		assert.same({ 1, 2 }, qualityStat[3])
		local firstDescriptions = build.data.describeStats(stats, grantedEffect.statSets[1].statDescriptionScope, true)
		local qualityStatSet = grantedEffect.statSets[qualityStat[3][1] + 1]
		local qualityDescriptions = build.data.describeStats(stats, qualityStatSet.statDescriptionScope, true)

		assert.are.equals(0, #firstDescriptions)
		assert.is_true(#qualityDescriptions > 0)
		assert.matches("Explosion radius", qualityDescriptions[1])
	end)

	it("uses companion resistances in the beast library controls", function()
		local minionId = "Metadata/Monsters/LeagueAbyss/Lightless/Cocoon3Spectre"
		local testData = {
			skills = build.data.skills,
			minions = {
				A = copyTable(build.data.minions[minionId]),
				B = copyTable(build.data.minions[minionId]),
			},
		}
		testData.minions.B.name = "B"
		testData.minions.B.fireResist = 0
		testData.minions.B.companionFireResist = 60

		local tooltip = {
			lines = { },
			CheckForUpdate = function()
				return true
			end,
			AddLine = function(self, _, text)
				table.insert(self.lines, text)
			end,
			AddSeparator = function()
			end,
		}
		local spectreList = new("MinionListControl", nil, { 0, 0, 100, 100 }, testData, { "A" }, nil, "Spectres")
		local beastList = new("MinionListControl", nil, { 0, 0, 100, 100 }, testData, { "A" }, nil, "Beasts", true)

		spectreList:AddValueTooltip(tooltip, 1, "A")
		assert.matches("Resistances:.*75", table.concat(tooltip.lines, "\n"))
		tooltip.lines = { }
		beastList:AddValueTooltip(tooltip, 1, "A")
		assert.matches("Resistances:.*50", table.concat(tooltip.lines, "\n"))

		local sourceList = { "A", "B" }
		local sourceControl = new("MinionSearchListControl", nil, { 0, 0, 100, 100 }, testData, sourceList, beastList, "Beasts", true)
		sourceControl.controls.sortModeDropDown.selIndex = 9
		sourceControl:sortSourceList()
		assert.are.equals("B", sourceControl.list[1])
	end)


	it("uses granted effect minion list when active skill minion list is missing", function()
		local srcInstance = { statSet = { }, skillPart = { }, nameSpec = "Spectre: Test" }
		local minionId = "RaisedSkeletonSniper"
		local activeEffect = {
			srcInstance = srcInstance,
			grantedEffect = {
				id = "TestSpectreSkill",
				name = "Spectre: Test",
				statSets = { { label = "Default" } },
				minionList = { minionId },
			},
			statSet = { skillFlags = { } },
		}
		local activeSkill = {
			activeEffect = activeEffect,
			skillData = { },
			-- activeSkill.minionList intentionally absent; this reproduces #1677.
		}
		build.skillsTab.socketGroupList[1] = {
			displaySkillList = { activeSkill },
			mainActiveSkill = 1,
		}

		build:RefreshSkillSelectControls(build.controls, 1, "")

		assert.are.equals("Skeletal Sniper", build.controls.mainSkillMinion.list[1].label)
		assert.are.equals(minionId, build.controls.mainSkillMinion.list[1].minionId)
	end)

	it("does not crash when minion activeSkillList is missing", function()
		local srcInstance = { statSet = { }, skillPart = { }, nameSpec = "Minion: Test" }
		local activeEffect = {
			srcInstance = srcInstance,
			grantedEffect = {
				id = "TestMinionSkill",
				name = "Minion: Test",
				statSets = { { label = "Default" } },
			},
			statSet = { skillFlags = { } },
		}
		local activeSkill = {
			activeEffect = activeEffect,
			skillData = { },
			minion = {
				-- activeSkillList is absent, reproducing the crash fix in #2243
			}
		}
		build.skillsTab.socketGroupList[1] = {
			displaySkillList = { activeSkill },
			mainActiveSkill = 1,
		}

		assert.has_no.errors(function()
			build:RefreshSkillSelectControls(build.controls, 1, "")
		end)
	end)

	it("does not crash when minion activeSkillList is an empty table", function()
		local srcInstance = { statSet = { }, skillPart = { }, nameSpec = "Minion: Test" }
		local activeEffect = {
			srcInstance = srcInstance,
			grantedEffect = {
				id = "TestMinionSkill",
				name = "Minion: Test",
				statSets = { { label = "Default" } },
			},
			statSet = { skillFlags = { } },
		}
		local activeSkill = {
			activeEffect = activeEffect,
			skillData = { },
			minion = {
				activeSkillList = { }  -- empty list, guard must check [1] as well
			}
		}
		build.skillsTab.socketGroupList[1] = {
			displaySkillList = { activeSkill },
			mainActiveSkill = 1,
		}

		assert.has_no.errors(function()
			build:RefreshSkillSelectControls(build.controls, 1, "")
		end)

		-- Minion skill dropdown should remain hidden when there are no skills
		assert.is_false(build.controls.mainSkillMinionSkill.shown)
	end)

	it("populates minion skill list and UI controls after full OnFrame cycle", function()
		-- End-to-end test: exercises the complete pipeline including
		-- calcs.buildOutput, calcs.perform, createMinionSkills, and
		-- RefreshSkillSelectControls in a single OnFrame frame.
		build.skillsTab:PasteSocketGroup("Skeletal Sniper 20/0  1")

		assert.has_no.errors(function()
			runCallback("OnFrame")
		end)

		-- Verify the calculation engine populated the minion correctly
		local minion = build.calcsTab.mainEnv.minion
		assert.is_not_nil(minion, "minion should be created by the calc engine")
		assert.is_not_nil(minion.activeSkillList, "activeSkillList should be populated by createMinionSkills")
		assert.is_true(#minion.activeSkillList > 0, "minion should have at least one skill")
		assert.is_not_nil(minion.mainSkill, "mainSkill should be selected from activeSkillList")

		-- Verify the UI controls were populated by RefreshSkillSelectControls
		assert.is_true(build.controls.mainSkillMinion.shown, "minion dropdown should be visible")
		assert.is_true(build.controls.mainSkillMinionSkill.shown, "minion skill dropdown should be visible")
		assert.is_true(#build.controls.mainSkillMinionSkill.list > 0, "minion skill dropdown should have entries")
	end)

	it("does not crash rendering socket tooltip when minion skill selection is missing", function()
		build.skillsTab:PasteSocketGroup("Skeletal Sniper 20/0  1")
		runCallback("OnFrame")

		local socketGroup = build.skillsTab.socketGroupList[1]
		socketGroup.displaySkillList[1].minion.mainSkill = nil

		local tooltip = {
			AddLine = function() end,
			AddSeparator = function() end,
		}
		assert.has_no.errors(function()
			build.skillsTab:AddSocketGroupTooltip(tooltip, socketGroup)
		end)
	end)

	it("does not crash when importing a character with a minion main skill and passive tree (issue #2243)", function()
		-- Reproduces the exact bug scenario: ImportItemsAndSkills adds a minion
		-- skill, ImportPassiveTreeAndJewels triggers a rebuild, and OnFrame must
		-- complete without crashing in RefreshSkillSelectControls or Calcs.
		local charData = {
			level = 50,
			class = "Witch2",
			league = "Test",
			equipment = {},
			skills = {
				{
					support = false,
					typeLine = "Skeletal Sniper",
					properties = {
						{ name = "Level", values = { { "20", 0 } } },
						{ name = "Quality", values = { { "+0%", 0 } } },
					},
				},
			},
		}

		build.importTab.controls.charImportItemsClearSkills.state = true
		build.importTab.controls.charImportItemsClearItems.state = false
		build.importTab:ImportItemsAndSkills(charData)

		-- At this point the minion skill is in socketGroupList but the calc
		-- engine hasn't run yet, so activeSkillList may be nil — the bug state.
		runCallback("OnFrame")

		-- Now import the passive tree, which sets buildFlag and triggers another
		-- full rebuild — this is the step that originally caused the crash.
		build.importTab:ImportPassiveTreeAndJewels({
			name = "TestMinionImport",
			class = "Witch2",
			league = "Test",
			level = 50,
			jewels = {},
			passives = {
				hashes = {},
				specialisations = {},
				skill_overrides = {},
				jewel_data = {},
				quest_stats = {},
			},
		})

		assert.has_no.errors(function()
			runCallback("OnFrame")
		end)

		-- Verify the minion skill was properly initialised after the full cycle
		local mainEnv = build.calcsTab.mainEnv
		assert.is_not_nil(mainEnv.minion, "minion should exist after import")
		assert.is_not_nil(mainEnv.minion.activeSkillList, "activeSkillList should be populated")
		assert.is_not_nil(mainEnv.minion.mainSkill, "mainSkill should be set")
	end)

	it("applies minion skill stat set selections to the selected minion skill only", function()

		build.skillsTab:PasteSocketGroup("Skeletal Sniper 20/0  1")
		runCallback("OnFrame")

		local srcInstance = build.skillsTab.socketGroupList[1].gemList[1]
		srcInstance.skillMinionSkill = 2
		srcInstance.skillMinionSkillCalcs = 2
		srcInstance.skillMinionSkillStatSetIndexLookup = { SummonSkeletalSnipersPlayer = { [2] = 3 } }
		srcInstance.skillMinionSkillStatSetIndexLookupCalcs = { SummonSkeletalSnipersPlayer = { [2] = 3 } }
		build.buildFlag = true
		build.modFlag = true

		assert.has_no.errors(function()
			runCallback("OnFrame")
		end)

		local minionSkills = build.calcsTab.mainEnv.minion.activeSkillList
		assert.are.equals("Basic Attack", minionSkills[1].activeEffect.statSet.statSet.label)
		assert.are.equals("Explosion", minionSkills[2].activeEffect.statSet.statSet.label)
	end)

	it("Test blasphemy reserving Spirit", function()
		build.skillsTab:PasteSocketGroup("Blasphemy 20/0  1\nDespair 20/0  1\n")
		runCallback("OnFrame")

		local oneCurseReservation = build.calcsTab.mainOutput.SpiritReservedPercent
		assert.True(oneCurseReservation > 0)

		newBuild()

		build.skillsTab:PasteSocketGroup("Blasphemy 20/0  1\nDespair 20/0  1\nTemporal Chains 20/0  1\n")
		runCallback("OnFrame")

		assert.True(build.calcsTab.mainOutput.SpiritReservedPercent > oneCurseReservation)
	end)

	it("applies life reservation efficiency to Atziri's Communion Blasphemy reservation", function()
		build.skillsTab:PasteSocketGroup("Blasphemy 20/0  1\nDespair 20/0  1\nAtziri's Communion 1/0  1\n")
		runCallback("OnFrame")

		assert.are.equals(0, build.calcsTab.mainOutput.SpiritReserved)
		assert.are.equals(0, build.calcsTab.mainOutput.SpiritReservedPercent)
		assert.are.equals(26, build.calcsTab.mainOutput.LifeReserved)
		assert.are.equals(40, build.calcsTab.mainOutput.LifeReservedPercent)

		build.configTab.input.customMods = "100% increased Life Reservation Efficiency"
		build.configTab:BuildModList()
		runCallback("OnFrame")

		assert.are.equals(13, build.calcsTab.mainOutput.LifeReserved)
		assert.are.equals(20, build.calcsTab.mainOutput.LifeReservedPercent)
	end)

	it("rounds Blasphemy curse magnitudes to the nearest integer", function()
		build.configTab.input.customMods = "79% increased Curse Magnitudes"
		build.configTab.input.enemyIsBoss = "None"
		build.configTab:BuildModList()
		build.skillsTab:PasteSocketGroup("Blasphemy 10/0  1\nDespair 12/0  1\n")

		runCallback("OnFrame")

		assert.are.equals(-42, build.calcsTab.mainEnv.enemyDB:Sum("BASE", nil, "ChaosResist"))
	end)

	it("applies active skill reservation multiplier to linked buff spirit reservation", function()
		build.skillsTab:PasteSocketGroup("Purity of Fire 20/0  1\nVitality II 1/0  1\n")
		runCallback("OnFrame")

		assert.are.equals(0, build.calcsTab.mainOutput.SpiritReserved)
	end)

	it("Keeps Virtuous armour scaling during Full DPS loop", function()
		build.itemsTab:CreateDisplayItemFromRaw("New Item\nRazor Quarterstaff\nQuality: 0")
		build.itemsTab:AddDisplayItem()
		build.skillsTab:PasteSocketGroup("Virtuous Barrier 20/0  1")
		build.skillsTab:PasteSocketGroup("Falling Thunder 20/0  1")
		build.skillsTab:PasteSocketGroup("Quarterstaff Strike 20/0  1")
		build.mainSocketGroup = 3
		runCallback("OnFrame")

		local calcs = LoadModule("Modules/Calcs")
		local env, cachedPlayerDB, cachedEnemyDB, cachedMinionDB = calcs.initEnv(build, "CALCULATOR")
		env.modDB:NewMod("Armour", "BASE", 1000, "Test Armour")
		env.modDB:NewMod("Damage", "INC", 10, "Test Armour Damage", ModFlag.Attack, 0, { type = "PerStat", stat = "Armour", div = 1 })
		calcs.perform(env)

		local normalArmour = env.player.output.Armour
		local normalDPS = env.player.output.TotalDPS
		assert.are.equals(1200, normalArmour)
		assert.is_true(normalDPS > 0)

		env = calcs.initEnv(build, "CALCULATOR", {}, {
			cachedPlayerDB = cachedPlayerDB,
			cachedEnemyDB = cachedEnemyDB,
			cachedMinionDB = cachedMinionDB,
			env = env,
			accelerate = {
				nodeAlloc = true,
				requirementsItems = true,
				requirementsGems = true,
				skills = true,
				everything = true,
			},
		})
		env.modDB:NewMod("Armour", "BASE", 1000, "Test Armour")
		env.modDB:NewMod("Damage", "INC", 10, "Test Armour Damage", ModFlag.Attack, 0, { type = "PerStat", stat = "Armour", div = 1 })
		calcs.perform(env)

		assert.are.equals(normalArmour, env.player.output.Armour)
		assert.are.near(normalDPS, env.player.output.TotalDPS, 0.001)
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

	it("Test socket group pasting with corruption levels and count", function()
		build.skillsTab:PasteSocketGroup("Wave of Frost 20/0  3 C+1\n Culmination I 1/0  1")
		assert.are.equals(3, build.skillsTab.socketGroupList[1].gemList[1].count)

		runCallback("OnFrame")

		assert.are.equals(3, build.skillsTab.socketGroupList[1].gemList[1].count)
		assert.are.equals(true, build.skillsTab.socketGroupList[1].gemList[1].corrupted)
		assert.are.equals(1, build.skillsTab.socketGroupList[1].gemList[1].corruptLevel)

		newBuild()
		-- Support gem first this time, with negative corruption value.
		build.skillsTab:PasteSocketGroup("Culmination I 1/0  1\nWave of Frost 20/20  2 C-1")
		assert.are.equals(2, build.skillsTab.socketGroupList[1].gemList[2].count)

		runCallback("OnFrame")

		assert.are.equals(2, build.skillsTab.socketGroupList[1].gemList[2].count)
		assert.are.equals(true, build.skillsTab.socketGroupList[1].gemList[2].corrupted)
		assert.are.equals(-1, build.skillsTab.socketGroupList[1].gemList[2].corruptLevel)
	end)

	it("Fractional skill count scales Full DPS", function()
		build.skillsTab:PasteSocketGroup("Ball Lightning 20/0  1")
		build.skillsTab.socketGroupList[1].includeInFullDPS = true
		runCallback("OnFrame")

		local fullDPS = build.calcsTab.mainOutput.FullDPS
		assert.truthy(fullDPS)
		assert.True(fullDPS > 0)

		newBuild()

		build.skillsTab:PasteSocketGroup("Ball Lightning 20/0  0.5")
		build.skillsTab.socketGroupList[1].includeInFullDPS = true
		runCallback("OnFrame")

		assert.are.equals(0.5, build.skillsTab.socketGroupList[1].gemList[1].count)
		assert.True(math.abs(build.calcsTab.mainOutput.FullDPS - fullDPS * 0.5) < fullDPS * 0.001)
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

	it("Test 'every rage also grants you' for minion mods and minion apply to you mods", function()
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

	it("applies generated minion offensive multiplier to attack damage", function()
		build.skillsTab:PasteSocketGroup("Wolf Pack 20/0  1")
		runCallback("OnFrame")

		local minion = build.calcsTab.mainEnv.minion
		local expectedPhysicalMax = floor(floor(build.calcsTab.mainEnv.data.monsterAllyDamageTable[minion.level]) * minion.minionData.damage * (1 + minion.minionData.damageSpread))

		assert.are.equals(expectedPhysicalMax, minion.weaponData1.PhysicalMax)
		assert.are.near(-30, minion.mainSkill.skillModList:Sum("MORE", minion.mainSkill.skillCfg, "AddedDamage"), 0.0001)
		assert.are.equals(0, minion.mainSkill.skillModList:Sum("MORE", minion.mainSkill.skillCfg, "Damage"))
	end)

	it("does not apply minion offensive multiplier to spectre or companion added damage", function()
		for _, skill in ipairs({ "Spectre: Lightless Abomination 20/0  1", "Companion: Lightless Abomination 20/0  1" }) do
			newBuild()
			build.skillsTab:PasteSocketGroup(skill)
			runCallback("OnFrame")

			local minion = build.calcsTab.mainEnv.minion
			assert.are.equals(0, minion.mainSkill.skillModList:Sum("MORE", minion.mainSkill.skillCfg, "AddedDamage"))
		end
	end)

	it("uses selected companion names in skill displays", function()
		build.skillsTab:PasteSocketGroup("Companion: Lightless Abomination 20/0  1")
		build.skillsTab:PasteSocketGroup("Companion: Lightless Moray 20/0  1")
		build.skillsTab.socketGroupList[1].includeInFullDPS = true
		build.skillsTab.socketGroupList[2].includeInFullDPS = true
		runCallback("OnFrame")

		local skillNames = { }
		for _, skill in ipairs(build.calcsTab.mainOutput.SkillDPS) do
			skillNames[skill.name] = true
		end
		assert.is_true(skillNames["Companion: Lightless Abomination"])
		assert.is_true(skillNames["Companion: Lightless Moray"])

		build:RefreshSkillSelectControls(build.controls, 1, "")
		assert.are.equals("Companion: Lightless Abomination", build.controls.mainSkill.list[1].label)

		build:RefreshSkillSelectControls(build.controls, 2, "")
		assert.are.equals("Companion: Lightless Moray", build.controls.mainSkill.list[1].label)
	end)

	it("Inspiring Ally only mirrors companion damage, not generic minion damage", function()
		build.itemsTab:CreateDisplayItemFromRaw([[
			New Item
			Fanatic Greathammer
			Quality: 0
		]])
		build.itemsTab:AddDisplayItem()
		build.skillsTab:PasteSocketGroup("Leap Slam 20/0  1")
		runCallback("OnFrame")

		local baseLeapSlamHit = build.calcsTab.mainOutput.AverageDamage

		build.configTab.input.customMods = "Increases and Reductions to Companion Damage also apply to you\nMinions deal 20% increased Damage"
		build.configTab:BuildModList()
		runCallback("OnFrame")

		assert.are.equals(baseLeapSlamHit, build.calcsTab.mainOutput.AverageDamage)

		build.configTab.input.customMods = "Increases and Reductions to Companion Damage also apply to you\nCompanions deal 12% increased Damage"
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

	it("Test corrupted blood config", function()
		build.skillsTab:PasteSocketGroup("Seismic Cry 20/0  1\nCorrupting Cry I 1/0  1")
		runCallback("OnFrame")
		selectActiveSkillById(build.skillsTab.socketGroupList[#build.skillsTab.socketGroupList], "TriggeredCorruptingCryPlayer")

		local baseCorruptingCryDps = build.calcsTab.mainOutput.CorruptingBloodDPS -- placeholder/input is 10

		build.configTab.input.conditionCorruptingCryStages = 5
		build.configTab:BuildModList()
		runCallback("OnFrame")
		assert.True(baseCorruptingCryDps > build.calcsTab.mainOutput.CorruptingBloodDPS)

		build.configTab.input.conditionCorruptingCryStages = 100 -- test limit
		build.configTab:BuildModList()
		runCallback("OnFrame")
		assert.True(baseCorruptingCryDps == build.calcsTab.mainOutput.CorruptingBloodDPS)
	end)

	it("support-granted active skills inherit the linked active skill level", function()
		local function getCorruptingCryDps(socketGroupText)
			newBuild()
			build.skillsTab:PasteSocketGroup(socketGroupText)
			runCallback("OnFrame")

			local activeSkill = selectActiveSkillById(build.skillsTab.socketGroupList[#build.skillsTab.socketGroupList], "TriggeredCorruptingCryPlayer")
			assert.is_not_nil(activeSkill)
			assert.are.equals(20, activeSkill.activeEffect.level)
			assert.are.equals("TriggeredCorruptingCryPlayer", build.calcsTab.mainEnv.player.mainSkill.activeEffect.grantedEffect.id)
			return build.calcsTab.mainOutput.CorruptingBloodDPS
		end

		local warcryFirstDps = getCorruptingCryDps("Seismic Cry 20/0  1\nCorrupting Cry I 1/0  1")
		local supportFirstDps = getCorruptingCryDps("Corrupting Cry I 1/0  1\nSeismic Cry 20/0  1")

		assert.is_not_nil(warcryFirstDps)
		assert.are.equals(warcryFirstDps, supportFirstDps)
	end)

	it("Flame Breath attack speed scales DPS and is not capped by its channel cooldown", function()
		build.itemsTab:CreateDisplayItemFromRaw([[
			New Item
			Roaring Talisman
		]])
		build.itemsTab:AddDisplayItem()
		runCallback("OnFrame")

		build.skillsTab:PasteSocketGroup("Flame Breath 20/0  1")
		runCallback("OnFrame")

		local baseSpeed = build.calcsTab.mainOutput.Speed
		local baseDPS = build.calcsTab.mainOutput.TotalDPS

		assert.True(baseSpeed > 1)
		assert.True(baseDPS > 0)

		build.configTab.input.customMods = "100% increased attack speed"
		build.configTab:BuildModList()
		runCallback("OnFrame")

		assert.True(build.calcsTab.mainOutput.Speed > baseSpeed * 1.9)
		assert.True(build.calcsTab.mainOutput.TotalDPS > baseDPS * 1.9)
	end)

	it("Test Atziri's Allure - ignore curse limit", function()
		build.skillsTab:PasteSocketGroup("Elemental Weakness 20/0  1\nAtziri's Allure 1/0 1")
		build.skillsTab:PasteSocketGroup("Despair 20/0  1\n")
		runCallback("OnFrame")

		local curseList = build.calcsTab.calcsOutput.CurseList
		assert.True(curseList:match("Despair") ~= nil and curseList:match("Elemental Weakness") ~= nil)
	end)

	-- skills that don't have a base CD and have more than one use need to use the added cooldown by whatever support allows the +1 limit to be supportable
	it("Test Added Cooldown interaction with +1 Limit", function()
		build.skillsTab:PasteSocketGroup("Thunderstorm 20/0  1\nHourglass 1/0 1\nOverabundance I 1/0 1\n")
		runCallback("OnFrame")

		assert.True(build.calcsTab.calcsOutput.Cooldown == 10)
	end)

	it("does not count item or tree granted active skills as gem groups", function()
		local function fakeGem(name, grantedEffect, extra)
			local gem = {
				enabled = true,
				gemData = {
					name = name,
					grantedEffect = grantedEffect or { },
				},
			}
			for key, value in pairs(extra or { }) do
				gem[key] = value
			end
			return gem
		end

		local skillsTab = {
			socketGroupList = {
				{ enabled = true, gemList = { fakeGem("Item Skill", { fromItem = true }) } },
				{ enabled = true, gemList = { fakeGem("Tree Skill", { fromTree = true }) } },
				{ enabled = true, gemList = { fakeGem("Stored Item Skill", nil, { fromItem = true }) } },
				{ enabled = true, gemList = { fakeGem("Socketed Skill"), fakeGem("Item Support", { support = true, fromItem = true }) } },
			},
		}

		build.skillsTab.UpdateGlobalGemCountAssignments(skillsTab)

		assert.are.equals(1, GlobalGemAssignments["GemGroupCount"])
	end)

	it("Test hidden meta supports do not count as connected supports", function()
		build.skillsTab:PasteSocketGroup("Cast on Critical 20/0  1\nArc 20/0  1\nUhtred's Omen 1/0  1\nRising Tempest 1/0  1")
		runCallback("OnFrame")

		local arcSkill = nil
		for _, activeSkill in ipairs(build.calcsTab.calcsEnv.player.activeSkillList) do
			if activeSkill.activeEffect.grantedEffect.name == "Arc" then
				arcSkill = activeSkill
				break
			end
		end

		assert.is_not_nil(arcSkill)
		assert.are.equals(2, arcSkill.skillModList:GetMultiplier("SupportCount", arcSkill.skillCfg))
		assert.are.equals(2, arcSkill.skillModList:Sum("BASE", arcSkill.skillCfg, "GemSupportLevel"))
	end)

	it("Test Elemental Conflux element selection", function()
		build.skillsTab:PasteSocketGroup("Arc 20/0  1")
		build.skillsTab:PasteSocketGroup("Elemental Conflux 20/0  1")
		build.configTab.input.elementalConfluxElement = 2 -- Lightning
		build.configTab:BuildModList()
		runCallback("OnFrame")
		local lightningDPS = build.calcsTab.mainOutput.TotalDPS

		-- Cold element should not boost a lightning skill
		build.configTab.input.elementalConfluxElement = 3 -- Cold
		build.configTab:BuildModList()
		runCallback("OnFrame")
		local coldSelectedDPS = build.calcsTab.mainOutput.TotalDPS

		assert.True(lightningDPS > coldSelectedDPS)

		-- Average should give an intermediate boost (1/3 per element)
		build.configTab.input.elementalConfluxElement = 1 -- Average
		build.configTab:BuildModList()
		runCallback("OnFrame")
		local avgDPS = build.calcsTab.mainOutput.TotalDPS

		assert.True(avgDPS > coldSelectedDPS)
		assert.True(avgDPS < lightningDPS)
	end)

	it("Test flicker strike scales with power charges", function()
		build.skillsTab:PasteSocketGroup("Flicker Strike 20/0  1")
		build.itemsTab:CreateDisplayItemFromRaw([[
			New Item
			Sinister Quarterstaff
			Quality: 0
		]])
		build.itemsTab:AddDisplayItem()

		runCallback("OnFrame")

		local avgNoCharges = build.calcsTab.mainOutput.AverageDamage
		local avgBurstNoCharges = build.calcsTab.mainOutput.AverageBurstDamage

		-- Burst isn't calculated with no charges
		assert.truthy(avgNoCharges)
		assert.True(avgBurstNoCharges == avgNoCharges)

		build.configTab.input.usePowerCharges = true
		build.configTab.input.overridePowerCharges = 2
		build.configTab:BuildModList()

		runCallback("OnFrame")
		-- Burst should be higher due to having multiple strikes, while average
		-- is only slightly higher due to power charges
		local avgCharges = build.calcsTab.mainOutput.AverageDamage
		local avgBurstCharges = build.calcsTab.mainOutput.AverageBurstDamage

		assert.True(avgNoCharges == avgCharges)
		assert.True(avgCharges < avgBurstCharges)
		-- Strikes 2 times per charge
		assert.True(avgNoCharges * 4 <= avgBurstCharges)
		assert.True(avgBurstCharges <= avgNoCharges * 6)


		-- One with the Storm strikes 2 additional times
		build.configTab.input.customMods = "quarterstaff skills that consume power charges count as consuming an additional power charge"
		build.configTab:BuildModList()
		runCallback("OnFrame")
		assert.True(avgNoCharges * 6 <= build.calcsTab.mainOutput.AverageBurstDamage)
	end)

	it("Test Barrage only repeats Barrageable skills", function()
		build.itemsTab:CreateDisplayItemFromRaw([[
			New Item
			Warmonger Bow
			Quality: 0
		]])
		build.itemsTab:AddDisplayItem()
		runCallback("OnFrame")

		build.skillsTab:PasteSocketGroup("Spiral Volley 20/0  1")
		runCallback("OnFrame")
		local spiralVolleyDPS = build.calcsTab.mainOutput.TotalDPS

		build.skillsTab:PasteSocketGroup("Barrage 20/0  1")
		runCallback("OnFrame")
		assert.are.equals(spiralVolleyDPS, build.calcsTab.mainOutput.TotalDPS)

		newBuild()

		build.itemsTab:CreateDisplayItemFromRaw([[
			New Item
			Warmonger Bow
			Quality: 0
		]])
		build.itemsTab:AddDisplayItem()
		runCallback("OnFrame")

		build.skillsTab:PasteSocketGroup("Ice Shot 20/0  1")
		runCallback("OnFrame")
		local iceShotDPS = build.calcsTab.mainOutput.TotalDPS

		build.skillsTab:PasteSocketGroup("Barrage 20/0  1")
		runCallback("OnFrame")
		assert.True(build.calcsTab.mainOutput.TotalDPS > iceShotDPS)
	end)

	it("Test Unwilling Offering", function()
		build.configTab.input.customMods = [[
			Your Offerings affect you instead of your Minions
			Offerings created by Culling Enemies have 1% increased Effect per Power of Culled Enemy
		]]
		build.configTab:BuildModList()
		runCallback("OnFrame")

		build.skillsTab:PasteSocketGroup("Fireball 20/0  1")
		runCallback("OnFrame")
		local baseFireball = build.calcsTab.mainOutput.TotalDPS

		build.skillsTab:PasteSocketGroup("Pain Offering 20/0  1")
		runCallback("OnFrame")
		local fireBallPain = build.calcsTab.mainOutput.TotalDPS
		assert.True(fireBallPain > baseFireball)

		build.skillsTab:PasteSocketGroup("Soul Offering 20/0  1")
		runCallback("OnFrame")
		local fireBallPainSoul = build.calcsTab.mainOutput.TotalDPS
		assert.True(fireBallPainSoul > fireBallPain)
		assert.equals(build.calcsTab.calcsOutput.BuffList, "Pain Offering, Soul Offering")

		build.configTab.input.unwillingOfferingPower = 20
		build.configTab:BuildModList()
		runCallback("OnFrame")
		local incEffectOfferings = build.calcsTab.mainOutput.TotalDPS
		assert.True(incEffectOfferings > fireBallPainSoul)

		newBuild()
		build.configTab.input.customMods = [[
			Your Offerings affect you instead of your Minions
			Offerings created by Culling Enemies have 1% increased Effect per Power of Culled Enemy
		]]
		build.configTab:BuildModList()
		runCallback("OnFrame")
		build.skillsTab:PasteSocketGroup("Raise Zombie 20/0  1")
		build.skillsTab:PasteSocketGroup("Soul Offering 20/0  1")
		runCallback("OnFrame")
		assert.equals(build.calcsTab.calcsOutput.Minion.BuffList, "")
	end)

	it("Test Umbral Well", function()
		build.configTab.input.customMods = [[
			Skeletal Minions you would create instead grant you Umbral Souls for each Minion you would have created
		]]
		build.configTab:BuildModList()
		runCallback("OnFrame")

		build.skillsTab:PasteSocketGroup("Fireball 20/0  1")
		runCallback("OnFrame")
		local baseFireball = build.calcsTab.mainOutput.TotalDPS

		build.skillsTab:PasteSocketGroup("Skeletal Storm Mage 20/0  1")
		runCallback("OnFrame")

		-- if one works they all do, surely
		assert.True(build.calcsTab.mainOutput.TotalDPS > baseFireball)
	end)

	it("Test Minion Pact damage requires a minion in your presence", function()
		build.itemsTab:CreateDisplayItemFromRaw([[
			New Item
			Warmonger Bow
			Quality: 0
		]])
		build.itemsTab:AddDisplayItem()
		runCallback("OnFrame")

		build.skillsTab:PasteSocketGroup("Lightning Arrow 1/0  1\nMinion Pact I 1/0  1")
		runCallback("OnFrame")

		local activeSkill = build.calcsTab.calcsEnv.player.activeSkillList[1]
		assert.are.equals(0, activeSkill.skillModList:Sum("MORE", activeSkill.skillCfg, "Damage"))
		local noMinionDps = build.calcsTab.calcsOutput.TotalDPS

		build.configTab.input.multiplierMinionsInPresence = 1
		build.configTab:BuildModList()
		runCallback("OnFrame")

		activeSkill = build.calcsTab.calcsEnv.player.activeSkillList[1]
		assert.are.equals(30, activeSkill.skillModList:Sum("MORE", activeSkill.skillCfg, "Damage"))
		assert.True(build.calcsTab.calcsOutput.TotalDPS > noMinionDps)
	end)

	it("Test conditional exposure supports make exposure configurable", function()
		build.itemsTab:CreateDisplayItemFromRaw([[
			New Item
			Razor Quarterstaff
			Quality: 0
		]])
		build.itemsTab:AddDisplayItem()
		runCallback("OnFrame")

		build.skillsTab:PasteSocketGroup("Killing Palm 20/0  1\nLightning Attunement 1/0  1\nLightning Exposure 1/0  1")
		runCallback("OnFrame")

		assert.True(build.calcsTab.mainEnv.player.modDB:GetCondition("CanApplyLightningExposure"))
	end)

	it("Test exposure supports on other active skills make exposure configurable", function()
		build.itemsTab:CreateDisplayItemFromRaw([[
			New Item
			Razor Quarterstaff
			Quality: 0
		]])
		build.itemsTab:AddDisplayItem()
		runCallback("OnFrame")

		build.skillsTab:PasteSocketGroup("Spark 20/0  1")
		build.skillsTab:PasteSocketGroup("Killing Palm 20/0  1\nLightning Attunement 1/0  1\nLightning Exposure 1/0  1")
		runCallback("OnFrame")

		assert.are.equals("Spark", build.calcsTab.mainEnv.player.mainSkill.activeEffect.grantedEffect.name)
		assert.True(build.calcsTab.mainEnv.player.modDB:GetCondition("CanApplyLightningExposure"))

		build.configTab.input.conditionEnemyLightningExposure = true
		build.configTab:BuildModList()
		runCallback("OnFrame")

		assert.are.equals(20, build.calcsTab.mainEnv.enemyDB:Sum("BASE", nil, "LightningExposure"))
	end)

	it("Test Potent Exposure only scales exposure from supported skills", function()
		build.skillsTab:PasteSocketGroup("Fireball 20/0  1\nFire Exposure 1/0  1")
		build.configTab.input.conditionEnemyFireExposure = true
		build.configTab:BuildModList()
		runCallback("OnFrame")
		local fireResistWithoutPotentExposure = build.calcsTab.mainEnv.enemyDB:Sum("BASE", nil, "FireResist")

		newBuild()
		build.skillsTab:PasteSocketGroup("Fireball 20/0  1\nFire Exposure 1/0  1")
		build.skillsTab:PasteSocketGroup("Spark 20/0  1\nPotent Exposure 1/0  1")
		build.configTab.input.conditionEnemyFireExposure = true
		build.configTab:BuildModList()
		runCallback("OnFrame")
		assert.are.equals(fireResistWithoutPotentExposure, build.calcsTab.mainEnv.enemyDB:Sum("BASE", nil, "FireResist"))

		newBuild()
		build.skillsTab:PasteSocketGroup("Fireball 20/0  1\nFire Exposure 1/0  1\nPotent Exposure 1/0  1")
		build.configTab.input.conditionEnemyFireExposure = true
		build.configTab:BuildModList()
		runCallback("OnFrame")
		assert.are.equals(20, build.calcsTab.mainEnv.enemyDB:Sum("BASE", nil, "FireExposure"))
		assert.True(build.calcsTab.mainEnv.enemyDB:Sum("BASE", nil, "FireResist") < fireResistWithoutPotentExposure)
	end)

	it("averages inverted elemental resistance after penetration", function()
		build.skillsTab:PasteSocketGroup("Fireball 20/0  1")
		build.configTab.input.enemyIsBoss = "None"
		build.configTab.input.enemyFireResist = 50
		build.configTab.input.customMods = "Hits have 50% chance to treat Enemy Monster Elemental Resistance values as inverted\nDamage Penetrates 50% of Enemy Fire Resistance"
		build.configTab:BuildModList()
		runCallback("OnFrame")

		assert.are.equals(1.25, build.calcsTab.calcsOutput.FireEffMult)
		local breakdownText = table.concat(build.calcsTab.calcsEnv.player.breakdown.FireEffMult, "\n")
		assert.truthy(breakdownText:match("inverted hit"))
		assert.truthy(breakdownText:match("weighted average"))
	end)

	it("Test granted skills with exposure stats make exposure configurable", function()
		build.skillsTab:PasteSocketGroup("Fireball 20/0  1")
		local spec = build.spec
		local brewConcoctionNode = spec.nodes[57141]
		local shatteringConcoctionNode = spec.nodes[18940]
		brewConcoctionNode.alloc = true
		shatteringConcoctionNode.alloc = true
		spec.allocNodes[brewConcoctionNode.id] = brewConcoctionNode
		spec.allocNodes[shatteringConcoctionNode.id] = shatteringConcoctionNode
		build.buildFlag = true
		runCallback("OnFrame")
		build.calcsTab.input.skill_number = 1
		build.buildFlag = true
		runCallback("OnFrame")

		assert.are.equals("Fireball", build.calcsTab.mainEnv.player.mainSkill.activeEffect.grantedEffect.name)
		assert.True(build.calcsTab.mainEnv.player.modDB:GetCondition("CanApplyFireExposure"))
		assert.True(build.configTab.varControls.conditionEnemyFireExposure:shown())
	end)

	it("Test Refraction III exposure scales from player armour", function()
		build.configTab.input.customMods = "+30000 to Armour"
		build.configTab.input.bannerPlanted = true
		build.configTab:BuildModList()
		build.skillsTab:PasteSocketGroup("War Banner 20/0  1\nRefraction III 1/0  1")
		runCallback("OnFrame")

		assert.are.equals(30000, build.calcsTab.mainEnv.player.output.Armour)
		assert.are.equals(60, build.calcsTab.mainEnv.enemyDB:Sum("BASE", nil, "FireExposure"))
		assert.are.equals(20, build.calcsTab.mainEnv.enemyDB:Sum("BASE", nil, "FireResist"))
		assert.True(build.calcsTab.mainEnv.enemyDB:Flag(nil, "Condition:HasExposure"))
	end)

	describe("Combo stacking", function()
		local CHAKRA_MOD = "Skills deal 8% increased Damage per Combo consumed, up to 40%"

		local function equipQuarterstaff()
			build.itemsTab:CreateDisplayItemFromRaw([[
				New Item
				Razor Quarterstaff
				Quality: 0
			]])
			build.itemsTab:AddDisplayItem()
			runCallback("OnFrame")
		end

		local function applyComboConfig(stacks, customMods)
			build.configTab.input.multiplierCombo = stacks
			build.configTab.input.customMods = customMods or ""
			build.configTab:BuildModList()
			runCallback("OnFrame")
			build.calcsTab:BuildOutput()
			runCallback("OnFrame")
		end

		local function findSkillIndex(skillName)
			for index, skill in ipairs(build.calcsTab.mainEnv.player.activeSkillList) do
				if skill.activeEffect.grantedEffect.name == skillName then
					return index
				end
			end
			error("Skill not found: " .. skillName)
		end

		local function getSkillIncDamage(skillIndex)
			local skill = build.calcsTab.mainEnv.player.activeSkillList[skillIndex]
			return skill.skillModList:Sum("INC", skill.skillCfg, "Damage")
		end

		local function getSkillMoreDamage(skillIndex)
			local skill = build.calcsTab.mainEnv.player.activeSkillList[skillIndex]
			return skill.skillModList:Sum("MORE", skill.skillCfg, "Damage")
		end

		local function getAverageHit()
			return build.calcsTab.mainOutput.AverageHit or 0
		end

		it("does not apply damage per combo consumed to non-ComboStacking skills", function()
			equipQuarterstaff()
			build.skillsTab:PasteSocketGroup("Ball Lightning 20/0  1\n")
			build.skillsTab:PasteSocketGroup("Tempest Bell 20/0  1\n")
			runCallback("OnFrame")

			applyComboConfig(10, "")
			local ballIncBase = getSkillIncDamage(findSkillIndex("Ball Lightning"))
			local tempestIncBase = getSkillIncDamage(findSkillIndex("Tempest Bell"))

			applyComboConfig(10, CHAKRA_MOD)
			local ballIncWith = getSkillIncDamage(findSkillIndex("Ball Lightning"))
			local tempestIncWith = getSkillIncDamage(findSkillIndex("Tempest Bell"))

			assert.are.equals(ballIncBase, ballIncWith)
			assert.True(tempestIncWith > tempestIncBase)
		end)

		it("caps damage per combo consumed at the stated limit", function()
			equipQuarterstaff()
			build.skillsTab:PasteSocketGroup("Tempest Bell 20/0  1\n")
			runCallback("OnFrame")

			applyComboConfig(0, "")
			local tempestIncBase = getSkillIncDamage(findSkillIndex("Tempest Bell"))

			applyComboConfig(3, CHAKRA_MOD)
			local incAt3 = getSkillIncDamage(findSkillIndex("Tempest Bell"))

			applyComboConfig(5, CHAKRA_MOD)
			local incAt5 = getSkillIncDamage(findSkillIndex("Tempest Bell"))

			applyComboConfig(10, CHAKRA_MOD)
			local incAt10 = getSkillIncDamage(findSkillIndex("Tempest Bell"))

			assert.are.equals(24, incAt3 - tempestIncBase)
			assert.are.equals(40, incAt5 - tempestIncBase)
			assert.are.equals(40, incAt10 - tempestIncBase)
			assert.are.equals(incAt5, incAt10)
		end)

		it("Culmination I caps combo damage at 10 stacks", function()
			equipQuarterstaff()
			build.skillsTab:PasteSocketGroup("Quarterstaff Strike 20/0  1\nCulmination I 20/0  1\n")
			runCallback("OnFrame")

			applyComboConfig(10)
			local moreAt10 = getSkillMoreDamage(findSkillIndex("Quarterstaff Strike"))
			local hitAt10 = getAverageHit()

			applyComboConfig(50)
			local moreAt50 = getSkillMoreDamage(findSkillIndex("Quarterstaff Strike"))
			local hitAt50 = getAverageHit()

			assert.are.equals(30, moreAt10)
			assert.are.equals(moreAt10, moreAt50)
			assert.are.equals(hitAt10, hitAt50)
		end)

		it("Culmination II caps combo damage at 20 stacks", function()
			equipQuarterstaff()
			build.skillsTab:PasteSocketGroup("Quarterstaff Strike 20/0  1\nCulmination II 20/0  1\n")
			runCallback("OnFrame")

			applyComboConfig(20)
			local moreAt20 = getSkillMoreDamage(findSkillIndex("Quarterstaff Strike"))
			local hitAt20 = getAverageHit()

			applyComboConfig(50)
			local moreAt50 = getSkillMoreDamage(findSkillIndex("Quarterstaff Strike"))
			local hitAt50 = getAverageHit()

			assert.are.equals(40, moreAt20)
			assert.are.equals(moreAt20, moreAt50)
			assert.are.equals(hitAt20, hitAt50)
		end)
	end)

	it("Test Pinnacle of Power", function()
		build.configTab.input.enemyIsBoss = "None"
		build.configTab.input.usePowerCharges = true
		build.configTab.input.overridePowerCharges = 3
		build.configTab:BuildModList()
		runCallback("OnFrame")

		build.skillsTab:PasteSocketGroup("Fireball 20/0  1")
		runCallback("OnFrame")
		assert.True(build.calcsTab.calcsOutput.FreezeBuildupAvg == 0)
		assert.True(build.calcsTab.calcsOutput.ShockEffectMod == nil)

		build.skillsTab:PasteSocketGroup("Pinnacle of Power 20/0  1")
		runCallback("OnFrame")
		local basePinnacleDamage = build.calcsTab.calcsOutput.TotalDPS
		assert.True(build.calcsTab.calcsOutput.FreezeBuildupAvg > 0)
		assert.True(build.calcsTab.calcsOutput.ShockEffectMod ~= nil)
		assert.are.equals(build.calcsTab.calcsOutput.BuffList, "Pinnacle of Power")


		build.skillsTab:PasteSocketGroup("Pinnacle of Power 20/0  1\nHeightened Charges 1/0 1")
		runCallback("OnFrame")
		-- Heightened Charges should increased the buff effect, therefore Fireball should have more damage than base Pinnacle of Power
		assert.True(build.calcsTab.calcsOutput.TotalDPS > basePinnacleDamage)
	end)

	it("Flame Wall Projectile Buff", function()
		build.skillsTab:PasteSocketGroup("Flame Wall 20/0  1")

		build.configTab.input.flameWallAddedDamage = true
		build.configTab:BuildModList()
		runCallback("OnFrame")

		-- validate Flame Wall buff appears even when the Wall/default skillPart is active
		assert.are.equals("Flame Wall", build.calcsTab.calcsOutput.BuffList)
	end)

	it("Test Ancestral Call - Ancestral Boost calcs", function()
		build.itemsTab:CreateDisplayItemFromRaw([[
			New Item
			Fanatic Greathammer
			Quality: 0
		]])
		build.itemsTab:AddDisplayItem()
		runCallback("OnFrame")

		build.skillsTab:PasteSocketGroup("Boneshatter 20/0  1\nAncestral Call I 1/0  1")
		runCallback("OnFrame")

		assert.True(build.calcsTab.calcsOutput.AvgAncestralCallDamageEffect ~= nil)
		assert.True(build.calcsTab.calcsOutput.AncestralCallUptimeRatio ~= nil)
		assert.are.equal(3, build.calcsTab.calcsOutput.StrikeTargets)
	end)

	it("Test chance to empower additional attacks contributes to average count", function()
		build.itemsTab:CreateDisplayItemFromRaw([[
			New Item
			Wrapped Quarterstaff
			Quality: 0
		]])
		build.itemsTab:AddDisplayItem()
		runCallback("OnFrame")

		build.skillsTab:PasteSocketGroup("Quarterstaff Strike 20/0  1")
		build.skillsTab:PasteSocketGroup("Infernal Cry 20/0  1")
		build.configTab.input.multiplierWarcryPower = 20
		build.configTab.input.customMods = "Warcries have 15% chance to Empower 3 additional Attacks"
		build.configTab:BuildModList()
		runCallback("OnFrame")

		assert.are.equals(2.45, round(build.calcsTab.calcsOutput.InfernalEmpoweredCount, 2))
	end)

	it("Test Combined Ancestral Boosts - Ancestral Empowerment and Fist of War", function()
		build.itemsTab:CreateDisplayItemFromRaw([[
			New Item
			Fanatic Greathammer
			Quality: 0
		]])
		build.itemsTab:AddDisplayItem()
		runCallback("OnFrame")
		build.skillsTab:PasteSocketGroup("Leap Slam 20/0  1\nFist of War I 1/0  1")
		runCallback("OnFrame")
		build.configTab.input.customMods = "every second slam skill you use yourself is ancestrally boosted"
		build.configTab:BuildModList()
		runCallback("OnFrame")
		local fistOfWarOneMaxDmgEffect = build.calcsTab.calcsOutput.MaxAncestralEmpowermentCombinedDamageEffect

		-- test that we are using the calcCombinedAncestralBoost function and the calcSection triggers are correct
		assert.True(build.calcsTab.calcsOutput.AncestralEmpowermentCombinedUptimeRatio ~= nil)
		assert.True(build.calcsTab.calcsOutput.AncestralEmpowermentUptimeRatio == nil)
		assert.True(build.calcsTab.calcsOutput.FistOfWarUptimeRatio == nil)

		newBuild()
		build.itemsTab:CreateDisplayItemFromRaw([[
			New Item
			Fanatic Greathammer
			Quality: 0
		]])
		build.itemsTab:AddDisplayItem()
		runCallback("OnFrame")
		build.skillsTab:PasteSocketGroup("Leap Slam 20/0  1\nFist of War III 1/0  1")
		runCallback("OnFrame")
		build.configTab.input.customMods = "every second slam skill you use yourself is ancestrally boosted"
		build.configTab:BuildModList()
		runCallback("OnFrame")

		-- test doubled effects of Fist of War III with Ancestral Empowerment
		assert.True(fistOfWarOneMaxDmgEffect < build.calcsTab.calcsOutput.MaxAncestralEmpowermentCombinedDamageEffect)
		local expectedAverageEffect = 1 + (build.calcsTab.calcsOutput.MaxAncestralEmpowermentCombinedDamageEffect - 1) * build.calcsTab.calcsOutput.AncestralEmpowermentCombinedUptimeRatio / 100
		assert.are.equals(round(expectedAverageEffect, 4), round(build.calcsTab.calcsOutput.AvgAncestralEmpowermentCombinedDamageEffect, 4))
	end)

	it("calculates effects of parry debuff correctly", function()
		build.itemsTab:CreateDisplayItemFromRaw([[
			Generic EV Shield
			Desert Buckler
			Evasion: 230
			Quality: 20
			LevelReq: 80
		]])
		build.itemsTab:AddDisplayItem()
		runCallback("OnFrame")
		build.skillsTab:PasteSocketGroup("Parry 20/0  1")
		runCallback("OnFrame")
		build.configTab:BuildModList()
		runCallback("OnFrame")
		build.calcsTab:BuildOutput()
		runCallback("OnFrame")

		-- Test general debuff
		local preParryDmg = build.calcsTab.mainOutput.AverageDamage
		build.configTab.configSets[1].input.parryActive = true
		build.configTab:BuildModList()
		build.calcsTab:BuildOutput()
		runCallback("OnFrame")
		local postParryDmg = build.calcsTab.mainOutput.AverageDamage
		assert.True(postParryDmg > preParryDmg, "Damage should be higher with Parry active")
		
		-- Test Magnitude
		build.configTab.input.customMods = "50% increased parried debuff magnitude"
		build.configTab:BuildModList()
		runCallback("OnFrame")
		build.calcsTab:BuildOutput()
		runCallback("OnFrame")
		local incMagnitudeDmg = build.calcsTab.mainOutput.AverageDamage
		assert.True(incMagnitudeDmg > postParryDmg, "Damage should be higher with increased parried debuff magnitude")

		-- Test effect on spells
		build.skillsTab:PasteSocketGroup("Bone Cage 20/0  1")
		runCallback("OnFrame")
		selectActiveSkillById(build.skillsTab.socketGroupList[#build.skillsTab.socketGroupList], "BoneCagePlayer")
		runCallback("OnFrame")
		build.calcsTab:BuildOutput()
		runCallback("OnFrame")
		local withParrySpellDmg = build.calcsTab.mainOutput.AverageDamage
		build.configTab.configSets[1].input.parryActive = false
		build.configTab:BuildModList()
		runCallback("OnFrame")
		build.calcsTab:BuildOutput()
		runCallback("OnFrame")
		local noParrySpellDmg = build.calcsTab.mainOutput.AverageDamage
		assert.equals(withParrySpellDmg, noParrySpellDmg, "Parry should not affect spell damage")
	end)
	
end)
