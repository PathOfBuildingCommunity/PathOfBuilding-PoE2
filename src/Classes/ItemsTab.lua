-- Path of Building
--
-- Module: Items Tab
-- Items tab for the current build.
--
local pairs = pairs
local ipairs = ipairs
local next = next
local t_insert = table.insert
local t_remove = table.remove
local s_format = string.format
local m_max = math.max
local m_min = math.min
local m_ceil = math.ceil
local m_floor = math.floor
local m_modf = math.modf

local rarityDropList = { 
	{ label = colorCodes.NORMAL.."Normal", rarity = "NORMAL" },
	{ label = colorCodes.MAGIC.."Magic", rarity = "MAGIC" },
	{ label = colorCodes.RARE.."Rare", rarity = "RARE" },
	{ label = colorCodes.UNIQUE.."Unique", rarity = "UNIQUE" },
	{ label = colorCodes.RELIC.."Relic", rarity = "RELIC" }
}

local socketDropList = {
	{ label = colorCodes.SCION.."S", color = "W" }
}

local baseSlots = { "Weapon 1", "Weapon 2", "Helmet", "Body Armour", "Gloves", "Boots", "Amulet", "Ring 1", "Ring 2", "Ring 3","Belt", "Charm 1", "Charm 2", "Charm 3", "Flask 1", "Flask 2" }

local catalystQualityFormat = {
	"^x7F7F7FQuality (Life Modifiers): "..colorCodes.MAGIC.."+%d%% (augmented)",
	"^x7F7F7FQuality (Mana Modifiers): "..colorCodes.MAGIC.."+%d%% (augmented)",
	"^x7F7F7FQuality (Defense Modifiers): "..colorCodes.MAGIC.."+%d%% (augmented)",
	"^x7F7F7FQuality (Physical): "..colorCodes.MAGIC.."+%d%% (augmented)",
	"^x7F7F7FQuality (Fire Modifiers): "..colorCodes.MAGIC.."+%d%% (augmented)",
	"^x7F7F7FQuality (Cold Modifiers): "..colorCodes.MAGIC.."+%d%% (augmented)",
	"^x7F7F7FQuality (Lightning Modifiers): "..colorCodes.MAGIC.."+%d%% (augmented)",
	"^x7F7F7FQuality (Chaos Modifiers): "..colorCodes.MAGIC.."+%d%% (augmented)",
	"^x7F7F7FQuality (Attack Modifiers): "..colorCodes.MAGIC.."+%d%% (augmented)",
	"^x7F7F7FQuality (Caster Modifiers): "..colorCodes.MAGIC.."+%d%% (augmented)",
	"^x7F7F7FQuality (Speed Modifiers): "..colorCodes.MAGIC.."+%d%% (augmented)",
	"^x7F7F7FQuality (Attribute Modifiers): "..colorCodes.MAGIC.."+%d%% (augmented)",
}

local flavourLookup = {}

for _, entry in pairs(data.flavourText) do
    if entry.name and entry.id and entry.text then
        flavourLookup[entry.name] = flavourLookup[entry.name] or {}
        flavourLookup[entry.name][entry.id] = entry.text
    end
end


