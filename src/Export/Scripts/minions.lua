local function makeSkillMod(modName, modType, modVal, flags, keywordFlags, ...)
	return {
		name = modName,
		type = modType,
		value = modVal,
		flags = flags or 0,
		keywordFlags = keywordFlags or 0,
		...
	}
end
local function makeFlagMod(modName, ...)
	return makeSkillMod(modName, "FLAG", true, 0, 0, ...)
end
local function makeSkillDataMod(dataKey, dataValue, ...)
	return makeSkillMod("SkillData", "LIST", { key = dataKey, value = dataValue }, 0, 0, ...)
end
dofile("../Data/Global.lua")
local skillStatMap = LoadModule("../Data/SkillStatMap.lua", makeSkillMod, makeFlagMod, makeSkillDataMod)

local function tableToString(tbl, pre)
	pre = pre or ""
	local tableString = "{ "
	local outNames = { }
	for name in pairs(tbl) do
		table.insert(outNames, name)
	end
	table.sort(outNames)
	for _, name in ipairs(outNames) do
		if type(tbl[name]) == "table" then
			tableString = tableString .. tableToString(tbl[name], pre .. name .. ".")
		else
			if _ > 1 then
				tableString = tableString .. ", "
			end
			tableString = tableString .. pre .. name .. " = " .. (type(tbl[name]) == "string" and '"' or '') .. tostring(tbl[name]) .. (type(tbl[name]) == "string" and '"' or '')
		end
	end
	return tableString .. " }"
end

local itemClassMap = {
	["Claw"] = "Claw",
	["Dagger"] = "Dagger",
	["Wand"] = "Wand",
	["One Hand Sword"] = "One Handed Sword",
	["Thrusting One Hand Sword"] = "One Handed Sword",
	["One Hand Axe"] = "One Handed Axe",
	["One Hand Mace"] = "One Handed Mace",
	["Crossbow"] = "Crossbow",
	["Bow"] = "Bow",
	["Fishing Rod"] = "Fishing Rod",
	["Staff"] = "Staff",
	["Warstaff"] = "Warstaff",
	["Two Hand Sword"] = "Two Handed Sword",
	["Two Hand Axe"] = "Two Handed Axe",
	["Two Hand Mace"] = "Two Handed Mace",
	["Shield"] = "Shield",
	["Sceptre"] = "One Handed Mace",
	["Flail"] = "Flail",
	["Spear"] = "Spear",
	["Unarmed"] = "None",
}

local directiveTable = { }

-- #monster <MonsterId> [<Name>] [<ExtraSkills>]
directiveTable.monster = function(state, args, out)
	state.varietyId = nil
	state.name = nil
	state.limit = nil
	state.extraFlags = state.extraFlags or { }
	state.extraModList = { }
	state.extraSkillList = { }
	for arg in args:gmatch("%S+") do
		if state.varietyId == nil then
			state.varietyId = arg
		elseif state.name == nil then
			if arg == "#" then
				state.name = state.varietyId
			else
				state.name = arg
			end
		else
			table.insert(state.extraSkillList, arg)
		end
	end
	state.varietyId = state.varietyId or args
	state.name = state.name or args
end

-- #limit <LimitVarName>
directiveTable.limit = function(state, args, out)
	state.limit = args
end

-- #flags
directiveTable.flags = function(state, args, out)
	for flag in args:gmatch("%S+") do
		table.insert(state.extraFlags, flag)
	end
end

-- #mod <ModDecl>
directiveTable.mod = function(state, args, out)
	table.insert(state.extraModList, args)
end

-- #skill <SkillId>
directiveTable.skill = function(state, args, out)
	table.insert(state.extraSkillList, args)
end

