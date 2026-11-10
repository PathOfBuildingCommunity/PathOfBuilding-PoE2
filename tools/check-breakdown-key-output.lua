-- 对照迁移前的计算模块，验证真实构筑的数值和英文计算报告。
package.cpath = '../runtime/?.dll;' .. package.cpath
package.path = '../runtime/lua/?.lua;../runtime/lua/?/init.lua;' .. package.path
arg = { }
io.stdout:setvbuf('no')
io.read = function() error('计算对照禁止等待交互') end
dofile('HeadlessWrapper.lua')
assert(build and not launch.promptMsg, 'PoB2 初始化失败')
main.userPath = 'Tests/Run/'
localisation:SetLanguage('en')
local calcs = require('Modules.CalcBase')
local modules = { 'CalcSetup', 'CalcPerform', 'CalcOffence', 'CalcDefence', 'CalcTriggers' }

-- 两套算法使用同一业务对象契约，只切换本批迁移涉及的计算模块。
local function selectModules(original)
	for _, name in ipairs(modules) do
		LoadModule(original and ('Tests/Run/' .. name .. '-before-keys') or ('Modules/' .. name))
	end
	calcs.breakdownModule = original and 'Tests/Run/CalcBreakdown-before-keys' or 'Modules/CalcBreakdown'
	wipeGlobalCache()
end

-- 仅比较输出标量和报告数据，跳过显示元数据及报告引用的业务对象。
local function flatten(object, path, result, visited)
	if type(object) ~= 'table' then
		if type(object) == 'number' or type(object) == 'string' or type(object) == 'boolean' then result[path] = object end
		return
	end
	if visited[object] then return end
	visited[object] = true
	for key, value in pairs(object) do
		local metadata = false
		if type(key) == 'string' then
			for _, suffix in ipairs({ 'Key', 'Params', 'Tokens', 'Prefix', 'Suffix', 'Display' }) do
				if key:sub(-#suffix) == suffix then metadata = true; break end
			end
		end
		local runtime = type(key) == 'string' and ({ sourceGem = true, activeEffect = true, skillData = true, modDB = true, mod = true, flags = true, keywordFlags = true, sourceGem = true })[key]
		if not metadata and not runtime and key ~= 'formatKey' and key ~= 'formatParams' and key ~= 'item' and key ~= 'node' and key ~= 'modList' then
			flatten(value, path .. '.' .. tostring(key), result, visited)
		end
	end
end

-- 每次重新导入同一份构筑，避免缓存和上一轮对象变更影响结果。
local function capture(xml, original)
	selectModules(original)
	loadBuildFromXML(xml, '计算报告对照')
	local env = calcs.buildOutput(build, 'CALCS')
	local result = { }
	for _, actor in ipairs({ 'player', 'minion' }) do
		if env[actor] then
			flatten(env[actor].output, actor .. '.output', result, { })
			flatten(env[actor].breakdown, actor .. '.breakdown', result, { })
		end
	end
	return result
end

local count, numericalCount, correctedNotes = 0, 0, 0
for _, id in ipairs({ 'resurrectgodaura', 'goodnerfing', 'xxthewizardofosu' }) do
	local file = assert(io.open('Tests/Fixtures/poe-ninja/' .. id .. '.xml', 'rb'))
	local xml = file:read('*a'); file:close()
	local expected, actual = capture(xml, true), capture(xml, false)
	for path, value in pairs(expected) do
		-- 旧版本把混沌护盾说明的布尔条件当成正文；仅允许这两处精确的已回归修正。
		if type(value) == 'string' and value:match('Energy Shieldtrue$') and path:match('%.breakdown%.ChaosTakenHit%.%d+$')
			or type(value) == 'string' and value:match('^Energy Shield: %d+true$') and path:match('%.breakdown%.ChaosTotalPool%.%d+$') then
			value = value:gsub('true$', '^8 (ES takes double damage from chaos)')
			correctedNotes = correctedNotes + 1
		end
		assert(actual[path] == value or type(value) == 'number' and value ~= value and actual[path] ~= actual[path], id .. ': ' .. path .. '\n' .. tostring(actual[path]) .. ' ~= ' .. tostring(value))
		count = count + 1
	end
	for path in pairs(actual) do assert(expected[path] ~= nil, id .. ': 新增非显示元数据 ' .. path) end
	print(id .. ' 数值和英文报告一致')
	-- 中文报告的词序可以变化，但计算输出的字段、类型和数值不能受语言影响。
	for _, language in ipairs({ 'zh-CN', 'zh-TW' }) do
		localisation:SetLanguage(language)
		local translated = capture(xml, false)
		for path, value in pairs(expected) do
			if path:find('.output.', 1, true) then
				assert(translated[path] == value or type(value) == 'number' and value ~= value and translated[path] ~= translated[path], id .. ' ' .. language .. ': 计算输出变化 ' .. path)
				numericalCount = numericalCount + 1
			end
		end
		for path in pairs(translated) do
			if path:find('.output.', 1, true) then assert(expected[path] ~= nil, id .. ' ' .. language .. ': 新增计算字段 ' .. path) end
		end
	end
	localisation:SetLanguage('en')
end
selectModules(false)
print('计算报告对照通过：' .. count .. ' 个输出标量。')
print('其中已核对的混沌护盾说明修正：' .. correctedNotes .. ' 处；其余英文报告保持。')
print('简繁计算输出对照通过：' .. numericalCount .. ' 个输出标量。')
