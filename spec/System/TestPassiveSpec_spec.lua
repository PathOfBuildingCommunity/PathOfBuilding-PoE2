describe("TestPassiveSpec", function()
	before_each(function()
		newBuild()
	end)

	local function pathContains(path, needle)
		if not path then
			return false
		end
		for _, node in ipairs(path) do
			if node == needle then
				return true
			end
		end
		return false
	end

	local function isAllocatableNormalNode(node)
		return node
			and not node.alloc
			and node.type == "Normal"
			and not node.ascendancyName
			and not node.isMultipleChoice
			and not node.isMultipleChoiceOption
			and #node.intuitiveLeapLikesAffecting == 0
	end

	local function findNormalPathNodeAfter(spec, throughNode)
		for _, node in ipairs(throughNode.linked) do
			if isAllocatableNormalNode(node) and (node.pathRoot == throughNode or pathContains(node.path, throughNode)) then
				return node
			end
		end
		for _, node in pairs(spec.nodes) do
			if isAllocatableNormalNode(node) and (node.pathRoot == throughNode or pathContains(node.path, throughNode)) then
				return node
			end
		end
	end

	it("normal passive allocation cannot continue through weapon-set-only branches", function()
		local spec = build.spec
		local startNode = spec.nodes[spec.curClass.startNodeId]
		local firstNode = findNormalPathNodeAfter(spec, startNode)
		assert.True(firstNode ~= nil)

		spec.allocMode = 0
		spec:AllocNode(firstNode)
		assert.are.equals(0, firstNode.allocMode)

		local weaponSetNode = findNormalPathNodeAfter(spec, firstNode)
		assert.True(weaponSetNode ~= nil)

		spec.allocMode = 1
		spec:AllocNode(weaponSetNode)
		assert.are.equals(1, weaponSetNode.allocMode)

		local blockedNode = findNormalPathNodeAfter(spec, weaponSetNode)
		assert.True(blockedNode ~= nil)
		assert.True(blockedNode.pathRoot == weaponSetNode or pathContains(blockedNode.path, weaponSetNode))

		spec.allocMode = 0
		spec:AllocNode(blockedNode)
		assert.are_not.equals(true, blockedNode.alloc)

		spec.allocMode = 1
		spec:AllocNode(blockedNode)
		assert.True(blockedNode.alloc)
		assert.are.equals(1, blockedNode.allocMode)
	end)
end)
