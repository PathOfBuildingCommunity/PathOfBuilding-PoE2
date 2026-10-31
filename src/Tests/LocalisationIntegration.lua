-- 加载真实 PoB2 应用进行集成检查；不登录账号或请求角色 API。
package.cpath = '../runtime/?.dll;' .. package.cpath
package.path = '../runtime/lua/?.lua;../runtime/lua/?/init.lua;' .. package.path
arg = { }
local read = io.read
io.read = function() error('无界面启动失败，禁止等待交互') end
dofile('HeadlessWrapper.lua')
io.read = read
assert(build and not __mainObject__.promptMsg, 'PoB2 初始化失败')
-- 设置回归使用独立目录，避免测试覆盖正在使用的个人配置。
local ready = assert(io.open('Tests/Run/.ready', 'rb'), '请通过 test-localisation.cmd 准备隔离目录')
ready:close()
main.userPath = 'Tests/Run/'
local assertions = 0
local function equal(actual, expected, label)
	assertions = assertions + 1
	assert(actual == expected, label .. ': ' .. tostring(actual) .. ' ~= ' .. tostring(expected))
end

-- 开发警告须经过启动队列，正文和颜色保持，中文各行适配固定提示框宽度。
equal(launch.devMode, true, '仓库启动触发开发模式警告')
equal(main.toastMessages[1].key, 'ui.main.init.developer_mode_warning', '启动队列保留开发警告资源身份')
local warningLanguage = localisation.language
local warningFont = dofile('Modules/Localisation/Font.lua').New('Locales/Fonts')
-- 使用真实主帧绘制队列，复现警告出现后切换语言，而不是重新创建警告。
local warningFrame = setmetatable({
	inputEvents = { }, popups = { }, onFrameFuncs = { }, toastMessages = { main.toastMessages[1] },
	toastMode = 'SHOWN', mainBarHeight = 58,
	CallMode = function() end, ProcessControlsInput = function() end, DrawControls = function() end,
}, { __index = main })
for _, language in ipairs({ 'en', 'zh-CN', 'zh-TW', 'en' }) do
	localisation:SetLanguage(language)
	local warning = localisation:Text('ui.main.init.developer_mode_warning')
	local title, body = warning:match('^([^\n]+)\n(.*)$')
	local originalDraw, drawn = DrawString, { }
	DrawString = function(left, top, align, height, font, text)
		if left == 4 then drawn[height] = text end
	end
	warningFrame:OnFrame()
	DrawString = originalDraw
	equal(drawn[20], title, language .. ' 切换后实际警告标题刷新')
	equal(drawn[16], body, language .. ' 切换后实际警告正文刷新')
	equal(warningFrame.toastHeight, select(2, warning:gsub('\n', '')) * 16 + 60, language .. ' 切换后警告高度适配当前语言')
	equal(title:sub(1, 8), '^xFF7700', language .. ' 警告标题保留橙色')
	equal(title:find('^7', 1, true) ~= nil, true, language .. ' 警告正文标题保留白色')
	if language == 'en' then
		equal(warning, '^xFF7700Warning: ^7Developer Mode active!\nThe program is currently running in developer\nmode, which is not intended for normal use.\nIf you are not expecting this, then you may have\nset up the program from the source .zip instead\nof using one of the installers. If that is the case,\nplease reinstall using one of the installers from\nthe "Releases" section of the GitHub page.', '英文开发警告与原文及换行一致')
	else
		equal(title, language == 'zh-CN' and '^xFF7700警告：^7已启用开发模式！' or '^xFF7700警告：^7已啟用開發模式！', language .. ' 开发警告标题已翻译')
		equal(body:gsub('GitHub', ''):gsub('Releases', ''):gsub('zip', ''):find('%a'), nil, language .. ' 开发警告正文无英文残留')
		equal(warningFont:Layout(20, title).width <= 300, true, language .. ' 警告标题适配面板宽度')
		for line in body:gmatch('[^\n]+') do equal(warningFont:Layout(16, line).width <= 300, true, language .. ' 警告正文行适配面板宽度') end
	end
end
localisation:SetLanguage(warningLanguage)

