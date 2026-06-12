describe("TestItemParse", function()
	local function raw(s, base)
		base = base or "Arcane Raiment"
		return "Rarity: Rare\nName\n"..base.."\n"..s
	end

	it("Rarity", function()
		local item = new("Item", "Rarity: Normal\nRing")
		assert.are.equals("NORMAL", item.rarity)
		item = new("Item", "Rarity: Magic\nRing")
		assert.are.equals("MAGIC", item.rarity)
		item = new("Item", "Rarity: Rare\nName\nRing")
		assert.are.equals("RARE", item.rarity)
		item = new("Item", "Rarity: Unique\nName\nRing")
		assert.are.equals("UNIQUE", item.rarity)
	end)

	--it("Defence", function()
	--	local item = new("Item", raw("Armour: 25"))
	--	assert.are.equals(25, item.armourData.Armour)
	--	item = new("Item", raw("Evasion Rating: 35", "Shabby Jerkin"))
	--	assert.are.equals(35, item.armourData.Evasion)
	--	item = new("Item", raw("Energy Shield: 15", "Simple Robe"))
	--	assert.are.equals(15, item.armourData.EnergyShield)
	--	item = new("Item", raw("Ward: 180", "Runic Crown"))
	--	assert.are.equals(180, item.armourData.Ward)
	--end)

	it("Title", function()
		local item = new("Item", [[
			Rarity: Rare
			Phoenix Paw
			Furtive Wraps
		]])
		assert.are.equal("Phoenix Paw", item.title)
		assert.are.equal("Furtive Wraps", item.baseName)
		assert.are.equal("Phoenix Paw, Furtive Wraps", item.name)
	end)

	it("Unique ID", function()
		local item = new("Item", raw("Unique ID: 40f9711d5bd7ad2bcbddaf71c705607aef0eecd3dcadaafec6c0192f79b82863"))
		assert.are.equals("40f9711d5bd7ad2bcbddaf71c705607aef0eecd3dcadaafec6c0192f79b82863", item.uniqueID)
	end)

	it("Unique ID line is not parsed as a modifier", function()
		local item = new("Item", [[
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
		local item = new("Item", raw("Item Level: 10"))
		assert.are.equals(10, item.itemLevel)
	end)

	it("Quality", function()
		local item = new("Item", raw("Quality: 10"))
		assert.are.equals(10, item.quality)
		item = new("Item", raw("Quality: +12% (augmented)"))
		assert.are.equals(12, item.quality)
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

	--it("variant", function()
	--end)
	
	--TODO: Alt variants for POB2
	--it("Alt Variant", function()
	--end)

	it("Requires Level", function()
		local item = new("Item", raw("Requires Level 10"))
		assert.are.equals(10, item.requirements.level)
		item = new("Item", raw("Level: 10"))
		assert.are.equals(10, item.requirements.level)
		item = new("Item", raw("LevelReq: 10"))
		assert.are.equals(10, item.requirements.level)
	end)

	it("Prefix/Suffix", function()
		local item = new("Item", raw([[
			Prefix: {range:0.1}IncreasedLife1
			Suffix: {range:0.2}ColdResist1
			]]))
		assert.are.equals("IncreasedLife1", item.prefixes[1].modId)
		assert.are.equals(0.1, item.prefixes[1].range)
		assert.are.equals("ColdResist1", item.suffixes[1].modId)
		assert.are.equals(0.2, item.suffixes[1].range)
	end)

	it("Implicits", function()
		local item = new("Item", raw([[
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
		local item = new("Item", [[
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
		assert.are.equals(1, #item.grantedSkills)
		assert.are.equals("SpearThrowPlayer", item.grantedSkills[1].skillId)
		assert.are.equals("Adds 39 to 62 Fire Damage", item.explicitModLines[1].line)

		assert.are.equals("Grants Skill: Level (1-20) Volatile Dead", data.itemBases["Volatile Wand"].implicit)

		item = new("Item", [[
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
		local item = new("Item")
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
		local item = new("Item", [[
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
		local item = new("Item", [[
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
		local item = new("Item", [[
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
		local item = new("Item", raw("Source: No longer obtainable"))
		assert.are.equals("No longer obtainable", item.source)
	end)

	it("Note", function()
		local item = new("Item", raw("Note: ~price 1 chaos"))
		assert.are.equals("~price 1 chaos", item.note)
	end)

	it("Attribute Requirements", function()
		local item = new("Item", raw("Dex: 100"))
		assert.are.equals(100, item.requirements.dex)
		item = new("Item", raw("Int: 101"))
		assert.are.equals(101, item.requirements.int)
		item = new("Item", raw("Str: 102"))
		assert.are.equals(102, item.requirements.str)
	end)

	it("Requires Class", function()
		local item = new("Item", raw("Requires Class Witch"))
		assert.are.equals("Witch", item.classRestriction)
		item = new("Item", raw("Class:: Witch"))
		assert.are.equals("Witch", item.classRestriction)
	end)

	--TODO: POB2 class locked variants?
	--it("Requires Class variant", function()
	--end)

	it("short flags", function()
		item = new("Item", raw("Mirrored"))
		assert.truthy(item.mirrored)
		item = new("Item", raw("Corrupted"))
		assert.truthy(item.corrupted)
		item = new("Item", raw("Leech 6.61% of Physical Attack Damage as Mana (fractured)"))
		assert.truthy(item.fractured)
		item = new("Item", raw("Adds 36 to 48 Fire Damage (desecrated)"))
		assert.truthy(item.desecrated)
		item = new("Item", raw("Crafted: true"))
		assert.truthy(item.crafted)
		item = new("Item", raw("Unreleased: true"))
		assert.truthy(item.unreleased)
	end)

	it("long flags", function()
		local item = new("Item", raw("This item can be anointed by Cassia"))
		assert.truthy(item.canBeAnointed)
		item = new("Item", raw("Can have 1 additional Instilled Modifier"))
		assert.truthy(item.canHaveTwoEnchants)
		item = new("Item", raw("Can have an additional Instilled Modifier"))
		assert.truthy(item.canHaveTwoEnchants)
		item = new("Item", raw("Can have 2 additional Instilled Modifiers"))
		assert.truthy(item.canHaveTwoEnchants)
		assert.truthy(item.canHaveThreeEnchants)
		item = new("Item", raw("Can have 3 additional Instilled Modifiers"))
		assert.truthy(item.canHaveTwoEnchants)
		assert.truthy(item.canHaveThreeEnchants)
		assert.truthy(item.canHaveFourEnchants)
	end)
	
	it("tags", function()
		local item = new("Item", raw("{tags:life,physical_damage}+8 to Strength"))
		assert.are.same({ "life", "physical_damage" }, item.explicitModLines[1].modTags)
	end)

	it("range", function()
		local item = new("Item", raw("{range:0.8}+(8-12) to Strength"))
		assert.are.equals(0.8, item.explicitModLines[1].range)
		assert.are.equals(11, item.baseModList[1].value) -- range 0.8 of (8-12) = 11
	end)

	it("custom", function()
		local item = new("Item", raw("{custom}+8 to Strength"))
		assert.truthy(item.explicitModLines[1].custom)
	end)

	it("crafted", function()
		local item = new("Item", raw("{crafted}+8 to Strength"))
		assert.truthy(item.explicitModLines[1].crafted)
	end)

	it("preserves crafted mod lines when rebuilding raw text", function()
		local item = new("Item", raw("+8 to Strength"))
		item.explicitModLines[1].crafted = true
		item:BuildAndParseRaw()
		assert.truthy(item.explicitModLines[1].crafted)
	end)

	it("enchant", function()
		local item = new("Item", raw("+8 to Strength (enchant)"))
		assert.are.equals(1, #item.enchantModLines)
		-- enchant also sets enchant and implicit
		assert.truthy(item.enchantModLines[1].enchant)
		assert.truthy(item.enchantModLines[1].implicit)
	end)
	
	it("fractured", function()
		local item = new("Item", raw("{fractured}+8 to Strength"))
		assert.truthy(item.explicitModLines[1].fractured)
		item = new("Item", raw("+8 to Strength (fractured)"))
		assert.truthy(item.explicitModLines[1].fractured)
	end)

	it("implicit", function()
		local item = new("Item", raw("+8 to Strength (implicit)"))
		assert.truthy(item.implicitModLines[1].implicit)
	end)

	--TODO: POB2 multi-base items
	--it("multiple bases", function()
	--end)

	it("parses text without armour value then changes quality and has correct final armour", function()
		local item = new("Item", [[
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
		local item = new("Item", [[
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
		local item = new("Item", [[
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
		local item = new("Item", [[
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
		assert.are.equals(1, item.runeModLines[1].runeCount)
		assert.are.equals(1, item.runeModLines[2].runeCount)
		assert.is_nil(item.runeModLines[3].runeCount)
		assert.is_nil(item.runeModLines[4].runeCount)
		for _, rune in ipairs(item.runes) do
			assert.are_not.equals("Lesser Glacial Rune", rune)
		end
	end)

	it("keeps bonded rune stats separate from normal rune stats", function()
		local item = new("Item", [[
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
	end)

	it("applies increased effect of socketed runes", function()
		local item = new("Item", [[
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

	it("does not double-scale imported socketed rune text", function()
		local item = new("Item", [[
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
		local item = new("Item", [[
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

		local damageGainAsLightning = 0
		for _, mod in ipairs(item.slotModList[1]) do
			if mod.name == "DamageGainAsLightning" and mod.type == "BASE" then
				damageGainAsLightning = damageGainAsLightning + mod.value
			end
		end
		assert.are.equals(120, damageGainAsLightning)

		item:BuildAndParseRaw()

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
	end)

	it("multi-line rune mod", function()
		-- Thruldana is Bow-only as well
		local item = new("Item", [[
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

	it("jewel sockets", function()
		local item = new("Item", [[
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
		local item = new("Item", raw([[
			{ Prefix Modifier "Azure" (Tier: 7) - Mana }
			+31(25-34) to maximum Mana
		]], "Refined Bracers"))
		assert.are.equals("IncreasedMana3", item.prefixes[1].modId)
		assert.are.equals(0.667, item.prefixes[1].range)
		assert.are.equals("mana", item.explicitModLines[1].modTags[1])
	end)

	it("parses correct range", function()
		local item = new("Item", raw([[
			{ Desecrated Prefix Modifier "Frigid" (Tier: 6) - Damage, Elemental, Cold, Attack }
			Adds 8(7-8) to 13(12-14) Cold damage to Attacks
		]], "Refined Bracers"))
		assert.are.equals("Adds 8 to 13 Cold damage to Attacks", item.explicitModLines[1].line)
	end)

	-- GGG scales each mod line separately here, but PoB scales them both together, so this parsing is a bit wonky
	it("parses multi-line mod", function()
		local item = new("Item", raw([[
			{ Prefix Modifier "Bishop's" (Tier: 3) — Life, Defences }
			27(27-32)% increased Energy Shield
			+31(26-32) to maximum Life
		]], "Ancestral Tiara"))
		assert.are.equals("LocalIncreasedEnergyShieldAndLife4", item.prefixes[1].modId)
		assert.are.equals(0, item.prefixes[1].range)
		assert.are.equals(0.833, item.explicitModLines[2].range)
	end)

	it("resets linePrefix", function() 
		local item = new("Item", raw([[
			{ Prefix Modifier "Warlock's" (Tier: 4) — Mana, Damage, Caster }
			32(30-37)% increased Spell Damage
			+46(42-47) to maximum Mana
			--------
			+15 to maximum life
		]], "Voltaic Staff"))
		assert.are_not.equals("mana", item.explicitModLines[3].modTags[1])
	end)

	it("resets linePostfix", function() 
		local item = new("Item", raw([[
			{ Corruption Enhancement — Mana }
			24(20-30)% increased Mana Regeneration Rate
			--------
			+15 to maximum life
		]]))
		assert.falsy(item.explicitModLines[1].enchant)
	end)

	it("parses vaaled catalyst", function() 
		local item = new("Item", raw([[
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
		local item = new("Item", raw([[
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
		local item = new("Item", raw([[
			Quality (Life and Mana Modifiers): +20% (augmented)
			{ Unique Modifier — Life, Defences, Energy Shield, Minion, Gem }
			Socketed Golem Skills gain 20% of Maximum Life as Extra Maximum Energy Shield — Unscalable Value
		]]))
		assert.are.equals(20, item.baseModList[1].value.mod.value)
	end)

	it("correctly matches conqueror mod", function()
		local item = new("Item", raw([[
			{ Suffix Modifier "of the Conquest" (Tier: 1) — Elemental, Cold }
			10(8-10)% chance to Avoid Cold Damage from Hits
			(No chance to avoid damage can be higher than 75%)
			Warlord Item
		]]))
		assert.are.equals(10, item.baseModList[1].value)
		-- assert.are.equals(1, item.explicitModLines[1].range) -- Not sure why this is returning 0.5
	end)

	it("parses enchant correctly #enchant", function()
		local item = new("Item", raw([[
			{ Corrupted Enhancement }
			+8(6-10)% to Fire Resistance
		]]))
		assert.are.equals(8, item.enchantModLines[1].modList[1].value)
	end)

	it("parses enchant with tags correctly #enchant", function()
		local item = new("Item", raw([[
			{ Corrupted Enhancement - Energy Shield }
			+8(6-10)% to Fire Resistance
		]]))
		assert.are.equals(8, item.enchantModLines[1].modList[1].value)
		assert.are.equals("energyshield", item.enchantModLines[1].modTags[1])
	end)

	it("parses junk", function()
		local godTestItem = new("Item", [[
			Item Class: Sceptres
			Rarity: Unique
			Nebulis
			Synthesised Void Sceptre
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
end)
