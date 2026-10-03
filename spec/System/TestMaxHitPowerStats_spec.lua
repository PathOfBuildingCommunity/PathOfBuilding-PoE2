describe("TestMaxHitPowerStats", function()
	before_each(function()
		newBuild()
	end)

	local maxHitStats = {
		{ stat = "PhysicalMaximumHitTaken", label = "Physical Max Hit" },
		{ stat = "LightningMaximumHitTaken", label = "Lightning Max Hit" },
		{ stat = "ColdMaximumHitTaken", label = "Cold Max Hit" },
		{ stat = "FireMaximumHitTaken", label = "Fire Max Hit" },
		{ stat = "ChaosMaximumHitTaken", label = "Chaos Max Hit" },
	}

	local function findPowerStat(list, stat)
		for _, entry in ipairs(list) do
			if entry.stat == stat then
				return entry
			end
		end
	end

	local function findLifeNode()
		local nodeIds = { }
		for id, node in pairs(build.spec.nodes) do
			if node.type == "Normal" and not node.alloc then
				for _, line in ipairs(node.sd or { }) do
					if line:match("^%d+%% increased maximum Life$") then
						table.insert(nodeIds, id)
						break
					end
				end
			end
		end
		table.sort(nodeIds)
		return build.spec.nodes[nodeIds[1]]
	end

	it("offers per damage type max hit in the passive tree power selector", function()
		for _, expected in ipairs(maxHitStats) do
			local entry = findPowerStat(build.treeTab.powerStatList, expected.stat)
			assert.is_not_nil(entry, expected.stat .. " missing from tree power stats")
			assert.are.equals(expected.label, entry.label)
		end
	end)

	it("offers minion variants of per damage type max hit", function()
		for _, expected in ipairs(maxHitStats) do
			local entry = findPowerStat(data.powerStatList, "Minion" .. expected.stat)
			assert.is_not_nil(entry, "Minion" .. expected.stat .. " missing from power stats")
			assert.are.equals("Minion " .. expected.label, entry.label)
		end
	end)

	it("scores a maximum Life node as positive power for every damage type", function()
		build.characterLevel = 90
		build.characterLevelAutoMode = false
		runCallback("OnFrame")
		local lifeNode = findLifeNode()
		assert.is_not_nil(lifeNode, "no unallocated maximum Life node found")
		local calcFunc, calcBase = build.calcsTab:GetMiscCalculator()
		local output = calcFunc({ addNodes = { [lifeNode] = true } })

		for _, expected in ipairs(maxHitStats) do
			local entry = findPowerStat(build.treeTab.powerStatList, expected.stat)
			assert.is_not_nil(entry, expected.stat .. " missing from tree power stats")
			assert.is_true(build.calcsTab:CalculatePowerStat(entry, output, calcBase) > 0, expected.stat .. " power should be positive")
		end
	end)
end)
