---
--- Programmatically generated uniques live here.
--- Some uniques have to be generated because the amount of variable mods makes it infeasible to implement them manually.
--- As a result, they are forward compatible to some extent as changes to the variable mods are picked up automatically.
---

data.uniques.generated = { }

local excludedItemKeystones = {
}

local uniqueMods = LoadModule("Data/ModItemExclusive")

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
		"Limited to: 1",
		"Has Alt Variant: true",
	}
	for _, mod in ipairs(againstMods) do
		table.insert(against, "Variant: " .. mod.name)
	end
	local variantCount = #against
	table.insert(against, "Selected Variant: 1")
	table.insert(against, "Selected Alt Variant: 2")
	table.insert(against, "Radius: Large")
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
	}
	local gems = { }
	for _, gemData in pairs(data.gems) do
		if not gemData.tags.support and not isValueInArray(excludedGems, gemData.name) then
			table.insert(gems, gemData.name)
		end
	end
	table.sort(gems)
	local prism = {
		"Prism of Belief",
		"Diamond",
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
