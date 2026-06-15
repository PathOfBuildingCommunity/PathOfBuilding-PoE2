-- Path of Building
--
-- Class: Tooltip
-- Tooltip
--
local ipairs = ipairs
local t_insert = table.insert
local m_max = math.max
local m_floor = math.floor
local s_gmatch = string.gmatch

-- Constants

local BORDER_WIDTH = 3
local H_PAD	= 12
local V_PAD = 10
-- spell-checker: disable
local headerConfigs = {
	RELIC = {left="itemsheaderfoilleft.png", middle="itemsheaderfoilmiddle.png", right="itemsheaderfoilright.png", height=58, sideWidth=47, middleWidth=47, textYOffset=2, allowInfluenceIcon=true},
	UNIQUE = {left="itemsheaderuniqueleft.png", middle="itemsheaderuniquemiddle.png", right="itemsheaderuniqueright.png", height=58, sideWidth=47, middleWidth=47, textYOffset=2, allowInfluenceIcon=true},
	RARE = {left="itemsheaderrareleft.png", middle="itemsheaderraremiddle.png", right="itemsheaderrareright.png", height=58, sideWidth=47, middleWidth=47, textYOffset=2, allowInfluenceIcon=true},
	MAGIC = {left="itemsheadermagicleft.png", middle="itemsheadermagicmiddle.png", right="itemsheadermagicright.png", height=38, sideWidth=32, middleWidth=32, textYOffset=4, allowInfluenceIcon=true},
	NORMAL = {left="itemsheaderwhiteleft.png", middle="itemsheaderwhitemiddle.png", right="itemsheaderwhiteright.png", height=38, sideWidth=32, middleWidth=32, textYOffset=4, allowInfluenceIcon=true},
	JEWEL = {left="jewelpassiveheaderleft.png", middle="jewelpassiveheadermiddle.png", right="jewelpassiveheaderright.png", height=38, sideWidth=32, middleWidth=32, textYOffset=4},
	NOTABLE = {left="notablepassiveheaderleft.png", middle="notablepassiveheadermiddle.png", right="notablepassiveheaderright.png", height=38, sideWidth=38, middleWidth=32, textYOffset=4},
	PASSIVE = {left="normalpassiveheaderleft.png", middle="normalpassiveheadermiddle.png", right="normalpassiveheaderright.png", height=38, sideWidth=32, middleWidth=32, textYOffset=4},
	KEYSTONE = {left="keystonepassiveheaderleft.png", middle="keystonepassiveheadermiddle.png", right="keystonepassiveheaderright.png", height=38, sideWidth=32, middleWidth=32, textYOffset=4},
	ASCENDANCY = {left="ascendancypassiveheaderleft.png", middle="ascendancypassiveheadermiddle.png", right="ascendancypassiveheaderright.png", height=38, sideWidth=32, middleWidth=32, textYOffset=4},
	ORACLE_PASSIVE = {left="oraclenormalpassiveheaderleft.png", middle="oraclenormalpassiveheadermiddle.png", right="oraclenormalpassiveheaderright.png", height=38, sideWidth=32, middleWidth=32, textYOffset=4},
	ORACLE_NOTABLE = {left="oraclenotablepassiveheaderleft.png", middle="oraclenotablepassiveheadermiddle.png", right="oraclenotablepassiveheaderright.png", height=38, sideWidth=38, middleWidth=32, textYOffset=4},
	ORACLE_KEYSTONE = {left="oraclekeystonepassiveheaderleft.png", middle="oraclekeystonepassiveheadermiddle.png", right="oraclekeystonepassiveheaderright.png", height=38, sideWidth=32, middleWidth=32, textYOffset=4},
}
-- spell-checker: enable

