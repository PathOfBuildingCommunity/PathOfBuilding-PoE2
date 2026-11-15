-- 从官方属性 ID、条件和变换提取稳定显示模板；无需启动计算或窗口。
package.path = '../runtime/lua/?.lua;' .. package.path
local json = require('dkjson')
local StatTemplates = dofile('Modules/Localisation/StatTemplates.lua')
local file = assert(io.open('Tests/Run/localisation-audit-input.json', 'rb'))
local manifest = assert(json.decode(file:read('*a'))); file:close()
local result, identities = { }, { }
for _, path in ipairs(manifest.statFiles) do
	local scope = path:match('([^/]+)$')
	local variants = { }
	for index, descriptor in ipairs(dofile(path .. '.lua')) do
		for branch, description in ipairs(descriptor[1] or { }) do
			local baseIdentity = StatTemplates.Identity(scope, descriptor.stats, description)
			variants[baseIdentity] = (variants[baseIdentity] or 0) + 1
			local identity = baseIdentity .. '|variant_' .. variants[baseIdentity]
			local text, slots = StatTemplates.Compile(description.text)
			if identities[identity] then
				assert(identities[identity] == text, '属性身份冲突: ' .. path .. ':' .. index .. ':' .. branch .. ' / ' .. identity .. '\n' .. identities[identity] .. '\n' .. text)
			else
				identities[identity] = text
				local parameters = { }
				for name, slot in pairs(slots) do
					parameters[#parameters + 1] = { name = name, expression = 'values[' .. slot.index .. ']', format = '', legacyIndex = slot.index - 1, legacyPrefix = slot.sign }
				end
				table.sort(parameters, function(a, b) return a.name < b.name end)
				result[#result + 1] = { domain = 'stat_description', id = identity, field = 'text', text = description.text, template = text, parameters = parameters, origin = path .. ':' .. index .. ':' .. branch }
			end
		end
	end
end
file = assert(io.open('Tests/Run/key-stat-data.json', 'wb'))
file:write(json.encode(result)); file:close()
print('已提取 ' .. #result .. ' 个具有属性身份和命名参数的描述模板。')
