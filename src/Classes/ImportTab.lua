-- Path of Building
--
-- Module: Import Tab
-- Import/Export tab for the current build.
--
local ipairs = ipairs
local t_insert = table.insert
local t_remove = table.remove
local b_rshift = bit.rshift
local band = bit.band
local m_max = math.max
local dkjson = require "dkjson"

local realmList = {
	{ label = "PoE2", id = "PoE2", realmCode = "poe2", hostName = "https://www.pathofexile.com/", profileURL = "account/view-profile/" },
}

local ImportTabClass = newClass("ImportTab", "ControlHost", "Control", function(self, build)
	self.ControlHost()
	self.Control()

	self.build = build
	self.api = new("PoEAPI", main.lastToken, main.lastRefreshToken, main.tokenExpiry)

	self.charImportMode = "AUTHENTICATION"
	self.charImportStatus = colorCodes.WARNING.."Not authenticated"
	self.controls.sectionCharImport = new("SectionControl", {"TOPLEFT",self,"TOPLEFT"}, {10, 18, 650, 200}, "Character Import")
	self.controls.charImportStatusLabel = new("LabelControl", {"TOPLEFT",self.controls.sectionCharImport,"TOPLEFT"}, {6, 14, 200, 16}, function()
		return "^7Character import status: "..(type(self.charImportStatus) == "function" and self.charImportStatus() or self.charImportStatus)
	end)

	self.controls.logoutApiButton = new("ButtonControl", {"TOPLEFT",self.controls.charImportStatusLabel,"TOPRIGHT"}, {4, 0, 180, 16}, "^7Logout from Path of Exile API", function()
		main.lastToken = nil
		self.api.authToken = nil
		main.lastRefreshToken = nil
		self.api.refreshToken = nil
		main.tokenExpiry = nil
		self.api.tokenExpiry = nil
		main:SaveSettings()
		self.charImportMode = "AUTHENTICATION"
		self.charImportStatus = colorCodes.WARNING.."Not authenticated"
	end)
	self.controls.logoutApiButton.shown = function()
		return (self.charImportMode == "SELECTCHAR" or self.charImportMode == "GETACCOUNTNAME") and self.api.authToken ~= nil
	end
	
	self.controls.characterImportAnchor = new("Control", {"TOPLEFT",self.controls.sectionCharImport,"TOPLEFT"}, {6, 40, 200, 16})
	self.controls.sectionCharImport.height = function() return self.charImportMode == "AUTHENTICATION" and 60 or 200 end

	-- Stage: Authenticate
	self.controls.authenticateButton = new("ButtonControl", {"TOPLEFT",self.controls.characterImportAnchor,"TOPLEFT"}, {0, 0, 200, 16}, "^7Authorize with Path of Exile", function()
		self.api:FetchAuthToken(function()
			if self.api.authToken then
				self.charImportMode = "GETACCOUNTNAME"
				self.charImportStatus = "Authenticated"

				main.lastToken = self.api.authToken
				main.lastRefreshToken = self.api.refreshToken
				main.tokenExpiry = self.api.tokenExpiry
				main:SaveSettings()
				self:DownloadCharacterList()
			else
				self.charImportStatus = colorCodes.WARNING.."Not authenticated"
			end
		end)
		local clickTime = os.time()
		self.charImportStatus = function() return "Logging in... (" .. m_max(0, (clickTime + 30) - os.time()) .. ")" end
	end)
	self.controls.authenticateButton.shown = function()
		return self.charImportMode == "AUTHENTICATION"
	end

	-- Stage: fetch characters
	self.controls.accountNameHeader = new("LabelControl", {"TOPLEFT",self.controls.characterImportAnchor,"TOPLEFT"}, {0, 0, 200, 16}, "^7To start importing a character, select your character's realm:")
	self.controls.accountNameHeader.shown = function()
		return self.charImportMode == "GETACCOUNTNAME"
	end
	self.controls.accountRealm = new("DropDownControl", {"TOPLEFT",self.controls.accountNameHeader,"BOTTOMLEFT"}, {0, 4, 60, 20}, realmList )
	self.controls.accountRealm:SelByValue( main.lastRealm or "PC", "id" )

	self.controls.accountNameGo = new("ButtonControl", {"LEFT",self.controls.accountNameHeader,"RIGHT"}, {8, 0, 60, 20}, "Start", function()
		self:DownloadCharacterList()
	end)

	-- Stage: select character and import data
	self.controls.charSelectHeader = new("LabelControl", {"TOPLEFT",self.controls.sectionCharImport,"TOPLEFT"}, {6, 40, 200, 16}, "^7Choose character to import data from:")
	self.controls.charSelectHeader.shown = function()
		return self.charImportMode == "SELECTCHAR" or self.charImportMode == "IMPORTING"
	end
	self.controls.charSelectLeagueLabel = new("LabelControl", {"TOPLEFT",self.controls.charSelectHeader,"BOTTOMLEFT"}, {0, 6, 0, 14}, "^7League:")
	self.controls.charSelectLeague = new("DropDownControl", {"LEFT",self.controls.charSelectLeagueLabel,"RIGHT"}, {4, 0, 150, 18}, nil, function(index, value)
		self:BuildCharacterList(value.league)
	end)
	self.controls.charSelect = new("DropDownControl", {"TOPLEFT",self.controls.charSelectHeader,"BOTTOMLEFT"}, {0, 24, 400, 18})
	self.controls.charSelect.enabled = function()
		return self.charImportMode == "SELECTCHAR"
	end
	self.controls.charImportHeader = new("LabelControl", {"TOPLEFT",self.controls.charSelect,"BOTTOMLEFT"}, {0, 16, 200, 16}, "Import:")
	self.controls.charImportTree = new("ButtonControl", {"LEFT",self.controls.charImportHeader, "RIGHT"}, {8, 0, 170, 20}, "Passive Tree and Jewels", function()
		if self.build.spec:CountAllocNodes() > 0 then
			main:OpenConfirmPopup("Character Import", "Importing the passive tree will overwrite your current tree.", "Import", function()
				self:DownloadPassiveTree()
			end)
		else
			self:DownloadPassiveTree()
		end
	end)
	self.controls.charImportTree.enabled = function()
		return self.charImportMode == "SELECTCHAR"
	end
	self.controls.charImportTreeClearJewels = new("CheckBoxControl", {"LEFT",self.controls.charImportTree,"RIGHT"}, {90, 0, 18}, "Delete jewels:", nil, "Delete all existing jewels when importing.", true)
	self.controls.charImportItems = new("ButtonControl", {"LEFT",self.controls.charImportTree, "LEFT"}, {0, 36, 110, 20}, "Items and Skills", function()
		self:DownloadItems()
	end)
	self.controls.charImportItems.enabled = function()
		return self.charImportMode == "SELECTCHAR"
	end
	self.controls.charImportItemsClearSkills = new("CheckBoxControl", {"LEFT",self.controls.charImportItems,"RIGHT"}, {85, 0, 18}, "Delete skills:", nil, "Delete all existing skills when importing.", true)
	self.controls.charImportItemsClearItems = new("CheckBoxControl", {"LEFT",self.controls.charImportItems,"RIGHT"}, {220, 0, 18}, "Delete equipment:", nil, "Delete all equipped items when importing.", true)
	self.controls.charImportItemsIgnoreWeaponSwap = new("CheckBoxControl", {"LEFT",self.controls.charImportItems,"RIGHT"}, {380, 0, 18}, "Ignore weapon swap:", nil, "Ignore items and skills in weapon swap.", false)

	-- Build import/export
	self.controls.sectionBuild = new("SectionControl", {"TOPLEFT",self.controls.sectionCharImport,"BOTTOMLEFT",true}, {0, 18, 650, 182}, "Build Sharing")
	self.controls.generateCodeLabel = new("LabelControl", {"TOPLEFT",self.controls.sectionBuild,"TOPLEFT"}, {6, 14, 0, 16}, "^7Generate a code to share this build with other Path of Building users:")
	self.controls.generateCode = new("ButtonControl", {"LEFT",self.controls.generateCodeLabel,"RIGHT"}, {4, 0, 80, 20}, "Generate", function()
		self.controls.generateCodeOut:SetText(common.base64.encode(Deflate(self.build:SaveDB("code"))):gsub("+","-"):gsub("/","_"))
	end)
	self.controls.enablePartyExportBuffs = new("CheckBoxControl", {"LEFT",self.controls.generateCode,"RIGHT"}, {100, 0, 18}, "Export Support", function(state)
		self.build.partyTab.enableExportBuffs = state
		self.build.buildFlag = true 
	end, "This is for party play, to export support character, it enables the exporting of auras, curses and modifiers to the enemy", false)
	self.controls.generateCodeOut = new("EditControl", {"TOPLEFT",self.controls.generateCodeLabel,"BOTTOMLEFT"}, {0, 8, 250, 20}, "", "Code", "%Z")
	self.controls.generateCodeOut.enabled = function()
		return #self.controls.generateCodeOut.buf > 0
	end
	self.controls.generateCodeCopy = new("ButtonControl", {"LEFT",self.controls.generateCodeOut,"RIGHT"}, {8, 0, 60, 20}, "Copy", function()
		Copy(self.controls.generateCodeOut.buf)
		self.controls.generateCodeOut:SetText("")
	end)
	self.controls.generateCodeCopy.enabled = function()
		return #self.controls.generateCodeOut.buf > 0
	end

	local getExportSitesFromImportList = function()
		local exportWebsites = { }
		for k,v in pairs(buildSites.websiteList) do
			-- if entry has fields needed for Export
			if buildSites.websiteList[k].postUrl and buildSites.websiteList[k].postFields and buildSites.websiteList[k].codeOut then
				table.insert(exportWebsites, v)
			end
		end
		return exportWebsites
	end
	local exportWebsitesList = getExportSitesFromImportList()

	self.controls.exportFrom = new("DropDownControl", { "LEFT", self.controls.generateCodeCopy,"RIGHT"}, {8, 0, 120, 20}, exportWebsitesList, function(_, selectedWebsite)
		main.lastExportWebsite = selectedWebsite.id
		self.exportWebsiteSelected = selectedWebsite.id
	end)
	self.controls.exportFrom:SelByValue(self.exportWebsiteSelected or main.lastExportWebsite or "Pastebin", "id")
	self.controls.generateCodeByLink = new("ButtonControl", { "LEFT", self.controls.exportFrom, "RIGHT"}, {8, 0, 100, 20}, "Share", function()
		local exportWebsite = exportWebsitesList[self.controls.exportFrom.selIndex]
		local subScriptId = buildSites.UploadBuild(self.controls.generateCodeOut.buf, exportWebsite)
		if subScriptId then
			self.controls.generateCodeOut:SetText("")
			self.controls.generateCodeByLink.label = "Creating link..."
			launch:RegisterSubScript(subScriptId, function(pasteLink, errMsg)
				self.controls.generateCodeByLink.label = "Share"
				if errMsg then
					main:OpenMessagePopup(exportWebsite.id, "Error creating link:\n"..errMsg)
				else
					self.controls.generateCodeOut:SetText(exportWebsite.codeOut..pasteLink)
				end
			end)
		end
	end)
	self.controls.generateCodeByLink.enabled = function()
		for _, exportSite in ipairs(exportWebsitesList) do
			if #self.controls.generateCodeOut.buf > 0 and self.controls.generateCodeOut.buf:match(exportSite.matchURL) then
				return false
			end
		end
		return #self.controls.generateCodeOut.buf > 0
	end
	self.controls.exportFrom.enabled = function()
		for _, exportSite in ipairs(exportWebsitesList) do
			if #self.controls.generateCodeOut.buf > 0 and self.controls.generateCodeOut.buf:match(exportSite.matchURL) then
				return false
			end
		end
		return #self.controls.generateCodeOut.buf > 0
	end
	self.controls.generateCodeNote = new("LabelControl", {"TOPLEFT",self.controls.generateCodeOut,"BOTTOMLEFT"}, {0, 4, 0, 14}, "^7Note: this code can be very long; you can use 'Share' to shrink it.")
	self.controls.importCodeHeader = new("LabelControl", {"TOPLEFT",self.controls.generateCodeNote,"BOTTOMLEFT"}, {0, 26, 0, 16}, "^7To import a build, enter URL or code here:")

	local importCodeHandle = function (buf)
		self.importCodeSite = nil
		self.importCodeDetail = ""
		self.importCodeXML = nil
		self.importCodeValid = false
		self.importCodeJson = nil

		if #buf == 0 then
			return
		end

		if not self.build.dbFileName then
			self.controls.importCodeMode.selIndex = 2
		end

		self.importCodeDetail = colorCodes.NEGATIVE.."Invalid input"
		local urlText = buf:gsub("^[%s?]+", ""):gsub("[%s?]+$", "") -- Quick Trim
		if urlText:match("youtube%.com/redirect%?") or urlText:match("google%.com/url%?") then
			local nested_url = urlText:gsub(".*[?&]q=([^&]+).*", "%1")
			urlText = UrlDecode(nested_url)
		end

		for j=1,#buildSites.websiteList do
			if urlText:match(buildSites.websiteList[j].matchURL) then
				self.controls.importCodeIn.text = urlText
				self.importCodeValid = true
				self.importCodeDetail = colorCodes.POSITIVE.."URL is valid ("..buildSites.websiteList[j].label..")"
				self.importCodeSite = j
				if buf ~= urlText then
					self.controls.importCodeIn:SetText(urlText, false)
				end
				return
			end
		end

		-- If we are in dev mode and the string is a json
		if launch.devMode and urlText:match("^%{.*%}$") ~= nil then
			local jsonData, _, errDecode = dkjson.decode(urlText)
			if errDecode then
				self.importCodeDetail = colorCodes.NEGATIVE.."Invalid JSON format (decode error)"
				return
			end
			if not jsonData.character then
				self.importCodeDetail = colorCodes.NEGATIVE.."Invalid JSON format (character missing)"
				return
			end
			jsonData = jsonData.character
			if not jsonData.equipment or not jsonData.passives then
				self.importCodeDetail = colorCodes.NEGATIVE.."Invalid JSON format (equipment or passives missing)"
				return
			end
			self.importCodeJson = jsonData
			self.importCodeDetail = colorCodes.POSITIVE.."JSON is valid"
			self.importCodeValid = true
			return
		end

		local xmlText = Inflate(common.base64.decode(buf:gsub("-","+"):gsub("_","/")))
		if not xmlText then
			return
		end
		if launch.devMode and IsKeyDown("SHIFT") then
			Copy(xmlText)
		end
		self.importCodeValid = true
		self.importCodeDetail = colorCodes.POSITIVE.."Code is valid"
		self.importCodeXML = xmlText
	end

	local importSelectedBuild = function()
		if not self.importCodeValid or self.importCodeFetching then
			return
		end

		if self.controls.importCodeMode.selIndex == 1 then
			main:OpenConfirmPopup("Build Import", colorCodes.WARNING.."Warning:^7 Importing to the current build will erase ALL existing data for this build.", "Import", function()
				self.build:Shutdown()
				self.build:Init(self.build.dbFileName, self.build.buildName, self.importCodeXML, false, self.importCodeSite and self.controls.importCodeIn.buf or nil)
				self.build.viewMode = "TREE"
			end)
		else
			self.build:Shutdown()
			self.build:Init(false, "Imported build", self.importCodeXML, false, self.importCodeSite and self.controls.importCodeIn.buf or nil)
			self.build.viewMode = "TREE"
		end
	end

	self.controls.importCodeIn = new("EditControl", {"TOPLEFT",self.controls.importCodeHeader,"BOTTOMLEFT"}, {0, 4, 328, 20}, "", nil, nil, nil, importCodeHandle, nil, nil, true)
	self.controls.importCodeIn.enterFunc = function()
		if self.importCodeValid then
			self.controls.importCodeGo.onClick()
		end
	end
	self.controls.importCodeState = new("LabelControl", {"LEFT",self.controls.importCodeIn,"RIGHT"}, {8, 0, 0, 16})
	self.controls.importCodeState.label = function()
		return self.importCodeDetail or ""
	end
	self.controls.importCodeMode = new("DropDownControl", {"TOPLEFT",self.controls.importCodeIn,"BOTTOMLEFT"}, {0, 4, 160, 20}, { "Import to this build", "Import to a new build" })
	self.controls.importCodeMode.enabled = function()
		return self.build.dbFileName and self.importCodeValid
	end
	self.controls.importCodeGo = new("ButtonControl", {"LEFT",self.controls.importCodeMode,"RIGHT"}, {8, 0, 160, 20}, "Import", function()
		if self.importCodeSite and not self.importCodeXML then
			self.importCodeFetching = true
			local selectedWebsite = buildSites.websiteList[self.importCodeSite]
			buildSites.DownloadBuild(self.controls.importCodeIn.buf, selectedWebsite, function(isSuccess, data)
				self.importCodeFetching = false
				if not isSuccess then
					self.importCodeDetail = colorCodes.NEGATIVE..data
					self.importCodeValid = false
				else
					importCodeHandle(data)
					importSelectedBuild()
				end
			end)
			return
		end

		if self.importCodeJson then
			self:ImportItemsAndSkills(self.importCodeJson)
			self:ImportPassiveTreeAndJewels(self.importCodeJson)
			return
		end

		importSelectedBuild()
	end)
	self.controls.importCodeGo.label = function ()
		return self.importCodeFetching and "Retrieving paste.." or "Import"
	end
	self.controls.importCodeGo.enabled = function()
		return self.importCodeValid and not self.importCodeFetching
	end
	self.controls.importCodeGo.enterFunc = function()
		if self.importCodeValid then
			self.controls.importCodeGo.onClick()
		end
	end

	-- validate the status of the api the first time
	self.api:ValidateAuth(function(valid, updateSettings)
		if valid then 
			if self.charImportMode == "AUTHENTICATION" then
				self.charImportMode = "GETACCOUNTNAME"
				self.charImportStatus = "Authenticated"
			end
			if updateSettings then
				self:SaveApiSettings()
			end
		else
			self.charImportMode = "AUTHENTICATION"
			self.charImportStatus = colorCodes.WARNING.."Not authenticated"
		end
	end)
end)

