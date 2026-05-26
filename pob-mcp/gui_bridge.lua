-- pob-mcp/gui_bridge.lua
--
-- Loaded by src/Launch.lua at startup when the file is present. Creates a
-- non-blocking TCP server on 127.0.0.1:12321 and exports a global tick function
-- (_G.pobMcpTick) that Launch.lua calls each OnFrame.
--
-- The MCP Python server auto-detects this port and switches to "GUI mode":
-- all commands operate on the live build object inside the running PoB process,
-- so changes (allocate nodes, config tweaks) appear in the GUI immediately
-- without saving/reloading XML.
--
-- Protocol: same line-delimited JSON as the headless bridge (bridge.lua).
-- Both ends are therefore interchangeable from server.py's perspective.

local ok, socket = pcall(require, "socket")
if not ok then
    ConPrintf("pob-mcp: LuaSocket not available, GUI bridge disabled")
    return
end

local dkjson = require("dkjson")

local PORT = 12321

-- Try to bind. If port is taken (another PoB instance already running with the
-- bridge) just silently skip — the Python client will use the existing one.
local srv, bindErr = socket.bind("*", PORT)
if not srv then
    ConPrintf("pob-mcp: could not bind port %d: %s", PORT, tostring(bindErr))
    return
end
srv:settimeout(0)  -- non-blocking accept

local clients = {}  -- open client sockets

--------------------------------------------------------------------------------
-- helpers
--------------------------------------------------------------------------------

local function cleanNumber(v)
    if v ~= v or v == math.huge or v == -math.huge then return nil end
    return v
end

-- Returns the active build object when a build is open in the GUI, else nil.
local function getActiveBuild()
    if not launch or not launch.main then return nil end
    local modes = launch.main.modes
    if not modes then return nil end
    local bm = modes["BUILD"]
    if not bm or not bm.spec or not bm.calcsTab then return nil end
    return bm
end

-- Synchronous recalc: update output tables and refresh the stat panel in the GUI.
local function guiRecalc(build)
    wipeGlobalCache()
    build.buildFlag = false
    build.calcsTab:BuildOutput()
    build:RefreshStatList()
end

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
                name = s.name, dps = cleanNumber(s.dps),
                count = s.count, skillPart = s.skillPart, trigger = s.trigger,
            }
        end
        res.SkillDPS = skills
    end
    return res
end

local function nodesById(build, ids)
    local set = {}
    local specNodes = build.spec and build.spec.nodes
    if not specNodes then error("build has no passive tree spec") end
    for _, id in ipairs(ids or {}) do
        local node = specNodes[id]
        if node then set[node] = true end
    end
    return set
end

--------------------------------------------------------------------------------
-- command handlers  (same surface as bridge.lua)
--------------------------------------------------------------------------------

local handlers = {}

function handlers.ping() return "pong" end

-- Return a status flag so the client can tell GUI mode from headless mode.
function handlers.gui_status()
    local build = getActiveBuild()
    return {
        gui = true,
        buildOpen = build ~= nil,
        className  = build and build.spec and build.spec.curClassName,
        ascendancy = build and build.spec and build.spec.curAscendClassName,
        level      = build and build.characterLevel,
    }
end

-- Load a build from a .xml file path or raw XML string.
-- In GUI mode this triggers PoB's own loader (SetMode), which processes the
-- build on the next OnFrame. The response arrives before the mode switch
-- completes, so the caller must wait a moment (Python side: 600 ms) and then
-- call get_output to confirm the build is ready.
function handlers.load_xml(req)
    if not launch or not launch.main then error("launch.main not ready") end
    if req.path then
        launch.main:SetMode("BUILD", false, req.path)
    elseif req.xml then
        launch.main:SetMode("BUILD", false, req.name or "MCP build", req.xml)
    else
        error("load_xml requires 'xml' or 'path'")
    end
    return { loaded = true, pending = true }
end

