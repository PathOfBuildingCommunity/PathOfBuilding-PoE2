describe("TestSocketables", function()
	before_each(function()
		newBuild()
	end)

	-- Item Tab display Tests
	-- Also checks slot type runes

	local extractNamesFromModRunes = function(item)
		local modRunes = LoadModule("../src/Data/ModRunes")
		local names = { }
		local baseType, specificType = item:GetSocketedAugmentTypes()
		for name, rune in pairs(modRunes) do
			if rune[baseType] or rune[specificType] then
				names[name] = true
			else
				for soulCoreType in pairs(item.socketedSoulCoreTypes) do
					if rune[soulCoreType] and rune[soulCoreType].type == "SoulCore" then
						names[name] = true
						break
					end
				end
			end
		end
		return names
	end

	local slotTypeTest = function(slotType, itemBase)
		-- ConPrintf("Testing: %s", slotType)
		local itemRaw = "Test\n" .. itemBase .. "\nSockets: S"

		-- Create an ItemTab and add a socketable item to it
		local item = new("Item"):Item(itemRaw)
		local modRunes = extractNamesFromModRunes(item)

		build.itemsTab:AddItem(item)
		build.itemsTab:SetDisplayItem(item)
		runCallback("OnFrame")

		-- The dropdown combines broad and specific slot types, then deduplicates by name.
		-- Compare that exact union so both missing and incorrectly included runes fail.
		local itemTabRunes = { }
		for _, rune in ipairs(build.itemsTab.controls["displayItemRune1"].list) do
			if rune.name ~= "None" then
				itemTabRunes[rune.name] = true
			end
		end
		assert.are.same(modRunes, itemTabRunes, "Rune list mismatch for slot type: " .. slotType)
	end

	-- Note: Except for weapon/armour/caster,
	--  "slotType" references the dat file ItemClasses.Id value as this is what dat file SoulCoresPerClass.ItemClass refs
	-- Not all item classes have runes yet
	it("'Weapon' runes appear in Items tab", slotTypeTest("weapon", "Massive Greathammer"))

	it("'Armour' runes appear in Items tab", slotTypeTest("armour", "Slayer Armour"))

	it("'Caster' runes appear in Items tab", slotTypeTest("caster", "Bone Wand"))

	it("'Body Armour' runes appear in Items tab", slotTypeTest("body armour", "Slayer Armour"))

	it("'Helmets' runes appear in Items tab", slotTypeTest("helmet", "Kamasan Tiara"))

	it("'Gloves' runes appear in Items tab", slotTypeTest("gloves", "Vaal Gloves"))

	it("'Boots' runes appear in Items tab", slotTypeTest("boots", "Vaal Greaves"))

	it("'Shield' runes appear in Items tab", slotTypeTest("shield", "Vaal Tower Shield"))

	it("'Focus' runes appear in Items tab", slotTypeTest("focus", "Hallowed Focus"))

	-- Weapons
	it("'Bow' runes appear in Items tab", slotTypeTest("bow", "Gemini Bow"))

	it("'Crossbow' runes appear in Items tab", slotTypeTest("crossbow", "Siege Crossbow"))

	it("'Wand' runes appear in Items tab", slotTypeTest("wand", "Bone Wand"))

	it("'Sceptre' runes appear in Items tab", slotTypeTest("sceptre", "Omen Sceptre"))

	it("'(Caster) Staff' runes appear in Items tab", slotTypeTest("staff", "Voltaic Staff"))

	it("'Quarterstaff' runes appear in Items tab", slotTypeTest("quarterstaff", "Striking Quarterstaff"))

	it("'Spear' runes appear in Items tab", slotTypeTest("spear", "Flying Spear"))

	it("'One Hand Mace' runes appear in Items tab", slotTypeTest("one hand mace", "Marauding Mace"))

	it("'Two Hand Mace' runes appear in Items tab", slotTypeTest("two hand mace", "Massive Greathammer"))

	-- Not Yet Added
	-- it("'One Hand Sword' runes appear in Items tab", slotTypeTest("one hand sword", ""))

	-- it("'Two Hand Sword' runes appear in Items tab", slotTypeTest("two hand sword", ""))

	-- it("'One Hand Axe' runes appear in Items tab", slotTypeTest("one hand axe", ""))

	-- it("'Two Hand Axe' runes appear in Items tab", slotTypeTest("two hand axe", ""))

	-- it("'Flail' runes appear in Items tab", slotTypeTest("flail", ""))

	-- Future note: Once traps are added, verify that GGG stayed with "traptool"
	-- it("'Trap' runes appear in Items tab", slotTypeTest("traptool", ""))

	-- it("'Claw' runes appear in Items tab", slotTypeTest("claw", ""))

	-- it("'Dagger' runes appear in Items tab", slotTypeTest("dagger", ""))
end)
