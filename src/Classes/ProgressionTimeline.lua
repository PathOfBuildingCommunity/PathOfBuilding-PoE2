-- Path of Building
--
-- Class: Progression Timeline
-- Allocation-order timeline for the passive tree: capture, reconcile, scrub, respec,
-- serialization. Reaches the tree only via the PassiveSpec host seam.
-- self.data is mutated in place (never reassigned) so the host can alias it.
--
local pairs = pairs
local ipairs = ipairs
local t_insert = table.insert
local t_remove = table.remove

local function newProgressionStage(kind)
	return { kind = kind == "respec" and "respec" or "progress", alloc = { }, dealloc = { } }
end

local function newProgression(enabled)
	return { enabled = enabled or false, version = 1, scrubStage = nil, respecOpen = false, stages = { } }
end

local function insertUnique(arr, id)
	if not isValueInArray(arr, id) then t_insert(arr, id) end
end

local function removeFromArray(arr, id)
	local removed = false
	for k = #arr, 1, -1 do
		if arr[k] == id then t_remove(arr, k) removed = true end
	end
	return removed
end

-- Author correction: drop an id from every recorded stage
local function scrubIdFromHistory(stages, id)
	for _, st in ipairs(stages) do
		removeFromArray(st.alloc, id)
		removeFromArray(st.dealloc, id)
	end
end

local function idInAnyStageAlloc(stages, id)
	for _, st in ipairs(stages) do
		if isValueInArray(st.alloc, id) then return true end
	end
	return false
end

local function setsEqual(a, b)
	for id in pairs(a) do if not b[id] then return false end end
	for id in pairs(b) do if not a[id] then return false end end
	return true
end

-- Diff two alloc snapshots; addedList honours orderedIds first, then the rest
local function diffSnapshots(before, after, orderedIds)
	local added, addedList, removed = { }, { }, { }
	for id in pairs(after) do if not before[id] then added[id] = true end end
	for id in pairs(before) do if not after[id] then t_insert(removed, id) end end
	if orderedIds then
		for _, id in ipairs(orderedIds) do
			if added[id] then t_insert(addedList, id) added[id] = nil end
		end
	end
	for id in pairs(added) do t_insert(addedList, id) end
	return addedList, removed
end

local ProgressionTimelineClass = newClass("ProgressionTimeline", function(self, spec)
	self.spec = spec
	self.data = newProgression(false)
	self._finalState = nil
end)

-- Replace data in place; identity preserved so the host's alias stays valid
function ProgressionTimelineClass:_resetData(tbl)
	wipeTable(self.data)
	for k, v in pairs(tbl) do self.data[k] = v end
	self._finalState = nil
end

function ProgressionTimelineClass:AdoptUndoData(progData)
	self:_resetData(progData and copyTable(progData) or newProgression(false))
	self.data.scrubStage = nil
	self.data.respecOpen = false
end

function ProgressionTimelineClass:StateAt(i)
	local set = { }
	local stages = self.data.stages
	for s = 1, i do
		local st = stages[s]
		if st then
			for _, id in ipairs(st.alloc) do set[id] = true end
			for _, id in ipairs(st.dealloc) do set[id] = nil end
		end
	end
	return set
end

-- Leveling order start->target; node.path is reversed, a trace path is already ordered
function ProgressionTimelineClass:NodeAllocationOrder(node, altPath)
	local ids = { }
	if altPath then
		for _, n in ipairs(altPath) do t_insert(ids, n.id) end
	elseif node and node.path then
		for k = #node.path, 1, -1 do t_insert(ids, node.path[k].id) end
	end
	return ids
end

-- Wrap a tree edit; record the alloc/dealloc delta (orderedIds keeps step order)
function ProgressionTimelineClass:Capture(orderedIds, fn)
	local prog = self.data
	if not (prog and prog.enabled) or self.spec:IsApplyingTimelineState() then
		return fn()
	end
	-- Record against the final tree; snap there first
	self:ScrubToFinal()
	local before = self.spec:SnapshotAllocIds()
	local r = fn()
	local after = self.spec:SnapshotAllocIds()
	self:ReconcileDelta(before, after, orderedIds)
	return r
end

