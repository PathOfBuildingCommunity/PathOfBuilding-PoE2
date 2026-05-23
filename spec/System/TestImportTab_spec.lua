describe("ImportTab", function()
	before_each(function()
		newBuild()
	end)

	it("builds character lists for private Ruthless league names without a Ruthless tree", function()
		local importTab = build.importTab
		importTab.lastCharList = {
			{
				name = "PrivateLeagueCharacter",
				class = "Amazon",
				level = 90,
				league = "My Private Ruthless League",
			},
		}

		local ok, err = pcall(function()
			importTab:BuildCharacterList(nil)
		end)

		assert.True(ok, err)
		assert.are.equals(1, #importTab.controls.charSelect.list)
		assert.are.equals("PrivateLeagueCharacter", importTab.controls.charSelect.list[1].label)
		assert.True(importTab.controls.charSelect.list[1].detail:match("Amazon") ~= nil)
	end)

	it("falls back to the default class color for unknown character classes", function()
		local importTab = build.importTab
		importTab.lastCharList = {
			{
				name = "UnknownClassCharacter",
				class = "Future Ascendancy",
				level = 1,
				league = "My Private Ruthless League",
			},
		}

		local ok, err = pcall(function()
			importTab:BuildCharacterList(nil)
		end)

		assert.True(ok, err)
		assert.are.equals(1, #importTab.controls.charSelect.list)
		assert.True(importTab.controls.charSelect.list[1].detail:match("Future Ascendancy") ~= nil)
	end)
end)
