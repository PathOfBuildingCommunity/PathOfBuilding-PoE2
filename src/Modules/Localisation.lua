-- PoB2 本地化入口：显示翻译、输入转换和中文搜索集中在此模块。
local Dictionary = dofile('Modules/Localisation/Dictionary.lua')
local Font = dofile('Modules/Localisation/Font.lua')
local Import = dofile('Modules/Localisation/Import.lua')
local Languages = dofile('Modules/Localisation/Languages.lua')
local localisation = { language = 'en', rawDepth = 0, dictionaries = { }, fonts = { }, cache = { }, cacheSize = 0 }

local function loadDictionary(language)
	if language == 'en' then return nil end
	if not localisation.dictionaries[language] then
		local resources = Languages.LoadResources(language)
		local dictionary = Dictionary.New(); dictionary:LoadFiles(resources.path, resources.files)
		localisation.dictionaries[language] = dictionary
	end
	return localisation.dictionaries[language]
end

--- <summary>返回可选语言，供原有设置界面生成下拉列表。</summary>
function localisation:LanguageList()
	return Languages.List()
end

--- <summary>词库与语言设置绑定，切换时清除显示缓存。</summary>
function localisation:SetLanguage(language)
	local requested = language
	local definition = Languages.Get(language) or Languages.Default()
	assert(definition, '没有可用的默认界面语言')
	if not Languages.Get(language) then self.invalidLanguage = requested else self.invalidLanguage = nil end
	language = definition.id
	loadDictionary(language)
	self.language = language; self.cache = { }; self.cacheSize = 0
	return language
end

--- <summary>显示翻译保留英文回退，缓存限制大小，避免长时间运行不断积累。</summary>
function localisation:Translate(text)
	if self.language == 'en' or self.rawDepth > 0 or type(text) ~= 'string' or text == '' then return text end
	if self.cache[text] then return self.cache[text] end
	local dictionary = loadDictionary(self.language)
	local result = dictionary and dictionary:Translate(text) or text
	local definition = Languages.Get(self.language)
	local fallback = definition and definition.fallback
	local visited = { [self.language] = true }
	while result == text and fallback and not visited[fallback] do
		visited[fallback] = true
		local fallbackDictionary = loadDictionary(fallback)
		result = fallbackDictionary and fallbackDictionary:Translate(text) or text
		local fallbackDefinition = Languages.Get(fallback)
		fallback = fallbackDefinition and fallbackDefinition.fallback
	end
	if self.cacheSize >= 8192 then self.cache = { }; self.cacheSize = 0 end
	self.cache[text] = result; self.cacheSize = self.cacheSize + 1
	return result
end

--- <summary>中文输入使用简体与繁体反向词典，不依赖当前显示语言。</summary>
function localisation:ToEnglish(text)
	if not text:find('[\128-\255]') then return text end
	local languages = { self.language }
	for _, definition in ipairs(Languages.List()) do
		if definition.id ~= self.language then languages[#languages + 1] = definition.id end
	end
	for _, language in ipairs(languages) do
		if language ~= 'en' then
			local translated = loadDictionary(language):Translate(text, true)
			if translated ~= text then return translated end
		end
	end
	return text
end

--- <summary>搜索同时匹配英文原名和当前语言译名，不改写业务标签表。</summary>
function localisation:Match(text, pattern)
	return text:match(pattern) or self:Translate(text):match(pattern)
end

--- <summary>在既有标签集合中寻找中文译名，避免修改由计算模块共享的标签表。</summary>
function localisation:TagName(tags, name)
	if tags[name] ~= nil or not name:find('[\128-\255]') then return name end
	for key in pairs(tags) do
		if self:Translate(key):gsub('%s+', ''):lower() == name then return key end
	end
	return name
end

--- <summary>物品和角色输入边界共用同一个无歧义词条转换器。</summary>
function localisation:ItemText(text)
	return Import.ItemText(text, function(line) return self:ToEnglish(line) end)
end

--- <summary>转换角色导入术语并保留原始对象。</summary>
function localisation:Character(character)
	return Import.Character(character, function(text) return self:ToEnglish(text) end)
end

--- <summary>按 PoB2 物品字段生成显示标题，避免唯一名称与基底名称拼接后失去词条边界。</summary>
function localisation:ItemTitle(item)
	local baseName = item.baseName and item.baseName:gsub(' %(.+%)', '') or nil
	if item.title then
		return self:Translate(item.title), self:Translate(baseName or item.baseName or '')
	end
	local prefix = item.namePrefix and self:Translate(item.namePrefix) or ''
	local suffix = item.nameSuffix and self:Translate(item.nameSuffix) or ''
	return nil, prefix .. self:Translate(baseName or item.baseName or '') .. suffix
end

--- <summary>编辑区显示内容始终来自用户原文；异常也必须恢复翻译开关。</summary>
function localisation:DrawRaw(callback, object, ...)
	self.rawDepth = self.rawDepth + 1
	local previousUnicode = self.rawUnicode
	self.rawUnicode = self.rawUnicode or (object.buf and object.buf:find('[\128-\255]') ~= nil)
	local ok, result = pcall(callback, object, ...)
	self.rawUnicode = previousUnicode
	self.rawDepth = self.rawDepth - 1
	if not ok then error(result, 0) end
	return result
end

-- 设置未存在时默认简体中文，已有英文构筑与数据不需要迁移。
localisation:SetLanguage('zh-CN')
local function activeFont()
	local definition = Languages.Get(localisation.language)
	local path = definition and definition.font
	if not path then return nil end
	if not localisation.fonts[path] then localisation.fonts[path] = Font.New(path) end
	return localisation.fonts[path]
end
local draw, width, cursor = DrawString, DrawStringWidth, DrawStringCursorIndex

--- <summary>编辑控件的滚动和插入计算也必须测量原文，不能只在 Draw 中关闭翻译。</summary>
function localisation:MeasureRaw(height, fontName, text, context)
	-- 计算表格中的数值最终按文本绘制，测宽时也统一转换为字符串。
	if type(text) ~= 'string' then text = tostring(text or '') end
	local font = activeFont()
	if font and (self.rawUnicode or (context or text):find('[\128-\255]') or text:find('[\128-\255]')) then return font:Layout(height, text).width end
	return width(height, fontName, text)
end

if draw then
	--- <summary>翻译显示文本，并为含中文的文本选择字形图集。</summary>
	function DrawString(left, top, align, height, fontName, text)
		text = localisation:Translate(text)
		local font = activeFont()
		if font and (localisation.rawUnicode or text:find('[\128-\255]')) then return font:Draw(left, top, align, height, text) end
		return draw(left, top, align, height, fontName, text)
	end
	--- <summary>按实际显示内容测宽，编辑区服从原文绘制上下文。</summary>
	function DrawStringWidth(height, fontName, text)
		text = localisation:Translate(text)
		return localisation:MeasureRaw(height, fontName, text)
	end
	--- <summary>返回原文光标字节索引，保持编辑数据与显示译文独立。</summary>
	function DrawStringCursorIndex(height, fontName, text, x, y)
		local font = activeFont()
		if font and text:find('[\128-\255]') then return font:Cursor(height, text, x, y) end
		return cursor(height, fontName, text, x, y)
	end
end

return localisation
