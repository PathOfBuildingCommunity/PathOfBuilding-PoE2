describe("Build display stats", function()
	local originalCompactValues

	before_each(function()
		originalCompactValues = main.useCompactValues
		newBuild()
	end)

	after_each(function()
		main.useCompactValues = originalCompactValues
	end)

	local function getSidebarLine(label)
		local suffix = label .. ":"
		for _, stat in ipairs(build.controls.statBox.list) do
			if stat[1] and stat[1]:sub(-#suffix) == suffix then
				return stat
			end
		end
	end

	it("only underlines sidebar stats with a visible breakdown", function()
		build.skillsTab:PasteSocketGroup("Fireball 20/0  1")
		runCallback("OnFrame")

		for _, line in ipairs(build.controls.statBox.list) do
			if line.underline and line.underline[2] then
				build:SetDisplayStat({ line = line, x = 0, y = 0, width = 300 }, false)
				assert.is_true(build.controls.breakdown.shown, line[1])
				build:ClearDisplayStat()
			end
		end
	end)

	it("uses aggregate breakdowns for dual-wield attacks", function()
		build.skillsTab:PasteSocketGroup("skillId:MeleeMaceMacePlayer Mace Strike 20/0  1")
		build.itemsTab:CreateDisplayItemFromRaw("New Item\nMarauding Mace\nQuality: 0\n20% increased Attack Speed")
		build.itemsTab:AddDisplayItem()
		build.itemsTab:CreateDisplayItemFromRaw("New Item\nMarauding Mace\nQuality: 0")
		build.itemsTab:AddDisplayItem()
		runCallback("OnFrame")

		local actor = build.calcsTab.mainEnv.player
		assert.is_true(actor.mainSkill.activeEffect.statSet.skillFlags.bothWeaponAttack)
		assert.matches("Simultaneous hits from each weapon", table.concat(actor.breakdown.Speed, "\n"), nil, true)
		assert.matches("Both weapons", table.concat(actor.breakdown.PreEffectiveCritChance, "\n"), nil, true)
		assert.matches("Both weapons", table.concat(actor.breakdown.CritChance, "\n"), nil, true)
		assert.not_matches("Crit confirmation roll", table.concat(actor.breakdown.PreEffectiveCritChance, "\n"), nil, true)
		assert.matches("Crit confirmation roll", table.concat(actor.breakdown.CritChance, "\n"), nil, true)
		assert.matches("Both weapons", table.concat(actor.breakdown.HitChance, "\n"), nil, true)

		local critLine = getSidebarLine("Crit Chance")
		local effectiveCritLine = getSidebarLine("Effective Crit Chance")
		assert.are.equal("PreEffectiveCritChance", critLine.breakdown)
		assert.are.equal("CritChance", effectiveCritLine.breakdown)

		local displayData = build:GetSidebarBreakdown(critLine.breakdown, critLine.modNames, critLine.ignoredSections, "player")
		local breakdownCount = 0
		local hasMainHandModifiers = false
		for _, section in ipairs(displayData) do
			breakdownCount = breakdownCount + (section.breakdown and 1 or 0)
			hasMainHandModifiers = hasMainHandModifiers or section.cfg == "weapon1"
		end
		assert.are.equal(1, breakdownCount)
		assert.is_true(hasMainHandModifiers)
	end)

	it("uses off-hand breakdowns for shield attacks", function()
		build.itemsTab:CreateDisplayItemFromRaw("New Item\nShortsword\nQuality: 0")
		build.itemsTab:AddDisplayItem()
		build.itemsTab:CreateDisplayItemFromRaw("New Item\nSplintered Tower Shield\nQuality: 0")
		build.itemsTab:AddDisplayItem()
		build.skillsTab:PasteSocketGroup("Shield Wall 20/0  1")
		build.configTab.input.enemyEvasion = 10000
		build.configTab:BuildModList()
		runCallback("OnFrame")

		local actor = build.calcsTab.mainEnv.player
		assert.is_falsy(actor.mainSkill.activeEffect.statSet.skillFlags.weapon1Attack)
		assert.is_true(actor.mainSkill.activeEffect.statSet.skillFlags.weapon2Attack)
		assert.are.equal(actor.breakdown.OffHand.Speed, actor.breakdown.Speed)
		assert.are.equal(actor.breakdown.OffHand.AccuracyHitChance, actor.breakdown.HitChance)
		assert.are.equal(actor.breakdown.OffHand.PreEffectiveCritChance, actor.breakdown.PreEffectiveCritChance)
		assert.are.equal(actor.breakdown.OffHand.CritChance, actor.breakdown.CritChance)

		local critLine = getSidebarLine("Crit Chance")
		local effectiveCritLine = getSidebarLine("Effective Crit Chance")
		assert.are.equal("PreEffectiveCritChance", critLine.breakdown)
		assert.are.equal("OffHand.CritChance", actor.breakdown.PreEffectiveCritChance.breakdownSource)
		assert.are.equal("CritChance", effectiveCritLine.breakdown)

		local displayData = build:GetSidebarBreakdown(critLine.breakdown, critLine.modNames, critLine.ignoredSections, "player")
		local hasModifierSection = false
		for _, section in ipairs(displayData) do
			hasModifierSection = hasModifierSection or section.modName ~= nil
		end
		assert.is_true(hasModifierSection)

		build.configTab.input.enemyBlockChance = 25
		build.configTab:BuildModList()
		runCallback("OnFrame")
		actor = build.calcsTab.mainEnv.player
		assert.are.equal(actor.breakdown.OffHand.HitChance, actor.breakdown.HitChance)
	end)
end)
