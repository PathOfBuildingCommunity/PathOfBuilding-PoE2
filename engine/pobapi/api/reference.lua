-- reference.*: compare the live build with a PoE2 BuildPlanner (.build) guide and rank steps toward it.
-- The .build JSON (GGG's in-game planner format, also written by PoB's BuildExportPoE2) is passed in as
-- params.reference on every call; the Python service keeps it between calls.
local util = require("pobapi.util")
local session = require("pobapi.session")
local stats = require("pobapi.api.stats")
local budget = require("pobapi.api.budget")

local M = { }

-- Entries apply to a character level range; with no level given every entry applies.
local function inStage(entry, level)
	local interval = type(entry) == "table" and entry.level_interval
	if not level or type(interval) ~= "table" then
		return true
	end
	return (tonumber(interval[1]) or 1) <= level and level <= (tonumber(interval[2]) or 100)
end

-- Strip PoE2 custom text markup (<b>{...}, <rgb(r,g,b)>{...}) down to plain text.
local function plainText(text)
	if type(text) ~= "string" or text == "" then
		return nil
	end
	text = text:gsub("\r\n", "\n"):gsub("<[^<>]*>", ""):gsub("[{}]", "")
	text = text:gsub("[ \t]+\n", "\n"):gsub("\n\n\n+", "\n\n"):gsub("^%s+", ""):gsub("%s+$", "")
	return text ~= "" and text or nil
end

