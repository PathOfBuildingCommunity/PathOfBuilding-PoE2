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
			t_insert(out, chain.label)
		end
		if base ~= nil then
			t_insert(out, s_format(unpack(chain.base)))
		end
		if base ~= 0 then
			for _, mult in ipairs(chain) do
				if mult[2] and mult[2] ~= 1 then
					multiplier = multiplier * mult[2]
					t_insert(out, "x "..s_format(unpack(mult)))
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
					out[1] = s_format("(%g + %g) ^8(base)", extraBase, base)
				else
					out[1] = s_format("%g ^8(base)", base + extraBase)
				end
				if inc ~= 0 then
					t_insert(out, s_format("x %.2f ^8(increased/reduced)", 1 + inc/100))
				end
				if more ~= 1 then
					t_insert(out, s_format("x %.2f ^8(more/less)", more))
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
				s_format("%.2f ^8(increased/reduced)", 1 + inc/100),
				s_format("x %.2f ^8(more/less)", more),
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
			source = source,
			sourceName = sourceName,
			item = not sourceName and actor.itemList[source],
		})
	end

	function breakdown.area(base, areaMod, total, incBreakpoint, moreBreakpoint, redBreakpoint, lessBreakpoint, label, radiusMod)
		local out = {}
		t_insert(out, label)
		if base ~= total then
			t_insert(out, s_format("%.1fm ^8(base radius)", base / 10))
			t_insert(out, s_format("x %.2f ^8(square root of area of effect modifier)", m_floor(100 * m_sqrt(areaMod)) / 100))
			if radiusMod and radiusMod ~= 1 then
				t_insert(out, s_format("x %.2f ^8(final radius modifier)", radiusMod))
			end
			t_insert(out, s_format("= %.1fm", total / 10))
		end
		if incBreakpoint and moreBreakpoint and redBreakpoint and lessBreakpoint then
			t_insert(out, s_format("^8Next 0.1m breakpoint: %d%% increased AoE / a %d%% more AoE multiplier", incBreakpoint, moreBreakpoint))
			t_insert(out, s_format("^8Previous 0.1m breakpoint: %d%% reduced AoE / a %d%% less AoE multiplier", redBreakpoint, lessBreakpoint))
		end
		out.radius = total
		return out
	end

	function breakdown.effMult(damageType, resist, pen, taken, mult, takenMore, sourceRes, useRes, invertChance, minPen, effectiveResist, normalHitResist, invertedHitResist)
		local out = { }
		local resistForm = (damageType == "Physical") and "physical damage reduction" or "resistance"
		local resistLabel = resistForm
		minPen = minPen or 0
		local calcPenResist = function(resist)
			return resist > minPen and m_max(resist - pen, minPen) or resist
		end
		effectiveResist = effectiveResist or calcPenResist(resist)

		if sourceRes and sourceRes ~= damageType then
			t_insert(out, s_format("Enemy %s: %d%% ^8(%s)", resistLabel, resist, sourceRes))
		elseif resist ~= 0 then
			t_insert(out, s_format("Enemy %s: %d%%", resistLabel, resist))
		end
		if invertChance and invertChance ~= 0 and useRes then
			normalHitResist = normalHitResist or calcPenResist(resist)
			invertedHitResist = invertedHitResist or calcPenResist(-resist)
			t_insert(out, "Effective resistance:")
			t_insert(out, s_format("%g%% ^8(non-inverted hit after penetration)", normalHitResist))
			t_insert(out, s_format("%g%% ^8(inverted hit after penetration)", invertedHitResist))
			t_insert(out, s_format("= %g%% ^8(weighted average from %.0f%% inversion chance)", effectiveResist, invertChance * 100))
		elseif pen ~= 0 or not useRes then
			t_insert(out, "Effective resistance:")
			t_insert(out, s_format("%d%% ^8(resistance)", resist))
			if pen < 0 then
				t_insert(out, s_format("+ %d%% ^8(penetration)", -pen))
			elseif pen > 0 then
				t_insert(out, s_format("- %d%% ^8(penetration)", pen))
			end
			if not useRes then
				t_insert(out, s_format("x %d%% ^8(resistance ignored)", 0))
				t_insert(out, s_format("= %d%%", (0)))
			elseif resist <= minPen then
				t_insert(out, s_format("= %d%% ^8(negative resistance unaffected by penetration)", resist))
			elseif (resist - pen) < minPen then
				t_insert(out, s_format("= %d%% ^8(penetration cannot bring resistances below %d%%)", m_max(resist - pen, minPen), minPen))
			else
				t_insert(out, s_format("= %d%%", (resist - pen)))
			end
		end
		if useRes then
			breakdown.multiChain(out, {
				label = "Effective DPS modifier:",
				{ "%.2f ^8(%s)", 1 - effectiveResist / 100, resistForm },
				{ "%.2f ^8(increased/reduced damage taken)", 1 + taken / 100 },
				{ "%.2f ^8(more/less damage taken)", takenMore },
				total = s_format("= %.3f", mult),
			})
		else
			t_insert(out, "Effective DPS modifier:")
			t_insert(out, s_format("= %.3f ^8(increased/reduced damage taken)", mult))
		end
		return out
	end

	function breakdown.dot(out, baseVal, inc, more, mult, rate, aura, effMult, total)
		breakdown.multiChain(out, {
			base = { "%.1f ^8(base damage per second)", baseVal },
			{ "%.2f ^8(increased/reduced)", 1 + inc/100 },
			{ "%.2f ^8(more/less)", more },
			{ "%.2f ^8(multiplier)", 1 + (mult or 0)/100 },
			{ "%.2f ^8(rate modifier)", rate },
			{ "%.3f ^8(aura effect modifier)", aura },
			{ "%.3f ^8(effective DPS modifier)", effMult },
			total = s_format("= %.1f ^8per second", total),
		})
	end

	function breakdown.critDot(dotMulti, critMulti, dotChance, critChance)
		local combined = (dotMulti * dotChance) + (critMulti * critChance)
		local out = { }
		if dotChance > 0 then
			t_insert(out, s_format("Contribution from Non-crits:"))
			t_insert(out, s_format("%.2f ^8(dot multiplier for non-crits)", dotMulti))
			t_insert(out, s_format("x %.4f ^8(portion of instances created by non-crits)", dotChance))
			t_insert(out, s_format("= %.2f", dotMulti * dotChance))
		end
		if critChance > 0 then
			t_insert(out, s_format("Contribution from Crits:"))
			t_insert(out, s_format("%.2f ^8(dot multiplier for crits)", critMulti))
			t_insert(out, s_format("x %.4f ^8(portion of instances created by crits)", critChance))
			t_insert(out, s_format("= %.2f", critMulti * critChance))
		end
		if (dotChance > 0 and critChance > 0) and (dotMulti ~= critMulti)then
			t_insert(out, s_format("Effective DoT Multiplier:"))
			t_insert(out, s_format("%.2f + %.2f", dotMulti * dotChance, critMulti * critChance))
			t_insert(out, s_format("= %.2f", combined))
		end
		return out
	end

	function breakdown.leech(output, resource, hitRate)
		local out = { }
		local prefix = resource.."Leech"
		local instant = output[prefix.."Instant"]
		local resistance = output.EnemyLeechResistance
		local resistMult = 1 - resistance / 100
		local resistText = resistance > 0 and s_format(" ^8(after %.2f%% enemy leech resistance)", resistance) or ""
		if actor.mainSkill.skillData.showAverage then
			local overTime = output[prefix.."PerHit"] - instant
			t_insert(out, "Leech per hit:")
			if overTime > 0 then
				t_insert(out, s_format("%.1f ^8(recovered over %.2fs)", overTime, output[prefix.."Duration"]))
			end
			if instant > 0 then
				t_insert(out, s_format("%s%.1f ^8(instant)", overTime > 0 and "+ " or "", instant))
			end
			t_insert(out, s_format("= %.1f%s", output[prefix.."PerHit"], resistText))
			return out
		end
		local instances = output[prefix.."Instances"]
		local instanceAmount = output[prefix.."InstanceAmount"] / resistMult
		local hasOverTime = instances > 0 and instanceAmount > 0
		if hasOverTime then
			t_insert(out, "Overlapping leech instances:")
			t_insert(out, s_format("%.2f ^8(hits per second)", hitRate))
			t_insert(out, s_format("x %.2fs ^8(duration)", output[prefix.."Duration"]))
			t_insert(out, s_format("= %.2f", instances))
			local critActive = output[prefix.."CritActive"] / 100
			if instances > 1 then
				t_insert(out, s_format("Only the strongest of %.2f instances recovers:", instances))
				t_insert(out, s_format("%.1f%% ^8(average roll, %.2f / (%.2f + 1))", output[prefix.."RollAverage"], instances, instances))
				if critActive > 0 and critActive < 1 then
					local critShare = 1 - (1 - critActive) ^ (1 / instances)
					t_insert(out, s_format("%.1f%% ^8(chance of a critical hit, 1 - (1 - %.1f%%) ^ %.2f)", critActive * 100, critShare * 100, instances))
				end
			end
			t_insert(out, instances > 1 and "Leech of the strongest instance:" or "Leech per instance:")
			local cap = data.gameConstants["EffectiveMaxDamageForLeech"]
			local function insertHit(op, label, hit, amount, chance)
				local damage = m_min(hit, cap)
				local capped = hit > cap and s_format(" capped from %.0f", hit) or ""
				local chanceText = chance < 1 and s_format(" x %.1f%%", chance * 100) or ""
				t_insert(out, s_format("%s%.0f x %.2f%%%s ^8(%s hit%s x leech%s)", op, damage, amount / resistMult / damage * 100, chanceText, label, capped, chance < 1 and " x chance" or ""))
			end
			if critActive < 1 then
				insertHit("", "non-critical", output[prefix.."NonCritHit"], output[prefix.."NonCritInstanceAmount"], 1 - critActive)
			end
			if critActive > 0 then
				insertHit(critActive < 1 and "+ " or "", "critical", output[prefix.."CritHit"], output[prefix.."CritInstanceAmount"], critActive)
			end
			t_insert(out, s_format("= %.1f", instanceAmount))
		end
		t_insert(out, "Leech per second:")
		if hasOverTime then
			t_insert(out, s_format("%.1f ^8(leech of the instance)", instanceAmount))
			if resistance > 0 then
				t_insert(out, s_format("x %.4f ^8(%.2f%% enemy leech resistance)", resistMult, resistance))
			end
			t_insert(out, s_format("x %.2f ^8(leech speed%s)", output[prefix.."Speed"], instant > 0 and ", the instant part shortens the duration instead" or ""))
			if instances < 1 then
				t_insert(out, s_format("x %.2f ^8(portion of time leeching)", instances))
			end
		end
		if instant > 0 then
			t_insert(out, s_format("%s%.1f x %.2f ^8(instant leech per hit x hits per second)", hasOverTime and "+ " or "", instant, hitRate))
		end
		t_insert(out, s_format("= %.1f ^8per second", output[prefix.."Rate"]))
		return out
	end

	return breakdown
end
