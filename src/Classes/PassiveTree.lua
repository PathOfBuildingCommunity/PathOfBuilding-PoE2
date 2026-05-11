-- Path of Building
--
-- Class: Passive Tree
-- Passive skill tree class.
-- Responsible for downloading and loading the passive tree data and assets
-- Also pre-calculates and pre-parses most of the data need to use the passive tree, including the node modifiers
--
local pairs = pairs
local ipairs = ipairs
local t_insert = table.insert
local t_remove = table.remove
local m_min = math.min
local m_max = math.max
local m_pi = math.pi
local m_sin = math.sin
local m_cos = math.cos
local m_tan = math.tan
local m_sqrt = math.sqrt
local m_rad = math.rad
local m_atan2 = math.atan2

-- Retrieve the file at the given URL
-- This is currently disabled as it does not work due to issues
-- its possible to fix this but its never used due to us performing preprocessing on tree
local function getFile(URL)
	local page = ""
	local easy = common.curl.easy()
	easy:setopt_url(URL)
	easy:setopt_writefunction(function(data)
		page = page..data
		return true
	end)
	easy:perform()
	easy:close()
	return #page > 0 and page
end

local PassiveTreeClass = newClass("PassiveTree", function(self, treeVersion)
	self.treeVersion = treeVersion
	self.scaleImage = 1 -- 0.3835
	local versionNum = treeVersions[treeVersion].num

	self.legion = LoadModule("Data/TimelessJewelData/LegionPassives")

	MakeDir("TreeData")

	ConPrintf("Loading passive tree data for version '%s'...", treeVersions[treeVersion].display)
	local treeText
	local treeFile = io.open("TreeData/"..treeVersion.."/tree.lua", "r")
	if treeFile then
		treeText = treeFile:read("*a")
		treeFile:close()
	else
		local page
		local pageFile = io.open("TreeData/"..treeVersion.."/data.json", "r")
		if pageFile then
			ConPrintf("Converting passive tree data json")
			page = pageFile:read("*a")
			pageFile:close()
		elseif main.allowTreeDownload then  -- Enable downloading with Ctrl+Shift+F5 (currently disabled)
			ConPrintf("Downloading passive tree data...")
			page = getFile("https://www.pathofexile.com/passive-skill-tree")
		end
		local treeData = page:match("var passiveSkillTreeData = (%b{})")
		if treeData then
			treeText = "local tree=" .. jsonToLua(page:match("var passiveSkillTreeData = (%b{})"))
			treeText = treeText .. "return tree"
		else
			treeText = "return " .. jsonToLua(page)
		end
		treeFile = io.open("TreeData/"..treeVersion.."/tree.lua", "w")
		treeFile:write(treeText)
		treeFile:close()
	end
	for k, v in pairs(assert(loadstring(treeText))()) do
		self[k] = v
	end

	self.size = m_min(self.max_x - self.min_x, self.max_y - self.min_y) * self.scaleImage * 1.1
	
	for i = 0, 6 do
		self.classes[i] = self.classes[i + 1]
		self.classes[i + 1] = nil
	end

	-- Build maps of class name -> class table
	self.classNameMap = { }
	self.ascendNameMap = { }
	self.classIntegerIdMap = { }
	self.internalAscendNameMap = { }
	self.classNotables = { }

	for classId, class in pairs(self.classes) do
		class.classes = class.ascendancies
		class.classes[0] = { name = "None" }
		self.classNameMap[class.name] = classId
		self.classIntegerIdMap[class.integerId] = classId
		for ascendClassId, ascendClass in pairs(class.classes) do
			self.ascendNameMap[ascendClass.id or ascendClass.name] = {
				classId = classId,
				class = class,
				ascendClassId = ascendClassId,
				ascendClass = ascendClass
			}

			if ascendClass.internalId then
				self.internalAscendNameMap[ascendClass.internalId] = {
					classId = classId,
					class = class,
					ascendClassId = ascendClassId,
					ascendClass = ascendClass
				}
			end
		end
	end

	self.skillsPerOrbit = self.constants.skillsPerOrbit
	self.orbitRadii = self.constants.orbitRadii
	self.orbitAnglesByOrbit = self.constants.orbitAnglesByOrbit

	ConPrintf("Loading passive tree assets...")
	for name, data in pairs(self.assets) do
		self:LoadImage(data[1], data, "MIPMAP")
	end

	self.ddsMap = { }
	self.ddsCoords = self.ddsCoords or { }
	for file, fileInfo in pairs(self.ddsCoords) do
		local data = { }
		self:LoadImage(file, data, "CLAMP")
		for name, position in pairs(fileInfo) do
			self.ddsMap[name] = {
				found = data.width > 0,
				handle = data.handle,
				width = data.width,
				height = data.height,
				[1] = position
			}
		end
	end

	for type, data in pairs(self.nodeOverlay) do
		local asset = self:GetAssetByName(data.alloc)
		local artWidth = asset.width * self.scaleImage
		data.artWidth = artWidth
		data.size = artWidth
		data.rsq = data.size * data.size
	end
	
	for _, group in pairs(self.groups) do
		group.n = group.nodes
		group.oo = { }
		for _, orbit in ipairs(group.orbits) do
			group.oo[orbit] = true
		end
	end

		-- Go away
		self.nodes.root = nil

	ConPrintf("Processing tree...")
	self.ascendancyMap = { }
	self.keystoneMap = { }
	self.notableMap = { }
	self.clusterNodeMap = { }
	self.sockets = { }
	self.masteryEffects = { }
	local nodeMap = { }
	for _, node in pairs(self.nodes) do
		node.id = node.skill
		node.g = node.group
		node.o = node.orbit
		node.oidx = node.orbitIndex
		node.dn = node.name
		node.sd = node.stats

		node.__index = node
		node.linkedId = { }
		nodeMap[node.id] = node

		-- Determine node type
		if node.classesStart then
			node.type = "ClassStart"
			for _, className in ipairs(node.classesStart) do
				local class = self.classes[self.classNameMap[className]]
				if class ~= nil then
					class.startNodeId = node.id
				end
			end
		elseif node.isAscendancyStart then
			node.type = "AscendClassStart"
			local ascendClass = self.ascendNameMap[node.ascendancyName].ascendClass
			ascendClass.startNodeId = node.id
			if node.isSwitchable then
				for ascName, _ in pairs(node.options) do
					local option = self.ascendNameMap[ascName].ascendClass
					option.startNodeId = node.id
				end
			end
		elseif node.isOnlyImage then
			node.type = "OnlyImage"
		elseif node.isJewelSocket then
			node.type = "Socket"
			self.sockets[node.id] = node
		elseif node.ks or node.isKeystone then
			node.type = "Keystone"
			self.keystoneMap[node.dn] = node
			self.keystoneMap[node.dn:lower()] = node
		elseif node["not"] or node.isNotable then
			node.type = "Notable"
			if not node.ascendancyName then
				-- Some nodes have duplicate names in the tree data for some reason, even though they're not on the tree
				-- Only add them if they're actually part of a group (i.e. in the tree)
				-- Add everything otherwise, because cluster jewel notables don't have a group
				if not self.notableMap[node.dn:lower()] then
					self.notableMap[node.dn:lower()] = node
				elseif node.g then
					self.notableMap[node.dn:lower()] = node
				end
			else
				if node.containJewelSocket then
					self.sockets[node.id] = node
				end
				self.ascendancyMap[node.dn:lower()] = node
				if not self.classNotables[self.ascendNameMap[node.ascendancyName].class.name] then
					self.classNotables[self.ascendNameMap[node.ascendancyName].class.name] = { }
				end
				if self.ascendNameMap[node.ascendancyName].class.name ~= "Scion" then
					t_insert(self.classNotables[self.ascendNameMap[node.ascendancyName].class.name], node.dn)
				end
			end
		else
			node.type = "Normal"
			if node.ascendancyName == "Ascendant" and not node.dn:find("Dexterity") and not node.dn:find("Intelligence") and
				not node.dn:find("Strength") and not node.dn:find("Passive") then
				self.ascendancyMap[node.dn:lower()] = node
				if not self.classNotables[self.ascendNameMap[node.ascendancyName].class.name] then
					self.classNotables[self.ascendNameMap[node.ascendancyName].class.name] = { }
				end
				t_insert(self.classNotables[self.ascendNameMap[node.ascendancyName].class.name], node.dn)
			end
		end

		-- Find the node group
		local group = self.groups[node.g]
		if group then
			node.group = group
			group.ascendancyName = node.ascendancyName
			if node.isAscendancyStart then
				group.isAscendancyStart = true
			end
		elseif node.type == "Notable" or node.type == "Keystone" then
			self.clusterNodeMap[node.dn] = node
		end

		self:ProcessNode(node)
	end

	-- Pregenerate the polygons for the node connector lines
	self.connectors = { }
	for _, node in pairs(self.nodes) do
		for _, connection in pairs(node.connections or {}) do
			local otherId = connection.id
			local other = nodeMap[otherId]

			if not other then
				ConPrintf("missing node "..otherId)
				goto endConnection
			end

			if node.type == "OnlyImage" or other.type == "OnlyImage" then
				goto endConnection
			end

			if node.id == otherId then
				goto endConnection
			end

			t_insert(other.linkedId, node.id)
			t_insert(node.linkedId, otherId)
			
			if node.ascendancyName ~= other.ascendancyName then
				goto endConnection
			end

			if node.classesStart ~= nil or other.classesStart ~= nil then
				goto endConnection
			end

			local connectors = self:BuildConnector(node, other, connection)

			if not connectors then
				goto endConnection
			end
			t_insert(self.connectors, connectors[1])
			if connectors[2] then
				t_insert(self.connectors, connectors[2])
			end
			:: endConnection ::
		end
	end

	-- Precalculate the lists of nodes that are within each radius of each socket
	for nodeId, socket in pairs(self.sockets) do
		if socket.name == "Charm Socket" then
			socket.charmSocket = true
		elseif not socket.containJewelSocket then
			socket.nodesInRadius = { }
			socket.attributesInRadius = { }
			for radiusIndex, _ in ipairs(data.jewelRadius) do
				socket.nodesInRadius[radiusIndex] = { }
				socket.attributesInRadius[radiusIndex] = { }
			end

			local minX, maxX = socket.x - data.maxJewelRadius, socket.x + data.maxJewelRadius
			local minY, maxY = socket.y - data.maxJewelRadius, socket.y + data.maxJewelRadius

			for _, node in pairs(self.nodes) do
				if node.x and node.x >= minX and node.x <= maxX and node.y and node.y >= minY and node.y <= maxY
					and node ~= socket and not node.isBlighted and node.group and not node.isProxy
					and not node.group.isProxy and not node.isMastery then
						local vX, vY = node.x - socket.x, node.y - socket.y
						local distSquared = vX * vX + vY * vY
						for radiusIndex, radiusInfo in ipairs(data.jewelRadius) do
							if distSquared <= radiusInfo.outerSquared and radiusInfo.innerSquared <= distSquared then
								socket.nodesInRadius[radiusIndex][node.id] = node
							end
						end
				end
			end
		end
	end

	for name, keystone in pairs(self.keystoneMap) do
		if not keystone.nodesInRadius then
			keystone.nodesInRadius = { }
			for radiusIndex, _ in ipairs(data.jewelRadius) do
				keystone.nodesInRadius[radiusIndex] = { }
			end

			if (keystone.x and keystone.y) then
				local minX, maxX = keystone.x - data.maxJewelRadius, keystone.x + data.maxJewelRadius
				local minY, maxY = keystone.y - data.maxJewelRadius, keystone.y + data.maxJewelRadius

				for _, node in pairs(self.nodes) do
					if node.x and node.x >= minX and node.x <= maxX and node.y and node.y >= minY and node.y <= maxY
						and node ~= keystone and not node.isBlighted and node.group and not node.isProxy
						and not node.group.isProxy and not node.OnlyImage and not node.isSocket then
							local vX, vY = node.x - keystone.x, node.y - keystone.y
							local distSquared = vX * vX + vY * vY
							for radiusIndex, radiusInfo in ipairs(data.jewelRadius) do
								if distSquared <= radiusInfo.outerSquared and radiusInfo.innerSquared <= distSquared then
									keystone.nodesInRadius[radiusIndex][node.id] = node
								end
							end
					end
				end
			end
		end
	end

	for classId, class in pairs(self.classes) do
		local startNode = nodeMap[class.startNodeId]
		for _, nodeId in ipairs(startNode.linkedId) do
			local node = nodeMap[nodeId]
			if node.type == "Normal" then
				node.modList:NewMod("Condition:ConnectedTo"..class.name.."Start", "FLAG", true, "Tree:"..nodeId)
			end
		end
	end
	
	-- Build ModList for legion jewels
	for _, node in pairs(self.legion.nodes) do
		-- Determine node type
		if node.m then
			node.type = "Mastery"
		elseif node.ks then
			node.type = "Keystone"
			if not self.keystoneMap[node.dn] then -- Don't override good tree data with legacy keystones
				self.keystoneMap[node.dn] = node
			end
		elseif node["not"] then
			node.type = "Notable"
		else
			node.type = "Normal"
		end
		
		--todo: update sprites? icon stuff
		---- Assign node artwork assets
		--node.sprites = self.spriteMap[node.icon]
		--if not node.sprites then
		--	--error("missing sprite "..node.icon)
		--	node.sprites = { }
		--end

		self:ProcessStats(node)
	end
end)

