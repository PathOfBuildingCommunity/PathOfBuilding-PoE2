-- 核对完整跨行条件、增减方向和独立数值，避免片段均为中文却改变节点含义。
return function(build, equal)
	local originalLanguage = localisation.language
	local cases = {
		{ id = 14226, first = 1, last = 2,
			cn = '技能速度总增 25%，条件是副手为空，且\n主手装备单手军用武器',
			tw = '技能速度更多 25%，條件是副手為空，且\n主手裝備單手軍用武器' },
		{ id = 24483, first = 1, last = 2,
			cn = '暴击几率提高 35%，针对未受到\n任何元素异常状态影响的敌人',
			tw = '增加 35% 暴擊率，針對未受到\n任何元素異常狀態影響的敵人' },
		{ id = 29881, first = 1, last = 2,
			cn = '变回人形时获得秘术增幅，前提是已\n持续变形至少 8 秒',
			tw = '變回人形時獲得秘術增幅，前提是已\n持續變形至少 8 秒' },
		{ id = 30996, first = 1, last = 4,
			cn = '每种镶嵌数量最多的辅助宝石颜色分别提供：\n红色：对你的击中没有暴击伤害加成\n蓝色：技能消耗总降 30%\n绿色：移动时使用技能的移动速度惩罚总降 40%',
			tw = '每種鑲嵌數量最多的輔助寶石顏色分別提供：\n紅色：對你的擊中沒有暴擊傷害加成\n藍色：技能消耗更少 30%\n綠色：移動時使用技能的移動速度懲罰更少 40%' },
		{ id = 32151, first = 1, last = 2,
			cn = '所有元素抗性上限 +1%，条件是已镶嵌\n红、绿、蓝色辅助宝石各至少 5 个',
			tw = '全部最大元素抗性 +1%，條件是已鑲嵌\n紅、綠、藍色輔助寶石各至少 5 顆' },
		{ id = 38570, first = 1, last = 2,
			cn = '获得相当于伤害 4% 的额外火焰伤害，按下列数量叠加：\n过去 8 秒内发射的不同榴弹种类数',
			tw = '獲得等同於傷害 4% 的額外火焰傷害，依下列數量疊加：\n過去 8 秒內發射的不同榴彈種類數' },
		{ id = 4367, first = 1, last = 2,
			cn = '翻滚时最多可消耗 2 根枭之羽毛，每额外消耗一根，使枭羽馈赠获得 100% 总增的\n强化效果',
			tw = '翻滾最多可消耗 2 片貓頭鷹羽毛，每額外消耗一片，使原始賞金獲得 100% 更多的\n強化效果' },
		{ id = 49363, first = 3, last = 4,
			cn = '消耗总降 50%\n持续时间总降 75%',
			tw = '消耗更少 50%\n持續時間更少 75%' },
		{ id = 58932, first = 3, last = 3,
			cn = '完整支付上述牺牲的法术，伤害总增 30%',
			tw = '完整支付上述犧牲的法術，傷害更多 30%' },
		{ id = 64601, first = 3, last = 5,
			cn = '基础徒手物理伤害改为基于技能等级的伤害\n装备的护甲物品每有 75 点物品闪避值，攻击速度总增 1%\n装备的护甲物品每有 10 点物品能量护盾，暴击几率 +0.1%',
			tw = '基礎徒手物理傷害改為基於技能等級的傷害\n裝備的護甲物品每有 75 點物品閃避值，攻擊速度更多 1%\n裝備的護甲物品每有 10 點物品能量護盾，暴擊率 +0.1%' },
		{ id = 11526, first = 1, last = 2,
			cn = '箭矢的暴击几率随穿越的距离而提高，\n7 米后暴击几率最多提高 40%',
			tw = '箭矢的暴擊率隨飛行距離提高，最多在\n7 公尺後增加 40% 暴擊率' },
		{ id = 11230, first = 1, last = 1,
			cn = '祈求技能改为每 2 秒触发法术',
			tw = '祈願技能改為每 2 秒觸發法術' },
		{ id = 34478, first = 2, last = 2,
			cn = '伙伴击中时有 40% 的几率施加中毒',
			tw = '夥伴擊中時有 40% 機率造成中毒' },
		{ id = 55375, first = 2, last = 2,
			cn = '存在范围内每有一个召唤生物，生命和魔力再生速率提高 5%，最多提高 40%',
			tw = '存在範圍內每有一個召喚物，增加 5% 生命及魔力再生率，最多 40%' },
		{ id = 56237, first = 1, last = 1,
			cn = '过去 8 秒内使用的每种不同的非瞬发攻击，使法术伤害提高 12%',
			tw = '過去 8 秒內使用的每種不同的非瞬發攻擊，增加 12% 法術傷害' },
		{ id = 56857, first = 1, last = 2,
			cn = '你当前能量护盾的 60% 会计入你的护甲，用于\n计算护甲提供的物理伤害减免',
			tw = '你目前能量護盾的 60% 會計入護甲，用於\n計算護甲提供的物理傷害減免' },
	}
	for _, id in ipairs({ 39102, 43486, 54289 }) do
		cases[#cases + 1] = { id = id, first = 1, last = 2,
			cn = '有 2% 的几率在获得暴击球时改为获得最多\n你的暴击球上限数量',
			tw = '若你會獲得暴擊球，有2%的機率改為獲得\n最大數量的暴擊球' }
	end
	-- 自动换行可能拆开词组；只移除显示空白，保留全部汉字、数字、标点及顺序。
	local function compact(text)
		return StripEscapes(text):gsub('%s', '')
	end
	for _, case in ipairs(cases) do
		local node = assert(build.spec.nodes[case.id], '缺少跨行语义回归节点')
		case.node, case.name, case.source = node, node.dn, { }
		for i, line in ipairs(node.sd) do case.source[i] = line end
	end
	for _, language in ipairs({ 'en', 'zh-CN', 'zh-TW', 'en' }) do
		localisation:SetLanguage(language)
		for _, case in ipairs(cases) do
			local node, rows, source = case.node, { }, { }
			for index = case.first, case.last do
				rows[#rows + 1] = localisation:Line(node, 'sd', index)
				source[#source + 1] = case.source[index]
			end
			local expected = language == 'en' and table.concat(source, '\n') or language == 'zh-CN' and case.cn or case.tw
			equal(table.concat(rows, '\n'), expected, language .. ' 完整条件和数值：' .. case.id)
			local tooltip = new('Tooltip'):Tooltip()
			build.treeTab.viewer:AddNodeTooltip(tooltip, node, build, 0)
			local displayed = { }
			-- 未支持属性每行另带警告；移除此固定后缀后核对原句，不把警告插入当成译文缺失。
			local unsupported = StripEscapes(localisation:Field(main, 'notSupportedTooltipText'))
			for _, line in ipairs(tooltip.lines) do
				local text = StripEscapes(line.text or '')
				if #unsupported > 0 and text:sub(-#unsupported) == unsupported then text = text:sub(1, -#unsupported - 1) end
				displayed[#displayed + 1] = text
			end
			-- 警告本身也可能被按字形换行，拼回正文后再移除完整固定后缀。
			local rendered = compact(table.concat(displayed, '\n'))
			if #unsupported > 0 then
				local pattern = compact(unsupported):gsub('([%%%^%$%(%)%.%[%]%*%+%-%?])', '%%%1')
				rendered = rendered:gsub(pattern, '')
			end
			equal(rendered:find(compact(expected), 1, true) ~= nil, true, language .. ' 真实提示框保留完整语义：' .. case.id)
			equal(node.dn, case.name, language .. ' 节点解析名称保持：' .. case.id)
			for index, line in ipairs(case.source) do equal(node.sd[index], line, language .. ' 原始属性保持：' .. case.id .. ':' .. index) end
		end
		local gift = assert(build.spec.nodes[11184])
		equal(localisation:Field(gift, 'dn'), language == 'en' and "Zarokh's Gift" or language == 'zh-CN' and '扎洛卡之赠' or '澤洛克之贈', language .. ' 珠宝插槽正文不覆盖节点名称')
		-- 同一模板参数名在两行分别表示伤害百分比和秒数，增效时仍应各自替换。
		local demolitionist = assert(build.spec.nodes[38570])
		local damage = localisation:Line(demolitionist, 'sd', 1, 'Gain 12% of Damage as Extra Fire Damage for')
		local duration = localisation:Line(demolitionist, 'sd', 2, 'every different Grenade fired in the past 16 seconds')
		equal(damage:find('12%%') ~= nil, true, language .. ' 增效伤害使用第一行数值')
		equal(duration:find('16', 1, true) ~= nil, true, language .. ' 时间使用第二行独立数值')
		equal(duration:find('12', 1, true), nil, language .. ' 伤害数值不串入持续时间')
	end
	localisation:SetLanguage(originalLanguage)
end
