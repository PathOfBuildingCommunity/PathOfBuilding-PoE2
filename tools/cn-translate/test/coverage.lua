-- Coverage probe: run the translator over a &&-separated corpus and report any
-- lines that still contain CJK (i.e. were not translated) after translation.
-- Usage: luajit test/coverage.lua <data.lua> <translator.lua> <corpus.txt>
_G.__CN_TRANSLATION_DATA = dofile(arg[1])
local M = dofile(arg[2])
local f = assert(io.open(arg[3], "rb"))
local corpus = f:read("*a"); f:close()

local function hasCJK(s) return s:find("[\227-\233][\128-\191][\128-\191]") ~= nil end

-- Split on a line that is exactly "&&".
local items, cur = {}, {}
for line in (corpus .. "\n"):gmatch("([^\n]*)\n") do
	if line:gsub("%s", "") == "&&" then
		items[#items + 1] = table.concat(cur, "\n"); cur = {}
	else
		cur[#cur + 1] = line
	end
end
if #cur > 0 then items[#items + 1] = table.concat(cur, "\n") end

local totalLines, missLines = 0, 0
local missCounts = {}
for i, raw in ipairs(items) do
	if raw:gsub("%s", "") ~= "" then
		local out = M.translate(raw)
		local itemMiss = {}
		for line in (out .. "\n"):gmatch("([^\n]*)\n") do
			if line ~= "" then
				totalLines = totalLines + 1
				if hasCJK(line) then
					missLines = missLines + 1
					itemMiss[#itemMiss + 1] = line
					missCounts[line] = (missCounts[line] or 0) + 1
				end
			end
		end
		if #itemMiss > 0 then
			io.write(string.format("\n--- item %d: %d untranslated line(s) ---\n", i, #itemMiss))
			for _, l in ipairs(itemMiss) do io.write("  " .. l .. "\n") end
		end
	end
end

io.write(string.format("\n===== %d items | %d/%d lines untranslated (%.1f%% translated) =====\n",
	#items, missLines, totalLines, 100 * (1 - missLines / math.max(1, totalLines))))
