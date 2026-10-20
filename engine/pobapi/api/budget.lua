-- budget.*: Spirit and totem budget, effective DPS across all totems, and "check before you buy" item verdicts.
--
-- Why this exists: PoB reports a totem skill's DPS per totem, reserves Ancestral Bond's "75 Spirit per totem" only
-- once (per skill instance), and does not parse "Your Totem Limit is doubled". A weapon that drops Spirit can
-- therefore cost totems without PoB showing any damage loss. Everything here works from PoB's own outputs.
local util = require("pobapi.util")
local session = require("pobapi.session")

local M = { }

local doublingParsed
-- True when PoB itself applies "Your Totem Limit is doubled" (then we must not double again).
local function doublingHandledByPoB()
	if doublingParsed == nil then
		local list = modLib.parseMod("Your Totem Limit is doubled")
		doublingParsed = type(list) == "table" and #list > 0
	end
	return doublingParsed
end

-- How a totem skill's limit is made up: `extra` is the BASE ActiveTotemLimit from sources other than skill gems
-- (passives, ascendancy, items), and `overridden` is set when a gem OVERRIDEs the limit. Spell Totem's data does
-- that (a fixed 2, "Should fix to take from active part of gem"), which drops every extra such as Oracle's
-- Unnamed Heartwood (+1 to maximum number of Summoned Totems).
local function totemLimitParts(skill)
	local res = { extra = 0 }
	if not skill.skillModList or not skill.skillCfg then
		return res
	end
	res.overridden = skill.skillModList:Override(skill.skillCfg, "ActiveTotemLimit", "ActiveBallistaLimit") ~= nil or nil
	for _, row in ipairs(skill.skillModList:Tabulate("BASE", skill.skillCfg, "ActiveTotemLimit", "ActiveBallistaLimit")) do
		local source = row.mod and row.mod.source or ""
		if not source:match("^Skill:") then
			res.extra = res.extra + (row.value or 0)
		end
	end
	return res
end

