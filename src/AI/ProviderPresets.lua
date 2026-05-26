-- Path of Building
--
-- Module: AI Provider Presets
-- OpenAI-compatible defaults for the build assistant.

local presets = {
	{
		id = "openai",
		label = "OpenAI-compatible",
		apiBase = "https://api.openai.com/v1",
		model = "",
	},
	{
		id = "custom",
		label = "Custom",
		apiBase = "",
		model = "",
	},
}

local byId = { }
for _, preset in ipairs(presets) do
	byId[preset.id] = preset
end

return {
	list = presets,
	byId = byId,
}
