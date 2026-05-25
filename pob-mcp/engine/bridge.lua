-- pob-mcp engine bridge
--
-- Loads Path of Building headless and exposes a line-delimited JSON protocol over
-- stdin/stdout so an external process (the MCP server) can drive build analysis.
--
-- Must be launched with the working directory set to PoB's `src/` folder, and with
-- LUA_PATH / LUA_CPATH pointing at `../runtime/lua/?.lua` and `../runtime/?.dll`
-- (HeadlessWrapper requires `dofile("Launch.lua")` and the `lua-utf8` C module).
--
-- Protocol: one JSON object per line in, one JSON object per line out.
--   request : {"id": <any>, "cmd": "<name>", ...args}
--   response: {"id": <any>, "ok": true,  "result": <value>}
--          or {"id": <any>, "ok": false, "error": "<message>"}
--
-- PoB writes a lot of diagnostic text via ConPrintf -> print. We redirect every
-- such write to stderr so stdout carries only protocol JSON.

local realStdout = io.stdout

local function logf(fmt, ...)
	io.stderr:write(string.format(fmt, ...), "\n")
end

print = function(...)
	local n = select("#", ...)
	local parts = {}
	for i = 1, n do parts[i] = tostring((select(i, ...))) end
	io.stderr:write(table.concat(parts, "\t"), "\n")
end

-- Boot the engine (this defines: build, newBuild, loadBuildFromXML, runCallback, mainObject)
dofile("HeadlessWrapper.lua")

if mainObject and mainObject.promptMsg then
	io.stderr:write("FATAL during PoB startup: " .. tostring(mainObject.promptMsg) .. "\n")
	os.exit(1)
end

local dkjson = require("dkjson")

--------------------------------------------------------------------------------
-- helpers
--------------------------------------------------------------------------------

local function reply(obj)
	realStdout:write(dkjson.encode(obj, { keyorder = nil }), "\n")
	realStdout:flush()
end

-- Convert non-finite numbers to nil so JSON encoding stays valid.
local function cleanNumber(v)
	if v ~= v then return nil end            -- NaN
	if v == math.huge or v == -math.huge then return nil end
	return v
end

-- Pull scalar stats out of a PoB output table. Tables/functions are skipped,
-- except SkillDPS which is flattened to an array of {name, dps, ...}.
local function serializeOutput(output, fields)
	local res = {}
	if not output then return res end
	if fields then
		for _, k in ipairs(fields) do
			local v = output[k]
			local t = type(v)
			if t == "number" then res[k] = cleanNumber(v)
			elseif t == "string" or t == "boolean" then res[k] = v end
		end
	else
		for k, v in pairs(output) do
			local t = type(v)
			if t == "number" then
				local n = cleanNumber(v)
				if n ~= nil then res[k] = n end
			elseif t == "string" or t == "boolean" then
				res[k] = v
			end
		end
	end
	if type(output.SkillDPS) == "table" then
		local skills = {}
		for _, s in ipairs(output.SkillDPS) do
			skills[#skills + 1] = {
				name = s.name,
				dps = cleanNumber(s.dps),
				count = s.count,
				skillPart = s.skillPart,
				trigger = s.trigger,
			}
		end
		res.SkillDPS = skills
	end
	return res
end

local function requireBuild()
	if not build or build.dbFileName == nil and not build.spec then
		error("no build loaded; call load_xml or new_build first")
	end
end

-- Resolve a list of node ids to the set form PoB's calculator expects:
--   { [nodeObject] = true, ... }
local function nodesById(ids)
	local set = {}
	local specNodes = build.spec and build.spec.nodes
	if not specNodes then error("build has no passive tree spec") end
	for _, id in ipairs(ids or {}) do
		local node = specNodes[id]
		if node then set[node] = true end
	end
	return set
end

local function recalc()
	build.buildFlag = true
	runCallback("OnFrame")
end

--------------------------------------------------------------------------------
-- command handlers
--------------------------------------------------------------------------------

local handlers = {}

function handlers.ping()
	return "pong"
end

function handlers.new_build()
	newBuild()
	return { loaded = true }
end

function handlers.load_xml(req)
	if type(req.xml) ~= "string" or req.xml == "" then
		error("load_xml requires a non-empty 'xml' string")
	end
	loadBuildFromXML(req.xml, req.name or "MCP build")
	recalc()
	local o = build.calcsTab.mainOutput
	return {
		loaded = true,
		className = build.spec and build.spec.curClassName,
		ascendancy = build.spec and build.spec.curAscendClassName,
		level = build.characterLevel,
		mainSocketGroup = build.mainSocketGroup,
		FullDPS = o and cleanNumber(o.FullDPS),
		Life = o and cleanNumber(o.Life),
	}
