-- Path of Building
--
-- Module: Compare Trade Helpers
-- Stateless trade mod lookup/matching and item display helper functions
--
local m_floor = math.floor
local dkjson = require "dkjson"

local M = {}

-- Helper: get rarity color code for an item
function M.getRarityColor(item)
	if not item then return "^7" end
	if item.rarity == "UNIQUE" then return colorCodes.UNIQUE
	elseif item.rarity == "RARE" then return colorCodes.RARE
	elseif item.rarity == "MAGIC" then return colorCodes.MAGIC
	else return colorCodes.NORMAL end
end

-- Helper: normalize a mod line by replacing numbers with "#" for template matching
function M.modLineTemplate(line)
	-- Replace decimal numbers first (e.g. "1.5"), then integers
	return line:gsub("[%d]+%.?[%d]*", "#")
end

-- Helper: extract the first number from a mod line for value comparison
function M.modLineValue(line)
	return tonumber(line:match("[%d]+%.?[%d]*")) or 0
end

-- Helper: fetch and cache the trade API stats
local _tradeStats = nil
local _tradeStatsFetched = false
local function getTradeStatsLookup()
	if _tradeStats then return _tradeStats end
	local tradeStats = ""
	local easy = common.curl.easy()
	if not easy then return nil end
	easy:setopt_url("https://www.pathofexile.com/api/trade2/data/stats")
	easy:setopt_useragent("Path of Building/" .. (launch.versionNumber or ""))
	easy:setopt_writefunction(function(d)
		tradeStats = tradeStats .. d
		return true
	end)
	local ok = easy:perform()
	easy:close()
	if not ok or tradeStats == "" then return {} end
	local parsed = dkjson.decode(tradeStats)
	_tradeStats = parsed.result
	return _tradeStats
end

-- Map source types used in OpenBuySimilarPopup to trade API category labels
M.sourceTypeToCategory = {
	["implicit"] = "Implicit",
	["explicit"] = "Explicit",
	["enchant"] = "Enchant",
}

function M.shouldBeInverted(tradeId, modLine, modType)
	local formattedLine = M.formatDatabaseText(M.formatDatabaseText(modLine))
	for _, category in ipairs(getTradeStatsLookup()) do
		if category.id == modType then
			for _, stat in ipairs(category.entries) do
				if tradeId == stat.id then
					-- remove radius jewel extra text
					local formattedTradeSiteText = M.formatDatabaseText(stat.text)
					-- local modifiers don't seem to be inverted. same goes for
					-- the single stat that has (charm) in it
					if formattedTradeSiteText:match("(Local)") or formattedTradeSiteText:match(" %(Charm%)$") then
						return false
					end
					-- trade site sometimes has a + sign, sometimes not
					return not (formattedLine == formattedTradeSiteText or formattedLine:gsub("^%+", "") == formattedTradeSiteText)
				end
			end
		end
	end
end

-- Helper: normalise data texts to # format
function M.formatDatabaseText(text)
	-- decimal -> integer
	text = text:gsub("%d+%.%d+", "1")
	-- (123-124) -> #
	text = text:gsub("%(%d+%-%d+%)", "#")
	text = text:gsub("%d+", "#")
	-- remove radius jewel text. the same description is used for regular and
	-- radius jewels in the exports
	text = text:gsub("^Notable Passive Skills in Radius also grant ", "")
	text = text:gsub("^Small Passive Skills in Radius also grant ", "")
	return text
end