function ImportTabClass:SaveApiSettings()
	main.lastToken = self.api.authToken
	main.lastRefreshToken = self.api.refreshToken
	main.tokenExpiry = self.api.tokenExpiry
	main:SaveSettings()
end

function ImportTabClass:Load(xml, fileName)
	self.lastRealm = xml.attrib.lastRealm
	self.controls.accountRealm:SelByValue( self.lastRealm or main.lastRealm or "PC", "id" )
	self.lastAccountHash = xml.attrib.lastAccountHash
	self.importLink = xml.attrib.importLink
	self.controls.enablePartyExportBuffs.state = xml.attrib.exportParty == "true"
	self.build.partyTab.enableExportBuffs = self.controls.enablePartyExportBuffs.state
	if self.lastAccountHash then
		for accountName in pairs(main.gameAccounts) do
			if common.sha1(accountName) == self.lastAccountHash then
				self.controls.accountName:SetText(accountName)
			end
		end
	end
	self.lastCharacterHash = xml.attrib.lastCharacterHash
end

function ImportTabClass:Save(xml)
	xml.attrib = {
		lastRealm = self.lastRealm,
		lastAccountHash = self.lastAccountHash,
		lastCharacterHash = self.lastCharacterHash,
		exportParty = tostring(self.controls.enablePartyExportBuffs.state),
		importLink = self.importLink
	}

	if self.build.importLink then
		xml.attrib.importLink = self.build.importLink
	end
	-- Gets rid of erroneous, potentially infinitely nested full base64 XML stored as an import link
	xml.attrib.importLink = (xml.attrib.importLink and xml.attrib.importLink:len() < 100) and xml.attrib.importLink or nil 
