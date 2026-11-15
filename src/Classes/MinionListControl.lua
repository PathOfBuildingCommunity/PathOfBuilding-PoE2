-- Path of Building
--
-- Class: Minion List
-- Minion list control.
--
local ipairs = ipairs
local t_insert = table.insert
local t_remove = table.remove
local s_format = string.format
local m_max = math.max

-- 出生区域以业务名称关联真实区域，界面只读取区域已经绑定的显示引用。
local spawnAreas = { }
for _, area in pairs(data.worldAreas) do
	if #area.monsterVarieties > 0 and not spawnAreas[area.name] then spawnAreas[area.name] = area end
end
-- 没有区域详情的已知地点仍使用召唤物自身的稳定显示引用。
local spawnLocations = { }
for _, minion in pairs(data.minions) do
	for index, source in ipairs(minion.spawnLocation or { }) do
		if not spawnLocations[source] then spawnLocations[source] = { minion = minion, index = index } end
	end
end

---@class MinionListControl: ListControl
local MinionListClass = newClass("MinionListControl", "ListControl")

function MinionListClass:MinionListControl(anchor, rect, data, list, dest, label, showCompanionStats)
	self:ListControl(anchor, rect, 16, "VERTICAL", not dest, list)
	self.data = data
	self.dest = dest
	self.showCompanionStats = showCompanionStats
	if dest then
		self.dragTargetList = { dest }
		self.label = label or localisation:Label("ui.minion_list_control.init.label")
		self.controls.add = new("ButtonControl"):ButtonControl({ "BOTTOMRIGHT", self, "TOPRIGHT" }, { 0, -2, 60, 18 }, localisation:Label("ui.minion_list_control.init.add.label"), function()
			self:AddSel()
		end)
		self.controls.add.enabled = function()
			return self.selValue ~= nil and not isValueInArray(dest.list, self.selValue)
		end
	else
		self.label = label or localisation:Label("ui.minion_list_control.init.label_2")
		self.controls.delete = new("ButtonControl"):ButtonControl({ "BOTTOMRIGHT", self, "TOPRIGHT" }, { 0, -2, 60, 18 }, localisation:Label("ui.minion_list_control.init.delete.label"), function()
			self:OnSelDelete(self.selIndex, self.selValue)
		end)
		self.controls.delete.enabled = function()
			return self.selValue ~= nil
		end
	end
	return self
end

function MinionListClass:AddSel()
	if self.dest and not isValueInArray(self.dest.list, self.selValue) then
		t_insert(self.dest.list, self.selValue)
	end
end

function MinionListClass:GetRowValue(column, index, minionId)
	local minion = self.data.minions[minionId]
	if column == 1 then
		return localisation:Field(minion, "name")
	end
end

function MinionListClass:AddValueTooltip(tooltip, index, minionId)
	if tooltip:CheckForUpdate(minionId) then
		local minion = self.data.minions[minionId]
		local fireResist = self.showCompanionStats and minion.companionFireResist or minion.fireResist
		local coldResist = self.showCompanionStats and minion.companionColdResist or minion.coldResist
		local lightningResist = self.showCompanionStats and minion.companionLightningResist or minion.lightningResist
		local chaosResist = self.showCompanionStats and minion.companionChaosResist or minion.chaosResist
		tooltip.center = true
		tooltip:AddLine(20, "^7"..localisation:Field(minion, "name"), "FONTIN SC")
		tooltip.center = false
		tooltip:AddSeparator(10)
		tooltip:AddLine(14, localisation:Text("ui.minion_list_control.add_value_tooltip.tooltip_16", { spirit = colorCodes.SPIRIT, value = tostring(minion.spectreReservation) }))
		tooltip:AddLine(14, localisation:Text("ui.minion_list_control.add_value_tooltip.tooltip_9", { spirit = colorCodes.SPIRIT, value = tostring(minion.companionReservation) }))
		tooltip:AddLine(14, localisation:Text("ui.minion_list_control.add_value_tooltip.tooltip_8", { monster_category = localisation:Field(minion, "monsterCategory") }))
		tooltip:AddLine(14, localisation:Text("ui.minion_list_control.add_value_tooltip.tooltip_12", { life = minion.life }))
		if minion.energyShield then
			tooltip:AddLine(14, localisation:Text("ui.minion_list_control.add_value_tooltip.tooltip_10", { value = minion.energyShield * 100 }))
		end
		if minion.armour then
			tooltip:AddLine(14, localisation:Text("ui.minion_list_control.add_value_tooltip.tooltip_2", { value = 1 + minion.armour }))
		end
		if minion.evasion then
			tooltip:AddLine(14, localisation:Text("ui.minion_list_control.add_value_tooltip.tooltip_11", { value = 1 + minion.evasion }))
		end
		tooltip:AddLine(14, localisation:Text("ui.minion_list_control.add_value_tooltip.tooltip_13", { fire = colorCodes.FIRE, fire_resist = fireResist, cold = colorCodes.COLD, cold_resist = coldResist, lightning = colorCodes.LIGHTNING, lightning_resist = lightningResist, chaos = colorCodes.CHAOS, chaos_resist = chaosResist }))
		tooltip:AddLine(14, localisation:Text("ui.minion_list_control.add_value_tooltip.tooltip_4", { damage = minion.damage }))
		tooltip:AddLine(14, localisation:Text("ui.minion_list_control.add_value_tooltip.tooltip_3", { value = 1 / minion.attackTime }))
		tooltip:AddLine(14, localisation:Text("ui.minion_list_control.add_value_tooltip.tooltip_5", { value = minion.baseMovementSpeed / 10 }))
		if #minion.skillList > 0 then
			tooltip:AddSeparator(10)
			for _, skillId in ipairs(minion.skillList) do
				if self.data.skills[skillId] then
					local color = data.skillColorMap[self.data.skills[skillId].color] or colorCodes.NORMAL
					tooltip:AddLine(14, localisation:Text("ui.minion_list_control.add_value_tooltip.tooltip_14", { color = color, name = localisation:Field(self.data.skills[skillId], "name") }))
				end
			end
		end
		tooltip:AddSeparator(10)
		if #minion.spawnLocation > 0 then
			local coloredLocations = {}
			for index in ipairs(minion.spawnLocation) do
				local location = localisation:Line(minion, 'spawnLocation', index)
				local mainText, bracket = location:match("^(.-)%s*(%b())%s*$")
				table.insert(coloredLocations, bracket and (colorCodes.RELIC .. mainText .. " " .. "^7" .. bracket) or (colorCodes.RELIC .. location))
			end
			for i, spawn in ipairs(coloredLocations) do
				if i == 1 then
					tooltip:AddLine(14, localisation:Text("ui.minion_list_control.add_value_tooltip.tooltip_15", { spawn = spawn }))
				else
					tooltip:AddLine(14, s_format("^7%s%s", "            ", spawn)) -- Indented so all locations line up vertically in tooltip
				end
			end
		end
	end
