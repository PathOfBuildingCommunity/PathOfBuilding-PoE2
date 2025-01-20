-- Path of Building
--
-- Module: Data
-- Contains static data used by other modules.
--

LoadModule("Data/Global")

local m_min = math.min
local m_max = math.max
local m_floor = math.floor
local t_insert = table.insert
local t_concat = table.concat

local skillTypes = {
	"act_str",
	"act_dex",
	"act_int",
	"other",
	"minion",
	"sup_str",
	"sup_dex",
	"sup_int",
}
local itemTypes = {
	"axe",
	"bow",
	"claw",
	"crossbow",
	"dagger",
	"fishing",
	"flail",
	"focus",
	"mace",
	"spear",
	"staff",
	"sceptre",
	"sword",
	"wand",
	"body",
	"gloves",
	"helmet",
	"boots",
	"shield",
	"quiver",
	"amulet",
	"ring",
	"belt",
	"jewel",
	"flask",
	"soulcore",
}

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
local function processMod(grantedEffect, mod)
	mod.source = grantedEffect.modSource
	if type(mod.value) == "table" and mod.value.mod then
		mod.value.mod.source = "Skill:"..grantedEffect.id
	end
	for _, tag in ipairs(mod) do
		if tag.type == "GlobalEffect" then
			grantedEffect.hasGlobalEffect = true
			break
		end
	end
end

-----------------
-- Common Data --
-----------------

-- These are semi-structured
----------------------------------------
-- Everything not in a later category
-- Item mods & jewel data
-- Boss data, skills and minions
-- Remaining Item Data and uniques
----------------------------------------

data = { }

-- Misc data tables
LoadModule("Data/Misc", data)

data.powerStatList = {
	{ stat=nil, label="Offence/Defence", combinedOffDef=true, ignoreForItems=true },
	{ stat=nil, label="Name", itemField="Name", ignoreForNodes=true, reverseSort=true, transform=function(value) return value:gsub("^The ","") end},
	{ stat="FullDPS", label="Full DPS" },
	{ stat="CombinedDPS", label="Combined DPS" },
	{ stat="TotalDPS", label="Hit DPS" },
	{ stat="WithImpaleDPS", label="Impale + Hit DPS" },
	{ stat="AverageDamage", label="Average Hit" },
	{ stat="Speed", label="Attack/Cast Speed" },
	{ stat="TotalDot", label="DoT DPS" },
	{ stat="BleedDPS", label="Bleed DPS" },
	{ stat="IgniteDPS", label="Ignite DPS" },
	{ stat="PoisonDPS", label="Poison DPS" },
	{ stat="Life", label="Life" },
	{ stat="LifeRegen", label="Life regen" },
	{ stat="LifeLeechRate", label="Life leech" },
	{ stat="Armour", label="Armour" },
	{ stat="Evasion", label="Evasion" },
	{ stat="EnergyShield", label="Energy Shield" },
	{ stat="EnergyShieldRecoveryCap", label="Recoverable ES" },
	{ stat="EnergyShieldRegen", label="Energy Shield regen" },
	{ stat="EnergyShieldLeechRate", label="Energy Shield leech" },
	{ stat="Mana", label="Mana" },
	{ stat="ManaRegen", label="Mana regen" },
	{ stat="ManaLeechRate", label="Mana leech" },
	{ stat="Ward", label="Ward" },
	{ stat="Str", label="Strength" },
	{ stat="Dex", label="Dexterity" },
	{ stat="Int", label="Intelligence" },
	{ stat="TotalAttr", label="Total Attributes" },
	{ stat="MeleeAvoidChance", label="Melee avoid chance" },
	{ stat="SpellAvoidChance", label="Spell avoid chance" },
	{ stat="ProjectileAvoidChance", label="Projectile avoid chance" },
	{ stat="TotalEHP", label="Effective Hit Pool" },
	{ stat="SecondMinimalMaximumHitTaken", label="Eff. Maximum Hit Taken" },
	{ stat="PhysicalTakenHit", label="Taken Phys dmg", transform=function(value) return -value end },
	{ stat="LightningTakenHit", label="Taken Lightning dmg", transform=function(value) return -value end },
	{ stat="ColdTakenHit", label="Taken Cold dmg", transform=function(value) return -value end },
	{ stat="FireTakenHit", label="Taken Fire dmg", transform=function(value) return -value end },
	{ stat="ChaosTakenHit", label="Taken Chaos dmg", transform=function(value) return -value end },
	{ stat="CritChance", label="Crit Chance" },
	{ stat="CritMultiplier", label="Crit Multiplier" },
	{ stat="BleedChance", label="Bleed Chance" },
	{ stat="FreezeChance", label="Freeze Chance" },
	{ stat="IgniteChance", label="Ignite Chance" },
	{ stat="ShockChance", label="Shock Chance" },
	{ stat="EffectiveMovementSpeedMod", label="Move speed" },
	{ stat="BlockChance", label="Block Chance" },
	{ stat="SpellBlockChance", label="Spell Block Chance" },
	{ stat="SpellSuppressionChance", label="Spell Suppression Chance" },
}

