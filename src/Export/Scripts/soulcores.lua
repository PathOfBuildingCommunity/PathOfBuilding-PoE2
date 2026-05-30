if not loadStatFile then
	dofile("statdesc.lua")
end
loadStatFile("stat_descriptions.csd")

classMap = {
	["Martial Weapon"] = { "weapon" },
	["Caster Weapon"] = { "caster" },
	["Martial Or Caster Weapon"] = { "weapon", "caster" },
	["Armour"] = { "armour" },
	["Wand or Staff"] = { "wand", "staff" },
	["Maces or Talisman"] = { "one hand mace", "two hand mace", "talisman" },
	["One Hand Mace or Quarterstaff"] = { "one hand mace", "quarterstaff" },
	["Shield or Buckler"] = { "shield", "buckler" },
	["All"] = { "weapon", "armour", "caster" },
	["Quarterstaff or Spear"] = { "quarterstaff", "spear" },
	["Crossbow Bow or Spear"] = { "crossbow", "bow", "spear" },
}

function table.containsId(table, element)
  for _, value in pairs(table) do
    if value.Id == element then
      return true
    end
  end
  return false
end

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
	if displayName:find("DNT") then
		return
	end
	displayName = displayName:gsub("\195\182","o")
	displayName = displayName:gsub("^%s*(.-)%s*$", "%1") -- trim spaces GGG might leave in by accident

	local function writeModLines(modLines, out)
		for _, modLine in ipairs(modLines) do
			out:write('\t\t["'..modLine.slotType..'"] = {\n')
			out:write('\t\t\t\ttype = "' .. modLine.type .. '",\n')
			-- only write labels/statOrder if present
			if modLine.label and #modLine.label > 0 then
				out:write('\t\t\t\t"'..table.concat(modLine.label, '",\n\t\t\t\t"')..'",\n')
				local statOrder = modLine.statOrder or {}
				out:write('\t\t\t\tstatOrder = { '..table.concat(statOrder, ', ')..' },\n')
				out:write('\t\t\t\ttradeHashes = { ')
				for hash, desc in pairs(modLine.tradeHashes) do
					local descriptionLines = '"'..table.concat(desc, '", "')..'"'
					out:write(string.format('[%d] = { %s }, ', hash, descriptionLines))
				end
				out:write(' },\n')
			end
			out:write('\t\t\t\trank = { '..(modLine.rank or 0)..' },\n')
			out:write('\t\t},\n')
		end
	end

	-- Check for Standard Weapon, Armour, Caster Runes
	local soulCores = dat("SoulCores"):GetRow("BaseItemTypes", baseItemType)
	local soulCoreStats = dat("SoulCoreStats"):GetRowList("Id", soulCores)
	out:write('\t["', displayName, '"] = {\n')
	local modLines = { }
	local rank = 0
	for _, soulCoreStat in ipairs(soulCoreStats) do
		rank = soulCores.LevelReq or 0

		local stats = { }
		local statHashes = {}
		for i, statKey in ipairs(soulCoreStat.Stats) do
			local statValue = soulCoreStat["StatValue"][i]
			table.insert(statHashes, intToBytes(statKey.Hash))
			stats[statKey.Id] = { min = statValue, max = statValue }
		end
		local bondedStats = { }
		for i, statKey in ipairs(soulCoreStat.BondedStats) do
			local statValue = soulCoreStat["BondedValues"][i]
			bondedStats[statKey.Id] = { min = statValue, max = statValue, bonded = true }
		end
		if next(stats) then
			for _, class in ipairs(classMap[soulCoreStat.Category.Id] or { string.lower(soulCoreStat.Category.Id) }) do
				printf("Category ID: " .. tostring(soulCoreStat.Category.Id))
				local stats, orders = describeStats(stats)
				local bondedStats, bondedOrders = describeStats(bondedStats)
				for i, stat in ipairs(bondedStats) do
					bondedStats[i] = "Bonded: " .. stat
				end
				for _, stat in ipairs(bondedStats) do
					table.insert(stats, stat)
				end
				for _, order in ipairs(bondedOrders) do
					table.insert(orders, order)
				end
				if #orders > 0 then
				local modIdx = 1
				local tradeHashes = {}
				while soulCoreStat.Stats[modIdx] do
					local currentStats = {}
					local stat = soulCoreStat.Stats[modIdx]
					currentStats[stat.Id] = {
						min = soulCoreStat.StatValue[modIdx], max = soulCoreStat.StatValue[modIdx]
					}
					local bytes = intToBytes(stat.Hash)
					-- # to # stats consist of two different stats as the min and max have different ranges
					if stat.Id:match("minimum") then
						local nextStat = soulCoreStat.Stats[modIdx + 1]
						if nextStat and nextStat.Id:match("maximum") then
							modIdx = modIdx + 1
							bytes = bytes .. intToBytes(nextStat.Hash)
							currentStats[nextStat.Id] = {
								min = soulCoreStat.StatValue[modIdx], max = soulCoreStat.StatValue[modIdx]
							}
						end
					end

					local description, _, _ = describeStats(currentStats)
					tradeHashes[murmurHash2(bytes, 0x02312233)] = description
					modIdx = modIdx + 1
				end
					local out = {
						type = soulCores.Type.Id,
						slotType = class,
						label = stats,
						statOrder = orders,
						rank = rank,
						tradeHashes = tradeHashes
					}
					table.insert(modLines, out)
				end
			end
		end
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
