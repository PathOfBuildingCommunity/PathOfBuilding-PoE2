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
end)