function PassiveTreeClass:ProcessStats(node, startIndex)
	startIndex = startIndex or 1
	if startIndex == 1 then
		node.modKey = ""
		node.mods = { }
		node.modList = new("ModList")
	end

	if not node.sd then
		return
	end

	-- Parse node modifier lines
	local i = startIndex
	while node.sd[i] do
		if node.sd[i]:match("\n") then
			local line = node.sd[i]
			local il = i
			t_remove(node.sd, i)
			for line in line:gmatch("[^\n]+") do
				t_insert(node.sd, il, line)
				il = il + 1
			end
		end
		local line = node.sd[i]
		local list, extra = modLib.parseMod(line)
		if not list or extra then
			-- Try to combine it with one or more of the lines that follow this one
			local endI = i + 1
			while node.sd[endI] do
				local comb = line
				for ci = i + 1, endI do
					comb = comb .. " " .. node.sd[ci]
				end
				list, extra = modLib.parseMod(comb, true)
				if list and not extra then
					-- Success, add dummy mod lists to the other lines that were combined with this one
					for ci = i + 1, endI do
						node.mods[ci] = { list = { } }
					end
					break
				end
				endI = endI + 1
			end
		end
		if not list then
			-- Parser had no idea how to read this modifier
			node.unknown = true
		elseif extra then
			-- Parser recognised this as a modifier but couldn't understand all of it
			node.extra = true
		else
			for _, mod in ipairs(list) do
				node.modKey = node.modKey.."["..modLib.formatMod(mod).."]"
			end
		end
		node.mods[i] = { list = list, extra = extra }
		i = i + 1
		while node.mods[i] do
			-- Skip any lines with dummy lists added by the line combining code
			i = i + 1
		end
	end

	-- Build unified list of modifiers from all recognised modifier lines
	for i = startIndex, #node.mods do
		local mod = node.mods[i]
		if mod.list and not mod.extra then
			for i, mod in ipairs(mod.list) do
				mod = modLib.setSource(mod, "Tree:"..node.id)
				node.modList:AddMod(mod)
			end
		end
	end
	if node.type == "Keystone" then
		node.keystoneMod = modLib.createMod("Keystone", "LIST", node.dn, "Tree"..node.id)
	end
