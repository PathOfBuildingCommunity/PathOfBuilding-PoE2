describe("TestItemParse", function()
	local function raw(s, base)
		base = base or "Arcane Raiment"
		return "Rarity: Rare\nName\n"..base.."\n"..s
	end

	it("Rarity", function()
		local item = new("Item"):Item("Rarity: Normal\nRing")
		assert.are.equals("NORMAL", item.rarity)
		item = new("Item"):Item("Rarity: Magic\nRing")
		assert.are.equals("MAGIC", item.rarity)
		item = new("Item"):Item("Rarity: Rare\nName\nRing")
		assert.are.equals("RARE", item.rarity)
		item = new("Item"):Item("Rarity: Unique\nName\nRing")
		assert.are.equals("UNIQUE", item.rarity)
	end)

	it("ignores display-only Spear Throw grants without affecting levelled item skills", function()
		for _, line in ipairs({ "Grants Skill: Spear Throw", "grants skill: spear throw" }) do
			local mods, extra = modLib.parseMod(line)
			assert.are.same({ }, mods)
			assert.is_nil(extra)
		end
		local item = new("Item"):Item(raw("Grants Skill: Spear Throw\nGrants Skill: Level 5 Fireball", "Hardwood Spear"))
		assert.are.equals(1, #item.grantedSkills)
		assert.are.equals("FireballPlayer", item.grantedSkills[1].skillId)
		assert.are.equals(5, item.grantedSkills[1].level)
	end)

	--it("Defence", function()
	--	local item = new("Item"):Item(raw("Armour: 25"))
	--	assert.are.equals(25, item.armourData.Armour)
	--	item = new("Item"):Item(raw("Evasion Rating: 35", "Shabby Jerkin"))
	--	assert.are.equals(35, item.armourData.Evasion)
	--	item = new("Item"):Item(raw("Energy Shield: 15", "Simple Robe"))
	--	assert.are.equals(15, item.armourData.EnergyShield)
	--	item = new("Item"):Item(raw("Ward: 180", "Runic Crown"))
	--	assert.are.equals(180, item.armourData.Ward)
	--end)

	it("Ward defence", function()
		local item = new("Item"):Item(raw("Ward: 180", "Runic Crown"))
		assert.are.equals(180, item.armourData.Ward)
		item = new("Item"):Item(raw("Runic Ward: 180", "Runic Crown"))
		assert.are.equals(180, item.armourData.Ward)
	end)

	it("Title", function()
		local item = new("Item"):Item([[
			Rarity: Rare
			Phoenix Paw
			Furtive Wraps
		]])
		assert.are.equal("Phoenix Paw", item.title)
		assert.are.equal("Furtive Wraps", item.baseName)
		assert.are.equal("Phoenix Paw, Furtive Wraps", item.name)
	end)

	it("Unique ID", function()
		local item = new("Item"):Item(raw("Unique ID: 40f9711d5bd7ad2bcbddaf71c705607aef0eecd3dcadaafec6c0192f79b82863"))
		assert.are.equals("40f9711d5bd7ad2bcbddaf71c705607aef0eecd3dcadaafec6c0192f79b82863", item.uniqueID)
	end)

	it("Unique ID line is not parsed as a modifier", function()
		local item = new("Item"):Item([[
			Rarity: Unique
			Evergrasping Ring
			Pearl Ring
			Unique ID: 5d96bc922c2ae073676c4149a2ecf0ebd0951f213ef894895bd2afe206845539
			Item Level: 66
			LevelReq: 32
			Implicits: 1
			7% increased Cast Speed
			+91 to maximum Mana
			Allies in your Presence Gain 22% of Damage as Extra Chaos Damage
			Enemies in your Presence Gain 8% of Damage as Extra Chaos Damage
		]])

		assert.are.equals("5d96bc922c2ae073676c4149a2ecf0ebd0951f213ef894895bd2afe206845539", item.uniqueID)
		assert.are.equals(3, #item.explicitModLines)
	end)

	it("Item Level", function()
		local item = new("Item"):Item(raw("Item Level: 10"))
		assert.are.equals(10, item.itemLevel)
	end)

	it("Quality", function()
		local item = new("Item"):Item(raw("Quality: 10"))
		assert.are.equals(10, item.quality)
		item = new("Item"):Item(raw("Quality: +12% (augmented)"))
		assert.are.equals(12, item.quality)
	end)

	it("parses '<element> spell' as a composable Spell + element tag (issue #2226)", function()
		local item = new("Item"):Item([[
			Rarity: Rare
			Xoph's Test Band
			Amethyst Ring
			Implicits: 0
			+5% to Fire Spell Critical Hit Chance
			+30% to Fire Spell Critical Damage Bonus
			+7% to Cold Spell Critical Hit Chance
		]])
		-- the "fire spell" tag composes with any crit stat (chance and damage bonus)
		assert.are.equals(5, item.baseModList:Sum("BASE", { flags = ModFlag.Spell, keywordFlags = KeywordFlag.Fire }, "CritChance"))
		assert.are.equals(30, item.baseModList:Sum("BASE", { flags = ModFlag.Spell, keywordFlags = KeywordFlag.Fire }, "CritMultiplier"))
		-- ...and works per element
		assert.are.equals(7, item.baseModList:Sum("BASE", { flags = ModFlag.Spell, keywordFlags = KeywordFlag.Cold }, "CritChance"))
		-- still correctly scoped: not attacks, and not the wrong element
		assert.are.equals(0, item.baseModList:Sum("BASE", { flags = ModFlag.Attack, keywordFlags = KeywordFlag.Fire }, "CritChance"))
		assert.are.equals(0, item.baseModList:Sum("BASE", { flags = ModFlag.Spell, keywordFlags = KeywordFlag.Cold }, "CritMultiplier"))
	end)

	--TODO: impl sockets for POB2
	--it("Sockets", function()
	--end)

	--TODO: impl jewels for POB2
	--it("Jewel", function()
	--end)

	--TODO: Variants for POB2?
	--it("Variant name", function()
	--end)

	it("allows duplicate selected variants when enabled", function()
		local item = new("Item"):Item([[
			Rarity: Unique
			Mageblood
			Utility Belt
			Has Alt Variant: true
			Has Alt Variant Two: true
			Has Alt Variant Three: true
			Selected Variant: 1
			Selected Alt Variant: 1
			Selected Alt Variant Two: 2
			Selected Alt Variant Three: 2
			Allow Duplicate Variants: true
			Variant: Legacy of Amethyst
			Variant: Legacy of Basalt
			Implicits: 0
			{variant:1}Legacy of Amethyst
			{variant:2}Legacy of Basalt
		]])

		assert.are.equals(2, item.baseModList:Sum("BASE", nil, "LegacyOfAmethyst"))
		assert.are.equals(2, item.baseModList:Sum("BASE", nil, "LegacyOfBasalt"))
	end)

	it("does not duplicate selected variants by default", function()
		local item = new("Item"):Item([[
			Rarity: Unique
			Mageblood
			Utility Belt
			Has Alt Variant: true
			Selected Variant: 1
			Selected Alt Variant: 1
			Variant: Legacy of Amethyst
			Implicits: 0
			{variant:1}Legacy of Amethyst
		]])

		assert.are.equals(1, item.baseModList:Sum("BASE", nil, "LegacyOfAmethyst"))
	end)
	
	--TODO: Alt variants for POB2
	--it("Alt Variant", function()
	--end)

	it("Requires Level", function()
		local item = new("Item"):Item(raw("Requires Level 10"))
		assert.are.equals(10, item.requirements.level)
		item = new("Item"):Item(raw("Level: 10"))
		assert.are.equals(10, item.requirements.level)
		item = new("Item"):Item(raw("LevelReq: 10"))
		assert.are.equals(10, item.requirements.level)
	end)

	it("Prefix/Suffix", function()
		local item = new("Item"):Item(raw([[
			Prefix: {range:0.1}IncreasedLife1
			Suffix: {range:0.2}ColdResist1
			]]))
		assert.are.equals("IncreasedLife1", item.prefixes[1].modId)
		assert.are.equals(0.1, item.prefixes[1].range)
		assert.are.equals("ColdResist1", item.suffixes[1].modId)
		assert.are.equals(0.2, item.suffixes[1].range)
	end)

	it("Implicits", function()
		local item = new("Item"):Item(raw([[
			Implicits: 2
			+8 to Strength
			+10 to Intelligence
			+12 to Dexterity
			]]))
		assert.are.equals(2, #item.implicitModLines)
		assert.are.equals("+8 to Strength", item.implicitModLines[1].line)
		assert.are.equals("+10 to Intelligence", item.implicitModLines[2].line)
		assert.are.equals(1, #item.explicitModLines)
		assert.are.equals("+12 to Dexterity", item.explicitModLines[1].line)
	end)

	it("Pasted separated base granted skills stay implicit", function()
		local item = new("Item"):Item([[
			Item Class: Spears
			Rarity: Rare
			Brood Edge
			Jagged Spear
			--------
			Physical Damage: 33-61
			Elemental Damage: 39-62 (fire), 9-14 (cold)
			Critical Hit Chance: 8.70% (augmented)
			Attacks per Second: 1.74 (augmented)
			--------
			Requires: Level 59, 33 Str, 81 (unmet) Dex
			--------
			Item Level: 76
			--------
			Bleeding you inflict deals Damage 11% faster (implicit)
			--------
			Grants Skill: Spear Throw
			--------
			Adds 39 to 62 Fire Damage
			Adds 9 to 14 Cold Damage
			+2.7% to Critical Hit Chance
			16% increased Attack Speed
			+22 to Dexterity
		]])

		assert.are.equals(2, #item.implicitModLines)
		assert.are.equals("Bleeding you inflict deals Damage 11% faster", item.implicitModLines[1].line)
		assert.are.equals("Grants Skill: Spear Throw", item.implicitModLines[2].line)
		assert.are.equals(0, #item.grantedSkills)
		assert.are.equals("Adds 39 to 62 Fire Damage", item.explicitModLines[1].line)

		assert.are.equals("Grants Skill: Level (1-20) Volatile Dead", data.itemBases["Volatile Wand"].implicit)

		item = new("Item"):Item([[
			Item Class: Wands
			Rarity: Rare
			Temp Wand
			Volatile Wand
			--------
			Physical Damage: 10-18
			Critical Hit Chance: 7.00%
			Attacks per Second: 1.45
			--------
			Requires: Level 45, 104 Int
			--------
			Item Level: 60
			--------
			Grants Skill: Level 11 Volatile Dead
			--------
			10% increased Spell Damage
		]])

		assert.are.equals(1, #item.implicitModLines)
		assert.are.equals("Grants Skill: Level 11 Volatile Dead", item.implicitModLines[1].line)
		assert.are.equals(1, #item.grantedSkills)
		assert.are.equals("VolatileDeadPlayer", item.grantedSkills[1].skillId)
		assert.are.equals("10% increased Spell Damage", item.explicitModLines[1].line)
	end)

	it("Crafted base granted skill ranges stay implicit", function()
		local base = data.itemBases["Volatile Wand"]
		local item = new("Item"):Item()
		item.name = "Volatile Wand"
		item.base = base
		item.baseName = "Volatile Wand"
		item.rarity = "RARE"
		item.title = "New Item"
		item.crafted = true
		item.prefixes = { }
		item.suffixes = { }
		item.buffModLines = { }
		item.enchantModLines = { }
		item.runeModLines = { }
		item.classRequirementModLines = { }
		item.implicitModLines = {
			{ line = base.implicit }
		}
		item.explicitModLines = { }
		item.sockets = { }
		item.runes = { }

		item:NormaliseQuality()
		item:BuildAndParseRaw()

		assert.are.equals(1, #item.implicitModLines)
		assert.are.equals("Grants Skill: Level (1-20) Volatile Dead", item.implicitModLines[1].line)
		assert.are.equals(1, #item.grantedSkills)
		assert.are.equals("VolatileDeadPlayer", item.grantedSkills[1].skillId)
	end)

	it("Crafted affixes matching base implicit ranges stay explicit", function()
		local item = new("Item"):Item([[
			Rarity: Rare
			New Item
			Solar Amulet
			Crafted: true
			Prefix: {range:0}IncreasedSpirit4
			Prefix: None
			Prefix: None
			Suffix: None
			Suffix: None
			Suffix: None
			Implicits: 1
			+(10-15) to Spirit
		]])

		item:Craft()
		assert.are.equals(1, #item.implicitModLines)
		assert.are.equals("+(10-15) to Spirit", item.implicitModLines[1].line)
		assert.are.equals(1, #item.explicitModLines)
		assert.are.equals("+43 to Spirit", item.explicitModLines[1].line)

		item.prefixes[1].range = 0.2
		item:Craft()
		assert.are.equals(1, #item.implicitModLines)
		assert.are.equals(1, #item.explicitModLines)
		assert.are.equals("+44 to Spirit", item.explicitModLines[1].line)
	end)

	it("Crafted affixes matching base implicits stay explicit", function()
		local item = new("Item"):Item([[
			Rarity: Rare
			New Item
			Gemini Crossbow
			Crafted: true
			Prefix: None
			Prefix: None
			Prefix: None
			Suffix: {range:0}AdditionalAmmo1
			Suffix: None
			Suffix: None
			Implicits: 1
			Loads an additional bolt
		]])

		item:Craft()
		assert.are.equals(1, #item.implicitModLines)
		assert.are.equals("Loads an additional bolt", item.implicitModLines[1].line)
		assert.are.equals(1, #item.explicitModLines)
		assert.are.equals("Loads an additional bolt", item.explicitModLines[1].line)

		item.suffixes[1].range = 0.2
		item:Craft()
		assert.are.equals(1, #item.implicitModLines)
		assert.are.equals(1, #item.explicitModLines)
		assert.are.equals("Loads an additional bolt", item.explicitModLines[1].line)
	end)

	it("Pasted affixes matching base implicits stay explicit", function()
		local item = new("Item"):Item([[
			Item Class: Crossbows
			Rarity: Rare
			New Item
			Gemini Crossbow
			--------
			Physical Damage: 28-112
			Critical Hit Chance: 5.00%
			Attacks per Second: 1.60
			Reload Time: 1.10
			--------
			Requires: Level 78, 89 Str, 89 Dex
			--------
			Item Level: 82
			--------
			Loads an additional bolt (implicit)
			--------
			Loads an additional bolt
		]])

		assert.are.equals(1, #item.implicitModLines)
		assert.are.equals("Loads an additional bolt", item.implicitModLines[1].line)
		assert.are.equals(1, #item.explicitModLines)
		assert.are.equals("Loads an additional bolt", item.explicitModLines[1].line)
	end)

	--TODO: POB2 Leagues?
	--it("League", function()
	--end)

	it("Source", function()
		local item = new("Item"):Item(raw("Source: No longer obtainable"))
		assert.are.equals("No longer obtainable", item.source)
	end)

	it("Note", function()
		local item = new("Item"):Item(raw("Note: ~price 1 chaos"))
		assert.are.equals("~price 1 chaos", item.note)
	end)

	it("ignores disabled modifiers in item conditions", function()
		local item = new("Item"):Item(raw("{disabled}+100 to maximum Life"))
		assert.is_false(item:FindModifierSubstring("life", "body armour"))
	end)

	it("Rune level requirements", function()
		local item = new("Item"):Item([[
			Test Wand
			Runic Fork
			Sockets: S
			Rune: Perfect Storm Rune
			LevelReq: 1
			Implicits: 1
			{enchant}{rune}Gain 12% of Damage as Extra Lightning Damage
		]])
		assert.are.equals(50, item.requirements.level)
	end)

	it("Unique mod level requirements", function()
		local foundAnvil
		for _, rawUnique in ipairs(data.uniques.amulet) do
			if rawUnique:match("The Anvil") then
				local item = new("Item"):Item(rawUnique)
				assert.are.equals(18, item.requirements.level)
				assert.is_nil(rawUnique:match("Requires Level 18"))
				foundAnvil = true
				break
			end
		end
		assert(foundAnvil, "The Anvil not found")

		local foundChoirOfTheStorm
		for _, rawUnique in ipairs(data.uniques.amulet) do
			if rawUnique:match("Choir of the Storm") then
				assert(rawUnique:find("Grants Skill: Level (1-20) Lightning Bolt", 1, true))
				assert(rawUnique:find("Trigger Lightning Bolt Skill on Critical Hit", 1, true))
				foundChoirOfTheStorm = true
				break
			end
		end
		assert(foundChoirOfTheStorm, "Choir of the Storm not found")

		local foundSylvansEffigy
		for _, rawUnique in ipairs(data.uniques.sceptre) do
			if rawUnique:match("Sylvan's Effigy") then
				local item = new("Item"):Item(rawUnique)
				assert.are.equals(62, item.requirements.level)
				foundSylvansEffigy = true
				break
			end
		end
		assert(foundSylvansEffigy, "Sylvan's Effigy not found")

		for _, rawUnique in ipairs(data.uniques.amulet) do
			if rawUnique:match("Hinekora's Sight") then
				local item = new("Item"):Item(rawUnique)
				assert.are.equals(44, item.requirements.level)
				assert(rawUnique:find("Grants Skill: Level (1-20) Future-Past", 1, true))
				return
			end
		end
		assert(false, "Hinekora's Sight not found")
	end)

	it("keeps legacy base implicit variants as implicits", function()
		for _, rawUnique in ipairs(data.uniques.belt) do
			if rawUnique:match("Goregirdle") then
				assert(rawUnique:find("Implicits: 3\n{variant:2}+(140-180) to Armour\n{variant:1}+(100-140) to Armour\nHas (1-3) Charm Slot", 1, true))
				return
			end
		end
		assert(false, "Goregirdle not found")
	end)

	it("uses upgraded base requirements for uniques", function()
		local item = new("Item"):Item([[
			Item Class: Spears
			Rarity: Unique
			Tyranny's Grip
			Runemastered Ironhead Spear
			Requires: Level 55, 31 Str, 76 Dex
			Item Level: 30
		]])
		assert.are.equals(55, item.requirements.level)

		item.itemSocketCount = 1
		item.runes = { "Legacy of Tyranny's Grip" }
		item:UpdateRunes()
		item:BuildAndParseRaw()
		assert.are.equals(65, item.requirements.level)

		item.runes[1] = "None"
		item:UpdateRunes()
		item:BuildAndParseRaw()
		assert.are.equals(55, item.requirements.level)
	end)

	it("inherits implicits from variant base types", function()
		for _, rawUnique in ipairs(data.uniques.shield) do
			if rawUnique:match("The Surrender") then
				assert(rawUnique:find("Implicits: 1\nGrants Skill: Raise Shield", 1, true))
				local item = new("Item"):Item(rawUnique)
				assert.are.equals(75, item.requirements.level)
				return
			end
		end
		assert(false, "The Surrender not found")
	end)

	it("Requires Class", function()
		local item = new("Item"):Item(raw("Requires Class Witch"))
		assert.are.equals("Witch", item.classRestriction)
		item = new("Item"):Item(raw("Class:: Witch"))
		assert.are.equals("Witch", item.classRestriction)
	end)

	--TODO: POB2 class locked variants?
	--it("Requires Class variant", function()
	--end)

	it("short flags", function()
		item = new("Item"):Item(raw("Mirrored"))
		assert.truthy(item.mirrored)
		item = new("Item"):Item(raw("Corrupted"))
		assert.truthy(item.corrupted)
		item = new("Item"):Item(raw("Leech 6.61% of Physical Attack Damage as Mana (fractured)"))
		assert.truthy(item.fractured)
		item = new("Item"):Item(raw("Adds 36 to 48 Fire Damage (desecrated)"))
		assert.truthy(item.desecrated)
		item = new("Item"):Item(raw("Crafted: true"))
		assert.truthy(item.crafted)
		item = new("Item"):Item(raw("Unreleased: true"))
		assert.truthy(item.unreleased)
	end)

	it("long flags", function()
		local item = new("Item"):Item(raw("This item can be anointed by Cassia"))
		assert.truthy(item.canBeAnointed)
		item = new("Item"):Item(raw("Can have 1 additional Instilled Modifier"))
		assert.truthy(item.canHaveTwoEnchants)
		item = new("Item"):Item(raw("Can have an additional Instilled Modifier"))
		assert.truthy(item.canHaveTwoEnchants)
		item = new("Item"):Item(raw("Can have 2 additional Instilled Modifiers"))
		assert.truthy(item.canHaveTwoEnchants)
		assert.truthy(item.canHaveThreeEnchants)
		item = new("Item"):Item(raw("Can have 3 additional Instilled Modifiers"))
		assert.truthy(item.canHaveTwoEnchants)
		assert.truthy(item.canHaveThreeEnchants)
		assert.truthy(item.canHaveFourEnchants)
	end)
	
	it("tags", function()
		local item = new("Item"):Item(raw("{tags:life,physical_damage}+8 to Strength"))
		assert.are.same({ "life", "physical_damage" }, item.explicitModLines[1].modTags)
	end)

	it("range", function()
		local item = new("Item"):Item(raw("{range:0.8}+(8-12) to Strength"))
		assert.are.equals(0.8, item.explicitModLines[1].range)
		assert.are.equals(11, item.baseModList[1].value) -- range 0.8 of (8-12) = 11
	end)

	it("custom", function()
		local item = new("Item"):Item(raw("{custom}+8 to Strength"))
		assert.truthy(item.explicitModLines[1].custom)
	end)

	it("crafted", function()
		local item = new("Item"):Item(raw("{crafted}+8 to Strength"))
		assert.truthy(item.explicitModLines[1].crafted)
	end)

	it("preserves crafted mod lines when rebuilding raw text", function()
		local item = new("Item"):Item(raw("+8 to Strength"))
		item.explicitModLines[1].crafted = true
		item:BuildAndParseRaw()
		assert.truthy(item.explicitModLines[1].crafted)
	end)

	it("enchant", function()
		local item = new("Item"):Item(raw("+8 to Strength (enchant)"))
		assert.are.equals(1, #item.enchantModLines)
		-- enchant also sets enchant and implicit
		assert.truthy(item.enchantModLines[1].enchant)
		assert.truthy(item.enchantModLines[1].implicit)
	end)
	
	it("fractured", function()
		local item = new("Item"):Item(raw("{fractured}+8 to Strength"))
		assert.truthy(item.explicitModLines[1].fractured)
		item = new("Item"):Item(raw("+8 to Strength (fractured)"))
		assert.truthy(item.explicitModLines[1].fractured)
	end)

	it("implicit", function()
		local item = new("Item"):Item(raw("+8 to Strength (implicit)"))
		assert.truthy(item.implicitModLines[1].implicit)
	end)

	--TODO: POB2 multi-base items
	--it("multiple bases", function()
	--end)

	it("parses text without armour value then changes quality and has correct final armour", function()
		local item = new("Item"):Item([[
				Armour Gloves
				Rope Cuffs
				Quality: 0
			]])

		local original = item.armourData.Armour
		item.quality = 20
		item:BuildAndParseRaw()
		assert.are.equals(round(original * 1.2), item.armourData.Armour)
	end)

	it("magic item", function()
		local item = new("Item"):Item([[
				Rarity: MAGIC
				Name Prefix Rope Cuffs -> +50 ignite chance
				+50% chance to Ignite
			]])

		assert.are.equals("Name Prefix ", item.namePrefix)
		assert.are.equals(" -> +50 ignite chance", item.nameSuffix)
		assert.are.equals("Rope Cuffs", item.baseName)
		assert.are.equals(1, #item.explicitModLines)
		assert.are.equals("+50% chance to Ignite", item.explicitModLines[1].line)
	end)

	it("attribute converted", function()
		local item = new("Item"):Item([[
			Test Item
			Aegis Quarterstaff
			Quality: 20
			Sockets: S S S
			Rune: Soul Core of Cholotl
			Rune: Soul Core of Zantipi
			Rune: Soul Core of Atmohua
			LevelReq: 79
			Implicits: 4
			{enchant}{rune}Convert 20% of Requirements to Dexterity
			{enchant}{rune}Convert 20% of Requirements to Intelligence
			{enchant}{rune}Convert 20% of Requirements to Strength
			{tags:block}{range:1}+(10-15)% to Block chance
			Corrupted
			]])
		item:BuildAndParseRaw()
		assert.are.equals(35, item.requirements.strMod)
		assert.are.equals(86, item.requirements.dexMod)
		assert.are.equals(55, item.requirements.intMod)	
		
	end)


	it("infers pasted multi-value rune lines as whole runes", function()
		local item = new("Item"):Item([[
			Rarity: Rare
			Onslaught Relic
			Warmonger Bow
			--------
			Quality: +20% (augmented)
			Physical Damage: 91-161 (augmented)
			Elemental Damage: 57-98 (fire), 58-98 (cold)
			Critical Hit Chance: 11.00%
			Attacks per Second: 1.50 (augmented)
			--------
			Requires: Level 67, 86 Str, 65 Int
			--------
			Sockets: S S S
			--------
			Item Level: 81
			--------
			Adds 9 to 15 Cold Damage (rune)
			Leeches 3% of Physical Damage as Life (rune)
			Bonded: 5% increased maximum Life (rune)
			Bonded: 30% increased Freeze Buildup (rune)
			--------
			Adds 16 to 35 Physical Damage
			Adds 49 to 83 Cold Damage
			20% increased Attack Speed
			+31 to Strength
			Adds 57 to 98 Fire Damage (desecrated)
			--------
			Corrupted
		]])

		assert.are.equals(3, item.itemSocketCount)
		assert.are.same({ "Greater Glacial Rune", "Lesser Body Rune" }, item.runes)
		local runeLines = { }
		for _, modLine in ipairs(item.runeModLines) do
			runeLines[modLine.line] = true
		end
		assert.are.equals(4, #item.runeModLines)
		assert.is_true(runeLines["Adds 9 to 15 Cold Damage"])
		assert.is_true(runeLines["Leeches 3% of Physical Damage as Life"])
		assert.is_true(runeLines["Bonded: 5% increased maximum Life"])
		assert.is_true(runeLines["Bonded: 30% increased Freeze Buildup"])
		for _, rune in ipairs(item.runes) do
			assert.are_not.equals("Lesser Glacial Rune", rune)
		end
	end)

	it("keeps bonded rune stats separate from normal rune stats", function()
		local item = new("Item"):Item([[
			Rarity: Rare
			Test Body
			Rusted Cuirass
		]])
		item.itemSocketCount = 1
		item.runes = { "Lesser Body Rune" }
		item:UpdateRunes()

		assert.are.equals(3, #item.runeModLines)
		assert.are.equals("+30 to maximum Life", item.runeModLines[1].line)
		assert.are.equals("Bonded: +20 to maximum Life", item.runeModLines[2].line)
		assert.are.equals("Bonded: +20 to maximum Mana", item.runeModLines[3].line)
		assert.are.equals("Life", item.runeModLines[2].modList[1].name)
		assert.are.equals("Mana", item.runeModLines[3].modList[1].name)
	end)

	it("applies increased effect of socketed runes", function()
		local item = new("Item"):Item([[
			Test Wand
			Runic Fork
			Sockets: S
			Rune: Lesser Desert Rune
			Implicits: 1
			{enchant}{rune}Gain 6% of Damage as Extra Fire Damage
			200% increased effect of Socketed Runes
		]])
		item:BuildAndParseRaw()

		local damageGainAsFire = 0
		for _, mod in ipairs(item.slotModList[1]) do
			if mod.name == "DamageGainAsFire" and mod.type == "BASE" then
				damageGainAsFire = damageGainAsFire + mod.value
			end
		end
		assert.are.equals(18, damageGainAsFire)
		assert.is_not_nil(item:BuildRaw():match("{enchant}{rune}Gain 18%% of Damage as Extra Fire Damage"))
	end)

	it("applies increased effect of socketed augment items", function()
		local item = new("Item"):Item([[
			Test Wand
			Runic Fork
			Sockets: S
			Rune: Lesser Desert Rune
			Implicits: 1
			{enchant}{rune}Gain 6% of Damage as Extra Fire Damage
			100% increased effect of Socketed Augment Items
		]])
		item:BuildAndParseRaw()

		local damageGainAsFire = 0
		for _, mod in ipairs(item.slotModList[1]) do
			if mod.name == "DamageGainAsFire" and mod.type == "BASE" then
				damageGainAsFire = damageGainAsFire + mod.value
			end
		end
		assert.are.equals(12, damageGainAsFire)
		assert.is_not_nil(item:BuildRaw():match("{enchant}{rune}Gain 12%% of Damage as Extra Fire Damage"))
	end)

	it("does not double-scale imported socketed rune text", function()
		local item = new("Item"):Item([[
			Runeseeker's Call
			Runic Fork
			Unique ID: bbcd083b0a9da5650f3ac0a001364b1c99d6b866c1f52f0568fafab863b44ccb
			Item Level: 86
			Quality: 20
			Sockets: S S S S S S
			Rune: Hedgewitch Assandra's Rune of Wisdom
			Rune: Saqawal's Rune of the Sky
			Rune: Perfect Iron Rune
			Rune: Perfect Iron Rune
			Rune: Perfect Vision Rune
			Rune: Legacy of Lifesprig
			LevelReq: 90
			Implicits: 11
			{enchant}{rune}210% increased Spell Damage
			{enchant}{rune}+9 to Level of all Spell Skills
			{enchant}{rune}84% increased Critical Hit Chance for Spells
			{enchant}{rune}Gain 15% of Damage as Extra Damage of all Elements
			{enchant}{rune}Bonded: 75% increased Critical Damage Bonus
			{enchant}{rune}Bonded: 36% chance when collecting an Elemental Infusion to gain an
			{enchant}{rune}additional Elemental Infusion of the same type
			{enchant}{rune}Bonded: Archon recovery period expires 90% faster
			{enchant}{rune}Bonded: Break Armour on Critical Hit with Spells equal to 72% of Physical Damage dealt
			{enchant}{rune}Bonded: Leeches 3% of maximum Life when you Cast a Spell
			Grants Skill: Level 20 The Stars Answer
			Only Runes can be Socketed in this item
			200% increased effect of Socketed Runes
			Corrupted
		]])
		item:BuildAndParseRaw()

		local spellDamage = 0
		for _, mod in ipairs(item.slotModList[1]) do
			if mod.name == "Damage" and mod.type == "INC" and mod.flags == ModFlag.Spell then
				spellDamage = spellDamage + mod.value
			end
		end
		assert.are.equals(210, spellDamage)
		local rawItem = item:BuildRaw()
		assert.is_not_nil(rawItem:match("{enchant}{rune}210%% increased Spell Damage"))
		assert.is_not_nil(rawItem:match("{enchant}{rune}%+9 to Level of all Spell Skills"))
	end)

	it("infers pasted game rune lines with socketed rune effect", function()
		local item = new("Item"):Item([[
			Item Class: Wands
			Rarity: Unique
			Runeseeker's Call
			Runic Fork
			--------
			Quality: +20% (augmented)
			--------
			Requires: Level 90 (unmet)
			--------
			Sockets: S S S S S
			--------
			Item Level: 86
			--------
			Gain 120% of Damage as Extra Lightning Damage (rune)
			Remnants you create have 75% reduced effect (rune)
			Remnants can be collected from 150% further away (rune)
			--------
			Grants Skill: Level 20 The Stars Answer
			--------
			{ Unique Modifier }
			Only Runes can be Socketed in this item — Unscalable Value
			{ Unique Modifier }
			200% increased effect of Socketed Runes — Unscalable Value
			--------
			Smithed from ancient metal
			wrought from the very stars.
			It is a means to call upon them,
			for one capable of wielding it.
			--------
			Corrupted
		]])
		assert.are.equals(90, item.requirements.level)

		local damageGainAsLightning = 0
		for _, mod in ipairs(item.slotModList[1]) do
			if mod.name == "DamageGainAsLightning" and mod.type == "BASE" then
				damageGainAsLightning = damageGainAsLightning + mod.value
			end
		end
		assert.are.equals(120, damageGainAsLightning)

		item:BuildAndParseRaw()
		assert.are.equals(90, item.requirements.level)

		assert.are.equals(5, item.itemSocketCount)
		assert.are.equals(5, #item.runes)
		for _, rune in ipairs(item.runes) do
			assert.are_not.equals("None", rune)
		end

		damageGainAsLightning = 0
		for _, mod in ipairs(item.slotModList[1]) do
			if mod.name == "DamageGainAsLightning" and mod.type == "BASE" then
				damageGainAsLightning = damageGainAsLightning + mod.value
			end
		end
		assert.are.equals(120, damageGainAsLightning)
		local rawItem = item:BuildRaw()
		assert.is_not_nil(rawItem:match("{enchant}{rune}Gain 120%% of Damage as Extra Lightning Damage"))
		assert.is_not_nil(rawItem:match("{enchant}{rune}Remnants you create have 75%% reduced effect"))
		assert.is_not_nil(rawItem:match("{enchant}{rune}Remnants can be collected from 150%% further away"))

		for i = 1, item.itemSocketCount do
			item.runes[i] = "None"
		end
		item:UpdateRunes()
		item:BuildAndParseRaw()
		assert.are.equals(65, item.requirements.level)
	end)

	it("multi-line rune mod", function()
		-- Thruldana is Bow-only as well
		local item = new("Item"):Item([[
			Test Item
			Crude Bow
			Quality: 20
			Sockets: S S
			Rune: Talisman of Thruldana
			Rune: Talisman of Thruldana
			Implicits: 2
			{enchant}{rune}50% reduced Poison Duration
			{enchant}{rune}Targets can be affected by +2 of your Poisons at the same time
		]])
		item:BuildAndParseRaw()
		
		assert.are.equals(2, #item.sockets)
		assert.are.equals(2, #item.runeModLines)
		
	end)

	it("loads Darkness Enthroned with two augment sockets", function()
		local item = new("Item"):Item(data.uniques.belt[6])

		assert.are.equals("Darkness Enthroned, Fine Belt", item.name)
		assert.are.equals(2, item.itemSocketCount)
		assert.are.equals(2, #item.sockets)

		item.variant = 1 -- Helmet
		item:BuildModList()
		local baseType, specificType = item:GetSocketedAugmentTypes()
		assert.are.equals("armour", baseType)
		assert.are.equals("helmet", specificType)
	end)

	it("infers helmet augments from an advanced copy of Darkness Enthroned", function()
		local item = new("Item"):Item([[
			Item Class: Belts
			Rarity: Unique
			Darkness Enthroned
			Fine Belt
			--------
			Requires: Level 62
			--------
			Sockets: S S
			--------
			Item Level: 83
			--------
			28% increased Armour, Evasion and Energy Shield (rune)
			12% increased Skill Effect Duration (rune)
			12% increased Cooldown Recovery Rate (rune)
			--------
			{ Implicit Modifier }
			Flasks gain 0.17 charges per Second
			{ Implicit Modifier — Charm }
			Has 1(1-3) Charm Slot
			--------
			{ Unique Modifier }
			This item gains bonuses from Socketed Items as though it was a Helmet — Unscalable Value
			{ Unique Modifier }
			61(50-100)% increased effect of Socketed Augment Items — Unscalable Value
			--------
			Kulemak sat triumphant, raising the crown.
			Darkness coiled the world in eternal night.
			Victory, a mere moment, came crashing down.
			No conqueror, no conquered, only searing Light.
			--------
			Corrupted
			--------
			Note: ~b/o 40 exalted
		]])

		assert.are.same({ "Greater Iron Rune", "Quipolatl's Soul Core of Flow" }, item.runes)
		local rawItem = item:BuildRaw()
		assert.is_not_nil(rawItem:match("28%% increased Armour, Evasion and Energy Shield"))
		assert.is_not_nil(rawItem:match("12%% increased Skill Effect Duration"))
		assert.is_not_nil(rawItem:match("12%% increased Cooldown Recovery Rate"))

		item:BuildAndParseRaw()
		assert.are.same({ "Greater Iron Rune", "Quipolatl's Soul Core of Flow" }, item.runes)
		rawItem = item:BuildRaw()
		assert.is_not_nil(rawItem:match("28%% increased Armour, Evasion and Energy Shield"))
		assert.is_not_nil(rawItem:match("12%% increased Skill Effect Duration"))
		assert.is_not_nil(rawItem:match("12%% increased Cooldown Recovery Rate"))
	end)

	it("infers body armour augments from an advanced copy of Darkness Enthroned", function()
		local item = new("Item"):Item([[
			Item Class: Belts
			Rarity: Unique
			Darkness Enthroned
			Fine Belt
			--------
			Requires: Level 62
			--------
			Sockets: S S
			--------
			Item Level: 86
			--------
			+83 to Spirit (rune)
			Idols socketed in this item gain the benefits of their Bonded modifiers (rune)
			-1 to Spirit per 2 Levels (rune)
			Bonded: +8% to Quality of all Skills (rune)
			--------
			{ Implicit Modifier }
			Flasks gain 0.17 charges per Second
			{ Implicit Modifier — Charm }
			Has 1(1-3) Charm Slot
			--------
			{ Unique Modifier }
			This item gains bonuses from Socketed Items as though it was a Body Armour — Unscalable Value
			{ Unique Modifier }
			66(50-100)% increased effect of Socketed Augment Items — Unscalable Value
			--------
			Kulemak sat triumphant, raising the crown.
			Darkness coiled the world in eternal night.
			Victory, a mere moment, came crashing down.
			No conqueror, no conquered, only searing Light.
			--------
			Corrupted
			--------
			Note: ~b/o 1 divine
		]])

		assert.are.same({ "Rune of the Blossom", "Fox Idol" }, item.runes)
		local rawItem = item:BuildRaw()
		assert.is_not_nil(rawItem:match("%+83 to Spirit"))
		assert.is_not_nil(rawItem:match("%-1 to Spirit per 2 Levels"))
		assert.is_not_nil(rawItem:match("Bonded: %+8%% to Quality of all Skills"))

		item:BuildAndParseRaw()
		assert.are.same({ "Rune of the Blossom", "Fox Idol" }, item.runes)
		rawItem = item:BuildRaw()
		assert.is_not_nil(rawItem:match("%+83 to Spirit"))
		assert.is_not_nil(rawItem:match("%-1 to Spirit per 2 Levels"))
		assert.is_not_nil(rawItem:match("Bonded: %+8%% to Quality of all Skills"))
	end)

	it("parses Atziri's Splendour soul core socket types", function()
		local item = new("Item"):Item(data.uniques.body[1])
		item.variant = 1 -- Helmet
		item:BuildModList()

		assert.is_true(item.socketedSoulCoreTypes["helmet"])
		assert.is_nil(item.socketedSoulCoreTypes["gloves"])
	end)

	it("infers Soul Cores using Atziri's Splendour's variant type", function()
		local item = new("Item"):Item([[
			Item Class: Body Armours
			Rarity: Unique
			Atziri's Splendour
			Sacrificial Regalia
			--------
			Sockets: S S S S S S
			--------
			Item Level: 86
			--------
			8% increased Skill Effect Duration (rune)
			8% increased Cooldown Recovery Rate (rune)
			--------
			Only Soul Cores can be Socketed in this item
			This item gains bonuses from Socketed Soul Cores as though it was also a Helmet
		]])

		assert.are.same({ "Quipolatl's Soul Core of Flow" }, item.runes)
		item:BuildAndParseRaw()
		assert.are.same({ "Quipolatl's Soul Core of Flow", "None", "None", "None", "None", "None" }, item.runes)
		assert.are.equals(2, #item.runeModLines)

		item = new("Item"):Item([[
			Item Class: Body Armours
			Rarity: Unique
			Atziri's Splendour
			Sacrificial Regalia
			--------
			Sockets: S S S S S S
			--------
			Item Level: 86
			--------
			Hits against you have 40% reduced Critical Damage Bonus (rune)
			--------
			Only Soul Cores can be Socketed in this item
			This item gains bonuses from Socketed Soul Cores as though it was also a Shield
		]])

		assert.are.same({ "Soul Core of Ticaba" }, item.runes)
		item:BuildAndParseRaw()
		assert.are.same({ "Soul Core of Ticaba", "None", "None", "None", "None", "None" }, item.runes)
		assert.are.equals("Hits against you have 40% reduced Critical Damage Bonus", item.runeModLines[1].line)
	end)

	it("infers pasted Soul Core lines with socketed Soul Core effect", function()
		local item = new("Item"):Item([[
			Item Class: Shields
			Rarity: Unique
			Mahuxotl's Machination
			Omen Crest Shield
			--------
			Sockets: S
			--------
			Hits against you have 40% reduced Critical Damage Bonus (rune)
			--------
			100% increased effect of Socketed Soul Cores
		]])

		assert.are.same({ "Soul Core of Ticaba" }, item.runes)
		item:BuildAndParseRaw()
		assert.are.same({ "Soul Core of Ticaba" }, item.runes)
		assert.is_not_nil(item:BuildRaw():match("Hits against you have 40%% reduced Critical Damage Bonus"))
	end)

	it("jewel sockets", function()
		local item = new("Item"):Item([[
			Six Socket Body
			Garment
			Quality: 20
			Sockets: J J J J J J
		]])
		item:BuildAndParseRaw()

		assert.are.equals(6, item.jewelSocketCount)
	end)
end)

describe("TestAdvancedItemParse #item", function()
	local function raw(s, base)
		base = base or "Arcane Raiment"
		return "Rarity: Rare\nName\n"..base.."\n"..s
	end

	it("parses to craft", function()
		local item = new("Item"):Item(raw([[
			{ Prefix Modifier "Azure" (Tier: 7) - Mana }
			+31(25-34) to maximum Mana
		]], "Refined Bracers"))
		assert.are.equals("IncreasedMana3", item.prefixes[1].modId)
		assert.are.equals(0.667, item.prefixes[1].range)
		assert.are.equals("mana", item.explicitModLines[1].modTags[1])
	end)

	it("parses correct range", function()
		local item = new("Item"):Item(raw([[
			{ Desecrated Prefix Modifier "Frigid" (Tier: 6) - Damage, Elemental, Cold, Attack }
			Adds 8(7-8) to 13(12-14) Cold damage to Attacks
		]], "Refined Bracers"))
		assert.are.equals("Adds 8 to 13 Cold damage to Attacks", item.explicitModLines[1].line)
	end)

	-- GGG scales each mod line separately here, but PoB scales them both together, so this parsing is a bit wonky
	it("parses multi-line mod", function()
		local item = new("Item"):Item(raw([[
			{ Prefix Modifier "Bishop's" (Tier: 3) — Life, Defences }
			27(27-32)% increased Energy Shield
			+31(26-32) to maximum Life
		]], "Ancestral Tiara"))
		assert.are.equals("LocalIncreasedEnergyShieldAndLife4", item.prefixes[1].modId)
		assert.are.equals(0, item.prefixes[1].range)
		assert.are.equals(0.833333, item.explicitModLines[2].range)
	end)

	it("resets linePrefix", function() 
		local item = new("Item"):Item(raw([[
			{ Prefix Modifier "Warlock's" (Tier: 4) — Mana, Damage, Caster }
			32(30-37)% increased Spell Damage
			+46(42-47) to maximum Mana
			--------
			+15 to maximum life
		]], "Voltaic Staff"))
		assert.are_not.equals("mana", item.explicitModLines[3].modTags[1])
	end)

	it("resets linePostfix", function() 
		local item = new("Item"):Item(raw([[
			{ Corruption Enhancement — Mana }
			24(20-30)% increased Mana Regeneration Rate
			--------
			+15 to maximum life
		]]))
		assert.falsy(item.explicitModLines[1].enchant)
	end)

	it("parses vaaled catalyst", function() 
		local item = new("Item"):Item(raw([[
			Quality (Attribute Modifiers): +19% (augmented)
			{ Unique Modifier — Attribute  — 19% Increased }
			+120(80-100) to all Attributes
			(Attributes are Strength, Dexterity, and Intelligence)
		]], "Stellar Amulet"))
		assert.are.equals(142, item.baseModList[1].value)
		-- assert.falsy(item.explicitModLines[1].range) -- Not sure why this is returning 0.5
		assert.are.equals(12, item.catalyst)
		assert.are.equals(19, item.catalystQuality)
	end)

	it("parses vaaled catalyst within range", function() 
		local item = new("Item"):Item(raw([[
			Quality (Attribute Modifiers): +19% (augmented)
			{ Unique Modifier — Attribute  — 19% Increased }
			+95(80-100) to all Attributes
			(Attributes are Strength, Dexterity, and Intelligence)
		]], "Stellar Amulet"))
		assert.are.equals(113, item.baseModList[1].value)
		assert.are.equals(0.75, item.explicitModLines[1].range)
		assert.are.equals(12, item.catalyst)
		assert.are.equals(19, item.catalystQuality)
	end)

	it("doesn't scale unscalable", function()
		local item = new("Item"):Item(raw([[
			Quality (Life and Mana Modifiers): +20% (augmented)
			{ Unique Modifier — Life, Defences, Energy Shield, Minion, Gem }
			Socketed Golem Skills gain 20% of Maximum Life as Extra Maximum Energy Shield — Unscalable Value
		]]))
		assert.are.equals(20, item.baseModList[1].value.mod.value)
	end)

	it("correctly matches conqueror mod", function()
		local item = new("Item"):Item(raw([[
			{ Suffix Modifier "of the Conquest" (Tier: 1) — Elemental, Cold }
			10(8-10)% chance to Avoid Cold Damage from Hits
			(No chance to avoid damage can be higher than 75%)
			Warlord Item
		]]))
		assert.are.equals(10, item.baseModList[1].value)
		-- assert.are.equals(1, item.explicitModLines[1].range) -- Not sure why this is returning 0.5
	end)

	it("parses enchant correctly #enchant", function()
		local item = new("Item"):Item(raw([[
			{ Corrupted Enhancement }
			+8(6-10)% to Fire Resistance
		]]))
		assert.are.equals(8, item.enchantModLines[1].modList[1].value)
	end)

	it("parses enchant with tags correctly #enchant", function()
		local item = new("Item"):Item(raw([[
			{ Corrupted Enhancement - Energy Shield }
			+8(6-10)% to Fire Resistance
		]]))
		assert.are.equals(8, item.enchantModLines[1].modList[1].value)
		assert.are.equals("energyshield", item.enchantModLines[1].modTags[1])
	end)

	it("parses junk", function()
		local godTestItem = new("Item"):Item([[
			Item Class: Sceptres
			Rarity: Unique
			Nebulis
			Synthesised Omen Sceptre
			--------
			Sceptre
			Physical Damage: 50-76
			Critical Strike Chance: 7.30%
			Attacks per Second: 1.25
			Weapon Range: 1.1 metres
			Memory Strands: 58
			--------
			Requirements:
			Level: 68
			Str: 104
			Int: 122
			--------
			Sockets: B R
			--------
			Item Level: 87
			--------
			+30% to Fire Resistance (scourge)
			22% reduced Global Defences (scourge)
			(Armour, Evasion Rating and Energy Shield are the standard Defences) (scourge)
			--------
			8% increased Explicit Cold Modifier magnitudes (enchant)
			Has 1 White Socket (enchant)
			--------
			{ Searing Exarch Implicit Modifier (Lesser) }
			Tempest Shield has 15(15-17)% increased Buff Effect
			{ Implicit Modifier — Damage, Critical  — 106% Increased }
			+15(15-17)% to Global Critical Strike Multiplier
			--------
			{ Prefix Modifier "Freezing" (Tier: 5) — Damage, Elemental, Cold, Caster  — 8% Increased }
			Adds 17(16-20) to 35(30-36) Cold Damage to Spells
			{ Prefix Modifier "Beetle's" (Tier: 6) — Defences, Armour }
			9(6-13)% increased Armour
			7(6-7)% increased Stun and Block Recovery
			{ Master Crafted Prefix Modifier "Upgraded" — Life, Defences, Armour }
			21(18-21)% increased Armour
			+18(17-19) to maximum Life
			{ Unique Modifier }
			106(60-120)% increased Implicit Modifier magnitudes — Unscalable Value
			(Implicit Modifiers are those that come from an item's type, rather than its random properties)
			{ Master Crafted Suffix Modifier "of Craft" (Rank: 3) — Elemental, Cold, Resistance }
			+35(29-35)% to Cold Resistance
			{ Fractured Prefix Modifier "Thorny" (Tier: 2) — Damage, Physical }
			Reflects 3(1-4) Physical Damage to Melee Attackers
			{ Prefix Modifier "Veiled" }
			Veiled Prefix
			Searing Exarch Item
			--------
			{ Allocated Crucible Passive Skill (Tier: 2) }
			Adds 2 to 6 Physical Damage to Spells
			--------
			Synthesised Item
			--------
			Corrupted
			--------
			Scourged
			--------
			Hinekora's Lock
			--------
			Note: ~b/o 2 chaos
		]])
	end)

	it("preserves independently rolled affix values when crafting", function()
		local item = new("Item"):Item(raw([[
			{ Fractured Prefix Modifier "Frigid" (Tier: 4) — Damage, Elemental, Cold, Attack }
			Adds 7(7-8) to 14(12-14) Cold damage to Attacks
		]], "Refined Bracers"))

		assert.are.equals("AddedColdDamage4", item.prefixes[1].modId)
		assert.are.same({ 0, 1 }, item.prefixes[1].range)
		assert.is_true(item.prefixes[1].fractured)
		item:Craft()
		assert.are.equals("Adds 7 to 14 Cold damage to Attacks", item.explicitModLines[1].line)
		assert.is_true(item.explicitModLines[1].fractured)
	end)

	it("parses fixed advanced-copy values from a legacy Prism Guardian", function()
		local item = new("Item"):Item([[
			Rarity: Unique
			Prism Guardian
			Sectarian Crest Shield
			{ Unique Modifier }
			+1 to Maximum Spirit per 25(50) Maximum Life
		]])

		assert.are.equals("+1 to Maximum Spirit per 25 Maximum Life", item.explicitModLines[1].line)
	end)

	it("preserves a Heroic Tragedy seed and selected commander", function()
		local item = new("Item"):Item([[
			Rarity: Unique
			Heroic Tragedy
			Timeless Jewel
			{ Unique Modifier }
			Remembrancing 7321(100-8000) songworthy deeds by the line of Vorana(Vorana-Olroth)
		]])

		assert.are.equals("Remembrancing 7321 songworthy deeds by the line of Vorana",
			itemLib.applyRange(item.explicitModLines[1].line, item.explicitModLines[1].range))
		item:BuildAndParseRaw()
		assert.are.equals("Remembrancing 7321 songworthy deeds by the line of Vorana",
			itemLib.applyRange(item.explicitModLines[1].line, item.explicitModLines[1].range))
	end)

	it("orders advanced-copy unique modifiers by database stat order", function()
		local item = new("Item"):Item([[
			Rarity: Unique
			Evergrasping Ring
			Pearl Ring
			{ Implicit Modifier — Caster, Speed }
			8(7-10)% increased Cast Speed
			{ Unique Modifier — Chaos }
			Enemies in your Presence Gain 8(6-12)% of Damage as Extra Chaos Damage
			{ Unique Modifier — Chaos }
			Allies in your Presence Gain 22(15-25)% of Damage as Extra Chaos Damage
			{ Unique Modifier — Mana }
			+91(60-100) to maximum Mana
		]])

		assert.are.same({
			"+(60-100) to maximum Mana",
			"Allies in your Presence Gain (15-25)% of Damage as Extra Chaos Damage",
			"Enemies in your Presence Gain (6-12)% of Damage as Extra Chaos Damage",
		}, {
			item.explicitModLines[1].line,
			item.explicitModLines[2].line,
			item.explicitModLines[3].line,
		})
	end)

	it("filters flask state and base-property lines", function()
		local item = new("Item"):Item([[
			Rarity: Unique
			Opportunity
			Ultimate Life Flask
			Recovers 2061 (augmented) Life over 4.20 Seconds
			Consumes 4 (augmented) of 75 Charges on use
			Currently has 0 Charges
			{ Unique Modifier }
			Cannot be Used manually
		]])

		assert.are.equals(1, #item.explicitModLines)
		assert.are.equals("Cannot be Used manually", item.explicitModLines[1].line)
	end)

	describe("mod magnitude scaling", function()
		before_each(function()
			newBuild()
			runCallback("onFrame")
		end)
		local function chaosDamageInc()
			return build.calcsTab.mainEnv.modDB:Sum("INC", nil, "ChaosDamage")
		end

		local function chaosResist()
			return build.calcsTab.mainEnv.modDB:Sum("BASE", nil, "ChaosResist")
		end

		local function spellCrit()
			return build.calcsTab.mainEnv.modDB:Sum("INC", { flags = ModFlag.Spell }, "CritChance")
		end

		local function spellDamage()
			return build.calcsTab.mainEnv.modDB:Sum("INC", { flags = ModFlag.Spell }, "Damage")
		end

		it("scales matching implicit mods by modifier magnitude", function()
			-- 130% * 1.7 = 221
			build.itemsTab:CreateDisplayItemFromRaw([[
			Rarity: RARE
			Test Subject
			Omen Sceptre
			LevelReq: 60
			Implicits: 1
			{range:0.5}(100-160)% increased Chaos Damage
			{range:0.5}70% increased implicit Modifier magnitudes
		]])
			local item = build.itemsTab.displayItem
			assert.is_true(item.advancedCopy)
			build.itemsTab:AddDisplayItem()
			runCallback("OnFrame")
			assert.are.equals(221, chaosDamageInc())
		end)

		it("does not apply disabled modifier magnitude", function()
			local item = new("Item"):Item([[
			Rarity: UNIQUE
			Magnitude Test
			Arcane Raiment
			Implicits: 1
			{range:0.5}+(10-20) to maximum Life
			{disabled}100% increased Implicit Modifier magnitudes
		]])
			assert.are.equals(1, item.implicitModLines[1].valueScalar)
		end)

		it("scales properly using old Eyes of the Greatwolf line", function()
			build.itemsTab:CreateDisplayItemFromRaw([[
			Rarity: UNIQUE
			Eyes of the Greatwolf
			Solar Amulet
			Quality (Caster Modifiers): +20% (augmented)
			LevelReq: 60
			Implicits: 1
			{tags:caster}{range:0.5}(100-160)% increased Spell Damage
			{range:0.5}Implicit Modifier magnitudes are doubled
		]])
			local item = build.itemsTab.displayItem
			assert.is_true(item.advancedCopy)
			build.itemsTab:AddDisplayItem()
			runCallback("OnFrame")
			assert.are.equals(312, spellDamage())
		end)

		it("scales properly using new Eyes of the Greatwolf line", function()
			-- 130% * 1.7 = 221
			build.itemsTab:CreateDisplayItemFromRaw([[
			Rarity: RARE
			Test Subject
			Solar Amulet
			LevelReq: 60
			Implicits: 1
			{range:0.5}{enchant}(100-160)% increased Chaos Damage
			{range:0.5}(50-100)% increased Enchantment Modifier magnitudes
		]])
			local item = build.itemsTab.displayItem
			assert.is_true(item.advancedCopy)
			build.itemsTab:AddDisplayItem()
			runCallback("OnFrame")
			assert.are.equals(227, chaosDamageInc())
		end)
		it("does not rescale old format (baked) copies", function()
			-- magnitude already baked in, so no rescale
			build.itemsTab:CreateDisplayItemFromRaw([[
			Rarity: RARE
			Baked Subject
			Gelid Staff
			LevelReq: 60
			Implicits: 0
			{tags:chaos,damage}130% increased Chaos Damage
			70% increased Chaos Modifier magnitudes
		]])
			local item = build.itemsTab.displayItem
			assert.is_false(item.advancedCopy)
			build.itemsTab:AddDisplayItem()
			runCallback("OnFrame")
			assert.are.equals(130, chaosDamageInc())
		end)

		it("only scales mods that share the magnitude mod's tags", function()
			build.itemsTab:CreateDisplayItemFromRaw([[
			Rarity: RARE
			Test Subject
			Sapphire Ring
			LevelReq: 20
			Implicits: 0
			{tags:chaos,damage}{range:0.5}(100-160)% increased Chaos Damage
			{tags:resistance}{range:0.5}+(20-40)% to Chaos Resistance
			{range:0.5}100% increased resistance modifier magnitudes
		]])
			assert.are.equals(0, chaosResist())
			build.itemsTab:AddDisplayItem()
			runCallback("OnFrame")
			assert.are.equals(60, chaosResist())
			assert.are.equals(130, chaosDamageInc())
			newBuild()

			build.itemsTab:CreateDisplayItemFromRaw([[
			Rarity: RARE
			Test Subject
			Sapphire Ring
			LevelReq: 20
			Implicits: 0
			{tags:chaos,damage}{range:0.5}(100-160)% increased Chaos Damage
			{tags:defences}{range:0.5}+(20-40)% to Chaos Resistance
			{range:0.5}100% increased defence modifier magnitudes
		]])
			assert.are.equals(0, chaosResist())
			build.itemsTab:AddDisplayItem()
			runCallback("OnFrame")
			assert.are.equals(60, chaosResist())
			assert.are.equals(130, chaosDamageInc())
			newBuild()

			build.itemsTab:CreateDisplayItemFromRaw([[
			Rarity: RARE
			Test Subject
			Sapphire Ring
			LevelReq: 20
			Implicits: 0
			{tags:chaos,damage}{range:0.5}(100-160)% increased Chaos Damage
			{tags:physical,damage}{range:0.5}+(20-40)% to Chaos Resistance
			{tags:caster,damage}{range:0.5}(10-30)% increased spell damage
			{range:0.5}100% increased Explicit Physical and Chaos Damage Modifier magnitudes
		]])
			assert.are.equals(0, chaosResist())
			build.itemsTab:AddDisplayItem()
			runCallback("OnFrame")
			assert.are.equals(60, chaosResist())
			assert.are.equals(260, chaosDamageInc())
			assert.are.equals(20, spellDamage())
		end)

		it("only scales the modifier type named by the magnitude mod", function()
			build.itemsTab:CreateDisplayItemFromRaw([[
			Rarity: RARE
			Test Subject
			Sapphire Ring
			LevelReq: 20
			Implicits: 1
			{range:0.5}(100-160)% increased Chaos Damage
			{range:0.5}+(20-40)% to Chaos Resistance
			{range:0.5}100% increased explicit modifier magnitudes
		]])
			assert.are.equals(0, chaosResist())
			build.itemsTab:AddDisplayItem()
			runCallback("OnFrame")
			assert.are.equals(60, chaosResist())
			assert.are.equals(130, chaosDamageInc())
		end)

		it("handles explicit physical and chaos modifier magnitudes", function()
			build.itemsTab:CreateDisplayItemFromRaw([[
			Rarity: RARE
			Test Subject
			Omen Sceptre
			LevelReq: 60
			Implicits: 1
			{tags:chaos,damage}{range:0.5}(100-160)% increased Chaos Damage
			{tags:physical,chaos,damage}{range:0.5}(100-160)% increased Chaos Damage
			{range:0.5}10% increased Explicit Physical and Chaos Damage Modifier magnitudes
		]])
			build.itemsTab:AddDisplayItem()
			runCallback("OnFrame")
			assert.are.equals(273, chaosDamageInc())
		end)

		it("does not scale unscalable modifiers", function()
			build.itemsTab:CreateDisplayItemFromRaw([[
			Rarity: RARE
			Test Subject
			Omen Sceptre
			LevelReq: 60
			Implicits: 0
			{tags:chaos,damage}{range:0.5}(100-160)% increased Chaos Damage — Unscalable Value
			{range:0.5}100% increased Explicit Modifier magnitudes
		]])
			build.itemsTab:AddDisplayItem()
			runCallback("OnFrame")
			assert.are.equals(130, chaosDamageInc())
		end)

		it("does not scale unscalable base implicits", function()
			local base = data.itemBases["Fists of Stone"]
			local item = new("Item"):Item("Rarity: Rare\nTest Subject\nFists of Stone\nCrafted: true\nImplicits: 2\n" .. base.implicit .. "\n100% increased Implicit Modifier magnitudes")
			for _, modLine in ipairs(item.implicitModLines) do
				assert.is_true(modLine.unscalable)
				assert.are.equals(1, modLine.valueScalar)
			end
		end)

		it("reduces the modifier magnitude correctly", function()
			build.itemsTab:CreateDisplayItemFromRaw([[
			Rarity: RARE
			Test Subject
			Sapphire Ring
			LevelReq: 20
			Implicits: 0
			{range:0.5}(100-160)% increased Chaos Damage
			{range:0.5}+(20-40)% to Chaos Resistance
			{range:0.5}50% reduced explicit modifier magnitudes
		]])
			assert.are.equals(0, chaosResist())
			build.itemsTab:AddDisplayItem()
			runCallback("OnFrame")
			assert.are.equals(15, chaosResist())
			assert.are.equals(65, chaosDamageInc())
		end)
		it("scales only prefixes for increased effect of prefixes", function()
			build.itemsTab:CreateDisplayItemFromRaw([[
			Rarity: RARE
			Test Subject
			Sapphire Ring
			LevelReq: 20
			Implicits: 0
			{prefix}{range:0.5}(100-160)% increased Chaos Damage
			{suffix}{range:0.5}+(20-40)% to Chaos Resistance
			{range:0.5}50% increased effect of prefixes
		]])
			assert.are.equals(0, chaosResist())
			build.itemsTab:AddDisplayItem()
			runCallback("OnFrame")
			assert.are.equals(30, chaosResist())
			assert.are.equals(195, chaosDamageInc())
		end)

		it("preserves affix types when crafting items", function()
			local item = new("Item"):Item([[
			Rarity: Rare
			Test Subject
			Sapphire
			Crafted: true
			Prefix: JewelChaosDamage
			Suffix: CraftedJewelPrefixEffect
			Implicits: 0
			10% increased Chaos Damage
			50% increased Effect of Prefixes
		]])
			item:Craft()
			assert.is_true(item.explicitModLines[1].prefix)
			assert.are.equals(15, item.baseModList:Sum("INC", nil, "ChaosDamage"))
		end)

		it("preserves affix tags when crafting items", function()
			local item = new("Item"):Item([[
			Rarity: Rare
			Test Subject
			Sapphire Ring
			Quality (Chaos Modifiers): +20% (augmented)
			Crafted: true
			Prefix: ChaosDamagePercent6
			Suffix: DestructionInfluenceChaosModifierEffect
			Implicits: 0
			{tags:chaos,damage}{prefix}{range:1}(27-30)% increased Chaos Damage
			{tags:chaos}{suffix}{range:1}(15-20)% increased Explicit Chaos Modifier magnitudes
		]])
			item.prefixes[1].range = 1
			item.suffixes[1].range = 1
			item:Craft()
			assert.are.equals(42, item.baseModList:Sum("INC", nil, "ChaosDamage"))
			item:BuildAndParseRaw()
			assert.are.equals(42, item.baseModList:Sum("INC", nil, "ChaosDamage"))
		end)

		-- actually a ring so we don't have to allocate a socket
		local realJewel = [[
				Rarity: Rare
				Pandemonium Desire
				Ruby Ring
				--------
				Quality (Caster Modifiers): +20% (augmented)
				--------
				Item Level: 80
				--------
				{ Corruption Enhancement — Elemental, Cold, Resistance }
				+7(5-10)% to Cold Resistance
				{ Corruption Enhancement — Attribute }
				+6(4-6) to Intelligence
				--------
				{ Fractured Crafted Prefix Modifier "" }
				60(40-60)% increased Effect of Suffixes — Unscalable Value
				{ Prefix Modifier "Mystic" (Tier: 1) — Damage, Caster — 20% Increased }
				7(5-15)% increased Spell Damage
				{ Suffix Modifier "of Unmaking" (Tier: 1) — Damage, Caster, Critical — 80% Increased }
				20(10-20)% increased Critical Spell Damage Bonus
				{ Desecrated Suffix Modifier "of Annihilating" (Tier: 1) — Caster, Critical — 80% Increased }
				15(5-15)% increased Critical Hit Chance for Spells
				{ Suffix Modifier "of Potency" (Tier: 1) — Damage, Critical — 60% Increased }
				20(10-20)% increased Critical Strike Multiplier
				--------
				Place into an allocated Jewel Socket on the Passive Skill Tree. Right click to remove from the Socket.
				--------
				Twice Corrupted
				--------
				Fractured Item
				--------
				Note: ~b/o 1 mirror
		]]
		it("scales only prefixes for increased effect of prefixes for advanced copy format", function()
			assert.equal(0, spellCrit())
			local item = new("Item"):Item(realJewel)
			build.itemsTab:AddItem(item)
			build.itemsTab:EquipItemInSet(item, build.itemsTab.activeItemSetId)
			runCallback("OnFrame")
			assert.equal(26, spellCrit())
			assert.equal(8, spellDamage())
		end)

		it("does not apply scaling twice when saving and loading", function()
			local item = new("Item"):Item(new("Item"):Item(realJewel):BuildRaw())
			build.itemsTab:AddItem(item)
			build.itemsTab:EquipItemInSet(item, build.itemsTab.activeItemSetId)
			runCallback("OnFrame")
			assert.equal(26, spellCrit())
			assert.equal(8, spellDamage())
		end)

		it("The Unborn Lich scales its desecrated mods #f", function()
			local raw
			for _, itemStr in ipairs(data.uniques.staff) do
				if itemStr:find("Unborn Lich") then
					raw = itemStr
					break
				end
			end
			if not raw then
				error("Couldn't find unborn lich")
			end
			build.itemsTab:CreateDisplayItemFromRaw(raw)
			build.itemsTab:AddDisplayItem()
			runCallback("OnFrame")
			assert.are.equals(221, chaosDamageInc())

			-- the tooltip advertises the same scaled value the calculation uses
			local tooltip = new("Tooltip"):Tooltip()
			build.itemsTab:AddItemTooltip(tooltip, new("Item"):Item(raw))
			local found = false
			for _, section in ipairs(tooltip.lines) do
				if section.text and section.text:find("221% increased Chaos Damage", 1, true) then
					found = true
					break
				end
			end
			assert.is_true(found)
		end)
	end)
end)