equal(localisation:SetLanguage(nil), 'en', '未指定语言回退默认语言')
localisation:SetLanguage('zh-CN')
local edit = new('EditControl'):EditControl(nil, {0, 0, 200, 20}, '')
edit:Insert('中文A')
equal(edit.buf, '中文A', '中文输入')
edit:OnKeyDown('LEFT')
equal(edit.caret, 7, '英文光标后退')
edit:OnKeyDown('BACK')
equal(edit.buf, '中A', '退格删除完整汉字')
equal(edit.caret, 4, '退格后光标')
edit:SetText('中文A'); edit.caret = 1; edit:OnKeyDown('DELETE')
equal(edit.buf, '文A', 'Delete 删除完整汉字')
local savedPaste, savedKey = Paste, IsKeyDown
Paste = function() return '中文粘贴' end
IsKeyDown = function(key) return key == 'CTRL' end
edit:SetText(''); edit:OnKeyDown('v')
Paste, IsKeyDown = savedPaste, savedKey
equal(edit.buf, '中文粘贴', '剪贴板保持 UTF-8')

-- 配置页的默认占位值可能是数字，必须走真实编辑控件绘制回归。
local viewPort = { x = 0, y = 0, width = 1920, height = 1080 }
for _, language in ipairs({ 'en', 'zh-CN', 'zh-TW', 'ja-JP', 'ko-KR' }) do
	localisation:SetLanguage(language)
	for _, value in ipairs({ 0, -5, 12.5 }) do
		edit:SetText('')
		edit.placeholder = value
		local drawn, err = pcall(edit.Draw, edit, viewPort)
		equal(drawn, true, language .. ' 数值占位符绘制 ' .. tostring(value) .. ': ' .. tostring(err))
		equal(edit.placeholder, value, language .. ' 绘制不改写数值占位符')
	end
	local drawn, err = pcall(build.configTab.Draw, build.configTab, viewPort, { })
	equal(drawn, true, language .. ' 配置页完整绘制: ' .. tostring(err))
	equal(localisation.rawDepth, 0, language .. ' 绘制后恢复原文上下文')
end
edit.placeholder = nil
localisation:SetLanguage('zh-CN')

dofile('Tests/LocalisationDisplayBoundary.lua')(build, equal)

dofile('Tests/LocalisationLanguageSelector.lua')(equal)

dofile('Tests/LocalisationEquipment.lua')(build, equal)
dofile('Tests/LocalisationEquipmentDetails.lua')(build, equal)
dofile('Tests/LocalisationCrafting.lua')(build, equal)
dofile('Tests/LocalisationRarePresets.lua')(build, equal)
dofile('Tests/LocalisationKeyFields.lua')(build, equal)
dofile('Tests/LocalisationTreeContext.lua')(build, equal)
dofile('Tests/LocalisationTreePresentation.lua')(build, equal)
dofile('Tests/LocalisationFlavour.lua')(build, equal)
dofile('Tests/LocalisationConfig.lua')(build, equal)
dofile('Tests/LocalisationKeyLists.lua')(build, equal)
dofile('Tests/LocalisationSkills.lua')(build, equal)
dofile('Tests/LocalisationDynamicSkills.lua')(build, equal)
dofile('Tests/LocalisationSkillBranches.lua')(build, equal)
dofile('Tests/LocalisationMinionConfig.lua')(build, equal)
dofile('Tests/LocalisationWorldAreas.lua')(build, equal)
dofile('Tests/LocalisationInterfaceFollowup.lua')(build, equal)
localisation:SetLanguage('zh-CN')

