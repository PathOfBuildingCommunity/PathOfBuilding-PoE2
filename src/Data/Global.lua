-- Path of Building
--
-- Module: Global
-- Global constants
--

colorCodes = {
	NORMAL = "^xC8C8C8",
	MAGIC = "^x8888FF",
	RARE = "^xFFFF77",
	UNIQUE = "^xAF6025",
	RELIC = "^x60C060",
	GEM = "^x1AA29B",
	PROPHECY = "^xB54BFF",
	CURRENCY = "^xAA9E82",
	ENCHANTED = "^xB8DAF1",
	CUSTOM = "^x5CF0BB",
	SOURCE = "^x88FFFF",
	UNSUPPORTED = "^xF05050",
	WARNING = "^xFF9922",
	TIP = "^x80A080",
	FIRE = "^xB97123",
	COLD = "^x3F6DB3",
	LIGHTNING = "^xADAA47",
	CHAOS = "^xD02090",
	POSITIVE = "^x33FF77",
	NEGATIVE = "^xDD0022",
	HIGHLIGHT ="^xFF0000",
	OFFENCE = "^xE07030",
	DEFENCE = "^x8080E0",
	SCION = "^xFFF0F0",
	MARAUDER = "^xE05030",
	WARRIOR = "^xE05030",
	RANGER = "^x70FF70",
	HUNTRESS = "^x70FF70",
	WITCH = "^x7070FF",
	SORCERESS = "^x7070FF",
	DUELIST = "^xE0E070",
	MERCENARY = "^xE0E070",
	TEMPLAR = "^xC040FF",
	DRUID = "^xC040FF",
	SHADOW = "^x30C0D0",
	MONK = "^x30C0D0",
	MAINHAND = "^x50FF50",
	MAINHANDBG = "^x071907",
	OFFHAND = "^xB7B7FF",
	OFFHANDBG = "^x070719",
	SHAPER = "^x55BBFF",
	ELDER = "^xAA77CC",
	FRACTURED = "^xA29160",
	ADJUDICATOR = "^xE9F831",
	BASILISK = "^x00CB3A",
	CRUSADER = "^x2946FC",
	EYRIE = "^xAAB7B8",
	CLEANSING = "^xF24141",
	TANGLE = "^x038C8C",
	CHILLBG = "^x151e26",
	FREEZEBG = "^x0c262b",
	SHOCKBG = "^x191732",
	SCORCHBG = "^x270b00",
	BRITTLEBG = "^x00122b",
	SAPBG = "^x261500",
	SCOURGE = "^xFF6E25",
	CRUCIBLE = "^xFFA500",
}
colorCodes.STRENGTH = colorCodes.MARAUDER
colorCodes.DEXTERITY = colorCodes.RANGER
colorCodes.INTELLIGENCE = colorCodes.WITCH

colorCodes.LIFE = colorCodes.MARAUDER
colorCodes.MANA = colorCodes.WITCH
colorCodes.SPIRIT = colorCodes.RARE
colorCodes.ES = colorCodes.SOURCE
colorCodes.WARD = colorCodes.RARE
colorCodes.ARMOUR = colorCodes.NORMAL
colorCodes.EVASION = colorCodes.POSITIVE
colorCodes.RAGE = colorCodes.WARNING
colorCodes.PHYS = colorCodes.NORMAL
colorCodes.DESECRATED = colorCodes.RELIC

defaultColorCodes = copyTable(colorCodes)
function updateColorCode(code, color)
 	if colorCodes[code] then
		colorCodes[code] = color:gsub("^0", "^")
		if code == "HIGHLIGHT" then
			rgbColor = hexToRGB(color)
		end
	end
end

function hexToRGB(hex)
	hex = hex:gsub("0x", "") -- Remove "0x" prefix
	hex = hex:gsub("#","") -- Remove '#' if present
	if #hex ~= 6 then
		return nil
	end
	local r = (tonumber(hex:sub(1, 2), 16)) / 255
	local g = (tonumber(hex:sub(3, 4), 16)) / 255
	local b = (tonumber(hex:sub(5, 6), 16)) / 255
	return {r, g, b}
end

