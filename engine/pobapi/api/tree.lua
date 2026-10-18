-- tree.*: passive tree state, search, allocation and layout for rendering.
local util = require("pobapi.util")
local session = require("pobapi.session")
local treelink = require("pobapi.treelink")

local M = { }

local function nodeInfo(node, withStats)
	local res = {
		id = node.id,
		name = node.dn,
		type = node.type,
		ascendancy = node.ascendancyName,
		allocated = node.alloc or false,
		isAttribute = node.isAttribute or nil,
	}
	if withStats then
		res.stats = util.array()
		for _, line in ipairs(node.sd or { }) do
			res.stats[#res.stats + 1] = util.strip(line)
		end
		if not node.alloc then
			res.pathLength = node.path and #node.path or nil
		end
	end
	return res
end

function M.get()
	local b = session.build()
	local spec = b.spec
	local used, ascUsed = spec:CountAllocNodes()
	local nodes = util.array()
	for _, node in pairs(spec.allocNodes) do
		nodes[#nodes + 1] = nodeInfo(node, true)
	end
	table.sort(nodes, function(a, c) return a.id < c.id end)
	return {
		treeVersion = spec.treeVersion,
		className = spec.curClassName,
		ascendClassName = spec.curAscendClassName,
		pointsUsed = used,
		ascendancyPointsUsed = ascUsed,
		nodes = nodes,
	}
end

-- Search nodes by name or stat text. Ignores small attribute nodes unless includeMinor.
function M.search(params)
	local query = util.require(params, "query", "string")
	local limit = params.limit or 25
	local spec = session.build().spec
	local res = util.array()
	for _, node in pairs(spec.nodes) do
		if node.dn and node.type ~= "ClassStart" and node.type ~= "AscendClassStart" and node.type ~= "OnlyImage"
			and (params.includeMinor or node.type ~= "Normal" or node.ascendancyName) then
			local match = util.contains(node.dn, query)
			if not match then
				for _, line in ipairs(node.sd or { }) do
					if util.contains(line, query) then
						match = true
						break
					end
				end
			end
			if match and (not node.ascendancyName or node.ascendancyName == spec.curAscendClassName or params.anyAscendancy) then
				res[#res + 1] = nodeInfo(node, true)
			end
		end
	end
	table.sort(res, function(a, c)
		if a.allocated ~= c.allocated then return not a.allocated end
		return (a.pathLength or 999) < (c.pathLength or 999)
	end)
	while #res > limit do
		table.remove(res)
	end
	return res
end

function M.node(params)
	local id = util.require(params, "id", "number")
	local node = session.build().spec.nodes[id]
	if not node then
		util.fail("Unknown node id: " .. id)
	end
	return nodeInfo(node, true)
end

local function eachNode(params)
	local spec = session.build().spec
	local list = { }
	for _, id in ipairs(util.require(params, "ids", "table")) do
		local node = spec.nodes[tonumber(id)]
		if not node then
			util.fail("Unknown node id: " .. tostring(id))
		end
		list[#list + 1] = node
	end
	return spec, list
end

function M.allocate(params)
	local spec, list = eachNode(params)
	local failed = util.array()
	for _, node in ipairs(list) do
		if not node.alloc then
			spec:AllocNode(node)
			if not node.alloc then
				failed[#failed + 1] = node.id
			end
		end
	end
	session.recalc()
	local res = M.get()
	res.failed = failed
	return res
end

function M.deallocate(params)
	local spec, list = eachNode(params)
	for _, node in ipairs(list) do
		if node.alloc then
			spec:DeallocNode(node)
		end
	end
	session.recalc()
	return M.get()
end

function M.reset()
	local spec = session.build().spec
	spec:ResetNodes()
	spec:BuildAllDependsAndPaths()
	session.recalc()
	return M.get()
end

-- Choose the +5 attribute on attribute nodes: changes = { { id = <node id>, attribute = "Strength"|"Dexterity"|"Intelligence" } }.
function M.set_attributes(params)
	local spec = session.build().spec
	for _, change in ipairs(util.require(params, "changes", "table")) do
		local id = tonumber(change.id)
		local treeNode = id and spec.tree.nodes[id]
		if not (treeNode and treeNode.isAttribute and treeNode.options) then
			util.fail("Not an attribute node: " .. tostring(change.id))
		end
		local index
		for i, option in ipairs(treeNode.options) do
			if (option.dn or option.name) == change.attribute then
				index = i
			end
		end
		if not index then
			util.fail("Unknown attribute: " .. tostring(change.attribute))
		end
		spec:SwitchAttributeNode(id, index)
		spec:ReplaceNode(spec.nodes[id], spec.hashOverrides[id])
	end
	session.recalc()
	return M.get()
end

function M.export_url()
	local code = treelink.encode(session.build().spec)
	return { url = treelink.PREFIX .. code, code = code }
end

function M.import_url(params)
	local url = util.require(params, "url", "string")
	local err = treelink.decode(session.build().spec, url)
	if err then
		util.fail("Invalid tree URL: " .. tostring(err))
	end
	session.recalc()
	return M.get()
end

local function round(v)
	return math.floor(v * 10 + 0.5) / 10
end

local function width(size)
	return size and size.width or nil
end

-- Orbit of the connection between two nodes, oriented from a to b.
local function connectionOrbit(tree, a, b)
	for _, c in ipairs(tree.nodes[a.id] and tree.nodes[a.id].connections or { }) do
		if c.id == b.id then
			return c.orbit or 0
		end
	end
	for _, c in ipairs(tree.nodes[b.id] and tree.nodes[b.id].connections or { }) do
		if c.id == a.id then
			return -(c.orbit or 0)
		end
	end
	return 0
end

-- Circle (cx, cy, r) a connection follows, mirroring PassiveTree:BuildConnector. nil for straight lines.
local function connectionArc(tree, n1, n2, orbit)
	local s = tree.scaleImage
	if orbit ~= 0 and tree.orbitRadii[math.abs(orbit) + 1] then
		local r = tree.orbitRadii[math.abs(orbit) + 1] * s
		local dx, dy = n2.x - n1.x, n2.y - n1.y
		local dist = math.sqrt(dx * dx + dy * dy)
		if dist > 0 and dist < r * 2 then
			local perp = math.sqrt(r * r - dist * dist / 4) * (orbit > 0 and 1 or -1)
			return n1.x + dx / 2 + perp * (dy / dist), n1.y + dy / 2 - perp * (dx / dist), r
		end
	elseif n1.group and n1.group == n2.group and n1.o and n1.o > 0 and n1.o == n2.o then
		return n1.group.x * s, n1.group.y * s, tree.orbitRadii[n1.o + 1] * s
	end
end

-- Geometry and artwork for rendering the tree. Asset names resolve through /tree-art/<version>/manifest.json.
function M.layout()
	local spec = session.build().spec
	local tree = spec.tree
	local s = tree.scaleImage
	local nodes = util.array()
	local edges = util.array()
	local decorations = util.array()
	for id, node in pairs(spec.nodes) do
		-- Base tree node: spec.nodes may hold a per-build attribute override.
		local treeNode = tree.nodes[id] or node
		if node.x and node.group and node.type == "OnlyImage" then
			if node.activeEffectImage then
				decorations[#decorations + 1] = { x = round(node.x), y = round(node.y), image = node.activeEffectImage, r = width(node.targetSize) }
			end
		elseif node.x and node.group then
			local size = node.targetSize or { }
			local entry = {
				id = id,
				x = round(node.x),
				y = round(node.y),
				type = node.type,
				name = treeNode.dn or node.dn,
				ascendancy = node.ascendancyName,
				alloc = node.alloc or nil,
				icon = treeNode.icon,
				r = size.width,
				fr = width(size.overlay),
				effect = treeNode.activeEffectImage,
				er = width(size.effect),
			}
			if node.type == "AscendClassStart" then
				entry.frame = { "AscendancyMiddle", "AscendancyMiddle", "AscendancyMiddle" }
			elseif node.overlay then
				entry.frame = { node.overlay.unalloc, node.overlay.path, node.overlay.alloc }
			end
			if treeNode.isAttribute and treeNode.options then
				entry.options = util.array()
				for _, option in ipairs(treeNode.options) do
					entry.options[#entry.options + 1] = { name = option.name, icon = option.icon }
				end
			end
			nodes[#nodes + 1] = entry
			for _, other in ipairs(node.linked or { }) do
				if other.id > id and other.x and other.group and other.type ~= "OnlyImage" and (node.ascendancyName == other.ascendancyName) then
					local cx, cy, r = connectionArc(tree, node, other, connectionOrbit(tree, node, other))
					edges[#edges + 1] = cx and { id, other.id, round(cx), round(cy), round(r) } or { id, other.id }
				end
			end
		end
	end
	local classes = util.array()
	for classId, class in pairs(tree.classes) do
		local bg = class.background
		if bg then
			local ascendancyImages = { }
			for ascendClassId, ascendClass in pairs(class.classes or { }) do
				if ascendClassId ~= 0 and ascendClass.background then
					ascendancyImages[ascendClass.id or ascendClass.name] = ascendClass.background.image
				end
			end
			classes[#classes + 1] = {
				id = classId,
				name = class.name,
				startNode = class.startNodeId,
				image = bg.image,
				ascendancyImages = ascendancyImages,
				x = round(bg.x * s),
				y = round(bg.y * s),
				w = bg.width,
				h = bg.height,
				treeW = width(bg.bg),
				activeW = width(bg.active),
			}
		end
	end
	local ascendancies = util.array()
	for name, data in pairs(tree.ascendNameMap) do
		local bg = data.ascendClass.background
		if bg then
			ascendancies[#ascendancies + 1] = {
				name = name,
				className = data.class.name,
				image = bg.image,
				x = round(bg.x * s),
				y = round(bg.y * s),
				w = bg.width,
				h = bg.height,
				replace = data.ascendClass.replace,
				replaceBy = data.ascendClass.replaceBy,
			}
		end
	end
	return {
		treeVersion = spec.treeVersion,
		nodes = nodes,
		edges = edges,
		decorations = decorations,
		classes = classes,
		ascendancies = ascendancies,
	}
end

return M
