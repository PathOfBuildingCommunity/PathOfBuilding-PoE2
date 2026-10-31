-- 使用实际制作弹窗覆盖可生成的前后缀、精华和情感，核对显示与选择身份。
return function(build, equal)
	local languageBefore = localisation.language
	local displayBefore = build.itemsTab.displayItem
	local bases = {
		'Abyssal Signet', 'Diamond', 'Double Belt', 'Chiming Staff', 'Garment', 'Akoyan Spear',
		'Colossal Life Flask', 'Absent Amulet', 'Aureate Targe', 'Adherent Leggings', 'Aromatic Sceptre',
		'Amethyst Charm', 'Avian Mask', 'Blunt Quiver', 'Abyssal Cuirass', 'Ancient Mail', 'Armoured Vest',
		"Adherent's Raiment", 'Ancestral Mail', 'Aged Tower Shield', 'Colossal Mana Flask', 'Trarthan Cannon',
		'Aegis Buckler', 'Anchorite Garb', 'Ancient Visor', 'Archon Crown', 'Armoured Cap', 'Bangled Sandals',
		'Bladed Shoes', 'Commander Greathelm', 'Ancestral Tiara', 'Fishing Rod', 'Adherent Bow', 'Alloy Crossbow',
		'Time-Lost Diamond', 'Acrid Wand', 'Adherent Cuffs', 'Mnemonic Ring', 'Secured Wraps', 'Fierce Greathelm',
		'Plate Belt', 'Ochre Sceptre', 'Scimitar', 'Offering Wand', 'Oiled Jacket', 'Ruby', 'Sapphire', 'Emerald',
		'Time-Lost Ruby', 'Time-Lost Sapphire', 'Time-Lost Emerald',
		'Adorned Wraps', 'Golden Visage', 'Ashen Staff', 'Aberrant Sledge', 'Antler Focus',
		'Golden Flame', 'Akoyan Club', 'Aegis Quarterstaff', 'Alpha Talisman',
	}
	local seenAffixes, seenEssences, seenEmotions, residuals = { }, { }, { }, { }
	local magicItems, checkedTitles = { }, { }
	local originalComparison = build.itemsTab.AddModComparisonTooltip
	-- 本测试遍历词缀正文；数值比较另由真实预览和现有计算回归覆盖。
	build.itemsTab.AddModComparisonTooltip = function() end
	local allowed = { x = true, s = true, m = true, ms = true, I = true, II = true, III = true, IV = true, V = true, VI = true, VII = true, VIII = true, IX = true, X = true, DPS = true }
	local function chinese(text, context)
		for word in StripEscapes(text):gmatch('%a+') do
			if not allowed[word] then residuals[context .. ': ' .. text] = true; break end
		end
	end
	for _, name in ipairs(bases) do
		local item = new('Item'):Item('Rarity: RARE\nLocalisation user name\n' .. name)
		assert(item.base, '制作回归基底无法解析：' .. name)
		build.itemsTab.displayItem = item
		local raw = item:BuildRaw()
		build.itemsTab:AddCustomModifierToDisplayItem()
		local popup = main.popups[1]
		for sourceIndex, source in ipairs(popup.controls.source.list) do
			if source.sourceId ~= 'CUSTOM' then
				popup.controls.source:SetSel(sourceIndex)
				local entries = popup.controls.modSelect.list
				local english = { }
				for _, language in ipairs({ 'en', 'zh-CN', 'zh-TW', 'en' }) do
					localisation:SetLanguage(language)
					for index, entry in ipairs(entries) do
						local label = localisation:Field(entry, 'label')
						if language == 'en' then
							equal(label, entry.label, '英文制作选项原文保持：' .. name .. ' / ' .. source.sourceId)
							if english[index] then equal(label, english[index], '切回英文恢复完整制作选项') else english[index] = label end
						else
							chinese(label, language .. ' ' .. source.sourceId .. ' ' .. name)
						end
						local tooltip = new('Tooltip'):Tooltip()
						popup.controls.modSelect.tooltipFunc(tooltip, 'HOVER', index, entry)
						for lineIndex, line in ipairs(tooltip.lines) do
							if line.text then
								if language == 'en' then equal(StripEscapes(line.text), entry.mod[lineIndex], '英文词缀悬停原文保持')
								else chinese(line.text, language .. ' 词缀悬停 ' .. name) end
							end
						end
						if source.sourceId == 'PREFIX' or source.sourceId == 'SUFFIX' or source.sourceId == 'RUNEINFLUENCED' or source.sourceId == 'DESECRATED' then
							seenAffixes[entry.mod.affix] = true
							if language ~= 'en' then chinese(localisation:DataText('equipment_affix', entry.mod.affix, 'name', entry.mod.affix), language .. ' 前后缀名称') end
							local affix = entry.mod.affix
							if not magicItems[affix] then
								local title = entry.mod.type == 'Prefix' and affix .. ' ' .. name or name .. ' ' .. affix
								local magic = new('Item'):Item('Rarity: MAGIC\n' .. title)
								assert(magic.base and not magic.title, '魔法物品标题无法解析：' .. title)
								magicItems[affix] = { item = magic, raw = magic:BuildRaw(), name = magic.name }
							end
							local identity = language .. ':' .. affix
							if not checkedTitles[identity] then
								local snapshot = magicItems[affix]
								local title, fullName = localisation:ItemTitle(snapshot.item)
								if language == 'en' then equal(fullName, snapshot.name, '英文魔法物品完整标题原文保持')
								else chinese(fullName, language .. ' 魔法物品标题 ' .. affix) end
								equal(snapshot.item:BuildRaw(), snapshot.raw, '魔法物品显示不改写保存原文')
								checkedTitles[identity] = true
							end
						elseif source.sourceId == 'ESSENCE' then seenEssences[entry.essence.name] = true
						elseif source.sourceId == 'EMOTION' then seenEmotions[entry.emotion.name] = true end
					end
					-- 选择仍传递原对象，实际预览不得向英文词缀写入中文。
					if entries[1] then
						popup.controls.modSelect:SetSel(1)
						local tooltip = new('Tooltip'):Tooltip()
						popup.controls.save.tooltipFunc(tooltip)
						equal(item:BuildRaw(), raw, language .. ' 制作预览不修改原物品')
					end
				end
			end
		end
		main:ClosePopup()
	end
	local function count(values) local result = 0; for _ in pairs(values) do result = result + 1 end; return result end
	local output = assert(io.open('Tests/Run/crafting-display-residuals.json', 'wb'))
	output:write(require('dkjson').encode(residuals, { indent = true })); output:close()
	equal(count(seenAffixes), 1229, '实际制作弹窗覆盖全部可生成前后缀名称，含亵渎及符文影响')
	equal(count(seenEssences), 80, '实际制作弹窗覆盖全部可用精华')
	equal(count(seenEmotions), 26, '实际制作弹窗覆盖全部可用情感')
	equal(count(residuals), 0, '制作弹窗无英文正文残留，详见独立记录')
	build.itemsTab.displayItem = displayBefore
	build.itemsTab.AddModComparisonTooltip = originalComparison
	localisation:SetLanguage(languageBefore)
end