-- NOTE: the LuaJIT bitwise operations we have are not 64-bit
-- so we need to implement them ourselves. Lua uses 53-bit doubles.
HIGH_MASK_53 = 0x1FFFFF
function OR64(...)
    local args = {...}
    if #args < 2 then
        return args[1] or 0
    end
    
    -- Start with first value
    local result = args[1]
    
    -- OR with each subsequent value
    for i = 2, #args do
        -- Split into high and low 32-bit parts
        local ah = math.floor(result / 0x100000000)
        local al = result % 0x100000000
        local bh = math.floor(args[i] / 0x100000000)
        local bl = args[i] % 0x100000000
        
        -- Perform OR operation on both parts
        local high = bit.bor(ah, bh)
        local low = bit.bor(al, bl)
        
        -- Combine the results
        result = bit.band(high, HIGH_MASK_53) * 0x100000000 + low
    end
    
    return result
end

function AND64(...)
    local args = {...}
    if #args < 2 then
        return args[1] or 0
    end
    
    -- Start with first value
    local result = args[1]
    
    -- AND with each subsequent value
    for i = 2, #args do
        -- Split into high and low 32-bit parts
        local ah = math.floor(result / 0x100000000)
        local al = result % 0x100000000
        local bh = math.floor(args[i] / 0x100000000)
        local bl = args[i] % 0x100000000
        
        -- Perform AND operation on both parts
        local high = bit.band(ah, bh)
        local low = bit.band(al, bl)
        
        -- Combine the results
        result = bit.band(high, HIGH_MASK_53) * 0x100000000 + low
    end
    
    return result
end

function XOR64(...)
    local args = {...}
    if #args < 2 then
        return args[1] or 0
    end
    
    -- Start with first value
    local result = args[1]
    
    -- XOR with each subsequent value
    for i = 2, #args do
        -- Split into high and low 32-bit parts
        local ah = math.floor(result / 0x100000000)
        local al = result % 0x100000000
        local bh = math.floor(args[i] / 0x100000000)
        local bl = args[i] % 0x100000000
        
        -- Perform XOR operation on both parts
        local high = bit.bxor(ah, bh)
        local low = bit.bxor(al, bl)
        
        -- Combine the results
        result = bit.band(high, HIGH_MASK_53) * 0x100000000 + low
    end
    
    return result
end

function NOT64(a)
    -- Split into high and low 32-bit parts
    local ah = math.floor(a / 0x100000000)
    local al = a % 0x100000000
    
    -- Perform NOT operation on both parts
    local high = bit.bnot(ah)
    local low = bit.bnot(al)
    
    -- Convert negative numbers to their unsigned equivalents
    if high < 0 then high = high + 0x100000000 end
    if low < 0 then low = low + 0x100000000 end
    
    -- Use bit operations to combine the results
    -- This avoids potential floating-point precision issues
    return bit.band(high, HIGH_MASK_53) * 0x100000000 + low
end

function strHex64(value)
    -- Split into high and low 32-bit parts
    local high = math.floor(value / 0x100000000)
    local low = value % 0x100000000
    
    -- Stringify as two 8-digit hex values
    return string.format("0x%08X%08X", high, low)
end

ModFlag = { }
-- Damage modes
ModFlag.Attack =	 0x0000000000000001
ModFlag.Spell =		 0x0000000000000002
ModFlag.Hit =		 0x0000000000000004
ModFlag.Dot =		 0x0000000000000008
ModFlag.Cast =		 0x0000000000000010
-- Damage sources
ModFlag.Melee =		 0x0000000000000100
ModFlag.Area =		 0x0000000000000200
ModFlag.Projectile = 0x0000000000000400
ModFlag.SourceMask = 0x0000000000000600
ModFlag.Ailment =	 0x0000000000000800
ModFlag.MeleeHit =	 0x0000000000001000
ModFlag.Weapon =	 0x0000000000002000
-- Weapon types
ModFlag.Axe =		 0x0000000000010000
ModFlag.Bow =		 0x0000000000020000
ModFlag.Claw =		 0x0000000000040000
ModFlag.Dagger =	 0x0000000000080000
ModFlag.Mace =		 0x0000000000100000
ModFlag.Staff =		 0x0000000000200000
ModFlag.Sword =		 0x0000000000400000
ModFlag.Wand =		 0x0000000000800000
ModFlag.Unarmed =	 0x0000000001000000
ModFlag.Fishing =	 0x0000000002000000
ModFlag.Crossbow =	 0x0000000004000000
ModFlag.Flail =		 0x0000000008000000
ModFlag.Spear =		 0x0000000010000000
-- Weapon classes
ModFlag.WeaponMelee =0x0000000100000000
ModFlag.WeaponRanged=0x0000000200000000
ModFlag.Weapon1H =	 0x0000000400000000
ModFlag.Weapon2H =	 0x0000000800000000
ModFlag.WeaponMask = 0x0000000F1FFF0000

