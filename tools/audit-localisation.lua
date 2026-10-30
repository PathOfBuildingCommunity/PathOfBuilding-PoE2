-- 全域数据与源码候选审计；按真实翻译输出报告，不把词库条数当作覆盖率。
package.cpath = '../runtime/?.dll;' .. package.cpath
package.path = '../runtime/lua/?.lua;../runtime/lua/?/init.lua;' .. package.path
arg = { }
io.stdout:setvbuf('no')
io.read = function() error('审计禁止等待交互') end
dofile('HeadlessWrapper.lua')
assert(build and not launch.promptMsg, 'PoB2 审计初始化失败')
main.userPath = 'Tests/Run/'

local input = assert(io.open('Tests/Run/localisation-audit-input.json', 'rb'), '请运行 python tools/audit-localisation.py')
local manifest = assert(require('dkjson').decode(input:read('*a')))
input:close()
local records, indexed = { }, { }

-- 同一数据域内按英文文本去重，并保留引用次数和首个定位供补录。
local function add(domain, origin, text)
	if type(text) ~= 'string' or not StripEscapes(text):find('%a') then return end
	local key = domain .. '\0' .. text
	if indexed[key] then indexed[key].count = indexed[key].count + 1; return end
	local record = { domain = domain, origin = tostring(origin), text = text, count = 1 }
	indexed[key] = record; records[#records + 1] = record
end

local nodes = 0
for id, node in pairs(build.spec.nodes) do
	nodes = nodes + 1
	add('tree.name', id, node.dn)
	add('tree.ascendancy', id, node.ascendancyName)
	for _, line in ipairs(node.sd or { }) do add('tree.stat', id, line) end
	for _, line in ipairs(node.reminderText or { }) do add('tree.reminder', id, line) end
	add('tree.flavour', id, node.flavourText)
end
for id, class in pairs(build.spec.tree.classes) do
	add('tree.class', id, class.name)
end
for name, base in pairs(data.itemBases) do
	add('item.base', name, name:gsub(' %(.+%)', ''))
	add('item.type', name, base.type)
	add('item.subtype', name, base.subType)
	if type(base.implicit) == 'table' then
		for _, line in ipairs(base.implicit) do add('item.implicit', name, line) end
	else add('item.implicit', name, base.implicit) end
end
for kind, list in pairs(data.uniques) do
	for index, raw in ipairs(list) do
		local item = new('Item'):Item(raw, 'UNIQUE')
		local origin = kind .. ':' .. index
		add('item.unique', origin, item.title)
		for _, field in ipairs({ 'enchantModLines', 'runeModLines', 'implicitModLines', 'explicitModLines' }) do
			for _, line in ipairs(item[field] or { }) do add('item.unique-mod', origin, line.line) end
		end
	end
end
for kind, mods in pairs(data.itemMods) do
	for id, mod in pairs(mods) do
		add('item.affix-name', kind .. ':' .. id, mod.affix)
		for _, line in ipairs(mod) do add('item.mod', kind .. ':' .. id, line) end
	end
end
for id, gem in pairs(data.gems) do
	add('gem.name', id, gem.name)
	add('gem.type', id, gem.gemType)
	for tag in (gem.tagString or ''):gmatch('[^,]+') do add('gem.tag', id, tag:match('^%s*(.-)%s*$')) end
end
for id, skill in pairs(data.skills) do
	add('skill.name', id, skill.name)
	add('skill.description', id, skill.description)
end
for id, minion in pairs(data.minions) do
	add('minion.name', id, minion.name)
	add('minion.category', id, minion.monsterCategory)
end
for id, flavour in ipairs(data.flavourText) do
	add('flavour.name', id, flavour.name)
	for _, line in ipairs(flavour.text or { }) do add('flavour.text', id, line) end
end
for index, option in ipairs(LoadModule('Modules/ConfigOptions')) do
	local origin = option.var or index
	for _, field in ipairs({ 'label', 'section', 'tooltip' }) do add('config.' .. field, origin, option[field]) end
	for _, entry in ipairs(option.list or { }) do add('config.option', origin, entry.label) end
end

-- 属性描述只提取显示模板，不翻译 stats 内部键、条件、范围和哈希。
local function statTexts(value, origin)
	if type(value) ~= 'table' then return end
	add('stat.template', origin, value.text)
	for _, child in pairs(value) do if type(child) == 'table' then statTexts(child, origin) end end
end
-- 计算页的静态显示字段以前只出现在未分类源码中；现在按实际加载对象审计。
local function displayFields(value, origin)
	if type(value) ~= 'table' then return end
	for key, child in pairs(value) do
		local location = origin .. '.' .. tostring(key)
		if key == 'label' or key == 'title' or key == 'tooltip' or key == 'text' or key == 'suffix' then
			add('calcs.' .. key, location, child)
		end
		if type(child) == 'table' then displayFields(child, location) end
	end
end
displayFields(LoadModule('Modules/CalcSections'), 'Modules/CalcSections')
displayFields(build.displayStats, 'Modules/BuildDisplayStats.player')
displayFields(build.minionDisplayStats, 'Modules/BuildDisplayStats.minion')
for _, path in ipairs(manifest.statFiles) do statTexts(LoadModule(path), path) end
for _, entry in ipairs(manifest.literals) do
	local decode = assert(loadstring('return ' .. entry.literal), entry.origin)
	add('source.literal-review', entry.origin, decode())
end
table.sort(records, function(a, b)
	if a.domain ~= b.domain then return a.domain < b.domain end
	return a.text < b.text
end)

local function csv(value)
	return '"' .. tostring(value):gsub('"', '""') .. '"'
end
local output = assert(io.open('../docs/localisation-runtime-missing.csv', 'wb'))
output:write('language,domain,status,origin,references,source,translation\n')
local report = assert(io.open('../docs/localisation-runtime-audit.md', 'wb'))
report:write('# PoB2 全域本地化审计\n\n')
report:write('本次重新生成：2026-10-30，装备显示修复之后。\n\n运行范围：当前 PoB2 运行时、' .. nodes .. ' 个天赋节点、全部装备/技能/召唤物数据、配置和计算页静态显示字段及 ' .. #manifest.statFiles .. ' 个属性描述文件。源码候选覆盖 ' .. #manifest.sourceFiles .. ' 个 Lua 文件。全仓逐文件范围见 `localisation-repository-inventory.csv`；历史树、未加载数据、二进制原生界面与导出/开发工具没有冒充已运行验收。\n\n')
report:write('命令：在工程根目录运行 `build.cmd`，然后 `python tools/audit-localisation.py`。\n\n')
report:write('“回退”表示输出仍为原英文；“含拉丁字母”表示输出有变化但仍需复核，可能是未翻译片段，也可能是专名、快捷键或格式符。无拉丁字母同样不证明译名准确。统计按数据域内唯一文本计数，明细保留引用次数与定位。\n\n')
report:write('`source.literal-review` 递归枚举 Classes、Modules 及 src 根目录全部 Lua 的字符串常量（排除注释），包含内部键、路径、调试文字和用户文案；仅作为防漏候选，状态固定为 unclassified，不进行翻译命中统计。函数生成文案与未触发的界面交互仍需真实窗口验收。\n\n')
report:write('| 语言 | 数据域 | 唯一文本 | 回退英文 | 含拉丁字母待复核 | 其余已变化 | 源码待分类 |\n|---|---|---:|---:|---:|---:|---:|\n')
for _, language in ipairs({ 'zh-CN', 'zh-TW' }) do
	localisation:SetLanguage(language)
	local summaries = { }
	local translations = { }
	local previousDomain
	for _, record in ipairs(records) do
		if previousDomain ~= record.domain then
			print(language .. ' 扫描 ' .. record.domain)
			previousDomain = record.domain
		end
		local translated, status = record.text, 'unclassified'
		if record.domain ~= 'source.literal-review' then
			translated = translations[record.text] or localisation:Translate(record.text)
			translations[record.text] = translated
			status = translated == record.text and 'fallback' or StripEscapes(translated):find('%a') and 'latin-review' or 'changed'
		end
		local summary = summaries[record.domain] or { total = 0, fallback = 0, ['latin-review'] = 0, changed = 0, unclassified = 0 }
		summaries[record.domain] = summary
		summary.total = summary.total + 1; summary[status] = summary[status] + 1
		if status ~= 'changed' then
			local values = { language, record.domain, status, record.origin, record.count, record.text, translated }
			for i, value in ipairs(values) do values[i] = csv(value) end
			output:write(table.concat(values, ',') .. '\n')
		end
	end
	local domains = { }
	for domain in pairs(summaries) do domains[#domains + 1] = domain end
	table.sort(domains)
	for _, domain in ipairs(domains) do
		local s = summaries[domain]
		report:write(string.format('| %s | %s | %d | %d | %d | %d | %d |\n', language, domain, s.total, s.fallback, s['latin-review'], s.changed, s.unclassified))
	end
	print(language .. ' 全域扫描完成：' .. #records .. ' 个唯一文本候选（含源码待核对项）')
end
report:write('\n缺口与复核明细：`localisation-runtime-missing.csv`。历史装备样本审计不能替代本报告，当前仍未完成全量中文化。\n')
report:close(); output:close()
print('报告已写入 docs/localisation-runtime-audit.md 和 docs/localisation-runtime-missing.csv')
