describe("TestEarthquake", function()
	before_each(function()
		newBuild()
	end)

	teardown(function()
		-- newBuild() takes care of resetting everything in setup()
	end)

	-- statSetIndex 1 = Impact, 2 = Aftershock
	local function setupEarthquake(statSetIndex, customMods, weapons)
		for _, weapon in ipairs(weapons or { "Wooden Club" }) do
			build.itemsTab:CreateDisplayItemFromRaw("New Item\n" .. weapon)
			build.itemsTab:AddDisplayItem()
		end
		build.skillsTab:PasteSocketGroup("Earthquake 20/0  1")
		local gemInstance = build.skillsTab.socketGroupList[1].gemList[1]
		gemInstance.statSet = { EarthquakePlayer = statSetIndex }
		gemInstance.statSetCalcs = { EarthquakePlayer = statSetIndex }
		build.mainSocketGroup = 1
		build.configTab.input.customMods = customMods or ""
		build.configTab:BuildModList()
		runCallback("OnFrame")
		return build.calcsTab.mainOutput
	end

	local function assertClose(expected, actual)
		assert.is_true(math.abs(expected - actual) < 0.001, string.format("expected %s, got %s", tostring(expected), tostring(actual)))
	end

	it("caps the Aftershock hit rate at once per Jagged Ground duration", function()
		local out = setupEarthquake(2)
		assert.is_true(out.Duration > 0)
		assert.is_true(out.Speed > 1 / out.Duration, "test assumes attack time is shorter than the patch duration")
		assertClose(1 / out.Duration, out.HitSpeed)
		assertClose(out.AverageDamage * out.HitSpeed * out.DpsMultiplier, out.TotalDPS)
		assert.is_falsy(build.calcsTab.mainEnv.player.mainSkill.skillData.showAverage)
	end)

	it("does not scale Aftershock DPS with attack speed while the patch duration is the limit", function()
		local base = setupEarthquake(2)

		newBuild()
		local out = setupEarthquake(2, "200% increased Attack Speed")
		assert.is_true(out.Speed > base.Speed)
		assertClose(base.HitSpeed, out.HitSpeed)
		assertClose(base.TotalDPS, out.TotalDPS)
	end)

	it("scales Aftershock DPS with reduced skill effect duration", function()
		local base = setupEarthquake(2)

		newBuild()
		local out = setupEarthquake(2, "50% reduced Skill Effect Duration")
		assertClose(base.Duration / 2, out.Duration)
		assertClose(1 / out.Duration, out.HitSpeed)
		assertClose(base.TotalDPS * 2, out.TotalDPS)
	end)

	it("uses the attack rate for Aftershock once the patch duration is shorter than the attack time", function()
		local out = setupEarthquake(2, "80% reduced Skill Effect Duration")
		assert.is_true(out.Speed < 1 / out.Duration, "test assumes attack time is longer than the patch duration")
		assertClose(out.Speed, out.HitSpeed)
		assertClose(out.AverageDamage * out.Speed * out.DpsMultiplier, out.TotalDPS)

		newBuild()
		out = setupEarthquake(2, "100% reduced Skill Effect Duration\n200% increased Attack Speed")
		assert.are.equals(0, out.Duration)
		assertClose(out.AverageDamage * out.Speed * out.DpsMultiplier, out.TotalDPS)
	end)

	it("caps the Aftershock hit rate using the combined attack time when dual wielding", function()
		local weapons = { "Marauding Mace\n20% increased Attack Speed", "Marauding Mace" }
		local out = setupEarthquake(2, nil, weapons)
		assert.is_true(out.MainHand.Speed ~= out.OffHand.Speed, "test assumes the two weapons attack at different speeds")
		assertClose(1 / out.Duration, out.HitSpeed)
		assertClose(out.AverageDamage * out.HitSpeed * out.DpsMultiplier, out.TotalDPS)

		newBuild()
		out = setupEarthquake(2, "85% reduced Skill Effect Duration", weapons)
		assert.is_true(out.Speed < 1 / out.Duration, "test assumes the combined attack time is longer than the patch duration")
		assert.is_true(out.Speed ~= out.MainHand.Speed, "test assumes the combined attack rate differs from the main hand rate")
		assertClose(out.Speed, out.HitSpeed)
		assertClose(out.AverageDamage * out.Speed * out.DpsMultiplier, out.TotalDPS)
	end)

	it("applies additional aftershock chance to the Aftershock but not to the Impact", function()
		local aftershockMod = "25% chance for Slam Skills you use yourself to cause an additional Aftershock"
		local base = setupEarthquake(1)
		newBuild()
		local out = setupEarthquake(1, aftershockMod)
		assert.is_falsy(out.AftershockChance and out.AftershockChance > 0)
		assertClose(base.TotalDPS, out.TotalDPS)

		newBuild()
		base = setupEarthquake(2)
		newBuild()
		out = setupEarthquake(2, aftershockMod)
		assert.are.equals(25, out.AftershockChance)
		assertClose(base.TotalDPS * 1.25, out.TotalDPS)
	end)

	it("does not cap the Impact hit rate", function()
		local base = setupEarthquake(1)
		assert.is_nil(base.HitSpeed)

		newBuild()
		local out = setupEarthquake(1, "200% increased Attack Speed")
		assert.is_nil(out.HitSpeed)
		assertClose(base.TotalDPS * out.Speed / base.Speed, out.TotalDPS)
	end)
end)
