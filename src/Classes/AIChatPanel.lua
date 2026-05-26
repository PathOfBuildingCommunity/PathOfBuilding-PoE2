-- Path of Building
--
-- Class: AI Chat Panel
-- Right-side AI assistant drawer for the build editor.

local t_insert = table.insert
local t_remove = table.remove
local m_min = math.min
local m_max = math.max
local m_floor = math.floor
local utf8 = require("lua-utf8")

local settingsStore = LoadModule("AI/Settings")
local providers = LoadModule("AI/ProviderPresets")
local aiClient = LoadModule("AI/AIClient")
local buildSnapshot = LoadModule("AI/BuildSnapshot")

local AIChatPanelClass = newClass("AIChatPanel", "ControlHost", function(self, build)
	self.ControlHost()
	self.build = build
	self.settings = settingsStore.Load()
	self.messages = { }
	self.history = { }
	self.messageRows = { }
	self.pending = false
	self.collapsed = false
	self.statusText = "Ready"
	self.currentSnapshot = nil

	self.anchor = new("Control", nil, {
		function()
			return main.screenW - self:GetWidth()
		end,
		32,
		0,
		0,
	})

	self.controls.toggle = new("ButtonControl", { "TOPLEFT", self.anchor, "TOPLEFT" }, { 6, 6, 28, 22 }, function()
		return self.collapsed and "AI" or "<"
	end, function()
		self.collapsed = not self.collapsed
	end)
	self.controls.toggle.tooltipText = "Show or hide the AI assistant"

	self.controls.settings = new("ButtonControl", { "TOPRIGHT", self.anchor, "TOPLEFT" }, {
		function()
			return self:GetWidth() - 8
		end,
		6,
		70,
		22,
	}, "Settings", function()
		self:OpenSettingsPopup()
	end)
	self.controls.settings.shown = function()
		return not self.collapsed
	end

	self.controls.analyze = new("ButtonControl", { "TOPLEFT", self.anchor, "TOPLEFT" }, { 8, 42, 160, 24 }, "Analyze Current Build", function()
		self:AnalyzeBuild()
	end)
	self.controls.analyze.shown = function()
		return not self.collapsed
	end
	self.controls.analyze.enabled = function()
		return not self.pending
	end

	self.controls.clear = new("ButtonControl", { "TOPRIGHT", self.anchor, "TOPLEFT" }, {
		function()
			return self:GetWidth() - 8
		end,
		42,
		52,
		24,
	}, "Clear", function()
		self.messages = { }
		self.history = { }
		self.currentSnapshot = nil
		self:UpdateMessageRows()
	end)
	self.controls.clear.shown = function()
		return not self.collapsed
	end
	self.controls.clear.enabled = function()
		return not self.pending and #self.messages > 0
	end

	self.controls.messages = new("TextListControl", { "TOPLEFT", self.anchor, "TOPLEFT" }, { 8, 92, 0, 0 }, { { x = 4, align = "LEFT" } }, self.messageRows)
	self.controls.messages.width = function()
		return self:GetWidth() - 16
	end
	self.controls.messages.height = function()
		return m_max(80, main.screenH - 32 - 92 - 40)
	end
	self.controls.messages.shown = function()
		return not self.collapsed
	end

	self.controls.input = new("EditControl", { "TOPLEFT", self.anchor, "TOPLEFT" }, {
		8,
		function()
			return main.screenH - 32 - 30
		end,
		function()
			return m_max(120, self:GetWidth() - 70)
		end,
		24,
	}, "", "Ask a question...", "%c", 1000, nil, nil, nil, true)
	self.controls.input.shown = function()
		return not self.collapsed
	end
	self.controls.input.enabled = function()
		return not self.pending
	end

	self.controls.send = new("ButtonControl", { "LEFT", self.controls.input, "RIGHT" }, { 6, 0, 50, 24 }, "Send", function()
		self:SendUserMessage()
	end)
	self.controls.send.shown = function()
		return not self.collapsed
	end
	self.controls.send.enabled = function()
		return not self.pending and self.controls.input.buf and self.controls.input.buf:match("%S") ~= nil
	end

	self:AddMessage("system", "Configure an OpenAI-compatible API, then click Analyze Current Build. The assistant only gives advice and will not modify your build.")
end)

