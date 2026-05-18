describe("TestCalcBreakdown", function()
	local calcBreakdown = LoadModule("Modules/CalcBreakdown", {}, {}, {})

	it("shows penetration minimum in effective DPS breakdown", function()
		local out = calcBreakdown.effMult("Lightning", 50, 100, 0, 1.5, 1, nil, true, nil, -50)
		local text = table.concat(out, "\n")

		assert.True(text:match("= %-50%%") ~= nil)
		assert.True(text:match("1%.50 %^8%(resistance%)") ~= nil)
		assert.True(text:match("= 1%.500") ~= nil)
	end)

	it("shows negative resistance in effective DPS breakdown without penetration", function()
		local out = calcBreakdown.effMult("Cold", -20, 0, 0, 1.2, 1, nil, true)
		local text = table.concat(out, "\n")

		assert.True(text:match("1%.20 %^8%(resistance%)") ~= nil)
		assert.True(text:match("= 1%.200") ~= nil)
	end)
end)
