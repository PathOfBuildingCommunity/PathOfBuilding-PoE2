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

local uniqueMods = LoadModule("../Data/ModItemExlusive.lua")
for _, name in ipairs(itemTypes) do
	local out = io.open("../Data/Uniques/"..name..".lua", "w")
	for line in io.lines("Uniques/"..name..".lua") do
		local specName, _ = line:match("^([%a ]+): (.+)$")
		if not specName and line ~= "]],[[" then
			local variantString = line:match("({variant:[%d,]+})")
			local fractured = line:match("({fractured})") or ""
			local modName, legacy = line:gsub("{.+}", ""):match("^([%a%d_]+)([%[%]-,%d]*)")
			local mod = uniqueMods[modName]
			if mod then
				if variantString then
					out:write(variantString)
				end
				local tags = {}
				if isValueInArray({"amulet", "ring"}, name) then
					for _, tag in ipairs(mod.modTags) do
						if catalystTags[tag] then
							table.insert(tags, tag)
						end
					end
				end
				if tags[1] then
					out:write("{tags:" .. table.concat(tags, ",") .. "}")
				end
				out:write(fractured)
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
				out:write(table.concat(legacyMod or mod, "\n" .. (variantString or "")), "\n")
			else
				out:write(line, "\n")
			end
		else
			out:write(line, "\n")
		end
	end
	out:close()
end

print("Unique text updated.")
