"""校验无界面指标快照的字体、生成器和内容身份，防止静默使用过期数据。"""
import hashlib
import json
from pathlib import Path


def main() -> None:
    """检查真实字体快照的来源哈希；不声称执行了 GDI 或像素验收。"""
    root = Path(__file__).resolve().parent.parent
    folder = root / 'src/Tests/Fixtures/fonts'
    sources = json.loads((folder / 'sources.json').read_text(encoding='utf-8'))
    for family in ('SC', 'JP', 'KR'):
        spec = sources[family]
        assert hashlib.sha256((root / spec['font']).read_bytes()).hexdigest() == spec['font_sha256'], f'{family}: 字体已变化，请在 Windows 重建指标'
        assert hashlib.sha256((folder / family / 'Glyphs.lua').read_bytes()).hexdigest() == spec['metrics_sha256'], f'{family}: 指标内容与来源记录不一致'
    generator = (root / 'tools/FontAtlas.cpp').read_text(encoding='utf-8').encode('utf-8')
    assert hashlib.sha256(generator).hexdigest() == sources['generator_sha256'], '字体生成器已变化，请在 Windows 重建指标'
    print('Headless font metric provenance passed: SC, JP, KR.')


if __name__ == '__main__':
    main()
