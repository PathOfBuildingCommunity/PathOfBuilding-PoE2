-- 从真实业务对象提取显示字段；身份使用原有 ID，不合并同文的不同对象。
package.cpath = '../runtime/?.dll;' .. package.cpath
package.path = '../runtime/lua/?.lua;../runtime/lua/?/init.lua;' .. package.path
arg = { }
io.read = function() error('资源提取禁止等待交互') end
dofile('HeadlessWrapper.lua')
assert(build and not launch.promptMsg, 'PoB2 初始化失败')
local records = { }
local seen = { }
local LineTemplates = dofile('Modules/Localisation/LineTemplates.lua')

-- 保留表的域、身份和显示字段，参数模板由独立迁移器生成。
local function add(domain, id, object, fields)
	for _, field in ipairs(fields) do
		local value = object[field]
		if type(value) == 'string' and value ~= '' then
			local identity = domain .. ':' .. tostring(id) .. ':' .. field
			if not seen[identity] then
				seen[identity] = value
				records[#records + 1] = { domain = domain, id = tostring(id), field = field, text = value }
			else assert(seen[identity] == value, '显示字段身份冲突: ' .. identity) end
		end
	end
end

-- 多行属性按原业务对象和行号建引用；数值独立成命名参数。
local function addLines(domain, id, object, field)
	for index, text in ipairs(object[field] or { }) do
		if text ~= '' then
			local template, values = LineTemplates.Compile(text)
			local parameters = { }
			for name in pairs(values) do parameters[#parameters + 1] = { name = name, expression = name, format = '', legacyIndex = tonumber(name:match('%d+')) - 1 } end
			table.sort(parameters, function(a, b) return a.legacyIndex < b.legacyIndex end)
			records[#records + 1] = { domain = domain, id = tostring(id), field = field .. '_' .. index, text = text, template = template, parameters = parameters }
		end
	end
end

-- 装备范围在解析时可能改变正负号和增减措辞，分别保留可识别的输入形状。
local function addModLines(domain, id, lines, context, prefix)
	for index, entry in ipairs(lines or { }) do
		local text = type(entry) == 'table' and entry.line or entry
		if text ~= '' then
			local examples = { { field = (prefix or 'line') .. '_' .. index, text = text } }
			local templates = { [LineTemplates.Compile(text)] = true }
			for _, range in ipairs({ 0, 0.5, 1 }) do
				local rolled = itemLib.applyRange(text, range)
				local template = LineTemplates.Compile(rolled)
				if not templates[template] then
					templates[template] = true
					examples[#examples + 1] = { field = (prefix or 'line') .. '_' .. index .. '_roll_' .. tostring(range):gsub('%.', '_'), text = rolled }
				end
			end
			for _, example in ipairs(examples) do
				local template, values = LineTemplates.Compile(example.text)
				local parameters = { }
				for name in pairs(values) do parameters[#parameters + 1] = { name = name, expression = name, format = '', legacyIndex = tonumber(name:match('%d+')) - 1 } end
				table.sort(parameters, function(a, b) return a.legacyIndex < b.legacyIndex end)
				records[#records + 1] = { domain = domain, id = tostring(id), field = example.field, text = example.text, template = template, parameters = parameters, inputContext = context }
			end
		end
	end
end
for id, gem in pairs(data.gems) do
	add('gem', id, gem, { 'name', 'gemType', 'tagString', 'gemFamily', 'weaponRequirements' })
	for tag in pairs(gem.tags or { }) do add('skill_tag', tag, { name = tag }, { 'name' }) end
end
for id, essence in pairs(data.essences) do add('essence', id, essence, { 'name' }) end
for id, emotion in pairs(data.emotions) do add('emotion', id, emotion, { 'name' }) end
for _, resource in ipairs(data.costs) do
	records[#records + 1] = {
		domain = 'skill_cost', id = resource.Resource, field = 'ResourceString', text = resource.ResourceString,
		template = resource.ResourceString:gsub('{0}', '{value}'),
		parameters = { { name = 'value', expression = 'value', format = '', legacyIndex = 0 } },
	}
end
for _, name in ipairs(data.itemBaseTypeList) do add('equipment_type', name, { name = name }, { 'name' }) end
for _, quest in ipairs(data.questRewards) do
	local id = 'quest' .. quest.Description .. quest.Area .. quest.Info
	add('quest_reward', id, quest, { 'Description', 'Area', 'Info', 'Stat' })
	for index, option in ipairs(quest.Options or { }) do
		add('quest_reward', id, { ['Option_' .. index] = option }, { 'Option_' .. index })
	end
end
for id, skill in pairs(data.skills) do
	add('skill', id, skill, { 'name', 'description' })
	for index, statSet in ipairs(skill.statSets or { }) do
		add('skill_stat_set', id .. ':' .. index, statSet, { 'label' })
	end
	addLines('skill', id, skill, 'flavourText')
end
for id, minion in pairs(data.minions) do
	add('minion', id, minion, { 'name', 'monsterCategory' })
	addLines('minion', id, minion, 'spawnLocation')
end
for id, base in pairs(data.itemBases) do
	add('equipment_base', id, { name = id:gsub(' %(.+%)', ''), type = base.type, subType = base.subType }, { 'name', 'type', 'subType' })
	add('equipment_type', base.type, { name = base.type }, { 'name' })
	for _, kind in ipairs({ 'flask', 'charm' }) do
		if base[kind] and base[kind].buff then addModLines('equipment_base_buff', id .. ':' .. kind, base[kind].buff, 'base:' .. id .. ':' .. kind) end
	end
end
for _, list in pairs(data.uniques) do
	for _, raw in ipairs(list) do
		local item = new('Item'):Item(raw, 'UNIQUE')
		if item.title then
			add('equipment_unique', item.title, { name = item.title }, { 'name' })
			for _, field in ipairs({ 'enchantModLines', 'runeModLines', 'implicitModLines', 'explicitModLines' }) do
				local identity = item.title .. ':' .. item.baseName
				addModLines('equipment_unique_modifier', identity, item[field], identity, field)
			end
			local identity = item.title .. ':' .. item.baseName
			for _, field in ipairs({ 'variantList', 'versionList', 'upgradePaths' }) do
				addModLines('equipment_unique_modifier', identity, item[field], identity, field)
			end
			if item.source then addModLines('equipment_unique_modifier', identity, { item.source }, identity, 'source') end
		end
	end
end
for id, area in pairs(data.worldAreas) do
	add('world_area', id, area, { 'name', 'baseName', 'description' })
	addLines('world_area', id, area, 'monsterVarieties')
	addLines('world_area', id, area, 'bossVarieties')
end
for kind, list in pairs(data.itemMods) do
	for id, mod in pairs(list) do
		if mod.affix then add('equipment_affix', mod.affix, { name = mod.affix }, { 'name' }) end
		if kind == 'Runes' then
			for slot, rune in pairs(mod) do
				addModLines('equipment_modifier', kind .. ':' .. id .. ':' .. slot, rune, '')
				if rune.bonded then addModLines('equipment_modifier', kind .. ':' .. id .. ':' .. slot .. ':bonded', rune.bonded, '') end
			end
		else addModLines('equipment_modifier', kind .. ':' .. id, mod, '') end
	end
end
-- 直接读取每个已安装树版本，避免只提取当前构筑的树和遗漏可切换节点。
local function addNode(domain, id, node)
	add(domain, id, { dn = node.dn or node.name, flavourText = node.flavourText }, { 'dn', 'flavourText' })
	local lines = { }
	for _, text in ipairs(node.stats or node.sd or { }) do
		if text:find('\n', 1, true) then
			for line in text:gmatch('[^\n]+') do lines[#lines + 1] = line end
		else lines[#lines + 1] = text end
	end
	addLines(domain, id, { sd = lines }, 'sd')
	addLines(domain, id, node, 'reminderText')
end
for version in pairs(treeVersions) do
	local file = io.open('TreeData/' .. version .. '/tree.lua', 'rb')
	if file then
		file:close()
		for _, node in pairs(dofile('TreeData/' .. version .. '/tree.lua').nodes) do
			local id = version .. ':' .. node.skill
			addNode('tree_node', id, node)
			for optionId, option in pairs(node.options or { }) do addNode('tree_node', id .. ':option:' .. optionId, option) end
		end
	end
end
for id, node in pairs(build.spec.tree.legion.nodes) do addNode('tree_legion', id, node) end
for _, entry in pairs(data.flavourText) do
	add('equipment_flavour', entry.id, entry, { 'origin' })
	addLines('equipment_flavour', entry.id, entry, 'text')
end
for id, class in pairs(build.spec.tree.classes) do
	add('tree_class', class.internalId or id, class, { 'name' })
	for index, ascendancy in pairs(class.classes) do
		add('tree_ascendancy', ascendancy.internalId or (class.internalId or id) .. ':' .. index, ascendancy, { 'name' })
	end
end
local file = assert(io.open('Tests/Run/key-game-data.json', 'wb'))
file:write(require('dkjson').encode(records)); file:close()
print('已提取 ' .. #records .. ' 个具有业务身份的显示字段。')
