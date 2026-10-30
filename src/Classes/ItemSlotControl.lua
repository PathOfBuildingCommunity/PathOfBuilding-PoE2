-- Path of Building
--
-- Class: Item Slot
-- Item Slot control, extends the basic dropdown control.
--
local pairs = pairs
local t_insert = table.insert
local m_min = math.min

local itemSlotHelper = LoadModule("Modules/ItemSlotHelper")
local BuildExportPoE2 = LoadModule("Modules/BuildExportPoE2")

-- 下拉列表分别保存显示标签和检索词，中文名称仍可按英文原名搜索。
local function itemEntry(item)
	local label = colorCodes[item.rarity] .. localisation:ItemName(item)
	return { label = label, searchFilter = StripEscapes(label) .. '\n' .. item.name }
end
---@class ItemSlotControl: DropDownControl
local ItemSlotClass = newClass("ItemSlotControl", "DropDownControl")

---@param anchor Anchor?
---@param x Prop<number>
---@param y Prop<number>
---@param itemsTab ItemsTab
---@param slotName string
---@param slotLabel? string
---@param nodeId integer?
function ItemSlotClass:ItemSlotControl(anchor, x, y, itemsTab, slotName, slotLabel, nodeId)
	self:DropDownControl(anchor, {x, y, 310, 20}, { }, function(index, value)
		if self.items[index] ~= self.selItemId then
			self:SetSelItemId(self.items[index])
			itemsTab:PopulateSlots()
			itemsTab:AddUndoState()
			itemsTab.build.buildFlag = true
		end
	end)
	self.anchor.collapse = true
	self.enabled = function()
		return #self.items > 1
	end
	self.shown = function()
		return not self.inactive
	end
	self.itemsTab = itemsTab
	self.items = { }
	self.selItemId = 0
	self.slotName = slotName
	self.slotNum = tonumber(slotName:match("%d+$") or slotName:match("%d+"))
	if data.buildFileInventorySlotMap[slotName] then
		self.controls.noteButton = new("ButtonControl"):ButtonControl({"LEFT",self,"RIGHT"}, {2, 0, 20, 20}, "~", function()
			local item = itemsTab.items[self.selItemId]
			main:OpenNoteEditPopup(self.slotName, self.note or "", function(note)
				self.note = note
				itemsTab:PopulateSlots()
				itemsTab:AddUndoState()
				itemsTab.build.buildFlag = true
			end, item and BuildExportPoE2.ItemAdditionalText(item))
		end)
		self.controls.noteButton.tooltipFunc = function(tooltip)
			tooltip:Clear()
			tooltip:AddBuildPlannerNote(14, self.note and self.note ~= "" and self.note or "Add a note for this item slot")
		end
	end
	if slotName:match("Flask") then
		self.controls.activate = new("CheckBoxControl"):CheckBoxControl({ "RIGHT", self, "LEFT" }, { -2, 0, 20 }, nil, function(state)
			self.active = state
			itemsTab.activeItemSet[self.slotName].active = state
			itemsTab:AddUndoState()
			itemsTab.build.buildFlag = true
		end)
		self.controls.activate.enabled = function()
			return self.selItemId ~= 0
		end
		self.controls.activate.tooltipText = localisation:Label("ui.item_slot_control.init.activate_tooltip_text.label_2")
		self.labelOffset = -24
	elseif slotName:match("Charm") then
		self.controls.activate = new("CheckBoxControl"):CheckBoxControl({ "RIGHT", self, "LEFT" }, { -2, 0, 20 }, nil, function(state)
			self.active = state
			itemsTab.activeItemSet[self.slotName].active = state
			itemsTab:AddUndoState()
			itemsTab.build.buildFlag = true
		end)
		self.controls.activate.enabled = function()
			return self.selItemId ~= 0
		end
		self.controls.activate.tooltipText = localisation:Label("ui.item_slot_control.init.activate_tooltip_text.label")
		self.labelOffset = -24
	else
		self.labelOffset = -2
	end
	self.socketList = { }
	self.jewelSocketList = { }
	self.tooltipFunc = function(tooltip, mode, index, itemId)
		local item = itemsTab.items[self.items[index]]
		-- not selControl.ListControl allows hover when All Items or Unique/Rare DB Sections are in focus
		if main.popups[1] or mode == "OUT" or not item
			or self.controls.noteButton and self:GetMouseOverControl() == self.controls.noteButton -- Note button has its own tooltip
			or (not self.dropped and itemsTab.selControl and itemsTab.selControl ~= self.controls.activate and not itemsTab.selControl.ListControl) then
			tooltip:Clear(true)
			elseif tooltip:CheckForUpdate(item, launch.devModeAlt, itemsTab.build.outputRevision, IsKeyDown("SHIFT")) then
			itemsTab:AddItemTooltip(tooltip, item, self)
		end
	end
	self.label = slotLabel or slotName
	local label = self.label
	if label:match('^Jewel #%d+$') then
		self.labelDisplay = localisation:Label('equipment.slot.jewel_index', { index = tonumber(label:match('%d+')) })
	else
		self.labelDisplay = function() return localisation:Term('equipment.slot', label) end
	end
	self.nodeId = nodeId
	return self
