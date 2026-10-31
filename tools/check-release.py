"""独立校验发布 ZIP、清单哈希、字体支持和禁止分发的开发文件。"""
import argparse
import hashlib
from pathlib import Path, PurePosixPath
import re
import runpy
import tempfile
import xml.etree.ElementTree as ET
import zipfile


def check_release(folder: Path) -> None:
    """检查实际发布附件，任何漏项、污染或内容损坏都使构建失败。"""
    archives = list(folder.glob('*.zip'))
    assert len(archives) == 1, '发布目录必须只有一个 ZIP'
    archive = archives[0]
    manifest = folder / 'manifest.xml'
    checksums = {}
    for line in (folder / 'SHA256SUMS.txt').read_text(encoding='utf-8').splitlines():
        digest, name = line.split('  ', 1)
        assert name not in checksums, f'重复校验项：{name}'
        checksums[name] = digest
    assert set(checksums) == {archive.name, manifest.name}, '附件校验项不完整'
    for path in (archive, manifest):
        assert hashlib.sha256(path.read_bytes()).hexdigest() == checksums[path.name], f'SHA-256 不符：{path.name}'

    with zipfile.ZipFile(archive) as bundle:
        assert bundle.testzip() is None, 'ZIP 数据损坏'
        names = bundle.namelist()
        folded = {name.casefold(): name for name in names}
        assert len(folded) == len(names), 'ZIP 含重复或大小写冲突的文件'
        for name in names:
            path = PurePosixPath(name)
            assert not path.is_absolute() and '..' not in path.parts and '\\' not in name, f'不安全的路径：{name}'
            assert not {'.git', 'tests', 'tools', 'node_modules', '__pycache__', 'builds', 'update', 'export', 'screenshots'} & set(name.casefold().split('/')), f'混入开发或个人目录：{name}'
            assert path.name.casefold() not in {'settings.xml', 'imgui.ini', 'simplegraphic.cfg', 'poe_api_response.json', 'luacov.stats.out', '.ready'}, f'混入个人状态：{name}'
            assert path.suffix.casefold() not in {'.log', '.pid', '.obj', '.pyc'}, f'混入生成报告：{name}'
        assert bundle.read('manifest.xml') == manifest.read_bytes(), 'ZIP 内外清单不一致'
        tree = ET.fromstring(manifest.read_bytes())
        entries = tree.findall('File')
        files = {entry.attrib['name']: entry.attrib for entry in entries}
        assert len(files) == len(entries), '清单含重复文件'
        assert set(files) == set(names) - {'manifest.xml'}, '清单没有准确覆盖包中所有文件'
        for name, entry in files.items():
            assert hashlib.sha1(bundle.read(name)).hexdigest() == entry['sha1'], f'清单哈希不符：{name}'
        for name in ('path of building-poe2.exe', 'lua51.dll', 'launch.lua', 'locales/manifest.lua'):
            assert name in folded, f'缺少运行文件：{name}'
        for family in ('SC', 'JP', 'KR'):
            for name in (f'assets/fonts/NotoSans{family}-VF.ttf', f'docs/licenses/NotoSans{family}-OFL.txt'):
                assert name.casefold() in folded and bundle.getinfo(folded[name.casefold()]).file_size > 0, f'缺少字体或许可证：{name}'
        config = bundle.read(folded['locales/manifest.lua']).decode('utf-8')
        for name in re.findall(r'fontFile = "([^"]+)"', config):
            assert name.casefold() in folded, f'语言配置引用的字体未打包：{name}'

        # 验证实际图集的引用和压缩内容；生成器可负责未预生成的语言。
        check_page = runpy.run_path(str(Path(__file__).with_name('check-atlas.py')))['check_page']
        with tempfile.TemporaryDirectory(prefix='pob2-atlas-check-') as temporary:
            def check_atlas(prefix: str) -> bool:
                # 缺失整套图集由生成器兜底，存在指标时必须完整校验全部页面。
                metrics = prefix + 'Glyphs.lua'
                if metrics.casefold() not in folded:
                    return False
                text = bundle.read(folded[metrics.casefold()]).decode('utf-8')
                pages = set(map(int, re.findall(r'^\[\d+\]=\{(\d+),', text, re.MULTILINE)))
                assert pages, f'图集没有字形指标：{metrics}'
                for page in sorted(pages):
                    name = prefix + f'atlas-{page:02d}.tga'
                    assert name.casefold() in folded, f'图集缺页：{name}'
                    target = Path(temporary) / f'atlas-{page:02d}.tga'
                    target.write_bytes(bundle.read(folded[name.casefold()]))
                    check_page(target)
                return True

            atlases = [check_atlas(prefix) for prefix in ('Locales/Fonts/', 'Locales/Fonts/ja-JP/', 'Locales/Fonts/ko-KR/')]
        generator = folded.get('fontatlas.exe')
        assert all(atlases) or generator, '必须提供 FontAtlas.exe 或所有语言的完整预生成图集'
        if generator:
            assert bundle.read(generator).startswith(b'MZ'), 'FontAtlas.exe 不是 Windows 可执行文件'
    print(f'发布包校验通过：{len(files)} 个文件，字体／OFL／字体支持完整，清单及 SHA-256 匹配。')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('folder', type=Path)
    check_release(parser.parse_args().folder)
