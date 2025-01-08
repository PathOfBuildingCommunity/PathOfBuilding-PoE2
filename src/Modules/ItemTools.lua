-- Path of Building
--
-- Module: Item Tools
-- Various functions for dealing with items.
--
local t_insert = table.insert
local t_remove = table.remove
local m_min = math.min
local m_max = math.max
local m_floor = math.floor

itemLib = { }
-- Apply a value scalar to the first n of any numbers present
function itemLib.applyValueScalar(line, valueScalar, baseValueScalar, numbers, precision)
	if not (valueScalar and type(valueScalar) == "number") then
		valueScalar = 1
	end
	if valueScalar ~= 1 or (baseValueScalar and baseValueScalar ~= 1) then
		if precision then
			return line:gsub("(%d+%.?%d*)", function(num)
				local power = 10 ^ precision
				local numVal = tonumber(num)
				if baseValueScalar then
					numVal = round(numVal * baseValueScalar * power) / power
				end
				numVal = m_floor(numVal * valueScalar * power) / power
				return tostring(numVal)
			end, numbers)
		else
			return line:gsub("(%d+)([^%.])", function(num, suffix)
				local numVal = tonumber(num)
				if baseValueScalar then
					numVal = round(num * baseValueScalar)
				end
				numVal = m_floor(numVal * valueScalar + 0.001)
				return tostring(numVal)..suffix
			end, numbers)
		end
	end
	return line
end

local antonyms = {
	["increased"] = "reduced",
	["reduced"] = "increased",
	["more"] = "less",
	["less"] = "more",
}

local function antonymFunc(num, word)
	local antonym = antonyms[word]
	return antonym and (num.." "..antonym) or ("-"..num.." "..word)
end

-- Apply range value (0 to 1) to a modifier that has a range: "(x-x)" or "(x-x) to (x-x)"
function itemLib.applyRange(line, range, valueScalar, baseValueScalar)
	local precisionSame = true
	-- Create a line with ranges removed to check if the mod is a high precision mod.
	local testLine = not line:find("-", 1, true) and line or
		line:gsub("(%+?)%((%-?%d+%.?%d*)%-(%-?%d+%.?%d*)%)",
		function(plus, min, max)
			min = tonumber(min)
			local maxPrecision = min + range * (tonumber(max) - min)
			local minPrecision = m_floor(maxPrecision + 0.5)
			if minPrecision ~= maxPrecision then
				precisionSame = false
			end
			return (minPrecision < 0 and "" or plus) .. tostring(minPrecision)
		end)
		:gsub("%-(%d+%%) (%a+)", antonymFunc)

	if precisionSame and (not valueScalar or valueScalar == 1) and (not baseValueScalar or baseValueScalar == 1)then
		return testLine
	end

	local precision = nil
	local modList, extra = modLib.parseMod(testLine)
	if modList and not extra then
		for _, mod in pairs(modList) do
			local subMod = mod
			if type(mod.value) == "table" and mod.value.mod then
				subMod = mod.value.mod
			end
			if type(subMod.value) == "number" and data.highPrecisionMods[subMod.name] and data.highPrecisionMods[subMod.name][subMod.type] then
				precision = data.highPrecisionMods[subMod.name][subMod.type]
			end
		end
	end
	if not precision and line:match("(%d+%.%d*)") then
		precision = data.defaultHighPrecision
	end

	local numbers = 0
	line = line:gsub("(%+?)%((%-?%d+%.?%d*)%-(%-?%d+%.?%d*)%)",
		function(plus, min, max)
			numbers = numbers + 1
			local power = 10 ^ (precision or 0)
			local numVal = m_floor((tonumber(min) + range * (tonumber(max) - tonumber(min))) * power + 0.5) / power
			return (numVal < 0 and "" or plus) .. tostring(numVal)
		end)
		:gsub("%-(%d+%%) (%a+)", antonymFunc)

	if numbers == 0 and line:match("(%d+%.?%d*)%%? ") then --If a mod contains x or x% and is not already a ranged value, then only the first number will be scalable as any following numbers will always be conditions or unscalable values.
		numbers = 1
	end

	return itemLib.applyValueScalar(line, valueScalar, baseValueScalar, numbers, precision)
end

function itemLib.formatModLine(modLine, dbMode)
	local line = (not dbMode and modLine.range and itemLib.applyRange(modLine.line, modLine.range, modLine.valueScalar, modLine.corruptedRange)) or modLine.line
	if line:match("^%+?0%%? ") or (line:match(" %+?0%%? ") and not line:match("0 to [1-9]")) or line:match(" 0%-0 ") or line:match(" 0 to 0 ") then -- Hack to hide 0-value modifiers
		return
	end
	local colorCode
	if modLine.extra then
		colorCode = colorCodes.UNSUPPORTED
		if launch.devModeAlt then
			line = line .. "   ^1'" .. modLine.extra .. "'"
		end
	else
		colorCode = (modLine.enchant and colorCodes.ENCHANTED) or (modLine.custom and colorCodes.CUSTOM) or colorCodes.MAGIC
	end
	return colorCode..line
end

itemLib.wiki = {
	key = "F1",
	openGem = function(gemData)
		local name
		if gemData.name then -- skill
			name = gemData.name
			if gemData.tags.support then
				name = name .. " Support"
			end
		else -- grantedEffect from item/passive
			name = gemData;
		end

		itemLib.wiki.open(name)
	end,
	openItem = function(item)
		local name = item.rarity == "UNIQUE" and item.title or item.baseName

		itemLib.wiki.open(name)
	end,
	open = function(name)
		local route = string.gsub(name, " ", "_")

		OpenURL("https://www.poe2wiki.net/wiki/" .. route)
		itemLib.wiki.triggered = true
	end,
	matchesKey = function(key)
		return key == itemLib.wiki.key
	end,
	triggered = false
}