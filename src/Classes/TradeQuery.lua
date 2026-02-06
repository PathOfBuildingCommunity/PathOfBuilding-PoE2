-- Path of Building
--
-- Module: Trade Query
-- Provides PoB Trader pane for interacting with PoE Trade
--


local dkjson = require "dkjson"

local get_time = os.time
local t_insert = table.insert
local t_remove = table.remove
local t_sort = table.sort
local m_max = math.max
local m_min = math.min
local m_ceil = math.ceil
local s_format = string.format
local DrawStringWidth = DrawStringWidth

local baseSlots = { "Weapon 1", "Weapon 2", "Weapon 1 Swap", "Weapon 2 Swap", "Helmet", "Body Armour", "Gloves", "Boots", "Amulet", "Ring 1", "Ring 2", "Ring 3", "Belt", "Charm 1", "Charm 2", "Charm 3", "Flask 1", "Flask 2" }

-- List control for stat pool (left column): shows stats from selected item, click to add to sort
local TradeStatPoolListControlClass = newClass("TradeStatPoolListControl", "ListControl", function(self, anchor, rect, queryTab)
	self.queryTab = queryTab
	self.filteredList = {}
	self.ListControl(anchor, rect, 16, true, false, self.filteredList)
end)
function TradeStatPoolListControlClass:UpdateFilteredList()
	local tab = self.queryTab
	if not tab or not tab.statPoolListData then
		wipeTable(self.filteredList)
		self.list = self.filteredList
		return
	end
	wipeTable(self.filteredList)
	local filter = (tab.statPoolSearchFilter or ""):lower()
	for _, entry in ipairs(tab.statPoolListData) do
		if filter == "" or (entry.label and entry.label:lower():find(filter, 1, true)) or (entry.stat and entry.stat:lower():find(filter, 1, true)) then
			t_insert(self.filteredList, entry)
		end
	end
	self.list = self.filteredList
end
function TradeStatPoolListControlClass:Draw(viewPort, noTooltip)
	self:UpdateFilteredList()
	self.ListControl.Draw(self, viewPort, noTooltip)
end
function TradeStatPoolListControlClass:GetRowValue(column, index, data)
	return data and data.label or ""
