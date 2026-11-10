-- 遍历已加载技能的所有已有等级及品质分支，覆盖低数值单复数和额外品质。
return function(build, equal)
	local languageBefore, fieldBefore = localisation.language, localisation.Field
	local owner, checked, keys, residuals, residualKeys = '', { }, { }, { }, { }
	local allowed = { I = true, II = true, III = true, IV = true, V = true, VI = true, X = true, x = true, m = true, s = true, ms = true, DPS = true }
	localisation.Field = function(self, object, name, parameters)
		local value = fieldBefore(self, object, name, parameters)
		if object.displaySlots and object.textKey then
			keys[object.textKey] = true
			local identity = self.language .. '\0' .. object.textKey .. '\0' .. value
			if self.language ~= 'en' and not checked[identity] then
				checked[identity] = true
				for word in StripEscapes(value):gmatch('%a+') do
					local key = self.language .. ':' .. object.textKey
					if not allowed[word] and not residualKeys[key] then
						residualKeys[key] = true
						residuals[#residuals + 1] = { language = self.language, key = object.textKey, owner = owner, display = value }
					end
				end
				local key = self.language .. ':' .. object.textKey
				if value:find('[', 1, true) and not residualKeys[key] then
					residualKeys[key] = true
					residuals[#residuals + 1] = { language = self.language, key = object.textKey, owner = owner, display = value }
				end
			end
		end
		return value
	end
	local samples, sets, withoutScope = 0, 0, 0
	for _, language in ipairs({ 'en', 'zh-CN', 'zh-TW' }) do
		localisation:SetLanguage(language)
		for id, effect in pairs(data.skills) do
			for index, statSet in ipairs(effect.statSets or { }) do
				if not statSet.statDescriptionScope then
					-- 内部爆炸计算对象没有说明作用域，产品也不把它作为技能说明绘制。
					withoutScope = withoutScope + 1
				else
					sets = sets + 1
					for level in pairs(effect.levels or { }) do
						for _, quality in ipairs({ 0, 1, 20, 30 }) do
							owner = id .. ':' .. index .. ':' .. level .. ':' .. quality
							local stats = calcLib.buildSkillInstanceStats({ level = level, quality = quality, actorLevel = 83 }, effect, statSet, true)
							data.describeStats(stats, statSet.statDescriptionScope)
							samples = samples + 1
						end
					end
					for _, stats in ipairs({ effect.qualityStats or { }, effect.altQualityStats or { } }) do
						for _, stat in ipairs(stats) do
							owner = id .. ':' .. index .. ':quality:' .. stat[1]
							data.describeStats({ [stat[1]] = 20 * stat[2] }, statSet.statDescriptionScope, true)
							samples = samples + 1
						end
					end
				end
			end
		end
	end
	local keyCount = 0
	for _ in pairs(keys) do keyCount = keyCount + 1 end
	equal(keyCount >= 2659, true, '全等级品质分支覆盖完整当前模板集')
	equal(withoutScope, 9, '仅排除三语各三个无描述作用域的内部计算属性组')
	localisation.Field = fieldBefore
	localisation:SetLanguage(languageBefore)
	if #residuals > 0 then print(require('dkjson').encode(residuals, { indent = true })) end
	equal(#residuals, 0, '全部已加载技能等级与品质分支没有非允许英文')
	print(string.format('全等级与品质属性回归：每语言 %d 个有效属性组，%d 个样本，合计 %d 个模板', sets / 3, samples / 3, keyCount))
end
