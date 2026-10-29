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

local clipboard = Paste
Paste = function() return 'Fireball 20/0 1' end
build.skillsTab:PasteSocketGroup()
Paste = clipboard
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
equal(('Fireball'):matchOrPattern('火球'), true, '公共搜索支持中文译名')
equal(localisation:TagName({ melee = true }, '近战'), 'melee', '中文标签搜索')
local englishWidth = localisation:MeasureRaw(16, 'VAR', 'Fireball')
assert(englishWidth ~= DrawStringWidth(16, 'VAR', 'Fireball'), '编辑原文测宽被显示翻译污染')
assert(type(localisation:MeasureRaw(12, 'VAR', 12345)) == 'number', '数值计算结果测宽')
local font = dofile('Modules/Localisation/Font.lua').New('Locales/Fonts')
equal(localisation:MeasureRaw(16, 'VAR', 'A', 'A中文'), font:Layout(16, 'A').width, '混排编辑框前缀测宽')
localisation:DrawRaw(function()
	equal(DrawStringWidth(16, 'VAR', 'A'), font:Layout(16, 'A').width, '混排绘制片段使用同一字体')
end, { buf = 'A中文' })
local ok = pcall(function() localisation:DrawRaw(function() error('预期异常') end, {}) end)
equal(ok, false, '保留绘制异常')
equal(localisation.rawDepth, 0, '异常后恢复显示翻译')

local cnBase = localisation:Translate('Lapis Amulet')
assert(cnBase ~= 'Lapis Amulet', '测试物品基底缺少译名')
local translatedTitle, translatedBase = localisation:ItemTitle({ title = 'Alkem Eira', baseName = 'Blazon Crest Shield' })
equal(translatedTitle, '神谕', '物品唯一名称按字段翻译')
equal(translatedBase, 'Blazon Crest Shield', '未知物品基底保留原文')
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
equal(#popup.controls.language.list, 3, '设置使用注册表中的三种语言')
popup.controls.language:SelByValue('en', 'id')
popup.controls.save.onClick()
equal(localisation.language, 'en', '保存设置后切换英文')
equal(localisation:Translate('Fireball'), 'Fireball', '英文模式回退')
local file = assert(io.open(main.userPath .. 'Settings.xml', 'rb'))
local settings = file:read('*a'); file:close()
assert(settings:find('language="en"', 1, true), '语言设置未持久化')
localisation:SetLanguage('zh-CN')
main:LoadSettings(true)
equal(localisation.language, 'en', '从设置重新加载语言')
localisation:SetLanguage('zh-TW')
assert(localisation:Translate('Options'):find('[\128-\255]'), '繁体词库未加载')
assert(localisation:Translate('Grants Skill: Raise Shield'):find('[\128-\255]'), '繁体组合词条未按字段翻译')
local twBase = localisation:Translate('Lapis Amulet')
assert(twBase ~= 'Lapis Amulet', '繁体物品基底缺少译名')
equal(localisation:ToEnglish(twBase), 'Lapis Amulet', '繁体物品反向转换')
equal(localisation:ItemText('稀有度: 普通\n' .. twBase .. '\n物品等級: 80'), 'Rarity: Normal\nLapis Amulet\nItem Level: 80', '繁体物品输入边界')
localisation:SetLanguage('missing-locale')
equal(localisation.language, 'zh-CN', '无效语言回退默认语言')
equal(localisation.invalidLanguage, 'missing-locale', '记录无效语言配置')
localisation:SetLanguage('zh-CN'); main:SaveSettings()

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
	equal(build.characterLevel, meta.level, fixture.id .. ' 等级导入')
	equal(build.spec.curAscendClassName, fixture.class, fixture.id .. ' 升华职业导入')
	assert(#build.itemsTab.items > 0, fixture.id .. ' 装备没有进入 PoB2')
	assert(#build.skillsTab.socketGroupList > 0, fixture.id .. ' 技能没有进入 PoB2')
	assert(#build.xmlSectionList > 0, fixture.id .. ' XML 段没有被 PoB2 保留')
end

print(string.format('真实 PoB2 集成检查通过 %d 个断言。', assertions))
