-- 输入识别规则与显示资源独立；禁止在绘制时查询此索引。
local result = { }
for _, rule in ipairs(dofile('Locales/Keys/ModifierInputs_1.lua')) do result[#result + 1] = rule end
for _, rule in ipairs(dofile('Locales/Keys/ModifierInputs_2.lua')) do result[#result + 1] = rule end
for _, rule in ipairs(dofile('Locales/Keys/ModifierInputs_3.lua')) do result[#result + 1] = rule end
return result
