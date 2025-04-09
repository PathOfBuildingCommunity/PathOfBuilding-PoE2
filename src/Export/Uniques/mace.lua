-- Item data (c) Grinding Gear Games

return {
-- Weapon: One Handed Mace
[[
Brynhand's Mark
Wooden Club
Variant: Pre 0.1.1
Variant: Current
{variant:1}UniqueLocalAddedPhysicalDamage5[3,4][6,8]
{variant:2}UniqueLocalAddedPhysicalDamage5
UniqueLocalIncreasedAccuracy1
{variant:2}UniqueLocalIncreasedAttackSpeed12
{variant:1}UniqueStrength15[5,10]
{variant:2}UniqueStrength15
UniqueLocalDoubleStunDamage1
]],[[
Frostbreath
Slim Mace
Variant: Pre 0.1.1
Variant: Current
{variant:1}UniqueLocalAddedPhysicalDamage4[4,6][8,12]
{variant:2}UniqueLocalAddedPhysicalDamage4
{variant:1}UniqueLocalAddedColdDamage2[4,6][8,12]
{variant:2}UniqueLocalAddedColdDamage2
{variant:2}UniqueLocalCriticalStrikeChance5
UniqueLocalAllDamageCanFreeze1
UniqueLocalCullingStrikeFrozenEnemies1
]],[[
Mjölner
Torment Club
Implicits: 1
Grants Skill: Level (1-20) Lightning Spell on Hit
UniqueIntelligenceRequirements2
UniqueStrengthRequirements2
UniqueLocalIncreasedPhysicalDamagePercent12
UniqueLocalIncreasedAttackSpeed20
UniqueGlobalLightningGemLevel2
]],[[
Nebuloch
Brigand Mace
UniqueLocalAddedPhysicalDamage17
UniqueLocalCriticalMultiplier2
UniqueLocalChaosDamage1
UniqueConsumeEnduranceChargeAlwaysCrit1
UniqueChaosDamagePerEnduranceCharge1
]],[[
Olrovasara
Torment Club
Source: Drops from unique{Olroth, Origin of the Fall}
Variant: Pre 0.2.0
Variant: Current
{variant:1}UniqueLocalAddedLightningDamage1[1,1][60,80]
{variant:2}UniqueLocalAddedLightningDamage1
UniqueLocalIncreasedAccuracy5
UniqueLocalIncreasedAttackSpeed10
UniqueMaximumLightningDamagePerPower1
]],[[
Sculpted Suffering
Warpick
Implicits: 1
MaceImplicitCriticalMultiplier1
UniqueLocalAddedPhysicalDamage18
UniqueLocalIncreasedAttackSpeed17
UniqueLocalArmourBreakOnDamage1
UniqueFullyArmourBrokenShatterOnKill1
]],[[
Seeing Stars
Plated Mace
Variant: Pre 0.1.1
Variant: Current
{variant:1}UniqueLocalAddedColdDamage3[9,12][18,22]
{variant:2}UniqueLocalAddedColdDamage3
{variant:1}UniqueLocalAddedLightningDamage2[1,1][30,35]
{variant:2}UniqueLocalAddedLightningDamage2
UniqueLocalIncreasedAttackSpeed6
UniqueDoubleEnergyGain1
]],[[
Trenchtimbre
Spiked Club
Variant: Pre 0.1.1
Variant: Pre 0.2.0
Variant: Current
{variant:1}UniqueLocalAddedPhysicalDamage10[10,12][18,35]
{variant:2,3}UniqueLocalAddedPhysicalDamage10
UniqueLocalIncreasedAttackSpeed11
{variant:2}UniqueGlobalMinionSpellSkillGemLevel1[1,3]
{variant:3}UniqueGlobalMinionSpellSkillGemLevel1
UniqueMinionAttackSpeedAffectsYou1
]],[[
Wylund's Stake
Smithing Hammer
Variant: Pre 0.1.1
Variant: Current
{variant:1}UniqueLocalAddedPhysicalDamage6[2,3][4,5]
{variant:2}UniqueLocalAddedPhysicalDamage6
{variant:1}UniqueLocalAddedFireDamage2[2,3][4,5]
{variant:2}UniqueLocalAddedFireDamage2
{variant:2}UniqueFireResist27
{variant:2}UniqueStrength30
UniqueLocalBreakArmourOnHit1
UniqueLocalFireExposureOnArmourBreak1
]],
-- Weapon: Two Handed Mace
[[
Brain Rattler
Studded Greatclub
Variant: Pre 0.1.1
Variant: Current
{variant:1}UniqueLocalAddedPhysicalDamage9[10,12][18,22]
{variant:2}UniqueLocalAddedPhysicalDamage9
{variant:1}UniqueLocalAddedLightningDamage3[1,1][36,42]
{variant:2}UniqueLocalAddedLightningDamage3
UniqueLocalIncreasedAttackSpeed5
UniqueLocalAllDamageCanElectrocute1
]],[[
Chober Chaber
Leaden Greathammer
Variant: Pre 0.1.1
Variant: Current
UniqueIntelligenceRequirements1
{variant:1}UniqueLocalIncreasedPhysicalDamagePercent4
{variant:2}UniqueLocalAddedPhysicalDamage12
UniqueIncreasedMana22
{variant:2}UniqueIncreasedSpirit8
{variant:1}UniqueLocalCriticalStrikeChance3
UniqueMinionDamageAffectsYou1
]],[[
The Empty Roar
Cultist Greathammer
Implicits: 1
MaceImplicitSplashDamage1
UniqueLocalAddedPhysicalDamage15
UniqueLifeLeechLocal2
UniqueLocalChanceToBleed1
UniqueAttacksCountAsExerted1
UniqueCannotUseWarcries1
]],[[
The Hammer of Faith
Giant Maul
UniqueLocalIncreasedPhysicalDamagePercent9
UniqueLocalIncreasedAttackSpeed14
UniqueAllResistances21
UniqueManaRegeneration29
UniqueShrineBuffAlternating1
]],[[
Hoghunt
Felled Greatclub
Variant: Pre 0.1.1
Variant: Current
{variant:1}UniqueLocalIncreasedPhysicalDamagePercent2
{variant:2}UniqueLocalAddedPhysicalDamage11
UniqueLocalCriticalStrikeChance1
UniqueLocalIncreasedAttackSpeed4
UniqueStrength19
UniqueLocalMaimOnCrit1
]],[[
Hrimnor's Hymn
Oak Greathammer
Variant: Pre 0.1.1
Variant: Current
Implicits: 1
MaceImplicitStunDamageIncrease1
{variant:1}UniqueLocalIncreasedPhysicalDamagePercent6[60,80]
{variant:2}UniqueLocalIncreasedPhysicalDamagePercent6
UniqueStrength3
UniqueLifeGainedFromEnemyDeath6
UniqueAftershockChance1
]],[[
Quecholli
Crumbling Maul
Implicits: 1
MaceImplicitEnemiesExplodeOnCrit1
UniqueLocalIncreasedPhysicalDamagePercent4
UniqueAllAttributes7
UniqueLifeGainedFromEnemyDeath8
UniqueLocalCritChanceOverride1
UniqueLocalNoCriticalStrikeMultiplier1
]],[[
Tidebreaker
Pointed Maul
UniqueLocalIncreasedPhysicalDamagePercent13
UniqueGlobalIncreaseMeleeSkillGemLevel1
UniqueIntelligence39
UniqueLocalStunDamageIncrease2
UniqueLocalAllDamageCanChill1
]],[[
Trephina
Forge Maul
Variant: Pre 0.1.1
Variant: Current
{variant:1}UniqueLocalAddedPhysicalDamage8[7,10][12,18]
{variant:2}UniqueLocalAddedPhysicalDamage8
UniqueLocalIncreasedAttackSpeed5
UniqueLocalStunDamageIncrease1
UniqueAlwaysCritHeavyStun1
]],[[
Shyaba
Temple Maul
UniqueDexterityRequirements1
UniqueStrengthRequirements1
UniqueLocalIncreasedPhysicalDamagePercent5
UniqueLocalIncreasedAttackSpeed15
UniqueLightRadius17
UniqueAlwaysHits1
]],
}
