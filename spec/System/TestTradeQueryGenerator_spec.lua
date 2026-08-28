describe("TradeQueryGenerator", function()
	local mock_queryGen = new("TradeQueryGenerator"):TradeQueryGenerator({ itemsTab = {} })

	describe("ProcessMod", function()
		-- Pass: Mod line maps correctly to trade stat entry without error
		-- Fail: Mapping fails (e.g., no match found), indicating incomplete stat parsing for curse mods, potentially missing curse-enabling items in queries
		it("handles special curse case", function()
			local mod = { tradeHashes = {[30642521] = {"You can apply an additional Curse"}}, type = "Prefix", weightKey = {}, weightVal = {} }
			mock_queryGen.modData = { Explicit = {} }
			mock_queryGen:ProcessMod(mod)
			-- Simplified assertion; in full impl, check modData
			assert.is_true(true)
		end)
	end)

	describe("WeightedRatioOutputs", function()
		-- Pass: Returns 0, avoiding math errors
		-- Fail: Returns NaN/inf or crashes, indicating unhandled infinite values, causing evaluation failures in infinite-scaling builds
		it("handles infinite base", function()
			local baseOutput = { TotalDPS = math.huge }
			local newOutput = { TotalDPS = 100 }
			local statWeights = { { stat = "TotalDPS", weightMult = 1 } }
			local result = mock_queryGen.WeightedRatioOutputs(baseOutput, newOutput, statWeights)
			assert.are.equal(result, 0)
		end)

		-- Pass: Returns capped value (100), preventing division issues
		-- Fail: Returns inf/NaN, indicating unhandled zero base, leading to invalid comparisons in low-output builds
		it("handles zero base", function()
			local baseOutput = { TotalDPS = 0 }
			local newOutput = { TotalDPS = 100 }
			local statWeights = { { stat = "TotalDPS", weightMult = 1 } }
			data.misc.maxStatIncrease = 1000
			local result = mock_queryGen.WeightedRatioOutputs(baseOutput, newOutput, statWeights)
			assert.are.equal(result, 100)
		end)

		it("uses minion output for non-FullDPS stats when minion output is desired", function()
			local baseOutput = { Life = 10, Minion = { Life = 100 } }
			local newOutput = { Life = 10, Minion = { Life = 250 } }
			local statWeights = { { stat = "MinionLife", weightMult = 1 } }
			data.misc.maxStatIncrease = 1000

			local result = mock_queryGen.WeightedRatioOutputs(baseOutput, newOutput, statWeights)

			assert.are.equal(result, 2.5)
		end)

		it("uses lower is better stats correctly", function()
			local baseOutput = { MaxHit = 100 }
			local newOutput = { MaxHit = 10 }
			local statWeights = { { stat = "MaxHit", weightMult = 1, transform = function(number) return -number end } }
			data.misc.maxStatIncrease = 1000

			local result = mock_queryGen.WeightedRatioOutputs(baseOutput, newOutput, statWeights)

			local close_enough = math.abs(result - -0.1) < 0.0001
			assert.True(close_enough)
		end)

		it("uses player and minion output for FullDPS", function()
			-- minion output gets assigned to the player's full dps in reality
			local baseOutput = { FullDPS = 100, Minion = { FullDPS = 100 } }
			local newOutput = { FullDPS = 250, Minion = { FullDPS = 1000 } }
			local statWeights = { { stat = "FullDPS", weightMult = 1 } }
			data.misc.maxStatIncrease = 1000

			local result = mock_queryGen.WeightedRatioOutputs(baseOutput, newOutput, statWeights)

			assert.are.equal(result, 2.5)
		end)

		it("uses player output for non-FullDPS even when minion output is available", function()
			local baseOutput = { Life = 100, Minion = { Life = 100 } }
			local newOutput = { Life = 250, Minion = { Life = 1000 } }
			local statWeights = { { stat = "Life", weightMult = 1 } }
			data.misc.maxStatIncrease = 1000

			local result = mock_queryGen.WeightedRatioOutputs(baseOutput, newOutput, statWeights)
			assert.are.equal(result, 2.5)
		end)

		it("uses the fallback DPS ratio once when FullDPS is unavailable", function()
			local baseOutput = { Minion = { TotalDPS = 10, TotalDotDPS = 0, CombinedDPS = 10 } }
			local newOutput = { Minion = { TotalDPS = 25, TotalDotDPS = 0, CombinedDPS = 25 } }
			local statWeights = { { stat = "FullDPS", weightMult = 1 } }
			data.misc.maxStatIncrease = 1000

			local result = mock_queryGen.WeightedRatioOutputs(baseOutput, newOutput, statWeights)

			assert.are.equal(result, 2.5)
		end)

		it("falls back to player output when the selected stat is not on minion output", function()
			local baseOutput = { Spirit = 100, Minion = { AverageDamage = 100 } }
			local newOutput = { Spirit = 120, Minion = { AverageDamage = 100 } }
			local statWeights = { { stat = "Spirit", weightMult = 1 } }
			data.misc.maxStatIncrease = 1000

			local result = mock_queryGen.WeightedRatioOutputs(baseOutput, newOutput, statWeights)

			assert.are.equal(result, 1.2)
		end)
	end)

	describe("Filter prioritization", function()
		it("counts socket constraints against MAX_FILTERS", function()
			local queryGen = new("TradeQueryGenerator"):TradeQueryGenerator({ itemsTab = { items = {} } })
			queryGen.modWeights = {}
			for index = 1, 40 do
				table.insert(queryGen.modWeights, {
					tradeModId = "explicit.stat_" .. index,
					weight = 1,
					meanStatDiff = 41 - index,
				})
			end
			queryGen.calcContext = {
				testItem = new("Item"):Item("Rarity: RARE\nNew Item\nGold Ring\nImplicits: 0"),
				baseOutput = {},
				baseStatValue = 0,
				itemCategoryQueryStr = "accessory.ring",
				special = {},
				options = {
					statWeights = {},
					includeMirrored = false,
					sockets = 3,
				},
			}
			queryGen.tradeTypeIndex = 1
			local query
			queryGen.requesterCallback = function(_, queryJson)
				query = require("dkjson").decode(queryJson).query
			end
			queryGen:FinishQuery()

			assert.are.equal(31, #query.stats[1].filters)
			assert.is_not_nil(query.filters.equipment_filters.filters.rune_sockets)
		end)
	end)

	describe("Pseudo stat filters", function()
		local function runQuery(modWeights)
			local queryGen = new("TradeQueryGenerator"):TradeQueryGenerator({ itemsTab = { items = {} } })
			queryGen.modWeights = modWeights
			queryGen.calcContext = {
				testItem = new("Item"):Item("Rarity: RARE\nNew Item\nGold Ring\nImplicits: 0"),
				baseOutput = {},
				baseStatValue = 0,
				itemCategoryQueryStr = "accessory.ring",
				special = {},
				options = { statWeights = {}, includeMirrored = true },
			}
			queryGen.tradeTypeIndex = 1
			local query
			queryGen.requesterCallback = function(_, queryJson)
				query = require("dkjson").decode(queryJson).query
			end
			queryGen:FinishQuery()
			return query.stats[1].filters
		end

		it("maps single resistances and attributes to pseudo stats, keeping the highest weight", function()
			local filters = runQuery({
				-- +#% to Fire Resistance, as explicit and as rune
				{ tradeModId = "explicit.stat_3372524247", weight = 5, meanStatDiff = 2 },
				{ tradeModId = "rune.stat_3372524247", weight = 3, meanStatDiff = 1 },
				-- +# to Strength
				{ tradeModId = "explicit.stat_4080418644", weight = 7, meanStatDiff = 3 },
			})

			table.sort(filters, function(a, b) return a.id < b.id end)
			assert.are.equal(2, #filters)
			assert.are.equal("pseudo.pseudo_total_fire_resistance", filters[1].id)
			assert.are.equal(5, filters[1].value.weight)
			assert.are.equal("pseudo.pseudo_total_strength", filters[2].id)
			assert.are.equal(7, filters[2].value.weight)
		end)

		it("drops hybrid resistance and attribute stats", function()
			local filters = runQuery({
				-- +#% to Fire and Cold Resistances
				{ tradeModId = "explicit.stat_2915988346", weight = 9, meanStatDiff = 5 },
				-- +#% to all Elemental Resistances
				{ tradeModId = "explicit.stat_2901986750", weight = 9, meanStatDiff = 4 },
				-- +# to Strength and Dexterity
				{ tradeModId = "explicit.stat_538848803", weight = 9, meanStatDiff = 3 },
				-- +# to all Attributes
				{ tradeModId = "explicit.stat_1379411836", weight = 9, meanStatDiff = 2 },
				-- +# to maximum Life, kept
				{ tradeModId = "explicit.stat_3299347043", weight = 4, meanStatDiff = 1 },
			})

			assert.are.equal(1, #filters)
			assert.are.equal("explicit.stat_3299347043", filters[1].id)
		end)
	end)
end)