-- Helper: find the trade stat ID for a mod line
function M.findTradeHash(item, modLine, modType, isDesecrated)
	local formattedLine = M.formatDatabaseText(modLine)
	-- the data export splits some mods into different parts, even though they
	-- are technically just one stat. we handle that here
	function findStat(dbMod, allowDefault)
		local excludeTags = (not allowDefault) and { default = true } or nil
		if #dbMod.weightKey > 0 and not (item:GetModSpawnWeight(dbMod, nil, excludeTags) > 0) then
			return nil
		end
		for tradeHash, description in pairs(dbMod.tradeHashes) do
			for _, line in ipairs(description) do
				local dbFormatted = M.formatDatabaseText(line)
				if formattedLine == dbFormatted then
					return tradeHash
				end
			end
		end
	end

	-- corruptions
	if modType == "enchant" then
		for _, dbMod in pairs(data.itemMods.Corruption) do
			local tradeHashMaybe = findStat(dbMod)
			if tradeHashMaybe then
				return tradeHashMaybe
			end
		end
		-- explicit
	elseif modType ~= "implicit" then
		local modList = (item.base and item.base.type == "Jewel" and data.itemMods.Jewel)
			or data.itemMods.Item
		for _, dbMod in pairs(modList) do
			local tradeHashMaybe = findStat(dbMod)
			if tradeHashMaybe then
				return tradeHashMaybe
			end
		end
	end
	-- implicit, and special explicit (e.g. unique and essence)
	for _, dbMod in pairs(data.itemMods.Exclusive) do
		local tradeHashMaybe = findStat(dbMod, true)
		if tradeHashMaybe then
			return tradeHashMaybe
		end
	end
	-- desecrated mods (some of these are unique)
	if isDesecrated then
		for _, dbMod in pairs(data.itemMods.Desecrated) do
			local tradeHashMaybe = findStat(dbMod)
			if tradeHashMaybe then
				return tradeHashMaybe
			end
		end
	end
	-- charm mods
	if item.base and item.base.type == "Charm" then
		for _, dbMod in pairs(data.itemMods.Charm) do
			-- charms don't seem to have any spawn weights, so allow the default tag here
			local tradeHashMaybe = findStat(dbMod, true)
			if tradeHashMaybe then
				return tradeHashMaybe
			end
		end
	end
end

-- Helper: get a display-friendly category name from slot name
function M.getTradeCategoryLabel(slotName, item)
	if not item or not item.base then return "Item" end
	local baseType = item.base.type or item.type
	return baseType or "Item"
end

-- Helper: build a mod comparison map from an item.
-- Returns a table keyed by template string → { line = original text, value = first number }
function M.buildModMap(item)
	local modMap = {}
	if not item then return modMap end
	for _, modList in ipairs{item.enchantModLines or {}, item.scourgeModLines or {}, item.implicitModLines or {}, item.explicitModLines or {}, item.crucibleModLines or {}} do
		for _, modLine in ipairs(modList) do
			if item:CheckModLineVariant(modLine) then
				local formatted = itemLib.formatModLine(modLine)
				if formatted then
					local template = M.modLineTemplate(modLine.line)
					modMap[template] = { line = modLine.line, value = M.modLineValue(modLine.line) }
				end
			end
		end
	end
	return modMap
end

-- Helper: get diff label string for an item slot comparison
function M.getSlotDiffLabel(pItem, cItem)
	if not pItem and not cItem then
		return "^8(both empty)"
	end
	if pItem and cItem and pItem.name == cItem.name then
		return colorCodes.POSITIVE .. "(match)"
	elseif not pItem then
		return colorCodes.NEGATIVE .. "(missing)"
	elseif not cItem then
		return colorCodes.TIP .. "(extra)"
	else
		return colorCodes.WARNING .. "(different)"
	end
end

