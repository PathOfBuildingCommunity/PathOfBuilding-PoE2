-- Path of Building
--
-- Class: Check Box Control
-- Basic check box control.
--
local CheckBoxClass = newClass("CheckBoxControl", "Control", "TooltipHost", function(self, anchor, rect, label, changeFunc, tooltipText, initialState)
	rect[4] = rect[3] or 0
	self.Control(anchor, rect)
	self.TooltipHost(tooltipText)
	self.label = label
	self.labelWidth = DrawStringWidth(self.width - 4, "VAR", label or "") + 5
	self.changeFunc = changeFunc
	self.state = initialState
	self.checkImage = nil
end)

function CheckBoxClass:IsMouseOver()
	if not self:IsShown() then
		return false
	end
	local x, y = self:GetPos()
	local width, height = self:GetSize()
	local cursorX, cursorY = GetCursorPos()

	-- move x left by label width, increase width by label width
	local label = self:GetProperty("label")
	if label then
		x = x - self.labelWidth
		width = width + self.labelWidth
	end
	return cursorX >= x and cursorY >= y and cursorX < x + width and cursorY < y + height
end

function CheckBoxClass:Draw(viewPort, noTooltip)
	local x, y = self:GetPos()
	local size = self.width
	local enabled = self:IsEnabled()
	local mOver = self:IsMouseOver()
	if not enabled then
		SetDrawColor(0.33, 0.33, 0.33)
	elseif mOver then
		SetDrawColor(1, 1, 1)
	elseif self.borderFunc then
		local r, g, b = self.borderFunc()
		SetDrawColor(r, g, b)
	elseif self.checkImage and self.state then
		SetDrawColor(0.75, 0.75, 0.75)
	else
		SetDrawColor(0.5, 0.5, 0.5)
	end
	DrawImage(nil, x, y, size, size)
	if not enabled then
		SetDrawColor(0, 0, 0)
	elseif self.clicked and mOver then
		SetDrawColor(0.5, 0.5, 0.5)
	elseif mOver then
		SetDrawColor(0.33, 0.33, 0.33)
	else
		SetDrawColor(0, 0, 0)
	end
	DrawImage(nil, x + 1, y + 1, size - 2, size - 2)
	if self.checkImage then
		if self.state then
			if not enabled then
				SetDrawColor(0.33, 0.33, 0.33)
			elseif mOver then
				SetDrawColor(2, 2, 2)
			else
				SetDrawColor(1, 1, 1)
			end
		else
			SetDrawColor(0.5, 0.5, 0.5)
		end
		DrawImage(self.checkImage.handle, x + 1, y + 1, size - 2, size - 2, self.checkImage[1])
	else
		if self.state then
			if not enabled then
				SetDrawColor(0.33, 0.33, 0.33)
			elseif mOver then
				SetDrawColor(1, 1, 1)
			else
				SetDrawColor(0.75, 0.75, 0.75)
			end
			main:DrawCheckMark(x + size/2, y + size/2, size * 0.8)
		end
	end
	if enabled then
		SetDrawColor(1, 1, 1)
	else
		SetDrawColor(0.33, 0.33, 0.33)
	end
	local label = self:GetProperty("label")
	if label then
		DrawString(x - 5, y + 2, "RIGHT_X", size - 4, "VAR", label)
	end
	if mOver and not noTooltip then
		SetDrawLayer(nil, 100)
		self:DrawTooltip(x, y, size, size, viewPort, self.state)
		SetDrawLayer(nil, 0)
	end
end

function CheckBoxClass:OnKeyDown(key)
	if not self:IsShown() or not self:IsEnabled() then
		return
	end
	if key == "LEFTBUTTON" then
		self.clicked = true
	end
	return self
end

function CheckBoxClass:OnKeyUp(key)
	if not self:IsShown() or not self:IsEnabled() then
		return
	end
	if key == "LEFTBUTTON" then
		if self:IsMouseOver() then
			self.state = not self.state
			if self.changeFunc then
				self.changeFunc(self.state)
			end
		end
	end
	self.clicked = false
end

---@param image table @The image to display instead of a check.  Expects a `handle` field with an image handle, and the sprite position at index `1`.  All other fields are ignored.  Set to `nil` to draw a normal check.
function CheckBoxClass:SetCheckImage(image)
	self.checkImage = image
end
