describe("TestSkills", function()
	before_each(function()
		newBuild()
	end)

	teardown(function()
		-- newBuild() takes care of resetting everything in setup()
	end)
	
	it("Test blasphemy reserving Spirit", function()
		build.skillsTab:PasteSocketGroup("Blasphemy 20/0  1\nDespair 20/0  1\n")
		runCallback("OnFrame")

		local oneCurseReservation = build.calcsTab.mainOutput.SpiritReservedPercent
		assert.True(oneCurseReservation > 0)

		newBuild()

		build.skillsTab:PasteSocketGroup("Blasphemy 20/0  1\nDespair 20/0  1\nFlammability 20/0  1\n")
		runCallback("OnFrame")

		assert.True(build.calcsTab.mainOutput.SpiritReservedPercent > oneCurseReservation)
	end)
end)