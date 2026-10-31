-- 枚举真实装备提示框和列表，保存实际显示仍含拉丁文字的行，供逐条校对。
package.cpath = '../runtime/?.dll;' .. package.cpath
package.path = '../runtime/lua/?.lua;../runtime/lua/?/init.lua;' .. package.path
arg = { }
io.stdout:setvbuf('no')
io.read = function() error('审计禁止等待交互') end
dofile('HeadlessWrapper.lua')
main.userPath = 'Tests/Run/'
main.showFlavourText, main.notSupportedModTooltips = true, true
build.itemsTab.showStatDifferences = false
local csv = assert(io.open('../docs/localisation-item-display-missing.csv', 'wb'))
csv:write('language,domain,item,source,display\n')
local domains = { }
local function quote(text) return '"' .. tostring(text):gsub('"', '""') .. '"' end
local function record(language, domain, item, text, source)
	if text:find('%a') then
		csv:write(quote(language), ',', quote(domain), ',', quote(item), ',', quote(source or text), ',', quote(text), '\n')
		domains[language] = domains[language] or { }
		domains[language][domain] = (domains[language][domain] or 0) + 1
		return true
	end
end
local counts = { }
for _, language in ipairs({ 'zh-CN', 'zh-TW' }) do
	localisation:SetLanguage(language)
	local totals = { bases = 0, baseMissing = 0, items = 0, lines = 0, latinLines = 0, labels = 0, labelMissing = 0, errors = 0 }
	for name in pairs(data.itemBases) do
		local source = name:gsub(' %(.+%)', '')
		totals.bases = totals.bases + 1
		local translated = localisation:DataText('equipment_base', name, 'name', source)
		if translated == source and source:find('%a') then totals.baseMissing = totals.baseMissing + 1 end
		record(language, 'base', name, translated, source)
	end
	for _, statList in ipairs({ build.displayStats, build.minionDisplayStats }) do
		for _, stat in ipairs(statList) do
			if stat.stat and stat.label then
				totals.labels = totals.labels + 1
				local translated = localisation:Field(stat, 'label')
				if translated == stat.label then totals.labelMissing = totals.labelMissing + 1 end
				record(language, 'comparison-label', stat.stat, translated, stat.label)
			end
		end
	end
	for kind, entries in pairsSortByKey(data.uniques) do
		for index, raw in ipairs(entries) do
			local item = new('Item'):Item(raw, 'UNIQUE')
			totals.items = totals.items + 1
			local tooltip = new('Tooltip'):Tooltip()
			-- 保存拆行前源文，确保缺口能够追溯到真实字段，而不只留下片段译文。
			local addLine = tooltip.AddLine
			tooltip.AddLine = function(self, size, source, ...)
				local first = #self.lines + 1
				addLine(self, size, source, ...)
				for i = first, #self.lines do self.lines[i].auditSource = source end
			end
			local ok, err = pcall(build.itemsTab.AddItemTooltip, build.itemsTab, tooltip, item, nil, true)
			if not ok then totals.errors = totals.errors + 1; record(language, 'error', item.name, tostring(err)) end
			record(language, 'list-name', item.name, StripEscapes(build.itemsTab.controls.uniqueDB:GetRowValue(1, index, item)), item.name)
			for _, line in ipairs(tooltip.lines) do
				if line.text then
					totals.lines = totals.lines + 1
					local source = line.auditSource or line.text
					local domain = line.modLine and 'tooltip.modifier' or line.font == 'FONTIN SC ITALIC' and 'tooltip.flavour' or source:find('Tip:', 1, true) and 'tooltip.hint' or (source:find('Source:', 1, true) or source:find('Exclusive to:', 1, true)) and 'tooltip.source' or 'tooltip.property'
					if record(language, domain, item.name, StripEscapes(line.text), source) then totals.latinLines = totals.latinLines + 1 end
				end
			end
		end
		print(language .. ' ' .. kind .. ' complete')
	end
	counts[language] = totals
end
csv:close()
local report = assert(io.open('../docs/localisation-item-display-audit.md', 'wb'))
report:write('# 装备实际显示审计\n\n生成日期：2026-10-31。命令：在 `src` 目录运行 `..\\tools\\LuaRunner.exe ..\\tools\\audit-item-display.lua`。\n\n使用真实 Item、ItemsTab:AddItemTooltip 和数据库 GetRowValue，启用风味文本及不支持附注。扫描当前默认变体；未遍历全部历史版本、分组变体、稀有词缀组合及 Shift 展开的技能子提示框。比较栏检查真实字段标签，数值拼接另外由集成测试覆盖。\n\n| 语言 | 基底数 | 原文回退基底 | 传奇样本 | 提示框行 | 含拉丁字母行 | 比较标签 | 原文回退标签 | 构建异常 |\n|---|---:|---:|---:|---:|---:|---:|---:|---:|\n')
for _, language in ipairs({ 'zh-CN', 'zh-TW' }) do
	local c = counts[language]
	report:write(string.format('| %s | %d | %d | %d | %d | %d | %d | %d | %d |\n', language, c.bases, c.baseMissing, c.items, c.lines, c.latinLines, c.labels, c.labelMissing, c.errors))
end
report:write('\n| 待复核输出域 | 简体含拉丁行 | 繁体含拉丁行 |\n|---|---:|---:|\n')
for _, domain in ipairs({ 'base', 'list-name', 'comparison-label', 'tooltip.property', 'tooltip.modifier', 'tooltip.flavour', 'tooltip.source', 'tooltip.hint', 'error' }) do
	report:write(string.format('| %s | %d | %d |\n', domain, domains['zh-CN'][domain] or 0, domains['zh-TW'][domain] or 0))
end
report:write('\n`localisation-item-display-missing.csv` 按属性、词缀、风味、来源、提示等域保存实际含拉丁字母输出，并携带拆行前源文与装备定位；其中包含 PoB、Shift、Ctrl、DPS 等合理保留项，不能直接当作未翻译数量。没有拉丁字母也不等于术语准确。该审计使用图形桩，不能代替原生窗口布局和交互验收。\n')
report:close()
print(require('dkjson').encode(counts))
assert(counts['zh-CN'].errors == 0 and counts['zh-TW'].errors == 0, '装备提示框存在构建异常')
