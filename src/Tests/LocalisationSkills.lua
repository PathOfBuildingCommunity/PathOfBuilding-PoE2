-- 验证技能名称与提示框的实际显示，以及编辑、搜索和保存身份。
return function(build, equal)
	local skillsTab = build.skillsTab
	local group = { gemList = { { nameSpec = 'Fulminating Concoction', level = 20, quality = 0, enabled = true, enableGlobal1 = true, enableGlobal2 = true, count = 1 } }, enabled = true }
	skillsTab:ProcessSocketGroup(group)
	local instance = group.gemList[1]
	assert(instance.gemData, '雷鸣灵药未识别为真实技能')
	local savedGroup = skillsTab.displayGroup
	skillsTab:SetDisplayGroup(group)
	local selector = skillsTab.gemSlots[1].nameSpec
	local viewport = { x = 0, y = 0, width = 1920, height = 1080 }
	local tooltipModule = LoadModule('Classes/GemTooltip')
	-- 禁用旧反查，确保技能显示来自显式资源引用。
	for _, language in ipairs({ 'en', 'zh-CN', 'zh-TW', 'en' }) do
		localisation:SetLanguage(language)
		local expectedName = localisation:Field(instance.gemData, 'name')
		-- 截图中的组标签、武器组和操作提示必须在同一控件上随语言切换。
		local expectedPrompt = language == 'zh-CN' and '标签' or language == 'zh-TW' and '標簽' or 'Label'
		equal(skillsTab.controls.groupLabel:GetProperty('prompt'), expectedPrompt, language .. ' 组标签提示按稳定资源显示')
		local expectedTip = language == 'zh-CN' and '^7使用技巧:\n- 按 Ctrl+C 复制插槽组，按 Ctrl+V 粘贴。\n- 按住 Ctrl 并单击，启用或禁用插槽组。\n- 按住 Ctrl 并右键单击，将插槽组计入或移出完整 DPS 计算。\n- 右键单击，设为主技能组。\n'
			or localisation:Text('ui.skills_tab.init.group_tip.label')
		equal(skillsTab.controls.groupTip:GetProperty('label'), expectedTip, language .. ' 插槽组操作提示完整翻译')
		local promptDraw, prompts = DrawString, { }
		DrawString = function(x, y, align, size, font, text) prompts[StripEscapes(text)] = true end
		local promptOk, promptError = pcall(skillsTab.controls.groupLabel.Draw, skillsTab.controls.groupLabel, viewport, true)
		if promptOk then skillsTab.controls.groupTip:Draw() end
		DrawString = promptDraw
		assert(promptOk, promptError)
		equal(prompts[expectedPrompt .. ':'], true, language .. ' 真实标签编辑框绘制当前译文')
		equal(prompts[StripEscapes(expectedTip)], true, language .. ' 底部提示绘制完整多行文字')
		for set, control in ipairs({ skillsTab.controls.set1Enabled, skillsTab.controls.set2Enabled }) do
			local label = language == 'zh-CN' and '武器组 ' .. set .. '：' or language == 'zh-TW' and '武器組 ' .. set .. '：' or 'Set ' .. set .. ':'
			equal(control:GetProperty('label'), label, language .. ' 武器组动态标签使用当前译文')
			local labelX = control:GetPos() - 5 - DrawStringWidth(16, 'VAR', label)
			local previous = set == 1 and skillsTab.anchorGroupDetail or skillsTab.controls.set1Enabled
			equal(labelX >= previous:GetPos() + (set == 1 and 0 or previous:GetSize()), true, language .. ' 武器组 ' .. set .. ' 标签不覆盖左侧列表或复选框：' .. labelX .. ' / ' .. previous:GetPos())
			local checkboxDraw, labels = DrawString, { }
			DrawString = function(x, y, align, size, font, text) labels[text] = true end
			local checkboxOk, checkboxError = pcall(control.Draw, control, viewport, true)
			DrawString = checkboxDraw
			assert(checkboxOk, checkboxError)
			equal(labels[label], true, language .. ' 武器组复选框实际绘制中文标签')
			-- 用真实锁定状态触发无效颜色，避免翻译时丢失可用性反馈。
			local source, slot, set1, set2 = group.source, group.slot, group.set1, group.set2
			group.source, group.slot, group.set1, group.set2 = 'Default Attack', 'Weapon 1', set ~= 1, set ~= 2
			equal(control:GetProperty('label'), colorCodes.NEGATIVE .. label, language .. ' 锁定武器组保留无效颜色')
			equal(control:IsEnabled(), false, language .. ' 锁定武器组仍禁止编辑')
			group.source, group.slot, group.set1, group.set2 = source, slot, set1, set2
		end
		local mainIndex, list = build.mainSocketGroup, skillsTab.controls.groupList
		local displayLabel, enabled, fullDPS, groupLabel = group.displayLabel, group.enabled, group.includeInFullDPS, group.label
		group.displayLabel = '用户组 Fireball'
		group.label = '用户组 Fireball'
		for _, active in ipairs({ true, false }) do
			for _, state in ipairs({ true, false }) do
				group.enabled, group.includeInFullDPS = state, true
				local suffix = language == 'en' and (active and (state and ' (Active)' or ' (Forced Active)') or '')
					or (active and (state and ' （当前主技能）' or ' （强制启用）') or '')
				if language == 'zh-TW' then suffix = active and (state and ' （目前主技能）' or ' （強制啟用）') or '' end
				local disabled = state and '' or ' ' .. localisation:Text('skill.group.status.disabled')
				local expected = (not active and not state and '^x7F7F7F' or '') .. '用户组 Fireball' .. disabled
					.. (active and colorCodes.RELIC or '') .. suffix .. colorCodes.CUSTOM .. ' '
					.. (language == 'en' and '(FullDPS)' or language == 'zh-CN' and '（计入完整 DPS）' or '（計入完整秒傷）')
				equal(list:GetRowValue(1, active and mainIndex or mainIndex + 1, group), expected, language .. ' 列表主技能/禁用/完整伤害状态已翻译且保留颜色')
			end
		end
		group.displayLabel, group.enabled, group.includeInFullDPS = displayLabel, enabled, fullDPS
		group.label = groupLabel
		local copy, copied = Copy
		Copy = function(text) copied = text end
		skillsTab:CopySocketGroup(group)
		Copy = copy
		equal(copied:find('Weapon Set: Both\r\n', 1, true) ~= nil, true, language .. ' 插槽组复制保留协议武器组身份')
		equal(copied:find('Fulminating Concoction 20/0', 1, true) ~= nil, true, language .. ' 插槽组复制保留技能原名与等级')
		equal(group.set1, true, language .. ' 显示翻译未改第一武器组')
		equal(group.set2, true, language .. ' 显示翻译未改第二武器组')
		local draw, drawn = DrawString, { }
		DrawString = function(x, y, align, height, font, text)
			drawn[#drawn + 1] = tostring(text)
			return draw(x, y, align, height, font, text)
		end
		selector.hasFocus = false
		local ok, err = pcall(selector.Draw, selector, viewport, true)
		DrawString = draw
		equal(ok, true, language .. ' 技能名称控件绘制: ' .. tostring(err))
		equal(table.concat(drawn):find(expectedName, 1, true) ~= nil, true, language .. ' 已选技能显示当前语言名称')
		equal(selector.buf, 'Fulminating Concoction', language .. ' 显示译名不改写编辑缓冲区')
		equal(instance.nameSpec, 'Fulminating Concoction', language .. ' 显示译名不改写保存名称')
		local tooltip = new('Tooltip'):Tooltip()
		tooltipModule.AddGemTooltip(tooltip, build, instance, { includeBuildPlannerNote = true })
		local lines = { }
		for _, line in ipairs(tooltip.lines) do
			if line.text then lines[#lines + 1] = StripEscapes(line.text) end
		end
		local text = table.concat(lines, '\n')
		local description = localisation:Field(instance.gemData.grantedEffect, 'description')
		if language ~= 'en' then
			equal(description ~= instance.gemData.grantedEffect.description, true, language .. ' 雷鸣灵药长描述已翻译')
			equal(text:find('Consume charges', 1, true), nil, language .. ' 真实提示框没有英文技能描述')
			equal(text:find('AoE', 1, true), nil, language .. ' 标签组合已翻译')
			equal(text:find('Unarmed', 1, true), nil, language .. ' 武器需求已翻译')
			equal(text:find('Cost:', 1, true), nil, language .. ' 消耗字段已翻译')
			equal(text:find(' of ', 1, true), nil, language .. ' 攻击字段没有残留英文')
			equal(text:find('(Max)', 1, true), nil, language .. ' 最高等级已翻译')
			equal(text:find('Right-Click', 1, true), nil, language .. ' 构筑备注提示已翻译')
		else
			equal(description, instance.gemData.grantedEffect.description, '英文描述保持原文')
			equal(text:find('AoE, Projectile, Lightning', 1, true) ~= nil, true, '英文标签保持原文')
		end
		local ambiguousError = skillsTab:FindSkillGem(language == 'zh-TW' and '寒冰碎片' or '冰屑')
		if language == 'zh-TW' then
			equal(type(ambiguousError), 'string', language .. ' 同名技能明确报告歧义')
		end
		-- 编辑时仍使用原文光标，离开编辑后也不能误译自定义输入。
		selector.hasFocus = true
		local editing = { }
		DrawString = function(x, y, align, height, font, value)
			editing[#editing + 1] = tostring(value)
			return draw(x, y, align, height, font, value)
		end
		local editOk, editError = pcall(selector.EditControl.Draw, selector, viewport, true)
		DrawString = draw
		equal(editOk, true, language .. ' 技能编辑控件绘制: ' .. tostring(editError))
		equal(table.concat(editing):find('Fulminating Concoction', 1, true) ~= nil, true, language .. ' 编辑时保留英文原文')
		selector.hasFocus = false
		selector:SetText('Fireball 用户输入')
		equal(selector.inactiveText(selector.buf), 'Fireball 用户输入', language .. ' 未确认输入保持原文')
		selector:SetText(instance.nameSpec)
	end
	-- 全部运行时技能和宝石检查实际绑定，防止资源存在却没有进入显示链路。
	for _, language in ipairs({ 'zh-CN', 'zh-TW' }) do
		localisation:SetLanguage(language)
		-- 描述引用其他技能时沿用其名称，避免正文另起译名。
		for _, reference in ipairs({
			{ 'apocalypseplayer', 'apocalypseplayer' },
			{ 'chilledgroundoasisconvertwaterdjinn', 'chilledgroundoasisconvertwaterdjinn' },
			{ 'greathuntpackleaderminion', 'greathuntpackleaderminion' },
			{ 'icearmourskeletonmageminion', 'icearmourskeletonmageminion' },
			{ 'grimfeastresummonplayer', 'grimfeastplayer' },
			{ 'nightfallembracethefallplayer', 'nightfallsoaringmidnightplayer' },
			{ 'supportboneshrapnelplayer', 'triggeredboneshrapnelplayer' },
			{ 'supportburningrunesplayer', 'triggeredburningrunesplayer' },
			{ 'supportcorruptingcryplayerthree', 'triggeredcorruptingcrythreeplayer' },
			{ 'supportkhatalsrejuvenationplayer', 'supportkhatalsrejuvenationplayer' },
			{ 'supporttrickstersshardplayer', 'triggeredfracturedselfplayer' },
			{ 'thestarsanswerplayer', 'thestarsanswercometplayer' },
			{ 'triggeredabyssalapparitionplayer', 'triggeredabyssalapparitionplayer' },
			{ 'triggeredskitteringstoneplayer', 'triggeredskitteringstoneplayer' },
			{ 'triggeredskitteringstoneplayertwo', 'triggeredskitteringstoneplayertwo' },
			{ 'triggeredstaticshocksplayer', 'triggeredstaticshocksplayer' },
			{ 'wolfpouncemarkplayer', 'wolfpouncesummonwolfplayer' },
			{ 'wolfpouncesummonwolfplayer', 'wolfpouncemarkplayer' },
		}) do
			local description = localisation:Text('game.skill.' .. reference[1] .. '.description')
			local name = localisation:Text('game.skill.' .. reference[2] .. '.name')
			equal(description:find(name, 1, true) ~= nil, true, language .. ' 描述沿用既有技能名: ' .. reference[1])
		end
		-- 英文重音符号不同的同名技能，也必须复用原词库的专名。
		local establishedNames = language == 'zh-CN' and {
			morrigansinsightsupport = '莫丽根的洞察', oisinsoathsupport = '奥辛之誓',
		} or {
			morrigansinsightsupport = '莫里根的洞察', oisinsoathsupport = '歐辛的誓言',
		}
		for identity, expected in pairs(establishedNames) do
			equal(localisation:Text('game.gem.metadata_items_gems_skillgem' .. identity .. '.name'), expected, language .. ' 复用已有专名: ' .. identity)
		end
		local family = localisation:Text('game.gem.metadata_items_gems_skillgemuhtredaugurysupport.gem_family')
		equal(family, language == 'zh-CN' and '卡古兰的乌崔德' or '卡爾葛的烏特雷', language .. ' 人物和地域沿用既有译名')
		local manifestation = localisation:Text('game.skill.triggeredmanifestruneplayer.description')
		local manifestationName = localisation:Text('game.skill.verisiummanifestationplayer.name')
		equal(manifestation:find(manifestationName, 1, true) ~= nil, true, language .. ' 材料及化形沿用既有译名')
		for id, skill in pairs(build.data.skills) do
			if skill.description and skill.description ~= '' then
				local description = localisation:Field(skill, 'description')
				equal(description ~= skill.description, true, language .. ' 技能描述缺少译文: ' .. id)
				-- X 是范围形状的合法符号，不属于未翻译的英文正文。
				equal(description:gsub('%f[%a]X%f[%A]', ''):find('%a'), nil, language .. ' 技能描述仍含英文或游戏标记: ' .. id)
			end
		end
		for id, gem in pairs(build.data.gems) do
			for _, field in ipairs({ 'name', 'gemType', 'tagString', 'weaponRequirements', 'gemFamily' }) do
				if gem[field] and gem[field]:find('%a') then
					equal(localisation:Field(gem, field) ~= gem[field], true, language .. ' 宝石字段缺少译文: ' .. id .. '.' .. field)
				end
			end
		end
	end
	skillsTab:SetDisplayGroup(savedGroup)
end
