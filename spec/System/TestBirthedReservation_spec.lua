describe("TestBirthedReservation", function()
	before_each(function()
		newBuild()
		build.configTab.input.customMods = "+1000 to Spirit"
		build.configTab:BuildModList()
	end)

	local function grantAmulet(baseName, skillLine)
		build.itemsTab:CreateDisplayItemFromRaw("New Item\n"..baseName.."\nImplicits: 1\nGrants Skill: "..skillLine.."\n")
		build.itemsTab:AddDisplayItem()
	end

	it("Absent Amulet grants a reservation-free skill", function()
		grantAmulet("Absent Amulet", "Level 20 Archmage")
		runCallback("OnFrame")
		assert.are.equals(0, build.calcsTab.mainOutput.SpiritReserved)
	end)

	it("other Birthed amulets also grant reservation-free skills", function()
		grantAmulet("Lament Amulet", "Level 20 Arctic Armour")
		runCallback("OnFrame")
		assert.are.equals(0, build.calcsTab.mainOutput.SpiritReserved)

		newBuild()
		build.configTab.input.customMods = "+1000 to Spirit"
		build.configTab:BuildModList()
		grantAmulet("Portent Amulet", "Level 20 Wolf Pack")
		runCallback("OnFrame")
		assert.are.equals(0, build.calcsTab.mainOutput.SpiritReserved)
	end)

	it("support gems added to a birthed-granted skill still reserve", function()
		grantAmulet("Absent Amulet", "Level 20 Archmage")
		build.skillsTab:PasteSocketGroup("Slot: Amulet\nClarity I 1/0  1\n")
		runCallback("OnFrame")
		assert.are.equals(10, build.calcsTab.mainOutput.SpiritReserved)
	end)

	it("support reservation conversions still apply", function()
		grantAmulet("Absent Amulet", "Level 20 Archmage")
		build.skillsTab:PasteSocketGroup("Slot: Amulet\nClarity I 1/0  1\nAtziri's Communion 1/0  1\n")
		runCallback("OnFrame")
		assert.is_true(build.calcsTab.mainOutput.LifeReservedPercent > 0)
		assert.are.equals(0, build.calcsTab.mainOutput.SpiritReserved)
	end)

	it("a non-birthed item granting the same skill still reserves normally", function()
		grantAmulet("Lapis Amulet", "Level 20 Archmage")
		runCallback("OnFrame")
		assert.are.equals(100, build.calcsTab.mainOutput.SpiritReserved)
	end)

	it("a socketed copy of the skill still reserves normally", function()
		build.skillsTab:PasteSocketGroup("Archmage 20/0  1\n")
		runCallback("OnFrame")
		assert.are.equals(100, build.calcsTab.mainOutput.SpiritReserved)
	end)
end)
