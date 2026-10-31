"""校验 TGA 压缩包行边界、字形图集大小和像素数，无第三方依赖。"""
from pathlib import Path
import argparse
import struct


def check_page(path: Path) -> None:
    """逐包校验，防止生成 SimpleGraphic 无法按行解码的图像。"""
    data = path.read_bytes()
    width, height = struct.unpack_from('<HH', data, 12)
    assert data[2] == 10 and data[16] == 32 and (width, height) == (2048, 2048), path
    offset, pixels = 18, 0
    while pixels < width * height:
        header = data[offset]
        count = (header & 127) + 1
        assert pixels % width + count <= width, f'{path}: RLE 包跨行'
        offset += 1 + (4 if header & 128 else count * 4)
        assert offset <= len(data), f'{path}: 像素数据被截断'
        pixels += count
    assert pixels == width * height and offset == len(data), f'{path}: 像素数量不符'


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--folder', type=Path, default=Path(__file__).resolve().parent.parent / 'src/Locales/Fonts')
    parser.add_argument('--all', action='store_true', help='同时检查日文、韩文图集')
    args = parser.parse_args()
    folders = [args.folder]
    if args.all:
        folders.extend(args.folder / language for language in ('ja-JP', 'ko-KR'))
    for folder in folders:
        assert (folder / 'Glyphs.lua').is_file(), f'{folder}: 缺少 Glyphs.lua'
        pages = sorted(folder.glob('atlas-*.tga'))
        assert pages, f'{folder}: 请先运行 build.cmd 生成字体图集'
        for page in pages:
            check_page(page)
        print(f'{folder}: 通过 {len(pages)} 张字体图集的 RLE 行边界与像素完整性检查。')
