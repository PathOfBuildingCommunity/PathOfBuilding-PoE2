-- sockets.*: rune, soul core and idol advice. What each socketed augment is worth, the best legal replacements per
-- socket, and a combined plan of swaps (greedy, re-measured after each accepted swap so caps and limits interact).
--
-- Legality: PoB's own ItemsTab:GetValidRunesForItem (slot type, uniques, jewellery, soul-core/rune-only items), plus
-- what it leaves out: corrupted items, the character level requirement, per-item limits and character-wide limits
-- that share a limitId (e.g. "AncientAugment": Amanamu's Gaze and Emergent Possibility exclude each other).
local util = require("pobapi.util")
local session = require("pobapi.session")
local gear = require("pobapi.api.gear")

local M = { }

local DEAD = 0.05 -- percent of the metric

-- Equipped items with augment sockets (weapon swap excluded).
local function socketedItems(b, only)
	local res = { }
	for _, slot in ipairs(b.itemsTab.orderedSlots) do
		local name = slot.slotName
		local item = b.itemsTab.items[slot.selItemId]
		if item and (item.itemSocketCount or 0) > 0 and not name:match("Swap") and (not only or only == name) then
			res[#res + 1] = { slot = name, item = item }
		end
	end
	if only and #res == 0 then
		util.fail("No socketed item in slot: " .. tostring(only))
	end
	return res
end

-- Data entries of a rune that apply to this item (same choice as Item:UpdateRunes).
local function applicableMods(item, name)
	local rune = data.itemMods.Runes[name]
	local res = { }
	if not rune then
		return res
	end
	local baseType, specificType = item:GetSocketedAugmentTypes()
	if rune[baseType] then res[#res + 1] = rune[baseType] end
	if specificType ~= baseType and rune[specificType] then res[#res + 1] = rune[specificType] end
	for soulCoreType in pairs(item.socketedSoulCoreTypes or { }) do
		local mod = rune[soulCoreType]
		if mod and mod.type == "SoulCore" then res[#res + 1] = mod end
	end
	return res
end

-- limit, limitId, level requirement and corruption rule of a rune on this item.
local function runeRules(item, name)
	local rules = { limit = nil, limitId = nil, levelReq = 0, corruptOk = false, socketBound = false, lines = { }, bonded = { }, type = nil }
	for _, mod in ipairs(applicableMods(item, name)) do
		rules.type = rules.type or mod.type
		rules.limit = mod.limit or rules.limit
		rules.limitId = mod.limitId or rules.limitId
		rules.levelReq = math.max(rules.levelReq, mod.levelReq or 0)
		rules.corruptOk = rules.corruptOk or mod.canSocketInCorruptedSanctified or false
		rules.socketBound = rules.socketBound or mod.isSocketBound or false
		for _, line in ipairs(mod) do
			rules.lines[#rules.lines + 1] = line
		end
		for _, line in ipairs(mod.bonded or { }) do
			rules.bonded[#rules.bonded + 1] = line
		end
	end
	return rules
end

-- Lines PoB does not model: their effect is invisible to every number here.
local function unmodelled(lines)
	local res = util.array()
	for _, line in ipairs(lines) do
		local list, extra = modLib.parseMod(line)
		if not list or extra then
			res[#res + 1] = line
		end
	end
	return res
end

-- Rune names in every equipped socket, for the character-wide limit check: { [item] = { [i] = name } }.
local function equippedRunes(entries)
	local res = { }
	for _, e in ipairs(entries) do
		local list, ids = { }, { }
		for i = 1, e.item.itemSocketCount do
			list[i] = e.item.runes[i] or "None"
			ids[i] = list[i] ~= "None" and runeRules(e.item, list[i]).limitId or nil
		end
		res[#res + 1] = { item = e.item, slot = e.slot, runes = list, limitIds = ids }
	end
	return res
end

-- Can `name` go in socket `i` of `item`, given what is socketed everywhere else? When the only obstacle is a
-- character-wide limit held by other sockets, also returns those sockets (a swap there would free it).
local function legal(b, item, i, name, everywhere)
	local rules = runeRules(item, name)
	if rules.socketBound then
		return false
	end
	if item.corrupted and not rules.corruptOk then
		return false
	end
	if rules.levelReq > (b.characterLevel or 100) then
		return false
	end
	if rules.limit or rules.limitId then
		local sameItem, holders = 0, { }
		for _, other in ipairs(everywhere) do
			for j, otherName in ipairs(other.runes) do
				if not (other.item == item and j == i) and otherName ~= "None" then
					if other.item == item and otherName == name then
						sameItem = sameItem + 1
					end
					if rules.limitId and other.limitIds[j] == rules.limitId then
						holders[#holders + 1] = { slot = other.slot, socket = j, name = otherName }
					end
				end
			end
		end
		local limit = rules.limit or 1
		if not rules.limitId and sameItem >= limit then
			return false
		end
		if rules.limitId and #holders >= limit then
			return false, holders
		end
	end
	return true
end

-- A copy of `item` with socket `i` holding `name` ("None" empties it).
local function variant(item, i, name)
	local copy = new("Item"):Item(item:BuildRaw())
	copy.runes[i] = name
	copy:UpdateRunes()
	copy:BuildAndParseRaw()
	copy:NormaliseQuality()
	copy:BuildModList()
	return copy
end

local function candidates(b, item)
	local names = { }
	for _, rune in ipairs(b.itemsTab:GetValidRunesForItem(item)) do
		if rune.name ~= "None" then
			names[#names + 1] = rune.name
		end
	end
	return names
end

local function row(name, item, r)
	local rules = runeRules(item, name)
	return {
		name = name,
		type = rules.type,
		limitId = rules.limitId,
		lines = rules.lines,
		bonded = #rules.bonded > 0 and rules.bonded or nil,
		unmodelled = (function() local u = unmodelled(rules.lines) return #u > 0 and u or nil end)(),
		score = r.score,
		dpsPercent = r.dpsPercent,
		ehpPercent = r.ehpPercent,
		totemsDelta = r.totemsDelta,
		spiritDelta = r.spiritDelta,
	}
end

-- Every legal option for one socket, measured against the item as it is now (best first). Options blocked only by
-- a character-wide limit held elsewhere are measured too and carry `blockedBy`. `withEmpty` adds "None".
local function rankSocket(b, entry, i, everywhere, calcFunc, measure, names, withEmpty)
	local item, cur = entry.item, entry.item.runes[i] or "None"
	local options = { }
	local list = names or candidates(b, item)
	if withEmpty and cur ~= "None" then
		list = { "None", unpack(list) }
	end
	for _, name in ipairs(list) do
		local isLegal, blockedBy = true, nil
		if name ~= "None" then
			isLegal, blockedBy = legal(b, item, i, name, everywhere)
		end
		if name ~= cur and (isLegal or blockedBy) then
			local ok, r = pcall(function()
				return measure(calcFunc({ repSlotName = entry.slot, repItem = variant(item, i, name) }))
			end)
			if ok then
				local opt
				if name == "None" then
					opt = { name = "None", lines = { }, score = r.score, dpsPercent = r.dpsPercent, ehpPercent = r.ehpPercent,
						totemsDelta = r.totemsDelta, spiritDelta = r.spiritDelta }
				else
					opt = row(name, item, r)
				end
				opt.blockedBy = blockedBy
				options[#options + 1] = opt
			end
		end
	end
	table.sort(options, function(x, y) return x.score > y.score end)
	return options
end

-- Per socket: the current augment's worth (vs an empty socket) and the best legal replacements.
function M.analyze(params)
	params = params or { }
	local b = session.build()
	local metric = gear._metricOf(params)
	local limit = tonumber(params.limit) or 5
	local calcFunc, _, measure = gear._measurer(b, metric)
	local entries = socketedItems(b, params.slot)
	local everywhere = equippedRunes(entries)
	local slots = util.array()
	for _, entry in ipairs(entries) do
		local item = entry.item
		local sockets = util.array()
		for i = 1, item.itemSocketCount do
			local cur = item.runes[i] or "None"
			local socket = { index = i, current = cur }
			if cur ~= "None" then
				local empty = measure(calcFunc({ repSlotName = entry.slot, repItem = variant(item, i, "None") }))
				local current = row(cur, item, { score = -empty.score, dpsPercent = -empty.dpsPercent, ehpPercent = -empty.ehpPercent,
					totemsDelta = empty.totemsDelta and -empty.totemsDelta, spiritDelta = empty.spiritDelta and -empty.spiritDelta })
				current.dead = math.abs(current.score) < DEAD and not current.unmodelled or nil
				current.socketBound = runeRules(item, cur).socketBound or nil
				socket.worth = current
			end
			if not (socket.worth and socket.worth.socketBound) then
				local options = rankSocket(b, entry, i, everywhere, calcFunc, measure)
				socket.legalOptions = #options
				socket.alternatives = util.array()
				for k = 1, math.min(limit, #options) do
					socket.alternatives[k] = options[k]
				end
				for _, o in ipairs(options) do
					if not o.blockedBy then
						socket.bestGain = o.score
						break
					end
				end
			end
			sockets[#sockets + 1] = socket
		end
		slots[#slots + 1] = {
			slot = entry.slot,
			item = item.name,
			corrupted = item.corrupted or nil,
			unique = (item.rarity == "UNIQUE" or item.rarity == "RELIC") or nil,
			sockets = sockets,
		}
	end
	return {
		metric = metric,
		slots = slots,
		note = "Percent of the current build (DPS counts every totem the Spirit budget keeps up). 'unmodelled' lines are invisible to PoB, so their worth shows as 0.",
	}
end

-- Greedy plan: take the best swap, apply it, re-measure, repeat. The build is restored afterwards.
function M.optimize(params)
	params = params or { }
	local b = session.build()
	local metric = gear._metricOf(params)
	local maxSwaps = tonumber(params.maxSwaps) or 8
	local minGain = tonumber(params.minGain) or 0.5
	local shortlist = tonumber(params.shortlist) or 6
	-- Augments with lines PoB can't see are only swapped out to free a character-wide limit.
	local keepUnmodelled = params.keepUnmodelled ~= false
	local entries = socketedItems(b, params.slot)
	local originals = { }
	for _, entry in ipairs(entries) do
		originals[#originals + 1] = { id = entry.item.id, item = entry.item }
	end
	local function restore()
		for _, o in ipairs(originals) do
			b.itemsTab.items[o.id] = o.item
		end
		session.recalc()
	end

	local steps, total = util.array(), nil
	local ok, err = pcall(function()
		local short = { } -- per socket: names worth re-testing after the first full pass
		for _ = 1, maxSwaps do
			local calcFunc, _, measure = gear._measurer(b, metric)
			local everywhere = equippedRunes(entries)
			-- Rank every socket from the current state.
			local ranked = { }
			for _, entry in ipairs(entries) do
				for i = 1, entry.item.itemSocketCount do
					local key = entry.slot .. "#" .. i
					local cur = entry.item.runes[i] or "None"
					if not runeRules(entry.item, cur).socketBound then
						local options = rankSocket(b, entry, i, everywhere, calcFunc, measure, short[key], true)
						if not short[key] then
							local names = { }
							for _, o in ipairs(options) do
								if #names >= shortlist then break end
								if o.name ~= "None" then names[#names + 1] = o.name end
							end
							short[key] = names
						end
						local lost = cur ~= "None" and unmodelled(runeRules(entry.item, cur).lines) or { }
						ranked[key] = { entry = entry, index = i, from = cur, options = options, lost = #lost > 0 and lost or nil }
					end
				end
			end
			-- Best move: one swap, or a swap blocked by a character-wide limit plus the swap that frees it.
			local function bestFree(r, limitId)
				for _, o in ipairs(r.options) do
					if not o.blockedBy and (not limitId or o.limitId ~= limitId) then
						return o
					end
				end
			end
			local best
			for _, r in pairs(ranked) do
				for _, o in ipairs(r.options) do
					local move
					if not o.blockedBy then
						if not (keepUnmodelled and r.lost) then
							move = { score = o.score, swaps = { { r = r, o = o } } }
						end
					elseif #o.blockedBy == 1 then
						local h = o.blockedBy[1]
						local other = ranked[h.slot .. "#" .. h.socket]
						local free = other and bestFree(other, o.limitId)
						if free then
							move = { score = o.score + free.score, swaps = { { r = r, o = o }, { r = other, o = free } } }
						end
					end
					if move and (not best or move.score > best.score) then
						best = move
					end
				end
			end
			if not best or best.score < minGain then
				break
			end
			for n, swap in ipairs(best.swaps) do
				local r, o = swap.r, swap.o
				steps[#steps + 1] = {
					slot = r.entry.slot, socket = r.index, from = r.from, to = o.name, lines = o.lines,
					unmodelled = o.unmodelled, losesUnmodelled = r.lost,
					pairedWith = #best.swaps > 1 and (best.swaps[3 - n].r.entry.slot .. " socket " .. best.swaps[3 - n].r.index) or nil,
					score = o.score, dpsPercent = o.dpsPercent, ehpPercent = o.ehpPercent,
					totemsDelta = o.totemsDelta, spiritDelta = o.spiritDelta,
				}
				local newItem = variant(r.entry.item, r.index, o.name)
				newItem.id = r.entry.item.id
				b.itemsTab.items[newItem.id] = newItem
				r.entry.item = newItem
				short[r.entry.slot .. "#" .. r.index] = nil
			end
			session.recalc()
		end
		if #steps > 0 then
			-- All steps together, measured against the original build.
			local finalOut = b.calcsTab.mainOutput
			restore()
			local _, _, measureFromStart = gear._measurer(b, metric)
			total = measureFromStart(finalOut)
		end
	end)
	restore()
	if not ok then
		error(err, 0)
	end
	local warnings = util.array()
	for _, s in ipairs(steps) do
		if s.losesUnmodelled then
			warnings[#warnings + 1] = ("%s socket %d: %s has effects PoB does not model (%s); weigh them before swapping"):format(
				s.slot, s.socket, s.from, table.concat(s.losesUnmodelled, "; "))
		end
	end
	return {
		metric = metric,
		steps = steps,
		total = total and { score = total.score, dpsPercent = total.dpsPercent, ehpPercent = total.ehpPercent,
			totemsDelta = total.totemsDelta, spiritDelta = total.spiritDelta } or nil,
		warnings = warnings,
		note = "Each step is measured after the previous ones are applied; 'total' is all steps together vs your current build. Nothing is changed.",
	}
end

return M
