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

describe("ImportTab quest reward import", function()
	before_each(function()
		newBuild()
	end)

	local function findQuest(info)
		for _, quest in ipairs(data.questRewards) do
			if quest.Info == info then
				return "quest" .. quest.Description .. quest.Area .. quest.Info, quest
			end
		end
		error("quest reward not found for Info: " .. info)
	end

	local function importStats(questStats)
		build.importTab:ImportQuestRewardConfig(questStats)
		return build.configTab.input
	end

	it("decomposes 0.5 rolled-up totals across the contributing quests", function()
		local input = importStats({
			"+20 to maximum Life",
			"+60 to [Spirit|Spirit]",
			"+15% to [Resistances|Cold Resistance]",
			"+15% to [Resistances|Fire Resistance]",
			"+15% to [Resistances|Lightning Resistance]",
		})

		assert.is_true(input[(findQuest("Candlemass"))])
		assert.is_true(input[(findQuest("King In The Mists"))])
		assert.is_true(input[(findQuest("Ignagduk"))])
		assert.is_true(input[(findQuest("Beira"))])
		assert.is_true(input[(findQuest("Blackjaw"))])
		assert.is_true(input[(findQuest("Sisters of Garukhan Shrine"))])

		local tasalioVar, tasalio = findQuest("Tasalio's Test")
		assert.are.equals(tasalio.Options[2], input[tasalioVar])
		local ngamahuVar, ngamahu = findQuest("Ngamahu's Test")
		assert.are.equals(ngamahu.Options[2], input[ngamahuVar])
		local tawhoaVar, tawhoa = findQuest("Tawhoa's Test")
		assert.are.equals(tawhoa.Options[2], input[tawhoaVar])

		assert.is_false(input[(findQuest("Lythara"))])
	end)

	it("sums duplicate 0.4 per-line Spirit rewards the same as the 0.5 summed total", function()
		local input = importStats({
			"+30 to [Spirit|Spirit]",
			"+30 to [Spirit|Spirit]",
			"+40 to [Spirit|Spirit]",
		})
		assert.is_true(input[(findQuest("King In The Mists"))])
		assert.is_true(input[(findQuest("Ignagduk"))])
		assert.is_true(input[(findQuest("Lythara"))])
	end)

	it("ticks exactly one of the interchangeable +30 Spirit quests when only one is claimed", function()
		local input = importStats({ "+30 to [Spirit|Spirit]" })
		local king = input[(findQuest("King In The Mists"))]
		local ignagduk = input[(findQuest("Ignagduk"))]
		assert.is_false(input[(findQuest("Lythara"))])
		assert.are.equals(1, (king and 1 or 0) + (ignagduk and 1 or 0))
	end)

	it("disambiguates Spirit total 70 to one +30 plus Lythara, not 30+30", function()
		local input = importStats({ "+70 to [Spirit|Spirit]" })
		assert.is_true(input[(findQuest("Lythara"))])
		local king = input[(findQuest("King In The Mists"))]
		local ignagduk = input[(findQuest("Ignagduk"))]
		assert.are.equals(1, (king and 1 or 0) + (ignagduk and 1 or 0))
	end)

	it("disambiguates Spirit total 40 to Lythara alone, not a +30", function()
		local input = importStats({ "+40 to [Spirit|Spirit]" })
		assert.is_true(input[(findQuest("Lythara"))])
		assert.is_false(input[(findQuest("King In The Mists"))])
		assert.is_false(input[(findQuest("Ignagduk"))])
	end)

	it("selects the correct multi-line option and leaves unclaimed option quests at None", function()
		local medallionVar, medallion = findQuest("Medallion")
		local input = importStats({
			"30% increased [Charm] Effect Duration",
			"+1 [Charm] Slot",
		})
		assert.are.equals(medallion.Options[2], input[medallionVar])
		assert.are.equals("None", input[(findQuest("Seven Pillars"))])
		assert.is_false(input[(findQuest("Beira"))])
	end)

	it("credits Tribal Medicine's Kaom option, not Seven Pillars which shares the stat at 15%", function()
		local tribalVar, tribal = findQuest("Tribal Medicine")
		local input = importStats({ "30% increased Global [Armour], [Evasion] and [EnergyShield|Energy Shield]" })
		assert.are.equals(tribal.Options[1], input[tribalVar])
		assert.are.equals("None", input[(findQuest("Seven Pillars"))])
	end)

	it("selects Tribal Medicine's Rakiata multi-stat option", function()
		local tribalVar, tribal = findQuest("Tribal Medicine")
		local input = importStats({
			"+15% of [Armour|Armour] also applies to [ElementalDamage|Elemental Damage]",
			"Gain [Deflect|Deflection Rating] equal to 12% of [Evasion|Evasion Rating]",
			"12% [FasterESRechargeStart|faster start of Energy Shield Recharge]",
		})
		assert.are.equals(tribal.Options[2], input[tribalVar])
	end)

	it("decomposes Global Armour, Evasion and Energy Shield shared by Tribal Medicine (30%) and Seven Pillars (15%)", function()
		local tribalVar, tribal = findQuest("Tribal Medicine")
		local sevenVar, seven = findQuest("Seven Pillars")
		local input = importStats({ "45% increased Global [Armour], [Evasion] and [EnergyShield|Energy Shield]" })
		assert.are.equals(tribal.Options[1], input[tribalVar])
		assert.are.equals(seven.Options[3], input[sevenVar])
	end)
end)
