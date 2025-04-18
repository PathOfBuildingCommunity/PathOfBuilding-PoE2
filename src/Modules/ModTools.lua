-- Path of Building
--
-- Module: Mod Tools
-- Various functions for dealing with modifiers
--
local pairs = pairs
local ipairs = ipairs
local select = select
local type = type
local t_insert = table.insert
local t_sort = table.sort
local m_floor = math.floor
local m_abs = math.abs
local s_format = string.format
local band = AND64 -- bit.band
local bor = OR64 -- bit.bor

modLib = { }

function modLib.createMod(modName, modType, modVal, ...)
	local flags = 0
	local keywordFlags = 0
	local tagStart = 1
	local source
	if select('#', ...) >= 1 and type(select(1, ...)) == "string" then
		source = select(1, ...)
		tagStart = 2
	end
	if select('#', ...) >= 2 and type(select(2, ...)) == "number" then
		flags = select(2, ...)
		tagStart = 3
	end
	if select('#', ...) >= 3 and type(select(3, ...)) == "number" then
		keywordFlags = select(3, ...)
		tagStart = 4
	end
	return {
		name = modName,
		type = modType,
		value = modVal,
		flags = flags,
		keywordFlags = keywordFlags,
		source = source,
		select(tagStart, ...)
	}
end

modLib.parseMod, modLib.parseModCache = LoadModule("Modules/ModParser", launch)

function modLib.parseTags(line)
	if not line or line == "-" then
		return {}
	end
	local Tags = {}
	for tagGroup in line:gmatch("([^,]*),?") do
		if tagGroup ~= "" then
			local tagSet = {}
			for tag in tagGroup:gmatch("([^/]*)/?") do
				if tag ~= "" then
					local tagName, tagValue = tag:match("^(%a+)=(.+)")
					if tagName then
						-- list of all the tag parts that should be numbers
						if ({threshold = true})[tagName] then
							tagValue = tonumber(tagValue)
						end
						tagSet[tagName] = tagValue == "true" and true or tagValue
					else
						ConPrintf("Error tag invalid: "..tag)
					end
				end
			end
			t_insert(Tags, tagSet)
		end
	end
	return Tags
end

function modLib.parseFormattedSourceMod(line)
	local modStrings = {}
	for line2 in line:gmatch("([^|]*)|?") do
		t_insert(modStrings, line2)
	end
	if #modStrings >= 4 then
		local mod = {
			value = (modStrings[1] == "true" and true) or tonumber(modStrings[1]) or 0,
			source = modStrings[2],
			name = modStrings[3],
			type = modStrings[4],
			flags = ModFlag[modStrings[5]] or 0,
			keywordFlags = KeywordFlag[modStrings[6]] or 0,
		}
		for _, tag in ipairs(modLib.parseTags(modStrings[7])) do
			t_insert(mod, tag)
		end
		return mod
	end
end

function modLib.compareModParams(modA, modB)
	if modA.name ~= modB.name or modA.type ~= modB.type or modA.flags ~= modB.flags or modA.keywordFlags ~= modB.keywordFlags or #modA ~= #modB then
		return false
	end
	for i, tag in ipairs(modA) do
		if tag.type ~= modB[i].type then
			return false
		end
		if modLib.formatTag(tag) ~= modLib.formatTag(modB[i]) then
			return false
		end
	end
	return true
end

function modLib.formatFlags(flags, src)
	local flagNames = { }
	for name, val in pairs(src) do
		if band(flags, val) == val then
			t_insert(flagNames, name)
		end
	end
	t_sort(flagNames)
	local ret
	for i, name in ipairs(flagNames) do
		ret = (ret and ret.."," or "") .. name
	end
	return ret or "-"
end

function modLib.formatTag(tag)
	local paramNames = { }
	local haveType
	for name, val in pairs(tag) do
		if name == "type" then
			haveType = true
		else
			t_insert(paramNames, name)
		end
	end
	t_sort(paramNames)
	if haveType then
		t_insert(paramNames, 1, "type")
	end
	local str = ""
	for i, paramName in ipairs(paramNames) do
		if i > 1 then
			str = str .. "/"
		end
		local val = tag[paramName]
		if type(val) == "table" then
			if val[1] then
				if type(val[1]) == "table" then
					val = modLib.formatTags(val)
				else
					val = table.concat(val, ",")
				end
			else
				val = modLib.formatTag(tag[paramName])
			end
			val = "{"..val.."}"
		end
		str = str .. s_format("%s=%s", paramName, tostring(val))
	end
	return str
end

function modLib.formatTags(tagList)
	local ret
	for _, tag in ipairs(tagList) do
		ret = (ret and ret.."," or "") .. modLib.formatTag(tag)
	end
	return ret or "-"
end

function modLib.formatValue(value)
	if type(value) ~= "table" then
		return tostring(value)
	end
	local paramNames = { }
	local haveType
	for name, val in pairs(value) do
		if name == "type" then
			haveType = true
		else
			t_insert(paramNames, name)
		end
	end

	t_sort(paramNames, function (a, b)
		if type(a) == "number" and type(b) == "number" then
			return a < b
		end
		if type(a) == "number" then
			return true
		end
		if type(b) == "number" then
			return false
		end
		return a < b
	end)

	if haveType then
		t_insert(paramNames, 1, "type")
	end
	local ret = ""
	for i, paramName in ipairs(paramNames) do
		if i > 1 then
			ret = ret .. "/"
		end
		if paramName == "mod" then
			ret = ret .. s_format("%s=[%s]", paramName, modLib.formatMod(value[paramName]))
		else
			ret = ret .. s_format("%s=%s", paramName, modLib.formatValue(value[paramName]))
		end
	end
	return "{"..ret.."}"
end

function modLib.formatModParams(mod)
	return s_format("%s|%s|%s|%s|%s", mod.name, mod.type, modLib.formatFlags(mod.flags, ModFlag), modLib.formatFlags(mod.keywordFlags, KeywordFlag), modLib.formatTags(mod))
end

function modLib.formatMod(mod)
	return modLib.formatValue(mod.value) .. " = " .. modLib.formatModParams(mod)
end

function modLib.formatSourceMod(mod)
    return s_format("%s|%s|%s", modLib.formatValue(mod.value), mod.source, modLib.formatModParams(mod))
end

function modLib.setSource(mod, source)
	mod.source = source
	if type(mod.value) == "table" and mod.value.mod then
		mod.value.mod.source = source
	end
	return mod
end