end

function ImportTabClass:Draw(viewPort, inputEvents)
	self.x = viewPort.x
	self.y = viewPort.y
	self.width = viewPort.width
	self.height = viewPort.height

	self:ProcessControlsInput(inputEvents, viewPort)

	main:DrawBackground(viewPort)

	self:DrawControls(viewPort)
end

function ImportTabClass:DownloadCharacterList()
	self.charImportMode = "DOWNLOADCHARLIST"
	self.charImportStatus = "Retrieving character list..."
	local realm = realmList[self.controls.accountRealm.selIndex]
	self.api:DownloadCharacterList(realm.realmCode, function(body, errMsg, updateSettings)
		if updateSettings then
			self:SaveApiSettings()
		end
		if errMsg == self.api.ERROR_NO_AUTH then
			self.charImportMode = "AUTHENTICATION"
			self.charImportStatus = colorCodes.WARNING.."Not authenticated"
			return
		elseif errMsg == "Response code: 401" then
			self.charImportStatus = colorCodes.NEGATIVE.."Sign-in is required."
			self.charImportMode = "GETSESSIONID"
			return
		elseif errMsg == "Response code: 403" then
			self.charImportStatus = colorCodes.NEGATIVE.."Account profile is private."
			self.charImportMode = "GETSESSIONID"
			return
		elseif errMsg == "Response code: 404" then
			self.charImportStatus = colorCodes.NEGATIVE.."Account name is incorrect."
			self.charImportMode = "GETACCOUNTNAME"
			return
		elseif errMsg == "Response code: 429" then
			self.charImportStatus = function() return colorCodes.NEGATIVE.."Requests are being sent too fast, try again in " .. tostring(m_max(0, body - os.time())) .. " seconds." end
			self.charImportMode = "GETACCOUNTNAME"
			return
		elseif errMsg then
			self.charImportStatus = colorCodes.NEGATIVE.."Error retrieving character list, try again ("..errMsg:gsub("\n"," ")..")"
			self.charImportMode = "GETACCOUNTNAME"
			return
		end
		local charList, _pos, errDecode = dkjson.decode(body)
		if errDecode then
			self.charImportStatus = colorCodes.NEGATIVE.."Error processing character list, try again later"
			self.charImportMode = "GETACCOUNTNAME"
			return
		end
		charList = charList.characters
		--ConPrintTable(charList)
		if #charList == 0 then
			self.charImportStatus = colorCodes.NEGATIVE.."The account has no characters to import."
			self.charImportMode = "GETACCOUNTNAME"
			return
		end

		self.charImportStatus = "Character list successfully retrieved."
		self.charImportMode = "SELECTCHAR"
		self.lastRealm = realm.id
		main.lastRealm = realm.id
		local leagueList = { }
		for i, char in ipairs(charList) do
			-- validate if the class have internal class
			if self.build.latestTree.internalAscendNameMap[char.class] ~= nil then
				char.class = self.build.latestTree.internalAscendNameMap[char.class].ascendClass.name
			end
			if not isValueInArray(leagueList, char.league) then
				t_insert(leagueList, char.league)
			end
		end
		table.sort(leagueList)
		wipeTable(self.controls.charSelectLeague.list)
		for _, league in ipairs(leagueList) do
			t_insert(self.controls.charSelectLeague.list, {
				label = league,
				league = league,
			})
		end
		t_insert(self.controls.charSelectLeague.list, {
			label = "All",
		})
		if self.controls.charSelectLeague.selIndex > #self.controls.charSelectLeague.list then
			self.controls.charSelectLeague.selIndex = 1
		end
		self.lastCharList = charList
		self:BuildCharacterList(self.controls.charSelectLeague:GetSelValueByKey("league"))
	end)