end

function MinionListClass:GetDragValue(index, value)
	return "MinionId", value
end

function MinionListClass:CanReceiveDrag(type, value)
	return type == "MinionId" and not isValueInArray(self.list, value)
end

function MinionListClass:ReceiveDrag(type, value, source)
	t_insert(self.list, self.selDragIndex or #self.list + 1, value)
end

function MinionListClass:OnSelClick(index, minionId, doubleClick)
	if doubleClick and self.dest then
		self:AddSel()
	end
end

function MinionListClass:OnSelDelete(index, minionId)
	if not self.dest then
		t_remove(self.list, index)
		self.selIndex = nil
		self.selValue = nil
	end
end

---@class SpawnListControl: ListControl
local SpawnListClass = newClass("SpawnListControl", "ListControl")

function SpawnListClass:SpawnListControl(anchor, rect, data, list, label)
	self:ListControl(anchor, rect, 16, "VERTICAL", false)
	self.data = data
	self.label = label or localisation:Label("ui.minion_list_control.spawn_list_control.label")
	return self
end

function SpawnListClass:GetRowValue(column, index, spawnLocation)
	local area = spawnAreas[spawnLocation]
	if area then return localisation:Field(area, 'name') end
	local location = spawnLocations[spawnLocation]
	if location then return localisation:Line(location.minion, 'spawnLocation', location.index) end
	return spawnLocation == 'Found in Maps' and localisation:Text('ui.minion_list_control.get_row_value.message') or spawnLocation
end
function SpawnListClass:AddValueTooltip(tooltip, index, value)
	if tooltip:CheckForUpdate(value) then
		local foundArea = spawnAreas[value]
		if foundArea then
			tooltip:AddLine(18, localisation:Field(foundArea, 'name'))
			if foundArea.description and foundArea.description ~= "" then
				tooltip:AddLine(14, colorCodes.CURRENCY .. '"' .. localisation:Field(foundArea, 'description') .. '"')
			end
			if foundArea.bossVarieties and #foundArea.bossVarieties > 0 then
				local bosses = { }
				for index in ipairs(foundArea.bossVarieties) do bosses[index] = localisation:Line(foundArea, 'bossVarieties', index) end
				tooltip:AddLine(14, colorCodes.UNIQUE .. localisation:Text("ui.minion_list_control.add_value_tooltip.tooltip_7", { value = table.concat(bosses, ", ") }))
			end
			tooltip:AddLine(14, localisation:Text("ui.minion_list_control.add_value_tooltip.tooltip", { level = foundArea.level }))
			local biomeNameMap = {
				water_biome = "world.biome.water",
				mountain_biome = "world.biome.mountain",
				grass_biome = "world.biome.grass",
				forest_biome = "world.biome.forest",
				swamp_biome = "world.biome.swamp",
				desert_biome = "world.biome.desert",
				faridun_city = "world.biome.faridun_city",
				ezomyte_city = "world.biome.ezomyte_city",
				vaal_city = "world.biome.vaal_city",
			}
			if #foundArea.tags > 0 then
				local biomeNameList = {}
				for _, tag in ipairs(foundArea.tags) do
					local biomeName = biomeNameMap[tag]
					if biomeName then
						table.insert(biomeNameList, localisation:Text(biomeName))
					end
				end
				if #biomeNameList > 0 then
					tooltip:AddLine(14, localisation:Text("ui.minion_list_control.add_value_tooltip.tooltip_6", { value = table.concat(biomeNameList, ", ") }))
				end
			end
			tooltip:AddSeparator(10)
			tooltip:AddLine(14, localisation:Text("ui.minion_list_control.add_value_tooltip.tooltip_17"))
			for index in ipairs(foundArea.monsterVarieties) do
				tooltip:AddLine(14, " - " .. localisation:Line(foundArea, 'monsterVarieties', index))
			end
		elseif value == "Found in Maps" then
			-- no tooltip
		else
			tooltip:AddLine(18, localisation:Text("ui.minion_list_control.add_value_tooltip.tooltip_18", { value = self:GetRowValue(1, index, value) }))
		end
	end
end
