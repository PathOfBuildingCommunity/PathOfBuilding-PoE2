describe("Way of the Mountain", function()
	local WAY_OF_THE_MOUNTAIN_NODE_ID = 51546
	local FULL_MOD_LINE = "100% Surpassing chance per enemy Power to gain Mountain's Teachings on Immobilising an enemy if you have the Way of the Mountain Ascendancy Passive Skill"

	local function expectedMountainsTeachingsMods()
		local mtTag = { type = "Condition", var = "MountainsTeachings" }
		return {
			damage = modLib.createMod("Damage", "MORE", 15, "Mountain's Teachings", ModFlag.Attack, mtTag,
				{ type = "SkillType", skillType = SkillType.Triggered, neg = true },
				{ type = "SkillType", skillType = SkillType.Minion, neg = true }),
			stun = modLib.createMod("StunThreshold", "MORE", 50, "Mountain's Teachings", mtTag),
		}
	end

	local function allocateNode(nodeId)
		local spec = build.spec
		local node = spec.nodes[nodeId]
		node.alloc = true
		spec.allocNodes[node.id] = node
	end

	local function setupMonkMartialArtist(allocWayOfMountain)
		local ascendInfo = build.spec.tree.ascendNameMap["Martial Artist"]
		build.spec:SelectClass(ascendInfo.classId)
		build.spec:SelectAscendClass(ascendInfo.ascendClassId)
		if allocWayOfMountain then
			allocateNode(WAY_OF_THE_MOUNTAIN_NODE_ID)
		end
		build.buildFlag = true
		runCallback("OnFrame")
	end

	local function findParsedMod(parsed, name)
		for _, mod in ipairs(parsed) do
			if mod.name == name then
				return mod
			end
		end
	end

	before_each(function()
		newBuild()
	end)

	describe("ModParser", function()
		it("parses the Way of the Mountain passive line into Mountain's Teachings modifiers", function()
			local expected = expectedMountainsTeachingsMods()
			local parsed, unrecognized = modLib.parseMod(FULL_MOD_LINE)
			assert.is_nil(unrecognized)
			assert.are.equals(2, #parsed)
			assert.True(modLib.compareModParams(findParsedMod(parsed, "Damage"), expected.damage))
			assert.True(modLib.compareModParams(findParsedMod(parsed, "StunThreshold"), expected.stun))
		end)

		it("matches the cached ModCache entry", function()
			local expected = expectedMountainsTeachingsMods()
			local cached = modLib.parseModCache[FULL_MOD_LINE]
			assert.is_not_nil(cached)
			assert.are.equals(2, #cached[1])
			assert.True(modLib.compareModParams(cached[1][1], expected.damage))
			assert.True(modLib.compareModParams(cached[1][2], expected.stun))
		end)
	end)

	describe("Mountain's Teachings config", function()
		it("is hidden without Martial Artist or Way of the Mountain", function()
			runCallback("OnFrame")
			local control = build.configTab.varControls.mountainsTeachingsEnabled
			assert.True(control ~= nil)
			assert.False(control:shown())

			setupMonkMartialArtist(false)
			assert.False(control:shown())
		end)

		it("is shown for Martial Artist with Way of the Mountain allocated", function()
			setupMonkMartialArtist(true)
			assert.are.equals("Martial Artist", build.spec.curAscendClassBaseName)
			assert.is_not_nil(build.spec.allocNodes[WAY_OF_THE_MOUNTAIN_NODE_ID])
			local control = build.configTab.varControls.mountainsTeachingsEnabled
			assert.True(control:shown())
			assert.is_true(build.configTab.input.mountainsTeachingsEnabled)
		end)
	end)

	describe("Mountain's Teachings bonuses", function()
		local function setupAttackLoadout(mountainsTeachingsEnabled)
			setupMonkMartialArtist(true)
			build.configTab.input.mountainsTeachingsEnabled = mountainsTeachingsEnabled
			build.configTab:BuildModList()
			build.itemsTab:CreateDisplayItemFromRaw([[
				New Item
				Razor Quarterstaff
				Quality: 0
			]])
			build.itemsTab:AddDisplayItem()
			build.skillsTab:PasteSocketGroup("Quarterstaff Strike 1/0  1")
			runCallback("OnFrame")
			build.calcsTab:BuildOutput()
			runCallback("OnFrame")
		end

		it("grants 15% more attack damage and 50% more stun threshold while active", function()
			setupAttackLoadout(true)
			local skill = build.calcsTab.mainEnv.player.activeSkillList[1]
			local attackDamageMore = skill.skillModList:More(skill.skillCfg, "Damage")
			assert.are.equals(1.15, attackDamageMore)
			assert.are.equals(1.5, build.calcsTab.mainEnv.player.modDB:More(nil, "StunThreshold"))
		end)

		it("does not grant bonuses when Mountain's Teachings is disabled", function()
			setupAttackLoadout(false)
			local skill = build.calcsTab.mainEnv.player.activeSkillList[1]
			local attackDamageMore = skill.skillModList:More(skill.skillCfg, "Damage")
			assert.are.equals(1, attackDamageMore)
			assert.are.equals(1, build.calcsTab.mainEnv.player.modDB:More(nil, "StunThreshold"))
		end)
	end)
end)
