-- 用真实宝石和天赋授予技能检查完整属性说明，保留英文与业务身份。
return function(build, equal)
	local originalLanguage, originalField = localisation.language, localisation.Field
	local originalDifferences = build.treeTab.viewer.showStatDifferences
	local originalSkillTooltip = build.treeTab.viewer.skillTooltip
	local owner, language, keys, samples = '', 'en', { }, 0
	local fieldOutputs = { }
	local allowed = { I = true, II = true, III = true, IV = true, V = true, VI = true, X = true, x = true, m = true, s = true, ms = true, DPS = true }
	local directions = {
		['gem_stat_descriptions_support_chaos_damage_final_if_corpse_consumed_on_use_1_normal_variant_1.text'] = 'more',
		['gem_stat_descriptions_support_chaos_damage_final_per_corpse_consumed_on_use_1_normal_variant_1.text'] = 'more',
		['gem_stat_descriptions_support_damage_final_per_crossbow_bolt_reloaded_in_past_6_seconds_1_normal_variant_1.text'] = 'more',
		['gem_stat_descriptions_support_damage_final_per_crossbow_bolt_reloaded_in_past_8_seconds_1_normal_variant_1.text'] = 'more',
		['gem_stat_descriptions_support_deliberation_movement_speed_penalty_final_while_performing_action_1_normal_variant_1.text'] = 'more',
		['gem_stat_descriptions_support_splinter_totem_area_of_effect_final_each_splinter_1_negate_1_normal_variant_1.text'] = 'less',
		['gem_stat_descriptions_support_splinter_totem_maximum_life_final_each_splinter_1_negate_1_normal_variant_1.text'] = 'less',
		['gem_stat_descriptions_support_totem_life_final_1_normal_variant_1.text'] = 'more',
		['gem_stat_descriptions_support_chaos_support_non_chaos_damage_final_1_negate_1_normal_variant_1.text'] = 'less',
		['boneshatter_boneshatter_damage_final_if_created_from_unique_1_normal_variant_1.text'] = 'more',
		['skill_stat_descriptions_active_skill_hit_damage_stun_multiplier_final_1_normal_variant_1.text'] = 'more',
	}
	local checkedDirections, checkedRanges = { }, { }
	localisation.Field = function(self, object, field, parameters)
		local result = originalField(self, object, field, parameters)
		if field == 'text' and object.displaySlots then
			assert(object.textKey, '未绑定实际技能属性：' .. owner)
			keys[object.textKey] = true
			fieldOutputs[#fieldOutputs + 1] = result
			samples = samples + 1
			if language ~= 'en' then
				for word in result:gmatch('%a+') do assert(allowed[word], language .. ' 技能属性英文残留：' .. owner .. ' / ' .. object.textKey .. ' / ' .. result) end
				equal(result:find('[', 1, true), nil, language .. ' 实际属性无破损术语标记：' .. owner)
				local suffix = object.textKey:sub(#'game.stat_description.' + 1)
				local direction = directions[suffix]
				if direction then
					local more = result:find('总增', 1, true) or result:find('總增', 1, true) or result:find('更多', 1, true)
					local less = result:find('总降', 1, true) or result:find('總降', 1, true) or result:find('更少', 1, true)
					equal(direction == 'more' and more ~= nil or direction == 'less' and less ~= nil, true, language .. ' 增减方向正确：' .. owner)
					equal(direction == 'more' and less ~= nil or direction == 'less' and more ~= nil, false, language .. ' 无反向增减：' .. owner)
					checkedDirections[suffix] = true
				end
				if suffix:find('support_damage_final_per_crossbow_bolt_reloaded_in_past_6_seconds', 1, true) then
					equal(result:find('6', 1, true) ~= nil, true, language .. ' 装填统计6秒')
					equal(result:find('8', 1, true), nil, language .. ' 6秒条件未误写8秒')
					checkedRanges.reload = true
				elseif suffix:find('support_close_combat_attack_damage_final_from_distance', 1, true) then
					equal(result:find('1', 1, true) ~= nil and result:find('3.5', 1, true) ~= nil, true, language .. ' 近距离加成从1米衰减到3.5米')
					equal(result:find('7', 1, true), nil, language .. ' 未误写7米外')
					checkedRanges.distance = true
				elseif suffix:find('azmerian_swarm_statset_0_active_skill_minion_1_attack_speed_per_x_player_dexterity', 1, true) then
					equal(result:find(language == 'zh-CN' and '攻击速度' or '攻擊速度', 1, true) ~= nil, true, language .. ' 敏捷增加虫群攻速')
					equal(result:find(language == 'zh-CN' and '效果范围' or '效果範圍', 1, true), nil, language .. ' 攻速未误译范围')
					checkedRanges.swarm = true
				end
			end
		end
		return result
	end
	local module = LoadModule('Classes/GemTooltip')
	-- 全量检查真实提示框；渲染器按实际宽度自动换行。
	local function tooltip()
		local tip = new('Tooltip'):Tooltip()
		tip.maxWidth = nil
		return tip
	end
	local function contents(tip)
		local result = { }
		for _, line in ipairs(tip.lines) do
			if line.text then result[#result + 1] = { text = line.text, font = line.font, size = line.size } end
		end
		return require('dkjson').encode(result)
	end
	-- 核对完整属性正文确实进入提示框，忽略颜色与排版空白。
	local function checkBody(tip, secondary)
		local parts = { }
		for _, line in ipairs(tip.lines) do if line.text then parts[#parts + 1] = StripEscapes(line.text):gsub('%s', '') end end
		if secondary then
			for _, line in ipairs(secondary.lines) do if line.text then parts[#parts + 1] = StripEscapes(line.text):gsub('%s', '') end end
		end
		local body = table.concat(parts)
		for _, text in ipairs(fieldOutputs) do
			text = StripEscapes(text):gsub('\\n', ''):gsub('%s', '')
			equal(body:find(text, 1, true) ~= nil, true, language .. ' 完整属性正文进入真实提示框：' .. owner)
		end
	end
	local english, counts = { }, { }
	for _, current in ipairs({ 'en', 'zh-CN', 'zh-TW', 'en' }) do
		language = current
		localisation:SetLanguage(language)
		local gems, nodes = 0, 0
		for id, gem in pairsSortByKey(data.gems) do
			local name, effect = gem.name, gem.grantedEffect
			for _, level in ipairs({ 1, math.min(20, gem.naturalMaxLevel or 20) }) do
				for _, quality in ipairs({ 0, 20 }) do
					owner = 'gem:' .. id .. ':' .. level .. ':' .. quality
					local instance = { gemData = gem, grantedEffect = effect, level = level, quality = quality, nameSpec = name }
					local tip = tooltip()
					fieldOutputs = { }
					module.AddGemTooltip(tip, build, instance, { includeBuildPlannerNote = true })
					checkBody(tip)
					if id == 'Metadata/Items/Gems/SkillGemFirestorm' and language ~= 'en' then
						local titles = { }
						for _, line in ipairs(tip.lines) do if line.text then titles[#titles + 1] = StripEscapes(line.text) end end
						local body = table.concat(titles, '\n')
						equal(body:find('冰霜箭矢', 1, true) ~= nil, true, language .. ' 冰霜分段显示完整标题')
						equal(body:find(language == 'zh-CN' and '闪电箭矢' or '閃電箭矢', 1, true) ~= nil, true, language .. ' 闪电分段显示完整标题')
						equal(body:find('Ice', 1, true), nil, language .. ' 分段标题没有英文残留')
					end
					if language == 'en' then
						local text = contents(tip)
						if english[owner] then equal(text, english[owner], '切回英文恢复完整技能提示框：' .. owner) else english[owner] = text end
					end
					equal(instance.nameSpec == name and instance.gemData == gem and instance.level == level and instance.quality == quality, true, language .. ' 显示未改技能身份及等级：' .. owner)
				end
			end
			equal(gem.name == name and gem.grantedEffect == effect, true, language .. ' 显示未改宝石数据：' .. id)
			gems = gems + 1
		end
		build.treeTab.viewer.showStatDifferences = false
		build.treeTab.viewer.skillTooltip = tooltip()
		for id, node in pairsSortByKey(build.spec.nodes) do
			owner = 'tree:' .. id
			local tip = tooltip()
			fieldOutputs = { }
			build.treeTab.viewer:AddNodeTooltip(tip, node, build, 0)
			checkBody(tip, build.treeTab.viewer.skillTooltip)
			if language == 'en' then
				local text = contents(tip)
				if english[owner] then equal(text, english[owner], '切回英文恢复完整天赋提示框：' .. owner) else english[owner] = text end
			end
			nodes = nodes + 1
		end
		counts[language] = { gems = gems, nodes = nodes }
	end
	for key in pairs(directions) do equal(checkedDirections[key], true, '增减方向样本确实进入实际提示框：' .. key) end
	for _, key in ipairs({ 'reload', 'distance', 'swarm' }) do equal(checkedRanges[key], true, '条件样本确实进入实际提示框：' .. key) end
	local keyCount = 0
	for key in pairs(keys) do keyCount = keyCount + 1 end
	equal(keyCount >= 2305, true, '完整覆盖当前可达动态模板')
	for _, id in ipairs({ 'SkillGemSorceryWard', 'SkillGemAscendancyAlignFate', 'SkillGemTasaliosRhythmSupport' }) do
		local gem = assert(data.gems['Metadata/Items/Gems/' .. id], '缺少自动换行样本：' .. id)
		for _, current in ipairs({ 'zh-CN', 'zh-TW' }) do
			language = current
			localisation:SetLanguage(language)
			local tip = new('Tooltip'):Tooltip()
			module.AddGemTooltip(tip, build, { gemData = gem, grantedEffect = gem.grantedEffect, level = math.min(20, gem.naturalMaxLevel or 20), quality = 20, nameSpec = gem.name })
			equal(tip.maxWidth, 600, language .. ' 多行说明沿用600像素提示框：' .. id)
			for _, line in ipairs(tip.lines) do
				if line.text then equal(DrawStringWidth(line.size, line.font, line.text) <= tip.maxWidth, true, language .. ' 多行说明不超出提示框宽度：' .. id) end
			end
		end
	end
	localisation.Field = originalField
	build.treeTab.viewer.showStatDifferences, build.treeTab.viewer.skillTooltip = originalDifferences, originalSkillTooltip
	localisation:SetLanguage(originalLanguage)
	print(string.format('动态技能实际回归：%d 个属性模板，%d 次参数输出；%d 个宝石，%d 个天赋', keyCount, samples, counts.en.gems, counts.en.nodes))
end