function handlers.get_output(req)
    local build = getActiveBuild()
    if not build then error("no build open in the PoB GUI") end
    return serializeOutput(build.calcsTab.mainOutput, req.fields)
end

function handlers.set_config(req)
    local build = getActiveBuild()
    if not build then error("no build open in the PoB GUI") end
    if req.key == nil then error("set_config requires 'key'") end
    if req.key == "mainSocketGroup" then
        build.mainSocketGroup = tonumber(req.value) or req.value
    else
        build.configTab.input[req.key] = req.value
        build.configTab:BuildModList()
    end
    guiRecalc(build)
    return { key = req.key, value = req.value }
end

function handlers.eval_override(req)
    local build = getActiveBuild()
    if not build then error("no build open in the PoB GUI") end
    local ov = req.override or {}
    local override = {}
    if ov.addNodes    then override.addNodes    = nodesById(build, ov.addNodes)    end
    if ov.removeNodes then override.removeNodes = nodesById(build, ov.removeNodes) end
    if ov.conditions  then override.conditions  = ov.conditions                    end

    local calcFunc, baseOutput = build.calcsTab.calcs.getMiscCalculator(build)
    local newOutput = calcFunc(override, req.useFullDPS ~= false)

    local metrics = req.metrics or { "FullDPS", "TotalDPS", "CombinedDPS", "Life", "EnergyShield", "Mana" }
    local deltas = {}
    for _, m in ipairs(metrics) do
        local a = tonumber(baseOutput[m]) or 0
        local b = tonumber(newOutput[m]) or 0
        deltas[m] = { base = cleanNumber(a), new = cleanNumber(b), delta = cleanNumber(b - a) }
    end
    local result = { deltas = deltas }
    if req.fullOutput then result.output = serializeOutput(newOutput) end
    return result
end

