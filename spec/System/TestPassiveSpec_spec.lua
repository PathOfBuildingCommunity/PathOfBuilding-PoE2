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
