-- Path of Building
--
-- Class: RectangleOutline Control
-- Simple Outline Only Rectangle control
--
local RectangleOutlineClass = newClass("RectangleOutlineControl", "Control", function(self, anchor, rect, style, stroke)
    self.Control(anchor, rect)
    self.stroke = stroke or 1
    self.style = style or 'rectangle_outline_border'
end)

function RectangleOutlineClass:Draw()
    local x, y = self:GetPos()
    SetDrawStyle(self.style)
    DrawImage(nil, x, y, self.width + self.stroke, self.stroke)
    DrawImage(nil, x, y + self.height, self.width + self.stroke, self.stroke)
    DrawImage(nil, x, y, self.stroke, self.height + self.stroke)
    DrawImage(nil, x + self.width, y, self.stroke, self.height + self.stroke)
end
