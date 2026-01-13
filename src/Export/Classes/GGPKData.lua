-- Dat View
--
-- Class: GGPK Data
-- GGPK Data
--
local ipairs = ipairs
local t_insert = table.insert

local function scanDir(directory, extension)
	local i = 0
	local t = { }
	local pFile = io.popen('dir "'..directory..'" /b')
	for filename in pFile:lines() do
		filename = filename:gsub('\r?$', '')
		--ConPrintf("%s\n", filename)
		if extension then
			if filename:match(extension) then
				i = i + 1
				t[i] = filename
			else
				--ConPrintf("No Files Found matching extension '%s'", extension)
			end
		else
			i = i + 1
			t[i] = filename
		end
	end
	pFile:close()
	return t
end

-- Path can be in any format recognized by the extractor at oozPath, ie,
-- a .ggpk file or a Steam Path of Exile directory
local GGPKClass = newClass("GGPKData", function(self, path, datPath, reExport)
	if datPath then
		self.oozPath = datPath:match("\\$") and datPath or (datPath .. "\\")
	else
		self.path = path
		self.oozPath = GetWorkDir() .. "\\ggpk\\"
		self:CleanDir(reExport)
		self:ExtractFiles(reExport)
	end

	self.dat = { }
	self.txt = { }
	self.ot = { }
	
	self:AddDat64Files()
end)

function GGPKClass:CleanDir(reExport)
	if reExport then
		local cmd = 'del ' .. self.oozPath .. 'Data ' .. self.oozPath .. 'Metadata /Q /S'
		ConPrintf(cmd)
		os.execute(cmd)
	end
end

function GGPKClass:ExtractFilesWithBun(fileListStr, useRegex)
	local useRegex = useRegex or false
	local cmd = 'cd ' .. self.oozPath .. ' && bun_extract_file.exe extract-files ' .. (useRegex and '--regex "' or '"') .. self.path .. '" . ' .. fileListStr
	ConPrintf(cmd)
	os.execute(cmd)
end

-- Use manifest files to avoid command line limit and reduce cmd calls
function GGPKClass:ExtractFilesWithBunFromTable(fileTable, useRegex)
	local useRegex = useRegex or false
	local manifest = self.oozPath .. "extract_list.txt"
	local f = assert(io.open(manifest, "w"))
	for _, fname in ipairs(fileTable) do
		f:write(string.lower(fname), "\n")
	end
	f:close()
	local cmd = 'cd "' .. self.oozPath .. '" && bun_extract_file.exe extract-files ' .. (useRegex and '--regex "' or '"') .. self.path .. '" . < "' .. manifest .. '"'
	ConPrintf(cmd)
	os.execute(cmd)
	os.remove(manifest)
end

