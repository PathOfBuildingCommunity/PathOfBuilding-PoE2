-- Item data (c) Grinding Gear Games

return {
-- Weapon: Staff
[[
The Burden of Shadows
Chiming Staff
Source: Drops from unique{The King in the Mists} in normal{Crux of Nothingness}
Implicits: 1
Grants Skill: Level (1-20) Sigil of Power
UniqueIncreasedCastSpeed11
UniqueLifeCost1
UniqueDamageGainedAsChaosPerCost1
]],[[
Dusk Vigil
Ashen Staff
Variant: Pre 0.4.0
Variant: Current
Implicits: 2
Grants Skill: Level (1-20) Firebolt
Grants Skill: Level (1-20) Ember Fusillade
{variant:2}UniqueDamageGainedAsFire3
{variant:1}UniqueSpellDamageOnWeapon3[60,80]
{variant:2}UniqueSpellDamageOnWeapon3
UniqueLifeGainedFromEnemyDeath9
UniqueManaRegeneration20
UniqueTriggerEmberFusilladeOnSpellCast1
]],[[
Earthbound
Voltaic Staff
Variant: Pre 0.4.0
Variant: Current
Implicits: 2
Grants Skill: Level (1-20) Lightning Bolt
Grants Skill: Level (1-20) Spark
{variant:1}UniqueLightningDamageOnWeapon1
{variant:2}UniqueSpellDamageOnWeapon11
UniqueIncreasedCastSpeed4
UniqueManaRegeneration6
{variant:2}UniqueShockChanceIncrease4
UniqueTriggerSparkOnKillingShockedEnemy1
]],[[
The Searing Touch
Pyrophyte Staff
Variant: Pre 0.4.0
Variant: Current
Implicits: 1
Grants Skill: Level (1-20) Living Bomb
UniqueFireDamageOnWeapon1
UniqueIncreasedCastSpeed4
UniqueIgniteChanceIncrease1
UniqueIgniteEffect2
{variant:2}UniqueStaffIgniteProliferation1
]],[[
Sire of Shards
Chiming Staff
League: Dawn of the Hunt
Implicits: 1
Grants Skill: Level (1-20) Sigil of Power
UniqueSpellDamageOnWeapon7
UniqueIncreasedCastSpeed4
UniqueAllResistances22
LightRadiusUniqueStaff10_
UniqueSpellAdditionalProjectilesInCircle1
]],[[
Taryn's Shiver
Gelid Staff
Variant: Pre 0.4.0
Variant: Current
Implicits: 1
Grants Skill: Level (1-20) Freezing Shards
{variant:1}UniqueColdDamageOnWeapon1
{variant:2}UniqueSpellDamageOnWeapon10
UniqueIncreasedCastSpeed4
{variant:1}UniqueFreezeDamageIncrease1[100,100]
{variant:2}UniqueFreezeDamageIncrease1
{variant:1}UniqueFrozenMonstersTakeIncreasedDamage1[50,50]
{variant:2}UniqueFrozenMonstersTakeIncreasedDamage1
]],[[
The Whispering Ice
Permafrost Staff
League: Dawn of the Hunt
Variant: Pre 0.4.0
Variant: Current
Implicits: 2
Grants Skill: Level (1-20) Heart of Ice
Grants Skill: Level (1-20) Icestorm
{variant:1}UniqueGlobalColdSpellGemsLevel1[2,4]
{variant:2}UniqueGlobalColdSpellGemsLevel1
UniqueIncreasedCastSpeed16
{variant:1}UniquePercentageIntelligence3[5,15]
{variant:2}UniquePercentageIntelligence3
{variant:1}SpellDamagePerIntelligenceUniqueStaff12[4,4]
{variant:2}SpellDamagePerIntelligenceUniqueStaff12
{variant:1}UniqueColdExposureOnHitWithMagnitude1[20,30]
{variant:2}UniqueColdExposureOnHitWithMagnitude1
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
Source: Drops from unique{Kosis, The Revelation}
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
Variant: Pre 0.3.0
Variant: Current
{variant:1}UniqueLocalIncreasedPhysicalDamagePercent4
{variant:2,3}UniqueLocalAddedPhysicalDamage13
UniqueIncreasedAccuracy2
UniqueStunDuration1
UniqueLocalDazeBuildup1
{variant:3}UniqueMeleeDamageAgainstStunnedEnemies1
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
]],[[
The Unborn Lich
Ravenous Staff
League: Rise of the Abyssal
Has Alt Variant: true
Has Alt Variant Two: true
Has Alt Variant Three: true
Selected Variant: 7
Selected Alt Variant: 8
Selected Alt Variant Two: 9
Selected Alt Variant Three: 10
Variant: His Dark Horizon
Variant: His Foul Emergence
Variant: His Grave Command
Variant: His Scattering Calamity
Variant: His Vile Intrusion
Variant: His Winnowing Flame
Variant: Elemental Damage and Ailment Duration
Variant: Spirit and Spirit Reservation Efficiency
Variant: Chaos Damage and Curse
Variant: Spell Physical Damage and Bleed Chance
Variant: Chaos Damage and Explode
Variant: Unholy Might
Implicits: 1
Grants Skill: Level (1-20) Feast of Flesh
UniqueDesecratedModEffect1
{variant:1}Grants Skill: Level (1-20) His Dark Horizon
{variant:2}Grants Skill: Level (1-20) His Foul Emergence
{variant:3}Grants Skill: Level (1-20) His Grave Command
{variant:4}Grants Skill: Level (1-20) His Scattering Calamity
{variant:5}Grants Skill: Level (1-20) His Vile Intrusion
{variant:6}Grants Skill: Level (1-20) His Winnowing Flame
{variant:7}UniqueKulemakElementalDamageEleAilmentDuration_1
{variant:8}UniqueKulemakSpiritAndSpiritReservationEfficiency_1
{variant:9}UniqueKulemakChaosDamageCurseLowersChaosRes_1
{variant:10}UniqueKulemakSpellPhysicalDamageBleedChance_1
{variant:11}UniqueKulemakChaosDamageAndExplosion_1
{variant:12}UniqueKulemakUnholyMightAndMagnitude_1
]],
}
