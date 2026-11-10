-- Path of Building
--
-- Class: Skill Set List
-- Skill set list control.
--
local t_insert = table.insert
local t_remove = table.remove
local t_maxn = table.maxn
local m_max = math.max
local s_format = string.format

---@class SkillSetListControl: ListControl
local SkillSetListClass = newClass("SkillSetListControl", "ListControl")

---@param anchor Anchor?
---@param rect Rect?
---@param skillsTab SkillsTab
function SkillSetListClass:SkillSetListControl(anchor, rect, skillsTab)
	self:ListControl(anchor, rect, 16, "VERTICAL", true, skillsTab.skillSetOrderList)
	self.skillsTab = skillsTab
	self.skillsSetService = new("SkillsSetService"):SkillsSetService(skillsTab)
	self.controls.copy = new("ButtonControl"):ButtonControl({ "BOTTOMLEFT", self, "TOP" }, { 2, -4, 60, 18 }, localisation:Label("ui.skill_set_list_control.init.copy.label"), function()
		self:CopySkillSet(self.selValue)
	end)
	self.controls.copy.enabled = function()
		return self.selValue ~= nil
	end
	self.controls.delete = new("ButtonControl"):ButtonControl({ "LEFT", self.controls.copy, "RIGHT" }, { 4, 0, 60, 18 }, localisation:Label("ui.skill_set_list_control.init.delete.label"),
		function()
			self:OnSelDelete(self.selIndex, self.selValue)
		end)
	self.controls.delete.enabled = function()
		return self.selValue ~= nil and #self.list > 1
	end
	self.controls.rename = new("ButtonControl"):ButtonControl({ "BOTTOMRIGHT", self, "TOP" }, { -2, -4, 60, 18 }, localisation:Label("ui.skill_set_list_control.init.rename.label"), function()
		self:RenameSkillSet(self.selValue)
	end)
	self.controls.rename.enabled = function()
		return self.selValue ~= nil
	end
	self.controls.new = new("ButtonControl"):ButtonControl({ "RIGHT", self.controls.rename, "LEFT" }, { -4, 0, 60, 18 }, localisation:Label("ui.skill_set_list_control.init.new.label"),
		function()
			self:CreateSkillSet()
		end)
	return self
end

function SkillSetListClass:CreateSkillSet()
	local controls = {}
	controls.label = new("LabelControl"):LabelControl(nil, { 0, 20, 0, 16 }, localisation:Label("ui.skill_set_list_control.create_skill_set.label_2"))
	controls.edit = new("EditControl"):EditControl(nil, { 0, 40, 350, 20 }, "New Skill Set", nil, nil, 100, function(buf)
		controls.save.enabled = buf:match("%S")
	end)
	controls.save = new("ButtonControl"):ButtonControl(nil, { -45, 70, 80, 20 }, localisation:Label("ui.skill_set_list_control.create_skill_set.save.label"), function()
		self.skillsSetService:NewSkillSet(controls.edit.buf)
		main:ClosePopup()
	end)
	controls.save.enabled = false
	controls.cancel = new("ButtonControl"):ButtonControl(nil, { 45, 70, 80, 20 }, localisation:Label("ui.skill_set_list_control.create_skill_set.cancel.label"), function()
		main:ClosePopup()
	end)
	main:OpenPopup(370, 100, localisation:Label("ui.skill_set_list_control.create_skill_set.label"), controls, "save", "edit", "cancel")
end

function SkillSetListClass:CopySkillSet(selValue)
	local skillSet = self.skillsTab.skillSets[selValue]
	local controls = {}
	local skillSetName = skillSet.title or "Default"
	controls.label = new("LabelControl"):LabelControl(nil, { 0, 20, 0, 16 }, localisation:Label("ui.skill_set_list_control.copy_skill_set.label_2"))
	controls.edit = new("EditControl"):EditControl(nil, { 0, 40, 350, 20 }, skillSetName, nil, nil, 100, function(buf)
		controls.save.enabled = buf:match("%S")
	end)
	controls.save = new("ButtonControl"):ButtonControl(nil, { -45, 70, 80, 20 }, localisation:Label("ui.skill_set_list_control.create_skill_set.save.label"), function()
		self.skillsSetService:CopySkillSet(selValue, controls.edit.buf)
		main:ClosePopup()
	end)
	controls.save.enabled = false
	controls.cancel = new("ButtonControl"):ButtonControl(nil, { 45, 70, 80, 20 }, localisation:Label("ui.skill_set_list_control.create_skill_set.cancel.label"), function()
		main:ClosePopup()
	end)
	main:OpenPopup(370, 100, localisation:Label("ui.skill_set_list_control.copy_skill_set.label"), controls, "save", "edit", "cancel")
end

function SkillSetListClass:RenameSkillSet(selValue)
	local skillSet = self.skillsTab.skillSets[selValue]
	local controls = {}
	local skillSetName = skillSet.title or "Default"
	controls.label = new("LabelControl"):LabelControl(nil, { 0, 20, 0, 16 }, localisation:Label("ui.skill_set_list_control.copy_skill_set.label_2"))
	controls.edit = new("EditControl"):EditControl(nil, { 0, 40, 350, 20 }, skillSetName, nil, nil, 100, function(buf)
		controls.save.enabled = buf:match("%S")
	end)
	controls.save = new("ButtonControl"):ButtonControl(nil, { -45, 70, 80, 20 }, localisation:Label("ui.skill_set_list_control.create_skill_set.save.label"), function()
		self.skillsSetService:RenameSkillSet(selValue, controls.edit.buf)
		main:ClosePopup()
	end)
	controls.save.enabled = false
	controls.cancel = new("ButtonControl"):ButtonControl(nil, { 45, 70, 80, 20 }, localisation:Label("ui.skill_set_list_control.create_skill_set.cancel.label"), function()
		main:ClosePopup()
	end)
	main:OpenPopup(370, 100, skillSetName and localisation:Label("ui.skill_set_list_control.rename_skill_set.label") or localisation:Label("ui.skill_set_list_control.rename_skill_set.label_2"), controls, "save", "edit", "cancel")
end

function SkillSetListClass:GetRowValue(column, index, skillSetId)
	local skillSet = self.skillsTab.skillSets[skillSetId]
	if column == 1 then
		return (skillSet.title or "Default") .. (skillSetId == self.skillsTab.activeSkillSetId and "  ^9(Current)" or "")
	end
end

function SkillSetListClass:OnOrderChange()
	self.skillsTab.modFlag = true
end

function SkillSetListClass:OnSelClick(index, skillSetId, doubleClick)
	if doubleClick and skillSetId ~= self.skillsTab.activeSkillSetId then
		self.skillsTab:SetActiveSkillSet(skillSetId)
		self.skillsTab:AddUndoState()
	end
end

function SkillSetListClass:OnSelDelete(index, skillSetId)
	local skillSet = self.skillsTab.skillSets[skillSetId]
	if #self.list > 1 then
		main:OpenConfirmPopup(localisation:Text("ui.skill_set_list_control.on_sel_delete.message_4"),
			localisation:Text("ui.skill_set_list_control.on_sel_delete.message", { value = (skillSet.title or localisation:Ref("ui.skill_set_list_control.on_sel_delete.message_2")) }), localisation:Text("ui.skill_set_list_control.on_sel_delete.message_3"), function()
				self.skillsSetService:DeleteSkillSet(skillSetId, index)

				self.selIndex = nil
				self.selValue = nil
			end)
	end
end

function SkillSetListClass:OnSelKeyDown(index, skillSetId, key)
	if key == "F2" then
		self:RenameSkillSet(skillSetId)
	end
end
