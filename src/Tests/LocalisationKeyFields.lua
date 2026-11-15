-- 通过真实控件验证共享显示字段、原业务身份、动态提示和搜索切换。
return function(build, equal)
	local options = LoadModule('Modules/ConfigOptions')
	local byId = { }
	for _, option in ipairs(options) do if option.var then byId[option.var] = option end end
	local originalLabel = byId.conditionFullLife.label
	local originalInput = build.configTab.input.conditionFullLife
	local modes = {
		{ label = 'Unbuffed', labelKey = 'ui.calcs_tab.module.buff_mode_drop_list.label_4', buffMode = 'UNBUFFED' },
		{ label = 'Buffed', labelKey = 'ui.calcs_tab.module.buff_mode_drop_list.label', buffMode = 'BUFFED' },
	}
	local dropdown = new('DropDownControl'):DropDownControl(nil, { 0, 0, 200, 20 }, modes)
	local savedLow = build.calcsTab.mainOutput.LowLifePercentage
	local savedFull = build.calcsTab.mainOutput.FullLifePercentage
	local fullControl = build.configTab.varControls.conditionFullLife
	local lowControl = build.configTab.varControls.conditionLowLife
	local labels = { }
	local quest
	for _, candidate in ipairs(build.data.questRewards) do
		if candidate.useConfig ~= false then quest = candidate; break end
	end
	local questId = 'quest' .. quest.Description .. quest.Area .. quest.Info
	local originalQuestStat = quest.Stat
	local bossDamage = build.data.enemyIsBossTooltipParams.standard_damage
	local sections = LoadModule('Modules/CalcSections')
	local function checkFormats(object)
		for _, field in ipairs({ 'format', 'extra' }) do
			if object[field .. 'Key'] then
				local original = formatCalcStr(object[field], build.calcsTab.calcsEnv.player, object)
				local actual = formatCalcField(object, field, build.calcsTab.calcsEnv.player, object)
				equal(actual, original, '计算模板英文数值与旧 DSL 一致: ' .. object[field .. 'Key'])
			end
		end
		for _, child in pairs(object) do if type(child) == 'table' then checkFormats(child) end end
	end
	localisation:SetLanguage('en')
	checkFormats(sections)
	-- 直接关闭旧显示反查，证明天赋正文和真实提示框由显式引用生成。
	local shock = assert(build.spec.nodes[4])
	for _, language in ipairs({ 'en', 'zh-CN', 'zh-TW' }) do
		localisation:SetLanguage(language)
		equal(byId[questId].var, questId, language .. ' 任务配置保存身份保持原值')
		equal(quest.Stat, originalQuestStat, language .. ' 奖励属性原文供解析器使用')
		local questTooltip = byId[questId].tooltip()
		equal(questTooltip:find(localisation:Field(quest, 'Stat'), 1, true) ~= nil, true, language .. ' 任务提示显式引用奖励资源')
		for _, reward in ipairs(build.data.questRewards) do
			if reward.Options and reward.useConfig ~= false then
				local rewardId = 'quest' .. reward.Description .. reward.Area .. reward.Info
				for index, option in ipairs(reward.Options) do
					equal(byId[rewardId].list[index + 1].val, option, language .. ' 任务选项显示不改变属性解析值')
					equal(localisation:Field(byId[rewardId].list[index + 1], 'label'), localisation:Field(reward, 'Option_' .. index), language .. ' 任务下拉按相同 key 显示')
				end
			end
		end
		build.data.enemyIsBossTooltipParams.standard_damage = '12345'
		local bossTooltip = localisation:Field(build.data, 'enemyIsBossTooltip')
		equal(bossTooltip:find('12345%', 1, true) ~= nil, true, language .. ' 首领提示在显示时读取最新数值参数')
		equal(bossTooltip:find('{[%a_]') == nil, true, language .. ' 首领完整模板没有遗留参数')
		build.data.enemyIsBossTooltipParams.standard_damage = bossDamage
		local line = localisation:Line(shock, 'sd', 1)
		equal(shock.sd[1], '15% increased chance to Shock', language .. ' 天赋原属性保持英文')
		equal(line:find('15', 1, true) ~= nil, true, language .. ' 天赋数值保留')
		if language ~= 'en' then equal(line ~= shock.sd[1], true, language .. ' 天赋正文不依赖旧反查') end
		local scaled = localisation:Line(shock, 'sd', 1, '30% increased chance to Shock')
		equal(scaled:find('30', 1, true) ~= nil, true, language .. ' 天赋增效作为参数传递')
		equal(localisation:Line(shock, 'sd', 1, '30% increased Damage'), '30% increased Damage', language .. ' 改变正文不能误用旧节点引用')
		local tooltip = new('Tooltip'):Tooltip()
		build.treeTab.viewer:AddNodeTooltip(tooltip, shock, build, 0)
		local found = false
		for _, row in ipairs(tooltip.lines) do if row.text and row.text:find(line, 1, true) then found = true end end
		equal(found, true, language .. ' 真实提示框显示显式属性引用')
	end
	-- 截图节点底部的复制和构筑备注提示必须直接来自当前语言资源。
	local crushingJudgement = assert(build.spec.nodes[35739], '缺少威压裁决回归节点')
	for _, language in ipairs({ 'en', 'zh-CN', 'zh-TW', 'en' }) do
		localisation:SetLanguage(language)
		local tooltip = new('Tooltip'):Tooltip()
		build.treeTab.viewer:AddNodeTooltip(tooltip, crushingJudgement, build, 0)
		local expectedCopy = language == 'zh-CN' and '提示：按 Ctrl+C 复制此节点的文本。'
			or language == 'zh-TW' and '提示：按 Ctrl+C 複製此節點的文本。'
			or "Tip: Press Ctrl+C to copy this node's text."
		local expectedNote = language == 'zh-CN' and '按 Shift＋鼠标右键添加构筑备注（用于 PoE2 .build 导出）'
			or language == 'zh-TW' and '按 Shift＋滑鼠右鍵添加流派備註（用於 PoE2 .build 匯出）'
			or 'Shift + Right-Click to add a build note (PoE2 .build export)'
		local copyFound, noteFound = false, false
		for _, line in ipairs(tooltip.lines) do
			local text = StripEscapes(line.text or '')
			copyFound = copyFound or text == expectedCopy
			noteFound = noteFound or text == expectedNote
			if text == expectedCopy or text == expectedNote then
				equal(line.text:sub(1, #colorCodes.TIP), colorCodes.TIP, language .. ' 底部操作提示保留提示颜色')
			end
			if language ~= 'en' and line.text then
				equal(line.text:find("Tip: Press Ctrl+C to copy this node's text.", 1, true), nil, language .. ' 复制节点提示无英文回退')
				equal(line.text:find('Shift + Right-Click to add a build note', 1, true), nil, language .. ' 构筑备注提示无英文回退')
			end
		end
		equal(copyFound, true, language .. ' 威压裁决显示复制节点的完整提示与颜色')
		equal(noteFound, true, language .. ' 威压裁决显示构筑备注的完整提示与颜色')
	end
	-- 传奇天赋的风味文本通过稳定引用翻译，真实提示框保留换行、颜色和斜体。
	local originalFlavour = main.showFlavourText
	main.showFlavourText = true
	for _, language in ipairs({ 'en', 'zh-CN', 'zh-TW', 'en' }) do
		localisation:SetLanguage(language)
		local heartstopper = assert(build.spec.nodes[34497], '缺少凝心者回归节点')
		local expectedFlavour = language == 'zh-CN' and '心跳暂歇，屏息凝神。毒发虽缓，唯死难逃。'
			or language == 'zh-TW' and '心跳暫歇，屏息凝神。毒發雖緩，唯死難逃。'
			or heartstopper.flavourText
		equal(localisation:Field(heartstopper, 'flavourText'), expectedFlavour, language .. ' 凝心者风味文本切换语言')
		local count = 0
		for _, node in pairs(build.spec.nodes) do
			if node.type == 'Keystone' and node.flavourText then
				count = count + 1
				local original = node.flavourText
				local displayed = localisation:Field(node, 'flavourText')
				if language == 'en' then equal(displayed, original, '英文保留传奇天赋风味原文')
				else equal(displayed:find('%a'), nil, language .. ' 传奇天赋风味文本无英文：' .. node.dn) end
				local tooltip = new('Tooltip'):Tooltip()
				build.treeTab.viewer:AddNodeTooltip(tooltip, node, build, 0)
				local lines = { }
				for _, row in ipairs(tooltip.lines) do
					if row.font == 'FONTIN ITALIC' and row.text then
						if #lines == 0 then equal(row.text:sub(1, #colorCodes.UNIQUE), colorCodes.UNIQUE, language .. ' 风味文本保留传奇颜色') end
						lines[#lines + 1] = StripEscapes(row.text)
					end
				end
				equal(table.concat(lines):gsub('%s', ''), displayed:gsub('%s', ''), language .. ' 真实提示框显示完整风味文本：' .. node.dn)
				equal(node.flavourText, original, language .. ' 显示不改写传奇天赋原文')
			end
		end
		equal(count > 0, true, language .. ' 实际遍历传奇天赋风味文本')
	end
	main.showFlavourText = originalFlavour
	-- 野兽与幽魂库的组合标题在同一弹窗内切换语言，不把显示名写回列表。
	for _, library in ipairs({ 'beast', 'spectre' }) do
		local originalList = library == 'beast' and build.beastList or build.spectreList
		build:OpenSpectreLibrary(library)
		local popup = main.popups[#main.popups]
		for _, language in ipairs({ 'en', 'zh-CN', 'zh-TW', 'en' }) do
			localisation:SetLanguage(language)
			local kind = language == 'en' and (library == 'beast' and 'Beasts' or 'Spectres')
				or (library == 'beast' and (language == 'zh-CN' and '野兽' or '野獸') or '幽魂')
			equal(popup.controls.list:GetProperty('label'), language == 'en' and kind .. ' in Build:' or (language == 'zh-CN' and '构筑中的' or '流派中的') .. kind .. '：', language .. ' 已选召唤物列表标题')
			equal(popup.controls.source:GetProperty('label'), language == 'en' and '^7Available ' .. kind .. ':' or '^7可用' .. kind .. '：', language .. ' 可用召唤物列表标题')
			equal(popup.controls.showAllLabel:GetProperty('label'), language == 'en' and '^7Show All ' .. kind .. ':' or (language == 'zh-CN' and '^7显示全部' or '^7顯示全部') .. kind .. '：', language .. ' 显示全部召唤物标签')
			equal(library == 'beast' and build.beastList or build.spectreList, originalList, language .. ' 语言切换不修改召唤物列表')
		end
		main:ClosePopup()
	end
	for _, language in ipairs({ 'en', 'zh-CN', 'zh-TW' }) do
		localisation:SetLanguage(language)
		for _, action in ipairs({ 'toggle', 'select' }) do
			local text = localisation:Text('ui.config_tab.init.control_tooltip_func.message', { prefix = localisation:Ref('config.option.' .. action .. '_action') })
			if language == 'en' then equal(text, action == 'toggle' and '^7Toggling this option will give you:' or '^7Selecting this option will give you:', '配置比较英文完整句保持一致')
			else equal(text:find('%a'), nil, language .. ' 配置比较动作不残留英文') end
		end
	end
	-- 标题栏的灌注材料独立于正文，测宽和绘制都必须使用当前语言，保留配方与图标身份。
	do
		local materialNames = {
			Ire = { '愤怒', '憤怒' }, Guilt = { '自责', '罪惡' }, Greed = { '贪婪', '貪婪' },
			Paranoia = { '疑惧', '妄想' }, Envy = { '嫉妒', '忌妒' }, Disgust = { '厌恶', '厭惡' },
			Despair = { '绝望', '絕望' }, Fear = { '恐惧', '恐懼' }, Suffering = { '苦难', '苦難' },
			Isolation = { '孤独', '孤立' }, Melancholy = { '忧郁', '憂鬱' },
			Ferocity = { '暴烈', '兇殘' }, Contempt = { '蔑视', '蔑視' },
		}
		local escapeVelocity = assert(build.spec.nodes[17854], '缺少动如脱兔回归节点')
		local samples, covered = { escapeVelocity }, { }
		for _, node in pairs(build.spec.nodes) do
			for _, material in ipairs(node.recipe or { }) do
				assert(materialNames[material], '缺少灌注材料回归译名：' .. material)
				if not covered[material] then samples[#samples + 1] = node; covered[material] = true end
			end
		end
		for material in pairs(materialNames) do equal(covered[material], true, '实际配方覆盖材料：' .. material) end
		local viewport = { x = 0, y = 0, width = 1920, height = 1080 }
		for _, language in ipairs({ 'en', 'zh-CN', 'zh-TW', 'en' }) do
			localisation:SetLanguage(language)
			for _, node in ipairs(samples) do
				local tooltip = new('Tooltip'):Tooltip()
				build.treeTab.viewer:AddNodeTooltip(tooltip, node, build, 0)
				local measure, measured = DrawStringWidth, { }
				DrawStringWidth = function(size, font, text)
					measured[text] = true
					return measure(size, font, text)
				end
				local ok, width, height = pcall(tooltip.GetSize, tooltip)
				DrawStringWidth = measure
				assert(ok, width)
				local _, _, stack = tooltip:CalculateColumns(0, 0, height, width, viewport)
				for index, material in ipairs(node.recipe) do
					local expected = language == 'en' and material or materialNames[material][language == 'zh-CN' and 1 or 2]
					equal(measured[expected], true, language .. ' 标题栏按当前材料译名测宽：' .. material)
					equal(StripEscapes(stack[index * 2][6]), expected, language .. ' 标题栏绘制材料译名：' .. material)
					equal(stack[index * 2 + 1][1], node.infoRecipe[index].sprite, language .. ' 材料图标与配方顺序保持一致')
					equal(node.infoRecipe[index].name, material, language .. ' 显示不改写灌注配方')
				end
			end
		end
	end
	local gem
	for _, candidate in pairs(data.gems) do if candidate.name == 'Fireball' then gem = candidate; break end end
	assert(gem and gem.nameKey, '火球必须具有显式显示引用')
	for _, language in ipairs({ 'en', 'zh-CN', 'zh-TW', 'en' }) do
		localisation:SetLanguage(language)
		local label = fullControl:GetProperty('label')
		equal(type(label), 'string', language .. ' 配置标签为显示文本')
		equal(byId.conditionFullLife.label, originalLabel, language .. ' 配置业务标签保留英文身份')
		equal(build.configTab.input.conditionFullLife, originalInput, language .. ' 配置值未被显示改写')
		labels[language] = label
		equal(gem.name, 'Fireball', language .. ' 技能业务身份保留')
		equal(localisation:SkillName({ gemData = gem, nameSpec = 'Fireball' }), localisation:Field(gem, 'name'), language .. ' 技能名称按显式引用显示')
		equal(localisation:SkillName({ gemData = gem, nameSpec = 'My custom name' }), 'My custom name', language .. ' 用户自定义技能名称保留')
		equal(localisation:MatchField(gem, 'name', 'fireball'), true, language .. ' 技能英文搜索不依赖绘制词典')
		equal(localisation:MatchField(gem, 'name', localisation:Field(gem, 'name'):lower()), true, language .. ' 技能当前译文搜索')
		for _, percentage in ipairs({ 50, 65, 100 }) do
			build.calcsTab.mainOutput.LowLifePercentage = percentage
			build.calcsTab.mainOutput.FullLifePercentage = percentage
			local low = lowControl:GetProperty('tooltipText')
			local full = fullControl:GetProperty('tooltipText')
			equal(type(low), 'string', language .. ' 低血提示函数被实际求值')
			equal(low:find(tostring(100 - percentage) .. '%', 1, true) ~= nil, true, language .. ' 低血提示取当前计算值')
			equal(full:find(tostring(percentage) .. '%', 1, true) ~= nil, true, language .. ' 满血提示取当前计算值')
		end
		dropdown.searchTerm = 'Unbuffed'; dropdown:UpdateSearch()
		equal(dropdown:GetMatchCount(), 1, language .. ' 下拉英文身份可检索')
		equal(modes[1].buffMode, 'UNBUFFED', language .. ' 下拉保留业务模式')
		if language ~= 'en' then
			equal(#dropdown.searchInfos[1].ranges, 0, language .. ' 英文别名不产生中文高亮范围')
			local translated = localisation:Field(modes[1], 'label')
			dropdown.searchTerm = translated; dropdown:UpdateSearch()
			equal(dropdown:GetMatchCount(), 1, language .. ' 当前译文可检索')
			equal(#dropdown.searchInfos[1].ranges > 0, true, language .. ' 当前译文使用自身字节范围高亮')
		end
		equal(build.calcsTab:SearchMatch('unused', 'unused'), false, language .. ' 空搜索不高亮')
	end
	equal(labels.en, originalLabel, '切回英文恢复原配置标签')
	equal(labels['zh-CN'] ~= labels.en, true, '同一配置控件切简体')
	equal(labels['zh-TW'] ~= labels.en, true, '同一配置控件切繁体')
	build.calcsTab.mainOutput.LowLifePercentage = savedLow
	build.calcsTab.mainOutput.FullLifePercentage = savedFull
end
