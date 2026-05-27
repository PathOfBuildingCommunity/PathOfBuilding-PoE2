local basePath = GetWorkDir() .. "/../TreeData/"
local version = "0_5"
local path = basePath .. version .. "/"
local fileTree = path .. "tree.lua"

-- you should clone the passive tree data from 
-- https://github.com/grindinggear/poe2-skilltree-export/tree/main
-- and set the path to the clone folder here
local fileGGGCloneFolder = "D:\\dev_poe\\poe2-skilltree-export"
local assetsFolder = fileGGGCloneFolder .. "\\assets"
local fileAssets = {
	"frame.json", "background.json", "skills.json", "mastery-effect-active.json", "group-background.json"
}

local json = require("dkjson")

local function round_to(num, decimal_places)
    local multiplier = 10 ^ decimal_places
    return math.floor(num * multiplier + 0.5) / multiplier
end

local function arcDirection(fromNode, toNode, edge)
    -- vectors from arc center to each node
    local v1x = fromNode.x - edge.orbitX
    local v1y = fromNode.y - edge.orbitY
    local v2x = toNode.x   - edge.orbitX
    local v2y = toNode.y   - edge.orbitY

    -- signed angle from v1 to v2, in (-pi, pi]
    local dot   = v1x * v2x + v1y * v2y
    local cross = v1x * v2y - v1y * v2x
    local angle = math.atan2(cross, dot)

    return cross > 0 and -1 or 1
end

local function CalcOrbitAngles(nodesInOrbit)
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
		orbitAngles[i] = math.rad(degrees)
	end

	return orbitAngles
end

local function baseTree(idPassiveTree)
	return {
		["tree"] = idPassiveTree,
		["min_x"]= 0,
		["min_y"]= 0,
		["max_x"]= 0,
		["max_y"]= 0,
		["classes"] = {},
		["groups"] = { },
		["nodes"]= { },
		["assets"]={},
		["ddsCoords"] = {},
		["jewelSlots"] = {},
		["constants"]= { -- calculate this
			["classes"]= {
				["StrDexIntClass"]= 0,
				["StrClass"]= 1,
				["DexClass"]= 2,
				["IntClass"]= 3,
				["StrDexClass"]= 4,
				["StrIntClass"]= 5,
				["DexIntClass"]= 6
			},
			["characterAttributes"]= {
				["Strength"]= 0,
				["Dexterity"]= 1,
				["Intelligence"]= 2
			},
			["PSSCentreInnerRadius"]= 130,
			["skillsPerOrbit"]= {},
			["orbitAnglesByOrbit"] = {},
			["orbitRadii"]= {
				0, 82, 162, 335, 493, 662, 846, 251, 1080, 1322
			},
		},
		["nodeOverlay"] = {
			Normal = {
				alloc = "PSSkillFrameActive",
				path = "PSSkillFrameHighlighted",
				unalloc = "PSSkillFrame",
			},
			Notable = {
				alloc = "NotableFrameAllocated",
				path = "NotableFrameCanAllocate",
				unalloc = "NotableFrameUnallocated",
			},
			Keystone = {
				alloc = "KeystoneFrameAllocated",
				path = "KeystoneFrameCanAllocate",
				unalloc = "KeystoneFrameUnallocated",
			},
			Socket = {
				alloc = "JewelFrameAllocated",
				path = "JewelFrameCanAllocate",
				unalloc = "JewelFrameUnallocated",
			},
		},
		["connectionArt"] = {
			default = "Character",
			ascendancy = "CharacterAscendancy",
		},
	}
end

-- load and decode the data.json file
local file, err = io.open(fileGGGCloneFolder .. "\\data.json", "r")

if file == nil then
	printf("Error opening file " .. fileGGGCloneFolder .. "\\data.json")
	printf(err)
	return
end

local content = file:read("*a")
file:close()
local data, pos, err = json.decode(content, 1, nil)
if err then
	printf("Error decoding JSON: " .. err)
	return
end