local skillAssetMap
local missingSkillAssets = { }
local function getSkillAssetByName(name)
	if not name or not data.skillAssets then
		return nil
	end
	if not skillAssetMap then
		skillAssetMap = { }
		for file, fileInfo in pairs(data.skillAssets.ddsCoords or { }) do
			local assetData = { }
			assetData.handle = NewImageHandle()
			assetData.handle:Load("Data/Skills/" .. file, "CLAMP")
			assetData.width, assetData.height = assetData.handle:ImageSize()
			for assetName, position in pairs(fileInfo) do
				skillAssetMap[assetName] = {
					found = assetData.width > 0,
					handle = assetData.handle,
					width = assetData.width,
					height = assetData.height,
					[1] = position,
				}
			end
		end
	end
	if not skillAssetMap[name] and not missingSkillAssets[name] then
		missingSkillAssets[name] = true
		ConPrintf("missing skill asset with name " .. name)
	end
	return skillAssetMap[name]
end

local TooltipClass = newClass("Tooltip", function(self)
	self.lines = { }
	self.blocks = { }
	self:Clear()
end)

function TooltipClass:Clear(clearUpdateParams)
	wipeTable(self.lines)
	wipeTable(self.blocks)
	if self.updateParams and clearUpdateParams then
		wipeTable(self.updateParams)
	end
	self.tooltipHeader = false
	self.isUniqueGem = nil
	self.runicItem = nil
	self.titleYOffset = 0
	self.recipe = nil
	self.gemIcon = nil
	self.gemBackground = nil
	self.center = false
	self.maxWidth = nil
	self.minWidth = nil
	self.color = { 0.5, 0.3, 0 }
	t_insert(self.blocks, { height = 0 })
end

function TooltipClass:CheckForUpdate(...)
	local doUpdate = false
	if not self.updateParams then
		self.updateParams = { }
	end

	for i = 1, select('#', ...) do
		local temp = select(i, ...)
		if self.updateParams[i] ~= temp then
			self.updateParams[i] = temp
			doUpdate = true
		end
	end
	if doUpdate or self.updateParams.notSupportedModTooltips ~= main.notSupportedModTooltips then
		self.updateParams.notSupportedModTooltips = main.notSupportedModTooltips
		self:Clear()
		return true
	end
end

