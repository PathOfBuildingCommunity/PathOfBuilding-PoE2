-- Path of Building
--
-- Module: Trade Query Requests
-- Handling trade api requests while respecting rate limits
--

local dkjson = require "dkjson"

---@class TradeQueryRequests
local TradeQueryRequestsClass = newClass("TradeQueryRequests", function(self, rateLimiter)
	self.maxFetchPerSearch = 10
	self.tradeQuery = tradeQuery
	self.rateLimiter = rateLimiter or new("TradeQueryRateLimiter")
	self.requestQueue = {
		["search"] = {},
		["fetch"] = {},
		["whisper"] = {},
	}
	self.hostName = "https://www.pathofexile.com/"
end)

---Main routine for processing request queue
function TradeQueryRequestsClass:ProcessQueue()
	for key, queue in pairs(self.requestQueue) do
		if #queue > 0 then
			local policy = self.rateLimiter:GetPolicyName(key)
			local now = os.time()
			local timeNext = self.rateLimiter:NextRequestTime(policy, now)
			if now >= timeNext then
				local request = table.remove(queue, 1)
				local requestId = self.rateLimiter:InsertRequest(policy)
				local onComplete = function(response, errMsg)
					self.rateLimiter:FinishRequest(policy, requestId)
					if response and response.header then
						self.rateLimiter:UpdateFromHeader(response.header)
					end
					if response and response.header and response.header:match("HTTP/[%d%.]+ (%d+)") == "429" then
						table.insert(queue, 1, request)
						return
					end
					-- if limit rules don't return account then the POESESSID is invalid.
					if response and response.header and response.header:match("X%-Rate%-Limit%-Rules: (.-)\n") and response.header:match("X%-Rate%-Limit%-Rules: (.-)\n"):match("Account") == nil and main.POESESSID ~= "" then
						main.POESESSID = ""
						if errMsg then
							errMsg = errMsg .. "\nPOESESSID is invalid. Please Re-Log and reset"
						else
							errMsg = "POESESSID is invalid. Please Re-Log and reset"
						end
					end
					request.callback(response and response.body or nil, errMsg, unpack(request.callbackParams or {}))
				end
				
				local header = request.headers or "Content-Type: application/json\nUser-Agent: Path of Building Community"
				if main.POESESSID ~= "" then
					header = header .. "\nCookie: POESESSID=" .. main.POESESSID
				end
				
				local downloadOptions = {
					header = header,
					body = request.body
				}
				if request.body then
					downloadOptions.post = "raw"
				end
				
				launch:DownloadPage(request.url, onComplete, downloadOptions)
			else
				break
			end
		end
	end
end

---Performs search and fetches results
---@param league string
---@param query string
---@param callback fun(items:table, errMsg:string)
---@param params table @ params = { callbackQueryId = fun(queryId:string) }
function TradeQueryRequestsClass:SearchWithQuery(realm, league, query, callback, params)
	params = params or {}
	--ConPrintf("Query json: %s", query)
	self:PerformSearch(realm, league, query, function(response, errMsg)
		if params.callbackQueryId and response and response.id then
			params.callbackQueryId(response.id)
		end
		if errMsg then
			return callback(nil, errMsg)
		end
		self:FetchResults(response.result, response.id, callback)
	end)
end

