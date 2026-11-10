-- 截图中的配置控件必须显式翻译，并保留配置值、任务解析文本和自定义标题。
return function(build, equal)
	local tab = build.configTab
	local options = LoadModule('Modules/ConfigOptions')
	local originalLanguage = localisation.language
	local saved = { }
	tab:Save(saved)
	local samples = {
		warcryMode = true, conditionHitMeleeRecently = true, conditionCritInPast8Sec = true,
		conditionShapeshifted = true, conditionTriggeredSkillRecently = true, configResonanceCount = true,
		twisterCold = true, twisterFire = true, twisterLightning = true,
		whirlwindStages = true, whirlwindBuffCold = true, whirlwindBuffFire = true, whirlwindBuffLightning = true,
		enemyEvasion = true, enemyIsBoss = true, presetBossSkills = true,
		enemyLightningResist = true, enemyColdResist = true, enemyFireResist = true, enemyChaosResist = true,
		enemyLightningDamage = true, enemyColdDamage = true, enemyFireDamage = true, enemyChaosDamage = true,
		enemyLightningPen = true, enemyColdPen = true, enemyFirePen = true,
		conditionEnemyFullLife = true, conditionEnemyLowLife = true, conditionEnemyBurning = true,
		conditionEnemyIgnited = true, conditionEnemyChilled = true, conditionEnemyChilledEffect = true,
		conditionEnemyFrozen = true, conditionEnemyShocked = true, conditionEnemyElectrocuted = true,
	}
	local titles = {
		['ui.config_options.module.config_settings.label_80'] = true,
		['ui.config_options.module.config_settings.label_81'] = true,
		['ui.config_options.module.config_settings.label_90'] = true,
		['ui.config_options.module.config_settings.label_91'] = true,
	}
	local found = { }
	local function numbers(text)
		local values = { }
		for value in text:gmatch('[%+%-]?%d+%.?%d*%%?') do values[#values + 1] = value end
		return table.concat(values, '|')
	end
	local defaultKey = 'ui.config_tab.custom_mod_block_control.delete_btn.title'
	local set = tab.configSets[tab.activeConfigSetId]
	set.customModsList = {
		{ title = 'Default', titleKey = defaultKey, text = '', enabled = true },
		{ title = 'Default', text = '', enabled = true },
		{ title = 'Fireball 用户输入', text = '10% increased Damage', enabled = true },
	}
	tab:UpdateCustomModsControls()
	for _, language in ipairs({ 'en', 'zh-CN', 'zh-TW', 'en' }) do
		localisation:SetLanguage(language)
		for _, option in ipairs(options) do
			-- 勾选项固定使用14字号，不能套用普通标签的12字号回退规则。
			if language ~= 'en' and option.var and option.label then
				local text = localisation:Field(option, 'label')
				if text ~= option.label then
					local size = option.type ~= 'check' and DrawStringWidth(14, 'VAR', text) > 228 and 12 or 14
					equal(DrawStringWidth(size, 'VAR', text) <= 228, true, language .. ' 全配置标签适配列宽：' .. option.labelKey)
				end
			end
			if samples[option.var] or titles[option.labelKey] then
				found[option.var or option.labelKey] = true
				local text = localisation:Field(option, 'label')
				local displayed = false
				for _, control in pairs(tab.controls) do
					if control.label then
						local label = control:GetProperty('label')
						displayed = displayed or label == text or label == '^7' .. text
					end
				end
				equal(displayed, true, language .. ' 实际配置控件使用显示资源：' .. option.labelKey)
				if language == 'en' then
					equal(text, option.label, '配置英文标签保持原文')
				else
					equal(StripEscapes(text):find('%a'), nil, language .. ' 截图配置标签无英文：' .. option.labelKey)
					local size = DrawStringWidth(14, 'VAR', text) > 228 and 12 or 14
					equal(DrawStringWidth(size, 'VAR', text) <= 228, true, language .. ' 配置标签适配列宽：' .. option.labelKey)
				end
				if type(option.tooltip) == 'string' then
					local tooltip = localisation:Field(option, 'tooltip')
					if language == 'en' then equal(tooltip, option.tooltip, '配置英文提示保持原文')
					else equal(StripEscapes(tooltip):find('%a'), nil, language .. ' 对应配置提示无英文：' .. option.tooltipKey) end
				end
				for _, entry in ipairs(option.list or { }) do
					if language ~= 'en' and option.var == 'enemyIsBoss' then
						equal(StripEscapes(localisation:Field(entry, 'label')):find('%a'), nil, language .. ' 首领下拉选项无英文')
					end
				end
			end
		end
		for _, quest in ipairs(build.data.questRewards) do
			for _, field in ipairs({ 'Area', 'Description', 'Info', 'Stat', 'Option_1', 'Option_2', 'Option_3', 'Option_4', 'Option_5', 'Option_6', 'Option_7' }) do
				if quest[field .. 'Key'] and language ~= 'en' then
					equal(StripEscapes(localisation:Field(quest, field)):find('%a'), nil, language .. ' 任务奖励字段完整翻译：' .. quest[field .. 'Key'])
					if field == 'Stat' or field:match('^Option_') then
						local original = quest[field] or quest.Options[tonumber(field:match('%d+'))]
						equal(numbers(localisation:Field(quest, field)), numbers(original), language .. ' 奖励数值、正负号、百分比及顺序保持：' .. quest[field .. 'Key'])
					end
				end
			end
		end
		local blocks = tab.customModsBlockControls
		equal(blocks[1].controls.titleEdit.inactiveText('Default'), language == 'en' and 'Default' or language == 'zh-CN' and '默认' or '預設', language .. ' 自动生成的词缀组标题翻译')
		equal(blocks[1].controls.titleEdit.buf, 'Default', language .. ' 编辑缓冲区保留默认标题原文')
		equal(blocks[2].controls.titleEdit.inactiveText('Default'), 'Default', language .. ' 用户输入的同名标题不推测翻译')
		equal(blocks[3].controls.titleEdit.inactiveText('Fireball 用户输入'), 'Fireball 用户输入', language .. ' 用户标题保持原样')
		equal(blocks[3].controls.textEdit.buf, '10% increased Damage', language .. ' 自定义词缀保持解析原文')
		if language ~= 'en' then
			equal(StripEscapes(tab.controls.customModsAddBlock:GetProperty('label')):find('%a'), nil, language .. ' 添加词缀组按钮翻译')
			equal(StripEscapes(blocks[1].controls.addModBtn:GetProperty('label')):find('%a'), nil, language .. ' 添加词缀按钮翻译')
		end
	end
	for id in pairs(samples) do equal(found[id], true, '覆盖截图配置项：' .. id) end
	for key in pairs(titles) do equal(found[key], true, '覆盖截图技能标题：' .. key) end
	-- 保存与重载保留默认标题标记；未带标记的旧标题保留为用户文本。
	local roundtrip = { }
	tab:Save(roundtrip)
	tab:Load(roundtrip, 'localisation-config-test')
	local blocks = tab.configSets[tab.activeConfigSetId].customModsList
	equal(blocks[1].titleKey, defaultKey, '默认标题翻译标记经过保存重载仍保留')
	equal(blocks[2].titleKey, nil, '同名自定义标题经过重载仍不翻译')
	equal(blocks[3].title, 'Fireball 用户输入', '用户标题经过重载不改写')
	local edit = tab.customModsBlockControls[1].controls.titleEdit
	edit:SetText('我的词缀组', true)
	equal(blocks[1].titleKey, nil, '编辑默认标题后取消翻译标记')
	equal(blocks[1].title, '我的词缀组', '标题编辑回调保存用户输入')
	tab:Load(saved, 'localisation-config-restore')
	local restored = { }
	tab:Save(restored)
	equal(common.xml.ComposeXML(restored), common.xml.ComposeXML(saved), '配置值和原有任务选项经过语言切换保持不变')
	localisation:SetLanguage(originalLanguage)
end
