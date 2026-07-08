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
}
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
	for _, order in pairs(orders) do
		for _, line in ipairs(statOrder[order]) do
			table.insert(lines, line)
		end
	end
end

local function stripLineTags(line)
	return (line:gsub("^({[^}]+})+", ""))
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
	local headerLineCount = 0
	local baseName
	local includeBaseImplicits = true
	local uniqueReqLevel = 0
	for line in io.lines("Uniques/"..name..".lua") do
		local specName, specVal = line:match("^([%a ]+): (.+)$")
		if line:match("]],") then -- start new unique
			local base = baseName and itemBases[baseName]
			local baseReqLevel = base and base.req.level or 0
			if uniqueReqLevel > baseReqLevel then
				table.insert(lines, "Requires Level "..uniqueReqLevel)
			end
			local baseImplicitLines = { }
			local finalImplicitLines = { }
			if includeBaseImplicits and base and base.implicit then
				local implicitIndex = 0
				for baseLine in base.implicit:gmatch("[^\n]+") do
					implicitIndex = implicitIndex + 1
					local prefix = ""
					if useCatalystTags then
						local tags = { }
						for _, tag in ipairs(base.implicitModTypes and base.implicitModTypes[implicitIndex] or { }) do
							if catalystTags[tag] then
								table.insert(tags, tag)
							end
						end
						if tags[1] then
							prefix = "{tags:"..table.concat(tags, ",").."}"
						end
					end
					for _, implicitLine in ipairs(variantBaseImplicitLines[stripLineTags(baseLine)] or { prefix..baseLine }) do
						if isGrantedSkillLine(implicitLine) then
							table.insert(finalImplicitLines, implicitLine)
						else
							table.insert(baseImplicitLines, implicitLine)
						end
					end
				end
			end
			for _, implicitLine in ipairs(grantedSkillLines) do
				table.insert(finalImplicitLines, implicitLine)
			end
			for _, implicitLine in ipairs(baseImplicitLines) do
				table.insert(finalImplicitLines, implicitLine)
			end
			for _, implicitLine in ipairs(implicitLines) do
				table.insert(finalImplicitLines, implicitLine)
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
			baseName = nil
			includeBaseImplicits = true
			uniqueReqLevel = 0
		elseif not specName or (sourceImplicitLines and sourceImplicitLines > 0) then
			local prefix = ""
			local variantString = line:match("({variant:[%d,]+})")
			local fractured = line:match("({fractured})") or ""
			local modName, legacy = line:gsub("{.+}", ""):match("^([%a%d_]+)([%[%]-,%d]*)")
			local mod = uniqueMods[modName] or modVeiled[modName]
			local rawMod = modName and dat("Mods"):GetRow("Id", modName)
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
				uniqueReqLevel = math.max(uniqueReqLevel, math.floor((mod.level or 0) * 0.8))
				local tags = {}
				if useCatalystTags then
					for _, tag in ipairs(mod.modTags) do
						if catalystTags[tag] then
							table.insert(tags, tag)
						end
					end
				end
				if tags[1] then
					prefix = prefix.."{tags:"..table.concat(tags, ",").."}"
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
					local baseImplicitLine
					if variantString then
						local base = baseName and itemBases[baseName]
						if base and base.implicit then
							for baseLine in base.implicit:gmatch("[^\n]+") do
								if stripLineTags(baseLine) == stripLineTags(line) then
									baseImplicitLine = stripLineTags(baseLine)
									variantBaseImplicitLines[baseImplicitLine] = variantBaseImplicitLines[baseImplicitLine] or { }
									table.insert(variantBaseImplicitLines[baseImplicitLine], prefix..line)
									break
								end
							end
						end
					end
					if not baseImplicitLine then
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
					uniqueReqLevel = math.max(uniqueReqLevel, math.floor((rawMod.Level or 0) * 0.8))
					table.insert(grantedSkillLines, prefix..grantedSkillLine)
				end
			elseif grantedSkillLine then
				modLines = modLines + 1
				uniqueReqLevel = math.max(uniqueReqLevel, math.floor((rawMod.Level or 0) * 0.8))
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
						baseName = nil
					else
						headerLineCount = headerLineCount + 1
						if headerLineCount == 2 then
							baseName = line
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
