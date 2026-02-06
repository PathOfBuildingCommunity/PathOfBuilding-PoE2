-- Path of Building
--
-- Class: Popup Dialog
-- Popup Dialog Box with a configurable list of controls
--
local m_floor = math.floor
local lastTraderSortLogTime = 0

local PopupDialogClass = newClass("PopupDialog", "ControlHost", "Control", function(self, width, height, title, controls, enterControl, defaultControl,
									escapeControl, scrollBarFunc, resizeFunc, topMarginFraction)
	self.ControlHost()
	self.Control(nil, {0, 0, width, height})
	self.x = function()
		return m_floor((main.screenW - width) / 2)
	end
	self.y = function()
		if topMarginFraction and topMarginFraction > 0 and topMarginFraction < 1 then
			return m_floor(main.screenH * topMarginFraction)
		end
		return m_floor((main.screenH - height) / 2)
	end
	self.title = title
	self.controls = controls
	self.enterControl = enterControl
	self.escapeControl = escapeControl
	for id, control in pairs(self.controls) do
		if not control.anchor.point then
			control:SetAnchor("TOP", self, "TOP")
		elseif not control.anchor.other then
			control.anchor.other = self
		elseif type(control.anchor.other) ~= "table" then
			control.anchor.other = self.controls[control.anchor.other]
		end
	end
	if defaultControl then
		self:SelectControl(self.controls[defaultControl])
	end
	-- allow scrollbar functionality inside of popups
	self.scrollBarFunc = scrollBarFunc
	-- allow resizing of popup
	self.resizeFunc = resizeFunc
end)

function PopupDialogClass:Draw(viewPort)
	local x, y = self:GetPos()
	local width, height = self:GetSize()
	-- #region agent log
	if self.title == "Trader" and self.controls.sortPanelBox then
		local t = os.clock()
		if t - lastTraderSortLogTime >= 1 then
			lastTraderSortLogTime = t
		local box = self.controls.sortPanelBox
		local boxShown = box:IsShown()
		local bx, by, bw, bh = 0, 0, 0, 0
		if boxShown then
			bx, by = box:GetPos()
			bw, bh = box:GetSize()
		end
		local c1x, c1y, c2x, c2y = 0, 0, 0, 0
		if self.controls.sortPanelCol1Label and self.controls.sortPanelCol1Label:IsShown() then
			c1x, c1y = self.controls.sortPanelCol1Label:GetPos()
		end
		if self.controls.sortPanelCol2Label and self.controls.sortPanelCol2Label:IsShown() then
			c2x, c2y = self.controls.sortPanelCol2Label:GetPos()
		end
		local logPath = "c:\\Users\\xpret\\AppData\\Roaming\\Path of Building Community (PoE2)\\.cursor\\debug.log"
		local f = io.open(logPath, "a")
		if f then
			local line = string.format('{"location":"PopupDialog.lua:Draw","message":"Trader sort panel pos","data":{"popupX":%d,"popupY":%d,"popupW":%d,"popupH":%d,"screenW":%d,"screenH":%d,"boxShown":%s,"boxX":%d,"boxY":%d,"boxW":%d,"boxH":%d,"col1X":%d,"col1Y":%d,"col2X":%d,"col2Y":%d},"timestamp":%d,"sessionId":"debug-session","hypothesisId":"H1_H2_H3"}', x, y, width, height, main.screenW, main.screenH, tostring(boxShown), bx, by, bw, bh, c1x, c1y, c2x, c2y, (os.time() or 0) * 1000)
			f:write(line .. "\n")
			f:close()
		end
		end
	end
	-- #endregion
	-- Draw dialog background
	SetDrawColor(0.8, 0.8, 0.8)
	DrawImage(nil, x, y, width, height)
	SetDrawColor(0.1, 0.1, 0.1)
	DrawImage(nil, x + 2, y + 2, width - 4, height - 4)
	-- Draw dialog title box
	local title = self:GetProperty("title")
	local titleWidth = DrawStringWidth(16, "VAR", title)
	local titleX = x + m_floor((width - titleWidth - 8) / 2)
	SetDrawColor(1, 1, 1)
	DrawImage(nil, titleX, y - 10, titleWidth + 8, 24)
	SetDrawColor(0, 0, 0)
	DrawImage(nil, titleX + 2, y - 8, titleWidth + 4, 20)
	SetDrawColor(1, 1, 1)
	DrawString(titleX + 4, y - 7, "LEFT", 16, "VAR", title)
	if self.scrollBarFunc then
		self.scrollBarFunc()
	end
	if self.resizeFunc then
		self.resizeFunc()
	end
	-- Draw controls
	self:DrawControls(viewPort)
end

function PopupDialogClass:ProcessInput(inputEvents, viewPort)
	self:ProcessControlsInput(inputEvents, viewPort)
	for id, event in ipairs(inputEvents) do
		if event.type == "KeyDown" then
			if event.key == "ESCAPE" then
				if self.escapeControl then
					self.controls[self.escapeControl]:Click()
				else
					main:ClosePopup()
				end
				return
			elseif event.key == "RETURN" then
				if self.enterControl then
					self.controls[self.enterControl]:Click()
					return
				end
			end
		elseif self.scrollBarFunc and event.type == "KeyUp" then
			if self.controls.scrollBar:IsScrollDownKey(event.key) then
				self.controls.scrollBar:Scroll(1)
			elseif self.controls.scrollBar:IsScrollUpKey(event.key) then
				self.controls.scrollBar:Scroll(-1)
			end
		end
	end
end