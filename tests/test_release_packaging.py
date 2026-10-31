"""发布行为回归：更新清单与便携包一致，污染或缺少字体支持必须失败。"""
import configparser
import hashlib
from pathlib import Path
import runpy
import tempfile
import unittest
import xml.etree.ElementTree as ET
import zipfile

ROOT = Path(__file__).resolve().parents[1]
stage_files = runpy.run_path(str(ROOT / 'tools/package-portable.py'))['stage_files']
check_release = runpy.run_path(str(ROOT / 'tools/check-release.py'))['check_release']
from update_manifest import manifest_paths


class ReleasePackagingTests(unittest.TestCase):
    """用真实目录与 ZIP 检查发布边界，不运行编译器或网络请求。"""

    def test_manifest_and_portable_share_selection(self):
        """个人状态和测试报告不进入任何发布清单，必要资源仍被保留。"""
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary) / 'source'
            root.mkdir()
            (root / 'manifest.cfg').write_bytes((ROOT / 'manifest.cfg').read_bytes())
            allowed = {
                'LICENSE.md', 'help.txt', 'changelog.txt',
                'src/Launch.lua', 'src/Modules/Localisation/Font.lua',
                'src/Locales/Manifest.lua', 'src/Locales/Fonts/Glyphs.lua',
                'src/Locales/Fonts/atlas-01.tga', 'src/TreeData/0_5/tree.lua',
                'runtime/FontAtlas.exe', 'runtime/Path{space}of{space}Building-PoE2.exe',
            }
            for family in ('SC', 'JP', 'KR'):
                allowed.update({f'assets/fonts/NotoSans{family}-VF.ttf', f'docs/licenses/NotoSans{family}-OFL.txt'})
            forbidden = {
                'src/Tests/Localisation.lua', 'src/Tests/Run/report.json',
                'src/Tests/Run/clone/LICENSE.md', 'src/Tests/Run/cache/Glyphs.lua',
                'src/Settings.xml', 'src/Builds/My Build.xml', 'src/HeadlessWrapper.lua',
                'src/LaunchInstall.lua', 'src/LaunchServer.lua', 'src/_SimpleGraphic.def.lua',
                'src/session.log', 'src/process.pid', 'src/Export/ggpk/data/test.json',
                'src/TreeData/0_5/export.log', 'runtime/SimpleGraphic/Screenshots/frame.jpg',
                'runtime/imgui.ini', 'runtime/SimpleGraphic/SimpleGraphic.cfg',
                'runtime/SimpleGraphic/SimpleGraphic.log', 'runtime/FontAtlas.obj',
                'tools/node_modules/example/LICENSE.md', 'tools/LuaRunner.exe',
                'assets/fonts/NotoSansCJKkr-Regular.otf', 'docs/localisation/report.json',
            }
            for name in allowed | forbidden:
                path = root / name
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_bytes(b'fixture')
            config = configparser.ConfigParser()
            config.read(root / 'manifest.cfg')
            selected = list(manifest_paths(root, config))
            self.assertEqual({path.as_posix() for _, path, _ in selected}, allowed)
            staged = Path(temporary) / 'portable'
            stage_files(root, staged)
            expected = {str(relative).replace('\\', '/').replace('{space}', ' ') for _, _, relative in selected}
            self.assertEqual({path.relative_to(staged).as_posix() for path in staged.rglob('*') if path.is_file()}, expected)

    def make_bundle(self, folder, changes=None, bad_sha1=False):
        # 构建最小可分发 ZIP，后续变异覆盖漏项和内容污染。
        files = {'Path of Building-PoE2.exe': b'MZapp', 'lua51.dll': b'MZlua',
                 'Launch.lua': b'-- entry', 'Locales/Manifest.lua': b'return {}',
                 'FontAtlas.exe': b'MZfont'}
        for family in ('SC', 'JP', 'KR'):
            files[f'assets/fonts/NotoSans{family}-VF.ttf'] = b'font'
            files[f'docs/licenses/NotoSans{family}-OFL.txt'] = b'OFL'
        for name, content in (changes or {}).items():
            if content is None:
                files.pop(name)
            else:
                files[name] = content
        tree = ET.Element('PoBVersion')
        for name, content in files.items():
            ET.SubElement(tree, 'File', name=name, part='program', sha1='bad' if bad_sha1 else hashlib.sha1(content).hexdigest())
        manifest = ET.tostring(tree)
        (folder / 'manifest.xml').write_bytes(manifest)
        with zipfile.ZipFile(folder / 'portable.zip', 'w') as archive:
            for name, content in files.items():
                archive.writestr(name, content)
            archive.writestr('manifest.xml', manifest)
        (folder / 'SHA256SUMS.txt').write_text(''.join(
            hashlib.sha256((folder / name).read_bytes()).hexdigest() + '  ' + name + '\n'
            for name in ('portable.zip', 'manifest.xml')), encoding='utf-8')

    def test_complete_bundle_passes(self):
        """生成器与三种字体及许可证齐全时通过附件校验。"""
        with tempfile.TemporaryDirectory() as temporary:
            folder = Path(temporary)
            self.make_bundle(folder)
            check_release(folder)

    def test_missing_font_license_or_support_fails(self):
        """删掉任一字体、许可证或全部字体支持都会失败。"""
        names = ['FontAtlas.exe']
        for family in ('SC', 'JP', 'KR'):
            names.extend((f'assets/fonts/NotoSans{family}-VF.ttf', f'docs/licenses/NotoSans{family}-OFL.txt'))
        for name in names:
            with self.subTest(name=name), tempfile.TemporaryDirectory() as temporary:
                folder = Path(temporary)
                self.make_bundle(folder, {name: None})
                with self.assertRaises(AssertionError):
                    check_release(folder)

    def test_private_state_and_reports_fail(self):
        """即使清单哈希有效，也拒绝发布测试报告或个人数据。"""
        for name in ('Tests/Run/report.json', 'Settings.xml', 'Builds/private.xml',
                     'tools/LuaRunner.exe', 'runtime.log', 'font.pid'):
            with self.subTest(name=name), tempfile.TemporaryDirectory() as temporary:
                folder = Path(temporary)
                self.make_bundle(folder, {name: b'private'})
                with self.assertRaises(AssertionError):
                    check_release(folder)

    def test_damaged_manifest_hash_fails(self):
        """附件整体校验有效也不能掩盖内部文件哈希错误。"""
        with tempfile.TemporaryDirectory() as temporary:
            folder = Path(temporary)
            self.make_bundle(folder, bad_sha1=True)
            with self.assertRaises(AssertionError):
                check_release(folder)

    def test_partial_atlas_fails_even_with_generator(self):
        """存在指标却缺少引用页面时，不允许把坏图集交给用户。"""
        with tempfile.TemporaryDirectory() as temporary:
            folder = Path(temporary)
            self.make_bundle(folder, {'Locales/Fonts/Glyphs.lua': b'return {glyphs={\n[63]={1,0,0,1,1,0,0,1}\n}}'})
            with self.assertRaises(AssertionError):
                check_release(folder)


if __name__ == '__main__':
    unittest.main()
