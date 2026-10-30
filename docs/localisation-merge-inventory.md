# 合并前整理快照

日期：2026-10-30
用途：记录当前工作树与官方 `dev` 基线的文件分类，供后续拆分、取舍和验收使用。本文不是提交清单，也不授权删除、提交或推送。

## 快照

- 分支：`feature/integrated-localisation`
- `HEAD`：`618911760`
- `upstream/dev`：`bb52d6b368307457eb9c54bb13f1829993d390b1`
- `HEAD` 相对基线：305 个文件，约 1,163,532 行新增，5,518 行删除。
- 当前工作树未提交改动：技能显示/资源/测试及其来源、术语文档共 9 个路径；这些改动必须保留并单独归入技能批次。
- 当前直接检查：`git diff --check` 无输出；未在本次整理中重跑完整构建或本地化测试。

## 本轮已执行的最小变更与验证

- 2026-10-31 提交前修正字体发布清单：保留 `assets/fonts/` 目标路径，并纳入三套 Noto 字体对应的 OFL 文本；使用隔离目录调用实际 `create_manifest()`，已确认 3 个字体和 3 个许可证路径、字体哈希及无关文件排除规则。完整发布清单、安装器和干净安装仍待验收。
- 已将官方新安装默认语言统一为 English：`src/Locales/Manifest.lua`、`src/Modules/Localisation.lua`、`src/Modules/Main.lua`，并同步 `Languages.Default` 与非法语言回退测试。
- 已移除 `LOCALISATION.md` 中的个人开发路径和过时的“尚未创建 fork”表述，改为仓库相对路径、来源表和远程配置说明。
- `cmd /c test-localisation.cmd`：退出码 0；99 个契约断言、12,487 个真实集成断言通过。
- `python tools/check-atlas.py`：退出码 0；本机现有 10 张图集通过 RLE 行边界、像素数量和数据完整性检查。
- 该测试仍输出官方基线已有的 `missing node` 警告；本轮没有重新执行无缓存构建、字体打包、CI 容器或真实窗口验收。

## 相对基线的初步分类

| 类别 | 数量 | 处理建议 | 当前动作 |
|---|---:|---|---|
| 运行时与资源 | 185 | 按框架、显示边界、语言包和数据域拆分；先确认依赖闭合 | 保留，待按 A/B/C 批次重组 |
| 工具 | 25 | 区分长期生成/校验工具和一次性迁移脚本 | 保留，待补齐输入、输出、退出码说明 |
| 测试与固定夹具 | 16 | 保留可复现的最小 fixture；在线抓取结果不能作为唯一依赖 | 保留，待核对测试入口和平台要求 |
| 文档与审计产物 | 25 | 区分当前结论、历史报告、摘要和逐行数据 | 保留，待维护者决定完整报告去留 |
| 其他 | 54 | 逐项核对构建脚本、清单、忽略规则、运行时和发布影响 | 暂不移动或删除 |

数量来自 `git diff --name-only upstream/dev...HEAD` 的路径初分组，不代表最终 PR 文件数；一项文件可能同时承担生成输入和运行时输出，需按来源关系复核。

## 被忽略但会影响干净检出的产物

当前工作树检测到以下忽略路径/文件：

- `src/Locales/Fonts/`
- `src/Tests/Run/`
- `tools/FontAtlas.exe`
- `tools/FontAtlas.obj`
- `tools/LuaRunner.exe`
- `tools/LuaRunner.obj`

这些内容没有进入相对基线的 305 个跟踪文件统计。后续必须在无这些缓存的干净检出中分别验证英文回退、字体生成、headless 测试和正式打包；不能因为本机存在它们就把启动或 CI 写成已验证。

字体发布的直接阻塞关系已经确认：`manifest.cfg` 的 `program.path=src` 会把被跟踪的 `src/Locales/Fonts/*` 纳入 `update_manifest.py` 的发布文件扫描，但当前 `src/Locales/Fonts/` 被 `.gitignore` 排除，干净检出不会有这些文件。因此“发布包携带图集”还需要在许可证/再分发依据明确后，二选一：将已批准的生成图集纳入版本库，或在正式发布流水线中先生成并再运行 manifest/打包步骤。当前不擅自改忽略规则或添加二进制资产。

现有 `.github/workflows/installer.yml` 只检出独立的 `PathOfBuilding-Installer` 仓库后制作安装包，不会替当前源码仓库生成字体。因此若继续采用发布包携带图集，必须把图集纳入源仓库发布输入，或明确在安装器流水线增加生成/复制步骤；这个事实已列为发布流程阻塞项。

### 字体授权与覆盖核对

