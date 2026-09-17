describe("TestAftershock", function()
	before_each(function()
		newBuild()
	end)

	teardown(function()
		-- newBuild() takes care of resetting everything in setup()
	end)

	local function setupSkill(weaponBase, gemLine, customMods)
		if weaponBase then
			build.itemsTab:CreateDisplayItemFromRaw("New Item\n" .. weaponBase)
			build.itemsTab:AddDisplayItem()
		end
		build.skillsTab:PasteSocketGroup(gemLine)
		build.mainSocketGroup = 1
		build.configTab.input.customMods = customMods or ""
		build.configTab:BuildModList()
		runCallback("OnFrame")
		return build.calcsTab.mainOutput
	end

	local function assertClose(expected, actual)
		assert.is_true(math.abs(expected - actual) < 0.001, string.format("expected %s, got %s", tostring(expected), tostring(actual)))
	end

	it("Earthbreaker gives slam skills a chance to cause an additional aftershock, scaling DPS but not average hit", function()
		local base = setupSkill("Wooden Club", "Leap Slam 20/0  1")
		local baseDPS, baseAvg = base.TotalDPS, base.AverageDamage
		assert.is_true(baseDPS > 0)
		assert.are.equals(0, base.AftershockChance)

		newBuild()
		local out = setupSkill("Wooden Club", "Leap Slam 20/0  1", "25% chance for Slam Skills you use yourself to cause an additional Aftershock")
		assert.are.equals(25, out.AftershockChance)
		assertClose(baseDPS * 1.25, out.TotalDPS)
		assertClose(baseAvg, out.AverageDamage)
	end)

	it("does not give non-slam skills an aftershock chance", function()
		local out = setupSkill("Wooden Club", "Perfect Strike 20/0  1", "25% chance for Slam Skills you use yourself to cause an additional Aftershock")
		assert.is_true(out.TotalDPS > 0)
		assert.is_nil(out.AftershockChance)
	end)

	it("stacks aftershock chance from passives and support gems without a cap", function()
		local base = setupSkill("Wooden Club", "Leap Slam 20/0  1")
		local baseDPS = base.TotalDPS

		newBuild()
		local out = setupSkill("Wooden Club", "Leap Slam 20/0  1", [[
		25% chance for Slam Skills you use yourself to cause an additional Aftershock
		10% chance for Mace Slam Skills you use yourself to cause an additional Aftershock
		5% chance for Slam Skills to cause an additional Aftershock
		]])
		assert.are.equals(40, out.AftershockChance)

		newBuild()
		out = setupSkill("Wooden Club", "Leap Slam 20/0  1\nAftershock II 20/0  1", "80% chance for Slam Skills you use yourself to cause an additional Aftershock")
		assert.are.equals(115, out.AftershockChance)
		assertClose(baseDPS * 2.15, out.TotalDPS)
	end)

	it("only applies mace slam aftershock chance when attacking with a mace", function()
		local out = setupSkill("Hardwood Spear", "Thunderous Leap 20/0  1", "10% chance for Mace Slam Skills you use yourself to cause an additional Aftershock")
		assert.is_true(out.TotalDPS > 0)
		assert.are.equals(0, out.AftershockChance)

		newBuild()
		out = setupSkill("Hardwood Spear", "Thunderous Leap 20/0  1", "25% chance for Slam Skills you use yourself to cause an additional Aftershock")
		assert.are.equals(25, out.AftershockChance)

		newBuild()
		out = setupSkill("Wooden Club", "Leap Slam 20/0  1", "10% chance for Mace Slam Skills you use yourself to cause an additional Aftershock")
		assert.are.equals(10, out.AftershockChance)
	end)

	it("only applies shapeshift slam aftershock chance to shapeshift slams", function()
		local out = setupSkill("Changeling Talisman", "Rampage 20/0  1", "15% chance for Shapeshift Slam Skills you use yourself to cause an additional Aftershock")
		assert.is_true(out.TotalDPS > 0)
		assert.are.equals(15, out.AftershockChance)

		newBuild()
		out = setupSkill("Wooden Club", "Leap Slam 20/0  1", "15% chance for Shapeshift Slam Skills you use yourself to cause an additional Aftershock")
		assert.are.equals(0, out.AftershockChance)
	end)
end)
