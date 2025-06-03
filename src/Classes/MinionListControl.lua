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

local MinionListClass = newClass("MinionListControl", "ListControl", function(self, anchor, rect, data, list, dest, label)
	self.ListControl(anchor, rect, 16, "VERTICAL", not dest, list)
	self.data = data
	self.dest = dest
	if dest then
		self.dragTargetList = { dest }
		self.label = label or "^7Available Spectres:"
		self.controls.add = new("ButtonControl", {"BOTTOMRIGHT",self,"TOPRIGHT"}, {0, -2, 60, 18}, "Add", function()
			self:AddSel()
		end)
		self.controls.add.enabled = function()
			return self.selValue ~= nil and not isValueInArray(dest.list, self.selValue)
		end
	else
		self.label = label or "^7Spectres in Build:"
		self.controls.delete = new("ButtonControl", {"BOTTOMRIGHT",self,"TOPRIGHT"}, {0, -2, 60, 18}, "Remove", function()
			self:OnSelDelete(self.selIndex, self.selValue)
		end)
		self.controls.delete.enabled = function()
			return self.selValue ~= nil
		end
	end
end)

function MinionListClass:AddSel()
	if self.dest and not isValueInArray(self.dest.list, self.selValue) then
		t_insert(self.dest.list, self.selValue)
	end
end

function MinionListClass:GetRowValue(column, index, minionId)
	local minion = self.data.minions[minionId]
	if column == 1 then
		return minion.name
	end
end

function MinionListClass:AddValueTooltip(tooltip, index, minionId)
	if tooltip:CheckForUpdate(minionId) then
		local minion = self.data.minions[minionId]
		tooltip:AddLine(18, "^7"..minion.name)
		tooltip:AddSeparator(10)
		tooltip:AddLine(14, s_format("^7Spectre Reservation: %s%d", colorCodes.SPIRIT, tostring(minion.spectreReservation)))
		tooltip:AddLine(14, s_format("^7Companion Reservation: %s%s%%", colorCodes.SPIRIT, tostring(minion.companionReservation)))
		tooltip:AddLine(14, "^7Category: "..minion.monsterCategory)
		tooltip:AddLine(14, s_format("^7Life Multiplier: x%.2f", minion.life))
		if minion.energyShield then
			tooltip:AddLine(14, s_format("^7Energy Shield: %d%% of base Life", minion.energyShield * 100))
		end
		if minion.armour then
			tooltip:AddLine(14, s_format("^7Armour Multiplier: x%.2f", 1 + minion.armour))
		end
		if minion.evasion then
			tooltip:AddLine(14, s_format("^7Evasion Multiplier: x%.2f", 1 + minion.evasion))
		end
		tooltip:AddLine(14, s_format("^7Resistances: %s%d ^7/ %s%d ^7/ %s%d ^7/ %s%d",
			colorCodes.FIRE, minion.fireResist, 
			colorCodes.COLD, minion.coldResist, 
			colorCodes.LIGHTNING, minion.lightningResist, 
			colorCodes.CHAOS, minion.chaosResist
		))
		tooltip:AddLine(14, s_format("^7Base Damage: x%.2f", minion.damage))
		tooltip:AddLine(14, s_format("^7Base Attack Speed: %.2f", 1 / minion.attackTime))
		tooltip:AddLine(14, s_format("^7Base Movement Speed: %.2f", minion.baseMovementSpeed / 10))
		for _, skillId in ipairs(minion.skillList) do
			if self.data.skills[skillId] then
				tooltip:AddLine(14, "^7Skill: "..self.data.skills[skillId].name)
			end
		end
		tooltip:AddSeparator(10)
		if #minion.spawnLocation > 0 then
			local coloredLocations = {}
			for _, location in ipairs(minion.spawnLocation) do -- Print (Map) or (Act 7) in white, and map name in green. 
				local mainText, bracket = location:match("^(.-)%s*(%b())%s*$")
				table.insert(coloredLocations, bracket and (colorCodes.RELIC .. mainText .. " " .. "^7" .. bracket) or (colorCodes.RELIC .. location))
			end
			for i, spawn in ipairs(coloredLocations) do
				if i == 1 then
					tooltip:AddLine(14, s_format("^7Spawn: %s", spawn))
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

local SpawnListClass = newClass("SpawnListControl", "ListControl", function(self, anchor, rect, data, list, label)
	self.ListControl(anchor, rect, 16, "VERTICAL", false)
	self.data = data
	self.label = label or "^7Available Items:"
end)

function SpawnListClass:GetRowValue(column, index, spawnLocation)
		return spawnLocation
end
function SpawnListClass:AddValueTooltip(tooltip, index, value)
	if tooltip:CheckForUpdate(value) then
		local foundArea = nil
		for _, area in pairs(data.worldAreas) do
			if area.name == value and #area .monsterVarieties > 0 then
				foundArea = area
				break
			end
		end
		if foundArea then
			tooltip:AddLine(18, foundArea.name)
			if foundArea.description and foundArea.description ~= "" then
				tooltip:AddLine(14, colorCodes.CURRENCY .. '"' .. foundArea.description .. '"')
			end
			if foundArea.bossVarieties and #foundArea.bossVarieties > 0 then
				tooltip:AddLine(14, colorCodes.UNIQUE.. "Bosses: ^7" .. table.concat(foundArea.bossVarieties, ", "))
			end
			tooltip:AddLine(14, "^7Area Level: "..foundArea.level)
			local biomeNameMap = {
				water_biome = "Water",
				mountain_biome = "Mountain",
				grass_biome = "Grass",
				forest_biome = "Forest",
				swamp_biome = "Swamp",
				desert_biome = "Desert",
				faridun_city = "Faridun City",
				ezomyte_city = "Ezomyte City",
				vaal_city = "Vaal City",
			}
			if #foundArea.tags > 0 then
				local biomeNameList = {}
				for _, tag in ipairs(foundArea.tags) do
					local biomeName = biomeNameMap[tag]
					if biomeName then
						table.insert(biomeNameList, biomeName)
					end
				end
				if #biomeNameList > 0 then
					tooltip:AddLine(14, "^7Biome: " .. table.concat(biomeNameList, ", "))
				end
			end
			tooltip:AddSeparator(10)
			tooltip:AddLine(14, "^7Spectres:")
			for _, monsterName in ipairs(foundArea.monsterVarieties) do
				tooltip:AddLine(14, " - " .. monsterName)
			end
		elseif value == "Found in Maps" then
			-- no tooltip
		else
			tooltip:AddLine(18, "^7World area not found: " .. tostring(value))
		end
	end
end