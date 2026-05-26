-- Path of Building
--
-- Module: AI Client
-- Minimal non-streaming OpenAI-compatible chat completions client.

local json = require("dkjson")

local client = { }

local function endpointFromBase(apiBase)
	apiBase = (apiBase or ""):gsub("%s+$", "")
	if apiBase:match("/chat/completions$") then
		return apiBase
	end
	apiBase = apiBase:gsub("/+$", "")
	return apiBase .. "/chat/completions"
end

local function extractContent(responseText)
	local data, _, err = json.decode(responseText or "")
	if not data then
		return nil, err or "Could not parse API response."
	end
	if data.error then
		if type(data.error) == "table" then
			return nil, data.error.message or data.error.code or "The API returned an error."
		end
		return nil, tostring(data.error)
	end
	local choice = data.choices and data.choices[1]
	local message = choice and choice.message
	if message and message.content then
		return message.content
	end
	if choice and choice.text then
		return choice.text
	end
	return nil, "The API response did not include displayable content."
end

function client.Send(settings, messages, callback)
	local body = json.encode({
		model = settings.model,
		messages = messages,
		temperature = tonumber(settings.temperature) or 0.2,
		stream = false,
	})
	local headers = "Content-Type: application/json"
	if settings.apiKey and settings.apiKey:match("%S") then
		headers = headers .. "\r\nAuthorization: Bearer " .. settings.apiKey
	end
	launch:DownloadPage(endpointFromBase(settings.apiBase), function(response, errMsg)
		local content, parseErr = extractContent(response and response.body or "")
		if content then
			callback(content)
		else
			callback(nil, parseErr or errMsg or "Request failed.")
		end
	end, {
		header = headers,
		body = body,
	})
end

return client
