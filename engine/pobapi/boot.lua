-- Boots Path of Building headless. Mirrors src/HeadlessWrapper.lua without blocking on stdin.
local M = {}

function M.start()
	dofile("_SimpleGraphic.def.lua")

	function GetVirtualScreenSize()
		return 1920, 1080
	end

	__callbackTable__ = { }
	function runCallback(name, ...)
		if __callbackTable__[name] then
			return __callbackTable__[name](...)
		elseif __mainObject__ and __mainObject__[name] then
			return __mainObject__[name](__mainObject__, ...)
		end
	end

	local l_require = require
	function require(name)
		-- lcurl is only needed for network features, which the worker does not use
		if name == "lcurl.safe" then
			return
		end
		return l_require(name)
	end

	dofile("Launch.lua")
	__mainObject__.continuousIntegrationMode = os.getenv("CI")
	runCallback("OnInit")
	runCallback("OnFrame")

	if __mainObject__.promptMsg then
		error("PoB failed to start: " .. tostring(__mainObject__.promptMsg))
	end

	build = __mainObject__.main.modes["BUILD"]
end

return M
