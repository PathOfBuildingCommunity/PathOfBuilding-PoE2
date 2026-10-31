-- 按稳定 key 加载显示资源；模板参数不依赖英文句子的匹配结果。
local CSV = dofile('Modules/Localisation/CSV.lua')
local Messages = { }
Messages.__index = Messages
local reference = { }

--- <summary>创建显式的嵌套文案引用，使参数随外层句子使用同一语言。</summary>
function Messages.Ref(key, parameters)
	return setmetatable({ key = key, parameters = parameters }, reference)
end

-- 编译命名参数并核对同一个参数的格式；双花括号表示字面花括号。
local function compile(text, key)
	local parts, parameters, pos = { }, { }, 1
	while pos <= #text do
		local first = text:find('[{}]', pos)
		if not first then parts[#parts + 1] = text:sub(pos); break end
		if first > pos then parts[#parts + 1] = text:sub(pos, first - 1) end
		local char = text:sub(first, first)
		if text:sub(first + 1, first + 1) == char then
			parts[#parts + 1] = char; pos = first + 2
		else
			assert(char == '{', '模板花括号未配对: ' .. key)
			local last = assert(text:find('}', first + 1, true), '模板花括号未配对: ' .. key)
			local field = text:sub(first + 1, last - 1)
			local name, format = field:match('^([%a_][%w_]*):(.+)$')
			if not name then name, format = field, '' end
			assert(name:match('^[%a_][%w_]*$'), '模板参数名无效: ' .. key .. ' / ' .. name)
			assert(format == '' or format:match('^[%+%-% #0%d%.]*[sdiufFeEgGxXoc]$'), '模板参数格式无效: ' .. key .. ' / ' .. name)
			assert(not parameters[name] or parameters[name] == format, '同名参数格式不一致: ' .. key .. ' / ' .. name)
			parameters[name] = format
			parts[#parts + 1] = { name = name, format = format }
			pos = last + 1
		end
	end
	return { parts = parts, parameters = parameters, text = text }
end

--- <summary>创建以英文为最终回退的独立显示资源表。</summary>
function Messages.New()
	return setmetatable({ languages = { } }, Messages)
end

--- <summary>加载严格双列 key 与模板资源，重复 key 和无效参数立即报告来源。</summary>
function Messages:LoadCSV(language, text, origin)
	local entries = self.languages[language] or { }
	self.languages[language] = entries
	local rowNumber = 0
	CSV.Read(text, function(row)
		rowNumber = rowNumber + 1
		if #row == 1 and row[1] == '' then return end
		if rowNumber == 1 and row[1] == 'key' and row[2] == 'text' then return end
		local location = (origin or language) .. ':' .. rowNumber
		assert(#row == 2, '显示资源必须有两列: ' .. location)
		local key, value = row[1], row[2]
		-- Git 检出和归档可改变 CSV 内嵌换行，显示模板统一使用 LF。
		value = value:gsub('\r\n', '\n')
		assert(key:match('^[a-z][a-z0-9_]*[%.a-z0-9_]*$') and not key:find('%.%.') and key:sub(-1) ~= '.', '显示 key 无效: ' .. location)
		assert(not entries[key], '显示 key 重复: ' .. key .. ' / ' .. location)
		assert(value ~= '', '显示资源为空: ' .. key .. ' / ' .. location)
		entries[key] = compile(value, key)
	end)
end

--- <summary>加载已声明的显示资源文件，缺失文件保留可定位错误。</summary>
function Messages:LoadFiles(language, folder, files)
	for _, name in ipairs(files or { }) do
		local path = folder .. '/' .. name
		local file = assert(io.open(path, 'rb'), '显示资源文件不存在: ' .. path)
		local text = file:read('*a'); file:close()
		self:LoadCSV(language, text, path)
	end
end

--- <summary>核对所有译文具有英文定义和完全一致的命名参数及格式。</summary>
function Messages:Validate()
	local english = assert(self.languages.en, '缺少英文显示资源')
	for language, entries in pairs(self.languages) do
		for key, entry in pairs(entries) do
			local source = assert(english[key], '译文没有英文 key: ' .. language .. ' / ' .. key)
			for name, format in pairs(source.parameters) do
				assert(entry.parameters[name] == format, '译文缺少参数或格式不一致: ' .. language .. ' / ' .. key .. ' / ' .. name)
			end
			for name in pairs(entry.parameters) do
				assert(source.parameters[name] ~= nil, '译文多出参数: ' .. language .. ' / ' .. key .. ' / ' .. name)
			end
		end
	end
end

--- <summary>按 key 和回退链生成完整句子，参数缺失或多余时报告用途。</summary>
function Messages:Text(key, parameters, languages)
	local english = self.languages.en
	local entry = assert(english and english[key], '未知显示 key: ' .. tostring(key))
	for _, language in ipairs(languages or { }) do
		local translated = self.languages[language] and self.languages[language][key]
		if translated then entry = translated; break end
	end
	parameters = parameters or { }
	for name in pairs(entry.parameters) do
		assert(parameters[name] ~= nil, '缺少显示参数: ' .. key .. ' / ' .. name)
	end
	for name in pairs(parameters) do
		assert(entry.parameters[name] ~= nil, '多余显示参数: ' .. key .. ' / ' .. tostring(name))
	end
	local result = { }
	for index, part in ipairs(entry.parts) do
		if type(part) == 'string' then
			result[index] = part
		else
			local value = parameters[part.name]
			if type(value) == 'table' and getmetatable(value) == reference then
				value = self:Text(value.key, value.parameters, languages)
			end
			if part.format == '' then
				result[index] = tostring(value)
			else
				local ok, formatted = pcall(string.format, '%' .. part.format, value)
				assert(ok, '显示参数无法格式化: ' .. key .. ' / ' .. part.name .. ' / ' .. tostring(formatted))
				result[index] = formatted
			end
		end
	end
	return table.concat(result)
end

return Messages