- 本地压缩包：`C:\Users\Wxiang\Downloads\AlimamaFangYuanTiVF.zip`；包含 `AlimamaFangYuanTiVF-Thin.ttf`、`*.woff`、`*.woff2`、`LICENSE.txt` 和 `INSTRUCTION.txt`。
- 官方声明与压缩包内 `LICENSE.txt` 一致：允许个人/企业基于合法目的进行商业或非商业使用，并明确允许嵌入式使用。
- 同一声明禁止未经授权的转换、修改、二次创作，以及有偿转让、授权或许可；没有明确授予把 TTF/WOFF/WOFF2 作为独立字体包再许可给第三方的权利。
- 用户已确认交付语义：字体文件本体不作修改，TGA 仅作为软件渲染用的字形图集生成并随软件嵌入发布；这对应声明中的“嵌入式使用”，不等同于独立再许可字体文件。
- 当前仍未把字体二进制或生成图集加入工作树，也未修改 `.gitignore`。后续只需验证图集生成、版权说明和正式打包链路，不再把图集栅格化本身视为对字体本体的二次创作。
- 本地试生成结果：阿里妈妈方圆体生成 7017 个字形、3 张图集；`python tools/check-atlas.py` 通过。
- 覆盖阻塞：当前简繁资源使用的 3942 个非 ASCII 码点中有 1069 个不在该字体图集中；`cmd /c test-localisation.cmd` 在 `src/Tests/Localisation.lua:101` 的“缺少中文字形”断言失败。因此尚不能把阿里妈妈方圆体作为完整简繁默认字体交付。
- 字体方案已改为项目内 Noto Sans SC：`assets/fonts/NotoSansSC-VF.ttf`，来源为 Google Fonts 官方仓库，SHA-256 为 `A3041811A78C361B1DE50F953C805E0244951C21C5BD412F7232EF0D899AF0DA`；按当前简繁资源实际码点检查，除零宽空格和 BOM 外均有字形。OFL 许可证副本见 `docs/licenses/NotoSansSC-OFL.txt`。
- 阿里妈妈方圆体保留为已核对但未采用的候选：其许可证允许嵌入，但当前字形覆盖不足，不能满足首个简繁资源批次。
- 已加入韩文字体 `assets/fonts/NotoSansKR-VF.ttf`：来源为 Google Fonts 官方仓库 `https://github.com/google/fonts/blob/main/ofl/notosanskr/NotoSansKR%5Bwght%5D.ttf`，SHA-256 为 `194018E6B2B293A7964F037B25C0249CE1418BC9AB3C971060A03AA57861E252`，许可证副本见 `docs/licenses/NotoSansKR-OFL.txt`。该文件保持官方字体本体不变，用于韩文图集生成/嵌入。
- 已加入日文字体 `assets/fonts/NotoSansJP-VF.ttf`：来源为 Google Fonts 官方仓库 `https://github.com/google/fonts/blob/main/ofl/notosansjp/NotoSansJP%5Bwght%5D.ttf`，SHA-256 为 `C2F3B4D463500A2DDCD3849CDED1FCEEB9FD6D1C32E6CBECD568453BA50FC68F`，许可证副本见 `docs/licenses/NotoSansJP-OFL.txt`。日文和韩文语言入口首发回退英文，待对应翻译资源加入后即可复用同一字体配置。
- Noto Sans SC 当前验证：`build.cmd` 退出码 0，生成 30,435 个字形和 10 张图集；日文生成 16,067 个字形和 6 张临时图集，韩文生成 22,852 个字形和 8 张临时图集；`cmd /c test-localisation.cmd` 退出码 0，99 个契约断言和 12,509 个真实集成断言通过。启动仍输出官方基线已有的 `missing node` 警告。
- 字体加载已改为按语言配置：已有 `Glyphs.lua`/TGA 直接使用；缺失时由 `Font.lua` 调用本地 `FontAtlas.exe`，写入用户目录下对应语言缓存。当前缓存生成依赖 Windows 字体接口和可用的 Noto 字体文件；Linux/macOS 仍需独立的栅格化实现或英文回退决定。

`src/Tests/Run/` 当前有 99 个被忽略文件，约 189 MB。初步分为：

- **候选长期入口**：审计/检查 Lua 与 Python 脚本，例如 `audit-key-display-boundaries.lua`、`check-key-paths.lua`、`check-quality-range.py`、`verify-skill-deliverables.py`；需要移到受版本控制的 `tools/` 或 `src/Tests` 并补充固定输入。
- **候选固定夹具**：少量稳定的 PoE2DB/技能来源样本和最小 JSON/CSV；需要去除抓取时间、本机路径和不必要的完整页面后再评估。
- **一次性中间产物**：`*-before*`、`*-candidates*`、大批量 `*.json`/`*.csv`、抓取 HTML、`Settings.xml`、`.ready` 和 node_modules；当前不进入首个 PR，也不直接删除。

## 当前未提交技能批次

必须保持原样、不得被整理动作覆盖：

```text
src/Classes/SkillsTab.lua
src/Locales/zh-CN/Game.csv
src/Locales/zh-CN/Messages.csv
src/Locales/zh-TW/Game.csv
src/Locales/zh-TW/Messages.csv
src/Tests/LocalisationIntegration.lua
src/Tests/LocalisationSkills.lua
docs/localisation-skills-fix.md
docs/localisation-skill-sources.csv
docs/localisation-skill-terminology.csv
```

它们依赖稳定的技能显示字段、资源加载和输入/保存身份边界。依赖未合入框架前，不能把这组修复描述为独立可用补丁。

## 后续整理入口

已确认的整理方向：

- 首个官方 PR 按 A+B+C 整理：框架、基础资源和技能名称/描述修复。
- 官方新安装默认语言采用 English；旧设置中的显式语言仍需兼容。
- 中文字体图集随发布包携带；需要把图集纳入正式打包清单，不能依赖用户首次启动时编译。

后续入口：

1. 以本快照为保护清单，在临时干净检出中生成 A/B/C 候选差异；源工作树只读，不覆盖现有改动。
2. 对 `src/Tests/Run/` 逐项标记“长期工具、固定 fixture、一次性中间产物、个人缓存”，不直接删除。
3. 对大体量 CSV、`DataBindings.json`、`MessageBindings.json` 和 `Locales/Keys/*` 追溯生成脚本、输入版本和重生成命令。
4. 核对发布包清单、字体资源再分发依据、CI 必跑范围和剩余来源许可事项。

## 停止条件

- 发现整理会覆盖或丢失未提交技能改动。
- 某个生成文件没有可追溯的输入或生成命令。
- 某个历史报告与当前版本冲突，却没有直接证据区分历史结论和当前结论。
- 需要决定审计产物去留、CI 必跑范围或来源许可，但尚未得到用户/维护者决定。
