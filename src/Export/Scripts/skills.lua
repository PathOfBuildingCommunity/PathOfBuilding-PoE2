local skillTypes = {
	"Attack",
	"Spell",
	"Projectile",
	"DualWieldOnly",
	"Buff",
	"Minion",
	"Damage",
	"Area",
	"Duration",
	"RequiresShield",
	"ProjectileSpeed",
	"HasReservation",
	"ReservationBecomesCost",
	"Trappable",
	"Totemable",
	"Mineable",
	"ElementalStatus",
	"MinionsCanExplode",
	"Chains",
	"Melee",
	"MeleeSingleTarget",
	"Multicastable",
	"TotemCastsAlone",
	"Multistrikeable",
	"CausesBurning",
	"SummonsTotem",
	"TotemCastsWhenNotDetached",
	"Physical",
	"Fire",
	"Cold",
	"Lightning",
	"Triggerable",
	"Trapped",
	"Movement",
	"DamageOverTime",
	"RemoteMined",
	"Triggered",
	"Vaal",
	"Aura",
	"CanTargetUnusableCorpse",
	"RangedAttack",
	"Chaos",
	"FixedSpeedProjectile",
	"ThresholdJewelArea",
	"ThresholdJewelProjectile",
	"ThresholdJewelDuration",
	"ThresholdJewelRangedAttack",
	"Channel",
	"DegenOnlySpellDamage",
	"InbuiltTrigger",
	"Golem",
	"Herald",
	"AuraAffectsEnemies",
	"NoRuthless",
	"ThresholdJewelSpellDamage",
	"Cascadable",
	"ProjectilesFromUser",
	"MirageArcherCanUse",
	"ProjectileSpiral",
	"SingleMainProjectile",
	"MinionsPersistWhenSkillRemoved",
	"ProjectileNumber",
	"Warcry",
	"Instant",
	"Brand",
	"TargetsDestructibleCorpses",
	"NonHitChill",
	"ChillingArea",
	"AppliesCurse",
	"CanRapidFire",
	"AuraDuration",
	"AreaSpell",
	"OR",
	"AND",
	"NOT",
	"AppliesMaim",
	"CreatesMinion",
	"Guard",
	"Travel",
	"Blink",
	"CanHaveBlessing",
	"ProjectilesNotFromUser",
	"AttackInPlaceIsDefault",
	"Nova",
	"InstantNoRepeatWhenHeld",
	"InstantShiftAttackForLeftMouse",
	"AuraNotOnCaster",
	"Banner",
	"Rain",
	"Cooldown",
	"ThresholdJewelChaining",
	"Slam",
	"Stance",
	"NonRepeatable",
	"UsedByTotem",
	"Steel",
	"Hex",
	"Mark",
	"Aegis",
	"Orb",
	"KillNoDamageModifiers",
	"RandomElement",
	"LateConsumeCooldown",
	"Arcane",
	"FixedCastTime",
	"RequiresOffHandNotWeapon",
	"Link",
	"Blessing",
	"ZeroReservation",
	"DynamicCooldown",
	"Microtransaction",
	"OwnerCannotUse",
	"ProjectilesNumberModifiersNotApplied",
	"TotemsAreBallistae",
	"SkillGrantedBySupport",
	"CrossbowSkill",
	"CrossbowAmmoSkill",
	"UseGlobalStats",
	"ModifiesNextSkill",
	"OngoingSkill",
	"UsableWhileShapeshifted",
	"Meta",
	"Bear",
	"Wolf",
	"Invokable",
	"CreatesSkeletonMinion",
	"CreatesUndeadMinion",
	"CreatesDemonMinion",
	"CommandsMinions",
	"ReservesManually",
	"ConsumesCharges",
	"ManualCooldownConsumption",
	"SupportedByHourglass",
	"ConsumesFullyBrokenArmour",
	"SkillConsumesFreeze",
	"SkillConsumesIgnite",
	"SkillConsumesShock",
	"Wall",
	"Persistent",
	"Nonpathing",
	"CanBecomeArrowRain",
	"MultipleReservation",
	"SupportedByElementalDischarge",
	"Limit",
	"Singular",
	"GeneratesCharges",
	"EmpowersOtherSkill",
	"PerformsFinalStrike",
	"PerfectTiming",
	"CanHaveMultipleOngoingSkillInstances",
	"Sustained",
	"ComboStacking",
	"SupportedByComboFinisher",
	"Offering",
	"Retaliation",
	"Shapeshift",
	"Invocation",
	"Grenade",
	"NoDualWield",
	"QuarterstaffSkill",
	"SupportedByFountains",
	"Jumping",
	"CannotChain",
	"CreatesGroundRune",
	"CreatesFissure",
	"SummonsAttackTotem",
	"NonWeaponAttack",
	"CreatesGroundEffect",
	"SupportedByComboMastery",
	"IceCrystal",
	"SkillConsumesPowerChargesOnUse",
	"SkillConsumesFrenzyChargesOnUse",
	"SkillConsumesEnduranceChargesOnUse",
	"SupportedByFerocity",
	"SupportedByPotential",
	"ProjectileNoCollision",
	"SupportedByExcise",
	"SupportedByExpanse",
	"SupportedByExecrate",
	"IsBlasphemy",
	"PersistentShowsCastTime",
	"GeneratesEnergy",
	"CommandableMinion",
}

