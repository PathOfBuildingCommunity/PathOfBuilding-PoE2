describe("TestAilments", function()
	before_each(function()
		newBuild()
	end)

	teardown(function()
		-- newBuild() takes care of resetting everything in setup()
	end)

	--TODO: Shock not supported currently
	--it("maximum shock value", function()
	--end)

	--TODO: Shock not supported currently
	--it("bleed is buffed by bleed chance", function()
	--end)

	it("does not double count chaos damage taken for chaos poison", function()
		build.skillsTab:PasteSocketGroup("Chaos Bolt 1/0  1\nPoison I 1/0  1\n")
		runCallback("OnFrame")

		local baseEffMult = build.calcsTab.mainOutput.PoisonEffMult
		assert.True(baseEffMult and baseEffMult > 0)

		build.configTab.input.customMods = "Nearby enemies take 10% increased Chaos Damage"
		build.configTab:BuildModList()
		runCallback("OnFrame")

		assert.are.equals(1.1, build.calcsTab.mainOutput.PoisonEffMult)
	end)

	-- Pseudo-hits: a skill flagged with skillData.pseudoHitAilment inflicts that one
	-- ailment as though dealing its hit damage, but the hit itself deals no damage
	-- (e.g. Infernal Legion's burn). No in-tree skill sets the flag yet, so run the
	-- calcs directly on an env with the flag injected.
	describe("pseudo-hit ailment sources", function()
		local function setupFireball(customMods)
			build.skillsTab:PasteSocketGroup("Fireball 20/0  1\n")
			runCallback("OnFrame")
			build.configTab.input.customMods = customMods
			build.configTab:BuildModList()
			runCallback("OnFrame")
		end

		local function performWith(pseudoHitAilment)
			local calcs = build.calcsTab.calcs
			local env = calcs.initEnv(build, "MAIN")
			env.player.mainSkill.skillData.pseudoHitAilment = pseudoHitAilment
			calcs.perform(env)
			return env.player.output
		end

		it("deals no hit damage but still applies its ailment", function()
			setupFireball("100% chance to Ignite")
			local real = performWith(nil)
			assert.True(real.TotalDPS and real.TotalDPS > 0)
			assert.True(real.IgniteDPS and real.IgniteDPS > 0)
			local pseudo = performWith("Ignite")
			assert.are.equals(0, pseudo.TotalDPS)
			assert.are.equals(0, pseudo.AverageDamage)
			-- the ailment still sees the full stored hit damage
			assert.are.equals(real.IgniteDPS, pseudo.IgniteDPS)
		end)

		it("does not let other on-hit ailments ride on the notional damage", function()
			setupFireball("100% chance to Ignite\n100% chance to Poison on Hit\nAdds 50 to 70 Chaos Damage to Spells")
			local real = performWith(nil)
			assert.True(real.PoisonDPS and real.PoisonDPS > 0)
			local pseudo = performWith("Ignite")
			assert.True(not pseudo.PoisonDPS or pseudo.PoisonDPS == 0, "pseudo-hit must not produce poison DPS")
			assert.are.equals(real.IgniteDPS, pseudo.IgniteDPS)
		end)

		it("still scales with ailment magnitude", function()
			setupFireball("100% chance to Ignite")
			local base = performWith("Ignite").IgniteDPS
			assert.True(base and base > 0)
			setupFireball("100% chance to Ignite\n50% increased Magnitude of Ailments")
			local scaled = performWith("Ignite").IgniteDPS
			assert.True(math.abs(scaled / base - 1.5) < 1e-6, string.format("expected 1.5x, got %.6fx", scaled / base))
		end)
	end)
end)
