describe("ModStore EvalMod", function()
	before_each(function()
		newBuild()
	end)

	it("evaluates Multiplier and MultiplierThreshold tags", function()
		local modDB = build.calcsTab.mainEnv.modDB
		modDB:AddMod(modLib.createMod("Multiplier:CustomMultiplier", "BASE", 2, "Test"))
		modDB:AddMod(modLib.createMod("Multiplier:OtherMultiplier", "BASE", 3, "Test"))
		modDB:AddMod(modLib.createMod("Multiplier:Divisor", "BASE", 2, "Test"))
		modDB.actor.player = modDB.actor
		modDB.actor.enemy = { modDB = new("ModDB"):ModDB() }
		modDB.actor.enemy.modDB.actor = modDB.actor.enemy
		modDB.actor.enemy.modDB:AddMod(modLib.createMod("Multiplier:CustomMultiplier", "BASE", 4, "Test"))
		modDB.actor.enemy.modDB:AddMod(modLib.createMod("Multiplier:EnemyLimit", "BASE", 1, "Test"))

		assert.are.equal(20, modDB:EvalMod(modLib.createMod("Test", "BASE", 10, "Test", { type = "Multiplier", var = "CustomMultiplier" })))
		assert.are.equal(10, modDB:EvalMod(modLib.createMod("Test", "BASE", 10, "Test", { type = "Multiplier", var = "CustomMultiplier", limit = 1 })))
		modDB:AddMod(modLib.createMod("Multiplier:CustomLimit", "BASE", 1, "Test"))
		assert.are.equal(10, modDB:EvalMod(modLib.createMod("Test", "BASE", 10, "Test", { type = "Multiplier", var = "CustomMultiplier", limitVar = "CustomLimit" })))
		assert.are.equal(40, modDB:EvalMod(modLib.createMod("Test", "BASE", 10, "Test", { type = "Multiplier", var = "CustomMultiplier", actor = "enemy" })))
		assert.are.equal(10, modDB:EvalMod(modLib.createMod("Test", "BASE", 10, "Test", { type = "Multiplier", var = "CustomMultiplier", limitActor = "enemy", limitVar = "EnemyLimit" })))
		assert.is_nil(modDB:EvalMod(modLib.createMod("Test", "BASE", 10, "Test", { type = "Multiplier", var = "CustomMultiplier", limitActor = "missingActor", limit = 1 })))
		assert.are.equal(10, modDB:EvalMod(modLib.createMod("Test", "BASE", 10, "Test", { type = "Multiplier", var = "CustomMultiplier", divVar = "Divisor" })))
		assert.are.equal(50, modDB:EvalMod(modLib.createMod("Test", "BASE", 10, "Test", { type = "Multiplier", varList = { "CustomMultiplier", "OtherMultiplier" }, base = 0 })))
		assert.are.equal(15, modDB:EvalMod(modLib.createMod("Test", "BASE", 10, "Test", { type = "Multiplier", var = "CustomMultiplier", div = 2, base = 5 })))
		assert.are.equal(10, modDB:EvalMod(modLib.createMod("Test", "BASE", 10, "Test", { type = "Multiplier", var = "OtherMultiplier", div = 2 })))
		modDB:AddMod(modLib.createMod("Multiplier:NegativeMultiplier", "BASE", -3, "Test"))
		assert.are.equal(-30, modDB:EvalMod(modLib.createMod("Test", "BASE", 10, "Test", { type = "Multiplier", var = "NegativeMultiplier", limit = 2 })))
		assert.are.equal(1.5, modDB:EvalMod(modLib.createMod("Test", "BASE", 10, "Test", { type = "Multiplier", var = "CustomMultiplier", limit = 1.5, limitTotal = true })))
		assert.are.equal(20, modDB:EvalMod(modLib.createMod("Test", "BASE", 10, "Test", { type = "Multiplier", var = "CustomMultiplier", limit = 1, limitNegTotal = true })))
		assert.are.equal(-15, modDB:EvalMod(modLib.createMod("Test", "BASE", -10, "Test", { type = "Multiplier", var = "CustomMultiplier", limit = -15, limitNegTotal = true })))
		assert.are.equal(5, modDB:EvalMod(modLib.createMod("Test", "BASE", 10, "Test", { type = "Multiplier", var = "CustomMultiplier", invert = true })))
		assert.are.equal(20, modDB:EvalMod(modLib.createMod("Test", "BASE", 10, "Test", { type = "Multiplier", var = "CustomMultiplier", actor = "player" })))
		assert.are.equal(10, modDB:EvalMod(modLib.createMod("Test", "BASE", 10, "Test", { type = "MultiplierThreshold", var = "CustomMultiplier", threshold = 2 })))
		assert.is_nil(modDB:EvalMod(modLib.createMod("Test", "BASE", 10, "Test", { type = "MultiplierThreshold", var = "CustomMultiplier", threshold = 3 })))
		assert.are.equal(10, modDB:EvalMod(modLib.createMod("Test", "BASE", 10, "Test", { type = "MultiplierThreshold", varList = { "MissingMultiplier", "CustomMultiplier" }, threshold = 2 })))
		assert.are.equal(10, modDB:EvalMod(modLib.createMod("Test", "BASE", 10, "Test", { type = "MultiplierThreshold", var = "CustomMultiplier", threshold = 2, upper = true })))
		assert.are.equal(10, modDB:EvalMod(modLib.createMod("Test", "BASE", 10, "Test", { type = "MultiplierThreshold", var = "CustomMultiplier", actor = "enemy", thresholdActor = "enemy", thresholdVar = "EnemyLimit" })))
		assert.is_nil(modDB:EvalMod(modLib.createMod("Test", "BASE", 10, "Test", { type = "MultiplierThreshold", var = "CustomMultiplier", actor = "enemy", thresholdActor = "enemy", thresholdVar = "EnemyLimit", upper = true })))
		assert.is_nil(modDB:EvalMod(modLib.createMod("Test", "BASE", 10, "Test", { type = "MultiplierThreshold", var = "CustomMultiplier", thresholdActor = "missingActor", threshold = 2 })))
	end)

	it("evaluates PerStat, PercentStat, and StatThreshold tags", function()
		local modDB = build.calcsTab.mainEnv.modDB
		modDB.actor.output = { Life = 100, Mana = 50, Devotion = 150, Str = 20, Dex = 30 }
		modDB.actor.parent = { output = { Life = 200 }, modDB = new("ModDB"):ModDB() }
		modDB.actor.parent.modDB.actor = modDB.actor.parent
		modDB.actor.parent.modDB:AddMod(modLib.createMod("Multiplier:ParentMultiplier", "BASE", 2, "Test"))
		modDB:AddMod(modLib.createMod("Multiplier:Divisor", "BASE", 2, "Test"))

		assert.are.equal(10, modDB:EvalMod(modLib.createMod("Test", "BASE", 1, "Test", { type = "PerStat", stat = "Life", div = 10 })))
		assert.are.equal(5, modDB:EvalMod(modLib.createMod("Test", "BASE", 1, "Test", { type = "PerStat", statList = { "Str", "Dex" }, div = 10 })))
		assert.are.equal(20, modDB:EvalMod(modLib.createMod("Test", "BASE", 1, "Test", { type = "PerStat", stat = "Life", div = 10, actor = "parent" })))
		assert.are.equal(50, modDB:EvalMod(modLib.createMod("Test", "BASE", 1, "Test", { type = "PerStat", stat = "Life", divVar = "Divisor" })))
		assert.are.equal(15, modDB:EvalMod(modLib.createMod("Test", "BASE", 2, "Test", { type = "PerStat", stat = "Life", div = 10, limit = 15, limitTotal = true })))
		assert.are.equal(10, modDB:EvalMod(modLib.createMod("Test", "BASE", 1, "Test", { type = "PerStat", stat = "Life", div = 1, limit = 10 })))
		modDB:AddMod(modLib.createMod("Multiplier:PerStatLimit", "BASE", 12, "Test"))
		assert.are.equal(12, modDB:EvalMod(modLib.createMod("Test", "BASE", 1, "Test", { type = "PerStat", stat = "Life", div = 1, limitVar = "PerStatLimit" })))
		assert.are.equal(50, modDB:EvalMod(modLib.createMod("Test", "BASE", 1, "Test", { type = "PercentStat", stat = "Life", percent = 50 })))
		assert.are.equal(25, modDB:EvalMod(modLib.createMod("Test", "BASE", 1, "Test", { type = "PercentStat", statList = { "Str", "Dex" }, percent = 50 })))
		modDB:AddMod(modLib.createMod("Multiplier:CustomPercent", "BASE", 25, "Test"))
		assert.are.equal(13, modDB:EvalMod(modLib.createMod("Test", "BASE", 1, "Test", { type = "PercentStat", stat = "Mana", percentVar = "CustomPercent" })))
		modDB:AddMod(modLib.createMod("Multiplier:PercentStatLimit", "BASE", 10, "Test"))
		assert.are.equal(10, modDB:EvalMod(modLib.createMod("Test", "BASE", 1, "Test", { type = "PercentStat", stat = "Mana", percentVar = "CustomPercent", limitVar = "PercentStatLimit" })))
		assert.are.equal(25, modDB:EvalMod(modLib.createMod("Test", "BASE", 1, "Test", { type = "PercentStat", stat = "Mana", percent = 50, floor = true })))
		assert.are.equal(20, modDB:EvalMod(modLib.createMod("Test", "BASE", 1, "Test", { type = "PercentStat", stat = "Life", percent = 50, limit = 20 })))
		assert.are.equal(10, modDB:EvalMod(modLib.createMod("Test", "BASE", 10, "Test", { type = "StatThreshold", stat = "Devotion", threshold = 100 })))
		assert.is_nil(modDB:EvalMod(modLib.createMod("Test", "BASE", 10, "Test", { type = "StatThreshold", stat = "Devotion", threshold = 200 })))
		assert.are.equal(10, modDB:EvalMod(modLib.createMod("Test", "BASE", 10, "Test", { type = "StatThreshold", stat = "Devotion", threshold = 150, upper = true })))
		assert.is_nil(modDB:EvalMod(modLib.createMod("Test", "BASE", 10, "Test", { type = "StatThreshold", stat = "Devotion", threshold = 100, upper = true })))
		assert.are.equal(10, modDB:EvalMod(modLib.createMod("Test", "BASE", 10, "Test", { type = "StatThreshold", statList = { "Str", "Dex" }, threshold = 40 })))
		assert.are.equal(10, modDB:EvalMod(modLib.createMod("Test", "BASE", 10, "Test", { type = "StatThreshold", stat = "Life", thresholdStat = "Mana", thresholdPercent = 100 })))
		modDB:AddMod(modLib.createMod("Multiplier:ThresholdPercent", "BASE", 200, "Test"))
		assert.are.equal(10, modDB:EvalMod(modLib.createMod("Test", "BASE", 10, "Test", { type = "StatThreshold", stat = "Life", thresholdStat = "Mana", thresholdPercentVar = "ThresholdPercent" })))
	end)

	it("evaluates DistanceRamp tags", function()
		local modDB = build.calcsTab.mainEnv.modDB
		local ramp = { { 0, 1 }, { 10, 2 }, { 20, 4 } }

		assert.are.equal(10, modDB:EvalMod(modLib.createMod("Test", "BASE", 10, "Test", { type = "DistanceRamp", ramp = ramp }), { skillDist = -5 }))
		assert.are.equal(15, modDB:EvalMod(modLib.createMod("Test", "BASE", 10, "Test", { type = "DistanceRamp", ramp = ramp }), { skillDist = 5 }))
		assert.are.equal(20, modDB:EvalMod(modLib.createMod("Test", "BASE", 10, "Test", { type = "DistanceRamp", ramp = ramp }), { skillDist = 10 }))
		assert.are.equal(30, modDB:EvalMod(modLib.createMod("Test", "BASE", 10, "Test", { type = "DistanceRamp", ramp = ramp }), { skillDist = 15 }))
		assert.are.equal(10, modDB:EvalMod(modLib.createMod("Test", "BASE", 10, "Test", { type = "DistanceRamp", ramp = ramp }), { skillDist = 0 }))
		assert.are.equal(40, modDB:EvalMod(modLib.createMod("Test", "BASE", 10, "Test", { type = "DistanceRamp", ramp = ramp }), { skillDist = 20 }))
		assert.are.equal(40, modDB:EvalMod(modLib.createMod("Test", "BASE", 10, "Test", { type = "DistanceRamp", ramp = ramp }), { skillDist = 25 }))
		assert.is_nil(modDB:EvalMod(modLib.createMod("Test", "BASE", 10, "Test", { type = "DistanceRamp", ramp = ramp }), { skillDist = false }))
		assert.is_nil(modDB:EvalMod(modLib.createMod("Test", "BASE", 10, "Test", { type = "DistanceRamp", ramp = ramp })))
	end)

	it("evaluates Limit tags", function()
		local modDB = build.calcsTab.mainEnv.modDB

		assert.are.equal(5, modDB:EvalMod(modLib.createMod("Test", "BASE", 10, "Test", { type = "Limit", limit = 5 })))
		assert.are.equal(-5, modDB:EvalMod(modLib.createMod("Test", "BASE", -10, "Test", { type = "Limit", limit = 5, neg = true })))
		modDB:AddMod(modLib.createMod("Multiplier:LimitMultiplier", "BASE", 3, "Test"))
		assert.are.equal(3, modDB:EvalMod(modLib.createMod("Test", "BASE", 10, "Test", { type = "Limit", limitVar = "LimitMultiplier" })))
	end)

	it("short-circuits failed tags and evaluates table values", function()
		local modDB = build.calcsTab.mainEnv.modDB
		modDB.conditions.TableCondition = true
		local mod = modLib.createMod("Test", "BASE", { value = 10 }, "Test", { type = "Condition", var = "TableCondition" })
		local result = modDB:EvalMod(mod)

		assert.are.equal(10, result.value)
		assert.is_nil(modDB:EvalMod(modLib.createMod("Test", "BASE", 10, "Test",
			{ type = "Condition", var = "MissingCondition" },
			{ type = "Limit", limit = 5 }
		)))
	end)

	it("evaluates Condition and ActorCondition tags", function()
		local modDB = build.calcsTab.mainEnv.modDB
		modDB.conditions.CustomCondition = true
		modDB.conditions.OtherCondition = true
		modDB.actor.enemy = { modDB = new("ModDB"):ModDB() }
		modDB.actor.enemy.actor = modDB.actor.enemy
		modDB.actor.enemy.modDB.conditions.CustomEnemyCondition = true
		modDB.actor.enemy.modDB.conditions.OtherEnemyCondition = true

		assert.are.equal(10, modDB:EvalMod(modLib.createMod("Test", "BASE", 10, "Test", { type = "Condition", var = "CustomCondition" })))
		assert.are.equal(10, modDB:EvalMod(modLib.createMod("Test", "BASE", 10, "Test", { type = "Condition", var = "ConfigSkillCondition" }), { skillCond = { ConfigSkillCondition = true } }))
		assert.is_nil(modDB:EvalMod(modLib.createMod("Test", "BASE", 10, "Test", { type = "Condition", var = "CustomCondition" }), { overrideCond = { CustomCondition = false } }))
		assert.are.equal(10, modDB:EvalMod(modLib.createMod("Test", "BASE", 10, "Test", { type = "Condition", var = "MissingCondition" }), { overrideCond = { MissingCondition = true } }))
		assert.are.equal(10, modDB:EvalMod(modLib.createMod("Test", "BASE", 10, "Test", { type = "Condition", varList = { "MissingCondition", "CustomCondition" } })))
		assert.is_nil(modDB:EvalMod(modLib.createMod("Test", "BASE", 10, "Test", { type = "Condition", var = "CustomCondition", neg = true })))
		assert.are.equal(10, modDB:EvalMod(modLib.createMod("Test", "BASE", 10, "Test", { type = "Condition", var = "MissingCondition", neg = true })))
		assert.is_nil(modDB:EvalMod(modLib.createMod("Test", "BASE", 10, "Test", { type = "Condition", var = "MissingCondition" })))
		modDB.actor.weaponData1 = { countsAsAll1H = true, AddedCustomWeaponCondition = false }
		assert.is_nil(modDB:EvalMod(modLib.createMod("Test", "BASE", 10, "Test", { type = "Condition", var = "CustomWeaponCondition", neg = true })))
		modDB.actor.weaponData1.AddedCustomWeaponCondition = true
		assert.are.equal(10, modDB:EvalMod(modLib.createMod("Test", "BASE", 10, "Test", { type = "Condition", var = "CustomWeaponCondition", neg = true })))
		modDB.actor.weaponData1 = nil
		assert.are.equal(10, modDB:EvalMod(modLib.createMod("Test", "BASE", 10, "Test", { type = "ActorCondition", actor = "enemy", var = "CustomEnemyCondition" })))
		assert.are.equal(10, modDB:EvalMod(modLib.createMod("Test", "BASE", 10, "Test", { type = "ActorCondition", actor = "enemy", varList = { "MissingEnemyCondition", "OtherEnemyCondition" } })))
		assert.are.equal(10, modDB:EvalMod(modLib.createMod("Test", "BASE", 10, "Test", { type = "ActorCondition", actor = "otherActor" }), { actor = "otherActor" }))
		assert.is_nil(modDB:EvalMod(modLib.createMod("Test", "BASE", 10, "Test", { type = "ActorCondition", actor = "otherActor", neg = true }), { actor = "otherActor" }))
		assert.are.equal(10, modDB:EvalMod(modLib.createMod("Test", "BASE", 10, "Test", { type = "ActorCondition", actor = "party", neg = true }), { actor = "other" }))
		assert.is_nil(modDB:EvalMod(modLib.createMod("Test", "BASE", 10, "Test", { type = "ActorCondition", actor = "enemy", var = "MissingCondition" })))
	end)

	it("evaluates ItemCondition tags", function()
		local modDB = build.calcsTab.mainEnv.modDB
		local function matchingItem(slot, rarity, itemType)
			return {
				rarity = rarity,
				name = slot == "Ring 1" and "Kalandra's Touch" or "Test " .. slot,
				type = itemType,
				corrupted = true,
				FindModifierSubstring = function(_, searchCond, slot)
					return searchCond == "shared modifier" or (searchCond == "jewel only" and slot == "jewel")
				end,
			}
		end
		modDB.actor.itemList = {
			["Body Armour"] = {
				rarity = "NORMAL",
				name = "Test Body Armour",
				corrupted = true,
				FindModifierSubstring = function(_, searchCond)
					return searchCond == "armour test"
				end,
			},
			["Ring 1"] = matchingItem("Ring 1", "UNIQUE"),
			["Ring 2"] = matchingItem("Ring 2", "MAGIC"),
			["Jewel"] = matchingItem("Jewel", "UNIQUE", "Jewel"),
		}

		assert.are.equal(10, modDB:EvalMod(modLib.createMod("Test", "BASE", 10, "Test", { type = "ItemCondition", itemSlot = "Body Armour", rarityCond = "NORMAL" })))
		assert.are.equal(10, modDB:EvalMod(modLib.createMod("Test", "BASE", 10, "Test", { type = "ItemCondition", itemSlot = "Body Armour", corruptedCond = true })))
		assert.are.equal(10, modDB:EvalMod(modLib.createMod("Test", "BASE", 10, "Test", { type = "ItemCondition", itemSlot = "Body Armour", searchCond = "armour test" })))
		assert.are.equal(10, modDB:EvalMod(modLib.createMod("Test", "BASE", 10, "Test", { type = "ItemCondition", itemSlot = "Body Armour", rarityCond = "UNIQUE", neg = true })))
		assert.are.equal(10, modDB:EvalMod(modLib.createMod("Test", "BASE", 10, "Test", { type = "ItemCondition", allSlots = true })))
		assert.are.equal(10, modDB:EvalMod(modLib.createMod("Test", "BASE", 10, "Test", { type = "ItemCondition", itemSlot = "Ring", bothSlots = true, rarityCond = "MAGIC" })))
		assert.are.equal(10, modDB:EvalMod(modLib.createMod("Test", "BASE", 10, "Test", { type = "ItemCondition", itemSlot = "Ring 1", rarityCond = "MAGIC" })))
		assert.are.equal(10, modDB:EvalMod(modLib.createMod("Test", "BASE", 10, "Test", { type = "ItemCondition", itemSlot = "Amulet", rarityCond = "NORMAL" }), { item = { rarity = "NORMAL", name = "Config Item" } }))
		assert.are.equal(10, modDB:EvalMod(modLib.createMod("Test", "BASE", 10, "Test", { type = "ItemCondition", itemSlot = "Body Armour", allSlots = true, excludeSelf = true, searchCond = "shared modifier" })))
		assert.is_nil(modDB:EvalMod(modLib.createMod("Test", "BASE", 10, "Test", { type = "ItemCondition", itemSlot = "Body Armour", allSlots = true, excludeSelf = true, searchCond = "jewel only" })))
		assert.is_nil(modDB:EvalMod(modLib.createMod("Test", "BASE", 10, "Test", { type = "ItemCondition", itemSlot = "Body Armour", allSlots = true, excludeSelf = true, searchCond = "shared modifier", neg = true })))
		assert.is_nil(modDB:EvalMod(modLib.createMod("Test", "BASE", 10, "Test", { type = "ItemCondition", itemSlot = "Amulet", bothSlots = true, rarityCond = "MAGIC" })))
		assert.is_nil(modDB:EvalMod(modLib.createMod("Test", "BASE", 10, "Test", { type = "ItemCondition", itemSlot = "Body Armour", rarityCond = "UNIQUE" })))
		assert.is_nil(modDB:EvalMod(modLib.createMod("Test", "BASE", 10, "Test", { type = "ItemCondition", itemSlot = "Body Armour", searchCond = "missing" })))
	end)

	it("evaluates SocketedIn tags", function()
		local modDB = build.calcsTab.mainEnv.modDB
		local cfg = {
			slotName = "Body Armour",
			socketColor = "R",
			socketNum = 1,
			strengthGems = 1,
			dexterityGems = 0,
			intelligenceGems = 0,
			skillGem = {
				name = "Fireball",
				tags = { fire = true },
				gemData = { name = "Fireball", tags = { fire = true } },
			},
		}

		assert.are.equal(10, modDB:EvalMod(modLib.createMod("Test", "BASE", 10, "Test", { type = "SocketedIn", slotName = "Body Armour" }), cfg))
		assert.are.equal(10, modDB:EvalMod(modLib.createMod("Test", "BASE", 10, "Test", { type = "SocketedIn", keyword = "fire" }), cfg))
		assert.are.equal(10, modDB:EvalMod(modLib.createMod("Test", "BASE", 10, "Test", { type = "SocketedIn", socketColor = "R" }), cfg))
		assert.are.equal(10, modDB:EvalMod(modLib.createMod("Test", "BASE", 10, "Test", { type = "SocketedIn", socketColor = "R", sockets = { 1, 2 } }), cfg))
		assert.are.equal(10, modDB:EvalMod(modLib.createMod("Test", "BASE", 10, "Test", { type = "SocketedIn", socketColor = "R", sockets = 2 }), cfg))
		assert.are.equal(10, modDB:EvalMod(modLib.createMod("Test", "BASE", 10, "Test", { type = "SocketedIn", socketColor = "R", sockets = "all" }), cfg))
		assert.is_nil(modDB:EvalMod(modLib.createMod("Test", "BASE", 10, "Test", { type = "SocketedIn", keyword = "cold" }), cfg))
		assert.is_nil(modDB:EvalMod(modLib.createMod("Test", "BASE", 10, "Test", { type = "SocketedIn", socketColor = "R", sockets = 1 }), cfg))
		assert.is_nil(modDB:EvalMod(modLib.createMod("Test", "BASE", 10, "Test", { type = "SocketedIn", socketColor = "R", neg = true }), cfg))
		assert.is_nil(modDB:EvalMod(modLib.createMod("Test", "BASE", 10, "Test", { type = "SocketedIn", slotName = "Body Armour" })))
		assert.are.equal(10, modDB:EvalMod(modLib.createMod("Test", "BASE", 10, "Test", { type = "SocketedIn", slotType = "Body Armour" }), cfg))
		assert.is_nil(modDB:EvalMod(modLib.createMod("Test", "BASE", 10, "Test", { type = "SocketedIn", slotName = "Helmet" }), cfg))
		assert.are.equal(10, modDB:EvalMod(modLib.createMod("Test", "BASE", 10, "Test", { type = "SocketedIn", socketColor = "G", neg = true }), cfg))
	end)

	it("evaluates skill and gem context tags", function()
		local modDB = build.calcsTab.mainEnv.modDB
		local cfg = {
			skillName = "Fireball",
			summonSkillName = "Summon Wolf",
			skillGrantedEffect = { id = "Fireball" },
			skillPart = 2,
			skillTypes = { [SkillType.Spell] = true, [SkillType.Attack] = true },
			skillGem = { tags = { fire = true, spell = true } },
		}

		assert.are.equal(10, modDB:EvalMod(modLib.createMod("Test", "BASE", 10, "Test", { type = "SkillName", skillName = "Fireball" }), cfg))
		assert.are.equal(10, modDB:EvalMod(modLib.createMod("Test", "BASE", 10, "Test", { type = "SkillName", skillName = "fIrEbAlL" }), cfg))
		assert.are.equal(10, modDB:EvalMod(modLib.createMod("Test", "BASE", 10, "Test", { type = "SkillName", skillName = "Fireball", includeTransfigured = true }), cfg))
		assert.are.equal(10, modDB:EvalMod(modLib.createMod("Test", "BASE", 10, "Test", { type = "SkillName", skillNameList = { "Fireball" }, includeTransfigured = true }), cfg))
		assert.are.equal(10, modDB:EvalMod(modLib.createMod("Test", "BASE", 10, "Test", { type = "SkillName", skillNameList = { "Iceball", "Fireball" } }), cfg))
		assert.are.equal(10, modDB:EvalMod(modLib.createMod("Test", "BASE", 10, "Test", { type = "SkillName", skillName = "Fire", partialMatch = true }), cfg))
		assert.are.equal(10, modDB:EvalMod(modLib.createMod("Test", "BASE", 10, "Test", { type = "SkillName", skillName = "Summon Wolf", summonSkill = true }), cfg))
		assert.are.equal(10, modDB:EvalMod(modLib.createMod("Test", "BASE", 10, "Test", { type = "SkillName", skillName = "Iceball", neg = true }), cfg))
		assert.are.equal(10, modDB:EvalMod(modLib.createMod("Test", "BASE", 10, "Test", { type = "SkillId", skillId = "Fireball" }), cfg))
		assert.are.equal(10, modDB:EvalMod(modLib.createMod("Test", "BASE", 10, "Test", { type = "SkillId", skillId = "Other", neg = true }), cfg))
		assert.are.equal(10, modDB:EvalMod(modLib.createMod("Test", "BASE", 10, "Test", { type = "SkillPart", skillPart = 2 }), cfg))
		assert.are.equal(10, modDB:EvalMod(modLib.createMod("Test", "BASE", 10, "Test", { type = "SkillPart", skillPartList = { 1, 2 } }), cfg))
		assert.are.equal(10, modDB:EvalMod(modLib.createMod("Test", "BASE", 10, "Test", { type = "SkillType", skillType = SkillType.Spell }), cfg))
		assert.are.equal(10, modDB:EvalMod(modLib.createMod("Test", "BASE", 10, "Test", { type = "SkillType", skillTypeList = { SkillType.Melee, SkillType.Attack } }), cfg))
		assert.are.equal(10, modDB:EvalMod(modLib.createMod("Test", "BASE", 10, "Test", { type = "SkillType", skillType = SkillType.Melee, neg = true }), cfg))
		assert.are.equal(10, modDB:EvalMod(modLib.createMod("Test", "BASE", 10, "Test", { type = "GemTag", gemTag = "Fire" }), cfg))
		assert.are.equal(10, modDB:EvalMod(modLib.createMod("Test", "BASE", 10, "Test", { type = "GemTag", gemTagList = { "Cold", "Fire" } }), cfg))
		assert.are.equal(10, modDB:EvalMod(modLib.createMod("Test", "BASE", 10, "Test", { type = "GemTag", gemTag = "Cold", neg = true }), cfg))
		assert.are.equal(10, modDB:EvalMod(modLib.createMod("Test", "BASE", 10, "Test", { type = "SkillName", skillName = "Fireball", neg = true })))
		assert.are.equal(10, modDB:EvalMod(modLib.createMod("Test", "BASE", 10, "Test", { type = "SkillId", skillId = "Fireball", neg = true })))
		assert.are.equal(10, modDB:EvalMod(modLib.createMod("Test", "BASE", 10, "Test", { type = "SkillPart", skillPart = 2, neg = true })))
		assert.are.equal(10, modDB:EvalMod(modLib.createMod("Test", "BASE", 10, "Test", { type = "SkillType", skillType = SkillType.Spell, neg = true })))
		assert.are.equal(10, modDB:EvalMod(modLib.createMod("Test", "BASE", 10, "Test", { type = "GemTag", gemTag = "Fire", neg = true })))
		assert.is_nil(modDB:EvalMod(modLib.createMod("Test", "BASE", 10, "Test", { type = "GemTag", gemTag = "Fire" }), { skillGem = { tags = {} } }))
	end)

	it("evaluates BaseFlag, SlotName, ModFlagOr, and KeywordFlagAnd tags", function()
		local modDB = build.calcsTab.mainEnv.modDB
		local cfg = {
			baseFlags = { projectile = true },
			skillGem = { grantedEffect = { statSets = { { baseFlags = { projectile = true, nested = true } } } } },
			slotName = "Helmet",
			flags = ModFlag.Attack,
			keywordFlags = KeywordFlag.Fire + KeywordFlag.Cold,
		}

		assert.are.equal(10, modDB:EvalMod(modLib.createMod("Test", "BASE", 10, "Test", { type = "BaseFlag", baseFlag = "projectile" }), cfg))
		assert.are.equal(10, modDB:EvalMod(modLib.createMod("Test", "BASE", 10, "Test", { type = "BaseFlag", baseFlag = "nested" }), cfg))
		assert.are.equal(10, modDB:EvalMod(modLib.createMod("Test", "BASE", 10, "Test", { type = "BaseFlag", baseFlag = "missing", neg = true }), cfg))
		assert.are.equal(10, modDB:EvalMod(modLib.createMod("Test", "BASE", 10, "Test", { type = "SlotName", slotName = "Helmet" }), cfg))
		assert.are.equal(10, modDB:EvalMod(modLib.createMod("Test", "BASE", 10, "Test", { type = "SlotName", slotNameList = { "Gloves", "Helmet" } }), cfg))
		assert.is_nil(modDB:EvalMod(modLib.createMod("Test", "BASE", 10, "Test", { type = "SlotName", slotName = "Helmet", neg = true }), cfg))
		assert.are.equal(10, modDB:EvalMod(modLib.createMod("Test", "BASE", 10, "Test", { type = "ModFlagOr", modFlags = ModFlag.Attack }), cfg))
		assert.is_nil(modDB:EvalMod(modLib.createMod("Test", "BASE", 10, "Test", { type = "ModFlagOr", modFlags = ModFlag.Spell }), cfg))
		assert.is_nil(modDB:EvalMod(modLib.createMod("Test", "BASE", 10, "Test", { type = "ModFlagOr", modFlags = ModFlag.Attack })))
		assert.are.equal(10, modDB:EvalMod(modLib.createMod("Test", "BASE", 10, "Test", { type = "KeywordFlagAnd", keywordFlags = KeywordFlag.Fire }), cfg))
		assert.is_nil(modDB:EvalMod(modLib.createMod("Test", "BASE", 10, "Test", { type = "KeywordFlagAnd", keywordFlags = KeywordFlag.Lightning }), cfg))
		assert.is_nil(modDB:EvalMod(modLib.createMod("Test", "BASE", 10, "Test", { type = "KeywordFlagAnd", keywordFlags = KeywordFlag.Fire + KeywordFlag.Lightning }), cfg))
		assert.is_nil(modDB:EvalMod(modLib.createMod("Test", "BASE", 10, "Test", { type = "KeywordFlagAnd", keywordFlags = KeywordFlag.Fire })))
	end)

	it("evaluates MonsterTag tags", function()
		local modDB = build.calcsTab.mainEnv.modDB
		modDB.actor.minionData = { monsterTags = { "Beast", "Undead" } }

		assert.are.equal(10, modDB:EvalMod(modLib.createMod("Test", "BASE", 10, "Test", { type = "MonsterTag", monsterTag = "Undead" })))
		assert.are.equal(10, modDB:EvalMod(modLib.createMod("Test", "BASE", 10, "Test", { type = "MonsterTag", monsterTag = "uNdEaD" })))
		assert.are.equal(10, modDB:EvalMod(modLib.createMod("Test", "BASE", 10, "Test", { type = "MonsterTag", monsterTagList = { "Demon", "Undead" } })))
		assert.is_nil(modDB:EvalMod(modLib.createMod("Test", "BASE", 10, "Test", { type = "MonsterTag", monsterTagList = { "Demon", "Human" } })))
		assert.are.equal(10, modDB:EvalMod(modLib.createMod("Test", "BASE", 10, "Test", { type = "MonsterTag", monsterTag = "Demon", neg = true })))
		modDB.actor.minionData.monsterTags = {}
		assert.are.equal(10, modDB:EvalMod(modLib.createMod("Test", "BASE", 10, "Test", { type = "MonsterTag", monsterTag = "Undead", neg = true })))
		assert.is_nil(modDB:EvalMod(modLib.createMod("Test", "BASE", 10, "Test", { type = "MonsterTag", monsterTag = "Demon" })))
	end)

	it("applies global limits after evaluating tags", function()
		local modDB = build.calcsTab.mainEnv.modDB
		local mod = modLib.createMod("Test", "BASE", 7, "Test", {
			type = "Multiplier",
			var = "CustomMultiplier",
			globalLimit = 5,
			globalLimitKey = "Damage",
		})
		local limits = { Damage = 0 }

		modDB:AddMod(modLib.createMod("Multiplier:CustomMultiplier", "BASE", 2, "Test"))
		assert.are.equal(5, modDB:EvalMod(mod, nil, limits))
		assert.are.equal(5, limits.Damage)

		local multiLimitMod = modLib.createMod("Test", "BASE", 7, "Test",
			{ globalLimit = 5, globalLimitKey = "Damage" },
			{ globalLimit = 10, globalLimitKey = "Damage" }
		)
		local multiLimits = { Damage = 0 }
		assert.are.equal(5, modDB:EvalMod(multiLimitMod, nil, multiLimits))
		assert.are.equal(10, multiLimits.Damage)
	end)

end)
