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
				text="Buff duration is {0} second"
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
				text="Buff duration is {0} seconds"
			}
		},
		stats={
			[1]="base_skill_effect_duration"
		}
	},
	[2]={
		[1]={
			[1]={
				limit={
					[1]={
						[1]=1000,
						[2]=1000
					}
				},
				text="Instantly reloads your Crossbow and restores one cooldown use for your Grenades upon Consuming\nFreeze, Shock, Ignite, or Fully Broken Armour, no more than\nonce per second"
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
				text="Instantly reloads your Crossbow and restores one cooldown use for your Grenades upon Consuming\nFreeze, Shock, Ignite, or Fully Broken Armour, no more than\nonce every {0} seconds"
			}
		},
		stats={
			[1]="reload_ammo_on_effect_consume_with_x_ms_cooldown"
		}
	},
	[3]={
		[1]={
		},
		stats={
			[1]="skill_effect_duration"
		}
	},
	["base_skill_effect_duration"]=1,
	parent="skill_stat_descriptions",
	["reload_ammo_on_effect_consume_with_x_ms_cooldown"]=2,
	["skill_effect_duration"]=3
}