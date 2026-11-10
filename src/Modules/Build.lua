-- Path of Building
--
-- Module: Build
-- Loads and manages the current build.
--
local pairs = pairs
local ipairs = ipairs
local next = next
local t_insert = table.insert
local t_remove = table.remove
local m_min = math.min
local m_max = math.max
local m_floor = math.floor
local m_abs = math.abs
local s_format = string.format
local function firstToUpper(str)
	return (str:gsub("^%l", string.upper))
end

---@class Build: ControlHost
---@field spec PassiveSpec added by TreeTab
---@field powerBuilderProgressCallback fun(progress: number)?
---@field powerBuilderCallback fun()?
local buildMode = new("ControlHost"):ControlHost()

local function InsertIfNew(t, val)
	if (not t) then return end
	for i,v in ipairs(t) do
		if v == val then return end
	end
	table.insert(t, val)
end

function buildMode:Init(dbFileName, buildName, buildXML, convertBuild, importLink)
	self.dbFileName = dbFileName
	self.buildName = buildName
	self.importLink = importLink
	if dbFileName then
		self.dbFileSubPath = self.dbFileName:sub(#main.buildPath + 1, -#self.buildName - 5)
	else
		self.dbFileSubPath = main.modes.LIST.subPath or ""
	end
	if not buildName then
		main:SetMode("LIST")
	end

	-- Load build file
	self.xmlSectionList = { }
	self.spectreList = { }
	self.beastList = { }
	self.timelessData = { jewelType = { }, conquerorType = { }, devotionVariant1 = 1, devotionVariant2 = 1, jewelSocket = { }, fallbackWeightMode = { }, searchList = "", searchListFallback = "", searchResults = { }, sharedResults = { } }
	self.viewMode = "TREE"
	self.characterLevel = m_min(m_max(main.defaultCharLevel or 1, 1), 100)
	self.targetVersion = liveTargetVersion
	self.characterLevelAutoMode = main.defaultCharLevel == 1 or main.defaultCharLevel == nil
	-- List of loadouts by spec name. Updated on each SyncLoadouts() call.
	self.loadoutsList = {}
	self.activeLoadout = nil
	if buildXML then
		if self:LoadDB(buildXML, "Unnamed build") then
			self:CloseBuild()
			return
		end
		self.modFlag = true
	else
		if self:LoadDBFile() then
			self:CloseBuild()
			return
		end
		self.modFlag = false
	end

	if convertBuild then
		self.targetVersion = liveTargetVersion
	end
	if self.targetVersion ~= liveTargetVersion then
		self.targetVersion = nil
		self:OpenConversionPopup()
		return
	end

	self.abortSave = true
	-- calculate acts Table based on data.questRewards
	self.acts = { { level = 1 , questPoints = 0 } }
	for _, quest in ipairs(data.questRewards) do
		if not quest.questPoints then
			goto nextQuest
		end
		local act = quest.Act + (quest.Type == "Cruel" and 3 or 0) + 1
		if not self.acts[act] then
			self.acts[act] = {
				level = quest.AreaLevel,
				questPoints = quest.questPoints + self.acts[act - 1].questPoints,
			}
		else
			self.acts[act].questPoints = self.acts[act].questPoints + quest.questPoints
			self.acts[act].level = m_max(self.acts[act].level, quest.AreaLevel)
		end
		:: nextQuest ::
	end
	self.maxActs = #self.acts
	self.maxWeaponSets = self.acts[self.maxActs].questPoints

	wipeTable(self.controls)

	local miscTooltip = new("Tooltip"):Tooltip()

	-- Controls: top bar, left side
	self.anchorTopBarLeft = new("Control"):Control(nil, { 4, 4, 0, 20 })
	self.controls.back = new("ButtonControl"):ButtonControl({ "LEFT", self.anchorTopBarLeft, "RIGHT" }, { 0, 0, 60, 20 }, localisation:Label("ui.build.init.back.label"), function()
		if self.unsaved then
			self:OpenSavePopup("LIST")
		else
			self:CloseBuild()
		end
	end)
	self.controls.save = new("ButtonControl"):ButtonControl({ "LEFT", self.controls.back, "RIGHT" }, { 8, 0, 50, 20 }, localisation:Label("ui.build.init.save.label"), function()
		self:SaveDBFile()
	end)
	self.controls.save.enabled = function()
		return not self.dbFileName or self.unsaved
	end
	self.controls.saveAs = new("ButtonControl"):ButtonControl({ "LEFT", self.controls.save, "RIGHT" }, { 8, 0, 70, 20 }, localisation:Label("ui.build.init.save_as.label"), function()
		self:OpenSaveAsPopup()
	end)
	self.controls.saveAs.enabled = function()
		return self.dbFileName
	end

	-- conditional for smaller screens to move "Current build" to the side bar
	local function buildNameConditional()
		return self.anchorTopBarRight:GetPos() < 900
	end
	self.controls.buildName = new("Control"):Control({ "LEFT", self.controls.saveAs, "RIGHT" }, { 4, 36, 0, 20 })
	self.controls.buildName.width = function(control)
		local limit = buildNameConditional() and 203 or
			(self.anchorTopBarRight:GetPos() - 98 - 58
			- self.controls.pointDisplay:GetSize() - self.controls.levelScalingButton:GetSize() - self.controls.characterLevel:GetSize()
			- self.controls.back:GetSize() - self.controls.save:GetSize() - self.controls.saveAs:GetSize())
		local bnw = DrawStringWidth(16, "VAR", self.buildName)
		self.strWidth = m_min(bnw, limit)
		self.strLimited = bnw > limit
		return self.strWidth + 98
	end
	self.controls.buildName.Draw = function(control)
		local x, y = control:GetPos()
		local width, height = control:GetSize()
		SetDrawColor(0.5, 0.5, 0.5)
		DrawImage(nil, x + 91, y, self.strWidth + 6, 20)
		SetDrawColor(0, 0, 0)
		DrawImage(nil, x + 92, y + 1, self.strWidth + 4, 18)
		SetDrawColor(1, 1, 1)
		SetViewport(x, y + 2, self.strWidth + 94, 16)
		DrawString(0, 0, "LEFT", 16, "VAR", localisation:Text("ui.build.init.build_name_draw.message", { build_name = self.buildName }))
		SetViewport()
		if control:IsMouseInBounds() then
			SetDrawLayer(nil, 10)
			miscTooltip:Clear()
			if self.dbFileSubPath and self.dbFileSubPath ~= "" then
				miscTooltip:AddLine(16, self.dbFileSubPath..self.buildName)
			elseif self.strLimited then
				miscTooltip:AddLine(16, self.buildName)
			end
			miscTooltip:Draw(x, y, width, height, main.viewPort)
			SetDrawLayer(nil, 0)
		end
	end
	self.controls.buildName.x = function()
		return buildNameConditional() and -196 or 8
	end
	self.controls.buildName.y = function()
		return buildNameConditional() and 32 or 0
	end

	-- Controls: top bar, right side
	self.anchorTopBarRight = new("Control"):Control(nil, { function() return main.screenW / 2 + self.controls.characterLevel.width + 10 end, 4, 0, 20 })

	local function getPointDisplayX() -- I had it hardcoded to -323 before switching to the control sizing
		return - (23 + self.controls.pointDisplay:GetSize() + self.controls.levelScalingButton:GetSize() + self.controls.characterLevel:GetSize())
	end
	self.controls.pointDisplay = new("Control"):Control({ "LEFT", self.anchorTopBarRight, "RIGHT" }, { function() return getPointDisplayX() end, 0, 0, 20 })
	self.controls.pointDisplay.width = function(control)
		return DrawStringWidth(16, "FIXED", control.str) + 8
	end
	self.controls.pointDisplay.Draw = function(control)
		local x, y = control:GetPos()
		local width, height = control:GetSize()
		SetDrawColor(1, 1, 1)
		DrawImage(nil, x, y, width, height)
		SetDrawColor(0, 0, 0)
		DrawImage(nil, x + 1, y + 1, width - 2, height - 2)
		SetDrawColor(1, 1, 1)
		DrawString(x + 4, y + 2, "LEFT", 16, "FIXED", control.str)
		if control:IsMouseInBounds() then
			SetDrawLayer(nil, 10)
			miscTooltip:Clear()
			miscTooltip:AddLine(16, control.req)
			miscTooltip:Draw(x, y, width, height, main.viewPort)
			SetDrawLayer(nil, 0)
		end
	end
	self.controls.levelScalingButton = new("ButtonControl"):ButtonControl({ "LEFT", self.controls.pointDisplay, "RIGHT" }, { 8, 0, 50, 20 }, self.characterLevelAutoMode and localisation:Label("ui.build.init.level_scaling_button.label") or localisation:Label("ui.build.init.level_scaling_button.label_2"), function()
		self.characterLevelAutoMode = not self.characterLevelAutoMode
		self.controls.levelScalingButton.label = self.characterLevelAutoMode and localisation:Label("ui.build.init.level_scaling_button_label.label") or localisation:Label("ui.build.init.level_scaling_button_label.label_2")
		self.configTab:BuildModList()
		self.modFlag = true
		self.buildFlag = true
	end)
	self.controls.characterLevel = new("EditControl"):EditControl({ "LEFT", self.controls.levelScalingButton, "RIGHT" }, { 10, 0, 106, 20 }, "", localisation:Label("ui.build.init.character_level.label"), "%D", 3, function(buf)
		self.characterLevel = m_min(m_max(tonumber(buf) or 1, 1), 100)
		self.configTab:BuildModList()
		self.modFlag = true
		self.buildFlag = true
		self.characterLevelAutoMode = false
		self.controls.levelScalingButton.label = localisation:Label("ui.build.init.level_scaling_button_label.label_2")
	end)
	self.controls.characterLevel:SetText(self.characterLevel)
	self.controls.characterLevel.tooltipFunc = function(tooltip)
		if tooltip:CheckForUpdate(self.characterLevel) then
			tooltip:AddLine(16, localisation:Text("ui.build.init.character_level_tooltip_func.tooltip"))
			local playerLevel = self.characterLevel
			local safeZone = 3 + m_floor(playerLevel / 16)
			for level, expLevel in ipairs(self.data.monsterExperienceLevelMap) do
				local diff = m_abs(playerLevel - expLevel) - safeZone
				local mult
				if diff <= 0 then
					mult = 1
				else
					mult = ((playerLevel + 5) / (playerLevel + 5 + diff ^ 2.5)) ^ 1.5
				end
				if playerLevel >= 95 then
					local xpPenalty = ({0.935, 0.885, 0.813, 0.7175, 0.6})[playerLevel - 94] or 0
					mult = mult * (1 / (1 + 0.1 * (playerLevel - 94))) * xpPenalty
				end
				if mult > 0.01 then
					local line = level
					if level >= 68 then
						line = line .. localisation:Text("build.level_scaling.tier", { tier = level - 67 })
					end
					line = line .. string.format(": %.1f%%", mult * 100)
					tooltip:AddLine(14, line)
				end
			end
		end
	end
	self.controls.classDrop = new("DropDownControl"):DropDownControl({ "LEFT", self.controls.characterLevel, "RIGHT" }, { 8, 0, 90, 20 }, nil, function(index, value)
		if value.classId ~= self.spec.curClassId then
			if self.spec:CountAllocNodes() == 0 or self.spec:IsClassConnected(value.classId) then
				self.spec:SelectClass(value.classId)
				self.spec:AddUndoState()
				self.spec:SetWindowTitleWithBuildClass()
				self.buildFlag = true
				self.treeTab.viewer.searchStrCached = ""
			else
				main:OpenConfirmPopup(localisation:Text("ui.build.init.class_drop.label_2"), localisation:Text("ui.build.init.class_drop.label", { label = localisation:Field(value, 'label'), label_2 = localisation:Field(value, 'label') }), localisation:Text("ui.build.init.class_drop.label_4"), function()
					self.spec:SelectClass(value.classId)
					self.spec:AddUndoState()
					self.spec:SetWindowTitleWithBuildClass()
					self.buildFlag = true
					self.treeTab.viewer.searchStrCached = ""
				end, localisation:Text("ui.build.init.class_drop.label_3"), function()
					if self.spec:ConnectToClass(value.classId) then
						self.spec:SelectClass(value.classId)
						self.spec:AddUndoState()
						self.spec:SetWindowTitleWithBuildClass()
						self.buildFlag = true
						self.treeTab.viewer.searchStrCached = ""
					end
				end)
			end
		end
	end)
	self.controls.ascendDrop = new("DropDownControl"):DropDownControl({ "LEFT", self.controls.classDrop, "RIGHT" }, { 8, 0, 120, 20 }, nil, function(index, value)
		self.spec:SelectAscendClass(value.ascendClassId)
		self.spec:AddUndoState()
		self.spec:SetWindowTitleWithBuildClass()
		self.buildFlag = true
	end)
	self.controls.buildLoadouts = new("DropDownControl"):DropDownControl({ "LEFT", self.controls.ascendDrop, "RIGHT" }, { 8, 0, 190, 20 }, {}, function(index, value)
		if value == "^7^7Loadouts:" or value == "^7^7-----" then
			self.controls.buildLoadouts:SetSel(1)
			return
		end
		if value == "^7^7Sync" then
			self:SyncLoadouts()
			self.controls.buildLoadouts:SetSel(1)
			return
		end
		if value == "^7^7Help >>" then
			main:OpenAboutPopup(7)
			self.controls.buildLoadouts:SetSel(1)
			return
		end
		if value == "^7^7Manage" then
			self:OpenBuildSetManagePopup()
		end

		local loadout = self:GetLoadoutByName(value)
		self:SetActiveLoadout(loadout)

		self.controls.buildLoadouts:SelByValue(value)
	end)

	if buildName == "~~temp~~" then
		-- Remove temporary build file
		os.remove(self.dbFileName)
		self.buildName = "Unnamed build"
		self.dbFileName = false
		self.dbFileSubPath = nil
		self.modFlag = true
	end

	-- List of display stats
	local displayStatsModule = LoadModule("Modules/BuildDisplayStats")
	self.displayStats = displayStatsModule.displayStats
	self.minionDisplayStats = displayStatsModule.minionDisplayStats
	self.extraSaveStats = displayStatsModule.extraSaveStats

	-- Controls: Side bar
	self.anchorSideBar = new("Control"):Control(nil, { 4, 60, 0, 0 })
	self.anchorSideBar.y = function()
		return buildNameConditional() and 60 or 36
	end

	self.controls.modeImport = new("ButtonControl"):ButtonControl({ "TOPLEFT", self.anchorSideBar, "TOPLEFT" }, { 0, 0, 134, 20 }, localisation:Label("ui.build.init.mode_import.label"), function()
		self.viewMode = "IMPORT"
		self.importTab:RefreshAuthStatus()
	end)
	self.controls.modeImport.locked = function() return self.viewMode == "IMPORT" end
	self.controls.modeNotes = new("ButtonControl"):ButtonControl({ "LEFT", self.controls.modeImport, "RIGHT" }, { 4, 0, 58, 20 }, localisation:Label("ui.build.init.mode_notes.label"), function()
		self.viewMode = "NOTES"
	end)
	self.controls.modeNotes.locked = function() return self.viewMode == "NOTES" end
	self.controls.modeConfig = new("ButtonControl"):ButtonControl({ "TOPRIGHT", self.anchorSideBar, "TOPLEFT" }, { 300, 0, 100, 20 }, localisation:Label("ui.build.init.mode_config.label"), function()
		self.viewMode = "CONFIG"
	end)
	self.controls.modeConfig.locked = function() return self.viewMode == "CONFIG" end
	self.controls.modeTree = new("ButtonControl"):ButtonControl({ "TOPLEFT", self.anchorSideBar, "TOPLEFT" }, { 0, 26, 72, 20 }, localisation:Label("ui.build.init.mode_tree.label"), function()
		self.viewMode = "TREE"
	end)
	self.controls.modeTree.locked = function() return self.viewMode == "TREE" end
	self.controls.modeSkills = new("ButtonControl"):ButtonControl({ "LEFT", self.controls.modeTree, "RIGHT" }, { 4, 0, 72, 20 }, localisation:Label("ui.build.init.mode_skills.label"), function()
		self.viewMode = "SKILLS"
	end)
	self.controls.modeSkills.locked = function() return self.viewMode == "SKILLS" end
	self.controls.modeItems = new("ButtonControl"):ButtonControl({ "LEFT", self.controls.modeSkills, "RIGHT" }, { 4, 0, 72, 20 }, localisation:Label("ui.build.init.mode_items.label"), function()
		self.viewMode = "ITEMS"
	end)
	self.controls.modeItems.locked = function() return self.viewMode == "ITEMS" end
	self.controls.modeCalcs = new("ButtonControl"):ButtonControl({ "LEFT", self.controls.modeItems, "RIGHT" }, { 4, 0, 72, 20 }, localisation:Label("ui.build.init.mode_calcs.label"), function()
		self.viewMode = "CALCS"
	end)
	self.controls.modeCalcs.locked = function() return self.viewMode == "CALCS" end
	self.controls.modeParty = new("ButtonControl"):ButtonControl({ "TOPLEFT", self.anchorSideBar, "TOPLEFT" }, { 0, 52, 72, 20 }, localisation:Label("ui.build.init.mode_party.label"), function()
		self.viewMode = "PARTY"
	end)
	self.controls.modeParty.locked = function() return self.viewMode == "PARTY" end
	self.controls.modeCompare = new("ButtonControl"):ButtonControl({ "LEFT", self.controls.modeParty, "RIGHT" }, { 4, 0, 72, 20 }, localisation:Label("ui.build.init.mode_compare.label"), function()
		self.viewMode = "COMPARE"
	end)
	self.controls.modeCompare.locked = function() return self.viewMode == "COMPARE" end
	-- Skills
	self.controls.mainSkillLabel = new("LabelControl"):LabelControl({ "TOPLEFT", self.anchorSideBar, "TOPLEFT" }, { 0, 80, 300, 16 }, localisation:Label("ui.build.init.main_skill_label.label"))
	self.controls.mainSocketGroup = new("DropDownControl"):DropDownControl({ "TOPLEFT", self.controls.mainSkillLabel, "BOTTOMLEFT" }, { 0, 2, 300, 18 }, nil, function(index, value)
		self.mainSocketGroup = index
		self.modFlag = true
		self.buildFlag = true
	end)
	self.controls.mainSocketGroup.maxDroppedWidth = 500
	self.controls.mainSocketGroup.tooltipFunc = function(tooltip, mode, index, value)
		local socketGroup = self.skillsTab.socketGroupList[index]
		if socketGroup and tooltip:CheckForUpdate(socketGroup, self.outputRevision) then
			self.skillsTab:AddSocketGroupTooltip(tooltip, socketGroup)
		end
	end
	self.controls.mainSkill = new("DropDownControl"):DropDownControl({ "TOPLEFT", self.controls.mainSocketGroup, "BOTTOMLEFT" }, { 0, 2, 300, 18 }, nil, function(index, value)
		local mainSocketGroup = self.skillsTab.socketGroupList[self.mainSocketGroup]
		mainSocketGroup.mainActiveSkill = index
		self.modFlag = true
		self.buildFlag = true
	end)
	self.controls.statSet = new("DropDownControl"):DropDownControl({ "TOPLEFT", self.controls.mainSkill, "BOTTOMLEFT" }, { 0, 2, 300, 18 }, nil, function(index, value)
		local mainSocketGroup = self.skillsTab.socketGroupList[self.mainSocketGroup]
		local srcInstance = mainSocketGroup.displaySkillList[mainSocketGroup.mainActiveSkill].activeEffect.srcInstance
		srcInstance.statSet = srcInstance.statSet or { }
		srcInstance.statSet[value.grantedEffectId] = index
		self.modFlag = true
		self.buildFlag = true
	end)
	self.controls.mainSkillPart = new("DropDownControl"):DropDownControl({ "TOPLEFT", self.controls.statSet, "BOTTOMLEFT", true }, { 0, 2, 300, 18 }, nil, function(index, value)
		local mainSocketGroup = self.skillsTab.socketGroupList[self.mainSocketGroup]
		local srcInstance = mainSocketGroup.displaySkillList[mainSocketGroup.mainActiveSkill].activeEffect.srcInstance
		srcInstance.skillPart = index
		self.modFlag = true
		self.buildFlag = true
	end)
	self.controls.mainSkillStageCountLabel = new("LabelControl"):LabelControl({ "TOPLEFT", self.controls.mainSkillPart, "BOTTOMLEFT", true }, { 0, 3, 0, 16 }, localisation:Label("ui.build.init.main_skill_stage_count_label.label")) {
		shown = function()
			return self.controls.mainSkillStageCount:IsShown()
		end,
	}
	self.controls.mainSkillStageCount = new("EditControl"):EditControl({ "LEFT", self.controls.mainSkillStageCountLabel, "RIGHT", true }, { 2, 0, 60, 18 }, nil, nil, "%D", nil, function(buf)
		local mainSocketGroup = self.skillsTab.socketGroupList[self.mainSocketGroup]
		local srcInstance = mainSocketGroup.displaySkillList[mainSocketGroup.mainActiveSkill].activeEffect.srcInstance
		srcInstance.skillStageCount = tonumber(buf)
		self.modFlag = true
		self.buildFlag = true
	end)
	self.controls.mainSkillMineCountLabel = new("LabelControl"):LabelControl({ "TOPLEFT", self.controls.mainSkillStageCountLabel, "BOTTOMLEFT", true }, { 0, 3, 0, 16 }, localisation:Label("ui.build.init.main_skill_mine_count_label.label")) {
		shown = function()
			return self.controls.mainSkillMineCount:IsShown()
		end,
	}
	self.controls.mainSkillMineCount = new("EditControl"):EditControl({ "LEFT", self.controls.mainSkillMineCountLabel, "RIGHT", true }, { 2, 0, 60, 18 }, nil, nil, "%D", nil, function(buf)
		local mainSocketGroup = self.skillsTab.socketGroupList[self.mainSocketGroup]
		local srcInstance = mainSocketGroup.displaySkillList[mainSocketGroup.mainActiveSkill].activeEffect.srcInstance
		srcInstance.skillMineCount = tonumber(buf)
		self.modFlag = true
		self.buildFlag = true
	end)
	self.controls.mainSkillMinion = new("DropDownControl"):DropDownControl({ "TOPLEFT", self.controls.mainSkillMineCountLabel, "BOTTOMLEFT", true }, { 0, 3, 178, 18 }, nil, function(index, value)
		local mainSocketGroup = self.skillsTab.socketGroupList[self.mainSocketGroup]
		local srcInstance = mainSocketGroup.displaySkillList[mainSocketGroup.mainActiveSkill].activeEffect.srcInstance
		if value.itemSetId then
			srcInstance.skillMinionItemSet = value.itemSetId
			srcInstance.skillMinionItemSetCalcs = value.itemSetId
			if srcInstance.nameSpec:match("^Spectre:") then
				srcInstance.nameSpec = "Spectre: ".. value.label
			elseif srcInstance.nameSpec:match("^Companion:") then
				srcInstance.nameSpec = "Companion: ".. value.label
			end
		else
			srcInstance.skillMinion = value.minionId
			srcInstance.skillMinionCalcs = value.minionId
			if srcInstance.nameSpec:match("^Spectre:") then
				srcInstance.nameSpec = "Spectre: ".. value.label
			elseif srcInstance.nameSpec:match("^Companion:") then
				srcInstance.nameSpec = "Companion: ".. value.label
			end
		end
		self.modFlag = true
		self.buildFlag = true
	end)
	function self.controls.mainSkillMinion.CanReceiveDrag(control, type, value)
		if type == "Item" and control.list[control.selIndex] and control.list[control.selIndex].itemSetId then
			local mainSocketGroup = self.skillsTab.socketGroupList[self.mainSocketGroup]
			local minionUses = mainSocketGroup.displaySkillList[mainSocketGroup.mainActiveSkill].activeEffect.grantedEffect.minionUses
			return minionUses and minionUses[value:GetPrimarySlot()] -- O_O
		end
	end
	function self.controls.mainSkillMinion.ReceiveDrag(control, type, value, source)
		self.itemsTab:EquipItemInSet(value, control.list[control.selIndex].itemSetId)
	end
	function self.controls.mainSkillMinion.tooltipFunc(tooltip, mode, index, value)
		tooltip:Clear()
		if value.itemSetId then
			self.itemsTab:AddItemSetTooltip(tooltip, self.itemsTab.itemSets[value.itemSetId])
			tooltip:AddSeparator(14)
			tooltip:AddLine(14, colorCodes.TIP .. localisation:Text("ui.build.tooltip_func.tooltip"))
		end
	end
	self.controls.mainSkillMinionLibrary = new("ButtonControl"):ButtonControl({ "LEFT", self.controls.mainSkillMinion, "RIGHT" }, { 2, 0, 120, 18 }, localisation:Label("ui.build.init.main_skill_minion_library.label"), function()
		self:OpenSpectreLibrary("spectre")
	end)
	self.controls.mainSkillBeastLibrary = new("ButtonControl"):ButtonControl({ "LEFT", self.controls.mainSkillMinion, "RIGHT" }, { 2, 0, 120, 18 }, localisation:Label("ui.build.init.main_skill_beast_library.label"), function()
		self:OpenSpectreLibrary("beast")
	end)
	self.controls.mainSkillMinionSkill = new("DropDownControl"):DropDownControl({ "TOPLEFT", self.controls.mainSkillMinion, "BOTTOMLEFT", true }, { 0, 2, 200, 16 }, nil, function(index, value)
		local mainSocketGroup = self.skillsTab.socketGroupList[self.mainSocketGroup]
		local srcInstance = mainSocketGroup.displaySkillList[mainSocketGroup.mainActiveSkill].activeEffect.srcInstance
		srcInstance.skillMinionSkill = index
		self.modFlag = true
		self.buildFlag = true
	end)
	self.controls.mainSkillMinionSkillStatSet = new("DropDownControl"):DropDownControl({ "TOPLEFT", self.controls.mainSkillMinionSkill, "BOTTOMLEFT", true }, { 0, 2, 200, 16 }, nil, function(index, value)
		local mainSocketGroup = self.skillsTab.socketGroupList[self.mainSocketGroup]
		local srcInstance = mainSocketGroup.displaySkillList[mainSocketGroup.mainActiveSkill].activeEffect.srcInstance
		srcInstance.skillMinionSkillStatSetIndexLookup = srcInstance.skillMinionSkillStatSetIndexLookup or { }
		srcInstance.skillMinionSkillStatSetIndexLookup[value.grantedEffectId] = srcInstance.skillMinionSkillStatSetIndexLookup[value.grantedEffectId] or { }
		srcInstance.skillMinionSkillStatSetIndexLookup[value.grantedEffectId][srcInstance.skillMinionSkill] = index
		self.modFlag = true
		self.buildFlag = true
	end)
	self.controls.statBoxAnchor = new("Control"):Control({ "TOPLEFT", self.controls.mainSkillMinionSkillStatSet, "BOTTOMLEFT", true }, { 0, 2, 0, 0 })
	self.controls.statBox = new("TextListControl"):TextListControl({ "TOPLEFT", self.controls.statBoxAnchor, "BOTTOMLEFT" }, { 0, 2, 300, 0 }, { { x = 170, align = "RIGHT_X" }, { x = 174, align = "LEFT" } })
	self.controls.statBox.height = function(control)
		local x, y = control:GetPos()
		local warnHeight = main.showWarnings and #self.controls.warnings.lines > 0 and 18 or 0
		return main.screenH - main.mainBarHeight - 4 - y - warnHeight
	end
	function self.controls.statBox.onClick(hoveredLine)
		self:SetDisplayStat(hoveredLine, true)
	end
	self.controls.warnings = new("Control"):Control({"TOPLEFT",self.controls.statBox,"BOTTOMLEFT",true}, {0, 0, 0, 18})
	self.controls.warnings.lines = {}
	self.controls.warnings.width = function(control)
		return control.str and DrawStringWidth(16, "FIXED", control.str) + 8 or 0
	end
	self.controls.warnings.Draw = function(control)
		if #self.controls.warnings.lines > 0 then
			local count = 0
			for _ in pairs(self.controls.warnings.lines) do count = count + 1 end
			control.str = colorCodes.NEGATIVE .. localisation:Text('build.warning.count', { count = count })
			local x, y = control:GetPos()
			local width, height = control:GetSize()
			DrawString(x, y + 2, "LEFT", 16, "FIXED", control.str)
			if control:IsMouseInBounds() then
				SetDrawLayer(nil, 10)
				miscTooltip:Clear()
				for k,v in pairs(self.controls.warnings.lines) do miscTooltip:AddLine(16, v) end
				miscTooltip:Draw(x, y, width, height, main.viewPort)
				SetDrawLayer(nil, 0)
			end
		else
			control.str = {}
		end
	end

	-- Initialise build components
	self.latestTree = main.tree[latestTreeVersion]
	data.setJewelRadiiGlobally(latestTreeVersion)
	self.data = data
	self.importTab = new("ImportTab"):ImportTab(self)
	self.notesTab = new("NotesTab"):NotesTab(self)
	self.partyTab = new("PartyTab"):PartyTab(self)
	self.configTab = new("ConfigTab"):ConfigTab(self)
	self.itemsTab = new("ItemsTab"):ItemsTab(self)
	self.treeTab = new("TreeTab"):TreeTab(self)
	self.skillsTab = new("SkillsTab"):SkillsTab(self)
	self.calcsTab = new("CalcsTab"):CalcsTab(self)
	self.controls.breakdown = new("CalcBreakdownControl"):CalcBreakdownControl(self.calcsTab)
	self.controls.breakdown.pinnedColour = hexToRGB(colorCodes.CUSTOM) or error("failed to set breakdown pin colour")
	self.controls.breakdown.envName = "mainEnv"
	self.controls.breakdown.clearDisplayFunc = function()
		self:ClearDisplayStat()
	end
	-- ensure that we don't refer to outdated calc tab sections
	self.breakdownIndex = nil
	self.compareTab = new("CompareTab"):CompareTab(self)
	-- Used for pinned calculation panes
	self.overlayPanes = { }

	-- Load sections from the build file
	self.savers = {
		["Config"] = self.configTab,
		["Notes"] = self.notesTab,
		["Party"] = self.partyTab,
		["Tree"] = self.treeTab,
		["TreeView"] = self.treeTab.viewer,
		["Items"] = self.itemsTab,
		["Skills"] = self.skillsTab,
		["Calcs"] = self.calcsTab,
		["Import"] = self.importTab,
	}
	self.legacyLoaders = { -- Special loaders for legacy sections
		["Spec"] = self.treeTab,
	}

	--special rebuild to properly initialise boss placeholders
	self.configTab:BuildModList()

	self:UpdateClassDropdowns()

	-- so we ran into problems with converted trees, trying to check passive tree routes and also consider thread jewels
	-- but we can't check jewel info because items have not been loaded yet, and they come after passives in the xml.
	-- the simplest solution seems to be making sure passive trees (which contain jewel sockets) are loaded last.
	local deferredPassiveTrees = { }
	for _, node in ipairs(self.xmlSectionList) do
		-- Check if there is a saver that can load this section
		local saver = self.savers[node.elem] or self.legacyLoaders[node.elem]
		if saver then
			-- if the saver is treeTab, defer it until everything is loaded
			if saver == self.treeTab  then
				t_insert(deferredPassiveTrees, node)
			else
				if saver:Load(node, self.dbFileName) then
					self:CloseBuild()
					return
				end
			end
		end
	end
	for _, node in ipairs(deferredPassiveTrees) do
		-- Check if there is a saver that can load this section
		if self.treeTab:Load(node, self.dbFileName) then
			self:CloseBuild()
			return
		end
	end
	for _, saver in pairs(self.savers) do
		if saver.PostLoad then
			saver:PostLoad()
		end
	end

	if next(self.configTab.input) == nil then
		-- Check for old calcs tab settings
		self.configTab:ImportCalcSettings()
	end

	-- Build calculation output tables
	self.outputRevision = 1
	self.calcsTab:BuildOutput()
	self:RefreshStatList()
	self.buildFlag = false

	self.spec:SetWindowTitleWithBuildClass()

	--[[
	local testTooltip = new("Tooltip"):Tooltip()
	for _, item in pairs(main.uniqueDB.list) do
		ConPrintf("%s", item.name)
		self.itemsTab:AddItemTooltip(testTooltip, item)
		testTooltip:Clear()
	end
	for _, item in pairs(main.rareDB.list) do
		ConPrintf("%s", item.name)
		self.itemsTab:AddItemTooltip(testTooltip, item)
		testTooltip:Clear()
	end
	--]]

	--[[
	local start = GetTime()
	SetProfiling(true)
	for i = 1, 10  do
		self.calcsTab:PowerBuilder()
	end
	SetProfiling(false)
	ConPrintf("Power build time: %d ms", GetTime() - start)
	--]]

	self.abortSave = false
	self:SyncLoadouts()
end

function buildMode:SyncLoadouts(skipBuildPlannerSync)
	self.controls.buildLoadouts.list = localisation:List({"No Loadouts"}, { "ui.build.loadouts.empty" })
	self.loadoutsList = {}

	local filteredList = {"^7^7Loadouts:"}
	local loadoutKeys = { [1] = "ui.build.loadouts.heading" }
	local filteredSpecs = {}
	local treeList = {}
	local itemList = {}
	local skillList = {}
	local configList = {}
	-- used when clicking on the dropdown to set the correct setId for each SetActiveSet()
	self.treeListSpecialLinks, self.itemListSpecialLinks, self.skillListSpecialLinks, self.configListSpecialLinks = {}, {}, {}, {}


	local oneSkill = self.skillsTab and #self.skillsTab.skillSetOrderList == 1
	local oneItem = self.itemsTab and #self.itemsTab.itemSetOrderList == 1
	local oneConfig = self.configTab and #self.configTab.configSetOrderList == 1

	if self.treeTab ~= nil and self.itemsTab ~= nil and self.skillsTab ~= nil and self.configTab ~= nil then
		local transferTable = {}
		local sortedTreeListSpecialLinks = {}
		for id, spec in ipairs(self.treeTab.specList) do
			local specTitle = spec.title or "Default"
			-- only alphanumeric and comma are allowed in the braces { }
			local linkIdentifier = string.match(specTitle, "%{([%w,]+)%}")

			if linkIdentifier then
				local setName = specTitle:gsub("%{" .. linkIdentifier .. "%}", ""):gsub("^%s*", ""):gsub("%s*$", "")
				if not setName or setName == "" then
					setName = "Default"
				end

				-- iterate over each identifier, delimited by comma, and set the index so we can grab it later
				-- setId index is the id of the set in the global list needed for SetActiveSet
				-- setName is only used for Tree currently and we strip the braces to get the plain name of the set, this is used as the name of the loadout
				for linkId in string.gmatch(linkIdentifier, "[^%,]+") do
					transferTable["setId"] = id
					transferTable["setName"] = setName
					transferTable["linkId"] = linkId
					self.treeListSpecialLinks[linkId] = transferTable
					t_insert(sortedTreeListSpecialLinks, transferTable)
					transferTable = {}
				end
			else
				t_insert(filteredSpecs, spec)
			end
		end

		-- item, skill, and config sets have identical structure
		local function identifyLinks(setOrderList, tabSets, setList, specialLinks, treeLinks)
			for id, set in ipairs(setOrderList) do
				local setTitle = tabSets[set].title or "Default"
				local linkIdentifier = string.match(setTitle, "%{([%w,]+)%}")

				-- this if/else prioritizes group identifier in case the user creates sets with same name AND same identifiers
				-- result is only the group is recognized and one loadout is created rather than a duplicate from each condition met
				if linkIdentifier then
					local setName = setTitle:gsub("%{" .. linkIdentifier .. "%}", ""):gsub("^%s*", ""):gsub("%s*$", "")
					if not setName or setName == "" then
						setName = "Default"
					end

					for linkId in string.gmatch(linkIdentifier, "[^%,]+") do
						transferTable["setId"] = set
						transferTable["setName"] = setName
						specialLinks[linkId] = transferTable
						transferTable = {}
					end
				else
					setList[setTitle] = true
				end
			end
		end
		identifyLinks(self.itemsTab.itemSetOrderList, self.itemsTab.itemSets, itemList, self.itemListSpecialLinks, self.treeListSpecialLinks)
		identifyLinks(self.skillsTab.skillSetOrderList, self.skillsTab.skillSets, skillList, self.skillListSpecialLinks, self.treeListSpecialLinks)
		identifyLinks(self.configTab.configSetOrderList, self.configTab.configSets, configList, self.configListSpecialLinks, self.treeListSpecialLinks)

		for id, spec in ipairs(filteredSpecs) do
			local specTitle = spec.title or "Default"
			t_insert(treeList, (spec.treeVersion ~= latestTreeVersion and ("["..treeVersions[spec.treeVersion].display.."] ") or "")..specTitle)
			local tree = treeList[#treeList]
			-- only exact match loadouts
			if (oneItem or itemList[tree]) and (oneSkill or skillList[tree]) and (oneConfig or configList[tree]) then
				t_insert(filteredList, tree)
				if not spec.title and spec.treeVersion == latestTreeVersion then
					loadoutKeys[#filteredList] = 'term.calculation_source.default'
				end
				t_insert(self.loadoutsList, filteredSpecs[id])
			end
		end

		-- loop over the identifiers found within braces and set the loadout name to the TreeSet
		for _, tree in ipairs(sortedTreeListSpecialLinks) do
			local treeLinkId = tree.linkId
			if ((oneItem or self.itemListSpecialLinks[treeLinkId]) and (oneSkill or self.skillListSpecialLinks[treeLinkId]) and (oneConfig or self.configListSpecialLinks[treeLinkId])) then
				t_insert(filteredList, tree.setName .. " {" .. treeLinkId .. "}")
			end
		end
	end

	if not skipBuildPlannerSync then
		self.importTab:RefreshBuildPlannerSets()
	end

	-- giving the options unique formatting so it can not match with user-created sets
	t_insert(filteredList, "^7^7-----")
	t_insert(filteredList, "^7^7Manage")
	t_insert(filteredList, "^7^7Sync")
	t_insert(filteredList, "^7^7Help >>")
	loadoutKeys[#filteredList - 2] = "ui.build.loadouts.manage"
	loadoutKeys[#filteredList - 1] = "ui.build.loadouts.sync"
	loadoutKeys[#filteredList] = "ui.build.loadouts.help"
	localisation:List(filteredList, loadoutKeys)

	if #filteredList > 0 then
		self.controls.buildLoadouts.list = filteredList
	end

	-- Try to select loadout in dropdown based on currently selected tree
	if self.treeTab then
		local spec = self.treeTab.specList[self.treeTab.activeSpec]
		local treeName = spec and spec.title or "Default"
		for i, loadout in ipairs(filteredList) do
			if loadout == treeName then
				local linkMatch = string.match(treeName, "%{(%w+)%}") or treeName
				if linkMatch then
					local skillName = self.skillsTab.skillSets[self.skillsTab.activeSkillSetId].title or "Default"
					local skillMatch = oneSkill or skillName:find(linkMatch, 1, true)
					local itemName = self.itemsTab.itemSets[self.itemsTab.activeItemSetId].title or "Default"
					local itemMatch = oneItem or itemName:find(linkMatch, 1, true)
					local configName = self.configTab.configSets[self.configTab.activeConfigSetId].title or "Default"
					local configMatch = oneConfig or configName:find(linkMatch, 1, true)

					if skillMatch and itemMatch and configMatch then
						self.controls.buildLoadouts:SetSel(i)
						self.activeLoadout = i - 1
						return treeList, itemList, skillList, configList
					end
				end
				break
			end
		end
	end

	self.activeLoadout = 1
	self.controls.buildLoadouts:SetSel(self.activeLoadout)
	return treeList, itemList, skillList, configList
end

function buildMode:NewLoadout(loadoutName)
	local newSpec = new("PassiveSpec"):PassiveSpec(self, latestTreeVersion)
	local newItemSet = self.itemsTab:NewItemSet(#self.itemsTab.itemSets + 1, loadoutName)
	local newSkillSet = self.skillsTab:NewSkillSet(#self.skillsTab.skillSets + 1, loadoutName)
	local newConfigSet = self.configTab:NewConfigSet(#self.configTab.configSets + 1, loadoutName)

	newSpec.title = loadoutName
	t_insert(self.treeTab.specList, newSpec)
	self:SyncLoadouts() -- Sync loadouts to update the dropdown with the new loadout and select it
	self:SetActiveLoadout(self:GetLoadoutByName(loadoutName))

	self.modFlag = true
end

function buildMode:CopyLoadout(copyLoadoutName, loadoutName)
	local loadout = self:GetLoadoutByName(copyLoadoutName)
	if not loadout then return end

	local newSpec = self.treeTab:CopyTree(loadout.specId, loadoutName)
	local newItemSet = self.itemsTab:CopyItemSet(loadout.itemSetId or 1, loadoutName)
	local newSkillSet = self.skillsTab:CopySkillSet(loadout.skillSetId or 1, loadoutName)
	local newConfigSet = self.configTab:CopyConfigSet(loadout.configSetId or 1, loadoutName)

	local copyLoadout = self:GetLoadoutByName(loadoutName)
	self:SetActiveLoadout(copyLoadout)

	self.modFlag = true
	return newSpec, newItemSet, newSkillSet, newConfigSet
end

function buildMode:CustomLoadout(specId, itemSetId, skillSetId, configSetId, name)
	local newSpec
	if specId == -1 then
		newSpec = new("PassiveSpec"):PassiveSpec(self, latestTreeVersion)
		newSpec.id = #self.treeTab.specList + 1
		t_insert(self.treeTab.specList, newSpec)
	else
		newSpec = self.treeTab:CopyTree(specId, name)
	end
	newSpec.title = name

	local newItemSet
	if itemSetId == -1 then
		newItemSet = self.itemsTab:NewItemSet(#self.itemsTab.itemSets + 1, name)
	else
		newItemSet = self.itemsTab:CopyItemSet(itemSetId, name)
	end

	local newSkillSet
	if skillSetId == -1 then
		newSkillSet = self.skillsTab:NewSkillSet(#self.skillsTab.skillSets + 1, name)
	else
		newSkillSet = self.skillsTab:CopySkillSet(skillSetId, name)
	end
	newSkillSet.title = name

	local newConfigSet
	if configSetId == -1 then
		newConfigSet = self.configTab:NewConfigSet(#self.configTab.configSets + 1, name)
	else
		newConfigSet = self.configTab:CopyConfigSet(configSetId, name)
	end

	local customLoadout = self:GetLoadoutByName(name)
	self:SetActiveLoadout(customLoadout)

	self.modFlag = true
	return newSpec, newItemSet, newSkillSet, newConfigSet
end

function buildMode:DeleteLoadout(loadoutName, nextLoadoutName)
	local function reverseLookup(setOrderList, value)
		for id, set in ipairs(setOrderList) do
			if set == value then
				return id
			end
		end
		return nil
	end

	local loadout = self:GetLoadoutByName(loadoutName)
	if loadout.specId then
		t_remove(self.treeTab.specList, loadout.specId)
	end
	if loadout.itemSetId and #self.itemsTab.itemSetOrderList > 1 then
		local index = reverseLookup(self.itemsTab.itemSetOrderList, loadout.itemSetId)
		self.itemsTab:DeleteItemSet(loadout.itemSetId, index)
	end
	if loadout.skillSetId and #self.skillsTab.skillSetOrderList > 1 then
		local index = reverseLookup(self.skillsTab.skillSetOrderList, loadout.skillSetId)
		self.skillsTab:DeleteSkillSet(loadout.skillSetId, index)
	end
	if loadout.configSetId and #self.configTab.configSetOrderList > 1 then
		local index = reverseLookup(self.configTab.configSetOrderList, loadout.configSetId)
		self.configTab:DeleteConfigSet(loadout.configSetId, index)
	end
	self.modFlag = true

	local nextLoadout = self:GetLoadoutByName(nextLoadoutName)
	self:SetActiveLoadout(nextLoadout)
end

function buildMode:RenameLoadout(oldName, newName)
	local loadout = self:GetLoadoutByName(oldName)
	if loadout.specId then
		self.treeTab.specList[loadout.specId].title = newName
		self.treeTab.modFlag = true
	end
	if loadout.itemSetId then
		self.itemsTab:RenameItemSet(loadout.itemSetId, newName)
	end
	if loadout.skillSetId then
		self.skillsTab:RenameSkillSet(loadout.skillSetId, newName)
	end
	if loadout.configSetId then
		self.configTab:RenameConfigSet(loadout.configSetId, newName)
	end
	self.modFlag = true
end

function buildMode:GetLoadoutByName(loadoutName)
	-- item, skill, and config sets have identical structure
	-- return id as soon as it's found
	local function findSetId(setOrderList, value, sets, setSpecialLinks)
		for _, setOrder in ipairs(setOrderList) do
			if value == (sets[setOrder].title or "Default") then
				return setOrder
			else
				local linkMatch = string.match(value, "%{(%w+)%}")
				if linkMatch then
					return setSpecialLinks[linkMatch]["setId"]
				end
			end
		end
		return nil
	end

	-- trees have a different structure with id/name pairs
	-- return id as soon as it's found
	local function findNamedSetId(treeList, value, setSpecialLinks)
		for id, spec in ipairs(treeList) do
			if value == spec then
				return id
			else
				local linkMatch = string.match(value, "%{(%w+)%}")
				if linkMatch then
					return setSpecialLinks[linkMatch]["setId"]
				end
			end
		end
		return nil
	end

	local oneSkill = self.skillsTab and #self.skillsTab.skillSetOrderList == 1
	local oneItem = self.itemsTab and #self.itemsTab.itemSetOrderList == 1
	local oneConfig = self.configTab and #self.configTab.configSetOrderList == 1

	local specId = findNamedSetId(self.treeTab:GetSpecList(), loadoutName, self.treeListSpecialLinks)
	local itemId = oneItem and self.itemsTab.itemSetOrderList[1] or findSetId(self.itemsTab.itemSetOrderList, loadoutName, self.itemsTab.itemSets,
		self.itemListSpecialLinks)
	local skillId = oneSkill and self.skillsTab.skillSetOrderList[1] or findSetId(self.skillsTab.skillSetOrderList, loadoutName, self.skillsTab.skillSets,
		self.skillListSpecialLinks)
	local configId = oneConfig and self.configTab.configSetOrderList[1] or findSetId(self.configTab.configSetOrderList, loadoutName, self.configTab.configSets,
		self.configListSpecialLinks)

	if not specId and not itemId and not skillId and not configId then
		return nil
	end

	return {
		specId = specId,
		itemSetId = itemId,
		skillSetId = skillId,
		configSetId = configId
	}
end

function buildMode:SetActiveLoadout(loadout)
	if not loadout then
		return
	end

	local newSpecId, newItemId, newSkillId, newConfigId = loadout.specId, loadout.itemSetId, loadout.skillSetId,
		loadout.configSetId
	if newSpecId == nil then
		return
	end

	if newSpecId ~= self.treeTab.activeSpec then
		self.treeTab:SetActiveSpec(newSpecId, true)
	end
	if newItemId ~= self.itemsTab.activeItemSetId then
		self.itemsTab:SetActiveItemSet(newItemId, true)
	end
	if newSkillId ~= self.skillsTab.activeSkillSetId then
		self.skillsTab:SetActiveSkillSet(newSkillId, true)
	end
	if newConfigId ~= self.configTab.activeConfigSetId then
		self.configTab:SetActiveConfigSet(newConfigId, false, true)
	end
	self:SyncLoadouts()
end

function buildMode:ReorderLoadout(oldIndex, newIndex)
	if not oldIndex or not newIndex then return end
	if oldIndex == newIndex then return end

	if oldIndex <= 0 or newIndex < 0 or oldIndex > #self.treeTab.specList or newIndex > #self.treeTab.specList or newIndex > #self.loadoutsList then
		return
	end

	local activeTitle = self.treeTab.specList[self.treeTab.activeSpec].title or "Default"

	-- if loadoutsList is the same size as specList, just reorder the specList
	if #self.treeTab.specList - #self.loadoutsList == 0 then
		local movedSpec = t_remove(self.treeTab.specList, oldIndex)
		t_insert(self.treeTab.specList, newIndex, movedSpec)

		self.modFlag = true
		self:SetActiveLoadout(self:GetLoadoutByName(activeTitle))
		return
	end

	-- if loadoutsList contains filtered specs, we'll rebuild the specList to match the order of the loadoutsList
	local oldSet = {}
	for _, v in ipairs(self.loadoutsList) do
		oldSet[v] = true
	end

	local newSpecList = {}
	local idx = 1
	for i = 1, #self.treeTab.specList do
		if oldSet[self.treeTab.specList[i]] then
			newSpecList[i] = self.loadoutsList[idx]
			idx = idx + 1
		else
			newSpecList[i] = self.treeTab.specList[i]
		end
	end

	self.treeTab.specList = newSpecList

	self.modFlag = true
	self:SetActiveLoadout(self:GetLoadoutByName(activeTitle))
end

function buildMode:EstimatePlayerProgress()
	if self.spec then
		local PointsUsed, AscUsed, SecondaryAscUsed, socketsUsed, weaponSet1Used, weaponSet2Used = self.spec:CountAllocNodes()
		local extra = self.calcsTab.mainOutput and self.calcsTab.mainOutput.ExtraPoints or 0
		local maxWeaponSets = self.maxWeaponSets
		local extraWeaponSets = self.calcsTab.mainOutput and self.calcsTab.mainOutput.PassivePointsToWeaponSetPoints or 0
		local usedMax, ascMax, secondaryAscMax, level, act = 99 + maxWeaponSets + extra, 8, 8, 1, 0

		repeat
			act = act + 1
			level = m_min(m_max(PointsUsed + 1 -  self.acts[act].questPoints - extra - m_min(weaponSet1Used, weaponSet2Used), self.acts[act].level), 100)
		until act == self.maxActs or level <= self.acts[act + 1].level

		if self.characterLevelAutoMode and self.characterLevel ~= level then
			self.characterLevel = level
			self.controls.characterLevel:SetText(self.characterLevel)
			self.configTab:BuildModList()
		end

		-- Ascendancy points for lab
		-- this is a recommendation for beginners who are using Path of Building for the first time and trying to map out progress in PoB
		local labSuggest = level < 33 and ""
			or level < 55 and "\nLabyrinth: Normal Lab"
			or level < 68 and "\nLabyrinth: Cruel Lab"
			or level < 75 and "\nLabyrinth: Merciless Lab"
			or level < 90 and "\nLabyrinth: Uber Lab"
			or ""

		local normalPassives = PointsUsed - m_min(weaponSet1Used, weaponSet2Used)
		if normalPassives > usedMax then InsertIfNew(self.controls.warnings.lines, localisation:Text("ui.build.warning.estimate_player_progress")) end
		if AscUsed > ascMax then InsertIfNew(self.controls.warnings.lines, localisation:Text("ui.build.warning.estimate_player_progress_2")) end
		if SecondaryAscUsed > secondaryAscMax then InsertIfNew(self.controls.warnings.lines, localisation:Text("ui.build.warning.estimate_player_progress_3")) end

		-- if you are using more than maxWeaponSets + extraWeaponSets, you are using too many weapon sets
		local warningsWeaponSet = false
		if weaponSet1Used > (maxWeaponSets + extraWeaponSets) then
			warningsWeaponSet = true
			InsertIfNew(self.controls.warnings.lines, localisation:Text("ui.build.warning.estimate_player_progress_4", { value = math.abs((maxWeaponSets + extraWeaponSets) - weaponSet1Used) }))
		end
		if weaponSet2Used > (maxWeaponSets + extraWeaponSets) then
			warningsWeaponSet = true
			InsertIfNew(self.controls.warnings.lines, localisation:Text("ui.build.warning.estimate_player_progress_5", { value = math.abs((maxWeaponSets + extraWeaponSets) - weaponSet2Used) }))
		end

		if not warningsWeaponSet and weaponSet1Used ~= weaponSet2Used then
			-- The set with fewer allocated points is the one with points to
			-- spare, since a node allocated in both sets is only paid for once.
			InsertIfNew(self.controls.warnings.lines, localisation:Text("ui.build.warning.estimate_player_progress_6", { value = math.abs(weaponSet2Used - weaponSet1Used), value_2 = ((weaponSet1Used < weaponSet2Used and 1) or 2) }))
		end

		self.Act = act == self.maxActs and "Endgame" or "Act " .. act

		self.controls.pointDisplay.str = string.format(
			"%s%3d / %3d %s%2d / %2d %s%2d / %2d   %s%d / %d",
			normalPassives > usedMax and colorCodes.NEGATIVE or "^7",
			normalPassives, usedMax,
			colorCodes.NEGATIVE,
			weaponSet1Used, maxWeaponSets + extraWeaponSets,
			colorCodes.POSITIVE,
			weaponSet2Used, maxWeaponSets + extraWeaponSets,
			AscUsed > ascMax and colorCodes.NEGATIVE or "^7",
			AscUsed, ascMax
		)
		self.controls.pointDisplay.req = string.format(
			"Required Level: %d\nEstimated Progress:\nAct: %s\nExtra Skillpoints: %d%s",
			level, self.Act, extra, labSuggest
		)
	end
end

function buildMode:CanExit(mode)
	if not self.unsaved then
		return true
	end
	self:OpenSavePopup(mode)
	return false
end

function buildMode:Shutdown()
	if launch.devMode and (not main.disableDevAutoSave) and self.targetVersion and not self.abortSave then
		if self.dbFileName then
			self:SaveDBFile()
		elseif self.unsaved then
			self.dbFileName = main.buildPath.."~~temp~~.xml"
			self.buildName = "~~temp~~"
			self.dbFileSubPath = ""
			self:SaveDBFile()
		end
	end
	self.abortSave = nil

	self.savers = nil
end

function buildMode:GetArgs()
	return self.dbFileName, self.buildName
end

function buildMode:CloseBuild()
	main:SetWindowTitleSubtext()
	main:SetMode("LIST", self.dbFileName and self.buildName, self.dbFileSubPath)
end

function buildMode:Load(xml, fileName)
	self.targetVersion = xml.attrib.targetVersion or legacyTargetVersion
	if xml.attrib.viewMode then
		self.viewMode = xml.attrib.viewMode
	end
	self.characterLevel = m_max(1 ,m_min(100, tonumber(xml.attrib.level) or 1))
	self.characterLevelAutoMode = xml.attrib.characterLevelAutoMode == "true"
	self.mainSocketGroup = tonumber(xml.attrib.mainSkillIndex) or tonumber(xml.attrib.mainSocketGroup) or 1
	wipeTable(self.spectreList)
	wipeTable(self.beastList)
	for _, child in ipairs(xml) do
		if child.elem == "Spectre" then
			if child.attrib.id and data.minions[child.attrib.id] then
				t_insert(self.spectreList, child.attrib.id)
			end
		elseif child.elem == "BeastCompanion" then
			if child.attrib.id and data.minions[child.attrib.id] then
				t_insert(self.beastList, child.attrib.id)
			end
		elseif child.elem == "TimelessData" then
			self.timelessData.jewelType = {
				id = tonumber(child.attrib.jewelTypeId)
			}
			self.timelessData.conquerorType = {
				id = tonumber(child.attrib.conquerorTypeId)
			}
			self.timelessData.devotionVariant1 = tonumber(child.attrib.devotionVariant1) or 1
			self.timelessData.devotionVariant2 = tonumber(child.attrib.devotionVariant2) or 1
			self.timelessData.jewelSocket = {
				id = tonumber(child.attrib.jewelSocketId)
			}
			self.timelessData.fallbackWeightMode = {
				idx = tonumber(child.attrib.fallbackWeightModeIdx)
			}
			self.timelessData.socketFilter = child.attrib.socketFilter == "true"
			self.timelessData.socketFilterDistance = tonumber(child.attrib.socketFilterDistance) or 0
			self.timelessData.searchList = child.attrib.searchList
			self.timelessData.searchListFallback = child.attrib.searchListFallback
		end
	end
end

function buildMode:Save(xml)
	xml.attrib = {
		targetVersion = self.targetVersion,
		viewMode = self.viewMode,
		level = tostring(self.characterLevel),
		className = self.spec.curClassName,
		ascendClassName = self.spec.curAscendClassName,
		mainSocketGroup = tostring(self.mainSocketGroup),
		characterLevelAutoMode = tostring(self.characterLevelAutoMode)
	}
	for _, id in ipairs(self.spectreList) do
		t_insert(xml, { elem = "Spectre", attrib = { id = id } })
	end
	for _, id in ipairs(self.beastList) do
		t_insert(xml, { elem = "BeastCompanion", attrib = { id = id } })
	end
	local addedStatNames = { }
	for index, statData in ipairs(self.displayStats) do
		if not statData.flag or self.calcsTab.mainEnv.player.mainSkill.activeEffect.statSet.skillFlags[statData.flag] then
			local statName = statData.stat and statData.stat..(statData.childStat or "")
			if statName and not addedStatNames[statName] then
				if statData.stat == "SkillDPS" then
					local statVal = self.calcsTab.mainOutput[statData.stat]
					for _, skillData in ipairs(statVal) do
						local triggerStr = ""
						if skillData.trigger and skillData.trigger ~= "" then
							triggerStr = skillData.trigger
						end
						local skillCount = skillData.count or 1
						local lhsString = skillData.name
						if skillCount ~= 1 then
							lhsString = s_format("%g", skillCount).."x "..skillData.name
						end
						t_insert(xml, { elem = "FullDPSSkill", attrib = { stat = lhsString, value = tostring(skillData.dps * skillCount), skillPart = skillData.skillPart or "", source = skillData.source or skillData.trigger or "" } })
					end
					addedStatNames[statName] = true
				else
					local statVal = self.calcsTab.mainOutput[statData.stat]
					if statVal and statData.childStat then
						statVal = statVal[statData.childStat]
					end
					if statVal and (statData.condFunc and statData.condFunc(statVal, self.calcsTab.mainOutput) or true) then
						t_insert(xml, { elem = "PlayerStat", attrib = { stat = statName, value = tostring(statVal) } })
						addedStatNames[statName] = true
					end
				end
			end
		end
	end
	for index, stat in ipairs(self.extraSaveStats) do
		local statVal = self.calcsTab.mainOutput[stat]
		if statVal then
			t_insert(xml, { elem = "PlayerStat", attrib = { stat = stat, value = tostring(statVal) } })
		end
	end
	if self.calcsTab.mainEnv.minion then
		for index, statData in ipairs(self.minionDisplayStats) do
			if statData.stat then
				local statVal = self.calcsTab.mainOutput.Minion[statData.stat]
				if statVal then
					t_insert(xml, { elem = "MinionStat", attrib = { stat = statData.stat, value = tostring(statVal) } })
				end
			end
		end
	end
	local buffs = {
		elem = "Buffs",
		attrib = {
			buffList = self.calcsTab.calcsOutput.BuffList,
			combatList = self.calcsTab.calcsOutput.CombatList,
			curseList = self.calcsTab.calcsOutput.CurseList,
		}
	}
	t_insert(xml, buffs)
	local timelessData = {
		elem = "TimelessData",
		attrib = {
			jewelTypeId = next(self.timelessData.jewelType) and tostring(self.timelessData.jewelType.id),
			conquerorTypeId = next(self.timelessData.conquerorType) and tostring(self.timelessData.conquerorType.id),
			devotionVariant1 = tostring(self.timelessData.devotionVariant1),
			devotionVariant2 = tostring(self.timelessData.devotionVariant2),
			jewelSocketId = next(self.timelessData.jewelSocket) and tostring(self.timelessData.jewelSocket.id),
			fallbackWeightModeIdx = next(self.timelessData.fallbackWeightMode) and tostring(self.timelessData.fallbackWeightMode.idx),
			socketFilter = self.timelessData.socketFilter and "true",
			socketFilterDistance = self.timelessData.socketFilterDistance and tostring(self.timelessData.socketFilterDistance),
			searchList = self.timelessData.searchList and tostring(self.timelessData.searchList),
			searchListFallback = self.timelessData.searchListFallback and tostring(self.timelessData.searchListFallback)
		}
	}
	t_insert(xml, timelessData)
end

function buildMode:ResetModFlags()
	self.modFlag = false
	self.notesTab.modFlag = false
	self.partyTab.modFlag = false
	self.configTab.modFlag = false
	self.treeTab.modFlag = false
	self.treeTab.searchFlag = false
	self.spec.modFlag = false
	self.skillsTab.modFlag = false
	self.itemsTab.modFlag = false
	self.calcsTab.modFlag = false
end

function buildMode:OnFrame(inputEvents)
	-- 计算详情在生成时使用显式文案，切换语言后重新生成缓存，不改动构筑数据。
	if self.displayLanguage ~= localisation.language then
		self.displayLanguage = localisation.language
		self.buildFlag = true
		if self.calcsTab then self.calcsTab.modFlag = true end
	end
	-- Stop at drawing the background if the loaded build needs to be converted
	if not self.targetVersion then
		main:DrawBackground(main.viewPort)
		return
	end

	if self.abortSave and not launch.devMode then
		self:CloseBuild()
	end

	for id, event in ipairs(inputEvents) do
		if event.type == "KeyDown" then
			if event.key == "MOUSE4" then
				if self.unsaved then
					self:OpenSavePopup("LIST")
				else
					self:CloseBuild()
				end
		elseif IsKeyDown("CTRL") then
				if event.key == "i" then
						self.viewMode = "IMPORT"
					self.importTab:SelectControl(self.importTab.controls.importCodeIn)
				elseif event.key == "s" then
					self:SaveDBFile()
					inputEvents[id] = nil
				elseif event.key == "w" then
					if self.unsaved then
						self:OpenSavePopup("LIST")
					else
						self:CloseBuild()
					end
				elseif event.key == "1" then
					self.viewMode = "TREE"
				elseif event.key == "2" then
					self.viewMode = "SKILLS"
				elseif event.key == "3" then
					self.viewMode = "ITEMS"
				elseif event.key == "4" then
					self.viewMode = "CALCS"
				elseif event.key == "5" then
					self.viewMode = "CONFIG"
				elseif event.key == "6" then
					self.viewMode = "NOTES"
				elseif event.key == "7" then
					self.viewMode = "PARTY"
				end
			end
		elseif event.type == "KeyUp" and event.key == "LEFTBUTTON" and self.controls.pointDisplay:IsMouseInBounds() then
			self.spec.allocMode = (self.spec.allocMode + 1) % 3
		end
	end

	-- Consume mouse events for overlay panes before normal input processing
	local cursorX, cursorY = GetCursorPos()
	local breakdown = self.calcsTab.controls.breakdown
	local overlayBreakdown = self.calcsTab.displayPinned and self.calcsTab.displayData
		and self.calcsTab.displayData.calcSection and self.calcsTab.displayData.calcSection.isOverlay
	for i = #inputEvents, 1, -1 do
		local event = inputEvents[i]
		if event then
			if event.type == "KeyDown" and event.key:match("BUTTON") then
				for paneIndex = #self.overlayPanes, 1, -1 do
					local pane = self.overlayPanes[paneIndex]
					if pane.isOverlay and pane:IsMouseInOverlay(cursorX, cursorY) then
						pane:HandleOverlayClick(event.key, cursorX, cursorY)
						inputEvents[i] = nil
						break
					end
				end
				if inputEvents[i] and overlayBreakdown and breakdown:IsMouseOver() then
					self.overlayBreakdownControl = breakdown:OnKeyDown(event.key, event.doubleClick)
					inputEvents[i] = nil
				end
			elseif event.type == "KeyUp" and event.key:match("BUTTON") then
				for _, pane in ipairs(self.overlayPanes) do
					if pane.isOverlay then
						pane:HandleOverlayRelease(event.key)
					end
				end
				if self.overlayBreakdownControl then
					self.overlayBreakdownControl:OnKeyUp(event.key)
					self.overlayBreakdownControl = nil
					inputEvents[i] = nil
				end
			elseif event.type == "KeyUp" and overlayBreakdown and breakdown:IsMouseOver()
				and (breakdown.controls.scrollBar:IsScrollDownKey(event.key) or breakdown.controls.scrollBar:IsScrollUpKey(event.key)) then
				breakdown:OnKeyUp(event.key)
				inputEvents[i] = nil
			end
		end
	end
	self:ProcessControlsInput(inputEvents, main.viewPort)

	self.controls.classDrop:SelByValue(self.spec.curClassId, "classId")
	self.controls.ascendDrop.list = self.controls.classDrop:GetSelValueByKey("ascendancies")
	self.controls.ascendDrop:SelByValue(self.spec.curAscendClassId, "ascendClassId")
	self.controls.ascendDrop:CheckDroppedWidth(true)
	-- // secondaryAscend dropdown hidden away until we learn more
	--self.controls.secondaryAscendDrop.list = {{label = "None", ascendClassId = 0}, {label = "Warden", ascendClassId = 1}, {label = "Warlock", ascendClassId = 2}, {label = "Primalist", ascendClassId = 3}}
	--self.controls.secondaryAscendDrop:SelByValue(self.spec.curSecondaryAscendClassId, "ascendClassId")

	if self.buildFlag then
		-- Wipe Global Cache
		wipeGlobalCache()

		-- Rebuild calculation output tables
		self.outputRevision = self.outputRevision + 1
		self.buildFlag = false
		self.calcsTab:BuildOutput()
		if self.controls.breakdown.pinned and self.breakdownInputs then
			self.controls.breakdown:SetBreakdownData()
			self.controls.breakdown:SetBreakdownData(unpack(self.breakdownInputs))
		end
		self:RefreshStatList()
		self.configTab.calcFunc, self.configTab.calcBase = self.calcsTab:GetMiscCalculator()
	end
	if main.showThousandsSeparators ~= self.lastShowThousandsSeparators then
		self:RefreshStatList()
	end
	if main.thousandsSeparator ~= self.lastShowThousandsSeparator then
		self:RefreshStatList()
	end
	if main.decimalSeparator ~= self.lastShowDecimalSeparator then
		self:RefreshStatList()
	end
	-- 窗口标题由原生接口输出，语言变化时也需重新读取职业显示资源。
	if main.showTitlebarName ~= self.lastShowTitlebarName or self.lastTitleLanguage ~= localisation.language then
		self.spec:SetWindowTitleWithBuildClass()
		self.lastTitleLanguage = localisation.language
	end

	-- Update contents of main skill dropdowns
	self:RefreshSkillSelectControls(self.controls, self.mainSocketGroup, "")

	-- Draw contents of current tab
	local sideBarWidth = 312
	local tabViewPort = {
		x = sideBarWidth,
		y = 32,
		width = main.screenW - sideBarWidth,
		height = main.screenH - 32
	}
	if self.viewMode == "IMPORT" then
		self.importTab:Draw(tabViewPort, inputEvents)
	elseif self.viewMode == "NOTES" then
		self.notesTab:Draw(tabViewPort, inputEvents)
	elseif self.viewMode == "PARTY" then
		self.partyTab:Draw(tabViewPort, inputEvents)
	elseif self.viewMode == "CONFIG" then
		self.configTab:Draw(tabViewPort, inputEvents)
	elseif self.viewMode == "TREE" then
		self.treeTab:Draw(tabViewPort, inputEvents)
	elseif self.viewMode == "SKILLS" then
		self.skillsTab:Draw(tabViewPort, inputEvents)
	elseif self.viewMode == "ITEMS" then
		self.itemsTab:Draw(tabViewPort, inputEvents)
	elseif self.viewMode == "CALCS" then
		self.calcsTab:Draw(tabViewPort, inputEvents)
	elseif self.viewMode == "COMPARE" then
		self.compareTab:Draw(tabViewPort, inputEvents)
	end

	-- Draw overlay panes on top of all tab content (last = topmost)
	for _, pane in ipairs(self.overlayPanes) do
		if pane.isOverlay then
			pane:DrawOverlay(main.viewPort, inputEvents)
		end
	end

	self.unsaved = self.modFlag or self.notesTab.modFlag or self.partyTab.modFlag or self.configTab.modFlag or self.treeTab.modFlag or self.treeTab.searchFlag or self.spec.modFlag or self.skillsTab.modFlag or self.itemsTab.modFlag or self.calcsTab.modFlag

	SetDrawLayer(5)

	-- Draw top bar background
	SetDrawColor(0.2, 0.2, 0.2)
	DrawImage(nil, 0, 0, main.screenW, 28)
	SetDrawColor(0.85, 0.85, 0.85)
	DrawImage(nil, 0, 28, main.screenW, 4)
	DrawImage(nil, main.screenW/2 - 2, 0, 4, 28)

	-- Draw side bar background
	SetDrawColor(0.1, 0.1, 0.1)
	DrawImage(nil, 0, 32, sideBarWidth - 4, main.screenH - 32)
	SetDrawColor(0.85, 0.85, 0.85)
	DrawImage(nil, sideBarWidth - 4, 32, 4, main.screenH - 32)


	local hovered = self.controls.statBox and self.controls.statBox.hoveredLine
	self:SetDisplayStat(hovered, false)
	self:DrawControls(main.viewPort)
	if self.controls.breakdown.pinned and self.breakdownInputs and not self.selControl then
		self:SelectControl(self.controls.breakdown)
	end
end

function buildMode:SetDisplayStat(hovered, pin)
	if not hovered or (not pin and self.controls.breakdown.pinned) then
		-- if this is a hover popup, clear when the user moved mouse out of frame
		if not self.controls.breakdown.pinned then
			self:ClearDisplayStat()
		end
		return
	end
	local key = hovered.line.breakdown
	-- user clicked a second time: clear
	if pin and self.controls.breakdown.pinned then
		self:ClearDisplayStat()
		return
		-- avoid being able to pin empty breakdowns
	elseif pin and not self.controls.breakdown.pinned and not key then
		return
	end

	self.sidebarBreakdownData = self:GetSidebarBreakdown(key, hovered.line.modNames, hovered.line.ignoredSections, hovered.line.actorName)
	self.sidebarBreakdownData.x = hovered.x - 1
	self.sidebarBreakdownData.y = hovered.y
	self.sidebarBreakdownData.width = hovered.width
	if hovered.line.breakdownColour then
		self.controls.breakdown.borderColour = hovered.line.breakdownColour
	end
	local breakdownInputs = { self.sidebarBreakdownData, pin, hovered.line.actorName }
	-- avoid rebuilding the sidebar every frame
	if tableDeepEquals(breakdownInputs, self.breakdownInputs) then
		return
	end
	self.breakdownInputs = breakdownInputs
	self.controls.breakdown:SetBreakdownData(unpack(breakdownInputs))
end

function buildMode:ClearDisplayStat()
	self.controls.breakdown:SetBreakdownData()
	self.breakdownInputs = nil
	self.sidebarBreakdownData = nil
end

function buildMode:UpdateClassDropdowns(treeVersion)
	local classes = main.tree[treeVersion or latestTreeVersion].classes
	wipeTable(self.controls.classDrop.list)
	-- Initialise class dropdown
	for classId, class in pairs(classes) do
		local ascendancies = {}
		-- Initialise ascendancy dropdown
		for i = 0, #class.classes do
			local ascendClass = class.classes[i]
			t_insert(ascendancies, {
				label = ascendClass.name,
				labelKey = ascendClass.nameKey,
				ascendClassId = i,
			})
		end
		t_insert(self.controls.classDrop.list, {
			label = class.name,
			labelKey = class.nameKey,
			classId = classId,
			ascendancies = ascendancies,
		})
	end
	table.sort(self.controls.classDrop.list, function(a, b) return a.label < b.label end)
end

-- Opens the game version conversion popup
function buildMode:OpenConversionPopup()
	local controls = { }
	local currentVersion = treeVersions[latestTreeVersion].display
	controls.note = new("LabelControl"):LabelControl(nil, { 0, 20, 0, 16 }, localisation:Label("ui.build.open_conversion_popup.note.label", nil, colorCodes.TIP))
	controls.label = new("LabelControl"):LabelControl(nil, { 0, 110, 0, 16 }, localisation:Label("ui.build.open_conversion_popup.label_2", nil, colorCodes.WARNING))
	controls.convert = new("ButtonControl"):ButtonControl(nil, { -40, 170, 120, 20 }, localisation:Label("ui.build.open_conversion_popup.convert.label", { current_version = currentVersion }), function()
		main:ClosePopup()
		self:Shutdown()
		self:Init(self.dbFileName, self.buildName, nil, true)
	end)
	controls.cancel = new("ButtonControl"):ButtonControl(nil, { 60, 170, 70, 20 }, localisation:Label("ui.build.open_conversion_popup.cancel.label"), function()
		main:ClosePopup()
		self:CloseBuild()
	end)
	main:OpenPopup(580, 200, localisation:Label("ui.build.open_conversion_popup.label"), controls, "convert", nil, "cancel")
end

function buildMode:OpenSavePopup(mode)
	local modeDesc = {
		["LIST"] = localisation:Ref("ui.build.open_save_popup.mode.now"),
		["EXIT"] = localisation:Ref("ui.build.open_save_popup.mode.before_exiting"),
		["UPDATE"] = localisation:Ref("ui.build.open_save_popup.mode.before_updating"),
	}
	local controls = { }
	controls.label = new("LabelControl"):LabelControl(nil, { 0, 20, 0, 16 }, localisation:Label("ui.build.open_save_popup.label_2", { value = modeDesc[mode] }))
	controls.save = new("ButtonControl"):ButtonControl(nil, { -90, 70, 80, 20 }, localisation:Label("ui.build.init.save.label"), function()
		main:ClosePopup()
		self.actionOnSave = mode
		self:SaveDBFile()
	end)
	controls.noSave = new("ButtonControl"):ButtonControl(nil, { 0, 70, 80, 20 }, localisation:Label("ui.build.open_save_popup.no_save.label"), function()
		main:ClosePopup()
		if mode == "LIST" then
			self:CloseBuild()
		elseif mode == "EXIT" then
			Exit()
		elseif mode == "UPDATE" then
			launch:ApplyUpdate(launch.updateAvailable)
		end
	end)
	controls.close = new("ButtonControl"):ButtonControl(nil, { 90, 70, 80, 20 }, localisation:Label("ui.build.open_conversion_popup.cancel.label"), function()
		main:ClosePopup()
	end)
	main:OpenPopup(300, 100, localisation:Label("ui.build.open_save_popup.label"), controls)
end

function buildMode:OpenSaveAsPopup()
	local newFileName, newBuildName
	local controls = { }
	local function updateBuildName()
		local buf = controls.edit.buf
		newFileName = main.buildPath..controls.folder.subPath..buf..".xml"
		newBuildName = buf
		controls.save.enabled = false
		if buf:match("%S") then
			local out = io.open(newFileName, "r")
			if out then
				out:close()
			else
				controls.save.enabled = true
			end
		end
	end
	controls.label = new("LabelControl"):LabelControl(nil, { 0, 20, 0, 16 }, localisation:Label("ui.build.open_save_as_popup.label"))
	controls.edit = new("EditControl"):EditControl(nil, { 0, 40, 450, 20 },
	(self.buildName or self.dbFileName):gsub("[\\/:%*%?\"<>|%c]", "-"), nil, "\\/:%*%?\"<>|%c", 100, function(buf)
		updateBuildName()
	end)
	controls.folderLabel = new("LabelControl"):LabelControl({ "TOPLEFT", nil, "TOPLEFT" }, { 10, 70, 0, 16 }, localisation:Label("ui.build.open_save_as_popup.folder_label.label"))
	controls.newFolder = new("ButtonControl"):ButtonControl({ "TOPLEFT", nil, "TOPLEFT" }, { 100, 67, 94, 20 }, localisation:Label("ui.build.open_save_as_popup.new_folder.label"), function()
		main:OpenNewFolderPopup(main.buildPath..controls.folder.subPath, function(newFolderName)
			if newFolderName then
				controls.folder:OpenFolder(newFolderName)
			end
		end)
	end)
	controls.folder = new("FolderListControl"):FolderListControl(nil, { 0, 115, 450, 100 }, self.dbFileSubPath, function(subPath)
		updateBuildName()
	end)
	controls.save = new("ButtonControl"):ButtonControl(nil, { -45, 225, 80, 20 }, localisation:Label("ui.build.init.save.label"), function()
		main:ClosePopup()
		self.dbFileName = newFileName
		self.buildName = newBuildName
		self.dbFileSubPath = controls.folder.subPath
		self:SaveDBFile()
		self.spec:SetWindowTitleWithBuildClass()
	end)
	controls.close = new("ButtonControl"):ButtonControl(nil, { 45, 225, 80, 20 }, localisation:Label("ui.build.open_conversion_popup.cancel.label"), function()
		main:ClosePopup()
		self.actionOnSave = nil
	end)

	if self.dbFileName or self.buildName then
		controls.save.enabled = self.dbFileName or self.buildName
		updateBuildName()
	else
		controls.save.enabled = false
	end

	main:OpenPopup(470, 255, self.dbFileName and localisation:Label("ui.build.open_save_as_popup.label_3") or localisation:Label("ui.build.open_save_as_popup.label_2"), controls, "save", "edit", "close")
end

-- Open the spectre library popup
function buildMode:OpenSpectreLibrary(library)
	local recommendedBeastList, recommendedSpectreList, popularList = {}, {}, {}
	local beastList, humanoidList, eldritchList, constructList, demonList, undeadList = {}, {}, {}, {}, {}, {}
	local destList = { }
	local sourceList = { }
	local controls = { }
	for id in pairs(self.data.spectres) do
		if self.data.minions[id].monsterCategory == "Beast" then
			t_insert(beastList, id)
		elseif self.data.minions[id].monsterCategory == "Humanoid" then
			t_insert(humanoidList, id)
		elseif self.data.minions[id].monsterCategory == "Eldritch" then
			t_insert(eldritchList, id)
		elseif self.data.minions[id].monsterCategory == "Construct" then
			t_insert(constructList, id)
		elseif self.data.minions[id].monsterCategory == "Demon" then
			t_insert(demonList, id)
		elseif self.data.minions[id].monsterCategory == "Undead" then
			t_insert(undeadList, id)
		end
		if self.data.minions[id].extraFlags and self.data.minions[id].extraFlags.recommendedSpectre then
			t_insert(recommendedSpectreList, id)
		end
		if self.data.minions[id].extraFlags and self.data.minions[id].extraFlags.recommendedBeast then
			t_insert(recommendedBeastList, id)
		end
	end
	if library == "beast" then
		destList = copyTable(self.beastList)
		popularList = recommendedBeastList
	else
		destList = copyTable(self.spectreList)
		popularList = recommendedSpectreList
	end
	local monsterTypeSort = {
		Beast = true,
		Humanoid = true,
		Eldritch = true,
		Construct = true,
		Demon = true,
		Undead = true,
		recommendedList = false,
	}
	local function buildSourceList(library, sourceList)
		wipeTable(sourceList)
		if library == "beast" then
			if monsterTypeSort["Beast"] then
				for _, id in ipairs(beastList) do
					table.insert(sourceList, id)
				end
			end
		else
			local monsterCategories = {
				{ key = "Beast", list = beastList },
				{ key = "Humanoid", list = humanoidList },
				{ key = "Eldritch", list = eldritchList },
				{ key = "Construct", list = constructList },
				{ key = "Demon", list = demonList },
				{ key = "Undead", list = undeadList },
			}
			for _, category in ipairs(monsterCategories) do
				if monsterTypeSort[category.key] then
					for _, id in ipairs(category.list) do
						table.insert(sourceList, id)
					end
				end
			end
		end
		-- Apply 'recommended' filter if checkbox is off
		if not monsterTypeSort.recommendedList then
			local allowed = {}
			for _, id in ipairs(popularList) do
				allowed[id] = true
			end
			for i = #sourceList, 1, -1 do
				if not allowed[sourceList[i]] then
					table.remove(sourceList, i)
				end
			end
		end
	end

	buildSourceList(library, sourceList)

	local function UpdateMinionDisplay(selected)
		self.lastSelectedMinion = selected
		local minion = self.data.minions[selected]
		local gemLevel = m_max(controls.minionGemLevel.buf,1)
		local baseLife = self.data.monsterAllyLifeTable[m_min(gemLevel * 2, 100)]
		local totalLife = baseLife * minion.life
		local totalES
		if minion.energyShield then
			totalES = totalLife * minion.energyShield
			totalLife = totalLife - (totalLife * minion.energyShield)
		else
			totalES = 0
		end
		local totalArmour = self.data.monsterArmourTable[m_min(gemLevel * 2, 100)]
		local totalEvasion = self.data.monsterEvasionTable[m_min(gemLevel * 2, 100)]
		if minion.armour then
			totalArmour = (1 + minion.armour) * totalArmour
		end
		if minion.evasion then
			totalEvasion = (1 + minion.evasion) * totalEvasion
		end
		-- Check if minion.modList contains a mod for BlockChance and use it for blockLabel
		local blockChance = 0
		if minion.modList then
			for _, mod in ipairs(minion.modList) do
				if mod.name == "BlockChance" then
					blockChance = mod.value
					break
				end
			end
		end
		local spawnLocationList = {}
		if minion.spawnLocation then
			for _, spawn in ipairs(minion.spawnLocation) do
				t_insert(spawnLocationList, spawn)
			end
		end
		local movementSpeed = minion.baseMovementSpeed / 10 .. " m/s"
		local fireResist = library == "beast" and minion.companionFireResist or minion.fireResist
		local coldResist = library == "beast" and minion.companionColdResist or minion.coldResist
		local lightningResist = library == "beast" and minion.companionLightningResist or minion.lightningResist
		local chaosResist = library == "beast" and minion.companionChaosResist or minion.chaosResist
		controls.minionNameLabel.minion = minion
		controls.lifeLabel.lifeValue = round(totalLife)
		controls.energyshieldLabel.energyShieldValue = round(totalES)
		controls.armourLabel.armourValue = round(totalArmour)
		controls.blockLabel.blockValue = blockChance
		controls.evasionLabel.evasionValue = round(totalEvasion)
		controls.spawnLocations.list = spawnLocationList
		controls.resistsLabel.resistsValue = (
			colorCodes.FIRE..fireResist.."^7 / "..
			colorCodes.COLD..coldResist.."^7 / "..
			colorCodes.LIGHTNING..lightningResist.."^7 / "..
			colorCodes.CHAOS..chaosResist)
		controls.movementSpeedLabel.movementSpeedValue = movementSpeed
	end

	local label = localisation:Ref(library == "beast" and "minion.library.beasts" or "minion.library.spectres")
	controls.list = new("MinionListControl"):MinionListControl(nil, { -230, 40, 210, 270 }, self.data, destList, nil, localisation:Label("minion.library.in_build", { kind = label }), library == "beast")
	controls.list.OnSelect = function()
			UpdateMinionDisplay(controls.list.selValue)
	end
	controls.source = new("MinionSearchListControl"):MinionSearchListControl(nil, { 0, 80, 210, 230 }, self.data, sourceList, controls.list, localisation:Label("minion.library.available", { kind = label }), library == "beast")
	controls.source.OnSelect = function()
			UpdateMinionDisplay(controls.source.selValue)
	end

	local function monsterTypeCheckboxChange(name)
		return function(state)
			monsterTypeSort[name] = state
			buildSourceList(library, sourceList)
			controls.source.unfilteredList = copyTable(sourceList)
			controls.source:ListFilterChanged(controls.source.controls.searchText.buf, controls.source.controls.searchModeDropDown.selIndex)
			controls.source:sortSourceList()
		end
	end
	local function getMonsterTypeImages()
		local images = {}
		for file, fileInfo in pairs((self.data.assets and self.data.assets.ddsCoords) or { }) do
			local assetData = { }
			assetData.handle = NewImageHandle()
			assetData.handle:Load("Assets/" .. file, "CLAMP")
			assetData.width, assetData.height = assetData.handle:ImageSize()
			for name, positionData in pairs(fileInfo) do
				local asset = {
					found = assetData.width > 0,
					handle = assetData.handle,
					width = assetData.width,
					height = assetData.height,
				}
				images[name] = applyDDSCoords(asset, positionData, assetData.width, assetData.height)
			end
		end
		return images
	end
	self.monsterImages = getMonsterTypeImages()

	local monsterTypeCheckbox = {
		{ name = "Beast", x = 0 },
		{ name = "Humanoid", x = 37 },
		{ name = "Eldritch", x = 74 },
		{ name = "Construct", x = 111 },
		{ name = "Demon", x = 148 },
		{ name = "Undead", x = 184 },
	}
	for _, monsterType in ipairs(monsterTypeCheckbox) do
		local controlName = "sortMonsterCheckbox" .. monsterType.name
		local checkbox = new("CheckBoxControl"):CheckBoxControl({ "TOPLEFT", controls.source, "BOTTOMLEFT" }, { monsterType.x, 30, 26, 26 }, "", monsterTypeCheckboxChange(monsterType.name), function() return localisation:Term("monster_category", monsterType.name, monsterType.name) end, true)
		checkbox:SetCheckImage(self.monsterImages[monsterType.name])
		checkbox.shown = library ~= "beast"
		controls[controlName] = checkbox
	end
	local libraryName = localisation:Ref(library == "beast" and "minion.library.beast" or "minion.library.spectre")
	controls.sortMonsterCheckboxShowAll = new("CheckBoxControl"):CheckBoxControl({ "TOPLEFT", controls.source, "BOTTOMLEFT" }, { 153, 2, 26, 26 }, "", monsterTypeCheckboxChange("recommendedList"), localisation:Label("ui.build.check_box_control.tooltip", { value = libraryName }), false)
	controls.showAllLabel = new("LabelControl"):LabelControl({ "RIGHT", controls.sortMonsterCheckboxShowAll, "LEFT" }, { -5, 0, 0, 16 }, localisation:Label("ui.build.open_spectre_library.show_all_label.label", { value = libraryName }))
	controls.save = new("ButtonControl"):ButtonControl(nil, { -45, 420, 80, 20 }, localisation:Label("ui.build.init.save.label"), function()
		if library == "beast" then
			self.beastList = destList
		else
			self.spectreList = destList
		end
		self.modFlag = true
		self.buildFlag = true
		main:ClosePopup()
	end)
	controls.cancel = new("ButtonControl"):ButtonControl(nil, { 45, 420, 80, 20 }, localisation:Label("ui.build.open_conversion_popup.cancel.label"), function()
		main:ClosePopup()
	end)
	local spectrePopup
	if library == "beast" then
		spectrePopup = main:OpenPopup(720, 450, localisation:Label("ui.build.open_spectre_library.spectre_popup.label"), controls)
		controls.noteLine1 = new("LabelControl"):LabelControl({ "TOP", controls.save, "BOTTOM" }, { 45, -60, 0, 16 }, localisation:Label("ui.build.open_spectre_library.note_line1.label"))
		controls.noteLine2 = new("LabelControl"):LabelControl({ "TOP", controls.save, "BOTTOM" }, { 45, -42, 0, 16 }, localisation:Label("ui.build.open_spectre_library.note_line2.label"))
	else
		spectrePopup = main:OpenPopup(720, 450, localisation:Label("ui.build.open_spectre_library.spectre_popup.label_2"), controls)
		controls.noteLine1 = new("LabelControl"):LabelControl({ "TOP", controls.save, "BOTTOM" }, { 45, -60, 0, 16 }, localisation:Label("ui.build.open_spectre_library.note_line1.label_2"))
		controls.noteLine2 = new("LabelControl"):LabelControl({ "TOP", controls.save, "BOTTOM" }, { 45, -42, 0, 16 }, localisation:Label("ui.build.open_spectre_library.note_line2.label_2"))
	end
	spectrePopup:SelectControl(spectrePopup.controls.source.controls.searchText)

	controls.minionNameLabel = new("LabelControl"):LabelControl({ "TOP", controls.source, "TOP" }, { 230, -50, 0, 18 }, localisation:Label("ui.build.open_spectre_library.minion_name_label.label"))
	controls.minionNameLabel.Draw = function(self, view)
		local xPos, yPos = self:GetPos()
		SetDrawColor(colorCodes.RELIC)
		DrawImage(nil, xPos-78, yPos-10, 245, 38)
		SetDrawColor(0,0,0,1)
		DrawImage(nil, xPos-76, yPos-8, 241, 34)
		SetDrawColor(1, 1, 1)
		DrawString(xPos + 45, yPos, "CENTER_X", 18, "VAR BOLD", self.minion and ("^7" .. localisation:Field(self.minion, 'name')) or localisation:Text("ui.build.open_spectre_library.minion_name_label_draw.message"))
	end
	controls.minionGemLevelLabel = new("LabelControl"):LabelControl({ "BOTTOM", controls.minionNameLabel, "TOP" }, { 24, 271, 0, 16 }, localisation:Label("ui.build.open_spectre_library.minion_gem_level_label.label"))
	controls.minionGemLevel = new("EditControl"):EditControl({ "LEFT", controls.minionGemLevelLabel, "RIGHT" }, { 4, 0, 60, 20 }, 20, nil, "%D", 3, function()
		if self.lastSelectedMinion then
			UpdateMinionDisplay(self.lastSelectedMinion)
		end
	end)
	controls.lifeLabel = new("LabelControl"):LabelControl({ "TOP", controls.source, "TOP" }, { 170, -9, 0, 16 }, localisation:Label("ui.build.open_spectre_library.life_label.label", nil, colorCodes.LIFE))
	controls.lifeLabel.Draw = function(self, view)
		local xPos, yPos = self:GetPos()
		local boxWidth, boxHeight = 120, 50
		local labelWidth = DrawStringWidth(16, "VAR BOLD", localisation:Text("ui.build.open_spectre_library.label_width.message_5"))
		SetDrawColor(colorCodes.LIFE)
		DrawImage(nil, xPos + (labelWidth / 2) - (boxWidth / 2), yPos - 3, boxWidth, boxHeight)
		SetDrawColor(0, 0, 0, 1)
		DrawImage(nil, xPos + (labelWidth / 2) - (boxWidth / 2) + 2, yPos - 1, boxWidth - 4, boxHeight - 4)
		SetDrawColor(colorCodes.LIFE)
		DrawImage(nil, xPos + (labelWidth / 2) - (boxWidth / 2), yPos + 16, boxWidth, 2)
		SetDrawColor(1, 1, 1)
		DrawString(xPos + (labelWidth / 2), yPos, "CENTER_X", 16, "VAR BOLD", localisation:Text("ui.build.open_spectre_library.life_label_draw.message"))
		if self.lifeValue then
			DrawString(xPos + (labelWidth / 2), yPos + 24, "CENTER_X", 16, "VAR", self.lifeValue)
		end
	end
	controls.energyshieldLabel = new("LabelControl"):LabelControl({ "TOP", controls.source, "TOP" }, { 293, -9, 0, 16 }, localisation:Label("ui.build.open_spectre_library.energyshield_label.label", nil, colorCodes.ES))
	controls.energyshieldLabel.Draw = function(self, view)
		local xPos, yPos = self:GetPos()
		local boxWidth, boxHeight = 120, 50
		local labelWidth = DrawStringWidth(16, "VAR BOLD", localisation:Text("ui.build.open_spectre_library.label_width.message_3"))
		SetDrawColor(colorCodes.ES)
		DrawImage(nil, xPos + (labelWidth / 2) - (boxWidth / 2), yPos - 3, boxWidth, boxHeight)
		SetDrawColor(0, 0, 0, 1)
		DrawImage(nil, xPos + (labelWidth / 2) - (boxWidth / 2) + 2, yPos - 1, boxWidth - 4, boxHeight - 4)
		SetDrawColor(colorCodes.ES)
		DrawImage(nil, xPos + (labelWidth / 2) - (boxWidth / 2), yPos + 16, boxWidth, 2)
		SetDrawColor(1, 1, 1)
		DrawString(xPos + (labelWidth / 2), yPos, "CENTER_X", 16, "VAR BOLD", localisation:Text("ui.build.open_spectre_library.energyshield_label_draw.message"))
		if self.energyShieldValue then
			DrawString(xPos + (labelWidth / 2), yPos + 24, "CENTER_X", 16, "VAR", self.energyShieldValue)
		end
	end
	controls.armourLabel = new("LabelControl"):LabelControl({ "TOP", controls.lifeLabel, "TOP" }, { 0, 54, 0, 16 }, localisation:Label("ui.build.open_spectre_library.armour_label.label", nil, colorCodes.ARMOUR))
	controls.armourLabel.Draw = function(self, view)
		local xPos, yPos = self:GetPos()
		local boxWidth, boxHeight = 120, 50
		local labelWidth = DrawStringWidth(16, "VAR BOLD", localisation:Text("ui.build.open_spectre_library.label_width.message"))
		SetDrawColor(colorCodes.NORMAL)
		DrawImage(nil, xPos + (labelWidth / 2) - (boxWidth / 2), yPos - 3, boxWidth, boxHeight)
		SetDrawColor(0, 0, 0, 1)
		DrawImage(nil, xPos + (labelWidth / 2) - (boxWidth / 2) + 2, yPos - 1, boxWidth - 4, boxHeight - 4)
		SetDrawColor(colorCodes.NORMAL)
		DrawImage(nil, xPos + (labelWidth / 2) - (boxWidth / 2), yPos + 16, boxWidth, 2)
		SetDrawColor(1, 1, 1)
		DrawString(xPos + (labelWidth / 2), yPos, "CENTER_X", 16, "VAR BOLD", localisation:Text("ui.build.open_spectre_library.armour_label_draw.message"))
		if self.armourValue then
			DrawString(xPos + (labelWidth / 2), yPos + 24, "CENTER_X", 16, "VAR", self.armourValue)
		end
	end
	controls.evasionLabel = new("LabelControl"):LabelControl({ "TOP", controls.energyshieldLabel, "TOP" }, { 1, 54, 0, 16 }, localisation:Label("ui.build.open_spectre_library.evasion_label.label", nil, colorCodes.EVASION))
	controls.evasionLabel.Draw = function(self, view)
		local xPos, yPos = self:GetPos()
		local boxWidth, boxHeight = 120, 50
		local labelWidth = DrawStringWidth(16, "VAR BOLD", localisation:Text("ui.build.open_spectre_library.label_width.message_4"))
		SetDrawColor(colorCodes.EVASION)
		DrawImage(nil, xPos + (labelWidth / 2) - (boxWidth / 2), yPos - 3, boxWidth, boxHeight)
		SetDrawColor(0, 0, 0, 1)
		DrawImage(nil, xPos + (labelWidth / 2) - (boxWidth / 2) + 2, yPos - 1, boxWidth - 4, boxHeight - 4)
		SetDrawColor(colorCodes.EVASION)
		DrawImage(nil, xPos + (labelWidth / 2) - (boxWidth / 2), yPos + 16, boxWidth, 2)
		SetDrawColor(1, 1, 1)
		DrawString(xPos + (labelWidth / 2), yPos, "CENTER_X", 16, "VAR BOLD", localisation:Text("ui.build.open_spectre_library.evasion_label_draw.message"))
		if self.evasionValue then
			DrawString(xPos + (labelWidth / 2), yPos + 24, "CENTER_X", 16, "VAR", self.evasionValue)
		end
	end
	controls.blockLabel = new("LabelControl"):LabelControl({ "TOP", controls.armourLabel, "TOP" }, { 1, 54, 0, 16 }, localisation:Label("ui.build.open_spectre_library.block_label.label", nil, colorCodes.NORMAL))
	controls.blockLabel.Draw = function(self, view)
		local xPos, yPos = self:GetPos()
		local boxWidth, boxHeight = 120, 50
		local labelWidth = DrawStringWidth(16, "VAR BOLD", localisation:Text("ui.build.open_spectre_library.label_width.message_2"))
		SetDrawColor(colorCodes.NORMAL)
		DrawImage(nil, xPos + (labelWidth / 2) - (boxWidth / 2), yPos - 3, boxWidth, boxHeight)
		SetDrawColor(0, 0, 0, 1)
		DrawImage(nil, xPos + (labelWidth / 2) - (boxWidth / 2) + 2, yPos - 1, boxWidth - 4, boxHeight - 4)
		SetDrawColor(colorCodes.NORMAL)
		DrawImage(nil, xPos + (labelWidth / 2) - (boxWidth / 2), yPos + 16, boxWidth, 2)
		SetDrawColor(1, 1, 1)
		DrawString(xPos + labelWidth / 2, yPos, "CENTER_X", 16, "VAR BOLD", localisation:Text("ui.build.open_spectre_library.block_label_draw.message"))
		if self.blockValue then
			DrawString(xPos + (labelWidth / 2), yPos + 24, "CENTER_X", 16, "VAR", self.blockValue)
		end
	end
	controls.resistsLabel = new("LabelControl"):LabelControl({ "TOP", controls.evasionLabel, "TOP" }, { 1, 54, 0, 16 }, localisation:Label("ui.build.open_spectre_library.resists_label.label"))
	controls.resistsLabel.Draw = function(self, view)
		local xPos, yPos = self:GetPos()
		local boxWidth, boxHeight = 120, 50
		local labelWidth = DrawStringWidth(16, "VAR BOLD", localisation:Text("ui.build.open_spectre_library.label_width.message_7"))
		SetDrawColor(colorCodes.DEFENCE)
		DrawImage(nil, xPos + (labelWidth / 2) - (boxWidth / 2), yPos - 3, boxWidth, boxHeight)
		SetDrawColor(0, 0, 0, 1)
		DrawImage(nil, xPos + (labelWidth / 2) - (boxWidth / 2) + 2, yPos - 1, boxWidth - 4, boxHeight - 4)
		SetDrawColor(colorCodes.DEFENCE)
		DrawImage(nil, xPos + (labelWidth / 2) - (boxWidth / 2), yPos + 16, boxWidth, 2)
		SetDrawColor(1, 1, 1)
		DrawString(xPos + labelWidth / 2, yPos, "CENTER_X", 16, "VAR BOLD", localisation:Text("ui.build.open_spectre_library.resists_label_draw.message"))
		if self.resistsValue then
			DrawString(xPos + (labelWidth / 2), yPos + 24, "CENTER_X", 16, "VAR", self.resistsValue)
		end
	end
	controls.movementSpeedLabel = new("LabelControl"):LabelControl({ "TOP", controls.blockLabel, "TOP" }, { 61, 54, 0, 16 }, localisation:Label("ui.build.open_spectre_library.movement_speed_label.label"))
	controls.movementSpeedLabel.Draw = function(self, view)
		local xPos, yPos = self:GetPos()
		local boxWidth, boxHeight = 244, 50
		local labelWidth = DrawStringWidth(16, "VAR BOLD", localisation:Text("ui.build.open_spectre_library.label_width.message_6"))
		SetDrawColor(colorCodes.DEFENCE)
		DrawImage(nil, xPos + (labelWidth / 2) - (boxWidth / 2), yPos - 3, boxWidth, boxHeight)
		SetDrawColor(0, 0, 0, 1)
		DrawImage(nil, xPos + (labelWidth / 2) - (boxWidth / 2) + 2, yPos - 1, boxWidth - 4, boxHeight - 4)
		SetDrawColor(colorCodes.DEFENCE)
		DrawImage(nil, xPos + (labelWidth / 2) - (boxWidth / 2), yPos + 16, boxWidth, 2)
		SetDrawColor(1, 1, 1)
		DrawString(xPos + labelWidth / 2, yPos, "CENTER_X", 16, "VAR BOLD", localisation:Text("ui.build.open_spectre_library.movement_speed_label_draw.message"))
		if self.movementSpeedValue then
			DrawString(xPos + (labelWidth / 2), yPos + 24, "CENTER_X", 16, "VAR", self.movementSpeedValue)
		end
	end
	controls.spawnLocations = new("SpawnListControl"):SpawnListControl({ "TOP", controls.movementSpeedLabel, "TOP" }, { 2, 73, 244, 68 }, self.data, nil, localisation:Label("minion.library.spawns"))
end

function buildMode:OpenSimilarPopup()
	local controls = { }
	-- local width, height = self:GetSize()
	local buildProviders = {
		{
			name = "PoB Archives",
			impl = new("PoBArchivesProvider"):PoBArchivesProvider("similar")
		}
	}
	local width = 600
	local height = function()
		return main.screenH * 0.8
	end
	local padding = 50
	controls.similarBuildList = new("ExtBuildListControl"):ExtBuildListControl(nil, { 0, padding, width, height() - 2 * padding }, buildProviders)
	controls.similarBuildList.shown = true
	controls.similarBuildList.height = function()
		return height() - 2 * padding
	end
	controls.similarBuildList.width = function ()
		return width - padding
	end
	controls.similarBuildList:SetImportCode(common.base64.encode(Deflate(self:SaveDB("code"))):gsub("+","-"):gsub("/","_"))
	controls.similarBuildList:Init("PoB Archives")

	-- controls.similarBuildList.shown = not controls.similarBuildList:IsShown()

	controls.close = new("ButtonControl"):ButtonControl(nil, { 0, height() - (padding + 20) / 2, 80, 20 }, localisation:Label("ui.build.open_similar_popup.close.label"), function()
		main:ClosePopup()
	end)
	-- used in PopupDialog to dynamically size the popup
	local function resizeFunc()
		main.popups[1].height = height()
		main.popups[1].y = function()
			return m_floor((main.screenH - height()) / 2)
		end
		controls.close.y = height() - 35
	end
	main:OpenPopup(width, height(), localisation:Label("ui.build.open_similar_popup.label"), controls, nil, nil, nil, nil, resizeFunc)
end

-- Refresh the set of controls used to select main group/skill/minion
function buildMode:RefreshSkillSelectControls(controls, mainGroup, suffix)
	controls.mainSocketGroup.selIndex = mainGroup
	wipeTable(controls.mainSocketGroup.list)
	for i, socketGroup in pairs(self.skillsTab.socketGroupList) do
		controls.mainSocketGroup.list[i] = { val = i, label = socketGroup.displayLabel, labelDisplay = function() return localisation:SocketGroupName(socketGroup) end }
	end
	controls.mainSocketGroup:CheckDroppedWidth(true)
	if controls.warnings then controls.warnings.shown = #controls.warnings.lines > 0 end
	controls.statSet.shown = false
	if #controls.mainSocketGroup.list == 0 then
		controls.mainSocketGroup.list[1] = { val = 1, label = "<No skills added yet>", labelKey = "ui.build.refresh_skill_select_controls.main_socket_group_list_1.label" }
		controls.mainSkill.shown = false
		controls.mainSkillPart.shown = false
		controls.mainSkillMineCount.shown = false
		controls.mainSkillStageCount.shown = false
		controls.mainSkillMinion.shown = false
		controls.mainSkillMinionSkill.shown = false
		controls.mainSkillMinionSkillStatSet.shown = false
	else
		local mainSocketGroup = self.skillsTab.socketGroupList[mainGroup]
		local displaySkillList = mainSocketGroup["displaySkillList"..suffix]
		local mainActiveSkill = mainSocketGroup["mainActiveSkill"..suffix] or 1
		wipeTable(controls.mainSkill.list)
		for i, activeSkill in ipairs(displaySkillList) do
			local explodeSource = activeSkill.activeEffect.srcInstance.explodeSource
			local explodeSourceName = explodeSource and (explodeSource.name or explodeSource.dn)
			local colourCoded = explodeSourceName and ("From "..colorCodes[explodeSource.rarity or "NORMAL"]..explodeSourceName)
			t_insert(controls.mainSkill.list, { val = i, label = colourCoded or self.calcsTab.calcs.getActiveSkillDisplayName(activeSkill), labelDisplay = function() return localisation:ActiveSkillSelectionName(activeSkill) end })
		end
		controls.mainSkill.enabled = #displaySkillList > 1
		controls.mainSkill.selIndex = mainActiveSkill
		controls.mainSkill.shown = true
		controls.mainSkillPart.shown = false
		controls.mainSkillMineCount.shown = false
		controls.mainSkillStageCount.shown = false
		controls.mainSkillMinion.shown = false
		controls.mainSkillMinionLibrary.shown = false
		controls.mainSkillBeastLibrary.shown = false
		controls.mainSkillMinionSkill.shown = false
		controls.mainSkillMinionSkillStatSet.shown = false
		if displaySkillList[1] then
			local activeSkill = displaySkillList[mainActiveSkill]
			local activeEffect = activeSkill.activeEffect
			if activeEffect then
				wipeTable(controls.statSet.list)
				for i, statSet in ipairs(activeEffect.grantedEffect.statSets) do
					t_insert(controls.statSet.list, { val = i, label = statSet.label, labelKey = statSet.labelKey, grantedEffectId = activeEffect.grantedEffect.id })
				end
				controls.statSet.selIndex = activeEffect.srcInstance["statSet"..suffix] and activeEffect.srcInstance["statSet"..suffix][activeEffect.grantedEffect.id] or 1
				controls.statSet.enabled = #controls.statSet.list > 1
				controls.statSet.shown = true
				if activeEffect.grantedEffect.parts and #activeEffect.grantedEffect.parts > 1 then
					controls.mainSkillPart.shown = true
					wipeTable(controls.mainSkillPart.list)
					for i, part in ipairs(activeEffect.grantedEffect.parts) do
						t_insert(controls.mainSkillPart.list, { val = i, label = part.name })
					end
					controls.mainSkillPart.selIndex = activeEffect.srcInstance["skillPart"..suffix] or 1
					if activeEffect.grantedEffect.parts[controls.mainSkillPart.selIndex].stages then
						controls.mainSkillStageCount.shown = true
						controls.mainSkillStageCount.buf = tostring(activeEffect.srcInstance["skillStageCount"..suffix] or activeEffect.grantedEffect.parts[controls.mainSkillPart.selIndex].stagesMin or 1)
					end
				end
				activeSkill.activeEffect.statSet = activeSkill.activeEffect.statSet or activeSkill.activeEffect.statSetCalcs or { }
				activeSkill.activeEffect.statSet.skillFlags = activeSkill.activeEffect.statSet.skillFlags or { }
				if activeSkill.activeEffect.statSet.skillFlags.mine then
					controls.mainSkillMineCount.shown = true
					controls.mainSkillMineCount.buf = tostring(activeEffect.srcInstance["skillMineCount"..suffix] or "")
				end
				if activeSkill.activeEffect.statSet.skillFlags.multiStage and not (activeEffect.grantedEffect.parts and #activeEffect.grantedEffect.parts > 1) then
					controls.mainSkillStageCount.shown = true
					controls.mainSkillStageCount.buf = tostring(activeEffect.srcInstance["skillStageCount"..suffix] or activeSkill.skillData.stagesMin or 1)
				end
				local minionList = activeSkill.minionList or activeEffect.grantedEffect.minionList
				if not activeSkill.activeEffect.statSet.skillFlags.disable and (activeEffect.grantedEffect.minionList or (minionList and minionList[1])) then
					wipeTable(controls.mainSkillMinion.list)
					if activeEffect.grantedEffect.minionHasItemSet then
						for _, itemSetId in ipairs(self.itemsTab.itemSetOrderList) do
							local itemSet = self.itemsTab.itemSets[itemSetId]
							t_insert(controls.mainSkillMinion.list, {
								label = itemSet.title or "Default Item Set",
								itemSetId = itemSetId,
							})
						end
						controls.mainSkillMinion:SelByValue(activeEffect.srcInstance["skillMinionItemSet"..suffix] or 1, "itemSetId")
					else
						controls.mainSkillMinionLibrary.shown = (
							activeEffect.grantedEffect.minionList
							and not activeEffect.grantedEffect.minionList[1]
							and activeSkill.activeEffect.grantedEffect.name:match("^Spectre:")
							and not (controls.showMinion and controls.showMinion.state == true)
						)
						controls.mainSkillBeastLibrary.shown = (
							activeEffect.grantedEffect.minionList
							and not activeEffect.grantedEffect.minionList[1]
							and activeSkill.activeEffect.grantedEffect.name:match("^Companion:")
							and not (controls.showMinion and controls.showMinion.state == true)
						)
						for _, minionId in ipairs(minionList or { }) do
							local minion = self.data.minions[minionId]
							if minion then
								t_insert(controls.mainSkillMinion.list, {
									label = minion.name,
									labelKey = minion.nameKey,
									minionId = minionId,
								})
							end
						end
						controls.mainSkillMinion:SelByValue(activeEffect.srcInstance["skillMinion"..suffix] or controls.mainSkillMinion.list[1], "minionId")
					end
					controls.mainSkillMinion.enabled = #controls.mainSkillMinion.list > 1
					controls.mainSkillMinion.shown = true
					wipeTable(controls.mainSkillMinionSkill.list)
					if activeSkill.minion then
						if activeSkill.minion.activeSkillList and activeSkill.minion.activeSkillList[1] then
							for _, minionSkill in ipairs(activeSkill.minion.activeSkillList) do
								local effect = minionSkill.activeEffect.grantedEffect
								t_insert(controls.mainSkillMinionSkill.list, { label = effect.name, labelKey = effect.nameKey })
							end
							controls.mainSkillMinionSkill.selIndex = activeEffect.srcInstance["skillMinionSkill"..suffix] or 1
							controls.mainSkillMinionSkill.shown = true
							controls.mainSkillMinionSkill.enabled = #controls.mainSkillMinionSkill.list > 1
							wipeTable(controls.mainSkillMinionSkillStatSet.list)
							for _, statSet in ipairs(activeSkill.minion.activeSkillList[controls.mainSkillMinionSkill.selIndex].activeEffect.grantedEffect.statSets) do
								t_insert(controls.mainSkillMinionSkillStatSet.list, {label =  statSet.label, labelKey = statSet.labelKey, grantedEffectId = activeEffect.grantedEffect.id})
							end
							local minionStatSetIndexLookup = activeEffect.srcInstance["skillMinionSkillStatSetIndexLookup"..suffix]
							controls.mainSkillMinionSkillStatSet.selIndex = minionStatSetIndexLookup and minionStatSetIndexLookup[activeEffect.grantedEffect.id] and minionStatSetIndexLookup[activeEffect.grantedEffect.id][controls.mainSkillMinionSkill.selIndex] or 1
							controls.mainSkillMinionSkillStatSet.shown = true
							controls.mainSkillMinionSkillStatSet.enabled = #controls.mainSkillMinionSkillStatSet.list > 1
						end
					else
						t_insert(controls.mainSkillMinion.list, "<No spectres in build>")
					end
				end
			end
		end
	end
end

function buildMode:FormatStat(statData, statVal, overCapStatVal, colorOverride)
	if type(statVal) == "table" then return "" end
	local val = statVal * ((statData.pc or statData.mod) and 100 or 1) - (statData.mod and 100 or 0)
	local color = colorOverride or (statVal >= 0 and "^7" or statData.chaosInoc and "^8" or colorCodes.NEGATIVE)
	if statData.label == "Unreserved Life" and statVal == 0 then
		color = colorCodes.NEGATIVE
	end

	local valStr = s_format("%"..statData.fmt, val)
	valStr:gsub("%.", main.decimalSeparator)
	valStr = color .. formatNumSep(valStr)

	if overCapStatVal and overCapStatVal > 0 then
		valStr = valStr .. "^x808080" .. " (+" .. s_format("%d", overCapStatVal) .. "%)"
	end
	self.lastShowThousandsSeparators = main.showThousandsSeparators
	self.lastShowThousandsSeparator = main.thousandsSeparator
	self.lastShowDecimalSeparator = main.decimalSeparator
	self.lastShowTitlebarName = main.showTitlebarName
	return valStr
end

-- lazily index the calcs tab sections so that we can look up the matching
-- sections by breakdown name. this function works by iterating through calc
-- sections. it will link every breakdown key to the first found calc section
-- column (basically, a box). the result will contain references to this column
-- data and will also contain a set of mod names referred to by cells of said
-- box. if a cell shouldn't be picked, the field `skipSideBarIndex` can be set
-- on the cell.
function buildMode:BuildBreakdownIndex()
	if self.breakdownIndex then
		return self.breakdownIndex
	end
	local index = {}
	local sectionList = self.calcsTab.sectionList
	for _, section in ipairs(sectionList) do
		if section.subSection then
			for _, subSection in ipairs(section.subSection) do
				-- cells for each mod name
				local modSectionsByName = {}
				local breakdownCells = {}
				---@type CalcSectionData
				local subSectionData = subSection.data
				for _, row in ipairs(subSectionData) do
					for _, colData in ipairs(row) do
						for _, cell in ipairs(colData) do
							if not cell.skipSideBarIndex and cell.breakdown and not breakdownCells[cell.breakdown] then
								breakdownCells[cell.breakdown] = colData
							end
							if cell.modName then
								-- inherit flags from parent row
								local copy = copyTable(row, true)
								for k, v in pairs(cell) do
									copy[k] = v
								end
								local names = type(cell.modName) == "table" and cell.modName or { cell.modName }
								for _, name in ipairs(names) do
									modSectionsByName[name] = modSectionsByName[name] or {}
									t_insert(modSectionsByName[name], copy)
								end
							end
						end
					end
				end
				for key, colData in pairs(breakdownCells) do
					-- ensure that we only set each breakdown once
					if not index[key] then
						index[key] = { colData = colData, modSectionsByName = modSectionsByName }
					end
				end
			end
		end
	end
	self.breakdownIndex = index
	return index
end

---@param key string A breakdown key
---@param modNames string[]? A modName key. Required if the mod name is different from the breakdown key. E.g. breakdown has Time while the mod has Speed
---@param ignoredSections table<string, boolean>?
---@param actorName string?
function buildMode:GetSidebarBreakdown(key, modNames, ignoredSections, actorName)
	local env = actorName and self.calcsTab.mainEnv[actorName]
	local breakdownData = env and env.breakdown and env.breakdown[key]
	local sourceKey = breakdownData and breakdownData.breakdownSource or key
	local entry = self:BuildBreakdownIndex()[sourceKey]
	if not entry then
		local output = { { breakdown = key } }
		-- it's possible for calc sections to not have a breakdown, while still
		-- having a mod list. this handles e.g. spell suppression chance
		if modNames then
			table.insert(output, { modName = modNames })
		end
		return output
	end
	local displayData = {}
	-- this will include all of the hover information for the selected breakdown
	for _, cell in ipairs(entry.colData) do
		local displayCell = copyTable(cell)
		if displayCell.breakdown == sourceKey then
			displayCell.breakdown = key
		end
		t_insert(displayData, displayCell)
	end
	-- sometimes the breakdown doesn't include the mod names. for
	-- example life has its mod tables separated to the inc and more breakdowns.
	if modNames then
		for _, modKey in ipairs(modNames) do
			if entry.modSectionsByName[modKey] then
				for _, statDisplay in ipairs(entry.modSectionsByName[modKey]) do
					t_insert(displayData, statDisplay)
				end
			end
		end
	end

	local visitedSections = {}
	-- remove sections that have been manually excluded, or ones that have
	-- already been added. it's probably not guaranteed that the sections with
	-- the same label always contain the exact same contents, but this gets rid
	-- of pointless repeated sections
	for i = #displayData, 1, -1 do
		local label = displayData[i].label
		if label then
			if visitedSections[label] or (ignoredSections and ignoredSections[label]) then
				table.remove(displayData, i)
			end
			visitedSections[label] = true
		end
	end
	if #displayData == 0 then
		return { { breakdown = key } }
	end
	return displayData
end

---@param actorName string
function buildMode:GetStatBreakdownKey(statData, actorName)
	local env = self.calcsTab.mainEnv[actorName]
	local breakdown = env and env.breakdown
	if not breakdown then
		return nil
	end
	local key
	if statData.breakdown ~= nil then
		key = statData.breakdown
	elseif statData.childStat then
		local parent = breakdown[statData.stat]
		if parent and parent[statData.childStat] then
			key = statData.stat .. "." .. statData.childStat
		end
	elseif breakdown[statData.stat] then
		key = statData.stat
	end
	if key == nil then
		return nil
	end
	-- Modifier-only popups do not require a calculated breakdown.
	if statData.modNames then
		return key
	end
	local namespace, name = key:match("^(%a+)%.(%a+)$")
	local breakdownData = namespace and breakdown[namespace] and breakdown[namespace][name] or breakdown[key]
	if breakdownData and (#breakdownData > 0
			or breakdownData.radius
			or breakdownData.rowList and #breakdownData.rowList > 0
			or breakdownData.reservations and #breakdownData.reservations > 0
			or breakdownData.damageTypes and #breakdownData.damageTypes > 0
			or breakdownData.slots and #breakdownData.slots > 0
			or breakdownData.modList and #breakdownData.modList > 0) then
		return key
	end
	return nil
end
-- Add stat list for given actor
---@param statList DisplayStat[]
---@param actor any
---@param actorName string
function buildMode:AddDisplayStatList(statList, actor, actorName)
	local statBoxList = self.controls.statBox.list
	for index, statData in ipairs(statList) do
		if not statData.flag or actor.mainSkill.activeEffect.statSet.skillFlags[statData.flag] then
			local labelColor = "^7"
			if statData.color then
				labelColor = statData.color
			end
			if statData.stat then
				local statVal = actor.output[statData.stat]
				-- access output values that are one node deeper (statData.stat is a table e.g. output.MainHand.Accuracy vs output.Life)
				if statVal and statData.childStat then
					statVal = statVal[statData.childStat]
				end
				if statVal and ((statData.condFunc and statData.condFunc(statVal,actor.output)) or (not statData.condFunc and statVal ~= 0)) then
					local overCapStatVal = actor.output[statData.overCapStat] or nil
					if statData.stat == "SkillDPS" then
						labelColor = colorCodes.CUSTOM
						table.sort(actor.output.SkillDPS, function(a,b) return (a.dps * a.count) > (b.dps * b.count) end)
						for _, skillData in ipairs(actor.output.SkillDPS) do
							local triggerStr = ""
							if skillData.trigger and skillData.trigger ~= "" then
								triggerStr = colorCodes.WARNING.." ("..localisation:Field(skillData, 'trigger')..")"..labelColor
							end
							local skillCount = skillData.count or 1
							local skillName = localisation:Field(skillData, 'name')
							local lhsString = labelColor..skillName..triggerStr..":"
							if skillCount ~= 1 then
								lhsString = labelColor..s_format("%g", skillCount).."x "..skillName..triggerStr..":"
							end
							t_insert(statBoxList, {
								height = 16,
								lhsString,
								self:FormatStat({fmt = "1.f"}, skillData.dps * skillCount, overCapStatVal),
							})
							if skillData.skillPart then
								t_insert(statBoxList, {
									height = 14,
									align = "CENTER_X", x = 140,
									"^8"..localisation:Field(skillData, 'skillPart'),
								})
							end
							if skillData.source then
								t_insert(statBoxList, {
									height = 14,
									align = "CENTER_X", x = 140,
									colorCodes.WARNING .. localisation:Text("ui.build.sidebar.add_display_stat_list", { source = localisation:Field(skillData, 'source') }),
								})
							end
						end
					elseif not (statData.hideStat) then
						-- Change the color of the stat label to red if cost exceeds pool
						local colorOverride = nil
						if actor.output[statData.stat.."Warning"] or (statData.warnFunc and statData.warnFunc(statVal, actor.output) and statData.warnColor) then
							colorOverride = colorCodes.NEGATIVE
						end
						local formattedStat = self:FormatStat(statData, statVal, overCapStatVal, colorOverride)
						if statData.suffix and (not statData.suffixCondFunc or statData.suffixCondFunc(statVal, actor.output)) then
							local suffix = statData.suffix
							if type(suffix) == "function" then
								suffix = suffix(statVal, actor.output)
							end
							if suffix then
								formattedStat = formattedStat .. "^x808080 (" .. suffix .. ")"
							end
						end
						local breakdown = self:GetStatBreakdownKey(statData, actorName)
						local ignoredSections
						if statData.ignoredSections then
							ignoredSections = {}
							for _, label in ipairs(statData.ignoredSections) do
								ignoredSections[label] = true
							end
						end
						-- SimpleGraphic also has these short codes which cannot be easily translated to hex
						local colourCodeMap = {
							["^1"] = { 0.917, 0, 0 },
							["^7"] = { 1, 1, 1 },
						}
						local breakdownColour = labelColor ~= "^7" and hexToRGB(labelColor) or colourCodeMap[labelColor]
						t_insert(statBoxList, {
							height = 16,
							labelColor..localisation:Field(statData, "label")..":",
							formattedStat,
							breakdown = breakdown,
							modNames = statData.modNames,
							underline = { false, not not breakdown },
							actorName = actorName,
							ignoredSections = ignoredSections,
							breakdownColour = breakdownColour,
						})
					end
				end
				if statData.warnFunc and statVal and ((statData.condFunc and statData.condFunc(statVal, actor.output)) or not statData.condFunc) then
					local v = statData.warnFunc(statVal, actor.output)
					if v then
						InsertIfNew(self.controls.warnings.lines, v)
					end
				end
			elseif statData.label and statData.condFunc and statData.condFunc(actor.output) then
				t_insert(statBoxList, {
					height = 16, labelColor..localisation:Field(statData, "label")..":",
					"^7"..actor.output[statData.labelStat].."%^x808080" .. " (" .. statData.val  .. ")",})
			elseif not statBoxList[#statBoxList] or statBoxList[#statBoxList][1] then
				t_insert(statBoxList, { height = 6 })
			end
		end
	end
	for pool, warningFlag in pairs({["Life"] = "LifeCostWarningList", ["Mana"] = "ManaCostWarningList", ["Runic Ward"] = "WardCostWarningList", ["Rage"] = "RageCostWarningList", ["Energy Shield"] = "ESCostWarningList", ["Unreserved life"] = "LifePercentCostPercentCostWarningList", ["Unreserved Mana"] = "ManaPercentCostPercentCostWarningList"}) do
		if actor.output[warningFlag] then
			local skills = { }
			for index, skill in ipairs(actor.output[warningFlag]) do
				local effect = actor.output[warningFlag .. "Display"] and actor.output[warningFlag .. "Display"][index]
				skills[index] = effect and localisation:Field(effect, "name") or skill
			end
			local resource = actor.output.EnergyShieldProtectsMana and pool == "Mana" and "Energy Shield and Mana" or pool
			InsertIfNew(self.controls.warnings.lines, localisation:Text("build.warning.insufficient_resource", { resource = localisation:TermRef("cost_pool", resource), skills = table.concat(skills, ", ") }))
		end
	end
	if actor.output.EternalLifeWarning then
		InsertIfNew(self.controls.warnings.lines, localisation:Text("ui.build.warning.add_display_stat_list"))
	end
	if actor.output.VixensTooMuchCastSpeedWarn then
		InsertIfNew(self.controls.warnings.lines, localisation:Text("ui.build.warning.add_display_stat_list_2"))
	end
	if actor.output.VixenModeNoVixenGlovesWarn then
		InsertIfNew(self.controls.warnings.lines, localisation:Text("ui.build.warning.add_display_stat_list_3"))
	end
end

function buildMode:InsertItemWarnings()
	if self.calcsTab.mainEnv.itemWarnings.jewelLimitWarning then
		for _, warning in ipairs(self.calcsTab.mainEnv.itemWarnings.jewelLimitWarning) do
			InsertIfNew(self.controls.warnings.lines, localisation:Text("ui.build.warning.insert_item_warnings", { warning = warning }))
		end
	end
	if self.calcsTab.mainEnv.itemWarnings.augmentLimitWarning then
		for _, warning in ipairs(self.calcsTab.mainEnv.itemWarnings.augmentLimitWarning) do
			InsertIfNew(self.controls.warnings.lines, localisation:Text("ui.build.warning.insert_item_warnings_2", { warning = warning }))
		end
	end
	if self.calcsTab.mainEnv.itemWarnings.socketLimitWarning then
		for _, warning in ipairs(self.calcsTab.mainEnv.itemWarnings.socketLimitWarning) do
			InsertIfNew(self.controls.warnings.lines, localisation:Text("ui.build.warning.insert_item_warnings_3", { warning = warning }))
		end
	end
	if self.calcsTab.mainEnv.itemWarnings.lineageSupportGemLimitWarning then
		for _, warning in ipairs(self.calcsTab.mainEnv.itemWarnings.lineageSupportGemLimitWarning) do
			InsertIfNew(self.controls.warnings.lines, localisation:Text("ui.build.warning.insert_item_warnings_4", { value = warning[1], value_2 = warning[2], value_3 = warning[3] and localisation:Ref("ui.build.warning.lineage_locations", { locations = table.concat(warning[3], ", ") }) or "" }))
		end
	end
	if self.calcsTab.mainEnv.itemWarnings.gemGroupCountWarning then
		for _, warning in ipairs(self.calcsTab.mainEnv.itemWarnings.gemGroupCountWarning) do
			InsertIfNew(self.controls.warnings.lines, localisation:Text("ui.build.warning.insert_item_warnings_5", { value = warning[1], value_2 = warning[2] }))
		end
	end
end

-- Build list of side bar stats
function buildMode:RefreshStatList()
	self.controls.warnings.lines = {}
	local statBoxList = wipeTable(self.controls.statBox.list)
	if self.calcsTab.mainEnv.player.mainSkill.infoMessage then
			if #self.calcsTab.mainEnv.player.mainSkill.infoMessage > 40 then
				for line in string.gmatch(self.calcsTab.mainEnv.player.mainSkill.infoMessage, "([^:]+)") do
					t_insert(statBoxList, { height = 14, align = "CENTER_X", x = 140, colorCodes.CUSTOM .. line})
				end
			else
				t_insert(statBoxList, { height = 14, align = "CENTER_X", x = 140, colorCodes.CUSTOM .. self.calcsTab.mainEnv.player.mainSkill.infoMessage})
			end
		if self.calcsTab.mainEnv.player.mainSkill.infoMessage2 then
			t_insert(statBoxList, { height = 14, align = "CENTER_X", x = 140, "^8" .. self.calcsTab.mainEnv.player.mainSkill.infoMessage2})
		end
	end
	if self.calcsTab.mainEnv.minion then
		t_insert(statBoxList, { height = 18, localisation:Text("ui.build.sidebar.refresh_stat_list") })
		if self.calcsTab.mainEnv.minion.mainSkill.infoMessage then
			-- Split the line if too long
			if #self.calcsTab.mainEnv.minion.mainSkill.infoMessage > 40 then
				for line in string.gmatch(self.calcsTab.mainEnv.minion.mainSkill.infoMessage, "([^:]+)") do
					t_insert(statBoxList, { height = 14, align = "CENTER_X", x = 140, colorCodes.CUSTOM .. line})
				end
			else
				t_insert(statBoxList, { height = 14, align = "CENTER_X", x = 140, colorCodes.CUSTOM .. self.calcsTab.mainEnv.minion.mainSkill.infoMessage})
			end
			if self.calcsTab.mainEnv.minion.mainSkill.infoMessage2 then
				t_insert(statBoxList, { height = 14, align = "CENTER_X", x = 140, "^8" .. self.calcsTab.mainEnv.minion.mainSkill.infoMessage2})
			end
		end
		self:AddDisplayStatList(self.minionDisplayStats, self.calcsTab.mainEnv.minion, "minion")
		t_insert(statBoxList, { height = 10 })
		t_insert(statBoxList, { height = 18, localisation:Text("ui.build.sidebar.refresh_stat_list_2") })
	end
	if self.calcsTab.mainEnv.player.mainSkill.activeEffect.statSet.skillFlags.disable then
		t_insert(statBoxList, { height = 16, localisation:Text("ui.build.sidebar.refresh_stat_list_3") })
		t_insert(statBoxList, { height = 14, align = "CENTER_X", x = 140, self.calcsTab.mainEnv.player.mainSkill.disableReason })
	end
	self:AddDisplayStatList(self.displayStats, self.calcsTab.mainEnv.player, "player")
	self:InsertItemWarnings()
	self:EstimatePlayerProgress()
end

function buildMode:CompareStatList(tooltip, statList, actor, baseOutput, compareOutput, header, nodeCount, newBlock)
	local count = 0
	for _, statData in ipairs(statList) do
		if statData.stat and (not statData.flag or actor.mainSkill.activeEffect.statSet.skillFlags[statData.flag]) and not statData.childStat and statData.stat ~= "SkillDPS" then
			local statVal1 = compareOutput[statData.stat] or 0
			local statVal2 = baseOutput[statData.stat] or 0
			local diff = statVal1 - statVal2
			if statData.stat == "FullDPS" and not compareOutput[statData.stat] then
				diff = 0
			end
			if (diff > 0.001 or diff < -0.001) and (not statData.condFunc or statData.condFunc(statVal1,compareOutput) or statData.condFunc(statVal2,baseOutput)) then
				if count == 0 then
					tooltip:AddLine(14, header, nil, nil, nil, newBlock)
				end
				local color = ((statData.lowerIsBetter and diff < 0) or (not statData.lowerIsBetter and diff > 0)) and colorCodes.POSITIVE or colorCodes.NEGATIVE
				local val = diff * ((statData.pc or statData.mod) and 100 or 1)
				local valStr = s_format("%+"..statData.fmt, val) -- Can't use self:FormatStat, because it doesn't have %+. Adding that would have complicated a simple function

				valStr = formatNumSep(valStr)

				local line = s_format("%s%s %s", color, valStr, localisation:Field(statData, "label"))
				local pcPerPt = ""
				if statData.compPercent and statVal1 ~= 0 and statVal2 ~= 0 then
					local pc = statVal1 / statVal2 * 100 - 100
					line = line .. s_format(" (%+.1f%%)", pc)
					if nodeCount then
						pcPerPt = s_format(" (%+.1f%%)", pc / nodeCount)
					end
				end
				if nodeCount then
					line = line .. localisation:Text("build.compare.per_point", { value = s_format("%+" .. statData.fmt, diff * ((statData.pc or statData.mod) and 100 or 1) / nodeCount), percentage = pcPerPt })
				end
				tooltip:AddLine(14, line)
				count = count + 1
			end
		end
	end
	return count
end

-- Compare values of all display stats between the two output tables, and add any changed stats to the tooltip
-- Adds the provided header line before the first stat line, if any are added
-- Returns the number of stat lines added
function buildMode:AddStatComparesToTooltip(tooltip, baseOutput, compareOutput, header, nodeCount, newBlock)
	local count = 0
	if self.calcsTab.mainEnv.player.mainSkill.minion and baseOutput.Minion and compareOutput.Minion then
		count = count + self:CompareStatList(tooltip, self.minionDisplayStats, self.calcsTab.mainEnv.minion, baseOutput.Minion, compareOutput.Minion, header.."\n^7Minion:", nodeCount, newBlock)
		if count > 0 then
			newBlock = false
			header = "^7Player:"
		else
			header = header.."\n^7Player:"
		end
	end
	count = count + self:CompareStatList(tooltip, self.displayStats, self.calcsTab.mainEnv.player, baseOutput, compareOutput, header, nodeCount, newBlock)
	return count
end

-- Add requirements to tooltip
do
	local req = { }
	function buildMode:AddRequirementsToTooltip(tooltip, level, str, dex, int, strBase, dexBase, intBase)
		if level and level > 0 then
			if tooltip.tooltipHeader ~= "GEM" then
				t_insert(req, "^x7F7F7F" .. localisation:Text("equipment.requirement.level_value", { colour = main:StatColor(level, nil, self.characterLevel), level = level }))
			else
				t_insert(req, "^7" .. localisation:Text("equipment.requirement.level_value", { colour = main:StatColor(level, nil, self.characterLevel), level = level }))
			end
		end
		-- Convert normal attributes to Omni attributes
		if self.calcsTab.mainEnv.modDB:Flag(nil, "OmniscienceRequirements") then
			local omniSatisfy = self.calcsTab.mainEnv.modDB:Sum("INC", nil, "OmniAttributeRequirements")
			local highestAttribute = 0
			for i, stat in ipairs({str, dex, int}) do
				if((stat or 0) > highestAttribute) then
					highestAttribute = stat
				end
			end
			local omni = math.floor(highestAttribute * (100/omniSatisfy))
			if omni and (omni > 0 or omni > self.calcsTab.mainOutput.Omni) then
				t_insert(req, localisation:Text("equipment.requirement.omniscience_value", { colour = main:StatColor(omni, 0, self.calcsTab.mainOutput.Omni), value = omni }))
			end
		else
			local attrTextColor = (tooltip.tooltipHeader == "GEM") and "^7" or "^x7F7F7F"
			if str and (str > 7 or str > self.calcsTab.mainOutput.Str) then
				t_insert(req, localisation:Text("equipment.requirement.attribute_value", { colour = main:StatColor(str, strBase, self.calcsTab.mainOutput.Str), value = str, label_colour = attrTextColor, attribute = localisation:TermRef("attribute", level and "Str" or "Strength") }))
			end
			if dex and (dex > 7 or dex > self.calcsTab.mainOutput.Dex) then
				t_insert(req, localisation:Text("equipment.requirement.attribute_value", { colour = main:StatColor(dex, dexBase, self.calcsTab.mainOutput.Dex), value = dex, label_colour = attrTextColor, attribute = localisation:TermRef("attribute", level and "Dex" or "Dexterity") }))
			end
			if int and (int > 7 or int > self.calcsTab.mainOutput.Int) then
				t_insert(req, localisation:Text("equipment.requirement.attribute_value", { colour = main:StatColor(int, intBase, self.calcsTab.mainOutput.Int), value = int, label_colour = attrTextColor, attribute = localisation:TermRef("attribute", level and "Int" or "Intelligence") }))
			end
		end
		if req[1] then
			local fontSizeBig = main.showFlavourText and 18 or 16
			if tooltip.tooltipHeader ~= "GEM" then
				tooltip:AddLine(fontSizeBig, localisation:Text("ui.build.add_requirements_to_tooltip.tooltip", { value = table.concat(req, "^x7F7F7F, ") }), "FONTIN SC")
				tooltip:AddSeparator(10)
			else
				tooltip:AddLine(fontSizeBig, localisation:Text("ui.build.add_requirements_to_tooltip.tooltip_2", { value = table.concat(req, "^7, ") }), "FONTIN SC")
			end
		end
		wipeTable(req)
	end
end

function buildMode:LoadDB(xmlText, fileName)
	-- Parse the XML
	local dbXML, errMsg = common.xml.ParseXML(xmlText)
	if errMsg and errMsg:match(".*file returns nil") then
		main:OpenCloudErrorPopup(fileName)
		return true
	elseif errMsg then
		launch:ShowErrMsg("^1"..errMsg)
		return true
	elseif dbXML[1].elem ~= "PathOfBuilding2" then
		launch:ShowErrMsg("%s", localisation:Text("ui.build.load_db.error", { file_name = fileName }))
		return true
	end

	-- Load Build section first
	for _, node in ipairs(dbXML[1]) do
		if type(node) == "table" and node.elem == "Build" then
			self:Load(node, self.dbFileName)
			break
		end
	end

	-- Check if xml has an import link
	for _, node in ipairs(dbXML[1]) do
		if type(node) == "table" and node.elem == "Import" then
			if node.attrib.importLink and not self.importLink then
				self.importLink = node.attrib.importLink
			end
			break
		end
	end

	-- Store other sections for later processing
	for _, node in ipairs(dbXML[1]) do
		if type(node) == "table" then
			t_insert(self.xmlSectionList, node)
		end
	end
end

function buildMode:LoadDBFile()
	if not self.dbFileName then
		return
	end
	ConPrintf("Loading '%s'...", self.dbFileName)
	local file = io.open(self.dbFileName, "r")
	if not file then
		self.dbFileName = nil
		return true
	end
	local xmlText = file:read("*a")
	file:close()
	return self:LoadDB(xmlText, self.dbFileName)
end

function buildMode:SaveDB(fileName)
	local dbXML = { elem = "PathOfBuilding2" }

	-- Save Build section first
	do
		local node = { elem = "Build" }
		self:Save(node)
		t_insert(dbXML, node)
	end

	-- Call on all savers to save their data in their respective sections
	for elem, saver in pairsSortByKey(self.savers) do
		local node = { elem = elem }
		saver:Save(node)
		t_insert(dbXML, node)
	end

	-- Compose the XML
	local xmlText, errMsg = common.xml.ComposeXML(dbXML)
	if not xmlText then
		launch:ShowErrMsg("%s", localisation:Text("ui.build.save_db.error", { file_name = fileName, err_msg = errMsg }))
	else
		return xmlText
	end
end


function buildMode:SaveDBFile()
	if not self.dbFileName then
		self:OpenSaveAsPopup()
		return
	end
	local xmlText = self:SaveDB(self.dbFileName)
	if not xmlText then
		return true
	end
	local file = io.open(self.dbFileName, "w+")
	if not file then
		main:OpenMessagePopup(localisation:Text("ui.build.save_dbfile.message_2"), localisation:Text("ui.build.save_dbfile.message", { db_file_name = self.dbFileName }))
		return true
	end
	file:write(xmlText)
	file:close()
	local action = self.actionOnSave
	self.actionOnSave = nil

	-- Reset all modFlags
	self:ResetModFlags()

	if action == "LIST" then
		self:CloseBuild()
	elseif action == "EXIT" then
		Exit()
	elseif action == "UPDATE" then
		launch:ApplyUpdate(launch.updateAvailable)
	end
end

-- Opens the build set manager
function buildMode:OpenBuildSetManagePopup()
	main:OpenPopup(400, 290, localisation:Label("ui.build.open_build_set_manage_popup.label_2"), {
		new("BuildSetListControl"):BuildSetListControl(nil, { 0, 50, 380, 200 }, self),
		new("ButtonControl"):ButtonControl(nil, { 0, 260, 90, 20 }, localisation:Label("ui.build.open_build_set_manage_popup.label"), function()
			main:ClosePopup()
			if self.activeLoadout and self.activeLoadout > 0 then
				self.controls.buildLoadouts:SetSel(self.activeLoadout + 1)
			else
				self.controls.buildLoadouts:SetSel(1)
			end
		end),
	})
end

return buildMode
