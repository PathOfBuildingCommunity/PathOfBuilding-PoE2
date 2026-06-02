describe("ImportTab", function()
	before_each(function()
		newBuild()
	end)

	it("parses [Ward|Runic Ward] property from GGG API data and sets armourData.Ward (import path)", function()
		local importTab = build.importTab
		-- Simulate a GGG API item with localized Ward property name
		local mockItemData = {
			typeLine = "Runeforged Serpentscale Coat",
			name = "Empyrean Shelter",
			frameType = 2,
			inventoryId = "BodyArmour",
			id = "body1",
			ilvl = 36,
			mirrored = false,
			corrupted = false,
			properties = {
				{ name = "[Ward|Runic Ward]", values = {{"104", 0}}, type = 104 },
			},
		}
		-- Returns (item, slotName)
		local item = importTab:ImportItem(mockItemData, "Body Armour")
		assert.is_not_nil(item)
		assert.are.equals(104, item.armourData.Ward)
	end)

	it("parses [Ward|Runic Ward] property with a Ward rune mod without double-counting", function()
		local importTab = build.importTab
		-- GGG API item data that includes rune mods adding Ward
		local mockItemData = {
			typeLine = "Runeforged Itinerant Jacket",
			name = "Loath Coat",
			frameType = 2,
			inventoryId = "BodyArmour",
			id = "body2",
			ilvl = 67,
			mirrored = false,
			corrupted = false,
			properties = {
				{ name = "[Ward|Runic Ward]", values = {{"104", 0}}, type = 104 },
				{ name = "[Evasion|Evasion Rating]", values = {{"157", 0}}, type = 4 },
				{ name = "[EnergyShield|Energy Shield]", values = {{"61", 0}}, type = 6 },
			},
			runeMods = {
				"{rune}{enchant}112% increased Ward\n+65 to maximum Ward",
			},
		}
		local item = importTab:ImportItem(mockItemData, "Body Armour")
		assert.is_not_nil(item)
		-- Property line value is authoritative for Ward; rune INC/flat mods must not be re-applied
		assert.are.equals(104, item.armourData.Ward)
		-- Rune mods should be parsed into runeModLines
		assert.are.equals(2, #item.runeModLines)
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
