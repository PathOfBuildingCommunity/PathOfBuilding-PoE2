describe("TestHeavyStun", function()
	before_each(function()
		newBuild()
	end)

	teardown(function()
		-- newBuild() takes care of resetting everything in setup()
	end)

	local function equipMace()
		build.itemsTab:CreateDisplayItemFromRaw([[
			New Item
			Felled Greatclub
		]])
		build.itemsTab:AddDisplayItem()
	end

	local function setConfig(input, customMods)
		for var, val in pairs(input) do
			build.configTab.input[var] = val
		end
		build.configTab.input.customMods = customMods or ""
		build.configTab:BuildModList()
		runCallback("OnFrame")
	end

	local function setupMaceStrike()
		equipMace()
		build.skillsTab:PasteSocketGroup("skillId:Melee2HMacePlayer Mace Strike 20/0  1")
		build.mainSocketGroup = 1
	end

	local function mainSkill()
		return build.calcsTab.mainEnv.player.mainSkill
	end

	describe("Crushing Blows", function()
		it("parses Your Hits are Crushing Blows", function()
			setupMaceStrike()
			setConfig({ }, "Your Hits are Crushing Blows")

			assert.is_true(mainSkill().skillModList:Flag(mainSkill().skillCfg, "CrushingBlows"))
		end)

		it("makes Syzygy hits Crushing Blows only against Ignited and Fully Armour Broken enemies", function()
			equipMace()
			build.skillsTab:PasteSocketGroup("Earthquake 20/0  1\nSyzygy 1/0  1")
			setConfig({ })
			assert.is_true(not mainSkill().skillModList:Flag(mainSkill().skillCfg, "CrushingBlows"))

			setConfig({ conditionEnemyIgnited = true, conditionEnemyArmourBroken = true })
			assert.is_true(mainSkill().skillModList:Flag(mainSkill().skillCfg, "CrushingBlows"))
		end)
	end)

	describe("configuration", function()
		it("loads the old Heavy Stunned checkbox as Always", function()
			build.configTab:Load({ attrib = { }, { elem = "Input", attrib = { name = "conditionEnemyHeavyStunned", boolean = "true" } } }, "test")

			assert.are.equals("ALWAYS", build.configTab.configSets[1].input.enemyHeavyStunMode)
			assert.is_nil(build.configTab.configSets[1].input.conditionEnemyHeavyStunned)
		end)

		it("shows the uptime field only for Custom %", function()
			setupMaceStrike()
			local stunMod = "100% more Damage against Heavy Stunned Enemies"
			local control = build.configTab.varControls.enemyHeavyStunUptime

			setConfig({ enemyHeavyStunMode = "CALCULATED" }, stunMod)
			assert.is_false(control.shown())

			setConfig({ enemyHeavyStunMode = "CUSTOM" }, stunMod)
			assert.is_true(control.shown())
		end)

		it("treats the enemy as Heavy Stunned all the time for Always", function()
			setupMaceStrike()
			local stunMod = "100% more Damage against Heavy Stunned Enemies"

			setConfig({ enemyHeavyStunMode = "NONE" }, stunMod)
			local notStunnedHit = build.calcsTab.mainOutput.AverageDamage
			setConfig({ enemyHeavyStunMode = "ALWAYS" }, stunMod)

			assert.are.equals(round(notStunnedHit * 2, 4), round(build.calcsTab.mainOutput.AverageDamage, 4))
		end)
	end)

	describe("uptime blend", function()
		local stunMod = "100% more Damage against Heavy Stunned Enemies\nAdds 100 to 100 Physical Damage to Attacks"

		local function numericOutputs(output)
			local values = { }
			for stat, value in pairs(output) do
				if type(value) == "number" then
					values[stat] = value
				end
			end
			for _, hand in ipairs({ "MainHand", "OffHand" }) do
				for stat, value in pairs(output[hand] or { }) do
					if type(value) == "number" then
						values[hand.."."..stat] = value
					end
				end
			end
			return values
		end

		local function assertSameOutputs(expected, actual)
			for stat, value in pairs(expected) do
				assert.are.equals(stat.."="..tostring(value), stat.."="..tostring(actual[stat]))
			end
		end

		it("averages damage against a Heavy Stunned and a normal enemy by the custom uptime", function()
			setupMaceStrike()
			setConfig({ enemyHeavyStunMode = "NONE" }, stunMod)
			local normalDPS = build.calcsTab.mainOutput.CombinedDPS
			setConfig({ enemyHeavyStunMode = "ALWAYS" }, stunMod)
			local stunnedDPS = build.calcsTab.mainOutput.CombinedDPS
			assert.is_true(stunnedDPS > normalDPS)

			setConfig({ enemyHeavyStunMode = "CUSTOM", enemyHeavyStunUptime = 40 }, stunMod)

			assert.are.equals(round(0.4 * stunnedDPS + 0.6 * normalDPS, 6), round(build.calcsTab.mainOutput.CombinedDPS, 6))
		end)

		it("matches No at 0% and Always at 100% custom uptime", function()
			setupMaceStrike()
			setConfig({ enemyHeavyStunMode = "NONE" }, stunMod)
			local normal = numericOutputs(build.calcsTab.mainOutput)
			setConfig({ enemyHeavyStunMode = "ALWAYS" }, stunMod)
			local stunned = numericOutputs(build.calcsTab.mainOutput)

			setConfig({ enemyHeavyStunMode = "CUSTOM", enemyHeavyStunUptime = 0 }, stunMod)
			assertSameOutputs(normal, numericOutputs(build.calcsTab.mainOutput))
			setConfig({ enemyHeavyStunMode = "CUSTOM", enemyHeavyStunUptime = 100 }, stunMod)
			assert.are.equals(round(stunned.CombinedDPS, 6), round(build.calcsTab.mainOutput.CombinedDPS, 6))
		end)

		it("does not apply offence mods twice when blending", function()
			equipMace()
			build.skillsTab:PasteSocketGroup("skillId:Melee2HMacePlayer Mace Strike 20/0  1\nRuthless 1/0  1")
			build.mainSocketGroup = 1
			setConfig({ enemyHeavyStunMode = "NONE" })
			local normal = numericOutputs(build.calcsTab.mainOutput)

			setConfig({ enemyHeavyStunMode = "CUSTOM", enemyHeavyStunUptime = 50 })

			assertSameOutputs(normal, numericOutputs(build.calcsTab.mainOutput))
		end)

		it("does not apply spell offence mods twice when blending", function()
			build.skillsTab:PasteSocketGroup("Fireball 20/0  1")
			build.mainSocketGroup = 1
			setConfig({ enemyHeavyStunMode = "NONE" })
			local normal = numericOutputs(build.calcsTab.mainOutput)

			setConfig({ enemyHeavyStunMode = "CUSTOM", enemyHeavyStunUptime = 50 })

			assertSameOutputs(normal, numericOutputs(build.calcsTab.mainOutput))
		end)

		it("does not apply minion offence mods twice when blending", function()
			build.skillsTab:PasteSocketGroup("Skeletal Sniper 20/0  1")
			build.mainSocketGroup = 1
			setConfig({ enemyHeavyStunMode = "NONE" })
			local normal = numericOutputs(build.calcsTab.mainEnv.minion.output)

			setConfig({ enemyHeavyStunMode = "CUSTOM", enemyHeavyStunUptime = 50 })

			assertSameOutputs(normal, numericOutputs(build.calcsTab.mainEnv.minion.output))
		end)

		it("averages damage by the calculated uptime", function()
			setupMaceStrike()
			local enemy = { enemyIsBoss = "None", enemyLevel = 20 }
			enemy.enemyHeavyStunMode = "NONE"
			setConfig(enemy, stunMod)
			local normalDPS = build.calcsTab.mainOutput.CombinedDPS
			enemy.enemyHeavyStunMode = "ALWAYS"
			setConfig(enemy, stunMod)
			local stunnedDPS = build.calcsTab.mainOutput.CombinedDPS

			enemy.enemyHeavyStunMode = "CALCULATED"
			setConfig(enemy, stunMod)
			local output = build.calcsTab.mainOutput

			assert.is_true(output.HeavyStunUptime > 0 and output.HeavyStunUptime < 100)
			assert.are.equals(round(normalDPS + (stunnedDPS - normalDPS) * output.HeavyStunUptime / 100, 6), round(output.CombinedDPS, 6))
		end)

		it("leaves the enemy not Heavy Stunned after blending", function()
			setupMaceStrike()
			setConfig({ enemyHeavyStunMode = "CUSTOM", enemyHeavyStunUptime = 50 }, stunMod)

			assert.is_true(not build.calcsTab.mainEnv.enemy.modDB:Flag(nil, "Condition:HeavyStunned"))
		end)
	end)

	describe("calculated uptime", function()
		-- A normal level 20 enemy takes about 27% Heavy Stun buildup per hit from this mace
		local baseMods = "Adds 100 to 100 Physical Damage to Attacks"

		local function calculate(customMods, enemy)
			local input = { enemyHeavyStunMode = "CALCULATED", enemyIsBoss = "None", enemyLevel = 20, conditionEnemyRareOrUnique = false }
			for var, val in pairs(enemy or { }) do
				input[var] = val
			end
			setConfig(input, baseMods .. "\n" .. (customMods or ""))
			return build.calcsTab.mainOutput
		end

		local function hitRate(output)
			return (output.HitSpeed or output.Speed) * output.DpsMultiplier * output.HitChance / 100
		end

		before_each(function()
			setupMaceStrike()
		end)

		it("needs enough hits to fill the Heavy Stun bar", function()
			local output = calculate()

			assert.is_true(output.HeavyStunBuildupAvg > 10 and output.HeavyStunBuildupAvg < 50)
			assert.are.equals(math.ceil(100 / output.HeavyStunBuildupAvg), output.HitsToHeavyStun)
		end)

		it("needs fewer hits with more Stun buildup", function()
			local base = calculate()
			local baseHits = base.HitsToHeavyStun
			local output = calculate("200% increased Stun Buildup")

			assert.is_true(output.HitsToHeavyStun < baseHits)
			assert.are.equals(math.ceil(100 / output.HeavyStunBuildupAvg), output.HitsToHeavyStun)
		end)

		it("reaches the Heavy Stun sooner with more attack speed", function()
			local base = calculate()
			local baseHits, baseTime, baseUptime = base.HitsToHeavyStun, base.TimeToHeavyStun, base.HeavyStunUptime
			local output = calculate("50% increased Attack Speed")

			assert.are.equals(baseHits, output.HitsToHeavyStun)
			assert.are.equals(round(output.HitsToHeavyStun / hitRate(output), 6), round(output.TimeToHeavyStun, 6))
			assert.is_true(output.TimeToHeavyStun < baseTime)
			assert.is_true(output.HeavyStunUptime > baseUptime)
		end)

		it("keeps the enemy Heavy Stunned longer with more Stun duration", function()
			local base = calculate()
			local baseUptime = base.HeavyStunUptime
			assert.are.equals(2, base.HeavyStunDuration)

			local output = calculate("100% increased Stun Duration")

			assert.are.equals(4, output.HeavyStunDuration)
			assert.is_true(output.HeavyStunUptime > baseUptime)
		end)

		it("counts the chance to double Stun duration as an average", function()
			local output = calculate("25% chance to double Stun Duration")

			assert.are.equals(2.5, output.HeavyStunDuration)
		end)

		it("is the Heavy Stun duration over the whole cycle", function()
			local output = calculate()
			local expected = output.HeavyStunDuration / (output.HeavyStunDuration + output.HitsToHeavyStun / hitRate(output)) * 100

			assert.are.equals(round(expected, 6), round(output.HeavyStunUptime, 6))
			assert.are.equals(round(output.HitsToHeavyStun / hitRate(output), 6), round(output.TimeToHeavyStun, 6))
		end)

		it("Heavy Stuns a Primed normal enemy with the next Crushing Blow", function()
			local output = calculate("Your Hits are Crushing Blows")
			local buildup = output.HeavyStunBuildupAvg

			assert.are.equals(math.min(math.ceil(100 / buildup), math.ceil(40 / buildup) + 1), output.HitsToHeavyStun)
			assert.are.equals(3, output.HitsToHeavyStun)
		end)

		it("uses the Primed threshold of rare and unique enemies for Crushing Blows", function()
			local rare = calculate("Your Hits are Crushing Blows", { conditionEnemyRareOrUnique = true })
			assert.are.equals(math.min(math.ceil(100 / rare.HeavyStunBuildupAvg), math.ceil(60 / rare.HeavyStunBuildupAvg) + 1), rare.HitsToHeavyStun)

			local unique = calculate("Your Hits are Crushing Blows\n1000% increased Stun Buildup", { enemyIsBoss = "Boss" })
			assert.are.equals(math.min(math.ceil(100 / unique.HeavyStunBuildupAvg), math.ceil(70 / unique.HeavyStunBuildupAvg) + 1), unique.HitsToHeavyStun)
		end)

		it("estimates the uptime when the enemy is not Heavy Stunned, but not when it always is", function()
			assert.is_true(calculate(nil, { enemyHeavyStunMode = "NONE" }).HeavyStunUptime > 0)

			assert.is_nil(calculate(nil, { enemyHeavyStunMode = "ALWAYS" }).HitsToHeavyStun)
		end)

		it("explains the uptime in the Calcs tab", function()
			calculate("Your Hits are Crushing Blows")
			build.calcsTab:BuildOutput()

			assert.is_not_nil(build.calcsTab.calcsEnv.player.breakdown.HeavyStunUptime)
			assert.is_not_nil(build.calcsTab.calcsEnv.player.breakdown.HitsToHeavyStun)
			assert.is_not_nil(build.calcsTab.calcsEnv.player.breakdown.HeavyStunDuration)
		end)
	end)
end)