data.misc = { -- magic numbers
	ServerTickTime = 0.033,
	ServerTickRate = 1 / 0.033,
	AccuracyPerDexBase = 5,
	LowPoolThreshold = 0.35,
	TemporalChainsEffectCap = 75,
	BuffExpirationSlowCap = 0.25,
	DamageReductionCap = 90,
	ResistFloor = -200,
	MaxResistCap = 90,
	EvadeChanceCap = 95,
	DodgeChanceCap = 75,
	BlockChanceCap = 90,
	SuppressionChanceCap = 100,
	SuppressionEffect = 50,
	AvoidChanceCap = 75,
	ArmourRatio = 10,
	EnergyShieldRechargeBase = 0.125,
	EnergyShieldRechargeDelay = 4,
	WardRechargeDelay = 2,
	Transfiguration = 0.3,
	EnemyMaxResist = 75,
	LeechRateBase = 0.02,
	DotDpsCap = 35791394, -- (2 ^ 31 - 1) / 60 (int max / 60 seconds)
	BleedPercentBase = data.gameConstants["BleedingHitDamagePercentPerMinute"] / 60 / 100,
	BleedDurationBase = data.gameConstants["BaseBleedingDuration"],
	PoisonPercentBase = data.gameConstants["PoisonHitDamagePercentPerMinute"] / 60 / 100,
	PoisonDurationBase = data.gameConstants["BasePoisonDuration"],
	IgnitePercentBase = data.gameConstants["IgniteHitDamagePercentPerMinute"] / 60 / 100,
	IgniteDurationBase = data.gameConstants["BaseIgniteDuration"],
	ImpaleStoredDamageBase = 0.1,
	TrapTriggerRadiusBase = 10,
	MineDetonationRadiusBase = 60,
	MineAuraRadiusBase = 35,
	BrandAttachmentRangeBase = 30,
	ProjectileDistanceCap = 150,
	MinStunChanceNeeded = 20,
	StunBaseMult = 200,
	StunBaseDuration = 0.35,
	StunNotMeleeDamageMult = 0.75,
	MaxEnemyLevel = 85,
	maxExperiencePenaltyFreeAreaLevel = 70,
	experiencePenaltyMultiplier = 0.06,
	-- Expected values to calculate EHP
	stdBossDPSMult = 4 / 4.40,
	pinnacleBossDPSMult = 8 / 4.40,
	pinnacleBossPen = 15 / 5,
	uberBossDPSMult = 10 / 4.25,
	uberBossPen = 40 / 5,
	-- ehp helper function magic numbers
	ehpCalcSpeedUp = 8,
	-- max damage can be increased for more accuracy
	ehpCalcMaxDamage = 100000000,
	-- max iterations can be increased for more accuracy this should be perfectly accurate unless it runs out of iterations and so high eHP values will be underestimated.
	ehpCalcMaxIterationsToCalc = 50,
	-- maximum increase for stat weights, only used in trader for now.
	maxStatIncrease = 2, -- 100% increased
	-- PvP scaling used for hogm
	PvpElemental1 = 0.55,
	PvpElemental2 = 150,
	PvpNonElemental1 = 0.57,
	PvpNonElemental2 = 90,
}

data.skillColorMap = { colorCodes.STRENGTH, colorCodes.DEXTERITY, colorCodes.INTELLIGENCE, colorCodes.NORMAL }

do
	---@param areaLevel number
	---@return number
	local function effectiveMonsterLevel(areaLevel)
		--- Areas with area level above a certain penalty-free level are considered to have
		--- a scaling lower effective monster level for experience penalty calculations.
		if areaLevel <= data.misc.maxExperiencePenaltyFreeAreaLevel then
			return areaLevel
		end
		return areaLevel - triangular(areaLevel - data.misc.maxExperiencePenaltyFreeAreaLevel) * data.misc.experiencePenaltyMultiplier
	end

	---@type table<number, number>
	data.monsterExperienceLevelMap = {}
	-- to max enemy level + 2 to keep functionality the same
	for i = 1, (data.misc.MaxEnemyLevel + 2) do
		data.monsterExperienceLevelMap[i] = effectiveMonsterLevel(i)
	end