-- This is here to fix name collisions like in the case of Barrage
local fullNameGems = {
	["Metadata/Items/Gems/SupportGemBarrage"] = true,
}

local function mapAST(ast)
	return "SkillType."..(skillTypes[ast._rowIndex] or ("Unknown"..ast._rowIndex))
end

local weaponClassMap = {
	["Claw"] = "Claw",
	["Dagger"] = "Dagger",
	["Wand"] = "Wand",
	["One Hand Sword"] = "One Handed Sword",
	["Thrusting One Hand Sword"] = "Thrusting One Handed Sword",
	["One Hand Axe"] = "One Handed Axe",
	["One Hand Mace"] = "One Handed Mace",
	["Bow"] = "Bow",
	["Crossbow"] = "Crossbow",
	["Fishing Rod"] = "Fishing Rod",
	["Staff"] = "Staff",
	["Two Hand Sword"] = "Two Handed Sword",
	["Two Hand Axe"] = "Two Handed Axe",
	["Two Hand Mace"] = "Two Handed Mace",
	["Unarmed"] = "None",
}

local skillStatScope = { }
local gems = { }
local trueGemNames = { }

local directiveTable = { }

-- #noGem
-- Disables the gem component of the next skill
directiveTable.noGem = function(state, args, out)
	state.noGem = true
end

-- #addSkillTypes <flag>[ <flag>[...]]
-- skill types to be added to the skillTypes flags for this active skill
directiveTable.addSkillTypes = function(state, args, out)
	state.addSkillTypes = {}
	for flag in args:gmatch("%a+") do
		table.insert(state.addSkillTypes, flag)
	end
end

