describe("ItemListControl", function()
	local originalGetCursorPos

	local function newItemListControl()
		local activeItemSet = {
			id = 1,
			title = "Boss",
			["Body Armour"] = { selItemId = 1 },
		}
		local itemsTab = {
			itemOrderList = { 1, 2 },
			items = {
				[1] = { id = 1, type = "Body Armour", base = { subType = "" } },
				[2] = { id = 2, type = "Jewel", base = { subType = "" } },
			},
			itemSets = { activeItemSet },
			activeItemSet = activeItemSet,
			slots = { },
			build = {
				treeTab = {
					activeSpec = 1,
					specList = { { title = "Boss", jewels = { }, nodes = { } } },
				},
			},
			PopulateSlots = function() end,
			AddUndoState = function() end,
		}
		local control = new("ItemListControl"):ItemListControl(nil, { 0, 0, 360, 308 }, itemsTab, true)
		return control, itemsTab
	end

	before_each(function()
		originalGetCursorPos = GetCursorPos
	end)

	after_each(function()
		GetCursorPos = originalGetCursorPos
	end)

	it("releases focus after opening an item with a double click", function()
		local control, itemsTab = newItemListControl()
		local item = new("Item"):Item([[
Rarity: Rare
Test Belt
Plate Belt
]])
		item.id = 1
		itemsTab.items[1] = item
		itemsTab.SetDisplayItem = function(_, displayItem)
			itemsTab.displayItem = displayItem
		end
		GetCursorPos = function()
			return 3, 3
		end
		control.GetRowRegion = function()
			return { x = 0, y = 0, width = 360, height = 308 }
		end

		local selectedControl = control:OnKeyDown("LEFTBUTTON", true)

		assert.is_nil(selectedControl)
		assert.are.equal(1, itemsTab.displayItem.id)
	end)
end)
