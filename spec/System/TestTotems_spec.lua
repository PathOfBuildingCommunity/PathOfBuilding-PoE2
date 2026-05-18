describe("TestTotems", function()
	before_each(function()
		newBuild()
	end)

	teardown(function()
		-- newBuild() takes care of resetting everything in setup()
	end)

	it("uses exported actor level for Shockwave Totem life", function()
		build.skillsTab:PasteSocketGroup("Shockwave Totem 20/0  1")
		runCallback("OnFrame")

		local checkedTotems = 0
		for _, activeSkill in ipairs(build.calcsTab.calcsEnv.player.activeSkillList) do
			local totemBase = activeSkill.skillData.totemBase
			if totemBase and totemBase.grantedEffect and totemBase.grantedEffect.name == "Shockwave Totem" then
				checkedTotems = checkedTotems + 1
				assert.are.equals(98, activeSkill.skillData.totemLevel)
			end
		end
		assert.True(checkedTotems > 0)
		assert.are.equals(data.monsterAllyLifeTable[98], build.calcsTab.mainOutput.TotemLife)
	end)
end)
