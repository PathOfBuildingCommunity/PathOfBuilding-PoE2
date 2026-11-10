-- 按常量预算拆分大型数据域，加载后仍保持同一业务身份索引。
local result = { }
for _, path in ipairs({ "Locales/Keys/stat_description_1.lua", "Locales/Keys/stat_description_2.lua", "Locales/Keys/stat_description_3.lua" }) do
	for id, fields in pairs(dofile(path)) do result[id] = fields end
end
return result
