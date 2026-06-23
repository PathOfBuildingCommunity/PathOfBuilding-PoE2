-- Tests for Facebreaker-style gloves: empty-handed gloves that grant their own base
-- weapon damage and let you attack as though using a One Hand Mace.
describe("TestFacebreaker", function()
	before_each(function()
		newBuild()
	end)

	teardown(function()
		-- newBuild() takes care of resetting everything in setup()
	end)

	-- Physical variant (Facebreaker)
	local function equipFacebreaker()
		build.itemsTab:CreateDisplayItemFromRaw([[
			New Item
			Stocky Mitts
			Has 8 to 12 Physical damage, +3 to +4 per Boss's Face Broken
			Can Attack as though using a One Handed Mace while both of your hand slots are empty
			Unarmed Attacks that would use an Equipped One Hand Mace's damage use this Item's damage
		]])
		build.itemsTab:AddDisplayItem()
		runCallback("OnFrame")
	end

	it("grants its base Physical damage to Unarmed attacks", function()
		equipFacebreaker()
		local weaponData1 = build.calcsTab.mainEnv.player.weaponData1
		assert.are.equals(8, weaponData1.FacebreakerPhysicalMin)
		assert.are.equals(12, weaponData1.FacebreakerPhysicalMax)
	end)

	it("lets you attack as though using a One Hand Mace while unarmed", function()
		equipFacebreaker()
		local weaponData1 = build.calcsTab.mainEnv.player.weaponData1
		assert.is_true(weaponData1.asThoughUsing ~= nil and weaponData1.asThoughUsing["One Hand Mace"] == true)
	end)

	it("scales its base damage per Boss's Face Broken", function()
		equipFacebreaker()
		build.configTab.input.configBossFaceBroken = 10
		build.configTab:BuildModList()
		runCallback("OnFrame")
		local weaponData1 = build.calcsTab.mainEnv.player.weaponData1
		-- 8 base + 3 per face broken * 10, 12 base + 4 per face broken * 10
		assert.are.equals(8 + 3 * 10, weaponData1.FacebreakerPhysicalMin)
		assert.are.equals(12 + 4 * 10, weaponData1.FacebreakerPhysicalMax)
	end)

	it("matches the in-game resolved damage at 60 Boss's Faces Broken (188-252)", function()
		-- Real in-game Facebreaker shows "Physical Damage: 188-252" at 60 Boss's Faces Broken
		equipFacebreaker()
		build.configTab.input.configBossFaceBroken = 60
		build.configTab:BuildModList()
		runCallback("OnFrame")
		build.skillsTab:PasteSocketGroup("Boneshatter 1/0  1")
		runCallback("OnFrame")
		build.calcsTab:BuildOutput()
		runCallback("OnFrame")
		local mainHand = build.calcsTab.mainOutput.MainHand
		assert.are.equals(188, mainHand.PhysicalMinBase)
		assert.are.equals(252, mainHand.PhysicalMaxBase)
	end)

	it("makes One Hand Mace skills usable unarmed and applies 'more Unarmed Damage per Strength' to them", function()
		build.itemsTab:CreateDisplayItemFromRaw([[
			New Item
			Stocky Mitts
			Has 8 to 12 Physical damage, +3 to +4 per Boss's Face Broken
			1% more Unarmed Damage per 5 Strength
			Can Attack as though using a One Handed Mace while both of your hand slots are empty
			Unarmed Attacks that would use an Equipped One Hand Mace's damage use this Item's damage
		]])
		build.itemsTab:AddDisplayItem()
		-- strip enemy Armour so the small base damage still resolves to a positive hit
		build.configTab.input.customMods = "Nearby Enemies have 100% less Armour"
		build.configTab:BuildModList()
		runCallback("OnFrame")
		-- Boneshatter requires a One/Two Hand Mace (no "None"): only usable unarmed thanks to Facebreaker
		build.skillsTab:PasteSocketGroup("Boneshatter 1/0  1")
		runCallback("OnFrame")
		build.calcsTab:BuildOutput()
		runCallback("OnFrame")
		local mainSkill = build.calcsTab.mainEnv.player.mainSkill
		assert.is_truthy(mainSkill)
		-- the Mace-only skill resolves to a real (unarmed) attack producing a positive hit
		assert.are.equals("Boneshatter", mainSkill.activeEffect.grantedEffect.name)
		assert.is_truthy(build.calcsTab.mainOutput.MainHand)
		assert.is_true(build.calcsTab.mainOutput.MainHand.AverageHit > 0)
		local modDB = build.calcsTab.mainEnv.player.modDB
		-- 'more Unarmed Damage per 5 Strength' applies to unarmed Hits (which is what Facebreaker mace attacks are)...
		assert.is_true(modDB:Sum("MORE", { flags = ModFlag.Unarmed + ModFlag.Hit }, "Damage") > 0)
		-- ...but not to actual weapon (e.g. Sword) Hits
		assert.are.equals(0, modDB:Sum("MORE", { flags = ModFlag.Sword + ModFlag.Hit }, "Damage"))
	end)

	it("auto-imports the Boss's Faces Broken count from character quest stats", function()
		build.importTab:ImportQuestRewardConfig({ "57 [BrokenFace|Broken Boss Faces]" })
		assert.is_nil(build.configTab.input.configBossFaceBroken)
		assert.are.equals(57, build.configTab.placeholder.configBossFaceBroken)
	end)

	it("supports the Fire damage variant", function()
		build.itemsTab:CreateDisplayItemFromRaw([[
			New Item
			Stocky Mitts
			Has 9 to 14 Fire damage, +3 to +5 per Boss's Face Broken
			Can Attack as though using a One Handed Mace while both of your hand slots are empty
			Unarmed Attacks that would use an Equipped One Hand Mace's damage use this Item's damage
		]])
		build.itemsTab:AddDisplayItem()
		runCallback("OnFrame")
		local weaponData1 = build.calcsTab.mainEnv.player.weaponData1
		assert.are.equals(9, weaponData1.FacebreakerFireMin)
		assert.are.equals(14, weaponData1.FacebreakerFireMax)
	end)

	it("uses Facebreaker item damage instead of Hollow Palm added Physical damage for mace-compatible staff skills", function()
		equipFacebreaker()
		build.configTab.input.customMods = "Hollow Palm Technique"
		build.configTab:BuildModList()
		runCallback("OnFrame")
		build.skillsTab:PasteSocketGroup("Rain of Blades 1/0  1")
		runCallback("OnFrame")
		local skillModList = build.calcsTab.mainEnv.player.mainSkill.skillModList
		assert.are.equals(0, skillModList:Sum("BASE", { flags = ModFlag.Attack }, "PhysicalMin"))
		assert.are.equals(0, skillModList:Sum("BASE", { flags = ModFlag.Attack }, "PhysicalMax"))
	end)

	it("keeps Hollow Palm added Physical damage for quarterstaff-only skills", function()
		equipFacebreaker()
		build.configTab.input.customMods = "Hollow Palm Technique"
		build.configTab:BuildModList()
		runCallback("OnFrame")
		build.skillsTab:PasteSocketGroup("Quarterstaff Strike 1/0  1")
		runCallback("OnFrame")
		local skillModList = build.calcsTab.mainEnv.player.mainSkill.skillModList
		assert.is_true(skillModList:Sum("BASE", { flags = ModFlag.Attack }, "PhysicalMin") > 0)
		assert.is_true(skillModList:Sum("BASE", { flags = ModFlag.Attack }, "PhysicalMax") > 0)
	end)
end)
