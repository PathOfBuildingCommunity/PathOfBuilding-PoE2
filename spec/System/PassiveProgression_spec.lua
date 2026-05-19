-- Tests for the automatic passive-tree progression timeline (PassiveSpec.progression)

describe("PassiveProgression", function()
	before_each(function()
		newBuild()
	end)

	-- Allocate one unallocated node directly linked to an already-allocated node,
	-- recording it through the same path the tree UI uses. Returns the node id.
	local function allocOneReachable(spec)
		spec = spec or build.spec
		local prog = spec:Progression()
		for _, node in pairs(spec.allocNodes) do
			for _, linked in ipairs(node.linked) do
				if not linked.alloc and linked.path and linked.type ~= "Mastery"
					and linked.type ~= "ClassStart" and linked.type ~= "AscendClassStart" then
					prog:Capture(prog:NodeAllocationOrder(linked), function() spec:AllocNode(linked) end)
					return linked.id
				end
			end
		end
	end

	-- Same as allocOneReachable but skips a given node id, forcing a distinct pick
	-- (a just-refunded node is reachable again and would otherwise be re-selected).
	local function allocOneReachableExcept(excludeId, spec)
		spec = spec or build.spec
		local prog = spec:Progression()
		for _, node in pairs(spec.allocNodes) do
			for _, linked in ipairs(node.linked) do
				if linked.id ~= excludeId and not linked.alloc and linked.path
					and linked.type ~= "Mastery" and linked.type ~= "ClassStart"
					and linked.type ~= "AscendClassStart" then
					prog:Capture(prog:NodeAllocationOrder(linked), function() spec:AllocNode(linked) end)
					return linked.id
				end
			end
		end
	end

	-- Allocate a node several hops away (path length >= 3) to exercise multi-node ordering
	local function allocFarNode(spec)
		spec = spec or build.spec
		local prog = spec:Progression()
		for _, node in pairs(spec.nodes) do
			if not node.alloc and node.path and #node.path >= 3 and node.type ~= "Mastery"
				and node.type ~= "ClassStart" and node.type ~= "AscendClassStart" then
				prog:Capture(prog:NodeAllocationOrder(node), function() spec:AllocNode(node) end)
				return node.id
			end
		end
	end

	local function count(set)
		local n = 0
		for _ in pairs(set) do n = n + 1 end
		return n
	end

	local function invariantHolds(spec)
		spec = spec or build.spec
		local allocIds = spec:SnapshotAllocIds()
		local produced = spec:Progression():StateAt(#spec.progression.stages)
		for id in pairs(allocIds) do if not produced[id] then return false end end
		for id in pairs(produced) do if not allocIds[id] then return false end end
		return true
	end

	local function stageOf(spec, id)
		for _, st in ipairs(spec.progression.stages) do
			for _, aid in ipairs(st.alloc) do if aid == id then return st end end
		end
	end

	local function stageIndexOf(spec, id)
		for i, st in ipairs(spec.progression.stages) do
			for _, aid in ipairs(st.alloc) do if aid == id then return i end end
		end
	end

	-- Allocate a not-yet-allocated reachable node WITHOUT recording (an unhooked mutation)
	local function allocUnhooked(spec)
		spec = spec or build.spec
		for _, node in pairs(spec.allocNodes) do
			for _, linked in ipairs(node.linked) do
				if not linked.alloc and linked.path and linked.type ~= "Mastery"
					and linked.type ~= "ClassStart" and linked.type ~= "AscendClassStart" then
					spec:AllocNode(linked)
					return linked.id
				end
			end
		end
	end

	-- While scrubbed: allocate a node adjacent to the (partial) tree that is NOT already in
	-- the timeline, recorded through the mid-scrub insert path. Returns its id.
	local function allocScrubbedNew(spec)
		spec = spec or build.spec
		local prog = spec:Progression()
		local inStages = { }
		for _, st in ipairs(spec.progression.stages) do
			for _, id in ipairs(st.alloc) do inStages[id] = true end
		end
		for _, node in pairs(spec.allocNodes) do
			for _, linked in ipairs(node.linked) do
				if not linked.alloc and not inStages[linked.id] and linked.path
					and linked.type ~= "Mastery" and linked.type ~= "ClassStart"
					and linked.type ~= "AscendClassStart" then
					prog:CaptureScrubbed(prog:NodeAllocationOrder(linked),
						function() spec:AllocNode(linked) end, false)
					return linked.id
				end
			end
		end
	end

	it("is enabled with an empty timeline for a new build", function()
		local prog = build.spec.progression
		assert.is_true(prog.enabled)
		assert.are.equal(0, #prog.stages)
		assert.is_false(prog.respecOpen)
	end)

	it("auto-creates one progress entry per allocated node", function()
		local id = allocOneReachable()
		assert.is_not_nil(id)
		local st = stageOf(build.spec, id)
		assert.is_not_nil(st)
		assert.are.equal("progress", st.kind)
		assert.are.equal(1, #st.alloc)
		assert.is_true(#build.spec.progression.stages >= 1)
		assert.is_true(invariantHolds())
	end)

	it("treats a deallocation (no respec) as a silent correction", function()
		local id = allocOneReachable()
		local before = #build.spec.progression.stages
		local node = build.spec.nodes[id]
		build.spec:Progression():Capture(nil, function() build.spec:DeallocNode(node) end)
		assert.is_nil(stageOf(build.spec, id))
		assert.is_true(#build.spec.progression.stages < before)
		assert.is_true(invariantHolds())
	end)

	it("groups refunds into one atomic respec block via ToggleRespec", function()
		local idA = allocOneReachable()
		build.spec:AddUndoState()
		build.spec:Progression():ToggleRespec()
		assert.is_true(build.spec.progression.respecOpen)
		local respec = build.spec.progression.stages[#build.spec.progression.stages]
		assert.are.equal("respec", respec.kind)

		local node = build.spec.nodes[idA]
		build.spec:Progression():Capture(nil, function() build.spec:DeallocNode(node) end)
		local refunded = false
		for _, did in ipairs(respec.dealloc) do if did == idA then refunded = true end end
		assert.is_true(refunded)

		local idB = allocOneReachableExcept(idA)
		assert.is_not_nil(idB)
		local added = false
		for _, aid in ipairs(respec.alloc) do if aid == idB then added = true end end
		assert.is_true(added)

		build.spec:Progression():ToggleRespec()
		assert.is_false(build.spec.progression.respecOpen)
		assert.is_true(invariantHolds())
	end)

	it("drops a refund-only respec and its orphaned entries", function()
		allocOneReachable()
		local idB = allocOneReachable()
		assert.is_not_nil(idB)
		build.spec:Progression():ToggleRespec()
		-- refund idB inside the respec but add nothing back
		build.spec:Progression():Capture(nil, function() build.spec:DeallocNode(build.spec.nodes[idB]) end)
		build.spec:Progression():ToggleRespec()
		build.spec:Progression():Normalize()
		for _, st in ipairs(build.spec.progression.stages) do
			assert.are_not.equal("respec", st.kind)
			for _, id in ipairs(st.alloc) do assert.are_not.equal(idB, id) end
		end
		assert.is_true(invariantHolds())
	end)

	it("records a multi-node path in leveling order so every scrub prefix stays connected", function()
		local id = allocFarNode()
		assert.is_not_nil(id)
		local spec = build.spec
		local n = #spec.progression.stages
		assert.is_true(n >= 3)
		local startCount = count(spec:Progression():StateAt(0))
		local prev = startCount
		for k = 1, n do
			spec:Progression():ScrubToStage(k >= n and nil or k)
			runCallback("OnFrame")
			local c = count(spec:SnapshotAllocIds())
			-- every prefix must actually allocate (connected to the tree), growing monotonically
			assert.is_true(c >= prev, "prefix "..k.." lost allocations (disconnected order)")
			if k < n then assert.is_true(c >= k) end
			prev = c
		end
		spec:Progression():ScrubToStage(nil)
		runCallback("OnFrame")
		assert.is_true(invariantHolds())
	end)

	it("stays consistent (replay == tree) after a cascade with a respec open", function()
		-- Build a small chain, open a respec, then deallocate a connector so the cascade
		-- removes several nodes at once. The timeline must never desync from the tree.
		allocOneReachable()
		allocOneReachable()
		local id = allocFarNode()
		assert.is_not_nil(id)
		build.spec:Progression():ToggleRespec()
		assert.is_true(build.spec.progression.respecOpen)
		-- find an allocated connector near the start and refund it (cascades dependents)
		for _, node in pairs(build.spec.allocNodes) do
			if node.type ~= "ClassStart" and node.type ~= "AscendClassStart"
				and node.isFreeAllocate == nil and node.depends and #node.depends > 1 then
				build.spec:Progression():Capture(nil, function() build.spec:DeallocNode(node) end)
				break
			end
		end
		assert.is_true(invariantHolds(), "timeline desynced from tree after cascade+respec")
		build.spec:Progression():ToggleRespec()
		assert.is_true(invariantHolds())
	end)

	it("scrub really changes the allocated set and restores it exactly", function()
		allocOneReachable()
		local id2 = allocOneReachable()
		assert.is_not_nil(id2)
		local n = #build.spec.progression.stages
		assert.is_true(n >= 2)
		local finalCount = count(build.spec:SnapshotAllocIds())

		build.spec:Progression():ScrubToStage(1)
		runCallback("OnFrame")
		assert.is_nil(build.spec.allocNodes[id2])
		assert.is_true(count(build.spec:SnapshotAllocIds()) < finalCount)

		build.spec:Progression():ScrubToStage(nil)
		runCallback("OnFrame")
		assert.is_not_nil(build.spec.allocNodes[id2])
		assert.are.equal(finalCount, count(build.spec:SnapshotAllocIds()))
		assert.is_nil(build.spec.progression.scrubStage)
	end)

	it("persists the final tree and reopens at the end even when scrubbed", function()
		allocOneReachable()
		allocOneReachable()
		local finalCount = count(build.spec:SnapshotAllocIds())

		build.spec:Progression():ScrubToStage(1) -- leave it mid-scrub
		local xml = build:SaveDB("code")
		assert.is_string(xml)
		assert.is_truthy(xml:find("<Progression"))

		loadBuildFromXML(xml, "roundtrip")
		local rp = build.spec.progression
		assert.is_true(rp.enabled)
		assert.is_nil(rp.scrubStage)
		assert.are.equal(finalCount, count(build.spec:SnapshotAllocIds()))
		assert.is_true(invariantHolds())
	end)

	it("does not give a timeline to a legacy build without <Progression>", function()
		allocOneReachable()
		local xml = build:SaveDB("code")
		local stripped = xml:gsub("<Progression.->.-</Progression>", ""):gsub("<Progression[^/]-/>", "")
		loadBuildFromXML(stripped, "legacy")
		assert.is_false(build.spec.progression.enabled)
		local resaved = build:SaveDB("code")
		assert.is_nil(resaved:find("<Progression"))
	end)

	it("keeps nodes and timeline in sync across undo/redo", function()
		build.spec:ResetUndo() -- baseline a loaded build always has; a new build has none
		local id = allocOneReachable()
		build.spec:AddUndoState()
		assert.is_not_nil(build.spec.allocNodes[id])
		build.spec:Undo()
		assert.is_nil(build.spec.allocNodes[id])
		assert.is_true(invariantHolds())
		build.spec:Redo()
		assert.is_not_nil(build.spec.allocNodes[id])
		assert.is_true(invariantHolds())
		assert.is_nil(build.spec.progression.scrubStage)
	end)

	it("empties the timeline on tree reset", function()
		allocOneReachable()
		build.spec:ResetNodes()
		build.spec:BuildAllDependsAndPaths()
		build.spec:Progression():Reset()
		assert.are.equal(0, #build.spec.progression.stages)
		assert.is_true(build.spec.progression.enabled)
		assert.is_true(invariantHolds())
	end)

	it("estimates a non-decreasing character level across timeline stages", function()
		allocOneReachable()
		allocOneReachable()
		allocOneReachable()
		local tl = build.treeTab.controls.timeline
		local stages = build.spec.progression.stages
		assert.is_true(#stages >= 1)
		local prev = build:EstimateLevelForPoints(0)
		assert.are.equal(1, prev)
		for k = 1, #stages do
			local lvl = tl:LevelAt(build.spec, k)
			assert.is_true(type(lvl) == "number" and lvl >= 1 and lvl <= 100)
			assert.is_true(lvl >= prev)
			prev = lvl
		end
	end)

	it("heals an unhooked alloc-set change without flattening recorded order", function()
		local spec = build.spec
		local idA = allocOneReachable()
		local idB = allocOneReachable()
		assert.is_not_nil(idA)
		assert.is_not_nil(idB)
		-- unhooked dealloc of the leaf idB, then an unhooked add of a new node
		spec:DeallocNode(spec.nodes[idB])
		local idC = allocUnhooked(spec)
		assert.is_not_nil(idC)
		spec:Progression():Normalize()
		-- idA keeps its recorded slot, idB silent-corrected away, idC appended after idA
		assert.is_not_nil(stageOf(spec, idA))
		assert.is_nil(stageOf(spec, idB))
		assert.is_not_nil(stageOf(spec, idC))
		assert.is_true(stageIndexOf(spec, idA) < stageIndexOf(spec, idC))
		assert.is_true(invariantHolds())
	end)

	it("is unaffected by an in-place node transform (timeless/Abyss keep the same id)", function()
		local spec = build.spec
		local id = allocOneReachable()
		assert.is_not_nil(id)
		local st = stageOf(spec, id)
		assert.is_not_nil(st)
		-- mimic ReplaceNode: change node CONTENTS but keep .id and .type
		local node = spec.nodes[id]
		node.dn = "Transformed Node"
		node.modList = node.modList or { }
		spec:Progression():Normalize()
		assert.are.equal(st, stageOf(spec, id)) -- same stage, same id
		assert.is_true(invariantHolds())
		-- scrub round-trips cleanly through the transformed node
		spec:Progression():ScrubToStage(0)
		runCallback("OnFrame")
		spec:Progression():ScrubToStage(nil)
		runCallback("OnFrame")
		assert.is_not_nil(spec.allocNodes[id])
		assert.is_true(invariantHolds())
	end)

	it("rebuilt-from-tree stages scrub through connected prefixes", function()
		local spec = build.spec
		allocOneReachable()
		local id = allocFarNode()
		assert.is_not_nil(id)
		spec:Progression():RebuildStagesFromTree(true)
		local n = #spec.progression.stages
		assert.is_true(n >= 3)
		local prev = count(spec:Progression():StateAt(0))
		for k = 1, n do
			spec:Progression():ScrubToStage(k >= n and nil or k)
			runCallback("OnFrame")
			local c = count(spec:SnapshotAllocIds())
			-- connected order => every prefix actually allocates (monotonic, never blanks)
			assert.is_true(c >= prev, "rebuilt prefix "..k.." disconnected")
			prev = c
		end
		spec:Progression():ScrubToStage(nil)
		runCallback("OnFrame")
		assert.is_true(invariantHolds())
	end)

	it("SetCompareSpec snaps a scrubbed spec back to its final tree", function()
		local spec = build.spec
		allocOneReachable()
		allocOneReachable()
		local finalCount = count(spec:SnapshotAllocIds())
		spec:Progression():ScrubToStage(1)
		runCallback("OnFrame")
		assert.is_not_nil(spec.progression.scrubStage)
		build.treeTab:SetCompareSpec(build.treeTab.activeSpec)
		assert.is_nil(spec.progression.scrubStage)
		assert.are.equal(finalCount, count(spec:SnapshotAllocIds()))
	end)

	it("mid-scrub allocation inserts at the cursor and keeps later progression", function()
		local spec = build.spec
		local a = allocOneReachable()
		local b = allocOneReachable()
		local c = allocOneReachable()
		assert.is_not_nil(c)
		local finalBefore = count(spec:SnapshotAllocIds())
		spec:Progression():ScrubToStage(1)
		runCallback("OnFrame")
		local newId = allocScrubbedNew(spec)
		assert.is_not_nil(newId)
		-- inserted right after the cursor; later stages preserved and shifted after it
		assert.are.equal(2, stageIndexOf(spec, newId))
		assert.are.equal(2, spec.progression.scrubStage) -- view stays at the inserted point
		assert.is_true(stageIndexOf(spec, b) > 2)
		assert.is_true(stageIndexOf(spec, c) > stageIndexOf(spec, b))
		spec:Progression():ScrubToStage(nil)
		runCallback("OnFrame")
		assert.is_true(invariantHolds())
		assert.are.equal(finalBefore + 1, count(spec:SnapshotAllocIds()))
		assert.is_not_nil(spec.allocNodes[newId])
	end)

	it("mid-scrub allocation of an already-later node dedupes the later copy", function()
		local spec = build.spec
		local a = allocOneReachable()
		local b = allocOneReachable()
		assert.is_not_nil(b)
		local finalBefore = count(spec:SnapshotAllocIds())
		local stagesBefore = #spec.progression.stages
		spec:Progression():ScrubToStage(1)
		runCallback("OnFrame")
		local bn = spec.nodes[b]
		spec:Progression():CaptureScrubbed(spec:Progression():NodeAllocationOrder(bn),
			function() spec:AllocNode(bn) end, false)
		local occurrences = 0
		for _, st in ipairs(spec.progression.stages) do
			for _, id in ipairs(st.alloc) do if id == b then occurrences = occurrences + 1 end end
		end
		assert.are.equal(1, occurrences)
		spec:Progression():ScrubToStage(nil)
		runCallback("OnFrame")
		assert.is_true(invariantHolds())
		assert.are.equal(finalBefore, count(spec:SnapshotAllocIds()))
		assert.are.equal(stagesBefore, #spec.progression.stages)
	end)

	it("a confirmed destructive mid-scrub edit truncates after the cursor", function()
		local spec = build.spec
		local a = allocOneReachable()
		local b = allocOneReachable()
		local c = allocOneReachable()
		assert.is_not_nil(c)
		spec:Progression():ScrubToStage(2)
		runCallback("OnFrame")
		local bn = spec.nodes[b]
		spec:Progression():CaptureScrubbed(nil, function() spec:DeallocNode(bn) end, true)
		runCallback("OnFrame")
		assert.is_nil(stageOf(spec, b)) -- removed node scrubbed out of history
		assert.is_nil(stageOf(spec, c)) -- everything after the cursor discarded
		assert.is_nil(spec.allocNodes[c])
		assert.is_true(invariantHolds())
	end)

	-- A not-yet-allocated attribute node reachable from the current tree.
	-- Scan the whole reachable graph (.path set) like allocFarNode: on a fresh
	-- build no attribute node is an immediate neighbour of the class start.
	local function findReachableAttribute(spec)
		spec = spec or build.spec
		for _, node in pairs(spec.nodes) do
			if node.isAttribute and not node.alloc and node.path and #node.path >= 1 then
				return node
			end
		end
	end

	it("records an attribute-popup allocation without needing a reload", function()
		local spec = build.spec
		local node = findReachableAttribute(spec)
		assert.is_not_nil(node, "no reachable attribute node found")
		-- mimic TreeTab:ModifyAttributePopup's Allocate button
		spec:SwitchAttributeNode(node.id, 1)
		spec.attributeIndex = 1
		spec:AllocNodeRecorded(node)
		assert.is_not_nil(spec.allocNodes[node.id])
		assert.is_not_nil(stageOf(spec, node.id)) -- recorded immediately, no save/reload
		assert.is_true(invariantHolds())
	end)

	it("keeps the scrub cursor on the inserted node (does not fly to the end)", function()
		local spec = build.spec
		allocOneReachable()
		local b = allocOneReachable()
		allocOneReachable()
		assert.is_not_nil(b)
		spec:Progression():ScrubToStage(1)
		runCallback("OnFrame")
		local newId = allocScrubbedNew(spec)
		assert.is_not_nil(newId)
		-- cursor follows the inserted node and stays scrubbed while later stages remain
		assert.is_not_nil(spec.progression.scrubStage)
		assert.are.equal(stageIndexOf(spec, newId), spec.progression.scrubStage)
		assert.is_true(#spec.progression.stages > spec.progression.scrubStage)
		assert.is_true(stageIndexOf(spec, b) > spec.progression.scrubStage)
		spec:Progression():ScrubToStage(nil)
		runCallback("OnFrame")
		assert.is_true(invariantHolds())
	end)
end)