local tree = baseTree(data.tree)

-- jewelSlots
for _, jewelSlot in ipairs(data.jewelSlots) do
	table.insert(tree.jewelSlots, jewelSlot)
end

-- build classes
local ascendancySeachNameById  = {}
for i,class in ipairs(data.classes) do
	if #class.ascendancies == 0 then
		print("Skipping class " .. class.name .. " because it has no ascendancy classes")
		goto classcontinue
	end

	local classData = {
		["base_dex"] = class.base_dex,
		["base_int"] = class.base_int,
		["base_str"] = class.base_str,
		["name"] = class.name,
		["integerId"] = i - 1,
		["ascendancies"] = {},
		["background"] = {
			active={
				height=2000,
				width=2000
			},
			bg={
				height=2000,
				width=2000
			},
			height=1500,
			image="class" .. class.name ..":Class0",
			section="AscendancyBackground",
			width=1500,
			x= 0,
			y= 0,
		}
	}

	for indexAscendancy, ascendancy in ipairs(class.ascendancies) do
		if ascendancy.id == "Witch3b" then
			print("Ignoring Abysal Lich no way to handle from data.json")
			goto nextAscendancy
		end
		if not ascendancy.name then
			print("Skipping ascendancy with id " .. ascendancy.id .. " because it has no name")
			goto nextAscendancy
		end
		local imageName = "class" .. class.name .. ":Class" .. indexAscendancy
		local replaceBy, replace
		if ascendancy.id == "Witch3b" then
			imageName =	"class" .. class.name .. ":Class" .. indexAscendancy - 1 
			replace = "Lich"
		elseif ascendancy.id == "Witch3" then
			replaceBy = "Abyssal Lich"
		end

		local ascendancyData = {
			["internalId"] = ascendancy.id,
			["name"] = ascendancy.name,
			["id"] = ascendancy.name,
			["background"] = {
				height=1500,
				image= imageName,
				section="AscendancyBackground",
				width=1500,
				x= ascendancy.offsetX,
				y= ascendancy.offsetY,
			},
			replace = replace,
			replaceBy = replaceBy
		}
		ascendancySeachNameById[ascendancy.id] = ascendancy.name
		table.insert(classData.ascendancies, ascendancyData)
		:: nextAscendancy ::
	end

	table.insert(tree.classes, classData)

	-- Load background-[class] dinamically
	table.insert(fileAssets, "background-" .. string.lower(class.name) .. ".json")
	:: classcontinue ::
end

local orbitsConstants = {}

-- build groups
print("Building groups")
for groupId, group in pairs(data.groups) do
	local groupData = {
		["x"] = round_to(group.x, 2),
		["y"] = round_to(group.y, 2),
		["orbits"] = group.orbits,
		["nodes"] = {},
	}
	for _, node in pairs(group.nodes) do
		if not data.nodes[node] or data.nodes[node].id == nil then
			printf("Skipping node " .. node .. " not id found")
			goto nextgroupnode
		end
		table.insert(groupData.nodes, tonumber(node))
		:: nextgroupnode ::
	end
	tree.groups[tonumber(groupId)] = groupData
end

-- build nodes
print("Building nodes")
local attributesNodesId = {26297, 14927, 57022}
local ascendancyGroups = {}
local classessNodeIds = {}