local clipboard = Paste
Paste = function() return 'Fireball 20/0 1' end
local beforeChinesePaste = #build.skillsTab.socketGroupList
build.skillsTab:PasteSocketGroup()
Paste = clipboard
local chinesePaste = Paste
Paste = function() return '火球 20/0 1' end
build.skillsTab:PasteSocketGroup()
Paste = chinesePaste
equal(#build.skillsTab.socketGroupList, beforeChinesePaste + 2, '中文技能组剪贴板创建技能组')
equal(build.skillsTab.socketGroupList[#build.skillsTab.socketGroupList].gemList[1].nameSpec, 'Fireball', '中文技能组剪贴板保留英文业务身份')
local selector = build.skillsTab.gemSlots[1].nameSpec
selector:SetText('')
selector:Insert('火球')
equal(selector.buf, '火球', '技能搜索框接受汉字')
selector:BuildList('火球')
local found = false
for _, id in ipairs(selector.list) do if selector.gems[id] and selector.gems[id].name == 'Fireball' then found = true end end
equal(found, true, '真实技能列表中文搜索')
selector:BuildList('Fireball')
equal(selector.noMatches, false, '英文技能搜索保持可用')
equal(('Fireball'):matchOrPattern('火球'), false, '公共原文搜索不再隐式反查译名')
equal(localisation:MatchField(data.skills.FireballPlayer, 'name', '火球'), true, '显式技能字段支持中文搜索')
equal(localisation:TagName({ melee = true }, '近战'), 'melee', '中文标签搜索')
local englishWidth = localisation:MeasureRaw(16, 'VAR', 'Fireball')
equal(englishWidth, DrawStringWidth(16, 'VAR', 'Fireball'), '绘制测宽不再隐式翻译英文')
assert(type(localisation:MeasureRaw(12, 'VAR', 12345)) == 'number', '数值计算结果测宽')
local font = dofile('Modules/Localisation/Font.lua').New('Locales/Fonts')
equal(localisation:MeasureRaw(16, 'VAR', 'A', 'A中文'), font:Layout(16, 'A').width, '混排编辑框前缀测宽')
localisation:DrawRaw(function()
	equal(DrawStringWidth(16, 'VAR', 'A'), font:Layout(16, 'A').width, '混排绘制片段使用同一字体')
end, { buf = 'A中文' })
local ok = pcall(function() localisation:DrawRaw(function() error('预期异常') end, {}) end)
equal(ok, false, '保留绘制异常')
equal(localisation.rawDepth, 0, '异常后恢复字体上下文')

local cnBase = localisation:DataText('equipment_base', 'Lapis Amulet', 'name', 'Lapis Amulet')
assert(cnBase ~= 'Lapis Amulet', '测试物品基底缺少译名')
local translatedTitle, translatedBase = localisation:ItemTitle({ title = 'Alkem Eira', baseName = 'Blazon Crest Shield' })
equal(translatedTitle, '神谕', '物品唯一名称按字段翻译')
equal(translatedBase, '饰印纹章盾', '新版物品基底翻译')
local _, unknownBase = localisation:ItemTitle({ baseName = 'Unknown Localisation Test Base' })
equal(unknownBase, 'Unknown Localisation Test Base', '未知物品基底保留原文')
local raw = '稀有度: 普通\n' .. cnBase .. '\n--------\n物品等级: 80\n'
build.itemsTab:CreateDisplayItemFromRaw(raw, true)
assert(build.itemsTab.displayItem, '中文物品未被实际解析器识别')
equal(build.itemsTab.displayItem.baseName, 'Lapis Amulet', '中文物品粘贴到真实物品解析器')
equal(build.itemsTab.displayItem.rarity, 'NORMAL', '稀有度转换')

local character = {
	level = 10,
	equipment = {{ id = 'localisation-fixture', name = '', typeLine = cnBase, baseType = cnBase,
		inventoryId = 'Amulet', frameType = 0, ilvl = 80, properties = { }, requirements = { },
		explicitMods = {{ description = '+25 生命上限', flags = { fractured = true } }} }},
	skills = {{ typeLine = '火球', properties = {{ name = '等级', values = {{'1', 0}} }} }},
}
build.importTab:ImportItemsAndSkills(character)
local amulet = build.itemsTab.items[build.itemsTab.slots.Amulet.selItemId]
assert(amulet, '中文角色物品未装备到 PoB2 槽位')
equal(amulet.baseName, 'Lapis Amulet', 'PoB2 角色导入装备')
equal(amulet.uniqueID, 'localisation-fixture', '导入后保留物品唯一 ID')
equal(amulet.explicitModLines[1].line, '+25 to maximum Life', '对象形式中文修饰词进入真实解析器')
equal(amulet.explicitModLines[1].fractured, true, '导入后保留破裂标记')
assert(amulet.explicitModLines[1].modList and #amulet.explicitModLines[1].modList > 0, '中文修饰词没有解析为计算属性')
local importedFireball = false
for _, group in ipairs(build.skillsTab.socketGroupList) do
	for _, gem in ipairs(group.gemList) do if gem.nameSpec == 'Fireball' then importedFireball = true end end
end
equal(importedFireball, true, 'PoB2 角色导入中文技能')
equal(character.skills[1].typeLine, '火球', '实际导入未改写原 JSON 数据')

main:OpenOptionsPopup()
local popup = main.popups[#main.popups]
assert(popup.controls.language, '设置中缺少语言选项')
equal(#popup.controls.language.list, 5, '设置使用注册表中的五种首发语言')
popup.controls.language:SelByValue('en', 'id')
popup.controls.save.onClick()
equal(localisation.language, 'en', '保存设置后切换英文')
equal(localisation:Field(data.skills.FireballPlayer, 'name'), 'Fireball', '英文模式回退')
local file = assert(io.open(main.userPath .. 'Settings.xml', 'rb'))
local settings = file:read('*a'); file:close()
assert(settings:find('language="en"', 1, true), '语言设置未持久化')
localisation:SetLanguage('zh-CN')
main:LoadSettings(true)
equal(localisation.language, 'en', '从设置重新加载语言')
localisation:SetLanguage('zh-TW')
assert(localisation:Text('ui.main.init.options.label'):find('[\128-\255]'), '繁体词库未加载')
assert(localisation:Field(data.skills.ShieldBlockPlayer, 'name'):find('[\128-\255]'), '繁体技能名称按字段翻译')
local twBase = localisation:DataText('equipment_base', 'Lapis Amulet', 'name', 'Lapis Amulet')
assert(twBase ~= 'Lapis Amulet', '繁体物品基底缺少译名')
equal(localisation:ToEnglish(twBase), 'Lapis Amulet', '繁体物品反向转换')
equal(localisation:ItemText('稀有度: 普通\n' .. twBase .. '\n物品等級: 80'), 'Rarity: Normal\nLapis Amulet\nItem Level: 80', '繁体物品输入边界')
localisation:SetLanguage('missing-locale')
equal(localisation.language, 'en', '无效语言回退默认语言')
equal(localisation.invalidLanguage, 'missing-locale', '记录无效语言配置')
localisation:SetLanguage('zh-CN'); main:SaveSettings()

-- 保存提示的模式短语必须随当前语言解析，测试只读取并关闭弹窗，不执行保存、退出或更新动作。
for _, language in ipairs({ 'en', 'zh-CN', 'zh-TW' }) do
	localisation:SetLanguage(language)
	for _, mode in ipairs({ 'LIST', 'EXIT', 'UPDATE' }) do
		build:OpenSavePopup(mode)
		local savePopup = main.popups[#main.popups]
		local label = StripEscapes(savePopup.controls.label:GetProperty('label'))
		local expected = {
			LIST = language == 'en' and 'Do you want to save them now?' or language == 'zh-CN' and '是否要现在保存？' or '是否要現在儲存？',
			EXIT = language == 'en' and 'Do you want to save them before exiting?' or language == 'zh-CN' and '是否要在退出前保存？' or '是否要在退出前儲存？',
			UPDATE = language == 'en' and 'Do you want to save them before updating?' or language == 'zh-CN' and '是否要在更新前保存？' or '是否要在更新前儲存？',
		}
		equal(label:find(expected[mode], 1, true) ~= nil, true, language .. ' 保存提示模式短语：' .. mode)
		main:ClosePopup()
	end
end
localisation:SetLanguage('zh-CN')

-- 天赋验收使用实际提示框内容，覆盖颜色码和换行产生的显示字符串。
for _, language in ipairs({ 'zh-CN', 'zh-TW' }) do
	localisation:SetLanguage(language)
	for _, id in ipairs({ 4, 16, 30, 40 }) do
		local node = assert(build.spec.nodes[id], '缺少天赋回归节点')
		local tooltip = new('Tooltip'):Tooltip()
		build.treeTab.viewer:AddNodeTooltip(tooltip, node, build, 0)
		local text = { }
		for _, line in ipairs(tooltip.lines) do
			if line.text then text[#text + 1] = StripEscapes(line.text) end
		end
		text = table.concat(text, '\n')
		equal(text:find(localisation:Field(node, 'dn'), 1, true) ~= nil, true, language .. ' 天赋标题进入真实提示框')
		equal(text:find(node.dn, 1, true), nil, language .. ' 天赋标题未保留英文')
		equal(text:find(localisation:Line(node, 'sd', 1), 1, true) ~= nil, true, language .. ' 天赋属性进入真实提示框')
	end
end

local languageTooltip = new('Tooltip'):Tooltip()
localisation:SetLanguage('zh-CN')
equal(languageTooltip:CheckForUpdate('language-fixture'), true, '提示框首次生成')
languageTooltip:AddLine(16, localisation:Field(data.skills.FireballPlayer, 'name'))
equal(languageTooltip.lines[1].text, '火球', '提示框保存当前语言译文')
equal(languageTooltip:CheckForUpdate('language-fixture'), nil, '同语言保留提示框缓存')
localisation:SetLanguage('en')
equal(languageTooltip:CheckForUpdate('language-fixture'), true, '切换语言使提示框缓存失效')
equal(#languageTooltip.lines, 0, '切换语言清理原提示框译文')
languageTooltip:AddLine(16, localisation:Field(data.skills.FireballPlayer, 'name'))
equal(languageTooltip.lines[1].text, 'Fireball', '切换英文后恢复原始名称')

-- 读取 poe.ninja 的公开 PoB2 导出，验证真实构筑可以被 PoB2 解析。
local dkjson = require('dkjson')
local poeNinjaFixtures = {
	{ id = 'resurrectgodaura', class = 'Martial Artist' },
	{ id = 'goodnerfing', class = 'Titan' },
	{ id = 'xxthewizardofosu', class = 'Smith of Kitava' },
}
for _, fixture in ipairs(poeNinjaFixtures) do
	local metaFile = assert(io.open('Tests/Fixtures/poe-ninja/' .. fixture.id .. '.json', 'rb'))
	local meta = dkjson.decode(metaFile:read('*a'))
	metaFile:close()
	local xmlFile = assert(io.open('Tests/Fixtures/poe-ninja/' .. fixture.id .. '.xml', 'rb'))
	local xml = xmlFile:read('*a')
	xmlFile:close()
	equal(meta.source, 'poe.ninja', fixture.id .. ' 来源')
	equal(meta.class, fixture.class, fixture.id .. ' 公开角色职业')
	assert(xml:find('<Items', 1, true), fixture.id .. ' 缺少装备段')
	assert(xml:find('<Skills', 1, true), fixture.id .. ' 缺少技能段')
	assert(xml:find('<Tree', 1, true), fixture.id .. ' 缺少天赋段')
	loadBuildFromXML(xml, 'poe.ninja ' .. fixture.id)
	dofile('Tests/LocalisationCoreCombinations.lua')(build, equal)
	if fixture.id == 'resurrectgodaura' then dofile('Tests/LocalisationBuildNotes.lua')(build, equal) end
	if fixture.id == 'resurrectgodaura' then dofile('Tests/LocalisationStatPopup.lua')(build, equal) end
	if fixture.id == 'resurrectgodaura' then dofile('Tests/LocalisationCalcs.lua')(build, equal) end
	if fixture.id == 'resurrectgodaura' then dofile('Tests/LocalisationHiddenInterface.lua')(build, equal) end
	equal(build.characterLevel, meta.level, fixture.id .. ' 等级导入')
	equal(build.spec.curAscendClassName, fixture.class, fixture.id .. ' 升华职业导入')
	assert(#build.itemsTab.items > 0, fixture.id .. ' 装备没有进入 PoB2')
	assert(#build.skillsTab.socketGroupList > 0, fixture.id .. ' 技能没有进入 PoB2')
	assert(#build.xmlSectionList > 0, fixture.id .. ' XML 段没有被 PoB2 保留')
	for _, language in ipairs({ 'en', 'zh-CN', 'zh-TW', 'ja-JP', 'ko-KR' }) do
		localisation:SetLanguage(language)
		local drawn, err = pcall(build.configTab.Draw, build.configTab, viewPort, { })
		equal(drawn, true, fixture.id .. ' ' .. language .. ' 配置页绘制: ' .. tostring(err))
	end
end

dofile('Tests/LocalisationTreeAlternatives.lua')(build, equal)
dofile('Tests/LocalisationMinionInterface.lua')(equal)
print(string.format('真实 PoB2 集成检查通过 %d 个断言。', assertions))