end

data.cursePriority = {
	["Temporal Chains"] = 1, -- Despair and Elemental Weakness override Temporal Chains.
	["Enfeeble"] = 2, -- Elemental Weakness and Vulnerability override Enfeeble.
	["Vulnerability"] = 3, -- Despair and Elemental Weakness override Vulnerability. Vulnerability was reworked in 3.1.0.
	["Elemental Weakness"] = 4, -- Despair and Flammability override Elemental Weakness.
	["Flammability"] = 5, -- Frostbite overrides Flammability.
	["Frostbite"] = 6, -- Conductivity overrides Frostbite.
	["Conductivity"] = 7,
	["Despair"] = 8, -- Despair was created in 3.1.0.
	["Punishment"] = 9, -- Punishment was reworked in 3.12.0.
	["Warlord's Mark"] = 10,
	["Assassin's Mark"] = 11,
	["Sniper's Mark"] = 12,
	["Poacher's Mark"] = 13,
	["SocketPriorityBase"] = 100,
	["Weapon 1"] = 1000,
	["Amulet"] = 2000,
	["Helmet"] = 3000,
	["Weapon 2"] = 4000,
	["Body Armour"] = 5000,
	["Gloves"] = 6000,
	["Boots"] = 7000,
	["Ring 1"] = 8000,
	["Ring 2"] = 9000,
	["CurseFromEquipment"] = 10000,
	["CurseFromAura"] = 20000,
}

---@type string[] @List of all keystones not exclusive to timeless jewels.
data.keystones = {
	"Acrobatics",
	"Ancestral Bond",
	"Avatar of Fire",
	"Blood Magic",
	"Bulwark",
	"Chaos Inoculation",
	"Conduit",
	"Dance with Death",
	"Eldritch Battery",
	"Elemental Equilibrium",
	"Eternal Youth",
	"Giant's Blood",
	"Glancing Blows",
	"Heartstopper",
	"Iron Reflexes",
	"Mind Over Matter",
	"Necromantic Talisman",
	"Oasis",
	"Pain Attunement",
	"Resolute Technique",
	"Resonance",
	"Unwavering Stance",
	"Vaal Pact",
	"Whispers of Doom",
	"Zealot's Oath",
}

data.ailmentTypeList = { "Bleed", "Poison", "Ignite", "Chill", "Freeze", "Shock" }
data.elementalAilmentTypeList = { "Ignite", "Chill", "Freeze", "Shock" }
data.nonDamagingAilmentTypeList = { "Chill", "Freeze", "Shock" }
data.nonElementalAilmentTypeList = { "Bleed", "Poison" }

data.nonDamagingAilment = {
	["Chill"] = { associatedType = "Cold", alt = false, default = 10, min = 5, max = data.gameConstants["ChillMaxEffect"], precision = 0, duration = data.gameConstants["BaseChillDuration"] },
	["Freeze"] = { associatedType = "Cold", alt = false, default = nil, min = 0.3, max = 3, precision = 2, duration = data.gameConstants["FreezeDuration"] },
	["Shock"] = { associatedType = "Lightning", alt = false, default = 15, min = 5, max = 50, precision = 0, duration = data.gameConstants["BaseShockDuration"] },
}

