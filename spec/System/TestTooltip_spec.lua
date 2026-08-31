local BuildExportPoE2 = require("Modules.BuildExportPoE2")

describe("Tooltip", function()
	local tooltip

	local function line(text, size, font)
		return { text = text, size = size or 14, font = font or "VAR" }
	end

	local function assertLines(expected)
		local actual = { }
		for _, value in ipairs(tooltip.lines) do
			table.insert(actual, { text = value.text, size = value.size, font = value.font })
		end
		assert.are.same(expected, actual)
	end

	before_each(function()
		newBuild()
		tooltip = new("Tooltip"):Tooltip()
	end)

	it("converts inline RGB colours and restores the default colour", function()
		local note = "Before <rgb(12, 34, 56)>{colour} after"
		tooltip:AddBuildPlannerNote(14, note)

		assertLines({ line("Before ^x0C2238colour^7 after") })
		assert.are.equal("Before <rgb(12, 34, 56)>{colour} after", note)
	end)

	it("restores the parent colour after nested RGB colours", function()
		tooltip:AddBuildPlannerNote(14, "<rgb(255, 0, 0)>{outer <rgb(0, 128, 255)>{inner} outer}")

		assertLines({ line("^xFF0000outer ^x0080FFinner^xFF0000 outer^7") })
	end)

	it("keeps inline styles inside inline colours on the default line style", function()
		tooltip:AddBuildPlannerNote(14, "Before <rgb(12, 34, 56)>{colour <i>{italic}} after")

		assertLines({ line("Before ^x0C2238colour italic^7 after") })
	end)

	it("reapplies RGB colours to each independently drawn line", function()
		tooltip:AddBuildPlannerNote(14, "<rgb(10, 20, 30)>{first\nsecond}")

		assertLines({
			line("^x0A141Efirst^7"),
			line("^x0A141Esecond^7"),
		})
	end)

	it("reapplies RGB colours to lines wrapped by AddLine", function()
		tooltip.maxWidth = 12
		tooltip:AddBuildPlannerNote(14, "<rgb(10, 20, 30)>{first second}")

		assertLines({
			line("^x0A141Efirst^7"),
			line("^x0A141Esecond^7"),
		})
	end)

	it("converts the documented red tag", function()
		tooltip:AddBuildPlannerNote(14, "Warning <red>{danger}")

		assertLines({ line("Warning ^xFF0000danger^7") })
	end)

	it("applies whole-line font and size tags", function()
		tooltip:AddBuildPlannerNote(20, table.concat({
			"<i>{italic}",
			"<b>{bold}",
			"<s>{small}",
			"<m>{medium}",
			"<l>{large}",
			"<rgb(1, 2, 3)>{<i>{coloured italic}}",
		}, "\n"))

		assertLines({
			line("italic", 20, "FONTIN SC ITALIC"),
			line("bold", 20, "VAR BOLD"),
			line("small", 15),
			line("medium", 20),
			line("large", 25),
			line("^x010203coloured italic^7", 20, "FONTIN SC ITALIC"),
		})
	end)

	it("strips inline font tags without applying line style", function()
		tooltip:AddBuildPlannerNote(14, "Inline <i>{italic} and <b>{bold}")

		assertLines({ line("Inline italic and bold") })
	end)

	it("strips underline tags without applying line style", function()
		tooltip:AddBuildPlannerNote(14, "Inline <u>{underline}")

		assertLines({ line("Inline underline") })
	end)

	it("keeps malformed markup safe and plain", function()
		local note = "<rgb(255, 0, 0)>{unfinished"

		assert.has_no.errors(function()
			tooltip:AddBuildPlannerNote(14, note)
		end)
		assertLines({ line(note) })
		assert.are.equal("<rgb(255, 0, 0)>{unfinished", note)
	end)

	it("draws unknown tooltip headers with the normal-header fallback", function()
		tooltip.tooltipHeader = "UNKNOWN"
		tooltip:AddLine(14, "Unknown node")

		assert.has_no.errors(function()
			tooltip:Draw(0, 0, nil, nil, { x = 0, y = 0, width = 1920, height = 1080 })
		end)
	end)
end)

