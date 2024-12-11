if not loadStatFile then
	dofile("statdesc.lua")
end
loadStatFile("stat_descriptions.csd")

local s_format = string.format

local directiveTable = { }
local bases = { All = { } }

directiveTable.type = function(state, args, out)
	state.type = args
end

directiveTable.subType = function(state, args, out)
	state.subType = args
end

directiveTable.influenceBaseTag = function(state, args, out)
	state.influenceBaseTag = args
end

directiveTable.forceShow = function(state, args, out)
	state.forceShow = (args == "true")
end

directiveTable.forceHide = function(state, args, out)
	state.forceHide = (args == "true")
end

directiveTable.socketLimit = function(state, args, out)
	state.socketLimit = tonumber(args)
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
	local function getBaseItemTags(baseItemType)
		if baseItemType == "nothing" then -- base case
			return {}
		end
		local file = getFile(baseItemType .. ".it")
		if not file then return nil end
		local text = convertUTF16to8(file)
		local tags = {}
		for line in text:gmatch("[^\r\n]+") do
			local superClass = line:match("extends \"(.+)\"")
			if superClass then
				local superClassTags = getBaseItemTags(superClass)
				if superClassTags then
					for _, tag in ipairs(superClassTags) do
						table.insert(tags, tag)
					end
				end
			elseif line:match("remove_tag") then
				table.remove(tags, isValueInTable(tags, line:match("remove_tag = \"(.+)\"")))
			elseif line:match("tag") then
				table.insert(tags, line:match("tag = \"(.+)\""))
			end
		end
		return tags
	end
	local baseItemTags = getBaseItemTags(baseItemType.BaseType)
	if not displayName then
		displayName = baseItemType.Name
	end
	displayName = displayName:gsub("\195\182","o")
	displayName = displayName:gsub("^%s*(.-)%s*$", "%1") -- trim spaces GGG might leave in by accident
	displayName = displayName ~= "Energy Blade" and displayName or (state.type == "One Handed Sword" and "Energy Blade One Handed" or "Energy Blade Two Handed")
	out:write('itemBases["', displayName, '"] = {\n')
	out:write('\ttype = "', state.type, '",\n')
	if state.subType and #state.subType > 0 then
		out:write('\tsubType = "', state.subType, '",\n')
	end
	if (baseItemType.Hidden == 0 or state.forceHide) and not baseTypeId:match("Talisman") and not state.forceShow then
		out:write('\thidden = true,\n')
	end
	if state.socketLimit then
		out:write('\tsocketLimit = ', state.socketLimit, ',\n')
	end
	out:write('\ttags = { ')
	local combinedTags = { }
	for _, tag in ipairs(baseItemTags or {}) do
		combinedTags[tag] = tag
	end
	for _, tag in ipairs(baseItemType.Tags) do
		combinedTags[tag.Id] = tag.Id
	end
	for _, tag in pairs(combinedTags) do
		out:write(tag, ' = true, ')
	end
	out:write('},\n')
	local influencePrefix = state.influenceBaseTag
	if influencePrefix then
		out:write('\tinfluenceTags = { ')
		for i, influenceSuffix in ipairs({ "shaper", "elder", "adjudicator", "basilisk", "crusader", "eyrie", "cleansing", "tangle" }) do
			if i ~= 1 then out:write(", ") end
			out:write(influenceSuffix, ' = "', influencePrefix, "_", influenceSuffix, '"')
		end
		out:write(' },\n')
	end
	local implicitLines = { }
	local implicitModTypes = { }
	for _, mod in ipairs(baseItemType.ImplicitMods) do
		local modDesc = describeMod(mod)
		for _, line in ipairs(modDesc) do
			table.insert(implicitLines, line)
			table.insert(implicitModTypes, modDesc.modTags)
		end
	end
	if #implicitLines > 0 then
		out:write('\timplicit = "', table.concat(implicitLines, "\\n"), '",\n')
	end
	out:write('\timplicitModTypes = { ')
	for i=1,#implicitModTypes do
		out:write('{ ', implicitModTypes[i], ' }, ')
	end
	out:write('},\n')
	local itemValueSum = 0
	local weaponType = dat("WeaponTypes"):GetRow("BaseItemType", baseItemType)
	if weaponType then
		out:write('\tweapon = { ')
		out:write('PhysicalMin = ', weaponType.DamageMin, ', PhysicalMax = ', weaponType.DamageMax, ', ')
		out:write('CritChanceBase = ', weaponType.CritChance / 100, ', ')
		out:write('AttackRateBase = ', round(1000 / weaponType.Speed, 2), ', ')
		out:write('Range = ', weaponType.Range, ', ')
		out:write('},\n')
		itemValueSum = weaponType.DamageMin + weaponType.DamageMax
	end
	local armourType = dat("ArmourTypes"):GetRow("BaseItemType", baseItemType)
	if armourType then
		out:write('\tarmour = { ')
		local shield = dat("ShieldTypes"):GetRow("BaseItemType", baseItemType)
		if shield then
			out:write('BlockChance = ', shield.Block, ', ')
		end
		if armourType.Armour > 0 then
			out:write('Armour = ', armourType.Armour, ', ')
			itemValueSum = itemValueSum + armourType.Armour
		end
		if armourType.Evasion > 0 then
			out:write('Evasion = ', armourType.Evasion, ', ')
			itemValueSum = itemValueSum + armourType.Evasion
		end
		if armourType.EnergyShield > 0 then
			out:write('EnergyShield = ', armourType.EnergyShield, ', ')
			itemValueSum = itemValueSum + armourType.EnergyShield
		end
		if armourType.MovementPenalty ~= 0 then
			out:write('MovementPenalty = ', -armourType.MovementPenalty, ', ')
		end
		out:write('},\n')
	end
	if state.type == "Flask" then
		local flask = dat("Flasks"):GetRow("BaseItemType", baseItemType)
		if flask then
			local compCharges = dat("ComponentCharges"):GetRow("BaseItemType", baseItemType.Id)
			out:write('\tflask = { ')
			if flask.LifePerUse > 0 then
				out:write('life = ', flask.LifePerUse, ', ')
			end
			if flask.ManaPerUse > 0 then
				out:write('mana = ', flask.ManaPerUse, ', ')
			end
			out:write('duration = ', flask.RecoveryTime / 10, ', ')
			out:write('chargesUsed = ', compCharges.PerUse, ', ')
			out:write('chargesMax = ', compCharges.Max, ', ')
			if flask.Buff then
				local stats = { }
				for i, stat in ipairs(flask.Buff.Stats) do
					stats[stat.Id] = { min = flask.BuffMagnitudes[i], max = flask.BuffMagnitudes[i] }
				end
				for i, stat in ipairs(flask.Buff.GrantedFlags) do
					stats[stat.Id] = { min = 1, max = 1 }
				end
				out:write('buff = { "', table.concat(describeStats(stats), '", "'), '" }, ')
			end
			out:write('},\n')
		end
	end
	-- Special handling of Runes and SoulCores
	if state.type == "Rune" or state.type == "SoulCore" then
		local soulcore = dat("SoulCores"):GetRow("BaseItemTypes", baseItemType)
		if soulcore then
			out:write('\timplicit = ')
			local stats = { }
			for i, statKey in ipairs(soulcore.StatsKeysWeapon) do
				local statValue = soulcore["StatsValuesWeapon"][i]
				stats[statKey.Id] = { min = statValue, max = statValue }
			end
			out:write('"Martial Weapons: ', table.concat(describeStats(stats), '", "'), '\\n')
			stats = { }  -- reset stats to empty
			for i, statKey in ipairs(soulcore.StatsKeysArmour) do
				local statValue = soulcore["StatsValuesArmour"][i]
				stats[statKey.Id] = { min = statValue, max = statValue }
			end
			out:write('Armour: ', table.concat(describeStats(stats), '", "'), '"')
			out:write(',\n')
		end
	end
	out:write('\treq = { ')
	local reqLevel = 1
	if weaponType or armourType then
		if baseItemType.DropLevel > 4 then
			reqLevel = baseItemType.DropLevel
		end
	end
	if flask then
		if baseItemType.DropLevel > 2 then
			reqLevel = baseItemType.DropLevel
		end
	end
	for _, mod in ipairs(baseItemType.ImplicitMods) do
		reqLevel = math.max(reqLevel, math.floor(mod.Level * 0.8))
	end
	if reqLevel > 1 then
		out:write('level = ', reqLevel, ', ')
	end
	local compAtt = dat("AttributeRequirements"):GetRow("BaseType", baseItemType.Id)
	if compAtt then
		if compAtt.ReqStr > 0 then
			out:write('str = ', compAtt.ReqStr, ', ')
		end
		if compAtt.ReqDex > 0 then
			out:write('dex = ', compAtt.ReqDex, ', ')
		end
		if compAtt.ReqInt > 0 then
			out:write('int = ', compAtt.ReqInt, ', ')
		end
	end
	out:write('},\n}\n')
	
	if not ((baseItemType.Hidden == 0 or state.forceHide) and not baseTypeId:match("Talisman") and not state.forceShow) then
		bases[state.type] = bases[state.type] or {}
		local subtype = state.subType and #state.subType and state.subType or ""
		if not bases[state.type][subtype] or itemValueSum > bases[state.type][subtype][2] then
			bases[state.type][subtype] = { displayName, itemValueSum }
		end
		bases["All"][displayName] = { state.type, state.subType }
	end
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
		if not string.find(baseItemType.Id, "Royale") then
			directiveTable.base(state, baseItemType.Id, out)
		end
	end