function AIChatPanelClass:GetWidth()
	if self.collapsed then
		return 40
	end
	local desired = m_min(420, m_max(340, m_floor((main.screenW or 1280) * 0.28)))
	if main and main.screenW then
		local maxWidth = main.screenW - 312 - 300
		if maxWidth < 260 then
			maxWidth = m_max(240, main.screenW - 312 - 220)
		end
		desired = m_min(desired, maxWidth)
	end
	return m_max(240, desired)
end

function AIChatPanelClass:GetViewport()
	local width = self:GetWidth()
	return {
		x = main.screenW - width,
		y = 32,
		width = width,
		height = main.screenH - 32,
	}
end

local function cleanText(text)
	text = tostring(text or "")
	if StripEscapes then
		text = StripEscapes(text)
	end
	text = text:gsub("\r\n", "\n"):gsub("\r", "\n")
	text = text:gsub("%^x%x%x%x%x%x%x", "")
	text = text:gsub("%^%d", "")
	text = text:gsub("%^%a", "")
	return text
end

local function utf8Len(text)
	local ok, len = pcall(utf8.len, text)
	if ok and len then
		return len
	end
	return #text
end

local function utf8Sub(text, first, last)
	local ok, out = pcall(utf8.sub, text, first, last)
	if ok and out then
		return out
	end
	return text:sub(first, last)
end

local function stripInlineMarkdown(text)
	text = tostring(text or "")
	text = text:gsub("`([^`]*)`", "%1")
	text = text:gsub("%*%*(.-)%*%*", "%1")
	text = text:gsub("__(.-)__", "%1")
	text = text:gsub("%*([^%*]-)%*", "%1")
	text = text:gsub("_([^_]-)_", "%1")
	return text
end