end

function ImportTabClass:BuildCharacterList(league)
	wipeTable(self.controls.charSelect.list)
	for i, char in ipairs(self.lastCharList) do
		if not league or char.league == league then
			charLvl = char.level or 0
			charLeague = char.league or "?"
			charName = char.name or "?"
			charClass = char.class or "?"

			classColor = colorCodes.DEFAULT
			if charClass ~= "?" then
				local tree = main:LoadTree(latestTreeVersion .. (char.league:match("Ruthless") and "_ruthless" or ""))
				classColor = colorCodes[charClass:upper()] or colorCodes[tree.ascendNameMap[charClass].class.name:upper()] or "^7"
			end

			local detail
			if league == nil then
				detail = string.format("%s%s ^x808080lvl %d in %s", classColor, charClass, charLvl, charLeague)
			else
				detail = string.format("%s%s ^x808080lvl %d", classColor, charClass, charLvl)
			end
			t_insert(self.controls.charSelect.list, {
				label = charName,
				char = char,
				searchFilter = charName.." "..charClass,
				detail = detail
			})
		end
	end
	table.sort(self.controls.charSelect.list, function(a,b)
		return a.char.name:lower() < b.char.name:lower()
	end)
	self.controls.charSelect.selIndex = 1
	if self.lastCharacterHash then
		for i, char in ipairs(self.controls.charSelect.list) do
			if common.sha1(char.char.name) == self.lastCharacterHash then
				self.controls.charSelect.selIndex = i
				break
			end
		end
	end