-- Helper: draw Copy, Equip, and Buy buttons at the given position.
-- btnStartX is the left edge where the first button (Buy) should appear.
-- copyBtnW, copyBtnH, buyBtnW are button dimensions (passed from LAYOUT by caller).
-- Returns copyHovered, equipHovered, buyHovered booleans.
function M.drawCopyButtons(cursorX, cursorY, btnStartX, btnY, slotMissing, copyBtnW, copyBtnH, buyBtnW, equipBtnW)
	local btnW     = copyBtnW
	local btnH     = copyBtnH
	local buyW     = buyBtnW
	local equipW = equipBtnW
	local btn3X = btnStartX
	local btn1X = btn3X + buyW + 4
	local btn2X = btn1X + btnW + 4

	local function drawBtn(x, w, hover, label)
		local pressed = hover and IsKeyDown("LEFTBUTTON")
		-- Outer border
		if hover then
			SetDrawColor(1, 1, 1)
		else
			SetDrawColor(0.5, 0.5, 0.5)
		end
		DrawImage(nil, x, btnY, w, btnH)
		-- Inner fill
		if pressed then
			SetDrawColor(0.5, 0.5, 0.5)
		elseif hover then
			SetDrawColor(0.33, 0.33, 0.33)
		else
			SetDrawColor(0, 0, 0)
		end
		DrawImage(nil, x + 1, btnY + 1, w - 2, btnH - 2)
		-- Label
		SetDrawColor(1, 1, 1)
		DrawString(x + w / 2, btnY + 1, "CENTER_X", 14, "VAR", label)
	end

	-- "Buy" button
	local b3Hover = cursorX >= btn3X and cursorX < btn3X + buyW
		and cursorY >= btnY and cursorY < btnY + btnH
	drawBtn(btn3X, buyW, b3Hover, "^7Buy")

	-- "Copy" button
	local b1Hover = cursorX >= btn1X and cursorX < btn1X + btnW
		and cursorY >= btnY and cursorY < btnY + btnH
	drawBtn(btn1X, btnW, b1Hover, "^7Copy")

	local b2Hover
	if slotMissing then
		-- Show "Missing slot" label instead of Equip button
		SetDrawColor(1, 1, 1)
		DrawString(btn2X + equipW / 2, btnY + 1, "CENTER_X", 14, "VAR", "^xBBBBBBMissing slot")
		b2Hover = false
	else
		-- "Equip" button
		b2Hover = cursorX >= btn2X and cursorX < btn2X + equipW
			and cursorY >= btnY and cursorY < btnY + btnH
		drawBtn(btn2X, equipW, b2Hover, "^7Equip")
	end

	return b1Hover, b2Hover, b3Hover, btn2X, btnY, equipW, btnH
end

-- Helper: fit a colored item name within maxW pixels, truncating with "..." if needed.
local function fitItemName(colorCode, name, maxW)
	local display = colorCode .. name
	if DrawStringWidth(16, "VAR", display) <= maxW then
		return display
	end
	local lo, hi = 0, #name
	while lo < hi do
		local mid = m_floor((lo + hi + 1) / 2)
		if DrawStringWidth(16, "VAR", colorCode .. name:sub(1, mid) .. "...") <= maxW then
			lo = mid
		else
			hi = mid - 1
		end
	end
	return colorCode .. name:sub(1, lo) .. "..."
end

local function fitSlotLabel(label, maxW)
	local display = "^7" .. label .. ":"
	if DrawStringWidth(16, "VAR", display) <= maxW then
		return display
	end
	local lo, hi = 0, #label
	while lo < hi do
		local mid = m_floor((lo + hi + 1) / 2)
		if DrawStringWidth(16, "VAR", "^7" .. label:sub(1, mid) .. "...:") <= maxW then
			lo = mid
		else
			hi = mid - 1
		end
	end
	return "^7" .. label:sub(1, lo) .. "...:"
end

-- Helper: draw a single compact-mode item row.
-- Returns: pHover, cHover, b1Hover, b2Hover, b3Hover, b2X, b2Y, b2W, b2H, hoverItem, hoverItemsTab
-- copyBtnW, copyBtnH, buyBtnW are button dimensions (passed from LAYOUT by caller).
local ITEM_BOX_W = 310
M.ITEM_BOX_W = ITEM_BOX_W
local ITEM_BOX_H = 20

