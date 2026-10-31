-- 检查词库结构问题是否进入实际显示与反向转换，并隔离原生标题输出探针。
package.cpath = '../runtime/?.dll;' .. package.cpath
package.path = '../runtime/lua/?.lua;../runtime/lua/?/init.lua;' .. package.path
arg = { }
io.stdout:setvbuf('no')
io.read = function() error('审计禁止等待交互') end
dofile('HeadlessWrapper.lua')
assert(build and not launch.promptMsg, 'PoB2 初始化失败')
main.userPath = 'Tests/Run/'
local output = assert(io.open('../docs/localisation-boundary-review.csv', 'wb'))
output:write('language,domain,origin,status,source,display,reverse\n')
local counts = { }
-- 从实际宝石对象取当前译名，不把英文名称拼成未经验证的技能 ID。
local function gemName(name)
	for _, gem in pairs(data.gems) do
		if gem.name == name then return localisation:Field(gem, 'name') end
	end
	error('审计样本没有对应宝石：' .. name)
end
-- 成功往返只计数，失败和差异保留逐条输入输出。
local function record(domain, origin, status, source, display, reverse)
	local key = localisation.language .. '|' .. domain .. '|' .. status
	counts[key] = (counts[key] or 0) + 1
	if status == 'roundtrip' then return end
	local values = { localisation.language, domain, origin, status, source, display, reverse or '' }
	for i, value in ipairs(values) do values[i] = '"' .. tostring(value):gsub('"', '""') .. '"' end
	output:write(table.concat(values, ',') .. '\n')
end
local Dictionary = dofile('Modules/Localisation/Dictionary.lua')
local Languages = dofile('Modules/Localisation/Languages.lua')
for _, language in ipairs({ 'zh-CN', 'zh-TW' }) do
	-- 历史词库仅作为输入转换风险探针，不代表当前显示覆盖。
	local resources = Languages.LoadResources(language)
	local dictionary = Dictionary.New(); dictionary:LoadFiles(resources.path, resources.files)
	localisation:SetLanguage(language)
	for _, sample in ipairs({
		'Consumes 1 Charge from 1 Life Flask',
		'Consumes 1 Charge from 1 Life Flask, if possible',
		'Consumes 2 Charges from 1 Life Flask, if possible',
		'Every 5 seconds, gain 10% of Physical Damage',
		'Adds 10 Physical Damage to Attacks while you have a Bestial Minion',
		'If left empty or set to 0, Fully Broken Armour will be assumed.',
		'Armour cannot be broken below 0 unless stated otherwise.',
		'Error fetching league list, default league will be used',
	}) do
		local translated = dictionary:Translate(sample)
		record('resource-probe', '词库异常样本', translated:find('{%d+}') and 'placeholder-leak' or translated == sample and 'fallback' or 'translation-review', sample, translated)
	end
	for name in pairsSortByKey(data.itemBases) do
		local source = name:gsub(' %(.+%)', '')
		local display = localisation:DataText('equipment_base', name, 'name', source)
		local reverse = localisation:ToEnglish(display)
		local status = reverse == source and 'roundtrip' or display == source and 'display-fallback' or reverse:find('[\128-\255]') and 'unconverted' or 'different-English'
		record('item.base-roundtrip', name, status, source, display, reverse)
		if status ~= 'roundtrip' then
			local english = new('Item'):Item('Rarity: Normal\n' .. source .. '\n')
			local imported = new('Item'):Item(localisation:ItemText('Rarity: Normal\n' .. display .. '\n'))
			if english.base then
				record('item.base-parse', name, not imported.base and 'parse-failed' or imported.base ~= english.base and 'different-base' or 'parse-compatible', source, display, imported.baseName or '')
			end
		end
	end
	for id, gem in pairsSortByKey(data.gems) do
		local display = localisation:Field(gem, 'name')
		local reverse = localisation:ToEnglish(display)
		local status = reverse == gem.name and 'roundtrip' or display == gem.name and 'display-fallback' or reverse:find('[\128-\255]') and 'unconverted' or 'different-English'
		record('gem.name-roundtrip', id, status, gem.name, display, reverse)
	end
	local titleFunc, captured, showTitle = SetWindowTitle, nil, main.showTitlebarName
	SetWindowTitle = function(text) captured = text end
	main.showTitlebarName = true
	build.spec:SetWindowTitleWithBuildClass()
	SetWindowTitle, main.showTitlebarName = titleFunc, showTitle
	local currentClass = build.spec.curAscendClassId == 0 and build.spec.curClass or build.spec.curAscendClass
	local expectedTitle = build.buildName .. ' (' .. localisation:Field(currentClass, 'name') .. ') - ' .. APP_NAME
	record('native.title', 'Classes/PassiveSpec.lua:SetWindowTitleWithBuildClass', captured == expectedTitle and 'display-compatible' or 'display-mismatch', currentClass.name, captured or '')
	for _, name in ipairs({ 'Fireball', 'Ice Shards', 'Rampage' }) do
		local translated = gemName(name)
		local err, gem = build.skillsTab:FindSkillGem(translated)
		local status = not err and 'lookup-compatible' or err:find('Ambiguous', 1, true) and 'lookup-ambiguous' or 'lookup-failed'
		record('skill.lookup', 'Classes/SkillsTab.lua:FindSkillGem', status, name, translated, gem and gem.name or err)
	end
	for _, name in ipairs({ 'Fireball', gemName('Fireball') }) do
		local savedPaste, before = Paste, #build.skillsTab.socketGroupList
		local text = name .. ' 20/0 1'
		Paste = function() return text end
		local ok, err = pcall(build.skillsTab.PasteSocketGroup, build.skillsTab)
		Paste = savedPaste
		local added = #build.skillsTab.socketGroupList - before
		record('skill.clipboard', 'Classes/SkillsTab.lua:PasteSocketGroup', not ok and 'error' or added == 0 and 'paste-rejected' or 'paste-compatible', text, '新增技能组：' .. added, err)
	end
	for _, file in ipairs({ 'help.txt', 'changelog.txt' }) do
		for line in io.lines('../' .. file) do
			if line:find('%a') then
				local translated = line
				record('text-resource.' .. file, file, translated == line and 'fallback' or 'translation-review', line, translated)
			end
		end
	end
	print(language .. ' 显示/反向转换边界检查完成')