function TooltipClass:AddLine(size, text, font, background)
	if text then
		local fontToUse
		if main.showFlavourText then
			fontToUse = font or "VAR"
		else
			fontToUse = "VAR"
		end
		for line in s_gmatch(text .. "\n", "([^\n]*)\n") do
			if line:match("^.*(Equipping)") == "Equipping" or line:match("^.*(Removing)") == "Removing" then
				t_insert(self.blocks, { height = size + 2})
			else
				self.blocks[#self.blocks].height = self.blocks[#self.blocks].height + size + 2
			end
			if self.maxWidth then
				for _, wrappedLine in ipairs(main:WrapString(line, size, self.maxWidth - H_PAD)) do
					t_insert(self.lines, { size = size, text = wrappedLine, block = #self.blocks, font = fontToUse, center = self.center, background = background })
				end
			else
				t_insert(self.lines, { size = size, text = line, block = #self.blocks, font = fontToUse, center = self.center, background = background })
			end
		end
	end
end

function TooltipClass:SetRecipe(recipe)
	self.recipe = recipe
end

function TooltipClass:AddSeparator(size)
	size = size or 10

	local lastLine = self.lines[#self.lines]
	if lastLine and lastLine.separatorImage then
		-- Prevent back-to-back separator lines
		return
	end

	local separatorImage = nil

	if self.tooltipHeader then
		local rarity = tostring(self.tooltipHeader):upper()
		-- spell-checker: disable
		local separatorConfigs = {
			RELIC = "Assets/itemsseparatorfoil.png",
			UNIQUE = "Assets/itemsseparatorunique.png",
			RARE = "Assets/itemsseparatorrare.png",
			MAGIC = "Assets/itemsseparatormagic.png",
			NORMAL = "Assets/itemsseparatorwhite.png",
			GEM = "Assets/itemsseparatorgem.png",
		}
		-- spell-checker: enable
		local separatorPath = separatorConfigs[rarity] or separatorConfigs.NORMAL

		if not self.separatorImage or self.separatorImagePath ~= separatorPath then
			self.separatorImage = NewImageHandle()
			self.separatorImage:Load(separatorPath)
			self.separatorImagePath = separatorPath
		end

		separatorImage = self.separatorImage
	end

	local lastBlock = lastLine and lastLine.block or 1
	t_insert(self.lines, {
		separatorImage = separatorImage,
		size = size,
		block = lastBlock,
	})
end

function TooltipClass:GetSize()
	local ttW, ttH = 0, 0
	for i, data in ipairs(self.lines) do
		if data.text or (self.lines[i - 1] and self.lines[i + 1] and self.lines[i + 1].text) then
			ttH = ttH + data.size + 2
		end
		if data.text then
			ttW = m_max(ttW, DrawStringWidth(data.size, data.font, data.text))
		end
	end

	-- Account for recipe display
	if self.recipe and self.lines[1] then
		local title = self.lines[1]
		local font = main.showFlavourText and "FONTIN" or "VAR"
		local imageX = DrawStringWidth(title.size, font, title.text) + title.size
		local recipeTextSize = (title.size * 3) / 4
		for _, recipeInfo in ipairs(self.recipe) do
			local recipeName = recipeInfo.name
			-- Trim "Oil" from the recipe name, which normally looks like "GoldenOil"
			local recipeNameShort = recipeName
			if #recipeNameShort > 3 and recipeNameShort:sub(-3) == "Oil" then
				recipeNameShort = recipeNameShort:sub(1, #recipeNameShort - 3)
			end
			imageX = imageX + DrawStringWidth(recipeTextSize, font, recipeNameShort) + title.size * 1.25
		end
		ttW = m_max(ttW, imageX)
	end

	if self.minWidth then
		ttW = m_max(ttW, self.minWidth)
	end

	return ttW + H_PAD, ttH + V_PAD
end

function TooltipClass:GetDynamicSize(viewPort)
	local staticttW, staticttH = self:GetSize()
	if self.tooltipHeader and main.showFlavourText and self.lines[1] and self.lines[1].text then
		local rarity = tostring(self.tooltipHeader):upper()
		local config = headerConfigs[rarity] or headerConfigs.NORMAL
		self.titleYOffset = config.textYOffset or 0
		staticttW = m_max(staticttW, DrawStringWidth(self.lines[1].size, self.lines[1].font, self.lines[1].text) + 50)
	end
	local columns, ttH, _, extraColumnWidth = self:CalculateColumns(0, 0, staticttH, staticttW, viewPort)

	-- ensure extra column width has sensible value
	extraColumnWidth = (columns > 1 and extraColumnWidth > 0) and extraColumnWidth or staticttW
	local ttW = staticttW + (m_max(columns - 1, 0) * extraColumnWidth)

	return ttW + H_PAD, ttH + V_PAD
end

--- Calculates the column breaks, layout heights, and individual rendering instructions for tooltip lines.
--- By default, items exceeding window height will wrap to a new column.
---@param ttY number Base y-coordinate for the tooltip content
---@param ttX number Base x-coordinate for the tooltip content
---@param ttH number The total estimated height of the tooltip content, used to determine column breakpoints
---@param ttW number The pixel width of the primary (first) tooltip column
---@param viewPort table A table `{x, y, width, height}` containing active screen boundaries
---@return number columns The total number of layout columns generated
---@return number maxColumnHeight The maximum pixel height reached across all formatted columns
---@return table drawStack An array of sequential rendering instructions (texts, images, separators, and their coordinates)
---@return number extraColumnWidth The required dynamic pixel width calculated for any additional columns beyond the first
function TooltipClass:CalculateColumns(ttY, ttX, ttH, ttW, viewPort)
	local y = ttY + 2 * BORDER_WIDTH
	if self.titleYOffset then
		y = y + self.titleYOffset
	end
	local x = ttX
	local columns = 1 -- reset to count columns by block heights
	local currentBlock = 1
	local extraColumnWidth = 0
	local maxColumnHeight = 0
	local drawStack = {}
	local font

	for i, data in ipairs(self.lines) do
		-- Handle first line with recipe/oils
		if main.showFlavourText then
			font = data.font or "VAR"
		else
			font = "VAR"
		end
		if self.recipe and i == 1 and data.text then
			local title = data
			local titleSize = title.size
			local recipeTextSize = math.floor(titleSize * 3 / 4)
			local padding = 4

			-- Measure total width for centering
			local totalWidth = DrawStringWidth(titleSize, font, title.text)
			local oilWidths = {}
			for _, r in ipairs(self.recipe) do
				local rn = r.name
				if #rn > 3 and rn:sub(-3) == "Oil" then
					rn = rn:sub(1, #rn - 3)
				end
				local textW = DrawStringWidth(recipeTextSize, font, rn)
				local iconW = titleSize
				table.insert(oilWidths, {rn, r.sprite, textW, iconW})
				totalWidth = totalWidth + textW + iconW + padding
			end

			-- Center title + oils
			local curX = ttX + ttW / 2 - totalWidth / 2
			-- Draw title
			t_insert(drawStack, {curX, y + (titleSize - titleSize)/2, "LEFT", titleSize, font, title.text})
			curX = curX + DrawStringWidth(titleSize, font, title.text) + (H_PAD / 2)

			-- Draw oils
			local maxOilHeight = 0
			for _, part in ipairs(oilWidths) do
				local rn, sprite, textW, iconW = part[1], part[2], part[3], part[4]
				if main.showFlavourText then
					rn = "^xF8E6CA" .. rn
				end
				t_insert(drawStack, {curX, y + (titleSize - recipeTextSize)/2, "LEFT", recipeTextSize, font, rn})
				curX = curX + textW
				t_insert(drawStack, {sprite, curX, y, iconW, iconW})
				curX = curX + iconW + padding
				maxOilHeight = m_max(maxOilHeight, recipeTextSize, iconW)
			end

			-- Advance y by max height
			y = y + m_max(titleSize, maxOilHeight) + 2

			-- Mark line handled so it won’t print again
			data._handled = true
		end

		-- Normal text handling (skip if first line handled)
		if data.text and not data._handled then
			-- Column break logic
			if currentBlock ~= data.block and self.blocks[data.block].height + y > ttY + math.min(ttH, viewPort.height) then
				y = ttY + 2 * BORDER_WIDTH
				x = ttX + ttW * columns
				columns = columns + 1
			end
			currentBlock = data.block

			local lineCentered = data.center
			if lineCentered == nil then
				lineCentered = self.center
			end
			local lineX = lineCentered and (x + ttW / 2) or (x + (H_PAD / 2))
			local lineAlign = lineCentered and "CENTER_X" or "LEFT"

			t_insert(drawStack, {lineX, y, lineAlign, data.size, font, data.text, background = data.background})
			y = y + data.size + 2

			-- track max width for extra columns
			if columns > 1 then
				extraColumnWidth = m_max(extraColumnWidth, DrawStringWidth(data.size, font, data.text) + H_PAD)
			end

		elseif data.separatorImage and main.showFlavourText then
			local sepSize = data.size or 10
			if currentBlock ~= data.block and y + sepSize > ttY + math.min(ttH, viewPort.height) then
				y = ttY + 2 * BORDER_WIDTH
				x = ttX + ttW * columns
				columns = columns + 1
			end
			currentBlock = data.block
			t_insert(drawStack, {{ handle = data.separatorImage, isSeparator = true }, x + (H_PAD / 2), y, ttW - H_PAD, sepSize})
			y = y + sepSize

		elseif self.lines[i + 1] and self.lines[i - 1] and self.lines[i + 1].text then
			t_insert(drawStack, {nil, x, y - 1 + data.size / 2, ttW - BORDER_WIDTH, 2})
			y = y + data.size + 2
		end

		maxColumnHeight = m_max(y - ttY + 2 * BORDER_WIDTH, maxColumnHeight)
	end

	-- Resizing/Shrinking drawStack elements in extra columns
	-- NOTE: this logic depends on the current structure of `drawStack` --> needs adjustment if lengths or coordinates logic changes
	if columns > 1 and extraColumnWidth > 0 then
	 	for _, line in ipairs(drawStack) do
			local isText = #line >= 6 -- Text elements have 6 props, images/separators have 5
			local xIdx = isText and 1 or 2 -- `x` value at index 1 for text, 2 otherwise
			local origX = line[xIdx]

			-- calculate column index (origX is at least x * original widths from start)
			local colIndex = m_floor((origX - ttX) / ttW) + 1

			if colIndex > 1 then
				local oldBaseX = ttX + ttW * (colIndex - 1)
				local newBaseX = ttX + ttW + extraColumnWidth * (colIndex - 2) -- `- 2` because first column is unchanged

				-- Update x coordinates
				if isText and line[3] == "CENTER_X" then
					-- centered texts
					line[xIdx] = newBaseX + extraColumnWidth / 2
				else
					-- "LEFT" aligned text and images (NOTE: "RIGHT" aligned does not seem to exist)
					line[xIdx] = origX - oldBaseX + newBaseX
				end

				-- Resize separators/dividers (technically unlikely to appear in extra columns, but just in case)
				if not isText then
					-- separator images have `width` value at index 4
					if line[1] and type(line[1]) == "table" and line[1].isSeparator then
						line[4] = extraColumnWidth - H_PAD -- "fancy" separators get extra padding
					else
						line[4] = extraColumnWidth - BORDER_WIDTH
					end
				end
			end
		end
	end

	return columns, maxColumnHeight, drawStack, extraColumnWidth
end
--- Draws tooltip to screen
---@param x number x-coordinate to draw the tooltip at
---@param y number y-coordinate to draw the tooltip at
---@param w number|nil optional width of the UI element being hovered over. Tooltip will position itself outside this box (if possible)
---@param h number|nil optional height of the UI element being hovered over. Needs to be provided alongside `w`
---@param viewPort table A table `{x, y, width, height}` contains active screen boundaries

function TooltipClass:Draw(x, y, w, h, viewPort)
	if #self.lines == 0 then
		return
	end
	local ttW, ttH = self:GetSize()

	-- ensure ttW is at least title width + 50 pixels, this fixes the header image for Magic items and some Tree passives.
	if self.tooltipHeader and main.showFlavourText and self.lines[1] and self.lines[1].text then
		local titleW = DrawStringWidth(self.lines[1].size, self.lines[1].font, self.lines[1].text)
		if titleW + 50 > ttW then
			ttW = titleW + 50
		end
	end
	-- spell-checker: disable
	local headerInfluence = {
		Fractured = "Assets/fractureditemsymbol.png",
		Desecrated = "Assets/veileditemsymbol.png",
		Mutated = "Assets/vaalitemicon.png",
	}
	-- spell-checker: enable
	local config
	if self.tooltipHeader and main.showFlavourText and self.lines[1] and self.lines[1].text then
		local rarity = tostring(self.tooltipHeader):upper()
		config = headerConfigs[rarity] or headerConfigs.NORMAL
		self.titleYOffset = config.textYOffset or 0
	end
	local ttX = x
	local ttY = y
	local isHoverToolTip = w and h -- `w` and `h` typically only provided for hover tooltips
	if isHoverToolTip then
		ttX = ttX + w + 5
		if ttX + ttW > viewPort.x + viewPort.width then
			ttX = m_max(viewPort.x, x - 5 - ttW)
			if ttX + ttW > x then
				ttY = ttY + h
			end
		end
		if ttY + ttH > viewPort.y + viewPort.height then
			ttY = m_max(viewPort.y, y + h - ttH)
		end
	end

	SetDrawColor(1, 1, 1)

	-- Initial column calculation
	local columns, maxColumnHeight, drawStack, extraColumnWidth = self:CalculateColumns(ttY, ttX, ttH, ttW, viewPort)

	-- ensure extraColumnWidth has sensible value and calculate new total width (original width + extraColumns)
	extraColumnWidth = (columns > 1 and extraColumnWidth > 0) and extraColumnWidth or ttW
	local totalDrawWidth = ttW + (m_max(columns - 1, 0) * extraColumnWidth)

	-- If hover tooltip and extra columns don't fit, shift to left and adjust drawStack (because hover tooltips can't scroll)
	if columns > 1 and isHoverToolTip and totalDrawWidth + ttX >= viewPort.x + viewPort.width then
		local newX = m_max(viewPort.x, viewPort.x + viewPort.width - totalDrawWidth)
		local offsetX = newX - ttX
		ttX = newX

		for _, line in ipairs(drawStack) do
			if #line < 6 then
				-- Text element entries have 6 entries and `x` at `[2]`
				line[2] = line[2] + offsetX
			else
				-- Image, Separators, etc. have 5 entries and `x` at `[1]`
				line[1] = line[1] + offsetX
			end
		end
	end

	-- background shading currently must be drawn before text lines.  API change will allow something like the commented lines below
	SetDrawColor(0, 0, 0, .85)
	--SetDrawLayer(nil, GetDrawLayer() - 5)
	DrawImage(nil, ttX, ttY + BORDER_WIDTH, totalDrawWidth - BORDER_WIDTH, maxColumnHeight - 2 * BORDER_WIDTH)
	--SetDrawLayer(nil, GetDrawLayer())
	SetDrawColor(1, 1, 1)

	-- Item header (drawn within borders)
	if self.tooltipHeader and main.showFlavourText and self.lines[1] and self.lines[1].text then
		local rarity = tostring(self.tooltipHeader):upper()
		local config = headerConfigs[rarity] or headerConfigs.NORMAL
		-- Animate RELIC header color (light green → bright yellow → white)
		if rarity == "RELIC" and main.showAnimations then
			local t = GetTime() * 0.003

			-- Three phase-shifted sine waves
			local s1 = math.sin(t)
			local s2 = math.sin(t + 2.094) -- +120°
			local s3 = math.sin(t + 4.188) -- +240°

			local r = 0.8 + 0.2 * ((s1 + 1) / 2)   -- boosts yellows/whites
			local g = 0.75 + 0.25 * ((s2 + 1) / 2) -- slightly darker green range
			local b = 0.6 + 0.15 * ((s3 + 1) / 2)  -- minimal blue, keeps warmth

			SetDrawColor(r, g, b)
		else
			SetDrawColor(1, 1, 1)
		end

		self.titleYOffset = config.textYOffset or 0

		local runic = self.runicItem and "runic" or ""
		local leftPath = runic .. config.left

		if not self.headerLeft or self.headerLeftPath ~= leftPath then
			self.headerLeft = NewImageHandle()
			self.headerLeft:Load("Assets/" .. leftPath)
			self.headerLeftPath = leftPath
			self.headerMiddle = NewImageHandle()
			self.headerMiddle:Load("Assets/" .. runic .. config.middle)
			self.headerMiddlePath = runic .. config.middle
			self.headerRight = NewImageHandle()
			self.headerRight:Load("Assets/" .. runic .. config.right)
			self.headerRightPath = runic .. config.right
		end

		local headerHeight = config.height
		local headerSideWidth = config.sideWidth
		local headerMiddleWidth = config.middleWidth

		local headerX = ttX + BORDER_WIDTH
		local headerY = ttY + BORDER_WIDTH
		local headerTotalWidth = ttW - 2 * BORDER_WIDTH
		local headerMiddleAreaWidth = m_max(0, headerTotalWidth - 2 * headerSideWidth)
		if self.influenceHeader1 then
			self.influenceIcon1 = NewImageHandle()
			self.influenceIcon1:Load(headerInfluence[self.influenceHeader1])
			self.influenceIcon2 = NewImageHandle()
			self.influenceIcon2:Load(headerInfluence[self.influenceHeader2])
		end

		if self.tooltipHeader ~= "GEM" then
			-- Draw left cap first, then influence icon on top
			DrawImage(self.headerLeft, headerX, headerY, headerSideWidth, headerHeight)
			if self.influenceHeader1 and config.allowInfluenceIcon then
				DrawImage(self.influenceIcon1, headerX + 2, headerY + (headerHeight - (headerHeight/2))/2, headerHeight/2, headerHeight/2)
			end

			-- Draw middle fill
			if headerMiddleAreaWidth > 0 then
				local drawX = headerX + headerSideWidth
				local endX = headerX + headerTotalWidth - headerSideWidth
				while drawX + headerMiddleWidth <= endX do
					DrawImage(self.headerMiddle, drawX, headerY, headerMiddleWidth, headerHeight)
					drawX = drawX + headerMiddleWidth
				end
				local remainingWidth = endX - drawX
				if remainingWidth > 0 then
					DrawImage(self.headerMiddle, drawX, headerY, remainingWidth, headerHeight)
				end
			end

			-- Draw right cap
			DrawImage(self.headerRight, headerX + headerTotalWidth - headerSideWidth, headerY, headerSideWidth, headerHeight)
			if self.influenceHeader2 and config.allowInfluenceIcon then
				DrawImage(self.influenceIcon2, headerX + headerTotalWidth - (headerHeight/2) - 2, headerY + (headerHeight - (headerHeight/2))/2, headerHeight/2, headerHeight/2)
			end
		elseif self.tooltipHeader == "GEM" then
			local gemIconImage = getSkillAssetByName(self.gemIcon)
			local gemBGImage = getSkillAssetByName(self.gemBackground)
			local headerPath = self.isUniqueGem and "Assets/gemhovertitleunique.png" or "Assets/gemhovertitle.png"
			if not self.gemHeaderImage or self.gemHeaderImagePath ~= headerPath then
				self.gemHeaderImage = NewImageHandle()
				self.gemHeaderImage:Load(headerPath)
				self.gemHeaderImagePath = headerPath
			end
			if not self.gemIconBorder then
				self.gemIconBorder = NewImageHandle()
				self.gemIconBorder:Load("Assets/skillpanelskilliconframe.png")
			end
			DrawImage(self.gemHeaderImage, headerX, headerY, 375, 59)
			if gemIconImage then
				DrawImage(gemIconImage.handle, headerX + 21, headerY + 6, 46, 46, unpack(gemIconImage))
				DrawImage(self.gemIconBorder, headerX + 21, headerY + 6, 48, 48)
			end
			if gemBGImage then
				DrawImage(gemBGImage.handle, headerX + headerTotalWidth -500, headerY, 500, 266, unpack(gemBGImage))
			else
				if not self.gemEmptyImage then
					self.gemEmptyImage = NewImageHandle()
					self.gemEmptyImage:Load("Assets/gemhoverimageempty.png")
				end
				DrawImage(self.gemEmptyImage, headerX + headerTotalWidth -500, headerY, 500, 266)
			end
		end
	end

	-- Draw lines and images
	local firstSeparatorSkipped = false
	for _, line in ipairs(drawStack) do
		if #line < 6 then
			local skip = false
			if line[1] and type(line[1]) == "table" and line[1].isSeparator then
				-- Only skip first separator for items and skill gems
				local tooltipType = self.tooltipHeader and tostring(self.tooltipHeader):upper() or ""
				if main.showFlavourText and not firstSeparatorSkipped and
				(tooltipType == "RELIC" or tooltipType == "UNIQUE" or tooltipType == "RARE" or tooltipType == "MAGIC" or tooltipType == "GEM" or tooltipType == "JEWEL") then
					firstSeparatorSkipped = true
					skip = true
				else
					SetDrawColor(1, 1, 1)
				end
			elseif type(self.color) == "string" then
				SetDrawColor(self.color)
			else
				SetDrawColor(unpack(self.color))
			end
			if not skip then
				if line[1] and line[1].handle then
					local args = { line[1].handle, line[2], line[3], line[4], line[5] }
					for _, v in ipairs(line[1]) do
						t_insert(args, v)
					end
					SetDrawColor(1,1,1)
					DrawImage(unpack(args))
				else
					DrawImage(unpack(line))
				end
			end
		else
			-- Draw background if specified, used for gem mod lines and desecrated mods on items.
			local bg = line.background
			if bg then
				-- Save current draw color BEFORE drawing background image, otherwise wrapped strings print white text for later lines.
				local prevR, prevG, prevB, prevA = GetDrawColor()

				if type(bg) == "string" then
					if not self._bgHandles then
						self._bgHandles = {}
					end
					if not self._bgHandles[bg] then
						local h = NewImageHandle()
						h:Load("Assets/" .. bg .. ".png")
						self._bgHandles[bg] = h
					end
					bg = self._bgHandles[bg]
				end

				local x = ttX
				local y = line[2] - 1
				local width = ttW - 8
				local height = line[4] + 3
				SetDrawColor(1,1,1,1)
				DrawImage(bg, x + 4, y, width, height)

				-- Restore color BEFORE DrawString
				SetDrawColor(prevR, prevG, prevB, prevA)
			end

			-- Draw text line
			DrawString(unpack(line))
		end
	end

	-- Draw borders
	if type(self.color) == "string" then
		SetDrawColor(self.color)
	else
		SetDrawColor(unpack(self.color))
	end

	-- draw vertical borders, accounting for separate extra column width
	for i = 0, columns do
		local extraColXOffset = i > 0 and ttW + ((i - 1) * extraColumnWidth) or 0
		local currentX = ttX + extraColXOffset
		DrawImage(nil, currentX - BORDER_WIDTH * math.ceil(i^2 / (i^2 + 1)), ttY, BORDER_WIDTH, maxColumnHeight)
	end
	-- draw horizontal borders
	DrawImage(nil, ttX, ttY, totalDrawWidth, BORDER_WIDTH) -- top
	DrawImage(nil, ttX, ttY + maxColumnHeight - BORDER_WIDTH, totalDrawWidth, BORDER_WIDTH) -- bottom

	-- draw child tooltips for item skills. these are placed directly to the right of the main
	-- tooltip, growing downwards, unless they would go outside the viewport, in which case they
	-- will draw over the main tooltip
	if self.childTooltips then
		local totalH = 0
		-- we will move the tooltips up as a group, so get the total height
		for _, tt in ipairs(self.childTooltips) do
			local _, childH = tt:GetSize(viewPort)
			totalH = totalH + childH
		end
		-- if the whole group would go over the bottom edge, we apply a negative offset to keep them
		-- in
		local yOffset = math.min(0, viewPort.height - totalH - ttY / 2)
		-- movement to the left happens individually. i.e. the right edges are aligned
		local yPos = ttY
		for _, tt in ipairs(self.childTooltips) do
			local childW, childH = tt:GetSize(viewPort)
			local furthestAllowedX = viewPort.width - childW / 2
			local furthestAllowedY = -totalH / 2
			tt:Draw(math.min(ttX + 4 + ttW, furthestAllowedX), math.max(yPos + yOffset, 0), nil, nil,
				viewPort)
			-- next tooltip goes below this one
			yPos = yPos + childH + 2
		end
	end
	return ttW, ttH
end