end

function handlers.get_output(req)
	requireBuild()
	return serializeOutput(build.calcsTab.mainOutput, req.fields)
end

function handlers.set_config(req)
	requireBuild()
	if req.key == nil then error("set_config requires 'key'") end
	if req.key == "mainSocketGroup" then
		-- mainSocketGroup is a build-level property, not a configTab input.
		build.mainSocketGroup = tonumber(req.value) or req.value
		recalc()
		return { key = req.key, value = build.mainSocketGroup }
	end
	build.configTab.input[req.key] = req.value
	build.configTab:BuildModList()
	recalc()
	return { key = req.key, value = build.configTab.input[req.key] }
end

-- Generic what-if. override = { addNodes=[ids], removeNodes=[ids], conditions=[..] }
-- Returns the resulting output plus deltas vs the current build for key stats.
function handlers.eval_override(req)
	requireBuild()
	local ov = req.override or {}
	local override = {}
	if ov.addNodes then override.addNodes = nodesById(ov.addNodes) end
	if ov.removeNodes then override.removeNodes = nodesById(ov.removeNodes) end
	if ov.conditions then override.conditions = ov.conditions end

	local calcFunc, baseOutput = build.calcsTab.calcs.getMiscCalculator(build)
	local newOutput = calcFunc(override, req.useFullDPS ~= false)

	local metrics = req.metrics or { "FullDPS", "TotalDPS", "Life", "EnergyShield", "Mana" }
	local deltas = {}
	for _, m in ipairs(metrics) do
		local a = tonumber(baseOutput[m]) or 0
		local b = tonumber(newOutput[m]) or 0
		deltas[m] = { base = cleanNumber(a), new = cleanNumber(b), delta = cleanNumber(b - a) }
	end
	local result = { deltas = deltas }
	if req.fullOutput then
		result.output = serializeOutput(newOutput, req.fields)
	end
	return result
end

