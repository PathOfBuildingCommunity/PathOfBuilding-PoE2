-- 语言包注册表；新增语言只需增加资源目录、文件清单和此处的声明。
return {
	default = "zh-CN",
	items = {
		{ id = "en", name = "English", fallback = "en", messagePath = "Locales/en", messageFiles = { "Messages.csv", "Game.csv" }, font = "Locales/Fonts" },
		{ id = "zh-CN", name = "简体中文", fallback = "en", path = "Locales/zh-CN", files = "Files.lua", messageFiles = { "Messages.csv", "Game.csv" }, font = "Locales/Fonts" },
		{ id = "zh-TW", name = "繁體中文", fallback = "en", path = "Locales/zh-TW", files = "Files.lua", messageFiles = { "Messages.csv", "Game.csv" }, font = "Locales/Fonts" },
	},
}