-- Used in ModStoreClass:ScaleAddMod(...) to identify high precision modifiers
data.defaultHighPrecision = 1
data.modScalability = LoadModule("Data/ModScalability")
data.highPrecisionMods = {
	["CritChance"] = {
		["BASE"] = 2,
	},
	["SelfCritChance"] = {
		["BASE"] = 2,
	},
	["LifeRegenPercent"] = {
		["BASE"] = 2,
	},
	["ManaRegenPercent"] = {
		["BASE"] = 2,
	},
	["EnergyShieldRegenPercent"] = {
		["BASE"] = 2,
	},
	["LifeRegen"] = {
		["BASE"] = 1,
	},
	["ManaRegen"] = {
		["BASE"] = 1,
	},
	["EnergyShieldRegen"] = {
		["BASE"] = 1,
	},
	["RageRegen"] = {
		["BASE"] = 1,
	},
	["LifeDegenPercent"] = {
		["BASE"] = 2,
	},
	["ManaDegenPercent"] = {
		["BASE"] = 2,
	},
	["EnergyShieldDegenPercent"] = {
		["BASE"] = 2,
	},
	["LifeDegen"] = {
		["BASE"] = 1,
	},
	["ManaDegen"] = {
		["BASE"] = 1,
	},
	["EnergyShieldDegen"] = {
		["BASE"] = 1,
	},
	["DamageLifeLeech"] = {
		["BASE"] = 2,
	},
	["PhysicalDamageLifeLeech"] = {
		["BASE"] = 2,
	},
	["ElementalDamageLifeLeech"] = {
		["BASE"] = 2,
	},
	["FireDamageLifeLeech"] = {
		["BASE"] = 2,
	},
	["ColdDamageLifeLeech"] = {
		["BASE"] = 2,
	},
	["LightningDamageLifeLeech"] = {
		["BASE"] = 2,
	},
	["ChaosDamageLifeLeech"] = {
		["BASE"] = 2,
	},
	["DamageManaLeech"] = {
		["BASE"] = 2,
	},
	["PhysicalDamageManaLeech"] = {
		["BASE"] = 2,
	},
	["ElementalDamageManaLeech"] = {
		["BASE"] = 2,
	},
	["FireDamageManaLeech"] = {
		["BASE"] = 2,
	},
	["ColdDamageManaLeech"] = {
		["BASE"] = 2,
	},
	["LightningDamageManaLeech"] = {
		["BASE"] = 2,
	},
	["ChaosDamageManaLeech"] = {
		["BASE"] = 2,
	},
	["DamageEnergyShieldLeech"] = {
		["BASE"] = 2,
	},
	["PhysicalDamageEnergyShieldLeech"] = {
		["BASE"] = 2,
	},
	["ElementalDamageEnergyShieldLeech"] = {
		["BASE"] = 2,
	},
	["FireDamageEnergyShieldLeech"] = {
		["BASE"] = 2,
	},
	["ColdDamageEnergyShieldLeech"] = {
		["BASE"] = 2,
	},
	["LightningDamageEnergyShieldLeech"] = {
		["BASE"] = 2,
	},
	["ChaosDamageEnergyShieldLeech"] = {
		["BASE"] = 2,
	},
	["SupportManaMultiplier"] = {
		["MORE"] = 4,
	},
}

data.weaponTypeInfo = {
	["None"] = { oneHand = true, melee = true, flag = "Unarmed" },
	["Bow"] = { oneHand = false, melee = false, flag = "Bow" },
	["Crossbow"] = { oneHand = false, melee = false, flag = "Crossbow" },
	["Claw"] = { oneHand = true, melee = true, flag = "Claw" },
	["Dagger"] = { oneHand = true, melee = true, flag = "Dagger" },
	["Spear"] = { oneHand = true, melee = true, flag = "Spear" },
	["Staff"] = { oneHand = false, melee = true, flag = "Staff", label = "Quarterstaff" },
	["Wand"] = { oneHand = true, melee = false, flag = "Wand" },
	["One Handed Axe"] = { oneHand = true, melee = true, flag = "Axe" },
	["One Handed Mace"] = { oneHand = true, melee = true, flag = "Mace" },
	["One Handed Sword"] = { oneHand = true, melee = true, flag = "Sword" },
	["Thrusting One Handed Sword"] = { oneHand = true, melee = true, flag = "Sword", label = "One Handed Sword" },
	["Fishing Rod"] = { oneHand = false, melee = true, flag = "Fishing" },
	["Two Handed Axe"] = { oneHand = false, melee = true, flag = "Axe" },
	["Two Handed Mace"] = { oneHand = false, melee = true, flag = "Mace" },
	["Two Handed Sword"] = { oneHand = false, melee = true, flag = "Sword" },
}
data.unarmedWeaponData = {
	[0] = { type = "None", AttackRate = 1.2, CritChance = 0, PhysicalMin = 2, PhysicalMax = 6 }, -- Scion
	[1] = { type = "None", AttackRate = 1.2, CritChance = 0, PhysicalMin = 2, PhysicalMax = 8 }, -- Marauder
	[2] = { type = "None", AttackRate = 1.2, CritChance = 0, PhysicalMin = 2, PhysicalMax = 5 }, -- Ranger
	[3] = { type = "None", AttackRate = 1.2, CritChance = 0, PhysicalMin = 2, PhysicalMax = 5 }, -- Witch
	[4] = { type = "None", AttackRate = 1.2, CritChance = 0, PhysicalMin = 2, PhysicalMax = 6 }, -- Duelist
	[5] = { type = "None", AttackRate = 1.2, CritChance = 0, PhysicalMin = 2, PhysicalMax = 6 }, -- Templar
	[6] = { type = "None", AttackRate = 1.2, CritChance = 0, PhysicalMin = 2, PhysicalMax = 5 }, -- Shadow
}