-- Mid-scrub edit at the cursor. truncate=false inserts a stage per added node (later
-- stages shift, dupes drop); truncate=true drops everything after the cursor.
function ProgressionTimelineClass:CaptureScrubbed(orderedIds, fn, truncate)
	local prog = self.data
	if not (prog and prog.enabled) or self.spec:IsApplyingTimelineState() or prog.scrubStage == nil then
		-- Not scrubbed: fall back to final-tree recording
		return self:Capture(orderedIds, fn)
	end
	local cursor = prog.scrubStage
	local before = self.spec:SnapshotAllocIds()
	local r = fn()
	local after = self.spec:SnapshotAllocIds()

	local addedList, removed = diffSnapshots(before, after, orderedIds)

	local stages = prog.stages
	-- Dealloc/swap mid-scrub is an author correction: scrub those ids out of history
	for _, id in ipairs(removed) do
		scrubIdFromHistory(stages, id)
	end

	if truncate then
		for j = #stages, cursor + 1, -1 do t_remove(stages, j) end
		for _, id in ipairs(addedList) do
			local st = newProgressionStage("progress")
			st.alloc[1] = id
			t_insert(stages, st)
		end
	else
		for offset, id in ipairs(addedList) do
			local st = newProgressionStage("progress")
			st.alloc[1] = id
			t_insert(stages, cursor + offset, st)
		end
		-- The earlier inserted entry wins; drop any later occurrence of the same node.
		for k = cursor + #addedList + 1, #stages do
			local st = stages[k]
			if st.kind == "progress" then
				for _, id in ipairs(addedList) do removeFromArray(st.alloc, id) end
			end
		end
	end
	local targetCursor = cursor + #addedList

	self:ScrubToFinal()
	self:Normalize()
	local n = #prog.stages
	-- Normalize/PruneEmptyStages may have shifted stages; re-find the inserted node
	-- so the cursor stays on it instead of collapsing to the final tree
	local target = targetCursor
	if #addedList > 0 then
		local lastId = addedList[#addedList]
		for i = n, 1, -1 do
			if isValueInArray(prog.stages[i].alloc, lastId) then target = i break end
		end
	end
	if target > n then target = n end
	self:ScrubToStage(target < n and target or nil)
	return r
end

-- Drop empty stages, except the currently-open respec block
function ProgressionTimelineClass:PruneEmptyStages()
	local prog = self.data
	local stages = prog.stages
	for k = #stages, 1, -1 do
		local st = stages[k]
		local openRespec = prog.respecOpen and k == #stages and st.kind == "respec"
		if not openRespec and #st.alloc == 0 and (st.kind ~= "respec" or #st.dealloc == 0) then
			t_remove(stages, k)
		end
	end
end

function ProgressionTimelineClass:GetActiveRespecStage()
	local prog = self.data
	local last = prog.respecOpen and prog.stages[#prog.stages]
	return (last and last.kind == "respec") and last or nil
end

function ProgressionTimelineClass:ReconcileDelta(before, after, orderedIds)
	local prog = self.data
	local stages = prog.stages
	local respecStage = self:GetActiveRespecStage()

	local addedList, removed = diffSnapshots(before, after, orderedIds)

	for _, id in ipairs(removed) do
		if not respecStage then
			-- author correction: scrub it out of history
			scrubIdFromHistory(stages, id)
		elseif isValueInArray(respecStage.alloc, id) then
			-- added then removed within this same respec: net zero
			removeFromArray(respecStage.alloc, id)
		else
			insertUnique(respecStage.dealloc, id)
		end
	end

	local function applyAdd(id)
		if not respecStage then
			if not idInAnyStageAlloc(stages, id) then
				local st = newProgressionStage("progress")
				st.alloc[1] = id
				t_insert(stages, st)
			end
		elseif removeFromArray(respecStage.dealloc, id) then
			-- re-allocating a node this respec refunded cancels the refund
		elseif not idInAnyStageAlloc(stages, id) then
			t_insert(respecStage.alloc, id)
		end
	end
	for _, id in ipairs(addedList) do applyAdd(id) end

	self:Normalize()
end

-- Allocated ids in connected leveling order: greedy walk via node.linked so every
-- prefix stays connected. Priority: authored order, then pathDist, then id.
function ProgressionTimelineClass:OrderedAllocIds(allocIds, preferOrder)
	local seen, pref = { }, { }
	if preferOrder then
		for _, st in ipairs(self.data.stages) do
			for _, id in ipairs(st.alloc) do
				if allocIds[id] and not seen[id] then seen[id] = true t_insert(pref, id) end
			end
		end
	end
	local rest = { }
	for id in pairs(allocIds) do if not seen[id] then t_insert(rest, id) end end
	table.sort(rest, function(a, b)
		local na, nb = self.spec:TimelineNode(a), self.spec:TimelineNode(b)
		local da, db = na and na.pathDist or 0, nb and nb.pathDist or 0
		if da ~= db then return da < db end
		return a < b
	end)
	for _, id in ipairs(rest) do t_insert(pref, id) end

	-- Seed reach with the allocated connection roots
	local reach, placed, ordered = { }, { }, { }
	for _, id in ipairs(self.spec:TimelineFixedAllocIds()) do reach[id] = true end
	local function adjacentToReach(id)
		local node = self.spec:TimelineNode(id)
		if not node or not node.linked then return false end
		for _, other in ipairs(node.linked) do
			if other.id and reach[other.id] then return true end
		end
		return false
	end
	local progress = true
	while progress do
		progress = false
		for _, id in ipairs(pref) do
			if not placed[id] and adjacentToReach(id) then
				placed[id] = true
				reach[id] = true
				t_insert(ordered, id)
				progress = true
			end
		end
	end
	-- Disconnected leftovers keep priority order
	for _, id in ipairs(pref) do
		if not placed[id] then t_insert(ordered, id) end
	end
	return ordered
end

-- Flat rebuild: one progress entry per node, drops respec blocks (divergence recovery)
function ProgressionTimelineClass:RebuildStagesFromTree(preferOrder)
	local ids = self:OrderedAllocIds(self.spec:SnapshotAllocIds(), preferOrder)
	local stages = { }
	for _, id in ipairs(ids) do
		local st = newProgressionStage("progress")
		st.alloc[1] = id
		t_insert(stages, st)
	end
	self.data.stages = stages
end

-- Heal a replay-vs-tree divergence: append missing allocated ids in connected order,
-- keeping recorded order + respec; only a hopeless case falls back to a full rebuild.
function ProgressionTimelineClass:ReconcileIncremental()
	local prog = self.data
	local allocIds = self.spec:SnapshotAllocIds()
	local present = self:StateAt(#prog.stages)
	local missing = { }
	for id in pairs(allocIds) do if not present[id] then missing[id] = true end end
	if next(missing) then
		for _, id in ipairs(self:OrderedAllocIds(allocIds, true)) do
			if missing[id] then
				local st = newProgressionStage("progress")
				st.alloc[1] = id
				t_insert(prog.stages, st)
			end
		end
	end
	self:PruneEmptyStages()
	if not setsEqual(self:StateAt(#prog.stages), allocIds) then
		self:RebuildStagesFromTree(true)
		prog.respecOpen = false
	end
end

-- Enforce the invariant: stages replay to the real allocated set; drop empty tree,
-- non-meaningful respec blocks and orphaned entries; rebuild per-node if still off.
function ProgressionTimelineClass:Normalize()
	local prog = self.data
	if not (prog and prog.enabled) then return end
	local allocIds = self.spec:SnapshotAllocIds()

	if next(allocIds) == nil then
		-- Keep an open respec block mid-recording so further edits group into it
		if not prog.respecOpen and #prog.stages > 0 then prog.stages = { } end
		return
	end

	-- A respec survives only if it refunds a node allocated before it AND adds one kept in
	-- the final tree; a refund-only/orphan block is clutter. Open block exempt. cur = state before k.
	local cur, dropRespec = { }, { }
	for k = 1, #prog.stages do
		local st = prog.stages[k]
		if st.kind == "respec" and not (prog.respecOpen and k == #prog.stages) then
			local refundsReal, addsKept = false, false
			for _, id in ipairs(st.dealloc) do if cur[id] then refundsReal = true break end end
			for _, id in ipairs(st.alloc) do if allocIds[id] then addsKept = true break end end
			if not (refundsReal and addsKept) then dropRespec[k] = true end
		end
		for _, id in ipairs(st.alloc) do cur[id] = true end
		for _, id in ipairs(st.dealloc) do cur[id] = nil end
	end
	for k = #prog.stages, 1, -1 do
		if dropRespec[k] then t_remove(prog.stages, k) end
	end

	local refunded = { }
	for _, st in ipairs(prog.stages) do
		if st.kind == "respec" then
			for _, id in ipairs(st.dealloc) do refunded[id] = true end
		end
	end
	for _, st in ipairs(prog.stages) do
		if st.kind ~= "respec" then
			for j = #st.alloc, 1, -1 do
				local id = st.alloc[j]
				if not allocIds[id] and not refunded[id] then t_remove(st.alloc, j) end
			end
		end
	end
	self:PruneEmptyStages()

	-- If stages no longer replay to the allocated tree, heal incrementally
	if not setsEqual(self:StateAt(#prog.stages), allocIds) then
		self:ReconcileIncremental()
	end
end

-- Resync after a wholesale rebuild (load/undo/convert/class switch); no-op if off or mid-scrub
function ProgressionTimelineClass:ReconcileFromTree()
	local prog = self.data
	if not (prog and prog.enabled) or self.spec:IsApplyingTimelineState() then return end
	prog.respecOpen = false
	prog.scrubStage = nil

	if #prog.stages == 0 then
		self:RebuildStagesFromTree(false)
		return
	end
	-- Drop ids no longer timeline-relevant; ids absent from the tree are left untouched
	for _, st in ipairs(prog.stages) do
		for k = #st.alloc, 1, -1 do
			local node = self.spec:TimelineNode(st.alloc[k])
			if node and not self.spec:IsTimelineRelevant(node) then t_remove(st.alloc, k) end
		end
		for k = #st.dealloc, 1, -1 do
			local node = self.spec:TimelineNode(st.dealloc[k])
			if node and not self.spec:IsTimelineRelevant(node) then t_remove(st.dealloc, k) end
		end
	end
	self:Normalize()
end

function ProgressionTimelineClass:Disable()
	self:_resetData(newProgression(false))
end

function ProgressionTimelineClass:Reset()
	local prog = self.data
	if not prog then return end
	prog.stages = { }
	prog.scrubStage = nil
	prog.respecOpen = false
	self._finalState = nil
end

-- Toggle a respec block; while open refunds + re-allocs group into one stage
function ProgressionTimelineClass:ToggleRespec()
	local prog = self.data
	if not (prog and prog.enabled) then return end
	self:ScrubToFinal()
	if prog.respecOpen then
		prog.respecOpen = false
		self:PruneEmptyStages()
	else
		t_insert(prog.stages, newProgressionStage("respec"))
		prog.respecOpen = true
	end
end

-- Rebuild the allocated set to stage i (nil/last = final)
function ProgressionTimelineClass:ScrubToStage(i)
	local prog = self.data
	if not (prog and prog.enabled) then return end
	if prog.respecOpen then
		-- Scrubbing ends recording: close any open respec block
		prog.respecOpen = false
		self:PruneEmptyStages()
	end
	local n = #prog.stages
	if i == nil or i >= n then i = nil end
	if i == prog.scrubStage then return end
	local hashList = { }
	for _, id in ipairs(self.spec:TimelineFixedAllocIds()) do
		t_insert(hashList, id)
	end
	for id in pairs(self:StateAt(i or n)) do
		t_insert(hashList, id)
	end
	local state = self._finalState
	if not state then
		state = self.spec:CaptureTimelineSnapshot()
		if prog.scrubStage == nil then
			self._finalState = state
		end
	end
	self.spec:ApplyTimelineState(state, hashList)
	prog.scrubStage = i
	if i == nil then
		self._finalState = nil
	end
	self.spec:RequestRecompute()
end

function ProgressionTimelineClass:ScrubToFinal()
	local prog = self.data
	if prog and prog.enabled and prog.scrubStage ~= nil then
		self:ScrubToStage(nil)
	end
end

-- Enable and seed from the current allocation
function ProgressionTimelineClass:Enable()
	local prog = self.data
	if not prog or prog.enabled then return end
	prog.enabled = true
	prog.version = 1
	prog.scrubStage = nil
	prog.respecOpen = false
	prog.stages = { }
	self._finalState = nil
	self:ReconcileFromTree()
end

-- Enable only for a genuinely new build (never loaded/imported)
function ProgressionTimelineClass:EnableIfEligible()
	if self.spec:IsTimelineEligible() then
		self:Enable()
	end
end

function ProgressionTimelineClass:IsEnabled()
	local prog = self.data
	return prog and prog.enabled or false
end

function ProgressionTimelineClass:IsScrubbed()
	local prog = self.data
	return prog and prog.enabled and prog.scrubStage ~= nil or false
end

function ProgressionTimelineClass:GetStage(i)
	local prog = self.data
	return prog and prog.stages[i] or nil
end

-- nil when off (caller skips the element)
function ProgressionTimelineClass:Serialize()
	local prog = self.data
	if not (prog and prog.enabled) then return nil end
	local progEl = { elem = "Progression", attrib = { version = tostring(prog.version or 1) } }
	for _, st in ipairs(prog.stages) do
		t_insert(progEl, {
			elem = "Stage",
			attrib = {
				kind = st.kind or "progress",
				alloc = table.concat(st.alloc, ","),
				dealloc = table.concat(st.dealloc, ","),
			}
		})
	end
	return progEl
end

-- Rebuild from a <Progression> element; nil => legacy/imported build
function ProgressionTimelineClass:Deserialize(progEl)
	if not progEl then
		self:EnableIfEligible()
		return
	end
	local ver = tonumber(progEl.attrib.version) or 1
	if ver > 1 then
		ConPrintf("[PassiveSpec] Unsupported progression version %s; timeline disabled for this tree.", tostring(ver))
		self:_resetData(newProgression(false))
		return
	end
	local stages = { }
	for _, child in ipairs(progEl) do
		if child.elem == "Stage" then
			-- legacy level/label attrs ignored
			local st = newProgressionStage(child.attrib.kind)
			for id in (child.attrib.alloc or ""):gmatch("%d+") do t_insert(st.alloc, tonumber(id)) end
			for id in (child.attrib.dealloc or ""):gmatch("%d+") do t_insert(st.dealloc, tonumber(id)) end
			t_insert(stages, st)
		end
	end
	self:_resetData(newProgression(true))
	self.data.stages = stages
	self:ReconcileFromTree()
end
