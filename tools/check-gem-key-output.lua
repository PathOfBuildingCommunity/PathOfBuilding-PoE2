-- 遍历宝石和装备名称，对照原英文显示及业务字段，防止格式和名称在迁移中改变。
package.cpath = '../runtime/?.dll;' .. package.cpath
package.path = '../runtime/lua/?.lua;../runtime/lua/?/init.lua;' .. package.path
arg = { }
io.stdout:setvbuf('no')
io.read = function() error('宝石对照禁止等待交互') end
dofile('HeadlessWrapper.lua')
assert(build and not launch.promptMsg, 'PoB2 初始化失败')
localisation:SetLanguage('en')
local before = LoadModule('Tests/Run/GemTooltip-before-keys')
local after = LoadModule('Classes/GemTooltip')
local count, items = 0, 0

-- 保留真实提示框路径，以同一构筑、同一等级与品质比较完整显示行。
local function capture(module, instance)
	local tooltip = new('Tooltip'):Tooltip()
	tooltip.maxWidth = nil
	local copy = { }
	for key, value in pairs(instance) do copy[key] = value end
	module.AddGemTooltip(tooltip, build, copy, { includeBuildPlannerNote = true })
	local lines = { }
	for _, line in ipairs(tooltip.lines) do
		if line.text then lines[#lines + 1] = line.text end
	end
	return table.concat(lines, '\n')
end

for id, gem in pairsSortByKey(data.gems) do
	for _, level in ipairs({ 1, math.min(20, gem.naturalMaxLevel or 20) }) do
		local instance = { gemData = gem, grantedEffect = gem.grantedEffect, level = level, quality = 20, nameSpec = gem.name }
		local expected, actual = capture(before, instance), capture(after, instance)
		assert(actual == expected, id .. ' 等级 ' .. level .. '\n' .. actual .. '\n~=\n' .. expected)
		count = count + 1
	end
end
for _, list in pairs(data.uniques) do
	for _, raw in ipairs(list) do
		local item = new('Item'):Item(raw, 'UNIQUE')
		assert(localisation:ItemName(item) == item.name, '唯一装备英文名称变化: ' .. item.name)
		items = items + 1
	end
end
for _, raw in ipairs(data.rares) do
	local item = new('Item'):Item(raw, 'RARE', true)
	if item.base then
		if item.crafted then item:Craft() end
		assert(localisation:ItemName(item) == item.name, '稀有模板英文名称变化: ' .. item.name .. ' / ' .. localisation:ItemName(item))
		items = items + 1
	end
end
print('英文宝石提示框对照通过：' .. count .. ' 个等级样本；装备名称 ' .. items .. ' 个。')
