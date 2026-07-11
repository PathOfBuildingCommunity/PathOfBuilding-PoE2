--
-- export flavour text data
--
local utils = LoadModule("../Modules/Utils")
local function normalizeId(id)
	id = tostring(id)
	-- Remove underscore and everything after it. We can't match hash sadly.
	-- Grip of Kulemak is FourUniqueRing33_a in stash layout and FourUniqueRing33 in flavour text.
	return id:match("^[^_]+")
end

local function cleanAndSplit(str)
	-- Normalize newlines
	str = str:gsub("\r\n", "\n")

	local lines = {}
	for line in str:gmatch("[^\n]+") do
		line = line:match("^%s*(.-)%s*$") -- trim each line
		if line ~= "" then
			table.insert(lines, line)
		end
	end

	return lines
end

local uniqueNameLookup = {}
local unmatchedIds = {}
local originLookup = {}
local forcedNameMap = {
	["FourUniqueSceptre6"]   = "Guiding Palm",
	["FourUniqueSceptre6a"]  = "Guiding Palm of the Heart",
	["FourUniqueSceptre6b"]  = "Guiding Palm of the Eye",
	["FourUniqueSceptre6c"]  = "Guiding Palm of the Mind",
	["VaalLimbReplacements"]  = "Transcendent Limb",
}

for row in dat("UniqueStashLayout"):Rows() do
	-- We use Text2 because Words.Text has "The Immortan" instead of "The Road Warrior". Everything else so far matches up.
	local name = sanitiseText(row.WordsKey.Text2)
	local id = normalizeId(row.ItemVisualIdentity.Id)
	uniqueNameLookup[id] = name
	unmatchedIds[id] = name

	-- Look for origin in UniqueOrigins
	for originRow in dat("UniqueOrigins"):Rows() do
		if tostring(sanitiseText(originRow.Unique.Text2)) == name then
			originLookup[id] = originRow.Origin.Id
			break
		end
	end
end

local out = {}

local index = 1
for c in dat("FlavourText"):Rows() do
	local id = normalizeId(c.Id)
	local name = forcedNameMap[id] or uniqueNameLookup[id]
	local origin = originLookup[id]

	if name then
		local lines = cleanAndSplit(tostring(c.Text))
		table.insert(out, {
			id = c.Id,
			name = name,
			origin = origin,
			text = lines,
		})
		index = index + 1
		unmatchedIds[id] = nil
	end
end

utils.saveTableToFile("../Data/FlavourText.lua", out)

print("Flavour Texts exported.")

-- Print unmatched
print("Unique items from UniqueStashLayout without flavour text:")
for id, name in pairs(unmatchedIds) do
	print(string.format("Id: %s, Name: %s", id, name))
end
