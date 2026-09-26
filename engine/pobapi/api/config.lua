-- config.*: the Configuration tab (enemy, buffs, conditions...).
local util = require("pobapi.util")
local session = require("pobapi.session")
local varList = require("Modules.ConfigOptions")

local M = { }

local function isShown(configTab, var)
	local control = configTab.varControls[var]
	if not control then
		return false
	end
	local shown = control.shown
	if type(shown) == "function" then
		local ok, res = pcall(shown, control)
		return ok and res and true or false
	end
	return shown ~= false
end

function M.list(params)
	local configTab = session.build().configTab
	local res = util.array()
	local section
	for _, varData in ipairs(varList) do
		if varData.section then
			section = varData.section
		elseif varData.var and varData.type ~= "text" then
			local shown = isShown(configTab, varData.var)
			if shown or params.all then
				local entry = {
					var = varData.var,
					type = varData.type,
					label = util.strip(varData.label),
					section = section,
					value = configTab.input[varData.var],
					default = configTab:GetDefaultState(varData.var),
					shown = shown,
				}
				if varData.list then
					entry.choices = util.array()
					for _, choice in ipairs(varData.list) do
						entry.choices[#entry.choices + 1] = { value = choice.val, label = util.strip(choice.label) }
					end
				end
				if not params.query or util.contains(entry.label, params.query) or util.contains(entry.var, params.query) then
					res[#res + 1] = entry
				end
			end
		end
	end
	return res
end

local byVar
local function varData(var)
	if not byVar then
		byVar = { }
		for _, v in ipairs(varList) do
			if v.var then byVar[v.var] = v end
		end
	end
	return byVar[var]
end

-- values: { [var] = value }. Use null/false to reset a checkbox.
function M.set(params)
	local values = util.require(params, "values", "table")
	local configTab = session.build().configTab
	for var, value in pairs(values) do
		local data = varData(var)
		if not data then
			util.fail("Unknown config option: " .. tostring(var))
		end
		if data.type == "check" then
			value = value == true
		elseif data.type == "count" or data.type == "integer" or data.type == "float" then
			value = tonumber(value)
		end
		configTab.input[var] = value
	end
	configTab:UpdateControls()
	configTab:BuildModList()
	session.recalc()
	local updated = { }
	for var in pairs(values) do
		updated[var] = configTab.input[var]
	end
	return { updated = updated }
end

function M.custom_mods(params)
	local configTab = session.build().configTab
	if params.text ~= nil then
		configTab.input.customMods = params.text
		configTab:UpdateControls()
		configTab:BuildModList()
		session.recalc()
	end
	return { text = configTab.input.customMods or "" }
end

return M
