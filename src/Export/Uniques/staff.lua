-- Item data (c) Grinding Gear Games

return {
-- Weapon: Staff
[[
The Burden of Shadows
Chiming Staff
Implicits: 1
Grants Skill: Level (1-20) Sigil of Power
UniqueIncreasedCastSpeed11
UniqueLifeCost1
UniqueDamageGainedAsChaosPerCost1
]],[[
Dusk Vigil
Ashen Staff
Implicits: 2
Grants Skill: Level (1-20) Firebolt
Grants Skill: Level (1-20) Ember Fusillade
UniqueSpellDamageOnWeapon3
UniqueLifeGainedFromEnemyDeath9
UniqueManaRegeneration20
UniqueTriggerEmberFusilladeOnSpellCast1
]],[[
Earthbound
Voltaic Staff
Implicits: 1
Grants Skill: Level (1-20) Lightning Bolt
Grants Skill: Level (1-20) Spark
UniqueLightningDamageOnWeapon1
UniqueIncreasedCastSpeed4
UniqueManaRegeneration6
UniqueTriggerSparkOnKillingShockedEnemy1
]],[[
The Searing Touch
Pyrophyte Staff
Implicits: 1
Grants Skill: Level (1-20) Living Bomb
UniqueFireDamageOnWeapon1
UniqueIncreasedCastSpeed4
UniqueIgniteChanceIncrease1
UniqueIgniteEffect2
]],[[
Taryn's Shiver
Gelid Staff
Implicits: 1
Grants Skill: Level (1-20) Freezing Shards
UniqueColdDamageOnWeapon1
UniqueIncreasedCastSpeed4
UniqueFreezeDamageIncrease1
UniqueFrozenMonstersTakeIncreasedDamage1
]],
-- Weapon: Warstaff
[[
The Blood Thorn
Wrapped Quarterstaff
Variant: Pre 0.1.1
Variant: Current
{variant:1}UniqueLocalAddedPhysicalDamage2[3,5][9,11]
{variant:2}UniqueLocalAddedPhysicalDamage2
UniqueStrength3
UniqueCausesBleeding1
UniqueAttackerTakesDamage1
]],[[
Collapsing Horizon
Wyrm Quarterstaff
UniqueWeaponElementalDamage1
UniqueLocalCriticalStrikeChance4
UniqueGlobalElementalGemLevel1
UniqueTriggersRefundEnergySpent1
]],[[
Matsya
Crescent Quarterstaff
Variant: Pre 0.1.1
Variant: Current
{variant:2}UniqueLocalAddedColdDamage5
{variant:2}UniqueLocalAddedLightningDamage5
UniqueLocalCriticalStrikeChance2
UniqueLocalIncreasedAttackSpeed9
UniqueManaRegeneration13
UniqueHalvedSpiritReservation1
]],[[
Nazir's Judgement
Steelpoint Quarterstaff
Variant: Pre 0.1.1
Variant: Current
{variant:1}UniqueLocalIncreasedPhysicalDamagePercent4
{variant:2}UniqueLocalAddedPhysicalDamage13
UniqueIncreasedAccuracy2
UniqueStunDuration1
UniqueLocalDazeBuildup1
]],[[
Pillar of the Caged God
Variant: Pre 0.2.0
Variant: Current
Long Quarterstaff
Implicits: 1
QuarterstaffWeaponRange1
{variant:1}UniqueAttackAreaOfEffectPerIntelligence1[2,2]
{variant:2}UniqueAttackAreaOfEffectPerIntelligence1
{variant:1}UniqueAttackSpeedPerDexterity1[2,2]
{variant:2}UniqueAttackSpeedPerDexterity1
UniqueWeaponDamagePerStrength1
]],[[
The Sentry
Gothic Quarterstaff
Variant: Pre 0.1.1
Variant: Current
{variant:2}UniqueLocalNoWeaponPhysicalDamage3
{variant:1}UniqueLocalAddedFireDamage3[8,12][16,20]
{variant:2}UniqueLocalAddedFireDamage3
{variant:2}UniqueLocalIncreasedAccuracy6
UniqueFireResist13
UniqueIgniteChanceIncrease1
UniqueLightRadius7
]],
}
