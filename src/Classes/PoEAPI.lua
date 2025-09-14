local base64 = require("base64")
local sha = require("sha2")
local dkjson = require "dkjson"

local scopesOAuth = {
	"account:profile",
	"account:leagues",
	"account:characters",
}

local filename = "poe_api_response.json"

local PoEAPIClass = newClass("PoEAPI", function(self, authToken, refreshToken, tokenExpiry)
	self.retries = 0
	self.authToken = authToken
	self.refreshToken = refreshToken
	self.tokenExpiry = tokenExpiry or 0
	self.baseUrl = "https://api.pathofexile.com"
	self.rateLimiter = new("TradeQueryRateLimiter")

	self.ERROR_NO_AUTH = "No auth token"
end)

-- func callback(valid, updateSettings)
function PoEAPIClass:ValidateAuth(callback)
	ConPrintf("Validating auth token")
	-- make a call for profile if not error we are good
	-- if error 401 then try to recreate the token with 
	if self.authToken and self.refreshToken and self.tokenExpiry then
		if self.tokenExpiry < os.time() then
			ConPrintf("Auth token expired")
			-- here recreate the token with the refresh_token
			local formText = "client_id=pob&grant_type=refresh_token&refresh_token=" .. self.refreshToken
			launch:DownloadPage("https://www.pathofexile.com/oauth/token", function (response, errMsg)
				ConPrintf("Recreating auth token")
				if errMsg then
					ConPrintf("Failed to recreate auth token: %s", errMsg)
					callback(false, false)
					return
				end
				local responseLua = dkjson.decode(response.body)
				self.authToken = responseLua.access_token
				self.refreshToken = responseLua.refresh_token
				self.tokenExpiry = os.time() + responseLua.expires_in
				self.retries = 0
				callback(true, true)
			end, { body = formText })
		else
			callback(true, false)
		end
	else
		callback(false, false)
	end
end

local function base64_encode(secret)
	return base64.encode(secret):gsub("+","-"):gsub("/","_"):gsub("=$", "")
end

function PoEAPIClass:FetchAuthToken(callback)
	math.randomseed(os.time())
	local secret = math.random(2^32-1)
	local code_verifier = base64_encode(tostring(secret))
	local code_challenge = base64_encode(sha.hex_to_bin(sha.sha256(code_verifier)))

	-- 16 character hex string
	local initialState = string.gsub('xxxxxxxxxxxxxxxx', 'x', function()
		return string.format('%x', math.random(0, 0xf))
	end)

	local authUrl = string.format(
		"https://www.pathofexile.com/oauth/authorize?client_id=pob&response_type=code&scope=%s&state=%s&code_challenge=%s&code_challenge_method=S256"
		,table.concat(scopesOAuth, "%20")
		,initialState
		,code_challenge
	)

	local server = io.open("LaunchServer.lua", "r")
	local id = LaunchSubScript(server:read("*a"), "", "ConPrintf,OpenURL", authUrl)
	if id then
		launch.subScripts[id] = {
			type = "DOWNLOAD",
			callback = function(code, errMsg, state, port)
				if not code then
					ConPrintf("Failed to get code from server: %s", errMsg)
					self.authToken = nil
					self.refreshToken = nil
					self.tokenExpiry = nil
					callback(nil, self.ERROR_NO_AUTH, true)
					return
				end

				if initialState ~= state then
					return
				end
				local formText = "client_id=pob&grant_type=authorization_code&code=" .. code .. "&redirect_uri=http://localhost:" .. port .. "&scope=" .. table.concat(scopesOAuth, " ") .. "&code_verifier=" .. code_verifier
				launch:DownloadPage("https://www.pathofexile.com/oauth/token", function (response, errMsg)
					if errMsg then
						ConPrintf("Failed to get token from server: " .. errMsg)
						self.authToken = nil
						self.refreshToken = nil
						self.tokenExpiry = nil
						callback()
						return
					end
					local responseLua = dkjson.decode(response.body)
					self.authToken = responseLua.access_token
					self.refreshToken = responseLua.refresh_token
					self.tokenExpiry = os.time() + responseLua.expires_in
					self.retries = 0
					SetForeground()
					callback()
				end, { body = formText })
			end
		}
	end
end

-- func callback(response, errorMsg, updateSettings)
function PoEAPIClass:DownloadWithRefresh(endpoint, callback)
	self:ValidateAuth(function(valid, updateSettings)
		if not valid then
			-- Clean info about token and refresh token
			self.authToken = nil
			self.refreshToken = nil
			self.tokenExpiry = nil
			callback(nil, self.ERROR_NO_AUTH, true)
			return
		end

		launch:DownloadPage( self.baseUrl .. endpoint, function (response, errMsg)
			if errMsg and errMsg:match("401") and self.retries < 1 then
				-- try once again with refresh token
				self.retries = 1
				self.tokenExpiry = 0
				self:DownloadWithRefresh(endpoint, callback)
			else
				self.retries = 0
				if errMsg then
					ConPrintf("Failed to download %s: %s", endpoint, errMsg)
				elseif response and response.body then
					-- create the file and log the name file
					local file = io.open(filename, "w")
					if file then
						file:write(response.body)
						file:close()
					end
					ConPrintf("Download %s:\n%s\n", endpoint, filename)
				end
				callback(response, errMsg, updateSettings)
			end
		end, { header = "Authorization: Bearer " .. self.authToken })
	end)
end

function PoEAPIClass:DownloadWithRateLimit(policy, url, callback)
	local now = os.time()
	local timeNext = self.rateLimiter:NextRequestTime(policy, now)
	if now >= timeNext then
		local requestId = self.rateLimiter:InsertRequest(policy)
		local onComplete = function(response, errMsg)
			self.rateLimiter:FinishRequest(policy, requestId)
			self.rateLimiter:UpdateFromHeader(response.header)
			if response.header:match("HTTP/[%d%.]+ (%d+)") == "429" then
				timeNext = self.rateLimiter:NextRequestTime(policy, now)
				callback(timeNext, "Response code: 429")
				return
			end
			callback(response.body, errMsg)
		end
		self:DownloadWithRefresh(url, onComplete)
	else
		callback(timeNext, "Response code: 429")
	end
end

---Fetches character list from PoE's OAuth api
---@param realm string Realm to fetch the list from (always poe2)
---@param callback function callback(response, errorMsg, updateSettings)
function PoEAPIClass:DownloadCharacterList(realm, callback)
	self:DownloadWithRateLimit("character-list-request-limit-poe2", "/character" .. (realm == "pc" and "" or "/" .. realm), callback)
end


---Fetches character from PoE's OAuth api
---@param realm string Realm to fetch the character from (always poe2)
---@param name string Character name to fetch
---@param callback function callback(response, errorMsg, updateSettings)
function PoEAPIClass:DownloadCharacter(realm, name, callback)
	self:DownloadWithRateLimit("character-request-limit-poe2", "/character" .. (realm == "pc" and "" or "/" .. realm) .. "/" .. name, callback)
end