KeywordFlag = { }
-- Skill keywords
KeywordFlag.Aura =		0x00000001
KeywordFlag.Curse =		0x00000002
KeywordFlag.Warcry =	0x00000004
KeywordFlag.Movement =	0x00000008
KeywordFlag.Physical =	0x00000010
KeywordFlag.Fire =		0x00000020
KeywordFlag.Cold =		0x00000040
KeywordFlag.Lightning =	0x00000080
KeywordFlag.Chaos =		0x00000100
KeywordFlag.Vaal =		0x00000200
KeywordFlag.Bow =		0x00000400
-- Skill types
KeywordFlag.Trap =		0x00001000
KeywordFlag.Mine =		0x00002000
KeywordFlag.Totem =		0x00004000
KeywordFlag.Minion =	0x00008000
KeywordFlag.Attack =	0x00010000
KeywordFlag.Spell =		0x00020000
KeywordFlag.Hit =		0x00040000
KeywordFlag.Ailment =	0x00080000
KeywordFlag.Brand =		0x00100000
-- Other effects
KeywordFlag.Poison =	0x00200000
KeywordFlag.Bleed =		0x00400000
KeywordFlag.Ignite =	0x00800000
-- Damage over Time types
KeywordFlag.PhysicalDot=0x01000000
KeywordFlag.LightningDot=0x02000000
KeywordFlag.ColdDot =	0x04000000
KeywordFlag.FireDot =	0x08000000
KeywordFlag.ChaosDot =	0x10000000
---The default behavior for KeywordFlags is to match *any* of the specified flags.
---Including the "MatchAll" flag when creating a mod will cause *all* flags to be matched rather than any.
KeywordFlag.MatchAll =	0x40000000

-- Helper function to compare KeywordFlags
local band = AND64
local bnot = NOT64
local MatchAllMask = bnot(KeywordFlag.MatchAll)
---@param keywordFlags number The KeywordFlags to be compared to.
---@param modKeywordFlags number The KeywordFlags stored in the mod.
---@return boolean Whether the KeywordFlags in the mod are satisfied.
function MatchKeywordFlags(keywordFlags, modKeywordFlags)
	local matchAll = band(modKeywordFlags, KeywordFlag.MatchAll) ~= 0
	modKeywordFlags = band(modKeywordFlags, MatchAllMask)
	keywordFlags = band(keywordFlags, MatchAllMask)
	if matchAll then
		return band(keywordFlags, modKeywordFlags) == modKeywordFlags
	end
	return modKeywordFlags == 0 or band(keywordFlags, modKeywordFlags) ~= 0
end

