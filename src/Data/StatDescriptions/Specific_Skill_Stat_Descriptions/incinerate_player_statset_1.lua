-- This file is automatically generated, do not edit!
-- Item data (c) Grinding Gear Games

return {
	[1]={
		[1]={
			[1]={
				[1]={
					k="milliseconds_to_seconds_2dp_if_required",
					v=1
				},
				limit={
					[1]={
						[1]=1000,
						[2]=1000
					}
				},
				text="Ignited Ground duration is {0} second"
			},
			[2]={
				[1]={
					k="milliseconds_to_seconds_2dp_if_required",
					v=1
				},
				limit={
					[1]={
						[1]="#",
						[2]="#"
					}
				},
				text="Ignited Ground duration is {0} seconds"
			}
		},
		stats={
			[1]="base_skill_effect_duration"
		}
	},
	[2]={
		[1]={
		},
		stats={
			[1]="skill_ignited_ground_effect_duration_ms"
		}
	},
	[3]={
		[1]={
			[1]={
				limit={
					[1]={
						[1]="#",
						[2]="#"
					},
					[2]={
						[1]="#",
						[2]="#"
					}
				},
				text="Ignites as though dealing {0} to {1} Fire damage"
			}
		},
		stats={
			[1]="spell_minimum_base_fire_damage",
			[2]="spell_maximum_base_fire_damage"
		}
	},
	["base_skill_effect_duration"]=1,
	parent="skill_stat_descriptions",
	["skill_ignited_ground_effect_duration_ms"]=2,
	["spell_maximum_base_fire_damage"]=3,
	["spell_minimum_base_fire_damage"]=3
}