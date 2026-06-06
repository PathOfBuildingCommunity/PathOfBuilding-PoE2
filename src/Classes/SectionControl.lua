-- Path of Building
--
-- Class: Section Control
-- Section box with label
--

local SectionClass = newClass("SectionControl", "Control", function(self, anchor, rect, label)
	self.Control(anchor, rect)
	self.label = label
end)

function SectionClass:Draw()
	local x, y = self:GetPos()
	local width, height = self:GetSize()
	-- Section-Border
	SetDrawLayer(nil, -10)
	SetDrawStyle('section_border')
	DrawImage(nil, x, y, width, height)
	-- Section-Fill
	SetDrawStyle('section_background')
	DrawImage(nil, x + 2, y + 2, width - 4, height - 4)
	SetDrawLayer(nil, 0)
	local label = self:GetProperty("label")
	local labelWidth = StyledDrawStringWidth(14, 'text_section_title', label)
	-- Section-Title-Border
	SetDrawStyle('section_border_title')
	DrawImage(nil, x + 6, y - 8, labelWidth + 6, 18)
	-- Section-Title-Fill
	SetDrawStyle('section_background_title')
	DrawImage(nil, x + 7, y - 7, labelWidth + 4, 16)
	-- Section-Title
	SetDrawStyle('text_section_title')
	StyledDrawString(x + 9, y - 6, "LEFT", 14, 'text_section_title', label)
end