end

-- Common processing code for nodes (used for both real tree nodes and subgraph nodes)
function PassiveTreeClass:ProcessNode(node)
	node.targetSize = self:GetNodeTargetSize(node)
	local overlayData
	if node.nodeOverlay then
		overlayData = { }
		for type, data in pairs(node.nodeOverlay) do
			overlayData[type] = data
		end
		local asset = self:GetAssetByName(overlayData.alloc)
		local artWidth = asset.width * self.scaleImage
		overlayData.artWidth = artWidth
		overlayData.size = artWidth
		overlayData.rsq = overlayData.size * overlayData.size
	else
		overlayData = self.nodeOverlay[node.type]
	end
	node.overlay = overlayData
	if node.overlay then
		local size = node.targetSize["overlay"] and node.targetSize["overlay"].width or node.targetSize.width
		node.rsq = size * size
		node.size = size
	end

	-- Derive the true position of the node
	if node.group then
		node.angle = self.orbitAnglesByOrbit[node.o + 1][node.oidx + 1]
		local orbitRadius = self.orbitRadii[node.o + 1]  * self.scaleImage
		node.x = (node.group.x * self.scaleImage) + m_sin(node.angle) * orbitRadius
		node.y = (node.group.y * self.scaleImage) - m_cos(node.angle) * orbitRadius
	end

	-- organize recipe aka oils
	if node.recipe then
		node.infoRecipe = { }
		for _, oil in ipairs(node.recipe) do
			table.insert(node.infoRecipe, {
				name = oil,
				sprite = self:GetAssetByName(oil)
			})
		end
	end

	self:ProcessStats(node)

	-- if this node isSwitchable then parse also subnodes
	if node.isSwitchable or node.isAttribute then
		for class, switchNode in pairs(node.options) do
			setmetatable(switchNode, { __index = node })
			if node.isAttribute then
				switchNode.id = node.id
			end
			switchNode.dn = switchNode.name
			switchNode.sd = switchNode.stats

			if switchNode.jewelOverlay then
				ConPrintf("SwitchNode with jewelOverlay found: "..switchNode.name)
				switchNode.overlay = switchNode.jewelOverlay
				if switchNode.overlay then
					local size = node.targetSize["overlay"] and node.targetSize["overlay"].width or node.targetSize.width
					switchNode.rsq = size * size
					switchNode.size = size
				end
			end

			self:ProcessStats(switchNode)
		end
	end
