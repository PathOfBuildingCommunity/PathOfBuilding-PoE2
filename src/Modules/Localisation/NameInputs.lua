-- 输入名称按当前业务域及显示 key 建立精确别名，不使用全局词典猜测对象。
local NameInputs = { }
NameInputs.__index = NameInputs

--- <summary>从当前对象的名称引用建立跨语言索引，不合并指向不同英文身份的译名。</summary>
function NameInputs.New(objects, languages)
	local self = setmetatable({ aliases = { } }, NameInputs)
	for _, object in pairs(objects) do
		local key = object.nameKey
		if key then
			local english = assert(languages.en[key], '输入名称缺少英文资源：' .. key).text
			for _, entries in pairs(languages) do
				local entry = entries[key]
				if entry and entry.text ~= english then
					local previous = self.aliases[entry.text]
					self.aliases[entry.text] = previous == nil and english or previous == english and english or false
				end
			end
		end
	end
	return self
end

--- <summary>唯一已知译名转换为英文身份；未知和有歧义的输入保留原文并返回状态。</summary>
function NameInputs:Resolve(text)
	local name = self.aliases[text]
	if name == false then return text, 'ambiguous' end
	if name then return name, 'resolved' end
	return text
end

return NameInputs