local ItemsTabClass = newClass("ItemsTab", "UndoHandler", "ControlHost", "Control", function(self, build)
	self.UndoHandler()
	self.ControlHost()
	self.Control()

	self.build = build
	
	self.socketViewer = new("PassiveTreeView")

	self.items = { }
	self.itemOrderList = { }

	self.showStatDifferences = true

	-- PoB Trader class initialization
	self.tradeQuery = new("TradeQuery", self)

	-- Set selector
	self.controls.setSelect = new("DropDownControl", {"TOPLEFT",self,"TOPLEFT"}, {96, 8, 216, 20}, nil, function(index, value)
		self:SetActiveItemSet(self.itemSetOrderList[index])
		self:AddUndoState()
	end)
	self.controls.setSelect.enableDroppedWidth = true
	self.controls.setSelect.enabled = function()
		return #self.itemSetOrderList > 1
	end
	self.controls.setSelect.tooltipFunc = function(tooltip, mode, index, value)
		tooltip:Clear()
		if mode == "HOVER" then
			self:AddItemSetTooltip(tooltip, self.itemSets[self.itemSetOrderList[index]])
		end
	end
	self.controls.setLabel = new("LabelControl", {"RIGHT",self.controls.setSelect,"LEFT"}, {-2, 0, 0, 16}, "^7Item set:")
	self.controls.setManage = new("ButtonControl", {"LEFT",self.controls.setSelect,"RIGHT"}, {4, 0, 90, 20}, "Manage...", function()
		self:OpenItemSetManagePopup()
	end)

	-- Price Items
	self.controls.priceDisplayItem = new("ButtonControl", {"TOPLEFT",self,"TOPLEFT"}, {96, 32, 310, 20}, "Trade for these items", function()
		self.tradeQuery:PriceItem()
	end)
	self.controls.priceDisplayItem.tooltipFunc = function(tooltip)
		tooltip:Clear()
		tooltip:AddLine(16, "^7Contains searches from the official trading site to help find")
		tooltip:AddLine(16, "^7similar or better items for this build")
	end

	-- Item slots
	self.slots = { }
	self.orderedSlots = { }
	self.slotOrder = { }
	self.initSockets = true
	self.slotAnchor = new("Control", {"TOPLEFT",self,"TOPLEFT"}, {96, 76, 310, 0})
	local prevSlot = self.slotAnchor
	local function addSlot(slot)
		prevSlot = slot
		self.slots[slot.slotName] = slot
		t_insert(self.orderedSlots, slot)
		self.slotOrder[slot.slotName] = #self.orderedSlots
		t_insert(self.controls, slot)
	end
	for index, slotName in ipairs(baseSlots) do
		local slot = new("ItemSlotControl", {"TOPLEFT",prevSlot,"BOTTOMLEFT"}, 0, 2, self, slotName)
		addSlot(slot)
		if slotName:match("Weapon") then
			-- Add alternate weapon slot
			slot.weaponSet = 1
			slot.shown = function()
				return not self.activeItemSet.useSecondWeaponSet
			end
			local swapSlot = new("ItemSlotControl", {"TOPLEFT",prevSlot,"BOTTOMLEFT"}, 0, 2, self, slotName.." Swap", slotName)
			addSlot(swapSlot)
			swapSlot.weaponSet = 2
			swapSlot.shown = function()
				return self.activeItemSet.useSecondWeaponSet
			end
		elseif slotName == "Ring 3" then
			slot.shown = function()
				return self.build.calcsTab.mainEnv.modDB:Flag(nil, "AdditionalRingSlot")
			end
		end
	end

	-- Passive tree dropdown controls
	self.controls.specSelect = new("DropDownControl", {"TOPLEFT",prevSlot,"BOTTOMLEFT"}, {0, 8, 216, 20}, nil, function(index, value)
		if self.build.treeTab.specList[index] then
			self.build.modFlag = true
			self.build.treeTab:SetActiveSpec(index)
		end
	end)
	self.controls.specSelect.enabled = function()
		return #self.controls.specSelect.list > 1
	end
	prevSlot = self.controls.specSelect
	self.controls.specButton = new("ButtonControl", {"LEFT",prevSlot,"RIGHT"}, {4, 0, 90, 20}, "Manage...", function()
		self.build.treeTab:OpenSpecManagePopup()
	end)
	self.controls.specLabel = new("LabelControl", {"RIGHT",prevSlot,"LEFT"}, {-2, 0, 0, 16}, "^7Passive tree:")

	self.sockets = { }
	local socketOrder = { }
	for _, node in pairs(build.latestTree.nodes) do
		if node.type == "Socket" or node.containJewelSocket then
			t_insert(socketOrder, node)
		end
	end
	table.sort(socketOrder, function(a, b)
		return a.id < b.id
	end)
	for _, node in ipairs(socketOrder) do
		local socketControl = new("ItemSlotControl", {"TOPLEFT",prevSlot,"BOTTOMLEFT"}, 0, 2, self, "Jewel "..node.id, "Socket", node.id)
		self.sockets[node.id] = socketControl
		addSlot(socketControl)
	end
	self.controls.slotHeader = new("LabelControl", {"BOTTOMLEFT",self.slotAnchor,"TOPLEFT"}, {0, -4, 0, 16}, "^7Equipped items:")
	self.controls.weaponSwap1 = new("ButtonControl", {"BOTTOMRIGHT",self.slotAnchor,"TOPRIGHT"}, {-20, -2, 18, 18}, "I", function()
		if self.activeItemSet.useSecondWeaponSet then
			self.activeItemSet.useSecondWeaponSet = false
			self:AddUndoState()
			self.build.buildFlag = true
			local mainSocketGroup = self.build.skillsTab.socketGroupList[self.build.mainSocketGroup]
			if mainSocketGroup and mainSocketGroup.slot and self.slots[mainSocketGroup.slot].weaponSet == 2 then
				for index, socketGroup in ipairs(self.build.skillsTab.socketGroupList) do
					if socketGroup.slot and self.slots[socketGroup.slot].weaponSet == 1 then
						self.build.mainSocketGroup = index
						break
					end
				end
			end
		end
	end)
	self.controls.weaponSwap1.overSizeText = 3
	self.controls.weaponSwap1.locked = function()
		return not self.activeItemSet.useSecondWeaponSet
	end
	self.controls.weaponSwap2 = new("ButtonControl", {"BOTTOMRIGHT",self.slotAnchor,"TOPRIGHT"}, {0, -2, 18, 18}, "II", function()
		if not self.activeItemSet.useSecondWeaponSet then
			self.activeItemSet.useSecondWeaponSet = true
			self:AddUndoState()
			self.build.buildFlag = true
			local mainSocketGroup = self.build.skillsTab.socketGroupList[self.build.mainSocketGroup]
			if mainSocketGroup and mainSocketGroup.slot and self.slots[mainSocketGroup.slot].weaponSet == 1 then
				for index, socketGroup in ipairs(self.build.skillsTab.socketGroupList) do
					if socketGroup.slot and self.slots[socketGroup.slot].weaponSet == 2 then
						self.build.mainSocketGroup = index
						break
					end
				end
			end
		end
	end)
	self.controls.weaponSwap2.overSizeText = 3
	self.controls.weaponSwap2.locked = function()
		return self.activeItemSet.useSecondWeaponSet
	end
	self.controls.weaponSwapLabel = new("LabelControl", {"RIGHT",self.controls.weaponSwap1,"LEFT"}, {-4, 0, 0, 14}, "^7Weapon Set:")

	-- All items list
	if main.portraitMode then
		self.controls.itemList = new("ItemListControl", {"TOPRIGHT",self.lastSlot,"BOTTOMRIGHT"}, {0, 0, 360, 308}, self, true)
	else
		self.controls.itemList = new("ItemListControl", {"TOPLEFT",self.controls.setManage,"TOPRIGHT"}, {20, 20, 360, 308}, self, true)
	end

	-- Database selector
	self.controls.selectDBLabel = new("LabelControl", {"TOPLEFT",self.controls.itemList,"BOTTOMLEFT"}, {0, 14, 0, 16}, "^7Import from:")
	self.controls.selectDBLabel.shown = function()
		return self.height < 980
	end
	self.selectedDB = "UNIQUE"

	-- Uniques Button
	self.controls.uniqueButton = new("ButtonControl", {"LEFT",self.controls.selectDBLabel,"RIGHT"}, {4, 0, 110, 18}, "Uniques", function()
	    self.selectedDB = "UNIQUE"
	end)
	self.controls.uniqueButton.locked = function() return self.selectedDB == "UNIQUE" end
	
	-- Rare Templates Button
	self.controls.rareButton = new("ButtonControl", {"LEFT",self.controls.selectDBLabel,"RIGHT"}, {120, 0, 110, 18}, "Rare Templates", function()
	    self.selectedDB = "RARE"
	end)
	self.controls.rareButton.locked = function() return self.selectedDB == "RARE" end
	
	-- Unique database
	self.controls.uniqueDB = new("ItemDBControl", {"TOPLEFT",self.controls.itemList,"BOTTOMLEFT"}, {0, 76, 360, function(c) return m_min(244, self.maxY - select(2, c:GetPos())) end}, self, main.uniqueDB, "UNIQUE")
	self.controls.uniqueDB.y = function()
		return self.controls.selectDBLabel:IsShown() and 118 or 90
	end
	self.controls.uniqueDB.shown = function()
		return not self.controls.selectDBLabel:IsShown() or self.selectedDB == "UNIQUE"
	end
	
	-- Rare template database
	self.controls.rareDB = new("ItemDBControl", {"TOPLEFT",self.controls.itemList,"BOTTOMLEFT"}, {0, 76, 360, function(c) return m_min(284, self.maxY - select(2, c:GetPos())) end}, self, main.rareDB, "RARE")
	self.controls.rareDB.y = function()
		return self.controls.selectDBLabel:IsShown() and 78 or 386
	end
	self.controls.rareDB.shown = function()
		return not self.controls.selectDBLabel:IsShown() or self.selectedDB == "RARE"
	end	

	-- Create/import item
	self.controls.craftDisplayItem = new("ButtonControl", {"TOPLEFT",main.portraitMode and self.controls.setManage or self.controls.itemList,"TOPRIGHT"}, {20, main.portraitMode and 0 or -20, 120, 20}, "Craft item...", function()
		self:CraftItem()
	end)
	self.controls.craftDisplayItem.shown = function()
		return self.displayItem == nil 
	end
	self.controls.newDisplayItem = new("ButtonControl", {"TOPLEFT",self.controls.craftDisplayItem,"TOPRIGHT"}, {8, 0, 120, 20}, "Create custom...", function()
		self:EditDisplayItemText()
	end)
	self.controls.displayItemTip = new("LabelControl", {"TOPLEFT",self.controls.craftDisplayItem,"BOTTOMLEFT"}, {0, 8, 100, 16}, 
[[^7Double-click an item from one of the lists,
or copy and paste an item from in game
(hover over the item and Ctrl+C) to view or edit
the item and add it to your build. You can 
also clone an item within Path of Building by 
copying and pasting it with Ctrl+C and Ctrl+V.

You can Control + Click an item to equip it, or 
drag it onto the slot.  This will also add it to 
your build if it's from the unique/template list.
If there's 2 slots an item can go in, 
holding Shift will put it in the second.]])
	self.controls.sharedItemList = new("SharedItemListControl", {"TOPLEFT",self.controls.craftDisplayItem, "BOTTOMLEFT"}, {0, 232, 340, 308}, self, true)

	-- Display item
	self.displayItemTooltip = new("Tooltip")
	self.displayItemTooltip.maxWidth = 458
	self.anchorDisplayItem = new("Control", {"TOPLEFT",main.portraitMode and self.controls.setManage or self.controls.itemList,"TOPRIGHT"}, {20, main.portraitMode and 0 or -20, 0, 0})
	self.anchorDisplayItem.shown = function()
		return self.displayItem ~= nil
	end
	self.controls.addDisplayItem = new("ButtonControl", {"TOPLEFT",self.anchorDisplayItem,"TOPLEFT"}, {0, 0, 100, 20}, "", function()
		self:AddDisplayItem()
	end)
	self.controls.addDisplayItem.label = function()
		return self.items[self.displayItem.id] and "Save" or "Add to build"
	end
	self.controls.editDisplayItem = new("ButtonControl", {"LEFT",self.controls.addDisplayItem,"RIGHT"}, {8, 0, 60, 20}, "Edit...", function()
		self:EditDisplayItemText()
	end)
	self.controls.removeDisplayItem = new("ButtonControl", {"LEFT",self.controls.editDisplayItem,"RIGHT"}, {8, 0, 60, 20}, "Cancel", function()
		self:SetDisplayItem()
	end)

	-- Section: Variant(s)

	self.controls.displayItemSectionVariant = new("Control", {"TOPLEFT",self.controls.addDisplayItem,"BOTTOMLEFT"}, {0, 8, 0, function()
		if not self.controls.displayItemVariant:IsShown() then
			return 0
		end
		return (28 + 
		(self.displayItem.hasAltVariant and 24 or 0) + 
		(self.displayItem.hasAltVariant2 and 24 or 0) + 
		(self.displayItem.hasAltVariant3 and 24 or 0) +
		(self.displayItem.hasAltVariant4 and 24 or 0) + 
		(self.displayItem.hasAltVariant5 and 24 or 0))
	end})
	self.controls.displayItemVariant = new("DropDownControl", {"TOPLEFT", self.controls.displayItemSectionVariant,"TOPLEFT"}, {0, 0, 300, 20}, nil, function(index, value)
		self.displayItem.variant = index
		self.displayItem:BuildAndParseRaw()
		self:UpdateDisplayItemTooltip()
		self:UpdateDisplayItemRangeLines()
	end)
	self.controls.displayItemVariant.maxDroppedWidth = 1000
	self.controls.displayItemVariant.shown = function()
		return self.displayItem.variantList and #self.displayItem.variantList > 1
	end
	self.controls.displayItemAltVariant = new("DropDownControl", {"TOPLEFT",self.controls.displayItemVariant,"BOTTOMLEFT"}, {0, 4, 300, 20}, nil, function(index, value)
		self.displayItem.variantAlt = index
		self.displayItem:BuildAndParseRaw()
		self:UpdateDisplayItemTooltip()
		self:UpdateDisplayItemRangeLines()
	end)
	self.controls.displayItemAltVariant.maxDroppedWidth = 1000
	self.controls.displayItemAltVariant.shown = function()
		return self.displayItem.hasAltVariant
	end
	self.controls.displayItemAltVariant2 = new("DropDownControl", {"TOPLEFT",self.controls.displayItemAltVariant,"BOTTOMLEFT"}, {0, 4, 300, 20}, nil, function(index, value)
		self.displayItem.variantAlt2 = index
		self.displayItem:BuildAndParseRaw()
		self:UpdateDisplayItemTooltip()
		self:UpdateDisplayItemRangeLines()
	end)
	self.controls.displayItemAltVariant2.maxDroppedWidth = 1000
	self.controls.displayItemAltVariant2.shown = function()
		return self.displayItem.hasAltVariant2
	end
	self.controls.displayItemAltVariant3 = new("DropDownControl", {"TOPLEFT",self.controls.displayItemAltVariant2,"BOTTOMLEFT"}, {0, 4, 300, 20}, nil, function(index, value)
		self.displayItem.variantAlt3 = index
		self.displayItem:BuildAndParseRaw()
		self:UpdateDisplayItemTooltip()
		self:UpdateDisplayItemRangeLines()
	end)
	self.controls.displayItemAltVariant3.maxDroppedWidth = 1000
	self.controls.displayItemAltVariant3.shown = function()
		return self.displayItem.hasAltVariant3
	end
	self.controls.displayItemAltVariant4 = new("DropDownControl", {"TOPLEFT",self.controls.displayItemAltVariant3,"BOTTOMLEFT"}, {0, 4, 300, 20}, nil, function(index, value)
		self.displayItem.variantAlt4 = index
		self.displayItem:BuildAndParseRaw()
		self:UpdateDisplayItemTooltip()
		self:UpdateDisplayItemRangeLines()
	end)
	self.controls.displayItemAltVariant4.maxDroppedWidth = 1000
	self.controls.displayItemAltVariant4.shown = function()
		return self.displayItem.hasAltVariant4
	end
	self.controls.displayItemAltVariant5 = new("DropDownControl", {"TOPLEFT",self.controls.displayItemAltVariant4,"BOTTOMLEFT"}, {0, 4, 300, 20}, nil, function(index, value)
		self.displayItem.variantAlt5 = index
		self.displayItem:BuildAndParseRaw()
		self:UpdateDisplayItemTooltip()
		self:UpdateDisplayItemRangeLines()
	end)
	self.controls.displayItemAltVariant5.maxDroppedWidth = 1000
	self.controls.displayItemAltVariant5.shown = function()
		return self.displayItem.hasAltVariant5
	end

	-- Section: Sockets and Links
	self.controls.displayItemSectionSockets = new("Control", {"TOPLEFT",self.controls.displayItemSectionVariant,"BOTTOMLEFT"}, {0, 0, 0, function()
		return self.displayItem and (self.displayItem.base.weapon or self.displayItem.base.armour or self.displayItem.base.tags.wand or self.displayItem.base.tags.staff or self.displayItem.base.tags.sceptre) and 28 or 0
	end})
	self.controls.displayItemSocketRune = new("LabelControl", {"TOPLEFT",self.controls.displayItemSectionSockets,"TOPLEFT"}, {0, 0, 36, 20}, "^x7F7F7FS")
	self.controls.displayItemSocketRune.shown = function()
		return self.displayItem.base.weapon or self.displayItem.base.armour or self.displayItem.base.tags.wand or self.displayItem.base.tags.staff or self.displayItem.base.tags.sceptre
	end
	self.controls.displayItemSocketRuneEdit = new("EditControl", {"LEFT",self.controls.displayItemSocketRune,"RIGHT"}, {2, 0, 50, 20}, nil, nil, "%D", 1, function(buf)
		if tonumber(buf) > 6 then
			self.controls.displayItemSocketRuneEdit:SetText(6)
			return
		end
		self.displayItem.itemSocketCount = tonumber(buf)
		self.displayItem:UpdateRunes()
		self.displayItem:BuildAndParseRaw()
		self:UpdateRuneControls()
		self:UpdateDisplayItemTooltip()
	end)
	self.controls.displayItemSocketRuneEdit.shown = self.controls.displayItemSocketRune
	
	-- Section: Enchant / Anoint / Corrupt
	self.controls.displayItemSectionEnchant = new("Control", {"TOPLEFT",self.controls.displayItemSectionSockets,"BOTTOMLEFT"}, {0, 0, 0, function()
		return (self.controls.displayItemAnoint:IsShown() or self.controls.displayItemCorrupt:IsShown() ) and 28 or 0
	end})
	self.controls.displayItemAnoint = new("ButtonControl", {"TOPLEFT",self.controls.displayItemSectionEnchant,"TOPLEFT"}, {0, 0, 100, 20}, "Anoint...", function()
		self:AnointDisplayItem(1)
	end)
	self.controls.displayItemAnoint.shown = function()
		return self.displayItem and (self.displayItem.base.type == "Amulet" or self.displayItem.canBeAnointed)
	end
	self.controls.displayItemCorrupt = new("ButtonControl", {"TOPLEFT",self.controls.displayItemAnoint,"TOPRIGHT",true}, {8, 0, 100, 20}, "Corrupt...", function()
		self:CorruptDisplayItem()
	end)
	self.controls.displayItemCorrupt.shown = function()
		return self.displayItem and self.displayItem.corruptible
	end

	-- Section: Item Quality
	self.controls.displayItemSectionQuality = new("Control", {"TOPLEFT",self.controls.displayItemSectionEnchant,"BOTTOMLEFT"}, {0, 0, 0, function()
		return (self.controls.displayItemQuality:IsShown() and self.controls.displayItemQualityEdit:IsShown()) and 28 or 0
	end})
	self.controls.displayItemQuality = new("LabelControl", {"TOPLEFT",self.controls.displayItemSectionQuality,"TOPRIGHT"}, {-4, 0, 0, 16}, "^7Quality:")
	self.controls.displayItemQuality.shown = function()
		return self.displayItem and self.displayItem.quality and self.displayItem.base.quality
	end

	self.controls.displayItemQualityEdit = new("EditControl", {"LEFT",self.controls.displayItemQuality,"RIGHT"}, {2, 0, 60, 20}, nil, nil, "%D", 2, function(buf)
		self.displayItem.quality = tonumber(buf)
		self.displayItem:BuildAndParseRaw()
		self:UpdateDisplayItemTooltip()
	end)
	self.controls.displayItemQualityEdit.shown = function()
		return self.displayItem and self.displayItem.quality and self.displayItem.base.quality
	end

	-- Section: Catalysts
	self.controls.displayItemSectionCatalyst = new("Control", {"TOPLEFT",self.controls.displayItemSectionQuality,"BOTTOMLEFT"}, {0, 0, 0, function()
		return (self.controls.displayItemCatalyst:IsShown() or self.controls.displayItemCatalystQualityEdit:IsShown()) and 28 or 0
	end})
	self.controls.displayItemCatalyst = new("DropDownControl", {"TOPLEFT",self.controls.displayItemSectionCatalyst,"TOPRIGHT"}, {0, 0, 250, 20},
		{"Catalyst",
		"Flesh (Life)",
		"Neural (Mana)",
		"Carapace (Defense)",
		"Uul-Netol's (Physical)",
		"Xoph's (Fire)",
		"Tul's (Cold)",
		"Esh's (Lightning)",
		"Chayula's (Chaos)",
		"Reaver (Attack)",
		"Sibilant (Caster)",
		"Skittering (Speed)",
		"Adaptive (Attribute)",
		},
		function(index, value)
			self.displayItem.catalyst = index - 1
			if not self.displayItem.catalystQuality then
				if string.match(self.displayItem.name, "Breach Ring") then 
					self.displayItem.catalystQuality = 50 
				else 
					self.displayItem.catalystQuality = 20 
				end 
				self.controls.displayItemCatalystQualityEdit:SetText(self.displayItem.catalystQuality)
			end
			if self.displayItem.crafted then
				for i = 1, self.displayItem.affixLimit do
					-- Force affix selectors to update
					local drop = self.controls["displayItemAffix"..i]
					drop.selFunc(drop.selIndex, drop.list[drop.selIndex])
				end
			end
			self.displayItem:BuildAndParseRaw()
			self:UpdateDisplayItemTooltip()
		end)
	self.controls.displayItemCatalyst.shown = function()
		return self.displayItem and (self.displayItem.crafted or self.displayItem.hasModTags) and (self.displayItem.base.type == "Amulet" or self.displayItem.base.type == "Ring")
	end
	self.controls.displayItemCatalystQualityEdit = new("EditControl", {"LEFT",self.controls.displayItemCatalyst,"RIGHT"}, {2, 0, 60, 20}, nil, nil, "%D", 2, function(buf)
		self.displayItem.catalystQuality = tonumber(buf)
		if self.displayItem.crafted then
			for i = 1, self.displayItem.affixLimit do
				-- Force affix selectors to update
				local drop = self.controls["displayItemAffix"..i]
				drop.selFunc(drop.selIndex, drop.list[drop.selIndex])
			end
		end
		self.displayItem:BuildAndParseRaw()
		self:UpdateDisplayItemTooltip()
	end)
	self.controls.displayItemCatalystQualityEdit.shown = function()
		return self.displayItem and (self.displayItem.crafted or self.displayItem.hasModTags) and self.displayItem.catalyst and self.displayItem.catalyst > 0
	end

	-- Section: Cluster Jewel
	self.controls.displayItemSectionClusterJewel = new("Control", {"TOPLEFT",self.controls.displayItemSectionCatalyst,"BOTTOMLEFT"}, {0, 0, 0, function()
		return self.controls.displayItemClusterJewelSkill:IsShown() and 52 or 0
	end})
	self.controls.displayItemClusterJewelSkill = new("DropDownControl", {"TOPLEFT",self.controls.displayItemSectionClusterJewel,"TOPLEFT"}, {0, 0, 300, 20}, { }, function(index, value)
		self.displayItem.clusterJewelSkill = value.skillId
		self:CraftClusterJewel()
	end) {
		shown = function()
			return self.displayItem and self.displayItem.crafted and self.displayItem.clusterJewel
		end
	}
	
	self.controls.displayItemClusterJewelNodeCountLabel = new("LabelControl", {"TOPLEFT",self.controls.displayItemClusterJewelSkill,"BOTTOMLEFT"}, {0, 7, 0, 14}, "^7Added Passives:")
	self.controls.displayItemClusterJewelNodeCount = new("SliderControl", {"LEFT",self.controls.displayItemClusterJewelNodeCountLabel,"RIGHT"}, {2, 0, 150, 20}, function(val)
		local divVal = self.controls.displayItemClusterJewelNodeCount:GetDivVal()
		local clusterJewel = self.displayItem.clusterJewel
		self.displayItem.clusterJewelNodeCount = round(val * (clusterJewel.maxNodes - clusterJewel.minNodes) + clusterJewel.minNodes)
		self:CraftClusterJewel()
	end)

	-- Section: Rune Selection
	self.controls.displayItemSectionRune = new("Control", {"TOPLEFT",self.controls.displayItemSectionClusterJewel,"BOTTOMLEFT"}, {0, 0, 0, function()
		if not self.displayItem or self.displayItem.itemSocketCount == 0 or not (self.displayItem.base.weapon or self.displayItem.base.armour or self.displayItem.base.tags.wand or self.displayItem.base.tags.staff or self.displayItem.base.tags.sceptre) then
			return 0
		end
		local h = 6
		for i = 1, 6 do
			if self.controls["displayItemRune"..i]:IsShown() then
				h = h + 24
			end
		end
		return h
	end})
	for i = 1, 6 do
		local prev = self.controls["displayItemRune"..(i-1)] or self.controls.displayItemSectionRune
		local drop
		drop = new("DropDownControl", {"TOPLEFT",prev,"TOPLEFT"}, {i==1 and 40 or 0, 0, 418, 20}, nil, function(index, value)
			self.displayItem.runes[i] = value.name
			self.displayItem:UpdateRunes()
			self.displayItem:BuildAndParseRaw()
			self:UpdateDisplayItemTooltip()
		end)
		drop.y = function()
			return i == 1 and 0 or 24
		end
		drop.tooltipFunc = function(tooltip, mode, index, value)
			tooltip:Clear()
			if value.label ~= "None" then
				tooltip:AddLine(14, "^7"..value.name)
				tooltip:AddLine(14, "^7"..data.itemBases[value.name].implicit)
				-- Adding Comparison
				self:AddModComparisonTooltip(tooltip, { value.label, type = "Rune" })
			end
		end
		drop.shown = function()
			return self.displayItem and i <= self.displayItem.itemSocketCount and (self.displayItem.base.weapon or self.displayItem.base.armour or self.displayItem.base.tags.wand or self.displayItem.base.tags.staff or self.displayItem.base.tags.sceptre)
		end
		
		self.controls["displayItemRune"..i] = drop
		self.controls["displayItemRuneLabel"..i] = new("LabelControl", {"RIGHT",drop,"LEFT"}, {-4, 0, 0, 14}, "^7Rune #"..i)
	end

	-- Section: Affix Selection
	self.controls.displayItemSectionAffix = new("Control", {"TOPLEFT",self.controls.displayItemSectionRune,"BOTTOMLEFT"}, {0, 0, 0, function()
		if not self.displayItem or not self.displayItem.crafted then
			return 0
		end
		local h = 6
		for i = 1, 6 do
			if self.controls["displayItemAffix"..i]:IsShown() then
				h = h + 24
				if self.controls["displayItemAffixRange"..i]:IsShown() then
					h = h + 18
				end
			end
		end
		return h
	end})
	for i = 1, 6 do
		local prev = self.controls["displayItemAffix"..(i-1)] or self.controls.displayItemSectionAffix
		local drop, slider
		local function verifyRange(range, index, drop) -- flips range if it will form discontinuous values
			local priorMod = index - 1 > 0 and self.displayItem.affixes[drop.list[drop.selIndex].modList[index - 1]] or nil
			local nextMod = index + 1 < #drop.list[drop.selIndex].modList and self.displayItem.affixes[drop.list[drop.selIndex].modList[index + 1]] or nil
			local function flipRange(modA, modB) -- assumes all pairs are ordered the same
				local function getMinMax(mod) -- gets first valid range from a mod
					for _, line in ipairs(mod) do
						local min, max = line:match("%((%d[%d%.]*)%-(%d[%d%.]*)%)")
						if min and max then return tonumber(min), tonumber(max)	end
					end
				end

				local minA, maxA = getMinMax(modA)
				local minB, maxB = getMinMax(modB)

				if not minA or not minB or not maxA or not maxB then
					return false
				end

				local allInts = minA == m_floor(minA) and maxA == m_floor(maxA) and minB == m_floor(minB) and maxB == m_floor(maxB) -- if the mod goes in steps that aren't 1, then the code below this doesn't work
				if (minA and minB and maxA and maxB and allInts) then
					if (minA < minB) then -- ascending
						return minA + 1 == maxB
					else -- descending
						return minA - 1 == maxB
					end
				end
				return false
			end
			
			if priorMod then
				if flipRange(priorMod, self.displayItem.affixes[drop.list[drop.selIndex].modList[index]]) then
					range = 1 - range
				end
			elseif nextMod then
				if flipRange(self.displayItem.affixes[drop.list[drop.selIndex].modList[index]], nextMod) then
					range = 1 - range
				end
			end
			return range
		end
		drop = new("DropDownControl", {"TOPLEFT",prev,"TOPLEFT"}, {i==1 and 40 or 0, 0, 418, 20}, nil, function(index, value)
			local affix = { modId = "None" }
			if value.modId then
				affix.modId = value.modId
				affix.range = slider.val
			elseif value.modList then
				slider.divCount = #value.modList
				local index, range = slider:GetDivVal()
				affix.modId = value.modList[index]
				affix.range = verifyRange(range, index, drop)
			end
			self.displayItem[drop.outputTable][drop.outputIndex] = affix
			self.displayItem:Craft()
			self:UpdateDisplayItemTooltip()
			self:UpdateAffixControls()
		end)
		drop.y = function()
			return i == 1 and 0 or 24 + (prev.slider:IsShown() and 18 or 0)
		end
		drop.tooltipFunc = function(tooltip, mode, index, value)
			local modList = value.modList
			if not modList or main.popups[1] or mode == "OUT" or (self.selControl and self.selControl ~= drop) then
				tooltip:Clear()
			elseif tooltip:CheckForUpdate(modList) then
				if value.modId or #modList == 1 then
					local mod = self.displayItem.affixes[value.modId or modList[1]]
					tooltip:AddLine(16, "^7Affix: "..mod.affix)
					for _, line in ipairs(mod) do
						tooltip:AddLine(14, "^7"..line)
					end
					if mod.level > 1 then
						tooltip:AddLine(16, "Level: "..mod.level)
					end
					if mod.modTags and #mod.modTags > 0 then
						tooltip:AddLine(16, "Tags: "..table.concat(mod.modTags, ', '))
					end
				else
					tooltip:AddLine(16, "^7"..#modList.." Tiers")
					local minMod = self.displayItem.affixes[modList[1]]
					local maxMod = self.displayItem.affixes[modList[#modList]]
					for l, line in ipairs(minMod) do
						local minLine = line:gsub("%((%d[%d%.]*)%-(%d[%d%.]*)%)", "%1")
						local maxLine = maxMod[l]:gsub("%((%d[%d%.]*)%-(%d[%d%.]*)%)", "%2")
						if maxLine == maxMod[l] then
							tooltip:AddLine(14, maxLine)
						else
							local start = 1
							tooltip:AddLine(14, minLine:gsub("%d[%d%.]*", function(min)
								local s, e, max = maxLine:find("(%d[%d%.]*)", start)
								start = e + 1
								if min == max then
									return min
								else
									return "("..min.."-"..max..")"
								end
							end))
						end
					end
					tooltip:AddLine(16, "Level: "..minMod.level.." to "..maxMod.level)
					-- Assuming that all mods have the same tags
					if maxMod.modTags and #maxMod.modTags > 0 then
						tooltip:AddLine(16, "Tags: "..table.concat(maxMod.modTags, ', '))
					end
				end
				local mod = self.displayItem.affixes[value.modId or modList[1]]
				local notableName = mod[1] and mod[1]:match("1 Added Passive Skill is (.*)")
				local node = notableName and self.build.spec.tree.clusterNodeMap[notableName]
				if node then
					tooltip:AddSeparator(14)

					-- Node name
					self.socketViewer:AddNodeName(tooltip, node, self.build)

					-- Node description
					if node.sd[1] then
						tooltip:AddLine(16, "")
						for i, line in ipairs(node.sd) do
							if line ~= " " and (node.mods[i].extra or not node.mods[i].list) then
								local line = colorCodes.UNSUPPORTED .. line
								line = main.notSupportedModTooltips and (line .. main.notSupportedTooltipText) or line
								tooltip:AddLine(16, line)
							else
								tooltip:AddLine(16, colorCodes.MAGIC..line)
							end
						end
					end

					-- Reminder text
					if node.reminderText then
						tooltip:AddSeparator(14)
						for _, line in ipairs(node.reminderText) do
							tooltip:AddLine(14, "^xA0A080"..line)
						end
					end

					-- Comparison
					tooltip:AddSeparator(14)
					self:AppendAddedNotableTooltip(tooltip, node)

					-- Information of for this notable appears
					local clusterInfo = self.build.data.clusterJewelInfoForNotable[notableName]
					if clusterInfo then
						tooltip:AddSeparator(14)
						tooltip:AddLine(20, "^7"..notableName.." can appear on:")
						local isFirstSize = true
						for size, v in pairs(clusterInfo.size) do
							tooltip:AddLine(18, colorCodes.MAGIC..size..":")
							local sizeSkills = self.build.data.clusterJewels.jewels[size].skills
							for i, type in ipairs(clusterInfo.jewelTypes) do
								if sizeSkills[type] then
									tooltip:AddLine(14, "^7    "..sizeSkills[type].name)
								end
							end
							if not isFirstSize then
								tooltip:AddLine(10, "")
							end
							isFirstSize = false
						end
					end
				else
					local mod = { }
					if value.modId or #modList == 1 then
						mod = self.displayItem.affixes[value.modId or modList[1]]
					else
						mod = self.displayItem.affixes[modList[1 + round((#modList - 1) * main.defaultItemAffixQuality)]]
					end
					
					-- Adding Mod
					self:AddModComparisonTooltip(tooltip, mod)
				end
			end
		end
		drop.shown = function()
			return self.displayItem and self.displayItem.crafted and i <= self.displayItem.affixLimit
		end
		slider = new("SliderControl", {"TOPLEFT",drop,"BOTTOMLEFT"}, {0, 2, 300, 16}, function(val)
			local affix = self.displayItem[drop.outputTable][drop.outputIndex]
			local index, range = slider:GetDivVal()
			affix.modId = drop.list[drop.selIndex].modList[index]

			affix.range = verifyRange(range, index, drop)
			self.displayItem:Craft()
			self:UpdateDisplayItemTooltip()
		end)
		slider.width = function()
			return slider.divCount and 300 or 100
		end
		slider.tooltipFunc = function(tooltip, val)
			local modList = drop.list[drop.selIndex].modList
			if not modList or main.popups[1] or (self.selControl and self.selControl ~= slider) then
				tooltip:Clear()
			elseif tooltip:CheckForUpdate(val, modList) then
				local index, range = slider:GetDivVal(val)
				local modId = modList[index]
				local mod = self.displayItem.affixes[modId]
				for _, line in ipairs(mod) do
					tooltip:AddLine(16, itemLib.applyRange(line, range))
				end
				tooltip:AddSeparator(10)
				if #modList > 1 then
					tooltip:AddLine(16, "^7Affix: Tier "..(#modList - isValueInArray(modList, modId) + 1).." ("..mod.affix..")")
				else
					tooltip:AddLine(16, "^7Affix: "..mod.affix)
				end
				for _, line in ipairs(mod) do
					tooltip:AddLine(14, line)
				end
				if mod.level > 1 then
					tooltip:AddLine(16, "Level: "..mod.level)
				end
			end
		end
		drop.slider = slider
		self.controls["displayItemAffix"..i] = drop
		self.controls["displayItemAffixLabel"..i] = new("LabelControl", {"RIGHT",drop,"LEFT"}, {-4, 0, 0, 14}, function()
			return drop.outputTable == "prefixes" and "^7Prefix:" or "^7Suffix:"
		end)
		self.controls["displayItemAffixRange"..i] = slider
		self.controls["displayItemAffixRangeLabel"..i] = new("LabelControl", {"RIGHT",slider,"LEFT"}, {-4, 0, 0, 14}, function()
			return drop.selIndex > 1 and "^7Roll:" or "^x7F7F7FRoll:"
		end)
	end

	-- Section: Custom modifiers
	-- if Custom mod button is shown, create the control for the list of mods
	self.controls.displayItemSectionCustom = new("Control", {"TOPLEFT",self.controls.displayItemSectionAffix,"BOTTOMLEFT"}, {0, 0, 0, function()
		return self.controls.displayItemAddCustom:IsShown() and 28 + self.displayItem.customCount * 22 or 0
	end})
	self.controls.displayItemAddCustom = new("ButtonControl", {"TOPLEFT",self.controls.displayItemSectionCustom,"TOPLEFT"}, {0, 0, 120, 20}, "Add modifier...", function()
		self:AddCustomModifierToDisplayItem()
	end)
	self.controls.displayItemAddCustom.shown = function()
		return self.displayItem and (self.displayItem.rarity == "MAGIC" or self.displayItem.rarity == "RARE")
	end

	-- Section: Modifier Range
	self.controls.displayItemSectionRange = new("Control", {"TOPLEFT",self.controls.displayItemSectionCustom,"BOTTOMLEFT"}, {0, 0, 0, function()
		return self.displayItem.rangeLineList[1] and 28 or 0
	end})
	self.controls.displayItemRangeLine = new("DropDownControl", {"TOPLEFT",self.controls.displayItemSectionRange,"TOPLEFT"}, {0, 0, 350, 18}, nil, function(index, value)
		self.controls.displayItemRangeSlider.val = self.displayItem.rangeLineList[index].range
	end)
	self.controls.displayItemRangeLine.shown = function()
		return self.displayItem and self.displayItem.rangeLineList[1] ~= nil
	end
	self.controls.displayItemRangeSlider = new("SliderControl", {"LEFT",self.controls.displayItemRangeLine,"RIGHT"}, {8, 0, 100, 18}, function(val)
		self.displayItem.rangeLineList[self.controls.displayItemRangeLine.selIndex].range = val
		self.displayItem:BuildAndParseRaw()
		self:UpdateDisplayItemTooltip()
		self:UpdateCustomControls()
	end)

	-- Tooltip anchor
	self.controls.displayItemTooltipAnchor = new("Control", {"TOPLEFT",self.controls.displayItemSectionRange,"BOTTOMLEFT"})

	-- Scroll bars
	self.controls.scrollBarH = new("ScrollBarControl", nil, {0, 0, 0, 18}, 100, "HORIZONTAL", true)
	self.controls.scrollBarV = new("ScrollBarControl", nil, {0, 0, 18, 0}, 100, "VERTICAL", true)

	-- Initialise drag target lists
	t_insert(self.controls.itemList.dragTargetList, self.controls.sharedItemList)
	t_insert(self.controls.itemList.dragTargetList, build.controls.mainSkillMinion)
	t_insert(self.controls.uniqueDB.dragTargetList, self.controls.itemList)
	t_insert(self.controls.uniqueDB.dragTargetList, self.controls.sharedItemList)
	t_insert(self.controls.uniqueDB.dragTargetList, build.controls.mainSkillMinion)
	t_insert(self.controls.rareDB.dragTargetList, self.controls.itemList)
	t_insert(self.controls.rareDB.dragTargetList, self.controls.sharedItemList)
	t_insert(self.controls.rareDB.dragTargetList, build.controls.mainSkillMinion)
	t_insert(self.controls.sharedItemList.dragTargetList, self.controls.itemList)
	t_insert(self.controls.sharedItemList.dragTargetList, build.controls.mainSkillMinion)
	for _, slot in pairs(self.slots) do
		t_insert(self.controls.itemList.dragTargetList, slot)
		t_insert(self.controls.uniqueDB.dragTargetList, slot)
		t_insert(self.controls.rareDB.dragTargetList, slot)
		t_insert(self.controls.sharedItemList.dragTargetList, slot)
	end

	-- Initialise item sets
	self.itemSets = { }
	self.itemSetOrderList = { 1 }
	self:NewItemSet(1)
	self:SetActiveItemSet(1)

	self:PopulateSlots()
	self.lastSlot = self.slots[baseSlots[#baseSlots]]
end)

function ItemsTabClass:Load(xml, dbFileName)
	self.activeItemSetId = 0
	self.itemSets = { }
	self.itemSetOrderList = { }
	self.tradeQuery.statSortSelectionList = { }
	for _, node in ipairs(xml) do
		if node.elem == "Item" then
			local item = new("Item", "")
			item.id = tonumber(node.attrib.id)
			item.variant = tonumber(node.attrib.variant)
			if node.attrib.variantAlt then
				item.hasAltVariant = true
				item.variantAlt = tonumber(node.attrib.variantAlt)
			end
			if node.attrib.variantAlt2 then
				item.hasAltVariant2 = true
				item.variantAlt2 = tonumber(node.attrib.variantAlt2)
			end
			if node.attrib.variantAlt3 then
				item.hasAltVariant3 = true
				item.variantAlt3 = tonumber(node.attrib.variantAlt3)
			end
			if node.attrib.variantAlt4 then
				item.hasAltVariant4 = true
				item.variantAlt4 = tonumber(node.attrib.variantAlt4)
			end
			if node.attrib.variantAlt5 then
				item.hasAltVariant5 = true
				item.variantAlt5 = tonumber(node.attrib.variantAlt5)
			end
			for _, child in ipairs(node) do
				if type(child) == "string" then
					item:ParseRaw(child)
				elseif child.elem == "ModRange" then
					local id = tonumber(child.attrib.id) or 0
					local range = tonumber(child.attrib.range) or 1
					-- This is garbage, but needed due to change to separate mod line lists
					-- 'ModRange' elements are legacy though, so is this actually needed? :<
					-- Maybe it is? Maybe it isn't? Maybe up is down? Maybe good is bad? AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
					-- Sorry, cluster jewels are making me crazy(-ier)
					for _, list in ipairs{item.buffModLines, item.enchantModLines, item.implicitModLines, item.explicitModLines } do
						if id <= #list then
							list[id].range = range
							break
						end
						id = id - #list
					end
				end
			end
			if item.base then
				item:BuildModList()
				self.items[item.id] = item
				t_insert(self.itemOrderList, item.id)
			end
		-- Below is OBE and left for legacy compatibility (all Slots are part of ItemSets now)
		elseif node.elem == "Slot" then
			local slot = self.slots[node.attrib.name or ""]
			if slot then
				slot.selItemId = tonumber(node.attrib.itemId)
				if slot.controls.activate then
					slot.active = node.attrib.active == "true"
					slot.controls.activate.state = slot.active
				end
			end
		elseif node.elem == "ItemSet" then
			local itemSet = self:NewItemSet(tonumber(node.attrib.id))
			itemSet.title = node.attrib.title
			itemSet.useSecondWeaponSet = node.attrib.useSecondWeaponSet == "true"
			for _, child in ipairs(node) do
				if child.elem == "Slot" then
					local slotName = child.attrib.name or ""
					if itemSet[slotName] then
						itemSet[slotName].selItemId = tonumber(child.attrib.itemId)
						itemSet[slotName].active = child.attrib.active == "true"
						itemSet[slotName].pbURL = child.attrib.itemPbURL or ""
					end
				elseif child.elem == "SocketIdURL" then
					local id = tonumber(child.attrib.nodeId)
					itemSet[id] = { pbURL = child.attrib.itemPbURL or "" }
				end
			end
			t_insert(self.itemSetOrderList, itemSet.id)
		elseif node.elem == "TradeSearchWeights" then
			for _, child in ipairs(node) do
				local statSort = {
					label = child.attrib.label,
					stat = child.attrib.stat,
					weightMult = tonumber(child.attrib.weightMult)
				}
				t_insert(self.tradeQuery.statSortSelectionList, statSort)
			end
		end
	end
	if not self.itemSetOrderList[1] then
		self.activeItemSet = self:NewItemSet(1)
		self.activeItemSet.useSecondWeaponSet = xml.attrib.useSecondWeaponSet == "true"
		self.itemSetOrderList[1] = 1
	end
	self:SetActiveItemSet(tonumber(xml.attrib.activeItemSet) or 1)
	if xml.attrib.showStatDifferences then
		self.showStatDifferences = xml.attrib.showStatDifferences == "true"
	end
	self:ResetUndo()
end

function ItemsTabClass:Save(xml)
	xml.attrib = {
		activeItemSet = tostring(self.activeItemSetId),
		useSecondWeaponSet = tostring(self.activeItemSet.useSecondWeaponSet),
		showStatDifferences = tostring(self.showStatDifferences),
	}
	for _, id in ipairs(self.itemOrderList) do
		local item = self.items[id]
		local child = { 
			elem = "Item", 
			attrib = { 
				id = tostring(id), 
				variant = item.variant and tostring(item.variant), 
				variantAlt = item.variantAlt and tostring(item.variantAlt), 
				variantAlt2 = item.variantAlt2 and tostring(item.variantAlt2),
				variantAlt3 = item.variantAlt3 and tostring(item.variantAlt3), 
				variantAlt4 = item.variantAlt4 and tostring(item.variantAlt4), 
				variantAlt5 = item.variantAlt5 and tostring(item.variantAlt5)
			} 
		}
		item:BuildAndParseRaw()
		t_insert(child, item.raw)
		local id = #item.buffModLines + 1
		for _, modLine in ipairs(item.enchantModLines) do
			if modLine.range then
				t_insert(child, { elem = "ModRange", attrib = { id = tostring(id), range = tostring(modLine.range) } })
			end
			id = id + 1
		end
		for _, modLine in ipairs(item.runeModLines) do
			if modLine.range then
				t_insert(child, { elem = "ModRange", attrib = { id = tostring(id), range = tostring(modLine.range) } })
			end
			id = id + 1
		end
		for _, modLine in ipairs(item.implicitModLines) do
			if modLine.range then
				t_insert(child, { elem = "ModRange", attrib = { id = tostring(id), range = tostring(modLine.range) } })
			end
			id = id + 1
		end
		for _, modLine in ipairs(item.explicitModLines) do
			if modLine.range then
				t_insert(child, { elem = "ModRange", attrib = { id = tostring(id), range = tostring(modLine.range) } })
			end
			id = id + 1
		end
		t_insert(xml, child)
	end
	for _, itemSetId in ipairs(self.itemSetOrderList) do
		local itemSet = self.itemSets[itemSetId]
		local child = { elem = "ItemSet", attrib = { id = tostring(itemSetId), title = itemSet.title, useSecondWeaponSet = tostring(itemSet.useSecondWeaponSet) } }
		for slotName, slot in pairs(self.slots) do
			if not slot.nodeId then
				t_insert(child, { elem = "Slot", attrib = { name = slotName, itemId = tostring(itemSet[slotName].selItemId), itemPbURL = itemSet[slotName].pbURL or "", active = itemSet[slotName].active and "true" }})
			else
				if self.build.spec.allocNodes[slot.nodeId] then
					t_insert(child, { elem = "SocketIdURL", attrib = { name = slotName, nodeId = tostring(slot.nodeId), itemPbURL = itemSet[slot.nodeId] and itemSet[slot.nodeId].pbURL or ""}})
				end
			end
		end
		t_insert(xml, child)
	end
	if self.tradeQuery.statSortSelectionList then
		local parent = {
			elem = "TradeSearchWeights"
		}
		for _, statSort in ipairs(self.tradeQuery.statSortSelectionList) do
			if statSort.weightMult and statSort.weightMult > 0 then
				local child = {
				elem = "Stat",
				attrib = {
					label = statSort.label,
					stat = statSort.stat,
					weightMult = s_format("%.2f", tostring(statSort.weightMult))
				}
			}
			t_insert(parent, child)
			end
		end
		t_insert(xml, parent)
	end
end

function ItemsTabClass:Draw(viewPort, inputEvents)
	self.x = viewPort.x
	self.y = viewPort.y
	self.width = viewPort.width
	self.height = viewPort.height
	self.controls.scrollBarH.width = viewPort.width
	self.controls.scrollBarH.x = viewPort.x
	self.controls.scrollBarH.y = viewPort.y + viewPort.height - 18
	self.controls.scrollBarV.height = viewPort.height - 18
	self.controls.scrollBarV.x = viewPort.x + viewPort.width - 18
	self.controls.scrollBarV.y = viewPort.y
	do
		local maxY = select(2, self.lastSlot:GetPos()) + 24
		local maxX = self.anchorDisplayItem:GetPos() + 462
		if self.displayItem then
			local x, y = self.controls.displayItemTooltipAnchor:GetPos()
			local ttW, ttH = self.displayItemTooltip:GetDynamicSize(viewPort)
			maxY = m_max(maxY, y + ttH + 4)
			maxX = m_max(maxX, x + ttW + 80)
		end
		local contentHeight = maxY - self.y
		local contentWidth = maxX - self.x
		local v = contentHeight > viewPort.height
		local h = contentWidth > viewPort.width - (v and 20 or 0)
		if h then
			v = contentHeight > viewPort.height - 20
		end
		self.controls.scrollBarV:SetContentDimension(contentHeight, viewPort.height - (h and 20 or 0))
		self.controls.scrollBarH:SetContentDimension(contentWidth, viewPort.width - (v and 20 or 0))
		if self.snapHScroll == "RIGHT" then
			self.controls.scrollBarH:SetOffset(self.controls.scrollBarH.offsetMax)
		elseif self.snapHScroll == "LEFT" then
			self.controls.scrollBarH:SetOffset(0)
		end
		self.snapHScroll = nil
		self.maxY = h and self.controls.scrollBarH.y or viewPort.y + viewPort.height
	end
	self.x = self.x - self.controls.scrollBarH.offset
	self.y = self.y - self.controls.scrollBarV.offset
	
	for _, event in ipairs(inputEvents) do
		if event.type == "KeyDown" then	
			if event.key == "v" and IsKeyDown("CTRL") then
				local newItem = Paste()
				if newItem then
					if newItem:find("{ ", 0, true) then
						main:OpenConfirmPopup("Warning", "\"Advanced Item Descriptions\" (Ctrl+Alt+c) are unsupported.\n\nAbort paste?", "OK", function()
							self:SetDisplayItem()
						end)
					end
					self:CreateDisplayItemFromRaw(newItem, true)
				end
				if self.displayItem and IsKeyDown("SHIFT") then
					self:AddDisplayItem()
				end
			elseif event.key == "e" then
				local mOverControl = self:GetMouseOverControl()
				if mOverControl and mOverControl._className == "ItemSlotControl" and mOverControl.selItemId ~= 0 then
					-- Trigger itemList's double click procedure
					self.controls.itemList:OnSelClick(0, mOverControl.selItemId, true)
				end
			elseif event.key == "z" and IsKeyDown("CTRL") then
				self:Undo()
				self.build.buildFlag = true
			elseif event.key == "y" and IsKeyDown("CTRL") then
				self:Redo()
				self.build.buildFlag = true
			elseif event.key == "f" and IsKeyDown("CTRL") then
				if self.selectedDB == "RARE" then
					self:SelectControl(self.controls.rareDB.controls.search)
				else
					self:SelectControl(self.controls.uniqueDB.controls.search)
				end
			elseif event.key == "d" and IsKeyDown("CTRL") then
				self.showStatDifferences = not self.showStatDifferences
				self.build.buildFlag = true
			elseif self.displayItem and IsKeyDown("RETURN") then
				self:AddDisplayItem()
			end
		end
	end
	self:ProcessControlsInput(inputEvents, viewPort)
	for _, event in ipairs(inputEvents) do
		if event.type == "KeyUp" then
			if self.controls.scrollBarV:IsScrollDownKey(event.key) then
				if self.controls.scrollBarV:IsMouseOver() or not self.controls.scrollBarH:IsShown() then
					self.controls.scrollBarV:Scroll(1)
				else
					self.controls.scrollBarH:Scroll(1)
				end
			elseif self.controls.scrollBarV:IsScrollUpKey(event.key) then
				if self.controls.scrollBarV:IsMouseOver() or not self.controls.scrollBarH:IsShown() then
					self.controls.scrollBarV:Scroll(-1)
				else
					self.controls.scrollBarH:Scroll(-1)
				end
			end
		end
	end

	main:DrawBackground(viewPort)

	local newItemList = { }
	for index, itemSetId in ipairs(self.itemSetOrderList) do
		local itemSet = self.itemSets[itemSetId]
		t_insert(newItemList, itemSet.title or "Default")
		if itemSetId == self.activeItemSetId then
			self.controls.setSelect.selIndex = index
		end
	end
	self.controls.setSelect:SetList(newItemList)

	if self.displayItem then
		local x, y = self.controls.displayItemTooltipAnchor:GetPos()
		self.displayItemTooltip:Draw(x, y, nil, nil, viewPort)
	end

	self:UpdateSockets()
	-- Update weapon slots in case we got Giant's Blood from somewhere
	self.slots["Weapon 2"]:Populate()
	self.slots["Weapon 2 Swap"]:Populate()

	self:DrawControls(viewPort)
	if self.controls.scrollBarH:IsShown() then
		self.controls.scrollBarH:Draw(viewPort)
	end
	if self.controls.scrollBarV:IsShown() then
		self.controls.scrollBarV:Draw(viewPort)
	end

	self.controls.specSelect:SetList(self.build.treeTab:GetSpecList())
end

-- Creates a new item set
function ItemsTabClass:NewItemSet(itemSetId)
	local itemSet = { id = itemSetId }
	if not itemSetId then
		itemSet.id = 1
		while self.itemSets[itemSet.id] do
			itemSet.id = itemSet.id + 1
		end
	end
	for slotName, slot in pairs(self.slots) do
		if not slot.nodeId then
			itemSet[slotName] = { selItemId = 0 }
		end
	end
	self.itemSets[itemSet.id] = itemSet
	return itemSet
end

-- Changes the active item set
function ItemsTabClass:SetActiveItemSet(itemSetId)
	local prevSet = self.activeItemSet
	if not self.itemSets[itemSetId] then
		itemSetId = self.itemSetOrderList[1]
	end
	self.activeItemSetId = itemSetId
	self.activeItemSet = self.itemSets[itemSetId]
	local curSet = self.activeItemSet
	for slotName, slot in pairs(self.slots) do
		if not slot.nodeId then
			if prevSet then
				-- Update the previous set
				prevSet[slotName].selItemId = slot.selItemId
				prevSet[slotName].active = slot.active
			end
			-- Equip the incoming set's item
			slot.selItemId = curSet[slotName].selItemId
			slot.active = curSet[slotName].active
			if slot.controls.activate then
				slot.controls.activate.state = slot.active
			end
		end
	end
	self.build.buildFlag = true
	self:PopulateSlots()
	self.build:SyncLoadouts()
end

-- Equips the given item in the given item set
function ItemsTabClass:EquipItemInSet(item, itemSetId)
	local itemSet = self.itemSets[itemSetId]
	local slotName = item:GetPrimarySlot()
	if self.slots[slotName].weaponSet == 1 and itemSet.useSecondWeaponSet then
		-- Redirect to second weapon set
		slotName = slotName .. " Swap"
	end
	if not item.id or not self.items[item.id] then
		item = new("Item", item.raw)
		self:AddItem(item, true)
	end
	local altSlot = slotName:gsub("1","2")
	if IsKeyDown("SHIFT") then
		-- Redirect to second slot if possible
		if self:IsItemValidForSlot(item, altSlot, itemSet) then
			slotName = altSlot
		end
	end
	if itemSet == self.activeItemSet then
		self.slots[slotName]:SetSelItemId(item.id)
	else
		itemSet[slotName].selItemId = item.id
		if itemSet[altSlot].selItemId ~= 0 and not self:IsItemValidForSlot(self.items[itemSet[altSlot].selItemId], altSlot, itemSet) then
			itemSet[altSlot].selItemId = 0
		end
	end
	self:PopulateSlots()
	self:AddUndoState()
	self.build.buildFlag = true
end

-- Update the item lists for all the slot controls
function ItemsTabClass:PopulateSlots()
	for _, slot in pairs(self.slots) do
		slot:Populate()
	end
end

-- Updates the status and position of the socket controls
function ItemsTabClass:UpdateSockets()
	-- Build a list of active sockets
	self.activeSocketList = { }
	for nodeId, slot in pairs(self.sockets) do
		if self.build.spec.allocNodes[nodeId] then
			t_insert(self.activeSocketList, nodeId)
			slot.inactive = false
		else
			slot.inactive = true
		end
	end
	table.sort(self.activeSocketList)

	-- Update the state of the active socket controls
	self.lastSlot = self.slots[baseSlots[#baseSlots]]
	for index, nodeId in ipairs(self.activeSocketList) do
		self.sockets[nodeId].label = "Socket #"..index
		self.lastSlot = self.sockets[nodeId]
	end

	if main.portraitMode then
		self.controls.itemList:SetAnchor("TOPRIGHT",self.lastSlot,"BOTTOMRIGHT", 0, 40)
	end
	self.initSockets = false
end

-- Returns the slot control and equipped jewel for the given node ID
function ItemsTabClass:GetSocketAndJewelForNodeID(nodeId)
	return self.sockets[nodeId], self.sockets[nodeId] and self.items[self.sockets[nodeId].selItemId] or nil
end

-- Adds the given item to the build's item list
function ItemsTabClass:AddItem(item, noAutoEquip, index)
	if not item.id then
		-- Find an unused item ID
		item.id = 1
		while self.items[item.id] do
			item.id = item.id + 1
		end

		if index then
			t_insert(self.itemOrderList, index, item.id)
		else
			-- Add it to the end of the display order list
			t_insert(self.itemOrderList, item.id)
		end

		if not noAutoEquip then
			-- Autoequip it
			for _, slot in ipairs(self.orderedSlots) do
				if not slot.nodeId and slot.selItemId == 0 and slot:IsShown() and self:IsItemValidForSlot(item, slot.slotName) then
					slot:SetSelItemId(item.id)
					break
				end
			end
		end
	end
	
	-- Add it to the list
	local replacing = self.items[item.id]
	self.items[item.id] = item
	item:BuildModList()
	
	if replacing and (replacing.clusterJewel or item.clusterJewel or replacing.baseName == "Timeless Jewel") then
		-- We're replacing an existing item, and either the new or old one is a cluster jewel
		if isValueInTable(self.build.spec.jewels, item.id) then
			-- Item is currently equipped, so we need to rebuild the graphs
			self.build.spec:BuildClusterJewelGraphs()
		end
	end
end

-- Adds the current display item to the build's item list
function ItemsTabClass:AddDisplayItem(noAutoEquip)
	-- Add it to the list and clear the current display item
	self:AddItem(self.displayItem, noAutoEquip)
	self:SetDisplayItem()

	self:PopulateSlots()
	self:AddUndoState()
	self.build.buildFlag = true
end

-- Sorts the build's item list
function ItemsTabClass:SortItemList()
	table.sort(self.itemOrderList, function(a, b)
		local itemA = self.items[a]
		local itemB = self.items[b]
		local primSlotA = itemA:GetPrimarySlot()
		local primSlotB = itemB:GetPrimarySlot()
		if primSlotA ~= primSlotB then
			if not self.slotOrder[primSlotA] then
				return false
			elseif not self.slotOrder[primSlotB] then
				return true
			end
			return self.slotOrder[primSlotA] < self.slotOrder[primSlotB]
		end
		local equipSlotA, equipSetA = self:GetEquippedSlotForItem(itemA)
		local equipSlotB, equipSetB = self:GetEquippedSlotForItem(itemB)
		if equipSlotA and equipSlotB then
			if equipSlotA ~= equipSlotB then
				return self.slotOrder[equipSlotA.slotName] < self.slotOrder[equipSlotB.slotName]
			elseif equipSetA and not equipSetB then
				return false
			elseif not equipSetA and equipSetB then
				return true
			elseif equipSetA and equipSetB then
				return isValueInArray(self.itemSetOrderList, equipSetA.id) < isValueInArray(self.itemSetOrderList, equipSetB.id)
			end
		elseif equipSlotA then
			return true
		elseif equipSlotB then
			return false
		end
		return itemA.name < itemB.name
	end)
	self:AddUndoState()
end

-- Deletes an item
function ItemsTabClass:DeleteItem(item, deferUndoState)
	for slotName, slot in pairs(self.slots) do
		if slot.selItemId == item.id then
			slot:SetSelItemId(0)
			self.build.buildFlag = true
		end
		if not slot.nodeId then
			for _, itemSet in pairs(self.itemSets) do
				if itemSet[slotName].selItemId == item.id then
					itemSet[slotName].selItemId = 0
					self.build.buildFlag = true
				end
			end
		end
	end
	for index, id in pairs(self.itemOrderList) do
		if id == item.id then
			t_remove(self.itemOrderList, index)
			break
		end
	end
	for _, spec in pairs(self.build.treeTab.specList) do
		local rebuildClusterJewelGraphs = false
		for nodeId, itemId in pairs(spec.jewels) do
			if itemId == item.id then
				spec.jewels[nodeId] = 0
				rebuildClusterJewelGraphs = true
				-- Deallocate all nodes that required this jewel
				if spec.nodes[nodeId] then
					for depNodeId, depNode in ipairs(spec.nodes[nodeId].depends) do
						depNode.alloc = false
						spec.allocNodes[depNodeId] = nil
					end
					spec.nodes[nodeId].alloc = false
					spec.allocNodes[nodeId] = nil
				end
			end
		end
		if rebuildClusterJewelGraphs and not deferUndoState then
			spec:BuildClusterJewelGraphs()
		end
	end
	self.items[item.id] = nil
	if not deferUndoState then
		self:PopulateSlots()
		self:AddUndoState()
	end
end

-- Attempt to create a new item from the given item raw text and sets it as the new display item
function ItemsTabClass:CreateDisplayItemFromRaw(itemRaw, normalise)
	local newItem = new("Item", itemRaw)
	if newItem.base then
		if normalise then
			newItem:NormaliseQuality()
			newItem:BuildModList()
		end
		self:SetDisplayItem(newItem)
	end
end

-- Sets the display item to the given item
function ItemsTabClass:SetDisplayItem(item)
	self.displayItem = item
	if item then
		-- Update the display item controls
		self:UpdateDisplayItemTooltip()
		self.snapHScroll = "RIGHT"

		self.controls.displayItemVariant.list = item.variantList
		self.controls.displayItemVariant.selIndex = item.variant
		self.controls.displayItemVariant:CheckDroppedWidth(true)
		if item.hasAltVariant then
			self.controls.displayItemAltVariant.list = item.variantList
			self.controls.displayItemAltVariant.selIndex = item.variantAlt
			self.controls.displayItemAltVariant:CheckDroppedWidth(true)
		end
		if item.hasAltVariant2 then
			self.controls.displayItemAltVariant2.list = item.variantList
			self.controls.displayItemAltVariant2.selIndex = item.variantAlt2
			self.controls.displayItemAltVariant2:CheckDroppedWidth(true)
		end
		if item.hasAltVariant3 then
			self.controls.displayItemAltVariant3.list = item.variantList
			self.controls.displayItemAltVariant3.selIndex = item.variantAlt3
			self.controls.displayItemAltVariant3:CheckDroppedWidth(true)
		end
		if item.hasAltVariant4 then
			self.controls.displayItemAltVariant4.list = item.variantList
			self.controls.displayItemAltVariant4.selIndex = item.variantAlt4
			self.controls.displayItemAltVariant4:CheckDroppedWidth(true)
		end
		if item.hasAltVariant5 then
			self.controls.displayItemAltVariant5.list = item.variantList
			self.controls.displayItemAltVariant5.selIndex = item.variantAlt5
			self.controls.displayItemAltVariant5:CheckDroppedWidth(true)
		end
		if item.crafted then
			self:UpdateAffixControls()
		end
		self.controls.displayItemSocketRuneEdit:SetText(item.itemSocketCount)
		self.controls.displayItemQualityEdit:SetText(item.quality)
		self.controls.displayItemCatalyst:SetSel((item.catalyst or 0) + 1)
		if item.catalystQuality then
			self.controls.displayItemCatalystQualityEdit:SetText(m_max(item.catalystQuality, 0))
		else
			self.controls.displayItemCatalystQualityEdit:SetText(0)
		end
		self:UpdateCustomControls()
		self:UpdateRuneControls()
		self:UpdateDisplayItemRangeLines()
		if item.clusterJewel and item.crafted then
			self:UpdateClusterJewelControls()
		end
	else
		self.snapHScroll = "LEFT"
	end
end

function ItemsTabClass:UpdateDisplayItemTooltip()
	self.displayItemTooltip:Clear()
	self:AddItemTooltip(self.displayItemTooltip, self.displayItem)
	self.displayItemTooltip.center = true
end

function ItemsTabClass:UpdateClusterJewelControls()
	local item = self.displayItem

	local unavailableSkills = { ["affliction_strength"] = true, ["affliction_dexterity"] = true, ["affliction_intelligence"] = true, }

	-- Update list of skills
	local skillList = wipeTable(self.controls.displayItemClusterJewelSkill.list)
	for skillId, skill in pairs(item.clusterJewel.skills) do
		if not unavailableSkills[skillId] then
			t_insert(skillList, { label = skill.name, skillId = skillId })
		end
	end
	table.sort(skillList, function(a, b) return a.label < b.label end)
	if not item.clusterJewelSkill or not item.clusterJewel.skills[item.clusterJewelSkill] then
		item.clusterJewelSkill = skillList[1].skillId
	end
	self.controls.displayItemClusterJewelSkill:SelByValue(item.clusterJewelSkill, "skillId")

	-- Update added node count slider
	local countControl = self.controls.displayItemClusterJewelNodeCount
	item.clusterJewelNodeCount = m_min(m_max(item.clusterJewelNodeCount or item.clusterJewel.maxNodes, item.clusterJewel.minNodes), item.clusterJewel.maxNodes)
	countControl.divCount = item.clusterJewel.maxNodes - item.clusterJewel.minNodes
	countControl.val = (item.clusterJewelNodeCount - item.clusterJewel.minNodes) / (item.clusterJewel.maxNodes - item.clusterJewel.minNodes)

	self:CraftClusterJewel()
end

function ItemsTabClass:CraftClusterJewel()
	local item = self.displayItem
	wipeTable(item.enchantModLines)
	t_insert(item.enchantModLines, { line = "Adds "..(item.clusterJewelNodeCount or item.clusterJewel.maxNodes).." Passive Skills", enchant = true })
	if item.clusterJewel.size == "Large" then
		t_insert(item.enchantModLines, { line = "2 Added Passive Skills are Jewel Sockets", enchant = true })
	elseif item.clusterJewel.size == "Medium" then
		t_insert(item.enchantModLines, { line = "1 Added Passive Skill is a Jewel Socket", enchant = true })
	end
	local skill = item.clusterJewel.skills[item.clusterJewelSkill]
	t_insert(item.enchantModLines, { line = table.concat(skill.enchant, "\n"), enchant = true })
	item:BuildAndParseRaw()

	-- Update affixes manually to force out affixes that may now be invalid
	self:UpdateAffixControls()
	for i = 1, item.affixLimit do
		local drop = self.controls["displayItemAffix"..i]
		drop.selFunc(drop.selIndex, drop.list[drop.selIndex])
	end
end

-- Update affix selection controls
function ItemsTabClass:UpdateAffixControls()
	local item = self.displayItem
	local prefixLimit = item.prefixes.limit or (item.affixLimit / 2)
	for i = 1, item.affixLimit do
		if i <= prefixLimit then
			self:UpdateAffixControl(self.controls["displayItemAffix"..i], item, "Prefix", "prefixes", i)
		else
			self:UpdateAffixControl(self.controls["displayItemAffix"..i], item, "Suffix", "suffixes", i - prefixLimit)
		end
	end	
	-- The custom affixes may have had their indexes changed, so the custom control UI is also rebuilt so that it will
	-- reference the correct affix index.
	self:UpdateCustomControls()
end

local runeModLines = { { name = "None", label = "None", order = -1, slot = "None", group = -1 } }
for name, runeMods in pairs(data.itemMods.Runes) do
	-- Some runes have multiple mod lines; insert each as separate entry
	for slotType, runeMod in pairs(runeMods) do
		for i, mod in ipairs(runeMod) do
			t_insert(runeModLines, { name = name, label = mod, order = runeMod.statOrder[1], slot = slotType, group = #runeMod })
		end
	end
end
table.sort(runeModLines, function(a, b)
	if a.order == b.order then
		return a.label < b.label
	elseif a.group == b.group then
		return a.order < b.order
	else
		return a.group < b.group
	end
end)
-- Update rune selection controls
function ItemsTabClass:UpdateRuneControls()
	local item = self.displayItem
	-- Build rune selection for item
	local runes = { }
	for _, rune in pairs(runeModLines) do
		if rune.slot == "None" or -- Needed "None" for Items Tab
			item.base.type:lower() == rune.slot or
			item.base.type == rune.slot or
			item.base.weapon and rune.slot == "weapon" or
			item.base.armour and rune.slot == "armour" or
			(item.base.tags.wand or item.base.tags.staff) and rune.slot == "caster" then
			table.insert(runes, rune)
		end
	end

	for i = 1, item.itemSocketCount do
		self.controls["displayItemRune"..i].list = runes
		if item.runes[i] then
			for j, modLine in ipairs(self.controls["displayItemRune"..i].list) do
				if item.runes[i] == modLine.name then
					self.controls["displayItemRune"..i].selIndex = j
				end
			end
		else
			self.controls["displayItemRune"..i].selIndex = 1
		end
	end
end

function ItemsTabClass:UpdateAffixControl(control, item, type, outputTable, outputIndex)
	local extraTags = { }
	local excludeGroups = { }
	for _, table in ipairs({"prefixes","suffixes"}) do
		for index = 1, (item[table].limit or (item.affixLimit / 2)) do
			if index ~= outputIndex or table ~= outputTable then
				local mod = item.affixes[item[table][index] and item[table][index].modId]
				if mod then
					if mod.group then
						excludeGroups[mod.group] = true
					end
					if mod.tags then
						for _, tag in ipairs(mod.tags) do
							extraTags[tag] = true
						end
					end
				end
			end
		end
	end
	if item.clusterJewel and item.clusterJewelSkill then	
		local skill = item.clusterJewel.skills[item.clusterJewelSkill]
		if skill then
			extraTags[skill.tag] = true
		end
	end
	local affixList = { }
	for modId, mod in pairs(item.affixes) do
		if mod.type == type and not excludeGroups[mod.group] and item:GetModSpawnWeight(mod, extraTags) > 0 then
			t_insert(affixList, modId)
		end
	end
	table.sort(affixList, function(a, b)
		local modA = item.affixes[a]
		local modB = item.affixes[b]
		for i = 1, m_max(#modA, #modB) do
			if not modA[i] then
				return true
			elseif not modB[i] then
				return false
			elseif modA.statOrder[i] ~= modB.statOrder[i] then
				return modA.statOrder[i] < modB.statOrder[i]
			end
		end
		return modA.level > modB.level
	end)
	control.selIndex = 1
	control.list = { "None" }
	control.outputTable = outputTable
	control.outputIndex = outputIndex
	control.slider.shown = false
	control.slider.val = main.defaultItemAffixQuality or 0.5
	local selAffix = item[outputTable][outputIndex].modId
	if (item.type == "Jewel" and item.base.subType ~= "Abyss") then
		for i, modId in pairs(affixList) do
			local mod = item.affixes[modId]
			if selAffix == modId then
				control.selIndex = i + 1
			end
			local modString = table.concat(mod, "/")
			local label = modString
			if item.type == "Flask" then
				label = mod.affix .. "   ^8[" .. modString .. "]"
			end
			-- shorten time-lost jewel affix labels to fit the dropdown
			if label and item.baseName:find("Time%-Lost") ~= nil then
				label = label:gsub(" Passive Skills in Radius also grant", ":")
			end
			control.list[i + 1] = {
				label = label,
				modList = { modId },
				modId = modId,
				haveRange = modString:match("%(%-?[%d%.]+%-%-?[%d%.]+%)"),
			}
		end
	else
		local lastSeries
		for _, modId in ipairs(affixList) do
			local mod = item.affixes[modId]
			if not lastSeries or not tableDeepEquals(lastSeries.statOrder, mod.statOrder) then
				local modString = table.concat(mod, "/")
				lastSeries = {
					label = modString,
					modList = { },
					haveRange = modString:match("%(%-?[%d%.]+%-%-?[%d%.]+%)"),
					statOrder = mod.statOrder,
				}
				t_insert(control.list, lastSeries)
			end
			if selAffix == modId then
				control.selIndex = #control.list
			end
			t_insert(lastSeries.modList, 1, modId)
			if #lastSeries.modList == 2 then
				lastSeries.label = lastSeries.label:gsub("%(%-?[%d%.]+%-%-?[%d%.]+%)","#"):gsub("%-?%d+%.?%d*","#")
				lastSeries.haveRange = true
			end
		end
	end
	if control.list[control.selIndex].haveRange then
		control.slider.divCount = #control.list[control.selIndex].modList
		control.slider.val = (isValueInArray(control.list[control.selIndex].modList, selAffix) - 1 + (item[outputTable][outputIndex].range or 0.5)) / control.slider.divCount
		if control.slider.divCount == 1 then
			control.slider.divCount = nil
		end
		control.slider.shown = true
	end
end

-- Create/update custom modifier controls
function ItemsTabClass:UpdateCustomControls()
	local item = self.displayItem
	local i = 1
	local modLines = copyTable(item.explicitModLines)
	if item.rarity == "MAGIC" or item.rarity == "RARE" then
		for index, modLine in ipairs(modLines) do
			if modLine.custom then
				local line = itemLib.formatModLine(modLine)
				if line then
					if not self.controls["displayItemCustomModifierRemove"..i] then
						self.controls["displayItemCustomModifierRemove"..i] = new("ButtonControl", {"TOPLEFT",self.controls.displayItemSectionCustom,"TOPLEFT"}, {0, i * 22 + 4, 70, 20}, "^7Remove")
						self.controls["displayItemCustomModifier"..i] = new("LabelControl", {"LEFT",self.controls["displayItemCustomModifierRemove"..i],"RIGHT"}, {65, 0, 0, 16})
						self.controls["displayItemCustomModifierLabel"..i] = new("LabelControl", {"LEFT",self.controls["displayItemCustomModifierRemove"..i],"RIGHT"}, {5, 0, 0, 16})
					end
					self.controls["displayItemCustomModifierRemove"..i].shown = true
					local label = itemLib.formatModLine(modLine)
					if DrawStringCursorIndex(16, "VAR", label, 330, 10) < #label then
						label = label:sub(1, DrawStringCursorIndex(16, "VAR", label, 310, 10)) .. "..."
					end
					self.controls["displayItemCustomModifier"..i].label = label
					self.controls["displayItemCustomModifierLabel"..i].label = " ^7Custom:"
					self.controls["displayItemCustomModifierRemove"..i].onClick = function()
						if index <= #item.explicitModLines then
							t_remove(item.explicitModLines, index)
						end
						item:BuildAndParseRaw()
						local id = item.id
						self:CreateDisplayItemFromRaw(item:BuildRaw())
						self.displayItem.id = id
					end				
					i = i + 1
				end
			end
		end
	end
	item.customCount = i - 1
	while self.controls["displayItemCustomModifierRemove"..i] do
		self.controls["displayItemCustomModifierRemove"..i].shown = false
		i = i + 1
	end
end

-- Updates the range line dropdown and range slider for the current display item
function ItemsTabClass:UpdateDisplayItemRangeLines()
	if self.displayItem and self.displayItem.rangeLineList[1] then
		wipeTable(self.controls.displayItemRangeLine.list)
		for _, modLine in ipairs(self.displayItem.rangeLineList) do
			-- primarily for Against the Darkness // a way to cut down on really long modLines, gsub could be updated for others
			t_insert(self.controls.displayItemRangeLine.list, (modLine.line:gsub(" Passive Skills in Radius also grant", ":")))
		end
		self.controls.displayItemRangeLine.selIndex = 1
		self.controls.displayItemRangeSlider.val = self.displayItem.rangeLineList[1].range
	end
end

local function checkLineForAllocates(line, nodes)
	if nodes and string.match(line, "Allocates") then
		local nodeId = tonumber(string.match(line, "%d+"))
		if nodes[nodeId] then
			return "Allocates "..nodes[nodeId].name
		end
	end
	return line
end

function ItemsTabClass:AddModComparisonTooltip(tooltip, mod)
	local slotName = self.displayItem:GetPrimarySlot()
	local newItem = new("Item", self.displayItem:BuildRaw())
	
	for _, subMod in ipairs(mod) do
		t_insert(newItem.explicitModLines, { line = checkLineForAllocates(subMod, self.build.spec.nodes), modTags = mod.modTags, [mod.type or "Suffix"] = true })
	end

	newItem:BuildAndParseRaw()

	local calcFunc = self.build.calcsTab:GetMiscCalculator()
	local outputBase = calcFunc({ repSlotName = slotName, repItem = self.displayItem })
	local outputNew = calcFunc({ repSlotName = slotName, repItem = newItem })
	self.build:AddStatComparesToTooltip(tooltip, outputBase, outputNew, "\nAdding this mod will give: ")	
end

-- Returns the first slot in which the given item is equipped
function ItemsTabClass:GetEquippedSlotForItem(item)
	for _, slot in ipairs(self.orderedSlots) do
		if not slot.inactive then
			if slot.selItemId == item.id then
				return slot
			end
			for _, itemSetId in ipairs(self.itemSetOrderList) do
				local itemSet = self.itemSets[itemSetId]
				if itemSetId ~= self.activeItemSetId and itemSet[slot.slotName] and itemSet[slot.slotName].selItemId == item.id then
					return slot, itemSet
				end
			end
		end
	end
end

-- Check if the given item could be equipped in the given slot, taking into account possible conflicts with currently equipped items
-- For example, a shield is not valid for Weapon 2 if Weapon 1 is a staff, and a wand is not valid for Weapon 2 if Weapon 1 is a dagger
function ItemsTabClass:IsItemValidForSlot(item, slotName, itemSet)
	itemSet = itemSet or self.activeItemSet
	local slotType, slotId = slotName:match("^([%a ]+) (%d+)$")
	if not slotType then
		slotType = slotName
	end
	if slotType == "Jewel" then
		-- Special checks for jewel sockets
		local node = self.build.spec.tree.nodes[tonumber(slotId)] or self.build.spec.nodes[tonumber(slotId)]
		if not node or item.type ~= "Jewel" then
			return false
		elseif node.containJewelSocket  then
			if item.rarity == "UNIQUE" or item.rarity == "RELIC" or (item.base and item.base.subType ~= nil) then
				-- Lich socket can only accept basic non-unique jewels
				-- Need to change this to use ModParser if GGG add different conditional ascendancy jewel sockets
				return false
			end
			return true
		elseif node.charmSocket or item.base.subType == "Charm" then
			-- Charm sockets can only have charms, and charms can only be in charm sockets
			if node.charmSocket and item.base.subType == "Charm" then
				return true
			end
			return false
		elseif item.clusterJewel and not node.expansionJewel then
			-- Don't allow cluster jewels in inner sockets
			return false
		elseif not node.expansionJewel or node.expansionJewel.size == 2 then
			-- Outer sockets can fit anything
			return true
		else
			-- Only allow jewels that fit in this socket
			return not item.clusterJewel or item.clusterJewel.sizeIndex <= node.expansionJewel.size
		end
	elseif item.type == "Flask" and slotType == "Flask" then
		if item.baseName:match("Life Flask") and slotName:match("Flask 1") then
			return true
		elseif item.baseName:match("Mana Flask") and slotName:match("Flask 2") then
			return true
		end
	elseif item.type == slotType then
		return true
	elseif slotName == "Weapon 1" or slotName == "Weapon 1 Swap" or slotName == "Weapon" then
		return item.base.tags.onehand or item.base.tags.twohand
	elseif slotName == "Weapon 2" or slotName == "Weapon 2 Swap" then
		local weapon1Sel = itemSet[slotName == "Weapon 2" and "Weapon 1" or "Weapon 1 Swap"].selItemId or 0
		local weapon1Base = self.items[weapon1Sel] and self.items[weapon1Sel].base or "Unarmed"
		-- Calcs tab isn't loaded yet when the items tab gets loaded, so assume we have Giant's Blood until proven wrong
		local giantsBlood = true
		if self.build.calcsTab and self.build.calcsTab.mainEnv then
			giantsBlood = self.build.calcsTab.mainEnv.modDB:Flag(nil, "GiantsBlood")
		end
		if weapon1Base.type == "Bow" then
			return item.type == "Quiver"
		elseif weapon1Base == "Unarmed" or weapon1Base.tags.onehand or (giantsBlood and (weapon1Base.tags.axe or weapon1Base.tags.mace or weapon1Base.tags.sword)) then
			return item.type == "Shield" or item.type == "Focus" or item.type == "Sceptre"
					or (item.base.tags.one_hand_weapon and weapon1Base.type ~= "Wand" and weapon1Base.type ~= "Sceptre")
					or (giantsBlood and (item.base.tags.axe or item.base.tags.mace or item.base.tags.sword))
		end
	end
end

-- Opens the item set manager
function ItemsTabClass:OpenItemSetManagePopup()
	local controls = { }
	controls.setList = new("ItemSetListControl", nil, {-155, 50, 300, 200}, self)
	controls.sharedList = new("SharedItemSetListControl", nil, {155, 50, 300, 200}, self)
	controls.setList.dragTargetList = { controls.sharedList }
	controls.sharedList.dragTargetList = { controls.setList }
	controls.close = new("ButtonControl", nil, {0, 260, 90, 20}, "Done", function()
		main:ClosePopup()
	end)
	main:OpenPopup(630, 290, "Manage Item Sets", controls)
end

-- Opens the item crafting popup
function ItemsTabClass:CraftItem()
	local controls = { }
	local function makeItem(base)
		local item = new("Item")
		item.name = base.name
		item.base = base.base
		item.baseName = base.name
		item.charmLimit = base.charmLimit
		item.spiritValue = base.spiritValue
		item.buffModLines = { }
		item.enchantModLines = { }
		item.runeModLines = { }
		item.classRequirementModLines = { }
		item.implicitModLines = { }
		item.explicitModLines = { }
		item.sockets = { }
		item.runes = { }
		if base.base.quality then
			item.quality = 0
		else
			item.quality = nil
		end
		if base.base.socketLimit and (base.base.weapon or base.base.armour or base.base.tags.wand or base.base.tags.staff or base.base.tags.sceptre) then -- must be a martial weapon/armour
			if #item.sockets == 0 then
				for i = 1, base.base.socketLimit do
					t_insert(item.sockets, { group = 0 })
				end
				item.itemSocketCount = #item.sockets
			end
		end
		local raritySel = controls.rarity.selIndex
		if base.base.flask
				or (base.base.type == "Jewel" and base.base.subType == "Charm")
		 		or base.base.type == "Charm"
		then
			if raritySel == 3 then
				raritySel = 2
			end
		end
		if base.base.type == "SoulCore" or base.base.type == "Rune" then
			if raritySel == 3 or raritySel == 2 then
				raritySel = 1
			end
		end
		if raritySel == 2 or raritySel == 3 then
			item.crafted = true
		end
		item.rarity = controls.rarity.list[raritySel].rarity
		if raritySel >= 3 then
			item.title = controls.title.buf:match("%S") and controls.title.buf or "New Item"
		end
		if base.base.implicit then
			local implicitIndex = 1
			for line in base.base.implicit:gmatch("[^\n]+") do
				local modList, extra = modLib.parseMod(line)
				t_insert(item.implicitModLines, { line = line, extra = extra, modList = modList or { }, modTags = base.base.implicitModTypes and base.base.implicitModTypes[implicitIndex] or { } })
				implicitIndex = implicitIndex + 1
			end
		end
		if base.base.type == "Jewel" and base.base.subType == "Radius" then
			item.jewelRadiusLabel = "Small"
		end
		item:NormaliseQuality()
		item:BuildAndParseRaw()
		return item
	end
	controls.rarityLabel = new("LabelControl", {"TOPRIGHT",nil,"TOPLEFT"}, {50, 20, 0, 16}, "Rarity:")
	controls.rarity = new("DropDownControl", nil, {-80, 20, 100, 18}, rarityDropList)
	controls.rarity.selIndex = self.lastCraftRaritySel or 3
	controls.title = new("EditControl", nil, {70, 20, 190, 18}, "", "Name")
	controls.title.shown = function()
		return controls.rarity.selIndex >= 3
	end
	controls.typeLabel = new("LabelControl", {"TOPRIGHT",nil,"TOPLEFT"}, {50, 45, 0, 16}, "Type:")
	controls.type = new("DropDownControl", {"TOPLEFT",nil,"TOPLEFT"}, {55, 45, 295, 18}, self.build.data.itemBaseTypeList, function(index, value)
		controls.base.list = self.build.data.itemBaseLists[self.build.data.itemBaseTypeList[index]]
		controls.base.selIndex = 1
	end)
	controls.type.selIndex = self.lastCraftTypeSel or 1
	controls.baseLabel = new("LabelControl", {"TOPRIGHT",nil,"TOPLEFT"}, {50, 70, 0, 16}, "Base:")
	controls.base = new("DropDownControl", {"TOPLEFT",nil,"TOPLEFT"}, {55, 70, 200, 18}, self.build.data.itemBaseLists[self.build.data.itemBaseTypeList[controls.type.selIndex]])
	controls.base.selIndex = self.lastCraftBaseSel or 1
	controls.base.tooltipFunc = function(tooltip, mode, index, value)
		tooltip:Clear()
		if mode ~= "OUT" then
			self:AddItemTooltip(tooltip, makeItem(value), nil, true)
		end
	end
	controls.save = new("ButtonControl", nil, {-45, 100, 80, 20}, "Create", function()
		main:ClosePopup()
		local item = makeItem(controls.base.list[controls.base.selIndex])
		self:SetDisplayItem(item)
		if not item.crafted and item.rarity ~= "NORMAL" then
			self:EditDisplayItemText()
		end
		self.lastCraftRaritySel = controls.rarity.selIndex
		self.lastCraftTypeSel = controls.type.selIndex
		self.lastCraftBaseSel = controls.base.selIndex
	end)
	controls.cancel = new("ButtonControl", nil, {45, 100, 80, 20}, "Cancel", function()
		main:ClosePopup()
	end)
	main:OpenPopup(370, 130, "Craft Item", controls)
end

-- Opens the item text editor popup
function ItemsTabClass:EditDisplayItemText(alsoAddItem)
	local controls = { }
	local function buildRaw()
		local editBuf = controls.edit.buf
		if editBuf:match("^Item Class: .*\nRarity: ") or editBuf:match("^Rarity: ") then
			return editBuf
		else
			return "Rarity: "..controls.rarity.list[controls.rarity.selIndex].rarity.."\n"..controls.edit.buf
		end
	end
	controls.rarity = new("DropDownControl", nil, {-190, 10, 100, 18}, rarityDropList)
	controls.edit = new("EditControl", nil, {0, 40, 480, 420}, "", nil, "^%C\t\n", nil, nil, 14)
	if self.displayItem then
		controls.edit:SetText(self.displayItem:BuildRaw():gsub("Rarity: %w+\n",""))
		controls.rarity:SelByValue(self.displayItem.rarity, "rarity")
	else
		controls.rarity.selIndex = 3
	end
	controls.edit.font = "FIXED"
	controls.edit.pasteFilter = sanitiseText
	controls.save = new("ButtonControl", nil, {-45, 470, 80, 20}, self.displayItem and "Save" or "Create", function()
		local id = self.displayItem and self.displayItem.id
		self:CreateDisplayItemFromRaw(buildRaw(), not self.displayItem)
		self.displayItem.id = id
		if alsoAddItem then
			self:AddDisplayItem()
		end
		main:ClosePopup()
	end, nil, true)
	controls.save.enabled = function()
		local item = new("Item", buildRaw())
		return item.base ~= nil
	end
	controls.save.tooltipFunc = function(tooltip)
		tooltip:Clear()
		local item = new("Item", buildRaw())
		if item.base then
			self:AddItemTooltip(tooltip, item, nil, true)
		else
			tooltip:AddLine(14, "The item is invalid.")
			tooltip:AddLine(14, "Check that the item's title and base name are in the correct format.")
			tooltip:AddLine(14, "For Rare and Unique items, the first 2 lines must be the title and base name. E.g.:")
			tooltip:AddLine(14, "Abberath's Horn")
			tooltip:AddLine(14, "Goat's Horn")
			tooltip:AddLine(14, "For Normal and Magic items, the base name must be somewhere in the first line. E.g.:")
			tooltip:AddLine(14, "Scholar's Platinum Kris of Joy")
		end
	end	
	controls.cancel = new("ButtonControl", nil, {45, 470, 80, 20}, "Cancel", function()
		main:ClosePopup()
	end)
	main:OpenPopup(500, 500, self.displayItem and "Edit Item Text" or "Create Custom Item from Text", controls, nil, "edit")
end

---Gets the name of the anointed node on an item
---@param item table @The item to get the anoint from
---@return string @The name of the anointed node, or nil if there is no anoint
function ItemsTabClass:getAnoint(item)
	local result = { }
	if item then
		for _, modList in ipairs{item.enchantModLines, item.implicitModLines, item.explicitModLines} do
			for _, mod in ipairs(modList) do
				local line = mod.line
				local anoint = line:find("Allocates ([a-zA-Z ]+)")
				if anoint then
					local nodeName = line:sub(anoint + string.len("Allocates "))
					t_insert(result, nodeName)
				end
			end
		end
	end
	return result
end

---Returns a copy of the currently displayed item, but anointed with a new node.
---Removes any existing enchantments before anointing. (Anoints are considered enchantments)
---@param node table @The passive tree node to anoint, or nil to just remove existing anoints.
---@return table @The new item
function ItemsTabClass:anointItem(node)
	self.anointEnchantSlot = self.anointEnchantSlot or 1
	local item = new("Item", self.displayItem:BuildRaw())
	item.id = self.displayItem.id
	if #item.enchantModLines >= self.anointEnchantSlot then
		t_remove(item.enchantModLines, self.anointEnchantSlot)
	end
	if node then
		t_insert(item.enchantModLines, self.anointEnchantSlot, { enchant = true, line = "Allocates " .. node.dn })
	end
	item:BuildAndParseRaw()
	return item
end

---Appends tooltip information for anointing a new passive tree node onto the currently editing amulet
---@param tooltip table @The tooltip to append into
---@param node table @The passive tree node that will be anointed, or nil to remove the current anoint.
function ItemsTabClass:AppendAnointTooltip(tooltip, node, actionText)
	if not self.displayItem then
		return
	end

	if not actionText then
		actionText = "Anointing"
	end

	local header
	if node then
		if self.build.spec.allocNodes[node.id] then
			tooltip:AddLine(14, "^7"..actionText.." "..node.dn.." changes nothing because this node is already allocated on the tree.")
			return
		end

		local curAnoints = self:getAnoint(self.displayItem)
		if curAnoints and #curAnoints > 0 then
			for _, curAnoint in ipairs(curAnoints) do
				if curAnoint == node.dn then
					tooltip:AddLine(14, "^7"..actionText.." "..node.dn.." changes nothing because this node is already anointed.")
					return
				end
			end
		end

		header = "^7"..actionText.." "..node.dn.." will give you: "
	else
		header = "^7"..actionText.." nothing will give you: "
	end
	local calcFunc = self.build.calcsTab:GetMiscCalculator()
	local outputBase = calcFunc({ repSlotName = "Amulet", repItem = self.displayItem })
	local outputNew = calcFunc({ repSlotName = "Amulet", repItem = self:anointItem(node) })
	local numChanges = self.build:AddStatComparesToTooltip(tooltip, outputBase, outputNew, header)
	if node and numChanges == 0 then
		tooltip:AddLine(14, "^7"..actionText.." "..node.dn.." changes nothing.")
	end
end

---Appends tooltip with information about added notable passive node if it would be allocated.
---@param tooltip table @The tooltip to append into
---@param node table @The passive tree node that will be added
function ItemsTabClass:AppendAddedNotableTooltip(tooltip, node)
	local calcFunc, calcBase = self.build.calcsTab:GetMiscCalculator()
	local outputNew = calcFunc({ addNodes = { [node] = true } })
	local numChanges = self.build:AddStatComparesToTooltip(tooltip, calcBase, outputNew, "^7Allocating "..node.dn.." will give you: ")
	if numChanges == 0 then
		tooltip:AddLine(14, "^7Allocating "..node.dn.." changes nothing.")
	end
end

-- Opens the item anointing popup
function ItemsTabClass:AnointDisplayItem(enchantSlot)
	self.anointEnchantSlot = enchantSlot or 1

	local controls = { } 
	controls.notableDB = new("NotableDBControl", {"TOPLEFT",nil,"TOPLEFT"}, {10, 20, 360, 400}, self, self.build.spec.tree.nodes, "ANOINT")

	local function saveLabel()
		local node = controls.notableDB.selValue
		if node then
			return "Anoint " .. node.dn
		end
		local curAnoints = self:getAnoint(self.displayItem)
		if curAnoints and #curAnoints >= self.anointEnchantSlot then
			return "Remove "..curAnoints[self.anointEnchantSlot]
		end
		return "No Anoint"
	end
	local function saveLabelWidth()
		local label = saveLabel()
		return DrawStringWidth(16, "VAR", label) + 10
	end
	local function saveLabelX()
		local width = saveLabelWidth()
		return -(width + 90) / 2
	end
	controls.save = new("ButtonControl", {"BOTTOMLEFT", nil, "BOTTOM" }, {saveLabelX, -4, saveLabelWidth, 20}, saveLabel, function()
		self:SetDisplayItem(self:anointItem(controls.notableDB.selValue))
		main:ClosePopup()
	end)
	controls.save.tooltipFunc = function(tooltip)
		tooltip:Clear()
		self:AppendAnointTooltip(tooltip, controls.notableDB.selValue)
	end	
	controls.close = new("ButtonControl", {"TOPLEFT", controls.save, "TOPRIGHT" }, {10, 0, 80, 20}, "Cancel", function()
		main:ClosePopup()
	end)
	main:OpenPopup(380, 448, "Anoint Item", controls)
end

-- Opens the item corrupting popup
function ItemsTabClass:CorruptDisplayItem() -- todo implement vaal orb new outcomes this code is for poe 1
	local controls = { } 
	local enchantList = { }
	local enchantNum = 1
	local shownExplicits = {}
	local explicitOffset = 0
	local corruptedRanges = {}
	local currentModType = "Corrupted"
	local sourceList = { "Corrupted" }
	if self.displayItem.base.type == "Helmet" then
		t_insert(sourceList, "Glimpse of Chaos")
	end
	local function buildEnchantList(modType)
		if enchantList[modType] then
			return
		end
		enchantList[modType] = {}
		for modId, mod in pairs(data.itemMods.Corruption) do
			if mod.type == modType and self.displayItem:GetModSpawnWeight(mod) > 0 then
				t_insert(enchantList[modType], mod)
			end
		end
		table.sort(enchantList[modType], function(a, b)
			local an = a[1]:lower():gsub("%(.-%)","$"):gsub("[%+%-%%]",""):gsub("%d+","$")
			local bn = b[1]:lower():gsub("%(.-%)","$"):gsub("[%+%-%%]",""):gsub("%d+","$")
			if an ~= bn then
				return an < bn
			else
				return a.level < b.level
			end
		end)
	end
	buildEnchantList("Corrupted")
	buildEnchantList("SpecialCorrupted")
	local function buildList(control, others, modType)
		local selfMod = control.selIndex and control.selIndex > 1 and control.list[control.selIndex].mod
		wipeTable(control.list)
		t_insert(control.list, { label = "None" })
		for _, mod in ipairs(enchantList[modType]) do
			local alreadySelected = false
			for _, other in ipairs(others) do
				local otherMod = other and other.selIndex and other.selIndex > 1 and other.list[other.selIndex].mod
				if otherMod and mod.group == otherMod.group then
					alreadySelected = true
				end
			end
			if not alreadySelected then
				t_insert(control.list, { label = table.concat(mod, "/"), mod = mod })
			end
		end
		control:SelByValue(selfMod, "mod")
	end
	local function corruptItem() 
		local item = new("Item", self.displayItem:BuildRaw())
		item.id = self.displayItem.id
		item.corrupted = true
		local newEnchant = { }
		for i = 1, enchantNum do
			local control = controls["enchant"..i]
			if control.selIndex > 1 then
				local mod = control.list[control.selIndex].mod
				for i, modLine in ipairs(mod) do
					if mod.modTags[1] then
						t_insert(newEnchant, { line = "{tags:" .. table.concat(mod.modTags, ",") .. "}" .. modLine, enchant = true, order = mod.statOrder[i] })
					else
						t_insert(newEnchant, { line = modLine, enchant = true, order = mod.statOrder[i] })
					end
				end
			end
		end
		if #newEnchant > 0 then
			table.sort(newEnchant, function(a, b)
				return a.order < b.order
			end)
			wipeTable(item.enchantModLines)
			for i, enchant in ipairs(newEnchant) do
				enchant.order = nil
				t_insert( item.enchantModLines, i, enchant)
			end
		end
		for i, modLine in ipairs(item.explicitModLines) do
			if corruptedRanges[i] ~= 1 then modLine.corruptedRange = corruptedRanges[i] end
		end
		item:BuildAndParseRaw()
		return item
	end
	if self.displayItem.rarity == "UNIQUE" then
		local item = new("Item", self.displayItem:BuildRaw())
		local offset = 20
		for i, mod in ipairs(item.explicitModLines) do
			local variantIds = {}
			for id, _ in pairs(item.explicitModLines[i].variantList or {}) do
				t_insert(variantIds, id)
			end
			local selectedVariant
			for _, variantId in ipairs(variantIds) do
				if item.variant == variantId or item.variantAlt == variantId or item.variantAlt2 == variantId or item.variantAlt3 == variantId or item.variantAlt4 == variantId or item.variantAlt5 == variantId then
					selectedVariant = true
				end
			end
			if #variantIds > 0 and selectedVariant or #variantIds == 0 then
				local label = ""
				controls["rollRangeValue"..i] = new("LabelControl", {"TOPLEFT",nil,"TOPLEFT"}, {10, 10 + offset, 200, 16}, "^71.00")
				controls["rollRangeSlider"..i] = new("SliderControl", { "LEFT", controls["rollRangeValue"..i], "RIGHT" }, {5, 0, 80, 18}, function(val)
					corruptedRanges[i] = 0.78+round(0.44*val, 2) -- 0.78-1.22
					controls["rollRangeValue"..i].label = "^7"..string.format("%.2f", corruptedRanges[i])
					local label = ""
					for i, line in ipairs(main:WrapString("^7"..itemLib.applyRange(mod.line, mod.range or main.defaultItemAffixQuality, mod.valueScalar or 1, corruptedRanges[i]),16,430)) do
						if i == 1 then
							label = line
						else
							label = label.."\n"..line
						end
					end
					controls["rollRangeLabel"..i].label = label
				end)
				corruptedRanges[i] = mod.corruptedRange or 1
				controls["rollRangeSlider"..i].val = ((corruptedRanges[i])-0.78)/0.44
				controls["rollRangeValue"..i].label = "^7"..string.format("%.2f", corruptedRanges[i])
				for i, line in ipairs(main:WrapString("^7"..itemLib.applyRange(mod.line, mod.range or main.defaultItemAffixQuality, mod.valueScalar or 1, corruptedRanges[i]),16,430)) do
					if i == 1 then
						label = line
					else
						offset = offset + 16
						label = label.."\n"..line
					end
				end
				controls["rollRangeLabel"..i] = new("LabelControl", {"LEFT", controls["rollRangeSlider"..i], "RIGHT"}, {5, 0 , 200, 16}, label)
				-- hide them by default as they are a secondary window
				controls["rollRangeLabel"..i].shown = false
				controls["rollRangeSlider"..i].shown = false
				controls["rollRangeValue"..i].shown = false
				offset = offset + 20
				t_insert(shownExplicits, i)
			end
		end
		explicitOffset = offset
	end
	controls.enchants = new("ButtonControl", {"TOPLEFT",nil,"TOPLEFT"}, {5, 5, 80, 20}, "Enchants", function()
		for i = 1, enchantNum do
			controls["enchant"..i].shown = true
			controls["enchant"..i.."Label"].shown = true
		end
		for _, i in ipairs(shownExplicits) do
			controls["rollRangeLabel"..i].shown = false
			controls["rollRangeSlider"..i].shown = false
			controls["rollRangeValue"..i].shown = false
		end
		controls.source.shown = true
		controls.sourceLabel.shown = true
		main.popups[1].height = 103 + 20 * enchantNum
		controls.close.y = 73 + 20 * enchantNum
		controls.save.y = 73 + 20 * enchantNum
	end)
	controls.enchants.shown = function ()
		return self.displayItem.rarity == "UNIQUE"
	end
	controls.rolls = new("ButtonControl", {"LEFT", controls.enchants, "RIGHT"}, {5, 0, 80, 20}, "Roll Ranges", function()
		for i = 1, 8 do
			controls["enchant"..i].shown = false
			controls["enchant"..i.."Label"].shown = false
		end
		for _, i in ipairs(shownExplicits) do
			controls["rollRangeLabel"..i].shown = true
			controls["rollRangeSlider"..i].shown = true
			controls["rollRangeValue"..i].shown = true
		end
		controls.source.shown = false
		controls.sourceLabel.shown = false
		main.popups[1].height = 55 + explicitOffset
		controls.close.y = 25 + explicitOffset
		controls.save.y = 25 + explicitOffset
	end)
	controls.rolls.shown = function ()
		return self.displayItem.rarity == "UNIQUE"
	end
	controls.sourceLabel = new("LabelControl", {"TOPRIGHT",nil,"TOPLEFT"}, {95, 30, 0, 16}, "^7Source:")
	controls.source = new("DropDownControl", {"TOPLEFT",nil,"TOPLEFT"}, {100, 30, 150, 18}, sourceList, function(index, value)
		if value == "Corrupted" then
			currentModType = "Corrupted"
			enchantNum = 1
		elseif value == "Glimpse of Chaos" and self.displayItem.base.type == "Helmet" then -- special corruption enchants
			currentModType = "SpecialCorrupted"
			if self.displayItem.title == "Glimpse of Chaos" then -- glimpse of chaos can have all 8 special enchants
				enchantNum = 8
			else -- other helmets can have 2
				enchantNum = 2
			end
		end

		for i = 1, 8 do
			if i <= enchantNum then
				controls["enchant"..i].shown = true
				controls["enchant"..i.."Label"].shown = true
				local others = { }
				for j = 1, enchantNum do
					if i ~= j then
						t_insert(others, controls["enchant"..j])
					end
				end
				buildList(controls["enchant"..i], others,  currentModType)
			else
				controls["enchant"..i].shown = false
				controls["enchant"..i.."Label"].shown = false
			end
			controls["enchant"..i]:SetSel(1)
		end
		main.popups[1].height = 103 + 20 * enchantNum
		controls.close.y = 73 + 20 * enchantNum
		controls.save.y = 73 + 20 * enchantNum
	end)
	for i = 1, 8 do
		if i == 1 then
			controls.enchant1Label = new("LabelControl", {"TOPRIGHT",nil,"TOPLEFT"}, {95, 55, 0, 16}, function()
				if enchantNum == 1 then -- update label so 1 doesn't appear in case of 1 enchant.
					return "^7Enchant:"
				else
					return "^7Enchant #1:"
				end
			end)
		else
			controls["enchant"..i.."Label"] = new("LabelControl", {"TOPRIGHT",nil,"TOPLEFT"}, {95, 35 + i * 20 , 0, 16}, "^7Enchant #"..i..":")
		end
		controls["enchant"..i] = new("DropDownControl", {"TOPLEFT",nil,"TOPLEFT"}, {100, 35 + i * 20, 440, 18}, nil, function()
			for i = 1, enchantNum do
				local others = { }
				for j = 1, enchantNum do
					if i ~= j then
						t_insert(others, controls["enchant"..j])
					end
				end
				buildList(controls["enchant"..i], others,  currentModType)
			end
		end)
		controls["enchant"..i].tooltipFunc = function(tooltip, mode, index, value)
			tooltip:Clear()
			if mode ~= "OUT" and value and value.mod then
				for _, line in ipairs(value.mod) do
					tooltip:AddLine(16, "^7"..line)
				end
				self:AddModComparisonTooltip(tooltip, value.mod)
			end
		end
		if i == 1 then
			controls["enchant"..i].shown = true
			controls["enchant"..i.."Label"].shown = true
		else
			controls["enchant"..i].shown = false
			controls["enchant"..i.."Label"].shown = false
		end

		if i <= enchantNum then
			local others = { }
			for j = 1, enchantNum do
				if i ~= j then
					t_insert(others, controls["enchant"..j])
				end
			end
			buildList(controls["enchant"..i], others,  currentModType)
		end
	end
	controls.save = new("ButtonControl", nil, {-45, 69 + enchantNum * 20, 80, 20}, "Corrupted", function()
		self:SetDisplayItem(corruptItem())
		main:ClosePopup()
	end)
	controls.save.tooltipFunc = function(tooltip)
		tooltip:Clear()
		self:AddItemTooltip(tooltip, corruptItem(), nil, true)
	end	
	controls.close = new("ButtonControl", nil, {45, 69 + enchantNum * 20, 80, 20}, "Cancel", function()
		main:ClosePopup()
	end)
	main:OpenPopup(620, 103 + enchantNum * 20, "Corrupted Item", controls)
end

-- Opens the custom modifier popup
function ItemsTabClass:AddCustomModifierToDisplayItem()
	local controls = { }
	local sourceList = { }
	local modList = { }
	---Mutates modList to contain mods from the specified source
	---@param sourceId string @The crafting source id to build the list of mods for
	local function buildMods(sourceId)
		wipeTable(modList)
		if sourceId == "PREFIX" or sourceId == "SUFFIX" then -- might be implied.
			for _, mod in pairs(self.displayItem.affixes) do
				if sourceId:lower() == mod.type:lower() and self.displayItem:GetModSpawnWeight(mod) > 0 then
					t_insert(modList, {
						label = mod.affix .. "   ^8[" .. table.concat(mod, "/") .. "]",
						mod = mod,
						type = "custom",
					})
				end
			end
			table.sort(modList, function(a, b)
				local modA = a.mod
				local modB = b.mod
				for i = 1, m_max(#modA, #modB) do
					if not modA[i] then
						return true
					elseif not modB[i] then
						return false
					elseif modA.statOrder[i] ~= modB.statOrder[i] then
						return modA.statOrder[i] < modB.statOrder[i]
					end
				end
				return modA.level > modB.level
			end)
		elseif sourceId == "ESSENCE" then
			for _, essence in pairs(self.build.data.essences) do
				local modId = essence.mods[self.displayItem.type]
				if modId then
					local mod = self.displayItem.affixes[modId] or data.itemMods.Exclusive[modId]
					if mod then -- passive_hash mods don't get described
						t_insert(modList, {
							label = essence.name .. "   " .. "^8[" .. table.concat(mod, "/") .. "]" .. " (" .. (mod.type or "Suffix") .. ")",
							mod = mod,
							type = "custom",
							essence = essence,
						})
					end
				end
			end
			table.sort(modList, function(a, b)
				if a.essence.type ~= b.essence.type then
					return a.essence.type > b.essence.type
				else
					return a.essence.tierLevel > b.essence.tierLevel
				end
			end)
		end
	end
	if not self.displayItem.crafted then
		t_insert(sourceList, { label = "Prefix", sourceId = "PREFIX" })
		t_insert(sourceList, { label = "Suffix", sourceId = "SUFFIX" })
	end
	buildMods("ESSENCE") 	-- This is technically a waste if there aren't any essence mods, 
									-- but it makes it so we don't have to maintain a list of applicable essence-able base types
	if #modList > 0 then
		t_insert(sourceList, { label = "Essence", sourceId = "ESSENCE" })
	end
	t_insert(sourceList, { label = "Custom", sourceId = "CUSTOM" })
	buildMods(sourceList[1].sourceId)
	local function addModifier()
		local item = new("Item", self.displayItem:BuildRaw())
		item.id = self.displayItem.id
		local sourceId = sourceList[controls.source.selIndex].sourceId
		if sourceId == "CUSTOM" then
			if controls.custom.buf:match("%S") then
				t_insert(item.explicitModLines, { line = controls.custom.buf, custom = true })
			end
		else
			local listMod = modList[controls.modSelect.selIndex]
			for _, line in ipairs(listMod.mod) do
				t_insert(item.explicitModLines, { line = line, modTags = listMod.mod.modTags, [listMod.type] = true })
			end
		end
		item:BuildAndParseRaw()
		return item
	end
	controls.sourceLabel = new("LabelControl", {"TOPRIGHT",nil,"TOPLEFT"}, {95, 20, 0, 16}, "^7Source:")
	controls.source = new("DropDownControl", {"TOPLEFT",nil,"TOPLEFT"}, {100, 20, 150, 18}, sourceList, function(index, value)
		buildMods(value.sourceId)
		controls.modSelect:SetSel(1)
	end)
	controls.source.enabled = #sourceList > 1
	controls.modSelectLabel = new("LabelControl", {"TOPRIGHT",nil,"TOPLEFT"}, {95, 45, 0, 16}, "^7Modifier:")
	controls.modSelect = new("DropDownControl", {"TOPLEFT",nil,"TOPLEFT"}, {100, 45, 600, 18}, modList)
	controls.modSelect.shown = function()
		return sourceList[controls.source.selIndex].sourceId ~= "CUSTOM"
	end
	controls.modSelect.tooltipFunc = function(tooltip, mode, index, value)
		tooltip:Clear()
		if mode ~= "OUT" and value then
			for _, line in ipairs(value.mod) do
				tooltip:AddLine(16, "^7"..line)
			end
			self:AddModComparisonTooltip(tooltip, value.mod)
		end
	end
	controls.custom = new("EditControl", {"TOPLEFT",nil,"TOPLEFT"}, {100, 45, 440, 18})
	controls.custom.shown = function()
		return sourceList[controls.source.selIndex].sourceId == "CUSTOM"
	end
	controls.save = new("ButtonControl", nil, {-45, 75, 80, 20}, "Add", function()
		self:SetDisplayItem(addModifier())
		main:ClosePopup()
	end)
	controls.save.tooltipFunc = function(tooltip)
		tooltip:Clear()
		self:AddItemTooltip(tooltip, addModifier())
	end	
	controls.close = new("ButtonControl", nil, {45, 75, 80, 20}, "Cancel", function()
		main:ClosePopup()
	end)
	main:OpenPopup(710, 105, "Add Modifier to Item", controls, "save", sourceList[controls.source.selIndex].sourceId == "CUSTOM" and "custom")	
end

function ItemsTabClass:AddItemSetTooltip(tooltip, itemSet)
	for _, slot in ipairs(self.orderedSlots) do
		if not slot.nodeId then
			local item = self.items[itemSet[slot.slotName].selItemId]
			if item then
				tooltip:AddLine(16, s_format("^7%s: %s%s", slot.slotName, colorCodes[item.rarity], item.name))
			end
		end
	end
end

function ItemsTabClass:SetTooltipHeaderInfluence(tooltip, item)
	tooltip.influenceHeader1 = nil
	tooltip.influenceHeader2 = nil
	-- Fractured items don't have the icon now, they did on trade before 0.3. Maybe they will return.
	--if item.fractured then
	--	tooltip.influenceHeader1 = "Fractured"
	--end
	if item.desecrated then
		if not tooltip.influenceHeader1 then
			tooltip.influenceHeader1 = "Desecrated"
		else
			tooltip.influenceHeader2 = "Desecrated"
		end
	end

	-- If only one influence, we copy to second header. Preparing for dual influence mods like in first game.
	if tooltip.influenceHeader1 and not tooltip.influenceHeader2 then
		tooltip.influenceHeader2 = tooltip.influenceHeader1
	end
end

function ItemsTabClass:FormatItemSource(text)
	return text:gsub("unique{([^}]+)}",colorCodes.UNIQUE.."%1"..colorCodes.SOURCE)
			   :gsub("normal{([^}]+)}",colorCodes.NORMAL.."%1"..colorCodes.SOURCE)
			   :gsub("currency{([^}]+)}",colorCodes.CURRENCY.."%1"..colorCodes.SOURCE)
			   :gsub("prophecy{([^}]+)}",colorCodes.PROPHECY.."%1"..colorCodes.SOURCE)
end

function ItemsTabClass:AddItemTooltip(tooltip, item, slot, dbMode)
	-- Item name
	local rarityCode = colorCodes[item.rarity]
	tooltip.maxWidth = 600 -- Should instead get the longest mod and set the width to that. Some flavour text is way too long so we need a cap of sorts.
	tooltip.tooltipHeader = item.rarity
	tooltip.center = true
	tooltip.color = rarityCode
	self:SetTooltipHeaderInfluence(tooltip, item)
	if item.title then
		tooltip:AddLine(20, rarityCode..item.title)
		tooltip:AddLine(20, rarityCode..item.baseName:gsub(" %(.+%)",""))
	else
		tooltip:AddLine(20, rarityCode..item.namePrefix..item.baseName:gsub(" %(.+%)","")..item.nameSuffix)
	end

	tooltip:AddSeparator(10)

	-- Special fields for database items
	if dbMode then
		if item.variantList then
			if #item.variantList == 1 then
				tooltip:AddLine(16, "^xFFFF30Variant: "..item.variantList[1])
			else
				tooltip:AddLine(16, "^xFFFF30Variant: "..item.variantList[item.variant].." ("..#item.variantList.." variants)")
			end
		end
		if item.league then
			tooltip:AddLine(16, "^xFF5555Exclusive to: "..item.league)
		end
		if item.unreleased then
			tooltip:AddLine(16, colorCodes.NEGATIVE.."Not yet available")
		end
		if item.source then
			tooltip:AddLine(16, colorCodes.SOURCE.."Source: "..self:FormatItemSource(item.source))
		end
		if item.upgradePaths then
			for _, path in ipairs(item.upgradePaths) do
				tooltip:AddLine(16, colorCodes.SOURCE..self:FormatItemSource(path))
			end
		end
		tooltip:AddSeparator(10)
	end

	local base = item.base
	local slotNum = slot and slot.slotNum or (IsKeyDown("SHIFT") and 2 or 1)
	local modList = item.modList or item.slotModList[slotNum]

	tooltip:AddLine(16, s_format("^x7F7F7F%s", base.weapon and self.build.data.weaponTypeInfo[base.type].label or base.type))
	if item.quality and item.quality > 0 then
		tooltip:AddLine(16, s_format("^x7F7F7FQuality: "..colorCodes.MAGIC.."+%d%%", item.quality))
	end

	if item.charmLimit then
		tooltip:AddLine(16, s_format("^x7F7F7FCharm Slots: "..main:StatColor(item.charmLimit, base.charmLimit).."%d", item.charmLimit))
	end
	if item.spiritValue then
		tooltip:AddLine(16, s_format("^x7F7F7FSpirit: "..main:StatColor(item.spiritValue, base.spirit).."%d", item.spiritValue))
	end

	if base.weapon then
		-- Weapon-specific info
		local weaponData = item.weaponData[slotNum]
		local totalDamageTypes = 0
		if weaponData.PhysicalDPS then
			tooltip:AddLine(16, s_format("^x7F7F7FPhysical Damage: "..colorCodes.MAGIC.."%d-%d (%.1f DPS)", weaponData.PhysicalMin, weaponData.PhysicalMax, weaponData.PhysicalDPS))
			totalDamageTypes = totalDamageTypes + 1
		end
		if weaponData.ElementalDPS then
			local elemLine
			for _, var in ipairs({"Fire","Cold","Lightning"}) do
				if weaponData[var.."DPS"] then
					elemLine = elemLine and elemLine.."^x7F7F7F, " or "^x7F7F7FElemental Damage: "
					elemLine = elemLine..s_format("%s%d-%d", colorCodes[var:upper()], weaponData[var.."Min"], weaponData[var.."Max"])
				end
			end
			tooltip:AddLine(16, elemLine)
			tooltip:AddLine(16, s_format("^x7F7F7FElemental DPS: "..colorCodes.MAGIC.."%.1f", weaponData.ElementalDPS))
			totalDamageTypes = totalDamageTypes + 1	
		end
		if weaponData.ChaosDPS then
			tooltip:AddLine(16, s_format("^x7F7F7FChaos Damage: "..colorCodes.CHAOS.."%d-%d "..colorCodes.MAGIC.."(%.1f DPS)", weaponData.ChaosMin, weaponData.ChaosMax, weaponData.ChaosDPS))
			totalDamageTypes = totalDamageTypes + 1
		end
		if totalDamageTypes > 1 then
			tooltip:AddLine(16, s_format("^x7F7F7FTotal DPS: "..colorCodes.MAGIC.."%.1f", weaponData.TotalDPS))
		end
		tooltip:AddLine(16, s_format("^x7F7F7FCritical Hit Chance: %s%.2f%%", main:StatColor(weaponData.CritChance, base.weapon.CritChanceBase), weaponData.CritChance))
		tooltip:AddLine(16, s_format("^x7F7F7FAttacks per Second: %s%.2f", main:StatColor(weaponData.AttackRate, base.weapon.AttackRateBase), weaponData.AttackRate))
		if weaponData.ReloadTime then
			tooltip:AddLine(16, s_format("^x7F7F7FReload Time: %s%.2f", main:StatColor(weaponData.ReloadTime, base.weapon.ReloadTimeBase), weaponData.ReloadTime))
		end
		if weaponData.range < 120 then
			tooltip:AddLine(16, s_format("^x7F7F7FWeapon Range: %s%.1f ^x7F7F7Fmetres", main:StatColor(weaponData.range, base.weapon.Range), weaponData.range / 10))
		end
	elseif base.armour then
		-- Armour-specific info
		local armourData = item.armourData
		if base.armour.BlockChance and armourData.BlockChance > 0 then
			tooltip:AddLine(16, s_format("^x7F7F7FChance to Block: %s%d%%", main:StatColor(armourData.BlockChance, base.armour.BlockChance), armourData.BlockChance))
		end
		if armourData.Armour > 0 then
			tooltip:AddLine(16, s_format("^x7F7F7FArmour: %s%d", main:StatColor(armourData.Armour, base.armour.ArmourBase), armourData.Armour))
		end
		if armourData.Evasion > 0 then
			tooltip:AddLine(16, s_format("^x7F7F7FEvasion Rating: %s%d", main:StatColor(armourData.Evasion, base.armour.EvasionBase), armourData.Evasion))
		end
		if armourData.EnergyShield > 0 then
			tooltip:AddLine(16, s_format("^x7F7F7FEnergy Shield: %s%d", main:StatColor(armourData.EnergyShield, base.armour.EnergyShieldBase), armourData.EnergyShield))
		end
		if armourData.Ward > 0 then
			tooltip:AddLine(16, s_format("^x7F7F7FWard: %s%d", main:StatColor(armourData.Ward, base.armour.WardBase), armourData.Ward))
		end
	elseif base.flask then
		-- Flask-specific info
		local flaskData = item.flaskData
		if flaskData.lifeTotal then
			if flaskData.lifeGradual ~= 0 then
				tooltip:AddLine(16, s_format("^x7F7F7FRecovers %s%d ^x7F7F7FLife over %s%.1f0 ^x7F7F7FSeconds",
					main:StatColor(flaskData.lifeTotal, base.flask.life), flaskData.lifeGradual,
					main:StatColor(flaskData.duration, base.flask.duration), flaskData.duration
					))
			end
			if flaskData.lifeInstant ~= 0 then
				tooltip:AddLine(16, s_format("^x7F7F7FRecovers %s%d ^x7F7F7FLife instantly", main:StatColor(flaskData.lifeTotal, base.flask.life), flaskData.lifeInstant))
			end
		end
		if flaskData.manaTotal then
			if flaskData.manaGradual ~= 0 then
				tooltip:AddLine(16, s_format("^x7F7F7FRecovers %s%d ^x7F7F7FMana over %s%.1f0 ^x7F7F7FSeconds",
					main:StatColor(flaskData.manaTotal, base.flask.mana), flaskData.manaGradual,
					main:StatColor(flaskData.duration, base.flask.duration), flaskData.duration
					))
			end
			if flaskData.manaInstant ~= 0 then
				tooltip:AddLine(16, s_format("^x7F7F7FRecovers %s%d ^x7F7F7FMana instantly", main:StatColor(flaskData.manaTotal, base.flask.mana), flaskData.manaInstant))
			end
		end
		tooltip:AddLine(16, s_format("^x7F7F7FConsumes %s%d ^x7F7F7Fof %s%d ^x7F7F7FCharges on use",
			main:StatColor(flaskData.chargesUsed, base.flask.chargesUsed), flaskData.chargesUsed,
			main:StatColor(flaskData.chargesMax, base.flask.chargesMax), flaskData.chargesMax
		))
		for _, modLine in pairs(item.buffModLines) do
			if modLine.extra then
				local line = colorCodes.UNSUPPORTED..modLine.line
				line = main.notSupportedModTooltips and (line .. main.notSupportedTooltipText) or line
				tooltip:AddLine(16, line)
			else
				tooltip:AddLine(16, colorCodes.MAGIC..modLine.line)
			end
		end
	elseif base.charm then
		-- Charm-specific info
		local charmData = item.charmData
		
		tooltip:AddLine(16, s_format("^x7F7F7FLasts %s%.2f ^x7F7F7FSeconds", main:StatColor(charmData.duration, base.charm.duration), charmData.duration))
		tooltip:AddLine(16, s_format("^x7F7F7FConsumes %s%d ^x7F7F7Fof %s%d ^x7F7F7FCharges on use",
			main:StatColor(charmData.chargesUsed, base.charm.chargesUsed), charmData.chargesUsed,
			main:StatColor(charmData.chargesMax, base.charm.chargesMax), charmData.chargesMax
		))
		for _, modLine in pairs(item.buffModLines) do
			if modLine.extra then
				local line = colorCodes.UNSUPPORTED..modLine.line
				line = main.notSupportedModTooltips and (line .. main.notSupportedTooltipText) or line
				tooltip:AddLine(16, line)
			else
				tooltip:AddLine(16, colorCodes.MAGIC..modLine.line)
			end
		end
	elseif item.type == "Jewel" then
		-- Jewel-specific info
		if item.limit then
			tooltip:AddLine(16, "^x7F7F7FLimited to: ^7"..item.limit)
		end
		if item.classRestriction then
			tooltip:AddLine(16, "^x7F7F7FRequires Class "..(self.build.spec.curClassName == item.classRestriction and colorCodes.POSITIVE or colorCodes.NEGATIVE)..item.classRestriction)
		end
		if item.jewelRadiusLabel then
			tooltip:AddLine(16, "^x7F7F7FRadius: ^7"..item.jewelRadiusLabel)
		end
		if item.jewelRadiusData and slot and item.jewelRadiusData[slot.nodeId] then
			local radiusData = item.jewelRadiusData[slot.nodeId]
			local line
			local codes = { colorCodes.STRENGTH, colorCodes.DEXTERITY, colorCodes.INTELLIGENCE }
			for i, stat in ipairs({"Str","Dex","Int"}) do
				if radiusData[stat] and radiusData[stat] ~= 0 then
					line = (line and line .. ", " or "") .. s_format("%s%d %s^7", codes[i], radiusData[stat], stat)
				end
			end
			if line then
				tooltip:AddLine(16, "^x7F7F7FAttributes in Radius: "..line)
			end
		end
	end
	
	if item.catalyst and item.catalyst > 0 and item.catalyst <= #catalystQualityFormat and item.catalystQuality and item.catalystQuality > 0 then
		tooltip:AddLine(16, s_format(catalystQualityFormat[item.catalyst], item.catalystQuality))
		tooltip:AddSeparator(10)
	end

	if item.itemSocketCount > 0 then
		local socketString = ""
		for _ = 1, item.itemSocketCount do
			socketString = socketString .. "S "
		end
		socketString = socketString:gsub(" $", "")
		tooltip:AddLine(16, "^x7F7F7FSockets: " .. socketString)
	end
	tooltip:AddSeparator(10)

	if item.talismanTier then
		tooltip:AddLine(16, "^x7F7F7FTalisman Tier ^xFFFFFF"..item.talismanTier)
		tooltip:AddSeparator(10)
	end

	-- Requirements
	self.build:AddRequirementsToTooltip(tooltip, item.requirements.level, 
		item.requirements.strMod, item.requirements.dexMod, item.requirements.intMod, 
		item.requirements.str or 0, item.requirements.dex or 0, item.requirements.int or 0)

	-- Modifiers
	-- Support for Lich Socket Jewel only for tooltip display
	-- the real calculation is done in the CalcSetup
	local scale = 1
	local extraTooltip = ""
	if slot and slot.nodeId then
		local node = self.build.spec.nodes[slot.nodeId]
		if node and node.containJewelSocket then
			local jewelEffect = node.modList:Sum("INC", nil, "SocketedJewelEffect")
			extraTooltip = "^x7F7F7FSocketed Jewel Effect: "			
			if jewelEffect > 0 then
				extraTooltip = extraTooltip .. s_format(colorCodes.MAGIC.."+%d%%", jewelEffect)
				tooltip:AddSeparator(10)
				tooltip:AddLine(16, extraTooltip)
				tooltip:AddSeparator(10)
			end
			
			scale = scale + (jewelEffect / 100)
		end
	end

	for _, modList in ipairs{item.enchantModLines, item.runeModLines, item.implicitModLines, item.explicitModLines} do
		if modList[1] then
			for _, modLine in ipairs(modList) do
				if item:CheckModLineVariant(modLine) then
					if scale ~= 1 then
						local copyModLine = copyTable(modLine)
						local modsList = copyTable(modLine.modList)
						local scaledList = new("ModList")
						scaledList:ScaleAddList(modsList, scale)
						for j, mod in ipairs(scaledList) do
							local newValue
							if type(mod.value) == "number" then
								newValue = mod.value
							elseif type(mod.value) == "table" then
								if mod.value.mod then
									newValue = mod.value.mod.value
								else
									newValue = mod.value.value
								end
							end
							if type(newValue) == "number" then
								copyModLine.line = copyModLine.line:gsub("%d*%.?%d+", math.abs(newValue), 1) -- Only scale first number in line
							end
						end
						tooltip:AddLine(16, itemLib.formatModLine(copyModLine, dbMode))
					else
						tooltip:AddLine(16, itemLib.formatModLine(modLine, dbMode))
					end

					-- Show mods from granted Notables
					if modLine.modList[1] and modLine.modList[1].name == "GrantedPassive" then
						local node = self.build.spec.tree.notableMap[modLine.modList[1].value]
						if node then
							for _, stat in ipairs(node.sd) do
								tooltip:AddLine(16, "^x7F7F7F"..stat)
							end
						end
						-- Add separator only for anoints
						if item.implicitModLines then
							tooltip:AddSeparator(10)
						end
					end
				end
			end
			tooltip:AddSeparator(10)
		end
	end

	-- Cluster jewel notables/keystone
	if item.clusterJewel then
		tooltip:AddSeparator(10)
		if #item.jewelData.clusterJewelNotables > 0 then
			for _, name in ipairs(item.jewelData.clusterJewelNotables) do
				local node = self.build.spec.tree.clusterNodeMap[name]
				if node then
					tooltip:AddLine(16, colorCodes.MAGIC .. node.dn)
					for _, stat in ipairs(node.sd) do
						tooltip:AddLine(16, "^x7F7F7F"..stat)
					end
				end
			end
		elseif item.jewelData.clusterJewelKeystone then
			local node = self.build.spec.tree.clusterNodeMap[item.jewelData.clusterJewelKeystone]
			if node then
				tooltip:AddLine(16, colorCodes.MAGIC .. node.dn)
				for _, stat in ipairs(node.sd) do
					tooltip:AddLine(16, "^x7F7F7F"..stat)
				end
			end
		end
		tooltip:AddSeparator(10)
	end

	-- Corrupted item label
	if item.corrupted or item.mirrored then
		if #item.explicitModLines == 0 then
			tooltip:AddSeparator(10)
		end
		if item.mirrored then
			tooltip:AddLine(16, colorCodes.NEGATIVE.."Mirrored")
		end
		if item.corrupted then
			tooltip:AddLine(16, colorCodes.NEGATIVE.."Corrupted")
		end
		tooltip:AddSeparator(10)
	end

	-- Show flavour text:
	if item.rarity == "UNIQUE" and main.showFlavourText == true then
		local flavourTable = flavourLookup[item.title]
		if flavourTable then
			local flavour = nil

			if item.title == "Sekhema's Resolve" then
				local selectedFlavourId = nil
				for _, lineEntry in ipairs(tooltip.lines or {}) do
					local lineText = lineEntry.text or ""
					if lineText:find("Emerald") then
						selectedFlavourId = "FourUniqueSanctum4a"
						break
					elseif lineText:find("Sapphire") then
						selectedFlavourId = "FourUniqueSanctum4b"
						break
					elseif lineText:find("Ruby") then
						selectedFlavourId = "FourUniqueSanctum4c"
						break
					end
				end
				if selectedFlavourId then
					flavour = flavourTable[selectedFlavourId]
				end

			elseif item.title == "Grand Spectrum" then
				local selectedFlavourId = nil
				local baseName = item.baseName
				if baseName == "Ruby" then
					selectedFlavourId = "FourUniqueJewel1"
				elseif baseName == "Emerald" then
					selectedFlavourId = "FourUniqueJewel2"
				elseif baseName == "Sapphire" then
					selectedFlavourId = "FourUniqueJewel3"
				end
				if selectedFlavourId then
					flavour = flavourTable[selectedFlavourId]
				end

			else
				for _, text in pairs(flavourTable) do
					flavour = text
					break
				end
			end

			if flavour then
				for _, line in ipairs(flavour) do
					tooltip:AddLine(16, colorCodes.UNIQUE .. line)
				end
				tooltip:AddSeparator(14)
			end
		end
	end

	-- Stat differences
	if not self.showStatDifferences then
		tooltip:AddSeparator(14)
		tooltip:AddLine(14, colorCodes.TIP.."Tip: Press Ctrl+D to enable the display of stat differences.")
		return
	end
	local calcFunc, calcBase = self.build.calcsTab:GetMiscCalculator()
	if base.flask then
		-- Special handling for flasks
		local stats = { }
		local flaskData = item.flaskData
		local modDB = self.build.calcsTab.mainEnv.modDB
		local output = self.build.calcsTab.mainOutput
		local durInc = modDB:Sum("INC", nil, "FlaskDuration")
		local effectInc = modDB:Sum("INC", { actor = "player" }, "FlaskEffect")
		local lifeDur = 0
		local manaDur = 0

		if item.base.flask.life or item.base.flask.mana then
			local rateInc = modDB:Sum("INC", nil, "FlaskRecoveryRate")
			if item.base.flask.life then
				local lifeInc = modDB:Sum("INC", nil, "FlaskLifeRecovery")
				local lifeMore = modDB:More(nil, "FlaskLifeRecovery")
				local lifeRateInc = modDB:Sum("INC", nil, "FlaskLifeRecoveryRate")
				local instantPerc = flaskData.instantPerc + modDB:Sum("BASE", nil, "LifeFlaskInstantRecovery")

				-- More life recovery while on low life is not affected by flask effect (verified ingame).
				-- Since this will be multiplied by the flask effect value below we have to counteract this by removing the flask effect from the value beforehand.
				-- This is also the reason why this value needs a separate multiplier and cannot just be calculated into FlaskLifeRecovery.
				local lifeMoreOnLowLife = modDB:More(nil, "FlaskLifeRecoveryLowLife")
				local lowLifeMulti = (lifeMoreOnLowLife > 1 and ((lifeMoreOnLowLife - 1) / (1 + effectInc / 100)) + 1 or 1)

				local inst = flaskData.lifeBase * instantPerc / 100 * (1 + lifeInc / 100) * lifeMore * (1 + effectInc / 100) * lowLifeMulti
				local base = flaskData.lifeBase * (1 - instantPerc / 100) * (1 + lifeInc / 100) * lifeMore * (1 + effectInc / 100) * (1 + durInc / 100) * lowLifeMulti
				local grad = base * output.LifeRecoveryRateMod
				local esGrad = base * output.EnergyShieldRecoveryRateMod
				lifeDur = flaskData.duration * (1 + durInc / 100) / (1 + rateInc / 100) / (1 + lifeRateInc / 100)

				if not modDB:Flag(nil, "LifeFlaskDoesNotApply") then
					-- LocalLifeFlaskAdditionalLifeRecovery flask mods
					if flaskData.lifeAdditional > 0 and not self.build.configTab.input.conditionFullLife then
						local totalAdditionalAmount = (flaskData.lifeAdditional/100) * flaskData.lifeTotal * output.LifeRecoveryRateMod
						local additionalGrad = (lifeDur/10) * totalAdditionalAmount
						local leftoverDur = 10 - lifeDur
						local leftoverAmount = totalAdditionalAmount - additionalGrad

						if inst > 0 then
							if grad > 0 then
								t_insert(stats, s_format("^8Life recovered: ^7%d ^8(^7%d^8 instantly, plus ^7%d ^8over^7 %.2fs^8, and an additional ^7%d ^8over subsequent ^7%.2fs^8)",
										inst + grad + totalAdditionalAmount, inst, grad + additionalGrad, lifeDur, leftoverAmount, leftoverDur))
							else
								lifeDur = 0
								t_insert(stats, s_format("^8Life recovered: ^7%d ^8(^7%d^8 instantly, and an additional ^7%d ^8over ^7%.2fs^8)",
										inst + totalAdditionalAmount, inst, totalAdditionalAmount, 10))
							end
						else
							t_insert(stats, s_format("^8Life recovered: ^7%d ^8(^7%d ^8over ^7%.2fs^8, and an additional ^7%d ^8over subsequent ^7%.2fs^8)",
							grad + totalAdditionalAmount, grad + additionalGrad, lifeDur, leftoverAmount, leftoverDur))
						end
					else
						if inst > 0 and grad > 0 then
							t_insert(stats, s_format("^8Life recovered: ^7%d ^8(^7%d^8 instantly, plus ^7%d ^8over^7 %.2fs^8)", inst + grad, inst, grad, lifeDur))
						-- modifiers to recovery amount or duration
						elseif inst + grad ~= flaskData.lifeTotal or (inst == 0 and lifeDur ~= flaskData.duration) then
							if inst > 0 then
								lifeDur = 0
								t_insert(stats, s_format("^8Life recovered: ^7%d ^8instantly", inst))
							elseif grad > 0 then
								t_insert(stats, s_format("^8Life recovered: ^7%d ^8over ^7%.2fs", grad, lifeDur))
							end
						end
					end
				end
				if modDB:Flag(nil, "LifeFlaskAppliesToEnergyShield") then
					if inst > 0 and esGrad > 0 then
						t_insert(stats, s_format("^8Energy Shield recovered: ^7%d ^8(^7%d^8 instantly, plus ^7%d ^8over^7 %.2fs^8)", inst + esGrad, inst, esGrad, lifeDur))
					elseif inst > 0 and esGrad == 0 then
						t_insert(stats, s_format("^8Energy Shield recovered: ^7%d ^8instantly", inst))
					elseif inst == 0 and esGrad > 0 then
						t_insert(stats, s_format("^8Energy Shield recovered: ^7%d ^8over ^7%.2fs", esGrad, lifeDur))
					end
				end
			end
			if item.base.flask.mana then
				local manaInc = modDB:Sum("INC", nil, "FlaskManaRecovery")
				local manaMore = modDB:More(nil, "FlaskManaRecovery")
				local manaRateInc = modDB:Sum("INC", nil, "FlaskManaRecoveryRate")
				local instantPerc = flaskData.instantPerc + modDB:Sum("BASE", nil, "ManaFlaskInstantRecovery")
				local inst = flaskData.manaBase * instantPerc / 100 * (1 + manaInc / 100) * manaMore * (1 + effectInc / 100)
				local base = flaskData.manaBase * (1 - instantPerc / 100) * (1 + manaInc / 100) * manaMore * (1 + effectInc / 100) * (1 + durInc / 100)
				local grad = base * output.ManaRecoveryRateMod
				local lifeGrad = base * output.LifeRecoveryRateMod
				manaDur = flaskData.duration * (1 + durInc / 100) / (1 + rateInc / 100) / (1 + manaRateInc / 100)

				if inst > 0 and grad > 0 then
					t_insert(stats, s_format("^8Mana recovered: ^7%d ^8(^7%d^8 instantly, plus ^7%d ^8over^7 %.2fs^8)", inst + grad, inst, grad, manaDur))
				elseif inst + grad ~= flaskData.manaTotal or (inst == 0 and manaDur ~= flaskData.duration) then
					if inst > 0 then
						manaDur = 0
						t_insert(stats, s_format("^8Mana recovered: ^7%d ^8instantly", inst))
					elseif grad > 0 then
						t_insert(stats, s_format("^8Mana recovered: ^7%d ^8over ^7%.2fs", grad, manaDur))
					end
				end
				if modDB:Flag(nil, "ManaFlaskAppliesToLife") then
					if lifeGrad > 0 then
						t_insert(stats, s_format("^8Life recovered: ^7%d ^8over ^7%.2fs", lifeGrad, manaDur))
					end
				end
			end
		end
		local effectMod = 1 + (flaskData.effectInc + effectInc) / 100
		if effectMod ~= 1 then
			t_insert(stats, s_format("^8Flask effect modifier: ^7%+d%%", effectMod * 100 - 100))
		end
		local usedInc = modDB:Sum("INC", nil, "FlaskChargesUsed")
		if item.base.flask.life then
			usedInc = usedInc + modDB:Sum("INC", nil, "LifeFlaskChargesUsed")
		end
		if item.base.flask.mana then
			usedInc = usedInc + modDB:Sum("INC", nil, "ManaFlaskChargesUsed")
		end
		if usedInc ~= 0 then
			local used = m_floor(flaskData.chargesUsed * (1 + usedInc / 100))
			t_insert(stats, s_format("^8Charges used: ^7%d ^8of ^7%d ^8(^7%d ^8uses)", used, flaskData.chargesMax, m_floor(flaskData.chargesMax / used)))
		end
		local gainInc = flaskData.gainInc + modDB:Sum("INC", nil, "FlaskChargesGained")
		if item.base.flask.life then
			gainInc = gainInc + modDB:Sum("INC", nil, "LifeFlaskChargesGained")
		end
		if item.base.flask.mana then
			gainInc = gainInc + modDB:Sum("INC", nil, "ManaFlaskChargesGained")
		end
		local gainMod = flaskData.gainMod * (1 + gainInc / 100)
		if gainMod ~= 1 then
			t_insert(stats, s_format("^8Charge gain modifier: ^7%+d%%", gainMod * 100 - 100))
		end

		-- charge generation
		local chargesGenerated = flaskData.gainBase + modDB:Sum("BASE", nil, "FlaskChargesGenerated")
		if item.base.flask.life then
			chargesGenerated = chargesGenerated + modDB:Sum("BASE", nil, "LifeFlaskChargesGenerated")
		end
		if item.base.flask.mana then
			chargesGenerated = chargesGenerated + modDB:Sum("BASE", nil, "ManaFlaskChargesGenerated")
		end

		local totalChargesGenerated = chargesGenerated * gainMod
		if totalChargesGenerated > 0 then
			t_insert(stats, s_format("^8Charges generated: ^7%.2f^8 per second", totalChargesGenerated))
		end

		local chanceToNotConsumeCharges = m_min(modDB:Sum("BASE", nil, "FlaskChanceNotConsumeCharges"), 100)
		if chanceToNotConsumeCharges ~= 0 then
			t_insert(stats, s_format("^8Chance to not consume charges: ^7%d%%", chanceToNotConsumeCharges))
		end

		-- flask uptime
		local hasUptime = not item.base.flask.life and not item.base.flask.mana
		local flaskDuration = flaskData.duration * (1 + durInc / 100)

		if item.base.flask.life and (flaskData.lifeEffectNotRemoved or modDB:Flag(nil, "LifeFlaskEffectNotRemoved")) then
			hasUptime = true
			flaskDuration = lifeDur
		elseif item.base.flask.mana and (flaskData.manaEffectNotRemoved or modDB:Flag(nil, "ManaFlaskEffectNotRemoved")) then
			hasUptime = true
			flaskDuration = manaDur
		end

		if hasUptime then
			local flaskChargesUsed = flaskData.chargesUsed * (1 + usedInc / 100)
			if flaskChargesUsed > 0 and flaskDuration > 0 then
				local averageChargesGenerated = totalChargesGenerated * flaskDuration
				local percentageMin = m_min(averageChargesGenerated / flaskChargesUsed * 100, 100)
				if percentageMin < 100 and chanceToNotConsumeCharges < 100 then
					local averageChargesUsed = flaskChargesUsed * (100 - chanceToNotConsumeCharges) / 100
					local percentageAvg = m_min(averageChargesGenerated / averageChargesUsed * 100, 100)
					t_insert(stats, s_format("^8Flask uptime: ^7%d%%^8 average, ^7%d%%^8 minimum", percentageAvg, percentageMin))
				else
					t_insert(stats, s_format("^8Flask uptime: ^7100%%^8"))
				end
			end
		end

		if stats[1] then
			tooltip:AddLine(14, "^7Effective flask stats:")
			for _, stat in ipairs(stats) do
				tooltip:AddLine(14, stat)
			end
		end
		local output = calcFunc({ toggleFlask = item })
		local header
		if self.build.calcsTab.mainEnv.flasks[item] then
			header = "^7Deactivating this flask will give you:"
		else
			header = "^7Activating this flask will give you:"
		end
		self.build:AddStatComparesToTooltip(tooltip, calcBase, output, header)
	elseif base.charm then
		-- Special handling for charms
		local stats = { }
		local charmData = item.charmData
		local modDB = self.build.calcsTab.mainEnv.modDB
		local output = self.build.calcsTab.mainOutput
		local durInc = modDB:Sum("INC", nil, "CharmDuration")
		local effectInc = modDB:Sum("INC", { actor = "player" }, "CharmEffect")

		if item.rarity == "MAGIC" then
			effectInc = effectInc + modDB:Sum("INC", { actor = "player" }, "MagicCharmEffect")
		end
		local effectMod = (1 + (charmData.effectInc + effectInc) / 100) * (1 + (item.quality or 0) / 100)
		if effectMod ~= 1 then
			t_insert(stats, s_format("^8Charm effect modifier: ^7%+d%%", effectMod * 100 - 100))
		end

		if durInc ~= 0 then
			t_insert(stats, s_format("^8Charm effect duration: ^7%.1f0s", charmData.duration * (1 + durInc / 100)))
		end

		if stats[1] then
			tooltip:AddLine(14, "^7Effective charm stats:")
			for _, stat in ipairs(stats) do
				tooltip:AddLine(14, stat)
			end
		end
		local output = calcFunc({ toggleCharm = item })
		local header
		if self.build.calcsTab.mainEnv.charms[item] then
			header = "^7Deactivating this charm will give you:"
		else
			header = "^7Activating this charm will give you:"
		end
		self.build:AddStatComparesToTooltip(tooltip, calcBase, output, header)
	else
		self:UpdateSockets()
		-- Build sorted list of slots to compare with
		local compareSlots = { }
		for slotName, slot in pairs(self.slots) do
			if self:IsItemValidForSlot(item, slotName) and not slot.inactive and (not slot.weaponSet or slot.weaponSet == (self.activeItemSet.useSecondWeaponSet and 2 or 1)) and slot.shown() then
				t_insert(compareSlots, slot)
			end
		end
		table.sort(compareSlots, function(a, b)
			if a ~= b then
				if slot == a then
					return true
				end
				if slot == b then
					return false
				end
			end
			if a.selItemId ~= b.selItemId then
				if item == self.items[a.selItemId] then
					return true
				end
				if item == self.items[b.selItemId] then
					return false
				end
			end
			local aNum = tonumber(a.slotName:match("%d+"))
			local bNum = tonumber(b.slotName:match("%d+"))
			if aNum and bNum then
				return aNum < bNum
			else
				return a.slotName < b.slotName
			end
		end)

		-- Add comparisons for each slot
		for _, compareSlot in pairs(compareSlots) do
			if not main.slotOnlyTooltips or (slot and (slot.nodeId == compareSlot.nodeId or slot.slotName == compareSlot.slotName)) or not slot or slot == compareSlot then
				local selItem = self.items[compareSlot.selItemId]
				local output = calcFunc({ repSlotName = compareSlot.slotName, repItem = item ~= selItem and item or nil})
				local header
				if item == selItem then
					header = "^7Removing this item from "..compareSlot.label.." will give you:"
				else
					header = string.format("^7Equipping this item in %s will give you:%s", compareSlot.label, selItem and "\n(replacing "..colorCodes[selItem.rarity]..selItem.name.."^7)" or "")
				end
				self.build:AddStatComparesToTooltip(tooltip, calcBase, output, header)
			end
		end
	end
	tooltip:AddLine(14, colorCodes.TIP.."Tip: Press Ctrl+D to disable the display of stat differences.")

	if launch.devModeAlt then
		-- Modifier debugging info
		tooltip:AddSeparator(10)
		for _, mod in ipairs(modList) do
			tooltip:AddLine(14, "^7"..modLib.formatMod(mod))
		end
	end
end

function ItemsTabClass:CreateUndoState()
	local state = { }
	state.activeItemSetId = self.activeItemSetId
	state.items = { }
	for k, v in pairs(self.items) do
		state.items[k] = copyTableSafe(self.items[k], true, true)
	end
	state.itemOrderList = copyTable(self.itemOrderList)
	state.slotSelItemId = { }
	for slotName, slot in pairs(self.slots) do
		state.slotSelItemId[slotName] = slot.selItemId
	end
	state.itemSets = copyTableSafe(self.itemSets)
	state.itemSetOrderList = copyTable(self.itemSetOrderList)
	return state
end

function ItemsTabClass:RestoreUndoState(state)
	self.items = state.items
	wipeTable(self.itemOrderList)
	for k, v in pairs(state.itemOrderList) do
		self.itemOrderList[k] = v
	end
	for slotName, selItemId in pairs(state.slotSelItemId) do
		self.slots[slotName]:SetSelItemId(selItemId)
	end
	self.itemSets = state.itemSets
	wipeTable(self.itemSetOrderList)
	for k, v in pairs(state.itemSetOrderList) do
		self.itemSetOrderList[k] = v
	end
	self.activeItemSetId = state.activeItemSetId
	self.activeItemSet = self.itemSets[self.activeItemSetId]
	self:PopulateSlots()
end
