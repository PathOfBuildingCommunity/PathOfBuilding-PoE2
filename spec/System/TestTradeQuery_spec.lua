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
end)