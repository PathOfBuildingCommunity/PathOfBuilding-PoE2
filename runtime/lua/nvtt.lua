local module = {}
local function escape_path(path)
    -- Replace '\' with '\\' first to avoid double escaping
    local escaped_path = path:gsub("\\", "\\")
    -- Replace '/' with '\\'
    escaped_path = escaped_path:gsub("/", "\\")
    return escaped_path
end
--[[
PLease install NVIDIA Texture Tools Mods exported
and add the path to the system environment variable
--]]
function module.CompressDDSIntoOtherFormat(path_base, path_for_bat, name, listOfFile, format, executeCommand)
	local shCommands = ""
	for _, file in ipairs(listOfFile) do
		shCommands = shCommands .. string.format(
			"nvcompress.exe -%s -highest \"%s\" \"%s\"\n",
			format,
			escape_path(path_base .. file),
			escape_path(path_base .. file)
		)
	end
	local batPath = path_for_bat .. "compress_" .. name .. ".bat"
	local batFile = io.open(batPath, "w")
	batFile:write(shCommands)
	batFile:close()

	local command = string.format(
		"cmd /c \"%s\"",
		escape_path(batPath)
	)

	if executeCommand then
		os.execute(command)
	end
end

return module