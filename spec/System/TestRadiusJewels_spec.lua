describe("TestRadiusJewels", function()
	before_each(function()
		newBuild()
	end)

	it("copies cached Time-Lost radius mods before adding weapon set conditions", function()
		GlobalCache.cachedData.MAIN.radiusJewelData = nil

		local function addTimeLostMana(node, modList)
			if node.type == "Normal" then
				modList:NewMod("Mana", "INC", 1, "Tree:500")
			end
		end

		local env = {
			mode = "MAIN",
			radiusJewelList = {
				{
					type = "Other",
					nodeId = 500,
					jewelHash = "time-lost-mana",
					item = { baseName = "Time-Lost Diamond" },
					nodes = {
						[100] = { type = "Normal" },
						[101] = { type = "Normal" },
					},
					func = addTimeLostMana,
					data = { },
				},
			},
			allocNodes = {
				[100] = true,
				[101] = true,
			},
			build = {
				spec = {
					nodes = {
						[500] = { allocMode = 0 },
					},
				},
				itemsTab = {
					activeItemSet = {
						useSecondWeaponSet = false,
					},
				},
			},
			explodeSources = { },
		}
		local weaponSetNode = {
			id = 100,
			type = "Normal",
			allocMode = 2,
			modList = new("ModList"),
		}
		local globalNode = {
			id = 101,
			type = "Normal",
			allocMode = 0,
			modList = new("ModList"),
		}

		local weaponSetModList = build.calcsTab.calcs.buildModListForNode(env, weaponSetNode, 0)
		assert.is_not_nil(weaponSetModList[1][1])
		assert.equals("WeaponSet2", weaponSetModList[1][1].var)

		local globalModList = build.calcsTab.calcs.buildModListForNode(env, globalNode, 0)
		assert.is_nil(globalModList[1][1])

		assert.is_not_nil(weaponSetModList[1][1])
		assert.equals("WeaponSet2", weaponSetModList[1][1].var)
	end)
end)
