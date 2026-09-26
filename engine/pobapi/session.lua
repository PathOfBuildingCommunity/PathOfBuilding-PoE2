-- Access to the live build object and recalculation helpers.
local M = {}

function M.build()
	return __mainObject__.main.modes["BUILD"]
end

-- Run one frame so PoB processes pending flags (buildFlag, mode changes, recalculation).
function M.frame()
	runCallback("OnFrame")
	build = M.build()
	return build
end

-- Mark the build dirty and recalculate.
function M.recalc()
	local b = M.build()
	b.buildFlag = true
	return M.frame()
end

function M.setMode(name, xml)
	if GlobalCache and GlobalCache.cachedData then
		wipeGlobalCache()
	end
	__mainObject__.main:SetMode("BUILD", false, name or "", xml)
	return M.frame()
end

function M.player()
	return M.build().calcsTab.mainEnv.player
end

function M.output()
	return M.build().calcsTab.mainOutput
end

return M