end

-- Checks if a given image is present and downloads it from the given URL if it isn't there
function PassiveTreeClass:LoadImage(imgName, data, ...)
	local imgFile = io.open("TreeData/"..self.treeVersion.."/"..imgName, "r")
	if imgFile then
		imgFile:close()
	else
		ConPrintf("Image '%s' not found...", imgName)
	end
	data.handle = NewImageHandle()
	data.handle:Load("TreeData/"..self.treeVersion.."/"..imgName, ...)
	data.width, data.height = data.handle:ImageSize()
end

-- Generate the quad used to render the line between the two given nodes
function PassiveTreeClass:BuildConnector(node1, node2, connection)
	local connector = {
		ascendancyName = node1.ascendancyName,
		connectionArt = node1.connectionArt or node2.connectionArt or self.connectionArt[node1.ascendancyName and "ascendancy" or "default"],
		nodeId1 = node1.id,
		nodeId2 = node2.id,
		c = { } -- This array will contain the quad's data: 1-8 are the vertex coordinates, 9-16 are the texture coordinates
				-- Only the texture coords are filled in at this time; the vertex coords need to be converted from tree-space to screen-space first
				-- This will occur when the tree is being drawn; .vert will map line state (Normal/Intermediate/Active) to the correct tree-space coordinates
	}

	if connection.orbit ~= 0 and self.orbitRadii[math.abs(connection.orbit) + 1] then
		local orbit = math.abs(connection.orbit)
		local r =  self.orbitRadii[orbit + 1] * self.scaleImage

		local dx, dy = node2.x - node1.x, node2.y - node1.y
		local dist = m_sqrt(dx * dx + dy * dy)

		if dist < r * 2 then
			local perp = m_sqrt(r * r - (dist * dist) / 4) * (connection.orbit > 0 and 1 or -1)
			local cx = node1.x + dx / 2 + perp * (dy / dist)
			local cy = node1.y + dy / 2 - perp * (dx / dist)

			local angle1 = m_atan2(node1.y - cy, node1.x - cx)
			local angle2 = m_atan2(node2.y - cy, node2.x - cx)

			-- Nodes are in the same orbit of the same group
			-- Calculate the starting angle (node1.angle) and arc angle
			if angle1 > angle2 then
				angle1, angle2 = angle2, angle1
			end
			local arcAngle = angle2 - angle1
			if arcAngle >= m_pi then
				angle1, angle2 = angle2, angle1
				arcAngle = m_pi * 2 - arcAngle
			end

			angle1 = angle1 + m_pi / 2
			if arcAngle <= m_pi then
				-- Angle is less than 180 degrees, draw an arc
				-- If our arc is greater than 90 degrees, we will need 2 arcs because our orbit assets are at most 90 degree arcs see below
				-- The calling class already handles adding a second connector object in the return table if provided and omits it if nil
				-- Establish a nil secondConnector to populate in the case that we need a second arc (>90 degree orbit)
				local secondConnector
				if arcAngle > (m_pi / 2) then
					-- Angle is greater than 90 degrees.
					-- The default behavior for a given arcAngle is to place the arc at the center point between two nodes and clip the excess
					-- If we need a second arc of any size, we should shift the arcAngle to 25% of the distance between the nodes instead of 50%
					arcAngle = arcAngle / 2
					-- clone the original connector table to ensure same functionality for both of the necessary connectors
					secondConnector = copyTableSafe(connector)
					-- And then ask the BuildArc function to create a connector that is a mirror of the provided arcAngle
					-- Provide the second connector as a parameter to store the mirrored arc
					self:BuildArc(arcAngle, orbit, cx , cy , angle1, secondConnector, true)
				end
				-- generate the primary arc -- this arcAngle may have been modified if we have determined that a second arc is necessary for this orbit
				self:BuildArc(arcAngle, orbit,  cx, cy , angle1, connector)
				return { connector, secondConnector }
			end
		end

		-- return
	elseif node1.g == node2.g and node1.o == node2.o and connection.orbit == 0 then
		-- Nodes are in the same orbit of the same group
		-- Calculate the starting angle (node1.angle) and arc angle
		if node1.angle > node2.angle then
			node1, node2 = node2, node1
		end
		local arcAngle = node2.angle - node1.angle
		if arcAngle >= m_pi then
			node1, node2 = node2, node1
			arcAngle = m_pi * 2 - arcAngle
		end
		if arcAngle <= m_pi then
			-- Angle is less than 180 degrees, draw an arc
			-- If our arc is greater than 90 degrees, we will need 2 arcs because our orbit assets are at most 90 degree arcs see below
			-- The calling class already handles adding a second connector object in the return table if provided and omits it if nil
			-- Establish a nil secondConnector to populate in the case that we need a second arc (>90 degree orbit)
			local secondConnector
			if arcAngle > (m_pi / 2) then
				-- Angle is greater than 90 degrees.
				-- The default behavior for a given arcAngle is to place the arc at the center point between two nodes and clip the excess
				-- If we need a second arc of any size, we should shift the arcAngle to 25% of the distance between the nodes instead of 50%
				arcAngle = arcAngle / 2
				-- clone the original connector table to ensure same functionality for both of the necessary connectors
				secondConnector = copyTableSafe(connector)
				-- And then ask the BuildArc function to create a connector that is a mirror of the provided arcAngle
				-- Provide the second connector as a parameter to store the mirrored arc
				self:BuildArc(arcAngle, node1.o, node1.group.x * self.scaleImage, node1.group.y * self.scaleImage, node1.angle, secondConnector, true)
			end
			-- generate the primary arc -- this arcAngle may have been modified if we have determined that a second arc is necessary for this orbit
			self:BuildArc(arcAngle, node1.o, node1.group.x * self.scaleImage, node1.group.y * self.scaleImage, node1.angle, connector)
			return { connector, secondConnector }
		end
	end

	-- Generate a straight line
	connector.type = "LineConnector"
	local art = self:GetAssetByName(connector.connectionArt .. "LineConnectorNormal")
	local vX, vY = node2.x - node1.x, node2.y - node1.y
	local dist = m_sqrt(vX * vX + vY * vY)
	local scale = art.height * 0.5 * self.scaleImage / dist
	local nX, nY = vX * scale, vY * scale
	local endS = dist / (art.width * self.scaleImage)
	connector[1], connector[2] = node1.x - nY, node1.y + nX
	connector[3], connector[4] = node1.x + nY, node1.y - nX
	connector[5], connector[6] = node2.x + nY, node2.y - nX
	connector[7], connector[8] = node2.x - nY, node2.y + nX
	connector.c[9], connector.c[10] = 0, 1
	connector.c[11], connector.c[12] = 0, 0
	connector.c[13], connector.c[14] = endS, 0
	connector.c[15], connector.c[16] = endS, 1
	connector.vert = { Normal = connector, Intermediate = connector, Active = connector }
	return { connector }
