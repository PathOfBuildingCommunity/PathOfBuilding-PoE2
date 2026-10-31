"""校验已审阅的显示调用候选与源码哈希，再写入 key 调用和独立语言资源。"""
from collections import defaultdict
import csv
import hashlib
import json
from pathlib import Path
import re
import sys


def parameters(text):
    """核对命名模板，不把字面双花括号误认为参数。"""
    result = {}
    position = 0
    while position < len(text):
        if text[position:position + 2] in ("{{", "}}"):
            position += 2
            continue
        if text[position] == "{":
            match = re.match(r"\{([a-zA-Z_][a-zA-Z0-9_]*)(?::([^{}]+))?\}", text[position:])
            if not match:
                raise ValueError("无效命名模板：" + text)
            name, format_spec = match[1], match[2] or ""
            if format_spec and not re.fullmatch(r"[+\- #0-9.]*[sdiufFeEgGxXoc]", format_spec):
                raise ValueError("无效参数格式：" + text)
            if name in result and result[name] != format_spec:
                raise ValueError("同名参数格式不一致：" + text)
            result[name] = format_spec
            position += len(match[0])
        elif text[position] == "}":
            raise ValueError("花括号未配对：" + text)
        else:
            position += 1
    return result


def main():
    """先完成所有校验，再按字节范围应用已定位的显示表达式。"""
    root = Path(__file__).resolve().parent.parent
    run = root / "src/Tests/Run"
    scan = json.loads((run / "key-migration-candidates.json").read_text(encoding="utf-8"))
    translations = json.loads((run / "key-migration-translations.json").read_text(encoding="utf-8"))
    catalogs = {}
    for language in ("en", "zh-CN", "zh-TW"):
        with (root / "src/Locales" / language / "Messages.csv").open(encoding="utf-8", newline="") as source:
            rows = list(csv.reader(source))
        assert rows[0] == ["key", "text"]
        catalogs[language] = dict(rows[1:])
    rejected = []
    for entry in translations:
        key, english = entry["key"], entry["en"]
        expected = parameters(english)
        assert "--resources-only" in sys.argv or key not in catalogs["en"] or catalogs["en"][key] == english, key
        catalogs["en"][key] = english
        if "--resources-only" in sys.argv:
            for language in ("zh-CN", "zh-TW"):
                catalogs[language].pop(key, None)
        for language, text in (entry["translations"] or {}).items():
            try:
                assert parameters(text) == expected
            except (AssertionError, ValueError):
                rejected.append({"key": key, "language": language, "translation": text})
                continue
            catalogs[language][key] = text
        for language, text in (entry["rejected"] or {}).items():
            rejected.append({"key": key, "language": language, "translation": text})
    grouped = defaultdict(list)
    for entry in scan["candidates"]:
        assert entry["key"] in catalogs["en"], entry["key"]
        grouped[entry["file"]].append(entry)
    hashes = {entry["file"]: entry["sha256"] for entry in scan["files"]}
    edits = {}
    for name, entries in ([] if "--resources-only" in sys.argv else grouped.items()):
        source = (root / name).read_bytes()
        assert hashlib.sha256(source).hexdigest() == hashes[name], "源码在扫描后变化：" + name
        for entry in sorted(entries, key=lambda item: item["range"][0], reverse=True):
            start, end = entry["range"]
            assert source[start:end] == entry["before"].encode("latin1"), name
            source = source[:start] + entry["after"].encode("latin1") + source[end:]
        edits[name] = source
    for language, entries in catalogs.items():
        for key, text in entries.items():
            assert parameters(text) == parameters(catalogs["en"][key]), (language, key)
    for language, entries in catalogs.items():
        with (root / "src/Locales" / language / "Messages.csv").open("w", encoding="utf-8", newline="") as output:
            writer = csv.writer(output, lineterminator="\n")
            writer.writerow(["key", "text"])
            writer.writerows(sorted(entries.items()))
    for name, source in edits.items():
        (root / name).write_bytes(source)
    report_path = root / "src/Tests/Run/localisation-key-calls.csv"
    previous_calls = []
    if report_path.exists():
        with report_path.open(encoding="utf-8", newline="") as source:
            previous_calls = list(csv.reader(source))[1:]
    calls = {tuple(row): row for row in previous_calls}
    for entry in scan["candidates"] + scan["resources"]:
        row = [entry["key"], entry["file"], str(entry["line"]), entry["context"], entry["text"], ", ".join(p["name"] for p in entry["parameters"])]
        calls[tuple(row)] = row
    with report_path.open("w", encoding="utf-8", newline="") as output:
        writer = csv.writer(output, lineterminator="\n")
        writer.writerow(["key", "file", "line", "context", "english", "parameters"])
        writer.writerows(calls.values())
    pending_path = root / "src/Tests/Run/localisation-key-pending.json"
    previous = json.loads(pending_path.read_text(encoding="utf-8")) if pending_path.exists() else {}
    pending = {}
    for category, entries in {"unmigratedExpressions": scan["pending"], "unparsedFiles": scan["errors"], "rejectedTranslations": rejected}.items():
        merged = {json.dumps(entry, sort_keys=True, ensure_ascii=False): entry for entry in previous.get(category, []) + entries}
        pending[category] = list(merged.values())
    pending_path.write_text(json.dumps(pending, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"已写入 {len(edits)} 个源码文件的 {len(scan['candidates'])} 个显示调用；英文资源 {len(catalogs['en'])} 个 key。")
    print(f"累计待复核 {len(pending['unmigratedExpressions'])} 个共享表达式、{len(pending['unparsedFiles'])} 条解析诊断、{len(pending['rejectedTranslations'])} 条无效译文；不是全量迁移完成。")


if __name__ == "__main__":
    main()