end

function ItemSlotClass:SetSelItemId(selItemId)
	if self.nodeId then
		if self.itemsTab.build.spec then
			self.itemsTab.build.spec.jewels[self.nodeId] = selItemId
			if selItemId ~= self.selItemId then
				self.itemsTab.build.spec:BuildClusterJewelGraphs()
			end
		end
	else
		self.itemsTab.activeItemSet[self.slotName].selItemId = selItemId
	end
	self.selItemId = selItemId
end

function ItemSlotClass:Populate()
	self.displayLanguage = localisation.language
	wipeTable(self.items)
	wipeTable(self.list)
	self.items[1] = 0
	self.list[1] = "None"
	localisation:List(self.list, { [1] = 'equipment.slot.empty' })
	self.selIndex = 1
	for _, item in pairs(self.itemsTab.items) do
		if self.itemsTab:IsItemValidForSlot(item, self.slotName) then
			t_insert(self.items, item.id)
			t_insert(self.list, itemEntry(item))
			if item.id == self.selItemId then
				self.selIndex = #self.list
			end
		end
	end
	if not self.selItemId or not self.itemsTab.items[self.selItemId] or not self.itemsTab:IsItemValidForSlot(self.itemsTab.items[self.selItemId], self.slotName) then
		self:SetSelItemId(0)
	end

	-- Update Jewel Sockets
	local jewelSocketCount = 0
	if self.selItemId > 0 then
		local selItem = self.itemsTab.items[self.selItemId]
		jewelSocketCount = selItem.jewelSocketCount or 0
	end
	for i, jewelSocket in ipairs(self.jewelSocketList) do
		jewelSocket.inactive = i > jewelSocketCount
	end
	if not self.nodeId then
		self.itemsTab.activeItemSet[self.slotName].note = self.note
	end
end

function ItemSlotClass:CanReceiveDrag(type, value)
	return type == "Item" and self.itemsTab:IsItemValidForSlot(value, self.slotName)
end

function ItemSlotClass:ReceiveDrag(type, value, source)
	if value.id and self.itemsTab.items[value.id] then
		self:SetSelItemId(value.id)
	else
		local newItem = new("Item"):Item(value.raw)
		newItem:NormaliseQuality()
		self.itemsTab:AddItem(newItem, true)
		self:SetSelItemId(newItem.id)
	end
	self.itemsTab:PopulateSlots()
	self.itemsTab:AddUndoState()
	self.itemsTab.build.buildFlag = true
end

function ItemSlotClass:Draw(viewPort)
	-- 语言切换只刷新显示名称，不重新装备物品或重算插槽。
	if self.displayLanguage ~= localisation.language then
		for index, itemId in ipairs(self.items) do
			local item = self.itemsTab.items[itemId]
			self.list[index] = item and itemEntry(item) or "None"
		end
		self.displayLanguage = localisation.language
		self:UpdateSearch()
	end
	local x, y = self:GetPos()
	local width, height = self:GetSize()
	DrawString(x + self.labelOffset, y + 2, "RIGHT_X", height - 4, "VAR", "^7"..localisation:Field(self, 'label')..":")
	self.DropDownControl:Draw(viewPort)
	self:DrawControls(viewPort)
	if not main.popups[1] and self.nodeId and (self.dropped or (self:IsMouseOver() and (self.otherDragSource or not self.itemsTab.selControl))) then
		local width = 308
		local height = 280
		local viewerY
		if self.DropDownControl.dropUp and self.DropDownControl.dropped then
			viewerY = y + 20
		else
			viewerY = m_min(y - height - 4, viewPort.y + viewPort.height - height)
		end
		itemSlotHelper.DrawViewer(self.itemsTab, self.nodeId, x, viewerY, width, height)
	end
end

function ItemSlotClass:OnKeyDown(key)
	if not self:IsShown() then
		return
	end
	local mOverControl = self:GetMouseOverControl()
	-- Notes don't care if the item slot is enabled or not
	if mOverControl and mOverControl == self.controls.noteButton then
		return mOverControl:OnKeyDown(key)
	end
	if not self:IsEnabled() then
		return
	end
	if mOverControl and mOverControl == self.controls.activate then
		return mOverControl:OnKeyDown(key)
	end
	return self.DropDownControl:OnKeyDown(key)
end

function ItemSlotClass:OnHoverKeyUp(key)
	if itemLib.wiki.matchesKey(key) then
		local index = self.DropDownControl:GetHoverIndex()
		if index then
			local itemIndex = self.items[index]
			local item = self.itemsTab.items[itemIndex]

			if item then
				itemLib.wiki.openItem(item)
			end
		end
	end
end