end

function ImportTabClass:DownloadCharacter(callback)
	self.charImportMode = "IMPORTING"
	self.charImportStatus = "Retrieving character data..."
	local realm = realmList[self.controls.accountRealm.selIndex]
	local charSelect = self.controls.charSelect
	local charData = charSelect.list[charSelect.selIndex].char
	self.api:DownloadCharacter(realm.realmCode, charData.name, function(body, errMsg, updateSettings)
		self.charImportMode = "SELECTCHAR"
		if updateSettings then
			self:SaveApiSettings()
		end
		if errMsg then
			if errMsg == self.api.ERROR_NO_AUTH then
				self.charImportMode = "AUTHENTICATION"
				self.charImportStatus = colorCodes.WARNING.."Not authenticated"
				return
			elseif errMsg == "Response code: 429" then
				self.charImportStatus = function() return colorCodes.NEGATIVE.."Requests are being sent too fast, try again in " .. tostring(m_max(0, body - os.time())) .. " seconds." end
				self.charImportMode = "GETACCOUNTNAME"
				return
			else
				self.charImportStatus = colorCodes.NEGATIVE.."Error importing character data, try again ("..errMsg:gsub("\n"," ")..")"
				return
			end
		elseif body == "false" then
			self.charImportStatus = colorCodes.NEGATIVE.."Failed to retrieve character data, try again."
			return
		end
		self.lastCharacterHash = common.sha1(charData.name)
		--local out = io.open("get-passive-skills.json", "w")
		--out:write(json)
		--out:close()
		local fullCharData, _pos, errParsing = dkjson.decode(body)
		--local out = io.open("get-passive-skills.json", "w")
		--writeLuaTable(out, charPassiveData, 1)
		--out:close()

		if errParsing then
			self.charImportStatus = colorCodes.NEGATIVE.."Error processing character data, try again later."
			return
		end
		fullCharData = fullCharData.character
		charSelect.list[charSelect.selIndex].char = fullCharData
		callback(fullCharData)
	end)
end

function ImportTabClass:DownloadPassiveTree()
	self:DownloadCharacter(function(charData)
		self:ImportPassiveTreeAndJewels(charData)
	end)
end

function ImportTabClass:DownloadItems()
	self:DownloadCharacter(function(charData)
		self:ImportItemsAndSkills(charData)
	end)
end

function ImportTabClass:ImportPassiveTreeAndJewels(charData)
	local charPassiveData = charData.passives
	self.charImportStatus = colorCodes.POSITIVE.."Passive tree and jewels successfully imported."
	self.build.spec.jewel_data = copyTable(charPassiveData.jewel_data)
	--ConPrintTable(charPassiveData)
	if self.controls.charImportTreeClearJewels.state then
		for _, slot in pairs(self.build.itemsTab.slots) do
			if slot.selItemId ~= 0 and slot.nodeId then
				self.build.itemsTab.build.spec.ignoreAllocatingSubgraph = true -- ignore allocated cluster nodes on Import when Delete Jewel is true, clean slate
				self.build.itemsTab:DeleteItem(self.build.itemsTab.items[slot.selItemId])
			end
		end
	end
	for _, itemData in ipairs(charData.jewels) do
		self:ImportItem(itemData)
	end
	self.build.itemsTab:PopulateSlots()
	self.build.itemsTab:AddUndoState()

	local hashes = copyTable(charPassiveData.hashes, true)
	local weaponSets = {}
	for setName, nodesId in pairs(charPassiveData.specialisations) do
		local weaponSet = tonumber(setName:match("^set(%d)"))
		for _, nodeId in ipairs(nodesId) do
			weaponSets[nodeId] = weaponSet
			t_insert(hashes, nodeId)
		end
	end

	self.build.spec:ImportFromNodeList(charData.class, nil, nil, charPassiveData.alternate_ascendancy or 0, hashes, weaponSets, {}, charPassiveData.mastery_effects or {}, latestTreeVersion .. (charData.league:match("Ruthless") and "_ruthless" or ""))

	-- workaround to update the ui to last option
	self.build.treeTab.controls.versionSelect.selIndex = #self.build.treeTab.treeVersions
	-- attributes nodes
	for skillId, nodeInfo in pairs(charPassiveData.skill_overrides) do
		local changeAttributeId = 0
		if nodeInfo.name == "Intelligence" then
			changeAttributeId = 3
		elseif nodeInfo.name == "Dexterity" then
			changeAttributeId = 2
		elseif nodeInfo.name == "Strength" then
			changeAttributeId = 1
		end

		if changeAttributeId > 0 then
			local id = tonumber(skillId)
			self.build.spec:SwitchAttributeNode(id, changeAttributeId)
			local node = self.build.spec.nodes[id]

			if node then
				self.build.spec:ReplaceNode(node, self.build.spec.hashOverrides[id])
			end
		end
	end

	self.build.spec:AddUndoState()
	self.build.characterLevel = charData.level
	self.build.characterLevelAutoMode = false
	self.build.configTab:UpdateLevel()
	self.build.controls.characterLevel:SetText(charData.level)
	self.build:EstimatePlayerProgress()
	local resistancePenaltyIndex = 7
	if self.build.Act then -- Estimate resistance penalty setting based on act progression estimate
		if type(self.build.Act) == "string" and self.build.Act == "Endgame" then resistancePenaltyIndex = 7
		elseif type(self.build.Act) == "number" then 
			if self.build.Act > 6 then resistancePenaltyIndex = 7
			elseif self.build.Act < 1 then resistancePenaltyIndex = 1
			else resistancePenaltyIndex = self.build.Act end
		end
	end
	self.build.configTab.varControls["resistancePenalty"]:SetSel(resistancePenaltyIndex)
	self.build.buildFlag = true
	main:SetWindowTitleSubtext(string.format("%s (%s, %s, %s)", self.build.buildName, charData.name, charData.class, charData.league))
