describe("TestLeech", function()
	before_each(function()
		newBuild()
		build.configTab.input.enemyLevel = 1
	end)

	local function setMods(mods)
		build.configTab.input.customMods = mods
		build.configTab:BuildModList()
		runCallback("OnFrame")
		return build.calcsTab.mainOutput
	end

	local hitMods = "Your hits can't be Evaded\nAdds 10 to 100 Physical Damage\nLeeches 10% of Physical Damage as Life\n"
	local baseMods = hitMods .. "Never deal Critical Hits\n"

	it("leeches a portion of hit damage over one second", function()
		local output = setMods(baseMods)
		assert.True(output.LifeLeechPerHit > 0)
		assert.are.near(0.1 * output.MainHand.PhysicalHitAverage, output.LifeLeechPerHit, 1e-9)
		assert.are.equals(1, output.LifeLeechDuration)
	end)

	it("only recovers from the strongest instance at a time", function()
		local output = setMods(baseMods)
		local hitRate = output.LifeLeechInstances / output.LifeLeechDuration
		assert.True(output.LifeLeechInstances > 1)
		assert.True(output.LifeLeechRate < output.LifeLeechPerHit * hitRate)
		-- the active instance rolls towards the top of the damage range
		assert.True(output.LifeLeechInstanceAmount > output.LifeLeechPerHit)
		assert.are.equals(output.LifeLeechInstanceAmount, output.LifeLeechRate)
	end)

	it("averages leech when instances do not overlap", function()
		local output = setMods(baseMods .. "75% reduced Attack Speed")
		local hitRate = output.LifeLeechInstances / output.LifeLeechDuration
		assert.True(output.LifeLeechInstances < 1)
		assert.are.near(output.LifeLeechPerHit * hitRate, output.LifeLeechRate, 1e-9)
	end)

	it("has no leech rate cap", function()
		local output = setMods(baseMods .. "Leeches 1000% of Physical Damage as Life")
		assert.True(output.LifeLeechRate > output.Life * 0.2)
	end)

	it("increases the amount leeched with amount modifiers", function()
		local base = setMods(baseMods).LifeLeechPerHit
		assert.are.near(base * 1.5, setMods(baseMods .. "50% increased amount of Life Leeched").LifeLeechPerHit, 1e-9)
		assert.are.near(base * 1.5, setMods(baseMods .. "50% more amount of Life Leeched").LifeLeechPerHit, 1e-9)
	end)

	it("slows leech without reducing the amount leeched", function()
		local base = setMods(baseMods).LifeLeechPerHit
		local output = setMods(baseMods .. "Leech Life 50% slower")
		assert.are.near(base, output.LifeLeechPerHit, 1e-9)
		assert.are.near(2, output.LifeLeechDuration, 1e-9)
		output = setMods(baseMods .. "Leech Life 67% less quickly")
		assert.are.near(1 / 0.33, output.LifeLeechDuration, 1e-9)
	end)

	it("treats hits above 40000 damage as 40000 damage", function()
		local output = setMods(baseMods .. "Adds 100000 to 100000 Physical Damage")
		assert.True(output.MainHand.PhysicalHitAverage > 40000)
		assert.are.near(4000, output.LifeLeechPerHit, 1e-6)
	end)

	it("shortens the duration with instant leech", function()
		local base = setMods(baseMods).LifeLeechPerHit
		local output = setMods(baseMods .. "25% of Leech is Instant")
		assert.are.near(base, output.LifeLeechPerHit, 1e-9)
		assert.are.near(base * 0.25, output.LifeLeechInstant, 1e-9)
		assert.are.near(0.75, output.LifeLeechDuration, 1e-9)
	end)

	it("is reduced by enemy leech resistance", function()
		local base = setMods(baseMods).LifeLeechPerHit
		build.configTab.input.enemyLevel = 83
		local output = setMods(baseMods)
		assert.are.near(base * (1 - data.monsterLeechResistanceTable[83] / 10000), output.LifeLeechPerHit, 1e-9)
		assert.True(output.LifeLeechPerHit < base)
	end)

	it("favours critical hits when instances overlap", function()
		local output = setMods(hitMods .. "+30% to Critical Hit Chance")
		local critChance = output.CritChance
		assert.True(critChance > 0 and critChance < 100)
		assert.True(output.LifeLeechInstances > 1)
		assert.True(output.LifeLeechCritActive > critChance)
	end)
end)
