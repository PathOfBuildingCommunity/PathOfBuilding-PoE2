-- 按常量预算拆分大型数据域，加载后仍保持同一业务身份索引。
local result = { }
for _, path in ipairs({ "Locales/Keys/tree_node_1.lua", "Locales/Keys/tree_node_2.lua", "Locales/Keys/tree_node_3.lua", "Locales/Keys/tree_node_4.lua" }) do
	for id, fields in pairs(dofile(path)) do result[id] = fields end
end
return result
