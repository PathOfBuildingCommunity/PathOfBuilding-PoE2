local gemTooltip = require("Classes.GemTooltip")

describe("TestSkillsTab", function()
	before_each(function()
		newBuild()
		runCallback("OnFrame")
	end)

	describe("SkillsTab", function()
		it("only shows the build-note shortcut when it is available", function()
			local gemInstance = {
				gemData = data.gems["Metadata/Items/Gems/SkillGemExplosiveGrenade"],
				level = 20,
				quality = 0,
				note = "Test note",
			}
			local tooltip = new("Tooltip"):Tooltip()

			gemTooltip.AddGemTooltip(tooltip, build, gemInstance)
			for _, line in ipairs(tooltip.lines) do
				assert.is_nil(line.text and line.text:find("Shift + Right-Click", 1, true))
			end

			tooltip:Clear()
			gemTooltip.AddGemTooltip(tooltip, build, gemInstance, { includeBuildPlannerNote = true })
			local noteHintFound
			local noteFound
			for _, line in ipairs(tooltip.lines) do
				noteHintFound = noteHintFound or line.text and line.text:find("Shift + Right-Click", 1, true)
				noteFound = noteFound or line.text and line.text:find("Test note", 1, true)
			end
			assert.is_truthy(noteHintFound)
			assert.is_truthy(noteFound)
		end)

		describe("NewSkillSet", function()
			it("Creates a new skill set with specified ID", function()
				local skillSetName = "New Skill Set"
				local skillSetId = 2
				build.skillsTab:NewSkillSet(skillSetId, skillSetName)

				assert.are.equals(skillSetName, build.skillsTab.skillSets[skillSetId].title)
				assert.are.equals(skillSetId, build.skillsTab.skillSets[skillSetId].id)
			end)

			it("Assigns auto-incremented ID when not specified", function()
				local skillSetName = "Auto ID Skill Set"
				local skillSet1 = build.skillsTab:NewSkillSet()
				local skillSet2 = build.skillsTab:NewSkillSet(nil, skillSetName)

				assert.are.equals(2, skillSet1.id)
				assert.are.equals(3, skillSet2.id)
				assert.are.equals(skillSetName, build.skillsTab.skillSets[skillSet2.id].title)
			end)

			it("Adds set to order list", function()
				local newTitle = "New Skill"

				build.skillsTab:NewSkillSet(nil, newTitle)

				assert.are.equals(2, #build.skillsTab.skillSetOrderList)
				assert.are.equals(2, build.skillsTab.skillSetOrderList[2])
			end)

			it("Updates the mod flag", function()
				local newTitle = "New Skill"
				build.skillsTab.modFlag = false

				build.skillsTab:NewSkillSet(nil, newTitle)

				assert.is_true(build.skillsTab.modFlag)
			end)
		end)

		describe("CopySkillSet", function()
			it("Copies a skill set with a new name", function()
				local newTitle = "Copied Skill"
				local newSkillSet = build.skillsTab:CopySkillSet(1, newTitle)

				assert.is_not.same(build.skillsTab.skillSets[1], newSkillSet)
				assert.are.equals(newTitle, newSkillSet.title)
				assert.are.same(newSkillSet.socketGroupList, build.skillsTab.skillSets[1].socketGroupList)
			end)

			it("Deep copies all socket groups and gems", function()
				local newTitle = "Copied Skill"

				local testGem = { nameSpec = "TestGem", level = 20 }
				build.skillsTab.skillSets[1].socketGroupList = { { gemList = { testGem } } }

				local newSkillSet = build.skillsTab:CopySkillSet(1, newTitle)

				assert.are.same("TestGem", build.skillsTab.skillSets[1].socketGroupList[1].gemList[1].nameSpec)
				assert.are.same(20, build.skillsTab.skillSets[1].socketGroupList[1].gemList[1].level)
				build.skillsTab.skillSets[1].socketGroupList[1].gemList[1].nameSpec = "Modified"

				assert.are.equals("TestGem", newSkillSet.socketGroupList[1].gemList[1].nameSpec)
				assert.are.equals(20, newSkillSet.socketGroupList[1].gemList[1].level)
			end)

			it("Returns copied skill set with next ID", function()
				local newTitle = "Copied Skill"

				local newSkillSet = build.skillsTab:CopySkillSet(1, newTitle)

				assert.are.equals(2, newSkillSet.id)
			end)

			it("Adds copied skill set to order list", function()
				local newTitle = "Copied Skill"

				build.skillsTab:CopySkillSet(1, newTitle)

				assert.are.equals(2, #build.skillsTab.skillSetOrderList)
				assert.are.equals(2, build.skillsTab.skillSetOrderList[2])
			end)

			it("Updates the mod flag", function()
				local newTitle = "Copied Skill"
				build.skillsTab.modFlag = false

				build.skillsTab:CopySkillSet(1, newTitle)

				assert.is_true(build.skillsTab.modFlag)
			end)
		end)

		describe("RenameSkillSet", function()
			it("Renames a skill set", function()
				local newTitle = "Renamed Skill"
				build.skillsTab:RenameSkillSet(1, newTitle)

				assert.are.equals(newTitle, build.skillsTab.skillSets[1].title)
			end)

			it("Does not rename non-existent skill set", function()
				build.skillsTab:RenameSkillSet(999, "Non-existent")

				assert.is_nil(build.skillsTab.skillSets[999])
			end)

			it("Updates the mod flag", function()
				local newTitle = "Renamed Skill"
				build.skillsTab.modFlag = false

				build.skillsTab:RenameSkillSet(1, newTitle)

				assert.is_true(build.skillsTab.modFlag)
			end)
		end)

		describe("DeleteSkillSet", function()
			it("Deletes a skill set and its order entry", function()
				local skillSetName = "Skill To Delete"
				build.skillsTab:NewSkillSet(2, skillSetName)

				build.skillsTab:DeleteSkillSet(2, 2)

				assert.is_nil(build.skillsTab.skillSets[2])
				assert.are.equals(1, #build.skillsTab.skillSetOrderList)
			end)

			it("allows deletion of the last skill set", function()
				local lastSkill = 1

				assert.are.equals(1, #build.skillsTab.skillSetOrderList)
				build.skillsTab:DeleteSkillSet(lastSkill, 1)

				assert.are.equals(0, #build.skillsTab.skillSetOrderList)
				assert.is_nil(build.skillsTab.skillSets[lastSkill])
			end)
		end)

		describe("SetActiveSkillSet", function()
			it("Switches to a valid skill set", function()
				local skillSetName = "New Skill"
				build.skillsTab:NewSkillSet(2, skillSetName)

				build.skillsTab:SetActiveSkillSet(2)

				assert.are.equals(2, build.skillsTab.activeSkillSetId)
				assert.are.same(build.skillsTab.skillSets[2].socketGroupList, build.skillsTab.socketGroupList)
			end)

			it("Defaults to first skill set if invalid ID provided", function()
				build.skillsTab:SetActiveSkillSet(999)

				assert.are.equals(1, build.skillsTab.activeSkillSetId)
			end)
		end)
	end)

	describe("SkillsSetService", function()
		local skillsSetService

		before_each(function()
			skillsSetService = new("SkillsSetService"):SkillsSetService(build.skillsTab)
		end)

		describe("NewSkillSet", function()
			it("Creates a new skill set via service", function()
				local skillSetName = "Service New Skill"
				skillsSetService:NewSkillSet(skillSetName)

				assert.are.equals(2, #build.skillsTab.skillSetOrderList)
				assert.are.equals(skillSetName, build.skillsTab.skillSets[2].title)
			end)

			it("Sets newly created skill as active", function()
				skillsSetService:NewSkillSet("New From Service")

				assert.are.equals(2, build.skillsTab.activeSkillSetId)
			end)

			it("Adds an undo state", function()
				local newTitle = "New Skill"

				local undoCountBefore = #build.skillsTab.undo
				skillsSetService:NewSkillSet(newTitle)

				assert.are.equals(#build.skillsTab.undo, undoCountBefore + 1)
			end)
		end)

		describe("CopySkillSet", function()
			it("Copies a skill set via service", function()
				local skillSetName = "Copied via Service"
				skillsSetService:CopySkillSet(1, skillSetName)
				local skillSetId = build.skillsTab.skillSetOrderList[2]

				assert.are.equals(skillSetName, build.skillsTab.skillSets[skillSetId].title)
			end)

			it("Sets copied skill set as active via service", function()
				skillsSetService:NewSkillSet("Skill")
				skillsSetService:CopySkillSet(1, "Service Copy")
				local skillSetId = build.skillsTab.skillSetOrderList[3]

				assert.are.equals(skillSetId, build.skillsTab.activeSkillSetId)
			end)

			it("Adds an undo state when copying a skill set", function()
				local undoCountBefore = #build.skillsTab.undo
				skillsSetService:CopySkillSet(1, "Copied Skill")

				assert.are.equals(#build.skillsTab.undo, undoCountBefore + 1)
			end)
		end)

		describe("RenameSkillSet", function()
			it("Renames a skill set via service", function()
				local skillSetName = "Original Name"
				skillsSetService:NewSkillSet(skillSetName)
				local skillSetId = build.skillsTab.skillSetOrderList[2]

				skillsSetService:RenameSkillSet(skillSetId, "New Name")

				assert.are.equals("New Name", build.skillsTab.skillSets[skillSetId].title)
			end)

			it("Does not rename non-existent skill set", function()
				skillsSetService:RenameSkillSet(10, "Non-existent")

				assert.is_nil(build.skillsTab.skillSets[10])
			end)

			it("Adds an undo state when renaming", function()
				local skillSetName = "Skill To Rename"
				skillsSetService:NewSkillSet(skillSetName)
				local skillSetId = build.skillsTab.skillSetOrderList[2]

				local undoCountBefore = #build.skillsTab.undo
				skillsSetService:RenameSkillSet(skillSetId, "Renamed Skill")

				assert.are.equals(#build.skillsTab.undo, undoCountBefore + 1)
			end)
		end)

		describe("DeleteSkillSet", function()
			it("Deletes a skill set via service", function()
				skillsSetService:NewSkillSet("Service Delete Me")

				skillsSetService:DeleteSkillSet(2, 2)

				assert.is_nil(build.skillsTab.skillSets[2])
				assert.is_nil(build.skillsTab.skillSetOrderList[2])
			end)

			it("Switches active skill set when deleting current", function()
				skillsSetService:NewSkillSet("Service Delete Me")
				local skillToKeep = 1
				local skillToDelete = 2

				assert.are.equals(skillToDelete, build.skillsTab.activeSkillSetId)

				skillsSetService:DeleteSkillSet(skillToDelete, 2)

				assert.are.equals(skillToKeep, build.skillsTab.activeSkillSetId)
			end)

			it("Does not delete last skill set via service", function()
				skillsSetService:NewSkillSet("Last One")

				skillsSetService:DeleteSkillSet(1, 1)

				assert.are.equals(1, #build.skillsTab.skillSetOrderList)
			end)

			it("Adds an undo state when deleting", function()
				local undoCountBefore = #build.skillsTab.undo
				local undoCountAfterNew = #build.skillsTab.undo
				skillsSetService:NewSkillSet("Undo Delete Test")

				skillsSetService:DeleteSkillSet(2, 2)

				assert.are.equals(#build.skillsTab.undo, undoCountBefore + 2)
			end)
		end)



		describe("Integration", function()
			it("Completes a skill set lifecycle", function()
				local skill1Name = "First Skill"
				local skill2Name = "Second Skill"

				skillsSetService:NewSkillSet(skill1Name)
				assert.are.equals("First Skill", build.skillsTab.skillSets[2].title)

				skillsSetService:CopySkillSet(2, skill2Name)
				assert.are.equals("Second Skill", build.skillsTab.skillSets[3].title)
			end)
		end)
	end)

	describe("SkillSetStateManagement", function()
		local skillsSetService

		before_each(function()
			skillsSetService = new("SkillsSetService"):SkillsSetService(build.skillsTab)
		end)

		describe("Socket group persistence", function()
			it("Preserves socket groups across skill set switches", function()
				skillsSetService:NewSkillSet("Set 1")
				skillsSetService:NewSkillSet("Set 2")

				local testSocketGroup = {
					label = "Test Group",
					enabled = true,
					gemList = {
						{ nameSpec = "TestGem", level = 20, quality = 0, enabled = true, count = 1 }
					}
				}

				build.skillsTab.skillSets[1].socketGroupList[1] = testSocketGroup
				build.skillsTab:SetActiveSkillSet(1)

				assert.are.same(testSocketGroup, build.skillsTab.skillSets[1].socketGroupList[1])

				build.skillsTab:SetActiveSkillSet(3)
				build.skillsTab.skillSets[3].socketGroupList[1] = { label = "Different" }

				build.skillsTab:SetActiveSkillSet(1)
				assert.are.same(testSocketGroup, build.skillsTab.skillSets[1].socketGroupList[1])
			end)

			it("Preserves nested gem data across skill set switches", function()
				skillsSetService:NewSkillSet("Set 1")
				skillsSetService:NewSkillSet("Set 2")
				skillsSetService:NewSkillSet("Set 3")

				local testGem = { nameSpec = "TestGem", level = 20, quality = 20 }
				build.skillsTab.skillSets[3].socketGroupList = { { gemList = { testGem } } }

				build.skillsTab:SetActiveSkillSet(3)
				assert.are.same(testGem, build.skillsTab.skillSets[3].socketGroupList[1].gemList[1])
			end)
		end)

		describe("Default values", function()
			it("Initializes new skill sets with default structure", function()
				assert.is_not_nil(build.skillsTab.skillSets[1])
				assert.is_not_nil(build.skillsTab.skillSets[1].socketGroupList)
				assert.is_not_nil(build.skillsTab.skillSets[1].removedSocketGroupList)
				assert.is_not_nil(build.skillsTab.skillSets[1].id)
			end)

			it("Copies socket group structure when copying skill sets", function()
				local testSocketGroup = {
					label = "Original",
					enabled = false,
					gemList = {}
				}
				build.skillsTab.skillSets[1].socketGroupList[1] = testSocketGroup
				build.skillsTab.skillSets[1].removedSocketGroupList.cached = {
					label = "Cached",
					gemList = { { nameSpec = "Arcane Tempo I", level = 1 } },
				}

				local newSkillSet = build.skillsTab:CopySkillSet(1, "Copy Test")

				assert.are.equals("Original", newSkillSet.socketGroupList[1].label)
				assert.is_false(newSkillSet.socketGroupList[1].enabled)
				assert.are.equals("Cached", newSkillSet.removedSocketGroupList.cached.label)
				assert.are_not.equals(build.skillsTab.skillSets[1].removedSocketGroupList.cached, newSkillSet.removedSocketGroupList.cached)
			end)

			it("Clones removed granted-skill groups in undo states", function()
				local cachedGroup = {
					label = "Granted",
					enabled = true,
					gemList = { { skillId = "GrantedSkill", level = 1, enabled = true } },
				}
				build.skillsTab.skillSets[1].removedSocketGroupList.granted = cachedGroup

				local state = build.skillsTab:CreateUndoState()
				local savedGroup = state.skillSets[1].removedSocketGroupList.granted
				build.skillsTab.skillSets[1].removedSocketGroupList.granted = nil
				cachedGroup.gemList[1].level = 2

				assert.are_not.equal(cachedGroup, savedGroup)
				assert.are_not.equal(cachedGroup.gemList[1], savedGroup.gemList[1])
				assert.are.equals(1, savedGroup.gemList[1].level)
			end)

			it("persists removed granted-skill groups", function()
				local key = "Item:Test\0Weapon 1\0Fireball"
				build.skillsTab.skillSets[1].removedSocketGroupList[key] = {
					label = "Cached",
					enabled = true,
					set1 = true,
					set2 = false,
					gemList = { { nameSpec = "Arcane Tempo I", level = 1, quality = 0, enabled = true, count = 1 } },
				}
				local xml = { }
				build.skillsTab:Save(xml)
				build.skillsTab:Load(xml)

				local restored = build.skillsTab.skillSets[1].removedSocketGroupList[key]
				assert.is_not_nil(restored)
				assert.are.equals("Cached", restored.label)
				assert.are.equals("Arcane Tempo I", restored.gemList[1].nameSpec)
				assert.is_false(restored.set2)
			end)

			it("keeps special generated source gems immutable", function()
				local group = {
					source = "Thorns",
					enabled = true,
					gemList = { { skillId = "ThornsPlayer", level = 1, quality = 0, enabled = true } },
				}
				build.skillsTab:SetDisplayGroup(group)

				assert.is_false(build.skillsTab.gemSlots[1].delete:IsEnabled())
				assert.is_false(build.skillsTab.gemSlots[1].nameSpec:IsEnabled())
			end)
		end)

		describe("Weapon set assignments", function()
			it("does not calculate weapon-set validity before the first output revision", function()
				build.skillsTab:PasteSocketGroup("Spark 20/0  1")
				local group = build.skillsTab.socketGroupList[1]
				build.outputRevision = nil
				build.skillsTab.weaponSetValidityRevision = nil
				build.skillsTab.weaponSetValidityCache = nil

				assert.has_no.errors(function()
					build.skillsTab:SetDisplayGroup(group)
				end)
				assert.is_nil(build.skillsTab.weaponSetValidityCache)
			end)

			it("calculates the inactive context only when checkbox validity is requested", function()
				build.skillsTab:PasteSocketGroup("Spark 20/0  1")
				local group = build.skillsTab.socketGroupList[1]
				build.mainSocketGroup = 1
				build.buildFlag = true
				runCallback("OnFrame")
				build.skillsTab.weaponSetValidityCache = nil
				build.skillsTab.weaponSetValidityRevision = nil

				local calcs = build.calcsTab.calcs
				local initEnv = calcs.initEnv
				local initCount = 0
				calcs.initEnv = function(...)
					initCount = initCount + 1
					return initEnv(...)
				end
				local set1Valid = build.skillsTab:IsSocketGroupWeaponSetValid(group, 1)
				local set2Valid = build.skillsTab:IsSocketGroupWeaponSetValid(group, 2)
				calcs.initEnv = initEnv

				assert.is_true(set1Valid)
				assert.is_true(set2Valid)
				assert.are.equals(1, initCount)
			end)

			it("keeps a set selectable when validity calculation fails", function()
				build.skillsTab:PasteSocketGroup("Spark 20/0  1")
				local group = build.skillsTab.socketGroupList[1]
				local calcs = build.calcsTab.calcs
				local initEnv = calcs.initEnv
				local mainEnv = build.calcsTab.mainEnv
				build.calcsTab.mainEnv = nil
				build.skillsTab.weaponSetValidityCache = nil
				build.skillsTab.weaponSetValidityRevision = nil
				calcs.initEnv = function()
					error("validation failed")
				end

				local valid = build.skillsTab:IsSocketGroupWeaponSetValid(group, 1)

				calcs.initEnv = initEnv
				build.calcsTab.mainEnv = mainEnv
				assert.is_true(valid)
			end)

			it("shows the selected assignment in sidebar and Calcs headings", function()
				build.skillsTab:PasteSocketGroup("Spark 20/0  1")
				local group = build.skillsTab.socketGroupList[1]
				group.set1 = false
				group.set2 = true
				build.mainSocketGroup = 1
				build.calcsTab.input.skill_number = 1
				build.buildFlag = true
				runCallback("OnFrame")

				assert.are.equals("^7Main Skill: Set 2", build.controls.mainSkillLabel:GetProperty("label"))
				assert.are.equals("Socket Group: Set 2", build.calcsTab.socketGroupRow.label)
			end)

			it("defaults legacy groups to both sets and preserves explicit false values", function()
				build.skillsTab:LoadSkill({ elem = "Skill", attrib = { enabled = "true" } }, 1)
				local legacy = build.skillsTab.skillSets[1].socketGroupList[#build.skillsTab.skillSets[1].socketGroupList]
				assert.is_true(legacy.set1)
				assert.is_true(legacy.set2)

				legacy.set1 = false
				local xml = { }
				build.skillsTab:Save(xml)
				local savedGroup = xml[1][#xml[1]]
				assert.are.equals("false", savedGroup.attrib.set1)
				assert.are.equals("true", savedGroup.attrib.set2)
			end)

			it("persists the fixed set of generated default attacks", function()
				build.skillsTab:LoadSkill({ elem = "Skill", attrib = {
					enabled = "true",
					source = "Default Attack",
					slot = "Weapon 1 Swap",
				} }, 1)
				local group = build.skillsTab.skillSets[1].socketGroupList[#build.skillsTab.skillSets[1].socketGroupList]
				assert.is_false(group.set1)
				assert.is_true(group.set2)
				assert.is_true(build.skillsTab:IsSocketGroupWeaponSetLocked(group))

				local xml = { }
				build.skillsTab:Save(xml)
				assert.are.equals("Default Attack", xml[1][#xml[1]].attrib.source)
				assert.are.equals("Weapon 1 Swap", xml[1][#xml[1]].attrib.slot)
			end)

			it("normalizes persisted groups with neither weapon set selected", function()
				build.skillsTab:LoadSkill({ elem = "Skill", attrib = { enabled = "true", set1 = "false", set2 = "false" } }, 1)
				local socketGroup = build.skillsTab.skillSets[1].socketGroupList[#build.skillsTab.skillSets[1].socketGroupList]
				assert.is_true(socketGroup.set1)
				assert.is_true(socketGroup.set2)
			end)

			it("does not allow both weapon sets to be unchecked", function()
				local group = { enabled = true, set1 = true, set2 = false, gemList = { } }
				build.skillsTab:SetDisplayGroup(group)
				build.skillsTab.controls.set1Enabled.state = false
				build.skillsTab.controls.set1Enabled.changeFunc(false)
				assert.is_true(build.skillsTab.controls.set1Enabled.state)
				assert.is_true(group.set1)
				assert.is_false(group.set2)
			end)

			it("forces skills with the all-weapon-sets reservation stat to both", function()
				local group = {
					enabled = true,
					set1 = true,
					set2 = false,
					gemList = { { skillId = "BlinkReservationPlayer", level = 1, quality = 0, enabled = true } },
				}
				build.skillsTab:ProcessSocketGroup(group)
				table.insert(build.skillsTab.socketGroupList, group)
				build.mainSocketGroup = #build.skillsTab.socketGroupList
				build.buildFlag = true
				runCallback("OnFrame")
				assert.is_true(group.forcedBoth)
				assert.is_true(group.set1)
				assert.is_true(group.set2)
			end)

			it("hides item and tree granted effects from the gem selector", function()
				for _, gemData in pairs(build.skillsTab.gemSlots[1].nameSpec.gems) do
					assert.is_not_true(gemData.grantedEffect.fromItem)
					assert.is_not_true(gemData.grantedEffect.fromTree)
				end
			end)
		end)
	end)
end)
