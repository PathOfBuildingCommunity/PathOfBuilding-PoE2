describe("TestCalcSectionOverlay", function()
	before_each(function()
		newBuild()
	end)

	local function findSections()
		local pinnable
		local controlled
		for _, section in ipairs(build.calcsTab.sectionList) do
			if section.hasControls then
				controlled = controlled or section
			else
				pinnable = pinnable or section
			end
		end
		return pinnable, controlled
	end

	it("initializes overlay state and pop-out controls", function()
		assert.same({ }, build.overlayPanes)

		local pinnable, controlled = findSections()
		assert.is_not_nil(pinnable)
		assert.is_not_nil(controlled)
		assert.is_not_nil(pinnable.controls.popOut)
		assert.is_not_nil(controlled.controls.popOut)

		pinnable.enabled = true
		controlled.enabled = true
		assert.is_true(pinnable.controls.popOut.shown())
		assert.is_false(controlled.controls.popOut.shown())
	end)

	it("adds, raises, and removes overlay panes", function()
		local first = findSections()
		local second
		for _, section in ipairs(build.calcsTab.sectionList) do
			if section ~= first and not section.hasControls then
				second = section
				break
			end
		end
		assert.is_not_nil(second)

		first.x, first.y = 100, 120
		second.x, second.y = 200, 220
		first:ToggleOverlay()
		second:ToggleOverlay()
		assert.same({ first, second }, build.overlayPanes)
		assert.is_true(first.isOverlay)
		assert.is_false(first.shown())

		first:RaiseOverlay()
		assert.same({ second, first }, build.overlayPanes)

		first:ToggleOverlay()
		assert.same({ second }, build.overlayPanes)
		assert.is_false(first.isOverlay)
		assert.is_false(first.dragging)
	end)

	it("closes an overlay through its close button", function()
		local section = findSections()
		section.x, section.y = 100, 120
		section:ToggleOverlay()

		section:HandleOverlayClick("LEFTBUTTON", section.overlayX + section.width - 10, section.overlayY + 10)

		assert.is_false(section.isOverlay)
		assert.same({ }, build.overlayPanes)
	end)

	it("draws a populated overlay outside the Calcs tab", function()
		build.viewMode = "CALCS"
		runCallback("OnFrame")
		local section
		for _, candidate in ipairs(build.calcsTab.sectionList) do
			if candidate.enabled and not candidate.hasControls then
				section = candidate
				break
			end
		end
		assert.is_not_nil(section)
		section:ToggleOverlay()
		build.viewMode = "TREE"

		assert.has_no.errors(function()
			runCallback("OnFrame")
		end)
	end)

	it("routes a click only to the topmost overlay", function()
		local clicked = { }
		local function fakePane(name)
			return {
				isOverlay = true,
				IsMouseInOverlay = function()
					return true
				end,
				HandleOverlayClick = function()
					table.insert(clicked, name)
				end,
				HandleOverlayRelease = function()
				end,
				DrawOverlay = function()
				end,
			}
		end
		build.overlayPanes = { fakePane("bottom"), fakePane("top") }
		local inputEvents = { { type = "KeyDown", key = "LEFTBUTTON" } }

		build:OnFrame(inputEvents)

		assert.same({ "top" }, clicked)
		assert.is_nil(inputEvents[1])
	end)

	it("unpins a stat breakdown when its cell is clicked again", function()
		local displayData
		for _, section in ipairs(build.calcsTab.sectionList) do
			for _, subSection in ipairs(section.subSection) do
				for _, rowData in ipairs(subSection.data) do
					for _, colData in ipairs(rowData) do
						if colData.format then
							displayData = colData
							break
						end
					end
					if displayData then break end
				end
				if displayData then break end
			end
			if displayData then break end
		end
		assert.is_not_nil(displayData)
		assert.is_not_nil(displayData.calcSection)
		build.calcsTab.controls.breakdown.SetBreakdownData = function()
		end

		build.calcsTab:SetDisplayStat(displayData, true)
		assert.are.equal(displayData, build.calcsTab.displayData)
		assert.is_true(build.calcsTab.displayPinned)

		build.calcsTab:SetDisplayStat(displayData, true)
		assert.is_nil(build.calcsTab.displayData)
		assert.is_nil(build.calcsTab.displayPinned)
	end)

	it("does not attach another pane's pinned breakdown to a hovered overlay", function()
		local section = findSections()
		local pinnedData = { calcSection = section }
		local hoveredData = { calcSection = section }
		build.calcsTab.controls.breakdown.SetBreakdownData = function()
		end
		build.calcsTab:SetDisplayStat(pinnedData, true)

		section:SetOverlayDisplayStat(hoveredData)

		assert.are.equal(pinnedData, build.calcsTab.displayData)
		assert.is_false(section.overlayBreakdownCell)
	end)
end)
