-- Newline-delimited JSON-RPC transport.
-- Request:  {"id": 1, "method": "ns.name", "params": {...}}
-- Response: {"id": 1, "result": ...} | {"id": 1, "error": {"message": "...", "traceback": "..."}}
local json = require("dkjson")
local util = require("pobapi.util")

local M = {}
local out

-- Reserve the real stdout for protocol frames; route everything else to stderr.
function M.captureStdout()
	out = io.stdout
	io.output(io.stderr)
	print = function(...)
		local parts = { }
		for i = 1, select("#", ...) do
			parts[i] = tostring((select(i, ...)))
		end
		io.stderr:write(table.concat(parts, "\t"), "\n")
	end
end

function M.send(msg)
	out:write(json.encode(util.sanitize(msg)), "\n")
	out:flush()
end

local function dispatch(handlers, req)
	local handler = handlers[req.method]
	if not handler then
		return nil, { message = "Unknown method: " .. tostring(req.method), code = "method_not_found" }
	end
	local tb
	local ok, result = xpcall(function() return handler(req.params or { }) end, function(e)
		tb = debug.traceback(e, 2)
		return e
	end)
	if ok then
		return result == nil and json.null or result
	end
	if type(result) == "table" and result.apiError then
		return nil, { message = result.message, code = result.code }
	end
	return nil, { message = tostring(result), code = "internal", traceback = tb }
end

function M.serve(handlers)
	M.send({ event = "ready", methods = util.sortedKeys(handlers) })
	for line in io.stdin:lines() do
		if line:match("%S") then
			local req, _, decodeErr = json.decode(line, 1, nil)
			if not req or type(req) ~= "table" then
				M.send({ id = json.null, error = { message = "Invalid JSON: " .. tostring(decodeErr), code = "parse_error" } })
			elseif req.method == "worker.shutdown" then
				M.send({ id = req.id, result = true })
				return
			else
				local result, err = dispatch(handlers, req)
				if err then
					M.send({ id = req.id, error = err })
				else
					M.send({ id = req.id, result = result })
				end
			end
		end
	end
end

return M
