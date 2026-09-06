describe("TestSoulCores", function()
	local modRunes = LoadModule("../src/Data/ModRunes")

	local function assertSoulCore(name, slot, lines)
		local soulCore = assert(modRunes[name], "Missing Soul Core: " .. name)
		local mod = assert(soulCore[slot], "Missing " .. slot .. " modifier for " .. name)
		assert.are.equal("SoulCore", mod.type)
		for index, line in ipairs(lines) do
			assert.are.equal(line, mod[index], name .. " (" .. slot .. ")")
		end
	end

	it("contains the new 0.5.5 Soul Cores", function()
		local expected = {
			{ "Jiquani's Soul Core of Automation", "weapon", "+1 to Level of all Totem Skill Gems" },
			{ "Jiquani's Soul Core of Malediction", "weapon", "+1 to Level of all Curse Skills" },
			{ "Jiquani's Soul Core of Targeting", "weapon", "+1 to Level of all Mark Skills" },
			{ "Jiquani's Soul Core of Rallying", "weapon", "+1 to Level of all Warcry Skill Gems" },
			{ "Jiquani's Soul Core of Radiance", "weapon", "+1 to Level of all Herald Skill Gems" },
			{ "Jiquani's Soul Core of Severing", "weapon", "+1 to Level of all Strike Skill Gems" },
			{ "Jiquani's Soul Core of Rippling", "weapon", "+1 to Level of all Nova Skill Gems" },
			{ "Jiquani's Soul Core of Quaking", "weapon", "+1 to Level of all Slam Skill Gems" },
			{ "Jiquani's Soul Core of Munitions", "weapon", "+1 to Level of all Grenade Skill Gems" },
			{ "Jiquani's Soul Core of Snares", "weapon", "+1 to Level of all Hazard Skill Gems" },
			{ "Jiquani's Soul Core of Abundance", "weapon", "+1 to Level of all Plant Skill Gems" },
			{ "Jiquani's Soul Core of Squalls", "weapon", "+1 to Level of all Wind Skill Gems" },
			{ "Jiquani's Soul Core of Thundering", "weapon", "+1 to Level of all Storm Skill Gems" },
			{ "Atziri's Soul Core of Devotion", "helmet", "1% increased Spirit for each Corrupted Item Equipped" },
			{ "Atziri's Soul Core of Vitality", "body armour", "1% increased Maximum Life for each Corrupted Item Equipped" },
			{ "Atziri's Soul Core of Alacrity", "gloves", "1% increased Skill Speed for each Corrupted Item Equipped" },
			{ "Atziri's Soul Core of Inoculation", "boots", "+2% to Chaos Resistance for each Corrupted Item Equipped" },
		}

		for _, soulCore in ipairs(expected) do
			assertSoulCore(soulCore[1], soulCore[2], { soulCore[3] })
		end
	end)

	it("contains the 0.5.5 Soul Core balance changes", function()
		local expected = {
			{ "Atmohua's Soul Core of Retreat", "body armour", { "40% increased Energy Shield from Equipped Focus" } },
			{ "Atmohua's Soul Core of Retreat", "focus", { "30% increased Energy Shield from Equipped Body Armour" } },
			{ "Cholotl's Soul Core of War", "bow", { "Projectiles have 20% chance to Chain an additional time from terrain" } },
			{ "Estazunti's Soul Core of Convalescence", "boots", { "15% increased speed of Recoup Effects" } },
			{ "Estazunti's Soul Core of Convalescence", "helmet", { "10% of Damage taken Recouped as Life" } },
			{ "Uromoti's Soul Core of Attenuation", "boots", { "20% increased Curse Duration", "20% increased Poison Duration" } },
			{ "Soul Core of Tacati", "weapon", { "25% increased Magnitude of Poison you inflict" } },
			{ "Soul Core of Tacati", "armour", { "+13% to Chaos Resistance" } },
			{ "Soul Core of Opiloti", "weapon", { "40% increased Magnitude of Bleeding you inflict" } },
			{ "Soul Core of Opiloti", "helmet", { "25% increased Pin duration" } },
			{ "Soul Core of Jiquani", "weapon", { "Recover 5% of maximum Life on Kill" } },
			{ "Soul Core of Jiquani", "body armour", { "5% increased maximum Life" } },
			{ "Soul Core of Zalatl", "weapon", { "Recover 4% of maximum Mana on Kill" } },
			{ "Soul Core of Zalatl", "helmet", { "5% increased maximum Mana" } },
			{ "Soul Core of Citaqualotl", "weapon", { "40% increased Elemental Damage with Attacks" } },
			{ "Soul Core of Citaqualotl", "armour", { "+6% to all Elemental Resistances" } },
			{ "Soul Core of Puhuarte", "weapon", { "40% increased Ignite Magnitude" } },
			{ "Soul Core of Puhuarte", "gloves", { "+2% to Maximum Fire Resistance" } },
			{ "Soul Core of Tzamoto", "weapon", { "60% increased Freeze Buildup" } },
			{ "Soul Core of Tzamoto", "helmet", { "+2% to Maximum Cold Resistance" } },
			{ "Soul Core of Xopec", "weapon", { "25% increased Magnitude of Shock you inflict" } },
			{ "Soul Core of Xopec", "boots", { "+2% to Maximum Lightning Resistance" } },
			{ "Soul Core of Topotante", "weapon", { "Attacks with this Weapon Penetrate 25% Elemental Resistances" } },
			{ "Soul Core of Topotante", "boots", { "25% reduced Effect of Non-Damaging Ailments on you" } },
			{ "Soul Core of Ticaba", "body armour", { "Hits against you have 50% reduced Critical Damage Bonus" } },
			{ "Soul Core of Atmohua", "weapon", { "Convert 40% of Requirements to Strength" } },
			{ "Soul Core of Cholotl", "weapon", { "Convert 40% of Requirements to Dexterity" } },
			{ "Soul Core of Zantipi", "weapon", { "Convert 40% of Requirements to Intelligence" } },
			{ "Jiquani's Thesis", "helmet", { "+1 to maximum Mana per 3 Item Armour on Equipped Helmet" } },
		}

		for _, soulCore in ipairs(expected) do
			assertSoulCore(soulCore[1], soulCore[2], soulCore[3])
		end
	end)
end)
