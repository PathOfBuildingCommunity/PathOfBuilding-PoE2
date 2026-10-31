-- 对照迁移前算法，遍历官方属性分支，验证英文数值、符号、范围和行映射。
package.cpath = '../runtime/?.dll;' .. package.cpath
package.path = '../runtime/lua/?.lua;../runtime/lua/?/init.lua;' .. package.path
arg = { }
io.read = function() error('属性验证禁止等待交互') end
dofile('HeadlessWrapper.lua')
assert(build and not launch.promptMsg, 'PoB2 初始化失败')
localisation:SetLanguage('en')
local before = dofile('Tests/Run/StatDescriber-before.lua')
local after = LoadModule('Modules/StatDescriber')
local json = require('dkjson')
local file = assert(io.open('Tests/Run/localisation-audit-input.json', 'rb'))
local manifest = assert(json.decode(file:read('*a'))); file:close()
local count, samples, unavailable = 0, 0, 0
for _, path in ipairs(manifest.statFiles) do
	local scope = path:match('([^/]+)$')
	for _, descriptor in ipairs(dofile(path .. '.lua')) do
		for _, description in ipairs(descriptor[1] or { }) do
			local stats = { }
			for index, id in ipairs(descriptor.stats) do
				local limit = description.limit[index]
				local number = limit and (type(limit[1]) == 'number' and limit[1] or type(limit[2]) == 'number' and limit[2] or 1) or 1
				if limit and limit[1] == '!' and number == limit[2] then number = number + 1 end
				stats[id] = number
			end
			for _, range in ipairs({ false, true }) do
				local input = copyTable(stats)
				if range then for id, value in pairs(input) do input[id] = { min = value, max = value + 1 } end end
				local originalOk, original, originalMap = pcall(before, copyTable(input), scope, description.gem_quality)
				local actualOk, actual, actualMap = pcall(after, copyTable(input), scope, description.gem_quality)
				assert(originalOk == actualOk, scope .. ': 算法错误状态变化 / ' .. tostring(actual))
				if not originalOk then
					assert(tostring(original):match(':%d+: (.*)') == tostring(actual):match(':%d+: (.*)'), scope .. ': 算法错误内容变化')
					unavailable = unavailable + 1
				else
				assert(#actual == #original, scope .. ': 行数变化 / ' .. description.text .. ' / ' .. json.encode(input) .. '\n' .. json.encode(original) .. '\n' .. json.encode(actual))
				for index, text in ipairs(original) do
					assert(actual[index] == text, scope .. ': ' .. tostring(actual[index]) .. ' ~= ' .. text)
					assert(actualMap[text] == originalMap[text], scope .. ': 属性身份映射变化')
					count = count + 1
				end
				samples = samples + 1
				end
			end
		end
	end
end
print('英文属性描述对照通过：' .. samples .. ' 个数值/范围样本，' .. count .. ' 行文字及属性身份。')
print('两套算法共同不支持的开发数据样本：' .. unavailable .. '，未计入通过范围。')
