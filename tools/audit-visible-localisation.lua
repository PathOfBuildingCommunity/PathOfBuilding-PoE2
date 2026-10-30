-- 逐页绘制并构建全部天赋、技能提示框，记录真正送入显示层的英文残留。
package.cpath = '../runtime/?.dll;' .. package.cpath
package.path = '../runtime/lua/?.lua;../runtime/lua/?/init.lua;' .. package.path
arg = { }
io.stdout:setvbuf('no')
io.read = function() error('审计禁止等待交互') end
dofile('HeadlessWrapper.lua')
assert(build and not launch.promptMsg, 'PoB2 初始化失败')
main.userPath = 'Tests/Run/'
main.showFlavourText, main.notSupportedModTooltips = true, true
local output = assert(io.open('../docs/localisation-visible-missing.csv', 'wb'))
output:write('language,scope,origin,status,source,display\n')
local scope, owner, seen, counts = 'startup', '', { }, { }
local allowed = { PoB = true, PoE = true, PoE2 = true, DPS = true, ES = true, EHP = true, FPS = true, Ctrl = true, Shift = true, Alt = true, D = true, V = true, C = true, X = true }
-- CSV 保留多行实际显示，避免拆行片段失去上下文。
local function quote(value) return '"' .. tostring(value):gsub('"', '""') .. '"' end
-- 每个场景去重并粗分英文残留，正常缩写仍保留供人工复核。
local function record(source, display, origin, errorStatus)
	if type(source) ~= 'string' or type(display) ~= 'string' then return end
	source, display = StripEscapes(source), StripEscapes(display)
	local key = localisation.language .. '\0' .. scope .. '\0' .. source .. '\0' .. display
	if seen[key] then return end
	seen[key] = true
	local summaryKey = localisation.language .. '|' .. scope
	local summary = counts[summaryKey] or { texts = 0, fallback = 0, partial = 0, allowed = 0, errors = 0 }
	counts[summaryKey] = summary; summary.texts = summary.texts + 1
	local status = errorStatus
	if errorStatus then
		summary.errors = summary.errors + 1
	elseif localisation.language == 'en' or not display:find('%a') then return
	else
		local onlyAllowed = true
		for word in display:gmatch('%a[%a%d]*') do if not allowed[word] then onlyAllowed = false end end
		status = onlyAllowed and 'allowed-only' or source == display and 'fallback' or 'partial'
		summary[status == 'allowed-only' and 'allowed' or status] = summary[status == 'allowed-only' and 'allowed' or status] + 1
	end
	local values = { localisation.language, scope, owner .. ' ' .. (origin or ''), status, source, display }
	for i, value in ipairs(values) do values[i] = quote(value) end
	output:write(table.concat(values, ',') .. '\n')
end
-- 定位业务调用位置，而不是把全部结果指向审计入口。
local function location(depth)
	local info = debug.getinfo(depth, 'Sl')
	return info and (info.short_src .. ':' .. info.currentline) or ''
end
local draw = DrawString
DrawString = function(x, y, align, size, font, text)
	-- 用户缓冲区原文不属于产品漏译；标签在进入原文绘制上下文前已翻译。
	if localisation.rawDepth == 0 then record(tostring(text or ''), localisation:Translate(tostring(text or '')), location(3)) end
	return draw(x, y, align, size, font, text)
end
-- 保留实际提示框拆行结果与拆行前文字之间的对应关系。
local function tooltip()
	local value = new('Tooltip'):Tooltip()
	local addLine = value.AddLine
	value.AddLine = function(self, size, source, ...)
		local origin = location(3)
		local first = #self.lines + 1
		-- 批量清点完整句子，不对每个技能反复测量换行片段；布局验证仍由真实换行回归承担。
		local savedWidth = self.maxWidth
		self.maxWidth = nil
		addLine(self, size, source, ...)
		self.maxWidth = savedWidth
		local lines = { }
		for i = first, #self.lines do if self.lines[i].text then lines[#lines + 1] = self.lines[i].text end end
		if #lines > 0 then record(source, table.concat(lines, '\n'), origin) end
	end
	return value
end
-- 单个样本失败时继续扫描，完整堆栈进入报告。
local function attempt(callback)
	local ok, err = xpcall(callback, debug.traceback)
	if not ok then record('审计调用异常', tostring(err), '', 'error') end
	return ok
end
-- 只读取无参数提示属性，不猜测需要特定上下文的回调参数。
local function controls(host, prefix, visited)
	if not host or visited[host] then return end
	visited[host] = true
	for id, control in pairs(host.controls or { }) do
		owner = prefix .. '.' .. tostring(id)
		attempt(function()
			local text = control:GetProperty('tooltipText')
			if type(text) == 'string' then local t = tooltip(); t:AddLine(16, text) end
		end)
		controls(control, prefix .. '.' .. tostring(id), visited)
	end
