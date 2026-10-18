-- advisor.*: where the next passive point should go, which allocated point to move, and attribute node choices.
-- Follows a reference guide when one is passed (params.reference), otherwise searches nearby notables.
local util = require("pobapi.util")
local session = require("pobapi.session")
local reference = require("pobapi.api.reference")

local M = { }

local ATTRIBUTES = { "Strength", "Dexterity", "Intelligence" }
local SHORT = { Strength = "Str", Dexterity = "Dex", Intelligence = "Int" }
local MIN_GAIN = 0.05 -- percent; smaller changes are noise

local METRICS = {
	balanced = function(r) return r.dpsPercent + r.ehpPercent end,
	dps = function(r) return r.dpsPercent end,
	ehp = function(r) return r.ehpPercent end,
}

local function nodeRef(node)
	return { id = node.id, name = node.dn, type = node.type, ascendancy = node.ascendancyName }
end

local function fmt(v, unit)
	return string.format("%s%.1f%s", v >= 0 and "+" or "", v, unit)
end

-- "+1.2% DPS, +6 ES" style summary of a change.
local function describe(r)
	local parts = { }
	if math.abs(r.dpsPercent) >= MIN_GAIN then parts[#parts + 1] = fmt(r.dpsPercent, "% DPS") end
	if math.abs(r.ehpPercent) >= MIN_GAIN then parts[#parts + 1] = fmt(r.ehpPercent, "% EHP") end
	if math.abs(r.lifeDelta) >= 1 then parts[#parts + 1] = string.format("%+d Life", math.floor(r.lifeDelta + 0.5)) end
	if math.abs(r.esDelta) >= 1 then parts[#parts + 1] = string.format("%+d ES", math.floor(r.esDelta + 0.5)) end
	return #parts > 0 and table.concat(parts, ", ") or "no measurable change"
end

-- What refunding a node does, phrased from the player's side.
local function refundEffect(r)
	if r.score >= MIN_GAIN then
		return "refunding it actually helps (" .. describe(r) .. ")"
	elseif r.score > -MIN_GAIN and math.abs(r.lifeDelta) < 1 and math.abs(r.esDelta) < 1 then
		return "refunding it costs nothing measurable"
	end
	local loss = { dpsPercent = -r.dpsPercent, ehpPercent = -r.ehpPercent, lifeDelta = -r.lifeDelta, esDelta = -r.esDelta }
	return "refunding it costs " .. describe(loss):gsub("%+", "")
end

-- Nodes in `set` ordered so each touches the tree (or an earlier one) when allocated.
local function allocationOrder(set)
	local order, seen, queue, head = { }, { }, { }, 1
	for node in pairs(set) do
		for _, other in ipairs(node.linked or { }) do
			if other.alloc and not set[other] and not seen[node]
				and (not other.ascendancyName or other.ascendancyName == node.ascendancyName) then
				seen[node] = true
				queue[#queue + 1] = node
			end
		end
	end
	table.sort(queue, function(a, b) return a.id < b.id end)
	while head <= #queue do
		local node = queue[head]
		head = head + 1
		order[#order + 1] = node
		for _, other in ipairs(node.linked or { }) do
			if set[other] and not seen[other] then
				seen[other] = true
				queue[#queue + 1] = other
			end
		end
	end
	return order
end

function M.plan(params)
	local b = session.build()
	local spec = b.spec
	local score = METRICS[params.metric or "balanced"] or METRICS.balanced
	local limit = tonumber(params.limit) or 10
	local calcFunc, baseOutput = b.calcsTab:GetMiscCalculator()
	local base = reference._headline(baseOutput)
	local function measure(override, points)
		local h = reference._headline(calcFunc(override))
		local r = {
			points = points,
			dpsPercent = reference._pct(base.dps, h.dps),
			ehpPercent = reference._pct(base.ehp, h.ehp),
			lifeDelta = h.life - base.life,
			esDelta = h.es - base.es,
		}
		r.score = score(r)
		reference._budgetDeltas(r, base, h)
		return r
	end

	local guide, level
	local wanted = { }
	if type(params.reference) == "table" then
		local ref
		ref, level = reference._getReference(params)
		level = level or b.characterLevel
		guide = { name = ref.name, level = level }
		wanted = reference._resolvePassives(spec, ref, level)
	end

	local granted = { }
	for _, id in pairs(spec.allocExtendedNodes or { }) do
		granted[id] = true
	end

	-- Candidate targets and the route to each.
	local candidates = { }
	if guide then
		local missing = { }
		for node in pairs(wanted) do
			if not node.alloc then
				missing[node] = true
			end
		end
		for node in pairs(missing) do
			if node.type == "Notable" or node.type == "Keystone" or node.type == "Socket" then
				local path = reference._routeTo(node, missing)
				if path then
					candidates[#candidates + 1] = { target = node, path = path }
				end
			end
		end
	else
		local maxPath = tonumber(params.maxPath) or 8
		for _, node in pairs(spec.nodes) do
			if not node.alloc and (node.type == "Notable" or node.type == "Keystone") and node.path and #node.path > 0
				and #node.path <= maxPath and (not node.ascendancyName or node.ascendancyName == spec.curAscendClassName) then
				local set = { }
				for _, pathNode in ipairs(node.path) do
					set[pathNode] = true
				end
				candidates[#candidates + 1] = { target = node, path = allocationOrder(set) }
			end
		end
		table.sort(candidates, function(a, c) return #a.path < #c.path end)
		while #candidates > 150 do
			table.remove(candidates)
		end
	end

	local steps = util.array()
	for _, cand in ipairs(candidates) do
		local set, ids = { }, util.array()
		for _, node in ipairs(cand.path) do
			set[node] = true
			ids[#ids + 1] = node.id
		end
		local r = measure({ addNodes = set }, #cand.path)
		r.perPoint = r.score / #cand.path
		r.target = nodeRef(cand.target)
		r.path = ids
		r.first = nodeRef(cand.path[1])
		r.inGuide = guide ~= nil
		if guide or r.score >= MIN_GAIN then
			steps[#steps + 1] = r
		end
	end
	table.sort(steps, function(a, c) return a.perPoint > c.perPoint end)

	-- Points to move: allocated tips (refunding them disconnects nothing), cheapest first.
	local refunds = util.array()
	for _, node in pairs(spec.allocNodes) do
		if not reference._isStart(node) and not node.ascendancyName and node.id < 65536 and not granted[node.id]
			and not wanted[node] and (#(node.depends or { }) <= 1) then
			local r = measure({ removeNodes = { [node] = true } }, 1)
			r.node = nodeRef(node)
			r.notInGuide = guide ~= nil
			r.reason = (guide and ((node.dn or "This node") .. " isn't in the guide; ") or ((node.dn or "This node") .. ": "))
				.. refundEffect(r) .. "."
			refunds[#refunds + 1] = r
		end
	end
	table.sort(refunds, function(a, c) return a.score > c.score end)

	local nextStep = steps[1]
	local move
	local refund = refunds[1]
	if nextStep and refund then
		local net = nextStep.perPoint + refund.score
		if guide or net >= MIN_GAIN then
			move = { refund = refund, allocate = nextStep, netPerPoint = net }
			move.reason = string.format("%s%s; spend the point toward %s instead (%s per point).",
				refund.node.name or "This node", guide and " isn't in the guide, and " .. refundEffect(refund) or ": " .. refundEffect(refund),
				nextStep.target.name, fmt(nextStep.perPoint, "%"))
		end
	end
	if nextStep then
		nextStep.reason = string.format("First point toward %s (%d point%s): %s in total.", nextStep.target.name,
			nextStep.points, nextStep.points == 1 and "" or "s", describe(nextStep))
	end
	while #steps > limit do table.remove(steps) end
	while #refunds > limit do table.remove(refunds) end

	return {
		mode = guide and "guide" or "free",
		guide = guide,
		metric = params.metric or "balanced",
		base = base,
		next = nextStep,
		steps = steps,
		refunds = refunds,
		move = move,
		attributes = M._attributes(spec, calcFunc, baseOutput, measure),
	}
end

-- Attribute nodes: the measured value of each +5 swap, constrained by gear/gem attribute requirements.
function M._attributes(spec, calcFunc, baseOutput, measure)
	local nodes, unset = { }, { }
	for id, node in pairs(spec.allocNodes) do
		local treeNode = spec.tree.nodes[id]
		if treeNode and treeNode.isAttribute and treeNode.options then
			nodes[#nodes + 1] = node
			if not SHORT[node.dn] then
				unset[node] = true -- allocated without a choice: gives nothing yet
			end
		end
	end
	table.sort(nodes, function(a, c) return a.id < c.id end)
	local margin, totals = { }, { }
	for _, attr in ipairs(ATTRIBUTES) do
		local short = SHORT[attr]
		totals[attr] = { value = baseOutput[short] or 0, required = baseOutput["Req" .. short] or 0 }
		margin[attr] = totals[attr].value - totals[attr].required
	end
	if #nodes == 0 then
		return { totals = totals, nodes = util.array(), changes = 0 }
	end

	local function altNode(id, attr)
		local treeNode = spec.tree.nodes[id]
		for _, option in ipairs(treeNode.options) do
			if (option.dn or option.name) == attr then
				local newNode = copyTableSafe(treeNode, false, true)
				spec:ReplaceNode(newNode, option)
				spec.tree:ProcessStats(newNode)
				return newNode
			end
		end
	end

	-- One measurement per (from, to) pair; every attribute node gives the same +5.
	local swap = { }
	for _, from in ipairs(ATTRIBUTES) do
		local rep
		for _, node in ipairs(nodes) do
			if node.dn == from and (node.allocMode or 0) == 0 then
				rep = node
				break
			end
		end
		rep = rep or (function() for _, node in ipairs(nodes) do if node.dn == from then return node end end end)()
		if rep then
			swap[from] = { }
			for _, to in ipairs(ATTRIBUTES) do
				local alt = to ~= from and altNode(rep.id, to)
				if alt then
					swap[from][to] = measure({ removeNodes = { [rep] = true }, addNodes = { [alt] = true } }, 0)
				end
			end
		end
	end

	local plan = { } -- node -> { to, kind, r }
	local left = { }
	for _, attr in ipairs(ATTRIBUTES) do left[attr] = margin[attr] end
	-- 0. Unassigned attribute nodes: cover a shortfall first, otherwise take the best measured choice.
	for _, node in ipairs(nodes) do
		if unset[node] then
			local best, bestR
			for _, attr in ipairs(ATTRIBUTES) do
				local alt = altNode(node.id, attr)
				if alt then
					local r = measure({ removeNodes = { [node] = true }, addNodes = { [alt] = true } }, 0)
					local short = left[attr] < 0
					if not best or (short and left[best] >= 0) or ((short == (left[best] < 0)) and r.score > bestR.score) then
						best, bestR = attr, r
					end
				end
			end
			if best then
				plan[node] = { to = best, kind = "unset", r = bestR }
				left[best] = left[best] + 5
			end
		end
	end
	local function assign(from, to, kind)
		for _, node in ipairs(nodes) do
			if not plan[node] and node.dn == from then
				plan[node] = { to = to, kind = kind }
				left[from] = left[from] - 5
				left[to] = left[to] + 5
				return true
			end
		end
	end
	-- 1. Cover attribute shortfalls (unusable gear or gems), taking from the cheapest surplus.
	for _, need in ipairs(ATTRIBUTES) do
		while left[need] < 0 do
			local best, bestScore
			for _, from in ipairs(ATTRIBUTES) do
				if from ~= need and left[from] >= 5 and swap[from] and swap[from][need] then
					local s = swap[from][need].score
					if not bestScore or s > bestScore then best, bestScore = from, s end
				end
			end
			if not best or not assign(best, need, "requirement") then break end
		end
	end
	-- 2. Swaps that measurably help, as far as requirements allow.
	local pairs_ = { }
	for from, targets in pairs(swap) do
		for to, r in pairs(targets) do
			if r.score >= MIN_GAIN then pairs_[#pairs_ + 1] = { from = from, to = to, r = r } end
		end
	end
	table.sort(pairs_, function(a, c) return a.r.score > c.r.score end)
	for _, p in ipairs(pairs_) do
		while left[p.from] >= 5 and assign(p.from, p.to, "gain") do end
	end

	local list, changes = util.array(), 0
	for _, node in ipairs(nodes) do
		local current = node.dn
		local entry = { id = node.id, current = current, recommended = current, weaponSet = node.allocMode or 0 }
		local p = plan[node]
		local t = totals[current]
		if p and p.kind == "unset" then
			changes = changes + 1
			local r = p.r
			entry.current = "unset"
			entry.recommended = p.to
			entry.dpsPercent, entry.ehpPercent, entry.lifeDelta, entry.esDelta = r.dpsPercent, r.ehpPercent, r.lifeDelta, r.esDelta
			entry.reason = string.format("No attribute chosen yet, so this node gives nothing. Choose +5 %s: %s.", SHORT[p.to], describe(r))
		elseif p then
			changes = changes + 1
			local r = swap[current][p.to]
			entry.recommended = p.to
			entry.dpsPercent, entry.ehpPercent, entry.lifeDelta, entry.esDelta = r.dpsPercent, r.ehpPercent, r.lifeDelta, r.esDelta
			if p.kind == "requirement" then
				local need = totals[p.to]
				entry.reason = string.format("Switch +5 %s to +5 %s: you have %d %s but your gear and gems need %d. (%s)",
					SHORT[current], SHORT[p.to], need.value, p.to, need.required, describe(r))
			else
				entry.reason = string.format("Switch +5 %s to +5 %s: %s. %s stays at or above the %d your gear and gems need.",
					SHORT[current], SHORT[p.to], describe(r), current, t.required)
			end
		else
			-- Explain why it stays.
			local bestTo, bestR
			for to, r in pairs(swap[current] or { }) do
				if not bestR or r.score > bestR.score then bestTo, bestR = to, r end
			end
			if bestR and bestR.score >= MIN_GAIN then
				entry.reason = string.format("Keep: +5 %s would give %s, but %s is needed (%d, gear and gems need %d).",
					SHORT[bestTo], describe(bestR), current, t.value, t.required)
				entry.blockedBy = "requirement"
			else
				entry.reason = string.format("Keep: +5 %s is already the best choice here.", SHORT[current])
			end
		end
		list[#list + 1] = entry
	end
	return { totals = totals, nodes = list, changes = changes }
end

return M
