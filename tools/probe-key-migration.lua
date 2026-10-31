-- 保存真实界面控件的英文输出，用于逐模块迁移前后对照。
package.cpath = '../runtime/?.dll;' .. package.cpath
package.path = '../runtime/lua/?.lua;../runtime/lua/?/init.lua;' .. package.path
arg = { }
local read = io.read
io.read = function() error('无界面启动失败，禁止等待交互') end
dofile('HeadlessWrapper.lua')
io.read = read
assert(build and not __mainObject__.promptMsg, 'PoB2 初始化失败')
localisation:SetLanguage('en')
local result, visited = { }, { }
local json = require('dkjson')
local baselineFile = assert(io.open('Tests/Run/key-migration-display-baseline.json', 'rb'))
local baseline = assert(json.decode(baselineFile:read('*a'))); baselineFile:close()

-- 只沿控件所有权递归，避免把共享计算对象误当作文案。
local function controls(owner, origin)
	if type(owner) ~= 'table' or visited[owner] then return end
	visited[owner] = true
	if owner.GetProperty then
		for _, field in ipairs({ 'label', 'prompt', 'tooltipText' }) do
			local ok, value = pcall(owner.GetProperty, owner, field)
			assert(ok or baseline[origin .. '.' .. field] == nil, origin .. '.' .. field .. ': ' .. tostring(value))
			if ok and type(value) == 'string' then result[origin .. '.' .. field] = value end
		end
	end
	for name, control in pairs(owner.controls or { }) do controls(control, origin .. '.controls.' .. tostring(name)) end
end
controls(build, 'build')
for _, name in ipairs({ 'treeTab', 'skillsTab', 'itemsTab', 'calcsTab', 'configTab', 'notesTab', 'importTab', 'partyTab', 'compareTab' }) do controls(build[name], 'build.' .. name) end
controls(main.modes.LIST, 'list')
main:OpenOptionsPopup()
controls(main.popups[#main.popups], 'options')
local file = assert(io.open('Tests/Run/key-migration-display.json', 'wb'))
file:write(json.encode(result)); file:close()
local count = 0
for _ in pairs(result) do count = count + 1 end
print(string.format('已保存 %d 个真实控件英文输出。', count))
