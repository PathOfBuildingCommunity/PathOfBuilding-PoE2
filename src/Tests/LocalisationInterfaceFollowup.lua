-- 读取实际确认弹窗和动态警告，所有删除、保存及版本转换回调均不执行。
return function(build, equal)
	local languageBefore = localisation.language
	local item = new('Item'):Item('Rarity: NORMAL\nLapis Amulet\nItem Level: 1')
	local branch, selectedSet
	local items = {
		items = { [1] = item }, itemOrderList = { 1 },
		GetEquippedSlotForItem = function()
			if branch == 'slot' then return build.itemsTab.slots.Amulet, selectedSet end
		end,
		DeleteItem = function() error('只读弹窗检查禁止删除物品') end,
	}
	local itemControl = new('ItemListControl'):ItemListControl(nil, { 0, 0, 500, 200 }, items)
	itemControl.FindEquippedItemSocket = function() if branch == 'socket' then return selectedSet end end
	itemControl.FindSocketedJewel = function() if branch == 'tree' then return 'User Tree' end end
	local function popupBody()
		local popup = main.popups[1]
		local lines = { }
		for _, control in ipairs(popup.controls) do
			if control.label then lines[#lines + 1] = StripEscapes(control:GetProperty('label')) end
		end
		return table.concat(lines, '\n')
	end
	local warningsBefore = build.controls.warnings.lines
	local itemWarningsBefore = build.calcsTab.mainEnv.itemWarnings
	local loadoutValues = copyTable(build.controls.buildLoadouts.list)
	local buildList = new('BuildListControl')
	for _, language in ipairs({ 'en', 'zh-CN', 'zh-TW', 'en' }) do
		localisation:SetLanguage(language)
		-- 直接读取实际按钮，验证同一控件随语言切换更新标签和宽度。
		local labels = language == 'en' and { 'Convert to ', 'Convert all trees to ' } or language == 'zh-CN' and { '转换为 ', '将全部天赋树转换为 ' } or { '轉換為 ', '將全部天賦樹轉換為 ' }
		for index, name in ipairs({ 'specConvert', 'specConvertAll' }) do
			local control = build.treeTab.controls[name]
			local display = treeVersions[latestTreeVersion .. (build.spec.treeVersion:match('^' .. latestTreeVersion .. '(.*)') or '')].display
			local label = control:GetProperty('label')
			equal(StripEscapes(label), labels[index] .. display, language .. ' 天赋转换按钮完整翻译')
			local width = control:GetSize()
			equal(width >= DrawStringWidth(16, 'VAR', label) + 20, true, language .. ' 天赋转换按钮宽度容纳当前语言')
		end
		local loadoutLabels = language == 'en' and { 'Loadouts:', 'Manage', 'Sync', 'Help >>' } or language == 'zh-CN' and { '配装方案：', '管理', '同步', '帮助 >>' } or { '配裝方案：', '管理', '同步', '說明 >>' }
		local list = build.controls.buildLoadouts.list
		for index, position in ipairs({ 1, #list - 2, #list - 1, #list }) do
			equal(StripEscapes(localisation:ListLabel(list, position)), loadoutLabels[index], language .. ' 配装固定选项翻译')
		end
		for index, value in ipairs(list) do equal(value, loadoutValues[index], language .. ' 配装回调仍读取原始选择值') end
		for _, class in pairs(main.tree[latestTreeVersion].classes) do
			for _, ascendancy in pairs(class.classes) do
				local header = { buildName = 'User Build', level = 90, className = class.name, ascendClassName = ascendancy.name }
				local rawName = ascendancy.name ~= 'None' and ascendancy.name or class.name
				local row = StripEscapes(buildList:GetRowValue(2, 1, header))
				if language == 'en' then equal(row, 'Level 90 ' .. rawName, '英文构筑列表摘要保持')
				else equal(row:find('%a'), nil, language .. ' 构筑列表等级和职业摘要翻译') end
				equal(header.className, class.name, '构筑列表保留原职业身份')
				equal(header.ascendClassName, ascendancy.name, '构筑列表保留原升华身份')
				equal(header.buildName, 'User Build', '构筑列表保留用户名称')
			end
		end
		local unknown = { buildName = 'User Build', className = 'User Class', ascendClassName = 'User Ascendancy' }
		equal(buildList:GetRowValue(2, 1, unknown):find('User Ascendancy', 1, true) ~= nil, true, language .. ' 未知历史职业保留原文')
		for _, mode in ipairs({ 'slot', 'socket', 'tree' }) do
			branch = mode
			for _, custom in ipairs({ false, true }) do
				selectedSet = { title = custom and 'User Set' or nil }
				local countBefore = #main.popups
				itemControl:OnSelDelete(1, 1)
				equal(#main.popups, countBefore + 1, language .. ' 实际物品删除确认弹窗：' .. mode)
				local body = popupBody()
				if language == 'en' then
					local phrase = mode == 'slot' and ' is currently equipped in ' or mode == 'socket' and ' is currently equipped in a Socket' or ' is currently equipped in passive tree '
					equal(body:find(phrase, 1, true) ~= nil, true, '英文删除提示保留原句')
					if mode ~= 'tree' then equal(body:find(" in set '" .. (custom and 'User Set' or 'Default') .. "'", 1, true) ~= nil, true, '英文装备组后缀保持') end
				else
					equal(body:gsub('User Set', ''):gsub('User Tree', ''):find('%a'), nil, language .. ' 删除提示及装备组连接语完整翻译')
					if mode ~= 'tree' and custom then equal(body:find('User Set', 1, true) ~= nil, true, language .. ' 用户装备组名保持') end
				end
				main:ClosePopup()
				equal(items.items[1], item, language .. ' 关闭确认没有删除物品')
			end
		end
		build:OpenConversionPopup()
		local popup = main.popups[1]
		for _, field in ipairs({ 'note', 'label' }) do
			local display = StripEscapes(popup.controls[field]:GetProperty('label'))
			if language ~= 'en' then equal(display:gsub('Path of Building Community', ''):find('%a'), nil, language .. ' 实际版本转换说明完整翻译') end
		end
		main:ClosePopup()
		-- 位置列表作为嵌套资源读取，支持宝石数量保持整数，用户位置名称原样保留。
		build.controls.warnings.lines = { }
		build.calcsTab.mainEnv.itemWarnings = { lineageSupportGemLimitWarning = { { '测试', 2, { 'User Group' } } } }
		build:InsertItemWarnings()
		local warning = build.controls.warnings.lines[1]
		equal(warning:find('2', 1, true) ~= nil, true, language .. ' 系谱警告数量保持')
		equal(warning:find('User Group', 1, true) ~= nil, true, language .. ' 系谱警告位置原名保持')
		if language ~= 'en' then equal(warning:gsub('User Group', ''):find('%a'), nil, language .. ' 系谱警告位置连接语翻译') end
	end
	build.controls.warnings.lines = warningsBefore
	build.calcsTab.mainEnv.itemWarnings = itemWarningsBefore
	localisation:SetLanguage(languageBefore)
end
