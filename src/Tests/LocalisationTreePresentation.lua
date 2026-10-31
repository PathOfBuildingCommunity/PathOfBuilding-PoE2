-- 天赋风味和职业显示使用已绑定资源；标题和界面显示不得改写构筑身份。
return function(build, equal)
	local originalLanguage = localisation.language
	local originalFlavour, originalTitlebar = main.showFlavourText, main.showTitlebarName
	local originalTitle = SetWindowTitle
	main.showFlavourText, main.showTitlebarName = true, true
	local captured
	SetWindowTitle = function(text) captured = text end
	local saved = { }
	for _, node in pairs(build.spec.nodes) do
		if node.flavourText then saved[#saved + 1] = { node = node, flavour = node.flavourText } end
	end
	for _, language in ipairs({ 'en', 'zh-CN', 'zh-TW', 'en' }) do
		localisation:SetLanguage(language)
		for _, entry in ipairs(saved) do
			local node, source = entry.node, entry.flavour
			local text = localisation:Field(node, 'flavourText')
			if language == 'en' then equal(text, source, '全部天赋风味英文原文保持：' .. node.id)
			else
				equal(text:find('%a'), nil, language .. ' 全部天赋风味无英文或网页标记：' .. node.id)
				equal(text:find('[{}<>]'), nil, language .. ' 风味字面术语不泄漏模板标记：' .. node.id)
			end
			local _, expectedBreaks = source:gsub('\n', '')
			local _, actualBreaks = text:gsub('\n', '')
			equal(actualBreaks, expectedBreaks, language .. ' 风味段落数保持：' .. node.id)
			local tooltip = new('Tooltip'):Tooltip()
			build.treeTab.viewer:AddNodeTooltip(tooltip, node, build, 0)
			local lines = { }
			for _, line in ipairs(tooltip.lines) do
				if line.font == 'FONTIN ITALIC' and line.text then
					if #lines == 0 then equal(line.text:sub(1, #colorCodes.UNIQUE), colorCodes.UNIQUE, language .. ' 风味保留颜色：' .. node.id) end
					lines[#lines + 1] = StripEscapes(line.text)
				end
			end
			equal(table.concat(lines):gsub('%s', ''), text:gsub('%s', ''), language .. ' 实际提示框保留全部风味文字：' .. node.id)
			equal(node.flavourText, source, language .. ' 风味解析原文未修改：' .. node.id)
		end
		for _, class in pairs(build.spec.tree.classes) do
			local className = class.name
			for ascendId, ascend in pairs(class.classes) do
				-- 使用真实树对象调用标题方法，不改变构筑当前职业、天赋或用户标题。
				local spec = { build = { buildName = 'Fireball 中文构筑 123' }, curClass = class, curAscendClass = ascend,
					curClassName = class.name, curAscendClassName = ascend.name, curAscendClassId = ascendId }
				build.spec.SetWindowTitleWithBuildClass(spec)
				local current = ascendId == 0 and class or ascend
				local display = localisation:Field(current, 'name')
				if language ~= 'en' then equal(display:find('%a'), nil, language .. ' 所有当前职业及升华名称均为中文：' .. current.name) end
				if current.name == 'Martial Artist' then equal(display, language == 'en' and 'Martial Artist' or language == 'zh-CN' and '武圣' or '武術家', language .. ' 原生窗口已知职业译名') end
				equal(captured, 'Fireball 中文构筑 123 (' .. display .. ') - ' .. APP_NAME, language .. ' 真实原生标题参数使用职业资源：' .. current.name)
				equal(class.name, className, language .. ' 职业原名保持')
				equal(spec.curAscendClassName, ascend.name, language .. ' 升华原名保持')
			end
		end
		local tooltip = new('Tooltip'):Tooltip()
		build.treeTab.controls.specSelect.tooltipFunc(tooltip, 'IN', build.treeTab.activeSpec)
		for _, field in ipairs({ { 'curClass', 'cur_class_name', 'tooltip_2' }, { 'curAscendClass', 'cur_ascend_class_name', 'tooltip' } }) do
			local expected = localisation:Text('ui.tree_tab.init.spec_select_tooltip_func.' .. field[3], { [field[2]] = localisation:Field(build.spec[field[1]], 'name') })
			local found = false
			for _, line in ipairs(tooltip.lines) do if line.text == expected then found = true end end
			equal(found, true, language .. ' 天赋组实际提示框使用职业显示资源：' .. field[1])
		end
	end
	-- 实际帧在语言变化后刷新原生标题，用户无需切换职业或重新打开构筑。
	build:OnFrame({ })
	for _, language in ipairs({ 'zh-CN', 'zh-TW', 'en' }) do
		localisation:SetLanguage(language)
		captured = nil
		build.viewMode = 'TREE'
		build:OnFrame({ })
		local current = build.spec.curAscendClassId == 0 and build.spec.curClass or build.spec.curAscendClass
		equal(captured, build.buildName .. ' (' .. localisation:Field(current, 'name') .. ') - ' .. APP_NAME, language .. ' 切换语言后实际帧刷新窗口标题')
	end
	main.showTitlebarName = false
	build.spec:SetWindowTitleWithBuildClass()
	equal(captured, APP_NAME, '关闭标题显示时保持应用名称')
	equal(#saved, 46, '当前树全部风味字段均进入回归')
	SetWindowTitle = originalTitle
	main.showFlavourText, main.showTitlebarName = originalFlavour, originalTitlebar
	localisation:SetLanguage(originalLanguage)
end
