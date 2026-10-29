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
