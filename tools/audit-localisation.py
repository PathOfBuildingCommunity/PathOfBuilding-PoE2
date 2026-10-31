"""刷新仓库范围清单，并用真实稳定字段引用生成显示审计。"""
from pathlib import Path
import csv
import json
import re
import subprocess
import sys


# 先匹配注释，避免将注释里的字符串当作源码候选；长字符串保留 Lua 原语法。
TOKENS = re.compile(
    r"--\[(?P<comment_eq>=*)\[.*?\](?P=comment_eq)\]|--[^\n]*"
    r"|\[(?P<string_eq>=*)\[.*?\](?P=string_eq)\]"
    r'''|"(?:\\[\s\S]|[^"\\])*"|'(?:\\[\s\S]|[^'\\])*' ''',
    re.DOTALL | re.VERBOSE,
)


def main():
    # 审计入口只准备隔离的输入清单，不修改用户构筑与设置。
    root = Path(__file__).resolve().parent.parent
    source = root / "src"
    run = source / "Tests" / "Run"
    run.mkdir(parents=True, exist_ok=True)
    literals = []
    paths = sorted((source / "Classes").rglob("*.lua"))
    paths += sorted((source / "Modules").rglob("*.lua"))
    paths += sorted(source.glob("*.lua"))
    # 全仓文件均入清单；数据/资源/开发工具不能冒充已经触发的产品界面。
    tracked = subprocess.check_output(
        ["git", "ls-files", "-z"], cwd=root
    ).decode("utf-8").split("\0")
    runtime_paths = {path.relative_to(root).as_posix() for path in paths}
    with (root / "docs/localisation-repository-inventory.csv").open(
        "w", encoding="utf-8", newline=""
    ) as output:
        writer = csv.writer(output)
        writer.writerow(["path", "scope", "method"])
        for name in sorted(filter(None, tracked)):
            if name in runtime_paths:
                scope, method = "runtime-source", "literal-candidates-and-display-probes"
            elif name.startswith(("src/Data/", "src/TreeData/")) and name.endswith(".lua"):
                scope, method = "game-data", "loaded-runtime-fields-current-version"
            elif name.startswith("src/Locales/"):
                scope, method = "locale-resource", "loaded-files-and-term-review"
            elif name in ("help.txt", "changelog.txt"):
                scope, method = "product-text-resource", "boundary-audit-inventory-only"
            elif name.startswith(("src/Export/", "tools/", "spec/", "tests/", "src/Tests/", ".github/")):
                scope, method = "development", "inventory-only-not-product-text"
            else:
                scope, method = "support-or-binary", "inventory-only-native-text-not-extracted"
            writer.writerow([name, scope, method])
    for path in paths:
        text = path.read_text(encoding="utf-8-sig")
        for match in TOKENS.finditer(text):
            literal = match.group()
            if literal.startswith("--"):
                continue
            line = text.count("\n", 0, match.start()) + 1
            literals.append({
                "origin": f"{path.relative_to(source).as_posix()}:{line}",
                "literal": literal,
            })
    manifest = {
        "literals": literals,
        "sourceFiles": [path.relative_to(source).as_posix() for path in paths],
        "statFiles": [
            path.relative_to(source).with_suffix("").as_posix()
            for path in sorted((source / "Data" / "StatDescriptions").rglob("*.lua"))
        ],
    }
    (run / "localisation-audit-input.json").write_text(
        json.dumps(manifest, ensure_ascii=False), encoding="utf-8"
    )
    # 稳定 key 审计独立运行时只更新源码范围，避免旧反查报告冒充当前字段结果。
    if "--inventory-only" in sys.argv:
        print(f"范围清单：{len(list(filter(None, tracked)))} 个跟踪文件；{len(paths)} 个产品 Lua；{len(literals)} 个字符串常量；{len(manifest['statFiles'])} 个属性描述文件")
        return
    result = subprocess.run(
        [str(root / "tools" / "LuaRunner.exe"), str(root / "tools" / "audit-localisation-fields.lua")],
        cwd=source,
    )
    raise SystemExit(result.returncode)


if __name__ == "__main__":
    main()
