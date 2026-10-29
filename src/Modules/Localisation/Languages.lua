-- 读取语言包注册表，隔离语言发现、回退和资源清单。
local Languages = { }

local manifest = dofile("Locales/Manifest.lua")
local definitions = { }
local ordered = { }

for _, item in ipairs(manifest.items or { }) do
	assert(type(item.id) == "string" and item.id ~= "", "语言包缺少 id")
	assert(type(item.name) == "string" and item.name ~= "", "语言包缺少 name: " .. item.id)
	assert(not definitions[item.id], "语言包 id 重复: " .. item.id)
	assert(item.fallback == nil or type(item.fallback) == "string", "语言包 fallback 无效: " .. item.id)
	definitions[item.id] = item
	ordered[#ordered + 1] = item
end

assert(definitions.en, "语言注册表必须包含 English")
assert(definitions[manifest.default], "默认语言未注册: " .. tostring(manifest.default))
for _, item in ipairs(ordered) do
	assert(not item.fallback or definitions[item.fallback], "语言回退目标未注册: " .. item.id)
	assert(not item.font or type(item.font) == "string", "语言字体配置无效: " .. item.id)
end

--- <summary>返回语言注册表中的语言定义。</summary>
function Languages.Get(id)
	return definitions[id]
end

--- <summary>返回稳定顺序的语言列表，供设置界面使用。</summary>
function Languages.List()
	local result = { }
	for index, item in ipairs(ordered) do result[index] = item end
	return result
end

--- <summary>返回配置的默认语言。</summary>
function Languages.Default()
	return definitions[manifest.default]
end

--- <summary>加载语言包的词库文件清单，不让业务模块关心目录结构。</summary>
function Languages.LoadResources(id)
	local definition = assert(definitions[id], "未知界面语言: " .. tostring(id))
	if not definition.path then
		return { definition = definition, path = nil, files = { } }
	end
	local files = definition.files
	if type(files) == "string" then files = dofile(definition.path .. "/" .. files) end
	assert(type(files) == "table", "语言包文件清单无效: " .. id)
	return { definition = definition, path = definition.path, files = files }
end

return Languages