for id, node in pairs(data.nodes) do
	if node.id == nil then
		printf("Node with id " .. id .. " has no id, skipping")
		goto nextNode
	end

	local nodeId = tonumber(id == "root" and 0 or id)
	local nodeData = {
		["group"] = node.group,
		["orbit"] = node.orbit,
		["skill"] = nodeId,
		["orbitIndex"] = node.orbitIndex,
		["icon"] = node.icon,
		["name"] = escapeGGGString(node.name),
		["isNotable"] = node.isNotable,
		["isKeystone"] = node.isKeystone,
		["isOnlyImage"] = node.isMastery,
		["activeEffectImage"] =  node.activeEffectImage,
		["isJewelSocket"] = node.isJewelSocket and not node.ascendancyId and true or nil,
		["containJewelSocket"] = node.isJewelSocket and node.ascendancyId and true or nil,
		["isAscendancyStart"] = node.isAscendancyStart,
		["isMultipleChoice"] = node.isMultipleChoice,
		["isMultipleChoiceOption"] = node.isMultipleChoiceOption,
		["isFreeAllocate"] = node.isFree,
		["ascendancyName"] = node.ascendancyId and ascendancySeachNameById[node.ascendancyId] or nil,
		["connections"] = {}
	}

	-- Fix background for ascendancyStart
	if node.ascendancyId then
		if not node.isJewelSocket then
			nodeData["nodeOverlay"] = {
				alloc= node.isNotable and "AscendancyFrameNotableAllocated" or "AscendancyFrameNormalAllocated",
				path=  node.isNotable and "AscendancyFrameNotableCanAllocate" or "AscendancyFrameNormalCanAllocate",
				unalloc= node.isNotable and "AscendancyFrameNotableUnallocated" or "AscendancyFrameNormalUnallocated"
			}
		else
			nodeData["nodeOverlay"] = {
				alloc= "JewelSocketAltActive",
				path=  "JewelSocketAltCanAllocate",
				unalloc= "JewelSocketAltNormal"
			}
		end
		local ascendancyName = ascendancySeachNameById[node.ascendancyId]
		ascendancyGroups = ascendancyGroups or {}
		ascendancyGroups[ascendancyName] = ascendancyGroups[ascendancyName] or { }
		ascendancyGroups[ascendancyName].startId = node.isAscendancyStart and nodeId or ascendancyGroups[ascendancyName].startId
		ascendancyGroups[ascendancyName][node.group] = true
	else
		-- recalculate max and min
		local group = tree.groups[node.group]
		tree.min_x = math.min(tree.min_x, group.x)
		tree.min_y = math.min(tree.min_y, group.y)
		tree.max_x = math.max(tree.max_x, group.x)
		tree.max_y = math.max(tree.max_y, group.y)
	end

	-- build flavor text
	if node.flavourText and #node.flavourText > 0 then
		nodeData.flavourText = table.concat(node.flavourText, '\\n')
	end
	-- buidl node stats
	if node.stats and #node.stats > 0 then
		nodeData.stats={}
		for _, stat in ipairs(node.stats) do
			table.insert(nodeData.stats, sanitiseText(escapeGGGString(stat)))
		end
	end

	-- build attribute nodes
	if node.isGenericAttribute == true then
		nodeData["isAttribute"] = true
		nodeData["options"] = {}
		for i, overrideId in ipairs(attributesNodesId) do
			local overrideNode =  data.skillOverrides[tostring(overrideId)]
			if overrideNode == nil then
				printf("Override node ".. overrideId .. " not found")
				return
			end
			local optionData = {
				["id"] = overrideId,
				["name"] = overrideNode.name,
				["icon"] = overrideNode.icon,
				["stats"] = {}
			}
			for _, statDesc in ipairs(overrideNode.stats) do
				table.insert(optionData.stats, escapeGGGString(statDesc))
			end

			table.insert(nodeData["options"], optionData)
		end
	end

	-- build classes start
	if node.classStartIndex  and #node.classStartIndex > 0 then
		nodeData.classesStart = {}
		for _, classStartIndex in ipairs(node.classStartIndex) do
			local className = data.classes[classStartIndex + 1].name
			table.insert(nodeData.classesStart, className)
			table.insert(classessNodeIds, nodeId)
		end
	end

	-- build connections
	local lengthIn, lengthOut, lengthEdge = #node["in"], #node["out"], #node.edges
	local nodeInCount = lengthEdge - (lengthIn + lengthOut) + lengthIn
	for index, nodeIdOut in ipairs(node.out) do
		local edgeIndex = node.edges[nodeInCount + index] + 1
		local orbitDataSearch = data.edges[edgeIndex]
		if orbitDataSearch == nil then
			printf("Edge index " ..  index .. " for " .. nodeIdOut .. " from " .. nodeId .. " not found")
			goto nextOrbit
		end

		local fromId = tonumber(orbitDataSearch.from == "root" and 0 or orbitDataSearch.from)
		if fromId ~= nodeId or orbitDataSearch.to ~= tonumber(nodeIdOut) then
			printf("Incorrect edge for " .. nodeId .. " " .. nodeIdOut )
			printf(fromId.. " => " .. orbitDataSearch.to .. " = " .. edgeIndex .. " " .. index .. " " .. nodeInCount)
			return
		end

		-- TODO: minimal check
		local nodeOrbit = 0
		if orbitDataSearch.orbit ~= nil and orbitDataSearch.orbit ~= 0  then
			nodeOrbit = (orbitDataSearch.orbit + 1) * arcDirection(node, data.nodes[nodeIdOut], orbitDataSearch)
		end

		local connectionData = {
			id = tonumber(nodeIdOut),
			orbit = nodeOrbit
		}
		table.insert(nodeData.connections, connectionData)
		:: nextOrbit ::
	end

	-- build unlock constraint
	if node.unlockConstraint ~= nil then
		nodeData["connectionArt"] = "CharacterPlanned"
		nodeData["unlockConstraint"] = {
			["ascendancy"] = ascendancySeachNameById[node.unlockConstraint.ascendancy],
			["nodes"] = node.unlockConstraint.nodes,
		}
		nodeData["nodeOverlay"] = {
			["alloc"] = "OracleFrameAllocated",
			["path"] = "OracleFrameCanAllocate",
			["unalloc"] = "OracleFrameUnallocated",
		}
	end

	orbitsConstants[node.orbit + 1] = math.max(orbitsConstants[node.orbit + 1] or 1, node.orbitIndex)
	tree.nodes[nodeId] =  nodeData
	:: nextNode ::
