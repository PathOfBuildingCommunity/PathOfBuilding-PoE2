-- 读取现有 CSV 词库，提供双向精确匹配和带编号占位符的整行转换。
local Dictionary = { }
Dictionary.__index = Dictionary
local CSV = dofile('Modules/Localisation/CSV.lua')

-- 模板只能把字面文本作为 Lua 模式使用，不能执行词库中的模式片段。
local function escape(text)
	return (text:gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1"))
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
	local numeric = source:match('^{%d+}[%a%%]+$') or target:match('^{%d+}[%a%%]+$')
	return { pattern = table.concat(pattern), order = order, target = target, prefix = prefix, suffix = source:sub(pos), length = #source, numeric = numeric }
end

--- <summary>加入一条翻译；同名词条以最后加载的内容为准。</summary>
function Dictionary:Add(source, target)
	if not source or source == '' or not target or target == '' or source == target then return end
	if not self.forward[source] then self.count = self.count + 1 end
	self.forward[source] = target; self.lower[source:lower()] = target
	self.dirty = true
end

-- 模板只按较长的固定前缀或后缀入桶，避免未知文本逐条尝试数万次模式匹配。
local function indexTemplates(templates)
	local index = { prefixes = { }, suffixes = { }, lengths = { } }
	local lengths = { }
	for priority, template in ipairs(templates) do
		template.priority = priority
		local usePrefix = #template.prefix >= #template.suffix
		local literal = usePrefix and template.prefix or template.suffix
		local buckets = usePrefix and index.prefixes or index.suffixes
		buckets[literal] = buckets[literal] or { }
		table.insert(buckets[literal], template)
		lengths[#literal] = true
	end
	for length in pairs(lengths) do table.insert(index.lengths, length) end
	table.sort(index.lengths)
	return index
end

-- 候选仍按原模板顺序匹配，保持长模板优先与反向歧义检查。
local function matchingTemplates(index, text)
	local candidates = { }
	if not index then return candidates end
	for _, length in ipairs(index.lengths) do
		if length > #text then break end
		for _, template in ipairs(index.prefixes[text:sub(1, length)] or { }) do
			table.insert(candidates, template)
		end
		for _, template in ipairs(length > 0 and index.suffixes[text:sub(-length)] or { }) do
			table.insert(candidates, template)
		end
	end
	table.sort(candidates, function(a, b) return a.priority < b.priority end)
	return candidates
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
	dictionary.templateIndex = indexTemplates(dictionary.templates)
	dictionary.reverseTemplateIndex = indexTemplates(dictionary.reverseTemplates)
	dictionary.dirty = false
end

--- <summary>从一个 CSV 文本加载词条，便于在实际运行与测试中共用解析器。</summary>
function Dictionary:LoadCSV(text)
	CSV.Read(text, function(row) if #row >= 2 then self:Add(row[1], row[2]) end end)
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
	-- 提示框换行后会追加颜色重置码，译文匹配不应包含这些显示标记。
	local colourStart = text:match('()%^x%x%x%x%x%x%x$') or text:match('()%^%d$')
	if colourStart then return self:Translate(text:sub(1, colourStart - 1), reverse) .. text:sub(colourStart) end
	-- 显示片段常带缩进或分隔空格，保留布局但按完整词条查找。
	local leading, trimmed, trailing = text:match('^(%s*)(.-)(%s*)$')
	if trimmed ~= text then return leading .. self:Translate(trimmed, reverse) .. trailing end
	local result
	for _, template in ipairs(matchingTemplates(reverse and self.reverseTemplateIndex or self.templateIndex, text)) do
		if template.prefix == '' or text:sub(1, #template.prefix) == template.prefix then
			local captures = { text:match(template.pattern) }
			if #captures == #template.order then
				local values, rawValues, valid = { }, { }, true
				for i, key in ipairs(template.order) do
					if rawValues[key] and rawValues[key] ~= captures[i] then valid = false end
					-- 秒数等纯单位模板只接受数值，不能把 Requires 的末尾 s 当成秒。
					if template.numeric and (not captures[i]:find('%d') or captures[i]:find('[^%d%+%-%.%,%(%)%s/]')) then valid = false end
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
	-- 整句优先；未命中时再按换行和内部颜色边界翻译，避免附注阻断正文匹配。
	if not reverse and not result then
		if text:find('\n', 1, true) then
			return (text:gsub('[^\n]+', function(line) return self:Translate(line) end))
		end
		local parts, pos = { }, 1
		while pos <= #text do
			local first, last = text:find('%^x%x%x%x%x%x%x', pos)
			local shortFirst, shortLast = text:find('%^%d', pos)
			if shortFirst and (not first or shortFirst < first) then first, last = shortFirst, shortLast end
			if not first then break end
			parts[#parts + 1] = self:Translate(text:sub(pos, first - 1))
			parts[#parts + 1] = text:sub(first, last)
			pos = last + 1
		end
		if #parts > 0 then
			parts[#parts + 1] = self:Translate(text:sub(pos))
			return table.concat(parts)
		end
	end
	return result or text
end

return Dictionary
