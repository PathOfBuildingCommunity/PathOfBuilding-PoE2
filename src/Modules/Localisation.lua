-- PoB2 本地化入口：显示翻译、输入转换和中文搜索集中在此模块。
local Dictionary = dofile('Modules/Localisation/Dictionary.lua')
local Font = dofile('Modules/Localisation/Font.lua')
local Import = dofile('Modules/Localisation/Import.lua')
local Languages = dofile('Modules/Localisation/Languages.lua')
local Messages = dofile('Modules/Localisation/Messages.lua')
local LineTemplates = dofile('Modules/Localisation/LineTemplates.lua')
local terms = dofile('Locales/Terms.lua')
local dataKeys = dofile('Locales/DataKeys.lua')
local lineInputs = dofile('Locales/LineInputs.lua')
local localisation = { language = 'en', rawDepth = 0, dictionaries = { }, fonts = { }, cache = { }, cacheSize = 0 }
local messages = Messages.New()
local missingTerms = { }
-- 数据容器会被业务代码用 pairs 枚举，显示引用独立保存，不能混入伪业务条目。
local modDataLines = setmetatable({ }, { __mode = 'k' })
local listKeys = setmetatable({ }, { __mode = 'k' })
for _, definition in ipairs(Languages.List()) do
	if definition.messageFiles then
		messages:LoadFiles(definition.id, definition.messagePath or definition.path, definition.messageFiles)
	end
end
messages:Validate()
local ModifierInputs = dofile('Modules/Localisation/ModifierInputs.lua')
local modifierInputs = ModifierInputs.New(dofile('Locales/ModifierInputs.lua'), messages.languages)

