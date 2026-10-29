"""枚举源码文字与属性模板文件，交给实际 PoB2 语言层生成覆盖报告。"""
from pathlib import Path
import json
import re
import subprocess


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
    paths = sorted((source / "Classes").glob("*.lua"))
    paths += sorted((source / "Modules").glob("*.lua"))
    paths += [source / "Launch.lua"]
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
        "statFiles": [
            path.relative_to(source).with_suffix("").as_posix()
            for path in sorted((source / "Data" / "StatDescriptions").rglob("*.lua"))
        ],
    }
    (run / "localisation-audit-input.json").write_text(
        json.dumps(manifest, ensure_ascii=False), encoding="utf-8"
    )
    result = subprocess.run(
        [str(root / "tools" / "LuaRunner.exe"), str(root / "tools" / "audit-localisation.lua")],
        cwd=source,
    )
    raise SystemExit(result.returncode)


if __name__ == "__main__":
    main()
