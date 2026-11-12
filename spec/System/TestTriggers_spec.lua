describe("TestTriggers", function()
	-- Select an active skill within a socket group as the main skill
	local function selectSkill(groupIndex, skillIndex)
		local group = build.skillsTab.socketGroupList[groupIndex]
		build.mainSocketGroup = groupIndex
		build.calcsTab.input.skill_number = groupIndex
		group.mainActiveSkill = skillIndex
		group.mainActiveSkillCalcs = skillIndex
		build.buildFlag = true
		build.modFlag = true
		runCallback("OnFrame")
		build.calcsTab:BuildOutput()
		runCallback("OnFrame")
	end

	-- Equipping a weapon inserts a generated default attack group, shifting the indices
	local function groupIndex(label)
		for index, group in ipairs(build.skillsTab.socketGroupList) do
			if group.displayLabel == label then
				return index
			end
		end
	end

	-- The same product reached by a different order of operations
	local function assertNear(expected, actual)
		assert.is_true(math.abs(expected - actual) <= math.abs(expected) * 1e-9,
			("expected %s, got %s"):format(tostring(expected), tostring(actual)))
	end

	local function setConfig(var, value)
		build.configTab.input[var] = value
		build.configTab:BuildModList()
		build.buildFlag = true
		build.modFlag = true
		runCallback("OnFrame")
		build.calcsTab:BuildOutput()
		runCallback("OnFrame")
	end

	before_each(function()
		newBuild()
	end)

	teardown(function()
		-- newBuild() takes care of resetting everything in setup()
	end)

	describe("Meta gem Energy", function()
		it("Maximum Energy is 100 per second of base cast time of the socketed skill", function()
			build.skillsTab:PasteSocketGroup("Cast on Dodge 20/0  1\nSpark 20/0  1")
			runCallback("OnFrame")
			selectSkill(1, 2)
			-- Spark has a 0.7 second base cast time and no added total cast time
			assert.are.equals(70, build.calcsTab.mainOutput.MaxEnergy)
		end)

		it("Modifiers to total cast time count double towards maximum Energy", function()
			build.skillsTab:PasteSocketGroup("Cast on Dodge 20/0  1\nComet 20/0  1")
			runCallback("OnFrame")
			selectSkill(1, 2)
			-- Comet is 1.00s base cast time plus 1.00s of added total cast time
			assert.are.equals(100 * 1 + 200 * 1, build.calcsTab.mainOutput.MaxEnergy)
		end)

		it("Maximum Energy is the total of every socketed skill", function()
			build.skillsTab:PasteSocketGroup("Cast on Dodge 20/0  1\nComet 20/0  1\nSpark 20/0  1")
			runCallback("OnFrame")
			selectSkill(1, 2)
			assert.are.equals(300 + 70, build.calcsTab.mainOutput.MaxEnergy)
		end)

		it("All socketed skills trigger at the same rate", function()
			build.skillsTab:PasteSocketGroup("Cast on Dodge 20/0  1\nComet 20/0  1\nSpark 20/0  1")
			runCallback("OnFrame")
			selectSkill(1, 2)
			local cometRate = build.calcsTab.mainOutput.SkillTriggerRate
			selectSkill(1, 3)
			assert.are.equals(cometRate, build.calcsTab.mainOutput.SkillTriggerRate)
		end)

		it("only reports a trigger rate cap for skills with a cooldown", function()
			build.skillsTab:PasteSocketGroup("Cast on Dodge 20/0  1\nSpark 20/0  1")
			runCallback("OnFrame")
			selectSkill(1, 2)
			assert.is_nil(build.calcsTab.mainOutput.TriggerRateCap)
		end)

		it("falls back to self-cast for meta gems that are not supported", function()
			build.skillsTab:PasteSocketGroup("Cast on Elemental Ailment 20/0  1\nComet 20/0  1")
			runCallback("OnFrame")
			selectSkill(1, 2)
			local mainSkill = build.calcsTab.mainEnv.player.mainSkill
			assert.is_nil(mainSkill.skillData.triggered)
			assert.are.equals("Cast on Elemental Ailment is not supported yet", mainSkill.infoMessage)
			assert.are.equals("DPS reported assuming Self-Cast", mainSkill.infoMessage2)
		end)

		it("only parses Energy modifiers that apply to meta skills", function()
			local mods = modLib.parseMod("Meta Skills gain 25% increased Energy while on Full Mana")
			assert.are.equals("EnergyGenerated", mods[1].name)
			assert.are.equals(25, mods[1].value)
			for _, line in ipairs({ "Invocated skills have 30% increased Maximum Energy", "25% chance for Trigger skills to refund half of Energy Spent" }) do
				for _, mod in ipairs(modLib.parseMod(line) or {}) do
					assert.are_not.equals("EnergyGenerated", mod.name)
				end
			end
		end)
	end)

	describe("Cast on Dodge", function()
		it("gains 2 Energy per whole metre travelled while dodge rolling", function()
			build.skillsTab:PasteSocketGroup("Cast on Dodge 20/0  1\nSpark 20/0  1")
			runCallback("OnFrame")
			selectSkill(1, 2)
			setConfig("dodgeRollsPerSecond", 1)
			-- 4.6m base distance rounds down to 4m, 2 Energy each, +57% from gem level 20
			assertNear(2 * 1.57 * 4, build.calcsTab.mainOutput.EnergyPerSecond)
			-- 70 Energy takes 23 metres, carried over between rolls. Energy past the maximum is discarded
			assertNear(4 / 23, build.calcsTab.mainOutput.SkillTriggerRate)
		end)

		it("adds the buff's dodge roll distance from additional quality effects", function()
			build.spec:SelectClass(build.spec.tree.classNameMap.Mercenary)
			for ascendClassId, ascendClass in pairs(build.spec.curClass.classes) do
				if ascendClass.name == "Gemling Legionnaire" then
					build.spec:SelectAscendClass(ascendClassId)
					break
				end
			end
			-- Advanced Thaumaturgy
			local node = build.spec.nodes[14429]
			node.alloc = true
			build.spec.allocNodes[node.id] = node
			build.skillsTab:PasteSocketGroup("Cast on Dodge 20/20  1\nSpark 20/0  1")
			runCallback("OnFrame")
			selectSkill(1, 2)
			setConfig("dodgeRollsPerSecond", 1)
			-- +1 metre from 20% quality, 5.6m rounds down to 5m
			assertNear(2 * 5 * 1.57, build.calcsTab.mainOutput.EnergyPerSecond)
		end)

		it("scales linearly with the number of dodge rolls per second", function()
			build.skillsTab:PasteSocketGroup("Cast on Dodge 20/0  1\nSpark 20/0  1")
			runCallback("OnFrame")
			selectSkill(1, 2)
			setConfig("dodgeRollsPerSecond", 1)
			local baseRate = build.calcsTab.mainOutput.SkillTriggerRate
			setConfig("dodgeRollsPerSecond", 2)
			assert.are.equals(baseRate * 2, build.calcsTab.mainOutput.SkillTriggerRate)
		end)

		it("does not lose a metre to floating point error", function()
			build.configTab.input.customMods = "+0.1 metres to Dodge Roll distance\n+0.3 metres to Dodge Roll distance"
			build.skillsTab:PasteSocketGroup("Cast on Dodge 20/0  1\nSpark 20/0  1")
			runCallback("OnFrame")
			selectSkill(1, 2)
			setConfig("dodgeRollsPerSecond", 1)
			-- 4.6 + 0.1 + 0.3 sums to 4.999... in floating point
			assertNear(2 * 5 * 1.57, build.calcsTab.mainOutput.EnergyPerSecond)
		end)

		it("scales distance with the square root of movement speed", function()
			build.configTab.input.customMods = "44% increased Movement Speed"
			build.skillsTab:PasteSocketGroup("Cast on Dodge 20/0  1\nSpark 20/0  1")
			runCallback("OnFrame")
			selectSkill(1, 2)
			setConfig("dodgeRollsPerSecond", 1)
			-- 4.6m * sqrt(1.44) = 5.52m rounds down to 5m
			assertNear(2 * 5 * 1.57, build.calcsTab.mainOutput.EnergyPerSecond)
		end)

		it("applies dodge roll distance as if you have Dodge Rolled Recently", function()
			build.configTab.input.customMods = "+1 metre to Dodge Roll distance if you've Dodge Rolled Recently\n+2 metres to Dodge Roll distance if you haven't Dodge Rolled Recently"
			build.skillsTab:PasteSocketGroup("Cast on Dodge 20/0  1\nSpark 20/0  1")
			runCallback("OnFrame")
			selectSkill(1, 2)
			setConfig("dodgeRollsPerSecond", 1)
			-- 4.6m + 1m rounds down to 5m
			assertNear(2 * 5 * 1.57, build.calcsTab.mainOutput.EnergyPerSecond)
		end)

		it("drives the triggered skill's cast rate", function()
			build.skillsTab:PasteSocketGroup("Cast on Dodge 20/0  1\nSpark 20/0  1")
			runCallback("OnFrame")
			selectSkill(1, 2)
			setConfig("dodgeRollsPerSecond", 1)
			local output = build.calcsTab.mainOutput
			assert.is_true(output.SkillTriggerRate > 0)
			assert.are.equals(output.SkillTriggerRate, output.Speed)
		end)
	end)

	describe("Energy Retention", function()
		-- Cast on Dodge with no added distance gains 4 metres per roll at 3.14 Energy per metre
		local energyPerMetre = 2 * 1.57

		it("refunds half of the triggered skill's Energy cost on 35% of triggers", function()
			build.skillsTab:PasteSocketGroup("Cast on Dodge 20/0  1\nSpark 20/0  1\nEnergy Retention 1/0  1")
			runCallback("OnFrame")
			selectSkill(1, 2)
			setConfig("dodgeRollsPerSecond", 1)
			-- 70 Energy takes 23 metres, or 12 metres after a refund of 35
			local metres = 0.65 * math.ceil(70 / energyPerMetre) + 0.35 * math.ceil(35 / energyPerMetre)
			assertNear(4 / metres, build.calcsTab.mainOutput.SkillTriggerRate)
		end)

		it("rolls the refund separately for each triggered skill", function()
			build.skillsTab:PasteSocketGroup("Cast on Dodge 20/0  1\nComet 20/0  1\nSpark 20/0  1\nEnergy Retention 1/0  1")
			runCallback("OnFrame")
			selectSkill(1, 2)
			setConfig("dodgeRollsPerSecond", 1)
			-- Comet refunds 150 and Spark refunds 35 of the 370 maximum Energy
			local metres = 0
			for _, outcome in ipairs({ { 0, 0.65 * 0.65 }, { 35, 0.65 * 0.35 }, { 150, 0.35 * 0.65 }, { 185, 0.35 * 0.35 } }) do
				metres = metres + outcome[2] * math.ceil((370 - outcome[1]) / energyPerMetre)
			end
			assertNear(4 / metres, build.calcsTab.mainOutput.SkillTriggerRate)
		end)

		it("supports the item modifiers", function()
			local mods, extra = modLib.parseMod("7% chance for Trigger skills to refund half of Energy Spent")
			assert.is_nil(extra)
			assert.are.equals("EnergyRefundChance", mods[1].name)
			assert.are.equals(7, mods[1].value)
			assert.are.equals(SkillType.Triggers, mods[1][1].skillType)

			build.configTab.input.customMods = "25% chance for Trigger skills to refund half of Energy Spent"
			build.skillsTab:PasteSocketGroup("Cast on Dodge 20/0  1\nSpark 20/0  1")
			runCallback("OnFrame")
			selectSkill(1, 2)
			setConfig("dodgeRollsPerSecond", 1)
			local metres = 0.75 * math.ceil(70 / energyPerMetre) + 0.25 * math.ceil(35 / energyPerMetre)
			assertNear(4 / metres, build.calcsTab.mainOutput.SkillTriggerRate)

			build.configTab.input.customMods = "Trigger skills refund half of Energy spent"
			setConfig("dodgeRollsPerSecond", 1)
			assertNear(4 / math.ceil(35 / energyPerMetre), build.calcsTab.mainOutput.SkillTriggerRate)
		end)

		it("caps the refund chance at 100%", function()
			build.configTab.input.customMods = "Trigger skills refund half of Energy spent"
			build.skillsTab:PasteSocketGroup("Cast on Dodge 20/0  1\nSpark 20/0  1\nEnergy Retention 1/0  1")
			runCallback("OnFrame")
			selectSkill(1, 2)
			setConfig("dodgeRollsPerSecond", 1)
			assertNear(4 / math.ceil(35 / energyPerMetre), build.calcsTab.mainOutput.SkillTriggerRate)
		end)
	end)

	describe("Cast on Critical", function()
		local function setupCastOnCritical()
			build.skillsTab:PasteSocketGroup("Spark 20/0  1")
			runCallback("OnFrame")
			build.skillsTab:PasteSocketGroup("Cast on Critical 20/0  1\nComet 20/0  1")
			runCallback("OnFrame")
			selectSkill(2, 2)
		end

		it("finds the Critical Hit source and reports it", function()
			setupCastOnCritical()
			assert.are.equals("Cast on Critical's Trigger: Spark", build.calcsTab.mainEnv.player.mainSkill.infoMessage)
			assert.is_true(build.calcsTab.mainOutput.SkillTriggerRate > 0)
		end)

		it("gains Energy per Monster Power scaled by the hit's share of the Ailment Threshold", function()
			setupCastOnCritical()
			setConfig("monsterPower", 20)
			local output = build.calcsTab.mainOutput

			-- Recreate the source's contribution from its own cached output
			local env = build.calcsTab.mainEnv
			local sourceUUID = env.player.mainSkill.skillData.triggerSourceUUID
			local cached = GlobalCache.cachedData[env.mode][sourceUUID]
			local critDamage = 0
			for _, damageType in ipairs({"Physical", "Lightning", "Cold", "Fire", "Chaos"}) do
				critDamage = critDamage + (cached.Env.player.output[damageType.."StoredCritAvg"] or 0)
			end
			local threshold = build.data.monsterAilmentThresholdTable[env.enemyLevel]
			local critsPerSecond = (cached.HitSpeed or cached.Speed) * cached.CritChance / 100
			-- Energy gains round down to 0.01
			local energyPerCrit = math.floor(20 * critDamage / threshold * 1.57 * 100 + 1e-9) / 100

			assertNear(energyPerCrit * critsPerSecond, output.EnergyPerSecond)
			assertNear(critsPerSecond / math.ceil(300 / energyPerCrit), output.SkillTriggerRate)
		end)

		it("scales with Monster Power", function()
			setupCastOnCritical()
			setConfig("monsterPower", 200)
			local baseRate = build.calcsTab.mainOutput.SkillTriggerRate
			setConfig("monsterPower", 100)
			assert.is_true(build.calcsTab.mainOutput.SkillTriggerRate < baseRate)
		end)

		it("applies the meta gem's 20% less Damage to socketed skills", function()
			setupCastOnCritical()
			local mainSkill = build.calcsTab.mainEnv.player.mainSkill
			assert.are.equals(0.8, mainSkill.skillModList:More(mainSkill.skillCfg, "Damage"))
		end)

		it("falls back to self-cast when nothing can Critically Hit", function()
			build.skillsTab:PasteSocketGroup("Cast on Critical 20/0  1\nComet 20/0  1")
			runCallback("OnFrame")
			selectSkill(1, 2)
			local mainSkill = build.calcsTab.mainEnv.player.mainSkill
			assert.is_nil(mainSkill.skillData.triggered)
			assert.are.equals("No Cast on Critical Triggering Skill Found", mainSkill.infoMessage)
			assert.are.equals("DPS reported assuming Self-Cast", mainSkill.infoMessage2)
		end)

		it("ignores hits from skills used by totems", function()
			build.skillsTab:PasteSocketGroup("Spell Totem 20/0  1\nSpark 20/0  1")
			runCallback("OnFrame")
			build.skillsTab:PasteSocketGroup("Cast on Critical 20/0  1\nComet 20/0  1")
			runCallback("OnFrame")
			selectSkill(2, 2)
			assert.are.equals("No Cast on Critical Triggering Skill Found", build.calcsTab.mainEnv.player.mainSkill.infoMessage)
		end)

		it("counts every hit of the source's DPS multiplier", function()
			setupCastOnCritical()
			local baseEnergy = build.calcsTab.mainOutput.EnergyPerSecond
			build.configTab.input.customMods = "100% more DPS"
			setConfig("monsterPower", nil)
			assertNear(baseEnergy * 2, build.calcsTab.mainOutput.EnergyPerSecond)
		end)
	end)

	describe("Spell on Melee Hit", function()
		local function setupThundergodsWrath()
			build.itemsTab:CreateDisplayItemFromRaw([[
				New Item
				Wrapped Quarterstaff
				Adds 200 to 300 Physical Damage
			]])
			build.itemsTab:AddDisplayItem()
			runCallback("OnFrame")
			build.skillsTab:PasteSocketGroup("Quarterstaff Strike 20/0  1")
			runCallback("OnFrame")
			build.skillsTab:PasteSocketGroup("Thundergod's Wrath 20/0  1\nSpark 20/0  1")
			runCallback("OnFrame")
			selectSkill(groupIndex("Thundergod's Wrath, Spark"), 2)
		end

		it("gains Energy from the melee attack that hits", function()
			setupThundergodsWrath()
			assert.are.equals("Thundergod's Wrath's Trigger: Quarterstaff Strike", build.calcsTab.mainEnv.player.mainSkill.infoMessage)
			assert.is_true(build.calcsTab.mainOutput.SkillTriggerRate > 0)
		end)

		it("gains 3 Energy per Monster Power scaled by the hit's share of the Ailment Threshold", function()
			setupThundergodsWrath()
			setConfig("monsterPower", 20)
			local env = build.calcsTab.mainEnv
			local cached = GlobalCache.cachedData[env.mode][env.player.mainSkill.skillData.triggerSourceUUID]
			local sourceOutput = cached.Env.player.output
			local damage = 0
			for _, damageType in ipairs({"Physical", "Lightning", "Cold", "Fire", "Chaos"}) do
				damage = damage + (sourceOutput.MainHand[damageType.."StoredCombinedAvg"] or 0)
			end
			local threshold = build.data.monsterAilmentThresholdTable[env.enemyLevel]
			local hitsPerSecond = (cached.HitSpeed or cached.Speed) * sourceOutput.HitChance / 100
			local energyPerHit = math.floor(3 * 20 * damage / threshold * 1.57 * 100 + 1e-9) / 100
			assertNear(energyPerHit * hitsPerSecond, build.calcsTab.mainOutput.EnergyPerSecond)
			assertNear(hitsPerSecond / math.ceil(70 / energyPerHit), build.calcsTab.mainOutput.SkillTriggerRate)
		end)

		it("ignores sources that are not melee attacks", function()
			build.skillsTab:PasteSocketGroup("Spark 20/0  1")
			runCallback("OnFrame")
			build.skillsTab:PasteSocketGroup("Thundergod's Wrath 20/0  1\nSpark 20/0  1")
			runCallback("OnFrame")
			selectSkill(groupIndex("Thundergod's Wrath, Spark"), 2)
			assert.are.equals("No Thundergod's Wrath Triggering Skill Found", build.calcsTab.mainEnv.player.mainSkill.infoMessage)
		end)
	end)

	describe("Cast on Block", function()
		local function setupCastOnBlock()
			build.itemsTab:CreateDisplayItemFromRaw([[
				New Item
				Effigial Tower Shield
				Quality: 0
			]])
			build.itemsTab:AddDisplayItem()
			runCallback("OnFrame")
			build.skillsTab:PasteSocketGroup("Cast on Block 20/0  1\nSpark 20/0  1")
			runCallback("OnFrame")
			selectSkill(groupIndex("Cast on Block, Spark"), 2)
		end

		it("gains a flat 25 Energy per Block, with no Monster Power term", function()
			setupCastOnBlock()
			local blockChance = build.calcsTab.mainOutput.BlockChance
			assert.is_true(blockChance > 0)
			-- 25 Energy, +57% from gem level 20, at the default 700ms enemy attack time
			local expected = 25 * 1.57 * (1000 / 700) * blockChance / 100
			assertNear(expected, build.calcsTab.mainOutput.EnergyPerSecond)
		end)

		it("is unaffected by Monster Power", function()
			setupCastOnBlock()
			setConfig("monsterPower", 20)
			local baseRate = build.calcsTab.mainOutput.SkillTriggerRate
			setConfig("monsterPower", 1)
			assert.are.equals(baseRate, build.calcsTab.mainOutput.SkillTriggerRate)
		end)

		it("scales with how often the enemy attacks", function()
			setupCastOnBlock()
			setConfig("enemySpeed", 700)
			local baseRate = build.calcsTab.mainOutput.SkillTriggerRate
			setConfig("enemySpeed", 350)
			assertNear(baseRate * 2, build.calcsTab.mainOutput.SkillTriggerRate)
		end)

		it("falls back to self-cast when the enemy attack time is 0", function()
			setupCastOnBlock()
			setConfig("enemySpeed", 0)
			local mainSkill = build.calcsTab.mainEnv.player.mainSkill
			assert.is_nil(mainSkill.skillData.triggered)
			assert.are.equals("Cast on Block gains no Energy from Blocks", mainSkill.infoMessage)
		end)
	end)

	describe("Cast on Charm Use", function()
		it("gains 2 Energy per Charm Charge used", function()
			build.skillsTab:PasteSocketGroup("Cast on Charm Use 20/0  1\nSpark 20/0  1")
			runCallback("OnFrame")
			selectSkill(groupIndex("Cast on Charm Use, Spark"), 2)
			setConfig("multiplierCharmChargesUsedPerSecond", 10)
			assertNear(2 * 1.57 * 10, build.calcsTab.mainOutput.EnergyPerSecond)
		end)
	end)
end)
