-- Path of Building
--
-- Module: Config Options
-- List of options for the Configuration tab.
--

local m_min = math.min
local m_max = math.max
local s_format = string.format


local function bossSkillsTooltip(tooltip, mode, index, value)
	local applyModes = { BODY = true, HOVER = true }
	tooltip:Clear()
	if applyModes[mode] then
		tooltip:AddLine(14, localisation:Text("ui.config_options.boss_skills_tooltip.tooltip"))
		if value.val ~= "None" then
			tooltip:AddLine(14, '\n^7'..value.val..": "..data.bossSkills[value.val].tooltip)
		end
	end
end

local function LowLifeTooltip(modList, build)
	return localisation:Text('ui.config_options.low_life_tooltip.message', { reserved = 100 - build.calcsTab.mainOutput.LowLifePercentage })
end

local function FullLifeTooltip(modList, build)
	return localisation:Text('ui.config_options.full_life_tooltip.message', { remaining = build.calcsTab.mainOutput.FullLifePercentage })
end

local function questModsRewards(source, line, modList)
	local strippedLine = StripEscapes(line):gsub("^[%s?]+", ""):gsub("[%s?]+$", "")
	local mods, extra = modLib.parseMod(strippedLine)

	if mods and not extra then
		for i = 1, #mods do
			local mod = mods[i]

			if mod then
				mod = modLib.setSource(mod, source)
				modList:AddMod(mod)
			end
		end
	end
end

local function addQuestModsRewardsConfigOptions(configSettings)
	table.insert(configSettings, { section = "Quest Rewards", sectionKey = "ui.config_options.add_quest_mods_rewards_config_options.section", col = 3 })

	-- Loop through sections of line to apply multiple mods
	local function applyModsFromString(source, str, modList)
		for line in tostring(str):gmatch("[^\r\n]+") do
			if line ~= "" then
				questModsRewards(source, line, modList)
			end
		end
	end

	for _, quest in ipairs(data.questRewards) do
		if quest.useConfig == false then
			goto continue
		end
		local key = "quest" .. quest.Description .. quest.Area .. quest.Info
		local label = string.format("%s: %s", quest.Description, quest.Area)
		local labelParams = { act = localisation:Ref(quest.DescriptionKey), area = localisation:Ref(quest.AreaKey) }
		local source = string.format("Quest:%s: %s", quest.Description, quest.Area)
		if quest.Stat then
			table.insert(configSettings, {
				var = key,
				label = label,
				labelKey = 'quest.reward.label', labelParams = labelParams,
				type = "check",
				defaultState = true,
				tooltip = function()
					return localisation:Text('quest.reward.tooltip', { info = localisation:Field(quest, 'Info'), stat = localisation:Field(quest, 'Stat') })
				end,
				apply = function(val, modList, enemyModList)
					applyModsFromString(source, quest.Stat, modList)
				end
			})
		elseif quest.Options then
			local listOptions = { { label = "^1Nothing^7", labelKey = "ui.config_options.add_quest_mods_rewards_config_options.list_options.label", val = "None" } }
			for index, option in ipairs(quest.Options) do
				table.insert(listOptions, { label = option, labelKey = quest['Option_' .. index .. 'Key'], val = option })
			end
			table.insert(configSettings, {
				var = key,
				label = label,
				labelKey = 'quest.reward.label', labelParams = labelParams,
				type = "list",
				list = listOptions,
				defaultIndex = 1,
				tooltip = function()
					local options = { }
					for index in ipairs(quest.Options) do options[index] = localisation:Field(quest, 'Option_' .. index) end
					return localisation:Text('quest.reward.choice_tooltip', { info = localisation:Field(quest, 'Info'), options = table.concat(options, '\n') })
				end,
				apply = function(val, modList, enemyModList)
				if val == "None" then
					return
				end
				applyModsFromString(source, val, modList)
				end
			})
		end
		::continue::
	end
end

local configSettings = {
	-- Section: General options
	{ section = "General", sectionKey = "ui.config_options.module.config_settings.section_4", col = 1 },
	{ var = "resistancePenalty", type = "list", label = "Elemental Resistance penalty:", labelKey = "ui.config_options.module.resistance_penalty.label_7", list = {{val=0,label="Act 1 (0%)", labelKey = "ui.config_options.module.resistance_penalty.label"},{val=-10,label="Act 2 (-10%)", labelKey = "ui.config_options.module.resistance_penalty.label_2"},{val=-20,label="Act 3 (-20%)", labelKey = "ui.config_options.module.resistance_penalty.label_3"},{val=-30,label="Act 4 (-30%)", labelKey = "ui.config_options.module.resistance_penalty.label_4"},{val=-40,label="Act 5 (-40%)", labelKey = "ui.config_options.module.resistance_penalty.label_5"},{val=-50,label="Act 6 (-50%)", labelKey = "ui.config_options.module.resistance_penalty.label_6"},{val=-60,label="Endgame (-60%)", labelKey = "ui.config_options.module.resistance_penalty.label_8"}}, defaultIndex = 7 },
	{ var = "detonateDeadCorpseLife", type = "count", label = "Enemy Corpse ^xE05030Life:", labelKey = "ui.config_options.module.detonate_dead_corpse_life.label", ifSkillData = "explodeCorpse", tooltip = "Sets the maximum ^xE05030life ^7of the target corpse for Detonate Dead and similar skills.\nFor reference, a level 70 monster has "..data.monsterLifeTable[70].." base ^xE05030life^7, and a level 80 monster has "..data.monsterLifeTable[80]..".", tooltipKey = "ui.config_options.module.detonate_dead_corpse_life.tooltip", tooltipParams = { value = data.monsterLifeTable[70], value_2 = data.monsterLifeTable[80] }, apply = function(val, modList, enemyModList)
		modList:NewMod("SkillData", "LIST", { key = "corpseLife", value = val }, "Config")
	end },
	{ var = "multiplierCurrentManaPercentage", type = "count", label = "Current ^x7070FFMana^7 %:", labelKey = "ui.config_options.module.multiplier_current_mana_percentage.label", ifSkillData = "currentManaPercentage", defaultState = 100, apply = function(val, modList, enemyModList)
		modList:NewMod("Multiplier:CurrentManaPercentage", "BASE", m_max(m_min(val,100), 0), "Config")
	end },
	{ var = "conditionStationary", type = "count", label = "Time spent stationary", labelKey = "ui.config_options.module.condition_stationary.label", ifCond = "Stationary",
		tooltip = "Applies mods that use `while stationary` and `per / every second while stationary`", tooltipKey = "ui.config_options.module.condition_stationary.tooltip",
		apply = function(val, modList, enemyModList)
		if type(val) == "boolean" then
			-- Backwards compatibility with older versions that set this condition as a boolean
			val = val and 1 or 0
		end
		local sanitizedValue = m_max(0, val)
		modList:NewMod("Multiplier:StationarySeconds", "BASE", sanitizedValue, "Config")
		if sanitizedValue > 0 then
			modList:NewMod("Condition:Stationary", "FLAG", true, "Config")
		end
	end },
	{ var = "conditionMoving", type = "check", label = "Are you always moving?", labelKey = "ui.config_options.module.condition_moving.label", ifCond = "Moving", apply = function(val, modList, enemyModList)
		modList:NewMod("Condition:Moving", "FLAG", true, "Config")
	end },
	{ var = "conditionFullLife", type = "check", label = "Are you always on Full ^xE05030Life?", labelKey = "ui.config_options.module.condition_full_life.label", ifCond = "FullLife", tooltip = FullLifeTooltip, apply = function(val, modList, enemyModList)
		modList:NewMod("Condition:FullLife", "FLAG", true, "Config")
	end },
	{ var = "conditionLowLife", type = "check", label = "Are you always on Low ^xE05030Life?", labelKey = "ui.config_options.module.condition_low_life.label", ifCond = "LowLife", tooltip = LowLifeTooltip, apply = function(val, modList, enemyModList)
		modList:NewMod("Condition:LowLife", "FLAG", true, "Config")
	end },
	{ var = "conditionFullMana", type = "check", label = "Are you always on Full ^x7070FFMana?", labelKey = "ui.config_options.module.condition_full_mana.label", ifCond = "FullMana", apply = function(val, modList, enemyModList)
		modList:NewMod("Condition:FullMana", "FLAG", true, "Config")
	end },
	{ var = "conditionLowMana", type = "check", label = "Are you always on Low ^x7070FFMana?", labelKey = "ui.config_options.module.condition_low_mana.label", ifCond = "LowMana", tooltip = "You will automatically be considered to be on Low ^x7070FFMana ^7if you have at least 50% ^x7070FFmana ^7reserved,\nbut you can use this option to force it if necessary.", tooltipKey = "ui.config_options.module.condition_low_mana.tooltip", apply = function(val, modList, enemyModList)
		modList:NewMod("Condition:LowMana", "FLAG", true, "Config")
	end },
	{ var = "conditionFullEnergyShield", type = "check", label = "Are you always on Full ^x88FFFFEnergy Shield?", labelKey = "ui.config_options.module.condition_full_energy_shield.label", ifCond = "FullEnergyShield", apply = function(val, modList, enemyModList)
		modList:NewMod("Condition:FullEnergyShield", "FLAG", true, "Config")
	end },
	{ var = "conditionLowEnergyShield", type = "check", label = "Are you always on Low ^x88FFFFEnergy Shield?", labelKey = "ui.config_options.module.condition_low_energy_shield.label", ifCond = "LowEnergyShield", tooltip = "You will automatically be considered to be on Low ^x88FFFFEnergy Shield ^7if you have at least 50% ^x88FFFFES ^7reserved,\nbut you can use this option to force it if necessary.", tooltipKey = "ui.config_options.module.condition_low_energy_shield.tooltip", apply = function(val, modList, enemyModList)
		modList:NewMod("Condition:LowEnergyShield", "FLAG", true, "Config")
	end },
	{ var = "conditionHaveEnergyShield", type = "check", label = "Do you always have ^x88FFFFEnergy Shield?", labelKey = "ui.config_options.module.condition_have_energy_shield.label", ifCond = "HaveEnergyShield", apply = function(val, modList, enemyModList)
		modList:NewMod("Condition:HaveEnergyShield", "FLAG", true, "Config")
	end },
	{ var = "multiplierCurrentEnergyShield", type = "count", label = "Current ^x88FFFFEnergy Shield^7 percentage:", labelKey = "ui.config_options.module.multiplier_current_energy_shield.label", ifCond = "UseCurrentEnergyShield", defaultPlaceholderState = 100, tooltip = "Used in calculations for ^xAF6025Silks of Veneration^7 and ^xAF6025The Mutable Star^7.\nOverflowed ^x88FFFFEnergy Shield^7 is allowed, up to 150%.", tooltipKey = "ui.config_options.module.multiplier_current_energy_shield.tooltip", apply = function(val, modList, enemyModList)
		modList:NewMod("Condition:UseCurrentEnergyShield", "FLAG", true, "Config")
		modList:NewMod("Multiplier:CurrentEnergyShield", "BASE", val, "Config")
	end },
	{ var = "conditionLowRunicWard", type = "check", label = "Are you on low ^xFFFF77Runic Ward?", labelKey = "ui.config_options.module.condition_low_runic_ward.label", ifCond = "LowRunicWard", tooltip = "You are on Low ^xFFFF77Runic Ward^7 if you have 35% of your maximum ^xFFFF77Runic Ward^7 or less.", tooltipKey = "ui.config_options.module.condition_low_runic_ward.tooltip", apply = function(val, modList, enemyModList)
		modList:NewMod("Condition:LowRunicWard", "FLAG", true, "Config")
		modList:NewMod("Condition:MissingRunicWard", "FLAG", true, "Config")
	end },
	{ var = "conditionMissingRunicWard", type = "check", label = "Are you missing ^xFFFF77Runic Ward?", labelKey = "ui.config_options.module.condition_missing_runic_ward.label", ifCond = "MissingRunicWard", apply = function(val, modList, enemyModList)
		modList:NewMod("Condition:MissingRunicWard", "FLAG", true, "Config")
	end },
	{ var = "conditionNoRunicWard", type = "check", label = "Do you have no ^xFFFF77Runic Ward?", labelKey = "ui.config_options.module.condition_no_runic_ward.label", ifCond = "NoRunicWard", apply = function(val, modList, enemyModList)
		modList:NewMod("Condition:NoRunicWard", "FLAG", true, "Config")
		modList:NewMod("Condition:LowRunicWard", "FLAG", true, "Config")
		modList:NewMod("Condition:MissingRunicWard", "FLAG", true, "Config")
	end },
	{ var = "minionsConditionFullLife", type = "check", label = "Are your Minions always on Full ^xE05030Life?", labelKey = "ui.config_options.module.minions_condition_full_life.label", ifMinionCond = "FullLife", apply = function(val, modList, enemyModList)
		modList:NewMod("MinionModifier", "LIST", { mod = modLib.createMod("Condition:FullLife", "FLAG", true, "Config") }, "Config")
	end },
	{ var = "minionsConditionFullEnergyShield", type = "check", label = "Minion is always on Full ^x88FFFFEnergy Shield?", labelKey = "ui.config_options.module.minions_condition_full_energy_shield.label", ifMinionCond = "FullEnergyShield", apply = function(val, modList, enemyModList)
		modList:NewMod("MinionModifier", "LIST", { mod = modLib.createMod("Condition:FullEnergyShield", "FLAG", true, "Config") }, "Config")
	end },
	{ var = "minionsConditionCreatedRecently", type = "check", label = "Have your Minions been created Recently?", labelKey = "ui.config_options.module.minions_condition_created_recently.label", ifCond = "MinionsCreatedRecently", apply = function(val, modList, enemyModList)
		modList:NewMod("Condition:MinionsCreatedRecently", "FLAG", true, "Config")
	end },
	{ var = "ailmentMode", type = "list", label = "Ailment calculation mode:", labelKey = "ui.config_options.module.ailment_mode.label", tooltip = "Controls how the base damage for applying Ailments is calculated:\n\tAverage: damage is based on the average application, including both crits and non-crits\n\tCrits Only: damage is based solely on Ailments inflicted with crits", tooltipKey = "ui.config_options.module.ailment_mode.tooltip", list = {{val="AVERAGE",label="Average", labelKey = "ui.config_options.module.ailment_mode.label_2"},{val="CRIT",label="Crits Only", labelKey = "ui.config_options.module.ailment_mode.label_3"}} },
	{ var = "cooldownMode", type = "list", label = "Cooldown calculation mode:", labelKey = "ui.config_options.module.cooldown_mode.label_2", tooltip = "Controls how the cooldown for skills is calculated:\n\tBase: The cooldown is calculated with normal behavior.\n\tAverage: The cooldown is adjusted to reflect the average time between uses, factoring in effects such as a chance to not consume a cooldown.", tooltipKey = "ui.config_options.module.cooldown_mode.tooltip", list = {{val="BASE",label="Base", labelKey = "ui.config_options.module.cooldown_mode.label"},{val="AVERAGE",label="Average", labelKey = "ui.config_options.module.ailment_mode.label_2"}} },
	{ var = "physMode", type = "list", label = "Random element mode:", labelKey = "ui.config_options.module.phys_mode.label_4", ifFlag = "randomPhys", tooltip = "Controls how modifiers which choose a random element will function.\n\tAverage: Modifiers will grant one third of their value to ^xB97123Fire^7, ^x3F6DB3Cold^7, and ^xADAA47Lightning ^7simultaneously\n\t^xB97123Fire ^7/ ^x3F6DB3Cold ^7/ ^xADAA47Lightning^7: Modifiers will grant their full value as the specified element\nIf a modifier chooses between just two elements, the full value can only be given as those two elements.", tooltipKey = "ui.config_options.module.phys_mode.tooltip", list = {{val="AVERAGE",label="Average", labelKey = "ui.config_options.module.ailment_mode.label_2"},{val="FIRE",label="^xB97123Fire", labelKey = "ui.config_options.module.phys_mode.label_2"},{val="COLD",label="^x3F6DB3Cold", labelKey = "ui.config_options.module.phys_mode.label"},{val="LIGHTNING",label="^xADAA47Lightning", labelKey = "ui.config_options.module.phys_mode.label_3"}} },
	{ var = "lifeRegenMode", type = "list", label = "^xE05030Life ^7regen calculation mode:", labelKey = "ui.config_options.module.life_regen_mode.label_2", ifCond = { "LifeRegenBurstAvg", "LifeRegenBurstFull" }, tooltip = "Controls how ^xE05030Life ^7regeneration is calculated:\n\tMinimum: does not include burst regen\n\tAverage: includes burst regen, averaged based on uptime\n\tBurst: includes full burst regen", tooltipKey = "ui.config_options.module.life_regen_mode.tooltip", list = {{val="MIN",label="Minimum", labelKey = "ui.config_options.module.life_regen_mode.label_3"},{val="AVERAGE",label="Average", labelKey = "ui.config_options.module.ailment_mode.label_2"},{val="FULL",label="Burst", labelKey = "ui.config_options.module.life_regen_mode.label"}}, apply = function(val, modList, enemyModList)
		if val == "AVERAGE" then
			modList:NewMod("Condition:LifeRegenBurstAvg", "FLAG", true, "Config")
		elseif val == "FULL" then
			modList:NewMod("Condition:LifeRegenBurstFull", "FLAG", true, "Config")
		end
	end },
	{ var = "resourceGainMode", type = "list", label = "Resource gain calculation mode:", labelKey = "ui.config_options.module.resource_gain_mode.label_2", ifCond = "AverageResourceGain", defaultIndex = 2, tooltip = "Controls how resource on hit/kill is calculated:\n\tMinimum: does not include chances\n\tAverage: includes chance gains, averaged based on uptime\n\tMaximum: treats all chances as certain", tooltipKey = "ui.config_options.module.resource_gain_mode.tooltip", list = {{val="MIN",label="Minimum", labelKey = "ui.config_options.module.life_regen_mode.label_3"},{val="AVERAGE",label="Average", labelKey = "ui.config_options.module.ailment_mode.label_2"},{val="MAX",label="Maximum", labelKey = "ui.config_options.module.resource_gain_mode.label"}}, apply = function(val, modList, enemyModList)
		if val == "AVERAGE" then
			modList:NewMod("Condition:AverageResourceGain", "FLAG", true, "Config")
		elseif val == "MAX" then
			modList:NewMod("Condition:MaxResourceGain", "FLAG", true, "Config")
		end
	end },
	{ var = "EHPUnluckyWorstOf", type = "list", label = "EHP calc unlucky:", labelKey = "ui.config_options.module.ehpunlucky_worst_of.label", tooltip = "Sets the EHP calc to pretend its unlucky and reduce the effects of random events such as\n\tBlock/Spell Block Chance\n\tDodge/Spell Dodge Chance\n\tSpell Suppression Chance\n\tAvoidance Chance", tooltipKey = "ui.config_options.module.ehpunlucky_worst_of.tooltip", list = {{val=1,label="Average", labelKey = "ui.config_options.module.ailment_mode.label_2"},{val=2,label="Unlucky", labelKey = "ui.config_options.module.ehpunlucky_worst_of.label_2"},{val=4,label="Very Unlucky", labelKey = "ui.config_options.module.ehpunlucky_worst_of.label_3"}} },
	{ var = "DisableEHPGainOnBlock", type = "check", label = "Disable EHP gain on block/suppress:", labelKey = "ui.config_options.module.disable_ehpgain_on_block.label", ifMod = {"LifeOnBlock", "ManaOnBlock", "WardOnBlock", "EnergyShieldOnBlock", "EnergyShieldOnSpellBlock", "LifeOnSuppress", "EnergyShieldOnSuppress"}, tooltip = "Sets the EHP calc to not apply gain on block and suppress effects", tooltipKey = "ui.config_options.module.disable_ehpgain_on_block.tooltip"},
	{ var = "armourCalculationMode", type = "list", label = "Armour calculation mode:", labelKey = "ui.config_options.module.armour_calculation_mode.label", ifCond = { "ArmourMax", "ArmourAvg" }, tooltip = "Controls how Defending with Double Armour is calculated:\n\tMinimum: never Defend with Double Armour\n\tAverage: Damage Reduction from Defending with Double Armour is proportional to chance\n\tMaximum: always Defend with Double Armour\nThis setting has no effect if you have 100% chance to Defend with Double Armour.", tooltipKey = "ui.config_options.module.armour_calculation_mode.tooltip", list = {{val="MIN",label="Minimum", labelKey = "ui.config_options.module.life_regen_mode.label_3"},{val="AVERAGE",label="Average", labelKey = "ui.config_options.module.ailment_mode.label_2"},{val="MAX",label="Maximum", labelKey = "ui.config_options.module.resource_gain_mode.label"}}, apply = function(val, modList, enemyModList)
		if val == "MAX" then
			modList:NewMod("Condition:ArmourMax", "FLAG", true, "Config")
		elseif val == "AVERAGE" then
			modList:NewMod("Condition:ArmourAvg", "FLAG", true, "Config")
		end
	end },
	{ var = "warcryMode", type = "list", label = "Boosted calc mode:", labelKey = "ui.config_options.module.warcry_mode.label", tooltip = "Controls how ancestrally boosted attacks are calculated:\nAverage: Averages out Boost usage with cast time, attack speed and cooldown.\nMax Hit: Shows maximum hit for lining up all sources of ancestral boost.", tooltipKey = "ui.config_options.module.warcry_mode.tooltip", list = {{val="AVERAGE",label="Average", labelKey = "ui.config_options.module.ailment_mode.label_2"},{val="MAX",label="Max Hit", labelKey = "ui.config_options.module.warcry_mode.label_2"}}, apply = function(val, modList, enemyModList)
		if val == "MAX" then
			modList:NewMod("Condition:WarcryMaxHit", "FLAG", true, "Config")
		end
	end },
	{ var = "EVBypass", type = "check", label = "Disable Emperor's Vigilance Bypass", labelKey = "ui.config_options.module.evbypass.label", ifCond = "EVBypass", apply = function(val, modList, enemyModList)
		modList:NewMod("Condition:EVBypass", "FLAG", true, "Config")
	end },
	{ var = "ignoreItemDisablers", type = "check", label = "Don't disable items", labelKey = "ui.config_options.module.ignore_item_disablers.label", ifTagType = "DisablesItem", tooltip = "Ignore the effects of things which disable items, like Bringer of Rain", tooltipKey = "ui.config_options.module.ignore_item_disablers.tooltip" },
	{ var = "ignoreJewelLimits", type = "check", label = "Ignore Jewel Limits", labelKey = "ui.config_options.module.ignore_jewel_limits.label", tooltip = "Ignore the limits on jewels", tooltipKey = "ui.config_options.module.ignore_jewel_limits.tooltip" },

	-- Section: Skill-specific options
	{ section = "Skill Options", sectionKey = "ui.config_options.module.config_settings.section_5", col = 2 },
	{ label = "Arcane Cloak:", labelKey = "ui.config_options.module.config_settings.label_2", ifSkill = "Arcane Cloak"},
	{ var = "arcaneCloakUsedRecentlyCheck", type = "check", label = "Include in ^x7070FFMana ^7spent Recently?", labelKey = "ui.config_options.module.arcane_cloak_used_recently_check.label", ifSkill = "Arcane Cloak", tooltip = "When enabled, the mana spent by Arcane Cloak used at full mana \nwill be added to the value provided in # of ^x7070FFMana ^7spent Recently.", tooltipKey = "ui.config_options.module.arcane_cloak_used_recently_check.tooltip", apply = function(val, modList, enemyModList)
		modList:NewMod("Condition:ArcaneCloakUsedRecently", "FLAG", true, "Config")
	end },
	{ label = "Arc:", labelKey = "ui.config_options.module.config_settings.label", ifSkill = "Arc"},
	{ var = "arcLightningInfused", type = "check", label = "Lightning Infused?", labelKey = "ui.config_options.module.arc_lightning_infused.label", ifSkill = "Arc", apply = function(val, modList, enemyModList)
		modList:NewMod("Condition:ArcLightningInfused", "FLAG", true, "Config", { type = "Condition", var = "CannotConsumeInfusion", neg = true })
	end },
	{ label = "Eldritch Empowerment:", labelKey = "ui.config_options.module.config_settings.label_22", ifFlag = "EldritchEmpowerment" },
	{ var = "eldritchEmpowermentSacrifice", type = "check", label = "Are you Sacrificing?", labelKey = "ui.config_options.module.eldritch_empowerment_sacrifice.label", tooltip = "Sacrifice 5% ^x88FFFFEnergy Shield^7 when you cast a Spell to give that Spell 30% more Damage.", tooltipKey = "ui.config_options.module.eldritch_empowerment_sacrifice.tooltip", ifFlag = "EldritchEmpowerment", apply = function(val, modList, enemyModList)
		modList:NewMod("Condition:EldritchEmpowermentSacrifice", "FLAG", true, "Config")
	end },
	{ label = "Unwilling Offering:", labelKey = "ui.config_options.module.config_settings.label_84", ifFlag = "UnwillingOffering" },
	{ var = "unwillingOfferingPower", type = "count", label = "Power of Culled Enemy?", labelKey = "ui.config_options.module.unwilling_offering_power.label", tooltip = "Offerings created by culling enemies gain 1% increased effect per Power.\nUnique enemies always have 20 Power.", tooltipKey = "ui.config_options.module.unwilling_offering_power.tooltip", ifFlag = "UnwillingOffering", apply = function(val, modList, enemyModList)
		modList:NewMod("Multiplier:UnwillingOfferingPower", "BASE", val, "Config")
	end },
	{ label = "Aspect of the Avian:", labelKey = "ui.config_options.module.config_settings.label_3", ifSkill = "Aspect of the Avian" },
	{ var = "aspectOfTheAvianAviansMight", type = "check", label = "Is Avian's Might active?", labelKey = "ui.config_options.module.aspect_of_the_avian_avians_might.label", ifSkill = "Aspect of the Avian", apply = function(val, modList, enemyModList)
		modList:NewMod("Condition:AviansMightActive", "FLAG", true, "Config")
	end },
	{ var = "aspectOfTheAvianAviansFlight", type = "check", label = "Is Avian's Flight active?", labelKey = "ui.config_options.module.aspect_of_the_avian_avians_flight.label", ifSkill = "Aspect of the Avian", apply = function(val, modList, enemyModList)
		modList:NewMod("Condition:AviansFlightActive", "FLAG", true, "Config")
	end },
	{ label = "Aspect of the Cat:", labelKey = "ui.config_options.module.config_settings.label_4", ifSkill = "Aspect of the Cat" },
	{ var = "aspectOfTheCatCatsStealth", type = "check", label = "Is Cat's Stealth active?", labelKey = "ui.config_options.module.aspect_of_the_cat_cats_stealth.label", ifSkill = "Aspect of the Cat", apply = function(val, modList, enemyModList)
		modList:NewMod("Condition:CatsStealthActive", "FLAG", true, "Config")
	end },
	{ var = "aspectOfTheCatCatsAgility", type = "check", label = "Is Cat's Agility active?", labelKey = "ui.config_options.module.aspect_of_the_cat_cats_agility.label", ifSkill = "Aspect of the Cat", apply = function(val, modList, enemyModList)
		modList:NewMod("Condition:CatsAgilityActive", "FLAG", true, "Config")
	end },
	{ label = "Aspect of the Crab:", labelKey = "ui.config_options.module.config_settings.label_5", ifSkill = "Aspect of the Crab" },
	{ var = "overrideCrabBarriers", type = "count", label = "# of Crab Barriers (if not maximum):", labelKey = "ui.config_options.module.override_crab_barriers.label", ifSkill = "Aspect of the Crab", apply = function(val, modList, enemyModList)
		modList:NewMod("CrabBarriers", "OVERRIDE", val, "Config", { type = "Condition", var = "Combat" })
	end },
	{ label = "Aspect of the Spider:", labelKey = "ui.config_options.module.config_settings.label_6", ifSkill = "Aspect of the Spider" },
	{ var = "aspectOfTheSpiderWebStacks", type = "count", label = "# of Spider's Web Stacks:", labelKey = "ui.config_options.module.aspect_of_the_spider_web_stacks.label", ifSkill = "Aspect of the Spider", apply = function(val, modList, enemyModList)
		modList:NewMod("ExtraSkillMod", "LIST", { mod = modLib.createMod("Multiplier:SpiderWebApplyStack", "BASE", val) }, "Config", { type = "SkillName", skillName = "Aspect of the Spider" })
	end },
	{ label = "Banner Skills:", labelKey = "ui.config_options.module.config_settings.label_7", ifSkill = { "Dread Banner", "War Banner", "Defiance Banner" } },
	{ var = "bannerPlanted", type = "check", label = "Is Banner Planted?", labelKey = "ui.config_options.module.banner_planted.label", ifSkill = { "Dread Banner", "War Banner", "Defiance Banner" }, apply = function(val, modList, enemyModList)
		modList:NewMod("Condition:BannerPlanted", "FLAG", true, "Config")
	end },
	{ var = "bannerValour", type = "count", label = "Banner Valour:", labelKey = "ui.config_options.module.banner_valour.label", tooltip = "The amount of valour consumed for the placed banner", tooltipKey = "ui.config_options.module.banner_valour.tooltip", ifSkill = { "Dread Banner", "War Banner", "Defiance Banner" }, apply = function(val, modList, enemyModList)
		modList:NewMod("Multiplier:ValourStacks", "BASE", val, "Config", { type = "IgnoreCond" }, { type = "Condition", var = "Combat" })
	end },
	{ label = "Unbound Avatar:", labelKey = "ui.config_options.module.config_settings.label_82", ifSkill = "Unbound Avatar" },
	{ var = "Unbound", type = "check", label = "Are you Unbound?", labelKey = "ui.config_options.module.unbound.label", ifSkill = "Unbound Avatar", apply = function(val, modList, enemyModList)
		modList:NewMod("Condition:Unbound", "FLAG", true, "Config")
	end },
	{ label = "Bladestorm:", labelKey = "ui.config_options.module.config_settings.label_8", ifSkill = "Bladestorm", includeTransfigured = true },
	{ var = "bladestormInBloodstorm", type = "check", label = "Are you in a Bloodstorm?", labelKey = "ui.config_options.module.bladestorm_in_bloodstorm.label", ifSkill = "Bladestorm", includeTransfigured = true, apply = function(val, modList, enemyModList)
		modList:NewMod("Condition:BladestormInBloodstorm", "FLAG", true, "Config", { type = "SkillName", skillName = "Bladestorm", includeTransfigured = true })
	end },
	{ var = "bladestormInSandstorm", type = "check", label = "Are you in a Sandstorm?", labelKey = "ui.config_options.module.bladestorm_in_sandstorm.label", ifSkill = "Bladestorm", includeTransfigured = true, apply = function(val, modList, enemyModList)
		modList:NewMod("Condition:BladestormInSandstorm", "FLAG", true, "Config", { type = "SkillName", skillName = "Bladestorm", includeTransfigured = true })
	end },
	{ label = "Blood Sacrament:", labelKey = "ui.config_options.module.config_settings.label_9", ifSkill = "Blood Sacrament" },
	{ var = "bloodSacramentReservationEHP", type = "check", label = "Count Skill Reservation towards eHP?", labelKey = "ui.config_options.module.blood_sacrament_reservation_ehp.label", ifSkill = "Blood Sacrament", tooltip = "Use this option to disable the skill reservation factoring into eHP calculations", tooltipKey = "ui.config_options.module.blood_sacrament_reservation_ehp.tooltip",apply = function(val, modList, enemyModList)
		modList:NewMod("Condition:BloodSacramentReservationEHP", "FLAG", true, "Config")
	end },
	{ label = "Brand Skills:", labelKey = "ui.config_options.module.config_settings.label_10", ifSkill = { "Armageddon Brand", "Storm Brand", "Arcanist Brand", "Penance Brand", "Wintertide Brand" }, includeTransfigured = true }, -- I barely resisted the temptation to label this "Generic Brand:"
	{ var = "ActiveBrands", type = "count", label = "# of active Brands:", labelKey = "ui.config_options.module.active_brands.label", ifSkill = { "Armageddon Brand", "Storm Brand", "Arcanist Brand", "Penance Brand", "Wintertide Brand" }, includeTransfigured = true , apply = function(val, modList, enemyModList)
		modList:NewMod("Multiplier:ConfigActiveBrands", "BASE", val, "Config")
	end },
	{ var = "BrandsAttachedToEnemy", type = "count", label = "# of Brands attached to the enemy:", labelKey = "ui.config_options.module.brands_attached_to_enemy.label", ifEnemyMult = "BrandsAttached", apply = function(val, modList, enemyModList)
		modList:NewMod("Multiplier:ConfigBrandsAttachedToEnemy", "BASE", val, "Config")
	end },
	{ var = "targetBrandedEnemy", type = "check", label = "Skill is targeting the Branded enemy", labelKey = "ui.config_options.module.target_branded_enemy.label", ifCond = "TargetingBrandedEnemy", defaultState = true, apply = function(val, modList, enemyModList)
		modList:NewMod("Condition:TargetingBrandedEnemy", "FLAG", true, "Config")
	end },
	{ var = "BrandsInLastQuarter", type = "check", label = "Last 25% of attached duration?", labelKey = "ui.config_options.module.brands_in_last_quarter.label", ifCond = "BrandLastQuarter", apply = function(val, modList, enemyModList)
		modList:NewMod("Condition:BrandLastQuarter", "FLAG", true, "Config")
		modList:NewMod("Condition:BrandLastHalf", "FLAG", true, "Config")
	end },
	{ var = "BrandsInLastHalf", type = "check", label = "Last 50% of attached duration?", labelKey = "ui.config_options.module.brands_in_last_half.label", ifCond = "BrandLastHalf", apply = function(val, modList, enemyModList)
		modList:NewMod("Condition:BrandLastHalf", "FLAG", true, "Config")
	end },
	{ label = "Carrion Golem:", labelKey = "ui.config_options.module.config_settings.label_11", ifSkill = "Summon Carrion Golem", includeTransfigured = true },
	{ var = "carrionGolemNearbyMinion", type = "count", label = "# of Nearby Non-Golem Minions:", labelKey = "ui.config_options.module.carrion_golem_nearby_minion.label", ifSkill = "Summon Carrion Golem", includeTransfigured = true, apply = function(val, modList, enemyModList)
		modList:NewMod("Multiplier:NearbyNonGolemMinion", "BASE", val, "Config")
	end },
	{ var = "carrionGolemEqualsChaosGolem", type = "check", label = "# Carrion Golem = # Chaos Golem:", labelKey = "ui.config_options.module.carrion_golem_equals_chaos_golem.label", ifCond = "CarrionEqualChaosGolem", ifSkill = "Summon Chaos Golem", includeTransfigured = true, apply = function(val, modList, enemyModList)
		modList:NewMod("Condition:CarrionEqualChaosGolem", "FLAG", true, "Config")
	end },
	{ var = "chaosGolemEqualsStoneGolem", type = "check", label = "# Chaos Golem = # Stone Golem:", labelKey = "ui.config_options.module.chaos_golem_equals_stone_golem.label", ifCond = "ChaosEqualStoneGolem", ifSkill = "Summon Stone Golem", includeTransfigured = true, apply = function(val, modList, enemyModList)
		modList:NewMod("Condition:ChaosEqualStoneGolem", "FLAG", true, "Config")
	end },
	{ var = "stoneGolemEqualsCarrionGolem", type = "check", label = "# Stone Golem = # Carrion Golem:", labelKey = "ui.config_options.module.stone_golem_equals_carrion_golem.label", ifCond = "StoneEqualCarrionGolem", ifSkill = "Summon Carrion Golem", includeTransfigured = true, apply = function(val, modList, enemyModList)
		modList:NewMod("Condition:StoneEqualCarrionGolem", "FLAG", true, "Config")
	end },
	{ label = "Clash Support:", labelKey = "ui.config_options.module.config_settings.label_12", ifSkill = "Clash" },
	{ var = "clashCondition", type = "check", label = "Enemy ^xE05030Life ^7% higher than Player?", labelKey = "ui.config_options.module.clash_condition.label", ifSkill = "Clash", tooltip = "Does the Enemy have a higher percentage of ^xE05030Life ^7remaining than the player", tooltipKey = "ui.config_options.module.clash_condition.tooltip", apply = function(val, modList, enemyModList)
		modList:NewMod("Condition:EnemyHigherLifePercent", "FLAG", true, "Config")
	end },
	{ label = "Cold Snap:", labelKey = "ui.config_options.module.config_settings.label_13", ifSkill = "Cold Snap", includeTransfigured = true },
	{ var = "ColdSnapBypassCD", type = "check", label = "Bypass CD?", labelKey = "ui.config_options.module.cold_snap_bypass_cd.label", ifSkill = "Cold Snap", includeTransfigured = true, apply = function(val, modList, enemyModList)
		modList:NewMod("CooldownRecovery", "OVERRIDE", 0, "Config", { type = "SkillName", skillName = "Cold Snap", includeTransfigured = true })
	end },
	{ label = "Consecrated Path of Endurance:", labelKey = "ui.config_options.module.config_settings.label_14", ifSkill = "Consecrated Path of Endurance" },
	{ var = "ConcPathBypassCD", type = "check", label = "Bypass CD?", labelKey = "ui.config_options.module.cold_snap_bypass_cd.label", ifSkill = "Consecrated Path of Endurance", defaultState = true, apply = function(val, modList, enemyModList)
		modList:NewMod("CooldownRecovery", "OVERRIDE", 0, "Config", { type = "SkillName", skillName = "Consecrated Path of Endurance" })
	end },
	{ label = "Drain Ailments:", labelKey = "ui.config_options.module.config_settings.label_21", ifSkill = "Drain Ailments" },
	{ var = "conditionAilmentConsumed", type = "check", label = "Consumed an Ailment?", labelKey = "ui.config_options.module.condition_ailment_consumed.label", ifSkill = "Drain Ailments", apply = function(val, modList, enemyModList)
		modList:NewMod("Condition:AilmentConsumed", "FLAG", true, "Config", { type = "Condition", var = "Effective" })
	end },
	{ label = "Elemental Discharge:", labelKey = "ui.config_options.module.config_settings.label_23", ifSkill = "Elemental Discharge" },
	{ var = "conditionIgniteConsumed", type = "check", label = "Consumed Ignite", labelKey = "ui.config_options.module.condition_ignite_consumed.label", ifSkill = "Elemental Discharge", apply = function(val, modList, enemyModList)
		modList:NewMod("Condition:IgniteConsumed", "FLAG", true, "Config", { type = "Condition", var = "Effective" })
	end },
	{ var = "conditionFreezeConsumed", type = "check", label = "Consumed Freeze", labelKey = "ui.config_options.module.condition_freeze_consumed.label", ifSkill = "Elemental Discharge", apply = function(val, modList, enemyModList)
		modList:NewMod("Condition:FreezeConsumed", "FLAG", true, "Config", { type = "Condition", var = "Effective" })
	end },
	{ var = "conditionShockConsumed", type = "check", label = "Consumed Shock", labelKey = "ui.config_options.module.condition_shock_consumed.label", ifSkill = "Elemental Discharge", apply = function(val, modList, enemyModList)
		modList:NewMod("Condition:ShockConsumed", "FLAG", true, "Config", { type = "Condition", var = "Effective" })
	end },
	{ label = "Corrupting Cry:", labelKey = "ui.config_options.module.config_settings.label_15", ifGemFamily = "Corrupting Cry" },
	{ var = "conditionCorruptingCryStages", type = "count", label = "# of Corrupted Blood stacks:", labelKey = "ui.config_options.module.condition_corrupting_cry_stages.label", ifGemFamily = "Corrupting Cry", defaultPlaceholderState = 10, apply = function(val, modList, enemyModList)
		-- It's set to 9 here with val -1 to so that it defaults to 1 stage and has max 10 stages.
		-- set limit in skill multiplier for max stages
		modList:NewMod("Multiplier:CorruptingCryStageAfterFirst", "BASE", val-1, "Config", { type = "Condition", var = "Effective" })
	end },
	{ label = "Cruelty:", labelKey = "ui.config_options.module.config_settings.label_16", ifSkill = "Cruelty" },
	{ var = "overrideCruelty", type = "count", label = "Damage % (if not maximum):", labelKey = "ui.config_options.module.override_cruelty.label", ifSkill = "Cruelty", tooltip = "Cruelty is a buff provided by Cruelty Support which grants\nup to 40% more damage over time to the skills it supports.", tooltipKey = "ui.config_options.module.override_cruelty.tooltip", apply = function(val, modList, enemyModList)
		modList:NewMod("Cruelty", "OVERRIDE", m_min(val, 40), "Config", { type = "Condition", var = "Combat" })
	end },
	{ label = "Cyclone:", labelKey = "ui.config_options.module.config_settings.label_17", ifSkill = "Cyclone", includeTransfigured = true },
	{ var = "channellingCycloneCheck", type = "check", label = "Are you Channelling Cyclone?", labelKey = "ui.config_options.module.channelling_cyclone_check.label", ifSkill = "Cyclone", includeTransfigured = true, apply = function(val, modList, enemyModList)
		modList:NewMod("Condition:ChannellingCyclone", "FLAG", true, "Config")
	end },
	{ label = "Dark Pact:", labelKey = "ui.config_options.module.config_settings.label_18", ifSkill = "Dark Pact" },
	{ var = "darkPactSkeletonLife", type = "count", label = "Skeleton ^xE05030Life:", labelKey = "ui.config_options.module.dark_pact_skeleton_life.label", ifSkill = "Dark Pact", tooltip = "Sets the maximum ^xE05030Life ^7of the Skeleton that is being targeted.", tooltipKey = "ui.config_options.module.dark_pact_skeleton_life.tooltip", apply = function(val, modList, enemyModList)
		modList:NewMod("SkillData", "LIST", { key = "skeletonLife", value = val }, "Config", { type = "SkillName", skillName = "Dark Pact" })
	end },
	{ label = "Demon Form:", labelKey = "ui.config_options.module.config_settings.label_19", ifSkill = "Demon Form" },
	{ var = "inDemonForm", type = "check", label = "Are you in Demon Form?", labelKey = "ui.config_options.module.in_demon_form.label", ifSkill = "Demon Form", defaultState = true, tooltip = "Players need a minimum of 2 ^xE05030Life ^7to enter Demon Form, so you cannot use it with Chaos Inoculation", tooltipKey = "ui.config_options.module.in_demon_form.tooltip", apply = function(val, modList, enemyModList)
		modList:NewMod("Condition:DemonForm", "FLAG", true, "Config", { type = "StatThreshold", stat = "Life", threshold = 2 })
	end },
	{ var = "demonFormStacks", type = "count", label = "Demonflame Stacks", labelKey = "ui.config_options.module.demon_form_stacks.label", ifSkill = "Demon Form", defaultPlaceholderState = 10, apply = function(val, modList, enemyModList)
		modList:NewMod("Multiplier:DemonFlameStacks", "BASE", val, "Config", { type = "Condition", var = "DemonForm" } )
	end },
	{ label = "Doom Blast:", labelKey = "ui.config_options.module.config_settings.label_20", ifSkill = "Doom Blast" },
	{ var = "doomBlastSource", type = "list", label = "Doom Blast Trigger Source:", labelKey = "ui.config_options.module.doom_blast_source.label_3", ifSkill = "Doom Blast", list = {{val="expiration",label="Curse Expiration", labelKey = "ui.config_options.module.doom_blast_source.label"},{val="replacement",label="Curse Replacement", labelKey = "ui.config_options.module.doom_blast_source.label_2"},{val="vixen",label="Vixen's Curse", labelKey = "ui.config_options.module.doom_blast_source.label_5"},{val="hexblast",label="Hexblast Replacement", labelKey = "ui.config_options.module.doom_blast_source.label_4"}}, defaultIndex = 3},
	{ var = "curseOverlaps", type = "count", label = "Curse overlaps:", labelKey = "ui.config_options.module.curse_overlaps.label", ifSkill = "Doom Blast", ifFlag = "UsesCurseOverlaps", apply = function(val, modList, enemyModList)
		modList:NewMod("Multiplier:CurseOverlaps", "BASE", val, "Config", { type = "Condition", var = "Effective" })
	end },
	{ label = "Embrace Madness:", labelKey = "ui.config_options.module.config_settings.label_24", ifSkill = "Embrace Madness" },
	{ var = "embraceMadnessActive", type = "check", label = "Is Embrace Madness active?", labelKey = "ui.config_options.module.embrace_madness_active.label", ifSkill = "Embrace Madness", apply = function(val, modList, enemyModList)
		modList:NewMod("Condition:AffectedByGloriousMadness", "FLAG", true, "Config")
	end },
	{ label = "Eye of Winter:", labelKey = "ui.config_options.module.config_settings.label_25", ifSkill = "Eye of Winter" },
	{ var = "eyeOfWinterCold", type = "check", label = "Eye of Winter gained ^x3F6DB3Cold^7 Damage:", labelKey = "ui.config_options.module.eye_of_winter_cold.label", ifSkill = "Eye of Winter", tooltip = "Eye of Winter has passed over ^x3F6DB3Cold^7 Ground Effect or Orb.", tooltipKey = "ui.config_options.module.eye_of_winter_cold.tooltip", apply = function(val, modList, enemyModList)
		modList:NewMod("Condition:EyeOfWinterCold", "FLAG", true, "Config")
	end },
	{ var = "eyeOfWinterFire", type = "check", label = "Eye of Winter gained ^xB97123Fire^7 Damage:", labelKey = "ui.config_options.module.eye_of_winter_fire.label", ifSkill = "Eye of Winter", tooltip = "Eye of Winter has passed over ^xB97123Fire^7 Ground Effect or Orb.", tooltipKey = "ui.config_options.module.eye_of_winter_fire.tooltip", apply = function(val, modList, enemyModList)
		modList:NewMod("Condition:EyeOfWinterFire", "FLAG", true, "Config")
	end },
	{ var = "eyeOfWinterLightning", type = "check", label = "Eye of Winter gained ^xADAA47Lightning^7 Damage:", labelKey = "ui.config_options.module.eye_of_winter_lightning.label", ifSkill = "Eye of Winter", tooltip = "Eye of Winter has passed over ^xADAA47Lightning^7 Ground Effect or Orb.", tooltipKey = "ui.config_options.module.eye_of_winter_lightning.tooltip", apply = function(val, modList, enemyModList)
		modList:NewMod("Condition:EyeOfWinterLightning", "FLAG", true, "Config")
	end },
	{ var = "touchedDebuffsCount", type = "countAllowZero", label = "Glorious Madness Stacks", labelKey = "ui.config_options.module.touched_debuffs_count.label", ifOption = "embraceMadnessActive", defaultState = 10, tooltip = "Glorious Madness Stacks grants:\n\tEroding Touch: 6% inc Damage Taken per stack\n\tParalysing Touch: 6% reduced Action Speed per stack\n\tDiluting Touch: 9% reduced Flask charges gained and 9% reduced Flask Effect per stack\n\tWasting Touch: 9% reduced ^xE05030Life ^7and ^x88FFFFEnergy Shield ^7recovery rate per stack", tooltipKey = "ui.config_options.module.touched_debuffs_count.tooltip", apply = function(val, modList, enemyModList)
		val = m_min(val, 10)
		modList:NewMod("DamageTaken", "INC", val * 6, val.." Eroding Touch Stacks", { type = "GlobalEffect", effectType = "Debuff" }, { type = "Condition", var = "AffectedByGloriousMadness" })
		modList:NewMod("ActionSpeed", "INC", -val * 6, val.." Paralysing Touch Stacks", { type = "GlobalEffect", effectType = "Debuff" }, { type = "Condition", var = "AffectedByGloriousMadness" })
		modList:NewMod("FlaskChargesGained", "INC", -val * 9, val.." Diluting Touch Stacks", { type = "GlobalEffect", effectType = "Debuff" }, { type = "Condition", var = "AffectedByGloriousMadness" })
		modList:NewMod("FlaskEffect", "INC", -val * 9, val.." Diluting Touch Stacks", { type = "GlobalEffect", effectType = "Debuff" }, { type = "Condition", var = "AffectedByGloriousMadness" })
		modList:NewMod("LifeRecoveryRate", "INC", -val * 9, val.." Wasting Touch Stacks", { type = "GlobalEffect", effectType = "Debuff" }, { type = "Condition", var = "AffectedByGloriousMadness" })
		modList:NewMod("EnergyShieldRecoveryRate", "INC", -val * 9, val.." Wasting Touch Stacks", { type = "GlobalEffect", effectType = "Debuff" }, { type = "Condition", var = "AffectedByGloriousMadness" })
	end },
	{ label = "Flame Wall:", labelKey = "ui.config_options.module.config_settings.label_26", ifSkill = "Flame Wall" },
	{ var = "flameWallAddedDamage", type = "check", label = "Projectile Travelled through?", labelKey = "ui.config_options.module.flame_wall_added_damage.label", ifSkill = "Flame Wall", apply = function(val, modList, enemyModList)
		modList:NewMod("Condition:FlameWallAddedDamage", "FLAG", true, "Config")
	end },
	{ var = "flameWallInfused", type = "check", label = "Lightning Infused?", labelKey = "ui.config_options.module.arc_lightning_infused.label", ifOption = "flameWallAddedDamage", apply = function(val, modList, enemyModList)
		modList:NewMod("Condition:FlameWallInfused", "FLAG", true, "Config", { type = "Condition", var = "FlameWallAddedDamage" })
	end },
	{ label = "Flicker Strike:", labelKey = "ui.config_options.module.config_settings.label_27", ifSkill = "Flicker Strike", includeTransfigured = true },
	{ var = "FlickerStrikeBypassCD", type = "check", label = "Bypass CD?", labelKey = "ui.config_options.module.cold_snap_bypass_cd.label", ifSkill = "Flicker Strike", includeTransfigured = true, defaultState = true, apply = function(val, modList, enemyModList)
		modList:NewMod("CooldownRecovery", "OVERRIDE", 0, "Config", { type = "SkillName", skillName = "Flicker Strike", includeTransfigured = true })
	end },
	{ var = "elementalConfluxElement", type = "list", label = "Elemental Conflux Element:", labelKey = "ui.config_options.module.elemental_conflux_element.label_2", ifSkill = "Elemental Conflux", list = { { val = 1, label = "Average", labelKey = "ui.config_options.module.ailment_mode.label_2" }, { val = 2, label = "Lightning", labelKey = "ui.config_options.module.elemental_conflux_element.label_4" }, { val = 3, label = "Cold", labelKey = "ui.config_options.module.elemental_conflux_element.label" }, { val = 4, label = "Fire", labelKey = "ui.config_options.module.elemental_conflux_element.label_3" } }, defaultIndex = 1, apply = function(val, modList, enemyModList)
			local coldMultiplier = 0
			local fireMultiplier = 0
			local lightningMultiplier = 0
			if val == 1 then
				coldMultiplier = 3
				fireMultiplier = 3
				lightningMultiplier = 3
			elseif val == 2 then
				lightningMultiplier = 1
			elseif val == 3 then
				coldMultiplier = 1
			elseif val == 4 then
				fireMultiplier = 1
			end
			modList:NewMod("Multiplier:ElementalConfluxLightningEffect", "BASE", lightningMultiplier, "Config",	{ type = "GlobalEffect" })
			modList:NewMod("Multiplier:ElementalConfluxColdEffect", "BASE", coldMultiplier, "Config", { type = "GlobalEffect" })
			modList:NewMod("Multiplier:ElementalConfluxFireEffect", "BASE", fireMultiplier, "Config", { type = "GlobalEffect" })
		end
	},
	{ label = "Fresh Meat:", labelKey = "ui.config_options.module.config_settings.label_28", ifSkill = "Fresh Meat" },
	{ var = "freshMeatBuffs", type = "check", label = "Is Fresh Meat active?", labelKey = "ui.config_options.module.fresh_meat_buffs.label", ifSkill = "Fresh Meat", apply = function(val, modList, enemyModList)
		modList:NewMod("Condition:FreshMeatActive", "FLAG", true, "Config")
	end },
	{ label = "Frost Shield:", labelKey = "ui.config_options.module.config_settings.label_29", ifSkill = "Frost Shield" },
	{ var = "frostShieldStages", type = "count", label = "Stages:", labelKey = "ui.config_options.module.frost_shield_stages.label", ifSkill = "Frost Shield", apply = function(val, modList, enemyModList)
		modList:NewMod("Multiplier:FrostShieldStage", "BASE", val, "Config")
	end },
	{ label = "Greater Harbinger of Time:", labelKey = "ui.config_options.module.config_settings.label_30", ifSkill =  "Summon Greater Harbinger of Time" },
	{ var = "greaterHarbingerOfTimeSlipstream", type = "check", label = "Is Slipstream active?:", labelKey = "ui.config_options.module.greater_harbinger_of_time_slipstream.label", ifSkill =  "Summon Greater Harbinger of Time", tooltip = "Greater Harbinger of Time Slipstream buff grants:\n10% increased Action Speed\nBuff affects the player and allies\nBuff has a base duration of 8s with a 10s Cooldown", tooltipKey = "ui.config_options.module.greater_harbinger_of_time_slipstream.tooltip", apply = function(val, modList, enemyModList)
		modList:NewMod("Condition:GreaterHarbingerOfTime", "FLAG", true, "Config")
	end },
	{ label = "Harbinger of Time:", labelKey = "ui.config_options.module.config_settings.label_31", ifSkill =  "Summon Harbinger of Time" },
	{ var = "harbingerOfTimeSlipstream", type = "check", label = "Is Slipstream active?:", labelKey = "ui.config_options.module.greater_harbinger_of_time_slipstream.label", ifSkill =  "Summon Harbinger of Time", tooltip = "Harbinger of Time Slipstream buff grants:\n10% increased Action Speed\nBuff affects the player, allies and enemies in a small radius\nBuff has a base duration of 8s with a 20s Cooldown", tooltipKey = "ui.config_options.module.harbinger_of_time_slipstream.tooltip", apply = function(val, modList, enemyModList)
		modList:NewMod("Condition:HarbingerOfTime", "FLAG", true, "Config")
	end },
	{ label = "Hex:", labelKey = "ui.config_options.module.config_settings.label_34", ifSkillFlag = "hex", ifMult = "MaxDoom" },
	{ var = "multiplierHexDoom", type = "count", label = "Doom on Hex:", labelKey = "ui.config_options.module.multiplier_hex_doom.label", ifSkillFlag = "hex", ifMult = "MaxDoom", apply = function(val, modList, enemyModList)
		modList:NewMod("Multiplier:HexDoomStack", "BASE", val, "Config")
	end },
	{ label = "Herald of Agony:", labelKey = "ui.config_options.module.config_settings.label_32", ifSkill = "Herald of Agony" },
	{ var = "heraldOfAgonyVirulenceStack", type = "count", label = "# of Virulence Stacks:", labelKey = "ui.config_options.module.herald_of_agony_virulence_stack.label", ifSkill = "Herald of Agony", apply = function(val, modList, enemyModList)
		modList:NewMod("Multiplier:VirulenceStack", "BASE", val, "Config")
	end },
	{ label = "Herald of Ash:", labelKey = "ui.config_options.module.config_settings.label_33", ifSkill = "Herald of Ash" },
	{ var = "hoaOverkill", type = "count", label = "Overkill damage:", labelKey = "ui.config_options.module.hoa_overkill.label", tooltip = "Herald of Ash's base ^xB97123Burning ^7damage is equal to 25% of Overkill damage.", tooltipKey = "ui.config_options.module.hoa_overkill.tooltip", ifSkill = "Herald of Ash", apply = function(val, modList, enemyModList)
		modList:NewMod("SkillData", "LIST", { key = "hoaOverkill", value = val }, "Config", { type = "SkillName", skillName = "Herald of Ash" })
	end },
	{ label = "Ice Nova:", labelKey = "ui.config_options.module.config_settings.label_35", ifSkill = "Ice Nova of Frostbolts" },
	{ var = "iceNovaCastOnFrostbolt", type = "check", label = "Cast on Frostbolt?", labelKey = "ui.config_options.module.ice_nova_cast_on_frostbolt.label", ifSkill = "Ice Nova of Frostbolts", apply = function(val, modList, enemyModList)
		modList:NewMod("Condition:CastOnFrostbolt", "FLAG", true, "Config", { type = "SkillName", skillName = "Ice Nova of Frostbolts" })
	end },
	{ label = "Incision Support:", labelKey = "ui.config_options.module.config_settings.label_36", ifSkill = "Incision" },
	{ var = "incisionConsumedRecently", type = "count", label = "# of Incisions consumed recently:", labelKey = "ui.config_options.module.incision_consumed_recently.label", ifSkill = "Incision", apply = function(val, modList, enemyModList)
		modList:NewMod("Multiplier:IncisionConsumedRecently", "BASE", val, "Config")
	end },
	{ label = "Inexorable Critical Support:", labelKey = "ui.config_options.module.config_settings.label_37", ifSkill = { "Inexorable Critical I", "Inexorable Critical II" } },
	{ var = "SecondsSinceInevitableCrit", type = "count", label = "# of seconds since Inevitable Crit:", labelKey = "ui.config_options.module.seconds_since_inevitable_crit.label", ifSkill = { "Inexorable Critical I", "Inexorable Critical II" }, defaultState = 10, tooltip = "Also implies you've crit recently if the value is 3s or below", tooltipKey = "ui.config_options.module.seconds_since_inevitable_crit.tooltip", apply = function(val, modList, enemyModList)
		modList:NewMod("Multiplier:SecondsSinceInevitableCrit", "BASE", val, "Config", { type = "Condition", var = "Combat" })
		if val < 4 then
			modList:NewMod("Condition:CritRecently", "FLAG", true, "Config", { type = "Condition", var = "Combat" })
			modList:NewMod("Condition:SkillCritRecently", "FLAG", true, "Config", { type = "Condition", var = "Combat" })
		end
	end },
	{ label = "Infusion:", labelKey = "ui.config_options.module.config_settings.label_38", ifSkill = "Infused Channelling" },
	{ var = "infusedChannellingInfusion", type = "check", label = "Is Infusion active?", labelKey = "ui.config_options.module.infused_channelling_infusion.label", ifSkill = "Infused Channelling", apply = function(val, modList, enemyModList)
		modList:NewMod("Condition:InfusionActive", "FLAG", true, "Config")
	end },
	{ label = "Intensify:", labelKey = "ui.config_options.module.config_settings.label_39", ifSkill = { "Intensify", "Crackling Lance", "Pinpoint" } },
	{ var = "intensifyIntensity", type = "count", label = "# of Intensity:", labelKey = "ui.config_options.module.intensify_intensity.label", ifSkill = { "Intensify", "Crackling Lance", "Pinpoint" }, apply = function(val, modList, enemyModList)
		modList:NewMod("Multiplier:Intensity", "BASE", val, "Config")
	end },
	{ label = "Into the Breach:", labelKey = "ui.config_options.module.config_settings.label_40", ifSkill = "Into the Breach" },
	{ var = "purpleFlameStacks", type = "count", label = "Purple Flames collected:", labelKey = "ui.config_options.module.purple_flame_stacks.label", tooltip = "Number of Purple Flames of Chayula collected (max 10).", tooltipKey = "ui.config_options.module.purple_flame_stacks.tooltip", ifSkill = "Into the Breach", defaultState = 10, apply = function(val, modList, enemyModList)
		modList:NewMod("Multiplier:PurpleFlamesCount", "BASE", m_min(val, 10), "Config")
	end },
	{ label = "Leylines:", labelKey = "ui.config_options.module.config_settings.label_41", ifSkill = "Leylines" },
	{ var = "onLeyline", type = "check", label = "Are you on a Leyline?", labelKey = "ui.config_options.module.on_leyline.label", ifSkill = "Leylines", apply = function(val, modList, enemyModList)
		modList:NewMod("Condition:OnLeyline", "FLAG", true, "Config")
	end },
	{ label = "Link Skills:", labelKey = "ui.config_options.module.config_settings.label_42", ifSkill = { "Destructive Link", "Flame Link", "Intuitive Link", "Protective Link", "Soul Link", "Vampiric Link" } },
	{ var = "multiplierLinkedTargets", type = "count", label = "# of linked Targets:", labelKey = "ui.config_options.module.multiplier_linked_targets.label", ifSkill = { "Destructive Link", "Flame Link", "Intuitive Link", "Protective Link", "Soul Link", "Vampiric Link" }, apply = function(val, modList, enemyModList)
		modList:NewMod("Multiplier:LinkedTargets", "BASE", val, "Config")
	end },
	{ var = "linkedToMinion", type = "check", label = "Linked To Minion?", labelKey = "ui.config_options.module.linked_to_minion.label", ifSkill = { "Destructive Link", "Flame Link", "Intuitive Link", "Protective Link", "Soul Link", "Vampiric Link" }, ifFlag = "Condition:CanLinkToMinions", apply = function(val, modList, enemyModList)
		modList:NewMod("Condition:LinkedToMinion", "FLAG", true, "Config")
	end },
	{ var = "linkedSourceRate", type = "float", label = "Source rate for Intuitive Link", labelKey = "ui.config_options.module.linked_source_rate.label", ifSkill = "Intuitive Link", apply = function(val, modList, enemyModList)
		modList:NewMod("IntuitiveLinkSourceRate", "BASE", val, "Config")
	end },
	{ label = "Manabond:", labelKey = "ui.config_options.module.config_settings.label_43", ifSkill = "Manabond" },
	{ var = "manabondMissingUnreservedManaPercentage", type = "count", label = "Missing Unreserved ^x7070FFMana^7 %:", labelKey = "ui.config_options.module.manabond_missing_unreserved_mana_percentage.label", tooltip = "Ignores values outside the 0-100 range, defaults to 100% if not specified. \nA more realistic value would be to match your Arcane Cloak spend %.", tooltipKey = "ui.config_options.module.manabond_missing_unreserved_mana_percentage.tooltip", ifSkill = "Manabond", apply = function(val, modList, enemyModList)
		modList:NewMod("SkillData", "LIST", { key = "ManabondMissingUnreservedManaPercentage", value = m_max(m_min(val,100), 0) }, "Config", { type = "SkillName", skillName = "Manabond" })
	end },
	{ label = "Meat Shield:", labelKey = "ui.config_options.module.config_settings.label_44", ifSkill = "Meat Shield" },
	{ var = "meatShieldEnemyNearYou", type = "check", label = "Is the enemy near you?", labelKey = "ui.config_options.module.meat_shield_enemy_near_you.label", ifSkill = "Meat Shield", apply = function(val, modList, enemyModList)
		modList:NewMod("Condition:MeatShieldEnemyNearYou", "FLAG", true, "Config")
	end },
	{ label = "Momentum:", labelKey = "ui.config_options.module.config_settings.label_46", ifSkill = "Momentum" },
	{ var = "momentumDamage", type = "check", label = "Moved 2m during Skill use?", labelKey = "ui.config_options.module.momentum_damage.label", ifSkill = "Momentum", ifFlag = "CanPerformSkillWhileMoving", apply = function(val, modList, enemyModList)
		modList:NewMod("Condition:Moved2m", "FLAG", true, "Config")
	end },
	{ label = "Stoicism:", labelKey = "ui.config_options.module.config_settings.label_68", ifSkill = { "Stoicism I", "Stoicism II" } },
	{ var = "stoicismSeconds", type = "count", label = "Seconds building Stoicism:", labelKey = "ui.config_options.module.stoicism_seconds.label", ifSkill = { "Stoicism I", "Stoicism II" }, tooltip = "Seconds since last reset. Stoicism I: 1%/s (full 20s). Stoicism II: 2%/s (full 10s).", tooltipKey = "ui.config_options.module.stoicism_seconds.tooltip", apply = function(val, modList, enemyModList)
		modList:NewMod("Condition:UsingStoicism", "FLAG", true, "Config")
		modList:NewMod("Multiplier:StoicismSeconds", "BASE", m_min(m_max(val, 0), 20), "Config")
		modList:NewMod("Multiplier:StoicismCap", "BASE", 20, "Config")
	end },
	{ label = "Parry:", labelKey = "ui.config_options.module.config_settings.label_48", ifFlag = "CanParry" },
	{ var = "parryActive", type = "check", label = "Enemy has Parry Debuff", labelKey = "ui.config_options.module.parry_active.label", ifFlag = "CanParry", tooltip = "The Parry debuff grants:\n\tEnemies take 50% more Attack Damage", tooltipKey = "ui.config_options.module.parry_active.tooltip", apply = function(val, modList, enemyModList)
		modList:NewMod("Condition:ParryActive", "FLAG", true, "Config")
	end },
	{ label = "Plague Bearer:", labelKey = "ui.config_options.module.config_settings.label_51", ifSkill = "Plague Bearer"},
	{ var = "plagueBearerState", type = "list", label = "State:", labelKey = "ui.config_options.module.plague_bearer_state.label_3", ifSkill = "Plague Bearer", list = {{val="INC",label="Incubating", labelKey = "ui.config_options.module.plague_bearer_state.label"},{val="INF",label="Infecting", labelKey = "ui.config_options.module.plague_bearer_state.label_2"}}, apply = function(val, modList, enemyModList)
		if val == "INC" then
			modList:NewMod("Condition:PlagueBearerIncubating", "FLAG", true, "Config")
		elseif val == "INF" then
			modList:NewMod("Condition:PlagueBearerInfecting", "FLAG", true, "Config")
		end
	end },
	{ label = "Perforate:", labelKey = "ui.config_options.module.config_settings.label_49", ifSkill = "Perforate", includeTransfigured = true },
	{ var = "perforateSpikeOverlap", type = "count", label = "# of Overlapping Spikes:", labelKey = "ui.config_options.module.perforate_spike_overlap.label", tooltip = "Affects the DPS of Perforate in Blood Stance.\nMaximum is limited by the number of Spikes of Perforate.", tooltipKey = "ui.config_options.module.perforate_spike_overlap.tooltip", ifSkill = "Perforate", includeTransfigured = true, apply = function(val, modList, enemyModList)
		modList:NewMod("Multiplier:PerforateSpikeOverlap", "BASE", val, "Config", { type = "SkillName", skillName = "Perforate", includeTransfigured = true })
	end },
	{ label = "Physical Aegis:", labelKey = "ui.config_options.module.config_settings.label_50", ifSkill = "Physical Aegis" },
	{ var = "physicalAegisDepleted", type = "check", label = "Is Physical Aegis depleted?", labelKey = "ui.config_options.module.physical_aegis_depleted.label", ifSkill = "Physical Aegis", apply = function(val, modList, enemyModList)
		modList:NewMod("Condition:PhysicalAegisDepleted", "FLAG", true, "Config")
	end },
	{ label = "Predator:", labelKey = "ui.config_options.module.config_settings.label_52", ifSkill = "Predator" },
	{ var = "deathmarkDeathmarkActive", type = "check", label = "Is the enemy marked with Signal Prey?", labelKey = "ui.config_options.module.deathmark_deathmark_active.label", ifSkill = "Predator", apply = function(val, modList, enemyModList)
		modList:NewMod("Condition:EnemyHasDeathmark", "FLAG", true, "Config")
	end },
	{ label = "Pride:", labelKey = "ui.config_options.module.config_settings.label_53", ifSkill = "Pride" },
	{ var = "prideEffect", type = "list", label = "Pride Aura Effect:", labelKey = "ui.config_options.module.pride_effect.label_3", ifSkill = { "Pride", "AzmeriDemonPhysicalDamageAura" }, list = {{val="MIN",label="Initial effect", labelKey = "ui.config_options.module.pride_effect.label"},{val="MAX",label="Maximum effect", labelKey = "ui.config_options.module.pride_effect.label_2"}}, apply = function(val, modList, enemyModList)
		if val == "MAX" then
			modList:NewMod("Condition:PrideMaxEffect", "FLAG", true, "Config")
		end
	end },
	{ label = "Rage Vortex:", labelKey = "ui.config_options.module.config_settings.label_54", ifSkill = "Rage Vortex" },
	{ var = "sacrificedRageCount", type = "count", label = "Amount of ^xFF9922Rage ^7Sacrificed (if not maximum):", labelKey = "ui.config_options.module.sacrificed_rage_count.label", ifSkill = "Rage Vortex", apply = function(val, modList, enemyModList)
		modList:NewMod("Multiplier:RageSacrificedStacks", "BASE", val, "Config")
	end },
	{ label = "Raise Spectre:", labelKey = "ui.config_options.module.config_settings.label_55", ifSkillFlag = "spectre", includeTransfigured = true },
	{ var = "raiseSpectreEnableBuffs", type = "check", defaultState = true, label = "Enable buffs:", labelKey = "ui.config_options.module.raise_spectre_enable_buffs.label", ifSkillFlag = "spectre", includeTransfigured = true, tooltip = "Enable any buff skills that your spectres have.", tooltipKey = "ui.config_options.module.raise_spectre_enable_buffs.tooltip", apply = function(val, modList, enemyModList)
		modList:NewMod("SkillData", "LIST", { key = "enable", value = true }, "Config", { type = "SkillType", skillType = SkillType.Buff }, { type = "SkillName", skillName = "Spectre", partialMatch = true, summonSkill = true })
	end },
	{ var = "raiseSpectreEnableCurses", type = "check", defaultState = true, label = "Enable curses:", labelKey = "ui.config_options.module.raise_spectre_enable_curses.label", ifSkillFlag = "spectre", includeTransfigured = true, tooltip = "Enable any curse skills that your spectres have.", tooltipKey = "ui.config_options.module.raise_spectre_enable_curses.tooltip", apply = function(val, modList, enemyModList)
		modList:NewMod("SkillData", "LIST", { key = "enable", value = true }, "Config", { type = "SkillType", skillType = SkillType.AppliesCurse }, { type = "SkillName", skillName = "Spectre", partialMatch = true, summonSkill = true })
	end },
	{ var = "conditionSummonedSpectreInPast8Sec", type = "check", label = "Summoned Spectre in past 8 Seconds?", labelKey = "ui.config_options.module.condition_summoned_spectre_in_past8_sec.label", ifCond = "SummonedSpectreInPast8Sec", ifSkillFlag = "spectre", includeTransfigured = true, apply = function(val, modList, enemyModList)
		modList:NewMod("Condition:SummonedSpectreInPast8Sec", "FLAG", true, "Config", { type = "Condition", var = "Combat" })
	end },
	{ var = "raiseSpectreBladeVortexBladeCount", type = "count", label = "Blade Vortex blade count:", labelKey = "ui.config_options.module.raise_spectre_blade_vortex_blade_count.label", ifSkill = {"DemonModularBladeVortexSpectre","GhostPirateBladeVortexSpectre"}, tooltip = "Sets the blade count for Blade Vortex skills used by spectres.\nDefault is 1; maximum is 5.", tooltipKey = "ui.config_options.module.raise_spectre_blade_vortex_blade_count.tooltip", apply = function(val, modList, enemyModList)
		modList:NewMod("SkillData", "LIST", { key = "dpsMultiplier", value = val }, "Config", { type = "SkillId", skillId = "DemonModularBladeVortexSpectre" })
		modList:NewMod("SkillData", "LIST", { key = "dpsMultiplier", value = val }, "Config", { type = "SkillId", skillId = "GhostPirateBladeVortexSpectre" })
	end },
	{ var = "raiseSpectreKaomFireBeamTotemStage", type = "count", label = "Scorching Ray Totem stage count:", labelKey = "ui.config_options.module.raise_spectre_kaom_fire_beam_totem_stage.label", ifSkill = "KaomFireBeamTotemSpectre", apply = function(val, modList, enemyModList)
		modList:NewMod("Multiplier:KaomFireBeamTotemStage", "BASE", val, "Config")
	end },
	{ var = "raiseSpectreEnableSummonedUrsaRallyingCry", type = "check", label = "Enable Summoned Ursa's Rallying Cry:", labelKey = "ui.config_options.module.raise_spectre_enable_summoned_ursa_rallying_cry.label", ifSkill = "DropBearSummonedRallyingCry", apply = function(val, modList, enemyModList)
		modList:NewMod("SkillData", "LIST", { key = "enable", value = true }, "Config", { type = "SkillId", skillId = "DropBearSummonedRallyingCry" })
	end },
	{ var = "raiseSpectreEnableSlashingHorrorEnrage", type = "check", label = "Disable Slashing Horror's Enrage:", labelKey = "ui.config_options.module.raise_spectre_enable_slashing_horror_enrage.label", ifSkill = "AzmeriDualStrikeDemonFireEnrage", apply = function(val, modList, enemyModList)
		modList:NewMod("SkillData", "LIST", { key = "enable", value = false }, "Config", { type = "SkillId", skillId = "AzmeriDualStrikeDemonFireEnrage" })
	end },
	{ var = "raiseSpectreEnableSanguimancerDemonLowLife", type = "check", label = "Sanguimancer Demon not on Low Life:", labelKey = "ui.config_options.module.raise_spectre_enable_sanguimancer_demon_low_life.label", ifSkill = "ABTTAzmeriShepherdSpellDamage", apply = function(val, modList, enemyModList)
		modList:NewMod("SkillData", "LIST", { key = "enable", value = false }, "Config", { type = "SkillId", skillId = "ABTTAzmeriShepherdSpellDamage" })
	end },
	{ label = "Raise Spiders:", labelKey = "ui.config_options.module.config_settings.label_56", ifSkill = "Raise Spiders" },
	{ var = "raiseSpidersSpiderCount", type = "count", label = "# of Spiders:", labelKey = "ui.config_options.module.raise_spiders_spider_count.label", ifSkill = "Raise Spiders", apply = function(val, modList, enemyModList)
		modList:NewMod("Multiplier:RaisedSpider", "BASE", m_min(val, 20), "Config")
	end },
	{ label = "Raise Zombie:", labelKey = "ui.config_options.module.config_settings.label_57", ifSkill = "Raise Zombie", includeTransfigured = true, ifCond = "SummonedZombieInPast8Sec" },
	{ var = "conditionSummonedZombieInPast8Sec", type = "check", label = "Summoned Zombie in past 8 Seconds?", labelKey = "ui.config_options.module.condition_summoned_zombie_in_past8_sec.label", ifCond = "SummonedZombieInPast8Sec", ifSkill = "Raise Zombie", includeTransfigured = true, apply = function(val, modList, enemyModList)
		modList:NewMod("Condition:SummonedZombieInPast8Sec", "FLAG", true, "Config", { type = "Condition", var = "Combat" })
	end },
	{ var = "animateWeaponLingeringBlade", type = "check", label = "Are you animating Lingering Blades?", labelKey = "ui.config_options.module.animate_weapon_lingering_blade.label", ifSkill = "Animate Weapon", tooltip = "Enables additional damage given to Lingering Blades\nThe exact weapon is unknown but should be similar to Glass Shank", tooltipKey = "ui.config_options.module.animate_weapon_lingering_blade.tooltip", apply = function(val, modList, enemyModList)
		modList:NewMod("Condition:AnimatingLingeringBlades", "FLAG", true, "Config")
	end },
	{ label = "Rising Tempest:", labelKey = "ui.config_options.module.config_settings.label_58", ifSkill = "Rising Tempest" },
	{ var = "risingTempestLightning", type = "check", label = "Lightning Skill used Recently:", labelKey = "ui.config_options.module.rising_tempest_lightning.label", ifSkill = "Rising Tempest", apply = function(val, modList, enemyModList)
		modList:NewMod("Multiplier:DifferentElementalSkillUsedRecently", "BASE", 1, "Config")
	end },
	{ var = "risingTempestCold", type = "check", label = "Cold Skill used Recently:", labelKey = "ui.config_options.module.rising_tempest_cold.label", ifSkill = "Rising Tempest", apply = function(val, modList, enemyModList)
		modList:NewMod("Multiplier:DifferentElementalSkillUsedRecently", "BASE", 1, "Config")
	end },
	{ var = "risingTempestFire", type = "check", label = "Fire Skill used Recently:", labelKey = "ui.config_options.module.rising_tempest_fire.label", ifSkill = "Rising Tempest", apply = function(val, modList, enemyModList)
		modList:NewMod("Multiplier:DifferentElementalSkillUsedRecently", "BASE", 1, "Config")
	end },
	{ label = "Scavenged Plating:", labelKey = "ui.config_options.module.config_settings.label_59", ifSkill = "Scavenged Plating" },
	{ var = "scavengedPlatingStacks", type = "count", label = "# of Scavenged Plating Stacks:", labelKey = "ui.config_options.module.scavenged_plating_stacks.label", ifSkill = "Scavenged Plating", apply = function(val, modList, enemyModList)
		modList:NewMod("Multiplier:ScavengedPlatingStacks", "BASE", val, "Config")
	end },
	{ label = "Shrapnel Ballista:", labelKey = "ui.config_options.module.config_settings.label_60", ifSkill = "Shrapnel Ballista", includeTransfigured = true },
	{ var = "ShrapnelBallistaProjectileOverlap", type = "count", label = "# of Shotgunning Projectiles:", labelKey = "ui.config_options.module.shrapnel_ballista_projectile_overlap.label", tooltip = "Maximum is limited by the number of Projectiles., default of 1, if Arrow nova then default of maximum projectiles", tooltipKey = "ui.config_options.module.shrapnel_ballista_projectile_overlap.tooltip", ifSkill = "Shrapnel Ballista", includeTransfigured = true, apply = function(val, modList, enemyModList)
		modList:NewMod("SkillData", "LIST", { key = "ShrapnelBallistaProjectileOverlap", value = val }, "Config", { type = "SkillName", skillName = "Shrapnel Ballista", includeTransfigured = true })
	end },
	{ label = "Sigil of Power:", labelKey = "ui.config_options.module.config_settings.label_61", ifSkill = "Sigil of Power" },
	{ var = "sigilOfPowerStages", type = "countAllowZero", label = "Stages:", labelKey = "ui.config_options.module.frost_shield_stages.label", ifSkill = "Sigil of Power", defaultPlaceholderState = 1, apply = function(val, modList, enemyModList)
		modList:NewMod("Multiplier:SigilOfPowerStage", "BASE", val, "Config")
	end },
	{ label = "Siphoning Trap:", labelKey = "ui.config_options.module.config_settings.label_62", ifSkill = "Siphoning Trap" },
	{ var = "siphoningTrapAffectedEnemies", type = "count", label = "# of Enemies affected:", labelKey = "ui.config_options.module.siphoning_trap_affected_enemies.label", ifSkill = "Siphoning Trap", tooltip = "Sets the number of enemies affected by Siphoning Trap.", tooltipKey = "ui.config_options.module.siphoning_trap_affected_enemies.tooltip", apply = function(val, modList, enemyModList)
		modList:NewMod("Multiplier:EnemyAffectedBySiphoningTrap", "BASE", val, "Config")
		modList:NewMod("Condition:SiphoningTrapSiphoning", "FLAG", true, "Config")
	end },
	{ label = "Spearfield:", labelKey = "ui.config_options.module.config_settings.label_63", ifSkill = "Spearfield" },
	{ var = "conditionOldSpear", type = "check", label = "Spear older than 0.5s?", labelKey = "ui.config_options.module.condition_old_spear.label", ifSkill = "Spearfield", apply = function(val, modList, enemyModList)
		modList:NewMod("Condition:SpearOlderThanHalfSecond", "FLAG", true, "Config")
	end },
	{ label = "Spectral Wolf:", labelKey = "ui.config_options.module.config_settings.label_64", ifSkill = "Summon Spectral Wolf" },
	{ var = "configSpectralWolfCount", type = "count", label = "# of Active Spectral Wolves:", labelKey = "ui.config_options.module.config_spectral_wolf_count.label", ifSkill = "Summon Spectral Wolf", tooltip = "Sets the number of active Spectral Wolves.\nThe maximum number of Spectral Wolves is 10.", tooltipKey = "ui.config_options.module.config_spectral_wolf_count.tooltip", apply = function(val, modList, enemyModList)
		modList:NewMod("Multiplier:SpectralWolfCount", "BASE", m_min(val, 10), "Config")
	end },
	{ label = "Spiraling Conspiracy:", labelKey = "ui.config_options.module.config_settings.label_65", ifSkill = "Spiraling Conspiracy" },
	{ var = "configMistRavenCount", type = "count", label = "# of Active Mist Ravens:", labelKey = "ui.config_options.module.config_mist_raven_count.label", ifSkill = "Spiraling Conspiracy", tooltip = "Sets the number of active Spiraling Conspiracy.\nThe maximum number of Spiraling Conspiracy is 30.", tooltipKey = "ui.config_options.module.config_mist_raven_count.tooltip", apply = function(val, modList, enemyModList)
		modList:NewMod("Multiplier:MistRavenCount", "BASE", m_min(val, 30), "Config")
	end },
	{ label = "Stance Skills:", labelKey = "ui.config_options.module.config_settings.label_66", ifSkill = { "Blood and Sand", "Flesh and Stone", "Lacerate", "Bladestorm", "Perforate", "Perforate of Duality" } },
	{ var = "bloodSandStance", type = "list", label = "Stance:", labelKey = "ui.config_options.module.blood_sand_stance.label_3", ifSkill = { "Blood and Sand", "Flesh and Stone", "Lacerate", "Bladestorm", "Perforate", "Perforate of Duality" }, list = {{val="BLOOD",label="Blood Stance", labelKey = "ui.config_options.module.blood_sand_stance.label"},{val="SAND",label="Sand Stance", labelKey = "ui.config_options.module.blood_sand_stance.label_2"}}, apply = function(val, modList, enemyModList)
		if val == "SAND" then
			modList:NewMod("Condition:SandStance", "FLAG", true, "Config")
		end
	end },
	{ var = "changedStance", type = "check", label = "Changed Stance recently?", labelKey = "ui.config_options.module.changed_stance.label", ifCond = "ChangedStanceRecently", apply = function(val, modList, enemyModList)
		modList:NewMod("Condition:ChangedStanceRecently", "FLAG", true, "Config")
	end },
	{ label = "Steel Skills:", labelKey = "ui.config_options.module.config_settings.label_67", ifSkill = { "Splitting Steel of Ammunition", "Shattering Steel of Ammunition", "Lancing Steel", "Shrapnel Ballista of Steel" } },
	{ var = "shardsConsumed", type = "count", label = "Steel Shards consumed:", labelKey = "ui.config_options.module.shards_consumed.label", ifSkill = { "Splitting Steel of Ammunition", "Shattering Steel of Ammunition", "Lancing Steel", "Shrapnel Ballista of Steel" }, apply = function(val, modList, enemyModList)
		modList:NewMod("Multiplier:SteelShardConsumed", "BASE", m_min(val, 12), "Config")
	end },
	{ var = "steelWards", type = "count", label = "Steel Wards:", labelKey = "ui.config_options.module.steel_wards.label", ifSkill = "Shattering Steel of Ammunition", tooltip = "Steel Wards are gained from using Shattering Steel of Ammunition with at least 2 Steel Shards.\nYou can have up to 6 Steel Wards, and each grants +8% chance to Block Projectile Attack Damage.", tooltipKey = "ui.config_options.module.steel_wards.tooltip", apply = function(val, modList, enemyModList)
		modList:NewMod("Multiplier:SteelWardCount", "BASE", val, "Config")
	end },
	{ label = "Storm Rain:", labelKey = "ui.config_options.module.config_settings.label_69", ifSkill = "Storm Rain" },
	{ var = "stormRainBeamOverlap", type = "count", label = "# of Overlapping Beams:", labelKey = "ui.config_options.module.storm_rain_beam_overlap.label", ifSkill = "Storm Rain", apply = function(val, modList, enemyModList)
		modList:NewMod("SkillData", "LIST", { key = "beamOverlapMultiplier", value = val }, "Config", { type = "SkillName", skillName = "Storm Rain" })
	end },
	{ label = "Storm Rain of the Conduit:", labelKey = "ui.config_options.module.config_settings.label_70", ifSkill = "Storm Rain of the Conduit" },
	{ var = "stormRainActiveArrows", type = "count", label = "# of Active Arrows:", labelKey = "ui.config_options.module.storm_rain_active_arrows.label", ifSkill = "Storm Rain of the Conduit", apply = function(val, modList, enemyModList)
		modList:NewMod("SkillData", "LIST", { key = "activeArrowMultiplier", value = val }, "Config", { type = "SkillName", skillName = "Storm Rain of the Conduit" })
	end },
	{ label = "Summon Companion:", labelKey = "ui.config_options.module.config_settings.label_71", ifSkillFlag = "summonBeast", includeTransfigured = true },
	{ var = "summonCompanionEnableBuffs", type = "check", defaultState = true, label = "Enable buffs:", labelKey = "ui.config_options.module.raise_spectre_enable_buffs.label", ifSkillFlag = "summonBeast", includeTransfigured = true, tooltip = "Enable any buff skills that your Companions have.", tooltipKey = "ui.config_options.module.summon_companion_enable_buffs.tooltip", apply = function(val, modList, enemyModList)
		modList:NewMod("SkillData", "LIST", { key = "enable", value = true }, "Config", { type = "SkillType", skillType = SkillType.Buff }, { type = "SkillName", skillName = "Companion", partialMatch = true, summonSkill = true })
	end },
	{ var = "summonCompanionEnableCurses", type = "check", defaultState = true, label = "Enable curses:", labelKey = "ui.config_options.module.raise_spectre_enable_curses.label", ifSkillFlag = "summonBeast", includeTransfigured = true, tooltip = "Enable any curse skills that your Companions have.", tooltipKey = "ui.config_options.module.summon_companion_enable_curses.tooltip", apply = function(val, modList, enemyModList)
		modList:NewMod("SkillData", "LIST", { key = "enable", value = true }, "Config", { type = "SkillType", skillType = SkillType.AppliesCurse }, { type = "SkillName", skillName = "Companion", partialMatch = true, summonSkill = true })
	end },
	{ label = "Summon Elemental Relic:", labelKey = "ui.config_options.module.config_settings.label_72", ifSkill = "Summon Elemental Relic" },
	{ var = "summonElementalRelicEnableAngerAura", type = "check", defaultState = true, label = "Enable Anger Aura:", labelKey = "ui.config_options.module.summon_elemental_relic_enable_anger_aura.label", ifSkill = "Summon Elemental Relic", apply = function(val, modList, enemyModList)
		modList:NewMod("SkillData", "LIST", { key = "enable", value = true }, "Config", { type = "SkillId", skillId = "Anger" }, { type = "SkillName", skillName = "Summon Elemental Relic", summonSkill = true })
	end },
	{ var = "summonElementalRelicEnableHatredAura", type = "check", defaultState = true, label = "Enable Hatred Aura:", labelKey = "ui.config_options.module.summon_elemental_relic_enable_hatred_aura.label", ifSkill = "Summon Elemental Relic", apply = function(val, modList, enemyModList)
		modList:NewMod("SkillData", "LIST", { key = "enable", value = true }, "Config", { type = "SkillId", skillId = "Hatred" }, { type = "SkillName", skillName = "Summon Elemental Relic", summonSkill = true })
	end },
	{ var = "summonElementalRelicEnableWrathAura", type = "check", defaultState = true, label = "Enable Wrath Aura:", labelKey = "ui.config_options.module.summon_elemental_relic_enable_wrath_aura.label", ifSkill = "Summon Elemental Relic", apply = function(val, modList, enemyModList)
		modList:NewMod("SkillData", "LIST", { key = "enable", value = true }, "Config", { type = "SkillId", skillId = "Wrath" }, { type = "SkillName", skillName = "Summon Elemental Relic", summonSkill = true })
	end },
	{ label = "Summon Holy Relic:", labelKey = "ui.config_options.module.config_settings.label_73", ifSkill = "Summon Holy Relic" },
	{ var = "summonHolyRelicEnableHolyRelicBoon", type = "check", label = "Enable Holy Relic's Boon Aura:", labelKey = "ui.config_options.module.summon_holy_relic_enable_holy_relic_boon.label", ifSkill = "Summon Holy Relic", apply = function(val, modList, enemyModList)
		modList:NewMod("Condition:HolyRelicBoonActive", "FLAG", true, "Config")
	end },
	{ label = "Summon Lightning Golem:", labelKey = "ui.config_options.module.config_settings.label_74", ifSkill = "Summon Lightning Golem", includeTransfigured = true },
	{ var = "summonLightningGolemEnableWrath", type = "check", label = "Enable Wrath Aura:", labelKey = "ui.config_options.module.summon_elemental_relic_enable_wrath_aura.label", ifSkill = "Summon Lightning Golem", includeTransfigured = true, apply = function(val, modList, enemyModList)
		modList:NewMod("SkillData", "LIST", { key = "enable", value = true }, "Config", { type = "SkillId", skillId = "LightningGolemWrath" })
	end },
	{ label = "Summon Reaper:", labelKey = "ui.config_options.module.config_settings.label_75", ifSkill = "Summon Reaper", includeTransfigured = true },
	{ var = "summonReaperConsumeRecently", type = "check", label = "Reaper Consumed recently?", labelKey = "ui.config_options.module.summon_reaper_consume_recently.label", ifSkill = "Summon Reaper", includeTransfigured = true, apply = function(val, modList, enemyModList)
		modList:NewMod("SkillData", "LIST", { key = "enable", value = true }, "Config", { type = "SkillId", skillId = "ReaperConsumeMinionForBuff" })
	end },
	{ label = "Thirst for Blood:", labelKey = "ui.config_options.module.config_settings.label_76", ifSkill = "Thirst for Blood" },
	{ var = "nearbyBleedingEnemies", type = "count", label = "# of Nearby Bleeding Enemies:", labelKey = "ui.config_options.module.nearby_bleeding_enemies.label", ifSkill = "Thirst for Blood", apply = function(val, modList, enemyModList)
		modList:NewMod("Multiplier:NearbyBleedingEnemies", "BASE", val, "Config" )
	end },
	{ label = "Tornado Shot:", labelKey = "ui.config_options.module.config_settings.label_77", ifSkill = "Tornado Shot" },
	{ var = "tornadoShotSecondaryHitChance", type = "count", label = "% chance for second proj to hit:", labelKey = "ui.config_options.module.tornado_shot_secondary_hit_chance.label", tooltip = "Override to the percent chance for the secondary projectiles to hit, default of 60% or 80% with helm enchant. (20% per secondary projectile)", tooltipKey = "ui.config_options.module.tornado_shot_secondary_hit_chance.tooltip", ifSkill = "Tornado Shot", apply = function(val, modList, enemyModList)
		modList:NewMod("SkillData", "LIST", { key = "tornadoShotSecondaryHitChance", value = val }, "Config", { type = "SkillName", skillName = "Tornado Shot" })
	end },
	{ label = "Toxic Rain:", labelKey = "ui.config_options.module.config_settings.label_78", ifSkill = "Toxic Rain", includeTransfigured = true },
	{ var = "toxicRainPodOverlap", type = "count", label = "# of Overlapping Pods:", labelKey = "ui.config_options.module.toxic_rain_pod_overlap.label", tooltip = "Maximum is limited by the number of Projectiles.", tooltipKey = "ui.config_options.module.toxic_rain_pod_overlap.tooltip", ifSkill = "Toxic Rain", includeTransfigured = true, apply = function(val, modList, enemyModList)
		modList:NewMod("SkillData", "LIST", { key = "podOverlapMultiplier", value = val }, "Config", { type = "SkillName", skillName = "Toxic Rain", includeTransfigured = true })
	end },
	{ label = "Trauma:", labelKey = "ui.config_options.module.config_settings.label_79", ifFlag = "HasTrauma" },
	{ var = "traumaStacks", type = "count", label = "# of Trauma Stacks:", labelKey = "ui.config_options.module.trauma_stacks.label", ifFlag = "HasTrauma", apply = function(val, modList, enemyModList)
		modList:NewMod("Multiplier:TraumaStacks", "BASE", val, "Config", { type = "Condition", var = "Combat" })
	end },
	{ label = "Trinity:", labelKey = "ui.config_options.module.config_settings.label_80", ifSkill = "Trinity" },
	{ var = "configResonanceCount", type = "count", label = "Total Resonance Count:", labelKey = "ui.config_options.module.config_resonance_count.label", ifSkill = "Trinity", tooltip = "Sets the total Resonance Count.", tooltipKey = "ui.config_options.module.config_resonance_count.tooltip", apply = function(val, modList, enemyModList)
		modList:NewMod("Multiplier:ResonanceCount", "BASE", m_max(m_min(val, 300), 0), "Config")
	end },
	{ label = "Twister:", labelKey = "ui.config_options.module.config_settings.label_81", ifSkill = "Twister" },
	{ var = "twisterCold", type = "check", label = "Twister gained ^x3F6DB3Cold^7 Element:", labelKey = "ui.config_options.module.twister_cold.label", ifSkill = "Twister", tooltip = "Twister has passed over ^x3F6DB3Cold^7 Ground or consumed a ^x3F6DB3Cold^7 Whirlwind.", tooltipKey = "ui.config_options.module.twister_cold.tooltip", apply = function(val, modList, enemyModList)
		modList:NewMod("Condition:TwisterCold", "FLAG", true, "Config")
	end },
	{ var = "twisterFire", type = "check", label = "Twister gained ^xB97123Fire^7 Element:", labelKey = "ui.config_options.module.twister_fire.label", ifSkill = "Twister", tooltip = "Twister has passed over ^xB97123Fire^7 Ground or consumed a ^xB97123Fire^7 Whirlwind.", tooltipKey = "ui.config_options.module.twister_fire.tooltip", apply = function(val, modList, enemyModList)
		modList:NewMod("Condition:TwisterFire", "FLAG", true, "Config")
	end },
	{ var = "twisterLightning", type = "check", label = "Twister gained ^xADAA47Lightning^7 Element:", labelKey = "ui.config_options.module.twister_lightning.label", ifSkill = "Twister", tooltip = "Twister has passed over ^xADAA47Lightning^7 Ground or consumed a ^xADAA47Lightning^7 Whirlwind.", tooltipKey = "ui.config_options.module.twister_lightning.tooltip", apply = function(val, modList, enemyModList)
		modList:NewMod("Condition:TwisterLightning", "FLAG", true, "Config")
	end },
	{ label = "Unhinge:", labelKey = "ui.config_options.module.config_settings.label_83", ifSkill = "Unhinge" },
	{ var = "conditionInsane", type = "check", label = "Are you Insane?", labelKey = "ui.config_options.module.condition_insane.label", ifCond = "Insane", apply = function(val, modList, enemyModList)
		modList:NewMod("Condition:Insane", "FLAG", true, "Config")
	end },
	{ var = "conditionUnravelling", type = "list", label = "Acolyte's Unravelling:", labelKey = "ui.config_options.module.condition_unravelling.label", ifFlag = "Unravelling", tooltip = "While affected by Unravelling, your ^xD02090Chaos^7 Damage randomly either also contributes to ^x3F6DB3Freeze^7 buildup,\n^xB97123Ignite^7 chance and magnitude, or ^xADAA47Shock^7 chance - changing which it contributes to every two seconds. ", tooltipKey = "ui.config_options.module.condition_unravelling.tooltip",
	list = {
		{val="Cold",label="Unravelling Frost", labelKey = "ui.config_options.module.condition_unravelling.label_4"},
		{val="Fire",label="Unravelling Flame", labelKey = "ui.config_options.module.condition_unravelling.label_3"},
		{val="Lightning",label="Unravelling Bolt", labelKey = "ui.config_options.module.condition_unravelling.label_2"},
	}, apply = function(val, modList, enemyModList)
		modList:NewMod("Condition:"..val.."Unravel", "FLAG", true, "Config")
	end },
	{ label = "Vigilant Strike:", labelKey = "ui.config_options.module.config_settings.label_86", ifSkill = "Vigilant Strike" },
	{ var = "VigilantStrikeBypassCD", type = "check", label = "Bypass CD?", labelKey = "ui.config_options.module.cold_snap_bypass_cd.label", ifSkill = "Vigilant Strike", defaultState = true, apply = function(val, modList, enemyModList)
		modList:NewMod("CooldownRecovery", "OVERRIDE", 0, "Config", { type = "SkillName", skillName = "Vigilant Strike" })
	end },
	{ label = "Voltaxic Burst:", labelKey = "ui.config_options.module.config_settings.label_87", ifSkill = "Voltaxic Burst" },
	{ var = "voltaxicBurstSpellsQueued", type = "count", label = "# of Casts currently waiting:", labelKey = "ui.config_options.module.voltaxic_burst_spells_queued.label", ifSkill = "Voltaxic Burst", apply = function(val, modList, enemyModList)
		modList:NewMod("Multiplier:WhirlwindStages", "BASE", val, "Config")
	end },
	{ label = "Vortex:", labelKey = "ui.config_options.module.config_settings.label_88", ifSkill = "Vortex of Projection" },
	{ var = "vortexCastOnFrostbolt", type = "check", label = "Cast on Frostbolt?", labelKey = "ui.config_options.module.ice_nova_cast_on_frostbolt.label", ifSkill = "Vortex of Projection", apply = function(val, modList, enemyModList)
		modList:NewMod("Condition:CastOnFrostbolt", "FLAG", true, "Config", { type = "SkillName", skillName = "Vortex of Projection" })
	end },
	{ label = "Warcry Skills:", labelKey = "ui.config_options.module.config_settings.label_89", ifFlag = "UsesWarcryPower" },
	{ var = "multiplierWarcryPower", type = "count", label = "Warcry Power:", labelKey = "ui.config_options.module.multiplier_warcry_power.label", ifFlag = "UsesWarcryPower", tooltip = "Power determines how strong your Warcry buffs will be, and is based on the total strength of nearby enemies.\nPower is assumed to be 20 if your target is a Boss, but you can override it here if necessary.\n\tEach Normal enemy grants 1 Power\n\tEach Magic enemy grants 2 Power\n\tEach Rare enemy grants 10 Power\n\tEach Unique enemy grants 20 Power", tooltipKey = "ui.config_options.module.multiplier_warcry_power.tooltip", apply = function(val, modList, enemyModList)
		modList:NewMod("WarcryPower", "OVERRIDE", val, "Config")
	end },
	{ label = "Whirlwind Stages:", labelKey = "ui.config_options.module.config_settings.label_91", ifSkill = { "Whirlwind Lance", "Whirling Slash" } },
	{ var = "whirlwindStages", type = "count", label = "# of Whirlwind Stages:", labelKey = "ui.config_options.module.whirlwind_stages.label", ifSkill = { "Whirlwind Lance", "Whirling Slash" }, apply = function(val, modList, enemyModList)
		modList:NewMod("Multiplier:WhirlwindStageAfterFirst", "BASE", m_min(val - 1, 3), "Config", { type = "Condition", var = "Combat" })
		modList:NewMod("Multiplier:WhirlwindStages", "BASE", m_min(val, 4), "Config", { type = "Condition", var = "Combat" })
	end },
	{ label = "Whirlwind Buffs:", labelKey = "ui.config_options.module.config_settings.label_90", ifSkill = { "Whirlwind Lance", "Whirling Slash" } },
	{ var = "whirlwindBuffCold", type = "check", label = "Whirlwind gained ^x3F6DB3Cold^7 Element:", labelKey = "ui.config_options.module.whirlwind_buff_cold.label", ifSkill = { "Whirlwind Lance", "Whirling Slash" }, tooltip = "Whirlwind has passed over ^x3F6DB3Cold^7 Ground.", tooltipKey = "ui.config_options.module.whirlwind_buff_cold.tooltip", apply = function(val, modList, enemyModList)
		modList:NewMod("Condition:WhirlwindBuffCold", "FLAG", true, "Config", { type = "Condition", var = "Combat" })
		enemyModList:NewMod("Condition:Chilled", "FLAG", true, "Config", { type = "Condition", var = "Effective" })
	end },
	{ var = "whirlwindBuffFire", type = "check", label = "Whirlwind gained ^xB97123Fire^7 Element:", labelKey = "ui.config_options.module.whirlwind_buff_fire.label", ifSkill = { "Whirlwind Lance", "Whirling Slash" }, tooltip = "Whirlwind has passed over ^xB97123Fire^7 Ground.", tooltipKey = "ui.config_options.module.whirlwind_buff_fire.tooltip", apply = function(val, modList, enemyModList)
		modList:NewMod("Condition:WhirlwindBuffFire", "FLAG", true, "Config", { type = "Condition", var = "Combat" })
		enemyModList:NewMod("Condition:Ignited", "FLAG", true, "Config", { type = "Condition", var = "Effective" })
	end },
	{ var = "whirlwindBuffLightning", type = "check", label = "Whirlwind gained ^xADAA47Lightning^7 Element:", labelKey = "ui.config_options.module.whirlwind_buff_lightning.label", ifSkill = { "Whirlwind Lance", "Whirling Slash" }, tooltip = "Whirlwind has passed over ^xADAA47Lightning^7 Ground.", tooltipKey = "ui.config_options.module.whirlwind_buff_lightning.tooltip", apply = function(val, modList, enemyModList)
		modList:NewMod("Condition:WhirlwindBuffLightning", "FLAG", true, "Config", { type = "Condition", var = "Combat" })
		enemyModList:NewMod("Condition:Shocked", "FLAG", true, "Config", { type = "Condition", var = "Effective" })
	end },
	{ label = "Wind Dancer:", labelKey = "ui.config_options.module.config_settings.label_92", ifSkill = "Wind Dancer" },
	{ var = "windDancerStacks", type = "countAllowZero", label = "# of Wind Dancer Stacks:", labelKey = "ui.config_options.module.wind_dancer_stacks.label", ifSkill = "Wind Dancer", apply = function(val, modList, enemyModList)
		modList:NewMod("Multiplier:WindDancerStacks", "BASE", val, "Config")
	end },
	{ var = "conditionEmpowered", type = "check", label = "Is the skill Empowered?", labelKey = "ui.config_options.module.condition_empowered.label", ifCond = "Empowered", tooltip = "Skills can be temporarily Empowered by certain buff skills.", tooltipKey = "ui.config_options.module.condition_empowered.tooltip", apply = function(val, modList, enemyModList)
		modList:NewMod("Condition:Empowered", "FLAG", true, "Config", { type = "Condition", var = "Combat" })
	end },
	{ var = "multiplierWoCExpiredDuration", type = "count", label = "% Wave of Conviction duration expired:", labelKey = "ui.config_options.module.multiplier_wo_cexpired_duration.label", ifMod = "WaveOfConvictionDurationDotMulti", apply = function(val, modList, enemyModList)
		modList:NewMod("Multiplier:WoCDurationExpired", "BASE", m_min(val, 100), "Config", { type = "Condition", var = "Effective" })
	end },
	{ var = "absolutionSkillDamageCountedOnce", type = "check", label = "Absolution: Count skill damage once", labelKey = "ui.config_options.module.absolution_skill_damage_counted_once.label", ifSkill = "Absolution", includeTransfigured = true, tooltip = "Your Absolution Skill Damage will not be scaled with Count setting.\nBy default it multiplies both minion count and skill hit count which leads to incorrect\nTotal DPS calculation since Absolution cannot inherently shotgun.\nDo not enable if you use Spell Totem support, Spell Cascade support or similar supports", tooltipKey = "ui.config_options.module.absolution_skill_damage_counted_once.tooltip", apply = function(val, modList, enemyModList)
		modList:NewMod("Condition:AbsolutionSkillDamageCountedOnce", "FLAG", true, "Config", { type = "Condition", var = "Combat" })
	end },
	{ label = "Molten Shell:", labelKey = "ui.config_options.module.config_settings.label_45", ifSkill = "Molten Shell" },
	{ var = "MoltenShellDamageMitigated", type = "count", label = "Damage mitigated:", labelKey = "ui.config_options.module.molten_shell_damage_mitigated.label", tooltip = "Molten Shell reflects damage to the enemy,\nbased on the amount of damage it has mitigated.", tooltipKey = "ui.config_options.module.molten_shell_damage_mitigated.tooltip", ifSkill = "Molten Shell", apply = function(val, modList, enemyModList)
		modList:NewMod("SkillData", "LIST", { key = "MoltenShellDamageMitigated", value = val }, "Config", { type = "SkillName", skillName = "Molten Shell" })
	end },
	{ label = "Vaal Molten Shell:", labelKey = "ui.config_options.module.config_settings.label_85", ifSkill = "Vaal Molten Shell" },
	{ var = "VaalMoltenShellDamageMitigated", type = "count", label = "Damage mitigated:", labelKey = "ui.config_options.module.molten_shell_damage_mitigated.label", tooltip = "Vaal Molten Shell reflects damage to the enemy,\nbased on the amount of damage it has mitigated in the last second.", tooltipKey = "ui.config_options.module.vaal_molten_shell_damage_mitigated.tooltip", ifSkill = "Vaal Molten Shell", apply = function(val, modList, enemyModList)
		modList:NewMod("SkillData", "LIST", { key = "VaalMoltenShellDamageMitigated", value = val }, "Config", { type = "SkillName", skillName = "Molten Shell" })
	end },
	{ label = "Multi-part area skills:", labelKey = "ui.config_options.module.config_settings.label_47", ifSkill = { "Seismic Trap", "Lightning Spire Trap", "Explosive Trap" }, includeTransfigured = true },
	{ var = "enemySizePreset", type = "list", label = "Enemy size preset:", labelKey = "ui.config_options.module.enemy_size_preset.label", ifSkill = { "Seismic Trap", "Lightning Spire Trap", "Explosive Trap" }, includeTransfigured = true, defaultIndex = 2, tooltip = [[
Configure the radius of an enemy hitbox which is used in calculating some area multi-hitting (shotgunning) effects.

Small sets the radius to 2.
	Most monsters and the players' character are this size.
Medium sets the radius to 3.
	This is the size of most humanoid bosses (i.e. The Maven; The Shaper; Izaro)
Large sets the radius to 5.
	This is the size of some larger bosses (i.e. King Kaom; Vaal Oversoul)
Huge sets the radius to 11.
	This is the size of some of the largest bosses (i.e. Nucleus of the Maven; Tsoagoth, The Brine King)]], tooltipKey = "ui.config_options.module.enemy_size_preset.tooltip", list = {{val="Small",label="Small", labelKey = "ui.config_options.module.enemy_size_preset.label_5"},{val="Medium",label="Medium", labelKey = "ui.config_options.module.enemy_size_preset.label_4"},{val="Large",label="Large", labelKey = "ui.config_options.module.enemy_size_preset.label_3"},{val="Huge",label="Huge", labelKey = "ui.config_options.module.enemy_size_preset.label_2"}}, apply = function(val, modList, enemyModList, build)
		if val == "Small" then
			build.configTab.varControls['enemyRadius']:SetPlaceholder(2, false)
			modList:NewMod("EnemyRadius", "BASE", 2, "Config")
		elseif val == "Medium" then
			build.configTab.varControls['enemyRadius']:SetPlaceholder(3, false)
			modList:NewMod("EnemyRadius", "BASE", 3, "Config")
		elseif val == "Large" then
			build.configTab.varControls['enemyRadius']:SetPlaceholder(5, false)
			modList:NewMod("EnemyRadius", "BASE", 5, "Config")
		elseif val == "Huge" then
			build.configTab.varControls['enemyRadius']:SetPlaceholder(11, false)
			modList:NewMod("EnemyRadius", "BASE", 11, "Config")
		end
	end },
	{ var = "enemyRadius", type = "countAllowZero", label = "Enemy radius:", labelKey = "ui.config_options.module.enemy_radius.label", ifSkill = { "Seismic Trap", "Lightning Spire Trap", "Explosive Trap" }, includeTransfigured = true, tooltip = "Configure the radius of an enemy hitbox to calculate some area overlapping (shotgunning) effects.", tooltipKey = "ui.config_options.module.enemy_radius.tooltip", apply = function(val, modList, enemyModList)
		modList:NewMod("EnemyRadius", "OVERRIDE", m_max(val, 1), "Config")
	end },
	{ var = "TotalSpectreLife", type = "countAllowZero", label = "Total Spectre Life override:", labelKey = "ui.config_options.module.total_spectre_life.label", ifMod = "TakenFromSpectresBeforeYou", tooltip = "Overrides the automatically calculated total Life of your damageable Spectres that can be taken before yours", tooltipKey = "ui.config_options.module.total_spectre_life.tooltip", apply = function(val, modList, enemyModList)
		modList:NewMod("TotalSpectreLife", "OVERRIDE", val, "Config")
	end },
	{ var = "TotalTotemLife", type = "countAllowZero", label = "Total Totem Life:", labelKey = "ui.config_options.module.total_totem_life.label", ifOption = "conditionHaveTotem", ifMod = "TakenFromTotemsBeforeYou", tooltip = "The total life of your Totems (excluding Vaal Rejuvenation Totem) that can be taken before yours (used by totem mastery)", tooltipKey = "ui.config_options.module.total_totem_life.tooltip", apply = function(val, modList, enemyModList)
		modList:NewMod("TotalTotemLife", "BASE", val, "Config")
	end },
	{ var = "TotalRadianceSentinelLife", type = "countAllowZero", label = "Total life pool of Sentinel of Radiance", labelKey = "ui.config_options.module.total_radiance_sentinel_life.label", ifMod = "takenFromRadianceSentinelBeforeYou", apply = function(val, modList, enemyModList)
		modList:NewMod("TotalRadianceSentinelLife", "BASE", val, "Config")
	end },
	{ var = "TotalVaalRejuvenationTotemLife", type = "countAllowZero", label = "Total Vaal Rejuvenation Totem Life:", labelKey = "ui.config_options.module.total_vaal_rejuvenation_totem_life.label", ifSkill = { "Vaal Rejuvenation Totem" }, ifMod = "takenFromVaalRejuvenationTotemsBeforeYou", tooltip = "The total life of your Vaal Rejuvenation Totems that can be taken before yours", tooltipKey = "ui.config_options.module.total_vaal_rejuvenation_totem_life.tooltip", apply = function(val, modList, enemyModList)
		modList:NewMod("TotalVaalRejuvenationTotemLife", "BASE", val, "Config")
	end },
	{ var = "TotalCompanionLife", type = "countAllowZero", label = "Total Companion Life override:", labelKey = "ui.config_options.module.total_companion_life.label", ifMod = { "TakenFromCompanionBeforeYou", "TakenFromCompanionBeforeYouFromDeflected" }, tooltip = "Overrides the automatically calculated total Life of your damageable Companions\nthat can be taken before yours (e.g. Starkonja's Head, Loyalty)", tooltipKey = "ui.config_options.module.total_companion_life.tooltip", apply = function(val, modList, enemyModList)
		modList:NewMod("TotalCompanionLife", "OVERRIDE", val, "Config")
	end },
	-- Section: Combat options
	{ section = "When In Combat", sectionKey = "ui.config_options.module.config_settings.section_6", col = 1 },
	{ var = "usePowerCharges", type = "check", label = "Do you use Power Charges?", labelKey = "ui.config_options.module.use_power_charges.label", apply = function(val, modList, enemyModList)
		modList:NewMod("Condition:UsePowerCharges", "FLAG", true, "Config")
	end },
	{ var = "overridePowerCharges", type = "count", label = "# of Power Charges (if not maximum):", labelKey = "ui.config_options.module.override_power_charges.label", ifOption = "usePowerCharges", apply = function(val, modList, enemyModList)
		modList:NewMod("PowerCharges", "OVERRIDE", val, "Config", { type = "Condition", var = "Combat" })
	end },
	{ var = "useFrenzyCharges", type = "check", label = "Do you use Frenzy Charges?", labelKey = "ui.config_options.module.use_frenzy_charges.label", apply = function(val, modList, enemyModList)
		modList:NewMod("Condition:UseFrenzyCharges", "FLAG", true, "Config")
	end },
	{ var = "overrideFrenzyCharges", type = "count", label = "# of Frenzy Charges (if not maximum):", labelKey = "ui.config_options.module.override_frenzy_charges.label", ifOption = "useFrenzyCharges", apply = function(val, modList, enemyModList)
		modList:NewMod("FrenzyCharges", "OVERRIDE", val, "Config", { type = "Condition", var = "Combat" })
	end },
	{ var = "useEnduranceCharges", type = "check", label = "Do you use Endurance Charges?", labelKey = "ui.config_options.module.use_endurance_charges.label", apply = function(val, modList, enemyModList)
		modList:NewMod("Condition:UseEnduranceCharges", "FLAG", true, "Config")
	end },
	{ var = "overrideEnduranceCharges", type = "count", label = "# of Endurance Charges (if not maximum):", labelKey = "ui.config_options.module.override_endurance_charges.label", ifOption = "useEnduranceCharges", apply = function(val, modList, enemyModList)
		modList:NewMod("EnduranceCharges", "OVERRIDE", val, "Config", { type = "Condition", var = "Combat" })
	end },
	{ var = "useSiphoningCharges", type = "check", label = "Do you use Siphoning Charges?", labelKey = "ui.config_options.module.use_siphoning_charges.label", ifMult = "SiphoningCharge", apply = function(val, modList, enemyModList)
		modList:NewMod("UseSiphoningCharges", "FLAG", true, "Config", { type = "Condition", var = "Combat" })
	end },
	{ var = "overrideSiphoningCharges", type = "count", label = "# of Siphoning Charges (if not maximum):", labelKey = "ui.config_options.module.override_siphoning_charges.label", ifOption = "useSiphoningCharges", apply = function(val, modList, enemyModList)
		modList:NewMod("SiphoningCharges", "OVERRIDE", val, "Config", { type = "Condition", var = "Combat" })
	end },
	{ var = "useChallengerCharges", type = "check", label = "Do you use Challenger Charges?", labelKey = "ui.config_options.module.use_challenger_charges.label", ifMult = "ChallengerCharge", apply = function(val, modList, enemyModList)
		modList:NewMod("UseChallengerCharges", "FLAG", true, "Config", { type = "Condition", var = "Combat" })
	end },
	{ var = "overrideChallengerCharges", type = "count", label = "# of Challenger Charges (if not maximum):", labelKey = "ui.config_options.module.override_challenger_charges.label", ifOption = "useChallengerCharges", apply = function(val, modList, enemyModList)
		modList:NewMod("ChallengerCharges", "OVERRIDE", val, "Config", { type = "Condition", var = "Combat" })
	end },
	{ var = "useBlitzCharges", type = "check", label = "Do you use Blitz Charges?", labelKey = "ui.config_options.module.use_blitz_charges.label", ifMult = "BlitzCharge", apply = function(val, modList, enemyModList)
		modList:NewMod("UseBlitzCharges", "FLAG", true, "Config", { type = "Condition", var = "Combat" })
	end },
	{ var = "overrideBlitzCharges", type = "count", label = "# of Blitz Charges (if not maximum):", labelKey = "ui.config_options.module.override_blitz_charges.label", ifOption = "useBlitzCharges", apply = function(val, modList, enemyModList)
		modList:NewMod("BlitzCharges", "OVERRIDE", val, "Config", { type = "Condition", var = "Combat" })
	end },
	{ var = "overrideInspirationCharges", type = "countAllowZero", label = "# of Inspiration Charges (if not maximum):", labelKey = "ui.config_options.module.override_inspiration_charges.label", ifMult = "InspirationCharge", apply = function(val, modList, enemyModList)
		modList:NewMod("InspirationCharges", "OVERRIDE", val, "Config", { type = "Condition", var = "Combat" })
	end },
	{ var = "useGhostShrouds", legacy = true, type = "check", label = "Do you use Ghost Shrouds?", labelKey = "ui.config_options.module.use_ghost_shrouds.label", ifMult = "GhostShroud", apply = function(val, modList, enemyModList)
		modList:NewMod("UseGhostShrouds", "FLAG", true, "Config", { type = "Condition", var = "Combat" })
	end },
	{ var = "overrideGhostShrouds", type = "count", label = "# of Ghost Shrouds (if not maximum):", labelKey = "ui.config_options.module.override_ghost_shrouds.label", ifOption = "useGhostShrouds", apply = function(val, modList, enemyModList)
		modList:NewMod("GhostShrouds", "OVERRIDE", val, "Config", { type = "Condition", var = "Combat" })
	end },
	{ var = "configBossFaceBroken", type = "count", label = "# of Boss's Faces Broken:", labelKey = "ui.config_options.module.config_boss_face_broken.label", ifMult = "BossFaceBroken", tooltip = "Boss's Face Broken refers to unique bosses defeated in the campaign that have a skull marker on the World Screen. Rare monster encounters with the skull marker do not count.", tooltipKey = "ui.config_options.module.config_boss_face_broken.tooltip", apply = function(val, modList, enemyModList)
		modList:NewMod("Multiplier:BossFaceBroken", "BASE", val, "Config")
	end },
	{ var = "waitForMaxSeals", type = "check", label = "Do you wait for Max Seals?", labelKey = "ui.config_options.module.wait_for_max_seals.label", ifFlag = "HasSeals", apply = function(val, modList, enemyModList)
		modList:NewMod("UseMaxUnleash", "FLAG", true, "Config", { type = "Condition", var = "Combat" })
	end },
	{ var = "repeatMode", type = "list", label = "Repeat Mode:", labelKey = "ui.config_options.module.repeat_mode.label_4", ifCond = "alwaysFinalRepeat", list = {
		{val="NONE",label="None", labelKey = "ui.config_options.module.repeat_mode.label_3"},
		{val="AVERAGE",label="Average", labelKey = "ui.config_options.module.ailment_mode.label_2"},
		{val="FINAL",label="Final only", labelKey = "ui.config_options.module.repeat_mode.label_2"},
		{val="FINAL_DPS",label="Final (all hits use final)", labelKey = "ui.config_options.module.repeat_mode.label"}
	}, defaultIndex = 2, apply = function(val, modList, enemyModList)
		if val == "AVERAGE" then
			modList:NewMod("Condition:averageRepeat", "FLAG", true, "Config")
			modList:NewMod("MinionModifier", "LIST", { mod = modLib.createMod("Condition:averageRepeat", "FLAG", true, "Config") })
		elseif val == "FINAL" or val == "FINAL_DPS" then
			modList:NewMod("Condition:alwaysFinalRepeat", "FLAG", true, "Config")
			modList:NewMod("MinionModifier", "LIST", { mod = modLib.createMod("Condition:alwaysFinalRepeat", "FLAG", true, "Config") })
		end
	end },
	{ var = "ruthlessSupportMode", type = "list", label = "Ruthless Support Mode:", labelKey = "ui.config_options.module.ruthless_support_mode.label_2", ifSkill = "Ruthless", tooltip = "Controls how the hit/ailment effect of Ruthless Support is calculated:\n\tAverage: damage is based on the average application\n\tMax Effect: damage is based on maximum effect", tooltipKey = "ui.config_options.module.ruthless_support_mode.tooltip", list = {{val="AVERAGE",label="Average", labelKey = "ui.config_options.module.ailment_mode.label_2"},{val="MAX",label="Max Effect", labelKey = "ui.config_options.module.ruthless_support_mode.label"}} },
	{ var = "ChanceToIgnoreEnemyPhysicalDamageReductionMode", type = "list", label = "Chance To Ignore PDR Mode:", labelKey = "ui.config_options.module.chance_to_ignore_enemy_physical_damage_reduction_mode.label", ifMod = "ChanceToIgnoreEnemyPhysicalDamageReduction", tooltip = "Controls how the chance on hit to ignore enemy physical damage reduction is calculated:\n\tMinimum: never ignores unless chance is at least 100%\n\tAverage: damage is based on the average application\n\tMax Effect: always ignores if you have any chance", tooltipKey = "ui.config_options.module.chance_to_ignore_enemy_physical_damage_reduction_mode.tooltip", list = {{val="MIN",label="Minimum", labelKey = "ui.config_options.module.life_regen_mode.label_3"},{val="AVERAGE",label="Average", labelKey = "ui.config_options.module.ailment_mode.label_2"},{val="MAX",label="Max Effect", labelKey = "ui.config_options.module.ruthless_support_mode.label"}}, defaultIndex = 2 },
	{ var = "conditionSprinting", type = "check", label = "Are you Sprinting?", labelKey = "ui.config_options.module.condition_sprinting.label", ifFlag = "Condition:CanSprint", apply = function(val, modList, enemyModList)
		modList:NewMod("Condition:Sprinting", "FLAG", true, "Config", { type = "Condition", var = "Combat" }, { type = "Condition", var = "CanSprint" })
	end },
	{ var = "overrideBloodCharges", type = "countAllowZero", label = "# of Blood Charges (if not maximum):", labelKey = "ui.config_options.module.override_blood_charges.label", ifMult = "BloodCharge", apply = function(val, modList, enemyModList)
		modList:NewMod("BloodCharges", "OVERRIDE", val, "Config", { type = "Condition", var = "Combat" })
	end },
	{ var = "overrideSpiritCharges", type = "countAllowZero", label = "# of Spirit Charges:", labelKey = "ui.config_options.module.override_spirit_charges.label", ifMult = "SpiritCharge", apply = function(val, modList, enemyModList)
		modList:NewMod("SpiritCharges", "OVERRIDE", val, "Config", { type = "Condition", var = "Combat" })
	end },
	{ var = "minionsUsePowerCharges", type = "check", label = "Do your Minions use Power Charges?", labelKey = "ui.config_options.module.minions_use_power_charges.label", ifFlag = "haveMinion", apply = function(val, modList, enemyModList)
		modList:NewMod("MinionModifier", "LIST", { mod = modLib.createMod("UsePowerCharges", "FLAG", true, "Config", { type = "Condition", var = "Combat" }) }, "Config")
	end },
	{ var = "minionsUseFrenzyCharges", type = "check", label = "Do your Minions use Frenzy Charges?", labelKey = "ui.config_options.module.minions_use_frenzy_charges.label", ifFlag = "haveMinion", apply = function(val, modList, enemyModList)
		modList:NewMod("MinionModifier", "LIST", { mod = modLib.createMod("UseFrenzyCharges", "FLAG", true, "Config", { type = "Condition", var = "Combat" }) }, "Config")
	end },
	{ var = "minionsUseEnduranceCharges", type = "check", label = "Do your Minions use Endur. Charges?", labelKey = "ui.config_options.module.minions_use_endurance_charges.label", ifFlag = "haveMinion", apply = function(val, modList, enemyModList)
		modList:NewMod("MinionModifier", "LIST", { mod = modLib.createMod("UseEnduranceCharges", "FLAG", true, "Config", { type = "Condition", var = "Combat" }) }, "Config")
	end },
	{ var = "minionsOverridePowerCharges", type = "count", label = "# of Power Charges (if not maximum):", labelKey = "ui.config_options.module.override_power_charges.label", ifFlag = "haveMinion", ifOption = "minionsUsePowerCharges", apply = function(val, modList, enemyModList)
		modList:NewMod("MinionModifier", "LIST", { mod = modLib.createMod("PowerCharges", "OVERRIDE", val, "Config", { type = "Condition", var = "Combat" }) }, "Config")
	end },
	{ var = "minionsOverrideFrenzyCharges", type = "count", label = "# of Frenzy Charges (if not maximum):", labelKey = "ui.config_options.module.override_frenzy_charges.label", ifFlag = "haveMinion", ifOption = "minionsUseFrenzyCharges", apply = function(val, modList, enemyModList)
		modList:NewMod("MinionModifier", "LIST", { mod = modLib.createMod("FrenzyCharges", "OVERRIDE", val, "Config", { type = "Condition", var = "Combat" }) }, "Config")
	end },
	{ var = "minionsOverrideEnduranceCharges", type = "count", label = "# of Endurance Charges (if not maximum):", labelKey = "ui.config_options.module.override_endurance_charges.label", ifFlag = "haveMinion", ifOption = "minionsUseEnduranceCharges", apply = function(val, modList, enemyModList)
		modList:NewMod("MinionModifier", "LIST", { mod = modLib.createMod("EnduranceCharges", "OVERRIDE", val, "Config", { type = "Condition", var = "Combat" }) }, "Config")
	end },
	{ var = "multiplierRampage", type = "count", label = "# of Rampage Kills:", labelKey = "ui.config_options.module.multiplier_rampage.label", ifFlag = "Condition:Rampage", tooltip = "Rampage grants the following, up to 1000 stacks:\n\t1% increased Movement Speed per 20 Rampage\n\t2% increased Damage per 20 Rampage\nYou lose Rampage if you do not get a Kill within 5 seconds.", tooltipKey = "ui.config_options.module.multiplier_rampage.tooltip", apply = function(val, modList, enemyModList)
		modList:NewMod("Multiplier:Rampage", "BASE", val, "Config", { type = "Condition", var = "Combat" })
	end },
	{ var = "multiplierSoulEater", type = "count", label = "# of Soul Eater Stacks:", labelKey = "ui.config_options.module.multiplier_soul_eater.label", ifFlag = "Condition:CanHaveSoulEater", tooltip = "Soul Eater grants the following, up to a base of 45 stacks:\n\t5% increased Attack Speed\n\t5% increased Cast Speed\n\t1% increased character size per stack.", tooltipKey = "ui.config_options.module.multiplier_soul_eater.tooltip", apply = function(val, modList, enemyModList)
		modList:NewMod("Multiplier:SoulEaterStack", "BASE", val, "Config", { type = "Condition", var = "Combat" })
	end },
	{ var = "conditionFocused", type = "check", label = "Are you Focused?", labelKey = "ui.config_options.module.condition_focused.label", ifCond = "Focused", apply = function(val, modList, enemyModList)
		modList:NewMod("Condition:Focused", "FLAG", true, "Config", { type = "Condition", var = "Combat" })
	end },
	{ var = "buffLifetap", type = "check", label = "Do you have Lifetap?", labelKey = "ui.config_options.module.buff_lifetap.label", ifCond = "Lifetap", apply = function(val, modList, enemyModList)
		modList:NewMod("Condition:Lifetap", "FLAG", true, "Config", { type = "Condition", var = "Combat" })
		modList:NewMod("FlaskLifeRecovery", "INC", 20, "Lifetap")
	end },
	{ var = "buffOnslaught", type = "check", label = "Do you have Onslaught?", labelKey = "ui.config_options.module.buff_onslaught.label", tooltip = "In addition to allowing any 'while you have Onslaught' modifiers to apply,\nthis will enable the Onslaught buff itself. (Grants 20% increased Attack, Cast, and Movement Speed)", tooltipKey = "ui.config_options.module.buff_onslaught.tooltip", apply = function(val, modList, enemyModList)
		modList:NewMod("Condition:Onslaught", "FLAG", true, "Config", { type = "Condition", var = "Combat" })
	end },
	{ var = "buffArcaneSurge", type = "check", label = "Do you have Arcane Surge?", labelKey = "ui.config_options.module.buff_arcane_surge.label", tooltip = "In addition to allowing any 'while you have Arcane Surge' modifiers to apply,\nthis will enable the Arcane Surge buff itself. (Grants 15% increased Cast Speed and 20% more Mana Regeneration rate)", tooltipKey = "ui.config_options.module.buff_arcane_surge.tooltip", apply = function(val, modList, enemyModList)
		modList:NewMod("Condition:ArcaneSurge", "FLAG", true, "Config", { type = "Condition", var = "Combat" })
	end },
	{ var = "buffQuicksandHourglass", type = "check", label = "Do you have Quicksand Hourglass?", labelKey = "ui.config_options.module.buff_quicksand_hourglass.label", ifFlag = "Condition:CanGainQuicksandHourglass", tooltip = "this will enable the Quicksand Hourglass buff itself.", tooltipKey = "ui.config_options.module.buff_quicksand_hourglass.tooltip", apply = function(val, modList, enemyModList)
		modList:NewMod("Condition:QuicksandHourglass", "FLAG", true, "Config", { type = "Condition", var = "Combat" })
	end },
	{ var = "minionBuffOnslaught", type = "check", label = "Do your minions have Onslaught?", labelKey = "ui.config_options.module.minion_buff_onslaught.label", ifFlag = "haveMinion", tooltip = "In addition to allowing any 'while your minions have Onslaught' modifiers to apply,\nthis will enable the Onslaught buff itself. (Grants 20% increased Attack, Cast, and Movement Speed)", tooltipKey = "ui.config_options.module.minion_buff_onslaught.tooltip", apply = function(val, modList, enemyModList)
		modList:NewMod("MinionModifier", "LIST", { mod = modLib.createMod("Condition:Onslaught", "FLAG", true, "Config", { type = "Condition", var = "Combat" }) })
	end },
	{ var = "buffUnholyMight", type = "check", label = "Do you have Unholy Might?", labelKey = "ui.config_options.module.buff_unholy_might.label", tooltip = "This will enable the Unholy Might buff.\n(Grants 30% of All Damage as extra ^xD02090Chaos ^7Damage)", tooltipKey = "ui.config_options.module.buff_unholy_might.tooltip", apply = function(val, modList, enemyModList)
		modList:NewMod("Condition:UnholyMight", "FLAG", true, "Config", { type = "Condition", var = "Combat" })
	end },
	{ var = "minionbuffUnholyMight", type = "check", label = "Do your minions have Unholy Might?", labelKey = "ui.config_options.module.minionbuff_unholy_might.label", ifFlag = "haveMinion", tooltip = "This will enable the Unholy Might buff on your minions.\n\n(Grants 30% of All Damage as extra ^xD02090Chaos ^7Damage)", tooltipKey = "ui.config_options.module.minionbuff_unholy_might.tooltip", apply = function(val, modList, enemyModList)
		modList:NewMod("MinionModifier", "LIST", { mod = modLib.createMod("Condition:UnholyMight", "FLAG", true, "Config", { type = "Condition", var = "Combat" }) })
	end },
	{ var = "buffChaoticMight", type = "check", label = "Do you have Chaotic Might?", labelKey = "ui.config_options.module.buff_chaotic_might.label", tooltip = "This will enable the Chaotic Might buff.\n(Grants 30% of Physical Damage as Extra ^xD02090Chaos ^7Damage)", tooltipKey = "ui.config_options.module.buff_chaotic_might.tooltip", apply = function(val, modList, enemyModList)
		modList:NewMod("Condition:ChaoticMight", "FLAG", true, "Config", { type = "Condition", var = "Combat" })
	end },
	{ var = "minionbuffChaoticMight", type = "check", label = "Do your minions have Chaotic Might?", labelKey = "ui.config_options.module.minionbuff_chaotic_might.label", ifFlag = "haveMinion", tooltip = "This will enable the Chaotic Might buff on your minions.\n(Grants 30% of Physical Damage as Extra ^xD02090Chaos ^7Damage)", tooltipKey = "ui.config_options.module.minionbuff_chaotic_might.tooltip", apply = function(val, modList, enemyModList)
		modList:NewMod("MinionModifier", "LIST", { mod = modLib.createMod("Condition:ChaoticMight", "FLAG", true, "Config", { type = "Condition", var = "Combat" }) })
	end },
	{ var = "buffPhasing", type = "check", label = "Do you have Phasing?", labelKey = "ui.config_options.module.buff_phasing.label", ifCond = "Phasing", apply = function(val, modList, enemyModList)
		modList:NewMod("Condition:Phasing", "FLAG", true, "Config", { type = "Condition", var = "Combat" })
	end },
	{ var = "overrideFortification", type = "count", label = "# of Fortification Stacks (if not maximum):", labelKey = "ui.config_options.module.override_fortification.label", ifFlag = "Condition:Fortified", tooltip = "You have 1% less damage taken from hits per stack of fortification:\nHas a default cap of 20 stacks.", tooltipKey = "ui.config_options.module.override_fortification.tooltip", apply = function(val, modList, enemyModList)
		modList:NewMod("FortificationStacks", "OVERRIDE", val, "Config", { type = "Condition", var = "Combat" })
	end },
	{ var = "multiplierTailwind", type = "count", label = "# of Tailwind Stacks:", labelKey = "ui.config_options.module.multiplier_tailwind.label", ifFlag = "Condition:CanHaveTailwind", tooltip = "Tailwind grants the following, up to a base of 10 stacks:\n\t1% increased movement speed\n\t3% increased Skill Speed\n\t15% increased Evasion Rating", tooltipKey = "ui.config_options.module.multiplier_tailwind.tooltip", apply = function(val, modList, enemyModList)
		modList:NewMod("Multiplier:Tailwind", "BASE", val, "Config", { type = "Condition", var = "Combat" })
	end },
	{ var = "buffAdrenaline", type = "check", label = "Do you have Adrenaline?", labelKey = "ui.config_options.module.buff_adrenaline.label", tooltip = "This will enable the Adrenaline buff, which grants:\n\t100% increased Damage\n\t25% increased Attack, Cast and Movement Speed\n\t10% additional Physical Damage Reduction", tooltipKey = "ui.config_options.module.buff_adrenaline.tooltip", apply = function(val, modList, enemyModList)
		modList:NewMod("Condition:Adrenaline", "FLAG", true, "Config", { type = "Condition", var = "Combat" })
	end },
	{ var = "conditionChangedStanceLastSecond", type = "check", label = "Changed Stance in the last 1s?", labelKey = "ui.config_options.module.condition_changed_stance_last_second.label", ifCond = "StanceChangeLastSecond", tooltip = "'Changing Stance' occurs by activating a Stance skill while it's toggled on", tooltipKey = "ui.config_options.module.condition_changed_stance_last_second.tooltip", apply = function(val, modList, enemyModList)
		modList:NewMod("Condition:StanceChangeLastSecond", "FLAG", true, "Config", { type = "Condition", var = "Combat" })
	end },
	{ var = "buffAlchemistsGenius", type = "check", label = "Do you have Alchemist's Genius?", labelKey = "ui.config_options.module.buff_alchemists_genius.label", ifFlag = "Condition:CanHaveAlchemistGenius", tooltip = "This will enable the Alchemist's Genius buff:\n20% increased Flask Charges gained\n10% increased effect of Flasks", tooltipKey = "ui.config_options.module.buff_alchemists_genius.tooltip", apply = function(val, modList, enemyModList)
		modList:NewMod("Condition:AlchemistsGenius", "FLAG", true, "Config", { type = "Condition", var = "Combat" }, { type = "Condition", var = "CanHaveAlchemistGenius" })
	end },
	{ var = "buffVaalArcLuckyHits", type = "check", label = "Do you have Vaal Arc's Lucky Buff?", labelKey = "ui.config_options.module.buff_vaal_arc_lucky_hits.label", ifFlag = "Condition:CanBeLucky",  tooltip = "Causes Damage with Arc Hits to be rolled twice, and the maximum roll used.", tooltipKey = "ui.config_options.module.buff_vaal_arc_lucky_hits.tooltip", apply = function(val, modList, enemyModList)
		modList:NewMod("LuckyHits", "FLAG", true, "Config", { type = "Condition", varList = { "Combat", "CanBeLucky" } }, { type = "SkillName", skillName = "Arc", includeTransfigured = true })
	end },
	{ var = "buffElusive", type = "check", label = "Are you Elusive?", labelKey = "ui.config_options.module.buff_elusive.label", ifFlag = "Condition:CanBeElusive", tooltip = "In addition to allowing any 'while Elusive' modifiers to apply,\nthis will enable the Elusive buff itself:\n\t15% Chance to Avoid all Damage from Hits\n\t30% increased Movement Speed\nThe effect of Elusive decays over time.", tooltipKey = "ui.config_options.module.buff_elusive.tooltip", apply = function(val, modList, enemyModList)
		modList:NewMod("Condition:Elusive", "FLAG", true, "Config", { type = "Condition", var = "Combat" }, { type = "Condition", var = "CanBeElusive" })
		modList:NewMod("Elusive", "FLAG", true, "Config", { type = "Condition", var = "Combat" }, { type = "Condition", var = "CanBeElusive" })
	end },
	{ var = "overrideBuffElusive", type = "count", label = "Effect of Elusive (if not average):", labelKey = "ui.config_options.module.override_buff_elusive.label", ifOption = "buffElusive", tooltip = "If you have a guaranteed source of Elusive, the strongest one will apply. \nYou can change this to see various buff values", tooltipKey = "ui.config_options.module.override_buff_elusive.tooltip", apply = function(val, modList, enemyModList)
		modList:NewMod("ElusiveEffect", "OVERRIDE", val, "Config", {type = "GlobalEffect", effectType = "Buff" })
	end },
	{ var = "buffDivinity", type = "check", label = "Do you have Divinity?", labelKey = "ui.config_options.module.buff_divinity.label", ifCond = "Divinity", tooltip = "This will enable the Divinity buff, which grants:\n\t50% more Elemental Damage\n\t20% less Elemental Damage taken", tooltipKey = "ui.config_options.module.buff_divinity.tooltip", apply = function(val, modList, enemyModList)
		modList:NewMod("Condition:Divinity", "FLAG", true, "Config", { type = "Condition", var = "Combat" })
	end },
	{ var = "multiplierDefiance", type = "count", label = "Defiance:", labelKey = "ui.config_options.module.multiplier_defiance.label", ifMult = "Defiance", apply = function(val, modList, enemyModList)
		modList:NewMod("Multiplier:Defiance", "BASE", m_min(val, 10), "Config", { type = "Condition", var = "Combat" })
	end },
	{ var = "multiplierRage", type = "count", label = "^xFF9922Rage:", labelKey = "ui.config_options.module.multiplier_rage.label", ifPlayerFlag = "Condition:CanGainRage", tooltip = "Base Maximum ^xFF9922Rage ^7is 30, and inherently grants 1% More Attack Damage per 1 ^xFF9922Rage^7\nYou lose 5 ^xFF9922Rage ^7every second if you have not been Hit or gained ^xFF9922Rage ^7in the last 4 seconds.", tooltipKey = "ui.config_options.module.multiplier_rage.tooltip", apply = function(val, modList, enemyModList)
		modList:NewMod("Multiplier:RageStack", "BASE", val, "Config", { type = "IgnoreCond" }, { type = "Condition", var = "Combat" }, { type = "Condition", var = "CanGainRage" })
	end },
	{ var = "multiplierMinionRage", type = "count", label = "Minion ^xFF9922Rage:", labelKey = "ui.config_options.module.multiplier_minion_rage.label", ifMinionFlag = "Condition:CanGainRage", tooltip = "Sets the Minion's current Rage.\nRage is capped at Minion's Maximum Rage.", tooltipKey = "ui.config_options.module.multiplier_minion_rage.tooltip", apply = function(val, modList, enemyModList) modList:NewMod("MinionModifier", "LIST", { mod = modLib.createMod("Multiplier:RageStack", "BASE", val, "Config", { type = "IgnoreCond" }, { type = "Condition", var = "Combat" }, { type = "Condition", var = "CanGainRage" }) }, "Config")
	end },
	{ var = "multiplierCombo", type = "count", label = "Combo:", labelKey = "ui.config_options.module.multiplier_combo.label", ifMult = "ComboStacks", tooltip = "Some skills and effects require a certain Combo count to use.\nCombo is built by successfully Striking Enemies.", tooltipKey = "ui.config_options.module.multiplier_combo.tooltip", apply = function(val, modList, enemyModList)
		modList:NewMod("Multiplier:ComboStacks", "BASE", val, "Config", { type = "IgnoreCond" }, { type = "Condition", var = "Combat" })
	end },
	{ var = "conditionLeeching", type = "check", label = "Are you Leeching?", labelKey = "ui.config_options.module.condition_leeching.label", ifCond = "Leeching", tooltip = "You will automatically be considered to be Leeching if you have '^xE05030Life ^7Leech effects are not removed at Full ^xE05030Life^7',\nbut you can use this option to force it if necessary.", tooltipKey = "ui.config_options.module.condition_leeching.tooltip", apply = function(val, modList, enemyModList)
		modList:NewMod("Condition:Leeching", "FLAG", true, "Config", { type = "Condition", var = "Combat" })
	end },
	{ var = "conditionLeechingLife", type = "check", label = "Are you Leeching ^xE05030Life?", labelKey = "ui.config_options.module.condition_leeching_life.label", ifCond = "LeechingLife", implyCond = "Leeching", apply = function(val, modList, enemyModList)
		modList:NewMod("Condition:LeechingLife", "FLAG", true, "Config", { type = "Condition", var = "Combat" })
		modList:NewMod("Condition:Leeching", "FLAG", true, "Config", { type = "Condition", var = "Combat" })
	end },
	{ var = "conditionLeechingEnergyShield", type = "check", label = "Are you Leeching ^x88FFFFEnergy Shield?", labelKey = "ui.config_options.module.condition_leeching_energy_shield.label", ifCond = "LeechingEnergyShield", implyCond = "Leeching", apply = function(val, modList, enemyModList)
		modList:NewMod("Condition:LeechingEnergyShield", "FLAG", true, "Config", { type = "Condition", var = "Combat" })
		modList:NewMod("Condition:Leeching", "FLAG", true, "Config", { type = "Condition", var = "Combat" })
	end },
	{ var = "conditionLeechingMana", type = "check", label = "Are you Leeching ^x7070FFMana?", labelKey = "ui.config_options.module.condition_leeching_mana.label", ifCond = "LeechingMana", implyCond = "Leeching", apply = function(val, modList, enemyModList)
		modList:NewMod("Condition:LeechingMana", "FLAG", true, "Config", { type = "Condition", var = "Combat" })
		modList:NewMod("Condition:Leeching", "FLAG", true, "Config", { type = "Condition", var = "Combat" })
	end },
	{ var = "minionsConditionLeechingEnergyShield", type = "check", label = "Minion is Leeching ^x88FFFFEnergy Shield?", labelKey = "ui.config_options.module.minions_condition_leeching_energy_shield.label", ifMinionCond = "LeechingEnergyShield", apply = function(val, modList, enemyModList)
		modList:NewMod("MinionModifier", "LIST", { mod = modLib.createMod("Condition:LeechingEnergyShield", "FLAG", true, "Config") }, "Config")
		modList:NewMod("MinionModifier", "LIST", { mod = modLib.createMod("Condition:Leeching", "FLAG", true, "Config") }, "Config")
	end },
	{ var = "conditionUsingFlask", type = "check", label = "Do you have a Flask active?", labelKey = "ui.config_options.module.condition_using_flask.label", ifCond = "UsingFlask", tooltip = "This is automatically enabled if you have a flask active,\nbut you can use this option to force it if necessary.", tooltipKey = "ui.config_options.module.condition_using_flask.tooltip", apply = function(val, modList, enemyModList)
		modList:NewMod("Condition:UsingFlask", "FLAG", true, "Config", { type = "Condition", var = "Combat" })
	end },
	{ var = "conditionNoLifeFlaskUsesLeft", type = "check", label = "Are you out of Life Flask uses?", labelKey = "ui.config_options.module.condition_no_life_flask_uses_left.label", ifCond = "NoLifeFlaskUsesLeft", tooltip = "This is automatically enabled if you have a flask active,\nbut you can use this option to force it if necessary.", tooltipKey = "ui.config_options.module.condition_using_flask.tooltip", apply = function(val, modList, enemyModList)
		modList:NewMod("Condition:NoLifeFlaskUsesLeft", "FLAG", true, "Config", { type = "Condition", var = "Combat" })
	end },
	{ var = "conditionUsingCharm", type = "check", label = "Do you have a Charm active?", labelKey = "ui.config_options.module.condition_using_charm.label", ifCond = "UsingCharm", tooltip = "This is automatically enabled if you have a charm active,\nbut you can use this option to force it if necessary.", tooltipKey = "ui.config_options.module.condition_using_charm.tooltip", apply = function(val, modList, enemyModList)
		modList:NewMod("Condition:UsingCharm", "FLAG", true, "Config", { type = "Condition", var = "Combat" })
	end },
	{ var = "conditionHaveTotem", type = "check", label = "Do you have a Totem summoned?", labelKey = "ui.config_options.module.condition_have_totem.label", ifCond = "HaveTotem", tooltip = "You will automatically be considered to have a Totem if your main skill is a Totem,\nbut you can use this option to force it if necessary.", tooltipKey = "ui.config_options.module.condition_have_totem.tooltip", apply = function(val, modList, enemyModList)
		modList:NewMod("Condition:HaveTotem", "FLAG", true, "Config", { type = "Condition", var = "Combat" })
	end },
	{ var = "conditionSummonedTotemRecently", type = "check", label = "Have you Summoned a Totem Recently?", labelKey = "ui.config_options.module.condition_summoned_totem_recently.label", ifCond = "SummonedTotemRecently", tooltip = "You will automatically be considered to have Summoned a Totem Recently if your main skill is a Totem,\nbut you can use this option to force it if necessary.", tooltipKey = "ui.config_options.module.condition_summoned_totem_recently.tooltip", apply = function(val, modList, enemyModList)
		modList:NewMod("Condition:SummonedTotemRecently", "FLAG", true, "Config", { type = "Condition", var = "Combat" })
	end },
	{ var = "TotemsSummoned", type = "count", label = "# of Summoned Totems (if not maximum):", labelKey = "ui.config_options.module.totems_summoned.label", ifStat = "TotemsSummoned", ifFlag = "totem", implyCond = "HaveTotem", tooltip = "This also implies that you have a Totem summoned.\nThis will affect all 'per Summoned Totem' modifiers, even for non-Totem skills.", tooltipKey = "ui.config_options.module.totems_summoned.tooltip", apply = function(val, modList, enemyModList)
		modList:NewMod("TotemsSummoned", "OVERRIDE", val, "Config", { type = "Condition", var = "Combat" })
		modList:NewMod("Condition:HaveTotem", "FLAG", val >= 1, "Config", { type = "Condition", var = "Combat" })
	end },
	{ var = "conditionSummonedGolemInPast8Sec", type = "check", label = "Summoned Golem in past 8 Seconds?", labelKey = "ui.config_options.module.condition_summoned_golem_in_past8_sec.label", ifCond = "SummonedGolemInPast8Sec", implyCond = "SummonedGolemInPast10Sec", apply = function(val, modList, enemyModList)
		modList:NewMod("Condition:SummonedGolemInPast8Sec", "FLAG", true, "Config", { type = "Condition", var = "Combat" })
	end },
	{ var = "conditionSummonedGolemInPast10Sec", type = "check", label = "Summoned Golem in past 10 Seconds?", labelKey = "ui.config_options.module.condition_summoned_golem_in_past10_sec.label", ifCond = "SummonedGolemInPast10Sec", apply = function(val, modList, enemyModList)
		modList:NewMod("Condition:SummonedGolemInPast10Sec", "FLAG", true, "Config", { type = "Condition", var = "Combat" })
	end },
	{ var = "companionInPresence", type = "check", label = "Is a Companion in your Presence?", labelKey = "ui.config_options.module.companion_in_presence.label", ifSkillType = SkillType.CreatesCompanion, defaultState = true, apply = function(val, modList, enemyModList)
		modList:NewMod("Condition:CompanionInPresence", "FLAG", true, "Config", { type = "Condition", var = "HaveCompanion" })
	end },
	{ var = "multiplierNearbyAlly", type = "count", label = "# of Nearby Allies:", labelKey = "ui.config_options.module.multiplier_nearby_ally.label", ifMult = "NearbyAlly", apply = function(val, modList, enemyModList)
		modList:NewMod("Multiplier:NearbyAlly", "BASE", val, "Config", { type = "Condition", var = "Combat" })
	end },
	{ var = "multiplierNearbyCorpse", type = "count", label = "# of Nearby Corpses:", labelKey = "ui.config_options.module.multiplier_nearby_corpse.label", ifMult = "NearbyCorpse", apply = function(val, modList, enemyModList)
		modList:NewMod("Multiplier:NearbyCorpse", "BASE", val, "Config", { type = "Condition", var = "Combat" })
	end },
	{ var = "multiplierSummonedMinion", type = "count", label = "# of Summoned Minions (if not maximum):", labelKey = "ui.config_options.module.multiplier_summoned_minion.label", ifMult = "SummonedMinion", tooltip = "Use this to override the count if you do not have all your minions summoned", tooltipKey = "ui.config_options.module.multiplier_summoned_minion.tooltip", apply = function(val, modList, enemyModList)
		modList:NewMod("Multiplier:SummonedMinion", "OVERRIDE", val, "Config", { type = "Condition", var = "Combat" })
	end },
	{ var = "multiplierMinionsInPresence", type = "count", label = "# of Minions in your Presence:", labelKey = "ui.config_options.module.multiplier_minions_in_presence.label", ifMult = "MinionPresenceCount", tooltip = "Use this to override the count if you do not have all your minions summoned", tooltipKey = "ui.config_options.module.multiplier_summoned_minion.tooltip", apply = function(val, modList, enemyModList)
		modList:NewMod("Multiplier:MinionPresenceCount", "OVERRIDE", val, "Config", { type = "Condition", var = "Combat" })
	end },
	{ var = "conditionOnConsecratedGround", type = "check", label = "Are you on Consecrated Ground?", labelKey = "ui.config_options.module.condition_on_consecrated_ground.label", tooltip = "In addition to allowing any 'while on Consecrated Ground' modifiers to apply,\nConsecrated Ground grants 5% ^xE05030Life ^7Regeneration to players and allies.", tooltipKey = "ui.config_options.module.condition_on_consecrated_ground.tooltip", apply = function(val, modList, enemyModList)
		modList:NewMod("Condition:OnConsecratedGround", "FLAG", true, "Config", { type = "Condition", var = "Combat" })
		modList:NewMod("MinionModifier", "LIST", { mod = modLib.createMod("Condition:OnConsecratedGround", "FLAG", true, "Config", { type = "Condition", var = "Combat" }) })
	end },
	{ var = "conditionOnCausticGround", type = "check", label = "Are you on Caustic Ground?", labelKey = "ui.config_options.module.condition_on_caustic_ground.label", ifCond = "OnCausticGround", apply = function(val, modList, enemyModList)
		modList:NewMod("Condition:OnCausticGround", "FLAG", true, "Config", { type = "Condition", var = "Combat" })
	end },
	{ var = "conditionOnFungalGround", type = "check", label = "Are you on Fungal Ground?", labelKey = "ui.config_options.module.condition_on_fungal_ground.label", ifCond = { "OnFungalGround", "CreateFungalGround" }, tooltip = "Allies on your Fungal Ground gain +25% ^xD02090Chaos ^7Resistance.", tooltipKey = "ui.config_options.module.condition_on_fungal_ground.tooltip", apply = function(val, modList, enemyModList)
		modList:NewMod("Condition:OnFungalGround", "FLAG", true, "Config", { type = "Condition", var = "Combat" })
	end },
	{ var = "conditionOnBurningGround", type = "check", label = "Are you on ^xB97123Burning ^7Ground?", labelKey = "ui.config_options.module.condition_on_burning_ground.label", ifCond = "OnBurningGround", implyCond = "Burning", tooltip = "This also implies that you are ^xB97123Burning.", tooltipKey = "ui.config_options.module.condition_on_burning_ground.tooltip", apply = function(val, modList, enemyModList)
		modList:NewMod("Condition:OnBurningGround", "FLAG", true, "Config", { type = "Condition", var = "Combat" })
		modList:NewMod("Condition:Burning", "FLAG", true, "Config", { type = "Condition", var = "Combat" })
	end },
	{ var = "conditionOnIgnitedGround", type = "check", label = "Are you on ^xB97123Ignited ^7Ground?", labelKey = "ui.config_options.module.condition_on_ignited_ground.label", ifCond = "OnIgnitedGround", implyCond = "Ignited", tooltip = "This also implies that you are ^xB97123Ignited.", tooltipKey = "ui.config_options.module.condition_on_ignited_ground.tooltip", apply = function(val, modList, enemyModList)
		modList:NewMod("Condition:OnIgnitedGround", "FLAG", true, "Config", { type = "Condition", var = "Combat" })
		modList:NewMod("Condition:Ignited", "FLAG", true, "Config", { type = "Condition", var = "Combat" })
	end },
	{ var = "conditionOnChilledGround", type = "check", label = "Are you on ^x3F6DB3Chilled ^7Ground?", labelKey = "ui.config_options.module.condition_on_chilled_ground.label", ifCond = "OnChilledGround", implyCond = "Chilled", tooltip = "This also implies that you are ^x3F6DB3Chilled.", tooltipKey = "ui.config_options.module.condition_on_chilled_ground.tooltip", apply = function(val, modList, enemyModList)
		modList:NewMod("Condition:OnChilledGround", "FLAG", true, "Config", { type = "Condition", var = "Combat" })
		modList:NewMod("Condition:Chilled", "FLAG", true, "Config", { type = "Condition", var = "Combat" })
	end },
	{ var = "conditionOnShockedGround", type = "check", label = "Are you on ^xADAA47Shocked ^7Ground?", labelKey = "ui.config_options.module.condition_on_shocked_ground.label", ifCond = "OnShockedGround", implyCond = "Shocked", tooltip = "This also implies that you are ^xADAA47Shocked.", tooltipKey = "ui.config_options.module.condition_on_shocked_ground.tooltip", apply = function(val, modList, enemyModList)
		modList:NewMod("Condition:OnShockedGround", "FLAG", true, "Config", { type = "Condition", var = "Combat" })
		modList:NewMod("Condition:Shocked", "FLAG", true, "Config", { type = "Condition", var = "Combat" })
	end },
	{ var = "conditionBlinded", type = "check", label = "Are you Blinded?", labelKey = "ui.config_options.module.condition_blinded.label", ifCond = "Blinded", apply = function(val, modList, enemyModList)
		modList:NewMod("Condition:Blinded", "FLAG", true, "Config", { type = "Condition", var = "Combat" })
	end },
	{ var = "conditionBurning", type = "check", label = "Are you ^xB97123Burning?", labelKey = "ui.config_options.module.condition_burning.label", ifCond = "Burning", apply = function(val, modList, enemyModList)
		modList:NewMod("Condition:Burning", "FLAG", true, "Config", { type = "Condition", var = "Combat" })
	end },
	{ var = "conditionIgnited", type = "check", label = "Are you ^xB97123Ignited?", labelKey = "ui.config_options.module.condition_ignited.label", ifCond = "Ignited", implyCond = "Burning", tooltip = "This also implies that you are ^xB97123Burning.", tooltipKey = "ui.config_options.module.condition_on_burning_ground.tooltip", apply = function(val, modList, enemyModList)
		modList:NewMod("Condition:Ignited", "FLAG", true, "Config", { type = "Condition", var = "Combat" })
	end },
	{ var = "conditionScorched", type = "check", label = "Are you ^xB97123Scorched?", labelKey = "ui.config_options.module.condition_scorched.label", ifCond = "Scorched", apply = function(val, modList, enemyModList)
		modList:NewMod("Condition:Scorched", "FLAG", true, "Config", { type = "Condition", var = "Combat" })
	end },
	{ var = "conditionChilled", type = "check", label = "Are you ^x3F6DB3Chilled?", labelKey = "ui.config_options.module.condition_chilled.label", ifCond = "Chilled", apply = function(val, modList, enemyModList)
		modList:NewMod("Condition:Chilled", "FLAG", true, "Config", { type = "Condition", var = "Combat" })
	end },
	{ var = "conditionChilledEffect", type = "count", label = "Effect of ^x3F6DB3Chill:", labelKey = "ui.config_options.module.condition_chilled_effect.label", ifOption = "conditionChilled", apply = function(val, modList, enemyModList)
		modList:NewMod("ChillVal", "OVERRIDE", val, "Chill", { type = "Condition", var = "Chilled" })
	end },
	{ var = "conditionSelfChill", type = "check", label = "Did you ^x3F6DB3Chill ^7yourself?", labelKey = "ui.config_options.module.condition_self_chill.label", ifOption = "conditionChilled", apply = function(val, modList, enemyModList)
		modList:NewMod("Condition:ChilledSelf", "FLAG", true, "Config", { type = "Condition", var = "Combat" })
	end },
	{ var = "conditionFrozen", type = "check", label = "Are you ^x3F6DB3Frozen?", labelKey = "ui.config_options.module.condition_frozen.label", ifCond = "Frozen", apply = function(val, modList, enemyModList)
		modList:NewMod("Condition:Frozen", "FLAG", true, "Config", { type = "Condition", var = "Combat" })
	end },
	{ var = "conditionBrittle", type = "check", label = "Are you ^x3F6DB3Brittle?", labelKey = "ui.config_options.module.condition_brittle.label", ifCond = "Brittle", apply = function(val, modList, enemyModList)
		modList:NewMod("Condition:Brittle", "FLAG", true, "Config", { type = "Condition", var = "Combat" })
	end },
	{ var = "conditionShocked", type = "check", label = "Are you ^xADAA47Shocked?", labelKey = "ui.config_options.module.condition_shocked.label", ifCond = "Shocked", apply = function(val, modList, enemyModList)
		modList:NewMod("Condition:Shocked", "FLAG", true, "Config", { type = "Condition", var = "Combat" })
		modList:NewMod("DamageTaken", "INC", 15, "Shock", { type = "Condition", var = "Shocked" })
	end },
	{ var = "conditionSapped", type = "check", label = "Are you ^xADAA47Sapped?", labelKey = "ui.config_options.module.condition_sapped.label", ifCond = "Sapped", apply = function(val, modList, enemyModList)
		modList:NewMod("Condition:Sapped", "FLAG", true, "Config", { type = "Condition", var = "Combat" })
	end },
	{ var = "conditionBleeding", type = "check", label = "Are you Bleeding?", labelKey = "ui.config_options.module.condition_bleeding.label", ifCond = "Bleeding", apply = function(val, modList, enemyModList)
		modList:NewMod("Condition:Bleeding", "FLAG", true, "Config", { type = "Condition", var = "Combat" })
	end },
	{ var = "conditionPoisoned", type = "check", label = "Are you Poisoned?", labelKey = "ui.config_options.module.condition_poisoned.label", ifCond = "Poisoned", apply = function(val, modList, enemyModList)
		modList:NewMod("Condition:Poisoned", "FLAG", true, "Config", { type = "Condition", var = "Combat" })
	end },
	{ var = "conditionCanBeCurseImmune", type = "check", label = "Are you Immune to Curses?", labelKey = "ui.config_options.module.condition_can_be_curse_immune.label", ifFlag = "Condition:CanBeCurseImmune", apply = function(val, modList, enemyModList)
		modList:NewMod("AvoidCurse", "BASE", 100, "Config", { type = "Condition", var = "Combat" }, { type = "GlobalEffect", effectType = "Global", unscalable = true })
	end },
	{ var = "multiplierPoisonOnSelf", type = "count", label = "# of Poison on You:", labelKey = "ui.config_options.module.multiplier_poison_on_self.label", ifMult = "PoisonStacks", implyCond = "Poisoned", tooltip = "This also implies that you are Poisoned.", tooltipKey = "ui.config_options.module.multiplier_poison_on_self.tooltip", apply = function(val, modList, enemyModList)
		modList:NewMod("Multiplier:PoisonStacks", "BASE", val, "Config", { type = "Condition", var = "Effective" })
	end },
	{ var = "multiplierWitheredStackCountSelf", type = "countAllowZero", label = "# of Withered Stacks on you:", labelKey = "ui.config_options.module.multiplier_withered_stack_count_self.label", ifFlag = "Condition:CanBeWithered", tooltip = "Withered applies 5% increased ^xD02090Chaos ^7Damage Taken to the self, up to 10 stacks.", tooltipKey = "ui.config_options.module.multiplier_withered_stack_count_self.tooltip", defaultPlaceholderState = 15, apply = function(val, modList, enemyModList)
		modList:NewMod("Multiplier:WitheredStack", "BASE", val, "Config", { type = "Condition", var = "Effective" })
	end },
	{ var = "multiplierNearbyEnemies", type = "count", label = "# of nearby Enemies:", labelKey = "ui.config_options.module.multiplier_nearby_enemies.label", ifMult = "NearbyEnemies", apply = function(val, modList, enemyModList)
		modList:NewMod("Multiplier:NearbyEnemies", "BASE", val, "Config", { type = "Condition", var = "Combat" })
		modList:NewMod("Condition:OnlyOneNearbyEnemy", "FLAG", val == 1, "Config", { type = "Condition", var = "Combat" })
	end },
	{ var = "multiplierNearbyRareOrUniqueEnemies", type = "countAllowZero", label = "# of nearby Rare or Unique Enemies:", labelKey = "ui.config_options.module.multiplier_nearby_rare_or_unique_enemies.label", ifMult = "NearbyRareOrUniqueEnemies", apply = function(val, modList, enemyModList)
		modList:NewMod("Multiplier:NearbyRareOrUniqueEnemies", "BASE", val, "Config", { type = "Condition", var = "Combat" })
		modList:NewMod("Multiplier:NearbyEnemies", "BASE", val, "Config", { type = "Condition", var = "Combat" })
		modList:NewMod("Condition:AtMostOneNearbyRareOrUniqueEnemy", "FLAG", val <= 1, "Config", { type = "Condition", var = "Combat" })
		enemyModList:NewMod("Condition:NearbyRareOrUniqueEnemy", "FLAG", val >= 1, "Config", { type = "Condition", var = "Combat" })
	end },
	{ var = "conditionSurrounded", type = "check", label = "Are you surrounded?", labelKey = "ui.config_options.module.condition_surrounded.label", ifCond = "Surrounded", tooltip = "You are surrounded if there are at least 5 Enemies within 3 metres of you", tooltipKey = "ui.config_options.module.condition_surrounded.tooltip", apply = function(val, modList, enemyModList)
		modList:NewMod("Condition:Surrounded", "FLAG", true, "Config", { type = "Condition", var = "Combat" })
	end },
	{ var = "conditionHitRecently", type = "check", label = "Have you Hit Recently?", labelKey = "ui.config_options.module.condition_hit_recently.label", ifCond = "HitRecently", tooltip = "You will automatically be considered to have Hit Recently if your main skill Hits and is self-cast,\nbut you can use this option to force it if necessary.", tooltipKey = "ui.config_options.module.condition_hit_recently.tooltip", apply = function(val, modList, enemyModList)
		modList:NewMod("Condition:HitRecently", "FLAG", true, "Config", { type = "Condition", var = "Combat" })
	end },
	{ var = "conditionHitSpellRecently", type = "check", label = "Have you Hit with a Spell Recently?", labelKey = "ui.config_options.module.condition_hit_spell_recently.label", ifCond = "HitSpellRecently", implyCond = "HitRecently", tooltip = "This also implies that you have Hit Recently.", tooltipKey = "ui.config_options.module.condition_hit_spell_recently.tooltip", apply = function(val, modList, enemyModList)
		modList:NewMod("Condition:HitSpellRecently", "FLAG", true, "Config", { type = "Condition", var = "Combat" })
		modList:NewMod("Condition:HitRecently", "FLAG", true, "Config", { type = "Condition", var = "Combat" })
	end },
	{ var = "conditionHitMeleeRecently", type = "check", label = "Have you Melee Hit Recently?", labelKey = "ui.config_options.module.condition_hit_melee_recently.label", ifCond = "HitMeleeRecently", implyCond = "HitRecently", tooltip = "This also implies that you have Hit Recently.", tooltipKey = "ui.config_options.module.condition_hit_spell_recently.tooltip", apply = function(val, modList, enemyModList)
		modList:NewMod("Condition:HitMeleeRecently", "FLAG", true, "Config", { type = "Condition", var = "Combat" })
		modList:NewMod("Condition:HitRecently", "FLAG", true, "Config", { type = "Condition", var = "Combat" })
	end },
	{ var = "conditionHitProjectileRecently", type = "check", label = "Have you Hit with a Proj. Att. Recently?", labelKey = "ui.config_options.module.condition_hit_projectile_recently.label", ifCond = "HitProjectileRecently", implyCond = "HitRecently", tooltip = "This also implies that you have Hit Recently.", tooltipKey = "ui.config_options.module.condition_hit_spell_recently.tooltip", apply = function(val, modList, enemyModList)
		modList:NewMod("Condition:HitProjectileRecently", "FLAG", true, "Config", { type = "Condition", var = "Combat" })
		modList:NewMod("Condition:HitRecently", "FLAG", true, "Config", { type = "Condition", var = "Combat" })
	end },
	{ var = "conditionCritRecently", type = "check", label = "Have you Crit Recently?", labelKey = "ui.config_options.module.condition_crit_recently.label", ifCond = "CritRecently", implyCondList = { "SkillCritRecently", "CritInPast8Sec" }, tooltip = "This also implies that your Skills have Crit Recently.", tooltipKey = "ui.config_options.module.condition_crit_recently.tooltip", apply = function(val, modList, enemyModList)
		modList:NewMod("Condition:CritRecently", "FLAG", true, "Config", { type = "Condition", var = "Combat" })
		modList:NewMod("Condition:SkillCritRecently", "FLAG", true, "Config", { type = "Condition", var = "Combat" })
		modList:NewMod("Condition:CritInPast8Sec", "FLAG", true, "Config", { type = "Condition", var = "Combat" })
	end },
	{ var = "conditionCritInPast8Sec", type = "check", label = "Have you Crit in the past 8s?", labelKey = "ui.config_options.module.condition_crit_in_past8_sec.label", ifCond = "CritInPast8Sec", apply = function(val, modList, enemyModList)
		modList:NewMod("Condition:CritInPast8Sec", "FLAG", true, "Config", { type = "Condition", var = "Combat" })
	end },
	{ var = "conditionSkillCritRecently", type = "check", label = "Have your Skills Crit Recently?", labelKey = "ui.config_options.module.condition_skill_crit_recently.label", ifCond = "SkillCritRecently", implyCond = "CritInPast8Sec", apply = function(val, modList, enemyModList)
		modList:NewMod("Condition:SkillCritRecently", "FLAG", true, "Config", { type = "Condition", var = "Combat" })
		modList:NewMod("Condition:CritInPast8Sec", "FLAG", true, "Config", { type = "Condition", var = "Combat" })
	end },
	{ var = "conditionCritWithHeraldSkillRecently", type = "check", label = "Have your Herald Skills Crit Recently?", labelKey = "ui.config_options.module.condition_crit_with_herald_skill_recently.label", ifCond = "CritWithHeraldSkillRecently", implyCondList = { "SkillCritRecently", "CritInPast8Sec" }, tooltip = "This also implies that your Skills have Crit Recently.", tooltipKey = "ui.config_options.module.condition_crit_recently.tooltip", apply = function(val, modList, enemyModList)
		modList:NewMod("Condition:CritWithHeraldSkillRecently", "FLAG", true, "Config", { type = "Condition", var = "Combat" })
		modList:NewMod("Condition:SkillCritRecently", "FLAG", true, "Config", { type = "Condition", var = "Combat" })
		modList:NewMod("Condition:CritInPast8Sec", "FLAG", true, "Config", { type = "Condition", var = "Combat" })
	end },
	{ var = "conditionNonCritRecently", type = "check", label = "Have you dealt a Non-Crit Recently?", labelKey = "ui.config_options.module.condition_non_crit_recently.label", ifCond = "NonCritRecently", apply = function(val, modList, enemyModList)
		modList:NewMod("Condition:NonCritRecently", "FLAG", true, "Config", { type = "Condition", var = "Combat" })
	end },
	{ var = "LostNonVaalBuffRecently", type = "check", label = "Lost a Non-Vaal Guard Skill buff recently?", labelKey = "ui.config_options.module.lost_non_vaal_buff_recently.label", ifCond = "LostNonVaalBuffRecently", apply = function(val, modList, enemyModList)
		modList:NewMod("Condition:LostNonVaalBuffRecently", "FLAG", true, "Config", { type = "Condition", var = "Combat" })
	end },
	{ var = "conditionChannelling", type = "check", label = "Are you Channelling?", labelKey = "ui.config_options.module.condition_channelling.label", ifCond = "Channelling", tooltip = "You will automatically be considered to be Channeling if your main skill is a channelled skill,\nbut you can use this option to force it if necessary.", tooltipKey = "ui.config_options.module.condition_channelling.tooltip", apply = function(val, modList, enemyModList)
		modList:NewMod("Condition:Channelling", "FLAG", true, "Config", { type = "Condition", var = "Combat" })
	end },
	{ var = "multiplierChannelling", type = "count", label = "Channeling for # seconds:", labelKey = "ui.config_options.module.multiplier_channelling.label", ifMult = "ChannellingTime", implyCond = "Channelling", tooltip = "This also implies that you are channelling", tooltipKey = "ui.config_options.module.multiplier_channelling.tooltip", apply = function(val, modList, enemyModList)
		modList:NewMod("Multiplier:ChannellingTime", "BASE", val, "Config", { type = "Condition", var = "Combat" })
		modList:NewMod("Condition:Channelling", "FLAG", true, "Config", { type = "Condition", var = "Combat" })
	end },
	{ var = "conditionHitRecentlyWithWeapon", type = "check", label = "Have you Hit Recently with Your Weapon?", labelKey = "ui.config_options.module.condition_hit_recently_with_weapon.label", ifCond = "HitRecentlyWithWeapon", tooltip = "This also implies that you have Hit Recently.", tooltipKey = "ui.config_options.module.condition_hit_spell_recently.tooltip", apply = function(val, modList, enemyModList)
		modList:NewMod("Condition:HitRecentlyWithWeapon", "FLAG", true, "Config", { type = "Condition", var = "Combat" })
	end },
	{ var = "conditionKilledRecently", type = "check", label = "Have you Killed Recently?", labelKey = "ui.config_options.module.condition_killed_recently.label", ifCond = "KilledRecently", apply = function(val, modList, enemyModList)
		modList:NewMod("Condition:KilledRecently", "FLAG", true, "Config", { type = "Condition", var = "Combat" })
	end },
	{ var = "multiplierKilledRecently", type = "count", label = "# of Enemies Killed Recently:", labelKey = "ui.config_options.module.multiplier_killed_recently.label", ifMult = "EnemyKilledRecently", implyCond = "KilledRecently", tooltip = "This also implies that you have Killed Recently.", tooltipKey = "ui.config_options.module.multiplier_killed_recently.tooltip", apply = function(val, modList, enemyModList)
		modList:NewMod("Multiplier:EnemyKilledRecently", "BASE", val, "Config", { type = "Condition", var = "Combat" })
		modList:NewMod("Condition:KilledRecently", "FLAG", true, "Config", { type = "Condition", var = "Combat" })
	end },
	{ var = "conditionKilledLast3Seconds", type = "check", label = "Have you Killed in the last 3 Seconds?", labelKey = "ui.config_options.module.condition_killed_last3_seconds.label", ifCond = "KilledLast3Seconds", implyCond = "KilledRecently", tooltip = "This also implies that you have Killed Recently.", tooltipKey = "ui.config_options.module.multiplier_killed_recently.tooltip", apply = function(val, modList, enemyModList)
		modList:NewMod("Condition:KilledLast3Seconds", "FLAG", true, "Config", { type = "Condition", var = "Combat" })
	end },
	{ var = "conditionKilledPoisonedLast2Seconds", type = "check", label = "Killed a poisoned enemy in the last 2 Seconds?", labelKey = "ui.config_options.module.condition_killed_poisoned_last2_seconds.label", ifCond = "KilledPoisonedLast2Seconds", implyCond = "KilledRecently", tooltip = "This also implies that you have Killed Recently.", tooltipKey = "ui.config_options.module.multiplier_killed_recently.tooltip", apply = function(val, modList, enemyModList)
		modList:NewMod("Condition:KilledPoisonedLast2Seconds", "FLAG", true, "Config", { type = "Condition", var = "Combat" })
	end },
	{ var = "conditionKilledShockedLast3Seconds", type = "check", label = "Killed a ^xADAA47Shocked ^7enemy in the last 3 Seconds?", labelKey = "ui.config_options.module.condition_killed_shocked_last3_seconds.label", ifCond = "KilledShockedLast3Seconds", implyCondList = { "KilledRecently", "KilledLast3Seconds" }, tooltip = "This also implies that you have Killed Recently.", tooltipKey = "ui.config_options.module.multiplier_killed_recently.tooltip", apply = function(val, modList, enemyModList)
		modList:NewMod("Condition:KilledShockedLast3Seconds", "FLAG", true, "Config", { type = "Condition", var = "Combat" })
	end },
	{ var = "conditionKilledTauntedEnemyRecently", type = "check", label = "Killed a taunted enemy recently?", labelKey = "ui.config_options.module.condition_killed_taunted_enemy_recently.label", ifCond = "KilledTauntedEnemyRecently", implyCondList = {"KilledRecently", "TauntedEnemyRecently" }, tooltip = "This also implies that you have killed and taunted recently.", tooltipKey = "ui.config_options.module.condition_killed_taunted_enemy_recently.tooltip", apply = function(val, modList, enemyModList)
		modList:NewMod("Condition:KilledTauntedEnemyRecently", "FLAG", true, "Config", { type = "Condition", var = "Combat" })
	end },
	{ var = "conditionTotemsNotSummonedInPastTwoSeconds", type = "check", label = "No summoned Totems in the past 2 seconds?", labelKey = "ui.config_options.module.condition_totems_not_summoned_in_past_two_seconds.label", ifCond = "NoSummonedTotemsInPastTwoSeconds", apply = function(val, modList, enemyModList)
		modList:NewMod("Condition:NoSummonedTotemsInPastTwoSeconds", "FLAG", true, "Config", { type = "Condition", var = "Combat" })
	end },
	{ var = "conditionTotemsKilledRecently", type = "check", label = "Have your Totems Killed Recently?", labelKey = "ui.config_options.module.condition_totems_killed_recently.label", ifCond = "TotemsKilledRecently", apply = function(val, modList, enemyModList)
		modList:NewMod("Condition:TotemsKilledRecently", "FLAG", true, "Config", { type = "Condition", var = "Combat" })
	end },
	{ var = "conditionTotemsHitRecently", type = "check", label = "Have your Totems Hit Recently?", labelKey = "ui.config_options.module.condition_totems_hit_recently.label", ifCond = "HitRecently", apply = function(val, modList, enemyModList)
		modList:NewMod("Condition:TotemsHitRecently", "FLAG", true, "Config", { type = "Condition", var = "Combat" })
	end },
	{ var = "conditionTotemsHitSpellRecently", type = "check", label = "Have your Totems Hit with a Spell Recently?", labelKey = "ui.config_options.module.condition_totems_hit_spell_recently.label", ifCond = "TotemsHitSpellRecently", implyCond = "TotemsHitRecently", tooltip = "This also implies that you Totems have Hit Recently.", tooltipKey = "ui.config_options.module.condition_totems_hit_spell_recently.tooltip", apply = function(val, modList, enemyModList)
		modList:NewMod("Condition:TotemsHitSpellRecently", "FLAG", true, "Config", { type = "Condition", var = "Combat" })
		modList:NewMod("Condition:TotemsHitRecently", "FLAG", true, "Config", { type = "Condition", var = "Combat" })
	end },
	{ var = "conditionUsedBrandRecently", type = "check", label = "Have you used a Brand Skill recently?", labelKey = "ui.config_options.module.condition_used_brand_recently.label", ifCond = "UsedBrandRecently",  apply = function(val, modList, enemyModList)
		modList:NewMod("Condition:UsedBrandRecently", "FLAG", true, "Config", { type = "Condition", var = "Combat" })
	end },
	{ var = "multiplierTotemsKilledRecently", type = "count", label = "# of Enemies Killed by Totems Recently:", labelKey = "ui.config_options.module.multiplier_totems_killed_recently.label", ifMult = "EnemyKilledByTotemsRecently", implyCond = "TotemsKilledRecently", tooltip = "This also implies that your Totems have Killed Recently.", tooltipKey = "ui.config_options.module.multiplier_totems_killed_recently.tooltip", apply = function(val, modList, enemyModList)
		modList:NewMod("Multiplier:EnemyKilledByTotemsRecently", "BASE", val, "Config", { type = "Condition", var = "Combat" })
		modList:NewMod("Condition:TotemsKilledRecently", "FLAG", true, "Config", { type = "Condition", var = "Combat" })
	end },
	{ var = "conditionMinionsKilledRecently", type = "check", label = "Have your Minions Killed Recently?", labelKey = "ui.config_options.module.condition_minions_killed_recently.label", ifCond = "MinionsKilledRecently", apply = function(val, modList, enemyModList)
		modList:NewMod("Condition:MinionsKilledRecently", "FLAG", true, "Config", { type = "Condition", var = "Combat" })
	end },
	{ var = "conditionMinionsDiedRecently", type = "check", label = "Has a Minion Died Recently?", labelKey = "ui.config_options.module.condition_minions_died_recently.label", ifCond = "MinionsDiedRecently", apply = function(val, modList, enemyModList)
		modList:NewMod("Condition:MinionsDiedRecently", "FLAG", true, "Config", { type = "Condition", var = "Combat" })
	end },
	{ var = "multiplierMinionsKilledRecently", type = "count", label = "# of Enemies Killed by Minions Recently:", labelKey = "ui.config_options.module.multiplier_minions_killed_recently.label", ifMult = "EnemyKilledByMinionsRecently", implyCond = "MinionsKilledRecently", tooltip = "This also implies that your Minions have Killed Recently.", tooltipKey = "ui.config_options.module.multiplier_minions_killed_recently.tooltip", apply = function(val, modList, enemyModList)
		modList:NewMod("Multiplier:EnemyKilledByMinionsRecently", "BASE", val, "Config", { type = "Condition", var = "Combat" })
		modList:NewMod("Condition:MinionsKilledRecently", "FLAG", true, "Config", { type = "Condition", var = "Combat" })
	end },
	{ var = "conditionKilledAffectedByDoT", type = "check", label = "Killed enemy affected by your DoT Recently?", labelKey = "ui.config_options.module.condition_killed_affected_by_do_t.label", ifCond = "KilledAffectedByDotRecently", apply = function(val, modList, enemyModList)
		modList:NewMod("Condition:KilledAffectedByDotRecently", "FLAG", true, "Config", { type = "Condition", var = "Combat" })
	end },
	{ var = "multiplierShockedEnemyKilledRecently", type = "count", label = "# of ^xADAA47Shocked ^7Enemies Killed Recently:", labelKey = "ui.config_options.module.multiplier_shocked_enemy_killed_recently.label", ifMult = "ShockedEnemyKilledRecently", apply = function(val, modList, enemyModList)
		modList:NewMod("Multiplier:ShockedEnemyKilledRecently", "BASE", val, "Config", { type = "Condition", var = "Combat" })
	end },
	{ var = "multiplierShockedNonShockedEnemyRecently", type = "count", label = "# of Non-^xADAA47Shocked ^7Enemies ^xADAA47Shocked ^7 Recently:", labelKey = "ui.config_options.module.multiplier_shocked_non_shocked_enemy_recently.label", ifMult = "ShockedNonShockedEnemyRecently", apply = function(val, modList, enemyModList)
		modList:NewMod("Multiplier:ShockedNonShockedEnemyRecently", "BASE", val, "Config", { type = "Condition", var = "Combat" })
	end },
	{ var = "conditionFrozenEnemyRecently", type = "check", label = "Have you ^x3F6DB3Frozen ^7an enemy Recently?", labelKey = "ui.config_options.module.condition_frozen_enemy_recently.label", ifCond = "FrozenEnemyRecently", apply = function(val, modList, enemyModList)
		modList:NewMod("Condition:FrozenEnemyRecently", "FLAG", true, "Config", { type = "Condition", var = "Combat" })
	end },
	{ var = "conditionChilledEnemyRecently", type = "check", label = "Have you ^x3F6DB3Chilled ^7an enemy Recently?", labelKey = "ui.config_options.module.condition_chilled_enemy_recently.label", ifCond = "ChilledEnemyRecently", apply = function(val, modList, enemyModList)
		modList:NewMod("Condition:ChilledEnemyRecently", "FLAG", true, "Config", { type = "Condition", var = "Combat" })
	end },
	{ var = "conditionShatteredEnemyRecently", type = "check", label = "Have you ^x3F6DB3Shattered ^7an enemy Recently?", labelKey = "ui.config_options.module.condition_shattered_enemy_recently.label", ifCond = "ShatteredEnemyRecently", apply = function(val, modList, enemyModList)
		modList:NewMod("Condition:ShatteredEnemyRecently", "FLAG", true, "Config", { type = "Condition", var = "Combat" })
	end },
	{ var = "conditionIgnitedEnemyRecently", type = "check", label = "Have you ^xB97123Ignited ^7an enemy Recently?", labelKey = "ui.config_options.module.condition_ignited_enemy_recently.label", ifCond = "IgnitedEnemyRecently", apply = function(val, modList, enemyModList)
		modList:NewMod("Condition:IgnitedEnemyRecently", "FLAG", true, "Config", { type = "Condition", var = "Combat" })
	end },
	{ var = "multiplierIgniteAppliedRecently", type = "count", label = "# of ^xB97123Ignites ^7applied Recently:", labelKey = "ui.config_options.module.multiplier_ignite_applied_recently.label", ifMult = "IgniteAppliedRecently", apply = function(val, modList, enemyModList)
		modList:NewMod("Multiplier:IgniteAppliedRecently", "BASE", val, "Config", { type = "Condition", var = "Combat" })
	end },
	{ var = "conditionShockedEnemyRecently", type = "check", label = "Have you ^xADAA47Shocked ^7an enemy Recently?", labelKey = "ui.config_options.module.condition_shocked_enemy_recently.label", ifCond = "ShockedEnemyRecently", apply = function(val, modList, enemyModList)
		modList:NewMod("Condition:ShockedEnemyRecently", "FLAG", true, "Config", { type = "Condition", var = "Combat" })
	end },
	{ var = "conditionStunnedEnemyRecently", type = "check", label = "Have you Stunned an enemy Recently?", labelKey = "ui.config_options.module.condition_stunned_enemy_recently.label", ifCond = "StunnedEnemyRecently", apply = function(val, modList, enemyModList)
		modList:NewMod("Condition:StunnedEnemyRecently", "FLAG", true, "Config", { type = "Condition", var = "Combat" })
	end },
	{ var = "conditionPinnedEnemyRecently", type = "check", label = "Have you Pinned an enemy Recently?", labelKey = "ui.config_options.module.condition_pinned_enemy_recently.label", ifCond = "PinnedEnemyRecently", apply = function(val, modList, enemyModList)
		modList:NewMod("Condition:PinnedEnemyRecently", "FLAG", true, "Config", { type = "Condition", var = "Combat" })
	end },
	{ var = "multiplierPoisonAppliedRecently", type = "count", label = "# of Poisons applied Recently:", labelKey = "ui.config_options.module.multiplier_poison_applied_recently.label", ifMult = "PoisonAppliedRecently", apply = function(val, modList, enemyModList)
		modList:NewMod("Multiplier:PoisonAppliedRecently", "BASE", val, "Config", { type = "Condition", var = "Combat" })
	end },
	{ var = "multiplierLifeSpentRecently", type = "count", label = "# of ^xE05030Life ^7spent Recently:", labelKey = "ui.config_options.module.multiplier_life_spent_recently.label", ifMult = "LifeSpentRecently", apply = function(val, modList, enemyModList)
		modList:NewMod("Multiplier:LifeSpentRecently", "BASE", val, "Config", { type = "Condition", var = "Combat" })
	end },
	{ var = "multiplierLifeSpentPast8s", type = "count", label = "# of ^xE05030Life ^7spent in past 8s:", labelKey = "ui.config_options.module.multiplier_life_spent_past8s.label", ifMult = "LifeSpentPast8s", apply = function(val, modList, enemyModList)
		modList:NewMod("Multiplier:LifeSpentPast8s", "BASE", val, "Config", { type = "Condition", var = "Combat" })
	end },
	{ var = "multiplierManaSpentRecently", type = "count", label = "# of ^x7070FFMana ^7spent Recently:", labelKey = "ui.config_options.module.multiplier_mana_spent_recently.label", ifMult = "ManaSpentRecently", apply = function(val, modList, enemyModList)
		modList:NewMod("Multiplier:ManaSpentRecently", "BASE", val, "Config", { type = "Condition", var = "Combat" })
	end },
	{ var = "conditionStunnedRecently", type = "check", label = "Have you been Stunned Recently?", labelKey = "ui.config_options.module.condition_stunned_recently.label", ifCond = "StunnedRecently", implyCond = "BeenHitRecently", apply = function(val, modList, enemyModList)
		modList:NewMod("Condition:StunnedRecently", "FLAG", true, "Config", { type = "Condition", var = "Combat" })
		modList:NewMod("Condition:BeenHitRecently", "FLAG", true, "Config", { type = "Condition", var = "Combat" })
	end },
	{ var = "multiplierStunnedRecently", type = "count", label = "# of times Stunned Recently:", labelKey = "ui.config_options.module.multiplier_stunned_recently.label", ifOption = "conditionStunnedRecently", defaultPlaceholderState = 1, apply = function(val, modList, enemyModList)
		modList:NewMod("Multiplier:StunnedRecently", "BASE", m_min(val, 100), "Config", { type = "Condition", var = "Combat" }, { type = "Condition", var = "StunnedRecently" } )
	end },
	{ var = "conditionShapeshifted", type = "check", label = "Currently Shapeshifted?", labelKey = "ui.config_options.module.condition_shapeshifted.label", apply = function(val, modList, enemyModList)
		modList:NewMod("Condition:Shapeshifted", "FLAG", true, "Config")
	end },
	{ var = "conditionShapeshiftToAnimal", type = "check", label = "Shapeshifted to animal recently?", labelKey = "ui.config_options.module.condition_shapeshift_to_animal.label", ifSkillType = { SkillType.Bear, SkillType.Wolf, SkillType.Wyvern }, apply = function(val, modList, enemyModList)
		modList:NewMod("Condition:ShapeshiftToAnimal", "FLAG", true, "Config", { type = "Condition", var = "Combat" })
	end },
	{ var = "conditionShapeshiftToHuman", type = "check", label = "Shapeshifted to human recently?", labelKey = "ui.config_options.module.condition_shapeshift_to_human.label", ifSkillType = SkillType.Shapeshift, apply = function(val, modList, enemyModList)
		modList:NewMod("Condition:ShapeshiftToHuman", "FLAG", true, "Config", { type = "Condition", var = "Combat" })
	end },
	{ var = "conditionInfusionConsumedRecently", type = "check", label = "Infusion consumed recently?", labelKey = "ui.config_options.module.condition_infusion_consumed_recently.label", apply = function(val, modList, enemyModList)
		modList:NewMod("Condition:InfusionConsumedRecently", "FLAG", true, "Config", { type = "Condition", var = "Combat" })
	end },
	{ var = "conditionInDodgeRoll", type = "check", label = "Are you in dodge roll?", labelKey = "ui.config_options.module.condition_in_dodge_roll.label", ifCond = "InDodgeRoll", apply = function(val, modList, enemyModList)
		modList:NewMod("Condition:InDodgeRoll", "FLAG", true, "Config", { type = "Condition", var = "Combat" }, { type = "Condition", var ="CannotDodgeRoll", neg = true })
	end },

	{ var = "conditionBeenHitRecently", type = "check", label = "Have you been Hit Recently?", labelKey = "ui.config_options.module.condition_been_hit_recently.label", ifCond = "BeenHitRecently", apply = function(val, modList, enemyModList)
		modList:NewMod("Condition:BeenHitRecently", "FLAG", true, "Config", { type = "Condition", var = "Combat" })
	end },
	{ var = "multiplierBeenHitRecently", type = "count", label = "# of times you have been Hit Recently:", labelKey = "ui.config_options.module.multiplier_been_hit_recently.label", ifMult = "BeenHitRecently", apply = function(val, modList, enemyModList)
		modList:NewMod("Multiplier:BeenHitRecently", "BASE", val, "Config", { type = "Condition", var = "Combat" })
		modList:NewMod("Condition:BeenHitRecently", "FLAG", 1 <= val, "Config", { type = "Condition", var = "Combat" })
	end },
	{ var = "conditionBeenHitByAttackRecently", type = "check", label = "Have you been Hit by an Attack Recently?", labelKey = "ui.config_options.module.condition_been_hit_by_attack_recently.label", ifCond = "BeenHitByAttackRecently", apply = function(val, modList, enemyModList)
		modList:NewMod("Condition:BeenHitByAttackRecently", "FLAG", true, "Config", { type = "Condition", var = "Combat" })
	end },
	{ var = "conditionBeenCritRecently", type = "check", label = "Have you been Crit Recently?", labelKey = "ui.config_options.module.condition_been_crit_recently.label", ifCond = "BeenCritRecently", apply = function(val, modList, enemyModList)
		modList:NewMod("Condition:BeenCritRecently", "FLAG", true, "Config", { type = "Condition", var = "Combat" })
	end },
	{ var = "conditionConsumed12SteelShardsRecently", type = "check", label = "Consumed 12 Steel Shards Recently?", labelKey = "ui.config_options.module.condition_consumed12_steel_shards_recently.label", ifCond = "Consumed12SteelShardsRecently", apply = function(val, modList, enemyModList)
		modList:NewMod("Condition:Consumed12SteelShardsRecently", "FLAG", true, "Config", { type = "Condition", var = "Combat" })
	end },
	{ var = "conditionGainedPowerChargeRecently", type = "check", label = "Gained a Power Charge Recently?", labelKey = "ui.config_options.module.condition_gained_power_charge_recently.label", ifCond = "GainedPowerChargeRecently", apply = function(val, modList, enemyModList)
		modList:NewMod("Condition:GainedPowerChargeRecently", "FLAG", true, "Config", { type = "Condition", var = "Combat" })
	end },
	{ var = "conditionGainedFrenzyChargeRecently", type = "check", label = "Gained a Frenzy Charge Recently?", labelKey = "ui.config_options.module.condition_gained_frenzy_charge_recently.label", ifCond = "GainedFrenzyChargeRecently", apply = function(val, modList, enemyModList)
		modList:NewMod("Condition:GainedFrenzyChargeRecently", "FLAG", true, "Config", { type = "Condition", var = "Combat" })
	end },
	{ var = "conditionBeenSavageHitRecently", type = "check", label = "Have you taken a Savage Hit Recently?", labelKey = "ui.config_options.module.condition_been_savage_hit_recently.label", ifCond = "BeenSavageHitRecently", implyCond = "BeenHitRecently", tooltip = "This also implies that you have been Hit Recently.", tooltipKey = "ui.config_options.module.condition_been_savage_hit_recently.tooltip", apply = function(val, modList, enemyModList)
		modList:NewMod("Condition:BeenSavageHitRecently", "FLAG", true, "Config", { type = "Condition", var = "Combat" })
		modList:NewMod("Condition:BeenHitRecently", "FLAG", true, "Config", { type = "Condition", var = "Combat" })
	end },
	{ var = "conditionHitByFireDamageRecently", type = "check", label = "Have you been hit by ^xB97123Fire ^7Recently?", labelKey = "ui.config_options.module.condition_hit_by_fire_damage_recently.label", ifCond = "HitByFireDamageRecently", implyCond = "BeenHitRecently", tooltip = "This also implies that you have been Hit Recently.", tooltipKey = "ui.config_options.module.condition_been_savage_hit_recently.tooltip", apply = function(val, modList, enemyModList)
		modList:NewMod("Condition:HitByFireDamageRecently", "FLAG", true, "Config", { type = "Condition", var = "Combat" })
		modList:NewMod("Condition:BeenHitRecently", "FLAG", true, "Config", { type = "Condition", var = "Combat" })
	end },
	{ var = "conditionHitByColdDamageRecently", type = "check", label = "Have you been hit by ^x3F6DB3Cold ^7Recently?", labelKey = "ui.config_options.module.condition_hit_by_cold_damage_recently.label", ifCond = "HitByColdDamageRecently", implyCond = "BeenHitRecently", tooltip = "This also implies that you have been Hit Recently.", tooltipKey = "ui.config_options.module.condition_been_savage_hit_recently.tooltip", apply = function(val, modList, enemyModList)
		modList:NewMod("Condition:HitByColdDamageRecently", "FLAG", true, "Config", { type = "Condition", var = "Combat" })
		modList:NewMod("Condition:BeenHitRecently", "FLAG", true, "Config", { type = "Condition", var = "Combat" })
	end },
	{ var = "conditionHitByLightningDamageRecently", type = "check", label = "Have you been hit by ^xADAA47Light. ^7Recently?", labelKey = "ui.config_options.module.condition_hit_by_lightning_damage_recently.label", ifCond = "HitByLightningDamageRecently", implyCond = "BeenHitRecently", tooltip = "This also implies that you have been Hit Recently.", tooltipKey = "ui.config_options.module.condition_been_savage_hit_recently.tooltip", apply = function(val, modList, enemyModList)
		modList:NewMod("Condition:HitByLightningDamageRecently", "FLAG", true, "Config", { type = "Condition", var = "Combat" })
		modList:NewMod("Condition:BeenHitRecently", "FLAG", true, "Config", { type = "Condition", var = "Combat" })
	end },
	{ var = "conditionHitBySpellDamageRecently", type = "check", label = "Have you taken Spell Damage Recently?", labelKey = "ui.config_options.module.condition_hit_by_spell_damage_recently.label", ifCond = "HitBySpellDamageRecently", implyCond = "BeenHitRecently", tooltip = "This also implies that you have been Hit Recently.", tooltipKey = "ui.config_options.module.condition_been_savage_hit_recently.tooltip", apply = function(val, modList, enemyModList)
		modList:NewMod("Condition:HitBySpellDamageRecently", "FLAG", true, "Config", { type = "Condition", var = "Combat" })
		modList:NewMod("Condition:BeenHitRecently", "FLAG", true, "Config", { type = "Condition", var = "Combat" })
	end },
	{ var = "conditionTakenFireDamageFromEnemyHitRecently", type = "check", label = "Taken ^xB97123Fire ^7Damage from enemy Hit Recently?", labelKey = "ui.config_options.module.condition_taken_fire_damage_from_enemy_hit_recently.label", ifCond = "TakenFireDamageFromEnemyHitRecently", implyCond = "BeenHitRecently", tooltip = "This also implies that you have been Hit Recently.", tooltipKey = "ui.config_options.module.condition_been_savage_hit_recently.tooltip", apply = function(val, modList, enemyModList)
		modList:NewMod("Condition:TakenFireDamageFromEnemyHitRecently", "FLAG", true, "Config", { type = "Condition", var = "Combat" })
		modList:NewMod("Condition:BeenHitRecently", "FLAG", true, "Config", { type = "Condition", var = "Combat" })
	end },
	{ var = "conditionBlockedRecently", type = "check", label = "Have you Blocked Recently?", labelKey = "ui.config_options.module.condition_blocked_recently.label", ifCond = "BlockedRecently", apply = function(val, modList, enemyModList)
		modList:NewMod("Condition:BlockedRecently", "FLAG", true, "Config", { type = "Condition", var = "Combat" })
	end },
	{ var = "conditionActiveBlockedRecently", type = "check", label = "Have you Active Blocked Recently?", labelKey = "ui.config_options.module.condition_active_blocked_recently.label", ifCond = "ActiveBlockedRecently", apply = function(val, modList, enemyModList)
		modList:NewMod("Condition:ActiveBlockedRecently", "FLAG", true, "Config", { type = "Condition", var = "Combat" })
	end },
	{ var = "conditionBlockedAttackRecently", type = "check", label = "Have you Blocked an Attack Recently?", labelKey = "ui.config_options.module.condition_blocked_attack_recently.label", ifCond = "BlockedAttackRecently", implyCond = "BlockedRecently", tooltip = "This also implies that you have Blocked Recently.", tooltipKey = "ui.config_options.module.condition_blocked_attack_recently.tooltip", apply = function(val, modList, enemyModList)
		modList:NewMod("Condition:BlockedAttackRecently", "FLAG", true, "Config", { type = "Condition", var = "Combat" })
		modList:NewMod("Condition:BlockedRecently", "FLAG", true, "Config", { type = "Condition", var = "Combat" })
	end },
	{ var = "conditionBlockedSpellRecently", type = "check", label = "Have you Blocked a Spell Recently?", labelKey = "ui.config_options.module.condition_blocked_spell_recently.label", ifCond = "BlockedSpellRecently", implyCond = "BlockedRecently", tooltip = "This also implies that you have Blocked Recently.", tooltipKey = "ui.config_options.module.condition_blocked_attack_recently.tooltip", apply = function(val, modList, enemyModList)
		modList:NewMod("Condition:BlockedSpellRecently", "FLAG", true, "Config", { type = "Condition", var = "Combat" })
		modList:NewMod("Condition:BlockedRecently", "FLAG", true, "Config", { type = "Condition", var = "Combat" })
	end },
	{ var = "conditionParriedRecently", type = "check", label = "Have you Parried Recently?", labelKey = "ui.config_options.module.condition_parried_recently.label", ifCond = "ParriedRecently", apply = function(val, modList, enemyModList)
		modList:NewMod("Condition:ParriedRecently", "FLAG", true, "Config", { type = "Condition", var = "Combat" })
		modList:NewMod("Condition:BlockedRecently", "FLAG", true, "Config", { type = "Condition", var = "Combat" })
	end },
	{ var = "conditionDodgeRolledRecently", type = "check", label = "Have you Dodge Rolled Recently?", labelKey = "ui.config_options.module.condition_dodge_rolled_recently.label", ifCond = "DodgeRolledRecently", apply = function(val, modList, enemyModList)
		modList:NewMod("Condition:DodgeRolledRecently", "FLAG", true, "Config", { type = "Condition", var = "Combat" })
	end },
	{ var = "conditionEnergyShieldRechargeRecently", type = "check", label = "^x88FFFFEnergy Shield ^7Recharge started Recently?", labelKey = "ui.config_options.module.condition_energy_shield_recharge_recently.label", ifCond = "EnergyShieldRechargeRecently", apply = function(val, modList, enemyModList)
		modList:NewMod("Condition:EnergyShieldRechargeRecently", "FLAG", true, "Config", { type = "Condition", var = "Combat" })
	end },
	{ var = "conditionEnergyShieldRechargePastTwoSec", type = "check", label = "^x88FFFFES ^7Recharge started past 2 seconds?", labelKey = "ui.config_options.module.condition_energy_shield_recharge_past_two_sec.label", ifCond = "EnergyShieldRechargePastTwoSec", apply = function(val, modList, enemyModList)
		modList:NewMod("Condition:EnergyShieldRechargePastTwoSec", "FLAG", true, "Config", { type = "Condition", var = "Combat" })
	end },
	{ var = "conditionStoppedTakingDamageOverTimeRecently", type = "check", label = "Have you stopped taking DoT recently?", labelKey = "ui.config_options.module.condition_stopped_taking_damage_over_time_recently.label", ifCond = "StoppedTakingDamageOverTimeRecently", apply = function(val, modList, enemyModList)
		modList:NewMod("Condition:StoppedTakingDamageOverTimeRecently", "FLAG", true, "Config", { type = "Condition", var = "Combat" })
	end },
	{ var = "conditionConvergence", type = "check", label = "Do you have Convergence?", labelKey = "ui.config_options.module.condition_convergence.label", ifFlag = "Condition:CanGainConvergence", apply = function(val, modList, enemyModList)
		modList:NewMod("Condition:Convergence", "FLAG", true, "Config", { type = "Condition", var = "Combat" }, { type = "Condition", var = "CanGainConvergence" })
	end },
	{ var = "buffPendulum", type = "list", label = "Is Pendulum of Destruction active?", labelKey = "ui.config_options.module.buff_pendulum.label_3", ifCond = "PendulumOfDestructionAreaOfEffect", list = {{val=0,label="None", labelKey = "ui.config_options.module.repeat_mode.label_3"},{val="AREA",label="Area of Effect", labelKey = "ui.config_options.module.buff_pendulum.label"},{val="DAMAGE",label="Elemental Damage", labelKey = "ui.config_options.module.buff_pendulum.label_2"}}, apply = function(val, modList, enemyModList)
		if val == "AREA" then
			modList:NewMod("Condition:PendulumOfDestructionAreaOfEffect", "FLAG", true, "Config", { type = "Condition", var = "Combat" })
		elseif val == "DAMAGE" then
			modList:NewMod("Condition:PendulumOfDestructionElementalDamage", "FLAG", true, "Config", { type = "Condition", var = "Combat" })
		end
	end },
	{ var = "buffConflux", type = "list", label = "Conflux Buff:", labelKey = "ui.config_options.module.buff_conflux.label_3", ifCond = "ChillingConflux", list = {{val=0,label="None", labelKey = "ui.config_options.module.repeat_mode.label_3"},{val="CHILLING",label="^x3F6DB3Chilling", labelKey = "ui.config_options.module.buff_conflux.label_2"},{val="SHOCKING",label="^xADAA47Shocking", labelKey = "ui.config_options.module.buff_conflux.label_5"},{val="IGNITING",label="^xB97123Igniting", labelKey = "ui.config_options.module.buff_conflux.label_4"},{val="ALL",label="^x3F6DB3Chill ^7+ ^xADAA47Shock ^7+ ^xB97123Ignite", labelKey = "ui.config_options.module.buff_conflux.label"}}, apply = function(val, modList, enemyModList)
		if val == "CHILLING" or val == "ALL" then
			modList:NewMod("Condition:ChillingConflux", "FLAG", true, "Config", { type = "Condition", var = "Combat" })
		end
		if val == "SHOCKING" or val == "ALL" then
			modList:NewMod("Condition:ShockingConflux", "FLAG", true, "Config", { type = "Condition", var = "Combat" })
		end
		if val == "IGNITING" or val == "ALL" then
			modList:NewMod("Condition:IgnitingConflux", "FLAG", true, "Config", { type = "Condition", var = "Combat" })
		end
	end },
	{ var = "highestDamageType", type = "list", ifFlag = "ChecksHighestDamage", label = "Highest damage type Override:", labelKey = "ui.config_options.module.highest_damage_type.label_3", tooltip = "Determines whether modifiers that depend on the highest damage type apply.", tooltipKey = "ui.config_options.module.highest_damage_type.tooltip", list = {{val="NONE",label="Default", labelKey = "ui.config_options.module.highest_damage_type.label_2"},{val="Physical",label="Physical", labelKey = "ui.config_options.module.highest_damage_type.label_4"},{val="Lightning",label="Lightning", labelKey = "ui.config_options.module.elemental_conflux_element.label_4"},{val="Cold",label="Cold", labelKey = "ui.config_options.module.elemental_conflux_element.label"},{val="Fire",label="Fire", labelKey = "ui.config_options.module.elemental_conflux_element.label_3"},{val="Chaos",label="Chaos", labelKey = "ui.config_options.module.highest_damage_type.label"}}, apply = function(val, modList, enemyModList)
		if val ~= "NONE" then
			modList:NewMod("Condition:"..val.."IsHighestDamageType", "FLAG", true, "Config")
			modList:NewMod("IsHighestDamageTypeOVERRIDE", "FLAG", true, "Config")
		end
	end },
	{ var = "buffHeartstopper", type = "list", label = "Heartstopper Mode:", labelKey = "ui.config_options.module.buff_heartstopper.label_2", ifCond = "HeartstopperHIT", list = {{val=0,label="None", labelKey = "ui.config_options.module.repeat_mode.label_3"},{val="AVERAGE",label="Average", labelKey = "ui.config_options.module.ailment_mode.label_2"},{val="HIT",label="Hit", labelKey = "ui.config_options.module.buff_heartstopper.label_3"},{val="DOT",label="Damage over Time", labelKey = "ui.config_options.module.buff_heartstopper.label"}}, apply = function(val, modList, enemyModList)
		if val == "HIT" then
			modList:NewMod("Condition:HeartstopperHIT", "FLAG", true, "Config", { type = "Condition", var = "Combat" })
		elseif val == "DOT" then
			modList:NewMod("Condition:HeartstopperDOT", "FLAG", true, "Config", { type = "Condition", var = "Combat" })
		elseif val == "AVERAGE" then
			modList:NewMod("Condition:HeartstopperAVERAGE", "FLAG", true, "Config", { type = "Condition", var = "Combat" })
		end
	end },
	{ var = "buffBastionOfHope", type = "check", label = "Is Bastion of Hope active?", labelKey = "ui.config_options.module.buff_bastion_of_hope.label", ifCond = "BastionOfHopeActive", apply = function(val, modList, enemyModList)
		modList:NewMod("Condition:BastionOfHopeActive", "FLAG", true, "Config", { type = "Condition", var = "Combat" })
	end },
	{ var = "buffNgamahuFlamesAdvance", type = "check", label = "Is Magmatic Strikes active?", labelKey = "ui.config_options.module.buff_ngamahu_flames_advance.label", ifCond = "NgamahuFlamesAdvance", apply = function(val, modList, enemyModList)
		modList:NewMod("Condition:NgamahuFlamesAdvance", "FLAG", true, "Config", { type = "Condition", var = "Combat" })
	end },
	{ var = "buffHerEmbrace", type = "check", label = "Are you in Her Embrace?", labelKey = "ui.config_options.module.buff_her_embrace.label", ifCond = "HerEmbrace", tooltip = "This option is specific to Oni-Goroshi.", tooltipKey = "ui.config_options.module.buff_her_embrace.tooltip", apply = function(val, modList, enemyModList)
		modList:NewMod("HerEmbrace", "FLAG", true, "Config", { type = "Condition", var = "Combat" }, { type = "Condition", var = "CanGainHerEmbrace" })
	end },
	{ var = "conditionChampionIntimidate", type = "check", label = "Is Champion's Intimidate active?", labelKey = "ui.config_options.module.condition_champion_intimidate.label", ifEnemyCond = "ChampionIntimidate", defaultState = true, apply = function(val, modList, enemyModList)
		enemyModList:NewMod("Condition:ChampionIntimidate", "FLAG", true, "Config", { type = "Condition", var = "Combat" })
	end },
	{ var = "conditionUsedSkillRecently", type = "check", label = "Have you used a Skill Recently?", labelKey = "ui.config_options.module.condition_used_skill_recently.label", ifCond = "UsedSkillRecently", apply = function(val, modList, enemyModList)
		modList:NewMod("Condition:UsedSkillRecently", "FLAG", true, "Config", { type = "Condition", var = "Combat" })
	end },
	{ var = "multiplierSkillUsedRecently", type = "count", label = "# of Skills Used Recently:", labelKey = "ui.config_options.module.multiplier_skill_used_recently.label", ifMult = "SkillUsedRecently", implyCond = "UsedSkillRecently", apply = function(val, modList, enemyModList)
		modList:NewMod("Multiplier:SkillUsedRecently", "BASE", val, "Config", { type = "Condition", var = "Combat" })
		modList:NewMod("Condition:UsedSkillRecently", "FLAG", true, "Config", { type = "Condition", var = "Combat" })
	end },
	{ var = "conditionAttackedRecently", type = "check", label = "Have you Attacked Recently?", labelKey = "ui.config_options.module.condition_attacked_recently.label", ifCond = "AttackedRecently", implyCond = "UsedSkillRecently", tooltip = "This also implies that you have used a Skill Recently.\nYou will automatically be considered to have Attacked Recently if your main skill is an attack,\nbut you can use this option to force it if necessary.", tooltipKey = "ui.config_options.module.condition_attacked_recently.tooltip", apply = function(val, modList, enemyModList)
		modList:NewMod("Condition:AttackedRecently", "FLAG", true, "Config", { type = "Condition", var = "Combat" })
		modList:NewMod("Condition:UsedSkillRecently", "FLAG", true, "Config", { type = "Condition", var = "Combat" })
	end },
	{ var = "conditionCastSpellRecently", type = "check", label = "Have you Cast a Spell Recently?", labelKey = "ui.config_options.module.condition_cast_spell_recently.label", ifCond = "CastSpellRecently", implyCond = "UsedSkillRecently", tooltip = "This also implies that you have used a Skill Recently.\nYou will automatically be considered to have Cast a Spell Recently if your main skill is a spell,\nbut you can use this option to force it if necessary.", tooltipKey = "ui.config_options.module.condition_cast_spell_recently.tooltip", apply = function(val, modList, enemyModList)
		modList:NewMod("Condition:CastSpellRecently", "FLAG", true, "Config", { type = "Condition", var = "Combat" })
		modList:NewMod("Condition:UsedSkillRecently", "FLAG", true, "Config", { type = "Condition", var = "Combat" })
	end },
	{ var = "multiplierNonInstantSpellCastRecently", type = "count", label = "# of Non-Instant Spells Cast Recently:", labelKey = "ui.config_options.module.multiplier_non_instant_spell_cast_recently.label", ifMult = "NonInstantSpellCastRecently", implyCond = "CastSpellRecently", tooltip = "Only the number of different spells you cast count", tooltipKey = "ui.config_options.module.multiplier_non_instant_spell_cast_recently.tooltip", apply = function(val, modList, enemyModList)
		modList:NewMod("Multiplier:NonInstantSpellCastRecently", "BASE", val, "Config", { type = "Condition", var = "Combat" })
	end },
	{ var = "multiplierAppliedAilmentsRecently", type = "count", label = "# of Recently Applied Ailments:", labelKey = "ui.config_options.module.multiplier_applied_ailments_recently.label", ifMult = "AppliedAilmentsRecently", tooltip = "Number of recently applied ailments", tooltipKey = "ui.config_options.module.multiplier_applied_ailments_recently.tooltip", apply = function(val, modList, enemyModList)
		modList:NewMod("Multiplier:AppliedAilmentsRecently", "BASE", val, "Config", { type = "Condition", var = "Combat" })
	end },
	{ var = "conditionLinkedRecently", type = "check", label = "Have you Linked recently?", labelKey = "ui.config_options.module.condition_linked_recently.label", ifCond = "LinkedRecently", apply = function(val, modList, enemyModList)
		modList:NewMod("Condition:LinkedRecently", "FLAG", true, "Config")
	end },
	{ var = "conditionStunnedWhileCastingRecently", type = "check", label = "Stunned while Casting Recently?", labelKey = "ui.config_options.module.condition_stunned_while_casting_recently.label", ifCond = "StunnedWhileCastingRecently", apply = function(val, modList, enemyModList)
		modList:NewMod("Condition:StunnedWhileCastingRecently", "FLAG", true, "Config", { type = "Condition", var = "Combat" })
	end },
	{ var = "conditionCastLast1Seconds", type = "check", label = "Have you Cast a Spell in the last second?", labelKey = "ui.config_options.module.condition_cast_last1_seconds.label", ifCond = "CastLast1Seconds", implyCond = "CastSpellRecently", apply = function(val, modList, enemyModList)
		modList:NewMod("Condition:CastLast1Seconds", "FLAG", true, "Config", { type = "Condition", var = "Combat" })
	end },
	{ var = "multiplierCastLast8Seconds", type = "count", label = "How many spells cast in the last 8 seconds?", labelKey = "ui.config_options.module.multiplier_cast_last8_seconds.label", ifMult = "CastLast8Seconds", tooltip = "Only non-instant spells you cast count", tooltipKey = "ui.config_options.module.multiplier_cast_last8_seconds.tooltip", apply = function(val, modList, enemyModList)
		modList:NewMod("Multiplier:CastLast8Seconds", "BASE", val, "Config", { type = "Condition", var = "Combat" })
	end },
	{ var = "conditionSuppressedRecently", type = "check", label = "Have you Suppressed Recently?", labelKey = "ui.config_options.module.condition_suppressed_recently.label", ifCond = "SuppressedRecently", apply = function(val, modList, enemyModList)
		modList:NewMod("Condition:SuppressedRecently", "FLAG", true, "Config", { type = "Condition", var = "Combat" })
	end },
	{ var = "multiplierHitsSuppressedRecently", type = "count", label = "# of Hits Suppressed Recently:", labelKey = "ui.config_options.module.multiplier_hits_suppressed_recently.label", ifMult = "HitsSuppressedRecently", implyCond = "SuppressedRecently", tooltip = "This also implies that you have Suppressed Recently.", tooltipKey = "ui.config_options.module.multiplier_hits_suppressed_recently.tooltip", apply = function(val, modList, enemyModList)
		modList:NewMod("Multiplier:HitsSuppressedRecently", "BASE", val, "Config", { type = "Condition", var = "Combat" })
		modList:NewMod("Condition:SuppressedRecently", "FLAG", true, "Config", { type = "Condition", var = "Combat" })
	end },
	{ var = "conditionUsedFireSkillRecently", type = "check", label = "Have you used a ^xB97123Fire ^7Skill Recently?", labelKey = "ui.config_options.module.condition_used_fire_skill_recently.label", ifCond = "UsedFireSkillRecently", implyCond = "UsedSkillRecently", tooltip = "This also implies that you have used a Skill Recently.", tooltipKey = "ui.config_options.module.condition_used_fire_skill_recently.tooltip", apply = function(val, modList, enemyModList)
		modList:NewMod("Condition:UsedFireSkillRecently", "FLAG", true, "Config", { type = "Condition", var = "Combat" })
		modList:NewMod("Condition:UsedSkillRecently", "FLAG", true, "Config", { type = "Condition", var = "Combat" })
	end },
	{ var = "conditionUsedColdSkillRecently", type = "check", label = "Have you used a ^x3F6DB3Cold ^7Skill Recently?", labelKey = "ui.config_options.module.condition_used_cold_skill_recently.label", ifCond = "UsedColdSkillRecently", implyCond = "UsedSkillRecently", tooltip = "This also implies that you have used a Skill Recently.", tooltipKey = "ui.config_options.module.condition_used_fire_skill_recently.tooltip", apply = function(val, modList, enemyModList)
		modList:NewMod("Condition:UsedColdSkillRecently", "FLAG", true, "Config", { type = "Condition", var = "Combat" })
		modList:NewMod("Condition:UsedSkillRecently", "FLAG", true, "Config", { type = "Condition", var = "Combat" })
	end },
	{ var = "conditionUsedMinionSkillRecently", type = "check", label = "Have you used a Minion Skill Recently?", labelKey = "ui.config_options.module.condition_used_minion_skill_recently.label", ifCond = "UsedMinionSkillRecently", implyCond = "UsedSkillRecently", tooltip = "This also implies that you have used a Skill Recently.\nYou will automatically be considered to have used a Minion skill Recently if your main skill is a Minion skill,\nbut you can use this option to force it if necessary.", tooltipKey = "ui.config_options.module.condition_used_minion_skill_recently.tooltip", apply = function(val, modList, enemyModList)
		modList:NewMod("Condition:UsedMinionSkillRecently", "FLAG", true, "Config", { type = "Condition", var = "Combat" })
		modList:NewMod("Condition:UsedSkillRecently", "FLAG", true, "Config", { type = "Condition", var = "Combat" })
	end },
	{ var = "conditionUsedTravelSkillRecently", type = "check", label = "Have you used a Travel Skill Recently?", labelKey = "ui.config_options.module.condition_used_travel_skill_recently.label", ifCond = "UsedTravelSkillRecently", implyCond = "UsedSkillRecently", tooltip = "This also implies that you have used a Skill Recently..", tooltipKey = "ui.config_options.module.condition_used_travel_skill_recently.tooltip", apply = function(val, modList, enemyModList)
		modList:NewMod("Condition:UsedTravelSkillRecently", "FLAG", true, "Config", { type = "Condition", var = "Combat" })
		modList:NewMod("Condition:UsedMovementSkillRecently", "FLAG", true, "Config", { type = "Condition", var = "Combat" })
		modList:NewMod("Condition:UsedSkillRecently", "FLAG", true, "Config", { type = "Condition", var = "Combat" })
	end },
	{ var = "conditionUsedDashRecently", type = "check", label = "Have you cast Dash Recently?", labelKey = "ui.config_options.module.condition_used_dash_recently.label", ifCond = "CastDashRecently", implyCondList = { "UsedTravelSkillRecently", "UsedMovementSkillRecently", "UsedSkillRecently"}, tooltip = "This also implies that you have used a Skill Recently..", tooltipKey = "ui.config_options.module.condition_used_travel_skill_recently.tooltip", apply = function(val, modList, enemyModList)
		modList:NewMod("Condition:CastDashRecently", "FLAG", true, "Config", { type = "Condition", var = "Combat" })
		modList:NewMod("Condition:UsedTravelSkillRecently", "FLAG", true, "Config", { type = "Condition", var = "Combat" })
		modList:NewMod("Condition:UsedMovementSkillRecently", "FLAG", true, "Config", { type = "Condition", var = "Combat" })
		modList:NewMod("Condition:UsedSkillRecently", "FLAG", true, "Config", { type = "Condition", var = "Combat" })
	end },
	{ var = "conditionUsedMovementSkillRecently", type = "check", label = "Have you used a Movement Skill Recently?", labelKey = "ui.config_options.module.condition_used_movement_skill_recently.label", ifCond = "UsedMovementSkillRecently", implyCond = "UsedSkillRecently", tooltip = "This also implies that you have used a Skill Recently.\nYou will automatically be considered to have used a Movement skill Recently if your main skill is a movement skill,\nbut you can use this option to force it if necessary.", tooltipKey = "ui.config_options.module.condition_used_movement_skill_recently.tooltip", apply = function(val, modList, enemyModList)
		modList:NewMod("Condition:UsedMovementSkillRecently", "FLAG", true, "Config", { type = "Condition", var = "Combat" })
		modList:NewMod("Condition:UsedSkillRecently", "FLAG", true, "Config", { type = "Condition", var = "Combat" })
	end },
	{ var = "conditionUsedVaalSkillRecently", type = "check", label = "Have you used a Vaal Skill Recently?", labelKey = "ui.config_options.module.condition_used_vaal_skill_recently.label", ifCond = "UsedVaalSkillRecently", implyCond = "UsedSkillRecently", tooltip = "This also implies that you have used a Skill Recently.\nYou will automatically be considered to have used a Vaal skill Recently if your main skill is a Vaal skill,\nbut you can use this option to force it if necessary.", tooltipKey = "ui.config_options.module.condition_used_vaal_skill_recently.tooltip", apply = function(val, modList, enemyModList)
		modList:NewMod("Condition:UsedVaalSkillRecently", "FLAG", true, "Config", { type = "Condition", var = "Combat" })
		modList:NewMod("Condition:UsedSkillRecently", "FLAG", true, "Config", { type = "Condition", var = "Combat" })
	end },
	{ var = "conditionSoulGainPrevention", type = "check", label = "Do you have Soul Gain Prevention?", labelKey = "ui.config_options.module.condition_soul_gain_prevention.label", ifCond = "SoulGainPrevention", apply = function(val, modList, enemyModList)
		modList:NewMod("Condition:SoulGainPrevention", "FLAG", true, "Config", { type = "Condition", var = "Combat" })
	end },
	{ var = "conditionUsedWarcryRecently", type = "check", label = "Have you used a Warcry Recently?", labelKey = "ui.config_options.module.condition_used_warcry_recently.label", ifFlag = "warcry", implyCondList = {"UsedWarcryInPast8Seconds", "UsedSkillRecently"}, tooltip = "This also implies that you have used a Skill Recently.", tooltipKey = "ui.config_options.module.condition_used_fire_skill_recently.tooltip", apply = function(val, modList, enemyModList)
		modList:NewMod("Condition:UsedWarcryRecently", "FLAG", true, "Config", { type = "Condition", var = "Combat" })
		modList:NewMod("Condition:UsedWarcryInPast8Seconds", "FLAG", true, "Config", { type = "Condition", var = "Combat" })
		modList:NewMod("Condition:UsedSkillRecently", "FLAG", true, "Config", { type = "Condition", var = "Combat" })
	end },
	{ var = "multiplierWarcryUsedRecently", type = "count", label = "# of Warcries Used Recently:", labelKey = "ui.config_options.module.multiplier_warcry_used_recently.label", defaultPlaceholderState = 1, ifOption = "conditionUsedWarcryRecently", apply = function(val, modList, enemyModList)
		modList:NewMod("Multiplier:WarcryUsedRecently", "BASE", m_min(val, 100), "Config", { type = "Condition", var = "Combat" }, { type = "Condition", var = "UsedWarcryRecently" } )
	end },
	{ var = "conditionUsedWarcryInPast8Seconds", type = "check", label = "Used a Warcry in the past 8 seconds?", labelKey = "ui.config_options.module.condition_used_warcry_in_past8_seconds.label", ifCond = "UsedWarcryInPast8Seconds", apply = function(val, modList, enemyModList)
		modList:NewMod("Condition:UsedWarcryInPast8Seconds", "FLAG", true, "Config", { type = "Condition", var = "Combat" })
	end },
	{ var = "multiplierAffectedByWarcryBuffDuration", type = "count", label = "# of seconds Affected by a Warcry Buff:", labelKey = "ui.config_options.module.multiplier_affected_by_warcry_buff_duration.label", ifMult = "AffectedByWarcryBuffDuration", apply = function(val, modList, enemyModList)
		modList:NewMod("Multiplier:AffectedByWarcryBuffDuration", "BASE", val, "Config", { type = "Condition", var = "Combat" })
	end },
	{ var = "DetonatedMinesRecently", type = "check", label = "Have you Detonated a Mine Recently", labelKey = "ui.config_options.module.detonated_mines_recently.label", ifCond = "DetonatedMinesRecently", apply = function(val, modList, enemyModList)
		modList:NewMod("Condition:DetonatedMinesRecently", "FLAG", true, "Config", { type = "Condition", var = "Combat" })
	end },
	{ var = "multiplierMineDetonatedRecently", type = "count", label = "# of Mines Detonated Recently:", labelKey = "ui.config_options.module.multiplier_mine_detonated_recently.label", ifMult = "MineDetonatedRecently", implyCond = "DetonatedMinesRecently", apply = function(val, modList, enemyModList)
		modList:NewMod("Multiplier:MineDetonatedRecently", "BASE", val, "Config", { type = "Condition", var = "Combat" })
	end },
	{ var = "minesPerThrow", type = "count", label = "# of Mines per throw:", labelKey = "ui.config_options.module.mines_per_throw.label", ifFlag = "mine", tooltip = "This will override the number of Mines per throw", tooltipKey = "ui.config_options.module.mines_per_throw.tooltip", apply = function(val, modList, enemyModList)
		modList:NewMod("MineThrowCount", "OVERRIDE", val, "Config", {type = "Condition", var = "Combat"})
	end },
	{ var = "TriggeredTrapsRecently", type = "check", label = "Have you Triggered a Trap Recently?", labelKey = "ui.config_options.module.triggered_traps_recently.label", ifCond = "TriggeredTrapsRecently", apply = function(val, modList, enemyModList)
		modList:NewMod("Condition:TriggeredTrapsRecently", "FLAG", true, "Config", { type = "Condition", var = "Combat" })
	end },
	{ var = "multiplierTrapTriggeredRecently", type = "count", label = "# of Traps Triggered Recently:", labelKey = "ui.config_options.module.multiplier_trap_triggered_recently.label", ifMult = "TrapTriggeredRecently", implyCond = "TriggeredTrapRecently", apply = function(val, modList, enemyModList)
		modList:NewMod("Multiplier:TrapTriggeredRecently", "BASE", val, "Config", { type = "Condition", var = "Combat" })
	end },
	{ var = "conditionThrownTrapOrMineRecently", type = "check", label = "Have you thrown a Trap or Mine Recently?", labelKey = "ui.config_options.module.condition_thrown_trap_or_mine_recently.label", ifCond = "TrapOrMineThrownRecently", apply = function(val, modList, enemyModList)
		modList:NewMod("Condition:TrapOrMineThrownRecently", "FLAG", true, "Config", { type = "Condition", var = "Combat" })
	end },
	{ var = "trapsPerThrow", type = "count", label = "# of Traps per throw:", labelKey = "ui.config_options.module.traps_per_throw.label", ifFlag = "trap", tooltip = "This will override the number of Traps per throw", tooltipKey = "ui.config_options.module.traps_per_throw.tooltip", apply = function(val, modList, enemyModList)
		modList:NewMod("TrapThrowCount", "OVERRIDE", val, "Config", {type = "Condition", var = "Combat"})
	end },
	{ var = "conditionTriggeredSkillRecently", type = "check", label = "Have you Triggered a skill Recently?", labelKey = "ui.config_options.module.condition_triggered_skill_recently.label", ifSkillType = SkillType.Triggered, apply = function(val, modList, enemyModList)
		modList:NewMod("Condition:TriggeredSkillRecently", "FLAG", true, "Config", { type = "Condition", var = "Effective" })
	end },
	{ var = "conditionCursedEnemyRecently", type = "check", label = "Have you Cursed an enemy Recently?", labelKey = "ui.config_options.module.condition_cursed_enemy_recently.label",  ifCond="CursedEnemyRecently", apply = function(val, modList, enemyModList)
		modList:NewMod("Condition:CursedEnemyRecently", "FLAG", true, "Config", { type = "Condition", var = "Effective" })
	end },
	{ var = "conditionCastMarkRecently", type = "check", label = "Have you used a Mark Recently?", labelKey = "ui.config_options.module.condition_cast_mark_recently.label", ifCond = "CastMarkRecently", apply = function(val, modList, enemyModList)
		modList:NewMod("Condition:CastMarkRecently", "FLAG", true, "Config", { type = "Condition", var = "Combat" })
	end },
	{ var = "conditionSpawnedCorpseRecently", type = "check", label = "Spawned a corpse Recently?", labelKey = "ui.config_options.module.condition_spawned_corpse_recently.label", ifCond = "SpawnedCorpseRecently", apply = function(val, modList, enemyModList)
		modList:NewMod("Condition:SpawnedCorpseRecently", "FLAG", true, "Config", { type = "Condition", var = "Combat" })
	end },
	{ var = "conditionConsumedCorpseRecently", type = "check", label = "Consumed a corpse Recently?", labelKey = "ui.config_options.module.condition_consumed_corpse_recently.label", ifCond = "ConsumedCorpseRecently", apply = function(val, modList, enemyModList)
		modList:NewMod("Condition:ConsumedCorpseRecently", "FLAG", true, "Config", { type = "Condition", var = "Combat" })
	end },
	{ var = "conditionConsumedCorpseInPast2Sec", type = "check", label = "Consumed a corpse in the past 2s?", labelKey = "ui.config_options.module.condition_consumed_corpse_in_past2_sec.label", ifCond = "ConsumedCorpseInPast2Sec", implyCond = "ConsumedCorpseRecently",tooltip = "This also implies you have 'Consumed a corpse Recently'", tooltipKey = "ui.config_options.module.condition_consumed_corpse_in_past2_sec.tooltip", apply = function(val, modList, enemyModList)
		modList:NewMod("Condition:ConsumedCorpseInPast2Sec", "FLAG", true, "Config", { type = "Condition", var = "Combat" })
	end },
	{ var = "multiplierCorpseConsumedRecently", type = "count", label = "# of Corpses Consumed Recently:", labelKey = "ui.config_options.module.multiplier_corpse_consumed_recently.label", ifMult = "CorpseConsumedRecently", implyCond = "ConsumedCorpseRecently", apply = function(val, modList, enemyModList)
		modList:NewMod("Multiplier:CorpseConsumedRecently", "BASE", val, "Config", { type = "Condition", var = "Combat" })
		modList:NewMod("Condition:ConsumedCorpseRecently", "FLAG", true, "Config", { type = "Condition", var = "Combat" })
	end },
	{ var = "conditionRavenousCorpseConsumed", type = "check", label = "Has Ravenous consumed a corpse?", labelKey = "ui.config_options.module.condition_ravenous_corpse_consumed.label", ifSkill = "Ravenous", implyCond = "ConsumedCorpseRecently", tooltip = "Corpse must be the same type as the monster you're fighting.\nThis also implies you have 'Consumed a corpse Recently'", tooltipKey = "ui.config_options.module.condition_ravenous_corpse_consumed.tooltip", apply = function(val, modList, enemyModList)
		modList:NewMod("Condition:RavenousCorpseConsumed", "FLAG", true, "Config", { type = "Condition", var = "Combat" })
	end },
	{ var = "conditionTauntedEnemyRecently", type = "check", label = "Taunted an enemy Recently?", labelKey = "ui.config_options.module.condition_taunted_enemy_recently.label", ifCond = "TauntedEnemyRecently", apply = function(val, modList, enemyModList)
		modList:NewMod("Condition:TauntedEnemyRecently", "FLAG", true, "Config", { type = "Condition", var = "Combat" })
	end },
	{ var = "conditionReloadedRecently", type = "check", label = "Have you Reloaded Recently?", labelKey = "ui.config_options.module.condition_reloaded_recently.label", ifSkillType = SkillType.CrossbowAmmoSkill, apply = function(val, modList, enemyModList)
		modList:NewMod("Condition:ReloadedRecently", "FLAG", true, "Config", { type = "Condition", var = "Effective" })
	end },
	{ var = "conditionLostEnduranceChargeInPast8Sec", type = "check", label = "Lost an Endurance Charge in the past 8s?", labelKey = "ui.config_options.module.condition_lost_endurance_charge_in_past8_sec.label", ifCond = "LostEnduranceChargeInPast8Sec", apply = function(val, modList, enemyModList)
		modList:NewMod("Condition:LostEnduranceChargeInPast8Sec", "FLAG", true, "Config", { type = "Condition", var = "Combat" })
	end },
	{ var = "multiplierEnduranceChargesLostRecently", type = "count", label = "# of Endurance Charges lost Recently:", labelKey = "ui.config_options.module.multiplier_endurance_charges_lost_recently.label", ifMult = "EnduranceChargesLostRecently", implyCond = "LostEnduranceChargeInPast8Sec", apply = function(val, modList, enemyModList)
		modList:NewMod("Multiplier:EnduranceChargesLostRecently", "BASE", val, "Config", { type = "Condition", var = "Combat" })
		modList:NewMod("Condition:LostEnduranceChargeInPast8Sec", "FLAG", true, "Config", { type = "Condition", var = "Combat" })
	end },
	{ var = "conditionBlockedHitFromUniqueEnemyInPast10Sec", type = "check", label = "Blocked a Hit from a Unique enemy in the past 10s?", labelKey = "ui.config_options.module.condition_blocked_hit_from_unique_enemy_in_past10_sec.label", ifCond = "BlockedHitFromUniqueEnemyInPast10Sec", apply = function(val, modList, enemyModList)
		modList:NewMod("Condition:BlockedHitFromUniqueEnemyInPast10Sec", "FLAG", true, "Config", { type = "Condition", var = "Combat" })
	end },
	{ var = "conditionKilledUniqueEnemy", type = "check", label = "Killed a Rare or Unique enemy Recently?", labelKey = "ui.config_options.module.condition_killed_unique_enemy.label", ifCond = "KilledUniqueEnemy", apply = function(val, modList, enemyModList)
		modList:NewMod("Condition:KilledUniqueEnemy", "FLAG", true, "Config", { type = "Condition", var = "Combat" })
	end },
	{ var = "multiplierBlockedPast10Sec", type = "count", label = "Number of times you've Blocked in the past 10s", labelKey = "ui.config_options.module.multiplier_blocked_past10_sec.label", ifMult = "BlockedPast10Sec", apply = function(val, modList, enemyModList)
		modList:NewMod("Multiplier:BlockedPast10Sec", "BASE", val, "Config", { type = "Condition", var = "Combat" })
	end },
	{ var = "conditionImpaledRecently", type = "check", ifCond = "ImpaledRecently", label = "Impaled an enemy recently?", labelKey = "ui.config_options.module.condition_impaled_recently.label", apply = function(val, modList, enemyModLIst)
		modList:NewMod("Condition:ImpaledRecently", "FLAG", true, "Config", { type = "Condition", var = "Combat" })
	end },
	{ var = "multiplierImpalesOnEnemy", type = "countAllowZero", label = "# of Impales on enemy (if not maximum):", labelKey = "ui.config_options.module.multiplier_impales_on_enemy.label", ifFlag = "impale", apply = function(val, modList, enemyModList)
		enemyModList:NewMod("Multiplier:ImpaleStacks", "BASE", val, "Config", { type = "Condition", var = "Combat" })
	end },
	{ var = "multiplierFragileRegrowth", type = "count", label = "# of Fragile Regrowth Stacks:", labelKey = "ui.config_options.module.multiplier_fragile_regrowth.label", ifMult = "FragileRegrowthCount", apply = function(val, modList, enemyModList)
		modList:NewMod("Multiplier:FragileRegrowthCount", "BASE", m_min(val,10), "Config", { type = "Condition", var = "Combat" })
	end },
	{ var = "conditionHaveArborix", type = "check", label = "Do you have Iron Reflexes?", labelKey = "ui.config_options.module.condition_have_arborix.label", ifFlag = "Condition:HaveArborix", tooltip = "This option is specific to Arborix.", tooltipKey = "ui.config_options.module.condition_have_arborix.tooltip",apply = function(val, modList, enemyModList)
		modList:NewMod("Condition:HaveIronReflexes", "FLAG", true, "Config", { type = "Condition", var = "Combat" })
		modList:NewMod("Keystone", "LIST", "Iron Reflexes", "Config")
	end },
	{ var = "conditionHaveAugyre", type = "list", label = "Augyre rotating buff:", labelKey = "ui.config_options.module.condition_have_augyre.label", ifFlag = "Condition:HaveAugyre", list = {{val="EleOverload",label="Elemental Overload", labelKey = "ui.config_options.module.condition_have_augyre.label_2"},{val="ResTechnique",label="Resolute Technique", labelKey = "ui.config_options.module.condition_have_augyre.label_3"}}, tooltip = "This option is specific to Augyre.", tooltipKey = "ui.config_options.module.condition_have_augyre.tooltip", apply = function(val, modList, enemyModList)
		if val == "EleOverload" then
			modList:NewMod("Condition:HaveElementalOverload", "FLAG", true, "Config", { type = "Condition", var = "Combat" })
			modList:NewMod("Keystone", "LIST", "Elemental Overload", "Config")
		elseif val == "ResTechnique" then
			modList:NewMod("Condition:HaveResoluteTechnique", "FLAG", true, "Config", { type = "Condition", var = "Combat" })
			modList:NewMod("Keystone", "LIST", "Resolute Technique", "Config")
		end
	end },
	{ var = "conditionHaveVulconus", type = "check", label = "Do you have Avatar Of Fire?", labelKey = "ui.config_options.module.condition_have_vulconus.label", ifFlag = "Condition:HaveVulconus", tooltip = "This option is specific to Vulconus.", tooltipKey = "ui.config_options.module.condition_have_vulconus.tooltip", apply = function(val, modList, enemyModList)
		modList:NewMod("Condition:HaveAvatarOfFire", "FLAG", true, "Config", { type = "Condition", var = "Combat" })
		modList:NewMod("Keystone", "LIST", "Avatar of Fire", "Config")
	end },
	{ var = "conditionHaveManaStorm", type = "check", label = "Do you have Manastorm's Buff?", labelKey = "ui.config_options.module.condition_have_mana_storm.label", ifFlag = "Condition:HaveManaStorm", tooltip = "This option enables Manastorm's ^xADAA47Lightning ^7Damage Buff.\n(When you cast a Spell, Sacrifice all ^x7070FFMana ^7to gain Added Maximum ^xADAA47Lightning ^7Damage\nequal to 50% of Sacrificed ^x7070FFMana ^7for 4 seconds)", tooltipKey = "ui.config_options.module.condition_have_mana_storm.tooltip", apply = function(val, modList, enemyModList)
		modList:NewMod("Condition:SacrificeManaForLightning", "FLAG", true, "Config", { type = "Condition", var = "Combat" })
	end },
	{ var = "GamblesprintMovementSpeed", type = "list", label = "Gamblesprint Movement Speed", labelKey = "ui.config_options.module.gamblesprint_movement_speed.label", defaultIndex=3, list={{val=0,label="0%"},{val=10,label="10%"},{val=20,label="20%"},{val=30,label="30%"},{val=40,label="40%"}}, ifFlag = "Condition:HaveGamblesprint", tooltip = "This option sets the Movement Speed from Gamblesprint boots.", tooltipKey = "ui.config_options.module.gamblesprint_movement_speed.tooltip", apply = function(val, modList, enemyModList)
		modList:NewMod("MovementSpeed", "INC", val, "Config", { type = "Condition", var = "Combat" }, { type = "Condition", var = "HaveGamblesprint" })
	end },
	{ var = "EverlastingSacrifice", type = "check", label = "Do you have Everlasting Sacrifice?", labelKey = "ui.config_options.module.everlasting_sacrifice.label", ifFlag = "Condition:EverlastingSacrifice", tooltip = "This option enables the Everlasting Sacrifice buff that grants +5% to all maximum resists.", tooltipKey = "ui.config_options.module.everlasting_sacrifice.tooltip", apply = function(val, modList , enemyModList)
		modList:NewMod("ElementalResistMax", "BASE", 5, "Config", { type = "Condition", var = "Combat" }, { type = "Condition", var = "EverlastingSacrifice"})
		modList:NewMod("ChaosResistMax", "BASE", 5, "Config", { type = "Condition", var = "Combat" }, { type = "Condition", var = "EverlastingSacrifice"})
	end },
	{ var = "buffFanaticism", type = "check", label = "Do you have Fanaticism?", labelKey = "ui.config_options.module.buff_fanaticism.label", ifFlag = "Condition:CanGainFanaticism", tooltip = "This will enable the Fanaticism buff itself. (Grants 75% more cast speed, reduced skill cost, and increased area of effect)", tooltipKey = "ui.config_options.module.buff_fanaticism.tooltip", apply = function(val, modList, enemyModList)
		modList:NewMod("Condition:Fanaticism", "FLAG", true, "Config", { type = "Condition", var = "Combat" }, { type = "Condition", var = "CanGainFanaticism" })
	end },
	{ var = "conditionHitsAlwaysStun", type = "check", label = "Do your hits always Stun?", labelKey = "ui.config_options.module.condition_hits_always_stun.label", ifCond = "AlwaysStunning", apply = function(val, modList, enemyModList)
		modList:NewMod("Condition:AlwaysStunning", "FLAG", true, "Config", { type = "Condition", var = "Combat" })
	end },
	{ var = "conditionHitsAlwaysHeavyStun", type = "check", label = "Do your hits always Heavy Stun?", labelKey = "ui.config_options.module.condition_hits_always_heavy_stun.label", ifCond = "AlwaysHeavyStunning", apply = function(val, modList, enemyModList)
		modList:NewMod("Condition:AlwaysHeavyStunning", "FLAG", true, "Config", { type = "Condition", var = "Combat" })
	end },
	{ var = "multiplierPvpTvalueOverride", type = "count", label = "PvP Tvalue override (ms):", labelKey = "ui.config_options.module.multiplier_pvp_tvalue_override.label", ifFlag = "isPvP", tooltip = "Tvalue in milliseconds. This overrides the Tvalue of a given skill, for instance any with fixed Tvalues, or modified Tvalues", tooltipKey = "ui.config_options.module.multiplier_pvp_tvalue_override.tooltip", apply = function(val, modList, enemyModList)
		modList:NewMod("MultiplierPvpTvalueOverride", "BASE", val, "Config", { type = "Condition", var = "Combat" })
	end },
	{ var = "multiplierPvpDamage", type = "count", label = "Custom PvP Damage multiplier percent:", labelKey = "ui.config_options.module.multiplier_pvp_damage.label", ifFlag = "isPvP", tooltip = "This multiplies the damage of a given skill in pvp, for instance any with damage multiplier specific to pvp (from skill or support or item like sire of shards)", tooltipKey = "ui.config_options.module.multiplier_pvp_damage.tooltip", apply = function(val, modList, enemyModList)
		modList:NewMod("PvpDamageMultiplier", "MORE", val - 100, "Config")
	end },
	{ var = "reservedDarkness", type = "count", label = "Reserved Darkness:", labelKey = "ui.config_options.module.reserved_darkness.label", ifFlag = "PlayerHasDarkness", apply = function(val, modList, enemyModList)
		modList:NewMod("ReservedDarkness", "BASE", val, "Config")
	end },
	{ var = "multiplierHazardsTriggeredRecently", type = "count", label = "# of Hazards triggered recently:", labelKey = "ui.config_options.module.multiplier_hazards_triggered_recently.label", ifMult = "HazardsTriggeredRecently", ifFlag = "CanCreateHazards", apply = function(val, modList, enemyModList)
		modList:NewMod("Multiplier:HazardsTriggeredRecently", "BASE", m_max(val,0), "Config", { type = "Condition", var = "Combat" })
	end },
	-- Section: Effective DPS options
	{ section = "For Effective DPS", sectionKey = "ui.config_options.module.config_settings.section_3", col = 1 },
	{ var = "enemyDistance", type = "count", label = "Distance to enemy:", labelKey = "ui.config_options.module.enemy_distance.label", tooltip = "10 units equals 1 metre\nPlayer and Minion Attacks incur an Accuracy penalty based on distance from the origin of the damage to the target,\nwith no penalty for targets within 2 metres and up to 90% less Accuracy for targets further than 12 metres away-", tooltipKey = "ui.config_options.module.enemy_distance.tooltip", defaultPlaceholderState = 20, apply = function(val, modList, enemyModList)
		modList:NewMod("Multiplier:enemyDistance", "BASE", val, "Config", { type = "Condition", var = "Effective" })
	end },
	{ var = "skillForkCount", type = "count", label = "# of times Skill has Forked:", labelKey = "ui.config_options.module.skill_fork_count.label", ifFlag = "forking", apply = function(val, modList, enemyModList)
		modList:NewMod("ForkedCount", "BASE", val, "Config", { type = "Condition", var = "Effective" })
	end },
	{ var = "skillChainCount", type = "count", label = "# of times Skill has Chained:", labelKey = "ui.config_options.module.skill_chain_count.label", ifStat = { "Chain", "ChainRemaining" }, ifFlag = "chaining", apply = function(val, modList, enemyModList)
		modList:NewMod("ChainCount", "BASE", val, "Config", { type = "Condition", var = "Effective" })
	end },
	{ var = "skillPierceCount", type = "count", label = "# of times Skill has Pierced:", labelKey = "ui.config_options.module.skill_pierce_count.label", ifStat = "PiercedCount", ifFlag = "piercing", apply = function(val, modList, enemyModList)
		modList:NewMod("PiercedCount", "BASE", val, "Config", { type = "Condition", var = "Effective" })
	end },
	{ var = "multiplierBoltsReloadedPer6Seconds", type = "countAllowZero", label = "# bolts reloaded past 6 seconds", labelKey = "ui.config_options.module.multiplier_bolts_reloaded_per6_seconds.label", tooltip = "Override number of bolts reloaded in the past 6 seconds.\nUsed to calculate damage bonus from Fresh Clip I support.\nAssumes calculated average if no value is specified.", tooltipKey = "ui.config_options.module.multiplier_bolts_reloaded_per6_seconds.tooltip", ifSkill = "Fresh Clip I", apply = function(val, modList, enemyModList)
		modList:NewMod("Multiplier:BoltsReloadedPastSixSeconds", "OVERRIDE", val, "Config", { type = "Condition", var = "Effective" })
	end },
	{ var = "multiplierBoltsReloadedPer8Seconds", type = "countAllowZero", label = "# bolts reloaded past 8 seconds", labelKey = "ui.config_options.module.multiplier_bolts_reloaded_per8_seconds.label", tooltip = "Override number of bolts reloaded in the past 8 seconds.\nUsed to calculate damage bonus from Fresh Clip II support.\nAssumes calculated average if no value is specified.", tooltipKey = "ui.config_options.module.multiplier_bolts_reloaded_per8_seconds.tooltip", ifSkill = "Fresh Clip II", apply = function(val, modList, enemyModList)
		modList:NewMod("Multiplier:BoltsReloadedPastEightSeconds", "OVERRIDE", val, "Config", { type = "Condition", var = "Effective" })
	end },
	{ var = "multiplierDifferentAmmoFired", type = "count", label = "# different Ammo Types Shot past 10s", labelKey = "ui.config_options.module.multiplier_different_ammo_fired.label", tooltip = "Number of different Ammunition types used in tha past 10s", tooltipKey = "ui.config_options.module.multiplier_different_ammo_fired.tooltip", ifMult = "DifferentAmmoFired", defaultPlaceholderState = 1, apply = function(val, modList, enemyModList)
		modList:NewMod("Multiplier:DifferentAmmoFired", "BASE", val, "Config", { type = "Condition", var = "Effective" })
	end },
	{ var = "multiplierDifferentGrenadeFired", type = "count", label = "# different Grenade Types Shot past 10s", labelKey = "ui.config_options.module.multiplier_different_grenade_fired.label", tooltip = "Number of different Grenade types used in tha past 10s", tooltipKey = "ui.config_options.module.multiplier_different_grenade_fired.tooltip", ifMult = "DifferentGrenadeFired", defaultPlaceholderState = 1, apply = function(val, modList, enemyModList)
		modList:NewMod("Multiplier:DifferentGrenadeFired", "BASE", val, "Config", { type = "Condition", var = "Effective" })
	end },
	{ var = "conditionAtCloseRange", type = "check", label = "Is the enemy at Close Range?", labelKey = "ui.config_options.module.condition_at_close_range.label", ifCond = "AtCloseRange", apply = function(val, modList, enemyModList)
		modList:NewMod("Condition:AtCloseRange", "FLAG", true, "Config", { type = "Condition", var = "Effective" })
	end },
	{ var = "enemyMultiplierEnemyPresenceSeconds", type = "count", label = "Enemy in Your Presence Duration", labelKey = "ui.config_options.module.enemy_multiplier_enemy_presence_seconds.label", tooltip = "Number of seconds the enemy has been in your presence.", tooltipKey = "ui.config_options.module.enemy_multiplier_enemy_presence_seconds.tooltip", ifEnemyMult = "EnemyPresenceSeconds", apply = function(val, modList, enemyModList)
		enemyModList:NewMod("Multiplier:EnemyPresenceSeconds", "BASE", val, "Config", { type = "Condition", var = "Effective" })
	end },
	{ var = "conditionEnemyExitedPresenceRecently", type = "check", label = "Enemy exited Presence Recently?", labelKey = "ui.config_options.module.condition_enemy_exited_presence_recently.label_2", ifEnemyCond = "ExitedPresenceRecently", tooltip = "Enemy has exited your Presence recently", tooltipKey = "ui.config_options.module.condition_enemy_exited_presence_recently.tooltip_2", apply = function(val, modList, enemyModList)
		enemyModList:NewMod("Condition:ExitedPresenceRecently", "FLAG", true, "Config", { type = "Condition", var = "Effective" })
	end },
	{ var = "conditionEnemyExitedPresenceRecently", type = "check", label = "Enemy entered Presence Recently?", labelKey = "ui.config_options.module.condition_enemy_exited_presence_recently.label", ifEnemyCond = "EnteredPresenceRecently", tooltip = "Enemy has entered your Presence recently", tooltipKey = "ui.config_options.module.condition_enemy_exited_presence_recently.tooltip", apply = function(val, modList, enemyModList)
		enemyModList:NewMod("Condition:EnteredPresenceRecently", "FLAG", true, "Config", { type = "Condition", var = "Effective" })
	end },
	{ var = "conditionEnemyMoving", type = "check", label = "Is the enemy Moving?", labelKey = "ui.config_options.module.condition_enemy_moving.label", ifMod = "BleedChance", tooltip = "Bleeding deals an extra 100% damage while the target is moving, or if the Bleeding is Aggravated", tooltipKey = "ui.config_options.module.condition_enemy_moving.tooltip", apply = function(val, modList, enemyModList)
		enemyModList:NewMod("Condition:Moving", "FLAG", true, "Config", { type = "Condition", var = "Effective" })
	end },
	{ var = "conditionBleedAggravated", type = "check", label = "Is the Bleed Aggravated?", labelKey = "ui.config_options.module.condition_bleed_aggravated.label", ifMod = "BleedChance", tooltip = "Bleeding deals an extra 100% damage while the target is moving, or if the Bleeding is Aggravated", tooltipKey = "ui.config_options.module.condition_enemy_moving.tooltip", apply = function(val, modList, enemyModList)
		enemyModList:NewMod("Condition:BleedAggravated", "FLAG", true, "Config", { type = "Condition", var = "Effective" })
	end },
	{ var = "conditionEnemyFullLife", type = "check", label = "Is the enemy on Full ^xE05030Life?", labelKey = "ui.config_options.module.condition_enemy_full_life.label", ifEnemyCond = "FullLife", apply = function(val, modList, enemyModList)
		enemyModList:NewMod("Condition:FullLife", "FLAG", true, "Config", { type = "Condition", var = "Effective" })
	end },
	{ var = "conditionEnemyLowLife", type = "check", label = "Is the enemy on Low ^xE05030Life?", labelKey = "ui.config_options.module.condition_enemy_low_life.label", ifEnemyCond = "LowLife", apply = function(val, modList, enemyModList)
		enemyModList:NewMod("Condition:LowLife", "FLAG", true, "Config", { type = "Condition", var = "Effective" })
	end },
	{ var = "conditionEnemyArmourBroken", type = "check", label = "Is enemy Armour Broken?", labelKey = "ui.config_options.module.condition_enemy_armour_broken.label", ifFlag = "Condition:CanArmourBreak", tooltip = "Some Skills, Items, Support Gems and other effects can Break Armour, which lowers a target's Armour by a specified amount.\nIf this brings the target's Armour value to 0, their Armour is Fully Broken for 12 seconds.", tooltipKey = "ui.config_options.module.condition_enemy_armour_broken.tooltip", apply = function(val, modList, enemyModList)
		enemyModList:NewMod("Condition:ArmourFullyBroken", "FLAG", true, "ArmourBreak", { type = "Condition", var = "Effective" })
		enemyModList:NewMod("Condition:ArmourBrokenBelowZeroMax", "FLAG", true, "ArmourBreak", { type = "Condition", var = "Effective" }, { type = "ActorCondition", actor = "enemy", var = "CanArmourBreakBelowZero" })
		enemyModList:NewMod("Armour", "OVERRIDE", 0, "ArmourBreak", { type = "Condition", var = "ArmourFullyBroken" }, { type = "GlobalEffect", effectType= "Debuff", effectName = "ArmourBreak" }, { type = "ActorCondition", actor = "enemy", var = "CanArmourBreakBelowZero", neg = true })
	end },
	{ var = "multiplierArmourBreak", type = "count", label = "# of Broken Armour (if not maximum):", labelKey = "ui.config_options.module.multiplier_armour_break.label", ifOption = "conditionEnemyArmourBroken", tooltip = "Use this field to set a custom Armour Break value.\nIf left empty or set to 0, Fully Broken Armour will be assumed.\nArmour cannot be broken below 0 unless stated otherwise.\nIf so, Armour can be broken up to the inverse of its original value.", tooltipKey = "ui.config_options.module.multiplier_armour_break.tooltip", apply = function(val, modList, enemyModList)
		enemyModList:NewMod("Condition:ArmourBroken", "FLAG", val > 0, "ArmourBreak", { type = "Condition", var = "Effective" }) -- only activate if value > 0 is entered
		enemyModList:ReplaceMod("Condition:ArmourFullyBroken", "FLAG", val < 1, "ArmourBreak", { type = "Condition", var = "Effective" }, { type = "ActorCondition", actor = "enemy", var = "CanArmourBreakBelowZero", neg = true }) -- disable FullyBrokenArmour if value >= 1 is entered
		enemyModList:ReplaceMod("Condition:ArmourBrokenBelowZeroMax", "FLAG", val < 1, "ArmourBreak", { type = "Condition", var = "Effective" }, { type = "ActorCondition", actor = "enemy", var = "CanArmourBreakBelowZero" })
		enemyModList:NewMod("Multiplier:ArmourBreakStack", "BASE", val, "ArmourBreak", { type = "Condition", var = "ArmourBroken" })
		enemyModList:NewMod("Armour", "BASE", -1, "ArmourBreak", { type = "Multiplier", var = "ArmourBreakStack" }, { type = "GlobalEffect", effectType= "Debuff", effectName = "ArmourBreak" })
	end },
	{ var = "conditionEnemyCursed", type = "check", label = "Is the enemy Cursed?", labelKey = "ui.config_options.module.condition_enemy_cursed.label", ifEnemyCond = "Cursed", tooltip = "The enemy will automatically be considered to be Cursed if you have at least one curse enabled,\nbut you can use this option to force it if necessary.", tooltipKey = "ui.config_options.module.condition_enemy_cursed.tooltip", apply = function(val, modList, enemyModList)
		enemyModList:NewMod("Condition:Cursed", "FLAG", true, "Config", { type = "Condition", var = "Effective" })
	end },
	{ var = "conditionEnemyDazed", type = "check", label = "Is the enemy Dazed?", labelKey = "ui.config_options.module.condition_enemy_dazed.label", tooltip ="Dazed enemies take 50% more stun buildup for 8 seconds.", tooltipKey = "ui.config_options.module.condition_enemy_dazed.tooltip", apply = function(val, modList, enemyModList)
		enemyModList:NewMod("Condition:Dazed", "FLAG", true, "Config", { type = "Condition", var = "Effective" })
	end },
	{ var = "conditionEnemyStunned", type = "check", label = "Is the enemy Stunned?", labelKey = "ui.config_options.module.condition_enemy_stunned.label", ifEnemyCond = "Stunned", apply = function(val, modList, enemyModList)
		enemyModList:NewMod("Condition:Stunned", "FLAG", true, "Config", { type = "Condition", var = "Effective" })
	end },
	{ var = "conditionEnemyHeavyStunned", type = "check", label = "Is the enemy Heavy Stunned?", labelKey = "ui.config_options.module.condition_enemy_heavy_stunned.label", ifEnemyCond = "HeavyStunned", tooltip = "This also implies that the enemy is stunned.", tooltipKey = "ui.config_options.module.condition_enemy_heavy_stunned.tooltip", apply = function(val, modList, enemyModList)
		enemyModList:NewMod("Condition:HeavyStunned", "FLAG", true, "Config", { type = "Condition", var = "Effective" })
		enemyModList:NewMod("Condition:Stunned", "FLAG", true, "Config", { type = "Condition", var = "Effective" })
		enemyModList:NewMod("Condition:Immobilised", "FLAG", true, "Config", { type = "Condition", var = "Effective" })
	end },
	{ var = "conditionEnemyBleeding", type = "check", label = "Is the enemy Bleeding?", labelKey = "ui.config_options.module.condition_enemy_bleeding.label", ifEnemyCond = "Bleeding", apply = function(val, modList, enemyModList)
		enemyModList:NewMod("Condition:Bleeding", "FLAG", true, "Config", { type = "Condition", var = "Effective" })
	end },
	{ var = "multiplierBleedsOnEnemy", type = "count", label = "# of Bleeds on enemy (if not average):", labelKey = "ui.config_options.module.multiplier_bleeds_on_enemy.label", ifFlag = "BleedCanStack", implyCond = "Bleeding", apply = function(val, modList, enemyModList)
		enemyModList:NewMod("Multiplier:BleedStacks", "BASE", val, "Config", { type = "Condition", var = "Combat" })
	end },
	{ var = "multiplierRuptureStacks", type = "count", label = "# of Rupture stacks?", labelKey = "ui.config_options.module.multiplier_rupture_stacks.label", ifFlag = "Condition:CanInflictRupture", tooltip = "Rupture applies more bleed damage and faster bleeds for 3 seconds, up to 3 stacks", tooltipKey = "ui.config_options.module.multiplier_rupture_stacks.tooltip", apply = function(val, modList, enemyModList)
		enemyModList:NewMod("Multiplier:RuptureStack", "BASE", val, "Config", { type = "Condition", var = "Effective" })
	end },
	{ var = "multiplierIncisionStackCount", type = "count", label = "# of Incision Stacks:", labelKey = "ui.config_options.module.multiplier_incision_stack_count.label", ifFlag = "Condition:CanInflictIncision", tooltip = "Incision applies 10% chance to Bleed the enemy, up to 10 stacks.", tooltipKey = "ui.config_options.module.multiplier_incision_stack_count.tooltip", apply = function(val, modList, enemyModList)
		enemyModList:NewMod("Multiplier:IncisionStack", "BASE", m_min(val, 10), "Config", { type = "Condition", var = "Effective" })
	end },
	{ var = "multiplierFaerieFireStackCount", type = "count", label = "# of Faerie Fire Stacks:", labelKey = "ui.config_options.module.multiplier_faerie_fire_stack_count.label", ifFlag = "Condition:CanInflictFaerieFire", tooltip = "Each Faerie Fire Debuff causes Hits against the affected target to Gain 2% of damage as Extra Damage of a random Element.\nThe Debuff lasts 8 seconds, and up to 10 can be applied to each target.", tooltipKey = "ui.config_options.module.multiplier_faerie_fire_stack_count.tooltip", apply = function(val, modList, enemyModList)
		enemyModList:NewMod("Multiplier:FaerieFireStack", "BASE", m_min(val, 10), "Config", { type = "Condition", var = "Effective" })
	end },
	{ var = "conditionEnemyPoisoned", type = "check", label = "Is the enemy Poisoned?", labelKey = "ui.config_options.module.condition_enemy_poisoned.label", ifEnemyCond = "Poisoned", apply = function(val, modList, enemyModList)
		enemyModList:NewMod("Condition:Poisoned", "FLAG", true, "Config", { type = "Condition", var = "Effective" })
	end },
	{ var = "multiplierPoisonOnEnemy", type = "count", label = "# of Poisons on enemy (if not average):", labelKey = "ui.config_options.module.multiplier_poison_on_enemy.label", ifFlag = "PoisonCanStack", implyCond = "Poisoned", apply = function(val, modList, enemyModList)
		enemyModList:NewMod("Multiplier:PoisonStacks", "BASE", val, "Config", { type = "Condition", var = "Effective" })
	end },
	{ var = "multiplierCurseExpiredOnEnemy", type = "count", label = "#% of Curse Expired on enemy:", labelKey = "ui.config_options.module.multiplier_curse_expired_on_enemy.label", ifEnemyMult = "CurseExpired", apply = function(val, modList, enemyModList)
		enemyModList:NewMod("Multiplier:CurseExpired", "BASE", val, "Config", { type = "Condition", var = "Effective" })
	end },
	{ var = "multiplierCurseDurationExpiredOnEnemy", type = "count", label = "Curse Duration Expired on enemy:", labelKey = "ui.config_options.module.multiplier_curse_duration_expired_on_enemy.label", ifEnemyMult = "CurseDurationExpired", apply = function(val, modList, enemyModList)
		enemyModList:NewMod("Multiplier:CurseDurationExpired", "BASE", val, "Config", { type = "Condition", var = "Effective" })
	end },
	{ var = "multiplierWitheredStackCount", type = "count", label = "# of Withered Stacks:", labelKey = "ui.config_options.module.multiplier_withered_stack_count.label", ifFlag = "Condition:CanWither", tooltip = "Withered applies 5% increased ^xD02090Chaos ^7Damage Taken to the enemy, up to 10 stacks.", tooltipKey = "ui.config_options.module.multiplier_withered_stack_count.tooltip", apply = function(val, modList, enemyModList)
		enemyModList:NewMod("Multiplier:WitheredStack", "BASE", val, "Config", { type = "Condition", var = "Effective" })
	end },
	{ var = "multiplierCorrosionStackCount", type = "count", label = "# of Corrosion Stacks:", labelKey = "ui.config_options.module.multiplier_corrosion_stack_count.label", ifFlag = "Condition:CanCorrode", tooltip = "Each stack of Corrosion applies -5000 to total Armour and -1000 to total ^x33FF77Evasion Rating ^7to the enemy.\nCorrosion lasts 4 seconds and refreshes the duration of existing Corrosion stacks\nCorrosion has no stack limit", tooltipKey = "ui.config_options.module.multiplier_corrosion_stack_count.tooltip", apply = function(val, modList, enemyModList)
		enemyModList:NewMod("Multiplier:CorrosionStack", "BASE", val, "Config", { type = "Condition", var = "Effective" })
		enemyModList:NewMod("Armour", "BASE", -5000, "Corrosion", { type = "Multiplier", var = "CorrosionStack" }, { type = "ActorCondition", actor = "enemy", var = "CanCorrode" })
		enemyModList:NewMod("Evasion", "BASE", -1000, "Corrosion", { type = "Multiplier", var = "CorrosionStack" }, { type = "ActorCondition", actor = "enemy", var = "CanCorrode" })
	end },
	{ var = "multiplierEnsnaredStackCount", type = "count", label = "# of Ensnare Stacks:", labelKey = "ui.config_options.module.multiplier_ensnared_stack_count.label", ifSkill = "Ensnaring Arrow", tooltip = "While ensnared, enemies take increased Projectile Damage from Attack Hits\nEnsnared enemies always count as moving, and have less movement speed while trying to break the snare.", tooltipKey = "ui.config_options.module.multiplier_ensnared_stack_count.tooltip", apply = function(val, modList, enemyModList)
		modList:NewMod("Multiplier:EnsnareStackCount", "BASE", val, "Config", { type = "Condition", var = "Effective" })
		enemyModList:NewMod("Condition:Moving", "FLAG", true, "Config", { type = "MultiplierThreshold", actor = "enemy", var = "EnsnareStackCount", threshold = 1 })
	end },
	{ var = "conditionEnemyMaimed", type = "check", label = "Is the enemy Maimed?", labelKey = "ui.config_options.module.condition_enemy_maimed.label", tooltip = "In addition to allowing 'against Maimed Enemies' modifiers to apply,\n Maim applies the following effects.\n -30% Reduced Movement Speed \n -15% Reduced ^x33FF77Evasion", tooltipKey = "ui.config_options.module.condition_enemy_maimed.tooltip", apply = function(val, modList, enemyModList)
		enemyModList:NewMod("Condition:Maimed", "FLAG", true, "Config", { type = "Condition", var = "Effective" })
	end },
	{ var = "conditionEnemyHindered", type = "check", label = "Is the enemy Hindered?", labelKey = "ui.config_options.module.condition_enemy_hindered.label", ifEnemyCond = "Hindered", apply = function(val, modList, enemyModList)
		enemyModList:NewMod("Condition:Hindered", "FLAG", true, "Config", { type = "Condition", var = "Effective" })
	end },
	{ var = "conditionEnemyBlinded", type = "check", label = "Is the enemy Blinded?", labelKey = "ui.config_options.module.condition_enemy_blinded.label", tooltip = "In addition to allowing 'against Blinded Enemies' modifiers to apply,\n Blind applies the following effects.\n -20% Less Accuracy \n -20% Less ^x33FF77Evasion", tooltipKey = "ui.config_options.module.condition_enemy_blinded.tooltip", apply = function(val, modList, enemyModList)
		enemyModList:NewMod("Condition:Blinded", "FLAG", true, "Config", { type = "Condition", var = "Effective" })
	end },
	{ var = "overrideBuffBlinded", type = "count", label = "Effect of Blind (if not maximum):", labelKey = "ui.config_options.module.override_buff_blinded.label", ifOption = "conditionEnemyBlinded", tooltip = "If you have a guaranteed source of Blind, the strongest one will apply.", tooltipKey = "ui.config_options.module.override_buff_blinded.tooltip", apply = function(val, modList, enemyModList)
		enemyModList:NewMod("BlindEffect", "OVERRIDE", val, "Config", {type = "GlobalEffect", effectType = "Buff" })
	end },
	{ var = "conditionEnemyPinned", type = "check", label = "Is the enemy Pinned?", labelKey = "ui.config_options.module.condition_enemy_pinned.label", tooltip ="Pinned enemies cannot move and cannot evade 4 seconds.\n They are also Light Stunned when they become pinned.", tooltipKey = "ui.config_options.module.condition_enemy_pinned.tooltip", apply = function(val, modList, enemyModList)
		enemyModList:NewMod("Condition:Pinned", "FLAG", true, "Config", { type = "Condition", var = "Effective" })
		enemyModList:NewMod("Condition:Immobilised", "FLAG", true, "Config", { type = "Condition", var = "Effective" })
		enemyModList:NewMod("CannotEvade", "FLAG", true, "Config", { type = "Condition", var = "Effective" })
		enemyModList:NewMod("Condition:StunnedRecently", "FLAG", true, "Config", { type = "Condition", var = "Effective" })
	end },
	{ var = "conditionEnemyTaunted", type = "check", label = "Is the enemy Taunted?", labelKey = "ui.config_options.module.condition_enemy_taunted.label", ifEnemyCond = "Taunted", apply = function(val, modList, enemyModList)
		enemyModList:NewMod("Condition:Taunted", "FLAG", true, "Config", { type = "Condition", var = "Effective" })
	end },
	{ var = "conditionEnemyDebilitated", type = "check", label = "Is the enemy Debilitated?", labelKey = "ui.config_options.module.condition_enemy_debilitated.label", ifMod = "DebilitateChance", tooltip = "Debilitated enemies deal 10% less damage.", tooltipKey = "ui.config_options.module.condition_enemy_debilitated.tooltip", apply = function(val, modList, enemyModList)
		enemyModList:NewMod("Condition:Debilitated", "FLAG", true, "Config", { type = "Condition", var = "Effective" })
	end },
	{ var = "conditionEnemyImmobilised", type = "check", label = "Is the enemy Immobilised?", labelKey = "ui.config_options.module.condition_enemy_immobilised.label", ifEnemyCond = "Immobilised", tooltip = "A target is immobilised if it cannot move, for example due to being Frozen, Pinned, Heavy Stunned, or Electrocuted.", tooltipKey = "ui.config_options.module.condition_enemy_immobilised.tooltip", apply = function(val, modList, enemyModList)
		enemyModList:NewMod("Condition:Immobilised", "FLAG", true, "Config", { type = "Condition", var = "Effective" })
	end },
	{ var = "conditionEnemyPacified", type = "check", label = "Is the enemy Pacified?", labelKey = "ui.config_options.module.condition_enemy_pacified.label", ifSkill = "Pacify", tooltip = "Enemies are Pacified after 60% of Pacify's duration has expired", tooltipKey = "ui.config_options.module.condition_enemy_pacified.tooltip", apply = function(val, modList, enemyModList)
		enemyModList:NewMod("Condition:Pacified", "FLAG", true, "Config", { type = "Condition", var = "Effective" })
	end },
	{ var = "conditionEnemyAffectedByHazardRecently", type = "check", label = "Enemy affected by Hazard recently?", labelKey = "ui.config_options.module.condition_enemy_affected_by_hazard_recently.label", ifEnemyCond = "AffectedByHazardRecently", apply = function(val, modList, enemyModList)
		enemyModList:NewMod("Condition:AffectedByHazardRecently", "FLAG", true, "Config", { type = "Condition", var = "Effective" })
	end },
	{ var = "conditionEnemyBurning", type = "check", label = "Is the enemy ^xB97123Burning?", labelKey = "ui.config_options.module.condition_enemy_burning.label", ifEnemyCond = "Burning", apply = function(val, modList, enemyModList)
		enemyModList:NewMod("Condition:Burning", "FLAG", true, "Config", { type = "Condition", var = "Effective" })
	end },
	{ var = "conditionEnemyIgnited", type = "check", label = "Is the enemy ^xB97123Ignited?", labelKey = "ui.config_options.module.condition_enemy_ignited.label", ifEnemyCond = "Ignited", implyCond = "Burning", tooltip = "This also implies that the enemy is ^xB97123Burning.", tooltipKey = "ui.config_options.module.condition_enemy_ignited.tooltip", apply = function(val, modList, enemyModList)
		enemyModList:NewMod("Condition:Ignited", "FLAG", true, "Config", { type = "Condition", var = "Effective" })
	end },
	{ var = "multiplierIgniteOnEnemy", type = "count", label = "# of ^xB97123Ignites^7 on enemy (if not average):", labelKey = "ui.config_options.module.multiplier_ignite_on_enemy.label", ifFlag = "IgniteCanStack", implyCond = "Ignited", apply = function(val, modList, enemyModList)
		enemyModList:NewMod("Multiplier:IgniteStacks", "BASE", val, "Config", { type = "Condition", var = "Effective" })
	end },
	{ var = "conditionEnemyScorched", type = "check", ifFlag = "inflictScorch", label = "Is the enemy ^xB97123Scorched?", labelKey = "ui.config_options.module.condition_enemy_scorched.label", tooltip = "^xB97123Scorched ^7enemies have lowered elemental resistances, up to -30%.\nThis option will also allow you to input the effect of ^xB97123Scorched.", tooltipKey = "ui.config_options.module.condition_enemy_scorched.tooltip", apply = function(val, modList, enemyModList)
		enemyModList:NewMod("Condition:Scorched", "FLAG", true, "Config", { type = "Condition", var = "Effective" })
		enemyModList:NewMod("Condition:ScorchedConfig", "FLAG", true, "Config", { type = "Condition", var = "Effective" })
	end },
	{ var = "conditionScorchedEffect", type = "count", label = "Effect of ^xB97123Scorched:", labelKey = "ui.config_options.module.condition_scorched_effect.label", ifOption = "conditionEnemyScorched", tooltip = "This effect will only be applied while you can inflict ^xB97123Scorched.", tooltipKey = "ui.config_options.module.condition_scorched_effect.tooltip", apply = function(val, modList, enemyModList)
		enemyModList:NewMod("ScorchVal", "BASE", val, "Config", { type = "Condition", var = "ScorchedConfig" })
	end },
	{ var = "ScorchStacks", type = "countAllowZero", label = "^xB97123Scorch ^7Stacks", labelKey = "ui.config_options.module.scorch_stacks.label", ifFlag = "ScorchCanStack", ifOption = "conditionEnemyScorched", defaultPlaceholderState = 1, tooltip = "Amount of stacks of ^xB97123Scorch ^7applied to the enemy.", tooltipKey = "ui.config_options.module.scorch_stacks.tooltip", apply = function(val, modList, enemyModList)
		enemyModList:NewMod("Multiplier:ScorchStacks", "BASE", val, "Config", { type = "Condition", var = "Effective" })
	end },
	{ var = "conditionEnemyOnScorchedGround", type = "check", label = "Is the enemy on ^xB97123Scorched ^7Ground?", labelKey = "ui.config_options.module.condition_enemy_on_scorched_ground.label", tooltip = "This also implies that the enemy is ^xB97123Scorched.", tooltipKey = "ui.config_options.module.condition_enemy_on_scorched_ground.tooltip", ifEnemyCond = "OnScorchedGround", apply = function(val, modList, enemyModList)
		enemyModList:NewMod("Condition:Scorched", "FLAG", true, "Config", { type = "Condition", var = "Effective" })
		enemyModList:NewMod("Condition:OnScorchedGround", "FLAG", true, "Config", { type = "Condition", var = "Effective" })
	end },
	{ var = "conditionEnemyChilled", type = "check", label = "Is the enemy ^x3F6DB3Chilled?", labelKey = "ui.config_options.module.condition_enemy_chilled.label", apply = function(val, modList, enemyModList)
		enemyModList:NewMod("Condition:Chilled", "FLAG", true, "Config", { type = "Condition", var = "Effective" })
		enemyModList:NewMod("Condition:ChilledConfig", "FLAG", true, "Config", { type = "Condition", var = "Effective" })
	end },
	{ var = "multiplierChilledByYouSeconds", type = "count", label = "Seconds of chill on enemy?", labelKey = "ui.config_options.module.multiplier_chilled_by_you_seconds.label", ifEnemyCond = "ChilledByYou", apply = function(val, modList, enemyModList)
		enemyModList:NewMod("Multiplier:ChilledByYouSeconds", "BASE", val, "Config", { type = "Condition", var = "Combat" })
		enemyModList:NewMod("Condition:ChilledByYou", "FLAG", true, "Config", { type = "Condition", var = "Effective" })
	end },
	{ var = "conditionEnemyChilledEffect", type = "count", label = "Effect of ^x3F6DB3Chill:", labelKey = "ui.config_options.module.condition_chilled_effect.label", ifOption = "conditionEnemyChilled", apply = function(val, modList, enemyModList)
		enemyModList:NewMod("ChillVal", "BASE", val, "Chill", { type = "Condition", var = "ChilledConfig" })
	end },
	{ var = "ChillStacks", type = "count", label = "^xADAA47Chill ^7Stacks", labelKey = "ui.config_options.module.chill_stacks.label", ifFlag = "ChillCanStack", ifOption = "conditionEnemyChilled", defaultPlaceholderState = 1, tooltip = "Amount of stacks of ^xADAA47Chill ^7applied to the enemy.", tooltipKey = "ui.config_options.module.chill_stacks.tooltip", apply = function(val, modList, enemyModList)
		enemyModList:NewMod("Multiplier:ChillStacks", "BASE", val, "Config", { type = "Condition", var = "Effective" })
	end },
	{ var = "conditionEnemyChilledByYourHits", type = "check", ifEnemyCond = "ChilledByYourHits", label = "Is the enemy ^x3F6DB3Chilled ^7by your Hits?", labelKey = "ui.config_options.module.condition_enemy_chilled_by_your_hits.label", apply = function(val, modList, enemyModList)
		enemyModList:NewMod("Condition:Chilled", "FLAG", true, "Config", { type = "Condition", var = "Effective" })
		enemyModList:NewMod("Condition:ChilledByYourHits", "FLAG", true, "Config", { type = "Condition", var = "Effective" })
	end },
	{ var = "HoarfrostStacks", type = "count", label = "^x3F6DB3Hoarfrost ^7Stacks", labelKey = "ui.config_options.module.hoarfrost_stacks.label", ifFlag = "HitsCanInflictHoarfrost", tooltip = "Amount of stacks of ^x3F6DB3Hoarfrost ^7applied to the enemy.", tooltipKey = "ui.config_options.module.hoarfrost_stacks.tooltip", apply = function(val, modList, enemyModList)
		enemyModList:NewMod("HoarfrostFreezeDuration", "INC", val * 20, "Config", { type = "Condition", var = "Effective" })
	end },
	{ var = "conditionEnemyFrozen", type = "check", label = "Is the enemy ^x3F6DB3Frozen?", labelKey = "ui.config_options.module.condition_enemy_frozen.label", ifEnemyCond = "Frozen", apply = function(val, modList, enemyModList)
		enemyModList:NewMod("Condition:Frozen", "FLAG", true, "Config", { type = "Condition", var = "Effective" })
		enemyModList:NewMod("Condition:Immobilised", "FLAG", true, "Config", { type = "Condition", var = "Effective" })
	end },
	{ var = "multiplierFrozenByYouSeconds", type = "count", label = "Seconds of freeze on enemy?", labelKey = "ui.config_options.module.multiplier_frozen_by_you_seconds.label", ifEnemyCond = "FrozenByYou", apply = function(val, modList, enemyModList)
		enemyModList:NewMod("Multiplier:FrozenByYouSeconds", "BASE", val, "Config", { type = "Condition", var = "Combat" })
		enemyModList:NewMod("Condition:FrozenByYou", "FLAG", true, "Config", { type = "Condition", var = "Effective" })
	end },
	{ var = "conditionEnemyOnChilledGround", type = "check", label = "Is the enemy on ^x3F6DB3Chilled ^7Ground?", labelKey = "ui.config_options.module.condition_enemy_on_chilled_ground.label", ifEnemyCond = "OnChilledGround", implyCond = "Chilled", tooltip = "This also implies that the enemy is ^x3F6DB3Chilled.", tooltipKey = "ui.config_options.module.condition_enemy_on_chilled_ground.tooltip", apply = function(val, modList, enemyModList)
		enemyModList:NewMod("Condition:OnChilledGround", "FLAG", true, "Config", { type = "Condition", var = "Effective" })
		enemyModList:NewMod("Condition:Chilled", "FLAG", true, "Config", { type = "Condition", var = "Effective" })
	end },
	{ var = "conditionEnemyBrittle", type = "check", ifFlag = "inflictBrittle", label = "Is the enemy ^x3F6DB3Brittle?", labelKey = "ui.config_options.module.condition_enemy_brittle.label", tooltip = "Hits against ^x3F6DB3Brittle ^7enemies have up to +6% Critical Strike Chance.\nThis option will also allow you to input the effect of ^x3F6DB3Brittle.", tooltipKey = "ui.config_options.module.condition_enemy_brittle.tooltip", apply = function(val, modList, enemyModList)
		enemyModList:NewMod("Condition:Brittle", "FLAG", true, "Config", { type = "Condition", var = "Effective" })
		enemyModList:NewMod("Condition:BrittleConfig", "FLAG", true, "Config", { type = "Condition", var = "Effective" })
	end },
	{ var = "conditionBrittleEffect", type = "count", label = "Effect of ^x3F6DB3Brittle:", labelKey = "ui.config_options.module.condition_brittle_effect.label", ifOption = "conditionEnemyBrittle", tooltip = "This effect will only be applied while you can inflict ^x3F6DB3Brittle.", tooltipKey = "ui.config_options.module.condition_brittle_effect.tooltip", apply = function(val, modList, enemyModList)
		enemyModList:NewMod("BrittleVal", "BASE", val, "Config", { type = "Condition", var = "BrittleConfig" })
	end },
	{ var = "conditionEnemyOnBrittleGround", type = "check", label = "Is the enemy on ^xADAA47Brittle ^7Ground?", labelKey = "ui.config_options.module.condition_enemy_on_brittle_ground.label", tooltip = "This also implies that the enemy is ^xADAA47Brittle.", tooltipKey = "ui.config_options.module.condition_enemy_on_brittle_ground.tooltip", ifEnemyCond = "OnBrittleGround", apply = function(val, modList, enemyModList)
		enemyModList:NewMod("Condition:Brittle", "FLAG", true, "Config", { type = "Condition", var = "Effective" })
		enemyModList:NewMod("Condition:OnBrittleGround", "FLAG", true, "Config", { type = "Condition", var = "Effective" })
	end },
	{ var = "conditionEnemyShocked", type = "check", label = "Is the enemy ^xADAA47Shocked?", labelKey = "ui.config_options.module.condition_enemy_shocked.label", tooltip = "In addition to allowing any 'against ^xADAA47Shocked ^7Enemies' modifiers to apply,\nthis will allow you to input the effect of the ^xADAA47Shock ^7applied to the enemy.", tooltipKey = "ui.config_options.module.condition_enemy_shocked.tooltip", apply = function(val, modList, enemyModList)
		enemyModList:NewMod("Condition:Shocked", "FLAG", true, "Config", { type = "Condition", var = "Effective" })
		enemyModList:NewMod("Condition:ShockedConfig", "FLAG", true, "Config", { type = "Condition", var = "Effective" })
	end },
	{ var = "conditionShockEffect", type = "count", label = "Effect of ^xADAA47Shock^7 (if not maximum):", labelKey = "ui.config_options.module.condition_shock_effect.label", ifOption = "conditionEnemyShocked", tooltip = "If you have a guaranteed source of ^xADAA47Shock^7,\nthe strongest one will apply instead unless this option would apply a stronger ^xADAA47Shock.", tooltipKey = "ui.config_options.module.condition_shock_effect.tooltip", apply = function(val, modList, enemyModList)
		enemyModList:NewMod("ShockVal", "BASE", val, "Shock", { type = "Condition", var = "ShockedConfig" })
	end },
	{ var = "ShockStacks", type = "count", label = "^xADAA47Shock ^7Stacks", labelKey = "ui.config_options.module.shock_stacks.label", ifFlag = "ShockCanStack", ifOption = "conditionEnemyShocked", defaultPlaceholderState = 1, tooltip = "Amount of stacks of ^xADAA47Shock ^7applied to the enemy.", tooltipKey = "ui.config_options.module.shock_stacks.tooltip", apply = function(val, modList, enemyModList)
		enemyModList:NewMod("Multiplier:ShockStacks", "BASE", val, "Config", { type = "Condition", var = "Effective" })
	end },
	{ var = "conditionEnemyElectrocuted", type = "check", label = "Is the enemy ^xADAA47Electrocuted?", labelKey = "ui.config_options.module.condition_enemy_electrocuted.label", ifEnemyCond = "Electrocuted", apply = function(val, modList, enemyModList)
		enemyModList:NewMod("Condition:Electrocuted", "FLAG", true, "Config", { type = "Condition", var = "Effective" })
		enemyModList:NewMod("Condition:Immobilised", "FLAG", true, "Config", { type = "Condition", var = "Effective" })
	end },
	{ var = "conditionEnemyOnShockedGround", type = "check", label = "Is the enemy on ^xADAA47Shocked ^7Ground?", labelKey = "ui.config_options.module.condition_enemy_on_shocked_ground.label", tooltip = "This also implies that the enemy is ^xADAA47Shocked.", tooltipKey = "ui.config_options.module.condition_enemy_on_shocked_ground.tooltip", ifEnemyCond = "OnShockedGround", apply = function(val, modList, enemyModList)
		enemyModList:NewMod("Condition:Shocked", "FLAG", true, "Config", { type = "Condition", var = "Effective" })
		enemyModList:NewMod("Condition:OnShockedGround", "FLAG", true, "Config", { type = "Condition", var = "Effective" })
	end },
	{ var = "conditionEnemySapped", type = "check", ifFlag = "inflictSap", label = "Is the enemy ^xADAA47Sapped?", labelKey = "ui.config_options.module.condition_enemy_sapped.label", tooltip = "^xADAA47Sapped ^7enemies deal less damage, up to 20%.", tooltipKey = "ui.config_options.module.condition_enemy_sapped.tooltip", apply = function(val, modList, enemyModList)
		enemyModList:NewMod("Condition:Sapped", "FLAG", true, "Config", { type = "Condition", var = "Effective" })
		enemyModList:NewMod("Condition:SappedConfig", "FLAG", true, "Config", { type = "Condition", var = "Effective" })
	end },
	{ var = "conditionSapEffect", type = "count", label = "Effect of ^xADAA47Sap:", labelKey = "ui.config_options.module.condition_sap_effect.label", ifOption = "conditionEnemySapped", tooltip = "If you have a guaranteed source of ^xADAA47Sap^7,\nthe strongest one will apply instead unless this option would apply a stronger ^xADAA47Sap.", tooltipKey = "ui.config_options.module.condition_sap_effect.tooltip", apply = function(val, modList, enemyModList)
		enemyModList:NewMod("SapVal", "BASE", val, "Sap", { type = "Condition", var = "SappedConfig" })
	end },
	{ var = "conditionEnemyOnSappedGround", type = "check", label = "Is the enemy on ^xADAA47Sapped ^7Ground?", labelKey = "ui.config_options.module.condition_enemy_on_sapped_ground.label", tooltip = "This also implies that the enemy is ^xADAA47Sapped.", tooltipKey = "ui.config_options.module.condition_enemy_on_sapped_ground.tooltip", ifEnemyCond = "OnSappedGround", apply = function(val, modList, enemyModList)
		enemyModList:NewMod("Condition:Sapped", "FLAG", true, "Config", { type = "Condition", var = "Effective" })
		enemyModList:NewMod("Condition:OnSappedGround", "FLAG", true, "Config", { type = "Condition", var = "Effective" })
	end },
	{ var = "multiplierFreezeShockIgniteOnEnemy", type = "count", label = "# of ^x3F6DB3Freeze ^7/ ^xADAA47Shock ^7/ ^xB97123Ignite ^7on enemy:", labelKey = "ui.config_options.module.multiplier_freeze_shock_ignite_on_enemy.label", ifMult = "FreezeShockIgniteOnEnemy", apply = function(val, modList, enemyModList)
		modList:NewMod("Multiplier:FreezeShockIgniteOnEnemy", "BASE", val, "Config", { type = "Condition", var = "Effective" })
	end },
	{ var = "conditionEnemyFireExposure", type = "check", label = "Is the enemy Exposed to ^xB97123Fire?", labelKey = "ui.config_options.module.condition_enemy_fire_exposure.label", ifFlag = "Condition:CanApplyFireExposure", tooltip = "This applies -20% ^xB97123Fire Resistance ^7to the enemy.", tooltipKey = "ui.config_options.module.condition_enemy_fire_exposure.tooltip", apply = function(val, modList, enemyModList)
		enemyModList:NewMod("FireExposure", "BASE", 20, "Config", { type = "Condition", var = "Effective" }, { type = "ActorCondition", actor = "enemy", var = "CanApplyFireExposure" })
	end },
	{ var = "conditionEnemyColdExposure", type = "check", label = "Is the enemy Exposed to ^x3F6DB3Cold?", labelKey = "ui.config_options.module.condition_enemy_cold_exposure.label", ifFlag = "Condition:CanApplyColdExposure", tooltip = "This applies -20% ^x3F6DB3Cold Resistance ^7to the enemy.", tooltipKey = "ui.config_options.module.condition_enemy_cold_exposure.tooltip", apply = function(val, modList, enemyModList)
		enemyModList:NewMod("ColdExposure", "BASE", 20, "Config", { type = "Condition", var = "Effective" }, { type = "ActorCondition", actor = "enemy", var = "CanApplyColdExposure" })
	end },
	{ var = "conditionEnemyLightningExposure", type = "check", label = "Is the enemy Exposed to ^xADAA47Lightning?", labelKey = "ui.config_options.module.condition_enemy_lightning_exposure.label", ifFlag = "Condition:CanApplyLightningExposure", tooltip = "This applies -20% ^xADAA47Lightning Resistance ^7to the enemy.", tooltipKey = "ui.config_options.module.condition_enemy_lightning_exposure.tooltip", apply = function(val, modList, enemyModList)
		enemyModList:NewMod("LightningExposure", "BASE", 20, "Config", { type = "Condition", var = "Effective" }, { type = "ActorCondition", actor = "enemy", var = "CanApplyLightningExposure" })
	end },
	{ var = "conditionEnemyIsolated", type = "check", label = "Is the enemy Isolated?", labelKey = "ui.config_options.module.condition_enemy_isolated.label", ifEnemyCond = "Isolated", tooltip = "A target is Isolated if none of its allies are within 6m of it.", tooltipKey = "ui.config_options.module.condition_enemy_isolated.tooltip", apply = function(val, modList, enemyModList)
		enemyModList:NewMod("Condition:Isolated", "FLAG", true, "Config", { type = "Condition", var = "Effective" })
	end },
	{ var = "conditionEnemyIntimidated", type = "check", label = "Is the enemy Intimidated?", labelKey = "ui.config_options.module.condition_enemy_intimidated.label", tooltip = "Intimidate is a Debuff that inflicts 10% increased damage taken and 10% reduced damage dealt.", tooltipKey = "ui.config_options.module.condition_enemy_intimidated.tooltip", apply = function(val, modList, enemyModList)
		enemyModList:NewMod("Condition:Intimidated", "FLAG", true, "Config", { type = "Condition", var = "Effective" })
	end },
	{ var = "conditionEnemyCrushed", type = "check", label = "Is the enemy Crushed?", labelKey = "ui.config_options.module.condition_enemy_crushed.label", tooltip = "Crushed enemies have 15% reduced Physical Damage Reduction.", tooltipKey = "ui.config_options.module.condition_enemy_crushed.tooltip", apply = function(val, modList, enemyModList)
		enemyModList:NewMod("Condition:Crushed", "FLAG", true, "Config", { type = "Condition", var = "Effective" })
	end },
	{ var = "conditionNearLinkedTarget", type = "check", label = "Is the enemy near you Linked target?", labelKey = "ui.config_options.module.condition_near_linked_target.label", ifEnemyCond = "NearLinkedTarget", apply = function(val, modList, enemyModList)
		enemyModList:NewMod("Condition:NearLinkedTarget", "FLAG", true, "Config", { type = "Condition", var = "Effective" })
	end },
	{ var = "conditionEnemyUnnerved", type = "check", label = "Is the enemy Unnerved?", labelKey = "ui.config_options.module.condition_enemy_unnerved.label", tooltip = "Unnerved enemies take 10% increased Spell Damage.", tooltipKey = "ui.config_options.module.condition_enemy_unnerved.tooltip", apply = function(val, modList, enemyModList)
		enemyModList:NewMod("Condition:Unnerved", "FLAG", true, "Config", { type = "Condition", var = "Effective" })
	end },
	{ var = "conditionEnemyCriticalWeakness", type = "check", label = "Is the enemy Critically Weak", labelKey = "ui.config_options.module.condition_enemy_critical_weakness.label", ifFlag = "ApplyCriticalWeakness", tooltip = "Hits against Critically Weak enemies have up to +10% Critical Strike Chance.\nThis option will also allow you to input the effect of Critical Weakness.", tooltipKey = "ui.config_options.module.condition_enemy_critical_weakness.tooltip", apply = function(val, modList, enemyModList)
		enemyModList:NewMod("Condition:ApplyCriticalWeakness", "FLAG", val, "Config", { type = "Condition", var = "Effective" })
	end },
	{ var = "enemyCriticalWeaknessStacks", type = "count", label = "Critical weakness stacks:", labelKey = "ui.config_options.module.enemy_critical_weakness_stacks.label", ifOption = "conditionEnemyCriticalWeakness", tooltip = "Each stack of critical weakness applies +0.5% to critical strike chance against the affected target", tooltipKey = "ui.config_options.module.enemy_critical_weakness_stacks.tooltip", defaultPlaceholderState = 20, apply = function(val, modList, enemyModList)
		enemyModList:NewMod("SelfCritChance", "BASE", m_max(m_min(val or 20, 20), 0) / 2, "Critical Weakness", { type = "Condition", var = "ApplyCriticalWeakness" })
	end },
	{ var = "conditionEnemyCoveredInAsh", type = "check", label = "Is the enemy covered in Ash?", labelKey = "ui.config_options.module.condition_enemy_covered_in_ash.label", tooltip = "Covered in Ash applies the following to the enemy:\n\t20% increased ^xB97123Fire ^7Damage taken\n\t20% less Movement Speed", tooltipKey = "ui.config_options.module.condition_enemy_covered_in_ash.tooltip", apply = function(val, modList, enemyModList)
		modList:NewMod("CoveredInAshEffect", "BASE", 20, "Covered in Ash")
	end },
	{ var = "conditionEnemyCoveredInFrost", type = "check", label = "Is the enemy covered in Frost?", labelKey = "ui.config_options.module.condition_enemy_covered_in_frost.label", tooltip = "Covered in Frost applies the following to the enemy:\n\t20% increased ^x3F6DB3Cold ^7Damage taken\n\t50% less Critical Strike Chance", tooltipKey = "ui.config_options.module.condition_enemy_covered_in_frost.tooltip", apply = function(val, modList, enemyModList)
		modList:NewMod("CoveredInFrostEffect", "BASE", 20, "Covered in Frost")
	end },
	{ var = "conditionEnemyHasOpenWeakness", type = "check", label = "Does enemy have Open Weakness?", labelKey = "ui.config_options.module.condition_enemy_has_open_weakness.label", ifCond = "EnemyHasOpenWeakness", apply = function(val, modList, enemyModList)
		-- This one means the enemy you're targeting has open weakness
		modList:NewMod("Condition:EnemyHasOpenWeakness", "FLAG", true, "Config", { type = "Condition", var = "Combat" })
	end },
	{ var = "conditionOpenWeaknessEnemyPresence", type = "check", label = "Enemy Open Weakness Presence?", labelKey = "ui.config_options.module.condition_open_weakness_enemy_presence.label", ifCond = "OpenWeaknessEnemyPresence", apply = function(val, modList, enemyModList)
		-- This one means there's an enemy that has open weakness "nearby"
		modList:NewMod("Condition:OpenWeaknessEnemyPresence", "FLAG", true, "Config", { type = "Condition", var = "Combat" })
	end },
	{ var = "conditionEnemyOnConsecratedGround", type = "check", label = "Is the enemy on Consecrated Ground?", labelKey = "ui.config_options.module.condition_enemy_on_consecrated_ground.label", ifEnemyCond = "OnConsecratedGround", apply = function(val, modList, enemyModList)
		enemyModList:NewMod("Condition:OnConsecratedGround", "FLAG", true, "Config", { type = "Condition", var = "Effective" })
	end },
	{ var = "conditionEnemyHaveEnergyShield", type = "check", label = "Does the enemy have ^x88FFFFEnergy Shield^7?", labelKey = "ui.config_options.module.condition_enemy_have_energy_shield.label", ifEnemyCond = "HaveEnergyShield", apply = function(val, modList, enemyModList)
		enemyModList:NewMod("Condition:HaveEnergyShield", "FLAG", true, "Config", { type = "Condition", var = "Effective" })
	end },
	{ var = "conditionEnemyOnProfaneGround", type = "check", label = "Is the enemy on Profane Ground?", labelKey = "ui.config_options.module.condition_enemy_on_profane_ground.label", ifFlag = "Condition:CreateProfaneGround", tooltip = "Enemies on Profane Ground receive the following modifiers:\n\t10% increased Effect of Curses\n\t100% increased chance to be Critically Hit", tooltipKey = "ui.config_options.module.condition_enemy_on_profane_ground.tooltip", apply = function(val, modList, enemyModList)
		enemyModList:NewMod("Condition:OnProfaneGround", "FLAG", true, "Config", { type = "Condition", var = "Effective" })
		enemyModList:NewMod("CurseEffectOnSelf", "INC", 10, "Config", { type = "Condition", var = "OnProfaneGround" })
		enemyModList:NewMod("SelfCritChance", "INC", 100, "Config", { type = "Condition", var = "OnProfaneGround" })
	end },
	{ var = "multiplierEnemyAffectedByGraspingVines", type = "count", label = "# of Grasping Vines affecting enemy:", labelKey = "ui.config_options.module.multiplier_enemy_affected_by_grasping_vines.label", ifMult = "GraspingVinesAffectingEnemy", apply = function(val, modList, enemyModList)
		modList:NewMod("Multiplier:GraspingVinesAffectingEnemy", "BASE", val, "Config", { type = "Condition", var = "Effective" })
	end },
	{ var = "conditionEnemyOnFungalGround", type = "check", label = "Is the enemy on Fungal Ground?", labelKey = "ui.config_options.module.condition_enemy_on_fungal_ground.label", ifCond = { "OnFungalGround", "CreateFungalGround" }, tooltip = "Enemies on your Fungal Ground have -10% to all Resistances.", tooltipKey = "ui.config_options.module.condition_enemy_on_fungal_ground.tooltip", apply = function(val, modList, enemyModList)
		enemyModList:NewMod("Condition:OnFungalGround", "FLAG", true, "Config", { type = "Condition", var = "Effective" })
	end },
	{ var = "conditionEnemyInChillingArea", type = "check", label = "Is the enemy in a ^x3F6DB3Chilling ^7area?", labelKey = "ui.config_options.module.condition_enemy_in_chilling_area.label", ifEnemyCond = "InChillingArea", apply = function(val, modList, enemyModList)
		enemyModList:NewMod("Condition:InChillingArea", "FLAG", true, "Config", { type = "Condition", var = "Effective" })
	end },
	{ var = "conditionEnemyInFrostGlobe", type = "check", label = "Is the enemy in the Frost Shield area?", labelKey = "ui.config_options.module.condition_enemy_in_frost_globe.label", ifEnemyCond = "EnemyInFrostGlobe", apply = function(val, modList, enemyModList)
		enemyModList:NewMod("Condition:EnemyInFrostGlobe", "FLAG", true, "Config", { type = "Condition", var = "Effective" })
	end },
	{ var = "enemyConditionHitByFireDamage", type = "check", label = "Enemy was Hit by ^xB97123Fire ^7Damage?", labelKey = "ui.config_options.module.enemy_condition_hit_by_fire_damage.label", ifFlag = "ElementalEquilibrium", apply = function(val, modList, enemyModList)
		enemyModList:NewMod("Condition:HitByFireDamage", "FLAG", true, "Config")
	end },
	{ var = "enemyConditionHitByColdDamage", type = "check", label = "Enemy was Hit by ^x3F6DB3Cold ^7Damage?", labelKey = "ui.config_options.module.enemy_condition_hit_by_cold_damage.label", ifFlag = "ElementalEquilibrium", apply = function(val, modList, enemyModList)
		enemyModList:NewMod("Condition:HitByColdDamage", "FLAG", true, "Config")
	end },
	{ var = "enemyConditionHitByLightningDamage", type = "check", label = "Enemy was Hit by ^xADAA47Light. ^7Damage?", labelKey = "ui.config_options.module.enemy_condition_hit_by_lightning_damage.label", ifFlag = "ElementalEquilibrium", apply = function(val, modList, enemyModList)
		enemyModList:NewMod("Condition:HitByLightningDamage", "FLAG", true, "Config")
	end },
	{ var = "enemyInRFOrScorchingRay", type = "check", label = "Is the enemy in RF or Scorching Ray:", labelKey = "ui.config_options.module.enemy_in_rfor_scorching_ray.label", ifCond = "InRFOrScorchingRay", ifSkill = { "Righteous Fire", "Scorching Ray" }, includeTransfigured = true, apply = function(val, modList, enemyModList)
		modList:NewMod("Condition:InRFOrScorchingRay", "FLAG", true, "Config")
	end },
	{ var = "EEIgnoreHitDamage", type = "check", label = "Ignore Skill Hit Damage?", labelKey = "ui.config_options.module.eeignore_hit_damage.label", ifFlag = "ElementalEquilibrium", tooltip = "This option prevents EE from being reset by the hit damage of your main skill.", tooltipKey = "ui.config_options.module.eeignore_hit_damage.tooltip" },
	{ var = "conditionBetweenYouAndLinkedTarget", type = "check", label = "Is the enemy in your Link beams?", labelKey = "ui.config_options.module.condition_between_you_and_linked_target.label", ifEnemyCond = "BetweenYouAndLinkedTarget", tooltip = "This option sets whether an enemy is between you and your linked target.", tooltipKey = "ui.config_options.module.condition_between_you_and_linked_target.tooltip", apply = function(val, modList, enemyModList)
		enemyModList:NewMod("Condition:BetweenYouAndLinkedTarget", "FLAG", true, "Config", { type = "Condition", var = "Effective" })
	end },
	{ var = "conditionEnemyFireResZero", type = "check", label = "Enemy hit you with ^xB97123Fire Damage^7?", labelKey = "ui.config_options.module.condition_enemy_fire_res_zero.label", ifFlag = "Condition:HaveTrickstersSmile", tooltip = "This option sets whether or not the enemy has hit you with ^xB97123Fire Damage^7 in the last 4 seconds.", tooltipKey = "ui.config_options.module.condition_enemy_fire_res_zero.tooltip", apply = function(val, modList, enemyModList)
		enemyModList:NewMod("FireResist", "OVERRIDE", 0, "Config", { type = "Condition", var = "Effective"}, { type = "ActorCondition", actor = "enemy", var = "HaveTrickstersSmile" })
	end },
	{ var = "conditionEnemyColdResZero", type = "check", label = "Enemy hit you with ^x3F6DB3Cold Damage^7?", labelKey = "ui.config_options.module.condition_enemy_cold_res_zero.label", ifFlag = "Condition:HaveTrickstersSmile", tooltip = "This option sets whether or not the enemy has hit you with ^x3F6DB3Cold Damage^7 in the last 4 seconds.", tooltipKey = "ui.config_options.module.condition_enemy_cold_res_zero.tooltip", apply = function(val, modList, enemyModList)
		enemyModList:NewMod("ColdResist", "OVERRIDE", 0, "Config", { type = "Condition", var = "Effective"}, { type = "ActorCondition", actor = "enemy", var = "HaveTrickstersSmile" })
	end },
	{ var = "conditionEnemyLightningResZero", type = "check", label = "Enemy hit you with ^xADAA47Light. Damage^7?", labelKey = "ui.config_options.module.condition_enemy_lightning_res_zero.label", ifFlag = "Condition:HaveTrickstersSmile", tooltip = "This option sets whether or not the enemy has hit you with ^xADAA47Lightning Damage^7 in the last 4 seconds.", tooltipKey = "ui.config_options.module.condition_enemy_lightning_res_zero.tooltip", apply = function(val, modList, enemyModList)
		enemyModList:NewMod("LightningResist", "OVERRIDE", 0, "Config", { type = "Condition", var = "Effective"}, { type = "ActorCondition", actor = "enemy", var = "HaveTrickstersSmile" })
	end },
	-- Section: Enemy Stats
	{ section = "Enemy Stats", sectionKey = "ui.config_options.module.config_settings.section_2", col = 2 },
	{ var = "enemyLevel", type = "count", label = "Enemy Level:", labelKey = "ui.config_options.module.enemy_level.label", tooltip = "This overrides the default enemy level used to estimate your hit, ^x33FF77evade ^7chance, and damage reduction.\n\nThe maximum level for normal enemies and all bosses is 85.\n\nThe default level of normal enemies and bosses scales with player level unless manually set.\n\nThe default and minimum level for pinnacle bosses and uber pinnacle bosses is 82.", tooltipKey = "ui.config_options.module.enemy_level.tooltip" },
	{ var = "conditionEnemyRareOrUnique", type = "check", label = "Is the enemy Rare?", labelKey = "ui.config_options.module.condition_enemy_rare_or_unique.label", ifFlag = {"CanCull","CritCanCull"}, tooltip = "The enemy will automatically be considered to be Unique if they are a Boss.\nUsed to set base Culling Strike Threshold.", tooltipKey = "ui.config_options.module.condition_enemy_rare_or_unique.tooltip", apply = function(val, modList, enemyModList)
		enemyModList:NewMod("Condition:RareOrUnique", "FLAG", true, "Config", { type = "Condition", var = "Effective" })
	end },
	{ var = "enemyIsBoss", type = "list", label = "Is the enemy a Boss?", labelKey = "ui.config_options.module.enemy_is_boss.label_2", defaultIndex = 3, tooltip = function() return localisation:Field(data, 'enemyIsBossTooltip') end, list = {{val="None",label="No", labelKey = "ui.config_options.module.enemy_is_boss.label_3"},{val="Boss",label="Standard Boss", labelKey = "ui.config_options.module.enemy_is_boss.label_4"},{val="Pinnacle",label="Guardian/Pinnacle Boss", labelKey = "ui.config_options.module.enemy_is_boss.label"},{val="Uber",label="Uber Pinnacle Boss", labelKey = "ui.config_options.module.enemy_is_boss.label_5"}}, apply = function(val, modList, enemyModList, build)
		-- These defaults are here so that the placeholders get reset correctly
		build.configTab.varControls['enemySpeed']:SetPlaceholder(700, true)
		build.configTab.varControls['enemyCritChance']:SetPlaceholder(5, true)
		build.configTab.varControls['enemyCritDamage']:SetPlaceholder(data.monsterConstants["base_critical_hit_damage_bonus"], true)
		if val == "None" then
			local defaultResist = ""
			build.configTab.varControls['enemyLightningResist']:SetPlaceholder(defaultResist, true)
			build.configTab.varControls['enemyColdResist']:SetPlaceholder(defaultResist, true)
			build.configTab.varControls['enemyFireResist']:SetPlaceholder(defaultResist, true)
			build.configTab.varControls['enemyChaosResist']:SetPlaceholder(defaultResist, true)

			local defaultLevel = 82
			build.configTab.varControls['enemyLevel']:SetPlaceholder(build.characterLevel, true)
			build.configTab:UpdateLevel()
			if build.configTab.enemyLevel then
				defaultLevel = build.configTab.enemyLevel
			end

			local defaultDamage = round(data.monsterDamageTable[defaultLevel] * 1.5 * data.misc.normalEnemyDPSMult)
			build.configTab.varControls['enemyPhysicalDamage']:SetPlaceholder(defaultDamage, true)
			build.configTab.varControls['enemyLightningDamage']:SetPlaceholder(defaultDamage, true)
			build.configTab.varControls['enemyColdDamage']:SetPlaceholder(defaultDamage, true)
			build.configTab.varControls['enemyFireDamage']:SetPlaceholder(defaultDamage, true)
			build.configTab.varControls['enemyChaosDamage']:SetPlaceholder(round(defaultDamage / 2.5), true)

			local defaultPen = ""
			build.configTab.varControls['enemyPhysicalOverwhelm']:SetPlaceholder(defaultPen, true)
			build.configTab.varControls['enemyLightningPen']:SetPlaceholder(defaultPen, true)
			build.configTab.varControls['enemyColdPen']:SetPlaceholder(defaultPen, true)
			build.configTab.varControls['enemyFirePen']:SetPlaceholder(defaultPen, true)

			build.configTab.varControls['enemyArmour']:SetPlaceholder(data.monsterArmourTable[defaultLevel], true)
			build.configTab.varControls['enemyEvasion']:SetPlaceholder(data.monsterEvasionTable[defaultLevel], true)
		elseif val == "Boss" then
			enemyModList:NewMod("Condition:Unique", "FLAG", true, "Config", { type = "Condition", var = "Effective" })
			enemyModList:NewMod("Condition:RareOrUnique", "FLAG", true, "Config", { type = "Condition", var = "Effective" })
			enemyModList:NewMod("CurseEffectOnSelf", "MORE", -50, "Unique", { type = "Condition", var = "Effective" }) -- MonsterUnique13
			enemyModList:NewMod("ExposureEffectOnSelf", "MORE", -50, "Unique", { type = "Condition", var = "Effective" }) -- MonsterUnique14
			enemyModList:NewMod("KnockbackDistanceOnSelf", "MORE", -75, "Unique", { type = "Condition", var = "Effective" }) -- MonsterUnique12
			enemyModList:NewMod("SlowEffectOnSelf", "MORE", -50, "Unique", { type = "Condition", var = "Effective" }) -- MonsterUnique11
			enemyModList:NewMod("MinimumMovementSpeed", "BASE", 20, "Unique", { type = "Condition", var = "Effective" }) -- MonsterUnique9
			enemyModList:NewMod("PoiseThreshold", "MORE", 500, "Unique", { type = "Condition", var = "Effective" }) -- MonsterUnique2
			enemyModList:NewMod("PoiseThreshold", "MORE", 213, "Map Boss", { type = "Condition", var = "Effective" })
			modList:NewMod("WarcryPower", "BASE", 20, "Boss")
			modList:NewMod("Multiplier:EnemyPower", "BASE", 20, "Boss")

			local defaultEleResist = 30
			build.configTab.varControls['enemyLightningResist']:SetPlaceholder(defaultEleResist, true)
			build.configTab.varControls['enemyColdResist']:SetPlaceholder(defaultEleResist, true)
			build.configTab.varControls['enemyFireResist']:SetPlaceholder(defaultEleResist, true)
			build.configTab.varControls['enemyChaosResist']:SetPlaceholder(0, true)

			local defaultLevel = 82
			build.configTab.varControls['enemyLevel']:SetPlaceholder(build.characterLevel, true)
			build.configTab:UpdateLevel()
			if build.configTab.enemyLevel then
				defaultLevel = build.configTab.enemyLevel
			end

			local defaultDamage = round(data.monsterDamageTable[defaultLevel] * 1.5  * data.misc.stdBossDPSMult)
			build.configTab.varControls['enemyPhysicalDamage']:SetPlaceholder(defaultDamage, true)
			build.configTab.varControls['enemyLightningDamage']:SetPlaceholder(defaultDamage, true)
			build.configTab.varControls['enemyColdDamage']:SetPlaceholder(defaultDamage, true)
			build.configTab.varControls['enemyFireDamage']:SetPlaceholder(defaultDamage, true)
			build.configTab.varControls['enemyChaosDamage']:SetPlaceholder(round(defaultDamage / 2.5), true)

			local defaultPen = ""
			build.configTab.varControls['enemyPhysicalOverwhelm']:SetPlaceholder(defaultPen, true)
			build.configTab.varControls['enemyLightningPen']:SetPlaceholder(defaultPen, true)
			build.configTab.varControls['enemyColdPen']:SetPlaceholder(defaultPen, true)
			build.configTab.varControls['enemyFirePen']:SetPlaceholder(defaultPen, true)

			build.configTab.varControls['enemyArmour']:SetPlaceholder(data.monsterArmourTable[defaultLevel], true)
			build.configTab.varControls['enemyEvasion']:SetPlaceholder(data.monsterEvasionTable[defaultLevel], true)
		elseif val == "Pinnacle" then
			enemyModList:NewMod("Condition:Unique", "FLAG", true, "Config", { type = "Condition", var = "Effective" })
			enemyModList:NewMod("Condition:RareOrUnique", "FLAG", true, "Config", { type = "Condition", var = "Effective" })
			enemyModList:NewMod("Condition:PinnacleBoss", "FLAG", true, "Config", { type = "Condition", var = "Effective" })
			enemyModList:NewMod("CurseEffectOnSelf", "MORE", -50, "Unique", { type = "Condition", var = "Effective" }) -- MonsterUnique13
			enemyModList:NewMod("ExposureEffectOnSelf", "MORE", -50, "Unique", { type = "Condition", var = "Effective" }) -- MonsterUnique14
			enemyModList:NewMod("KnockbackDistanceOnSelf", "MORE", -75, "Unique", { type = "Condition", var = "Effective" }) -- MonsterUnique12
			enemyModList:NewMod("SlowEffectOnSelf", "MORE", -50, "Unique", { type = "Condition", var = "Effective" }) -- MonsterUnique11
			enemyModList:NewMod("MinimumMovementSpeed", "BASE", 20, "Unique", { type = "Condition", var = "Effective" }) -- MonsterUnique9
			enemyModList:NewMod("PoiseThreshold", "MORE", 500, "Unique", { type = "Condition", var = "Effective" }) -- MonsterUnique2
			enemyModList:NewMod("PoiseThreshold", "MORE", 838, "Xesht", { type = "Condition", var = "Effective" })
			modList:NewMod("WarcryPower", "BASE", 20, "Boss")
			modList:NewMod("Multiplier:EnemyPower", "BASE", 20, "Boss")

			local defaultEleResist = 50
			build.configTab.varControls['enemyLightningResist']:SetPlaceholder(defaultEleResist, true)
			build.configTab.varControls['enemyColdResist']:SetPlaceholder(defaultEleResist, true)
			build.configTab.varControls['enemyFireResist']:SetPlaceholder(defaultEleResist, true)
			build.configTab.varControls['enemyChaosResist']:SetPlaceholder(0, true)

			local defaultLevel = 82
			build.configTab.varControls['enemyLevel']:SetPlaceholder(defaultLevel, true)
			build.configTab:UpdateLevel()
			if build.configTab.enemyLevel then
				defaultLevel = m_max(build.configTab.enemyLevel, defaultLevel)
			end

			local defaultDamage = round(data.monsterDamageTable[defaultLevel] * 1.5  * data.misc.pinnacleBossDPSMult)
			build.configTab.varControls['enemyPhysicalDamage']:SetPlaceholder(defaultDamage, true)
			build.configTab.varControls['enemyLightningDamage']:SetPlaceholder(defaultDamage, true)
			build.configTab.varControls['enemyColdDamage']:SetPlaceholder(defaultDamage, true)
			build.configTab.varControls['enemyFireDamage']:SetPlaceholder(defaultDamage, true)
			build.configTab.varControls['enemyChaosDamage']:SetPlaceholder(round(defaultDamage / 2.5), true)

			build.configTab.varControls['enemyLightningPen']:SetPlaceholder(data.misc.pinnacleBossPen, true)
			build.configTab.varControls['enemyColdPen']:SetPlaceholder(data.misc.pinnacleBossPen, true)
			build.configTab.varControls['enemyFirePen']:SetPlaceholder(data.misc.pinnacleBossPen, true)

			build.configTab.varControls['enemyArmour']:SetPlaceholder(round(data.monsterArmourTable[defaultLevel] * (data.bossStats.PinnacleArmourMean/100)), true)
			build.configTab.varControls['enemyEvasion']:SetPlaceholder(round(data.monsterEvasionTable[defaultLevel] * (data.bossStats.PinnacleEvasionMean/100)), true)
		elseif val == "Uber" then
			enemyModList:NewMod("Condition:Unique", "FLAG", true, "Config", { type = "Condition", var = "Effective" })
			enemyModList:NewMod("Condition:RareOrUnique", "FLAG", true, "Config", { type = "Condition", var = "Effective" })
			enemyModList:NewMod("Condition:PinnacleBoss", "FLAG", true, "Config", { type = "Condition", var = "Effective" })
			enemyModList:NewMod("CurseEffectOnSelf", "MORE", -50, "Unique", { type = "Condition", var = "Effective" }) -- MonsterUnique13
			enemyModList:NewMod("ExposureEffectOnSelf", "MORE", -50, "Unique", { type = "Condition", var = "Effective" }) -- MonsterUnique14
			enemyModList:NewMod("KnockbackDistanceOnSelf", "MORE", -75, "Unique", { type = "Condition", var = "Effective" }) -- MonsterUnique12
			enemyModList:NewMod("SlowEffectOnSelf", "MORE", -50, "Unique", { type = "Condition", var = "Effective" }) -- MonsterUnique11
			enemyModList:NewMod("MinimumMovementSpeed", "BASE", 20, "Unique", { type = "Condition", var = "Effective" }) -- MonsterUnique9
			enemyModList:NewMod("DamageTaken", "MORE", -70, "Boss")
			enemyModList:NewMod("PoiseThreshold", "MORE", 500, "Unique", { type = "Condition", var = "Effective" }) -- MonsterUnique2
			enemyModList:NewMod("PoiseThreshold", "MORE", 838, "Xesht", { type = "Condition", var = "Effective" })
			modList:NewMod("WarcryPower", "BASE", 20, "Boss")
			modList:NewMod("Multiplier:EnemyPower", "BASE", 20, "Boss")

			local defaultEleResist = 50
			build.configTab.varControls['enemyLightningResist']:SetPlaceholder(defaultEleResist, true)
			build.configTab.varControls['enemyColdResist']:SetPlaceholder(defaultEleResist, true)
			build.configTab.varControls['enemyFireResist']:SetPlaceholder(defaultEleResist, true)
			build.configTab.varControls['enemyChaosResist']:SetPlaceholder(0, true)

			local defaultLevel = 82
			build.configTab.varControls['enemyLevel']:SetPlaceholder(defaultLevel, true)
			build.configTab:UpdateLevel()
			if build.configTab.enemyLevel then
				defaultLevel = m_max(build.configTab.enemyLevel, defaultLevel)
			end

			local defaultDamage = round(data.monsterDamageTable[defaultLevel] * 1.5  * data.misc.uberBossDPSMult)
			build.configTab.varControls['enemyPhysicalDamage']:SetPlaceholder(defaultDamage, true)
			build.configTab.varControls['enemyLightningDamage']:SetPlaceholder(defaultDamage, true)
			build.configTab.varControls['enemyColdDamage']:SetPlaceholder(defaultDamage, true)
			build.configTab.varControls['enemyFireDamage']:SetPlaceholder(defaultDamage, true)
			build.configTab.varControls['enemyChaosDamage']:SetPlaceholder(round(defaultDamage / 4), true)

			build.configTab.varControls['enemyLightningPen']:SetPlaceholder(data.misc.uberBossPen, true)
			build.configTab.varControls['enemyColdPen']:SetPlaceholder(data.misc.uberBossPen, true)
			build.configTab.varControls['enemyFirePen']:SetPlaceholder(data.misc.uberBossPen, true)

			build.configTab.varControls['enemyArmour']:SetPlaceholder(round(data.monsterArmourTable[defaultLevel] * (data.bossStats.UberArmourMean/100)), true)
			build.configTab.varControls['enemyEvasion']:SetPlaceholder(round(data.monsterEvasionTable[defaultLevel] * (data.bossStats.UberEvasionMean/100)), true)
		end
	end },
	{ var = "deliriousPercentage", type = "list", label = "Delirious Effect:", labelKey = "ui.config_options.module.delirious_percentage.label_6", list = {{val=0,label="None", labelKey = "ui.config_options.module.repeat_mode.label_3"},{val="20Percent",label="20% Delirious", labelKey = "ui.config_options.module.delirious_percentage.label_2"},{val="40Percent",label="40% Delirious", labelKey = "ui.config_options.module.delirious_percentage.label_3"},{val="60Percent",label="60% Delirious", labelKey = "ui.config_options.module.delirious_percentage.label_4"},{val="80Percent",label="80% Delirious", labelKey = "ui.config_options.module.delirious_percentage.label_5"},{val="100Percent",label="100% Delirious", labelKey = "ui.config_options.module.delirious_percentage.label"}}, tooltip = "Delirium scales enemy 'less Damage Taken' as well as enemy 'increased Damage dealt'\nAt 100% effect:\nEnemies Deal 30% Increased Damage\nEnemies take 80% Less Damage", tooltipKey = "ui.config_options.module.delirious_percentage.tooltip", apply = function(val, modList, enemyModList)
		if val == "20Percent" then
			enemyModList:NewMod("DamageTaken", "MORE", -16, "20% Delirious")
			enemyModList:NewMod("Damage", "INC", 6, "20% Delirious")
		end
		if val == "40Percent" then
			enemyModList:NewMod("DamageTaken", "MORE", -32, "40% Delirious")
			enemyModList:NewMod("Damage", "INC", 12, "40% Delirious")
		end
		if val == "60Percent" then
			enemyModList:NewMod("DamageTaken", "MORE", -48, "60% Delirious")
			enemyModList:NewMod("Damage", "INC", 18, "60% Delirious")
		end
		if val == "80Percent" then
			enemyModList:NewMod("DamageTaken", "MORE", -64, "80% Delirious")
			enemyModList:NewMod("Damage", "INC", 24, "80% Delirious")
		end
		if val == "100Percent" then
			enemyModList:NewMod("DamageTaken", "MORE", -80, "100% Delirious")
			enemyModList:NewMod("Damage", "INC", 30, "100% Delirious")
		end
	end },
	{ var = "enemyPhysicalReduction", type = "integer", label = "Enemy Phys. Damage Reduction:", labelKey = "ui.config_options.module.enemy_physical_reduction.label", apply = function(val, modList, enemyModList)
		enemyModList:NewMod("PhysicalDamageReduction", "BASE", val, "EnemyConfig")
	end },
	{ var = "enemyLightningResist", type = "countAllowZero", label = "Enemy ^xADAA47Lightning Resistance:", labelKey = "ui.config_options.module.enemy_lightning_resist.label", apply = function(val, modList, enemyModList)
		enemyModList:NewMod("LightningResist", "BASE", val, "EnemyConfig")
	end },
	{ var = "enemyColdResist", type = "countAllowZero", label = "Enemy ^x3F6DB3Cold Resistance:", labelKey = "ui.config_options.module.enemy_cold_resist.label", apply = function(val, modList, enemyModList)
		enemyModList:NewMod("ColdResist", "BASE", val, "EnemyConfig")
	end },
	{ var = "enemyFireResist", type = "countAllowZero", label = "Enemy ^xB97123Fire Resistance:", labelKey = "ui.config_options.module.enemy_fire_resist.label", apply = function(val, modList, enemyModList)
		enemyModList:NewMod("FireResist", "BASE", val, "EnemyConfig")
	end },
	{ var = "enemyChaosResist", type = "countAllowZero", label = "Enemy ^xD02090Chaos Resistance:", labelKey = "ui.config_options.module.enemy_chaos_resist.label", apply = function(val, modList, enemyModList)
		enemyModList:NewMod("ChaosResist", "BASE", val, "EnemyConfig")
	end },
	{ var = "enemyMaxResist", type = "check", label = "Enemy Max Resistance is always 75%", labelKey = "ui.config_options.module.enemy_max_resist.label", tooltip = "Enemy Maximum resistance is increased by the resistance configurations \nThis locks it at the default value", tooltipKey = "ui.config_options.module.enemy_max_resist.tooltip", apply = function(val, modList, enemyModList)
		enemyModList:NewMod("DoNotChangeMaxResFromConfig", "FLAG", true, "EnemyConfig")
	end },
	{ var = "enemyBlockChance", type = "countAllowZero", label = "Enemy Block Chance:", labelKey = "ui.config_options.module.enemy_block_chance.label", apply = function(val, modList, enemyModList)
		enemyModList:NewMod("BlockChance", "BASE", val, "Config")
	end },
	{ var = "enemyEvasion", type = "countAllowZero", label = "Enemy Base ^x33FF77Evasion:", labelKey = "ui.config_options.module.enemy_evasion.label", apply = function(val, modList, enemyModList)
		enemyModList:NewMod("Evasion", "BASE", val, "Config")
	end },
	{ var = "enemyArmour", type = "countAllowZero", label = "Enemy Base Armour:", labelKey = "ui.config_options.module.enemy_armour.label", apply = function(val, modList, enemyModList)
		enemyModList:NewMod("Armour", "BASE", val, "Config")
	end },
	{ var = "presetBossSkills", type = "list", defaultIndex = 1, label = "Boss Skill Preset", labelKey = "ui.config_options.module.preset_boss_skills.label", tooltipFunc = bossSkillsTooltip, list = data.bossSkillsList, apply = function(val, modList, enemyModList, build)
		if not (val == "None") then
			local bossData = data.bossSkills[val]
			local isUber = build.configTab.varControls['enemyIsBoss'].list[build.configTab.varControls['enemyIsBoss'].selIndex].val == "Uber"
			if bossData.earlierUber and build.configTab.varControls['enemyIsBoss'].list[build.configTab.varControls['enemyIsBoss'].selIndex].val == "Pinnacle" then
				isUber = true
			end
			local defaultDamage = ""
			build.configTab.varControls['enemyPhysicalDamage']:SetPlaceholder(defaultDamage, true)
			build.configTab.varControls['enemyLightningDamage']:SetPlaceholder(defaultDamage, true)
			build.configTab.varControls['enemyColdDamage']:SetPlaceholder(defaultDamage, true)
			build.configTab.varControls['enemyFireDamage']:SetPlaceholder(defaultDamage, true)
			build.configTab.varControls['enemyChaosDamage']:SetPlaceholder(defaultDamage, true)

			local rollRangeMult = m_min(m_max(build.configTab.input['enemyDamageRollRange'] or build.configTab.varControls['enemyDamageRollRange'].placeholder, 0), 100)
			for damageType, damageMult in pairs(bossData.DamageMultipliers) do
				if isUber and bossData.UberDamageMultiplier then
					build.configTab.varControls['enemy'..damageType..'Damage']:SetPlaceholder(round(data.monsterDamageTable[build.configTab.enemyLevel] * (damageMult[1] + rollRangeMult * damageMult[2]) * bossData.UberDamageMultiplier), true)
				else
					build.configTab.varControls['enemy'..damageType..'Damage']:SetPlaceholder(round(data.monsterDamageTable[build.configTab.enemyLevel] * (damageMult[1] + rollRangeMult * damageMult[2])), true)
				end
			end

			local defaultPen = ""
			build.configTab.varControls['enemyPhysicalOverwhelm']:SetPlaceholder(defaultPen, true)
			build.configTab.varControls['enemyLightningPen']:SetPlaceholder(defaultPen, true)
			build.configTab.varControls['enemyColdPen']:SetPlaceholder(defaultPen, true)
			build.configTab.varControls['enemyFirePen']:SetPlaceholder(defaultPen, true)

			if bossData.DamagePenetrations then
				for penType, pen in pairs(bossData.DamagePenetrations) do
					if isUber and bossData.UberDamagePenetrations and bossData.UberDamagePenetrations[penType] then
						build.configTab.varControls['enemy'..penType]:SetPlaceholder(bossData.UberDamagePenetrations[penType], true)
					else
						build.configTab.varControls['enemy'..penType]:SetPlaceholder(pen, true)
					end
				end
			end

			if bossData.DamageType then
				build.configTab.varControls['enemyDamageType']:SelByValue(bossData.DamageType, "val")
				build.configTab.input['enemyDamageType'] = bossData.DamageType
			end
			build.configTab.varControls['enemyDamageType'].enabled = false

			if isUber and bossData.UberSpeed then
				build.configTab.varControls['enemySpeed']:SetPlaceholder(bossData.UberSpeed, true)
			elseif bossData.speed then
				build.configTab.varControls['enemySpeed']:SetPlaceholder(bossData.speed, true)
			end
			if bossData.critChance then
				build.configTab.varControls['enemyCritChance']:SetPlaceholder(bossData.critChance, true)
			end

			modList:NewMod("BossSkillActive", "FLAG", true, "Config")

			-- boss specific mods
			if val == "Atziri Flameblast" and isUber then
				enemyModList:NewMod("Damage", "INC", 60, "Alluring Abyss Map Mod")
			end
			if bossData.additionalStats then
				local additionalStats = isUber and bossData.additionalStats.uber or bossData.additionalStats.base
				if additionalStats then
					for k, v in pairs(additionalStats) do
						if tostring(v) == "flag" then
							enemyModList:NewMod(k, "FLAG", true, "BossSkillAdditionalData")
						else
							enemyModList:NewMod(k, "BASE", v, "BossSkillAdditionalData")
						end
					end
				end
			end
		else
			if build.configTab.varControls['enemyDamageType'].enabled == false then
				build.configTab.input['enemyDamageType'] = "Average"
				build.configTab.varControls['enemyDamageType']:SelByValue("Average", "val")
			end
			build.configTab.varControls['enemyDamageType'].enabled = true
		end
	end },
	{ var = "enemyDamageRollRange", type = "countAllowZero", label = "Enemy Skill Roll Range %:", labelKey = "ui.config_options.module.enemy_damage_roll_range.label", ifFlag = "BossSkillActive", tooltip = "The percentage of the roll range the enemy hits for \n eg at 100% the enemy deals its maximum damage", tooltipKey = "ui.config_options.module.enemy_damage_roll_range.tooltip", defaultPlaceholderState = 70, hideIfInvalid = true },
	{ var = "enemyDamageType", type = "list", label = "Enemy Damage Type:", labelKey = "ui.config_options.module.enemy_damage_type.label_2", tooltip = "Controls which types of damage the EHP calculation uses:\n\tAverage: uses the Average of all typed damage types (except Damage Over Time and Untyped)\n\nIf a specific damage type is selected, that will be the only type used.", tooltipKey = "ui.config_options.module.enemy_damage_type.tooltip", list = {
		{val="Average",label="Average", labelKey = "ui.config_options.module.ailment_mode.label_2"},
		{val="Untyped",label="Untyped", labelKey = "ui.config_options.module.enemy_damage_type.label_7"},
		{val="DamageOverTime",label="Damage Over Time", labelKey = "ui.config_options.module.enemy_damage_type.label"},
		{val="Melee",label="Melee", labelKey = "ui.config_options.module.enemy_damage_type.label_3"},
		{val="Projectile",label="Projectile", labelKey = "ui.config_options.module.enemy_damage_type.label_4"},
		{val="Spell",label="Spell", labelKey = "ui.config_options.module.enemy_damage_type.label_6"},
		{val="SpellProjectile",label="Projectile Spell", labelKey = "ui.config_options.module.enemy_damage_type.label_5"}
	} },
	{ var = "enemySpeed", type = "countAllowZero", label = "Enemy attack / cast time in ms:", labelKey = "ui.config_options.module.enemy_speed.label", defaultPlaceholderState = 700 },
	{ var = "enemyMultiplierPvpDamage", type = "count", label = "Custom PvP Damage multiplier percent:", labelKey = "ui.config_options.module.multiplier_pvp_damage.label", ifFlag = "isPvP", tooltip = "This multiplies the damage of a given skill in pvp, for instance any with damage multiplier specific to pvp (from skill or support or item like sire of shards)", tooltipKey = "ui.config_options.module.multiplier_pvp_damage.tooltip", apply = function(val, modList, enemyModList)
		enemyModList:NewMod("MultiplierPvpDamage", "BASE", val, "Config")
	end },
	{ var = "enemyCritChance", type = "countAllowZero", label = "Enemy critical strike chance:", labelKey = "ui.config_options.module.enemy_crit_chance.label", defaultPlaceholderState = 5 },
	{ var = "enemyCritDamage", type = "countAllowZero", label = "Enemy critical strike multiplier:", labelKey = "ui.config_options.module.enemy_crit_damage.label", defaultPlaceholderState = data.monsterConstants["base_critical_hit_damage_bonus"] },
	{ var = "enemyPhysicalDamage", type = "countAllowZero", label = "Enemy Skill Physical Damage:", labelKey = "ui.config_options.module.enemy_physical_damage.label", tooltip = "This overrides the default damage amount used to estimate your damage reduction from armour.\nThe default is 1.5 times the enemy's base damage, which is the same value\nused in-game to calculate the estimate shown on the character sheet.", tooltipKey = "ui.config_options.module.enemy_physical_damage.tooltip", defaultPlaceholderState = 7 },
	{ var = "enemyPhysicalOverwhelm", type = "countAllowZero", label = "Enemy Skill Physical Overwhelm:", labelKey = "ui.config_options.module.enemy_physical_overwhelm.label"},
	{ var = "enemyLightningDamage", type = "countAllowZero", label = "Enemy Skill ^xADAA47Lightning Damage:", labelKey = "ui.config_options.module.enemy_lightning_damage.label"},
	{ var = "enemyLightningPen", type = "countAllowZero", label = "Enemy Skill ^xADAA47Lightning Pen:", labelKey = "ui.config_options.module.enemy_lightning_pen.label"},
	{ var = "enemyColdDamage", type = "countAllowZero", label = "Enemy Skill ^x3F6DB3Cold Damage:", labelKey = "ui.config_options.module.enemy_cold_damage.label"},
	{ var = "enemyColdPen", type = "countAllowZero", label = "Enemy Skill ^x3F6DB3Cold Pen:", labelKey = "ui.config_options.module.enemy_cold_pen.label"},
	{ var = "enemyFireDamage", type = "countAllowZero", label = "Enemy Skill ^xB97123Fire Damage:", labelKey = "ui.config_options.module.enemy_fire_damage.label"},
	{ var = "enemyFirePen", type = "countAllowZero", label = "Enemy Skill ^xB97123Fire Pen:", labelKey = "ui.config_options.module.enemy_fire_pen.label"},
	{ var = "enemyChaosDamage", type = "countAllowZero", label = "Enemy Skill ^xD02090Chaos Damage:", labelKey = "ui.config_options.module.enemy_chaos_damage.label"},

	-- Section: Custom mods
	{ section = "Custom Modifiers", sectionKey = "ui.config_options.module.config_settings.section", col = 1 },
}

addQuestModsRewardsConfigOptions(configSettings)

return configSettings
