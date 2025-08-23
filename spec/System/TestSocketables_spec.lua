describe("TestSocketables", function()
    before_each(function()
        newBuild()
    end)

    it("ModRunes matches Data/Soulcores", function()
        local modRunes = LoadModule("../src/Data/ModRunes")
        local soulcores = {}
        LoadModule("../src/Data/Bases/soulcore", soulcores)
        local soulCoreCount = 0
        for name, _ in pairs(soulcores) do
            assert.is_not.equals(modRunes[name], nil)
            soulCoreCount = soulCoreCount + 1
        end

        local modRunesCount = 0
        for name, _ in pairs(modRunes) do
            assert.is_not.equals(soulcores[name], nil)
            modRunesCount = modRunesCount + 1
        end
        -- Final check that Bases/soulcore has same number of entries as ModRunes
        assert.are.equals(modRunesCount, soulCoreCount)
    end)

    -- Item Tab display Tests
    -- Also checks slot type runes

    local extractNamesFromModRunes = function(slotType) 
        local modRunes = LoadModule("../src/Data/ModRunes")
        local names = { }
        for name, rune in pairs(modRunes) do
            for runeSlotType, mods in pairs(rune) do
                if runeSlotType == slotType then
                    -- Need to add an entry of the name for each mod line for tests
                    for _, _ in ipairs(mods) do
                        table.insert(names, name)    
                    end                    
                end
            end
        end
        return names
    end

    local slotTypeTest = function(slotType, itemBase) 
        -- ConPrintf("Testing: %s", slotType)
        local itemRaw = "Test\n" .. itemBase .. "\nSockets: S"

        local modRunes = extractNamesFromModRunes(slotType)

        -- Create an ItemTab and add a socketable item to it
        local item = new("Item", itemRaw)
        
        build.itemsTab:AddItem(item)
        build.itemsTab:SetDisplayItem(item)
        runCallback("OnFrame")
        
        -- Extract the proper slot type runes from the list
        local itemTabRunes = { }
        for _, rune in ipairs(build.itemsTab.controls["displayItemRune1"].list) do
            if rune.slot == slotType then
                table.insert(itemTabRunes, rune.name)
            end
        end
        -- To keep the test fast, only check that the lengths match
        -- This should also catch issues with multi-mod line runes since the rune name will appear
        -- for the number of mod lines that the rune has.
        assert.are.equals(#itemTabRunes, #modRunes)
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

    it("'(Quarterstaff) War Staff' runes appear in Items tab", slotTypeTest("warstaff", "Striking Quarterstaff"))

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