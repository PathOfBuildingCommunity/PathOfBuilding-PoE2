-- 使用真实装备、列表、槽位和比较提示框回归，防止只测试词条却遗漏显示拼接。
return function(build, equal)
	-- 截图中的失落珠宝必须整句翻译，且范围标签随语言切换。
	local jewelRaw = 'Rarity: RARE\nLoath Stone\nTime-Lost Emerald\nRadius: Very Large\nNotable Passive Skills in Radius also grant 2% increased Attack Speed\nNotable Passive Skills in Radius also grant 2% increased Attack Speed with Spears\nSmall Passive Skills in Radius also grant 2% increased Evasion Rating\nUpgrades Radius to Very Large'
	local jewel = new('Item'):Item(jewelRaw)
	assert(jewel and jewel.base and #jewel.explicitModLines == 4, '缺少失落珠宝回归样本')
	local expected = {
		['zh-CN'] = { '范围内的核心天赋额外提供：攻击速度提高 2%', '范围内的核心天赋额外提供：战矛的攻击速度提高 2%', '范围内的小型天赋额外提供：闪避值提高 2%', '极大型' },
		['zh-TW'] = { '範圍內的核心天賦額外提供：增加2%攻擊速度', '範圍內的核心天賦額外提供：增加2%長矛攻擊速度', '範圍內的小型天賦額外提供：增加2%閃避值', '極大型' },
	}
	for _, language in ipairs({ 'en', 'zh-CN', 'zh-TW', 'en' }) do
		localisation:SetLanguage(language)
		local tooltip = new('Tooltip'):Tooltip()
		build.itemsTab:AddItemTooltip(tooltip, jewel, nil, true)
		local lines = { }
		for _, line in ipairs(tooltip.lines) do if line.text then lines[#lines + 1] = StripEscapes(line.text) end end
		local text = table.concat(lines, '\n')
		for index = 1, 3 do
			local modLine = jewel.explicitModLines[index]
			local displayed = localisation:ModLine(modLine, modLine.line)
			equal(displayed, expected[language] and expected[language][index] or modLine.line, language .. ' 失落珠宝词缀 ' .. index)
			if language == 'en' then equal(text:find(modLine.line, 1, true) ~= nil, true, '切回英文保留珠宝原词缀') end
			equal(modLine.modList and #modLine.modList > 0, true, language .. ' 珠宝词缀仍解析为计算属性')
		end
		if expected[language] then
			equal(text:find(expected[language][4], 1, true) ~= nil, true, language .. ' 实际提示框翻译极大型范围')
			for _, source in ipairs({ 'Passive Skills', 'also grant', 'Very Large', 'Attack Speed', 'Evasion Rating' }) do
				equal(text:find(source, 1, true), nil, language .. ' 珠宝提示框不残留 ' .. source)
			end
		end
		equal(jewel.raw, jewelRaw, language .. ' 翻译不改写珠宝原文')
		equal(jewel.jewelRadiusLabel, 'Very Large', language .. ' 翻译不改写珠宝范围身份')
	end
	-- 遍历运行时实际拼接的珠宝词缀，防止只补截图而遗漏同类属性或输入绑定歧义。
	for _, language in ipairs({ 'zh-CN', 'zh-TW' }) do
		localisation:SetLanguage(language)
		for _, kind in ipairs({ 'Jewel', 'Desecrated' }) do
			for id, mod in pairs(data.itemMods[kind]) do
				if mod[1] and mod[1]:match('^%a+ Passive Skills in Radius also grant ') then
					local rolled = itemLib.applyRange(mod[1], 0.5)
					local modLine = { line = rolled }
					localisation:BindModLine(modLine)
					local displayed = localisation:ModLine(modLine, rolled)
					equal(displayed:find('%a'), nil, language .. ' 范围珠宝完整译文 ' .. id .. ': ' .. displayed)
					equal(displayed, localisation:ModDataLine(mod, 1, rolled), language .. ' 范围珠宝输入与词缀表显示一致 ' .. id)
					for value in rolled:gmatch('%d+%.?%d*') do
						equal(displayed:find(value, 1, true) ~= nil, true, language .. ' 珠宝加成保留数值 ' .. id)
					end
				end
			end
		end
	end
	local item
	for _, raw in ipairs(dofile('Data/Uniques/shield.lua')) do
		if raw:match('^%s*Alkem Eira\n') then item = new('Item'):Item(raw, 'UNIQUE'); break end
	end
	assert(item and item.base, '缺少神谕装备样本')
	local raw, name, baseName = item.raw, item.name, item.baseName
	local blockLine
	for _, line in ipairs(item.explicitModLines) do if line.line:find('increased Block chance', 1, true) then blockLine = line; break end end
	assert(blockLine and #blockLine.displayReferences > 0, '已知唯一装备词缀必须绑定显示引用')
	for _, language in ipairs({ 'en', 'zh-CN', 'zh-TW', 'en' }) do
		localisation:SetLanguage(language)
		local displayed = localisation:ModLine(blockLine, blockLine.line)
		if language == 'en' then equal(displayed, blockLine.line, '装备词缀切回英文保留原范围')
		else equal(displayed ~= blockLine.line, true, language .. ' 装备词缀不依赖绘制词典') end
		local rolled = itemLib.applyRange(blockLine.line, 0.5)
		local rendered = localisation:ModLine(blockLine, rolled)
		equal(rendered:find(rolled:match('%d+'), 1, true) ~= nil, true, language .. ' 已绑定词缀保留实际范围数值')
		equal(item.raw, raw, language .. ' 绑定显示引用不改写物品原文')
	end
	local unknown = { line = 'My custom unknown modifier 42' }
	localisation:BindModLine(unknown)
	equal(localisation:ModLine(unknown, unknown.line), unknown.line, '未知用户词缀保留原文')
	local originalFlavour, originalSupport = main.showFlavourText, main.notSupportedModTooltips
	main.showFlavourText, main.notSupportedModTooltips = true, true
	build.itemsTab:AddItem(item, true)
	build.itemsTab:PopulateSlots()
	local slot = build.itemsTab.slots['Weapon 2']
	local viewPort = { x = 0, y = 0, width = 1920, height = 1080 }
	local englishBlocks
	for _, language in ipairs({ 'en', 'zh-CN', 'zh-TW', 'en' }) do
		localisation:SetLanguage(language)
		-- 人造肢体槽位沿用原始保存身份，仅为实际控件补齐显示名称。
		for _, specification in ipairs({
			{ 'Arm 1', '手臂 1', '手臂 1' }, { 'Arm 2', '手臂 2', '手臂 2' },
			{ 'Leg 1', '腿部 1', '腿部 1' }, { 'Leg 2', '腿部 2', '腿部 2' },
		}) do
			local limbSlot = build.itemsTab.slots[specification[1]]
			local name = language == 'zh-CN' and specification[2] or language == 'zh-TW' and specification[3] or specification[1]
			equal(localisation:Field(limbSlot, 'label'), name, language .. ' 人造肢体槽实际标签：' .. specification[1])
			equal(limbSlot.slotName, specification[1], language .. ' 人造肢体槽保存身份保持')
		end
		local tooltip = new('Tooltip'):Tooltip()
		build.itemsTab:AddItemTooltip(tooltip, item, nil, true)
		local lines = { }
		for _, line in ipairs(tooltip.lines) do
			if line.text then lines[#lines + 1] = StripEscapes(line.text) end
		end
		local text = table.concat(lines, '\n')
		local expectedName = language == 'en' and item.name or (language == 'zh-CN' and '神谕, 饰印纹章盾' or '神諭, 家徽紋章盾')
		if language == 'en' then
			equal(text:find('Blazon Crest Shield', 1, true) ~= nil, true, '英文基底显示')
			equal(text:find('Damage Blocked is Recouped as Mana', 1, true) ~= nil, true, '英文不支持词缀仍保持原文')
			englishBlocks = #tooltip.blocks
		else
			for _, source in ipairs({ 'Blazon Crest Shield', 'Grants Skill:', 'Raise Shield', 'increased Block chance', 'increased Armour and Energy Shield', 'to maximum Mana', 'Damage Blocked is Recouped as Mana', 'Not supported in PoB yet', 'May your resolve never waver.', 'Tip:', 'Effective Hit Pool', 'Phys Max Hit', 'Movement Speed Modifier' }) do
				equal(text:find(source, 1, true), nil, language .. ' 装备真实提示框不残留 ' .. source)
			end
			equal(text:find(language == 'zh-CN' and '饰印纹章盾' or '家徽紋章盾', 1, true) ~= nil, true, language .. ' 基底进入真实提示框')
			equal(text:find('(15-20)', 1, true) ~= nil, true, language .. ' 词缀范围完整保留')
			equal(text:find(language == 'zh-CN' and '被格挡的伤害吸纳为魔力' or '格擋的傷害補償為魔力', 1, true) ~= nil, true, language .. ' 不支持附注的正文翻译')
			equal(#tooltip.blocks, englishBlocks, language .. ' 比较提示框分块保持一致')
			local remaining = text:gsub('PoB', ''):gsub('Shift', ''):gsub('Ctrl%+D', '')
			equal(remaining:find('%a'), nil, language .. ' 神谕主提示框无未翻译英文：' .. remaining)
		end
		equal(StripEscapes(build.itemsTab.controls.uniqueDB:GetRowValue(1, 1, item)), expectedName, language .. ' 数据库列表显示名')
		equal(StripEscapes(build.itemsTab.controls.sharedItemList:GetRowValue(1, 1, item)), expectedName, language .. ' 共享列表显示名')
		local listName = StripEscapes(build.itemsTab.controls.itemList:GetRowValue(1, 1, item.id))
		equal(listName:sub(1, #expectedName), expectedName, language .. ' 构筑列表显示名')
		if language ~= 'en' then equal(listName:find('Unused', 1, true), nil, language .. ' 使用状态翻译') end
		slot:Draw(viewPort)
		local found = false
		for index, id in ipairs(slot.items) do
			if id == item.id then
				local entry = slot.list[index]
				equal(StripEscapes(type(entry) == 'table' and entry.label or entry), expectedName, language .. ' 装备槽切换语言立即刷新'); found = true
			end
		end
		equal(found, true, language .. ' 装备仍在槽位候选中')
		for _, query in ipairs({ 'Alkem', language == 'en' and 'Blazon' or (language == 'zh-CN' and '神谕' or '神諭') }) do
			slot.searchTerm = query; slot:UpdateSearch()
			equal(slot:GetMatchCount() > 0, true, language .. ' 装备槽检索 ' .. query)
			slot:ResetSearch()
			local db = build.itemsTab.controls.uniqueDB
			local mode, obtainable = db.controls.searchMode.selIndex, db.controls.obtainable.selIndex
			db.controls.searchMode.selIndex, db.controls.obtainable.selIndex = 2, 2
			db.controls.search:SetText(query)
			equal(db:DoesItemMatchFilters(item), true, language .. ' 数据库检索 ' .. query)
			db.controls.search:SetText('')
			db.controls.searchMode.selIndex, db.controls.obtainable.selIndex = mode, obtainable
		end
		equal(item.raw, raw, language .. ' 不改写装备原文')
		equal(item.name, name, language .. ' 不改写内部名称')
		equal(item.baseName, baseName, language .. ' 不改写内部基底')
	end
	-- 授予多个技能时不残留英文复数，跨页面查看装备时使用已翻译的页面提示。
	local originalSkills, originalView = item.grantedSkills, build.viewMode
	assert(originalSkills and originalSkills[1], '缺少授予技能的装备样本')
	for _, language in ipairs({ 'en', 'zh-CN', 'zh-TW', 'en' }) do
		localisation:SetLanguage(language)
		for _, mode in ipairs({ 'ITEMS', 'TREE' }) do
			build.viewMode = mode
			for count = 1, 2 do
				item.grantedSkills = { originalSkills[1], count == 2 and originalSkills[1] or nil }
				local tooltip = new('Tooltip'):Tooltip()
				build.itemsTab:AddItemTooltip(tooltip, item, nil, true)
				local lines = { }
				for _, row in ipairs(tooltip.lines) do if row.text then lines[#lines + 1] = StripEscapes(row.text) end end
				local text = table.concat(lines, '\n')
				if language == 'en' then
					equal(text:find('for the granted skill' .. (count == 2 and 's' or '') .. '.', 1, true) ~= nil, true, '英文授予技能提示单复数保持一致')
					equal(text:find(' in the Items tab', 1, true) ~= nil, mode ~= 'ITEMS', '英文物品页上下文保持一致')
				else
					equal(text:find('in the Items tab', 1, true), nil, language .. ' 跨页面装备提示不残留英文上下文')
					equal(text:find('授予技能的提示框', 1, true) ~= nil, true, language .. ' 多个授予技能使用完整中文句子')
				end
			end
		end
	end
	item.grantedSkills, build.viewMode = originalSkills, originalView
	-- 验证标签翻译不会把用户输入中的英文技能名称改成译文。
	for _, language in ipairs({ 'en', 'zh-CN', 'zh-TW' }) do
		localisation:SetLanguage(language)
		local edit = new('EditControl'):EditControl(nil, { 0, 0, 200, 20 }, 'Fireball', localisation:Label('ui.build_list.init.search_text.label'))
		local draw, drawn = DrawString, { }
		DrawString = function(x, y, align, height, font, text) drawn[#drawn + 1] = tostring(text); return draw(x, y, align, height, font, text) end
		local ok, err = pcall(edit.Draw, edit, viewPort)
		DrawString = draw
		equal(ok, true, language .. ' 搜索输入框绘制 ' .. tostring(err))
		equal(table.concat(drawn):find(localisation:Text('ui.build_list.init.search_text.label'), 1, true) ~= nil, true, language .. ' 搜索标签翻译')
		equal(edit.buf, 'Fireball', language .. ' 标签翻译不污染输入内容')
	end
	for _, language in ipairs({ 'zh-CN', 'zh-TW' }) do
		localisation:SetLanguage(language)
		local missingBases, missingLabels = { }, { }
		local requirements = new('Tooltip'):Tooltip()
		requirements.tooltipHeader = 'UNIQUE'
		build:AddRequirementsToTooltip(requirements, 18, 60, 55, 50, 0, 0, 0)
		local requirementText = { }
		for _, line in ipairs(requirements.lines) do if line.text then requirementText[#requirementText + 1] = StripEscapes(line.text) end end
		requirementText = table.concat(requirementText, '\n')
		equal(requirementText:find('%a'), nil, language .. ' 等级与属性需求无英文：' .. requirementText)
		equal(requirementText:find('18', 1, true) ~= nil, true, language .. ' 需求数值完整保留')
		for name in pairs(data.itemBases) do
			local source = name:gsub(' %(.+%)', '')
			if localisation:DataText('equipment_base', name, 'name', source) == source and source:find('%a') then missingBases[#missingBases + 1] = source end
		end
		for _, list in ipairs({ build.displayStats, build.minionDisplayStats }) do
			for _, stat in ipairs(list) do
				if stat.stat and stat.label and localisation:Field(stat, 'label') == stat.label then missingLabels[#missingLabels + 1] = stat.label end
			end
		end
		equal(#missingBases, 0, language .. ' 全部装备基底无原文回退：' .. table.concat(missingBases, ', '))
		equal(#missingLabels, 0, language .. ' 全部比较属性标签无原文回退：' .. table.concat(missingLabels, ', '))
	end
	main.showFlavourText, main.notSupportedModTooltips = originalFlavour, originalSupport
end
