-- 验证真实下拉列表在切换语言后仍能搜索、选择原值，词缀复制保持显示引用。
return function(build, equal)
	local values = { 'Unbuffed', 'Buffed' }
	local list = localisation:List(values, { 'ui.calcs_tab.module.buff_mode_drop_list.label_4', 'ui.calcs_tab.module.buff_mode_drop_list.label' })
	local selected
	local control = new('DropDownControl'):DropDownControl(nil, { 0, 0, 200, 20 }, list, function(_, value) selected = value end)
	for _, language in ipairs({ 'zh-CN', 'zh-TW', 'en' }) do
		localisation:SetLanguage(language)
		equal(list, values, language .. ' 显示绑定保留列表身份')
		local count = 0
		for _ in pairs(list) do count = count + 1 end
		equal(count, 2, language .. ' 显示引用不污染业务枚举')
		control.searchTerm = 'Buffed'; control:UpdateSearch()
		equal(control:GetMatchCount() > 0, true, language .. ' 原始列表支持英文搜索')
		local display = localisation:ListLabel(list, 1)
		control.searchTerm = display; control:UpdateSearch()
		equal(control:GetMatchCount(), 1, language .. ' 当前语言列表支持搜索')
		equal(#control.searchInfos[1].ranges > 0, true, language .. ' 搜索高亮使用显示文字范围')
		control:ResetSearch(); control:SetSel(2)
		equal(selected, 'Buffed', language .. ' 选择回调收到原业务值')
		control:SetSel(1)
		equal(values[1], 'Unbuffed', language .. ' 语言切换未改写列表')
	end
	local rune
	for _, mods in pairs(data.itemMods.Runes) do
		for _, candidate in pairs(mods) do
			if candidate[1] == '20% increased Armour, Evasion and Energy Shield' then rune = candidate; break end
		end
		if rune then break end
	end
	assert(rune, '缺少符文显示回归样本')
	local copied = { line = rune[1] }
	localisation:BindModDataLine(rune, 1, copied)
	copied = copyTable(copied, true)
	for _, language in ipairs({ 'en', 'zh-CN', 'zh-TW' }) do
		localisation:SetLanguage(language)
		local text = localisation:ModLine(copied, '40% increased Armour, Evasion and Energy Shield')
		equal(text:find('40', 1, true) ~= nil, true, language .. ' 符文复制后保持当前数值')
		if language ~= 'en' then equal(text:find('increased Armour', 1, true), nil, language .. ' 符文复制后保留显示引用') end
		local bonded = localisation:ModLine(copied, 'Bonded: 40% increased Armour, Evasion and Energy Shield')
		equal(bonded, localisation:Text('equipment.modifier.bonded', { modifier = text }), language .. ' 绑定符文完整句子使用当前语言')
	end
	for _, language in ipairs({ 'en', 'zh-CN', 'zh-TW' }) do
		localisation:SetLanguage(language)
		local slot = build.itemsTab.slots['Weapon 1']
		equal(slot.label, 'Weapon 1', language .. ' 槽位原标签保留字符串')
		equal(type(localisation:Field(slot, 'label')), 'string', language .. ' 槽位显示引用实际求值')
		if language ~= 'en' then equal(localisation:Field(slot, 'label'), '武器 1', language .. ' 槽位显示不依赖英文反查') end
		for _, resource in ipairs(data.costs) do
			local text = localisation:Field(resource, 'ResourceString', { value = '(1.25-2.5)' })
			equal(text:find('(1.25-2.5)', 1, true) ~= nil, true, language .. ' 技能消耗保持数值范围: ' .. resource.Resource)
			equal(resource.ResourceString:find('{0}', 1, true) ~= nil, true, language .. ' 技能消耗不改写原业务模板: ' .. resource.Resource)
			if language == 'en' then
				equal(text, resource.ResourceString:gsub('{0}', '(1.25-2.5)'), '英文消耗与旧占位替换一致: ' .. resource.Resource)
			else
				equal(text:find('[A-Za-z]'), nil, language .. ' 消耗正文使用独立译文: ' .. resource.Resource)
			end
		end
	end
	localisation:SetLanguage('en')
end
