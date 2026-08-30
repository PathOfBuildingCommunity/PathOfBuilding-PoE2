describe("PoEAPI auth", function()
	local originalLaunchSubScript
	local originalDownloadPage
	local originalSubScripts

	before_each(function()
		originalLaunchSubScript = _G.LaunchSubScript
		originalDownloadPage = launch.DownloadPage
		originalSubScripts = launch.subScripts
		launch.subScripts = { }
	end)

	after_each(function()
		_G.LaunchSubScript = originalLaunchSubScript
		launch.DownloadPage = originalDownloadPage
		launch.subScripts = originalSubScripts
	end)

	it("passes token exchange errors to the auth callback #auth", function()
		local authState
		local exportedFunctions
		_G.LaunchSubScript = function(_, _, exports, authUrl)
			exportedFunctions = exports
			authState = authUrl:match("state=([^&]+)")
			return 123
		end
		launch.DownloadPage = function(_, url, callback)
			assert.are.equals("https://www.pathofexile.com/oauth/token", url)
			callback(nil, "SSL connect error")
		end

		local api = new("PoEAPI"):PoEAPI()
		local callbackArgs
		api:FetchAuthToken(function(response, errMsg, updateSettings)
			callbackArgs = {
				response = response,
				errMsg = errMsg,
				updateSettings = updateSettings,
			}
		end)

		assert.is_not_nil(authState)
		assert.are.equals("ConPrintf,OpenURL,Copy", exportedFunctions)
		assert.is_not_nil(launch.subScripts[123])
		launch.subScripts[123].callback("auth-code", nil, authState, 12345)

		assert.is_nil(callbackArgs.response)
		assert.are.equals("SSL connect error", callbackArgs.errMsg)
		assert.True(callbackArgs.updateSettings)
		assert.is_nil(api.authToken)
	end)

	it("reports OAuth state mismatches without exchanging a token", function()
		_G.LaunchSubScript = function()
			return 123
		end
		launch.DownloadPage = function()
			error("token exchange should not run for mismatched OAuth state")
		end

		local api = new("PoEAPI"):PoEAPI()
		local callbackArgs
		api:FetchAuthToken(function(response, errMsg, updateSettings)
			callbackArgs = {
				response = response,
				errMsg = errMsg,
				updateSettings = updateSettings,
			}
		end)

		assert.is_not_nil(launch.subScripts[123])
		launch.subScripts[123].callback("auth-code", nil, "wrong-state", 12345)

		assert.is_nil(callbackArgs.response)
		assert.are.equals("OAuth state mismatch", callbackArgs.errMsg)
		assert.True(callbackArgs.updateSettings)
		assert.is_nil(api.authToken)
	end)

	it("configures the callback server clipboard fallback for 60 seconds", function()
		local server = assert(io.open("LaunchServer.lua", "r"))
		local source = server:read("*a")
		server:close()

		assert.is_function(assert(loadstring(source, "@LaunchServer.lua")))
		assert.matches("Copy%(url%)", source)
		assert.matches("local stopAt = os%.time%(%) %+ 60", source)
	end)
end)
