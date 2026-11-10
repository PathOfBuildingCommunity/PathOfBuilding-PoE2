-- 按常量预算拆分大型数据域，加载后仍保持同一业务身份索引。
local result = { }
for _, path in ipairs({ "Locales/Keys/equipment_modifier_1.lua", "Locales/Keys/equipment_modifier_2.lua" }) do
	for id, fields in pairs(dofile(path)) do result[id] = fields end
end
return result
