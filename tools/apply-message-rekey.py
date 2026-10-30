"""校验命名审阅与源码哈希，统一更新资源和显式 key 引用。"""
import csv
import hashlib
import io
import json
from pathlib import Path
import re


def main():
    """先核对全部输入，再写入双射重命名和可追溯的引用映射。"""
    root = Path(__file__).resolve().parent.parent
    plan = json.loads((root / 'src/Tests/Run/key-message-rekey.json').read_text(encoding='utf-8'))
    mapping = plan['mapping']
    assert len(set(mapping.values())) == len(mapping), '重命名后的 key 冲突'
    for entry in plan['files']:
        assert hashlib.sha256((root / entry['file']).read_bytes()).hexdigest() == entry['sha256'], '源码在命名审阅后改变: ' + entry['file']
    edits = {}
    pattern = re.compile(rb'([\x22\x27])(ui\.[a-z0-9_.]+)\1')
    for folder in ('src/Classes', 'src/Modules', 'src/Tests', 'src/Locales', 'tools'):
        for path in (root / folder).rglob('*.lua'):
            original = path.read_bytes()
            result = pattern.sub(lambda match: match[1] + mapping.get(match[2].decode('ascii'), match[2].decode('ascii')).encode('ascii') + match[1], original)
            if original != result:
                edits[path] = result
    for name in ('Launch.lua', 'LaunchInstall.lua', 'UpdateCheck.lua', 'UpdateApply.lua'):
        path = root / 'src' / name
        if path.exists():
            original = path.read_bytes()
            result = pattern.sub(lambda match: match[1] + mapping.get(match[2].decode('ascii'), match[2].decode('ascii')).encode('ascii') + match[1], original)
            if original != result:
                edits[path] = result
    for language in ('en', 'zh-CN', 'zh-TW'):
        path = root / 'src/Locales' / language / 'Messages.csv'
        with path.open(encoding='utf-8', newline='') as source:
            catalog = dict(list(csv.reader(source))[1:])
        if language == 'en':
            assert not (set(mapping) - catalog.keys()), '存在没有英文资源的引用'
        entries = {}
        for key, text in catalog.items():
            renamed = mapping.get(key, key)
            assert renamed not in entries, '资源重命名冲突: ' + renamed
            entries[renamed] = text
        output = io.StringIO(newline='')
        writer = csv.writer(output, lineterminator='\n')
        writer.writerow(('key', 'text'))
        writer.writerows(sorted(entries.items()))
        edits[path] = output.getvalue().encode('utf-8')
    report = root / 'docs/localisation-key-calls.csv'
    with report.open(encoding='utf-8', newline='') as source:
        rows = list(csv.reader(source))
    for row in rows[1:]:
        row[0] = mapping.get(row[0], row[0])
    output = io.StringIO(newline='')
    csv.writer(output, lineterminator='\n').writerows(rows)
    edits[report] = output.getvalue().encode('utf-8')
    bindings_path = root / 'src/Locales/MessageBindings.json'
    previous = json.loads(bindings_path.read_text(encoding='utf-8')) if bindings_path.exists() else {'mapping': {}, 'evidence': []}
    assert not (set(previous['mapping']) & mapping.keys()), '不得重定义已经建立的 key 映射'
    previous['mapping'].update(mapping)
    previous['evidence'].extend(plan['evidence'])
    edits[bindings_path] = (json.dumps(previous, ensure_ascii=False, indent=2) + '\n').encode('utf-8')
    for path, content in edits.items():
        path.write_bytes(content)
    print('Renamed', len(mapping), 'message keys;', len(edits), 'files updated; language text unchanged.')


if __name__ == '__main__':
    main()
