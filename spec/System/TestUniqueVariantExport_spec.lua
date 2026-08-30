describe("Unique variant export", function()
	-- Run the real exporter against in-memory files without requiring GGPK data
	-- or overwriting any generated unique databases.
	local function export(source, base, mods, tables)
		local outputs = { }
		local env = setmetatable({
			table = setmetatable({ containsId = true }, { __index = table }),
			print = function() end,
			LoadModule = function(path)
				if path:find("/Bases/", 1, true) then
					return function(bases) bases["Gold Ring"] = base end
				end
				return path:find("ModItemExclusive", 1, true) and mods or { }
			end,
			dat = function(name)
				return tables and tables[name] or { GetRow = function() end }
			end,
			io = {
				open = function(path, mode)
					if mode == "r" then
						return { close = function() end }
					end
					local output = { }
					outputs[path] = output
					return {
						write = function(_, ...) table.insert(output, table.concat({ ... })) end,
						close = function() end,
					}
				end,
				lines = function(path)
					return (path == "Uniques/ring.lua" and source or ""):gmatch("[^\n]+")
				end,
			},
		}, { __index = _G })
		setfenv(assert(loadfile("Export/Scripts/uModsToText.lua")), env)()
		return table.concat(outputs["../Data/Uniques/ring.lua"])
	end

	it("preserves versions and reusable groups on translated and literal modifiers", function()
		local result = export([=[return {
[[
Export Test
Gold Ring
Version: Legacy
Version: Current
Variant: Life and Mana
Variant: Armour
Selected Variant Group: 1=1
{version:2}{variant:1}{group:1,2}{fractured}TestMod
{version:1}{variant:2}{group:1,2}+30 to Armour
]],
}]=], { req = { level = 1 } }, {
			TestMod = { "+10 to maximum Life", "+20 to maximum Mana", modTags = { "life" }, statOrder = { 1, 2 } },
		})
		assert.matches("Version: Legacy\nVersion: Current", result, 1, true)
		assert.matches("Selected Variant Group: 1=1", result, 1, true)
		assert.matches("{version:2}{variant:1}{group:1,2}{tags:life}{fractured}+10 to maximum Life", result, 1, true)
		assert.matches("{version:2}{variant:1}{group:1,2}{tags:life}{fractured}+20 to maximum Mana", result, 1, true)
		assert.matches("{version:1}{variant:2}{group:1,2}+30 to Armour", result, 1, true)
		local item = new("Item"):Item(assert(loadstring(result))()[1])
		assert.equals(10, item.baseModList:Sum("BASE", nil, "Life"))
		assert.equals(20, item.baseModList:Sum("BASE", nil, "Mana"))
	end)

	it("preserves independent versioned variants without adding group tags", function()
		local result = export([=[return {
[[
Independent Variant Export Test
Gold Ring
Version: Legacy
Version: Current
Selected Variant: 2
Variant: Life
Variant: Mana
{variant:1}TestMod
{variant:2}+20 to maximum Mana
]],
}]=], { req = { level = 1 } }, {
			TestMod = { "+10 to maximum Life", modTags = { "life" }, statOrder = { 1 } },
		})
		assert.matches("Version: Legacy\nVersion: Current", result, 1, true)
		assert.matches("{variant:1}{tags:life}+10 to maximum Life", result, 1, true)
		assert.matches("{variant:2}+20 to maximum Mana", result, 1, true)
		assert.is_nil(result:find("{group:", 1, true))
		local item = new("Item"):Item(assert(loadstring(result))()[1])
		assert.equals(2, item.variant)
		assert.is_true(item:HasIndependentVariants())
		assert.same({ }, item.variantGroups)
		assert.equals(20, item.baseModList:Sum("BASE", nil, "Mana"))
	end)

	it("replaces a base implicit with versioned implicit lines", function()
		local result = export([=[return {
[[
Implicit Test
Gold Ring
Version: Legacy
Version: Current
{version:1}TestImplicit
{version:2}TestImplicit
]],
}]=], { req = { level = 1 }, implicit = "+10 to maximum Life" }, {
			TestImplicit = { "+10 to maximum Life", modTags = { "life" }, statOrder = { 1 } },
		})
		assert.matches("Implicits: 2", result, 1, true)
		assert.matches("{version:1}{tags:life}+10 to maximum Life", result, 1, true)
		assert.matches("{version:2}{tags:life}+10 to maximum Life", result, 1, true)
		local item = new("Item"):Item(assert(loadstring(result))()[1])
		assert.equals(10, item.baseModList:Sum("BASE", nil, "Life"))
		assert.equals(2, #item.implicitModLines)
	end)

	it("preserves selection tags on granted skills", function()
		local rawMod = { Level = 1 }
		local result = export([=[return {
[[
Skill Test
Gold Ring
Version: Current
Variant: Skill
{version:1}{variant:1}{group:1}SkillMod
]],
}]=], { req = { level = 1 } }, { }, {
			Mods = { GetRow = function(_, _, name) return name == "SkillMod" and rawMod or nil end },
			ModGrantedSkills = { GetRow = function()
				return { SkillGem = {
					IsSupport = true,
					GemEffects = { { GrantedEffect = { ActiveSkill = { DisplayName = "Test Skill" } } } },
				} }
			end },
		})
		assert.matches("Implicits: 1\n{version:1}{variant:1}{group:1}Grants Skill: Test Skill", result, 1, true)
	end)
end)
