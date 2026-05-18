describe("TestChargeConsumption", function()
	before_each(function()
		newBuild()
	end)

	local function setupBarrage(inhibitor)
		build.itemsTab:CreateDisplayItemFromRaw([[
			New Item
			Hardwood Spear
			Quality: 0
		]])
		build.itemsTab:AddDisplayItem()
		runCallback("OnFrame")

		local socketGroup = "Barrage 20/0  1"
		if inhibitor then
			socketGroup = socketGroup .. "\nInhibitor 1/0  1"
		end
		build.skillsTab:PasteSocketGroup(socketGroup)
		runCallback("OnFrame")
	end

	local function getBarrageRepeatCounts()
		local baseRepeats = 0
		local chargeRepeats = 0
		for _, auxSkill in ipairs(build.calcsTab.mainEnv.auxSkillList) do
			if auxSkill.activeEffect.grantedEffect.name == "Barrage" then
				for _, buff in ipairs(auxSkill.buffList) do
					if buff.name == "Barrage" then
						for _, mod in ipairs(buff.modList) do
							if mod.name == "BarrageRepeats" then
								local usesRemovableFrenzyCharge = false
								for _, tag in ipairs(mod) do
									if tag.var == "RemovableFrenzyCharge" then
										usesRemovableFrenzyCharge = true
										break
									end
								end
								if usesRemovableFrenzyCharge then
									chargeRepeats = chargeRepeats + 1
								else
									baseRepeats = baseRepeats + 1
								end
							end
						end
					end
				end
			end
		end
		return baseRepeats, chargeRepeats
	end

	it("Inhibitor removes Barrage charge-consumption repeat benefits", function()
		setupBarrage(false)
		local baseRepeats, chargeRepeats = getBarrageRepeatCounts()
		assert.are.equals(1, baseRepeats)
		assert.are.equals(1, chargeRepeats)

		newBuild()
		setupBarrage(true)
		baseRepeats, chargeRepeats = getBarrageRepeatCounts()
		assert.are.equals(1, baseRepeats)
		assert.are.equals(0, chargeRepeats)
	end)
end)
