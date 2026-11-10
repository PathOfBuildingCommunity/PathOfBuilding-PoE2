-- 固定语言名称须使用自身字体，覆盖运行中切换、展开列表、搜索与设置保存。
return function(equal)
	local Font = dofile('Modules/Localisation/Font.lua')
	local languageBefore = localisation.language
	local scriptPath, userPath = GetScriptPath, GetUserPath
	-- 无界面宿主的默认路径为空；字体生成和缓存限定在测试目录。
	GetScriptPath = function() return '.' end
	GetUserPath = function() return 'Tests/Run' end
	local languages = localisation:LanguageList()
	local names = { en = 'English', ['zh-CN'] = '简体中文', ['zh-TW'] = '繁體中文', ['ja-JP'] = '日本語', ['ko-KR'] = '한국어' }
	local fonts, nativeNames = { }, { }
	for _, name in pairs(names) do nativeNames[name] = true end
	for _, language in ipairs(languages) do
		if language.font then
			-- 早前的无界面绘制可能缓存字体不可用，路径就绪后重新尝试。
			local key = language.font.folder .. '\0' .. (language.font.cache or '')
			if localisation.fonts[key] == false then localisation.fonts[key] = nil end
			fonts[language.id] = assert(Font.New(language.font.folder, language.font), '无法载入语言字体：' .. language.id)
		end
	end
	-- 记录实际字形纹理坐标和尺寸，不能只验证原字符串或绘制没有异常。
	local function glyphs(callback)
		local original, result = DrawImage, { }
		DrawImage = function(handle, x, y, width, height, u, v, u2, v2)
			if handle and u then result[#result + 1] = table.concat({width, height, u, v, u2, v2}, ',') end
		end
		local ok, err = pcall(callback)
		DrawImage = original
		assert(ok, err)
		return table.concat(result, ';')
	end
	local expected, expectedList = { }, { }
	for _, language in ipairs(languages) do
		expected[language.id] = fonts[language.id] and glyphs(function() fonts[language.id]:Draw(0, 0, 'LEFT', 14, names[language.id]) end) or ''
		if fonts[language.id] then
			for _, token in ipairs(fonts[language.id]:Layout(14, names[language.id]).lines[1].tokens) do
				equal(token.glyph ~= fonts[language.id].metrics.glyphs[63], true, language.id .. ' 本名没有问号替代字形')
			end
		end
		if expected[language.id] ~= '' then expectedList[#expectedList + 1] = expected[language.id] end
	end
	local viewPort = { x = 0, y = 0, width = 1920, height = 1080 }
	for _, current in ipairs({ 'zh-CN', 'en', 'zh-TW', 'ja-JP', 'ko-KR', 'en', 'zh-CN' }) do
		localisation:SetLanguage(current)
		local dictionary = localisation.dictionaries[current]
		local translate = dictionary and dictionary.Translate
		if dictionary then
			dictionary.Translate = function(self, text, ...)
				assert(not nativeNames[text], '语言本名进入了本地化词典：' .. text)
				return translate(self, text, ...)
			end
		end
		main:OpenOptionsPopup()
		local popup = main.popups[#main.popups]
		local control = popup.controls.language
		equal(control.list[control.selIndex].id, current, current .. ' 打开设置保持当前选择')
		for _, language in ipairs(languages) do
			control:SelByValue(language.id, 'id')
			equal(control.list[control.selIndex].label, names[language.id], current .. ' 固定语言本名')
			control.dropped = false
			equal(glyphs(function() control:Draw(viewPort, true) end), expected[language.id], current .. ' 已选语言字形：' .. language.id)
		end
		control:SelByValue('en', 'id')
		control.dropped = true
		equal(glyphs(function() control:Draw(viewPort, true) end), table.concat(expectedList, ';'), current .. ' 展开显示全部语言的正确字形')
		for _, language in ipairs(languages) do
			control.searchTerm = names[language.id]
			control:UpdateSearch()
			equal(control:GetDropCount(), 1, current .. ' 按本名搜索：' .. language.id)
			equal(glyphs(function() control:Draw(viewPort, true) end):sub(-#expected[language.id]), expected[language.id], current .. ' 搜索结果字形：' .. language.id)
		end
		control:ResetSearch()
		if current == 'zh-CN' or current == 'zh-TW' then
			equal(StripEscapes(popup.controls.languageLabel:GetProperty('label')), current == 'zh-CN' and '语言-Language:' or '語言-Language:', current .. ' 双语标题')
		end
		-- 自动宽度同样使用对应字体，保持搜索高亮和裁剪与字形一致。
		control.width = 1
		control:CheckDroppedWidth(true)
		local widest = 1
		for _, language in ipairs(languages) do
			local width = fonts[language.id] and fonts[language.id]:Layout(14, names[language.id]).width or localisation:WithRawLanguage('en', DrawStringWidth, 14, 'VAR', names[language.id])
			widest = math.max(widest, width + 10)
		end
		equal(control.droppedWidth, widest, current .. ' 自动宽度按实际字体测量')
		main:ClosePopup()
		if dictionary then dictionary.Translate = translate end
	end
	-- 使用独立设置文件验证真实保存、重新打开和重新加载，不仅直接修改语言变量。
	for _, language in ipairs(languages) do
		main:OpenOptionsPopup()
		local popup = main.popups[#main.popups]
		popup.controls.language:SelByValue(language.id, 'id')
		popup.controls.save.onClick()
		equal(localisation.language, language.id, '保存设置切换：' .. language.id)
		local file = assert(io.open(main.userPath .. 'Settings.xml', 'rb'))
		local settings = file:read('*a'); file:close()
		equal(settings:find('language="' .. language.id .. '"', 1, true) ~= nil, true, '保存原语言 ID：' .. language.id)
		localisation:SetLanguage(language.id == 'en' and 'zh-CN' or 'en')
		main:LoadSettings(true)
		equal(localisation.language, language.id, '重新加载语言：' .. language.id)
		main:OpenOptionsPopup()
		popup = main.popups[#main.popups]
		equal(popup.controls.language.list[popup.controls.language.selIndex].id, language.id, '重开设置选择值：' .. language.id)
		main:ClosePopup()
	end
	local ok = pcall(function() localisation:WithRawLanguage('ko-KR', function() error('测试绘制异常') end) end)
	equal(ok, false, '绘制异常继续抛出')
	equal(localisation.rawDepth, 0, '绘制异常恢复翻译开关')
	equal(localisation.rawLanguage, nil, '绘制异常恢复字体上下文')
	GetScriptPath, GetUserPath = scriptPath, userPath
	localisation:SetLanguage(languageBefore)
	main:SaveSettings()
end
