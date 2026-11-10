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

	-- first unallocated small passive (by id) with a stat line matching the pattern
	local function findNode(pattern)
		local nodeIds = { }
		for id, node in pairs(build.spec.nodes) do
			if node.type == "Normal" and not node.alloc then
				for _, line in ipairs(node.sd or { }) do
					if line:match(pattern) then
						table.insert(nodeIds, id)
						break
					end
				end
			end
		end
		table.sort(nodeIds)
		return build.spec.nodes[nodeIds[1]]
	end

	-- power of each max hit stat when the node is added, as the node power sweep calculates it
	local function maxHitPowers(node)
		build.characterLevel = 90
		build.characterLevelAutoMode = false
		build.buildFlag = true
		runCallback("OnFrame")
		local calcFunc, calcBase = build.calcsTab:GetMiscCalculator()
		local output = calcFunc({ addNodes = { [node] = true } })
		local powers = { }
		for _, expected in ipairs(maxHitStats) do
			local entry = findPowerStat(build.treeTab.powerStatList, expected.stat)
			assert.is_not_nil(entry, expected.stat .. " missing from tree power stats")
			powers[expected.stat] = build.calcsTab:CalculatePowerStat(entry, output, calcBase)
		end
		return powers
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
		local lifeNode = findNode("^%d+%% increased maximum Life$")
		assert.is_not_nil(lifeNode, "no unallocated maximum Life node found")
		local powers = maxHitPowers(lifeNode)

		for _, expected in ipairs(maxHitStats) do
			assert.is_true(powers[expected.stat] > 0, expected.stat .. " power should be positive")
		end
	end)

	it("scores a Fire Resistance node only for Fire Max Hit", function()
		local fireResNode = findNode("^%+%d+%% to Fire Resistance$")
		assert.is_not_nil(fireResNode, "no unallocated Fire Resistance node found")
		local powers = maxHitPowers(fireResNode)

		for _, expected in ipairs(maxHitStats) do
			if expected.stat == "FireMaximumHitTaken" then
				assert.is_true(powers[expected.stat] > 0, expected.stat .. " power should be positive")
			else
				assert.are.equals(0, powers[expected.stat], expected.stat .. " power should be zero")
			end
		end
	end)
end)
