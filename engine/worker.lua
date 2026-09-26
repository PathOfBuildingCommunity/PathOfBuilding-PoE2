-- PoB2-Enhanced headless engine worker.
-- Speaks newline-delimited JSON-RPC over stdin/stdout. All PoB console output goes to stderr.
-- Must be started with the working directory set to src/:  luajit ../engine/worker.lua
local engineDir = (arg and arg[0] or ""):match("^(.*)[/\\]worker%.lua$") or "../engine"
package.path = engineDir .. "/?.lua;../runtime/lua/?.lua;../runtime/lua/?/init.lua;" .. package.path

local rpc = require("pobapi.rpc")
rpc.captureStdout()

local ok, err = xpcall(function() require("pobapi.boot").start() end, debug.traceback)
if not ok then
	rpc.send({ event = "fatal", error = { message = tostring(err) } })
	os.exit(1)
end

rpc.serve(require("pobapi.registry"))
