describe("TestDefence", function()
	before_each(function()
		newBuild()
	end)

	teardown(function()
		-- newBuild() takes care of resetting everything in setup()
	end)
	
	local function pob1and2Compat()
		build.configTab.input.customMods = build.configTab.input.customMods.."\n\z
		5% reduced maximum life\n\z
		5% reduced maximum mana\n\z
		-2 to life\n\z
		-10% to elemental resistances\n\z
		-60% to chaos resistance\n\z
		+2 to mana\n\z
		"
		build.configTab:BuildModList()
		runCallback("OnFrame")
	end

	-- a small helper function to calculate damage taken from limited test parameters
	local function takenHitFromTypeMaxHit(type, enemyDamageMulti)
		return build.calcsTab.calcs.takenHitFromDamage(build.calcsTab.calcsOutput[type.."MaximumHitTaken"] * (enemyDamageMulti or 1), type, build.calcsTab.calcsEnv.player)
	end
	
	local function poolsRemainingAfterTypeMaxHit(type, enemyDamageMulti)
		local _, takenDamages = takenHitFromTypeMaxHit(type, enemyDamageMulti)
		return build.calcsTab.calcs.reducePoolsByDamage(nil, takenDamages, build.calcsTab.calcsEnv.player)
	end

	it("converts total energy shield modifiers to mana", function()
		build.configTab.input.customMods = "Convert 100% of maximum Energy Shield to maximum Mana\n100% increased maximum Mana"
		build.configTab:BuildModList()
		runCallback("OnFrame")

		local manaWithoutTotalEnergyShield = build.calcsTab.mainOutput.Mana
		local env = build.calcsTab.mainEnv
		local player = env.player

		player.modDB:NewMod("EnergyShieldTotal", "BASE", 100, "Test")
		player.output = { }
		build.calcsTab.calcs.defence(env, player)

		assert.are.equals(0, player.output.EnergyShield)
		assert.are.equals(0, player.modDB:Sum("BASE", nil, "ExtraMana"))
		assert.are.equals(100, player.modDB:Sum("BASE", nil, "ManaTotal"))
		assert.are.equals(manaWithoutTotalEnergyShield + 100, player.output.Mana)
	end)

	it("no armour max hits", function()
		build.configTab.input.enemyIsBoss = "None"
		build.configTab.input.customMods = ""
		pob1and2Compat()

		assert.are.equals(60, build.calcsTab.calcsOutput.PhysicalMaximumHitTaken)
		assert.are.equals(38, build.calcsTab.calcsOutput.FireMaximumHitTaken)
		assert.are.equals(38, build.calcsTab.calcsOutput.ColdMaximumHitTaken)
		assert.are.equals(38, build.calcsTab.calcsOutput.LightningMaximumHitTaken)
		assert.are.equals(38, build.calcsTab.calcsOutput.ChaosMaximumHitTaken)

		build.configTab.input.customMods = "\z
		+200 to all resistances\n\z
		200% additional Physical Damage Reduction\n\z
		"
		pob1and2Compat()
		assert.are.equals(600, build.calcsTab.calcsOutput.PhysicalMaximumHitTaken)
		assert.are.equals(240, build.calcsTab.calcsOutput.FireMaximumHitTaken)
		assert.are.equals(240, build.calcsTab.calcsOutput.ColdMaximumHitTaken)
		assert.are.equals(240, build.calcsTab.calcsOutput.LightningMaximumHitTaken)
		assert.are.equals(240, build.calcsTab.calcsOutput.ChaosMaximumHitTaken)

		build.configTab.input.customMods = "\z
		+200 to all resistances\n\z
		+200 to all maximum resistances\n\z
		200% additional Physical Damage Reduction\n\z
		"
		build.configTab.input.enemyPhysicalOverwhelm = 15 -- should result 75% DR
		pob1and2Compat()
		assert.are.equals(240, build.calcsTab.calcsOutput.PhysicalMaximumHitTaken)
		assert.are.equals(600, build.calcsTab.calcsOutput.FireMaximumHitTaken)
		assert.are.equals(600, build.calcsTab.calcsOutput.ColdMaximumHitTaken)
		assert.are.equals(600, build.calcsTab.calcsOutput.LightningMaximumHitTaken)
		assert.are.equals(600, build.calcsTab.calcsOutput.ChaosMaximumHitTaken)

		build.configTab.input.customMods = "\z
		+200 to all resistances\n\z
		+200 to all maximum resistances\n\z
		50% reduced damage taken\n\z
		"
		pob1and2Compat()
		assert.are.equals(120, build.calcsTab.calcsOutput.PhysicalMaximumHitTaken)
		assert.are.equals(1200, build.calcsTab.calcsOutput.FireMaximumHitTaken)
		assert.are.equals(1200, build.calcsTab.calcsOutput.ColdMaximumHitTaken)
		assert.are.equals(1200, build.calcsTab.calcsOutput.LightningMaximumHitTaken)
		assert.are.equals(1200, build.calcsTab.calcsOutput.ChaosMaximumHitTaken)

		build.configTab.input.customMods = "\z
		+200 to all resistances\n\z
		+200 to all maximum resistances\n\z
		50% reduced damage taken\n\z
		50% less damage taken\n\z
		"
		pob1and2Compat()
		assert.are.equals(240, build.calcsTab.calcsOutput.PhysicalMaximumHitTaken)
		assert.are.equals(2400, build.calcsTab.calcsOutput.FireMaximumHitTaken)
		assert.are.equals(2400, build.calcsTab.calcsOutput.ColdMaximumHitTaken)
		assert.are.equals(2400, build.calcsTab.calcsOutput.LightningMaximumHitTaken)
		assert.are.equals(2400, build.calcsTab.calcsOutput.ChaosMaximumHitTaken)

		build.configTab.input.customMods = "\z
		+200 to all resistances\n\z
		+200 to all maximum resistances\n\z
		50% reduced damage taken\n\z
		50% less damage taken\n\z
		Nearby enemies deal 20% less damage\n\z
		"
		pob1and2Compat()
		assert.are.equals(300, build.calcsTab.calcsOutput.PhysicalMaximumHitTaken)
		assert.are.equals(3000, build.calcsTab.calcsOutput.FireMaximumHitTaken)
		assert.are.equals(3000, build.calcsTab.calcsOutput.ColdMaximumHitTaken)
		assert.are.equals(3000, build.calcsTab.calcsOutput.LightningMaximumHitTaken)
		assert.are.equals(3000, build.calcsTab.calcsOutput.ChaosMaximumHitTaken)
		local poolsRemaining = poolsRemainingAfterTypeMaxHit("Lightning", 0.8)
		assert.are.equals(0, floor(poolsRemaining.Life))
		assert.are.equals(0, floor(poolsRemaining.OverkillDamage))

		build.configTab.input.customMods = "\z
		+200 to all resistances\n\z
		+200 to all maximum resistances\n\z
		50% reduced damage taken\n\z
		50% less damage taken\n\z
		Nearby enemies deal 20% less damage\n\z
		Gain 100% of life as extra maximum energy shield\n\z
		intelligence provides no bonus to energy shield\n\z
		"
		pob1and2Compat()
		assert.are.equals(600, build.calcsTab.calcsOutput.PhysicalMaximumHitTaken)
		assert.are.equals(6000, build.calcsTab.calcsOutput.FireMaximumHitTaken)
		assert.are.equals(6000, build.calcsTab.calcsOutput.ColdMaximumHitTaken)
		assert.are.equals(6000, build.calcsTab.calcsOutput.LightningMaximumHitTaken)
		assert.are.equals(4500, build.calcsTab.calcsOutput.ChaosMaximumHitTaken)
		assert.are.equals(0, floor(poolsRemaining.EnergyShield))
		assert.are.equals(0, floor(poolsRemaining.Life))
		assert.are.equals(0, floor(poolsRemaining.OverkillDamage))
	end)

	it("armoured max hits", function()
		build.configTab.input.enemyIsBoss = "None"
		build.configTab.input.customMods = "\z
		+940 to maximum life\n\z
		+10000 to armour\n\z
		" -- hit of 2000 on 10000 armour results in 50% DR which reduces the damage to 1000 - total HP
		pob1and2Compat()
		assert.are.equals(1000, takenHitFromTypeMaxHit("Physical"))
		assert.are.equals(625, build.calcsTab.calcsOutput.FireMaximumHitTaken)
		assert.are.equals(625, build.calcsTab.calcsOutput.ColdMaximumHitTaken)
		assert.are.equals(625, build.calcsTab.calcsOutput.LightningMaximumHitTaken)
		assert.are.equals(625, build.calcsTab.calcsOutput.ChaosMaximumHitTaken)

		build.configTab.input.customMods = "\z
		+940 to maximum life\n\z
		+100000 to armour\n\z
		" -- hit of 5000 on 100000 armour results in 80% DR which reduces the damage to 1000 - total HP
		pob1and2Compat()
		assert.are.equals(1000, takenHitFromTypeMaxHit("Physical"))
		assert.are.equals(625, build.calcsTab.calcsOutput.FireMaximumHitTaken)
		assert.are.equals(625, build.calcsTab.calcsOutput.ColdMaximumHitTaken)
		assert.are.equals(625, build.calcsTab.calcsOutput.LightningMaximumHitTaken)
		assert.are.equals(625, build.calcsTab.calcsOutput.ChaosMaximumHitTaken)

		build.configTab.input.customMods = "\z
		+940 to maximum life\n\z
		+1000000000 to armour\n\z
		" -- 90% DR cap
		pob1and2Compat()
		assert.are.equals(1000, takenHitFromTypeMaxHit("Physical"))
		assert.are.equals(625, build.calcsTab.calcsOutput.FireMaximumHitTaken)
		assert.are.equals(625, build.calcsTab.calcsOutput.ColdMaximumHitTaken)
		assert.are.equals(625, build.calcsTab.calcsOutput.LightningMaximumHitTaken)
		assert.are.equals(625, build.calcsTab.calcsOutput.ChaosMaximumHitTaken)

		build.configTab.input.customMods = "\z
		+940 to maximum life\n\z
		+1000000000 to armour\n\z
		" -- 90% DR cap
		build.configTab.input.enemyPhysicalOverwhelm = 15 -- should result 75% DR
		pob1and2Compat()
		assert.are.equals(1000, takenHitFromTypeMaxHit("Physical"))
		assert.are.equals(625, build.calcsTab.calcsOutput.FireMaximumHitTaken)
		assert.are.equals(625, build.calcsTab.calcsOutput.ColdMaximumHitTaken)
		assert.are.equals(625, build.calcsTab.calcsOutput.LightningMaximumHitTaken)
		assert.are.equals(625, build.calcsTab.calcsOutput.ChaosMaximumHitTaken)

		build.configTab.input.customMods = "\z
		+940 to maximum life\n\z
		+10000 to armour\n\z
		+60% to all elemental resistances\n\z
		Armour applies to Fire, Cold and Lightning Damage taken from Hits instead of Physical Damage\n\z
		" -- with no resistances results should be same as physical
		pob1and2Compat()
		assert.are.equals(1000, build.calcsTab.calcsOutput.PhysicalMaximumHitTaken)
		assert.are.equals(1000, takenHitFromTypeMaxHit("Fire"))
		assert.are.equals(1000, takenHitFromTypeMaxHit("Cold"))
		assert.are.equals(1000, takenHitFromTypeMaxHit("Lightning"))
		assert.are.equals(625, build.calcsTab.calcsOutput.ChaosMaximumHitTaken)

		build.configTab.input.customMods = "\z
		+940 to maximum life\n\z
		+10000 to armour\n\z
		+110% to all elemental resistances\n\z
		Armour applies to Fire, Cold and Lightning Damage taken from Hits instead of Physical Damage\n\z
		" -- max hit should be 4000
		-- [max] [res]     [armour] [armour]      [max]  [res]
		-- 4000 * 0.5 * (1 - 10000 / (10000 + 5 * 4000 * 0.5)) = 1000
		pob1and2Compat()
		assert.are.equals(1000, build.calcsTab.calcsOutput.PhysicalMaximumHitTaken)
		assert.are.equals(1000, takenHitFromTypeMaxHit("Fire"))
		assert.are.equals(1000, takenHitFromTypeMaxHit("Cold"))
		assert.are.equals(1000, takenHitFromTypeMaxHit("Lightning"))
		assert.are.equals(625, build.calcsTab.calcsOutput.ChaosMaximumHitTaken)

		build.configTab.input.customMods = "\z
		+940 to maximum life\n\z
		+10000 to armour\n\z
		+110% to all elemental resistances\n\z
		Armour applies to Fire, Cold and Lightning Damage taken from Hits instead of Physical Damage\n\z
		50% less damage taken\n\z
		" -- max hit should be 6472
		-- [max] [res]     [armour] [armour]      [max]  [res]  [less]
		-- 6472 * 0.5 * (1 - 10000 / (10000 + 5 * 6472 * 0.5)) * 0.5 = 1000
		pob1and2Compat()
		assert.are.equals(2000, build.calcsTab.calcsOutput.PhysicalMaximumHitTaken)
		assert.are.equals(1000, takenHitFromTypeMaxHit("Fire"))
		assert.are.equals(1000, takenHitFromTypeMaxHit("Cold"))
		assert.are.equals(1000, takenHitFromTypeMaxHit("Lightning"))
		assert.are.equals(1250, build.calcsTab.calcsOutput.ChaosMaximumHitTaken)
	end)
	
	local function withinTenPercent(value, otherValue)
		local ratio = otherValue / value
		return 0.9 < ratio and ratio < 1.1
	end

	it("damage conversion max hits", function()
		build.configTab.input.enemyIsBoss = "None"

		build.configTab.input.customMods = "\z
		+940 to maximum life\n\z
		+200 to all resistances\n\z
		+200 to all maximum resistances\n\z
		50% reduced damage taken\n\z
		50% less damage taken\n\z
		50% of physical damage taken as fire\n\z
		"
		pob1and2Compat()
		assert.is.not_false(withinTenPercent(1000, takenHitFromTypeMaxHit("Physical")))

		build.configTab.input.customMods = "\z
		+940 to maximum life\n\z
		+200 to all resistances\n\z
		+200 to all maximum resistances\n\z
		50% reduced damage taken\n\z
		50% less damage taken\n\z
		50% of physical damage taken as fire\n\z
		50% of cold damage taken as fire\n\z
		"
		pob1and2Compat()
		assert.is.not_false(withinTenPercent(1000, takenHitFromTypeMaxHit("Physical")))
		assert.is.not_false(withinTenPercent(1000, takenHitFromTypeMaxHit("Cold")))

		build.configTab.input.customMods = "\z
		+940 to maximum life\n\z
		+10000 to armour\n\z
		+110% to all elemental resistances\n\z
		Armour applies to Fire, Cold and Lightning Damage taken from Hits instead of Physical Damage\n\z
		50% of physical damage taken as fire\n\z
		50% of cold damage taken as fire\n\z
		"
		pob1and2Compat()
		assert.is.not_false(withinTenPercent(1000, takenHitFromTypeMaxHit("Physical")))
		assert.is.not_false(withinTenPercent(1000, takenHitFromTypeMaxHit("Cold")))

		build.configTab.input.customMods = "\z
		+940 to maximum life\n\z
		+10000 to armour\n\z
		+110% to all elemental resistances\n\z
		Armour applies to Fire, Cold and Lightning Damage taken from Hits instead of Physical Damage\n\z
		50% of physical damage taken as fire\n\z
		50% of cold damage taken as fire\n\z
		50% less fire damage taken\n\z
		"
		pob1and2Compat()
		assert.is.not_false(withinTenPercent(1000, takenHitFromTypeMaxHit("Physical")))
		assert.is.not_false(withinTenPercent(1000, takenHitFromTypeMaxHit("Cold")))

		build.configTab.input.customMods = "\z
		+940 to maximum life\n\z
		+10000 to armour\n\z
		+110% to fire resistance\n\z
		Armour applies to Fire, Cold and Lightning Damage taken from Hits instead of Physical Damage\n\z
		100% of cold damage taken as fire\n\z
		50% of lightning damage taken as fire\n\z
		50% less fire damage taken\n\z
		"
		pob1and2Compat()
		assert.is.not_false(withinTenPercent(1000, takenHitFromTypeMaxHit("Physical")))
		assert.is.not_false(withinTenPercent(1000, takenHitFromTypeMaxHit("Cold")))

		build.configTab.input.customMods = "\z
		+99 to energy shield\n\z
		100% less attributes\n\z
		+60% to all elemental resistances\n\z
		25% of Elemental Damage from Hits taken as Chaos Damage\n\z
		Chaos Inoculation\n\z
		"
		pob1and2Compat()
		local poolsRemaining = poolsRemainingAfterTypeMaxHit("Cold")
		assert.are.equals(0, floor(poolsRemaining.Life))
		assert.are.equals(0, floor(poolsRemaining.OverkillDamage))
	end)
	
	it("damage conversion to different size pools", function()
		-- conversion into a smaller pool
		build.configTab.input.customMods = "\z
		+40 to maximum life\n\z
		+950 to mana\n\z
		+10000 to armour\n\z
		+110% to all elemental resistances\n\z
		Armour applies to Fire, Cold and Lightning Damage taken from Hits instead of Physical Damage\n\z
		100% of Lightning Damage is taken from Mana before Life\n\z
		10% of lightning damage taken as cold damage\n\z
		"   -- Small amount of conversion into a smaller pool leads to the higher pool damage type (lightning) draining it's own excess pool (mana), and then joining back on the shared pools (life)
		pob1and2Compat()
		local poolsRemaining = poolsRemainingAfterTypeMaxHit("Lightning")
		assert.are.equals(0, floor(poolsRemaining.Mana))
		assert.are.equals(0, floor(poolsRemaining.Life))
		assert.are.equals(0, floor(poolsRemaining.OverkillDamage))

		build.configTab.input.customMods = "\z
		+140 to maximum life\n\z
		+950 to mana\n\z
		+10000 to armour\n\z
		+110% to all elemental resistances\n\z
		Armour applies to Fire, Cold and Lightning Damage taken from Hits instead of Physical Damage\n\z
		100% of Lightning Damage is taken from Mana before Life\n\z
		20% of lightning damage taken as cold damage\n\z
		"   -- This is a case where cold damage drains the whole life pool and lightning damage drains the entire mana pool, leaving nothing
		pob1and2Compat()
		poolsRemaining = poolsRemainingAfterTypeMaxHit("Lightning")
		assert.are.equals(0, floor(poolsRemaining.Mana))
		assert.are.equals(0, floor(poolsRemaining.Life))
		assert.are.equals(0, floor(poolsRemaining.OverkillDamage))

		build.configTab.input.customMods = "\z
		+40 to maximum life\n\z
		+1950 to mana\n\z
		+10000 to armour\n\z
		+110% to all elemental resistances\n\z
		Armour applies to Fire, Cold and Lightning Damage taken from Hits instead of Physical Damage\n\z
		100% of Lightning Damage is taken from Mana before Life\n\z
		20% of lightning damage taken as cold damage\n\z
		"   -- Any extra mana in this case will not help and be left over after death, since life hits 0 from the cold damage alone
		pob1and2Compat()
		poolsRemaining = poolsRemainingAfterTypeMaxHit("Lightning")
		assert.are.not_false(1000 < round(poolsRemaining.Mana))
		assert.are.equals(0, floor(poolsRemaining.Life))
		assert.are.equals(0, floor(poolsRemaining.OverkillDamage))

		-- conversion into a bigger pool
		build.configTab.input.customMods = "\z
		+40 to maximum life\n\z
		+950 to mana\n\z
		+10000 to armour\n\z
		+110% to all elemental resistances\n\z
		Armour applies to Fire, Cold and Lightning Damage taken from Hits instead of Physical Damage\n\z
		100% of Lightning Damage is taken from Mana before Life\n\z
		90% of cold damage taken as lightning damage\n\z
		"   -- With inverted conversion amounts the behaviour of converting into a bigger pool should be exactly the same as converting into a lower one.
		pob1and2Compat()
		poolsRemaining = poolsRemainingAfterTypeMaxHit("Cold")
		assert.are.equals(0, floor(poolsRemaining.Mana))
		assert.are.equals(0, floor(poolsRemaining.Life))
		assert.are.equals(0, floor(poolsRemaining.OverkillDamage))

		build.configTab.input.customMods = "\z
		+140 to maximum life\n\z
		+950 to mana\n\z
		+10000 to armour\n\z
		+110% to all elemental resistances\n\z
		Armour applies to Fire, Cold and Lightning Damage taken from Hits instead of Physical Damage\n\z
		100% of Lightning Damage is taken from Mana before Life\n\z
		80% of cold damage taken as lightning damage\n\z
		"
		pob1and2Compat()
		poolsRemaining = poolsRemainingAfterTypeMaxHit("Cold")
		assert.are.equals(0, floor(poolsRemaining.Mana))
		assert.are.equals(0, floor(poolsRemaining.Life))
		assert.are.equals(0, floor(poolsRemaining.OverkillDamage))

		build.configTab.input.customMods = "\z
		+40 to maximum life\n\z
		+1950 to mana\n\z
		+10000 to armour\n\z
		+110% to all elemental resistances\n\z
		Armour applies to Fire, Cold and Lightning Damage taken from Hits instead of Physical Damage\n\z
		100% of Lightning Damage is taken from Mana before Life\n\z
		80% of cold damage taken as lightning damage\n\z
		"
		pob1and2Compat()
		poolsRemaining = poolsRemainingAfterTypeMaxHit("Cold")
		assert.are.not_false(1000 < round(poolsRemaining.Mana))
		assert.are.equals(0, floor(poolsRemaining.Life))
		assert.are.equals(0, floor(poolsRemaining.OverkillDamage))

		build.configTab.input.customMods = "\z
		+940 to maximum life\n\z
		+950 to mana\n\z
		+1000 to energy shield\n\z
		+10000 to armour\n\z
		+110% to all elemental resistances\n\z
		Armour applies to Fire, Cold and Lightning Damage taken from Hits instead of Physical Damage\n\z
		100% of Lightning Damage is taken from Mana before Life\n\z
		80% of cold damage taken as lightning damage\n\z
		50% of fire damage taken as chaos damage\n\z
		"
		pob1and2Compat()
		poolsRemaining = poolsRemainingAfterTypeMaxHit("Cold")
		assert.are.equals(0, floor(poolsRemaining.EnergyShield))
		assert.are.equals(0, floor(poolsRemaining.Mana))
		assert.are.not_false(1 >= floor(poolsRemaining.Life))
		assert.are.equals(0, floor(poolsRemaining.OverkillDamage))
		poolsRemaining = poolsRemainingAfterTypeMaxHit("Fire")
		assert.are.equals(0, floor(poolsRemaining.EnergyShield))
		assert.are.equals(1000, floor(poolsRemaining.Mana))
		assert.are.not_false(1 >= floor(poolsRemaining.Life))
		assert.are.equals(0, floor(poolsRemaining.OverkillDamage))
	end)

	it("energy shield bypass tests #pet", function()
		build.configTab.input.enemyIsBoss = "None"
		build.configTab.input.customMods = [[
			+40 to maximum life
			+300 to energy shield
			50% of damage taken bypasses energy shield
			You have no intelligence
			+60% to all resistances
		]]
		pob1and2Compat()
		local poolsRemaining = poolsRemainingAfterTypeMaxHit("Chaos")
		assert.are.equals(100, round(poolsRemaining.EnergyShield))
		assert.are.equals(0, floor(poolsRemaining.Life))
		assert.are.equals(0, floor(poolsRemaining.OverkillDamage))
		assert.are.equals(200, build.calcsTab.calcsOutput.FireMaximumHitTaken)
		assert.are.equals(200, build.calcsTab.calcsOutput.ChaosMaximumHitTaken)

		-- Make sure we can't reach over 100% bypass
		build.configTab.input.customMods = [[
			+40 to maximum life
			+100 to energy shield
			physical damage taken bypasses energy shield
			You have no intelligence
			+60% to all resistances
		]]
		pob1and2Compat()
		assert.are.equals(100, build.calcsTab.calcsOutput.PhysicalMaximumHitTaken)
		assert.are.equals(200, build.calcsTab.calcsOutput.FireMaximumHitTaken)
		assert.are.equals(150, build.calcsTab.calcsOutput.ChaosMaximumHitTaken)
		poolsRemaining = poolsRemainingAfterTypeMaxHit("Physical")
		assert.are.equals(100, floor(poolsRemaining.EnergyShield))
		assert.are.equals(0, floor(poolsRemaining.Life))
		assert.are.equals(0, floor(poolsRemaining.OverkillDamage))
		poolsRemaining = poolsRemainingAfterTypeMaxHit("Chaos")
		assert.are.equals(0, floor(poolsRemaining.EnergyShield))
		assert.are.equals(0, floor(poolsRemaining.Life))
		assert.are.equals(0, floor(poolsRemaining.OverkillDamage))
		-- Chaos damage should still bypass
		build.configTab.input.customMods = build.configTab.input.customMods .. "\nAll damage taken bypasses energy shield"
		build.configTab:BuildModList()
		runCallback("OnFrame")
		assert.are.equals(100, build.calcsTab.calcsOutput.PhysicalMaximumHitTaken)
		assert.are.equals(100, build.calcsTab.calcsOutput.FireMaximumHitTaken)
		assert.are.equals(100, build.calcsTab.calcsOutput.ChaosMaximumHitTaken)
		poolsRemaining = poolsRemainingAfterTypeMaxHit("Physical")
		assert.are.equals(100, floor(poolsRemaining.EnergyShield))
		assert.are.equals(0, floor(poolsRemaining.Life))
		assert.are.equals(0, floor(poolsRemaining.OverkillDamage))
		poolsRemaining = poolsRemainingAfterTypeMaxHit("Chaos")
		assert.are.equals(100, round(poolsRemaining.EnergyShield))
		assert.are.equals(0, floor(poolsRemaining.Life))
		assert.are.equals(0, floor(poolsRemaining.OverkillDamage))

		-- Bypass + MoM
		build.configTab.input.customMods = [[
			+40 to maximum life
			+50 to mana
			+200 to energy shield
			50% of damage taken bypasses energy shield
			50% of Lightning Damage is taken from Mana before Life
			intelligence provides no bonus to energy shield
			+60% to all resistances
		]]
		pob1and2Compat()
		assert.are.equals(400, build.calcsTab.calcsOutput.LightningMaximumHitTaken)
		assert.are.equals(200, build.calcsTab.calcsOutput.FireMaximumHitTaken)
		assert.are.equals(200, build.calcsTab.calcsOutput.ChaosMaximumHitTaken)
		poolsRemaining = poolsRemainingAfterTypeMaxHit("Chaos")
		assert.are.equals(0, round(poolsRemaining.EnergyShield))
		assert.are.equals(0, floor(poolsRemaining.Life))
		assert.are.equals(0, floor(poolsRemaining.OverkillDamage))
		poolsRemaining = poolsRemainingAfterTypeMaxHit("Fire")
		assert.are.equals(100, round(poolsRemaining.EnergyShield))
		assert.are.equals(0, floor(poolsRemaining.Life))
		assert.are.equals(0, floor(poolsRemaining.OverkillDamage))
		poolsRemaining = poolsRemainingAfterTypeMaxHit("Lightning")
		assert.are.equals(0, round(poolsRemaining.EnergyShield))
		assert.are.equals(0, floor(poolsRemaining.Mana))
		assert.are.equals(0, floor(poolsRemaining.Life))
		assert.are.equals(0, floor(poolsRemaining.OverkillDamage))

		build.configTab.input.customMods = [[
			+40 to maximum life
			+150 to mana
			+300 to energy shield
			50% of damage taken bypasses energy shield
			50% of Lightning Damage is taken from Mana before Life
			intelligence provides no bonus to energy shield
			+60% to all resistances
		]]
		pob1and2Compat()
		assert.are.equals(400, build.calcsTab.calcsOutput.LightningMaximumHitTaken)
		assert.are.equals(200, build.calcsTab.calcsOutput.FireMaximumHitTaken)
		assert.are.equals(200, build.calcsTab.calcsOutput.ChaosMaximumHitTaken)
		poolsRemaining = poolsRemainingAfterTypeMaxHit("Chaos")
		assert.are.equals(100, round(poolsRemaining.EnergyShield))
		assert.are.equals(0, floor(poolsRemaining.Life))
		assert.are.equals(0, floor(poolsRemaining.OverkillDamage))
		poolsRemaining = poolsRemainingAfterTypeMaxHit("Fire")
		assert.are.equals(200, round(poolsRemaining.EnergyShield))
		assert.are.equals(0, floor(poolsRemaining.Life))
		assert.are.equals(0, floor(poolsRemaining.OverkillDamage))
		poolsRemaining = poolsRemainingAfterTypeMaxHit("Lightning")
		assert.are.equals(100, round(poolsRemaining.EnergyShield))
		assert.are.equals(100, floor(poolsRemaining.Mana))
		assert.are.equals(0, floor(poolsRemaining.Life))
		assert.are.equals(0, floor(poolsRemaining.OverkillDamage))
	end)
	
	it("uses block chance against projectile spells", function()
		build.configTab.input.enemyIsBoss = "None"
		build.configTab.input.enemyDamageType = "SpellProjectile"
		build.configTab.input.customMods = [[
			20% chance to block
		]]
		build.configTab:BuildModList()
		runCallback("OnFrame")

		assert.are.equals(20, build.calcsTab.calcsOutput.EffectiveBlockChance)
		assert.are.equals(20, build.calcsTab.calcsOutput.EffectiveProjectileBlockChance)
		assert.are.equals(20, build.calcsTab.calcsOutput.EffectiveSpellProjectileBlockChance)
		assert.are.equals(80, build.calcsTab.calcsOutput.ConfiguredDamageChance)

		build.configTab.input.enemyDamageType = "Average"
		build.configTab:BuildModList()
		runCallback("OnFrame")

		assert.are.equals(15, build.calcsTab.calcsOutput.EffectiveAverageBlockChance)
		assert.are.equals(85, build.calcsTab.calcsOutput.ConfiguredDamageChance)
	end)

	it("limits EHP speedup when hit damage is delayed", function()
		local function assertClose(actual, expected)
			assert.is_true(math.abs(actual - expected) < 0.01)
		end

		local function calcEHP(extraMods)
			build.configTab.input.enemyPhysicalDamage = "500"
			build.configTab.input.enemyFireDamage = "500"
			build.configTab.input.enemyColdDamage = "500"
			build.configTab.input.enemyLightningDamage = "500"
			build.configTab.input.enemyChaosDamage = "0"
			build.configTab.input.customMods = [[
				+4000 to maximum Life
				75% of Life Loss from Hits is prevented, then that much Life is lost over 4 seconds instead
				+75% to all Elemental Resistances
				+75% to Chaos Resistance
				]] .. (extraMods or "")
			pob1and2Compat()
			runCallback("OnFrame")
			runCallback("OnFrame")
			local calcsOutput = build.calcsTab.calcsOutput
			return {
				TotalEHP = calcsOutput.TotalEHP,
				EffectiveBlockChance = calcsOutput.EffectiveBlockChance,
				NumberOfMitigatedDamagingHits = calcsOutput.NumberOfMitigatedDamagingHits,
			}
		end

		local base = calcEHP()
		local block = calcEHP("\n+10% to Block chance\n")

		newBuild()

		assertClose(base.TotalEHP, 17582.417582418)
		assertClose(block.TotalEHP, 19008.019008019)
		assertClose(block.EffectiveBlockChance, 10)
		assert.is_true(block.TotalEHP > base.TotalEHP)
	end)

	describe("damage taken from companion's life before you", function()
		it("redirects damage to the configured companion life pool", function()
			build.configTab.input.enemyIsBoss = "None"
			build.configTab.input.customMods = ""
			pob1and2Compat()
			local baseMaxHit = build.calcsTab.calcsOutput.PhysicalMaximumHitTaken

			build.configTab.input.customMods = "15% of Damage from Hits is taken from your Damageable Companion's Life before you"
			build.configTab.input.TotalCompanionLife = 1000
			pob1and2Compat()

			local output = build.calcsTab.calcsOutput
			assert.are.equals(15, output.CompanionAllyDamageMitigation)
			assert.are.equals(1000, output.TotalCompanionLife)
			assert.is_true(output.PhysicalMaximumHitTaken > baseMaxHit)

			local totalTaken = takenHitFromTypeMaxHit("Physical")
			local pools = poolsRemainingAfterTypeMaxHit("Physical")
			local drained = 1000 - pools.AlliesTakenBeforeYou["companion"].remaining
			assert.are.near(totalTaken * 0.15, drained, 1)
		end)

		it("stacks redirect sources additively", function()
			build.configTab.input.enemyIsBoss = "None"
			build.configTab.input.customMods = "\z
			5% of Damage from Hits is taken from your Damageable Companion's Life before you\n\z
			15% of Damage from Hits is taken from your Damageable Companion's Life before you\n\z
			"
			build.configTab.input.TotalCompanionLife = 100
			pob1and2Compat()

			assert.are.equals(20, build.calcsTab.calcsOutput.CompanionAllyDamageMitigation)
		end)

		it("scales the deflected-hits redirect by deflect chance", function()
			build.configTab.input.enemyIsBoss = "None"
			build.configTab.input.customMods = "\z
			10% of Damage from Deflected Hits is taken from Damageable Companion's Life before you\n\z
			+1000 to Deflection Rating\n\z
			"
			build.configTab.input.TotalCompanionLife = 500
			pob1and2Compat()

			local output = build.calcsTab.calcsOutput
			assert.is_true(output.DeflectChance > 0)
			assert.are.near(10 * output.DeflectChance / 100, output.CompanionAllyDamageMitigation, 0.001)
		end)

		it("sums companion life automatically and applies Loyalty's redirect and life penalty", function()
			build.skillsTab:PasteSocketGroup("Companion: Lightless Abomination 20/0  1")
			runCallback("OnFrame")
			local unsupportedLife = build.calcsTab.calcsEnv.minion.output.Life

			newBuild()
			build.skillsTab:PasteSocketGroup("Companion: Lightless Abomination 20/0  1\nLoyalty 1/0  1")
			runCallback("OnFrame")

			local output = build.calcsTab.calcsOutput
			local companionLife = build.calcsTab.calcsEnv.minion.output.Life
			assert.are.equals(10, output.CompanionAllyDamageMitigation)
			assert.are.equals(companionLife, output.TotalCompanionLife)
			assert.are.near(unsupportedLife * 0.7, companionLife, 1)
		end)

		it("sums companion life when the companion is not the main skill", function()
			build.skillsTab:PasteSocketGroup("Companion: Lightless Abomination 20/0  1\nLoyalty 1/0  1")
			runCallback("OnFrame")
			local mainSkillCompanionLife = build.calcsTab.calcsOutput.TotalCompanionLife

			newBuild()
			build.skillsTab:PasteSocketGroup("Quarterstaff Strike 20/0  1")
			build.skillsTab:PasteSocketGroup("Companion: Lightless Abomination 20/0  1\nLoyalty 1/0  1")
			build.mainSocketGroup = 1
			runCallback("OnFrame")

			local output = build.calcsTab.calcsOutput
			assert.are.equals(10, output.CompanionAllyDamageMitigation)
			assert.are.near(mainSkillCompanionLife, output.TotalCompanionLife, 1)
		end)

		it("has no effect with no companions and no config override", function()
			build.configTab.input.enemyIsBoss = "None"
			build.configTab.input.customMods = ""
			pob1and2Compat()
			local baseMaxHit = build.calcsTab.calcsOutput.PhysicalMaximumHitTaken

			build.configTab.input.customMods = "15% of Damage from Hits is taken from your Damageable Companion's Life before you"
			pob1and2Compat()

			assert.are.equals(0, build.calcsTab.calcsOutput.TotalCompanionLife)
			assert.are.equals(baseMaxHit, build.calcsTab.calcsOutput.PhysicalMaximumHitTaken)
		end)
	end)
end)
