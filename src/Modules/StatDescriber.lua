-- Path of Building
--
-- Module: Stat Describer
-- Manages stat description files, and provides stat descriptions
--
local pairs = pairs
local ipairs = ipairs
local t_insert = table.insert
local s_format = string.format

local scopes = { }

local M = {}
local function getScope(scopeName)
	if not scopes[scopeName] then
		local scope = nil
		-- Allow lowercase "specific_skill_stat_descriptions/<name>" by stripping the prefix (Linux is case-sensitive).
		local normalizedScopeName = scopeName:gsub("^specific_skill_stat_descriptions/", "")

		local file = io.open("Data/StatDescriptions/Specific_Skill_Stat_Descriptions/"..normalizedScopeName..".lua", 'rb')
		if file then
			file:close()
			scope = LoadModule("Data/StatDescriptions/Specific_Skill_Stat_Descriptions/"..normalizedScopeName)
		else
			scope = LoadModule("Data/StatDescriptions/"..normalizedScopeName)
		end 
		scope.name = scopeName
		if scope.parent then
			local parentScope = getScope(scope.parent)
			scope.scopeList = copyTable(parentScope.scopeList, true)
		else
			scope.scopeList = { }
		end
		t_insert(scope.scopeList, 1, scope)
		scopes[scopeName] = scope
		return scope
	else
		return scopes[scopeName]
	end
end

local function matchLimit(lang, val, quality)
	for _, desc in ipairs(lang) do
		if quality or not desc.gem_quality then -- Skip gem_quality lines for regular mods
			local match = true
			for i, limit in ipairs(desc.limit) do
				if limit[1] == "!" then
					if val[i].min == limit[2] then
						match = false
						break
					end
				elseif (limit[2] ~= "#" and val[i].min > limit[2]) or (limit[1] ~= "#" and val[i].min < limit[1]) then
					match = false
					break
				end
			end
			if match then
				return desc
			end
		end
	end
end

