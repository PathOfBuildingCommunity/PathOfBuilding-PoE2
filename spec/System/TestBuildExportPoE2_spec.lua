local BuildExportPoE2 = require("Modules.BuildExportPoE2")

describe("PoE2 BuildPlanner export", function()
	local originalWriteFile
	local originalWriteAllLoadouts

	local function addRing(note)
		local item = new("Item"):Item([[Rarity: RARE
Export Ring
Gold Ring
Implicits: 0
+10 to maximum Life]])
		build.itemsTab:AddItem(item, true)
		local slot = build.itemsTab.activeItemSet["Ring 1"]
		slot.selItemId = item.id
		slot.note = note
		return item, slot
	end

	local function inventoryEntry(exported, slotName)
		local slotId = data.buildFileInventorySlotMap[slotName].id
		for _, entry in ipairs(exported.inventory_slots) do
			if entry.inventory_id == slotId then
				return entry
			end
		end
	end

	before_each(function()
		newBuild()
		originalWriteFile = BuildExportPoE2.WriteFile
		originalWriteAllLoadouts = BuildExportPoE2.WriteAllLoadouts
	end)

	after_each(function()
		BuildExportPoE2.WriteFile = originalWriteFile
		BuildExportPoE2.WriteAllLoadouts = originalWriteAllLoadouts
	end)

	it("uses game ids for active and support gems", function()
		local activeGem = {
			enabled = true,
			gemData = data.gems["Metadata/Items/Gems/SkillGemExplosiveGrenade"],
			level = 20,
			quality = 0,
		}
		local supportGem = {
			enabled = true,
			gemData = data.gems["Metadata/Items/Gems/SkillGemFocusedCurseSupport"],
			level = 1,
			quality = 0,
		}
		local skillSetId = 99
		build.skillsTab.skillSets[skillSetId] = {
			socketGroupList = { { enabled = true, mainActiveSkill = 1, gemList = { activeGem, supportGem } } },
		}

		local exported = BuildExportPoE2.BuildTable(build, {}, {
			specIndex = build.treeTab.activeSpec,
			skillSetId = skillSetId,
			itemSetId = build.itemsTab.activeItemSetId,
		})

		assert.are.equal(activeGem.gemData.gameId, exported.skills[1].id)
		assert.are.equal(supportGem.gemData.gameId, exported.skills[1].support_skills[1])
	end)

	it("resolves secondary active effects in inactive skill sets", function()
		local gem = {
			enabled = true,
			gemData = data.gems["Metadata/Items/Gems/SkillGemShatteringPalm"],
			level = 20,
			quality = 0,
		}
		local skillSetId = 99
		build.skillsTab.skillSets[skillSetId] = {
			socketGroupList = { { enabled = true, mainActiveSkill = 2, gemList = { gem } } },
		}

		local exported = BuildExportPoE2.BuildTable(build, {}, {
			specIndex = build.treeTab.activeSpec,
			skillSetId = skillSetId,
			itemSetId = build.itemsTab.activeItemSetId,
		})

		assert.are.equal(gem.gemData.gameId, exported.skills[1].id)
	end)

	it("uses placeholder values for empty build metadata fields", function()
		local importTab = build.importTab
		assert.are.equal("", importTab.controls.buildPlannerBuildName.buf)
		assert.are.equal("Build name", importTab.controls.buildPlannerBuildName.prompt)
		assert.are.equal("Unnamed Build", importTab.controls.buildPlannerBuildName.placeholder)
		assert.are.equal("", importTab.controls.buildPlannerAuthorName.buf)
		assert.are.equal("Author name", importTab.controls.buildPlannerAuthorName.prompt)
		assert.are.equal("Author", importTab.controls.buildPlannerAuthorName.placeholder)
		assert.are.same({ name = "Unnamed Build", author = "Author", description = "", useGeneratedItemText = true }, importTab:GetBuildPlannerMetadata())

		importTab.controls.buildPlannerBuildName:SetText("My Build", true)
		importTab.controls.buildPlannerAuthorName:SetText("My Author")
		assert.are.same({ name = "My Build", author = "My Author", description = "", useGeneratedItemText = true }, importTab:GetBuildPlannerMetadata())
		local treeVersion = build.treeTab.specList[importTab.exportSpecIndex].treeVersion:gsub("_", ".")
		assert.are.equal(BuildExportPoE2.DefaultDir() .. "My Build [" .. treeVersion .. "].build", importTab.controls.poe2ExportPath.buf)
	end)

	it("passes export options through the selected export button without serialising them", function()
		local importTab = build.importTab
		local selectedMetadata
		importTab.controls.poe2ExportPath:SetText("build-export-test.build")
		importTab.controls.buildPlannerUseGeneratedItemText.state = false
		BuildExportPoE2.WriteFile = function(_, path, metadata)
			selectedMetadata = metadata
			return path
		end

		importTab.controls.poe2ExportSave.onClick()

		assert.is_false(importTab:GetBuildPlannerMetadata().useGeneratedItemText)
		assert.is_false(selectedMetadata.useGeneratedItemText)
		local json = BuildExportPoE2.Export(build, selectedMetadata, {
			specIndex = build.treeTab.activeSpec,
			skillSetId = build.skillsTab.activeSkillSetId,
			itemSetId = build.itemsTab.activeItemSetId,
		})
		assert.is_nil(json:find("useGeneratedItemText", 1, true))
		while main.popups[1] do
			main:ClosePopup()
		end
	end)

	it("passes export options through the all-loadout export button", function()
		local importTab = build.importTab
		local allLoadoutsMetadata
		importTab.controls.poe2ExportPath:SetText("build-export-test.build")
		importTab.controls.buildPlannerUseGeneratedItemText.state = false
		BuildExportPoE2.WriteAllLoadouts = function(_, _, metadata)
			allLoadoutsMetadata = metadata
			return { }, { }
		end

		importTab.controls.poe2ExportSaveAll.onClick()

		assert.is_false(allLoadoutsMetadata.useGeneratedItemText)
		while main.popups[1] do
			main:ClosePopup()
		end
	end)

	it("forwards the export option to every loadout", function()
		local calls = { }
		BuildExportPoE2.WriteFile = function(_, path, metadata, selection)
			table.insert(calls, { metadata = metadata, selection = selection })
			return path
		end
		local selection = {
			specIndex = build.treeTab.activeSpec,
			skillSetId = build.skillsTab.activeSkillSetId,
			itemSetId = build.itemsTab.activeItemSetId,
		}
		local written, errors = BuildExportPoE2.WriteAllLoadouts(build, "build-export-test.build", {
			name = "Build",
			author = "Author",
			description = "",
			useGeneratedItemText = false,
		}, {
			{ name = "First", fileName = "First", specIndex = selection.specIndex, skillSetId = selection.skillSetId, itemSetId = selection.itemSetId },
			{ name = "Second", fileName = "Second", specIndex = selection.specIndex, skillSetId = selection.skillSetId, itemSetId = selection.itemSetId },
		})

		assert.are.equal(2, #written)
		assert.are.equal(0, #errors)
		assert.are.equal(2, #calls)
		for _, call in ipairs(calls) do
			assert.is_false(call.metadata.useGeneratedItemText)
			local json = BuildExportPoE2.Export(build, call.metadata, call.selection)
			assert.is_nil(json:find("useGeneratedItemText", 1, true))
		end
	end)

	it("keeps the tree version at the end of loadout filenames", function()
		assert.are.equal("Build [0.5].build", BuildExportPoE2.BuildPath("Build", "0_5", "Existing.build"))
		assert.are.equal("Build - Leveling [0.5].build", BuildExportPoE2.LoadoutPath("Build [0.4].build", "Leveling", "0_5"))
		assert.are.equal("Build [SSF] - Leveling [0.5].build", BuildExportPoE2.LoadoutPath("Build [SSF].build", "Leveling", "0_5"))
	end)

	it("hides the user profile from displayed paths", function()
		local path = BuildExportPoE2.DefaultDir() .. "Test.build"
		local sep = path:find("\\", 1, true) and "\\" or "/"
		local displayedPath = BuildExportPoE2.DisplayPath(path)

		assert.are.equal("..." .. sep .. "Path of Exile 2" .. sep .. "BuildPlanner" .. sep .. "Test.build", displayedPath)
	end)

	it("hides the full path by default", function()
		local importTab = build.importTab

		assert.is_false(importTab.controls.poe2ExportShowPath.state)
		assert.is_false(importTab.controls.poe2ExportPath.shown())
		assert.is_true(importTab.controls.poe2ExportPathDisplay.shown())
		importTab.controls.poe2ExportShowPath.state = true

		assert.is_true(importTab.controls.poe2ExportPath.shown())
		assert.is_false(importTab.controls.poe2ExportPathDisplay.shown())
	end)

	it("exports only the selected item variant", function()
		local item = new("Item"):Item([[Rarity: UNIQUE
Variant Test
Plate Belt
Variant: First
Variant: Second
Selected Variant: 2
Implicits: 0
{variant:1}+1 to Strength
{variant:2}+2 to Strength]])
		build.itemsTab:AddItem(item, true)
		build.itemsTab.activeItemSet.Belt.selItemId = item.id

		local exported = BuildExportPoE2.BuildTable(build, {}, {
			specIndex = build.treeTab.activeSpec,
			skillSetId = build.skillsTab.activeSkillSetId,
			itemSetId = build.itemsTab.activeItemSetId,
		})
		local beltEntry
		for _, entry in ipairs(exported.inventory_slots) do
			if entry.inventory_id == data.buildFileInventorySlotMap.Belt.id then
				beltEntry = entry
				break
			end
		end

		assert.is_not_nil(beltEntry)
		assert.matches("+2 to Strength", beltEntry.additional_text, nil, true)
		assert.is_nil(beltEntry.additional_text:find("+1 to Strength", 1, true))
	end)

	it("exports duplicate Mageblood variants", function()
		local magebloodRaw
		for _, raw in ipairs(data.uniques.belt) do
			if raw:find("Mageblood", 1, true) then
				magebloodRaw = raw
				break
			end
		end
		local item = new("Item"):Item("Rarity: UNIQUE\n" .. magebloodRaw)
		item.variantAlt = item.variant
		build.itemsTab:AddItem(item, true)
		build.itemsTab.activeItemSet.Belt.selItemId = item.id

		local exported = BuildExportPoE2.BuildTable(build, {}, {
			specIndex = build.treeTab.activeSpec,
			skillSetId = build.skillsTab.activeSkillSetId,
			itemSetId = build.itemsTab.activeItemSetId,
		})
		local beltEntry
		for _, entry in ipairs(exported.inventory_slots) do
			if entry.inventory_id == data.buildFileInventorySlotMap.Belt.id then
				beltEntry = entry
				break
			end
		end
		local _, count = beltEntry.additional_text:gsub("Legacy of Amethyst", "")

		assert.are.equal(2, count)
	end)

	it("exports generated item text for an equipped item with a nil note when enabled", function()
		local item = addRing(nil)
		local exported = BuildExportPoE2.BuildTable(build, { useGeneratedItemText = true }, {
			specIndex = build.treeTab.activeSpec,
			skillSetId = build.skillsTab.activeSkillSetId,
			itemSetId = build.itemsTab.activeItemSetId,
		})

		assert.are.equal(BuildExportPoE2.ItemAdditionalText(item), inventoryEntry(exported, "Ring 1").additional_text)
	end)

	it("does not export an empty item note when generated text is disabled", function()
		addRing("")
		local exported = BuildExportPoE2.BuildTable(build, { useGeneratedItemText = false }, {
			specIndex = build.treeTab.activeSpec,
			skillSetId = build.skillsTab.activeSkillSetId,
			itemSetId = build.itemsTab.activeItemSetId,
		})

		assert.is_nil(inventoryEntry(exported, "Ring 1"))
	end)

	it("uses a non-empty item note instead of generated text for either option", function()
		local item, slot = addRing("Only this note")
		for _, useGeneratedItemText in ipairs({ true, false }) do
			local exported = BuildExportPoE2.BuildTable(build, { useGeneratedItemText = useGeneratedItemText }, {
				specIndex = build.treeTab.activeSpec,
				skillSetId = build.skillsTab.activeSkillSetId,
				itemSetId = build.itemsTab.activeItemSetId,
			})
			local entry = inventoryEntry(exported, "Ring 1")

			assert.are.equal(slot.note, entry.additional_text)
			assert.is_nil(entry.additional_text:find(item.name, 1, true))
			assert.is_nil(entry.additional_text:find("maximum Life", 1, true))
		end
	end)

	it("exports a note even when its slot has no item", function()
		local slot = build.itemsTab.activeItemSet["Ring 1"]
		slot.selItemId = 0
		slot.note = "Standalone note"
		local exported = BuildExportPoE2.BuildTable(build, { useGeneratedItemText = false }, {
			specIndex = build.treeTab.activeSpec,
			skillSetId = build.skillsTab.activeSkillSetId,
			itemSetId = build.itemsTab.activeItemSetId,
		})

		assert.are.equal("Standalone note", inventoryEntry(exported, "Ring 1").additional_text)
	end)

	it("keeps linked loadout identifiers in filenames", function()
		local paths = {}
		BuildExportPoE2.WriteFile = function(_, path)
			table.insert(paths, path)
			return path
		end
		local exportBuild = {
			buildName = "Build",
			treeTab = { specList = {} },
			skillsTab = { skillSets = {} },
			itemsTab = { itemSets = {} },
			controls = { buildLoadouts = { list = { "^7^7Loadouts:", "Leveling {a}", "Leveling {b}" } } },
			SyncLoadouts = function() end,
			GetLoadoutByName = function()
				return { specId = 1, skillSetId = 1, itemSetId = 1 }
			end,
		}
		local loadouts = BuildExportPoE2.GetLoadouts(exportBuild)

		local written, errors = BuildExportPoE2.WriteAllLoadouts(exportBuild, "Build.build", {}, loadouts)

		assert.are.same({ "Leveling", "Leveling" }, { loadouts[1].name, loadouts[2].name })
		assert.are.equal(2, #written)
		assert.are.equal(0, #errors)
		assert.are.same({ "Build - Leveling {a}.build", "Build - Leveling {b}.build" }, paths)
	end)

	it("rejects filename collisions before writing", function()
		local writeCount = 0
		BuildExportPoE2.WriteFile = function()
			writeCount = writeCount + 1
		end

		local written, errors = BuildExportPoE2.WriteAllLoadouts(build, "Build.build", {}, {
			{ name = "Boss/A" },
			{ name = "Boss:A" },
		})

		assert.are.equal(0, writeCount)
		assert.are.equal(0, #written)
		assert.are.equal(1, #errors)
		assert.matches("export to the same file", errors[1], nil, true)
	end)
end)
