-- Path of Building
--
-- Class: Button Control
-- Basic button control.
--
local ButtonClass = newClass("ButtonControl", "Control", "TooltipHost", function(self, anchor, rect, label, onClick, onHover, forceTooltip)
	self.Control(anchor, rect)
	self.TooltipHost()
	self.label = label
	self.onClick = onClick
	self.onHover = onHover
	self.forceTooltip = forceTooltip
end)

function ButtonClass:Click()
	if self:IsShown() and self:IsEnabled() then
		self.onClick()
	end
end

function ButtonClass:SetImage(path)
	if path then
		self.image = NewImageHandle()
		self.image:Load(path)
	else
		self.image = nil
	end
end

function ButtonClass:IsMouseOver()
	if not self:IsShown() then
		return false
	end
	return self:IsMouseInBounds()
end

function ButtonClass:Draw(viewPort, noTooltip)
	local x, y = self:GetPos()
	local width, height = self:GetSize()
	local enabled = self:IsEnabled()
	local mOver = self:IsMouseOver()
	local locked = self:GetProperty("locked")
	-- Button-Border
	if not enabled then
		SetDrawStyle('button_border_disabled')
	elseif mOver then
		SetDrawStyle('button_border_hover')
	elseif locked then
		SetDrawStyle('button_border_toggled')
	else
		SetDrawStyle('button_border')
	end
	DrawImage(nil, x, y, width, height)
	-- Button-Fill
	if not enabled then
		SetDrawStyle('button_background_disabled')
	elseif self.clicked and mOver then
		SetDrawStyle('button_background_clicked')
	elseif locked then
		SetDrawStyle('button_background_toggled')
	elseif mOver then
		SetDrawStyle('button_background_hover')
	else
		SetDrawStyle('button_background')
	end
	DrawImage(nil, x + 1, y + 1, width - 2, height - 2)
	-- Button-Image
	if self.image then
		if enabled then
			SetDrawStyle('button_image')
		else
			SetDrawStyle('button_image_disabled')
		end
		DrawImage(self.image, x + 2, y + 2, width - 4, height - 4)
		if self.clicked and mOver then
			SetDrawStyle('button_image_overlay_clicked')
			DrawImage(nil, x + 1, y + 1, width - 2, height - 2)
		end
	end
	-- Button-Text
	if enabled then
		SetDrawStyle('text_button')
	else
		SetDrawStyle('text_button_disabled')
	end
	local label = self:GetProperty("label")
	if label == "+" then
		DrawImage(nil, x + width * 0.2, y + height * 0.45, width * 0.6, height * 0.1)
		DrawImage(nil, x + width * 0.45, y + height * 0.2, width * 0.1, height * 0.6)
	elseif label == "-" then
		DrawImage(nil, x + width * 0.2, y + height * 0.45, width * 0.6, height * 0.1)
	elseif label == "x" then
		DrawImageQuad(nil, x + width * 0.2, y + height * 0.3, x + width * 0.3, y + height * 0.2, x + width * 0.8, y + height * 0.7, x + width * 0.7, y + height * 0.8)
		DrawImageQuad(nil, x + width * 0.7, y + height * 0.2, x + width * 0.8, y + height * 0.3, x + width * 0.3, y + height * 0.8, x + width * 0.2, y + height * 0.7)
	else
		local overSize = self.overSizeText or 0
		StyledDrawString(x + width / 2, y + 2 - overSize, "CENTER_X", height - 4 + overSize * 2, 'text_button', label)
	end
	if mOver then
		if not noTooltip or self.forceTooltip then
			SetDrawLayer(nil, 100)
			self:DrawTooltip(x, y, width, height, viewPort)
			SetDrawLayer(nil, 0)
		end
		if self.onHover ~= nil then
			return self.onHover()
		end
	end
end

function ButtonClass:OnKeyDown(key)
	if not self:IsShown() or not self:IsEnabled() then
		return
	end
	if key == "LEFTBUTTON" then
		self.clicked = true
	elseif self.enterFunc then
		self.enterFunc()
	end
	return self
end

function ButtonClass:OnKeyUp(key)
	if not self:IsShown() or not self:IsEnabled() then
		return
	end
	if key == "LEFTBUTTON" and self.clicked then
		self.clicked = false
		if self:IsMouseOver() then
			return self.onClick()
		end
	end
	self.clicked = false
end
