describe("TestDefence", function()
	before_each(function()
		newBuild()
	end)

	teardown(function()
		-- newBuild() takes care of resetting everything in setup()
	end)

	--it("no armour max hits", function()
	--end)
	
	-- a small helper function to calculate damage taken from limited test parameters
	local function takenHitFromTypeMaxHit(type, enemyDamageMulti)
		return build.calcsTab.calcs.takenHitFromDamage(build.calcsTab.calcsOutput[type.."MaximumHitTaken"] * (enemyDamageMulti or 1), type, build.calcsTab.calcsEnv.player)
	end

	--it("armoured max hits", function()
	--end)
	
	local function withinTenPercent(value, otherValue)
		local ratio = otherValue / value
		return 0.9 < ratio and ratio < 1.1
	end

	--it("damage conversion max hits", function()
	--end)
	
	--it("damage conversion to different size pools", function()
	--end)

	--it("energy shield bypass tests #pet", function()
	--end)
end)