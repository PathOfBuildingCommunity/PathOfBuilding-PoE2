-- 业务行识别形状独立于英文显示措辞。
local result = { }
for key, template in pairs(dofile('Locales/Keys/LineInputs_1.lua')) do result[key] = template end
for key, template in pairs(dofile('Locales/Keys/LineInputs_2.lua')) do result[key] = template end
for key, template in pairs(dofile('Locales/Keys/LineInputs_3.lua')) do result[key] = template end
for key, template in pairs(dofile('Locales/Keys/LineInputs_4.lua')) do result[key] = template end
for key, template in pairs(dofile('Locales/Keys/LineInputs_5.lua')) do result[key] = template end
return result