data.setJewelRadiiGlobally = function(treeVersion)
	local tMajor, tMinor = treeVersion:match("(%d+)_(%d+)")
	tMajor, tMinor = tonumber(tMajor), tonumber(tMinor)

	local sMajor, sMinor = nil, nil

	for version, _ in pairs(data.jewelRadii) do
		local jMajor, jMinor = version:match("(%d+)_(%d+)")
		jMajor, jMinor = tonumber(jMajor), tonumber(jMinor)

		if (jMajor < tMajor) or (jMajor == tMajor and jMinor <= tMinor) then
			if not sMajor or (jMajor > sMajor) or (jMajor == sMajor and jMinor > sMinor) then
				sMajor, sMinor = jMajor, jMinor
			end
		end
	end
	data.jewelRadius = data.jewelRadii[sMajor.."_"..sMinor]

	local maxJewelRadius = 0
	for _, radiusInfo in ipairs(data.jewelRadius) do
		radiusInfo.outerSquared = radiusInfo.outer * radiusInfo.outer * data.gameConstants["PassiveTreeJewelDistanceMultiplier"] * data.gameConstants["PassiveTreeJewelDistanceMultiplier"]
		radiusInfo.innerSquared = radiusInfo.inner * radiusInfo.inner * data.gameConstants["PassiveTreeJewelDistanceMultiplier"] * data.gameConstants["PassiveTreeJewelDistanceMultiplier"]

		if radiusInfo.outer > maxJewelRadius then
			maxJewelRadius = radiusInfo.outer * data.gameConstants["PassiveTreeJewelDistanceMultiplier"]
		end
	end
	data.maxJewelRadius = maxJewelRadius
end

data.jewelRadii = {
	["0_1"] = {
		{ inner = 0, outer = 1000, col = "^xBB6600", label = "Small" },
		{ inner = 0, outer = 1150, col = "^x66FFCC", label = "Medium" },
		{ inner = 0, outer = 1300, col = "^x2222CC", label = "Large" },
		{ inner = 0, outer = 1500, col = "^xC100FF", label = "Very Large" },

		{ inner = 650, outer = 950, col = "^xD35400", label = "Variable" },
		{ inner = 800, outer = 1100, col = "^x66FFCC", label = "Variable" },
		{ inner = 950, outer = 1250, col = "^x2222CC", label = "Variable" },
		{ inner = 1100, outer = 1400, col = "^xC100FF", label = "Variable" },
		{ inner = 1250, outer = 1550, col = "^x0B9300", label = "Variable" },
		{ inner = 1400, outer = 1700, col = "^xFFCC00", label = "Variable" },
		{ inner = 1650, outer = 1950, col = "^xFF6600", label = "Variable" },
		{ inner = 1800, outer = 2100, col = "^x0099FF", label = "Variable" },
	}
}

data.jewelRadius = data.setJewelRadiiGlobally(latestTreeVersion)

-- Stat descriptions
data.describeStats = LoadModule("Modules/StatDescriber")

-- Load item modifiers
data.itemMods = {
	Item = LoadModule("Data/ModItem"),
	Flask = LoadModule("Data/ModFlask"),
	Charm = LoadModule("Data/ModCharm"),
	Jewel = LoadModule("Data/ModJewel"),
	Corruption = LoadModule("Data/ModCorrupted"),
	Runes = LoadModule("Data/ModRunes")
}

data.costs = LoadModule("Data/Costs")
do
	local map = { }
	for i, value in ipairs(data.costs) do
		map[value.Resource] = i
	end
	setmetatable(data.costs, { __index = function(t, k) return t[map[k]] end })
end
data.mapMods = LoadModule("Data/ModMap")

