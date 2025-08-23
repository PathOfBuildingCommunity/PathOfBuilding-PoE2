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
		self.oozPath = io.popen("cd"):read('*l'):gsub('\r?', '') .. "\\ggpk\\"
		self:CleanDir(reExport)
		self:ExtractFiles(reExport)
	end

	self.dat = { }
	self.txt = { }

	if USE_DAT64 then
		self:AddDat64Files()
	else
		self:AddDatFiles()
	end
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

function GGPKClass:ExtractFiles(reExport)
	if reExport then
		local datList, csdList, itList = self:GetNeededFiles()
		local sweetSpotCharacter = 6000
		local fileList = ''

		for _, fname in ipairs(datList) do
			if USE_DAT64 then
				fileList = fileList .. '"' .. fname .. 'c64" '
			else
				fileList = fileList .. '"' .. fname .. '" '
			end

			if fileList:len() > sweetSpotCharacter then
				self:ExtractFilesWithBun(fileList)
				fileList = ''
			end
		end

		for _, fname in ipairs(itList) do
			fileList = fileList .. '"' .. fname .. '" '

			if fileList:len() > sweetSpotCharacter then
				self:ExtractFilesWithBun(fileList)
				fileList = ''
			end
		end

		if (fileList:len() > 0) then
			self:ExtractFilesWithBun(fileList)
			fileList = ''
		end

		-- Special handling for stat descriptions (CSD) as they
		-- are regex based
		for _, fname in ipairs(csdList) do
			self:ExtractFilesWithBun('"' .. fname .. '"', true)
		end
	end

	-- Overwrite Enums
	local errMsg = PLoadModule("Scripts/enums.lua")
	if errMsg then
		print(errMsg)
	end
end

function GGPKClass:AddDatFiles()
	local datFiles = scanDir(self.oozPath .. "Data\\", '%w+%.dat$')
	for _, f in ipairs(datFiles) do
		local record = { }
		record.name = f
		local rawFile = io.open(self.oozPath .. "Data\\" .. f, 'rb')
		record.data = rawFile:read("*all")
		rawFile:close()
		--ConPrintf("FILENAME: %s", fname)
		t_insert(self.dat, record)
	end
end

function GGPKClass:AddDat64Files()
	local datFiles = scanDir(self.oozPath .. "Data\\", '%w+%.datc64$')
	for _, f in ipairs(datFiles) do
		local record = { }
		record.name = f
		local rawFile = io.open(self.oozPath .. "Data\\" .. f, 'rb')
		record.data = rawFile:read("*all")
		rawFile:close()
		--ConPrintf("FILENAME: %s", fname)
		t_insert(self.dat, record)
	end
end