end
output:close()
local report = assert(io.open('../docs/localisation-boundary-audit.md', 'wb'))
report:write('# 中文使用边界审计\n\n生成日期：2026-10-31。命令：在 src 运行 `..\\tools\\LuaRunner.exe ..\\tools\\audit-localisation-boundaries.lua`。\n\n使用当前稳定资源 DataText/Field 取得基底与宝石显示名称，再以真实 ToEnglish 检查名称往返。unconverted 表示译名未转回英文；different-English 表示转成其他英文，须验证是否为兼容别名；不直接把此统计等同于角色导入失败数。名称往返不一致的基底同时交给真实 Item 解析器，与同名英文基线对照；parse-failed 是英文可以解析而中文失败。技能剪贴板使用真实 PasteSocketGroup，对照英文和当前中文技能名。静态名称往返通过也不代表中文真实物品完整格式已被解析。\n\n资源探针包含历史/未启用词条，只证明坏词库能够产生截断、残留参数或错误英文译文，不代表每条都在当前物品触发。help.txt/changelog.txt 逐行只统计原文，未接入产品稳定资源，文件中尚未被窗口滚动到的行不冒充已显示。标题探针拦截真实 SetWindowTitle 参数，不修改原生窗口或用户设置。\n\n| 语言/数据域/状态 | 次数 |\n|---|---:|\n')
for key, count in pairsSortByKey(counts) do report:write('| ' .. key:gsub('%|', ' / ') .. ' | ' .. count .. ' |\n') end
report:write('\n原文、实际输出及反向结果见 `localisation-boundary-review.csv`。\n')
report:close()
