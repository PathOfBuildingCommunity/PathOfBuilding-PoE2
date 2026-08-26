-- Socket groups whose active skill is provided by an item or the passive tree
-- must not count against the character's skill slot limit. Support gems never
-- occupy a skill slot on their own, so adding one to such a group must not
-- change whether the group is counted.
describe("TestGemGroupCount", function()
	before_each(function()
		newBuild()
		runCallback("OnFrame")
	end)

	-- Bow Shot is the default attack granted by having a bow equipped; its
	-- granted effect carries fromItem = true in Data/Skills/other.lua.
	local BOW_SHOT = "Metadata/Items/Gems/SkillGemPlayerDefaultBow"
	local ICE_SHOT = "Metadata/Items/Gems/SkillGemIceShot"
	local RAPID_ATTACKS = "Metadata/Items/Gems/SkillGemRapidAttacksSupport"

	local function gem(gemId)
		return {
			gemId = gemId, level = 1, quality = 0, enabled = true, count = 1,
			enableGlobal1 = true, enableGlobal2 = true,
		}
	end

	local function addGroup(...)
		local group = { enabled = true, gemList = { } }
		for _, gemId in ipairs({ ... }) do
			table.insert(group.gemList, gem(gemId))
		end
		table.insert(build.skillsTab.socketGroupList, group)
		build.skillsTab:ProcessSocketGroup(group)
		return group
	end

	local function groupCount()
		build.skillsTab:UpdateGlobalGemCountAssignments()
		return GlobalGemAssignments["GemGroupCount"]
	end

	it("counts a normal active skill group", function()
		addGroup(ICE_SHOT)
		assert.are.equals(1, groupCount())
	end)

	it("does not count the default weapon attack on its own", function()
		addGroup(BOW_SHOT)
		assert.are.equals(0, groupCount())
	end)

	it("does not count the default weapon attack when supported", function()
		addGroup(BOW_SHOT, RAPID_ATTACKS)
		assert.are.equals(0, groupCount())
	end)

	it("counts a supported normal skill exactly once", function()
		addGroup(ICE_SHOT, RAPID_ATTACKS)
		assert.are.equals(1, groupCount())
	end)

	-- Skills granted by an equipped item get fromItem set on the gem instance
	-- itself (CalcSetup.lua, "activeGemInstance.fromItem = grantedSkill.sourceItem ~= nil"),
	-- rather than on the granted effect. Both paths must survive a support gem.
	it("does not count an item granted skill when supported", function()
		local group = addGroup(ICE_SHOT, RAPID_ATTACKS)
		group.gemList[1].fromItem = true
		assert.are.equals(0, groupCount())
	end)

	it("ignores a disabled group", function()
		local group = addGroup(ICE_SHOT)
		group.enabled = false
		assert.are.equals(0, groupCount())
	end)
end)
