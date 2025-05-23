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
				text="Cone length is {0} metre"
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
				text="Cone length is {0} metres"
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
					k="milliseconds_to_seconds_2dp_if_required",
					v=1
				},
				limit={
					[1]={
						[1]=1000,
						[2]=1000
					}
				},
				text="Fire Exposure duration is {0} second"
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
				text="Fire Exposure duration is {0} seconds"
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
						[1]="#",
						[2]="#"
					}
				},
				text="Deals {0}% more damage per stage"
			}
		},
		stats={
			[1]="incinerate_damage_+%_final_per_stage"
		}
	},
	[5]={
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
				text="Inflicts stacking Fire Exposure at maximum stages, reducing Fire Resistance by {0}% per stack, up to a maximum of {1}%"
			}
		},
		stats={
			[1]="incinerate_buff_exposure_-_to_total_fire_resistance_per_stack",
			[2]="incinerate_maximum_exposure_magnitude"
		}
	},
	[6]={
		[1]={
			[1]={
				limit={
					[1]={
						[1]="#",
						[2]="#"
					}
				},
				text="{0} maximum stages"
			}
		},
		stats={
			[1]="incinerate_maximum_stages"
		}
	},
	[7]={
		[1]={
		},
		stats={
			[1]="skill_effect_duration"
		}
	},
	[8]={
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
	["active_skill_area_of_effect_radius"]=1,
	["active_skill_base_area_of_effect_radius"]=2,
	["base_skill_effect_duration"]=3,
	["incinerate_buff_exposure_-_to_total_fire_resistance_per_stack"]=5,
	["incinerate_damage_+%_final_per_stage"]=4,
	["incinerate_maximum_exposure_magnitude"]=5,
	["incinerate_maximum_stages"]=6,
	parent="skill_stat_descriptions",
	["skill_effect_duration"]=7,
	["spell_maximum_base_fire_damage"]=8,
	["spell_minimum_base_fire_damage"]=8
}