function M.drawCompactSlotRow(drawY, slotLabel, pItem, cItem,
	colWidth, cursorX, cursorY, maxLabelW, primaryItemsTab, compareItemsTab, pWarn, cWarn, slotMissing,
	copyBtnW, copyBtnH, buyBtnW, equipBtnW, xOffset)

	xOffset = xOffset or 0
	local pName = pItem and pItem.name or "(empty)"
	local cName = cItem and cItem.name or "(empty)"
	if pWarn and pWarn ~= "" then pName = pName .. pWarn end
	if cWarn and cWarn ~= "" then cName = cName .. cWarn end
	local pColor = M.getRarityColor(pItem)
	local cColor = M.getRarityColor(cItem)
	local diffLabel = M.getSlotDiffLabel(pItem, cItem)

	-- Layout positions (fixed 310px box width matching regular Items tab)
	local labelX = xOffset + 10
	local pBoxX = labelX + maxLabelW + 4
	local pBoxW = ITEM_BOX_W

	local cBoxX = xOffset + colWidth + 10
	local cBoxW = ITEM_BOX_W

	-- Diff indicator position
	local diffX = pBoxX + pBoxW + 6

	-- Hover detection
	local pHover = pItem and cursorX >= pBoxX and cursorX < pBoxX + pBoxW
		and cursorY >= drawY and cursorY < drawY + ITEM_BOX_H
	local cHover = cItem and cursorX >= cBoxX and cursorX < cBoxX + cBoxW
		and cursorY >= drawY and cursorY < drawY + ITEM_BOX_H

	-- Draw slot label
	SetDrawColor(1, 1, 1)
	DrawString(labelX, drawY + 2, "LEFT", 16, "VAR", fitSlotLabel(slotLabel, maxLabelW))

	-- Draw primary item box
	local pBorderGray = pHover and 0.5 or 0.33
	SetDrawColor(pBorderGray, pBorderGray, pBorderGray)
	DrawImage(nil, pBoxX, drawY, pBoxW, ITEM_BOX_H)
	SetDrawColor(0.05, 0.05, 0.05)
	DrawImage(nil, pBoxX + 1, drawY + 1, pBoxW - 2, ITEM_BOX_H - 2)
	SetDrawColor(1, 1, 1)
	DrawString(pBoxX + 4, drawY + 2, "LEFT", 16, "VAR", fitItemName(pColor, pName, pBoxW - 8))

	-- Draw diff indicator (between the two item boxes)
	DrawString(diffX, drawY + 3, "LEFT", 14, "VAR", diffLabel)

	-- Draw compare item box
	local cBorderGray = cHover and 0.5 or 0.33
	SetDrawColor(cBorderGray, cBorderGray, cBorderGray)
	DrawImage(nil, cBoxX, drawY, cBoxW, ITEM_BOX_H)
	SetDrawColor(0.05, 0.05, 0.05)
	DrawImage(nil, cBoxX + 1, drawY + 1, cBoxW - 2, ITEM_BOX_H - 2)
	SetDrawColor(1, 1, 1)
	DrawString(cBoxX + 4, drawY + 2, "LEFT", 16, "VAR", fitItemName(cColor, cName, cBoxW - 8))

	-- Draw buttons
	local b1Hover, b2Hover, b3Hover, b2X, b2Y, b2W, b2H
	if cItem then
		local btnStartX = cBoxX + cBoxW + 6
		b1Hover, b2Hover, b3Hover, b2X, b2Y, b2W, b2H =
			M.drawCopyButtons(cursorX, cursorY, btnStartX, drawY + 1, slotMissing, copyBtnW, copyBtnH, buyBtnW, equipBtnW)
	end

	-- Determine hovered item and tooltip anchor position
	local hoverItem = nil
	local hoverItemsTab = nil
	local hoverBoxX, hoverBoxY, hoverBoxW, hoverBoxH = 0, 0, 0, 0
	if pHover then
		hoverItem = pItem
		hoverItemsTab = primaryItemsTab
		hoverBoxX, hoverBoxY, hoverBoxW, hoverBoxH = pBoxX, drawY, pBoxW, ITEM_BOX_H
	elseif cHover then
		hoverItem = cItem
		hoverItemsTab = compareItemsTab
		hoverBoxX, hoverBoxY, hoverBoxW, hoverBoxH = cBoxX, drawY, cBoxW, ITEM_BOX_H
	end

	return pHover, cHover, b1Hover, b2Hover, b3Hover, b2X, b2Y, b2W, b2H,
		hoverItem, hoverItemsTab, hoverBoxX, hoverBoxY, hoverBoxW, hoverBoxH
end

return M
