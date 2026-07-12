describe("MiscCalculator", function()
	before_each(function()
		newBuild()
	end)
	describe("repItem behaviour", function()
		local calcFunc
		before_each(function ()
			calcFunc = build.calcsTab:GetMiscCalculator()
		end)

		local function pasteAndEquipItem(itemText)
			build.itemsTab:CreateDisplayItemFromRaw(itemText)
			build.itemsTab:AddDisplayItem()
			runCallback("OnFrame")
		end

		local function allocateKeystone(keystoneText)
			build.configTab.input.customMods = keystoneText
			build.configTab:BuildModList()
			runCallback("OnFrame")
			calcFunc = build.calcsTab:GetMiscCalculator()
		end

		local function equipInSlot(item, slotName)
			build.itemsTab:AddItem(item, true)
			build.itemsTab.slots[slotName]:SetSelItemId(item.id)
			runCallback("OnFrame")
		end
		local focus = [[Rarity: RARE
+2 Energy Shield
Hallowed Focus
Energy Shield: 57
Crafted: true
Prefix: {range:0.8}LocalIncreasedEnergyShield8
Prefix: {range:0.8}LocalIncreasedEnergyShieldPercent6
Prefix: None
Suffix: {range:0.8}GlobalSpellGemsLevel2
Suffix: None
Suffix: None
Quality: 0
LevelReq: 61
Implicits: 0
+71 to maximum Energy Shield
89% increased Energy Shield
+2 to Level of all Spell Skills]]

		local quiver = [[Test Subject
Rarity: Rare
Toxic Quiver
Crafted: true
Implicits: 1
+100 to maximum energy shield]]

		local bow = new("Item", [[Rarity: Rare
Test Subject
Gemini Bow]])

		local talisman = new("Item", [[Rarity: Rare
Test Subject
Spiny Talisman]])

		local staff = new("Item", [[Rarity: Rare
Test Subject
Chiming Staff]])

		local mace = new("Item", [[Rarity: Rare
Test Subject
Ironwood Greathammer]])

		local sceptre = new("Item", [[Rarity: Rare
Test Subject
Rattling Sceptre
+100 to maximum Energy Shield]])
		local wand = new("Item", [[Rarity: Rare
Test Subject
Dueling Wand]])
		it("calculates off-hand without a weapon", function ()
			pasteAndEquipItem(focus)
			local output = calcFunc()
			assert.True(output.EnergyShield > 0)
		end)
		it("unequips the off-hand focus when replacing weapon 1 with two-handed weapons", function()
			pasteAndEquipItem(focus)
			for _, item in ipairs({ bow, talisman, staff, mace }) do
				local output = calcFunc({ repSlotName = "Weapon 1", repItem = item })
				assert.True(output.EnergyShield == 0)
			end
		end)
		it("keeps the off-hand quiver when using bow", function()
			-- quivers need a bow to be equipped first
			pasteAndEquipItem(bow:BuildRaw())
			pasteAndEquipItem(quiver)
			local output = calcFunc({ repSlotName = "Weapon 1", repItem = bow })
			assert.True(output.EnergyShield > 0)
		end)
		it("keeps the off-hand focus when using a two-handed weapon with Giant's Blood", function()
			pasteAndEquipItem(focus)
			allocateKeystone("You can wield Two-Handed Axes, Maces and Swords in one hand")
			local output = calcFunc({ repSlotName = "Weapon 1", repItem = mace })
			assert.True(output.EnergyShield > 0)
		end)
		it("keeps the off-hand focus when using a staff with Instruments of Power", function()
			pasteAndEquipItem(focus)
			allocateKeystone("You can equip a Focus while wielding a Staff")
			local output = calcFunc({ repSlotName = "Weapon 1", repItem = staff })
			assert.True(output.EnergyShield > 0)
		end)
		it("keeps rare off-hand sceptre when using a talisman with Lord of the Wilds", function()
			equipInSlot(sceptre, "Weapon 2")
			allocateKeystone("You can equip a non-Unique Sceptre while wielding a Talisman")
			local output = calcFunc({ repSlotName = "Weapon 1", repItem = talisman })
			assert.True(output.EnergyShield > 0)
		end)
		it("unequips unique off-hand sceptre when using a talisman with Lord of the Wilds", function()
			equipInSlot(new("Item", "Rarity: Unique\n" .. sceptre:BuildRaw()), "Weapon 2")
			allocateKeystone("You can equip a non-Unique Sceptre while wielding a Talisman")
			local output = calcFunc({ repSlotName = "Weapon 1", repItem = talisman })
			assert.True(output.EnergyShield == 0)
		end)
		it("keeps off-hand when using one-handed weapon", function()
			pasteAndEquipItem(focus)
			local output = calcFunc({ repSlotName = "Weapon 1", repItem = wand })
			assert.True(output.EnergyShield > 0)
		end)
	end)
end)
