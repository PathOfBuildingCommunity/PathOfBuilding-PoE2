-- gear.*: gear and jewel advice. What each item and mod is worth, what to look for on a replacement (PoB's own
-- trade stat weighting), a weighted trade-site query per slot, and which uniques would help most.
local util = require("pobapi.util")
local session = require("pobapi.session")
local reference = require("pobapi.api.reference")

local M = { }

local tradeHelpers = LoadModule("Classes/TradeHelpers")

-- Stat weights in TradeQueryGenerator's format. Results are reported as % of the current build (DPS% + EHP%).
local STAT_WEIGHTS = {
	balanced = { { stat = "FullDPS", weightMult = 1 }, { stat = "TotalEHP", weightMult = 1 } },
	dps = { { stat = "FullDPS", weightMult = 1 } },
	ehp = { { stat = "TotalEHP", weightMult = 1 } },
}
local SCORE = {
	balanced = function(r) return r.dpsPercent + r.ehpPercent end,
	dps = function(r) return r.dpsPercent end,
	ehp = function(r) return r.ehpPercent end,
}
local DEAD = 0.05 -- percent

local function metricOf(params)
	local m = params.metric or "balanced"
	return STAT_WEIGHTS[m] and m or "balanced"
end

local function measurer(b, metric)
	-- Item replacements also drop the replaced item's granted skills (see budget._calculator).
	local calcFunc, baseOutput = require("pobapi.api.budget")._calculator(b)
	local base = reference._headline(baseOutput)
	local score = SCORE[metric]
	return calcFunc, baseOutput, function(output)
		local h = reference._headline(output)
		local r = {
			dpsPercent = reference._pct(base.dps, h.dps),
			ehpPercent = reference._pct(base.ehp, h.ehp),
			lifeDelta = h.life - base.life,
			esDelta = h.es - base.es,
		}
		r.score = score(r)
		reference._budgetDeltas(r, base, h)
		return r
	end
end

-- Slots always advised on; others (weapon swap, Ring 3, limbs) only when something is equipped there.
local STANDARD = {
	["Weapon 1"] = "", ["Weapon 2"] = "", Helmet = "Helmet", ["Body Armour"] = "Body Armour", Gloves = "Gloves",
	Boots = "Boots", Amulet = "Amulet", ["Ring 1"] = "Ring", ["Ring 2"] = "Ring", Belt = "Belt",
}
local TWO_HANDED = { Staff = true, Bow = true, Crossbow = true, ["Two Hand Sword"] = true, ["Two Hand Axe"] = true,
	["Two Hand Mace"] = true, ["Fishing Rod"] = true }

-- Highest-level base of a type, used to evaluate an empty slot.
local function bestBase(baseType)
	local best, bestLevel
	for name, base in pairs(data.itemBases) do
		if base.type == baseType and not base.hidden then
			local level = base.req and base.req.level or 0
			if not best or level > bestLevel then
				best, bestLevel = name, level
			end
		end
	end
	return best
end

-- Base to evaluate an empty slot with, or nil when the slot can't be used.
local function emptySlotBase(b, name)
	if name == "Weapon 2" then
		local main = b.itemsTab.items[b.itemsTab.slots["Weapon 1"].selItemId]
		local t = main and main.base and main.base.type
		if t and TWO_HANDED[t] and t ~= "Bow" then
			return nil
		end
		return bestBase(t == "Bow" and "Quiver" or (t == "Wand" or t == "Sceptre") and "Focus" or "Shield")
	end
	local baseType = STANDARD[name]
	return baseType and baseType ~= "" and bestBase(baseType) or nil
end

