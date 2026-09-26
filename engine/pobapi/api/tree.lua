-- tree.*: passive tree state, search, allocation and layout for rendering.
local util = require("pobapi.util")
local session = require("pobapi.session")

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

function M.export_url()
	return { url = session.build().spec:EncodeURL("https://pathofexile.com/passive-skill-tree/") }
end

function M.import_url(params)
	local url = util.require(params, "url", "string")
	local spec = session.build().spec
	local err = spec:DecodeURL(url)
	if err then
		util.fail("Invalid tree URL: " .. tostring(err))
	end
	session.recalc()
	return M.get()
end

-- Geometry for rendering the tree. Straight edges only; arcs are left to the client.
function M.layout()
	local spec = session.build().spec
	local nodes = util.array()
	local edges = util.array()
	for id, node in pairs(spec.nodes) do
		if node.x and node.type ~= "OnlyImage" and node.group then
			nodes[#nodes + 1] = {
				id = id,
				x = math.floor(node.x + 0.5),
				y = math.floor(node.y + 0.5),
				type = node.type,
				name = node.dn,
				ascendancy = node.ascendancyName,
				alloc = node.alloc or nil,
			}
			for _, other in ipairs(node.linked or { }) do
				if other.id > id and other.x and other.group and (node.ascendancyName == other.ascendancyName) then
					edges[#edges + 1] = { id, other.id }
				end
			end
		end
	end
	return { treeVersion = spec.treeVersion, nodes = nodes, edges = edges }
end

return M
