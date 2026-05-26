-- Path of Building
--
-- Module: AI Settings
-- Stores AI assistant API settings in the user's local PoB data folder.

local json = require("dkjson")
local providers = LoadModule("AI/ProviderPresets")

local settings = { }

local function copyDefaults()
	local defaultProvider = providers.byId.openai or providers.list[1]
	return {
		provider = defaultProvider.id,
		apiBase = defaultProvider.apiBase,
		apiKey = "",
		model = defaultProvider.model,
		temperature = 0.2,
	}
end

local function getPath()
	local userPath = main and main.userPath or ""
	return userPath .. "AIAssistantSettings.json"
end

function settings.Load()
	local out = copyDefaults()
	local file = io.open(getPath(), "r")
	if file then
		local text = file:read("*a")
		file:close()
		local data = json.decode(text)
		if type(data) == "table" then
			for key, value in pairs(data) do
				out[key] = value
			end
		end
	end
	return out
end

function settings.Save(data)
	local file, err = io.open(getPath(), "w+")
	if not file then
		return nil, err
	end
	file:write(json.encode(data, { indent = true }))
	file:close()
	return true
end

function settings.IsConfigured(data)
	if not (data and data.apiBase and data.apiBase:match("%S") and data.model and data.model:match("%S")) then
		return false
	end
	if data.apiBase:match("localhost") or data.apiBase:match("127%.0%.0%.1") then
		return true
	end
	return data.apiKey and data.apiKey:match("%S")
end

function settings.GetPath()
	return getPath()
end

return settings
