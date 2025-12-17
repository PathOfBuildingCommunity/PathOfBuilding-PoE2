-- Path of Building
--
-- Stat to internal modifier mapping table for buffs
-- Stat data (c) Grinding Gear Games
--
local mod, flag, skill = ...

return {
["elemental_damage_with_spell_skills_+%_final_from_archon_buff"]={
	mod("ElementalDamage", "MORE", nil, ModFlag.Spell),
},
["archon_spells_ignite_chance_+%_final"]={
	mod("EnemyIgniteChance", "MORE", nil, ModFlag.Spell),
},
["archon_spells_hit_damage_freeze_multiplier_+%_final"]={
	mod("EnemyFreezeBuildup", "MORE", nil, ModFlag.Spell),
},
["archon_spells_shock_chance_+%_final"]={
	mod("EnemyShockChance", "MORE", nil, ModFlag.Spell),
},
}