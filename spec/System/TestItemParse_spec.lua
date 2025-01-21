describe("TestItemParse", function()
	local function raw(s, base)
		base = base or "Arcane Robe"
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
		item = new("Item", raw("Crafted: true"))
		assert.truthy(item.crafted)
		item = new("Item", raw("Unreleased: true"))
		assert.truthy(item.unreleased)
	end)

	--TODO: Add long flags applicable for POE2
	--it("long flags", function()
	--end)
	
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

	it("enchant", function()
		local item = new("Item", raw("+8 to Strength (enchant)"))
		assert.are.equals(1, #item.enchantModLines)
		-- enchant also sets enchant and implicit
		assert.truthy(item.enchantModLines[1].enchant)
		assert.truthy(item.enchantModLines[1].implicit)
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
end)
