describe("StatDescriber getScope scenarios", function()
	before_each(function()
		newBuild()
	end)

	teardown(function()
		-- newBuild() resets environment in setup()
	end)

	local cases = {
		{ name = "should_load_lowercase_prefixed_herald_scope", scope = "specific_skill_stat_descriptions/herald_of_thunder_statset_1", stats = {}, shouldSucceed = true, expectedOutputLines = 0 },
		{ name = "should_load_herald_scope_without_prefix", scope = "herald_of_thunder_statset_1", stats = {}, shouldSucceed = true, expectedOutputLines = 0 },
		{ name = "should_load_alchemist_boon_scope", scope = "alchemist_boon", stats = {}, shouldSucceed = true, expectedOutputLines = 0 },
		{ name = "should_load_skill_stat_descriptions", scope = "skill_stat_descriptions", stats = {}, shouldSucceed = true, expectedOutputLines = 0 },
		{ name = "should_generate_output_for_life_stat", scope = "stat_descriptions", stats = { base_maximum_life = 50 }, shouldSucceed = true, expectedOutputLines = 1 },
		{ name = "should_generate_output_for_alchemist_boon_flask_recovery", scope = "alchemist_boon", stats = { ["recovery_from_flasks_applies_to_allies_in_presence_%"] = 30 }, shouldSucceed = true, expectedOutputLines = 1 },
		{ name = "should_generate_output_for_fireball_area_radius", scope = "fireball", stats = { active_skill_base_area_of_effect_radius = 15 }, shouldSucceed = true, expectedOutputLines = 1 },
		{ name = "should_fail_for_nonexistent_scope", scope = "definitely_nonexistent_scope_12345", stats = {}, shouldSucceed = false },
		{ name = "should_fail_for_nonexistent_prefixed_scope", scope = "specific_skill_stat_descriptions/definitely_nonexistent_scope_12345", stats = {}, shouldSucceed = false },
	}

	for _, case in ipairs(cases) do
		it(case.name, function()
			ConPrintf("[StatDescriber getScope] %s", case.name)
			local describe = require("Modules/StatDescriber")
			
			if case.shouldSucceed then
				local out, lineMap = describe(case.stats, case.scope)
				assert.are.equal("table", type(out))
				assert.are.equal("table", type(lineMap))
				if case.expectedOutputLines then
					assert.are.equal(case.expectedOutputLines, #out)
				end
			else
				local ok, err = pcall(function()
					describe(case.stats, case.scope)
				end)
				assert.False(ok)
				assert.is_string(err)
			end
		end)
	end
end)
