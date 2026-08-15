describe("WeaponSetPoints", function()
	before_each(function()
		newBuild()
	end)

	-- The warning only reads the per-set counts from CountAllocNodes, so the
	-- nodes are placed straight into allocNodes: allocating through the tree
	-- would drag pathing into a test about which set gets named.
	local function warningFor(set1Used, set2Used)
		local id = 0
		for _ = 1, set1Used + set2Used do
			id = id + 1
			build.spec.allocNodes["fake" .. id] = {
				type = "Normal",
				allocMode = id <= set1Used and 1 or 2,
			}
		end
		build.controls.warnings.lines = { }
		build:EstimatePlayerProgress()
		for _, line in ipairs(build.controls.warnings.lines) do
			if line:match("passives available") then
				return line
			end
		end
	end

	it("names weapon set 1 when set 1 has fewer points allocated", function()
		assert.are.equals("You have 2 Weapon set 1 passives available", warningFor(1, 3))
	end)

	it("names weapon set 2 when set 2 has fewer points allocated", function()
		assert.are.equals("You have 2 Weapon set 2 passives available", warningFor(3, 1))
	end)

	it("says nothing when both sets have the same number allocated", function()
		assert.is_nil(warningFor(2, 2))
	end)
end)