---Performs search and fetches results, adjusting the query weight and repeating
---the search to fetch more items when the search cap (10k items) is reached
---@param league string
---@param query string
---@param callback fun(items:table, errMsg:string)
---@param params table @ params = { callbackQueryId = fun(queryId:string) }
function TradeQueryRequestsClass:SearchWithQueryWeightAdjusted(realm, league, query, callback, params)
	params = params or {}
	local previousSearchId = nil
	local previousSearchItemIds = nil
	local previousSearchItems = nil
	-- Limit recursion to prevent potential loops
	-- Each repeat is a leap of 10k items, normally we shouldn't need more than 1-2 steps anyways
	local maxRecursion = 5
	local currentRecursion = 0
	local function performSearchCallback(response, errMsg)
		currentRecursion = currentRecursion + 1
		if params.callbackQueryId and response and response.id then
			params.callbackQueryId(response.id)
		end
		if errMsg and ((errMsg == "No Matching Results Found" and currentRecursion >= maxRecursion) or errMsg ~= "No Matching Results Found") then
			return callback(nil, errMsg)
		end
		if (response.total > self.maxFetchPerSearch and response.total < 10000) or currentRecursion >= maxRecursion then
			-- Search not clipped or max recursion reached, fetch results and finalize
			if previousSearchItems and self.maxFetchPerSearch > response.total then
				-- Not enough items in the last search, fill results from previous search
				self:FetchResults(response.result, response.id, function(items, errMsg)
					if errMsg then
						return callback(nil, errMsg)
					end
					local fetchedItemIds = {}
					for _, value in pairs(items) do
						table.insert(fetchedItemIds, value.id)
					end
					for _, value in pairs(previousSearchItems) do
						if #items >= self.maxFetchPerSearch then
							break
						end
						if not isValueInTable(fetchedItemIds, value.id) then
							table.insert(items, value)
							table.insert(fetchedItemIds, value.id)
						end
					end
					local fillCount = self.maxFetchPerSearch - #items
					if fillCount > 0 then
						-- fill with previous search results
						local unfetchedItemIds = {}
						for _, value in pairs(previousSearchItemIds) do
							if #unfetchedItemIds >= fillCount then
								break
							end
							if not isValueInTable(fetchedItemIds, value) then
								table.insert(unfetchedItemIds, value)
							end
						end
						self:FetchResults(unfetchedItemIds, previousSearchId, function(newItems, errMsg)
							if errMsg then
								return callback(nil, errMsg)
							end
							items = tableConcat(items, newItems)
							callback(items, errMsg)
						end)
					else
						callback(items, errMsg)
					end
				end)
			else
				-- Search not clipped and result count satisfy maxFetchPerSearch, proceed normally
				self:FetchResults(response.result, response.id,  callback)
			end
		else
			if response.total < self.maxFetchPerSearch then -- Less than maximum items retrieved lower weight to try and get more.
				local queryJson = dkjson.decode(query)
				queryJson.query.stats[1].value.min = queryJson.query.stats[1].value.min / 2
				query = dkjson.encode(queryJson)
				self:PerformSearch(realm, league, query, performSearchCallback)
			else -- Search clipped, fetch highest weight item, update query weight and repeat search
				previousSearchItemIds = response.result
				previousSearchId = response.id
				local firstResultBatch = {unpack(response.result, 1, math.min(#response.result, 10))}
				self:FetchResults(firstResultBatch, response.id, function(items, errMsg)
					if errMsg then
						return callback(nil, errMsg)
					end
					previousSearchItems = items
					local highestWeight = items[1].weight
					local queryJson = dkjson.decode(query)
					queryJson.query.stats[1].value.min = (tonumber(highestWeight) + queryJson.query.stats[1].value.min) / 2
					query = dkjson.encode(queryJson)
					self:PerformSearch(realm, league, query, performSearchCallback)
				end)
			end
		end
	end
	self:PerformSearch(realm, league, query, performSearchCallback)
end

---Perform search and run callback function on returned item hashes.
---Item info has to be fetched separately 
---@param league string
---@param query string
---@param callback fun(response:table, errMsg:string)
function TradeQueryRequestsClass:PerformSearch(realm, league, query, callback)
	table.insert(self.requestQueue["search"], {
		url = self:buildUrl(self.hostName .. "api/trade2/search", realm, league),
		body = query,
		callback = function(response, errMsg)
			if errMsg and not errMsg:find("Response code: 400") and not errMsg:find("POESESSID") then
				return callback(nil, errMsg)
			end
			local response = dkjson.decode(response)
			if not response then
				errMsg = "Failed to Get Trade response"
				return callback(nil, errMsg)
			end
			if not response.result or #response.result == 0 then
				if response.error then
					if not (response.error.code and response.error.message) then
						errMsg = "Encountered unknown error, check console for details."
						ConPrintf("Unknown error: %s", stringify(response.error))
						callback(response, errMsg)
					end
					if response.error.message:find("Logging in will increase this limit") then
						if main.POESESSID ~= "" then
							errMsg = "POESESSID is invalid. Please Re-Log and reset"
							main.POESESSID = ""
						else
							errMsg = "Session is invalid. Please add your POESESSID"
						end
					else
						-- Report unhandled error
						errMsg = "[ " .. response.error.code .. ": " .. response.error.message .. " ]"
					end
				else
					ConPrintf("Found 0 results for " .. self.hostName .. "api/trade2/search/" .. league .. "/" .. response.id)
					errMsg = "No Matching Results Found"
				end
				return callback(response, errMsg)
			end
			callback(response, errMsg)
		end,
	})
end

---Fetch item details for itemHashes
---@param itemHashes string[]
---@param queryId string
---@param callback fun(items:table, errMsg:string)
function TradeQueryRequestsClass:FetchResults(itemHashes, queryId, callback)
	local quantity_found = math.min(#itemHashes, self.maxFetchPerSearch)
	local max_block_size = 10
	local items = {}
	for fetch_block_start = 1, quantity_found, max_block_size do
		local fetch_block_end = math.min(fetch_block_start + max_block_size - 1, quantity_found)
		local param_item_hashes = table.concat({unpack(itemHashes, fetch_block_start, fetch_block_end)}, ",")
		local fetch_url = self.hostName .. "api/trade2/fetch/"..param_item_hashes.."?query="..queryId
		self:FetchResultBlock(fetch_url, function(itemBlock, errMsg)
			if errMsg then
				return callback(nil, errMsg)
			end
			for _, item in pairs(itemBlock) do
				table.insert(items, item)
			end
			-- finished fetching item blocks
			if #items >= quantity_found then
				callback(items)
			end
		end)
	end
end

---Fetch details for paginated items
---@param url string
---@param callback fun(items: table, errMsg:string)
function TradeQueryRequestsClass:FetchResultBlock(url, callback)
	table.insert(self.requestQueue["fetch"], {
		url = url,
		callback = function(response, errMsg)
			if errMsg then
				return callback(nil, errMsg)
			end
			local response, response_err = dkjson.decode(response)
			if not response or not response.result then
				if response_err then
					errMsg = "JSON Parse Error: " .. (errMsg or "")
				else
					errMsg = "Failed to Get Trade Items: " .. (errMsg or "")
				end
				return callback(nil, errMsg)
			end
			local items = {}
			for _, trade_entry in pairs(response.result) do
				local item = trade_entry.item
				local spirit
				local armour
				local evasion
				local es
				local charmSlots
				local quality
				local radius
				local limit
				local t_insert = table.insert
				-- local catalystList = {"Abrasive", "Accelerating", "Fertile", "Imbued", "Intrinsic", "Noxious", "Prismatic", "Tempering", "Turbulent", "Unstable"}
				
				if item.properties then
					for _, property in ipairs(item.properties) do
						local name = escapeGGGString(property.name)
						if name == "Armour" then
							armour = property.values[1][1]
						elseif name == "Evasion Rating" then
							evasion = property.values[1][1]
						elseif name == "Energy Shield" then
							es = property.values[1][1]
						elseif name == "Quality" then
							quality = property.values[1][1]:sub(2, -2) -- remove + and % on quality value	
						elseif name == "Spirit" then
							spirit = property.values[1][1]
						elseif name == "Charm Slots" then
							charmSlots = property.values[1][1]
						-- elseif name == "Quality (Mana Modifiers)" then
							-- catalyst quality stuff tbd it all needs reworking anyway as it has changed.
						elseif name == "Radius" then
							radius = property.values[1][1]
						elseif name == "Limited to" then
							limit = property.values[1][1]
						end
					end
				end
				
				local rawLines = { }
				t_insert(rawLines, "Rarity: " .. item.rarity)
				-- item.name is empty when magic and full magic name is in typeLine but typeLine == baseType when rare.
				if item.name ~= "" then
					t_insert(rawLines, item.name) 
				end
				t_insert(rawLines, item.typeLine)

				if charmSlots then
					t_insert(rawLines, "Charm Slots: " .. charmSlots)
				end
				
				if spirit then
					t_insert(rawLines, "Spirit: " .. spirit)
				end

				if armour then
					t_insert(rawLines,  "Armour: " .. armour)
				end
				if evasion then
					t_insert(rawLines,  "Evasion: " ..evasion)
				end
				if es then
					t_insert(rawLines,  "Energy Shield: " .. es)
				end

				-- if self.catalyst and self.catalyst > 0 then
				-- 	t_insert(rawLines, "Catalyst: " .. catalystList[self.catalyst])
				-- end
				-- if self.catalystQuality then
				-- 	t_insert(rawLines, "CatalystQuality: " .. self.catalystQuality)
				-- end

				if item.ilvl then
					t_insert(rawLines, "Item Level: " .. item.ilvl)
				end
				if quality then
					t_insert(rawLines, "Quality: " .. quality)
				end
				if item.sockets then
					local socketString = ""
					for _, _ in ipairs(item.sockets) do
						socketString = socketString .. "S "
					end
					socketString = socketString:gsub(" $", "")
					t_insert(rawLines, "Sockets: " .. socketString)
				end

				if item.requirements then
					for _, requirement in ipairs(item.requirements) do
						if requirement.name == "Level"  then
							t_insert(rawLines, "LevelReq: " .. requirement.values[1][1])
						end
					end
				end

				if radius then
					t_insert(rawLines, "Radius: " .. radius)
				end
				if limit then
					t_insert(rawLines, "Limited to: " .. limit)
				end

				-- ensure these fields are initialised
				item.enchantMods = item.enchantMods or { }
				item.fracturedMods = item.fracturedMods or { }
				item.desecratedMods = item.desecratedMods or { }
				item.runeMods = item.runeMods or { }
				item.implicitMods = item.implicitMods or { }
				item.explicitMods = item.explicitMods or { }

				t_insert(rawLines, "Implicits: " .. (#item.enchantMods + #item.runeMods + #item.implicitMods))
				for _, modLine in ipairs(item.enchantMods) do
					t_insert(rawLines, "{enchant}"	.. escapeGGGString(modLine))
				end
				for _, modLine in ipairs(item.runeMods) do
					t_insert(rawLines, "{enchant}{rune}"	.. escapeGGGString(modLine))
				end
				for _, modLine in ipairs(item.implicitMods) do
					t_insert(rawLines, escapeGGGString(modLine))
				end
				for _, modLine in ipairs(item.fracturedMods) do
					t_insert(rawLines, "{fractured}"	.. escapeGGGString(modLine))
				end
				for _, modLine in ipairs(item.explicitMods) do
					t_insert(rawLines, escapeGGGString(modLine))
				end
				for _, modLine in ipairs(item.desecratedMods) do
					t_insert(rawLines, "{desecrated}"	.. escapeGGGString(modLine))
				end
				if item.mirrored then
					t_insert(rawLines, "Mirrored")
				end
				if item.corrupted then
					t_insert(rawLines, "Corrupted")
				end
				

				table.insert(items, {
					amount = trade_entry.listing.price.amount,
					currency = trade_entry.listing.price.currency,
					item_string = table.concat(rawLines, "\n"),
					whisper = trade_entry.listing.whisper,
					whisper_token = trade_entry.listing.whisper_token,
					hideout_token = trade_entry.listing.hideout_token,
					weight = trade_entry.item.pseudoMods and trade_entry.item.pseudoMods[1]:match("Sum: (.+)") or "0",
					id = trade_entry.id
				})
			end
			return callback(items)
		end
	})
end

---@param callback fun(items:table, errMsg:string)
function TradeQueryRequestsClass:SearchWithURL(url, callback)
	local subpath = url:match(self.hostName .. "trade2/search/(.+)$")
	local paths = {}
	for path in subpath:gmatch("[^/]+") do
		table.insert(paths, path)
	end
	if #paths < 2 or #paths > 3 then
		return callback(nil, "Invalid URL")
	end
	local realm, league, queryId
	if #paths == 3 then
		realm = paths[1]
	end
	league = paths[#paths-1]
	queryId = paths[#paths]
	self:FetchSearchQuery(realm, league, queryId, function(query, errMsg)
		if errMsg then
			return callback(nil, errMsg)
		end

		-- update sorting on provided url to sort by weights.
		local json_data = dkjson.decode(query)
		if not json_data or json_data.error then
			errMsg = json_data and json_data.error or "Failed to parse search query JSON"
		end
		if json_data.query.stats and json_data.query.stats[1] and json_data.query.stats[1].type == "weight" then
			json_data.sort = {}
			json_data.sort["statgroup.0"] = "desc"
		else
			json_data.sort = { price = "asc"}
		end
		query = dkjson.encode(json_data)

		self:SearchWithQuery(realm, league, query, callback)
	end)
end

---Fetch query data needed to perform the search
---@param queryId string
---@param league string
---@param callback fun(query:string, errMsg:string)
function TradeQueryRequestsClass:FetchSearchQuery(realm, league, queryId, callback)
	local url = self:buildUrl(self.hostName .. "api/trade2/search", realm, league, queryId)
	table.insert(self.requestQueue["search"], {
		url = url,
		callback = function(response, errMsg)
			if errMsg then
				return callback(nil, errMsg)
			end
			local json_data = dkjson.decode(response)
			if not json_data or json_data.error then
				errMsg = json_data and json_data.error or "Failed to get search query"
			end
			callback(response, errMsg)
		end
	})
end

--- Fetches the list of all available leagues using trade2 league API
---@param realm string
---@param callback fun(query:table, errMsg:string)
function TradeQueryRequestsClass:FetchLeagues(realm, callback)
	local header = "Cookie: POESESSID=" .. main.POESESSID
	launch:DownloadPage(
			self.hostName .. "api/trade2/data/leagues",
			function(response, errMsg)
				if errMsg then
					return callback({"Standard", "Hardcore"}, errMsg)
				end
				local json_data = dkjson.decode(response.body)
				if not json_data or json_data.error then
					errMsg = json_data and json_data.error or "Failed to parse trade leagues JSON"
				end
				local leagues = {}
				for _, value in pairs(json_data.result) do
					if value.realm == realm then
						table.insert(leagues, value.id)
					end
				end
				callback(leagues, errMsg)
			end,
			{header = header}
	)
end

--- Build search and trade URLs with proper encoding
---@param root string
---@param realm string
---@param league string
---@param queryId string
function TradeQueryRequestsClass:buildUrl(root, realm, league, queryId)
	local result = root
	if realm and realm ~='pc' then
		result = result .. "/" .. realm
	end	
	result = result .. "/" .. league:gsub(" ", "+")
	if queryId then
		result = result .. "/" .. queryId
	end
	return result	
end

---@param callback fun(items:table, errMsg:string)
function TradeQueryRequestsClass:SendWhisper(token, refererUrl, callback)
	ConPrintf("Attempting to send whisper with token: " .. tostring(token))

	-- Manually construct the JSON string to ensure a space after the colon
	local requestBody = '{"token": "' .. token .. '"}'

	-- Construct the full headers required by the whisper API
	local headers = {
		"Content-Type: application/json",
		"User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/139.0.0.0 Safari/537.36",
		"X-Requested-With: XMLHttpRequest"
	}
	if refererUrl then
		table.insert(headers, "Referer: " .. refererUrl)
	end

	table.insert(self.requestQueue["whisper"], {
		url = self.hostName .. "api/trade2/whisper",
		body = requestBody,
		headers = table.concat(headers, "\n"),
		callback = function(responseBody, errMsg)
			ConPrintf("Whisper API Response Body: " .. tostring(responseBody))
			ConPrintf("Whisper API Error Message: " .. tostring(errMsg))
			if errMsg then
				return callback(nil, errMsg)
			end
			local response, jsonErr = dkjson.decode(responseBody)
			if not response then
				errMsg = "Failed to decode Whisper JSON response: " .. (jsonErr or "Empty response")
				return callback(nil, errMsg)
			end
			callback(response, errMsg)
		end,
	})
end