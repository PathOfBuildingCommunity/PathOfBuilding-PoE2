describe("Versioned item variants", function()
	local groupedRaw = [[
		Rarity: Unique
		Grouped Test Item
		Gold Ring
		Version: Pre 0.4.0
		Version: Current
		Variant: Life
		Variant: Energy Shield
		Variant: Mana
		Variant: Armour
		Implicits: 0
		{version:1}{variant:1}{group:1,2}{tags:life}+10 to maximum Life
		{version:2}{variant:2}{group:1,2}{tags:defences}+20 to maximum Energy Shield
		{variant:3}{group:1,2}{tags:mana}+30 to maximum Mana
		{variant:4}{group:1,2}{tags:defences}+40 to Armour
	]]
	local ungroupedRaw = [[
		Rarity: Unique
		Ungrouped Variant Test Item
		Gold Ring
		Version: Legacy
		Version: Current
		Selected Variant: 2
		Variant: Life
		Variant: Mana
		Variant: Unreferenced
		Implicits: 0
		{variant:1}{tags:life}+10 to maximum Life
		{variant:2}{tags:mana}+20 to maximum Mana
	]]

	it("defaults to the current version with distinct options from a shared pool", function()
		local item = new("Item"):Item(groupedRaw)
		assert.same({ "Pre 0.4.0", "Current" }, item.versionList)
		assert.equals(2, item.selectedVersion)
		assert.same({ 2, 3 }, item.variantGroupSelections)
		assert.same({ 2, 3, 4 }, item:GetVariantGroupOptions(1, false))
		assert.same({ 2, 4 }, item:GetVariantGroupOptions(1, true))
		assert.equals(0, item.baseModList:Sum("BASE", nil, "Life"))
		assert.equals(20, item.baseModList:Sum("BASE", nil, "EnergyShield"))
		assert.equals(30, item.baseModList:Sum("BASE", nil, "Mana"))
		assert.is_false(item:FindModifierSubstring("life", "Ring 1"))
		assert.is_true(item:FindModifierSubstring("mana", "Ring 1"))
	end)

	it("ignores disabled modifiers in the selected variant groups", function()
		local item = new("Item"):Item(groupedRaw)
		local manaLine
		for _, modLine in ipairs(item.explicitModLines) do
			if modLine.line:find("maximum Mana", 1, true) then
				manaLine = modLine
				break
			end
		end
		assert.is_not_nil(manaLine)
		manaLine.disabled = true
		assert.is_true(item:CheckModLineVariant(manaLine))
		assert.is_false(item:FindModifierSubstring("mana", "Ring 1"))
	end)

	it("keeps an independent variant selection when versions and variants exist", function()
		local item = new("Item"):Item(ungroupedRaw)
		assert.is_true(item:HasIndependentVariants())
		assert.is_false(item:HasVariantGroups())
		assert.equals(2, item.selectedVersion)
		assert.equals(2, item.variant)
		assert.same({ }, item.variantGroupSelections)
		assert.same({ }, item.variantGroups)
		assert.equals(0, item.baseModList:Sum("BASE", nil, "Life"))
		assert.equals(20, item.baseModList:Sum("BASE", nil, "Mana"))
		item:BuildAndParseRaw()
		assert.is_nil(item.raw:find("{group:", 1, true))
		assert.matches("Selected Variant: 2", item.raw, 1, true)
		assert.equals(2, item.variant)
	end)

	it("normalises an invalid independent variant selection", function()
		local item = new("Item"):Item(ungroupedRaw:gsub("Selected Variant: 2", "Selected Variant: 99"))
		assert.equals(3, item.variant)
		assert.matches("Selected Variant: 3", item:BuildRaw(), 1, true)
	end)

	it("keeps ungrouped variants available independently of version", function()
		local item = new("Item"):Item([[
			Rarity: Unique
			Implicit Availability Test
			Gold Ring
			Version: Legacy
			Version: Current
			Variant: Life
			Variant: Mana
			Variant: Always Available
			Implicits: 0
			{version:1}{variant:1}+10 to maximum Life
			{version:2}{variant:2}+20 to maximum Mana
		]])
		assert.equals(3, item.variant)
		item.selectedVersion = 1
		item:NormaliseVariantSelections()
		assert.equals(3, item.variant)
		item.variant = 1
		item:BuildAndParseRaw()
		assert.equals(10, item.baseModList:Sum("BASE", nil, "Life"))
	end)

	it("preserves eligible selections and replaces unavailable selections when changing version", function()
		local item = new("Item"):Item(groupedRaw)
		item.variantGroupSelections = { 3, 2 }
		item.selectedVersion = 1
		item:NormaliseVariantSelections()
		assert.same({ 3, 1 }, item.variantGroupSelections)
		item:BuildAndParseRaw()
		assert.equals(10, item.baseModList:Sum("BASE", nil, "Life"))
		assert.equals(0, item.baseModList:Sum("BASE", nil, "EnergyShield"))
		assert.equals(30, item.baseModList:Sum("BASE", nil, "Mana"))
	end)

	it("round trips selected versions, groups, catalyst tags and ranges", function()
		local item = new("Item"):Item(groupedRaw)
		item.selectedVersion = 1
		item.variantGroupSelections = { 1, 4 }
		item.explicitModLines[1].line = "+(10-20) to maximum Life"
		item.explicitModLines[1].range = 0.25
		item:BuildAndParseRaw()
		assert.matches("Selected Version: 1", item.raw, 1, true)
		assert.matches("Selected Variant Group: 1=1", item.raw, 1, true)
		assert.matches("{version:1}{variant:1}{group:1,2}{tags:life}", item.raw, 1, true)
		local restored = new("Item"):Item(item.raw)
		assert.same({ 1, 4 }, restored.variantGroupSelections)
		assert.same({ "life" }, restored.explicitModLines[1].modTags)
		assert.equals(0.25, restored.explicitModLines[1].range)
		assert.equals(item.baseModList:Sum("BASE", nil, "Life"), restored.baseModList:Sum("BASE", nil, "Life"))
	end)

	it("preserves selection tags on each line of a multiline modifier", function()
		local item = new("Item"):Item([[
			Rarity: Unique
			Multiline Test
			Diamond
			Version: Legacy
			Version: Current
			Variant: Effect
			Implicits: 0
			{version:2}{variant:1}{group:1}100% increased Effect of Jewel Socket Passive Skills
			{version:2}{variant:1}{group:1}containing Corrupted Magic Jewels
		]])
		assert.equals(1, #item.explicitModLines)
		item:BuildAndParseRaw()
		assert.matches("\n{version:2}{variant:1}{group:1}containing Corrupted Magic Jewels", item.raw, 1, true)
		assert.is_nil(item.explicitModLines[1].extra)
	end)

	it("supports groups without versions and sparse group IDs", function()
		local item = new("Item"):Item([[
			Rarity: Unique
			Sparse Test
			Gold Ring
			Variant: Life
			Variant: Mana
			Implicits: 0
			{variant:1}{group:2}+10 to maximum Life
			{variant:2}{group:4}+20 to maximum Mana
		]])
		assert.is_nil(item.selectedVersion)
		assert.same({ [2] = 1, [4] = 2 }, item.variantGroupSelections)
		assert.equals(10, item.baseModList:Sum("BASE", nil, "Life"))
		assert.equals(20, item.baseModList:Sum("BASE", nil, "Mana"))
		item:BuildAndParseRaw()
		assert.same({ [2] = 1, [4] = 2 }, new("Item"):Item(item.raw).variantGroupSelections)
	end)

	it("supports version-only items and clamps invalid saved versions", function()
		local item = new("Item"):Item([[
			Rarity: Unique
			Version Test
			Gold Ring
			Version: Legacy
			Version: Current
			Selected Version: 99
			Implicits: 0
			{version:1}+10 to maximum Life
			{version:2}+20 to maximum Life
		]])
		assert.equals(2, item.selectedVersion)
		assert.equals(20, item.baseModList:Sum("BASE", nil, "Life"))
		item:BuildAndParseRaw()
		assert.equals(20, new("Item"):Item(item.raw).baseModList:Sum("BASE", nil, "Life"))
	end)

	it("applies the selected version's modifier magnitude on the first parse", function()
		local item = new("Item"):Item([[
			Rarity: Unique
			Magnitude Test
			Gold Ring
			Version: Legacy
			Version: Current
			Implicits: 0
			{version:1}{range:0.5}100% increased explicit modifier magnitudes
			{version:2}{range:0.5}200% increased explicit modifier magnitudes
			{tags:life}+(10-10) to maximum Life
		]])
		assert.equals(30, item.baseModList:Sum("BASE", nil, "Life"))
		item.selectedVersion = 1
		item:BuildAndParseRaw()
		assert.equals(20, item.baseModList:Sum("BASE", nil, "Life"))
	end)

	it("selects versioned bases and preserves their tags without variants", function()
		local item = new("Item"):Item([[
			Rarity: Unique
			Base Test
			Version: Legacy
			Version: Current
			Selected Version: 99
			{version:1}Gold Ring
			{version:2}Iron Ring
			Implicits: 0
			+10 to maximum Life
		]])
		assert.equals("Iron Ring", item.baseName)
		item.selectedVersion = 1
		item:BuildAndParseRaw()
		assert.equals("Gold Ring", item.baseName)
		assert.matches("{version:2}Iron Ring", item.raw, 1, true)
		assert.equals("Gold Ring", new("Item"):Item(item.raw).baseName)
	end)

	it("selects grouped bases on the first parse", function()
		local item = new("Item"):Item([[
			Rarity: Unique
			Base Test
			{variant:1}{group:1}Gold Ring
			{variant:2}{group:1}Iron Ring
			Variant: Gold
			Variant: Iron
			Selected Variant Group: 1=99
			Implicits: 0
			+10 to maximum Life
		]])
		assert.equals("Gold Ring", item.baseName)
		assert.equals(10, item.baseModList:Sum("BASE", nil, "Life"))
		item.variantGroupSelections[1] = 2
		item:BuildAndParseRaw()
		assert.equals("Iron Ring", item.baseName)
	end)

	it("selects a base from independent version and variant dimensions", function()
		local item = new("Item"):Item([[
			Rarity: Unique
			Independent Base Test
			{version:1}{variant:1}Gold Ring
			{version:2}{variant:2}Iron Ring
			Version: Legacy
			Version: Current
			Selected Version: 2
			Variant: Gold
			Variant: Iron
			Selected Variant: 2
			Implicits: 0
			+10 to maximum Life
		]])
		assert.equals("Iron Ring", item.baseName)
		item.selectedVersion = 1
		item.variant = 1
		item:BuildAndParseRaw()
		assert.equals("Gold Ring", item.baseName)
	end)

	it("applies grouped rune socket overrides on the first parse", function()
		local item = new("Item"):Item([[
			Rarity: Unique
			Rune Test
			Grand Regalia
			Variant: Weapon
			Variant: Armour
			Implicits: 0
			{variant:1}{group:1}This item gains bonuses from Socketed Items as though it was a Weapon
			{variant:2}{group:1}This item gains bonuses from Socketed Items as though it was Body Armour
		]])
		assert.equals("weapon", item.socketedAugmentTypeOverride)
		item.variantGroupSelections[1] = 2
		item:BuildAndParseRaw()
		assert.equals("body armour", item.socketedAugmentTypeOverride)
	end)

	it("keeps Controlled Metamorphosis radius independent of its version", function()
		local raw
		for _, unique in ipairs(data.uniques.jewel) do
			if unique:match("^Controlled Metamorphosis\n") then
				raw = unique
				break
			end
		end
		assert.is_not_nil(raw)
		assert.is_nil(raw:find("{group:", 1, true))
		local item = new("Item"):Item(raw)
		assert.equals(2, item.selectedVersion)
		assert.equals(4, item.variant)
		assert.same({ }, item.variantGroupSelections)
		assert.equals(0, item.baseModList:Sum("BASE", nil, "ChaosResist"))
		for radius = 1, 8 do
			item.variant = radius
			item.selectedVersion = 2
			item:BuildAndParseRaw()
			local radiusIndex = item.jewelData.radiusIndex
			assert.is_not_nil(radiusIndex)
			item.selectedVersion = 1
			item:BuildAndParseRaw()
			assert.equals(radiusIndex, item.jewelData.radiusIndex)
			assert.equals(radiusIndex, item.jewelRadiusIndex)
			assert.is_true(item.baseModList:Sum("BASE", nil, "ChaosResist") < 0)
			assert.equals(radius, new("Item"):Item(item.raw).variant)
		end
	end)

	describe("item editor", function()
		before_each(newBuild)

		it("shows independent version and variant dropdowns", function()
			build.itemsTab:CreateDisplayItemFromRaw(ungroupedRaw)
			local controls = build.itemsTab.controls
			assert.is_true(controls.displayItemVersion:IsShown())
			assert.is_true(controls.displayItemVariant:IsShown())
			assert.is_nil(controls.displayItemVariant.variantGroupId)
			assert.equals(3, #controls.displayItemVariant.list)
			assert.equals("Mana", controls.displayItemVariant.list[2])
			controls.displayItemVariant:SetSel(1)
			assert.equals(1, build.itemsTab.displayItem.variant)
			assert.equals(10, build.itemsTab.displayItem.baseModList:Sum("BASE", nil, "Life"))
			controls.displayItemVersion:SetSel(1)
			assert.equals(1, build.itemsTab.displayItem.variant)
			assert.equals(10, build.itemsTab.displayItem.baseModList:Sum("BASE", nil, "Life"))
			assert.is_nil(build.itemsTab.displayItem.raw:find("{group:", 1, true))
			local tooltip = new("Tooltip"):Tooltip()
			build.itemsTab:AddItemTooltip(tooltip, build.itemsTab.displayItem, nil, true)
			local text = ""
			for _, line in ipairs(tooltip.lines) do
				text = text .. (line.text or "") .. "\n"
			end
			assert.matches("Version: Legacy", text, 1, true)
			assert.matches("Variant: Life", text, 1, true)
		end)

		it("updates reusable pools when changing version or selection", function()
			build.itemsTab:CreateDisplayItemFromRaw(groupedRaw)
			local controls = build.itemsTab.controls
			local version = controls.displayItemVersion
			local group1 = controls.displayItemVariant
			local group2 = controls.displayItemAltVariant
			assert.is_true(version:IsShown())
			assert.equals(2, version.selIndex)
			assert.equals("Energy Shield", group1.list[1].label)
			assert.equals("Mana", group2.list[1].label)
			group2:SetSel(2)
			group1:SetSel(2)
			assert.same({ 3, 4 }, build.itemsTab.displayItem.variantGroupSelections)
			version:SetSel(1)
			assert.same({ 3, 4 }, build.itemsTab.displayItem.variantGroupSelections)
			assert.equals("Life", group1.list[1].label)
			assert.equals("Life", group2.list[1].label)
			local tooltip = new("Tooltip"):Tooltip()
			build.itemsTab:AddItemTooltip(tooltip, build.itemsTab.displayItem, nil, true)
			local text = ""
			for _, line in ipairs(tooltip.lines) do
				text = text .. (line.text or "") .. "\n"
			end
			assert.matches("Version: Pre 0.4.0", text, 1, true)
			assert.matches("Variants: Mana, Armour", text, 1, true)
		end)

		it("disables exhausted pools and restores legacy controls", function()
			build.itemsTab:CreateDisplayItemFromRaw([[
				Rarity: Unique
				Exhausted Pool
				Gold Ring
				Variant: Life
				Implicits: 0
				{variant:1}{group:1,2}+10 to maximum Life
			]])
			local controls = build.itemsTab.controls
			assert.is_true(controls.displayItemAltVariant:IsShown())
			assert.is_false(controls.displayItemAltVariant:IsEnabled())
			assert.equals("No available variants", controls.displayItemAltVariant.list[1].label)
			assert.equals(10, build.itemsTab.displayItem.baseModList:Sum("BASE", nil, "Life"))
			build.itemsTab:CreateDisplayItemFromRaw([[
				Rarity: Unique
				Legacy Test
				Gold Ring
				Variant: Life
				Variant: Mana
				Implicits: 0
				{variant:1}+10 to maximum Life
				{variant:2}+20 to maximum Mana
			]])
			assert.is_false(controls.displayItemVersion:IsShown())
			assert.is_true(controls.displayItemVariant:IsEnabled())
			assert.is_falsy(controls.displayItemAltVariant:IsShown())
			controls.displayItemVariant:SetSel(1)
			assert.equals(10, build.itemsTab.displayItem.baseModList:Sum("BASE", nil, "Life"))
		end)

		it("hides inactive groups and restores their selections when changing version", function()
			build.itemsTab:CreateDisplayItemFromRaw([[
				Rarity: Unique
				Changing Pools
				Gold Ring
				Version: Legacy
				Version: Current
				Variant: Life
				Variant: Mana
				Variant: Armour
				Implicits: 0
				{version:1}{variant:1}{group:2}+10 to maximum Life
				{version:2}{variant:2}{group:4}+20 to maximum Mana
				{variant:3}{group:7}+30 to Armour
			]])
			local controls = build.itemsTab.controls
			assert.equals(4, controls.displayItemVariant.variantGroupId)
			assert.equals(7, controls.displayItemAltVariant.variantGroupId)
			controls.displayItemVersion:SetSel(1)
			assert.equals(2, controls.displayItemVariant.variantGroupId)
			assert.equals(7, controls.displayItemAltVariant.variantGroupId)
			assert.equals("Life", controls.displayItemVariant.list[1].label)
			controls.displayItemVersion:SetSel(2)
			assert.equals(4, controls.displayItemVariant.variantGroupId)
			assert.equals("Mana", controls.displayItemVariant.list[1].label)
			assert.equals(2, build.itemsTab.displayItem.variantGroupSelections[4])
		end)

		it("saves and loads group selections in build XML", function()
			build.itemsTab:CreateDisplayItemFromRaw(groupedRaw)
			local item = build.itemsTab.displayItem
			item.selectedVersion = 1
			item.variantGroupSelections = { 4, 1 }
			item:BuildAndParseRaw()
			build.itemsTab:AddDisplayItem()
			local xml = { }
			build.itemsTab:Save(xml)
			newBuild()
			build.itemsTab:Load(xml)
			local restored = build.itemsTab.items[build.itemsTab.itemOrderList[1]]
			assert.equals(1, restored.selectedVersion)
			assert.same({ 4, 1 }, restored.variantGroupSelections)
			assert.equals(10, restored.baseModList:Sum("BASE", nil, "Life"))
		end)
	end)
end)
