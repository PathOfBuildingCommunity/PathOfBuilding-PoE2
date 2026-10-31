-- Path of Building
--
-- Module: Calc Breakdown
-- Calculation breakdown generators
--

local unpack = unpack
local ipairs = ipairs
local t_insert = table.insert
local m_floor = math.floor
local m_sqrt = math.sqrt
local m_min = math.min
local m_max = math.max
local s_format = string.format

return function(modDB, output, actor)
	---@class Breakdown
	local breakdown = {}

	function breakdown.multiChain(out, chain)
		local base = (chain.base and chain.base[2]) or nil
		local multiplier = 1
		local lines = 0 -- lines is the total number of non 1 multipliers.
		if chain.label then
			t_insert(out, localisation:Field(chain, 'label'))
		end
		if base ~= nil then
			t_insert(out, localisation:FormatArray(chain.base))
		end
		if base ~= 0 then
			for _, mult in ipairs(chain) do
				if mult[2] and mult[2] ~= 1 then
					multiplier = multiplier * mult[2]
					t_insert(out, "x "..localisation:FormatArray(mult))
					lines = lines + 1
				end
			end
		end
		if chain.total then
			t_insert(out, chain.total)
		elseif not chain.noTotal and (lines > 0 and base ~= nil) or (lines > 1 and base == nil) then
			t_insert(out, s_format("= %.2f", multiplier * (base or 1)))
		end
		return lines
	end

	function breakdown.simple(extraBase, cfg, total, ...)
		extraBase = extraBase or 0
		local base = modDB:Sum("BASE", cfg, (...))
		if (base + extraBase) ~= 0 then
			local inc = modDB:Sum("INC", cfg, ...)
			local more = modDB:More(cfg, ...)
			if inc ~= 0 or more ~= 1 or (base ~= 0 and extraBase ~= 0) then
				local out = { }
				if base ~= 0 and extraBase ~= 0 then
					out[1] = localisation:Text("calc.breakdown.simple.line", { extra_base = extraBase, base = base })
				else
					out[1] = localisation:Text("calc.breakdown.simple.line_2", { value = base + extraBase })
				end
				if inc ~= 0 then
					t_insert(out, localisation:Text("calc.breakdown.simple.line_3", { value = 1 + inc/100 }))
				end
				if more ~= 1 then
					t_insert(out, localisation:Text("calc.breakdown.simple.line_4", { more = more }))
				end
				t_insert(out, s_format("= %g", total))
				return out
			end
		end
	end

	function breakdown.mod(modList, cfg, ...)
		local inc = modList:Sum("INC", cfg, ...)
		local more = modList:More(cfg, ...)
		if inc ~= 0 and more ~= 1 then
			return {
				localisation:Text("calc.breakdown.mod.line", { value = 1 + inc/100 }),
				localisation:Text("calc.breakdown.mod.line_2", { more = more }),
				s_format("= %.2f", (1 + inc/100) * more),
			}
		end
	end

	function breakdown.slot(source, sourceName, cfg, base, total, ...)
		local inc = modDB:Sum("INC", cfg, ...)
		local more = modDB:More(cfg, ...)
		t_insert(breakdown[...].slots, {
			base = base,
			inc = (inc ~= 0) and s_format(" x %.2f", 1 + inc/100),
			more = (more ~= 1) and s_format(" x %.2f", more),
			total = s_format("%.2f", total or (base * (1 + inc / 100) * more)),
			source = source, sourceKey = localisation:TermKey((source == "Global" or source == "Conversion") and "calculation_source" or "equipment.slot", source),
			sourceName = sourceName,
			item = not sourceName and actor.itemList[source],
		})
	end

	function breakdown.area(base, areaMod, total, incBreakpoint, moreBreakpoint, redBreakpoint, lessBreakpoint, label, radiusMod)
		local out = {}
		t_insert(out, label)
		if base ~= total then
			t_insert(out, localisation:Text("calc.breakdown.area.line", { value = base / 10 }))
			t_insert(out, localisation:Text("calc.breakdown.area.line_2", { value = m_floor(100 * m_sqrt(areaMod)) / 100 }))
			if radiusMod and radiusMod ~= 1 then
				t_insert(out, localisation:Text("calc.breakdown.area.line_3", { radius_mod = radiusMod }))
			end
			t_insert(out, s_format("= %.1fm", total / 10))
		end
		if incBreakpoint and moreBreakpoint and redBreakpoint and lessBreakpoint then
			t_insert(out, localisation:Text("calc.breakdown.area.line_4", { inc_breakpoint = incBreakpoint, more_breakpoint = moreBreakpoint }))
			t_insert(out, localisation:Text("calc.breakdown.area.line_5", { red_breakpoint = redBreakpoint, less_breakpoint = lessBreakpoint }))
		end
		out.radius = total
		return out
	end

	function breakdown.effMult(damageType, resist, pen, taken, mult, takenMore, sourceRes, useRes, invertChance, minPen, effectiveResist, normalHitResist, invertedHitResist)
		local out = { }
		local resistLabel = localisation:Ref(damageType == "Physical" and "calc.resistance.physical_reduction" or "calc.resistance.resistance")
		minPen = minPen or 0
		local calcPenResist = function(resist)
			return resist > minPen and m_max(resist - pen, minPen) or resist
		end
		effectiveResist = effectiveResist or calcPenResist(resist)

		if sourceRes and sourceRes ~= damageType then
			t_insert(out, localisation:Text("calc.breakdown.eff_mult.line", { resist_label = resistLabel, resist = resist, source_res = sourceRes }))
		elseif resist ~= 0 then
			t_insert(out, localisation:Text("calc.breakdown.eff_mult.line_2", { resist_label = resistLabel, resist = resist }))
		end
		if invertChance and invertChance ~= 0 and useRes then
			normalHitResist = normalHitResist or calcPenResist(resist)
			invertedHitResist = invertedHitResist or calcPenResist(-resist)
			t_insert(out, localisation:Text("calc.breakdown.eff_mult.line_3"))
			t_insert(out, localisation:Text("calc.breakdown.eff_mult.line_4", { normal_hit_resist = normalHitResist }))
			t_insert(out, localisation:Text("calc.breakdown.eff_mult.line_5", { inverted_hit_resist = invertedHitResist }))
			t_insert(out, localisation:Text("calc.breakdown.eff_mult.line_6", { effective_resist = effectiveResist, value = invertChance * 100 }))
		elseif pen ~= 0 or not useRes then
			t_insert(out, localisation:Text("calc.breakdown.eff_mult.line_3"))
			t_insert(out, localisation:Text("calc.breakdown.eff_mult.line_7", { resist = resist }))
			if pen < 0 then
				t_insert(out, localisation:Text("calc.breakdown.eff_mult.line_8", { value = -pen }))
			elseif pen > 0 then
				t_insert(out, localisation:Text("calc.breakdown.eff_mult.line_9", { pen = pen }))
			end
			if not useRes then
				t_insert(out, localisation:Text("calc.breakdown.eff_mult.line_10", { value = 0 }))
				t_insert(out, s_format("= %d%%", (0)))
			elseif resist <= minPen then
				t_insert(out, localisation:Text("calc.breakdown.eff_mult.line_11", { resist = resist }))
			elseif (resist - pen) < minPen then
				t_insert(out, localisation:Text("calc.breakdown.eff_mult.line_12", { value = m_max(resist - pen, minPen), min_pen = minPen }))
			else
				t_insert(out, s_format("= %d%%", (resist - pen)))
			end
		end
		if useRes then
			breakdown.multiChain(out, {
				label = "Effective DPS modifier:", labelKey = "ui.calc_breakdown.eff_mult.label",
				{ "%.2f ^8(%s)", 1 - effectiveResist / 100, resistLabel, formatKey = "calc.resistance.factor", formatParams = { value = 2, resistance = 3 } },
				{ "%.2f ^8(increased/reduced damage taken)", 1 + taken / 100, formatKey = "calc.breakdown.eff_mult.factor", formatParams = { value = 2 } },
				{ "%.2f ^8(more/less damage taken)", takenMore, formatKey = "calc.breakdown.eff_mult.factor_2", formatParams = { taken_more = 2 } },
				total = s_format("= %.3f", mult),
			})
		else
			t_insert(out, localisation:Text("calc.breakdown.eff_mult.line_13"))
			t_insert(out, localisation:Text("calc.breakdown.eff_mult.line_14", { mult = mult }))
		end
		return out
	end

	function breakdown.dot(out, baseVal, inc, more, mult, rate, aura, effMult, total)
		breakdown.multiChain(out, {
			base = { "%.1f ^8(base damage per second)", baseVal, formatKey = "calc.breakdown.dot.factor", formatParams = { base_val = 2 } },
			{ "%.2f ^8(increased/reduced)", 1 + inc/100, formatKey = "calc.breakdown.dot.factor_2", formatParams = { value = 2 } },
			{ "%.2f ^8(more/less)", more, formatKey = "calc.breakdown.dot.factor_3", formatParams = { more = 2 } },
			{ "%.2f ^8(multiplier)", 1 + (mult or 0)/100, formatKey = "calc.breakdown.dot.factor_4", formatParams = { value = 2 } },
			{ "%.2f ^8(rate modifier)", rate, formatKey = "calc.breakdown.dot.factor_5", formatParams = { rate = 2 } },
			{ "%.3f ^8(aura effect modifier)", aura, formatKey = "calc.breakdown.dot.factor_6", formatParams = { aura = 2 } },
			{ "%.3f ^8(effective DPS modifier)", effMult, formatKey = "calc.breakdown.dot.factor_7", formatParams = { eff_mult = 2 } },
			total = localisation:Text("calc.breakdown.dot.line", { total = total }),
		})
	end

	function breakdown.critDot(dotMulti, critMulti, dotChance, critChance)
		local combined = (dotMulti * dotChance) + (critMulti * critChance)
		local out = { }
		if dotChance > 0 then
			t_insert(out, localisation:Text("calc.breakdown.crit_dot.line"))
			t_insert(out, localisation:Text("calc.breakdown.crit_dot.line_2", { dot_multi = dotMulti }))
			t_insert(out, localisation:Text("calc.breakdown.crit_dot.line_3", { dot_chance = dotChance }))
			t_insert(out, s_format("= %.2f", dotMulti * dotChance))
		end
		if critChance > 0 then
			t_insert(out, localisation:Text("calc.breakdown.crit_dot.line_4"))
			t_insert(out, localisation:Text("calc.breakdown.crit_dot.line_5", { crit_multi = critMulti }))
			t_insert(out, localisation:Text("calc.breakdown.crit_dot.line_6", { crit_chance = critChance }))
			t_insert(out, s_format("= %.2f", critMulti * critChance))
		end
		if (dotChance > 0 and critChance > 0) and (dotMulti ~= critMulti)then
			t_insert(out, localisation:Text("calc.breakdown.crit_dot.line_7"))
			t_insert(out, s_format("%.2f + %.2f", dotMulti * dotChance, critMulti * critChance))
			t_insert(out, s_format("= %.2f", combined))
		end
		return out
	end

	function breakdown.leech(instant, instantRate, instances, pool, rate, max, dur, instantLeechProportion, hitRate)
		local out = { }
		if actor.mainSkill.skillData.showAverage then
			if instant > 0 then
				if instantLeechProportion ~= 1 then
					t_insert(out, localisation:Text("calc.breakdown.leech.line", { instant = instant, value = instantLeechProportion * 100, value_2 = dur * pool * data.misc.LeechRateBase / (1-instantLeechProportion) }))
				else
					t_insert(out, localisation:Text("calc.breakdown.leech.line_2", { instant = instant }))
				end
			end
			if instances > 0 then
				t_insert(out, localisation:Text("calc.breakdown.leech.line_3"))
				t_insert(out, localisation:Text("calc.breakdown.leech.line_4", { pool = pool }))
				t_insert(out, localisation:Text("calc.breakdown.leech.line_5", { leech_rate_base = data.misc.LeechRateBase, value = 100 * data.misc.LeechRateBase }))
				local rateMod = calcLib.mod(modDB, skillCfg, rate)
				if rateMod ~= 1 then
					t_insert(out, localisation:Text("calc.breakdown.leech.line_6", { rate_mod = rateMod }))
				end
				t_insert(out, localisation:Text("calc.breakdown.leech.line_7", { dur = dur }))
				t_insert(out, s_format("= %.1f", pool * data.misc.LeechRateBase * rateMod * dur))
			end
		else
			if instantRate > 0 then
				if instantLeechProportion ~= 1 then
					t_insert(out, localisation:Text("calc.breakdown.leech.line", { instant = instant, value = instantLeechProportion * 100, value_2 = dur * pool * data.misc.LeechRateBase / (1-instantLeechProportion) }))
				else
					t_insert(out, localisation:Text("calc.breakdown.leech.line_2", { instant = instant }))
				end
				t_insert(out, localisation:Text("calc.breakdown.leech.line_8", { instant_rate = instantRate, instant = instant, hit_rate = hitRate }))
			end
			if instances > 0 then
				t_insert(out, localisation:Text("calc.breakdown.leech.line_9"))
				t_insert(out, localisation:Text("calc.breakdown.leech.line_4", { pool = pool }))
				t_insert(out, localisation:Text("calc.breakdown.leech.line_5", { leech_rate_base = data.misc.LeechRateBase, value = 100 * data.misc.LeechRateBase }))
				local rateMod = calcLib.mod(modDB, skillCfg, rate)
				if rateMod ~= 1 then
					t_insert(out, localisation:Text("calc.breakdown.leech.line_6", { rate_mod = rateMod }))
				end
				t_insert(out, localisation:Text("calc.breakdown.leech.line_10", { value = pool * data.misc.LeechRateBase * rateMod }))
				t_insert(out, localisation:Text("calc.breakdown.leech.line_11"))
				t_insert(out, s_format("%.1f", pool * data.misc.LeechRateBase * rateMod))
				t_insert(out, localisation:Text("calc.breakdown.leech.line_12", { instances = instances }))
				local total = pool * data.misc.LeechRateBase * rateMod * instances
				t_insert(out, localisation:Text("calc.breakdown.leech.line_13", { total = total }))
				if total <= max then
					t_insert(out, localisation:Text("calc.breakdown.leech.line_14", { dur = dur }))
				end
				t_insert(out, localisation:Text("calc.breakdown.leech.line_15", { max = max }))
				if total > max then
					t_insert(out, localisation:Text("calc.breakdown.leech.line_16", { value = dur / total * max }))
				end
			end
		end
		return out
	end

	return breakdown
end
