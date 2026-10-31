# 中文使用边界审计

生成日期：2026-10-31。命令：在 src 运行 `..\tools\LuaRunner.exe ..\tools\audit-localisation-boundaries.lua`。

使用当前稳定资源 DataText/Field 取得基底与宝石显示名称，再以真实 ToEnglish 检查名称往返。unconverted 表示译名未转回英文；different-English 表示转成其他英文，须验证是否为兼容别名；不直接把此统计等同于角色导入失败数。名称往返不一致的基底同时交给真实 Item 解析器，与同名英文基线对照；parse-failed 是英文可以解析而中文失败。技能剪贴板使用真实 PasteSocketGroup，对照英文和当前中文技能名。静态名称往返通过也不代表中文真实物品完整格式已被解析。

资源探针包含历史/未启用词条，只证明坏词库能够产生截断、残留参数或错误英文译文，不代表每条都在当前物品触发。help.txt/changelog.txt 逐行按词库翻译检查，文件中尚未被窗口滚动到的行不冒充已显示。标题探针拦截真实 SetWindowTitle 参数，不修改原生窗口或用户设置。

| 语言/数据域/状态 | 次数 |
|---|---:|
| zh-CN / gem.name-roundtrip / different-English | 4 |
| zh-CN / gem.name-roundtrip / roundtrip | 926 |
| zh-CN / gem.name-roundtrip / unconverted | 36 |
| zh-CN / item.base-parse / parse-compatible | 15 |
| zh-CN / item.base-parse / parse-failed | 22 |
| zh-CN / item.base-roundtrip / different-English | 2 |
| zh-CN / item.base-roundtrip / roundtrip | 1719 |
| zh-CN / item.base-roundtrip / unconverted | 35 |
| zh-CN / native.title / display-compatible | 1 |
| zh-CN / resource-probe / fallback | 1 |
| zh-CN / resource-probe / translation-review | 7 |
| zh-CN / skill.clipboard / paste-compatible | 2 |
| zh-CN / skill.lookup / lookup-compatible | 3 |
| zh-CN / text-resource.changelog.txt / fallback | 1167 |
| zh-CN / text-resource.help.txt / fallback | 157 |
| zh-CN / text-resource.help.txt / translation-review | 1 |
| zh-TW / gem.name-roundtrip / different-English | 2 |
| zh-TW / gem.name-roundtrip / roundtrip | 915 |
| zh-TW / gem.name-roundtrip / unconverted | 49 |
| zh-TW / item.base-parse / parse-compatible | 11 |
| zh-TW / item.base-parse / parse-failed | 2 |
| zh-TW / item.base-roundtrip / different-English | 2 |
| zh-TW / item.base-roundtrip / roundtrip | 1743 |
| zh-TW / item.base-roundtrip / unconverted | 11 |
| zh-TW / native.title / display-compatible | 1 |
| zh-TW / resource-probe / fallback | 4 |
| zh-TW / resource-probe / translation-review | 4 |
| zh-TW / skill.clipboard / paste-compatible | 2 |
| zh-TW / skill.lookup / lookup-ambiguous | 1 |
| zh-TW / skill.lookup / lookup-compatible | 2 |
| zh-TW / text-resource.changelog.txt / fallback | 1167 |
| zh-TW / text-resource.help.txt / fallback | 158 |

原文、实际输出及反向结果见 `localisation-boundary-review.csv`。
