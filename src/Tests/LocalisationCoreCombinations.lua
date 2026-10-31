-- 用真实全 DPS 计算与备注控件验证组合文案；原数值和用户正文须保持。
return function(build, equal)
	local languageBefore = localisation.language
	local included = { }
	for _, group in ipairs(build.skillsTab.socketGroupList) do
		included[group] = group.includeInFullDPS or false
		group.includeInFullDPS = true
	end
	local expected, records = { }, 0
	local calcs = build.calcsTab.calcs
	for _, language in ipairs({ 'en', 'zh-CN', 'zh-TW', 'en' }) do
		localisation:SetLanguage(language)
		-- 来源直接取真实装备与天赋对象，覆盖两条爆炸技能来源路径。
		local sources = { }
		for _, item in pairs(build.itemsTab.items) do if item.baseName then sources[#sources + 1] = item; break end end
		for _, node in pairs(build.spec.nodes) do if node.dn and node.dnKey then sources[#sources + 1] = node; break end end
		equal(#sources, 2, language .. ' 实际装备和天赋来源样本齐全')
		for _, source in ipairs(sources) do
			local skill = { activeEffect = { srcInstance = { explodeSource = source } } }
			local name = source.name or source.dn
			if language ~= 'en' then name = source.baseName and localisation:ItemName(source) or localisation:Field(source, 'dn') end
			equal(localisation:ActiveSkillSelectionName(skill), localisation:Text('skill.active.explosion_source', { source = colorCodes[source.rarity or 'NORMAL'] .. name }), language .. ' 主技能来源模板按对象解析')
		end
		local dps = calcs.calcFullDPS(build, 'CALCULATOR', { })
		local rowsBefore = build.controls.statBox.list
		build.controls.statBox.list = { }
		build:AddDisplayStatList({ { stat = 'SkillDPS' } }, { output = { SkillDPS = dps.skills } }, 'player')
		local displayed = { }
		for _, row in ipairs(build.controls.statBox.list) do displayed[#displayed + 1] = StripEscapes(row[1]) end
		build.controls.statBox.list = rowsBefore
		local text = table.concat(displayed, '\n')
		if language == 'en' then
			equal(#dps.skills > 0, true, '实际全 DPS 列表有输出')
			if records == 0 then records = #dps.skills end
		end
		equal(#dps.skills, records, language .. ' 全 DPS 行数保持')
		for index, row in ipairs(dps.skills) do
			local raw = { name = row.name, dps = row.dps, count = row.count, source = row.source, trigger = row.trigger, skillPart = row.skillPart }
			if not expected[index] then expected[index] = raw end
			for field, value in pairs(expected[index]) do equal(raw[field], value, language .. ' 原始全 DPS 字段保持 ' .. index .. ':' .. field) end
			for field in pairs(raw) do equal(expected[index][field] ~= nil, true, language .. ' 没有新增原始全 DPS 字段') end
			for _, field in ipairs({ 'name', 'source', 'trigger', 'skillPart' }) do
				if row[field] and row[field] ~= '' then
					local label = localisation:Field(row, field)
					equal(text:find(StripEscapes(label), 1, true) ~= nil, true, language .. ' 组合文字进入实际侧栏 ' .. field)
					if language == 'en' then equal(label, row[field], '英文组合文字保持 ' .. field)
					else equal(StripEscapes(label):gsub('DPS', ''):find('%a'), nil, language .. ' 全 DPS 组合文字已翻译 ' .. tostring(row[field])) end
				end
			end
		end
		-- 直接调用实际 XML 导出入口，中文显示不得污染外部构筑身份。
		local outputBefore = build.calcsTab.mainOutput.SkillDPS
		build.calcsTab.mainOutput.SkillDPS = dps.skills
		local xml = { }
		build:Save(xml)
		build.calcsTab.mainOutput.SkillDPS = outputBefore
		local exported = 0
		for _, entry in ipairs(xml) do
			if entry.elem == 'FullDPSSkill' then
				exported = exported + 1
				local row = expected[exported]
				local name = row.count == 1 and row.name or string.format('%gx %s', row.count, row.name)
				equal(entry.attrib.stat, name, language .. ' XML 技能名保持原文')
				equal(entry.attrib.value, tostring(row.dps * row.count), language .. ' XML DPS 保持')
				equal(entry.attrib.skillPart, row.skillPart or '', language .. ' XML 分段名保持原文')
				equal(entry.attrib.source, row.source or row.trigger or '', language .. ' XML 来源保持原文')
			end
		end
		equal(exported, records, language .. ' XML 导出完整全 DPS 列表')
		-- 回用计算快照后，显示引用仍应按当前语言解析。
		local store = { }
		local captured = calcs.calcFullDPS(build, 'CALCULATOR', { }, { fullDPSCache = { store = store, capture = true } })
		local cached = calcs.calcFullDPS(build, 'CALCULATOR', { }, { fullDPSCache = { store = store } })
		equal(cached.combinedDPS, captured.combinedDPS, language .. ' 缓存回用不改变总 DPS')
		equal(#cached.skills, #captured.skills, language .. ' 缓存回用保留显示行')
		for index, row in ipairs(cached.skills) do
			equal(localisation:Field(row, 'name'), localisation:Field(captured.skills[index], 'name'), language .. ' 缓存回用保留名称引用')
		end
	end
	for group, value in pairs(included) do group.includeInFullDPS = value end
	localisation:SetLanguage(languageBefore)
	print('全 DPS 实际组合回归：' .. records .. ' 条记录，三语往返及计算缓存回用')
end
