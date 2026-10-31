-- 用截图对应构筑检查计算页真实绘制、动态效果列表和固定标签列宽。
return function(build, equal)
	local tab = build.calcsTab
	local originalLanguage = localisation.language
	local actor = tab.calcsEnv.player
	local originalOutput = { }
	for key, value in pairs(actor.output) do
		if type(value) ~= 'table' then originalOutput[key] = value end
	end
	local originalNames = { }
	for id, skill in pairs(build.data.skills) do originalNames[id] = skill.name end
	local formatter = LoadModule('Modules/CalcDisplay').New(build.data.skills)
	local sample = { output = {
		BuffList = 'Barrage, Blazing Critical, Cannibalism II, Charge Infusion, Clarity II, Combat Frenzy, EternalRage, Rage, ArmourBreak, Herald of Ice, Precision I, Purity of Fire',
		CombatList = '3 Power Charges, 3 Frenzy Charges, 3 Endurance Charges',
		CurseList = "Sniper's Mark, Wither (3 stacks)",
		CustomList = 'User Build (3 stacks), 3 Custom Power Charges',
	} }
	local rawLists = { }
	for key, value in pairs(sample.output) do rawLists[key] = value end
	local viewport = { x = 0, y = 0, width = 1920, height = 1080 }
	local buffCells = { }
	for _, section in ipairs(tab.sectionList) do
		if section.id == 'SkillSelect' then
			for _, row in ipairs(section.subSection[1].data) do
				if row[1].formatDisplay then buffCells[row[1].format] = row[1] end
			end
		end
	end
	for _, language in ipairs({ 'en', 'zh-CN', 'zh-TW', 'en' }) do
		localisation:SetLanguage(language)
		local rows, drawn, widths = { }, { }, { }
		local draw, cursor = DrawString, GetCursorPos
		DrawString = function(x, y, align, size, font, text)
			local plain = StripEscapes(text)
			drawn[plain] = true
			if align == 'RIGHT_X' then
				rows[#rows + 1] = plain
				widths[#widths + 1] = { text = plain, width = DrawStringWidth(size, font, text) }
			end
		end
		GetCursorPos = function() return -1000, -1000 end
		local ok, err = pcall(function()
			for _, section in ipairs(tab.sectionList) do
				section:UpdateSize()
				section:UpdatePos()
				section:DrawContent(0, 0, section.width, actor, viewport, false, true)
				if section.id == 'Crit' then section:DrawContent(0, 0, section.width, actor, viewport, true, true) end
			end
		end)
		DrawString, GetCursorPos = draw, cursor
		assert(ok, err)
		equal(#rows > 70, true, language .. ' 实际覆盖计算页多分区标签')
		if language ~= 'en' then
			for _, text in ipairs(rows) do equal(text:find('%a'), nil, language .. ' 截图计算页标签没有英文：' .. text) end
			for _, row in ipairs(widths) do equal(row.width <= 130, true, language .. ' 译文适配固定标签列：' .. row.text) end
		end
		for field, raw in pairs(rawLists) do
			local text = formatter:EffectList(sample, field)
			if language == 'en' or field == 'CustomList' then
				equal(text, raw, language .. ' 英文和未知用户列表保持原文：' .. field)
			else
				equal(text:gsub(' II', ''):gsub(' I', ''):find('%a'), nil, language .. ' 截图效果列表完整翻译并保留宝石阶级：' .. field)
				if field == 'CombatList' then
					local count = 0
					for number in text:gmatch('%d+') do equal(number, '3', language .. ' 充能球数量保持'); count = count + 1 end
					equal(count, 3, language .. ' 三类充能球保持顺序与数量')
				end
			end
			equal(sample.output[field], raw, language .. ' 显示不改写原始效果输出：' .. field)
		end
		for _, field in ipairs({ 'BuffList', 'CombatList', 'CurseList' }) do
			local cell = assert(buffCells['{output:' .. field .. '}'])
			equal(cell.formatDisplay(sample), formatter:EffectList(sample, field), language .. ' 真实计算单元格使用动态显示适配：' .. field)
			if actor.output[field] ~= '' then
				equal(drawn[formatter:EffectList(actor, field)], true, language .. ' 动态列表进入真实绘制：' .. field)
			end
		end
		-- 置顶浮窗复用同一绘制路径，较长主手标签也必须完整显示。
		local longLabel = localisation:Text('ui.calc_sections.crit.main_hand.label_4') .. ':'
		equal(drawn[longLabel], true, language .. ' 实际绘制主手暴击伤害倍率标签')
		for key, value in pairs(originalOutput) do
			equal(actor.output[key] == value or type(value) == 'number' and value ~= value and actor.output[key] ~= actor.output[key], true, language .. ' 计算输出保持：' .. key)
		end
		for id, name in pairs(originalNames) do equal(build.data.skills[id].name, name, language .. ' 技能业务名称保持：' .. id) end
	end
	localisation:SetLanguage(originalLanguage)
end
