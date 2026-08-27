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
end)
