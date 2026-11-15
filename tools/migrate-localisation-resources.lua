-- 仅把已定位显示调用的旧译文提取为 key 资源候选，不修改产品词库。
package.path = '../runtime/lua/?.lua;' .. package.path
io.stdout:setvbuf('no')
local json = require('dkjson')
local Dictionary = dofile('Modules/Localisation/Dictionary.lua')
-- 迁移批次会重复引用同名术语和句子，只缓存提取工具的正向查询。
local translate = Dictionary.Translate
function Dictionary:Translate(text, reverse)
	if reverse then return translate(self, text, reverse) end
	self.migrationCache = self.migrationCache or { }
	local cached = self.migrationCache[text]
	if cached ~= nil then return cached end
	local result = translate(self, text)
	self.migrationCache[text] = result
	return result
end
local file = assert(io.open('Tests/Run/key-migration-candidates.json', 'rb'))
local input = assert(json.decode(file:read('*a'))); file:close()
local result, seen = { }, { }
for _, entry in ipairs(input.resources or { }) do input.candidates[#input.candidates + 1] = entry end
local dictionaries = { }
for _, language in ipairs({ 'zh-CN', 'zh-TW' }) do
	local dictionary = Dictionary.New(); dictionary:LoadFolder('Locales/' .. language)
	dictionaries[language] = dictionary
end
for _, entry in ipairs(input.candidates) do
	if not seen[entry.key] then
		seen[entry.key] = true
		local names, byName, styles = { }, { }, { }
		for index, parameter in ipairs(entry.parameters) do
			local legacyIndex = parameter.legacyIndex or index - 1
			names[legacyIndex + 1] = parameter.name
			byName[parameter.name] = { index = legacyIndex, format = parameter.format, prefix = parameter.legacyPrefix }
			if parameter.expression:find('main:StatColor', 1, true) or parameter.expression:find('colorCodes', 1, true) then
				local code = string.format('^xF1%04X', index)
				byName[parameter.name].style = code
				styles[code] = parameter.name
			end
		end
		local source = entry.text:gsub('{([%a_][%w_]*):?[^{}]*}', function(name)
			local parameter = byName[name]
			return parameter and (parameter.style or (parameter.prefix or '') .. '{' .. parameter.index .. '}') or '{' .. name .. '}'
		end)
		local record = { key = entry.key, en = entry.text, translations = { }, rejected = { } }
		for language, dictionary in pairs(entry.skipExisting and { } or dictionaries) do
			local text = dictionary:Translate(source)
			if text == source and source:upper() == source then
				local lower = source:lower()
				local translated = dictionary:Translate(lower)
				if translated ~= lower then text = translated end
			end
			if text ~= source then
				local found, valid = { }, true
				if next(byName) then text = text:gsub('([%+%-]?){(%d+)}', function(sign, number)
					local name = names[tonumber(number) + 1]
					if not name then valid = false; return '{' .. number .. '}' end
					found[name] = true
					local format = byName[name].format
					return (byName[name].prefix and byName[name].prefix ~= '' and '' or sign) .. '{' .. name .. (format ~= '' and ':' .. format or '') .. '}'
				end) end
				for code, name in pairs(styles) do
					text = text:gsub('%' .. code, function()
						found[name] = true
						local format = byName[name].format
						return '{' .. name .. (format ~= '' and ':' .. format or '') .. '}'
					end)
				end
				for name in pairs(byName) do if not found[name] then valid = false end end
				if valid then record.translations[language] = text else record.rejected[language] = text end
			end
		end
		result[#result + 1] = record
		if #result % 1000 == 0 then print('译文提取进度: ' .. #result) end
	end
end
file = assert(io.open('Tests/Run/key-migration-translations.json', 'wb'))
file:write(json.encode(result)); file:close()
print(string.format('已提取 %d 个 key 的译文候选；资源写入前仍需参数和源码哈希校验。', #result))
