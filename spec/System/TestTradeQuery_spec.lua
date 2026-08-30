describe("TradeQuery", function ()
	local mock_tradeQuery
	local mock_queryGen

	before_each(function()
		mock_tradeQuery = new("TradeQuery"):TradeQuery({ itemsTab = {} })
		mock_queryGen = new("TradeQueryGenerator"):TradeQueryGenerator({ itemsTab = {} })
	end)

	describe("result dropdown tooltipFunc", function()
		-- Builds a TradeQuery with the strict minimum needed for
		-- PriceItemRowDisplay to construct row 1 without exploding. Only the
		-- two itemsTab subtables read by the slot lookup at the top of
		-- PriceItemRowDisplay need to be created here; everything else either
		-- lives behind a callback we never trigger, or is already initialized
		-- by the TradeQuery constructor.
		local function newTradeQuery(state)
			local tq                  = new("TradeQuery"):TradeQuery({ itemsTab = {} })
			tq.itemsTab.activeItemSet = {}
			tq.itemsTab.slots         = {}
			tq.slotTables[1]          = { slotName = "Ring 1" }
			if state.resultTbl then tq.resultTbl = state.resultTbl end
			if state.sortedResultTbl then tq.sortedResultTbl = state.sortedResultTbl end
			return tq
		end
		-- Builds row 1 of the trader UI and returns the dropdown that owns the
		-- tooltipFunc we want to exercise.
		local function buildRow1Dropdown(tq)
			tq:PriceItemRowDisplay(1, nil, 0, 20)
			return tq.controls.resultDropdown1
		end

		it("returns early when sortedResultTbl[row_idx] is missing", function()
			-- No sorted results at all -> first guard must short-circuit.
			local tq = newTradeQuery({})
			local dropdown = buildRow1Dropdown(tq)
			local tooltip = new("Tooltip"):Tooltip()

			assert.has_no.errors(function()
				dropdown.tooltipFunc(tooltip, "DROP", 1, nil)
			end)
			assert.are.equal(0, #tooltip.lines)
		end)

		it("returns early when the backing result entry has been cleared", function()
			-- The dropdown must be built against a valid result so that
			-- PriceItemRowDisplay's construction loop succeeds; we wipe
			-- resultTbl[1] only afterwards, to simulate a stale tooltip
			-- callback firing after the results were invalidated.
			local tq = newTradeQuery({
				resultTbl = { [1] = { [1] = { item_string = "Rarity: RARE\nBehemoth Hold\nGold Ring", amount = 1, currency = "chaos" } } },
				sortedResultTbl = { [1] = { { index = 1 } } },
			})
			local dropdown = buildRow1Dropdown(tq)
			tq.resultTbl[1] = {}
			local tooltip = new("Tooltip"):Tooltip()

			assert.has_no.errors(function()
				dropdown.tooltipFunc(tooltip, "DROP", 1, nil)
			end)
			assert.are.equal(0, #tooltip.lines)
		end)
	end)

	it("fits the OAuth clipboard status inside the login button", function()
		local status = mock_tradeQuery:FormatOAuthLoginStatus(60)

		assert.are.equals("URL copied - Login (60)", status)
		assert.is_true(DrawStringWidth(16, "VAR", status) <= 188)
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

	describe("result dropdown sizing", function()
		it("reserves space between labels and score details", function()
			local entry = { label = "A result item label", detail = "+123.4%" }
			local dropdown = new("DropDownControl"):DropDownControl(nil, { 0, 0, 100, 20 }, { entry })
			dropdown.maxDroppedWidth = 1000
			dropdown:CheckDroppedWidth(true)

			local textWidth = DrawStringWidth(16, "VAR", entry.label) + DrawStringWidth(16, "VAR", entry.detail)
			assert.is_true(dropdown.droppedWidth >= textWidth + 36)
		end)
	end)
end)
