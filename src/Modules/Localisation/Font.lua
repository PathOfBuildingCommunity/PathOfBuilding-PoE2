-- 在官方图像 API 上绘制 Unicode 字体，布局结果同时用于测宽和字节光标。
local Font = { }
Font.__index = Font

local function fileExists(path)
	local file = io.open(path, "rb")
	if file then file:close(); return true end
	return false
end

local function shellQuote(value)
	return '"' .. value:gsub('"', '\\"') .. '"'
end

local function resolveFontFile(spec)
	local fontFile = spec.fontFileEnv and os.getenv(spec.fontFileEnv)
	if not fontFile or fontFile == "" then fontFile = spec.fontFile end
	if not fontFile or fontFile == "" then return nil end
	if fileExists(fontFile) then return fontFile end
	local scriptPath = GetScriptPath and GetScriptPath()
	if scriptPath then
		for _, prefix in ipairs({ scriptPath, scriptPath .. "/.." }) do
			local candidate = prefix .. "/" .. fontFile
			if fileExists(candidate) then return candidate end
		end
	end
	return fontFile
end

local function findGenerator()
	local candidates = { }
	local scriptPath = GetScriptPath and GetScriptPath()
	if scriptPath then
		candidates[#candidates + 1] = scriptPath .. "/../tools/FontAtlas.exe"
		candidates[#candidates + 1] = scriptPath .. "/tools/FontAtlas.exe"
	end
	local runtimePath = GetRuntimePath and GetRuntimePath()
	if runtimePath then candidates[#candidates + 1] = runtimePath .. "/FontAtlas.exe" end
	for _, path in ipairs(candidates) do
		if fileExists(path) then return path end
	end
end

local function ensureGenerated(folder, spec)
	if folder and fileExists(folder .. "/Glyphs.lua") then return folder end
	if not spec or not spec.cache or not spec.face then return nil end
	local output = spec.cache
	local userPath = GetUserPath and GetUserPath()
	if userPath then output = userPath .. "/Path of Building (PoE2)/" .. output end
	if fileExists(output .. "/Glyphs.lua") then return output end
	local generator = findGenerator()
	if not generator or not MakeDir then return nil end
	local ok = pcall(function()
		MakeDir(output)
		local command = shellQuote(generator) .. " " .. shellQuote(output) .. " " .. shellQuote(spec.face)
		local fontFile = resolveFontFile(spec)
		if fontFile then command = command .. " " .. shellQuote(fontFile) end
		os.execute(command)
	end)
	return ok and fileExists(output .. "/Glyphs.lua") and output or nil
end

-- 解析 UTF-8 单个码点；无效字节显示替代字形并保持字节位置可预测。
local function codepoint(text, pos)
	local first = text:byte(pos)
	if first < 128 then return first, pos + 1 end
	local length = first >= 240 and 4 or first >= 224 and 3 or first >= 194 and 2 or 1
	local value = first % (2 ^ (7 - length))
	for i = 1, length - 1 do
		local byte = text:byte(pos + i)
		if not byte or byte < 128 or byte > 191 then return 63, pos + 1 end
		value = value * 64 + byte - 128
	end
	return length == 1 and 63 or value, pos + length
end

--- <summary>字形图集按需载入；缺失时为配置语言生成并缓存图集。</summary>
function Font.New(folder, spec)
	folder = ensureGenerated(folder, spec)
	if not folder or not fileExists(folder .. "/Glyphs.lua") then return nil end
	return setmetatable({ folder = folder, metrics = dofile(folder .. '/Glyphs.lua'), pages = { }, cache = { }, cacheSize = 0 }, Font)
end

--- <summary>构造共享布局；颜色码不占宽度，索引始终对应原字符串的字节。</summary>
function Font:Layout(height, text)
	local key = height .. '\0' .. text
	if self.cache[key] then return self.cache[key] end
	local result = { lines = { }, width = 0 }
	local line = { tokens = { }, width = 0, start = 1 }
	result.lines[1] = line
	local pos, scale = 1, height / self.metrics.size
	while pos <= #text do
		local colour = text:sub(pos):match('^(%^x%x%x%x%x%x%x)') or text:sub(pos):match('^(%^%d)')
		if colour then
			line.tokens[#line.tokens + 1] = { colour = colour, first = pos, after = pos + #colour, x = line.width }
			pos = pos + #colour
		else
			local first = pos
			local cp; cp, pos = codepoint(text, pos)
			if cp == 10 then
				line.after = first; result.width = math.max(result.width, line.width)
				line = { tokens = { }, width = 0, start = pos }; result.lines[#result.lines + 1] = line
			else
				local glyph = self.metrics.glyphs[cp] or self.metrics.glyphs[63]
				local advance = cp == 9 and self.metrics.glyphs[32][8] * scale * 4 or glyph[8] * scale
				line.tokens[#line.tokens + 1] = { glyph = cp ~= 9 and glyph or nil, first = first, after = pos, x = line.width, advance = advance }
				line.width = line.width + advance
			end
		end
	end
	line.after = #text + 1; result.width = math.max(result.width, line.width)
	if self.cacheSize >= 4096 then self.cache = { }; self.cacheSize = 0 end
	self.cache[key] = result; self.cacheSize = self.cacheSize + 1
	return result
end

--- <summary>返回光标前的字节索引，与官方 DrawStringCursorIndex 的一基索引一致。</summary>
function Font:Cursor(height, text, x, y)
	local layout = self:Layout(height, text)
	local index = math.max(1, math.min(#layout.lines, math.floor(y / height) + 1))
	local line = layout.lines[index]
	for _, token in ipairs(line.tokens) do
		if token.advance and x < token.x + token.advance / 2 then return token.first end
	end
	return line.after
end

--- <summary>按共享布局绘制，复用宿主当前颜色、裁剪、图层和虚拟屏幕坐标。</summary>
function Font:Draw(left, top, align, height, text)
	local layout, scale = self:Layout(height, text), height / self.metrics.size
	local screenWidth = (GetVirtualScreenSize or GetScreenSize)()
	for row, line in ipairs(layout.lines) do
		local x = left
		if align == 'CENTER' then x = (screenWidth - line.width) / 2 + left
		elseif align == 'RIGHT' then x = screenWidth - line.width - left
		elseif align == 'CENTER_X' then x = left - line.width / 2
		elseif align == 'RIGHT_X' then x = left - line.width end
		for _, token in ipairs(line.tokens) do
			if token.colour then SetDrawColor(token.colour)
			elseif token.glyph then
				local glyph, page = token.glyph, self.pages[token.glyph[1]]
				if not page then
					page = NewImageHandle(); page:Load(string.format('%s/atlas-%02d.tga', self.folder, glyph[1]), 'CLAMP')
					self.pages[glyph[1]] = page
				end
				if glyph[4] > 0 and glyph[5] > 0 then
					DrawImage(page, math.floor(x + token.x + glyph[6] * scale), top + (row - 1) * height + (self.metrics.baseline - glyph[7]) * scale,
						glyph[4] * scale, glyph[5] * scale, glyph[2] / self.metrics.atlasSize, glyph[3] / self.metrics.atlasSize,
						(glyph[2] + glyph[4]) / self.metrics.atlasSize, (glyph[3] + glyph[5]) / self.metrics.atlasSize)
				end
			end
		end
	end
end

return Font
