describe("Minion Rage", function()
	before_each(function()
		newBuild()
	end)

	local function setupMinionSkill(gemId, supportGemId, quality)
		local gemList = {
			{
				gemId = gemId,
				level = 20,
				quality = quality or 0,
				enabled = true,
				count = 1,
				enableGlobal1 = true,
				enableGlobal2 = true,
			},
		}

		if supportGemId then
			table.insert(gemList, {
				gemId = supportGemId,
				level = 1,
				quality = 0,
				enabled = true,
				count = 1,
				enableGlobal1 = true,
				enableGlobal2 = true,
			})
		end

		local socketGroup = {
			enabled = true,
			gemList = gemList,
		}

		table.insert(build.skillsTab.socketGroupList, socketGroup)
		build.skillsTab:ProcessSocketGroup(socketGroup)

		local groupIndex = #build.skillsTab.socketGroupList
		build.mainSocketGroup = groupIndex
		build.calcsTab.input.skill_number = groupIndex
		socketGroup.mainActiveSkill = 1
		socketGroup.mainActiveSkillCalcs = 1

		build.buildFlag = true
		build.modFlag = true
		runCallback("OnFrame")
		build.calcsTab:BuildOutput()
		runCallback("OnFrame")
	end

	local function setMinionRage(rage)
		build.configTab.input.multiplierMinionRage = rage
		build.configTab:BuildModList()

		build.modFlag = true
		build.buildFlag = true
		runCallback("OnFrame")
		build.calcsTab:BuildOutput()
		runCallback("OnFrame")

		return build.calcsTab.mainOutput.Minion, build.calcsTab.mainEnv.minion
	end

	it("hides Minion Rage for an unsupported non-Reaver minion", function()
		setupMinionSkill("Metadata/Items/Gems/SkillGemSkeletalBrute")

		local control = build.configTab.varControls.multiplierMinionRage
		assert.is_not_nil(control)
		assert.is_false(control.shown())
	end)

	it("shows Minion Rage for a minion supported by Rage III", function()
		setupMinionSkill(
			"Metadata/Items/Gems/SkillGemSkeletalBrute",
			"Metadata/Items/Gems/SkillGemRageSupportThree"
		)

		local control = build.configTab.varControls.multiplierMinionRage
		assert.is_true(control.shown())
	end)

	it("shows Minion Rage for Skeletal Reavers without Rage support", function()
		setupMinionSkill("Metadata/Items/Gems/SkillGemSkeletalReaver")

		local control = build.configTab.varControls.multiplierMinionRage
		assert.is_true(control.shown())
	end)

	it("clamps configured Minion Rage to Maximum Rage", function()
		setupMinionSkill("Metadata/Items/Gems/SkillGemSkeletalReaver")

		local output = setMinionRage(40)

		assert.are.equals(30, output.Rage)
		assert.are.equals(30, output.MaximumRage)
	end)

	it("grants Skeletal Reavers 3% increased Attack Speed per Rage", function()
		setupMinionSkill("Metadata/Items/Gems/SkillGemSkeletalReaver")

		local output, minion = setMinionRage(20)
		local speedIncrease = minion.mainSkill.skillModList:Sum(
			"INC",
			minion.mainSkill.skillCfg,
			"Speed"
		)

		assert.are.equals(20, output.RageEffect)
		assert.are.equals(60, speedIncrease)
	end)

	it("applies Skeletal Reaver quality to Rage effect", function()
		setupMinionSkill(
			"Metadata/Items/Gems/SkillGemSkeletalReaver",
			nil,
			20
		)

		local output, minion = setMinionRage(20)
		local speedIncrease = minion.mainSkill.skillModList:Sum(
			"INC",
			minion.mainSkill.skillCfg,
			"Speed"
		)

		assert.are.equals(24, output.RageEffect)
		assert.are.equals(72, speedIncrease)
	end)

	it("applies Rage III Attack Speed only below Maximum Rage", function()
		setupMinionSkill(
			"Metadata/Items/Gems/SkillGemSkeletalBrute",
			"Metadata/Items/Gems/SkillGemRageSupportThree"
		)

		local outputAt29, minionAt29 = setMinionRage(29)
		local speedAt29 = minionAt29.mainSkill.skillModList:Sum(
			"INC",
			minionAt29.mainSkill.skillCfg,
			"Speed"
		)

		local outputAt30, minionAt30 = setMinionRage(30)
		local speedAt30 = minionAt30.mainSkill.skillModList:Sum(
			"INC",
			minionAt30.mainSkill.skillCfg,
			"Speed"
		)

		assert.are.equals(29, outputAt29.Rage)
		assert.are.equals(15, speedAt29)
		assert.are.equals(30, outputAt30.Rage)
		assert.are.equals(0, speedAt30)
	end)

	it("applies Rage as more Attack Damage to minions", function()
		setupMinionSkill(
			"Metadata/Items/Gems/SkillGemSkeletalBrute",
			"Metadata/Items/Gems/SkillGemRageSupportThree"
		)

		local _, minionAtZero = setMinionRage(0)
		local damageAtZero = minionAtZero.mainSkill.skillModList:Sum(
			"MORE",
			minionAtZero.mainSkill.skillCfg,
			"Damage"
		)

		local outputAt20, minionAt20 = setMinionRage(20)
		local damageAt20 = minionAt20.mainSkill.skillModList:Sum(
			"MORE",
			minionAt20.mainSkill.skillCfg,
			"Damage"
		)

		assert.are.equals(20, outputAt20.RageEffect)
		assert.are.equals(damageAtZero + 20, damageAt20)
	end)

	it("uses Maximum Rage from a weapon copied by Manifest Weapon", function()
		build.itemsTab:CreateDisplayItemFromRaw([[
			New Item
			Rabid Talisman
			Implicits: 1
			+10 to Maximum Rage
		]])
		build.itemsTab:AddDisplayItem()
		runCallback("OnFrame")

		setupMinionSkill(
			"Metadata/Items/Gems/SkillGemManifestWeapon",
			"Metadata/Items/Gems/SkillGemRageSupportThree"
		)

		local outputAt30, minionAt30 = setMinionRage(30)
		local speedAt30 = minionAt30.mainSkill.skillModList:Sum(
			"INC",
			minionAt30.mainSkill.skillCfg,
			"Speed"
		)

		assert.are.equals(40, outputAt30.MaximumRage)
		assert.are.equals(30, outputAt30.Rage)

		local outputAt40, minionAt40 = setMinionRage(40)
		local speedAt40 = minionAt40.mainSkill.skillModList:Sum(
			"INC",
			minionAt40.mainSkill.skillCfg,
			"Speed"
		)

		assert.are.equals(40, outputAt40.MaximumRage)
		assert.are.equals(40, outputAt40.Rage)
		assert.are.equals(15, speedAt30 - speedAt40)
	end)
end)