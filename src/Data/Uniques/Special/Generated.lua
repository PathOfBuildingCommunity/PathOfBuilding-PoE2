---
--- Programmatically generated uniques live here.
--- Some uniques have to be generated because the amount of variable mods makes it infeasible to implement them manually.
--- As a result, they are forward compatible to some extent as changes to the variable mods are picked up automatically.
---

data.uniques.generated = { }

local excludedItemKeystones = {
}

local uniqueMods = data.itemMods.Exclusive

do
	local againstMods = { }
	for modName, mod in pairs(uniqueMods) do
		local name = modName:match("^UniqueJewelRadius(.+)$")
		if name then
			table.insert(againstMods, { mod = mod, name = name:gsub("([a-z])([A-Z])", "%1 %2"):gsub("Strenth", "Strength") })
		end
	end
	table.sort(againstMods, function(a, b) return a.name < b.name end)
	local against = {
		"Against the Darkness",
		"Time-Lost Diamond",
		"Source: Drops from unique{Zarokh, the Temporal}",
		"Limited to: 1",
		"Has Alt Variant: true",
	}
	for _, mod in ipairs(againstMods) do
		table.insert(against, "Variant: " .. mod.name)
	end
	local variantCount = #against
	table.insert(against, "Selected Variant: 1")
	table.insert(against, "Selected Alt Variant: 2")
	table.insert(against, "Radius: Small")
	table.insert(against, "Implicits: 0")
	local smallLine = "Small Passive Skills in Radius also grant "
	local notableLine = "Notable Passive Skills in Radius also grant "
	for index, mod in ipairs(againstMods) do
		if mod.mod.nodeType == 1 then
			table.insert(against, "{variant:" .. index .. "," .. variantCount .. "}" .. smallLine .. mod.mod[1])
		else
			table.insert(against, "{variant:" .. index .. "," .. variantCount .. "}" .. notableLine .. mod.mod[1])
		end
	end
	table.insert(data.uniques.generated, table.concat(against, "\n"))
end

do
	local fromNothingKeystones = {}
	for _, name in ipairs(data.keystones) do
		if not isValueInArray(excludedItemKeystones, name) then
			table.insert(fromNothingKeystones, name)
		end
	end
	local fromNothing = {
		"From Nothing",
		"Diamond",
		"Source: Drops from unique{The King in the Mists} in normal{Crux of Nothingness}",
		"Limited to: 1",
		"Radius: Small",
	}
	for _, name in ipairs(fromNothingKeystones) do
		table.insert(fromNothing, "Variant: " .. name)
	end
	table.insert(fromNothing, "Variant: Everything (QoL Test Variant)")
	local variantCount = #fromNothingKeystones + 1
	for index, name in ipairs(fromNothingKeystones) do
		table.insert(fromNothing, "{variant:" .. index .. "," .. variantCount .. "}Passives in radius of " .. name .. " can be Allocated without being connected to your tree")
	end
	table.insert(fromNothing, "Corrupted")
	table.insert(data.uniques.generated, table.concat(fromNothing, "\n"))
end

do
	local excludedGems = {
		"Detonate Minion",
		"Rhoa Mount",
	}
	local gems = { }
	for _, gemData in pairs(data.gems) do
		if not gemData.tags.support and not isValueInArray(excludedGems, gemData.name) and not gemData.grantedEffect.hidden and not gemData.grantedEffect.fromItem and not gemData.grantedEffect.fromTree then
			gemData.name = gemData.name:gsub("Spectre: {0}", "Summon Spectre"):gsub("Companion: {0}", "Tamed Companion")
			table.insert(gems, gemData.name)
		end
	end
	table.sort(gems)
	local prism = {
		"Prism of Belief",
		"Diamond",
		"Source: Drops from unique{Arbiter of Ash} in normal{The Burning Monolith}",
		"Limited to: 1",
	}
	for _, name in ipairs(gems) do
		table.insert(prism, "Variant: " .. name)
	end
	for index, name in ipairs(gems) do
		table.insert(prism, "{variant:" .. index .. "}+(1-3) to Level of all " .. name .. " Skills")
	end
	table.insert(prism, "Corrupted")
	table.insert(data.uniques.generated, table.concat(prism, "\n"))
end

local treedata = LoadModule("TreeData/" .. latestTreeVersion .. "/tree.lua")
local nodes = treedata.nodes

