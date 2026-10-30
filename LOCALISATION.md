# PoB2 内置中文支持

此工程直接基于官方 PoB2，分支 `feature/integrated-localisation`。程序使用原有 PoB2 界面、计算逻辑和官方 SimpleGraphic 运行时。没有 PoeCharm 启动器、每日迷宫或原 DLL 注入依赖。

后续开发和启动统一使用 `E:\PathOfBuilding-PoE2`。

## 运行

在本目录双击 `start.cmd`。在左下角“选项”中选择 English、简体中文或繁體中文，点击保存即可切换。语言保存在 PoB2 的 `Settings.xml` 中。

首次从源码检出时，运行 `build.cmd` 编译工具并生成字形图集；`start.cmd` 在图集缺失时也会调用构建。需要 Windows 和 Visual Studio 2022 C++ 工具。默认支持 Community 安装位置，也可以从已配置好的 x64 开发者命令提示符运行。

```cmd
build.cmd
test-localisation.cmd
start.cmd
```

`build.cmd` 编译本次新增的字体生成器和 Lua 测试入口。PoB2 的业务源码是 Lua，编辑后可直接运行，不需要重新编译整个应用。官方运行时二进制保留原样；运行时的完整原生构建说明见官方 SimpleGraphic 仓库。

## 已接入的功能

- 通过 CSV 词库显示中文，保留 PoB2 原有界面和颜色、图层、裁剪。
- 统一处理中文绘制、文本测宽、换行与字节光标定位。
- 中文编辑与粘贴；退格和 Delete 删除完整汉字。
- 技能、物品及天赋的公共搜索同时匹配英文原名和译名；技能支持中文标签。
- 中文物品文本在粘贴边界转换，之后交给 PoB2 自己的物品解析器。
- 角色导入按 PoB2 的 equipment、skills、jewels、passives 结构转换。物品 ID、哈希、数值和角色名保留原样。
- 输入字段按原文显示，不把计算数据或用户编辑内容改成译文。

## 继续开发

| 路径 | 职责 |
| --- | --- |
| `src/Modules/Localisation.lua` | 语言状态、显示入口、搜索和输入边界 |
| `src/Modules/Localisation/Dictionary.lua` | CSV、双向词条和编号参数模板 |
| `src/Modules/Localisation/Languages.lua` | 语言注册表、资源清单和默认回退 |
| `src/Modules/Localisation/Font.lua` | 官方图像 API 上的字形绘制和布局 |
| `src/Modules/Localisation/Import.lua` | PoB2 角色结构和剪贴板转换 |
| `src/Locales/Manifest.lua` | 可选语言、显示名称、词库目录和字体配置 |
| `src/Locales/zh-CN`、`zh-TW` | 外部词库；`Integrated.csv` 用于本 fork 的补充词条 |
| `tools/FontAtlas.cpp` | 从 Windows 已安装字体生成图集 |
| `src/Tests` | 词库与真实 PoB2 集成测试 |

更改 CSV 后重新启动生效。新增文件需要写入对应 `Files.lua` 清单。英文未知文本保持英文；反向译名有歧义时保持原文，具体字段有已验证上下文时才作定向处理。请优先补充 PoE2 已确认译名，不把 PoE1 的同名对象当作相同数据。

新增语言时，在 `src/Locales/Manifest.lua` 增加一条语言声明，创建对应目录和 `Files.lua`，再提供词库与字体图集配置。设置界面会从注册表自动生成选项；不需要在 PoB2 的计算、导入或控件业务模块中增加语言分支。

图集从 Windows 系统的 Microsoft YaHei 生成，不复制或捆绑原字体文件。生成的图集和编译产物被 Git 忽略，可以用同一命令重新生成。

## 来源和更新上游

- 官方 PoB2 dev 基线：`bb52d6b368307457eb9c54bb13f1829993d390b1`。
- CSV 来源：当前 `E:\PoECN\Data\Translate` 发布数据；保留原词库文件内容，新增词条独立保存。
- 原 EXE 解压的 `translator.js` 留在上一级调查目录。本工程的输入转换采用可编辑 Lua 实现，没有直接调用旧结构的 JS。
- 这是本地 fork，尚未创建或推送 GitHub fork。

`upstream` 指向官方仓库。合并更新前先保存自己的改动，再执行：

```cmd
git fetch upstream dev
git rebase upstream/dev
test-localisation.cmd
```

官方 PoB2 和 SimpleGraphic 的原许可证继续适用，见原 `LICENSE.md` 和对应引擎源码仓库。

## 验证范围与限制

全量中文化尚未完成。全域数据与界面源码待核对候选见 `docs/localisation-runtime-audit.md`，可通过 `python tools/audit-localisation.py` 重新生成。三个 poe.ninja 构筑的装备字段扫描只覆盖样本中的装备，不代表技能、天赋和整个界面的翻译覆盖。

实际构建、字体检查、Lua 测试和界面截图见 `docs/localisation-verification.md`。本次未验证在线角色数据的网络获取链路；角色数据转换通过离线结构和真实 PoB2 物品解析器验证。账号登录与鉴权不属于本地化功能验收范围。

原词库中包含历史 PoE1 术语，也缺少部分新增 PoE2 词条。当前提供内置中文功能和可维护的工程，不宣称所有词条都已完成准确校对。未命中的内容保留英文；未知中文物品词条可能仍无法被官方英文解析器识别。

目前中文混排使用系统常规字体，未分别生成粗体/斜体字形；编辑框双击汉字按单个码点选择。Linux/macOS 字体生成与输入法组合状态不在本次已验证范围。
