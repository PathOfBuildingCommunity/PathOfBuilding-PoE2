-- Path of Building
--
-- Class: Config Set List
-- Config Set list control
--
---@class ConfigSetListControl: ListControl
local ConfigSetListClass = newClass("ConfigSetListControl", "ListControl")

function ConfigSetListClass:ConfigSetListControl(anchor, rect, configTab)
	self:ListControl(anchor, rect, 16, "VERTICAL", true, configTab.configSetOrderList)
	self.configTab = configTab
	self.configSetService = new("ConfigSetService"):ConfigSetService(configTab)
	self.controls.copy = new("ButtonControl"):ButtonControl({ "BOTTOMLEFT", self, "TOP" }, { 2, -4, 60, 18 }, localisation:Label("ui.config_set_list_control.init.copy.label"), function()
		self:CopyConfigSet(self.selValue)
	end)
	self.controls.copy.enabled = function()
		return self.selValue ~= nil
	end
	self.controls.delete = new("ButtonControl"):ButtonControl({ "LEFT", self.controls.copy, "RIGHT" }, { 4, 0, 60, 18 }, localisation:Label("ui.config_set_list_control.init.delete.label"),
		function()
			self:OnSelDelete(self.selIndex, self.selValue)
		end)
	self.controls.delete.enabled = function()
		return self.selValue ~= nil and #self.list > 1
	end
	self.controls.rename = new("ButtonControl"):ButtonControl({ "BOTTOMRIGHT", self, "TOP" }, { -2, -4, 60, 18 }, localisation:Label("ui.config_set_list_control.init.rename.label"), function()
		self:RenameConfigSet(self.selValue)
	end)
	self.controls.rename.enabled = function()
		return self.selValue ~= nil
	end
	self.controls.new = new("ButtonControl"):ButtonControl({ "RIGHT", self.controls.rename, "LEFT" }, { -4, 0, 60, 18 }, localisation:Label("ui.config_set_list_control.init.new.label"),
		function()
			self:CreateConfigSet()
		end)
	return self
end

function ConfigSetListClass:CreateConfigSet()
	local controls = {}
	controls.label = new("LabelControl"):LabelControl(nil, { 0, 20, 0, 16 }, localisation:Label("ui.config_set_list_control.create_config_set.label_2"))
	controls.edit = new("EditControl"):EditControl(nil, { 0, 40, 350, 20 }, "New Config Set", nil, nil, 100, function(buf)
		controls.save.enabled = buf:match("%S")
	end)
	controls.save = new("ButtonControl"):ButtonControl(nil, { -45, 70, 80, 20 }, localisation:Label("ui.config_set_list_control.create_config_set.save.label"), function()
		self.configSetService:NewConfigSet(controls.edit.buf)
		main:ClosePopup()
	end)
	controls.save.enabled = false
	controls.cancel = new("ButtonControl"):ButtonControl(nil, { 45, 70, 80, 20 }, localisation:Label("ui.config_set_list_control.create_config_set.cancel.label"), function()
		main:ClosePopup()
	end)
	main:OpenPopup(370, 100, localisation:Label("ui.config_set_list_control.create_config_set.label"), controls, "save", "edit", "cancel")
end

function ConfigSetListClass:CopyConfigSet(selValue)
	local configSet = self.configTab.configSets[selValue]
	local controls = {}
	controls.label = new("LabelControl"):LabelControl(nil, { 0, 20, 0, 16 }, localisation:Label("ui.config_set_list_control.copy_config_set.label_2"))
	controls.edit = new("EditControl"):EditControl(nil, { 0, 40, 350, 20 }, configSet.title or "Default", nil, nil, 100, function(buf)
		controls.save.enabled = buf:match("%S")
	end)
	controls.save = new("ButtonControl"):ButtonControl(nil, { -45, 70, 80, 20 }, localisation:Label("ui.config_set_list_control.create_config_set.save.label"), function()
		self.configSetService:CopyConfigSet(selValue, controls.edit.buf)
		main:ClosePopup()
	end)
	controls.save.enabled = false
	controls.cancel = new("ButtonControl"):ButtonControl(nil, { 45, 70, 80, 20 }, localisation:Label("ui.config_set_list_control.create_config_set.cancel.label"), function()
		main:ClosePopup()
	end)
	main:OpenPopup(370, 100, localisation:Label("ui.config_set_list_control.copy_config_set.label"), controls, "save", "edit", "cancel")
end

function ConfigSetListClass:RenameConfigSet(selValue)
	local configSet = self.configTab.configSets[selValue]
	local controls = {}
	local specName = configSet.title or "Default"
	controls.label = new("LabelControl"):LabelControl(nil, { 0, 20, 0, 16 }, localisation:Label("ui.config_set_list_control.copy_config_set.label_2"))
	controls.edit = new("EditControl"):EditControl(nil, { 0, 40, 350, 20 }, specName, nil, nil, 100, function(buf)
		controls.save.enabled = buf:match("%S")
	end)
	controls.save = new("ButtonControl"):ButtonControl(nil, { -45, 70, 80, 20 }, localisation:Label("ui.config_set_list_control.create_config_set.save.label"), function()
		self.configSetService:RenameConfigSet(selValue, controls.edit.buf)
		main:ClosePopup()
	end)
	controls.save.enabled = false
	controls.cancel = new("ButtonControl"):ButtonControl(nil, { 45, 70, 80, 20 }, localisation:Label("ui.config_set_list_control.create_config_set.cancel.label"), function()
		main:ClosePopup()
	end)
	main:OpenPopup(370, 100, specName and localisation:Label("ui.config_set_list_control.rename_config_set.label") or localisation:Label("ui.config_set_list_control.rename_config_set.label_2"), controls, "save", "edit", "cancel")
end

function ConfigSetListClass:GetRowValue(column, index, configSetId)
	local configSet = self.configTab.configSets[configSetId]
	if column == 1 then
		return (configSet.title or "Default") ..
			(configSetId == self.configTab.activeConfigSetId and "  ^9(Current)" or "")
	end
end

function ConfigSetListClass:OnOrderChange()
	self.configTab.modFlag = true
end

function ConfigSetListClass:OnSelClick(index, configSetId, doubleClick)
	if doubleClick and configSetId ~= self.configTab.activeConfigSetId then
		self.configTab:SetActiveConfigSet(configSetId)
		self.configTab:AddUndoState()
	end
end

function ConfigSetListClass:OnSelDelete(index, configSetId)
	local configSet = self.configTab.configSets[configSetId]
	if #self.list > 1 then
		main:OpenConfirmPopup(localisation:Text("ui.config_set_list_control.on_sel_delete.message_4"),
			localisation:Text("ui.config_set_list_control.on_sel_delete.message", { value = (configSet.title or localisation:Ref("ui.config_set_list_control.on_sel_delete.message_2")) }), localisation:Text("ui.config_set_list_control.on_sel_delete.message_3"), function()
				self.configSetService:DeleteConfigSet(configSetId, index)

				self.selIndex = nil
				self.selValue = nil
			end)
	end
end

function ConfigSetListClass:OnSelKeyDown(index, configSetId, key)
	if key == "F2" then
		self:RenameConfigSet(configSetId)
	end
end
