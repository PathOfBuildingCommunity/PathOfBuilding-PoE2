local nk = { }

local statDescriptor
local statDescriptors = { }
function loadStatFile(fileName)
	if statDescriptors[fileName] then
		statDescriptor = statDescriptors[fileName]
		return
	end
	statDescriptor = { }
	statDescriptors[fileName] = statDescriptor 
	local curLang
	local curDescriptor = { }
	local order = 1
	local function processLine(line)
		local include = line:match('include "Metadata/StatDescriptions/(.+)"$')
		if include then
			local text = convertUTF16to8(getFile("Metadata/StatDescriptions/"..include))
			for line in text:gmatch("[^\r\n]+") do
				processLine(line)
			end
			return
		end
		local noDesc = line:match("no_description ([%w_%+%-%%]+)")
		if noDesc then
			statDescriptor[noDesc] = { order = 0 }
		elseif line:match("handed_description") or (line:match("description") and not line:match("_description")) then	
			local name = line:match("description ([%w_]+)")
			curLang = { }
			curDescriptor = { curLang, order = order, name = name }
			order = order + 1
		elseif not curDescriptor.stats then
			local stats = line:match("%d+%s+([%w_%+%-%% ]+)")
			if stats then
				curDescriptor.stats = { }
				for stat in stats:gmatch("[%w_%+%-%%]+") do
					table.insert(curDescriptor.stats, stat)
					statDescriptor[stat] = curDescriptor
				end
			end
		else
			local langName = line:match('lang "(.+)"')
			if langName then
				curLang = { }
				--curDescriptor.lang[langName] = curLang
			elseif not line:match('table_only') then
				local statLimits, text, special = line:match('([%d%-#| !]+)%s*"(.-)"%s*(.*)')
				if statLimits then
					local desc = { text = escapeGGGString(text):gsub("\\([^nb])", "\\n%1"), limit = { } }
					for statLimit in statLimits:gmatch("[!%d%-#|]+") do
						local limit = { }
						
						if statLimit == "#" then
							limit[1] = "#"
							limit[2] = "#"
						elseif statLimit:match("^%-?%d+$") then
							limit[1] = tonumber(statLimit)
							limit[2] = tonumber(statLimit)
						else
							local negate = statLimit:match("^!(-?%d+)$")
							if negate then
								limit[1] = "!"
								limit[2] = tonumber(negate)
							else
								limit[1], limit[2] = statLimit:match("([%d%-#]+)|([%d%-#]+)")
								limit[1] = tonumber(limit[1]) or limit[1]
								limit[2] = tonumber(limit[2]) or limit[2]
							end
						end
						table.insert(desc.limit, limit)
					end
					for k, v in special:gmatch("([%w%%_]+) (%d+)") do
						table.insert(desc, {
							k = k,
							v = tonumber(v) or v,
						})
						nk[k] = v
					end
					if special:match("canonical_line") then
						table.insert(desc, {
							k = "canonical_line",
							v = true,
						})
						nk["canonical_line"] = true
					end
					table.insert(curLang, desc)
				end
			end
		end
	end
	local text = convertUTF16to8(getFile("Metadata/StatDescriptions/"..fileName))
	for line in text:gmatch("[^\r\n]+") do
		processLine(line)
	end
	print(fileName.. " loaded. ("..order.." stats)")
end

for k, v in pairs(nk) do
	print("'"..k.."' = '"..v.."'")
end

local function matchLimit(lang, val)
	for _, desc in ipairs(lang) do
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

function describeModTags(modTags)
	if not modTags then
		return ""
	end

	local tagsDat = dat("Tags")
	local modTagsText = ""
	for i=1,#modTags do
		local curModTagIndex = modTags[i]._rowIndex
		if #modTagsText > 0 then
			modTagsText = modTagsText..', '
		end
		modTagsText = modTagsText..'"'..tagsDat:ReadCellText(curModTagIndex, 1)..'"'
	end
	return modTagsText
end

