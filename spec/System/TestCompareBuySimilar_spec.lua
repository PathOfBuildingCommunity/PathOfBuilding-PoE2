describe("Buy similar mod stat matching", function()
	local bs = LoadModule("Classes/CompareBuySimilar")

	describe("addModEntries mod matching", function()
		it("prefers the exact Instant Recovery trade stat over its percentage alternative", function()
			local item = new("Item"):Item("Rarity: Unique\nOlroth's Resolve\nUltimate Life Flask\nImplicits: 0\nInstant Recovery")
			local entries = bs.addModEntries(item, { { list = item.explicitModLines, type = "explicit" } })

			assert.equal(1, #entries)
			assert.same({ "explicit.stat_1526933524" }, entries[1].tradeIds)
			assert.is_nil(entries[1].value)
			assert.is_false(entries[1].isOption)
		end)

		it("keeps the numeric stat for partial instant recovery", function()
			local item = new("Item"):Item("Rarity: Magic\nUltimate Life Flask\nImplicits: 0\n25% of Recovery applied Instantly")
			local entries = bs.addModEntries(item, { { list = item.explicitModLines, type = "explicit" } })

			assert.equal(1, #entries)
			assert.same({ "explicit.stat_2503377690" }, entries[1].tradeIds)
			assert.equal(25, entries[1].value)
		end)

		it("matches from nothing mods as options", function()
			local fromNothing = new("Item"):Item([[
From Nothing
Diamond
LevelReq: 0
Radius: Small
Limited to: 1
Implicits: 0
Passives in radius of Zealot's Oath can be Allocated without being connected to your tree
Corrupted]])

			local modSources = {
				{ list = fromNothing.explicitModLines, type = "explicit" }
			}
			local modEntries = bs.addModEntries(fromNothing, modSources)
			assert.equal(1, #modEntries)
			assert.same(
				{
					formattedLines = { colorCodes.MAGIC.."Passives in radius of Zealot's Oath can be Allocated without being connected to your tree" },
					type =
					"explicit",
					isOption = true,
					invert = false,
					tradeIds = { "explicit.stat_2422708892|52" },
					value = nil
				},
				modEntries[1])
		end)

		it("combines mods that are the same stat", function()
			local lifeDiamond = new("Item"):Item([[
Test Subject
Diamond
Implicits: 0
+100 to Maximum Life
+50 to Maximum Life
+50% to Fire Resistance]])

			local entries = bs.addModEntries(lifeDiamond, { { list = lifeDiamond.explicitModLines, type = "explicit" } })
			assert.equal(2, #entries)
			assert.equal(2, #entries[1].formattedLines)
			assert.equal("+100 to Maximum Life", StripEscapes(entries[1].formattedLines[1]))
			assert.equal("+50 to Maximum Life", StripEscapes(entries[1].formattedLines[2]))
			assert.equal(150, entries[1].value)

			local lifelessDiamond = new("Item"):Item([[
Test Subject
Diamond
Implicits: 0
-100 to Maximum Life
+50 to Maximum Life
+50% to Fire Resistance]])
			local entries = bs.addModEntries(lifelessDiamond,
				{ { list = lifelessDiamond.explicitModLines, type = "explicit" } })
			assert.equal(2, #entries)
			assert.equal(2, #entries[1].formattedLines)
			assert.equal(-50, entries[1].value)
		end)

		it("is not case-sensitive", function ()
			local funnyItem = new("Item"):Item([[
Test Subject
Diamond
Implicits: 1
+50 tO MaxIMum lifE]])

			local entries = bs.addModEntries(funnyItem, {{list = funnyItem.implicitModLines, type = "implicit"}})
			assert.equal(1, #entries)
		end)

		it("does not combine implicit and explicit mods", function()
			local lifelessDiamond = new("Item"):Item([[
Test Subject
Diamond
Implicits: 1
-100 to Maximum Life
+50 to Maximum Life]])
			local entries = bs.addModEntries(lifelessDiamond,
				{ { list = lifelessDiamond.implicitModLines, type = "implicit" }, { list = lifelessDiamond.explicitModLines, type = "explicit" } })
			assert.equal(2, #entries)
			assert.equal(-100, entries[1].value)
			assert.equal(50, entries[2].value)
		end)
	end)

	describe("popup URL controls", function()
		local originalCopy
		local originalOpenURL
		local originalFetchLeagues
		local copiedUrl
		local searchEnv

		before_each(function()
			newBuild()
			local requests = build.itemsTab.tradeQuery.tradeQueryRequests
			originalFetchLeagues = requests.FetchLeagues
			requests.FetchLeagues = function(_, realm, callback)
				callback({ "Test League", "Standard" })
			end
		end)

		after_each(function()
			build.itemsTab.tradeQuery.tradeQueryRequests.FetchLeagues = originalFetchLeagues
			searchEnv.Copy = originalCopy
			searchEnv.OpenURL = originalOpenURL
			bs.lastRealmIdx = nil
			bs.lastLeagueIdx = nil
			bs.lastListedIndex = nil
			main:ClosePopup()
		end)

		local function openPopup(raw, slotName)
			local item = new("Item"):Item(raw or "Rarity: Rare\nTest Ring\nRuby Ring\nImplicits: 0\n+50 to maximum Life")
			bs.openPopup(item, slotName or "Ring", build)
			local controls = main.popups[1].controls
			searchEnv = getfenv(controls.search.onClick)
			originalCopy = originalCopy or searchEnv.Copy
			originalOpenURL = originalOpenURL or searchEnv.OpenURL
			searchEnv.Copy = function(url) copiedUrl = url end
			searchEnv.OpenURL = function() end
			return controls
		end

		it("searches for Instant Recovery without a percentage minimum", function()
			local controls = openPopup("Rarity: Unique\nOlroth's Resolve\nUltimate Life Flask\nImplicits: 0\nInstant Recovery", "Flask 1")
			controls.mod1Check.state = true
			controls.mod1Check.changeFunc(true)
			controls.search.onClick()
			local queryJson = copiedUrl:match("%?q=(.*)"):gsub("%%(%x%x)", function(hex)
				return string.char(tonumber(hex, 16))
			end)
			local query = require("dkjson").decode(queryJson)

			assert.same({ { type = "and", filters = { { id = "explicit.stat_1526933524" } } } }, query.query.stats)
		end)

		it("rebuilds the URL when league and listed status change", function()
			local controls = openPopup()
			controls.search.onClick()
			local initialUrl = copiedUrl

			controls.leagueDrop:SetSel(2)
			controls.search.onClick()
			assert.not_equal(initialUrl, copiedUrl)
			assert.is_truthy(copiedUrl:find("/Standard?", 1, true))
			local standardUrl = copiedUrl

			controls.listedDrop:SetSel(4)
			controls.search.onClick()
			assert.not_equal(standardUrl, copiedUrl)
			assert.is_truthy(copiedUrl:find("any", 1, true))
		end)

		it("persists popup selector choices", function()
			local controls = openPopup()
			controls.realmDrop.selFunc(1, "PoE2")
			controls.leagueDrop:SetSel(2)
			controls.listedDrop:SetSel(4)
			main:ClosePopup()

			controls = openPopup()
			assert.equal(1, bs.lastRealmIdx)
			assert.equal("Standard", controls.leagueDrop:GetSelValue())
			assert.equal("Any", controls.listedDrop:GetSelValue())
		end)
	end)
end)
