-- 用截图对应的真实构筑验证属性详情文字、绘制内容和计算数据。
return function(build, equal)
	local calcs = require('Modules.CalcBase')
	local control = new('CalcBreakdownControl'):CalcBreakdownControl(build.calcsTab)
	control.envName = 'mainEnv'
	local baseline, englishRows, additionalRows, requirementRows, categoryOutputs
	local function numbers(object, path, result, visited)
		if visited[object] then return end
		visited[object] = true
		for key, value in pairs(object) do
			local name = path .. '.' .. tostring(key)
			if type(value) == 'number' then result[name] = value
			elseif type(value) == 'table' and (key == 'MainHand' or key == 'OffHand') then numbers(value, name, result, visited) end
		end
	end
	for _, language in ipairs({ 'en', 'zh-CN', 'zh-TW', 'en' }) do
		localisation:SetLanguage(language)
		for _, flags in ipairs({ ModFlag, KeywordFlag }) do
			for name in pairs(flags) do
				local label = localisation:Term('calculation_flag', name, name)
				if language == 'en' then equal(label, name, '英文位标志名称保持原值')
				else equal(label:find('%a'), nil, language .. ' 位标志显示已登记：' .. name) end
			end
		end
		local env = calcs.buildOutput(build, 'MAIN')
		build.calcsTab.mainEnv = env
		control:SetBreakdownData({ { breakdown = 'MainHand.CritChance' }, { modName = { 'CritChance', 'WeaponBaseCritChance' }, cfg = 'weapon1' } })
		local output = { }
		numbers(env.player.output, 'player', output, { })
		baseline = baseline or output
		for key, value in pairs(baseline) do
			equal(output[key] == value or value ~= value and output[key] ~= output[key], true, language .. ' 属性弹窗数值保持：' .. key)
		end
		for key in pairs(output) do equal(baseline[key] ~= nil, true, language .. ' 计算输出字段保持：' .. key) end
		local cn, tw = language == 'zh-CN', language == 'zh-TW'
		local expectedLines = {
			'(12.53 + 3.3) ^8(' .. (cn and '基础' or tw and '基礎' or 'base') .. ')',
			'x 2.84 ^8(' .. (cn and '提高/降低' or tw and '增加/減少' or 'increased/reduced') .. ')',
			'x 2.02 ^8(' .. (cn and '额外提高/额外降低' or tw and '更多/更少' or 'more/less') .. ')',
			'= 90.63% ^8(' .. (cn and '暴击率' or tw and '暴擊率' or 'crit chance') .. ')',
		}
		for index, text in ipairs(expectedLines) do equal(control.sectionList[1].lines[index], text, language .. ' 真实暴击率公式第 ' .. index .. ' 行') end
		local expectedFlags = cn and '击中, 长矛' or tw and '擊中, 長鋒' or 'Hit, Spear'
		local expectedCondition = cn and '条件: 武器组 2' or tw and '條件: 武器組 2' or 'Condition: Weapon Set 2'
		local expectedBuff = cn and '若 暴击球 >= 1, 增益效果' or tw and '若 暴擊球 >= 1, 增益效果' or 'If Power Charges >= 1, Buff'
		local foundFlags, foundCondition, foundBuff, foundItem = false, false, false, false
		local identities = { }
		for _, row in ipairs(control.sectionList[2].rowList) do
			local mod = row.mod
			local tags = { }
			for _, tag in ipairs(mod) do tags[#tags + 1] = table.concat({ tag.type, tag.var or '', tag.effectType or '', tostring(tag.threshold or '') }, ':') end
			local identity = table.concat({ mod.name, mod.source, mod.type, tostring(mod.flags), tostring(mod.keywordFlags), tostring(row.value), table.concat(tags, ';') }, '|')
			identities[identity] = (identities[identity] or 0) + 1
			foundFlags = foundFlags or row.flags == expectedFlags
			foundCondition = foundCondition or row.tags == expectedCondition
			foundBuff = foundBuff or row.tags == expectedBuff
			foundItem = foundItem or (row.sourceName or ''):find('Pain Caress, ', 1, true) ~= nil
			if cn or tw then
				for _, field in ipairs({ 'name', 'flags', 'tags', 'source' }) do
					equal((row[field] or ''):find('%a'), nil, language .. ' 截图表格无英文标签：' .. field)
				end
			end
		end
		englishRows = englishRows or identities
		for identity, count in pairs(englishRows) do equal(identities[identity], count, language .. ' 修饰词业务身份和数值保持') end
		for identity in pairs(identities) do equal(englishRows[identity] ~= nil, true, language .. ' 未新增计算修饰词') end
		equal(foundFlags, true, language .. ' 击中和矛类型已翻译')
		equal(foundCondition, true, language .. ' 第二武器组条件已翻译')
		equal(foundBuff, true, language .. ' 暴击球阈值和增益已翻译')
		equal(foundItem, true, language .. ' 导入稀有物品标题保持原文')
		local draw, cursor = DrawString, GetCursorPos
		local drawn = { }
		DrawString = function(x, y, align, size, font, text) drawn[StripEscapes(text)] = true end
		GetCursorPos = function() return -1000, -1000 end
		local ok, err = pcall(control.DrawBreakdownTable, control, { x = 0, y = 0, width = 1920, height = 1080 }, 0, 0, control.sectionList[2])
		DrawString, GetCursorPos = draw, cursor
		assert(ok, err)
		for _, text in ipairs({ expectedFlags, expectedCondition, expectedBuff }) do equal(drawn[text], true, language .. ' 实际表格绘制翻译文本') end
		equal(control:FormatVarNameOrList(nil, { 'WeaponSet2', 'PowerCharges' }), cn and '武器组 2 / 暴击球' or tw and '武器組 2 / 暴擊球' or 'Weapon Set 2 / Power Charges', language .. ' 条件列表按独立身份显示')
		equal(control:FormatModName('UnknownFutureMod'), 'Unknown Future Mod', language .. ' 未登记名称保留英文回退')
		-- 对真实额外伤害、击杀回复和连续投射物来源核对显示与业务身份。
		control:SetBreakdownData({ { modName = { 'DamageGainAsFire', 'LifeOnKill', 'SequentialProjectiles' }, cfg = 'weapon1' } })
		local expectedNames = {
			DamageGainAsFire = cn and '伤害获得额外火焰伤害' or tw and '傷害獲得額外火焰傷害' or 'Damage Gain As Fire',
			LifeOnKill = cn and '击杀生命回复' or tw and '擊殺生命恢復' or 'Life On Kill',
			SequentialProjectiles = cn and '连续发射投射物' or tw and '連續發射投射物' or 'Sequential Projectiles',
		}
		local namesFound, currentRows = { }, { }
		for _, row in ipairs(control.sectionList[1].rowList) do
			equal(row.name, expectedNames[row.mod.name], language .. ' 真实属性来源名称：' .. row.mod.name)
			namesFound[row.mod.name] = true
			local identity = table.concat({ row.mod.name, row.mod.source, row.mod.type, tostring(row.value), tostring(row.mod.flags), tostring(row.mod.keywordFlags) }, '|')
			currentRows[identity] = (currentRows[identity] or 0) + 1
		end
		for name in pairs(expectedNames) do equal(namesFound[name], true, language .. ' 真实构筑包含来源：' .. name) end
		additionalRows = additionalRows or currentRows
		for identity, count in pairs(additionalRows) do equal(currentRows[identity], count, language .. ' 补译后原始修饰词和数值保持') end
		for identity in pairs(currentRows) do equal(additionalRows[identity] ~= nil, true, language .. ' 补译后未新增修饰词') end
		drawn = { }
		DrawString = function(x, y, align, size, font, text) drawn[StripEscapes(text)] = true end
		GetCursorPos = function() return -1000, -1000 end
		ok, err = pcall(control.DrawBreakdownTable, control, { x = 0, y = 0, width = 1920, height = 1080 }, 0, 0, control.sectionList[1])
		DrawString, GetCursorPos = draw, cursor
		assert(ok, err)
		for _, name in pairs(expectedNames) do equal(drawn[name], true, language .. ' 补译名称进入实际表格绘制') end
		-- 敌人条件前缀与配置来源也来自真实修饰词，不改写actor或来源身份。
		control:SetBreakdownData({ { modName = 'Damage', cfg = 'weapon1' } })
		local enemyPrefix = cn and '敌人条件' or tw and '敵人條件' or 'Enemy Condition'
		local foundEnemyCondition = false
		for _, row in ipairs(control.sectionList[1].rowList) do
			for _, tag in ipairs(row.mod) do
				if tag.type == 'ActorCondition' and tag.actor == 'enemy' then
					equal(row.tags:find(enemyPrefix, 1, true) ~= nil, true, language .. ' 真实敌人条件前缀')
					foundEnemyCondition = true
				end
			end
		end
		equal(foundEnemyCondition, true, language .. ' 真实伤害来源包含敌人条件')
		control:SetBreakdownData({ { modName = 'FireResist', enemy = true } })
		local foundEnemyConfig = false
		for _, row in ipairs(control.sectionList[1].rowList) do
			if row.mod.source == 'EnemyConfig' then
				equal(row.source, cn and '敌人配置' or tw and '敵人配置' or 'EnemyConfig', language .. ' 真实敌人抗性配置来源')
				foundEnemyConfig = true
			end
		end
		equal(foundEnemyConfig, true, language .. ' 真实敌人配置身份保留')
		-- 后续截图的攻击速度与有效承伤池同样通过真实详情控件检查。
		control:SetBreakdownData({ { breakdown = 'MainHand.Speed' }, { modName = 'Speed', modType = 'INC', cfg = 'weapon1' } })
		local speedLines = control.sectionList[1].lines
		local expectedRate = language == 'en' and string.format('= %.2f ^8casts per second', env.player.output.MainHand.CastRate)
			or string.format('= %.2f ^8次/秒', env.player.output.MainHand.CastRate)
		equal(speedLines[#speedLines], expectedRate, language .. ' 攻击和施法共用速率模板显示正确单位')
		local expectedFlask = cn and '条件: 药剂生效期间' or tw and '條件: 藥劑效果期間' or 'Condition: Using Flask'
		local foundFlask = false
		for _, row in ipairs(control.sectionList[2].rowList) do
			foundFlask = foundFlask or row.tags == expectedFlask
			if cn or tw then equal((row.tags or ''):find('Using Flask', 1, true), nil, language .. ' 攻速条件无英文残留') end
		end
		equal(foundFlask, true, language .. ' 实际攻速来源中的药剂条件已翻译')
		control:SetBreakdownData({ { breakdown = 'TotalEHP' } })
		local ehpLines = control.sectionList[1].lines
		local incoming = math.floor(env.player.output.totalEnemyDamageIn)
		local total = math.floor(env.player.output.TotalEHP)
		local expectedEhp = {
			string.format('%.2f ^8(%s)', env.player.output.TotalNumberOfHits, cn and '平均可承受的击中次数' or tw and '總平均可承受擊中數' or 'total average number of hits you can take'),
			string.format('x %d ^8(%s)', incoming, cn and '单次击中的传入总伤害' or tw and '總傳入傷害' or 'total incoming damage'),
			string.format('= %d ^8(%s)', total, cn and '可承受的总伤害' or tw and '可承受之總傷害' or 'total damage you can take'),
		}
		for index, line in ipairs(expectedEhp) do equal(ehpLines[index], line, language .. ' 有效承伤池公式第 ' .. index .. ' 行') end
		if cn or tw then equal(env.player.breakdown.MainHand.AccuracyHitChance[1]:find('%a'), nil, language .. ' 真实命中率的配置页说明无英文残留') end
		-- 积累公式的嵌套状态引用应随语言变化，重度晕眩不得回退为内部驼峰身份。
		for ailment, names in pairs({ Freeze = { '冻结', '冰凍' }, Electrocute = { '电刑', '電刑' }, HeavyStun = { '重度晕眩', '重度暈眩' }, Pin = { '钉身', '釘身' } }) do
			local lines = env.player.breakdown[ailment .. 'Buildup']
			local name = cn and names[1] or tw and names[2] or ailment
			equal(lines[4], cn and '普通击中' .. name .. '积累' or tw and '普通擊中' .. name .. '累積' or 'Regular Hit ' .. name .. ' buildup', language .. ' 真实控制积累公式：' .. ailment)
			if cn or tw then
				for index, line in ipairs(lines) do equal(line:find('%a'), nil, language .. ' 控制积累公式无英文残留：' .. ailment .. ':' .. index) end
			end
		end
		-- 伤害区间、平均异常状态取值和宝石来源走真实详情路径，保留原始数值。
		control:SetBreakdownData({ { breakdown = 'MainHand.Physical' } })
		local physicalText = StripEscapes(table.concat(control.sectionList[1].lines, '\n'))
		local rangeConnector = language == 'en' and ' to ' or ' 至 '
		equal(physicalText:find(rangeConnector, 1, true) ~= nil, true, language .. ' 真实伤害区间连接词')
		equal(physicalText:find(cn and '来自武器的伤害' or tw and '來自武器的傷害' or 'damage from weapon', 1, true) ~= nil, true, language .. ' 武器来源嵌套参数已翻译')
		local roll = env.player.breakdown.IgniteRollAverage
		equal(roll[5], language == 'en' and 'Average Roll:' or '平均取值：', language .. ' 真实点燃平均取值标题')
		equal(roll[6], cn and '50%（平均施加次数 <= 1）' or tw and '50%（平均施加次數 <= 1）' or '50% (averaging <= 1 applications)', language .. ' 真实点燃平均次数说明保留阈值')
		-- 普通与暴击来源应复用同一公式译文，暴击分支也必须进入稳定资源路径。
		local derivation = env.player.breakdown.IgniteDPS
		local expectedFormula = cn and '^8综合来源最小值 + （综合来源最大值 - 综合来源最小值） * 平均取值'
			or tw and '^8綜合來源最小值 + （綜合來源最大值 - 綜合來源最小值） * 平均取值'
			or '^8min combined sources + (max combined sources - min combined sources) * average roll'
		equal(derivation[3], expectedFormula, language .. ' 真实非暴击异常状态来源公式')
		equal(derivation[6], cn and '暴击伤害推导：' or tw and '暴擊傷害推導：' or 'Crit Dmg Derivation:', language .. ' 真实暴击异常状态来源标题')
		equal(derivation[8], expectedFormula, language .. ' 真实暴击异常状态来源公式')
		for _, specification in ipairs({
			{ mod = 'GemLevel', source = 'Max Level', cn = '等级上限', tw = '等級上限' },
			{ mod = 'GemQuality', source = 'Gem Quality', cn = '宝石品质', tw = '寶石品質' },
		}) do
			control:SetBreakdownData({ { modName = { specification.mod }, cfg = 'skill' } })
			local found = false
			for _, row in ipairs(control.sectionList[1].rowList) do
				if row.mod.source == specification.source then
					equal(row.source, cn and specification.cn or tw and specification.tw or specification.source, language .. ' 宝石来源按稳定身份翻译')
					found = true
				end
			end
			equal(found, true, language .. ' 保留真实宝石来源：' .. specification.source)
		end
		-- 需求表显示引用不得改变原始来源名称、属性需求和排序数值。
		local requirements, supportFound = { }, false
		for _, attr in ipairs({ 'Str', 'Dex', 'Int' }) do
			control:SetBreakdownData({ { breakdown = 'Req' .. attr } })
			local section = control.sectionList[1]
			equal(localisation:Field(section.colList[1], 'label'), localisation:Term('attribute', attr), language .. ' 真实需求表属性列标题')
			for index, row in ipairs(section.rowList) do
				requirements[attr .. ':' .. index] = table.concat({ row.source, row.sourceName, row.reqNum, tostring(row.req) }, '|')
				local source = localisation:Field(row, 'source')
				if cn or tw then equal(StripEscapes(source):find('%a'), nil, language .. ' 真实需求表来源已翻译') end
				if row.source == 'Support Gems' then
					supportFound = true
					local name = StripEscapes(localisation:Field(row, 'sourceName'))
					if cn or tw then equal(name:find('%a'), nil, language .. ' 真实辅助宝石数量与属性说明已翻译')
					else equal(localisation:Field(row, 'sourceName'), row.sourceName, '辅助宝石英文显示保持') end
				end
			end
		end
		equal(supportFound, true, language .. ' 真实构筑存在辅助宝石需求')
		requirementRows = requirementRows or requirements
		for identity, value in pairs(requirementRows) do equal(requirements[identity], value, language .. ' 需求表原文、数值和顺序保持') end
		-- 从实际任务词缀身份找到任务对象，要求来源区域与配置页使用同一显示引用。
		local questFound = false
		control:SetBreakdownData({ { modName = 'FireResist' } })
		for _, row in ipairs(control.sectionList[1].rowList) do
			if row.mod.source:sub(1, 6) == 'Quest:' then
				for _, quest in ipairs(build.data.questRewards) do
					if row.mod.source == 'Quest:' .. quest.Description .. ': ' .. quest.Area then
						local label = localisation:Text('quest.reward.label', { act = localisation:Ref(quest.DescriptionKey), area = localisation:Ref(quest.AreaKey) })
						equal(row.sourceName, label, language .. ' 实际任务来源与配置标签一致')
						if cn or tw then equal(row.sourceName:find('%a'), nil, language .. ' 实际任务来源无英文残留') end
						questFound = true
					end
				end
			end
		end
		equal(questFound, true, language .. ' 真实抗性词缀存在任务来源')
		control:SetBreakdownData({ { breakdown = 'EnergyShieldRecharge' } })
		local rechargeText = table.concat(control.sectionList[1].lines, '\n')
		equal(rechargeText:find(language == 'en' and 'Effective Recharge rate:' or '有效充能速率：', 1, true) ~= nil, true, language .. ' 实际有效充能标题')
		local chaosNote = localisation:Text('calc.defence.build_defence_estimations.line.parameter_3')
		control:SetBreakdownData({ { breakdown = 'ChaosTakenHit' } })
		local chaosText = table.concat(control.sectionList[1].lines, '\n')
		equal(chaosText:find(chaosNote, 1, true) ~= nil, true, language .. ' 混沌击中说明显示双倍护盾承伤文字')
		equal(chaosText:find('true', 1, true), nil, language .. ' 混沌击中说明不显示布尔值')
		if cn or tw then
			for _, name in ipairs({ 'EnergyShieldRecharge', 'EnergyShieldRegenRecovery', 'RageRegenRecovery', 'FireResist' }) do
				control:SetBreakdownData({ { breakdown = name } })
				equal(StripEscapes(table.concat(control.sectionList[1].lines, '\n')):gsub('%f[%a]x%f[%A]', ''):find('%a'), nil, language .. ' 实际充能回复和抗性说明无英文：' .. name)
			end
		end
		-- 给实际计算环境添加可控来源，翻译不能参与来源筛选而漏掉门槛明细。
		for _, source in ipairs({ 'Tree', 'Item', 'Skill' }) do
			env.player.modDB:NewMod('StunThreshold', 'BASE', 17, source .. ':localisation-regression')
		end
		calcs.buildDefenceEstimations(env, env.player)
		local stunLines = table.concat(env.player.breakdown.StunThreshold, '\n')
		if cn or tw then
			equal(StripEscapes(stunLines):gsub('%f[%a]x%f[%A]', ''):find('%a'), nil, language .. ' 晕眩门槛的资源来源也已翻译')
			for _, name in ipairs({ 'ConfiguredDamageChance', 'ConfiguredNotHitChance' }) do
				equal(StripEscapes(table.concat(env.player.breakdown[name], '\n')):gsub('%f[%a]x%f[%A]', ''):find('%a'), nil, language .. ' 配置的击中类型嵌套参数已翻译：' .. name)
			end
		end
		for _, source in ipairs({ 'Tree', 'Item', 'Skill' }) do
			local value = env.player.modDB:Sum('BASE', { source = source }, 'StunThreshold')
			local expected = localisation:Text('calc.defence.build_defence_estimations.line_33', { source_val = value, source = localisation:TermRef('calculation_source', source) })
			equal(stunLines:find(expected, 1, true) ~= nil, true, language .. ' 晕眩门槛明细按原始来源身份筛选：' .. source)
		end
		-- 六种配置类型均走实际承伤计算，英文冠词片段不能混入中文参数。
		env.configInput = copyTable(env.configInput)
		local categoryValues = { }
		for _, category in ipairs({
			{ 'Average', 'n Average', '平均', '平均' },
			{ 'Untyped', 'n Untyped', '无类型', '無類型' },
			{ 'Melee', ' Melee', '近战', '近戰' },
			{ 'Projectile', ' Projectile', '投射物', '投射物' },
			{ 'Spell', ' Spell', '法术', '法術' },
			{ 'SpellProjectile', ' SpellProjectile', '投射物法术', '投射物法術' },
		}) do
			env.configInput.enemyDamageType = category[1]
			calcs.buildDefenceEstimations(env, env.player)
			local prefix = cn and category[3] or tw and category[4] or category[2]
			for _, specification in ipairs({
				{ 'ConfiguredDamageChance', 'calc.defence.build_defence_estimations.line_82' },
				{ 'ConfiguredNotHitChance', 'calc.defence.build_defence_estimations.line_92' },
			}) do
				local name, key = unpack(specification)
				local value = name == 'ConfiguredNotHitChance' and 100 - env.player.output[name] or env.player.output[name]
				local lines = env.player.breakdown[name]
				equal(lines[#lines], localisation:Text(key, { value = value, value_2 = prefix }), language .. ' 实际击中类型参数：' .. category[1] .. ':' .. name)
				categoryValues[category[1] .. ':' .. name] = env.player.output[name]
			end
		end
		categoryOutputs = categoryOutputs or categoryValues
		for identity, value in pairs(categoryOutputs) do equal(categoryValues[identity], value, language .. ' 六种击中类型的计算数值保持：' .. identity) end
		-- 永恒生命的资源池也有同一段说明，双倍承伤被禁用时应完整移除。
		env.player.modDB:NewMod('EternalLife', 'FLAG', true, 'Custom:localisation-chaos-note')
		calcs.buildDefenceEstimations(env, env.player)
		local poolText = table.concat(env.player.breakdown.ChaosTotalPool, '\n')
		equal(poolText:find(chaosNote, 1, true) ~= nil, true, language .. ' 永恒生命资源池显示双倍护盾承伤文字')
		equal(poolText:find('true', 1, true), nil, language .. ' 永恒生命资源池不显示布尔值')
		env.player.modDB:NewMod('ChaosNotDoubleESDamage', 'FLAG', true, 'Custom:localisation-chaos-note')
		calcs.buildDefenceEstimations(env, env.player)
		for _, name in ipairs({ 'ChaosTakenHit', 'ChaosTotalPool' }) do
			local text = table.concat(env.player.breakdown[name], '\n')
			equal(text:find(chaosNote, 1, true), nil, language .. ' 无双倍承伤时移除说明：' .. name)
			equal(text:find('true', 1, true), nil, language .. ' 无双倍承伤时不显示布尔值：' .. name)
		end
		-- 命中率距离表的当前配置标记必须走显示资源，不能遗漏在拼接字符串中。
		local accuracyText = table.concat(env.player.breakdown.HitChance, '\n')
		local configNote = language == 'en' and ' ^8(current config)' or cn and ' ^8(当前配置)' or ' ^8(目前設定)'
		equal(accuracyText:find(configNote, 1, true) ~= nil, true, language .. ' 实际命中率距离表包含当前配置译文')
		local bossThresholdFound = false
		for _, row in ipairs(env.player.breakdown.MainHand.ChillDPS.rowList) do
			local boss = language == 'en' and '(Pinnacle)' or cn and '(巅峰首领)' or '(巔峰頭目)'
			if row.thresh:find(boss, 1, true) then bossThresholdFound = true end
		end
		equal(bossThresholdFound, true, language .. ' 实际冰缓门槛标记翻译首领类别')
		-- 在真实来源表中加入已确认的内部来源，显示翻译不得改写来源身份和修饰词数值。
		local sources = {
			{ 'Chill', '冰缓', '冰緩' },
			{ 'Uptime Scaled Infernal Cry', '按覆盖率折算的炽焰战吼', '按覆蓋率換算的煉獄戰吼' },
			{ 'Bifurcated Crit Damage Bonus', '暴击分叉伤害加成', '暴擊分叉傷害加成' },
			{ 'Xesht', '席斯特', '薛斯特' },
		}
		for _, source in ipairs(sources) do env.player.modDB:NewMod('Damage', 'INC', 17, source[1]) end
		control:SetBreakdownData({ { modName = 'Damage', modType = 'INC' } })
		for _, source in ipairs(sources) do
			local found = false
			for _, row in ipairs(control.sectionList[1].rowList) do
				if row.mod.source == source[1] then
					equal(row.source, cn and source[2] or tw and source[3] or source[1], language .. ' 实际战吼与暴击来源译文：' .. source[1])
					equal(row.mod.value, 17, language .. ' 显示译文保留来源数值：' .. source[1])
					found = true
				end
			end
			equal(found, true, language .. ' 显示表仍可按原始来源查找：' .. source[1])
		end
		-- 非默认物理减免触发实际持续伤害倍率分支，英文保留原来的小写类型。
		env.player.modDB:NewMod('PhysicalDamageReduction', 'BASE', 17, 'Custom:localisation-dot-type')
		calcs.defence(env, env.player)
		calcs.buildDefenceEstimations(env, env.player)
		local dotText = table.concat(env.player.breakdown.PhysicalTakenDotMult, '\n')
		local reductionText = language == 'en' and 'physical damage reduction' or cn and '物理伤害减免' or '物理傷害減免'
		equal(dotText:find(reductionText, 1, true) ~= nil, true, language .. ' 实际持续伤害公式的嵌套类型已翻译')
	end
end
