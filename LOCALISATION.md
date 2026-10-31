# PoB2 内置中文支持

2026-10-31 最终交付：核心补译、K4 旧显示反查移除及新增入口检查已验收；311 个分类入口、216 项契约及 423,612 项实际集成断言通过。全 DPS 与备注／来源的最后组合分支已补齐，原生三语切换正常。显示资源英文 123,836、简体 123,176、繁体 123,181；其他范围缺 key 660／655 已逐项统计。详见 [最终交付与保留边界](docs/localisation-delivery-2026-10-31.md)。以下较早计数与未完成描述保留对应历史时点。

此工程直接基于官方 PoB2，分支 `feature/integrated-localisation`。程序使用原有 PoB2 界面、计算逻辑和官方 SimpleGraphic 运行时。没有 PoeCharm 启动器、每日迷宫或原 DLL 注入依赖。

后续开发和启动在本仓库根目录执行；以下命令均以仓库根目录为当前目录。

## 运行

在本目录双击 `start.cmd`。在左下角“选项”中选择 English、简体中文、繁體中文、日本語或 한국어，点击保存即可切换。语言保存在 PoB2 的 `Settings.xml` 中。

首次从源码检出时，运行 `build.cmd` 编译工具并生成字形图集；`start.cmd` 在图集缺失时也会调用构建。需要 Windows 和 Visual Studio 2022 C++ 工具。默认支持 Community 安装位置，也可以从已配置好的 x64 开发者命令提示符运行。

```cmd
npm ci --prefix tools
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

2026-10-31 已移除 K4 的全局英文字符串反查：`DrawString`、测宽、`Tooltip:AddLine` 和通用字符串搜索均不再猜测翻译身份。当前验证和保留边界见 [K4 验收记录](docs/localisation-k4-2026-10-31.md)。

新增界面文字先在英文 `Messages.csv` 定义稳定 key，再补简体、繁体资源；完整动态句子使用命名参数。控件使用 `localisation:Label` 或对应 `*Key` 属性，绘制调用使用 `Text`，游戏数据使用 `Field`、`Line`、`ModLine` 或有业务域的 `Term`。显示引用不替换计算对象、保存内容或用户名称。搜索使用 `MatchField` / `MatchModLine` 同时匹配原文和译文。

`test-localisation.cmd` 会先运行 `node tools/check-localisation-display.cjs`，检查六类显示候选、旧接口调用及固定 key。新文字必须绑定资源；共享变量须追溯其来源，在 `docs/localisation-display-review.json` 记录审核依据。不能重新生成整个审阅清单来绕过失败。当前清单保留通用控件、用户文本、业务标识及历史界面的分类，它不是所有动态分支均已人工验收的证明。

| 路径 | 职责 |
| --- | --- |
| `src/Modules/Localisation.lua` | 语言状态、显示入口、搜索和输入边界 |
| `src/Modules/Localisation/Messages.lua` | 稳定 key、命名参数和显示资源校验 |
| `src/Modules/Localisation/Dictionary.lua` | 旧输入词典、中文反向转换和编号参数模板；不参与界面显示 |
| `src/Modules/Localisation/Languages.lua` | 语言注册表、资源清单和默认回退 |
| `src/Modules/Localisation/Font.lua` | 官方图像 API 上的字形绘制和布局 |
| `src/Modules/Localisation/Import.lua` | PoB2 角色结构和剪贴板转换 |
| `src/Locales/Manifest.lua` | 可选语言、显示名称、词库目录和字体配置 |
| `src/Locales/zh-CN`、`zh-TW` | 外部词库；`Integrated.csv` 用于本 fork 的补充词条；日本語和 한국어 首发入口暂时回退 English |
| `tools/FontAtlas.cpp` | 从 Windows 已安装字体生成图集 |
| `src/Tests` | 词库与真实 PoB2 集成测试 |

更改 CSV 后重新启动生效。新增文件需要写入对应 `Files.lua` 清单。英文未知文本保持英文；反向译名有歧义时保持原文，具体字段有已验证上下文时才作定向处理。请优先补充 PoE2 已确认译名，不把 PoE1 的同名对象当作相同数据。

新增语言时，在 `src/Locales/Manifest.lua` 增加一条语言声明，创建对应目录和 `Files.lua`，再提供词库与字体图集配置。设置界面会从注册表自动生成选项；不需要在 PoB2 的计算、导入或控件业务模块中增加语言分支。

当前图集生成器按语言使用项目内的 Noto Sans SC、Noto Sans JP 和 Noto Sans KR；字体文件本体保持原样，TGA 仅作为软件渲染用的嵌入图集，并附带各自的 OFL 版权声明。语言配置可以指定独立的字体目录和缓存目录：已有图集直接读取，缺失时首次使用该语言再生成到用户缓存，不要求把所有语言的图集预先放进安装包。中文字体仍可用 `NOTO_SANS_SC_FONT` 覆盖项目内默认文件；字体会在本次生成期间私有加载，不会安装或修改系统字体。生成的图集和编译产物被 Git 忽略，可以用同一命令重新生成。

## 来源和更新上游

- 官方 PoB2 dev 基线：`bb52d6b368307457eb9c54bb13f1829993d390b1`。
- CSV 来源、版本和获取记录见对应的来源表；保留原词库文件内容，新增词条独立保存。
- 原 EXE 解压的 `translator.js` 留在上一级调查目录。本工程的输入转换采用可编辑 Lua 实现，没有直接调用旧结构的 JS。
- 当前工作树的 `origin` 与 `upstream` 远程配置以 `git remote -v` 为准；对外贡献目标是官方仓库的 `dev` 分支。

`upstream` 指向官方仓库。合并更新前先保存自己的改动，再执行：

```cmd
git fetch upstream dev
git rebase upstream/dev
test-localisation.cmd
```

官方 PoB2 和 SimpleGraphic 的原许可证继续适用，见原 `LICENSE.md` 和对应引擎源码仓库。

## 验证范围与限制

最新验证见 [K4 验收记录](docs/localisation-k4-2026-10-31.md)，较早全面复查及分批补译见 [本地化全面复查](docs/localisation-comprehensive-2026-10-31.md)。当前显示资源简体缺 660、繁体缺 655 个 key，主要是按范围仅统计的区域名称和地图机制。中文技能粘贴可创建技能组并保留英文内部身份；输入仍有简体 22、繁体 2 个同名基底歧义，旧输入词典另有参数及反向冲突候选。“已接入”不代表全部数据和流程均已兼容。

全量语义校对尚未完成。`python tools/audit-localisation.py` 生成真实显示字段审计及仓库清单，`python tools/audit-localisation-keys.py` 生成逐 key 缺译和英文残留候选；源码显示边界以检查工具及其审阅清单为准。三个 poe.ninja 构筑的装备字段扫描只覆盖样本中的装备，不代表技能、天赋和整个界面的翻译覆盖。

实际构建、字体检查、Lua 测试和界面截图见 `docs/localisation-verification.md`。本次未验证在线角色数据的网络获取链路；角色数据转换通过离线结构和真实 PoB2 物品解析器验证。账号登录与鉴权不属于本地化功能验收范围。

原词库中包含历史 PoE1 术语，也缺少部分新增 PoE2 词条。当前提供内置中文功能和可维护的工程，不宣称所有词条都已完成准确校对。未命中的内容保留英文；未知中文物品词条可能仍无法被官方英文解析器识别。

目前中文混排使用系统常规字体，未分别生成粗体/斜体字形；编辑框双击汉字按单个码点选择。Linux/macOS 字体生成与输入法组合状态不在本次已验证范围。