end
function TradeStatPoolListControlClass:OnSelClick(index, data, doubleClick)
	if not data or not self.queryTab then return end
	local tab = self.queryTab
	local entry = { stat = data.stat, label = data.label, priority = false, favorite = false, minVal = nil, maxVal = nil }
	t_insert(tab.clickSortStats, entry)
	if tab.controls.sortByList and tab.controls.sortByList.SelectIndex then
		-- #region agent log
		do
			local f = io.open("c:\\Users\\xpret\\AppData\\Roaming\\Path of Building Community (PoE2)\\.cursor\\debug.log", "a")
			if f then
				f:write(string.format('{"location":"TradeQuery.lua:OnSelClick add stat","message":"SelectIndex after add","data":{"index":%s},"timestamp":%d,"sessionId":"debug-session","hypothesisId":"H3"}\n', #tab.clickSortStats, (os.time() or 0) * 1000))
				f:close()
			end
		end
		-- #endregion
		tab.controls.sortByList:SelectIndex(#tab.clickSortStats)
	end
	if tab.sortPanelSelectedRowIdx and tab.resultTbl[tab.sortPanelSelectedRowIdx] then
		tab:RunDeferredSort(tab.sortPanelSelectedRowIdx, tab.sortModes.StatClick)
	end
end

-- List control for sort-by column (right): label + icons ! * X; Shift+click row to remove
local iconW = 18
local iconCount = 3
local iconTotalW = iconW * iconCount

local TradeSortByListControlClass = newClass("TradeSortByListControl", "ListControl", function(self, anchor, rect, queryTab)
	self.queryTab = queryTab
	self.ListControl(anchor, rect, 16, true, false, queryTab.clickSortStats or {})
	self.colList = {
		{ width = function(ctrl) local w = ctrl:GetSize(); return (w and w > 0 and w or 200) - 20 - iconTotalW end },
		{ width = iconW },
		{ width = iconW },
		{ width = iconW },
	}
end)
function TradeSortByListControlClass:GetRowValue(column, index, data)
	if not data then return "" end
	if column == 1 then return data.label or "" end
	if column == 2 then return "!" end
	if column == 3 then return "*" end
	if column == 4 then return "X" end
	return ""
end
function TradeSortByListControlClass:Draw(viewPort, noTooltip)
	local x, y = self:GetPos()
	local w, h = self:GetSize()
	local cx, cy = GetCursorPos()
	local rowRegion = self:GetRowRegion()
	local hoverIconCol = nil
	local hoverRow = nil
	if cx >= x + rowRegion.x and cy >= y + rowRegion.y and cx < x + rowRegion.x + rowRegion.width and cy < y + rowRegion.y + rowRegion.height then
		local relX = cx - (x + rowRegion.x)
		local relY = cy - (y + rowRegion.y)
		local scrollOffsetV = self.controls.scrollBarV and self.controls.scrollBarV.offset or 0
		local scrollOffsetH = self.controls.scrollBarH and self.controls.scrollBarH.offset or 0
		local rowHeight = self.rowHeight
		local row = math.floor((relY + scrollOffsetV) / rowHeight) + 1
		if row >= 1 and row <= #(self.queryTab.clickSortStats or {}) then
			local colOffset = 0
			for colIdx, column in ipairs(self.colList) do
				local colW = self:GetColumnProperty(column, "width") or (colIdx == #self.colList and self.scroll and w - 20 or w - colOffset) or 0
				local colStart = colOffset - scrollOffsetH
				local colEnd = colStart + colW
				if relX >= colStart and relX < colEnd then
					if colIdx >= 2 and colIdx <= 4 then
						hoverIconCol = colIdx
						hoverRow = row
					end
					break
				end
				colOffset = colOffset + colW
			end
		end
	end
	self.hoverIconCol = hoverIconCol
	self.hoverRow = hoverRow
	self.ListControl.Draw(self, viewPort, noTooltip)
end
function TradeSortByListControlClass:SetHighlightColor(index, value)
	if self.hoverIconCol and self.hoverRow == index then
		local x, y = self:GetPos()
		local w, h = self:GetSize()
		local rowRegion = self:GetRowRegion()
		local scrollOffsetV = self.controls.scrollBarV and self.controls.scrollBarV.offset or 0
		local scrollOffsetH = self.controls.scrollBarH and self.controls.scrollBarH.offset or 0
		local rowHeight = self.rowHeight
		local lineY = rowHeight * (index - 1) - scrollOffsetV + (self.colLabels and 18 or 0)
		local colOffset = 0
		for colIdx, column in ipairs(self.colList) do
			local colW = self:GetColumnProperty(column, "width") or (colIdx == #self.colList and self.scroll and w - 20 or w - colOffset) or 0
			if colIdx == self.hoverIconCol then
				local iconX = colOffset - scrollOffsetH
				SetDrawColor(0.3, 0.5, 0.8)
				DrawImage(nil, iconX, lineY, colW, rowHeight)
				return true
			end
			colOffset = colOffset + colW
		end
	end
	return false
end
function TradeSortByListControlClass:AddValueTooltip(tooltip, index, data)
	tooltip:Clear()
	if not data then return end
	if self.hoverIconCol == 2 then
		tooltip:AddLine(16, "! Priority - seek highest value for this stat")
	elseif self.hoverIconCol == 3 then
		tooltip:AddLine(16, "* Favorite - highlight on items that have it")
	elseif self.hoverIconCol == 4 then
		tooltip:AddLine(16, "X Remove from sort (or Shift+click row)")
	else
		tooltip:AddLine(16, "! Priority - seek highest value for this stat")
		tooltip:AddLine(16, "* Favorite - highlight on items that have it")
		tooltip:AddLine(16, "X Remove from sort (or Shift+click row)")
	end
end
function TradeSortByListControlClass:OnKeyDown(key, doubleClick)
	if not self:IsShown() or not self:IsEnabled() then
		return
	end
	if not key or not key:match("BUTTON") then
		return self.ListControl.OnKeyDown(self, key, doubleClick)
	end
	local tab = self.queryTab
	if not tab or not tab.clickSortStats then
		return self.ListControl.OnKeyDown(self, key, doubleClick)
	end
	local x, y = self:GetPos()
	local w, h = self:GetSize()
	local cx, cy = GetCursorPos()
	local rowRegion = self:GetRowRegion()
	if cx < x + rowRegion.x or cy < y + rowRegion.y or cx >= x + rowRegion.x + rowRegion.width or cy >= y + rowRegion.y + rowRegion.height then
		return self.ListControl.OnKeyDown(self, key, doubleClick)
	end
	local relX = cx - (x + rowRegion.x)
	local relY = cy - (y + rowRegion.y)
	local rowHeight = self.rowHeight
	local scrollOffsetV = self.controls.scrollBarV and self.controls.scrollBarV.offset or 0
	local scrollOffsetH = self.controls.scrollBarH and self.controls.scrollBarH.offset or 0
	local row = math.floor((relY + scrollOffsetV) / rowHeight) + 1
	if row < 1 or row > #tab.clickSortStats then
		return self.ListControl.OnKeyDown(self, key, doubleClick)
	end
	local data = tab.clickSortStats[row]
	if not data then
		return self.ListControl.OnKeyDown(self, key, doubleClick)
	end
	local colOffset = 0
	for colIdx, column in ipairs(self.colList) do
		local colW = self:GetColumnProperty(column, "width") or (colIdx == #self.colList and self.scroll and w - 20 or w - colOffset) or 0
		local colStart = colOffset - scrollOffsetH
		local colEnd = colStart + colW
		if relX >= colStart and relX < colEnd then
			if colIdx == 1 then
				if IsKeyDown("SHIFT") and key == "LEFTBUTTON" then
					tab.sortPanelUndoStack = tab.sortPanelUndoStack or {}
					if #tab.sortPanelUndoStack >= 10 then t_remove(tab.sortPanelUndoStack, 1) end
					local copy = {}
					for _, e in ipairs(tab.clickSortStats) do
						t_insert(copy, { stat = e.stat, label = e.label, priority = e.priority, favorite = e.favorite, minVal = e.minVal, maxVal = e.maxVal })
					end
					t_insert(tab.sortPanelUndoStack, copy)
					t_remove(tab.clickSortStats, row)
					if tab.sortPanelSelectedRowIdx and tab.resultTbl[tab.sortPanelSelectedRowIdx] then
						tab:RunDeferredSort(tab.sortPanelSelectedRowIdx, tab.sortModes.StatClick)
					end
					return self
				end
				return self.ListControl.OnKeyDown(self, key, doubleClick)
			elseif colIdx == 2 then
				data.priority = true
				t_remove(tab.clickSortStats, row)
				t_insert(tab.clickSortStats, 1, data)
				return self
			elseif colIdx == 3 then
				tab.favoriteStats = tab.favoriteStats or {}
				tab.favoriteStats[data.stat] = not tab.favoriteStats[data.stat]
				data.favorite = tab.favoriteStats[data.stat]
				return self
			elseif colIdx == 4 then
				tab.sortPanelUndoStack = tab.sortPanelUndoStack or {}
				if #tab.sortPanelUndoStack >= 10 then t_remove(tab.sortPanelUndoStack, 1) end
				local copy = {}
				for _, e in ipairs(tab.clickSortStats) do
					t_insert(copy, { stat = e.stat, label = e.label, priority = e.priority, favorite = e.favorite, minVal = e.minVal, maxVal = e.maxVal })
				end
				t_insert(tab.sortPanelUndoStack, copy)
				t_remove(tab.clickSortStats, row)
				if tab.sortPanelSelectedRowIdx and tab.resultTbl[tab.sortPanelSelectedRowIdx] then
					tab:RunDeferredSort(tab.sortPanelSelectedRowIdx, tab.sortModes.StatClick)
				end
				return self
			end
		end
		colOffset = colOffset + colW
	end
	return self.ListControl.OnKeyDown(self, key, doubleClick)
end
function TradeSortByListControlClass:OnSelect(index, value)
	if self.queryTab and self.queryTab.controls.sortPanelMinEdit and self.queryTab.controls.sortPanelMaxEdit and value then
		self.queryTab.controls.sortPanelMinEdit:SetText(value.minVal and tostring(value.minVal) or "", true)
		self.queryTab.controls.sortPanelMaxEdit:SetText(value.maxVal and tostring(value.maxVal) or "", true)
	elseif self.queryTab and self.queryTab.controls.sortPanelMinEdit and self.queryTab.controls.sortPanelMaxEdit then
		self.queryTab.controls.sortPanelMinEdit:SetText("", true)
		self.queryTab.controls.sortPanelMaxEdit:SetText("", true)
	end
end
function TradeSortByListControlClass:OnSelClick(index, data, doubleClick)
	if not data or not self.queryTab then return end
	if not IsKeyDown("SHIFT") then return end
	local tab = self.queryTab
	tab.sortPanelUndoStack = tab.sortPanelUndoStack or {}
	if #tab.sortPanelUndoStack >= 10 then t_remove(tab.sortPanelUndoStack, 1) end
	local copy = {}
	for _, e in ipairs(tab.clickSortStats) do
		t_insert(copy, { stat = e.stat, label = e.label, priority = e.priority, favorite = e.favorite, minVal = e.minVal, maxVal = e.maxVal })
	end
	t_insert(tab.sortPanelUndoStack, copy)
	t_remove(tab.clickSortStats, index)
	if tab.sortPanelSelectedRowIdx and tab.resultTbl[tab.sortPanelSelectedRowIdx] then
		tab:RunDeferredSort(tab.sortPanelSelectedRowIdx, tab.sortModes.StatClick)
	end
end

local TradeQueryClass = newClass("TradeQuery", function(self, itemsTab)
	self.itemsTab = itemsTab
	self.itemsTab.leagueDropList = { }
	self.totalPrice = { }
	self.controls = { }
	-- table of price results index by slot and number of fetched results
	self.resultTbl = { }
	self.sortedResultTbl = { }
	self.itemIndexTbl = { }
	-- Sort-by-stats panel (TRADER_SORT_BY_STATS_SPEC.md)
	self.clickSortStats = { }          -- list { stat, label, priority, favorite, minVal, maxVal }
	self.favoriteStats = { }           -- set [statName] = true
	self.sortPanelSelectedRowIdx = nil
	self.sortPanelSelectedItemIdx = nil
	self.statPoolListData = { }        -- filled by RefreshStatPool from selected item
	self.sortPanelUndoStack = { }     -- max 10, for Undo after remove
	self.sortingInProgress = false   -- true while UpdateControlsWithItems is running (show overlay)
	-- tooltip acceleration tables
	self.onlyWeightedBaseOutput = { }
	self.lastComparedWeightList = { }

	-- default set of trade item sort selection
	self.slotTables = { }
	self.pbItemSortSelectionIndex = 1
	self.pbCurrencyConversion = { }
	self.currencyConversionTradeMap = { }
	self.lastCurrencyConversionRequest = 0
	self.lastCurrencyFileTime = { }
	self.pbFileTimestampDiff = { }
	self.pbRealm = ""
	self.pbRealmIndex = 1
	self.pbLeagueIndex = 1
	-- table holding all realm/league pairs. (allLeagues[realm] = [league.id,...])
	self.allLeagues = {}
	-- realm id-text table to pair realm name with API parameter
	self.realmIds = {
		["PoE 2"]   = "poe2",
	}

	self.tradeQueryRequests = new("TradeQueryRequests")
	main.onFrameFuncs["TradeQueryRequests"] = function()
		self.tradeQueryRequests:ProcessQueue()
	end

	-- set
	self.hostName = "https://www.pathofexile.com/"
	self.lastSearchId = nil
end)

---Fetch currency short-names from Poe API (used for PoeNinja price pairing)
---@param callback fun()
function TradeQueryClass:FetchCurrencyConversionTable(callback)
	launch:DownloadPage(
		"https://www.pathofexile.com/api/trade2/data/static",
		function(response, errMsg)
			if errMsg then
				-- SKIP CALLBACK ON ERROR TO PREVENT PARTIAL DATA
				return
			end
			local obj = dkjson.decode(response.body)
			local currencyConversionTradeMap = {}
			local currencyTable
			for _, value in pairs(obj.result) do
				if value.id and value.id == "Currency" then
					currencyTable = value.entries
					break
				end
			end
			for _, value in pairs(currencyTable) do
				currencyConversionTradeMap[value.text:lower()] = value.id
			end
			self.currencyConversionTradeMap = currencyConversionTradeMap
			if callback then
				callback()
			end
		end)
end


-- Method to pull down and interpret available leagues from PoE
function TradeQueryClass:PullLeagueList()
	launch:DownloadPage(
		self.hostName .. "api/leagues?type=main&compact=1",
		function(response, errMsg)
			if errMsg then
				self:SetNotice(self.controls.pbNotice, "Error: " .. tostring(errMsg))
				return "POE ERROR", "Error: "..errMsg
			else
				local json_data = dkjson.decode(response.body)
				if not json_data then
					self:SetNotice(self.controls.pbNotice, "Failed to Get PoE League List response")
					return
				end
				table.sort(json_data, function(a, b)
					if a.endAt == nil then return false end
					if b.endAt == nil then return true end
					return a.id < b.id
				end)
				self.itemsTab.leagueDropList = {}
				for _, league_data in pairs(json_data) do
					if not league_data.id:find("SSF") then
						t_insert(self.itemsTab.leagueDropList,league_data.id)
					end
				end
				self.controls.league:SetList(self.itemsTab.leagueDropList)
				self.controls.league.selIndex = 1
				self.pbLeague = self.itemsTab.leagueDropList[self.controls.league.selIndex]
				self:SetCurrencyConversionButton()
			end
		end)
end

-- Method to convert currency to chaos equivalent
function TradeQueryClass:ConvertCurrencyToChaos(currency, amount)
	local conversionTable = self.pbCurrencyConversion[self.pbLeague]

	-- we take the ceiling of all prices to integer chaos
	-- to prevent dealing with shenanigans of people asking 4.9 chaos
	if conversionTable and conversionTable[currency:lower()] then
		--ConPrintf("Converted '"..currency.."' at " ..tostring(conversionTable[currency:lower()]))
		return m_ceil(amount * conversionTable[currency:lower()])
	elseif currency:lower() == "chaos" then
		return m_ceil(amount)
	else
		ConPrintf("Unhandled Currency Conversion: '" .. currency:lower() .. "'")
		return nil
	end
end

-- Method to pull down and interpret the PoE.Ninja JSON endpoint data
function TradeQueryClass:PullPoENinjaCurrencyConversion(league)
	local now = get_time()
	-- Limit PoE Ninja Currency Conversion request to 1 per hour
	if (now - self.lastCurrencyConversionRequest) < 3600 then
		self:SetNotice(self.controls.pbNotice, "PoE Ninja Rate Limit Exceeded: " .. tostring(3600 - (now - self.lastCurrencyConversionRequest)))
		return
	end
	-- We are getting currency short-names from Poe API before getting PoeNinja rates
	-- Potentially, currency short-names could be cached but this request runs
	-- once per hour at most and the Poe API response is already Cloudflare cached
	self:FetchCurrencyConversionTable(function(data, errMsg)
		if errMsg then
			self:SetNotice(self.controls.pbNotice, "Error: " .. tostring(errMsg))
			return
		end
		self.pbCurrencyConversion[league] = { }
		self.lastCurrencyConversionRequest = now
		launch:DownloadPage(
			"https://poe.ninja/api/data/CurrencyRates?league=" .. urlEncode(league),
			function(response, errMsg)
				if errMsg then
					self:SetNotice(self.controls.pbNotice, "Error: " .. tostring(errMsg))
					return
				end
				local json_data = dkjson.decode(response.body)
				if not json_data then
					self:SetNotice(self.controls.pbNotice, "Failed to Get PoE Ninja response")
					return
				end
				self:PriceBuilderProcessPoENinjaResponse(json_data, self.controls)
				local print_str = ""
				for key, value in pairs(self.pbCurrencyConversion[self.pbLeague]) do
					print_str = print_str .. '"'..key..'": '..tostring(value)..','
				end
				local foo = io.open("../"..self.pbLeague.."_currency_values.json", "w")
				foo:write("{" .. print_str .. '"updateTime": ' .. tostring(get_time()) .. "}")
				foo:close()
				self:SetCurrencyConversionButton()
			end)
	end)
end

-- Method to process the PoE.Ninja response
function TradeQueryClass:PriceBuilderProcessPoENinjaResponse(resp)
	if resp then
		-- Populate the chaos-converted values for each tradeId
		for currencyName, chaosEquivalent in pairs(resp) do
			if self.currencyConversionTradeMap[currencyName] then
				self.pbCurrencyConversion[self.pbLeague][self.currencyConversionTradeMap[currencyName]] = chaosEquivalent
			else
				ConPrintf("Unhandled Currency Name: '"..currencyName.."'")
			end
		end
	else
		self:SetNotice(self.controls.pbNotice, "PoE Ninja JSON Processing Error")
	end
end

local function initStatSortSelectionList(list)
	t_insert(list,  {
		label = "Full DPS",
		stat = "FullDPS",
		weightMult = 1.0,
	})
	t_insert(list,  {
		label = "Effective Hit Pool",
		stat = "TotalEHP",
		weightMult = 0.5,
	})
end

-- we do not want to overwrite previous list if the new list is the default, e.g. hitting reset multiple times in a row
local function isSameAsDefaultList(list)
	return list and #list == 2
		and list[1].stat == "FullDPS" and list[1].weightMult == 1.0
		and list[2].stat == "TotalEHP" and list[2].weightMult == 0.5
end

-- Opens the item pricing popup
function TradeQueryClass:PriceItem()
	self.tradeQueryGenerator = new("TradeQueryGenerator", self)
	main.onFrameFuncs["TradeQueryGenerator"] = function()
		self.tradeQueryGenerator:OnFrame()
	end

	-- Set main Price Builder pane height and width
	local row_height = 20
	local row_vertical_padding = 4
	local top_pane_alignment_ref = nil
	local pane_margins_horizontal = 16
	local pane_margins_vertical = 16

	local newItemList = { }
	for index, itemSetId in ipairs(self.itemsTab.itemSetOrderList) do
		local itemSet = self.itemsTab.itemSets[itemSetId]
		t_insert(newItemList, itemSet.title or "Default")
	end
	self.controls.setSelect = new("DropDownControl", {"TOPLEFT", nil, "TOPLEFT"}, {pane_margins_horizontal, pane_margins_vertical, 188, row_height}, newItemList, function(index, value)
		self.itemsTab:SetActiveItemSet(self.itemsTab.itemSetOrderList[index])
		self.itemsTab:AddUndoState()
	end)
	self.controls.setSelect.enableDroppedWidth = true
	self.controls.setSelect.enabled = function()
		return #self.itemsTab.itemSetOrderList > 1
	end

	self.controls.poesessidButton = new("ButtonControl", {"TOPLEFT", self.controls.setSelect, "TOPLEFT"}, {0, row_height + row_vertical_padding, 188, row_height}, function() return main.POESESSID ~= "" and "^2Session Mode" or colorCodes.WARNING.."No Session Mode" end, function()
		local poesessid_controls = {}
		poesessid_controls.sessionInput = new("EditControl", nil, {0, 18, 350, 18}, main.POESESSID, nil, "%X", 32)
		poesessid_controls.sessionInput:SetProtected(true)
		poesessid_controls.sessionInput.placeholder = "Enter your session ID here"
		poesessid_controls.sessionInput.tooltipText = "You can get this from your web browser's cookies while logged into the Path of Exile website."
		poesessid_controls.save = new("ButtonControl", {"TOPRIGHT", poesessid_controls.sessionInput, "TOP"}, {-8, 24, 90, row_height}, "Save", function()
			main.POESESSID = poesessid_controls.sessionInput.buf
			main:ClosePopup()
			main:SaveSettings()
			self:UpdateRealms()
		end)
		poesessid_controls.save.enabled = function() return #poesessid_controls.sessionInput.buf == 32 or poesessid_controls.sessionInput.buf == "" end
		poesessid_controls.cancel = new("ButtonControl", {"TOPLEFT", poesessid_controls.sessionInput, "TOP"}, {8, 24, 90, row_height}, "Cancel", function()
			main:ClosePopup()
		end)
		main:OpenPopup(364, 72, "Change session ID", poesessid_controls)
	end)
	self.controls.poesessidButton.tooltipText = [[
The Trader feature supports two modes of operation depending on the POESESSID availability.
You can click this button to enter your POESESSID.

^2Session Mode^7
- Requires POESESSID.
- You can search, compare, and quickly import items without leaving Path of Building.
- You can generate and perform searches for the private leagues you are participating.

^xFF9922No Session Mode^7
- Doesn't require POESESSID.
- You cannot search and compare items in Path of Building.
- You can generate weighted search URLs but have to visit the trade site and manually import items.
- You can only generate weighted searches for public leagues. (Generated searches can be modified
on trade site to work on other leagues and realms)]]

-- Fetches Box (domyślnie 3 strony; max 50)
	local fetchPagesMax = 50
	local defaults = main.tradeDefaults or {}
	local savedFetch = (defaults.fetchPages and m_min(m_max(defaults.fetchPages, 1), fetchPagesMax)) or nil
	self.maxFetchPerSearchDefault = savedFetch or 3
	self.maxFetchPages = self.maxFetchPerSearchDefault
	self.controls.fetchCountEdit = new("EditControl", {"TOPRIGHT", nil, "TOPRIGHT"}, {-12, 19, 154, row_height}, "", "Fetch Pages", "%D", 3, function(buf)
		self.maxFetchPages = m_min(m_max(tonumber(buf) or self.maxFetchPerSearchDefault, 1), fetchPagesMax)
		self.tradeQueryRequests.maxFetchPerSearch = 10 * self.maxFetchPages
		self.controls.fetchCountEdit.focusValue = self.maxFetchPages
		main.tradeDefaults = main.tradeDefaults or {}
		main.tradeDefaults.fetchPages = self.maxFetchPages
	end)
	self.controls.fetchCountEdit.focusValue = self.maxFetchPerSearchDefault
	self.tradeQueryRequests.maxFetchPerSearch = 10 * self.maxFetchPerSearchDefault
	self.controls.fetchCountEdit:SetText(tostring(self.maxFetchPages or self.maxFetchPerSearchDefault))
	function self.controls.fetchCountEdit:OnFocusLost()
		self:SetText(tostring(self.focusValue))
	end
	self.controls.fetchCountEdit.tooltipFunc = function(tooltip)
		tooltip:Clear()
		tooltip:AddLine(16, "Specify maximum number of item pages to retrieve per search from PoE Trade.")
		tooltip:AddLine(16, "Each page fetches up to 10 items.")
		tooltip:AddLine(16, s_format("Acceptable Range is: 1 to %d", fetchPagesMax))
	end

	-- Stat sort popup button
	-- if the list is nil or empty, set default sorting, otherwise keep whatever was loaded from xml
	if not self.statSortSelectionList or (#self.statSortSelectionList) == 0 then
		self.statSortSelectionList = { }
		initStatSortSelectionList(self.statSortSelectionList)
	end
	self.controls.StatWeightMultipliersButton = new("ButtonControl", {"TOPRIGHT", self.controls.fetchCountEdit, "BOTTOMRIGHT"}, {0, row_vertical_padding, 150, row_height}, "^7Adjust search weights", function()
		self.itemsTab.modFlag = true
		self:SetStatWeights()
	end)
	self.controls.StatWeightMultipliersButton.tooltipFunc = function(tooltip)
		tooltip:Clear()
		tooltip:AddLine(16, "Sorts the weights by the stats selected multiplied by a value")
		tooltip:AddLine(16, "Currently sorting by:")
		for _, stat in ipairs(self.statSortSelectionList) do
			tooltip:AddLine(16, s_format("%s: %.2f", stat.label, stat.weightMult))
		end
	end
	self.sortModes = {
		StatValue = "(Highest) Stat Value",
		StatValuePrice = "Stat Value / Price",
		Price = "(Lowest) Price",
		Weight = "(Highest) Weighted Sum",
		StatClick = "(Sort by) Selected stats",
	}
	-- Item sort dropdown
	self.itemSortSelectionList = {
		self.sortModes.StatValue,
		self.sortModes.StatValuePrice,
		self.sortModes.Price,
		self.sortModes.Weight,
		self.sortModes.StatClick,
	}
	self.controls.itemSortSelection = new("DropDownControl", {"TOPRIGHT", self.controls.StatWeightMultipliersButton, "TOPLEFT"}, {-8, 0, 170, row_height}, self.itemSortSelectionList, function(index, value)
		self.pbItemSortSelectionIndex = index
		for row_idx, _ in pairs(self.resultTbl) do
			self:UpdateControlsWithItems(row_idx)
		end
	end)
	self.controls.itemSortSelection.tooltipText =
[[Weighted Sum searches will always sort using descending weighted sum
Additional post filtering options can be done these include:
Highest Stat Value - Sort from highest to lowest Stat Value change of equipping item
Highest Stat Value / Price - Sorts from highest to lowest Stat Value per currency
Lowest Price - Sorts from lowest to highest price of retrieved items
Highest Weight - Displays the order retrieved from trade]]
	self.controls.itemSortSelection:SetSel(self.pbItemSortSelectionIndex)
	self.controls.itemSortSelectionLabel = new("LabelControl", {"TOPRIGHT", self.controls.itemSortSelection, "TOPLEFT"}, {-4, 0, 60, 16}, "^7Sort By:")

	-- Use Enchant in DPS sorting
	self.controls.enchantInSort = new("CheckBoxControl", {"TOPRIGHT",self.controls.fetchCountEdit,"TOPLEFT"}, {-8, 0, row_height}, "Include Enchants:", function(state)
		self.enchantInSort = state
		for row_idx, _ in pairs(self.resultTbl) do
			self:UpdateControlsWithItems(row_idx)
		end
	end)
	self.controls.enchantInSort.tooltipText = "This includes enchants in sorting that occurs after trade results have been retrieved"

	self.controls.updateCurrencyConversion = new("ButtonControl", {"BOTTOMLEFT", nil, "BOTTOMLEFT"}, {pane_margins_horizontal, -pane_margins_vertical, 240, row_height}, "Get Currency Conversion Rates", function()
		-- self:PullPoENinjaCurrencyConversion(self.pbLeague)
	end)
	self.controls.pbNotice = new("LabelControl",  {"BOTTOMRIGHT", nil, "BOTTOMRIGHT"}, {-row_height - pane_margins_vertical - row_vertical_padding, -pane_margins_vertical - row_height - row_vertical_padding, 300, row_height}, "")

	-- Realm selection
	self.controls.realmLabel = new("LabelControl", {"LEFT", self.controls.setSelect, "RIGHT"}, {18, 0, 20, row_height - 4}, "^7Realm:")
	self.controls.realm = new("DropDownControl", {"LEFT", self.controls.realmLabel, "RIGHT"}, {6, 0, 150, row_height}, self.realmDropList, function(index, value)
		self.pbRealmIndex = index
		self.pbRealm = self.realmIds[value]
		local function setLeagueDropList()
			self.itemsTab.leagueDropList = copyTable(self.allLeagues[self.pbRealm])
			self.controls.league:SetList(self.itemsTab.leagueDropList)
			-- invalidate selIndex to trigger select function call in the SetSel
			self.controls.league.selIndex = nil
			self.controls.league:SetSel(self.pbLeagueIndex)
			self:SetCurrencyConversionButton()
		end
		if self.allLeagues[self.pbRealm] then
			setLeagueDropList()
		else
			self.tradeQueryRequests:FetchLeagues(self.pbRealm, function(leagues, errMsg)
				if errMsg then
					self:SetNotice(self.controls.pbNotice, "Error while fetching league list: "..errMsg)
					return
				end
				local sorted_leagues = { }
				for _, league in ipairs(leagues) do
					if league ~= "Standard" and league ~= "Hardcore" then
						t_insert(sorted_leagues, league)
					end
				end
				t_insert(sorted_leagues, "Standard")
				t_insert(sorted_leagues, "Hardcore")
				self.allLeagues[self.pbRealm] = sorted_leagues
				setLeagueDropList()
			end)
		end
	end)
	self.controls.realm:SetSel(self.pbRealmIndex)
	self.controls.realm.enabled = function()
		return #self.controls.realm.list > 1
	end

	-- League selection
	self.controls.leagueLabel = new("LabelControl", {"TOPRIGHT", self.controls.realmLabel, "TOPRIGHT"}, {0, row_height + row_vertical_padding, 20, row_height - 4}, "^7League:")
	self.controls.league = new("DropDownControl", {"LEFT", self.controls.leagueLabel, "RIGHT"}, {6, 0, 150, row_height}, self.itemsTab.leagueDropList, function(index, value)
		self.pbLeagueIndex = index
		self.pbLeague = value
		self:SetCurrencyConversionButton()
	end)
	self.controls.league:SetSel(self.pbLeagueIndex)
	self.controls.league.enabled = function()
		return #self.controls.league.list > 1
	end

	if self.pbRealm == "" then
		self:UpdateRealms()
	end

	-- Individual slot rows
	local slotTables = {}
	for _, slotName in ipairs(baseSlots) do
		if self.itemsTab.slots[slotName].shown() then
			t_insert(slotTables, { slotName = slotName })
		end
	end
	local activeSocketList = { }
	for nodeId, slot in pairs(self.itemsTab.sockets) do
		if not slot.inactive then
			t_insert(activeSocketList, nodeId)
		end
	end
	table.sort(activeSocketList)
	for _, nodeId in ipairs(activeSocketList) do
		t_insert(slotTables, { slotName = self.itemsTab.sockets[nodeId].label, nodeId = nodeId })
	end

	self.controls.sectionAnchor = new("LabelControl", {"LEFT", self.controls.poesessidButton, "LEFT"}, {0, 0, 0, 0}, "")
	top_pane_alignment_ref = {"TOPLEFT", self.controls.sectionAnchor, "TOPLEFT"}
	local scrollBarShown = #slotTables > 21 -- clipping starts beyond this
	-- dynamically hide rows that are above or below the scrollBar
	local hideRowFunc = function(self, index)
		if scrollBarShown then
			-- 22 items fit in the scrollBar "box" so as the offset moves, we need to dynamically show what is within the boundaries
			if (index < 23 and (self.controls.scrollBar.offset < ((row_height + row_vertical_padding)*(index-1) + row_vertical_padding))) or
				-- the second and in this applies if we have more than 44 slots because we need to hide the next "page" of rows as they go above the line, e.g. #23 could be above or below the "box"
				(index >= 23 and (self.controls.scrollBar.offset > (row_height + row_vertical_padding)*(index-22) and self.controls.scrollBar.offset < (row_height + row_vertical_padding)*(index-1))) then
				return true
			end
		else
			return true
		end
		return false
	end
	for index, slotTbl in pairs(slotTables) do
		self.slotTables[index] = slotTbl
		self:PriceItemRowDisplay(index, top_pane_alignment_ref, row_vertical_padding, row_height)
		self.controls["name"..index].shown = function()
			return hideRowFunc(self, index)
		end
	end

	self.controls.otherTradesLabel = new("LabelControl", top_pane_alignment_ref, {0, (#slotTables+1)*(row_height + row_vertical_padding), 100, 16}, "^8Other trades:")
	self.controls.otherTradesLabel.shown = function()
		return hideRowFunc(self, #slotTables+1)
	end
	local row_count = #slotTables + 1
	self.slotTables[row_count] = { slotName = "Megalomaniac", unique = true, alreadyCorrupted = true }
	self:PriceItemRowDisplay(row_count, top_pane_alignment_ref, row_vertical_padding, row_height)
	self.controls["name"..row_count].y = self.controls["name"..row_count].y + (row_height + row_vertical_padding) -- Megalomaniac needs to drop an extra row for "Other Trades"
	self.controls["name"..row_count].shown = function()
		return hideRowFunc(self, row_count)
	end
	row_count = row_count + 1

	local sortPanelGap = 50
	local sortPanelHeight = 160
	local sortListRowHeight = 16
	local effective_row_count = row_count - ((scrollBarShown and #slotTables >= 19) and #slotTables-19 or 0) + 2 + 2 -- Two top menu rows, two bottom rows, slots after #19 overlap the other controls at the bottom of the pane
	self.effective_rows_height = row_height * (effective_row_count - #slotTables + (18 - (#slotTables > 37 and 3 or 0))) + sortPanelGap + sortPanelHeight -- include stats panel area below rows
	self.pane_height = (row_height + row_vertical_padding) * effective_row_count + 3 * pane_margins_vertical + row_height / 2 + sortPanelGap + sortPanelHeight
	local pane_width = 950 + (scrollBarShown and 25 or 0)

	self.controls.scrollBar = new("ScrollBarControl", {"TOPRIGHT", self.controls["StatWeightMultipliersButton"],"TOPRIGHT"}, {0, 25, 18, 0}, 50, "VERTICAL", false)
	self.controls.scrollBar.shown = function() return scrollBarShown end

	local function wipeItemControls()
		for index, _ in pairs(self.controls) do
			if index:match("%d") then
				self.controls[index] = nil
			end
		end
	end
	-- Sort-by-stats panel: inside Trader window, 50px below item rows; +10 so "Sort by stats" doesn't cover "Stat pool"
	local sortPanelY = row_count * (row_height + row_vertical_padding) + sortPanelGap + 10
	self.controls.sortPanelAnchor = new("LabelControl", top_pane_alignment_ref, {0, sortPanelY, 0, 0}, "")
	self.controls.sortPanelAnchor.queryTab = self
	self.controls.sortPanelAnchor.shown = function(a)
		local tab = a.queryTab
		for _, _ in pairs(tab.resultTbl) do return true end
		return false
	end
	local sortPanelBoxW = pane_width - 2 * pane_margins_horizontal
	self.controls.sortPanelBox = new("SectionControl", {"TOPLEFT", self.controls.sortPanelAnchor, "TOPLEFT"}, {0, 0, sortPanelBoxW, sortPanelHeight}, "Sort by stats")
	self.controls.sortPanelBox.queryTab = self
	self.controls.sortPanelBox.shown = function(box)
		return box.queryTab.controls.sortPanelAnchor:IsShown()
	end
	local sortListH = sortPanelHeight - row_height * 2 - 36
	local halfW = (sortPanelBoxW - 24) / 2
	self.controls.sortPanelCol1Label = new("LabelControl", {"TOPLEFT", self.controls.sortPanelBox, "TOPLEFT"}, {0, 12, halfW, row_height}, "^7Stat pool (select item from list)")
	self.controls.sortPanelCol1Label.queryTab = self
	self.controls.sortPanelCol1Label.shown = function(lbl) return lbl.queryTab.controls.sortPanelBox:IsShown() end
	self.statPoolSearchFilter = ""
	self.controls.statPoolSearch = new("EditControl", {"TOPLEFT", self.controls.sortPanelCol1Label, "BOTTOMLEFT"}, {0, 2, halfW, row_height}, "", "Search for stat", "%c", 100, function(buf)
		self.statPoolSearchFilter = buf:lower()
	end)
	self.controls.statPoolSearch.queryTab = self
	self.controls.statPoolSearch.shown = function(c) return c.queryTab.controls.sortPanelBox:IsShown() end
	self.controls.statPoolList = new("TradeStatPoolListControl", {"TOPLEFT", self.controls.statPoolSearch, "BOTTOMLEFT"}, {0, 2, halfW, sortListH}, self)
	self.controls.statPoolList.queryTab = self
	self.controls.statPoolList.shown = function(c) return c.queryTab.controls.sortPanelBox:IsShown() end
	self.controls.sortPanelCol2Label = new("LabelControl", {"TOPLEFT", self.controls.sortPanelBox, "TOPLEFT"}, {halfW + 12, 12, halfW, row_height}, "^7Sort by (click: add, Shift+click: remove)")
	self.controls.sortPanelCol2Label.queryTab = self
	self.controls.sortPanelCol2Label.shown = function(lbl) return lbl.queryTab.controls.sortPanelBox:IsShown() end
	self.controls.sortByList = new("TradeSortByListControl", {"TOPLEFT", self.controls.sortPanelCol2Label, "BOTTOMLEFT"}, {0, 2, halfW, sortListH}, self)
	self.controls.sortByList.queryTab = self
	self.controls.sortByList.shown = function(c) return c.queryTab.controls.sortPanelBox:IsShown() end
	self.controls.sortPanelClearBtn = new("ButtonControl", {"BOTTOMLEFT", self.controls.sortPanelBox, "BOTTOMLEFT"}, {0, -2, 90, row_height}, "Clear all", function()
		local tab = self
		tab.sortPanelUndoStack = tab.sortPanelUndoStack or {}
		if #tab.sortPanelUndoStack >= 10 then t_remove(tab.sortPanelUndoStack, 1) end
		local copy = {}
		for _, e in ipairs(tab.clickSortStats) do
			t_insert(copy, { stat = e.stat, label = e.label, priority = e.priority, favorite = e.favorite, minVal = e.minVal, maxVal = e.maxVal })
		end
		t_insert(tab.sortPanelUndoStack, copy)
		wipeTable(tab.clickSortStats)
		if tab.sortPanelSelectedRowIdx and tab.resultTbl[tab.sortPanelSelectedRowIdx] then
			tab:RunDeferredSort(tab.sortPanelSelectedRowIdx, tab.sortModes.StatValue)
		end
	end)
	self.controls.sortPanelClearBtn.queryTab = self
	self.controls.sortPanelClearBtn.shown = function(c) return c.queryTab.controls.sortPanelBox:IsShown() end
	self.controls.sortPanelUndoBtn = new("ButtonControl", {"LEFT", self.controls.sortPanelClearBtn, "RIGHT"}, {4, 0, 80, row_height}, function()
		local n = #(self.sortPanelUndoStack or {})
		return n > 0 and ("Undo (" .. n .. ")") or "Undo (0)"
	end, function()
		local tab = self
		if not tab.sortPanelUndoStack or #tab.sortPanelUndoStack == 0 then return end
		local restored = t_remove(tab.sortPanelUndoStack)
		wipeTable(tab.clickSortStats)
		for _, e in ipairs(restored) do
			t_insert(tab.clickSortStats, e)
		end
		if tab.sortPanelSelectedRowIdx and tab.resultTbl[tab.sortPanelSelectedRowIdx] then
			tab:RunDeferredSort(tab.sortPanelSelectedRowIdx, tab.sortModes.StatClick)
		end
	end)
	self.controls.sortPanelUndoBtn.queryTab = self
	self.controls.sortPanelUndoBtn.shown = function(c) return c.queryTab.controls.sortPanelBox:IsShown() end
	self.controls.sortPanelUndoBtn.enabled = function() return #(self.sortPanelUndoStack or {}) > 0 end
	self.controls.sortPanelMinLabel = new("LabelControl", {"LEFT", self.controls.sortPanelUndoBtn, "RIGHT"}, {12, 0, 70, row_height}, "^7Greater than:")
	self.controls.sortPanelMinLabel.queryTab = self
	self.controls.sortPanelMinLabel.shown = function(lbl) return lbl.queryTab.controls.sortPanelBox:IsShown() end
	self.controls.sortPanelMinEdit = new("EditControl", {"LEFT", self.controls.sortPanelMinLabel, "RIGHT"}, {2, 0, 50, row_height}, "", nil, "^[%d%.%-]", 10, function(buf)
		local tab = self
		local selIdx = (tab.sortByList and tab.sortByList.selIndex) or 1
		local entry = tab.clickSortStats and tab.clickSortStats[selIdx]
		-- #region agent log
		do
			local f = io.open("c:\\Users\\xpret\\AppData\\Roaming\\Path of Building Community (PoE2)\\.cursor\\debug.log", "a")
			if f then
				f:write(string.format('{"location":"TradeQuery.lua:sortPanelMinEdit callback","message":"Greater than changed","data":{"bufLen":%s,"selIdx":%s,"hasEntry":%s},"timestamp":%d,"sessionId":"debug-session","hypothesisId":"H2"}\n', buf and #buf or 0, selIdx or 0, tostring(entry ~= nil), (os.time() or 0) * 1000))
				f:close()
			end
		end
		-- #endregion
		if entry then
			entry.minVal = (buf and buf ~= "") and buf or nil
			if tab.sortPanelSelectedRowIdx and tab.resultTbl[tab.sortPanelSelectedRowIdx] then
				tab:RunDeferredSort(tab.sortPanelSelectedRowIdx, tab.sortModes.StatClick)
			end
		end
	end)
	self.controls.sortPanelMinEdit.queryTab = self
	self.controls.sortPanelMinEdit.tooltipFunc = function(tooltip) tooltip:Clear() tooltip:AddLine(16, "Filter: stat >= value (inclusive)") end
	self.controls.sortPanelMinEdit.shown = function(c)
		local tab = c.queryTab
		return tab.controls.sortPanelBox:IsShown() and tab.clickSortStats and #tab.clickSortStats >= 1
	end
	self.controls.sortPanelMaxLabel = new("LabelControl", {"LEFT", self.controls.sortPanelMinEdit, "RIGHT"}, {4, 0, 70, row_height}, "^7Less than:")
	self.controls.sortPanelMaxLabel.queryTab = self
	self.controls.sortPanelMaxLabel.shown = function(lbl)
		local tab = lbl.queryTab
		return tab.controls.sortPanelBox:IsShown() and tab.clickSortStats and #tab.clickSortStats >= 1
	end
	self.controls.sortPanelMaxEdit = new("EditControl", {"LEFT", self.controls.sortPanelMaxLabel, "RIGHT"}, {2, 0, 50, row_height}, "", nil, "^[%d%.%-]", 10, function(buf)
		local tab = self
		local selIdx = (tab.sortByList and tab.sortByList.selIndex) or 1
		local entry = tab.clickSortStats and tab.clickSortStats[selIdx]
		if entry then
			entry.maxVal = (buf and buf ~= "") and buf or nil
			if tab.sortPanelSelectedRowIdx and tab.resultTbl[tab.sortPanelSelectedRowIdx] then
				tab:RunDeferredSort(tab.sortPanelSelectedRowIdx, tab.sortModes.StatClick)
			end
		end
	end)
	self.controls.sortPanelMaxEdit.queryTab = self
	self.controls.sortPanelMaxEdit.tooltipFunc = function(tooltip) tooltip:Clear() tooltip:AddLine(16, "Filter: stat <= value (inclusive)") end
	self.controls.sortPanelMaxEdit.shown = function(c)
		local tab = c.queryTab
		return tab.controls.sortPanelBox:IsShown() and tab.clickSortStats and #tab.clickSortStats >= 1
	end

	-- Overlay shown during sorting (deferred so one frame shows "Sorting..." before blocking)
	self.controls.sortingOverlay = new("LabelControl", {"TOPLEFT", self.controls.sectionAnchor, "TOPLEFT"}, {0, 0, pane_width, self.pane_height}, "Sorting, please wait...")
	self.controls.sortingOverlay.queryTab = self
	self.controls.sortingOverlay.shown = function(c) return c.queryTab.sortingInProgress end
	self.controls.sortingOverlay.Draw = function(ctrl, viewPort, noTooltip)
		if not ctrl:IsShown() then return end
		local x, y = ctrl:GetPos()
		local w, h = ctrl:GetSize()
		SetDrawColor(0.1, 0.1, 0.1, 0.85)
		DrawImage(nil, x, y, w, h)
		SetDrawColor(1, 1, 1)
		local msg = "Sorting, please wait..."
		local fh = 18
		local fw = DrawStringWidth(fh, "VAR", msg)
		DrawString(x + (w - fw) / 2, y + (h - fh) / 2, "LEFT", fh, "VAR", msg)
	end

	self.controls.fullPrice = new("LabelControl", {"BOTTOM", nil, "BOTTOM"}, {0, -row_height - pane_margins_vertical - row_vertical_padding, pane_width - 2 * pane_margins_horizontal, row_height}, "")
	self.controls.fullPrice.y = function()
		return -row_height - pane_margins_vertical - row_vertical_padding
	end
	self.controls.close = new("ButtonControl", {"BOTTOM", nil, "BOTTOM"}, {0, -pane_margins_vertical, 90, row_height}, "Done", function()
		main.tradeDefaults = main.tradeDefaults or {}
		main.tradeDefaults.fetchPages = self.maxFetchPages or self.maxFetchPerSearchDefault
		local popup = main.popups and main.popups[1]
		if popup and popup.GetSize then
			local w, h = popup:GetSize()
			if w and h then
				main.tradeDefaults.traderWidth = w
				main.tradeDefaults.traderHeight = h
			end
		end
		main:SaveSettings()
		main:ClosePopup()
		wipeItemControls()
	end)
	self.controls.reSearchBtn = new("ButtonControl", {"RIGHT", self.controls.close, "LEFT"}, {-4, 0, 90, row_height}, "^x50E050RE-SEARCH", function()
		local row_idx = self.sortPanelSelectedRowIdx
		if not row_idx then return end
		local uriCtrl = self.controls["uri"..row_idx]
		local priceBtn = self.controls["priceButton"..row_idx]
		if uriCtrl and uriCtrl.validURL and priceBtn and priceBtn.enabled and priceBtn.enabled() then
			priceBtn.label = "Searching..."
			self.tradeQueryRequests:SearchWithURL(uriCtrl.buf, function(items, errMsg)
				if errMsg then
					self:SetNotice(self.controls.pbNotice, "Error: " .. errMsg)
				else
					self:SetNotice(self.controls.pbNotice, "")
					self.resultTbl[row_idx] = items
					self:RunDeferredSort(row_idx, self.sortModes.StatClick)
				end
				priceBtn.label = "Price Item"
			end, {
				callbackQueryId = function(queryId, realm, league)
					self.lastSearchId = queryId
					realm = realm or self.pbRealm
					league = league or self.pbLeague
					local url = self.tradeQueryRequests:buildUrl(
						self.hostName .. "trade2/search", realm, league, queryId)
					uriCtrl:SetText(url, true)
				end
			})
		elseif self.resultTbl[row_idx] then
			self:RunDeferredSort(row_idx, self.sortModes.StatClick)
		end
	end)
	self.controls.reSearchBtn.shown = function()
		local row = self.sortPanelSelectedRowIdx
		if not row or not self.controls["uri"..row] then return false end
		return self.controls["uri"..row].validURL or (self.resultTbl[row] and #self.resultTbl[row] > 0)
	end

	-- used in PopupDialog:Draw()
	local function scrollBarFunc()
		self.controls.scrollBar.height = self.pane_height-100
		self.controls.scrollBar:SetContentDimension(self.pane_height-100, self.effective_rows_height)
		self.controls.sectionAnchor.y = -self.controls.scrollBar.offset
	end
	-- Trader window: 5% from top for more space; use saved size if valid else content size
	local defW = (main.tradeDefaults and main.tradeDefaults.traderWidth) or pane_width
	local defH = (main.tradeDefaults and main.tradeDefaults.traderHeight) or self.pane_height
	local openW = m_max(pane_width, m_min(1200, defW))
	local openH = m_max(self.pane_height, m_min(main.screenH - 80, defH))
	main:OpenPopup(openW, openH, "Trader", self.controls, nil, nil, "close", (scrollBarShown and scrollBarFunc or nil), nil, 0.05)
end

-- Popup to set stat weight multipliers for sorting
function TradeQueryClass:SetStatWeights(previousSelectionList)
	previousSelectionList = previousSelectionList or {}
	local controls = { }
	local statList = { }
	local sliderController = { index = 1 }
	local popupHeight = 285

	controls.ListControl = new("TradeStatWeightMultiplierListControl", {"TOPLEFT", nil, "TOPRIGHT"}, {-410, 45, 400, 200}, statList, sliderController)

	for id, stat in pairs(data.powerStatList) do
		if not stat.ignoreForItems and stat.label ~= "Name" then
			t_insert(statList, {
				label = "0      :  "..stat.label,
				stat = {
					label = stat.label,
					stat = stat.stat,
					transform = stat.transform,
					weightMult = 0,
				}
			})
		end
	end

	controls.SliderLabel = new("LabelControl", { "TOPLEFT", nil, "TOPRIGHT" }, {-410, 20, 0, 16}, "^7"..statList[1].stat.label..":")
	controls.Slider = new("SliderControl", { "TOPLEFT", controls.SliderLabel, "TOPRIGHT" }, {20, 0, 150, 16}, function(value)
		if value == 0 then
			controls.SliderValue.label = "^7Disabled"
			statList[sliderController.index].stat.weightMult = 0
			statList[sliderController.index].label = s_format("%d      :  ", 0)..statList[sliderController.index].stat.label
		else
			controls.SliderValue.label = s_format("^7%.2f", 0.01 + value * 0.99)
			statList[sliderController.index].stat.weightMult = 0.01 + value * 0.99
			statList[sliderController.index].label = s_format("%.2f :  ", 0.01 + value * 0.99)..statList[sliderController.index].stat.label
		end
	end)
	controls.SliderValue = new("LabelControl", { "TOPLEFT", controls.Slider, "TOPRIGHT" }, {20, 0, 0, 16}, "^7Disabled")
	controls.Slider.tooltip.realDraw = controls.Slider.tooltip.Draw
	controls.Slider.tooltip.Draw = function(self, x, y, width, height, viewPort)
		local sliderOffsetX = round(184 * (1 - controls.Slider.val))
		local tooltipWidth, tooltipHeight = self:GetSize()
		if main.screenW >= 1338 - sliderOffsetX then
			return controls[stat.label.."Slider"].tooltip.realDraw(self, x - 8 - sliderOffsetX, y - 4 - tooltipHeight, width, height, viewPort)
		end
		return controls.Slider.tooltip.realDraw(self, x, y, width, height, viewPort)
	end
	sliderController.SliderLabel = controls.SliderLabel
	sliderController.Slider = controls.Slider
	sliderController.SliderValue = controls.SliderValue

	for _, statBase in ipairs(self.statSortSelectionList) do
		for _, stat in ipairs(statList) do
			if stat.stat.stat == statBase.stat then
				stat.stat.weightMult = statBase.weightMult
				stat.label = s_format("%.2f :  ", statBase.weightMult)..statBase.label
				if statList[sliderController.index].stat.stat == statBase.stat then
					controls.Slider:SetVal(statBase.weightMult == 1 and 1 or statBase.weightMult - 0.01)
				end
			end
		end
	end

	controls.finalise = new("ButtonControl", { "BOTTOM", nil, "BOTTOM" }, {-90, -10, 80, 20}, "Save", function()
		main:ClosePopup()

		-- used in ItemsTab to save to xml under TradeSearchWeights node
		local statSortSelectionList = {}
		for stat, statTable in pairs(statList) do
			if statTable.stat.weightMult > 0 then
				t_insert(statSortSelectionList, statTable.stat)
			end
		end
		if (#statSortSelectionList) > 0 then
			--THIS SHOULD REALLY GIVE A WARNING NOT JUST USE PREVIOUS
			self.statSortSelectionList = statSortSelectionList
		end
		for row_idx in pairs(self.resultTbl) do
			self:UpdateControlsWithItems(row_idx)
		end
    end)
	controls.cancel = new("ButtonControl", { "BOTTOM", nil, "BOTTOM" }, { 0, -10, 80, 20 }, "Cancel", function()
		if previousSelectionList and #previousSelectionList > 0 then
			self.statSortSelectionList = copyTable(previousSelectionList, true)
		end
		main:ClosePopup()
	end)
	controls.reset = new("ButtonControl", { "BOTTOM", nil, "BOTTOM" }, { 90, -10, 80, 20 }, "Reset", function()
		local previousSelection = { }
		if isSameAsDefaultList(self.statSortSelectionList) then
			previousSelection = copyTable(previousSelectionList, true)
		else
			previousSelection = copyTable(self.statSortSelectionList, true) -- this is so we can revert if user hits Cancel after Reset
		end
		self.statSortSelectionList = { }
		initStatSortSelectionList(self.statSortSelectionList)
		main:ClosePopup()
		self:SetStatWeights(previousSelection)
	end)
	main:OpenPopup(420, popupHeight, "Stat Weight Multipliers", controls)
end

-- Method to update the Currency Conversion button label
function TradeQueryClass:SetCurrencyConversionButton()
	local currencyLabel = "Update Currency Conversion Rates"
	self.pbFileTimestampDiff[self.controls.league.selIndex] = nil
	if self.pbLeague == nil then
		return
	end
	if true then -- tbd once poe ninja has data for poe2
		self.controls.updateCurrencyConversion.label = "Currency Rates are not available"
		self.controls.updateCurrencyConversion.enabled = false
		self.controls.updateCurrencyConversion.tooltipFunc = function(tooltip)
			tooltip:Clear()
			tooltip:AddLine(16, "Currency Conversion rates are pulled from PoE Ninja")
		end
		return
	end
	local values_file = io.open("../"..self.pbLeague.."_currency_values.json", "r")
	if values_file then
		local lines = values_file:read "*a"
		values_file:close()
		self.pbCurrencyConversion[self.pbLeague] = dkjson.decode(lines)
		self.lastCurrencyFileTime[self.controls.league.selIndex]  = self.pbCurrencyConversion[self.pbLeague]["updateTime"]
		self.pbFileTimestampDiff[self.controls.league.selIndex] = get_time() - self.lastCurrencyFileTime[self.controls.league.selIndex]
		if self.pbFileTimestampDiff[self.controls.league.selIndex] < 3600 then
			-- Less than 1 hour (60 * 60 = 3600)
			currencyLabel = "Currency Rates are very recent"
		elseif self.pbFileTimestampDiff[self.controls.league.selIndex] < (24 * 3600) then
			-- Less than 1 day
			currencyLabel = "Currency Rates are recent"
		end
	else
		currencyLabel = "Get Currency Conversion Rates"
	end
	self.controls.updateCurrencyConversion.label = currencyLabel
	self.controls.updateCurrencyConversion.enabled = function()
		return self.pbFileTimestampDiff[self.controls.league.selIndex] == nil or self.pbFileTimestampDiff[self.controls.league.selIndex] >= 3600
	end
	self.controls.updateCurrencyConversion.tooltipFunc = function(tooltip)
		tooltip:Clear()
		if self.lastCurrencyFileTime[self.controls.league.selIndex] ~= nil then
			self.pbFileTimestampDiff[self.controls.league.selIndex] = get_time() - self.lastCurrencyFileTime[self.controls.league.selIndex]
		end
		if self.pbFileTimestampDiff[self.controls.league.selIndex] == nil or self.pbFileTimestampDiff[self.controls.league.selIndex] >= 3600 then
			tooltip:AddLine(16, "Currency Conversion rates are pulled from PoE Ninja")
			tooltip:AddLine(16, "Updates are limited to once per hour and not necessary more than once per day")
		elseif self.pbFileTimestampDiff[self.controls.league.selIndex] ~= nil and self.pbFileTimestampDiff[self.controls.league.selIndex] < 3600 then
			tooltip:AddLine(16, "Conversion Rates are less than an hour old (" .. tostring(self.pbFileTimestampDiff[self.controls.league.selIndex]) .. " seconds old)")
		end
	end
end

-- Method to set the notice message in upper right of PoB Trader pane
function TradeQueryClass:SetNotice(notice_control, msg)
	if msg:find("No Matching Results") then
		msg = colorCodes.WARNING .. msg
	elseif msg:find("Error") then
		msg = colorCodes.NEGATIVE .. msg
	end
	notice_control.label = msg
end

---Zwraca true, jeśli item przechodzi filtr typu oferty (zgodnie z TRADER_SORT_BY_STATS_SPEC.md).
---@param item table element z resultTbl (ma .isInstantBuyout, .whisper, .accountStatus)
---@param listingType string "any" | "instant_buyout" | "whisper" | "whisper_online"
---@return boolean
function TradeQueryClass:passesListingTypeFilter(item, listingType)
	if not listingType or listingType == "any" then return true end
	if listingType == "instant_buyout" then return item.isInstantBuyout == true end
	if listingType == "whisper" then return item.whisper and item.whisper ~= "" end
	if listingType == "whisper_online" then
		return (item.whisper and item.whisper ~= "") and (item.accountStatus or "") == "ONLINE"
	end
	return true
end

-- Returns full calculator output for one result (no ReduceOutput); used for stat pool and StatClick sort
function TradeQueryClass:GetResultFullOutput(row_idx, result_index)
	local result = self.resultTbl[row_idx] and self.resultTbl[row_idx][result_index]
	if not result then return nil end
	local calcFunc, baseOutput = self.itemsTab.build.calcsTab:GetMiscCalculator()
	if not calcFunc then return nil end
	local slotName = self.slotTables[row_idx].nodeId and "Jewel " .. tostring(self.slotTables[row_idx].nodeId) or self.slotTables[row_idx].slotName
	if slotName == "Megalomaniac" then
		local addedNodes = {}
		for nodeName in (result.item_string.."\r\n"):gmatch("Allocates (.-)\r?\n") do
			local node = self.itemsTab.build.spec.tree.notableMap[nodeName:lower()]
			if node and node.recipes ~= nil then
				addedNodes[node] = true
			end
		end
		return calcFunc({ addNodes = addedNodes })
	end
	local item = new("Item", result.item_string)
	if not self.enchantInSort then
		item.enchantModLines = { }
		item:BuildAndParseRaw()
	end
	return calcFunc({ repSlotName = slotName, repItem = item })
end

-- Refreshes stat pool (left column) from ALL results in current search (deduplicated)
function TradeQueryClass:RefreshStatPool()
	wipeTable(self.statPoolListData)
	local row = self.sortPanelSelectedRowIdx
	if not row or not self.resultTbl[row] or not self.sortedResultTbl[row] then
		return
	end
	local build = self.itemsTab.build
	if not build or not build.displayStats then
		return
	end
	local allStats = {}
	for result_index = 1, #self.resultTbl[row] do
		local output = self:GetResultFullOutput(row, result_index)
		if output then
			for _, ds in ipairs(build.displayStats) do
				local v = output[ds.stat]
				if v ~= nil and (type(v) == "number" or type(v) == "string") then
					if not (ds.condFunc and not ds.condFunc(v, output)) then
						if not allStats[ds.stat] then
							allStats[ds.stat] = { stat = ds.stat, label = ds.label or ds.stat }
						end
					end
				end
			end
		end
	end
	local seenStat = {}
	for _, ds in ipairs(build.displayStats) do
		if allStats[ds.stat] and not seenStat[ds.stat] then
			seenStat[ds.stat] = true
			t_insert(self.statPoolListData, allStats[ds.stat])
		end
	end
end

-- Method to reduce the full output to only the values that were 'weighted'
function TradeQueryClass:ReduceOutput(output)
	local smallOutput = {}
	for _, statTable in ipairs(self.statSortSelectionList) do
		smallOutput[statTable.stat] = output[statTable.stat]
	end
	return smallOutput
end

-- Method to evaluate a result by getting it's output and weight
function TradeQueryClass:GetResultEvaluation(row_idx, result_index)
	local result = self.resultTbl[row_idx][result_index]
	local calcFunc, baseOutput = self.itemsTab.build.calcsTab:GetMiscCalculator()
	local onlyWeightedBaseOutput = self:ReduceOutput(baseOutput)
	if not self.onlyWeightedBaseOutput[row_idx] then
		self.onlyWeightedBaseOutput[row_idx] = { }
	end
	if not self.lastComparedWeightList[row_idx] then
		self.lastComparedWeightList[row_idx] = { }
	end
	-- If the interesting stats are the same (the build hasn't changed) and result has already been evaluated, then just return that
	if result.evaluation and tableDeepEquals(onlyWeightedBaseOutput, self.onlyWeightedBaseOutput[row_idx][result_index]) and tableDeepEquals(self.statSortSelectionList, self.lastComparedWeightList[row_idx][result_index]) then
		return result.evaluation
	end
	self.fullBaseOutput = baseOutput
	self.onlyWeightedBaseOutput[row_idx][result_index] = onlyWeightedBaseOutput
	self.lastComparedWeightList[row_idx][result_index] = self.statSortSelectionList
	
	local slotName = self.slotTables[row_idx].nodeId and "Jewel " .. tostring(self.slotTables[row_idx].nodeId) or self.slotTables[row_idx].slotName
	if slotName == "Megalomaniac" then
		local addedNodes = {}
		for nodeName in (result.item_string.."\r\n"):gmatch("Allocates (.-)\r?\n") do
			local node = self.itemsTab.build.spec.tree.notableMap[nodeName:lower()]
			if node and node.recipes ~= nil then
				addedNodes[node] = true
			end
		end
		
		local output = self:ReduceOutput(calcFunc({ addNodes = addedNodes }))
		local weight = self.tradeQueryGenerator.WeightedRatioOutputs(baseOutput, output, self.statSortSelectionList)
		result.evaluation = {{ output = output, weight = weight }}
	else
		local item = new("Item", result.item_string)
		if not self.enchantInSort then -- Calc item DPS without anoint or enchant as these can generally be added after.
			item.enchantModLines = { }
			item:BuildAndParseRaw()
		end
		local output = self:ReduceOutput(calcFunc({ repSlotName = slotName, repItem = item }))
		local weight = self.tradeQueryGenerator.WeightedRatioOutputs(baseOutput, output, self.statSortSelectionList)
		result.evaluation = {{ output = output, weight = weight }}
	end
	return result.evaluation
end

-- Schedules UpdateControlsWithItems for next frame and shows "Sorting, please wait..." overlay
function TradeQueryClass:RunDeferredSort(row_idx, overrideMode)
	if not row_idx or not self.resultTbl[row_idx] then return end
	self.sortingInProgress = true
	self:SetNotice(self.controls.pbNotice, "Sorting, please wait...")
	local tab = self
	main.onFrameFuncs["TraderSorting"] = function()
		tab:UpdateControlsWithItems(row_idx, overrideMode)
		tab.sortingInProgress = false
		main.onFrameFuncs["TraderSorting"] = nil
	end
end

-- Method to update controls after a search is completed
-- overrideMode: optional, e.g. self.sortModes.StatClick when RE-SEARCH is used
function TradeQueryClass:UpdateControlsWithItems(row_idx, overrideMode)
	local sortMode = overrideMode or self.itemSortSelectionList[self.pbItemSortSelectionIndex]
	local sortedItems, errMsg = self:SortFetchResults(row_idx, sortMode)
	if errMsg == "MissingConversionRates" then
		self:SetNotice(self.controls.pbNotice, "^4Price sorting is not available, falling back to Stat Value sort.")
		sortedItems, errMsg = self:SortFetchResults(row_idx, self.sortModes.StatValue)
	end
	if errMsg then
		self:SetNotice(self.controls.pbNotice, "Error: " .. errMsg)
		return
	elseif self.filterNoMatchMessage then
		self:SetNotice(self.controls.pbNotice, "^4No items match filter criteria. Showing all items sorted by selected stats.")
	else
		self:SetNotice(self.controls.pbNotice, "")
	end

	if not sortedItems or #sortedItems == 0 then
		self:SetNotice(self.controls.pbNotice, "^4No items match the selected filter.")
		self.resultTbl[row_idx] = nil
		self.sortedResultTbl[row_idx] = nil
		self.itemIndexTbl[row_idx] = nil
		self.totalPrice[row_idx] = nil
		self.controls.fullPrice.label = "Total Price: " .. self:GetTotalPriceString()
		return
	end

	self.sortedResultTbl[row_idx] = sortedItems
	local pb_index = self.sortedResultTbl[row_idx][1].index
	self.itemIndexTbl[row_idx] = pb_index
	self.controls["priceButton".. row_idx].tooltipText = "Sorted by " .. self.itemSortSelectionList[self.pbItemSortSelectionIndex]
	self.totalPrice[row_idx] = {
		currency = self.resultTbl[row_idx][pb_index].currency,
		amount = self.resultTbl[row_idx][pb_index].amount,
	}
	self.controls.fullPrice.label = "Total Price: " .. self:GetTotalPriceString()
	local dropdownLabels = {}
	for result_index = 1, #self.resultTbl[row_idx] do
		local pb_index = self.sortedResultTbl[row_idx][result_index].index
		local item = new("Item", self.resultTbl[row_idx][pb_index].item_string)
		table.insert(dropdownLabels, colorCodes[item.rarity]..item.name)
	end
	self.controls["resultDropdown".. row_idx].selIndex = 1
	self.controls["resultDropdown".. row_idx]:SetList(dropdownLabels)
	if not self.sortPanelSelectedRowIdx or not self.resultTbl[self.sortPanelSelectedRowIdx] then
		self.sortPanelSelectedRowIdx = row_idx
		self.sortPanelSelectedItemIdx = pb_index
	end
	self:RefreshStatPool()
	if self.controls.sortByList and self.clickSortStats and #self.clickSortStats >= 1 then
		local sl = self.controls.sortByList
		if not sl.selIndex or sl.selIndex > #self.clickSortStats then
			-- #region agent log
			do
				local f = io.open("c:\\Users\\xpret\\AppData\\Roaming\\Path of Building Community (PoE2)\\.cursor\\debug.log", "a")
				if f then
					f:write(string.format('{"location":"TradeQuery.lua:UpdateControlsWithItems","message":"Auto SelectIndex(1)","data":{"nStats":%s},"timestamp":%d,"sessionId":"debug-session","hypothesisId":"H1"}\n', #self.clickSortStats, (os.time() or 0) * 1000))
					f:close()
				end
			end
			-- #endregion
			sl:SelectIndex(1)
		end
	end
end

-- Method to set the current result return in the pane based of an index
function TradeQueryClass:SetFetchResultReturn(row_idx, index)
	if self.resultTbl[row_idx] and self.resultTbl[row_idx][index] then
		self.totalPrice[row_idx] = {
			currency = self.resultTbl[row_idx][index].currency,
			amount = self.resultTbl[row_idx][index].amount,
		}
		self.controls.fullPrice.label = "Total Price: " .. self:GetTotalPriceString()
	end
end

-- Method to sort the fetched results
function TradeQueryClass:SortFetchResults(row_idx, mode)
	local function getResultWeight(result_index)
		local sum = 0
		for _, eval in ipairs(self:GetResultEvaluation(row_idx, result_index)) do
			sum = sum + eval.weight
		end
		return sum
	end
	local function getPriceTable()
		local out = {}
		local pricedItems = self:addChaosEquivalentPriceToItems(self.resultTbl[row_idx])
		if pricedItems == nil then
			return nil
		end
		for index, tbl in pairs(pricedItems) do
			local chaosAmount = self:ConvertCurrencyToChaos(tbl.currency, tbl.amount)
			if chaosAmount > 0 then
				out[index] = chaosAmount
			end
		end
		return out
	end
	local newTbl = {}
	if mode == self.sortModes.Weight then
		for index, _ in pairs(self.resultTbl[row_idx]) do
			t_insert(newTbl, { outputAttr = index, index = index })
		end
		return newTbl
	elseif mode == self.sortModes.StatValue  then
		for result_index = 1, #self.resultTbl[row_idx] do
			t_insert(newTbl, { outputAttr = getResultWeight(result_index), index = result_index })
		end
		table.sort(newTbl, function(a,b) return a.outputAttr > b.outputAttr end)
	elseif mode == self.sortModes.StatValuePrice then
		local priceTable = getPriceTable()
		if priceTable == nil then
			return nil, "MissingConversionRates"
		end
		for result_index = 1, #self.resultTbl[row_idx] do
			t_insert(newTbl, { outputAttr = getResultWeight(result_index) / priceTable[result_index], index = result_index })
		end
		table.sort(newTbl, function(a,b) return a.outputAttr > b.outputAttr end)
	elseif mode == self.sortModes.Price then
		local priceTable = getPriceTable()
		if priceTable == nil then
			return nil, "MissingConversionRates"
		end
		for result_index, price in pairs(priceTable) do
			t_insert(newTbl, { outputAttr = price, index = result_index })
		end
		table.sort(newTbl, function(a,b) return a.outputAttr < b.outputAttr end)
	elseif mode == self.sortModes.StatClick then
		if not self.clickSortStats or #self.clickSortStats == 0 then
			for result_index = 1, #self.resultTbl[row_idx] do
				t_insert(newTbl, { outputAttr = getResultWeight(result_index), index = result_index })
			end
			table.sort(newTbl, function(a,b) return a.outputAttr > b.outputAttr end)
		else
			for result_index = 1, #self.resultTbl[row_idx] do
				t_insert(newTbl, { result_index = result_index, index = result_index })
			end
			-- Filter by minVal/maxVal (inclusive)
			local filtered = {}
			local allFiltered = {}
			for _, entry in ipairs(newTbl) do
				local out = self:GetResultFullOutput(row_idx, entry.result_index)
				if not out then
					t_insert(filtered, entry)
					t_insert(allFiltered, entry)
				else
					local pass = true
					for _, statEntry in ipairs(self.clickSortStats) do
						local v = out[statEntry.stat]
						local n = tonumber(v)
						if statEntry.minVal and statEntry.minVal ~= "" then
							local minN = tonumber(statEntry.minVal)
							if minN and n then
								if n < minN then pass = false break end
							elseif minN and not n then
								pass = false break
							end
						end
						if statEntry.maxVal and statEntry.maxVal ~= "" and pass then
							local maxN = tonumber(statEntry.maxVal)
							if maxN and n then
								if n > maxN then pass = false break end
							elseif maxN and not n then
								pass = false break
							end
						end
					end
					if pass then
						t_insert(filtered, entry)
					end
					t_insert(allFiltered, entry)
				end
			end
			if #filtered == 0 and #allFiltered > 0 then
				newTbl = allFiltered
				self.filterNoMatchMessage = true
			else
				self.filterNoMatchMessage = false
				newTbl = filtered
			end
			table.sort(newTbl, function(a, b)
				local outA = self:GetResultFullOutput(row_idx, a.result_index)
				local outB = self:GetResultFullOutput(row_idx, b.result_index)
				if not outA or not outB then return (a.result_index or 0) < (b.result_index or 0) end
				for _, entry in ipairs(self.clickSortStats) do
					local stat = entry.stat
					local vA = outA[stat]
					local vB = outB[stat]
					if vA ~= vB then
						local na, nb = tonumber(vA), tonumber(vB)
						if na and nb then
							return na > nb
						end
						return tostring(vA or "") > tostring(vB or "")
					end
				end
				return false
			end)
		end
	else
		return nil, "InvalidSort"
	end
	return newTbl
end

--- Convert item prices to chaos equivalent using poeninja data, returns nil if fails to convert any
function TradeQueryClass:addChaosEquivalentPriceToItems(items)
	local outputItems = copyTable(items)
	for _, item in ipairs(outputItems) do
		local chaosAmount = self:ConvertCurrencyToChaos(item.currency, item.amount)
		if chaosAmount == nil then
			return nil
		end
		item.chaosEquivalent = chaosAmount
	end
	return outputItems
end

-- Method to generate pane elements for each item slot
function TradeQueryClass:PriceItemRowDisplay(row_idx, top_pane_alignment_ref, row_vertical_padding, row_height)
	local controls = self.controls
	local slotTbl = self.slotTables[row_idx]
	local activeSlotRef = slotTbl.nodeId and self.itemsTab.activeItemSet[slotTbl.nodeId] or self.itemsTab.activeItemSet[slotTbl.slotName]
	local activeSlot = slotTbl.nodeId and self.itemsTab.sockets[slotTbl.nodeId] or slotTbl.slotName and self.itemsTab.slots[slotTbl.slotName]
	local nameColor = slotTbl.unique and colorCodes.UNIQUE or "^7"
	controls["name"..row_idx] = new("LabelControl", top_pane_alignment_ref, {0, row_idx*(row_height + row_vertical_padding), 100, row_height - 4}, nameColor..slotTbl.slotName)
	controls["bestButton"..row_idx] = new("ButtonControl", { "LEFT", controls["name"..row_idx], "LEFT"}, {100 + 8, 0, 80, row_height}, "Find best", function()
		self.tradeQueryGenerator:RequestQuery(activeSlot, { slotTbl = slotTbl, controls = controls, row_idx = row_idx }, self.statSortSelectionList, function(context, query, errMsg)
			if errMsg then
				self:SetNotice(context.controls.pbNotice, colorCodes.NEGATIVE .. errMsg)
				return
			else
				self:SetNotice(context.controls.pbNotice, "")
			end
			if main.POESESSID == nil or main.POESESSID == "" then
				local url = self.tradeQueryRequests:buildUrl(self.hostName .. "trade2/search", self.pbRealm, self.pbLeague)
				url = url .. "?q=" .. urlEncode(query)
				controls["uri"..context.row_idx]:SetText(url, true)
				return
			end
			context.controls["priceButton"..context.row_idx].label = "Searching..."
			self.tradeQueryRequests:SearchWithQueryWeightAdjusted(self.pbRealm, self.pbLeague, query,
				function(items, errMsg)
					if errMsg then
						self:SetNotice(context.controls.pbNotice, colorCodes.NEGATIVE .. errMsg)
						context.controls["priceButton"..context.row_idx].label =  "Price Item"
						return
					else
						self:SetNotice(context.controls.pbNotice, "")
					end
					local listingType = context.listingType or "any"
					if listingType ~= "any" then
						local filtered = {}
						for _, item in ipairs(items) do
							if self:passesListingTypeFilter(item, listingType) then
								t_insert(filtered, item)
							end
						end
						items = filtered
					end
					self.resultTbl[context.row_idx] = items
					self:UpdateControlsWithItems(context.row_idx)
					context.controls["priceButton"..context.row_idx].label =  "Price Item"
				end,
				{
					callbackQueryId = function(queryId, realm, league)
						self.lastSearchId = queryId
						realm = realm or self.pbRealm
						league = league or self.pbLeague
						local url = self.tradeQueryRequests:buildUrl(
							self.hostName .. "trade2/search", realm, league, queryId)
						controls["uri"..context.row_idx]:SetText(url, true)
					end
				}
			)
		end)
	end)
	controls["bestButton"..row_idx].shown = function() return not self.resultTbl[row_idx] end
	controls["bestButton"..row_idx].enabled = function() return self.pbLeague end
	controls["bestButton"..row_idx].tooltipText = "Creates a weighted search to find the highest Stat Value items for this slot."
	local pbURL
	controls["uri"..row_idx] = new("EditControl", { "TOPLEFT", controls["bestButton"..row_idx], "TOPRIGHT"}, {8, 0, 514, row_height}, nil, nil, "^%C\t\n", nil, function(buf)
		local subpath = buf:match(self.hostName .. "trade2/search/(.+)$") or ""
		local paths = {}
		for path in subpath:gmatch("[^/]+") do
			table.insert(paths, path)
		end
		controls["uri"..row_idx].validURL = #paths == 2 or #paths == 3
		if controls["uri"..row_idx].validURL then
			pbURL = buf
		elseif buf == "" then
			pbURL = ""
		end
		if not activeSlotRef and slotTbl.nodeId then
			self.itemsTab.activeItemSet[slotTbl.nodeId] = { pbURL = "" }
			activeSlotRef = self.itemsTab.activeItemSet[slotTbl.nodeId]
		end
	end, nil)
	controls["uri"..row_idx]:SetPlaceholder("Paste trade URL here...")
	if pbURL and pbURL ~= "" then
		controls["uri"..row_idx]:SetText(pbURL, true)
	end
	controls["uri"..row_idx].tooltipFunc = function(tooltip)
		tooltip:Clear()
		if controls["uri"..row_idx].buf:find('^'..self.hostName..'trade2/search/') ~= nil then
			tooltip:AddLine(16, "Control + click to open in web-browser")
		end
	end
	controls["priceButton"..row_idx] = new("ButtonControl", { "TOPLEFT", controls["uri"..row_idx], "TOPRIGHT"}, {8, 0, 100, row_height}, "Price Item",
		function()
			controls["priceButton"..row_idx].label = "Searching..."
			self.tradeQueryRequests:SearchWithURL(controls["uri"..row_idx].buf, function(items, errMsg)
				if errMsg then
					self:SetNotice(controls.pbNotice, "Error: " .. errMsg)
				else
					self:SetNotice(controls.pbNotice, "")
					self.resultTbl[row_idx] = items
					self:UpdateControlsWithItems(row_idx)
				end
				controls["priceButton"..row_idx].label = "Price Item"
			end, 			{
				callbackQueryId = function(queryId, realm, league)
					self.lastSearchId = queryId
					realm = realm or self.pbRealm
					league = league or self.pbLeague
					local url = self.tradeQueryRequests:buildUrl(
						self.hostName .. "trade2/search", realm, league, queryId)
					controls["uri"..row_idx]:SetText(url, true)
				end
			})
		end)
	controls["priceButton"..row_idx].enabled = function()
		local poesessidAvailable = main.POESESSID and main.POESESSID ~= ""
		local validURL = controls["uri"..row_idx].validURL
		local isSearching = controls["priceButton"..row_idx].label == "Searching..."
		return poesessidAvailable and validURL and not isSearching
	end
	controls["priceButton"..row_idx].tooltipFunc = function(tooltip)
		tooltip:Clear()
		if not main.POESESSID or main.POESESSID == "" then
			tooltip:AddLine(16, "You must set your POESESSID to use search feature")
		elseif not controls["uri"..row_idx].validURL then
			tooltip:AddLine(16, "Enter a valid trade URL")
		end
	end
	local clampItemIndex = function(index)
		return m_min(m_max(index or 1, 1), self.sortedResultTbl[row_idx] and #self.sortedResultTbl[row_idx] or 1)
	end
	controls["changeButton"..row_idx] = new("ButtonControl", { "LEFT", controls["name"..row_idx], "LEFT"}, {100 + 8, 0, 80, row_height}, "<< Search", function()
		self.itemIndexTbl[row_idx] = nil
		self.sortedResultTbl[row_idx] = nil
		self.resultTbl[row_idx] = nil
		self.totalPrice[row_idx] = nil
		self.controls.fullPrice.label = "Total Price: " .. self:GetTotalPriceString()
	end)
	controls["changeButton"..row_idx].shown = function() return self.resultTbl[row_idx] end
	-- Traffic light: status indicator before result row (online/afk/offline)
	controls["statusIndicator"..row_idx] = new("LabelControl", {"LEFT", controls["changeButton"..row_idx], "RIGHT"}, {4, 0, 12, row_height}, "")
	controls["statusIndicator"..row_idx].queryTab = self
	controls["statusIndicator"..row_idx].row_idx = row_idx
	controls["statusIndicator"..row_idx].Draw = function(indicator, viewPort)
		if not indicator:IsShown() then return end
		local tab = indicator.queryTab
		local idx = indicator.row_idx
		local resultIdx = tab.itemIndexTbl[idx]
		if not tab.resultTbl[idx] or not resultIdx then return end
		local item = tab.resultTbl[idx][resultIdx]
		local status = (item.accountStatus or "OFFLINE"):upper()
		local r, g, b = 0.5, 0.5, 0.5
		if status == "ONLINE" then
			r, g, b = 0.1, 0.9, 0.1
		elseif status == "AFK" then
			r, g, b = 1.0, 0.6, 0.0
		end
		local ix, iy = indicator:GetPos()
		local _, iheight = indicator:GetSize()
		local cx = ix + 6
		local cy = iy + iheight / 2
		local radius = 3.5
		SetDrawColor(r, g, b, 1)
		DrawImage(nil, cx - radius, cy - radius, radius * 2, radius * 2)
		SetDrawColor(1, 1, 1)
	end
	controls["statusIndicator"..row_idx].width = 12
	controls["statusIndicator"..row_idx].shown = function() return self.resultTbl[row_idx] end
	local dropdownLabels = {}
	for _, sortedResult in ipairs(self.sortedResultTbl[row_idx] or {}) do
		local item = new("Item", self.resultTbl[row_idx][sortedResult.index].item_string)
		table.insert(dropdownLabels, colorCodes[item.rarity]..item.name)
	end
	controls["resultDropdown"..row_idx] = new("DropDownControl", { "TOPLEFT", controls["statusIndicator"..row_idx], "TOPRIGHT"}, {4, 0, 325, row_height}, dropdownLabels, function(index)
		self.itemIndexTbl[row_idx] = self.sortedResultTbl[row_idx][index].index
		self:SetFetchResultReturn(row_idx, self.itemIndexTbl[row_idx])
		self.sortPanelSelectedRowIdx = row_idx
		self.sortPanelSelectedItemIdx = self.sortedResultTbl[row_idx][index].index
		self:RefreshStatPool()
	end)
	local function getItemDisplayName(result)
		if not result then return "" end
		local name = ""
		local ok, itemObj = pcall(function() return new("Item", result.item_string) end)
		if ok and itemObj and itemObj.title and itemObj.baseName and itemObj.title ~= itemObj.baseName then
			name = itemObj.title .. " " .. itemObj.baseName:gsub(" %(.+%)", "")
		end
		if name == "" and result.fullItemName and result.fullItemName ~= "" then
			name = result.fullItemName
		elseif name == "" and result.whisper and result.whisper ~= "" then
			name = result.whisper:match("your (.+) listed") or ""
		end
		if name == "" and ok and itemObj then
			if itemObj.title and itemObj.baseName then
				name = itemObj.title .. " " .. itemObj.baseName:gsub(" %(.+%)", "")
			elseif itemObj.name then
				name = itemObj.name
			end
		end
		-- Trade site expects "Cataclysm Core Varnished Crossbow", not "Cataclysm Core, Sturdy Crossbow"
		return (name or ""):gsub(",%s*", " "):gsub("^%s*(.-)%s*$", "%1")
	end
	-- Build a trade search URL with item name + optional exact price filter
	local function buildItemNameSearchURL(itemName, itemAmount, itemCurrency)
		if not itemName or itemName == "" then return nil end
		local escapedName = itemName:gsub('"', '\\"')
		local tradeFilters = ""
		if itemAmount and itemCurrency and itemCurrency ~= "" then
			tradeFilters = '"trade_filters":{"filters":{"sale_type":{"option":"priced"},"price":{"option":"' .. itemCurrency .. '","min":' .. tostring(itemAmount) .. ',"max":' .. tostring(itemAmount) .. '}}}'
		end
		local filtersBlock = tradeFilters ~= "" and tradeFilters or ""
		local query = '{"query":{"term":"' .. escapedName .. '","status":{"option":"any"},"filters":{' .. filtersBlock .. '},"stats":[{"type":"and","filters":[]}]},"sort":{"price":"asc"}}'
		local base = self.tradeQueryRequests:buildUrl(self.hostName .. "trade2/search", self.pbRealm, self.pbLeague)
		return base .. "?q=" .. urlEncode(query)
	end
	local function addCompareTooltip(tooltip, result_index, dbMode)
		local result = self.resultTbl[row_idx][result_index]
		local item = new("Item", result.item_string)
		self.itemsTab:AddItemTooltip(tooltip, item, slotTbl, dbMode)
		if main.slotOnlyTooltips and slotTbl.slotName == "Megalomaniac" then
			local evaluation = self.resultTbl[row_idx][result_index].evaluation
			self.itemsTab.build:AddStatComparesToTooltip(tooltip, self.onlyWeightedBaseOutput[row_idx][result_index], evaluation[1].output, "^7Equipping this item will give you:")
		end
	end
	controls["resultDropdown"..row_idx].tooltipFunc = function(tooltip, dropdown_mode, dropdown_index, dropdown_display_string)
		tooltip:Clear()
		if not (self.sortedResultTbl[row_idx] and self.sortedResultTbl[row_idx][dropdown_index]) then
			tooltip:AddLine(14, "^7If you don't see the item preview on hover, click the item.")
			return
		end
		local result_index = self.sortedResultTbl[row_idx][dropdown_index].index
		local result = self.resultTbl[row_idx][result_index]
		addCompareTooltip(tooltip, result_index)
		tooltip:AddSeparator(10)
		tooltip:AddLine(16, string.format("^7Price: %s %s", result.amount, result.currency))
		tooltip:AddLine(12, "^8If you don't see the item preview on hover, click the item.")
	end
	controls["importButton"..row_idx] = new("ButtonControl", { "TOPLEFT", controls["resultDropdown"..row_idx], "TOPRIGHT"}, {8, 0, 100, row_height}, "Import Item", function()
		self.itemsTab:CreateDisplayItemFromRaw(self.resultTbl[row_idx][self.itemIndexTbl[row_idx]].item_string)
		local item = self.itemsTab.displayItem
		-- pass "true" to not auto equip it as we will have our own logic
		self.itemsTab:AddDisplayItem(true)
		-- Autoequip it
		local slot = slotTbl.nodeId and self.itemsTab.sockets[slotTbl.nodeId] or self.itemsTab.slots[slotTbl.slotName]
		if slot and slotTbl.slotName == slot.label and slot:IsShown() and self.itemsTab:IsItemValidForSlot(item, slot.slotName) then
			slot:SetSelItemId(item.id)
			self.itemsTab:PopulateSlots()
			self.itemsTab:AddUndoState()
			self.itemsTab.build.buildFlag = true
		end
	end)
	controls["importButton"..row_idx].tooltipFunc = function(tooltip)
		tooltip:Clear()
		local selected_result_index = self.itemIndexTbl[row_idx]
		if selected_result_index then
			addCompareTooltip(tooltip, selected_result_index, true)
		end
	end
	controls["importButton"..row_idx].enabled = function()
		return self.itemIndexTbl[row_idx] and self.resultTbl[row_idx][self.itemIndexTbl[row_idx]].item_string ~= nil
	end
	-- Dynamic Action Button: Hideout (gold, opens browser) or Whisper (copies to clipboard)
	controls["actionButton"..row_idx] = new("ButtonControl", { "TOPLEFT", controls["importButton"..row_idx], "TOPRIGHT"}, {8, 0, 70, row_height}, function()
		local item = self.resultTbl[row_idx] and self.resultTbl[row_idx][self.itemIndexTbl[row_idx]]
		if not item then return "^7Whisper:" end
		if item.isInstantBuyout then
			local statusColor = { ONLINE = colorCodes.POSITIVE, AFK = colorCodes.WARNING, OFFLINE = "^x808080" }
			local dot = (statusColor[item.accountStatus] or "") .. "o ^xFFCC00"
			local tp = self.totalPrice[row_idx]
			return dot .. ((tp and ("Hideout: " .. tp.amount .. " " .. tp.currency)) or "Hideout:")
		end
		local statusColor = { ONLINE = colorCodes.POSITIVE, AFK = colorCodes.WARNING, OFFLINE = "^x808080" }
		local dot = (statusColor[item.accountStatus] or "") .. "o ^7"
		local tp = self.totalPrice[row_idx]
		return dot .. ((tp and ("Whisper: " .. tp.amount .. " " .. tp.currency)) or "Whisper:")
	end, function()
		local item = self.resultTbl[row_idx] and self.resultTbl[row_idx][self.itemIndexTbl[row_idx]]
		if not item then return end
		local itemName = getItemDisplayName(item)
		if item.isInstantBuyout then
			-- Build URL with item name + exact price filter
			local nameUrl = buildItemNameSearchURL(itemName, item.amount, item.currency)
			if nameUrl then
				OpenURL(nameUrl)
			else
				local url = controls["uri"..row_idx].buf
				if url and url ~= "" then OpenURL(url) end
			end
			if itemName ~= "" then Copy(itemName) end
		else
			Copy(item.whisper or "")
		end
	end)
	controls["actionButton"..row_idx].queryTab = self
	controls["actionButton"..row_idx].row_idx = row_idx
	controls["actionButton"..row_idx].width = function(ctrl)
		local tab = ctrl.queryTab
		local r = ctrl.row_idx
		local item = tab.resultTbl[r] and tab.resultTbl[r][tab.itemIndexTbl[r]]
		local lab = "o Whisper:"
		if item and item.isInstantBuyout then
			lab = tab.totalPrice[r] and ("o Hideout: " .. tab.totalPrice[r].amount .. " " .. tab.totalPrice[r].currency) or "o Hideout:"
		elseif tab.totalPrice[r] then
			lab = "o Whisper: " .. tab.totalPrice[r].amount .. " " .. tab.totalPrice[r].currency
		end
		return m_max(70, DrawStringWidth(16, "VAR", lab) + 16)
	end
	controls["actionButton"..row_idx].enabled = function()
		if not self.itemIndexTbl[row_idx] or not self.resultTbl[row_idx] then return false end
		local item = self.resultTbl[row_idx][self.itemIndexTbl[row_idx]]
		if not item then return false end
		if item.isInstantBuyout then
			-- Always enabled for IB: we build the URL from the item name
			return true
		end
		return item.whisper and item.whisper ~= ""
	end
	controls["actionButton"..row_idx].tooltipFunc = function(tooltip)
		tooltip:Clear()
		local item = self.resultTbl[row_idx] and self.resultTbl[row_idx][self.itemIndexTbl[row_idx]]
		if not item then return end
		tooltip.center = true
		if item.isInstantBuyout then
			tooltip:AddLine(16, "Opens trade page in browser.")
			tooltip:AddLine(16, "Copies item name to clipboard (for manual search).")
			tooltip:AddLine(16, "Click 'Travel to Hideout' on the trade site to buy.")
		else
			tooltip:AddLine(16, "Copies the whisper to clipboard.")
			tooltip:AddLine(16, "Paste it in-game chat to contact the seller.")
		end
	end
	controls["actionButton"..row_idx].shown = function() return self.resultTbl[row_idx] end
	-- [Link] button: open per-row trade URL in browser
	controls["linkButton"..row_idx] = new("ButtonControl", { "TOPLEFT", controls["actionButton"..row_idx], "TOPRIGHT"}, {5, 0, 36, row_height}, "[Link]", function()
		local item = self.resultTbl[row_idx] and self.resultTbl[row_idx][self.itemIndexTbl[row_idx]]
		local itemName = item and getItemDisplayName(item) or ""
		-- Open trade search with item name + exact price filter
		local amt = item and item.amount or nil
		local cur = item and item.currency or nil
		local nameUrl = buildItemNameSearchURL(itemName, amt, cur)
		if nameUrl then
			OpenURL(nameUrl)
		else
			local url = controls["uri"..row_idx].buf
			if url and url ~= "" then OpenURL(url) end
		end
		if itemName ~= "" then Copy(itemName) end
	end)
	controls["linkButton"..row_idx].enabled = function()
		-- Enabled if we have a valid URI or a selected item (we can build URL from name)
		if controls["uri"..row_idx].validURL then return true end
		local item = self.resultTbl[row_idx] and self.resultTbl[row_idx][self.itemIndexTbl[row_idx]]
		return item ~= nil
	end
	controls["linkButton"..row_idx].shown = function() return self.resultTbl[row_idx] end
	controls["linkButton"..row_idx].tooltipFunc = function(tooltip)
		tooltip:Clear()
		tooltip:AddLine(16, "Open this trade search in browser.")
		tooltip:AddLine(16, "Copies item name to clipboard (for manual search).")
	end
end

-- Method to update the Total Price string sum of all items
function TradeQueryClass:GetTotalPriceString()
	local text = ""
	local sorted_price = { }
	for _, entry in pairs(self.totalPrice) do
		if sorted_price[entry.currency] then
			sorted_price[entry.currency] = sorted_price[entry.currency] + entry.amount
		else
			sorted_price[entry.currency] = entry.amount
		end
	end
	for currency, value in pairs(sorted_price) do
		text = text .. tostring(value) .. " " .. currency .. ", "
	end
	if text ~= "" then
		text = text:sub(1, -3)
	end
	return text
end

-- Method to update realms and leagues
function TradeQueryClass:UpdateRealms()
	local function setRealmDropList()
		self.realmDropList = {}
		for realm, _ in pairs(self.realmIds) do
			t_insert(self.realmDropList, realm)
		end
		self.controls.realm:SetList(self.realmDropList)
		-- invalidate selIndex to trigger select function call in the SetSel
		-- DropDownControl doesn't check if the inner list has changed so selecting the first item doesn't count as an update after list refresh
		self.controls.realm.selIndex = nil
		self.controls.realm:SetSel(self.pbRealmIndex)
	end

	-- use trade leagues api to get trade leagues including private leagues if valid.
	for _, realmId in pairs (self.realmIds) do
		self.tradeQueryRequests:FetchLeagues(realmId, function(leagues, errMsg)
			if errMsg then
				self:SetNotice(self.controls.pbNotice, "Using Fallback Error while fetching league list: "..errMsg)
			end
			self.allLeagues = {}
			for _, league in ipairs(leagues) do
				if not self.allLeagues[realmId] then self.allLeagues[realmId] = {} end
				t_insert(self.allLeagues[realmId], league)
			end
			setRealmDropList()

		end)
	end

	-- perform a generic search to make sure POESESSID if valid.
	self.tradeQueryRequests:PerformSearch("poe2", "Standard", [[{"query":{"status":{"option":"online"},"stats":[{"type":"and","filters":[]}]},"sort":{"price":"asc"}}]], function(response, errMsg) 
		if errMsg then
			self:SetNotice(self.controls.pbNotice, "Error: " .. tostring(errMsg))
		end
	end)
end
