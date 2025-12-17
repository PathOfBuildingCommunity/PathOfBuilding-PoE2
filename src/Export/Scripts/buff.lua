if not loadStatFile then
	dofile("statdesc.lua")
end
loadStatFile("stat_descriptions.csd")

local directiveTable = { }

-- #Buff <BuffDefinitionId>
directiveTable.buff = function(state, args, out)
	state.currentBuffId = args
	local bufDefinitionID = dat("buffdefinitions"):GetRow("Id", state.currentBuffId)
	if not bufDefinitionID then
		error("BuffDefinitionId '" .. state.currentBuffId .. "' not found in database")
	end
	state.currentBuffDefinitionId = bufDefinitionID
	out:write('buffs["', state.currentBuffId, '"] = {\n')

	-- print name
	if bufDefinitionID.Name then
		out:write('\tname = "', bufDefinitionID.Name:gsub('"', '\\"'), '",\n')
	end
end

directiveTable.buffEnd = function(state, args, out)
	state.currentBuffId = nil
	state.currentBuffDefinitionId = nil
	out:write('}')
end

-- #condition <condition>
-- build "Condition:<condition>" and "Condition:CanHave<condition>"
directiveTable.condition = function(state, args, out)
	out:write('\tcheck="Condition:CanHave' .. args .. '",\n')
	out:write('\tcondition="' .. args .. '",\n')
end

-- #stats
directiveTable.stats = function(state, args, out)
	if not state.currentBuffDefinitionId.Stats then
		error("BuffDefinitionId '" .. state.currentBuffId .. "' has no associated stats")
	end

	print("Writing stats for buff " .. state.currentBuffId)
	local stats = state.currentBuffDefinitionId.Stats
	local flags = state.currentBuffDefinitionId.GrantedFlags
	local grantStats = state.currentBuffDefinitionId.GrantedStats

	out:write('\tstats={\n')
	for k, stat in ipairs(stats) do
		print("    Writing stat " .. stat.Id)
		out:write('\t\t"' .. stat.Id .. '",\n')
	end
	out:write('\t},\n')

	out:write('\tflags={\n')
	for k, stat in ipairs(flags) do
		print("    Writing flag " .. stat.Id)
		out:write('\t\t"' .. stat.Id .. '",\n')
	end
	out:write('\t},\n')

	out:write('\tgrants={\n')
	for k, stat in ipairs(grantStats) do
		print("    Writing granted stat " .. stat.Id)
		out:write('\t\t"' .. stat.Id .. '",\n')
	end
	out:write('\t},\n')

	-- now search for bufftemplates that reference this buffdefinition
	print("Searching for buff templates for buff " .. state.currentBuffId)
	local buffTemplates = dat("bufftemplates"):GetRow("BuffDefinition", state.currentBuffDefinitionId)
	if buffTemplates then
		out:write('\tvalues={\n')
		for k, stat in ipairs(buffTemplates.Stats) do
			print("    Writing template stat " .. stat.Id)
			out:write('\t\t{"' .. stat.Id .. '",' .. buffTemplates.StatValues[k] .. '}')
			out:write(',\n')
		end
		out:write('\t},\n')
		-- enable duration
		out:write('\tduration = ', buffTemplates.Duration, ',\n')
	end
end

for _, name in pairs({"general"}) do
	processTemplateFile(name, "Buffs/", "../Data/Buffs/", directiveTable)
end

print("Buff data exported.")