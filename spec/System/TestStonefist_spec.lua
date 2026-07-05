-- Tests for the "Way of the Stonefist" ascendancy passive (Martial Artist): equipped
-- Gloves transform to the "Fists of Stone" base, renaming the base, converting their
-- explicit mods to stronger related mods, and granting per-level Evasion/Energy Shield.
describe("TestStonefist", function()
	before_each(function()
		newBuild()
	end)

	teardown(function()
		-- newBuild() takes care of resetting everything in setup()
	end)

	-- "+38 to maximum Energy Shield" is tier LocalIncreasedEnergyShield5 (36-41), which
	-- the map converts to +3 Evasion and +1 Energy Shield per level.
	local function makeVariant(baseName, level)
		local item = new("Item", "New Item\n" .. baseName .. "\n+38 to maximum Energy Shield")
		return item, item:CreateStonefistVariant(level)
	end

	it("renames the transformed base to Fists of Stone", function()
		local _, variant = makeVariant("Sombre Gloves")
		assert.is_truthy(variant)
		assert.are.equals("Fists of Stone", variant.baseName)
	end)

	it("converts a flat Energy Shield prefix into per-level defences", function()
		local _, variant = makeVariant("Sombre Gloves")
		-- flat Energy Shield is gone, replaced by per-level Evasion/Energy Shield
		assert.are.equals(0, variant.baseModList:Sum("BASE", nil, "EnergyShield"))
		assert.is_true(variant.baseModList:Sum("BASE", nil, "EvasionPerLevel") > 0)
		assert.is_true(variant.baseModList:Sum("BASE", nil, "EnergyShieldPerLevel") > 0)
	end)

	it("adds the Fists of Stone base implicit per-level defences", function()
		-- a glove with no defensive affix still gains the +3 Eva / +1 ES per level implicit
		local item = new("Item", "New Item\nSombre Gloves\n+38 to maximum Life")
		local variant = item:CreateStonefistVariant()
		assert.is_truthy(variant)
		assert.is_true(variant.baseModList:Sum("BASE", nil, "EvasionPerLevel") >= 3)
		assert.is_true(variant.baseModList:Sum("BASE", nil, "EnergyShieldPerLevel") >= 1)
	end)

	it("combines base implicit and converted item mods in the level-scaled defence value", function()
		local _, variant = makeVariant("Sombre Gloves")
		-- implicit (+3 Eva / +1 ES) + converted mod (+3 Eva / +1 ES) per level, at level 100,
		-- excluding the global "% more" modifier
		assert.are.equals(600, variant:GetArmourDataValue("Evasion", 100))
		assert.are.equals(200, variant:GetArmourDataValue("EnergyShield", 100))
		assert.are.equals(0, variant:GetArmourDataValue("Ward", 100))
	end)

	it("uses the Runeforged Fists of Stone implicit (with Runic Ward) for runeforged bases", function()
		local _, variant = makeVariant("Runeforged Sombre Gloves")
		-- runeforged implicit (+2 Eva / +1 ES / +1 Ward) + converted mod (+3 Eva / +1 ES) per level
		assert.are.equals(500, variant:GetArmourDataValue("Evasion", 100))
		assert.are.equals(200, variant:GetArmourDataValue("EnergyShield", 100))
		assert.are.equals(100, variant:GetArmourDataValue("Ward", 100))
	end)

	it("resolves per-level display strings at the given character level", function()
		local _, variant = makeVariant("Sombre Gloves", 100)
		-- with a display level, "per player level" implicits resolve to concrete values (+3 * 100)
		local resolved = false
		for _, line in ipairs(variant.implicitModLines) do
			if line.line:find("+300 to Evasion Rating", 1, true) then
				resolved = true
			end
			assert.is_nil(line.line:find("per player level", 1, true))
		end
		assert.is_true(resolved)
	end)

	it("returns nil for items that are not armour gloves", function()
		local ring = new("Item", "New Item\nSapphire Ring")
		assert.is_nil(ring:CreateStonefistVariant())
	end)
end)
