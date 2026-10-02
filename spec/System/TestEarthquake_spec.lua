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

	-- Jagged Ground cannot be created on top of an existing patch: an attack that lands before the previous patch
	-- erupts creates nothing, so the next patch (and its Aftershock) comes from the first attack at or after the eruption
	local function expectedHitTime(out)
		local attackTime = 1 / out.Speed
		return attackTime * math.max(math.ceil(out.Duration / attackTime - 1e-9), 1)
	end

	it("fires the Aftershock on every Nth attack, N being the attack times needed to cover the patch duration", function()
		local out = setupEarthquake(2)
		assert.is_true(out.Duration > 0)
		assert.is_true(out.Speed > 1 / out.Duration, "test assumes attack time is shorter than the patch duration")
		assertClose(expectedHitTime(out), out.HitTime)
		assertClose(1 / out.HitTime, out.HitSpeed)
		assert.is_true(out.HitTime >= out.Duration - 0.001, "no patch can be created before the previous one erupts")
		assert.is_true(out.HitTime - 1 / out.Speed < out.Duration, "the first attack after the eruption creates the next patch")
		assertClose(out.AverageDamage * out.HitSpeed * out.DpsMultiplier, out.TotalDPS)
		assert.is_falsy(build.calcsTab.mainEnv.player.mainSkill.skillData.showAverage)
	end)

	it("rounds the Aftershock time up to a whole number of attacks for any patch duration", function()
		for _, reduced in ipairs({ 30, 50, 70, 80, 90 }) do
			newBuild()
			local out = setupEarthquake(2, reduced .. "% reduced Skill Effect Duration")
			assertClose(expectedHitTime(out), out.HitTime)
			assertClose(out.AverageDamage / out.HitTime * out.DpsMultiplier, out.TotalDPS)
		end
	end)

	it("wastes every other attack when the patch outlasts the attack time", function()
		local base = setupEarthquake(2)
		local attackTime = 1 / base.Speed
		-- shorten the patch to 1.5 attack times: the second attack lands on the live patch and creates nothing
		local reduced = math.floor(100 * (1 - 1.5 * attackTime / base.Duration))
		newBuild()
		local out = setupEarthquake(2, reduced .. "% reduced Skill Effect Duration")
		assert.is_true(out.Duration > attackTime and out.Duration < 2 * attackTime, "test assumes the patch lasts between one and two attack times")
		assertClose(2 * attackTime, out.HitTime)
		assertClose(base.Speed / 2, out.HitSpeed)
	end)

	it("lowers Aftershock DPS when attacking slightly faster than the patch duration", function()
		local base = setupEarthquake(2)
		local attackTime = 1 / base.Speed
		-- patch just shorter than the attack time: every attack creates a patch
		local reduced = math.ceil(100 * (1 - 0.95 * attackTime / base.Duration))
		newBuild()
		local slow = setupEarthquake(2, reduced .. "% reduced Skill Effect Duration")
		assert.is_true(slow.Duration <= 1 / slow.Speed, "test assumes the patch erupts before the next attack")
		assertClose(slow.Speed, slow.HitSpeed)
		-- 10% more attack speed makes the next attack land on the live patch, halving the Aftershock rate
		newBuild()
		local fast = setupEarthquake(2, reduced .. "% reduced Skill Effect Duration\n10% increased Attack Speed")
		assert.is_true(fast.Speed > slow.Speed)
		assert.is_true(fast.Duration > 1 / fast.Speed, "test assumes the next attack now lands before the eruption")
		assertClose(fast.Speed / 2, fast.HitSpeed)
		assert.is_true(fast.TotalDPS < slow.TotalDPS)
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

	it("rounds the Aftershock time using the combined attack time when dual wielding", function()
		local weapons = { "Marauding Mace\n20% increased Attack Speed", "Marauding Mace" }
		local out = setupEarthquake(2, nil, weapons)
		assert.is_true(out.MainHand.Speed ~= out.OffHand.Speed, "test assumes the two weapons attack at different speeds")
		assertClose(expectedHitTime(out), out.HitTime)
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
