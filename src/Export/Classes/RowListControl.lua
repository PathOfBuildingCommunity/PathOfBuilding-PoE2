-- Dat View
--
-- Class: Row List
-- Row list control.
--
local ipairs = ipairs
local t_insert = table.insert

local RowListClass = newClass("RowListControl", "ListControl", function(self, anchor, rect)
	self.ListControl(anchor, rect, 14, "HORIZONTAL", false, { })
	self.colLabels = true
end)

function RowListClass:BuildRows(filter)
	wipeTable(self.list)
	local filterFunc
	main.controls.filterError.label = ""
	if filter:match("%S") then
		local error
		filterFunc, error = loadstring([[
			return ]]..filter..[[
		]])
		if error then
			main.controls.filterError.label = "^7"..error
		end
	end
	for rowIndex, row in ipairs(main.curDatFile.rows) do
		if filterFunc then
			setfenv(filterFunc, main.curDatFile:GetRowByIndex(rowIndex))
			local status, result = pcall(filterFunc)
			if status then
				if result then
					t_insert(self.list, rowIndex)
				end
			else
				main.controls.filterError.label = string.format("^7Row %d: %s", rowIndex, result)
				return
			end
		else
			t_insert(self.list, rowIndex)
		end
	end
end

function RowListClass:BuildColumns()
	wipeTable(self.colList)
	self.colList[1] = { width = 50, label = "#", font = "FIXED", sortable = true }
	for _, specCol in ipairs(main.curDatFile.spec) do
		t_insert(self.colList, { 
			width = specCol.width, 
			label = specCol.name, 
			font = function() return IsKeyDown("CTRL") and "FIXED" or "VAR" end,
			sortable = true
		})
	end
	local short = main.curDatFile.rowSize - main.curDatFile.specSize
	if short > 0 then
		t_insert(self.colList, { width = short * DrawStringWidth(self.rowHeight, "FIXED", "00 "), font = "FIXED", sortable = true })
	end
end

function RowListClass:GetRowValue(column, index, row)
	if column == 1 then
		return string.format("%5d", row)
	end
	if not main.curDatFile.spec[column - 1] or IsKeyDown("CTRL") then
		local out = { main.curDatFile:ReadCellRaw(row, column - 1) }
		for i, b in ipairs(out) do
			out[i] = string.format("%02X", b)
		end
		return table.concat(out, main.curDatFile.spec[column - 1] and "" or " ")
	else
		local data = main.curDatFile:ReadCellText(row, column - 1)
		if type(data) == "table" then
			for i, v in ipairs(data) do
				data[i] = tostring(v)
			end
			return table.concat(data, ", ")
		else
			return tostring(data)
		end
	end
end

