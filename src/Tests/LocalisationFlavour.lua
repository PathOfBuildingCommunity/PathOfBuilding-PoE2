-- 风味翻译须进入真实装备和技能提示框，同时保留原文、换行、颜色及开关行为。
return function(build, equal)
	local originalLanguage = localisation.language
	local originalFlavour, originalDifferences = main.showFlavourText, build.itemsTab.showStatDifferences
	main.showFlavourText, build.itemsTab.showStatDifferences = true, false
	local entries, byName, items, skills = { }, { }, { }, { }
	for _, entry in ipairs(data.flavourText) do
		entries[#entries + 1] = { object = entry, lines = copyTable(entry.text), origin = entry.origin }
		byName[entry.name] = byName[entry.name] or { }
		table.insert(byName[entry.name], entry)
	end
	for kind, list in pairsSortByKey(data.uniques) do
		for index, raw in ipairs(list) do
			local item = new('Item'):Item(raw, 'UNIQUE')
			items[#items + 1] = { object = item, raw = item.raw, name = item.name, baseName = item.baseName, label = kind .. ':' .. index }
		end
	end
	local uniqueCount = #items
	-- 超凡肢体没有传奇数据库条目，须用实际基底额外覆盖其共享风味路径。
	for name, base in pairsSortByKey(data.itemBases) do
		if base.type == 'Transcendent Limb' then
			local item = new('Item'):Item('Rarity: NORMAL\n' .. name)
			assert(item.base, '超凡肢体基底无法解析：' .. name)
			items[#items + 1] = { object = item, raw = item.raw, name = item.name, baseName = item.baseName, label = name }
		end
	end
	for id, skill in pairsSortByKey(data.skills) do
		if skill.flavourText then
			local instance = { nameSpec = skill.name, skillId = id, level = 1, quality = 0, enabled = true }
			build.skillsTab:ProcessSocketGroup({ gemList = { instance }, enabled = true })
			skills[#skills + 1] = { object = skill, id = id, name = skill.name, lines = copyTable(skill.flavourText), instance = instance }
		end
	end
	local gemTooltip = LoadModule('Classes/GemTooltip')
	local function compact(text) return text:gsub('%s', '') end
	-- 同时检查传入提示框的整行和自动换行后的最终文本，避免仅检查资源命中。
	local function tooltip()
		local result, calls = new('Tooltip'):Tooltip(), { }
		local addLine = result.AddLine
		result.AddLine = function(self, size, text, font, ...)
			if font == 'FONTIN SC ITALIC' then calls[#calls + 1] = text end
			return addLine(self, size, text, font, ...)
		end
		return result, calls
	end
	local function checkRendered(result, calls, expected, label)
		equal(#calls, #expected, label .. ' 完整保留原始段落行数')
		for index, text in ipairs(expected) do equal(calls[index], colorCodes.UNIQUE .. text, label .. ' 保留暗金色及整行译文 ' .. index) end
		local rendered = { }
		for _, row in ipairs(result.lines) do
			if row.font == 'FONTIN SC ITALIC' and row.text then rendered[#rendered + 1] = StripEscapes(row.text) end
		end
		equal(compact(table.concat(rendered)), compact(table.concat(expected)), label .. ' 实际拆行后文字完整')
	end
	local checkedItems, checkedSkills, seenEntries = 0, 0, { }
	for _, language in ipairs({ 'en', 'zh-CN', 'zh-TW', 'en' }) do
		localisation:SetLanguage(language)
		for _, saved in ipairs(entries) do
			for index, source in ipairs(saved.lines) do
				local display = localisation:Line(saved.object, 'text', index, source)
				if language == 'en' then equal(display, source, '全部装备风味英文还原：' .. saved.object.id)
				else equal(display:find('%a'), nil, language .. ' 全部装备风味无英文回退：' .. saved.object.id) end
				equal(saved.object.text[index], source, language .. ' 装备风味数据不被改写：' .. saved.object.id)
			end
			equal(saved.object.origin, saved.origin, language .. ' 装备来源身份保持：' .. saved.object.id)
		end
		for _, saved in ipairs(items) do
			local item = saved.object
			local candidates = byName[item.base.type == 'Transcendent Limb' and 'Transcendent Limb' or item.title] or { }
			local result, calls = tooltip()
			build.itemsTab:AddItemTooltip(result, item, nil, true)
			local expected = { }
			if #candidates > 0 then
				local entry = candidates[1]
				if item.title == 'Grand Spectrum' then
					local id = ({ Ruby = 'FourUniqueJewel1', Emerald = 'FourUniqueJewel2', Sapphire = 'FourUniqueJewel3' })[item.baseName]
					entry = nil
					for _, candidate in ipairs(candidates) do if candidate.id == id then entry = candidate end end
				end
				assert(entry, '缺少装备风味身份：' .. saved.label)
				seenEntries[entry.id] = true
				for index, source in ipairs(entry.text) do expected[index] = localisation:Line(entry, 'text', index, source) end
				if language == 'zh-CN' then checkedItems = checkedItems + 1 end
			end
			checkRendered(result, calls, expected, language .. ' 装备提示框 ' .. saved.label)
			main.showFlavourText = false
			local hidden, hiddenCalls = tooltip()
			build.itemsTab:AddItemTooltip(hidden, item, nil, true)
			equal(#hiddenCalls, 0, language .. ' 装备风味开关仍生效：' .. saved.label)
			main.showFlavourText = true
			equal(item.raw, saved.raw, language .. ' 装备原始输入保持：' .. saved.label)
			equal(item.name, saved.name, language .. ' 装备计算名称保持：' .. saved.label)
			equal(item.baseName, saved.baseName, language .. ' 装备基底身份保持：' .. saved.label)
		end
		for _, saved in ipairs(skills) do
			local expected = { }
			for index, source in ipairs(saved.lines) do
				local display = localisation:Line(saved.object, 'flavourText', index, source)
				expected[index] = display
				if language == 'en' then equal(display, source, '全部传奇技能风味英文还原：' .. saved.id)
				else equal(display:find('%a'), nil, language .. ' 全部传奇技能风味无英文回退：' .. saved.id) end
				equal(saved.object.flavourText[index], source, language .. ' 技能风味原文保持：' .. saved.id)
			end
			local result, calls = tooltip()
			gemTooltip.AddGemTooltip(result, build, saved.instance, { })
			checkRendered(result, calls, expected, language .. ' 技能提示框 ' .. saved.id)
			main.showFlavourText = false
			local hidden, hiddenCalls = tooltip()
			gemTooltip.AddGemTooltip(hidden, build, saved.instance, { })
			equal(#hiddenCalls, 0, language .. ' 技能风味开关仍生效：' .. saved.id)
			main.showFlavourText = true
			equal(saved.object.name, saved.name, language .. ' 技能计算名称保持：' .. saved.id)
			equal(saved.instance.skillId, saved.id, language .. ' 技能保存身份保持：' .. saved.id)
			if language == 'zh-CN' then checkedSkills = checkedSkills + 1 end
		end
	end
	for _, saved in ipairs(entries) do equal(seenEntries[saved.object.id], true, '所有装备风味身份均已进入实际提示框：' .. saved.object.id) end
	assert(checkedItems > 0 and checkedSkills > 0, '风味提示框覆盖不能为空')
	print('风味真实提示框回归：传奇装备 ' .. uniqueCount .. ' 个，超凡肢体 ' .. (#items - uniqueCount) .. ' 个；风味装备 ' .. checkedItems .. ' 个；技能 ' .. checkedSkills .. ' 个；装备风味数据 ' .. #entries .. ' 组')
	main.showFlavourText, build.itemsTab.showStatDifferences = originalFlavour, originalDifferences
	localisation:SetLanguage(originalLanguage)
end
