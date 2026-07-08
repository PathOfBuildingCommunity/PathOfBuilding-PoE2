-- Path of Building
--
-- Class: Label Control
-- Simple text label.
--
local LabelClass = newClass("LabelControl", "Control", function(self, anchor, rect, label)
	self.Control(anchor, rect)
	self.label = label
	self.width = function()
		return StyledDrawStringWidth(self:GetProperty("height"), 'text_label', self:GetProperty("label"))
	end
end)

function LabelClass:Draw()
	local x, y = self:GetPos()
	SetDrawStyle('text_label')
	StyledDrawString(x, y, "LEFT", self:GetProperty("height"), 'text_label', self:GetProperty("label"))
end