-- Per-build facts that what-if outputs don't carry: Spirit cost per totem and how PoB counted it.
function M._context(b)
	b = b or session.build()
	local env = b.calcsTab.mainEnv
	local ctx = { ancestralBond = false, cost = nil, pobCount = 1, skills = { }, totemGroups = { }, totemLimits = { }, mainGroup = b.mainSocketGroup }
	if not env or not env.player then
		return ctx
	end
	-- Socket groups whose skills are cast by totems (PoB reports a totem limit for every main skill).
	local groupIndex = { }
	for i, group in ipairs(b.skillsTab.socketGroupList) do
		groupIndex[group] = i
	end
	ctx.ancestralBond = env.player.modDB:Flag(nil, "AncestralBond") or false
	ctx.configuredTotems = env.configInput and tonumber(env.configInput.TotemsSummoned) or nil
	for _, skill in ipairs(env.player.activeSkillList or { }) do
		local gi = skill.socketGroup and groupIndex[skill.socketGroup]
		if gi and ((skill.skillFlags and skill.skillFlags.totem) or (skill.skillTypes and skill.skillTypes[SkillType.SummonsTotem])) then
			ctx.totemGroups[gi] = true
		end
		if gi then
			-- A meta gem's group holds the totem (Spell Totem) and the skill it casts (Grim Pillars); the override
			-- sits on the cast skill, which is not flagged as a totem skill itself.
			local parts, seen = totemLimitParts(skill), ctx.totemLimits[gi]
			if seen then
				parts.overridden = parts.overridden or seen.overridden
				parts.extra = math.max(parts.extra, seen.extra)
			end
			ctx.totemLimits[gi] = parts
		end
		local reserved = skill.skillData and skill.skillData.SpiritReservedBase
		if reserved and reserved > 0 then
			local name = skill.activeEffect and skill.activeEffect.grantedEffect and skill.activeEffect.grantedEffect.name or "?"
			local count = skill.activeEffect and skill.activeEffect.srcInstance and skill.activeEffect.srcInstance.count or 1
			local isTotem = skill.skillTypes and skill.skillTypes[SkillType.SummonsTotem] and ctx.ancestralBond
			ctx.skills[#ctx.skills + 1] = { name = name, spirit = reserved, totem = isTotem or nil }
			if isTotem then
				ctx.cost = math.max(ctx.cost or 0, reserved / math.max(count, 1))
				ctx.pobCount = math.max(count, 1)
			end
		end
	end
	return ctx
end

-- Spirit and totems for one calc output (base or what-if); `group` is the main socket group it was calculated for.
function M._summarize(output, ctx, group)
	local res = {
		spirit = output.Spirit or 0,
		unreserved = output.SpiritUnreserved or 0,
	}
	res.reserved = res.spirit - res.unreserved
	local limit = output.ActiveTotemLimit
	group = group or ctx.mainGroup
	if limit and limit > 0 and ctx.totemGroups[group] then
		-- Split the limit into the skill's own base and the extras (passives, ascendancy, items). An OVERRIDE
		-- (Spell Totem) hides the extras from PoB's number, so they are added back here.
		local parts = ctx.totemLimits[group] or { extra = 0 }
		local extra = parts.extra or 0
		local base = parts.overridden and limit or math.max(limit - extra, 0)
		if ctx.ancestralBond and not doublingHandledByPoB() then
			-- The order of "Totem Limit is doubled" and flat additions is not documented. In game, Spell Totem (2)
			-- with Unnamed Heartwood (+1) and Ancestral Bond places 5 = 2 x 2 + 1, so only the base is doubled.
			base = base * 2
		end
		local cap = base + extra
		-- Config "# of Summoned Totems" may say more than PoB works out (e.g. mods it does not parse), and fewer.
		local wanted = cap
		if ctx.configuredTotems and ctx.configuredTotems > 0 then
			wanted = ctx.configuredTotems
			cap = math.max(cap, wanted)
		end
		res.totemCap = cap
		res.totems = wanted
		if ctx.cost and ctx.cost > 0 then
			-- PoB already subtracted one totem's worth (pobCount); add it back and divide by the per-totem cost.
			local affordable = math.floor((res.unreserved + ctx.cost * ctx.pobCount) / ctx.cost + 1e-9)
			res.totemCost = ctx.cost
			res.totemsAffordable = math.max(0, affordable)
			res.totems = math.min(wanted, res.totemsAffordable)
			res.spiritLimited = res.totemsAffordable < wanted or nil
		end
		res.perTotemDps = math.max(output.TotalDPS or 0, output.CombinedDPS or 0)
	end
	if res.unreserved < 0 then
		res.spiritShort = -res.unreserved
	end
	return res
end

-- Main-skill DPS counting every totem you can actually keep up (unchanged for non-totem skills and Full DPS).
function M._effectiveDps(output, summary)
	local full = output.FullDPS or 0
	if full > 0 then
		return full
	end
	local dps = math.max(output.TotalDPS or 0, output.CombinedDPS or 0)
	if summary.totems then
		dps = dps * summary.totems
	end
	return dps
end

-- Run fn with the skills granted by the item in `slotName` switched off: they disappear when that item is replaced
-- (e.g. Sacred Flame's Purity of Fire), but PoB's what-if calculator keeps them unless told otherwise.
function M._withoutGrantedSkills(b, slotName, fn)
	local disabled = { }
	for _, group in ipairs(b.skillsTab.socketGroupList) do
		if group.sourceItem and group.slot == slotName and group.enabled ~= false then
			group.enabled = false
			disabled[#disabled + 1] = group
		end
	end
	local ok, res = pcall(fn)
	for _, group in ipairs(disabled) do
		group.enabled = true
	end
	if not ok then
		error(res, 0)
	end
	return res
end

-- A misc calculator whose item replacements also drop the replaced item's granted skills.
function M._calculator(b)
	local rawCalc, baseOutput = b.calcsTab:GetMiscCalculator()
	local function calc(override, ...)
		if override and override.repSlotName and override.repItem then
			local args = { ... }
			return M._withoutGrantedSkills(b, override.repSlotName, function() return rawCalc(override, unpack(args)) end)
		end
		return rawCalc(override, ...)
	end
	return calc, baseOutput
end

local ATTRIBUTES = { Str = "Strength", Dex = "Dexterity", Int = "Intelligence" }

-- Attributes that fall below what gear and gems need in `out` (they were met in `base`).
function M._brokenRequirements(base, out)
	local res = util.array()
	for short, long in pairs(ATTRIBUTES) do
		if (base[short] or 0) >= (base["Req" .. short] or 0) and (out[short] or 0) < (out["Req" .. short] or 0) then
			res[#res + 1] = { attribute = long, have = out[short] or 0, need = out["Req" .. short] or 0 }
		end
	end
	return res
end

-- Before/after budget for a what-if, with plain-language warnings.
function M._compare(baseOutput, newOutput, ctx)
	ctx = ctx or M._context()
	local before, after = M._summarize(baseOutput, ctx), M._summarize(newOutput, ctx)
	local res = {
		before = before,
		after = after,
		effectiveBefore = M._effectiveDps(baseOutput, before),
		effectiveAfter = M._effectiveDps(newOutput, after),
		warnings = util.array(),
	}
	if before.totems and after.totems and after.totems < before.totems then
		res.warnings[#res.warnings + 1] = ("Totems %d → %d: Spirit %d → %d (each totem reserves %d Spirit)"):format(
			before.totems, after.totems, before.spirit, after.spirit, after.totemCost or ctx.cost or 0)
	end
	if after.spiritShort and not before.spiritShort then
		res.warnings[#res.warnings + 1] = ("Spirit short by %d: some reserving skills would switch off"):format(after.spiritShort)
	end
	for _, r in ipairs(M._brokenRequirements(baseOutput, newOutput)) do
		res.warnings[#res.warnings + 1] = ("%s %d below the %d your gear and gems need"):format(r.attribute, r.have, r.need)
	end
	return res
end

-- Current budget with the Spirit reservation breakdown.
function M.get()
	local b = session.build()
	local ctx = M._context(b)
	local output = b.calcsTab.mainOutput
	local summary = M._summarize(output, ctx)
	summary.effectiveDps = M._effectiveDps(output, summary)
	summary.ancestralBond = ctx.ancestralBond or nil
	summary.reservations = util.array()
	for _, s in ipairs(ctx.skills) do
		if s.totem and summary.totems then
			summary.reservations[#summary.reservations + 1] = { name = s.name .. " totems", spirit = (summary.totemCost or 0) * summary.totems, totem = true, count = summary.totems }
		else
			summary.reservations[#summary.reservations + 1] = { name = s.name, spirit = s.spirit }
		end
	end
	if summary.totems then
		-- Spirit actually in use once every affordable totem is out.
		summary.free = summary.spirit - (summary.reserved - (summary.totemCost or 0) * ctx.pobCount) - (summary.totemCost or 0) * summary.totems
	else
		summary.free = summary.unreserved
	end
	return summary
end

local function slotFor(b, item, wanted)
	if wanted then
		if not b.itemsTab.slots[wanted] then
			util.fail("Unknown slot: " .. tostring(wanted))
		end
		return { wanted }
	end
	local primary = item:GetPrimarySlot()
	-- Upstream only maps shields and quivers to the off-hand; a Focus comes back as "Focus", which is not a slot.
	if item.type == "Focus" then
		primary = "Weapon 2"
	end
	if not b.itemsTab.slots[primary] then
		util.fail(("No slot for %s items (%s)"):format(tostring(item.type), tostring(primary)))
	end
	if primary == "Ring 1" then
		return { "Ring 1", "Ring 2" }
	end
	if item.type == "Jewel" then
		local res = { }
		for _, slot in ipairs(b.itemsTab.orderedSlots) do
			if slot.nodeId and b.spec.allocNodes[slot.nodeId] then
				res[#res + 1] = slot.slotName
			end
		end
		return res
	end
	return { primary }
end

-- "Check before you buy": every damage skill (counting totems), Spirit/totems, defences, requirements, verdict.
function M.check_item(params)
	local b = session.build()
	local item = new("Item"):Item(util.require(params, "text", "string"))
	if not item.base then
		util.fail("Could not parse item (unknown base type)")
	end
	item:NormaliseQuality()
	item:BuildModList()
	local ctx = M._context(b)
	local calcFunc, baseOutput = M._calculator(b)

	-- Pick the slot where it does best (e.g. the weaker ring, the weakest jewel).
	local best
	for _, slotName in ipairs(slotFor(b, item, params.slot)) do
		local out = calcFunc({ repSlotName = slotName, repItem = item })
		local cmp = M._compare(baseOutput, out, ctx)
		local score = cmp.effectiveBefore > 0 and (cmp.effectiveAfter / cmp.effectiveBefore - 1) or 0
		score = score + ((baseOutput.TotalEHP or 0) > 0 and ((out.TotalEHP or 0) / baseOutput.TotalEHP - 1) or 0)
		if not best or score > best.score then
			best = { slot = slotName, out = out, cmp = cmp, score = score }
		end
	end
	if not best then
		util.fail("This item doesn't fit any of your slots")
	end
	local out, cmp = best.out, best.cmp
	local current = b.itemsTab.items[b.itemsTab.slots[best.slot].selItemId]

	-- Each damage skill, measured as the main skill, with its totems counted.
	local skills = util.array()
	for gi, group in ipairs(b.skillsTab.socketGroupList) do
		if group.enabled ~= false and group.displaySkillList and group.displaySkillList[1] then
			local before = calcFunc({ mainSocketGroup = gi })
			local after = calcFunc({ mainSocketGroup = gi, repSlotName = best.slot, repItem = item })
			local sb, sa = M._summarize(before, ctx, gi), M._summarize(after, ctx, gi)
			local eb, ea = M._effectiveDps(before, sb), M._effectiveDps(after, sa)
			local lost = group.sourceItem and group.slot == best.slot
			if lost then
				ea = 0
			end
			if eb > 0 or ea > 0 then
				local ge = group.displaySkillList[#group.displaySkillList].activeEffect.grantedEffect
				skills[#skills + 1] = {
					group = gi,
					name = ge and ge.name or ("Group " .. gi),
					isMain = b.mainSocketGroup == gi or nil,
					before = eb,
					after = ea,
					percent = eb > 0 and (ea / eb - 1) * 100 or nil,
					totemsBefore = sb.totems,
					totemsAfter = (not lost) and sa.totems or nil,
					lost = lost or nil,
				}
			end
		end
	end

	local function stat(key)
		return { before = baseOutput[key] or 0, after = out[key] or 0 }
	end
	local defence = {
		Life = stat("Life"), EnergyShield = stat("EnergyShield"), Mana = stat("Mana"), TotalEHP = stat("TotalEHP"),
		FireResist = stat("FireResist"), ColdResist = stat("ColdResist"), LightningResist = stat("LightningResist"),
		ChaosResist = stat("ChaosResist"), PhysicalMaximumHitTaken = stat("PhysicalMaximumHitTaken"),
		LifeRegenRecovery = stat("LifeRegenRecovery"),
	}

	local lostSkills = util.array()
	for _, group in ipairs(b.skillsTab.socketGroupList) do
		if group.sourceItem and group.slot == best.slot and group.enabled ~= false and group.displaySkillList and group.displaySkillList[1] then
			local ge = group.displaySkillList[1].activeEffect.grantedEffect
			lostSkills[#lostSkills + 1] = ge and ge.name or "?"
		end
	end
	if #lostSkills > 0 then
		cmp.warnings[#cmp.warnings + 1] = "Removes skills granted by " .. (current and current.name or "the current item") .. ": " .. table.concat(lostSkills, ", ")
	end

	-- Verdict, judged on the main skill (all totems) and effective HP.
	local main
	for _, s in ipairs(skills) do
		if s.isMain then main = s end
	end
	local dpsPct = main and main.percent or 0
	local ehpPct = defence.TotalEHP.before > 0 and (defence.TotalEHP.after / defence.TotalEHP.before - 1) * 100 or 0
	local reasons = util.array()
	local verdict
	if #cmp.warnings > 0 then
		for _, w in ipairs(cmp.warnings) do reasons[#reasons + 1] = w end
	end
	if main then
		reasons[#reasons + 1] = ("%s: %s DPS%s"):format(main.name, ("%+.1f%%"):format(dpsPct),
			main.totemsAfter and (" (" .. main.totemsAfter .. " totem" .. (main.totemsAfter == 1 and "" or "s") .. ")") or "")
	end
	reasons[#reasons + 1] = ("Effective HP %+.1f%%"):format(ehpPct)
	local lostTotems = main and main.totemsBefore and main.totemsAfter and main.totemsAfter < main.totemsBefore
	if dpsPct <= -2 or ehpPct <= -5 or lostTotems or (cmp.after.spiritShort and not cmp.before.spiritShort) then
		verdict = "downgrade"
	elseif (dpsPct >= 2 and ehpPct > -2) or (ehpPct >= 3 and dpsPct > -1) then
		verdict = "upgrade"
	else
		verdict = "sidegrade"
	end
	return {
		item = item.name,
		slot = best.slot,
		replaces = current and current.name or nil,
		verdict = verdict,
		reasons = reasons,
		warnings = cmp.warnings,
		budget = { before = cmp.before, after = cmp.after },
		lostSkills = lostSkills,
		skills = skills,
		defence = defence,
		caveat = "PoB's calculation for your current Config settings. Skills the new item grants are not counted until it is equipped; skills the replaced item granted are removed.",
	}
end

return M
