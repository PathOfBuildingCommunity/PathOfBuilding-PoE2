describe("TestSkills", function()
	before_each(function()
		newBuild()
	end)

	teardown(function()
		-- newBuild() takes care of resetting everything in setup()
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
		build.skillsTab:PasteSocketGroup("Flammability 20/0  1\n")
		runCallback("OnFrame")

		local curseList = build.calcsTab.calcsOutput.CurseList
		assert.True(curseList:match("Flammability") ~= nil and curseList:match("Elemental Weakness") ~= nil)
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
		assert.are.equals(3, arcSkill.skillModList:Sum("BASE", arcSkill.skillCfg, "GemSupportLevel"))
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
end)