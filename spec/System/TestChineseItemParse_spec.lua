-- 国服 fork: verify a Simplified-Chinese (WeGame) item paste is auto-translated
-- and parsed by PoB's real parser (the constructor hook calls translateChineseItem
-- before sanitiseText). The translation tables are datamined (see tools/cn-translate).
describe("TestChineseItemParse", function()
	-- The example 国服 paste from POB-FORK-HANDOFF.md (a rare Shrine Sceptre).
	local sceptreRaw = table.concat({
		"物品类别： 权杖",
		"稀有度： 稀有",
		"复仇 巨锤",
		"圣地权杖",
		"--------",
		"品质： +20% (augmented)",
		"精魂： 177 (augmented)",
		"--------",
		"需求： 等级 84, 45 力量, 114 智慧",
		"--------",
		"插槽： S",
		"--------",
		"物品等级： 84",
		"--------",
		"该装备精魂提高 15% (rune)",
		"--------",
		"获得技能： 等级 19 冰霜净化",
		"--------",
		'{ 前缀属性 "龙胆的" (等阶：4) — 魔力 }',
		"+98 (90-104) 魔力上限",
		'{ 前缀属性 "国王的" (等阶：1) }',
		"该装备精魂提高 62 (61-65)%",
		'{ 后缀属性 "哲学家之" (等阶：4) — 属性 }',
		"+21 (21-24) 智慧",
		'{ 后缀属性 "涅盘之" (等阶：1) — 魔力 }',
		"魔力再生率提高 67 (60-69)%",
		'{ 后缀属性 "校长之" (等阶：3) — 生命, 召唤生物 }',
		"召唤生物的生命上限提高 39 (36-40)%",
		"--------",
		"引路石掉落",
	}, "\n")

	it("parses base type, class and rarity", function()
		local item = new("Item", sceptreRaw)
		assert.are.equals("RARE", item.rarity)
		assert.are.equals("Shrine Sceptre", item.baseName)
		assert.is_not_nil(item.base)
	end)

	it("parses the explicit mods", function()
		local item = new("Item", sceptreRaw)
		local text = table.concat(item.explicitModLines and (function()
			local t = {}
			for _, m in ipairs(item.explicitModLines) do t[#t + 1] = m.line end
			return t
		end)() or {}, "\n")
		assert.is_true(#item.explicitModLines >= 5)
		assert.is_truthy(text:find("increased Mana Regeneration Rate", 1, true))
		assert.is_truthy(text:find("to maximum Mana", 1, true))
		assert.is_truthy(text:find("to Intelligence", 1, true))
		assert.is_truthy(text:find("increased maximum Life", 1, true))
	end)

	it("parses item level and spirit", function()
		local item = new("Item", sceptreRaw)
		assert.are.equals(84, item.itemLevel)
		assert.are.equals(177, item.spiritValue)
	end)

	it("routes the rune mod to runeModLines", function()
		local item = new("Item", sceptreRaw)
		local foundRune = false
		for _, m in ipairs(item.runeModLines or {}) do
			if m.line:find("increased Spirit", 1, true) then foundRune = true end
		end
		assert.is_true(foundRune)
	end)

	it("leaves an English paste untouched", function()
		local en = "Rarity: Rare\nName\nShrine Sceptre\n--------\nItem Level: 84"
		local item = new("Item", en)
		assert.are.equals("Shrine Sceptre", item.baseName)
		assert.are.equals(84, item.itemLevel)
	end)

	-- Corpus of real in-game 国服 pastes (tools/items.txt, &&-separated). Every item
	-- must have its base type recognised after translation; we also report mod counts.
	it("parses the real 国服 corpus", function()
		local f = io.open("../tools/items.txt", "rb")
		if not f then pending("tools/items.txt not present"); return end
		local corpus = f:read("*a"); f:close()
		local items, cur = {}, {}
		for line in (corpus .. "\n"):gmatch("([^\n]*)\n") do
			if line:gsub("%s", "") == "&&" then
				items[#items + 1] = table.concat(cur, "\n"); cur = {}
			else cur[#cur + 1] = line end
		end
		if #cur > 0 then items[#items + 1] = table.concat(cur, "\n") end

		local failures = {}
		for i, raw in ipairs(items) do
			if raw:gsub("%s", "") ~= "" then
				local item = new("Item", raw)
				local nMods = #item.explicitModLines + #item.implicitModLines
					+ #item.runeModLines + #item.enchantModLines
				print(string.format("  item %2d: base=%-28s rarity=%-7s mods=%d prefix=%d suffix=%d",
					i, tostring(item.baseName), tostring(item.rarity), nMods, #item.prefixes, #item.suffixes))
				if not item.base then
					failures[#failures + 1] = string.format("item %d: base %q not recognised", i, tostring(item.baseName))
				end
			end
		end
		assert.are.equals(0, #failures, "\n" .. table.concat(failures, "\n"))
	end)
end)