-- #skill <GrantedEffectId> [<Display name>]
-- Initialises the skill data and emits the skill header
directiveTable.skill = function(state, args, out)
	local grantedId, displayName = args:match("(%w+) (.+)")
	if not grantedId then
		grantedId = args
		displayName = args
	end
	out:write('skills["', grantedId, '"] = {\n')
	local granted = dat("GrantedEffects"):GetRow("Id", grantedId)
	if not granted then
		ConPrintf('Unknown GE: "'..grantedId..'"')
		return
	end
	local gemEffect = dat("GemEffects"):GetRow("GrantedEffect", granted)
	local secondaryEffect
	if not gemEffect then
		gemEffect = dat("GemEffects"):GetRow("AdditionalGrantedEffects", granted)
		if gemEffect then 
			secondaryEffect = true
		end
	end
	local skillGem
	if gemEffect then
		for gem in dat("SkillGems"):Rows() do
			for _, variant in ipairs(gem.GemEffects) do
				if gemEffect.Id == variant.Id then
					skillGem = gem
					local trueGemNameObj = dat("GemEffects"):GetRow("Id", gemEffect.Id)
					if trueGemNameObj.Name ~= "" then
						trueGemNames[gemEffect.Id] = trueGemNameObj.Name
					end
					break
				end
			end
			if skillGem then break end
		end
	end
	local skill = { }
	state.skill = skill
	if skillGem and not state.noGem then
		gems[gemEffect.Id] = true
		if granted.IsSupport then
			skill.displayName = fullNameGems[skillGem.BaseItemType.Id] and skillGem.BaseItemType.Name or skillGem.BaseItemType.Name:gsub(" Support", "")
			out:write('\tname = "', skill.displayName, '",\n')
			if #gemEffect.Description > 0 then
				out:write('\tdescription = "', escapeGGGString(gemEffect.Description:gsub('"','\\"'):gsub('\r',''):gsub('\n','\\n')), '",\n')
			end
		else
			skill.displayName = secondaryEffect and granted.ActiveSkill.DisplayName or trueGemNames[gemEffect.Id] or granted.ActiveSkill.DisplayName
			out:write('\tname = "', skill.displayName, '",\n')
			-- Hybrid gems (e.g. Vaal gems) use the display name of the active skill e.g. Vaal Summon Skeletons of Sorcery
			out:write('\tbaseTypeName = "', granted.ActiveSkill.DisplayName, '",\n')
		end
	else
		if displayName == args and not granted.IsSupport then
			displayName = gemEffect and trueGemNames[gemEffect.Id] or granted.ActiveSkill.DisplayName
		end
		skill.displayName = displayName
		out:write('\tname = "', displayName, '",\n')
		out:write('\thidden = true,\n')
	end
	state.noGem = false
	skill.baseFlags = { }
	skill.levels = { }
	skill.sets = { }
	skill.setIndex = 1
	skill.addSkillTypes = state.addSkillTypes
	state.addSkillTypes = nil
	if skillGem and not state.noGem then
		out:write('\tcolor = ', skillGem.GemColour, ',\n')
	end
	local nextGemLevelReqValue = 0
	local perLevel = dat("GrantedEffectsPerLevel"):GetRowList("GrantedEffect", granted)
	local gemLevelProgression = nil
	if skillGem and not state.noGem then
		gemLevelProgression = dat("ItemExperiencePerLevel"):GetRowList("ItemExperienceType", skillGem.GemLevelProgression)
	end
	for indx = 1, #perLevel do
		local levelRow = perLevel[indx]
		local level = { extra = { }, statInterpolation = { }, actorLevel = 1, cost = { } }
		level.level = levelRow.Level
		level.extra.levelRequirement = math.max(gemLevelProgression and gemLevelProgression[indx] and gemLevelProgression[indx].PlayerLevel or 0, nextGemLevelReqValue)
		nextGemLevelReqValue = level.extra.levelRequirement
		for i, cost in ipairs(granted.CostType) do
			level.cost[cost["Resource"]] = levelRow.CostAmounts[i]
		end
		--if levelRow.ManaReservationFlat ~= 0 then
		--	level.extra.manaReservationFlat = levelRow.ManaReservationFlat
		--end
		--if levelRow.ManaReservationPercent ~= 0 then
		--	level.extra.manaReservationPercent = levelRow.ManaReservationPercent / 100
		--end
		--if levelRow.LifeReservationFlat ~= 0 then
		--	level.extra.lifeReservationFlat = levelRow.LifeReservationFlat
		--end
		--if levelRow.LifeReservationPercent ~= 0 then
		--	level.extra.lifeReservationPercent = levelRow.LifeReservationPercent / 100
		--end
		if levelRow.CostMultiplier ~= 100 then
			level.extra.manaMultiplier = levelRow.CostMultiplier - 100
		end
		if levelRow.AttackSpeedMultiplier and levelRow.AttackSpeedMultiplier ~= 0 then
			level.extra.attackSpeedMultiplier = levelRow.AttackSpeedMultiplier
		end
		if levelRow.AttackTime ~= 0 then
			level.extra.attackTime = levelRow.AttackTime
		end
		if levelRow.Cooldown and levelRow.Cooldown ~= 0 then
			level.extra.cooldown = levelRow.Cooldown / 1000
		end
		if levelRow.PvPDamageMultiplier ~= 0 then
			level.extra.PvPDamageMultiplier = levelRow.PvPDamageMultiplier
		end
		if levelRow.StoredUses ~= 0 then
			level.extra.storedUses = levelRow.StoredUses
		end
		if levelRow.VaalSouls ~= 0 then
			level.cost.Soul = levelRow.VaalSouls
		end
		if levelRow.VaalStoredUses ~= 0 then
			level.extra.vaalStoredUses = levelRow.VaalStoredUses
		end
		if levelRow.SoulGainPreventionDuration ~= 0 then
			level.extra.soulPreventionDuration = levelRow.SoulGainPreventionDuration / 1000
		end
		-- stat based level info
		--if statRow.DamageEffectiveness ~= 0 then
		--	level.extra.damageEffectiveness = statRow.DamageEffectiveness / 10000 + 1
		--end
		level.actorLevel = levelRow.ActorLevel
		table.insert(skill.levels, level)
	end
	out:write('\tlevels = {\n')
	for _, level in ipairs(skill.levels) do
		out:write('\t\t[', level.level, '] = { ')
		for _, statVal in ipairs(level) do
			out:write(tostring(statVal), ', ')
		end
		for k, v in pairs(level.extra) do
			out:write(k, ' = ', tostring(v), ', ')
		end
		if level.actorLevel ~= nil then
			out:write('actorLevel = ', level.actorLevel, ', ')
		end
		if next(level.cost) ~= nil then
			out:write('cost = { ')
			for k, v in pairs(level.cost) do
				out:write(k, ' = ', tostring(v), ', ')
			end
			out:write('}, ')
		end
		out:write('},\n')
	end
	out:write('\t},\n')
	if not skill.qualityStats then
		skill.qualityStats = { }
		for i, qualityStatsRow in ipairs(dat("GrantedEffectQualityStats"):GetRowList("GrantedEffect", granted)) do
			skill.qualityStats[i] = { }
			for j, stat in ipairs(qualityStatsRow.GrantedStats) do
				table.insert(skill.qualityStats[i], { stat.Id, qualityStatsRow.StatValues[j] / 1000 })
				--ConPrintf("[%d] %s %s", i, granted.ActiveSkill.DisplayName, stat.Id)
			end
		end
	end
	if granted.IsSupport then
		skill.isSupport = true
		out:write('\tsupport = true,\n')
		out:write('\trequireSkillTypes = { ')
		for _, type in ipairs(granted.SupportTypes) do
			out:write(mapAST(type), ', ')
		end
		out:write('},\n')
		out:write('\taddSkillTypes = { ')
		skill.isTrigger = false
		for _, type in ipairs(granted.AddTypes) do
			local typeString = mapAST(type)
			if typeString == "SkillType.Triggered" then
				skill.isTrigger = true
			end
			out:write(typeString, ', ')
		end
		out:write('},\n')
		out:write('\texcludeSkillTypes = { ')
		for _, type in ipairs(granted.ExcludeTypes) do
			out:write(mapAST(type), ', ')
		end
		out:write('},\n')
		if skill.isTrigger then
			out:write('\tisTrigger = true,\n')
		end
		if granted.SupportGemsOnly then
			out:write('\tsupportGemsOnly = true,\n')
		end
		if granted.IgnoreMinionTypes then
			out:write('\tignoreMinionTypes = true,\n')
		end
		local weaponTypes = { }
		for _, class in ipairs(granted.WeaponRestrictions) do
			if weaponClassMap[class.Id] then
				weaponTypes[weaponClassMap[class.Id]] = true
			end
		end
		if next(weaponTypes) then
			out:write('\tweaponTypes = {\n')
			for type in pairs(weaponTypes) do
				out:write('\t\t["', type, '"] = true,\n')
			end
			out:write('\t},\n')
		end
		out:write('\tstatDescriptionScope = "gem_stat_descriptions",\n')
	else
		if #granted.ActiveSkill.Description > 0 then
			out:write('\tdescription = "', escapeGGGString(granted.ActiveSkill.Description:gsub('"','\\"'):gsub('\r',''):gsub('\n','\\n')), '",\n')
		end
		out:write('\tskillTypes = { ')
		for _, type in ipairs(granted.ActiveSkill.SkillTypes) do
			out:write('[', mapAST(type), '] = true, ')
		end
		if skill.addSkillTypes then
			for _, type in ipairs(skill.addSkillTypes) do
				out:write('[SkillType.', type , '] = true, ')
			end
		end
		out:write('},\n')
		if granted.ActiveSkill.MinionSkillTypes[1] then
			out:write('\tminionSkillTypes = { ')
			for _, type in ipairs(granted.ActiveSkill.MinionSkillTypes) do
				out:write('[', mapAST(type), '] = true, ')
			end
			out:write('},\n')
		end
		local weaponTypes = { }
		for _, class in ipairs(granted.ActiveSkill.WeaponRestrictions) do
			if weaponClassMap[class.Id] then
				weaponTypes[weaponClassMap[class.Id]] = true
			end
		end
		if next(weaponTypes) then
			out:write('\tweaponTypes = {\n')
			for type in pairs(weaponTypes) do
				out:write('\t\t["', type, '"] = true,\n')
			end
			out:write('\t},\n')
		end
		local file = getFile("Metadata/StatDescriptions/specific_skill_stat_descriptions/"..granted.ActiveSkill.Id..".csd")
		if file then
			skillStatScope[granted.ActiveSkill.Id] = granted.ActiveSkill.Id
		end
		out:write('\tstatDescriptionScope = "', skillStatScope[granted.ActiveSkill.Id] or "skill_stat_descriptions", '",\n')
		if granted.ActiveSkill.SkillTotem <= 21 then
			out:write('\tskillTotemId = ', granted.ActiveSkill.SkillTotem, ',\n')
		end
		out:write('\tcastTime = ', granted.CastTime / 1000, ',\n')
		if granted.CannotBeSupported then
			out:write('\tcannotBeSupported = true,\n')
		end
	end
