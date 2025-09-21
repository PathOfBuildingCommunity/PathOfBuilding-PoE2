-- Path of Building
--
-- Class: Passive Tree View
-- Passive skill tree viewer.
-- Draws the passive skill tree, and also maintains the current view settings (zoom level, position, etc)
--
local pairs = pairs
local ipairs = ipairs
local t_insert = table.insert
local t_remove = table.remove
local m_min = math.min
local m_max = math.max
local m_floor = math.floor
local band = AND64 -- bit.band
local b_rshift = bit.rshift

local PassiveTreeViewClass = newClass("PassiveTreeView", function(self)
	self.ring = NewImageHandle()
	self.ring:Load("Assets/ring.png", "CLAMP")
	self.highlightRing = NewImageHandle()
	self.highlightRing:Load("Assets/small_ring.png", "CLAMP")
	self.jewelShadedOuterRing = NewImageHandle()
	self.jewelShadedOuterRing:Load("Assets/ShadedOuterRing.png", "CLAMP")
	self.jewelShadedOuterRingFlipped = NewImageHandle()
	self.jewelShadedOuterRingFlipped:Load("Assets/ShadedOuterRingFlipped.png", "CLAMP")
	self.jewelShadedInnerRing = NewImageHandle()
	self.jewelShadedInnerRing:Load("Assets/ShadedInnerRing.png", "CLAMP")
	self.jewelShadedInnerRingFlipped = NewImageHandle()
	self.jewelShadedInnerRingFlipped:Load("Assets/ShadedInnerRingFlipped.png", "CLAMP")

	self.tooltip = new("Tooltip")

	self.zoomLevel = 3
	self.zoom = 1.2 ^ self.zoomLevel
	self.zoomX = 0
	self.zoomY = 0

	self.searchStr = ""
	self.searchStrSaved = ""
	self.searchStrCached = ""
	self.searchStrResults = {}
	self.showStatDifferences = true
	self.hoverNode = nil
end)

function PassiveTreeViewClass:Load(xml, fileName)
	if xml.attrib.zoomLevel then
		self.zoomLevel = tonumber(xml.attrib.zoomLevel)
		self.zoom = 1.2 ^ self.zoomLevel
	end
	if xml.attrib.zoomX and xml.attrib.zoomY then
		self.zoomX = tonumber(xml.attrib.zoomX)
		self.zoomY = tonumber(xml.attrib.zoomY)
	end
	if xml.attrib.searchStr then
		self.searchStr = xml.attrib.searchStr
		self.searchStrSaved = xml.attrib.searchStr
	end
	if xml.attrib.showStatDifferences then
		self.showStatDifferences = xml.attrib.showStatDifferences == "true"
	end
end

function PassiveTreeViewClass:Save(xml)
	self.searchStrSaved = self.searchStr
	xml.attrib = {
		zoomLevel = tostring(self.zoomLevel),
		zoomX = tostring(self.zoomX),
		zoomY = tostring(self.zoomY),
		searchStr = self.searchStr,
		showStatDifferences = tostring(self.showStatDifferences),
	}
end