-- Manually seeded modifier tag against item slot table for Mastery Item Condition based modifiers
-- Data is informed by getTagBasedModifiers() located in Item.lua
data.itemTagSpecial = {
	["life"] = {
		["body armour"] = {
			-- Keystone
			"Blood Magic",
			"Eternal Youth",
			"Ghost Reaver",
			"Mind Over Matter",
			"The Agnostic",
			"Vaal Pact",
			"Zealot's Oath",
			-- Special Cases
			"^Cannot Leech$",
		},
	},
	["evasion"] = {
		["ring"] = {
			-- Delve
			"chance to Evade",
			-- Unique
			"Cannot Evade",
		},
	},
}
data.itemTagSpecialExclusionPattern = {
	["life"] = {
		["amulet"] = {
			"lower Life on Hit", -- The Eternal Struggle
			"your Spectres' Life", -- The Jinxed Juju
			"when on Full Life",
			"when on Low Life",
			"^Allocates",
		},
		["body armour"] = {
			"Life as Physical Damage",
			"Life as Extra Maximum Energy Shield",
			"maximum Life as Fire Damage",
			"when on Full Life",
			"when on Low Life",
			"Gain Maximum Life instead of Maximum Energy Shield",
			"^Socketed Gems are Supported by Level",
			"^Allocates",
		},
		["boots"] = {
			"Enemy's Life", -- Legacy of Fury
			"^Enemies Cannot Leech Life", -- Sin Trek
			"when on Full Life",
			"when on Low Life",
			"^Allocates",
		},
		["belt"] = {
			"Life as Extra Maximum Energy Shield", -- Soul Tether
			"Life Recovery from Flasks", -- The Druggery
			"Life Flasks gain", -- The Druggery
			"when on Full Life",
			"when on Low Life",
			"^Allocates",
		},
		["gloves"] = {
			"maximum Life as Physical Damage", -- Haemophilia
			"Traps Cost Life", -- Slavedriver's Hand
			"when on Full Life",
			"when on Low Life",
			"^Allocates",
		},
		["helmet"] = {
			"Recouped as Life", -- Flame Exarch
			"Life when you Suppress", -- Elevore
			"Leech when on Low Life", -- Deidbell
			"while no Life is Reserved", -- Malachai's Awakening
			"^Socketed Gems are Supported by Level", -- Shako
			"when on Full Life",
			"when on Low Life",
			"^Allocates",
		},
		["ring 1"] = {
			"Energy Shield instead of Life", -- Valyrium
			"increased Damage while Leeching Life", -- Synthesis Implicit
			"when on Full Life",
			"when on Low Life",
			"^Allocates",
		},
		["ring 2"] = {
			"Energy Shield instead of Life", -- Valyrium
			"increased Damage while Leeching Life", -- Synthesis Implicit
			"when on Full Life",
			"when on Low Life",
			"^Allocates",
		},
		["weapon 1"] = {
			"^Socketed Gems are Supported by Level", -- Hiltless, etc
			"maximum Life as Chaos Damage", -- Obliteration
			"total Maximum Life and Energy Shield as Fire Damage", -- Oni-Goroshi
			"Life as Physical Damage", -- Crucible/Synthesis
			"maximum Life as Fire Damage", -- Crucible
			"when on Full Life",
			"when on Low Life",
			"^Allocates",

		},
		["weapon 2"] = {
			"maximum Life as Chaos Damage", -- Obliteration
			"^Socketed Gems Cost and Reserve Life", -- Prism Guardian
			"increased Damage while Leeching Life", -- Synthesis Implicit ~ Quivers
			"Life as Physical Damage", -- Crucible/Synthesis
			"maximum Life as Fire Damage", -- Crucible
			"when on Full Life",
			"when on Low Life",
			"^Allocates",
		}
	},
	["evasion"] = {
		["ring"] = {
		},
	},
}

