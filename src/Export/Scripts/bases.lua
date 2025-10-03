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

	local function getMaximumQuality(baseItemType)
		if baseItemType == "nothing" then -- base case
			return 0
		end
		local file = getFile(baseItemType .. ".it")
		if not file then return nil end
		local text = convertUTF16to8(file)
		local superClassQuality
		for line in text:gmatch("[^\r\n]+") do
			local superClass = line:match("extends \"(.+)\"")
			if superClass then
				superClassQuality = getMaximumQuality(superClass)
			elseif line:match("max_quality") then
				return line:match("max_quality = (.+)")
			end
		end
		return superClassQuality
	end

	local baseItemTags = getBaseItemTags(baseItemType.BaseType)
	local maximumQuality = getMaximumQuality(baseItemType.BaseType)
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
	if maximumQuality ~= 0 then --If it crashes on this line, you are missing a .It file for a base ConPrintf(baseItemType.BaseType)
		out:write('\tquality = ', maximumQuality, ',\n')
	end
	if state.type == "Belt" then
			out:write('\tcharmLimit = 0,\n')
	end
	local itemSpirit = dat("ItemSpirit"):GetRow("BaseItemType", baseItemType)
	if itemSpirit then
		out:write('\tspirit = ', itemSpirit.Value, ',\n')
	end
	if state.forceHide and not baseTypeId:match("Talisman") and not state.forceShow then
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
	local implicitLines = { }
	local implicitModTypes = { }
	for _, mod in ipairs(baseItemType.ImplicitMods) do
		local modDesc = describeMod(mod)
		for _, line in ipairs(modDesc) do
			table.insert(implicitLines, line)
			table.insert(implicitModTypes, modDesc.modTags)
		end
		if mod.Id == "SpearImplicitDisplaySpearThrow1" then
			table.insert(implicitLines, "Grants Skill: Spear Throw")
		end
	end
	if state.type == "Belt" then
		table.insert(implicitLines, "Has (1-3) Charm Slots")
	end
	if #implicitLines > 0 then
		out:write('\timplicit = "', table.concat(implicitLines, "\\n"), '",\n')
	end
	local inherentSkillType = dat("ItemInherentSkills"):GetRow("BaseItemType", baseItemType)
	if inherentSkillType then
		local skillGem = dat("SkillGems"):GetRow("BaseItemType", inherentSkillType.Skill[1].BaseItemType)
		local gemEffect = dat("GemEffects"):GetRow("GrantedEffect", skillGem.GemEffects[1].GrantedEffect)
		if #inherentSkillType.Skill > 1 then
			print("Unhandled Instance - Inherent Skill number more than 1")
		end
		out:write('\timplicit = "Grants Skill: Level (1-20) ', gemEffect.GrantedEffect.ActiveSkill.DisplayName, '",\n')
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
		local modConversionMap = {
			["local_weapon_implicit_hidden_%_base_damage_is_fire"] = "Fire",
			["local_weapon_implicit_hidden_%_base_damage_is_cold"] = "Cold",
			["local_weapon_implicit_hidden_%_base_damage_is_lightning"] = "Lightning",
			["local_weapon_implicit_hidden_%_base_damage_is_chaos"] = "Chaos",
		}
		local modAddedMinMap = {
			["local_weapon_implicit_hidden_added_minimum_fire_damage"] = "Fire",
			["local_weapon_implicit_hidden_added_minimum_cold_damage"] = "Cold",
			["local_weapon_implicit_hidden_added_minimum_lightning_damage"] = "Lightning",
			["local_weapon_implicit_hidden_added_minimum_chaos_damage"] = "Chaos",
		}
		local modAddedMaxMap = {
			["local_weapon_implicit_hidden_added_maximum_fire_damage"] = "Fire",
			["local_weapon_implicit_hidden_added_maximum_cold_damage"] = "Cold",
			["local_weapon_implicit_hidden_added_maximum_lightning_damage"] = "Lightning",
			["local_weapon_implicit_hidden_added_maximum_chaos_damage"] = "Chaos",
		}
		local conversion = {
			["Physical"] = 100,
			["Fire"] = 0,
			["Cold"] = 0,
			["Lightning"] = 0,
			["Chaos"] = 0,
		}
		local addedMin = {
			["Physical"] = 0,
			["Fire"] = 0,
			["Cold"] = 0,
			["Lightning"] = 0,
			["Chaos"] = 0,
		}
		local addedMax = {
			["Physical"] = 0,
			["Fire"] = 0,
			["Cold"] = 0,
			["Lightning"] = 0,
			["Chaos"] = 0,
		}
		local total = 0
		for _, mod in ipairs(baseItemType.ImplicitMods) do
			for i = 1, 6 do
				if mod["Stat"..i] then
					local dmgType = modConversionMap[mod["Stat"..i].Id]
					if dmgType then
						local value = mod["Stat"..i.."Value"][1]
						conversion[dmgType] = conversion[dmgType] + value
						total = total + value
					end
					local addedMinDamage = modAddedMinMap[mod["Stat"..i].Id]
					if addedMinDamage then
						local value = mod["Stat"..i.."Value"][1]
						addedMin[addedMinDamage] = addedMin[addedMinDamage] + value
					end
					local addedMaxDamage = modAddedMaxMap[mod["Stat"..i].Id]
					if addedMaxDamage then
						local value = mod["Stat"..i.."Value"][1]
						addedMax[addedMaxDamage] = addedMax[addedMaxDamage] + value
					end
				end
			end
		end
		local factor = total > 100 and 100 / total or 1
		for _, type in ipairs({ "Physical", "Fire", "Cold", "Lightning", "Chaos" }) do
			if type == "Physical" then
				conversion[type] = 1 - math.min(total / 100, 1)
			else
				conversion[type] = conversion[type] * factor / 100
			end
			if conversion[type] ~= 0 then
				out:write(type, 'Min = ', math.floor(weaponType.DamageMin * conversion[type]), ', ', type, 'Max = ', math.floor(weaponType.DamageMax * conversion[type]), ', ')
			end
			if addedMin[type] ~= 0 then
				out:write(type, 'Min = ', addedMin[type], ', ')
			end
			if addedMax[type] ~= 0 then
				out:write(type,'Max = ', addedMax[type], ', ')
			end
		end
		out:write('CritChanceBase = ', weaponType.CritChance / 100, ', ')
		out:write('AttackRateBase = ', round(1000 / weaponType.Speed, 2), ', ')
		out:write('Range = ', weaponType.Range, ', ')
		if weaponType.ReloadTime > 0 then
			out:write('ReloadTimeBase = ', round(weaponType.ReloadTime / 1000, 2), ', ')
		end
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
			out:write('MovementPenalty = ', -armourType.MovementPenalty / 10000, ', ')
		end
		out:write('},\n')
	end
	if state.type == "Flask" or state.type == "Charm" then
		local flask = dat("Flasks"):GetRow("BaseItemType", baseItemType)
		if flask then
			local compCharges = dat("ComponentCharges"):GetRow("BaseItemType", baseItemType.Id)
			if state.type == "Charm" then
				out:write('\tcharm = { ')
			else
				out:write('\tflask = { ')
			end
			if flask.LifePerUse > 0 then
				out:write('life = ', flask.LifePerUse, ', ')
			end
			if flask.ManaPerUse > 0 then
				out:write('mana = ', flask.ManaPerUse, ', ')
			end
			out:write('duration = ', flask.RecoveryTime / 10, ', ')
			out:write('chargesUsed = ', compCharges.PerUse, ', ')
			out:write('chargesMax = ', compCharges.Max, ', ')
			if next(flask.UtilityBuffs) then
				local stats = { }
				for _, buff in ipairs(flask.UtilityBuffs) do
					for i, stat in ipairs(buff.BuffDefinitionsKey.GrantedStats) do
						stats[stat.Id] = { min = buff.StatValues[i], max = buff.StatValues[i] }
					end
					for i, stat in ipairs(buff.BuffDefinitionsKey.GrantedFlags) do
						stats[stat.Id] = { min = 1, max = 1 }
					end
				end
				out:write('buff = { "', table.concat(describeStats(stats), '", "'), '" }, ')
			end
			out:write('},\n')
		end
	end
	-- Special handling of Runes and SoulCores
	if state.type == "Rune" or state.type == "SoulCore" or state.type == "Talisman" then
		local soulCores = dat("SoulCores"):GetRow("BaseItemTypes", baseItemType)
		local soulCoresPerClass = dat("SoulCoresPerClass"):GetRow("BaseItemType", baseItemType)

		local stats = { }
		local outLines = { }
		if soulCores then
			if #soulCores.StatsKeysWeapon > 0 then
				for i, statKey in ipairs(soulCores.StatsKeysWeapon) do
					local statValue = soulCores["StatsValuesWeapon"][i]
					stats[statKey.Id] = { min = statValue, max = statValue }
				end
				table.insert(outLines, 'Martial Weapons: ' .. table.concat(describeStats(stats), '\\n'))
			end
			if #soulCores.StatsKeysArmour > 0 then
				stats = { }  -- reset stats to empty
				for i, statKey in ipairs(soulCores.StatsKeysArmour) do
					local statValue = soulCores["StatsValuesArmour"][i]
					stats[statKey.Id] = { min = statValue, max = statValue }
				end
				table.insert(outLines, 'Armour: ' .. table.concat(describeStats(stats), '\\n'))
			end
			if #soulCores.StatsKeysCaster > 0 then
				stats = { }  -- reset stats to empty
				for i, statKey in ipairs(soulCores.StatsKeysCaster) do
					local statValue = soulCores["StatsValuesCaster"][i]
					stats[statKey.Id] = { min = statValue, max = statValue }
				end
				table.insert(outLines, 'Caster: ' .. table.concat(describeStats(stats), '\\n'))
			end
			-- Attribute runes are special case and can socket in everything
			-- Sceptres are handled in "soulCoresPerClass"
			if #soulCores.StatsKeysAttributes > 0 then
				stats = { }  -- reset stats to empty
				for i, statKey in ipairs(soulCores.StatsKeysAttributes) do
					local statValue = soulCores["StatsValuesAttributes"][i]
					stats[statKey.Id] = { min = statValue, max = statValue }
				end
				table.insert(outLines, 'Martial Weapons: ' .. table.concat(describeStats(stats), '\\n'))
				table.insert(outLines, 'Armour: ' .. table.concat(describeStats(stats), '\\n'))
				table.insert(outLines, 'Caster: ' .. table.concat(describeStats(stats), '\\n'))
			end
		end
		-- Check for more slot specific Soulcores/Runes/Talismans
		local soulCoresPerClassList = dat("SoulCoresPerClass"):GetRowList("BaseItemType", baseItemType) or {}
		for _, row in ipairs(soulCoresPerClassList) do
			stats = {}
			for i, statKey in ipairs(row.Stats or {}) do
				local statValue = row.StatsValues[i]
				stats[statKey.Id] = { min = statValue, max = statValue }
			end
			if next(stats) then
				local coreItemClass = row.ItemClass and row.ItemClass.Id or "unknown"
				table.insert(outLines, coreItemClass .. ': ' .. table.concat(describeStats(stats), '\\n'))
			end
		end
		out:write('\timplicit = "'..table.concat(outLines, '\\n')..'",\n')
	end
	out:write('\treq = { ')
	local reqLevel = 1
	if weaponType or armourType then
		if baseItemType.DropLevel > 4 then
			reqLevel = baseItemType.DropLevel
		end
	end
	if state.type == "Flask" or state.type == "SoulCore" or state.type == "Rune" or state.type == "Charm" then
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
	local compAtt = dat("AttributeRequirements"):GetRow("BaseType", baseItemType)
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
	
	if not (state.forceHide and not baseTypeId:match("Talisman") and not state.forceShow) then
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
		directiveTable.base(state, baseItemType.Id, out)
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
	"sceptre",
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

processTemplateFile("Rares", "Bases/", "../Data/", directiveTable)
print("Rare Item Templates Generated and Verified")
