-- 语言包注册表；新增语言只需增加资源目录、文件清单和此处的声明。
return {
	default = "en",
	items = {
		{ id = "en", name = "English", fallback = "en", messagePath = "Locales/en", messageFiles = { "Messages.csv", "Game.csv" } },
		{ id = "zh-CN", name = "简体中文", fallback = "en", path = "Locales/zh-CN", files = "Files.lua", messageFiles = { "Messages.csv", "Game.csv" }, font = { folder = "Locales/Fonts", cache = "Fonts/zh-CN", face = "Noto Sans SC", fontFile = "assets/fonts/NotoSansSC-VF.ttf", fontFileEnv = "NOTO_SANS_SC_FONT" } },
		{ id = "zh-TW", name = "繁體中文", fallback = "en", path = "Locales/zh-TW", files = "Files.lua", messageFiles = { "Messages.csv", "Game.csv" }, font = { folder = "Locales/Fonts", cache = "Fonts/zh-TW", face = "Noto Sans SC", fontFile = "assets/fonts/NotoSansSC-VF.ttf", fontFileEnv = "NOTO_SANS_SC_FONT" } },
		{ id = "ja-JP", name = "日本語", fallback = "en", messagePath = "Locales/ja-JP", messageFiles = { "Messages.csv", "Game.csv" }, font = { folder = "Locales/Fonts/ja-JP", cache = "Fonts/ja-JP", face = "Noto Sans JP", fontFile = "assets/fonts/NotoSansJP-VF.ttf" } },
		{ id = "ko-KR", name = "한국어", fallback = "en", messagePath = "Locales/ko-KR", messageFiles = { "Messages.csv", "Game.csv" }, font = { folder = "Locales/Fonts/ko-KR", cache = "Fonts/ko-KR", face = "Noto Sans KR", fontFile = "assets/fonts/NotoSansKR-VF.ttf" } },
	},
}
