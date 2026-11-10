-- 将数据行中的原始数值保留为命名参数；身份由调用方的业务对象提供。
local LineTemplates = { }

--- <summary>提取单值或括号范围，保留原符号、精度和不参与数值的文本。</summary>
function LineTemplates.Compile(text)
	local values, parts, position = { }, { }, 1
	while position <= #text do
		local first, last = text:find('%d+%.?%d*', position)
		if not first then break end
		-- 范围作为一个参数，避免把分隔符误认为负号或改变范围顺序。
		local rangeFirst, rangeLast = text:find('%(%-?%d+%.?%d*%-%-?%d+%.?%d*%)', position)
		if rangeFirst and rangeFirst <= first then first, last = rangeFirst, rangeLast end
		parts[#parts + 1] = text:sub(position, first - 1):gsub('{', '{{'):gsub('}', '}}')
		local name = 'value_' .. (#values + 1)
		values[#values + 1] = text:sub(first, last)
		parts[#parts + 1] = '{' .. name .. '}'
		position = last + 1
	end
	parts[#parts + 1] = text:sub(position):gsub('{', '{{'):gsub('}', '}}')
	local parameters = { }
	for index, value in ipairs(values) do parameters['value_' .. index] = value end
	return table.concat(parts), parameters
end

--- <summary>绑定时记录资源模板形状，显示值改变后仍沿用同一个业务引用。</summary>
function LineTemplates.Bind(key, text)
	return { key = key, template = LineTemplates.Compile(text) }
end

--- <summary>仅在原绑定模板匹配时返回参数，防止动态替换节点沿用过期文案。</summary>
function LineTemplates.Parameters(reference, text)
	if not reference then return end
	local template, parameters = LineTemplates.Compile(text)
	if template == reference.template then return parameters end
end

return LineTemplates
