local BuildExportPoE2 = require("Modules.BuildExportPoE2")

describe("PoE2 BuildPlanner export", function()
	local originalWriteFile

	before_each(function()
		newBuild()
		originalWriteFile = BuildExportPoE2.WriteFile
	end)

	after_each(function()
		BuildExportPoE2.WriteFile = originalWriteFile
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
		assert.are.same({ name = "Unnamed Build", author = "Author", description = "" }, importTab:GetBuildPlannerMetadata())

		importTab.controls.buildPlannerBuildName:SetText("My Build")
		importTab.controls.buildPlannerAuthorName:SetText("My Author")
		assert.are.same({ name = "My Build", author = "My Author", description = "" }, importTab:GetBuildPlannerMetadata())
	end)

	it("keeps linked loadout identifiers in filenames", function()
		local paths = {}
		BuildExportPoE2.WriteFile = function(_, path)
			table.insert(paths, path)
			return path
		end
		local exportBuild = {
			buildName = "Build",
			treeTab = {},
			skillsTab = {},
			itemsTab = {},
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