-- applies stat description special functions to stat values. for example percentage-based stats usually have divide_by_one_hundred which turns 200 into 2
---@param val table[] Array of stat values
---@param spec table The spec entry in the array part of the stat description
---@param skipNegation boolean? Whether to skip the negation. Useful when transforming stats for the trade site
function M.applySpecial(val, spec, skipNegation)
	if spec.k == "negate" and not skipNegation then
		val[spec.v].max, val[spec.v].min = -val[spec.v].min, -val[spec.v].max
	elseif spec.k == "invert_chance" then
		val[spec.v].max, val[spec.v].min = 100 - val[spec.v].min, 100 - val[spec.v].max
	elseif spec.k == "negate_and_double" then
		local mult = skipNegation and 2 or -2
		val[spec.v].max, val[spec.v].min = mult * val[spec.v].min, mult * val[spec.v].max
	elseif spec.k == "divide_by_two_0dp" then
		val[spec.v].min = round(val[spec.v].min / 2)
		val[spec.v].max = round(val[spec.v].max / 2)
	elseif spec.k == "divide_by_three" then
		val[spec.v].min = val[spec.v].min / 3
		val[spec.v].max = val[spec.v].max / 3
		val[spec.v].fmt = "g"
	elseif spec.k == "divide_by_four" then
		val[spec.v].min = val[spec.v].min / 4
		val[spec.v].max = val[spec.v].max / 4
		val[spec.v].fmt = "g"
	elseif spec.k == "divide_by_five" then
		val[spec.v].min = val[spec.v].min / 5
		val[spec.v].max = val[spec.v].max / 5
		val[spec.v].fmt = "g"
	elseif spec.k == "divide_by_six" then
		val[spec.v].min = val[spec.v].min / 6
		val[spec.v].max = val[spec.v].max / 6
		val[spec.v].fmt = "g"
	elseif spec.k == "divide_by_ten_0dp" then
		val[spec.v].min = round(val[spec.v].min / 10)
		val[spec.v].max = round(val[spec.v].max / 10)
	elseif spec.k == "divide_by_ten_1dp" or spec.k == "divide_by_ten_1dp_if_required" then
		val[spec.v].min = round(val[spec.v].min / 10, 1)
		val[spec.v].max = round(val[spec.v].max / 10, 1)
		val[spec.v].fmt = "g"
	elseif spec.k == "divide_by_twelve" then
		val[spec.v].min = val[spec.v].min / 12
		val[spec.v].max = val[spec.v].max / 12
		val[spec.v].fmt = "g"
	elseif spec.k == "divide_by_fifteen_0dp" then
		val[spec.v].min = round(val[spec.v].min / 15)
		val[spec.v].max = round(val[spec.v].max / 15)
	elseif spec.k == "divide_by_twenty" then
		val[spec.v].min = val[spec.v].min / 20
		val[spec.v].max = val[spec.v].max / 20
		val[spec.v].fmt = "g"
	elseif spec.k == "divide_by_twenty_then_double_0dp" then
		val[spec.v].min = round(val[spec.v].min / 20) * 2
		val[spec.v].max = round(val[spec.v].max / 20) * 2
	elseif spec.k == "divide_by_fifty" then
		val[spec.v].min = val[spec.v].min / 50
		val[spec.v].max = val[spec.v].max / 50
		val[spec.v].fmt = "g"
	elseif spec.k == "divide_by_one_hundred" then
		val[spec.v].min = val[spec.v].min / 100
		val[spec.v].max = val[spec.v].max / 100
		val[spec.v].fmt = "g"
	elseif spec.k == "divide_by_one_hundred_0dp" then
		val[spec.v].min = round(val[spec.v].min / 100)
		val[spec.v].max = round(val[spec.v].max / 100)
		val[spec.v].fmt = "g"
	elseif spec.k == "divide_by_one_hundred_1dp" then
		val[spec.v].min = round(val[spec.v].min / 100, 1)
		val[spec.v].max = round(val[spec.v].max / 100, 1)
		val[spec.v].fmt = "g"
	elseif spec.k == "divide_by_one_hundred_2dp_if_required" or spec.k == "divide_by_one_hundred_2dp" then
		val[spec.v].min = round(val[spec.v].min / 100, 2)
		val[spec.v].max = round(val[spec.v].max / 100, 2)
		val[spec.v].fmt = "g"
	elseif spec.k == "divide_by_one_hundred_and_negate" then
		val[spec.v].min = -val[spec.v].min / 100
		val[spec.v].max = -val[spec.v].max / 100
		val[spec.v].fmt = "g"
	elseif spec.k == "divide_by_one_thousand" then
		val[spec.v].min = val[spec.v].min / 1000
		val[spec.v].max = val[spec.v].max / 1000
		val[spec.v].fmt = "g"
	elseif spec.k == "divide_by_ten_thousand_1dp" then
		val[spec.v].min = round(val[spec.v].min / 10000, 1)
		val[spec.v].max = round(val[spec.v].max / 10000, 1)
		val[spec.v].fmt = "g"
	elseif spec.k == "per_minute_to_per_second" then
		val[spec.v].min = floor(val[spec.v].min / 60, 1)
		val[spec.v].max = floor(val[spec.v].max / 60, 1)
		val[spec.v].fmt = "g"
	elseif spec.k == "per_minute_to_per_second_0dp" then
		val[spec.v].min = round(val[spec.v].min / 60)
		val[spec.v].max = round(val[spec.v].max / 60)
	elseif spec.k == "per_minute_to_per_second_1dp" then
		val[spec.v].min = round(val[spec.v].min / 60, 1)
		val[spec.v].max = round(val[spec.v].max / 60, 1)
		val[spec.v].fmt = "g"
	elseif spec.k == "per_minute_to_per_second_2dp_if_required" or spec.k == "per_minute_to_per_second_2dp" then
		val[spec.v].min = round(val[spec.v].min / 60, 2)
		val[spec.v].max = round(val[spec.v].max / 60, 2)
		val[spec.v].fmt = "g"
	elseif spec.k == "milliseconds_to_seconds" then
		val[spec.v].min = val[spec.v].min / 1000
		val[spec.v].max = val[spec.v].max / 1000
		val[spec.v].fmt = "g"
	elseif spec.k == "milliseconds_to_seconds_halved" then
		val[spec.v].min = val[spec.v].min / 1000 / 2
		val[spec.v].max = val[spec.v].max / 1000 / 2
		val[spec.v].fmt = "g"
	elseif spec.k == "milliseconds_to_seconds_0dp" then
		val[spec.v].min = round(val[spec.v].min / 1000)
		val[spec.v].max = round(val[spec.v].max / 1000)
	elseif spec.k == "milliseconds_to_seconds_1dp" then
		val[spec.v].min = round(val[spec.v].min / 1000, 1)
		val[spec.v].max = round(val[spec.v].max / 1000, 1)
		val[spec.v].fmt = "g"
	elseif spec.k == "milliseconds_to_seconds_2dp" or spec.k == "milliseconds_to_seconds_2dp_if_required" then
		val[spec.v].min = round(val[spec.v].min / 1000, 2)
		val[spec.v].max = round(val[spec.v].max / 1000, 2)
		val[spec.v].fmt = "g"									
	elseif spec.k == "deciseconds_to_seconds" then
		val[spec.v].min = val[spec.v].min / 10
		val[spec.v].max = val[spec.v].max / 10
		val[spec.v].fmt = ".2f"
	elseif spec.k == "30%_of_value" then
		val[spec.v].min = val[spec.v].min * 0.3
		val[spec.v].max = val[spec.v].max * 0.3
	elseif spec.k == "60%_of_value" then
		val[spec.v].min = val[spec.v].min * 0.6
		val[spec.v].max = val[spec.v].max * 0.6
	elseif spec.k == "mod_value_to_item_class" then
		val[spec.v].min = ItemClasses[val[spec.v].min].Name
		val[spec.v].max = ItemClasses[val[spec.v].max].Name
		val[spec.v].fmt = "s"
	elseif spec.k == "one_hundred_divide_by_value" then
		val[spec.v].min = round(100 / val[spec.v].min, 2)
		val[spec.v].max = round(100 / val[spec.v].max, 2)
		val[spec.v].fmt = "g"
	elseif spec.k == "multiplicative_damage_modifier" then
		val[spec.v].min = 100 + val[spec.v].min
		val[spec.v].max = 100 + val[spec.v].max
	elseif spec.k == "multiplicative_permyriad_damage_modifier" then
		val[spec.v].min = 100 + (val[spec.v].min / 100)
		val[spec.v].max = 100 + (val[spec.v].max / 100)
		val[spec.v].fmt = "g"
	elseif spec.k == "times_one_point_five" then
		val[spec.v].min = val[spec.v].min * 1.5
		val[spec.v].max = val[spec.v].max * 1.5
	elseif spec.k == "double" then
		val[spec.v].min = val[spec.v].min * 2
		val[spec.v].max = val[spec.v].max * 2
	elseif spec.k == "multiply_by_four" then
		val[spec.v].min = val[spec.v].min * 4
		val[spec.v].max = val[spec.v].max * 4
	elseif spec.k == "multiply_by_four_and_negate" then
		local mult = skipNegation and 4 or -4
		val[spec.v].min = val[spec.v].min * mult
		val[spec.v].max = val[spec.v].max * mult
	elseif spec.k == "multiply_by_ten" then
		val[spec.v].min = val[spec.v].min * 10
		val[spec.v].max = val[spec.v].max * 10
	elseif spec.k == "times_twenty" then
		val[spec.v].min = val[spec.v].min * 20
		val[spec.v].max = val[spec.v].max * 20
	elseif spec.k == "multiply_by_one_hundred" then
		val[spec.v].min = val[spec.v].min * 100
		val[spec.v].max = val[spec.v].max * 100
	elseif spec.k == "plus_two_hundred" then
		val[spec.v].min = val[spec.v].min + 200
		val[spec.v].max = val[spec.v].max + 200
	elseif spec.k == "reminderstring" or spec.k == "canonical_line" or spec.k == "canonical_stat" then
	elseif spec.k then
		ConPrintf("Unknown description function: %s", spec.k)
	end