function handlers.rank_nodes(req)
    local build = getActiveBuild()
    if not build then error("no build open in the PoB GUI") end
    local metric   = req.metric   or "FullDPS"
    local maxDepth = req.maxDepth or 6
    local limit    = req.limit    or 25

    build.spec:BuildAllDependsAndPaths()

    local calcFunc, baseOutput = build.calcsTab.calcs.getMiscCalculator(build)
    local base = tonumber(baseOutput[metric]) or 0

    local cache   = {}
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
                    id   = nodeId,
                    name = node.dn or node.name,
                    type = node.type,
                    pathDist = node.pathDist,
                    delta        = cleanNumber(delta),
                    deltaPerPoint = cleanNumber(delta / math.max(node.pathDist or 1, 1)),
                }
            end
        end
    end
    table.sort(results, function(a, b) return (a.delta or 0) > (b.delta or 0) end)
    local top = {}
    for i = 1, math.min(limit, #results) do top[i] = results[i] end
    return { metric = metric, base = cleanNumber(base), nodes = top,
             evaluated = evaluated, withEffect = #results }
end

function handlers.allocate_nodes(req)
    local build = getActiveBuild()
    if not build then error("no build open in the PoB GUI") end
    build.spec:AddUndoState()
    build.spec:BuildAllDependsAndPaths()
    local ids    = req.ids or {}
    local newly  = {}
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
    guiRecalc(build)
    local o = build.calcsTab.mainOutput
    return {
        allocated = newly, alreadyAlloc = already, skipped = skipped,
        FullDPS      = o and cleanNumber(o.FullDPS),
        CombinedDPS  = o and cleanNumber(o.CombinedDPS),
        Life         = o and cleanNumber(o.Life),
        EnergyShield = o and cleanNumber(o.EnergyShield),
    }
end

function handlers.deallocate_nodes(req)
    local build = getActiveBuild()
    if not build then error("no build open in the PoB GUI") end
    build.spec:AddUndoState()
    local ids    = req.ids or {}
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
    guiRecalc(build)
    local o = build.calcsTab.mainOutput
    return {
        removed = removed, notAlloc = notAlloc,
        FullDPS      = o and cleanNumber(o.FullDPS),
        CombinedDPS  = o and cleanNumber(o.CombinedDPS),
        Life         = o and cleanNumber(o.Life),
        EnergyShield = o and cleanNumber(o.EnergyShield),
    }
end

local function getSkillGroupDiag(build)
    local groups = {}
    for i, sg in ipairs(build.skillsTab.socketGroupList or {}) do
        local gems = {}
        for _, g in ipairs(sg.gemList or {}) do gems[#gems+1] = g.nameSpec end
        groups[#groups+1] = {
            index = i, label = sg.label, enabled = sg.enabled,
            includeInFullDPS = sg.includeInFullDPS,
            isMain = (i == build.mainSocketGroup), gems = gems,
        }
    end
    return groups
end

function handlers.optimize_tree(req)
    local build = getActiveBuild()
    if not build then error("no build open in the PoB GUI") end
    local metric   = req.metric   or "CombinedDPS"
    local budget   = req.budget   or 10
    local maxDepth = req.maxDepth or 3

    build.spec:BuildAllDependsAndPaths()

    local calcFunc, baseOutput = build.calcsTab.calcs.getMiscCalculator(build)
    local base = tonumber(baseOutput[metric]) or 0
    if base == 0 then
        local diag = getSkillGroupDiag(build)
        error(string.format(
            "Base %s = 0, cannot optimize. mainSocketGroup=%s. Skill groups: %s",
            metric, tostring(build.mainSocketGroup), dkjson.encode(diag)
        ))
    end

    build.spec:AddUndoState()

    local deadline = GetTime() + 25000

    -- BFS from every node adjacent to the allocated tree.
    -- Finds ALL paths (not just PoB's single shortest path) up to depthLimit steps.
    -- Returns a flat list of candidates: {node, pathList, cost, addSet}.
    -- Each unique path to each reachable notable/normal node is a separate candidate.
    -- Deduplication is by sorted node-id set so the same allocation isn't evaluated twice.
    local function gatherCandidates(depthLimit)
        local candidates = {}
        local seenKeys   = {}
        local grantedPassives = build.calcsTab.mainEnv and build.calcsTab.mainEnv.grantedPassives

        -- BFS queue entries: {front=node, pathList={...}, pathSet={id=true}}
        local queue   = {}
        local qHead   = 1
        local seenStart = {}
        for _, node in pairs(build.spec.nodes) do
            if not node.alloc and not node.ascendancyName then
                for _, nb in ipairs(node.linked or {}) do
                    if nb.alloc and not seenStart[node.id] then
                        seenStart[node.id] = true
                        queue[#queue + 1] = {
                            front    = node,
                            pathList = { node },
                            pathSet  = { [node.id] = true },
                        }
                        break
                    end
                end
            end
        end

        while qHead <= #queue do
            local item  = queue[qHead]; qHead = qHead + 1
            local depth = #item.pathList
            local node  = item.front

            -- Add as candidate if this node contributes mods and fits in budget
            if node.modKey and node.modKey ~= ""
                and not (grantedPassives and grantedPassives[node.id]) then

                -- Key = endNodeId + sorted path ids (same allocation = same key)
                local ids = {}
                for id in pairs(item.pathSet) do ids[#ids + 1] = id end
                table.sort(ids)
                local key = table.concat(ids, ",")

                if not seenKeys[key] then
                    seenKeys[key] = true
                    local addSet = {}
                    for _, n in ipairs(item.pathList) do addSet[n] = true end
                    candidates[#candidates + 1] = {
                        node     = node,
                        pathList = item.pathList,
                        cost     = depth,
                        addSet   = addSet,
                    }
                end
            end

            -- Expand deeper
            if depth < depthLimit then
                for _, nb in ipairs(node.linked or {}) do
                    if not nb.alloc and not nb.ascendancyName
                        and not item.pathSet[nb.id] then
                        local newList = {}
                        for _, n in ipairs(item.pathList) do newList[#newList + 1] = n end
                        newList[#newList + 1] = nb
                        local newSet = {}
                        for k in pairs(item.pathSet) do newSet[k] = true end
                        newSet[nb.id] = true
                        queue[#queue + 1] = {
                            front    = nb,
                            pathList = newList,
                            pathSet  = newSet,
                        }
                    end
                end
            end
        end
        return candidates
    end

    local remaining = budget
    local steps = {}
    while remaining > 0 do
        if GetTime() > deadline then
            steps[#steps + 1] = { timedOut = true, remainingPoints = remaining }
            break
        end

        local depthLimit = math.min(maxDepth, remaining)
        local candidates = gatherCandidates(depthLimit)

        local bestNode, bestPath, bestEfficiency, bestDelta = nil, nil, 0, 0
        for _, cand in ipairs(candidates) do
            if GetTime() > deadline then break end
            local out = calcFunc({ addNodes = cand.addSet }, true)
            local val = tonumber(out[metric]) or 0
            local delta = val - base
            local efficiency = delta / cand.cost
            if efficiency > bestEfficiency then
                bestEfficiency = efficiency
                bestDelta      = delta
                bestNode       = cand.node
                bestPath       = cand.pathList
            end
        end
        if not bestNode then break end

        -- Allocate via our BFS-chosen path so PoB doesn't pick an arbitrary one
        local before = 0
        for _ in pairs(build.spec.allocNodes) do before = before + 1 end
        build.spec:AllocNode(bestNode, bestPath)
        local after = 0
        for _ in pairs(build.spec.allocNodes) do after = after + 1 end
        local actualCost = after - before

        remaining = remaining - actualCost
        build.spec:BuildAllDependsAndPaths()
        steps[#steps + 1] = {
            step = #steps + 1, id = bestNode.id, name = bestNode.dn or bestNode.name,
            delta = cleanNumber(bestDelta), cost = actualCost,
            remainingPoints = remaining,
        }

        calcFunc, baseOutput = build.calcsTab.calcs.getMiscCalculator(build)
        base = tonumber(baseOutput[metric]) or 0
    end

    guiRecalc(build)
    local o = build.calcsTab.mainOutput
    return {
        metric = metric, steps = steps,
        pointsUsed = budget - remaining,
        stepsCount = #steps,
        finalValue   = cleanNumber(tonumber(o[metric]) or 0),
        CombinedDPS  = o and cleanNumber(o.CombinedDPS),
        Life         = o and cleanNumber(o.Life),
        EnergyShield = o and cleanNumber(o.EnergyShield),
    }
end

function handlers.set_gem(req)
    local build = getActiveBuild()
    if not build then error("no build open in the PoB GUI") end
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
    guiRecalc(build)
    local o = build.calcsTab.mainOutput
    return {
        group = req.group, name = req.name, level = req.level, quality = req.quality,
        CombinedDPS  = o and cleanNumber(o.CombinedDPS),
        FullDPS      = o and cleanNumber(o.FullDPS),
        EnergyShield = o and cleanNumber(o.EnergyShield),
    }
end

function handlers.undo_tree(req)
    local build = getActiveBuild()
    if not build then error("no build open in the PoB GUI") end
    build.spec:Undo()
    guiRecalc(build)
    local o = build.calcsTab.mainOutput
    return { CombinedDPS = o and cleanNumber(o.CombinedDPS), Life = o and cleanNumber(o.Life), EnergyShield = o and cleanNumber(o.EnergyShield) }
end

function handlers.redo_tree(req)
    local build = getActiveBuild()
    if not build then error("no build open in the PoB GUI") end
    build.spec:Redo()
    guiRecalc(build)
    local o = build.calcsTab.mainOutput
    return { CombinedDPS = o and cleanNumber(o.CombinedDPS), Life = o and cleanNumber(o.Life), EnergyShield = o and cleanNumber(o.EnergyShield) }
end

function handlers.get_xml(req)
    local build = getActiveBuild()
    if not build then error("no build open in the PoB GUI") end
    local xml = build:SaveDB(req.name or "MCP build")
    if type(xml) ~= "string" or xml == "" then
        error("build:SaveDB() returned nothing")
    end
    return { xml = xml }
end

function handlers.list_state(req)
    local build = getActiveBuild()
    if not build then error("no build open in the PoB GUI") end
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
                label = sg.label, slot = sg.slot, enabled = sg.enabled,
                includeInFullDPS = sg.includeInFullDPS,
                mainActiveSkill = sg.mainActiveSkill, gems = gems,
            }
        end
        return { mainSocketGroup = build.mainSocketGroup, groups = groups }
    elseif what == "items" then
        local items = {}
        for slotName, slot in pairs(build.itemsTab.slots or {}) do
            if slot.selItemId and slot.selItemId ~= 0 then
                local item = build.itemsTab.items[slot.selItemId]
                if item then items[#items + 1] = { slot = slotName, name = item.name, rarity = item.rarity } end
            end
        end
        return { items = items }
    elseif what == "nodes" then
        local alloc = {}
        for nodeId, node in pairs(build.spec.allocNodes or {}) do
            alloc[#alloc + 1] = { id = nodeId, name = node.dn or node.name, type = node.type }
        end
        return { allocated = alloc, usedPoints = #alloc }
    else
        local o = build.calcsTab.mainOutput
        return {
            className  = build.spec and build.spec.curClassName,
            ascendancy = build.spec and build.spec.curAscendClassName,
            level      = build.characterLevel,
            FullDPS      = o and cleanNumber(o.FullDPS),
            CombinedDPS  = o and cleanNumber(o.CombinedDPS),
            Life         = o and cleanNumber(o.Life),
            EnergyShield = o and cleanNumber(o.EnergyShield),
        }
    end
end

--------------------------------------------------------------------------------
-- per-client read buffer (handles partial lines)
--------------------------------------------------------------------------------

local buffers = {}   -- socket -> accumulated string

local function processClient(c)
    buffers[c] = buffers[c] or ""
    local chunk, err, partial = c:receive(4096)
    local data = chunk or partial or ""
    if data ~= "" then
        buffers[c] = buffers[c] .. data
    end

    -- Process all complete lines
    while true do
        local nl = buffers[c]:find("\n", 1, true)
        if not nl then break end
        local line = buffers[c]:sub(1, nl - 1)
        buffers[c] = buffers[c]:sub(nl + 1)
        if line ~= "" then
            local req, _, perr = dkjson.decode(line)
            if not req then
                c:send(dkjson.encode({ ok = false, error = "invalid JSON: " .. tostring(perr) }) .. "\n")
            else
                local handler = handlers[req.cmd]
                if not handler then
                    c:send(dkjson.encode({ id = req.id, ok = false, error = "unknown cmd: " .. tostring(req.cmd) }) .. "\n")
                else
                    local ok2, result = pcall(handler, req)
                    if ok2 then
                        c:send(dkjson.encode({ id = req.id, ok = true, result = result }) .. "\n")
                    else
                        c:send(dkjson.encode({ id = req.id, ok = false, error = tostring(result) }) .. "\n")
                    end
                end
            end
        end
    end

    return err  -- "closed" | "timeout" | nil
end

--------------------------------------------------------------------------------
-- global tick function — called from Launch.lua:OnFrame every frame
--------------------------------------------------------------------------------

function _G.pobMcpTick()
    -- Accept new connections (non-blocking)
    local client = srv:accept()
    if client then
        client:settimeout(0)
        clients[#clients + 1] = client
        -- Send handshake so engine_client knows we're ready
        client:send(dkjson.encode({ event = "ready", gui = true }) .. "\n")
    end

    -- Serve existing clients
    local i = 1
    while i <= #clients do
        local err = processClient(clients[i])
        if err == "closed" then
            buffers[clients[i]] = nil
            table.remove(clients, i)
        else
            i = i + 1
        end
    end
end

ConPrintf("pob-mcp: GUI bridge listening on 127.0.0.1:%d", PORT)
