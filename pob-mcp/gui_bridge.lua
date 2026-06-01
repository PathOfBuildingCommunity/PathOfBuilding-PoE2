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

local function nextItemId(build)
    local maxId = 0
    for id in pairs(build.itemsTab.items or {}) do
        if type(id) == "number" and id > maxId then maxId = id end
    end
    return maxId + 1
end

local function serializeItemMods(item)
    local mods = {}
    local function add(list, mtype)
        for _, ml in ipairs(list or {}) do
            if ml.line then mods[#mods+1] = { type = mtype, line = ml.line } end
        end
    end
    add(item.implicitModLines, "implicit")
    add(item.explicitModLines, "explicit")
    add(item.enchantModLines,  "enchant")
    add(item.runeModLines,     "rune")
    return mods
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
    local ids       = req.ids or {}
    local removed   = {}
    local notAlloc  = {}
    local protected = {}  -- ClassStart / AscendClassStart — never removable
    for _, id in ipairs(ids) do
        local node = build.spec.nodes[id]
        if not node then error("node id not found: " .. tostring(id)) end
        if node.type == "ClassStart" or node.type == "AscendClassStart" then
            protected[#protected + 1] = id
        elseif not node.alloc then
            notAlloc[#notAlloc + 1] = id
        else
            build.spec:DeallocNode(node)
            removed[#removed + 1] = id
        end
    end
    guiRecalc(build)
    local o = build.calcsTab.mainOutput
    return {
        removed = removed, notAlloc = notAlloc, protected = protected,
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
    local metric         = req.metric         or "CombinedDPS"
    local budget         = req.budget         or 10
    local maxDepth       = req.maxDepth       or 3
    local weights        = req.weights        -- optional {metric->weight}, normalised scoring
    local minConstraints = req.minConstraints -- optional {metric->minValue}, hard floor

    build.spec:BuildAllDependsAndPaths()
    local calcFunc, baseOutput = build.calcsTab.calcs.getMiscCalculator(build)
    local base = tonumber(baseOutput[metric]) or 0

    if base == 0 and not weights then
        local diag = getSkillGroupDiag(build)
        error(string.format(
            "Base %s = 0, cannot optimize. mainSocketGroup=%s. Skill groups: %s",
            metric, tostring(build.mainSocketGroup), dkjson.encode(diag)
        ))
    end

    build.spec:AddUndoState()
    local deadline = GetTime() + 25000

    -- Weighted normalised score: sum of w_i * (new_i - base_i) / |base_i|.
    -- Falls back to simple absolute delta when no weights are given.
    local function computeScore(out)
        if not weights then
            return (tonumber(out[metric]) or 0) - base
        end
        local score = 0
        for m, w in pairs(weights) do
            local a = tonumber(baseOutput[m]) or 0
            local b = tonumber(out[m]) or 0
            if a ~= 0 then score = score + w * (b - a) / math.abs(a) end
        end
        return score
    end

    -- Returns false if any minConstraint would be violated by this output.
    local function meetsConstraints(out)
        if not minConstraints then return true end
        for m, minVal in pairs(minConstraints) do
            if (tonumber(out[m]) or 0) < minVal then return false end
        end
        return true
    end

    -- Cache key based on the combined modKey set of the path.
    -- Two paths whose nodes share identical modifier sets produce the same calc
    -- result, so we can skip redundant calcFunc calls.
    local function pathCacheKey(pathList)
        local keys = {}
        for _, n in ipairs(pathList) do
            if n.modKey and n.modKey ~= "" then keys[#keys + 1] = n.modKey end
        end
        table.sort(keys)
        return table.concat(keys, "\0")
    end

    -- BFS from every node adjacent to the allocated tree.
    -- Gathers all unique allocation-paths up to depthLimit for normal nodes,
    -- and up to maxSearchDepth for Notables/Keystones (lookahead beyond budget step).
    -- Deduplication: sorted path-id set → only one entry per unique allocation.
    local function gatherCandidates(depthLimit, remaining)
        local candidates  = {}
        local seenKeys    = {}
        local grantedPassives = build.calcsTab.mainEnv and build.calcsTab.mainEnv.grantedPassives
        local maxSearchDepth  = math.min(8, remaining)

        local queue, qHead = {}, 1
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

            if node.modKey and node.modKey ~= ""
                and not (grantedPassives and grantedPassives[node.id]) then
                local shouldAdd = depth <= depthLimit
                    or (depth <= maxSearchDepth
                        and (node.type == "Notable" or node.type == "Keystone"))
                if shouldAdd then
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
            end

            if depth < maxSearchDepth then
                for _, nb in ipairs(node.linked or {}) do
                    if not nb.alloc and not nb.ascendancyName
                        and not item.pathSet[nb.id] then
                        local newList, newSet = {}, {}
                        for _, n in ipairs(item.pathList) do newList[#newList + 1] = n end
                        newList[#newList + 1] = nb
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
    local steps     = {}
    while remaining > 0 do
        if GetTime() > deadline then
            steps[#steps + 1] = { timedOut = true, remainingPoints = remaining }
            break
        end

        local depthLimit = math.min(maxDepth, remaining)
        local candidates = gatherCandidates(depthLimit, remaining)
        local evalCache  = {}  -- modKey-set cache, reset each step (base changed)

        local bestNode, bestPath, bestEfficiency, bestDelta = nil, nil, 0, 0
        for _, cand in ipairs(candidates) do
            if GetTime() > deadline then break end
            local ckey = pathCacheKey(cand.pathList)
            local out  = evalCache[ckey]
            if not out then
                out = calcFunc({ addNodes = cand.addSet }, true)
                evalCache[ckey] = out
            end
            if meetsConstraints(out) then
                local s = computeScore(out)
                local efficiency = s / cand.cost
                if efficiency > bestEfficiency then
                    bestEfficiency = efficiency
                    bestDelta      = (tonumber(out[metric]) or 0) - base
                    bestNode       = cand.node
                    bestPath       = cand.pathList
                end
            end
        end
        if not bestNode then break end

        local before = 0
        for _ in pairs(build.spec.allocNodes) do before = before + 1 end
        build.spec:AllocNode(bestNode, bestPath)
        local after = 0
        for _ in pairs(build.spec.allocNodes) do after = after + 1 end
        local actualCost = after - before

        remaining = remaining - actualCost
        build.spec:BuildAllDependsAndPaths()
        steps[#steps + 1] = {
            step  = #steps + 1,
            id    = bestNode.id,
            name  = bestNode.dn or bestNode.name,
            type  = bestNode.type,
            delta = cleanNumber(bestDelta),
            cost  = actualCost,
            remainingPoints = remaining,
        }

        calcFunc, baseOutput = build.calcsTab.calcs.getMiscCalculator(build)
        base = tonumber(baseOutput[metric]) or 0
    end

    guiRecalc(build)
    local o = build.calcsTab.mainOutput
    return {
        metric     = metric,
        steps      = steps,
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
                if item then
                    local entry = { slot = slotName, name = item.name, rarity = item.rarity }
                    if slotName:match("^Flask") then entry.active = slot.active or false end
                    items[#items + 1] = entry
                end
            end
        end
        return { items = items }
    elseif what == "nodes" then
        local alloc      = {}
        local usedPoints = 0
        for nodeId, node in pairs(build.spec.allocNodes or {}) do
            alloc[#alloc + 1] = { id = nodeId, name = node.dn or node.name, type = node.type }
            -- Mirror PassiveSpec:CountAllocNodes — start nodes and free-allocate nodes
            -- don't cost a passive point and must not be counted.
            if node.type ~= "ClassStart" and node.type ~= "AscendClassStart"
                and not node.isFreeAllocate then
                usedPoints = usedPoints + 1
            end
        end
        return { allocated = alloc, usedPoints = usedPoints }
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

function handlers.equip_item(req)
    local build = getActiveBuild()
    if not build then error("no build open in the PoB GUI") end
    if not req.slot      then error("equip_item requires 'slot'") end
    if not req.item_text then error("equip_item requires 'item_text'") end
    local slot = build.itemsTab.slots[req.slot]
    if not slot then
        local avail = {}
        for k in pairs(build.itemsTab.slots or {}) do avail[#avail+1] = k end
        table.sort(avail)
        error("slot '" .. req.slot .. "' not found. Available: " .. table.concat(avail, ", "))
    end
    local item = new("Item")
    item:ParseRaw(req.item_text)
    local newId = nextItemId(build)
    item.id = newId
    build.itemsTab.items[newId] = item
    slot.selItemId = newId
    guiRecalc(build)
    local o = build.calcsTab.mainOutput
    return {
        slot = req.slot, name = item.name, rarity = item.rarity, itemId = newId,
        FullDPS = o and cleanNumber(o.FullDPS), CombinedDPS = o and cleanNumber(o.CombinedDPS),
        Life = o and cleanNumber(o.Life), EnergyShield = o and cleanNumber(o.EnergyShield),
    }
end

function handlers.remove_item(req)
    local build = getActiveBuild()
    if not build then error("no build open in the PoB GUI") end
    if not req.slot then error("remove_item requires 'slot'") end
    local slot = build.itemsTab.slots[req.slot]
    if not slot then error("slot '" .. req.slot .. "' not found") end
    local oldId = slot.selItemId
    slot.selItemId = 0
    guiRecalc(build)
    local o = build.calcsTab.mainOutput
    return {
        slot = req.slot, removedItemId = oldId,
        FullDPS = o and cleanNumber(o.FullDPS), CombinedDPS = o and cleanNumber(o.CombinedDPS),
        Life = o and cleanNumber(o.Life), EnergyShield = o and cleanNumber(o.EnergyShield),
    }
end

function handlers.get_item_details(req)
    local build = getActiveBuild()
    if not build then error("no build open in the PoB GUI") end
    if not req.slot then error("get_item_details requires 'slot'") end
    local slot = build.itemsTab.slots[req.slot]
    if not slot then error("slot '" .. req.slot .. "' not found") end
    if not slot.selItemId or slot.selItemId == 0 then
        return { slot = req.slot, empty = true }
    end
    local item = build.itemsTab.items[slot.selItemId]
    if not item then return { slot = req.slot, empty = true } end
    return {
        slot = req.slot, id = item.id, name = item.name,
        baseName = item.baseName, rarity = item.rarity, quality = item.quality,
        raw = item.raw, mods = serializeItemMods(item),
    }
end

function handlers.eval_item_change(req)
    local build = getActiveBuild()
    if not build then error("no build open in the PoB GUI") end
    if not req.slot      then error("eval_item_change requires 'slot'") end
    if not req.item_text then error("eval_item_change requires 'item_text'") end
    local slot = build.itemsTab.slots[req.slot]
    if not slot then error("slot '" .. req.slot .. "' not found") end
    local metrics = req.metrics or { "FullDPS", "TotalDPS", "CombinedDPS", "Life", "EnergyShield", "Mana" }
    -- capture base values before any mutation
    local baseVals = {}
    local baseOut = build.calcsTab.mainOutput
    for _, m in ipairs(metrics) do baseVals[m] = tonumber(baseOut and baseOut[m]) or 0 end
    -- add temp item with negative ID so it doesn't collide with real items
    local item = new("Item")
    item:ParseRaw(req.item_text)
    local tempId = -(nextItemId(build))
    item.id = tempId
    build.itemsTab.items[tempId] = item
    local oldId = slot.selItemId
    slot.selItemId = tempId
    guiRecalc(build)
    local newOut = build.calcsTab.mainOutput
    local deltas = {}
    for _, m in ipairs(metrics) do
        local a, b = baseVals[m], tonumber(newOut and newOut[m]) or 0
        deltas[m] = { base = cleanNumber(a), new = cleanNumber(b), delta = cleanNumber(b - a) }
    end
    -- restore original state
    slot.selItemId = oldId
    build.itemsTab.items[tempId] = nil
    guiRecalc(build)
    return { slot = req.slot, newItemName = item.name, newItemRarity = item.rarity, deltas = deltas }
end

function handlers.add_gem(req)
    local build = getActiveBuild()
    if not build then error("no build open in the PoB GUI") end
    local sg = build.skillsTab.socketGroupList[req.group]
    if not sg then error("socket group " .. tostring(req.group) .. " not found") end
    local newGem = {
        nameSpec = req.name, level = req.level or 1, quality = req.quality or 0,
        enabled = true, enableGlobal1 = true, enableGlobal2 = true, count = 1,
    }
    table.insert(sg.gemList, newGem)
    build.skillsTab:ProcessSocketGroup(sg)
    guiRecalc(build)
    local o = build.calcsTab.mainOutput
    return {
        group = req.group, added = req.name,
        FullDPS = o and cleanNumber(o.FullDPS), CombinedDPS = o and cleanNumber(o.CombinedDPS),
        Life = o and cleanNumber(o.Life), EnergyShield = o and cleanNumber(o.EnergyShield),
    }
end

function handlers.remove_gem(req)
    local build = getActiveBuild()
    if not build then error("no build open in the PoB GUI") end
    local sg = build.skillsTab.socketGroupList[req.group]
    if not sg then error("socket group " .. tostring(req.group) .. " not found") end
    local found = false
    for i, gem in ipairs(sg.gemList or {}) do
        if gem.nameSpec == req.name then table.remove(sg.gemList, i); found = true; break end
    end
    if not found then error("gem '" .. req.name .. "' not found in group " .. tostring(req.group)) end
    build.skillsTab:ProcessSocketGroup(sg)
    guiRecalc(build)
    local o = build.calcsTab.mainOutput
    return {
        group = req.group, removed = req.name,
        FullDPS = o and cleanNumber(o.FullDPS), CombinedDPS = o and cleanNumber(o.CombinedDPS),
        Life = o and cleanNumber(o.Life), EnergyShield = o and cleanNumber(o.EnergyShield),
    }
end

function handlers.toggle_gem(req)
    local build = getActiveBuild()
    if not build then error("no build open in the PoB GUI") end
    local sg = build.skillsTab.socketGroupList[req.group]
    if not sg then error("socket group " .. tostring(req.group) .. " not found") end
    local found = false
    for _, gem in ipairs(sg.gemList or {}) do
        if gem.nameSpec == req.name then gem.enabled = req.enabled; found = true; break end
    end
    if not found then error("gem '" .. req.name .. "' not found in group " .. tostring(req.group)) end
    build.skillsTab:ProcessSocketGroup(sg)
    guiRecalc(build)
    local o = build.calcsTab.mainOutput
    return {
        group = req.group, gem = req.name, enabled = req.enabled,
        FullDPS = o and cleanNumber(o.FullDPS), CombinedDPS = o and cleanNumber(o.CombinedDPS),
        Life = o and cleanNumber(o.Life), EnergyShield = o and cleanNumber(o.EnergyShield),
    }
end

function handlers.toggle_skill_group(req)
    local build = getActiveBuild()
    if not build then error("no build open in the PoB GUI") end
    local sg = build.skillsTab.socketGroupList[req.group]
    if not sg then error("socket group " .. tostring(req.group) .. " not found") end
    sg.enabled = req.enabled
    build.skillsTab:ProcessSocketGroup(sg)
    guiRecalc(build)
    local o = build.calcsTab.mainOutput
    return {
        group = req.group, enabled = req.enabled,
        FullDPS = o and cleanNumber(o.FullDPS), CombinedDPS = o and cleanNumber(o.CombinedDPS),
        Life = o and cleanNumber(o.Life), EnergyShield = o and cleanNumber(o.EnergyShield),
    }
end

function handlers.set_main_skill(req)
    local build = getActiveBuild()
    if not build then error("no build open in the PoB GUI") end
    if not req.group then error("set_main_skill requires 'group'") end
    local total = #(build.skillsTab.socketGroupList or {})
    if req.group < 1 or req.group > total then
        error(string.format("group %d out of range (1-%d)", req.group, total))
    end
    build.mainSocketGroup = req.group
    guiRecalc(build)
    local o = build.calcsTab.mainOutput
    return {
        mainSocketGroup = req.group,
        FullDPS = o and cleanNumber(o.FullDPS), CombinedDPS = o and cleanNumber(o.CombinedDPS),
        Life = o and cleanNumber(o.Life), EnergyShield = o and cleanNumber(o.EnergyShield),
    }
end

function handlers.list_masteries(req)
    local build = getActiveBuild()
    if not build then error("no build open in the PoB GUI") end
    local allocatedOnly = req.allocatedOnly == true
    local masteries = {}
    for nodeId, node in pairs(build.spec.nodes) do
        if node.type == "Mastery" then
            if not allocatedOnly or node.alloc then
                local effects = {}
                for _, eff in ipairs(node.masteryEffects or {}) do
                    local effectId = eff.effect
                    local stats = {}
                    local effectData = build.spec.tree.masteryEffects and build.spec.tree.masteryEffects[effectId]
                    if effectData then
                        for _, s in ipairs(effectData.sd or {}) do stats[#stats+1] = s end
                    end
                    effects[#effects+1] = { id = effectId, stats = stats }
                end
                local selectedEffect = build.spec.masterySelections and build.spec.masterySelections[nodeId]
                masteries[#masteries+1] = {
                    nodeId        = nodeId,
                    name          = node.dn or node.name,
                    allocated     = node.alloc or false,
                    selectedEffect = selectedEffect,
                    effects       = effects,
                }
            end
        end
    end
    return { masteries = masteries }
end

function handlers.set_mastery(req)
    local build = getActiveBuild()
    if not build then error("no build open in the PoB GUI") end
    if not req.nodeId   then error("set_mastery requires 'nodeId'") end
    if not req.effectId then error("set_mastery requires 'effectId'") end
    local node = build.spec.nodes[req.nodeId]
    if not node then error("node not found: " .. tostring(req.nodeId)) end
    if node.type ~= "Mastery" then
        error("node " .. req.nodeId .. " is type '" .. (node.type or "?") .. "', not 'Mastery'")
    end
    local validEffect = false
    for _, eff in ipairs(node.masteryEffects or {}) do
        if eff.effect == req.effectId then validEffect = true; break end
    end
    if not validEffect then
        local valid = {}
        for _, eff in ipairs(node.masteryEffects or {}) do valid[#valid+1] = tostring(eff.effect) end
        error("effectId " .. req.effectId .. " not valid for this node. Valid ids: " .. table.concat(valid, ", "))
    end
    if not build.spec.masterySelections then build.spec.masterySelections = {} end
    build.spec.masterySelections[req.nodeId] = req.effectId
    if build.spec.tree.ProcessStats then
        build.spec.tree:ProcessStats(node)
    end
    guiRecalc(build)
    local o = build.calcsTab.mainOutput
    return {
        nodeId = req.nodeId, effectId = req.effectId,
        FullDPS = o and cleanNumber(o.FullDPS), CombinedDPS = o and cleanNumber(o.CombinedDPS),
        Life = o and cleanNumber(o.Life), EnergyShield = o and cleanNumber(o.EnergyShield),
    }
end

function handlers.get_node_info(req)
    local build = getActiveBuild()
    if not build then error("no build open in the PoB GUI") end
    build.spec:BuildAllDependsAndPaths()
    local ids = req.ids or {}
    local nodes = {}
    for _, id in ipairs(ids) do
        local node = build.spec.nodes[id]
        if not node then
            nodes[#nodes+1] = { id = id, error = "not found" }
        else
            local stats = {}
            for _, s in ipairs(node.sd or {}) do stats[#stats+1] = s end
            nodes[#nodes+1] = {
                id         = id,
                name       = node.dn or node.name,
                type       = node.type,
                allocated  = node.alloc or false,
                stats      = stats,
                ascendancy = node.ascendancyName,
                pathDist   = node.pathDist,
            }
        end
    end
    return { nodes = nodes }
end

function handlers.set_character(req)
    local build = getActiveBuild()
    if not build then error("no build open in the PoB GUI") end
    if req.level ~= nil then
        local lvl = tonumber(req.level)
        if not lvl or lvl < 1 or lvl > 100 then error("level must be 1-100") end
        build.characterLevel = lvl
    end
    if req.className ~= nil then
        local classId
        local classes = build.spec.tree.classes or {}
        for id, cls in pairs(classes) do
            if type(cls) == "table" and cls.name and cls.name:lower() == req.className:lower() then
                classId = id; break
            end
        end
        if not classId then
            local avail = {}
            for _, cls in pairs(classes) do
                if type(cls) == "table" and cls.name then avail[#avail+1] = cls.name end
            end
            table.sort(avail)
            error("class '" .. req.className .. "' not found. Available: " .. table.concat(avail, ", "))
        end
        build.spec:SelectClass(classId)
    end
    if req.ascendancy ~= nil then
        local curClass = build.spec.tree.classes[build.spec.curClassId]
        if not curClass then error("no current class; set className first") end
        local ascId
        for id, asc in pairs(curClass.ascendancies or {}) do
            if type(asc) == "table" and asc.name and asc.name:lower() == req.ascendancy:lower() then
                ascId = id; break
            end
        end
        if not ascId then
            local avail = {}
            for _, asc in pairs(curClass.ascendancies or {}) do
                if type(asc) == "table" and asc.name then avail[#avail+1] = asc.name end
            end
            table.sort(avail)
            error("ascendancy '" .. req.ascendancy .. "' not found. Available: " .. table.concat(avail, ", "))
        end
        build.spec:SelectAscendClass(ascId)
    end
    guiRecalc(build)
    local o = build.calcsTab.mainOutput
    return {
        level      = build.characterLevel,
        className  = build.spec.curClassName,
        ascendancy = build.spec.curAscendClassName,
        FullDPS = o and cleanNumber(o.FullDPS), CombinedDPS = o and cleanNumber(o.CombinedDPS),
        Life = o and cleanNumber(o.Life), EnergyShield = o and cleanNumber(o.EnergyShield),
    }
end

function handlers.set_bandit(req)
    local build = getActiveBuild()
    if not build then error("no build open in the PoB GUI") end
    if req.choice == nil then error("set_bandit requires 'choice'") end
    build.bandit = req.choice
    guiRecalc(build)
    local o = build.calcsTab.mainOutput
    return {
        bandit = build.bandit,
        FullDPS = o and cleanNumber(o.FullDPS), CombinedDPS = o and cleanNumber(o.CombinedDPS),
        Life = o and cleanNumber(o.Life), EnergyShield = o and cleanNumber(o.EnergyShield),
    }
end

function handlers.set_pantheon(req)
    local build = getActiveBuild()
    if not build then error("no build open in the PoB GUI") end
    if req.major ~= nil then build.pantheonMajorGod = req.major end
    if req.minor ~= nil then build.pantheonMinorGod = req.minor end
    guiRecalc(build)
    local o = build.calcsTab.mainOutput
    return {
        pantheonMajorGod = build.pantheonMajorGod,
        pantheonMinorGod = build.pantheonMinorGod,
        FullDPS = o and cleanNumber(o.FullDPS), CombinedDPS = o and cleanNumber(o.CombinedDPS),
        Life = o and cleanNumber(o.Life), EnergyShield = o and cleanNumber(o.EnergyShield),
    }
end

function handlers.list_flasks(req)
    local build = getActiveBuild()
    if not build then error("no build open in the PoB GUI") end
    local flasks = {}
    for slotName, slot in pairs(build.itemsTab.slots or {}) do
        if slotName:match("^Flask") then
            local entry = { slot = slotName, active = slot.active or false, empty = true }
            if slot.selItemId and slot.selItemId ~= 0 then
                local item = build.itemsTab.items[slot.selItemId]
                if item then
                    entry.empty  = false
                    entry.name   = item.name
                    entry.rarity = item.rarity
                    if item.base and item.base.flask then
                        entry.flask = {
                            subType     = item.base.subType,
                            life        = item.base.flask.life,
                            mana        = item.base.flask.mana,
                            duration    = item.base.flask.duration,
                            chargesMax  = item.base.flask.chargesMax,
                            chargesUsed = item.base.flask.chargesUsed,
                        }
                    end
                    if item.flaskData then
                        entry.flaskData = {
                            lifeTotal = cleanNumber(item.flaskData.lifeTotal),
                            manaTotal = cleanNumber(item.flaskData.manaTotal),
                            effectInc = cleanNumber(item.flaskData.effectInc),
                        }
                    end
                end
            end
            flasks[#flasks+1] = entry
        end
    end
    table.sort(flasks, function(a, b) return a.slot < b.slot end)
    return { flasks = flasks }
end

function handlers.toggle_flask(req)
    local build = getActiveBuild()
    if not build then error("no build open in the PoB GUI") end
    if not req.slot   then error("toggle_flask requires 'slot'") end
    if req.active == nil then error("toggle_flask requires 'active'") end
    if not req.slot:match("^Flask") then
        error("'" .. req.slot .. "' is not a flask slot (expected 'Flask 1' or 'Flask 2')")
    end
    local slot = build.itemsTab.slots[req.slot]
    if not slot then error("slot '" .. req.slot .. "' not found") end
    slot.active = req.active
    if build.itemsTab.activeItemSet and build.itemsTab.activeItemSet[req.slot] then
        build.itemsTab.activeItemSet[req.slot].active = req.active
    end
    guiRecalc(build)
    local o = build.calcsTab.mainOutput
    return {
        slot = req.slot, active = req.active,
        FullDPS = o and cleanNumber(o.FullDPS), CombinedDPS = o and cleanNumber(o.CombinedDPS),
        Life = o and cleanNumber(o.Life), EnergyShield = o and cleanNumber(o.EnergyShield),
    }
end

function handlers.list_keystones(req)
    local build = getActiveBuild()
    if not build then error("no build open in the PoB GUI") end
    build.spec:BuildAllDependsAndPaths()
    local maxDepth = req.maxDepth  -- nil = no limit
    local keystones = {}
    for nodeId, node in pairs(build.spec.nodes) do
        if node.type == "Keystone" then
            local dist = node.pathDist or (node.alloc and 0) or 999
            if not maxDepth or node.alloc or dist <= maxDepth then
                local stats = {}
                for _, s in ipairs(node.sd or {}) do stats[#stats+1] = s end
                keystones[#keystones+1] = {
                    id        = nodeId,
                    name      = node.dn or node.name,
                    allocated = node.alloc or false,
                    pathDist  = node.alloc and 0 or dist,
                    stats     = stats,
                }
            end
        end
    end
    -- Allocated first, then by distance
    table.sort(keystones, function(a, b)
        if a.allocated ~= b.allocated then return a.allocated end
        return (a.pathDist or 999) < (b.pathDist or 999)
    end)
    return { keystones = keystones, count = #keystones }
end

function handlers.set_node_stat(req)
    local build = getActiveBuild()
    if not build then error("no build open in the PoB GUI") end
    if not req.nodeId   then error("set_node_stat requires 'nodeId'") end
    if req.index == nil then error("set_node_stat requires 'index'")  end
    if req.stat  == nil then error("set_node_stat requires 'stat'")   end
    local node = build.spec.nodes[req.nodeId]
    if not node then error("node not found: " .. tostring(req.nodeId)) end
    if node.type == "ClassStart" or node.type == "AscendClassStart" then
        error("cannot modify the start node (type: " .. node.type .. ")")
    end
    local sd  = node.sd or {}
    local idx = req.index
    if idx < 1 or idx > #sd then
        error("stat index " .. idx .. " out of range (node has " .. #sd .. " stats)")
    end
    local oldStat = sd[idx]
    sd[idx]  = req.stat
    node.sd  = sd
    build.spec.tree:ProcessStats(node)
    guiRecalc(build)
    local o = build.calcsTab.mainOutput
    return {
        nodeId  = req.nodeId,
        name    = node.dn or node.name,
        index   = idx,
        oldStat = oldStat,
        newStat = req.stat,
        stats   = {
            FullDPS      = o and cleanNumber(o.FullDPS),
            CombinedDPS  = o and cleanNumber(o.CombinedDPS),
            Life         = o and cleanNumber(o.Life),
            EnergyShield = o and cleanNumber(o.EnergyShield),
            Armour       = o and cleanNumber(o.Armour),
            Evasion      = o and cleanNumber(o.Evasion),
        },
    }
end

function handlers.evaluate_node_stat(req)
    local build = getActiveBuild()
    if not build then error("no build open in the PoB GUI") end
    if not req.nodeId    then error("evaluate_node_stat requires 'nodeId'")    end
    if not req.overrides then error("evaluate_node_stat requires 'overrides'") end
    local node = build.spec.nodes[req.nodeId]
    if not node then error("node not found: " .. tostring(req.nodeId)) end

    -- Capture baseline
    guiRecalc(build)
    local o0   = build.calcsTab.mainOutput
    local keys = {
        "FullDPS","CombinedDPS","Life","EnergyShield","Armour","Evasion",
        "PhysicalDmgReductionPercent","SpellBlockChance","AttackBlockChance",
        "MeleeEvadeChance","Mana","MaxManaReserved",
    }
    local before = {}
    for _, k in ipairs(keys) do before[k] = o0 and cleanNumber(o0[k]) end

    -- Save original sd lines
    local origSd = {}
    for i, s in ipairs(node.sd or {}) do origSd[i] = s end

    -- Apply overrides: {index(string or number) -> newStatText}
    for rawIdx, newStat in pairs(req.overrides) do
        local i = tonumber(rawIdx)
        if i and i >= 1 and i <= #origSd then
            node.sd[i] = newStat
        end
    end

    -- Rebuild modList then recalc
    build.spec.tree:ProcessStats(node)
    guiRecalc(build)
    local o1  = build.calcsTab.mainOutput
    local after = {}
    for _, k in ipairs(keys) do after[k] = o1 and cleanNumber(o1[k]) end

    -- Restore original sd and modList
    for i, s in ipairs(origSd) do node.sd[i] = s end
    build.spec.tree:ProcessStats(node)
    guiRecalc(build)

    -- Compute delta for changed stats only
    local delta = {}
    for _, k in ipairs(keys) do
        local b, a = before[k], after[k]
        if type(b) == "number" and type(a) == "number" and a ~= b then
            delta[k] = { before = b, after = a, diff = a - b }
        end
    end

    return {
        nodeId     = req.nodeId,
        name       = node.dn or node.name,
        nodeType   = node.type,
        sdOriginal = origSd,
        before     = before,
        after      = after,
        delta      = delta,
    }
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
local function logDebug(msg)
    local f = io.open("c:/Users/imfal/Documents/GitHub/PathOfBuilding-PoE2/pob-mcp-tick-debug.txt", "a")
    if f then
        f:write(string.format("[%s] %s\n", os.date("%Y-%m-%d %H:%M:%S"), msg))
        f:close()
    end
end

logDebug("GUI bridge loaded successfully! Listening on port " .. PORT)

function _G.pobMcpTick()
    if not _G.pobMcpTickCount then
        _G.pobMcpTickCount = 0
        logDebug("First pobMcpTick called!")
    end
    _G.pobMcpTickCount = _G.pobMcpTickCount + 1

    -- Accept new connections (non-blocking)
    local client = srv:accept()
    if client then
        logDebug("Accepted client connection!")
        -- Send handshake with a safe short timeout to guarantee immediate delivery on Windows
        client:settimeout(0.5)
        local h_ok, h_err = pcall(function() client:send(dkjson.encode({ event = "ready", gui = true }) .. "\n") end)
        logDebug("Handshake sent: ok=" .. tostring(h_ok) .. ", err=" .. tostring(h_err))
        client:settimeout(0) -- Set to non-blocking for all subsequent frame ticks
        clients[#clients + 1] = client
    end

    -- Serve existing clients
    local i = 1
    while i <= #clients do
        local ok, err = pcall(processClient, clients[i])
        if not ok or (err and err ~= "timeout") then
            logDebug("Disconnected client: ok=" .. tostring(ok) .. ", err=" .. tostring(err))
            buffers[clients[i]] = nil
            pcall(function() clients[i]:close() end) -- Safely close the client socket to prevent CLOSE_WAIT leaks!
            table.remove(clients, i)
        else
            i = i + 1
        end
    end
end

ConPrintf("pob-mcp: GUI bridge listening on 127.0.0.1:%d", PORT)
