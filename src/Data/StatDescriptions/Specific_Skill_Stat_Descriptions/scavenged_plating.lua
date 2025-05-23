-- This file is automatically generated, do not edit!
-- Item data (c) Grinding Gear Games

return {
	[1]={
		stats={
			[1]="base_secondary_skill_effect_duration"
		}
	},
	[2]={
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
				text="Scavenged Plating duration is {0} second"
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
				text="Scavenged Plating duration is {0} seconds"
			}
		},
		stats={
			[1]="base_skill_effect_duration"
		}
	},
	[3]={
		[1]={
			[1]={
				limit={
					[1]={
						[1]=1,
						[2]="#"
					}
				},
				text="{0}% more Armour per Scavenged Plating"
			},
			[2]={
				[1]={
					k="negate",
					v=1
				},
				limit={
					[1]={
						[1]="#",
						[2]=-1
					}
				},
				text="{0}% less Armour per Scavenged Plating"
			}
		},
		stats={
			[1]="scavenged_plating_armour_+%_final_per_stack"
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
				text="Maximum {0} Scavenged Plating"
			}
		},
		stats={
			[1]="scavenged_plating_maximum_stacks_display"
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
				text="{0} to {1} Thorns per Scavenged Plating"
			}
		},
		stats={
			[1]="scavenged_plating_thorns_minimum_physical_damage",
			[2]="scavenged_plating_thorns_maximum_physical_damage"
		}
	},
	[6]={
		[1]={
		},
		stats={
			[1]="skill_effect_duration"
		}
	},
	["base_secondary_skill_effect_duration"]=1,
	["base_skill_effect_duration"]=2,
	parent="skill_stat_descriptions",
	["scavenged_plating_armour_+%_final_per_stack"]=3,
	["scavenged_plating_maximum_stacks_display"]=4,
	["scavenged_plating_thorns_maximum_physical_damage"]=5,
	["scavenged_plating_thorns_minimum_physical_damage"]=5,
	["skill_effect_duration"]=6
}