function PassiveTreeViewClass:Draw(build, viewPort, inputEvents)
	local spec = build.spec
	local tree = spec.tree

	local cursorX, cursorY = GetCursorPos()
	local mOver = cursorX >= viewPort.x and cursorX < viewPort.x + viewPort.width and cursorY >= viewPort.y and cursorY < viewPort.y + viewPort.height
	
	-- Process input events
	local treeClick
	for id, event in ipairs(inputEvents) do
		if event.type == "KeyDown" then
			if event.key == "LEFTBUTTON" then
				if mOver then
					-- Record starting coords of mouse drag
					-- Dragging won't actually commence unless the cursor moves far enough
					self.dragX, self.dragY = cursorX, cursorY
				end
			elseif IsKeyDown("ALT") and mOver then
				if event.key == "WHEELDOWN" then
					spec.allocMode = math.max(0, spec.allocMode - 1)
				elseif event.key == "WHEELUP" then
					spec.allocMode = math.min(2, spec.allocMode + 1)
				end
			elseif event.key == "p" then
				self.showHeatMap = not self.showHeatMap
			elseif event.key == "d" and IsKeyDown("CTRL") then
				self.showStatDifferences = not self.showStatDifferences
			elseif event.key == "c" and IsKeyDown("CTRL") and self.hoverNode and self.hoverNode.type ~= "Socket" then
				local result = "# ".. self.hoverNode.dn .. "\n"
				for _, line in ipairs(self.hoverNode.sd) do
					result = result .. line .. "\n"
				end
				Copy(result)
			elseif event.key == "PAGEUP" then
				self:Zoom(IsKeyDown("SHIFT") and 3 or 1, viewPort)
			elseif event.key == "PAGEDOWN" then
				self:Zoom(IsKeyDown("SHIFT") and -3 or -1, viewPort)
			elseif itemLib.wiki.matchesKey(event.key) and self.hoverNode then
				itemLib.wiki.open(self.hoverNode.name or self.hoverNode.dn)
			end
		elseif event.type == "KeyUp" then
			if event.key == "LEFTBUTTON" then
				if self.dragX and not self.dragging then
					-- Mouse button went down, but didn't move far enough to trigger drag, so register a normal click
					treeClick = "LEFT"
				end
			elseif mOver then
				if event.key == "RIGHTBUTTON" then
					treeClick = "RIGHT"
				elseif event.key == "WHEELUP" and not IsKeyDown("ALT") then
					self:Zoom(IsKeyDown("SHIFT") and 3 or 1, viewPort)
				elseif event.key == "WHEELDOWN" and not IsKeyDown("ALT") then
					self:Zoom(IsKeyDown("SHIFT") and -3 or -1, viewPort)
				end	
			end
		end
	end

	if not IsKeyDown("LEFTBUTTON") then
		-- Left mouse button isn't down, stop dragging if dragging was in progress
		self.dragging = false
		self.dragX, self.dragY = nil, nil
	end
	if self.dragX then
		-- Left mouse is down
		if not self.dragging then
			-- Check if mouse has moved more than a few pixels, and if so, initiate dragging
			if math.abs(cursorX - self.dragX) > 5 or math.abs(cursorY - self.dragY) > 5 then
				self.dragging = true
			end
		end
		if self.dragging then
			self.zoomX = self.zoomX + cursorX - self.dragX
			self.zoomY = self.zoomY + cursorY - self.dragY
			self.dragX, self.dragY = cursorX, cursorY
		end
	end

	-- Ctrl-click to zoom
	if treeClick and IsKeyDown("CTRL") then
		self:Zoom(treeClick == "RIGHT" and -2 or 2, viewPort)
		treeClick = nil
	end

	-- Clamp zoom offset
	local clampFactor = self.zoom * 2 / 3
	self.zoomX = self.zoomX ~= nil and m_min(m_max(self.zoomX, -viewPort.width * clampFactor), viewPort.width * clampFactor) or 1
	self.zoomY = self.zoomY ~= nil and m_min(m_max(self.zoomY, -viewPort.height * clampFactor), viewPort.height * clampFactor) or 1

	-- Create functions that will convert coordinates between the screen and tree coordinate spaces
	local scale = m_min(viewPort.width, viewPort.height) / tree.size * self.zoom

	local offsetX = self.zoomX + viewPort.x + viewPort.width/2
	local offsetY = self.zoomY + viewPort.y + viewPort.height/2
	local function treeToScreen(x, y)
		return x * scale + offsetX,
		       y * scale + offsetY
	end
	local function screenToTree(x, y)
		return (x - offsetX) / scale,
		       (y - offsetY) / scale
	end

	if IsKeyDown("SHIFT") then
		-- Enable path tracing mode
		self.traceMode = true
		self.tracePath = self.tracePath or { }
	else
		self.traceMode = false
		self.tracePath = nil
	end

	local hoverNode
	if mOver then
		-- Cursor is over the tree, check if it is over a node
		local curTreeX, curTreeY = screenToTree(cursorX, cursorY)
		for nodeId, node in pairs(spec.nodes) do
			if node.rsq and node.group and not node.isProxy and not node.group.isProxy then
				-- Node has a defined size (i.e. has artwork)
				local vX = curTreeX - node.x
				local vY = curTreeY - node.y
				if vX * vX + vY * vY <= node.rsq then
					hoverNode = node
					break
				end
			end
		end
	end

	self.hoverNode = hoverNode
	-- If hovering over a node, find the path to it (if unallocated) or the list of dependent nodes (if allocated)
	local hoverPath, hoverDep
	if self.traceMode then
		-- Path tracing mode is enabled
		if hoverNode then
			if not hoverNode.path then
				-- Don't highlight the node if it can't be pathed to
				hoverNode = nil
			elseif not self.tracePath[1] then
				-- Initialise the trace path using this node's path
				for _, pathNode in ipairs(hoverNode.path) do
					t_insert(self.tracePath, 1, pathNode)
				end
			else
				local lastPathNode = self.tracePath[#self.tracePath]
				if hoverNode ~= lastPathNode then
					-- If node is directly linked to the last node in the path, add it
					if isValueInArray(hoverNode.linked, lastPathNode) then
						local index = isValueInArray(self.tracePath, hoverNode)
						if index then
							-- Node is already in the trace path, remove it first
							t_remove(self.tracePath, index)
							t_insert(self.tracePath, hoverNode)
						else
							t_insert(self.tracePath, hoverNode)
						end
					else
						hoverNode = nil
					end
				end
			end
		end
		-- Use the trace path as the path 
		hoverPath = { }
		for _, pathNode in pairs(self.tracePath) do
			hoverPath[pathNode] = true
		end
	elseif hoverNode and hoverNode.path then
		-- Use the node's own path and dependence list
		hoverPath = { }
		if #hoverNode.intuitiveLeapLikesAffecting == 0 then
			for _, pathNode in pairs(hoverNode.path) do
				hoverPath[pathNode] = true
			end
		end
		hoverDep = { }
		for _, depNode in pairs(hoverNode.depends) do
			hoverDep[depNode] = true
		end
	end
	
	-- switchAttribute true -> allocating an attribute node, possibly with attribute in path -or- hot-swap allocated attribute
	-- switchAttribute false -> allocating a non-attribute node, possibly with attribute in path
	-- we always want to keep track of last used attribute
	local function processAttributeHotkeys(switchAttribute)
		if IsKeyDown("2") or IsKeyDown("S") then
			spec.attributeIndex = 1
			if switchAttribute then spec:SwitchAttributeNode(hoverNode.id, 1) end
		elseif IsKeyDown("3") or IsKeyDown("D") then
			spec.attributeIndex = 2
			if switchAttribute then spec:SwitchAttributeNode(hoverNode.id, 2) end
		elseif IsKeyDown("1") or IsKeyDown("I") then
			spec.attributeIndex = 3
			if switchAttribute then spec:SwitchAttributeNode(hoverNode.id, 3) end
		end
	end
	
	local hotkeyPressed = IsKeyDown("1") or IsKeyDown("I") or IsKeyDown("2") or IsKeyDown("S") or IsKeyDown("3") or IsKeyDown("D")

	-- Helper function to determine if global node allocation should be blocked
	local function shouldBlockGlobalNodeAllocation(node)
		local isGlobalNode = node.type == "Keystone" or node.type == "Socket" or node.containJewelSocket

		if not isGlobalNode or node.alloc or not node.path then
			return false
		end

		local weaponSetMode = spec.allocMode > 0
		local connectedToWeaponSetNodes = self:IsConnectedToWeaponSetNodes(node)

		-- Only allow allocation from main tree AND node must not be connected to weapon set nodes
		local shouldBlock = weaponSetMode or connectedToWeaponSetNodes

		return shouldBlock
	end

	-- Helper function to determine if global node deallocation should be blocked
	local function shouldBlockGlobalNodeDeallocation(node)
		local isGlobalNode = node.type == "Keystone" or node.type == "Socket" or node.containJewelSocket

		if not isGlobalNode or not node.alloc then
			return false
		end

		-- Main-tree global nodes can only be deallocated from main tree
		-- Legacy weapon-set global nodes can be deallocated from any mode
		local shouldBlock = node.allocMode == 0 and spec.allocMode > 0

		return shouldBlock
	end

	if treeClick == "LEFT" then
		if hoverNode then
			-- User left-clicked on a node
			if hoverNode.alloc and not shouldBlockGlobalNodeDeallocation(hoverNode) then
				-- Handle deallocation of allocated nodes
				if hoverNode.isAttribute then
					-- change to other attribute without needing to deallocate
					if hotkeyPressed then
						processAttributeHotkeys(true)
						-- reload allocated node with new attribute
						spec:BuildAllDependsAndPaths()
					else -- reset switched node to generic Attribute
						spec.hashOverrides[hoverNode.id] = nil
						spec:DeallocNode(hoverNode)
					end
				else
					spec:DeallocNode(hoverNode)
				end
				spec:AddUndoState()
				build.buildFlag = true
			elseif hoverNode.path and not shouldBlockGlobalNodeAllocation(hoverNode) then
				-- Handle allocation of unallocated nodes
				if hoverNode.isAttribute and not hotkeyPressed then
					build.treeTab:ModifyAttributePopup(hoverNode)
				else
					-- the odd conditional here is so the popup only calls AllocNode inside and to avoid duplicating some code
					-- same flow for hotkey attribute and non attribute nodes
					if hotkeyPressed then
						processAttributeHotkeys(hoverNode.isAttribute)
					end
					spec:AllocNode(hoverNode, self.tracePath and hoverNode == self.tracePath[#self.tracePath] and self.tracePath)
					spec:AddUndoState()
					build.buildFlag = true
				end
			end
		end
	elseif treeClick == "RIGHT" then
		-- User right-clicked on a node
		if hoverNode then
			if hoverNode.alloc and (hoverNode.type == "Socket" or hoverNode.containJewelSocket) then
				local slot = build.itemsTab.sockets[hoverNode.id]
				if slot:IsEnabled() then
					-- User right-clicked a jewel socket, jump to the item page and focus the corresponding item slot control
					slot.dropped = true
					build.itemsTab:SelectControl(slot)
					build.viewMode = "ITEMS"
				end
			else
				-- a way for us to bypass the popup when allocating attribute nodes, last used hotkey + RMB
				-- RMB + non attribute node logic
				-- RMB hot-swap logic
				if hotkeyPressed then
					processAttributeHotkeys(hoverNode.isAttribute)
				elseif hoverNode.isAttribute then
					-- If the attribute node is already set to str, int, or dex create a toggle effect between attrs
					if hoverNode.dn == "Intelligence" then
						spec.attributeIndex = 1
					elseif hoverNode.dn == "Dexterity" then
						spec.attributeIndex = 3
					elseif hoverNode.dn == "Strength" then
						spec.attributeIndex = 2
					end
					spec:SwitchAttributeNode(hoverNode.id, spec.attributeIndex or 1)
				end
				spec:AllocNode(hoverNode, self.tracePath and hoverNode == self.tracePath[#self.tracePath] and self.tracePath)
				spec:AddUndoState()
				build.buildFlag = true
			end
		end
	end

	-- Draw the background artwork
	local bg = tree:GetAssetByName("Background2")
	if bg.width == 0 then
		bg.width, bg.height = bg.handle:ImageSize()
	end
	if bg.width > 0 then
		SetDrawColor(1, 1, 1, 1)
		DrawImage(bg.handle, viewPort.x, viewPort.y, viewPort.width, viewPort.height, 0, 0, viewPort.width / 100, viewPort.height / 100)
	end

	-- draw allocMode text
	self:DrawAllocMode(spec.allocMode, viewPort)

	-- TODO: More dynamic
	local treeCenter = tree:GetAssetByName("BGTree")
	local treeCenterActive = tree:GetAssetByName("BGTreeActive")
	-- draw background artwork base on current class
	local class = tree.classes[spec.curClassId]
	if class and class.background then
		local bgAssetName = class.background.image
		if spec.curAscendClassId ~= 0 and class.classes[spec.curAscendClassId] then
			bgAssetName = class.classes[spec.curAscendClassId].background.image
		end
		local bg = tree:GetAssetByName(bgAssetName)
		local scrX, scrY = treeToScreen(class.background.x * tree.scaleImage, class.background.y * tree.scaleImage)
		bg.width =  class.background.width
		bg.height = class.background.height

		self:DrawAsset(bg, scrX, scrY, scale)

		-- calculate rotation with quad
		local startNode = spec.nodes[class.startNodeId]
		local xActive = class.background.x * tree.scaleImage
		local yActive = class.background.y * tree.scaleImage
		local angleRad = (math.pi / 2) + math.atan2(startNode.y - yActive, startNode.x - xActive)
		treeCenterActive.width = class.background['active'].width
		treeCenterActive.height = class.background['active'].height
		self:DrawQuadAndRotate(treeCenterActive, class.background.x * tree.scaleImage, class.background.y * tree.scaleImage, angleRad, treeToScreen)

		treeCenter.width = class.background['bg'].width
		treeCenter.height = class.background['bg'].height
		self:DrawAsset(treeCenter, scrX, scrY, scale)
	end

	-- draw ascendancies
	for name, data in pairs(tree.ascendNameMap) do
		local ascendancy = data.ascendClass
		local drawn = true
		if ascendancy.replaceBy and ascendancy.replaceBy == spec.curAscendClassBaseName then
			drawn = false
		elseif ascendancy.replace and name ~= spec.curAscendClassBaseName then
			drawn = false
		end

		if ascendancy.background and drawn  then
			local bg = tree:GetAssetByName(ascendancy.background.image)
			local scrX, scrY = treeToScreen(ascendancy.background.x * tree.scaleImage, ascendancy.background.y * tree.scaleImage)
			bg.width = ascendancy.background.width
			bg.height = ascendancy.background.height
			if name == spec.curAscendClassBaseName then
				SetDrawColor(1, 1, 1)
			else
				SetDrawColor(0.5, 0.5, 0.5)
			end
			self:DrawAsset(bg, scrX, scrY, scale)
		end
	end

	local function renderGroup(group)
		if group.background then
			local scrX, scrY = treeToScreen(group.x * tree.scaleImage, group.y * tree.scaleImage)
			local bgAsset = tree:GetAssetByName(group.background.image)
			if group.background.offsetX and group.background.offsetY then
				scrX, scrY = treeToScreen(group.x + group.background.offsetX, group.y + group.background.offsetY)
			end
			self:DrawAsset(bgAsset, scrX, scrY, scale * tree.scaleImage, group.background.isHalfImage ~= nil)
		end
	end

	-- Draw the group backgrounds
	for _, group in pairs(tree.groups) do
		if not group.isProxy then
			renderGroup(group)
		end
	end

	local connectorColor = { 1, 1, 1 }
	local function setConnectorColor(r, g, b)
		connectorColor[1], connectorColor[2], connectorColor[3] = r, g, b
	end
	local function getState(n1, n2)
		-- Determine the connector state
		local state = "Normal"
		if n1.alloc and n2.alloc then
			state = "Active"
		elseif hoverPath then
			if (n1.alloc or n1 == hoverNode or hoverPath[n1]) and (n2.alloc or n2 == hoverNode or hoverPath[n2]) then
				state = "Intermediate"
			end
		end
		return state
	end
	local function renderConnector(connector)
		local node1, node2 = spec.nodes[connector.nodeId1], spec.nodes[connector.nodeId2]
		setConnectorColor(1, 1, 1)
		local state = getState(node1, node2)
		local baseState = state
		if self.compareSpec then
			local cNode1, cNode2 = self.compareSpec.nodes[connector.nodeId1], self.compareSpec.nodes[connector.nodeId2]
			if cNode1 and cNode2 then
				baseState = getState(cNode1,cNode2)
			end
		end

		if baseState == "Active" and state ~= "Active" then
			state = "Active"
			setConnectorColor(0, 1, 0)
		end
		if baseState ~= "Active" and state == "Active" then
			setConnectorColor(1, 0, 0)
		end

		if baseState == "Intermediate" and spec.allocMode > 0 and not connector.ascendancyName then
			if spec.allocMode == 1 then
				setConnectorColor(unpack(hexToRGB(colorCodes["NEGATIVE"]:sub(3))))
			elseif spec.allocMode == 2 then
				setConnectorColor(unpack(hexToRGB(colorCodes["POSITIVE"]:sub(3))))
			end
		end

		if baseState == "Active" and state == "Active" and not connector.ascendancyName then
			local allocMode =  (node1 and node1.allocMode and node1.allocMode ~= 0 and node1.allocMode) or (node2 and node2.allocMode and node2.allocMode ~= 0 and node2.allocMode) or 0
			if allocMode == 1 then
				setConnectorColor(unpack(hexToRGB(colorCodes["NEGATIVE"]:sub(3))))
			elseif allocMode == 2 then
				setConnectorColor(unpack(hexToRGB(colorCodes["POSITIVE"]:sub(3))))
			end
		end

		-- Convert vertex coordinates to screen-space and add them to the coordinate array
		local vert = connector.vert[state]
		connector.c[1], connector.c[2] = treeToScreen(vert[1], vert[2])
		connector.c[3], connector.c[4] = treeToScreen(vert[3], vert[4])
		connector.c[5], connector.c[6] = treeToScreen(vert[5], vert[6])
		connector.c[7], connector.c[8] = treeToScreen(vert[7], vert[8])

		if hoverDep and hoverDep[node1] and hoverDep[node2] then
			-- Both nodes depend on the node currently being hovered over, so color the line red
			setConnectorColor(1, 0, 0)
		elseif connector.ascendancyName and connector.ascendancyName ~= spec.curAscendClassBaseName then
			-- Fade out lines in ascendancy classes other than the current one
			setConnectorColor(0.75, 0.75, 0.75)
		end
		SetDrawColor(unpack(connectorColor))
		handle = tree:GetAssetByName(connector.type..state).handle
		DrawImageQuad(handle, unpack(connector.c))
	end

	-- Draw the connecting lines between nodes
	SetDrawLayer(nil, 20)
	for _, connector in pairs(tree.connectors) do
		renderConnector(connector)
	end
	for _, subGraph in pairs(spec.subGraphs) do
		for _, connector in pairs(subGraph.connectors) do
			renderConnector(connector)
		end
	end

	if self.showHeatMap then
		-- Build the power numbers if needed
		build.calcsTab:BuildPower()
		self.heatMapStat = build.calcsTab.powerStat
	end

	-- Update cached node data
	if self.searchStrCached ~= self.searchStr or self.searchNeedsForceUpdate == true then
		self.searchStrCached = self.searchStr
		self.searchNeedsForceUpdate = false

		local function prepSearch(search)
			search = search:lower()
			--gsub("([%[%]%%])", "%%%1")
			local searchWords = {}
			for matchstring, v in search:gmatch('"([^"]*)"') do
				searchWords[#searchWords+1] = matchstring
				search = search:gsub('"'..matchstring:gsub("([%(%)])", "%%%1")..'"', "")
			end
			for matchstring, v in search:gmatch("(%S*)") do
				if matchstring:match("%S") ~= nil then
					searchWords[#searchWords+1] = matchstring
				end
			end
			return searchWords
		end
		self.searchParams = prepSearch(self.searchStr)

		for nodeId, node in pairs(spec.nodes) do
			self.searchStrResults[nodeId] = #self.searchParams > 0 and self:DoesNodeMatchSearchParams(node)
		end
	end

	if launch.devModeAlt and hoverNode then
		-- Draw orbits of the group node
		local groupNode = hoverNode.group
		SetDrawLayer(nil, 80)
		SetDrawColor(1, 0, 0)
		for _, orbit in ipairs(groupNode.orbits) do
			local x, y = treeToScreen(groupNode.x * tree.scaleImage, groupNode.y * tree.scaleImage)
			local orbitRadius = tree.orbitRadii[orbit + 1] * tree.scaleImage
			local innerSize = orbitRadius * scale
			DrawImage(self.ring, x - innerSize, y - innerSize, innerSize * 2, innerSize * 2)
		end
		SetDrawColor(1, 1, 1)

		local node1 = hoverNode
		for _, connection in ipairs(hoverNode.connections) do
			-- draw connections by hand
			local node2 = spec.nodes[connection.id]
			if connection.orbit ~= 0 and tree.orbitRadii[math.abs(connection.orbit) + 1] then
				local r =  tree.orbitRadii[math.abs(connection.orbit) + 1] * tree.scaleImage

				local dx, dy = node2.x - node1.x, node2.y - node1.y
				local dist = math.sqrt(dx * dx + dy * dy) * (connection.orbit > 0 and 1 or -1)

				if dist < r * 2 then
					local perpendicular = math.sqrt(r * r - (dist * dist) / 4) * (r > 0 and 1 or -1)
					local cx = node1.x + dx / 2 + perpendicular * (dy / dist)
					local cy = node1.y + dy / 2 - perpendicular * (dx / dist)
					local scx, scy = treeToScreen(cx, cy)
					
					local innerSize = r * scale
					SetDrawColor(0, 1, 0)
					DrawImage(self.ring, scx - innerSize, scy - innerSize, innerSize * 2, innerSize * 2)
					SetDrawColor(1, 1, 1)
				end
			end
		end
	end

	-- calculate inc from SmallPassiveSkillEffect
	local incSmallPassiveSkillEffect = 0
	for _, node in pairs(spec.allocNodes) do
		incSmallPassiveSkillEffect = incSmallPassiveSkillEffect + node.modList:Sum("INC", nil ,"SmallPassiveSkillEffect")
	end

	-- Draw the nodes
	for nodeId, node in pairs(spec.nodes) do
		-- Determine the base and overlay images for this node based on type and state
		local compareNode = self.compareSpec and self.compareSpec.nodes[nodeId] or nil

		local base, overlay, effect
		local isAlloc = node.alloc or build.calcsTab.mainEnv.grantedPassives[nodeId] or (compareNode and compareNode.alloc)
		SetDrawLayer(nil, 25)
		if node.type == "ClassStart" then
			overlay = nil
		elseif node.type == "AscendClassStart" then
			overlay = "AscendancyMiddle"
			if node.ascendancyName and tree.secondaryAscendNameMap and tree.secondaryAscendNameMap[node.ascendancyName] then
				overlay = "Azmeri"..overlay
			end
		else
			local state
			if self.showHeatMap or isAlloc or node == hoverNode or (self.traceMode and node == self.tracePath[#self.tracePath])then
				-- Show node as allocated if it is being hovered over
				-- Also if the heat map is turned on (makes the nodes more visible)
				state = "alloc"
			elseif hoverPath and hoverPath[node] then
				state = "path"
			else
				state = "unalloc"
			end
			if node.type == "Socket" or node.containJewelSocket then
				-- Node is a jewel socket, retrieve the socketed jewel (if present) so we can display the correct art
				base = tree:GetAssetByName(node.overlay[state])

				local socket, jewel = build.itemsTab:GetSocketAndJewelForNodeID(nodeId)
				if isAlloc and jewel then
					overlay = jewel.baseName
				end
			elseif node.type == "OnlyImage" then
				-- This is the icon that appears in the center of many groups
				base = tree:GetAssetByName(node.activeEffectImage)

				SetDrawLayer(nil, 15)
			else
				-- Normal node (includes keystones and notables)
				if node.activeEffectImage then
					effect = tree:GetAssetByName(node.activeEffectImage)
				end

				base = tree:GetAssetByName(node.icon)

				overlay = node.overlay[state .. (node.ascendancyName and "Ascend" or "") .. (node.isBlighted and "Blighted" or "")]
				
				if node.ascendancyName and tree.secondaryAscendNameMap and tree.secondaryAscendNameMap[node.ascendancyName] then
					overlay = "Azmeri"..overlay
				end
			end
		end

		-- Convert node position to screen-space
		local scrX, scrY = treeToScreen(node.x, node.y)
	
		-- Determine color for the base artwork
		if self.showHeatMap then
			if not isAlloc and node.type ~= "ClassStart" and node.type ~= "AscendClassStart" then
				if self.heatMapStat and self.heatMapStat.stat then
					-- Calculate color based on a single stat
					local stat = m_max(node.power.singleStat or 0, 0)
					local statCol = (stat / build.calcsTab.powerMax.singleStat * 1.5) ^ 0.5
					if main.nodePowerTheme == "RED/BLUE" then
						SetDrawColor(statCol, 0, 0)
					elseif main.nodePowerTheme == "RED/GREEN" then
						SetDrawColor(0, statCol, 0)
					elseif main.nodePowerTheme == "GREEN/BLUE" then
						SetDrawColor(0, 0, statCol)
					end
				else
					-- Calculate color based on DPS and defensive powers
					local offence = m_max(node.power.offence or 0, 0)
					local defence = m_max(node.power.defence or 0, 0)
					local dpsCol = (offence / build.calcsTab.powerMax.offence * 1.5) ^ 0.5
					local defCol = (defence / build.calcsTab.powerMax.defence * 1.5) ^ 0.5
					local mixCol = (m_max(dpsCol - 0.5, 0) + m_max(defCol - 0.5, 0)) / 2
					if main.nodePowerTheme == "RED/BLUE" then
						SetDrawColor(dpsCol, mixCol, defCol)
					elseif main.nodePowerTheme == "RED/GREEN" then
						SetDrawColor(dpsCol, defCol, mixCol)
					elseif main.nodePowerTheme == "GREEN/BLUE" then
						SetDrawColor(mixCol, dpsCol, defCol)
					end
				end
			else
				if compareNode then
					if compareNode.alloc and not node.alloc then
						-- Base has, current has not, color green (take these nodes to match)
						SetDrawColor(0, 1, 0)
					elseif not compareNode.alloc and node.alloc then
						-- Base has not, current has, color red (Remove nodes to match)
						SetDrawColor(1, 0, 0)
					else
						-- Both have or both have not, use white
						SetDrawColor(1, 1, 1)
					end
				else
					SetDrawColor(1, 1, 1)
				end
			end
		elseif launch.devModeAlt then
			-- Debug display
			if node.extra then
				SetDrawColor(1, 0, 0)
			elseif node.unknown then
				SetDrawColor(0, 1, 1)
			else
				SetDrawColor(0, 0, 0)
			end
		else
			if compareNode then
				if compareNode.alloc and not node.alloc then
					-- Base has, current has not, color green (take these nodes to match)
					SetDrawColor(0, 1, 0)
				elseif not compareNode.alloc and node.alloc then
					-- Base has not, current has, color red (Remove nodes to match)
					SetDrawColor(1, 0, 0)
				else
					-- Both have or both have not, use white
					SetDrawColor(1, 1, 1)
				end
			else
				SetDrawColor(1, 1, 1)
			end
		end

		-- Draw mastery effect artwork
		if effect and not launch.devModeAlt and not self.showHeatMap then
			if node.targetSize and node.targetSize["effect"] then
				effect.width = node.targetSize["effect"].width
				effect.height = node.targetSize["effect"].height
			end
			SetDrawLayer(nil, 15)
			if isAlloc or (self.tracePath and isValueInArray(self.tracePath, node)) or (hoverNode and hoverNode.path and isValueInArray(hoverNode.path, node))  then
				SetDrawColor(1, 1, 1)
			else
				SetDrawColor(1,1,1, 0.15)
			end
			self:DrawAsset(effect, scrX, scrY, scale)
			SetDrawColor(1, 1, 1)
			SetDrawLayer(nil, 25)
		end

		-- Draw base artwork
		if base then
			-- apply target size to the base image
			if node.targetSize then
				base.width = node.targetSize.width
				base.height = node.targetSize.height
			end
			if node.type == "Socket" and hoverDep and hoverDep[node] then
				SetDrawColor(1, 0, 0);
				self:DrawAsset(base, scrX, scrY, scale)
				SetDrawColor(1, 1, 1);
			elseif node.type == "Socket" then
				self:DrawAsset(base, scrX, scrY, scale)
			elseif node.type == "OnlyImage" then
				SetDrawColor(1,1,1, 0.15)
				self:DrawAsset(base, scrX, scrY, scale)
			else

				if not self.showHeatMap and not launch.devModeAlt and not node.alloc then
					self:LessLuminance()
				end

				self:DrawAsset(base, scrX, scrY, scale)
				if not self.showHeatMap and not launch.devModeAlt and not node.alloc then
					SetDrawColor(1, 1, 1, 1);
				end
			end
		end

		if overlay then
			-- Draw overlay
			if node.type ~= "ClassStart" and node.type ~= "AscendClassStart" then
				if hoverNode and hoverNode ~= node then
					-- Mouse is hovering over a different node
					if hoverDep and hoverDep[node] then
						-- This node depends on the hover node, turn it red
						SetDrawColor(1, 0, 0)
					elseif hoverNode.type == "Socket" and hoverNode.nodesInRadius then
						-- Hover node is a socket, check if this node falls within its radius and color it accordingly
						local socket, jewel = build.itemsTab:GetSocketAndJewelForNodeID(hoverNode.id)
						local isThreadOfHope = jewel and jewel.jewelRadiusLabel == "Variable"
						if isThreadOfHope then
							-- Jewel in socket is Thread of Hope or similar
							for index, data in ipairs(build.data.jewelRadius) do
								if hoverNode.nodesInRadius[index][node.id] then
									-- Draw Thread of Hope's annuli
									if data.inner ~= 0 then
										SetDrawColor(data.col)
										break
									end
								end
							end
						else
							-- Jewel in socket is not Thread of Hope or similar
							for index, data in ipairs(build.data.jewelRadius) do
								if hoverNode.nodesInRadius[index][node.id] then
									-- Draw normal jewel radii
									if data.inner == 0 then
										SetDrawColor(data.col)
										break
									end
								end
							end
						end
					end
				end
			end

			local overlayImage = tree:GetAssetByName(overlay)

			-- apply target size to the base image
			if overlayImage and node.targetSize and node.targetSize["overlay"] then
				overlayImage.width = node.targetSize["overlay"].width
				overlayImage.height = node.targetSize["overlay"].height
			end

			if not self.showHeatMap and not launch.devModeAlt and not node.alloc and (node.type == "AscendClassStart" or node.type == "ClassStart") then
				self:LessLuminance()
			end
			self:DrawAsset(overlayImage, scrX, scrY, scale)
			if not self.showHeatMap and not launch.devModeAlt and not node.alloc and (node.type == "AscendClassStart" or node.type == "ClassStart") then
				SetDrawColor(1, 1, 1)
			end
		end
		if self.searchStrResults[nodeId] then
			-- Node matches the search string, show the highlight circle
			SetDrawLayer(nil, 30)
			local rgbColor = rgbColor or {1, 0, 0}
			SetDrawColor(rgbColor[1], rgbColor[2], rgbColor[3])
			local size = 140 * scale / self.zoom ^ 0.2

			if main.edgeSearchHighlight then
				-- Snap node matches to the edge of the viewPort
				local peekaboo_ratio = 1.15
				local scaled_down_ratio = 0.6667
				local wide_cull = {viewPort.x - size / peekaboo_ratio, viewPort.x + viewPort.width - size * peekaboo_ratio}
				local high_cull = {viewPort.y - size / peekaboo_ratio, viewPort.y + viewPort.height - size * peekaboo_ratio}
				local newX = m_min(m_max(scrX - size, wide_cull[1]), wide_cull[2])
				local newY = m_min(m_max(scrY - size, high_cull[1]), high_cull[2])

				if newX ~= scrX - size or newY ~= scrY - size then
				size = size * scaled_down_ratio
				newX = newX + size / 2
				newY = newY + size / 2
				end
				DrawImage(self.highlightRing, newX, newY, size * 2, size * 2)
			else
				DrawImage(self.highlightRing, scrX - size, scrY - size, size * 2, size * 2)
			end

		end
		if node == hoverNode and (node.type ~= "Socket" or not IsKeyDown("SHIFT")) and not IsKeyDown("CTRL") and not main.popups[1] then
			-- Draw tooltip
			SetDrawLayer(nil, 100)
			local size = m_floor(node.size * scale)
			if self.tooltip:CheckForUpdate(node, self.showStatDifferences, self.tracePath, launch.devModeAlt, build.outputRevision, build.spec.allocMode) then
				self:AddNodeTooltip(self.tooltip, node, build, incSmallPassiveSkillEffect)
			end
			self.tooltip.center = true
			self.tooltip:Draw(m_floor(scrX - size), m_floor(scrY - size), size * 2, size * 2, viewPort)
		end
	end
	
	-- Draw ring overlays for jewel sockets
	SetDrawLayer(nil, 25)
	for nodeId in pairs(tree.sockets) do
		local node = spec.nodes[nodeId]
		if node and node.name ~= "Charm Socket" and node.containJewelSocket ~= true and (not node.expansionJewel or node.expansionJewel.size == 2) then
			local scrX, scrY = treeToScreen(node.x, node.y)
			local socket, jewel = build.itemsTab:GetSocketAndJewelForNodeID(nodeId)
			if node == hoverNode then
				local isThreadOfHope = jewel and jewel.jewelRadiusLabel == "Variable"
				if isThreadOfHope then
					for _, radData in ipairs(build.data.jewelRadius) do
						local outerSize = radData.outer * data.gameConstants["PassiveTreeJewelDistanceMultiplier"] * scale
						local innerSize = radData.inner * data.gameConstants["PassiveTreeJewelDistanceMultiplier"] * scale
						-- Jewel in socket is Thread of Hope or similar, draw it's annulus
						if innerSize ~= 0 then
							SetDrawColor(radData.col)
							DrawImage(self.ring, scrX - outerSize, scrY - outerSize, outerSize * 2, outerSize * 2)
							DrawImage(self.ring, scrX - innerSize, scrY - innerSize, innerSize * 2, innerSize * 2)
						end
					end
				else
					for _, radData in ipairs(build.data.jewelRadius) do
						local outerSize = radData.outer * data.gameConstants["PassiveTreeJewelDistanceMultiplier"] * scale
						local innerSize = radData.inner * data.gameConstants["PassiveTreeJewelDistanceMultiplier"] * scale
						-- Jewel in socket is not Thread of Hope or similar, draw normal jewel radius
						if innerSize == 0 then
							SetDrawColor(radData.col)
							DrawImage(self.ring, scrX - outerSize, scrY - outerSize, outerSize * 2, outerSize * 2)
						end
					end
				end
			elseif node.alloc then
				if jewel and jewel.jewelRadiusIndex then
					-- Draw only the selected jewel radius
					local radData = build.data.jewelRadius[jewel.jewelRadiusIndex]
					local outerSize = radData.outer * data.gameConstants["PassiveTreeJewelDistanceMultiplier"] * scale
					local innerSize = radData.inner * data.gameConstants["PassiveTreeJewelDistanceMultiplier"] * scale * 1.06
					SetDrawColor(1,1,1,0.7)
					if jewel.title == "From Nothing" then
						-- From Nothing ring shows on the allocated Keystone
						for keystoneName, _ in pairs(jewel.jewelData.fromNothingKeystones) do
							local keystone = spec.tree.keystoneMap[keystoneName]
							if keystone and keystone.x and keystone.y then
								innerSize = 150 * scale
								local keyX, keyY = treeToScreen(keystone.x, keystone.y)
								DrawImage(self.jewelShadedOuterRing, keyX - outerSize, keyY - outerSize, outerSize * 2, outerSize * 2)
								DrawImage(self.jewelShadedOuterRingFlipped, keyX - outerSize, keyY - outerSize, outerSize * 2, outerSize * 2)
								DrawImage(self.jewelShadedInnerRing, keyX - innerSize, keyY - innerSize, innerSize * 2, innerSize * 2)
								DrawImage(self.jewelShadedInnerRingFlipped, keyX - innerSize, keyY - innerSize, innerSize * 2, innerSize * 2)
							end
						end
					elseif jewel.jewelData and jewel.jewelData.conqueredBy and jewel.jewelData.conqueredBy.conqueror and jewel.jewelData.conqueredBy.conqueror.type then
						local conqueror = jewel.jewelData.conqueredBy.conqueror.type
						if conqueror == "kalguur" then
							conqueror = "kalguuran"
						end
						local circle1 = tree:GetAssetByName("art/textures/interface/2d/2dart/uiimages/ingame/passiveskillscreen".. conqueror .."jewelcircle1.dds")
						local circle2 = tree:GetAssetByName("art/textures/interface/2d/2dart/uiimages/ingame/passiveskillscreen".. conqueror .."jewelcircle2.dds")
						if conqueror == "abyss" then
							circle1 = tree:GetAssetByName("art/textures/interface/2d/2dart/uiimages/ingame/".. conqueror .."/".. conqueror .."passiveskillscreenjewelcircle1.dds")
							circle2 = circle1
						end
						DrawImage(circle1.handle, scrX - outerSize, scrY - outerSize, outerSize * 2, outerSize * 2, unpack(circle1))
						DrawImage(circle2.handle, scrX - outerSize, scrY - outerSize, outerSize * 2, outerSize * 2, unpack(circle2))
					else
						DrawImage(self.jewelShadedOuterRing, scrX - outerSize, scrY - outerSize, outerSize * 2, outerSize * 2)
						DrawImage(self.jewelShadedOuterRingFlipped, scrX - outerSize, scrY - outerSize, outerSize * 2, outerSize * 2)
						DrawImage(self.jewelShadedInnerRing, scrX - innerSize, scrY - innerSize, innerSize * 2, innerSize * 2)
						DrawImage(self.jewelShadedInnerRingFlipped, scrX - innerSize, scrY - innerSize, innerSize * 2, innerSize * 2)
					end
				end
			end
		end
	end
end

-- Draws the given asset at the given position
function PassiveTreeViewClass:DrawAsset(data, x, y, scale, isHalf)
	if not data or not data.found then
		return
	end
	if data.width == 0 then
		data.width, data.height = data.handle:ImageSize()
		if data.width == 0 then
			return
		end
	end
	local width = data.width * scale
	local height = data.height * scale
	if isHalf then
		DrawImage(data.handle, x - width, y - height * 2, width * 2, height * 2)
		DrawImage(data.handle, x - width, y, width * 2, height * 2, 0, 1, 1, 0)
	else
		DrawImage(data.handle, x - width, y - height, width * 2, height * 2, unpack(data))
	end
end

function PassiveTreeViewClass:DrawQuadAndRotate(data, xTree, yTree, angleRad, treeToScreen)
	local vertActive = {}
		local xActive = xTree
		local yActive = yTree
		local widthActive = data.width
		local heightActive = data.height
	
		local function rotate(x, y, cx, cy, theta)
			local translatedX = x - cy
			local translatedY = y - cy

			local cosTheta = math.cos(theta)
			local sinTheta = math.sin(theta)
			local rotatedX =  translatedX * cosTheta - translatedY * sinTheta
			local rotatedY =  translatedX * sinTheta + translatedY * cosTheta

			return rotatedX + cx, rotatedY + cy
		end

		vertActive[1], vertActive[2] = xActive - widthActive, yActive - heightActive
		vertActive[3], vertActive[4] = xActive + widthActive, yActive - heightActive
		vertActive[5], vertActive[6] = xActive + widthActive, yActive + heightActive
		vertActive[7], vertActive[8] = xActive - widthActive, yActive + heightActive
		vertActive[9] = data[1] -- s1

		-- rotate the quad
		vertActive[1], vertActive[2] = treeToScreen(rotate(vertActive[1], vertActive[2], xActive, yActive, angleRad))
		vertActive[3], vertActive[4] = treeToScreen(rotate(vertActive[3], vertActive[4], xActive, yActive, angleRad))
		vertActive[5], vertActive[6] = treeToScreen(rotate(vertActive[5], vertActive[6], xActive, yActive, angleRad))
		vertActive[7], vertActive[8] = treeToScreen(rotate(vertActive[7], vertActive[8], xActive, yActive, angleRad))

		DrawImageQuad(data.handle, unpack(vertActive))
end

-- Zoom the tree in or out
function PassiveTreeViewClass:Zoom(level, viewPort)
	-- Calculate new zoom level and zoom factor
	self.zoomLevel = m_max(0, m_min(20, self.zoomLevel + level))
	local oldZoom = self.zoom
	self.zoom = 1.2 ^ self.zoomLevel

	-- Adjust zoom center position so that the point on the tree that is currently under the mouse will remain under it
	local factor = self.zoom / oldZoom
	local cursorX, cursorY = GetCursorPos()
	local relX = cursorX - viewPort.x - viewPort.width/2
	local relY = cursorY - viewPort.y - viewPort.height/2
	self.zoomX = relX + (self.zoomX - relX) * factor
	self.zoomY = relY + (self.zoomY - relY) * factor
end

function PassiveTreeViewClass:Focus(x, y, viewPort, build)
	self.zoomLevel = 20
	self.zoom = 1.2 ^ self.zoomLevel

	local tree = build.spec.tree
	local scale = m_min(viewPort.width, viewPort.height) / tree.size * self.zoom
	
	self.zoomX = -x * scale
	self.zoomY = -y * scale
end

function PassiveTreeViewClass:DoesNodeMatchSearchParams(node)
	if node.type == "ClassStart" or node.type == "OnlyImage" then
		return
	end

	local needMatches = copyTable(self.searchParams)
	local err

	local function search(haystack, need)
		for i=#need, 1, -1 do
			if haystack:matchOrPattern(need[i]) then
				table.remove(need, i)
			end
		end
		return need
	end

	-- Check recipes
	if needMatches[1] == "oil:" then
		if node.recipe then
			for _, recipeName in ipairs(node.recipe) do
				err, needMatches = PCall(search, recipeName:gsub("Oil",""):lower(), needMatches)
				if err then return false end
				if #needMatches == 1 and needMatches[1] == "oil:" then
					return true
				end
			end
		end
		return false
	end

	-- Check node name
	err, needMatches = PCall(search, node.dn:lower(), needMatches)
	if err then return false end
	if #needMatches == 0 then
		return true
	end

	-- Check node description
	if not node.sd then
		ConPrintf("Node %d has no sd", node.id)
	else
		for index, line in ipairs(node.sd) do
			-- Check display text first
			err, needMatches = PCall(search, line:lower(), needMatches)
			if err then return false end
			if #needMatches == 0 then
				return true
			end
			if #needMatches > 0 and node.mods[index].list then
				-- Then check modifiers
				for _, mod in ipairs(node.mods[index].list) do
					err, needMatches = PCall(search, mod.name, needMatches)
					if err then return false end
					if #needMatches == 0 then
						return true
					end
				end
			end
		end
	end

	-- Check node type
	err, needMatches = PCall(search, node.type:lower(), needMatches)
	if err then return false end
	if #needMatches == 0 then
		return true
	end
	
	-- Check node id for devs
	if launch.devMode then
		err, needMatches = PCall(search, tostring(node.id), needMatches)
		if err then return false end
		if #needMatches == 0 then
			return true
		end
	end
end

function PassiveTreeViewClass:AddNodeName(tooltip, node, build)
	tooltip:SetRecipe(node.infoRecipe)
	local tooltipMap = {
		Normal = "PASSIVE",
		Notable = "NOTABLE",
		Socket = "JEWEL",
		Keystone = "KEYSTONE",
		Ascendancy = "ASCENDANCY",
	}
	if (node.type == "Notable" or node.type == "Normal") and node.ascendancyName then
		tooltip.tooltipHeader = "ASCENDANCY"
	else
		tooltip.tooltipHeader = tooltipMap[node.type] or "UNKNOWN"
	end
	tooltip:AddLine(24, "^7"..node.dn..(launch.devModeAlt and " ["..node.id.."]" or ""))
	if launch.devModeAlt and node.id > 65535 then
		-- Decompose cluster node Id
		local index = band(node.id, 0xF)
		local size = band(b_rshift(node.id, 4), 0x3)
		local large = band(b_rshift(node.id, 6), 0x7)
		local medium = band(b_rshift(node.id, 9), 0x3)
		tooltip:AddLine(16, string.format("^7Cluster node index: %d, size: %d, large index: %d, medium index: %d", index, size, large, medium))
	end
	if node.type == "Socket" and node.nodesInRadius then
		local attribTotals = { }
		for nodeId in pairs(node.nodesInRadius[2]) do
			local specNode = build.spec.nodes[nodeId]
			for _, attrib in ipairs{"Str","Dex","Int"} do
				attribTotals[attrib] = (attribTotals[attrib] or 0) + specNode.finalModList:Sum("BASE", nil, attrib)
			end
		end
		if attribTotals["Str"] >= 40 then
			tooltip:AddLine(16, "^7Can support "..colorCodes.STRENGTH.."Strength ^7threshold jewels")
		end
		if attribTotals["Dex"] >= 40 then
			tooltip:AddLine(16, "^7Can support "..colorCodes.DEXTERITY.."Dexterity ^7threshold jewels")
		end
		if attribTotals["Int"] >= 40 then
			tooltip:AddLine(16, "^7Can support "..colorCodes.INTELLIGENCE.."Intelligence ^7threshold jewels")
		end
	end
	if node.type == "Socket" and node.alloc then
		if node.distanceToClassStart and node.distanceToClassStart > 0 then
			tooltip:AddSeparator(14)
			tooltip:AddLine(16, string.format("^7Distance to start: %d", node.distanceToClassStart))
		end
	end
end

function PassiveTreeViewClass:AddNodeTooltip(tooltip, node, build, incSmallPassiveSkillEffect)
	-- Special case for sockets
	if node.type == "Socket" and node.alloc then
		local socket, jewel = build.itemsTab:GetSocketAndJewelForNodeID(node.id)
		if jewel then
			build.itemsTab:AddItemTooltip(tooltip, jewel, { nodeId = node.id })
			if node.distanceToClassStart and node.distanceToClassStart > 0 then
				tooltip:AddSeparator(14)
				tooltip:AddLine(16, string.format("^7Distance to start: %d", node.distanceToClassStart))
			end
		else
			self:AddNodeName(tooltip, node, build)
		end
		tooltip:AddSeparator(14)
		if socket ~= nil and socket:IsEnabled() then
			tooltip:AddLine(14, colorCodes.TIP.."Tip: Right click this socket to go to the items page and choose the jewel for this socket.")
		end

		self:AddGlobalNodeWarningsToTooltip(tooltip, node, build)

		tooltip:AddLine(14, colorCodes.TIP.."Tip: Hold Shift or Ctrl to hide this tooltip.")
		return
	end

	-- Node name
	self:AddNodeName(tooltip, node, build)
	if launch.devModeAlt then
		if node.power and node.power.offence then
			-- Power debugging info
			tooltip:AddLine(16, string.format("DPS power: %g   Defence power: %g", node.power.offence, node.power.defence))
		end
	end

	-- add position dev info
	if launch.devModeAlt then
		tooltip:AddSeparator(14)
		tooltip:AddLine(16, string.format("^7Position: %d, %d", node.x, node.y))
		tooltip:AddLine(16, string.format("Angle: %f", node.angle))
		tooltip:AddLine(16, string.format("Orbit: %d, Orbit Index: %d", node.orbit, node.orbitIndex))
		tooltip:AddLine(16, string.format("Group: %d", node.g))
		tooltip:AddLine(16, string.format("AllocMode: %d", node.allocMode))
		tooltip:AddSeparator(14)

		-- add connection info for debugging
		for _, connection in ipairs(node.connections) do
			tooltip:AddLine(16, string.format("^7Connection: %d, Orbit: %d", connection.id, connection.orbit))
		end

		tooltip:AddSeparator(14)
	end

	local function addModInfoToTooltip(node, i, line, localIncEffect)
		if node.mods[i] then
			if launch.devModeAlt and node.mods[i].list then
				-- Modifier debugging info
				local modStr
				for _, mod in pairs(node.mods[i].list) do
					modStr = (modStr and modStr..", " or "^2") .. modLib.formatMod(mod)
				end
				if node.mods[i].extra then
					modStr = (modStr and modStr.."  " or "") .. colorCodes.NEGATIVE .. node.mods[i].extra
				end
				if modStr then
					line = line .. "  " .. modStr
				end
			end
			
			-- Apply Inc Node scaling from Hulking Form + Radius Jewels only visually
			if (((incSmallPassiveSkillEffect + localIncEffect) > 0 and node.type == "Normal") or (localIncEffect > 0 and node.type == "Notable")) and not node.isAttribute and not node.ascendancyName and node.mods[i].list then
				local scale = 1 + (node.type == "Normal" and incSmallPassiveSkillEffect or 0 + localIncEffect) / 100
				local modsList = copyTable(node.mods[i].list)
				local scaledList = new("ModList")
				scaledList:ScaleAddList(modsList, scale)
				for j, mod in ipairs(scaledList) do
					local newValue
					if type(mod.value) == "number" then
						newValue = mod.value
					elseif type(mod.value) == "table" then
						if mod.value.mod then
							newValue = mod.value.mod.value
						else
							newValue = mod.value.value
						end
					end
					if type(newValue) == "number" then
						line = line:gsub("%d*%.?%d+", math.abs(newValue), 1) -- Only scale first number in line
					end
				end
				-- line = line .. "  ^8(Effect increased by "..incSmallPassiveSkillEffect.."%)"
			end
			
			if line ~= " " and (node.mods[i].extra or not node.mods[i].list) then 
				local line = colorCodes.UNSUPPORTED..line
				line = main.notSupportedModTooltips and (line .. main.notSupportedTooltipText) or line
				tooltip:AddLine(16, line)
			else
				tooltip:AddLine(16, colorCodes.MAGIC..line)
			end
		end
	end

	local function mergeStats(nodeSd, jewelSd, spec)
		-- copy the original tree node so we ignore the mods being added from the jewel
		local nodeSdCopy = copyTable(nodeSd)
		local nodeNumber = 0
		local nodeString = ""
		local modToAddNumber = 0
		local modToAddString = ""

		-- loop the original node mods and compare to the jewel mod we want to add
		-- if the strings without the numbers are identical, the mods should be identical
		-- if so, update the node's version of the mod and do not add the jewel mods to the list
		-- otherwise, add the jewel mod because it's unique/new to the node
		for index, originalSd in ipairs(nodeSdCopy) do
			nodeString = originalSd:gsub("(%d+)", function(number)
				nodeNumber = number
				return ""
			end)
			modToAddString = jewelSd:gsub("(%d+)", function(number)
				modToAddNumber = number
				return ""
			end)
			if nodeString == modToAddString then
				nodeSd[index] = nodeSd[index]:gsub("(%d+)", (nodeNumber + modToAddNumber))
				return
			end
		end
		t_insert(nodeSd, jewelSd)
	end

	-- loop over mods generated in CalcSetup by rad.func calls and grab the lines added
	-- processStats once on copied node to cleanly setup for the tooltip
	local function processTimeLostModsAndGetLocalEffect(mNode, build)
		local localIncEffect = 0
		local hasWSCondition = false
		local newSd = copyTable(mNode.sd)
		for _, mod in ipairs(mNode.finalModList) do
			-- if the jewelMod has a WS Condition, only add the incEffect given it matches the activeWeaponSet
			-- otherwise the mod came from a jewel that is allocMode 0, so it always applies
			for _, modCriteria in ipairs(mod) do
				if modCriteria.type == "Condition" and modCriteria.var and modCriteria.var:match("^WeaponSet") then
					if (tonumber(modCriteria.var:match("(%d)")) == (build.itemsTab.activeItemSet.useSecondWeaponSet and 2 or 1)) then
						if mod.name == "JewelSmallPassiveSkillEffect" then
							localIncEffect = mod.value
						elseif mod.name == "JewelNotablePassiveSkillEffect" then
							localIncEffect = mod.value
						elseif mod.parsedLine then
							mergeStats(newSd, mod.parsedLine, build.spec)
						end
					end
					hasWSCondition = true
				end
			end
			if not hasWSCondition then
				if mod.name == "JewelSmallPassiveSkillEffect" then
					localIncEffect = mod.value
				elseif mod.name == "JewelNotablePassiveSkillEffect" then
						localIncEffect = mod.value
				elseif mod.parsedLine then
					mergeStats(newSd, mod.parsedLine, build.spec)
				end
			end
		end
		mNode.sd = copyTable(newSd)
		build.spec.tree:ProcessStats(mNode)
		return localIncEffect
	end
	
	-- we only want to run the timeLost function on a node that can could be in a jewel socket radius of up to Large
	-- essentially trying to avoid calling ProcessStats for a Normal/Notable node that can't possibly be affected
	-- loops potentially every socket (24) until itemsTab is loaded or a jewel socket is hovered, then it will only loop the allocated sockets
	local function isNodeInARadius(node) 
		local isInRadius = false
		for id, socket in pairs(build.itemsTab.sockets) do
			if build.itemsTab.activeSocketList and socket.inactive == false or socket.inactive == nil then
				isInRadius = isInRadius or (build.spec.nodes[id] and build.spec.nodes[id].nodesInRadius and build.spec.nodes[id].nodesInRadius[4][node.id] ~= nil)
				if isInRadius then break end
			end
		end
		return isInRadius
	end
	
	-- If so, check if the left hand tree is unallocated, but the right hand tree is allocated.
	-- Then continue processing as normal
	local mNode = copyTableSafe(node, true, true)

	-- This stanza actives for both Mastery and non Mastery tooltips. Proof: add '"Blah "..' to addModInfoToTooltip
	if not mNode.sd then
		ConPrintf("Node %d has no sd", node.id)
	end
	if mNode.sd and mNode.sd[1] and not mNode.allMasteryOptions then
		tooltip:AddLine(16, "")
		local localIncEffect = 0
		if not (mNode.isAttribute and not mNode.conqueredBy) and (mNode.type == "Normal" or mNode.type == "Notable") and isNodeInARadius(node) then
			localIncEffect = processTimeLostModsAndGetLocalEffect(mNode, build)
		end
		for i, line in ipairs(mNode.sd) do
			addModInfoToTooltip(mNode, i, line, localIncEffect)
		end
	end

	if node.containJewelSocket then
		tooltip:AddSeparator(14)
		-- Jewel socket with a jewel in it, show the jewel tooltip instead of the node tooltip
		local socket, jewel = build.itemsTab:GetSocketAndJewelForNodeID(node.id)
		if jewel then
			build.itemsTab:AddItemTooltip(tooltip, jewel, { nodeId = node.id })
			tooltip:AddSeparator(14)
		end

		if socket ~= nil and socket:IsEnabled() then
			tooltip:AddLine(14, colorCodes.TIP.."Tip: Right click this socket to go to the items page and choose the jewel for this socket.")
		end
	end

	-- Reminder text
	if node.reminderText then
		tooltip:AddSeparator(14)
		for _, line in ipairs(node.reminderText) do
			tooltip:AddLine(14, "^xA0A080"..line)
		end
	end

	-- Mod differences
	if self.showStatDifferences then
		local calcFunc, calcBase = build.calcsTab:GetMiscCalculator(build)
		tooltip:AddSeparator(14)
		local path = (node.alloc and node.depends) or self.tracePath or node.path or { }
		local pathLength = #path
		local pathNodes = { }
		for _, node in pairs(path) do
			pathNodes[node] = true
		end
		local nodeOutput, pathOutput
		local isGranted = build.calcsTab.mainEnv.grantedPassives[node.id]
		local realloc = false
		if node.alloc then
			-- Calculate the differences caused by deallocating this node and its dependent nodes
			nodeOutput = calcFunc({ removeNodes = { [node] = true } })
			if pathLength > 1 then
				pathOutput = calcFunc({ removeNodes = pathNodes })
			end
		elseif isGranted then
			-- Calculate the differences caused by deallocating this node
			nodeOutput = calcFunc({ removeNodes = { [node.id] = true } })
		else
			nodeOutput = calcFunc({ addNodes = { [node] = true } })
			if pathLength > 1 then
				pathOutput = calcFunc({ addNodes = pathNodes })
			end
		end
		local count = build:AddStatComparesToTooltip(tooltip, calcBase, nodeOutput, realloc and "^7Reallocating this node will give you:" or node.alloc and "^7Unallocating this node will give you:" or isGranted and "^7This node is granted by an item. Removing it will give you:" or "^7Allocating this node will give you:")
		if pathLength > 1 and not isGranted and (#node.intuitiveLeapLikesAffecting == 0 or node.alloc) then
			count = count + build:AddStatComparesToTooltip(tooltip, calcBase, pathOutput, node.alloc and "^7Unallocating this node and all nodes depending on it will give you:" or "^7Allocating this node and all nodes leading to it will give you:", pathLength)
		end
		if count == 0 then
			if isGranted then
				tooltip:AddLine(14, string.format("^7This node is granted by an item. Removing it will cause no changes"))
			else
				tooltip:AddLine(14, string.format("^7No changes from %s this node%s.", node.alloc and "unallocating" or "allocating", node.intuitiveLeapLikesAffecting == 0 and pathLength > 1 and " or the nodes leading to it" or ""))
			end
		end
		tooltip:AddLine(14, colorCodes.TIP.."Tip: Press Ctrl+D to disable the display of stat differences.")
	else
		tooltip:AddSeparator(14)
		tooltip:AddLine(14, colorCodes.TIP.."Tip: Press Ctrl+D to enable the display of stat differences.")
	end

	-- Pathing distance
	tooltip:AddSeparator(14)
	if node.path and #node.path > 0 then
		if self.traceMode and isValueInArray(self.tracePath, node) then
			tooltip:AddLine(14, "^7"..#self.tracePath .. " nodes in trace path")
			tooltip:AddLine(14, colorCodes.TIP)
		else
			tooltip:AddLine(14, "^7"..node.pathDist .. " points to node" .. (#node.intuitiveLeapLikesAffecting > 0 and " ^8(Can be allocated without pathing to it)" or ""))
			tooltip:AddLine(14, colorCodes.TIP)
			if #node.path > 1 then
				-- Handy hint!
				tooltip:AddLine(14, "Tip: To reach this node by a different path, hold Shift, then trace the path and click this node")
			end
		end
	end
	if node.depends and #node.depends > 1 then
		tooltip:AddSeparator(14)
		tooltip:AddLine(14, "^7"..#node.depends .. " points gained from unallocating these nodes")
		tooltip:AddLine(14, colorCodes.TIP)
	end

	self:AddGlobalNodeWarningsToTooltip(tooltip, node, build)

	if node.type == "Socket" then
		tooltip:AddLine(14, colorCodes.TIP.."Tip: Hold Shift or Ctrl to hide this tooltip.")
	else
		tooltip:AddLine(14, colorCodes.TIP.."Tip: Hold Ctrl to hide this tooltip.")
		tooltip:AddLine(14, colorCodes.TIP.."Tip: Press Ctrl+C to copy this node's text.")
	end
end

-- Helper function to check if a node is connected to weapon set nodes
function PassiveTreeViewClass:IsConnectedToWeaponSetNodes(node)
	-- First check the path for weapon set nodes
	if node.path and #node.path > 1 then
		-- Check all nodes in the path (except the first element since it's the target node itself)
		for i = 2, #node.path do
			local pathNode = node.path[i]
			if pathNode.alloc and pathNode.allocMode > 0 then
				return true
			end
		end
	end

	-- And finally check for direct connections when path is short or empty
	-- (This handles cases where global nodes are directly adjacent to weapon set nodes)
	if node.linked then
		for _, linkedNode in ipairs(node.linked) do
			if linkedNode.alloc and linkedNode.allocMode and linkedNode.allocMode > 0 then
				return true
			end
		end
	end

	return false
end

-- Helper function to add warnings in the tooltip for global nodes (keystones/jewel sockets)
function PassiveTreeViewClass:AddGlobalNodeWarningsToTooltip(tooltip, node, build)
	local isGlobalNode = node.type == "Keystone" or node.type == "Socket" or node.containJewelSocket

	if not isGlobalNode then
		return -- No warning needed for non-global nodes
	end

	local nodeTypeText = node.type == "Keystone" and "keystones" or "jewel sockets"
	local warningText = ""
	local tipText = ""

	if not node.alloc and node.path then
		-- Unallocated global node - check allocation conditions
		if build.spec.allocMode > 0 then
			warningText = "Cannot allocate " .. nodeTypeText .. " while weapon set " .. build.spec.allocMode .. " is selected"
			tipText = "Tip: Switch to main tree (Alt+scroll) to allocate " .. nodeTypeText
		elseif self:IsConnectedToWeaponSetNodes(node) then
			warningText = "Cannot allocate " .. nodeTypeText .. " - connected to weapon set nodes"
			tipText = "Tip: Deallocate weapon set nodes in the connection path to allow allocation"
		end
	elseif node.alloc and node.allocMode == 0 and build.spec.allocMode > 0 then
		-- Allocated main-tree global node viewed from weapon set
		warningText = "Cannot deallocate global " .. nodeTypeText .. " from weapon set " .. build.spec.allocMode
		tipText = "Tip: Switch to main tree (Alt+scroll) to deallocate " .. nodeTypeText
	end

	if warningText ~= "" then
		tooltip:AddSeparator(14)
		tooltip:AddLine(14, colorCodes.WARNING .. warningText)
		tooltip:AddLine(14, colorCodes.TIP .. tipText)
	end
end

function PassiveTreeViewClass:DrawAllocMode(allocMode, viewPort)
	local rgbColor
	if allocMode == 0 then
		return
	elseif allocMode == 1 then
		rgbColor = hexToRGB(colorCodes["NEGATIVE"]:sub(3))
	elseif allocMode == 2 then
		rgbColor = hexToRGB(colorCodes["POSITIVE"]:sub(3))
	end

	SetDrawLayer(nil, 80)
	SetDrawColor(rgbColor[1], rgbColor[2], rgbColor[3], 0.4)
	DrawImage(nil, viewPort.x, viewPort.y + viewPort.height - 20 , viewPort.width, 20)

	SetDrawColor(1, 1, 1, 1)
	DrawString(viewPort.x + 2, viewPort.y + viewPort.height - 20 + 2, "LEFT", 16, "VAR", string.format("^7Allocating Weapon set %d Mode", allocMode))

	SetDrawColor(1, 1, 1, 1)

	SetDrawLayer(nil, 10)
end

function PassiveTreeViewClass:LessLuminance()
	local luminanceFactor = 0.5
	local r,g,b,a = 1, 1, 1, 1
	local desaturationFactor = 0.5;
	local alphaFactor = 1;
	local luminance = 0.2126 * r + 0.7152 * g  + 0.0722 * b;

	-- Blend with original color
	local newR = (1.0 - desaturationFactor) * r + desaturationFactor * luminance;
	local newG = (1.0 - desaturationFactor) * g + desaturationFactor * luminance;
	local newB = (1.0 - desaturationFactor) * b + desaturationFactor * luminance;

	-- Apply luminance adjustment
	newR = newR * luminanceFactor;
	newG = newG * luminanceFactor;
	newB = newB * luminanceFactor;

	local newA = a * alphaFactor;
	SetDrawColor(newR, newG, newB, newA)
end