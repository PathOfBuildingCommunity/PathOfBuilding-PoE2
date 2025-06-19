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

local TooltipClass = newClass("Tooltip", function(self)
	self.lines = { }
	self.blocks = { }
	self:Clear()
end)

function TooltipClass:Clear()
	wipeTable(self.lines)
	wipeTable(self.blocks)
	if self.updateParams then
		wipeTable(self.updateParams)
	end
	self.recipe = nil
	self.center = false
	self.color = { 0.5, 0.3, 0 }
	t_insert(self.blocks, { height = 0 })
end

function TooltipClass:CheckForUpdate(...)
	local doUpdate = false
	if not self.updateParams then
		self.updateParams = { }
	end
	for i = 1, select('#', ...) do
		if self.updateParams[i] ~= select(i, ...) then
			doUpdate = true
			break
		end
	end
	if doUpdate then
		self:Clear()
		for i = 1, select('#', ...) do
			self.updateParams[i] = select(i, ...)
		end
		return true
	end
end

function TooltipClass:AddLine(size, text)
	if text then
		for line in s_gmatch(text .. "\n", "([^\n]*)\n") do	
			if line:match("^.*(Equipping)") == "Equipping" or line:match("^.*(Removing)") == "Removing" then
				t_insert(self.blocks, { height = size + 2})
			else
				self.blocks[#self.blocks].height = self.blocks[#self.blocks].height + size + 2
			end
			if self.maxWidth then
				for _, line in ipairs(main:WrapString(line, size, self.maxWidth - H_PAD)) do
					t_insert(self.lines, { size = size, text = line, block = #self.blocks })
				end
			else
				t_insert(self.lines, { size = size, text = line, block = #self.blocks })
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

	if self.itemTooltip then
		local rarity = tostring(self.itemTooltip):upper()
		local separatorConfigs = {
			RELIC = "Assets/itemsseparatorfoil.png",
			UNIQUE = "Assets/itemsseparatorunique.png",
			RARE = "Assets/itemsseparatorrare.png",
			MAGIC = "Assets/itemsseparatormagic.png",
			NORMAL = "Assets/itemsseparatorwhite.png",
			GEM = "Assets/itemsseparatorgem.png",
		}
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
			ttW = m_max(ttW, DrawStringWidth(data.size, "VAR", data.text))
		end
	end

	-- Account for recipe display
	if self.recipe and self.lines[1] then
		local title = self.lines[1]
		local imageX = DrawStringWidth(title.size, "VAR", title.text) + title.size
		local recipeTextSize = (title.size * 3) / 4
		for _, recipeInfo in ipairs(self.recipe) do
			local recipeName = recipeInfo.name
			-- Trim "Oil" from the recipe name, which normally looks like "GoldenOil"
			local recipeNameShort = recipeName
			if #recipeNameShort > 3 and recipeNameShort:sub(-3) == "Oil" then
				recipeNameShort = recipeNameShort:sub(1, #recipeNameShort - 3)
			end
			imageX = imageX + DrawStringWidth(recipeTextSize, "VAR", recipeNameShort) + title.size * 1.25
		end
		ttW = m_max(ttW, imageX)
	end

	return ttW + H_PAD, ttH + V_PAD
end

function TooltipClass:GetDynamicSize(viewPort)
	local staticttW, staticttH = self:GetSize()
	local columns, ttH = self:CalculateColumns(0, 0, staticttH, staticttW, viewPort)
	local ttW = columns * staticttW

	return ttW + H_PAD, ttH + V_PAD
end

function TooltipClass:CalculateColumns(ttY, ttX, ttH, ttW, viewPort)
	local y = ttY + 2 * BORDER_WIDTH
	local x = ttX
	local columns = 1 -- reset to count columns by block heights
	local currentBlock = 1
	local maxColumnHeight = 0
	local drawStack = {}

	for i, data in ipairs(self.lines) do
		-- Draw recipe oils on first line
		if self.recipe and i == 1 then
			local title = self.lines[1]
			local imageX = DrawStringWidth(title.size, "VAR", title.text) + title.size
			local recipeTextSize = (title.size * 3) / 4
			for _, recipeInfo in ipairs(self.recipe) do
				local recipeName = recipeInfo.name
				-- Trim "Oil" from the recipe name, which normally looks like "GoldenOil"
				local recipeNameShort = recipeName
				if #recipeNameShort > 3 and recipeNameShort:sub(-3) == "Oil" then
					recipeNameShort = recipeNameShort:sub(1, #recipeNameShort - 3)
				end
				-- Draw the name of the recipe component (oil)
				t_insert(drawStack, {ttX + imageX, y + (title.size - recipeTextSize) / 2, "LEFT", recipeTextSize, "VAR", recipeNameShort})
				imageX = imageX + DrawStringWidth(recipeTextSize, "VAR", recipeNameShort)
				-- Draw the image of the recipe component (oil)
				t_insert(drawStack, {recipeInfo.sprite, ttX + imageX, y, title.size, title.size})
				imageX = imageX + title.size * 1.25
			end
		end

		local margin = 80
		local maxHeight = math.min(ttH, viewPort.height - margin)

		-- Wrapping logic for text lines
		if data.text then
			if currentBlock ~= data.block and (y + data.size > ttY + maxHeight) then
				y = ttY + 2 * BORDER_WIDTH
				x = ttX + ttW * columns
				columns = columns + 1
			end
			currentBlock = data.block

			local yOffset = (i == 1 and self.titleYOffset) or 0
			local drawY = y + yOffset

			if self.center then
				t_insert(drawStack, {x + ttW / 2, drawY, "CENTER_X", data.size, "VAR", data.text})
			else
				t_insert(drawStack, {x + 6, drawY, "LEFT", data.size, "VAR", data.text})
			end
			y = y + data.size + 2

		-- Wrapping logic for separator images (counts as a "text" line for wrap height)
		elseif data.separatorImage and main.showFlavourText then
			local sepSize = data.size or 10
			if currentBlock ~= data.block and (y + sepSize > ttY + maxHeight) then
				y = ttY + 2 * BORDER_WIDTH
				x = ttX + ttW * columns
				columns = columns + 1
			end
			currentBlock = data.block

			t_insert(drawStack, {{ handle = data.separatorImage, isSeparator = true },x + 6, y, ttW - 12, sepSize})
			y = y + sepSize + 2

		-- Horizontal line, if surrounded by text lines
		elseif self.lines[i + 1] and self.lines[i - 1] and self.lines[i + 1].text then
			t_insert(drawStack, {nil, x, y - 1 + data.size / 2, ttW - BORDER_WIDTH, 2})
			y = y + data.size + 2
		end

		maxColumnHeight = m_max(y - ttY + 2 * BORDER_WIDTH, maxColumnHeight)
	end

	return columns, maxColumnHeight, drawStack
end

function TooltipClass:Draw(x, y, w, h, viewPort)
	if #self.lines == 0 then
		return
	end
	local ttW, ttH = self:GetSize()
	local ttX = x
	local ttY = y
	if w and h then
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
	elseif self.center then
		ttX = m_floor(x - ttW / 2)
	end

	SetDrawColor(1, 1, 1)

	local columns, maxColumnHeight, drawStack = self:CalculateColumns(ttY, ttX, ttH, ttW, viewPort)

	-- background shading currently must be drawn before text lines.  API change will allow something like the commented lines below
	SetDrawColor(0, 0, 0, .85)
	--SetDrawLayer(nil, GetDrawLayer() - 5)
	DrawImage(nil, ttX, ttY + BORDER_WIDTH, ttW * columns - BORDER_WIDTH, maxColumnHeight - 2 * BORDER_WIDTH)
	--SetDrawLayer(nil, GetDrawLayer())
	SetDrawColor(1, 1, 1)

	-- Item header (drawn within borders)
	if self.itemTooltip and main.showFlavourText and self.lines[1] and self.lines[1].text then
		local rarity = tostring(self.itemTooltip):upper()
		local headerConfigs = {
			RELIC = {left="Assets/itemsheaderfoilleft.png",middle="Assets/itemsheaderfoilmiddle.png",right="Assets/itemsheaderfoilright.png",height=53,sideWidth=43,middleWidth=43,textYOffset=2},
			UNIQUE = {left="Assets/itemsheaderuniqueleft.png",middle="Assets/itemsheaderuniquemiddle.png",right="Assets/itemsheaderuniqueright.png",height=53,sideWidth=43,middleWidth=43,textYOffset=2},
			RARE = {left="Assets/itemsheaderrareleft.png",middle="Assets/itemsheaderraremiddle.png",right="Assets/itemsheaderrareright.png",height=53,sideWidth=43,middleWidth=43,textYOffset=2},
			MAGIC = {left="Assets/itemsheadermagicleft.png",middle="Assets/itemsheadermagicmiddle.png",right="Assets/itemsheadermagicright.png",height=38,sideWidth=32,middleWidth=32,textYOffset=4},
			NORMAL = {left="Assets/itemsheaderwhiteleft.png",middle="Assets/itemsheaderwhitemiddle.png",right="Assets/itemsheaderwhiteright.png",height=38,sideWidth=32,middleWidth=32,textYOffset=4},
			GEM = {left="Assets/itemsheadergemleft.png",middle="Assets/itemsheadergemmiddle.png",right="Assets/itemsheadergemright.png",height=38,sideWidth=32,middleWidth=32,textYOffset=4},
			JEWELSOCKET = {left="Assets/jewelpassiveheaderleft.png",middle="Assets/jewelpassiveheadermiddle.png",right="Assets/jewelpassiveheaderright.png",height=38,sideWidth=32,middleWidth=32,textYOffset=2},
			NOTABLENODE = {left="Assets/notablepassiveheaderleft.png",middle="Assets/notablepassiveheadermiddle.png",right="Assets/notablepassiveheaderright.png",height=38,sideWidth=38,middleWidth=32,textYOffset=2},
			PASSIVENODE = {left="Assets/normalpassiveheaderleft.png",middle="Assets/normalpassiveheadermiddle.png",right="Assets/normalpassiveheaderright.png",height=38,sideWidth=32,middleWidth=32,textYOffset=2},
			KEYSTONENODE = {left="Assets/keystonepassiveheaderleft.png",middle="Assets/keystonepassiveheadermiddle.png",right="Assets/keystonepassiveheaderright.png",height=38,sideWidth=32,middleWidth=32,textYOffset=2},
		}
		local config = headerConfigs[rarity] or headerConfigs.NORMAL

		self.titleYOffset = config.textYOffset or 0

		if not self.headerLeft or self.headerLeftPath ~= config.left then
			self.headerLeft = NewImageHandle()
			self.headerLeft:Load(config.left)
			self.headerLeftPath = config.left
		end
		if not self.headerMiddle or self.headerMiddlePath ~= config.middle then
			self.headerMiddle = NewImageHandle()
			self.headerMiddle:Load(config.middle)
			self.headerMiddlePath = config.middle
		end
		if not self.headerRight or self.headerRightPath ~= config.right then
			self.headerRight = NewImageHandle()
			self.headerRight:Load(config.right)
			self.headerRightPath = config.right
		end

		local headerHeight = config.height
		local headerSideWidth = config.sideWidth
		local headerMiddleWidth = config.middleWidth

		local headerX = ttX + BORDER_WIDTH
		local headerY = ttY + BORDER_WIDTH
		local headerTotalWidth = ttW - 2 * BORDER_WIDTH
		local headerMiddleAreaWidth = m_max(0, headerTotalWidth - 2 * headerSideWidth)

		-- Draw left cap
		DrawImage(self.headerLeft, headerX, headerY, headerSideWidth, headerHeight)

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
	end

	-- Draw lines and images
	for _, line in ipairs(drawStack) do 
		if #line < 6 then
			if line[1] and type(line[1]) == "table" and line[1].isSeparator then
				SetDrawColor(1, 1, 1)
			elseif type(self.color) == "string" then
				SetDrawColor(self.color)
			else
				SetDrawColor(unpack(self.color))
			end
			if line[1] and line[1].handle then
				local args = {
					line[1].handle, line[2], line[3], line[4], line[5]
				}
				for _, v in ipairs(line[1]) do
					t_insert(args, v)
				end
				SetDrawColor(1,1,1)
				DrawImage(unpack(args))
			else
				DrawImage(unpack(line))
			end
		else
			DrawString(unpack(line))
		end
	end

	-- Draw borders
	if type(self.color) == "string" then
		SetDrawColor(self.color) 
	else
		SetDrawColor(unpack(self.color))
	end
	for i = 0, columns do
		DrawImage(nil, ttX + ttW * i - BORDER_WIDTH * math.ceil(i^2 / (i^2 + 1)), ttY, BORDER_WIDTH, maxColumnHeight)
	end
	DrawImage(nil, ttX, ttY, ttW * columns, BORDER_WIDTH) -- top
	DrawImage(nil, ttX, ttY + maxColumnHeight - BORDER_WIDTH, ttW * columns, BORDER_WIDTH) -- bottom

	return ttW, ttH
end
