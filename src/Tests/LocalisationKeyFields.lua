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
	local originalTranslate = localisation.Translate
	-- 直接关闭旧显示反查，证明天赋正文和真实提示框由显式引用生成。
	localisation.Translate = function(self, text) return text end
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
	localisation.Translate = originalTranslate
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