function describeStats(stats)
	local out = { }
	local orders = { }
	local descriptors = { }
	local missing = {false}
	for s, v in pairs(stats) do
		if s ~= "Type" and statDescriptor[s] and statDescriptor[s].stats then
			if (v.min ~= 0 or v.max ~= 0) then
				descriptors[statDescriptor[s]] = true
			end
		elseif s ~= "Type" then
			missing[1] = true
			missing[s] = v
		end
	end
	local descOrdered = { }
	for descriptor in pairs(descriptors) do
		table.insert(descOrdered, descriptor)
	end
	table.sort(descOrdered, function(a, b) return a.order < b.order end)
	for _, descriptor in ipairs(descOrdered) do
		local val = { }
		for i, s in ipairs(descriptor.stats) do
			val[i] = stats[s] or { min = 0, max = 0 }
			val[i].fmt = "d"
		end
		local desc = matchLimit(descriptor[1], val)

		-- Hack to handle ranges starting or ending at 0 where no descriptor is defined for 0
		-- Attempt to adapt existing ranges
		if not desc then
			for _, s in ipairs(val) do
				if s.min == 0 and s.max > 0 then
					s.min = 1
					s.minZ = true
				elseif s.min < 0 and s.max == 0 then
					s.max = -1
					s.maxZ = true
				end
			end
			desc = matchLimit(descriptor[1], val)
			for _, s in ipairs(val) do
				if s.minZ then s.min = 0 end
				if s.maxZ then s.max = 0 end
			end
		end

		if desc then
			for _, spec in ipairs(desc) do
				if spec.k == "negate" then
					val[spec.v].max, val[spec.v].min = -val[spec.v].min, -val[spec.v].max
				elseif spec.k == "invert_chance" then
					val[spec.v].max, val[spec.v].min = 100 - val[spec.v].min, 100 - val[spec.v].max
				elseif spec.k == "negate_and_double" then
					val[spec.v].max, val[spec.v].min = -2 * val[spec.v].min, -2 * val[spec.v].max
				elseif spec.k == "passive_hash" then
					-- handled elsewhere
					if val[spec.v].min < 0 then
						val[spec.v].min = val[spec.v].min + 65536
						val[spec.v].max = val[spec.v].max + 65536
					end
				elseif spec.k == "divide_by_two_0dp" then
					val[spec.v].min = round(val[spec.v].min / 2)
					val[spec.v].max = round(val[spec.v].max / 2)
				elseif spec.k == "divide_by_three" then
					val[spec.v].min = val[spec.v].min / 3
					val[spec.v].max = val[spec.v].min / 3
					val[spec.v].fmt = "g"
				elseif spec.k == "divide_by_four" then
					val[spec.v].min = val[spec.v].min / 4
					val[spec.v].max = val[spec.v].min / 4
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
				elseif spec.k == "per_minute_to_per_second" then
					val[spec.v].min = val[spec.v].min / 60
					val[spec.v].max = val[spec.v].max / 60
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
					val[spec.v].min = -val[spec.v].min * 4
					val[spec.v].max = -val[spec.v].max * 4
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
			local statDesc = desc.text:gsub("{(%d)}", function(n) 
				local v = val[tonumber(n)+1]
				if v.min == v.max then
					return string.format("%"..v.fmt, v.min)
				else
					return string.format("(%"..v.fmt.."-%"..v.fmt..")", v.min, v.max)
				end
			end):gsub("{}", function() 
				local v = val[1]
				if v.min == v.max then
					return string.format("%"..v.fmt, v.min)
				else
					return string.format("(%"..v.fmt.."-%"..v.fmt..")", v.min, v.max)
				end
			end):gsub("{(%d?):(%+?)d?}", function(n, fmt)
				-- Most forms are {0:1}, however Chain Hook enchantment is {0:}
				-- the above pattern supports both cases.
				n = n ~= "" and n or "0"
				local v = val[tonumber(n)+1]
				if v.min == v.max then
					return string.format("%"..fmt..v.fmt, v.min)
				elseif fmt == "+" then
					if v.max < 0 then
						return string.format("-(%" .. v.fmt .. "-%" .. v.fmt .. ")", -v.min, -v.max)
					else
						return string.format("+(%" .. v.fmt .. "-%" .. v.fmt .. ")", v.min, v.max)
					end
				else
					return string.format("(%"..fmt..v.fmt.."-%"..fmt..v.fmt..")", v.min, v.max)
				end
			end):gsub("%%%%","%%")
			local order = descriptor.order
			for line in (statDesc.."\\n"):gmatch("([^\\]+)\\n") do
				table.insert(out, line)
				table.insert(orders, order)
				order = order + 0.1
			end
		end
	end
	return out, orders, missing
end

function describeMod(mod)
	local stats = { }
	for i = 1, 6 do
		if mod["Stat"..i] then
			stats[mod["Stat"..i].Id] = { min = mod["Stat"..i.."Value"][1], max = mod["Stat"..i.."Value"][2] }
		end
	end
	if mod.Type then
		stats.Type = mod.Type
	end
	local out, orders, missing = describeStats(stats)
	out.modTags = describeModTags(mod.ImplicitTags)
	return out, orders, missing
end

function describeScalability(fileName)
	local out = { }
	local stats = dat("stats")
	for stat, statDescription in pairs(statDescriptors[fileName]) do
		local scalability = { }
		if statDescription.stats then
			for i, stat in ipairs(statDescription.stats) do
				table.insert(scalability, stats:GetRow("Id", stat).IsScalable)
			end
			for _, wordings in ipairs(statDescription[1]) do
				local wordingFormats = {}
				local inOrderScalability = { }
				for _, format in ipairs(wordings) do
					if type(format.v) == "number" then
						if wordingFormats[tonumber(format.v)] then
							table.insert(wordingFormats[tonumber(format.v)],  format.k)
						else
							wordingFormats[tonumber(format.v)] = { format.k }
						end
					end
				end
				local strippedLine = wordings.text:gsub("[%+%-]?(%b{})", function(num)
					local statNum = (num:match("%d") or 0) + 1
					table.insert(inOrderScalability, { isScalable = scalability[statNum], formats = wordingFormats[statNum] })
					return "#"
				end)
				if out[strippedLine] then -- we want to use the format with the least oddities in it. If their are less formats then that will be used instead.
					for j, priorScalability in ipairs(out[strippedLine]) do
						if (priorScalability.formats and #priorScalability.formats or 0) > (wordingFormats[j] and #wordingFormats[j] or 0) then 
							out[strippedLine][j] = inOrderScalability[j]
						end
					end
				else -- no present
					out[strippedLine] = inOrderScalability
				end
			end
		end
	end
	return out
end