--- <summary>使用稳定语义 key 和命名参数生成当前语言文案，最终回退英文资源。</summary>
function localisation:Text(key, parameters)
	local chain, visited, language = { }, { }, self.language
	while language and not visited[language] do
		visited[language] = true; chain[#chain + 1] = language
		local definition = Languages.Get(language)
		language = definition and definition.fallback
	end
	return messages:Text(key, parameters, chain)
end

--- <summary>创建控件文案属性，在读取时按当前语言和最新参数生成文本。</summary>
function localisation:Label(key, parameters, prefix, suffix)
	return function(control)
		return (prefix or '') .. self:Text(key, type(parameters) == 'function' and parameters(control) or parameters) .. (suffix or '')
	end
end

--- <summary>为句中另一条文案建立显式引用，避免切换语言后参数停留在旧译文。</summary>
function localisation:Ref(key, parameters)
	return Messages.Ref(key, parameters)
end

--- <summary>返回已登记业务术语的稳定显示引用，未知身份保留原字段并记录诊断。</summary>
function localisation:TermKey(domain, id)
	local key = terms[domain] and terms[domain][id]
	if not key then missingTerms[domain .. ':' .. tostring(id)] = true end
	return key
end

--- <summary>按业务域和原有身份获取术语显示，未知身份保留英文并记录诊断。</summary>
function localisation:Term(domain, id, english)
	local key = terms[domain] and terms[domain][id]
	if key then return self:Text(key) end
	missingTerms[domain .. ':' .. tostring(id)] = true
	return english or id
end

--- <summary>为动态句子引用业务术语，使参数随当前语言解析。</summary>
function localisation:TermRef(domain, id, english)
	local key = terms[domain] and terms[domain][id]
	if key then return self:Ref(key) end
	missingTerms[domain .. ':' .. tostring(id)] = true
	return english or id
end

--- <summary>读取带有稳定显示引用的数据字段，保留原业务字段用于索引和保存。</summary>
function localisation:Field(object, field, parameters)
	local key = object[field .. 'Key']
	if not key then
		local display = object[field .. 'Display']
		return type(display) == 'function' and display(object) or object[field]
	end
	return (object[field .. 'Prefix'] or '') .. self:Text(key, parameters or object[field .. 'Params']) .. (object[field .. 'Suffix'] or '')
end

--- <summary>按业务域和原有身份附加显示引用，不改写计算、索引或保存字段。</summary>
function localisation:BindFields(domain, id, object)
	local fields = dataKeys[domain] and dataKeys[domain][tostring(id)]
	if not fields then return end
	for field, key in pairs(fields) do object[field .. 'Key'] = key end
end

--- <summary>按业务身份绑定多行字段；原属性行和计算数据保持不变。</summary>
function localisation:BindLines(domain, id, object, field)
	local fields = dataKeys[domain] and dataKeys[domain][tostring(id)] or { }
	local references = { }
	for index, text in ipairs(object[field] or { }) do
		local key = fields[field .. '_' .. index]
		if key and lineInputs[key] == LineTemplates.Compile(text) then references[index] = LineTemplates.Bind(key, text) end
	end
	object[field .. 'Display'] = references
end

--- <summary>使用已绑定的属性引用生成当前数值文案，变化后的未知正文保留原文并诊断。</summary>
function localisation:Line(object, field, index, text)
	text = text or object[field][index]
	local reference = object[field .. 'Display'] and object[field .. 'Display'][index]
	local parameters = LineTemplates.Parameters(reference, text)
	if parameters then return self:Text(reference.key, parameters) end
	missingTerms['line:' .. tostring(reference and reference.key or object.id or object.name) .. ':' .. field .. ':' .. index] = true
	return text
end

--- <summary>在装备原文完成解析时绑定词缀显示身份，不把输入语法用于最终绘制查询。</summary>
function localisation:BindModLine(modLine, context, examples)
	local inputs = { modLine.line }
	for _, text in ipairs(examples or { }) do inputs[#inputs + 1] = text end
	local body = modLine.line:match('^Bonded: (.*)$')
	if body then inputs[#inputs + 1] = body end
	modLine.displayReferences = modifierInputs:Bind(context, inputs)
end

--- <summary>为具有明确业务 ID 的词缀表直接绑定各行及数值分支。</summary>
function localisation:BindModData(domain, id, lines)
	local fields = dataKeys[domain] and dataKeys[domain][tostring(id)] or { }
	modDataLines[lines] = { }
	for index, text in ipairs(lines) do
		local entry = { line = text, displayReferences = { } }
		for field, key in pairs(fields) do
			if field == 'line_' .. index or field:match('^line_' .. index .. '_roll_') then
				local reference = modifierInputs.byKey[key]
				if reference then entry.displayReferences[#entry.displayReferences + 1] = reference end
			end
		end
		modDataLines[lines][index] = entry
	end
end

--- <summary>显示已知词缀表中的指定行，使用数据加载时的业务引用。</summary>
function localisation:ModDataLine(lines, index, text)
	text = text or lines[index]
	local entry = modDataLines[lines] and modDataLines[lines][index]
	return entry and self:ModLine(entry, text) or text
end

--- <summary>复制已知词缀行的显示引用，原表的业务身份不会因复制或拼接而丢失。</summary>
function localisation:BindModDataLine(lines, index, modLine)
	local entry = modDataLines[lines] and modDataLines[lines][index]
	modLine.displayReferences = entry and entry.displayReferences or { }
end

--- <summary>列表显示引用独立于原始值，选择回调和保存仍读取业务原文。</summary>
function localisation:ListLabel(list, index)
	local entry = list[index]
	if type(entry) == 'table' then return self:Field(entry, 'label') end
	if listKeys[list] and listKeys[list][index] then return self:Text(listKeys[list][index]) end
	return self:ModDataLine(list, index, entry)
end

--- <summary>为原字符串列表登记显示 key，业务枚举、选择值和保存内容保持原结构。</summary>
function localisation:List(list, keys)
	listKeys[list] = keys
	return list
end

--- <summary>为原字符串列表按业务域绑定显示字段，同时保留已经登记的固定选项。</summary>
function localisation:BindDataList(domain, list, field)
	local keys = listKeys[list] or { }
	for index, id in ipairs(list) do
		local fields = dataKeys[domain] and dataKeys[domain][tostring(id)]
		if fields and fields[field] then keys[index] = fields[field] end
	end
	listKeys[list] = keys
end

--- <summary>计算详情的原格式数组保留数值位置，显示通过命名参数和稳定资源生成。</summary>
function localisation:FormatArray(values)
	if not values.formatKey then return string.format(unpack(values)) end
	local parameters = { }
	for name, index in pairs(values.formatParams) do parameters[name] = values[index] end
	return self:Text(values.formatKey, parameters)
end

--- <summary>在物品解析结束时绑定已知来源和变体，未知用户元数据保持原样。</summary>
function localisation:BindItemMetadata(item)
	local context = item.title and item.title .. ':' .. (item.baseName or '')
	for _, field in ipairs({ 'variantList', 'versionList', 'upgradePaths' }) do
		if item[field] then
			modDataLines[item[field]] = { }
			for index, text in ipairs(item[field]) do
				local entry = { line = text }
				self:BindModLine(entry, context)
				modDataLines[item[field]][index] = entry
			end
		end
	end
	item.sourceDisplay = item.source and { line = item.source }
	if item.sourceDisplay then self:BindModLine(item.sourceDisplay, context) end
end

--- <summary>使用已绑定词缀引用和当前范围数值显示，未知用户词条保留原文。</summary>
function localisation:ModLine(modLine, text)
	local body = text:match('^Bonded: (.*)$')
	for _, reference in ipairs(modLine.displayReferences or { }) do
		local parameters = LineTemplates.Parameters(reference, text)
		if parameters then return self:Text(reference.key, parameters) end
		parameters = body and LineTemplates.Parameters(reference, body)
		if parameters then return self:Text('equipment.modifier.bonded', { modifier = self:Ref(reference.key, parameters) }) end
	end
	missingTerms['modifier:' .. modLine.line] = true
	return text
end

--- <summary>装备检索同时匹配原输入和已绑定译文，不使用全局显示反查。</summary>
function localisation:MatchModLine(modLine, pattern)
	return string.matchOrPattern(modLine.line:lower(), pattern, true)
		or string.matchOrPattern(self:ModLine(modLine, modLine.line):lower(), pattern, true)
end

--- <summary>通过业务身份读取独立数据文案；未登记的用户内容保留原文。</summary>
function localisation:DataText(domain, id, field, english, parameters)
	local key = dataKeys[domain] and dataKeys[domain][tostring(id)] and dataKeys[domain][tostring(id)][field]
	if key then return self:Text(key, parameters) end
	missingTerms[domain .. ':' .. tostring(id) .. ':' .. field] = true
	return english
end

--- <summary>搜索独立匹配业务原文和显式引用的当前译文，不经过绘制词典反查。</summary>
function localisation:MatchField(object, field, pattern)
	return string.matchOrPattern((object[field] or ''):lower(), pattern, true)
		or string.matchOrPattern((self:Field(object, field) or ''):lower(), pattern, true)
end

--- <summary>显示已识别的技能名称，保留用户自定义名称和未识别输入原文。</summary>
function localisation:SkillName(instance, effect)
	local gem = instance and instance.gemData
	if instance and instance.nameSpec and (not gem or instance.nameSpec ~= gem.name) then return instance.nameSpec end
	local object = gem or effect or instance and instance.grantedEffect
	return object and self:Field(object, 'name') or instance and instance.nameSpec or ''
end

--- <summary>返回尚未建立稳定显示引用的业务术语，供迁移审计逐条处理。</summary>
function localisation:MissingTerms()
	local result = { }
	for id in pairs(missingTerms) do result[#result + 1] = id end
	table.sort(result)
	return result
end

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
		if self:DataText('skill_tag', key, 'name', key):gsub('%s+', ''):lower() == name then return key end
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
	local baseLabel = self:DataText('equipment_base', item.baseName, 'name', baseName or item.baseName or '')
	if item.title then
		return (item.rarity == 'UNIQUE' or item.rarity == 'RELIC' or not item.rarity) and self:DataText('equipment_unique', item.title, 'name', item.title) or item.title, baseLabel
	end
	local function affix(text)
		if not text then return '' end
		local leading, name, trailing = text:match('^(%s*)(.-)(%s*)$')
		return leading .. self:DataText('equipment_affix', name, 'name', name) .. trailing
	end
	return nil, affix(item.namePrefix) .. baseLabel .. affix(item.nameSuffix)
end

--- <summary>列表和装备槽按字段生成名称，只改变显示，不写回物品数据。</summary>
function localisation:ItemName(item)
	if not item.baseName then return self:Field(item, 'name') or '' end
	local title, baseName = self:ItemTitle(item)
	return title and title .. ', ' .. baseName or baseName
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

-- 设置未存在时默认英文，已有显式语言选择继续生效。
localisation:SetLanguage('en')
local function activeFont()
	local definition = Languages.Get(localisation.language)
	local config = definition and definition.font
	if not config then return nil end
	local folder = type(config) == "string" and config or config.folder
	local key = type(config) == "string" and config or (config.folder .. "\0" .. (config.cache or ""))
	if localisation.fonts[key] == false then return nil end
	if not localisation.fonts[key] then
		local font = Font.New(folder, type(config) == "table" and config or nil)
		localisation.fonts[key] = font or false
	end
	return localisation.fonts[key] ~= false and localisation.fonts[key] or nil
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
		-- 配置占位符和计算结果允许传入数字，与测宽入口保持一致。
		if type(text) ~= 'string' then text = tostring(text or '') end
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
