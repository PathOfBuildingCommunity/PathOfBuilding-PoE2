describe("TestIdolatry", function()
	before_each(function()
		newBuild()
	end)

	-- The Spirit Walker "Idolatry" notable grants three mods that scale with the
	-- number of Idols / non-Idol augments (Runes + Soul Cores) socketed across equipped items.

	-- Counting: CalcSetup tallies socketed augments by type into the IdolsInEquipment and
	-- NonIdolAugmentsInEquipment multipliers, which the three Idolatry mods scale against.
	it("counts Idols and non-Idol augments across equipped items", function()
		-- Gloves with 2 Idols socketed
		build.itemsTab:CreateDisplayItemFromRaw([[
			Rarity: MAGIC
			Idolatry Test Gloves
			Vaal Gloves
			Sockets: S S
			Rune: Idol of Sirrius
			Rune: Idol of Sirrius
			Implicits: 0
		]])
		build.itemsTab:AddDisplayItem()

		-- Quarterstaff with 3 Soul Cores socketed (non-Idol augments)
		build.itemsTab:CreateDisplayItemFromRaw([[
			Rarity: MAGIC
			Idolatry Test Staff
			Aegis Quarterstaff
			Sockets: S S S
			Rune: Soul Core of Cholotl
			Rune: Soul Core of Zantipi
			Rune: Soul Core of Atmohua
			Implicits: 0
		]])
		build.itemsTab:AddDisplayItem()
		runCallback("OnFrame")

		local modDB = build.calcsTab.mainEnv.modDB
		assert.are.equals(2, modDB.multipliers.IdolsInEquipment)
		assert.are.equals(3, modDB.multipliers.NonIdolAugmentsInEquipment)
	end)

	-- Empty sockets (itemSocketCount populated while item.runes has no entry for the slot, e.g. a
	-- freshly created base item) must not be counted as augments.
	it("does not count empty sockets as augments", function()
		build.itemsTab:CreateDisplayItemFromRaw([[
			Rarity: MAGIC
			Empty Socket Test Gloves
			Vaal Gloves
			Sockets: S S
			Implicits: 0
		]])
		build.itemsTab:AddDisplayItem()
		runCallback("OnFrame")

		local modDB = build.calcsTab.mainEnv.modDB
		assert.is_nil(modDB.multipliers.IdolsInEquipment)
		assert.is_nil(modDB.multipliers.NonIdolAugmentsInEquipment)
	end)

	-- Parsing: the three stat lines must resolve to mods that scale against those multipliers.
	it("parses the three Idolatry stat lines", function()
		local parseMod = LoadModule("Modules/ModParser")

		-- Helper to find the Multiplier tag on a mod (tags are stored as array entries)
		local function multiplierTag(mod)
			for _, tag in ipairs(mod) do
				if tag.type == "Multiplier" then return tag end
			end
		end

		-- 1) Companion damage scales by the player's (parent's) Idol count.
		local companion = parseMod("Companions deal 10% increased damage per Idol in your Equipment")
		assert.are.equals(1, #companion)
		assert.are.equals("MinionModifier", companion[1].name)
		local inner = companion[1].value.mod
		assert.are.equals("Damage", inner.name)
		assert.are.equals("INC", inner.type)
		assert.are.equals(10, inner.value)
		local companionTag = multiplierTag(inner)
		assert.is_not_nil(companionTag)
		assert.are.equals("IdolsInEquipment", companionTag.var)
		assert.are.equals("parent", companionTag.actor)

		-- 2) Reservation Efficiency scales by the Idol count (player context).
		local reservation = parseMod("2% increased Reservation Efficiency of Skills per Idol in your Equipment")
		assert.are.equals(1, #reservation)
		assert.are.equals("ReservationEfficiency", reservation[1].name)
		assert.are.equals("INC", reservation[1].type)
		assert.are.equals(2, reservation[1].value)
		assert.are.equals("IdolsInEquipment", multiplierTag(reservation[1]).var)

		-- 3) Elemental Resistance penalty scales by the non-Idol augment count (player context).
		local resist = parseMod("-4% to all Elemental Resistances per non-Idol Augment in your Equipment")
		assert.are.equals(1, #resist)
		assert.are.equals("ElementalResist", resist[1].name)
		assert.are.equals("BASE", resist[1].type)
		assert.are.equals(-4, resist[1].value)
		assert.are.equals("NonIdolAugmentsInEquipment", multiplierTag(resist[1]).var)
	end)
end)
