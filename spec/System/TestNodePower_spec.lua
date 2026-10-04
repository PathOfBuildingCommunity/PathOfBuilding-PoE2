describe("TestNodePower", function()
	before_each(function()
		newBuild()
	end)

	-- Start as the given class with Spark in Full DPS, so nodes near the class start matter
	local function setUp(className)
		build.spec:SelectClass(build.spec.tree.classNameMap[className])
		build.skillsTab:PasteSocketGroup("Spark 20/0  1")
		runCallback("OnFrame")
		local group = build.skillsTab.socketGroupList[1]
		group.mainActiveSkill = 1
		group.includeInFullDPS = true
		build.mainSocketGroup = 1
		-- The tree view forces Full DPS in the slow path, which node power must not depend on
		build.viewMode = "TREE"
		build.buildFlag = true
		runCallback("OnFrame")
	end

	local function findStat(stat)
		for _, powerStat in ipairs(data.powerStatList) do
			if powerStat.stat == stat then
				return powerStat
			end
		end
	end

	-- Run the node power builder to completion for the nodes closest to the allocated tree
	local function buildPower(powerStat)
		local calcsTab = build.calcsTab
		calcsTab.powerStat = powerStat
		calcsTab.nodePowerMaxDepth = 5
		calcsTab.powerBuildFlag = true
		repeat
			calcsTab:BuildPower()
		until not calcsTab.powerBuilder
	end

	-- Node power must equal the stat difference from a full, unaccelerated calculation
	local function assertMatchesSlowPath(powerStat)
		buildPower(powerStat)
		local calcsTab = build.calcsTab
		local calcFunc, calcBase = calcsTab:GetMiscCalculator()
		local checked, nonZero = 0, 0
		for _, node in pairs(build.spec.nodes) do
			if not node.alloc and node.power.singleStat and node.power.distance <= 5 then
				local expected = calcsTab:CalculatePowerStat(powerStat, calcFunc({ addNodes = { [node] = true } }), calcBase)
				local scale = math.max(math.abs(expected), 1)
				assert.is_true(math.abs(expected - node.power.singleStat) <= scale * 1e-9,
					powerStat.stat .. " power of " .. node.dn .. ": expected " .. expected .. ", got " .. node.power.singleStat)
				checked = checked + 1
				if expected ~= 0 then
					nonZero = nonZero + 1
				end
			end
		end
		assert.is_true(checked > 0, "no nodes checked")
		return nonZero
	end

	it("Full DPS power reflects the node, not cached skill results", function()
		setUp("Sorceress")
		assert.is_true(assertMatchesSlowPath(findStat("FullDPS")) > 0, "expected some node to change Full DPS")
	end)

	it("Life power matches the full calculation", function()
		setUp("Warrior")
		assert.is_true(assertMatchesSlowPath(findStat("Life")) > 0, "expected some node to change Life")
	end)

	it("EHP power matches the full calculation", function()
		setUp("Warrior")
		assert.is_true(assertMatchesSlowPath(findStat("TotalEHP")) > 0, "expected some node to change EHP")
	end)

	it("does not calculate Full DPS for other stats", function()
		setUp("Warrior")
		local calcs = build.calcsTab.calcs
		local realCalcFullDPS = calcs.calcFullDPS
		local fullDPSCalls = 0
		calcs.calcFullDPS = function(...)
			fullDPSCalls = fullDPSCalls + 1
			return realCalcFullDPS(...)
		end
		buildPower(findStat("Life"))
		calcs.calcFullDPS = realCalcFullDPS
		assert.are.equal(0, fullDPSCalls)
	end)
end)
