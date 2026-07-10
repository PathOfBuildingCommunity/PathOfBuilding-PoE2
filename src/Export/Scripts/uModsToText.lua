if not table.containsId then
	dofile("Scripts/mods.lua")
end
local catalystTags = {
	["attack"] = true,
	["speed"] = true,
	["life"] = true,
	["mana"] = true,
	["caster"] = true,
	["attribute"] = true,
	["physical"] = true,
	["fire"] = true,
	["cold"] = true,
	["lightning"] = true,
	["chaos"] = true,
	["defences"] = true,
	["minion"] = true,
}

local function getCatalystTagPrefix(modTags)
	local tags = { }
	for _, tag in ipairs(modTags) do
		if catalystTags[tag] then
			table.insert(tags, tag)
		end
	end
	return tags[1] and "{tags:"..table.concat(tags, ",").."}" or ""
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
	"talisman",
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
	"incursionlimb",
}
local function appendMods(lines, statOrder)
	local orders = { }
	for order, _ in pairs(statOrder) do
		table.insert(orders, order)
	end
	table.sort(orders)
	for _, order in ipairs(orders) do
		for _, line in ipairs(statOrder[order]) do
			table.insert(lines, line)
		end
	end
end

local function stripLineTags(line)
	return (line:gsub("{[^}]+}", ""))
end

local function isGrantedSkillLine(line)
	return stripLineTags(line):match("^Grants Skill")
end

local function writeLines(out, lines)
	for _, line in ipairs(lines) do
		out:write(line, "\n")
	end
end

local itemBases = { }
for _, name in ipairs(itemTypes) do
	local baseFileName = "../Data/Bases/"..name..".lua"
	local baseFile = io.open(baseFileName, "r")
	if baseFile then
		baseFile:close()
		LoadModule(baseFileName, itemBases)
	end
end

local uniqueMods = LoadModule("../Data/ModItemExclusive.lua")
local modVeiled = LoadModule("../Data/ModVeiled.lua")