do
    local megalomaniac = {
        "Megalomaniac",
        "Diamond",
		"Source: Drops from unique{Kosis, The Revelation}",
        "Limited to: 1",
        "Has Alt Variant: true",
        "Has Alt Variant Two: true",
    }
    local megalomaniacMods = { }
    for _, node in pairs(nodes) do
        if node.isNotable == true and node.recipe then
            table.insert(megalomaniacMods, node)
        end
    end
    table.sort(megalomaniacMods, function(a, b) return a.name < b.name end)  -- Sort by name, if needed
    for _, node in ipairs(megalomaniacMods) do
        table.insert(megalomaniac, "Variant: " .. node.name)  -- Add the name of the node to megalomaniac
    end
    table.insert(megalomaniac, "Selected Variant: 1")
    table.insert(megalomaniac, "Selected Alt Variant: 2")
    table.insert(megalomaniac, "Selected Alt Variant: 3")
	for index, node in ipairs(megalomaniacMods) do
		table.insert(megalomaniac, "{variant:"..index.."}Allocates "..node.name)
	end
	table.insert(megalomaniac, "Corrupted")
    table.insert(data.uniques.generated, table.concat(megalomaniac, "\n"))
end

do
	local kulemakMods = { }
	for modName, mod in pairs(uniqueMods) do
		local name = modName:match("^PassageUnique(.+)$")
		if name then
			table.insert(kulemakMods, { 
				mod = mod, 
				name = name
					:gsub("([a-z])([A-Z])", "%1 %2")
					:gsub("(%d+)([A-Za-z])", " %1 %2") -- separate numbers from letters after
					:gsub("([A-Za-z])(%d+)", "%1 %2") -- separate letters from numbers before
			})
		end
	end
	table.sort(kulemakMods, function(a, b) return a.name < b.name end)
	local kulemak = {
		"Grip of Kulemak",
		"Abyssal Signet",
		"League: Rise of the Abyssal",
		"Has Alt Variant: true",
		"Has Alt Variant Two: true",
		"Has Alt Variant Three: true",
	}
	for _, mod in ipairs(kulemakMods) do
		table.insert(kulemak, "Variant: " .. mod.name)
	end
	table.insert(kulemak, "Selected Variant: 1")
	table.insert(kulemak, "Selected Alt Variant: 2")
	table.insert(kulemak, "Selected Alt Variant Two: 3")
	table.insert(kulemak, "Selected Alt Variant Three: 4")
	table.insert(kulemak, "Implicits: 1")
	table.insert(kulemak, "Inflict Abyssal Wasting on Hit")
	for index, mod in ipairs(kulemakMods) do
		table.insert(kulemak, "{variant:" .. index .. "}" .. mod.mod[1])
	end
	table.insert(data.uniques.generated, table.concat(kulemak, "\n"))
end

local veiledMods = LoadModule("Data/ModVeiled")

do
	local heartMods = { }
	for modName, mod in pairs(veiledMods) do
		local name = modName:match("^UniqueHeart(.+)$")
		if name then
			local displayName = name
				:gsub("([a-z])([A-Z])", "%1 %2")
				:gsub("(%d+)([A-Za-z])", " %1 %2") -- separate numbers from letters after
				:gsub("([A-Za-z])(%d+)", "%1 %2") -- separate letters from numbers before
				-- Hacky replacement as the Mod names don't match the stat type.
				:gsub("Gained As Lightning", "__TEMP_LIGHTNING__")
				:gsub("Gained As Chaos", "Gained As Lightning")
				:gsub("Gained As Cold", "Gained As Chaos")
				:gsub("__TEMP_LIGHTNING__", "Gained As Cold")
			table.insert(heartMods, {
				mod = mod,
				name = displayName
			})
		end
	end
	table.sort(heartMods, function(a, b) return a.name < b.name end)
	local heart = {
		"Heart of the Well",
		"Diamond",
		"League: Rise of the Abyssal",
		"Limited to: 1",
		"Has Alt Variant: true",
		"Has Alt Variant Two: true",
		"Has Alt Variant Three: true",
	}
	for _, mod in ipairs(heartMods) do
		table.insert(heart, "Variant: " .. mod.name)
	end
	table.insert(heart, "Selected Variant: 1")
	table.insert(heart, "Selected Alt Variant: 2")
	table.insert(heart, "Selected Alt Variant Two: 40")
	table.insert(heart, "Selected Alt Variant Three: 41")
	for index, mod in ipairs(heartMods) do
		table.insert(heart, "{variant:" .. index .. "}{desecrated}" .. mod.mod[1])
	end
	table.insert(data.uniques.generated, table.concat(heart, "\n"))
end
