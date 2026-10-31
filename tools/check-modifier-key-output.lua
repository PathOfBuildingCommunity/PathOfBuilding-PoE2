-- 对照未接入显示 key 的原格式算法，审计已知装备词缀的引用及数值输出。
package.cpath = '../runtime/?.dll;' .. package.cpath
package.path = '../runtime/lua/?.lua;../runtime/lua/?/init.lua;' .. package.path
arg = { }
io.read = function() error('装备验证禁止等待交互') end
dofile('HeadlessWrapper.lua')
assert(build and not launch.promptMsg, 'PoB2 初始化失败')
localisation:SetLanguage('en')
local json = require('dkjson')
local file = assert(io.open('Modules/ItemTools.lua', 'rb'))
local source = file:read('*a'); file:close()
local body = assert(source:match('function itemLib%.formatModLine(.-)\nend'))
body = body:gsub('\n\tline = localisation:ModLine%(modLine, line%)', '')
local before = assert(loadstring('return function' .. body .. '\nend'))()
local count, bound, missing, branches = 0, 0, { }, { }
local LineTemplates = dofile('Modules/Localisation/LineTemplates.lua')

-- 同一原行在数据库、实际范围、增效和禁用状态下保留原英文格式。
local function check(modLine, identity)
	if modLine.displayReferences and #modLine.displayReferences > 0 then bound = bound + 1
	else missing[#missing + 1] = { id = identity, text = modLine.line } end
	for _, mode in ipairs({ true, false }) do
		for _, range in ipairs({ 0, 0.5, 1 }) do
			local copy = copyTable(modLine)
			copy.range = range
			local expected = before(copy, mode)
			local actual = itemLib.formatModLine(copy, mode)
			if expected then
				local text = mode and copy.line or itemLib.applyRange(copy.line, range, copy.valueScalar, copy.corruptedRange)
				local matched = false
				for _, reference in ipairs(copy.displayReferences or { }) do
					if LineTemplates.Parameters(reference, text) then matched = true; break end
				end
				if not matched then branches[#branches + 1] = { id = identity, text = text, database = mode, range = range } end
			end
			assert(expected == actual, identity .. ': 英文词缀发生变化\n' .. tostring(expected) .. '\n' .. tostring(actual))
			count = count + 1
		end
	end
end
for kind, list in pairs(data.uniques) do
	for _, raw in ipairs(list) do
		local item = new('Item'):Item(raw, 'UNIQUE')
		for _, field in ipairs({ 'enchantModLines', 'runeModLines', 'implicitModLines', 'explicitModLines' }) do
			for index, modLine in ipairs(item[field]) do check(modLine, kind .. ':' .. item.name .. ':' .. field .. ':' .. index) end
		end
	end
end
file = assert(io.open('Tests/Run/modifier-key-missing.json', 'wb'))
file:write(json.encode(missing)); file:close()
print('装备英文对照通过 ' .. count .. ' 个状态；已绑定 ' .. bound .. ' 行，未绑定 ' .. #missing .. ' 行。')
file = assert(io.open('Tests/Run/modifier-key-branches-missing.json', 'wb'))
file:write(json.encode(branches)); file:close()
print('实际显示分支未匹配绑定引用: ' .. #branches)
