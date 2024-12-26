local module = { }

local function escape_path(path)
    -- Replace '\' with '\\' first to avoid double escaping
    local escaped_path = path:gsub("\\", "\\\\")
    -- Replace '/' with '\\'
    escaped_path = escaped_path:gsub("/", "\\\\")
    return escaped_path
end

local function standard_path(path)
    return path:gsub("/", "\\")
end
--[[
{
	["filename"]= "path-example/output.png",
	["w"]= 360,
	["h"]= 302,
	["coords"]= {
		{
			["icon"]= "path/file1.dds",
			["x"]= 122,
			["y"]= 183,
			["w"]= 58,
			["h"]= 58,
		},
		{
			["icon"]= "path/file2.dds",
			["x"]= 180,
			["y"]= 183,
			["w"]= 58,
			["h"]= 58,
		},
		{
			["icon"]= "path/file3.dds",
			["x"]= 238,
			["y"]= 183,
			["w"]= 58,
			["h"]= 58,
		}
	}
},
]]--
function module.combine_images_to_sprite(sheet_name, sheet_data, from_path, to_path, script_batch_path, saturation, executeCommand)
	executeCommand = executeCommand == nil and true or executeCommand
	local fileLog = to_path.."log_" .. sheet_name  .. ".txt"
	printf(fileLog)

	local logFile = io.open(fileLog, "w")
	local output_path = to_path .. sheet_data["filename"]
	local width = sheet_data["w"]
	local height = sheet_data["h"]
	local coords = sheet_data["coords"]
	
	-- Convert input DDS files and coordinates to a format suitable for the GIMP script
	local coords_str = ""

	for _, coords_data in pairs(coords) do
		local dds_file = coords_data["icon"]
		local x = coords_data["x"]
		local y = coords_data["y"]
		local w = coords_data["w"]
		local h = coords_data["h"]

		-- Format each DDS entry and append to the string
		coords_str = coords_str .. string.format('("%s%s" %d %d %d %d) ', escape_path(from_path), escape_path(dds_file), x, y, w, h)
	end

	-- Trim last comma from the coordinates string
	coords_str = coords_str:sub(1, -2)

	-- because command can be big we are creating a file scm and load base on script_batch_path
	local script_batch_content = string.format(
		"(load \"%s\")"
		, escape_path(script_batch_path)
	)

	local callToFunction = string.format(
		"(combine-images-into-sprite-sheet \"%s\" %d %d %d '(%s))", 
		escape_path(output_path), width, height, saturation, coords_str
	)

	script_batch_content = script_batch_content .. "\n\n" .. callToFunction
	local new_script_path = to_path.."script_".. sheet_name ..".scm"
	local new_script = io.open(new_script_path, "w")
	new_script:write(script_batch_content)
	new_script:close()

	-- Construct the GIMP batch command
	local cmd = string.format(
		'gimp-console-3.exe --batch-interpreter plug-in-script-fu-eval -i -b "(load \\\"%s\\\")" -b "(gimp-quit 0)"',
		escape_path(new_script_path)
	)
	logFile:write(cmd.."\n")

	if executeCommand then
		os.execute(cmd)
	end

	logFile:close()
end

--[[
info = {
	{
		mask = "Art/./mask.png",
		file = "Art/./file.png",
		extension = "png",
		basename = "file",
		total = 10
	}
}
--]]
function module.extract_lines_from_image(name, info, from_path, to_path, script_batch_path, executeCommand)
	executeCommand = executeCommand == nil and true or executeCommand

	local fileLog = to_path.."log_" .. name  .. ".txt"
	printf(fileLog)

	local logFile = io.open(fileLog, "w")

	for _, data in pairs(info) do
		local src = from_path..data["file"]
		local mask = from_path..data["mask"]
		local basename = data["basename"]
		local extension = data["extension"]
		local total = data["total"]
		-- because command can be big we are creating a file scm and load base on script_batch_path
		local script_batch_content = string.format(
			"(load \"%s\")"
			, escape_path(script_batch_path)
		)

		local callToFunction = string.format(
			"(extract-lines-pob \"%s\" \"%s\" %d \"%s\" \"%s\" \"%s\" %d)", 
			escape_path(src), escape_path(mask),  total, escape_path(to_path), basename, extension, 0
		)

		script_batch_content = script_batch_content .. "\n\n" .. callToFunction
		local new_script_path = to_path.."script_".. name .. "_" .. basename ..".scm"
		local new_script = io.open(new_script_path, "w")
		new_script:write(script_batch_content)
		new_script:close()

		-- Construct the GIMP batch command
		local cmd = string.format(
			'gimp-console-3.exe --batch-interpreter plug-in-script-fu-eval -i -b "(load \\\"%s\\\")" -b "(gimp-quit 0)"',
			escape_path(new_script_path)
		)
		logFile:write(cmd.."\n")

		if executeCommand then
			os.execute(cmd)
		end
	end

	logFile:close()
end

return module