end

-- Build isSwitchavle / overridePairs
for _, classData in ipairs(data.classes) do
	if classData.overridePairs then
		for nodeId, replaceNodeId in pairs(classData.overridePairs) do
			local sourceNode = tree.nodes[tonumber(nodeId)]
			if sourceNode == nil then
				printf("Not Node for override found for " .. nodeId)
				goto nextReplacement
			end
			local replaceNode = data.skillOverrides[tostring(replaceNodeId)]
			if replaceNode == nil then
				printf("Not skillOverrides for override found for " .. replaceNodeId)
				goto nextReplacement
			end

			if #replaceNode > 0 then
				replaceNode = replaceNode[1]
			end

			sourceNode["isSwitchable"] = true
			sourceNode.options = sourceNode.options or {}

			local replaceNodeData = {
				["icon"] = replaceNode.icon,
				["id"] = replaceNodeId,
				["name"] =  escapeGGGString(replaceNode.name),
				["stats"] = {}
			}

			for _, statDesc in ipairs(replaceNode.stats) do
				table.insert(replaceNodeData.stats, sanitiseText(escapeGGGString(statDesc)))
			end

			sourceNode.options[classData.name] = replaceNodeData
		end
	end
	:: nextReplacement ::
end

-- updating skillsPerOrbit
for i, orbit in ipairs(orbitsConstants) do
	-- only numbers base on 12
	orbit = i == 1 and orbit or math.ceil(orbit / 12) * 12
	tree.constants.skillsPerOrbit[i] = orbit
end

-- calculate the orbit radius
for orbit, skillsInOrbit in ipairs(tree.constants.skillsPerOrbit) do
	tree.constants.orbitAnglesByOrbit[orbit] = CalcOrbitAngles(skillsInOrbit)
end