function GGPKClass:ExtractFiles(reExport)
	if reExport then
		local datList, csdList, otList, itList = self:GetNeededFiles()
		local datFiles = {}
		for _, fname in ipairs(datList) do
			datFiles[#datFiles + 1] = fname .. "c64"
		end

		-- non-regex chunk: dat files + itList
		for i = 1, #itList do
			datFiles[#datFiles + 1] = itList[i]
		end
		self:ExtractFilesWithBunFromTable(datFiles, false)

		-- regex chunk: otList + csdList (stat descriptions)
		local regexFiles = {}
		for i = 1, #otList do
			regexFiles[#regexFiles + 1] = otList[i]
		end
		for i = 1, #csdList do
			regexFiles[#regexFiles + 1] = csdList[i]
		end
		self:ExtractFilesWithBunFromTable(regexFiles, true)
	end

	-- Overwrite Enums
	local errMsg = PLoadModule("Scripts/enums.lua")
	if errMsg then
		print(errMsg)
	end
end

function GGPKClass:ExtractList(listToExtract, cache, useRegex)
	useRegex = useRegex or false
	printf("Extracting ...")
	local fileTable = {}
	for _, fname in ipairs(listToExtract) do
		-- we are going to validate if the file is already extracted in this session
		if not cache[fname] then
			cache[fname] = true
			fileTable[#fileTable + 1] = fname
		end
	end

	self:ExtractFilesWithBunFromTable(fileTable, useRegex)
end

function GGPKClass:AddDat64Files()
	local datFiles = self:GetNeededFiles()
	table.sort(datFiles, function(a, b) return a:lower() < b:lower() end)
	for _, fname in ipairs(datFiles) do
		local record = { }
		record.name = fname:match("([^/\\]+)$") .. "c64"
		local rawFile = io.open(self.oozPath .. fname:gsub("/", "\\") .. "c64", 'rb')
		record.data = rawFile:read("*all")
		rawFile:close()
		t_insert(self.dat, record)
	end
end

function GGPKClass:GetNeededFiles()
	local datFiles = {
		"Data/Balance/Stats.dat",
		"Data/Balance/VirtualStatContextFlags.dat",
		"Data/Balance/BaseItemTypes.dat",
		"Data/Balance/WeaponTypes.dat",
		"Data/Balance/ArmourTypes.dat",
		"Data/Balance/ShieldTypes.dat",
		"Data/Balance/Flasks.dat",
		"Data/Balance/ComponentCharges.dat",
		"Data/Balance/PassiveSkills.dat",
		"Data/Balance/PassiveSkillStatCategories.dat",
		"Data/Balance/PassiveSkillMasteryGroups.dat",
		"Data/Balance/PassiveSkillMasteryEffects.dat",
		"Data/Balance/PassiveTreeExpansionJewelSizes.dat",
		"Data/Balance/PassiveTreeExpansionJewels.dat",
		"Data/Balance/PassiveJewelSlots.dat",
		"Data/Balance/PassiveTreeExpansionSkills.dat",
		"Data/Balance/PassiveTreeExpansionSpecialSkills.dat",
		"Data/Balance/PassiveKeystoneList.dat",
		"Data/Balance/Mods.dat",
		"Data/Balance/ModType.dat",
		"Data/Balance/ModFamily.dat",
		"Data/Balance/ModSellPriceTypes.dat",
		"Data/Balance/ModEffectStats.dat",
		"Data/Balance/ModDomains.dat",
		"Data/Balance/ModGenerationTypes.dat",
		"Data/Balance/ActiveSkills.dat",
		"Data/Balance/ActiveSkillType.dat",
		"Data/Balance/AlternateSkillTargetingBehaviours.dat",
		"Data/Balance/Ascendancy.dat",
		"Data/Balance/ClientStrings.dat",
		"Data/Balance/FlavourText.dat",
		"Data/Balance/Words.dat",
		"Data/Balance/ItemClasses.dat",
		"Data/Balance/SkillTotemVariations.dat",
		"Data/Balance/Essences.dat",
		"Data/Balance/EssenceMods.dat",
		"Data/Balance/EssenceTargetItemCategories.dat",
		"Data/Balance/EssenceType.dat",
		"Data/Balance/Characters.dat",
		"Data/Balance/BuffDefinitions.dat",
		"Data/Balance/BuffTemplates.dat",
		"Data/Balance/BuffVisuals.dat",
		"Data/Balance/BuffVisualSetEntries.dat",
		"Data/Balance/BuffVisualsArtVariations.dat",
		"Data/Balance/BuffVisualOrbs.dat",
		"Data/Balance/BuffVisualOrbTypes.dat",
		"Data/Balance/GenericBuffAuras.dat",
		"Data/Balance/AddBuffToTargetVarieties.dat",
		"Data/Balance/TacticianTotemBuffs.dat",
		"Data/Balance/InterpolateBuffEffect.dat",
		"Data/Balance/OnGoingBuffVariations.dat",
		"Data/Balance/MonsterBonuses.dat",
		"Data/Balance/HideoutNPCs.dat",
		"Data/Balance/NPCs.dat",
		"Data/Balance/CraftingBenchOptions.dat",
		"Data/Balance/CraftingItemClassCategories.dat",
		"Data/Balance/CraftingBenchUnlockCategories.dat",
		"Data/Balance/CraftingBenchSortCategories.dat",
		"Data/Balance/MonsterVarieties.dat",
		"Data/Balance/MonsterResistances.dat",
		"Data/Balance/MonsterTypes.dat",
		"Data/Balance/DefaultMonsterStats.dat",
		"Data/Balance/SkillGems.dat",
		"Data/Balance/GrantedEffects.dat",
		"Data/Balance/GrantedEffectsPerLevel.dat",
		"Data/Balance/ItemExperiencePerLevel.dat",
		"Data/Balance/EffectivenessCostConstants.dat",
		"Data/Balance/Tags.dat",
		"Data/Balance/GemTags.dat",
		"Data/Balance/ItemVisualIdentity.dat",
		"Data/Balance/AchievementItems.dat",
		"Data/Balance/MultiPartAchievements.dat",
		"Data/Balance/PantheonPanelLayout.dat",
		"Data/Balance/AlternatePassiveAdditions.dat",
		"Data/Balance/AlternatePassiveSkills.dat",
		"Data/Balance/AlternateTreeVersions.dat",
		"Data/Balance/GrantedEffectQualityStats.dat",
		"Data/Balance/AegisVariations.dat",
		"Data/Balance/CostTypes.dat",
		"Data/Balance/PassiveJewelRadii.dat",
		"Data/Balance/SoundEffects.dat",
		"Data/Balance/MavenJewelRadiusKeystones.dat",
		"Data/Balance/TableCharge.dat",
		"Data/Balance/GrantedEffectStatSets.dat",
		"Data/Balance/GrantedEffectStatSetsPerLevel.dat",
		"Data/Balance/MonsterMapDifficulty.dat",
		"Data/Balance/MonsterMapBossDifficulty.dat",
		"Data/Balance/ReminderText.dat",
		"Data/Balance/Projectiles.dat",
		"Data/Balance/ItemExperienceTypes.dat",
		"Data/Balance/UniqueStashLayout.dat",
		"Data/Balance/UniqueStashTypes.dat",
		"Data/Balance/Shrines.dat",
		"Data/Balance/PassiveOverrideLimits.dat",
		"Data/Balance/PassiveSkillOverrides.dat",
		"Data/Balance/PassiveSkillOverrideTypes.dat",
		"Data/Balance/DisplayMinionMonsterType.dat",
		"Data/Balance/LeagueNames.dat",
		"Data/Balance/GemEffects.dat",
		"Data/Balance/ActionTypes.dat",
		"Data/Balance/IndexableSupportGems.dat",
		"Data/Balance/ItemClassCategories.dat",
		"Data/Balance/MinionType.dat",
		"Data/Balance/SummonedSpecificMonsters.dat",
		"Data/Balance/GameConstants.dat",
		"Data/Balance/AlternateQualityTypes.dat",
		"Data/Balance/WeaponClasses.dat",
		"Data/Balance/MonsterConditions.dat",
		"Data/Balance/Rarity.dat",
		"Data/Balance/Commands.dat",
		"Data/Balance/ModEquivalencies.dat",
		"Data/Balance/InfluenceTags.dat",
		"Data/Balance/AttributeRequirements.dat",
		"Data/Balance/GrantedEffectLabels.dat",
		"Data/Balance/ItemInherentSkills.dat",
		"Data/Balance/KeywordPopups.dat",
		"Data/Balance/SoulCores.dat",
		"Data/Balance/SoulCoreStats.dat",
		"Data/Balance/SoulCoreTypes.dat",
		"Data/Balance/SoulCoreLimits.dat",
		"Data/Balance/SoulCoreStatCategories.dat",
		"Data/Balance/UtilityFlaskBuffs.dat",
		"Data/Balance/GrantedSkillSocketNumbers.dat",
		"Data/Balance/AdvancedCraftingBenchCustomTags.dat",
		"Data/Balance/AdvancedCraftingBenchTabFilterTypes.dat",
		"Data/Balance/CharacterMeleeSkills.dat",
		"Data/Balance/ClientStrings2.dat",
		"Data/Balance/CraftableModTypes.dat",
		"Data/Balance/DamageCalculationTypes.dat",
		"Data/Balance/EndgameCorruptionMods.dat",
		"Data/Balance/GoldInherentSkillPricesPerLevel.dat",
		"Data/Balance/GoldModPrices.dat",
		"Data/Balance/GoldRespecPrices.dat",
		"Data/Balance/HideoutResistPenalties.dat",
		"Data/Balance/MinionGemLevelScaling.dat",
		"Data/Balance/MinionStats.dat",
		"Data/Balance/ModGrantedSkills.dat",
		"Data/Balance/PassiveJewelNodeModifyingStats.dat",
		"Data/Balance/ResistancePenaltyPerAreaLevel.dat",
		"Data/Balance/ShapeShiftForms.dat",
		"Data/Balance/SkillGemsForUniqueStat.dat",
		"Data/Balance/SkillGemSupports.dat",
		"Data/Balance/SupportGems.dat",
		"Data/Balance/TrapTools.dat",
		"Data/Balance/UncutGems.dat",
		"Data/Balance/UncutGemTiers.dat",
		"Data/Balance/PassiveSkillTrees.dat",
		"Data/Balance/PassiveSkillTreeUiArt.dat",
		"Data/Balance/BlightCraftingTypes.dat",
		"Data/Balance/BlightCraftingRecipes.dat",
		"Data/Balance/BlightCraftingResults.dat",
		"Data/Balance/BlightCraftingItems.dat",
		"Data/Balance/ItemSpirit.dat",
		"Data/Balance/ItemInherentSkills.dat",
		"Data/Balance/StartingPassiveSkills.dat",
		"Data/Balance/ClassPassiveSkillOverrides.dat",
		"Data/Balance/AscendancyPassiveSkillOverrides.dat",
		"Data/Balance/PassiveJewelArt.dat",
		"Data/Balance/PassiveJewelRadiiArt.dat",
		"Data/Balance/PassiveJewelUniqueArt.dat",
		"Data/Balance/PassiveNodeTypes.dat",
		"Data/Balance/PassiveSkillTypes.dat",
		"Data/Balance/QuestStaticRewards.dat",
		"Data/Balance/QuestFlags.dat",
		"Data/Balance/Quest.dat",
		"Data/Balance/QuestType.dat",
		"Data/Balance/QuestRewards.dat",
		"Data/Balance/QuestRewardOffers.dat",
		"Data/Balance/QuestRewardType.dat",
		"Data/Balance/WieldableClasses.dat",
		"Data/Balance/ActiveSkillWeaponRequirement.dat",
		"Data/Balance/SkillGemSearchTerms.dat",
		"Data/Balance/PassiveSkillTreeNodeFrameArt.dat",
		"Data/Balance/PassiveSkillTreeConnectionArt.dat",
		"Data/Balance/PassiveSkillTreeMasteryArt.dat",
		"Data/Balance/PlayerMinionIntrinsicStats.dat",
		"Data/Balance/MonsterCategories.dat",
		"Data/Balance/ActiveSkillRequirements.dat",
		"Data/Balance/ArchnemesisMods.dat",
		"Data/Balance/MonsterPackEntries.dat",
		"Data/Balance/MonsterPacks.dat",
		"Data/Balance/WorldAreas.dat",
		"Data/Balance/SpectreOverrides.dat",
		"Data/Balance/MonsterProjectileAttack.dat",
		"Data/Balance/MonsterProjectileSpell.dat",
		"Data/Balance/MonsterMortar.dat",
		"Data/Balance/EndGameMaps.dat",
		"Data/Balance/EndGameMapBiomes.dat",
		"Data/Balance/EndGameMapPins.dat",
		"Data/Balance/EndGameMapContentSet.dat",
		"Data/Balance/EndGameMapContent.dat",
		"Data/Balance/EndGameMapLocation.dat",
		"Data/Balance/StrongBoxPacks.dat",
		"Data/Balance/SkillArtVariations.dat",
		"Data/Balance/MiscAnimated.dat",
		"Data/Balance/MiscAnimatedArtVariations.dat",
		"Data/Balance/MiscBeams.dat",
		"Data/Balance/MiscBeamsArtVariations.dat",
		"Data/Balance/MiscEffectPacksArtVariations.dat",
		"Data/Balance/MiscObjects.dat",
		"Data/Balance/MiscObjectsArtVariations.dat",
		"Data/Balance/ProjectilesArtVariations.dat",
		"Data/Balance/MonsterVarietiesArtVariations.dat",
		"Data/Balance/MiscProjectileMod.dat",
		"Data/Balance/MiscProjectileModArtVariations.dat",
		"Data/Balance/MiscParticles.dat",
		"Data/Balance/MiscParticlesArtVariations.dat",
		"Data/Balance/MonsterVarietiesArtVariations.dat",
		"Data/Balance/PreloadGroups.dat",
		"Data/Balance/MiscEffectPacks.dat",
		"Data/Balance/BallisticBounceOverride.dat",
		"Data/Balance/DamageEffectVariations.dat",
		"Data/Balance/AttackSkillDamageScalingType.dat",
		"Data/Balance/AttackSkillDamageScalingValues.dat",
		"Data/Balance/FlatPhysicalDamageValues.dat",
		"Data/Balance/SupportGemFamily.dat",
		"Data/Balance/TormentSpirits.dat",
		"Data/Balance/CharacterShapeshiftBasicSkills.dat",
	}
	local csdFiles = {
		"^Data/StatDescriptions/specific_skill_stat_descriptions/\\w+.csd$",
		"^Data/StatDescriptions/\\w+.csd$",
		"^Data/StatDescriptions/specific_skill_stat_descriptions/\\w+/\\w+.csd$",
	}
	local otFiles = {
		"^Metadata/Monsters/(?:[\\w-]+/)*[\\w-]+\\.ot$",
		"^Metadata/Characters/(?:[\\w-]+/)*[\\w-]+\\.ot$",
	}
	local itFiles = {
		"Metadata/Items/Equipment.it",
		"Metadata/Items/Item.it",
		"Metadata/Items/Incursion2/Arm.it",
		"Metadata/Items/Incursion2/Leg.it",
		"Metadata/Items/Weapons/AbstractWeapon.it",
		"Metadata/Items/Weapons/TwoHandWeapons/AbstractTwoHandWeapon.it",
		"Metadata/Items/Weapons/TwoHandWeapons/TwoHandSwords/StormbladeTwoHand.it",
		"Metadata/Items/Weapons/TwoHandWeapons/TwoHandSwords/AbstractTwoHandSword.it",
		"Metadata/Items/Weapons/TwoHandWeapons/TwoHandMaces/AbstractTwoHandMace.it",
		"Metadata/Items/Weapons/TwoHandWeapons/TwoHandAxes/AbstractTwoHandAxe.it",
		"Metadata/Items/Weapons/TwoHandWeapons/Staves/AbstractWarstaff.it",
		"Metadata/Items/Weapons/TwoHandWeapons/FishingRods/AbstractFishingRod.it",
		"Metadata/Items/Weapons/TwoHandWeapons/Crossbows/AbstractCrossbow.it",
		"Metadata/Items/Weapons/TwoHandWeapons/TwoHandTalismans/AbstractTalisman.it",
		"Metadata/Items/Weapons/TwoHandWeapons/Bows/AbstractBow.it",
		"Metadata/Items/Weapons/OneHandWeapons/AbstractOneHandWeapon.it",
		"Metadata/Items/Weapons/OneHandWeapons/Spears/AbstractSpear.it",
		"Metadata/Items/Weapons/OneHandWeapons/OneHandSwords/StormbladeOneHand.it",
		"Metadata/Items/Weapons/OneHandWeapons/OneHandSwords/AbstractOneHandSword.it",
		"Metadata/Items/Weapons/OneHandWeapons/OneHandMaces/AbstractOneHandMace.it",
		"Metadata/Items/Weapons/OneHandWeapons/OneHandAxes/AbstractOneHandAxe.it",
		"Metadata/Items/Weapons/OneHandWeapons/Flail/AbstractFlail.it",
		"Metadata/Items/Weapons/OneHandWeapons/Daggers/AbstractDagger.it",
		"Metadata/Items/Weapons/OneHandWeapons/Claws/AbstractClaw.it",
		"Metadata/Items/Wands/AbstractWand.it",
		"Metadata/Items/TrapTools/AbstractTrapTool.it",
		"Metadata/Items/Staves/AbstractStaff.it",
		"Metadata/Items/SoulCores/AbstractSoulCore.it",
		"Metadata/Items/Sceptres/AbstractSceptre.it",
		"Metadata/Items/Rings/AbstractRing.it",
		"Metadata/Items/Quivers/AbstractQuiver.it",
		"Metadata/Items/Jewels/AbstractJewel.it",
		"Metadata/Items/Flasks/AbstractUtilityFlask.it",
		"Metadata/Items/Flasks/AbstractManaFlask.it",
		"Metadata/Items/Flasks/AbstractLifeFlask.it",
		"Metadata/Items/Flasks/AbstractFlask.it",
		"Metadata/Items/Belts/AbstractBelt.it",
		"Metadata/Items/Armours/AbstractArmour.it",
		"Metadata/Items/Armours/Shields/AbstractShield.it",
		"Metadata/Items/Armours/Shields/AbstractBuckler.it",
		"Metadata/Items/Armours/Helmets/AbstractHelmet.it",
		"Metadata/Items/Armours/Gloves/AbstractGloves.it",
		"Metadata/Items/Armours/Focus/AbstractFocus.it",
		"Metadata/Items/Armours/Boots/AbstractBoots.it",
		"Metadata/Items/Armours/BodyArmours/AbstractBodyArmour.it",
		"Metadata/Items/Amulets/AbstractAmulet.it",
	}
	
	return datFiles, csdFiles, otFiles, itFiles
end