end

function ImportTabClass:ImportItemsAndSkills(charData)
	local charItemData = charData.equipment
	if self.controls.charImportItemsClearItems.state then
		for _, slot in pairs(self.build.itemsTab.slots) do
			if slot.selItemId ~= 0 and not slot.nodeId then
				self.build.itemsTab:DeleteItem(self.build.itemsTab.items[slot.selItemId])
			end
		end
	end

	local mainSkillEmpty = #self.build.skillsTab.socketGroupList == 0
	local skillOrder
	if self.controls.charImportItemsClearSkills.state then
		skillOrder = { }
		for _, socketGroup in ipairs(self.build.skillsTab.socketGroupList) do
			for _, gem in ipairs(socketGroup.gemList) do
				if gem.grantedEffect and not gem.grantedEffect.support then
					t_insert(skillOrder, gem.grantedEffect.name)
				end
			end
		end
		wipeTable(self.build.skillsTab.socketGroupList)
	end
	self.charImportStatus = colorCodes.POSITIVE.."Items and skills successfully imported."
	--ConPrintTable(charItemData)
	for _, itemData in ipairs(charItemData) do
		self:ImportItem(itemData)
	end

	local funcGetGemInstance = function(skillData)
		local typeLine = sanitiseText(skillData.typeLine) .. (skillData.support and " Support" or "")
		local gemId = self.build.data.gemForBaseName[typeLine:lower()]
		
		if typeLine:match("^Spectre:") then
			gemId = "Metadata/Items/Gems/SkillGemSummonSpectre"
		end		
		if typeLine:match("^Companion:") then
			gemId = "Metadata/Items/Gems/SkillGemSummonBeast"
		end

		if gemId then
			local gemInstance = { level = 20, quality = 0, enabled = true, enableGlobal1 = true, enableGlobal2 = true, count = 1,  gemId = gemId }
			gemInstance.support = skillData.support

			local spectreList = data.spectres
			if typeLine:sub(1, 8) == "Spectre:" then
				local spectreName = typeLine:sub(10) -- gets monster name after "Spectre: "
				for _, property in pairs(skillData.properties) do
					if property.name == "Reservation" and property.values and property.values[1] and property.values[1][1] then
						-- Example: "42 [Spirit]"
						local reservationValue = property.values[1][1]:match("(%d+)")
						if reservationValue then
							gemInstance.reservation = tonumber(reservationValue)
						end
					end
				end
				for id, spectre in pairs(spectreList) do
					if spectre.name == spectreName and gemInstance.reservation == spectre.spectreReservation then
						if not isValueInArray(self.build.spectreList, id) then
							t_insert(self.build.spectreList, id)
						end
						gemInstance.skillMinion = id -- Sets imported minion in dropdown on left
						gemInstance.skillMinionCalcs = id-- Sets imported minion in dropdown in calcs tab
						break
					end
				end
			end
			if typeLine:sub(1, 10) == "Companion:" then
				local companionName = typeLine:sub(12)
				for _, property in pairs(skillData.properties) do
					if property.name == "Reservation" and property.values and property.values[1] and property.values[1][1] then
						-- Example: "42.3% [Spirit]"
						local companionReservation = property.values[1][1]:match("([%d%.]+)%%?")
						if companionReservation then
							gemInstance.companionReservation = tonumber(companionReservation)
						end
					end
				end
				for id, spectre in pairs(spectreList) do
					if spectre.name == companionName and gemInstance.companionReservation == spectre.companionReservation then
						if not isValueInArray(self.build.beastList, id) then
							t_insert(self.build.beastList, id)
						end
						gemInstance.skillMinion = id
						gemInstance.skillMinionCalcs = id
						break
					end
				end
			end

			gemInstance.nameSpec = self.build.data.gems[gemId].name
			for _, property in pairs(skillData.properties) do
				if property.name == "Level" then
					if skillData.properties[_ + 1] and skillData.properties[_ + 1].values[1][1]:match("(%d+) Level[s]? from Gem") then
						gemInstance.level = tonumber(skillData.properties[_ + 1].values[1][1]:match("(%d+) Level[s]? from Gem"))
					else
						gemInstance.level = tonumber(property.values[1][1]:match("%d+"))
					end
					if skillData.properties[_ + 2] and skillData.properties[_ + 2].values[1][1]:match("(%d+) Level[s]? from Corruption") then
						gemInstance.level = gemInstance.level + tonumber(skillData.properties[_ + 2].values[1][1]:match("(%d+) Level[s]? from Corruption"))
					end
				elseif escapeGGGString(property.name) == "Quality" then
					gemInstance.quality = tonumber(property.values[1][1]:match("%d+"))
				end
			end

			return gemInstance
		end
		return nil
	end
	for _, skillData in pairs(charData.skills) do
		local gemInstance = funcGetGemInstance(skillData)
		
		if gemInstance then
			local group = { label = "", enabled = true, gemList = { } }
			t_insert(group.gemList, gemInstance )

			if skillData.socketedItems then
				for _, anotherSkillData in pairs(skillData.socketedItems) do
					local anotherGemInstance = funcGetGemInstance(anotherSkillData)
					if anotherGemInstance then
						t_insert(group.gemList, anotherGemInstance )
					end
				end
			end

			t_insert(self.build.skillsTab.socketGroupList, group)
			self.build.skillsTab:ProcessSocketGroup(group)
		end
	end

	if skillOrder then
		local groupOrder = { }
		for index, socketGroup in ipairs(self.build.skillsTab.socketGroupList) do
			groupOrder[socketGroup] = index
		end
		table.sort(self.build.skillsTab.socketGroupList, function(a, b)
			local orderA
			for _, gem in ipairs(a.gemList) do
				if gem.grantedEffect and not gem.grantedEffect.support then
					local i = isValueInArray(skillOrder, gem.grantedEffect.name)
					if i and (not orderA or i < orderA) then
						orderA = i
					end
				end
			end
			local orderB
			for _, gem in ipairs(b.gemList) do
				if gem.grantedEffect and not gem.grantedEffect.support then
					local i = isValueInArray(skillOrder, gem.grantedEffect.name)
					if i and (not orderB or i < orderB) then
						orderB = i
					end
				end
			end
			if orderA and orderB then
				if orderA ~= orderB then
					return orderA < orderB
				else
					return groupOrder[a] < groupOrder[b]
				end
			elseif not orderA and not orderB then
				return groupOrder[a] < groupOrder[b]
			else
				return orderA
			end
		end)
	end
	if mainSkillEmpty then
		self.build.mainSocketGroup = self:GuessMainSocketGroup()
	end
	self.build.itemsTab:PopulateSlots()
	self.build.itemsTab:AddUndoState()
	self.build.skillsTab:AddUndoState()
	self.build.characterLevel = charData.level
	self.build.configTab:UpdateLevel()
	self.build.controls.characterLevel:SetText(charData.level)
	self.build.buildFlag = true
	return charData -- For the wrapper
