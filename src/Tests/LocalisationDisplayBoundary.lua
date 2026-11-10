-- 显示边界回归：资源解析由调用点负责，绘制、提示框及通用搜索不反查英文。
return function(build, equal)
	local languageBefore = localisation.language
	equal(localisation.Translate, nil, '已移除全局显示反查接口')
	equal(localisation.Match, nil, '已移除通用搜索反查接口')
	for _, language in ipairs({ 'en', 'zh-CN', 'zh-TW', 'en' }) do
		localisation:SetLanguage(language)
		local tooltip = new('Tooltip'):Tooltip()
		tooltip:AddLine(16, 'Fireball')
		equal(tooltip.lines[1].text, 'Fireball', language .. ' 提示框保留调用点原文')
		local translated = localisation:Field(data.skills.FireballPlayer, 'name')
		tooltip:Clear(); tooltip:AddLine(16, translated)
		equal(tooltip.lines[1].text, translated, language .. ' 显式字段进入提示框')
		equal(translated ~= 'Fireball', language ~= 'en', language .. ' 技能资源随语言刷新')
		build.importTab:RefreshBuildPlannerSets()
		for _, id in ipairs({ 'buildPlannerSpec', 'buildPlannerSkillSet', 'buildPlannerItemSet' }) do
			local control = assert(build.importTab.controls[id])
			for _, entry in ipairs(control.list) do
				if entry.labelKey then equal(localisation:Field(entry, 'label'), localisation:Text(entry.labelKey), language .. ' 导出配装默认资源')
				else equal(localisation:Field(entry, 'label'), entry.label, language .. ' 导出用户配装名保留') end
			end
		end
		local spec = build.treeTab.specList[1]
		local titleBefore, keyBefore = spec.title, spec.titleKey
		spec.title, spec.titleKey = 'My Fireball Build', nil
		build.importTab:RefreshBuildPlannerSets()
		equal(localisation:Field(build.importTab.controls.buildPlannerSpec.list[1], 'label'), spec.title, language .. ' 导出自定义名称不变为默认')
		spec.title, spec.titleKey = titleBefore, keyBefore
		build:SyncLoadouts()
		local list = build.controls.buildLoadouts.list
		if list[2] == 'Default' then equal(localisation:ListLabel(list, 2), localisation:Text('term.calculation_source.default'), language .. ' 默认配装标签绑定引用') end
		equal(localisation:SocketGroupName({ label = 'Thorns', source = 'Thorns' }), localisation:Text('ui.calc_setup.init_env.group.label_2'), language .. ' 导入自动组恢复资源引用')
		local viewport = { x = 0, y = 0, width = 1920, height = 1080 }
		for _, tab in ipairs({ build.itemsTab, build.skillsTab, build.configTab }) do
			tab:Draw(viewport, { })
			for index, value in ipairs(tab.controls.setSelect.list) do
				local sets = tab.itemSets or tab.skillSets or tab.configSets
				local order = tab.itemSetOrderList or tab.skillSetOrderList or tab.configSetOrderList
				local source = sets[order[index]]
				if not source.title or source.titleKey then
					equal(localisation:ListLabel(tab.controls.setSelect.list, index), localisation:Text('term.calculation_source.default'), language .. ' 自动配装名称绑定资源')
				else
					equal(localisation:ListLabel(tab.controls.setSelect.list, index), value, language .. ' 已命名配装原文保留')
				end
			end
		end
		local actor = { output = { PierceCountString = 'All targets', ForkCountString = 'Cannot fork', SplitCountString = 3, Life = 42 } }
		equal(formatCalcField({ value = '{output:PierceCountString}' }, 'value', actor), localisation:Text('calcs.projectile.all_targets'), language .. ' 投射状态按字段枚举解析')
		equal(formatCalcField({ value = '{output:ForkCountString}' }, 'value', actor), localisation:Text('calcs.projectile.cannot_fork'), language .. ' 无法分叉状态解析')
		equal(formatCalcField({ value = '{output:SplitCountString}' }, 'value', actor), '3', language .. ' 投射物数量不变')
		equal(formatCalcField({ value = '{output:Life}' }, 'value', actor), '42', language .. ' 普通数值不查词典')
		equal(actor.output.PierceCountString, 'All targets', language .. ' 计算原始输出不变')
		equal(localisation:SocketGroupName({ label = 'Fireball', gemList = { } }), 'Fireball', language .. ' 用户技能组名称原样保留')
		equal(localisation:SocketGroupName({ label = 'Thorns', labelKey = 'term.calculation_flag.thorns' }), localisation:Text('term.calculation_flag.thorns'), language .. ' 自动技能组引用刷新')
	end
	localisation:SetLanguage(languageBefore)
end