-- Permanently allocate passive nodes and recalculate.
-- req = { ids = [nodeId, ...] }
-- Returns { allocated=[ids actually newly allocated], alreadyAlloc=[ids already taken],
--           skipped=[ids with no path to tree] }
function handlers.allocate_nodes(req)
	requireBuild()
	build.spec:AddUndoState()
	build.spec:BuildAllDependsAndPaths()
	local ids = req.ids or {}
	local newly = {}
	local already = {}
	local skipped = {}
	for _, id in ipairs(ids) do
		local node = build.spec.nodes[id]
		if not node then error("node id not found: " .. tostring(id)) end
		if node.alloc then
			already[#already + 1] = id
		elseif not node.path then
			skipped[#skipped + 1] = id
		else
			build.spec:AllocNode(node)
			newly[#newly + 1] = id
		end
	end
	recalc()
	local o = build.calcsTab.mainOutput
	return {
		allocated = newly, alreadyAlloc = already, skipped = skipped,
		FullDPS = o and cleanNumber(o.FullDPS),
		CombinedDPS = o and cleanNumber(o.CombinedDPS),
		Life = o and cleanNumber(o.Life),
		EnergyShield = o and cleanNumber(o.EnergyShield),
	}
end

-- Permanently deallocate passive nodes and recalculate.
-- req = { ids = [nodeId, ...] }
function handlers.deallocate_nodes(req)
	requireBuild()
	build.spec:AddUndoState()
	local ids = req.ids or {}
	local removed = {}
	local notAlloc = {}
	for _, id in ipairs(ids) do
		local node = build.spec.nodes[id]
		if not node then error("node id not found: " .. tostring(id)) end
		if not node.alloc then
			notAlloc[#notAlloc + 1] = id
		else
			build.spec:DeallocNode(node)
			removed[#removed + 1] = id
		end
	end
	recalc()
	local o = build.calcsTab.mainOutput
	return {
		removed = removed, notAlloc = notAlloc,
		FullDPS = o and cleanNumber(o.FullDPS),
		CombinedDPS = o and cleanNumber(o.CombinedDPS),
		Life = o and cleanNumber(o.Life),
		EnergyShield = o and cleanNumber(o.EnergyShield),
	}
end

-- Greedy passive tree optimizer: each step picks the single best node and allocates it.
-- One undo state is saved before all steps so the whole run can be undone at once.
-- req = { metric, budget, maxDepth }
function handlers.optimize_tree(req)
	requireBuild()
	local metric   = req.metric   or "CombinedDPS"
	local budget   = req.budget   or 10
	local maxDepth = req.maxDepth or 3

	build.spec:AddUndoState()
	build.spec:BuildAllDependsAndPaths()

	local steps = {}
	for step = 1, budget do
		local calcFunc, baseOutput = build.calcsTab.calcs.getMiscCalculator(build)
		local base = tonumber(baseOutput[metric]) or 0
		local bestNode, bestDelta, bestName = nil, 0, nil
		local cache = {}
		for nodeId, node in pairs(build.spec.nodes) do
			if not node.alloc and node.modKey and node.modKey ~= ""
				and node.path and (node.pathDist or 999) <= maxDepth
				and not node.ascendancyName
				and not (build.calcsTab.mainEnv and build.calcsTab.mainEnv.grantedPassives[nodeId]) then
				local val = cache[node.modKey]
				if val == nil then
					local out = calcFunc({ addNodes = { [node] = true } }, true)
					val = tonumber(out[metric]) or 0
					cache[node.modKey] = val
				end
				local delta = val - base
				if delta > bestDelta then
					bestDelta, bestNode, bestName = delta, node, node.dn or node.name
				end
			end
		end
		if not bestNode then break end
		build.spec:AllocNode(bestNode)
		build.spec:BuildAllDependsAndPaths()
		steps[#steps + 1] = { step = step, id = bestNode.id, name = bestName, delta = cleanNumber(bestDelta) }
	end

	recalc()
	local o = build.calcsTab.mainOutput
	return {
		metric = metric, steps = steps, pointsUsed = #steps,
		finalValue   = cleanNumber(tonumber(o[metric]) or 0),
		CombinedDPS  = o and cleanNumber(o.CombinedDPS),
		Life         = o and cleanNumber(o.Life),
		EnergyShield = o and cleanNumber(o.EnergyShield),
	}
end

-- Change the level and/or quality of a gem in a socket group.
-- req = { group=<1-based>, name=<nameSpec>, level=<int>?, quality=<int>? }
function handlers.set_gem(req)
	requireBuild()
	local sg = build.skillsTab.socketGroupList[req.group]
	if not sg then error("socket group " .. tostring(req.group) .. " not found") end
	local found = false
	for _, gem in ipairs(sg.gemList or {}) do
		if gem.nameSpec == req.name then
			if req.level   ~= nil then gem.level   = req.level   end
			if req.quality ~= nil then gem.quality  = req.quality end
			found = true
			break
		end
	end
	if not found then error("gem '" .. tostring(req.name) .. "' not found in group " .. tostring(req.group)) end
	build.skillsTab:ProcessSocketGroup(sg)
	recalc()
	local o = build.calcsTab.mainOutput
	return {
		group = req.group, name = req.name, level = req.level, quality = req.quality,
		CombinedDPS  = o and cleanNumber(o.CombinedDPS),
		FullDPS      = o and cleanNumber(o.FullDPS),
		EnergyShield = o and cleanNumber(o.EnergyShield),
	}
end

-- Undo the last passive tree change (allocate / deallocate / optimize_tree).
function handlers.undo_tree(req)
	requireBuild()
	build.spec:Undo()
	recalc()
	local o = build.calcsTab.mainOutput
	return { CombinedDPS = o and cleanNumber(o.CombinedDPS), Life = o and cleanNumber(o.Life), EnergyShield = o and cleanNumber(o.EnergyShield) }
end

-- Redo the last undone passive tree change.
function handlers.redo_tree(req)
	requireBuild()
	build.spec:Redo()
	recalc()
	local o = build.calcsTab.mainOutput
	return { CombinedDPS = o and cleanNumber(o.CombinedDPS), Life = o and cleanNumber(o.Life), EnergyShield = o and cleanNumber(o.EnergyShield) }
end

-- Export the current build state as XML (for saving or loading in PoB GUI).
function handlers.get_xml(req)
	requireBuild()
	local xml = build:SaveDB(req.name or "MCP build")
	if type(xml) ~= "string" or xml == "" then
		error("build:SaveDB() returned nothing; build may not be fully loaded")
	end
	return { xml = xml }
end

-- Rank unallocated passive nodes by their marginal contribution.
-- req = { metric="FullDPS"|"Life"|..., maxDepth=<points>, limit=<N> }
function handlers.rank_nodes(req)
	requireBuild()
	local metric = req.metric or "FullDPS"
	local maxDepth = req.maxDepth or 6
	local limit = req.limit or 25

	-- Ensure node.path / node.pathDist are populated (the GUI builds these when the
	-- tree is drawn; in headless we must trigger it explicitly).
	build.spec:BuildAllDependsAndPaths()

	local calcFunc, baseOutput = build.calcsTab.calcs.getMiscCalculator(build)
	local base = tonumber(baseOutput[metric]) or 0

	local cache = {}
	local results = {}
	local evaluated = 0
	for nodeId, node in pairs(build.spec.nodes) do
		if not node.alloc
			and node.modKey and node.modKey ~= ""
			and node.path
			and (node.pathDist or 999) <= maxDepth
			and not (build.calcsTab.mainEnv and build.calcsTab.mainEnv.grantedPassives[nodeId])
			and not node.ascendancyName then
			evaluated = evaluated + 1
			local val = cache[node.modKey]
			if val == nil then
				local out = calcFunc({ addNodes = { [node] = true } }, req.useFullDPS ~= false)
				val = tonumber(out[metric]) or 0
				cache[node.modKey] = val
			end
			local delta = val - base
			if delta ~= 0 then
				results[#results + 1] = {
					id = nodeId,
					name = node.dn or node.name,
					type = node.type,
					pathDist = node.pathDist,
					delta = cleanNumber(delta),
					deltaPerPoint = cleanNumber(delta / math.max(node.pathDist or 1, 1)),
				}
			end
		end
	end
	table.sort(results, function(a, b) return (a.delta or 0) > (b.delta or 0) end)
	local top = {}
	for i = 1, math.min(limit, #results) do top[i] = results[i] end
	return { metric = metric, base = cleanNumber(base), nodes = top, evaluated = evaluated, withEffect = #results }
end

function handlers.list_state(req)
	requireBuild()
	local what = req.what or "summary"
	if what == "config" then
		local input = {}
		for k, v in pairs(build.configTab.input) do
			local t = type(v)
			if t == "number" or t == "string" or t == "boolean" then input[k] = v end
		end
		return { input = input }
	elseif what == "skills" then
		local groups = {}
		for _, sg in ipairs(build.skillsTab.socketGroupList or {}) do
			local gems = {}
			for _, gem in ipairs(sg.gemList or {}) do
				gems[#gems + 1] = { name = gem.nameSpec, level = gem.level, quality = gem.quality, enabled = gem.enabled }
			end
			groups[#groups + 1] = {
				label = sg.label,
				slot = sg.slot,
				enabled = sg.enabled,
				includeInFullDPS = sg.includeInFullDPS,
				mainActiveSkill = sg.mainActiveSkill,
				gems = gems,
			}
		end
		return { mainSocketGroup = build.mainSocketGroup, groups = groups }
	elseif what == "items" then
		local items = {}
		for slotName, slot in pairs(build.itemsTab.slots or {}) do
			if slot.selItemId and slot.selItemId ~= 0 then
				local item = build.itemsTab.items[slot.selItemId]
				if item then
					items[#items + 1] = { slot = slotName, name = item.name, rarity = item.rarity }
				end
			end
		end
		return { items = items }
	elseif what == "nodes" then
		local alloc = {}
		for nodeId, node in pairs(build.spec.allocNodes or {}) do
			alloc[#alloc + 1] = { id = nodeId, name = node.dn or node.name, type = node.type }
		end
		return { allocated = alloc, usedPoints = build.spec.allocNodes and #alloc }
	else -- summary
		local o = build.calcsTab.mainOutput
		return {
			className = build.spec and build.spec.curClassName,
			ascendancy = build.spec and build.spec.curAscendClassName,
			level = build.characterLevel,
			FullDPS = o and cleanNumber(o.FullDPS),
			Life = o and cleanNumber(o.Life),
			EnergyShield = o and cleanNumber(o.EnergyShield),
		}
	end
end

--------------------------------------------------------------------------------
-- main loop
--------------------------------------------------------------------------------

logf("pob-mcp bridge ready")
reply({ event = "ready" })

while true do
	local line = io.read("*l")
	if line == nil then break end
	if line ~= "" then
		local req, _, perr = dkjson.decode(line)
		if not req then
			reply({ ok = false, error = "invalid JSON: " .. tostring(perr) })
		else
			local handler = handlers[req.cmd]
			if not handler then
				reply({ id = req.id, ok = false, error = "unknown cmd: " .. tostring(req.cmd) })
			else
				local ok, result = pcall(handler, req)
				if ok then
					reply({ id = req.id, ok = true, result = result })
				else
					reply({ id = req.id, ok = false, error = tostring(result) })
				end
			end
		end
	end
end
