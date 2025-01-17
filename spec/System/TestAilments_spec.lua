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
end)