-- Load bosses
do 
	data.bosses = { }
	LoadModule("Data/Bosses", data.bosses)
	
	local count, uberCount = 0, 0
	local armourTotal, evasionTotal = 0, 0
	local uberArmourTotal, uberEvasionTotal = 0, 0

	for _, boss in pairs(data.bosses) do
		if boss.isUber then
			uberCount = uberCount + 1
			uberArmourTotal = uberArmourTotal + boss.armourMult
			uberEvasionTotal = uberEvasionTotal + boss.evasionMult
		end
		count = count + 1
		armourTotal = armourTotal + boss.armourMult
		evasionTotal = evasionTotal + boss.evasionMult
	end

	data.bossStats = {
		PinnacleArmourMean = 100 + armourTotal / count,
		PinnacleEvasionMean = 100 + evasionTotal / count,
		UberArmourMean = 100 + uberArmourTotal / uberCount,
		UberEvasionMean = 100 + uberEvasionTotal / uberCount
	}

	data.bossSkills, data.bossSkillsList = LoadModule("Data/BossSkills")

	data.enemyIsBossTooltip = [[Bosses' damage is monster damage scaled to an average damage of their attacks
This is divided by 4.40 to represent 4 damage types + some (40% as much) ^xD02090chaos
^7Fill in the exact damage numbers if more precision is needed

Bosses' armour and evasion multiplier are calculated using the average of the boss type

Standard Boss adds the following modifiers:
	+30% to enemy Elemental Resistances
	^7]]..tostring(m_floor(data.misc.stdBossDPSMult * 100))..[[% of monster Damage of each type
	]]..tostring(m_floor(data.misc.stdBossDPSMult * 4.4 * 100))..[[% of monster Damage total

Guardian / Pinnacle Boss adds the following modifiers:
	+50% to enemy Elemental Resistances
	^7]]..tostring(m_floor(data.bossStats.PinnacleArmourMean))..[[% of monster Armour
	]]..tostring(m_floor(data.bossStats.PinnacleEvasionMean))..[[% of monster ^x33FF77Evasion
	^7]]..tostring(m_floor(data.misc.pinnacleBossDPSMult * 100))..[[% of monster Damage of each type
	]]..tostring(m_floor(data.misc.pinnacleBossDPSMult * 4.4 * 100))..[[% of monster Damage total
	]]..tostring(data.misc.pinnacleBossPen)..[[% penetration

Uber Pinnacle Boss adds the following modifiers:
	+50% to enemy Elemental Resistances
	^7]]..tostring(m_floor(data.bossStats.UberArmourMean))..[[% of monster Armour
	]]..tostring(m_floor(data.bossStats.UberEvasionMean))..[[% of monster ^x33FF77Evasion
	^770% less to enemy Damage taken
	]]..tostring(m_floor(data.misc.uberBossDPSMult * 100))..[[% of monster Damage of each type
	]]..tostring(m_floor(data.misc.uberBossDPSMult * 4.25 * 100))..[[% of monster Damage total
	]]..tostring(data.misc.uberBossPen)..[[% penetration]]
end

-- Load skills
data.skills = { }
data.skillStatMap = LoadModule("Data/SkillStatMap", makeSkillMod, makeFlagMod, makeSkillDataMod)
data.skillStatMapMeta = {
	__index = function(t, key)
		local map = data.skillStatMap[key]
		if map then
			map = copyTable(map)
			t[key] = map
			for _, mod in ipairs(map) do
				processMod(t._grantedEffect, mod)
			end
			return map
		end
	end
}
for _, type in pairs(skillTypes) do
	LoadModule("Data/Skills/"..type, data.skills, makeSkillMod, makeFlagMod, makeSkillDataMod)
end
for skillId, grantedEffect in pairs(data.skills) do
	grantedEffect.name = sanitiseText(grantedEffect.name)
	grantedEffect.id = skillId
	grantedEffect.modSource = "Skill:"..skillId
	-- Add sources for skill mods, and check for global effects
	for _, skillPart in pairs(tableConcat({grantedEffect}, grantedEffect.statSets or {})) do
		for _, list in pairs({skillPart.baseMods, skillPart.qualityMods, skillPart.levelMods}) do
			for _, mod in pairs(list) do
				if mod.name then
					processMod(grantedEffect, mod)
				else
					for _, mod in ipairs(mod) do
						processMod(grantedEffect, mod)
					end
				end
			end
		end
	end
	-- Install stat map metatable
	for _, statSet in pairs(tableConcat({grantedEffect}, grantedEffect.statSets or {})) do
		statSet.statMap = statSet.statMap or { }
		setmetatable(statSet.statMap, data.skillStatMapMeta)
		statSet.statMap._grantedEffect = grantedEffect
		for _, map in ipairs(statSet.statMap or {}) do
			-- Some mods need different scalars for different stats, but the same value.  Putting them in a group allows this
			for _, modOrGroup in ipairs(map) do
				if modOrGroup.name then
					processMod(grantedEffect, modOrGroup)
				else
					for _, mod in ipairs(modOrGroup) do
						processMod(grantedEffect, mod)
					end
				end
			end
		end
	end
end