-- Update position of ascendancy base on min / max 
-- get the orbit radius + hard-coded value, calculate the angle of the class start
-- translate the ascendancy to the new position in arc position
local widthTree, heightTree = tree.max_x - tree.min_x, tree.max_y - tree.min_y
local radiusTree = (math.max(widthTree, heightTree) + 700) / 2
local arcAngle = { [0] = 0, [1] = 0, [2] = 12, [3] = 24, [4] = 36, [5] = 48, [6] = 60, [7] = 72, [8] = 84, [9] = 96 }
for i, classId in ipairs(classessNodeIds) do
	local nodeStart = tree.nodes[classId]
	local group = tree.groups[nodeStart.group]
	local angleToCenter = math.atan2(group.y, group.x)
	local hardCoded = radiusTree + 2800

	-- calculate how many ascendancies in that place?
	local total = 0
	local classes = {}

	for _, class in ipairs(tree.classes) do
		for _, nodeClasses in ipairs(nodeStart.classesStart) do
			if nodeClasses == class.name then
				total = total + #class.ascendancies
				table.insert(classes, class)
			end
		end
	end

	local startAngle = angleToCenter - math.rad(arcAngle[total] / 2)
	local angleStep = math.rad(arcAngle[total] / (total - 1)) or 0
	local j = 1
	for _, class in ipairs(classes) do
		for _, ascendancy in ipairs(class.ascendancies) do
			--printf("Positioning ascendancy " .. ascendancy.name .. " for class " .. class.name)
			
			local angle = startAngle + (j - 1) * angleStep
			local cX = hardCoded * math.cos(angle)
			local cY = hardCoded * math.sin(angle)

			local info = ascendancyGroups[ascendancy.id]
			if info == nil then
				printf("Ascendancy group " .. ascendancy.id .. " not found")
				goto continuepositioning
			end
			local ascendancyNode = tree.nodes[info.startId]
			if ascendancyNode == nil then
				printf("Ascendancy node " .. ascendancy.id .. " not found")
				goto continuepositioning
			end

			ascendancy.background.x = cX
			ascendancy.background.y = cY

			local groupAscendancy = tree.groups[ascendancyNode.group]

			local innerRadious = dat("ascendancy"):GetRow("Id", ascendancy.internalId).distanceTree

			local newInnerX = cX + math.cos(angleToCenter) * innerRadious
			local newInnerY = cY + math.sin(angleToCenter) * innerRadious

			local nodeAngle = tree.constants.orbitAnglesByOrbit[ascendancyNode.orbit + 1][ascendancyNode.orbitIndex + 1]
			local orbitRadius = tree.constants.orbitRadii[ascendancyNode.orbit + 1]
			local newX = newInnerX - math.sin(nodeAngle) * orbitRadius
			local newY = newInnerY + math.cos(nodeAngle) * orbitRadius

			local offsetX = newX - groupAscendancy.x
			local offsetY = newY - groupAscendancy.y

			-- now update the whole groups with the offset
			for groupId, value in pairs(info) do
				if type(value) == "boolean" then
					local group = tree.groups[groupId]
					group.x = group.x + offsetX
					group.y = group.y + offsetY

					-- recalculate min / max
					tree.min_x = math.min(tree.min_x, group.x - hardCoded / 2)
					tree.min_y = math.min(tree.min_y, group.y - hardCoded / 2)
					tree.max_x = math.max(tree.max_x, group.x + hardCoded / 2)
					tree.max_y = math.max(tree.max_y, group.y + hardCoded / 2)
				end
			end

			j = j + 1
			:: continuepositioning ::
		end
	end
end

-- build spriteCoords
tree.spriteCoords = {}

