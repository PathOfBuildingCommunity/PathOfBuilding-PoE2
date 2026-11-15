-- 内置稀有预设使用明确的标题资源；相同原文的用户物品不得被推测为预设。
return function(build, equal)
	local originalLanguage = localisation.language
	local presets = { }
	for _, item in pairsSortByKey(main.rareDB.list) do
		presets[#presets + 1] = { item = item, raw = item.raw, name = item.name, title = item.title, baseName = item.baseName }
	end
	equal(#presets, #data.rares, '全部内置稀有预设已完成加载')
	for _, language in ipairs({ 'en', 'zh-CN', 'zh-TW', 'en' }) do
		localisation:SetLanguage(language)
		for _, saved in ipairs(presets) do
			local item = saved.item
			local title, baseName = localisation:ItemTitle(item)
			if saved.title then
				if language == 'en' then
					equal(title, saved.title, '内置预设英文标题保持：' .. saved.title)
				else
					equal(title:find('%a'), nil, language .. ' 内置预设完整标题翻译：' .. saved.title)
					equal(title, localisation:Text(item.titleKey), language .. ' 内置预设标题使用明确资源')
				end
				local expected = title .. ', ' .. baseName
				equal(StripEscapes(build.itemsTab.controls.rareDB:GetRowValue(1, 1, item)), expected, language .. ' 稀有数据库实际列表名称')
				local tooltip = new('Tooltip'):Tooltip()
				build.itemsTab:AddItemTooltip(tooltip, item, nil, true)
				equal(StripEscapes(tooltip.lines[1].text), title, language .. ' 稀有预设实际提示框标题')
				-- 数据库加入构筑与打开编辑器均通过原始文本创建新物品，不传播预设身份。
				local copy = new('Item'):Item(item.raw)
				equal(copy.titleKey, nil, language .. ' 原文复制不传播预设标题引用')
				equal(localisation:ItemTitle(copy), saved.title, language .. ' 同名用户物品保留原始标题')
				equal(copy.raw, saved.raw, language .. ' 复制原文保持且不写入显示引用')
			end
			equal(item.raw, saved.raw, language .. ' 预设原文保持')
			equal(item.name, saved.name, language .. ' 数据库索引身份保持')
			equal(item.title, saved.title, language .. ' 预设原始标题保持')
			equal(item.baseName, saved.baseName, language .. ' 预设基底身份保持')
		end
	end
	localisation:SetLanguage(originalLanguage)
end
