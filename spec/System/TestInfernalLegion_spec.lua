describe("TestInfernalLegion", function()
	before_each(function()
		newBuild()
	end)

	-- Helper: minion supported by Infernal Legion, with the minion pointed at the IL skill.
	-- Set any config/customMods before calling this so the build picks them up.
	local function setupIL()
		build.configTab:BuildModList()
		build.skillsTab:PasteSocketGroup("Skeletal Warrior 20/0  1\nInfernal Legion I 1/0  1\n")
		runCallback("OnFrame")
		build.skillsTab:SetDisplayGroup(build.skillsTab.socketGroupList[1])
		runCallback("OnFrame")
		local env = build.calcsTab.mainEnv
		local ilIndex
		for i, s in ipairs(env.minion and env.minion.activeSkillList or {}) do
			local ge = s.activeEffect and s.activeEffect.grantedEffect
			if ge and ge.id == "InfernalLegion" then ilIndex = i break end
		end
		assert.is_not_nil(ilIndex, "Infernal Legion should be on the minion's skill list")
		for _, gem in ipairs(build.skillsTab.socketGroupList[1].gemList) do
			gem.skillMinionSkill = ilIndex
			gem.skillMinionSkillCalcs = ilIndex
		end
		build.mainSocketGroup = 1
		build.modFlag = true; build.buildFlag = true
		for _ = 1, 6 do runCallback("OnFrame") end
		return build.calcsTab.mainEnv
	end

	local function recalc()
		build.configTab:BuildModList()
		build.modFlag = true; build.buildFlag = true
		for _ = 1, 4 do runCallback("OnFrame") end
		return build.calcsTab.mainEnv
	end

	-- IL's "hit" is a pseudo-hit: it seeds the ignite but deals no damage of its own.
	it("IL deals no hit damage (pseudo-hit) but still ignites", function()
		local o = setupIL().minion.output
		assert.are.equals(0, o.AverageDamage)
		assert.are.equals(0, o.TotalDPS)
		assert.True(o.IgniteDPS and o.IgniteDPS > 0, "IL should produce ignite DPS")
	end)

	-- IL ignite crits use a 50% base crit bonus (1.5x), not the minion's default 100% (2x).
	it("IL uses a 50% base crit bonus (1.5x multiplier)", function()
		assert.are.equals(1.5, setupIL().minion.output.PreEffectiveCritMultiplier)
	end)

	-- The minion's *increased* crit damage applies at half effectiveness for IL.
	it("the minion's increased crit damage is half-effective for IL", function()
		build.configTab.input.customMods = "Minions have 100% increased Critical Damage Bonus"
		-- base 0.5 bonus, +100% increased applied at half (=+50%): 0.5 * (1 + 0.5) = 0.75 -> 1.75x.
		-- (Full effectiveness would give 0.5 * 2.0 = 1.0 -> 2.0x.)
		assert.are.equals(1.75, setupIL().minion.output.PreEffectiveCritMultiplier)
	end)

	-- "Minions have X% increased Magnitude of Ailments" scales IL's ignite end-to-end.
	it("minion 'increased Magnitude of Ailments' scales IL ignite", function()
		local base = setupIL().minion.output.IgniteDPS
		assert.True(base and base > 0)
		build.configTab.input.customMods = "Minions have 100% increased Magnitude of Ailments"
		local scaled = recalc().minion.output.IgniteDPS
		-- +100% magnitude roughly doubles the ignite (baseline magnitude increase is 0 here).
		assert.True(math.abs(scaled - 2 * base) < 1e-6, string.format("expected %.6f, got %.6f", 2 * base, scaled))
	end)

	-- Full DPS runs offence on the IL skill an extra time. The half-effect that
	-- preDamageFunc injects must not stack, or crit would over-halve.
	it("IL crit/ignite stay correct under Full DPS (no double-applied halving)", function()
		local base = setupIL().minion.output.IgniteDPS
		build.skillsTab.socketGroupList[1].includeInFullDPS = true
		local env = recalc()
		assert.are.equals(1.5, env.minion.output.PreEffectiveCritMultiplier)
		assert.True(math.abs(env.minion.output.IgniteDPS - base) < 1e-6,
			string.format("ignite changed under Full DPS: %.6f vs %.6f", env.minion.output.IgniteDPS, base))
	end)

	-- IL's hit is a pseudo-hit (no real damage), so a poison source must not seed a
	-- poison off its big notional damage -- that was inflating Poison's evaluated value.
	it("IL pseudo-hit does not seed poison from a poison source", function()
		local igniteBefore = setupIL().minion.output.IgniteDPS
		build.configTab.input.customMods = "Minions have 100% chance to Poison on Hit"
		local env = recalc()
		local poison = env.minion.output.PoisonDPS
		assert.True(not poison or poison == 0, "IL pseudo-hit must not produce poison DPS")
		assert.True(math.abs(env.minion.output.IgniteDPS - igniteBefore) < 1e-6, "ignite must be unchanged")
	end)
end)
