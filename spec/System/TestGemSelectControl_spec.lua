describe("TestGemSelectControl", function()
	before_each(function()
		newBuild()
		build.skillsTab:PasteSocketGroup("Fireball 20/0  1")
		runCallback("OnFrame")
	end)

	local function getGemSelect()
		return build.skillsTab.gemSlots[1].nameSpec
	end

	local function selectTemporaryGem(control, gemName)
		control:OnFocusGained()
		control.buf = gemName
		control:BuildList(control.buf)
		control.selIndex = 1
		control:UpdateGem(false, false, false)
		assert.are.equal(gemName, build.skillsTab.displayGroup.gemList[1].nameSpec)
	end

	it("queues DPS sorting with PoE2's fast calculation options", function()
		local control = getGemSelect()
		assert.is_false(control.dpsBuildFlag)

		control:OnFocusGained()

		assert.is_true(control.dpsBuildFlag)
		assert.is_table(control.sortCache.pendingGems)
		assert.same({
			nodeAlloc = true,
			requirementsItems = true,
			requirementsGems = true,
			skipEHP = true,
			fullDPSOnly = false,
		}, control.sortCache.fastCalcOptions)
	end)

	it("keeps the current gem selected when the DPS list is resorted", function()
		local control = getGemSelect()
		control:OnFocusGained()
		control.buf = control.buf:lower()
		control.selIndex = 0

		control:SortCurrentList()

		local selectedGem = control.gems[control.list[control.selIndex]]
		assert.is_not_nil(selectedGem)
		assert.are.equal("fireball", selectedGem.name:lower())
	end)

	it("waits for the hover selection to settle before calculating its tooltip", function()
		local control = getGemSelect()
		control.hoverSel = 2

		assert.is_false(control:IsHoverSelectionReady())
		assert.is_false(control:IsHoverSelectionReady())
		assert.is_true(control:IsHoverSelectionReady())

		control.hoverSel = 3
		assert.is_false(control:IsHoverSelectionReady())
		control.hoverSel = nil
		assert.is_false(control:IsHoverSelectionReady())
		assert.is_nil(control.lastHoverSel)
		assert.are.equal(0, control.hoverFrameCount)
	end)

	it("restores the existing gem when selection is cancelled with Escape", function()
		local control = getGemSelect()
		selectTemporaryGem(control, "Spark")

		control:OnKeyDown("ESCAPE")

		assert.are.equal("Fireball", control.buf)
		assert.are.equal("Fireball", build.skillsTab.displayGroup.gemList[1].nameSpec)
	end)

	it("restores the existing gem when the control loses focus", function()
		local control = getGemSelect()
		selectTemporaryGem(control, "Spark")

		control:OnFocusLost()

		assert.are.equal("Fireball", control.buf)
		assert.are.equal("Fireball", build.skillsTab.displayGroup.gemList[1].nameSpec)
	end)

	it("restores the existing gem when clicking outside the dropdown", function()
		local control = getGemSelect()
		selectTemporaryGem(control, "Spark")
		control.IsMouseOver = function()
			return false
		end

		control:OnKeyDown("LEFTBUTTON")

		assert.are.equal("Fireball", control.buf)
		assert.are.equal("Fireball", build.skillsTab.displayGroup.gemList[1].nameSpec)
	end)
end)
