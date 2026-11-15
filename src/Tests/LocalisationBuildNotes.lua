-- 备注系统文字翻译，用户正文、颜色标签和字号标签保持原样。
return function(build, equal)
	local languageBefore, note = localisation.language, 'My Fireball Note <b>{测试}'
	main:OpenNoteEditPopup(nil, note, function() error('备注回归不应保存用户正文') end)
	local popup = main.popups[1]
	local styles = { 'Regular', 'Bold', 'Italic', 'Underline', 'Small', 'Medium', 'Large' }
	local colors = { 'NORMAL', 'MAGIC', 'RARE', 'UNIQUE', 'RELIC', 'GEM', 'FIRE', 'COLD', 'LIGHTNING', 'CHAOS', 'STRENGTH', 'DEXTERITY', 'INTELLIGENCE', 'POSITIVE', 'NEGATIVE', 'WARNING', 'TIP', 'CURRENCY' }
	for _, language in ipairs({ 'en', 'zh-CN', 'zh-TW', 'en' }) do
		localisation:SetLanguage(language)
		equal(popup.controls.edit.buf, note, language .. ' 备注正文原样保留')
		for _, style in ipairs(styles) do
			local control = assert(popup.controls['font' .. style])
			local label = StripEscapes(control:GetProperty('label'))
			if language == 'en' then equal(label, style, '英文字体按钮保持')
			else equal(label:find('%a'), nil, language .. ' 字体按钮翻译') end
			equal(control:GetProperty('tooltipText'), localisation:Text('build_note.markup_help'), language .. ' 共享标签提示翻译')
		end
		for _, code in ipairs(colors) do
			local control = assert(popup.controls['color' .. code])
			equal(StripEscapes(control:GetProperty('label')), localisation:Text('build_note.color.' .. code:lower()), language .. ' 颜色按钮按资源显示')
		end
		local tooltip = new('Tooltip'):Tooltip()
		local slot = build.itemsTab.slots.Helmet
		local original = slot.note
		slot.note = nil; slot.controls.noteButton.tooltipFunc(tooltip)
		equal(tooltip.lines[1].text, localisation:Text('build_note.empty_item_slot'), language .. ' 空物品备注提示翻译')
		tooltip:Clear(); slot.note = note; slot.controls.noteButton.tooltipFunc(tooltip)
		equal(tooltip.lines[1].text:find('My Fireball Note', 1, true) ~= nil, true, language .. ' 用户英文备注不翻译')
		slot.note = original
		-- 同时走技能和天赋的真实提示框，验证系统前缀与用户英文正文分开处理。
		local gem = assert(data.gems['Metadata/Items/Gems/SkillGemFireball'])
		local instance = { gemData = gem, grantedEffect = gem.grantedEffect, level = 1, quality = 0, nameSpec = gem.name, note = note }
		local gemTip = new('Tooltip'):Tooltip()
		LoadModule('Classes/GemTooltip').AddGemTooltip(gemTip, build, instance, { includeBuildPlannerNote = true })
		local node
		for _, candidate in pairs(build.spec.nodes) do if candidate.dn and candidate.dnKey then node = candidate; break end end
		assert(node, '备注提示框缺少实际天赋样本')
		local notesBefore, differencesBefore = build.spec.nodeNotes, build.treeTab.viewer.showStatDifferences
		build.spec.nodeNotes = { [node.id] = note }
		build.treeTab.viewer.showStatDifferences = false
		local nodeTip = new('Tooltip'):Tooltip()
		build.treeTab.viewer:AddNodeTooltip(nodeTip, node, build, 0)
		build.spec.nodeNotes, build.treeTab.viewer.showStatDifferences = notesBefore, differencesBefore
		for _, tip in ipairs({ gemTip, nodeTip }) do
			local found = false
			for _, line in ipairs(tip.lines) do
				if line.text and StripEscapes(line.text):find(localisation:Text('build_note.prefix') .. 'My Fireball Note', 1, true) then found = true end
			end
			equal(found, true, language .. ' 实际备注提示框前缀翻译且英文正文保留')
		end
		equal(instance.note, note, language .. ' 技能备注原始内容保持')
	end
	main:ClosePopup()
	localisation:SetLanguage(languageBefore)
end
