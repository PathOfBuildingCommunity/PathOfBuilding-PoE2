describe("TestImportReimport", function()
	local DEFAULT_CHARACTER_LEVEL = 12
	local DEFAULT_ITEM_LEVEL = 10
	local TEST_IMPORT_ITEM_ID = "test-import-item-1"

	before_each(function()
		newBuild()
	end)

	local function makeGemProperties(level)
		return {
			{ name = "Level", values = { { tostring(level), 0 } } },
			{ name = "Quality", values = { { "+0%", 0 } } },
		}
	end

	local function makeGemEntry(support, typeLine, level, socketedItems)
		return {
			support = support,
			typeLine = typeLine,
			properties = makeGemProperties(level),
			socketedItems = socketedItems,
		}
	end

	-- Build a minimal import item so the tests stay focused on state, not fixture noise.
	local function makeImportItem(itemTypeLine, inventoryId, itemId)
		return {
			id = itemId or TEST_IMPORT_ITEM_ID,
			frameType = 0,
			name = "",
			typeLine = itemTypeLine,
			inventoryId = inventoryId,
			ilvl = DEFAULT_ITEM_LEVEL,
			properties = {},
		}
	end

	-- Build a minimal import payload so the tests stay focused on state, not fixture noise.
	local function buildImportPayload(items, skills)
		return {
			level = DEFAULT_CHARACTER_LEVEL,
			equipment = items,
			skills = skills,
		}
	end

	local function reimportSkillsWithOptions(itemTypeLine, inventoryId, skills, clearItems)
		build.importTab.controls.charImportItemsClearSkills.state = true
		build.importTab.controls.charImportItemsClearItems.state = clearItems
		build.importTab:ImportItemsAndSkills(buildImportPayload({
			makeImportItem(itemTypeLine, inventoryId),
		}, skills))
		runCallback("OnFrame")
	end

	local function reimportSingleGemWithOptions(itemTypeLine, inventoryId, gemName, clearItems)
		reimportSkillsWithOptions(itemTypeLine, inventoryId, {
			makeGemEntry(false, gemName, 20),
		}, clearItems)
	end

	local function reimportSingleGem(itemTypeLine, inventoryId, gemName)
		reimportSingleGemWithOptions(itemTypeLine, inventoryId, gemName, false)
	end

	local function assertReimportPreservesSkillSubstate(itemTypeLine, inventoryId, gemName, fieldName, fieldValue)
		build.skillsTab:PasteSocketGroup(string.format([[
%s 20/0  1
]], gemName))
		runCallback("OnFrame")

		local socketGroup = build.skillsTab.socketGroupList[1]
		local srcInstance = socketGroup.displaySkillList[1].activeEffect.srcInstance
		srcInstance[fieldName] = fieldValue
		srcInstance[fieldName.."Calcs"] = fieldValue
		build.modFlag = true
		build.buildFlag = true
		runCallback("OnFrame")

		reimportSingleGem(itemTypeLine, inventoryId, gemName)

		socketGroup = build.skillsTab.socketGroupList[1]
		srcInstance = socketGroup.displaySkillList[1].activeEffect.srcInstance
		assert.are.equal(fieldValue, srcInstance[fieldName])
		assert.are.equal(fieldValue, srcInstance[fieldName.."Calcs"])
	end

	it("preserves full DPS state and manually disabled gems when reimporting items and skills", function()
		build.skillsTab:PasteSocketGroup([[
Slot: Gloves
Dark Effigy 1/0  1
Controlled Destruction 1/0 DISABLED 1
]])
		runCallback("OnFrame")

		local socketGroup = build.skillsTab.socketGroupList[1]
		socketGroup.includeInFullDPS = true
		socketGroup.mainActiveSkill = 2
		runCallback("OnFrame")

		build.importTab.controls.charImportItemsClearSkills.state = true
		build.importTab.controls.charImportItemsClearItems.state = false
		build.importTab:ImportItemsAndSkills(buildImportPayload({
			makeImportItem("Wrapped Cap", "Helm"),
		}, {
			makeGemEntry(false, "Dark Effigy", 2, {
				makeGemEntry(true, "Controlled Destruction", 1),
			}),
		}))
		runCallback("OnFrame")

		socketGroup = build.skillsTab.socketGroupList[1]
		assert.is_true(socketGroup.includeInFullDPS)
		assert.are.equal(2, socketGroup.mainActiveSkill)
		assert.are.equal(2, socketGroup.gemList[1].level)
		assert.is_false(socketGroup.gemList[2].enabled)
	end)

	it("preserves full DPS state and disabled gems when reimporting with deleted equipment", function()
		build.skillsTab:PasteSocketGroup([[
Dark Effigy 1/0  1
Controlled Destruction 1/0 DISABLED 1
]])
		runCallback("OnFrame")

		local socketGroup = build.skillsTab.socketGroupList[1]
		socketGroup.includeInFullDPS = true
		socketGroup.mainActiveSkill = 2
		runCallback("OnFrame")

		reimportSkillsWithOptions("Wrapped Cap", "Helm", {
			makeGemEntry(false, "Dark Effigy", 2, {
				makeGemEntry(true, "Controlled Destruction", 1),
			}),
		}, true)

		socketGroup = build.skillsTab.socketGroupList[1]
		assert.is_true(socketGroup.includeInFullDPS)
		assert.are.equal(2, socketGroup.mainActiveSkill)
		assert.are.equal(2, socketGroup.gemList[1].level)
		assert.is_false(socketGroup.gemList[2].enabled)
	end)

	it("preserves two socket groups when reimporting items and skills", function()
		build.skillsTab:PasteSocketGroup([[
Dark Effigy 1/0  1
Controlled Destruction 1/0 DISABLED 1
]])
		runCallback("OnFrame")

		build.skillsTab:PasteSocketGroup([[
Fireball 20/0  1
]])
		runCallback("OnFrame")

		local darkEffigyGroup = build.skillsTab.socketGroupList[1]
		darkEffigyGroup.includeInFullDPS = true
		darkEffigyGroup.mainActiveSkill = 2
		local fireballGroup = build.skillsTab.socketGroupList[2]
		fireballGroup.enabled = false
		runCallback("OnFrame")

		build.importTab.controls.charImportItemsClearSkills.state = true
		build.importTab.controls.charImportItemsClearItems.state = false
		build.importTab:ImportItemsAndSkills(buildImportPayload({
			makeImportItem("Wrapped Cap", "Helm", "test-import-item-helmet"),
			makeImportItem("Linen Wraps", "Gloves", "test-import-item-gloves"),
		}, {
			makeGemEntry(false, "Dark Effigy", 1, {
				makeGemEntry(true, "Controlled Destruction", 1),
			}),
			makeGemEntry(false, "Fireball", 20),
		}))
		runCallback("OnFrame")

		local groupsByGem = {}
		for _, socketGroup in ipairs(build.skillsTab.socketGroupList) do
			groupsByGem[socketGroup.gemList[1].nameSpec] = socketGroup
		end

		assert.are.equal(2, #build.skillsTab.socketGroupList)
		assert.is_not_nil(groupsByGem["Dark Effigy"])
		assert.is_not_nil(groupsByGem.Fireball)
		assert.is_true(groupsByGem["Dark Effigy"].includeInFullDPS)
		assert.are.equal(2, groupsByGem["Dark Effigy"].mainActiveSkill)
		assert.is_false(groupsByGem.Fireball.enabled)
	end)

	it("clears the stale socket group selection when reimporting skills", function()
		build.skillsTab:PasteSocketGroup([[
Fireball 20/0  1
]])
		runCallback("OnFrame")

		local oldSocketGroup = build.skillsTab.socketGroupList[1]
		assert.are.equal(oldSocketGroup, build.skillsTab.displayGroup)
		assert.are.equal(oldSocketGroup, build.skillsTab.controls.groupList.selValue)

		reimportSingleGem("Linen Wraps", "Gloves", "Dark Effigy")

		assert.is_nil(build.skillsTab.displayGroup)
		assert.is_nil(build.skillsTab.controls.groupList.selIndex)
		assert.is_nil(build.skillsTab.controls.groupList.selValue)
		assert.are_not.equal(oldSocketGroup, build.skillsTab.socketGroupList[1])
	end)

	it("imports item socketed jewels using jewel socket order instead of raw socket index", function()
		build.importTab.controls.charImportItemsClearItems.state = true
		build.importTab.controls.charImportItemsClearSkills.state = true

		local gloves = makeImportItem("Linen Wraps", "Gloves", "test-import-gloves")
		gloves.sockets = {
			{ type = "rune" },
			{ type = "jewel" },
		}
		gloves.socketedItems = {
			{ baseType = "Greater Rune of Nobility" },
			{
				id = "test-import-jewel",
				frameType = 2,
				name = "Vivid Ornament",
				typeLine = "Sapphire",
				baseType = "Sapphire",
				inventoryId = "PassiveJewels",
				ilvl = DEFAULT_ITEM_LEVEL,
				properties = {},
				socket = 1,
			},
		}

		build.importTab:ImportItemsAndSkills(buildImportPayload({ gloves }, {}))
		runCallback("OnFrame")

		local socketedJewel = build.itemsTab.items[build.itemsTab.slots["Gloves Jewel Socket 1"].selItemId]
		assert.is_not_nil(socketedJewel)
		assert.are.equal("test-import-jewel", socketedJewel.uniqueID)
		assert.are.equal(0, build.itemsTab.slots["Gloves Jewel Socket 2"].selItemId)
	end)

	it("keeps an imported shield equipped with Bringer of Rain and a two-handed mace", function()
		build.importTab.controls.charImportItemsClearItems.state = true
		build.importTab.controls.charImportItemsClearSkills.state = true

		local shield = makeImportItem("Glacial Fortress", "Offhand2", "test-import-shield")
		local weapon = makeImportItem("Ironwood Greathammer", "Weapon2", "test-import-two-handed-mace")
		local helmet = makeImportItem("Decorated Helm", "Helm", "test-import-bringer-of-rain")
		helmet.frameType = 3
		helmet.name = "The Bringer of Rain"
		helmet.explicitMods = {
			"You can wield Two-Handed Axes, Maces and Swords in one hand",
		}
		local maceStrike = makeGemEntry(false, "Mace Strike", 20)
		maceStrike.weaponRequirements = {
			{ name = "", values = { { "[Mace|Two Hand Mace]", 0 } } },
		}

		build.importTab:ImportItemsAndSkills(buildImportPayload({ shield, weapon, helmet }, { maceStrike }))

		assert.are_not.equal(0, build.itemsTab.slots["Weapon 1 Swap"].selItemId)
		assert.are_not.equal(0, build.itemsTab.slots["Weapon 2 Swap"].selItemId)
		assert.are.equal("Metadata/Items/Gems/SkillGemPlayerDefault2HMace", build.skillsTab.socketGroupList[1].gemList[1].gemId)
	end)

	it("uses unique database and rune levels when importing unique items from account data", function()
		while main.uniqueDB.loading do
			runCallback("OnFrame")
		end

		build.importTab.controls.charImportItemsClearItems.state = true
		build.importTab.controls.charImportItemsClearSkills.state = true

		local body = makeImportItem("Rusted Cuirass", "BodyArmour", "test-import-bramblejack")
		body.frameType = 3
		body.name = "Bramblejack"
		body.requirements = {
			{ name = "Level", values = { { "22", 0 } } },
		}
		build.importTab:ImportItemsAndSkills(buildImportPayload({ body }, {}))
		runCallback("OnFrame")

		local importedItem = build.itemsTab.items[build.itemsTab.slots["Body Armour"].selItemId]
		assert.are.equal("Bramblejack, Rusted Cuirass", importedItem.name)
		assert.are.equal(0, importedItem.requirements.level)

		body.sockets = {
			{ type = "rune" },
		}
		body.socketedItems = {
			{ baseType = "Legacy of Blackbraid" },
		}

		build.importTab:ImportItemsAndSkills(buildImportPayload({ body }, {}))
		runCallback("OnFrame")

		importedItem = build.itemsTab.items[build.itemsTab.slots["Body Armour"].selItemId]
		assert.are.equal(65, importedItem.requirements.level)

		importedItem.runes[1] = "None"
		importedItem:UpdateRunes()
		importedItem:BuildAndParseRaw()
		assert.are.equal(0, importedItem.requirements.level)

		local weapon = makeImportItem("Runemastered Ironhead Spear", "Weapon", "test-import-tyranny's-grip")
		weapon.frameType = 3
		weapon.name = "Tyranny's Grip"
		weapon.sockets = {
			{ type = "rune" },
		}
		weapon.socketedItems = {
			{ baseType = "Legacy of Tyranny's Grip" },
		}

		build.importTab:ImportItemsAndSkills(buildImportPayload({ weapon }, {}))
		runCallback("OnFrame")

		importedItem = build.itemsTab.items[build.itemsTab.slots["Weapon 1"].selItemId]
		assert.are.equal(65, importedItem.requirements.level)

		importedItem.runes[1] = "None"
		importedItem:UpdateRunes()
		importedItem:BuildAndParseRaw()
		assert.are.equal(55, importedItem.requirements.level)
	end)

	it("imports scaled Darkness Enthroned augments from account data without rescaling them", function()
		build.importTab.controls.charImportItemsClearItems.state = true
		build.importTab.controls.charImportItemsClearSkills.state = true

		local belt = makeImportItem("Fine Belt", "Belt", "test-import-darkness-enthroned")
		belt.frameType = 3
		belt.name = "Darkness Enthroned"
		belt.sockets = {
			{ type = "rune" },
			{ type = "rune" },
		}
		belt.socketedItems = {
			{ baseType = "Rune of the Blossom" },
			{ baseType = "Fox Idol" },
		}
		belt.runeMods = {
			"+83 to Spirit",
			"Idols socketed in this item gain the benefits of their Bonded modifiers",
			"-1 to Spirit per 2 Levels",
			"Bonded: +8% to Quality of all Skills",
		}
		belt.explicitMods = {
			"This item gains bonuses from Socketed Items as though it was a Body Armour",
			"66% increased effect of Socketed Augment Items",
		}

		build.importTab:ImportItemsAndSkills(buildImportPayload({ belt }, {}))
		runCallback("OnFrame")

		local importedItem = build.itemsTab.items[build.itemsTab.slots.Belt.selItemId]
		assert.are.same({ "Rune of the Blossom", "Fox Idol" }, importedItem.runes)
		local rawItem = importedItem:BuildRaw()
		assert.is_not_nil(rawItem:match("%+83 to Spirit"))
		assert.is_not_nil(rawItem:match("%-1 to Spirit per 2 Levels"))
		assert.is_not_nil(rawItem:match("Bonded: %+8%% to Quality of all Skills"))

		importedItem:BuildAndParseRaw()
		assert.are.same({ "Rune of the Blossom", "Fox Idol" }, importedItem.runes)
		rawItem = importedItem:BuildRaw()
		assert.is_not_nil(rawItem:match("%+83 to Spirit"))
		assert.is_not_nil(rawItem:match("Bonded: %+8%% to Quality of all Skills"))
	end)

	it("preserves skill part selection when reimporting items and skills", function()
		assertReimportPreservesSkillSubstate("Twig Focus", "Offhand", "Dark Effigy", "skillPart", 2)
	end)

	it("preserves stage count when reimporting items and skills", function()
		assertReimportPreservesSkillSubstate("Withered Wand", "Weapon", "Flameblast", "skillStageCount", 8)
	end)

	it("preserves minion skill when reimporting items and skills", function()
		assertReimportPreservesSkillSubstate("Linen Wraps", "Gloves", "Skeletal Sniper", "skillMinionSkill", 2)
	end)

	it("preserves minion skill stat set when reimporting items and skills", function()
		build.skillsTab:PasteSocketGroup([[
Skeletal Sniper 20/0  1
]])
		runCallback("OnFrame")

		local socketGroup = build.skillsTab.socketGroupList[1]
		local activeEffect = socketGroup.displaySkillList[1].activeEffect
		local grantedEffectId = activeEffect.grantedEffect.id
		local srcInstance = activeEffect.srcInstance
		srcInstance.skillMinionSkill = 2
		srcInstance.skillMinionSkillCalcs = 2
		srcInstance.skillMinionSkillStatSetIndexLookup = { [grantedEffectId] = { [2] = 3 } }
		srcInstance.skillMinionSkillStatSetIndexLookupCalcs = { [grantedEffectId] = { [2] = 2 } }

		reimportSingleGem("Linen Wraps", "Gloves", "Skeletal Sniper")

		socketGroup = build.skillsTab.socketGroupList[1]
		activeEffect = socketGroup.displaySkillList[1].activeEffect
		grantedEffectId = activeEffect.grantedEffect.id
		srcInstance = activeEffect.srcInstance
		assert.are.equal(2, srcInstance.skillMinionSkill)
		assert.are.equal(2, srcInstance.skillMinionSkillCalcs)
		assert.are.equal(3, srcInstance.skillMinionSkillStatSetIndexLookup[grantedEffectId][2])
		assert.are.equal(2, srcInstance.skillMinionSkillStatSetIndexLookupCalcs[grantedEffectId][2])
	end)

	it("preserves active skill stat set when reimporting items and skills", function()
		build.skillsTab:PasteSocketGroup([[
Fireball 20/0  1
]])
		runCallback("OnFrame")

		local socketGroup = build.skillsTab.socketGroupList[1]
		local activeEffect = socketGroup.displaySkillList[1].activeEffect
		local grantedEffectId = activeEffect.grantedEffect.id
		local srcInstance = activeEffect.srcInstance
		srcInstance.statSet = { [grantedEffectId] = 3 }
		srcInstance.statSetCalcs = { [grantedEffectId] = 2 }

		reimportSingleGem("Linen Wraps", "Gloves", "Fireball")

		socketGroup = build.skillsTab.socketGroupList[1]
		activeEffect = socketGroup.displaySkillList[1].activeEffect
		grantedEffectId = activeEffect.grantedEffect.id
		srcInstance = activeEffect.srcInstance
		assert.are.equal(3, srcInstance.statSet[grantedEffectId])
		assert.are.equal(2, srcInstance.statSetCalcs[grantedEffectId])
	end)
end)
