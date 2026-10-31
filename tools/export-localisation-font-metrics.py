"""从已生成的真实字体图集更新 Linux 布局测试指标，不复制像素页面。"""
import hashlib
import json
from pathlib import Path


def main() -> None:
    """导出三种字体的完整指标，并记录字体及生成器的内容身份。"""
    root = Path(__file__).resolve().parent.parent
    fixtures = root / 'src/Tests/Fixtures/fonts'
    sources = {}
    for family, folder in (('SC', ''), ('JP', 'ja-JP'), ('KR', 'ko-KR')):
        source = root / 'src/Locales/Fonts' / folder / 'Glyphs.lua'
        content = source.read_bytes()
        target = fixtures / family / 'Glyphs.lua'
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(content)
        font = root / f'assets/fonts/NotoSans{family}-VF.ttf'
        sources[family] = {
            'font': font.relative_to(root).as_posix(),
            'font_sha256': hashlib.sha256(font.read_bytes()).hexdigest(),
            'metrics_sha256': hashlib.sha256(content).hexdigest(),
        }
    sources['generator_sha256'] = hashlib.sha256((root / 'tools/FontAtlas.cpp').read_text(encoding='utf-8').encode('utf-8')).hexdigest()
    (fixtures / 'sources.json').write_text(json.dumps(sources, indent=2) + '\n', encoding='utf-8')


if __name__ == '__main__':
    main()