end

directiveTable.startSets = function(state, args, out)
	out:write('\tstatSets = {\n')
end

-- #set <GrantedEffectStatSetsId>
-- Initialises the statSet data and emits information pertaining to statSet 
directiveTable.set = function(state, args, out)
	local statSetId = args
	local grantedEffectStatSet = dat("GrantedEffectStatSets"):GetRow("Id", statSetId)
	local statsPerLevel = dat("GrantedEffectStatSetsPerLevel"):GetRowList("GrantedEffectStatSets", grantedEffectStatSet)
	local label = grantedEffectStatSet.LabelType and grantedEffectStatSet.LabelType.Id or state.skill.displayName
	local set = { }
	state.skill.sets[args] = set
	state.set = set
	set.baseFlags = { }
	set.mods = { }
	set.levels = { }
	set.stats = { }
	set.constantStats = { }
	
	local statMap = { }
	local statMapOrder = {}

	for indx = 1, #statsPerLevel do
		local statRow = statsPerLevel[indx]
		local level = { extra = { }, statInterpolation = { }, actorLevel = 1 } 
		level.level = statRow.GemLevel
		-- stat based level info
		--if statRow.DamageEffectiveness ~= 0 then
		--	level.extra.damageEffectiveness = statRow.DamageEffectiveness / 10000 + 1
		--end
		if statRow.AttackCritChance ~= 0 then
			level.extra.critChance = statRow.AttackCritChance / 100
		end
		if statRow.OffhandCritChance ~= 0 then
			level.extra.critChance = statRow.OffhandCritChance / 100
		end
		if statRow.BaseMultiplier and statRow.BaseMultiplier ~= 0 then
			level.extra.baseMultiplier = statRow.BaseMultiplier / 10000 + 1
		end
		level.statInterpolation = statRow.StatInterpolations
		level.actorLevel = statRow.ActorLevel
		local resolveInterpolation = false
		local injectConstantValuesIntoEachLevel = false
		local statMapOrderIndex = 1
		for i, stat in ipairs(statRow.FloatStats) do
			if not statMap[stat.Id] or indx == 1 then
				statMap[stat.Id] = #set.stats + 1
				table.insert(set.stats, { id = stat.Id })
				if indx == 1 then
					table.insert(statMapOrder, stat.Id)
				else
					print(label .. ": stat missing from earlier levels: ".. stat.Id)
				end
			elseif statMapOrder[statMapOrderIndex] ~= stat.Id then
				-- add missing stats
				while statMapOrderIndex < #statMapOrder and statMapOrder[statMapOrderIndex] ~= stat.Id do
					table.insert(level, 0)
					if #level.statInterpolation < #statMapOrder then
						table.insert(level.statInterpolation, statMapOrderIndex, "0")
					end
					statMapOrderIndex = statMapOrderIndex + 1
				end
			end
			statMapOrderIndex = statMapOrderIndex + 1
			if resolveInterpolation then
				table.insert(level, statRow.BaseResolvedValues[i])
				level.statInterpolation[statMapOrderIndex] = 1
			else
				table.insert(level, statRow.FloatStatsValues[i] / math.max(statRow.InterpolationBases[i].Value, 0.00001) )
			end
		end
		if injectConstantValuesIntoEachLevel then
			for i, stat in ipairs(grantedEffectStatSet.ConstantStats) do
				if not statMap[stat.Id] then
					statMap[stat.Id] = #set.stats + #set.constantStats + 1
					table.insert(set.stats, { id = stat.Id })
					if indx == 1 then
						table.insert(statMapOrder, stat.Id)
					else
						print(label .. ": stat missing from earlier levels: ".. stat.Id)
					end
				elseif statMapOrder[statMapOrderIndex] ~= stat.Id then
					-- add missing stats
					while statMapOrderIndex < #statMapOrder and statMapOrder[statMapOrderIndex] ~= stat.Id do
						table.insert(level, 0)
						if #level.statInterpolation < #statMapOrder then
							table.insert(level.statInterpolation, statMapOrderIndex, "0")
						end
						statMapOrderIndex = statMapOrderIndex + 1
					end
				end
				statMapOrderIndex = statMapOrderIndex + 1
				table.insert(level, grantedEffectStatSet.ConstantStatsValues[i])
				table.insert(level.statInterpolation, #statRow.FloatStats + 1, 1)
			end
		end
		for i, stat in ipairs(statRow.AdditionalStats) do
			if not statMap[stat.Id] then
				statMap[stat.Id] = #set.stats + 1
				table.insert(set.stats, { id = stat.Id })
				if indx == 1 then
					table.insert(statMapOrder, stat.Id)
				else
					print(label .. ": stat missing from earlier levels: ".. stat.Id)
				end
			elseif statMapOrder[statMapOrderIndex] ~= stat.Id then
				-- add missing stats
				while statMapOrderIndex < #statMapOrder and statMapOrder[statMapOrderIndex] ~= stat.Id do
					table.insert(level, 0)
					if #level.statInterpolation < #statMapOrder then
						table.insert(level.statInterpolation, statMapOrderIndex, "0")
					end
					statMapOrderIndex = statMapOrderIndex + 1
				end
			end
			statMapOrderIndex = statMapOrderIndex + 1
			table.insert(level, statRow.AdditionalStatsValues[i])
		end
		for i, stat in ipairs(statRow.AdditionalBooleanStats) do
			if not statMap[stat.Id] then
				statMap[stat.Id] = #set.stats + 1
				table.insert(set.stats, { id = stat.Id })
			end
		end
		table.insert(set.levels, level)
	end
	if grantedEffectStatSet and grantedEffectStatSet.ImplicitStats then
		for i, stat in ipairs(grantedEffectStatSet.ImplicitStats) do
			if not statMap[stat.Id] then
				statMap[stat.Id] = #set.stats + 1
				table.insert(set.stats, { id = stat.Id })
			end
		end
	end
	if grantedEffectStatSet and grantedEffectStatSet.ConstantStats then
		for i, stat in ipairs(grantedEffectStatSet.ConstantStats) do
			table.insert(set.constantStats, { stat.Id, grantedEffectStatSet.ConstantStatsValues[i] })
		end
	end

	-- Emitting statSet data
	out:write('\t\t['..state.skill.setIndex..'] = {\n')
	state.skill.setIndex = state.skill.setIndex + 1
	out:write('\t\t\tlabel = "'..state.skill.displayName..'",\n')
	if grantedEffectStatSet.BaseEffectiveness ~= 1 then
		out:write('\t\t\tbaseEffectiveness = ', grantedEffectStatSet.BaseEffectiveness, ',\n')
	end
	if grantedEffectStatSet.IncrementalEffectiveness ~= 0 then
		out:write('\t\t\tincrementalEffectiveness = ', grantedEffectStatSet.IncrementalEffectiveness, ',\n')
	end
	if grantedEffectStatSet.DamageIncrementalEffectiveness ~= 0 then
		out:write('\t\t\tdamageIncrementalEffectiveness = ', grantedEffectStatSet.DamageIncrementalEffectiveness, ',\n')
	end
end

-- #flags <flag>[ <flag>[...]]
-- Sets the base flags for this active set
directiveTable.flags = function(state, args, out)
	local set = state.set
	for flag in args:gmatch("%a+") do
		table.insert(set.baseFlags, flag)
	end
end

-- #baseMod <mod definition>
-- Adds a base modifier to the set
directiveTable.baseMod = function(state, args, out)
	local set = state.set
	table.insert(set.mods, args)
end

-- #mods
-- Emits the set modifiers
directiveTable.mods = function(state, args, out)
	local set = state.set
	if not set then
		print("No statSet set, you're likely missing a #set directive in the .txt file")
		return
	end
	if not args:match("noBaseFlags") then
		if not set.isSupport then
			out:write('\t\t\tbaseFlags = {\n')
			for _, flag in ipairs(set.baseFlags) do
				out:write('\t\t\t\t', flag, ' = true,\n')
			end
			out:write('\t\t\t},\n')
		end
	end
	if not args:match("noBaseMods") then
		if next(set.mods) ~= nil then
			out:write('\t\t\tbaseMods = {\n')
			for _, mod in ipairs(set.mods) do
				out:write('\t\t\t\t', mod, ',\n')
			end
			out:write('\t\t\t},\n')
		end
	end
	if not args:match("noStats") then
		if next(set.constantStats) ~= nil then
			-- write out constant stats that don't change per level
			out:write('\t\t\tconstantStats = {\n')
			for _, stat in ipairs(set.constantStats) do
				out:write('\t\t\t\t{ "', stat[1], '", ', stat[2], ' },\n')
			end
			out:write('\t\t\t},\n')
		end
		out:write('\t\t\tstats = {\n')
		for _, stat in ipairs(set.stats) do
			out:write('\t\t\t\t"', stat.id, '",\n')
		end
		out:write('\t\t\t},\n')
	end
	if not args:match("noLevels") then
		out:write('\t\t\tlevels = {\n')
		for index, level in ipairs(set.levels) do
			out:write('\t\t\t\t[', level.level, '] = { ')
			for _, statVal in ipairs(level) do
				out:write(tostring(statVal), ', ')
			end
			for k, v in pairs(level.extra) do
				out:write(k, ' = ', tostring(v), ', ')
			end
			if next(level.statInterpolation) ~= nil then
				out:write('statInterpolation = { ')
				for _, type in ipairs(level.statInterpolation) do
					out:write(type, ', ')
				end
				out:write('}, ')
			end
			if level.actorLevel ~= nil then
				out:write('actorLevel = ', level.actorLevel, ', ')
			end
			out:write('},\n')
		end
		out:write('\t\t\t},\n')
	end
	out:write('\t\t},\n')
	state.set = nil
end

directiveTable.skillEnd = function(state, args, out)
	out:write('\t}\n')
	out:write('}')
	state.skill = nil
end

for _, name in pairs({"act_str","act_dex","act_int","other","sup_str","sup_dex","sup_int"}) do
	processTemplateFile(name, "Skills/", "../Data/Skills/", directiveTable)
end

local out = io.open("../Data/Gems.lua", "w")
out:write('-- This file is automatically generated, do not edit!\n')
out:write('-- Gem data (c) Grinding Gear Games\n\nreturn {\n')
for skillGem in dat("SkillGems"):Rows() do
	for _, gemEffect in ipairs(skillGem.GemEffects) do
		if gems[gemEffect.Id] then
			out:write('\t["', "Metadata/Items/Gems/SkillGem" .. gemEffect.Id, '"] = {\n')
			out:write('\t\tname = "', fullNameGems[skillGem.BaseItemType.Id] and skillGem.BaseItemType.Name or trueGemNames[gemEffect.Id] or skillGem.BaseItemType.Name:gsub(" Support",""), '",\n')
			-- Hybrid gems (e.g. Vaal gems) use the display name of the active skill e.g. Vaal Summon Skeletons of Sorcery
			if not skillGem.IsSupport then
				out:write('\t\tbaseTypeName = "', gemEffect.GrantedEffect.ActiveSkill.DisplayName, '",\n')
			end
			out:write('\t\tgameId = "', skillGem.BaseItemType.Id, '",\n')
			out:write('\t\tvariantId = "', gemEffect.Id, '",\n')
			out:write('\t\tgrantedEffectId = "', gemEffect.GrantedEffect.Id, '",\n')
			if gemEffect.GrantedEffect.AdditionalStatSets then
				for count, additionalGrantedEffect in ipairs(gemEffect.GrantedEffect.AdditionalStatSets) do
					out:write('\t\tadditionalStatSet' .. tostring(count) .. ' = "', additionalGrantedEffect.Id, '",\n')
				end
			end
			if gemEffect.AdditionalGrantedEffects then
				for count, additionalGrantedEffect in ipairs(gemEffect.AdditionalGrantedEffects) do
					out:write('\t\tadditionalGrantedEffectId' .. tostring(count) .. ' = "', additionalGrantedEffect.Id, '",\n')
				end
			end
			if #gemEffect.SecondarySupportName > 0 then
				out:write('\t\tsecondaryEffectName = "', gemEffect.SecondarySupportName, '",\n')
			end
			if skillGem.IsVaalGem then
				out:write('\t\tvaalGem = true,\n')
			end
			local tagNames = { }
			out:write('\t\ttags = {\n')
			for _, tag in ipairs(gemEffect.Tags) do
				out:write('\t\t\t', tag.Id, ' = true,\n')
				if #tag.Name > 0 then
					tag.Name = escapeGGGString(tag.Name) --Remove the words in brackets e.g. [DurationSkill|Duration] -> Duration
					table.insert(tagNames, tag.Name)
				end
			end
			out:write('\t\t},\n')
			out:write('\t\ttagString = "', table.concat(tagNames, ", "), '",\n')
			out:write('\t\treqStr = ', skillGem.Str, ',\n')
			out:write('\t\treqDex = ', skillGem.Dex, ',\n')
			out:write('\t\treqInt = ', skillGem.Int, ',\n')
			local naturalMaxLevel = #dat("ItemExperiencePerLevel"):GetRowList("ItemExperienceType", skillGem.GemLevelProgression)
			out:write('\t\tnaturalMaxLevel = ', naturalMaxLevel > 0 and naturalMaxLevel or 1, ',\n')
			out:write('\t},\n')
		end
	end
end
out:write('}')
out:close()

print("Skill data exported.")
