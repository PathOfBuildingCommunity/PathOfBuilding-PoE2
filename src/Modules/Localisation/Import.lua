-- 只转换 PoB2 导入格式中明确属于展示术语的字段，保留 ID、哈希和数值。
local Import = { }

local termFields = { name = true, baseType = true, typeLine = true }
local modFields = { implicitMods = true, explicitMods = true, enchantMods = true, craftedMods = true, fracturedMods = true, runeMods = true, desecratedMods = true }
local propertyFields = { properties = true, additionalProperties = true, requirements = true, weaponRequirements = true, grantedSkills = true }
local attributes = { ["力量"] = "Strength", ["敏捷"] = "Dexterity", ["智慧"] = "Intelligence", ["智力"] = "Intelligence" }

-- 原数据保留供日志、重复导入和调用方使用，避免原地改写下载结果。
local function copy(value)
	if type(value) ~= 'table' then return value end
	local result = { }; for key, child in pairs(value) do result[key] = copy(child) end
	return result
end

-- 逐项转换词条，未知或有歧义的译名保持原样。
local function item(value, translate, inputName, domain)
	for field in pairs(termFields) do
		if type(value[field]) == 'string' then
			-- 稀有装备名称属于用户原文；基底和宝石名称由当前数据域消除旧词典的同名冲突。
			if field ~= 'name' or value.frameType ~= 2 then
				local text, status = value[field]
				if inputName and field ~= 'name' then text, status = inputName(domain, text) end
				value[field] = status and text or translate(text)
			end
		end
	end
	for field in pairs(modFields) do
		for i, mod in ipairs(value[field] or { }) do
			if type(mod) == 'string' then value[field][i] = translate(mod)
			elseif type(mod) == 'table' and type(mod.description) == 'string' then mod.description = translate(mod.description) end
		end
	end
	for field in pairs(propertyFields) do
		for _, property in ipairs(value[field] or { }) do
			if property.name then property.name = translate(property.name) end
			for _, pair in ipairs(property.values or { }) do if type(pair[1]) == 'string' then pair[1] = translate(pair[1]) end end
		end
	end
	for _, socketed in ipairs(value.socketedItems or { }) do item(socketed, translate, inputName, domain) end
	for _, socketed in ipairs(value.sockets or { }) do if socketed.item then item(socketed.item, translate, inputName, 'equipment_base') end end
	for _, support in ipairs(value.supports or { }) do item(support, translate, inputName, 'gem') end
end

--- <summary>接受 PoB2 的角色对象，既不扁平化数据，也不把 PoE1 items 结构直接套入。</summary>
function Import.Character(character, translate, inputName)
	local result = copy(character)
	for _, field in ipairs({ 'equipment', 'skills', 'jewels' }) do
		for _, value in ipairs(result[field] or { }) do item(value, translate, inputName, field == 'skills' and 'gem' or 'equipment_base') end
	end
	for _, override in pairs(result.passives and result.passives.skill_overrides or { }) do
		-- 此位置由 PoB2 明确按三种属性名读取，可消除“智慧”与其他词条的歧义。
		if override.name then override.name = attributes[override.name] or translate(override.name) end
	end
	return result
end

--- <summary>游戏剪贴板按整行处理，保留换行、稀有物品自定义名称和未识别词条。</summary>
function Import.ItemText(text, translate, baseName)
	local rarity, headerLines
	return (text:gsub('[^\r\n]+', function(line)
		-- 双行装备头的第一行是名称；稀有名称不进入任何翻译或基底匹配。
		if headerLines == 2 then
			headerLines = 1
			return rarity == 'RARE' and line or translate(line)
		end
		if baseName and (headerLines == 1 or not rarity) then
			local name, status = baseName(line)
			if headerLines == 1 then headerLines = 0 end
			if status then return name end
		end
		local translated = translate(line)
		local value = translated:match('^Rarity:%s*(.+)$')
		if value then
			rarity = value:upper()
			headerLines = (rarity == 'RARE' or rarity == 'UNIQUE' or rarity == 'RELIC') and 2 or 1
		end
		return translated
	end))
end

return Import
