describe("TetsItemMods", function()
	before_each(function()
		newBuild()
	end)

	teardown(function()
		-- newBuild() takes care of resetting everything in setup()
	end)

	it("shows duplicate selected variants in item tooltips when enabled", function()
		local item = new("Item", [[
			Rarity: Unique
			Mageblood
			Utility Belt
			Has Alt Variant: true
			Selected Variant: 1
			Selected Alt Variant: 1
			Allow Duplicate Variants: true
			Variant: Legacy of Amethyst
			Implicits: 0
			{variant:1}Legacy of Amethyst
		]])
		local tooltip = new("Tooltip")

		build.itemsTab:AddItemTooltip(tooltip, item)

		local legacyLines = 0
		for _, line in ipairs(tooltip.lines) do
			if line.text and line.text:find("Legacy of Amethyst", 1, true) then
				legacyLines = legacyLines + 1
			end
		end
		assert.are.equals(2, legacyLines)
	end)

	it("aggregates matching ring item rarity lines before applying ring bonus effect", function()
		build.configTab.input.customMods = "30% increased bonuses gained from left Equipped Ring"
		build.configTab:BuildModList()
		build.itemsTab:CreateDisplayItemFromRaw([[
			New Item
			Ruby Ring
			Implicits: 0
			16% increased Rarity of Items found
			16% increased Rarity of Items found
			16% increased Rarity of Items found
		]])
		build.itemsTab:AddDisplayItem()
		runCallback("OnFrame")

		assert.are.equals(62, build.calcsTab.mainEnv.modDB:Sum("INC", nil, "LootRarity"))
	end)

	it("aggregates matching ring resistance lines before applying ring bonus effect", function()
		build.configTab.input.customMods = "80% increased bonuses gained from left Equipped Ring"
		build.configTab:BuildModList()
		build.itemsTab:CreateDisplayItemFromRaw([[
			New Item
			Amethyst Ring
			Implicits: 0
			+12% to Chaos Resistance
			+26% to Chaos Resistance
		]])
		build.itemsTab:AddDisplayItem()
		runCallback("OnFrame")

		assert.are.equals(68, build.calcsTab.mainOutput.ChaosResistTotal)
	end)

	it("sorts defensive item stats when the best score is negative", function()
		build.configTab.input.enemyFireDamage = "1000"
		build.configTab:BuildModList()
		runCallback("OnFrame")

		local itemDB = build.itemsTab.controls.uniqueDB
		itemDB.db = { list = {
			new("Item", "New Item\nRing"),
			new("Item", "New Item\nRing\n+50% to Fire Resistance"),
			new("Item", "New Item\nBroadhead Quiver"),
		} }
		itemDB:SetSortMode("FireTakenHit")

		itemDB:ListBuilder()

		assert.is_true(itemDB.list[1].measuredPower < 0)
		assert.are.equals(-math.huge, itemDB.list[#itemDB.list].measuredPower)
	end)

	it("Both slots mod (evasion and es mastery)", function()

		build.configTab.input.customMods = "\z
		20% increased Maximum Energy Shield if both Equipped Rings have an Evasion Modifier\n\z
		"
		build.configTab:BuildModList()
		runCallback("OnFrame")

		build.itemsTab:CreateDisplayItemFromRaw([[
			New Item
			Elementalist Robe
			Energy Shield: 116
		]])
		build.itemsTab:AddDisplayItem()
		runCallback("OnFrame")

		local baseEs = build.calcsTab.mainOutput.EnergyShield

		build.itemsTab:CreateDisplayItemFromRaw([[
			New Item
			Ring
			Implicits: 1
			+71 to Evasion Rating
			+10 to maximum life
		]])
		build.itemsTab:AddDisplayItem()
		runCallback("OnFrame")

		assert.are.equals(baseEs, build.calcsTab.mainOutput.EnergyShield) -- No change in es with just one ring.

		build.itemsTab:CreateDisplayItemFromRaw([[
			New Item
			Ring
			+71 to Evasion Rating
		]])
		build.itemsTab:AddDisplayItem()
		runCallback("OnFrame")

		assert.are_not.equals(baseEs, build.calcsTab.mainOutput.EnergyShield)
		-- Es changes after adding another ring with mod. Regardless of the evasion mod on the first ring being implicit.
	end)

	it("Both slots explicit mod with mixed mod rings (evasion and es mastery)", function()
	
		build.configTab.input.customMods = "\z
		20% increased Maximum Energy Shield if both Equipped Rings have an Explicit Evasion Modifier\n\z
		"
		build.configTab:BuildModList()
		runCallback("OnFrame")

		build.itemsTab:CreateDisplayItemFromRaw([[
			New Item
			Elementalist Robe
			Energy Shield: 116
		]])
		build.itemsTab:AddDisplayItem()
		runCallback("OnFrame")

		local baseEs = build.calcsTab.mainOutput.EnergyShield

		build.itemsTab:CreateDisplayItemFromRaw([[
			New Item
			Ring
			Implicits: 1
			+71 to Evasion Rating
			+10 to maximum life
		]])
		build.itemsTab:AddDisplayItem()
		runCallback("OnFrame")

		assert.are.equals(baseEs, build.calcsTab.mainOutput.EnergyShield) -- No change in es with just one ring.

		build.itemsTab:CreateDisplayItemFromRaw([[
			New Item
			Ring
			+71 to Evasion Rating
		]])
		build.itemsTab:AddDisplayItem()
		runCallback("OnFrame")

		assert.are.equals(baseEs, build.calcsTab.mainOutput.EnergyShield)
		-- Es does not change after adding another ring with mod due to the first ring having an implicit evasion mod.
	end)

	it("Both slots explicit mod (evasion and es mastery)", function()

		build.configTab.input.customMods = "\z
		20% increased Maximum Energy Shield if both Equipped Rings have an Explicit Evasion Modifier\n\z
		"
		build.configTab:BuildModList()
		runCallback("OnFrame")

		build.itemsTab:CreateDisplayItemFromRaw([[
			New Item
			Elementalist Robe
			Energy Shield: 116
		]])
		build.itemsTab:AddDisplayItem()
		runCallback("OnFrame")

		local baseEs = build.calcsTab.mainOutput.EnergyShield

		build.itemsTab:CreateDisplayItemFromRaw([[
			New Item
			Ring
			+71 to Evasion Rating
		]])
		build.itemsTab:AddDisplayItem()
		runCallback("OnFrame")

		assert.are.equals(baseEs, build.calcsTab.mainOutput.EnergyShield) -- No change in es with just one ring.

		build.itemsTab:CreateDisplayItemFromRaw([[
			New Item
			Ring
			+71 to Evasion Rating
		]])
		build.itemsTab:AddDisplayItem()
		runCallback("OnFrame")

		assert.are_not.equals(baseEs, build.calcsTab.mainOutput.EnergyShield)
		-- Es changes after adding two rings with explicit mods.
	end)

	it("Both slots explicit mod no rings (evasion and es mastery)", function()
		build.itemsTab:CreateDisplayItemFromRaw([[
			New Item
			Elementalist Robe
			Energy Shield: 116
		]])
		build.itemsTab:AddDisplayItem()
		runCallback("OnFrame")

		local baseEs = build.calcsTab.mainOutput.EnergyShield

		build.configTab.input.customMods = "\z
		20% increased Maximum Energy Shield if both Equipped Rings have an Explicit Evasion Modifier\n\z
		"
		build.configTab:BuildModList()
		runCallback("OnFrame")

		assert.are.equals(baseEs, build.calcsTab.mainOutput.EnergyShield) -- No change in es with no rings.

	end)

	it("mod if no mod on x slot", function()
		local baseLife = build.calcsTab.mainOutput.Life

		build.configTab.input.customMods = "\z
		15% increased maximum Life if there are no Life Modifiers on Equipped Body Armour\n\z
		"
		build.configTab:BuildModList()
		runCallback("OnFrame")

		assert.are_not.equals(baseLife, build.calcsTab.mainOutput.Life)

		baseLife = build.calcsTab.mainOutput.Life

		build.itemsTab:CreateDisplayItemFromRaw([[
			New Item
			Elementalist Robe
			Energy Shield: 116
			+95 to maximum Life
		]])
		build.itemsTab:AddDisplayItem()
		runCallback("OnFrame")

		assert.are_not.equals(baseLife, build.calcsTab.mainOutput.Life)
	end)

	it("globalLimit mods", function()
		build.configTab.input.customMods = [[
			-1000% to cold resistance
		]]
		build.configTab:BuildModList()
		build.itemsTab:CreateDisplayItemFromRaw([[Replica Nebulis
			Clasped Sceptre
			League: Heist
			Quality: 20
			Sockets: B-B-B
			LevelReq: 68
			Implicits: 1
			40% increased Elemental Damage
			{fractured}{range:1}(15-20)% increased Cast Speed
			{range:1}(15-20)% increased Cold Damage per 1% Missing Cold Resistance, up to a maximum of 300%
			{range:1}(15-20)% increased Fire Damage per 1% Missing Fire Resistance, up to a maximum of 300%]])
		build.itemsTab:AddDisplayItem()
		build.skillsTab:PasteSocketGroup("Slot: Weapon 1\nFireball 20/0 Default  1\n")
		runCallback("OnFrame")

		assert.are_not.equals(340, build.calcsTab.mainEnv.modDB:Sum("INC", "FireDamage"))
		assert.are_not.equals(340, build.calcsTab.mainEnv.modDB:Sum("INC", "ColdDamage"))

		newBuild()

		build.configTab.input.customMods = [[
			Gain 25% increased Armour per 5 Power for 8 seconds when you Warcry, up to a maximum of 100%
			Warcries have infinite Power
			warcries grant arcane surge to you and allies, with 10% increased effect per 5 power, up to 100%
		]]
		build.configTab:BuildModList()
		build.itemsTab:CreateDisplayItemFromRaw([[
			New Item
			Fur Plate
			Armour: 60
		]])
		build.itemsTab:AddDisplayItem()
		build.skillsTab:PasteSocketGroup("Arc 20/0 Default  1")

		assert.are_not.equals(20, build.calcsTab.mainEnv.modDB:Sum("MORE", { flags = ModFlag.Cast }, "Speed"))
		assert.are_not.equals(120, build.calcsTab.mainOutput.Armour)
		runCallback("OnFrame")
	end)

	it("Jarngreipr - strength satisfies melee weapons and skills", function()
		build.configTab.input.customMods = "+1000 Strength"
		build.configTab:BuildModList()
		build.itemsTab:CreateDisplayItemFromRaw([[
			Rarity: UNIQUE
			Chober Chaber
			Leaden Greathammer
			Variant: Pre 0.1.1
			Variant: Current
			Selected Variant: 2
			Quality: 20
			LevelReq: 33
			Implicits: 0
			+100 Intelligence Requirement
			{variant:1}{range:0.5}(80-120)% increased Physical Damage
			{variant:2}{range:0.5}Adds (58-65) to (102-110) Physical Damage
			{range:0.5}+(80-100) to maximum Mana
			{variant:2}+50 to Spirit
			{variant:1}+5% to Critical Hit Chance
			Increases and Reductions to Minion Damage also affect you
		]])
		build.itemsTab:AddDisplayItem()
		runCallback("OnFrame")
		assert.True(build.controls.warnings.lines[1]:match("Intelligence requirement") ~= nil)
		assert.True(build.controls.warnings.lines[1]:match("Chober Chaber") ~= nil)

		build.itemsTab:CreateDisplayItemFromRaw([[
			Rarity: UNIQUE
			Jarngreipr
			Ringmail Gauntlets
			Armour: 23
			Evasion: 18
			Variant: Pre 0.1.1
			Variant: Current
			Selected Variant: 2
			Quality: 20
			LevelReq: 6
			Implicits: 0
			{variant:2}50% increased Armour and Evasion
			{range:0.5}Adds (2-3) to (5-6) Physical Damage to Attacks
			{range:0.5}+(30-50) to maximum Life
			{range:0.5}(4-8)% increased Attack Speed
			Strength can satisfy other Attribute Requirements of Melee Weapons and Melee Skills
		]])
		build.itemsTab:AddDisplayItem()
		runCallback("OnFrame")
		assert.True(build.controls.warnings.lines[1] == nil) -- melee item check int

		newBuild()
		build.configTab.input.customMods = "+1000 Strength"
		build.configTab:BuildModList()
		build.skillsTab:PasteSocketGroup("Primal Strikes 20/0 1")
		runCallback("OnFrame")
		assert.True(build.controls.warnings.lines[1]:match("Dexterity requirement") ~= nil)
		assert.True(build.controls.warnings.lines[1]:match("Primal Strikes") ~= nil)

		build.itemsTab:CreateDisplayItemFromRaw([[
			Rarity: UNIQUE
			Jarngreipr
			Ringmail Gauntlets
			Armour: 23
			Evasion: 18
			Variant: Pre 0.1.1
			Variant: Current
			Selected Variant: 2
			Quality: 20
			LevelReq: 6
			Implicits: 0
			{variant:2}50% increased Armour and Evasion
			{range:0.5}Adds (2-3) to (5-6) Physical Damage to Attacks
			{range:0.5}+(30-50) to maximum Life
			{range:0.5}(4-8)% increased Attack Speed
			Strength can satisfy other Attribute Requirements of Melee Weapons and Melee Skills
		]])
		build.itemsTab:AddDisplayItem()
		runCallback("OnFrame")
		assert.True(build.controls.warnings.lines[1] == nil) -- melee skill check dex

		build.skillsTab:PasteSocketGroup("Fireball 20/0 1")
		runCallback("OnFrame")
		-- make sure something like Fireball still needs the Int requirement and isn't being ignored
		assert.True(build.controls.warnings.lines[1]:match("Intelligence requirement") ~= nil)
		assert.True(build.controls.warnings.lines[1]:match("Fireball") ~= nil)

		build.configTab.input.customMods = [[
			+1000 Strength
			+100 mana
			Attribute Requirements of Gems can be satisified by your highest Attribute
		]] -- fix mana warning
		build.configTab:BuildModList()
		runCallback("OnFrame")
		assert.True(build.controls.warnings.lines[1] == nil) -- validate Gemling's Adaptive Capability still works

		newBuild()
		build.configTab.input.customMods = [[
			+1000 Intelligence
			+100 mana
			Attribute Requirements of Gems can be satisified by your highest Attribute
		]]
		build.configTab:BuildModList()
		build.skillsTab:PasteSocketGroup("Primal Strikes 20/0 1")
		build.itemsTab:CreateDisplayItemFromRaw([[
			Rarity: UNIQUE
			Jarngreipr
			Ringmail Gauntlets
			Armour: 23
			Evasion: 18
			Variant: Pre 0.1.1
			Variant: Current
			Selected Variant: 2
			Quality: 20
			LevelReq: 6
			Implicits: 0
			{variant:2}50% increased Armour and Evasion
			{range:0.5}Adds (2-3) to (5-6) Physical Damage to Attacks
			{range:0.5}+(30-50) to maximum Life
			{range:0.5}(4-8)% increased Attack Speed
			Strength can satisfy other Attribute Requirements of Melee Weapons and Melee Skills
		]])
		build.itemsTab:AddDisplayItem()
		runCallback("OnFrame")
		assert.True(build.controls.warnings.lines[1] == nil) -- Gemling highest attribute still satisfies melee gems with Jarngreipr
	end)

	it("sacrosanctum - add life recoup to es recoup", function()
		build.itemsTab:CreateDisplayItemFromRaw([[
			Rarity: UNIQUE
			Sacrosanctum
			Corvus Mantle
			Armour: 588
			Energy Shield: 202
			League: Dawn of the Hunt
			Variant: Pre 0.4.0
			Variant: Current
			Selected Variant: 2
			Quality: 20
			LevelReq: 68
			Implicits: 1
			{range:0.5}+(20-30) to Spirit
			{range:0.5}(80-120)% increased Armour and Energy Shield
			{range:0.5}+(20-30) to Strength
			{range:0.5}+(20-30) to Intelligence
			{range:0.5}+(17-23)% to Chaos Resistance
			{variant:1}{range:0.5}(5-10)% of Damage taken Recouped as Life
			{variant:2}{range:0.5}(10-20)% of Damage taken Recouped as Life
			Damage taken Recouped as Life is also Recouped as Energy Shield
		]])
		build.itemsTab:AddDisplayItem()
		runCallback("OnFrame")

		assert.True(build.calcsTab.calcsOutput.LifeRecoupRecoveryAvg > 0)
		assert.True(build.calcsTab.calcsOutput.EnergyShieldRecoupRecoveryAvg > 0)
		assert.True(build.calcsTab.calcsOutput.LifeRecoupRecoveryAvg == build.calcsTab.calcsOutput.EnergyShieldRecoupRecoveryAvg)
	end)

	it("solus ipse, max lineage count", function()
		build.configTab.input.customMods = [[
			You can Socket 2 additional copies of each Lineage Support Gem, in different Skills
		]]
		build.configTab:BuildModList()
		runCallback("OnFrame")
		build.skillsTab:PasteSocketGroup("Arc 20/0 1 \nZarokh's Refrain 1/0 1")
		build.skillsTab:PasteSocketGroup("Ice Nova 20/0 1 \nZarokh's Refrain 1/0 1")
		build.skillsTab:PasteSocketGroup("Fireball 20/0 1 \nZarokh's Refrain 1/0 1")
		runCallback("OnFrame")

		assert.are.equals(2, #build.controls.warnings.lines)

		build.skillsTab:PasteSocketGroup("Comet 20/0 1 \nZarokh's Refrain 1/0 1")
		runCallback("OnFrame")

		assert.are.equals(3, #build.controls.warnings.lines)
		assert.True(build.controls.warnings.lines[3]:match("lineage support gems allocated") ~= nil)
	end)

	it("all damage can contribute", function()
		build.itemsTab:CreateDisplayItemFromRaw([[
			Rarity: UNIQUE
			Tidebreaker
			Pointed Maul
			League: Dawn of the Hunt
			Quality: 20
			LevelReq: 45
			Implicits: 0
			{range:0.5}(120-150)% increased Physical Damage
			{range:0.5}+(2-3) to Level of all Melee Skills
			{range:0.5}+(20-30) to Intelligence
			{range:0.5}Causes (150-200)% increased Stun Buildup
			All Damage from Hits with this Weapon Contributes to Chill Magnitude
		]])
		build.itemsTab:AddDisplayItem()
		runCallback("OnFrame")
		build.skillsTab:PasteSocketGroup("Leap Slam 20/0  1")
		runCallback("OnFrame")
		assert.True(build.calcsTab.calcsOutput.ChillEffectMod ~= nil)
	end)

	it("ironbound", function()
		build.itemsTab:CreateDisplayItemFromRaw([[
			Rarity: UNIQUE
			Ironbound Test
			Gemini Bow
			Quality: 20
			Sockets: S S S S
			Rune: None
			Rune: None
			Rune: None
			Rune: None
			LevelReq: 78
			Implicits: 1
			23% chance to chain an additional time
			5% increased Block Chance per 100 Total Item Armour on Equipped Armour Items
			Hits with this Weapon have 1 to 4 Added Physical Damage per 1% Block Chance
		]])
		build.itemsTab:AddDisplayItem()
		runCallback("OnFrame")

		build.itemsTab:CreateDisplayItemFromRaw([[
			Rarity: RARE
			Armour Chest
			Glorious Plate
			Armour: 534
			Crafted: true
			Prefix: None
			Prefix: None
			Prefix: None
			Suffix: None
			Suffix: None
			Suffix: None
			Quality: 0
			LevelReq: 65
			Implicits: 0
		]])
		build.itemsTab:AddDisplayItem()
		runCallback("OnFrame")

		local basePhys = build.calcsTab.mainOutput.PhysicalStoredCombinedAvg

		build.configTab.input.customMods = [[
			10% chance to block
		]]
		build.configTab:BuildModList()
		runCallback("OnFrame")

		-- ~500 armour gives 25% increased block => 12.5%
		assert.equals(12.5, build.calcsTab.mainOutput.EffectiveBlockChance)
		assert.True(basePhys < build.calcsTab.mainOutput.PhysicalStoredCombinedAvg)
	end)
	it("liminal coil", function()
		build.itemsTab:CreateDisplayItemFromRaw([[
			Rarity: UNIQUE
			Liminal Coil Test
			Acrid Wand
			Quality: 20
			Sockets: S S S
			Rune: None
			Rune: None
			Rune: None
			LevelReq: 41
			Implicits: 0
			Magnitudes of Curses you inflict are zero
			Curses you inflict ignore Curse Limit
			Spell Hits Gain 27% of Damage as Extra Chaos Damage per Curse on Target
			Spell Hits Gain 27% of Damage as Extra Physical Damage per Curse on Target
		]])
		build.itemsTab:AddDisplayItem()
		runCallback("OnFrame")
		build.skillsTab:PasteSocketGroup("Fireball 20/0  1")
		runCallback("OnFrame")

		local basePhys = round(build.calcsTab.mainOutput.PhysicalStoredCombinedAvg)
		local baseChaos = round(build.calcsTab.mainOutput.ChaosStoredCombinedAvg)

		build.skillsTab:PasteSocketGroup("Elemental Weakness 20/0  1")
		runCallback("OnFrame")
		local afterEleWeaknessPhys = round(build.calcsTab.mainOutput.PhysicalStoredCombinedAvg)
		local afterEleWeaknessChaos = round(build.calcsTab.mainOutput.ChaosStoredCombinedAvg)
		-- curses increase damage
		assert.are_not.equals(basePhys, afterEleWeaknessPhys)
		assert.are_not.equals(basePhys, afterEleWeaknessChaos)

		build.skillsTab:PasteSocketGroup("Enfeeble 20/0  1")
		runCallback("OnFrame")
		local afterEnfeeblePhys = round(build.calcsTab.mainOutput.PhysicalStoredCombinedAvg)
		local afterEnfeebleChaos = round(build.calcsTab.mainOutput.ChaosStoredCombinedAvg)
		-- more curse more dmg
		assert.are_not.equals(afterEleWeaknessPhys, afterEnfeeblePhys)
		assert.are_not.equals(afterEleWeaknessChaos, afterEnfeebleChaos)
	end)

	it("twisted empyrean", function()
		build.itemsTab:CreateDisplayItemFromRaw([[
			Rarity: UNIQUE
			Twisted Empyrean Test
			Greatmace
			Quality: 0
			Sockets: S S S S
			Rune: None
			Rune: None
			Rune: None
			Rune: None
			LevelReq: 52
			Implicits: 0
			Attacks with this Weapon have Added Cold Damage equal to 6% to 10% of Maximum Mana
			Convert 100% of Fire Damage of Mace Skills to Cold Damage
		]])
		build.itemsTab:AddDisplayItem()
		runCallback("OnFrame")

		build.skillsTab:PasteSocketGroup("Leap Slam 20/0  1")
		runCallback("OnFrame")

		local baseColdAvg = round(build.calcsTab.mainOutput.ColdStoredCombinedAvg)

		build.configTab.input.customMods = [[
		+904 maximum mana
		]]
		build.configTab:BuildModList()
		runCallback("OnFrame")
		-- more mana increases average cold hit
		assert.are_not.equals(baseColdAvg, round(build.calcsTab.mainOutput.ColdStoredCombinedAvg))

		build.configTab.input.customMods = [[
		100 to 200 added fire damage
		]]
		build.configTab:BuildModList()
		runCallback("OnFrame")
		-- added fire damage increases cold damage
		assert.are_not.equals(baseColdAvg, round(build.calcsTab.mainOutput.ColdStoredCombinedAvg))
		assert.equals(0, round(build.calcsTab.mainOutput.FireStoredCombinedAvg))
	end)

	it("Timeless jewels grant conquered attribute passive bonuses", function()
		local calcs = build.calcsTab.calcs
		local jewelSocketNodeId = 999
		local attributeNode = {
			id = 1,
			type = "Normal",
			isAttribute = true,
			allocMode = 0,
			modList = new("ModList"),
		}
		local smallNode = {
			id = 2,
			type = "Normal",
			allocMode = 0,
			modList = new("ModList"),
		}
		local envMode = "SPEC_TIMELESS_ATTRIBUTE"
		GlobalCache.cachedData[envMode] = { }
		local env = {
			mode = envMode,
			radiusJewelList = { },
			allocNodes = { },
			build = {
				itemsTab = {
					activeItemSet = {
						useSecondWeaponSet = false,
					},
				},
				spec = {
					nodes = {
						[jewelSocketNodeId] = {
							allocMode = 0,
						},
					},
				},
			},
		}
		table.insert(env.radiusJewelList, {
			type = "Other",
			nodes = {
				[attributeNode.id] = { type = "Normal" },
				[smallNode.id] = { type = "Normal" },
			},
			item = {
				baseName = "Timeless Jewel",
			},
			nodeId = jewelSocketNodeId,
			jewelHash = "undying-hate-spec",
			data = {
				modSource = "Tree:" .. jewelSocketNodeId,
			},
			func = function(node, out, data)
				if node and node.type == "Normal" and node.isAttribute then
					out:NewMod("Str", "BASE", 7, data.modSource)
				elseif node and node.type == "Normal" and not node.isAttribute then
					out:NewMod("Dex", "BASE", 11, data.modSource)
				end
			end,
		})

		local attributeModList = calcs.buildModListForNode(env, attributeNode, 0, false)
		local smallModList = calcs.buildModListForNode(env, smallNode, 0, false)
		GlobalCache.cachedData[envMode] = nil

		assert.are.equals(7, attributeModList:Sum("BASE", nil, "Str"))
		assert.are.equals(0, attributeModList:Sum("BASE", nil, "Dex"))
		assert.are.equals(0, smallModList:Sum("BASE", nil, "Str"))
		assert.are.equals(11, smallModList:Sum("BASE", nil, "Dex"))
	end)

	it("Blistering Bond with Avatar of Fire", function()
		build.itemsTab:CreateDisplayItemFromRaw([[
			Rarity: UNIQUE
			The Blood Thorn
			Wrapped Quarterstaff
			{variant:1}{range:0.5}Adds (3-5) to (9-11) Physical Damage
			{variant:2}{range:0.5}Adds (8-12) to (16-18) Physical Damage
			{range:0.5}+(10-15) to Strength
			Causes Bleeding on Hit
		]])
		build.itemsTab:AddDisplayItem()
		runCallback("OnFrame")

		build.configTab.input.customMods = [[
		75% of Damage Converted to Fire Damage
		Deal no Non-Fire Damage
		]]
		build.configTab:BuildModList()
		runCallback("OnFrame")

		build.skillsTab:PasteSocketGroup("Quarterstaff Strike 20/0  1")
		runCallback("OnFrame")

		local baseBleedPlusAvatarWithoutBlistering = build.calcsTab.mainOutput.BleedDPS
		assert.True(baseBleedPlusAvatarWithoutBlistering == nil) -- fire cannot bleed, deal no physical = no bleed

		build.itemsTab:CreateDisplayItemFromRaw([[
		Rarity: UNIQUE
		0.5 Blistering Bond Test
		Ruby Ring
		LevelReq: 8
		Implicits: 1
		{tags:fire}{range:0.5}+(20-30)% to Fire Resistance
		{tags:life}{range:0.5}+(40-60) to maximum Life
		{tags:fire}{range:0.5}+(20-30)% to Fire Resistance
		{tags:cold}{range:0.5}-(15-10)% to Cold Resistance
		You take Fire Damage instead of Physical Damage from Bleeding
		Fire Damage also Contributes to Bleeding Magnitude
		Bleeding you Inflict deals Fire damage instead of Physical damage
		]])
		build.itemsTab:AddDisplayItem()
		runCallback("OnFrame")
		local baseBleed = build.calcsTab.mainOutput.BleedDPS

		build.configTab.input.customMods = [[
		Adds 100 to 200 fire damage
		]]
		build.configTab:BuildModList()
		runCallback("OnFrame")
		local baseBleedPlusFire = build.calcsTab.mainOutput.BleedDPS
		assert.True(baseBleedPlusFire > baseBleed) -- fire can bleed, +fire = +bleed

		build.configTab.input.customMods = [[
		75% of Damage Converted to Fire Damage
		Deal no Non-Fire Damage
		]]
		build.configTab:BuildModList()
		runCallback("OnFrame")
		local baseBleedPlusAvatar = build.calcsTab.mainOutput.BleedDPS
		assert.True(baseBleedPlusAvatar > 0) -- fire can bleed, deal no physical = can bleed
	end)

	it("ancestral bond", function()
		build.itemsTab:CreateDisplayItemFromRaw([[
		Rarity: UNIQUE
		Hoghunt
		Felled Greatclub
		Variant: Pre 0.1.1
		Variant: Current
		Selected Variant: 2
		Quality: 20
		LevelReq: 0
		Implicits: 0
		{variant:1}{range:0.5}(100-150)% increased Physical Damage
		{variant:2}{range:0.5}Adds (16-20) to (23-27) Physical Damage
		+15% to Critical Hit Chance
		10% reduced Attack Speed
		+10 to Strength
		Maim on Critical Hit
		]])
		build.itemsTab:AddDisplayItem()
		runCallback("OnFrame")

		build.skillsTab:PasteSocketGroup("Ancestral Warrior Totem 20/0 2")
		runCallback("OnFrame")

		build.configTab.input.customMods = [[
		Totems reserve 75 spirit each
		+100 spirit
		]]
		build.configTab:BuildModList()
		runCallback("OnFrame")
		assert.are.equals(150, build.calcsTab.mainOutput.SpiritReserved)

		build.configTab.input.customMods = [[
		Totems reserve 75 spirit each
		100% increased spirit reservation efficiency
		]]
		build.configTab:BuildModList()
		runCallback("OnFrame")
		assert.are.equals(76, build.calcsTab.mainOutput.SpiritReserved)
	end)
end)
