-- Path of Building
--
-- Class: Label Control
-- Simple text label.
--
local LabelClass = newClass("LabelControl", "Control", "TooltipHost", function(self, anchor, rect, label)
	self.Control(anchor, rect)
	self.TooltipHost()
	self.label = label
	self.width = function()
		return DrawStringWidth(self:GetProperty("height"), "VAR", self:GetProperty("label"))
	end
end)

-- Labels are mouse-transparent unless a tooltip has been set on them, so they
-- never intercept hover or clicks meant for surrounding controls
function LabelClass:IsMouseOver()
	if not self:IsShown() or not (self.tooltipText or self.tooltipFunc) then
		return false
	end
	return self:IsMouseInBounds()
end

function LabelClass:Draw(viewPort)
	local x, y = self:GetPos()
	DrawString(x, y, "LEFT", self:GetProperty("height"), "VAR", self:GetProperty("label"))
	if self:IsMouseOver() then
		SetDrawLayer(nil, 100)
		local width, height = self:GetSize()
		self:DrawTooltip(x, y, width, height, viewPort)
		SetDrawLayer(nil, 0)
	end
end
