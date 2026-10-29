-- 读取现有 CSV 词库，提供双向精确匹配和带编号占位符的整行转换。
local Dictionary = { }
Dictionary.__index = Dictionary

-- 模板只能把字面文本作为 Lua 模式使用，不能执行词库中的模式片段。
local function escape(text)
	return (text:gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1"))
end

-- 支持引号、双引号转义、逗号和引号内换行；CSV 没有必需的表头。
local function parseCSV(text, callback)
	text = text:gsub("^\239\187\191", "")
	local row, field, pos = { }, { }, 1
	local quoted = false
	while pos <= #text do
		local nextPos = text:find(quoted and '"' or '[,\r\n"]', pos)
		if not nextPos then field[#field + 1] = text:sub(pos); break end
		field[#field + 1] = text:sub(pos, nextPos - 1)
		local char = text:sub(nextPos, nextPos)
		pos = nextPos + 1
		if char == '"' then
			if quoted and text:sub(pos, pos) == '"' then
				field[#field + 1] = '"'; pos = pos + 1
			else quoted = not quoted end
		elseif not quoted then
			row[#row + 1] = table.concat(field); field = { }
			if char ~= ',' then
				if char == '\r' and text:sub(pos, pos) == '\n' then pos = pos + 1 end
				callback(row); row = { }
			end
		end
	end
	assert(not quoted, "CSV 引号未闭合")
	if #field > 0 or #row > 0 then row[#row + 1] = table.concat(field); callback(row) end
end

--- <summary>创建双向索引，冲突的反向词条不会静默选择其中一个。</summary>
function Dictionary.New()
	return setmetatable({ forward = { }, reverse = { }, ambiguous = { }, lower = { }, templates = { }, reverseTemplates = { }, count = 0 }, Dictionary)
end

-- 把编号占位符编译为整行模板，并保存原编号以支持译文调整顺序。
local function compile(source, target)
	local pattern, order, pos = { '^' }, { }, 1
	for first, number, last in source:gmatch('(){(%d+)}()') do
		pattern[#pattern + 1] = escape(source:sub(pos, first - 1))
		pattern[#pattern + 1] = '(.-)'; order[#order + 1] = number; pos = last
	end
	if #order == 0 then return end
	pattern[#pattern + 1] = escape(source:sub(pos)) .. '$'
	-- 用首个字面片段筛选，避免每个字符串遍历整套数万条模式。
	local prefix = source:match('^(.-){%d+}')
	return { pattern = table.concat(pattern), order = order, target = target, prefix = prefix, length = #source }
end

--- <summary>加入一条翻译；同名词条以最后加载的内容为准。</summary>
function Dictionary:Add(source, target)
	if not source or source == '' or not target or target == '' or source == target then return end
	if not self.forward[source] then self.count = self.count + 1 end
	self.forward[source] = target; self.lower[source:lower()] = target
	self.dirty = true
end

-- 按最终正向词条重建索引，避免覆盖后仍保留旧译文或旧模板。
local function rebuild(dictionary)
	if not dictionary.dirty then return end
	dictionary.reverse = { }; dictionary.ambiguous = { }; dictionary.templates = { }; dictionary.reverseTemplates = { }
	for source, target in pairs(dictionary.forward) do
		if dictionary.reverse[target] and dictionary.reverse[target] ~= source then
			local current = dictionary.reverse[target]
			if source == current .. 's' then
				-- 中文词库常把英文单复数合并，物品输入优先保留单数基底。
			elseif current == source .. 's' then
				dictionary.reverse[target] = source
			else
				dictionary.ambiguous[target] = true; dictionary.reverse[target] = nil
			end
		elseif not dictionary.ambiguous[target] then dictionary.reverse[target] = source end
		local template = compile(source, target)
		if template then dictionary.templates[#dictionary.templates + 1] = template end
		local reverse = compile(target, source)
		if reverse then dictionary.reverseTemplates[#dictionary.reverseTemplates + 1] = reverse end
	end
	table.sort(dictionary.templates, function(a, b) return a.length > b.length end)
	table.sort(dictionary.reverseTemplates, function(a, b) return a.length > b.length end)
	dictionary.dirty = false
end

--- <summary>从一个 CSV 文本加载词条，便于在实际运行与测试中共用解析器。</summary>
function Dictionary:LoadCSV(text)
	parseCSV(text, function(row) if #row >= 2 then self:Add(row[1], row[2]) end end)
end

--- <summary>按语言包提供的文件清单加载词库。</summary>
function Dictionary:LoadFiles(folder, files)
	for _, name in ipairs(files or { }) do
		local file = assert(io.open(folder .. '/' .. name, 'rb'))
		local text = file:read('*a'); file:close(); self:LoadCSV(text)
	end
	rebuild(self)
end

--- <summary>加载固定目录的词库清单；新增 CSV 后更新 Files.lua 即可。</summary>
function Dictionary:LoadFolder(folder)
	self:LoadFiles(folder, dofile(folder .. '/Files.lua'))
end

--- <summary>保留未知内容与颜色码，不翻译数据标识或零散单词片段。</summary>
function Dictionary:Translate(text, reverse)
	rebuild(self)
	local index = reverse and self.reverse or self.forward
	if index[text] then return index[text] end
	if not reverse and self.lower[text] then return self.lower[text] end
	if reverse and self.ambiguous[text] then return text end
	local colour, body = text:match('^(%^x%x%x%x%x%x%x)(.*)$')
	if not colour then colour, body = text:match('^(%^%d)(.*)$') end
	if colour then return colour .. self:Translate(body, reverse) end
	local result
	for _, template in ipairs(reverse and self.reverseTemplates or self.templates) do
		if template.prefix == '' or text:sub(1, #template.prefix) == template.prefix then
			local captures = { text:match(template.pattern) }
			if #captures == #template.order then
				local values, rawValues, valid = { }, { }, true
				for i, key in ipairs(template.order) do
					if rawValues[key] and rawValues[key] ~= captures[i] then valid = false end
					rawValues[key] = captures[i]
					-- 组合词条的动态片段也可能是技能名或属性名，先按独立词条转换。
					values[key] = self:Translate(captures[i])
				end
				if valid then
					local translated = template.target:gsub('{(%d+)}', function(key) return values[key] or '{' .. key .. '}' end)
					if not reverse then return translated end
					if result and result ~= translated then return text end
					result = translated
				end
			end
		end
	end
	-- 处理 PoB2 常见的“固定标签: 动态值”拼接，只允许词库中已有的固定标签。
	if not reverse then
		local prefix, separator, suffix = text:match('^(.-)(:%s+)(.+)$')
		if prefix and suffix then
			local translatedPrefix = self.forward[prefix] or self.lower[prefix:lower()]
			local prefixWithColon = false
			if not translatedPrefix then
				translatedPrefix = self.forward[prefix .. ':'] or self.lower[(prefix .. ':'):lower()]
				prefixWithColon = translatedPrefix ~= nil
			end
			if translatedPrefix then
				-- PoE2 常把“固定标签: 动态名称”拼成一行；名称本身仍需按独立词条转换。
				local translatedSuffix = self:Translate(suffix)
				if translatedSuffix ~= suffix then suffix = translatedSuffix end
				if prefixWithColon then return translatedPrefix:gsub('%s+$', '') .. ' ' .. suffix end
				return translatedPrefix .. separator .. suffix
			end
		end
	end
	return result or text
end

return Dictionary
