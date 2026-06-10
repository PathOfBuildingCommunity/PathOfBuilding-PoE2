describe("TestTamedBeastMods", function()
	before_each(function()
		newBuild()
	end)

	local sampleProperties = {
		{
			name = "Monster Modifiers:\n{0}",
			values = {
				{ "[MonsterFlaskRemovalAura1|Siphons Flask Charges]\n[MonsterLifeRegenerationRatePercentage1|Regenerates Life]\nPeriodically unleashes [Cold|Ice]\n[MonsterAdditionalProjectiles1|Additional Projectiles]", 0 },
			},
			displayMode = 3,
		},
	}

	describe("ImportTab.ParseTamedBeastProperties", function()
		it("parses mod-id tokens and resolves display-only lines", function()
			local list = build.importTab:ParseTamedBeastProperties(sampleProperties)

			assert.are.equals(4, #list)
			assert.are.equals("MonsterFlaskRemovalAura1", list[1].modId)
			assert.are.equals("Siphons Flask Charges", list[1].display)
			assert.are.equals("MonsterLifeRegenerationRatePercentage1", list[2].modId)
			-- No leading [ModId|...] token; resolved by display line lookup
			assert.are.equals("Periodically unleashes Ice", list[3].display)
			assert.is_not_nil(list[3].modId)
			assert.are.equals("MonsterAdditionalProjectiles1", list[4].modId)
			for _, entry in ipairs(list) do
				assert.True(entry.enabled)
			end
		end)

		it("keeps unresolvable lines with display text only", function()
			local list = build.importTab:ParseTamedBeastProperties({
				{ values = { { "[MonsterMadeUpModDoesNotExist1|Made Up Mod]", 0 } } },
			})

			assert.are.equals(1, #list)
			assert.is_nil(list[1].modId)
			assert.are.equals("Made Up Mod", list[1].display)
		end)

		it("returns nil for absent or empty input", function()
			assert.is_nil(build.importTab:ParseTamedBeastProperties(nil))
			assert.is_nil(build.importTab:ParseTamedBeastProperties({ }))
		end)
	end)

	describe("SkillsTab persistence", function()
		it("saves tamed beast mods as Gem child elements", function()
			build.skillsTab.skillSets[1].socketGroupList = { {
				enabled = true,
				gemList = { {
					nameSpec = "Companion: Mighty Silverfist",
					level = 20, quality = 0, enabled = true, enableGlobal1 = true, enableGlobal2 = true,
					count = 1, corrupted = false, corruptLevel = 0,
					tamedBeastModList = {
						{ modId = "MonsterDamageGainedAsCold1", enabled = true },
						{ display = "Periodically unleashes Ice", enabled = false },
					},
				} },
			} }

			local xml = { }
			build.skillsTab:Save(xml)

			local gemNode
			for _, skillSetNode in ipairs(xml) do
				if skillSetNode.elem == "SkillSet" then
					for _, skillNode in ipairs(skillSetNode) do
						if skillNode.elem == "Skill" then
							gemNode = skillNode[1]
						end
					end
				end
			end
			assert.is_not_nil(gemNode)
			assert.are.equals("Gem", gemNode.elem)

			local beastModNodes = { }
			for _, child in ipairs(gemNode) do
				if child.elem == "TamedBeastMod" then
					table.insert(beastModNodes, child)
				end
			end
			assert.are.equals(2, #beastModNodes)
			assert.are.equals("MonsterDamageGainedAsCold1", beastModNodes[1].attrib.modId)
			assert.are.equals("true", beastModNodes[1].attrib.enabled)
			assert.is_nil(beastModNodes[2].attrib.modId)
			assert.are.equals("Periodically unleashes Ice", beastModNodes[2].attrib.display)
			assert.are.equals("false", beastModNodes[2].attrib.enabled)
		end)

		it("loads TamedBeastMod elements back onto the gem instance", function()
			local node = { elem = "Skill", attrib = { enabled = "true" },
				{ elem = "Gem", attrib = { nameSpec = "Companion: Mighty Silverfist", level = "20", quality = "0", enabled = "true" },
					{ elem = "TamedBeastMod", attrib = { modId = "MonsterDamageGainedAsCold1", enabled = "true" } },
					{ elem = "TamedBeastMod", attrib = { display = "Periodically unleashes Ice", enabled = "false" } },
				},
			}

			build.skillsTab:LoadSkill(node, 1)

			local socketGroupList = build.skillsTab.skillSets[1].socketGroupList
			local gemInstance = socketGroupList[#socketGroupList].gemList[1]
			assert.is_not_nil(gemInstance.tamedBeastModList)
			assert.are.equals(2, #gemInstance.tamedBeastModList)
			assert.are.equals("MonsterDamageGainedAsCold1", gemInstance.tamedBeastModList[1].modId)
			assert.True(gemInstance.tamedBeastModList[1].enabled)
			assert.is_nil(gemInstance.tamedBeastModList[2].modId)
			assert.are.equals("Periodically unleashes Ice", gemInstance.tamedBeastModList[2].display)
			assert.False(gemInstance.tamedBeastModList[2].enabled)
		end)

		it("loads legacy gems without beast mods as nil", function()
			local node = { elem = "Skill", attrib = { enabled = "true" },
				{ elem = "Gem", attrib = { nameSpec = "Fireball", level = "20", quality = "0", enabled = "true" } },
			}

			build.skillsTab:LoadSkill(node, 1)

			local socketGroupList = build.skillsTab.skillSets[1].socketGroupList
			assert.is_nil(socketGroupList[#socketGroupList].gemList[1].tamedBeastModList)
		end)
	end)

	describe("Calculation wiring", function()
		local beastId = "Metadata/Monsters/Quadrilla/QuadrillaBossMinion1" -- Mighty Silverfist

		local function buildCompanionGroup(tamedBeastModList)
			table.insert(build.beastList, beastId)
			local gemInstance = {
				nameSpec = "Companion: Mighty Silverfist",
				gemId = "Metadata/Items/Gems/SkillGemSummonBeast",
				level = 20, quality = 0, enabled = true, enableGlobal1 = true, enableGlobal2 = true,
				count = 1, corrupted = false, corruptLevel = 0,
				skillMinion = beastId,
				skillMinionCalcs = beastId,
				tamedBeastModList = tamedBeastModList,
			}
			local group = { label = "", enabled = true, gemList = { gemInstance } }
			table.insert(build.skillsTab.socketGroupList, group)
			build.skillsTab:ProcessSocketGroup(group)
			build.mainSocketGroup = #build.skillsTab.socketGroupList
			build.buildFlag = true
			runCallback("OnFrame")
			return gemInstance
		end

		it("applies enabled beast mods to the companion minion", function()
			buildCompanionGroup({ { modId = "MonsterDamageGainedAsCold1", enabled = true } })

			local minion = build.calcsTab.mainEnv.minion
			assert.is_not_nil(minion)
			assert.are.equals(40, minion.modDB:Sum("BASE", nil, "DamageGainAsCold"))
		end)

		it("skips disabled and unresolved beast mods", function()
			local gemInstance = buildCompanionGroup({
				{ modId = "MonsterDamageGainedAsCold1", enabled = false },
				{ display = "Periodically unleashes Ice", enabled = true },
			})

			local minion = build.calcsTab.mainEnv.minion
			assert.is_not_nil(minion)
			assert.are.equals(0, minion.modDB:Sum("BASE", nil, "DamageGainAsCold"))

			gemInstance.tamedBeastModList[1].enabled = true
			build.buildFlag = true
			runCallback("OnFrame")
			assert.are.equals(40, build.calcsTab.mainEnv.minion.modDB:Sum("BASE", nil, "DamageGainAsCold"))
		end)

		it("does not affect companions without beast mods", function()
			buildCompanionGroup(nil)

			local minion = build.calcsTab.mainEnv.minion
			assert.is_not_nil(minion)
			assert.are.equals(0, minion.modDB:Sum("BASE", nil, "DamageGainAsCold"))
		end)

		it("does not apply a stale beast mod list when the gem is not a Companion", function()
			build.skillsTab:PasteSocketGroup("Skeletal Sniper 20/0  1")
			runCallback("OnFrame")
			local srcInstance = build.skillsTab.socketGroupList[1].gemList[1]
			srcInstance.tamedBeastModList = { { modId = "MonsterDamageGainedAsCold1", enabled = true } }
			build.buildFlag = true
			runCallback("OnFrame")

			local minion = build.calcsTab.mainEnv.minion
			assert.is_not_nil(minion)
			assert.are.equals(0, minion.modDB:Sum("BASE", nil, "DamageGainAsCold"))
		end)

		it("applies entries beyond the fourth and creates UI rows for them", function()
			buildCompanionGroup({
				{ modId = "MonsterIncreasedSpeedAura1", enabled = false },
				{ modId = "MonsterLifeRegenerationRatePercentage1", enabled = false },
				{ modId = "MonsterAdditionalProjectiles1", enabled = false },
				{ modId = "MonsterFlaskRemovalAura1", enabled = false },
				{ modId = "MonsterDamageGainedAsCold1", enabled = true },
			})

			assert.are.equals(40, build.calcsTab.mainEnv.minion.modDB:Sum("BASE", nil, "DamageGainAsCold"))

			local skillsTab = build.skillsTab
			skillsTab:SetDisplayGroup(skillsTab.socketGroupList[#skillsTab.socketGroupList])
			skillsTab:UpdateBeastModSlots()
			assert.is_not_nil(skillsTab.beastModSlots[6])
			local slot5 = skillsTab.beastModSlots[5]
			assert.are.equals("MonsterDamageGainedAsCold1", slot5.select.list[slot5.select.selIndex].modId)
		end)
	end)

	describe("Re-import preservation", function()
		local function companionPayload()
			return {
				level = 12,
				equipment = { },
				skills = { {
					support = false,
					typeLine = "Companion: Mighty Silverfist",
					properties = { { name = "Level", values = { { "17", 0 } } } },
					tamedBeastProperties = { {
						name = "Monster Modifiers:\n{0}",
						values = { { "[MonsterDamageGainedAsCold1|Extra Cold Damage]\n[MonsterIncreasedSpeedAura1|Haste Aura]", 0 } },
						displayMode = 3,
					} },
				} },
			}
		end

		it("keeps user enable choices for surviving mods when re-importing", function()
			build.importTab.controls.charImportItemsClearSkills.state = true
			build.importTab.controls.charImportItemsClearItems.state = false
			build.importTab:ImportItemsAndSkills(companionPayload())
			runCallback("OnFrame")

			local gem = build.skillsTab.socketGroupList[1].gemList[1]
			assert.are.equals(2, #gem.tamedBeastModList)
			assert.True(gem.tamedBeastModList[1].enabled)
			gem.tamedBeastModList[1].enabled = false

			build.importTab:ImportItemsAndSkills(companionPayload())
			runCallback("OnFrame")

			gem = build.skillsTab.socketGroupList[1].gemList[1]
			assert.are.equals(2, #gem.tamedBeastModList)
			assert.are.equals("MonsterDamageGainedAsCold1", gem.tamedBeastModList[1].modId)
			assert.False(gem.tamedBeastModList[1].enabled)
			assert.True(gem.tamedBeastModList[2].enabled)
		end)
	end)
end)
