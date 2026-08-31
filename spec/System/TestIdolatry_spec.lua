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
	it("parses Idolatry and bonded-idol stat lines", function()
		local parseMod = LoadModule("Modules/ModParser")

		-- Helper to find the Multiplier tag on a mod (tags are stored as array entries)
		local function multiplierTag(mod)
			for _, tag in ipairs(mod) do
				if tag.type == "Multiplier" then return tag end
			end
		end

		-- 1) Companion damage scales by the player's Idol count (read via actor = "player"
		-- since the mod is evaluated in the companion's own modDB).
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
		assert.are.equals("player", companionTag.actor)

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

		-- 4) Fox Idol's unlock is an item-local flag, not a global condition.
		local localUnlock = parseMod("Idols socketed in this item gain the benefits of their Bonded modifiers")
		assert.are.equals(1, #localUnlock)
		assert.are.equals("SocketedIdolsUseBondedModifiers", localUnlock[1].name)
		assert.are.equals("FLAG", localUnlock[1].type)

		-- 5) The ascendancy unlock is a flag consumed by calc setup, not a condition on each bonded mod.
		local globalUnlock = parseMod("Gain the benefits of Bonded modifiers on Runes and Idols")
		assert.are.equals(1, #globalUnlock)
		assert.are.equals("CanUseBonded", globalUnlock[1].name)
		assert.are.equals("FLAG", globalUnlock[1].type)

		-- Bonded is no longer consumed as a parser prefix, so other prefixes still apply.
		local minionMod, extra = parseMod("Minions have 30% increased Area of Effect")
		assert.is_nil(extra)
		assert.are.equals("MinionModifier", minionMod[1].name)
	end)

	it("enables only Idol Bonded modifiers from Fox Idol locally", function()
		local item = new("Item"):Item([[
			Test Body
			Rusted Cuirass
		]])
		item.itemSocketCount = 2
		item.runes = { "Fox Idol", "Lesser Body Rune" }
		item:UpdateRunes()
		item:BuildAndParseRaw()
		assert.is_true(item.socketedIdolsUseBondedModifiers)

		local foxBondedLine
		local bodyRuneBondedLife
		for _, modLine in ipairs(item.runeModLines) do
			if modLine.line == "Bonded: +5% to Quality of all Skills" then
				foxBondedLine = modLine
			end
			if modLine.line == "Bonded: +20 to maximum Life" then
				bodyRuneBondedLife = modLine
			end
		end
		assert.is_not_nil(foxBondedLine)
		assert.are.equals("GemProperty", foxBondedLine.modList[1].name)
		assert.is_not_nil(bodyRuneBondedLife)
		assert.are.equals("Life", bodyRuneBondedLife.modList[1].name)

		build.itemsTab:AddItem(item)
		build.buildFlag = true
		runCallback("OnFrame")

		local modDB = build.calcsTab.mainEnv.itemModDB
		local foxBondedQuality
		for _, mod in ipairs(modDB.mods.GemProperty or { }) do
			if mod.value.value == 5 and mod.source == item.modSource then
				foxBondedQuality = mod
				break
			end
		end
		assert.is_not_nil(foxBondedQuality)
		assert.is_not_nil(foxBondedLine.bondedModList)

		for _, mod in ipairs(modDB.mods.Life or { }) do
			assert.is_false(mod.type == "BASE" and mod.value == 20 and mod.source == item.modSource)
		end
	end)

	it("does not enable disabled Bonded modifiers", function()
		local item = new("Item"):Item([[
			Test Body
			Rusted Cuirass
		]])
		item.itemSocketCount = 1
		item.runes = { "Lesser Body Rune" }
		item:UpdateRunes()
		for _, modLine in ipairs(item.runeModLines) do
			if modLine.line == "Bonded: +20 to maximum Life" then
				modLine.disabled = true
			end
		end
		item:BuildModList()
		for _, mod in ipairs(item:GetActiveModListForSlotNum(nil, true)) do
			assert.is_false(mod.name == "Life" and mod.type == "BASE" and mod.value == 20)
		end
	end)

	it("processes active Bonded modifiers through local item calculations", function()
		local item = new("Item"):Item([[
			Test Mace
			Marauding Mace
		]])
		item.itemSocketCount = 1
		item.runes = { "Legacy of Brynhand's Mark" }
		item:UpdateRunes()
		item:BuildModList()
		local physicalMin = item.weaponData[1].PhysicalMin
		local physicalMax = item.weaponData[1].PhysicalMax

		item:GetActiveModListForSlotNum(1, true)

		assert.are.equals(physicalMin + 14, item.weaponData[1].PhysicalMin)
		assert.are.equals(physicalMax + 20, item.weaponData[1].PhysicalMax)

		item:GetActiveModListForSlotNum(1, false)
		assert.are.equals(physicalMin, item.weaponData[1].PhysicalMin)
		assert.are.equals(physicalMax, item.weaponData[1].PhysicalMax)
	end)

	it("enables and scales Bonded modifiers from the ascendancy flag", function()
		build.spec:SelectClass(build.spec.tree.classNameMap.Druid)
		for ascendClassId, ascendClass in pairs(build.spec.curClass.classes) do
			if ascendClass.name == "Shaman" then
				build.spec:SelectAscendClass(ascendClassId)
				break
			end
		end
		local wisdomOfTheMaji = build.spec.nodes[42253]
		wisdomOfTheMaji.alloc = true
		build.spec.allocNodes[wisdomOfTheMaji.id] = wisdomOfTheMaji
		build.buildFlag = true
		runCallback("OnFrame")
		local baseModDB = build.calcsTab.mainEnv.modDB
		local baseLife = baseModDB:Sum("BASE", nil, "Life")
		local baseMana = baseModDB:Sum("BASE", nil, "Mana")

		local item = new("Item"):Item([[
			Test Body
			Rusted Cuirass
			200% increased effect of Socketed Runes
		]])
		item.itemSocketCount = 1
		item.runes = { "Lesser Body Rune" }
		item:UpdateRunes()
		item:BuildAndParseRaw()
		build.itemsTab:AddItem(item)
		build.itemsTab:EquipItemInSet(item, build.itemsTab.activeItemSetId)
		build.buildFlag = true
		runCallback("OnFrame")

		local modDB = build.calcsTab.mainEnv.modDB
		assert.are.equals(150, modDB:Sum("BASE", nil, "Life") - baseLife)
		assert.are.equals(60, modDB:Sum("BASE", nil, "Mana") - baseMana)
	end)
end)
