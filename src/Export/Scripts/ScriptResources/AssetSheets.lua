local assetSheets = { }

function assetSheets.extractSheetFiles(allSheets, is4kEnabled, extraFiles, cacheExtract)
	local filesToExtract = { }
	local seen = { }
	for _, sheet in ipairs(allSheets) do
		for icon in pairs(sheet.files) do
			if not seen[icon] then
				seen[icon] = true
				table.insert(filesToExtract, icon)
			end
			if is4kEnabled then
				local icon4k = icon:gsub("(.*/)([^/]+)$", "%14k/%2")
				if not seen[icon4k] then
					seen[icon4k] = true
					table.insert(filesToExtract, icon4k)
				end
			end
		end
	end
	if extraFiles then
		for _, file in ipairs(extraFiles) do
			if not seen[file] then
				seen[file] = true
				table.insert(filesToExtract, file)
			end
		end
	end
	if #filesToExtract > 0 then
		main.ggpk:ExtractList(filesToExtract, cacheExtract)
	end
end

function assetSheets.newSheet(name, startWidth, saturation)
	return {
		name = name,
		startWidth = startWidth,
		saturation = saturation,
		sprite = { },
		files = { },
	}
end

function assetSheets.addToSheet(sheet, icon, section, metadata)
	sheet.files[icon] = sheet.files[icon] or { }
	if sheet.files[icon][section] then
		if metadata.alias then
			for _, meta in pairs(sheet.files[icon][section]) do
				if meta.alias == metadata.alias then
					return
				end
			end
		else
			for _, meta in pairs(sheet.files[icon][section]) do
				if meta.alias == nil then
					return
				end
			end
		end
	end
	sheet.files[icon][section] = sheet.files[icon][section] or { }
	table.insert(sheet.files[icon][section], metadata)
end

function assetSheets.calculateDDSPack(sheet, fromBase, toBase, is4kEnabled)
	local stackTextures = { }
	local ddsCoords = { }

	for icon, sections in pairsSortByKey(sheet.files) do
		local tex = Texture.new()
		local rc
		if is4kEnabled then
			local icon4k = icon:gsub("(.*/)([^/]+)$", "%14k/%2")
			rc = tex:Load(fromBase .. string.lower(icon4k))
		end
		if not rc then
			rc = tex:Load(fromBase .. string.lower(icon))
		end

		local info = tex:Info()
		local ident = string.format("%d_%d_%s", info.width, info.height, info.formatStr)

		stackTextures[ident] = stackTextures[ident] or { }
		table.insert(stackTextures[ident], {
			tex = tex,
			icon = icon,
			sections = sections,
		})
	end

	for ident, stackInfo in pairsSortByKey(stackTextures) do
		local stacks = { }
		local file = sheet.name .. "_" .. ident .. ".dds.zst"
		ddsCoords[file] = { }
		for position, stack in ipairs(stackInfo) do
			for _, metadata in pairs(stack.sections) do
				for _, meta in ipairs(metadata) do
					local icon = meta.alias or stack.icon
					ddsCoords[file][icon] = position
				end
			end
			table.insert(stacks, stack.tex)
		end
		local stackTex = Texture.new()
		stackTex:StackTextures(stacks)
		stackTex:Save(toBase .. file)
	end
	sheet.ddsCoords = ddsCoords
end

function assetSheets.parseUIImages(file)
	local text
	if main.ggpk.txt[file] then
		text = main.ggpk.txt[file]
	else
		text = convertUTF16to8(getFile(file))
		main.ggpk.txt[file] = text
	end

	local images = { }
	for line in text:gmatch("[^\r\n]+") do
		local index = 0
		local name = ""
		for field in line:gmatch('"?([^%s"]+)"?') do
			if index == 0 then
				name = string.lower(field)
				images[name] = { }
			elseif index == 1 then
				images[name].path = string.lower(field)
			elseif index == 2 then
				images[name].x = tonumber(field)
			elseif index == 3 then
				images[name].y = tonumber(field)
			elseif index == 4 then
				images[name].width = tonumber(field)
			elseif index == 5 then
				images[name].height = tonumber(field)
			end
			index = index + 1
		end
	end
	return images
end

return assetSheets
