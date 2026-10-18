-- stats.*: calculated output, sidebar stats and what-if comparisons.
local util = require("pobapi.util")
local session = require("pobapi.session")

local M = { }

local function statValue(statData, output)
	local v = output[statData.stat]
	if v ~= nil and statData.childStat then
		v = type(v) == "table" and v[statData.childStat] or nil
	end
	return v
end

local function scaled(statData, v)
	return v * ((statData.pc or statData.mod) and 100 or 1) - (statData.mod and 100 or 0)
end

-- Replicates the sidebar filtering in buildMode:AddDisplayStatList.
local function isShown(statData, actor, output, v)
	if not statData.stat or statData.hideStat or statData.stat == "SkillDPS" then
		return false
	end
	if statData.flag then
		local flags = actor.mainSkill and actor.mainSkill.activeEffect.statSet.skillFlags or { }
		if not flags[statData.flag] then
			return false
		end
	end
	if type(v) ~= "number" then
		return false
	end
	if statData.condFunc then
		local ok, res = pcall(statData.condFunc, v, output)
		return ok and res and true or false
	end
	return v ~= 0
end

local function displayList(statList, actor, output)
	local rows = util.array()
	local seen = { }
	for _, statData in ipairs(statList) do
		local v = statValue(statData, output)
		local key = statData.stat and statData.label and (statData.stat .. "|" .. statData.label)
		if key and not seen[key] and isShown(statData, actor, output, v) then
			seen[key] = true
			local warn
			if statData.warnFunc then
				local ok, w = pcall(statData.warnFunc, v, output)
				warn = ok and type(w) == "string" and w or nil
			end
			rows[#rows + 1] = {
				stat = statData.stat,
				childStat = statData.childStat,
				label = statData.label,
				value = scaled(statData, v),
				formatted = util.strip(string.format("%" .. statData.fmt, scaled(statData, v))),
				overCap = statData.overCapStat and output[statData.overCapStat] or nil,
				lowerIsBetter = statData.lowerIsBetter or nil,
				warning = warn,
			}
		end
	end
	return rows
end

function M.summary()
	local b = session.build()
	local player = session.player()
	local res = { player = displayList(b.displayStats, player, player.output) }
	local minion = player.mainSkill and player.mainSkill.minion
	if minion and minion.output then
		res.minion = displayList(b.minionDisplayStats, minion, minion.output)
	end
	res.skillDPS = util.array()
	for _, s in ipairs(player.output.SkillDPS or { }) do
		res.skillDPS[#res.skillDPS + 1] = { name = s.name, dps = s.dps, count = s.count or 1, source = s.source, trigger = s.trigger }
	end
	return res
end

-- Raw calculated output. Without keys only scalar values are returned.
function M.get(params)
	local output = session.output()
	local res = { }
	if type(params.keys) == "table" and #params.keys > 0 then
		for _, key in ipairs(params.keys) do
			res[key] = output[key]
		end
		return res
	end
	for k, v in pairs(output) do
		local t = type(v)
		if t == "number" or t == "boolean" or t == "string" then
			res[k] = v
		end
	end
	return res
end

-- Build a before/after comparison over the sidebar stats.
local function diff(base, new)
	local b = session.build()
	local player = session.player()
	local rows = util.array()
	local seen = { }
	for _, statData in ipairs(b.displayStats) do
		if statData.stat and statData.label and not statData.hideStat and statData.stat ~= "SkillDPS" then
			local key = statData.stat .. "|" .. (statData.childStat or "")
			local before, after = statValue(statData, base), statValue(statData, new)
			if not seen[key] and type(before) == "number" and type(after) == "number" and before ~= after
				and (isShown(statData, player, base, before) or isShown(statData, player, new, after)) then
				seen[key] = true
				local bv, av = scaled(statData, before), scaled(statData, after)
				local better = (av > bv) ~= (statData.lowerIsBetter or false)
				rows[#rows + 1] = {
					stat = statData.stat,
					label = statData.label,
					before = bv,
					after = av,
					delta = av - bv,
					percent = bv ~= 0 and (av - bv) / math.abs(bv) * 100 or nil,
					better = better,
				}
			end
		end
	end
	return rows
end
M.diff = diff

local function nodesFromIds(ids)
	local spec = session.build().spec
	local set = { }
	for _, id in ipairs(ids or { }) do
		local node = spec.nodes[tonumber(id)]
		if not node then
			util.fail("Unknown passive node id: " .. tostring(id))
		end
		set[node] = true
	end
	return set
end

-- What-if for passive nodes. `add` includes the path needed to reach each node.
function M.compare_nodes(params)
	local b = session.build()
	local calcFunc, baseOutput = b.calcsTab:GetMiscCalculator()
	local override = { }
	if params.add and #params.add > 0 then
		override.addNodes = { }
		for node in pairs(nodesFromIds(params.add)) do
			if not node.alloc then
				for _, pathNode in ipairs(node.path or { node }) do
					override.addNodes[pathNode] = true
				end
			end
		end
	end
	if params.remove and #params.remove > 0 then
		override.removeNodes = { }
		for node in pairs(nodesFromIds(params.remove)) do
			for _, dep in ipairs(node.depends or { node }) do
				override.removeNodes[dep] = true
			end
		end
	end
	local pointDelta = 0
	for _ in pairs(override.addNodes or { }) do pointDelta = pointDelta + 1 end
	for _ in pairs(override.removeNodes or { }) do pointDelta = pointDelta - 1 end
	local newOutput = calcFunc(override)
	return { pointDelta = pointDelta, changes = diff(baseOutput, newOutput), budget = require("pobapi.api.budget")._compare(baseOutput, newOutput) }
end

-- What-if for an item. Slot defaults to the item's primary slot.
function M.compare_item(params)
	local text = util.require(params, "text", "string")
	local b = session.build()
	local item = new("Item"):Item(text)
	if not item.base then
		util.fail("Could not parse item (unknown base type)")
	end
	item:NormaliseQuality()
	item:BuildModList()
	local slot = params.slot or item:GetPrimarySlot()
	if not b.itemsTab.slots[slot] then
		util.fail("Unknown slot: " .. tostring(slot))
	end
	local calcFunc, baseOutput = require("pobapi.api.budget")._calculator(b)
	local newOutput = calcFunc({ repSlotName = slot, repItem = item })
	return {
		slot = slot,
		item = item.name,
		changes = diff(baseOutput, newOutput),
		-- Spirit/totems/requirements and main-skill DPS across all totems (the sidebar rows don't show these).
		budget = require("pobapi.api.budget")._compare(baseOutput, newOutput),
	}
end

return M