end

function M.describeStats(stats, scopeName, quality)
	local rootScope = getScope(scopeName)

	-- Figure out which descriptions we need, and identify them by the first stat that they describe
	local describeStats = { }
	for s, v in pairs(stats) do
		if (type(v) == "number" and v ~= 0) or (type(v) == "table" and (v.min ~= 0 or v.max ~= 0)) then	
			for depth, scope in ipairs(rootScope.scopeList) do
				if scope[s] then
					local descriptor = scope[scope[s]]
					if descriptor[1] then
						describeStats[descriptor.stats[1]] = { depth = depth, order = scope[s], description = scope[scope[s]] }
					end
					break
				end
			end
		end
	end

	-- Sort them by depth/order
	local descOrdered = { }
	for s, descriptor in pairs(describeStats) do
		t_insert(descOrdered, descriptor)
	end
	table.sort(descOrdered, function(a, b) if a.depth ~= b.depth then return a.depth > b.depth else return a.order < b.order end end)

	-- Describe the stats
	local out = { }
	local lineMap = { }
	local transformedStats = {}
	for _, descriptor in ipairs(descOrdered) do
		local val = { }
		local stat
		local statMap = {}
		for i, s in ipairs(descriptor.description.stats) do
			if stats[s] then
				if type(stats[s]) == "number" then
					val[i] = { min = stats[s], max = stats[s] }
				else
					val[i] = stats[s]
				end
				stat = s
				statMap[i] = s
			else
				val[i] = { min = 0, max = 0 }
			end
			val[i].fmt = "d"
		end
		local desc = matchLimit(descriptor.description[1], val, quality)
		if desc then
			for _, spec in ipairs(desc) do
				M.applySpecial(val, spec)
			end
			-- copy stats back so that we can return the transformed stats
			for i, statVal in ipairs(val) do
				local statName = statMap[i]
				if statName then
					transformedStats[statName] = statVal
				end
			end
			local statDesc = desc.text:gsub("{(%d)}", function(n) 
				local v = val[tonumber(n)+1]
				if v.min == v.max then
					return s_format("%"..v.fmt, v.min)
				else
					return s_format("(%"..v.fmt.."-%"..v.fmt..")", v.min, v.max)
				end
			end):gsub("{}", function() 
				local v = val[1]
				if v.min == v.max then
					return s_format("%"..v.fmt, v.min)
				else
					return s_format("(%"..v.fmt.."-%"..v.fmt..")", v.min, v.max)
				end
			end):gsub("{:%+?d}", function() 
				local v = val[1]
				if v.min == v.max then
					return s_format("%"..v.fmt, v.min)
				else
					return s_format("(%"..v.fmt.."-%"..v.fmt..")", v.min, v.max)
				end
			end):gsub("{(%d):(%+?)d}", function(n, fmt)
				local v = val[tonumber(n)+1]
				if v.min == v.max then
					return s_format("%"..fmt..v.fmt, v.min)
				elseif fmt == "+" then
					if v.max < 0 then
						return s_format("-(%d-%d)", -v.min, -v.max)
					else
						return s_format("+(%d-%d)", v.min, v.max)
					end
				else
					return s_format("(%"..fmt..v.fmt.."-%"..fmt..v.fmt..")", v.min, v.max)
				end
			end):gsub("%%%%","%%")
			for line in (statDesc.."\\n"):gmatch("([^\\]+)\\n") do
				t_insert(out, line)
				lineMap[line] = stat
			end
		end
	end
	return out, lineMap, transformedStats
end

return M
