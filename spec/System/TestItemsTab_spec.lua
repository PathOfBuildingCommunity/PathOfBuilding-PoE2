describe("TestItemsTab", function()
	before_each(function()
		newBuild()

		build.itemsTab:CreateDisplayItemFromRaw([[
			New Item
			Elementalist Robe
			Energy Shield: 116
			+95 to maximum Life
		]])
		build.itemsTab:AddDisplayItem(true)

		build.itemsTab:CreateDisplayItemFromRaw("New Item\nClasped Sceptre")
		build.itemsTab:AddDisplayItem(true)

		runCallback("OnFrame")
	end)

	it("keeps item tooltips for socket slots without note buttons", function()
		local item = new("Item"):Item([[Rarity: RARE
Test Jewel
Ruby]])
		build.itemsTab:AddItem(item, true)
		build.itemsTab:PopulateSlots()

		local socket, itemIndex
		for _, candidate in pairs(build.itemsTab.sockets) do
			for index, itemId in ipairs(candidate.items) do
				if itemId == item.id then
					socket, itemIndex = candidate, index
					break
				end
			end
			if socket then break end
		end
		assert.is_not_nil(socket)
		assert.is_nil(socket.controls.noteButton)

		local checkCalled = false
		local clearCalled = false
		local tooltip = {
			Clear = function()
				clearCalled = true
			end,
			CheckForUpdate = function()
				checkCalled = true
				return false
			end,
		}
		local popup = main.popups[1]
		local selControl = build.itemsTab.selControl
		main.popups[1] = nil
		build.itemsTab.selControl = nil
		socket.tooltipFunc(tooltip, "IN", itemIndex, item.id)
		main.popups[1] = popup
		build.itemsTab.selControl = selControl

		assert.is_true(checkCalled)
		assert.is_false(clearCalled)
	end)

	describe("ItemsTab", function()
		describe("NewItemSet", function()
			it("Creates a new item set with specified ID", function()
				local itemSetName = "New Item Set"
				local setId = 2
				build.itemsTab:NewItemSet(setId, itemSetName)

				assert.are.equals(itemSetName, build.itemsTab.itemSets[setId].title)
				assert.are.equals(setId, build.itemsTab.itemSets[setId].id)
			end)

			it("Assigns auto-incremented ID when not specified", function()
				local itemSetName = "Auto ID Item Set"
				local setId1 = build.itemsTab:NewItemSet()
				local setId2 = build.itemsTab:NewItemSet(nil, itemSetName)

				assert.are.equals(2, setId1.id)
				assert.are.equals(3, setId2.id)
				assert.are.equals(itemSetName, build.itemsTab.itemSets[setId2.id].title)
			end)

			it("Adds set to order list", function()
				local newTitle = "New Item"

				build.itemsTab:NewItemSet(nil, newTitle)

				assert.are.equals(2, #build.itemsTab.itemSetOrderList)
				assert.are.equals(2, build.itemsTab.itemSetOrderList[2])
			end)

			it("Sets mod flag when creating new item set", function()
				local newTitle = "New Item"
				build.itemsTab.modFlag = false

				build.itemsTab.modFlag = false

				build.itemsTab:NewItemSet(nil, newTitle)

				assert.is_true(build.itemsTab.modFlag)
			end)

			it("does not copy equipment notes into a new item set", function()
				build.itemsTab.slots.Belt.note = "Active set note"

				local newItemSet = build.itemsTab:NewItemSet(nil, "New Item Set")

				assert.is_nil(newItemSet.Belt.note)
			end)
		end)

		describe("CopyItemSet", function()
			it("Copies an item set with a new name", function()
				local newTitle = "Copied Item Set"
				local newItemSet = build.itemsTab:CopyItemSet(1, newTitle)

				assert.is_not.same(build.itemsTab.itemSets[1], newItemSet)
				assert.are.equals(newTitle, newItemSet.title)
			end)

			it("Returns copied item set with next ID", function()
				local newTitle = "Copied Item"

				local newItemSet = build.itemsTab:CopyItemSet(1, newTitle)

				assert.are.equals(2, newItemSet.id)
			end)

			it("Adds copied item set to order list", function()
				local newTitle = "Copied Item"

				build.itemsTab:CopyItemSet(1, newTitle)

				assert.are.equals(2, #build.itemsTab.itemSetOrderList)
				assert.are.equals(2, build.itemsTab.itemSetOrderList[2])
			end)

			it("Updates the mod flag", function()
				local newTitle = "Copied Item"
				build.itemsTab.modFlag = false

				build.itemsTab:CopyItemSet(1, newTitle)

				assert.is_true(build.itemsTab.modFlag)
			end)
		end)

		describe("RenameItemSet", function()
			it("Renames an item set", function()
				local newTitle = "Renamed Item Set"
				build.itemsTab:RenameItemSet(1, newTitle)

				assert.are.equals(newTitle, build.itemsTab.itemSets[1].title)
			end)

			it("Updates the mod flag", function()
				local newTitle = "Renamed Item"
				build.itemsTab.modFlag = false

				build.itemsTab:RenameItemSet(1, newTitle)

				assert.is_true(build.itemsTab.modFlag)
			end)

			it("Does not error on invalid item set ID", function()
				build.itemsTab.modFlag = false

				build.itemsTab:RenameItemSet(999, "Should Not Error")

				assert.is_false(build.itemsTab.modFlag)
			end)
		end)

		describe("DeleteItemSet", function()
			it("Deletes an item set and removes from order list", function()
				local itemSetName = "Item Set To Delete"
				build.itemsTab:NewItemSet(2, itemSetName)

				build.itemsTab:DeleteItemSet(2, 2)

				assert.is_nil(build.itemsTab.itemSets[2])
				assert.are.equals(1, #build.itemsTab.itemSetOrderList)
			end)

			it("Updates the mod flag", function()
				build.itemsTab:NewItemSet(2, "ToDelete")
				build.itemsTab.modFlag = false

				build.itemsTab:DeleteItemSet(2, 2)

				assert.is_true(build.itemsTab.modFlag)
			end)

			it("allows deletion of the last item set", function()
				local lastConfig = 1

				assert.are.equals(1, #build.itemsTab.itemSetOrderList)
				build.itemsTab:DeleteItemSet(lastConfig, 1)

				assert.are.equals(0, #build.itemsTab.itemSetOrderList)
				assert.is_nil(build.itemsTab.itemSets[lastConfig])
			end)
		end)
	end)

	describe("SetActiveItemSet", function()
		it("Switches to a valid item set", function()
			local itemSetName = "New Item Set"
			build.itemsTab:NewItemSet(2, itemSetName)

			build.itemsTab:SetActiveItemSet(2)

			assert.are.equals(2, build.itemsTab.activeItemSetId)
			assert.are.same(build.itemsTab.itemSets[2], build.itemsTab.activeItemSet)
		end)

		it("Defaults to first item set if invalid ID provided", function()
			build.itemsTab:SetActiveItemSet(999)

			assert.are.equals(1, build.itemsTab.activeItemSetId)
		end)

		it("Sets buildFlag", function()
			local itemSetName = "New Item Set"
			build.itemsTab:NewItemSet(2, itemSetName)

			build.buildFlag = false

			build.itemsTab:SetActiveItemSet(2, true)

			assert.are.equals(2, build.itemsTab.activeItemSetId)
			assert.is_true(build.buildFlag)
		end)
	end)

	describe("ItemSetListControl", function()
		it("adds an imported shared item set to the build once", function()
			local itemSetList = new("ItemSetListControl"):ItemSetListControl(nil, { 0, 0, 300, 200 }, build.itemsTab)

			itemSetList:ReceiveDrag("SharedItemList", { title = "Shared Set", slots = {} })

			assert.are.equals(2, #build.itemsTab.itemSetOrderList)
			assert.are.equals("Shared Set", build.itemsTab.itemSets[build.itemsTab.itemSetOrderList[2]].title)
		end)
	end)

	describe("ItemSetService", function()
		local itemSetService
		before_each(function()
			itemSetService = new("ItemSetService"):ItemSetService(build.itemsTab)
		end)

		describe("NewItemSet", function()
			it("Creates a new item set via service", function()
				local itemSetName = "Service New Item"
				itemSetService:NewItemSet(itemSetName)

				assert.are.equals(2, #build.itemsTab.itemSetOrderList)
				assert.are.equals(itemSetName, build.itemsTab.itemSets[2].title)
			end)

			it("Sets newly created item set as active", function()
				itemSetService:NewItemSet("New From Service")

				assert.are.equals(2, build.itemsTab.activeItemSetId)
			end)

			it("Adds an undo state", function()
				local newTitle = "New Item"

				local undoCountBefore = #build.itemsTab.undo
				itemSetService:NewItemSet(newTitle)

				assert.are.equals(#build.itemsTab.undo, undoCountBefore + 1)
			end)
		end)

		describe("CopyItemSet", function()
			it("Copies a item set via service", function()
				local itemName = "Copied via Service"
				itemSetService:CopyItemSet(1, itemName)
				local setId = build.itemsTab.itemSetOrderList[2]

				assert.are.equals(itemName, build.itemsTab.itemSets[setId].title)
			end)

			it("Sets copied item set as active via service", function()
				itemSetService:NewItemSet("Item")
				itemSetService:CopyItemSet(1, "Service Copy")
				local setId = build.itemsTab.itemSetOrderList[3]

				assert.are.equals(setId, build.itemsTab.activeItemSetId)
			end)

			it("Adds an undo state when copying a item set", function()
				local undoCountBefore = #build.itemsTab.undo
				itemSetService:CopyItemSet(1, "Copied Item")

				assert.are.equals(#build.itemsTab.undo, undoCountBefore + 1)
			end)
		end)

		describe("RenameItemSet", function()
			it("Renames a item set via service", function()
				local itemName = "Original Name"
				itemSetService:NewItemSet(itemName)
				local setId = build.itemsTab.itemSetOrderList[2]

				itemSetService:RenameItemSet(setId, "New Name")

				assert.are.equals("New Name", build.itemsTab.itemSets[setId].title)
			end)

			it("Does not rename non-existent item set", function()
				itemSetService:RenameItemSet(10, "Non-existent")

				assert.is_nil(build.itemsTab.itemSets[10])
			end)

			it("Adds an undo state when renaming", function()
				local itemSetName = "Item To Rename"
				itemSetService:NewItemSet(itemSetName)
				local setId = build.itemsTab.itemSetOrderList[2]

				local undoCountBefore = #build.itemsTab.undo
				itemSetService:RenameItemSet(setId, "Renamed Item")

				assert.are.equals(#build.itemsTab.undo, undoCountBefore + 1)
			end)
		end)

		describe("DeleteItemSet", function()
			it("Deletes a item set via service", function()
				itemSetService:NewItemSet("Service Delete Me")

				itemSetService:DeleteItemSet(2, 2)

				assert.is_nil(build.itemsTab.itemSets[2])
				assert.is_nil(build.itemsTab.itemSetOrderList[2])
			end)


			it("Switches active item set when deleting current", function()
				itemSetService:NewItemSet("Service Delete Me")
				local itemToKeep = 1
				local itemToDelete = 2

				assert.are.equals(itemToDelete, build.itemsTab.activeItemSetId)

				itemSetService:DeleteItemSet(itemToDelete, 2)

				assert.are.equals(itemToKeep, build.itemsTab.activeItemSetId)
			end)

			it("Does not delete last item set via service", function()
				itemSetService:NewItemSet("Last One")

				itemSetService:DeleteItemSet(1, 1)

				assert.are.equals(1, #build.itemsTab.itemSetOrderList)
			end)

			it("Adds an undo state when deleting", function()
				local undoCountBefore = #build.itemsTab.undo
				local undoCountAfterNew = #build.itemsTab.undo
				itemSetService:NewItemSet("Undo Delete Test")

				itemSetService:DeleteItemSet(2, 2)

				assert.are.equals(#build.itemsTab.undo, undoCountBefore + 2)
			end)
		end)

		describe("Integration", function()
			it("Completes a item set lifecycle", function()
				local item1Name = "First Item"
				local item2Name = "Second Item"

				itemSetService:NewItemSet(item1Name)
				assert.are.equals("First Item", build.itemsTab.itemSets[2].title)

				itemSetService:CopyItemSet(2, item2Name)
				assert.are.equals("Second Item", build.itemsTab.itemSets[3].title)
			end)
		end)
	end)

	describe("ItemStateManagement", function()
		local itemSetService

		before_each(function()
			itemSetService = new("ItemSetService"):ItemSetService(build.itemsTab)
		end)

		describe("Item set persistence across switches", function()
			it("Preserves item assignments when switching between item sets", function()
				local itemSetName1 = "Set 1"
				local itemSetName2 = "Set 2"

				itemSetService:NewItemSet(itemSetName1)
				itemSetService:NewItemSet(itemSetName2)

				local setId1 = 2
				local setId2 = 3

				build.itemsTab:SetActiveItemSet(setId1)
				build.itemsTab:EquipItemInSet(build.itemsTab.items[1], setId1)

				build.itemsTab:SetActiveItemSet(setId2)
				build.itemsTab:EquipItemInSet(build.itemsTab.items[2], setId2)

				build.itemsTab:SetActiveItemSet(setId1)
				assert.are.equals(1, build.itemsTab.activeItemSet["Body Armour"].selItemId)

				build.itemsTab:SetActiveItemSet(setId2)
				assert.are.equals(2, build.itemsTab.activeItemSet["Weapon 1"].selItemId)
			end)

			it("Preserves weapon set flags when switching between item sets", function()
				itemSetService:NewItemSet("First Set")
				itemSetService:NewItemSet("Set with Weapon Swap")

				build.itemsTab.activeItemSet.useSecondWeaponSet = true

				build.itemsTab:SetActiveItemSet(2)
				assert.is_not.truthy(build.itemsTab.activeItemSet.useSecondWeaponSet)

				build.itemsTab:SetActiveItemSet(3)
				assert.is_true(build.itemsTab.activeItemSet.useSecondWeaponSet)
			end)

			it("Preserves active slot flags when switching between item sets", function()
				itemSetService:NewItemSet("First Set")
				itemSetService:NewItemSet("Second Set")

				build.itemsTab.slots["Weapon 1"].active = true
				build.itemsTab.activeItemSet["Weapon 1"].active = true

				build.itemsTab:SetActiveItemSet(2)
				assert.is_not.truthy(build.itemsTab.activeItemSet["Weapon 1"].active)

				build.itemsTab:SetActiveItemSet(3)
				assert.is_true(build.itemsTab.activeItemSet["Weapon 1"].active)
			end)
		end)

		describe("Default values", function()
			it("Initializes new item sets with default placeholder states", function()
				assert.is_not_nil(build.itemsTab.itemSets[1])
				assert.is.same(build.itemsTab.itemSets[1]["Weapon 1"], { selItemId = 0 })
			end)

			it("Copies placeholder states when copying item sets", function()
				build.itemsTab.itemSets[1]["Weapon 1"].selItemId = 1

				local newItemSet = build.itemsTab:CopyItemSet(1, "Copy Test")

				assert.are.equals(1, newItemSet["Weapon 1"].selItemId)
			end)
		end)
	end)

	describe("TestCopyAnointsAndAugments", function ()
		before_each(function ()
			newBuild()
		end)

		-- Equips an item into the active item set's appropriate slot
		local function equip(raw)
			local item = new("Item"):Item(raw)
			build.itemsTab:AddItem(item)
			build.itemsTab:EquipItemInSet(item, build.itemsTab.activeItemSetId)
			return item
		end

		describe("Anoints", function ()
			it("copies an anoint from the equipped item onto a new item", function ()
				equip([[
					Rarity: RARE
					Equipped
					Crimson Amulet
					Allocates Serrated Edges (enchant)
				]])

				local newItem = new("Item"):Item([[
					Rarity: RARE
					New
					Azure Amulet
				]])
				build.itemsTab:CopyAnointsAndAugments(newItem, false, false)

				assert.are.equals(1, #newItem.enchantModLines)
			end)

			it("does not overwrite an existing anoint when overwrite is false", function ()
				equip([[
					Rarity: RARE
					Equipped
					Crimson Amulet
					Allocates Serrated Edges (enchant)
				]])

				local newItem = new("Item"):Item([[
					Rarity: RARE
					New
					Azure Amulet
					Allocates Unbound Forces (enchant)
				]])
				build.itemsTab:CopyAnointsAndAugments(newItem, false, false)

				assert.are.equals(1, #newItem.enchantModLines)
				assert.is_not_nil(newItem.enchantModLines[1].line:find("Unbound Forces"))
			end)

			it("overwrites an existing anoint when overwrite is true", function ()
				equip([[
					Rarity: RARE
					Equipped
					Crimson Amulet
					Allocates Serrated Edges (enchant)
				]])

				local newItem = new("Item"):Item([[
					Rarity: RARE
					New
					Azure Amulet
					Allocates Unbound Forces (enchant)
				]])
				build.itemsTab:CopyAnointsAndAugments(newItem, false, true)

				assert.are.equals(1, #newItem.enchantModLines)
				assert.is_not_nil(newItem.enchantModLines[1].line:find("Serrated Edges"))
			end)

			it("does not modify a corrupted item", function ()
				equip([[
					Rarity: RARE
					Equipped
					Crimson Amulet
					Allocates Serrated Edges (enchant)
				]])

				for _, status in ipairs({ "Corrupted", "Mirrored", "Sanctified" }) do
					local newItem = new("Item"):Item(string.format([[
						Rarity: RARE
						New
						Azure Amulet
						%s
					]], status))
					build.itemsTab:CopyAnointsAndAugments(newItem, false, false)

					assert.are.equals(0, #newItem.enchantModLines)
				end
			end)
		end)

		describe("Augments", function ()
			local rune = "Greater Robust Rune"

			local existingItemText = string.format([[
					Rarity: RARE
					Equipped
					Stocky Mitts
					Sockets: S
					Rune: %s
				]], rune)

			local newItemText = [[
					Rarity: RARE
					New
					Stocky Mitts
				]]

			it("copies runes from the equipped item when copyAugments is true", function ()
				equip(existingItemText)

				local newItem = new("Item"):Item([[
					Rarity: RARE
					New
					Stocky Mitts
				]])
				build.itemsTab:CopyAnointsAndAugments(newItem, true, false)

				assert.are.equals(rune, newItem.runes[1])
			end)

			it("adds sockets to the new item to fit the copied runes", function ()
				equip(existingItemText)

				local newItem = new("Item"):Item(newItemText)
				assert.are.equals(0, #newItem.sockets)

				build.itemsTab:CopyAnointsAndAugments(newItem, true, false)

				assert.are.equals(1, #newItem.sockets)
			end)

			it("does not copy runes when copyAugments is false", function ()
				equip(existingItemText)

				local newItem = new("Item"):Item(newItemText)
				build.itemsTab:CopyAnointsAndAugments(newItem, false, false)

				assert.are.equals(0, #newItem.sockets)
			end)

			it("does not replace socket bound runes", function ()
				equip(existingItemText)

				local newItem = new("Item"):Item([[
					Rarity: RARE
					Equipped
					Stocky Mitts
					Sockets: S
					Rune: Kolr's Hunt
				]])
				build.itemsTab:CopyAnointsAndAugments(newItem, true, true)
				assert.are.equals(newItem.runes[1], "Kolr's Hunt")

				local newItem = new("Item"):Item([[
					Rarity: RARE
					Equipped
					Stocky Mitts
					Sockets: S S
					Rune: Kolr's Hunt
				]])
				build.itemsTab:CopyAnointsAndAugments(newItem, true, true)
				assert.are.equals(newItem.runes[1], "Kolr's Hunt")
				assert.are.equals(newItem.runes[2], rune)
			end)

			it("replaces runes when overwrite is true", function ()
				equip(existingItemText)

				local newItem = new("Item"):Item([[
					Rarity: RARE
					Equipped
					Stocky Mitts
					Sockets: S S
					Rune: Lesser Robust Rune
				]])
				build.itemsTab:CopyAnointsAndAugments(newItem, true, true)
				assert.are.equals(newItem.runes[1], rune)
				assert.are.equals(newItem.runes[2], "None")
			end)

			it("identifies socket bound runes", function ()
				local item = new("Item"):Item([[
					Rarity: RARE
					Equipped
					Stocky Mitts
					Sockets: S S
					Rune: Kolr's Hunt
					Rune: Lesser Robust Rune
				]])
				local validRunes = build.itemsTab:GetValidRunesForItem(item)

				assert.is_true(build.itemsTab:IsSocketBoundRune(item, item.runes[1], validRunes))
				assert.is_false(build.itemsTab:IsSocketBoundRune(item, item.runes[2], validRunes))
			end)

			it("uses variant socket types for valid augments", function ()
				for _, itemRaw in ipairs({ data.uniques.belt[6], data.uniques.body[1] }) do
					local item = new("Item"):Item(itemRaw)
					item.variant = 1 -- Helmet
					item:BuildModList()

					local foundHelmetSoulCore = false
					for _, rune in ipairs(build.itemsTab:GetValidRunesForItem(item)) do
						if rune.name == "Quipolatl's Soul Core of Flow" then
							foundHelmetSoulCore = true
							break
						end
					end
					assert.is_true(foundHelmetSoulCore)

					item.runes[1] = "Quipolatl's Soul Core of Flow"
					item:UpdateRunes()

					assert.are.equals(2, #item.runeModLines)
					assert.are.equals("8% increased Skill Effect Duration", item.runeModLines[1].line)
					assert.are.equals("8% increased Cooldown Recovery Rate", item.runeModLines[2].line)
				end
			end)

			it("refreshes valid augments when the item variant changes", function ()
				local item = new("Item"):Item(data.uniques.body[1])
				item.variant = 3 -- Boots
				item:BuildModList()
				build.itemsTab:SetDisplayItem(item)

				build.itemsTab.controls.displayItemVariant:SetSel(1) -- Helmet

				local foundMaximumRage = false
				for _, rune in ipairs(build.itemsTab.controls.displayItemRune1.list) do
					if rune.name == "Tzamoto's Soul Core of Ferocity" then
						foundMaximumRage = true
						break
					end
				end
				assert.is_true(foundMaximumRage)
			end)

			it("refreshes affix controls when an augment changes affix limits", function ()
				build.itemsTab:CreateDisplayItemFromRaw([[
					Rarity: RARE
					New
					Stocky Mitts
					Crafted: true
					Sockets: S
				]], true)

				local runeControl = build.itemsTab.controls.displayItemRune1
				local serlesIndex
				for index, rune in ipairs(runeControl.list) do
					if rune.name == "Serle's Triumph" then
						serlesIndex = index
						break
					end
				end
				assert.is_not_nil(serlesIndex)
				runeControl:SetSel(serlesIndex)

				local affixControl = build.itemsTab.controls.displayItemAffix7
				assert.are.equals(7, build.itemsTab.displayItem.affixLimit)
				assert.are.equals("suffixes", affixControl.outputTable)
				assert.are.equals("None", affixControl.list[1])
				affixControl.tooltipFunc({ Clear = function() end }, "BODY", affixControl.selIndex, affixControl.list[affixControl.selIndex])
			end)

			it("keeps Darkness Enthroned's socket editor available at zero sockets", function ()
				build.itemsTab:CreateDisplayItemFromRaw([[
					Item Class: Belts
					Rarity: Unique
					Darkness Enthroned
					Fine Belt
					--------
					Sockets: S S
					--------
					This item gains bonuses from Socketed Items as though it was a Helmet
					81% increased effect of Socketed Augment Items
				]], true)

				assert.are.equals(2, build.itemsTab.displayItem.itemSocketCount)
				build.itemsTab.controls.displayItemSocketRuneEdit:SetText(0, true)
				assert.is_true(build.itemsTab.controls.displayItemSocketRune:IsShown())
				build.itemsTab.controls.displayItemSocketRuneEdit:SetText(2, true)
				assert.are.equals(2, build.itemsTab.displayItem.itemSocketCount)
			end)

			it("selects inferred augments from an advanced copy of Darkness Enthroned", function ()
				build.itemsTab:CreateDisplayItemFromRaw([[
					Item Class: Belts
					Rarity: Unique
					Darkness Enthroned
					Fine Belt
					--------
					Requires: Level 62
					--------
					Sockets: S S
					--------
					Item Level: 86
					--------
					+83 to Spirit (rune)
					Idols socketed in this item gain the benefits of their Bonded modifiers (rune)
					-1 to Spirit per 2 Levels (rune)
					Bonded: +8% to Quality of all Skills (rune)
					--------
					{ Implicit Modifier }
					Flasks gain 0.17 charges per Second
					{ Implicit Modifier — Charm }
					Has 1(1-3) Charm Slot
					--------
					{ Unique Modifier }
					This item gains bonuses from Socketed Items as though it was a Body Armour — Unscalable Value
					{ Unique Modifier }
					66(50-100)% increased effect of Socketed Augment Items — Unscalable Value
				]], true)

				assert.are.same({ "Rune of the Blossom", "Fox Idol" }, build.itemsTab.displayItem.runes)
				assert.are.equals("Rune of the Blossom", build.itemsTab.controls.displayItemRune1.list[build.itemsTab.controls.displayItemRune1.selIndex].name)
				assert.are.equals("Fox Idol", build.itemsTab.controls.displayItemRune2.list[build.itemsTab.controls.displayItemRune2.selIndex].name)
			end)

			it("deduplicates valid augments by socketed item name", function ()
				local item = new("Item"):Item(data.uniques.body[1])
				item.variant = 4 -- Shield
				item:BuildModList()

				local ticabaCount = 0
				local ticabaRune
				for _, rune in ipairs(build.itemsTab:GetValidRunesForItem(item)) do
					if rune.name == "Soul Core of Ticaba" then
						ticabaCount = ticabaCount + 1
						ticabaRune = rune
					end
				end
				assert.are.equals(1, ticabaCount)
				assert.are.equals(2, #ticabaRune.lines)
				assert.are.equals("Hits against you have 20% reduced Critical Damage Bonus", ticabaRune.lines[1])
				assert.are.equals("Hits against you have 20% reduced Critical Damage Bonus", ticabaRune.lines[2])
			end)

			it("uses the regular rune mod as the dropdown label", function ()
				local weaponMods = data.itemMods.Runes["Perfect Robust Rune"].weapon
				assert.are.equals("+15 to Strength", weaponMods[1])
				assert.are.same({ "Adds 6 to 10 Physical Damage to Attacks", "Adds 6 to 10 Fire damage to Attacks" }, { unpack(weaponMods.bonded) })

				local item = new("Item"):Item([[
					Test Wand
					Runic Fork
				]])

				for _, rune in ipairs(build.itemsTab:GetValidRunesForItem(item)) do
					if rune.name == "Perfect Robust Rune" then
						assert.are.equals("+15 to Strength", rune.label)
						return
					end
				end
				assert.fail("Perfect Robust Rune was not valid for a wand")
			end)
		end)

		it("does nothing when no matching item is equipped", function ()
			local newItem = new("Item"):Item([[
				Rarity: RARE
				New
				Azure Amulet
				+8 to Strength (enchant)
			]])
			build.itemsTab:CopyAnointsAndAugments(newItem, true, false)

			assert.are.equals(1, #newItem.enchantModLines)
		end)
	end)
end)
