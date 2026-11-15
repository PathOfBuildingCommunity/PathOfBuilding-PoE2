-- 用真实召唤物列表、出生区域与首领预设验证显示引用，不改业务身份。
return function(build, equal)
	local originalLanguage = localisation.language
	local minionControl = new('MinionListControl'):MinionListControl(nil, { 0, 0, 300, 400 }, data, { })
	local spawnControl = new('SpawnListControl'):SpawnListControl(nil, { 0, 0, 300, 400 }, data, { })
	local options = LoadModule('Modules/ConfigOptions')
	local presetOption
	for _, option in ipairs(options) do if option.var == 'presetBossSkills' then presetOption = option end end
	assert(presetOption, '缺少首领技能预设回归入口')
	local configKeys = {
		['ui.config_options.module.config_settings.label_84'] = true,
		['ui.config_options.module.doom_blast_source.label_5'] = true,
		['ui.config_options.module.doom_blast_source.label_4'] = true,
		['ui.config_options.module.raise_spectre_enable_summoned_ursa_rallying_cry.label'] = true,
		['ui.config_options.module.raise_spectre_enable_slashing_horror_enrage.label'] = true,
		['ui.config_options.module.raise_spectre_enable_sanguimancer_demon_low_life.label'] = true,
	}
	local originals, english, locations, total, tooltips = { }, { }, { }, 0, 0
	for id, minion in pairsSortByKey(data.minions) do
		originals[id] = { name = minion.name, monsterCategory = minion.monsterCategory, spawnLocation = copyTable(minion.spawnLocation or { }), skillList = copyTable(minion.skillList or { }) }
		for _, location in ipairs(minion.spawnLocation or { }) do locations[location] = true end
		total = total + 1
	end
	local allowed = { x = true, inf = true, I = true, II = true, III = true, IV = true, V = true, VI = true, DPS = true, m = true, s = true }
	local function checkChinese(text, label)
		for word in StripEscapes(text):gmatch('%a+') do equal(allowed[word] == true, true, label .. ' 无英文正文：' .. text) end
	end
	local function compact(text) return StripEscapes(text):gsub('%s', '') end
	local seenKeys = { }
	for _, language in ipairs({ 'en', 'zh-CN', 'zh-TW', 'en' }) do
		localisation:SetLanguage(language)
		for id, minion in pairsSortByKey(data.minions) do
			local name = localisation:Field(minion, 'name')
			equal(minionControl:GetRowValue(1, 1, id), name, language .. ' 真实召唤物列表读取名称引用：' .. id)
			if language == 'en' then equal(name, originals[id].name, '英文召唤物名称保持') else checkChinese(name, language .. ' ' .. id) end
			if minion.monsterCategory then
				local tooltip = new('Tooltip'):Tooltip()
				minionControl:AddValueTooltip(tooltip, 1, id)
				local parts, snapshot = { }, { }
				for _, line in ipairs(tooltip.lines) do
					if line.text then
						parts[#parts + 1] = line.text
						snapshot[#snapshot + 1] = { text = line.text, font = line.font, size = line.size }
						if language ~= 'en' then checkChinese(line.text, language .. ' 召唤物实际提示框：' .. id) end
					end
				end
				local body = compact(table.concat(parts))
				equal(body:find(compact(name), 1, true) ~= nil, true, language .. ' 名称进入真实提示框')
				for index in ipairs(minion.spawnLocation or { }) do
					local location = localisation:Line(minion, 'spawnLocation', index)
					equal(body:find(compact(location), 1, true) ~= nil, true, language .. ' 完整出生地点进入真实提示框：' .. id)
				end
				if language == 'en' then
					local text = require('dkjson').encode(snapshot)
					if english[id] then equal(text, english[id], '切回英文恢复召唤物完整提示框：' .. id) else english[id] = text end
				end
				tooltips = tooltips + 1
			end
			local original = originals[id]
			equal(minion.name == original.name and minion.monsterCategory == original.monsterCategory, true, language .. ' 召唤物内部名称与类别保持')
			for index, source in ipairs(original.spawnLocation) do equal(minion.spawnLocation[index], source, language .. ' 出生地点业务原文保持') end
			for index, source in ipairs(original.skillList) do equal(minion.skillList[index], source, language .. ' 召唤物技能身份保持') end
		end
		for source in pairs(locations) do
			local display = spawnControl:GetRowValue(1, 1, source)
			if language == 'en' then equal(display, source, '英文出生地点列表保持') else checkChinese(display, language .. ' 出生地点真实列表') end
		end
		equal(spawnControl:GetRowValue(1, 1, 'Unknown user location'), 'Unknown user location', language .. ' 未登记的用户地点不猜译')
		for _, option in ipairs(options) do
			local entries = { option }
			for _, entry in ipairs(option.list or { }) do entries[#entries + 1] = entry end
			for _, entry in ipairs(entries) do
				if configKeys[entry.labelKey] then
					seenKeys[entry.labelKey] = true
					local display = localisation:Field(entry, 'label')
					if language == 'en' then equal(display, entry.label, '英文配置标签保持') else checkChinese(display, language .. ' 配置标签') end
				end
			end
		end
		for _, preset in ipairs(data.bossSkillsList) do
			local value = preset.val
			local display = localisation:Field(preset, 'label')
			if language == 'en' then equal(display, preset.label, '英文首领预设标签保持') else checkChinese(display, language .. ' 首领预设标签') end
			for _, mode in ipairs({ 'BODY', 'HOVER' }) do
				local tooltip = new('Tooltip'):Tooltip()
				presetOption.tooltipFunc(tooltip, mode, 1, preset)
				local parts = { }
				for _, line in ipairs(tooltip.lines) do if line.text then parts[#parts + 1] = line.text end end
				local text = table.concat(parts)
				if value ~= 'None' then
					equal(compact(text):find(compact(display), 1, true) ~= nil, true, language .. ' 首领名称进入实际预设提示框')
					if language ~= 'en' then checkChinese(text, language .. ' 首领预设实际提示框') end
				end
			end
			equal(preset.val, value, language .. ' 首领预设计算值保持')
		end
	end
	for key in pairs(configKeys) do equal(seenKeys[key], true, '配置候选确实经过回归：' .. key) end
	equal(total, 649, '全部当前召唤物名称已覆盖')
	equal(tooltips, 647 * 4, '实际列表有效提示框完整覆盖，两个无类别的脚本召唤物单独保留诊断')
	localisation:SetLanguage(originalLanguage)
	print(string.format('召唤物与配置实际回归：%d 个名称，%d 个有效提示框及全部首领技能预设', total, tooltips / 4))
end
