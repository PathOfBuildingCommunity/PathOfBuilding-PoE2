"""审计语言包清单、有效词条、参数和反向歧义，不据此判断术语准确率。"""
from collections import Counter, defaultdict
import csv
from pathlib import Path
import re
import runpy


def audit_messages(root, records):
    """独立校验按 key 加载的显示资源，旧输入词典的风险不混入显示契约。"""
    parameters = runpy.run_path(str(root / 'tools/apply-localisation-keys.py'))['parameters']
    manifest = (root / 'src/Locales/Manifest.lua').read_text(encoding='utf-8')
    definitions = re.findall(r'\{ id = "([^"]+)"[^\n]*messageFiles = \{([^}]+)\}', manifest)
    catalogs, summaries, declared = {}, [], {}
    for language, names in definitions:
        files = re.findall(r'"([^"]+\.csv)"', names)
        declared[language] = set(files)
        catalog, totals = {}, Counter()
        for name in files:
            path = root / 'src/Locales' / language / name
            if not path.exists():
                records.append([language, 'message-missing-file', str(path.relative_to(root)), '', ''])
                totals['errors'] += 1
                continue
            with path.open(encoding='utf-8-sig', newline='') as source:
                reader = csv.reader(source, strict=True)
                for row in reader:
                    if reader.line_num == 1 and row == ['key', 'text']: continue
                    origin = f'{path.relative_to(root).as_posix()}:{reader.line_num}'
                    if len(row) != 2 or not all(row):
                        totals['errors'] += 1
                        records.append([language, 'message-invalid-row', origin, repr(row), ''])
                        continue
                    key, value = row
                    if not re.fullmatch(r'[a-z][a-z0-9_]*(?:\.[a-z0-9_]+)*', key) or key in catalog:
                        totals['errors'] += 1
                        records.append([language, 'message-invalid-or-duplicate-key', origin, key, value])
                    try:
                        signature = parameters(value)
                    except ValueError as error:
                        totals['errors'] += 1
                        records.append([language, 'message-invalid-template', origin, key, str(error)])
                        signature = None
                    catalog[key] = value, signature, origin
                    totals['keys'] += 1
        catalogs[language] = catalog
        summaries.append((language, totals))
    english = catalogs.get('en', {})
    for language, totals in summaries:
        catalog = catalogs[language]
        if language != 'en': totals['english-fallback-keys'] = len(english.keys() - catalog.keys())
        for key, (value, signature, origin) in catalog.items():
            if key not in english or signature != english[key][1]:
                totals['errors'] += 1
                records.append([language, 'message-unknown-key-or-parameters', origin, key, value])
        totals['files'] = len(declared[language])
    return summaries, declared