-- #emit
directiveTable.emit = function(state, args, out)

	local monsterVariety = dat("MonsterVarieties"):GetRow("Id", state.varietyId)
	local matchingEntries = {}
	local allMonsterPackIds = {}

	-- Step 1: From MonsterPackEntries
	for i = 1, 2000 do
		local entry = dat("MonsterPackEntries"):GetRow("Id", tostring(i))
		if entry and entry.MonsterPacksKey then
			local packId = entry.MonsterPacksKey.Id
			if packId then
				allMonsterPackIds[packId] = true -- add to full set of pack IDs
				if entry.MonsterVarietiesKey and entry.MonsterVarietiesKey.Name == monsterVariety.Name then
					table.insert(matchingEntries, packId)
				end
			end
		end
	end
	-- Step 2: Check if monster is in AdditionalMonsters within MonsterPacks
	for packId, _ in pairs(allMonsterPackIds) do
		local pack = dat("MonsterPacks"):GetRow("Id", tostring(packId))
		if pack and pack.AdditionalMonsters then
			for _, addMon in ipairs(pack.AdditionalMonsters) do
				if addMon.Name == monsterVariety.Name then
					table.insert(matchingEntries, pack.Id)
				end
			end
		end
	end
	-- Step 3: Get WorldAreas for each matching MonsterPack
	local worldAreaNames = {}
	local seenAreas = {}

	for _, packId in ipairs(matchingEntries) do
		local pack = dat("MonsterPacks"):GetRow("Id", tostring(packId))
		if pack and pack.WorldAreas then
			for _, worldAreaRef in ipairs(pack.WorldAreas) do
				local area = dat("WorldAreas"):GetRow("Id", worldAreaRef.Id)
				if area and area.Name ~= "NULL" and not seenAreas[area.Name] then
					 table.insert(worldAreaNames, area.Name)
					 seenAreas[area.Name] = true
				end
			end
		end
	end

	if not monsterVariety then
		print("Invalid Variety: "..state.varietyId)
		return
	end
	out:write('minions["', state.name, '"] = {\n')
	out:write('\tname = "', monsterVariety.Name, '",\n')
	out:write('\tmonsterTags = { ')
	for _, tag in ipairs(monsterVariety.Tags) do
		out:write('"',tag.Id, '", ')
	end
	out:write('},\n')
	if #state.extraFlags > 0 then
		out:write('\textraFlags = {\n')
		for _, flag in ipairs(state.extraFlags) do
			out:write('\t\t', flag, ' = true,\n')
		end
		out:write('\t},\n')
	end
	out:write('\tlife = ', (monsterVariety.LifeMultiplier/100), ',\n')
	if monsterVariety.Type.BaseDamageIgnoresAttackSpeed then
		out:write('\tbaseDamageIgnoresAttackSpeed = true,\n')
	end
	if monsterVariety.Type.EnergyShield ~= 0 then
		out:write('\tenergyShield = ', (monsterVariety.Type.EnergyShield / 100), ',\n')
	end
	if monsterVariety.Type.Armour ~= 0 then
		out:write('\tarmour = ', monsterVariety.Type.Armour / 100, ',\n')
	end
	if monsterVariety.Type.Evasion ~= 0 then
		out:write('\tevasion = ', monsterVariety.Type.Evasion / 100, ',\n')
	end
	out:write('\tfireResist = ', monsterVariety.Type.Resistances[1].Fire1[1], ',\n')
	out:write('\tcoldResist = ', monsterVariety.Type.Resistances[1].Cold1[1], ',\n')
	out:write('\tlightningResist = ', monsterVariety.Type.Resistances[1].Lightning1[1], ',\n')
	out:write('\tchaosResist = ', monsterVariety.Type.Resistances[1].Chaos1[1], ',\n')
	out:write('\tdamage = ', (monsterVariety.DamageMultiplier/100), ',\n')
	out:write('\tdamageSpread = ', (monsterVariety.Type.DamageSpread / 100), ',\n')
	out:write('\tattackTime = ', (monsterVariety.AttackDuration/1000), ',\n')
	out:write('\tattackRange = ', monsterVariety.MaximumAttackRange, ',\n')
	out:write('\taccuracy = ', monsterVariety.Type.Accuracy / 100, ',\n')
	for _, mod in ipairs(monsterVariety.Mods) do
		if mod.Id == "MonsterSpeedAndDamageFixupSmall" then
			out:write('\tdamageFixup = 0.11,\n')
		elseif mod.Id == "MonsterSpeedAndDamageFixupLarge" then
			out:write('\tdamageFixup = 0.22,\n')
		elseif mod.Id == "MonsterSpeedAndDamageFixupComplete" then
			out:write('\tdamageFixup = 0.33,\n')
		end
	end
	if monsterVariety.MainHandItemClass and itemClassMap[monsterVariety.MainHandItemClass.Id] then
		out:write('\tweaponType1 = "', itemClassMap[monsterVariety.MainHandItemClass.Id], '",\n')
	end
	if monsterVariety.OffHandItemClass and itemClassMap[monsterVariety.OffHandItemClass.Id] then
		out:write('\tweaponType2 = "', itemClassMap[monsterVariety.OffHandItemClass.Id], '",\n')
	end
	if state.limit then
		out:write('\tlimit = "', state.limit, '",\n')
	end
	if monsterVariety.ExperienceMultiplier then
		out:write('\tspectreReservation = ', (round(50 * math.max(monsterVariety.ExperienceMultiplier/100, 0) / 10) * 10), ',\n')
		out:write('\tcompanionReservation = ', (round(math.sqrt(monsterVariety.ExperienceMultiplier/100), 2) * 30), ',\n') 
	end
	if monsterVariety.MonsterCategory then
		out:write('\tmonsterCategory = "', (monsterVariety.MonsterCategory.Type), '",\n')
	end
	out:write('\tspawnLocation = {\n')
	for _, name in ipairs(worldAreaNames) do
		out:write('\t\t"', name, '",\n')
	end
	out:write('\t},\n')
	out:write('\tskillList = {\n')
	for _, grantedEffect in ipairs(monsterVariety.GrantedEffects) do
		out:write('\t\t"', grantedEffect.Id, '",\n')
	end
	for _, skill in ipairs(state.extraSkillList) do
		out:write('\t\t"', skill, '",\n')
	end
	out:write('\t},\n')

	local modList = { }
	for _, mod in ipairs(monsterVariety.Mods) do
		table.insert(modList, mod)
	end
	for _, mod in ipairs(monsterVariety.SpecialMods) do
		table.insert(modList, mod)
	end
	out:write('\tmodList = {\n')
	for _, mod in ipairs(modList) do
		local modStats = ""
		for i = 1, 6 do
			if mod["Stat"..i] then
				modStats = ' [' .. mod["Stat"..i].Id .. ' = ' .. mod["Stat"..i.."Value"][1] .. ']'
				if skillStatMap[mod["Stat"..i].Id] then
					local newMod = skillStatMap[mod["Stat"..i].Id][1]
					--mod("Speed", "INC", -80, ModFlag.Cast, KeywordFlag.Curse)
					out:write('\t\tmod("', newMod.name, '", "', newMod.type, '", ', newMod.value and type(newMod.value) ~= "boolean" and tableToString(newMod.value) or (skillStatMap[mod["Stat"..i].Id].value or mod["Stat"..i.."Value"][1] * (skillStatMap[mod["Stat"..i].Id].mult or 1) / (skillStatMap[mod["Stat"..i].Id].div or 1)), ', ', newMod.flags or 0, ', ', newMod.keywordFlags or 0)
					for _, extra in ipairs(newMod) do
						out:write(', ', tableToString(extra))
					end
					out:write('), -- ', mod.Id, modStats, '\n')
				else
					out:write('\t\t-- ', mod.Id, modStats, '\n')
				end
			end
		end
	end
	for _, mod in ipairs(state.extraModList) do
		out:write('\t\t', mod, ',\n')
	end
	out:write('\t},\n')
	out:write('}\n')
	state.extraFlags = { }
end

-- #spectre <MonsterId> [<Name>]
directiveTable.spectre = function(state, args, out)
	directiveTable.monster(state, args, out)
end

for _, name in pairs({"Spectres","Minions"}) do -- Add back when Spectres are in the game again
--for _, name in pairs({"Minions"}) do
	processTemplateFile(name, "Minions/", "../Data/", directiveTable)
end

print("Minion data exported.")