-- This file is automatically generated, do not edit!
-- Item data (c) Grinding Gear Games

return {
	[1]={
		stats={
			[1]="quality_display_base_number_of_projectiles_is_gem"
		}
	},
	[2]={
		[1]={
		},
		stats={
			[1]="active_skill_area_of_effect_radius"
		}
	},
	[3]={
		[1]={
			[1]={
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
				text="Bolts shatter on impact, dealing Damage in a {0} metre cone"
			}
		},
		stats={
			[1]="active_skill_base_area_of_effect_radius"
		}
	},
	[4]={
		[1]={
			[1]={
				limit={
					[1]={
						[1]=2,
						[2]="#"
					},
					[2]={
						[1]="#",
						[2]="#"
					}
				},
				text="Fires {0} fragments per shot"
			}
		},
		stats={
			[1]="base_number_of_projectiles",
			[2]="skill_can_fire_arrows"
		}
	},
	[5]={
		[1]={
			[1]={
				limit={
					[1]={
						[1]="#",
						[2]="#"
					}
				},
				text="Multiple fragments can Hit the same target\nMultiple Fragments hitting a target simultaneously will combine their damage into a single Hit"
			}
		},
		stats={
			[1]="projectiles_can_shotgun"
		}
	},
	["active_skill_area_of_effect_radius"]=2,
	["active_skill_base_area_of_effect_radius"]=3,
	["base_number_of_projectiles"]=4,
	parent="skill_stat_descriptions",
	["projectiles_can_shotgun"]=5,
	["quality_display_base_number_of_projectiles_is_gem"]=1,
	["skill_can_fire_arrows"]=4
}