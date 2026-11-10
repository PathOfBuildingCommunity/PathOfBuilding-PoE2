describe("TestLeech", function()
	-- Punch with a large flat hit that always lands and never crits, so each hit deals exactly out.AverageDamage
	local baseMods = [[
Never deal Critical Hits
+100000 to Accuracy Rating
Adds 1000 to 1000 Physical Damage to Attacks
]]

	local function calcWith(mods)
		build.configTab.input.customMods = baseMods .. mods
		build.configTab:BuildModList()
		runCallback("OnFrame")
		local out = build.calcsTab.mainOutput
		assert.are.equals(100, out.HitChance)
		return out
	end

	before_each(function()
		newBuild()
	end)

	it("leeches a percentage of hit damage without a cap based on the size of the pool", function()
		local out = calcWith("Leech 10% of Physical Attack Damage as Life")
		-- 10% of maximum Life was the PoE1 per-instance cap
		assert.is_true(out.AverageDamage * 0.1 > out.Life * 0.1)
		assert.are.near(out.AverageDamage * 0.1, out.LifeLeechPerHit, 0.01)
	end)

	it("increased amount of Life Leeched multiplies the amount leeched per hit", function()
		local out = calcWith("Leech 10% of Physical Attack Damage as Life\n50% increased amount of Life Leeched")
		assert.are.near(out.AverageDamage * 0.1 * 1.5, out.LifeLeechPerHit, 0.01)
	end)

	it("increased amount of Mana Leeched multiplies the amount leeched per hit", function()
		local out = calcWith("Leech 10% of Physical Attack Damage as Mana\n50% increased amount of Mana Leeched")
		assert.are.near(out.AverageDamage * 0.1 * 1.5, out.ManaLeechPerHit, 0.01)
	end)

	it("recovers one leech instance at a time, so hitting more than once per second does not raise the rate", function()
		local out = calcWith("Leech 10% of Physical Attack Damage as Life")
		assert.is_true(out.Speed > 1)
		-- one instance recovers its whole amount over 1 second
		assert.are.near(out.AverageDamage * 0.1, out.LifeLeechRate, 0.01)

		newBuild()
		local fastOut = calcWith("Leech 10% of Physical Attack Damage as Life\n100% increased Attack Speed")
		assert.are.near(out.LifeLeechRate, fastOut.LifeLeechRate, 0.01)
	end)

	it("scales the leech rate with hit rate when hitting less than once per second", function()
		local out = calcWith("Leech 10% of Physical Attack Damage as Life\n75% reduced Attack Speed")
		assert.is_true(out.Speed < 1)
		assert.are.near(out.AverageDamage * 0.1 * out.Speed, out.LifeLeechRate, 0.01)
	end)

	it("faster leech shortens each instance instead of adding recovery", function()
		local out = calcWith("Leech 10% of Physical Attack Damage as Life\nLeech Life 50% faster")
		assert.is_true(out.Speed > 1.5)
		assert.are.near(out.AverageDamage * 0.1, out.LifeLeechPerHit, 0.01)
		assert.are.near(1 / 1.5, out.LifeLeechDuration, 0.0001)
		-- the single active instance recovers 1.5x its amount per second and is always refreshed
		assert.are.near(out.AverageDamage * 0.1 * 1.5, out.LifeLeechRate, 0.01)
	end)

	it("recovers the instant share immediately and the rest over the remaining duration", function()
		local out = calcWith("Leech 10% of Physical Attack Damage as Life\n20% of Leech is Instant")
		assert.are.near(out.AverageDamage * 0.1 * 0.2, out.LifeLeechInstant, 0.01)
		assert.are.near(0.8, out.LifeLeechDuration, 0.0001)
		assert.are.near(out.AverageDamage * 0.1, out.LifeLeechPerHit, 0.01)
	end)

	it("treats hits above 40,000 damage as dealing 40,000 damage", function()
		local out = calcWith("Leech 10% of Physical Attack Damage as Life\nAdds 100000 to 100000 Physical Damage to Attacks")
		assert.is_true(out.AverageDamage > 40000)
		assert.are.near(4000, out.LifeLeechPerHit, 0.01)
	end)

	it("scales every damage type of a capped hit evenly", function()
		local out = calcWith("Leech 10% of Physical Attack Damage as Life\nAdds 100000 to 100000 Physical Damage to Attacks\nAdds 100000 to 100000 Fire Damage to Attacks")
		local physical = out.MainHand.PhysicalHitAverage
		local fire = out.MainHand.FireHitAverage
		assert.is_true(fire > 0)
		assert.are.near(4000 * physical / (physical + fire), out.LifeLeechPerHit, 0.01)
	end)

	it("explains the single active instance and its uptime in the leech rate breakdown", function()
		local out = calcWith("Leech 10% of Physical Attack Damage as Life\n75% reduced Attack Speed")
		local lines = build.calcsTab.calcsEnv.player.breakdown.LifeLeech
		local text = table.concat(lines, "\n")
		assert.truthy(text:find("Only one instance recovers at a time", 1, true))
		assert.truthy(text:find(string.format("%.2f hits per second", out.Speed), 1, true))
		assert.truthy(lines[#lines]:find(string.format("%.1f", out.LifeLeechRate), 1, true))
	end)

	it("averages the leech of both weapons when dual wielding hits once with each weapon", function()
		build.skillsTab:PasteSocketGroup("skillId:MeleeMaceMacePlayer Mace Strike 20/0  1")
		build.itemsTab:CreateDisplayItemFromRaw("New Item\nMarauding Mace\nQuality: 0\nAdds 500 to 500 Physical Damage")
		build.itemsTab:AddDisplayItem()
		build.itemsTab:CreateDisplayItemFromRaw("New Item\nMarauding Mace\nQuality: 0")
		build.itemsTab:AddDisplayItem()
		local out = calcWith("Leech 10% of Physical Attack Damage as Life")
		assert.is_true(build.calcsTab.mainEnv.player.mainSkill.activeEffect.statSet.skillFlags.bothWeaponAttack)
		local mainHandLeech = out.MainHand.AverageDamage * 0.1
		local offHandLeech = out.OffHand.AverageDamage * 0.1
		assert.is_true(mainHandLeech > offHandLeech)
		assert.are.near((mainHandLeech + offHandLeech) / 2, out.LifeLeechPerHit, 0.01)
		-- each use hits once with each weapon, so an instance is always active while using the skill at least twice per second
		assert.is_true(out.Speed > 0.5)
		assert.are.near((mainHandLeech + offHandLeech) / 2, out.LifeLeechRate, 0.01)
	end)

	it("applies 'Leech X% faster' to life, mana and energy shield leech", function()
		local out = calcWith("Leech 10% of Physical Attack Damage as Life\nLeech 10% of Physical Attack Damage as Mana\nLeech 30% faster")
		assert.are.near(1 / 1.3, out.LifeLeechDuration, 0.0001)
		assert.are.near(1 / 1.3, out.ManaLeechDuration, 0.0001)
	end)
end)