-- Build frame coords info
for _, strFile in ipairs(fileAssets) do
	local fileName = assetsFolder .. "\\" .. strFile
	local file, err = io.open(fileName, "r")
	if file == nil then
		printf("Error opening file " .. fileName)
		printf(err)
		return
	end

	local content = file:read("*a")
	file:close()
	local dataFrame, pos, err = json.decode(content, 1, nil)
	if err then
		printf("Error decoding JSON: " .. err)
		return
	end

	-- this file contains frame & meta
	local fileNameMeta =  dataFrame.meta.image
	-- copy the file to tree data destination
	-- this assume you are on windows
	os.execute(string.format('copy "%s\\%s" "%s"', assetsFolder, fileNameMeta, path))

	tree.spriteCoords[fileNameMeta] = {}
	for name, frameData in pairs(dataFrame.frames) do
		local a, b = name:match("([^:]+):([^:]+)")
		if a == "startNode" and b == "MainCircle" then
			b = "BGTree"
		elseif a == "startNode" and b == "MainCircleActive" then
			b = "BGTreeActive"
		elseif a == "frame" and b == "AscendancyStartNode" then
			b = "AscendancyMiddle"
		elseif a:sub(1,5) == "class" then
			-- Enable class and ascendancies background
			b = a .. ":" .. b
		end
		local frame = frameData.frame
		local internalName = b or a
		tree.spriteCoords[fileNameMeta][internalName] = {
			x = frame.x,
			y = frame.y,
			w = frame.w,
			h = frame.h
		}
	end
