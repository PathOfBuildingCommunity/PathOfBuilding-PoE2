-- 用独立构筑和实际控件验证灵体详情、自动技能组及主技能下拉框。
return function(equal)
	local languageBefore = localisation.language
	local minionId
	for id, minion in pairs(data.minions) do
		if minion.name == 'Black Scythe Arbalest' then minionId = id; break end
	end
	assert(minionId, '缺少灵体界面回归样本')
	loadBuildFromXML('<PathOfBuilding2><Build targetVersion="' .. liveTargetVersion .. '" level="90" className="Witch"><Spectre id="' .. minionId .. '"/></Build><Skills activeSkillSet="1"><SkillSet id="1"><Skill enabled="true" mainActiveSkill="1" set1="true" set2="true"><Gem gemId="Metadata/Items/Gems/SkillGemSummonSpectre" nameSpec="Spectre: Black Scythe Arbalest" enableGlobal1="true" enableGlobal2="true" level="20" quality="0" enabled="true" skillMinion="' .. minionId .. '"/></Skill></SkillSet></Skills></PathOfBuilding2>', 'Localisation minion interface')
	build:OpenSpectreLibrary('spectre')
	local popup = main.popups[1]
	local controls = popup.controls
	controls.source.selValue = minionId
	controls.source:OnSelect()
	local minion = data.minions[minionId]
	local rawName = minion.name
	local viewport = { x = 0, y = 0, width = 1920, height = 1080 }
	local group = build.skillsTab.socketGroupList[1]
	build.mainSocketGroup = 1
	build:RefreshSkillSelectControls(build.controls, 1, '')
	local rawGroup = group.displayLabel
	for _, language in ipairs({ 'en', 'zh-CN', 'zh-TW', 'en' }) do
		localisation:SetLanguage(language)
		local draw, drawn = DrawString, { }
		DrawString = function(x, y, align, height, font, text) drawn[#drawn + 1] = text end
		local ok, err = pcall(controls.minionNameLabel.Draw, controls.minionNameLabel, viewport)
		DrawString = draw
		assert(ok, err)
		equal(drawn[1], '^7' .. localisation:Field(minion, 'name'), language .. ' 已选灵体标题在不重选时随语言刷新')
		equal(controls.spawnLocations:GetProperty('label'), language == 'en' and 'Spawns:' or language == 'zh-CN' and '出生地点：' or '出現地點：', language .. ' 实际出生地点标题使用专用资源')
		local expectedGroup = language == 'en' and rawGroup or localisation:Text('skill.active.spectre', { minion = localisation:Field(minion, 'name') })
		equal(localisation:Field(build.controls.mainSocketGroup.list[1], 'label'), expectedGroup, language .. ' 主技能组下拉框显示自动译名')
		local active = group.displaySkillList[1]
		local label = localisation:Field(build.controls.mainSkill.list[1], 'label')
		if language == 'en' then
			equal(label, build.calcsTab.calcs.getActiveSkillDisplayName(active), '英文主动技能名称保持原行为')
		else
			equal(label:find('{0}', 1, true), nil, language .. ' 主技能名称没有未展开占位符')
			equal(label:find('%a'), nil, language .. ' 实际灵体技能名称已翻译')
			equal(localisation:Field(build.controls.statSet.list[1], 'label'):find('%a'), nil, language .. ' 实际召唤物属性组标签已翻译')
			for _, entry in ipairs(build.controls.mainSkillMinionSkill.list) do equal(localisation:Field(entry, 'label'):find('%a'), nil, language .. ' 实际召唤物技能下拉框已翻译') end
		end
		group.label = '用户标签 Fireball'
		equal(localisation:Field(build.controls.mainSocketGroup.list[1], 'label'), group.label, language .. ' 主技能下拉框保留用户组名')
		group.label = nil
		equal(group.displayLabel, rawGroup, language .. ' 自动组名显示不改写原始字段')
		equal(group.gemList[1].nameSpec, 'Spectre: ' .. rawName, language .. ' 动态灵体宝石保存身份保持')
		equal(minion.name, rawName, language .. ' 灵体内部名称保持')
		equal(build.spectreList[1], minionId, language .. ' 灵体保存身份保持')
	end
	main:ClosePopup()
	localisation:SetLanguage(languageBefore)
end
