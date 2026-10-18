-- PoE2 passive tree links (pathofexile2.com/game/passive-skill-tree/<code>), format version 7.
-- Mirrors GGG's web planner: u32 version, u8 class, u8 ascendancy, u16 count, then per node
-- u16 hash, u16 flags [, u8 allocation type if flags & 1] [, u16 attribute override id if flags & 2].
-- Older (v4-v6, PoE1-era) codes are delegated to PoB's PassiveSpec:DecodeURL.
local M = { }

M.PREFIX = "https://pathofexile2.com/game/passive-skill-tree/"

local VERSION = 7
local FLAG_ALLOC_TYPE = 1
local FLAG_OVERRIDE = 2
-- GGG allocation types
local BASE, ASCENDANCY, WEAPON_SET_1 = 0, 1, 2

local function u16(n)
	return string.char(math.floor(n / 256) % 256, n % 256)
end

-- Attribute nodes (+5 Str/Dex/Int choice) store GGG's option id as the override. The ids are the same on every
-- attribute node; PoB overwrites option ids with the node id while loading the tree, so they are listed here.
local ATTRIBUTE_OPTION_IDS = { Strength = 26297, Dexterity = 14927, Intelligence = 57022 }

local function overrideId(spec, id, node)
	if spec.hashOverrides and spec.hashOverrides[id] and node.isAttribute then
		return ATTRIBUTE_OPTION_IDS[node.dn]
	end
end

-- GGG's planner replays the list in order and only counts a node toward its point pool if it touches an
-- already-loaded node of a compatible pool, so emit nodes outward from the start nodes: base tree from the
-- class start, then weapon-set nodes, then the ascendancy from its start node.
local function connectedOrder(spec, ids)
	local wanted, seen, order = { }, { }, { }
	for _, id in ipairs(ids) do
		wanted[id] = true
	end
	local function walk(roots, accept)
		local queue, head = { }, 1
		for _, node in ipairs(roots) do
			queue[#queue + 1] = node
		end
		while head <= #queue do
			local node = queue[head]
			head = head + 1
			for _, other in ipairs(node.linked or { }) do
				if wanted[other.id] and not seen[other.id] and accept(other) then
					seen[other.id] = true
					order[#order + 1] = other.id
					queue[#queue + 1] = other
				end
			end
		end
	end
	local class = spec.tree.classes[spec.curClassId]
	local roots = { class and spec.nodes[class.startNodeId] }
	walk(roots, function(node) return not node.ascendancyName and (node.allocMode or 0) == 0 end)
	for _, id in ipairs(order) do
		roots[#roots + 1] = spec.nodes[id]
	end
	walk(roots, function(node) return not node.ascendancyName end)
	for _, node in pairs(spec.allocNodes) do
		if node.type == "AscendClassStart" then
			walk({ node }, function(other) return other.ascendancyName ~= nil end)
		end
	end
	for _, id in ipairs(ids) do
		if not seen[id] then
			order[#order + 1] = id
		end
	end
	return order
end

function M.encode(spec)
	local ids = { }
	for id, node in pairs(spec.allocNodes) do
		if node.type ~= "ClassStart" and node.type ~= "AscendClassStart" and id < 65536 then
			ids[#ids + 1] = id
		end
	end
	table.sort(ids)
	ids = connectedOrder(spec, ids)
	local parts = { string.char(0, 0, 0, VERSION, spec.curClassId or 0, spec.curAscendClassId or 0), u16(#ids) }
	for _, id in ipairs(ids) do
		local node = spec.allocNodes[id]
		local allocType = BASE
		if node.ascendancyName then
			allocType = ASCENDANCY
		elseif (node.allocMode or 0) > 0 then
			allocType = WEAPON_SET_1 + node.allocMode - 1
		end
		local override = overrideId(spec, id, node)
		local flags = (allocType ~= BASE and FLAG_ALLOC_TYPE or 0) + (override and FLAG_OVERRIDE or 0)
		parts[#parts + 1] = u16(id) .. u16(flags)
		if allocType ~= BASE then
			parts[#parts + 1] = string.char(allocType)
		end
		if override then
			parts[#parts + 1] = u16(override)
		end
	end
	return (common.base64.encode(table.concat(parts)):gsub("+", "-"):gsub("/", "_"))
end

local function codeFromUrl(url)
	local code = url:gsub("[?#].*$", ""):gsub("/+$", ""):gsub("^.*/", "")
	code = code:gsub("%%(%x%x)", function(hex) return string.char(tonumber(hex, 16)) end)
	return (code:gsub("-", "+"):gsub("_", "/"))
end

-- Returns nil on success, or an error message.
function M.decode(spec, url)
	local b = common.base64.decode(codeFromUrl(url))
	if not b or #b < 8 then
		return "unrecognised format"
	end
	local version = b:byte(1) * 16777216 + b:byte(2) * 65536 + b:byte(3) * 256 + b:byte(4)
	if version < VERSION then
		return spec:DecodeURL(url)
	elseif version > VERSION then
		return "unknown version number " .. version
	end
	local classId, ascendClassId = b:byte(5), b:byte(6)
	local pos = 9
	local function read(n)
		if pos + n - 1 > #b then
			error("truncated tree link", 0)
		end
		local v = 0
		for i = pos, pos + n - 1 do
			v = v * 256 + b:byte(i)
		end
		pos = pos + n
		return v
	end
	local hashes, weaponSets, overrides = { }, { }, { }
	local ok, err = pcall(function()
		if b:byte(7) * 256 + b:byte(8) == 0 then
			return
		end
		while pos <= #b do
			local id, flags = read(2), read(2)
			local allocType = BASE
			if flags % 2 == 1 then
				allocType = read(1)
			end
			if math.floor(flags / 2) % 2 == 1 then
				overrides[id] = read(2)
			end
			hashes[#hashes + 1] = id
			if allocType >= WEAPON_SET_1 then
				weaponSets[id] = allocType - WEAPON_SET_1 + 1
			end
		end
	end)
	if not ok then
		return err
	end
	-- GGG links always describe the live game tree.
	local tree = main:LoadTree(latestTreeVersion)
	if not tree.classes[classId] then
		return "bad class id " .. classId
	end
	if ascendClassId ~= 0 and not tree.classes[classId].classes[ascendClassId] then
		return "bad ascendancy id " .. ascendClassId
	end
	spec:ImportFromNodeList(nil, classId, ascendClassId, 0, hashes, weaponSets, { }, { }, latestTreeVersion)
	for id, optionId in pairs(overrides) do
		local treeNode = spec.tree.nodes[id]
		for index, option in ipairs(treeNode and treeNode.options or { }) do
			if ATTRIBUTE_OPTION_IDS[option.dn or option.name] == optionId then
				spec:SwitchAttributeNode(id, index)
				if spec.nodes[id] then
					spec:ReplaceNode(spec.nodes[id], spec.hashOverrides[id])
				end
				break
			end
		end
	end
	spec:BuildAllDependsAndPaths()
end

return M
