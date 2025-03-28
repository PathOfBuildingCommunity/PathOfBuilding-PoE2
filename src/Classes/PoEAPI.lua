local base64 = require("base64")
local sha = require("sha2")
local dkjson = require "dkjson"

local retries = 0

local PoEAPIClass = newClass("PoEAPI", function(self, authToken)
	self.authToken = authToken
	self.baseUrl = "https://api.pathofexile.com"
end)

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
	-- TODO: Make port based on what port is available (See LaunchServer.lua)
	local authUrl = "https://www.pathofexile.com/oauth/authorize?client_id=pob&response_type=code&scope=account:profile account:leagues account:characters&state=" .. state .. "&redirect_uri=http://localhost:49082&code_challenge=" .. code_challenge .. "&code_challenge_method=S256"
	OpenURL(authUrl)

	local server = io.open("LaunchServer.lua", "r")
	local id = LaunchSubScript(server:read("*a"), "", "ConPrintf")
	if id then
		launch.subScripts[id] = {
			type = "DOWNLOAD",
			callback = function(code, state, port)
				if "test" ~= state then
					return
				end
				local formText = "client_id=pob&grant_type=authorization_code&code=" .. code .. "&redirect_uri=http://localhost:" .. port .. "&scope=account:profile account:leagues account:characters&code_verifier=" .. code_verifier
				launch:DownloadPage("https://www.pathofexile.com/oauth/token", function (response, errMsg)
					local responseLua = dkjson.decode(response.body)
					self.authToken = responseLua.access_token
					ConPrintf(self.authToken)
					callback()
				end, { body = formText })
			end
		}
	end
end

function PoEAPIClass:DownloadWithRefresh(endpoint, callback)
	launch:DownloadPage(self.baseUrl .. endpoint, function (response, errMsg)
		if errMsg and errMsg:match("401") and retries < 1 then
			self:FetchAuthToken()
			self:DownloadWithRefresh(endpoint, callback)
		else
			retries = 0
		end
		callback(response.body, errMsg)
	end, { header = "Authorization: Bearer " .. self.authToken })
end

function PoEAPIClass:DownloadCharacterList(realm, callback)
	self:DownloadWithRefresh("/character" .. (realm == "pc" and "" or "/" .. realm), callback)
end

function PoEAPIClass:DownloadCharacter(realm, name, callback)
	self:DownloadWithRefresh("/character" .. (realm == "pc" and "" or "/" .. realm) .. "/" .. name, callback)
end