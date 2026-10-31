-- 无界面测试只替换平台字体资源来源；布局、绘制、光标及所有产品断言继续执行。
if os.getenv('POB_LOCALISATION_NATIVE_FONTS') == '1' then return end

local load = dofile
local Font = load('Modules/Localisation/Font.lua')
local new = Font.New
local folders = {
	['Locales/Fonts'] = 'Tests/Fixtures/fonts/SC',
	['Locales/Fonts/ja-JP'] = 'Tests/Fixtures/fonts/JP',
	['Locales/Fonts/ko-KR'] = 'Tests/Fixtures/fonts/KR',
}

-- 指标来自项目字体的真实 GDI 输出，不读取开发机图集或用户字体缓存。
Font.New = function(folder)
	local fixture = assert(folders[folder], '未登记测试字体目录：' .. tostring(folder))
	return assert(new(fixture), '缺少版本化字体指标：' .. fixture)
end

-- 应用与测试加载同一字体模块，避免在 Linux 尝试运行 Windows 生成器。
function dofile(file)
	if file == 'Modules/Localisation/Font.lua' then return Font end
	return load(file)
end
print('Headless fonts: versioned GDI metrics; atlas pixels and native rendering are checked separately.')
