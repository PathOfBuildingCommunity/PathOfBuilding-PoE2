describe("TestCompanionFullDPS", function()
	before_each(function()
		newBuild()
	end)

	-- Mighty Silverfist has exactly two attacks with skill data:
	-- [1] MeleeAtAnimationSpeedUnique (Basic Attack), [2] GAQuadrillaBossRectSlam (Pillar Slam)
	local beastId = "Metadata/Monsters/Quadrilla/QuadrillaBossMinion1"
	local meleeId = "MeleeAtAnimationSpeedUnique"
	local slamId = "GAQuadrillaBossRectSlam"

	local function buildCompanionGroup(fullDPSMinionSkills)
		table.insert(build.beastList, beastId)
		local gemInstance = {
			nameSpec = "Companion: Mighty Silverfist",
			gemId = "Metadata/Items/Gems/SkillGemSummonBeast",
			level = 20, quality = 0, enabled = true, enableGlobal1 = true, enableGlobal2 = true,
			count = 1, corrupted = false, corruptLevel = 0,
			skillMinion = beastId,
			skillMinionCalcs = beastId,
			fullDPSMinionSkills = fullDPSMinionSkills,
		}
		local group = { label = "", enabled = true, includeInFullDPS = true, gemList = { gemInstance } }
		table.insert(build.skillsTab.socketGroupList, group)
		build.skillsTab:ProcessSocketGroup(group)
		build.mainSocketGroup = #build.skillsTab.socketGroupList
		build.buildFlag = true
		runCallback("OnFrame")
		return gemInstance, group
	end

	local function companionEntries()
		local entries = { }
		for _, entry in ipairs(build.calcsTab.mainOutput.SkillDPS or { }) do
			if entry.source and entry.source:match("^Companion") then
				table.insert(entries, entry)
			end
		end
		return entries
	end

	it("counts only the active attack when no selection is made", function()
		local gemInstance = buildCompanionGroup(nil)

		local entries = companionEntries()
		assert.are.equals(1, #entries)
		-- the attack leads the entry; the companion is the source line
		assert.are.equals("Basic Attack", entries[1].name)
		assert.are.equals("Companion: Mighty Silverfist", entries[1].source)
		assert.is_nil(entries[1].skillPart)
		assert.True(entries[1].dps > 0)
		assert.is_nil(gemInstance.fullDPSMinionSkills)
	end)

	it("creates one Full DPS entry per selected attack and sums them", function()
		local gemInstance = buildCompanionGroup({ [meleeId] = true, [slamId] = true })

		local entries = companionEntries()
		assert.are.equals(2, #entries)
		assert.are_not.equals(entries[1].name, entries[2].name)
		local sum = 0
		for _, entry in ipairs(entries) do
			assert.are.equals("Companion: Mighty Silverfist", entry.source)
			assert.True(entry.dps > 0)
			sum = sum + entry.dps * entry.count
		end
		assert.True(math.abs(build.calcsTab.mainOutput.FullDPS - sum) < 0.01)
		-- the calc must not leak its per-pass override or touch persisted fields
		assert.are.equals(beastId, gemInstance.skillMinion)
		assert.True(gemInstance.fullDPSMinionSkills[meleeId])
		assert.True(gemInstance.fullDPSMinionSkills[slamId])
		for _, activeSkill in ipairs(build.calcsTab.mainEnv.player.activeSkillList) do
			assert.is_nil(activeSkill.minionSkillIndexOverride)
		end
	end)

	it("excludes the active attack when only another attack is selected", function()
		buildCompanionGroup({ [slamId] = true })

		local entries = companionEntries()
		assert.are.equals(1, #entries)
		assert.are.equals("Pillar Slam", entries[1].name)
	end)

	it("falls back to the active attack when no selected id matches the beast", function()
		buildCompanionGroup({ NotARealMinionSkillId = true })

		local entries = companionEntries()
		assert.are.equals(1, #entries)
		assert.are.equals("Basic Attack", entries[1].name)
	end)

	it("lists other minions' entries in the same attack-plus-source format", function()
		build.skillsTab:PasteSocketGroup("Skeletal Sniper 20/0  1")
		local group = build.skillsTab.socketGroupList[#build.skillsTab.socketGroupList]
		group.includeInFullDPS = true
		build.buildFlag = true
		runCallback("OnFrame")

		local entry
		for _, skillEntry in ipairs(build.calcsTab.mainOutput.SkillDPS or { }) do
			if skillEntry.source == "Skeletal Sniper Minion" then
				entry = skillEntry
			end
		end
		assert.is_not_nil(entry)
		assert.is_nil(entry.skillPart)
		assert.True(entry.dps > 0)
	end)

	it("a single selected attack matches the unselected baseline DPS", function()
		buildCompanionGroup(nil)
		local baseline = companionEntries()[1]

		newBuild()
		buildCompanionGroup({ [meleeId] = true })
		local selected = companionEntries()[1]

		assert.are.equals(baseline.dps, selected.dps)
		assert.are.equals(baseline.name, selected.name)
	end)

	describe("persistence", function()
		it("saves selected attacks as sorted Gem child elements", function()
			build.skillsTab.skillSets[1].socketGroupList = { {
				enabled = true,
				gemList = { {
					nameSpec = "Companion: Mighty Silverfist",
					level = 20, quality = 0, enabled = true, enableGlobal1 = true, enableGlobal2 = true,
					count = 1, corrupted = false, corruptLevel = 0,
					fullDPSMinionSkills = { [slamId] = true, [meleeId] = true },
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

			local skillIds = { }
			for _, child in ipairs(gemNode) do
				if child.elem == "FullDPSMinionSkill" then
					table.insert(skillIds, child.attrib.skillId)
				end
			end
			assert.are.equals(2, #skillIds)
			-- sorted for deterministic build XML
			assert.are.equals(slamId, skillIds[1])
			assert.are.equals(meleeId, skillIds[2])
		end)

		it("loads FullDPSMinionSkill elements back onto the gem instance", function()
			local node = { elem = "Skill", attrib = { enabled = "true" },
				{ elem = "Gem", attrib = { nameSpec = "Companion: Mighty Silverfist", level = "20", quality = "0", enabled = "true" },
					{ elem = "FullDPSMinionSkill", attrib = { skillId = meleeId } },
					{ elem = "FullDPSMinionSkill", attrib = { skillId = slamId } },
				},
			}

			build.skillsTab:LoadSkill(node, 1)

			local socketGroupList = build.skillsTab.skillSets[1].socketGroupList
			local gemInstance = socketGroupList[#socketGroupList].gemList[1]
			assert.is_not_nil(gemInstance.fullDPSMinionSkills)
			assert.True(gemInstance.fullDPSMinionSkills[meleeId])
			assert.True(gemInstance.fullDPSMinionSkills[slamId])
		end)

		it("loads gems without a selection as nil", function()
			local node = { elem = "Skill", attrib = { enabled = "true" },
				{ elem = "Gem", attrib = { nameSpec = "Fireball", level = "20", quality = "0", enabled = "true" } },
			}

			build.skillsTab:LoadSkill(node, 1)

			local socketGroupList = build.skillsTab.skillSets[1].socketGroupList
			assert.is_nil(socketGroupList[#socketGroupList].gemList[1].fullDPSMinionSkills)
		end)
	end)

	describe("SkillsTab UI", function()
		local function displayLastGroup()
			local skillsTab = build.skillsTab
			skillsTab:SetDisplayGroup(skillsTab.socketGroupList[#skillsTab.socketGroupList])
			skillsTab:UpdateBeastAttackSlots()
			return skillsTab
		end

		it("creates attack rows with default check state on the active attack", function()
			buildCompanionGroup(nil)
			local skillsTab = displayLastGroup()

			local attacks = skillsTab:GetDisplayedBeastAttacks()
			assert.is_not_nil(attacks)
			assert.are.equals(2, #attacks)
			assert.is_not_nil(skillsTab.beastAttackSlots[2])
			assert.True(skillsTab.beastAttackSlots[1].enabled.state)
			assert.False(skillsTab.beastAttackSlots[2].enabled.state)
		end)

		it("shows all attacks unchecked while the group is out of Full DPS", function()
			local gemInstance, group = buildCompanionGroup({ [slamId] = true })
			group.includeInFullDPS = false
			local skillsTab = displayLastGroup()

			assert.False(skillsTab.beastAttackSlots[1].enabled.state)
			assert.False(skillsTab.beastAttackSlots[2].enabled.state)
		end)

		it("reflects an explicit selection and replaces the table on toggle", function()
			local gemInstance, group = buildCompanionGroup({ [slamId] = true })
			local skillsTab = displayLastGroup()

			assert.False(skillsTab.beastAttackSlots[1].enabled.state)
			assert.True(skillsTab.beastAttackSlots[2].enabled.state)

			-- toggling builds a new table (undo snapshots share nested tables)
			local before = gemInstance.fullDPSMinionSkills
			skillsTab.beastAttackSlots[1].enabled.changeFunc(true)
			assert.are_not.equals(before, gemInstance.fullDPSMinionSkills)
			assert.True(gemInstance.fullDPSMinionSkills[meleeId])
			assert.True(gemInstance.fullDPSMinionSkills[slamId])
			assert.True(group.includeInFullDPS)

			-- unchecking everything clears the selection and leaves Full DPS,
			-- updating the group's checkbox state as well
			skillsTab.beastAttackSlots[1].enabled.changeFunc(false)
			skillsTab.beastAttackSlots[2].enabled.changeFunc(false)
			assert.is_nil(gemInstance.fullDPSMinionSkills)
			assert.False(group.includeInFullDPS)
			assert.False(skillsTab.controls.includeInFullDPS.state)
		end)

		it("checking an attack pulls the group into Full DPS", function()
			local gemInstance, group = buildCompanionGroup(nil)
			group.includeInFullDPS = false
			local skillsTab = displayLastGroup()

			skillsTab.beastAttackSlots[2].enabled.changeFunc(true)
			assert.True(group.includeInFullDPS)
			assert.True(skillsTab.controls.includeInFullDPS.state)
			assert.True(gemInstance.fullDPSMinionSkills[slamId])
			assert.is_nil(gemInstance.fullDPSMinionSkills[meleeId])
		end)

		it("toggling Include in Full DPS syncs the attack selection", function()
			local gemInstance, group = buildCompanionGroup({ [slamId] = true })
			local skillsTab = displayLastGroup()

			skillsTab.controls.includeInFullDPS.changeFunc(false)
			assert.False(group.includeInFullDPS)
			assert.is_nil(gemInstance.fullDPSMinionSkills)

			-- re-enabling selects the first attack
			skillsTab.controls.includeInFullDPS.changeFunc(true)
			assert.True(group.includeInFullDPS)
			assert.True(gemInstance.fullDPSMinionSkills[meleeId])
			assert.is_nil(gemInstance.fullDPSMinionSkills[slamId])
		end)

		it("shows the skill data on hover, gem tooltip style", function()
			buildCompanionGroup(nil)
			local skillsTab = displayLastGroup()

			local slot = skillsTab.beastAttackSlots[2]
			-- plain attack name, no (active) marker, no info button
			assert.are.equals("^7Pillar Slam", slot.label.label())
			assert.is_nil(slot.info)

			local tooltip = new("Tooltip")
			slot.label.tooltipFunc(tooltip)
			local sawTitle, sawDamage, sawTags = false, false, false
			for _, line in ipairs(tooltip.lines) do
				if line.text and line.text:match("Pillar Slam") then
					sawTitle = true
				end
				-- Pillar Slam's baseMultiplier of 3 renders as "Attack Damage: 300% of base"
				if line.text and line.text:match("Attack Damage") and line.text:match("300") then
					sawDamage = true
				end
				-- gem-style tag line from the base flags: attack, melee, area
				if line.text and line.text:match("AoE, Attack, Melee") then
					sawTags = true
				end
			end
			assert.True(sawTitle)
			assert.True(sawDamage)
			assert.True(sawTags)
		end)

		it("populates the beast dropdown from the build's beast library", function()
			buildCompanionGroup(nil)
			local skillsTab = displayLastGroup()

			local list = skillsTab.controls.companionBeastSelect.list
			assert.are.equals(1, #list)
			assert.are.equals(beastId, list[1].minionId)
		end)

		it("renames the gem and refreshes the gem slot when the beast changes", function()
			local crowbellId = "Metadata/Monsters/CrowBell/CrowBellBossMinion1"
			local gemInstance = buildCompanionGroup(nil)
			table.insert(build.beastList, crowbellId)
			local skillsTab = displayLastGroup()

			skillsTab.controls.companionBeastSelect.selFunc(2, { minionId = crowbellId, label = "The Crowbell" })

			assert.are.equals(crowbellId, gemInstance.skillMinion)
			assert.are.equals("Companion: The Crowbell", gemInstance.nameSpec)
			-- the visible gem name box must follow the rename
			assert.are.equals("Companion: The Crowbell", skillsTab.gemSlots[1].nameSpec.buf)
		end)
	end)
end)