-- Equipment slots worth advising on, plus allocated jewel sockets.
local function adviceSlots(b)
	local list = { }
	for _, slot in ipairs(b.itemsTab.orderedSlots) do
		local name = slot.slotName
		local item = b.itemsTab.items[slot.selItemId]
		if slot.nodeId then
			if b.spec.allocNodes[slot.nodeId] then
				list[#list + 1] = { slot = slot, name = name, item = item, jewel = true, base = item and item.baseName or "Sapphire" }
			end
		elseif item and not name:match("^Flask") and not name:find("Socket") then
			list[#list + 1] = { slot = slot, name = name, item = item, base = item.baseName }
		elseif not item and STANDARD[name] then
			local base = emptySlotBase(b, name)
			if base then
				list[#list + 1] = { slot = slot, name = name, base = base }
			end
		end
	end
	return list
end

function M.slots()
	local b = session.build()
	local res = util.array()
	for _, s in ipairs(adviceSlots(b)) do
		res[#res + 1] = {
			slot = s.name,
			jewel = s.jewel or nil,
			nodeId = s.slot.nodeId,
			item = s.item and { name = s.item.name, rarity = s.item.rarity, baseName = s.item.baseName } or nil,
		}
	end
	return res
end

local function copyItem(item)
	local copy = new("Item"):Item(item:BuildRaw())
	copy:NormaliseQuality()
	return copy
end

local ATTR_NAMES = { Str = "Strength", Dex = "Dexterity", Int = "Intelligence" }

-- Attribute that would fall below what gear and gems need (it was met in `base`).
local function brokenRequirement(base, out)
	for short, long in pairs(ATTR_NAMES) do
		if (base[short] or 0) >= (base["Req" .. short] or 0) and (out[short] or 0) < (out["Req" .. short] or 0) then
			return long
		end
	end
end

-- Value of each explicit/implicit mod line: the change from removing just that line.
local function modValues(slotName, item, calcFunc, measure, baseOutput)
	local res = util.array()
	for _, list in ipairs({ { key = "implicitModLines", kind = "implicit" }, { key = "explicitModLines", kind = "explicit" } }) do
		for i, line in ipairs(item[list.key] or { }) do
			if line.line and line.line ~= "" then
				local copy = copyItem(item)
				table.remove(copy[list.key], i)
				copy:BuildAndParseRaw()
				local out = calcFunc({ repSlotName = slotName, repItem = copy })
				local r = measure(out)
				local needed = brokenRequirement(baseOutput, out)
				-- Report what the line is worth (positive = it helps).
				res[#res + 1] = {
					text = util.strip(line.line),
					kind = list.kind,
					dpsPercent = -r.dpsPercent,
					ehpPercent = -r.ehpPercent,
					lifeDelta = -r.lifeDelta,
					esDelta = -r.esDelta,
					score = -r.score,
					requirement = needed,
					-- A unique's lines can't be rerolled, so an unmeasured one is reported as such rather than "dead".
					dead = item.rarity ~= "UNIQUE" and not needed and math.abs(r.score) < DEAD and math.abs(r.lifeDelta) < 1 and math.abs(r.esDelta) < 1 or nil,
					unmeasured = item.rarity == "UNIQUE" and not needed and math.abs(r.score) < DEAD or nil,
				}
			end
		end
	end
	return res
end

local generator
local tradeText
local function tradeGenerator(b)
	if not generator then
		generator = new("TradeQueryGenerator"):TradeQueryGenerator({ itemsTab = b.itemsTab })
		tradeText = { }
		for _, entries in pairs(generator.modData) do
			for _, entry in pairs(entries) do
				if type(entry) == "table" and entry.tradeMod then
					tradeText[entry.tradeMod.id] = entry.tradeMod.text
				end
			end
		end
	end
	generator.itemsTab = b.itemsTab
	return generator
end

-- Run TradeQueryGenerator's mod weighting for one slot (synchronously; it yields every ~50ms).
local function tradeWeights(b, s, metric, calcFunc, baseOutput)
	local testItem = new("Item"):Item("Rarity: RARE\nStat Tester\n" .. s.base)
	local categoryStr, category = tradeHelpers.getTradeCategory(s.name, s.item or testItem)
	if not category then
		return nil
	end
	if category == "Jewel" then
		category = "AnyJewel"
	end
	local gen = tradeGenerator(b)
	local weights = STAT_WEIGHTS[metric]
	local blankOutput = calcFunc({ repSlotName = s.name, repItem = testItem })
	local blankValue = gen.WeightedRatioOutputs(baseOutput, blankOutput, weights) * 1000
	gen.modWeights = { }
	gen.alreadyWeightedMods = { }
	gen.calcContext = {
		itemCategoryQueryStr = categoryStr,
		itemCategory = category,
		special = { },
		testItem = testItem,
		baseOutput = baseOutput,
		baseStatValue = blankValue,
		calcFunc = calcFunc,
		options = { statWeights = weights, jewelType = "Any" },
		slot = s.slot,
	}
	local co = coroutine.create(gen.ExecuteQuery)
	repeat
		local ok, err = coroutine.resume(co, gen)
		if not ok then
			error(err, 0)
		end
	until coroutine.status(co) == "dead"

	-- What the current item's mods are worth on the same scale.
	local current = 0
	if s.item then
		testItem.explicitModLines = { }
		for _, key in ipairs({ "explicitModLines", "implicitModLines" }) do
			for _, line in ipairs(s.item[key] or { }) do
				table.insert(testItem.explicitModLines, line)
			end
		end
		testItem:BuildAndParseRaw()
		local out = calcFunc({ repSlotName = s.name, repItem = testItem })
		current = gen.WeightedRatioOutputs(baseOutput, out, weights) * 1000 - blankValue
	end
	table.sort(gen.modWeights, function(a, c) return a.meanStatDiff > c.meanStatDiff end)
	return { categoryStr = categoryStr, category = category, weights = gen.modWeights, current = current }
end

local function lookForText(id, value)
	local text = tradeText[id] or id
	local v = math.floor(value + 0.5)
	text = text:gsub("%+?#", (text:find("%+#") and v >= 0) and ("+" .. v) or tostring(v), 1):gsub("%s*%(Local%)", "")
	return (text:gsub("^%s+", ""):gsub("%s+$", ""))
end

-- Full advice for one slot.
function M.slot(params)
	local b = session.build()
	local name = util.require(params, "slot", "string")
	local metric = metricOf(params)
	local target
	for _, s in ipairs(adviceSlots(b)) do
		if s.name == name then
			target = s
		end
	end
	if not target then
		util.fail("Unknown or unadvisable slot: " .. name)
	end
	local calcFunc, baseOutput, measure = measurer(b, metric)
	local res = { slot = name, metric = metric, jewel = target.jewel or nil, testBase = not target.item and target.base or nil }
	if target.item then
		local it = target.item
		res.item = { name = it.name, rarity = it.rarity, baseName = it.baseName, title = it.title }
		-- Worth of the whole item: swap it for the bare base, and for nothing at all.
		local blank = new("Item"):Item("Rarity: RARE\nStat Tester\n" .. it.baseName)
		res.modsWorth = (function()
			local r = measure(calcFunc({ repSlotName = name, repItem = blank }))
			return { dpsPercent = -r.dpsPercent, ehpPercent = -r.ehpPercent, lifeDelta = -r.lifeDelta, esDelta = -r.esDelta, score = -r.score }
		end)()
		res.mods = modValues(name, it, calcFunc, measure, baseOutput)
	end

	local tw = tradeWeights(b, target, metric, calcFunc, baseOutput)
	if tw then
		local look = util.array()
		local limit = tonumber(params.limit) or 12
		for i, w in ipairs(tw.weights) do
			if i > limit then break end
			local value = w.weight ~= 0 and w.meanStatDiff / w.weight or 0
			look[#look + 1] = { id = w.tradeModId, text = lookForText(w.tradeModId, value), value = value, percent = w.meanStatDiff / 10 }
		end
		res.lookFor = look
		res.currentPercent = tw.current / 10
		-- A good replacement: the four most valuable mods at average rolls.
		local ideal = 0
		for i = 1, math.min(4, #tw.weights) do
			ideal = ideal + tw.weights[i].meanStatDiff / 10
		end
		res.idealPercent = ideal
		res.headroom = math.max(0, ideal - res.currentPercent)
		-- Weighted-sum query for the trade site (the service adds the league to build the URL).
		local filters = { }
		for i, w in ipairs(tw.weights) do
			if i > 35 then break end
			filters[#filters + 1] = { id = w.tradeModId, value = { weight = w.weight } }
		end
		res.tradeQuery = {
			query = {
				filters = {
					type_filters = { filters = { category = { option = tw.categoryStr }, rarity = { option = "nonunique" } } },
					misc_filters = { disabled = false, filters = { mirrored = false } },
				},
				status = { option = "online" },
				stats = { { type = "weight", value = { min = math.max(0, tw.current * 0.5) }, filters = filters } },
			},
			sort = { ["statgroup.0"] = "desc" },
			engine = "new",
		}
	else
		res.unsupported = true
	end
	if res.mods then
		local dead = 0
		for _, m in ipairs(res.mods) do
			if m.dead then dead = dead + 1 end
		end
		res.deadMods = dead
	end
	return res
end

-- Uniques from PoB's database that fit a slot, measured in the current build, best first per slot.
function M.uniques(params)
	local b = session.build()
	local metric = metricOf(params)
	local limit = tonumber(params.limit) or 8
	local calcFunc, _, measure = measurer(b, metric)
	local slots = adviceSlots(b)
	local bySlot, best = { }, { }
	for name, item in pairs(main.uniqueDB.list) do
		if item.base and not item.base.flask then
			local top
			for _, s in ipairs(slots) do
				if b.itemsTab:IsItemValidForSlot(item, s.name) and not (s.item and s.item.title == item.title) then
					local r = measure(calcFunc({ repSlotName = s.name, repItem = item }))
					if not top or r.score > top.r.score then
						top = { r = r, slot = s.name }
					end
				end
			end
			if top then
				local key = top.slot:match("^Jewel") and "Jewel" or top.slot:gsub(" %d$", "")
				bySlot[key] = bySlot[key] or { }
				local row = top.r
				row.name = item.title or name
				row.baseName = item.baseName
				row.slot = top.slot
				row.levelRequirement = item.requirements and item.requirements.level or nil
				table.insert(bySlot[key], row)
			end
		end
	end
	local res = util.array()
	for key, rows in pairs(bySlot) do
		table.sort(rows, function(a, c) return a.score > c.score end)
		local kept = util.array()
		for i, row in ipairs(rows) do
			if i > limit or row.score < DEAD then break end
			kept[#kept + 1] = row
		end
		if #kept > 0 then
			res[#res + 1] = { slot = key, items = kept }
		end
	end
	table.sort(res, function(a, c) return a.items[1].score > c.items[1].score end)
	return res
end

M._metricOf = metricOf
M._measurer = measurer

return M
