-- 按当前对象的稳定引用检查全部配置、计算字段和游戏显示字段，包含未被空构筑触发的选项。
package.cpath = '../runtime/?.dll;' .. package.cpath
package.path = '../runtime/lua/?.lua;../runtime/lua/?/init.lua;' .. package.path
arg = { }
io.stdout:setvbuf('no')
io.read = function() error('审计禁止等待交互') end
dofile('HeadlessWrapper.lua')
assert(build and not launch.promptMsg, 'PoB2 初始化失败')
main.userPath = 'Tests/Run/'
-- 直接检查稳定字段引用，显示层没有词典兜底。
local records = { }
local function field(domain, origin, object, name)
	if type(object[name]) ~= 'string' or not object[name]:find('%a') then return end
	records[#records + 1] = { domain = domain, origin = origin, key = object[name .. 'Key'], source = object[name], resolve = function() return localisation:Field(object, name) end }
end
-- 递归读取明确的显示字段，不能把计算字段和业务枚举当成界面文案。
local function displayFields(domain, object, origin, visited)
	if type(object) ~= 'table' or visited[object] then return end
	visited[object] = true
	for _, name in ipairs({ 'label', 'section', 'title', 'tooltip', 'text', 'suffix' }) do field(domain .. '.' .. name, origin .. '.' .. name, object, name) end
	for key, value in pairs(object) do
		if type(value) == 'table' then displayFields(domain, value, origin .. '.' .. tostring(key), visited) end
	end
end
displayFields('config', LoadModule('Modules/ConfigOptions'), 'ConfigOptions', { })
displayFields('calcs', LoadModule('Modules/CalcSections'), 'CalcSections', { })
displayFields('sidebar.player', build.displayStats, 'BuildDisplayStats.player', { })
displayFields('sidebar.minion', build.minionDisplayStats, 'BuildDisplayStats.minion', { })
for id, skill in pairsSortByKey(data.skills) do
	field('skill.name', id, skill, 'name')
	field('skill.description', id, skill, 'description')
end
for id, gem in pairsSortByKey(data.gems) do
	for _, name in ipairs({ 'name', 'tagString', 'gemFamily' }) do field('gem.' .. name, id, gem, name) end
end
for id, minion in pairsSortByKey(data.minions) do
	field('minion.name', id, minion, 'name')
	field('minion.category', id, minion, 'monsterCategory')
end
for id, node in pairsSortByKey(build.spec.nodes) do
	field('tree.name', id, node, 'dn')
	field('tree.flavour', id, node, 'flavourText')
	for _, name in ipairs({ 'sd', 'reminderText' }) do
		for index, text in ipairs(node[name] or { }) do
			local object, slot, lineIndex = node, name, index
			records[#records + 1] = { domain = 'tree.' .. name, origin = id .. ':' .. index, source = text,
				key = node[name .. 'Display'] and node[name .. 'Display'][index] and node[name .. 'Display'][index].key,
				resolve = function() return localisation:Line(object, slot, lineIndex) end }
		end
	end
end
local output = assert(io.open('Tests/Run/localisation-field-review.csv', 'wb'))
output:write('language,domain,status,origin,key,source,display\n')
local summaries = { }
local function quote(value) return '"' .. tostring(value or ''):gsub('"', '""') .. '"' end
for _, language in ipairs({ 'en', 'zh-CN', 'zh-TW' }) do
	localisation:SetLanguage(language)
	local seen = { }
	for _, row in ipairs(records) do
		local ok, text = pcall(row.resolve)
		local status = not ok and 'error' or type(text) ~= 'string' and 'non-string' or language == 'en' and 'baseline'
			or text == row.source and 'unchanged' or StripEscapes(text):find('%a') and 'latin-review' or 'changed'
		local identity = row.domain .. '\0' .. (row.key or row.source)
		if not seen[identity] then
			seen[identity] = true
			local counts = summaries[language .. '|' .. row.domain] or { total = 0 }
			summaries[language .. '|' .. row.domain] = counts
			counts.total = counts.total + 1; counts[status] = (counts[status] or 0) + 1
		end
		if status ~= 'changed' and status ~= 'baseline' then
			output:write(table.concat({ quote(language), quote(row.domain), quote(status), quote(row.origin), quote(row.key), quote(row.source), quote(text) }, ',') .. '\n')
		end
	end
	print(language .. ' 已检查 ' .. #records .. ' 个显示字段引用')
end
output:close()
local file = assert(io.open('Tests/Run/localisation-field-summary.json', 'wb'))
file:write(require('dkjson').encode(summaries, { indent = true })); file:close()
for domain, counts in pairs(summaries) do assert(not counts.error, domain .. ' 字段解析异常，见审计 CSV') end
