describe("ExposureSource", function()
	before_each(function()
		newBuild()
	end)

	local function equipWhisperingIce()
		build.itemsTab:CreateDisplayItemFromRaw([[
			New Item
			Permafrost Staff
			Implicits: 0
			Inflict Elemental Exposure on Hit, lowering Total Elemental Resistances by 60%
		]])
		build.itemsTab:AddDisplayItem()
		runCallback("OnFrame")
	end

	local function canApply(element)
		return build.calcsTab.calcsEnv.modDB:Flag(nil, "Condition:CanApply" .. element .. "Exposure") == true
	end

	local function enemyResist(element)
		return build.calcsTab.calcsEnv.enemyDB:Sum("BASE", nil, element .. "Resist")
	end

	it("counts exposure granted directly to the enemy as a source", function()
		equipWhisperingIce()

		-- Without this the enemy is exposed while the build is told it cannot
		-- expose, which hides the "Is the enemy Exposed" config entirely.
		assert.is_true(build.calcsTab.calcsEnv.enemyDB:Flag(nil, "Condition:HasFireExposure") == true)
		for _, element in ipairs({ "Fire", "Cold", "Lightning" }) do
			assert.is_true(canApply(element))
		end
	end)

	it("does not report a source when nothing grants exposure", function()
		runCallback("OnFrame")

		for _, element in ipairs({ "Fire", "Cold", "Lightning" }) do
			assert.is_false(canApply(element))
		end
	end)

	it("keeps the largest exposure when the config is also enabled", function()
		equipWhisperingIce()
		local itemOnly = enemyResist("Fire")

		build.configTab.input.conditionEnemyFireExposure = true
		build.configTab:BuildModList()
		runCallback("OnFrame")

		-- Exposure does not stack: the -20% from the config must not add to the
		-- -60% from the item.
		assert.are.equals(itemOnly, enemyResist("Fire"))
	end)
end)
