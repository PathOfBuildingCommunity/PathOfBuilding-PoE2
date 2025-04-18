-- This file is automatically generated, do not edit!
-- Item data (c) Grinding Gear Games

return {
	[1]={
		[1]={
			[1]={
				limit={
					[1]={
						[1]=1,
						[2]="#"
					}
				},
				text="Parried Debuff makes targets take {0}% more Attack Damage"
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
				text="Parried Debuff makes targets take {0}% less Attack Damage"
			}
		},
		stats={
			[1]="base_parry_buff_damage_taken_+%_final_to_apply"
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
						[1]="#",
						[2]="#"
					},
					[2]={
						[1]=0,
						[2]=0
					}
				},
				text="Parried Debuff lasts for an additional {0:+d} seconds"
			},
			[2]={
				[1]={
					k="milliseconds_to_seconds_2dp_if_required",
					v=1
				},
				limit={
					[1]={
						[1]=1000,
						[2]=1000
					},
					[2]={
						[1]="#",
						[2]="#"
					}
				},
				text="Parried Debuff duration is {0} second"
			},
			[3]={
				[1]={
					k="milliseconds_to_seconds_2dp_if_required",
					v=1
				},
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
				text="Parried Debuff duration is {0} seconds"
			}
		},
		stats={
			[1]="base_skill_effect_duration",
			[2]="quality_display_base_skill_effect_duration_is_gem"
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
				text="{0} to {1} Added Physical Damage per 5 Evasion Rating on Buckler"
			}
		},
		stats={
			[1]="off_hand_minimum_added_physical_damage_per_5_shield_evasion_rating",
			[2]="off_hand_maximum_added_physical_damage_per_5_shield_evasion_rating"
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
				text="Can Parry Projectiles fired from within {0} metre"
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
				text="Can Parry Projectiles fired from within {0} metres"
			}
		},
		stats={
			[1]="parry_blocked_projectile_distance"
		}
	},
	[5]={
		[1]={
		},
		stats={
			[1]="parry_buff_attack_damage_taken_+%_final_magnitude_to_apply"
		}
	},
	[6]={
		[1]={
		},
		stats={
			[1]="parry_buff_spell_damage_taken_+%_final_magnitude_to_apply"
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
		},
		stats={
			[1]="virtual_parry_blocked_projectile_distance"
		}
	},
	["base_parry_buff_damage_taken_+%_final_to_apply"]=1,
	["base_skill_effect_duration"]=2,
	["off_hand_maximum_added_physical_damage_per_5_shield_evasion_rating"]=3,
	["off_hand_minimum_added_physical_damage_per_5_shield_evasion_rating"]=3,
	parent="skill_stat_descriptions",
	["parry_blocked_projectile_distance"]=4,
	["parry_buff_attack_damage_taken_+%_final_magnitude_to_apply"]=5,
	["parry_buff_spell_damage_taken_+%_final_magnitude_to_apply"]=6,
	["quality_display_base_skill_effect_duration_is_gem"]=2,
	["skill_effect_duration"]=7,
	["virtual_parry_blocked_projectile_distance"]=8
}