-- 仅在物品解析边界识别已知词缀语法，显示时使用已经绑定的引用。
local LineTemplates = dofile('Modules/Localisation/LineTemplates.lua')
local ModifierInputs = { }
ModifierInputs.__index = ModifierInputs

--- <summary>建立独立输入索引；同一语法存在不同用途译文时保持歧义，不能任选词条。</summary>
function ModifierInputs.New(rules, catalogs)
	local self = setmetatable({ contexts = { }, byKey = { } }, ModifierInputs)
	local languages = { }
	for language in pairs(catalogs) do languages[#languages + 1] = language end
	table.sort(languages)
	for _, rule in ipairs(rules) do
		local context, template, key = unpack(rule)
		local source = assert(catalogs.en[key], '输入规则没有显示资源: ' .. key)
		self.byKey[key] = { key = key, template = template }
		local texts = { }
		for _, language in ipairs(languages) do texts[#texts + 1] = (catalogs[language][key] or source).text end
		local fingerprint = table.concat(texts, '\0')
		local entries = self.contexts[context] or { }
		self.contexts[context] = entries
		local previous = entries[template]
		if previous == nil then
			entries[template] = { key = key, template = template, fingerprint = fingerprint }
		elseif previous and previous.fingerprint ~= fingerprint then
			entries[template] = false
		elseif previous and key < previous.key then
			previous.key = key
		end
	end
	return self
end

--- <summary>在解析时绑定原行及已知正负分支，保留未知和歧义输入。</summary>
function ModifierInputs:Bind(context, examples)
	local references, seen = { }, { }
	for _, text in ipairs(examples) do
		local template = LineTemplates.Compile(text)
		local entry = self.contexts[context or ''] and self.contexts[context or ''][template]
		if entry == nil then entry = self.contexts[''] and self.contexts[''][template] end
		if entry and not seen[entry.key] then
			references[#references + 1] = entry
			seen[entry.key] = true
		end
	end
	return references
end

return ModifierInputs