end
local viewport = { x = 0, y = 0, width = 1920, height = 1080 }
local gemTooltip = LoadModule('Classes/GemTooltip')
-- 全遍历会重复翻译同一技能片段；只缓存审计期间不变词库的纯函数结果，不改产品代码。
local function memoiseDictionary(language)
	local dictionary = localisation.dictionaries[language]
	if not dictionary then return end
	local original, memo = dictionary.Translate, { }
	dictionary.Translate = function(self, text, reverse)
		local key = (reverse and 'r' or 'f') .. text
		if memo[key] ~= nil then return memo[key] end
		local result = original(self, text, reverse)
		memo[key] = result
		return result
	end
end
for _, language in ipairs({ 'en', 'zh-CN', 'zh-TW' }) do
	localisation:SetLanguage(language)
	memoiseDictionary(language)
	for _, mode in ipairs({ 'IMPORT', 'NOTES', 'PARTY', 'CONFIG', 'TREE', 'SKILLS', 'ITEMS', 'CALCS', 'COMPARE' }) do
		scope, owner = 'page.' .. mode, 'blank-build'
		build.viewMode = mode
		attempt(function() build:OnFrame({ }) end)
	end
	scope, owner = 'options', 'Options'
	attempt(function()
		main:OpenOptionsPopup()
		main.popups[1]:Draw(viewport)
		controls(main.popups[1], 'options', { })
	end)
	main.popups = { }
	scope = 'control.tooltip'
	for _, name in ipairs({ 'importTab', 'notesTab', 'partyTab', 'configTab', 'treeTab', 'skillsTab', 'itemsTab', 'calcsTab', 'compareTab' }) do controls(build[name], name, { }) end
	print(language .. ' 页面及控件提示框扫描完成')
	scope = 'tree.tooltip'
	build.treeTab.viewer.showStatDifferences = false
	build.treeTab.viewer.skillTooltip = tooltip()
	local nodes = 0
	for id, node in pairsSortByKey(build.spec.nodes) do
		owner = tostring(id) .. ':' .. tostring(node.dn)
		attempt(function() build.treeTab.viewer:AddNodeTooltip(tooltip(), node, build, 0) end)
		nodes = nodes + 1
	end
	print(language .. ' ' .. nodes .. ' 个天赋提示框扫描完成')
	scope = 'gem.tooltip'
	local gems = 0
	for id, gem in pairsSortByKey(data.gems) do
		owner = id
		attempt(function()
			local instance = { gemData = gem, grantedEffect = gem.grantedEffect, level = math.min(20, gem.naturalMaxLevel or 20), quality = 20, nameSpec = gem.name }
			gemTooltip.AddGemTooltip(tooltip(), build, instance, { includeBuildPlannerNote = true })
		end)
		gems = gems + 1
	end
	print(language .. ' ' .. gems .. ' 个技能提示框扫描完成')
end
DrawString = draw
output:close()
local report = assert(io.open('../docs/localisation-visible-audit.md', 'wb'))
report:write('# 实际显示路径扫描\n\n生成日期：2026-10-30。命令：在 src 目录运行 `..\\tools\\LuaRunner.exe ..\\tools\\audit-visible-localisation.lua`。\n\n执行 English、简体、繁体的九个构筑页面、选项页、递归控件提示文字、当前树的全部节点提示框（关闭属性比较，包含授予技能子提示框）和全部宝石的 20 级/20 品质提示框（自然最高等级不足 20 时使用自然最高等级）。没有点击购买、更新或外部服务。用户编辑原文保留，不算漏译。\n\n批量提示框关闭自动换行，以完整句子统计翻译；缓存优化前后的两个保留换行版本曾对照 1,189 条简体非宝石残留记录，结果一致，另有 40 个缓存前后结果等价探针。这些对照不证明本次完整句子结果与换行片段逐行一致。审计期间仅缓存固定词库的纯函数结果。代表样本换行路径有集成回归，不能据此宣称全节点/技能的换行布局通过。\n\n此扫描使用图形桩调用实际 Lua 绘制/提示框逻辑；不证明原生窗口布局、字体输入法、网络流程、隐藏弹窗和全部动态状态已验收。控件 tooltipFunc 没有强行用不完整参数调用；其字符串仍在全仓源码候选中。统计按语言/场景/源文/输出去重；allowed-only 只作常见缩写与按键的粗分，不保证语义正确。\n\n| 语言与场景 | 唯一文本/异常 | 原文回退 | 部分英文 | 仅保留项 | 调用异常 |\n|---|---:|---:|---:|---:|---:|\n')
for key, count in pairsSortByKey(counts) do
	report:write(string.format('| %s | %d | %d | %d | %d | %d |\n', key:gsub('%|', ' / '), count.texts, count.fallback, count.partial, count.allowed, count.errors))
end
report:write('\n定位与完整实际输出见 `localisation-visible-missing.csv`。所有异常保留原始堆栈，须区分审计输入缺失与产品缺陷。英文基线异常同时出现时不能归因于汉化。\n')
report:close()
print('实际显示报告已生成')
