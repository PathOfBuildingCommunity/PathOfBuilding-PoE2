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
end)
