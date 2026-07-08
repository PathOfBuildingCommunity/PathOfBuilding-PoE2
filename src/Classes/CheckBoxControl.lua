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
	self.labelWidth = StyledDrawStringWidth(self.width - 4, 'text_label', label or "") + 5
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
	-- Checkbox-Border
	if not enabled then
		SetDrawStyle('checkbox_border_disabled')
	elseif mOver then
		SetDrawStyle('checkbox_border_hover')
	elseif self.borderFunc then
		SetDrawStyle('checkbox'..self.borderFunc())
	elseif self.checkImage and self.state then
		-- TODO: why different border when using image instead of checkmark?
		SetDrawStyle('checkbox_border_toggled')
	else
		SetDrawStyle('checkbox_border')
	end
	DrawImage(nil, x, y, size, size)
	-- Checkbox-Fill
	if not enabled then
		SetDrawStyle('checkbox_background_disabled')
	elseif self.clicked and mOver then
		SetDrawStyle('checkbox_background_clicked')
	elseif mOver then
		SetDrawStyle('checkbox_background_hover')
	else
		SetDrawStyle('checkbox_background')
	end
	DrawImage(nil, x + 1, y + 1, size - 2, size - 2)
	-- Checkbox-Checkmark
	if self.checkImage then
		if self.state then
			if not enabled then
				SetDrawStyle('checkbox_checkimage_disabled')
			elseif mOver then
				SetDrawStyle('checkbox_checkimage_hover')
			else
				SetDrawStyle('checkbox_checkimage_toggled')
			end
		else
			SetDrawStyle('checkbox_checkimage')
		end
		DrawImage(self.checkImage.handle, x + 1, y + 1, size - 2, size - 2, self.checkImage[1])
	else
		if self.state then
			if not enabled then
				SetDrawStyle('checkbox_checkmark_disabled')
			elseif mOver then
				SetDrawStyle('checkbox_checkmark_hover')
			else
				SetDrawStyle('checkbox_checkmark')
			end
			main:DrawCheckMark(x + size/2, y + size/2, size * 0.8)
		end
	end
	-- Checkbox-Label-Text
	if enabled then
		SetDrawStyle('text_label')
	else
		SetDrawStyle('text_disabled')
	end
	local label = self:GetProperty("label")
	if label then
		StyledDrawString(x - 5, y + 2, "RIGHT_X", size - 4, 'text_label', label)
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
