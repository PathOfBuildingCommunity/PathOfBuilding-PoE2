describe("TestConfigTab", function()
	before_each(function()
		newBuild()
	end)

	teardown(function()
		-- newBuild() takes care of resetting everything in setup()
	end)

	it("Show All Configurations reveals skill-gated inactive options", function()
		runCallback("OnFrame")

		local control = build.configTab.varControls.arcaneCloakUsedRecentlyCheck
		assert.True(control ~= nil)
		assert.False(control.shown())

		build.configTab.toggleConfigs = true

		assert.True(control.shown())
	end)

	it("Show All Configurations keeps parent-gated child options hidden", function()
		runCallback("OnFrame")

		local control = build.configTab.varControls.overridePowerCharges
		assert.True(control ~= nil)

		build.configTab.toggleConfigs = true

		assert.False(control.shown())
	end)
end)
