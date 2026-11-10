"""以业务身份生成游戏显示资源候选和引用表，保留已有稳定 key。"""
import csv
import json
from pathlib import Path
import re
import sys


def lua_string(value):
    """编码 Lua 字符串，保留资源身份中的路径和标点。"""
    return json.dumps(value, ensure_ascii=False)


def main():
    """准备译文提取候选，或在校验身份后写入独立游戏语言资源。"""
    root = Path(__file__).resolve().parent.parent
    run = root / 'src/Tests/Run'
    if '--apply' in sys.argv:
        records = json.loads((run / 'key-game-records-prepared.json').read_text(encoding='utf-8'))
    else:
        records = json.loads((run / 'key-game-data.json').read_text(encoding='utf-8'))
        if (run / 'key-stat-data.json').exists():
            records += json.loads((run / 'key-stat-data.json').read_text(encoding='utf-8'))
    unique_records = {}
    for record in records:
        identity = (record['domain'], record['id'], record['field'])
        previous = unique_records.get(identity)
        assert previous is None or previous == record, f'显示字段身份冲突: {identity}'
        unique_records[identity] = record
    records = list(unique_records.values())
    bindings_path = root / 'src/Locales/DataBindings.json'
    bindings = json.loads(bindings_path.read_text(encoding='utf-8')) if bindings_path.exists() else {}
    used = {key for domain in bindings.values() for fields in domain.values() for key in fields.values()}
    existing_english = {}
    if (root / 'src/Locales/en/Game.csv').exists():
        with (root / 'src/Locales/en/Game.csv').open(encoding='utf-8', newline='') as source:
            existing_english = dict(list(csv.reader(source))[1:])
    candidates = []
    for record in sorted(records, key=lambda row: (row['domain'], row['id'], row['field'])):
        fields = bindings.setdefault(record['domain'], {}).setdefault(record['id'], {})
        key = fields.get(record['field'])
        if not key:
            identity = re.sub('[^a-z0-9]+', '_', record['id'].lower()).strip('_')
            field = re.sub(r'([a-z])([A-Z])', r'\1_\2', record['field']).lower()
            base = f"game.{record['domain']}.{identity}.{field}"
            key, number = base, 1
            while key in used:
                number += 1
                key = f'{base}_{number}'
            fields[record['field']] = key
            used.add(key)
        text = record.get('template', record['text'].replace('{', '{{').replace('}', '}}'))
        candidates.append({
            'key': key, 'text': text, 'skipExisting': existing_english.get(key) == text and '--refresh-translations' not in sys.argv,
            'file': record['domain'] + ':' + record['id'], 'line': 0,
            'context': 'data.' + record['field'], 'parameters': record.get('parameters', []),
        })
    if '--apply' not in sys.argv:
        (run / 'key-game-records-prepared.json').write_text(json.dumps(records, ensure_ascii=False), encoding='utf-8')
        (run / 'key-migration-candidates.json').write_text(json.dumps({'files': [], 'candidates': candidates, 'resources': [], 'pending': [], 'errors': []}, ensure_ascii=False, indent=2), encoding='utf-8')
        (run / 'key-game-bindings.json').write_text(json.dumps(bindings, ensure_ascii=False, indent=2), encoding='utf-8')
        print(f'Prepared {len(candidates)} data field resources.')
        return
    assert bindings == json.loads((run / 'key-game-bindings.json').read_text(encoding='utf-8')), '数据身份在提取后变化'
    translations = {row['key']: row for row in json.loads((run / 'key-migration-translations.json').read_text(encoding='utf-8'))}
    catalogs = {lang: {} for lang in ('en', 'zh-CN', 'zh-TW')}
    import runpy
    validate_parameters = runpy.run_path(str(root / 'tools/apply-localisation-keys.py'))['parameters']
    rejected = []
    for candidate in candidates:
        row = translations[candidate['key']]
        assert row['en'] == candidate['text'], candidate['key']
        for language, text in (row['rejected'] or {}).items():
            rejected.append({'key': row['key'], 'language': language, 'source': row['en'], 'rejectedTranslation': text})
        catalogs['en'][row['key']] = row['en']
        expected = validate_parameters(row['en'])
        for language, text in (row['translations'] or {}).items():
            try:
                assert validate_parameters(text) == expected
            except (AssertionError, ValueError) as error:
                rejected.append({'key': row['key'], 'language': language, 'source': row['en'], 'rejectedTranslation': text, 'reason': str(error) or '参数集合不一致'})
                continue
            catalogs[language][row['key']] = text
    for language, entries in catalogs.items():
        resource = root / 'src/Locales' / language / 'Game.csv'
        if resource.exists():
            with resource.open(encoding='utf-8', newline='') as source:
                previous = dict(list(csv.reader(source))[1:])
            if language == 'en':
                previous.update(entries)
            else:
                for key, text in entries.items(): previous.setdefault(key, text)
            entries = previous
        with resource.open('w', encoding='utf-8', newline='') as output:
            writer = csv.writer(output, lineterminator='\n')
            writer.writerow(['key', 'text']); writer.writerows(sorted(entries.items()))
    bindings_path.write_text(json.dumps(bindings, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    lines = ['-- 业务身份到显示字段 key 的显式引用；英文正文独立存放在 Game.csv。', 'return {']
    key_folder = root / 'src/Locales/Keys'
    key_folder.mkdir(exist_ok=True)
    for domain, objects in sorted(bindings.items()):
        lines.append('\t[' + lua_string(domain) + "] = dofile('Locales/Keys/" + domain + ".lua'),")
        domain_lines = ['-- 按业务身份保留显示字段引用，避免单个 Lua 函数超过常量表上限。', 'return {']
        chunks, constants = [], 0
        for identity, fields in sorted(objects.items()):
            if constants + len(fields) + 1 > 20000:
                chunks.append(domain_lines + ['}'])
                domain_lines = [domain_lines[0], 'return {']
                constants = 0
            values = ', '.join('[' + lua_string(field) + '] = ' + lua_string(key) for field, key in sorted(fields.items()))
            domain_lines.append('\t[' + lua_string(identity) + '] = { ' + values + ' },')
            constants += len(fields) + 1
        domain_lines.append('}')
        if chunks:
            chunks.append(domain_lines)
            paths = []
            for index, chunk in enumerate(chunks, 1):
                name = f'{domain}_{index}.lua'
                (key_folder / name).write_text('\n'.join(chunk) + '\n', encoding='utf-8')
                paths.append(lua_string('Locales/Keys/' + name))
            domain_lines = ['-- 按常量预算拆分大型数据域，加载后仍保持同一业务身份索引。', 'local result = { }',
                            'for _, path in ipairs({ ' + ', '.join(paths) + ' }) do',
                            '\tfor id, fields in pairs(dofile(path)) do result[id] = fields end', 'end', 'return result']
        (key_folder / (domain + '.lua')).write_text('\n'.join(domain_lines) + '\n', encoding='utf-8')
    lines.append('}')
    (root / 'src/Locales/DataKeys.lua').write_text('\n'.join(lines) + '\n', encoding='utf-8')
    # 业务源行的形状与英文显示模板分开，修改英文措辞不会使绑定失效。
    line_inputs = {}
    for record in records:
        if 'template' in record and re.search(r'_\d+$', record['field']) and 'inputContext' not in record:
            line_inputs[bindings[record['domain']][record['id']][record['field']]] = record['template']
    line_loader = ['-- 业务行识别形状独立于英文显示措辞。', 'local result = { }']
    line_entries = sorted(line_inputs.items())
    for offset in range(0, len(line_entries), 8000):
        name = f'LineInputs_{offset // 8000 + 1}.lua'
        chunk = ['-- 仅用于绑定时核对业务源行，禁止在最终绘制时反查。', 'return {']
        for key, template in line_entries[offset:offset + 8000]:
            chunk.append('\t[' + lua_string(key) + '] = ' + lua_string(template) + ',')
        (key_folder / name).write_text('\n'.join(chunk + ['}']) + '\n', encoding='utf-8')
        line_loader.append("for key, template in pairs(dofile('Locales/Keys/" + name + "')) do result[key] = template end")
    (root / 'src/Locales/LineInputs.lua').write_text('\n'.join(line_loader + ['return result']) + '\n', encoding='utf-8')
    # 输入规则只用于原物品解析边界，显示仍由绑定后的稳定 key 决定。
    input_rules, seen_rules = [], set()
    for record in records:
        if 'inputContext' not in record:
            continue
        key = bindings[record['domain']][record['id']][record['field']]
        rule = (record['inputContext'], record['template'], key)
        if rule not in seen_rules:
            seen_rules.add(rule)
            input_rules.append(rule)
    rule_files = []
    for offset in range(0, len(input_rules), 8000):
        name = f'ModifierInputs_{offset // 8000 + 1}.lua'
        rule_files.append(name)
        rule_lines = ['-- 物品解析边界的独立输入语法和已知业务资源引用。', 'return {']
        for context, template, key in sorted(input_rules[offset:offset + 8000]):
            rule_lines.append('\t{ ' + ', '.join(map(lua_string, (context, template, key))) + ' },')
        (key_folder / name).write_text('\n'.join(rule_lines + ['}']) + '\n', encoding='utf-8')
    rule_loader = ['-- 输入识别规则与显示资源独立；禁止在绘制时查询此索引。', 'local result = { }']
    for name in rule_files:
        rule_loader.append("for _, rule in ipairs(dofile('Locales/Keys/" + name + "')) do result[#result + 1] = rule end")
    (root / 'src/Locales/ModifierInputs.lua').write_text('\n'.join(rule_loader + ['return result']) + '\n', encoding='utf-8')
    (root / 'src/Tests/Run/localisation-game-rejected.json').write_text(json.dumps(rejected, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    with (root / 'src/Tests/Run/localisation-game-fields.csv').open('w', encoding='utf-8', newline='') as output:
        writer = csv.writer(output, lineterminator='\n')
        writer.writerow(['domain', 'id', 'field', 'key'])
        for domain, objects in sorted(bindings.items()):
            for identity, fields in sorted(objects.items()):
                for field, key in sorted(fields.items()): writer.writerow([domain, identity, field, key])
    print(f'Wrote {len(candidates)} data field resources and explicit identity bindings.')


if __name__ == '__main__':
    main()