end

function PassiveTreeClass:BuildArc(arcAngle, orbit, xScale, yScale, angle, connector, isMirroredArc)
	connector.type = "Orbit" .. orbit
	-- This is an arc texture mapped onto a kite-shaped quad
	-- Calculate how much the arc needs to be clipped by
	-- Both ends of the arc will be clipped by this amount, so 90 degree arc angle = no clipping and 30 degree arc angle = 75 degrees of clipping
	-- The clipping is accomplished by effectively moving the bottom left and top right corners of the arc texture towards the top left corner
	-- The arc texture only shows 90 degrees of an arc, but some arcs must go for more than 90 degrees
	-- Fortunately there's nowhere on the tree where we can't just show the middle 90 degrees and rely on the node artwork to cover the gaps :)
	local clipAngle = m_pi / 4 - arcAngle / 2
	local p = 1 - m_max(m_tan(clipAngle), 0)
	local angle = angle - clipAngle
	if isMirroredArc then
		-- The center of the mirrored angle should be positioned at 75% of the way between nodes.
		angle = angle + arcAngle
	end
	connector.vert = { }
	for _, state in pairs({ "Normal", "Intermediate", "Active" }) do
		-- The different line states have differently-sized artwork, so the vertex coords must be calculated separately for each one
		local art  = self:GetAssetByName( connector.connectionArt .. connector.type .. state)
		local size =  art.width * self.scaleImage --self.orbitRadii[orbit + 1]  * self.scaleImage
		local oX, oY = size * m_sqrt(2) * m_sin(angle + m_pi / 4), size * m_sqrt(2) * -m_cos(angle + m_pi / 4)
		local cX, cY = xScale + oX, yScale + oY
		local vert = { }
		vert[1], vert[2] = xScale, yScale
		vert[3], vert[4] = cX + (size * m_sin(angle) - oX) * p, cY + (size * -m_cos(angle) - oY) * p
		vert[5], vert[6] = cX, cY
		vert[7], vert[8] = cX + (size * m_cos(angle) - oX) * p, cY + (size * m_sin(angle) - oY) * p
		if (isMirroredArc) then
		-- Flip the quad's non-origin, non-center vertexes when drawing a mirrored arc so that the arc actually mirrored
		-- This is required to prevent the connection of the 2 arcs appear to have a 'seam'
			local temp1, temp2 = vert[3],vert[4]
			vert[3],vert[4] = vert[7],vert[8]
			vert[7],vert[8] = temp1, temp2
		end
		connector.vert[state] = vert
	end
	connector.c[9], connector.c[10] = 1, 1
	connector.c[11], connector.c[12] = 0, p
	connector.c[13], connector.c[14] = 0, 0
	connector.c[15], connector.c[16] = p, 0