end

local baseMods = { }
directiveTable.baseGroup = function(state, args, out)
	local baseGroup, values = args:match("^([^%)]+), %[ ([^%)]+)%]")
	baseMods[baseGroup] = values
end

directiveTable.setBestBase = function(state, args, out)
	local baseClass, baseSubType, itemNameOverride, values = args:match("^([^,]+), ([^,]+), ([^,]+), %[([^%]]+)%]")
	if not baseClass then
		baseClass, baseSubType, values = args:match("^([^%)]+), ([^%)]+), %[ ([^%)]+)%]")
	end
	local itemName = itemNameOverride and itemNameOverride or (baseSubType..' '..baseClass)
	local base = bases[baseClass][baseSubType][1]
	out:write('[[\n')
	out:write(itemName,'\n')
	out:write(base,'\n')
	if not values:match("Crafted: true") then
		out:write('Crafted: true\n')
	end
	if values ~= " " then
		for line in values:gmatch('([^,]+)') do
			out:write(line:gsub("^ ", ""),'\n')
		end
	elseif baseMods[itemName] then
		for line in values:gmatch('([^,]+)') do
			out:write(line:gsub("^ ", ""),'\n')
		end
	end
	out:write(']],')
end

directiveTable.setBase = function(state, args, out)
	local baseName, itemName, values = args:match("^([^,]+), ([^,]+), %[([^%]]+)%]")
	if not baseName then
		baseName, values = args:match("([^,]+), %[([^%]]+)%]")
	end
	if baseName and not bases["All"][baseName] then
		print("Missing base")
		print(baseName)
		return
	end
	out:write('[[\n')
	local baseClass, baseSubType = unpack(bases["All"][baseName])
	local groupName = baseClass
	if itemName then
		out:write(s_format(itemName, baseClass):gsub("One Handed", "1H"):gsub("Two Handed", "2H"),'\n')
		groupName = s_format(itemName, (baseClass:match("One Handed") or baseClass:match("Claw") or baseClass:match("Dagger") or baseClass:match("Sceptre") or baseClass:match("Wand")) and "One Handed" or (baseClass:match("Two Handed") or baseClass:match("Staff")) and "Two Handed" or "")
	else
		if baseSubType then
			groupName = baseSubType..' '..baseClass
			out:write(groupName,'\n')
		else
			out:write(baseClass,'\n')
		end
	end
	out:write(baseName,'\n')
	if not values:match("Crafted: true") then
		out:write('Crafted: true\n')
	end
	if values ~= " " then
		for line in values:gmatch('([^,]+)') do
			out:write(line:gsub("^ ", ""),'\n')
		end
	elseif baseMods[groupName] then
		for line in baseMods[groupName]:gmatch('([^,]+)') do
			out:write(line:gsub("^ ", ""),'\n')
		end
	end
	out:write(']],')
end

local itemTypes = {
	"axe",
	"bow",
	"claw",
	"crossbow",
	"dagger",
	"fishing",
	"flail",
	"mace",
	"spear",
	"staff",
	"sword",
	"wand",
	"helmet",
	"body",
	"focus",
	"gloves",
	"boots",
	"shield",
	"quiver",
	"traptool",
	"amulet",
	"ring",
	"belt",
	"jewel",
	"flask",
	"soulcore",
}
for _, name in pairs(itemTypes) do
	processTemplateFile(name, "Bases/", "../Data/Bases/", directiveTable)
end

print("Item bases exported.")

--processTemplateFile("Rares", "Bases/", "../Data/", directiveTable)
--print("Rare Item Templates Generated and Verified")
