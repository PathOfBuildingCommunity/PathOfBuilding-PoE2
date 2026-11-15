-- 装备元数据和全部词缀须在语言切换后保持引用、业务原文及真实提示框。
return function(build, equal)
	local originalLanguage = localisation.language
	local saved, english, fields = { }, { }, 0
	local allowed = { I = true, II = true, III = true, IV = true, V = true, VI = true, VII = true, VIII = true, IX = true, X = true, F = true, f = true, e = true, DPS = true, m = true, s = true }
	for kind, list in pairsSortByKey(data.uniques) do
		for index, raw in ipairs(list) do
			local item = new('Item'):Item(raw, 'UNIQUE')
			saved[#saved + 1] = { item = item, raw = item.raw, name = item.name, baseName = item.baseName, league = item.league, source = item.source, label = kind .. ':' .. index }
		end
	end
	local function checkText(text, language, label)
		if language ~= 'en' then
			for word in StripEscapes(text):gmatch('%a+') do equal(allowed[word] == true, true, language .. ' 装备正文无英文回退：' .. label .. ' / ' .. text) end
		end
	end
	local function compact(text) return StripEscapes(text):gsub('%s', '') end
	for _, language in ipairs({ 'en', 'zh-CN', 'zh-TW', 'en' }) do
		localisation:SetLanguage(language)
		for _, entry in ipairs(saved) do
			local item = entry.item
			local tooltip = new('Tooltip'):Tooltip()
			build.itemsTab:AddItemTooltip(tooltip, item, nil, true)
			local rendered, snapshot = { }, { }
			for _, line in ipairs(tooltip.lines) do
				if line.text then
					rendered[#rendered + 1] = line.text
					snapshot[#snapshot + 1] = { text = line.text, font = line.font, size = line.size }
				end
			end
			local body = compact(table.concat(rendered))
			if language == 'en' then
				local text = require('dkjson').encode(snapshot)
				if english[entry.label] then equal(text, english[entry.label], '切回英文完整恢复装备提示框：' .. entry.label) else english[entry.label] = text end
			end
			if item.league then
				local display = localisation:Term('item_league', item.league)
				checkText(display, language, item.league)
				equal(body:find(compact(display), 1, true) ~= nil, true, language .. ' 赛季进入实际提示框：' .. entry.label)
				if language == 'en' then equal(display, item.league, '英文赛季保持原文') end
				fields = fields + 1
			end
			if item.source then
				local source = localisation:ModLine(item.sourceDisplay, item.source)
				local display = build.itemsTab:FormatItemSource(source)
				checkText(display, language, item.source)
				equal(body:find(compact(display), 1, true) ~= nil, true, language .. ' 来源进入实际提示框：' .. entry.label)
				equal(display:find('[{}]'), nil, language .. ' 来源颜色宏完全解析：' .. entry.label)
				for _, macro in ipairs({ 'unique', 'normal' }) do
					if item.source:find(macro .. '{', 1, true) then equal(display:find(colorCodes[macro == 'unique' and 'UNIQUE' or 'NORMAL'], 1, true) ~= nil, true, language .. ' 来源保留颜色：' .. macro) end
				end
				if language == 'en' then equal(source, item.source, '英文来源保持原文') end
				fields = fields + 1
			end
			for _, field in ipairs({ 'variantList', 'versionList', 'upgradePaths' }) do
				for index, source in ipairs(item[field] or { }) do
					local display = localisation:ListLabel(item[field], index)
					checkText(build.itemsTab:FormatItemSource(display), language, item.title .. ':' .. field .. ':' .. index)
					if language == 'en' then equal(display, source, '英文装备列表原文保持') end
					fields = fields + 1
				end
			end
			for _, field in ipairs({ 'implicitModLines', 'explicitModLines', 'buffModLines', 'enchantModLines' }) do
				for _, line in ipairs(item[field] or { }) do
					local source = line.line
					local display = localisation:ModLine(line, source)
					checkText(display, language, item.title .. ':' .. field)
					if language == 'en' then equal(display, source, '英文装备词缀原文保持') end
					equal(line.line, source, language .. ' 显示未改变解析词缀')
					fields = fields + 1
				end
			end
			equal(item.raw == entry.raw and item.name == entry.name and item.baseName == entry.baseName and item.league == entry.league and item.source == entry.source, true, language .. ' 装备身份、赛季、来源与原始输入保持：' .. entry.label)
		end
		equal(localisation:Term('item_league', 'Unknown user league'), 'Unknown user league', language .. ' 未登记的用户赛季保持原文')
	end
	equal(#saved, 443, '覆盖全部当前传奇装备')
	equal(fields, 6518 * 4, '覆盖全部元数据及词缀行')
	localisation:SetLanguage(originalLanguage)
	print(string.format('装备详情实际回归：%d 个传奇，%d 行元数据及词缀，四次语言往返', #saved, fields / 4))
end
