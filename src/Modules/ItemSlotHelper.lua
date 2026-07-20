local M = {}

-- Draws a small display window of a jewel socket's position. Note that this will reset the
-- viewport and the draw layer.
---@param nodeId integer
---@param x integer
---@param y integer
---@param w integer
---@param h integer
function M.DrawViewer(itemsTab, nodeId, x, y, w, h)
	local node = itemsTab.build.spec.nodes[nodeId]
	if not node then return end
	SetDrawLayer(nil, 15)
	SetDrawColor(1, 1, 1)

	local borderWidth = 1
	DrawImage(nil, x, y, w + 2 * borderWidth, h + 2 * borderWidth)

	local viewer = itemsTab.socketViewer
	viewer.zoom = 17
	-- Zoom out if needed so the socketed jewel's radius ring (including the Time-Lost
	-- radius increase from Baryanic Leylines) fits inside the preview: the ring's
	-- diameter must fit min(w,h), with ~5% margin so the ring stroke isn't clipped
	local _, jewel = itemsTab:GetSocketAndJewelForNodeID(nodeId)
	if jewel and jewel.jewelRadiusIndex then
		local radData = data.jewelRadius[itemsTab.build.spec:GetJewelRadiusIndex(jewel)]
		local ringSize = radData.outer * data.gameConstants["PassiveTreeJewelDistanceMultiplier"]
		viewer.zoom = math.min(viewer.zoom, itemsTab.build.spec.tree.size / (2 * ringSize) / 1.05)
	end

	local viewPortSize = math.min(w, h)
	local scale = itemsTab.build.spec.tree.size / (viewPortSize * viewer.zoom)
	viewer.zoomX = -node.x / scale
	viewer.zoomY = -node.y / scale
	-- offset viewport to be inside borders
	SetViewport(x + borderWidth, y + borderWidth, w, h)
	-- draw the actual image
	viewer:Draw(itemsTab.build, { x = 0, y = 0, width = w, height = h }, {})
	SetDrawLayer(nil, 30)
	SetDrawColor(1, 1, 1, 0.2)
	-- draw crosshair
	DrawImage(nil, math.floor(w / 2) - 1, 0, 2, h)
	DrawImage(nil, 0, math.floor(h / 2) - 1, w, 2)
	SetViewport()
	SetDrawLayer(nil, 0)
end

return M