end

local rarityMap = { [0] = "NORMAL", "MAGIC", "RARE", "UNIQUE", [9] = "RELIC", [10] = "RELIC" }
local slotMap = { ["Weapon"] = "Weapon 1", ["Offhand"] = "Weapon 2", ["Weapon2"] = "Weapon 1 Swap", ["Offhand2"] = "Weapon 2 Swap", ["Helm"] = "Helmet", ["BodyArmour"] = "Body Armour", ["Gloves"] = "Gloves", ["Boots"] = "Boots", ["Amulet"] = "Amulet", ["Ring"] = "Ring 1", ["Ring2"] = "Ring 2", ["Ring3"] = "Ring 3", ["Belt"] = "Belt" }

function ImportTabClass:ImportItem(itemData, slotName)
	if not slotName then
		if itemData.inventoryId == "PassiveJewels" then
			slotName = "Jewel ".. self.build.latestTree.jewelSlots[itemData.x + 1]
		elseif itemData.inventoryId == "Flask" then
			if itemData.x > 1 then
				slotName = "Charm " .. (itemData.x - 1)
			else
				slotName = "Flask "..(itemData.x + 1)
			end
		elseif not (self.controls.charImportItemsIgnoreWeaponSwap.state and (itemData.inventoryId == "Weapon2" or itemData.inventoryId == "Offhand2")) then
			slotName = slotMap[itemData.inventoryId]
		end
	end
	if not slotName then
		-- Ignore any items that won't go into known slots
		return
	end

	local item = new("Item")

	-- Determine rarity, display name and base type of the item
	item.rarity = rarityMap[itemData.frameType]
	if #itemData.name > 0 then
		item.title = sanitiseText(itemData.name)
		item.baseName = sanitiseText(itemData.typeLine):gsub("Synthesised ","")
		item.name = item.title .. ", " .. item.baseName
		if item.baseName == "Two-Toned Boots" then
			-- Hack for Two-Toned Boots
			item.baseName = "Two-Toned Boots (Armour/Energy Shield)"
		end
		item.base = self.build.data.itemBases[item.baseName]
		if item.base then
			item.type = item.base.type
		else
			ConPrintf("Unrecognised base in imported item: %s", item.baseName)
		end
	else
		item.name = sanitiseText(itemData.typeLine)
		if item.name:match("Energy Blade") then
			local oneHanded = false
			for _, p in ipairs(itemData.properties) do
				if self.build.data.weaponTypeInfo[p.name] and self.build.data.weaponTypeInfo[p.name].oneHand then
					oneHanded = true
					break
				end
			end
			item.name = oneHanded and "Energy Blade One Handed" or "Energy Blade Two Handed"
			item.rarity = "NORMAL"
			itemData.implicitMods = { }
			itemData.explicitMods = { }
		end
		for baseName, baseData in pairs(self.build.data.itemBases) do
			local s, e = item.name:find(baseName, 1, true)
			if s then
				item.baseName = baseName
				item.namePrefix = item.name:sub(1, s - 1)
				item.nameSuffix = item.name:sub(e + 1)
				item.type = baseData.type
				break
			end
		end
		if not item.baseName then
			local s, e = item.name:find("Two-Toned Boots", 1, true)
			if s then
				-- Hack for Two-Toned Boots
				item.baseName = "Two-Toned Boots (Armour/Energy Shield)"
				item.namePrefix = item.name:sub(1, s - 1)
				item.nameSuffix = item.name:sub(e + 1)
				item.type = "Boots"
			end
		end
		item.base = self.build.data.itemBases[item.baseName]
	end
	if not item.base or not item.rarity then
		return
	end

	-- Import item data
	item.uniqueID = itemData.id
	if itemData.ilvl > 0 then
		item.itemLevel = itemData.ilvl
	end
	if item.base.quality then
		item.quality = 0
	end
	if itemData.properties then
		for _, property in pairs(itemData.properties) do
			if escapeGGGString(property.name) == "Quality" then
				item.quality = tonumber(property.values[1][1]:match("%d+"))
			elseif property.name == "Radius" then
				item.jewelRadiusLabel = property.values[1][1]
			elseif property.name == "Limited to" then
				item.limit = tonumber(property.values[1][1])
			elseif property.name == "Evasion Rating" then
				if item.baseName == "Two-Toned Boots (Armour/Energy Shield)" then
					-- Another hack for Two-Toned Boots
					item.baseName = "Two-Toned Boots (Armour/Evasion)"
					item.base = self.build.data.itemBases[item.baseName]
				end
			elseif property.name == "Energy Shield" then
				if item.baseName == "Two-Toned Boots (Armour/Evasion)" then
					-- Yet another hack for Two-Toned Boots
					item.baseName = "Two-Toned Boots (Evasion/Energy Shield)"
					item.base = self.build.data.itemBases[item.baseName]
				end
			end
			if property.name == "Energy Shield" or property.name == "Ward" or property.name == "Armour" or property.name == "Evasion Rating" then
				item.armourData = item.armourData or { }
				for _, value in ipairs(property.values) do
					item.armourData[property.name:gsub(" Rating", ""):gsub(" ", "")] = (item.armourData[property.name:gsub(" Rating", ""):gsub(" ", "")] or 0) + tonumber(value[1])
				end
			end
		end
	end
	item.mirrored = itemData.mirrored
	item.corrupted = itemData.corrupted
	item.fractured = itemData.fractured
	item.desecrated = itemData.desecrated
	if itemData.sockets and itemData.sockets[1] then
		item.sockets = { }
		item.itemSocketCount = 0
		for i, socket in pairs(itemData.sockets) do
			item.sockets[i] = { }
			item.itemSocketCount = item.itemSocketCount + 1
		end
	end

	item.runes = { }
	if itemData.socketedItems then
		self:ImportSocketedItems(item, itemData.socketedItems, slotName)
	end
	if itemData.requirements and (not itemData.socketedItems or not itemData.socketedItems[1]) then
		-- Requirements cannot be trusted if there are socketed gems, as they may override the item's natural requirements
		item.requirements = { }
		for _, req in ipairs(itemData.requirements) do
			if req.name == "Level" then
				item.requirements.level = req.values[1][1]
			elseif req.name == "Class:" then
				item.classRestriction = req.values[1][1]
			elseif req.name == "Charm Slots:" then
				item.charmLimit = req.values[1][1]
			end
		end
	end
	item.enchantModLines = { }
	item.runeModLines = { }
	item.classRequirementModLines = { }
	item.implicitModLines = { }
	item.explicitModLines = { }
	if itemData.enchantMods then
		for _, line in ipairs(itemData.enchantMods) do
			for line in line:gmatch("[^\n]+") do
				local modList, extra = modLib.parseMod(line)
				t_insert(item.enchantModLines, { line = line, extra = extra, mods = modList or { }, enchant = true })
			end
		end
	end
	if itemData.runeMods then
		for _, line in ipairs(itemData.runeMods) do
			for line in line:gmatch("[^\n]+") do
				local modList, extra = modLib.parseMod(line)
				t_insert(item.runeModLines, { line = line, extra = extra, mods = modList or { }, enchant = true, rune = true })
			end
		end
	end
	if itemData.implicitMods then
		for _, line in ipairs(itemData.implicitMods) do
			for line in line:gmatch("[^\n]+") do
				local modList, extra = modLib.parseMod(line)
				t_insert(item.implicitModLines, { line = line, extra = extra, mods = modList or { } })
			end
		end
	end
	if itemData.fracturedMods then
		for _, line in ipairs(itemData.fracturedMods) do
			for line in line:gmatch("[^\n]+") do
				local modList, extra = modLib.parseMod(line)
				t_insert(item.explicitModLines, { line = line, extra = extra, mods = modList or { }, fractured = true })
			end
		end
	end
	if itemData.explicitMods then
		for _, line in ipairs(itemData.explicitMods) do
			for line in line:gmatch("[^\n]+") do
				local modList, extra = modLib.parseMod(line)
				t_insert(item.explicitModLines, { line = line, extra = extra, mods = modList or { } })
			end
		end
	end
	if itemData.desecratedMods then
		for _, line in ipairs(itemData.desecratedMods) do
			for line in line:gmatch("[^\n]+") do
				local modList, extra = modLib.parseMod(line)
				t_insert(item.explicitModLines, { line = line, extra = extra, mods = modList or { }, desecrated = true })
			end
		end
	end

	if itemData.grantedSkills then
		for _, grantedSkillInfo in ipairs(itemData.grantedSkills) do
			local level = grantedSkillInfo.values and #grantedSkillInfo.values > 0 and #grantedSkillInfo.values[1] > 0 and grantedSkillInfo.values[1][1] or "unknown"
			local grantedSkills =  string.format(
				"%s: %s",
				grantedSkillInfo.name,
				level
			)
			local modList, extra = modLib.parseMod(grantedSkills)
			t_insert(item.implicitModLines, { line = grantedSkills, extra = extra, mods = modList or { } })
		end
	end

	-- Sometimes flavour text has actual mods that PoB cares about
	-- Right now, the only known one is "This item can be anointed by Cassia"
	if itemData.flavourText then
		for _, line in ipairs(itemData.flavourText) do
			for line in line:gmatch("[^\n]+") do
				-- Remove any text outside of curly braces, if they exist.
				-- This fixes lines such as:
				--   "<default>{This item can be anointed by Cassia}"
				-- To now be:
				--   "This item can be anointed by Cassia"
				local startBracket = line:find("{")
				local endBracket = line:find("}")
				if startBracket and endBracket and endBracket > startBracket then
					line = line:sub(startBracket + 1, endBracket - 1)
				end

				-- If the line parses, then it should be included as an explicit mod
				local modList, extra = modLib.parseMod(line)
				if modList then
					t_insert(item.explicitModLines, { line = line, extra = extra, mods = modList or { } })
				end
			end
		end
	end

	-- Add and equip the new item
	item:BuildAndParseRaw()
	--ConPrintf("%s", item.raw)
	if item.base then
		local repIndex, repItem
		for index, item in pairs(self.build.itemsTab.items) do
			if item.uniqueID == itemData.id then
				repIndex = index
				repItem = item
				break
			end
		end
		if repIndex then
			-- Item already exists in the build, overwrite it
			item.id = repItem.id
			self.build.itemsTab.items[item.id] = item
			item:BuildModList()
		else
			self.build.itemsTab:AddItem(item, true)
		end
		if self.build.itemsTab.slots[slotName] then
			self.build.itemsTab.slots[slotName]:SetSelItemId(item.id)
		else
			ConPrintf("Unrecognised slot name in imported item: %s", slotName)
		end
	end
end

function ImportTabClass:ImportSocketedItems(item, socketedItems, slotName)
	-- Build socket group list
	for _, socketedItem in ipairs(socketedItems) do
		t_insert(item.runes, socketedItem.baseType)
	end
end

-- Return the index of the group with the most gems
function ImportTabClass:GuessMainSocketGroup()
	local largestGroupSize = 0
	local largestGroupIndex = 1
	for i, socketGroup in ipairs(self.build.skillsTab.socketGroupList) do
		if #socketGroup.gemList > largestGroupSize then
			largestGroupSize = #socketGroup.gemList
			largestGroupIndex = i
		end
	end
	return largestGroupIndex
end

function HexToChar(x)
	return string.char(tonumber(x, 16))
end

function UrlDecode(url)
	if url == nil then
		return
	end
	url = url:gsub("+", " ")
	url = url:gsub("%%(%x%x)", HexToChar)
	return url
end