-- 使用真实装备、列表、槽位和比较提示框回归，防止只测试词条却遗漏显示拼接。
return function(build, equal)
	local item
	for _, raw in ipairs(dofile('Data/Uniques/shield.lua')) do
		if raw:match('^%s*Alkem Eira\n') then item = new('Item'):Item(raw, 'UNIQUE'); break end
	end
	assert(item and item.base, '缺少神谕装备样本')
	local raw, name, baseName = item.raw, item.name, item.baseName
	local originalTranslate = localisation.Translate
	localisation.Translate = function(self, text) return text end
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
	localisation.Translate = originalTranslate
	local originalFlavour, originalSupport = main.showFlavourText, main.notSupportedModTooltips
	main.showFlavourText, main.notSupportedModTooltips = true, true
	build.itemsTab:AddItem(item, true)
	build.itemsTab:PopulateSlots()
	local slot = build.itemsTab.slots['Weapon 2']
	local viewPort = { x = 0, y = 0, width = 1920, height = 1080 }
	local englishBlocks
	for _, language in ipairs({ 'en', 'zh-CN', 'zh-TW', 'en' }) do
		localisation:SetLanguage(language)
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
	-- 验证标签翻译不会把用户输入中的英文技能名称改成译文。
	for _, language in ipairs({ 'en', 'zh-CN', 'zh-TW' }) do
		localisation:SetLanguage(language)
		local edit = new('EditControl'):EditControl(nil, { 0, 0, 200, 20 }, 'Fireball', 'Search')
		local draw, drawn = DrawString, { }
		DrawString = function(x, y, align, height, font, text) drawn[#drawn + 1] = tostring(text); return draw(x, y, align, height, font, text) end
		local ok, err = pcall(edit.Draw, edit, viewPort)
		DrawString = draw
		equal(ok, true, language .. ' 搜索输入框绘制 ' .. tostring(err))
		equal(table.concat(drawn):find(localisation:Translate('Search'), 1, true) ~= nil, true, language .. ' 搜索标签翻译')
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
			if localisation:Translate(source) == source and source:find('%a') then missingBases[#missingBases + 1] = source end
		end
		for _, list in ipairs({ build.displayStats, build.minionDisplayStats }) do
			for _, stat in ipairs(list) do
				if stat.stat and stat.label and localisation:Translate(stat.label) == stat.label then missingLabels[#missingLabels + 1] = stat.label end
			end
		end
		equal(#missingBases, 0, language .. ' 全部装备基底无原文回退：' .. table.concat(missingBases, ', '))
		equal(#missingLabels, 0, language .. ' 全部比较属性标签无原文回退：' .. table.concat(missingLabels, ', '))
	end
	main.showFlavourText, main.notSupportedModTooltips = originalFlavour, originalSupport
end
