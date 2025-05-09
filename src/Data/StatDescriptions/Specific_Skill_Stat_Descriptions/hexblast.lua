-- This file is automatically generated, do not edit!
-- Item data (c) Grinding Gear Games

return {
	[1]={
		[1]={
		},
		stats={
			[1]="active_skill_area_of_effect_radius"
		}
	},
	[2]={
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
				text="Explosion radius is {0} metre"
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
				text="Explosion radius is {0} metres"
			}
		},
		stats={
			[1]="active_skill_base_area_of_effect_radius"
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
				text="Detonates a Curse on enemies in a {0} metre radius"
			}
		},
		stats={
			[1]="active_skill_base_secondary_area_of_effect_radius"
		}
	},
	[4]={
		[1]={
		},
		stats={
			[1]="active_skill_secondary_area_of_effect_radius"
		}
	},
	[5]={
		[1]={
			[1]={
				limit={
					[1]={
						[1]=1,
						[2]="#"
					}
				},
				text="Maximum {0} Explosions per cast"
			}
		},
		stats={
			[1]="hexblast_maximum_number_of_explosions"
		}
	},
	["active_skill_area_of_effect_radius"]=1,
	["active_skill_base_area_of_effect_radius"]=2,
	["active_skill_base_secondary_area_of_effect_radius"]=3,
	["active_skill_secondary_area_of_effect_radius"]=4,
	["hexblast_maximum_number_of_explosions"]=5,
	parent="skill_stat_descriptions"
}