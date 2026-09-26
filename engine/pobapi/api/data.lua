-- data.*: static game data lookups (gems, uniques, bases, classes).
local util = require("pobapi.util")
local session = require("pobapi.session")

local M = { }

local function limitList(list, limit)
	table.sort(list, function(a, b) return a.name < b.name end)
	while #list > (limit or 50) do
		table.remove(list)
	end
	return list
end

function M.gems(params)
	local query = params.query or ""
	local res = util.array()
	for id, gem in pairs(data.gems) do
		local ge = gem.grantedEffect
		local isSupport = ge and ge.support or false
		if (query == "" or util.contains(gem.name, query) or util.contains(gem.tagString, query))
			and (params.support == nil or params.support == isSupport) then
			res[#res + 1] = {
				id = id,
				name = gem.name,
				support = isSupport,
				tags = util.strip(gem.tagString),
				description = ge and ge.description and util.strip(ge.description) or nil,
			}
		end
	end
	return limitList(res, params.limit)
end

function M.uniques(params)
	local query = params.query or ""
	local res = util.array()
	for name, item in pairs(main.uniqueDB.list) do
		if (query == "" or util.contains(name, query) or util.contains(item.baseName, query))
			and (not params.type or util.contains(item.type, params.type)) then
			res[#res + 1] = { name = name, baseName = item.baseName, type = item.type }
		end
	end
	return limitList(res, params.limit)
end

function M.unique(params)
	local name = util.require(params, "name", "string")
	local item = main.uniqueDB.list[name]
	if not item then
		for n, it in pairs(main.uniqueDB.list) do
			if n:lower() == name:lower() then
				item = it
			end
		end
	end
	if not item then
		util.fail("Unique not found: " .. name, "not_found")
	end
	return { name = item.name, baseName = item.baseName, type = item.type, text = item:BuildRaw() }
end

function M.bases(params)
	local query = params.query or ""
	local res = util.array()
	for name, base in pairs(data.itemBases) do
		if (query == "" or util.contains(name, query)) and (not params.type or util.contains(base.type, params.type)) then
			res[#res + 1] = { name = name, type = base.type, subType = base.subType, level = base.req and base.req.level }
		end
	end
	return limitList(res, params.limit)
end

function M.classes()
	local tree = session.build().spec.tree
	local res = util.array()
	for id, class in pairs(tree.classes) do
		local entry = { id = id, name = class.name, ascendancies = util.array() }
		for ascId, asc in pairs(class.classes or { }) do
			if ascId ~= 0 then
				entry.ascendancies[#entry.ascendancies + 1] = asc.name
			end
		end
		table.sort(entry.ascendancies)
		res[#res + 1] = entry
	end
	table.sort(res, function(a, b) return a.id < b.id end)
	return res
end

return M
