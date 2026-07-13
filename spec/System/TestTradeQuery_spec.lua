describe("TradeQuery", function ()
	local mock_tradeQuery
	local mock_queryGen

	before_each(function()
		mock_tradeQuery = new("TradeQuery", { itemsTab = {} })
		mock_queryGen = new("TradeQueryGenerator", { itemsTab = {} })
	end)

	describe("ReduceOutput", function()
		it("uses selected minion stats for weighted result comparison", function()
			mock_tradeQuery.statSortSelectionList = { { stat = "AverageDamage" } }

			local result = mock_tradeQuery:ReduceOutput({
				AverageDamage = 10,
				Life = 100,
				Minion = {
					AverageDamage = 250,
					Life = 200,
				},
			})

			assert.are.equals(260, result.AverageDamage)
			assert.is_nil(result.Life)
		end)

		it("keeps fallback DPS stats when FullDPS is selected but not present", function()
			mock_tradeQuery.statSortSelectionList = { { stat = "FullDPS", weightMult = 1 } }

			local baseOutput = {
				CombinedDPS = 100,
				TotalDPS = 100,
				TotalDotDPS = 0,
			}
			local reducedOutput = mock_tradeQuery:ReduceOutput({
				CombinedDPS = 120,
				TotalDPS = 120,
				TotalDotDPS = 0,
			})

			local result = mock_queryGen.WeightedRatioOutputs(baseOutput, reducedOutput, mock_tradeQuery.statSortSelectionList)

			assert.are.equals(1.2, result)
		end)
	end)

	describe("ComputeStatDetails", function()
		it("uses Trader's FullDPS fallback inputs", function()
			mock_tradeQuery.statSortSelectionList = { { label = "Full DPS", stat = "FullDPS", weightMult = 1 } }

			local result = mock_tradeQuery:ComputeStatDetails({
				CombinedDPS = 100,
				TotalDPS = 100,
				TotalDotDPS = 0,
			}, {
				CombinedDPS = 100,
				TotalDPS = 200,
				TotalDotDPS = 0,
			})

			assert.are.equals(50, result[1].percentChange)
		end)

		it("reports lower-is-better stat improvements as positive", function()
			mock_tradeQuery.statSortSelectionList = {
				{
					label = "Taken Phys dmg",
					stat = "PhysicalTakenHit",
					weightMult = 1,
					transform = function(value) return -value end,
				},
			}

			local result = mock_tradeQuery:ComputeStatDetails({ PhysicalTakenHit = 100 }, { PhysicalTakenHit = 80 })

			assert.is_true(math.abs(result[1].percentChange - 20) < 0.0001)
		end)

		it("caps displayed increases to Trader's scoring maximum", function()
			mock_tradeQuery.statSortSelectionList = { { label = "Life", stat = "Life", weightMult = 1 } }
			local maxStatIncrease = data.misc.maxStatIncrease

			local result = mock_tradeQuery:ComputeStatDetails({ Life = 1 }, { Life = maxStatIncrease + 1 })

			assert.are.equals((maxStatIncrease - 1) * 100, result[1].percentChange)
		end)

		it("reports unchanged zero-value stats as unchanged", function()
			mock_tradeQuery.statSortSelectionList = { { label = "Block Chance", stat = "BlockChance", weightMult = 1 } }

			local result = mock_tradeQuery:ComputeStatDetails({ BlockChance = 0 }, { BlockChance = 0 })

			assert.are.equals(0, result[1].percentChange)
		end)

		it("reports improvements from zero as positive", function()
			mock_tradeQuery.statSortSelectionList = { { label = "Block Chance", stat = "BlockChance", weightMult = 1 } }
			local maxStatIncrease = data.misc.maxStatIncrease

			local result = mock_tradeQuery:ComputeStatDetails({ BlockChance = 0 }, { BlockChance = 0.5 })

			assert.are.equals((maxStatIncrease - 1) * 100, result[1].percentChange)
		end)
	end)

	describe("GetResultScorePercent", function()
		it("returns the weighted average stat delta", function()
			local result = mock_tradeQuery:GetResultScorePercent({
				statDetails = {
					{ percentChange = 10, weightMult = 1 },
					{ percentChange = -10, weightMult = 0.5 },
				},
			})

			assert.is_true(math.abs(result - (10 / 3)) < 0.0001)
		end)
	end)
end)
