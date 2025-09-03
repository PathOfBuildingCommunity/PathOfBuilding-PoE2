describe("TestTradeQuery", function()
	before_each(function()
		-- Mock necessary global objects and functions to isolate the test
		_G.new = function(className, ...)
			if className == "TradeQueryRateLimiter" then
				return {
					GetPolicyName = function() return "mock_policy" end,
					NextRequestTime = function() return 0 end,
					InsertRequest = function() return 1 end,
					FinishRequest = function() end,
					UpdateFromHeader = function() end
				}
			end
			-- Fallback for other classes if needed
			return {}
		end
		_G.main = {
			POESESSID = "mock_poesessid_for_testing"
		}
		_G.dkjson = require("dkjson")
		_G.tradeQuery = nil -- Mock or setup as needed
	end)

	teardown(function()
		-- Clean up global mocks
		_G.new = nil
		_G.main = nil
		_G.dkjson = nil
		_G.tradeQuery = nil
	end)

	it("should construct the correct whisper URL", function()
		local requests = newClass("TradeQueryRequests")()
		assert.are.equals("https://www.pathofexile.com/api/trade2/whisper", requests.hostName .. "api/trade2/whisper")
	end)

	it("should format the whisper request body correctly with a space", function()
		local requests = newClass("TradeQueryRequests")()
		local testToken = "test_token_12345"
		requests:SendWhisper(testToken, "http://mock.referer", function() end)

		local whisperRequest = requests.requestQueue.whisper[1]
		assert.is_not_nil(whisperRequest)

		local expectedBody = '{"token": "' .. testToken .. '"}'
		assert.are.equals(expectedBody, whisperRequest.body)
	end)

	it("should include correct headers for the whisper request", function()
		local requests = newClass("TradeQueryRequests")()
		local testToken = "test_token_12345"
		local testReferer = "https://www.pathofexile.com/trade2/search/poe2/Test%20League/abcdef123"
		requests:SendWhisper(testToken, testReferer, function() end)

		local whisperRequest = requests.requestQueue.whisper[1]
		assert.is_not_nil(whisperRequest)
		assert.is_not_nil(whisperRequest.headers)

		assert.truthy(string.find(whisperRequest.headers, "Content-Type: application/json", 1, true))
		assert.truthy(string.find(whisperRequest.headers, "User-Agent: Mozilla/5.0", 1, true))
		assert.truthy(string.find(whisperRequest.headers, "X-Requested-With: XMLHttpRequest", 1, true))
		assert.truthy(string.find(whisperRequest.headers, "Referer: " .. testReferer, 1, true))
	end)

	it("should correctly build a trade search URL for the referer header", function()
		local requests = newClass("TradeQueryRequests")()
		local url = requests:buildUrl("https://www.pathofexile.com/trade2/search", "poe2", "Rise of the Abyssal", "kMLBg0KC5")
		local expectedUrl = "https://www.pathofexile.com/trade2/search/poe2/Rise+of+the+Abyssal/kMLBg0KC5"
		assert.are.equals(expectedUrl, url)
	end)
end)