end
-- buidl orbits info
tree.assets={
	CharacterAscendancyLineConnectorActive={
		[1]="CharacterAscendancy_orbit_intermediateactive0.png"
	},
	CharacterAscendancyLineConnectorIntermediate={
		[1]="CharacterAscendancy_orbit_intermediate0.png"
	},
	CharacterAscendancyLineConnectorNormal={
		[1]="CharacterAscendancy_orbit_normal0.png"
	},
	CharacterAscendancyOrbit1Active={
		[1]="CharacterAscendancy_orbit_intermediateactive9.png"
	},
	CharacterAscendancyOrbit1Intermediate={
		[1]="CharacterAscendancy_orbit_intermediate9.png"
	},
	CharacterAscendancyOrbit1Normal={
		[1]="CharacterAscendancy_orbit_normal9.png"
	},
	CharacterAscendancyOrbit2Active={
		[1]="CharacterAscendancy_orbit_intermediateactive8.png"
	},
	CharacterAscendancyOrbit2Intermediate={
		[1]="CharacterAscendancy_orbit_intermediate8.png"
	},
	CharacterAscendancyOrbit2Normal={
		[1]="CharacterAscendancy_orbit_normal8.png"
	},
	CharacterAscendancyOrbit3Active={
		[1]="CharacterAscendancy_orbit_intermediateactive6.png"
	},
	CharacterAscendancyOrbit3Intermediate={
		[1]="CharacterAscendancy_orbit_intermediate6.png"
	},
	CharacterAscendancyOrbit3Normal={
		[1]="CharacterAscendancy_orbit_normal6.png"
	},
	CharacterAscendancyOrbit4Active={
		[1]="CharacterAscendancy_orbit_intermediateactive5.png"
	},
	CharacterAscendancyOrbit4Intermediate={
		[1]="CharacterAscendancy_orbit_intermediate5.png"
	},
	CharacterAscendancyOrbit4Normal={
		[1]="CharacterAscendancy_orbit_normal5.png"
	},
	CharacterAscendancyOrbit5Active={
		[1]="CharacterAscendancy_orbit_intermediateactive4.png"
	},
	CharacterAscendancyOrbit5Intermediate={
		[1]="CharacterAscendancy_orbit_intermediate4.png"
	},
	CharacterAscendancyOrbit5Normal={
		[1]="CharacterAscendancy_orbit_normal4.png"
	},
	CharacterAscendancyOrbit6Active={
		[1]="CharacterAscendancy_orbit_intermediateactive3.png"
	},
	CharacterAscendancyOrbit6Intermediate={
		[1]="CharacterAscendancy_orbit_intermediate3.png"
	},
	CharacterAscendancyOrbit6Normal={
		[1]="CharacterAscendancy_orbit_normal3.png"
	},
	CharacterAscendancyOrbit7Active={
		[1]="CharacterAscendancy_orbit_intermediateactive7.png"
	},
	CharacterAscendancyOrbit7Intermediate={
		[1]="CharacterAscendancy_orbit_intermediate7.png"
	},
	CharacterAscendancyOrbit7Normal={
		[1]="CharacterAscendancy_orbit_normal7.png"
	},
	CharacterAscendancyOrbit8Active={
		[1]="CharacterAscendancy_orbit_intermediateactive2.png"
	},
	CharacterAscendancyOrbit8Intermediate={
		[1]="CharacterAscendancy_orbit_intermediate2.png"
	},
	CharacterAscendancyOrbit8Normal={
		[1]="CharacterAscendancy_orbit_normal2.png"
	},
	CharacterAscendancyOrbit9Active={
		[1]="CharacterAscendancy_orbit_intermediateactive1.png"
	},
	CharacterAscendancyOrbit9Intermediate={
		[1]="CharacterAscendancy_orbit_intermediate1.png"
	},
	CharacterAscendancyOrbit9Normal={
		[1]="CharacterAscendancy_orbit_normal1.png"
	},
	CharacterLineConnectorActive={
		[1]="Character_orbit_intermediateactive0.png"
	},
	CharacterLineConnectorIntermediate={
		[1]="Character_orbit_intermediate0.png"
	},
	CharacterLineConnectorNormal={
		[1]="Character_orbit_normal0.png"
	},
	CharacterOrbit1Active={
		[1]="Character_orbit_intermediateactive9.png"
	},
	CharacterOrbit1Intermediate={
		[1]="Character_orbit_intermediate9.png"
	},
	CharacterOrbit1Normal={
		[1]="Character_orbit_normal9.png"
	},
	CharacterOrbit2Active={
		[1]="Character_orbit_intermediateactive8.png"
	},
	CharacterOrbit2Intermediate={
		[1]="Character_orbit_intermediate8.png"
	},
	CharacterOrbit2Normal={
		[1]="Character_orbit_normal8.png"
	},
	CharacterOrbit3Active={
		[1]="Character_orbit_intermediateactive6.png"
	},
	CharacterOrbit3Intermediate={
		[1]="Character_orbit_intermediate6.png"
	},
	CharacterOrbit3Normal={
		[1]="Character_orbit_normal6.png"
	},
	CharacterOrbit4Active={
		[1]="Character_orbit_intermediateactive5.png"
	},
	CharacterOrbit4Intermediate={
		[1]="Character_orbit_intermediate5.png"
	},
	CharacterOrbit4Normal={
		[1]="Character_orbit_normal5.png"
	},
	CharacterOrbit5Active={
		[1]="Character_orbit_intermediateactive4.png"
	},
	CharacterOrbit5Intermediate={
		[1]="Character_orbit_intermediate4.png"
	},
	CharacterOrbit5Normal={
		[1]="Character_orbit_normal4.png"
	},
	CharacterOrbit6Active={
		[1]="Character_orbit_intermediateactive3.png"
	},
	CharacterOrbit6Intermediate={
		[1]="Character_orbit_intermediate3.png"
	},
	CharacterOrbit6Normal={
		[1]="Character_orbit_normal3.png"
	},
	CharacterOrbit7Active={
		[1]="Character_orbit_intermediateactive7.png"
	},
	CharacterOrbit7Intermediate={
		[1]="Character_orbit_intermediate7.png"
	},
	CharacterOrbit7Normal={
		[1]="Character_orbit_normal7.png"
	},
	CharacterOrbit8Active={
		[1]="Character_orbit_intermediateactive2.png"
	},
	CharacterOrbit8Intermediate={
		[1]="Character_orbit_intermediate2.png"
	},
	CharacterOrbit8Normal={
		[1]="Character_orbit_normal2.png"
	},
	CharacterOrbit9Active={
		[1]="Character_orbit_intermediateactive1.png"
	},
	CharacterOrbit9Intermediate={
		[1]="Character_orbit_intermediate1.png"
	},
	CharacterOrbit9Normal={
		[1]="Character_orbit_normal1.png"
	},
	CharacterPlannedLineConnectorActive={
		[1]="CharacterPlanned_orbit_intermediateactive0.png"
	},
	CharacterPlannedLineConnectorIntermediate={
		[1]="CharacterPlanned_orbit_intermediate0.png"
	},
	CharacterPlannedLineConnectorNormal={
		[1]="CharacterPlanned_orbit_normal0.png"
	},
	CharacterPlannedOrbit1Active={
		[1]="CharacterPlanned_orbit_intermediateactive9.png"
	},
	CharacterPlannedOrbit1Intermediate={
		[1]="CharacterPlanned_orbit_intermediate9.png"
	},
	CharacterPlannedOrbit1Normal={
		[1]="CharacterPlanned_orbit_normal9.png"
	},
	CharacterPlannedOrbit2Active={
		[1]="CharacterPlanned_orbit_intermediateactive8.png"
	},
	CharacterPlannedOrbit2Intermediate={
		[1]="CharacterPlanned_orbit_intermediate8.png"
	},
	CharacterPlannedOrbit2Normal={
		[1]="CharacterPlanned_orbit_normal8.png"
	},
	CharacterPlannedOrbit3Active={
		[1]="CharacterPlanned_orbit_intermediateactive6.png"
	},
	CharacterPlannedOrbit3Intermediate={
		[1]="CharacterPlanned_orbit_intermediate6.png"
	},
	CharacterPlannedOrbit3Normal={
		[1]="CharacterPlanned_orbit_normal6.png"
	},
	CharacterPlannedOrbit4Active={
		[1]="CharacterPlanned_orbit_intermediateactive5.png"
	},
	CharacterPlannedOrbit4Intermediate={
		[1]="CharacterPlanned_orbit_intermediate5.png"
	},
	CharacterPlannedOrbit4Normal={
		[1]="CharacterPlanned_orbit_normal5.png"
	},
	CharacterPlannedOrbit5Active={
		[1]="CharacterPlanned_orbit_intermediateactive4.png"
	},
	CharacterPlannedOrbit5Intermediate={
		[1]="CharacterPlanned_orbit_intermediate4.png"
	},
	CharacterPlannedOrbit5Normal={
		[1]="CharacterPlanned_orbit_normal4.png"
	},
	CharacterPlannedOrbit6Active={
		[1]="CharacterPlanned_orbit_intermediateactive3.png"
	},
	CharacterPlannedOrbit6Intermediate={
		[1]="CharacterPlanned_orbit_intermediate3.png"
	},
	CharacterPlannedOrbit6Normal={
		[1]="CharacterPlanned_orbit_normal3.png"
	},
	CharacterPlannedOrbit7Active={
		[1]="CharacterPlanned_orbit_intermediateactive7.png"
	},
	CharacterPlannedOrbit7Intermediate={
		[1]="CharacterPlanned_orbit_intermediate7.png"
	},
	CharacterPlannedOrbit7Normal={
		[1]="CharacterPlanned_orbit_normal7.png"
	},
	CharacterPlannedOrbit8Active={
		[1]="CharacterPlanned_orbit_intermediateactive2.png"
	},
	CharacterPlannedOrbit8Intermediate={
		[1]="CharacterPlanned_orbit_intermediate2.png"
	},
	CharacterPlannedOrbit8Normal={
		[1]="CharacterPlanned_orbit_normal2.png"
	},
	CharacterPlannedOrbit9Active={
		[1]="CharacterPlanned_orbit_intermediateactive1.png"
	},
	CharacterPlannedOrbit9Intermediate={
		[1]="CharacterPlanned_orbit_intermediate1.png"
	},
	CharacterPlannedOrbit9Normal={
		[1]="CharacterPlanned_orbit_normal1.png"
	}
}

printf("Generating lua tree file")
local out, err = io.open(fileTree, "w")
if out == nil then
	printf("Error opening file " .. fileTree)
	printf(err)
	return
end
out:write('return ')
writeLuaTable(out, tree, 1)
out:close()

print("Done")