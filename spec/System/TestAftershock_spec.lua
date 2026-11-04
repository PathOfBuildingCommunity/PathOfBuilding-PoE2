describe("TestAftershock", function()
	before_each(function()
		newBuild()
		build.itemsTab:CreateDisplayItemFromRaw("New Item\nMarauding Mace")
		build.itemsTab:AddDisplayItem()
	end)

	teardown(function()
		-- newBuild() takes care of resetting everything in setup()
	end)

	local function dpsWith(group, customMods)
		build.skillsTab:PasteSocketGroup(group)
		build.configTab.input.customMods = customMods or ""
		build.configTab:BuildModList()
		runCallback("OnFrame")
		local hand = build.calcsTab.mainOutput.MainHand or build.calcsTab.mainOutput
		return build.calcsTab.mainOutput.TotalDPS, hand.AftershockChance
	end

	it("counts the Aftershock support in Slam DPS", function()
		local base = dpsWith("Leap Slam 1/0  1")
		newBuild()
		build.itemsTab:CreateDisplayItemFromRaw("New Item\nMarauding Mace")
		build.itemsTab:AddDisplayItem()
		local supported, chance = dpsWith("Leap Slam 1/0  1\nAftershock I 1/0  1")
		assert.are.equals(25, chance)
		assert.is_true(math.abs(supported - base * 1.25) < 0.01)
	end)

	it("parses aftershock chance lines on Slams, including Mace Slams", function()
		local base = dpsWith("Leap Slam 1/0  1")
		local dps, chance = dpsWith("Leap Slam 1/0  1", "20% chance for Mace Slam Skills you use yourself to cause an additional Aftershock\n5% chance for Slam Skills to cause an additional Aftershock")
		assert.are.equals(25, chance)
		assert.is_true(math.abs(dps - base * 1.25) < 0.01)
	end)

	it("limits Mace and Shapeshift aftershock lines to those Slams", function()
		local function tagsOf(line)
			local mods = modLib.parseMod(line)
			local tags = { }
			for _, tag in ipairs(mods[1]) do
				tags[#tags + 1] = tag.var or tag.skillType
			end
			return tags
		end
		assert.are.same({ SkillType.Slam, "UsingMace" }, tagsOf("20% chance for Mace Slam Skills you use yourself to cause an additional Aftershock"))
		assert.are.same({ SkillType.Slam, SkillType.Shapeshift }, tagsOf("10% chance for Shapeshift Slam Skills you use yourself to cause an additional Aftershock"))
		assert.are.same({ SkillType.Slam }, tagsOf("5% chance for Slam Skills to cause an additional Aftershock"))
	end)

	it("caps aftershock chance at 100%", function()
		local base = dpsWith("Leap Slam 1/0  1")
		local dps, chance = dpsWith("Leap Slam 1/0  1", "Slam Skills you use yourself cause an additional Aftershock\n25% chance for Slam Skills you use yourself to cause an additional Aftershock")
		assert.are.equals(100, chance)
		assert.is_true(math.abs(dps - base * 2) < 0.01)
	end)

	it("does not apply aftershocks to non-Slam skills", function()
		local base = dpsWith("Boneshatter 1/0  1")
		local dps, chance = dpsWith("Boneshatter 1/0  1", "Slam Skills you use yourself cause an additional Aftershock")
		assert.is_nil(chance)
		assert.are.equals(base, dps)
	end)
end)
