-- Shared helpers for the API layer.
local json = require("dkjson")

local M = {}

-- Raise an error that is reported to the client as a clean message (no traceback).
function M.fail(message, code)
	error({ apiError = true, message = message, code = code or "bad_request" }, 0)
end

function M.require(params, key, kind)
	local v = params[key]
	if v == nil then
		M.fail("Missing parameter: " .. key)
	end
	if kind and type(v) ~= kind then
		M.fail(("Parameter '%s' must be a %s"):format(key, kind))
	end
	return v
end

-- Remove SimpleGraphic colour escapes (^7, ^xRRGGBB).
function M.strip(text)
	if type(text) ~= "string" then
		return text
	end
	return (text:gsub("%^x%x%x%x%x%x%x", ""):gsub("%^%d", ""))
end

function M.sortedKeys(t)
	local keys = { }
	for k in pairs(t) do
		keys[#keys + 1] = k
	end
	table.sort(keys)
	return keys
end

-- Make a value JSON-safe: drop functions/userdata, replace NaN/inf, break cycles.
function M.sanitize(v, seen)
	local t = type(v)
	if t == "number" then
		if v ~= v then return json.null end
		if v == math.huge then return 1e308 end
		if v == -math.huge then return -1e308 end
		return v
	elseif t == "string" or t == "boolean" or v == json.null then
		return v
	elseif t == "table" then
		seen = seen or { }
		if seen[v] then return json.null end
		seen[v] = true
		local res = { }
		for k, val in pairs(v) do
			local kt = type(k)
			if kt == "string" or kt == "number" then
				local sv = M.sanitize(val, seen)
				if sv ~= nil then
					res[k] = sv
				end
			end
		end
		seen[v] = nil
		local mt = getmetatable(v)
		if type(mt) == "table" and mt.__jsontype then
			setmetatable(res, { __jsontype = mt.__jsontype })
		end
		return res
	end
	return nil
end

-- Mark a table so dkjson always encodes it as an array (even when empty).
function M.array(t)
	return setmetatable(t or { }, { __jsontype = "array" })
end

function M.contains(haystack, needle)
	return type(haystack) == "string" and haystack:lower():find(needle:lower(), 1, true) ~= nil
end

return M
