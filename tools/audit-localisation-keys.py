"""核对全部稳定显示资源，逐 key 保留缺译与英文残留候选，不调用旧反查。"""
import csv
import re
from collections import Counter
from pathlib import Path


def main():
    # 模板候选不能当作可达界面漏译总数；保留定位供运行时审计交叉核对。
    root = Path(__file__).resolve().parent.parent
    catalogs, origins = {}, {}
    for language in ('en', 'zh-CN', 'zh-TW'):
        catalogs[language], origins[language] = {}, {}
        for name in ('Messages', 'Game'):
            path = root / 'src/Locales' / language / (name + '.csv')
            with path.open(encoding='utf-8', newline='') as source:
                reader = csv.reader(source, strict=True)
                assert next(reader) == ['key', 'text']
                for key, text in reader:
                    assert key not in catalogs[language], (language, key)
                    catalogs[language][key] = text
                    origins[language][key] = f'{path.relative_to(root).as_posix()}:{reader.line_num}'
    counts = Counter()
    with (root / 'docs/localisation-key-review.csv').open('w', encoding='utf-8', newline='') as output:
        writer = csv.writer(output)
        writer.writerow(['language', 'domain', 'status', 'key', 'origin', 'source', 'display'])
        for language in ('zh-CN', 'zh-TW'):
            for key, source in catalogs['en'].items():
                domain = '.'.join(key.split('.')[:2])
                text = catalogs[language].get(key, source)
                # 去掉参数名与颜色码，避免把模板语法误当作英文正文。
                prose = re.sub(r'\{[A-Za-z_][^{}]*\}|\^x[0-9A-Fa-f]{6}|\^[0-9]', '', text)
                status = ('missing-key' if key not in catalogs[language] else
                          'identical-English' if text == source and re.search('[A-Za-z]', prose) else
                          'latin-review' if re.search('[A-Za-z]', prose) else 'no-Latin')
                counts[language, domain, status] += 1
                if status != 'no-Latin':
                    writer.writerow([language, domain, status, key, origins[language].get(key, origins['en'][key]), source, text])
    with (root / 'docs/localisation-key-summary.csv').open('w', encoding='utf-8', newline='') as output:
        writer = csv.writer(output)
        writer.writerow(['language', 'domain', 'status', 'count'])
        for (language, domain, status), count in sorted(counts.items()):
            writer.writerow([language, domain, status, count])
    for language in ('zh-CN', 'zh-TW'):
        print(language, dict(Counter({status: sum(n for (lang, _, state), n in counts.items() if lang == language and state == status)
                                     for status in ('missing-key', 'identical-English', 'latin-review', 'no-Latin')})))


if __name__ == '__main__':
    main()
