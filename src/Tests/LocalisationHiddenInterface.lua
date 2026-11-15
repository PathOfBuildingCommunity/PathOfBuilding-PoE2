-- 使用实际计算与控件验证隐藏分支；交易数据加载用离线桩，禁止网络、搜索和私聊。
return function(build, equal)
	local languageBefore = localisation.language
	local calcs = require('Modules.CalcBase')
	local snapshots = { }
	for _, language in ipairs({ 'en', 'zh-CN', 'zh-TW', 'en' }) do
		localisation:SetLanguage(language)
		for _, base in ipairs({ 1, 3 }) do
			for _, extra in ipairs({ 0, 1, 2 }) do
				local env = calcs.buildOutput(build, 'CALCS')
				local skill = env.player.mainSkill
				skill.skillData.storedUses = base
				skill.skillModList:NewMod('AdditionalCooldownUses', 'BASE', extra, 'Localisation Test')
				calcs.offence(env, env.player, skill)
				equal(env.player.output.StoredUses, base + extra, language .. ' 使用次数计算保持')
				local lines = env.player.breakdown.StoredUses
				equal(#lines, extra == 0 and 1 or 3, language .. ' 使用次数详情分支保持')
				if language == 'en' then
					equal(lines[1], string.format('%d ^8(skill use%s)', base, base == 1 and '' or 's'), '英文基础使用次数单复数保持')
					if extra ~= 0 then
						equal(lines[2], string.format('+ %d ^8(additional use%s)', extra, extra == 1 and '' or 's'), '英文额外使用次数单复数保持')
						equal(lines[3], string.format('= %d ^8(total uses)', base + extra), '英文总使用次数保持')
					end
				else
					for _, line in ipairs(lines) do equal(StripEscapes(line):find('%a'), nil, language .. ' 实际使用次数详情无复数后缀残留') end
				end
				local key = base .. ':' .. extra
				snapshots[key] = snapshots[key] or env.player.output.StoredUses
				equal(env.player.output.StoredUses, snapshots[key], language .. ' 切换语言不改变使用次数')
			end
		end
	end
	-- 实际涂抹弹窗按控件身份判断遮挡，标题解析函数不能参与业务判断。
	local itemBefore, slotBefore = build.itemsTab.displayItem, build.itemsTab.anointEnchantSlot
	build.itemsTab.displayItem = new('Item'):Item(build.itemsTab.items[build.itemsTab.slots.Amulet.selItemId]:BuildRaw())
	local sourceRaw = build.itemsTab.displayItem:BuildRaw()
	local node
	for _, candidate in pairs(build.spec.tree.nodes) do
		if candidate.type == 'Notable' and candidate.sd[1] and not build.spec.allocNodes[candidate.id] then node = candidate; break end
	end
	equal(node ~= nil, true, '涂抹回归具备未分配天赋样本')
	build.itemsTab:AnointDisplayItem(1)
	local popup = main.popups[1]
	local comparesBefore, header = build.AddStatComparesToTooltip
	build.AddStatComparesToTooltip = function(self, tooltip, base, changed, text, ...)
		header = text
		return comparesBefore(self, tooltip, base, changed, text, ...)
	end
	local themeBefore = main.nodePowerTheme
	for _, language in ipairs({ 'en', 'zh-CN', 'zh-TW', 'en' }) do
		localisation:SetLanguage(language)
		equal(type(popup.title), 'function', language .. ' 涂抹标题保持动态解析')
		local tooltip = new('Tooltip'):Tooltip()
		popup.controls.notableDB:AddValueTooltip(tooltip, 1, node)
		equal(#tooltip.lines > 0, true, language .. ' 实际涂抹弹窗悬停天赋说明可见')
		if language == 'en' then equal(header, '^7Anointing ' .. node.dn .. ' will give you: ', '英文涂抹对比标题保持')
		else equal(StripEscapes(header):find('%a'), nil, language .. ' 涂抹对比标题和天赋名翻译') end
		popup.controls.notableDB.controls.sort.dropped = true
		popup.controls.notableDB:AddValueTooltip(tooltip, 1, node)
		equal(#tooltip.lines, 0, language .. ' 下拉菜单遮挡时仍隐藏天赋说明')
		popup.controls.notableDB.controls.sort.dropped = false
		main:OpenPopup(100, 100, 'Other popup', { })
		popup.controls.notableDB:AddValueTooltip(tooltip, 1, node)
		equal(#tooltip.lines, 0, language .. ' 其他弹窗遮挡时仍隐藏天赋说明')
		main:ClosePopup()
		build.itemsTab:AppendAnointTooltip(tooltip, nil)
		if language == 'en' then equal(header, '^7Anointing nothing will give you: ', '英文移除涂抹对比标题保持')
		else equal(StripEscapes(header):find('%a'), nil, language .. ' 移除涂抹对比标题翻译') end
		local original = build.itemsTab.displayItem
		build.itemsTab.displayItem = build.itemsTab:anointItem(node)
		local removeLabel = popup.controls.save:GetProperty('label')
		if language == 'en' then equal(removeLabel, localisation:Text('equipment.anoint.remove', { anoint = node.dn }), '英文移除涂抹按钮保持')
		else equal(StripEscapes(removeLabel):find('%a'), nil, language .. ' 移除涂抹按钮天赋名翻译') end
		build.itemsTab.displayItem = original
		equal(original:BuildRaw(), sourceRaw, language .. ' 悬停与切换语言不修改原物品')
		for _, theme in ipairs({ 'RED/BLUE', 'RED/GREEN', 'GREEN/BLUE' }) do
			main.nodePowerTheme = theme
			local text = build.treeTab.controls.treeHeatMap:GetProperty('tooltipText')
			if language ~= 'en' then equal(StripEscapes(text):find('%a'), nil, language .. ' 三种强度图配色说明翻译') end
		end
		for _, slot in ipairs(build.itemsTab.runeSlotOrder) do
			local text = build.itemsTab.controls[slot .. ' Label']:GetProperty('label')
			if language ~= 'en' then equal(StripEscapes(text):find('%a'), nil, language .. ' 角色符文槽标签翻译：' .. slot) end
		end
	end
	main.nodePowerTheme = themeBefore
	build.AddStatComparesToTooltip = comparesBefore
	main:ClosePopup()
	build.itemsTab.displayItem, build.itemsTab.anointEnchantSlot = itemBefore, slotBefore
	-- 使用独立交易对象读取真实控件；离线数据桩不验证联网交易功能。
	new('TradeQueryGenerator')
	local generatorClass = common.classes.TradeQueryGenerator
	local initModsBefore, downloadBefore = generatorClass.InitMods, launch.DownloadPage
	local tokenBefore, leaguesBefore = main.api.authToken, build.itemsTab.leagueDropList
	local frameBefore = main.onFrameFuncs.TradeQueryGenerator
	local popupsBefore = #main.popups
	generatorClass.InitMods = function(self) self.modData = { } end
	launch.DownloadPage = function() error('隐藏文案回归禁止网络请求') end
	main.api.authToken = nil
	local query = new('TradeQuery'):TradeQuery(build.itemsTab)
	query.realmDropList, query.pbRealm = { }, 'poe2'
	query.pbCurrencyConversion.poe2 = { timestamp = os.time() }
	query:PriceItem()
	generatorClass.InitMods = initModsBefore
	local notable = new('NotableDBControl'):NotableDBControl(nil, { 0, 0, 360, 500 }, build.itemsTab, { }, 'Notable')
	notable:ListBuilder()
	for _, language in ipairs({ 'en', 'zh-CN', 'zh-TW', 'en' }) do
		localisation:SetLanguage(language)
		for _, name in ipairs({ 'StatWeightMultipliersButton', 'otherTradesLabel' }) do
			local label = StripEscapes(query.controls[name]:GetProperty('label'))
			if language ~= 'en' then equal(label:find('%a'), nil, language .. ' 实际交易标签翻译：' .. name) end
		end
		local tooltip = new('Tooltip'):Tooltip()
		query.controls.fetchCountEdit.tooltipFunc(tooltip)
		equal(#tooltip.lines, 3, language .. ' 获取页数实际提示三行')
		for _, line in ipairs(tooltip.lines) do
			if language ~= 'en' then equal(line.text:gsub('PoE', ''):find('%a'), nil, language .. ' 页数说明完整翻译') end
		end
		for _, slot in ipairs({ build.itemsTab.slots.Amulet, build.itemsTab.slots['Weapon 1'] }) do
			query.tradeQueryGenerator:RequestQuery(slot, { slotTbl = { unique = true } }, { }, function() error('隐藏文案回归禁止交易查询') end)
			local controls = main.popups[1].controls
			local behaviour = controls.anointBehaviour or controls.augmentBehaviour
			local text = behaviour:GetProperty('tooltipText')
			if language == 'en' then
				equal(text:find('Controls how ', 1, true) == 1, true, '英文策略说明保持')
			else
				equal(StripEscapes(text):find('%a'), nil, language .. ' 实际符文／涂抹策略完整翻译')
				equal(StripEscapes(controls.maxLevelLabel:GetProperty('label')):find('%a'), nil, language .. ' 最高等级短标签翻译')
			end
			equal(behaviour:GetSelValue(), 'Copy Current', language .. ' 策略业务值保持原文')
			main:ClosePopup()
		end
		local count = 0
		for name, available in pairs(notable.emotionsAvailable) do
			count = count + 1
			equal(available, true, language .. ' 原材料筛选状态保持')
			local text = notable.controls['emotionCheckbox' .. name]:GetProperty('tooltipText')
			if language == 'en' then equal(text, 'Distilled ' .. name, '英文材料提示保持原名')
			else equal(text:find('%a'), nil, language .. ' 实际材料提示包含中文名称') end
		end
		equal(count, 13, language .. ' 实际材料筛选覆盖十三种身份')
		local drawBefore, drawn = DrawString, false
		DrawString = function(x, y, align, size, font, text)
			if text == localisation:Text('ui.notable_dbcontrol.no_matches') then drawn = true end
		end
		notable.ListControl.Draw(notable, { x = 0, y = 0, width = 1920, height = 1080 })
		DrawString = drawBefore
		equal(drawn, true, language .. ' 已缓存空筛选结果随语言实际绘制')
	end
	while #main.popups > popupsBefore do main:ClosePopup() end
	main.api.authToken, build.itemsTab.leagueDropList = tokenBefore, leaguesBefore
	main.onFrameFuncs.TradeQueryGenerator, launch.DownloadPage = frameBefore, downloadBefore
	localisation:SetLanguage(languageBefore)
end
