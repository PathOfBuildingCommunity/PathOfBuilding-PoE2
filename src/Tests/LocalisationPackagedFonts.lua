-- 从实际解压包执行，检查配置路径及首次生成；测试入口和缓存均不进入分发包。
local Font = dofile('Modules/Localisation/Font.lua')
local manifest = dofile('Locales/Manifest.lua')
GetScriptPath = function() return '.' end
GetRuntimePath = function() return '.' end
GetUserPath = function() return assert(os.getenv('POB_PACKAGED_TEST_USER')) end
-- 字体生成器自己创建输出目录，无界面宿主仅提供所需入口。
MakeDir = function() return true end
local samples = { ['zh-CN'] = '简体中文', ['zh-TW'] = '繁體中文', ['ja-JP'] = '日本語', ['ko-KR'] = '한국어' }
for _, language in ipairs(manifest.items) do
	if language.font then
		local file = assert(io.open(language.font.fontFile, 'rb'), '发布包缺少字体：' .. language.id)
		file:close()
		local font = assert(Font.New(language.font.folder, language.font), '发布包字体无法载入：' .. language.id)
		for _, token in ipairs(font:Layout(16, samples[language.id]).lines[1].tokens) do
			assert(token.glyph ~= font.metrics.glyphs[63], '发布包字体缺少语言本名字形：' .. language.id)
		end
		assert(font:Cursor(16, samples[language.id], 9999, 0) == #samples[language.id] + 1)
		print('Packaged font passed: ' .. language.id .. ' -> ' .. font.folder)
	end
end