end

function PassiveTreeClass:CalcOrbitAngles(nodesInOrbit)
	local orbitAngles = {}

	if nodesInOrbit == 16 then
		-- Every 30 and 45 degrees, per https://github.com/grindinggear/skilltree-export/blob/3.17.0/README.md
		orbitAngles = { 0, 30, 45, 60, 90, 120, 135, 150, 180, 210, 225, 240, 270, 300, 315, 330 }
	elseif nodesInOrbit == 40 then
		-- Every 10 and 45 degrees
		orbitAngles = { 0, 10, 20, 30, 40, 45, 50, 60, 70, 80, 90, 100, 110, 120, 130, 135, 140, 150, 160, 170, 180, 190, 200, 210, 220, 225, 230, 240, 250, 260, 270, 280, 290, 300, 310, 315, 320, 330, 340, 350 }
	else
		-- Uniformly spaced
		for i = 0, nodesInOrbit do
			orbitAngles[i + 1] = 360 * i / nodesInOrbit
		end
	end

	for i, degrees in ipairs(orbitAngles) do
		orbitAngles[i] = m_rad(degrees)
	end

	return orbitAngles
end

function PassiveTreeClass:GetAssetByName(name, type)
	return self.ddsMap[name] or self.assets[name]
end

function PassiveTreeClass:GetNodeTargetSize(node)
	if node.isAscendancyStart then
		return {
			['overlay'] = { width = math.floor(50 * self.scaleImage), height = math.floor(50 * self.scaleImage) },
		}
	elseif node.type == "Normal" and node.ascendancyName then
		return {
			['overlay'] = { width = math.floor(80 * self.scaleImage), height = math.floor(80 * self.scaleImage) },
			width = math.floor(37  * self.scaleImage), height = math.floor( 37  * self.scaleImage)
		}
	elseif node.containJewelSocket then
		return {
			['overlay'] = { width = math.floor(80 * self.scaleImage), height = math.floor(80 * self.scaleImage) },
			width = math.floor(80 * self.scaleImage), height = math.floor(80 * self.scaleImage)
		}
	elseif node.ascendancyName then
		return {
			['overlay'] = { width = math.floor(100 * self.scaleImage), height = math.floor(100 * self.scaleImage) },
			width = math.floor(54  * self.scaleImage), height = math.floor( 54  * self.scaleImage)
		}
	elseif node.type == "Notable"then
		return {
			['effect'] =  { width = math.floor(380 * self.scaleImage), height = math.floor(380 * self.scaleImage) },
			['overlay'] = { width = math.floor(80 * self.scaleImage), height = math.floor(80 * self.scaleImage) },
			width = math.floor(54 * self.scaleImage), height = math.floor(54 * self.scaleImage)
		}
	elseif node.type == "AscendClassStart" then
		return {
			['effect'] =  { width = math.floor(380 * self.scaleImage), height = math.floor(380 * self.scaleImage) },
			['overlay'] = { width = math.floor(48 * 0.5 * self.scaleImage), height = math.floor(48 * 0.5 * self.scaleImage) },
			width = math.floor(32 * 0.5 * self.scaleImage), height = math.floor(32 * 0.5 * self.scaleImage)
		}
	elseif node.type == "OnlyImage" then
		return { width = math.floor(380 * self.scaleImage), height = math.floor(380 * self.scaleImage) }
	elseif node.type == "Keystone" then
		return {
			['effect'] =  { width = math.floor(380 * self.scaleImage), height = math.floor(380 * self.scaleImage) },
			['overlay'] = { width = math.floor(120 * self.scaleImage), height = math.floor(120 * self.scaleImage) },
			width = math.floor(82 * self.scaleImage), height = math.floor(82 * self.scaleImage)
		}
	elseif node.type == "Normal" then
		return {
			['overlay'] = { width = math.floor(54 * self.scaleImage), height = math.floor(54 * self.scaleImage) },
			width = math.floor(37  * self.scaleImage), height = math.floor( 37  * self.scaleImage)
		}
	elseif node.type == "Socket" then
		return {
			['overlay'] = {width = math.floor(76 * self.scaleImage), height = math.floor(76 * self.scaleImage) },
			width = math.floor(76 * self.scaleImage), height = math.floor(76 * self.scaleImage)
		}
	elseif node.type == "ClassStart" then
		return {
			['overlay'] = { width = math.floor(1 * self.scaleImage), height = math.floor(1 * self.scaleImage) },
			width = math.floor(37  * self.scaleImage), height = math.floor( 37  * self.scaleImage)
		}
	else
		return { width = 0, height = 0 }
	end
end