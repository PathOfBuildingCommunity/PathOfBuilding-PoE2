-- 使用公开 poe.ninja 构筑对当前语言层做字段级回归扫描。
package.cpath = '../runtime/?.dll;' .. package.cpath
package.path = '../runtime/lua/?.lua;../runtime/lua/?/init.lua;' .. package.path
arg = { }
local read = io.read
io.read = function() error('审计禁止等待交互') end
dofile('HeadlessWrapper.lua')
io.read = read

local fixtures = { 'resurrectgodaura', 'goodnerfing', 'xxthewizardofosu' }
local output = assert(io.open('Tests/Run/poe-ninja-localisation-audit.txt', 'wb'))
local seen = { }
local total = 0
local currentLanguage = 'zh-CN'

local function add(kind, buildName, value, detail)
	if type(value) ~= 'string' or value == '' or not value:find('%a') then return end
	local translated = localisation:Translate(value)
	if translated ~= value then return end
	local key = currentLanguage .. '\t' .. kind .. '\t' .. value
	if seen[key] then return end
	seen[key] = true
	total = total + 1
	output:write(string.format('%s\t%s\t%s\t%s\t%s\n', currentLanguage, kind, buildName, detail or '', value))
end

local function scanItem(buildName, item)
	if item.rarity == 'UNIQUE' or item.rarity == 'RELIC' then
		add('item.unique-name', buildName, item.title or item.name, item.rarity)
	end
	add('item.base', buildName, item.baseName, item.rarity)
	for _, listName in ipairs({ 'enchantModLines', 'runeModLines', 'implicitModLines', 'explicitModLines', 'craftedModLines', 'fracturedModLines' }) do
		for _, modLine in ipairs(item[listName] or { }) do add('item.' .. listName, buildName, modLine.line, item.rarity) end
	end
	for _, property in ipairs(item.properties or { }) do
		add('item.property.name', buildName, property.name, item.rarity)
		for _, pair in ipairs(property.values or { }) do add('item.property.value', buildName, pair[1], item.rarity) end
	end
	for _, requirement in ipairs(item.requirements or { }) do
		add('item.requirement.name', buildName, requirement.name, item.rarity)
		for _, pair in ipairs(requirement.values or { }) do add('item.requirement.value', buildName, pair[1], item.rarity) end
	end
end

local function readAll(path)
	local file = assert(io.open(path, 'rb'))
	local text = file:read('*a')
	file:close()
	return text
end

for _, language in ipairs({ 'zh-CN', 'zh-TW' }) do
	currentLanguage = language
	localisation:SetLanguage(language)
	for _, fixture in ipairs(fixtures) do
		local xml = readAll('Tests/Fixtures/poe-ninja/' .. fixture .. '.xml')
		loadBuildFromXML(xml, 'poe.ninja ' .. fixture)
		for _, item in ipairs(build.itemsTab.items or { }) do scanItem(fixture, item) end
	end
end

output:write(string.format('\n总缺口候选: %d\n', total))
output:close()
print(string.format('poe.ninja 字段级审计完成：%d 个未命中候选，结果写入 Tests/Run/poe-ninja-localisation-audit.txt', total))