local function trimText(text)
	return tostring(text or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

local function normalizeMessageLines(text)
	local out = { }
	text = cleanText(text)
	for rawLine in (text .. "\n"):gmatch("([^\n]*)\n") do
		local line = trimText(rawLine)
		if line:match("^```") then
			-- Drop code fences; keep following lines as plain text.
		elseif line == "" then
			t_insert(out, { kind = "blank", text = "" })
		else
			local compact = line:gsub("%s+", "")
			if #compact >= 3 and compact:match("^[-_=%*]+$") then
				t_insert(out, { kind = "blank", text = "" })
			else
				line = line:gsub("^>%s*", "")
				line = stripInlineMarkdown(line)
				local heading = line:match("^#+%s*(.+)$")
				if heading then
					t_insert(out, { kind = "heading", text = trimText(stripInlineMarkdown(heading)) })
				else
					line = line:gsub("^%s*[%-%*%+]%s+", "- ")
					line = line:gsub("^%s*(%d+)[%.)]%s+", "%1. ")
					if line:find("|", 1, true) then
						line = line:gsub("^%s*|", ""):gsub("|%s*$", ""):gsub("%s*|%s*", " / ")
					end
					line = line:gsub("```", "")
					t_insert(out, { kind = "body", text = trimText(line) })
				end
			end
		end
	end
	return out
end

local function wrapLine(text, width, fontSize)
	local wrapped = { }
	text = tostring(text or "")
	if text == "" then
		t_insert(wrapped, "")
		return wrapped
	end
	local continuationPrefix = ""
	if text:match("^%- ") then
		continuationPrefix = "  "
	elseif text:match("^%d+%. ") then
		continuationPrefix = "   "
	end
	local line = ""
	local len = utf8Len(text)
	for index = 1, len do
		local ch = utf8Sub(text, index, index)
		local candidate = line .. ch
		if line ~= "" and DrawStringWidth(fontSize, "VAR", candidate) > width then
			t_insert(wrapped, line)
			line = continuationPrefix .. ch
		else
			line = candidate
		end
	end
	if line ~= "" then
		t_insert(wrapped, line)
	end
	return wrapped
end

local function truncateText(text, limit)
	text = tostring(text or "")
	if utf8Len(text) <= limit then
		return text
	end
	return utf8Sub(text, 1, limit) .. "\n[Brief mode omitted part of the build snapshot.]"
end

function AIChatPanelClass:UpdateMessageRows()
	local rows = self.messageRows
	wipeTable(rows)
	local width = m_max(130, self:GetWidth() - 96)
	for _, message in ipairs(self.messages) do
		local name
		local headerColor
		local bodyColor
		if message.role == "assistant" then
			name = "AI Assistant"
			headerColor = colorCodes.CURRENCY
			bodyColor = "^7"
		elseif message.role == "user" then
			name = "You"
			headerColor = colorCodes.MAGIC
			bodyColor = "^7"
		else
			name = "System"
			headerColor = colorCodes.TIP
			bodyColor = "^8"
		end
		t_insert(rows, { height = 18, font = "VAR", headerColor .. name })
		for _, visualLine in ipairs(normalizeMessageLines(message.content)) do
			if visualLine.kind == "blank" then
				t_insert(rows, { height = 6 })
			elseif visualLine.kind == "heading" then
				for _, line in ipairs(wrapLine(visualLine.text, width, 15)) do
					t_insert(rows, { height = 17, font = "VAR", colorCodes.CURRENCY .. line })
				end
			else
				for _, line in ipairs(wrapLine(visualLine.text, width, 14)) do
					t_insert(rows, { height = 16, font = "VAR", bodyColor .. line })
				end
			end
		end
		t_insert(rows, { height = 8 })
	end
	self.controls.messages.controls.scrollBar.offset = 999999
end

function AIChatPanelClass:AddMessage(role, content)
	local message = { role = role, content = content or "" }
	t_insert(self.messages, message)
	while #self.messages > 80 do
		t_remove(self.messages, 1)
	end
	self:UpdateMessageRows()
	return message
end

function AIChatPanelClass:RefreshBuildOutput()
	if self.build and self.build.buildFlag then
		wipeGlobalCache()
		self.build.outputRevision = (self.build.outputRevision or 0) + 1
		self.build.buildFlag = false
		self.build.calcsTab:BuildOutput()
		self.build:RefreshStatList()
	end
end

function AIChatPanelClass:ClassifyReplyMode(userText, forcedMode)
	if forcedMode then
		return forcedMode
	end
	local text = cleanText(userText):lower()
	local briefWords = { "brief", "short", "quick", "one sentence", "summarize", "simple", "tl;dr" }
	for _, word in ipairs(briefWords) do
		if text:find(word, 1, true) then
			return "brief"
		end
	end
	local simpleQuestion = text:match("^%s*what is ") or text:match("^%s*what does ") or text:match("^%s*why is ")
	if simpleQuestion and utf8Len(text) <= 80 then
		return "brief"
	end
	local normalWords = { "detail", "detailed", "analyze", "analysis", "improve", "upgrade", "optimize", "gear", "item", "items", "skill", "skills", "tree", "defense", "defence", "dps", "damage", "resistance", "build", "advice", "check", "why", "how" }
	for _, word in ipairs(normalWords) do
		if text:find(word, 1, true) then
			return "normal"
		end
	end
	return "brief"
end

function AIChatPanelClass:GetSystemPrompt(replyMode)
	local modePrompt
	if replyMode == "analysis" then
		modePrompt = "This is Analyze Current Build mode. Give 3-6 highest-priority findings first, then concise checks. Keep the total answer under 900 words."
	elseif replyMode == "normal" then
		modePrompt = "This is advice mode. Give up to 5 concise suggestions, with the conclusion before the reason. Do not rewrite a full build audit. Keep the total answer under 450 words."
	else
		modePrompt = "This is a normal follow-up question. Prefer 1-3 sentences, or at most 3 short bullets. Unless the user asks, do not expand into a full build analysis. Keep the total answer under 180 words."
	end
	return [[You are a Path of Building for Path of Exile 2 build-analysis assistant.
You only provide analysis, advice, and explanations. Do not claim you modified the build, and do not ask the user to apply automatic changes.
Answer in English. Prioritize main skill links, damage scaling, defensive layers, resistances, accuracy/crit, resource reservation, gear weaknesses, and possibly incorrect configuration settings.
Do not output markdown tables, code blocks, ### headings, **bold markers**, backticks, or long --- dividers. Use short plain-text paragraphs. Lists may use "- " or "1. ".
If the build snapshot is insufficient, say exactly which page or value the user should check.
]] .. modePrompt
end

function AIChatPanelClass:BuildRequestMessages(userText, replyMode)
	local snapshot = self.currentSnapshot or ""
	local contextPrompt = "Current build snapshot:\n"
	if replyMode == "brief" then
		snapshot = truncateText(snapshot, 1800)
		contextPrompt = "Use the current build snapshot only as background. This is a normal follow-up question; unless required, do not re-analyze the whole build.\n"
	elseif replyMode == "normal" then
		snapshot = truncateText(snapshot, 3500)
		contextPrompt = "Current build snapshot. Answer only the user's question with targeted advice; do not output a complete audit report.\n"
	end
	local messages = {
		{ role = "system", content = self:GetSystemPrompt(replyMode) },
		{ role = "user", content = contextPrompt .. snapshot },
	}
	local startIndex = m_max(1, #self.history - 7)
	for index = startIndex, #self.history do
		t_insert(messages, self.history[index])
	end
	t_insert(messages, { role = "user", content = userText })
	return messages
end

function AIChatPanelClass:EnsureConfigured()
	self.settings = settingsStore.Load()
	if settingsStore.IsConfigured(self.settings) then
		return true
	end
	self.statusText = "API not configured"
	self:AddMessage("system", "Open Settings and enter an API base URL, API key, and model name first.")
	self:OpenSettingsPopup()
	return false
end

function AIChatPanelClass:RunAI(userText, displayText, refreshSnapshot, forcedMode)
	if self.pending then
		return
	end
	if not self:EnsureConfigured() then
		return
	end
	local replyMode = self:ClassifyReplyMode(userText, forcedMode)
	if refreshSnapshot or not self.currentSnapshot then
		self:RefreshBuildOutput()
		self.currentSnapshot = buildSnapshot.Create(self.build)
	end
	local requestMessages = self:BuildRequestMessages(userText, replyMode)
	self.pending = true
	self.statusText = "Thinking..."
	self:AddMessage("user", displayText or userText)
	local pendingMessage = self:AddMessage("assistant", "Thinking...")
	t_insert(self.history, { role = "user", content = userText })
	while #self.history > 16 do
		t_remove(self.history, 1)
	end
	aiClient.Send(self.settings, requestMessages, function(content, errMsg)
		self.pending = false
		if content then
			self.statusText = "Done"
			pendingMessage.role = "assistant"
			pendingMessage.content = content
			self:UpdateMessageRows()
			t_insert(self.history, { role = "assistant", content = content })
			while #self.history > 16 do
				t_remove(self.history, 1)
			end
		else
			self.statusText = "Request failed"
			pendingMessage.role = "system"
			pendingMessage.content = "Request failed: " .. tostring(errMsg or "unknown error")
			self:UpdateMessageRows()
		end
	end)
end

function AIChatPanelClass:AnalyzeBuild()
	self:RunAI("Analyze the current build. Start with 3-6 highest-priority conclusions, then list the damage, defense, gear, skills, and configuration checks that matter most.", "Analyze Current Build", true, "analysis")
end

function AIChatPanelClass:SendUserMessage()
	local text = self.controls.input.buf or ""
	text = text:gsub("^%s+", ""):gsub("%s+$", "")
	if text == "" then
		return
	end
	self.controls.input:SetText("")
	self:RunAI(text, text, false)
end

function AIChatPanelClass:GetProviderIndex(providerId)
	for index, provider in ipairs(providers.list) do
		if provider.id == providerId then
			return index
		end
	end
	return #providers.list
end

function AIChatPanelClass:OpenSettingsPopup()
	local data = settingsStore.Load()
	local controls = { }
	local inputX = 170
	local inputW = 500
	local function formLabel(key, y, text)
		controls[key] = new("LabelControl", { "TOPRIGHT", nil, "TOPLEFT" }, { inputX - 12, y, 0, 18 }, "^7" .. text)
	end
	formLabel("providerLabel", 24, "Provider:")
	controls.provider = new("DropDownControl", { "TOPLEFT", nil, "TOPLEFT" }, { inputX, 20, inputW, 22 }, providers.list, function(index, value)
		data.provider = value.id
		data.apiBase = value.apiBase or ""
		data.model = value.model or ""
		controls.apiBase:SetText(data.apiBase)
		controls.model:SetText(data.model)
	end)
	controls.provider.maxDroppedWidth = inputW
	controls.provider.selIndex = self:GetProviderIndex(data.provider)
	formLabel("apiBaseLabel", 62, "API Base URL:")
	controls.apiBase = new("EditControl", { "TOPLEFT", nil, "TOPLEFT" }, { inputX, 58, inputW, 22 }, data.apiBase or "", nil, "%c", 300)
	formLabel("apiKeyLabel", 100, "API Key:")
	controls.apiKey = new("EditControl", { "TOPLEFT", nil, "TOPLEFT" }, { inputX, 96, inputW, 22 }, data.apiKey or "", nil, "%c", 500)
	controls.apiKey:SetProtected(true)
	formLabel("modelLabel", 138, "Model:")
	controls.model = new("EditControl", { "TOPLEFT", nil, "TOPLEFT" }, { inputX, 134, inputW, 22 }, data.model or "", nil, "%c", 160)
	controls.note = new("LabelControl", { "TOPLEFT", nil, "TOPLEFT" }, { inputX, 176, 0, 16 }, "^8Settings are saved locally to AIAssistantSettings.json.")
	controls.save = new("ButtonControl", { "TOPLEFT", nil, "TOPLEFT" }, { 260, 218, 90, 24 }, "Save", function()
		local selected = controls.provider.list[controls.provider.selIndex] or providers.list[#providers.list]
		data.provider = selected.id
		data.apiBase = controls.apiBase.buf
		data.apiKey = controls.apiKey.buf
		data.model = controls.model.buf
		data.temperature = tonumber(data.temperature) or 0.2
		local ok, err = settingsStore.Save(data)
		if ok then
			self.settings = settingsStore.Load()
			self.statusText = "Settings saved"
			main:ClosePopup()
		else
			main:OpenMessagePopup("AI Settings Save Failed", tostring(err))
		end
	end)
	controls.cancel = new("ButtonControl", { "TOPLEFT", nil, "TOPLEFT" }, { 370, 218, 90, 24 }, "Cancel", function()
		main:ClosePopup()
	end)
	main:OpenPopup(720, 268, "AI Assistant Settings", controls, "save", "apiKey", "cancel")
end

function AIChatPanelClass:ProcessInput(inputEvents)
	local view = self:GetViewport()
	for id, event in ipairs(inputEvents) do
		if event.type == "KeyDown" and event.key == "RETURN" and self.selControl == self.controls.input then
			self:SendUserMessage()
			inputEvents[id] = nil
		elseif event.type == "KeyDown" and event.key == "LEFTBUTTON" and self.selControl and not self.selControl:IsMouseOver() then
			self:SelectControl()
		end
	end
	self:ProcessControlsInput(inputEvents, view)
	for id, event in ipairs(inputEvents) do
		if event and event.key and event.key:match("BUTTON") and isMouseInRegion(view) then
			inputEvents[id] = nil
		end
	end
end

function AIChatPanelClass:Draw()
	local view = self:GetViewport()
	SetDrawLayer(6)
	SetDrawColor(0.85, 0.85, 0.85)
	DrawImage(nil, view.x, view.y, 4, view.height)
	DrawImage(nil, view.x, view.y, view.width, 2)
	SetDrawColor(0.08, 0.09, 0.1)
	DrawImage(nil, view.x + 4, view.y + 2, view.width - 4, view.height - 2)

	if self.collapsed then
		SetDrawColor(1, 1, 1)
		DrawString(view.x + 8, view.y + 42, "LEFT", 18, "VAR", "AI")
		self:DrawControls(main.viewPort)
		SetDrawLayer(0)
		return
	end

	SetDrawColor(0.16, 0.17, 0.18)
	DrawImage(nil, view.x + 4, view.y + 2, view.width - 4, 34)
	SetDrawColor(1, 1, 1)
	DrawString(view.x + 42, view.y + 9, "LEFT", 18, "VAR", "AI Assistant")
	local provider = providers.byId[self.settings.provider]
	local providerLabel = provider and provider.label or "Custom"
	local status = self.statusText or ""
	if not settingsStore.IsConfigured(self.settings) then
		status = "API not configured"
	end
	SetDrawColor(1, 1, 1)
	SetViewport(view.x + 8, view.y + 70, view.width - 16, 18)
	DrawString(0, 0, "LEFT", 14, "VAR", "^8" .. providerLabel .. " / " .. status)
	SetViewport()
	self:DrawControls(main.viewPort)
	SetDrawLayer(0)
end

return AIChatPanelClass
