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
						[1]=1,
						[2]="#"
					}
				},
				text="+{0} metres to explosion radius per previous explosion"
			}
		},
		stats={
			[1]="spear_discharge_base_area_of_effect_radius_+_per_explosion"
		}
	},
	[4]={
		[1]={
			[1]={
				limit={
					[1]={
						[1]=1,
						[2]="#"
					}
				},
				text="{0}% of Physical damage Converted to the consumed Infusion's type"
			}
		},
		stats={
			[1]="spear_discharge_base_physical_damage_%_to_convert_to_infused_element"
		}
	},
	["active_skill_area_of_effect_radius"]=1,
	["active_skill_base_area_of_effect_radius"]=2,
	parent="skill_stat_descriptions",
	["spear_discharge_base_area_of_effect_radius_+_per_explosion"]=3,
	["spear_discharge_base_physical_damage_%_to_convert_to_infused_element"]=4
}