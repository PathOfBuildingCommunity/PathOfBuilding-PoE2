local base64 = require("base64")
local sha = require("sha2")
local dkjson = require "dkjson"

local scopesOAuth = {
	"account:profile",
	"account:leagues",
	"account:characters",
}

local PoEAPIClass = newClass("PoEAPI", function(self, authToken, refreshToken)
	self.retries = 0
	self.authToken = authToken
	self.refreshToken = refreshToken
	self.baseUrl = "https://api.pathofexile.com"
end)

-- func callback(valid, updateSettings)
function PoEAPIClass:ValidateAuth(callback)
	ConPrintf("Validating auth token")
	-- make a call for profile if not error we are good
	-- if error 401 then try to recreate the token with 
	if self.authToken and self.refreshToken then
		launch:DownloadPage(self.baseUrl .. "/profile", function (response, errMsg)
			if errMsg and errMsg:match("401") then
				-- here recreate the token with the refresh_token
				local formText = "client_id=pob&grant_type=refresh_token&refresh_token=" .. self.refreshToken
				launch:DownloadPage("https://www.pathofexile.com/oauth/token", function (response, errMsg)
					ConPrintf("Recreating auth token")
					if errMsg then
						ConPrintf("Failed to recreate auth token: %s", errMsg)
						callback(false, false)
						return
					end
					-- TODO : Check for error in response
					local responseLua = dkjson.decode(response.body)
					self.authToken = responseLua.access_token
					self.refreshToken = responseLua.refresh_token
					self.retries = 0
					callback(true, true)
				end, { body = formText })
			else
				callback(true, false)
			end
		end, { header = "Authorization: Bearer " .. self.authToken })
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

	-- TODO: Generate state
	local state = "test"

	local authUrl = string.format(
		"https://www.pathofexile.com/oauth/authorize?client_id=pob&response_type=code&scope=%s&state=%s&code_challenge=%s&code_challenge_method=S256"
		,table.concat(scopesOAuth, " ")
		,state
		,code_challenge
	)

	local server = io.open("LaunchServer.lua", "r")
	local id = LaunchSubScript(server:read("*a"), "", "ConPrintf,OpenURL", authUrl)
	if id then
		launch.subScripts[id] = {
			type = "DOWNLOAD",
			callback = function(code, state, port)
				if not code then
					ConPrintf("Failed to get code from server")
					callback()
					return
				end

				if "test" ~= state then
					return
				end
				local formText = "client_id=pob&grant_type=authorization_code&code=" .. code .. "&redirect_uri=http://localhost:" .. port .. "&scope=account:profile account:leagues account:characters&code_verifier=" .. code_verifier
				launch:DownloadPage("https://www.pathofexile.com/oauth/token", function (response, errMsg)
					-- TODO : Check for error in response
					local responseLua = dkjson.decode(response.body)
					self.authToken = responseLua.access_token
					self.refreshToken = responseLua.refresh_token
					self.retries = 0
					ConPrintf(self.authToken)
					SetForeground()
					callback()
				end, { body = formText })
			end
		}
	end
end

function PoEAPIClass:DownloadWithRefresh(endpoint, callback)
	launch:DownloadPage(self.baseUrl .. endpoint, function (response, errMsg)
		if errMsg and errMsg:match("401") and self.retries < 1 then
			self.retries = self.retries + 1
			self:FetchAuthToken(function()
				self:DownloadWithRefresh(endpoint, callback)
			end)
		else
			self.retries = 0
			callback(response.body, errMsg)
		end
	end, { header = "Authorization: Bearer " .. self.authToken })
end

function PoEAPIClass:DownloadCharacterList(realm, callback)
	self:DownloadWithRefresh("/character" .. (realm == "pc" and "" or "/" .. realm), callback)
end

function PoEAPIClass:DownloadCharacter(realm, name, callback)
	self:DownloadWithRefresh("/character" .. (realm == "pc" and "" or "/" .. realm) .. "/" .. name, callback)
end