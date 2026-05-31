-- Path of Building
--
-- Class: Level Range
-- Level Range controls to be reused for sets and the .build file
--

local LevelRangeClass = newClass("LevelRangeControl", "ControlHost", "Control", function(self, anchor, rect, set)
	self.ControlHost()
	self.Control(anchor, rect)
	self.set = set
	self.controls = {}
	self.controls.minLevel = new("EditControl", {"TOPLEFT",self,"TOPLEFT"}, {0, 0, 150, 20}, set.levelMin or 0, "Level Min", "%D", 3, function(buf)
		self.set.levelMin = tonumber(buf)
	end)
	self.controls.minLevel:SetPlaceholder("0")
	self.controls.maxLevel = new("EditControl", {"TOPLEFT",self.controls.minLevel,"TOPRIGHT"}, {10, 0, 150, 20}, set.levelMax or 100, "Level Max", "%D", 3, function(buf)
		self.set.levelMax = tonumber(buf)
	end)
	self.controls.maxLevel:SetPlaceholder("100")
end)

function LevelRangeClass:LoadSet(set)
	self.set = set
	self.controls.minLevel.buf = tostring(set.levelMin or "")
	self.controls.maxLevel.buf = tostring(set.levelMax or "")
end

function LevelRangeClass:IsMouseOver()
	if not self:IsShown() then
		return false
	end
	return self:IsMouseInBounds() or self:GetMouseOverControl()
end

function LevelRangeClass:OnKeyDown(key, doubleClick)
	if not self:IsShown() or not self:IsEnabled() then
		return
	end
	local mOverControl = self:GetMouseOverControl()
	if mOverControl and mOverControl.OnKeyDown then
		return mOverControl:OnKeyDown(key, doubleClick)
	end
end

function LevelRangeClass:Draw()
	self:DrawControls()
end