function RowListClass:Draw(viewPort)
	local x, y = self:GetPos()
	local width, height = self:GetSize()
	local rowHeight = self.rowHeight
	local list = self.list

	local colOffset = 0
	for index, column in ipairs(self.colList) do
		column._offset = colOffset
		column._width = self:GetColumnProperty(column, "width") or (index == #self.colList and self.scroll and width - 20 or width - colOffset) or 0
		colOffset = colOffset + column._width
	end

	local scrollBarV = self.controls.scrollBarV
	local rowRegion = self:GetRowRegion()
	scrollBarV:SetContentDimension(#list * rowHeight, rowRegion.height)
	local scrollOffsetV = scrollBarV.offset
	local scrollBarH = self.controls.scrollBarH
	local lastCol = self.colList[#self.colList]
	scrollBarH:SetContentDimension(lastCol._offset + lastCol._width, rowRegion.width)
	local scrollOffsetH = scrollBarH.offset

	local cursorX, cursorY = GetCursorPos()

	local label = self:GetProperty("label") 
	if label then
		DrawString(x + self.labelPositionOffset[1], y - 20 + self.labelPositionOffset[2], "LEFT", 16, self.font, label)
	end
	if self.hasFocus then
		SetDrawColor(1, 1, 1)
	else
		SetDrawColor(0.5, 0.5, 0.5)
	end
	DrawImage(nil, x, y, width, height)
	SetDrawColor(0, 0, 0)
	DrawImage(nil, x + 1, y + 1, width - 2, height - 2)
	self:DrawControls(viewPort)

	SetViewport(x + 2, y + 2,  self.scroll and width - 20 or width, height - 4 - (self.scroll and self.scrollH and 16 or 0))
	local textOffsetY = self.showRowSeparators and 2 or 0
	local textHeight = rowHeight - textOffsetY * 2
	local minIndex = math.floor(scrollOffsetV / rowHeight + 1)
	local maxIndex = math.min(math.floor((scrollOffsetV + height) / rowHeight + 1), #list)
	for colIndex, column in ipairs(self.colList) do
		local colFont = self:GetColumnProperty(column, "font") or "VAR"
		local clipWidth = DrawStringWidth(textHeight, colFont, "...")
		colOffset = column._offset - scrollOffsetH
		local colWidth = column._width
		local relX = cursorX - (x + 2)
		local relY = cursorY - (y + 2)
		for index = minIndex, maxIndex do
			local lineY = rowHeight * (index - 1) - scrollOffsetV + (self.colLabels and 18 or 0)
			local value = list[index]
			local text = self:GetRowValue(colIndex, index, value)
			local textWidth = DrawStringWidth(textHeight, colFont, text)
			if textWidth > colWidth - 2 then
				local clipIndex = DrawStringCursorIndex(textHeight, colFont, text, colWidth - clipWidth - 2, 0)
				text = text:sub(1, clipIndex - 1) .. "..."
				textWidth = DrawStringWidth(textHeight, colFont, text)
			end
			if self.showRowSeparators then
				if self.hasFocus and value == self.selValue then
					SetDrawColor(1, 1, 1)
				else
					SetDrawColor(0.5, 0.5, 0.5)
				end
				DrawImage(nil, colOffset, lineY, not self.scroll and colWidth - 4 or colWidth, rowHeight)
				if index % 2 == 0 then
					SetDrawColor(0.05, 0.05, 0.05)
				else
					SetDrawColor(0, 0, 0)
				end
				DrawImage(nil, colOffset, lineY + 1, not self.scroll and colWidth - 4 or colWidth, rowHeight - 2)
			elseif value == self.selValue then
				if self.hasFocus and value == self.selValue then
					SetDrawColor(1, 1, 1)
				else
					SetDrawColor(0.5, 0.5, 0.5)
				end
				DrawImage(nil, colOffset, lineY, not self.scroll and colWidth - 4 or colWidth, rowHeight)
				SetDrawColor(0.15, 0.15, 0.15)
				DrawImage(nil, colOffset, lineY + 1, not self.scroll and colWidth - 4 or colWidth, rowHeight - 2)
			end
			if not self.SetHighlightColor or not self:SetHighlightColor(index, value) then
				SetDrawColor(1, 1, 1)
			end
			DrawString(colOffset, lineY + textOffsetY, "LEFT", textHeight, colFont, text)
		end
		if self.colLabels then
			local mOver = relX >= colOffset and relX <= colOffset + colWidth and relY >= 0 and relY <= 18

			local isSelected = (colIndex - 1) == main.curSpecColIndex
			local outerColor
			if mOver then
				outerColor = {1, 1, 1}
			elseif isSelected then
				outerColor = {1, 0.3, 0.2}
			else
				outerColor = {0.5, 0.5, 0.5}
			end
			local innerColor = isSelected and {0.6, 0.25, 0.2} or (mOver and self:GetColumnProperty(column, "sortable") and {0.33, 0.33, 0.33} or {0.15, 0.15, 0.15})

			SetDrawColor(unpack(outerColor))
			DrawImage(nil, colOffset, 1, colWidth, 18)
			SetDrawColor(unpack(innerColor))
			DrawImage(nil, colOffset + 1, 2, colWidth - 2, 16)

			local label = self:GetColumnProperty(column, "label")
			if label and #label > 0 then
				SetDrawColor(1, 1, 1)
				DrawString(colOffset + colWidth/2, 4, "CENTER_X", 12, "VAR", label)
			end
		end
	end
	if #self.list == 0 and self.defaultText then
		SetDrawColor(1, 1, 1)
		DrawString(2, 2, "LEFT", 14, self.font, self.defaultText)
	end
	SetViewport()
end

function RowListClass:ReSort(colIndex)
	local asc = true
	if self.lastSortedCol == colIndex then
		asc = not self.sortAsc
	end

	table.sort(self.list, function(a, b)
		local valA = self:GetRowValue(colIndex, nil, a)
		local valB = self:GetRowValue(colIndex, nil, b)

		local numA = tonumber(valA)
		local numB = tonumber(valB)

		if numA and numB then
			if asc then
				return numA < numB
			else
				return numA > numB
			end
		else
			valA = tostring(valA or "")
			valB = tostring(valB or "")
			if asc then
				return valA < valB
			else
				return valA > valB
			end
		end
	end)

	self.lastSortedCol = colIndex
	self.sortAsc = asc
end
