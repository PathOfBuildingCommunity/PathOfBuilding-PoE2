-- This file is automatically generated, do not edit!
-- Item data (c) Grinding Gear Games

return {
	[1]={
		[1]={
			[1]={
				limit={
					[1]={
						[1]="#",
						[2]="#"
					}
				},
				text="Curse inflicts {0:+d}% to Chaos Resistance"
			}
		},
		stats={
			[1]="base_skill_buff_chaos_damage_resistance_%_to_apply"
		}
	},
	[2]={
		[1]={
		},
		stats={
			[1]="skill_curse_chaos_damage_resistance_%_magnitude_to_apply"
		}
	},
	[3]={
		[1]={
		},
		stats={
			[1]="active_skill_area_of_effect_radius"
		}
	},
	[4]={
		[1]={
			[1]={
				[1]={
					k="divide_by_ten_1dp_if_required",
					v=1
				},
				limit={
					[1]={
						[1]=10,
						[2]=10
					}
				},
				text="Curse radius is {0} metre"
			},
			[2]={
				[1]={
					k="divide_by_ten_1dp_if_required",
					v=1
				},
				limit={
					[1]={
						[1]="#",
						[2]="#"
					}
				},
				text="Curse radius is {0} metres"
			}
		},
		stats={
			[1]="active_skill_base_area_of_effect_radius"
		}
	},
	[5]={
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
				text="Curse duration is {0} second"
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
				text="Curse duration is {0} seconds"
			}
		},
		stats={
			[1]="base_skill_effect_duration"
		}
	},
	[6]={
		[1]={
		},
		stats={
			[1]="skill_effect_duration"
		}
	},
	["active_skill_area_of_effect_radius"]=3,
	["active_skill_base_area_of_effect_radius"]=4,
	["base_skill_buff_chaos_damage_resistance_%_to_apply"]=1,
	["base_skill_effect_duration"]=5,
	parent="skill_stat_descriptions",
	["skill_curse_chaos_damage_resistance_%_magnitude_to_apply"]=2,
	["skill_effect_duration"]=6
}