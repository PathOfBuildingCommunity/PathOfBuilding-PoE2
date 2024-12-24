---
--- Programmatically generated uniques live here.
--- Some uniques have to be generated because the amount of variable mods makes it infeasible to implement them manually.
--- As a result, they are forward compatible to some extent as changes to the variable mods are picked up automatically.
---

data.uniques.generated = { }

local excludedItemKeystones = {
}

local uniqueMods = LoadModule("Data/ModUnique")

do
	local againstMods = {
		{ mod = "UniqueJewelRadiusMana", name = "Mana", notable = false },
		{ mod = "UniqueJewelRadiusLife", name = "Life", notable = false },
		{ mod = "UniqueJewelRadiusIgniteDurationOnSelf", name = "Ignite Duration", notable = false },
		{ mod = "UniqueJewelRadiusFreezeDurationOnSelf", name = "Freeze Duration", notable = false },
		{ mod = "UniqueJewelRadiusShockDurationOnSelf", name = "Shock Duration", notable = false },
		{ mod = "UniqueJewelRadiusFireResistance", name = "Fire Resistance", notable = false },
		{ mod = "UniqueJewelRadiusColdResistance", name = "Cold Resistance", notable = false },
		{ mod = "UniqueJewelRadiusLightningResistance", name = "Lightning Resistance", notable = false },
		{ mod = "UniqueJewelRadiusChaosResistance", name = "Chaos Resistance", notable = false },
		{ mod = "UniqueJewelRadiusMaxFireResistance", name = "Max Fire Resistance", notable = true },
		{ mod = "UniqueJewelRadiusMaxColdResistance", name = "Max Cold Resistance", notable = true },
		{ mod = "UniqueJewelRadiusMaxLightningResistance", name = "Max Lightning Resistance", notable = true },
		{ mod = "UniqueJewelRadiusMaxChaosResistance", name = "Max Chaos Resistance", notable = true },
		{ mod = "UniqueJewelRadiusPercentStrenth", name = "Percent Strenth", notable = true },
		{ mod = "UniqueJewelRadiusPercentIntelligence", name = "Percent Intelligence", notable = true },
		{ mod = "UniqueJewelRadiusPercentDexterity", name = "Percent Dexterity", notable = true },
		{ mod = "UniqueJewelRadiusSpirit", name = "Spirit", notable = true },
		{ mod = "UniqueJewelRadiusDamageAsFire", name = "Damage As Fire", notable = true },
		{ mod = "UniqueJewelRadiusDamageAsCold", name = "Damage As Cold", notable = true },
		{ mod = "UniqueJewelRadiusDamageAsLightning", name = "Damage As Lightning", notable = true },
		{ mod = "UniqueJewelRadiusDamageAsChaos", name = "Damage As Chaos", notable = true },
	}
	local against = {
		"Against The Darkness",
		"Time-Lost Diamond",
		"Limited to: 1",
		"Radius: Large",
		"Has Alt Variant: true",
		"Selected Variant: 1",
		"Selected Alt Variant: 2",
	}
	for _, mod in ipairs(againstMods) do
		table.insert(against, "Variant: " .. mod.name)
	end
	local smallLine = "Small Passive Skills in Radius also grant "
	local notableLine = "Notable Passive Skills in Radius also grant "
	for index, mod in ipairs(againstMods) do
		table.insert(against, "{variant:" .. index .. "}" .. (mod.notable and notableLine or smallLine) .. uniqueMods[mod.mod][1])
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
