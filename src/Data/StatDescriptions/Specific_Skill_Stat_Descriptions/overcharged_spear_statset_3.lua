-- This file is automatically generated, do not edit!
-- Item data (c) Grinding Gear Games

return {
	[1]={
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
				text="Fires bolts at enemies within a {0} metre radius"
			}
		},
		stats={
			[1]="active_skill_base_secondary_area_of_effect_radius"
		}
	},
	[2]={
		[1]={
		},
		stats={
			[1]="active_skill_secondary_area_of_effect_radius"
		}
	},
	[3]={
		[1]={
			[1]={
				limit={
					[1]={
						[1]=1,
						[2]=1
					}
				},
				text="Fires {0} bolt"
			},
			[2]={
				limit={
					[1]={
						[1]=2,
						[2]="#"
					}
				},
				text="Fires {0} bolts"
			}
		},
		stats={
			[1]="overcharged_spear_detonate_number_of_beams"
		}
	},
	["active_skill_base_secondary_area_of_effect_radius"]=1,
	["active_skill_secondary_area_of_effect_radius"]=2,
	["overcharged_spear_detonate_number_of_beams"]=3,
	parent="skill_stat_descriptions"
}