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
function module.ExportDDSToPng(path_base, path_for_bat, name, listOfFile, executeCommand)
	local shCommands = "@echo off\n"
	for _, file in ipairs(listOfFile) do
		local output = escape_path(path_base .. string.gsub(file, ".dds", ".png"))
		local input = escape_path(path_base .. file)
		shCommands = shCommands .. string.format(
			"if not exist \"%s\" (\n\tnvtt_export.exe -o \"%s\" \"%s\"\n) else (\n\techo File %s already exists\n)\n",
			output,
			output,
			input,
			output
		)
	end
	local batPath = path_for_bat .. "export_" .. name .. ".bat"
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