-- Active skill types, used in ActiveSkills.dat and GrantedEffects.dat
-- Names taken from ActiveSkillType.dat as of PoE 3.17
SkillType = {
	Attack = 1,
	Spell = 2,
	Projectile = 3, -- Specifically skills which fire projectiles
	DualWieldOnly = 4, -- Attack requires dual wielding, only used on Dual Strike
	Buff = 5,
	Minion = 6,
	Damage = 7, -- Skill hits (not used on attacks because all of them hit)
	Area = 8,
	Duration = 9,
	RequiresShield = 10,
	ProjectileSpeed = 11,
	HasReservation = 12,
	ReservationBecomesCost = 13,
	Trappable = 14, -- Skill can be turned into a trap
	Totemable = 15, -- Skill can be turned into a totem
	Mineable = 16, -- Skill can be turned into a mine
	ElementalStatus = 17, -- Causes elemental status effects, but doesn't hit (used on Herald of Ash to allow Elemental Proliferation to apply)
	MinionsCanExplode = 18,
	Chains = 19,
	Melee = 20,
	MeleeSingleTarget = 21,
	Multicastable = 22, -- Spell can repeat via Spell Echo
	TotemCastsAlone = 23,
	CausesBurning = 24, -- Deals burning damage
	SummonsTotem = 25,
	TotemCastsWhenNotDetached = 26,
	Physical = 27,
	Fire = 28,
	Cold = 29,
	Lightning = 30,
	Triggerable = 31,
	Triggers = 32,
	Trapped = 33,
	Movement = 34,
	DamageOverTime = 35,
	RemoteMined = 36,
	Triggered = 37,
	Vaal = 38,
	Aura = 39,
	CanTargetUnusableCorpse = 40, -- Doesn't appear to be used at all
	RangedAttack = 41,
	Chaos = 42,
	FixedSpeedProjectile = 43, -- Not used by any skill
	ThresholdJewelArea = 44, -- Allows Burning Arrow and Vigilant Strike to be supported by Inc AoE and Conc Effect
	ThresholdJewelProjectile = 45,
	ThresholdJewelDuration = 46, -- Allows Burning Arrow to be supported by Inc/Less Duration and Rapid Decay
	ThresholdJewelRangedAttack = 47,
	Channel = 48,
	DegenOnlySpellDamage = 49, -- Allows Contagion, Blight and Scorching Ray to be supported by Controlled Destruction
	InbuiltTrigger = 50, -- Skill granted by item that is automatically triggered, prevents trigger gems and trap/mine/totem from applying
	Golem = 51,
	Herald = 52,
	AuraAffectsEnemies = 53, -- Used by Death Aura, added by Blasphemy
	NoRuthless = 54,
	ThresholdJewelSpellDamage = 55,
	Cascadable = 56, -- Spell can cascade via Spell Cascade
	ProjectilesFromUser = 57, -- Skill can be supported by Volley
	MirageArcherCanUse = 58, -- Skill can be supported by Mirage Archer
	ProjectileSpiral = 59, -- Excludes Volley from Vaal Fireball and Vaal Spark
	SingleMainProjectile = 60, -- Excludes Volley from Spectral Shield Throw
	MinionsPersistWhenSkillRemoved = 61, -- Excludes Summon Phantasm on Kill from Manifest Dancing Dervish
	ProjectileNumber = 62, -- Allows LMP/GMP on Rain of Arrows and Toxic Rain
	Warcry = 63, -- Warcry
	Instant = 64, -- Instant cast skill
	Brand = 65,
	TargetsDestructibleCorpses = 66, -- Consumes corpses on use
	NonHitChill = 67,
	ChillingArea = 68,
	AppliesCurse = 69,
	Barrageable = 70,
	AuraDuration = 71,
	AreaSpell = 72,
	OR = 73,
	AND = 74,
	NOT = 75,
	AppliesMaim = 76,
	CreatesMinion = 77,
	Guard = 78,
	Travel = 79,
	Blink = 80,
	CanHaveBlessing = 81,
	ProjectilesNotFromUser = 82,
	AttackInPlaceIsDefault = 83,
	Nova = 84,
	InstantNoRepeatWhenHeld = 85,
	InstantShiftAttackForLeftMouse = 86,
	AuraNotOnCaster = 87,
	Banner = 88,
	Rain = 89,
	Cooldown = 90,
	ThresholdJewelChaining = 91,
	Slam = 92,
	Stance = 93,
	NonRepeatable = 94, -- Blood and Sand + Flesh and Stone
	UsedByTotem = 95,
	Steel = 96,
	Hex = 97,
	Mark = 98,
	Aegis = 99,
	Orb = 100,
	KillNoDamageModifiers = 101,
	RandomElement = 102, -- means elements cannot repeat
	LateConsumeCooldown = 103,
	Arcane = 104, -- means it is reliant on amount of mana spent
	FixedCastTime = 105,
	RequiresOffHandNotWeapon = 106,
	Link = 107,
	Blessing = 108,
	ZeroReservation = 109,
	DynamicCooldown = 110,
	Microtransaction = 111,
	OwnerCannotUse = 112,
	ProjectilesNumberModifiersNotApplied = 113,
	TotemsAreBallistae = 114,
	SkillGrantedBySupport = 115,
	CrossbowSkill = 116,
	CrossbowAmmoSkill = 117,
	UseGlobalStats = 118,
	ModifiesNextSkill = 119,
	OngoingSkill = 120,
	UsableWhileShapeshifted = 121,
	Meta = 122,
	Bear = 123,
	Wolf = 124,
	Invokable = 125,
	CreatesSkeletonMinion = 126,
	CreatesUndeadMinion = 127,
	CreatesDemonMinion = 128,
	CommandsMinions = 129,
	ReservesManually = 130,
	ConsumesCharges = 131,
	ManualCooldownConsumption = 132,
	SupportedByHourglass = 133,
	ConsumesFullyBrokenArmour = 134,
	SkillConsumesFreeze = 135,
	SkillConsumesIgnite = 136,
	SkillConsumesShock = 137,
	Wall = 138,
	Persistent = 139,
	UsableWhileMoving = 140,
	CanBecomeArrowRain = 141,
	MultipleReservation = 142,
	SupportedByElementalDischarge = 143,
	Limit = 144,
	Singular = 145,
	GeneratesCharges = 146,
	EmpowersOtherSkill = 147,
	PerformsFinalStrike = 148,
	PerfectTiming = 149,
	CanHaveMultipleOngoingSkillInstances = 150,
	Sustained = 151,
	ComboStacking = 152,
	SupportedByComboFinisher = 153,
	Offering = 154,
	Retaliation = 155,
	Shapeshift = 156,
	Invocation = 157,
	Grenade = 158,
	NoDualWield = 159,
	QuarterstaffSkill = 160,
	SupportedByFountains = 161,
	Jumping = 162,
	CannotChain = 163,
	CreatesGroundRune = 164,
	CreatesFissure = 165,
	SummonsAttackTotem = 166,
	NonWeaponAttack = 167,
	CreatesGroundEffect = 168,
	SupportedByComboMastery = 169,
	IceCrystal = 170,
	SkillConsumesPowerChargesOnUse = 171,
	SkillConsumesFrenzyChargesOnUse = 172,
	SkillConsumesEnduranceChargesOnUse = 173,
	SupportedByFerocity = 174,
	SupportedByPotential = 175,
	ProjectileNoCollision = 176,
	SupportedByExcise = 177,
	SupportedByExpanse = 178,
	SupportedByExecrate = 179,
	IsBlasphemy = 180,
	PersistentShowsCastTime = 181,
	GeneratesEnergy = 182,
	GeneratesRemnants = 183,
	CommandableMinion = 184,
	Bow = 185,
	AffectsPresence = 186,
	GainsStages = 187,
	HasSeals = 188,
	SupportedByUnleash = 189,
	SupportedBySalvo = 190,
	Spear = 191,
	GroundTargetedProjectile = 192,
	SupportedByFusillade = 193,
	HasUsageCondition = 194,
	SupportedByMobileAssault = 195,
	RequiresBuckler = 196,
	UsableWhileMounted = 197,
	Companion = 198,
	ConsumesInstillment = 199,
	CanCancelActions = 200,
	SupportedByUnmoving = 201,
	SupportedByCleanse = 202,
	Hazard = 203,
	SupportedByRally = 204,
	SupportedByFlamepierce = 205,
	SupportedByStormchain = 206,
	SupportedByFreezefork = 207,
	Palm = 208,
	CannotSpiritStrike = 209,
	SkillConsumesBleeding = 210,
	SkillConsumesPoison = 211,
	TargetsDestructibleRareCorpses = 212,
	SupportedByAncestralAid = 213,
	MinionsAreUndamagable = 214,
	GeneratesInfusion = 215,
	SkillConsumesParried = 216,
	DetonatesAfterTime = 217,
	NoAttackOrCastTime = 218,
	CreatesCompanion = 219,
	CannotTerrainChain = 220,
	SupportedByTumult = 221,
	RequiresCharges = 222,
	CannotConsumeCharges = 223,
	ConsumesRage = 224,
	NonDamageArmourBreak = 225,
	Necrotic = 226,
	Nature = 227,
	NoAttackInPlace = 228,
	DodgeReplacement = 229,
	SupportedByDurationThree = 230,
	ToggleSpawnedObjectTargetable_DefaultOn = 231,
	ToggleSpawnedObjectTargetable_DefaultOff = 232,
	ReserveInAllSets = 233,
	Unleashable = 234,
	CannotCreateJaggedGround = 235,
	SingleLevelSkill = 236,
	SupportedByZarokh = 237,
	SupportedByGarukhan = 238,
	FrozenSpite = 239,
	ObjectDurability = 240,
	Detonator = 241,
	SupportedByOverabundanceThree = 242,
	UnlimitedTotems = 243,
	SupportedByHaemoCrystals = 244,
	SupportedByFlamePillar = 245,
	CanCreateStoneElementals = 246,
	RemnantCannotBeShared = 247,
}

GlobalCache = { 
	cachedData = { MAIN = {}, CALCS = {}, CALCULATOR = {}, CACHE = {}, },
}

GlobalGemAssignments = { }