def main():
    """生成语言资源风险候选和汇总，保留未确认问题的复核状态。"""
    root = Path(__file__).resolve().parent.parent
    records, summaries = [], []
    glyph_file = root / "src/Locales/Fonts/Glyphs.lua"
    glyphs = set(map(int, re.findall(r"^\[(\d+)\]=", glyph_file.read_text(encoding="utf-8"), re.MULTILINE)))
    message_summaries, message_files = audit_messages(root, records)
    for language in ("zh-CN", "zh-TW"):
        folder = root / "src/Locales" / language
        files = re.findall(r'"([^"\n]+\.csv)"', (folder / "Files.lua").read_text(encoding="utf-8"))
        effective, origins = {}, {}
        totals = Counter()
        for path in sorted(folder.glob("*.csv")):
            if path.name not in files and path.name not in message_files.get(language, set()):
                records.append([language, "unloaded-file", str(path.relative_to(root)), "", ""])
                totals["unloaded-files"] += 1
        for name in files:
            path = folder / name
            if not path.exists():
                records.append([language, "missing-file", str(path.relative_to(root)), "", ""])
                totals["missing-files"] += 1
                continue
            with path.open(encoding="utf-8-sig", newline="") as source:
                reader = csv.reader(source, strict=True)
                for row in reader:
                    totals["rows"] += 1
                    origin = f"{path.relative_to(root).as_posix()}:{reader.line_num}"
                    if len(row) > 2 and any(row[2:]):
                        totals["extra-nonempty-columns"] += 1
                        records.append([language, "extra-columns-review", origin, row[0], " | ".join(row[1:])])
                    if len(row) < 2 or not row[0] or not row[1]:
                        if any(row):
                            totals["empty-or-short"] += 1
                            records.append([language, "empty-or-short", origin, row[0] if row else "", row[1] if len(row) > 1 else ""])
                        continue
                    text, target = row[:2]
                    if text == target:
                        totals["identity-rows"] += 1
                        continue
                    if text in effective and effective[text] != target:
                        totals["overrides"] += 1
                    effective[text], origins[text] = target, origin
        reverse = defaultdict(list)
        lower = defaultdict(set)
        missing_glyphs = set()
        for text, target in effective.items():
            reverse[target].append(text)
            lower[text.lower()].add(target)
            if set(re.findall(r"\{(\d+)\}", text)) != set(re.findall(r"\{(\d+)\}", target)):
                totals["placeholder-mismatch"] += 1
                records.append([language, "placeholder-mismatch", origins[text], text, target])
            missing = {ord(char) for char in target if ord(char) >= 32 and ord(char) not in glyphs}
            if missing:
                missing_glyphs.update(missing)
                totals["missing-glyph-terms"] += 1
                points = ", ".join(f"U+{point:04X}" for point in sorted(missing))
                records.append([language, "missing-glyph-review", origins[text] + " [" + points + "]", text, target])
        for target, texts in reverse.items():
            if len(texts) < 2 or (len(texts) == 2 and (texts[0] + "s" == texts[1] or texts[1] + "s" == texts[0])):
                continue
            totals["reverse-collision-groups"] += 1
            records.append([language, "reverse-ambiguity-review", "; ".join(origins[text] for text in texts), " | ".join(sorted(texts)), target])
        for text, targets in lower.items():
            if len(targets) > 1:
                totals["case-collision-groups"] += 1
                records.append([language, "case-collision-review", "", text, " | ".join(sorted(targets))])
        totals["loaded-files"], totals["effective-terms"] = len(files), len(effective)
        totals["missing-glyph-codepoints"] = len(missing_glyphs)
        summaries.append((language, totals))
    with (root / "docs/localisation-resource-review.csv").open("w", encoding="utf-8", newline="") as output:
        writer = csv.writer(output)
        writer.writerow(["language", "status", "origin", "source", "translation"])
        writer.writerows(records)
    lines = ["# 语言资源结构审计", "", "生成日期：2026-10-30。命令：`python tools/audit-locale-resources.py`。", "", "按 Files.lua 顺序和 Dictionary:Add 的空值/同文跳过规则计算有效词条。覆盖次数不等于缺陷；反向歧义允许安全保留原文，不能直接当成导入已兼容。大小写冲突需要结合精确匹配与小写检索复核。参数集合不一致可能丢值或产生占位符残留，须逐条核实。", "", "| 语言 | 项目 | 数量 |", "|---|---|---:|"]
    lines.extend(['', '显示资源（Manifest.messageFiles）使用稳定 key 和命名参数独立校验。英文回退数量表示尚无该语言译文，不是参数错误；以下输入词典统计不参与显示资源查找。', '', '| 显示资源语言 | 项目 | 数量 |', '|---|---|---:|'])
    for language, totals in message_summaries:
        for key, count in sorted(totals.items()):
            lines.append(f'| {language} | {key} | {count} |')
        print('messages', language, dict(totals))
    lines.extend(['', '| 输入词典语言 | 项目 | 数量 |', '|---|---|---:|'])
    for language, totals in summaries:
        for key, count in sorted(totals.items()):
            lines.append(f"| {language} | {key} | {count} |")
        print(language, dict(totals))
    lines.extend(["", "完整定位见 `localisation-resource-review.csv`。没有执行自动词库替换，也没有把每个歧义项都判成运行错误。", ""])
    (root / "docs/localisation-resource-audit.md").write_text("\n".join(lines), encoding="utf-8")


if __name__ == "__main__":
    main()