for _, name in ipairs(itemTypes) do
	local out = io.open("../Data/Uniques/"..name..".lua", "w")
	local useCatalystTags = name == "amulet" or name == "ring"
	local lines = { }
	local implicitLines = { }
	local grantedSkillLines = { }
	local statOrder = {}
	local postModLines = {}
	local variantBaseImplicitLines = { }
	local modLines = 0
	local sourceImplicitLines
	local headerLineCount
	local base
	local baseReqLevel = 0
	local includeBaseImplicits = true
	local uniqueReqLevel = 0
	for line in io.lines("Uniques/"..name..".lua") do
		local specName, specVal = line:match("^([%a ]+): (.+)$")
		if line:match("]],") then -- start new unique
			assert(base, "Missing base type while exporting "..name..".lua")
			if uniqueReqLevel > baseReqLevel then
				table.insert(lines, "Requires Level "..uniqueReqLevel)
			end
			local baseImplicitLines = { }
			local finalImplicitLines = { }
			if includeBaseImplicits and base.implicit then
				local implicitIndex = 0
				for baseLine in base.implicit:gmatch("[^\n]+") do
					implicitIndex = implicitIndex + 1
					local modTypes = base.implicitModTypes and base.implicitModTypes[implicitIndex] or { }
					local prefix = useCatalystTags and getCatalystTagPrefix(modTypes) or ""
					for _, implicitLine in ipairs(variantBaseImplicitLines[stripLineTags(baseLine)] or { prefix..baseLine }) do
						if isGrantedSkillLine(implicitLine) then
							table.insert(finalImplicitLines, implicitLine)
						else
							table.insert(baseImplicitLines, implicitLine)
						end
					end
				end
			end
			for _, implicitList in ipairs({ grantedSkillLines, baseImplicitLines, implicitLines }) do
				for _, implicitLine in ipairs(implicitList) do
					table.insert(finalImplicitLines, implicitLine)
				end
			end
			if finalImplicitLines[1] then
				table.insert(lines, "Implicits: "..#finalImplicitLines)
				for _, implicitLine in ipairs(finalImplicitLines) do
					table.insert(lines, implicitLine)
				end
			end
			appendMods(lines, statOrder)
			for _, line in ipairs(postModLines) do
				table.insert(lines, line)
			end
			table.insert(lines, line)
			writeLines(out, lines)
			lines = { }
			implicitLines = { }
			grantedSkillLines = { }
			statOrder = { }
			postModLines = { }
			variantBaseImplicitLines = { }
			modLines = 0
			sourceImplicitLines = nil
			headerLineCount = 0
			base = nil
			baseReqLevel = 0
			includeBaseImplicits = true
			uniqueReqLevel = 0
		elseif not specName or (sourceImplicitLines and sourceImplicitLines > 0) then
			local prefix = ""
			local variantString = line:match("({variant:[%d,]+})")
			local fractured = line:match("({fractured})") or ""
			local modName, legacy = stripLineTags(line):match("^([%a%d_]+)([%[%]-,%d]*)$")
			local mod = base and (uniqueMods[modName] or modVeiled[modName])
			local rawMod = base and modName and dat("Mods"):GetRow("Id", modName)
			local modLevel = rawMod and rawMod.Level or mod and mod.level
			if modLevel then
				uniqueReqLevel = math.max(uniqueReqLevel, math.floor(modLevel * 0.8))
			end
			local grantedSkill = rawMod and dat("ModGrantedSkills"):GetRow("Mod", rawMod)
			local grantedSkillLine
			if grantedSkill then
				local skillName = grantedSkill.SkillGem.GemEffects[1].GrantedEffect.ActiveSkill.DisplayName
				local naturalMaxLevel = grantedSkill.SkillGem.IsSupport and 1 or #dat("ItemExperiencePerLevel"):GetRowList("ItemExperienceType", grantedSkill.SkillGem.GemLevelProgression)
				naturalMaxLevel = naturalMaxLevel > 0 and naturalMaxLevel or 1
				grantedSkillLine = "Grants Skill: "..(naturalMaxLevel == 1 and "" or "Level (1-"..naturalMaxLevel..") ")..skillName
			end
			local isSourceImplicit = sourceImplicitLines and sourceImplicitLines > 0
			if variantString then
				prefix = prefix ..variantString
			end
			if mod then
				modLines = modLines + 1
				if useCatalystTags then
					prefix = prefix..getCatalystTagPrefix(mod.modTags)
				end
				prefix = prefix..fractured
				local legacyMod
				if legacy ~= "" then
					local values = { }
					for range in legacy:gmatch("%b[]") do
						local min, max = range:match("%[([%d%-]+),([%d%-]+)%]")
						table.insert(values, { min = tonumber(min), max = tonumber(max) })
					end
					local mod = dat("Mods"):GetRow("Id", modName)
					local stats = { }
					for i = 1, 6 do
						if mod["Stat"..i] then
							stats[mod["Stat"..i].Id] = values[i]
						end
					end
					if mod.Type then
						stats.Type = mod.Type
					end
					legacyMod = describeStats(stats)
				end 
				for i, line in ipairs(legacyMod or mod) do
					local order = math.floor(mod.statOrder[i])
					local variantImplicitLines = variantString and variantBaseImplicitLines[modName]
					if variantString and not variantImplicitLines and base.implicit then
						for baseLine in base.implicit:gmatch("[^\n]+") do
							if stripLineTags(baseLine) == stripLineTags(line) then
								variantImplicitLines = { }
								variantBaseImplicitLines[modName] = variantImplicitLines
								variantBaseImplicitLines[stripLineTags(baseLine)] = variantImplicitLines
								break
							end
						end
					end
					if variantImplicitLines then
						table.insert(variantImplicitLines, prefix..line)
					else
						if isSourceImplicit then
							if isGrantedSkillLine(line) then
								table.insert(grantedSkillLines, prefix..line)
							else
								table.insert(implicitLines, prefix..line)
							end
						elseif statOrder[order] then
							table.insert(statOrder[order], prefix..line)
						else
							statOrder[order] = { prefix..line }
						end
					end
				end
				if grantedSkillLine then
					table.insert(grantedSkillLines, prefix..grantedSkillLine)
				end
			elseif grantedSkillLine then
				modLines = modLines + 1
				table.insert(grantedSkillLines, prefix..grantedSkillLine)
			else
				if modLines > 0 then -- treat as post line e.g. mirrored
					table.insert(postModLines, line)
				elseif isSourceImplicit then
					if isGrantedSkillLine(line) then
						table.insert(grantedSkillLines, line)
					else
						table.insert(implicitLines, line)
					end
				elseif not line:match("^Requires:? Level") then
					table.insert(lines, line)
					if line:match("%[%[") then
						headerLineCount = 0
						base = nil
					elseif headerLineCount then
						headerLineCount = headerLineCount + 1
						local parsedBaseName = headerLineCount > 1 and stripLineTags(line)
						local parsedBase = parsedBaseName and itemBases[parsedBaseName]
						if parsedBase then
							base = base or parsedBase
							if parsedBase.req.level then
								baseReqLevel = math.max(baseReqLevel, parsedBase.req.level)
							end
						end
					end
				end
			end
			if sourceImplicitLines and sourceImplicitLines > 0 then
				sourceImplicitLines = sourceImplicitLines - 1
			end
		else
			if specName == "Requires Level" then
				-- Requirement levels are derived from the base type and unique mod levels.
			elseif specName == "Base Implicits" then
				includeBaseImplicits = specVal ~= "false"
			elseif specName == "Implicits" then
				sourceImplicitLines = tonumber(specVal)
			else
				table.insert(lines, line)
			end
		end
	end
	writeLines(out, lines)
	out:close()
end

print("Unique text updated.")
