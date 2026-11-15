# poe.ninja PoE2 角色 fixture

这些 fixture 来自 `https://poe.ninja/poe2` 的公开角色详情接口，抓取日期为 2026-10-29，联盟为 `Runes of Aldur`，snapshot 为 `0912-20261029-40914`。

- `*.json`：角色元数据和 poe.ninja 返回的 `pathOfBuildingExport`。
- `*.pob2.txt`：原始 PoB2 URL-safe 压缩构筑码。
- `*.xml`：由原始构筑码解压得到的 PoB2 XML，供 headless PoB2 导入测试使用。

测试角色覆盖 Martial Artist、Titan、Smith of Kitava 三种升华职业。角色名和账号名是 poe.ninja 页面公开显示的数据，不用于登录或鉴权。
