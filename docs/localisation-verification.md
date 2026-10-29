# 本地化集成验证记录

验证日期：2026-10-29（Windows，Asia/Shanghai）。

工程基于官方 PoB2 `dev` 基线提交 `bb52d6b368307457eb9c54bb13f1829993d390b1`，本地分支为 `feature/integrated-localisation`。`upstream` 指向官方 `PathOfBuilding-PoE2`；没有创建或推送远程 fork。

## 可重复命令

在 `E:\PoE2` 执行：

```cmd
build.cmd
python tools\check-atlas.py
test-localisation.cmd
start.cmd
```

本次实际结果：

- `build.cmd` 成功编译 `FontAtlas.exe` 和 `LuaRunner.exe`，生成 29,666 个字形、10 张 2048×2048 图集。
- `check-atlas.py` 通过全部 10 张 TGA 的 RLE 行边界、像素数量和数据完整性检查。
- 词库与契约测试通过 41 个断言，包含 CSV 引号/换行、参数模板、反向歧义、语言包注册表、动态标签与授予技能组合、PoB2 角色字段、中文光标和字形。
- 真实 PoB2 启动集成测试通过 45 个断言，包含中文技能搜索、简体与繁体物品解析边界、角色装备与技能导入、对象形式修饰词、语言设置持久化、无效语言回退、中文退格/Delete 和异常恢复。
- poe.ninja 三个公开构筑在简体与繁体字段级扫描中均为 0 个未命中候选；审计命令为 `cd /d E:\PoE2\src && ..\tools\LuaRunner.exe ..\tools\audit-poe-ninja.lua`。

### 数值占位符绘制崩溃回归（2026-10-29）

配置页会直接将数值默认值赋给编辑控件的 `placeholder`。原 `DrawString` 本地化包装器在翻译返回数字后调用 `text:find`，触发 `Modules/Localisation.lua:144: attempt to index local 'text' (a number value)`；此前的数字测宽检查没有覆盖绘制。

新增真实 `EditControl:Draw` 回归后，修改前以英文模式的数值占位符 `0` 稳定复现相同报错，测试退出码为 1。修复在绘制入口将显示值转换为字符串，保持原数值数据不变。修改后 `test-localisation.cmd` 退出码为 0，41 个契约断言和 78 个集成断言通过，新增检查覆盖：三种语言的 `0`、负数、小数占位符、绘制后数值与上下文保留、完整配置页，以及三个公开构筑分别在三种语言下的配置页绘制。

上述绘制回归通过 `HeadlessWrapper.lua` 执行实际 Lua 控件与配置页逻辑，未重新取得原生窗口的人工交互截图。这证明本次 Lua 异常已消除，不代表整个应用翻译覆盖已经完成。原 poe.ninja 审计只扫描装备字段，不应作为技能或天赋显示的验收证据。

### 天赋提示框颜色码与换行回归（2026-10-29）

真实节点探针显示：节点 4、16、30、40 的名称与首行属性均能单独命中简繁词库，但 `AddNodeTooltip` 产生的 `^xF8E6CAShock Chance^7`、`^x8888FF15% increased chance to Shock^7` 等字符串仍然返回英文。根因是词库只处理开头颜色码，提示框末尾的 `^7` 阻断了整行匹配；先按英文拆行也会丢失原词条边界。

修复保留尾部颜色码，并在 `Tooltip:AddLine` 拆行前执行翻译；语言切换后提示框缓存重新生成。最新 `test-localisation.cmd` 退出码为 0，45 个契约断言与 108 个集成断言通过；新增断言覆盖首尾颜色码、连续尾部颜色码、未知文本回退、语言切换后的提示框重建，以及以上四个实际节点的简繁标题与属性进入真实提示框的结果。数据对象及计算字段仍使用英文。该验证不表示其他未补录词条已完成翻译。

### 全域缺口审计（2026-10-30）

`python tools/audit-localisation.py` 退出码为 0。本轮覆盖当前运行时全部 4,914 个天赋节点、764 个属性描述文件，以及装备、技能、召唤物、配置、风味文本和源码候选；每种语言有 64,461 个去重候选，其中 17,391 个是源码待分类项。双语缺口及复核 CSV 共 51,166 行，独立读取 CSV 并按语言、数据域、状态汇总，与 Markdown 报告逐项核对一致。详见 `localisation-runtime-audit.md`；尚未完成全量中文化，也没有据此补齐原生窗口的布局与交互验收。

集成测试使用官方 PoB2 运行时启动完整 Lua 应用，不请求在线角色数据。启动时出现的 14 条 `missing node` 输出在未修改的官方基线中逐条相同，属于基线数据警告，不是本地化改动产生的错误。

## 界面证据

以下截图来自当前源码启动的官方 PoB2 窗口：

- [主界面中文显示](localisation-main.png)
- [原有选项中的界面语言选择](localisation-options.png)

原始 `Path{space}of{space}Building-PoE2.exe`、`SimpleGraphic.dll` 和 `lua51.dll` 与对照的官方运行时副本 SHA-256 一致；新增代码只在 Lua 源码、词库、字体生成工具和测试目录中。

## 已知边界

- 现有 CSV 是发布目录中的历史词库，包含部分 PoE1 术语，也缺少部分新增 PoE2 词条；未命中内容保持英文，未知中文物品词条可能无法被官方英文解析器识别。
- 未验证在线角色数据的网络获取链路；角色对象转换、装备/技能/珠宝/天赋字段处理和真实 PoB2 物品解析器已经通过离线 fixture 验证。账号登录与鉴权不属于本地化功能验收范围。
- 中文字体图集由本机 Microsoft YaHei 生成，不分开提供粗体/斜体中文字形；不复制或分发系统字体文件。
- 当前运行和构建验证针对 Windows；Linux/macOS 的字体生成、输入法组合状态和原生运行时没有验收。
- 语言注册表位于 `src/Locales/Manifest.lua`；设置界面从注册表生成三种语言选项，新增语言不需要修改 PoB2 业务模块。
- `RecoveredPoE2` 只保存逆向调查证据，不是产品工程；可运行、可继续开发的工程是本目录 `E:\PoE2`。