-- Load gems
data.gems = LoadModule("Data/Gems")
data.gemForSkill = { }
data.gemForBaseName = { }
data.gemsByGameId = { }
-- Lookup table - [Gem.grantedEffectId] = VaalGemId
data.gemGrantedEffectIdForVaalGemId = { }
data.gemVaalGemIdForBaseGemId = { }
local function setupGem(gem, gemId)
	gem.id = gemId
	gem.grantedEffect = data.skills[gem.grantedEffectId]
	data.gemForSkill[gem.grantedEffect] = gemId
	data.gemsByGameId[gem.gameId] = data.gemsByGameId[gem.gameId] or {}
	data.gemsByGameId[gem.gameId][gem.variantId] = gem
	local baseName = gem.name
	if gem.grantedEffect.support and gem.grantedEffectId ~= "SupportBarrage" then
		baseName = baseName .. " Support"
	end
	data.gemForBaseName[baseName:lower()] = gemId
	-- Hybrid gems (e.g. Vaal gems) use the display name of the active skill e.g. Vaal Summon Skeletons of Sorcery
	if gem.baseTypeName and gem.baseTypeName ~= baseName then
		data.gemForBaseName[gem.baseTypeName:lower()] = gemId
	end
	gem.additionalGrantedEffects = {}
	gem.grantedEffectList = {
		gem.grantedEffect,
	}
	local i = 1
	while gem["additionalGrantedEffectId"..i] do
		table.insert(gem.grantedEffectList, data.skills[gem["additionalGrantedEffectId"..i]])
		table.insert(gem.additionalGrantedEffects, data.skills[gem["additionalGrantedEffectId"..i]])
		i = i + 1
	end
	gem.naturalMaxLevel = gem.naturalMaxLevel or (#gem.grantedEffect.levels > 20 and #gem.grantedEffect.levels - 20) or (gem.grantedEffect.levels[3][1] and 3) or 1
end

local toAddGems = { }
for gemId, gem in pairs(data.gems) do
    gem.name = sanitiseText(gem.name)
    setupGem(gem, gemId)
    local loc, _ = gemId:find('Vaal')
	if loc then
		data.gemGrantedEffectIdForVaalGemId[gem.secondaryGrantedEffectId] = gemId
		for otherGemId, otherGem in pairs(data.gems) do
			if otherGem.grantedEffectId == gem.secondaryGrantedEffectId then
				data.gemVaalGemIdForBaseGemId[gemId] = otherGemId 
				break
			end
		end
	end
end
for id, gem in pairs(toAddGems) do
    data.gems[id] = gem
end

-- Load minions
data.minions = { }
LoadModule("Data/Minions", data.minions, makeSkillMod, makeFlagMod)
data.spectres = { }
LoadModule("Data/Spectres", data.spectres, makeSkillMod, makeFlagMod)
for name, spectre in pairs(data.spectres) do
	spectre.limit = "ActiveSpectreLimit"
	data.minions[name] = spectre
end
for _, minion in pairs(data.minions) do
	for _, mod in ipairs(minion.modList) do
		mod.source = "Minion:"..minion.name
	end
end
data.printMissingMinionSkills = function()
	local missing = { }
	for _, minion in pairs(data.minions) do
		for _, skillId in ipairs(minion.skillList) do
			if not data.skills[skillId] and not missing[skillId] then
				--ConPrintf("'%s' missing skill '%s'", minion.name, skillId)
				missing[skillId] = true
			end
		end
	end
end

-- Item bases
data.itemBases = { }
for _, type in pairs(itemTypes) do
	LoadModule("Data/Bases/"..type, data.itemBases)
end

-- Build lists of item bases, separated by type
data.itemBaseLists = { }
for name, base in pairs(data.itemBases) do
	if not base.hidden then
		local type = base.type
		if base.subType then
			type = type .. ": " .. base.subType
		end
		data.itemBaseLists[type] = data.itemBaseLists[type] or { }
		table.insert(data.itemBaseLists[type], { label = name:gsub(" %(.+%)",""), name = name, base = base })
	end
end
data.itemBaseTypeList = { }
for type, list in pairs(data.itemBaseLists) do
	table.insert(data.itemBaseTypeList, type)
	table.sort(list, function(a, b)
		if a.base.req and b.base.req then
			if a.base.req.level == b.base.req.level then
				return a.name < b.name
			else
				return (a.base.req.level or 1) > (b.base.req.level or 1)
			end
		elseif a.base.req and not b.base.req then
			return true
		elseif b.base.req and not a.base.req then
			return false
		else
			return a.name < b.name
		end
	end)
end
table.sort(data.itemBaseTypeList)

-- Rare templates
--data.rares = LoadModule("Data/Rares")

-- Uniques (loaded after version-specific data because reasons)
data.uniques = { }
for _, type in pairs(itemTypes) do
	data.uniques[type] = LoadModule("Data/Uniques/"..type)
end
data.uniques['race'] = LoadModule("Data/Uniques/Special/race")
LoadModule("Data/Uniques/Special/Generated")
LoadModule("Data/Uniques/Special/New")

data.questRewards = LoadModule("Data/QuestRewards")