local function stageList(ref)
	local seen, list = { }, util.array()
	for _, key in ipairs({ "passives", "skills", "inventory_slots" }) do
		for _, entry in ipairs(type(ref[key]) == "table" and ref[key] or { }) do
			local interval = entry.level_interval
			if type(interval) == "table" and interval[1] then
				local id = interval[1] .. "-" .. (interval[2] or 100)
				if not seen[id] then
					seen[id] = true
					list[#list + 1] = { from = tonumber(interval[1]), to = tonumber(interval[2]) or 100 }
				end
			end
		end
	end
	table.sort(list, function(a, b) return a.from < b.from or (a.from == b.from and a.to < b.to) end)
	return list
end

local function getReference(params)
	local ref = util.require(params, "reference", "table")
	if type(ref.passives) ~= "table" and type(ref.skills) ~= "table" and type(ref.inventory_slots) ~= "table" then
		util.fail("Not a PoE2 BuildPlanner file (no passives, skills or inventory_slots)")
	end
	return ref, tonumber(params.level)
end

local function nodeInfo(node)
	return { id = node.id, name = node.dn, type = node.type, ascendancy = node.ascendancyName }
end

local function isStart(node)
	return node.type == "ClassStart" or node.type == "AscendClassStart"
end

-- Resolve the reference passives against the live tree.
local function resolvePassives(spec, ref, level)
	local byString = { }
	for _, node in pairs(spec.nodes) do
		if node.stringId then
			byString[node.stringId] = node
		end
	end
	local wanted, weaponSets, unknown = { }, { }, util.array()
	for _, entry in ipairs(type(ref.passives) == "table" and ref.passives or { }) do
		if inStage(entry, level) then
			local id = type(entry) == "string" and entry or entry.id
			local node = id and byString[id]
			if node and not isStart(node) then
				wanted[node] = true
				weaponSets[node] = tonumber(type(entry) == "table" and entry.weapon_set) or 0
			elseif id and not node then
				unknown[#unknown + 1] = id
			end
		end
	end
	return wanted, weaponSets, unknown
end

local function resolveAscendancy(spec, ref)
	local internal = ref.ascendancy
	local entry = internal and spec.tree.internalAscendNameMap and spec.tree.internalAscendNameMap[internal]
	if not entry then
		return nil
	end
	return {
		internalId = internal,
		className = entry.class.name,
		classId = entry.classId,
		name = entry.ascendClass.id or entry.ascendClass.name,
		ascendClassId = entry.ascendClassId,
	}
end

local gemByTail
local function gemFor(gameId)
	if type(gameId) ~= "string" then
		return nil
	end
	local variants = data.gemsByGameId[gameId]
	if not variants then
		-- Tolerate path variations (e.g. "Metadata/Items/Gem/..." vs "Metadata/Items/Gems/...").
		if not gemByTail then
			gemByTail = { }
			for id, v in pairs(data.gemsByGameId) do
				gemByTail[id:match("([^/]+)$")] = v
			end
		end
		variants = gemByTail[gameId:match("([^/]+)$")]
	end
	local best
	for variantId, gem in pairs(variants or { }) do
		if not best or variantId < best.variantId then
			best = gem
		end
	end
	return best
end

local function supportFamily(name)
	return (name:gsub("%s+[IVX]+$", ""))
end

local function compareSkills(b, ref, level)
	local groups = { }
	for index, group in ipairs(b.skillsTab.socketGroupList) do
		local names, supports = { }, { }
		for _, gem in ipairs(group.gemList or { }) do
			local gemData = gem.gemData
			if gemData then
				names[gemData.name] = true
				if gemData.grantedEffect and gemData.grantedEffect.support then
					supports[gemData.name] = true
				end
			end
		end
		groups[#groups + 1] = { index = index, group = group, names = names, supports = supports }
	end
	local res, unknown = util.array(), util.array()
	for _, entry in ipairs(type(ref.skills) == "table" and ref.skills or { }) do
		if inStage(entry, level) then
			local gem = gemFor(entry.id)
			if not gem then
				unknown[#unknown + 1] = tostring(entry.id)
			else
				local refSupports = util.array()
				for _, sup in ipairs(type(entry.support_skills) == "table" and entry.support_skills or { }) do
					local supId = type(sup) == "string" and sup or (type(sup) == "table" and sup.id)
					if inStage(sup, level) then
						local supGem = gemFor(supId)
						if supGem then
							refSupports[#refSupports + 1] = supGem.name
						else
							unknown[#unknown + 1] = tostring(supId)
						end
					end
				end
				local match
				for _, g in ipairs(groups) do
					if g.names[gem.name] and not g.supports[gem.name] then
						match = g
						break
					end
				end
				local row = {
					name = gem.name,
					note = plainText(entry.additional_text),
					found = match ~= nil,
					supports = refSupports,
					missingSupports = util.array(),
					extraSupports = util.array(),
					tierDifferences = util.array(),
				}
				if match then
					row.group = match.index
					row.enabled = match.group.enabled ~= false
					-- Supports come in tiers ("Biting Frost I/II"); a different tier of the same support is a match.
					local haveByFamily, used = { }, { }
					for name in pairs(match.supports) do
						haveByFamily[supportFamily(name)] = name
					end
					for _, name in ipairs(refSupports) do
						local have = match.supports[name] and name or haveByFamily[supportFamily(name)]
						if not have then
							row.missingSupports[#row.missingSupports + 1] = name
						else
							used[have] = true
							if have ~= name then
								row.tierDifferences[#row.tierDifferences + 1] = { reference = name, current = have }
							end
						end
					end
					for name in pairs(match.supports) do
						if not used[name] then
							row.extraSupports[#row.extraSupports + 1] = name
						end
					end
					table.sort(row.extraSupports)
				end
				res[#res + 1] = row
			end
		end
	end
	return res, unknown
end

-- .build inventory ids -> PoB slot names (inverse of Data/InventorySlots, plus charms stored as Trinket1 x2-4).
local function slotFor(inventoryId, x)
	x = tonumber(x) or 0
	for slotName, mapping in pairs(data.buildFileInventorySlotMap) do
		if mapping.id == inventoryId and (mapping.slot_x or 0) == x then
			return slotName
		end
	end
	if inventoryId == "Trinket1" and x >= 2 and x <= 4 then
		return "Charm " .. (x - 1)
	end
	if inventoryId == "Flask1" and x <= 1 then
		return "Flask " .. (x + 1)
	end
end

local function compareItems(b, ref, level)
	local res = util.array()
	for _, entry in ipairs(type(ref.inventory_slots) == "table" and ref.inventory_slots or { }) do
		if inStage(entry, level) then
			local slot = slotFor(entry.inventory_id, entry.slot_x)
			local slotData = slot and b.itemsTab.slots[slot]
			local item = slotData and b.itemsTab.items[slotData.selItemId]
			local row = {
				slot = slot or tostring(entry.inventory_id) .. " " .. tostring(entry.slot_x or 0),
				uniqueName = entry.unique_name,
				note = plainText(entry.additional_text),
			}
			if item then
				row.equipped = { name = item.name, title = item.title, baseName = item.baseName, rarity = item.rarity }
				if entry.unique_name then
					row.match = item.title == entry.unique_name
				end
			end
			res[#res + 1] = row
		end
	end
	table.sort(res, function(a, c) return a.slot < c.slot end)
	return res
end

function M.compare(params)
	local ref, level = getReference(params)
	local b = session.build()
	local spec = b.spec
	level = level or b.characterLevel
	local wanted, weaponSets, unknownPassives = resolvePassives(spec, ref, level)
	local missing, extra, matched = util.array(), util.array(), 0
	local weaponSetMismatch = 0
	local refPoints, refAscPoints = 0, 0
	for node in pairs(wanted) do
		if node.ascendancyName then refAscPoints = refAscPoints + 1 else refPoints = refPoints + 1 end
		if node.alloc then
			matched = matched + 1
			if (node.allocMode or 0) ~= weaponSets[node] then
				weaponSetMismatch = weaponSetMismatch + 1
			end
		else
			missing[#missing + 1] = nodeInfo(node)
		end
	end
	for _, node in pairs(spec.allocNodes) do
		if not wanted[node] and not isStart(node) and node.id < 65536 then
			extra[#extra + 1] = nodeInfo(node)
		end
	end
	local byName = function(a, c) return (a.name or "") < (c.name or "") end
	table.sort(missing, byName)
	table.sort(extra, byName)
	local skillRows, unknownGems = compareSkills(b, ref, level)
	local used, ascUsed = spec:CountAllocNodes()
	return {
		name = ref.name,
		author = ref.author,
		link = ref.link,
		description = plainText(ref.description),
		level = level,
		stages = stageList(ref),
		ascendancy = resolveAscendancy(spec, ref),
		current = { className = spec.curClassName, ascendClassName = spec.curAscendClassName, points = used, ascendancyPoints = ascUsed },
		passives = {
			referencePoints = refPoints,
			referenceAscendancyPoints = refAscPoints,
			matched = matched,
			missing = missing,
			extra = extra,
			weaponSetMismatch = weaponSetMismatch,
			unknown = unknownPassives,
		},
		skills = skillRows,
		items = compareItems(b, ref, level),
		unknownGems = unknownGems,
	}
end

-- Headline numbers from a calc output, for ranking.
-- Headline numbers. DPS is the main skill across every totem the Spirit budget can keep up (see budget.lua):
-- PoB reports totem DPS per totem, so a change that costs totems must show up as lost damage.
local function headline(output, ctx, group)
	local summary = budget._summarize(output, ctx or budget._context(), group)
	return {
		dps = budget._effectiveDps(output, summary),
		ehp = output.TotalEHP or 0,
		life = output.Life or 0,
		es = output.EnergyShield or 0,
		totems = summary.totems,
		spirit = summary.spirit,
	}
end

-- Totem/Spirit side effects of a change, added to a gain row only when something moved.
local function budgetDeltas(r, base, h)
	if h.totems and base.totems and h.totems ~= base.totems then
		r.totemsDelta = h.totems - base.totems
	end
	if (h.spirit or 0) ~= (base.spirit or 0) then
		r.spiritDelta = (h.spirit or 0) - (base.spirit or 0)
	end
	return r
end

local function pct(before, after)
	if before == 0 then
		return after ~= 0 and 100 or 0
	end
	return (after - before) / math.abs(before) * 100
end

-- Shortest route from the current allocation to `target` that only uses reference nodes.
local function routeTo(target, missingSet)
	local prev, queue, head = { [target] = false }, { target }, 1
	while head <= #queue do
		local node = queue[head]
		head = head + 1
		for _, other in ipairs(node.linked or { }) do
			if other.alloc and (not other.ascendancyName or other.ascendancyName == node.ascendancyName) then
				local path, cur = { }, node
				while cur do
					path[#path + 1] = cur
					cur = prev[cur]
				end
				return path
			end
			if prev[other] == nil and missingSet[other] then
				prev[other] = node
				queue[#queue + 1] = other
			end
		end
	end
end

-- Stat impact: the whole reference tree, plus ranked next steps and what each extra node is worth.
function M.impact(params)
	local ref, level = getReference(params)
	local b = session.build()
	local spec = b.spec
	level = level or b.characterLevel
	local limit = tonumber(params.limit) or 40
	local wanted = resolvePassives(spec, ref, level)
	local calcFunc, baseOutput = b.calcsTab:GetMiscCalculator()
	local base = headline(baseOutput)

	local missingSet, extraSet = { }, { }
	for node in pairs(wanted) do
		if not node.alloc then
			missingSet[node] = true
		end
	end
	for _, node in pairs(spec.allocNodes) do
		if not wanted[node] and not isStart(node) and node.id < 65536 then
			extraSet[node] = true
		end
	end
	local function count(set)
		local n = 0
		for _ in pairs(set) do n = n + 1 end
		return n
	end
	local function summarise(output, points)
		local h = headline(output)
		return budgetDeltas({
			points = points,
			dpsPercent = pct(base.dps, h.dps),
			ehpPercent = pct(base.ehp, h.ehp),
			lifeDelta = h.life - base.life,
			esDelta = h.es - base.es,
		}, base, h)
	end

	local fullOutput = calcFunc({ addNodes = missingSet, removeNodes = extraSet })
	local full = summarise(fullOutput, count(missingSet) - count(extraSet))
	full.added = count(missingSet)
	full.removed = count(extraSet)
	full.changes = stats.diff(baseOutput, fullOutput)

	-- Next steps: each notable/keystone/socket the guide takes, via its route through other guide nodes.
	local steps = util.array()
	for node in pairs(missingSet) do
		if node.type == "Notable" or node.type == "Keystone" or node.type == "Socket" then
			local path = routeTo(node, missingSet)
			if path then
				-- path[1] touches the current tree; path[#path] is the target.
				local set, ids = { }, util.array()
				for i = 1, #path do
					set[path[i]] = true
					ids[#ids + 1] = path[i].id
				end
				local row = summarise(calcFunc({ addNodes = set }), #path)
				row.id, row.name, row.type, row.ascendancy, row.path = node.id, node.dn, node.type, node.ascendancyName, ids
				row.score = (row.dpsPercent + row.ehpPercent) / #path
				steps[#steps + 1] = row
			end
		end
	end
	table.sort(steps, function(a, c) return a.score > c.score end)
	while #steps > limit do
		table.remove(steps)
	end

	-- Extra notables/keystones: what removing each one alone would cost.
	local extras = util.array()
	for node in pairs(extraSet) do
		if node.type == "Notable" or node.type == "Keystone" then
			local row = summarise(calcFunc({ removeNodes = { [node] = true } }), -1)
			row.id, row.name, row.type, row.ascendancy = node.id, node.dn, node.type, node.ascendancyName
			extras[#extras + 1] = row
		end
	end
	table.sort(extras, function(a, c) return a.dpsPercent + a.ehpPercent > c.dpsPercent + c.ehpPercent end)

	return { level = level, base = base, fullTree = full, steps = steps, extras = extras }
end

-- Replace the passive tree with the reference tree (and its ascendancy when it belongs to the current class).
-- Attribute choices on nodes kept are preserved; new attribute nodes take the most common existing choice.
function M.apply_tree(params)
	local ref, level = getReference(params)
	local b = session.build()
	local spec = b.spec
	level = level or b.characterLevel
	local wanted, weaponSets = resolvePassives(spec, ref, level)
	local asc = resolveAscendancy(spec, ref)
	local ascendClassId = spec.curAscendClassId
	if asc and asc.classId == spec.curClassId then
		ascendClassId = asc.ascendClassId
	end
	local choices, tally = { }, { }
	for id, node in pairs(spec.hashOverrides or { }) do
		if node.dn then
			choices[id] = node.dn
			tally[node.dn] = (tally[node.dn] or 0) + 1
		end
	end
	local favourite
	for name, n in pairs(tally) do
		if not favourite or n > tally[favourite] then
			favourite = name
		end
	end
	local hashes, sets = { }, { }
	for node in pairs(wanted) do
		hashes[#hashes + 1] = node.id
		if weaponSets[node] > 0 then
			sets[node.id] = weaponSets[node]
		end
	end
	spec:ImportFromNodeList(nil, spec.curClassId, ascendClassId, 0, hashes, sets, { }, { })
	for _, id in ipairs(hashes) do
		local treeNode = spec.tree.nodes[id]
		local choice = choices[id] or favourite
		if treeNode and treeNode.isAttribute and choice then
			for index, option in ipairs(treeNode.options or { }) do
				if (option.dn or option.name) == choice then
					spec:SwitchAttributeNode(id, index)
					spec:ReplaceNode(spec.nodes[id], spec.hashOverrides[id])
					break
				end
			end
		end
	end
	spec:BuildAllDependsAndPaths()
	session.recalc()
	return require("pobapi.api.tree").get()
end

-- Shared with advisor.* (leading underscore keeps them off the RPC registry).
M._getReference = getReference
M._resolvePassives = resolvePassives
M._headline = headline
M._budgetDeltas = budgetDeltas
M._pct = pct
M._routeTo = routeTo
M._isStart = isStart

return M
