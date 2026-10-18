-- gems.*: skill and support gem advice. What each support is worth, the best replacement for the weakest support
-- in each skill, gem level/quality upgrades and setup problems. Uses PoB's misc calculator, which rebuilds skills
-- from the live socket groups on every call (the same trick PoB's gem picker uses to sort gems by DPS).
local util = require("pobapi.util")
local session = require("pobapi.session")
local reference = require("pobapi.api.reference")

local M = { }

local SCORE = {
	balanced = function(r) return r.dpsPercent + r.ehpPercent end,
	dps = function(r) return r.dpsPercent end,
	ehp = function(r) return r.ehpPercent end,
}
local MIN = 0.05 -- percent

local function family(name)
	return (name:gsub("%s+[IVX]+$", ""))
end

local function isSupport(gem)
	return gem.gemData and gem.gemData.grantedEffect and gem.gemData.grantedEffect.support
end

function M.advise(params)
	local b = session.build()
	local metric = SCORE[params.metric or ""] and params.metric or "balanced"
	local score = SCORE[metric]
	local calcFunc, baseOutput = b.calcsTab:GetMiscCalculator()
	local base = reference._headline(baseOutput)
	-- Measure against `ref` (the build, or a secondary skill's own numbers when it is evaluated as main).
	local function measurer(ref, ownSkill, group)
		return function(output)
			local h = reference._headline(output, nil, group)
			local r = {
				dpsPercent = reference._pct(ref.dps, h.dps),
				ehpPercent = ownSkill and 0 or reference._pct(ref.ehp, h.ehp),
				lifeDelta = ownSkill and 0 or h.life - ref.life,
				esDelta = ownSkill and 0 or h.es - ref.es,
			}
			r.score = ownSkill and r.dpsPercent or score(r)
			reference._budgetDeltas(r, ref, h)
			return r
		end
	end

	-- Candidate supports (non-legacy, not item/tree granted), measured per group below.
	local supports = { }
	for id, gemData in pairs(data.gems) do
		local ge = gemData.grantedEffect
		if ge and ge.support and not ge.legacy and not ge.fromItem and not ge.fromTree then
			supports[#supports + 1] = { id = id, data = gemData }
		end
	end

	local groups, upgrades, problems = util.array(), util.array(), util.array()
	for gi, group in ipairs(b.skillsTab.socketGroupList) do
		if group.enabled ~= false and group.gemList and #group.gemList > 0 and not group.source then
			local actives = group.displaySkillList or { }
			local skillNames = util.array()
			for _, skill in ipairs(actives) do
				local ge = skill.activeEffect and skill.activeEffect.grantedEffect
				skillNames[#skillNames + 1] = ge and ge.name or "?"
			end
			-- Secondary damage skills are judged on their own DPS (evaluated as the main skill); utility skills
			-- (curses, auras, buffs) on what they do for the build.
			local isMain = b.mainSocketGroup == gi
			local override = { }
			local ref, ownSkill = base, false
			if not isMain then
				local own = reference._headline(calcFunc({ mainSocketGroup = gi }), nil, gi)
				if own.dps > 0 then
					override, ref, ownSkill = { mainSocketGroup = gi }, own, true
				end
			end
			local measure = measurer(ref, ownSkill, ownSkill and gi or nil)
			local entry = {
				measuredOn = ownSkill and "skill" or "build",
				index = gi,
				label = (group.label ~= "" and group.label) or util.strip(group.displayLabel or ""),
				skills = skillNames,
				isMain = isMain,
				gems = util.array(),
			}
			local families, weakest = { }, nil
			for idx, gem in ipairs(group.gemList) do
				local name = gem.gemData and gem.gemData.name or gem.nameSpec
				local g = { index = idx, name = name, support = isSupport(gem) or false, level = gem.level, quality = gem.quality, enabled = gem.enabled ~= false, problems = util.array() }
				if not gem.gemData then
					g.problems[#g.problems + 1] = "Not recognised by PoB"
				elseif gem.enabled == false then
					g.problems[#g.problems + 1] = "Disabled"
				else
					if g.support then
						local fam = family(name)
						if families[fam] then
							g.problems[#g.problems + 1] = "Duplicate of " .. families[fam]
						end
						families[fam] = name
						if gem.supportEffect and gem.supportEffect.isSupporting and next(gem.supportEffect.isSupporting) == nil then
							g.problems[#g.problems + 1] = "Doesn't support any skill in this group"
						end
						-- Worth: switch it off.
						gem.enabled = false
						local r = measure(calcFunc(override))
						gem.enabled = true
						g.worth = { dpsPercent = -r.dpsPercent, ehpPercent = -r.ehpPercent, lifeDelta = -r.lifeDelta, esDelta = -r.esDelta, score = -r.score }
						if r.score >= MIN then
							g.problems[#g.problems + 1] = ("Lowers output: removing it gives %+.1f%%"):format(r.score)
						elseif math.abs(r.score) < MIN then
							g.noEffect = true -- utility (cost, area, duration) or not modelled
						end
						if not weakest or g.worth.score < weakest.g.worth.score then
							weakest = { g = g, gem = gem }
						end
					end
					-- Level and quality upgrades.
					local maxLevel = gem.gemData.naturalMaxLevel or 20
					if (gem.level or 1) < maxLevel then
						local old = gem.level
						gem.level = old + 1
						local r = measure(calcFunc(override))
						gem.level = old
						if r.score >= MIN then
							g.levelUp = r
							upgrades[#upgrades + 1] = { kind = "level", group = gi, index = idx, name = name, from = old, to = old + 1, gain = r,
								text = ("Level %s %d → %d"):format(name, old, old + 1) }
						end
					end
					if not g.support and (gem.quality or 0) < 20 then
						local old = gem.quality or 0
						gem.quality = 20
						local r = measure(calcFunc(override))
						gem.quality = old
						if r.score >= MIN then
							g.qualityUp = r
							upgrades[#upgrades + 1] = { kind = "quality", group = gi, index = idx, name = name, from = old, to = 20, gain = r,
								text = ("Quality %s %d%% → 20%%"):format(name, old) }
						end
					end
				end
				for _, p in ipairs(g.problems) do
					problems[#problems + 1] = { group = gi, index = idx, name = name, problem = p }
				end
				entry.gems[#entry.gems + 1] = g
			end

			-- Best replacement for the weakest support.
			if weakest and actives[1] then
				local gem = weakest.gem
				local saved = { gemData = gem.gemData, level = gem.level, displayEffect = gem.displayEffect }
				local alternatives = { }
				-- Fresh calculator: the accelerated path caches its environment between calls.
				local swapCalc = b.calcsTab:GetMiscCalculator()
				for _, cand in ipairs(supports) do
					local fam = family(cand.data.name)
					if not families[fam] or fam == family(saved.gemData.name) then
						local ok = false
						for _, skill in ipairs(actives) do
							if calcLib.canGrantedEffectSupportActiveSkill(cand.data.grantedEffect, skill) then
								ok = true
								break
							end
						end
						if ok and cand.data ~= saved.gemData then
							gem.gemData = cand.data
							gem.level = b.skillsTab:ProcessGemLevel(cand.data)
							gem.displayEffect = nil
							local r = measure(swapCalc(override))
							r.name = cand.data.name
							r.lineage = cand.data.grantedEffect.isLineage or nil
							alternatives[#alternatives + 1] = r
						end
					end
				end
				gem.gemData, gem.level, gem.displayEffect = saved.gemData, saved.level, saved.displayEffect
				table.sort(alternatives, function(a, c) return a.score > c.score end)
				-- Regular supports first; the best lineage (rare, unique-like) support is listed separately.
				local top, bestAlt, bestLineage = util.array(), nil, nil
				for _, alt in ipairs(alternatives) do
					if alt.lineage then
						bestLineage = bestLineage or alt
					else
						bestAlt = bestAlt or alt
						if #top < 3 then top[#top + 1] = alt end
					end
				end
				if bestLineage and bestLineage.score >= MIN and (not bestAlt or bestLineage.score > bestAlt.score) then
					entry.lineage = bestLineage
				end
				if bestAlt and bestAlt.score >= MIN then
					entry.swap = { replace = weakest.g.name, index = weakest.g.index, with = bestAlt.name, gain = bestAlt, alternatives = top }
					upgrades[#upgrades + 1] = { kind = "swap", group = gi, index = weakest.g.index, name = weakest.g.name, with = bestAlt.name, gain = bestAlt,
						text = ("Replace %s with %s in %s"):format(weakest.g.name, bestAlt.name, skillNames[1] or entry.label) }
				end
			end
			groups[#groups + 1] = entry
		end
	end
	table.sort(upgrades, function(a, c) return a.gain.score > c.gain.score end)
	return { metric = metric, base = base, groups = groups, upgrades = upgrades, problems = problems }
end

return M