describe("BuildPlanner note popup", function()
	local function openNote(initial, generatedText)
		main:OpenNoteEditPopup("Test note", initial, function() end, generatedText)
		return main.popups[1], main.popups[1].controls
	end

	local function addRing()
		local item = new("Item"):Item([[Rarity: RARE
Export Ring
Gold Ring
Implicits: 0
+10 to maximum Life]])
		build.itemsTab:AddItem(item, true)
		build.itemsTab:EquipItemInSet(item, build.itemsTab.activeItemSetId)
		return item, build.itemsTab.slots["Ring 1"]
	end

	local function click(popup, button)
		button.IsMouseOver = function() return true end
		popup.GetMouseOverControl = function() end
		popup:SelectControl(button)
		popup:ProcessControlsInput({
			{ type = "KeyDown", key = "LEFTBUTTON" },
			{ type = "KeyUp", key = "LEFTBUTTON" },
		}, { })
	end

	before_each(function()
		newBuild()
	end)

	after_each(function()
		while main.popups[1] do
			main:ClosePopup()
		end
	end)

	it("does not add an item-text control to ordinary note popups", function()
		local _, controls = openNote("")

		assert.is_nil(controls.addItemText)
	end)

	it("adds the item-text control only for a selected item", function()
		local item, slot = addRing()
		slot.controls.noteButton.onClick()

		local controls = main.popups[1].controls
		assert.is_not_nil(controls.addItemText)
		assert.are.equal("TOPLEFT", controls.addItemText.anchor.point)
		assert.is_true(controls.addItemText.forceTooltip)
		assert.are.equal(240, controls.edit.height)
	end)

	it("inserts exact generated item text at the edit caret", function()
		local item, slot = addRing()
		slot.controls.noteButton.onClick()
		local popup = main.popups[1]
		local controls = popup.controls
		local generatedText = BuildExportPoE2.ItemAdditionalText(item)
		local prefix, suffix = "prefix\n", "\nsuffix"

		controls.edit:SetText(prefix .. suffix)
		controls.edit.caret = #prefix + 1
		click(popup, controls.addItemText)

		assert.are.equal(prefix .. generatedText .. suffix, controls.edit.buf)
		assert.are.equal(controls.edit, popup.selControl)
		assert.is_true(controls.edit.hasFocus)
		assert.are.equal(#prefix + #generatedText + 1, controls.edit.caret)
	end)

	it("saves generated item text when the existing note is over 960 bytes", function()
		local item, slot = addRing()
		local prefix = string.rep("x", 961)
		local generatedText = BuildExportPoE2.ItemAdditionalText(item)
		slot.note = prefix
		slot.controls.noteButton.onClick()
		local popup = main.popups[1]
		local controls = popup.controls

		controls.edit.caret = #controls.edit.buf + 1
		click(popup, controls.addItemText)

		assert.are.equal(prefix .. generatedText, controls.edit.buf)
		assert.are.equal(#controls.edit.buf + 1, controls.edit.caret)
		controls.save.onClick()
		assert.are.equal(prefix .. generatedText, slot.note)
	end)

	it("builds the save tooltip from the current formatted buffer", function()
		local _, controls = openNote("")
		local tooltip = new("Tooltip"):Tooltip()

		assert.is_true(controls.save.forceTooltip)
		controls.edit:SetText("<rgb(1, 2, 3)>{coloured}\n<b>{bold}")
		controls.save.tooltipFunc(tooltip)
		assert.are.equal(2, #tooltip.lines)
		assert.are.equal("^x010203coloured^7", tooltip.lines[1].text)
		assert.are.equal("bold", tooltip.lines[2].text)
		assert.are.equal("VAR BOLD", tooltip.lines[2].font)

		controls.edit:SetText("updated")
		controls.save.tooltipFunc(tooltip)
		assert.are.equal(1, #tooltip.lines)
		assert.are.equal("updated", tooltip.lines[1].text)

		controls.edit:SetText("")
		controls.save.tooltipFunc(tooltip)
		assert.are.equal("Save an empty note to remove it.", tooltip.lines[1].text)
	end)
end)
