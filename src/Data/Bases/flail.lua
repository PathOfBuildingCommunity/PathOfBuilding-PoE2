-- This file is automatically generated, do not edit!
-- Item data (c) Grinding Gear Games
local itemBases = ...

itemBases["Splintered Flail"] = {
	type = "Flail",
	quality = 20,
	socketLimit = 2,
	tags = { onehand = true, flail = true, ezomyte_basetype = true, weapon = true, one_hand_weapon = true, default = true, },
	implicitModTypes = { },
	weapon = { PhysicalMin = 6, PhysicalMax = 9, CritChanceBase = 10, AttackRateBase = 1.45, Range = 11, },
	req = { },
}
itemBases["Chain Flail"] = {
	type = "Flail",
	quality = 20,
	socketLimit = 2,
	tags = { onehand = true, flail = true, ezomyte_basetype = true, weapon = true, one_hand_weapon = true, default = true, },
	implicitModTypes = { },
	weapon = { PhysicalMin = 8, PhysicalMax = 14, CritChanceBase = 10, AttackRateBase = 1.45, Range = 11, },
	req = { level = 6, str = 13, },
}
itemBases["Holy Flail"] = {
	type = "Flail",
	quality = 20,
	socketLimit = 2,
	tags = { onehand = true, flail = true, ezomyte_basetype = true, weapon = true, one_hand_weapon = true, default = true, },
	implicitModTypes = { },
	weapon = { PhysicalMin = 10, PhysicalMax = 17, CritChanceBase = 10, AttackRateBase = 1.45, Range = 11, },
	req = { level = 11, str = 22, int = 11, },
}
itemBases["Iron Flail"] = {
	type = "Flail",
	quality = 20,
	socketLimit = 2,
	tags = { maraketh_basetype = true, onehand = true, flail = true, weapon = true, one_hand_weapon = true, default = true, },
	implicitModTypes = { },
	weapon = { PhysicalMin = 14, PhysicalMax = 23, CritChanceBase = 10, AttackRateBase = 1.45, Range = 11, },
	req = { level = 16, str = 30, int = 14, },
}
itemBases["Twin Flail"] = {
	type = "Flail",
	quality = 20,
	socketLimit = 2,
	tags = { maraketh_basetype = true, onehand = true, flail = true, weapon = true, one_hand_weapon = true, default = true, },
	implicit = "Forks Critical Hits",
	implicitModTypes = { {  }, },
	weapon = { PhysicalMin = 8, PhysicalMax = 18, CritChanceBase = 10, AttackRateBase = 1.4, Range = 11, },
	req = { level = 20, str = 37, int = 16, },
}
itemBases["Slender Flail"] = {
	type = "Flail",
	quality = 20,
	socketLimit = 2,
	tags = { maraketh_basetype = true, onehand = true, flail = true, weapon = true, one_hand_weapon = true, default = true, },
	implicitModTypes = { },
	weapon = { PhysicalMin = 19, PhysicalMax = 32, CritChanceBase = 8, AttackRateBase = 1.5, Range = 11, },
	req = { level = 26, str = 48, int = 20, },
}
itemBases["Stone Flail"] = {
	type = "Flail",
	quality = 20,
	socketLimit = 2,
	tags = { onehand = true, flail = true, vaal_basetype = true, weapon = true, one_hand_weapon = true, default = true, },
	implicit = "Unblockable",
	implicitModTypes = { {  }, },
	weapon = { PhysicalMin = 23, PhysicalMax = 38, CritChanceBase = 10, AttackRateBase = 1.45, Range = 11, },
	req = { level = 33, str = 60, int = 25, },
}
itemBases["Ring Flail"] = {
	type = "Flail",
	quality = 20,
	socketLimit = 2,
	tags = { onehand = true, flail = true, vaal_basetype = true, weapon = true, one_hand_weapon = true, default = true, },
	implicitModTypes = { },
	weapon = { PhysicalMin = 23, PhysicalMax = 44, CritChanceBase = 10, AttackRateBase = 1.45, Range = 11, },
	req = { level = 38, str = 69, int = 28, },
}
itemBases["Guarded Flail"] = {
	type = "Flail",
	quality = 20,
	socketLimit = 2,
	tags = { onehand = true, flail = true, weapon = true, one_hand_weapon = true, default = true, },
	implicitModTypes = { },
	weapon = { PhysicalMin = 31, PhysicalMax = 57, CritChanceBase = 10, AttackRateBase = 1.4, Range = 11, },
	req = { level = 45, str = 81, int = 33, },
}
itemBases["Icicle Flail"] = {
	type = "Flail",
	quality = 20,
	socketLimit = 2,
	tags = { onehand = true, flail = true, weapon = true, one_hand_weapon = true, default = true, },
	implicitModTypes = { },
	weapon = { ColdMin = 24, ColdMax = 55, CritChanceBase = 10, AttackRateBase = 1.45, Range = 11, },
	req = { level = 47, str = 84, int = 34, },
}
itemBases["Tearing Flail"] = {
	type = "Flail",
	quality = 20,
	socketLimit = 2,
	tags = { onehand = true, flail = true, weapon = true, one_hand_weapon = true, default = true, },
	implicitModTypes = { },
	weapon = { PhysicalMin = 27, PhysicalMax = 56, CritChanceBase = 12.5, AttackRateBase = 1.4, Range = 11, },
	req = { level = 52, str = 93, int = 37, },
}
itemBases["Great Flail"] = {
	type = "Flail",
	quality = 20,
	socketLimit = 2,
	tags = { onehand = true, flail = true, weapon = true, one_hand_weapon = true, default = true, },
	implicitModTypes = { },
	weapon = { PhysicalMin = 35, PhysicalMax = 58, CritChanceBase = 10, AttackRateBase = 1.45, Range = 11, },
	req = { level = 58, str = 103, int = 41, },
}
itemBases["Abyssal Flail"] = {
	type = "Flail",
	quality = 20,
	socketLimit = 2,
	tags = { onehand = true, flail = true, weapon = true, one_hand_weapon = true, default = true, },
	implicitModTypes = { },
	weapon = { PhysicalMin = 36, PhysicalMax = 66, CritChanceBase = 10, AttackRateBase = 1.45, Range = 11, },
	req = { level = 65, str = 116, int = 45, },
}
-- not working this way? baseMatch BaseType Metadata/Items/Weapons/OneHandWeapons/Flails/AbstractFlail
