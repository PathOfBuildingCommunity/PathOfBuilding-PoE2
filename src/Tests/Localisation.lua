-- 长期契约测试：词库解析、未知输入保护、实际角色结构、中文光标与图集。
package.cpath = '../runtime/?.dll;' .. package.cpath
package.path = '../runtime/lua/?.lua;' .. package.path
local Dictionary = dofile('Modules/Localisation/Dictionary.lua')
local Font = dofile('Modules/Localisation/Font.lua')
local Import = dofile('Modules/Localisation/Import.lua')
local Languages = dofile('Modules/Localisation/Languages.lua')
local assertions = 0

-- 对比可观察输出，失败信息携带具体输入用途。
local function equal(actual, expected, label)
	assertions = assertions + 1
	assert(actual == expected, (label or '输出不符') .. ': ' .. tostring(actual) .. ' ~= ' .. tostring(expected))
end

local languageList = Languages.List()
equal(#languageList, 3, '当前语言数量')
equal(languageList[1].id, 'en', '英文语言顺序')
equal(Languages.Default().id, 'zh-CN', '默认语言')
assert(Languages.LoadResources('zh-CN').files[1], '简体语言包文件清单')
assert(Languages.LoadResources('zh-TW').files[1], '繁体语言包文件清单')

local dictionary = Dictionary.New()
dictionary:LoadCSV('\239\187\191"Hello, World","你好，世界"\r\n"A ""quote""","引用"\n"two\nlines","两行"\n{0} vs {1},{1} 对 {0}\n')
equal(dictionary:Translate('Hello, World'), '你好，世界', '引号内逗号')
equal(dictionary:Translate('A "quote"'), '引用', '引号转义')
equal(dictionary:Translate('two\nlines'), '两行', '多行字段')
equal(dictionary:Translate('123 vs 456'), '456 对 123', '占位符重排')
equal(dictionary:Translate('456 对 123', true), '123 vs 456', '反向占位符重排')
dictionary:Add('Alpha', '冲突'); dictionary:Add('Beta', '冲突')
equal(dictionary:Translate('冲突', true), '冲突', '有歧义时原样保留')
equal(dictionary:Translate('unknown'), 'unknown', '未知词条回退')
dictionary:Add('First {0}', '冲突 {0}'); dictionary:Add('Second {0}', '冲突 {0}')
equal(dictionary:Translate('冲突 12', true), '冲突 12', '反向模板有歧义时保留原文')
dictionary:Add('Updated {0}', '旧值 {0}'); dictionary:Add('Updated {0}', '新值 {0}')
equal(dictionary:Translate('Updated 12'), '新值 12', '模板覆盖采用最终词条')
equal(dictionary:Translate('旧值 12', true), '旧值 12', '被覆盖的旧译文不再反向转换')
dictionary:Add('{0}s', '{0} 秒')
equal(dictionary:Translate('Requires'), 'Requires', '秒数模板不匹配普通英文单词')
equal(dictionary:Translate('12.5s'), '12.5 秒', '秒数模板仍可转换数值')

dictionary = Dictionary.New()
local start = os.clock(); dictionary:LoadFolder('Locales/zh-CN')
print(string.format('实际简体词库：%d 条，加载 %.2f 秒', dictionary.count, os.clock() - start))
equal(dictionary:Translate('Fireball'), '火球', '真实技能译名')
equal(dictionary:Translate('fireball'), '火球', '英文小写搜索')
equal(dictionary:Translate('^7Tree'), '^7天赋树', '保留颜色码')
equal(dictionary:Translate('^xF8E6CAShock Chance^7'), '^xF8E6CA感电几率^7', '天赋标题保留首尾颜色码')
equal(dictionary:Translate('^x8888FF15% increased chance to Shock^7'), '^x8888FF感电几率提高 15%^7', '天赋属性保留末尾颜色重置码')
equal(dictionary:Translate('^7Tree^7^xFFFFFF'), '^7天赋树^7^xFFFFFF', '连续尾部颜色码')
equal(dictionary:Translate('^7unknown^7'), '^7unknown^7', '未知词条与颜色码保持原样')
equal(dictionary:Translate('  Fireball '), '  火球 ', '布局空白不阻断词条匹配')
equal(dictionary:Translate('^xF05050Damage Blocked is Recouped as Mana ^8(Not supported in PoB yet)^7'), '^xF05050被格挡的伤害吸纳为魔力 ^8(PoB 暂不支持)^7', '内部颜色附注不阻断词缀翻译')
equal(dictionary:Translate('^7unknown ^8(unknown)^7'), '^7unknown ^8(unknown)^7', '未知内部颜色片段保持原样')
equal(dictionary:Translate('Fireball\nTree'), '火球\n天赋树', '多行标签在拆行前翻译')
equal(dictionary:Translate('25 Passive Points'), '25 天赋点', '真实数字模板')
equal(dictionary:Translate('Current build: Demo'), '当前 BD: Demo', '动态标签前缀')
dictionary:Add('Grants Skill:', '赋予技能:')
dictionary:Add('Raise Shield', '架盾')
equal(dictionary:Translate('Grants Skill: Raise Shield'), '赋予技能: 架盾', '固定标签与动态名称分段翻译')
dictionary:Add('Grants Skill: Level {0} {1}', '赋予技能: 等级 {0} {1}')
equal(dictionary:Translate('Grants Skill: Level 14 Raise Shield'), '赋予技能: 等级 14 架盾', '带等级的授予技能组合翻译')
equal(dictionary:Translate('珊瑚护身符', true), 'Coral Amulet', '中文物品基底')
equal(dictionary:Translate('unknown-{999}'), 'unknown-{999}', '未知模板回退')

local translate = function(text) return dictionary:Translate(text, true) end
local source = {
	name = '用户角色名', class = 'Warrior',
	equipment = {{ id = 'immutable-id', baseType = '珊瑚护身符', typeLine = '珊瑚护身符', explicitMods = { '未知修饰词' },
		properties = {{ name = '等级', values = {{ '20', 0 }} }},
		implicitMods = {{ description = '火球', flags = { fractured = true } }},
		grantedSkills = {{ name = '火球', values = {{ '20', 0 }} }} }},
	skills = {{ typeLine = '火球', supports = {{ typeLine = '火球' }} }},
	jewels = { }, passives = { hashes = {123, 456}, skill_overrides = { ['123'] = { name = '智慧' } } },
}
local result = Import.Character(source, translate)
equal(result.equipment[1].baseType, 'Coral Amulet', 'PoB2 equipment 转换')
equal(result.skills[1].typeLine, 'Fireball', 'PoB2 skills 转换')
equal(result.skills[1].supports[1].typeLine, 'Fireball', '支援技能转换')
equal(result.passives.skill_overrides['123'].name, 'Intelligence', '天赋属性转换')
equal(result.name, source.name, '角色名保持原样')
equal(result.equipment[1].id, 'immutable-id', '物品 ID 保持原样')
equal(result.passives.hashes[2], 456, '天赋哈希保持原样')
equal(result.equipment[1].explicitMods[1], '未知修饰词', '未知修饰词保持原样')
equal(source.equipment[1].baseType, '珊瑚护身符', '输入对象未修改')
equal(result.equipment[1].implicitMods[1].description, 'Fireball', '对象形式修饰词转换')
equal(result.equipment[1].implicitMods[1].flags.fractured, true, '修饰词标记保持原样')
equal(source.equipment[1].implicitMods[1].description, '火球', '修饰词对象原文保留')
equal(result.equipment[1].grantedSkills[1].name, 'Fireball', '装备授予技能转换')
equal(Import.ItemText('珊瑚护身符\r\n物品等级: 80\r\n未知词条', translate), 'Coral Amulet\r\nItem Level: 80\r\n未知词条', '剪贴板行与换行')

local font = Font.New('Locales/Fonts')
local layout = font:Layout(16, '^7中文 A\n火球')
assert(layout.width > 0 and #layout.lines == 2)
equal(font:Cursor(16, '中文', 0, 0), 1, '中文首字节')
equal(font:Cursor(16, '中文', font:Layout(16, '中').width, 0), 4, '中文字符边界')
equal(font:Cursor(16, '中文', 999, 0), 7, '中文末尾')
equal(font:Cursor(16, '中文\nA', 0, 17), 8, '第二行字节索引')
equal(font:Layout(16, '^7中文').width, font:Layout(16, '中文').width, '颜色码零宽')
for _, cp in ipairs({ 0x4e2d, 0x6587, 0x7b80, 0x9ad4 }) do assert(font.metrics.glyphs[cp], '缺少中文字形') end

-- 所有改动 Lua 文件必须在官方 LuaJIT 下可编译。
for _, file in ipairs({ 'Launch.lua', 'Modules/Main.lua', 'Modules/Common.lua', 'Classes/EditControl.lua', 'Classes/GemSelectControl.lua', 'Classes/ImportTab.lua', 'Classes/ItemsTab.lua', 'Modules/Localisation.lua' }) do
	assert(loadfile(file), file)
end
print(string.format('通过 %d 个断言；Lua 语法检查通过。', assertions))
