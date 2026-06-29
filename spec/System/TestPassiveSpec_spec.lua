describe("TestPassiveSpec", function()
	before_each(function()
		newBuild()
	end)

	local function firstLoadedSocketNode(spec)
		for nodeId in pairs(spec.tree.sockets) do
			if spec.nodes[nodeId] then
				return nodeId
			end
		end
	end

	local function findNodeByName(spec, name)
		for nodeId, node in pairs(spec.nodes) do
			if node.name == name or node.dn == name then
				return nodeId, node
			end
		end
	end

	local function firstNormalJewelSocket(spec)
		for nodeId, node in pairs(spec.nodes) do
			if node.isJewelSocket and node.name == "Jewel Socket" then
				return nodeId, node
			end
		end
	end

	local function normalJewelSockets(spec, count)
		local sockets = { }
		for nodeId, node in pairs(spec.nodes) do
			if node.isJewelSocket and node.name == "Jewel Socket" then
				table.insert(sockets, { nodeId = nodeId, node = node })
			end
		end
		table.sort(sockets, function(a, b) return a.nodeId < b.nodeId end)
		if count then
			while #sockets > count do
				table.remove(sockets)
			end
		end
		return sockets
	end

	local function makeAmulet(rawMod)
		local item = new("Item", [[
Rarity: RARE
Test Locket
Gold Amulet
--------
Item Level: 80
--------
]] .. (rawMod or "") .. [[
]])
		return item
	end

	local function makeCustomAmulet(rawMod)
		local item = makeAmulet(rawMod)
		build.itemsTab:AddItem(item, true)
		build.itemsTab.slots["Amulet"]:SetSelItemId(item.id)
		build.buildFlag = true
		return item
	end

	local function socketJewel(nodeId, raw)
		local item = new("Item", raw)
		build.itemsTab:AddItem(item, true)
		build.spec.jewels[nodeId] = item.id
		if build.itemsTab.sockets[nodeId] then
			build.itemsTab.sockets[nodeId]:SetSelItemId(item.id)
		end
		build.buildFlag = true
		return item
	end

	local function socketIntJewel(nodeId)
		return socketJewel(nodeId, [[
Rarity: RARE
Test Mind
Sapphire
--------
Item Level: 80
--------
+10 to Intelligence
]])
	end

	it("ignores stale jewel socket item ids when loading saved builds", function()
		local spec = new("PassiveSpec", build, latestTreeVersion)
		local socketNodeId = firstLoadedSocketNode(spec)

		spec:Load({
			attrib = { title = "Stale Socket Test" },
			{
				elem = "Sockets",
				{
					elem = "Socket",
					attrib = {
						nodeId = tostring(socketNodeId),
						itemId = "999999",
					}
				}
			}
		}, "stale_socket.xml")

		assert.is_nil(spec.jewels[socketNodeId])
	end)

	it("does not crash when radius helpers see a stale jewel socket item id", function()
		local spec = new("PassiveSpec", build, latestTreeVersion)
		local socketNodeId = firstLoadedSocketNode(spec)
		spec.jewels[socketNodeId] = 999999

		local ok, err = pcall(function()
			return spec:NodesInIntuitiveLeapLikeRadius(spec.nodes[socketNodeId])
		end)

		assert.is_true(ok, err)
	end)

	it("grants Zarokh's Gift as an active free sinister jewel socket from item mods", function()
		makeCustomAmulet("Allocates Zarokh's Gift")
		runCallback("OnFrame")

		local nodeId, node = findNodeByName(build.spec, "Zarokh's Gift")
		assert.is_not_nil(nodeId)
		assert.is_true(node.isJewelSocket)
		assert.is_not_nil(build.spec.allocNodes[nodeId])
		assert.is_true(build.spec.allocNodes[nodeId].isFreeAllocate)
		assert.is_true(build.spec.allocNodes[nodeId].isGrantedPassive)
		assert.is_not_nil(build.itemsTab.sockets[nodeId])
		assert.is_false(build.itemsTab.sockets[nodeId].inactive)

		local pointsUsed = build.spec:CountAllocNodes()
		assert.are.equals(0, pointsUsed)

		local xml = { }
		build.spec:Save(xml)
		local savedNodeIds = { }
		for savedNodeId in xml.attrib.nodes:gmatch("%d+") do
			savedNodeIds[tonumber(savedNodeId)] = true
		end
		assert.is_nil(savedNodeIds[nodeId])
	end)

	it("jewel socketed in item-granted Zarokh's Gift contributes in the same recompute", function()
		makeCustomAmulet("Allocates Zarokh's Gift")
		runCallback("OnFrame")

		local nodeId = assert(findNodeByName(build.spec, "Zarokh's Gift"))
		local beforeInt = build.calcsTab.mainOutput.Int or 0

		socketJewel(nodeId, [[
Rarity: RARE
Test Mind
Sapphire
--------
Item Level: 80
--------
+10 to Intelligence
]])
		runCallback("OnFrame")

		assert.True((build.calcsTab.mainOutput.Int or 0) >= beforeInt + 10)
	end)

	it("calculator replacement without Zarokh's Gift ignores jewels in stale granted sockets", function()
		makeCustomAmulet("Allocates Zarokh's Gift")
		runCallback("OnFrame")

		local nodeId = assert(findNodeByName(build.spec, "Zarokh's Gift"))
		socketIntJewel(nodeId)
		runCallback("OnFrame")

		local intWithSocket = build.calcsTab.mainOutput.Int or 0
		local calcFunc = build.calcsTab:GetMiscCalculator()
		local output = calcFunc({ repSlotName = "Amulet", repItem = makeAmulet("") }, false)

		assert.are.equals(intWithSocket - 10, output.Int or 0)
		assert.is_not_nil(build.spec.allocNodes[nodeId])
	end)

	it("calculator replacement granting Zarokh's Gift uses socket jewels without mutating the build spec", function()
		makeCustomAmulet("")
		runCallback("OnFrame")

		local nodeId = assert(findNodeByName(build.spec, "Zarokh's Gift"))
		local baseInt = build.calcsTab.mainOutput.Int or 0
		assert.is_nil(build.spec.allocNodes[nodeId])

		socketIntJewel(nodeId)
		runCallback("OnFrame")
		assert.are.equals(baseInt, build.calcsTab.mainOutput.Int or 0)

		local calcFunc = build.calcsTab:GetMiscCalculator()
		local output = calcFunc({ repSlotName = "Amulet", repItem = makeAmulet("Allocates Zarokh's Gift") }, false)

		assert.are.equals(baseInt + 10, output.Int or 0)
		assert.is_nil(build.spec.allocNodes[nodeId])
	end)

	it("does not allow unique jewels in item-granted Zarokh's Gift", function()
		makeCustomAmulet("Allocates Zarokh's Gift")
		runCallback("OnFrame")

		local nodeId = assert(findNodeByName(build.spec, "Zarokh's Gift"))
		local voices = new("Item", [[
Rarity: UNIQUE
Voices
Sapphire
--------
Limited to: 1
Allocates 2 Sinister Jewel sockets
Corrupted
]])
		build.itemsTab:AddItem(voices, true)

		assert.is_false(build.itemsTab:IsItemValidForSlot(voices, "Jewel " .. nodeId))

		build.spec.jewels[nodeId] = voices.id
		build.itemsTab.sockets[nodeId]:SetSelItemId(voices.id)
		build.buildFlag = true
		runCallback("OnFrame")

		assert.is_nil(build.spec.allocNodes[62152])
		assert.is_nil(build.spec.allocNodes[26178])
	end)

	it("resolves Voices sinister socket grants by alias order", function()
		local nodes = build.spec:ResolveGrantedPassiveNodes("3 sinister jewel sockets")
		assert.are.equals(3, #nodes)
		assert.are.equals("voices_jewel_slot1", nodes[1].aliasPassiveSocket)
		assert.are.equals("voices_jewel_slot2", nodes[2].aliasPassiveSocket)
		assert.are.equals("voices_jewel_slot3__", nodes[3].aliasPassiveSocket)
	end)

	it("Voices grants free Sinister Jewel sockets from an active tree jewel", function()
		local hostNodeId, hostNode = firstNormalJewelSocket(build.spec)
		build.spec:AllocNode(hostNode)
		socketJewel(hostNodeId, [[
Rarity: UNIQUE
Voices
Sapphire
--------
Limited to: 1
Allocates 3 Sinister Jewel sockets
Corrupted
]])

		runCallback("OnFrame")

		local activeSinister = { }
		for _, node in pairs(build.spec.allocNodes) do
			if node.name == "Sinister Jewel Socket" then
				activeSinister[node.aliasPassiveSocket] = true
				assert.is_true(node.isFreeAllocate)
			end
		end
		assert.is_true(activeSinister["voices_jewel_slot1"])
		assert.is_true(activeSinister["voices_jewel_slot2"])
		assert.is_true(activeSinister["voices_jewel_slot3__"])
		assert.is_nil(activeSinister["voices_jewel_slot4"])
	end)

	it("removes Voices-granted sockets when the Voices jewel is removed", function()
		local hostNodeId, hostNode = firstNormalJewelSocket(build.spec)
		build.spec:AllocNode(hostNode)
		socketJewel(hostNodeId, [[
Rarity: UNIQUE
Voices
Sapphire
--------
Limited to: 1
Allocates 2 Sinister Jewel sockets
Corrupted
]])
		runCallback("OnFrame")
		assert.is_not_nil(build.spec.allocNodes[62152])

		build.spec.jewels[hostNodeId] = 0
		if build.itemsTab.sockets[hostNodeId] then
			build.itemsTab.sockets[hostNodeId]:SetSelItemId(0)
		end
		build.buildFlag = true
		runCallback("OnFrame")

		assert.is_nil(build.spec.allocNodes[62152])
		assert.is_nil(build.spec.allocNodes[26178])
	end)

	it("does not remove a user-allocated passive when an item grant goes away", function()
		local nodeId, node = findNodeByName(build.spec, "Acceleration")
		assert.is_not_nil(nodeId)
		build.spec:AllocNode(node)
		local pointsUsed = build.spec:CountAllocNodes()
		assert.is_true(pointsUsed > 0)

		makeCustomAmulet("Allocates Acceleration")
		runCallback("OnFrame")
		assert.is_not_nil(build.spec.allocNodes[nodeId])
		assert.is_nil(build.spec.allocNodes[nodeId].isFreeAllocate)

		build.itemsTab.slots["Amulet"]:SetSelItemId(0)
		build.buildFlag = true
		runCallback("OnFrame")

		assert.is_not_nil(build.spec.allocNodes[nodeId])
		assert.are.equals(pointsUsed, build.spec:CountAllocNodes())
	end)

	it("does not persist ordinary anoint notables as granted tree allocations", function()
		local nodeId = assert(findNodeByName(build.spec, "Acceleration"))
		runCallback("OnFrame")
		assert.are.equals(1, build.calcsTab.mainOutput.MovementSpeedMod)

		makeCustomAmulet("Allocates Acceleration")
		runCallback("OnFrame")

		assert.is_nil(build.spec.allocNodes[nodeId])
		assert.is_true(build.calcsTab.mainEnv.grantedPassives[nodeId])
		assert.are.equals(1.03, build.calcsTab.mainOutput.MovementSpeedMod)
	end)

	it("anoint tooltip comparison includes jewels in a prospective Zarokh's Gift socket", function()
		makeCustomAmulet("")
		runCallback("OnFrame")

		local zarokhNodeId, zarokhNode = assert(findNodeByName(build.spec, "Zarokh's Gift"))
		socketIntJewel(zarokhNodeId)
		build.itemsTab.displayItem = makeAmulet("")

		local capturedBase
		local capturedNew
		local originalAddStatComparesToTooltip = build.AddStatComparesToTooltip
		build.AddStatComparesToTooltip = function(_, tooltip, outputBase, outputNew)
			capturedBase = outputBase
			capturedNew = outputNew
			return 1
		end
		build.itemsTab:AppendAnointTooltip({ AddLine = function() end }, zarokhNode)
		build.AddStatComparesToTooltip = originalAddStatComparesToTooltip

		assert.are.equals((capturedBase.Int or 0) + 10, capturedNew.Int or 0)
		assert.is_nil(build.spec.allocNodes[zarokhNodeId])
	end)

	it("removes secondary socket grants from jewels in a removed granted socket", function()
		makeCustomAmulet("Allocates Zarokh's Gift")
		runCallback("OnFrame")

		local zarokhNodeId = assert(findNodeByName(build.spec, "Zarokh's Gift"))
		socketJewel(zarokhNodeId, [[
Rarity: RARE
Test Eye
Sapphire
--------
Item Level: 80
--------
Allocates 2 Sinister Jewel sockets
]])
		runCallback("OnFrame")
		assert.is_not_nil(build.spec.allocNodes[62152])
		assert.is_not_nil(build.spec.allocNodes[26178])

		build.itemsTab.slots["Amulet"]:SetSelItemId(0)
		build.buildFlag = true
		runCallback("OnFrame")

		assert.is_nil(build.spec.allocNodes[zarokhNodeId])
		assert.is_nil(build.spec.allocNodes[62152])
		assert.is_nil(build.spec.allocNodes[26178])
	end)

	it("replaces Zarokh's Gift with an ordinary amulet anoint and removes the socket jewel effect", function()
		makeCustomAmulet("Allocates Zarokh's Gift")
		runCallback("OnFrame")

		local zarokhNodeId = assert(findNodeByName(build.spec, "Zarokh's Gift"))
		local accelerationNodeId = assert(findNodeByName(build.spec, "Acceleration"))
		local baseInt = build.calcsTab.mainOutput.Int or 0
		socketIntJewel(zarokhNodeId)
		runCallback("OnFrame")
		assert.are.equals(baseInt + 10, build.calcsTab.mainOutput.Int or 0)

		local amulet = makeAmulet("Allocates Acceleration")
		build.itemsTab:AddItem(amulet, true)
		build.itemsTab.slots["Amulet"]:SetSelItemId(amulet.id)
		build.buildFlag = true
		runCallback("OnFrame")

		assert.is_nil(build.spec.allocNodes[zarokhNodeId])
		assert.are.equals(baseInt, build.calcsTab.mainOutput.Int or 0)
		assert.is_true(build.calcsTab.mainEnv.grantedPassives[accelerationNodeId])
		assert.are.equals(1.03, build.calcsTab.mainOutput.MovementSpeedMod)
	end)

	it("ignores grants from duplicate limited Voices jewels", function()
		local sockets = normalJewelSockets(build.spec, 2)
		assert.are.equals(2, #sockets)
		build.spec:AllocNode(sockets[1].node)
		build.spec:AllocNode(sockets[2].node)
		socketJewel(sockets[1].nodeId, [[
Rarity: UNIQUE
Voices
Sapphire
--------
Limited to: 1
Allocates 2 Sinister Jewel sockets
Corrupted
]])
		socketJewel(sockets[2].nodeId, [[
Rarity: UNIQUE
Voices
Sapphire
--------
Limited to: 1
Allocates 3 Sinister Jewel sockets
Corrupted
]])

		runCallback("OnFrame")

		local activeSinister = { }
		for _, node in pairs(build.spec.allocNodes) do
			if node.name == "Sinister Jewel Socket" then
				activeSinister[node.aliasPassiveSocket] = true
			end
		end
		assert.is_true(activeSinister["voices_jewel_slot1"])
		assert.is_true(activeSinister["voices_jewel_slot2"])
		assert.is_nil(activeSinister["voices_jewel_slot3__"])
	end)

	it("jewel socketed in a Voices-granted Sinister socket contributes in the same recompute", function()
		local hostNodeId, hostNode = firstNormalJewelSocket(build.spec)
		build.spec:AllocNode(hostNode)
		socketJewel(hostNodeId, [[
Rarity: UNIQUE
Voices
Sapphire
--------
Limited to: 1
Allocates 3 Sinister Jewel sockets
Corrupted
]])
		runCallback("OnFrame")

		local beforeInt = build.calcsTab.mainOutput.Int or 0
		socketJewel(62152, [[
Rarity: RARE
Test Mind
Sapphire
--------
Item Level: 80
--------
+10 to Intelligence
]])
		runCallback("OnFrame")

		assert.True((build.calcsTab.mainOutput.Int or 0) >= beforeInt + 10)
	end)

	it("remaps legacy class ids only for trees before 0.4", function()
		local function loadClass(treeVersion, classId)
			local spec = new("PassiveSpec", build, latestTreeVersion)
			spec.treeVersion = treeVersion
			spec:Load({
				attrib = {
					title = "Legacy Class Test",
					classId = tostring(classId),
					ascendClassId = "0",
					nodes = "",
				}
			}, "legacy_class.xml")
			return spec.curClassName
		end

		assert.are.equals("Witch", loadClass("0_1", 3))
		assert.are.equals("Huntress", loadClass("0_2", 1))
		assert.are.equals("Monk", loadClass("0_3", 6))
		assert.are.equals("Witch", loadClass("0_4", 1))
	end)

	local function allocNode(spec, nodeId, allocMode)
		local node = spec.nodes[nodeId]
		spec.allocMode = allocMode
		spec:AllocNode(node)
		assert.are.equals(allocMode, node.allocMode)
		return node
	end

	it("normal passive allocation promotes the shortest path instead of using a longer detour", function()
		local spec = build.spec
		allocNode(spec, 56651, 0)
		local weaponSetNode = allocNode(spec, 38143, 1)
		assert.are.equals("Strength", weaponSetNode.dn)

		local reachableNode = spec.nodes[43923]
		assert.are.equals("Accuracy", reachableNode.dn)

		spec.allocMode = 0
		spec:AllocNode(reachableNode)

		assert.True(reachableNode.alloc)
		assert.are.equals(0, reachableNode.allocMode)
		assert.are.equals(0, weaponSetNode.allocMode)
	end)

	it("normal passive allocation promotes the weapon-set chain behind the path root", function()
		local spec = build.spec
		allocNode(spec, 56651, 0)
		allocNode(spec, 35324, 0)
		allocNode(spec, 35660, 1)
		allocNode(spec, 18548, 1)

		local promotedNode = spec.nodes[28992]
		assert.are.equals("Honed Instincts", promotedNode.dn)

		spec.allocMode = 0
		spec:AllocNode(promotedNode)

		assert.True(promotedNode.alloc)
		assert.are.equals(0, promotedNode.allocMode)
		assert.are.equals(0, spec.nodes[18548].allocMode)
		assert.are.equals(0, spec.nodes[35660].allocMode)
	end)

	it("weapon-set allocation cannot originate from another weapon set path", function()
		local spec = build.spec
		allocNode(spec, 56651, 0)
		allocNode(spec, 35324, 0)
		allocNode(spec, 35660, 1)
		allocNode(spec, 18548, 1)

		local weaponSet2Node = spec.nodes[28992]
		assert.are.equals("Honed Instincts", weaponSet2Node.dn)

		spec.allocMode = 2
		spec:AllocNode(weaponSet2Node)

		assert.True(weaponSet2Node.alloc)
		assert.are.equals(2, weaponSet2Node.allocMode)
		assert.are.equals(1, spec.nodes[18548].allocMode)
		assert.are.equals(1, spec.nodes[35660].allocMode)
	end)

	it("normal passives cannot stay connected through weapon-set-only paths", function()
		local spec = build.spec
		allocNode(spec, 56651, 0)
		allocNode(spec, 35234, 0)
		allocNode(spec, 6789, 0)
		allocNode(spec, 4313, 0)
		allocNode(spec, 28992, 0)
		allocNode(spec, 35660, 1)
		allocNode(spec, 18548, 1)

		spec:DeallocNode(spec.nodes[4313])

		assert.are_not.equals(true, spec.nodes[28992].alloc)
		assert.True(spec.nodes[35660].alloc)
		assert.True(spec.nodes[18548].alloc)
		assert.are.equals(1, spec.nodes[35660].allocMode)
		assert.are.equals(1, spec.nodes[18548].allocMode)
	end)
end)
