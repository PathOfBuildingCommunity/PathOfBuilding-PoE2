-- 覆盖出生地区二级提示框与区域详情字段，保留业务原文、等级、标签及名单顺序。
return function(build, equal)
	local originalLanguage = localisation.language
	local spawnControl = new('SpawnListControl'):SpawnListControl(nil, { 0, 0, 300, 400 }, data, { })
	local originals, spawnAreas, english = { }, { }, { }
	local spawnRecords = 0
	local json = require('dkjson')
	local function snapshot(area)
		return json.encode({ name = area.name, description = area.description, level = area.level,
			tags = area.tags, monsters = area.monsterVarieties, bosses = area.bossVarieties })
	end
	for id, area in pairs(data.worldAreas) do
		originals[id] = snapshot(area)
		if #area.monsterVarieties > 0 then
			spawnRecords = spawnRecords + 1
			if not spawnAreas[area.name] then spawnAreas[area.name] = area end
		end
	end
	local function compact(text) return StripEscapes(text):gsub('%s', '') end
	local function checkChinese(text, label)
		-- BIC 为原文纪年标记，保留以避免把未知纪年解释为游戏外含义。
		equal(StripEscapes(text):gsub('BIC', ''):find('%a'), nil, label .. ' 无英文正文：' .. text)
		equal(text:find('比特币', 1, true), nil, label .. ' 纪年没有被误译为货币')
	end
	local areaCount, descriptionCount, bossCount, monsterCount = 0, 0, 0, 0
	for _, language in ipairs({ 'en', 'zh-CN', 'zh-TW', 'en' }) do
		localisation:SetLanguage(language)
		for id, area in pairsSortByKey(data.worldAreas) do
			if area.description and area.description ~= '' then
				local display = localisation:Field(area, 'description')
				if language == 'en' then equal(display, area.description, '英文区域背景保持：' .. id)
				else checkChinese(display, language .. ' 区域背景：' .. id) end
				if language == 'zh-CN' then descriptionCount = descriptionCount + 1 end
			end
			for _, field in ipairs({ 'bossVarieties', 'monsterVarieties' }) do
				for index, source in ipairs(area[field] or { }) do
					local display = localisation:Line(area, field, index)
					if language == 'en' then equal(display, source, '英文区域名单保持：' .. id)
					else checkChinese(display, language .. ' 区域名单：' .. id) end
					if language == 'zh-CN' then
						if field == 'bossVarieties' then bossCount = bossCount + 1 else monsterCount = monsterCount + 1 end
					end
				end
			end
			equal(snapshot(area), originals[id], language .. ' 区域业务元数据保持：' .. id)
		end
		for source, area in pairs(spawnAreas) do
			local tooltip = new('Tooltip'):Tooltip()
			spawnControl:AddValueTooltip(tooltip, 1, source)
			local lines = { }
			for _, line in ipairs(tooltip.lines) do
				if line.text then
					lines[#lines + 1] = { text = line.text, font = line.font, size = line.size }
					if language ~= 'en' then checkChinese(line.text, language .. ' 实际地区提示框：' .. source) end
				end
			end
			equal(#lines > 0, true, language .. ' 实际地区提示框非空：' .. source)
			local body = { }
			for _, line in ipairs(lines) do body[#body + 1] = line.text end
			body = compact(table.concat(body))
			if area.description and area.description ~= '' then
				equal(body:find(compact(localisation:Field(area, 'description')), 1, true) ~= nil, true, language .. ' 背景进入实际地区提示框')
			end
			for _, field in ipairs({ 'bossVarieties', 'monsterVarieties' }) do
				for index in ipairs(area[field] or { }) do
					equal(body:find(compact(localisation:Line(area, field, index)), 1, true) ~= nil, true, language .. ' 名单进入实际地区提示框')
				end
			end
			if language == 'en' then
				local current = json.encode(lines)
				if english[source] then equal(current, english[source], '切回英文恢复地区全文、字号及字体') else english[source] = current end
			end
			if language == 'zh-CN' then areaCount = areaCount + 1 end
		end
	end
	equal(spawnRecords, 218, '全部出生地区记录覆盖')
	equal(areaCount, 216, '全部按名称合并的出生地区二级提示框覆盖')
	equal(descriptionCount, 287, '全部已登记区域背景覆盖')
	equal(bossCount, 244, '全部已登记区域首领引用覆盖')
	equal(monsterCount, 1292, '全部已登记区域怪物引用覆盖')
	localisation:SetLanguage(originalLanguage)
	print(string.format('区域详情实际回归：%d 个提示框，%d 条背景、%d 条首领、%d 条怪物引用', areaCount, descriptionCount, bossCount, monsterCount))
end
