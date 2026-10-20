-- Maps RPC method names ("namespace.method") to handler functions.
local registry = { }

local namespaces = { "build", "stats", "skills", "items", "tree", "config", "data", "reference", "advisor", "gear", "gems", "budget", "sockets" }
for _, ns in ipairs(namespaces) do
	local mod = require("pobapi.api." .. ns)
	for name, fn in pairs(mod) do
		if type(fn) == "function" and name:sub(1, 1) ~= "_" and name ~= "describe" and name ~= "diff" and name ~= "suggest" then
			registry[ns .. "." .. name] = fn
		end
	end
end

registry["worker.ping"] = function()
	return { pong = true, version = launch.versionNumber, time = os.time() }
end

return registry
