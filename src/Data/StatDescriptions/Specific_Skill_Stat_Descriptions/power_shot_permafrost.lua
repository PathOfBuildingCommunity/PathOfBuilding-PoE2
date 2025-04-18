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
					k="milliseconds_to_seconds_1dp",
					v=1
				},
				limit={
					[1]={
						[1]=1000,
						[2]=1000
					}
				},
				text="Wall lasts {0} second"
			},
			[2]={
				[1]={
					k="milliseconds_to_seconds_1dp",
					v=1
				},
				limit={
					[1]={
						[1]="#",
						[2]="#"
					}
				},
				text="Wall lasts {0} seconds"
			}
		},
		stats={
			[1]="base_skill_effect_duration"
		}
	},
	[4]={
		[1]={
			[1]={
				limit={
					[1]={
						[1]=1,
						[2]="#"
					},
					[2]={
						[1]=0,
						[2]=0
					}
				},
				text="Ice Crystals have {0} maximum Life"
			},
			[2]={
				limit={
					[1]={
						[1]=1,
						[2]="#"
					},
					[2]={
						[1]="#",
						[2]="#"
					}
				},
				text="Ice Crystal has {0} maximum Life"
			}
		},
		stats={
			[1]="frost_wall_maximum_life",
			[2]="frozen_locus_crystal_display_stat"
		}
	},
	["active_skill_area_of_effect_radius"]=1,
	["active_skill_base_area_of_effect_radius"]=2,
	["base_skill_effect_duration"]=3,
	["frost_wall_maximum_life"]=4,
	["frozen_locus_crystal_display_stat"]=4,
	parent="skill_stat_descriptions"
}