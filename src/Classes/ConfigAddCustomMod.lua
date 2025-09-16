-- Path of Building
--
-- Class: Config Set List
-- Config Set list control
--
local t_insert = table.insert
local t_remove = table.remove
local m_max = math.max

local ConfigAddCustomModClass = newClass("ConfigAddCustomMod", "ListControl", function(self, anchor, rect, configTab)

    local mods = {}

	-- format keys to allow for collisions and subsequent removal
	local replacements = {"x", "y", "z", "w", "v"}
	for key, _ in pairs(modLib.parseModCache) do
		local strKey = tostring(key)
		if strKey ~= "" then
			local idx = 0
			-- replace ranges, decimals, dice numbers
			local cleanKey = strKey:gsub("(%d+[%d%.d%-]*)", function()
				idx = idx + 1
				return replacements[idx] or "{value}"
			end)
			-- remove parentheses that are left around single placeholders
			cleanKey = cleanKey:gsub("%((%w+)%)", "%1")
			mods[cleanKey] = {}
		end
	end

	-- convert keys to sequential array for ListControl
    self.modStrings = {}
    for k in pairs(mods) do
        t_insert(self.modStrings, k)
    end
    table.sort(self.modStrings)
	local keys = {}
	for key, _ in pairs(mods) do
		if keys[key] then
			-- remove duplicate
			mods[key] = nil 
		else
			keys[key] = true
		end
	end
	keys = nil
	self.selValue = self.modStrings[1]

	self.controls = self.controls or {}
    self.ListControl(anchor, rect, 16, "VERTICAL", true, self.modStrings)
	self.configTab = configTab
end)

function ConfigAddCustomModClass:OnSelClick(selIndex, selValue, doubleClick)
    -- do whatever you want immediately when selection changes
    print("New selection:", selValue)
end

function ConfigAddCustomModClass:GetRowValue(column, index, modId)
	local modStr = self.modStrings[index] or "Unknown Mod"
	if column == 1 then
		return modStr
	end
end

function ConfigAddCustomModClass:OnOrderChange()
	self.configTab.modFlag = true
end



function ConfigAddCustomModClass:OnSelKeyDown(index, configSetId, key)
	if key == "F2" then
		self:RenameSet(self.configTab.configSets[configSetId])
	end
end
