if not loadStatFile then
	dofile("statdesc.lua")
end
loadStatFile("stat_descriptions.csd")

function table.containsId(table, element)
  for _, value in pairs(table) do
    if value.Id == element then
      return true
    end
  end
  return false
end

local s_format = string.format

local directiveTable = { }

directiveTable.type = function(state, args, out)
	state.type = args
end

directiveTable.base = function(state, args, out)
	local baseTypeId, displayName = args:match("([%w/_]+) (.+)")
	if not baseTypeId then
		baseTypeId = args
	end
	local baseItemType = dat("BaseItemTypes"):GetRow("Id", baseTypeId)
	if not baseItemType then
		printf("Invalid Id %s", baseTypeId)
		return
	end
	if not displayName then
		displayName = baseItemType.Name
	end
	displayName = displayName:gsub("\195\182","o")
	displayName = displayName:gsub("^%s*(.-)%s*$", "%1") -- trim spaces GGG might leave in by accident
	
	-- Special handling of Runes and SoulCores
	local function addRuneStats(stats, slotType, modLines, rank)
		local stats, orders = describeStats(stats)
		if #orders > 0 then
			local out = {
				type = "Rune",
				slotType = slotType,
				label = stats,
				statOrder = orders,
				rank = rank,
			}
			table.insert(modLines, out)
		end
	end

	local function writeModLines(modLines, out)
		for _, modLine in ipairs(modLines) do
			out:write('\t\t["'..modLine.slotType..'"] = {\n')
			out:write('\t\t\t\ttype = "Rune",\n')
			-- only write labels/statOrder if present
			if modLine.label and #modLine.label > 0 then
				out:write('\t\t\t\t"'..table.concat(modLine.label, '",\n\t\t\t\t"')..'",\n')
				local statOrder = modLine.statOrder or {}
				out:write('\t\t\t\tstatOrder = { '..table.concat(statOrder, ', ')..' },\n')
			end
			out:write('\t\t\t\trank = { '..(modLine.rank or 0)..' },\n')
			out:write('\t\t},\n')
		end
	end

	-- Check for Standard Weapon, Armour, Caster Runes
	local soulCores = dat("SoulCores"):GetRow("BaseItemTypes", baseItemType)
	out:write('\t["', displayName, '"] = {\n')
	local modLines = { }
	local rank = 0
	if soulCores then
		rank = soulCores.Rank or 0

		-- weapons
		local stats = { }
		for i, statKey in ipairs(soulCores.StatsKeysWeapon) do
			local statValue = soulCores["StatsValuesWeapon"][i]
			stats[statKey.Id] = { min = statValue, max = statValue }
		end
		if next(stats) then
			addRuneStats(stats, "weapon", modLines, rank)
		end

		-- armour
		stats = { }  -- reset stats to empty
		for i, statKey in ipairs(soulCores.StatsKeysArmour) do
			local statValue = soulCores["StatsValuesArmour"][i]
			stats[statKey.Id] = { min = statValue, max = statValue }
		end
		if next(stats) then
			addRuneStats(stats, "armour", modLines, rank)
		end

		-- caster check (wand & staff)
		stats = { }  -- reset stats to empty
		for i, statKey in ipairs(soulCores.StatsKeysCaster) do
			local statValue = soulCores["StatsValuesCaster"][i]
			stats[statKey.Id] = { min = statValue, max = statValue }
		end
		if next(stats) then
			addRuneStats(stats, "caster", modLines, rank)
		end

		-- Check if the row is an Attribute rune which can go in all slots
		if soulCores.StatsKeysAttributes then
			stats = { }  -- reset stats to empty
			for i, statKey in ipairs(soulCores.StatsKeysAttributes) do
				local statValue = soulCores["StatsValuesAttributes"][i]
				stats[statKey.Id] = { min = statValue, max = statValue }
			end
			if next(stats) then
				addRuneStats(stats, "weapon", modLines, rank)
				addRuneStats(stats, "armour", modLines, rank)
				addRuneStats(stats, "caster", modLines, rank)
			end
		end
	end

	-- Handle special case of new runes on specific item types
	local soulCoresPerClassList = dat("SoulCoresPerClass"):GetRowList("BaseItemType", baseItemType) or {}
	local mergedSlotStats = {}

	for _, row in ipairs(soulCoresPerClassList) do
		local stats = {} -- reset stats to empty
		for i, statKey in ipairs(row.Stats or {}) do
			local statValue = row.StatsValues[i]
			stats[statKey.Id] = { min = statValue, max = statValue }
		end
		local slotType = (row.ItemClass and row.ItemClass.Id or "unknown"):lower()
		if next(stats) then
			mergedSlotStats[slotType] = mergedSlotStats[slotType] or {}
			for k,v in pairs(stats) do
				mergedSlotStats[slotType][k] = v
			end
		end
	end

	for slotType, stats in pairs(mergedSlotStats) do
		-- use the soulCores.Rank (if present) for per-class slots too
		addRuneStats(stats, slotType, modLines, rank)
	end

	-- If nothing produced stats but the soulCores row carries a Rank, export a rank-only entry
	if #modLines == 0 and rank then
		-- produce a rank-only entry (no labels/statOrder) so other code can read Rank
		table.insert(modLines, { slotType = "weapon", label = {}, statOrder = {}, rank = rank })
	end

	writeModLines(modLines, out)
	out:write('\t},\n')
end

directiveTable.baseMatch = function(state, argstr, out)
	-- Default to look at the Id column for matching
	local key = "Id"
	local args = {}
	for i in string.gmatch(argstr, "%S+") do
		table.insert(args, i)
	end
	local value = args[1]
	-- If column name is specified, use that
	if args[2] then
		key = args[1]
		value = args[2]
	end
	for i, baseItemType in ipairs(dat("BaseItemTypes"):GetRowList(key, value, true)) do
		directiveTable.base(state, baseItemType.Id, out)
	end
end

local out = io.open("../Data/ModRunes.lua", "w")
out:write('-- This file is automatically generated, do not edit!\n')
out:write('-- Item data (c) Grinding Gear Games\n\nreturn {\n')

local state = { }
for line in io.lines("Bases/soulcore.txt") do
	local spec, args = line:match("#(%a+) ?(.*)")
	if spec then
		if directiveTable[spec] then
			directiveTable[spec](state, args, out)
		else
			printf("Unknown directive '%s'", spec)
		end
	end
end

out:write("}")
out:close()

print("Soul Cores exported.")
