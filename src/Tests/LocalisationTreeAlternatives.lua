-- 覆盖职业分支及当前珠宝转换的标题和正文，避免只检查当前职业默认树。
return function(build, equal)
	local languageBefore = localisation.language
	local cases, sharedNames, optionCount = { }, 0, 0
	for id, node in pairs(build.spec.tree.nodes) do
		for optionId, option in pairs(node.options or { }) do
			cases[#cases + 1] = { base = build.spec.nodes[id], node = option, label = id .. ':' .. optionId }
			optionCount = optionCount + 1
			if option.dn == node.dn and not rawget(option, 'name') then
				equal(option.dnKey, node.dnKey, '沿用父名称的选项复用父名称资源：' .. id)
				sharedNames = sharedNames + 1
			end
		end
	end
	local keystoneBase
	for _, node in pairs(build.spec.nodes) do if node.type == 'Keystone' then keystoneBase = node; break end end
	local keystones, tribute = 0, 0
	for _, node in pairs(build.spec.tree.legion.nodes) do
		if node.id:match('^abyss_keystone_') or node.id:match('^kalguur_keystone_') or node.id == 'abyss_small_tribute' then
			cases[#cases + 1] = { base = keystoneBase, node = node, label = node.id }
			if node.type == 'Keystone' then keystones = keystones + 1 else tribute = tribute + 1 end
		end
	end
	-- 独立树通过真实珠宝半径处理追加贡品，避免测试只手工拼接显示引用。
	local spec = new('PassiveSpec'):PassiveSpec(build, build.spec.treeVersion)
	local socket
	for _, node in pairs(spec.nodes) do if node.type == 'Socket' and node.nodesInRadius then socket = node; break end end
	assert(socket, '缺少珠宝半径回归插槽')
	spec.build = setmetatable({ itemsTab = { items = { [1] = { jewelRadiusIndex = 3, jewelData = { conqueredBy = { id = 1, conqueror = { type = 'abyss', id = 1 } } } } } } }, { __index = build })
	spec.jewels[socket.id], spec.allocNodes[socket.id], socket.alloc = 1, socket, true
	spec:BuildAllDependsAndPaths()
	local added = { }
	for _, node in pairs(spec.nodes) do if node.sd[#node.sd] == '+3 to Tribute' then added[#added + 1] = node end end
	equal(#added > 0, true, '真实珠宝半径覆盖属性节点追加贡品')
	local allowed = { I = true, II = true, III = true, IV = true, V = true }
	for _, language in ipairs({ 'en', 'zh-CN', 'zh-TW', 'en' }) do
		localisation:SetLanguage(language)
		for _, node in ipairs(added) do
			local index = #node.sd
			local expected = language == 'en' and '+3 to Tribute' or language == 'zh-CN' and '+3 贡品' or '+3 貢品'
			equal(localisation:Line(node, 'sd', index), expected, language .. ' 珠宝追加属性使用当前数值')
			equal(node.sd[index], '+3 to Tribute', '追加贡品保留英文计算原文')
			local tooltip = new('Tooltip'):Tooltip()
			-- 使用现有构筑的实际半径入口，让提示框执行完整属性重解析。
			local socketsBefore = build.itemsTab.sockets
			local showDifferencesBefore = build.treeTab.viewer.showStatDifferences
			build.treeTab.viewer.showStatDifferences = false
			build.itemsTab.sockets = { [socket.id] = { inactive = false } }
			build.treeTab.viewer:AddNodeTooltip(tooltip, node, build, 0)
			build.itemsTab.sockets = socketsBefore
			build.treeTab.viewer.showStatDifferences = showDifferencesBefore
			local found = false
			for _, line in ipairs(tooltip.lines) do
				if line.text and StripEscapes(line.text) == expected then found = true end
			end
			equal(found, true, language .. ' 真实半径提示框重解析后保留追加属性翻译')
		end
		for _, case in ipairs(cases) do
			local node, source = case.node, case.node.dn
			local title = localisation:Field(node, 'dn')
			if language == 'en' then equal(title, source, '英文选项与珠宝转换名称原文保持：' .. case.label)
			else equal(title:find('%a'), nil, language .. ' 当前选项与珠宝转换标题为中文：' .. case.label) end
			-- 使用实际替换方法继承几何与连通信息，替换对象不写回当前构筑。
			local replaced = setmetatable({ sd = { } }, { __index = case.base })
			build.spec:ReplaceNode(replaced, node)
			equal(replaced.dn, source, '真实替换路径保留业务名称：' .. case.label)
			equal(localisation:Field(replaced, 'dn'), title, language .. ' 真实替换路径保留显示引用：' .. case.label)
			local tooltip = new('Tooltip'):Tooltip()
			build.treeTab.viewer:AddNodeTooltip(tooltip, replaced, build, 0)
			local rendered = { }
			for _, line in ipairs(tooltip.lines) do if line.text then rendered[#rendered + 1] = StripEscapes(line.text) end end
			equal(table.concat(rendered):gsub('%s', ''):find(title:gsub('%s', ''), 1, true) ~= nil, true, language .. ' 替换节点标题进入实际提示框：' .. case.label)
			for index, sourceLine in ipairs(node.sd or { }) do
				local display = localisation:Line(replaced, 'sd', index)
				if language == 'en' then equal(display, sourceLine, '英文选项属性原文保持：' .. case.label)
				else
					for word in StripEscapes(display):gmatch('%a+') do equal(allowed[word] == true, true, language .. ' 选项属性无英文残留：' .. case.label .. ' / ' .. display) end
				end
				equal(replaced.sd[index], sourceLine, '替换显示未改写计算属性：' .. case.label)
			end
			equal(node.dn, source, '源节点名称保持')
		end
	end
	equal(keystones, 8, '覆盖当前全部深渊与卡尔古珠宝传奇转换')
	equal(tribute, 1, '覆盖普通节点贡品替换')
	equal(sharedNames > 0, true, '覆盖沿用父节点名称的职业选项')
	localisation:SetLanguage(languageBefore)
	print(string.format('职业选项与珠宝转换实际回归：%d 个选项，%d 个传奇转换，普通贡品替换和 %d 个属性节点追加', optionCount, keystones, #added))
end
