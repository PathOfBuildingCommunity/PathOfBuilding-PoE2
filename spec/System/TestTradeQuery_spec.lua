describe("TradeQuery", function ()
	local mock_tradeQuery

	before_each(function()
		mock_tradeQuery = new("TradeQuery", { itemsTab = {} })
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
	end)
end)