function GGPKClass:GetNeededFiles()
	local datFiles = {
		"Data/Stats.dat",
		"Data/VirtualStatContextFlags.dat",
		"Data/BaseItemTypes.dat",
		"Data/WeaponTypes.dat",
		"Data/ArmourTypes.dat",
		"Data/ShieldTypes.dat",
		"Data/Flasks.dat",
		"Data/ComponentCharges.dat",
		"Data/PassiveSkills.dat",
		"Data/PassiveSkillStatCategories.dat",
		"Data/PassiveSkillMasteryGroups.dat",
		"Data/PassiveSkillMasteryEffects.dat",
		"Data/PassiveTreeExpansionJewelSizes.dat",
		"Data/PassiveTreeExpansionJewels.dat",
		"Data/PassiveJewelSlots.dat",
		"Data/PassiveTreeExpansionSkills.dat",
		"Data/PassiveTreeExpansionSpecialSkills.dat",
		"Data/Mods.dat",
		"Data/ModType.dat",
		"Data/ModFamily.dat",
		"Data/ModSellPriceTypes.dat",
		"Data/ModEffectStats.dat",
		"Data/ActiveSkills.dat",
		"Data/ActiveSkillType.dat",
		"Data/AlternateSkillTargetingBehaviours.dat",
		"Data/Ascendancy.dat",
		"Data/ClientStrings.dat",
		"Data/FlavourText.dat",
		"Data/Words.dat",
		"Data/ItemClasses.dat",
		"Data/SkillTotemVariations.dat",
		"Data/Essences.dat",
		"Data/EssenceType.dat",
		"Data/Characters.dat",
		"Data/BuffDefinitions.dat",
		"Data/BuffTemplates.dat",
		"Data/BuffVisuals.dat",
		"Data/BuffVisualSetEntries.dat",
		"Data/BuffVisualsArtVariations.dat",
		"Data/BuffVisualOrbs.dat",
		"Data/BuffVisualOrbTypes.dat",
		"Data/GenericBuffAuras.dat",
		"Data/AddBuffToTargetVarieties.dat",
		"Data/HideoutNPCs.dat",
		"Data/NPCs.dat",
		"Data/CraftingBenchOptions.dat",
		"Data/CraftingItemClassCategories.dat",
		"Data/CraftingBenchUnlockCategories.dat",
		"Data/CraftingBenchSortCategories.dat",
		"Data/MonsterVarieties.dat",
		"Data/MonsterResistances.dat",
		"Data/MonsterTypes.dat",
		"Data/DefaultMonsterStats.dat",
		"Data/SkillGems.dat",
		"Data/GrantedEffects.dat",
		"Data/GrantedEffectsPerLevel.dat",
		"Data/ItemExperiencePerLevel.dat",
		"Data/EffectivenessCostConstants.dat",
		"Data/Tags.dat",
		"Data/GemTags.dat",
		"Data/ItemVisualIdentity.dat",
		"Data/AchievementItems.dat",
		"Data/MultiPartAchievements.dat",
		"Data/PantheonPanelLayout.dat",
		"Data/AlternatePassiveAdditions.dat",
		"Data/AlternatePassiveSkills.dat",
		"Data/AlternateTreeVersions.dat",
		"Data/GrantedEffectQualityStats.dat",
		"Data/AegisVariations.dat",
		"Data/CostTypes.dat",
		"Data/PassiveJewelRadii.dat",
		"Data/SoundEffects.dat",
		"Data/MavenJewelRadiusKeystones.dat",
		"Data/TableCharge.dat",
		"Data/GrantedEffectStatSets.dat",
		"Data/GrantedEffectStatSetsPerLevel.dat",
		"Data/MonsterMapDifficulty.dat",
		"Data/MonsterMapBossDifficulty.dat",
		"Data/ReminderText.dat",
		"Data/Projectiles.dat",
		"Data/ItemExperienceTypes.dat",
		"Data/UniqueStashLayout.dat",
		"Data/UniqueStashTypes.dat",
		"Data/Shrines.dat",
		"Data/PassiveOverrideLimits.dat",
		"Data/PassiveSkillOverrides.dat",
		"Data/PassiveSkillOverrideTypes.dat",
		"Data/DisplayMinionMonsterType.dat",
		"Data/GemEffects.dat",
		"Data/ActionTypes.dat",
		"Data/IndexableSupportGems.dat",
		"Data/ItemClassCategories.dat",
		"Data/MinionType.dat",
		"Data/SummonedSpecificMonsters.dat",
		"Data/GameConstants.dat",
		"Data/AlternateQualityTypes.dat",
		"Data/WeaponClasses.dat",
		"Data/MonsterConditions.dat",
		"Data/Rarity.dat",
		"Data/TradeMarketCategory.dat",
		"Data/TradeMarketCategoryGroups.dat",
		"Data/PlayerTradeWhisperFormats.dat",
		"Data/TradeMarketCategoryListAllClass.dat",
		"Data/TradeMarketIndexItemAs.dat",
		"Data/TradeMarketImplicitModDisplay.dat",
		"Data/Commands.dat",
		"Data/ModEquivalencies.dat",
		"Data/InfluenceTags.dat",
		"Data/AttributeRequirements.dat",
		"Data/GrantedEffectLabels.dat",
		"Data/ItemInherentSkills.dat",
		"Data/KeywordPopups.dat",
		"Data/SoulCores.dat",
		"Data/SoulCoresPerClass.dat",
		"Data/UtilityFlaskBuffs.dat",
		"Data/GrantedSkillSocketNumbers.dat",
		"Data/AdvancedCraftingBenchCustomTags.dat",
		"Data/AdvancedCraftingBenchTabFilterTypes.dat",
		"Data/CharacterMeleeSkills.dat",
		"Data/ClientStrings2.dat",
		"Data/CraftableModTypes.dat",
		"Data/DamageCalculationTypes.dat",
		"Data/EndgameCorruptionMods.dat",
		"Data/GoldInherentSkillPricesPerLevel.dat",
		"Data/GoldModPrices.dat",
		"Data/GoldRespecPrices.dat",
		"Data/HideoutResistPenalties.dat",
		"Data/MinionGemLevelScaling.dat",
		"Data/MinionStats.dat",
		"Data/ModGrantedSkills.dat",
		"Data/PassiveJewelNodeModifyingStats.dat",
		"Data/ResistancePenaltyPerAreaLevel.dat",
		"Data/ShapeShiftForms.dat",
		"Data/SkillGemsForUniqueStat.dat",
		"Data/SkillGemSupports.dat",
		"Data/SupportGems.dat",
		"Data/TrapTools.dat",
		"Data/UncutGemAdditionalTiers.dat",
		"Data/UncutGemTiers.dat",
		"Data/PassiveSkillTrees.dat",
		"Data/PassiveSkillTreeUiArt.dat",
		"Data/BlightCraftingTypes.dat",
		"Data/BlightCraftingRecipes.dat",
		"Data/BlightCraftingResults.dat",
		"Data/BlightCraftingItems.dat",
		"Data/ItemSpirit.dat",
		"Data/ItemInherentSkills.dat",
		"Data/StartingPassiveSkills.dat",
		"Data/ClassPassiveSkillOverrides.dat",
		"Data/PassiveJewelArt.dat",
		"Data/PassiveJewelUniqueArt.dat",
		"Data/QuestStaticRewards.dat",
		"Data/QuestFlags.dat",
		"Data/Quest.dat",
		"Data/QuestType.dat",
		"Data/QuestRewards.dat",
		"Data/QuestRewardOffers.dat",
		"Data/QuestRewardType.dat",
		"Data/WieldableClasses.dat",
		"Data/ActiveSkillWeaponRequirement.dat",
		"Data/SkillGemSearchTerms.dat",
		"Data/PassiveNodeUIArtOverride.dat",
		"Data/PlayerMinionIntrinsicStats.dat",
		"Data/MonsterCategories.dat",
		"Data/ActiveSkillRequirements.dat",
		"Data/ArchnemesisMods.dat",
		"Data/MonsterPackEntries.dat",
		"Data/MonsterPacks.dat",
		"Data/WorldAreas.dat",
		"Data/SpectreOverrides.dat",
		"Data/MonsterProjectileAttack.dat",
		"Data/MonsterProjectileSpell.dat",
		"Data/MonsterMortar.dat",
		"Data/EndGameMaps.dat",
		"Data/EndGameMapBiomes.dat",
		"Data/EndGameMapPins.dat",
		"Data/EndGameMapContentSet.dat",
		"Data/EndGameMapContent.dat",
		"Data/EndGameMapLocation.dat",
		"Data/StrongBoxPacks.dat",
		"Data/SkillArtVariations.dat",
		"Data/MiscAnimated.dat",
		"Data/MiscAnimatedArtVariations.dat",
		"Data/MiscBeams.dat",
		"Data/MiscBeamsArtVariations.dat",
		"Data/MiscEffectPacksArtVariations.dat",
		"Data/MiscObjects.dat",
		"Data/MiscObjectsArtVariations.dat",
		"Data/ProjectilesArtVariations.dat",
		"Data/MonsterVarietiesArtVariations.dat",
		"Data/MiscProjectileMod.dat",
		"Data/MiscProjectileModArtVariations.dat",
		"Data/MiscParticles.dat",
		"Data/MiscParticlesArtVariations.dat",
		"Data/MonsterVarietiesArtVariations.dat",
		"Data/PreloadGroups.dat",
		"Data/MiscEffectPacks.dat",
		"Data/BallisticBounceOverride.dat",
		"Data/DamageEffectVariations.dat",
	}
	local csdFiles = {
		"^Metadata/StatDescriptions/specific_skill_stat_descriptions/\\w+.csd$",
		"^Metadata/StatDescriptions/\\w+.csd$",
		"^Metadata/StatDescriptions/specific_skill_stat_descriptions/\\w+/\\w+.csd$",
	}
	local itFiles = {
		"Metadata/Items/Equipment.it",
		"Metadata/Items/Item.it",
		"Metadata/Items/Weapons/AbstractWeapon.it",
		"Metadata/Items/Weapons/TwoHandWeapons/AbstractTwoHandWeapon.it",
		"Metadata/Items/Weapons/TwoHandWeapons/TwoHandSwords/StormbladeTwoHand.it",
		"Metadata/Items/Weapons/TwoHandWeapons/TwoHandSwords/AbstractTwoHandSword.it",
		"Metadata/Items/Weapons/TwoHandWeapons/TwoHandMaces/AbstractTwoHandMace.it",
		"Metadata/Items/Weapons/TwoHandWeapons/TwoHandAxes/AbstractTwoHandAxe.it",
		"Metadata/Items/Weapons/TwoHandWeapons/Staves/AbstractWarstaff.it",
		"Metadata/Items/Weapons/TwoHandWeapons/FishingRods/AbstractFishingRod.it",
		"Metadata/Items/Weapons/TwoHandWeapons/Crossbows/AbstractCrossbow.it",
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
	return datFiles, csdFiles, itFiles
end
