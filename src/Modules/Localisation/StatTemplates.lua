-- 属性模板的业务身份、命名参数和原数值格式，与语言资源查询分离。
local StatTemplates = { }

--- <summary>使用作用域、属性 ID、条件与变换确定描述身份，不使用英文正文。</summary>
function StatTemplates.Identity(scope, stats, description)
	scope = scope:gsub('^[Ss]pecific_[Ss]kill_[Ss]tat_[Dd]escriptions/', ''):lower()
	local parts = { scope, table.concat(stats, ',') }
	for _, limit in ipairs(description.limit or { }) do parts[#parts + 1] = tostring(limit[1]) .. ':' .. tostring(limit[2]) end
	for _, spec in ipairs(description) do parts[#parts + 1] = tostring(spec.k) .. ':' .. tostring(spec.v) end
	parts[#parts + 1] = description.gem_quality and 'quality' or 'normal'
	return table.concat(parts, '|')
end

--- <summary>把官方编号参数改为命名参数，保留属性索引、符号和字面括号。</summary>
function StatTemplates.Compile(text)
	local parameters, parts, position, hasNumber = { }, { }, 1, false
	for first, body, last in text:gmatch('(){([^{}]*)}()') do
		local prefix = text:sub(position, first - 1)
		-- 品质范围原先只改每个逻辑行的首个数值；真实换行不等于字面分行标记。
		if prefix:find('\\n', 1, true) then hasNumber = false; prefix = prefix:match('.*\\n(.*)') end
		if prefix:find('%d') then hasNumber = true end
		parts[#parts + 1] = text:sub(position, first - 1):gsub('{', '{{'):gsub('}', '}}')
		local index, sign = body:match('^(%d*):([%+%-]?)d$')
		if not index and (body == '' or body:match('^%d+$')) then index, sign = body, '' end
		assert(index ~= nil, '不支持的属性参数: {' .. body .. '}')
		-- 原实现对未编号的 {:d}/{:+d} 不应用显式符号，迁移保留其输出。
		if index == '' then sign = '' end
		index = tonumber(index) or 0
		local name = 'value_' .. (index + 1) .. (sign == '+' and '_plus' or sign == '-' and '_minus' or '')
		parameters[name] = parameters[name] or { index = index + 1, sign = sign, firstNumber = not hasNumber }
		hasNumber = true
		parts[#parts + 1] = '{' .. name .. '}'
		position = last
	end
	parts[#parts + 1] = text:sub(position):gsub('{', '{{'):gsub('}', '}}')
	return table.concat(parts):gsub('%%%%', '%%'):gsub('\\n', '\n'), parameters
end

--- <summary>按原属性变换后的精度生成值或范围，供各语言完整句子重排。</summary>
function StatTemplates.Parameters(slots, values, transform)
	local parameters = { }
	for name, slot in pairs(slots) do
		local value, sign = assert(values[slot.index], '缺少属性值: ' .. name), slot.sign
		local format = value.fmt or 'd'
		if value.min == value.max then
			parameters[name] = string.format('%' .. sign .. format, value.min)
		elseif sign == '+' or sign == '-' then
			parameters[name] = string.format(value.max < 0 and '-(%d-%d)' or '+(%d-%d)', value.max < 0 and -value.min or value.min, value.max < 0 and -value.max or value.max)
		else
			parameters[name] = string.format('(%' .. format .. '-%' .. format .. ')', value.min, value.max)
		end
		if transform then parameters[name] = transform(parameters[name], slot.index, slot.firstNumber) end
	end
	return parameters
end

return StatTemplates
